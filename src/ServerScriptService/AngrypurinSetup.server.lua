-- AngrypurinSetup
-- Her sunucu basinda workspace.angrypurin2 modelinden ReplicatedStorage.AngrypurinTemplate
-- uretilir ve orijinal kaldirilir. Client (AngrypurinChaseClient) kendi kopyasini
-- bu sablondan olusturur; orijinal kalsaydi home'da iki boss gorunurdu.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local original = workspace:FindFirstChild("angrypurin2")
if not original then
	warn("[AngrypurinSetup] workspace.angrypurin2 bulunamadi; kurulum atlandi.")
	return
end

local mesh = original:FindFirstChild("Mesh_0")
if not mesh then
	warn("[AngrypurinSetup] angrypurin2.Mesh_0 yok; sablon uretilemedi.")
	return
end

local oldTemplate = ReplicatedStorage:FindFirstChild("AngrypurinTemplate")
if oldTemplate then oldTemplate:Destroy() end

local template = original:Clone()
template.Name = "AngrypurinTemplate"
local tmesh = template:FindFirstChild("Mesh_0")
template.PrimaryPart = tmesh
template.Parent = ReplicatedStorage

original:Destroy()
