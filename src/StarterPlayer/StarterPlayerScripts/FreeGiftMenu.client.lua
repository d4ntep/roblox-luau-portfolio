-- FreeGiftMenu
-- freegui: gruba katil + odul al. Dogrulama ve odul sunucuda (FreeGiftSystem);
-- burasi sadece prompt'u acar ve sonucu gosterir.

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local MenuController = require(ReplicatedStorage:WaitForChild("MenuController"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local claimEvent = Remotes.event("ClaimFreeGift")

local gui = player:WaitForChild("PlayerGui"):WaitForChild("freegui")
local menuFrame = gui:WaitForChild("menu")
local buttonFrame = gui:WaitForChild("button")
local chocodrip = gui:WaitForChild("chocodrip")
local closeBtn = gui:WaitForChild("closebutton")

local menu = MenuController.createSlideMenu({
	name = "freegui",
	gui = gui,
	parts = {menuFrame, chocodrip, closeBtn},
	openButton = buttonFrame,
	closeButton = closeBtn,
	hoverDarken = true,
})

-- Haritadaki sandik prompt'u da menuyu acar
ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
	if prompt.Name == "FreeGiftPrompt" and who == player then
		menu.toggle()
	end
end)

-- Verify & Claim ----------------------------------------------------------

local verifyFrame = menuFrame:WaitForChild("verify", 5)
local verifyButton = verifyFrame and verifyFrame:WaitForChild("verify", 5)
local verifyLabel = verifyButton and verifyButton:WaitForChild("Label", 5)
if not (verifyFrame and verifyButton and verifyLabel) then
	warn("[FreeGiftMenu] freegui.menu.verify bulunamadi")
	return
end

local CLAIM_TIMEOUT = 5
local processing = false

local function waitForClaim(): boolean
	local start = os.clock()
	while os.clock() - start < CLAIM_TIMEOUT do
		if player:GetAttribute("ClaimedFreeGift") then
			return true
		end
		task.wait(0.2)
	end
	return false
end

local function attemptClaim()
	if processing or player:GetAttribute("ClaimedFreeGift") then
		return
	end
	processing = true
	verifyLabel.Text = "Checking..."
	task.wait(0.4)

	if not player:IsInGroup(GameConfig.GROUP_ID) then
		verifyLabel.Text = "Join the group first!"
		local ok, status = pcall(GroupService.PromptJoinAsync, GroupService, GameConfig.GROUP_ID)
		local joined = ok and (status == Enum.GroupMembershipStatus.Joined or status == Enum.GroupMembershipStatus.AlreadyMember)
		if not joined then
			processing = false
			return
		end
		verifyLabel.Text = "Checking..."
	end

	claimEvent:FireServer()
	verifyLabel.Text = if waitForClaim() then "Claimed!" else "Click & Claim!"
	processing = false
end

verifyButton.MouseButton1Click:Connect(attemptClaim)

local function refreshState()
	if player:GetAttribute("ClaimedFreeGift") then
		verifyLabel.Text = "Claimed!"
	end
end
player:GetAttributeChangedSignal("ClaimedFreeGift"):Connect(refreshState)
refreshState()
