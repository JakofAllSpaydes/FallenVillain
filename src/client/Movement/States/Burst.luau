--!strict
-- Burst (spec §3, §4.2–4.3): straight up. The Space hold picks a target height from Burst.HoldHeights, capped by
-- the highest Burst Power allows; the launch velocity is solved to reach it. No gravity for the ignition, then
-- Burst gravity. No steering at first, then a slow drift. Hands over to Hang once the climb has nearly stopped.

local Shared = game:GetService("ReplicatedStorage").Shared
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)
local MathUtil = require(script.Parent.Parent.MathUtil)

local Burst = { Air = true, Punch = "Air" }

local function gravity(): number
	return math.max(Tuning.Gravity.Burst, 1e-3)
end

-- Seconds to apex and height gained for a launch velocity.
function Burst.predict(velocity: number): (number, number)
	local B = Tuning.Burst
	local g = gravity()
	return B.IgnitionTime + velocity / g, velocity * B.IgnitionTime + velocity * velocity / (2 * g)
end

-- Highest Burst for a Power level.
function Burst.ceiling(power: number): number
	local B = Tuning.Burst
	local full = math.min(B.BaseVelocity + B.VelocityPerPower * (power - 1), B.MaxVelocity)
	local _, height = Burst.predict(full)
	return height
end

-- Target height for a hold of `seconds` (Burst.HoldHeights).
function Burst.heightForHold(seconds: number): number
	return MathUtil.holdCurve(Tuning.Burst.HoldHeights, seconds)
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
	local height = math.min(Burst.heightForHold(held), Burst.ceiling(ctx.Power))
	local velocity = velocityFor(height)
	ctx.BurstHeld = held
	ctx.BurstCharge = math.clamp(height / B.FeelFullHeight, B.MinFeelCharge, 1)
	ctx.BurstAscentTime = Burst.predict(velocity)
	ctx.Velocity = Vector3.yAxis * velocity
	ctx.FallPeak = ctx.Altitude + height
	ctx.BodyDirection = Vector3.yAxis
	ctx.Bank = 0
end

function Burst.update(ctx: Types.Ctx, dt: number): (Types.MovementState?, any)
	local B = Tuning.Burst
	local g = if ctx.StateTime < B.IgnitionTime then Tuning.Gravity.BurstIgnition else Tuning.Gravity.Burst
	local vy = ctx.Velocity.Y - g * dt
	if vy <= B.HangEntryVerticalSpeed then
		return "Hang", nil
	end

	local horizontal = MathUtil.flat(ctx.Velocity)
	if ctx.StateTime >= B.NoSteerTime then
		local wish = MathUtil.cameraMove(ctx.Input.Move) * B.DriftSpeed
		horizontal = MathUtil.moveTowardVector(horizontal, wish, B.DriftAccel * dt)
	end
	ctx.Velocity = horizontal + Vector3.yAxis * vy
	local look = MathUtil.flat(ctx.LookDirection)
	if look.Magnitude > 1e-3 then
		ctx.Heading = look.Unit
	end
	return nil
end

return Burst
