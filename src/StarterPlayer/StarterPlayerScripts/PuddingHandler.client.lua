-- PuddingHandler
-- Haritadaki on binlerce puding icin Touched yerine spatial grid: puding
-- konumlari 16 stud'luk hucrelere hashlenir, tek bir Heartbeat dongusu sadece
-- karakterin cevresindeki 27 hucreye bakar. Basilan puding TweenService ile ezilir.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart")

player.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
	hrp = newCharacter:WaitForChild("HumanoidRootPart")
end)

local puddings = workspace:WaitForChild("Puddings", 10)
if not puddings then warn("Puddings bulunamadi!") return end

-- ===== SESLER =====
local waxFolder = workspace:WaitForChild("sounds", 10)
if waxFolder then waxFolder = waxFolder:WaitForChild("wax", 10) end
local waxSounds = {}
if waxFolder then
	for _, s in ipairs(waxFolder:GetChildren()) do
		if s:IsA("Sound") then table.insert(waxSounds, s) end
	end
else
	warn("wax klasoru bulunamadi!")
end
local lastSoundTime = 0
local SOUND_COOLDOWN = 0.05

-- ===== AYARLAR =====
local CHECK_INTERVAL = 0.05   -- temas kontrol sikligi (sn)
local CELL = 16               -- grid hucre boyutu (stud)
local H_MARGIN = 0.8          -- yatay temas payi
local SWEEP_STEP = 4          -- yuksek hizda iki kontrol arasindaki yol bu adimlarla taranir
local V_UP = 5                -- HRP merkezi puding merkezinden en fazla bu kadar + yari yukseklik yukarida
local V_DOWN = 4
local SQUISH_DURATION = 0.18
local RESTORE_DURATION = 0.25
local TARGET_Y_SCALE = 0.352

local squishInfo = TweenInfo.new(SQUISH_DURATION, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
local restoreInfo = TweenInfo.new(RESTORE_DURATION, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)

-- ===== SPATIAL GRID =====
local grid = {}          -- ["x,y,z"] = { record, ... }
local recordByPart = {}  -- [part] = record
local squished = {}      -- [record] = true (su an basili olanlar)

local function playRandomWax(part)
	if #waxSounds == 0 then return end
	if (os.clock() - lastSoundTime) < SOUND_COOLDOWN then return end
	lastSoundTime = os.clock()
	local chosen = waxSounds[math.random(1, #waxSounds)]
	local clone = chosen:Clone()
	clone.Parent = part
	clone:Play()
	Debris:AddItem(clone, chosen.TimeLength + 1)
end

local function addPudding(part)
	if not part:IsA("MeshPart") then return end
	if recordByPart[part] then return end
	local size, pos = part.Size, part.Position
	local squishY = size.Y * TARGET_Y_SCALE
	local rec = {
		part = part,
		hx = size.X / 2 + H_MARGIN,
		hz = size.Z / 2 + H_MARGIN,
		halfY = size.Y / 2,
		origSize = size,
		origPos = pos,
		squishSize = Vector3.new(size.X, squishY, size.Z),
		squishPos = Vector3.new(pos.X, pos.Y - size.Y / 2 + squishY / 2, pos.Z),
		tween = nil,
		key = nil,
	}
	local key = math.floor(pos.X / CELL) .. "," .. math.floor(pos.Y / CELL) .. "," .. math.floor(pos.Z / CELL)
	rec.key = key
	local bucket = grid[key]
	if not bucket then bucket = {}; grid[key] = bucket end
	table.insert(bucket, rec)
	recordByPart[part] = rec
end

local function removePudding(part)
	local rec = recordByPart[part]
	if not rec then return end
	recordByPart[part] = nil
	squished[rec] = nil
	if rec.tween then rec.tween:Cancel(); rec.tween = nil end
	local bucket = grid[rec.key]
	if bucket then
		for i, r in ipairs(bucket) do
			if r == rec then
				bucket[i] = bucket[#bucket]
				bucket[#bucket] = nil
				break
			end
		end
		if #bucket == 0 then grid[rec.key] = nil end
	end
end

-- Mevcut pudingler + StreamingEnabled ile sonradan gelen/giden pudingler
for _, d in ipairs(puddings:GetDescendants()) do
	addPudding(d)
end
puddings.DescendantAdded:Connect(addPudding)
puddings.DescendantRemoving:Connect(removePudding)

-- ===== TEMAS KONTROLU =====
local function inContact(rec, cpos)
	local p = rec.origPos
	if math.abs(cpos.X - p.X) > rec.hx then return false end
	if math.abs(cpos.Z - p.Z) > rec.hz then return false end
	local dy = cpos.Y - p.Y
	return dy > -V_DOWN and dy < (V_UP + rec.halfY)
end

local function setSquished(rec, on)
	if rec.tween then rec.tween:Cancel() end
	local goal
	if on then
		squished[rec] = true
		goal = { Size = rec.squishSize, Position = rec.squishPos }
		playRandomWax(rec.part)
	else
		squished[rec] = nil
		goal = { Size = rec.origSize, Position = rec.origPos }
	end
	local tw = TweenService:Create(rec.part, on and squishInfo or restoreInfo, goal)
	rec.tween = tw
	tw:Play()
end

-- Ana dongu
local function checkPoint(cpos)
	local bx = math.floor(cpos.X / CELL)
	local by = math.floor(cpos.Y / CELL)
	local bz = math.floor(cpos.Z / CELL)
	for dx = -1, 1 do
		for dy = -1, 1 do
			for dz = -1, 1 do
				local bucket = grid[(bx + dx) .. "," .. (by + dy) .. "," .. (bz + dz)]
				if bucket then
					for _, rec in ipairs(bucket) do
						if not squished[rec] and inContact(rec, cpos) then
							setSquished(rec, true)
						end
					end
				end
			end
		end
	end
end

local acc = 0
local lastPos = nil
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < CHECK_INTERVAL then return end
	acc = 0
	if not hrp or not hrp.Parent then lastPos = nil return end
	local cpos = hrp.Position

	-- Yuksek hizda arada kalan pudingler atlanmasin diye yol orneklenir;
	-- isinlanma gibi buyuk sicramalarda (60+ stud) sweep yapilmaz
	if lastPos then
		local delta = cpos - lastPos
		local dist = delta.Magnitude
		if dist > SWEEP_STEP and dist <= 60 then
			local steps = math.ceil(dist / SWEEP_STEP)
			for i = 1, steps - 1 do
				checkPoint(lastPos + delta * (i / steps))
			end
		end
	end
	lastPos = cpos
	checkPoint(cpos)

	-- basili olanlardan temasi bitenleri geri sisir
	for rec in pairs(squished) do
		if not inContact(rec, cpos) then
			setSquished(rec, false)
		end
	end
end)
