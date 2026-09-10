-- AngrypurinChaseClient
-- Labirent boss'u. PurinchanChaseClient ile ayni client-side desen: model her
-- oyuncunun kendi ekraninda klonlanir. Farklar: "notsafe2" alanina girince 5 sn
-- geri sayim, PathfindingService ile duvarlardan gecmeyen takip, boss muzigi.
-- Yakalanma sunucuda uygulanir (PurinchanServer).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local CHASE_SPEED = 230        -- stud/sn
local RETURN_SPEED = 230
local KILL_DISTANCE = 16       -- model ~33 stud genis; yatay mesafe
local WARNING_SECONDS = 5      -- alana girince geri sayim
local RECOMPUTE_INTERVAL = 0.5 -- yol yenileme araligi
local AGENT_RADIUS = 16        -- model yari genisligi; yolu koridor ortasinda tutar
local AGENT_HEIGHT = 10
local AGENT_CAN_JUMP = true    -- zemindeki kucuk basamaklar icin
local WAYPOINT_THRESHOLD = 3
local HOME_ARRIVE_THRESHOLD = 2

local LOS_CHECK_WIDTH = 12     -- merkez + iki yan ray; govde genis oldugu icin
local PREDICT_TIME = 0.3       -- hedefe oyuncu hizina gore ongoru

local HOP_HEIGHT = 1.5
local HOP_DURATION = 0.5
local LEAN_ANGLE = 14
local LEAN_RISE_FRACTION = 0.2
local FACING_YAW_OFFSET = 0    -- mesh'in onu yanlis bakiyorsa derece cinsinden duzelt

local JUMP_ALLOWANCE = 30      -- alanin ustunde bu kadar yukseklik hala "alanda"
local BELOW_ALLOWANCE = 5

local GROUND_CLEARANCE = 2     -- mesh'in gorunur tabani bounding box'tan yukarida
local GROUND_IGNORE_NAMES = {"Puddings"} -- zemin ararken ustune cikilmayacak dekorlar

local caughtRemote = Remotes.event("PurinchanCaught")

-- Model ReplicatedStorage sablonundan klonlanir; workspace'teki orijinal
-- StreamingEnabled yuzunden eksik gelebilir. Sablonun Mesh_0 CFrame'i home konumudur.
local template = ReplicatedStorage:WaitForChild("AngrypurinTemplate")
template:WaitForChild("Mesh_0")

-- Workspace'teki orijinal stream ile gelirse lokal olarak gizlenir
local function hideModelLocally(m)
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			p.LocalTransparencyModifier = 1
			p.CanCollide = false
			p.CanTouch = false
		end
	end
end
local existingOriginal = workspace:FindFirstChild("angrypurin2")
if existingOriginal then hideModelLocally(existingOriginal) end
workspace.ChildAdded:Connect(function(c)
	if c.Name == "angrypurin2" and c:IsA("Model") then
		task.defer(hideModelLocally, c)
	end
end)

local model = template:Clone()
model.Name = "Angrypurin_Local"
local mesh = model:WaitForChild("Mesh_0")
model.PrimaryPart = mesh
mesh.Anchored = true     -- fizik karismasin, CFrame ile suruyoruz
mesh.CanCollide = false  -- oyuncuyu itip jitter yaratmasin
mesh.CanTouch = false
mesh.CanQuery = false    -- raycast/pathfinding kendine takilmasin
model.Parent = workspace

local HOME_CFRAME = mesh.CFrame
local HOME_LOOK_VECTOR = HOME_CFRAME.LookVector
model:PivotTo(HOME_CFRAME)

