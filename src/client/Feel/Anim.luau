--!strict
-- Character animation (spec §4, §10, §12; §15 milestones 3b and 5). Two layers on the Humanoid rig, R15 first
-- with an R6 fallback (players use both):
--   * Locomotion: Roblox's own stock clips (idle, walk, run, jump, fall; Tuning.Anim.Clips) chosen by state and
--     ground speed, played through the Animator so they replicate. The character's default Animate script is
--     disabled: the controller owns every state, so this module owns every clip.
--   * Poses: every FALL-specific shape (jump-charge squat, punch wind-back, the punch, burst extension, hang,
--     glide, dive, swoop, slide, takeoff stretch, touchdown squash, the three-point landing, hit recoil) is a
--     set of joint offsets in Tuning.Poses. Each frame the active poses are summed per joint with their
--     weights, and composed into the joint's Transform in front of whatever the clip wrote, so a punch
--     wind-back layers over a walk and a squat deepens under an idle. Offsets are in the parent part's axes
--     (see Tuning.Poses). Joints are Motor6Ds on classic rigs and AnimationConstraints on current ones (C0
--     derived, read-only); both expose Transform, which the Animator rewrites each frame for animated joints.
--     Joints no clip is driving keep the last Transform, so the layer remembers what it wrote and never
--     compounds its own offset.
-- Every joint channel follows its target on a damped spring (Tuning.Anim.SpringFrequency / SpringDamping), so
-- poses land with a little overshoot and settle; state enters and punches snap with the faster, bouncier pair
-- for SnapTime (spec §4.10: cut in, fade out). On top of the poses: the head looks at the aim point, the body
-- leans into ground acceleration, the wings flutter and flex in a glide, a fast dive tightens, and tremble,
-- breathing and dive vibration are added as noise or sine. This module reads the controller; it never drives
-- movement.

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)

local Blast = require(script.Parent.Parent.Movement.Blast)
local Controller = require(script.Parent.Parent.Movement.Controller)
local JumpCheck = require(script.Parent.Parent.Movement.JumpCheck)
local MathUtil = require(script.Parent.Parent.Movement.MathUtil)
local Punch = require(script.Parent.Parent.Movement.Punch)

local Anim = {}

-- A pose from Tuning.Poses: joint name → { P, T, S, Up, Fwd }, each optional. Typed loosely because strict mode
-- can't match the literal tables in Tuning against optional fields.
type Pose = { [string]: { [string]: number } }
-- Channels: 1 P, 2 T, 3 S (degrees), 4 Up, 5 Fwd (studs).
type Joint = {
	Motor: any, -- Motor6D or AnimationConstraint; both have C0 (read) and Transform (write)
	Position: Vector3, -- rest C0 translation
	Rotation: CFrame, -- rest C0 rotation
	Inverse: CFrame, -- rest C0 inverse
	Current: { number },
	Velocity: { number }, -- spring velocity per channel
	Target: { number },
	LastWritten: CFrame?, -- the Transform this layer wrote last frame
	LastBase: CFrame, -- the clip's Transform that write was layered on
}
-- A one-shot pose weight: full for Hold seconds, then decaying to zero by Duration.
type Kick = { Start: number, Duration: number, Hold: number, Amount: number }

-- Abstract joint → { part that holds the Motor6D, motor name } per rig.
local RIGS: { [string]: { [string]: { string } } } = {
	R15 = {
		Root = { "LowerTorso", "Root" },
		Waist = { "UpperTorso", "Waist" },
		Neck = { "Head", "Neck" },
		LShoulder = { "LeftUpperArm", "LeftShoulder" },
		LElbow = { "LeftLowerArm", "LeftElbow" },
		RShoulder = { "RightUpperArm", "RightShoulder" },
		RElbow = { "RightLowerArm", "RightElbow" },
		LHip = { "LeftUpperLeg", "LeftHip" },
		LKnee = { "LeftLowerLeg", "LeftKnee" },
		RHip = { "RightUpperLeg", "RightHip" },
		RKnee = { "RightLowerLeg", "RightKnee" },
	},
	R6 = {
		Root = { "HumanoidRootPart", "RootJoint" },
		Neck = { "Torso", "Neck" },
		LShoulder = { "Torso", "Left Shoulder" },
		RShoulder = { "Torso", "Right Shoulder" },
		LHip = { "Torso", "Left Hip" },
		RHip = { "Torso", "Right Hip" },
	},
}

