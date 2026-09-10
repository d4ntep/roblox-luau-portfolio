-- PerkColorClient
-- winperks.perky1..8 partlarini bu oyuncunun durumuna gore boyar (kilitli /
-- acik / aktif). Partlar sunucuda ortak oldugu icin renk client'ta degistirilir;
-- boylece her oyuncu ayni partlari kendi durumuna gore gorur.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local player = Players.LocalPlayer
local winperks = workspace:WaitForChild("winperks")

local COLOR_LOCKED = Color3.fromRGB(255, 176, 0)
local COLOR_UNLOCKED = Color3.fromRGB(100, 220, 100)
local COLOR_ACTIVE = Color3.fromRGB(0, 140, 0)

local perkyParts = {}
for i = 1, #GameConfig.PERK_WINS do
	perkyParts[i] = winperks:WaitForChild("perky" .. i, 10)
end

local winsStat = player:WaitForChild("leaderstats"):WaitForChild("Wins")
local activeTierStat = player:WaitForChild("ActivePerkTier")

local function updateColors()
	for i, part in pairs(perkyParts) do
		if winsStat.Value < GameConfig.PERK_WINS[i] then
			part.Color = COLOR_LOCKED
		elseif i == activeTierStat.Value then
			part.Color = COLOR_ACTIVE
		else
			part.Color = COLOR_UNLOCKED
		end
	end
end

winsStat.Changed:Connect(updateColors)
activeTierStat.Changed:Connect(updateColors)
updateColors()
