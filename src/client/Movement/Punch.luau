--!strict
-- LMB punch (spec §15, milestone 2). Holding charges it anywhere, ground or air, for as long as you like (the
-- forward twin of the Burst): nothing but releasing it ever spends the charge. While charging, walk, hop and
-- glide speed take a small cut. The lunge it adds follows Punch.HoldBoosts, from a tap's jab up to a minute's
-- map-crossing launch, and crossing a Punch.Tiers threshold fires TierReached for feedback.
-- Releasing always fires and cancels whatever you were doing (Charging, Burst, Glide...):
--   * dash: toward the crosshair. During a held dive it adds to the dive instead and keeps until it ends.
--     From the ground it always lifts off a little, so gravity carries it into a hop rather than a slide.
--   * rocket jump (like TF2): aim steeply at a surface (at least Punch.RocketMinAngle below level) within Reach.
--     It pushes you away along the opposite of the aim, plus a share of the lunge along your facing, so
--     straight down pops you up and forward. Much stronger point blank, where it also bounces back the speed
--     you were moving into the surface; from the ground (no momentum to reflect) it is weaker (GroundedMult).
-- The lunge decays fast after a tap and slowly after a long charge (Punch.decay).
-- The controller calls `update` before the state runs; it returns the transition when the punch fires.

local Shared = game:GetService("ReplicatedStorage").Shared
local Signal = require(Shared.Signal)
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)
local MathUtil = require(script.Parent.MathUtil)

local Punch = {}

-- (kind: "Rocket" | "Dash" | "Fizzle", seconds held, position)
Punch.Fired = Signal.new() :: Signal.Signal<string, number, Vector3>
-- (seconds held) when a charge starts
Punch.ChargeStarted = Signal.new() :: Signal.Signal<number>
-- (seconds held) each time the hold crosses a Punch.Tiers threshold
Punch.TierReached = Signal.new() :: Signal.Signal<number>

-- Lunge speed for a hold of `seconds`.
function Punch.boostFor(seconds: number): number
	return MathUtil.holdCurve(Tuning.Punch.HoldBoosts, seconds)
end

-- Speed multiplier while a punch is charging.
function Punch.slow(ctx: Types.Ctx, mult: number): number
	return if ctx.PunchHold ~= nil then mult else 1
end

-- Each air frame, the speed a punch added dies off at a rate set by its charge. Only removes speed still going
-- the boost's way.
function Punch.decay(ctx: Types.Ctx, dt: number)
	local boost = ctx.PunchBoost
	if boost.Magnitude < 0.5 then
		ctx.PunchBoost = Vector3.zero
		return
	end
	local keep = math.exp(-ctx.PunchBoostRate * dt)
	local remove = boost * (1 - keep)
	ctx.PunchBoost = boost * keep
	local direction = remove.Unit
	local along = math.max(0, ctx.Velocity:Dot(direction))
	ctx.Velocity -= direction * math.min(remove.Magnitude, along)
end

local function setBoost(ctx: Types.Ctx, added: Vector3, charge: number)
	local P = Tuning.Punch
	ctx.PunchBoost = added
	ctx.PunchBoostRate = P.DashDecayTap + (P.DashDecayFull - P.DashDecayTap) * charge
end

local function aimDirection(ctx: Types.Ctx): Vector3
	local toAim = ctx.AimPoint - ctx.Root.Position
	return if toAim.Magnitude > 1e-3 then toAim.Unit else ctx.LookDirection
end

