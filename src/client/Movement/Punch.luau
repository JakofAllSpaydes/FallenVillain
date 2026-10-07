--!strict
-- LMB punch (spec §15, milestone 2). Holding charges it in any state without locking movement; while charging,
-- walk, hop and glide speed take a small cut. Releasing always fires and cancels whatever you were doing
-- (Charging, Burst, Dive, Glide...). Every punch is a burst of speed; the rocket jump is an extra on top that
-- only happens when you mean it:
--   * dash: toward the crosshair, from a tap's burst up to a big charged lunge. From the ground it always lifts
--     off a little, so gravity carries it into a hop rather than a slide.
--   * rocket jump (like TF2): aim steeply at a surface (at least Punch.RocketMinAngle below level) within Reach.
--     It pushes you away along the opposite of the aim, plus a share of the forward burst along your facing, so
--     straight down pops you up and forward. Much stronger point blank, where it also bounces back the speed
--     you were moving into the surface; from the ground (no momentum to reflect) it is weaker (GroundedMult).
-- The controller calls `update` before the state runs; it returns the transition when the punch fires.

local Shared = game:GetService("ReplicatedStorage").Shared
local Signal = require(Shared.Signal)
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)
local MathUtil = require(script.Parent.MathUtil)

local Punch = {}

-- (kind: "Rocket" | "Dash", power 0–1, position)
Punch.Fired = Signal.new() :: Signal.Signal<string, number, Vector3>

-- Each air frame, the speed a punch added dies off at a rate set by its charge: a tap is a sharp jab whose
-- speed is gone almost at once; a charged punch carries. Only removes speed still going the boost's way.
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

-- Speed multiplier while a punch is charging.
function Punch.slow(ctx: Types.Ctx, mult: number): number
	return if ctx.PunchHold ~= nil then mult else 1
end

local function rocket(ctx: Types.Ctx, charge: number, grounded: boolean): (Vector3?, Vector3?)
	local P = Tuning.Punch
	local toAim = ctx.AimPoint - ctx.Root.Position
	if toAim.Magnitude < 1e-3 then
		return nil, nil
	end
	local into = toAim.Unit
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

local function boostFor(charge: number): number
	local P = Tuning.Punch
	return P.DashTapSpeed + (P.DashFullSpeed - P.DashTapSpeed) * charge
end

-- Returns the new velocity and the lunge it added.
local function dash(ctx: Types.Ctx, charge: number): (Vector3, Vector3)
	local P = Tuning.Punch
	local toAim = ctx.AimPoint - ctx.Root.Position
	local direction = if toAim.Magnitude > 1e-3 then toAim.Unit else ctx.LookDirection
	ctx.GlideEnergy = math.max(0, ctx.GlideEnergy - P.DashEnergyCost * charge)
	-- Keep the speed already going this way, trim the rest, then add the lunge.
	local along = math.max(0, ctx.Velocity:Dot(direction))
	local across = ctx.Velocity - direction * ctx.Velocity:Dot(direction)
	local boost = boostFor(charge)
	local velocity = direction * (along + boost) + across * P.DashKeepSideways
	local added = direction * boost
	local cap = math.max(ctx.Velocity.Magnitude, P.MaxDashSpeed)
	if velocity.Magnitude > cap then
		velocity = velocity.Unit * cap
	end
	return velocity, added
end

function Punch.update(ctx: Types.Ctx, mode: ("Ground" | "Air")?, dt: number): (Types.MovementState?, any)
	if ctx.Input.PrimaryHeld then
		ctx.PunchHold = (ctx.PunchHold or 0) + dt
		return nil
	end
	local hold = ctx.PunchHold
	ctx.PunchHold = nil
	if hold == nil or mode == nil or ctx.Now < ctx.PunchReadyAt then
		return nil
	end
	ctx.PunchReadyAt = ctx.Now + Tuning.Punch.Cooldown
	local charge = math.clamp(hold / Tuning.Punch.ChargeTime, 0, 1)
	local grounded = mode == "Ground"

	local launch, at = rocket(ctx, charge, grounded)
	if launch and at then
		-- The forward burst still happens, along your facing; the bounce rides on top of it.
		local P = Tuning.Punch
		local forward = MathUtil.flat(ctx.LookDirection)
		local added = Vector3.zero
		if forward.Magnitude > 1e-3 then
			added = forward.Unit * boostFor(charge) * P.RocketForwardShare
			launch += added
		end
		setBoost(ctx, added, charge)
		local cap = math.max(ctx.Velocity.Magnitude, P.MaxLaunchSpeed)
		if launch.Magnitude > cap then
			launch = launch.Unit * cap
		end
		ctx.GlideEnergy = math.max(0, ctx.GlideEnergy - P.DashEnergyCost * charge)
		ctx.Velocity = launch
		Punch.Fired:Fire("Rocket", charge, at)
		return "Hop", { Launch = true }
	end

	-- During a held dive the lunge just adds to the dive and stays until it hits something.
	if ctx.State == "Dive" and ctx.Input.JumpHeld then
		local toAim = ctx.AimPoint - ctx.Root.Position
		local direction = if toAim.Magnitude > 1e-3 then toAim.Unit else ctx.LookDirection
		local boost = math.min(boostFor(charge), math.max(0, Tuning.Punch.MaxDiveBonus - ctx.DiveBonus))
		ctx.Velocity += direction * boost
		ctx.DiveBonus += boost
		ctx.GlideEnergy = math.max(0, ctx.GlideEnergy - Tuning.Punch.DashEnergyCost * charge)
		Punch.Fired:Fire("Dash", charge, ctx.Root.Position)
		return nil
	end

	local velocity, added = dash(ctx, charge)
	-- From the ground only the horizontal lunge decays; the lift is left to gravity.
	setBoost(ctx, if grounded then MathUtil.flat(added) else added, charge)
	ctx.Velocity = velocity
	Punch.Fired:Fire("Dash", charge, ctx.Root.Position)
	if not grounded then
		return "Glide", nil
	end
	ctx.Velocity = MathUtil.flat(velocity) + Vector3.yAxis * math.max(velocity.Y, Tuning.Punch.GroundDashLift)
	return "Hop", { Launch = true }
end

return Punch
