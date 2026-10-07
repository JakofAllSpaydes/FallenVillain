--!strict
-- Aimed dive (spec §3): snap toward the aim point with all your speed, thrust plus ramping gravity with no
-- terminal speed, steer within a cone that widens the longer Space is held. Release converts to Swoop above
-- the entry speed, else Glide.

local Shared = game:GetService("ReplicatedStorage").Shared
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)
local MathUtil = require(script.Parent.Parent.MathUtil)

local Dive = { Punch = "Air" }

local forced = false
local straightDown = false
local holdTime = 0
local speed = 0
local direction = -Vector3.yAxis
local entryDirection = -Vector3.yAxis
local lastUp = Vector3.yAxis

local function aimDirection(ctx: Types.Ctx): Vector3
	if straightDown then
		return -ctx.Up
	end
	local toAim = ctx.AimPoint - ctx.Root.Position
	if toAim.Magnitude < 1e-3 then
		return direction
	end
	return MathUtil.clampPitch(toAim.Unit, Tuning.Dive.MaxPitch, ctx.Heading, ctx.Up)
end

local function ramp(from: number, to: number, time: number): number
	return from + (to - from) * math.clamp(holdTime / time, 0, 1)
end

function Dive.enter(ctx: Types.Ctx, payload: any)
	forced = payload ~= nil and payload.Forced == true
	straightDown = payload ~= nil and payload.StraightDown == true
	holdTime = 0
	direction = aimDirection(ctx)
	entryDirection = direction
	-- All the momentum you had turns into the dive, whichever way you were going.
	speed = ctx.Velocity.Magnitude
	ctx.Velocity = direction * speed
	ctx.BodyDirection = direction
	ctx.Bank = 0
	lastUp = ctx.Up
end

function Dive.update(ctx: Types.Ctx, dt: number): (Types.MovementState?, any)
	local T = Tuning.Dive
	-- A tap still dives for MinHoldTime so it always does something.
	if not forced and not ctx.Input.JumpHeld and holdTime >= T.MinHoldTime then
		local S = Tuning.Swoop
		if speed >= S.MinEntrySpeed and ctx.Now >= ctx.SwoopReadyAt and ctx.GlideEnergy >= S.EnergyCost then
			return "Swoop", nil
		end
		return "Glide", nil
	end

	-- Roll the dive with the planet (the controller already rolled the velocity), so it follows the curve.
	local roll = MathUtil.transport(lastUp, ctx.Up)
	direction = (roll * direction).Unit
	entryDirection = (roll * entryDirection).Unit
	lastUp = ctx.Up
	holdTime += dt
	local cone = math.rad(ramp(T.ConeStart, T.ConeEnd, T.ConeWidenTime))
	local target = MathUtil.rotateTowards(entryDirection, aimDirection(ctx), cone)
	direction = MathUtil.rotateTowards(direction, target, math.rad(T.SteerRate) * dt)

	-- Read back so walls and collisions take speed away and a punch dash adds it.
	speed = math.max(0, ctx.Velocity:Dot(direction))
	local gravity = ramp(Tuning.Gravity.DiveStart, Tuning.Gravity.DiveEnd, Tuning.Gravity.DiveRampTime)
	speed += (T.Thrust - gravity * direction:Dot(ctx.Up)) * dt
	-- No terminal speed: a dive only ever gets faster until it hits something.

	ctx.Heading = MathUtil.tangent(direction, ctx.Up, ctx.Heading)
	ctx.Velocity = direction * speed
	ctx.BodyDirection = direction
	return nil
end

return Dive
