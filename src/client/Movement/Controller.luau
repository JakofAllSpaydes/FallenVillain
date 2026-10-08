--!strict
-- Movement state machine (spec §9, §10, §15 milestone 3). Owns the shared context, runs the current state in
-- PreSimulation, hands its velocity to physics, and fires StateChanged for everything else. States never touch
-- effects; they only return the next state.
--
-- The world is a globe. World gravity is zero (every state integrates its own gravity along ctx.Up) and the
-- character's frame rolls with the planet: each frame the velocity, heading and body direction are rotated by
-- the change in "up" since the last frame (parallel transport), so level flight follows the curve of the
-- planet. A fast flat punch circles the globe instead of flying off it.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Destructibles = require(Shared.Destructibles)
local Globe = require(Shared.Globe)
local Planet = require(Shared.Planets.Planet1)
local Signal = require(Shared.Signal)
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)

local Aim = require(script.Parent.Aim)
local Input = require(script.Parent.Input)
local JumpCheck = require(script.Parent.JumpCheck)
local MathUtil = require(script.Parent.MathUtil)
local Punch = require(script.Parent.Punch)
local TimeScale = require(script.Parent.Parent.Feel.TimeScale)

local States: { [Types.MovementState]: Types.StateModule } = {
	Grounded = require(script.Parent.States.Grounded),
	Charging = require(script.Parent.States.Charging),
	Burst = require(script.Parent.States.Burst),
	Hang = require(script.Parent.States.Hang),
	Hop = require(script.Parent.States.Hop),
	Glide = require(script.Parent.States.Glide),
	Dive = require(script.Parent.States.Dive),
	Swoop = require(script.Parent.States.Swoop),
	Landing = require(script.Parent.States.Landing),
	Slide = require(script.Parent.States.Slide),
} :: any

local Controller = {}

-- (from, to, payload)
Controller.StateChanged = Signal.new() :: Signal.Signal<Types.MovementState, Types.MovementState, any>
Controller.ctx = nil :: Types.Ctx?
-- (position, speed before the bounce) whenever the bounce rule throws the player off a wall or the ground
Controller.Bounced = Signal.new() :: Signal.Signal<Vector3, number>
-- (position, speed, radius, direct, force, effort) when a dive smashes into the ground or, with `direct`, into
-- that destructible mid-air (spec §4.8); `force` is the attack multiplier on the speed's hits and `effort` the
-- speed scaled by how much the object resisted (0 when it gave way easily, the full speed when it stood), which
-- the structure's impact feel follows. Combat/Smash reports it; Juice plays the structure impact frame.
Controller.Smashed = Signal.new() :: Signal.Signal<Vector3, number, number, Model?, number, number>
-- (model, position, speed, force, effort) when flying into a destructible without diving: it hits what it touched.
Controller.HitObject = Signal.new() :: Signal.Signal<Model, Vector3, number, number, number>
-- (model, position, speed) when a contact is expected to finish the object and you pass through it.
Controller.BrokeThrough = Signal.new() :: Signal.Signal<Model, Vector3, number>
-- (model, position, health left 0–1, effort) when a contact damaged an object without finishing it; the health
-- reveal (Feel/Damage) cracks, leans and shudders it from this.
Controller.Damaged = Signal.new() :: Signal.Signal<Model, Vector3, number, number>

local persistentPower = 1
local recentHits: { [Model]: number } = {} -- last contact time per destructible, for Smash.RehitTime
-- Damage this client expects it has dealt each destructible, to predict whether a contact breaks through or
-- bounces (the server decides the real break). Destruction resets it on every break and rebuild.
local predictedDamage: { [Model]: number } = {}
local predictedBroken: { [Model]: boolean } = {}
local appliedScale = 1 -- time scale the last velocity handed to physics was multiplied by
local appliedTilt = CFrame.identity -- arc correction the last velocity handed to physics was rotated by
local traceFrames = 0

