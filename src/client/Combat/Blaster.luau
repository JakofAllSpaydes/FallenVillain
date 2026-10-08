--!strict
-- Shots, the chain, the beam and the spirit bomb (spec §15 milestone 6). Movement/Blast decides what fires;
-- this flies it:
--   * Shots: pooled glowing orbs with a streak trail, moving straight at Blast.ShotSpeed, swept by a ray each
--     frame; where one lands it smashes (a Blast contact with its strength, through Combat/Smash) and fires
--     BlastHit. Past Blast.MaxRange it fizzles. A chain fires Blast.chainCount of them, bigger, one every
--     ChainInterval with a little spread.
--   * The beam: a bright core and a wide soft glow from the hands to the first thing the aim ray hits (or the
--     hold's range), with a flare at the hit, re-aimed every frame so it sweeps. Every Blast.BeamTickTime it
--     smashes at the hit point for BeamTickShare of its strength; broken objects go unqueryable, so it carves on.
--   * The spirit bomb: while the hold is past the fourth circle, a ball grows above the head; on release it is
--     thrown toward the aim at SpiritSpeed and smashes where it lands with the full strength.
-- Client-only visuals under the camera; the server applies the damage from the contacts. Signals here feed the
-- FeelTable through Juice.

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Destructibles = require(Shared.Destructibles)
local Globe = require(Shared.Globe)
local Progression = require(Shared.Progression)
local Signal = require(Shared.Signal)
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)

local Controller = require(script.Parent.Parent.Movement.Controller)
local Blast = require(script.Parent.Parent.Movement.Blast)
local TimeScale = require(script.Parent.Parent.Feel.TimeScale)
local Smash = require(script.Parent.Smash)

local Blaster = {}

-- (origin) a shot leaves the hands
Blaster.Shot = Signal.new() :: Signal.Signal<Vector3>
-- (origin) the first shot of a chain
Blaster.ChainStarted = Signal.new() :: Signal.Signal<Vector3>
-- (position, strength) a shot or the bomb landed, or a beam tick smashed
Blaster.Hit = Signal.new() :: Signal.Signal<Vector3, number>
-- (position) a beam tick, for the small per-tick feel
Blaster.BeamTick = Signal.new() :: Signal.Signal<Vector3>
Blaster.BeamStarted = Signal.new() :: Signal.Signal<Vector3>
Blaster.BeamEnded = Signal.new() :: Signal.Signal<Vector3>
-- (origin, strength) the spirit bomb leaves the hands
Blaster.SpiritThrown = Signal.new() :: Signal.Signal<Vector3, number>
-- (position, strength) the spirit bomb landed
Blaster.SpiritLanded = Signal.new() :: Signal.Signal<Vector3, number>

type Shot = {
	Part: Part,
	Light: PointLight,
	Trail: Trail,
	Velocity: Vector3,
	Travelled: number,
	Strength: number,
	Active: boolean,
}

local HAND_PARTS = { { "LeftHand", "RightHand" }, { "Left Arm", "Right Arm" } } -- R15 first, R6 fallback
local CORE_SHARE = 0.35 -- the core beam's width relative to the glow; not a feel value
local FLARE_SCALE = 2.6 -- the hit flare's size relative to the beam width
local SPIRIT_CORE_SHARE = 0.55 -- the bomb's bright core relative to its glow shell
local SPIRIT_RANGE_SHARE = 4 -- the thrown bomb flies up to this many shot ranges before fizzling

type Segment = { Core: Part, Shell: Part }

local folder: Folder
local shots: { Shot } = {}
local nextShot = 1
local beamSegments: { Segment } = {} -- the solid cylinder the beam is built from (review note: not a ribbon)
local beamCore: Beam
local beamGlow: Beam
local beamFrom: Attachment
local beamTo: Attachment
local flareGui: BillboardGui
local flare: ImageLabel
local beamActive = false
local beamStrength = 0
local beamWidth = 0
local beamRange = 0
local nextTick = 0
local spiritShell: Part
local spiritCore: Part
local spiritLight: PointLight
local spiritFlying = false
local spiritVelocity = Vector3.zero
local spiritStrength = 0
local spiritRadius = 0
local spiritTravelled = 0

-- Where the blast leaves: between the hands, a little above, or in front of the root.
local function handsOrigin(ctx: Types.Ctx): Vector3
	for _, pair in HAND_PARTS do
		local left = ctx.Character:FindFirstChild(pair[1])
		local right = ctx.Character:FindFirstChild(pair[2])
		if left and right and left:IsA("BasePart") and right:IsA("BasePart") then
			return (left.Position + right.Position) / 2 + ctx.Up * Tuning.Blast.HandLift
		end
	end
	return ctx.Root.Position + ctx.LookDirection * 2
