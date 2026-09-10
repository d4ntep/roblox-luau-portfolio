-- GamePassCache
-- UserOwnsGamePassAsync sonuclarini oyuncu basina cache'ler; satin alma
-- sonrasi SetOwned ile aninda guncellenir.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local GamePassCache = {}
local cache = {} -- [userId] = { [gamePassId] = boolean }

function GamePassCache.PlayerOwnsGamePass(player, gamePassId)
	local userId = player.UserId
	cache[userId] = cache[userId] or {}
	local cached = cache[userId][gamePassId]
	if cached ~= nil then
		return cached
	end

	local success, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(userId, gamePassId)
	end)

	if success then
		cache[userId][gamePassId] = owns
		return owns
	end

	warn("[GamePassCache] UserOwnsGamePassAsync basarisiz: " .. player.Name .. " / " .. tostring(gamePassId))
	return false
end

function GamePassCache.SetOwned(player, gamePassId, owns)
	local userId = player.UserId
	cache[userId] = cache[userId] or {}
	cache[userId][gamePassId] = owns
end

Players.PlayerRemoving:Connect(function(player)
	cache[player.UserId] = nil
end)

return GamePassCache
