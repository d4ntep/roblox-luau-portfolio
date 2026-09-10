-- TutorialSystem
-- Tutorial fazlarinin tamamlanma kaydi. Client "request" gonderir, sunucu hangi
-- fazlarin bittigini dondurur; client bir fazi bitirince "phase_complete" yollar.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local SafeStore = require(script.Parent.SafeStore)

local store = DataStoreService:GetDataStore(GameConfig.DATASTORE_NAME)
local event = Remotes.event("TutorialEvent")

local TOTAL_PHASES = 5
local TRACK_COMPLETION = true -- test icin false yapilirsa tutorial her giriste oynar

local function phaseKey(player: Player, phase: number): string
	return "tutorial_phase_" .. phase .. "_" .. player.UserId
end

local function isCompleted(player: Player, phase: number): boolean
	if not TRACK_COMPLETION then
		return false
	end
	local ok, value = SafeStore.get(store, phaseKey(player, phase))
	if not ok then
		return true -- okunamiyorsa tutorial'i zorla gostermeyelim
	end
	return value == true
end

event.OnServerEvent:Connect(function(player, action, phase)
	if action == "request" then
		task.spawn(function()
			local completed = {}
			local allDone = true
			for i = 1, TOTAL_PHASES do
				completed[i] = isCompleted(player, i)
				allDone = allDone and completed[i]
			end
			if not allDone then
				event:FireClient(player, "show", completed)
			end
		end)
	elseif action == "phase_complete" and type(phase) == "number" and TRACK_COMPLETION then
		task.spawn(SafeStore.set, store, phaseKey(player, phase), true)
	end
end)