-- The rocket bounce off a surface, or nil if the aim isn't steep enough or nothing is in reach.
local function rocket(ctx: Types.Ctx, charge: number, grounded: boolean): (Vector3?, Vector3?)
	local P = Tuning.Punch
	local into = aimDirection(ctx)
	if into.Y > -math.sin(math.rad(P.RocketMinAngle)) then
		return nil, nil
	end
	local hit = workspace:Raycast(ctx.Root.Position, into * (P.Reach + ctx.StandHeight), ctx.RaycastParams)
	if not hit then
		return nil, nil
	end
	local strength = (P.MinPower + (1 - P.MinPower) * charge) * (if grounded then P.GroundedMult else 1)
	local clearance = math.max(0, hit.Distance - ctx.StandHeight)
	local falloff = (1 - math.clamp(clearance / P.Reach, 0, 1)) ^ P.ProximityExponent
	local proximity = P.MinProximity + (1 - P.MinProximity) * falloff
	local incoming = math.max(0, ctx.Velocity:Dot(into))
	local push = proximity * (incoming * (1 + P.Reflect * strength) + P.Impulse * strength)
	if push < 1e-3 then
		return nil, nil
	end
	local velocity = ctx.Velocity - into * push
	local cap = math.max(ctx.Velocity.Magnitude, P.MaxLaunchSpeed)
	if velocity.Magnitude > cap then
		velocity = velocity.Unit * cap
	end
	return velocity, hit.Position
end

local function release(ctx: Types.Ctx, hold: number, grounded: boolean): (Types.MovementState?, any)
	local P = Tuning.Punch
	local charge = math.clamp(hold / P.ChargeTime, 0, 1)
	local boost = Punch.boostFor(hold)
	ctx.GlideEnergy = math.max(0, ctx.GlideEnergy - P.DashEnergyCost * charge)

	local launch, at = rocket(ctx, charge, grounded)
	if launch and at then
		-- The forward lunge still happens, along your facing; the bounce rides on top of it.
		local forward = MathUtil.flat(ctx.LookDirection)
		local added = if forward.Magnitude > 1e-3 then forward.Unit * boost * P.RocketForwardShare else Vector3.zero
		setBoost(ctx, added, charge)
		ctx.Velocity = launch + added
		Punch.Fired:Fire("Rocket", hold, at)
		return "Hop", { Launch = true }
	end

	local direction = aimDirection(ctx)
	if ctx.State == "Dive" and ctx.Input.JumpHeld then
		-- The lunge adds to the dive and stays until it ends; stacking taps is capped, one big punch never is.
		local target = math.max(math.min(ctx.DiveBonus + boost, P.MaxDiveBonus), boost)
		local added = math.max(0, target - ctx.DiveBonus)
		ctx.Velocity += direction * added
		ctx.DiveBonus += added
		Punch.Fired:Fire("Dash", hold, ctx.Root.Position)
		return nil
	end

	-- Keep the speed already going this way, trim the rest, then add the lunge.
	local along = math.max(0, ctx.Velocity:Dot(direction))
	local across = ctx.Velocity - direction * ctx.Velocity:Dot(direction)
	local velocity = direction * (along + boost) + across * P.DashKeepSideways
	local added = direction * boost
	Punch.Fired:Fire("Dash", hold, ctx.Root.Position)
	if not grounded then
		setBoost(ctx, added, charge)
		ctx.Velocity = velocity
		return "Glide", nil
	end
	-- From the ground only the horizontal lunge decays; the lift is left to gravity.
	setBoost(ctx, MathUtil.flat(added), charge)
	ctx.Velocity = MathUtil.flat(velocity) + Vector3.yAxis * math.max(velocity.Y, P.GroundDashLift)
	return "Hop", { Launch = true }
end

function Punch.update(ctx: Types.Ctx, mode: ("Ground" | "Air")?, dt: number): (Types.MovementState?, any)
	if ctx.Input.PrimaryHeld then
		local before = ctx.PunchHold
		local hold = (before or 0) + dt
		ctx.PunchHold = hold
		if before == nil then
			Punch.ChargeStarted:Fire(hold)
		elseif MathUtil.tier(Tuning.Punch.Tiers, hold) > MathUtil.tier(Tuning.Punch.Tiers, before) then
			Punch.TierReached:Fire(hold)
		end
		return nil
	end
	local hold = ctx.PunchHold
	if hold == nil or mode == nil then
		return nil
	end
	ctx.PunchHold = nil
	-- Released inside the cooldown: the click fizzles; the next one fires normally.
	if ctx.Now < ctx.PunchReadyAt then
		Punch.Fired:Fire("Fizzle", hold, ctx.Root.Position)
		return nil
	end
	ctx.PunchReadyAt = ctx.Now + Tuning.Punch.Cooldown
	return release(ctx, hold, mode == "Ground")
end

return Punch
