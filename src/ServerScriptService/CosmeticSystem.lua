-- CosmeticSystem
-- Aura ve Trail gibi "sahip ol / tak" kozmetikleri icin ortak sunucu mantigi:
-- kayit, Win ile satin alma, gamepass sahipligi, equip ve XP carpani.
-- Gorsel uygulama her kozmetik turunun kendi script'inde (applyVisual) kalir.

local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local ServerRegistry = require(script.Parent.ServerRegistry)
local SafeStore = require(script.Parent.SafeStore)

local store = DataStoreService:GetDataStore(GameConfig.DATASTORE_NAME)

local SAVE_THROTTLE = 6

export type Definition = {
	id: string,
	multiplier: number,
	winsPrice: number,
	robuxId: number?,
}

export type Config = {
	name: string,                 -- "aura" | "trail"; registry ve remote isimleri bundan turer
	definitions: {Definition},    -- AuraData / TrailData
	storePrefix: string,          -- "auras_" gibi
	attribute: string,            -- oyuncuya yazilan "takili" attribute'u
	applyVisual: (Player, Definition?) -> (),
}

local CosmeticSystem = {}

function CosmeticSystem.new(config: Config)
	local byId = {}
	local byGamePass = {}
	for _, def in ipairs(config.definitions) do
		byId[def.id] = def
		if def.robuxId and def.robuxId ~= 0 then
			byGamePass[def.robuxId] = def
		end
	end

	local buyEvent = Remotes.event("Buy" .. config.name)
	local equipEvent = Remotes.event("Equip" .. config.name)
	local syncEvent = Remotes.event("Sync" .. config.name)

	local data: {[number]: {owned: {[string]: boolean}, equipped: string}} = {}
	local canSave: {[number]: boolean} = {}
	local lastSave: {[number]: number} = {}

	local function sync(player: Player)
		local d = data[player.UserId]
		if d then
			player:SetAttribute(config.attribute, d.equipped)
			syncEvent:FireClient(player, d.owned, d.equipped)
		end
	end

	local function save(player: Player, force: boolean?)
		local d = data[player.UserId]
		if not d or not canSave[player.UserId] then
			return
		end
		local now = os.clock()
		if not force and lastSave[player.UserId] and now - lastSave[player.UserId] < SAVE_THROTTLE then
			return
		end
		lastSave[player.UserId] = now
		SafeStore.set(store, config.storePrefix .. player.UserId, d)
	end

	local function applyVisual(player: Player)
		local d = data[player.UserId]
		local def = d and byId[d.equipped] or nil
		config.applyVisual(player, def)
	end

	-- Gamepass ile alinmis ama kayda islenmemis kozmetikleri tamamla
	local function verifyGamepasses(player: Player)
		local d = data[player.UserId]
		if not d then
			return
		end
		local changed = false
		for gamePassId, def in pairs(byGamePass) do
			if not d.owned[def.id] then
				local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, gamePassId)
				if ok and owns then
					d.owned[def.id] = true
					changed = true
				end
			end
		end
		if changed then
			save(player, true)
		end
	end

	local function load(player: Player)
		local ok, saved = SafeStore.get(store, config.storePrefix .. player.UserId)
		canSave[player.UserId] = ok
		local d = {owned = {}, equipped = ""}
		if type(saved) == "table" then
			if type(saved.owned) == "table" then
				d.owned = saved.owned
			end
			if type(saved.equipped) == "string" and byId[saved.equipped] then
				d.equipped = saved.equipped
			end
		end
		data[player.UserId] = d
		verifyGamepasses(player)
		sync(player)
		if player.Character then
			applyVisual(player)
		end
	end

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart", 5)
			applyVisual(player)
		end)
		load(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		save(player, true)
		data[player.UserId] = nil
		canSave[player.UserId] = nil
		lastSave[player.UserId] = nil
	end)

	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			save(player, true)
		end
	end)

	-- Win ile satin alma
	buyEvent.OnServerEvent:Connect(function(player, id)
		local def = byId[id]
		local d = data[player.UserId]
		if not (def and d) or d.owned[id] then
			return
		end
		local leaderstats = player:FindFirstChild("leaderstats")
		local wins = leaderstats and leaderstats:FindFirstChild("Wins")
		if not wins or wins.Value < def.winsPrice then
			sync(player)
			return
		end
		wins.Value -= def.winsPrice
		d.owned[id] = true
		save(player)
		sync(player)
	end)

	-- Gamepass ile satin alma
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, purchased)
		local def = purchased and byGamePass[gamePassId]
		local d = def and data[player.UserId]
		if not d or d.owned[def.id] then
			return
		end
		d.owned[def.id] = true
		save(player, true)
		sync(player)
	end)

	-- Equip / unequip ("" = cikar)
	equipEvent.OnServerEvent:Connect(function(player, id)
		local d = data[player.UserId]
		if not d or type(id) ~= "string" then
			return
		end
		if id ~= "" and not d.owned[id] then
			return
		end
		d.equipped = id
		save(player)
		sync(player)
		applyVisual(player)
	end)

	ServerRegistry.addMultiplierSource(config.name, function(player)
		local d = data[player.UserId]
		local def = d and byId[d.equipped]
		return def and def.multiplier or 1
	end)

	return {
		getEquipped = function(player: Player): Definition?
			local d = data[player.UserId]
			return d and byId[d.equipped] or nil
		end,
	}
end

return CosmeticSystem
