-- AuraData
-- Aura tanimlari. robuxId bir GamePass ID'sidir; robuxPrice sadece etiket icindir.

local AuraData = {
	{
		id = "aura1",
		name = "Glow Aura",
		multiplier = 1.2,
		winsPrice = 1000000,
		robuxPrice = 59,
		robuxId = 1917788367,
		color = Color3.fromRGB(120, 190, 255),
	},
	{
		id = "aura2",
		name = "Wind Aura",
		multiplier = 1.5,
		winsPrice = 5000000,
		robuxPrice = 249,
		robuxId = 1918274348,
		color = Color3.fromRGB(60, 220, 190),
	},
	{
		id = "aura3",
		name = "Water Aura",
		multiplier = 2.0,
		winsPrice = 10000000,
		robuxPrice = 489,
		robuxId = 1917614387,
		color = Color3.fromRGB(80, 170, 255),
	},
	{
		id = "aura4",
		name = "Fire Aura",
		multiplier = 4.0,
		winsPrice = 25000000,
		robuxPrice = 649,
		robuxId = 1917902343,
		color = Color3.fromRGB(100, 55, 30),
	},
	{
		id = "aura5",
		name = "Electric Aura",
		multiplier = 5.0,
		winsPrice = 50000000,
		robuxPrice = 799,
		robuxId = 1917686348,
		color = Color3.fromRGB(255, 220, 80),
	},
}

local byId = {}
for _, aura in ipairs(AuraData) do
	byId[aura.id] = aura
end

function AuraData.getById(id)
	return byId[id]
end

return AuraData
