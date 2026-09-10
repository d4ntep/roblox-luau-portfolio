-- TutorialClient
-- Bes fazli tutorial diyalogu. Faz 1 ilk giriste, digerleri level/win
-- esiklerinde oynar. Hareket kilidi, typewriter metin, skip butonu ve
-- Faz 2'de win butonuna rehber ok icerir. Tamamlanan fazlar sunucuda kaydedilir.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local StarterGuiService = game:GetService("StarterGui")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local TutorialData = require(ReplicatedStorage:WaitForChild("TutorialData"))
local event = Remotes.event("TutorialEvent")

local TYPE_SPEED = TutorialData.TYPEWRITER_SPEED or 0.03
local rng = Random.new()

-- PlayerModule kontrolleri (hareket kilitleme)
local function getControls()
	local ok, controls = pcall(function()
		local pm = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
		return pm:GetControls()
	end)
	return ok and controls or nil
end

-- GPU warm-up: her gorselin 1x1 px kopyasi renderda tutulur, gecis boslugu olmaz
local warmupGui = nil

local function collectAllImages()
	local seen, list = {}, {}
	local function add(id)
		if id and not seen[id] then
			seen[id] = true
			table.insert(list, id)
		end
	end
	for _, step in ipairs(TutorialData.Steps) do add(step.image) end
	for _, step in ipairs(TutorialData.Phase2Steps or {}) do add(step.image) end
	for _, id in ipairs(TutorialData.RandomImagePool or {}) do add(id) end
	return list
end

local function createWarmup()
	if warmupGui then return end
	warmupGui = Instance.new("ScreenGui")
	warmupGui.Name = "__TutorialWarmup"
	warmupGui.ResetOnSpawn = false
	warmupGui.DisplayOrder = 1
	warmupGui.Parent = playerGui

	for _, id in ipairs(collectAllImages()) do
		local warm = Instance.new("ImageLabel")
		warm.Size = UDim2.fromOffset(1, 1)
		warm.AnchorPoint = Vector2.new(0, 1)
		warm.Position = UDim2.new(0, 0, 1, 0)
		warm.BackgroundTransparency = 1
		warm.ImageTransparency = 0.95
		warm.Image = id
		warm.Parent = warmupGui
	end
end

local function destroyWarmup()
	if warmupGui then
		warmupGui:Destroy()
		warmupGui = nil
	end
end

-- Kamera odaklama (Faz 4)
local savedCameraType = nil
local savedCameraCFrame = nil

local function focusCamera(targetCFrame)
	local cam = workspace.CurrentCamera
	savedCameraType = cam.CameraType
	savedCameraCFrame = cam.CFrame
	cam.CameraType = Enum.CameraType.Scriptable
	TweenService:Create(cam, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
		CFrame = targetCFrame
	}):Play()
end

local function restoreCamera()
	local cam = workspace.CurrentCamera
	if savedCameraType then
		TweenService:Create(cam, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
			CFrame = savedCameraCFrame
		}):Play()
		task.delay(1.5, function()
			cam.CameraType = savedCameraType or Enum.CameraType.Custom
			savedCameraType = nil
			savedCameraCFrame = nil
		end)
	end
end

local function handleCameraAction(action)
	if action == "focusPerky2" then
		local focusCF = TutorialData.Phase4CameraFocus
		if focusCF then focusCamera(focusCF) end
	elseif action == "restore" then
		restoreCamera()
	end
end

