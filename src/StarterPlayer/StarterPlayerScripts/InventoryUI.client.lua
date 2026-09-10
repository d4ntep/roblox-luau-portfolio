-- InventoryUI
-- inventorygui: menu acma/kapama, sekmeler ve Items sekmesi (envanter grid'i).
-- Aura/Trail sekmeleri CosmeticShop'ta.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local GamePassIds = require(ReplicatedStorage:WaitForChild("GamePassIds"))
local ItemShopData = require(ReplicatedStorage:WaitForChild("ItemShopData"))
local MenuController = require(ReplicatedStorage:WaitForChild("MenuController"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local player = Players.LocalPlayer

local gui = player:WaitForChild("PlayerGui"):WaitForChild("inventorygui")
local menuFrame = gui:WaitForChild("menu")
local buttonFrame = gui:WaitForChild("button")
local chocodrip = gui:WaitForChild("chocodrip")
local closeBtn = gui:WaitForChild("closebutton")
local titleText = gui:WaitForChild("invtxt")
titleText.ZIndex = 30

local itemsTab = menuFrame:WaitForChild("itemstab")
local trailsTab = menuFrame:WaitForChild("trailstab")
local auraTab = menuFrame:WaitForChild("auratab")

-- Menu ------------------------------------------------------------------

local menu = MenuController.createSlideMenu({
	name = "inventorygui",
	gui = gui,
	parts = {
		{instance = menuFrame, open = UDim2.new(0.5077, 0, 0.0445, 0)},
		{instance = chocodrip, open = UDim2.new(0.5066, 0, 0.0225, 0)},
		{instance = closeBtn, open = UDim2.new(0.7182, 0, 0.0213, 0)},
		titleText,
	},
	openButton = buttonFrame,
	closeButton = closeBtn,
	hoverDarken = true,
})

-- Sekmeler ----------------------------------------------------------------

local tabs = {
	items = {button = menuFrame:WaitForChild("items"), content = itemsTab},
	trails = {button = menuFrame:WaitForChild("trails"), content = trailsTab},
	aura = {button = menuFrame:WaitForChild("aura"), content = auraTab},
}
local currentTab = "items"

local function applyTabVisual(name, animate)
	for tabName, tab in pairs(tabs) do
		local active = tabName == name
		tab.content.Visible = active
		local icon = tab.button:FindFirstChild("lighticon")
		local stroke = tab.button:FindFirstChildOfClass("UIStroke")
		if animate then
			if icon then
				TweenService:Create(icon, TweenInfo.new(0.15), {ImageTransparency = if active then 0 else 0.7}):Play()
			end
			if stroke then
				TweenService:Create(stroke, TweenInfo.new(0.15), {Transparency = if active then 0 else 0.5}):Play()
			end
		else
			if icon then
				icon.ImageTransparency = if active then 0 else 0.7
			end
			if stroke then
				stroke.Transparency = if active then 0 else 0.5
			end
		end
	end
end

for name, tab in pairs(tabs) do
	MenuController.addOverlay(tab.button, function()
		if currentTab ~= name then
			currentTab = name
			applyTabVisual(name, true)
		end
	end)
end
applyTabVisual(currentTab, false)

-- Items sekmesi -----------------------------------------------------------

local getInventoryFunc = Remotes.func("GetItemInventory")
local inventoryEvent = Remotes.event("SendItemInventory")
local equipItemEvent = Remotes.event("EquipShopItem")
local equipBestEvent = Remotes.event("EquipBestItems")
local unequipAllEvent = Remotes.event("UnequipAllItems")

local ownedFrame = itemsTab:WaitForChild("owned")
local equippedFrame = itemsTab:WaitForChild("equipped")
local ownedGrid = ownedFrame:WaitForChild("ItemGrid")
local equippedGrid = equippedFrame:WaitForChild("ItemGrid")

local itemTemplate = ownedFrame:WaitForChild("item")
itemTemplate.Visible = false

local ownedCountText = ownedFrame:WaitForChild("border"):WaitForChild("equippedtxt")

-- equipped tarafinda "border" adinda iki frame var: baslik ve buton bari
local equippedHeader, buttonBar
for _, child in ipairs(equippedFrame:GetChildren()) do
	if child.Name == "border" then
		if child:FindFirstChild("equipbest") then
			buttonBar = child
		else
			equippedHeader = child
		end
	end
end

local equippedCountText = equippedHeader:WaitForChild("equippedtxt")
local speedPercentText = equippedHeader:WaitForChild("speedpercent")
local equipBestBtn = buttonBar:WaitForChild("equipbest"):WaitForChild("equipbtn")
local unequipAllBtn = buttonBar:WaitForChild("unequipall"):WaitForChild("unequipbtn")

-- Item Slots gamepass butonu (+10 slot)
local itemSlotFrame = equippedHeader:FindFirstChild("itemslot") or buttonBar:FindFirstChild("itemslot")
local itemSlotBtn = itemSlotFrame and itemSlotFrame:FindFirstChild("itemslot")
if itemSlotBtn and itemSlotBtn:IsA("TextButton") then
	itemSlotBtn.MouseButton1Click:Connect(function()
		MarketplaceService:PromptGamePassPurchase(player, GamePassIds.ITEM_SLOTS_20)
	end)
end

-- Template offset'lerini scale'e cevir; hucre boyutu degisince icerik orantili kalir
do
	local baseX = math.max(itemTemplate.Size.X.Offset, 1)
	local baseY = math.max(itemTemplate.Size.Y.Offset, 1)
	for _, child in ipairs(itemTemplate:GetChildren()) do
		if child:IsA("GuiObject") then
			local s, p = child.Size, child.Position
			child.Size = UDim2.fromScale(s.X.Scale + s.X.Offset / baseX, s.Y.Scale + s.Y.Offset / baseY)
			child.Position = UDim2.fromScale(p.X.Scale + p.X.Offset / baseX, p.Y.Scale + p.Y.Offset / baseY)
		end
	end
	for _, corner in ipairs(itemTemplate:GetDescendants()) do
		if corner:IsA("UICorner") then
			corner.CornerRadius = UDim.new(corner.CornerRadius.Scale + corner.CornerRadius.Offset / baseX, 0)
		end
	end
end

-- Kare hucreler: ScrollingFrame icinde scale bazli CellSize canvas'a gore
-- hesaplandigi icin gorunen genislikten piksel olarak turetilir.
local function setupGrid(grid: ScrollingFrame, columns: number)
	local layout = grid:FindFirstChildOfClass("UIGridLayout")
	if not layout then
		return
	end
	local GAP = 10
	local MIN_CELL = 24
	local SAFETY = 6
	layout.CellPadding = UDim2.fromOffset(GAP, GAP)
	layout.FillDirectionMaxCells = columns
	local padding = grid:FindFirstChildOfClass("UIPadding")

	local function recalc()
		local width = grid.AbsoluteWindowSize.X
		if width <= 0 then
			width = grid.AbsoluteSize.X
		end
		if width <= 0 then
			return
		end
		-- AbsoluteWindowSize UIScale uygulanmis gelir, CellSize ise tekrar carpilir
		local scale = gui:FindFirstChildOfClass("UIScale")
		width /= (scale and scale.Scale > 0) and scale.Scale or 1
		local padLoss = padding and (padding.PaddingLeft.Offset + padding.PaddingRight.Offset) or 16
		local cell = math.floor((width - padLoss - GAP * (columns - 1) - SAFETY) / columns)
		cell = math.max(cell, MIN_CELL)
		layout.CellSize = UDim2.fromOffset(cell, cell)
	end

	grid:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(recalc)
	grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(recalc)
	local scale = gui:FindFirstChildOfClass("UIScale")
	if scale then
		scale:GetPropertyChangedSignal("Scale"):Connect(recalc)
	end
	-- Ust frame'lerden biri gorunur olunca da yeniden hesapla (gizliyken boyut 0 olabilir)
	local ancestor = grid.Parent
	while ancestor and not ancestor:IsA("ScreenGui") do
		if ancestor:IsA("GuiObject") then
			local frame = ancestor
			frame:GetPropertyChangedSignal("Visible"):Connect(function()
				if frame.Visible then
					task.defer(recalc)
				end
			end)
		end
		ancestor = ancestor.Parent
	end
	task.defer(recalc)
	task.delay(0.1, recalc)
end
setupGrid(equippedGrid, 3)
setupGrid(ownedGrid, 4)

-- Epic+ kartlarin kenarlik gradienti doner
local activeGradients = {}
local gradientRotation = 0
RunService.Heartbeat:Connect(function(dt)
	if not (menu.isOpen() and itemsTab.Visible) or #activeGradients == 0 then
		return
	end
	gradientRotation = (gradientRotation + dt * 90) % 360
	for _, gradient in ipairs(activeGradients) do
		gradient.Rotation = gradientRotation
	end
end)

local HOVER_TINT = Color3.fromRGB(175, 175, 175)
local lastCardClick = 0

local function createCard(parent: Instance, item, order: number)
	local def, rarity = ItemShopData.FindById(item.itemId)
	local theme = def and ItemShopData.RarityThemes[rarity]
	if not theme then
		return
	end

	local card = itemTemplate:Clone()
	card.Name = item.uid
	card.LayoutOrder = order
	card.Visible = true

	local rarityBg = card:FindFirstChild("raritybg")
	if rarityBg then
		rarityBg.Image = theme.bg
		local bgStroke = rarityBg:FindFirstChildOfClass("UIStroke")
		if bgStroke then
			bgStroke.Color = theme.strokeColor
		end
	end
	local cardStroke = card:FindFirstChildOfClass("UIStroke")
	if cardStroke then
		cardStroke.Color = theme.strokeColor
		if theme.gradient then
			local gradient = Instance.new("UIGradient")
			gradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, theme.gradient[1]),
				ColorSequenceKeypoint.new(0.5, theme.gradient[2]),
				ColorSequenceKeypoint.new(1, theme.gradient[3]),
			})
			gradient.Parent = cardStroke
			cardStroke.Color = Color3.new(1, 1, 1)
			table.insert(activeGradients, gradient)
		end
	end

	local icon = card:FindFirstChild("itemlb")
	if icon then
		icon.Image = item.icon
	end
	local nameLabel = card:FindFirstChild("itemname")
	if nameLabel then
		nameLabel.Text = item.name
		nameLabel.TextColor3 = theme.textColor
	end
	local speedLabel = card:FindFirstChild("itemspeed")
	if speedLabel then
		speedLabel.Text = "+%" .. item.speedBonus
		speedLabel.TextColor3 = theme.textColor
	end

	local overlay = Instance.new("TextButton")
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundTransparency = 1
	overlay.Text = ""
	overlay.ZIndex = card.ZIndex + 5
	overlay.Parent = card
	overlay.MouseEnter:Connect(function()
		if rarityBg then
			TweenService:Create(rarityBg, TweenInfo.new(0.12), {ImageColor3 = HOVER_TINT}):Play()
		end
	end)
	overlay.MouseLeave:Connect(function()
		if rarityBg then
			TweenService:Create(rarityBg, TweenInfo.new(0.12), {ImageColor3 = Color3.new(1, 1, 1)}):Play()
		end
	end)
	overlay.MouseButton1Click:Connect(function()
		local now = os.clock()
		if now - lastCardClick < 0.25 then
			return
		end
		lastCardClick = now
		equipItemEvent:FireServer(item.uid)
	end)

	card.Parent = parent
