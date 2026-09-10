-- ReviveSystem
-- Oyuncu olup yeniden dogunca ekranin ustunden "Revive to Stage X?" paneli
-- kayar. Panel tek bir butondur; tiklaninca Robux prompt'u acilir. Gercek
-- isinlanma odeme onaylaninca sunucuda (StageCheckpointSystem) yapilir.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local MenuController = require(ReplicatedStorage:WaitForChild("MenuController"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local PRODUCT_ID = GameConfig.PRODUCTS.REVIVE
local AUTO_DISMISS_SECONDS = 10
local SLIDE_DURATION = 0.35

local player = Players.LocalPlayer
local reviveOfferEvent = Remotes.event("ReviveOffer")

local gui = player:WaitForChild("PlayerGui"):WaitForChild("revivegui")
local panel = gui:WaitForChild("RevivePanel")
local clickButton = panel:WaitForChild("RevivePanel")
local label = clickButton:WaitForChild("Label")

MenuController.attachUIScale(gui)

local REST_POSITION = panel.Position
local HIDDEN_POSITION = UDim2.new(REST_POSITION.X.Scale, REST_POSITION.X.Offset, -0.35, 0)
panel.Position = HIDDEN_POSITION
panel.Visible = false

-- Ust uste tetiklenirse eski zamanlayici yeni paneli kapatmasin
local generation = 0

local function slideIn()
	generation += 1
	local myGeneration = generation
	panel.Visible = true
	panel.Position = HIDDEN_POSITION
	TweenService:Create(panel, TweenInfo.new(SLIDE_DURATION, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = REST_POSITION}):Play()

	task.delay(AUTO_DISMISS_SECONDS, function()
		if generation ~= myGeneration then
			return
		end
		local tween = TweenService:Create(panel, TweenInfo.new(SLIDE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = HIDDEN_POSITION})
		tween:Play()
		tween.Completed:Wait()
		if generation == myGeneration then
			panel.Visible = false
		end
	end)
end

clickButton.MouseButton1Click:Connect(function()
	generation += 1
	panel.Visible = false
	panel.Position = HIDDEN_POSITION
	MarketplaceService:PromptProductPurchase(player, PRODUCT_ID)
end)

-- Odeme iptal edildiyse teklifi tekrar goster
MarketplaceService.PromptProductPurchaseFinished:Connect(function(_, productId, purchased)
	if productId == PRODUCT_ID and not purchased then
		slideIn()
	end
end)

reviveOfferEvent.OnClientEvent:Connect(function(stageNumber)
	label.Text = "Revive to Stage " .. stageNumber .. "?"
	slideIn()
end)
