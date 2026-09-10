-- SpeedSystem
-- Oyuncu ilerlemesi: leaderstats, kayit/yukleme, level, WalkSpeed, rebirth ve
-- Speed satin alma. XP client'ta hesaplanip gonderilir; sunucu bunu oyuncunun
-- carpanlarina gore mumkun olan tavana kirpar ve level'i toplam XP'den turetir.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local ServerRegistry = require(script.Parent.ServerRegistry)
local SafeStore = require(script.Parent.SafeStore)
local SpawnTracker = require(script.Parent.SpawnTracker)

local playerStore = DataStoreService:GetDataStore(GameConfig.DATASTORE_NAME)

local updateSpeedEvent = Remotes.event("UpdateSpeed")          -- client -> server: totalXP
local progressSyncEvent = Remotes.event("ProgressSync")        -- server -> client: {level, xp, totalXP}
local getProgressFunc = Remotes.func("GetProgress")            -- client -> server: kayitli ilerleme
local rebirthEvent = Remotes.event("Rebirth")                  -- client -> server
local speedGrantedEvent = Remotes.event("SpeedGranted")        -- server -> client: satin alinan/hediye Speed
local setWalkSpeedEvent = Remotes.event("SetCustomWalkSpeed")  -- client -> server: istenen hiz

local AUTOSAVE_INTERVAL = 60
local BURST_CAP_SECONDS = 3 -- XP butcesi en fazla bu kadar saniyelik pay biriktirir

-- Oyuncu durumu ----------------------------------------------------------

local loaded: {[number]: boolean} = {}       -- veri yuklendi ve kaydedilebilir
local lastXPUpdate: {[number]: number} = {}  -- os.clock
local xpBudget: {[number]: number} = {}

local function defaultData()
	return {level = 1, xp = 0, totalXP = 0, rebirths = 0, wins = 0}
end

local function loadData(player: Player)
	local ok, data = SafeStore.get(playerStore, "player_" .. player.UserId)
	if not ok then
		return nil
	end
	local result = defaultData()
	if type(data) == "table" then
		for key in pairs(result) do
			if type(data[key]) == "number" then
				result[key] = data[key]
			end
		end
	end
	return result
end

