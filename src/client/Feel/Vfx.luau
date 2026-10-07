--!strict
-- Placeholder world VFX (spec §4.1–4.3, §12). Everything is client-only and pooled under the camera, built once
-- at start; nothing is created in the hot path.
-- Layers (held values tweened by FeelTable): CrackRadius, ChestLight, ChargeBeam, Trails.
-- Spawns (one-shots at a position): Shockwave, Debris, LightColumn, Dust.

local RunService = game:GetService("RunService")

local Tuning = require(game:GetService("ReplicatedStorage").Shared.Tuning)
local Controller = require(script.Parent.Parent.Movement.Controller)
local Layers = require(script.Parent.Layers)

local Vfx = {}

local layers = Layers.new({ "CrackRadius", "ChestLight", "ChargeBeam", "Trails" })

local FLAT = CFrame.Angles(0, 0, math.pi / 2) -- cylinder axis is X; lay it flat
local DECAL_LIFT = 0.05 -- keeps flat parts off the ground without z-fighting; not a feel value

type Shockwave = { Part: Part, Start: number, Duration: number, Radius: number, Alpha: number }
type Debris = { Part: Part, Velocity: Vector3, Start: number, Life: number }
type Column = { Beam: Beam, Base: Attachment, Top: Attachment, Start: number, Duration: number, Alpha: number }

local folder: Folder
local crack: Part
local crackAnchor: Vector3? = nil
local beam: Beam
local beamBase: Attachment
local beamTop: Attachment
local light: PointLight
local trails: { Trail } = {}
local trailRoot: BasePart? = nil
local dust: ParticleEmitter
local dustAttachment: Attachment

local shockwaves: { Shockwave } = {}
local debris: { Debris } = {}
local columns: { Column } = {}
local nextShockwave, nextDebris, nextColumn = 1, 1, 1

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

local function terrainAttachment(): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Parent = workspace.Terrain
	return attachment
end

function Vfx.groundBelow(position: Vector3): Vector3
	local ctx = Controller.ctx
	local params = if ctx then ctx.RaycastParams else nil
	local hit = workspace:Raycast(position, -Vector3.yAxis * Tuning.Vfx.GroundProbe, params)
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

