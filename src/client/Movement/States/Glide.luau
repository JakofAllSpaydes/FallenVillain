--!strict
-- Glide (spec §3, §10): move vector maps to pitch and yaw rate; with no sideways input the glide follows the aim.
-- Pitch trades sink for speed. Glide energy drains; below the strain threshold sink doubles, at zero a forced dive.

local Shared = game:GetService("ReplicatedStorage").Shared
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)
local MathUtil = require(script.Parent.Parent.MathUtil)

local Glide = { Air = true }

local pitch = 0

function Glide.enter(ctx: Types.Ctx, payload: any)
	pitch = 0
	ctx.Heading = MathUtil.exitHeading(ctx)
	if payload ~= nil and payload.TapBoost then
		-- Dive-tap boost: a quick dive tap trades a little height and energy for forward speed.
		local T = Tuning.Tech
		local forward = math.max(0, MathUtil.flat(ctx.Velocity):Dot(ctx.Heading))
		forward = math.min(forward + T.TapBoost, math.max(forward, T.MaxCarrySpeed))
		ctx.Velocity = ctx.Heading * forward + Vector3.yAxis * ctx.Velocity.Y
		ctx.GlideEnergy = math.max(0, ctx.GlideEnergy - T.TapEnergyCost)
	end
end

function Glide.update(ctx: Types.Ctx, dt: number): (Types.MovementState?, any)
	local T = Tuning.Glide
	local E = Tuning.GlideEnergy

	ctx.GlideEnergy -= E.DrainPerSecond * dt
	if ctx.GlideEnergy <= 0 then
		ctx.GlideEnergy = 0
		return "Dive", { Forced = true }
	end
	if ctx.Input.PrimaryHeld then
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
	local targetSpeed = T.ForwardSpeed * (1 + (T.PitchUpSpeedFactor - 1) * pitchUp)
	local speed = math.max(0, MathUtil.flat(ctx.Velocity):Dot(ctx.Heading))
	-- Speed above ForwardSpeed (from boosts, swoops and chains) bleeds slowly unless the player pitches up to brake.
	local rate = if speed < targetSpeed
		then T.Accel
		elseif speed > T.ForwardSpeed then T.OverspeedBleed + (T.Decel - T.OverspeedBleed) * pitchUp
		else T.Decel
	speed = MathUtil.moveToward(speed, targetSpeed, rate * dt)

	local noseDown = (T.PitchMax - pitch) / (T.PitchMax - T.PitchMin)
	local sink = T.SinkMin + (T.SinkMax - T.SinkMin) * noseDown
	if ctx.GlideEnergy < E.StrainThreshold then
		sink *= E.StrainSinkMultiplier
	end
	vy -= Tuning.Gravity.Glide * dt
	if vy < -sink then
		vy = MathUtil.moveToward(vy, -sink, T.SinkRecovery * dt)
	end

	ctx.Velocity = ctx.Heading * speed + Vector3.yAxis * vy
	local bodyPitch = math.rad(pitch * T.BodyPitchFraction)
	ctx.BodyDirection = ctx.Heading * math.cos(bodyPitch) + Vector3.yAxis * math.sin(bodyPitch)
	return nil
end

return Glide
