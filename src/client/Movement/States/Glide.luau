--!strict
-- Glide (spec §3, §10): move vector maps to pitch and yaw rate; with no sideways input the glide follows the aim.
-- Pitch trades sink for speed. Glide energy drains; below the strain threshold sink doubles, at zero a forced dive.

local Shared = game:GetService("ReplicatedStorage").Shared
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)
local MathUtil = require(script.Parent.Parent.MathUtil)
local Punch = require(script.Parent.Parent.Punch)

local Glide = { Air = true, Punch = "Air" }

local pitch = 0

function Glide.enter(ctx: Types.Ctx, _payload: any)
	pitch = 0
	ctx.Heading = MathUtil.exitHeading(ctx)
end

function Glide.update(ctx: Types.Ctx, dt: number): (Types.MovementState?, any)
	local T = Tuning.Glide
	local E = Tuning.GlideEnergy

	ctx.GlideEnergy -= E.DrainPerSecond * dt
	if ctx.GlideEnergy <= 0 then
		ctx.GlideEnergy = 0
		return "Dive", { Forced = true }
	end
	if ctx.Input.JumpPressed then
		return "Dive", nil
	end

	local vy = ctx.Velocity.Y

	local moveZ = ctx.Input.Move.Z
	local pitchTarget = if moveZ < 0 then T.PitchMin * -moveZ else T.PitchMax * moveZ
	pitch = MathUtil.approach(pitch, pitchTarget, T.PitchResponse, dt)

	local steer = MathUtil.steerInput(ctx)
	ctx.Heading = MathUtil.yawRight(ctx.Heading, T.YawRate * steer * dt)
	ctx.Bank = MathUtil.approach(ctx.Bank, T.BankMax * steer, T.BankResponse, dt)

	local pitchUp = math.max(pitch, 0) / T.PitchMax
	local targetSpeed = T.ForwardSpeed
		* (1 + (T.PitchUpSpeedFactor - 1) * pitchUp)
		* Punch.slow(ctx, Tuning.Punch.ChargeGlideMult)
	local speed = math.max(0, MathUtil.flat(ctx.Velocity):Dot(ctx.Heading))
	-- Speed only grows on its own: below the target it accelerates, above it it is kept unless the player
	-- pitches up to brake.
	if speed < targetSpeed then
		speed = MathUtil.moveToward(speed, targetSpeed, T.Accel * dt)
	elseif pitchUp > 0 then
		speed = MathUtil.moveToward(speed, targetSpeed, T.Decel * pitchUp * dt)
	end

	local noseDown = (T.PitchMax - pitch) / (T.PitchMax - T.PitchMin)
	local sink = T.SinkMin + (T.SinkMax - T.SinkMin) * noseDown
	if ctx.GlideEnergy < E.StrainThreshold then
		sink *= E.StrainSinkMultiplier
	end
	vy -= Tuning.Gravity.Glide * dt
	if vy < -sink then
		-- Levelling out of a fast fall turns the fall speed you arrived with into forward speed instead of
		-- losing it (gravity's steady pull in a settled glide doesn't count, or the glide would speed up forever).
		local levelled = MathUtil.moveToward(vy, -sink, T.SinkRecovery * dt)
		local arrived = math.max(0, -sink - ctx.Velocity.Y)
		speed += math.min(levelled - vy, arrived) * T.FallToForward
		vy = levelled
	end

	ctx.Velocity = ctx.Heading * speed + Vector3.yAxis * vy
	local bodyPitch = math.rad(pitch * T.BodyPitchFraction)
	ctx.BodyDirection = ctx.Heading * math.cos(bodyPitch) + Vector3.yAxis * math.sin(bodyPitch)
	return nil
end

return Glide
