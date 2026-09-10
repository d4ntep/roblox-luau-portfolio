-- MenuController (client)
-- Tum menulerin ortak davranisi: UIScale, acilis/kapanis animasyonu, blur,
-- sesler ve "ayni anda tek menu acik" kurali. Her menu createSlideMenu ile
-- kaydolur; ayrintili is (sekmeler, kartlar) menunun kendi script'inde kalir.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local MenuController = {}

-- Ayarlar --------------------------------------------------------------

local REFERENCE_WIDTH = 1920
local REFERENCE_HEIGHT = 1080
local MIN_SCALE = 0.35
local MAX_SCALE = 2.0

local BLUR_SIZE = 24
local OPEN_DURATION = 0.65
local CLOSE_DURATION = 0.3
local BOUNCE_OVERSHOOT = 1.035
local BOUNCE_PEAK_AT = 0.72
local CLOSED_Y_SCALE = 2.0

-- Paylasilan blur ------------------------------------------------------

local blurEffect = Lighting:FindFirstChildOfClass("BlurEffect")
if not blurEffect then
	blurEffect = Instance.new("BlurEffect")
	blurEffect.Name = "MenuBlur"
	blurEffect.Size = 0
	blurEffect.Parent = Lighting
end
MenuController.blur = blurEffect

-- Sesler ---------------------------------------------------------------

local sounds = {}
do
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("sounds")
	folder = folder and folder:FindFirstChild("menusounds")
	if folder then
		sounds.open = folder:FindFirstChild("menuopening")
		sounds.close = folder:FindFirstChild("menuclosing")
		sounds.hover = folder:FindFirstChild("mousehover")
	end
end

local function playFadeIn(sound: Sound?)
	if not sound then
		return
	end
	sound.Volume = 0
	sound:Play()
	TweenService:Create(sound, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Volume = 0.5}):Play()
end

function MenuController.playHover()
	if sounds.hover then
		sounds.hover:Play()
	end
end

-- UIScale --------------------------------------------------------------

function MenuController.applyUIScale(gui: ScreenGui)
	local scale = gui:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Parent = gui
	end
	local vp = camera.ViewportSize
	scale.Scale = math.clamp(math.min(vp.X / REFERENCE_WIDTH, vp.Y / REFERENCE_HEIGHT), MIN_SCALE, MAX_SCALE)
end

-- Olceklemeyi uygular ve pencere boyutu degisince yeniler
function MenuController.attachUIScale(gui: ScreenGui): RBXScriptConnection
	MenuController.applyUIScale(gui)
	return camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		MenuController.applyUIScale(gui)
	end)
end

-- Animasyon ------------------------------------------------------------

local function bounceEaseOut(t: number): number
	if t < BOUNCE_PEAK_AT then
		local p = t / BOUNCE_PEAK_AT
		return BOUNCE_OVERSHOOT * (1 - (1 - p) ^ 5)
	end
	local p = (t - BOUNCE_PEAK_AT) / (1 - BOUNCE_PEAK_AT)
	local smooth = p * p * (3 - 2 * p)
	return BOUNCE_OVERSHOOT - (BOUNCE_OVERSHOOT - 1) * smooth
end

local function lerpUDim2(a: UDim2, b: UDim2, t: number): UDim2
	return UDim2.new(
		a.X.Scale + (b.X.Scale - a.X.Scale) * t,
		a.X.Offset + (b.X.Offset - a.X.Offset) * t,
		a.Y.Scale + (b.Y.Scale - a.Y.Scale) * t,
		a.Y.Offset + (b.Y.Offset - a.Y.Offset) * t
	)
end

function MenuController.tweenBounce(obj: GuiObject, from: UDim2, to: UDim2, duration: number)
	local elapsed = 0
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		local alpha = math.min(elapsed / duration, 1)
		obj.Position = lerpUDim2(from, to, bounceEaseOut(alpha))
		if alpha >= 1 then
			conn:Disconnect()
		end
	end)
end

local function closedPositionOf(openPos: UDim2): UDim2
	return UDim2.new(openPos.X.Scale, openPos.X.Offset, CLOSED_Y_SCALE, 0)
end

