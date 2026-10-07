--!strict
-- Grounded: the Humanoid walks; the controller only watches for hop, ground smash and walking off ledges.

local Shared = game:GetService("ReplicatedStorage").Shared
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)
local MathUtil = require(script.Parent.Parent.MathUtil)

local Grounded = { Air = false }

local airborneTime = 0

function Grounded.enter(ctx: Types.Ctx, _payload: any)
	ctx.Humanoid.WalkSpeed = Tuning.Walk.Speed
	airborneTime = 0
end

function Grounded.update(ctx: Types.Ctx, dt: number): (Types.MovementState?, any)
	local look = MathUtil.flat(ctx.Root.CFrame.LookVector)
	if look.Magnitude > 1e-3 then
		ctx.Heading = look.Unit
	end

	if ctx.Input.JumpPressed then
		return "Hop", nil
	end
	if ctx.Input.PrimaryPressed then
		return "Hop", { Smash = true }
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
