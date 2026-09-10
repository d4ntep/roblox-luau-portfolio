-- FallingBridgeClient
-- Kopru segmentlerinin gorsel solmasi. Collision sunucuda ayni tempoyla kapanir.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local remote = Remotes.event("FallingBridge")
local segmentsFolder = workspace:WaitForChild("Puddings"):WaitForChild("FallingBridge"):WaitForChild("Segments")

local NUM_SEGMENTS = 150
local FADE_TIME = 0.35
local fadeInfo = TweenInfo.new(FADE_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

local segments = {}
local originalTransparency = {} -- [index] = {part = n, meshes = {[mesh] = n}}

local function cacheSegment(i: number, segment: BasePart)
	segments[i] = segment
	local entry = {part = segment.Transparency, meshes = {}}
	local meshFolder = segment:FindFirstChild("Meshes_" .. i)
	if meshFolder then
		for _, mesh in ipairs(meshFolder:GetChildren()) do
			if mesh:IsA("BasePart") then
				entry.meshes[mesh] = mesh.Transparency
			end
		end
	end
	originalTransparency[i] = entry
end

-- StreamingEnabled ile segmentler gec gelebilir; ilk gorundugunde cache'lenir
local function getSegment(i: number): BasePart?
	if segments[i] then
		return segments[i]
	end
	local segment = segmentsFolder:FindFirstChild("Segment_" .. i)
	if segment then
		cacheSegment(i, segment)
	end
	return segment
end

for i = 1, NUM_SEGMENTS do
	getSegment(i)
end

local function fadeSegment(i: number, fadeOut: boolean)
	local segment = getSegment(i)
	if not segment then
		return
	end
	local original = originalTransparency[i]
	TweenService:Create(segment, fadeInfo, {Transparency = if fadeOut then 1 else original.part}):Play()
	for mesh, transparency in pairs(original.meshes) do
		if mesh.Parent then
			TweenService:Create(mesh, fadeInfo, {Transparency = if fadeOut then 1 else transparency}):Play()
		end
	end
end

remote.OnClientEvent:Connect(function(action, startIndex, initialDelay, waveDelay)
	if action == "startWave" then
		task.spawn(function()
			task.wait(initialDelay or 0.5)
			for i = startIndex, 1, -1 do
				fadeSegment(i, true)
				task.wait(waveDelay or 0.05)
			end
		end)
	elseif action == "resetWave" then
		for i = startIndex, 1, -1 do
			fadeSegment(i, false)
		end
	end
end)
