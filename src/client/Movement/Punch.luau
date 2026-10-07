--!strict
-- LMB punch (spec §15, milestone 2). Holding charges it in any state without locking movement; while charging,
-- walk, hop and glide speed take a small cut. On release:
--   * a surface under the crosshair within Reach: rocket jump. The punch reflects off the surface, so it is
--     strongest point blank and adds back the speed you were moving into the surface. Releasing early just
--     stops you. Standing still it is a weak pop; timed off a hop or a fall it launches.
--   * otherwise, in the air: a dash toward the crosshair that costs glide energy.
-- The controller calls `update` before the state runs; it returns a transition when the punch moves you.

local Shared = game:GetService("ReplicatedStorage").Shared
local Signal = require(Shared.Signal)
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)

local Punch = {}

-- (kind: "Rocket" | "Dash" | "Whiff", power 0–1, position)
Punch.Fired = Signal.new() :: Signal.Signal<string, number, Vector3>

-- Speed multiplier while a punch is charging.
function Punch.slow(ctx: Types.Ctx, mult: number): number
	return if ctx.PunchHold ~= nil then mult else 1
end

local function power(hold: number): number
	local P = Tuning.Punch
	return P.MinPower + (1 - P.MinPower) * math.clamp(hold / P.ChargeTime, 0, 1)
end

local function rocket(ctx: Types.Ctx, strength: number): (Vector3?, Vector3?)
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
	local clearance = math.max(0, hit.Distance - ctx.StandHeight)
	local proximity = (1 - math.clamp(clearance / P.Reach, 0, 1)) ^ P.ProximityExponent
	local incoming = math.max(0, ctx.Velocity:Dot(into))
	local push = proximity * (incoming * (1 + P.Reflect * strength) + P.Impulse * strength)
	local velocity = ctx.Velocity - into * push
	local cap = math.max(ctx.Velocity.Magnitude, P.MaxLaunchSpeed)
	if velocity.Magnitude > cap then
		velocity = velocity.Unit * cap
	end
	return velocity, hit.Position
end

local function dash(ctx: Types.Ctx, strength: number): Vector3?
	local P = Tuning.Punch
	local toAim = ctx.AimPoint - ctx.Root.Position
	if toAim.Magnitude < 1e-3 or ctx.GlideEnergy <= 0 then
		return nil
	end
	-- Low on energy, the dash is as strong as what's left pays for.
	local cost = P.DashEnergyCost * strength
	local paid = math.min(cost, ctx.GlideEnergy)
	ctx.GlideEnergy -= paid
	local velocity = ctx.Velocity + toAim.Unit * P.DashSpeed * strength * (paid / cost)
	local cap = math.max(ctx.Velocity.Magnitude, Tuning.Tech.MaxCarrySpeed)
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
	local strength = power(hold)

	local launch, at = rocket(ctx, strength)
	if launch and at and launch ~= ctx.Velocity then
		ctx.Velocity = launch
		Punch.Fired:Fire("Rocket", strength, at)
		return "Hop", { Launch = true }
	end
	if mode == "Air" then
		local velocity = dash(ctx, strength)
		if velocity then
			ctx.Velocity = velocity
			Punch.Fired:Fire("Dash", strength, ctx.Root.Position)
			-- A dash during a held dive stays in the dive; it just goes faster.
			if ctx.State == "Dive" and ctx.Input.JumpHeld then
				return nil
			end
			return "Glide", nil
		end
	end
	Punch.Fired:Fire("Whiff", strength, ctx.Root.Position)
	return nil
end

return Punch
