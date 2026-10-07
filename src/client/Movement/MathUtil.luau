--!strict
-- Vector helpers shared by movement states and the camera rig.

local Shared = game:GetService("ReplicatedStorage").Shared
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)

local MathUtil = {}

function MathUtil.flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function MathUtil.moveToward(current: number, target: number, maxDelta: number): number
	if current < target then
		return math.min(current + maxDelta, target)
	end
	return math.max(current - maxDelta, target)
end

function MathUtil.moveTowardVector(current: Vector3, target: Vector3, maxDelta: number): Vector3
	local delta = target - current
	if delta.Magnitude <= maxDelta then
		return target
	end
	return current + delta.Unit * maxDelta
end

-- Exponential approach that is frame-rate independent: rate is 1/seconds.
function MathUtil.approach(current: number, target: number, rate: number, dt: number): number
	return target + (current - target) * math.exp(-rate * dt)
end

-- Rotates unit vector `from` toward unit vector `to` by at most `maxAngle` radians.
function MathUtil.rotateTowards(from: Vector3, to: Vector3, maxAngle: number): Vector3
	local angle = math.acos(math.clamp(from:Dot(to), -1, 1))
	if angle <= maxAngle then
		return to
	end
	local axis = from:Cross(to)
	if axis.Magnitude < 1e-6 then
		axis = from:Cross(Vector3.xAxis)
		if axis.Magnitude < 1e-6 then
			axis = from:Cross(Vector3.zAxis)
		end
	end
	return (CFrame.fromAxisAngle(axis.Unit, maxAngle) * from).Unit
end

-- Limits how far above the horizon a unit direction may point. maxPitch in degrees.
function MathUtil.clampPitch(dir: Vector3, maxPitch: number, fallbackHeading: Vector3): Vector3
	local limit = math.rad(maxPitch)
	if math.asin(math.clamp(dir.Y, -1, 1)) <= limit then
		return dir
	end
	local flat = MathUtil.flat(dir)
	local heading = if flat.Magnitude > 1e-4 then flat.Unit else fallbackHeading
	return heading * math.cos(limit) + Vector3.yAxis * math.sin(limit)
end

-- Rotates a horizontal heading by `degrees` to the right (clockwise seen from above).
function MathUtil.yawRight(heading: Vector3, degrees: number): Vector3
	return CFrame.Angles(0, -math.rad(degrees), 0) * heading
end

-- Signed horizontal angle in degrees from `heading` to `target`; positive = target is to the right.
function MathUtil.signedYaw(heading: Vector3, target: Vector3): number
	local flat = MathUtil.flat(target)
	if flat.Magnitude < 1e-4 then
		return 0
	end
	flat = flat.Unit
	return math.deg(math.atan2(-heading:Cross(flat).Y, heading:Dot(flat)))
end

-- Camera yaw (degrees) that looks along a horizontal direction, matching CFrame.fromOrientation.
function MathUtil.yawOf(dir: Vector3): number
	return math.deg(math.atan2(-dir.X, -dir.Z))
end

function MathUtil.pitchOf(dir: Vector3): number
	return math.deg(math.asin(math.clamp(dir.Unit.Y, -1, 1)))
end

-- Camera-relative world direction for the move vector, flattened.
function MathUtil.cameraMove(move: Vector3): Vector3
	local look = MathUtil.flat(workspace.CurrentCamera.CFrame.LookVector)
	if look.Magnitude < 1e-4 or move.Magnitude < 1e-4 then
		return Vector3.zero
	end
	look = look.Unit
	local right = look:Cross(Vector3.yAxis)
	return right * move.X - look * move.Z
end

-- Heading to fly out of a dive with. Steep dives have almost no horizontal velocity, and its direction is
-- noise, so use where the camera looks instead of flinging the player that way.
function MathUtil.exitHeading(ctx: Types.Ctx): Vector3
	local horizontal = MathUtil.flat(ctx.Velocity)
	if horizontal.Magnitude > 1 and horizontal.Magnitude >= ctx.Velocity.Magnitude * Tuning.Swoop.SteepFraction then
		return horizontal.Unit
	end
	local look = MathUtil.flat(ctx.LookDirection)
	if look.Magnitude > 1e-3 then
		return look.Unit
	end
	return ctx.Heading
end

-- Yaw steering input in [-1, 1] for Glide and Swoop: A/D if pressed, else turn toward where the camera looks.
-- The camera never follows the heading, so this converges instead of feeding back on itself.
function MathUtil.steerInput(ctx: Types.Ctx): number
	local x = ctx.Input.Move.X
	if math.abs(x) > 0.01 or Tuning.Glide.LookFollowWeight <= 0 then
		return math.clamp(x, -1, 1)
	end
	local angle = MathUtil.signedYaw(ctx.Heading, ctx.LookDirection)
	return math.clamp(angle / Tuning.Glide.LookFollowFullAngle, -1, 1) * Tuning.Glide.LookFollowWeight
end

return MathUtil
