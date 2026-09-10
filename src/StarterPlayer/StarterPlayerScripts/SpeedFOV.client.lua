-- SpeedFOV
-- Kamera ayarlari: zoom sinirlari ve hiza bagli FOV. FOV, WalkSpeed'e degil
-- karakterin gercek yatay hizina gore iki kademeli olarak artar; boylece
-- dusuk seviyede tavana ulasilmaz, hiz arttikca "zoom" hissi buyur.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

player.CameraMaxZoomDistance = 50
player.CameraMinZoomDistance = 5

local BASE_FOV = 75
local SPEED_TIER_1 = 120
local FOV_TIER_1 = 85
local SPEED_TIER_2 = 200
local FOV_TIER_2 = 95
local SMOOTH_TIME = 0.15

local currentFOV = BASE_FOV

RunService.RenderStepped:Connect(function(dt)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")

	local targetFOV = BASE_FOV
	if humanoid and root and humanoid.Health > 0 then
		local velocity = root.AssemblyLinearVelocity
		local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		if speed <= SPEED_TIER_1 then
			targetFOV = BASE_FOV + (FOV_TIER_1 - BASE_FOV) * math.clamp(speed / SPEED_TIER_1, 0, 1)
		else
			local alpha = math.clamp((speed - SPEED_TIER_1) / (SPEED_TIER_2 - SPEED_TIER_1), 0, 1)
			targetFOV = FOV_TIER_1 + (FOV_TIER_2 - FOV_TIER_1) * alpha
		end
	end

	-- Framerate'den bagimsiz eksponansiyel yumusatma
	currentFOV += (targetFOV - currentFOV) * (1 - math.exp(-dt / SMOOTH_TIME))
	camera.FieldOfView = currentFOV
end)
