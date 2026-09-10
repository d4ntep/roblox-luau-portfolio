-- TeleportGuiClient
-- Stage warp menusu: stagelist icindeki satirlari StageData ile doldurur,
-- Robux fiyatlarini sunucudan alir. Menu "teleportdetector" alaninda acilir.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MenuController = require(ReplicatedStorage:WaitForChild("MenuController"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local StageData = require(ReplicatedStorage:WaitForChild("StageData"))

local player = Players.LocalPlayer

local buyStageEvent = Remotes.event("BuyStageWins")
local promptRobuxEvent = Remotes.event("PromptStageRobux")
local resultEvent = Remotes.event("StagePurchaseResult")
local getRobuxPricesFunc = Remotes.func("GetStageRobuxPrices")

local gui = script.Parent
local menuFrame = gui:WaitForChild("menu")
local buttonFrame = gui:WaitForChild("button")
local chocodrip = gui:WaitForChild("chocodrip")
local closeBtn = gui:WaitForChild("closebutton")
local list = menuFrame:WaitForChild("stagelist")

local menu = MenuController.createSlideMenu({
	name = "teleportgui",
	gui = gui,
	parts = {menuFrame, chocodrip, closeBtn},
	openButton = buttonFrame,
	closeButton = closeBtn,
})

-- Satirlar ----------------------------------------------------------------

local ROW_COUNT = 10
local CLICK_GUARD = 0.4
local lastRowClick = {}
local winPriceLabels = {}
local robuxPriceLabels = {}

local function rowGuard(stageNumber: number): boolean
	local now = os.clock()
	if lastRowClick[stageNumber] and now - lastRowClick[stageNumber] < CLICK_GUARD then
		return false
	end
	lastRowClick[stageNumber] = now
	return true
end

local function winPriceText(def): string
	return if def.winsPrice <= 0 then "FREE" else StageData.FormatNumber(def.winsPrice)
end

for i = 1, ROW_COUNT do
	local def = StageData.getByNumber(i)
	local row = list:FindFirstChild("stagerow" .. i)
	if def and row then
		local winOuter = row:FindFirstChild("winbuy")
		local winBtn = winOuter and winOuter:FindFirstChild("winbuy")
		if winBtn then
			local price = winBtn:FindFirstChild("price")
			if price then
				price.Text = winPriceText(def)
				winPriceLabels[i] = price
			end
			winBtn.Activated:Connect(function()
				if rowGuard(i) then
					buyStageEvent:FireServer(i)
				end
			end)
		end

		local robuxOuter = row:FindFirstChild("robuxbuy")
		local robuxBtn = robuxOuter and robuxOuter:FindFirstChild("robuxbuy")
		if robuxOuter and robuxBtn then
			robuxOuter.Visible = def.productId ~= 0
			local price = robuxBtn:FindFirstChild("price")
			if price then
				price.Text = tostring(def.robuxPrice)
				robuxPriceLabels[i] = price
			end
			robuxBtn.Activated:Connect(function()
				if rowGuard(i) then
					promptRobuxEvent:FireServer(i)
				end
			end)
		end
	end
end

-- Gercek Robux fiyatlari gelene kadar StageData'daki tahmin gosterilir
task.spawn(function()
	local ok, prices = pcall(function()
		return getRobuxPricesFunc:InvokeServer()
	end)
	if ok and type(prices) == "table" then
		for stageNumber, price in pairs(prices) do
			local label = robuxPriceLabels[stageNumber]
			if label then
				label.Text = tostring(price)
			end
		end
	end
end)

-- Basarisiz sonucta Win fiyat etiketinde kisa mesaj
local resultToken = 0
resultEvent.OnClientEvent:Connect(function(ok, message, stageNumber)
	local label = winPriceLabels[stageNumber]
	local def = StageData.getByNumber(stageNumber)
	if ok or not (label and def) then
		return
	end
	resultToken += 1
	local token = resultToken
	label.Text = message
	task.delay(1.2, function()
		if token == resultToken then
			label.Text = winPriceText(def)
		end
	end)
end)

-- Bolge tetikleme ----------------------------------------------------------

local wasInside = false
player.CharacterAdded:Connect(function()
	wasInside = false
end)

task.spawn(function()
	local detector = workspace:WaitForChild("teleportdetector", 30)
	if not detector then
		warn("[TeleportGuiClient] teleportdetector bulunamadi")
		return
	end
	local function isInside(): boolean
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root then
			return false
		end
		local localPos = detector.CFrame:PointToObjectSpace(root.Position)
		local half = detector.Size / 2
		return math.abs(localPos.X) <= half.X and math.abs(localPos.Y) <= half.Y and math.abs(localPos.Z) <= half.Z
	end
	while true do
		local inside = isInside()
		if inside and not wasInside then
			wasInside = true
			menu.open()
		elseif not inside and wasInside then
			wasInside = false
			menu.close()
		end
		task.wait(0.15)
	end
end)
