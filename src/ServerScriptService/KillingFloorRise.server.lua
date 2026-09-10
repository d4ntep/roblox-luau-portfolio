-- KillingFloorRise
-- killingfloorup parcasi surekli olarak yukselir ve geri iner.

local TweenService = game:GetService("TweenService")

local part = workspace:WaitForChild("killingfloorup")

local START_SIZE = Vector3.new(92.611, 51.019, 94.475)
local TARGET_SIZE = Vector3.new(92.611, 755.019, 94.475)
local RISE_DURATION = 5
local FALL_DURATION = 2.5

local basePos = part.Position
local targetPos = Vector3.new(
	basePos.X,
	basePos.Y + (TARGET_SIZE.Y - START_SIZE.Y) / 2,
	basePos.Z
)

while true do
	part.Size = START_SIZE
	part.Position = basePos

	local riseTween = TweenService:Create(part, TweenInfo.new(RISE_DURATION, Enum.EasingStyle.Linear), {
		Size = TARGET_SIZE,
		Position = targetPos,
	})
	riseTween:Play()
	riseTween.Completed:Wait()

	task.wait(2)

	local fallTween = TweenService:Create(part, TweenInfo.new(FALL_DURATION, Enum.EasingStyle.Linear), {
		Size = START_SIZE,
		Position = basePos,
	})
	fallTween:Play()
	fallTween.Completed:Wait()

	task.wait(2)
end
