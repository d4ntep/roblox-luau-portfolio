-- PurinchanChaseClient
-- Purinchan kovalamacasi tamamen client'ta calisir: model her oyuncunun kendi
-- ekraninda klonlanir, diger oyunculara replike edilmez. Oyuncu "notsafeN"
-- alanindayken kovalar, cikinca evine doner. Yakalanma sunucuya bildirilir.
-- Alan kontrolu Touched yerine konum bazlidir (ziplayinca temas kopmasin diye).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local localPlayer = Players.LocalPlayer

local CHASE_SPEED = 24       -- stud/sn
local RETURN_SPEED = 24
local ARRIVE_THRESHOLD = 1.5
local KILL_DISTANCE = 8

local HOP_HEIGHT = 1.2
local HOP_DURATION = 0.45
local LEAN_ANGLE = 18          -- derece, ters gorunurse negatif
local LEAN_RISE_FRACTION = 0.2

local JUMP_ALLOWANCE = 20      -- alanin ustunde bu kadar yukseklik hala "alanda"
local BELOW_ALLOWANCE = 5

local template = ReplicatedStorage:WaitForChild("PurinchanTemplate")
local caughtRemote = Remotes.event("PurinchanCaught")

local HOME_CFRAME = template.PrimaryPart.CFrame
local HOME_LOOK_VECTOR = HOME_CFRAME.LookVector

-- Client'ta olusturulan klon: sadece bu oyuncu gorur
local model = template:Clone()
model.Name = "Purinchan_Local"
local mesh = model:FindFirstChild("Mesh_0")
model.PrimaryPart = mesh
mesh.CanCollide = false -- oyuncuyu itip jitter yaratmasin diye
mesh.Anchored = true    -- fizik/yercekimi karismasin, CFrame ile suruyoruz
model.Parent = workspace
model:PivotTo(HOME_CFRAME)

local state = {
	chasing = false,
	basePosition = HOME_CFRAME.Position, -- ziplama olmadan gercek/mantiksal konum
	lastDirection = HOME_LOOK_VECTOR,
	hopTime = 0,
	killCooldown = 0, -- yakaladiktan sonra tekrar remote spamlamasin
}

-- Duz zeminde (Y sabit) hedefe dogru basePosition'i ilerletir
local function advanceTowards(currentPos, targetPos, speed, dt)
	local delta = targetPos - currentPos
	local dist = delta.Magnitude
	if dist < 0.05 then
		return currentPos, nil, dist
	end
	local step = math.min(speed * dt, dist)
	local direction = delta.Unit
	return currentPos + direction * step, direction, dist
end

-- basePosition + hop/lean'i birlestirip gercek mesh CFrame'ini uretir
local function applyHopVisual()
	local lookDir = Vector3.new(state.lastDirection.X, 0, state.lastDirection.Z)
	if lookDir.Magnitude < 0.01 then
		lookDir = Vector3.new(HOME_LOOK_VECTOR.X, 0, HOME_LOOK_VECTOR.Z)
	end

	local phase = state.hopTime / HOP_DURATION
	local hopOffset = HOP_HEIGHT * math.sin(phase * math.pi)

	local leanAngle
	if phase < LEAN_RISE_FRACTION then
		leanAngle = LEAN_ANGLE * (phase / LEAN_RISE_FRACTION)
	else
		leanAngle = LEAN_ANGLE * (1 - (phase - LEAN_RISE_FRACTION) / (1 - LEAN_RISE_FRACTION))
	end

	local visualPos = state.basePosition + Vector3.new(0, hopOffset, 0)
	mesh.CFrame = CFrame.new(visualPos, visualPos + lookDir) * CFrame.Angles(math.rad(-leanAngle), 0, 0)
end

local notsafeParts = {}

local function setupNotSafe(part)
	if not part:IsA("BasePart") then return end
	if not tostring(part.Name):match("^notsafe%d+$") then return end
	-- notsafe2 labirent boss'una ait (AngrypurinChaseClient)
	if part.Name == "notsafe2" then return end
	for _, existing in ipairs(notsafeParts) do
		if existing == part then return end
	end
	table.insert(notsafeParts, part)
end

-- Verilen dunya pozisyonu, kayitli notsafeN parcalarinin sinirlari icinde mi?
local function isInNotSafeZone(worldPos)
	for _, part in ipairs(notsafeParts) do
		if part.Parent then
			local localPos = part.CFrame:PointToObjectSpace(worldPos)
			local halfSize = part.Size / 2
			if math.abs(localPos.X) <= halfSize.X
				and math.abs(localPos.Z) <= halfSize.Z
				and localPos.Y >= -halfSize.Y - BELOW_ALLOWANCE
				and localPos.Y <= halfSize.Y + JUMP_ALLOWANCE then
				return true
			end
		end
	end
	return false
end

RunService.Heartbeat:Connect(function(dt)
	state.killCooldown = math.max(0, state.killCooldown - dt)

	local character = localPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local alive = hrp and humanoid and humanoid.Health > 0

	state.chasing = alive and isInNotSafeZone(hrp.Position) or false

	local moving = false

	if state.chasing then
		local targetPos = Vector3.new(hrp.Position.X, state.basePosition.Y, hrp.Position.Z)
		local newPos, direction = advanceTowards(state.basePosition, targetPos, CHASE_SPEED, dt)
		state.basePosition = newPos
		if direction then state.lastDirection = direction end
		moving = true

		-- Yatay mesafeye bak (Y farkini yok say); yakalandiysa sunucuya bildir
		local flatDelta = Vector3.new(state.basePosition.X - hrp.Position.X, 0, state.basePosition.Z - hrp.Position.Z)
		if flatDelta.Magnitude <= KILL_DISTANCE and state.killCooldown <= 0 then
			state.killCooldown = 1
			state.chasing = false
			caughtRemote:FireServer()
		end
	else
		local dist = (state.basePosition - HOME_CFRAME.Position).Magnitude
		if dist > ARRIVE_THRESHOLD then
			local newPos, direction = advanceTowards(state.basePosition, HOME_CFRAME.Position, RETURN_SPEED, dt)
			state.basePosition = newPos
			if direction then state.lastDirection = direction end
			moving = true
		else
			state.basePosition = HOME_CFRAME.Position
			state.hopTime = 0
		end
	end

	if moving then
		state.hopTime = (state.hopTime + dt) % HOP_DURATION
		applyHopVisual()
	else
		mesh.CFrame = HOME_CFRAME
	end
end)

-- Mevcut notsafe parcalarini bul ve kur
for _, obj in ipairs(workspace:GetDescendants()) do
	setupNotSafe(obj)
end

-- Sonradan eklenen/replike olan notsafe parcalarini da yakala
workspace.DescendantAdded:Connect(function(obj)
	task.defer(setupNotSafe, obj)
end)