-- Hands the state's velocity to physics. A straight step along a level velocity ends outside the sphere
-- (the chord leaves the arc), so the velocity is tilted by half the frame's rotation around the planet
-- before it is written: the step then lands on the arc, and level flight holds its altitude at any speed.
local function writeVelocity(ctx: Types.Ctx, dt: number)
	local nextUp = MathUtil.upAt(ctx.Root.Position + ctx.Velocity * dt)
	appliedTilt = CFrame.identity:Lerp(MathUtil.transport(ctx.Up, nextUp), 0.5)
	appliedScale = ctx.TimeScale
	ctx.Root.AssemblyLinearVelocity = (appliedTilt * ctx.Velocity) * ctx.TimeScale
end

-- Studio-only movement trace (Tuning.Dev.TraceMovement): transitions and bounces print, and a few numbers
-- are exposed as player attributes for the cheat sheet and test scripts.
local function trace(ctx: Types.Ctx, message: string)
	if Tuning.Dev.TraceMovement and RunService:IsStudio() then
		local climb = ctx.Velocity:Dot(ctx.Up)
		print(
			string.format(
				"[FALL %s] %s alt=%.0f spd=%.0f climb=%.0f",
				ctx.State,
				message,
				ctx.Altitude,
				ctx.Velocity.Magnitude,
				climb
			)
		)
	end
end

local function bodyOrientation(ctx: Types.Ctx): CFrame
	local forward = ctx.BodyDirection
	if not forward then
		return MathUtil.upright(Vector3.zero, ctx.Heading, ctx.Up)
	end
	-- Head points along `forward`; the body's right is the heading's right, so the front faces the heading whether
	-- the body leans forward (glide, dive: belly down) or back (slide). Bank rolls around the long axis.
	local right = ctx.Heading:Cross(ctx.Up)
	right = (right - forward * right:Dot(forward)).Unit
	return CFrame.fromMatrix(Vector3.zero, right, forward) * CFrame.Angles(0, math.rad(ctx.Bank), 0)
end

local function transition(ctx: Types.Ctx, nextState: Types.MovementState, payload: any)
	local from = ctx.State
	local old = States[from]
	local new = States[nextState]
	assert(new, `unknown movement state {nextState}`)
	if old.exit then
		old.exit(ctx)
	end
	if new.OnGround and not old.OnGround then
		ctx.BodyDirection = nil
		ctx.Bank = 0
	end
	ctx.State = nextState
	ctx.StateTime = 0
	ctx.Player:SetAttribute("MovementState", nextState) -- local-only; for inspecting in Studio
	new.enter(ctx, payload)
	writeVelocity(ctx, Tuning.Physics.MaxDt)
	trace(ctx, `from {from}`)
	Controller.StateChanged:Fire(from, nextState, payload)
end

local function placeOnGround(ctx: Types.Ctx, groundPosition: Vector3)
	ctx.Up = MathUtil.upAt(groundPosition)
	ctx.Root.CFrame = MathUtil.upright(groundPosition + ctx.Up * ctx.StandHeight, ctx.Heading, ctx.Up)
	ctx.Root.AssemblyLinearVelocity = Vector3.zero
	ctx.Velocity = Vector3.zero
end

local function altarPosition(): Vector3
	local altar = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Altar")
	if altar and altar:IsA("Model") then
		-- Only the altar's direction matters: the spawn always sits on the analytic surface, so a Studio altar
		-- left at an old radius (the globe has been resized twice) can't put the player inside or above the world.
		local up = MathUtil.upAt(altar:GetPivot().Position)
		local probe = Tuning.World.SpawnProbe
		local hit = Globe.raycast(Planet.Center + up * (Planet.Radius + probe), -up * probe * 2, nil)
		return if hit then hit.Position else Planet.Center + up * Planet.Radius
	end
	return Planet.Center + Vector3.yAxis * Planet.Radius
