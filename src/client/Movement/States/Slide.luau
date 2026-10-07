--!strict
-- Dive-slide (movement tech): touching down from a Dive (any angle) or a shallow Swoop with speed keeps the
-- level momentum as a ground slide instead of stopping. Friction bleeds it; hopping out keeps it (inside the chain window it counts
-- as a perfect hop); holding Space charges a Burst. Friction is high, so it is a short burst.
-- Slides off a ledge into Glide; settles into Landing when slow.

local Shared = game:GetService("ReplicatedStorage").Shared
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)
local GroundHold = require(script.Parent.Parent.GroundHold)
local JumpCheck = require(script.Parent.Parent.JumpCheck)
local MathUtil = require(script.Parent.Parent.MathUtil)

local Slide = { OnGround = true, Punch = "Ground" }

local speed = 0

function Slide.enter(ctx: Types.Ctx, _payload: any)
	local T = Tuning.Tech
	local landed = ctx.LandVelocity
	if landed.Magnitude > 1e-3 then
		ctx.Heading = landed.Unit
	end
	speed = math.min(landed.Magnitude * T.SlideKeep, math.max(T.MaxCarrySpeed, Tuning.Glide.ForwardSpeed))
	ctx.Velocity = ctx.Heading * speed
	ctx.Bank = 0
end

function Slide.update(ctx: Types.Ctx, dt: number): (Types.MovementState?, any)
	local T = Tuning.Tech
	local up = ctx.Up
	local jump, jumpPayload = JumpCheck.update(ctx)
	if jump then
		return jump, jumpPayload
	end

	local ground = GroundHold.floor(ctx)
	if not ground then
		return "Glide", nil
	end

	local steer = MathUtil.steerInput(ctx)
	ctx.Heading = MathUtil.yawRight(ctx.Heading, T.SlideYawRate * steer * dt, up)

	speed = math.min(speed, math.max(0, MathUtil.flat(ctx.Velocity, up):Dot(ctx.Heading)))
	speed = MathUtil.moveToward(speed, 0, T.SlideFriction * dt)
	if speed < T.SlideExitSpeed then
		ctx.LandVelocity = ctx.Heading * speed
		return "Landing", nil
	end

	-- Hold the root at standing height over the ground so the slide follows it.
	local lift = (ground.Position - ctx.Root.Position):Dot(up) + ctx.StandHeight
	local vy = if dt > 0 then lift / dt else 0
	ctx.Velocity = ctx.Heading * speed + up * vy

	local lean = math.rad(T.SlideLean)
	ctx.BodyDirection = up * math.cos(lean) - ctx.Heading * math.sin(lean)
	return nil
end

return Slide
