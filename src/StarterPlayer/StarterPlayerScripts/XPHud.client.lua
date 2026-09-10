-- XPHud
-- xpgui uzerindeki XP cubugu, carpan panelleri, kazanc popup'lari ve
-- orta ekran anonslari (level up / win).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))
local PlayerProgress = require(script.Parent:WaitForChild("PlayerProgress"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

local leaderstats = player:WaitForChild("leaderstats")
local winsStat = leaderstats:WaitForChild("Wins")
local rebirthStat = leaderstats:WaitForChild("Rebirths")

local effects = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("sounds"):WaitForChild("effects")
local sfxLevelUp = effects:WaitForChild("levelup")
local sfxWin = effects:WaitForChild("rebirthup")

local xpbar = playerGui:WaitForChild("xpgui"):WaitForChild("xpbar")
local levelLabel = xpbar:WaitForChild("level")
local xpLabel = xpbar:WaitForChild("xp")
local speedLabel = xpbar:WaitForChild("speed")
local fillFrame = xpbar:WaitForChild("fill")

local leftPanel = xpbar:WaitForChild("leftStatsPanel")
local rightPanel = xpbar:WaitForChild("rightStatsPanel")
local itemBonusLabel = leftPanel:WaitForChild("stepBonus")
local gamepassLabel = leftPanel:WaitForChild("gamepassMult")
local cosmeticLabel = rightPanel:WaitForChild("auraMult")
local rebirthLabel = rightPanel:WaitForChild("rebirthMult")

local announcementGui = playerGui:WaitForChild("announcementgui")
local levelUpBanner = announcementGui:WaitForChild("LevelUpBanner")
local winBanner = announcementGui:WaitForChild("WinBanner")
levelUpBanner.Visible = false
winBanner.Visible = false

local function playOneShot(template: Sound)
	local clone = template:Clone()
	clone.Parent = workspace
	clone:Play()
	Debris:AddItem(clone, 3)
end

-- XP cubugu -------------------------------------------------------------

local function updateBar()
	local xp, level, totalXP = PlayerProgress.get()
	local required = PlayerProgress.getRequiredXP()
	levelLabel.Text = "Level " .. level
	xpLabel.Text = NumberFormat.abbreviate(xp) .. " / " .. NumberFormat.abbreviate(required)
	speedLabel.Text = NumberFormat.abbreviate(totalXP) .. " Speed"
	TweenService:Create(fillFrame, TweenInfo.new(0.2), {
		Size = UDim2.new(math.clamp(xp / required, 0, 1), 0, 1, 0),
	}):Play()
end

local function updateMultipliers()
	local parts = PlayerProgress.getMultiplierParts()
	itemBonusLabel.Text = "+" .. NumberFormat.abbreviate(player:GetAttribute("ItemXPBonus") or 0) .. "% Speed (Items)"
	gamepassLabel.Text = "Multiplier x" .. parts.gamepass .. " (Gamepass)"
	cosmeticLabel.Text = "Multiplier x" .. (parts.aura * parts.trail) .. " (Trail & Aura)"
	rebirthLabel.Text = "Multiplier x" .. NumberFormat.abbreviate(parts.rebirth) .. " (Rebirth)"
end

PlayerProgress.Changed:Connect(updateBar)
rebirthStat.Changed:Connect(updateMultipliers)
for _, attribute in ipairs({"ItemXPBonus", "SpeedBonusOwned", "EquippedAura", "EquippedTrail"}) do
	player:GetAttributeChangedSignal(attribute):Connect(updateMultipliers)
end
local perkTier = player:WaitForChild("ActivePerkTier", 10)
if perkTier then
	perkTier.Changed:Connect(updateMultipliers)
end
updateBar()
updateMultipliers()

-- Gamepass etiketinde donen RGB gradient
local gamepassGradient = gamepassLabel:FindFirstChildOfClass("UIGradient")
if gamepassGradient then
	local phase = 0
	RunService.Heartbeat:Connect(function(dt)
		phase = (phase + dt * 0.2) % 1
		local function hue(offset)
			return Color3.fromHSV((offset + phase) % 1, 0.85, 1)
		end
		gamepassGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, hue(0)),
			ColorSequenceKeypoint.new(0.25, hue(0.25)),
			ColorSequenceKeypoint.new(0.5, hue(0.5)),
			ColorSequenceKeypoint.new(0.75, hue(0.75)),
			ColorSequenceKeypoint.new(1, hue(0.99)),
		})
	end)
end

-- Kazanc popup'lari ------------------------------------------------------

local popupGui = Instance.new("ScreenGui")
popupGui.Name = "PopupGui"
popupGui.ResetOnSpawn = false
popupGui.DisplayOrder = 999
popupGui.IgnoreGuiInset = true
popupGui.Parent = playerGui

