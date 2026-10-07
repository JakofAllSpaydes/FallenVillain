--!strict
-- World VFX (spec §4.1–4.3, §4.6, §4.8, §12). Everything is client-only and pooled under the camera, built once
-- at start; nothing is created in the hot path. Ground effects are thin parts carrying a soft decal from the
-- game's own textures (Tuning.Vfx.*Texture) laid flat on the globe, not neon primitives.
-- Layers (held values tweened by FeelTable): CrackRadius, ChestLight, ChargeBeam, Trails.
-- Driven (set per frame by Feel/Drivers): SpeedLines, Embers, Fist, Trails.
-- Spawns (one-shots at a position): Shockwave, Flash3D, DustRing, Dust, Sparks, Debris, Crater, LightColumn.

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Globe = require(Shared.Globe)
local Tuning = require(Shared.Tuning)
local Controller = require(script.Parent.Parent.Movement.Controller)
local MathUtil = require(script.Parent.Parent.Movement.MathUtil)
local Layers = require(script.Parent.Layers)

local Vfx = {}

local layers = Layers.new({ "CrackRadius", "ChestLight", "ChargeBeam", "Trails" })
local driven: { [string]: number } = { SpeedLines = 0, Embers = 0, Fist = 0, Trails = 0 }

local DECAL_LIFT = 0.05 -- keeps flat parts off the ground without z-fighting; not a feel value
local DECAL_THICKNESS = 0.1
local HAND_PARTS = { "RightHand", "Right Arm" } -- R15 first, R6 fallback

-- A flat effect frame on the globe at `position`: Y along up, so a block's Top face lies on the ground.
local function groundFrame(position: Vector3, lift: number): CFrame
	local up = MathUtil.upAt(position)
	return MathUtil.upright(position + up * lift, Vector3.xAxis, up)
end

type Decal2 = { Part: Part, Decal: Decal }
type Shockwave = { Slot: Decal2, Start: number, Duration: number, Radius: number, Alpha: number }
type Flash = { Gui: BillboardGui, Image: ImageLabel, Start: number, Duration: number, Size: number }
type Debris = { Part: Part, Velocity: Vector3, Spin: Vector3, Start: number, Life: number }
type Column = { Beam: Beam, Base: Attachment, Top: Attachment, Start: number, Duration: number, Alpha: number }
type Crater = { Cracks: Decal2, Scorch: Decal2, Start: number, Duration: number }
type DustRing = { Part: Part, Emitter: ParticleEmitter }

local folder: Folder
local crack: Decal2
local crackAnchor: Vector3? = nil
local beam: Beam
local beamBase: Attachment
local beamTop: Attachment
local light: PointLight
local trails: { Trail } = {}
local trailRoot: BasePart? = nil
local dust: ParticleEmitter
local dustAttachment: Attachment
local sparks: ParticleEmitter
local sparksAttachment: Attachment
local pebbles: ParticleEmitter
local pebbleAttachment: Attachment
local speedLines: ParticleEmitter
local embers: ParticleEmitter
local bodyAttachment: Attachment
local bodyRoot: BasePart? = nil
local fistLight: PointLight
local fistMotes: ParticleEmitter
local fistGlow: ImageLabel
local fistAttachment: Attachment
local fistCharacter: Model? = nil

local shockwaves: { Shockwave } = {}
local flashes: { Flash } = {}
local debris: { Debris } = {}
local columns: { Column } = {}
local craters: { Crater } = {}
local dustRings: { DustRing } = {}
local nextShockwave, nextFlash, nextDebris, nextColumn, nextCrater, nextDustRing = 1, 1, 1, 1, 1, 1