-- steps: { {text, image, imageHeight, onShown?, cameraAction?}, ... }
-- Skip'e basildiysa true doner
local function runDialogue(steps)
	local sourceGui = StarterGuiService:WaitForChild("firstencounter", 10)
	if not sourceGui then
		warn("[TutorialClient] StarterGui.firstencounter bulunamadi.")
		return false
	end

	local existing = playerGui:FindFirstChild("firstencounter")
	if existing then existing:Destroy() end

	local gui = sourceGui:Clone()
	gui.Enabled = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 900
	gui.Parent = playerGui

	local ensureSkipTouchSize -- skipButton alindiktan sonra tanimlanir
	local function applyUIScale()
		local vp = workspace.CurrentCamera.ViewportSize
		local s = gui:FindFirstChildOfClass("UIScale")
		if not s then s = Instance.new("UIScale") s.Parent = gui end
		s.Scale = math.clamp(math.min(vp.X / 1920, vp.Y / 1080), 0.35, 2.0) -- MAX 2.0: 4K TV uyumu
		if ensureSkipTouchSize then ensureSkipTouchSize() end
	end
	applyUIScale()
	local viewportConn = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applyUIScale)
	gui.Destroying:Connect(function()
		if viewportConn then viewportConn:Disconnect() viewportConn = nil end
	end)

	local chatbox     = gui:WaitForChild("chatbox", 5)
	local skipButton  = gui:WaitForChild("skipbutton", 5)
	local purinchan   = chatbox and chatbox:WaitForChild("purinchan", 5)
	local dialogeText = chatbox and chatbox:WaitForChild("dialougetext", 5)

	if not (chatbox and skipButton and purinchan and dialogeText) then
		warn("[TutorialClient] firstencounter icinde beklenen instance'lar eksik.")
		gui:Destroy()
		return false
	end

	-- Mobil: chatbox'i yatayda ortala
	chatbox.AnchorPoint = Vector2.new(0.5, 0)
	chatbox.Position = UDim2.new(0.5, 0, chatbox.Position.Y.Scale, chatbox.Position.Y.Offset)

	-- Mobil: skip butonu ekranda en az MIN_TOUCH_PX olsun
	local SKIP_BASE = math.max(skipButton.Size.X.Offset, 1)
	local MIN_TOUCH_PX = 44
	ensureSkipTouchSize = function()
		local s = gui:FindFirstChildOfClass("UIScale")
		local k = (s and s.Scale > 0) and s.Scale or 1
		local bs = skipButton:FindFirstChildOfClass("UIScale")
		if not bs then bs = Instance.new("UIScale") bs.Parent = skipButton end
		bs.Scale = math.max(1, MIN_TOUCH_PX / (SKIP_BASE * k))
	end
	ensureSkipTouchSize()

	purinchan.ScaleType = Enum.ScaleType.Fit
	local purinWidth = purinchan.Size.X.Offset
	local purinDefaultHeight = purinchan.Size.Y.Offset

	-- On-yuklu gorsel katmanlari
	local imageLayers = {}
	purinchan.Visible = false

	for _, step in ipairs(steps) do
		if step.image and not imageLayers[step.image] then
			local layer = purinchan:Clone()
			layer.Name = "purinLayer_" .. tostring(step.image):gsub("%D", "")
			layer.Image = step.image
			layer.Visible = false
			layer.Parent = chatbox
			imageLayers[step.image] = layer
		end
	end

	local function showImageLayer(assetId, imageHeight)
		for id, layer in pairs(imageLayers) do
			layer.Visible = (id == assetId)
			if id == assetId then
				layer.Size = UDim2.new(0, purinWidth, 0, imageHeight or purinDefaultHeight)
			end
		end
	end

	-- Ses
	local talkSound
	local soundOk = pcall(function()
		local srcSound = ReplicatedStorage.Assets.sounds.effects.purinchantalk
		talkSound = srcSound:Clone()
		talkSound.Parent = gui
	end)
	if not soundOk then
		warn("[TutorialClient] purinchantalk sesi bulunamadi, sessiz devam ediliyor.")
	end

	local function playTalk()
		if talkSound then
			talkSound:Stop()
			talkSound.TimePosition = 0
			talkSound:Play()
		end
	end
	local function stopTalk()
		if talkSound then talkSound:Stop() end
	end

	-- Tiklama overlay'i
	local overlay = Instance.new("TextButton")
	overlay.Name = "TutorialClickOverlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.Position = UDim2.fromScale(0, 0)
	overlay.BackgroundTransparency = 1
	overlay.Text = ""
	overlay.Modal = true
	overlay.AutoButtonColor = false
	overlay.ZIndex = 1
	overlay.Parent = gui

	chatbox.ZIndex = 5
	skipButton.ZIndex = 6

	-- Hareketi kilitle
	local controls = getControls()
	if controls then controls:Disable() end

	local typing = false
	local skipSentence = false
	local advanceRequested = false
	local skipAll = false

	overlay.Activated:Connect(function()
		if typing then
			skipSentence = true
		else
			advanceRequested = true
		end
	end)

	skipButton.Activated:Connect(function()
		skipAll = true
		skipSentence = true
		advanceRequested = true
	end)

	local function typeText(fullText)
		typing = true
		skipSentence = false
		dialogeText.Text = ""
		playTalk()

		local chars = {}
		for _, cp in utf8.codes(fullText) do
			table.insert(chars, utf8.char(cp))
		end

		local shown = ""
		for i = 1, #chars do
			if skipSentence or skipAll then
				break
			end
			shown = shown .. chars[i]
			dialogeText.Text = shown
			task.wait(TYPE_SPEED)
		end

		dialogeText.Text = fullText
		typing = false
		stopTalk()
	end

	for _, step in ipairs(steps) do
		if skipAll then break end
		showImageLayer(step.image, step.imageHeight)
		if step.onShown then task.spawn(step.onShown) end
		if step.cameraAction then task.spawn(handleCameraAction, step.cameraAction) end
		typeText(step.text)
		advanceRequested = false
		while not advanceRequested and not skipAll do
			task.wait(0.05)
		end
	end

	stopTalk()
	if controls then controls:Enable() end
	gui:Destroy()
	return skipAll
