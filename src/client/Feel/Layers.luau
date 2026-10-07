--!strict
-- Named additive values with their own timing (spec §4.10). Each layer is a held value that tweens to a target
-- (Quad out) plus one-shot kicks that decay to zero, summed. Camera effects, post, audio, VFX and HUD each keep a
-- set, so a burst recoil and an ascent FOV ramp stack instead of fighting. Times are real time, not hitstop time.

local Layers = {}
Layers.__index = Layers

type Kick = { Amount: number, Start: number, Duration: number }
type Layer = { From: number, To: number, Start: number, Duration: number, Kicks: { Kick } }

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

-- Add a one-shot that starts at `amount` and decays to zero over `duration` (Quad out).
function Layers.kick(self: Set, name: string, amount: number, duration: number)
	table.insert(find(self, name).Kicks, { Amount = amount, Start = os.clock(), Duration = math.max(duration, 1e-3) })
end

-- Apply a FeelTable entry to a layer: `kick` adds a one-shot, otherwise `to` (with optional `from`) tweens.
function Layers.apply(self: Set, name: string, entry: { [string]: any }, duration: number)
	if entry.kick ~= nil then
		self:kick(name, entry.kick, duration)
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
			value += kick.Amount * (1 - p) ^ 2
		end
	end
	return value
end

return Layers
