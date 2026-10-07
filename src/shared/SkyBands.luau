--!strict
-- Altitude bands (spec §5). Sorted by MinAltitude; AtmosphereDriver lerps between neighbours.

export type Band = {
	Name: string,
	MinAltitude: number,
	MaxAltitude: number,
}

local SkyBands: { Band } = {
	{ Name = "Surface", MinAltitude = 0, MaxAltitude = 300 },
	{ Name = "CloudDeck", MinAltitude = 300, MaxAltitude = 1200 },
	{ Name = "Clear", MinAltitude = 1200, MaxAltitude = 3500 },
	{ Name = "Storm", MinAltitude = 3500, MaxAltitude = 7000 },
	{ Name = "Aurora", MinAltitude = 7000, MaxAltitude = 11000 },
	{ Name = "Edge", MinAltitude = 11000, MaxAltitude = 16000 },
}

return SkyBands