end

-- Rehber: oyuncudan highlight'li win butonuna uzanan ok beam'i (Faz 2)
local guideActive = false
local guideConnections = {}
local guideBeam, guideAtt0, guideAtt1, guideHighlight

local function findHighlightedWinButton()
	local folder = workspace:FindFirstChild("winbutton")
	if not folder then return nil, nil end
	for _, model in ipairs(folder:GetChildren()) do
		local hl = model:FindFirstChildWhichIsA("Highlight", true)
		if hl then
			local part = model:FindFirstChild("pluswin", true) or model:FindFirstChildWhichIsA("BasePart", true)
			return hl, part
		end
	end
	return nil, nil
end

local function deactivateGuide()
	if not guideActive then return end
	guideActive = false
	if guideHighlight then guideHighlight.Enabled = false end
	for _, conn in ipairs(guideConnections) do
		conn:Disconnect()
	end
	table.clear(guideConnections)
	if guideBeam then guideBeam:Destroy() guideBeam = nil end
	if guideAtt0 then guideAtt0:Destroy() guideAtt0 = nil end
	if guideAtt1 then guideAtt1:Destroy() guideAtt1 = nil end
end

local function attachGuideToCharacter(character)
	local root = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5)
	if not root or not guideBeam then return end
	if guideAtt0 then guideAtt0:Destroy() end
	guideAtt0 = Instance.new("Attachment")
	guideAtt0.Name = "TutorialGuideAttachment"
	guideAtt0.Parent = root
	guideBeam.Attachment1 = guideAtt0
end

