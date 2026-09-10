-- ItemShopSystem
-- Sunucu geneli ortak stoklu, periyodik restock olan Item Shop.
-- Slot1-3 sabit rarity, slot4 sans ile Epic/Legendary/Mythic.
-- Satin alinan itemler oyuncunun envanterine ayri instance olarak eklenir;
-- takili itemlerin toplam bonusu XP carpani olarak ServerRegistry'ye verilir.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local GamePassIds = require(ReplicatedStorage:WaitForChild("GamePassIds"))
local ItemShopData = require(ReplicatedStorage:WaitForChild("ItemShopData"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local GamePassCache = require(script.Parent.GamePassCache)
local SafeStore = require(script.Parent.SafeStore)
local ServerRegistry = require(script.Parent.ServerRegistry)

local store = DataStoreService:GetDataStore(GameConfig.DATASTORE_NAME)

local getShopFunc = Remotes.func("GetItemShop")
local getInventoryFunc = Remotes.func("GetItemInventory")
local shopUpdatedEvent = Remotes.event("ItemShopUpdated")     -- server -> herkes: restock
local stockChangedEvent = Remotes.event("ItemShopStock")      -- server -> herkes: tek slot stok
local buyEvent = Remotes.event("BuyShopItem")                 -- client -> server: slotIndex (Win)
local promptRobuxEvent = Remotes.event("PromptShopRobux")     -- client -> server: slotIndex
local promptRestockEvent = Remotes.event("PromptShopRestock") -- client -> server
local shopResultEvent = Remotes.event("ShopPurchaseResult")   -- server -> client: ok, mesaj, slotIndex
local equipEvent = Remotes.event("EquipShopItem")             -- client -> server: uid
local inventoryEvent = Remotes.event("SendItemInventory")     -- server -> client: envanter paketi
local equipBestEvent = Remotes.event("EquipBestItems")
local unequipAllEvent = Remotes.event("UnequipAllItems")

local SAVE_THROTTLE = 6
local BULK_THROTTLE = 0.5
local FIXED_SLOTS = {"Common", "Uncommon", "Rare"}

-- Shop durumu -----------------------------------------------------------

local shop = {
	slots = {}, -- [1..4] = {rarity, itemId, currentStock, maxStock}
	nextRestockTime = 0,
}

local function rollSlot4Rarity(): string
	local roll = math.random(1, 100)
	local cumulative = 0
	for _, entry in ipairs(ItemShopData.SLOT4_CHANCES) do
		cumulative += entry.chance
		if roll <= cumulative then
			return entry.rarity
		end
	end
	return "Epic"
end

local function pickFromPool(rarity: string)
	local pool = ItemShopData.Items[rarity]
	if not pool or #pool == 0 then
		pool = ItemShopData.Items.Epic
		rarity = "Epic"
	end
	return pool[math.random(1, #pool)], rarity
end

local function generateShop()
	local slots = {}
	for i, rarity in ipairs(FIXED_SLOTS) do
		local item = pickFromPool(rarity)
		slots[i] = {rarity = rarity, itemId = item.id, currentStock = item.maxStock, maxStock = item.maxStock}
	end
	local item4, rarity4 = pickFromPool(rollSlot4Rarity())
	slots[4] = {rarity = rarity4, itemId = item4.id, currentStock = item4.maxStock, maxStock = item4.maxStock}
	shop.slots = slots
	shop.nextRestockTime = os.time() + ItemShopData.RESTOCK_INTERVAL
end

local function buildShopPacket()
	local packet = {slots = {}, nextRestockTime = shop.nextRestockTime}
	for i, slot in ipairs(shop.slots) do
		local def = ItemShopData.FindById(slot.itemId)
		packet.slots[i] = {
			rarity = slot.rarity,
			itemId = slot.itemId,
			name = def and def.name or "?",
			icon = def and def.icon or "",
			speedBonus = def and def.speedBonus or 0,
			winsPrice = def and def.winsPrice or 0,
			robuxPrice = def and def.robuxPrice or 0,
			currentStock = slot.currentStock,
			maxStock = slot.maxStock,
		}
	end
	return packet
end

-- Envanter --------------------------------------------------------------
-- inventories[userId] = { {uid, itemId, equipped}, ... }

local inventories: {[number]: {any}} = {}
local canSave: {[number]: boolean} = {}
local lastSave: {[number]: number} = {}
local lastBulk: {[number]: number} = {}

local function getEquipLimit(player: Player): number
	if GamePassCache.PlayerOwnsGamePass(player, GamePassIds.ITEM_SLOTS_20) then
		return 20
	end
	return ItemShopData.EQUIP_LIMIT
end

local function countEquipped(items): number
	local n = 0
	for _, item in ipairs(items) do
		if item.equipped then
			n += 1
		end
	end
	return n
end

local function getTotalBonus(player: Player): number
	local items = inventories[player.UserId]
	if not items then
		return 0
	end
	local total = 0
	for _, item in ipairs(items) do
		if item.equipped then
			local def = ItemShopData.FindById(item.itemId)
			total += def and def.speedBonus or 0
		end
	end
	return total
end

local function saveInventory(player: Player, force: boolean?)
	local items = inventories[player.UserId]
	if not items or not canSave[player.UserId] then
		return
	end
	local now = os.clock()
	if not force and lastSave[player.UserId] and now - lastSave[player.UserId] < SAVE_THROTTLE then
		return
	end
	lastSave[player.UserId] = now
	SafeStore.set(store, "items_" .. player.UserId, {items = items})
end

local function buildInventoryPacket(player: Player)
	local list = {}
	for _, item in ipairs(inventories[player.UserId] or {}) do
		local def = ItemShopData.FindById(item.itemId)
		if def then
			table.insert(list, {
				uid = item.uid,
				itemId = item.itemId,
				name = def.name,
				icon = def.icon,
				speedBonus = def.speedBonus,
				equipped = item.equipped == true,
			})
		end
	end
	return {items = list, equipLimit = getEquipLimit(player), totalBonus = getTotalBonus(player)}
end

-- Envanter degisince: attribute (client XP hesabi icin), paket ve kayit
local function commitInventory(player: Player, force: boolean?)
	player:SetAttribute("ItemXPBonus", getTotalBonus(player))
	inventoryEvent:FireClient(player, buildInventoryPacket(player))
	task.spawn(saveInventory, player, force)
end

local function grantItem(player: Player, itemId: string, force: boolean?): boolean
	local items = inventories[player.UserId]
	if not items then
		return false
	end
	table.insert(items, {
		uid = HttpService:GenerateGUID(false),
		itemId = itemId,
		equipped = countEquipped(items) < getEquipLimit(player),
	})
	commitInventory(player, force)
	return true
end

ServerRegistry.addMultiplierSource("Item", function(player)
	return 1 + getTotalBonus(player) / 100
end)

-- Satin alma: Win --------------------------------------------------------

buyEvent.OnServerEvent:Connect(function(player, slotIndex)
	if type(slotIndex) ~= "number" then
		return
	end
	slotIndex = math.floor(slotIndex)
	local slot = shop.slots[slotIndex]
	if not slot or not inventories[player.UserId] then
		return
	end
	if slot.currentStock <= 0 then
		shopResultEvent:FireClient(player, false, "Sold out!", slotIndex)
		return
	end
	local def = ItemShopData.FindById(slot.itemId)
	local leaderstats = player:FindFirstChild("leaderstats")
	local wins = leaderstats and leaderstats:FindFirstChild("Wins")
	if not (def and wins) then
		return
	end
	if wins.Value < def.winsPrice then
		shopResultEvent:FireClient(player, false, "Not enough Wins!", slotIndex)
		return
	end

	-- Kontrol ile dusurme arasinda yield yok; yaris durumu olusmaz
	slot.currentStock -= 1
	wins.Value -= def.winsPrice
	grantItem(player, def.id)
	stockChangedEvent:FireAllClients(slotIndex, slot.currentStock)
	shopResultEvent:FireClient(player, true, "Purchased!", slotIndex)
end)

-- Satin alma: Robux (stoktan bagimsiz) ------------------------------------

promptRobuxEvent.OnServerEvent:Connect(function(player, slotIndex)
	if type(slotIndex) ~= "number" then
		return
	end
	local slot = shop.slots[math.floor(slotIndex)]
	local def = slot and ItemShopData.FindById(slot.itemId)
	if def and def.productId and def.productId ~= 0 then
		MarketplaceService:PromptProductPurchase(player, def.productId)
	end
end)

promptRestockEvent.OnServerEvent:Connect(function(player)
	MarketplaceService:PromptProductPurchase(player, ItemShopData.RESTOCK_PRODUCT_ID)
end)

ServerRegistry.registerProduct(ItemShopData.RESTOCK_PRODUCT_ID, function(player)
	generateShop()
	shopUpdatedEvent:FireAllClients(buildShopPacket())
	shopResultEvent:FireClient(player, true, "Shop restocked!", 0)
	return true
end)

for _, pool in pairs(ItemShopData.Items) do
	for _, def in ipairs(pool) do
		ServerRegistry.registerProduct(def.productId, function(player)
			if not inventories[player.UserId] then
				return false -- veri henuz yuklenmedi, Roblox tekrar dener
			end
			grantItem(player, def.id, true)
			shopResultEvent:FireClient(player, true, "Purchased!", 0)
			return true
		end)
	end
end

-- Equip ----------------------------------------------------------------

equipEvent.OnServerEvent:Connect(function(player, uid)
	local items = inventories[player.UserId]
	if not items or type(uid) ~= "string" then
		return
	end
	for _, item in ipairs(items) do
		if item.uid == uid then
			if item.equipped then
				item.equipped = false
			else
				local limit = getEquipLimit(player)
				if countEquipped(items) >= limit then
					shopResultEvent:FireClient(player, false, "Equip limit reached (" .. limit .. ")", 0)
					return
				end
				item.equipped = true
			end
			commitInventory(player)
			return
		end
	end
end)

local function bulkAllowed(player: Player): boolean
	local now = os.clock()
	if lastBulk[player.UserId] and now - lastBulk[player.UserId] < BULK_THROTTLE then
		return false
	end
	lastBulk[player.UserId] = now
	return true
end

-- En yuksek bonuslu ilk N itemi tak, gerisini cikar
equipBestEvent.OnServerEvent:Connect(function(player)
	local items = inventories[player.UserId]
	if not items or not bulkAllowed(player) then
		return
	end
	local sorted = table.clone(items)
	table.sort(sorted, function(a, b)
		local defA = ItemShopData.FindById(a.itemId)
		local defB = ItemShopData.FindById(b.itemId)
		local bonusA = defA and defA.speedBonus or 0
		local bonusB = defB and defB.speedBonus or 0
		if bonusA ~= bonusB then
			return bonusA > bonusB
		end
		return a.uid < b.uid
	end)
	local limit = getEquipLimit(player)
	for i, item in ipairs(sorted) do
		item.equipped = i <= limit
	end
	commitInventory(player)
end)

unequipAllEvent.OnServerEvent:Connect(function(player)
	local items = inventories[player.UserId]
	if not items or not bulkAllowed(player) then
		return
	end
	for _, item in ipairs(items) do
		item.equipped = false
	end
	commitInventory(player)
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if purchased and passId == GamePassIds.ITEM_SLOTS_20 then
		GamePassCache.SetOwned(player, passId, true)
		inventoryEvent:FireClient(player, buildInventoryPacket(player))
	end
end)

getShopFunc.OnServerInvoke = function()
	return buildShopPacket()
end

getInventoryFunc.OnServerInvoke = function(player)
	return buildInventoryPacket(player)
end

-- Oyuncu giris/cikis -----------------------------------------------------

local function onPlayerAdded(player: Player)
	local ok, data = SafeStore.get(store, "items_" .. player.UserId)
	canSave[player.UserId] = ok
	local items = {}
	if type(data) == "table" and type(data.items) == "table" then
		items = data.items
	end
	inventories[player.UserId] = items
	player:SetAttribute("ItemXPBonus", getTotalBonus(player))
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	saveInventory(player, true)
	inventories[player.UserId] = nil
	canSave[player.UserId] = nil
	lastSave[player.UserId] = nil
	lastBulk[player.UserId] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		saveInventory(player, true)
	end
end)

-- Restock dongusu --------------------------------------------------------

generateShop()
task.spawn(function()
	while true do
		local remaining = shop.nextRestockTime - os.time()
		if remaining <= 0 then
			generateShop()
			shopUpdatedEvent:FireAllClients(buildShopPacket())
		else
			task.wait(math.min(remaining, 1))
		end
	end
end)