-- Zemine yapisma: mesh her frame altindaki zemine raycast ile hizalanir;
-- streaming ile gec gelen zemin ve engebeli labirent icin sabit offset yetmez.
local groundRayParams = RaycastParams.new()
groundRayParams.FilterType = Enum.RaycastFilterType.Exclude
local function refreshGroundFilter()
	local filter = { model }
	local wsOriginal = workspace:FindFirstChild("angrypurin2")
	if wsOriginal then table.insert(filter, wsOriginal) end
	local char = localPlayer.Character
	if char then table.insert(filter, char) end
	-- Puddings vb. dekorlari disla: boss onlarin tepesine cikmasin, altindaki gercek
	-- zemini takip etsin (klasor eklemek tum descendant'larini otomatik disar).
	for _, name in ipairs(GROUND_IGNORE_NAMES) do
		local inst = workspace:FindFirstChild(name)
		if inst then table.insert(filter, inst) end
	end
	groundRayParams.FilterDescendantsInstances = filter
end
refreshGroundFilter()
localPlayer.CharacterAdded:Connect(refreshGroundFilter)

-- Verilen XZ'nin altindaki zemin Y'si (yoksa nil). Boss'un kendini/orijinali/oyuncuyu disar.
local function groundYAt(x, z, fromY)
	local origin = Vector3.new(x, (fromY or 0) + 60, z)
	local hit = workspace:Raycast(origin, Vector3.new(0, -400, 0), groundRayParams)
	return hit and hit.Position.Y or nil
end

-- Mesh merkezinin zeminden yuksekligi home'da bir kez olculur
local VISUAL_OFFSET = mesh.Size.Y / 2
local visualOffsetCalibrated = false
local function calibrateVisualOffset()
	if visualOffsetCalibrated then return end
	local gY = groundYAt(HOME_CFRAME.Position.X, HOME_CFRAME.Position.Z, HOME_CFRAME.Position.Y)
	if gY then
		VISUAL_OFFSET = HOME_CFRAME.Position.Y - gY
		visualOffsetCalibrated = true
	end
end
calibrateVisualOffset()

-- Verilen XZ'yi zemine yapistiran mantiksal konum (zemin yoksa fallback Y korunur)
local function groundedPos(x, z, fallbackY)
	calibrateVisualOffset()
	local gY = groundYAt(x, z, fallbackY)
	if gY then
		return Vector3.new(x, gY + VISUAL_OFFSET + GROUND_CLEARANCE, z)
	end
	return Vector3.new(x, fallbackY, z)
end

-- Idle ile kovalama ayni yukseklikte kalsin diye home'a da clearance eklenir
local function homeRenderCFrame()
	return HOME_CFRAME + Vector3.new(0, GROUND_CLEARANCE, 0)
end

-- Home'un zemin hedefi (pathfinding icin), canli hesaplanir
local function getHomeGround()
	local gY = groundYAt(HOME_CFRAME.Position.X, HOME_CFRAME.Position.Z, HOME_CFRAME.Position.Y)
	return Vector3.new(HOME_CFRAME.Position.X,
		gY or (HOME_CFRAME.Position.Y - VISUAL_OFFSET),
		HOME_CFRAME.Position.Z)
end

-- Alan (notsafe2): streaming yuzunden init'te beklenmez, referans canli tutulur
local zonePart = workspace:FindFirstChild("notsafe2")

local function trackZone(obj)
	if obj.Name == "notsafe2" and obj:IsA("BasePart") then
		zonePart = obj
	end
end
workspace.ChildAdded:Connect(trackZone)
workspace.DescendantAdded:Connect(trackZone)

local function isInZone(worldPos)
	if not (zonePart and zonePart.Parent) then
		-- Stream-out olduysa canli referansi tazele
		zonePart = workspace:FindFirstChild("notsafe2")
		if not zonePart then return false end
	end
	local localPos = zonePart.CFrame:PointToObjectSpace(worldPos)
	local half = zonePart.Size / 2
	return math.abs(localPos.X) <= half.X
		and math.abs(localPos.Z) <= half.Z
		and localPos.Y >= -half.Y - BELOW_ALLOWANCE
		and localPos.Y <= half.Y + JUMP_ALLOWANCE
end

-- Boss muzigi (lokal klon, fade in/out)
local musicTemplate = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("sounds")
	:WaitForChild("bossmusic"):WaitForChild("bossmusic")
local music = musicTemplate:Clone()
local MUSIC_VOLUME = music.Volume > 0 and music.Volume or 0.5
music.Looped = true
music.Volume = 0
music.Parent = SoundService

local function playMusic()
	if not music.IsPlaying then music:Play() end
	TweenService:Create(music, TweenInfo.new(0.5), { Volume = MUSIC_VOLUME }):Play()
end

local function stopMusic()
	local t = TweenService:Create(music, TweenInfo.new(0.8), { Volume = 0 })
	t:Play()
	t.Completed:Once(function()
		if music.Volume <= 0.01 then music:Stop() end
	end)
end

-- Geri sayim popup'i (announcementgui.BossIncoming)
local function runCountdownPopups(seconds, isCancelled)
	local gui = playerGui:WaitForChild("announcementgui", 10)
	local banner = gui and gui:WaitForChild("BossIncoming", 5)
	local cooldownLabel = banner and banner:WaitForChild("cooldown", 5)
	local popScale = banner and banner:FindFirstChild("PopScale")

	for s = seconds, 1, -1 do
		if isCancelled() then break end

		if banner then
			if cooldownLabel then cooldownLabel.Text = tostring(s) end
			banner.GroupTransparency = 1
			banner.Visible = true
			if popScale then
				popScale.Scale = 0.5
				TweenService:Create(popScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			end
			TweenService:Create(banner, TweenInfo.new(0.15), { GroupTransparency = 0 }):Play()
		end

		task.wait(0.6)
		if banner then
			TweenService:Create(banner, TweenInfo.new(0.3), { GroupTransparency = 1 }):Play()
		end
		task.wait(0.4) -- toplam ~1 sn / rakam
	end

	if banner then
		banner.Visible = false
		banner.GroupTransparency = 0
	end
end

-- Durum makinesi: idle -> warning -> chasing -> returning -> idle
local state = {
	mode = "idle",
	basePosition = HOME_CFRAME.Position, -- hop olmadan gercek/mantiksal pivot konumu
	lastDirection = HOME_LOOK_VECTOR,
	hopTime = 0,
	killCooldown = 0,
	waypoints = nil,      -- aktif yol (Path:GetWaypoints() sonucu)
	waypointIndex = 1,
	pathPurpose = nil,    -- "player" | "home"
	recomputeTimer = math.huge, -- kovalamada hemen ilk hesap yapilsin
	homeRetryTimer = 0,
	homeFailCount = 0,
}

local warningGeneration = 0

-- Gorus hatti aciksa pathfinding atlanir ve boss her frame dogrudan oyuncuya
-- yonelir (yol yenileme gecikmesi olmadigi icin yan cizerek kacilamaz).
-- Duvar varsa pathfinding devrede kalir.
local losParams = RaycastParams.new()
losParams.FilterType = Enum.RaycastFilterType.Exclude
losParams.RespectCanCollide = true -- collide olmayan dekorlar (hali, yastik, teleport) engel sayilmaz
local function refreshLosFilter()
	local filter = { model }
	local wsOriginal = workspace:FindFirstChild("angrypurin2")
	if wsOriginal then table.insert(filter, wsOriginal) end
	local char = localPlayer.Character
	if char then table.insert(filter, char) end
	local zp = workspace:FindFirstChild("notsafe2")
	if zp then table.insert(filter, zp) end -- zone parti collide=true, engel sanilmasin
	for _, name in ipairs(GROUND_IGNORE_NAMES) do
		local inst = workspace:FindFirstChild(name)
		if inst then table.insert(filter, inst) end
	end
	losParams.FilterDescendantsInstances = filter
end
refreshLosFilter()
localPlayer.CharacterAdded:Connect(refreshLosFilter)

local function hasLineOfSight(targetPos)
	local from = Vector3.new(state.basePosition.X, targetPos.Y, state.basePosition.Z)
	local delta = targetPos - from
	if delta.Magnitude < 1 then return true end
	local dir = delta.Unit
	local side = Vector3.new(-dir.Z, 0, dir.X) -- yatay dik vektor
	for _, off in ipairs({ 0, LOS_CHECK_WIDTH, -LOS_CHECK_WIDTH }) do
		local o = side * off
		if workspace:Raycast(from + o, delta, losParams) then
			return false
		end
	end
	return true
end

-- Oyuncu konumuna hiz bazli ongoru; duvara denk gelirse gerisine kirpilir
local function predictedPlayerPos(hrp)
	local vel = hrp.AssemblyLinearVelocity
	local flatVel = Vector3.new(vel.X, 0, vel.Z)
	if flatVel.Magnitude < 5 then return hrp.Position end
	local offset = flatVel * PREDICT_TIME
	local hit = workspace:Raycast(hrp.Position, offset, losParams)
	if hit then
		local dir = offset.Unit
		return hit.Position - dir * 3
	end
	return hrp.Position + offset
end

local computing = false
local function requestPath(targetGroundPos, purpose)
	if computing then return end
	computing = true
	task.spawn(function()
		local path = PathfindingService:CreatePath({
			AgentRadius = AGENT_RADIUS,
			AgentHeight = AGENT_HEIGHT,
			AgentCanJump = AGENT_CAN_JUMP,
		})
		local sgY = groundYAt(state.basePosition.X, state.basePosition.Z, state.basePosition.Y)
		local startGround = Vector3.new(state.basePosition.X,
			sgY or (state.basePosition.Y - VISUAL_OFFSET),
			state.basePosition.Z)
		local ok = pcall(function()
			path:ComputeAsync(startGround, targetGroundPos)
		end)
		computing = false

		-- Hesap suresince mod degistiyse sonucu cope at
		if purpose == "player" and state.mode ~= "chasing" then return end
		if purpose == "home" and state.mode == "chasing" then return end

		if ok and path.Status == Enum.PathStatus.Success then
			local wps = path:GetWaypoints()
			if #wps > 1 then
				-- Hesap surerken boss ilerlemis olabilir; guncel konuma en yakin
				-- waypoint'ten devam edilir, yoksa geri donup baslangica gider.
				local bestIdx, bestDist = 2, math.huge
				local curXZ = Vector2.new(state.basePosition.X, state.basePosition.Z)
				for i = 2, #wps do
					local wpXZ = Vector2.new(wps[i].Position.X, wps[i].Position.Z)
					local d = (wpXZ - curXZ).Magnitude
					if d < bestDist then
						bestDist = d
						bestIdx = i
					end
				end
				state.waypoints = wps
				state.waypointIndex = bestIdx
				state.pathPurpose = purpose
				if purpose == "home" then state.homeFailCount = 0 end
				return
			end
		end

		-- Yol bulunamadi: duvar icinden GECME, bekle/yeniden dene
		if state.pathPurpose == purpose then
			state.waypoints = nil
		end
		if purpose == "home" then
			state.homeFailCount += 1
		end
	end)
end

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

local function followWaypoints(speed, dt)
	local wps = state.waypoints
	if not wps then return false end
	local wp = wps[state.waypointIndex]
	if not wp then
		state.waypoints = nil
		return false
	end
	-- Sadece XZ'de ilerle; Y her frame zemine yapistirilir
	local cur = state.basePosition
	local targetXZ = Vector3.new(wp.Position.X, cur.Y, wp.Position.Z)
	local newPos, direction, dist = advanceTowards(cur, targetXZ, speed, dt)
	if direction then
		local flat = Vector3.new(direction.X, 0, direction.Z)
		if flat.Magnitude > 0.01 then state.lastDirection = flat.Unit end
	end
	state.basePosition = groundedPos(newPos.X, newPos.Z, cur.Y)
	if dist <= WAYPOINT_THRESHOLD then
		state.waypointIndex += 1
	end
	return true
end

-- basePosition + hop/lean gorselini mesh'e uygula
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
	mesh.CFrame = CFrame.new(visualPos, visualPos + lookDir)
		* CFrame.Angles(0, math.rad(FACING_YAW_OFFSET), 0)
		* CFrame.Angles(math.rad(-leanAngle), 0, 0)
end

local function startChase()
	state.mode = "chasing"
	state.waypoints = nil
	state.pathPurpose = nil
	state.recomputeTimer = math.huge -- ilk frame'de hemen yol hesapla
	playMusic()
end

local function stopChaseAndReturn()
	if state.mode == "chasing" then stopMusic() end
	state.mode = "returning"
	state.waypoints = nil
	state.pathPurpose = nil
	state.homeRetryTimer = 0
	state.homeFailCount = 0
end

local function isPlayerInZoneAlive()
	local character = localPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (hrp and humanoid and humanoid.Health > 0) then return false end
	return isInZone(hrp.Position)
end

local function startWarning()
	state.mode = "warning"
	warningGeneration += 1
	local gen = warningGeneration
	task.spawn(function()
		runCountdownPopups(WARNING_SECONDS, function()
			return gen ~= warningGeneration or not isPlayerInZoneAlive()
		end)
		if gen ~= warningGeneration then return end
		if state.mode ~= "warning" then return end

		if isPlayerInZoneAlive() then
			startChase()
		else
			-- Sayim sirasinda alandan cikti/oldu: kovalamadan eve don
			stopChaseAndReturn()
		end
	end)
end

-- Ana dongu
RunService.Heartbeat:Connect(function(dt)
	state.killCooldown = math.max(0, state.killCooldown - dt)

	local character = localPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local alive = hrp and humanoid and humanoid.Health > 0
	local inZone = alive and isInZone(hrp.Position) or false

	local moving = false

	if state.mode == "idle" then
		if inZone then
			startWarning()
		end

	elseif state.mode == "warning" then
		-- Sayim coroutine'de; bu sirada yarim kalmis eve donus varsa surdur
		if state.pathPurpose == "home" and state.waypoints then
			moving = followWaypoints(RETURN_SPEED, dt)
		end

	elseif state.mode == "chasing" then
		if not inZone then
			-- Oyuncu alandan cikti ya da oldu: birak, eve don
			stopChaseAndReturn()
		else
			if hasLineOfSight(hrp.Position) then
				state.waypoints = nil
				state.pathPurpose = nil
				state.recomputeTimer = math.huge -- LOS kaybolursa ilk frame'de hemen yol hesaplansin
				local cur = state.basePosition
				local targetXZ = Vector3.new(hrp.Position.X, cur.Y, hrp.Position.Z)
				local newPos, direction, dist = advanceTowards(cur, targetXZ, CHASE_SPEED, dt)
				if direction then
					local flat = Vector3.new(direction.X, 0, direction.Z)
					if flat.Magnitude > 0.01 then state.lastDirection = flat.Unit end
				end
				state.basePosition = groundedPos(newPos.X, newPos.Z, cur.Y)
				moving = dist > 0.05
			else
				state.recomputeTimer = (state.recomputeTimer == math.huge) and math.huge or state.recomputeTimer + dt
				if state.recomputeTimer >= RECOMPUTE_INTERVAL or state.recomputeTimer == math.huge then
					state.recomputeTimer = 0
					requestPath(predictedPlayerPos(hrp), "player")
				end

				moving = followWaypoints(CHASE_SPEED, dt)
			end

			-- Yakalama kontrolu (yatay mesafe)
			local flatDelta = Vector3.new(
				state.basePosition.X - hrp.Position.X, 0,
				state.basePosition.Z - hrp.Position.Z)
			if flatDelta.Magnitude <= KILL_DISTANCE and state.killCooldown <= 0 then
				state.killCooldown = 2
				caughtRemote:FireServer() -- olum sunucuda uygulanir
				stopChaseAndReturn()
			end
		end

	elseif state.mode == "returning" then
		if inZone then
			-- Oyuncu tekrar girdi: eve yurumeye devam ederken sayim yeniden baslar
			startWarning()
		else
			local distHome = (state.basePosition - HOME_CFRAME.Position).Magnitude
			if distHome <= HOME_ARRIVE_THRESHOLD then
				-- Vardi: tam yerine otur
				state.basePosition = HOME_CFRAME.Position
				state.waypoints = nil
				state.pathPurpose = nil
				state.hopTime = 0
				state.mode = "idle"
				mesh.CFrame = homeRenderCFrame()
			else
				-- Eve giden yol yoksa hesapla (basarisizsa periyodik yeniden dene)
				if state.pathPurpose ~= "home" or not state.waypoints then
					state.homeRetryTimer += dt
					if state.homeRetryTimer >= 1 or state.pathPurpose ~= "home" then
						state.homeRetryTimer = 0
						requestPath(getHomeGround(), "home")
					end
					-- Cok uzun sure yol bulunamadiysa (sikisti) guvenli cikis: eve isinla
					if state.homeFailCount >= 6 then
						state.basePosition = HOME_CFRAME.Position
						state.mode = "idle"
						state.hopTime = 0
						mesh.CFrame = homeRenderCFrame()
					end
				else
					moving = followWaypoints(RETURN_SPEED, dt)
					-- Yol bitti ama henuz evde degil: yeniden hesaplat
					if not moving then
						state.pathPurpose = nil
					end
				end
			end
		end
	end

	if moving then
		state.hopTime = (state.hopTime + dt) % HOP_DURATION
		applyHopVisual()
	elseif state.mode == "idle" then
		mesh.CFrame = homeRenderCFrame()
	end
end)
