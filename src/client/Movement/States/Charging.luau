--!strict
-- Charging (spec §3, §4.1): Space held on the ground past Hop.HoldTime. Your momentum bleeds off hard
-- (Charging.Damping) rather than freezing, so it still breaks a movement chain without a jarring stop.
-- Releasing always Bursts; the hold (counted from the press) sets the height (Burst.HoldHeights).
-- Releasing a punch here cancels the charge into the punch.

local Shared = game:GetService("ReplicatedStorage").Shared
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)
local GroundHold = require(script.Parent.Parent.GroundHold)

local Charging = { Air = true, SkipTouchdown = true, Punch = "Ground" }

local held = 0

function Charging.enter(ctx: Types.Ctx, payload: any)
	held = if payload ~= nil and payload.Held then payload.Held else 0
	ctx.BodyDirection = nil
	ctx.Bank = 0
end

function Charging.update(ctx: Types.Ctx, dt: number): (Types.MovementState?, any)
	held += dt
	if not GroundHold.step(ctx, dt, Tuning.Charging.Damping, 0) then
		return "Glide", nil
	end
	if ctx.Input.JumpHeld then
		return nil
	end
	return "Burst", { Held = held }
end

return Charging
