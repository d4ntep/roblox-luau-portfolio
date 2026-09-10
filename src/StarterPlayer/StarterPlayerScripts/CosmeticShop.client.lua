-- CosmeticShop
-- inventorygui icindeki aura ve trail sekmeleri. Kartlar Studio'da elle
-- tasarlanmistir (auratab.ItemGrid.aura1..5, trailstab.ItemGrid.trail1..5);
-- bu script fiyatlari yazar, sahiplik/equip durumunu gunceller ve butonlari baglar.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AuraData = require(ReplicatedStorage:WaitForChild("AuraData"))
local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local TrailData = require(ReplicatedStorage:WaitForChild("TrailData"))

local player = Players.LocalPlayer
local menuFrame = player:WaitForChild("PlayerGui"):WaitForChild("inventorygui"):WaitForChild("menu")

local STROKE_EQUIPPED = Color3.fromRGB(80, 220, 120)
local STROKE_DEFAULT = Color3.fromRGB(0, 0, 0)

local function setupTab(config)
	local grid = menuFrame:WaitForChild(config.tab):WaitForChild("ItemGrid")
	local buyEvent = Remotes.event("Buy" .. config.name)
	local equipEvent = Remotes.event("Equip" .. config.name)
	local syncEvent = Remotes.event("Sync" .. config.name)

	local owned = {}
	local equipped = ""
	local wired = {} -- card -> true (butonlar bir kez baglanir)

	local function refreshCard(def)
		local card = grid:FindFirstChild(def.id)
		if not card then
			warn("[CosmeticShop] Kart yok: " .. def.id)
			return
		end
		local isOwned = owned[def.id] == true
		local isEquipped = equipped == def.id

		local winFrame = card:FindFirstChild("winbuy")
		local robuxFrame = card:FindFirstChild("robuxbuy")
		local equipFrame = card:FindFirstChild("equip")
		local winBtn = winFrame and winFrame:FindFirstChild("winbuy")
		local robuxBtn = robuxFrame and robuxFrame:FindFirstChild("robuxbuy")
		local equipBtn = equipFrame and equipFrame:FindFirstChild("equip")

		local stroke = card:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if isEquipped then STROKE_EQUIPPED else STROKE_DEFAULT
		end
		if winFrame then
			winFrame.Visible = not isOwned
		end
		if robuxFrame then
			robuxFrame.Visible = not isOwned
		end
		if equipFrame then
			equipFrame.Visible = isOwned
		end

		local winPrice = winBtn and winBtn:FindFirstChild("price")
		if winPrice then
			winPrice.Text = NumberFormat.compact(def.winsPrice)
		end
		local robuxPrice = robuxBtn and robuxBtn:FindFirstChild("price")
		if robuxPrice then
			robuxPrice.Text = tostring(def.robuxPrice)
		end
		local equipLabel = equipBtn and equipBtn:FindFirstChild("equip")
		if equipLabel then
			equipLabel.Text = if isEquipped then "Equipped" else "Equip"
		end

		if wired[card] then
			return
		end
		wired[card] = true
		if winBtn then
			winBtn.MouseButton1Click:Connect(function()
				buyEvent:FireServer(def.id)
			end)
		end
		if robuxBtn then
			robuxBtn.MouseButton1Click:Connect(function()
				if def.robuxId and def.robuxId ~= 0 then
					MarketplaceService:PromptGamePassPurchase(player, def.robuxId)
				end
			end)
		end
		if equipBtn then
			equipBtn.MouseButton1Click:Connect(function()
				equipEvent:FireServer(if equipped == def.id then "" else def.id)
			end)
		end
	end

	local function refreshAll()
		for _, def in ipairs(config.data) do
			refreshCard(def)
		end
	end

	syncEvent.OnClientEvent:Connect(function(newOwned, newEquipped)
		owned = newOwned or {}
		equipped = newEquipped or ""
		refreshAll()
	end)
	refreshAll()
end

setupTab({name = "Aura", tab = "auratab", data = AuraData})
setupTab({name = "Trail", tab = "trailstab", data = TrailData})
