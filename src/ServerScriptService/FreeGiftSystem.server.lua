-- FreeGiftSystem
-- Gruba katilan oyuncuya tek seferlik Speed odulu. Grup uyeligi sunucuda
-- GetGroupsAsync ile dogrulanir (IsInGroup 60 sn cache tuttugu icin
-- PromptJoinAsync sonrasi guncel sonuc vermez). Claim durumu ayri bir
-- DataStore'da tutulur ve oyuncu girisinde bir kez okunur.

local DataStoreService = game:GetService("DataStoreService")
local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local SafeStore = require(script.Parent.SafeStore)
local ServerRegistry = require(script.Parent.ServerRegistry)

local claimStore = DataStoreService:GetDataStore("PudingFreeGiftClaims")
local claimEvent = Remotes.event("ClaimFreeGift")

local claimed: {[number]: boolean} = {}   -- bilinen durum
local claimLoaded: {[number]: boolean} = {}

local function isInGroup(player: Player): boolean
	local ok, groups = pcall(GroupService.GetGroupsAsync, GroupService, player.UserId)
	if not ok then
		warn("[FreeGiftSystem] GetGroupsAsync basarisiz: " .. tostring(groups))
		return false
	end
	for _, group in ipairs(groups) do
		if group.Id == GameConfig.GROUP_ID then
			return true
		end
	end
	return false
end

local function loadClaim(player: Player)
	local ok, data = SafeStore.get(claimStore, "player_" .. player.UserId)
	claimLoaded[player.UserId] = ok
	claimed[player.UserId] = ok and type(data) == "table" and data.claimed == true
	player:SetAttribute("ClaimedFreeGift", claimed[player.UserId])
end

Players.PlayerAdded:Connect(loadClaim)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(loadClaim, player)
end

Players.PlayerRemoving:Connect(function(player)
	claimed[player.UserId] = nil
	claimLoaded[player.UserId] = nil
end)

claimEvent.OnServerEvent:Connect(function(player)
	local userId = player.UserId
	if not claimLoaded[userId] or claimed[userId] then
		return
	end
	if not isInGroup(player) then
		return
	end
	if not ServerRegistry.grantSpeed then
		return
	end

	claimed[userId] = true -- ayni anda ikinci istek gelirse tekrar verilmesin
	if not ServerRegistry.grantSpeed(player, GameConfig.FREE_GIFT_SPEED) then
		claimed[userId] = false
		return
	end
	player:SetAttribute("ClaimedFreeGift", true)
	SafeStore.set(claimStore, "player_" .. userId, {claimed = true})
end)
