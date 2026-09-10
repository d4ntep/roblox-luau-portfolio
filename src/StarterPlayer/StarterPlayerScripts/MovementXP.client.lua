-- MovementXP
-- Kat edilen mesafeye gore XP (her STUD_PER_XP stud'da 1 taban XP) ve
-- treadmill XP tick'leri. Sunucu bu artislari kendi tavaniyla dogrular.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local PlayerProgress = require(script.Parent:WaitForChild("PlayerProgress"))

local player = Players.LocalPlayer
local treadmillEvent = Remotes.event("TreadmillXP")

local MAX_FRAME_DIST = 15 -- respawn / teleport sicramalari sayilmaz
local RUN_ANIMATION_ID = "rbxassetid://913376220"

-- Hareket -----------------------------------------------------------------

local lastPos: Vector3? = nil
local distanceAccum = 0

player.CharacterAdded:Connect(function()
	lastPos = nil
	distanceAccum = 0
end)

RunService.Heartbeat:Connect(function()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local pos = root.Position
	if not lastPos then
		lastPos = pos
		return
	end
	local delta = pos - lastPos
	lastPos = pos
	local horizontal = Vector3.new(delta.X, 0, delta.Z).Magnitude
	if horizontal >= MAX_FRAME_DIST then
		return
	end
	distanceAccum += horizontal
	while distanceAccum >= GameConfig.STUD_PER_XP do
		distanceAccum -= GameConfig.STUD_PER_XP
		PlayerProgress.addXP(1, "movement")
	end
end)

-- Treadmill --------------------------------------------------------------

local runTrack: AnimationTrack? = nil

local function startRunAnimation()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	if not runTrack then
		local animation = Instance.new("Animation")
		animation.AnimationId = RUN_ANIMATION_ID
		runTrack = animator:LoadAnimation(animation)
	end
	if not runTrack.IsPlaying then
		runTrack:Play()
	end
end

local function stopRunAnimation()
	if runTrack and runTrack.IsPlaying then
		runTrack:Stop()
	end
end

player.CharacterAdded:Connect(function()
	runTrack = nil
end)

local promptCooldown = false
treadmillEvent.OnClientEvent:Connect(function(action, multiplier, gamePassId)
	if action == "start" then
		startRunAnimation()
	elseif action == "stop" then
		stopRunAnimation()
	elseif action == "xp" then
		PlayerProgress.addXP(multiplier, "treadmill")
	elseif action == "locked" and gamePassId and not promptCooldown then
		promptCooldown = true
		pcall(MarketplaceService.PromptGamePassPurchase, MarketplaceService, player, gamePassId)
		task.delay(3, function()
			promptCooldown = false
		end)
	end
end)