end

local function respawnAtAltar(ctx: Types.Ctx)
	placeOnGround(ctx, altarPosition())
	transition(ctx, "Grounded", nil)
end

-- Air-gain ceiling (spec §3: total air gain per fall capped).
local function applyCeiling(ctx: Types.Ctx)
	local v = ctx.Velocity
	local ceiling = ctx.FallPeak * (1 + Tuning.Swoop.MaxAirGainFraction)
	local climb = v:Dot(ctx.Up)
	if ctx.State ~= "Hop" and ctx.State ~= "Burst" and climb > 0 then
		-- Cap climb speed to what would just coast to the ceiling, so the arc rounds off instead of snapping flat.
		local room = math.max(0, ceiling - ctx.Altitude)
		local maxClimb = math.sqrt(2 * Tuning.Physics.CeilingDecel * room)
		if climb > maxClimb then
			v = MathUtil.flat(v, ctx.Up) + ctx.Up * maxClimb
		end
	end
	ctx.Velocity = v
end

-- Speed out of a surface for a hit at `speedIn` along its normal: restitution, capped so a hypersonic dive
-- doesn't fire you into orbit. Speed along the surface is always kept.
local function bounceOut(speedIn: number): number
	return math.min(speedIn * Tuning.Physics.BounceRestitution, Tuning.Physics.MaxBounceSpeed)
end

-- Reflects the velocity off a surface with this normal if moving into it. Returns whether it bounced.
local function reflect(ctx: Types.Ctx, normal: Vector3): boolean
	local into = ctx.Velocity:Dot(normal)
	if into >= 0 then
		return false
	end
	ctx.Velocity += normal * (-into + bounceOut(-into))
	local flat = MathUtil.flat(ctx.Velocity, ctx.Up)
	if flat.Magnitude > 1 then
		ctx.Heading = flat.Unit
	end
	return true
end

local function smashRadius(speed: number): number
	local I = Tuning.Impact
	return I.RadiusBase + speed / I.RadiusSpeedDivisor
end

-- The attack multiplier on a contact's hits: a dive, and a punch held or just fired (spec §15 milestone 4).
local function contactForce(ctx: Types.Ctx): number
	local S = Tuning.Smash
	local force = if ctx.State == "Dive" then S.DiveMult else 1
	if ctx.Input.PrimaryHeld or ctx.Now < ctx.PunchFiredAt + S.PunchWindow then
		force *= S.PunchMult
	end
	return force
end

-- Hits a destructible can take: its catalog Health, growing with its size (Smash.HealthBySize).
local function healthOf(model: Model): number
	local entry = Destructibles.entryOf(model)
	return (if entry then entry.Health else 1) * model:GetScale() ^ Tuning.Smash.HealthBySize
end

