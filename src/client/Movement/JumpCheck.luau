--!strict
-- Space on the ground, shared by every ground state (Grounded, Landing, Slide) so a hold carries across them.
-- Released before Hop.HoldTime it hops, higher the longer it was held past Hop.TapTime; momentum is untouched
-- while you hold. Held to Hop.HoldTime it starts Charging a Burst, which bleeds momentum off.
-- The hop keeps the press time, so a chain hop is judged by when you pressed.

local Shared = game:GetService("ReplicatedStorage").Shared
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)

local JumpCheck = {}

local pressedAt: number? = nil

function JumpCheck.reset()
	pressedAt = nil
end

function JumpCheck.update(ctx: Types.Ctx): (Types.MovementState?, any)
	local T = Tuning.Hop
	if ctx.Input.JumpPressed then
		pressedAt = ctx.Now
	end
	local started = pressedAt
	if started == nil then
		return nil
	end
	local held = ctx.Now - started
	if not ctx.Input.JumpHeld then
		pressedAt = nil
		local charge = math.clamp((held - T.TapTime) / math.max(T.HoldTime - T.TapTime, 1e-3), 0, 1)
		return "Hop", { PressedAt = started, Charge = charge }
	end
	if held >= T.HoldTime then
		pressedAt = nil
		return "Charging", { Held = held }
	end
	return nil
end

return JumpCheck
