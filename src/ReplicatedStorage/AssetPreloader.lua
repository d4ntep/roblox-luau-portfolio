-- AssetPreloader
-- Loading ekrani icin oyundaki image/sound asset ID'lerini toplar: PlayerGui,
-- asset klasorleri ve data modulleri taranir.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetPreloader = {}

local ASSET_PROPERTIES = {"Image", "SoundId", "MeshId", "Texture", "Decal"}

local function scanInstanceTree(root, foundSet)
	for _, inst in ipairs(root:GetDescendants()) do
		for _, propName in ipairs(ASSET_PROPERTIES) do
			local ok, value = pcall(function()
				return inst[propName]
			end)
			if ok and typeof(value) == "string" and value:match("^rbxassetid://%d+") then
				foundSet[value] = true
			end
		end
	end
end

local function scanTable(tbl, foundSet, seen)
	seen = seen or {}
	if seen[tbl] then return end
	seen[tbl] = true
	for _, value in pairs(tbl) do
		if typeof(value) == "string" and value:match("^rbxassetid://%d+") then
			foundSet[value] = true
		elseif typeof(value) == "table" then
			scanTable(value, foundSet, seen)
		end
	end
end

-- Icinde asset ID gecen data modulleri
local MODULES_TO_SCAN = {
	"ItemShopData",
	"AuraData",
	"TrailData",
	"TutorialData",
}

local function getInstanceRoots(player)
	local roots = {}
	if player and player:FindFirstChild("PlayerGui") then
		table.insert(roots, player.PlayerGui)
	end
	local pudingasset = ReplicatedStorage:FindFirstChild("pudingasset")
	if pudingasset then table.insert(roots, pudingasset) end
	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	if assetsFolder then table.insert(roots, assetsFolder) end
	return roots
end

function AssetPreloader.gatherAll(player)
	local foundSet = {}

	for _, root in ipairs(getInstanceRoots(player)) do
		scanInstanceTree(root, foundSet)
	end

	for _, moduleName in ipairs(MODULES_TO_SCAN) do
		local mod = ReplicatedStorage:FindFirstChild(moduleName)
		if mod and mod:IsA("ModuleScript") then
			local ok, data = pcall(require, mod)
			if ok and typeof(data) == "table" then
				scanTable(data, foundSet)
			end
		end
	end

	local list = {}
	for assetId in pairs(foundSet) do
		table.insert(list, assetId)
	end
	table.sort(list)
	return list
end

return AssetPreloader