-- Contact with a destructible (spec §15 milestone 4). Below Smash.MinSpeed it is solid like any wall. Faster,
-- it takes speed / SpeedPerHit hits times the attack force; if this client expects that to finish it (its
-- health against the damage dealt so far) you break through, losing a share of your speed in proportion to how
-- close it was (weight), and a dive also smashes everything around the contact point. Otherwise it stands and
-- you bounce off it, and it keeps the damage. Returns whether you broke through. Each object counts once per
-- Smash.RehitTime, so passing through something doesn't hit it every frame.
local function contactDestructible(ctx: Types.Ctx, model: Model, position: Vector3): boolean
	local S = Tuning.Smash
	local speed = ctx.Velocity.Magnitude
	if speed < S.MinSpeed then
		return false
	end
	local last = recentHits[model]
	if last and ctx.Now - last < S.RehitTime then
		return predictedBroken[model] == true
	end
	for other, at in recentHits do
		if ctx.Now - at >= S.RehitTime then
			recentHits[other] = nil
		end
	end
	recentHits[model] = ctx.Now
	local force = contactForce(ctx)
	local hits = speed / S.SpeedPerHit * force
	local health = healthOf(model)
	local remaining = health - (predictedDamage[model] or 0)
	predictedDamage[model] = (predictedDamage[model] or 0) + hits
	-- Health decides, with the punch as a force multiplier (review note: a tap punch shouldn't level a tower; it
	-- has to be gradual with the charge). A tap clears trees and houses; a few seconds of charge opens towers.
	local breaks = hits >= remaining
	predictedBroken[model] = breaks
	-- How much it resisted: nothing for a tree under a charged punch, everything for a wall that stops you.
	-- The feel and the speed you lose both follow it, so cutting through a cluster at speed stays smooth
	-- (review note: it must be gradual with the charge, not a switch).
	local resistance = if breaks then math.clamp(remaining / math.max(hits, 1e-3), 0, 1) else 1
	local effort = speed * resistance
	if ctx.State == "Dive" then
		trace(ctx, if breaks then "smashed through a structure" else "smashed into a structure")
		Controller.Smashed:Fire(position, speed, smashRadius(speed), model, force, effort)
	else
		trace(ctx, if breaks then "broke through a destructible" else "hit a destructible")
		Controller.HitObject:Fire(model, position, speed, force, effort)
	end
	if breaks then
		ctx.Velocity *= 1 - S.PassLoss * resistance
		Controller.BrokeThrough:Fire(model, position, speed)
	else
		local left = math.clamp((remaining - hits) / math.max(health, 1e-3), 0, 1)
		Controller.Damaged:Fire(model, position, left, effort)
	end
	return breaks
end

-- Destruction calls this when the server breaks or rebuilds an object, so predictions start fresh.
function Controller.resetDamage(model: Model)
	predictedDamage[model] = nil
	predictedBroken[model] = nil
	recentHits[model] = nil
end

-- The bounce rule (spec §15): anything that isn't destructible bounces you; destructibles break instead.
-- Ground is a landing, not a bounce. Returns where it bounced, if it did.
local function bounceOffWalls(ctx: Types.Ctx, dt: number): Vector3?
	local speed = ctx.Velocity.Magnitude
	if speed < 1 then
		return nil
	end
	local position = ctx.Root.Position
	local reach = ctx.Velocity.Unit * (speed * dt + Tuning.Physics.BounceProbe)
	local hit = Globe.raycast(position, reach, ctx.RaycastParams)
	if not hit or hit.Normal:Dot(ctx.Up) >= Tuning.Physics.MinGroundNormalY then
		return nil
	end
	local model = Destructibles.modelOf(hit.Instance)
	if model and contactDestructible(ctx, model, hit.Position) then
		return nil
	end
	if reflect(ctx, hit.Normal) then
		return hit.Position
	end
	return nil
end

-- Ground states don't bounce: walking into a wall (or a destructible you're too slow to break) slides along
-- it, keeping only the velocity across its face. A fast ground contact still hits a destructible.
local function slideAlongWalls(ctx: Types.Ctx, dt: number)
	local level = MathUtil.flat(ctx.Velocity, ctx.Up)
	local speed = level.Magnitude
	if speed < 1 then
		return
	end
	local reach = level.Unit * (speed * dt + Tuning.Physics.BounceProbe)
	local hit = Globe.raycast(ctx.Root.Position, reach, ctx.RaycastParams)
	if not hit or hit.Normal:Dot(ctx.Up) >= Tuning.Physics.MinGroundNormalY then
		return
	end
	local model = Destructibles.modelOf(hit.Instance)
	if model and contactDestructible(ctx, model, hit.Position) then
		return
	end
	local into = ctx.Velocity:Dot(hit.Normal)
	if into < 0 then
		ctx.Velocity -= hit.Normal * into
	end
end

