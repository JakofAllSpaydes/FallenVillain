--!strict
-- Burst (spec §3, §4.2–4.3; §15 milestone 6): straight up. The Space hold picks a target height from
-- Burst.HoldHeights, the hold capped by the level's unlocked circles and the height scaled by its power
-- multiplier (shared/Progression.luau); the launch velocity is solved to reach it. No gravity for the ignition,
-- then Burst gravity. No steering at first, then a slow drift. Hands over to Hang once the climb has nearly
-- stopped.

local Shared = game:GetService("ReplicatedStorage").Shared
local Progression = require(Shared.Progression)
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)
local MathUtil = require(script.Parent.Parent.MathUtil)

local Burst = { Punch = "Air" }

local function gravity(): number
	return math.max(Tuning.Gravity.Burst, 1e-3)
end

-- Seconds to apex and height gained for a launch velocity.
function Burst.predict(velocity: number): (number, number)
	local B = Tuning.Burst
	local g = gravity()
	return B.IgnitionTime + velocity / g, velocity * B.IgnitionTime + velocity * velocity / (2 * g)
end

-- Target height for a hold of `seconds` (Burst.HoldHeights) at `level`: the hold capped by the unlocked
-- circles, the height scaled by the level's power.
function Burst.heightForHold(seconds: number, level: number): number
	local capped = Progression.capHold("Burst", seconds, level)
	return MathUtil.holdCurve(Tuning.Burst.HoldHeights, capped) * Progression.power(level)
end

-- Launch velocity that reaches `height`: solves v·Ignition + v²/2g = height.
local function velocityFor(height: number): number
	local ignition = Tuning.Burst.IgnitionTime
	local g = gravity()
	return g * (-ignition + math.sqrt(ignition * ignition + 2 * height / g))
end

function Burst.enter(ctx: Types.Ctx, payload: any)
	local B = Tuning.Burst
	local held = if payload ~= nil and payload.Held then payload.Held else 0
	local height = Burst.heightForHold(held, ctx.Level)
	local velocity = velocityFor(height)
	ctx.BurstHeld = held
	ctx.BurstCharge = math.clamp(height / B.FeelFullHeight, B.MinFeelCharge, 1)
	ctx.BurstAscentTime = Burst.predict(velocity)
	ctx.Velocity = ctx.Up * velocity
	ctx.FallPeak = ctx.Altitude + height
	ctx.BodyDirection = ctx.Up
	ctx.Bank = 0
end

function Burst.update(ctx: Types.Ctx, dt: number): (Types.MovementState?, any)
	local B = Tuning.Burst
	local up = ctx.Up
	local g = if ctx.StateTime < B.IgnitionTime then Tuning.Gravity.BurstIgnition else Tuning.Gravity.Burst
	local vy = ctx.Velocity:Dot(up) - g * dt
	if vy <= B.HangEntryVerticalSpeed then
		return "Hang", nil
	end

	local level = MathUtil.flat(ctx.Velocity, up)
	if ctx.StateTime >= B.NoSteerTime then
		local wish = MathUtil.cameraMove(ctx.Input.Move, up) * B.DriftSpeed
		level = MathUtil.moveTowardVector(level, wish, B.DriftAccel * dt)
	end
	ctx.Velocity = level + up * vy
	ctx.Heading = MathUtil.tangent(ctx.LookDirection, up, ctx.Heading)
	ctx.BodyDirection = up
	return nil
end

return Burst
