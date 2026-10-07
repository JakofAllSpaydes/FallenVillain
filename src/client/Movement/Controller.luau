--!strict
-- Movement state machine (spec §9, §10). Owns the shared context, runs the current state in PreSimulation,
-- applies velocity with a VectorForce cancelling world gravity, and fires StateChanged for everything else.
-- States never touch effects; they only return the next state.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Destructibles = require(Shared.Destructibles)
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
-- (position) whenever the bounce rule throws the player off a wall
Controller.Bounced = Signal.new() :: Signal.Signal<Vector3>

local persistentPower = 1
local appliedScale = 1 -- time scale the last velocity handed to physics was multiplied by

local function uprightCFrame(position: Vector3, heading: Vector3): CFrame
	return CFrame.lookAt(position, position + heading)
end

local function bodyOrientation(ctx: Types.Ctx): CFrame
	local forward = ctx.BodyDirection
	if not forward then
		return uprightCFrame(Vector3.zero, ctx.Heading)
	end
	-- Head points along `forward`; the body's right is the heading's right, so the front faces the heading whether
	-- the body leans forward (glide, dive: belly down) or back (slide). Bank rolls around the long axis.
	local right = ctx.Heading:Cross(Vector3.yAxis)
	right = (right - forward * right:Dot(forward)).Unit
	return CFrame.fromMatrix(Vector3.zero, right, forward) * CFrame.Angles(0, math.rad(ctx.Bank), 0)
end

