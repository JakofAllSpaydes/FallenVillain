--!strict
-- Server-authoritative destruction (spec §9, §13, §15 milestone 4): object health, who broke what, payouts with
-- the altitude and combo multipliers, and rebuild timers. Clients send batches of contacts (Combat/Smash.luau):
-- a Smash (a dive into the ground or a structure: position, speed, dive start altitude, the object touched, the
-- attack force) or a Hit (flying into one object). The server budgets contacts per player, validates each
-- against the replicated character, applies damage in hits (speed / Smash.SpeedPerHit × force, falling off to
-- the radius edge; the object touched takes the full hit, and a punch finishes it outright), and broadcasts
-- each contact's break list with the wave delay per object, so every client plays the same radial destruction
-- wave. Health and value scale with the prefab's size.
--
-- Rebuilds are per cluster (spec §4.12): a section folder (a town, hamlet, forest, grove, landmark) comes back
-- Rebuild.Delay after its last break, all at once (a section under constant attack still returns after
-- Rebuild.MaxWait); loose scatter rebuilds per object. Rebuild.GhostTime before the snap the server broadcasts
-- Ghosting(models) so every client fades the scaffolding ghosts in, then Rebuilt(models).
--
-- The attack force (a dive, a punch) comes from the client and is only clamped (Smash.MaxForceMult); proper
-- validation of it is part of the anti-exploit pass. The client predicts break-through for its own movement;
-- the visible break waits for this broadcast.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Destructibles = require(Shared.Destructibles)
local Net = require(Shared.Net)
local Tuning = require(Shared.Tuning)

local PlayerData = require(script.Parent.PlayerData)

local DestructionAuthority = {}

type Object = {
	Model: Model,
	Entry: Destructibles.Entry,
	Scale: number,
	Health: number,
	Broken: boolean,
}
export type Break = { Model: Model, Delay: number, Cash: number, Combo: number }
type Budget = { Tokens: number, At: number }
-- A cluster's pending rebuild: the objects broken since its last rebuild, when the first of them fell, and a
-- generation that a later break bumps to push the timer back.
type Section = { Broken: { Object }, FirstBreak: number, Generation: number, Pending: boolean }

local objects: { [Model]: Object } = {}
local budgets: { [Player]: Budget } = {}
local sections: { [Instance]: Section } = {}
local overlap = OverlapParams.new()

local brokenEvent: RemoteEvent
local ghostingEvent: RemoteEvent
local rebuiltEvent: RemoteEvent

local function fullHealth(entry: Destructibles.Entry, scale: number): number
	return entry.Health * scale ^ Tuning.Smash.HealthBySize
end

local function register(model: Model)
	local entry = Destructibles.entryOf(model)
	if not entry then
		warn(`[FALL] destructible {model:GetFullName()} has no catalog prefab`)
		return
	end
	local scale = model:GetScale()
	objects[model] = {
		Model = model,
		Entry = entry,
		Scale = scale,
		Health = fullHealth(entry, scale),
		Broken = false,
	}
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Payout for one object (spec §6): value (scaled by size) × altitude multiplier × combo multiplier; the combo
-- is counted first.
local function payout(player: Player, object: Object, fallPeak: number, now: number): (number, number)
	local data = PlayerData.get(player)
	local C, E = Tuning.Combo, Tuning.Economy
	if now > data.ComboEndsAt then
		data.Combo = 0
	end
	data.Combo += 1
	data.ComboEndsAt = now + C.Window
	data.TotalDestroyed += 1
	local altitudeMult = 1 + fallPeak / E.AltitudeMultDivisor
	local comboMult = 1 + C.MultPerHit * math.min(data.Combo, C.MaxCount)
	local cash = object.Entry.Value * object.Scale * altitudeMult * comboMult
	PlayerData.addCash(player, cash)
	return cash, data.Combo
end

-- The cluster an object rebuilds with: its section folder, or itself for loose scatter.
local function sectionKey(model: Model): Instance
	local parent = model.Parent
	local root = Destructibles.folder()
	if parent and parent ~= root and parent.Name ~= "Scatter" then
		return parent
	end
	return model
end

-- Ghosts, then rebuilds, this batch of a cluster's objects.
local function rebuildBatch(batch: { Object })
	local models: { Model } = {}
	for _, object in batch do
		if object.Model.Parent then
			table.insert(models, object.Model)
		end
	end
	if #models > 0 then
		ghostingEvent:FireAllClients(models)
	end
	task.delay(Tuning.Rebuild.GhostTime, function()
		for _, object in batch do
			object.Broken = false
			object.Health = fullHealth(object.Entry, object.Scale)
		end
		if #models > 0 then
			rebuiltEvent:FireAllClients(models)
		end
	end)
