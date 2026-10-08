--!strict
-- Health reveal (spec §4.12, milestone 5): what a destructible you hit but didn't finish shows, from the
-- controller's local damage prediction (Controller.Damaged). On every such hit the object shudders (a decaying
-- rotation about its base, scaled by how hard it resisted) and flashes with a pooled Highlight; at or under
-- Reveal.CrackHealth a crack decal lands on the face you hit; at or under Reveal.LeanHealth the whole object
-- leans away from the hit, further as health runs out. Everything is client-local: pivots are moved with
-- PivotTo on the replicated model (the server never moves them, so the change holds until the break or the
-- rebuild, when Damage.clear restores the pivot and returns the decals and highlight to their pools).

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Tuning = require(Shared.Tuning)

local Controller = require(script.Parent.Parent.Movement.Controller)
local MathUtil = require(script.Parent.Parent.Movement.MathUtil)

local Damage = {}

type Record = {
	Model: Model,
	Pivot: CFrame, -- the undamaged pivot
	Up: Vector3,
	LeanAxis: Vector3, -- rotation axis for the lean and the wobble (level, perpendicular to the hit direction)
	Lean: number, -- degrees the lean is heading to
	LeanCurrent: number,
	WobbleStart: number,
	WobbleAmount: number, -- degrees
	Decals: { Decal },
	Highlight: Highlight?,
	FlashStart: number,
}

local records: { [Model]: Record } = {}
local decalPool: { Decal } = {}
local highlightPool: { Highlight } = {}
local poolFolder: Folder

local FACES = {
	Enum.NormalId.Right,
	Enum.NormalId.Left,
	Enum.NormalId.Top,
	Enum.NormalId.Bottom,
	Enum.NormalId.Back,
	Enum.NormalId.Front,
}

local function takeDecal(): Decal?
	return table.remove(decalPool)
end

local function takeHighlight(): Highlight?
	return table.remove(highlightPool)
end

local function releaseRecord(record: Record)
	for _, decal in record.Decals do
		decal.Parent = poolFolder
		table.insert(decalPool, decal)
	end
	record.Decals = {}
	if record.Highlight then
		record.Highlight.Adornee = nil
		record.Highlight.Enabled = false
		table.insert(highlightPool, record.Highlight)
		record.Highlight = nil
	end
	if record.Model.Parent then
		record.Model:PivotTo(record.Pivot)
	end
end

-- The part of `model` nearest `position`, and the face of it that `position` is in front of.
local function hitFace(model: Model, position: Vector3): (BasePart?, Enum.NormalId)
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local distance = (descendant.Position - position).Magnitude
			if distance < bestDistance then
				best, bestDistance = descendant, distance
			end
		end
	end
	if not best then
		return nil, Enum.NormalId.Front
	end
	local offset = best.CFrame:PointToObjectSpace(position)
	local half = best.Size / 2
	local ratios = {
		offset.X / math.max(half.X, 1e-3),
		-offset.X / math.max(half.X, 1e-3),
		offset.Y / math.max(half.Y, 1e-3),
		-offset.Y / math.max(half.Y, 1e-3),
		offset.Z / math.max(half.Z, 1e-3),
		-offset.Z / math.max(half.Z, 1e-3),
	}
	local face = 1
	for index = 2, 6 do
		if ratios[index] > ratios[face] then
			face = index
		end
	end
	return best, FACES[face]
end