-- Predicts ground contact this frame so even terminal-speed dives never tunnel through the surface.
local function findTouchdown(ctx: Types.Ctx, dt: number): Globe.Hit?
	local vy = ctx.Velocity:Dot(ctx.Up)
	if vy > 0 then
		return nil
	end
	local reach = ctx.StandHeight + Tuning.Physics.LandSnap + -vy * dt
	local hit = Globe.raycast(ctx.Root.Position, -ctx.Up * reach, ctx.RaycastParams)
	if hit and hit.Normal:Dot(ctx.Up) >= Tuning.Physics.MinGroundNormalY then
		return hit
	end
	return nil
end

-- Dive-slide: a touchdown out of a Dive or Swoop keeps its level momentum on the ground as a short slide
-- (a steep dive has little level speed and just lands). Swoops only slide from a shallow angle.
-- Call before placeOnGround; uses LandVelocity and the pre-touchdown velocity.
local function canSlide(ctx: Types.Ctx, speed: number): boolean
	local T = Tuning.Tech
	if ctx.State ~= "Swoop" and ctx.State ~= "Dive" then
		return false
	end
	if ctx.LandVelocity.Magnitude < T.SlideMinSpeed or speed < 1e-3 then
		return false
	end
	if ctx.State == "Dive" then
		return true
	end
	local descent = math.deg(math.acos(math.clamp(ctx.LandVelocity.Magnitude / speed, 0, 1)))
	return descent <= T.SlideMaxAngle
end

-- Rolls the character's frame with the planet: whatever was level last frame stays level now.
local function transportFrame(ctx: Types.Ctx)
	local up = MathUtil.upAt(ctx.Root.Position)
	local roll = MathUtil.transport(ctx.Up, up)
	if roll ~= CFrame.identity then
		ctx.Velocity = roll * ctx.Velocity
		ctx.Heading = MathUtil.tangent(roll * ctx.Heading, up, Vector3.xAxis)
		if ctx.BodyDirection then
			ctx.BodyDirection = (roll * ctx.BodyDirection).Unit
		end
	end
	ctx.Up = up
end

