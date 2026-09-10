-- TrailSystem
-- Trail sahipligi/equip CosmeticSystem'de; bu dosya sadece Trail gorselini uygular.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrailData = require(ReplicatedStorage:WaitForChild("TrailData"))
local CosmeticSystem = require(script.Parent.CosmeticSystem)

local FX_NAMES = {"_TrailFx", "_TrailAtt0", "_TrailAtt1"}

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
	ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 140, 0)),
	ColorSequenceKeypoint.new(0.34, Color3.fromRGB(255, 235, 0)),
	ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 200, 80)),
	ColorSequenceKeypoint.new(0.66, Color3.fromRGB(0, 140, 255)),
	ColorSequenceKeypoint.new(0.83, Color3.fromRGB(110, 60, 255)),
	ColorSequenceKeypoint.new(1.00, Color3.fromRGB(200, 60, 220)),
})

-- Tek renkten acik -> ana -> koyu uc tonlu sekans
local function threeToneSequence(base: Color3): ColorSequence
	local light = base:Lerp(Color3.new(1, 1, 1), 0.45)
	local dark = base:Lerp(Color3.new(0, 0, 0), 0.45)
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0.00, light),
		ColorSequenceKeypoint.new(0.30, light),
		ColorSequenceKeypoint.new(0.38, base),
		ColorSequenceKeypoint.new(0.62, base),
		ColorSequenceKeypoint.new(0.70, dark),
		ColorSequenceKeypoint.new(1.00, dark),
	})
end

local function clearVisual(root: BasePart)
	for _, name in ipairs(FX_NAMES) do
		local existing = root:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
	end
end

local function applyVisual(player: Player, trail)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	clearVisual(root)
	if not trail then
		return
	end

	local att0 = Instance.new("Attachment")
	att0.Name = "_TrailAtt0"
	att0.Position = Vector3.new(-1.5, 0.4, 0)
	att0.Parent = root

	local att1 = Instance.new("Attachment")
	att1.Name = "_TrailAtt1"
	att1.Position = Vector3.new(1.5, 0.4, 0)
	att1.Parent = root

	local fx = Instance.new("Trail")
	fx.Name = "_TrailFx"
	fx.Attachment0 = att0
	fx.Attachment1 = att1
	fx.Color = if trail.id == "trail5" then RAINBOW else threeToneSequence(trail.color)
	fx.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	fx.Lifetime = 0.8
	fx.MinLength = 0.05
	fx.WidthScale = NumberSequence.new(1, 0)
	fx.FaceCamera = true
	fx.Parent = root
end

CosmeticSystem.new({
	name = "Trail",
	definitions = TrailData,
	storePrefix = "trails_",
	attribute = "EquippedTrail",
	applyVisual = applyVisual,
})
