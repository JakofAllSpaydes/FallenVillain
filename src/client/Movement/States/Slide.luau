--!strict
-- Dive-slide (movement tech): touching down from Dive or Swoop at a shallow angle and speed keeps the momentum
-- as a ground slide instead of stopping. Friction bleeds it; hopping out keeps it (inside the chain window
-- it counts as a perfect hop); holding Space stops the slide and charges a Burst. Slides off a ledge into Glide; settles into Grounded when slow.

local Shared = game:GetService("ReplicatedStorage").Shared
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)
local JumpCheck = require(script.Parent.Parent.JumpCheck)
local MathUtil = require(script.Parent.Parent.MathUtil)

local Slide = { Air = true, SkipTouchdown = true, Punch = "Ground" }

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
	local jump, jumpPayload = JumpCheck.update(ctx)
	if jump then
		return jump, jumpPayload
	end

	local probe = -Vector3.yAxis * (ctx.StandHeight + T.SlideGroundProbe)
	local ground = workspace:Raycast(ctx.Root.Position, probe, ctx.RaycastParams)
	if not ground then
		JumpCheck.reset()
		return "Glide", nil
	end

	local steer = MathUtil.steerInput(ctx)
	ctx.Heading = MathUtil.yawRight(ctx.Heading, T.SlideYawRate * steer * dt)

	speed = math.min(speed, math.max(0, MathUtil.flat(ctx.Velocity):Dot(ctx.Heading)))
	speed = MathUtil.moveToward(speed, 0, T.SlideFriction * dt)
	if speed < T.SlideExitSpeed then
		return "Grounded", nil
	end

	-- Hold the root at standing height over the ground so the slide follows it.
	local targetY = ground.Position.Y + ctx.StandHeight
	local vy = (targetY - ctx.Root.Position.Y) / dt
	ctx.Velocity = ctx.Heading * speed + Vector3.yAxis * vy

	local lean = math.rad(T.SlideLean)
	ctx.BodyDirection = Vector3.yAxis * math.cos(lean) - ctx.Heading * math.sin(lean)
	return nil
end

return Slide
