--!strict
-- Landing (spec §3, §4.8): a short stillness after touching down from the air. Hop cancels it, and a hop
-- inside the chain window counts as a chain hop. Milestone 3 routes landings from Dive to Impact instead.

local Shared = game:GetService("ReplicatedStorage").Shared
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)

local Landing = { Air = false }

function Landing.enter(ctx: Types.Ctx, _payload: any)
	ctx.Humanoid.WalkSpeed = 0
end

function Landing.update(ctx: Types.Ctx, _dt: number): (Types.MovementState?, any)
	if ctx.Input.JumpPressed then
		return "Hop", nil
	end
	if ctx.Input.PrimaryPressed then
		return "Hop", { Smash = true }
	end
	if ctx.StateTime >= Tuning.Impact.LandingTime then
		return "Grounded", nil
	end
	return nil
end

return Landing
