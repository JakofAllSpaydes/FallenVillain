--!strict
-- Per-frame driven effects (spec §4.6, §11: "the dive FOV is a per-frame function of speed, not a tween").
-- Where the FeelTable fires one-shots and tweens on events, this reads the live context every frame and sets
-- the driven layers of each sink, which add to the FeelTable's own layers:
--   * Charge zoom: both charges pull the camera in and narrow the FOV the longer you hold (jump charge while
--     Space is held on the ground, punch charge while LMB is held), log-shaped over the whole hold curve so the
--     first seconds move it most, easing back out on release.
--   * Speed: FOV is the speed meter and shake is the danger meter (spec §4.10); the rush loop, speed lines,
--     embers, the orange heat edges and the dive blur all follow speed. Nothing here has a terminal speed:
--     everything saturates toward its maximum with a reference speed (Tuning.Drive.Speed).
--   * The fist glow while a punch charges.
-- Values live in Tuning.Drive. This module reads the controller; it never drives movement.

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Tuning = require(Shared.Tuning)

local CameraEffects = require(script.Parent.Parent.Camera.CameraEffects)
local Controller = require(script.Parent.Parent.Movement.Controller)
local JumpCheck = require(script.Parent.Parent.Movement.JumpCheck)
local MathUtil = require(script.Parent.Parent.Movement.MathUtil)
local Audio = require(script.Parent.Audio)
local Post = require(script.Parent.Post)
local Vfx = require(script.Parent.Vfx)

local Drivers = {}

local GROUND_STATES: { [string]: boolean } = { Grounded = true, Landing = true, Charging = true, Slide = true }

local zoom, narrow = 0, 0

-- 0–1 over a hold curve whose last point is at `lastEnd` seconds, log-shaped.
local function holdProgress(held: number, lastEnd: number): number
	return math.clamp(math.log(1 + held) / math.log(1 + lastEnd), 0, 1)
end

-- 0–1 that approaches 1 as `value` grows past `ref`, with no cap.
local function saturate(value: number, ref: number): number
	return 1 - math.exp(-math.max(0, value) / math.max(ref, 1e-3))
end

local function clear()
	CameraEffects.drive("fovDrive", 0)
	CameraEffects.drive("distanceDrive", 0)
	CameraEffects.drive("shakeDrive", 0)
	Audio.drive("Rush", 0, 0)
	Post.drive("Heat", 0)
	Post.drive("Tint", 0)
	Post.drive("BlurDrive", 0)
	Post.drive("SpeedLines", 0)
	Vfx.drive("SpeedLines", 0)
	Vfx.drive("Trails", 0)
	Vfx.drive("Embers", 0)
	Vfx.drive("Fist", 0)
end

local function update(dt: number)
	local ctx = Controller.ctx
	if not ctx then
		clear()
		return
	end
	local D = Tuning.Drive

	-- Charge zoom.
	local burstHeights = Tuning.Burst.HoldHeights
	local punchBoosts = Tuning.Punch.HoldBoosts
	local held = JumpCheck.held()
	local jumpProgress = 0
	if held and held > Tuning.Hop.TapTime and GROUND_STATES[ctx.State] then
		jumpProgress = holdProgress(held, burstHeights[#burstHeights][1])
	end
	local punchHold = ctx.PunchHold
	local punchProgress = if punchHold then holdProgress(punchHold, punchBoosts[#punchBoosts][1]) else 0
	local zoomTarget = D.Charge.Zoom * jumpProgress + D.PunchCharge.Zoom * punchProgress
	local narrowTarget = D.Charge.Fov * jumpProgress + D.PunchCharge.Fov * punchProgress
	zoom = MathUtil.approach(zoom, zoomTarget, if zoomTarget > zoom then D.ChargeSmooth else D.ChargeRelease, dt)
	narrow = MathUtil.approach(
		narrow,
		narrowTarget,
		if math.abs(narrowTarget) > math.abs(narrow) then D.ChargeSmooth else D.ChargeRelease,
		dt
	)

	-- Speed.
	local S = D.Speed
	local speed = ctx.Velocity.Magnitude
	local over = speed - S.Floor
	local rush = saturate(over, S.RushRef)
	local heat = math.clamp((speed - S.HeatStart) / math.max(S.HeatRange, 1e-3), 0, 1)
	local blur = if ctx.State == "Dive" then S.DiveBlur * saturate(over, S.DiveBlurRef) else 0

	local lines = saturate(speed - S.LinesStart, S.LinesRef)
	CameraEffects.drive("fovDrive", S.Fov * saturate(over, S.FovRef) + narrow)
	CameraEffects.drive("distanceDrive", -zoom)
	CameraEffects.drive("shakeDrive", S.Shake * saturate(over, S.ShakeRef), S.ShakeFreq)
	Audio.drive("Rush", rush, S.RushPitch * rush)
	Post.drive("Heat", S.Heat * heat)
	Post.drive("Tint", S.Tint * heat)
	Post.drive("BlurDrive", blur)
	Post.drive("SpeedLines", lines)
	Vfx.drive("SpeedLines", lines)
	Vfx.drive("Trails", lines)
	Vfx.drive("Embers", heat)

	-- Fist glow.
	local fist = 0
	if punchHold then
		local basic = math.clamp(punchHold / Tuning.Punch.ChargeTime, 0, 1)
		fist = D.FistBaseShare * basic + (1 - D.FistBaseShare) * punchProgress
	end
	Vfx.drive("Fist", fist)
end

function Drivers.start()
	-- Before the camera rig reads its layers this frame.
	RunService:BindToRenderStep("FallDrivers", Enum.RenderPriority.Camera.Value - 1, update)
end

return Drivers
