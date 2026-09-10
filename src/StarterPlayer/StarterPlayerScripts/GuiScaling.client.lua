-- GuiScaling
-- HUD ScreenGui'lerini 1920x1080 referansina gore olcekler. Menuler kendi
-- olceklerini MenuController uzerinden alir; burasi menu olmayan GUI'ler icin.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MenuController = require(ReplicatedStorage:WaitForChild("MenuController"))

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

local GUI_NAMES = {
	xpgui = true,
	soundgui = true,
	walkspeedgui = true,
	announcementgui = true,
	speedbonus = true,
	graphics = true,
	wincurrency = true,
	treadmillgui = true,
}

local function scaleAll()
	for _, gui in ipairs(playerGui:GetChildren()) do
		if GUI_NAMES[gui.Name] and gui:IsA("ScreenGui") then
			MenuController.applyUIScale(gui)
		end
	end
end

scaleAll()
playerGui.ChildAdded:Connect(function(child)
	if GUI_NAMES[child.Name] and child:IsA("ScreenGui") then
		task.defer(MenuController.applyUIScale, child)
	end
end)
camera:GetPropertyChangedSignal("ViewportSize"):Connect(scaleAll)
