-- WinCurrencyDisplay
-- wincurrency GUI'sindeki Win sayacini leaderstats ile senkron tutar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))

local player = Players.LocalPlayer
local winLabel = player:WaitForChild("PlayerGui"):WaitForChild("wincurrency"):WaitForChild("Frame"):WaitForChild("win")
local winsStat = player:WaitForChild("leaderstats"):WaitForChild("Wins")

local function update()
	winLabel.Text = NumberFormat.abbreviate(winsStat.Value)
end

update()
winsStat.Changed:Connect(update)
