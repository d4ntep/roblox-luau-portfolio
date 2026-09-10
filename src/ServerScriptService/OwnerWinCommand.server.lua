-- OwnerWinCommand
-- Test komutu, sadece oyun sahibi icin: "/win <miktar>" veya "/win <oyuncu> <miktar>".

local Players = game:GetService("Players")

local COMMAND_PREFIX = "/win "

local function isOwner(player)
	return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
end

local function findPlayerByName(partialName)
	partialName = partialName:lower()
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Name:lower():sub(1, #partialName) == partialName then
			return plr
		end
	end
	return nil
end

local function applyWin(targetPlayer, amount, sourceName)
	local leaderstats = targetPlayer:FindFirstChild("leaderstats")
	local winsStat = leaderstats and leaderstats:FindFirstChild("Wins")
	if not winsStat then return end

	winsStat.Value = math.max(0, winsStat.Value + amount)
	print("[OwnerWinCommand] " .. sourceName .. " -> " .. targetPlayer.Name .. " Wins = " .. winsStat.Value)
end

local function onChatted(player, message)
	if not isOwner(player) then return end

	local lower = message:lower()
	if lower:sub(1, #COMMAND_PREFIX) ~= COMMAND_PREFIX then return end

	local rest = message:sub(#COMMAND_PREFIX + 1)

	-- Once tek parametre (sayi) mi diye dene: "/win 50"
	local onlyAmount = tonumber(rest)
	if onlyAmount then
		applyWin(player, math.floor(onlyAmount), player.Name)
		return
	end

	-- Degilse "/win <isim> <miktar>" formatini dene
	local nameArg, amountArg = rest:match("^(%S+)%s+(%-?%d+)$")
	if not nameArg then return end

	local targetPlayer = findPlayerByName(nameArg)
	if not targetPlayer then
		warn("[OwnerWinCommand] '" .. nameArg .. "' isimli oyuncu bulunamadi.")
		return
	end

	applyWin(targetPlayer, math.floor(tonumber(amountArg)), player.Name)
end

Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(message)
		onChatted(player, message)
	end)
end)