end

-- A break joins its cluster's pending rebuild and pushes the timer back to Rebuild.Delay from now, unless the
-- cluster has been under attack since before MaxWait - Delay ago, in which case the running timer stands.
local function scheduleRebuild(object: Object, now: number)
	local R = Tuning.Rebuild
	local key = sectionKey(object.Model)
	local existing = sections[key]
	local item: Section
	if existing and existing.Pending then
		item = existing
	else
		item = { Broken = {}, FirstBreak = now, Generation = 0, Pending = true }
		sections[key] = item
	end
	table.insert(item.Broken, object)
	if item.Generation > 0 and now - item.FirstBreak >= R.MaxWait - R.Delay then
		return -- the standing timer rebuilds everything broken so far
	end
	item.Generation += 1
	local generation = item.Generation
	task.delay(math.max(R.Delay - R.GhostTime, 0), function()
		if item.Generation ~= generation then
			return -- a later break pushed the timer back
		end
		item.Pending = false
		local batch = item.Broken
		item.Broken = {}
		rebuildBatch(batch)
	end)
end

-- Damage every object within `radius` of `origin`, most at the centre; the object touched (`direct`) takes the
-- full hit wherever its centre is. Returns the breaks in wave order. (`punching` is kept for the radius choice
-- upstream; a punch no longer finishes its target outright, health decides.)
local function damageRadius(
	player: Player,
	origin: Vector3,
	radius: number,
	hits: number,
	fallPeak: number,
	direct: Model?,
	punching: boolean
): { Break }
	local S = Tuning.Smash
	local breaks: { Break } = {}
	local now = os.clock()
	local folder = Destructibles.folder()
	if not folder then
		return breaks
	end
	overlap.FilterDescendantsInstances = { folder }
	local seen: { [Model]: boolean } = {}
	local candidates: { Model } = {}
	if direct and objects[direct] then
		table.insert(candidates, direct)
	end
	for _, part in workspace:GetPartBoundsInRadius(origin, radius, overlap) do
		local model = Destructibles.modelOf(part)
		if model then
			table.insert(candidates, model)
		end
	end
	for _, model in candidates do
		local object = objects[model]
		if not object or object.Broken or seen[model] then
			continue
		end
		seen[model] = true
		local distance = (model:GetPivot().Position - origin).Magnitude
		local falloff = 1 - (1 - S.EdgeDamageShare) * math.clamp(distance / math.max(radius, 1e-3), 0, 1)
		object.Health -= hits * (if model == direct then 1 else falloff)
		if object.Health <= 0 then
			object.Broken = true
			local cash, combo = payout(player, object, fallPeak, now)
			table.insert(breaks, {
				Model = model,
				Delay = distance / Tuning.Impact.WaveSpeed,
				Cash = cash,
				Combo = combo,
			})
			scheduleRebuild(object, now)
		end
	end
	table.sort(breaks, function(a, b)
		return a.Delay < b.Delay
	end)
	return breaks
end

local function validNumber(value: unknown, low: number, high: number): number?
	if type(value) ~= "number" or value ~= value or value < low or value > high then
		return nil
	end
	return value
end

-- Token bucket per player: ContactBudgetPerSecond contacts, burstable up to a second's worth.
local function spendBudget(player: Player, now: number, count: number): number
	local rate = Tuning.Net.ContactBudgetPerSecond
	local budget = budgets[player]
	if not budget then
		budget = { Tokens = rate, At = now }
		budgets[player] = budget
	end
	budget.Tokens = math.min(rate, budget.Tokens + (now - budget.At) * rate)
	budget.At = now
	local allowed = math.min(count, math.floor(budget.Tokens))
	budget.Tokens -= allowed
	return allowed
end