local function onDamaged(model: Model, position: Vector3, left: number, effort: number)
	local R = Tuning.Reveal
	local now = os.clock()
	local record = records[model]
	if not record then
		local pivot = model:GetPivot()
		local up = MathUtil.upAt(pivot.Position)
		record = {
			Model = model,
			Pivot = pivot,
			Up = up,
			LeanAxis = Vector3.xAxis,
			Lean = 0,
			LeanCurrent = 0,
			WobbleStart = -math.huge,
			WobbleAmount = 0,
			Decals = {},
			Highlight = nil,
			FlashStart = -math.huge,
		}
		records[model] = record
	end
	local item = record :: Record
	-- Away from the hit: the direction from the contact to the object's centre, level.
	local away = MathUtil.flat(item.Pivot.Position - position, item.Up)
	if away.Magnitude > 1e-3 then
		item.LeanAxis = item.Up:Cross(away.Unit)
	end
	item.WobbleStart = now
	item.WobbleAmount = R.WobbleDegrees * math.clamp(effort / math.max(R.WobbleFullSpeed, 1e-3), 0.25, 1)
	-- The hit flash.
	local highlight = item.Highlight or takeHighlight()
	if highlight then
		item.Highlight = highlight
		highlight.Adornee = model
		highlight.Enabled = true
		item.FlashStart = now
	end
	-- Cracks on the face you hit.
	if left <= R.CrackHealth and #item.Decals < R.CracksPerObject then
		local part, face = hitFace(model, position)
		local decal = if part then takeDecal() else nil
		if part and decal then
			decal.Face = face
			decal.Parent = part
			table.insert(item.Decals, decal)
		end
	end
	-- The lean, growing as health runs out.
	if left <= R.LeanHealth then
		local depth = 1 - left / math.max(R.LeanHealth, 1e-3)
		item.Lean = R.LeanDegrees + (R.LeanMaxDegrees - R.LeanDegrees) * depth
	end
end

-- The object broke or came back: everything it showed is undone.
function Damage.clear(model: Model)
	local record = records[model]
	if record then
		releaseRecord(record)
		records[model] = nil
	end
end

local function update(dt: number)
	local R = Tuning.Reveal
	local now = os.clock()
	for model, record in records do
		if not model.Parent then
			records[model] = nil
			continue
		end
		-- Flash fade.
		local highlight = record.Highlight
		if highlight then
			local p = (now - record.FlashStart) / math.max(R.FlashTime, 1e-3)
			if p >= 1 then
				highlight.Adornee = nil
				highlight.Enabled = false
				table.insert(highlightPool, highlight)
				record.Highlight = nil
			else
				local fade = (1 - p) ^ 2
				highlight.FillTransparency = 1 - (1 - R.FlashFill) * fade
				highlight.OutlineTransparency = 1 - fade
			end
		end
		-- Lean and wobble about the base.
		record.LeanCurrent = MathUtil.approach(record.LeanCurrent, record.Lean, 1 / math.max(R.LeanTime, 1e-3) * 3, dt)
		local wobble = 0
		local age = now - record.WobbleStart
		if age < R.WobbleTime then
			local p = age / R.WobbleTime
			wobble = record.WobbleAmount * math.exp(-4 * p) * math.sin(2 * math.pi * R.WobbleCycles * p)
		end
		local angle = record.LeanCurrent + wobble
		if math.abs(angle) > 0.01 then
			local base = record.Pivot
			model:PivotTo(CFrame.fromAxisAngle(record.LeanAxis, math.rad(angle)) * base.Rotation + base.Position)
		elseif record.Lean == 0 and #record.Decals == 0 and not record.Highlight and age >= R.WobbleTime then
			-- Nothing left to show: restore and forget it.
			releaseRecord(record)
			records[model] = nil
		end
	end
end

function Damage.start()
	local R = Tuning.Reveal
	poolFolder = Instance.new("Folder")
	poolFolder.Name = "FallDamage"
	poolFolder.Parent = workspace.CurrentCamera
	for _ = 1, R.CrackPool do
		local decal = Instance.new("Decal")
		decal.Texture = Tuning.Vfx.CrackTexture
		decal.Color3 = Tuning.Vfx.CrackColor
		decal.Transparency = R.CrackTransparency
		decal.Parent = poolFolder
		table.insert(decalPool, decal)
	end
	for _ = 1, R.HighlightPool do
		local highlight = Instance.new("Highlight")
		highlight.FillColor = R.FlashColor
		highlight.OutlineColor = R.FlashColor
		highlight.FillTransparency = 1
		highlight.OutlineTransparency = 1
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Enabled = false
		highlight.Parent = poolFolder
		table.insert(highlightPool, highlight)
	end
	Controller.Damaged:Connect(onDamaged)
	RunService.RenderStepped:Connect(update)
end

return Damage
