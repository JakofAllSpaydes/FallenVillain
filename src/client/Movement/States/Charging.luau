--!strict
-- Charging (spec §3, §4.1): Space held on the ground with a full Burst charge. Rooted. Releasing before
-- Charging.CancelThreshold (total hold, counted from the press) cancels; after it, Burst.

local Shared = game:GetService("ReplicatedStorage").Shared
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)

local Charging = { Air = false }

local held = 0

function Charging.enter(ctx: Types.Ctx, payload: any)
	held = if payload ~= nil and payload.Held then payload.Held else 0
	ctx.Humanoid.WalkSpeed = 0
end

function Charging.update(ctx: Types.Ctx, dt: number): (Types.MovementState?, any)
	held += dt
	if ctx.Input.JumpHeld then
		return nil
	end
	if held < Tuning.Charging.CancelThreshold then
		return "Grounded", { Cancelled = true }
	end
	return "Burst", nil
end

return Charging
