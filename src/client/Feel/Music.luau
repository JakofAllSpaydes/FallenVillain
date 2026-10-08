--!strict
-- Music (spec §4.5, §12; Tuning.Music): a shuffled playlist on the Music bus, crossfading between tracks. The
-- bus already ducks for the impact silence and the Burst ignition, so every FeelTable `bus = "Music"` entry
-- shapes the music without this module knowing. Two Sound objects alternate: the next track starts
-- Crossfade seconds before the current one ends and the two overlap. Tracks are Roblox audio asset ids in
-- Tuning.Music.Tracks; an empty list plays nothing.

local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Tuning = require(game:GetService("ReplicatedStorage").Shared.Tuning)
local Audio = require(script.Parent.Audio)

local Music = {}

local LOAD_TIMEOUT = 10 -- seconds to wait for a track's length before giving up on it; not a feel value

local decks: { Sound } = {}
local current = 0 -- which deck is playing the lead track
local order: { number } = {}
local orderIndex = 0

local function shuffle(count: number): { number }
	local list = {}
	for index = 1, count do
		list[index] = index
	end
	if Tuning.Music.Shuffle then
		for index = count, 2, -1 do
			local swap = math.random(index)
			list[index], list[swap] = list[swap], list[index]
		end
	end
	return list
end

local function nextTrack(): string?
	local tracks = Tuning.Music.Tracks
	if #tracks == 0 then
		return nil
	end
	if orderIndex >= #order then
		order = shuffle(#tracks)
		orderIndex = 0
	end
	orderIndex += 1
	return tracks[order[orderIndex]]
end

-- Fades `from` out and `to` in over Crossfade seconds, in real time.
local function crossfade(from: Sound?, to: Sound)
	local M = Tuning.Music
	local start = os.clock()
	to.Volume = 0
	to:Play()
	while true do
		local p = math.clamp((os.clock() - start) / math.max(M.Crossfade, 1e-3), 0, 1)
		to.Volume = M.Volume * p
		if from then
			from.Volume = M.Volume * (1 - p)
		end
		if p >= 1 then
			break
		end
		task.wait()
	end
	if from then
		from:Stop()
	end
end

local function play(deck: Sound, id: string)
	deck.SoundId = id
	local waited = 0
	while not deck.IsLoaded and waited < LOAD_TIMEOUT do
		waited += task.wait(0.1)
	end
end

local function run()
	local M = Tuning.Music
	while true do
		local id = nextTrack()
		if not id then
			task.wait(5)
			continue
		end
		local incoming = decks[current % 2 + 1]
		local outgoing = if current > 0 then decks[(current - 1) % 2 + 1] else nil
		play(incoming, id)
		if not incoming.IsLoaded then
			continue -- skip a track that won't load
		end
		current += 1
		task.spawn(crossfade, outgoing, incoming)
		-- Hand over Crossfade seconds before the end (plus the gap), or when the track stops on its own.
		local length = incoming.TimeLength
		local wait = math.max(length - M.Crossfade + M.Gap, 1)
		local started = os.clock()
		while os.clock() - started < wait and incoming.IsPlaying do
			task.wait(0.25)
		end
	end
end

function Music.start()
	local group = Audio.group("Music")
	for _ = 1, 2 do
		local sound = Instance.new("Sound")
		sound.Name = "FallMusic"
		sound.Volume = 0
		sound.Looped = false
		sound.SoundGroup = group
		sound.Parent = SoundService
		table.insert(decks, sound)
	end
	if RunService:IsClient() then
		task.spawn(run)
	end
end

return Music