local function effectPart(shape: Enum.PartType, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Shape = shape
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = material
	part.Color = color
	part.Transparency = 1
	part.Parent = folder
	return part
end

-- A thin invisible block whose Top face carries a tinted decal.
local function decalPart(texture: string, tint: Color3): Decal2
	local part = effectPart(Enum.PartType.Block, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	local decal = Instance.new("Decal")
	decal.Texture = texture
	decal.Face = Enum.NormalId.Top
	decal.Color3 = tint
	decal.Transparency = 1
	decal.Parent = part
	return { Part = part, Decal = decal }
end

local function placeDecal(slot: Decal2, position: Vector3, radius: number, lift: number)
	slot.Part.Size = Vector3.new(radius * 2, DECAL_THICKNESS, radius * 2)
	slot.Part.CFrame = groundFrame(position, lift)
end

local function terrainAttachment(): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Parent = workspace.Terrain
	return attachment
end

local function emitter(parent: Instance, texture: string, color: Color3): ParticleEmitter
	local item = Instance.new("ParticleEmitter")
	item.Texture = texture
	item.Enabled = false
	item.Rate = 0
	item.Color = ColorSequence.new(color)
	item.Parent = parent
	return item
end

local function glowBillboard(size: number, color: Color3): (BillboardGui, ImageLabel)
	local gui = Instance.new("BillboardGui")
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.Size = UDim2.fromScale(size, size)
	gui.Enabled = false
	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Image = Tuning.Vfx.GlowTexture
	image.ImageColor3 = color
	image.Size = UDim2.fromScale(1, 1)
	image.Parent = gui
	return gui, image
end

function Vfx.groundBelow(position: Vector3): Vector3
	local ctx = Controller.ctx
	local params = if ctx then ctx.RaycastParams else nil
	local hit = Globe.raycast(position, -MathUtil.upAt(position) * Tuning.Vfx.GroundProbe, params)
	return if hit then hit.Position else position
end

-- Where spawns land when the entry doesn't give a position: the ground under the local player.
function Vfx.playerGround(): Vector3?
	local ctx = Controller.ctx
	return if ctx then Vfx.groundBelow(ctx.Root.Position) else nil
end

function Vfx.apply(entry: { [string]: any }, duration: number)
	layers:apply(entry.vfx, entry, duration)
end

-- Per-frame 0–1 for a driven effect (SpeedLines, Embers, Fist, Trails).
function Vfx.drive(name: string, value: number)
	driven[name] = value
end

function Vfx.spawn(entry: { [string]: any }, duration: number, position: Vector3)
	local kind = entry.spawn
	local now = os.clock()
	local V = Tuning.Vfx
	if kind == "Shockwave" then
		local wave = shockwaves[nextShockwave]
		nextShockwave = nextShockwave % #shockwaves + 1
		wave.Start, wave.Duration, wave.Radius, wave.Alpha = now, duration, entry.radius, entry.alpha
		placeDecal(wave.Slot, position, 0.01, DECAL_LIFT * 2)
	elseif kind == "Flash3D" then
		local flash = flashes[nextFlash]
		nextFlash = nextFlash % #flashes + 1
		flash.Start, flash.Duration, flash.Size = now, duration, entry.size
		flash.Gui.StudsOffsetWorldSpace = position + MathUtil.upAt(position) * (entry.lift or 0)
		flash.Gui.Enabled = true
	elseif kind == "DustRing" then
		local ring = dustRings[nextDustRing]
		nextDustRing = nextDustRing % #dustRings + 1
		ring.Part.Size = Vector3.new(entry.radius * 2, 1, entry.radius * 2)
		ring.Part.CFrame = groundFrame(position, 0.5)
		ring.Emitter:Emit(entry.count)
	elseif kind == "Debris" then
		local frame = groundFrame(position, 0)
		for _ = 1, math.min(entry.count, #debris) do
			local piece = debris[nextDebris]
			nextDebris = nextDebris % #debris + 1
			local angle = math.random() * math.pi * 2
			local out = frame:VectorToWorldSpace(Vector3.new(math.cos(angle), entry.upBias, math.sin(angle)).Unit)
			local speed = entry.speedMin + math.random() * (entry.speedMax - entry.speedMin)
			piece.Velocity = out * speed
			piece.Spin = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * (2 * V.DebrisSpin)
			piece.Start, piece.Life = now, entry.life
			piece.Part.CFrame = CFrame.new(position + frame.YVector)
				* CFrame.Angles(math.random() * math.pi * 2, math.random() * math.pi * 2, 0)
			piece.Part.Transparency = 0
		end
	elseif kind == "LightColumn" then
		local column = columns[nextColumn]
		nextColumn = nextColumn % #columns + 1
		column.Base.WorldPosition = position
		column.Top.WorldPosition = position + MathUtil.upAt(position) * entry.height
		column.Beam.Width0, column.Beam.Width1 = entry.width, entry.width
		column.Start, column.Duration, column.Alpha = now, duration, entry.alpha
		column.Beam.Enabled = true
	elseif kind == "Dust" then
		dustAttachment.WorldPosition = position
		dust:Emit(entry.count)
	elseif kind == "Sparks" then
		sparksAttachment.WorldPosition = position
		sparks:Emit(entry.count)
	elseif kind == "Crater" then
		local crater = craters[nextCrater]
		nextCrater = nextCrater % #craters + 1
		crater.Start, crater.Duration = now, duration
		placeDecal(crater.Scorch, position, entry.radius * V.CraterScorchScale, DECAL_LIFT)
		placeDecal(crater.Cracks, position, entry.radius, DECAL_LIFT * 1.5)
		crater.Cracks.Part.CFrame *= CFrame.Angles(0, math.random() * math.pi * 2, 0)
		crater.Scorch.Decal.Transparency = V.CraterScorchTransparency
		crater.Cracks.Decal.Transparency = V.CraterTransparency
	end
end

local function updateCharge(ctx: any)
	local radius = layers:get("CrackRadius")
	if radius > 0.05 and ctx then
		crackAnchor = crackAnchor or Vfx.groundBelow(ctx.Root.Position)
		placeDecal(crack, crackAnchor :: Vector3, radius, DECAL_LIFT)
		crack.Decal.Transparency = Tuning.Vfx.CrackTransparency
		pebbleAttachment.CFrame = CFrame.new(crackAnchor :: Vector3) * MathUtil.transport(Vector3.yAxis, ctx.Up)
		pebbles.Enabled = true
	else
		crackAnchor = nil
		crack.Decal.Transparency = 1
		pebbles.Enabled = false
	end

	local alpha = layers:get("ChargeBeam")
	beam.Enabled = alpha > 0.01 and ctx ~= nil
	if beam.Enabled then
		local ground = Vfx.groundBelow(ctx.Root.Position)
		beamBase.WorldPosition = ground
		beamTop.WorldPosition = ground + ctx.Up * Tuning.Vfx.ChargeBeamHeight
		beam.Transparency = NumberSequence.new(1 - alpha)
	end

	local brightness = layers:get("ChestLight")
	light.Brightness = brightness
	light.Enabled = brightness > 0.01 and ctx ~= nil
	if ctx and light.Parent ~= ctx.Root then
		light.Parent = ctx.Root
	end
end

local function attachTrails(root: BasePart)
	local V = Tuning.Vfx
	for index, side in { -1, 1 } do
		local top = Instance.new("Attachment")
		top.Position = Vector3.new(side * V.TrailSpan, V.TrailWidth / 2, 0)
		top.Parent = root
		local bottom = Instance.new("Attachment")
		bottom.Position = Vector3.new(side * V.TrailSpan, -V.TrailWidth / 2, 0)
		bottom.Parent = root
		local trail = trails[index]
		trail.Attachment0 = top
		trail.Attachment1 = bottom
		trail.Parent = root
	end
	trailRoot = root
end

local function updateTrails(ctx: any)
	if ctx and trailRoot ~= ctx.Root then
		attachTrails(ctx.Root)
	end
	local on = ctx ~= nil and (layers:get("Trails") > 0.01 or driven.Trails >= Tuning.Vfx.TrailSpeedOn)
	for _, trail in trails do
		trail.Enabled = on
	end
end

-- Speed lines and embers stream back off the body; the fist glows on the punching hand.
local function updateDriven(ctx: any)
	local V = Tuning.Vfx
	if ctx and bodyRoot ~= ctx.Root then
		bodyRoot = ctx.Root
		-- +Y of the attachment is the emit direction: point it backward along the body.
		bodyAttachment.CFrame = CFrame.Angles(math.rad(90), 0, 0)
		bodyAttachment.Parent = ctx.Root
	end
	local lines = if ctx then driven.SpeedLines else 0
	speedLines.Rate = V.SpeedLineRate * lines
	speedLines.Enabled = lines > 0.02
	local heat = if ctx then driven.Embers else 0
	embers.Rate = V.EmberRate * heat
	embers.Enabled = heat > 0.02

	if ctx and fistCharacter ~= ctx.Character then
		fistCharacter = ctx.Character
		fistAttachment.Parent = nil
	end
	if ctx and fistAttachment.Parent == nil then
		for _, name in HAND_PARTS do
			local hand = ctx.Character:FindFirstChild(name)
			if hand and hand:IsA("BasePart") then
				fistAttachment.Position = Vector3.new(0, -hand.Size.Y / 2, 0)
				fistAttachment.Parent = hand
				break
			end
		end
	end
	local fist = if ctx then driven.Fist else 0
	fistLight.Brightness = V.FistLight * fist
	fistLight.Enabled = fist > 0.02
	fistMotes.Rate = V.FistRate * fist
	fistMotes.Enabled = fist > 0.02
	local glow = fistGlow.Parent :: BillboardGui
	glow.Enabled = fist > 0.02
	glow.Size = UDim2.fromScale(V.FistGlowSize * (0.5 + 0.5 * fist), V.FistGlowSize * (0.5 + 0.5 * fist))
	fistGlow.ImageTransparency = 1 - fist * V.FistGlowAlpha
end

local function update(dt: number)
	local ctx = Controller.ctx
	local now = os.clock()
	local V = Tuning.Vfx
	updateCharge(ctx)
	updateTrails(ctx)
	updateDriven(ctx)

	for _, wave in shockwaves do
		local p = (now - wave.Start) / wave.Duration
		local decal = wave.Slot.Decal
		if p < 1 then
			-- Expo-out growth: most of the travel in the first frames, then it hangs and fades.
			local grow = 1 - math.exp(-V.ShockwaveSnap * p)
			local radius = math.max(0.01, wave.Radius * grow / (1 - math.exp(-V.ShockwaveSnap)))
			wave.Slot.Part.Size = Vector3.new(radius * 2, DECAL_THICKNESS, radius * 2)
			decal.Transparency = 1 - wave.Alpha * (1 - p) ^ 2
		elseif decal.Transparency < 1 then
			decal.Transparency = 1
		end
	end

	for _, flash in flashes do
		if flash.Gui.Enabled then
			local p = (now - flash.Start) / flash.Duration
			if p >= 1 then
				flash.Gui.Enabled = false
			else
				local size = flash.Size * (1 + (V.FlashGrow - 1) * (1 - (1 - p) ^ 3))
				flash.Gui.Size = UDim2.fromScale(size, size)
				flash.Image.ImageTransparency = 1 - (1 - p) ^ 2
			end
		end
	end

	for _, crater in craters do
		if crater.Cracks.Decal.Transparency < 1 then
			local p = (now - crater.Start) / crater.Duration
			if p >= 1 then
				crater.Cracks.Decal.Transparency = 1
				crater.Scorch.Decal.Transparency = 1
			else
				local fade = p * p
				crater.Cracks.Decal.Transparency = V.CraterTransparency + (1 - V.CraterTransparency) * fade
				crater.Scorch.Decal.Transparency = V.CraterScorchTransparency + (1 - V.CraterScorchTransparency) * fade
			end
		end
	end

	local gravity = Tuning.Gravity.Default
	for _, piece in debris do
		local age = now - piece.Start
		if age < piece.Life then
			local part = piece.Part
			local up = MathUtil.upAt(part.Position)
			piece.Velocity -= up * gravity * dt
			local position = part.Position + piece.Velocity * dt
			-- One bounce off the surface, then it settles.
			local floor = part.Size.Y / 2
			if MathUtil.altitudeAt(position) < floor then
				local vy = piece.Velocity:Dot(up)
				if vy < 0 then
					local level = MathUtil.flat(piece.Velocity, up) * V.DebrisBounceFriction
					piece.Velocity = level - up * vy * V.DebrisBounce
					piece.Spin *= V.DebrisBounceFriction
				end
				position += up * (floor - MathUtil.altitudeAt(position))
			end
			local spin = piece.Spin * dt
			part.CFrame = CFrame.new(position) * (part.CFrame.Rotation * CFrame.Angles(spin.X, spin.Y, spin.Z))
			part.Transparency = math.clamp((age - piece.Life + V.DebrisFade) / V.DebrisFade, 0, 1)
		elseif piece.Part.Transparency < 1 then
			piece.Part.Transparency = 1
		end
	end

	for _, column in columns do
		if column.Beam.Enabled then
			local p = (now - column.Start) / column.Duration
			if p >= 1 then
				column.Beam.Enabled = false
			else
				column.Beam.Transparency = NumberSequence.new(1 - column.Alpha * (1 - p))
			end
		end
	end
end

local function makeBeam(a0: Attachment, a1: Attachment): Beam
	local item = Instance.new("Beam")
	item.Attachment0 = a0
	item.Attachment1 = a1
	item.FaceCamera = true
	item.LightEmission = 1
	item.Segments = 1
	item.Color = ColorSequence.new(Color3.new(1, 1, 1))
	item.Enabled = false
	item.Parent = workspace.Terrain
	return item
end

local function warmFade(color: Color3, tail: Color3): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.3, color),
		ColorSequenceKeypoint.new(1, tail),
	})
