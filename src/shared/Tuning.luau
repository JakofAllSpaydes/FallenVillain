--!strict
-- Every tunable number in the game lives here (spec §3, §4, §6). Never inline a number in gameplay code.

local Tuning = {
	Gravity = {
		Default = 196.2,
		Grounded = 196,
		BurstIgnition = 0,
		Burst = 60,
		Hang = 4,
		Glide = 40,
		DiveStart = 196,
		DiveEnd = 260,
		DiveRampTime = 2,
		Swoop = 40,
		HopApexFloat = 20,
		Hop = 196,
	},

	Walk = {
		Speed = 24,
	},

	Hop = {
		Height = 12, -- tap hop: a little over a default Roblox jump (7.2)
		ChargedHeight = 30, -- hop released just before HoldTime
		TapTime = 0.1, -- holds shorter than this are a plain tap
		HoldTime = 1, -- holding Space this long on the ground starts Charging a Burst instead
		ApexFloatTime = 0.35,
		ChainWindow = 0.2,
		ChainBonus = 0.35, -- extra height per chained hop
		ChainForwardBoost = 15, -- forward speed each chained hop adds
		GlideClearance = 25, -- a hop only opens into a glide with this much air below its apex; lower, it falls
		MaxChain = 3,
		AirControlSpeed = 30,
		AirControlAccel = 90,
	},

	-- LMB punch. Holding charges it without locking movement (at a small speed cost). Releasing cancels whatever
	-- you are doing: a surface under the crosshair within Reach is a rocket jump, otherwise a dash at the crosshair.
	Punch = {
		ChargeTime = 0.6,
		MinPower = 0.5, -- rocket strength of a tap punch
		ChargeWalkMult = 0.8,
		ChargeHopMult = 0.85,
		ChargeGlideMult = 0.9,
		Reach = 60, -- clearance in studs within which a steep punch at a surface rocket-jumps
		RocketMinAngle = 45, -- degrees below level the aim must be for a rocket jump; shallower is just a dash
		RocketForwardShare = 0.6, -- share of the dash burst a rocket jump adds along your facing
		ProximityExponent = 4, -- higher makes the point-blank sweet spot sharper
		MinProximity = 0.2, -- a punch at the edge of Reach still bounces this much
		Impulse = 320, -- launch speed of a full punch at point blank with no momentum
		Reflect = 1, -- extra share of the speed you were moving into the surface that bounces back
		GroundedMult = 0.6, -- rocket strength when punching from the ground instead of timing it from the air
		MaxLaunchSpeed = 520,
		DashTapSpeed = 80, -- dash added by a tap punch
		DashFullSpeed = 240, -- dash added by a fully charged punch
		DashDecayTap = 12, -- 1/seconds a tap punch's added speed dies off at: a sharp jab
		DashDecayFull = 1.5, -- a fully charged punch's added speed lasts much longer
		DashKeepSideways = 0.3, -- share of velocity across the dash direction that survives it
		MaxDashSpeed = 320,
		GroundDashLift = 35, -- a ground dash always leaves the ground with at least this much upward speed
		DashEnergyCost = 10,
		Cooldown = 0.25,
	},

	Burst = {
		BaseVelocity = 350,
		VelocityPerPower = 45,
		MaxVelocity = 1400,
		-- Height reached for a Space hold of N seconds (from the press), interpolated geometrically between points
		-- so it starts gentle and climbs harder the longer you hold. Power caps it.
		HoldHeights = {
			{ 1, 60 },
			{ 3, 250 },
			{ 5, 450 },
			{ 10, 1000 },
			{ 15, 1400 },
			{ 25, 3000 },
			{ 30, 3700 },
			{ 60, 16000 },
		},
		FeelFullHeight = 1500, -- Burst height at which byCharge effects reach full strength
		MinFeelCharge = 0.15,
		IgnitionTime = 0.3,
		NoSteerTime = 0.5,
		DriftSpeed = 15,
		DriftAccel = 30,
		HangEntryVerticalSpeed = 5,
	},

	Hang = {
		Time = 4, -- spec range is 2–6 s; the Hang stat that spreads it is cut from MVP
		MinTime = 0.4, -- small Bursts hang for Time scaled by their feel charge, never less than this
		DriftSpeed = 8,
		DriftAccel = 12,
	},

	Charging = {
		Damping = 4, -- 1/seconds; momentum bleeds off hard while charging instead of stopping dead
	},

	Landing = {
		Damping = 6, -- 1/seconds; touchdown momentum bleeds toward walking
		MinTime = 0.15,
		MaxTime = 0.8,
		SettleSpeed = 4, -- hand over to walking once within this much of walk speed
	},

	Glide = {
		ForwardSpeed = 90,
		SinkMin = 12,
		SinkMax = 30,
		PitchMin = -35,
		PitchMax = 25,
		YawRate = 90,
		Accel = 60,
		Decel = 40, -- braking toward a lower target when pitched up
		OverspeedBleed = 10, -- how slowly speed above ForwardSpeed bleeds off, so boosts and chains carry
		PitchResponse = 4,
		PitchUpSpeedFactor = 0.6,
		SinkRecovery = 120,
		BankMax = 30,
		BankResponse = 6,
		BodyPitchFraction = 0.5,
		LookFollowWeight = 1,
		LookFollowFullAngle = 45,
	},

	GlideEnergy = {
		Max = 100,
		DrainPerSecond = 6,
		RingRefill = 20,
		ThermalRefill = 10,
		StrainThreshold = 20,
		StrainSinkMultiplier = 2,
	},

	Dive = {
		Thrust = 120,
		TerminalStart = 380,
		TerminalEnd = 420,
		ConeStart = 25,
		ConeEnd = 60,
		ConeWidenTime = 1,
		SteerRate = 35,
		TerminalRampTime = 2,
		MaxPitch = -10,
		MinHoldTime = 0.2, -- a tapped dive lasts this long
	},

	Swoop = {
		MinEntrySpeed = 150,
		LiftFraction = 0.55,
		MaxLift = 160,
		BleedPerSecond = 0.35,
		ExitSpeed = 90,
		Cooldown = 1.2,
		MaxAirGainFraction = 0.25,
		EnergyCost = 15,
		PullUpRate = 240, -- degrees per second the flight path rotates upward
		SteepFraction = 0.3, -- below this share of horizontal speed, pull up toward the camera look
		YawRate = 120,
	},

	Impact = {
		RecoveryTime = 0.4,
		RadiusBase = 6,
		RadiusSpeedDivisor = 8,
		DamagePerSpeed = 2,
		WaveSpeed = 200,
	},

	Laser = {
		MaxRange = 1200,
		BaseWidth = 2,
		WidthPerAltitude = 1 / 1000,
		BaseDps = 40,
		DpsPerAltitude = 1 / 40,
		EnergyMax = 100,
		EnergyDrain = 30,
		EnergyRefill = 25,
		FallSlowdown = 0.3,
		CutterWidth = 1,
		CutterDps = 25,
		SweepSampleSpacing = 4,
		HitBatchInterval = 0.1,
	},

	Combo = {
		Window = 4,
		MaxCount = 20,
		MultPerHit = 0.2,
	},

	Economy = {
		AltitudeMultDivisor = 2000,
		CashPerAltitudeOnLanding = 1 / 100,
		RingCash = 20,
		PowerMaxLevel = 25,
		PowerBaseCost = 100,
		PowerCostGrowth = 1.4,
		JetpackCost = 5000,
	},

	Input = {
		StickDeadzone = 0.2,
	},

	Aim = {
		MaxDistance = 2000,
		MagnetRadius = 30,
		MagnetStrength = 0.4,
		FirstRunMagnetStrength = 0.7,
	},

	Physics = {
		MaxDt = 1 / 30,
		GroundRayLength = 6,
		LandingVerticalSpeed = -20,
		ImpactLookahead = 4,
		LandSnap = 0.5,
		CeilingDecel = 150, -- how hard climbs round off into the air-gain ceiling
		MinGroundNormalY = 0.6,
		AirborneGraceTime = 0.15,
		AlignResponsiveness = 40,
		AlignMaxTorque = 1e7,
		BounceRestitution = 0.7, -- share of the speed into a non-destructible wall that bounces back
		GroundHoldProbe = 4, -- how far below standing height ground states look for the floor
		BounceProbe = 2, -- studs beyond this frame's travel to look for walls
	},

	World = {
		EdgeWallMargin = 40,
		FallOffDepth = 60,
	},

	-- Hidden movement tech. All of it comes from input timing; MaxCarrySpeed caps what chains can build.
	Tech = {
		MaxCarrySpeed = 180,
		PerfectHopBonus = 0.1, -- extra speed for a chain hop inside Hop.ChainWindow
		SlideMinSpeed = 60,
		SlideMaxAngle = 45, -- degrees below horizontal; steeper touchdowns land instead of sliding
		SlideKeep = 0.95,
		SlideFriction = 110, -- high so a dive-slide is a short burst, not a glide along the ground
		SlideExitSpeed = 25,
		SlideYawRate = 60,
		SlideLean = 35, -- degrees the body leans back while sliding
		SkimHeight = 25, -- a swoop arc passing this close to the ground skims
		SkimBoost = 0.2,
		SkimPitch = 3,
		MaxSkimSpeed = 480,
	},

	GroundShadow = {
		Diameter = 5,
		MinScale = 0.5, -- size at MaxHeight
		Transparency = 0.4, -- on the ground; fades to invisible at MaxHeight
		MaxHeight = 500,
	},

	Camera = {
		BaseFov = 70,
		FocusHeight = 2,
		DistanceResponse = 4,
		CollisionMargin = 1,
		ShoulderOffset = 2.5, -- camera sits right of the character so it never covers the crosshair
		StartPitch = -15,
		PitchMin = -85,
		PitchMax = 60,
		MouseSensitivity = 0.25, -- degrees per pixel, times the player's Roblox sensitivity setting
		StickYawRate = 220,
		StickPitchRate = 140,
		Distance = {
			Grounded = 16,
			Charging = 14,
			Burst = 12,
			Hang = 20,
			Hop = 16,
			Landing = 16,
			Glide = 18,
			Dive = 10,
			Swoop = 18,
			Slide = 14,
		},
	},

	-- FeelTable (spec §4, §12): every effect, keyed by event. Juice.luau documents the entry keys.
	-- Frame timings from §4 are at 60 fps: frame 2 = 0.033 s, frame 4 = 0.066 s, frame 8 = 0.133 s.
	Feel = {
		Grounded = { { loop = "Wind", to = 0.15, dur = 1 } },
		Landing = { { loop = "Wind", to = 0.15, dur = 0.6 } },
		Hop = { { sound = "Hop" }, { loop = "Wind", to = 0.25, dur = 0.3 } },
		Glide = { { loop = "Wind", to = 0.4, dur = 0.5 } },
		Dive = { { loop = "Wind", to = 0.85, dur = 0.3 } },
		Swoop = { { loop = "Wind", to = 0.6, dur = 0.3 } },
		Slide = { { loop = "Wind", to = 0.5, dur = 0.3 } },

		-- §4.1: the hold narrows everything in. The crack and light are the charge bar. Ramps run over the
		-- first seconds of the hold; the Burst height keeps climbing after they finish.
		Charging = {
			{ cam = "fovOffset", to = -8, dur = 8 },
			{ cam = "shake", from = 0.05, to = 0.3, freq = 20, dur = 8 },
			{ cam = "tilt", to = -3, dur = 8 },
			{ post = "Saturation", to = -0.4, dur = 8 },
			{ post = "Contrast", to = 0.15, dur = 8 },
			{ post = "Vignette", to = 0.5, dur = 8 },
			{ bus = "Ambient", to = 0.4, dur = 0.5 },
			{ loop = "Wind", to = 0, dur = 1 },
			{ loop = "ChargeDrone", from = 0, to = 1, dur = 0.3, pitchFrom = 0, pitchTo = 2, pitchDur = 8 },
			{ vfx = "CrackRadius", from = 4, to = 14, dur = 8, delay = 0.3 },
			{ vfx = "ChestLight", to = 8, dur = 8 },
			{ vfx = "ChargeBeam", to = 0.4, dur = 8 },
		},

		-- Leaving Charging any way (Burst, or a punch cancelling it) clears the charge effects.
		ExitCharging = {
			{ cam = "fovOffset", to = 0, dur = 0.3 },
			{ cam = "shake", to = 0, dur = 0.3 },
			{ cam = "tilt", to = 0, dur = 0.3 },
			{ post = "Saturation", to = 0, dur = 0.3 },
			{ post = "Contrast", to = 0, dur = 0.3 },
			{ post = "Vignette", to = 0, dur = 0.3 },
			{ bus = "Ambient", to = 0, dur = 0.3 },
			{ loop = "ChargeDrone", to = 0, dur = 0.3 },
			{ vfx = "CrackRadius", to = 0, dur = 0.3 },
			{ vfx = "ChestLight", to = 0, dur = 0.3 },
			{ vfx = "ChargeBeam", to = 0, dur = 0.3 },
		},

		-- §4.2 ignition and §4.3 ascent. Freeze and silence first, then the cannon shot. byCharge entries scale
		-- with how long the Burst was charged.
		Burst = {
			{ time = 0.15, dur = 0.12 },
			{ bus = "Ambient", to = 1, dur = 0 },
			{ bus = "Wind", to = 1, dur = 0 },
			{ bus = "Music", to = 1, dur = 0 },
			{ bus = "Ambient", to = 0, dur = 0.3, delay = 0.12 },
			{ bus = "Wind", to = 0, dur = 0.05, delay = 0.12 },
			{ bus = "Music", to = 0, dur = 0.3, delay = 0.12 },
			{ sound = "SubHit", minHeld = 5 },
			{ sound = "BurstHop", maxHeld = 5 },
			{ post = "Flash", kick = 0.9, dur = 0.25, byCharge = true },
			{ spawn = "Shockwave", radius = 60, alpha = 0.8, dur = 0.6, byCharge = true },
			{ spawn = "Debris", count = 24, speedMin = 40, speedMax = 80, upBias = 0.5, life = 2, byCharge = true },
			{ spawn = "LightColumn", height = 3000, width = 4, alpha = 0.7, dur = 3, byCharge = true },
			{ vfx = "CrackRadius", to = 0, dur = 0 },
			{ vfx = "ChargeBeam", to = 0, dur = 0 },
			{ vfx = "ChestLight", to = 0, dur = 0.3 },
			{ loop = "ChargeDrone", to = 0, dur = 0 },
			{ cam = "shake", to = 0, dur = 0 },
			{ cam = "tilt", to = 0, dur = 0 },
			{ post = "Saturation", to = 0, dur = 0.4 },
			{ post = "Contrast", to = 0, dur = 0.4 },
			{ post = "Vignette", to = 0, dur = 0.4 },
			{ cam = "recoilDown", kick = 2, dur = 0.3, delay = 0.033, byCharge = true },
			{ cam = "recoilBack", kick = 3, dur = 0.3, delay = 0.033, byCharge = true },
			{ cam = "shake", kick = 1.2, freq = 35, dur = 0.6, delay = 0.033, byCharge = true },
			{ cam = "fovOffset", to = 35, dur = 0.15, delay = 0.033, byCharge = true },
			{ post = "Blur", to = 12, dur = 0.1, delay = 0.033, byCharge = true },
			{ post = "Blur", to = 0, dur = 0.4, delay = 0.2 },
			{ sound = "BurstCrack", delay = 0.066, minHeld = 5 },
			{ spawn = "Dust", count = 200, delay = 0.066, byCharge = true },
			{ loop = "Wind", to = 1, dur = 0.05, delay = 0.133 },
			{ vfx = "Trails", to = 1, dur = 0 },
			-- Ascent: FOV 105 → 85, camera pulls back 12 → 20 and tilts up, wind thins.
			{ cam = "fovOffset", to = 15, durAscent = 0.9, delay = 0.2 },
			{ cam = "distanceOffset", to = 8, durAscent = 1 },
			{ cam = "tilt", to = 10, durAscent = 1 },
			{ loop = "Wind", to = 0.15, durAscent = 0.8, delay = 1 },
			-- Deceleration cue just before the apex.
			{ sound = "ApexBell", atApex = -0.8 },
			{ vfx = "Trails", to = 0, dur = 0, atApex = -0.8 },
		},

		-- Leaving Burst early (a punch) drops the ascent camera; Hang overrides these when it follows.
		ExitBurst = {
			{ vfx = "Trails", to = 0, dur = 0 },
			{ cam = "fovOffset", to = 0, dur = 0.5 },
			{ cam = "distanceOffset", to = 0, dur = 0.8 },
			{ cam = "tilt", to = 0, dur = 0.5 },
		},

		-- §4.4: the slow pull-back, silence, the god-ray, the altitude.
		Hang = {
			{ sound = "HangChime" },
			{ cam = "fovOffset", to = 0, dur = 1.5 },
			{ cam = "distanceOffset", to = 18, dur = 1.5 },
			{ cam = "tilt", to = 0, dur = 1.5 },
			{ cam = "shake", to = 0, dur = 0 },
			{ post = "Bloom", to = 0.3, dur = 1.5 },
			{ post = "Vignette", to = 0.2, dur = 1.5 },
			{ post = "SunRays", to = 0.2, dur = 1.5 },
			{ loop = "Wind", to = 0, dur = 0.6 },
			{ ui = "Altitude", to = 1, dur = 0.8, record = 1 },
		},
		ExitHang = {
			{ sound = "WingFold" },
			{ cam = "distanceOffset", to = 0, dur = 1 },
			{ post = "Bloom", to = 0, dur = 0.6 },
			{ post = "Vignette", to = 0, dur = 0.6 },
			{ post = "SunRays", to = 0, dur = 0.6 },
			{ ui = "Altitude", to = 0, dur = 0.4 },
		},

		Rocket = {
			{ sound = "RocketPop" },
			{ cam = "shake", kick = 0.5, freq = 30, dur = 0.3 },
			{ cam = "fovOffset", kick = 6, dur = 0.3 },
			{ spawn = "Dust", count = 30 },
		},
		Dash = {
			{ sound = "Dash" },
			{ cam = "fovOffset", kick = 5, dur = 0.3 },
		},
		-- Bouncing off a wall that isn't destructible.
		Bounce = {
			{ sound = "Bounce" },
			{ cam = "shake", kick = 0.4, freq = 30, dur = 0.25 },
		},
		-- Another player's burst (spec §7): the column everyone sees.
		RemoteBurst = {
			{ spawn = "LightColumn", height = 3000, width = 4, alpha = 0.7, dur = 3 },
			{ spawn = "Shockwave", radius = 60, alpha = 0.5, dur = 0.6 },
		},
	},

	-- Placeholder sounds from the engine's built-in content until the audio pass (milestone 7).
	Sounds = {
		Wind = { Id = "rbxasset://sounds/action_falling.ogg", Bus = "Wind", Volume = 0.6, Pitch = 1, Loop = true },
		ChargeDrone = {
			Id = "rbxasset://sounds/action_falling.ogg",
			Bus = "Sfx",
			Volume = 0.8,
			Pitch = 0.4,
			Loop = true,
		},
		SubHit = { Id = "rbxasset://sounds/impact_explosion_03.mp3", Bus = "Sfx", Volume = 1, Pitch = 0.4 },
		BurstCrack = { Id = "rbxasset://sounds/impact_explosion_03.mp3", Bus = "Sfx", Volume = 1, Pitch = 1 },
		Hop = { Id = "rbxasset://sounds/action_jump.mp3", Bus = "Sfx", Volume = 0.6, Pitch = 1 },
		BurstHop = { Id = "rbxasset://sounds/action_jump.mp3", Bus = "Sfx", Volume = 0.8, Pitch = 0.8 },
		Exhale = { Id = "rbxasset://sounds/action_jump.mp3", Bus = "Sfx", Volume = 0.5, Pitch = 0.6 },
		ApexBell = { Id = "rbxasset://sounds/volume_slider.ogg", Bus = "Sfx", Volume = 0.6, Pitch = 1.5 },
		HangChime = { Id = "rbxasset://sounds/volume_slider.ogg", Bus = "Sfx", Volume = 0.5, Pitch = 2 },
		WingFold = { Id = "rbxasset://sounds/action_get_up.mp3", Bus = "Sfx", Volume = 0.5, Pitch = 0.7 },
		RocketPop = { Id = "rbxasset://sounds/action_jump_land.mp3", Bus = "Sfx", Volume = 0.5, Pitch = 0.8 },
		Dash = { Id = "rbxasset://sounds/action_jump.mp3", Bus = "Sfx", Volume = 0.6, Pitch = 1.4 },
		Bounce = { Id = "rbxasset://sounds/action_jump_land.mp3", Bus = "Sfx", Volume = 0.4, Pitch = 1.2 },
	},

	Audio = {
		BusVolume = 0.25,
		PitchJitter = 0.05,
		LowPassMidShare = 0.3, -- share of the altitude low-pass applied to mids
	},

	Vfx = {
		GroundProbe = 40,
		CrackColor = Color3.fromRGB(35, 33, 30),
		CrackTransparency = 0.15,
		ChargeBeamHeight = 400,
		ChargeBeamWidth = 0.5,
		ChestLightRange = 18,
		LightColor = Color3.fromRGB(255, 244, 220),
		TrailSpan = 2.5, -- wingtip distance from the body centre
		TrailWidth = 1.5,
		TrailLifetime = 1.2,
		TrailTransparency = 0.2,
		ShockwavePool = 4,
		DebrisPool = 30,
		DebrisSize = 0.8,
		DebrisColor = Color3.fromRGB(90, 86, 80),
		DebrisFade = 0.5,
		ColumnPool = 6,
		DustTexture = "rbxasset://textures/particles/smoke_main.dds",
		DustLifetimeMin = 0.9,
		DustLifetimeMax = 1.5,
		DustSpeedMin = 20,
		DustSpeedMax = 60,
		DustDrag = 3,
		DustSizeStart = 3,
		DustSizeEnd = 8,
		DustTransparency = 0.4,
		DustColor = Color3.fromRGB(170, 165, 155),
	},

	Sky = {
		Smoothing = 0.5, -- seconds; band transitions ease with this time constant
	},

	Net = {
		BurstMinInterval = 5, -- spec §13 rate limit
		MaxPositionError = 40, -- reported positions further than this from the replicated character are ignored
	},

	Ui = {
		AltitudeTop = 48,
		AltitudeAlpha = 0.5,
		RecordPulseTime = 1,
		PunchWheelSize = 34,
		PunchWheelOffset = 32, -- pixels right of and below the crosshair
		PunchWheelThickness = 4,
		PunchWheelTrackTransparency = 0.75,
		PunchWheelFade = 0.2,
		JumpWheelSize = 48,
		JumpWheelInnerScale = 0.62, -- inner (hop) ring size relative to the outer (Burst) ring
		JumpWheelThickness = 4,
		JumpWheelHeight = 4.5, -- studs above the root
		JumpWheelTrackTransparency = 0.75,
		JumpWheelFade = 0.2,
	},

	Dev = {
		DropAltitudes = { 300, 1000, 3000 },
		PowerPresets = { 1, 6, 11, 18, 25 },
		ShowControlsHud = true, -- tester cheat sheet in every build; turn off when milestone 7 hints land
	},
}

return Tuning
