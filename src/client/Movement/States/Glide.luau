--!strict
-- Glide (spec §3, §10): move vector maps to pitch and yaw rate; with no sideways input the glide follows the aim.
-- Pitch trades sink for speed. Glide energy drains; below the strain threshold sink doubles, at zero a forced dive.

local Shared = game:GetService("ReplicatedStorage").Shared
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)
local MathUtil = require(script.Parent.Parent.MathUtil)
local Punch = require(script.Parent.Parent.Punch)
local Blast = require(script.Parent.Parent.Blast)

local Glide = { Punch = "Air" }

local pitch = 0

function Glide.enter(ctx: Types.Ctx, _payload: any)
	pitch = 0
	ctx.Heading = MathUtil.exitHeading(ctx)
end

function Glide.update(ctx: Types.Ctx, dt: number): (Types.MovementState?, any)
	local T = Tuning.Glide
	local E = Tuning.GlideEnergy
	local up = ctx.Up

	ctx.GlideEnergy -= E.DrainPerSecond * dt
	if ctx.GlideEnergy <= 0 then
		ctx.GlideEnergy = 0
		return "Dive", { Forced = true }
	end
	if ctx.Input.JumpPressed then
		return "Dive", nil
	end

	local vy = ctx.Velocity:Dot(up)

	local moveZ = ctx.Input.Move.Z
	local pitchTarget = if moveZ < 0 then T.PitchMin * -moveZ else T.PitchMax * moveZ
	pitch = MathUtil.approach(pitch, pitchTarget, T.PitchResponse, dt)

	local steer = MathUtil.steerInput(ctx)
	ctx.Heading = MathUtil.yawRight(ctx.Heading, T.YawRate * steer * dt, up)
	ctx.Bank = MathUtil.approach(ctx.Bank, T.BankMax * steer, T.BankResponse, dt)

	local pitchUp = math.max(pitch, 0) / T.PitchMax
	local targetSpeed = T.ForwardSpeed
		* (1 + (T.PitchUpSpeedFactor - 1) * pitchUp)
		* Punch.slow(ctx, Tuning.Punch.ChargeGlideMult)
		* Blast.slow(ctx, Tuning.Blast.ChargeGlideMult)
	local speed = math.max(0, MathUtil.flat(ctx.Velocity, up):Dot(ctx.Heading))
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
	-- The glide only levels out when asked (review note): pitching up, or looking above the horizon. Otherwise
	-- gravity keeps building the fall and a dive only builds it faster.
	local levelling = pitch > 0 or ctx.LookDirection:Dot(up) > T.LevelLookUp
	if levelling and vy < -sink then
		-- Levelling out of a fast fall turns the fall speed you arrived with into forward speed instead of
		-- losing it (gravity's steady pull in a settled glide doesn't count, or the glide would speed up forever).
		local levelled = MathUtil.moveToward(vy, -sink, T.SinkRecovery * dt)
		local arrived = math.max(0, -sink - ctx.Velocity:Dot(up))
		speed += math.min(levelled - vy, arrived) * T.FallToForward
		vy = levelled
	end

	ctx.Velocity = ctx.Heading * speed + up * vy
	ctx.BodyDirection = MathUtil.pathDirection(ctx.Heading, pitch * T.BodyPitchFraction, up)
	return nil
end

return Glide
