-- KillingFloorSystem
-- "killingfloor" / "killingfloorup" isimli parcalara dokunan oyuncu olur.

local function setupKillingFloor(part)
	part.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character then return end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end
		if humanoid.Health <= 0 then return end
		humanoid.Health = 0
	end)
end

-- Workspace'te "killingfloor" ve "killingfloorup" isimli tum parcalari bul
for _, obj in ipairs(workspace:GetDescendants()) do
	if (obj.Name == "killingfloor" or obj.Name == "killingfloorup") and obj:IsA("BasePart") then
		setupKillingFloor(obj)
	end
end

-- Harita gelistirilirken sonradan eklenen parcalari da yakala
workspace.DescendantAdded:Connect(function(obj)
	if (obj.Name == "killingfloor" or obj.Name == "killingfloorup") and obj:IsA("BasePart") then
		setupKillingFloor(obj)
	end
end)
