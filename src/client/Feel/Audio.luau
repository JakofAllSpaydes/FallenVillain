--!strict
-- Layered mixer (spec §12). Buses are SoundGroups whose duck amount is a layer; loops (wind, drone) are started
-- once and their volume and pitch are layers; one-shots come from small per-sound pools with pitch jitter.
-- The wind and ambient buses carry an EQ the atmosphere driver uses as the altitude low-pass.
-- Sound definitions live in Tuning.Sounds; FeelTable entries reference them by name.

local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Tuning = require(game:GetService("ReplicatedStorage").Shared.Tuning)
local Layers = require(script.Parent.Layers)

local Audio = {}

local BUSES = { "Ambient", "Wind", "Music", "Sfx", "Ui" }
local LOW_PASS_BUSES = { Wind = true, Ambient = true }
local POOL_SIZE = 3 -- overlapping copies per one-shot; not a feel value

local groups: { [string]: SoundGroup } = {}
local equalizers: { EqualizerSoundEffect } = {}
local loops: { [string]: Sound } = {}
local pools: { [string]: { Sound } } = {}
local poolNext: { [string]: number } = {}
local layers: Layers.Set

local function makeSound(name: string): Sound
	local def = Tuning.Sounds[name]
	assert(def, `unknown sound {name}`)
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = def.Id
	sound.Volume = def.Volume
	sound.PlaybackSpeed = def.Pitch
	sound.Looped = def.Loop == true
	sound.SoundGroup = groups[def.Bus]
	sound.Parent = SoundService
	return sound
end

-- `volume` scales the sound's own volume (default 1); entries scaled by speed pass it down.
-- One-shot; `volume` and `pitch` multiply the definition's.
function Audio.play(name: string, volume: number?, pitch: number?)
	local pool = pools[name]
	if not pool then
		pool = {}
		for _ = 1, POOL_SIZE do
			table.insert(pool, makeSound(name))
		end
		pools[name] = pool
		poolNext[name] = 1
	end
	local index = poolNext[name]
	poolNext[name] = index % #pool + 1
	local sound = pool[index]
	local def = Tuning.Sounds[name]
	-- A sound set: one of its variations at random (spec §4.12).
	local ids = def.Ids
	if ids then
		local id = ids[math.random(#ids)]
		if sound.SoundId ~= id then
			sound.SoundId = id
		end
	end
	local jitter = def.Jitter or Tuning.Audio.PitchJitter
	sound.PlaybackSpeed = def.Pitch * (pitch or 1) * (1 + (math.random() * 2 - 1) * jitter)
	sound.Volume = def.Volume * (volume or 1)
	sound.TimePosition = 0
	sound:Play()
end

-- Per-frame values for a loop (set, never tweened): volume 0–1 of its own volume, pitch added to 1×.
function Audio.drive(loop: string, volume: number, pitch: number)
	layers:set(`loop.{loop}`, volume, 0)
	layers:set(`pitch.{loop}`, pitch, 0)
end

function Audio.apply(entry: { [string]: any }, duration: number)
	if entry.sound then
		Audio.play(entry.sound, entry.volume, entry.pitch)
	elseif entry.bus then
		layers:apply(`bus.{entry.bus}`, entry, duration)
	elseif entry.loop then
		layers:apply(`loop.{entry.loop}`, entry, duration)
		if entry.pitchTo ~= nil then
			layers:set(`pitch.{entry.loop}`, entry.pitchTo, entry.pitchDur or duration, entry.pitchFrom)
		end
	end
end

-- Altitude low-pass in dB (0 = open, negative = muffled), set by the atmosphere driver.
function Audio.setLowPass(db: number)
	for _, eq in equalizers do
		eq.HighGain = db
		eq.MidGain = db * Tuning.Audio.LowPassMidShare
	end
end

local function update()
	for _, name in BUSES do
		groups[name].Volume = Tuning.Audio.BusVolume * (1 - math.clamp(layers:get(`bus.{name}`), 0, 1))
	end
	for name, sound in loops do
		local def = Tuning.Sounds[name]
		local volume = math.max(0, layers:get(`loop.{name}`)) * def.Volume
		sound.Volume = volume
		sound.PlaybackSpeed = def.Pitch * math.max(0.05, 1 + layers:get(`pitch.{name}`))
		if volume > 1e-3 and not sound.IsPlaying then
			sound:Play()
		elseif volume <= 1e-3 and sound.IsPlaying then
			sound:Stop()
		end
	end
end

function Audio.start()
	local names = {}
	for _, bus in BUSES do
		local group = Instance.new("SoundGroup")
		group.Name = `Fall{bus}`
		group.Parent = SoundService
		groups[bus] = group
		table.insert(names, `bus.{bus}`)
		if LOW_PASS_BUSES[bus] then
			local eq = Instance.new("EqualizerSoundEffect")
			eq.LowGain = 0
			eq.MidGain = 0
			eq.HighGain = 0
			eq.Parent = group
			table.insert(equalizers, eq)
		end
	end
	for name, def in Tuning.Sounds do
		if def.Loop then
			loops[name] = makeSound(name)
			table.insert(names, `loop.{name}`)
			table.insert(names, `pitch.{name}`)
		end
	end
	layers = Layers.new(names)
	RunService.RenderStepped:Connect(update)
end

return Audio