local function step(dt: number)
	local ctx = Controller.ctx
	if not ctx or not ctx.Root.Parent then
		return
	end
	-- Hitstop scales dt and the velocity handed to physics; ctx.Velocity stays the unscaled velocity.
	local scale = TimeScale.get()
	ctx.TimeScale = scale
	dt = math.min(dt, Tuning.Physics.MaxDt) * scale

	ctx.Now = os.clock()
	ctx.Input = Input.snapshot()
	Aim.update(ctx)
	if appliedScale > 1e-3 then
		ctx.Velocity = appliedTilt:Inverse() * (ctx.Root.AssemblyLinearVelocity / appliedScale)
	end
	transportFrame(ctx)
	ctx.Altitude = MathUtil.altitudeAt(ctx.Root.Position)
	ctx.StateTime += dt

	if ctx.Altitude < -Tuning.World.FallOffDepth then
		trace(ctx, "fell through: respawn")
		respawnAtAltar(ctx)
		return
	elseif ctx.Altitude < -Tuning.Physics.InsideSnap then
		-- Under the surface (a step at extreme speed clipped the sphere): lift straight back onto it.
		trace(ctx, "under the surface: lifted out")
		placeOnGround(ctx, Planet.Center + ctx.Up * Planet.Radius)
		ctx.Altitude = 0
	end
	if Tuning.Dev.TraceMovement then
		traceFrames += 1
		ctx.Player:SetAttribute("DbgFrames", traceFrames)
		ctx.Player:SetAttribute("DbgFallPeak", ctx.FallPeak)
		ctx.Player:SetAttribute("DbgAimPitch", MathUtil.pitchOf(ctx.AimPoint - ctx.Root.Position, ctx.Up))
		ctx.Player:SetAttribute(
			"DbgBodyPitch",
			if ctx.BodyDirection then MathUtil.pitchOf(ctx.BodyDirection, ctx.Up) else 0
		)
	end

	local state = States[ctx.State]
	JumpCheck.track(ctx, dt, state.OnGround == true)
	local punchState, punchPayload = Punch.update(ctx, state.Punch, dt)
	if punchState then
		transition(ctx, punchState, punchPayload)
		return
	end
	local nextState, payload = state.update(ctx, dt)
	if nextState then
		transition(ctx, nextState, payload)
		return
	end

	applyCeiling(ctx)
	if state.NoBounce then
		slideAlongWalls(ctx, dt)
	else
		local speedBefore = ctx.Velocity.Magnitude
		local bouncedAt = bounceOffWalls(ctx, dt)
		if bouncedAt then
			ctx.LookFollowAfter = ctx.Now + Tuning.Physics.BounceSteerPause
			trace(ctx, "bounced off a wall")
			Controller.Bounced:Fire(bouncedAt, speedBefore)
			-- A dive or swoop can't hold a reversed path; the bounce throws you back into a glide.
			if ctx.State == "Dive" or ctx.State == "Swoop" then
				transition(ctx, "Glide", nil)
				return
			end
		end
	end
	local ground = if state.OnGround then nil else findTouchdown(ctx, dt)
	if
		ground
		and ctx.State == "Dive"
		and ctx.Input.PrimaryHeld
		and not (ground.Instance and Destructibles.isDestructible(ground.Instance))
	then
		-- Punching into the ground: a dive that hits it hard enough while a punch is held bounces off.
		-- Without the punch, dives land and slide (review note).
		local bounced = ctx.Velocity
		local into = -bounced:Dot(ground.Normal)
		if into >= Tuning.Physics.MinGroundBounceSpeed then
			bounced += ground.Normal * (into + bounceOut(into))
			placeOnGround(ctx, ground.Position)
			ctx.Velocity = bounced
			trace(ctx, "bounced off the ground")
			Controller.Bounced:Fire(ground.Position, into)
			transition(ctx, "Hop", { Launch = true, Speed = into })
			return
		end
	end
	if ground then
		local speed = ctx.Velocity.Magnitude
		local model = Destructibles.modelOf(ground.Instance)
		if model then
			-- Touching down on a destructible at speed (a canopy top, a roof) is a contact, not a landing: finish
			-- it and keep flying (the other half of the bounce rule); if it holds, or you're slow, land on it.
			-- (Review note: fast flights across tree clusters were "landing" on every canopy and staggering.)
			if contactDestructible(ctx, model, ground.Position) then
				writeVelocity(ctx, dt)
				ctx.Align.CFrame = bodyOrientation(ctx)
				return
			end
		elseif ctx.State == "Dive" and speed >= Tuning.Smash.MinSpeed then
			-- The ground smash (spec §4.8): the touchdown juice plays through Landing/Slide; this only reports it.
			trace(ctx, "smashed the ground")
			Controller.Smashed:Fire(ground.Position, speed, smashRadius(speed), nil, contactForce(ctx), speed)
		end
	end
	if ground then
		local landing = { Speed = ctx.Velocity.Magnitude, FromDive = ctx.State == "Dive" }
		ctx.LandVelocity = MathUtil.flat(ctx.Velocity, ctx.Up)
		placeOnGround(ctx, ground.Position)
		ctx.LastLandTime = ctx.Now
		transition(ctx, if canSlide(ctx, landing.Speed) then "Slide" else "Landing", landing)
		return
	end
	writeVelocity(ctx, dt)
	ctx.Align.CFrame = bodyOrientation(ctx)
end