-- One contact from a batch. Everything it says is checked against the replicated character.
local function handleContact(player: Player, root: BasePart, item: any)
	if type(item) ~= "table" then
		return
	end
	local S, I, N = Tuning.Smash, Tuning.Impact, Tuning.Net
	local position = item.Position
	local speed = validNumber(item.Speed, S.MinSpeed, N.MaxSpeed)
	if typeof(position) ~= "Vector3" or not speed then
		return
	end
	-- The replicated character trails a fast player by a few frames, so the allowance grows with speed.
	local error = (position - root.Position).Magnitude
	if error > N.MaxPositionError + speed * N.PositionLag then
		if RunService:IsStudio() and Tuning.Dev.TraceMovement then
			warn(string.format("[FALL] contact rejected: %.0f studs from the character at speed %.0f", error, speed))
		end
		return
	end
	local fallPeak = validNumber(item.FallPeak, 0, N.MaxFallPeak) or 0
	local force = validNumber(item.Force, 1, S.MaxForceMult) or 1
	local punching = force >= S.PunchMult
	local hits = speed / S.SpeedPerHit * force

	-- The object touched must actually be where the contact happened: the contact point within HitMaxDistance
	-- of its bounding box (not its pivot, which sits at the base of a tower the player may have hit 100 studs up).
	local touched: Model? = nil
	local model = item.Model
	if typeof(model) == "Instance" and model:IsA("Model") and objects[model] then
		local box, size = model:GetBoundingBox()
		local offset = box:PointToObjectSpace(position)
		local outside = Vector3.new(
			math.max(math.abs(offset.X) - size.X / 2, 0),
			math.max(math.abs(offset.Y) - size.Y / 2, 0),
			math.max(math.abs(offset.Z) - size.Z / 2, 0)
		)
		if outside.Magnitude <= N.HitMaxDistance then
			touched = model
		elseif RunService:IsStudio() and Tuning.Dev.TraceMovement then
			warn(string.format("[FALL] contact rejected: %.0f studs from %s", outside.Magnitude, model.Name))
		end
	end

	local radius: number
	if item.Kind == "Smash" then
		-- A dive into the ground or a structure: everything in the speed radius takes the hit; a plain landing
		-- gets PlainPoundScale of it, a punch (a rocket punch's pound, or a punch held into the dive) all of it.
		radius = (I.RadiusBase + speed / I.RadiusSpeedDivisor) * (if punching then 1 else I.PlainPoundScale)
	elseif item.Kind == "Hit" and touched then
		-- Flying into one object: it takes the hit; a punch also smashes a share of a dive's radius around it.
		radius = if punching
			then (I.RadiusBase + speed / I.RadiusSpeedDivisor) * S.PunchRadiusScale
			else S.ContactRadius
	else
		return
	end
	local breaks = damageRadius(player, position, radius, hits, fallPeak, touched, punching)
	if #breaks > 0 then
		brokenEvent:FireAllClients(player, position, radius, speed, breaks)
	end
end

function DestructionAuthority.start()
	PlayerData.start()
	brokenEvent = Net.event("Broken")
	ghostingEvent = Net.event("Ghosting")
	rebuiltEvent = Net.event("Rebuilt")
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.MaxParts = Tuning.Net.MaxOverlapParts

	for _, instance in CollectionService:GetTagged(Destructibles.Tag) do
		if instance:IsA("Model") and instance:IsDescendantOf(workspace) then
			register(instance)
		end
	end
	CollectionService:GetInstanceAddedSignal(Destructibles.Tag):Connect(function(instance)
		if instance:IsA("Model") and instance:IsDescendantOf(workspace) then
			register(instance)
		end
	end)
	CollectionService:GetInstanceRemovedSignal(Destructibles.Tag):Connect(function(instance)
		if instance:IsA("Model") then
			objects[instance] = nil
			sections[instance] = nil
		end
	end)

	Net.event("Contacts").OnServerEvent:Connect(function(player, batch: unknown)
		if type(batch) ~= "table" then
			return
		end
		local list = batch :: { any }
		local root = rootOf(player)
		if not root then
			return
		end
		local count = math.min(#list, Tuning.Net.MaxContactsPerBatch)
		local allowed = spendBudget(player, os.clock(), count)
		for index = 1, allowed do
			handleContact(player, root, list[index])
		end
	end)

	-- Movement events refill a running combo (tech on the client; a Burst release adds its flight time, clamped
	-- to BurstExtendMax); plain pings are rate-limited here too, and only an open window refills.
	local lastAlive: { [Player]: number } = {}
	Net.event("ComboAlive").OnServerEvent:Connect(function(player, extra: unknown)
		local now = os.clock()
		local bonus = validNumber(extra, 0, Tuning.Combo.BurstExtendMax) or 0
		if bonus <= 0 and now - (lastAlive[player] or -math.huge) < Tuning.Combo.PingInterval * 0.8 then
			return
		end
		lastAlive[player] = now
		local data = PlayerData.get(player)
		if data.Combo > 0 and now <= data.ComboEndsAt then
			data.ComboEndsAt = now + Tuning.Combo.Window + bonus
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		budgets[player] = nil
		lastAlive[player] = nil
	end)
end

return DestructionAuthority
