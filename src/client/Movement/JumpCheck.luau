--!strict
-- Space on the ground is a tap-or-hold check, shared by every ground state (Grounded, Landing, Slide) so a hold
-- carries across them: released within Hop.TapTime it hops; held longer it always breaks your momentum and
-- starts Charging a Burst. The hop keeps the press time, so a chain hop is judged by when you pressed.

local Shared = game:GetService("ReplicatedStorage").Shared
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)

local JumpCheck = {}

local pressedAt: number? = nil

function JumpCheck.reset()
	pressedAt = nil
end

function JumpCheck.update(ctx: Types.Ctx): (Types.MovementState?, any)
	if ctx.Input.JumpPressed then
		pressedAt = ctx.Now
	end
	local started = pressedAt
	if started == nil then
		return nil
	end
	if not ctx.Input.JumpHeld then
		pressedAt = nil
		return "Hop", { PressedAt = started }
	end
	if ctx.Now - started >= Tuning.Hop.TapTime then
		pressedAt = nil
		return "Charging", { Held = ctx.Now - started }
	end
	return nil
end

return JumpCheck
