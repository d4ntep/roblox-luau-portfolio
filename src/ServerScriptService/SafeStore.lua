-- SafeStore
-- DataStore cagrilarini pcall + tekrar deneme ile sarar. Okuma basarisiz olursa
-- cagiran taraf bunu bilir ve o oyuncu icin kayit yapmaz; boylece gecici bir
-- DataStore kesintisi oyuncunun ilerlemesini bos veriyle ezmez.

local SafeStore = {}

local MAX_ATTEMPTS = 3
local RETRY_DELAY = 1

local function attempt(fn)
	local lastErr
	for i = 1, MAX_ATTEMPTS do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		if i < MAX_ATTEMPTS then
			task.wait(RETRY_DELAY * i)
		end
	end
	return false, lastErr
end

-- Basari durumunda (true, deger) doner; deger nil olabilir (yeni oyuncu)
function SafeStore.get(store: GlobalDataStore, key: string): (boolean, any)
	local ok, result = attempt(function()
		return store:GetAsync(key)
	end)
	if not ok then
		warn(("[SafeStore] GetAsync basarisiz (%s): %s"):format(key, tostring(result)))
	end
	return ok, result
end

function SafeStore.set(store: GlobalDataStore, key: string, value: any): boolean
	local ok, err = attempt(function()
		store:SetAsync(key, value)
	end)
	if not ok then
		warn(("[SafeStore] SetAsync basarisiz (%s): %s"):format(key, tostring(err)))
	end
	return ok
end

return SafeStore
