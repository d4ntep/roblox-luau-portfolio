-- WinMultiplierBillboardClient
-- 2X Win pass sahibi oyunculara, win butonlarinin ustundeki "+X Win" yazisini
-- "+X Win (2X!)" olarak gosterir. Client-side property degisikligi oldugu icin
-- SADECE bu oyuncunun ekraninda gorunur, diger oyuncularin gordugu yaziyi etkilemez.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local WIN_BUTTON_TAG = "WinButton"
local player = Players.LocalPlayer

local function findExistingAmountLabel(root)
	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("BillboardGui") then
			local label = obj:FindFirstChildWhichIsA("TextLabel", true)
			if label then return label end
		end
	end
	return nil
end

local function waitForLabel(button, timeout)
	timeout = timeout or 5
	local label = findExistingAmountLabel(button)
	local elapsed = 0
	while not label and elapsed < timeout do
		task.wait(0.1)
		elapsed += 0.1
		label = findExistingAmountLabel(button)
	end
	return label
end

local function refreshButtonLabel(button)
	if not player:GetAttribute("Owns2XWinPass") then return end

	local amount = button:GetAttribute("WinAmount") or 1
	local label = waitForLabel(button)
	if label then
		label.Text = "+" .. tostring(amount) .. " Win (2X!)"
	end
end

local function refreshAll()
	for _, button in ipairs(CollectionService:GetTagged(WIN_BUTTON_TAG)) do
		task.spawn(refreshButtonLabel, button)
	end
end

player:GetAttributeChangedSignal("Owns2XWinPass"):Connect(refreshAll)
CollectionService:GetInstanceAddedSignal(WIN_BUTTON_TAG):Connect(refreshButtonLabel)

refreshAll()
