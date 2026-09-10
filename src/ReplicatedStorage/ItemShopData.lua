-- ItemShopData
-- Item Shop konfigurasyonu: havuzlar, rarity temalari, sans dagilimi, stok ve fiyat.
-- Yeni item eklemek icin ilgili rarity havuzuna bir satir eklemek yeterli.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))

local ItemShopData = {}

-- Restock araligi (saniye)
ItemShopData.RESTOCK_INTERVAL = 300

-- Robux ile aninda restock urunu
ItemShopData.RESTOCK_PRODUCT_ID = 3609160817

-- Ayni anda takili olabilecek maksimum item sayisi
ItemShopData.EQUIP_LIMIT = 10

-- Slot4 rarity sans dagilimi (toplam 100 olmali)
ItemShopData.SLOT4_CHANCES = {
	{ rarity = "Epic",      chance = 85 },
	{ rarity = "Legendary", chance = 10 },
	{ rarity = "Mythic",    chance = 5  },
}

-- Rarity temalari (slot4 bunlara gore boyanir, slot1-3 sabit tasarim)
ItemShopData.RarityThemes = {
	Common = {
		bg          = "rbxassetid://107086487756128",
		strokeColor = Color3.fromRGB(56, 56, 56),
		textColor   = Color3.fromRGB(255, 255, 255),
	},
	Uncommon = {
		bg          = "rbxassetid://80253910553158",
		strokeColor = Color3.fromRGB(0, 90, 36),
		textColor   = Color3.fromRGB(41, 222, 0),
	},
	Rare = {
		bg          = "rbxassetid://136042130293819",
		strokeColor = Color3.fromRGB(0, 67, 108),
		textColor   = Color3.fromRGB(1, 103, 255),
	},
	Epic = {
		bg          = "rbxassetid://114437786883187",
		strokeColor = Color3.fromRGB(88, 44, 141),
		textColor   = Color3.fromRGB(190, 120, 255),
		-- Kenarlik gradient tonlari
		gradient = {
			Color3.fromRGB(74, 44, 109),
			Color3.fromRGB(139, 95, 191),
			Color3.fromRGB(201, 168, 232),
		},
	},
	Legendary = {
		bg          = "rbxassetid://79498815080620",
		strokeColor = Color3.fromRGB(196, 142, 26),
		textColor   = Color3.fromRGB(255, 196, 56),
		gradient = {
			Color3.fromRGB(186, 128, 20),
			Color3.fromRGB(255, 190, 60),
			Color3.fromRGB(255, 235, 165),
		},
	},
	Mythic = {
		bg          = "rbxassetid://128973588280963",
		strokeColor = Color3.fromRGB(74, 38, 18),
		textColor   = Color3.fromRGB(255, 150, 90),
		gradient = {
			Color3.fromRGB(61, 30, 12),
			Color3.fromRGB(139, 82, 43),
			Color3.fromRGB(230, 180, 130),
		},
	},
}

-- Item havuzlari: restock'ta her rarity icin havuzdan rastgele secilir
ItemShopData.Items = {
	Common = {
		{
			id = "VanillaPudding", name = "Vanilla Pudding",
			icon = "rbxassetid://108650626753520",
			speedBonus = 3, winsPrice = 3000, robuxPrice = 49,
			productId = 3608989452, maxStock = 3,
		},
	},
	Uncommon = {
		{
			id = "MatchaPudding", name = "Matcha Pudding",
			icon = "rbxassetid://87889953590281",
			speedBonus = 5, winsPrice = 25000, robuxPrice = 89,
			productId = 3608989509, maxStock = 1,
		},
	},
	Rare = {
		{
			id = "BlueberryPudding", name = "Blueberry Pudding",
			icon = "rbxassetid://117171361946411",
			speedBonus = 10, winsPrice = 250000, robuxPrice = 179,
			productId = 3608989574, maxStock = 1,
		},
	},
	Epic = {
		{
			id = "LavenderPudding", name = "Lavender Pudding",
			icon = "rbxassetid://74563185090664",
			speedBonus = 15, winsPrice = 3500000, robuxPrice = 489,
			productId = 3608989626, maxStock = 1,
		},
	},
	Legendary = {
		{
			id = "HoneyPudding", name = "Honey Pudding",
			icon = "rbxassetid://120593571173607",
			speedBonus = 25, winsPrice = 10000000, robuxPrice = 750,
			productId = 3608989708, maxStock = 1,
		},
	},
	Mythic = {
		{
			id = "ZerasPudding", name = "Zera's Pudding",
			icon = "rbxassetid://139390654670161",
			speedBonus = 75, winsPrice = 100000000, robuxPrice = 1400,
			productId = 3608989756, maxStock = 1,
		},
	},
}

function ItemShopData.FindById(itemId)
	for rarity, pool in pairs(ItemShopData.Items) do
		for _, item in ipairs(pool) do
			if item.id == itemId then
				return item, rarity
			end
		end
	end
	return nil
end

function ItemShopData.FindByProductId(productId)
	for rarity, pool in pairs(ItemShopData.Items) do
		for _, item in ipairs(pool) do
			if item.productId == productId then
				return item, rarity
			end
		end
	end
	return nil
end

function ItemShopData.FormatNumber(n)
	return NumberFormat.compact(n)
end

return ItemShopData
