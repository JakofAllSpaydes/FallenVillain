--!strict
-- Grounded: the Humanoid walks; the controller watches Space (JumpCheck) and walking off ledges.

local Shared = game:GetService("ReplicatedStorage").Shared
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)
local JumpCheck = require(script.Parent.Parent.JumpCheck)
local MathUtil = require(script.Parent.Parent.MathUtil)
local Punch = require(script.Parent.Parent.Punch)

local Grounded = { Air = false, OnGround = true, Punch = "Ground" }

local airborneTime = 0

function Grounded.enter(_ctx: Types.Ctx, _payload: any)
	airborneTime = 0
end

function Grounded.update(ctx: Types.Ctx, dt: number): (Types.MovementState?, any)
	ctx.Humanoid.WalkSpeed = Tuning.Walk.Speed * Punch.slow(ctx, Tuning.Punch.ChargeWalkMult)
	local look = MathUtil.flat(ctx.Root.CFrame.LookVector)
	if look.Magnitude > 1e-3 then
		ctx.Heading = look.Unit
	end

	local jump, payload = JumpCheck.update(ctx)
	if jump then
		return jump, payload
	end

	if ctx.Humanoid.FloorMaterial == Enum.Material.Air then
		airborneTime += dt
		if airborneTime >= Tuning.Physics.AirborneGraceTime then
			local probe = -Vector3.yAxis * (ctx.StandHeight + Tuning.Physics.GroundRayLength)
			if not workspace:Raycast(ctx.Root.Position, probe, ctx.RaycastParams) then
				return "Glide", nil
			end
		end
	else
		airborneTime = 0
	end
	return nil
end

return Grounded
