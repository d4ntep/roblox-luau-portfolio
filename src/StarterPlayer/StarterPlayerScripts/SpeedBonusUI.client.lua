-- SpeedBonusUI
-- speedbonus GUI: siradaki Speed Bonus gamepass'inin carpani ve fiyati.
-- Sahiplik ve fiyat sunucudan attribute olarak gelir; tiklama sadece
-- "siradakini sun" istegi gonderir.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local GamePassIds = require(ReplicatedStorage:WaitForChild("GamePassIds"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local MAX_PASSES = #GamePassIds.SPEED_BONUS_PASSES
local requestPurchaseEvent = Remotes.event("RequestSpeedBonusPurchase")

local gui = player:WaitForChild("PlayerGui"):WaitForChild("speedbonus")
local buyButton = gui:WaitForChild("menu"):WaitForChild("bonusbuy")
local speedLabel = buyButton:WaitForChild("speedx")
local priceLabel = gui:WaitForChild("price")

local function update()
	local owned = player:GetAttribute("SpeedBonusOwned") or 0
	if owned >= MAX_PASSES then
		speedLabel.Text = "Max Speed"
		priceLabel.Visible = false
		return
	end
	speedLabel.Text = GameConfig.getGamepassSpeedMultiplier(owned + 1) .. "X Speed"
	local price = player:GetAttribute("SpeedBonusNextPrice") or 0
	priceLabel.Text = "Only " .. price
	priceLabel.Visible = price > 0
end

player:GetAttributeChangedSignal("SpeedBonusOwned"):Connect(update)
player:GetAttributeChangedSignal("SpeedBonusNextPrice"):Connect(update)
update()

buyButton.MouseButton1Click:Connect(function()
	requestPurchaseEvent:FireServer()
end)