local function setAirborne(ctx: Types.Ctx, air: boolean)
	ctx.Humanoid.PlatformStand = air
	ctx.Gravity.Enabled = air
	ctx.Align.Enabled = air
	if air then
		ctx.Gravity.Force = Vector3.yAxis * ctx.Root.AssemblyMass * workspace.Gravity
		ctx.Align.CFrame = bodyOrientation(ctx)
	else
		-- Stand up from whatever pose the air state left (e.g. the slide's lean) before the Humanoid takes over.
		ctx.Root.CFrame = uprightCFrame(ctx.Root.Position, ctx.Heading)
		ctx.Humanoid:ChangeState(Enum.HumanoidStateType.Running)
	end
end

local function transition(ctx: Types.Ctx, nextState: Types.MovementState, payload: any)
	local from = ctx.State
	local old = States[from]
	local new = States[nextState]
	assert(new, `unknown movement state {nextState}`)
	if old.exit then
		old.exit(ctx)
	end
	if old.Air ~= new.Air then
		if not new.Air then
			ctx.BodyDirection = nil
			ctx.Bank = 0
		end
		setAirborne(ctx, new.Air)
	end
	ctx.State = nextState
	ctx.StateTime = 0
	ctx.Player:SetAttribute("MovementState", nextState) -- local-only; for inspecting in Studio
	new.enter(ctx, payload)
	if new.Air then
		ctx.Root.AssemblyLinearVelocity = ctx.Velocity * ctx.TimeScale
		appliedScale = ctx.TimeScale
	end
	Controller.StateChanged:Fire(from, nextState, payload)
end

local function placeOnGround(ctx: Types.Ctx, groundPosition: Vector3)
	ctx.Root.CFrame = uprightCFrame(groundPosition + Vector3.yAxis * ctx.StandHeight, ctx.Heading)
	ctx.Root.AssemblyLinearVelocity = Vector3.zero
	ctx.Velocity = Vector3.zero
end

local function altarPosition(): Vector3
	local altar = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Altar")
	if altar and altar:IsA("Model") then
		local pivot = altar:GetPivot()
		local _, size = altar:GetBoundingBox()
		return pivot.Position + Vector3.yAxis * size.Y / 2
	end
	return Vector3.new(0, Planet.SurfaceY, 0)
end

local function respawnAtAltar(ctx: Types.Ctx)
	placeOnGround(ctx, altarPosition())
	transition(ctx, "Grounded", nil)
end

-- Air-gain ceiling (spec §3: total air gain per fall capped).
local function applyCeiling(ctx: Types.Ctx)
	local v = ctx.Velocity
	local ceiling = ctx.FallPeak * (1 + Tuning.Swoop.MaxAirGainFraction)
	if ctx.State ~= "Hop" and ctx.State ~= "Burst" and v.Y > 0 then
		-- Cap climb speed to what would just coast to the ceiling, so the arc rounds off instead of snapping flat.
		local room = math.max(0, ceiling - ctx.Altitude)
		local maxClimb = math.sqrt(2 * Tuning.Physics.CeilingDecel * room)
		if v.Y > maxClimb then
			v = MathUtil.flat(v) + Vector3.yAxis * maxClimb
		end
	end
	ctx.Velocity = v
end

-- Reflects the velocity off a surface with this normal if moving into it. Returns whether it bounced.
local function reflect(ctx: Types.Ctx, normal: Vector3): boolean
	local into = ctx.Velocity:Dot(normal)
	if into >= 0 then
		return false
	end
	ctx.Velocity -= normal * into * (1 + Tuning.Physics.BounceRestitution)
	local flat = MathUtil.flat(ctx.Velocity)
	if flat.Magnitude > 1 then
		ctx.Heading = flat.Unit
	end
	return true
end

-- The bounce rule (spec §15): anything that isn't destructible bounces you, walls and the invisible wall past
-- the disc edge alike. Destructibles don't; milestone 3 breaks them instead. Ground is a landing, not a bounce.
-- Returns where it bounced, if it did.
local function bounceOffWalls(ctx: Types.Ctx, dt: number): Vector3?
	local position = ctx.Root.Position
	local flatPos = MathUtil.flat(position)
	if flatPos.Magnitude > Planet.DiscDiameter / 2 + Tuning.World.EdgeWallMargin then
		if reflect(ctx, -flatPos.Unit) then
			return position
		end
	end

	local speed = ctx.Velocity.Magnitude
	if speed < 1 then
		return nil
	end
	local reach = ctx.Velocity.Unit * (speed * dt + Tuning.Physics.BounceProbe)
	local hit = workspace:Raycast(position, reach, ctx.RaycastParams)
	if
		hit
		and hit.Normal.Y < Tuning.Physics.MinGroundNormalY
		and not Destructibles.isDestructible(hit.Instance)
		and reflect(ctx, hit.Normal)
	then
		return hit.Position
	end
	return nil
end

-- Predicts ground contact this frame so even terminal-speed dives never tunnel through the surface.
local function findTouchdown(ctx: Types.Ctx, dt: number): RaycastResult?
	local vy = ctx.Velocity.Y
	if vy > 0 then
		return nil
	end
	local reach = ctx.StandHeight + Tuning.Physics.LandSnap + -vy * dt
	local hit = workspace:Raycast(ctx.Root.Position, -Vector3.yAxis * reach, ctx.RaycastParams)
	if hit and hit.Normal.Y >= Tuning.Physics.MinGroundNormalY then
		return hit
	end
	return nil
end

-- Dive-slide: a fast, shallow touchdown out of Dive or Swoop keeps its momentum on the ground.
-- Call before placeOnGround; uses LandVelocity and the pre-touchdown velocity.
local function canSlide(ctx: Types.Ctx, speed: number): boolean
	local T = Tuning.Tech
	if ctx.State ~= "Dive" and ctx.State ~= "Swoop" then
		return false
	end
	if ctx.LandVelocity.Magnitude < T.SlideMinSpeed or speed < 1e-3 then
		return false
	end
	local descent = math.deg(math.acos(math.clamp(ctx.LandVelocity.Magnitude / speed, 0, 1)))
	return descent <= T.SlideMaxAngle
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
	if not States[ctx.State].Air then
		ctx.Velocity = ctx.Root.AssemblyLinearVelocity
	elseif appliedScale > 1e-3 then
		ctx.Velocity = ctx.Root.AssemblyLinearVelocity / appliedScale
	end
	ctx.Altitude = ctx.Root.Position.Y - Planet.SurfaceY
	ctx.StateTime += dt

	if ctx.Altitude < -Tuning.World.FallOffDepth then
		respawnAtAltar(ctx)
		return
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
	if not state.Air then
		return
	end

	Punch.decay(ctx, dt)
	applyCeiling(ctx)
	local bouncedAt = bounceOffWalls(ctx, dt)
	if bouncedAt then
		Controller.Bounced:Fire(bouncedAt)
		-- A dive or swoop can't hold a reversed path; the bounce throws you back into a glide.
		if ctx.State == "Dive" or ctx.State == "Swoop" then
			transition(ctx, "Glide", nil)
			return
		end
	end
	local ground = if state.SkipTouchdown then nil else findTouchdown(ctx, dt)
	if ground then
		local landing = { Speed = ctx.Velocity.Magnitude, FromDive = ctx.State == "Dive" }
		ctx.LandVelocity = MathUtil.flat(ctx.Velocity)
		placeOnGround(ctx, ground.Position)
		ctx.LastLandTime = ctx.Now
		transition(ctx, if canSlide(ctx, landing.Speed) then "Slide" else "Landing", landing)
		return
	end
	ctx.Root.AssemblyLinearVelocity = ctx.Velocity * scale
	appliedScale = scale
	ctx.Align.CFrame = bodyOrientation(ctx)
end

local function attach(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart

	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	humanoid.WalkSpeed = Tuning.Walk.Speed

	local attachment = Instance.new("Attachment")
	attachment.Name = "MovementRoot"
	attachment.Parent = root

	local gravity = Instance.new("VectorForce")
	gravity.Name = "StateGravity"
	gravity.Attachment0 = attachment
	gravity.RelativeTo = Enum.ActuatorRelativeTo.World
	gravity.ApplyAtCenterOfMass = true
	gravity.Enabled = false
	gravity.Parent = root

	local align = Instance.new("AlignOrientation")
	align.Name = "BodyAlign"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.Responsiveness = Tuning.Physics.AlignResponsiveness
	align.MaxTorque = Tuning.Physics.AlignMaxTorque
	align.Enabled = false
	align.Parent = root

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.CollisionGroup = "Characters"

	local look = MathUtil.flat(root.CFrame.LookVector)
	local ctx: Types.Ctx = {
		Player = Players.LocalPlayer,
		Character = character,
		Humanoid = humanoid,
		Root = root,
		Gravity = gravity,
		Align = align,
		RaycastParams = params,
		StandHeight = humanoid.HipHeight + root.Size.Y / 2,

		Input = Input.snapshot(),
		AimPoint = root.Position,
		LookDirection = -Vector3.zAxis,
		Now = os.clock(),

		State = "Grounded",
		StateTime = 0,
		Velocity = Vector3.zero,
		Altitude = root.Position.Y - Planet.SurfaceY,
		Heading = if look.Magnitude > 1e-3 then look.Unit else -Vector3.zAxis,
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
		PunchBoost = Vector3.zero,
		PunchBoostRate = 0,
		TimeScale = 1,
	}
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
	local position = ctx.Root.Position
	ctx.Root.CFrame = uprightCFrame(Vector3.new(position.X, Planet.SurfaceY + altitude, position.Z), ctx.Heading)
	ctx.Altitude = altitude
	ctx.Velocity = Vector3.zero
	ctx.FallPeak = altitude
	ctx.GlideEnergy = Tuning.GlideEnergy.Max
	transition(ctx, "Glide", nil)
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
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(attach)
	if player.Character then
		task.spawn(attach, player.Character)
	end
	RunService.PreSimulation:Connect(step)
end

return Controller
