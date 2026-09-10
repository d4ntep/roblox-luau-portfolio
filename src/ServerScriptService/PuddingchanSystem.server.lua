-- PuddingchanSystem
-- "puddingchan" modeli belirli araliklarla baslangictan "puddingchanend"
-- parcasina dogru sabit hizla gider, dokunan oyuncuyu oldurur. Paylasilan
-- bir dunya objesi oldugu icin sunucuda hareket ettirilir.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local spawnSound = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("sounds"):WaitForChild("effects"):WaitForChild("puddinchanspawn")

local MOVE_SPEED = 220        -- stud/sn
local SPAWN_COOLDOWN = 5      -- saniye
local ARRIVE_THRESHOLD = 1.5

local function findByName(name)
	name = name:lower()
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj.Name:lower() == name then
			return obj
		end
	end
	return nil
end

local puddingchan = findByName("puddingchan")
local endPart      = findByName("puddingchanend")
local cdPart       = findByName("puddinchancd")

if not puddingchan or not puddingchan:IsA("Model") then
	warn("[PuddingchanSystem] 'puddingchan' modeli bulunamadi!")
	return
end
if not endPart then
	warn("[PuddingchanSystem] 'puddingchanend' parcasi bulunamadi!")
	return
end

if not puddingchan.PrimaryPart then
	puddingchan.PrimaryPart = puddingchan:FindFirstChildWhichIsA("BasePart", true)
end
if not puddingchan.PrimaryPart then
	warn("[PuddingchanSystem] 'puddingchan' modelinde hicbir BasePart yok!")
	return
end

local HOME_CFRAME  = puddingchan:GetPivot()
local HOME_ROTATION = HOME_CFRAME - HOME_CFRAME.Position -- sadece rotasyon (konumsuz)
local END_POSITION = endPart:IsA("BasePart") and endPart.Position or endPart:GetPivot().Position

-- Cooldown gostergesi
local cooldownLabel = nil
if cdPart then
	for _, gui in ipairs(cdPart:GetChildren()) do
		if gui:IsA("SurfaceGui") then
			cooldownLabel = gui:FindFirstChild("cooldown", true)
			if cooldownLabel then break end
		end
	end
	if not cooldownLabel then
		warn("[PuddingchanSystem] 'puddinchancd' icinde SurfaceGui > cooldown TextLabel bulunamadi!")
	end
else
	warn("[PuddingchanSystem] 'puddinchancd' parcasi bulunamadi!")
end

local function setCooldownText(seconds)
	if cooldownLabel then
		cooldownLabel.Text = string.format("%.1f", math.max(seconds, 0))
	end
end

-- Orijinal model gizli bir sablondur; her turda bir kopya yola cikar ve varinca
-- yok edilir. Transparency degerleri siraya gore saklanir (Clone sirayi korur).
local originalTransparencies = {}
for _, part in ipairs(puddingchan:GetDescendants()) do
	if part:IsA("BasePart") then
		table.insert(originalTransparencies, part.Transparency)
		part.Transparency = 1
		part.CanCollide = false
		part.CanTouch = false
	end
end
puddingchan:PivotTo(HOME_CFRAME)

local function spawnClone()
	local clone = puddingchan:Clone()
	clone.Name = "PuddingchanClone"
	clone.Parent = workspace
	clone:PivotTo(HOME_CFRAME)

	local soundClone = spawnSound:Clone()
	soundClone.Parent = clone.PrimaryPart
	soundClone:Play()

	local i = 0
	for _, part in ipairs(clone:GetDescendants()) do
		if part:IsA("BasePart") then
			i += 1
			part.Transparency = originalTransparencies[i] or 0
			part.CanCollide = true
			part.CanTouch = true
			part.Touched:Connect(function(hit)
				local character = hit.Parent
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if humanoid and humanoid.Health > 0 then
					humanoid.Health = 0
				end
			end)
		end
	end

	-- Rotasyon sabit kalir, sadece pozisyon ilerler
	while true do
		local pos = clone:GetPivot().Position
		local delta = END_POSITION - pos
		local dist = delta.Magnitude
		if dist <= ARRIVE_THRESHOLD then
			break
		end
		local dt = RunService.Heartbeat:Wait()
		local step = math.min(MOVE_SPEED * dt, dist)
		local newPos = pos + delta.Unit * step
		clone:PivotTo(CFrame.new(newPos) * HOME_ROTATION)
	end

	clone:Destroy()
end

-- Geri sayim bagimsiz doner; birden fazla kopya ayni anda yolda olabilir
task.spawn(function()
	while true do
		local remaining = SPAWN_COOLDOWN
		setCooldownText(remaining)
		while remaining > 0 do
			local dt = RunService.Heartbeat:Wait()
			remaining = math.max(remaining - dt, 0)
			setCooldownText(remaining)
		end

		task.spawn(spawnClone)
	end
end)
