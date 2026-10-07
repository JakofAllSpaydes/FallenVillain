--!strict
-- Planet config (spec §5, §15 milestone 3a). The world is a real globe centered on the world origin: gravity
-- points at Center everywhere, the surface is an analytic sphere (shared/Globe.luau), and the altar sits on
-- its top at (0, Radius, 0). A second planet is another module with the same shape.

local Radius = 2500

return {
	Name = "Planet1",
	Seed = 1,
	Radius = Radius,
	Center = Vector3.zero,
	HaloRadius = Radius + 150,
	CloudAltitudeMin = 540,
	CloudAltitudeMax = 900,
}
