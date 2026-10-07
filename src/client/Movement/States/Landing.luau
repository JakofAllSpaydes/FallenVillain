--!strict
-- Landing (spec §3, §4.8): a short stillness after touching down from the air. Space runs the same tap-or-hold
-- check as Grounded: a tap hops (a chain hop if pressed inside the window), a hold starts Charging.
-- Milestone 3 routes landings from Dive to Impact instead.

local Shared = game:GetService("ReplicatedStorage").Shared
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)
local JumpCheck = require(script.Parent.Parent.JumpCheck)

local Landing = { Air = false, Punch = "Ground" }

function Landing.enter(ctx: Types.Ctx, _payload: any)
	ctx.Humanoid.WalkSpeed = 0
end

function Landing.update(ctx: Types.Ctx, _dt: number): (Types.MovementState?, any)
	local jump, payload = JumpCheck.update(ctx)
	if jump then
		return jump, payload
	end
	if ctx.StateTime >= Tuning.Impact.LandingTime then
		return "Grounded", nil
	end
	return nil
end

return Landing