end

local function smashAt(position: Vector3, strength: number, instance: Instance?)
	Smash.queueBlast(position, strength, Destructibles.modelOf(instance))
	Blaster.Hit:Fire(position, strength)
end

local function launchShot(origin: Vector3, direction: Vector3, strength: number, size: number)
	local shot = shots[nextShot]
	nextShot = nextShot % #shots + 1
	shot.Active = true
	shot.Travelled = 0
	shot.Strength = strength
	shot.Velocity = direction * Tuning.Blast.ShotSpeed
	shot.Part.Size = Vector3.one * size
	shot.Part.CFrame = CFrame.new(origin)
	shot.Part.Transparency = 0
	shot.Light.Enabled = true
	shot.Trail.Enabled = true
	Blaster.Shot:Fire(origin)
end

-- A direction nudged by up to `degrees` in a random direction.
local function scatter(direction: Vector3, degrees: number): Vector3
	local angle = math.random() * math.pi * 2
	local tilt = math.rad(degrees) * math.sqrt(math.random())
	local frame = CFrame.lookAlong(Vector3.zero, direction)
	return (frame * CFrame.Angles(0, 0, angle) * CFrame.Angles(tilt, 0, 0)).LookVector
end

local function setSpirit(position: Vector3, radius: number, visible: boolean, spin: number)
	spiritShell.Size = Vector3.one * (radius * 2)
	spiritCore.Size = Vector3.one * (radius * 2 * SPIRIT_CORE_SHARE)
	spiritShell.CFrame = CFrame.new(position) * CFrame.Angles(0, spin, 0)
	spiritCore.Position = position
	spiritShell.Transparency = if visible then Tuning.Vfx.SpiritShellTransparency else 1
	spiritCore.Transparency = if visible then 0 else 1
	spiritLight.Enabled = visible
	spiritLight.Range = radius * 3
end

-- Where the charging bomb hangs: above the head by its own radius.
local function spiritHome(ctx: Types.Ctx, radius: number): Vector3
	return ctx.Root.Position + ctx.Up * (ctx.StandHeight + Tuning.Blast.SpiritHeight + radius)
end

local function spiritRadiusFor(hold: number): number
	local L = Tuning.Blast
	local radius = L.SpiritStartRadius + (L.SpiritMaxRadius - L.SpiritStartRadius) * Blast.spiritProgress(hold)
	return math.min(radius, L.SpiritCapRadius)
end

-- Lays the beam's cylinder segments along origin → endPoint at `width`, or hides them.
local function placeBeam(origin: Vector3?, endPoint: Vector3?, width: number)
	if not origin or not endPoint then
		for _, segment in beamSegments do
			segment.Core.Transparency = 1
			segment.Shell.Transparency = 1
		end
		return
	end
	local span = endPoint - origin
	local length = span.Magnitude
	if length < 1e-3 then
		return
	end
	local direction = span / length
	local count = #beamSegments
	local each = length / count
	for index, segment in beamSegments do
		local center = origin + direction * (each * (index - 0.5))
		-- A cylinder's axis is X: look along the beam, then turn X onto it.
		local frame = CFrame.lookAlong(center, direction) * CFrame.Angles(0, math.rad(90), 0)
		segment.Shell.Size = Vector3.new(each, width, width)
		segment.Shell.CFrame = frame
		segment.Shell.Transparency = Tuning.Vfx.BeamShellTransparency
		segment.Core.Size = Vector3.new(each, width * CORE_SHARE, width * CORE_SHARE)
		segment.Core.CFrame = frame
		segment.Core.Transparency = 0
	end
end

