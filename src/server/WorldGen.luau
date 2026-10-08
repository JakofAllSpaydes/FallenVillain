--!strict
-- World generation (spec §5, §13, §15 milestone 4). At server start the prefab templates built in Studio
-- (ServerStorage.Prefabs: one Model per Destructibles.Catalog entry, plus the non-destructible CliffRock) are
-- cloned over the whole globe from one seed: a town a fixed distance from the altar (the first target), then
-- towns, hamlets, forests and cliffs at random well-spaced spots, then loose trees and rocks everywhere between.
-- The seed is Dev.WorldSeed, or a new one per server, and is printed so a layout can be reproduced (§13).
-- Everything lands under workspace.World.Destructibles (sections in their own folders) and World.Cliffs.

local ServerStorage = game:GetService("ServerStorage")

local Shared = game:GetService("ReplicatedStorage").Shared
local Destructibles = require(Shared.Destructibles)
local Planet = require(Shared.Planets.Planet1)
local Tuning = require(Shared.Tuning)

local WorldGen = {}

local TEMPLATES = "Prefabs"
local CLIFF_ROCK = "CliffRock"
local CLIFF_HEIGHT = 36 -- the CliffRock template's height; its top carries the mast

local rng: Random
local templates: Folder
local placed = 0
local centers: { Vector3 } = {} -- section centre directions, for spacing

