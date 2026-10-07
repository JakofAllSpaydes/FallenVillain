--!strict
-- Additive camera layers on top of the base rig (spec §4.10, §11): shake, recoil, fovOffset, distanceOffset,
-- tilt, roll, driven by FeelTable entries through Juice, plus the per-frame driven layers (fovDrive,
-- distanceDrive, shakeDrive) that Feel/Drivers sets from live speed and charge. Shake, tilt and roll are
-- visual: the aim ray uses the base rig, so the crosshair never wanders with them.
--
-- Shake is trauma-style: the amplitude is a "trauma" level, and the shake applied is amplitude² (small hits
-- barely register, big ones are violent), split between a positional offset and a rotational wobble (roll,
-- pitch, yaw) from smooth noise. Rotation is what sells a hit; position alone reads as drift.

local Tuning = require(game:GetService("ReplicatedStorage").Shared.Tuning)
local Layers = require(script.Parent.Parent.Feel.Layers)

local CameraEffects = {}

local layers = Layers.new({
	"shake",
	"recoilDown",
	"recoilBack",
	"fovOffset",
	"distanceOffset",
	"tilt",
	"roll",
	"fovDrive",
	"distanceDrive",
	"shakeDrive",
})
local shakeFrequency = 20
local driveFrequency = 30
-- Decorrelate the noise channels; not feel values.
local SEEDS = { 17.3, 41.9, 73.1, 5.7, 23.3, 91.7 }
local DRIVE_SEEDS = { 11.1, 37.7, 59.3, 83.9, 19.7, 47.1 }

function CameraEffects.apply(entry: { [string]: any }, duration: number)
	local name = entry.cam
	if entry.freq then
		shakeFrequency = entry.freq
	end
	layers:apply(name, entry, duration)
end

-- Per-frame value for a driven layer (set, never tweened).
function CameraEffects.drive(name: string, value: number, frequency: number?)
	if frequency then
		driveFrequency = frequency
	end
	layers:set(name, value, 0)
end

export type Sample = { Fov: number, Distance: number, Rotation: CFrame, Offset: Vector3 }

-- Position (studs) and rotation (radians) for a trauma level at this frequency. math.noise spans about ±0.5.
local function shake(trauma: number, frequency: number, seeds: { number }): (Vector3, Vector3)
	if trauma <= 1e-3 then
		return Vector3.zero, Vector3.zero
	end
	local S = Tuning.CameraShake
	local power = math.clamp(trauma, 0, S.MaxTrauma) ^ S.Exponent
	local t = os.clock() * frequency
	local position = Vector3.new(math.noise(t, seeds[1]), math.noise(t, seeds[2]), math.noise(t, seeds[3]))
		* (2 * power * S.PositionScale)
	local rotation = Vector3.new(math.noise(t, seeds[4]), math.noise(t, seeds[5]), math.noise(t, seeds[6]))
		* (2 * power * math.rad(S.RotationDegrees))
	return position, rotation
end

-- Offsets for this frame. Offset is in camera space (x right, y up, z back).
function CameraEffects.sample(): Sample
	local offset = Vector3.new(0, -layers:get("recoilDown"), layers:get("recoilBack"))
	local p1, r1 = shake(layers:get("shake"), shakeFrequency, SEEDS)
	local p2, r2 = shake(layers:get("shakeDrive"), driveFrequency, DRIVE_SEEDS)
	offset += p1 + p2
	local wobble = r1 + r2
	local rotation =
		CFrame.Angles(math.rad(layers:get("tilt")) + wobble.X, wobble.Y, math.rad(layers:get("roll")) + wobble.Z)
	return {
		Fov = layers:get("fovOffset") + layers:get("fovDrive"),
		Distance = layers:get("distanceOffset") + layers:get("distanceDrive"),
		Rotation = rotation,
		Offset = offset,
	}
end

return CameraEffects
