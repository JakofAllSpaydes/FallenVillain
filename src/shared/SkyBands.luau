--!strict
-- Altitude bands (spec §5). Sorted by MinAltitude. Each band's look is the target at its MinAltitude;
-- AtmosphereDriver lerps between neighbours, so a band's look is fully reached where the next band starts
-- blending from it. Monochrome palette: warm gray at the surface, white in the clouds, near black at the Edge.

export type Look = {
	AtmosphereDensity: number,
	AtmosphereOffset: number,
	AtmosphereHaze: number,
	AtmosphereGlare: number,
	AtmosphereColor: Color3,
	AtmosphereDecay: Color3,
	Ambient: Color3,
	OutdoorAmbient: Color3,
	Brightness: number,
	SunRays: number, -- base SunRays intensity; post layers add on top
	Bloom: number, -- base Bloom intensity
	LowPass: number, -- dB on the wind and ambient buses
}

export type Band = {
	Name: string,
	MinAltitude: number,
	MaxAltitude: number,
	Look: Look,
}

local function gray(value: number): Color3
	return Color3.fromRGB(value, value, value)
end

local SkyBands: { Band } = {
	{
		Name = "Surface",
		MinAltitude = 0,
		MaxAltitude = 300,
		Look = {
			AtmosphereDensity = 0.35,
			AtmosphereOffset = 0.1,
			AtmosphereHaze = 1.5,
			AtmosphereGlare = 0,
			AtmosphereColor = Color3.fromRGB(200, 196, 188),
			AtmosphereDecay = Color3.fromRGB(120, 114, 106),
			Ambient = gray(70),
			OutdoorAmbient = gray(130),
			Brightness = 2,
			SunRays = 0,
			Bloom = 0.4,
			LowPass = 0,
		},
	},
	{
		Name = "CloudDeck",
		MinAltitude = 300,
		MaxAltitude = 1200,
		Look = {
			AtmosphereDensity = 0.45,
			AtmosphereOffset = 0.2,
			AtmosphereHaze = 2.5,
			AtmosphereGlare = 0.2,
			AtmosphereColor = gray(228),
			AtmosphereDecay = gray(180),
			Ambient = gray(110),
			OutdoorAmbient = gray(170),
			Brightness = 2.5,
			SunRays = 0.1,
			Bloom = 0.5,
			LowPass = -6,
		},
	},
	{
		Name = "Clear",
		MinAltitude = 1200,
		MaxAltitude = 3500,
		Look = {
			AtmosphereDensity = 0.22,
			AtmosphereOffset = 0.25,
			AtmosphereHaze = 0.6,
			AtmosphereGlare = 0.4,
			AtmosphereColor = Color3.fromRGB(150, 160, 178),
			AtmosphereDecay = Color3.fromRGB(70, 78, 96),
			Ambient = gray(80),
			OutdoorAmbient = gray(140),
			Brightness = 2.5,
			SunRays = 0.4,
			Bloom = 0.5,
			LowPass = -12,
		},
	},
	{
		Name = "Storm",
		MinAltitude = 3500,
		MaxAltitude = 7000,
		Look = {
			AtmosphereDensity = 0.15,
			AtmosphereOffset = 0.3,
			AtmosphereHaze = 1,
			AtmosphereGlare = 0.3,
			AtmosphereColor = Color3.fromRGB(90, 94, 106),
			AtmosphereDecay = Color3.fromRGB(30, 30, 40),
			Ambient = gray(55),
			OutdoorAmbient = gray(95),
			Brightness = 2,
			SunRays = 0.4,
			Bloom = 0.5,
			LowPass = -18,
		},
	},
	{
		Name = "Aurora",
		MinAltitude = 7000,
		MaxAltitude = 11000,
		Look = {
			AtmosphereDensity = 0.06,
			AtmosphereOffset = 0.4,
			AtmosphereHaze = 0.3,
			AtmosphereGlare = 0.5,
			AtmosphereColor = Color3.fromRGB(40, 48, 66),
			AtmosphereDecay = Color3.fromRGB(10, 12, 20),
			Ambient = gray(45),
			OutdoorAmbient = gray(80),
			Brightness = 2,
			SunRays = 0.4,
			Bloom = 0.6,
			LowPass = -24,
		},
	},
	{
		Name = "Edge",
		MinAltitude = 11000,
		MaxAltitude = 16000,
		Look = {
			AtmosphereDensity = 0.02,
			AtmosphereOffset = 0.5,
			AtmosphereHaze = 0,
			AtmosphereGlare = 0.6,
			AtmosphereColor = gray(14),
			AtmosphereDecay = gray(4),
			Ambient = gray(40),
			OutdoorAmbient = gray(70),
			Brightness = 2,
			SunRays = 0.4,
			Bloom = 0.6,
			LowPass = -30,
		},
	},
}

return SkyBands
