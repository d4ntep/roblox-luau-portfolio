-- FallingBridge (server)
-- Segmentli kopru: bir segmente basilinca o segmentten geriye dogru dalga
-- halinde CanCollide kapatilir, bir sure sonra geri acilir. Gorsel solma
-- client'ta (FallingBridgeClient) ayni tempoyla oynatilir.
-- Collision sunucuda degistigi icin dalga sirasinda koprude olan herkes duser.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local remote = Remotes.event("FallingBridge")
local segmentsFolder = script.Parent.Segments

local NUM_SEGMENTS = 150
local INITIAL_DELAY = 0.5
local WAVE_DELAY = 6.0935 / 125 -- segment uzunlugu / hedef walkspeed: kosan oyuncu tam yakalanir
local RESPAWN_TIME = 3

local segments = {}
for i = 1, NUM_SEGMENTS do
	segments[i] = segmentsFolder:FindFirstChild("Segment_" .. i)
end

local falling: {[Player]: boolean} = {}

local function triggerWave(player: Player, startIndex: number)
	if falling[player] then
		return
	end
	falling[player] = true
	remote:FireClient(player, "startWave", startIndex, INITIAL_DELAY, WAVE_DELAY)

	task.spawn(function()
		task.wait(INITIAL_DELAY)
		for i = startIndex, 1, -1 do
			if segments[i] then
				segments[i].CanCollide = false
			end
			task.wait(WAVE_DELAY)
		end

		task.wait(RESPAWN_TIME)
		for i = 1, startIndex do
			if segments[i] then
				segments[i].CanCollide = true
			end
		end
		remote:FireClient(player, "resetWave", startIndex)
		falling[player] = nil
	end)
end

for i, segment in pairs(segments) do
	segment.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player and hit.Parent:FindFirstChildOfClass("Humanoid") then
			triggerWave(player, i)
		end
	end)
end

Players.PlayerRemoving:Connect(function(player)
	falling[player] = nil
end)
