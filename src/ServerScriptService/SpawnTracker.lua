-- SpawnTracker
-- Her oyuncunun ilk spawn CFrame'ini tutar. Rebirth ve Win butonu oyuncuyu
-- buraya geri gonderir.

local Players = game:GetService("Players")

local SpawnTracker = {}
local spawnCFrames: {[number]: CFrame} = {}

local function onCharacterAdded(player: Player, character: Model)
	if spawnCFrames[player.UserId] then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 5)
	if root then
		spawnCFrames[player.UserId] = root.CFrame
	end
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

Players.PlayerRemoving:Connect(function(player)
	spawnCFrames[player.UserId] = nil
end)

function SpawnTracker.get(player: Player): CFrame?
	return spawnCFrames[player.UserId]
end

-- Karakteri ilk spawn noktasina tasir; basariliysa true doner
function SpawnTracker.returnToSpawn(player: Player): boolean
	local cframe = spawnCFrames[player.UserId]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (cframe and root) then
		return false
	end
	root.CFrame = cframe
	root.AssemblyLinearVelocity = Vector3.zero
	return true
end

return SpawnTracker
