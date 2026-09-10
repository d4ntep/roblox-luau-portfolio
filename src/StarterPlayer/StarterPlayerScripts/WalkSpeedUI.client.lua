-- WalkSpeedUI
-- walkspeedgui: oyuncu, level'inin izin verdigi tavana kadar kendi WalkSpeed'ini girer.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local levelStat = player:WaitForChild("Level")
local setWalkSpeedEvent = Remotes.event("SetCustomWalkSpeed")

local gui = player:WaitForChild("PlayerGui"):WaitForChild("walkspeedgui")
local menuFrame = gui:WaitForChild("menu")
local speedEntry = menuFrame:WaitForChild("speedentry")
local maxLabel = menuFrame:WaitForChild("yourmaxspeed")
local setButton = menuFrame:WaitForChild("speedsetbtn")
local setLabel = setButton:WaitForChild("TextLabel")

local function getMaxSpeed(): number
	return GameConfig.getMaxWalkSpeed(levelStat.Value)
end

local function getCurrentWalkSpeed(): number
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return humanoid and humanoid.WalkSpeed or getMaxSpeed()
end

local speedBox = Instance.new("TextBox")
speedBox.Name = "_SpeedInput"
speedBox.Size = UDim2.fromScale(1, 1)
speedBox.BackgroundTransparency = 1
speedBox.Text = tostring(math.floor(getCurrentWalkSpeed()))
speedBox.PlaceholderText = "WalkSpeed"
speedBox.TextColor3 = Color3.fromRGB(255, 245, 200)
speedBox.TextStrokeTransparency = 0
speedBox.TextScaled = true
speedBox.Font = Enum.Font.FredokaOne
speedBox.ClearTextOnFocus = false
speedBox.ZIndex = 50
speedBox.Parent = speedEntry

local function updateMaxLabel()
	maxLabel.Text = "Max Speed = " .. getMaxSpeed()
end
updateMaxLabel()
levelStat.Changed:Connect(updateMaxLabel)

-- WalkSpeed disaridan degisirse (level, rebirth) kutuyu guncelle
local function hookCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid then
		return
	end
	humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
		if not speedBox:IsFocused() then
			speedBox.Text = tostring(math.floor(humanoid.WalkSpeed))
		end
	end)
end
if player.Character then
	hookCharacter(player.Character)
end
player.CharacterAdded:Connect(hookCharacter)

local function applySpeed()
	local input = tonumber(speedBox.Text)
	if not input then
		speedBox.Text = tostring(math.floor(getCurrentWalkSpeed()))
		return
	end
	local clamped = math.clamp(math.floor(input), 1, getMaxSpeed())
	speedBox.Text = tostring(clamped)
	setWalkSpeedEvent:FireServer(clamped)
end

local overlay = Instance.new("TextButton")
overlay.Name = "_SetOverlay"
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundTransparency = 1
overlay.Text = ""
overlay.ZIndex = setLabel.ZIndex + 10
overlay.Parent = setButton
overlay.MouseButton1Click:Connect(applySpeed)

speedBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		applySpeed()
	end
end)
