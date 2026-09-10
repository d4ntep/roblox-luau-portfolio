-- CharacterStepDetectorSystem
-- HumanoidRootPart'a carpismasiz, gorunmez ve biraz daha genis bir "StepDetector"
-- parcasi kaynaklar. Touched tabanli sistemler (puding, win butonu, checkpoint)
-- boylece daha rahat tetiklenir; gercek hitbox degismez.

local Players = game:GetService("Players")

local EXTRA_SIZE = 2 -- X ve Z'de toplam, yani her yone +1 stud

local function addStepDetector(character)
	local hrp = character:WaitForChild("HumanoidRootPart", 5)
	if not hrp then return end

	if character:FindFirstChild("StepDetector") then return end

	local detector = Instance.new("Part")
	detector.Name = "StepDetector"
	detector.Size = Vector3.new(hrp.Size.X + EXTRA_SIZE, hrp.Size.Y, hrp.Size.Z + EXTRA_SIZE)
	detector.CFrame = hrp.CFrame
	detector.Transparency = 1
	detector.CanCollide = false
	detector.CanQuery = false
	detector.CanTouch = true
	detector.Massless = true
	detector.Parent = character

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hrp
	weld.Part1 = detector
	weld.Parent = detector
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(addStepDetector)
	if player.Character then
		addStepDetector(player.Character)
	end
end)

for _, player in ipairs(Players:GetPlayers()) do
	player.CharacterAdded:Connect(addStepDetector)
	if player.Character then
		addStepDetector(player.Character)
	end
end
