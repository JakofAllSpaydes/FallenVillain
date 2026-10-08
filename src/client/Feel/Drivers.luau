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
--   * The smash preview (spec §4.6): in the air, a ring on the ground at the aim point sized to the smash
--     radius at the current speed (the punch's full radius while punching), stronger with speed and over a
--     destructible; and the "oh no" approach in a dive, which drives the approach drone, bloom and the
--     target's glow spot as impact closes within Preview.ApproachTime.
-- Values live in Tuning.Drive and Tuning.Preview. This module reads the controller; it never drives movement.

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Globe = require(Shared.Globe)
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
local previewRadius, previewAlpha, previewHot = 0, 0, 0

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
	Audio.drive("Creak", 0, 0)
	Post.drive("Heat", 0)
	Post.drive("Tint", 0)
	Post.drive("BlurDrive", 0)
	Post.drive("SpeedLines", 0)
	Vfx.drive("SpeedLines", 0)
	Vfx.drive("Trails", 0)
	Vfx.drive("Embers", 0)
	Vfx.drive("Fist", 0)
	Vfx.setPreview(nil, 0, 0, 0, 0)
	Audio.drive("ApproachDrone", 0, 0)
	Post.drive("BloomDrive", 0)
end

-- The smash preview and the dive approach.
local function updatePreview(ctx: any, dt: number)
	local P, S, I = Tuning.Preview, Tuning.Smash, Tuning.Impact
	local speed = ctx.Velocity.Magnitude
	local shown = P.States[ctx.State] == true and speed >= S.MinSpeed
	local punching = ctx.Input.PrimaryHeld or ctx.Now < ctx.PunchFiredAt + S.PunchWindow
	local radius = (I.RadiusBase + speed / I.RadiusSpeedDivisor)
		* (if punching then 1 else I.PlainPoundScale)
		* (1 + ctx.FallPeak / I.PeakDivisor * I.PeakRadiusBonus)
	local strength = math.clamp((speed - S.MinSpeed) / math.max(P.FullSpeed - S.MinSpeed, 1e-3), 0, 1)
	local hot = if ctx.AimTarget then ctx.AimMagnet else 0
	local alpha = if shown then P.MinAlpha + (P.MaxAlpha - P.MinAlpha) * strength + P.HotBoost * hot else 0
	previewRadius = MathUtil.approach(previewRadius, radius, P.Response, dt)
	previewAlpha = MathUtil.approach(previewAlpha, alpha, P.Response, dt)
	previewHot = MathUtil.approach(previewHot, hot, P.Response, dt)

	-- Approach: seconds to the aim point at this speed, or to the ground straight down, whichever is sooner.
	local approach = 0
	if ctx.State == "Dive" and shown then
		local toAim = (ctx.AimPoint - ctx.Root.Position).Magnitude / math.max(speed, 1)
		local sink = -ctx.Velocity:Dot(ctx.Up)
		local toGround = if sink > 1 then ctx.Altitude / sink else math.huge
		local time = math.min(toAim, toGround)
		approach = math.clamp(1 - time / math.max(P.ApproachTime, 1e-3), 0, 1)
	end
	Audio.drive("ApproachDrone", approach ^ 1.5, P.ApproachPitchRise * approach)
	Post.drive("BloomDrive", P.ApproachBloom * approach * approach)

	if previewAlpha > 0.01 then
		-- The ring sits on the ground under the aim point (a wall hit puts it at the building's foot).
		local up = MathUtil.upAt(ctx.AimPoint)
		local ground = Globe.raycast(ctx.AimPoint + up * 2, -up * P.GroundProbe, ctx.RaycastParams)
		local position = if ground then ground.Position else ctx.AimPoint
		Vfx.setPreview(position, previewRadius, previewAlpha, previewHot, approach)
	else
		Vfx.setPreview(nil, 0, 0, 0, 0)
	end
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

	-- The fall: descent speed in the air pulls the camera in and builds the blur, shake and rush from the apex
	-- on, saturating toward full (review note: start it as soon as you start falling, scaled to the max).
	local F = D.Fall
	local descent = if GROUND_STATES[ctx.State] then 0 else math.max(0, -ctx.Velocity:Dot(ctx.Up))
	local fall = saturate(descent, F.Ref)
	blur = math.max(blur, F.Blur * fall)
	rush = math.max(rush, F.Rush * fall)

	local lines = saturate(speed - S.LinesStart, S.LinesRef)
	CameraEffects.drive("fovDrive", S.Fov * saturate(over, S.FovRef) + F.Fov * fall + narrow)
	CameraEffects.drive("distanceDrive", -zoom - F.Zoom * fall)
	CameraEffects.drive("shakeDrive", S.Shake * saturate(over, S.ShakeRef) + F.Shake * fall, S.ShakeFreq)
	Audio.drive("Rush", rush, S.RushPitch * rush)
	-- Glide energy running low: the wings creak (spec §4.5).
	local E = Tuning.GlideEnergy
	local strain = if ctx.State == "Glide" and ctx.GlideEnergy < E.StrainThreshold
		then 1 - ctx.GlideEnergy / math.max(E.StrainThreshold, 1e-3)
		else 0
	Audio.drive("Creak", strain, 0)
	Post.drive("Heat", S.Heat * heat)
	Post.drive("Tint", S.Tint * heat)
	Post.drive("BlurDrive", blur)
	Post.drive("SpeedLines", lines)
	Vfx.drive("SpeedLines", lines)
	Vfx.drive("Trails", lines)
	Vfx.drive("Embers", heat)

	-- Fist glow, from the punch charge or the blast charge, whichever is further along.
	local fist = 0
	if punchHold then
		local basic = math.clamp(punchHold / Tuning.Punch.ChargeTime, 0, 1)
		fist = D.FistBaseShare * basic + (1 - D.FistBaseShare) * punchProgress
	end
	local blastHold = ctx.BlastHold
	if blastHold then
		local strengths = Tuning.Blast.HoldStrengths
		local basic = math.clamp(blastHold / Tuning.Blast.ChargeTime, 0, 1)
		local progress = holdProgress(blastHold, strengths[#strengths][1])
		fist = math.max(fist, D.FistBaseShare * basic + (1 - D.FistBaseShare) * progress)
	end
	Vfx.drive("Fist", fist)

	updatePreview(ctx, dt)
end

function Drivers.start()
	-- Before the camera rig reads its layers this frame.
	RunService:BindToRenderStep("FallDrivers", Enum.RenderPriority.Camera.Value - 1, update)
end

return Drivers
