--!strict
-- Planet config (spec §5). A second planet is another module with the same shape.

return {
	Name = "Planet1",
	Seed = 1,
	SurfaceY = 0,
	DiscDiameter = 1200,
	EdgeCurve = 100,
	ShellRadius = 1500,
	ShellOffsetY = -1509, -- shell top sits just under the 8-stud disc (spec said -1480, which pokes through it)
	HaloRadius = 1560,
}
