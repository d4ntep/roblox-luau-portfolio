-- PurchaseHandler
-- Tek ProcessReceipt. Hangi urunun ne yapacagini bilmez; ilgili sistem
-- ServerRegistry.registerProduct ile kendi handler'ini kaydeder.
-- Handler true donerse odeme onaylanir, aksi halde Roblox makbuzu tekrar dener.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local ServerRegistry = require(script.Parent.ServerRegistry)

MarketplaceService.ProcessReceipt = function(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local handler = ServerRegistry.getProductHandler(receipt.ProductId)
	if not handler then
		warn(("[PurchaseHandler] Bilinmeyen urun: %d (%s)"):format(receipt.ProductId, player.Name))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local ok, granted = pcall(handler, player, receipt.ProductId)
	if not ok then
		warn(("[PurchaseHandler] Handler hatasi (%d): %s"):format(receipt.ProductId, tostring(granted)))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if granted then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end
