--!strict
-- Concentric charge rings, one per tier. The rings are a purely visual split of one hold time: ring k fills
-- from the end of ring k−1 to `ends[k]` seconds, so with tier ends that spread out, each ring fills fast at
-- first and later rings take longer. Ring 1 is innermost; each ring appears when the previous one fills.
-- A filled ring turns gold; the ring that is filling wears its circle's colour from the action's hue ramp
-- (Ui.ChargePalettes). Only the unlocked rings and the next one show (the next as a dim locked track, a tease
-- of what a level will open); the rest stay hidden.
-- The wheel only appears once the hold outlasts `showFrom` (so taps never flicker it) and fades in from
-- Ui.WheelStartAlpha to full as the first ring completes. Fades out (keeping its fill) when the hold ends.
-- Add a tier to the tier list and a ring appears for it.

local Tuning = require(game:GetService("ReplicatedStorage").Shared.Tuning)
local Arc = require(script.Parent.Arc)

local ChargeRings = {}
ChargeRings.__index = ChargeRings

-- Look of the rings; not gameplay tuning.
local FULL = Color3.fromRGB(240, 200, 90) -- a filled ring, and every ring at max charge
local LOCKED = Color3.fromRGB(70, 70, 80)
local LOCKED_ALPHA = 0.45

type Ring = { Arc: Arc.Arc, Alpha: number, Fill: number, Color: Color3 }
export type ChargeRings = typeof(setmetatable(
	{} :: { Rings: { Ring }, Held: number, Offset: number, Kind: string },
	ChargeRings
))

-- The colour of ring k: the hop ring (when the wheel has one in front) is neutral, then the action's ramp.
local function ringColor(self: ChargeRings, k: number): Color3
	if k <= self.Offset then
		return Tuning.Ui.HopRingColor
	end
	local circles = #self.Rings - self.Offset
	return ChargeRings.circleColor(self.Kind, k - self.Offset, circles)
end

-- Circle `index` of `count` in the action's ramp (shared with the charge VFX).
function ChargeRings.circleColor(kind: string, index: number, count: number): Color3
	local palette = Tuning.Ui.ChargePalettes[kind] or Tuning.Ui.ChargePalettes.Punch
	local t = if count > 1 then math.clamp((index - 1) / (count - 1), 0, 1) else 0
	return palette.From:Lerp(palette.To, t)
end

-- `kind` picks the hue ramp (Burst, Punch, Blast); `hopRing`: the first ring is a hop ring in front of the
-- circles (the jump wheel).
function ChargeRings.new(parent: Instance, count: number, kind: string, hopRing: boolean?): ChargeRings
	local U = Tuning.Ui
	local rings = {}
	-- Outermost first so inner rings draw on top.
	for k = count, 1, -1 do
		local scale = if count > 1 then U.RingInnerScale + (1 - U.RingInnerScale) * (k - 1) / (count - 1) else 1
		local arc =
			Arc.new(parent, UDim2.fromScale(scale, scale), U.RingThickness, U.RingBorder, U.RingTrackTransparency)
		rings[k] = { Arc = arc, Alpha = 0, Fill = 0, Color = FULL }
	end
	return setmetatable({ Rings = rings, Held = 0, Offset = if hopRing then 1 else 0, Kind = kind }, ChargeRings)
end

-- held: seconds of the current hold, or nil to fade out. ends: seconds where each ring is full.
-- showFrom: seconds before which nothing shows. maxed: everything unlocked shows gold (the charge can't grow
-- further). unlocked: rings past this many are locked; the first locked one shows dim, the rest are hidden
-- (default: all unlocked).
function ChargeRings.update(
	self: ChargeRings,
	dt: number,
	held: number?,
	ends: { number },
	showFrom: number,
	maxed: boolean,
	unlocked: number?
)
	local U = Tuning.Ui
	local fadeStep = dt / U.RingFade
	local active = held ~= nil and held >= showFrom
	local open = unlocked or #self.Rings
	if active then
		self.Held = held :: number
	end
	-- The whole wheel fades in from WheelStartAlpha as the first ring completes.
	local firstEnd = ends[1] or showFrom
	local reveal = U.WheelStartAlpha
		+ (1 - U.WheelStartAlpha) * math.clamp((self.Held - showFrom) / math.max(firstEnd - showFrom, 1e-3), 0, 1)
	for k, ring in self.Rings do
		local start = ends[k - 1] or 0
		local finish = ends[k] or start
		if k > open + 1 then
			-- Beyond the tease: hidden.
			ring.Alpha = 0
			ring.Arc:set(0, LOCKED, 0)
			continue
		end
		if k > open then
			-- The next circle to earn: a dim empty track while the wheel is up.
			ring.Fill = 0
			ring.Color = LOCKED
			ring.Alpha = if active
				then math.min(LOCKED_ALPHA, ring.Alpha + fadeStep)
				else math.max(0, ring.Alpha - fadeStep)
			ring.Arc:set(0, ring.Color, ring.Alpha * reveal)
			continue
		end
		local shown = active and (k == 1 or self.Held >= start)
		if shown then
			ring.Fill = math.clamp((self.Held - start) / math.max(finish - start, 1e-3), 0, 1)
			ring.Color = if maxed or ring.Fill >= 1 then FULL else ringColor(self, k)
			ring.Alpha = math.min(1, ring.Alpha + fadeStep)
		else
			ring.Alpha = math.max(0, ring.Alpha - fadeStep)
		end
		ring.Arc:set(ring.Fill, ring.Color, ring.Alpha * reveal)
	end
end

return ChargeRings
