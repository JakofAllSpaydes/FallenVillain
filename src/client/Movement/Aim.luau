--!strict
-- Aim ray (spec §10, §4.6): from the camera through the screen-center crosshair, against the world, excluding
-- characters. The magnet: destructibles within Aim.MagnetRadius of the hit pull the aim point toward the
-- nearest one's centre (a soft pull that fades with distance, never a lock), so dives and punches land on
-- buildings; the hit object itself, when destructible, is the target with no pull. The reticle and the smash
-- preview read AimTarget and AimMagnet.

local Shared = game:GetService("ReplicatedStorage").Shared
local Destructibles = require(Shared.Destructibles)
local Globe = require(Shared.Globe)
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)

local Aim = {}

-- The camera rig writes its base view here each frame (without shake, tilt or roll), so effects never move the aim.
Aim.view = nil :: CFrame?

local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include

-- The nearest destructible to `point` within the magnet radius (by bounding-box centre), and its centre.
local function nearestDestructible(point: Vector3): (Model?, Vector3?, number)
	local folder = Destructibles.folder()
	if not folder then
		return nil, nil, 0
	end
	local A = Tuning.Aim
	overlap.FilterDescendantsInstances = { folder }
	overlap.MaxParts = A.MagnetMaxParts
	local best: Model? = nil
	local bestCenter: Vector3? = nil
	local bestDistance = math.huge
	local seen: { [Model]: boolean } = {}
	for _, part in workspace:GetPartBoundsInRadius(point, A.MagnetRadius, overlap) do
		local model = Destructibles.modelOf(part)
		if model and not seen[model] then
			seen[model] = true
			local box = model:GetBoundingBox()
			local distance = (box.Position - point).Magnitude
			if distance < bestDistance then
				best, bestCenter, bestDistance = model, box.Position, distance
			end
		end
	end
	return best, bestCenter, bestDistance
end

function Aim.update(ctx: Types.Ctx)
	local A = Tuning.Aim
	local view = Aim.view or workspace.CurrentCamera.CFrame
	local reach = view.LookVector * A.MaxDistance
	local hit = Globe.raycast(view.Position, reach, ctx.RaycastParams)
	ctx.LookDirection = view.LookVector
	if not hit then
		ctx.AimPoint = view.Position + reach
		ctx.AimTarget = nil
		ctx.AimMagnet = 0
		return
	end
	local direct = Destructibles.modelOf(hit.Instance)
	if direct then
		ctx.AimPoint = hit.Position
		ctx.AimTarget = direct
		ctx.AimMagnet = 1
		return
	end
	local model, center, distance = nearestDestructible(hit.Position)
	if model and center then
		-- Pull toward the target's centre, projected back onto the ground plane of the hit so the aim point
		-- stays on the surface rather than floating at the building's middle.
		local closeness = 1 - math.clamp(distance / math.max(A.MagnetRadius, 1e-3), 0, 1)
		local pull = A.MagnetStrength * closeness
		local target = center - hit.Normal * (center - hit.Position):Dot(hit.Normal)
		ctx.AimPoint = hit.Position:Lerp(target, pull)
		ctx.AimTarget = model
		ctx.AimMagnet = closeness
	else
		ctx.AimPoint = hit.Position
		ctx.AimTarget = nil
		ctx.AimMagnet = 0
	end
end

return Aim
