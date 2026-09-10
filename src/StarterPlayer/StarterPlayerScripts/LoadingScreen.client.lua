-- LoadingScreen
-- StarterGui.loadingscreen'i klonlayip calistirir. "loading" katmani (cikolata)
-- soldan saga maske ile acilir; asset listesi AssetPreloader'dan gelir.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider   = game:GetService("ContentProvider")
local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local StarterGui        = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local AssetPreloader = require(ReplicatedStorage:WaitForChild("AssetPreloader"))

-- StarterGui.loadingscreen kaynak olarak kalir, PlayerGui'ye klonlanir

local sourceGui = StarterGui:WaitForChild("loadingscreen", 10)
if not sourceGui then
	warn("[LoadingScreen] StarterGui.loadingscreen bulunamadi, script durduruluyor.")
	return
end

local existing = playerGui:FindFirstChild("loadingscreen")
if existing then
	existing:Destroy()
end

local gui = sourceGui:Clone()
gui.Enabled = true
gui.DisplayOrder = 1000
gui.ScreenInsets = Enum.ScreenInsets.None -- centik dahil tum ekran
gui.Parent = playerGui

-- "Cover" olcekleme: menulerdeki "fit"in aksine 1920x1080 tasarim ekrani
-- tamamen kaplar, tasan kisim iki yana esit kirpilir.
local DESIGN_W, DESIGN_H = 1920, 1080
local function applyUIScale()
	local vp = workspace.CurrentCamera.ViewportSize
	local s = gui:FindFirstChildOfClass("UIScale")
	if not s then s = Instance.new("UIScale") s.Parent = gui end
	local k = math.clamp(math.max(vp.X / DESIGN_W, vp.Y / DESIGN_H), 0.2, 3)
	s.Scale = k
	-- Offset'ler de UIScale ile carpildigi icin hesap tasarim pikseli cinsinden
	local frame = gui:FindFirstChild("loadingframe")
	if frame then
		frame.Position = UDim2.new(
			0, math.floor((vp.X / k - DESIGN_W) / 2),
			0, math.floor((vp.Y / k - DESIGN_H) / 2)
		)
	end
end
applyUIScale()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applyUIScale)

local loadingframe = gui:WaitForChild("loadingframe", 10)
if not loadingframe then
	warn("[LoadingScreen] loadingframe bulunamadi, script durduruluyor.")
	gui:Destroy()
	return
end

local chocoLayer   = loadingframe:WaitForChild("loading", 10)   -- cikolata kremasi (acilacak)
local loadingText  = loadingframe:WaitForChild("load", 10)       -- "loading" yazisi (sabit)
local staticCream  = loadingframe:WaitForChild("staticload", 10) -- beyaz krema (sabit)
local fullimage    = loadingframe:WaitForChild("fullimage", 10)  -- arka plan cerceve (sabit)

if not (chocoLayer and loadingText and staticCream and fullimage) then
	warn("[LoadingScreen] Beklenen alt-instance'lar eksik (loading/load/staticload/fullimage). Script durduruluyor.")
	gui:Destroy()
	return
end

-- "load" (loading yazisi) her zaman "loading" (cikolata) katmaninin USTUNDE olmali
loadingText.ZIndex = math.max(chocoLayer.ZIndex + 1, loadingText.ZIndex)

-- Maske: chocoLayer, ClipsDescendants'li bir frame icine alinir ve frame'in
-- genisligi 0'dan tam genislige acilir

local originalSize = chocoLayer.Size
local originalPosition = chocoLayer.Position
local originalAnchor = chocoLayer.AnchorPoint
local originalZIndex = chocoLayer.ZIndex

local maskFrame = Instance.new("Frame")
maskFrame.Name = "ChocoMask"
maskFrame.BackgroundTransparency = 1
maskFrame.ClipsDescendants = true
maskFrame.AnchorPoint = originalAnchor
maskFrame.Position = originalPosition
maskFrame.Size = UDim2.new(0, 0, originalSize.Y.Scale, originalSize.Y.Offset) -- baslangicta genislik 0
maskFrame.ZIndex = originalZIndex
maskFrame.Parent = loadingframe

chocoLayer.Parent = maskFrame
chocoLayer.Position = UDim2.new(0, 0, 0, 0)
chocoLayer.AnchorPoint = Vector2.new(0, 0)
chocoLayer.Size = originalSize -- tam boyutunda kalsin, maskFrame disini kirpar

-- Yukleme: ekran en az MIN_LOADING_TIME gorunur, asset yuklemesi bitmezse
-- MAX_WAIT_TIME sonra yine de devam edilir

local MIN_LOADING_TIME = 7
local MAX_WAIT_TIME = 20

local assetList = AssetPreloader.gatherAll(player)
local total = #assetList
local loadedCount = 0
local startTime = os.clock()

local function applyFillAlpha(alpha)
	alpha = math.clamp(alpha, 0, 1)
	local targetWidthScale = originalSize.X.Scale * alpha
	local targetWidthOffset = originalSize.X.Offset * alpha
	maskFrame.Size = UDim2.new(targetWidthScale, targetWidthOffset, originalSize.Y.Scale, originalSize.Y.Offset)
end

task.spawn(function()
	if total > 0 then
		for _, assetId in ipairs(assetList) do
			pcall(function()
				ContentProvider:PreloadAsync({ assetId })
			end)
			loadedCount += 1
		end
	end
end)

while true do
	local elapsed = os.clock() - startTime
	local timeAlpha = math.clamp(elapsed / MIN_LOADING_TIME, 0, 1)
	local assetAlpha = total > 0 and (loadedCount / total) or 1
	applyFillAlpha(timeAlpha)
	-- Ilk frame'lerde ViewportSize gercek pencere boyutunu yansitmayabilir
	applyUIScale()

	if elapsed >= MIN_LOADING_TIME and assetAlpha >= 1 then
		break
	end
	if elapsed >= MAX_WAIT_TIME then
		warn("[LoadingScreen] MAX_WAIT_TIME (" .. MAX_WAIT_TIME .. "s) asildi, asset yuklemesi tamamlanmadan devam ediliyor. Yuklenen: " .. loadedCount .. "/" .. total)
		break
	end
	task.wait(0.05)
end

applyFillAlpha(1)
task.wait(0.3)

-- Kapanis: tum fade-out tweenleri ayni anda baslar

local FADE_DURATION = 0.5
local fadeTweens = {}

for _, descendant in ipairs(loadingframe:GetDescendants()) do
	if descendant:IsA("ImageLabel") or descendant:IsA("ImageButton") then
		table.insert(fadeTweens, TweenService:Create(descendant, TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Quad), { ImageTransparency = 1 }))
	elseif descendant:IsA("TextLabel") then
		table.insert(fadeTweens, TweenService:Create(descendant, TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Quad), { TextTransparency = 1 }))
	end
end

for _, tw in ipairs(fadeTweens) do
	tw:Play()
end

task.wait(FADE_DURATION)

gui.Enabled = false
for _, descendant in ipairs(gui:GetDescendants()) do
	if descendant:IsA("GuiObject") then
		descendant.Visible = false
	end
end
gui:Destroy()
