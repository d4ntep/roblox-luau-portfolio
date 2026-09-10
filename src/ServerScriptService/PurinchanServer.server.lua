-- PurinchanServer
-- Kovalama mantigi client'ta (PurinchanChaseClient / AngrypurinChaseClient).
-- Client "yakalandim" dediginde yalnizca kendi karakteri oldurulur; Health
-- client'tan replike edilmedigi icin bu remote gerekli.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local caughtEvent = Remotes.event("PurinchanCaught")

caughtEvent.OnServerEvent:Connect(function(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = 0
	end
end)
