--!strict
-- Controller-driven ground states (Slide, Landing, Charging) keep their own horizontal momentum instead of
-- handing the body to the Humanoid, which would stop it dead. This holds the root at standing height over the
-- ground and bleeds momentum toward the walk input, so touchdowns and charging feel weighted, not frozen.

local Shared = game:GetService("ReplicatedStorage").Shared
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)
local MathUtil = require(script.Parent.MathUtil)

local GroundHold = {}

-- Returns false when there is no ground below (walked off a ledge).
-- `damping` is 1/seconds; `walk` scales the walk speed momentum settles toward (0 = come to rest).
function GroundHold.step(ctx: Types.Ctx, dt: number, damping: number, walk: number): boolean
	local probe = -Vector3.yAxis * (ctx.StandHeight + Tuning.Physics.GroundHoldProbe)
	local ground = workspace:Raycast(ctx.Root.Position, probe, ctx.RaycastParams)
	if not ground then
		return false
	end
	local wish = MathUtil.cameraMove(ctx.Input.Move) * Tuning.Walk.Speed * walk
	local horizontal = MathUtil.flat(ctx.Velocity)
	horizontal = wish + (horizontal - wish) * math.exp(-damping * dt)
	local targetY = ground.Position.Y + ctx.StandHeight
	local vy = if dt > 0 then (targetY - ctx.Root.Position.Y) / dt else 0
	ctx.Velocity = horizontal + Vector3.yAxis * vy
	if horizontal.Magnitude > 1 then
		ctx.Heading = horizontal.Unit
	end
	return true
end

return GroundHold
