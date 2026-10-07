--!strict
-- Additive camera layers on top of the base rig (spec §4.10, §11): shake, recoil, fovOffset, distanceOffset,
-- tilt, roll. Driven only by FeelTable entries through Juice. Shake, tilt and roll are visual: the aim ray uses
-- the base rig, so the crosshair never wanders with them.

local Layers = require(script.Parent.Parent.Feel.Layers)

local CameraEffects = {}

local layers = Layers.new({ "shake", "recoilDown", "recoilBack", "fovOffset", "distanceOffset", "tilt", "roll" })
local shakeFrequency = 20
local NOISE_SEEDS = Vector3.new(17.3, 41.9, 73.1) -- decorrelate the three shake axes; not a feel value

function CameraEffects.apply(entry: { [string]: any }, duration: number)
	local name = entry.cam
	if entry.freq then
		shakeFrequency = entry.freq
	end
	layers:apply(name, entry, duration)
end

export type Sample = { Fov: number, Distance: number, Rotation: CFrame, Offset: Vector3 }

-- Offsets for this frame. Offset is in camera space (x right, y up, z back).
function CameraEffects.sample(): Sample
	local amplitude = layers:get("shake")
	local offset = Vector3.new(0, -layers:get("recoilDown"), layers:get("recoilBack"))
	if amplitude > 1e-3 then
		local t = os.clock() * shakeFrequency
		offset += Vector3.new(math.noise(t, NOISE_SEEDS.X), math.noise(t, NOISE_SEEDS.Y), math.noise(t, NOISE_SEEDS.Z)) * amplitude * 2 -- math.noise spans about ±0.5
	end
	return {
		Fov = layers:get("fovOffset"),
		Distance = layers:get("distanceOffset"),
		Rotation = CFrame.Angles(math.rad(layers:get("tilt")), 0, math.rad(layers:get("roll"))),
		Offset = offset,
	}
end

return CameraEffects
