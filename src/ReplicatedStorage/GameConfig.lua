-- GameConfig
-- Oyun genelinde paylasilan sabitler ve formuller. Client ve server ayni
-- modulu kullanir, boylece iki taraf hicbir zaman farkli tablo tutmaz.

local GameConfig = {}

GameConfig.DATASTORE_NAME = "PudingGameData_v1"
GameConfig.GROUP_ID = 950745915
GameConfig.FREE_GIFT_SPEED = 30000

-- XP
GameConfig.BASE_XP = 100
GameConfig.XP_GROWTH = 1.20
GameConfig.STUD_PER_XP = 3
GameConfig.TREADMILL_TICK_SECONDS = 0.2

-- WalkSpeed
GameConfig.BASE_WALK_SPEED = 10
GameConfig.WALK_SPEED_PER_LEVEL = 2
GameConfig.MAX_WALK_SPEED = 300

-- Rebirth: {gerekli level, XP carpani}
GameConfig.REBIRTH_TABLE = {
	{15, 1.5},
	{25, 2},
	{35, 4},
	{50, 10},
	{75, 100},
	{100, 500},
	{140, 1000},
	{190, 10000},
	{250, 100000},
	{290, 200000},
	{350, 500000},
	{400, 3000000},
	{500, 7000000},
	{600, 12000000},
	{700, 30000000},
}
GameConfig.REBIRTH_OVERFLOW_LEVEL_STEP = 100

-- Perk kademeleri
GameConfig.PERK_WINS = {0, 3, 15, 100, 500, 2500, 15000, 50000}
GameConfig.PERK_STEPS = {1, 4, 9, 34, 84, 184, 434, 934}

-- Developer Product'lar
GameConfig.PRODUCTS = {
	SKIP_REBIRTH = 3610297210,
	REVIVE = 3608010418,
}

-- Speed satin alma kademeleri: milestone XP'sinin yuzdesi
GameConfig.SPEED_BUY_TIERS = {
	{pct = 0.03, productId = 3610053764},
	{pct = 0.08, productId = 3610053830},
	{pct = 0.15, productId = 3610296037},
}

-- XP formulleri ---------------------------------------------------------

function GameConfig.getRequiredXP(level: number): number
	return math.floor(GameConfig.BASE_XP * (GameConfig.XP_GROWTH ^ (level - 1)))
end

-- Level 1'den `level`e ulasmak icin gereken toplam XP
function GameConfig.getCumulativeXP(level: number): number
	local total = 0
	for i = 1, level - 1 do
		total += GameConfig.getRequiredXP(i)
	end
	return total
end

-- Rebirth icinde kazanilan toplam XP'den level turetir
function GameConfig.getLevelFromTotalXP(totalXP: number): number
	local level = 1
	local spent = 0
	while true do
		local need = GameConfig.getRequiredXP(level)
		if spent + need > totalXP then
			break
		end
		spent += need
		level += 1
	end
	return level
end

function GameConfig.getMaxWalkSpeed(level: number): number
	return math.min(
		GameConfig.BASE_WALK_SPEED + (level - 1) * GameConfig.WALK_SPEED_PER_LEVEL,
		GameConfig.MAX_WALK_SPEED
	)
end

-- Speed satin alma tabani: bulunulan 15'lik level dilimine kadar toplam XP
function GameConfig.getMilestoneXP(level: number): number
	local milestone = math.max(15, math.floor(level / 15) * 15)
	return GameConfig.getCumulativeXP(milestone)
end

function GameConfig.getSpeedBuyAmount(level: number, tierIndex: number): number?
	local tier = GameConfig.SPEED_BUY_TIERS[tierIndex]
	if not tier then
		return nil
	end
	return math.max(1, math.floor(GameConfig.getMilestoneXP(level) * tier.pct))
end

function GameConfig.getSpeedBuyTierByProduct(productId: number): number?
	for i, tier in ipairs(GameConfig.SPEED_BUY_TIERS) do
		if tier.productId == productId then
			return i
		end
	end
	return nil
end

-- Rebirth ---------------------------------------------------------------

function GameConfig.getRebirthRequiredLevel(rebirths: number): number
	local nextIndex = rebirths + 1
	local entry = GameConfig.REBIRTH_TABLE[nextIndex]
	if entry then
		return entry[1]
	end
	local last = GameConfig.REBIRTH_TABLE[#GameConfig.REBIRTH_TABLE][1]
	local overflow = nextIndex - #GameConfig.REBIRTH_TABLE
	return last + overflow * GameConfig.REBIRTH_OVERFLOW_LEVEL_STEP
end

function GameConfig.getRebirthMultiplier(rebirths: number): number
	if rebirths <= 0 then
		return 1
	end
	local entry = GameConfig.REBIRTH_TABLE[rebirths]
	if entry then
		return entry[2]
	end
	return GameConfig.REBIRTH_TABLE[#GameConfig.REBIRTH_TABLE][2]
end

-- Perk ------------------------------------------------------------------

function GameConfig.getPerkStepBonus(tier: number): number
	return GameConfig.PERK_STEPS[tier] or 1
end

function GameConfig.getHighestUnlockedPerkTier(wins: number): number
	local highest = 1
	for i, required in ipairs(GameConfig.PERK_WINS) do
		if wins >= required then
			highest = i
		end
	end
	return highest
end

-- Speed Bonus gamepass'leri: her pass toplami ikiye katlar
function GameConfig.getGamepassSpeedMultiplier(ownedCount: number): number
	return 2 ^ ownedCount
end

return GameConfig
