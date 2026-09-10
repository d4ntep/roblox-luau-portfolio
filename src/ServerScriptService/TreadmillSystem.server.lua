-- TreadmillSystem
-- Haritadaki "<N>x treadmill" modelleri: oyuncu Attachment0-Attachment1 arasindaki
-- bantta durdugu surece client'a periyodik XP tick'i gonderilir. 1x herkese acik,
-- digerleri gamepass ister. Ayrica oyuncu tasinabilir (portable) bir treadmill
-- spawnlayabilir: sahip oldugu en yuksek tier, sadece kendisine XP verir.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local GamePassIds = require(ReplicatedStorage:WaitForChild("GamePassIds"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local GamePassCache = require(script.Parent.GamePassCache)

local TREADMILL_PASSES = GamePassIds.TREADMILL_PASSES
local treadmillEvent = Remotes.event("TreadmillXP")       -- server -> client: "start"|"stop"|"xp"|"locked"
local portableEvent = Remotes.event("PortableTreadmill")  -- iki yonlu: spawn/kaldir istegi ve durum

local XP_TICK = GameConfig.TREADMILL_TICK_SECONDS
local PORTABLE_TIER_ORDER = {100, 25, 10, 1}
local OFFZONE_DESPAWN_TIME = 1.5 -- ziplama gibi kisa cikislarda hemen kaybolmasin
local PORTABLE_FALLBACK_BELT_LEN = 8
local PORTABLE_DEBOUNCE = 0.6

-- Statik treadmill'ler -----------------------------------------------------

local treadmills = {} -- {model, multiplier, att0, att1}
local templates = {}  -- multiplier -> model

for _, obj in ipairs(workspace:GetDescendants()) do
	local name = obj.Name:lower()
	if obj:IsA("Model") and name:find("treadmill") and not name:find("spawner") then
		local att0 = obj:FindFirstChild("Attachment0")
		local att1 = obj:FindFirstChild("Attachment1")
		if att0 and att1 then
			local multiplier = tonumber(obj.Name:match("(%d+)x")) or 1
			table.insert(treadmills, {model = obj, multiplier = multiplier, att0 = att0, att1 = att1})
			templates[multiplier] = templates[multiplier] or obj
		end
	end
end

local function isOnTreadmill(root: BasePart, att0: Attachment, att1: Attachment): boolean
	local pos = root.Position
	local p0, p1 = att0.WorldPosition, att1.WorldPosition
	return pos.X >= math.min(p0.X, p1.X) - 3 and pos.X <= math.max(p0.X, p1.X) + 3
		and pos.Z >= math.min(p0.Z, p1.Z) - 3 and pos.Z <= math.max(p0.Z, p1.Z) + 3
		and pos.Y >= math.min(p0.Y, p1.Y) - 1 and pos.Y <= math.max(p0.Y, p1.Y) + 4
end

-- Portable treadmill ---------------------------------------------------------
-- Boyut referansi workspace.Treadmillspawner modelidir; onu Studio'da
-- buyutup kucultmek portable treadmill boyutunu dogrudan degistirir.

local portables = {} -- player -> {model, multiplier, att0, att1, offZone, removing}
local portableDebounce = {}

local function getReferenceBeltLength(): number
	local spawner = workspace:FindFirstChild("Treadmillspawner")
	local a0 = spawner and spawner:FindFirstChild("Attachment0")
	local a1 = spawner and spawner:FindFirstChild("Attachment1")
	if a0 and a1 then
		local len = (a1.WorldPosition - a0.WorldPosition).Magnitude
		if len > 0.5 then
			return len
		end
	end
	return PORTABLE_FALLBACK_BELT_LEN
end

local function getBestOwnedMultiplier(player: Player): number?
	for _, mult in ipairs(PORTABLE_TIER_ORDER) do
		if templates[mult] then
			local passId = TREADMILL_PASSES[mult]
			if not passId or GamePassCache.PlayerOwnsGamePass(player, passId) then
				return mult
			end
		end
	end
	return nil
end

local function animateScale(model: Model, from: number, to: number, duration: number, onDone: (() -> ())?)
	task.spawn(function()
		local start = os.clock()
		while model.Parent do
			local alpha = math.clamp((os.clock() - start) / duration, 0, 1)
			local eased = 1 - (1 - alpha) * (1 - alpha)
			pcall(model.ScaleTo, model, math.max(from + (to - from) * eased, 0.05))
			if alpha >= 1 then
				break
			end
			task.wait()
		end
		if onDone then
			onDone()
		end
	end)
end

local playerTimers = {}
local playerOnTreadmill = {}

local function despawnPortable(player: Player, instant: boolean?)
	local portable = portables[player]
	if not portable or portable.removing then
		return
	end
	portable.removing = true
	portables[player] = nil

	if playerOnTreadmill[player] == portable then
		playerOnTreadmill[player] = nil
		if player.Parent then
			treadmillEvent:FireClient(player, "stop", 0)
		end
	end
	if player.Parent then
		portableEvent:FireClient(player, "removed")
	end

	local model = portable.model
	if instant or not model.Parent then
		model:Destroy()
		return
	end
	local current = model:GetScale()
	animateScale(model, current, math.max(current * 0.05, 0.01), 0.25, function()
		model:Destroy()
	end)
end

local function spawnPortable(player: Player)
	if portables[player] then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	-- Zaten bir bandin ustundeyse ust uste bindirme (cift XP) yok
	for _, t in ipairs(treadmills) do
		if isOnTreadmill(root, t.att0, t.att1) then
			portableEvent:FireClient(player, "blocked")
			return
		end
	end

	local mult = getBestOwnedMultiplier(player)
	local template = mult and templates[mult]
	local tAtt0 = template and template:FindFirstChild("Attachment0")
	local tAtt1 = template and template:FindFirstChild("Attachment1")
	if not (tAtt0 and tAtt1) then
		return
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {character}
	local ray = workspace:Raycast(root.Position, Vector3.new(0, -60, 0), rayParams)
	local groundY = ray and ray.Position.Y or (root.Position.Y - 3)

	-- Bant yonunu oyuncunun baktigi yone cevir
	local origPivot = template:GetPivot()
	local a0w, a1w = tAtt0.WorldPosition, tAtt1.WorldPosition
	local beltDir = (a1w - a0w) * Vector3.new(1, 0, 1)
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	local function yawOf(v: Vector3)
		return math.atan2(-v.X, -v.Z)
	end
	local deltaYaw = 0
	if beltDir.Magnitude > 0.01 and look.Magnitude > 0.01 then
		deltaYaw = yawOf(look.Unit) - yawOf(beltDir.Unit)
	end
	local rotation = CFrame.Angles(0, deltaYaw, 0) * origPivot.Rotation

	-- ScaleTo mutlak scale alir; hedef, sablonun mevcut scale'i uzerinden oranlanir
	local sizeFactor = 1
	local beltLen = (a1w - a0w).Magnitude
	if beltLen > 0.1 then
		sizeFactor = getReferenceBeltLength() / beltLen
	end
	local targetScale = template:GetScale() * sizeFactor

	-- Bant orta noktasi oyuncunun altindaki zemine gelsin
	local midLocal = origPivot:PointToObjectSpace((a0w + a1w) / 2) * sizeFactor
	local targetMid = Vector3.new(root.Position.X, groundY + 0.15, root.Position.Z)
	local pivotPos = targetMid - rotation:PointToWorldSpace(midLocal)

	local clone = template:Clone()
	clone.Name = "PortableTreadmill_" .. player.UserId
	clone:PivotTo(CFrame.new(pivotPos) * rotation)
	pcall(clone.ScaleTo, clone, math.max(targetScale * 0.1, 0.01))
	clone.Parent = workspace

	portables[player] = {
		model = clone,
		multiplier = mult,
		att0 = clone:FindFirstChild("Attachment0"),
		att1 = clone:FindFirstChild("Attachment1"),
		offZone = 0,
	}
	portableEvent:FireClient(player, "spawned", mult)
	animateScale(clone, targetScale * 0.1, targetScale, 0.35)
end

portableEvent.OnServerEvent:Connect(function(player)
	local now = os.clock()
	if portableDebounce[player] and now - portableDebounce[player] < PORTABLE_DEBOUNCE then
		return
	end
	portableDebounce[player] = now
	if portables[player] then
		despawnPortable(player)
	else
		spawnPortable(player)
	end
end)

-- Oyuncu takibi ----------------------------------------------------------

local function onPlayerAdded(player: Player)
	playerTimers[player] = 0
	player.CharacterAdded:Connect(function()
		despawnPortable(player, true)
	end)
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

Players.PlayerRemoving:Connect(function(player)
	despawnPortable(player, true)
	playerTimers[player] = nil
	playerOnTreadmill[player] = nil
	portableDebounce[player] = nil
end)

-- Ana dongu: oyuncu ayni anda tek treadmill'den XP alir; kendi portable'i
-- oncelikli, baskasinin portable'i hic sayilmaz.
RunService.Heartbeat:Connect(function(dt)
	for _, player in ipairs(Players:GetPlayers()) do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root then
			continue
		end

		local active = nil
		local portable = portables[player]
		if portable and portable.att0 and portable.att1 and portable.model.Parent
			and isOnTreadmill(root, portable.att0, portable.att1) then
			active = portable
			portable.offZone = 0
		else
			for _, t in ipairs(treadmills) do
				if isOnTreadmill(root, t.att0, t.att1) then
					active = t
					break
				end
			end
			if portable then
				portable.offZone += dt
				if portable.offZone >= OFFZONE_DESPAWN_TIME then
					despawnPortable(player)
				end
			end
		end

		if not active then
			if playerOnTreadmill[player] then
				playerOnTreadmill[player] = nil
				treadmillEvent:FireClient(player, "stop", 0)
			end
			playerTimers[player] = 0
			continue
		end

		local requiredPass = TREADMILL_PASSES[active.multiplier]
		if requiredPass and not GamePassCache.PlayerOwnsGamePass(player, requiredPass) then
			if playerOnTreadmill[player] then
				playerOnTreadmill[player] = nil
				treadmillEvent:FireClient(player, "stop", 0)
			end
			playerTimers[player] = 0
			treadmillEvent:FireClient(player, "locked", active.multiplier, requiredPass)
			continue
		end

		if playerOnTreadmill[player] ~= active then
			playerOnTreadmill[player] = active
			treadmillEvent:FireClient(player, "start", active.multiplier)
		end

		playerTimers[player] = (playerTimers[player] or 0) + dt
		if playerTimers[player] >= XP_TICK then
			playerTimers[player] = 0
			treadmillEvent:FireClient(player, "xp", active.multiplier)
		end
	end
end)

-- Gamepass alinir alinmaz treadmill calissin
local treadmillPassSet = {}
for _, passId in pairs(TREADMILL_PASSES) do
	treadmillPassSet[passId] = true
end
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if purchased and treadmillPassSet[passId] then
		GamePassCache.SetOwned(player, passId, true)
	end
end)