local function getStats(player: Player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local level = player:FindFirstChild("Level")
	if not (leaderstats and level) then
		return nil
	end
	return {
		level = level,
		speed = leaderstats:FindFirstChild("Speed"),
		xp = leaderstats:FindFirstChild("XP"),
		wins = leaderstats:FindFirstChild("Wins"),
		rebirths = leaderstats:FindFirstChild("Rebirths"),
	}
end

local function saveData(player: Player)
	if not loaded[player.UserId] then
		return
	end
	local stats = getStats(player)
	if not stats then
		return
	end
	SafeStore.set(playerStore, "player_" .. player.UserId, {
		level = stats.level.Value,
		xp = stats.xp.Value,
		totalXP = stats.speed.Value,
		rebirths = stats.rebirths.Value,
		wins = stats.wins.Value,
	})
end

local function buildProgressPacket(stats)
	return {
		level = stats.level.Value,
		xp = stats.xp.Value,
		totalXP = stats.speed.Value,
	}
end

-- XP tavani --------------------------------------------------------------

local function getMaxTreadmillMultiplier(): number
	local highest = 1
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and obj.Name:lower():find("treadmill") then
			local mult = tonumber(obj.Name:match("(%d+)x"))
			if mult and mult > highest then
				highest = mult
			end
		end
	end
	return highest
end
local MAX_TREADMILL_MULTIPLIER = getMaxTreadmillMultiplier()

local function getMultiplierStack(player: Player, rebirths: number): number
	return GameConfig.getRebirthMultiplier(rebirths) * ServerRegistry.getMultiplier(player)
end

-- Hareket + treadmill ayni anda mumkun oldugu icin ikisi toplanir
local function getMaxXPPerSecond(player: Player, rebirths: number): number
	local stack = getMultiplierStack(player, rebirths)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local walkSpeed = humanoid and humanoid.WalkSpeed or 0
	local movement = (walkSpeed / GameConfig.STUD_PER_XP) * stack
	local treadmill = (1 / GameConfig.TREADMILL_TICK_SECONDS) * MAX_TREADMILL_MULTIPLIER * stack
	return movement + treadmill
end

-- Level her zaman toplam XP'den turetilir; asla geri dusmez
local function syncLevelFromTotalXP(stats)
	local derived = GameConfig.getLevelFromTotalXP(stats.speed.Value)
	if derived > stats.level.Value then
		stats.level.Value = derived
	end
	local levelStartXP = GameConfig.getCumulativeXP(stats.level.Value)
	stats.xp.Value = math.max(0, stats.speed.Value - levelStartXP)
end

-- WalkSpeed --------------------------------------------------------------

local function applyWalkSpeed(player: Player)
	local levelStat = player:FindFirstChild("Level")
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if levelStat and humanoid then
		humanoid.WalkSpeed = GameConfig.getMaxWalkSpeed(levelStat.Value)
	end
end

-- Oyuncu giris/cikis -----------------------------------------------------

local function createStat(className: string, name: string, value: number, parent: Instance)
	local stat = Instance.new(className)
	stat.Name = name
	stat.Value = value
	stat.Parent = parent
	return stat
end

Players.PlayerAdded:Connect(function(player)
	local saved = loadData(player)
	local canSave = saved ~= nil
	saved = saved or defaultData()
	if not canSave then
		warn(("[SpeedSystem] %s icin veri yuklenemedi; bu oturumda kayit yapilmayacak"):format(player.Name))
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local levelStat = createStat("IntValue", "Level", saved.level, player)
	local speedStat = createStat("NumberValue", "Speed", saved.totalXP, leaderstats)
	createStat("NumberValue", "XP", saved.xp, leaderstats)
	createStat("IntValue", "Wins", saved.wins, leaderstats)
	createStat("IntValue", "Rebirths", saved.rebirths, leaderstats)
	leaderstats.Parent = player

	loaded[player.UserId] = canSave
	lastXPUpdate[player.UserId] = os.clock()
	xpBudget[player.UserId] = 0

	-- Eski kayitlarda level ile toplam XP uyumsuz olabilir; yukari dogru esitle
	local derived = GameConfig.getLevelFromTotalXP(speedStat.Value)
	if derived > levelStat.Value then
		levelStat.Value = derived
	end

	levelStat.Changed:Connect(function()
		applyWalkSpeed(player)
	end)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid")
		applyWalkSpeed(player)
	end)
	applyWalkSpeed(player)

	task.spawn(function()
		while player.Parent do
			task.wait(AUTOSAVE_INTERVAL)
			if player.Parent then
				saveData(player)
			end
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	saveData(player)
	loaded[player.UserId] = nil
	lastXPUpdate[player.UserId] = nil
	xpBudget[player.UserId] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		saveData(player)
	end
end)

getProgressFunc.OnServerInvoke = function(player)
	local stats = getStats(player)
	local waited = 0
	while not stats and waited < 10 do
		task.wait(0.2)
		waited += 0.2
		stats = getStats(player)
	end
	return stats and buildProgressPacket(stats) or nil
end

-- XP guncelleme ----------------------------------------------------------
-- Token bucket: butce saniyede maxPerSec kadar dolar, en fazla BURST_CAP_SECONDS
-- kadar biriktirir. Mesru cok sayida kucuk artis gecer; event spam'i butceyi tuketir.

updateSpeedEvent.OnServerEvent:Connect(function(player, totalXP)
	if type(totalXP) ~= "number" or totalXP ~= totalXP or totalXP < 0 then
		return
	end
	local stats = getStats(player)
	if not stats then
		return
	end

	local userId = player.UserId
	local now = os.clock()
	local elapsed = math.max(0, now - (lastXPUpdate[userId] or now))
	lastXPUpdate[userId] = now

	local maxPerSec = getMaxXPPerSecond(player, stats.rebirths.Value)
	local budget = math.min((xpBudget[userId] or 0) + maxPerSec * elapsed, maxPerSec * BURST_CAP_SECONDS)

	local current = stats.speed.Value
	local requested = totalXP - current
	local needsSync = false

	if requested > 0 then
		if requested <= budget then
			budget -= requested
			current = totalXP
		else
			current += budget
			budget = 0
			needsSync = true
			warn(("[SpeedSystem] %s XP artisi kirpildi (+%d istendi)"):format(player.Name, math.floor(requested)))
		end
	elseif requested < 0 then
		-- Client sunucunun gerisinde (gec paket ya da baslangic verisi alamadi): dogru degeri gonder
		needsSync = true
	end

	xpBudget[userId] = budget
	stats.speed.Value = math.floor(current)
	syncLevelFromTotalXP(stats)

	if needsSync then
		progressSyncEvent:FireClient(player, buildProgressPacket(stats))
	end
end)

-- Speed verme (satin alma / hediye) ---------------------------------------

local function grantSpeed(player: Player, amount: number): boolean
	local stats = getStats(player)
	if not stats or amount <= 0 then
		return false
	end
	stats.speed.Value += amount
	syncLevelFromTotalXP(stats)
	speedGrantedEvent:FireClient(player, amount, buildProgressPacket(stats))
	return true
end

-- Diger sistemler (FreeGift vb.) buradan Speed verir
ServerRegistry.grantSpeed = grantSpeed

for tierIndex, tier in ipairs(GameConfig.SPEED_BUY_TIERS) do
	ServerRegistry.registerProduct(tier.productId, function(player)
		local levelStat = player:FindFirstChild("Level")
		local amount = GameConfig.getSpeedBuyAmount(levelStat and levelStat.Value or 1, tierIndex)
		return grantSpeed(player, amount or 0)
	end)
end

-- Rebirth ----------------------------------------------------------------

local function performRebirth(player: Player, skipLevelCheck: boolean): boolean
	local stats = getStats(player)
	if not stats then
		return false
	end
	if not skipLevelCheck then
		local required = GameConfig.getRebirthRequiredLevel(stats.rebirths.Value)
		if stats.level.Value < required then
			return false
		end
	end

	stats.rebirths.Value += 1
	stats.level.Value = 1
	stats.xp.Value = 0
	stats.speed.Value = 0
	lastXPUpdate[player.UserId] = os.clock()
	xpBudget[player.UserId] = 0

	SpawnTracker.returnToSpawn(player)
	progressSyncEvent:FireClient(player, buildProgressPacket(stats))
	saveData(player)
	return true
end

rebirthEvent.OnServerEvent:Connect(function(player)
	performRebirth(player, false)
end)

ServerRegistry.registerProduct(GameConfig.PRODUCTS.SKIP_REBIRTH, function(player)
	return performRebirth(player, true)
end)

-- Ozel WalkSpeed ---------------------------------------------------------

setWalkSpeedEvent.OnServerEvent:Connect(function(player, requestedSpeed)
	if type(requestedSpeed) ~= "number" or requestedSpeed ~= requestedSpeed then
		return
	end
	local levelStat = player:FindFirstChild("Level")
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not (levelStat and humanoid) then
		return
	end
	local maxSpeed = GameConfig.getMaxWalkSpeed(levelStat.Value)
	humanoid.WalkSpeed = math.clamp(math.floor(requestedSpeed), 1, maxSpeed)
end)
