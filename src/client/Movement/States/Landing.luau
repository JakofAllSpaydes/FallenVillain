--!strict
-- Landing (spec §3, §4.8): after touching down from the air, momentum bleeds off quickly (Landing.Damping)
-- toward walking instead of stopping dead, then the Humanoid takes over. Space runs the ground tap-or-hold
-- check, so a hop inside the chain window still chains. Milestone 3 routes landings from Dive to Impact.

local Shared = game:GetService("ReplicatedStorage").Shared
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)
local GroundHold = require(script.Parent.Parent.GroundHold)
local JumpCheck = require(script.Parent.Parent.JumpCheck)
local MathUtil = require(script.Parent.Parent.MathUtil)

local Landing = { Air = true, SkipTouchdown = true, OnGround = true, Punch = "Ground" }

function Landing.enter(ctx: Types.Ctx, _payload: any)
	ctx.Velocity = ctx.LandVelocity
	ctx.BodyDirection = nil
	ctx.Bank = 0
end

function Landing.update(ctx: Types.Ctx, dt: number): (Types.MovementState?, any)
	local L = Tuning.Landing
	local jump, payload = JumpCheck.update(ctx)
	if jump then
		return jump, payload
	end
	if not GroundHold.step(ctx, dt, L.Damping, 1) then
		return "Glide", nil
	end
	local excess = MathUtil.flat(ctx.Velocity).Magnitude - Tuning.Walk.Speed
	if ctx.StateTime >= L.MaxTime or (ctx.StateTime >= L.MinTime and excess <= L.SettleSpeed) then
		return "Grounded", nil
	end
	return nil
end

return Landing