-- Frame'lerin ustune seffaf tiklama alani
function MenuController.addOverlay(frame: GuiObject, onClick: () -> (), options)
	options = options or {}
	local overlay = Instance.new("TextButton")
	overlay.Name = "_ClickOverlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundTransparency = 1
	overlay.Text = ""
	overlay.ZIndex = options.zIndex or (frame.ZIndex + 10)
	overlay.Parent = frame

	local originalColor = frame.BackgroundColor3
	overlay.MouseEnter:Connect(function()
		MenuController.playHover()
		if options.hoverDarken then
			TweenService:Create(frame, TweenInfo.new(0.15), {BackgroundColor3 = Color3.new(0, 0, 0)}):Play()
		end
	end)
	if options.hoverDarken then
		overlay.MouseLeave:Connect(function()
			TweenService:Create(frame, TweenInfo.new(0.15), {BackgroundColor3 = originalColor}):Play()
		end)
	end

	local lastClick = 0
	local cooldown = options.cooldown or 0
	overlay.MouseButton1Click:Connect(function()
		local now = os.clock()
		if now - lastClick < cooldown then
			return
		end
		lastClick = now
		onClick()
	end)
	return overlay
end

-- Menu kaydi -----------------------------------------------------------

local registry = {} -- name -> animasyonlu close fonksiyonu

function MenuController.closeOthers(exceptName: string)
	for name, closeFn in pairs(registry) do
		if name ~= exceptName then
			closeFn()
		end
	end
end

function MenuController.hardReset()
	blurEffect.Size = 0
end

export type SlideMenuConfig = {
	name: string,
	gui: ScreenGui,
	parts: {GuiObject | {instance: GuiObject, open: UDim2}},
	openButton: GuiObject?,
	closeButton: GuiObject?,
	hoverDarken: boolean?,
	closeOnRespawn: boolean?,
	onOpen: (() -> ())?,
	onClose: (() -> ())?,
}

-- Asagidan yukari kayan standart menu. `parts` icindeki her eleman ekran
-- disindan kendi acik konumuna gelir; acik konum verilmezse mevcut Position alinir.
function MenuController.createSlideMenu(config: SlideMenuConfig)
	local parts = {}
	for _, entry in ipairs(config.parts) do
		local instance = if typeof(entry) == "Instance" then entry else entry.instance
		local openPos = if typeof(entry) == "Instance" then instance.Position else entry.open
		table.insert(parts, {
			instance = instance,
			open = openPos,
			closed = closedPositionOf(openPos),
		})
	end

	local function snapClosed()
		for _, part in ipairs(parts) do
			part.instance.Position = part.closed
			part.instance.Visible = false
		end
	end
	snapClosed()
	MenuController.attachUIScale(config.gui)

	local isOpen = false
	local handle = {}

	function handle.isOpen()
		return isOpen
	end

	function handle.open()
		if isOpen then
			return
		end
		MenuController.closeOthers(config.name)
		isOpen = true
		playFadeIn(sounds.open)
		TweenService:Create(blurEffect, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = BLUR_SIZE}):Play()
		for _, part in ipairs(parts) do
			part.instance.Visible = true
			MenuController.tweenBounce(part.instance, part.closed, part.open, OPEN_DURATION)
		end
		if config.onOpen then
			config.onOpen()
		end
	end

	function handle.close()
		if not isOpen then
			return
		end
		isOpen = false
		playFadeIn(sounds.close)
		local info = TweenInfo.new(CLOSE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(blurEffect, info, {Size = 0}):Play()
		for _, part in ipairs(parts) do
			TweenService:Create(part.instance, info, {Position = part.closed}):Play()
		end
		task.delay(CLOSE_DURATION, function()
			if not isOpen then
				for _, part in ipairs(parts) do
					part.instance.Visible = false
				end
			end
		end)
		if config.onClose then
			config.onClose()
		end
	end

	function handle.forceClose()
		if not isOpen then
			return
		end
		isOpen = false
		MenuController.hardReset()
		snapClosed()
		if config.onClose then
			config.onClose()
		end
	end

	function handle.toggle()
		if isOpen then
			handle.close()
		else
			handle.open()
		end
	end

	if config.openButton then
		MenuController.addOverlay(config.openButton, handle.toggle, {
			hoverDarken = config.hoverDarken,
			cooldown = 0.3,
		})
	end
	if config.closeButton then
		MenuController.addOverlay(config.closeButton, handle.close, {zIndex = 20})
	end
	if config.closeOnRespawn ~= false then
		player.CharacterAdded:Connect(handle.forceClose)
	end

	registry[config.name] = handle.close
	return handle
end

return MenuController
