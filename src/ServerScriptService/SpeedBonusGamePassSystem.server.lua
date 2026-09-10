-- SpeedBonusGamePassSystem
-- 12 sirali gamepass; her biri Speed carpanini ikiye katlar. Client butona
-- basinca sunucu siradaki (sahip olunmayan ilk) pass icin prompt acar.
-- Sahip olunan sayi ve siradaki fiyat Player attribute'u olarak replike edilir.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local GamePassIds = require(ReplicatedStorage:WaitForChild("GamePassIds"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local GamePassCache = require(script.Parent.GamePassCache)
local ServerRegistry = require(script.Parent.ServerRegistry)

local PASSES = GamePassIds.SPEED_BONUS_PASSES
local requestPurchaseEvent = Remotes.event("RequestSpeedBonusPurchase")

local passSet = {}
for _, passId in ipairs(PASSES) do
	passSet[passId] = true
end

-- Roblox sayfasindan sirasiz alinabilecegi icin sayarak bulunur
local function countOwned(player: Player): number
	local count = 0
	for _, passId in ipairs(PASSES) do
		if passId ~= 0 and GamePassCache.PlayerOwnsGamePass(player, passId) then
			count += 1
		end
	end
	return count
end

local priceCache: {[number]: number | false} = {}
local function getPassPrice(passId: number): number?
	if priceCache[passId] ~= nil then
		return priceCache[passId] or nil
	end
	local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, passId, Enum.InfoType.GamePass)
	if ok and info and info.PriceInRobux then
		priceCache[passId] = info.PriceInRobux
		return info.PriceInRobux
	end
	priceCache[passId] = false
	return nil
end

local function refresh(player: Player)
	local owned = countOwned(player)
	player:SetAttribute("SpeedBonusOwned", owned)
	local nextPass = PASSES[owned + 1]
	if nextPass and nextPass ~= 0 then
		task.spawn(function()
			player:SetAttribute("SpeedBonusNextPrice", getPassPrice(nextPass) or 0)
		end)
	else
		player:SetAttribute("SpeedBonusNextPrice", 0)
	end
end

ServerRegistry.addMultiplierSource("SpeedBonus", function(player)
	return GameConfig.getGamepassSpeedMultiplier(player:GetAttribute("SpeedBonusOwned") or 0)
end)

Players.PlayerAdded:Connect(function(player)
	task.spawn(refresh, player)
end)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(refresh, player)
end

requestPurchaseEvent.OnServerEvent:Connect(function(player)
	local owned = player:GetAttribute("SpeedBonusOwned") or countOwned(player)
	local nextPass = PASSES[owned + 1]
	if nextPass and nextPass ~= 0 then
		MarketplaceService:PromptGamePassPurchase(player, nextPass)
	end
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if purchased and passSet[passId] then
		GamePassCache.SetOwned(player, passId, true)
		refresh(player)
	end
end)