local function attach(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart

	-- The controller owns the body in every state; the Humanoid stays for the rig, animation and replication.
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	humanoid.AutoRotate = false
	humanoid.PlatformStand = true

	local attachment = Instance.new("Attachment")
	attachment.Name = "MovementRoot"
	attachment.Parent = root

	local align = Instance.new("AlignOrientation")
	align.Name = "BodyAlign"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.Responsiveness = Tuning.Physics.AlignResponsiveness
	align.MaxTorque = Tuning.Physics.AlignMaxTorque
	align.Parent = root

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.CollisionGroup = "MovementRays" -- sees the world, never a character (registered by the server)

	local up = MathUtil.upAt(root.Position)
	local ctx: Types.Ctx = {
		Player = Players.LocalPlayer,
		Character = character,
		Humanoid = humanoid,
		Root = root,
		Align = align,
		RaycastParams = params,
		StandHeight = humanoid.HipHeight + root.Size.Y / 2,

		Input = Input.snapshot(),
		AimPoint = root.Position,
		AimTarget = nil,
		AimMagnet = 0,
		LookDirection = -Vector3.zAxis,
		Now = os.clock(),

		State = "Grounded",
		StateTime = 0,
		Velocity = Vector3.zero,
		Up = up,
		Altitude = MathUtil.altitudeAt(root.Position),
		Heading = MathUtil.tangent(root.CFrame.LookVector, up, -Vector3.zAxis),
		BodyDirection = nil,
		Bank = 0,

		GlideEnergy = Tuning.GlideEnergy.Max,
		BurstCharge = 1,
		BurstAscentTime = 0,
		BurstHeld = 0,
		HopChain = 0,
		LastLandTime = -math.huge,
		LandVelocity = Vector3.zero,
		SwoopReadyAt = 0,
		FallPeak = 0,
		Power = persistentPower,
		PunchHold = nil,
		PunchReadyAt = 0,
		PunchFiredAt = -math.huge,
		LookFollowAfter = 0,
		TimeScale = 1,
	}
	align.CFrame = bodyOrientation(ctx)
	States.Grounded.enter(ctx, nil)
	Controller.ctx = ctx

	humanoid.Died:Connect(function()
		persistentPower = ctx.Power
		if Controller.ctx == ctx then
			Controller.ctx = nil
		end
	end)
end

-- Dev panel hook: drop the player at an altitude above their current spot, in Glide.
function Controller.drop(altitude: number)
	local ctx = Controller.ctx
	if not ctx then
		return
	end
	local up = MathUtil.upAt(ctx.Root.Position)
	local position = Planet.Center + up * (Planet.Radius + altitude)
	ctx.Up = up
	ctx.Root.CFrame = MathUtil.upright(position, ctx.Heading, up)
	ctx.Altitude = altitude
	ctx.Velocity = Vector3.zero
	ctx.FallPeak = altitude
	ctx.GlideEnergy = Tuning.GlideEnergy.Max
	transition(ctx, "Glide", nil)
end

-- Dev hook (Studio F4): smash the ground under the player at Dev.TestSmashSpeed, as if a dive had landed there.
function Controller.testSmash()
	local ctx = Controller.ctx
	if not ctx then
		return
	end
	local ground = Globe.raycast(ctx.Root.Position, -ctx.Up * Tuning.Vfx.GroundProbe, ctx.RaycastParams)
	if ground then
		local speed = Tuning.Dev.TestSmashSpeed
		Controller.Smashed:Fire(
			ground.Position,
			speed,
			smashRadius(speed),
			Destructibles.modelOf(ground.Instance),
			Tuning.Smash.DiveMult,
			speed
		)
	end
end

-- Dev panel hook: set the Power level.
function Controller.setPower(power: number)
	persistentPower = power
	if Controller.ctx then
		Controller.ctx.Power = power
	end
end

function Controller.start()
	Input.start()
	-- A rocket punch pounds the surface it fires off, with the punch's force; the strength stands in for speed.
	Punch.GroundPound:Connect(function(position, strength, model)
		Controller.Smashed:Fire(position, strength, smashRadius(strength), model, Tuning.Smash.PunchMult, strength)
	end)
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(attach)
	if player.Character then
		task.spawn(attach, player.Character)
	end
	RunService.PreSimulation:Connect(step)
end

return Controller
