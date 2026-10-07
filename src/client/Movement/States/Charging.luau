--!strict
-- Charging (spec §3, §4.1): Space held on the ground past Hop.HoldTime. Your momentum bleeds off hard
-- (Charging.Damping) rather than freezing, so it still breaks a movement chain without a jarring stop.
-- Releasing always Bursts; the hold (JumpCheck.held) sets the height (Burst.HoldHeights). A punch here fires
-- the punch and keeps the Space hold (JumpCheck), so landing still holding resumes the charge.

local Shared = game:GetService("ReplicatedStorage").Shared
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)
local GroundHold = require(script.Parent.Parent.GroundHold)
local JumpCheck = require(script.Parent.Parent.JumpCheck)

local Charging = { OnGround = true, NoBounce = true, Punch = "Ground" }

function Charging.enter(ctx: Types.Ctx, _payload: any)
	ctx.BodyDirection = nil
	ctx.Bank = 0
end

function Charging.update(ctx: Types.Ctx, dt: number): (Types.MovementState?, any)
	if not GroundHold.step(ctx, dt, Tuning.Charging.Damping, 0) then
		return "Glide", nil
	end
	if ctx.Input.JumpHeld then
		return nil
	end
	local held = JumpCheck.held() or Tuning.Hop.HoldTime
	JumpCheck.clear()
	return "Burst", { Held = held }
end

return Charging
