--!strict
-- Client side of destruction (spec §4.8, §4.12, §15 milestone 4). The server broadcasts each break list with a
-- wave delay per object (distance / Impact.WaveSpeed); this plays it: hides the prefab locally (invisible and
-- unqueryable, so aim and contact rays pass through the rubble), fires the per-family Break feel at it (pitched
-- and sized by the prefab's scale, quieter with distance), and flings pooled chunks copied from the prefab's own
-- parts away from the smash centre. When the server broadcasts Ghosting (Rebuild.GhostTime before a cluster's
-- Rebuilt), each prefab fades back in as a translucent scaffolding ghost rising out of the ground (spec §4.12);
-- Rebuilt snaps the cluster solid with one rebuild chime at its centre and a puff per prefab. Chunks are
-- client-only parts under the camera, integrated by hand (world gravity is zero): one bounce off the globe,
-- then they fade. Past Chunks.Pool alive, breaks are particles only.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Destructibles = require(Shared.Destructibles)
local Net = require(Shared.Net)
local Signal = require(Shared.Signal)
local Tuning = require(Shared.Tuning)

local Controller = require(script.Parent.Parent.Movement.Controller)
local MathUtil = require(script.Parent.Parent.Movement.MathUtil)
local Damage = require(script.Parent.Damage)
local Juice = require(script.Parent.Juice)
local TimeScale = require(script.Parent.TimeScale)

local WHITE = Color3.new(1, 1, 1)

local Destruction = {}

-- (position, cash, combo count, prefab name) each time the server credits one of the local player's breaks
Destruction.Credited = Signal.new() :: Signal.Signal<Vector3, number, number, string>

type Break = { Model: Model, Delay: number, Cash: number, Combo: number }
type Chunk = { Part: Part, Velocity: Vector3, Spin: Vector3, Start: number, Life: number, Color: Color3 }
type Ghost = { Model: Model, At: number, Pivot: CFrame, Up: Vector3, Parts: { BasePart } }

local FAMILY_EVENT = { wood = "BreakWood", stone = "BreakStone", glass = "BreakGlass", metal = "BreakMetal" }

local chunks: { Chunk } = {}
local nextChunk = 1
local folder: Folder
local ghosts: { [Model]: Ghost } = {}
local hidden: { [Model]: boolean } = {} -- prefabs this client has hidden (so a ghost never fades an intact one)

local function partsOf(model: Model): { BasePart }
	local parts: { BasePart } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	return parts
end

local function setHidden(model: Model, hidden: boolean)
	for _, part in partsOf(model) do
		part.LocalTransparencyModifier = if hidden then 1 else 0
		part.CanQuery = not hidden
	end
end

-- A chunk slot whose last life is over, or nil when the budget is spent.
local function freeChunk(now: number): Chunk?
	for _ = 1, #chunks do
		local chunk = chunks[nextChunk]
		nextChunk = nextChunk % #chunks + 1
		if now - chunk.Start >= chunk.Life then
			return chunk
		end
	end
	return nil
end

local function fling(
	model: Model,
	entry: Destructibles.Entry,
	origin: Vector3,
	radius: number,
	contact: number,
	now: number
)
	local C = Tuning.Chunks
	local parts = partsOf(model)
	for index = 1, math.min(entry.Chunks, #parts) do
		local chunk = freeChunk(now)
		if not chunk then
			return
		end
		local source = parts[index]
		local center = source.Position
		local up = MathUtil.upAt(center)
		local away = MathUtil.flat(center - origin, up)
		if away.Magnitude < 1e-3 then
			local angle = math.random() * math.pi * 2
			away = MathUtil.upright(Vector3.zero, Vector3.xAxis, up)
				:VectorToWorldSpace(Vector3.new(math.cos(angle), 0, math.sin(angle)))
		end
		local direction = (away.Unit + up * C.UpBias).Unit
		local distance = (center - origin).Magnitude
		local speed = C.BaseSpeed + math.max(0, radius - distance) * C.SpeedPerStud + contact * C.SpeedByContact
		chunk.Velocity = direction * speed
		local spin = C.Spin + contact * C.SpinByContact
		chunk.Spin = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * (2 * spin)
		chunk.Start, chunk.Life = now, C.Life
		local part = chunk.Part
		part.Size = source.Size * C.SizeScale
		chunk.Color = source.Color
		part.Color = WHITE -- the hit flash: settles to the real colour over Chunks.FlashTime
		part.Material = source.Material
		part.CFrame = source.CFrame
		part.Transparency = 0
	end
end

-- Per-object modifiers for the break feel: bigger prefabs break lower and with more dust; far breaks (other
-- players) arrive quieter.
local function breakMods(model: Model, position: Vector3): Juice.Mods
	local S, A = Tuning.Smash, Tuning.Audio
	local scale = math.max(model:GetScale(), 1e-3)
	local volume = 1
	local ctx = Controller.ctx
	if ctx then
		local distance = (ctx.Root.Position - position).Magnitude
		volume = 1 - math.clamp((distance - A.FalloffStart) / math.max(A.FalloffRange, 1e-3), 0, 1)
	end
	return { pitch = scale ^ -S.PitchBySize, volume = volume, size = scale ^ S.CountBySize }
end

local function breakOne(
	model: Model,
	origin: Vector3,
	radius: number,
	contact: number,
	near: boolean,
	cash: number?,
	combo: number
)
	if not model.Parent then
		return
	end
	local entry = Destructibles.entryOf(model)
	if not entry then
		return
	end
	Damage.clear(model) -- back to the undamaged pivot, so chunks and the ghost start straight
	local pivot = model:GetPivot()
	setHidden(model, true)
	hidden[model] = true
	Controller.resetDamage(model)
	local position = pivot.Position
	local mods = breakMods(model, position)
	-- Every family the prefab is made of plays (glass shatters over the stone crumble), big objects add
	-- BreakBig on top, and a car may pop a moment later (spec §4.12).
	for _, family in entry.Families do
		Juice.fire(FAMILY_EVENT[family] or "BreakStone", position, nil, nil, contact, mods)
	end
	if entry.Value >= Tuning.Smash.BigBreakValue then
		Juice.fire("BreakBig", position, nil, nil, contact, mods)
	end
	if entry.PopChance and math.random() < entry.PopChance then
		task.delay(0.5 + math.random() * 0.5, Juice.fire, "CarPop", position)
	end
	if near then
		fling(model, entry, origin, radius, contact, os.clock())
	end
	if cash then
		local prefab = model:GetAttribute(Destructibles.PrefabAttribute)
		Destruction.Credited:Fire(position, cash, combo, if type(prefab) == "string" then prefab else "")
	end
end

-- The server says this cluster is about to come back: start its ghosts (only for prefabs hidden here).
local function ghostOne(model: Model, now: number)
	if not hidden[model] or not model.Parent then
		return
	end
	local pivot = model:GetPivot()
	ghosts[model] = {
		Model = model,
		At = now,
		Pivot = pivot,
		Up = MathUtil.upAt(pivot.Position),
		Parts = partsOf(model),
	}
end

local function rebuildOne(model: Model)
	local ghost = ghosts[model]
	ghosts[model] = nil
	if ghost and model.Parent then
		model:PivotTo(ghost.Pivot)
	end
	setHidden(model, false)
	hidden[model] = nil
	Controller.resetDamage(model)
	Juice.fire("RebuildOne", model:GetPivot().Position)
end

local function updateGhosts(now: number)
	local R = Tuning.Rebuild
	for model, ghost in ghosts do
		if not model.Parent then
			ghosts[model] = nil
			continue
		end
		if now < ghost.At then
			continue
		end
		local p = math.clamp((now - ghost.At) / math.max(R.GhostTime, 1e-3), 0, 1)
		local ease = 1 - (1 - p) ^ 2
		local pulse = R.GhostPulse * (0.5 + 0.5 * math.sin(now * R.GhostPulseHz * 2 * math.pi))
		local transparency = math.clamp(1 - (1 - R.GhostTransparency) * ease + pulse * ease, 0, 1)
		for _, part in ghost.Parts do
			part.LocalTransparencyModifier = transparency
		end
		model:PivotTo(ghost.Pivot - ghost.Up * (R.GhostRise * (1 - ease)))
	end
end

local function update(dt: number)
	local C = Tuning.Chunks
	local now = os.clock()
	local gravity = Tuning.Gravity.Default
	updateGhosts(now)
	dt *= TimeScale.get() -- the impact freeze holds the chunks in the air too
	for _, chunk in chunks do
		local age = now - chunk.Start
		local part = chunk.Part
		if age < chunk.Life then
			if age < C.FlashTime then
				part.Color = WHITE:Lerp(chunk.Color, age / C.FlashTime)
			elseif part.Color ~= chunk.Color then
				part.Color = chunk.Color
			end
			local up = MathUtil.upAt(part.Position)
			chunk.Velocity -= up * gravity * dt
			local position = part.Position + chunk.Velocity * dt
			local floor = math.min(part.Size.X, part.Size.Y, part.Size.Z) / 2
			if MathUtil.altitudeAt(position) < floor then
				local vy = chunk.Velocity:Dot(up)
				if vy < 0 then
					chunk.Velocity = MathUtil.flat(chunk.Velocity, up) * C.BounceFriction - up * vy * C.Bounce
					chunk.Spin *= C.BounceFriction
				end
				position += up * (floor - MathUtil.altitudeAt(position))
			end
			local spin = chunk.Spin * dt
			part.CFrame = CFrame.new(position) * (part.CFrame.Rotation * CFrame.Angles(spin.X, spin.Y, spin.Z))
			part.Transparency = math.clamp((age - chunk.Life + C.Fade) / C.Fade, 0, 1)
		elseif part.Transparency < 1 then
			part.Transparency = 1
		end
	end
end

function Destruction.start()
	local C = Tuning.Chunks
	folder = Instance.new("Folder")
	folder.Name = "FallChunks"
	folder.Parent = workspace.CurrentCamera
	for _ = 1, C.Pool do
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Transparency = 1
		part.Parent = folder
		table.insert(
			chunks,
			{ Part = part, Velocity = Vector3.zero, Spin = Vector3.zero, Start = -math.huge, Life = 0, Color = WHITE }
		)
	end

	Net.event("Broken").OnClientEvent
		:Connect(function(player: Player, origin: Vector3, radius: number, contact: number, breaks: { Break })
			local isLocal = player == Players.LocalPlayer
			local ctx = Controller.ctx
			local near = isLocal or (ctx ~= nil and (ctx.Root.Position - origin).Magnitude <= C.RemoteRange)
			for _, entry in breaks do
				local model = entry.Model
				if not model then
					continue -- not streamed in here
				end
				local cash = if isLocal then entry.Cash else nil
				if entry.Delay <= 0 then
					breakOne(model, origin, radius, contact, near, cash, entry.Combo)
				else
					task.delay(entry.Delay, breakOne, model, origin, radius, contact, near, cash, entry.Combo)
				end
			end
		end)

	Net.event("Ghosting").OnClientEvent:Connect(function(models: { Model })
		local now = os.clock()
		for _, model in models do
			if model then
				ghostOne(model, now)
			end
		end
	end)

	Net.event("Rebuilt").OnClientEvent:Connect(function(models: { Model })
		-- One chime for the cluster, at its centre; a puff per prefab.
		local sum, count = Vector3.zero, 0
		for _, model in models do
			if model and model.Parent then
				sum += model:GetPivot().Position
				count += 1
				rebuildOne(model)
			end
		end
		if count > 0 then
			Juice.fire("Rebuild", sum / count)
		end
	end)

	RunService.RenderStepped:Connect(update)
end

return Destruction
