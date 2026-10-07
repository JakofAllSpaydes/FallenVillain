--!strict
-- Controller-driven ground states (Grounded, Slide, Landing, Charging) keep their own level momentum instead
-- of handing the body to the Humanoid. This holds the root at standing height over the ground and bleeds
-- momentum toward the walk input, so walking, touchdowns and charging feel weighted, not frozen.

local Shared = game:GetService("ReplicatedStorage").Shared
local Globe = require(Shared.Globe)
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)
local MathUtil = require(script.Parent.MathUtil)

local GroundHold = {}

-- The floor under the player within the hold probe, or nil (walked off a ledge).
function GroundHold.floor(ctx: Types.Ctx): Globe.Hit?
	local probe = -ctx.Up * (ctx.StandHeight + Tuning.Physics.GroundHoldProbe)
	return Globe.raycast(ctx.Root.Position, probe, ctx.RaycastParams)
end

-- Returns false when there is no ground below.
-- `damping` is 1/seconds; `walk` scales the walk speed momentum settles toward (0 = come to rest).
function GroundHold.step(ctx: Types.Ctx, dt: number, damping: number, walk: number): boolean
	local ground = GroundHold.floor(ctx)
	if not ground then
		return false
	end
	local up = ctx.Up
	local wish = MathUtil.cameraMove(ctx.Input.Move, up) * Tuning.Walk.Speed * walk
	local level = MathUtil.flat(ctx.Velocity, up)
	level = wish + (level - wish) * math.exp(-damping * dt)
	local lift = (ground.Position - ctx.Root.Position):Dot(up) + ctx.StandHeight
	local vy = if dt > 0 then lift / dt else 0
	ctx.Velocity = level + up * vy
	if level.Magnitude > 1 then
		ctx.Heading = level.Unit
	end
	return true
end

return GroundHold