-- Frame on the surface in direction `dir` (Y up) at `altitude`, turned by `yaw`.
local function surfaceFrame(dir: Vector3, altitude: number, yaw: number): CFrame
	local up = dir.Unit
	local ref = if math.abs(up.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis
	local right = up:Cross(ref).Unit
	return CFrame.fromMatrix(Planet.Center + up * (Planet.Radius + altitude), right, up) * CFrame.Angles(0, yaw, 0)
end

-- Direction for an offset (u right, v forward) in studs from a centre direction.
local function offsetDir(center: Vector3, u: number, v: number): Vector3
	local frame = surfaceFrame(center, 0, 0)
	return (frame.Position + frame.RightVector * u + frame.LookVector * v - Planet.Center).Unit
end

-- Surface distance between two directions.
local function distance(a: Vector3, b: Vector3): number
	return math.acos(math.clamp(a.Unit:Dot(b.Unit), -1, 1)) * Planet.Radius
end

-- Clones a template onto the surface at its own random size (WorldGen.Scale) unless `scale` is given.
local function place(name: string, parent: Instance, dir: Vector3, altitude: number, yaw: number, scale: number?)
	local template = templates:FindFirstChild(name)
	if not template or not template:IsA("Model") then
		warn(`[FALL] no prefab template {name}`)
		return
	end
	local model = template:Clone()
	local range = Tuning.WorldGen.Scale[name]
	local size = scale or (if range then rng:NextNumber(range[1], range[2]) else 1)
	if size ~= 1 then
		model:ScaleTo(size)
	end
	model:PivotTo(surfaceFrame(dir, altitude, yaw))
	model.Parent = parent
	placed += 1
	if placed % Tuning.WorldGen.YieldEvery == 0 then
		task.wait()
	end
end

local function folder(name: string, parent: Instance): Folder
	local item = Instance.new("Folder")
	item.Name = name
	item.Parent = parent
	return item
end

-- Town: a random-sized grid, towers nearest the centre, then shops, then houses; cars and lamps along the
-- streets between the rows.
local function town(parent: Instance, center: Vector3)
	local W = Tuning.WorldGen
	local cols = rng:NextInteger(W.TownColsMin, W.TownColsMax)
	local rows = rng:NextInteger(W.TownRowsMin, W.TownRowsMax)
	local slots = {}
	for col = 0, cols - 1 do
		for row = 0, rows - 1 do
			table.insert(slots, { (col - (cols - 1) / 2) * W.TownSpacing, (row - (rows - 1) / 2) * W.TownStreet })
		end
	end
	table.sort(slots, function(a, b)
		return a[1] ^ 2 + a[2] ^ 2 < b[1] ^ 2 + b[2] ^ 2
	end)
	local total = #slots
	local towers = math.max(1, math.round(total * W.TownTowerShare))
	local shops = math.round(total * W.TownShopShare)
	local skyscraper = rng:NextNumber() < W.TownSkyscraperChance
	for index, slot in slots do
		local kind = if index == 1 and skyscraper
			then "Skyscraper"
			elseif index <= towers then "Tower"
			elseif index <= towers + shops then "Shop"
			else "SmallHouse"
		local scale = if kind == "Skyscraper"
			then rng:NextNumber(W.TownSkyscraperScale[1], W.TownSkyscraperScale[2])
			else nil
		place(kind, parent, offsetDir(center, slot[1], slot[2]), 0, rng:NextInteger(0, 3) * math.pi / 2, scale)
	end
	local street = W.TownStreet
	local halfWidth = (cols - 1) / 2 * W.TownSpacing
	for _ = 1, math.round(total * W.TownCarsPerSlot) do
		local row = rng:NextInteger(0, rows - 2) - (rows - 1) / 2 + 0.5
		local u = rng:NextNumber(-halfWidth, halfWidth)
		place("Car", parent, offsetDir(center, u, row * street), 0, rng:NextNumber(-0.15, 0.15))
	end
	for _ = 1, math.round(total * W.TownLampsPerSlot) do
		local row = rng:NextInteger(0, rows - 2) - (rows - 1) / 2 + 0.5
		local u = rng:NextNumber(-halfWidth, halfWidth)
		place("Lamp", parent, offsetDir(center, u, row * street + (if rng:NextNumber() < 0.5 then -10 else 10)), 0, 0)
	end
end

-- Hamlet: a loose ring of houses with fences around, sometimes a windmill in the middle.
local function hamlet(parent: Instance, center: Vector3)
	if rng:NextNumber() < Tuning.WorldGen.HamletWindmillChance then
		place("Windmill", parent, center, 0, rng:NextNumber(0, math.pi * 2))
	end
	for index = 1, 7 do
		local a = (index - 1) / 7 * math.pi * 2
		place("SmallHouse", parent, offsetDir(center, math.cos(a) * 45, math.sin(a) * 45), 0, -a + math.pi / 2)
	end
	for index = 1, 10 do
		local a = (index - 0.5) / 10 * math.pi * 2
		place("Fence", parent, offsetDir(center, math.cos(a) * 70, math.sin(a) * 70), 0, -a)
	end
end

local function tree(parent: Instance, dir: Vector3)
	place("Tree", parent, dir, 0, rng:NextNumber(0, math.pi * 2))
end

local function rock(parent: Instance, dir: Vector3)
	place("Rock", parent, dir, 0, rng:NextNumber(0, math.pi * 2))
end

-- Forest: trees and rocks scattered over ForestSize × 0.75 ForestSize.
local function forest(parent: Instance, center: Vector3)
	local W = Tuning.WorldGen
	local half = W.ForestSize / 2
	for _ = 1, W.ForestTrees do
		tree(parent, offsetDir(center, rng:NextNumber(-half, half), rng:NextNumber(-half * 0.75, half * 0.75)))
	end
	for _ = 1, W.ForestRocks do
		rock(parent, offsetDir(center, rng:NextNumber(-half, half) * 1.1, rng:NextNumber(-half * 0.8, half * 0.8)))
	end
end

-- Grove: a small clump of trees with a rock or two, the in-between cluster.
local function grove(parent: Instance, center: Vector3)
	local W = Tuning.WorldGen
	local half = W.GroveSize / 2
	for _ = 1, rng:NextInteger(W.GroveTreesMin, W.GroveTreesMax) do
		local a, r = rng:NextNumber(0, math.pi * 2), math.sqrt(rng:NextNumber(0, 1)) * half
		tree(parent, offsetDir(center, math.cos(a) * r, math.sin(a) * r))
	end
	for _ = 1, rng:NextInteger(0, 2) do
		local a, r = rng:NextNumber(0, math.pi * 2), math.sqrt(rng:NextNumber(0, 1)) * half
		rock(parent, offsetDir(center, math.cos(a) * r, math.sin(a) * r))
	end
end

-- Landmark: one big silhouette alone with a ring of lamps, scaled by its size.
local function landmark(parent: Instance, center: Vector3)
	local W = Tuning.WorldGen
	local kind = W.LandmarkKinds[rng:NextInteger(1, #W.LandmarkKinds)]
	local range = W.Scale[kind]
	local size = if range then rng:NextNumber(range[1], range[2]) else 1
	place(kind, parent, center, 0, rng:NextNumber(0, math.pi * 2), size)
	local ring = W.LandmarkLampRing * size
	for index = 1, W.LandmarkLamps do
		local a = (index - 1) / W.LandmarkLamps * math.pi * 2
		place("Lamp", parent, offsetDir(center, math.cos(a) * ring, math.sin(a) * ring), 0, 0)
	end
end

-- Cliff: a raised rock (not destructible; the controller stands on queryable parts) with a mast on top.
local function cliff(parent: Instance, cliffs: Instance, center: Vector3)
	local yaw = rng:NextNumber(0, math.pi * 2)
	place(CLIFF_ROCK, cliffs, center, 0, yaw, 1)
	place("RadioMast", parent, offsetDir(center, 10, -10), CLIFF_HEIGHT - 2, 0)
end

-- A random spot at least `clear` from every section centre and AltarClear from the altar, or nil after 60 tries.
local function sectionSpot(clear: number): Vector3?
	local W = Tuning.WorldGen
	for _ = 1, 60 do
		local dir = rng:NextUnitVector()
		if distance(dir, Vector3.yAxis) < W.AltarClear + W.FirstTownDistance then
			continue
		end
		local free = true
		for _, other in centers do
			if distance(dir, other) < clear then
				free = false
				break
			end
		end
		if free then
			return dir
		end
	end
	return nil
end

local function section(kind: string, index: number, parent: Instance, cliffs: Instance, dir: Vector3)
	table.insert(centers, dir)
	local area = folder(`{kind}{index}`, parent)
	if kind == "Town" then
		town(area, dir)
	elseif kind == "Hamlet" then
		hamlet(area, dir)
	elseif kind == "Forest" then
		forest(area, dir)
	elseif kind == "Grove" then
		grove(area, dir)
	elseif kind == "Landmark" then
		landmark(area, dir)
	elseif kind == "Cliff" then
		cliff(area, cliffs, dir)
	end
end

function WorldGen.generate()
	local W = Tuning.WorldGen
	local seed = if Tuning.Dev.WorldSeed ~= 0 then Tuning.Dev.WorldSeed else os.time() % 1000000
	rng = Random.new(seed)
	print(`[FALL] world seed {seed}`)

	local found = ServerStorage:FindFirstChild(TEMPLATES)
	assert(found and found:IsA("Folder"), "ServerStorage.Prefabs is missing; build the templates in Studio")
	templates = found

	local world = workspace:WaitForChild("World")
	for _, name in { Destructibles.FolderName, "Cliffs" } do
		local old = world:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local root = folder(Destructibles.FolderName, world)
	local cliffs = folder("Cliffs", world)

	-- The first town: always the first target, a fixed distance from the altar in a random direction.
	local angle = rng:NextNumber(0, math.pi * 2)
	section(
		"Town",
		1,
		root,
		cliffs,
		offsetDir(Vector3.yAxis, math.cos(angle) * W.FirstTownDistance, math.sin(angle) * W.FirstTownDistance)
	)
	-- Big sections keep SectionClear apart; groves squeeze into the gaps with GroveClear.
	local plan: { { any } } = {
		{ "Town", W.Towns - 1, W.SectionClear },
		{ "Hamlet", W.Hamlets, W.SectionClear },
		{ "Forest", W.Forests, W.SectionClear },
		{ "Cliff", W.Cliffs, W.SectionClear },
		{ "Landmark", W.Landmarks, W.SectionClear },
		{ "Grove", W.Groves, W.GroveClear },
	}
	local counts: { [string]: number } = { Town = 1 }
	local busy: { Vector3 } = { centers[1] } -- town and hamlet centres the scatter keeps clear of
	for _, item in plan do
		local kind, count, clear = item[1], item[2], item[3]
		for _ = 1, count do
			local dir = sectionSpot(clear)
			if not dir then
				break
			end
			counts[kind] = (counts[kind] or 0) + 1
			section(kind, counts[kind], root, cliffs, dir)
			if kind == "Town" or kind == "Hamlet" then
				table.insert(busy, dir)
			end
		end
	end

	-- The scatter: loose trees and rocks everywhere, clear of the altar and of town and hamlet centres.
	local scatter = folder("Scatter", root)
	local function scatterSpot(): Vector3?
		for _ = 1, 10 do
			local dir = rng:NextUnitVector()
			if distance(dir, Vector3.yAxis) < W.AltarClear then
				continue
			end
			local clear = true
			for _, center in busy do
				if distance(dir, center) < W.ScatterClear then
					clear = false
					break
				end
			end
			if clear then
				return dir
			end
		end
		return nil
	end
	for _ = 1, W.ScatterTrees do
		local dir = scatterSpot()
		if dir then
			tree(scatter, dir)
		end
	end
	for _ = 1, W.ScatterRocks do
		local dir = scatterSpot()
		if dir then
			rock(scatter, dir)
		end
	end
	print(`[FALL] world generated: {placed} prefabs, {#centers} sections`)
end

return WorldGen
