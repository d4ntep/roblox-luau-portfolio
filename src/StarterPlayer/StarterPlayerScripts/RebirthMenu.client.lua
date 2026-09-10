-- RebirthMenu
-- rebirthgui: mevcut/sonraki carpan, level ilerlemesi, rebirth ve Skip Rebirth.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local MenuController = require(ReplicatedStorage:WaitForChild("MenuController"))
local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))
local PlayerProgress = require(script.Parent:WaitForChild("PlayerProgress"))

local player = Players.LocalPlayer
local rebirthStat = player:WaitForChild("leaderstats"):WaitForChild("Rebirths")
local sfxRebirth = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("sounds"):WaitForChild("effects"):WaitForChild("rebirthup")

local gui = player:WaitForChild("PlayerGui"):WaitForChild("rebirthgui")
local menuFrame = gui:WaitForChild("menu")
local buttonFrame = gui:WaitForChild("button")
local chocodrip = gui:WaitForChild("chocodrip")
local closeBtn = gui:WaitForChild("closebutton")
local reqLabel = gui:WaitForChild("reqx")

local currentSpeedLabel = menuFrame:WaitForChild("currentspd"):WaitForChild("currentspeed")
local nextSpeedLabel = menuFrame:WaitForChild("nextspd"):WaitForChild("nextspeed")
local levelUpFrame = menuFrame:WaitForChild("levelup")
local progressFrame = menuFrame:WaitForChild("progress")
local levelLabel = progressFrame:WaitForChild("level")
local needLabel = progressFrame:WaitForChild("lvlneed")
local fillFrame = progressFrame:WaitForChild("fill")
local skipRebirthFrame = menuFrame:WaitForChild("skiprebirth")

-- Menu ------------------------------------------------------------------

local function refresh()
	local _, level = PlayerProgress.get()
	local rebirths = rebirthStat.Value
	local requiredLevel = GameConfig.getRebirthRequiredLevel(rebirths)

	currentSpeedLabel.Text = NumberFormat.abbreviate(GameConfig.getRebirthMultiplier(rebirths)) .. "x Speed"
	nextSpeedLabel.Text = NumberFormat.abbreviate(GameConfig.getRebirthMultiplier(rebirths + 1)) .. "x Speed"
	levelLabel.Text = "Level " .. level
	needLabel.Text = level .. "/" .. requiredLevel

	local reqLevelLabel = levelUpFrame:FindFirstChild("reqlvl")
	if reqLevelLabel then
		reqLevelLabel.Text = "Need Lv." .. requiredLevel
	end
	TweenService:Create(fillFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(math.clamp(level / requiredLevel, 0, 1), 0, 1, 0),
	}):Play()
end

local menu = MenuController.createSlideMenu({
	name = "rebirthgui",
	gui = gui,
	parts = {
		{instance = menuFrame, open = UDim2.new(0.5, 0, 0.066, 0)},
		{instance = chocodrip, open = UDim2.new(0.5, 0, 0.037, 0)},
		{instance = closeBtn, open = UDim2.new(0.735, 0, 0.036, 0)},
	},
	openButton = buttonFrame,
	closeButton = closeBtn,
	hoverDarken = true,
	onOpen = refresh,
})

PlayerProgress.Changed:Connect(function()
	if menu.isOpen() then
		refresh()
	end
end)
rebirthStat.Changed:Connect(refresh)
refresh()

-- "Yetersiz level" uyarisi ------------------------------------------------

local REQ_START = UDim2.new(0.5, 0, 0.22, 0)
local REQ_TARGET = UDim2.new(0.5, 0, 0.18, 0)
local REQ_EXIT = UDim2.new(0.5, 0, 0.14, 0)
local reqStroke = reqLabel:FindFirstChildOfClass("UIStroke")
local reqBusy = false

reqLabel.AnchorPoint = Vector2.new(0.5, 0.5)
reqLabel.Position = REQ_START
reqLabel.TextTransparency = 1
reqLabel.TextStrokeTransparency = 1
if reqStroke then
	reqStroke.Transparency = 1
end
reqLabel.Visible = true

local function showRequirementMessage()
	if reqBusy then
		return
	end
	reqBusy = true
	reqLabel.Position = REQ_START
	TweenService:Create(reqLabel, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 0,
		Position = REQ_TARGET,
	}):Play()
	if reqStroke then
		TweenService:Create(reqStroke, TweenInfo.new(0.1), {Transparency = 0}):Play()
	end
	task.delay(2.5, function()
		TweenService:Create(reqLabel, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextTransparency = 1,
			Position = REQ_EXIT,
		}):Play()
		if reqStroke then
			TweenService:Create(reqStroke, TweenInfo.new(0.25), {Transparency = 1}):Play()
		end
		task.delay(0.25, function()
			reqLabel.Position = REQ_START
			reqBusy = false
		end)
	end)
end

-- Butonlar --------------------------------------------------------------

MenuController.addOverlay(levelUpFrame, function()
	if PlayerProgress.canRebirth() then
		PlayerProgress.requestRebirth()
		sfxRebirth:Play()
		menu.close()
	else
		showRequirementMessage()
	end
end)

MenuController.addOverlay(skipRebirthFrame, function()
	MarketplaceService:PromptProductPurchase(player, GameConfig.PRODUCTS.SKIP_REBIRTH)
end, {zIndex = 999})
