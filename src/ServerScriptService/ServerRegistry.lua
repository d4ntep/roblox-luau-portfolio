-- ServerRegistry
-- Sunucu sistemlerinin birbirine bagimlilik olmadan konusmasi icin kucuk kayit
-- noktasi. Iki seyi toplar:
--   * XP carpani kaynaklari (aura, trail, item, gamepass, perk)
--   * Developer Product islem fonksiyonlari (productId -> handler)

local ServerRegistry = {}

-- SpeedSystem yuklenince atanir: (player, amount) -> boolean
ServerRegistry.grantSpeed = nil :: ((Player, number) -> boolean)?

local multiplierSources: {[string]: (Player) -> number} = {}
local productHandlers: {[number]: (Player, number) -> boolean} = {}

function ServerRegistry.addMultiplierSource(name: string, getter: (Player) -> number)
	multiplierSources[name] = getter
end

-- Kayitli tum kaynaklarin carpimi (kaynak yoksa 1)
function ServerRegistry.getMultiplier(player: Player): number
	local total = 1
	for _, getter in pairs(multiplierSources) do
		total *= getter(player) or 1
	end
	return total
end

function ServerRegistry.registerProduct(productId: number, handler: (Player, number) -> boolean)
	if productId == nil or productId == 0 then
		return
	end
	if productHandlers[productId] then
		warn(("[ServerRegistry] %d icin birden fazla handler kaydedildi"):format(productId))
	end
	productHandlers[productId] = handler
end

function ServerRegistry.getProductHandler(productId: number)
	return productHandlers[productId]
end

return ServerRegistry
