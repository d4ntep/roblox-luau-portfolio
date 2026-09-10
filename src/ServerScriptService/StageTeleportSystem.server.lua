-- StageTeleportSystem
-- Stage warp menusu. Kalici sahiplik yoktur; her isinlanma Win veya Robux ile
-- ayri bir satin almadir. Robux fiyatlari MarketplaceService'ten cekilir ki
-- Creator Dashboard'da degisince menu kod degismeden guncel kalsin.

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local StageData = require(ReplicatedStorage:WaitForChild("StageData"))
local ServerRegistry = require(script.Parent.ServerRegistry)

local buyStageEvent = Remotes.event("BuyStageWins")          -- client -> server: stageNumber
local promptRobuxEvent = Remotes.event("PromptStageRobux")   -- client -> server: stageNumber
local resultEvent = Remotes.event("StagePurchaseResult")     -- server -> client: ok, mesaj, stageNumber
local getRobuxPricesFunc = Remotes.func("GetStageRobuxPrices")

-- Robux fiyatlari -------------------------------------------------------

local robuxPrices: {[number]: number} = {}
local pricesReady = false

task.spawn(function()
	for _, def in ipairs(StageData.Stages) do
		if def.productId and def.productId ~= 0 then
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, def.productId, Enum.InfoType.Product)
			if ok and info and info.PriceInRobux then
				robuxPrices[def.number] = info.PriceInRobux
			else
				warn("[StageTeleport] Fiyat cekilemedi: Stage" .. def.number)
			end
		end
	end
	pricesReady = true
end)

getRobuxPricesFunc.OnServerInvoke = function()
	local waited = 0
	while not pricesReady and waited < 10 do
		task.wait(0.1)
		waited += 0.1
	end
	return robuxPrices
end

-- Isinlanma ---------------------------------------------------------------

local function getStageCFrame(stageNumber: number): CFrame?
	local def = StageData.getByNumber(stageNumber)
	if def and def.pos then
		return CFrame.new(def.pos)
	end
	local folder = workspace:FindFirstChild("stages")
	local model = folder and folder:FindFirstChild("Stage" .. stageNumber)
	local part = model and model:FindFirstChild("teleport")
	return part and part:IsA("BasePart") and part.CFrame or nil
end

local function warp(player: Player, stageNumber: number): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local cframe = getStageCFrame(stageNumber)
	if not (root and cframe) then
		return false
	end
	root.CFrame = cframe + Vector3.new(0, 3, 0)
	return true
end

buyStageEvent.OnServerEvent:Connect(function(player, stageNumber)
	if type(stageNumber) ~= "number" then
		return
	end
	stageNumber = math.floor(stageNumber)
	local def = StageData.getByNumber(stageNumber)
	local leaderstats = player:FindFirstChild("leaderstats")
	local wins = leaderstats and leaderstats:FindFirstChild("Wins")
	if not (def and wins) then
		return
	end
	if wins.Value < def.winsPrice then
		resultEvent:FireClient(player, false, "Not enough Wins!", stageNumber)
		return
	end
	wins.Value -= def.winsPrice
	if warp(player, stageNumber) then
		resultEvent:FireClient(player, true, "Teleported!", stageNumber)
	else
		wins.Value += def.winsPrice
		resultEvent:FireClient(player, false, "Teleport failed", stageNumber)
	end
end)

promptRobuxEvent.OnServerEvent:Connect(function(player, stageNumber)
	if type(stageNumber) ~= "number" then
		return
	end
	local def = StageData.getByNumber(math.floor(stageNumber))
	if def and def.productId and def.productId ~= 0 then
		MarketplaceService:PromptProductPurchase(player, def.productId)
	end
end)

for _, def in ipairs(StageData.Stages) do
	ServerRegistry.registerProduct(def.productId, function(player)
		warp(player, def.number)
		resultEvent:FireClient(player, true, "Teleported!", def.number)
		return true
	end)
end