local function fire(kind: Blast.Kind, hold: number, direction: Vector3, strength: number)
	local ctx = Controller.ctx
	if not ctx then
		return
	end
	local L = Tuning.Blast
	local origin = handsOrigin(ctx)
	if kind == "Shot" then
		launchShot(origin, direction, strength, L.ShotSize)
	elseif kind == "Chain" then
		local count = Blast.chainCount(hold)
		Blaster.ChainStarted:Fire(origin)
		for index = 1, count do
			task.delay((index - 1) * L.ChainInterval, function()
				local now = Controller.ctx
				if not now then
					return
				end
				-- Each shot leaves the hands as they are now, toward the aim as it is now, with a little spread.
				local from = handsOrigin(now)
				local toAim = now.AimPoint - from
				local aim = if toAim.Magnitude > 1e-3 then toAim.Unit else direction
				launchShot(from, scatter(aim, L.ChainSpread), strength * L.ChainShotShare, L.ChainShotSize)
			end)
		end
	elseif kind == "Beam" then
		beamActive = true
		beamStrength = strength
		beamWidth = Blast.beamWidthFor(hold)
		beamRange = Blast.beamRangeFor(hold)
		nextTick = os.clock()
		beamCore.Enabled = true
		beamGlow.Enabled = true
		flareGui.Enabled = true
		Blaster.BeamStarted:Fire(origin)
	elseif kind == "Spirit" then
		spiritRadius = spiritRadiusFor(hold)
		spiritStrength = strength
		spiritFlying = true
		spiritTravelled = 0
		-- Fast enough to land within SpiritFlightTime wherever the aim is (review note: it arrived late).
		local distance = (ctx.AimPoint - ctx.Root.Position).Magnitude
		spiritVelocity = direction * math.max(L.SpiritSpeed, distance / math.max(L.SpiritFlightTime, 1e-3))
		local start = spiritHome(ctx, spiritRadius)
		setSpirit(start, spiritRadius, true, 0)
		Blaster.SpiritThrown:Fire(start, strength)
	end
end

local function endBeam(ctx: Types.Ctx?)
	beamActive = false
	beamCore.Enabled = false
	beamGlow.Enabled = false
	flareGui.Enabled = false
	placeBeam(nil, nil, 0)
	Blaster.BeamEnded:Fire(if ctx then handsOrigin(ctx) else Vector3.zero)
end

local function updateShots(dt: number, ctx: Types.Ctx?)
	local L = Tuning.Blast
	local params = if ctx then ctx.RaycastParams else nil
	for _, shot in shots do
		if not shot.Active then
			continue
		end
		local from = shot.Part.Position
		local step = shot.Velocity * dt
		local reach = step + shot.Velocity.Unit * (shot.Part.Size.X / 2)
		local hit = Globe.raycast(from, reach, params)
		if hit then
			smashAt(hit.Position, shot.Strength, hit.Instance)
			shot.Active = false
		else
			shot.Travelled += step.Magnitude
			shot.Part.CFrame = CFrame.new(from + step)
			if shot.Travelled >= L.MaxRange then
				shot.Active = false
			end
		end
		if not shot.Active then
			shot.Part.Transparency = 1
			shot.Light.Enabled = false
			shot.Trail.Enabled = false
		end
	end
end

local function updateBeam(now: number, ctx: Types.Ctx?)
	if not beamActive then
		return
	end
	if not ctx or now >= ctx.BeamUntil then
		endBeam(ctx)
		return
	end
	local L = Tuning.Blast
	local origin = handsOrigin(ctx)
	local toAim = ctx.AimPoint - origin
	local direction = if toAim.Magnitude > 1e-3 then toAim.Unit else ctx.LookDirection
	local hit = Globe.raycast(origin, direction * beamRange, ctx.RaycastParams)
	local endPoint = if hit then hit.Position else origin + direction * beamRange
	beamFrom.WorldPosition = origin
	beamTo.WorldPosition = endPoint
	-- The solid cylinder carries the shape; the ribbons are a soft halo around it.
	placeBeam(origin, endPoint, beamWidth)
	local halo = beamWidth * Tuning.Vfx.BeamHaloScale
	beamGlow.Width0, beamGlow.Width1 = halo, halo
	beamCore.Width0, beamCore.Width1 = beamWidth * 0.6, beamWidth * 0.6
	flareGui.StudsOffsetWorldSpace = endPoint
	local size = beamWidth * FLARE_SCALE
	flareGui.Size = UDim2.fromScale(size, size)
	flareGui.Enabled = hit ~= nil
	if hit and now >= nextTick then
		nextTick = now + L.BeamTickTime
		smashAt(hit.Position, beamStrength * L.BeamTickShare, hit.Instance)
		Blaster.BeamTick:Fire(hit.Position)
	end
end

-- The bomb: charging above the head while the hold is past the fourth circle, or flying after the throw.
local function updateSpirit(dt: number, now: number, ctx: Types.Ctx?)
	local L = Tuning.Blast
	if spiritFlying then
		local from = spiritCore.Position
		local step = spiritVelocity * dt
		local reach = step + spiritVelocity.Unit * spiritRadius
		local hit = Globe.raycast(from, reach, if ctx then ctx.RaycastParams else nil)
		if hit then
			smashAt(hit.Position, spiritStrength, hit.Instance)
			Blaster.SpiritLanded:Fire(hit.Position, spiritStrength)
			spiritFlying = false
			setSpirit(from, spiritRadius, false, 0)
		else
			spiritTravelled += step.Magnitude
			setSpirit(from + step, spiritRadius, true, now * L.SpiritSpin)
			if spiritTravelled >= L.MaxRange * SPIRIT_RANGE_SHARE then
				spiritFlying = false
				setSpirit(from, spiritRadius, false, 0)
			end
		end
		return
	end
	local hold = if ctx then Blast.cappedHold(ctx) else nil
	if ctx and hold and hold >= Progression.circleEnds("Blast")[4] then
		local radius = spiritRadiusFor(hold)
		setSpirit(spiritHome(ctx, radius), radius, true, now * L.SpiritSpin)
	elseif spiritLight.Enabled then
		setSpirit(spiritCore.Position, spiritRadius, false, 0)
	end
