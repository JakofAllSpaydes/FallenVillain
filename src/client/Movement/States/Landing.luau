--!strict
-- Landing (spec §3, §4.8): a short stillness after touching down from the air. Space inside the chain window
-- hops at once (a chain hop); a later press hands over to Grounded's tap-or-hold check, so a Burst can still
-- be charged. Milestone 3 routes landings from Dive to Impact instead.

local Shared = game:GetService("ReplicatedStorage").Shared
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)

local Landing = { Air = false, Punch = "Ground" }

function Landing.enter(ctx: Types.Ctx, _payload: any)
	ctx.Humanoid.WalkSpeed = 0
end

function Landing.update(ctx: Types.Ctx, _dt: number): (Types.MovementState?, any)
	if ctx.Input.JumpPressed then
		if ctx.Now - ctx.LastLandTime <= Tuning.Hop.ChainWindow then
			return "Hop", nil
		end
		return "Grounded", { JumpPending = true }
	end
	if ctx.StateTime >= Tuning.Impact.LandingTime then
		return "Grounded", nil
	end
	return nil
end

return Landing
