--!strict
-- Burst (spec §3, §4.2–4.3): straight up at a velocity set by Power and how long the charge was held. No gravity for the ignition, then Burst
-- gravity. No steering at first, then a slow drift. Hands over to Hang once the climb has nearly stopped.

local Shared = game:GetService("ReplicatedStorage").Shared
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)
local MathUtil = require(script.Parent.Parent.MathUtil)

local Burst = { Air = true }

-- `charge` is the share of a full Burst (0–1). Velocity follows charge ^ ChargeCurve; at 0.5 the height grows
-- roughly in step with the charge.
function Burst.velocity(power: number, charge: number): number
	local B = Tuning.Burst
	local full = math.min(B.BaseVelocity + B.VelocityPerPower * (power - 1), B.MaxVelocity)
	return full * math.clamp(charge, 0, 1) ^ B.ChargeCurve
end

-- Seconds from ignition to apex and the altitude gained, for effects that scale with the ascent.
function Burst.predict(power: number, charge: number): (number, number)
	local B = Tuning.Burst
	local v = Burst.velocity(power, charge)
	local g = math.max(Tuning.Gravity.Burst, 1e-3)
	return B.IgnitionTime + v / g, v * B.IgnitionTime + v * v / (2 * g)
end

function Burst.enter(ctx: Types.Ctx, payload: any)
	ctx.BurstCharge = if payload ~= nil and payload.Charge then payload.Charge else 1
	local _, gain = Burst.predict(ctx.Power, ctx.BurstCharge)
	ctx.Velocity = Vector3.yAxis * Burst.velocity(ctx.Power, ctx.BurstCharge)
	ctx.FallPeak = ctx.Altitude + gain
	ctx.BodyDirection = Vector3.yAxis
	ctx.Bank = 0
end

function Burst.update(ctx: Types.Ctx, dt: number): (Types.MovementState?, any)
	local B = Tuning.Burst
	local gravity = if ctx.StateTime < B.IgnitionTime then Tuning.Gravity.BurstIgnition else Tuning.Gravity.Burst
	local vy = ctx.Velocity.Y - gravity * dt
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
