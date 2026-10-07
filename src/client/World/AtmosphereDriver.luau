--!strict
-- Altitude drives the sky (spec §5, §11): each frame, find the bands around the camera's altitude, lerp their
-- looks, and ease Lighting, Atmosphere, the post bases and the audio low-pass toward it, so band edges never pop.
-- Client-only; writes local copies of Lighting properties.

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Planet = require(Shared.Planets.Planet1)
local SkyBands = require(Shared.SkyBands)
local Tuning = require(Shared.Tuning)

local Audio = require(script.Parent.Parent.Feel.Audio)
local Post = require(script.Parent.Parent.Feel.Post)

local AtmosphereDriver = {}

local NUMBERS = {
	"AtmosphereDensity",
	"AtmosphereOffset",
	"AtmosphereHaze",
	"AtmosphereGlare",
	"Brightness",
	"SunRays",
	"Bloom",
	"LowPass",
}
local COLORS = { "AtmosphereColor", "AtmosphereDecay", "Ambient", "OutdoorAmbient" }

local current: { [string]: any } = {}
local atmosphere: Atmosphere?

local function target(altitude: number): { [string]: any }
	local lower, upper = SkyBands[1], SkyBands[1]
	for index, band in SkyBands do
		if altitude >= band.MinAltitude then
			lower = band
			upper = SkyBands[index + 1] or band
		end
	end
	local span = upper.MinAltitude - lower.MinAltitude
	local t = if span > 0 then math.clamp((altitude - lower.MinAltitude) / span, 0, 1) else 0
	local look: { [string]: any } = {}
	local a, b = lower.Look :: any, upper.Look :: any
	for _, key in NUMBERS do
		look[key] = a[key] + (b[key] - a[key]) * t
	end
	for _, key in COLORS do
		look[key] = (a[key] :: Color3):Lerp(b[key], t)
	end
	return look
end

local function apply(look: { [string]: any })
	if atmosphere then
		atmosphere.Density = look.AtmosphereDensity
		atmosphere.Offset = look.AtmosphereOffset
		atmosphere.Haze = look.AtmosphereHaze
		atmosphere.Glare = look.AtmosphereGlare
		atmosphere.Color = look.AtmosphereColor
		atmosphere.Decay = look.AtmosphereDecay
	end
	Lighting.Ambient = look.Ambient
	Lighting.OutdoorAmbient = look.OutdoorAmbient
	Lighting.Brightness = look.Brightness
	Post.setBase("SunRays", look.SunRays)
	Post.setBase("Bloom", look.Bloom)
	Audio.setLowPass(look.LowPass)
end

local function update(dt: number)
	local altitude = workspace.CurrentCamera.CFrame.Position.Y - Planet.SurfaceY
	local goal = target(altitude)
	-- Exponential ease with a time constant of Sky.Smoothing seconds.
	local alpha = 1 - math.exp(-dt / Tuning.Sky.Smoothing)
	for _, key in NUMBERS do
		current[key] += (goal[key] - current[key]) * alpha
	end
	for _, key in COLORS do
		current[key] = (current[key] :: Color3):Lerp(goal[key], alpha)
	end
	apply(current)
end

function AtmosphereDriver.start()
	atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	current = target(workspace.CurrentCamera.CFrame.Position.Y - Planet.SurfaceY)
	apply(current)
	RunService.RenderStepped:Connect(update)
end

return AtmosphereDriver
