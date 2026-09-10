-- StageData
-- Stage warp menusu tanimlari. Stage1 ucretsizdir; digerleri her seferinde
-- Win veya Robux ile tekrar satin alinir (kalici sahiplik yok).
-- pos: isinlanma noktasinin dunya konumu. StreamingEnabled acik oldugu icin
-- uzak stage'lerin "teleport" parcasi sunucuda yuklu olmayabilir; sabit koordinat
-- warp'i streaming'den bagimsiz kilar.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))

local StageData = {}

StageData.Stages = {
	{ number = 1, name = "Stage 1", winsPrice = 0,       robuxPrice = 0,   productId = 0, pos = Vector3.new(-16.752, 19.523, 73.164) },
	{ number = 2, name = "Stage 2", winsPrice = 2,     robuxPrice = 25,  productId = 3610862185, pos = Vector3.new(-16.819, 3.581, 247.268) },
	{ number = 3, name = "Stage 3", winsPrice = 10,    robuxPrice = 50,  productId = 3610862241, pos = Vector3.new(-18.752, 3.581, 448.371) },
	{ number = 4, name = "Stage 4", winsPrice = 30,    robuxPrice = 90,  productId = 3610862379, pos = Vector3.new(-15.253, 63.175, 700.981) },
	{ number = 5, name = "Stage 5", winsPrice = 80,    robuxPrice = 150, productId = 3610862435, pos = Vector3.new(-20.778, 77.970, 1014.637) },
	{ number = 6, name = "Stage 6", winsPrice = 200,   robuxPrice = 250, productId = 3610862487, pos = Vector3.new(-683.009, 53.602, 1058.088) },
	{ number = 7, name = "Stage 7", winsPrice = 500,   robuxPrice = 350, productId = 3610862586, pos = Vector3.new(-1681.009, 52.602, 1058.088) },
	{ number = 8, name = "Stage 8", winsPrice = 1200,  robuxPrice = 500, productId = 3610862672, pos = Vector3.new(-3198.814, 69.000, 1059.770) },
	{ number = 9, name = "Stage 9", winsPrice = 3000,  robuxPrice = 750, productId = 3610862758, pos = Vector3.new(-3344.856, 762.171, 1058.017) },
	{ number = 10, name = "Stage 10", winsPrice = 16000, robuxPrice = 1000, productId = 3610862949, pos = Vector3.new(-4263.573, 762.171, 999.017) },
}

local byNumber = {}
local byProductId = {}
for _, s in ipairs(StageData.Stages) do
	byNumber[s.number] = s
	if s.productId and s.productId ~= 0 then
		byProductId[s.productId] = s
	end
end

function StageData.getByNumber(n)
	return byNumber[n]
end

function StageData.getByProductId(id)
	return byProductId[id]
end

function StageData.FormatNumber(n)
	return NumberFormat.compact(n)
end

return StageData
