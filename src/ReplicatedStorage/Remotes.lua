-- Remotes
-- RemoteEvent / RemoteFunction erisimi tek noktadan. Server tarafinda
-- ihtiyac duyulan remote yoksa olusturulur, client tarafinda beklenir.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local Remotes = {}

local function getFolder(): Folder
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = FOLDER_NAME
			folder.Parent = ReplicatedStorage
		end
		return folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

local function get(className: string, name: string)
	local folder = getFolder()
	if RunService:IsServer() then
		local existing = folder:FindFirstChild(name)
		if existing then
			return existing
		end
		local remote = Instance.new(className)
		remote.Name = name
		remote.Parent = folder
		return remote
	end
	return folder:WaitForChild(name)
end

function Remotes.event(name: string): RemoteEvent
	return get("RemoteEvent", name)
end

function Remotes.func(name: string): RemoteFunction
	return get("RemoteFunction", name)
end

return Remotes