local GROUND_STATES: { [string]: boolean } = { Grounded = true, Landing = true, Charging = true, Slide = true }
local LEAN_STATES: { [string]: boolean } = { Grounded = true, Landing = true }
local BIND_RETRY_TIME = 5 -- seconds to keep looking for joints that load late; not a feel value
local FOREIGN_SWEEP_INTERVAL = 0.25 -- seconds between sweeps of the default Animate script's tracks
local NOISE_SEED_P, NOISE_SEED_S, NOISE_SEED_V = 3.7, 29.1, 61.3 -- decorrelate tremble axes; not a feel value
local SPRING_SUBSTEP = 1 / 120 -- integration step for the joint springs; not a feel value
local SPRING_MAX_SUBSTEPS = 4
local LOOK_HEIGHT = 1.5 -- studs above the root the look-at measures from; not a feel value

local character: Model? = nil
local rigName = "R15"
local joints: { [string]: Joint } = {}
local expectedJoints = 0
local boundAt = 0
local animator: Animator? = nil
local tracks: { [string]: AnimationTrack } = {}
local playing: string? = nil
local snapUntil = 0
local kicks: { [string]: Kick } = {}
local lastLevel = Vector3.zero -- level velocity last frame, for the acceleration lean
local leanAccel = Vector3.zero -- smoothed level acceleration

local function kickValue(name: string, now: number): number
	local kick = kicks[name]
	if not kick then
		return 0
	end
	local age = now - kick.Start
	if age >= kick.Duration then
		kicks[name] = nil
		return 0
	end
	if age < kick.Hold then
		return kick.Amount
	end
	local p = (age - kick.Hold) / math.max(kick.Duration - kick.Hold, 1e-3)
	return kick.Amount * (1 - p) ^ 2
end

local function kick(name: string, amount: number, duration: number, hold: number?)
	kicks[name] = {
		Start = os.clock(),
		Duration = math.max(duration, 1e-3),
		Hold = math.clamp(hold or 0, 0, duration),
		Amount = amount,
	}
end

local function snap()
	snapUntil = os.clock() + Tuning.Anim.SnapTime
end

-- 0–1 that approaches 1 as `value` grows past `ref`, with no cap.
local function saturate(value: number, ref: number): number
	return 1 - math.exp(-math.max(0, value) / math.max(ref, 1e-3))
end

-- Finds the rig's joints and remembers their rest C0 (the pose offsets are relative to it).
local function findJoints(model: Model)
	local map = RIGS[rigName]
	expectedJoints = 0
	for name, spec in map do
		expectedJoints += 1
		if joints[name] then
			continue
		end
		local part = model:FindFirstChild(spec[1])
		local motor = if part then part:FindFirstChild(spec[2]) else nil
		if motor and (motor:IsA("Motor6D") or motor:IsA("AnimationConstraint")) then
			local c0 = (motor :: any).C0 :: CFrame
			joints[name] = {
				Motor = motor,
				Position = c0.Position,
				Rotation = c0.Rotation,
				Inverse = c0:Inverse(),
				Current = { 0, 0, 0, 0, 0 },
				Velocity = { 0, 0, 0, 0, 0 },
				Target = { 0, 0, 0, 0, 0 },
				LastWritten = nil,
				LastBase = CFrame.identity,
			}
		end
	end
end

local function jointCount(): number
	local count = 0
	for _ in joints do
		count += 1
	end
	return count
end

local function loadClips(humanoid: Humanoid)
	local target = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	animator = target
	tracks = {}
	playing = nil
	for name, id in Tuning.Anim.Clips[rigName] do
		local animation = Instance.new("Animation")
		animation.Name = name
		animation.AnimationId = id
		local track = target:LoadAnimation(animation)
		track.Looped = name ~= "jump"
		tracks[name] = track
	end
end