end

local function update(dt: number)
	local ctx = Controller.ctx
	local now = os.clock()
	dt *= TimeScale.get() -- the impact freeze holds the shots too
	updateShots(dt, ctx)
	updateBeam(now, ctx)
	updateSpirit(dt, now, ctx)
end

local function makeBeam(width: number, color: Color3, transparency: number): Beam
	local beam = Instance.new("Beam")
	beam.Attachment0 = beamFrom
	beam.Attachment1 = beamTo
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Segments = 1
	beam.Width0, beam.Width1 = width, width
	beam.Color = ColorSequence.new(color)
	beam.Transparency = NumberSequence.new(transparency)
	beam.Enabled = false
	beam.Parent = workspace.Terrain
	return beam
end

local function orb(size: number, color: Color3, transparency: number): Part
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * size
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = transparency
	part.Parent = folder
	return part
end

function Blaster.start()
	local L, V = Tuning.Blast, Tuning.Vfx
	folder = Instance.new("Folder")
	folder.Name = "FallBlaster"
	folder.Parent = workspace.CurrentCamera

	for _ = 1, L.ShotPool do
		local part = orb(L.ShotSize, V.BlastCoreColor, 1)
		local light = Instance.new("PointLight")
		light.Color = V.BlastColor
		light.Brightness = V.ShotLight
		light.Range = V.ShotLightRange
		light.Enabled = false
		light.Parent = part
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, L.ShotSize / 2, 0)
		a0.Parent = part
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -L.ShotSize / 2, 0)
		a1.Parent = part
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.FaceCamera = true
		trail.LightEmission = 1
		trail.Texture = V.StreakTexture
		trail.TextureMode = Enum.TextureMode.Stretch
		trail.Lifetime = V.ShotTrailLifetime
		trail.Color = ColorSequence.new(V.BlastColor)
		trail.Transparency = NumberSequence.new(0.1, 1)
		trail.WidthScale = NumberSequence.new(1, 0.2)
		trail.Enabled = false
		trail.Parent = part
		table.insert(shots, {
			Part = part,
			Light = light,
			Trail = trail,
			Velocity = Vector3.zero,
			Travelled = 0,
			Strength = 0,
			Active = false,
		})
	end

	beamFrom = Instance.new("Attachment")
	beamFrom.Parent = workspace.Terrain
	beamTo = Instance.new("Attachment")
	beamTo.Parent = workspace.Terrain
	beamGlow = makeBeam(4, V.BlastColor, V.BeamGlowTransparency)
	beamCore = makeBeam(1.4, V.BlastCoreColor, V.BeamGlowTransparency)
	beamCore.ZOffset = 0.1
	for _ = 1, L.BeamSegments do
		local shell = orb(1, V.BlastColor, 1)
		shell.Shape = Enum.PartType.Cylinder
		local core = orb(1, V.BlastCoreColor, 1)
		core.Shape = Enum.PartType.Cylinder
		table.insert(beamSegments, { Core = core, Shell = shell })
	end

	flareGui = Instance.new("BillboardGui")
	flareGui.AlwaysOnTop = false
	flareGui.LightInfluence = 0
	flareGui.Size = UDim2.fromScale(1, 1)
	flareGui.Enabled = false
	flareGui.Parent = workspace.Terrain
	flare = Instance.new("ImageLabel")
	flare.BackgroundTransparency = 1
	flare.Image = V.GlowTexture
	flare.ImageColor3 = V.BlastCoreColor
	flare.Size = UDim2.fromScale(1, 1)
	flare.Parent = flareGui

	spiritShell = orb(1, V.BlastColor, 1)
	spiritShell.Material = Enum.Material.ForceField
	spiritCore = orb(1, V.BlastCoreColor, 1)
	spiritLight = Instance.new("PointLight")
	spiritLight.Color = V.BlastColor
	spiritLight.Brightness = V.SpiritLight
	spiritLight.Enabled = false
	spiritLight.Parent = spiritCore

	Blast.Fired:Connect(fire)
	RunService.RenderStepped:Connect(update)
end

return Blaster
