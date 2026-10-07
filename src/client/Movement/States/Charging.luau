--!strict
-- Charging (spec §3, §4.1): Space held on the ground. Always available, and it stops you dead, so it breaks any
-- movement chain. The Burst's strength grows with the hold: Burst.MinCharge at CancelThreshold, full at
-- Burst.ChargeTime (both counted from the press). Releasing before CancelThreshold cancels.

local Shared = game:GetService("ReplicatedStorage").Shared
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)

local Charging = { Air = false }

local held = 0

function Charging.enter(ctx: Types.Ctx, payload: any)
	held = if payload ~= nil and payload.Held then payload.Held else 0
	ctx.Humanoid.WalkSpeed = 0
	ctx.Velocity = Vector3.zero
	ctx.Root.AssemblyLinearVelocity = Vector3.zero
end

-- Share of a full Burst for a hold of `seconds` from the press.
function Charging.fraction(seconds: number): number
	local B = Tuning.Burst
	local span = math.max(B.ChargeTime - Tuning.Charging.CancelThreshold, 1e-3)
	local t = math.clamp((seconds - Tuning.Charging.CancelThreshold) / span, 0, 1)
	return B.MinCharge + (1 - B.MinCharge) * t
end

function Charging.update(ctx: Types.Ctx, dt: number): (Types.MovementState?, any)
	held += dt
	if ctx.Input.JumpHeld then
		return nil
	end
	if held < Tuning.Charging.CancelThreshold then
		return "Grounded", { Cancelled = true }
	end
	return "Burst", { Charge = Charging.fraction(held) }
end

return Charging
