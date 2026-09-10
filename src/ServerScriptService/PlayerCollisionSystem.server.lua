-- PlayerCollisionSystem
-- Oyuncu-oyuncu carpismasini kapatir: tum karakter parcalari "Players"
-- collision group'una alinir ve grubun kendisiyle carpismasi kapatilir.

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")

local GROUP_NAME = "Players"

-- Grup zaten kayitliysa hata verir, sorun degil
pcall(function()
	PhysicsService:RegisterCollisionGroup(GROUP_NAME)
end)

PhysicsService:CollisionGroupSetCollidable(GROUP_NAME, GROUP_NAME, false)

local function assignCollisionGroup(character)
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = GROUP_NAME
		end
	end
	character.DescendantAdded:Connect(function(obj)
		if obj:IsA("BasePart") then
			obj.CollisionGroup = GROUP_NAME
		end
	end)
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(assignCollisionGroup)
	if player.Character then
		assignCollisionGroup(player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end