end

function Vfx.start()
	local V = Tuning.Vfx
	folder = Instance.new("Folder")
	folder.Name = "FallVfx"
	folder.Parent = workspace.CurrentCamera

	crack = decalPart(V.CrackTexture, V.CrackColor)

	beamBase, beamTop = terrainAttachment(), terrainAttachment()
	beam = makeBeam(beamBase, beamTop)
	beam.Width0, beam.Width1 = V.ChargeBeamWidth, V.ChargeBeamWidth

	light = Instance.new("PointLight")
	light.Range = V.ChestLightRange
	light.Color = V.LightColor
	light.Enabled = false

	for _ = 1, 2 do
		local trail = Instance.new("Trail")
		trail.Lifetime = V.TrailLifetime
		trail.LightEmission = 1
		trail.FaceCamera = true
		trail.Texture = V.StreakTexture
		trail.TextureMode = Enum.TextureMode.Stretch
		trail.Color = ColorSequence.new(V.TrailColor)
		trail.Transparency = NumberSequence.new(V.TrailTransparency, 1)
		trail.WidthScale = NumberSequence.new(1, V.TrailWidthEnd)
		trail.Enabled = false
		table.insert(trails, trail)
	end

	for _ = 1, V.ShockwavePool do
		local slot = decalPart(V.RingTexture, Color3.new(1, 1, 1))
		table.insert(shockwaves, { Slot = slot, Start = 0, Duration = 1, Radius = 0, Alpha = 0 })
	end
	for _ = 1, V.FlashPool do
		local gui, image = glowBillboard(1, V.FlashColor3D)
		gui.Parent = workspace.Terrain
		table.insert(flashes, { Gui = gui, Image = image, Start = 0, Duration = 1, Size = 1 })
	end
	for _ = 1, V.CraterPool do
		table.insert(craters, {
			Scorch = decalPart(V.GlowTexture, V.CraterColor),
			Cracks = decalPart(V.CrackTexture, V.CraterColor),
			Start = 0,
			Duration = 1,
		})
	end
	for _ = 1, V.DebrisPool do
		local part = effectPart(Enum.PartType.Block, V.DebrisColor, Enum.Material.Slate)
		part.Size = Vector3.one * V.DebrisSize
		table.insert(debris, { Part = part, Velocity = Vector3.zero, Spin = Vector3.zero, Start = 0, Life = 0 })
	end
	for _ = 1, V.ColumnPool do
		local base, top = terrainAttachment(), terrainAttachment()
		table.insert(
			columns,
			{ Beam = makeBeam(base, top), Base = base, Top = top, Start = 0, Duration = 1, Alpha = 0 }
		)
	end
	for _ = 1, V.DustRingPool do
		local part = effectPart(Enum.PartType.Block, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
		local ring = emitter(part, V.DustTexture, V.DustColor)
		ring.Shape = Enum.ParticleEmitterShape.Cylinder
		ring.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		ring.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
		ring.ShapePartial = 1
		ring.Lifetime = NumberRange.new(V.DustRingLifetimeMin, V.DustRingLifetimeMax)
		ring.Speed = NumberRange.new(V.DustRingSpeedMin, V.DustRingSpeedMax)
		ring.SpreadAngle = Vector2.new(25, 25)
		ring.Acceleration = Vector3.new(0, V.DustRingRise, 0)
		ring.Drag = V.DustDrag
		ring.Size = NumberSequence.new(V.DustRingSizeStart, V.DustRingSizeEnd)
		ring.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, V.DustTransparency),
			NumberSequenceKeypoint.new(0.4, V.DustTransparency + 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
		ring.Rotation = NumberRange.new(-180, 180)
		ring.RotSpeed = NumberRange.new(-40, 40)
		table.insert(dustRings, { Part = part, Emitter = ring })
	end

	dustAttachment = terrainAttachment()
	dust = emitter(dustAttachment, V.DustTexture, V.DustColor)
	dust.Lifetime = NumberRange.new(V.DustLifetimeMin, V.DustLifetimeMax)
	dust.Speed = NumberRange.new(V.DustSpeedMin, V.DustSpeedMax)
	dust.SpreadAngle = Vector2.new(180, 180)
	dust.Drag = V.DustDrag
	dust.Size = NumberSequence.new(V.DustSizeStart, V.DustSizeEnd)
	dust.Transparency = NumberSequence.new(V.DustTransparency, 1)
	dust.Rotation = NumberRange.new(-180, 180)
	dust.RotSpeed = NumberRange.new(-60, 60)

	sparksAttachment = terrainAttachment()
	sparks = emitter(sparksAttachment, V.StreakTexture, V.SparkColor)
	sparks.LightEmission = 1
	sparks.Color = warmFade(V.SparkColor, V.EmberColor)
	sparks.Lifetime = NumberRange.new(V.SparkLifetimeMin, V.SparkLifetimeMax)
	sparks.Speed = NumberRange.new(V.SparkSpeedMin, V.SparkSpeedMax)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Drag = V.SparkDrag
	sparks.Size = NumberSequence.new(V.SparkSize, 0)
	sparks.Squash = NumberSequence.new(V.SparkSquash)
	sparks.Orientation = Enum.ParticleOrientation.VelocityParallel
	sparks.Transparency = NumberSequence.new(0, 1)
	sparks.Acceleration = Vector3.new(0, -V.SparkGravity, 0)

	pebbleAttachment = terrainAttachment()
	pebbles = emitter(pebbleAttachment, V.DustTexture, V.PebbleColor)
	pebbles.Rate = V.PebbleRate
	pebbles.Lifetime = NumberRange.new(V.PebbleLifetime)
	pebbles.Speed = NumberRange.new(V.PebbleSpeedMin, V.PebbleSpeedMax)
	pebbles.SpreadAngle = Vector2.new(V.PebbleSpread, V.PebbleSpread)
	pebbles.Size = NumberSequence.new(V.PebbleSize)
	pebbles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0),
		NumberSequenceKeypoint.new(0.8, 0),
		NumberSequenceKeypoint.new(1, 1),
	})

	bodyAttachment = Instance.new("Attachment")
	bodyAttachment.Name = "FallBody"
	speedLines = emitter(bodyAttachment, V.StreakTexture, Color3.new(1, 1, 1))
	speedLines.LightEmission = 1
	speedLines.Lifetime = NumberRange.new(V.SpeedLineLifetime)
	speedLines.Speed = NumberRange.new(V.SpeedLineSpeed)
	speedLines.SpreadAngle = Vector2.new(V.SpeedLineSpread, V.SpeedLineSpread)
	speedLines.Size = NumberSequence.new(V.SpeedLineSize)
	speedLines.Squash = NumberSequence.new(V.SpeedLineSquash)
	speedLines.Orientation = Enum.ParticleOrientation.VelocityParallel
	speedLines.Transparency = NumberSequence.new(V.SpeedLineTransparency, 1)
	embers = emitter(bodyAttachment, V.StreakTexture, V.EmberColor)
	embers.LightEmission = 1
	embers.Color = warmFade(V.EmberColor, V.EmberTail)
	embers.Lifetime = NumberRange.new(V.EmberLifetime)
	embers.Speed = NumberRange.new(V.EmberSpeed)
	embers.SpreadAngle = Vector2.new(V.SpeedLineSpread, V.SpeedLineSpread)
	embers.Size = NumberSequence.new(V.EmberSize, 0)
	embers.Squash = NumberSequence.new(V.SparkSquash)
	embers.Orientation = Enum.ParticleOrientation.VelocityParallel
	embers.Transparency = NumberSequence.new(0, 1)

	fistAttachment = Instance.new("Attachment")
	fistAttachment.Name = "FallFist"
	fistLight = Instance.new("PointLight")
	fistLight.Range = V.FistLightRange
	fistLight.Color = V.FistColor
	fistLight.Enabled = false
	fistLight.Parent = fistAttachment
	fistMotes = emitter(fistAttachment, V.GlowTexture, V.FistColor)
	fistMotes.LightEmission = 1
	fistMotes.Lifetime = NumberRange.new(V.FistLifetime)
	fistMotes.Speed = NumberRange.new(V.FistSpeed)
	fistMotes.SpreadAngle = Vector2.new(180, 180)
	fistMotes.Size = NumberSequence.new(V.FistSize, 0)
	fistMotes.Transparency = NumberSequence.new(0, 1)
	local fistGui
	fistGui, fistGlow = glowBillboard(V.FistGlowSize, V.FistColor)
	fistGui.Adornee = fistAttachment
	fistGui.Parent = fistAttachment

	RunService.RenderStepped:Connect(update)
end

return Vfx