-- The default Animate script would fight for the same joints; silence it and whatever it already started.
-- Its idle can start before this binds and lives on the Humanoid as well as the Animator, so foreign tracks
-- are swept from both for a while after binding.
local function disableDefaultAnimate(model: Model, humanoid: Humanoid)
	local mine = tracks
	task.spawn(function()
		local animate = model:WaitForChild("Animate", BIND_RETRY_TIME)
		if animate and animate:IsA("LocalScript") then
			animate.Disabled = true
		end
		local until_ = os.clock() + BIND_RETRY_TIME
		while os.clock() < until_ and tracks == mine do
			local ours: { [AnimationTrack]: boolean } = {}
			for _, track in tracks do
				ours[track] = true
			end
			local playing = humanoid:GetPlayingAnimationTracks()
			if animator then
				for _, track in animator:GetPlayingAnimationTracks() do
					table.insert(playing, track)
				end
			end
			for _, track in playing do
				if not ours[track] then
					track:Stop(0)
				end
			end
			task.wait(FOREIGN_SWEEP_INTERVAL)
		end
	end)
end

local function bind(ctx: Types.Ctx)
	character = ctx.Character
	rigName = if ctx.Humanoid.RigType == Enum.HumanoidRigType.R6 then "R6" else "R15"
	joints = {}
	kicks = {}
	lastLevel = Vector3.zero
	leanAccel = Vector3.zero
	boundAt = os.clock()
	findJoints(ctx.Character)
	loadClips(ctx.Humanoid)
	disableDefaultAnimate(ctx.Character, ctx.Humanoid)
end

local function playClip(name: string?, rate: number)
	local A = Tuning.Anim
	if name ~= playing then
		if playing and tracks[playing] then
			tracks[playing]:Stop(A.Fade)
		end
		playing = name
		if name and tracks[name] then
			tracks[name]:Play(A.Fade)
		end
	end
	if name and tracks[name] then
		tracks[name]:AdjustSpeed(rate)
	end
end

-- Which stock clip fits this frame: idle/walk/run by ground speed, jump and fall in a hop, nothing in flight.
local function chooseClip(ctx: Types.Ctx): (string?, number)
	local A = Tuning.Anim
	local state = ctx.State
	if state == "Grounded" or state == "Landing" or state == "Charging" then
		local speed = MathUtil.flat(ctx.Velocity, ctx.Up).Magnitude
		if state == "Charging" or speed < A.WalkMinSpeed then
			return "idle", 1
		end
		local rate = math.clamp(speed / A.ClipRefSpeed, A.MinClipRate, A.MaxClipRate)
		return if speed >= A.RunSpeed then "run" else "walk", rate
	elseif state == "Hop" then
		return if ctx.Velocity:Dot(ctx.Up) > 0 then "jump" else "fall", 1
	end
	return nil, 1
end

local function addPose(raw: any, weight: number)
	local pose: Pose? = raw
	if not pose or math.abs(weight) < 1e-4 then
		return
	end
	for name, offset in pose do
		local joint = joints[name]
		if joint then
			local t = joint.Target
			t[1] += (offset.P or 0) * weight
			t[2] += (offset.T or 0) * weight
			t[3] += (offset.S or 0) * weight
			t[4] += (offset.Up or 0) * weight
			t[5] += (offset.Fwd or 0) * weight
		end
	end
end

local function addNoise(name: string, now: number, amplitude: number, channelA: number, channelB: number)
	local joint = joints[name]
	if not joint or amplitude < 1e-4 then
		return
	end
	local t = now * Tuning.Anim.TrembleFrequency
	joint.Target[channelA] += math.noise(t, NOISE_SEED_P) * 2 * amplitude
	joint.Target[channelB] += math.noise(t, NOISE_SEED_S) * 2 * amplitude
end

