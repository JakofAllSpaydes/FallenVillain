--!strict
-- Vector helpers shared by movement states and the camera rig. The world is a globe (spec §15 milestone 3), so
-- "up" is a direction passed in (ctx.Up, away from the planet's center), never world Y.

local Shared = game:GetService("ReplicatedStorage").Shared
local Globe = require(Shared.Globe)
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)

local MathUtil = {}

MathUtil.upAt = Globe.upAt
MathUtil.altitudeAt = Globe.altitudeAt

-- The component of `v` along the ground (perpendicular to `up`).
function MathUtil.flat(v: Vector3, up: Vector3): Vector3
	return v - up * v:Dot(up)
end

-- Rotation that carries `fromUp` onto `toUp` by the shortest arc: parallel transport around the globe, so a
-- velocity or heading that was level stays level as the player moves over the curve.
function MathUtil.transport(fromUp: Vector3, toUp: Vector3): CFrame
	local axis = fromUp:Cross(toUp)
	local sine = axis.Magnitude
	if sine < 1e-6 then
		return CFrame.identity
	end
	local angle = math.atan2(sine, fromUp:Dot(toUp))
	return CFrame.fromAxisAngle(axis / sine, angle)
end

-- A unit vector perpendicular to `up` that is as close as possible to `dir`, or `fallback` if `dir` is along up.
function MathUtil.tangent(dir: Vector3, up: Vector3, fallback: Vector3): Vector3
	local flat = MathUtil.flat(dir, up)
	if flat.Magnitude > 1e-4 then
		return flat.Unit
	end
	flat = MathUtil.flat(fallback, up)
	if flat.Magnitude > 1e-4 then
		return flat.Unit
	end
	local any = if math.abs(up.X) < 0.9 then Vector3.xAxis else Vector3.zAxis
	return MathUtil.flat(any, up).Unit
end

-- An upright body frame at `position`: Y along `up`, facing `heading`.
function MathUtil.upright(position: Vector3, heading: Vector3, up: Vector3): CFrame
	local forward = MathUtil.tangent(heading, up, Vector3.xAxis)
	return CFrame.fromMatrix(position, forward:Cross(up), up)
end

-- A frame whose X axis is `normal`: lays an X-axis cylinder (decal, ring, shadow) flat on a surface.
function MathUtil.onSurface(position: Vector3, normal: Vector3): CFrame
	local tangent = MathUtil.tangent(Vector3.xAxis, normal, Vector3.zAxis)
	return CFrame.fromMatrix(position, normal, tangent)
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

-- Value of a hold-time curve: points are { seconds, value } sorted by seconds, interpolated geometrically so the
-- curve starts gentle and climbs harder the longer the hold. Clamped to the first and last points.
function MathUtil.holdCurve(points: { { number } }, seconds: number): number
	if seconds <= points[1][1] then
		return points[1][2]
	end
	for index = 2, #points do
		local a, b = points[index - 1], points[index]
		if seconds <= b[1] then
			local t = (seconds - a[1]) / math.max(b[1] - a[1], 1e-3)
			return a[2] * (b[2] / a[2]) ^ t
		end
	end
	return points[#points][2]
end

-- Number of tier thresholds (sorted seconds) a hold has reached.
function MathUtil.tier(thresholds: { number }, seconds: number): number
	local reached = 0
	for _, threshold in thresholds do
		if seconds >= threshold then
			reached += 1
		end
	end
	return reached
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
function MathUtil.clampPitch(dir: Vector3, maxPitch: number, fallbackHeading: Vector3, up: Vector3): Vector3
	local limit = math.rad(maxPitch)
	if math.asin(math.clamp(dir:Dot(up), -1, 1)) <= limit then
		return dir
	end
	local heading = MathUtil.tangent(dir, up, fallbackHeading)
	return heading * math.cos(limit) + up * math.sin(limit)
end

-- Rotates a level heading by `degrees` to the right (clockwise seen from above).
function MathUtil.yawRight(heading: Vector3, degrees: number, up: Vector3): Vector3
	return CFrame.fromAxisAngle(up, -math.rad(degrees)) * heading
end

-- Signed level angle in degrees from `heading` to `target`; positive = target is to the right.
function MathUtil.signedYaw(heading: Vector3, target: Vector3, up: Vector3): number
	local flat = MathUtil.flat(target, up)
	if flat.Magnitude < 1e-4 then
		return 0
	end
	flat = flat.Unit
	return math.deg(math.atan2(-heading:Cross(flat):Dot(up), heading:Dot(flat)))
end

-- Angle of a direction above the horizon, in degrees.
function MathUtil.pitchOf(dir: Vector3, up: Vector3): number
	return math.deg(math.asin(math.clamp(dir.Unit:Dot(up), -1, 1)))
end

-- A level direction along `heading` tilted `degrees` above the horizon.
function MathUtil.pathDirection(heading: Vector3, degrees: number, up: Vector3): Vector3
	local radians = math.rad(degrees)
	return heading * math.cos(radians) + up * math.sin(radians)
end

-- Camera-relative level world direction for the move vector.
function MathUtil.cameraMove(move: Vector3, up: Vector3): Vector3
	local view = workspace.CurrentCamera.CFrame
	if move.Magnitude < 1e-4 then
		return Vector3.zero
	end
	local look = MathUtil.flat(view.LookVector, up)
	if look.Magnitude < 1e-4 then
		-- Looking straight up or down: the screen's up edge is forward.
		look = MathUtil.flat(view.UpVector, up)
		if look.Magnitude < 1e-4 then
			return Vector3.zero
		end
	end
	look = look.Unit
	local right = look:Cross(up)
	return right * move.X - look * move.Z
end

-- Heading to fly out of a dive with. Steep dives have almost no level velocity, and its direction is
-- noise, so use where the camera looks instead of flinging the player that way.
function MathUtil.exitHeading(ctx: Types.Ctx): Vector3
	local horizontal = MathUtil.flat(ctx.Velocity, ctx.Up)
	if horizontal.Magnitude > 1 and horizontal.Magnitude >= ctx.Velocity.Magnitude * Tuning.Swoop.SteepFraction then
		return horizontal.Unit
	end
	return MathUtil.tangent(ctx.LookDirection, ctx.Up, ctx.Heading)
end

-- Yaw steering input in [-1, 1] for Glide and Swoop: A/D if pressed, else turn toward where the camera looks.
-- The camera never follows the heading, so this converges instead of feeding back on itself.
function MathUtil.steerInput(ctx: Types.Ctx): number
	local x = ctx.Input.Move.X
	-- Just after a bounce, don't steer back toward the look, or a glide turns straight back into the wall.
	if math.abs(x) > 0.01 or Tuning.Glide.LookFollowWeight <= 0 or ctx.Now < ctx.LookFollowAfter then
		return math.clamp(x, -1, 1)
	end
	local angle = MathUtil.signedYaw(ctx.Heading, ctx.LookDirection, ctx.Up)
	return math.clamp(angle / Tuning.Glide.LookFollowFullAngle, -1, 1) * Tuning.Glide.LookFollowWeight
end

return MathUtil
