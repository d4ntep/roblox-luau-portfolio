-- TutorialData
-- Tutorial diyaloglari. Her adim: text, opsiyonel image ve imageHeight.
-- image verilmeyen adimlar RandomImagePool'dan rastgele gorsel alir.

local TutorialData = {}

-- Harf basina bekleme suresi (typewriter hizi)
TutorialData.TYPEWRITER_SPEED = 0.03

TutorialData.Steps = {
	{
		text  = "Hello everyone! Welcome to Purin World!",
		image = "rbxassetid://93238087082500",
	},
	{
		text  = "My name is Purin, nice to meet you!",
		image = "rbxassetid://132231617982333",
	},
	{
		text  = "Since this is your first time here, I'll need to teach you the basics.",
		image = "rbxassetid://84009967353966",
	},
	{
		text  = "Don't worry, we still have a skip button.",
		image = "rbxassetid://131587677449533",
	},
	{
		text  = "First of all, this is a game where you gain speed as you take steps.",
		image = "rbxassetid://84009967353966",
	},
	{
		text  = "Come on, take a few steps and reach level 4!",
		image = "rbxassetid://113213768710649",
	},
}

-- Faz 2 bu seviyede baslar
TutorialData.PHASE2_LEVEL = 4

TutorialData.RandomImagePool = {
	"rbxassetid://132231617982333",
	"rbxassetid://84009967353966",
	"rbxassetid://131587677449533",
	"rbxassetid://113213768710649",
}

TutorialData.Phase2Steps = {
	{ text = "Congratulations, you're now level 4!" },
	{ text = "Try to get past the first obstacle ahead of you." },
	{ text = "You'll see a win button there." },
	{ text = "Grab it, and we'll talk about what to do next." },
}

-- Ilk Win sonrasi
TutorialData.Phase3Steps = {
	{ text = "Congratulations, you got your first Win!" },
	{ text = "Win is the currency of this game. The more Wins you earn, the faster you level up and gain speed." },
	{ text = "You can check your inventory from the menu on the left." },
	{ text = "You can equip trail and aura cosmetics you've earned or purchased from there." },
	{ text = "In the Shop, you can find new items in exchange for Wins." },
	{ text = "There are six different rarity tiers from Common to Mythic, give it a try!" },
	{ text = "If you join our group, you can instantly earn free speed!" },
	{ text = "Don't forget to click the Free button on the left side!" },
	{ text = "Now go earn 3 Wins!" },
}

-- Faz 4 bu kadar Win'de baslar
TutorialData.PHASE4_WINS = 3

TutorialData.Phase4Steps = {
	{ text = "Congratulations. You're doing great!" },
	{
		text = "On your left, you'll see some perks.",
		cameraAction = "focusPerky2",
	},
	{
		text = "They'll help you gain even more speed as you earn Wins.",
		cameraAction = "restore",
	},
	{ text = "Don't worry about constantly tracking your Wins to pick the highest tier." },
	{ text = "We handle that automatically for you." },
	{ text = "Now keep playing — we'll talk again when the time comes!" },
}

-- Faz 4 kamera odagi (perky2)
TutorialData.Phase4CameraFocus = CFrame.new(
	13.1719284, 20.4634819, 27.4799557,
	0.00125998829, 0.567319274, -0.823496997,
	-5.82076609e-11, 0.823497713, 0.567319691,
	0.999999285, -0.000714816095, 0.00103759731
)

-- Faz 5 bu seviyede baslar
TutorialData.PHASE5_LEVEL = 15

TutorialData.Phase5Steps = {
	{ text = "You've reached level 15 — the Rebirth button on the left is now available!" },
	{ text = "Rebirth resets your level back to 1, but permanently increases your speed multiplier." },
	{ text = "The higher your multiplier, the faster you gain speed with every step you take." },
	{ text = "Each Rebirth also raises the level requirement for the next one, so the challenge keeps growing." },
	{ text = "When you're ready, hit that Rebirth button and keep pushing your limits!" },
	{ text = "That's all from me for now — see you next time!" },
}

return TutorialData
