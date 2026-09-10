-- WinButtonSystem
-- "WinButton" tag'li Part/Model'lere dokunan oyuncuya WinAmount attribute'u
-- kadar Win verir ve oyuncuyu spawn'a dondurur. Miktar her zaman sunucudaki
-- attribute'tan okunur. Obje icinde hazir bir BillboardGui varsa yazi ona
-- yazilir, yoksa basit bir billboard olusturulur.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GamePassIds = require(ReplicatedStorage:WaitForChild("GamePassIds"))
local GamePassCache = require(script.Parent.GamePassCache)
local SpawnTracker = require(script.Parent.SpawnTracker)

local TAG = "WinButton"
local DEBOUNCE_SECONDS = 1
local BILLBOARD_MAX_DISTANCE = 50

local debounce: {[number]: {[Instance]: boolean}} = {}

local function isDebounced(userId: number, button: Instance): boolean
	local map = debounce[userId]
	return map ~= nil and map[button] == true
end

local function setDebounce(userId: number, button: Instance)
	debounce[userId] = debounce[userId] or {}
	debounce[userId][button] = true
	task.delay(DEBOUNCE_SECONDS, function()
		if debounce[userId] then
			debounce[userId][button] = nil
		end
	end)
end

Players.PlayerRemoving:Connect(function(player)
	debounce[player.UserId] = nil
end)

local function findExistingLabel(root: Instance): TextLabel?
	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("BillboardGui") then
			local label = obj:FindFirstChildWhichIsA("TextLabel", true)
			if label then
				return label
			end
		end
	end
	return nil
end

local function createBillboard(part: BasePart, text: string)
	if part:FindFirstChild("WinAmountBillboard") then
		return
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "WinAmountBillboard"
	billboard.Size = UDim2.fromOffset(160, 50)
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	billboard.MaxDistance = BILLBOARD_MAX_DISTANCE
	billboard.AlwaysOnTop = true

	local label = Instance.new("TextLabel")
	label.Name = "AmountLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(255, 245, 200)
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.Parent = billboard
	billboard.Parent = part
end

-- WinAmount once objenin kendisinde, yoksa alt parcalarinda aranir
local function findWinAmount(button: Instance): number?
	local own = button:GetAttribute("WinAmount")
	if type(own) == "number" and own > 0 then
		return own
	end
	for _, child in ipairs(button:GetDescendants()) do
		local value = child:GetAttribute("WinAmount")
		if type(value) == "number" and value > 0 then
			return value
		end
	end
	return nil
end

local function setupButton(button: Instance)
	if not (button:IsA("BasePart") or button:IsA("Model")) then
		return
	end
	local amount = findWinAmount(button)
	if not amount then
		warn("[WinButtonSystem] WinAmount yok, 1 kullanildi: " .. button:GetFullName())
		amount = 1
	end

	local text = "+" .. amount .. " Win"
	local existing = findExistingLabel(button)
	if existing then
		existing.Text = text
	else
		local part = if button:IsA("BasePart") then button else button:FindFirstChildWhichIsA("BasePart", true)
		if part then
			createBillboard(part, text)
		end
	end

	local function onTouched(hit: BasePart)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player or isDebounced(player.UserId, button) then
			return
		end
		setDebounce(player.UserId, button)

		local leaderstats = player:FindFirstChild("leaderstats")
		local wins = leaderstats and leaderstats:FindFirstChild("Wins")
		if not wins then
			return
		end
		local multiplier = if GamePassCache.PlayerOwnsGamePass(player, GamePassIds.WIN_MULTIPLIER_2X) then 2 else 1
		wins.Value += amount * multiplier
		SpawnTracker.returnToSpawn(player)
	end

	if button:IsA("BasePart") then
		button.Touched:Connect(onTouched)
	else
		for _, part in ipairs(button:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Touched:Connect(onTouched)
			end
		end
	end
end

for _, button in ipairs(CollectionService:GetTagged(TAG)) do
	setupButton(button)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(setupButton)
