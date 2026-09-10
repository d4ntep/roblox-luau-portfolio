-- TrophyGamePassSystem
-- workspace.trophy uzerindeki ProximityPrompt 2X Win gamepass'ini sunar.
-- Sahiplik "Owns2XWinPass" attribute'u ile client'a replike edilir.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GamePassIds = require(ReplicatedStorage:WaitForChild("GamePassIds"))
local GamePassCache = require(script.Parent.GamePassCache)

local PASS_ID = GamePassIds.WIN_MULTIPLIER_2X

local trophy = workspace:WaitForChild("trophy")
local part = if trophy:IsA("BasePart") then trophy else trophy:FindFirstChildWhichIsA("BasePart", true)

if part then
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "WinMultiplierPrompt"
	prompt.ActionText = "2X Win!"
	prompt.ObjectText = "Trophy"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompt.Triggered:Connect(function(player)
		MarketplaceService:PromptGamePassPurchase(player, PASS_ID)
	end)
else
	warn("[TrophyGamePassSystem] trophy icinde BasePart yok")
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if purchased and passId == PASS_ID then
		GamePassCache.SetOwned(player, passId, true)
		player:SetAttribute("Owns2XWinPass", true)
	end
end)

local function checkOwnership(player: Player)
	player:SetAttribute("Owns2XWinPass", false)
	task.spawn(function()
		if GamePassCache.PlayerOwnsGamePass(player, PASS_ID) then
			player:SetAttribute("Owns2XWinPass", true)
		end
	end)
end

Players.PlayerAdded:Connect(checkOwnership)
for _, player in ipairs(Players:GetPlayers()) do
	checkOwnership(player)
end
