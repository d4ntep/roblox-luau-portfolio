-- GraphicsSettings
-- Dusuk/Yuksek grafik toggle: golgeler, post-processing, particle'lar,
-- materyaller ve streaming yaricapi.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local player = Players.LocalPlayer

local playerGui = player:WaitForChild("PlayerGui")
local graphicsGui = playerGui:WaitForChild("graphics")
local button = graphicsGui:WaitForChild("button")
local icon = button:WaitForChild("icon")
local iconlow = button:WaitForChild("iconlow")

local COOLDOWN = 1
local lastToggleTime = 0
local isLowGraphics = false

-- Tiklanabilir overlay ekle (button bir Frame oldugu icin dogrudan tiklama algilamiyor)
local overlay = Instance.new("TextButton")
overlay.Name = "_ToggleOverlay"
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundTransparency = 1
overlay.Text = ""
overlay.ZIndex = 999
overlay.Parent = button

-- Orijinal Lighting degerlerini sakla (Yuksek moda donerken geri yuklemek icin)
local originalLighting = {
	GlobalShadows = Lighting.GlobalShadows,
	ShadowSoftness = Lighting.ShadowSoftness,
	Brightness = Lighting.Brightness,
	EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
	EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
}

local originalStreamingTargetRadius = workspace.StreamingTargetRadius
local originalPostEffectStates = {}

-- Her efekti ilk goruldugu andaki durumuyla kaydet. Boylece yuksek moda
-- donerken baslangicta kapali olan DepthOfField/Blur gibi efektler acilmaz.
local function rememberPostEffect(effect)
	if effect:IsA("PostEffect") and originalPostEffectStates[effect] == nil then
		originalPostEffectStates[effect] = effect.Enabled
	end
end

for _, effect in ipairs(Lighting:GetChildren()) do
	rememberPostEffect(effect)
end

Lighting.ChildAdded:Connect(rememberPostEffect)

-- Post-processing efektlerini (Bloom, ColorCorrection, Blur, vb.) bul
local function getPostEffects()
	local effects = {}
	for _, e in ipairs(Lighting:GetChildren()) do
		if e:IsA("PostEffect") then
			table.insert(effects, e)
		end
	end
	return effects
end

-- Karakterdeki tum ParticleEmitter'lari (aura/trail efektleri dahil) etkiler
local function setCharacterParticlesEnabled(enabled)
	local char = player.Character
	if not char then return end
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("ParticleEmitter") or d:IsA("Beam") then
			d.Enabled = enabled
		end
	end
end

-- Tum oyuncularin karakterlerindeki particle/beam'ler
local function setAllPlayersParticlesEnabled(enabled)
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			for _, d in ipairs(p.Character:GetDescendants()) do
				if d:IsA("ParticleEmitter") or d:IsA("Beam") then
					d.Enabled = enabled
				end
			end
		end
	end
end

-- Harita materyallerini SmoothPlastic'e cevirme / geri yukleme
local originalMaterials = {}
local materialsSwapped = false

local function applyLowMaterials()
	if materialsSwapped then return end
	materialsSwapped = true
	for _, part in ipairs(workspace:GetDescendants()) do
		if part:IsA("BasePart") and part.Material ~= Enum.Material.SmoothPlastic then
			originalMaterials[part] = part.Material
			part.Material = Enum.Material.SmoothPlastic
		end
	end
end

local function restoreMaterials()
	if not materialsSwapped then return end
	materialsSwapped = false
	for part, mat in pairs(originalMaterials) do
		if part and part.Parent then
			part.Material = mat
		end
	end
	originalMaterials = {}
end

local function applyLowGraphics()
	-- Golgeler
	Lighting.GlobalShadows = false
	Lighting.ShadowSoftness = 1

	-- Post-processing efektlerini kapat
	for _, e in ipairs(getPostEffects()) do
		e.Enabled = false
	end

	-- Aura/Trail particle'larini kapat (kendi karakterin + diger oyuncularin)
	setAllPlayersParticlesEnabled(false)

	-- Haritadaki materyalleri duz/hafif SmoothPlastic'e cevir
	applyLowMaterials()

	pcall(function()
		workspace.StreamingTargetRadius = 250
	end)
end

local function applyHighGraphics()
	-- Golgeleri eski haline getir
	Lighting.GlobalShadows = originalLighting.GlobalShadows
	Lighting.ShadowSoftness = originalLighting.ShadowSoftness

	-- Post-processing efektlerini baslangictaki durumlarina getir
	for _, e in ipairs(getPostEffects()) do
		local wasEnabled = originalPostEffectStates[e]
		if wasEnabled ~= nil then
			e.Enabled = wasEnabled
		end
	end

	-- Particle'lari geri ac
	setAllPlayersParticlesEnabled(true)

	-- Materyalleri eski haline getir
	restoreMaterials()

	pcall(function()
		workspace.StreamingTargetRadius = originalStreamingTargetRadius
	end)
end

local function updateIcons()
	icon.Visible = not isLowGraphics
	iconlow.Visible = isLowGraphics
end

local function toggleGraphics()
	local now = os.clock()
	if now - lastToggleTime < COOLDOWN then
		return
	end
	lastToggleTime = now

	isLowGraphics = not isLowGraphics
	updateIcons()

	if isLowGraphics then
		applyLowGraphics()
	else
		applyHighGraphics()
	end
end

overlay.MouseButton1Click:Connect(toggleGraphics)

-- Baslangicta normal (yuksek) grafik gorunumunde baslar
updateIcons()

-- Respawn'da yeni karakterin particle'lari da moda uysun
player.CharacterAdded:Connect(function()
	if isLowGraphics then
		task.wait(0.5) -- karakterin tum parcalari yuklensin
		setCharacterParticlesEnabled(false)
	end
end)

-- Sonradan katilan / respawn olan diger oyuncular icin de
Players.PlayerAdded:Connect(function(otherPlayer)
	otherPlayer.CharacterAdded:Connect(function(char)
		if isLowGraphics then
			task.wait(0.5)
			for _, d in ipairs(char:GetDescendants()) do
				if d:IsA("ParticleEmitter") or d:IsA("Beam") then
					d.Enabled = false
				end
			end
		end
	end)
end)
