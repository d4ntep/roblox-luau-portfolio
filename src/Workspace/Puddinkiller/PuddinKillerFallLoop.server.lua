-- PuddinKillerFallLoop
-- Parca periyodik olarak birakilir, yavaslatilmis dusus sirasinda dokunani
-- oldurur, sonra baslangic konumuna doner.

local part = script.Parent
local RunService = game:GetService("RunService")

local originalCFrame = part.CFrame
local originalCanCollide = part.CanCollide
local lockedX = originalCFrame.Position.X

local Y_DAMPING = 0.985 -- dusme hizi her karede bu oranla azalir

while true do
	part.CFrame = originalCFrame
	part.Transparency = 0
	part.CanTouch = true
	part.CanCollide = originalCanCollide
	part.Anchored = false
	part.AssemblyLinearVelocity = Vector3.new(0, 0, 0)

	local function onTouched(hit)
		local character = hit.Parent
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Health = 0
		end
	end
	local connection = part.Touched:Connect(onTouched)

	local heartbeatConn
	heartbeatConn = RunService.Heartbeat:Connect(function()
		if not part or not part.Parent then return end
		local vel = part.AssemblyLinearVelocity
		local pos = part.Position

		-- X ekseni kilitli
		part.CFrame = CFrame.new(lockedX, pos.Y, pos.Z) * (part.CFrame - part.CFrame.Position)

		local newVelY = vel.Y
		if newVelY < 0 then
			newVelY = newVelY * Y_DAMPING
		end
		part.AssemblyLinearVelocity = Vector3.new(0, newVelY, vel.Z)
	end)

	task.wait(5)

	if heartbeatConn then heartbeatConn:Disconnect() end
	connection:Disconnect()

	part.Transparency = 1
	part.CanTouch = false
	part.CanCollide = false
	part.Anchored = true

	task.wait(3)
end
