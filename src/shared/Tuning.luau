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
		Height = 60,
		ChargedHeight = 120,
		TapTime = 0.15, -- on the ground, Space released sooner is a hop; held longer charges (a Burst if full)
		ChargeTime = 0.4, -- extra hold past TapTime to reach ChargedHeight when the Burst charge isn't full
		ApexFloatTime = 0.35,
		ChainWindow = 0.2,
		ChainBonus = 0.1,
		MaxChain = 3,
		BurstChargeGain = 0.04,
		AirControlSpeed = 30,
		AirControlAccel = 90,
	},

	Charging = {
		CancelThreshold = 0.4, -- total Space hold; releasing sooner cancels the Burst
	},

	-- LMB punch. Holding charges it without locking movement (at a small speed cost). Releasing with a surface
	-- under the crosshair within Reach is a rocket jump; otherwise, in the air, a dash toward the crosshair.
	Punch = {
		ChargeTime = 0.6,
		MinPower = 0.3, -- power of a tap punch
		ChargeWalkMult = 0.8,
		ChargeHopMult = 0.85,
		ChargeGlideMult = 0.9,
		Reach = 30, -- clearance in studs between the body and the surface under the crosshair
		ProximityExponent = 2, -- higher rewards releasing closer to the surface
		Impulse = 150, -- launch speed of a full punch at point blank with no momentum
		Reflect = 0.5, -- extra share of the speed you were moving into the surface that bounces back
		MaxLaunchSpeed = 320,
		DashSpeed = 70,
		DashEnergyCost = 10,
		Cooldown = 0.25,
	},

	Burst = {
		BaseVelocity = 350,
		VelocityPerPower = 45,
		MaxVelocity = 1400,
		IgnitionTime = 0.3,
		NoSteerTime = 0.5,
		DriftSpeed = 15,
		DriftAccel = 30,
		HangEntryVerticalSpeed = 5,
	},

	Hang = {
		Time = 4, -- spec range is 2–6 s; the Hang stat that spreads it is cut from MVP
		DriftSpeed = 8,
		DriftAccel = 12,
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
		LandingTime = 0.8,
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

	Charge = {
		IdlePerSecond = 0.012,
		PerDestroyed = 0.02,
		PerRing = 0.12,
		PerThermal = 0.06,
		ImpactMax = 0.15,
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
		SlideFriction = 45,
		SlideExitSpeed = 25,
		SlideYawRate = 60,
		SlideGroundProbe = 4,
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

	Dev = {
		DropAltitudes = { 300, 1000, 3000 },
		PowerPresets = { 1, 6, 11, 18, 25 },
		ShowControlsHud = true, -- tester cheat sheet in every build; turn off when milestone 7 hints land
	},
}

return Tuning
