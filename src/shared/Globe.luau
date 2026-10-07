--!strict
-- The globe's ground is analytic (spec §15 milestone 3a): parts cap at 2,048 studs, so the planet surface is a
-- sphere in math rather than a collider, and the visual ball in the place has no collision. Every ground query
-- goes through Globe.raycast, which returns the nearer of a world raycast (props, buildings, walls) and the
-- ray's intersection with the surface sphere. Ground states hold the body at standing height themselves, so
-- nothing needs to physically rest on the sphere.

local Planet = require(script.Parent.Planets.Planet1)

local Globe = {}

export type Hit = {
	Position: Vector3,
	Normal: Vector3,
	Distance: number,
	Instance: Instance?, -- nil when the hit is the planet surface
}

-- Up (away from the planet's center) at a world position.
function Globe.upAt(position: Vector3): Vector3
	local radial = position - Planet.Center
	return if radial.Magnitude > 1e-3 then radial.Unit else Vector3.yAxis
end

-- Height above the planet's surface at a world position.
function Globe.altitudeAt(position: Vector3): number
	return (position - Planet.Center).Magnitude - Planet.Radius
end

-- Where a ray (origin, direction with length = reach) meets the surface sphere, or nil. An origin already
-- under the surface reports a hit at distance 0 on the surface straight above it, so a body that ever ends
-- up inside the planet is lifted back out instead of falling through.
local function sphereHit(origin: Vector3, direction: Vector3): Hit?
	local radius = Planet.Radius
	local offset = origin - Planet.Center
	local depth = offset.Magnitude
	if depth <= radius then
		local up = if depth > 1e-3 then offset / depth else Vector3.yAxis
		return { Position = Planet.Center + up * radius, Normal = up, Distance = 0, Instance = nil }
	end
	local length = direction.Magnitude
	if length < 1e-6 then
		return nil
	end
	local dir = direction / length
	-- Solve |offset + t·dir| = radius for the nearest t in [0, length].
	local b = offset:Dot(dir)
	local c = offset:Dot(offset) - radius * radius
	local discriminant = b * b - c
	if discriminant < 0 then
		return nil
	end
	local t = -b - math.sqrt(discriminant)
	if t < 0 or t > length then
		return nil
	end
	local position = origin + dir * t
	return { Position = position, Normal = (position - Planet.Center).Unit, Distance = t, Instance = nil }
end

-- Nearest hit along the ray among world parts and the planet surface.
function Globe.raycast(origin: Vector3, direction: Vector3, params: RaycastParams?): Hit?
	local surface = sphereHit(origin, direction)
	local part = workspace:Raycast(origin, direction, params)
	if part and (not surface or part.Distance < surface.Distance) then
		return { Position = part.Position, Normal = part.Normal, Distance = part.Distance, Instance = part.Instance }
	end
	return surface
end

return Globe
