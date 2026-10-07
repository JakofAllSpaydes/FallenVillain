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
	},

	Walk = {
		Speed = 24,
	},

	Hop = {
		Height = 60,
		ChargedHeight = 120,
		ChargeTime = 0.4,
		ApexFloatTime = 0.35,
		ChainWindow = 0.2,
		ChainBonus = 0.1,
		MaxChain = 3,
		BurstChargeGain = 0.04,
	},

	Charging = {
		CancelThreshold = 0.4,
	},

	Burst = {
		BaseVelocity = 350,
		VelocityPerPower = 45,
		MaxVelocity = 1400,
		IgnitionTime = 0.3,
		NoSteerTime = 0.5,
		DriftFraction = 0.15,
		HangEntryVerticalSpeed = 5,
	},

	Hang = {
		MinTime = 2,
		MaxTime = 6,
		DriftSpeed = 8,
	},

	Glide = {
		ForwardSpeed = 90,
		SinkMin = 12,
		SinkMax = 30,
		PitchMin = -35,
		PitchMax = 25,
		YawRate = 90,
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
	},

	Swoop = {
		MinEntrySpeed = 150,
		LiftFraction = 0.55,
		MaxLift = 160,
		BleedPerSecond = 0.35,
		ExitSpeed = 90,
		Cooldown = 1.2,
		MaxAirGainFraction = 0.25,
	},

	Impact = {
		RecoveryTime = 0.4,
		LandingTime = 0.8,
		RadiusBase = 6,
		RadiusSpeedDivisor = 8,
		DamagePerSpeed = 2,
		GroundSmashHopHeight = 10,
		GroundSmashRadius = 14,
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
	},

	Camera = {
		BaseFov = 70,
	},
}

return Tuning
