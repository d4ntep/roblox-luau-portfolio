-- TrailData
-- Trail tanimlari. AuraData ile ayni yapi.

local TrailData = {
	{
		id = "trail1",
		name = "GreenTrail",
		multiplier = 1.5,
		winsPrice = 500,
		robuxPrice = 19,
		robuxId = 1918436288,
		color = Color3.fromRGB(90, 220, 100),
	},
	{
		id = "trail2",
		name = "BlueTrail",
		multiplier = 2.0,
		winsPrice = 1500,
		robuxPrice = 29,
		robuxId = 1918982284,
		color = Color3.fromRGB(80, 160, 255),
	},
	{
		id = "trail3",
		name = "PurpleTrail",
		multiplier = 3.0,
		winsPrice = 5000,
		robuxPrice = 59,
		robuxId = 1918268303,
		color = Color3.fromRGB(170, 90, 230),
	},
	{
		id = "trail4",
		name = "RedTrail",
		multiplier = 4.0,
		winsPrice = 25000,
		robuxPrice = 139,
		robuxId = 1917584311,
		color = Color3.fromRGB(230, 60, 60),
	},
	{
		id = "trail5",
		name = "RainbowTrail",
		multiplier = 5.0,
		winsPrice = 100000,
		robuxPrice = 249,
		robuxId = 1918706294,
		color = Color3.fromRGB(255, 200, 60),
	},
}

local byId = {}
for _, trail in ipairs(TrailData) do
	byId[trail.id] = trail
end

function TrailData.getById(id)
	return byId[id]
end

return TrailData