end

local function clearGrid(grid: Instance)
	for _, child in ipairs(grid:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

local function redraw(packet)
	if type(packet) ~= "table" or type(packet.items) ~= "table" then
		return
	end
	clearGrid(ownedGrid)
	clearGrid(equippedGrid)
	table.clear(activeGradients)

	local sorted = table.clone(packet.items)
	table.sort(sorted, function(a, b)
		if a.speedBonus ~= b.speedBonus then
			return a.speedBonus > b.speedBonus
		end
		return a.uid < b.uid
	end)

	local equippedCount, ownedCount = 0, 0
	for i, item in ipairs(sorted) do
		if item.equipped then
			equippedCount += 1
			createCard(equippedGrid, item, i)
		else
			ownedCount += 1
			createCard(ownedGrid, item, i)
		end
	end

	local limit = packet.equipLimit or ItemShopData.EQUIP_LIMIT
	ownedCountText.Text = "Owned (" .. ownedCount .. ")"
	equippedCountText.Text = "Equipped (" .. equippedCount .. "/" .. limit .. ")"
	speedPercentText.Text = "%" .. (packet.totalBonus or 0) .. " Speed"
	if itemSlotFrame then
		itemSlotFrame.Visible = limit < 20
	end
end

inventoryEvent.OnClientEvent:Connect(redraw)
task.spawn(function()
	local ok, packet = pcall(function()
		return getInventoryFunc:InvokeServer()
	end)
	if ok then
		redraw(packet)
	end
end)

local lastBulkClick = 0
local function bulkGuard(): boolean
	local now = os.clock()
	if now - lastBulkClick < 0.6 then
		return false
	end
	lastBulkClick = now
	return true
end

equipBestBtn.MouseButton1Click:Connect(function()
	if bulkGuard() then
		equipBestEvent:FireServer()
	end
end)
unequipAllBtn.MouseButton1Click:Connect(function()
	if bulkGuard() then
		unequipAllEvent:FireServer()
	end
end)