-- Seconds of the longest punch hold on the curve; tremble and overcharge saturate there.
local function lastPunchTier(): number
	local boosts = Tuning.Punch.HoldBoosts
	return boosts[#boosts][1]
end

local function lastBurstTier(): number
	local heights = Tuning.Burst.HoldHeights
	return heights[#heights][1]
end

-- The head (and a share of the waist) turns toward the aim point, measured in the body's frame.
local function addLook(ctx: Types.Ctx)
	local A = Tuning.Anim
	local weight = A.LookWeights[ctx.State]
	if not weight or weight <= 0 then
		return
	end
	local from = ctx.Root.Position + ctx.Up * LOOK_HEIGHT
	local toAim = ctx.AimPoint - from
	if toAim.Magnitude < 1 then
		return
	end
	local local_ = ctx.Root.CFrame:VectorToObjectSpace(toAim.Unit)
	-- The body looks down -Z; yaw is positive to the character's left, pitch positive up.
	local yaw = math.clamp(math.deg(math.atan2(-local_.X, -local_.Z)), -A.LookYawMax, A.LookYawMax)
	local pitch = math.clamp(math.deg(math.asin(math.clamp(local_.Y, -1, 1))), -A.LookPitchMax, A.LookPitchMax)
	local neck = joints.Neck
	local waist = joints.Waist
	local waistShare = if waist then A.LookWaistShare else 0
	if neck then
		neck.Target[1] += pitch * weight
		neck.Target[2] += yaw * weight * (1 - waistShare)
	end
	if waist then
		waist.Target[2] += yaw * weight * waistShare
		waist.Target[1] += pitch * weight * waistShare * 0.5
	end
end

-- The body leans into level acceleration on the ground: forward when speeding up, back when braking, and
-- into turns.
local function addLean(ctx: Types.Ctx, dt: number)
	local A = Tuning.Anim
	local P = Tuning.Poses
	local level = MathUtil.flat(ctx.Velocity, ctx.Up)
	local accel = if dt > 1e-4 then (level - lastLevel) / dt else Vector3.zero
	lastLevel = level
	if not LEAN_STATES[ctx.State] then
		accel = Vector3.zero
	end
	leanAccel = leanAccel:Lerp(accel, math.clamp(A.LeanSmooth * dt, 0, 1))
	local right = ctx.Heading:Cross(ctx.Up)
	local forward = math.clamp(leanAccel:Dot(ctx.Heading) * A.LeanPerAccel, -A.LeanMax, A.LeanMax)
	local side = math.clamp(leanAccel:Dot(right) * A.LeanPerAccel, -A.LeanMax, A.LeanMax)
	addPose(P.LeanForward, forward)
	addPose(P.LeanSide, side)
end

local function buildTargets(ctx: Types.Ctx, now: number, dt: number)
	local P = Tuning.Poses
	local A = Tuning.Anim
	for _, joint in joints do
		local t = joint.Target
		t[1], t[2], t[3], t[4], t[5] = 0, 0, 0, 0, 0
	end

	local state = ctx.State
	local speed = ctx.Velocity.Magnitude
	local climb = ctx.Velocity:Dot(ctx.Up)

	-- The flying punch: for the attack window after a release, in the air, the punch pose takes over the
	-- state's pose (held, then eased out), so a dash reads as a punch rather than a dive.
	local flight = 0
	if not GROUND_STATES[state] then
		local p = (now - ctx.PunchFiredAt) / math.max(Tuning.Smash.PunchWindow, 1e-3)
		if p >= 0 and p < 1 then
			local hold = A.PunchFlightHold
			flight = if p < hold then 1 else 1 - ((p - hold) / math.max(1 - hold, 1e-3)) ^ 2
		end
	end
	local stateWeight = 1 - flight * A.PunchFlightOverride

	if state == "Burst" then
		addPose(P.Burst, 1)
	elseif state == "Hang" then
		addPose(P.Hang, 1)
		addPose(P.HangBreath, math.sin(2 * math.pi * ctx.StateTime / A.HangBreathPeriod))
	elseif state == "Glide" then
		addPose(P.Glide, stateWeight)
		addPose(P.GlideBank, ctx.Bank / Tuning.Glide.BankMax)
		-- Wing life: flex with the climb, and a slow flutter (per unit of the GlideFlex pose's 16° sweep).
		local flex = math.clamp(climb / math.max(A.GlideFlexRef, 1e-3), -1, 1)
		local flutter = math.sin(now * 2 * math.pi * A.GlideFlutterHz) * A.GlideFlutter / 16
		addPose(P.GlideFlex, (flex + flutter) * stateWeight)
	elseif state == "Dive" then
		addPose(P.Dive, stateWeight)
		addPose(P.DiveTight, math.clamp(ctx.StateTime / A.DiveTightenTime, 0, 1) * stateWeight)
		addPose(P.DiveSpeed, saturate(speed, A.DiveSpeedRef) * stateWeight)
		local vibration = A.DiveShake * (1 - math.exp(-speed / A.DiveShakeRef))
		local root = joints.Root
		if root then
			local t = now * A.DiveShakeFrequency
			root.Target[4] += math.noise(t, NOISE_SEED_V) * 2 * vibration
			root.Target[5] += math.noise(t, NOISE_SEED_S) * 2 * vibration
		end
	elseif state == "Swoop" then
		addPose(P.Swoop, stateWeight)
		addPose(P.GlideBank, ctx.Bank / Tuning.Glide.BankMax)
	elseif state == "Slide" then
		addPose(P.Slide, 1)
	elseif state == "Hop" then
		addPose(P.Hop, stateWeight)
		addPose(P.HopFall, math.clamp(-climb / math.max(A.HopFallRef, 1e-3), 0, 1) * stateWeight)
	end
	addPose(P.PunchFlight, flight)

	-- Jump charge: the squat deepens with the Space hold and trembles as the Burst charge climbs.
	if GROUND_STATES[state] then
		local held = JumpCheck.held()
		if state == "Charging" then
			addPose(P.Squat, 1)
			local charge = math.clamp((held or 0) / lastBurstTier(), 0, 1)
			addNoise("Root", now, A.SquatTremble * charge, 1, 3)
		else
			local hop = JumpCheck.hopCharge()
			if hop then
				addPose(P.Squat, A.SquatHopDepth * hop)
			end
		end
	end

	-- Punch charge: the upper body winds back over the basic charge, then keeps pulling through the tiers.
	local hold = ctx.PunchHold
	if hold then
		local basic = math.clamp(hold / Tuning.Punch.ChargeTime, 0, 1)
		local tiers = math.clamp(
			(hold - Tuning.Punch.ChargeTime) / math.max(lastPunchTier() - Tuning.Punch.ChargeTime, 1e-3),
			0,
			1
		)
		addPose(P.Wind, basic + A.WindOvercharge * tiers)
		addNoise("RShoulder", now, A.WindTremble * tiers, 1, 3)
	end

	-- Blast charge: both hands drawn to the hip over the charge time, trembling as the tiers climb; the beam
	-- braces both arms forward while it fires.
	local blastHold = Blast.cappedHold(ctx)
	if blastHold then
		local basic = math.clamp(blastHold / Tuning.Blast.ChargeTime, 0, 1)
		local strengths = Tuning.Blast.HoldStrengths
		local tiers = math.clamp(blastHold / strengths[#strengths][1], 0, 1)
		-- Past the fourth circle the hands go up to hold the spirit bomb.
		local spirit = if Blast.kindFor(blastHold) == "Spirit" then 1 else 0
		addPose(P.BlastCharge, basic * (1 - spirit))
		addPose(P.BlastSpirit, spirit)
		addNoise("LShoulder", now, A.WindTremble * tiers, 1, 3)
	end
	if ctx.BeamUntil > now then
		addPose(P.BlastFire, 1)
	end

	addLook(ctx)
	addLean(ctx, dt)

	-- One-shots: the punch, takeoff stretch, touchdown squash, the three-point landing, hit recoil, the
	-- break-through snap and the ignition whip.
	addPose(P.PunchOut, kickValue("PunchOut", now))
	addPose(P.Squash, kickValue("Squash", now))
	addPose(P.Stretch, kickValue("Stretch", now))
	addPose(P.ThreePoint, kickValue("ThreePoint", now))
	addPose(P.Recoil, kickValue("Recoil", now))
	addPose(P.Through, kickValue("Through", now))
	addPose(P.BurstKick, kickValue("BurstKick", now))
	addPose(P.BlastShot, kickValue("BlastShot", now))
end

-- Every channel follows its target on a damped spring, substepped for stability at the snap frequency.
local function writeJoints(dt: number, now: number)
	local A = Tuning.Anim
	local snapping = now < snapUntil
	local omega = 2 * math.pi * (if snapping then A.SnapFrequency else A.SpringFrequency)
	local damping = if snapping then A.SnapDamping else A.SpringDamping
	local steps = math.clamp(math.ceil(dt / SPRING_SUBSTEP), 1, SPRING_MAX_SUBSTEPS)
	local h = dt / steps
	for _, joint in joints do
		local c, v, t = joint.Current, joint.Velocity, joint.Target
		for index = 1, 5 do
			local x, vel = c[index], v[index]
			for _ = 1, steps do
				vel += (omega * omega * (t[index] - x) - 2 * damping * omega * vel) * h
				x += vel * h
			end
			c[index], v[index] = x, vel
		end
		-- Part1 = Part0 × C0 × Transform × C1⁻¹. The offset wants to sit at the pivot in Part0's axes:
		-- Part0 × [translation] × [rotation in Part0's axes] × C0 × clip, so Transform = C0⁻¹ × that × clip.
		local pivot = CFrame.new(joint.Position + Vector3.new(0, c[4], -c[5]))
			* CFrame.fromEulerAnglesYXZ(math.rad(c[1]), math.rad(c[2]), math.rad(c[3]))
			* joint.Rotation
		local motor = joint.Motor
		local current: CFrame = motor.Transform
		-- If nothing rewrote the Transform since our last write, the clip's contribution is what it was then.
		local base = if joint.LastWritten ~= nil and current == joint.LastWritten then joint.LastBase else current
		local written = joint.Inverse * pivot * base
		motor.Transform = written
		joint.LastWritten = written
		joint.LastBase = base
	end
end

local function update(dt: number)
	local ctx = Controller.ctx
	if not ctx or not ctx.Root.Parent then
		return
	end
	if ctx.Character ~= character then
		bind(ctx)
	elseif jointCount() < expectedJoints and os.clock() - boundAt < BIND_RETRY_TIME then
		findJoints(ctx.Character)
	end
	local now = os.clock()
	playClip(chooseClip(ctx))
	buildTargets(ctx, now, dt)
	writeJoints(dt, now)
end

function Anim.start()
	local A = Tuning.Anim
	Controller.StateChanged:Connect(function(_from, to, payload)
		snap()
		if to == "Hop" then
			kick("Stretch", 1, A.StretchTime)
		elseif to == "Burst" then
			kick("BurstKick", 1, A.BurstKickTime)
		elseif to == "Landing" or to == "Slide" then
			local speed = if payload ~= nil and payload.Speed then payload.Speed else 0
			kick("Squash", math.clamp(speed / A.SquashFullSpeed, A.SquashMin, 1), A.SquashTime)
			-- A fast dive landing is the three-point landing (spec §4.8): held through the hitstop and a beat.
			if to == "Landing" and payload ~= nil and payload.FromDive and speed >= A.ThreePointMinSpeed * 0.5 then
				local amount = math.clamp(speed / math.max(A.ThreePointMinSpeed, 1e-3), 0, 1)
				kick("ThreePoint", amount, A.ThreePointTime, A.ThreePointHold)
			end
		end
	end)
	Punch.Fired:Connect(function(kind)
		if kind == "Dash" or kind == "Rocket" then
			snap()
			kick("PunchOut", 1, A.PunchOutTime)
		end
	end)
	Blast.Fired:Connect(function(kind)
		if kind == "Shot" then
			snap()
			kick("BlastShot", 1, A.BlastShotTime)
		elseif kind == "Beam" then
			snap()
		end
	end)
	-- Hitting something that holds folds the body back by how hard it resisted; a bounce off a wall the same.
	Controller.Damaged:Connect(function(_model, _position, _left, effort)
		snap()
		kick("Recoil", math.clamp(effort / math.max(A.RecoilFullSpeed, 1e-3), A.RecoilMin, 1), A.RecoilTime)
	end)
	Controller.Bounced:Connect(function(_position, speed)
		snap()
		kick("Recoil", math.clamp(speed / math.max(A.RecoilFullSpeed, 1e-3), A.RecoilMin, 1), A.RecoilTime)
	end)
	-- Breaking through: the lead fist punches on.
	Controller.BrokeThrough:Connect(function(_model, _position, speed)
		snap()
		kick("Through", math.max(0.4, saturate(speed, A.ThroughFullSpeed)), A.ThroughTime)
	end)
	-- After the Animator has written this frame's clip Transforms, before physics poses the parts.
	RunService.PreSimulation:Connect(update)
end

return Anim
