--!strict
-- Hang (spec §3, §4.4): the apex. Near-zero gravity and a slow drift for Hang.Time (shorter after small Bursts),
-- then the wings fold into Glide. Space dives straight out of it. Hang refills glide energy and starts the
-- fall's air-gain ceiling.

local Shared = game:GetService("ReplicatedStorage").Shared
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)
local MathUtil = require(script.Parent.Parent.MathUtil)

local Hang = { Punch = "Air" }

function Hang.enter(ctx: Types.Ctx, _payload: any)
	ctx.GlideEnergy = Tuning.GlideEnergy.Max
	ctx.FallPeak = ctx.Altitude
	ctx.BodyDirection = nil
	ctx.Bank = 0
end

function Hang.update(ctx: Types.Ctx, dt: number): (Types.MovementState?, any)
	local H = Tuning.Hang
	if ctx.Input.JumpPressed then
		return "Dive", nil
	end
	if ctx.StateTime >= math.max(H.MinTime, H.Time * ctx.BurstCharge) then
		return "Glide", nil
	end

	local up = ctx.Up
	local vy = ctx.Velocity:Dot(up) - Tuning.Gravity.Hang * dt
	local wish = MathUtil.cameraMove(ctx.Input.Move, up) * H.DriftSpeed
	local level = MathUtil.moveTowardVector(MathUtil.flat(ctx.Velocity, up), wish, H.DriftAccel * dt)
	ctx.Velocity = level + up * vy
	ctx.FallPeak = math.max(ctx.FallPeak, ctx.Altitude)
	ctx.Heading = MathUtil.tangent(ctx.LookDirection, up, ctx.Heading)
	return nil
end

return Hang
