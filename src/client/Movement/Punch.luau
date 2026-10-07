--!strict
-- LMB punch (spec §15, milestone 2). Holding charges it in any state without locking movement; while charging,
-- walk, hop and glide speed take a small cut. Releasing always does something and cancels whatever you were
-- doing (Charging, Burst, Dive, Glide...):
--   * a surface under the crosshair within Reach: rocket jump. The punch reflects off the surface, so it is
--     strongest point blank and bounces back the speed you were moving into the surface. Released early it
--     mostly stops you. From the ground (no momentum to reflect) it is weaker (GroundedMult).
--   * otherwise: a dash toward the crosshair, from a tap's burst up to a big charged lunge. On the ground a
--     level dash is a slide; one aimed upward leaves the ground.
-- The controller calls `update` before the state runs; it returns the transition when the punch fires.

local Shared = game:GetService("ReplicatedStorage").Shared
local Signal = require(Shared.Signal)
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)
local MathUtil = require(script.Parent.MathUtil)

local Punch = {}

-- (kind: "Rocket" | "Dash", power 0–1, position)
Punch.Fired = Signal.new() :: Signal.Signal<string, number, Vector3>

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
	local hit = workspace:Raycast(ctx.Root.Position, into * (P.Reach + ctx.StandHeight), ctx.RaycastParams)
	if not hit then
		return nil, nil
	end
	local strength = (P.MinPower + (1 - P.MinPower) * charge) * (if grounded then P.GroundedMult else 1)
	local clearance = math.max(0, hit.Distance - ctx.StandHeight)
	local proximity = (1 - math.clamp(clearance / P.Reach, 0, 1)) ^ P.ProximityExponent
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

local function dash(ctx: Types.Ctx, charge: number): Vector3
	local P = Tuning.Punch
	local toAim = ctx.AimPoint - ctx.Root.Position
	local direction = if toAim.Magnitude > 1e-3 then toAim.Unit else ctx.LookDirection
	ctx.GlideEnergy = math.max(0, ctx.GlideEnergy - P.DashEnergyCost * charge)
	-- Keep the speed already going this way, trim the rest, then add the lunge.
	local along = math.max(0, ctx.Velocity:Dot(direction))
	local across = ctx.Velocity - direction * ctx.Velocity:Dot(direction)
	local boost = P.DashTapSpeed + (P.DashFullSpeed - P.DashTapSpeed) * charge
	local velocity = direction * (along + boost) + across * P.DashKeepSideways
	local cap = math.max(ctx.Velocity.Magnitude, P.MaxDashSpeed)
	if velocity.Magnitude > cap then
		velocity = velocity.Unit * cap
	end
	return velocity
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
		ctx.Velocity = launch
		Punch.Fired:Fire("Rocket", charge, at)
		return "Hop", { Launch = true }
	end

	local velocity = dash(ctx, charge)
	ctx.Velocity = velocity
	Punch.Fired:Fire("Dash", charge, ctx.Root.Position)
	if not grounded then
		return "Glide", nil
	end
	-- From the ground: a level lunge slides, one aimed upward takes off.
	if velocity.Unit.Y > Tuning.Punch.GroundLiftThreshold then
		return "Hop", { Launch = true }
	end
	ctx.LandVelocity = MathUtil.flat(velocity)
	return "Slide", nil
end

return Punch
