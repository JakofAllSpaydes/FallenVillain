--!strict
-- Concentric charge rings, one per tier. The rings are a purely visual split of one hold time: ring k fills
-- from the end of ring k−1 to `ends[k]` seconds, so with tier ends that spread out, each ring fills fast at
-- first and later rings take longer. Ring 1 is innermost; each ring appears when the previous one fills.
-- A filled ring turns gold; the ring that is filling shows its tier colour. Fades out (keeping its fill) when
-- the hold ends. Add a tier to the tier list and a ring appears for it.

local Tuning = require(game:GetService("ReplicatedStorage").Shared.Tuning)
local Arc = require(script.Parent.Arc)

local ChargeRings = {}
ChargeRings.__index = ChargeRings

-- Look of the rings; not gameplay tuning.
local FULL = Color3.fromRGB(240, 200, 90)
local TIER_COLORS = {
	Color3.new(1, 1, 1),
	Color3.fromRGB(175, 205, 255),
	Color3.fromRGB(255, 160, 70),
	Color3.fromRGB(255, 80, 70),
	Color3.fromRGB(220, 130, 255),
	Color3.fromRGB(255, 240, 225),
}

type Ring = { Arc: Arc.Arc, Alpha: number, Fill: number, Color: Color3 }
export type ChargeRings = typeof(setmetatable({} :: { Rings: { Ring }, Held: number }, ChargeRings))

function ChargeRings.new(parent: Instance, count: number): ChargeRings
	local U = Tuning.Ui
	local rings = {}
	-- Outermost first so inner rings draw on top.
	for k = count, 1, -1 do
		local scale = if count > 1 then U.RingInnerScale + (1 - U.RingInnerScale) * (k - 1) / (count - 1) else 1
		local arc =
			Arc.new(parent, UDim2.fromScale(scale, scale), U.RingThickness, U.RingBorder, U.RingTrackTransparency)
		rings[k] = { Arc = arc, Alpha = 0, Fill = 0, Color = TIER_COLORS[1] }
	end
	return setmetatable({ Rings = rings, Held = 0 }, ChargeRings)
end

-- held: seconds of the current hold, or nil to fade out. ends: seconds where each ring is full.
-- showFrom: seconds before which nothing shows. maxed: everything shows gold (the charge can't grow further).
function ChargeRings.update(
	self: ChargeRings,
	dt: number,
	held: number?,
	ends: { number },
	showFrom: number,
	maxed: boolean
)
	local fadeStep = dt / Tuning.Ui.RingFade
	local active = held ~= nil and held >= showFrom
	if active then
		self.Held = held :: number
	end
	for k, ring in self.Rings do
		local start = ends[k - 1] or 0
		local finish = ends[k] or start
		local shown = active and (k == 1 or self.Held >= start)
		if shown then
			ring.Fill = math.clamp((self.Held - start) / math.max(finish - start, 1e-3), 0, 1)
			ring.Color = if maxed or ring.Fill >= 1 then FULL else TIER_COLORS[math.min(k, #TIER_COLORS)]
			ring.Alpha = math.min(1, ring.Alpha + fadeStep)
		else
			ring.Alpha = math.max(0, ring.Alpha - fadeStep)
		end
		ring.Arc:set(ring.Fill, ring.Color, ring.Alpha)
	end
end

return ChargeRings
