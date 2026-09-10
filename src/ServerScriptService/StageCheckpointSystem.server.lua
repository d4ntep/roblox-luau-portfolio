-- StageCheckpointSystem
-- "Stage<N>" isimli modellere dokunan oyuncunun son stage'i oturum boyunca
-- hafizada tutulur. Oyuncu olup yeniden dogunca client'a revive teklifi
-- gonderilir; odeme onaylaninca oyuncu o stage'e isinlanir.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local ServerRegistry = require(script.Parent.ServerRegistry)

local reviveOfferEvent = Remotes.event("ReviveOffer") -- server -> client: stageNumber

local lastStage: {[number]: {number: number, cframe: CFrame}} = {}

local function getStageNumber(obj: Instance): number?
	local n = obj.Name:match("^Stage(%d+)$")
	return n and tonumber(n) or nil
end

-- Oncelik: model icindeki "teleport" parcasi; yoksa PrimaryPart / ilk BasePart
local function getStageCFrame(obj: Instance): CFrame?
	if obj:IsA("Model") then
		local teleport = obj:FindFirstChild("teleport")
		if teleport and teleport:IsA("BasePart") then
			return teleport.CFrame
		end
		if obj.PrimaryPart then
			return obj.PrimaryPart.CFrame
		end
		local first = obj:FindFirstChildWhichIsA("BasePart", true)
		return first and first.CFrame or nil
	elseif obj:IsA("BasePart") then
		return obj.CFrame
	end
	return nil
end

local function setupStage(obj: Instance)
	local number = getStageNumber(obj)
	if not number or not (obj:IsA("Model") or obj:IsA("BasePart")) then
		return
	end
	local cframe = getStageCFrame(obj)
	if not cframe then
		warn("[StageCheckpointSystem] Konum bulunamadi: " .. obj:GetFullName())
		return
	end

	local function onTouched(hit: BasePart)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player then
			lastStage[player.UserId] = {number = number, cframe = cframe}
		end
	end

	if obj:IsA("BasePart") then
		obj.Touched:Connect(onTouched)
	else
		for _, part in ipairs(obj:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Touched:Connect(onTouched)
			end
		end
	end
end

for _, obj in ipairs(workspace:GetDescendants()) do
	setupStage(obj)
end
workspace.DescendantAdded:Connect(function(obj)
	task.defer(setupStage, obj)
end)

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.Died:Connect(function()
			local info = lastStage[player.UserId]
			if not info then
				return
			end
			-- Teklif, yeni karakter spawn olunca gosterilir
			player.CharacterAdded:Wait()
			reviveOfferEvent:FireClient(player, info.number)
		end)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	lastStage[player.UserId] = nil
end)

-- Odeme onaylandiktan sonra cagrilir. Oyuncunun o an gecerli checkpoint'i
-- kalmamis olsa bile odeme alinmis oldugu icin true donulur.
ServerRegistry.registerProduct(GameConfig.PRODUCTS.REVIVE, function(player)
	local info = lastStage[player.UserId]
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if info and root then
		root.CFrame = info.cframe + Vector3.new(0, 3, 0)
	end
	return true
end)
