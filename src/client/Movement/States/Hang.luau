--!strict
-- Hang (spec §3, §4.4): the apex. Near-zero gravity and a slow drift for Hang.Time, then the wings fold into
-- Glide. Space dives straight out of it. Hang refills glide energy and starts the fall's air-gain ceiling.

local Shared = game:GetService("ReplicatedStorage").Shared
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)
local MathUtil = require(script.Parent.Parent.MathUtil)

local Hang = { Air = true, Punch = "Air" }

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
	if ctx.StateTime >= H.Time then
		return "Glide", nil
	end

	local vy = ctx.Velocity.Y - Tuning.Gravity.Hang * dt
	local wish = MathUtil.cameraMove(ctx.Input.Move) * H.DriftSpeed
	local horizontal = MathUtil.moveTowardVector(MathUtil.flat(ctx.Velocity), wish, H.DriftAccel * dt)
	ctx.Velocity = horizontal + Vector3.yAxis * vy
	ctx.FallPeak = math.max(ctx.FallPeak, ctx.Altitude)

	local look = MathUtil.flat(ctx.LookDirection)
	if look.Magnitude > 1e-3 then
		ctx.Heading = look.Unit
	end
	return nil
end

return Hang
