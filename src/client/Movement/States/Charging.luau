--!strict
-- Charging (spec §3, §4.1): Space held on the ground. Always available, and it stops you dead, so it breaks any
-- movement chain. Releasing always Bursts; the hold (counted from the press) sets the height (Burst.HoldHeights).
-- Releasing a punch here cancels the charge into the punch.

local Types = require(game:GetService("ReplicatedStorage").Shared.Types)

local Charging = { Air = false, Punch = "Ground" }

local held = 0

function Charging.enter(ctx: Types.Ctx, payload: any)
	held = if payload ~= nil and payload.Held then payload.Held else 0
	ctx.Humanoid.WalkSpeed = 0
	ctx.Velocity = Vector3.zero
	ctx.Root.AssemblyLinearVelocity = Vector3.zero
end

function Charging.update(ctx: Types.Ctx, dt: number): (Types.MovementState?, any)
	held += dt
	if ctx.Input.JumpHeld then
		return nil
	end
	return "Burst", { Held = held }
end

return Charging