local MAX_POPUPS = 10
local POPUP_MIN_GAP = 0.12 -- hareket popup'lari icin minimum aralik
local POPUP_ICON = "rbxassetid://80881685658979"
local BASE_SIZE = 25
local REFERENCE_DIST = 12
local HEAD_OFFSET = Vector3.new(0, 2.6, 0)
local SCATTER_RADIUS = 2.2

local activePopups = 0
local lastMovementPopup = 0

local function easeOut(t)
	return 1 - (1 - t) ^ 3
end

local function showPopup(amount: number)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or activePopups >= MAX_POPUPS then
		return
	end
	activePopups += 1

	local text = "+" .. NumberFormat.abbreviate(amount)
	local iconWidth = BASE_SIZE * 1.7
	local textSize = TextService:GetTextSize(text, BASE_SIZE, Enum.Font.FredokaOne, Vector2.new(1000, BASE_SIZE * 1.4))
	local baseWidth = iconWidth + textSize.X + 10

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundTransparency = 1
	frame.ZIndex = 999

	local icon = Instance.new("ImageLabel")
	icon.Size = UDim2.new(0, iconWidth, 1, 0)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.fromScale(0, 0.5)
	icon.BackgroundTransparency = 1
	icon.Image = POPUP_ICON
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = frame

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -iconWidth, 1, 0)
	label.Position = UDim2.fromOffset(iconWidth, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(255, 245, 200)
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.ZIndex = 999
	label.Parent = frame
	frame.Parent = popupGui

	local offset = Vector3.new(
		(math.random() - 0.5) * SCATTER_RADIUS * 2,
		math.random() * 1.4 + 0.6,
		(math.random() - 0.5) * SCATTER_RADIUS * 2
	)

	local elapsed = 0
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		local t = math.clamp(elapsed, 0, 1)
		local rise = easeOut(math.clamp(t / 0.5, 0, 1))
		local worldPos = root.Position + HEAD_OFFSET + offset * rise
		local screenPos = camera:WorldToViewportPoint(worldPos)
		local dist = (camera.CFrame.Position - worldPos).Magnitude
		local scale = math.clamp(REFERENCE_DIST / math.max(dist, 2), 0.35, 2.4) * (if t <= 0.5 then rise else 1)

		frame.Size = UDim2.fromOffset(baseWidth * scale, BASE_SIZE * scale)
		frame.Position = UDim2.fromOffset(screenPos.X, screenPos.Y)
		if t > 0.7 then
			local fade = (t - 0.7) / 0.3
			label.TextTransparency = fade
			icon.ImageTransparency = fade
		end
		if t >= 1 then
			conn:Disconnect()
			frame:Destroy()
			activePopups -= 1
		end
	end)
end

PlayerProgress.XPEarned:Connect(function(earned, source)
	if source == "movement" then
		local now = os.clock()
		if now - lastMovementPopup < POPUP_MIN_GAP then
			return
		end
		lastMovementPopup = now
	end
	showPopup(earned)
end)

-- Anonslar ---------------------------------------------------------------
-- Ayni banner arka arkaya tetiklenirse eski gizleme zamanlayicisi yenisini
-- kapatmasin diye her gosterime bir nesil numarasi verilir.

local bannerGeneration = {}

local function playBanner(banner: CanvasGroup)
	local scale = banner:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Parent = banner
	end
	local generation = (bannerGeneration[banner] or 0) + 1
	bannerGeneration[banner] = generation

	banner.Visible = true
	banner.GroupTransparency = 1
	scale.Scale = 0.6
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
	TweenService:Create(banner, TweenInfo.new(0.2), {GroupTransparency = 0}):Play()

	task.delay(1.5, function()
		if bannerGeneration[banner] ~= generation then
			return
		end
		local fade = TweenService:Create(banner, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {GroupTransparency = 1})
		fade:Play()
		fade.Completed:Wait()
		if bannerGeneration[banner] == generation then
			banner.Visible = false
		end
	end)
end

PlayerProgress.LevelUp:Connect(function(newLevel)
	local label = levelUpBanner:FindFirstChild("Label")
	if label then
		label.Text = "LEVEL " .. newLevel .. "!"
	end
	playOneShot(sfxLevelUp)
	playBanner(levelUpBanner)
end)

local lastWins = winsStat.Value
winsStat.Changed:Connect(function(newValue)
	local delta = newValue - lastWins
	lastWins = newValue
	if delta > 0 then
		local label = winBanner:FindFirstChild("Label")
		if label then
			label.Text = "+" .. NumberFormat.abbreviate(delta) .. " Win!"
		end
		playOneShot(sfxWin)
		playBanner(winBanner)
	end
end)
