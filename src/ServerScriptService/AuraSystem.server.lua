-- AuraSystem
-- Aura sahipligi/equip CosmeticSystem'de; bu dosya sadece gorseli uygular.
-- Efekt sablonlari ReplicatedStorage altinda durur, karaktere klonlanir ve
-- server'da olusturuldugu icin tum oyunculara replike olur.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AuraData = require(ReplicatedStorage:WaitForChild("AuraData"))
local CosmeticSystem = require(script.Parent.CosmeticSystem)

local FX_TAG = "_AuraFxPart"

local TEMPLATES = {
	aura1 = ReplicatedStorage:WaitForChild("AuraEffectTemplate"),
	aura2 = ReplicatedStorage:WaitForChild("WindAuraEffectTemplate"),
	aura3 = ReplicatedStorage:WaitForChild("WaterAuraEffectTemplate"),
	aura4 = ReplicatedStorage:WaitForChild("FireAuraEffectTemplate"),
	aura5 = ReplicatedStorage:WaitForChild("ElectricAuraEffectTemplate"),
}

-- Sablonlar kendi temalarina gore boyandigi icin renk override edilmez.
-- Yeni bir aura eklenirken tint istenirse buraya false yazilir.
local KEEP_TEMPLATE_COLOR = {
	aura1 = true,
	aura2 = true,
	aura3 = true,
	aura4 = true,
	aura5 = true,
}

local function tint(instance: Instance, color: Color3)
	local targets = instance:GetDescendants()
	table.insert(targets, instance)
	for _, obj in ipairs(targets) do
		if obj:IsA("ParticleEmitter") or obj:IsA("Beam") then
			obj.Color = ColorSequence.new(color)
		elseif obj:IsA("PointLight") then
			obj.Color = color
		end
	end
end

local function clearVisual(character: Model)
	for _, part in ipairs(character:GetChildren()) do
		if part:IsA("BasePart") then
			for _, child in ipairs(part:GetChildren()) do
				if child:GetAttribute(FX_TAG) then
					child:Destroy()
				end
			end
		end
	end
end

local function applyVisual(player: Player, aura)
	local character = player.Character
	if not character then
		return
	end
	clearVisual(character)
	if not aura then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	local template = TEMPLATES[aura.id]
	if not (root and template) then
		return
	end

	-- Parcada "TargetPart" attribute'u varsa o vucut parcasina, yoksa root'a baglanir
	for _, piece in ipairs(template:GetChildren()) do
		local clone = piece:Clone()
		clone:SetAttribute(FX_TAG, true)
		if not KEEP_TEMPLATE_COLOR[aura.id] then
			tint(clone, aura.color)
		end

		local targetName = clone:GetAttribute("TargetPart")
		local target = targetName and character:FindFirstChild(targetName) or root
		if target then
			clone.Parent = target
		else
			clone:Destroy()
		end
	end
end

CosmeticSystem.new({
	name = "Aura",
	definitions = AuraData,
	storePrefix = "auras_",
	attribute = "EquippedAura",
	applyVisual = applyVisual,
})
