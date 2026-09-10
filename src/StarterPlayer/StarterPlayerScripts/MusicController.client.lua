-- MusicController
-- ReplicatedStorage.Assets.sounds.music altindaki sarkilari sirayla, crossfade ile calar.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local FADE_DURATION = 3    -- saniye, fade-in ve fade-out suresi
local CROSSFADE_BEFORE = 3 -- bitmeden kac saniye once bir sonraki fade-in baslasin

-- Muzik klasorunu bul
local musicFolder = ReplicatedStorage.Assets.sounds.music

-- Sarkilari topla (Sound instance'lari, ekleme sirasina gore)
local function getSongs()
	local list = {}
	for _, inst in ipairs(musicFolder:GetChildren()) do
		if inst:IsA("Sound") then
			table.insert(list, inst)
		end
	end
	return list
end

-- Sarki klonlari icin tutucu
local soundHolder = Instance.new("ScreenGui")
soundHolder.Name = "__MusicHolder"
soundHolder.ResetOnSpawn = false
soundHolder.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

local function prepareSongs(songs)
	local prepared = {}
	for _, song in ipairs(songs) do
		local clone = song:Clone()
		clone.Volume = 0
		clone.Looped = false
		clone.Parent = soundHolder
		table.insert(prepared, {
			sound = clone,
			targetVolume = song.Volume, -- orijinal volume
		})
	end
	return prepared
end

local function fadeIn(sound, targetVolume)
	sound.Volume = 0
	sound:Play()
	TweenService:Create(sound, TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Linear), {
		Volume = targetVolume
	}):Play()
end

local function fadeOut(sound)
	local t = TweenService:Create(sound, TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Linear), {
		Volume = 0
	})
	t:Play()
	t.Completed:Wait()
	sound:Stop()
	sound.Volume = 0
end

-- Ana muzik dongusu
task.spawn(function()
	while true do
		local songs = prepareSongs(getSongs())
		if #songs == 0 then
			task.wait(5)
			for _, c in ipairs(soundHolder:GetChildren()) do c:Destroy() end
			continue
		end

		local index = 1
		local currentEntry = songs[index]

		fadeIn(currentEntry.sound, currentEntry.targetVolume)

		while true do
			local sound = currentEntry.sound

			local function waitUntilNearEnd()
				while true do
					if not sound.IsPlaying then return end
					local remaining = sound.TimeLength - sound.TimePosition
					if remaining <= CROSSFADE_BEFORE then return end
					task.wait(0.1)
				end
			end

			waitUntilNearEnd()

			-- Sonraki sarki
			index = (index % #songs) + 1
			local nextEntry = songs[index]

			-- Crossfade
			task.spawn(fadeOut, currentEntry.sound)
			fadeIn(nextEntry.sound, nextEntry.targetVolume)

			currentEntry = nextEntry

			task.wait(FADE_DURATION)
		end
	end
end)