function Vfx.spawn(entry: { [string]: any }, duration: number, position: Vector3)
	local kind = entry.spawn
	local now = os.clock()
	if kind == "Shockwave" then
		local slot = shockwaves[nextShockwave]
		nextShockwave = nextShockwave % #shockwaves + 1
		slot.Start, slot.Duration, slot.Radius, slot.Alpha = now, duration, entry.radius, entry.alpha
		slot.Part.CFrame = CFrame.new(position + Vector3.yAxis * DECAL_LIFT) * FLAT
	elseif kind == "Debris" then
		for _ = 1, math.min(entry.count, #debris) do
			local slot = debris[nextDebris]
			nextDebris = nextDebris % #debris + 1
			local angle = math.random() * math.pi * 2
			local out = Vector3.new(math.cos(angle), entry.upBias, math.sin(angle)).Unit
			local speed = entry.speedMin + math.random() * (entry.speedMax - entry.speedMin)
			slot.Velocity = out * speed
			slot.Start, slot.Life = now, entry.life
			slot.Part.CFrame = CFrame.new(position + Vector3.yAxis)
				* CFrame.Angles(math.random() * math.pi * 2, math.random() * math.pi * 2, 0)
			slot.Part.Transparency = 0
		end
	elseif kind == "LightColumn" then
		local slot = columns[nextColumn]
		nextColumn = nextColumn % #columns + 1
		slot.Base.WorldPosition = position
		slot.Top.WorldPosition = position + Vector3.yAxis * entry.height
		slot.Beam.Width0, slot.Beam.Width1 = entry.width, entry.width
		slot.Start, slot.Duration, slot.Alpha = now, duration, entry.alpha
		slot.Beam.Enabled = true
	elseif kind == "Dust" then
		dustAttachment.WorldPosition = position
		dust:Emit(entry.count)
	end
end

local function updateCharge(ctx: any)
	local radius = layers:get("CrackRadius")
	if radius > 0.05 and ctx then
		crackAnchor = crackAnchor or Vfx.groundBelow(ctx.Root.Position)
		crack.Size = Vector3.new(0.1, radius * 2, radius * 2)
		crack.CFrame = CFrame.new((crackAnchor :: Vector3) + Vector3.yAxis * DECAL_LIFT) * FLAT
		crack.Transparency = Tuning.Vfx.CrackTransparency
	else
		crackAnchor = nil
		crack.Transparency = 1
	end

	local alpha = layers:get("ChargeBeam")
	beam.Enabled = alpha > 0.01 and ctx ~= nil
	if beam.Enabled then
		local ground = Vfx.groundBelow(ctx.Root.Position)
		beamBase.WorldPosition = ground
		beamTop.WorldPosition = ground + Vector3.yAxis * Tuning.Vfx.ChargeBeamHeight
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
	local on = layers:get("Trails") > 0.01 and ctx ~= nil
	for _, trail in trails do
		trail.Enabled = on
	end
end

local function update(dt: number)
	local ctx = Controller.ctx
	local now = os.clock()
	updateCharge(ctx)
	updateTrails(ctx)

	for _, wave in shockwaves do
		local p = (now - wave.Start) / wave.Duration
		if p < 1 then
			local radius = wave.Radius * (1 - (1 - p) ^ 2)
			wave.Part.Size = Vector3.new(0.1, radius * 2, radius * 2)
			wave.Part.Transparency = 1 - wave.Alpha * (1 - p)
		elseif wave.Part.Transparency < 1 then
			wave.Part.Transparency = 1
		end
	end

	local gravity = Tuning.Gravity.Default
	for _, piece in debris do
		local age = now - piece.Start
		if age < piece.Life then
			piece.Velocity -= Vector3.yAxis * gravity * dt
			piece.Part.CFrame = piece.Part.CFrame + piece.Velocity * dt
			piece.Part.Transparency =
				math.clamp((age - piece.Life + Tuning.Vfx.DebrisFade) / Tuning.Vfx.DebrisFade, 0, 1)
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

function Vfx.start()
	local V = Tuning.Vfx
	folder = Instance.new("Folder")
	folder.Name = "FallVfx"
	folder.Parent = workspace.CurrentCamera

	crack = effectPart(Enum.PartType.Cylinder, V.CrackColor, Enum.Material.Slate)

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
		trail.Transparency = NumberSequence.new(V.TrailTransparency, 1)
		trail.Enabled = false
		table.insert(trails, trail)
	end

	for _ = 1, V.ShockwavePool do
		local part = effectPart(Enum.PartType.Cylinder, Color3.new(1, 1, 1), Enum.Material.Neon)
		table.insert(shockwaves, { Part = part, Start = 0, Duration = 1, Radius = 0, Alpha = 0 })
	end
	for _ = 1, V.DebrisPool do
		local part = effectPart(Enum.PartType.Block, V.DebrisColor, Enum.Material.Slate)
		part.Size = Vector3.one * V.DebrisSize
		table.insert(debris, { Part = part, Velocity = Vector3.zero, Start = 0, Life = 0 })
	end
	for _ = 1, V.ColumnPool do
		local base, top = terrainAttachment(), terrainAttachment()
		table.insert(
			columns,
			{ Beam = makeBeam(base, top), Base = base, Top = top, Start = 0, Duration = 1, Alpha = 0 }
		)
	end

	dustAttachment = terrainAttachment()
	dust = Instance.new("ParticleEmitter")
	dust.Texture = V.DustTexture
	dust.Enabled = false
	dust.Lifetime = NumberRange.new(V.DustLifetimeMin, V.DustLifetimeMax)
	dust.Speed = NumberRange.new(V.DustSpeedMin, V.DustSpeedMax)
	dust.SpreadAngle = Vector2.new(180, 180)
	dust.Drag = V.DustDrag
	dust.Size = NumberSequence.new(V.DustSizeStart, V.DustSizeEnd)
	dust.Transparency = NumberSequence.new(V.DustTransparency, 1)
	dust.Color = ColorSequence.new(V.DustColor)
	dust.Parent = dustAttachment

	RunService.RenderStepped:Connect(update)
end

return Vfx
