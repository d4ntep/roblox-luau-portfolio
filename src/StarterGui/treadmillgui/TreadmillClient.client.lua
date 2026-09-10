-- TreadmillClient
-- treadmillgui.button: sahip olunan en yuksek treadmill'i oyuncunun altina
-- spawnlar, tekrar basinca kaldirir. Secim ve dogrulama sunucuda.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MenuController = require(ReplicatedStorage:WaitForChild("MenuController"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local portableEvent = Remotes.event("PortableTreadmill")

local gui = player:WaitForChild("PlayerGui"):WaitForChild("treadmillgui")
local buttonFrame = gui:WaitForChild("button")
local label = buttonFrame:WaitForChild("TextLabel")

local defaultText = label.Text
local isSpawned = false
local flashToken = 0

MenuController.addOverlay(buttonFrame, function()
	portableEvent:FireServer()
end, {hoverDarken = true, cooldown = 0.7})

local function flash(message: string)
	flashToken += 1
	local token = flashToken
	label.Text = message
	task.delay(1.5, function()
		if token == flashToken then
			label.Text = if isSpawned then "Remove" else defaultText
		end
	end)
end

portableEvent.OnClientEvent:Connect(function(action)
	if action == "spawned" then
		isSpawned = true
		flashToken += 1
		label.Text = "Remove"
	elseif action == "removed" then
		isSpawned = false
		flashToken += 1
		label.Text = defaultText
	elseif action == "blocked" then
		flash("Already on one!")
	end
end)
