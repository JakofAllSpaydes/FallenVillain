--!strict
-- A pair of charge rings: the inner one fills for the basic charge and turns gold when full; the outer one
-- appears around it for the long charge and steps through tier colours as it climbs. Each ring fades in while
-- its value is given and fades out (keeping its last fill) when it isn't.

local Tuning = require(game:GetService("ReplicatedStorage").Shared.Tuning)
local Arc = require(script.Parent.Arc)

local ChargeRings = {}
ChargeRings.__index = ChargeRings

-- Look of the rings; not gameplay tuning.
local BASE = Color3.new(1, 1, 1)
local FULL = Color3.fromRGB(240, 200, 90)
local TIER_COLORS = {
	Color3.fromRGB(175, 205, 255),
	Color3.fromRGB(240, 200, 90),
	Color3.fromRGB(255, 140, 50),
	Color3.fromRGB(255, 70, 60),
	Color3.fromRGB(255, 240, 225),
}

type Ring = { Arc: Arc.Arc, Alpha: number, Fill: number, Color: Color3 }
export type ChargeRings = typeof(setmetatable({} :: { Inner: Ring, Outer: Ring }, ChargeRings))

local function newRing(parent: Instance, scale: number): Ring
	local U = Tuning.Ui
	local arc = Arc.new(parent, UDim2.fromScale(scale, scale), U.RingThickness, U.RingBorder, U.RingTrackTransparency)
	return { Arc = arc, Alpha = 0, Fill = 0, Color = BASE }
end

function ChargeRings.new(parent: Instance): ChargeRings
	-- Outer first so the inner ring draws on top of it.
	local outer = newRing(parent, 1)
	local inner = newRing(parent, Tuning.Ui.RingInnerScale)
	return setmetatable({ Inner = inner, Outer = outer }, ChargeRings)
end

local function step(ring: Ring, value: number?, color: Color3, dt: number)
	local fadeStep = dt / Tuning.Ui.RingFade
	if value ~= nil then
		ring.Fill = value
		ring.Color = color
		ring.Alpha = math.min(1, ring.Alpha + fadeStep)
	else
		ring.Alpha = math.max(0, ring.Alpha - fadeStep)
	end
	ring.Arc:set(ring.Fill, ring.Color, ring.Alpha)
end

-- inner / outer: 0–1 fills, or nil to fade that ring out. tier: 1-based colour step for the outer ring.
function ChargeRings.update(self: ChargeRings, dt: number, inner: number?, outer: number?, tier: number)
	step(self.Inner, inner, if inner ~= nil and inner >= 1 then FULL else BASE, dt)
	step(self.Outer, outer, TIER_COLORS[math.clamp(tier, 1, #TIER_COLORS)], dt)
end

return ChargeRings
