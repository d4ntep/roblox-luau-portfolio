-- NumberFormat
-- Sayi kisaltma yardimcilari.

local NumberFormat = {}

local SUFFIXES = {
	{1e33, "Dc"},
	{1e30, "No"},
	{1e27, "Oc"},
	{1e24, "Sp"},
	{1e21, "Sx"},
	{1e18, "Qi"},
	{1e15, "Qa"},
	{1e12, "T"},
	{1e9, "B"},
	{1e6, "M"},
	{1e3, "K"},
}

-- 1234567 -> "1.2M", 950 -> "950", 1.5 -> "1.5"
function NumberFormat.abbreviate(n: number): string
	for _, entry in ipairs(SUFFIXES) do
		if n >= entry[1] then
			return string.format("%.1f%s", n / entry[1], entry[2])
		end
	end
	if n == math.floor(n) then
		return tostring(math.floor(n))
	end
	return tostring(n)
end

-- Fiyat etiketleri icin: 3000 -> "3K", 3500000 -> "3.5M"
function NumberFormat.compact(n: number): string
	local function fmt(value, suffix)
		if value == math.floor(value) then
			return string.format("%d%s", value, suffix)
		end
		return string.format("%.1f%s", value, suffix)
	end
	if n >= 1e9 then
		return fmt(n / 1e9, "B")
	elseif n >= 1e6 then
		return fmt(n / 1e6, "M")
	elseif n >= 1e3 then
		return fmt(n / 1e3, "K")
	end
	return tostring(n)
end

return NumberFormat
