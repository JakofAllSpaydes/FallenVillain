--!strict
-- Grounded: controller-driven walking on the globe (the Humanoid's walker only knows world-Y up). Momentum
-- eases toward the move input (Walk.Response) so starts and stops are weighted. The controller watches Space
-- (JumpCheck); walking off a ledge falls like a hop's descent.

local Shared = game:GetService("ReplicatedStorage").Shared
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)
local GroundHold = require(script.Parent.Parent.GroundHold)
local JumpCheck = require(script.Parent.Parent.JumpCheck)
local Punch = require(script.Parent.Parent.Punch)

local Grounded = { OnGround = true, NoBounce = true, Punch = "Ground" }

function Grounded.enter(ctx: Types.Ctx, _payload: any)
	ctx.BodyDirection = nil
	ctx.Bank = 0
end

function Grounded.update(ctx: Types.Ctx, dt: number): (Types.MovementState?, any)
	local jump, payload = JumpCheck.update(ctx)
	if jump then
		return jump, payload
	end
	local walk = Punch.slow(ctx, Tuning.Punch.ChargeWalkMult)
	if not GroundHold.step(ctx, dt, Tuning.Walk.Response, walk) then
		return "Hop", { Launch = true }
	end
	return nil
end

return Grounded
