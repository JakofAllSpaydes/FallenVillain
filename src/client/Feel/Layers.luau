--!strict
-- Named additive values with their own timing (spec §4.10). Each layer is a held value that tweens to a target
-- (Quad out) plus one-shot kicks that decay to zero, summed. Camera effects, post, audio, VFX and HUD each keep a
-- set, so a burst recoil and an ascent FOV ramp stack instead of fighting. Times are real time, not hitstop time.

local Layers = {}
Layers.__index = Layers

-- Kick curves (value over 0–1 progress, from 1 to 0):
--   quad    (1 − p)²            the default: quick start, soft tail
--   expo    e^(−6p) shaped      snappier: most of the hit in the first frames, a long faint tail
--   spring  damped cosine       overshoots once past zero and settles, for recoil that springs back
--   hold    flat then quad      full strength for the first third, then decays
export type Curve = "quad" | "expo" | "spring" | "hold"

type Kick = { Amount: number, Start: number, Duration: number, Curve: Curve }
type Layer = { From: number, To: number, Start: number, Duration: number, Kicks: { Kick } }

local EXPO_RATE = 6
local SPRING_CYCLES = 1.25
local SPRING_DECAY = 4.5
local HOLD_SHARE = 0.33

local function curve(kind: Curve, p: number): number
	if kind == "expo" then
		return (math.exp(-EXPO_RATE * p) - math.exp(-EXPO_RATE)) / (1 - math.exp(-EXPO_RATE))
	elseif kind == "spring" then
		return math.exp(-SPRING_DECAY * p) * math.cos(2 * math.pi * SPRING_CYCLES * p)
	elseif kind == "hold" then
		if p < HOLD_SHARE then
			return 1
		end
		local q = (p - HOLD_SHARE) / (1 - HOLD_SHARE)
		return (1 - q) ^ 2
	end
	return (1 - p) ^ 2
end

export type Set = typeof(setmetatable({} :: { Layers: { [string]: Layer } }, Layers))

function Layers.new(names: { string }): Set
	local layers = {}
	for _, name in names do
		layers[name] = { From = 0, To = 0, Start = 0, Duration = 0, Kicks = {} }
	end
	return setmetatable({ Layers = layers }, Layers)
end

local function held(layer: Layer, now: number): number
	if layer.Duration <= 0 or now >= layer.Start + layer.Duration then
		return layer.To
	end
	local p = math.clamp((now - layer.Start) / layer.Duration, 0, 1)
	return layer.From + (layer.To - layer.From) * (1 - (1 - p) ^ 2)
end

local function find(self: Set, name: string): Layer
	local layer = self.Layers[name]
	assert(layer, `unknown effect layer {name}`)
	return layer
end

function Layers.has(self: Set, name: string): boolean
	return self.Layers[name] ~= nil
end

-- Tween the held value to `to` over `duration` (0 = snap), starting from `from` or the current value.
function Layers.set(self: Set, name: string, to: number, duration: number, from: number?)
	local layer = find(self, name)
	local now = os.clock()
	layer.From = if from ~= nil then from else held(layer, now)
	layer.To = to
	layer.Start = now
	layer.Duration = duration
end

-- Add a one-shot that starts at `amount` and decays to zero over `duration` along `kind` (default quad).
function Layers.kick(self: Set, name: string, amount: number, duration: number, kind: Curve?)
	table.insert(find(self, name).Kicks, {
		Amount = amount,
		Start = os.clock(),
		Duration = math.max(duration, 1e-3),
		Curve = kind or "quad",
	})
end

-- Apply a FeelTable entry to a layer: `kick` adds a one-shot (with optional `curve`), otherwise `to` (with
-- optional `from`) tweens.
function Layers.apply(self: Set, name: string, entry: { [string]: any }, duration: number)
	if entry.kick ~= nil then
		self:kick(name, entry.kick, duration, entry.curve)
	elseif entry.to ~= nil then
		self:set(name, entry.to, duration, entry.from)
	end
end

function Layers.get(self: Set, name: string): number
	local layer = find(self, name)
	local now = os.clock()
	local value = held(layer, now)
	for index = #layer.Kicks, 1, -1 do
		local kick = layer.Kicks[index]
		local p = (now - kick.Start) / kick.Duration
		if p >= 1 then
			table.remove(layer.Kicks, index)
		else
			value += kick.Amount * curve(kick.Curve, p)
		end
	end
	return value
end

return Layers
