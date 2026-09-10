-- ItemShopClient
-- Item Shop GUI'sini sunucu verisiyle doldurur: slotlar, slot4 rarity temasi,
-- stok, fiyatlar, restock sayaci ve satin alma butonlari. Menu, oyuncu
-- "itemshopdetector" alanina girince acilir, cikinca kapanir.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ItemShopData = require(ReplicatedStorage:WaitForChild("ItemShopData"))
local MenuController = require(ReplicatedStorage:WaitForChild("MenuController"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local player = Players.LocalPlayer

local getShopFunc = Remotes.func("GetItemShop")
local shopUpdatedEvent = Remotes.event("ItemShopUpdated")
local stockChangedEvent = Remotes.event("ItemShopStock")
local buyEvent = Remotes.event("BuyShopItem")
local promptRobuxEvent = Remotes.event("PromptShopRobux")
local promptRestockEvent = Remotes.event("PromptShopRestock")
local shopResultEvent = Remotes.event("ShopPurchaseResult")

local gui = script.Parent
local shopFrame = gui:WaitForChild("itemshop")
local itemsFrame = shopFrame:WaitForChild("items")
local closeBtn = shopFrame:WaitForChild("closebutton")
local restockLabel = shopFrame:FindFirstChild("restocktxt", true)
local restockButtonFrame = shopFrame:FindFirstChild("restockbutton", true)
local restockButton = restockButtonFrame and restockButtonFrame:FindFirstChild("restockbutton")

local slots = {}
for i = 1, 4 do
	slots[i] = itemsFrame:WaitForChild("slot" .. i)
end

local currentData = nil

-- Pop animasyonu icin slot anchor'larini ortala
local originalSizes = {}
for i, slot in ipairs(slots) do
	local anchor, size, pos = slot.AnchorPoint, slot.Size, slot.Position
	slot.Position = UDim2.new(
		pos.X.Scale, pos.X.Offset + size.X.Offset * (0.5 - anchor.X),
		pos.Y.Scale, pos.Y.Offset + size.Y.Offset * (0.5 - anchor.Y)
	)
	slot.AnchorPoint = Vector2.new(0.5, 0.5)
	originalSizes[i] = size
end

-- Slot yardimcilari ------------------------------------------------------

local function getButton(slot: Instance, name: string)
	local frame = slot:FindFirstChild(name)
	return frame and frame:FindFirstChild(name)
end

local slot4 = slots[4]
local slot4Stroke = slot4:FindFirstChild("UIStroke")
local slot4Gradient = slot4Stroke and slot4Stroke:FindFirstChild("UIGradient")

local function applySlot4Theme(rarity: string)
	local theme = ItemShopData.RarityThemes[rarity]
	if not theme then
		return
	end
	local bg = slot4:FindFirstChild("raritybg")
	if bg then
		bg.Image = theme.bg
	end
	if slot4Stroke then
		slot4Stroke.Color = theme.strokeColor
	end
	local rarityText = slot4:FindFirstChild("raritytxt")
	if rarityText then
		rarityText.Text = rarity
		rarityText.TextColor3 = theme.textColor
	end
	-- Uc ton birkac kez tekrarlanir; donerken renk daha sik degisir
	if slot4Gradient and theme.gradient then
		local REPEATS = 3
		local points = {}
		for r = 0, REPEATS - 1 do
			local start = r / REPEATS
			local len = 1 / REPEATS
			table.insert(points, ColorSequenceKeypoint.new(start, theme.gradient[1]))
			table.insert(points, ColorSequenceKeypoint.new(start + len / 3, theme.gradient[2]))
			table.insert(points, ColorSequenceKeypoint.new(start + len * 2 / 3, theme.gradient[3]))
		end
		table.insert(points, ColorSequenceKeypoint.new(1, theme.gradient[1]))
		slot4Gradient.Color = ColorSequence.new(points)
	end
end

if slot4Gradient then
	RunService.RenderStepped:Connect(function(dt)
		slot4Gradient.Rotation = (slot4Gradient.Rotation + dt * 50) % 360
	end)
end

-- Robux alimlari stoktan bagimsiz oldugu icin "tukendi" gorseli sadece Win butonunu etkiler
local function setSoldOut(slot: Instance, soldOut: boolean)
	local icon = slot:FindFirstChild("itemlb")
	if icon then
		icon.ImageColor3 = if soldOut then Color3.fromRGB(120, 120, 120) else Color3.new(1, 1, 1)
	end
	local winBtn = getButton(slot, "winbuy")
	if winBtn then
		winBtn.AutoButtonColor = not soldOut
	end
end

local function populateSlot(i: number, data)
	local slot = slots[i]
	local icon = slot:FindFirstChild("itemlb")
	if icon then
		icon.Image = data.icon
		local nameLabel = icon:FindFirstChild("itemname")
		if nameLabel then
			nameLabel.Text = data.name
		end
		local speedLabel = icon:FindFirstChild("itemspeed")
		if speedLabel then
			speedLabel.Text = "+%" .. data.speedBonus .. " Speed"
		end
	end
	local stockLabel = slot:FindFirstChild("stocktxt")
	if stockLabel then
		stockLabel.Text = data.currentStock .. "/" .. data.maxStock
	end
	local winBtn = getButton(slot, "winbuy")
	local winPrice = winBtn and winBtn:FindFirstChild("price")
	if winPrice then
		winPrice.Text = ItemShopData.FormatNumber(data.winsPrice)
	end
	local robuxBtn = getButton(slot, "robuxbuy")
	local robuxPrice = robuxBtn and robuxBtn:FindFirstChild("price")
	if robuxPrice then
		robuxPrice.Text = tostring(data.robuxPrice)
	end
	if i == 4 then
		applySlot4Theme(data.rarity)
	end
	setSoldOut(slot, data.currentStock <= 0)
end

local function populateAll(packet)
	currentData = packet
	for i = 1, 4 do
		if packet.slots[i] then
			populateSlot(i, packet.slots[i])
		end
	end
end

-- Restock: slotlar kuculur, veri yenilenir, buyur
local animating = false
local function restockAnimation(packet)
	if animating then
		populateAll(packet)
		return
	end
	animating = true
	local outInfo = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	local inInfo = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	for _, slot in ipairs(slots) do
		TweenService:Create(slot, outInfo, {Size = UDim2.new()}):Play()
	end
	task.wait(0.55)
	populateAll(packet)
	for i, slot in ipairs(slots) do
		TweenService:Create(slot, inInfo, {Size = originalSizes[i]}):Play()
	end
	task.wait(0.45)
	animating = false
end

-- Satin alma sonucu: ilgili slotun Win fiyat etiketinde kisa mesaj
local resultToken = 0
local function showResult(slotIndex: number, message: string)
	local slot = slots[slotIndex]
	local winBtn = slot and getButton(slot, "winbuy")
	local priceLabel = winBtn and winBtn:FindFirstChild("price")
	if not priceLabel then
		return
	end
	resultToken += 1
	local token = resultToken
	priceLabel.Text = message
	task.delay(1.2, function()
		if token == resultToken and currentData and currentData.slots[slotIndex] then
			priceLabel.Text = ItemShopData.FormatNumber(currentData.slots[slotIndex].winsPrice)
		end
	end)
end

-- Butonlar --------------------------------------------------------------

for i, slot in ipairs(slots) do
	local winBtn = getButton(slot, "winbuy")
	if winBtn then
		winBtn.Activated:Connect(function()
			local data = currentData and currentData.slots[i]
			if data and data.currentStock > 0 then
				buyEvent:FireServer(i)
			end
		end)
	end
	local robuxBtn = getButton(slot, "robuxbuy")
	if robuxBtn then
		robuxBtn.Activated:Connect(function()
			if currentData and currentData.slots[i] then
				promptRobuxEvent:FireServer(i)
			end
		end)
	end
end

if restockButton then
	restockButton.Activated:Connect(function()
		promptRestockEvent:FireServer()
	end)
	restockButton.MouseEnter:Connect(MenuController.playHover)
end

-- Sunucu olaylari --------------------------------------------------------

shopUpdatedEvent.OnClientEvent:Connect(restockAnimation)

stockChangedEvent.OnClientEvent:Connect(function(slotIndex, newStock)
	local data = currentData and currentData.slots[slotIndex]
	if not data then
		return
	end
	data.currentStock = newStock
	local stockLabel = slots[slotIndex]:FindFirstChild("stocktxt")
	if stockLabel then
		stockLabel.Text = newStock .. "/" .. data.maxStock
	end
	setSoldOut(slots[slotIndex], newStock <= 0)
end)

shopResultEvent.OnClientEvent:Connect(function(ok, message, slotIndex)
	if slotIndex and slotIndex > 0 and not ok then
		showResult(slotIndex, message)
	end
end)

task.spawn(function()
	while true do
		if restockLabel and currentData then
			local remaining = math.max(0, currentData.nextRestockTime - os.time())
			restockLabel.Text = string.format("New items in %dm %02ds", remaining // 60, remaining % 60)
		end
		task.wait(1)
	end
end)

-- Menu + bolge tetikleme -----------------------------------------------------

local menu = MenuController.createSlideMenu({
	name = "itemshop",
	gui = gui,
	parts = {shopFrame},
	closeButton = closeBtn,
})

local wasInside = false
player.CharacterAdded:Connect(function()
	wasInside = false
end)

task.spawn(function()
	local detector = workspace:WaitForChild("itemshopdetector", 30)
	if not detector then
		warn("[ItemShopClient] itemshopdetector bulunamadi")
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

local packet = getShopFunc:InvokeServer()
if packet then
	populateAll(packet)
end