local function activateGuide()
	if guideActive then return end
	local highlight, targetPart = findHighlightedWinButton()
	if not (highlight and targetPart) then
		warn("[TutorialClient] Highlight'li winbutton bulunamadi, rehber atlaniyor.")
		return
	end
	guideActive = true
	guideHighlight = highlight
	highlight.Enabled = true

	-- Hedef attachment (winbutton uzerinde)
	guideAtt1 = Instance.new("Attachment")
	guideAtt1.Name = "TutorialGuideTarget"
	guideAtt1.Parent = targetPart

	-- Hareketli ok beam'i (treadmill'lerle ayni texture/his)
	guideBeam = Instance.new("Beam")
	guideBeam.Name = "TutorialGuideBeam"
	guideBeam.Texture = "rbxassetid://10249261576"
	guideBeam.TextureSpeed = -3
	guideBeam.TextureLength = 4.65
	guideBeam.TextureMode = Enum.TextureMode.Static
	guideBeam.Width0 = 2.5
	guideBeam.Width1 = 2.5
	guideBeam.FaceCamera = true
	guideBeam.Transparency = NumberSequence.new(0.15)
	guideBeam.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80))
	guideBeam.Attachment0 = guideAtt1
	guideBeam.Parent = targetPart

	-- Oyuncu tarafi attachment (respawn'da yeniden baglanir)
	if player.Character then
		attachGuideToCharacter(player.Character)
	end
	table.insert(guideConnections, player.CharacterAdded:Connect(function(char)
		if guideActive then
			task.spawn(attachGuideToCharacter, char)
		end
	end))

	-- Alinma tespiti: Wins degeri artarsa buton alinmis demektir -> rehberi kapat
	local ls = player:FindFirstChild("leaderstats")
	local wins = ls and ls:FindFirstChild("Wins")
	if wins then
		local baseline = wins.Value
		table.insert(guideConnections, wins.Changed:Connect(function(newValue)
			if newValue > baseline then
				deactivateGuide()
			end
		end))
	end
end

-- Gorseli olmayan adimlara havuzdan rastgele gorsel ata (ust uste ayni gelmez)
local function resolveSteps(stepList)
	local pool = TutorialData.RandomImagePool or {}
	local resolved = {}
	local lastImage = nil
	for _, step in ipairs(stepList or {}) do
		local image = step.image
		if not image and #pool > 0 then
			repeat
				image = pool[rng:NextInteger(1, #pool)]
			until image ~= lastImage or #pool <= 1
		end
		lastImage = image
		table.insert(resolved, {
			text = step.text,
			image = image,
			imageHeight = step.imageHeight,
			onShown = step.onShown,
			cameraAction = step.cameraAction,
		})
	end
	return resolved
end

local function resolvePhase2Steps()
	local pool = TutorialData.RandomImagePool or {}
	local resolved = {}
	local lastImage = nil
	for _, step in ipairs(TutorialData.Phase2Steps or {}) do
		local image = step.image
		if not image and #pool > 0 then
			repeat
				image = pool[rng:NextInteger(1, #pool)]
			until image ~= lastImage or #pool <= 1
		end
		lastImage = image
		table.insert(resolved, {
			text = step.text,
			image = image,
			imageHeight = step.imageHeight,
			-- 3. cumle gorununce highlight + rehber ok aktiflesir
			onShown = (#resolved + 1 == 3) and activateGuide or nil,
		})
	end
	return resolved
end

-- Ana akis
local function runTutorial(completed)
	completed = completed or {}
	local function phaseCompleted(n) return completed[n] == true end
	local function markPhase(n) event:FireServer("phase_complete", n) end

	createWarmup()

	-- Loading screen bitene kadar bekle (sadece ENABLED olani say)
	local function activeLoadingExists()
		for _, c in ipairs(playerGui:GetChildren()) do
			if c.Name == "loadingscreen" and c:IsA("ScreenGui") and c.Enabled then
				return true
			end
		end
		return false
	end

	local waited = 0
	task.wait(1.5)
	while activeLoadingExists() and waited < 40 do
		task.wait(0.2)
		waited += 0.2
	end

	-- FAZ 1
	if not phaseCompleted(1) then
		runDialogue(TutorialData.Steps)
		markPhase(1)
	end

	-- FAZ 2: level esigini bekle
	local levelStat = player:WaitForChild("Level", 30)
	if not levelStat then
		warn("[TutorialClient] player.Level bulunamadi, Faz 2+ atlaniyor.")
		destroyWarmup()
		return
	end

	if not phaseCompleted(2) then
		local target = TutorialData.PHASE2_LEVEL or 4
		while levelStat.Value < target do
			levelStat.Changed:Wait()
		end
		runDialogue(resolvePhase2Steps())
		markPhase(2)
	end

	-- FAZ 3: ilk win alininca tetiklenir
	if not phaseCompleted(3) then
		local ls = player:FindFirstChild("leaderstats")
		local wins = ls and ls:FindFirstChild("Wins")
		if wins then
			local baseline3 = wins.Value
			while wins.Value <= baseline3 do
				wins.Changed:Wait()
			end
			runDialogue(resolveSteps(TutorialData.Phase3Steps))
			markPhase(3)
		else
			warn("[TutorialClient] leaderstats.Wins bulunamadi, Faz 3 atlaniyor.")
		end
	end

	-- FAZ 4: toplam 3 win'e ulasinca tetiklenir
	if not phaseCompleted(4) then
		local ls4 = player:FindFirstChild("leaderstats")
		local wins4 = ls4 and ls4:FindFirstChild("Wins")
		if wins4 then
			local target4 = TutorialData.PHASE4_WINS or 3
			if wins4.Value < target4 then
				while wins4.Value < target4 do
					wins4.Changed:Wait()
				end
			end

			local perky2 = workspace:FindFirstChild("winperks") and workspace.winperks:FindFirstChild("perky2")
			local perky2Highlight = nil
			if perky2 then
				perky2Highlight = perky2:FindFirstChildWhichIsA("Highlight")
				if not perky2Highlight then
					perky2Highlight = Instance.new("Highlight")
					perky2Highlight.Parent = perky2
				end
				perky2Highlight.Enabled = true
			end

			runDialogue(resolveSteps(TutorialData.Phase4Steps))
			markPhase(4)

			if perky2Highlight then perky2Highlight.Enabled = false end
			restoreCamera()
		end
	end

	-- FAZ 5: level 15'e ulasinca rebirth anlatimi
	if not phaseCompleted(5) then
		local levelStat5 = player:FindFirstChild("Level")
		if levelStat5 then
			local target5 = TutorialData.PHASE5_LEVEL or 15
			if levelStat5.Value < target5 then
				while levelStat5.Value < target5 do
					levelStat5.Changed:Wait()
				end
			end
			runDialogue(resolveSteps(TutorialData.Phase5Steps))
			markPhase(5)
		else
			warn("[TutorialClient] player.Level bulunamadi, Faz 5 atlaniyor.")
		end
	end

	destroyWarmup()
end

event.OnClientEvent:Connect(function(action, completed)
	if action == "show" then
		task.spawn(function()
			local ok, err = pcall(runTutorial, completed or {})
			if not ok then
				warn("[TutorialClient] runTutorial hata verdi, guvenli sekilde kapatiliyor: ", err)
				local okC, controls = pcall(getControls)
				if okC and controls then
					pcall(function() controls:Enable() end)
				end
				destroyWarmup()
				pcall(deactivateGuide)
				local fe = playerGui:FindFirstChild("firstencounter")
				if fe then fe:Destroy() end
			end
		end)
	end
end)

event:FireServer("request")
