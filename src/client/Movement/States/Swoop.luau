--!strict
-- Swoop (spec §3, §4.7): releasing a fast dive pulls up in an arc. The velocity keeps its speed and rotates
-- upward at PullUpRate until the climb reaches the lift target (LiftFraction of speed, capped at MaxLift);
-- after that gravity takes over until the player settles into Glide. Speed is only traded for height, never bled.
-- Re-pressing dive re-aims.

local Shared = game:GetService("ReplicatedStorage").Shared
local Globe = require(Shared.Globe)
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)
local MathUtil = require(script.Parent.Parent.MathUtil)

local Swoop = { Punch = "Air" }

local pullingUp = false
local pitch = 0 -- degrees, current flight-path angle while pulling up
local targetPitch = 0
local speed = 0
local skimming = false

function Swoop.enter(ctx: Types.Ctx, _payload: any)
	local S = Tuning.Swoop
	local up = ctx.Up
	speed = ctx.Velocity.Magnitude
	ctx.Heading = MathUtil.exitHeading(ctx)
	pitch = MathUtil.pitchOf(ctx.Velocity, up)
	targetPitch = math.deg(math.asin(math.min(speed * S.LiftFraction, S.MaxLift) / speed))
	pullingUp = true
	skimming = false

	ctx.Velocity = MathUtil.pathDirection(ctx.Heading, pitch, up) * speed
	ctx.SwoopReadyAt = ctx.Now + S.Cooldown
	ctx.GlideEnergy -= S.EnergyCost
end

function Swoop.update(ctx: Types.Ctx, dt: number): (Types.MovementState?, any)
	local S = Tuning.Swoop
	local up = ctx.Up
	if ctx.Input.JumpPressed then
		return "Dive", nil
	end

	ctx.GlideEnergy -= Tuning.GlideEnergy.DrainPerSecond * dt
	if ctx.GlideEnergy <= 0 then
		ctx.GlideEnergy = 0
		return "Dive", { Forced = true }
	end

	local steer = MathUtil.steerInput(ctx)
	ctx.Heading = MathUtil.yawRight(ctx.Heading, S.YawRate * steer * dt, up)
	ctx.Bank = MathUtil.approach(ctx.Bank, Tuning.Glide.BankMax * steer, Tuning.Glide.BankResponse, dt)

	if pullingUp then
		-- Read back so the ground or a wall takes speed away.
		speed = math.min(speed, math.max(0, ctx.Velocity:Dot(MathUtil.pathDirection(ctx.Heading, pitch, up))))
		-- Swoop skim: an arc that bottoms out close to the ground levels off low and gets a burst of speed.
		local T = Tuning.Tech
		if not skimming and Globe.raycast(ctx.Root.Position, -up * T.SkimHeight, ctx.RaycastParams) then
			skimming = true
			speed = math.min(speed * (1 + T.SkimBoost), math.max(speed, T.MaxSkimSpeed))
			targetPitch = math.min(targetPitch, T.SkimPitch)
		end
		pitch = MathUtil.moveToward(pitch, targetPitch, S.PullUpRate * dt)
		speed -= Tuning.Gravity.Swoop * math.sin(math.rad(pitch)) * dt
		ctx.Velocity = MathUtil.pathDirection(ctx.Heading, pitch, up) * speed
		pullingUp = pitch < targetPitch
	else
		local forward = math.max(0, MathUtil.flat(ctx.Velocity, up):Dot(ctx.Heading))
		local vy = ctx.Velocity:Dot(up) - Tuning.Gravity.Swoop * dt
		ctx.Velocity = ctx.Heading * forward + up * vy
	end

	if ctx.Velocity.Magnitude > 1e-3 then
		ctx.BodyDirection = ctx.Velocity.Unit
	end
	if ctx.Velocity.Magnitude < S.ExitSpeed then
		return "Glide", nil
	end
	return nil
end

return Swoop
