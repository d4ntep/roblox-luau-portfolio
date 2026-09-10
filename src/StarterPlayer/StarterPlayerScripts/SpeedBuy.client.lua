-- SpeedBuy
-- xpgui.xpbar uzerindeki 3percent / 8percent / 15percent butonlari: bulunulan
-- milestone'un yuzdesi kadar Speed satan Developer Product'lar.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local MenuController = require(ReplicatedStorage:WaitForChild("MenuController"))
local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))
local PlayerProgress = require(script.Parent:WaitForChild("PlayerProgress"))

local player = Players.LocalPlayer
local xpbar = player:WaitForChild("PlayerGui"):WaitForChild("xpgui"):WaitForChild("xpbar")

local BUTTON_NAMES = {"3percent", "8percent", "15percent"}
local buttons = {}
for i, name in ipairs(BUTTON_NAMES) do
	buttons[i] = xpbar:WaitForChild(name)
end

local function refreshLabels()
	local _, level = PlayerProgress.get()
	for i, frame in ipairs(buttons) do
		local label = frame:FindFirstChild("5percent")
		local amount = GameConfig.getSpeedBuyAmount(level, i)
		if label and amount then
			label.Text = "+" .. NumberFormat.abbreviate(amount) .. " Speed"
		end
	end
end

for i, frame in ipairs(buttons) do
	MenuController.addOverlay(frame, function()
		local tier = GameConfig.SPEED_BUY_TIERS[i]
		if tier and tier.productId ~= 0 then
			MarketplaceService:PromptProductPurchase(player, tier.productId)
		end
	end, {zIndex = 999})
end

PlayerProgress.Changed:Connect(refreshLabels)
refreshLabels()
