-- PerkSystem
-- workspace.winperks altindaki perky1..8 partlari perk kademeleridir. Oyuncu
-- Win sayisina gore acilan kademelerden birine basarak aktif perk'ini secer;
-- yeni kademe acilinca otomatik en yuksege gecer. Secim DataStore'a kaydedilir.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local SafeStore = require(script.Parent.SafeStore)
local ServerRegistry = require(script.Parent.ServerRegistry)

local store = DataStoreService:GetDataStore(GameConfig.DATASTORE_NAME)
local winperks = workspace:WaitForChild("winperks")

local SAVE_THROTTLE = 6
local TIER_COUNT = #GameConfig.PERK_WINS

local activeTier: {[number]: number} = {}
local lastSave: {[number]: number} = {}

local function saveTier(player: Player, force: boolean?)
	local tier = activeTier[player.UserId]
	if not tier then
		return
	end
	local now = os.clock()
	if not force and lastSave[player.UserId] and now - lastSave[player.UserId] < SAVE_THROTTLE then
		return
	end
	lastSave[player.UserId] = now
	SafeStore.set(store, "perktier_" .. player.UserId, tier)
end

local function setTier(player: Player, tier: number)
	activeTier[player.UserId] = tier
	local stat = player:FindFirstChild("ActivePerkTier")
	if stat then
		stat.Value = tier
	end
	saveTier(player)
end

ServerRegistry.addMultiplierSource("Perk", function(player)
	return GameConfig.getPerkStepBonus(activeTier[player.UserId] or 1)
end)

-- Perk partlari: tek baglanti, oyuncu dokunandan cozulur
for i = 1, TIER_COUNT do
	local part = winperks:FindFirstChild("perky" .. i)
	if part then
		part.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if not player or not activeTier[player.UserId] then
				return
			end
			local leaderstats = player:FindFirstChild("leaderstats")
			local wins = leaderstats and leaderstats:FindFirstChild("Wins")
			if not wins or wins.Value < GameConfig.PERK_WINS[i] then
				return
			end
			if activeTier[player.UserId] ~= i then
				setTier(player, i)
			end
		end)
	end
end

Players.PlayerAdded:Connect(function(player)
	local stat = Instance.new("IntValue")
	stat.Name = "ActivePerkTier"
	stat.Value = 1
	stat.Parent = player

	local leaderstats = player:WaitForChild("leaderstats")
	local wins = leaderstats:WaitForChild("Wins")

	local highest = GameConfig.getHighestUnlockedPerkTier(wins.Value)
	local _, saved = SafeStore.get(store, "perktier_" .. player.UserId)
	local startTier = highest
	if type(saved) == "number" and saved >= 1 and saved <= TIER_COUNT and wins.Value >= GameConfig.PERK_WINS[saved] then
		startTier = saved
	end
	activeTier[player.UserId] = startTier
	stat.Value = startTier

	wins.Changed:Connect(function(newWins)
		local newHighest = GameConfig.getHighestUnlockedPerkTier(newWins)
		if newHighest > (activeTier[player.UserId] or 1) then
			setTier(player, newHighest)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	saveTier(player, true)
	activeTier[player.UserId] = nil
	lastSave[player.UserId] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		saveTier(player, true)
	end
end)
