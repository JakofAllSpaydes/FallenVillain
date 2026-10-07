--!strict
-- Character animation (spec §4, §10, §12; §15 milestone 3b). Two layers on the Humanoid rig, R15 first with
-- an R6 fallback (players use both):
--   * Locomotion: Roblox's own stock clips (idle, walk, run, jump, fall; Tuning.Anim.Clips) chosen by state and
--     ground speed, played through the Animator so they replicate. The character's default Animate script is
--     disabled: the controller owns every state, so this module owns every clip.
--   * Poses: every FALL-specific shape (jump-charge squat, punch wind-back, the punch, burst extension, hang,
--     glide, dive, swoop, slide, takeoff stretch, touchdown squash) is a set of joint offsets in Tuning.Poses.
--     Each frame the active poses are summed per joint with their weights, eased, and composed into the
--     joint's Transform in front of whatever the clip wrote, so a punch wind-back layers over a walk and a
--     squat deepens under an idle. Offsets are in the parent part's axes (see Tuning.Poses). Joints are
--     Motor6Ds on classic rigs and AnimationConstraints on current ones (C0 derived, read-only); both expose
--     Transform, which the Animator rewrites each frame for animated joints. Joints no clip is driving keep
--     the last Transform, so the layer remembers what it wrote and never compounds its own offset.
-- State enters and punches snap (spec §4.10: cut in, fade out); everything else eases. Tremble, breathing and
-- dive vibration are added as noise or sine on top of the poses. This module reads the controller; it never
-- drives movement.

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)

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
	Target: { number },
	LastWritten: CFrame?, -- the Transform this layer wrote last frame
	LastBase: CFrame, -- the clip's Transform that write was layered on
}
type Kick = { Start: number, Duration: number, Amount: number }

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
local BIND_RETRY_TIME = 5 -- seconds to keep looking for joints that load late; not a feel value
local FOREIGN_SWEEP_INTERVAL = 0.25 -- seconds between sweeps of the default Animate script's tracks
local NOISE_SEED_P, NOISE_SEED_S, NOISE_SEED_V = 3.7, 29.1, 61.3 -- decorrelate tremble axes; not a feel value

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

local function kickValue(name: string, now: number): number
	local kick = kicks[name]
	if not kick then
		return 0
	end
	local p = (now - kick.Start) / kick.Duration
	if p >= 1 then
		kicks[name] = nil
		return 0
	end
	return kick.Amount * (1 - p) ^ 2
end

local function kick(name: string, amount: number, duration: number)
	kicks[name] = { Start = os.clock(), Duration = math.max(duration, 1e-3), Amount = amount }
end

local function snap()
	snapUntil = os.clock() + Tuning.Anim.SnapTime
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

local function buildTargets(ctx: Types.Ctx, now: number)
	local P = Tuning.Poses
	local A = Tuning.Anim
	for _, joint in joints do
		local t = joint.Target
		t[1], t[2], t[3], t[4], t[5] = 0, 0, 0, 0, 0
	end

	local state = ctx.State
	local speed = ctx.Velocity.Magnitude
	if state == "Burst" then
		addPose(P.Burst, 1)
	elseif state == "Hang" then
		addPose(P.Hang, 1)
		addPose(P.HangBreath, math.sin(2 * math.pi * ctx.StateTime / A.HangBreathPeriod))
	elseif state == "Glide" then
		addPose(P.Glide, 1)
		addPose(P.GlideBank, ctx.Bank / Tuning.Glide.BankMax)
	elseif state == "Dive" then
		addPose(P.Dive, 1)
		addPose(P.DiveTight, math.clamp(ctx.StateTime / A.DiveTightenTime, 0, 1))
		local vibration = A.DiveShake * (1 - math.exp(-speed / A.DiveShakeRef))
		local root = joints.Root
		if root then
			local t = now * A.DiveShakeFrequency
			root.Target[4] += math.noise(t, NOISE_SEED_V) * 2 * vibration
			root.Target[5] += math.noise(t, NOISE_SEED_S) * 2 * vibration
		end
	elseif state == "Swoop" then
		addPose(P.Swoop, 1)
		addPose(P.GlideBank, ctx.Bank / Tuning.Glide.BankMax)
	elseif state == "Slide" then
		addPose(P.Slide, 1)
	elseif state == "Hop" then
		addPose(P.Hop, 1)
	end

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

	addPose(P.PunchOut, kickValue("PunchOut", now))
	addPose(P.Squash, kickValue("Squash", now))
	addPose(P.Stretch, kickValue("Stretch", now))
end

local function writeJoints(dt: number, now: number)
	local A = Tuning.Anim
	local rate = if now < snapUntil then A.SnapResponse else A.Response
	for _, joint in joints do
		local c, t = joint.Current, joint.Target
		for index = 1, 5 do
			c[index] = MathUtil.approach(c[index], t[index], rate, dt)
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
	buildTargets(ctx, now)
	writeJoints(dt, now)
end

function Anim.start()
	local A = Tuning.Anim
	Controller.StateChanged:Connect(function(_from, to, payload)
		snap()
		if to == "Hop" then
			kick("Stretch", 1, A.StretchTime)
		elseif to == "Landing" or to == "Slide" then
			local speed = if payload ~= nil and payload.Speed then payload.Speed else 0
			kick("Squash", math.clamp(speed / A.SquashFullSpeed, A.SquashMin, 1), A.SquashTime)
		end
	end)
	Punch.Fired:Connect(function(kind)
		if kind == "Dash" or kind == "Rocket" then
			snap()
			kick("PunchOut", 1, A.PunchOutTime)
		end
	end)
	-- After the Animator has written this frame's clip Transforms, before physics poses the parts.
	RunService.PreSimulation:Connect(update)
end

return Anim
