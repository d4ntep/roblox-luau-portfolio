-- PlayerProgress (client)
-- Oyuncunun XP / level / toplam Speed durumunun tek sahibi. HUD, menuler ve
-- hareket sistemi bu modul uzerinden okur ve XP ekler. Sunucudan gelen
-- duzeltmeler (kirpma, rebirth, satin alma) burada uygulanir.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AuraData = require(ReplicatedStorage:WaitForChild("AuraData"))
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local TrailData = require(ReplicatedStorage:WaitForChild("TrailData"))

local player = Players.LocalPlayer
local leaderstats = player:WaitForChild("leaderstats")
local rebirthStat = leaderstats:WaitForChild("Rebirths")
local perkTierStat = player:WaitForChild("ActivePerkTier", 10)

local updateSpeedEvent = Remotes.event("UpdateSpeed")
local progressSyncEvent = Remotes.event("ProgressSync")
local speedGrantedEvent = Remotes.event("SpeedGranted")
local getProgressFunc = Remotes.func("GetProgress")
local rebirthEvent = Remotes.event("Rebirth")

local PlayerProgress = {}

local xp = 0
local level = 1
local totalXP = 0

local changedSignal = Instance.new("BindableEvent")
local levelUpSignal = Instance.new("BindableEvent")
local xpEarnedSignal = Instance.new("BindableEvent")
local speedGrantedSignal = Instance.new("BindableEvent")

PlayerProgress.Changed = changedSignal.Event         -- ()
PlayerProgress.LevelUp = levelUpSignal.Event         -- (newLevel)
PlayerProgress.XPEarned = xpEarnedSignal.Event       -- (earned, source)
PlayerProgress.SpeedGranted = speedGrantedSignal.Event -- (amount)

-- Okuma ----------------------------------------------------------------

function PlayerProgress.get(): (number, number, number)
	return xp, level, totalXP
end

function PlayerProgress.getRequiredXP(): number
	return GameConfig.getRequiredXP(level)
end

-- Carpan bilesenleri; hepsi sunucunun replike ettigi degerlerden okunur
function PlayerProgress.getMultiplierParts()
	local aura = AuraData.getById(player:GetAttribute("EquippedAura") or "")
	local trail = TrailData.getById(player:GetAttribute("EquippedTrail") or "")
	return {
		perk = GameConfig.getPerkStepBonus(perkTierStat and perkTierStat.Value or 1),
		rebirth = GameConfig.getRebirthMultiplier(rebirthStat.Value),
		aura = aura and aura.multiplier or 1,
		trail = trail and trail.multiplier or 1,
		item = 1 + (player:GetAttribute("ItemXPBonus") or 0) / 100,
		gamepass = GameConfig.getGamepassSpeedMultiplier(player:GetAttribute("SpeedBonusOwned") or 0),
	}
end

function PlayerProgress.getMultiplier(): number
	local p = PlayerProgress.getMultiplierParts()
	return p.perk * p.rebirth * p.aura * p.trail * p.item * p.gamepass
end

function PlayerProgress.canRebirth(): boolean
	return level >= GameConfig.getRebirthRequiredLevel(rebirthStat.Value)
end

-- Yazma ----------------------------------------------------------------

local function applyPacket(packet)
	if type(packet) ~= "table" then
		return
	end
	local oldLevel = level
	xp = packet.xp or xp
	level = packet.level or level
	totalXP = packet.totalXP or totalXP
	changedSignal:Fire()
	if level > oldLevel then
		levelUpSignal:Fire(level)
	end
end

local function checkLevelUp()
	local required = GameConfig.getRequiredXP(level)
	while xp >= required do
		xp -= required
		level += 1
		required = GameConfig.getRequiredXP(level)
		levelUpSignal:Fire(level)
	end
end

-- baseAmount carpanlarla carpilir; kazanilan miktar doner
function PlayerProgress.addXP(baseAmount: number, source: string?): number
	local earned = math.max(1, math.floor(baseAmount * PlayerProgress.getMultiplier()))
	xp += earned
	totalXP += earned
	checkLevelUp()
	updateSpeedEvent:FireServer(totalXP)
	xpEarnedSignal:Fire(earned, source or "movement")
	changedSignal:Fire()
	return earned
end

function PlayerProgress.requestRebirth()
	if PlayerProgress.canRebirth() then
		rebirthEvent:FireServer()
	end
end

-- Sunucu olaylari ------------------------------------------------------

progressSyncEvent.OnClientEvent:Connect(applyPacket)

speedGrantedEvent.OnClientEvent:Connect(function(amount, packet)
	applyPacket(packet)
	speedGrantedSignal:Fire(amount)
end)

-- Baslangic verisi: sunucu DataStore'u yuklemis olana kadar birkac kez denenir
task.spawn(function()
	for _ = 1, 3 do
		local ok, packet = pcall(function()
			return getProgressFunc:InvokeServer()
		end)
		if ok and packet then
			applyPacket(packet)
			return
		end
		task.wait(2)
	end
end)

return PlayerProgress
