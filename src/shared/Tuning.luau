--!strict
-- Every tunable number in the game lives here (spec §3, §4, §6). Never inline a number in gameplay code.

-- A FeelTable entry (Juice.luau documents the keys) and a list of them. Annotated so strict mode doesn't try
-- to unify every differently shaped entry in a list.
export type FeelEntry = { [string]: any }
export type FeelList = { FeelEntry }

local function join(...: FeelList): FeelList
	local out: FeelList = {}
	for _, list in { ... } do
		for _, entry in list do
			table.insert(out, entry)
		end
	end
	return out
end

-- Touchdown and smash juice shared by Landing, Slide and a mid-air Smash (spec §4.8). bySpeed entries scale with
-- the contact speed from minSpeed to fullSpeed (review note: a mach-10 crash must feel far bigger than a hop):
-- the ordinary layer tops out at IMPACT_FULL, and a heavy layer keeps growing from HEAVY_MIN to HEAVY_FULL. A hop
-- landing is a soft thud; a dive from altitude is a hitstop, a flash, rings, a crater and flying debris; a
-- hypersonic crash is a longer freeze, a harder and longer shake, a wider third ring and a wall of debris.
local IMPACT_FULL = 900
local HEAVY_MIN, HEAVY_FULL = 600, 2000
-- A plain dive landing pounds at this share of the full radius (review note: too strong); a punch into the
-- ground gets the full one. Mirrored in Impact.PlainPoundScale for the server and the juice.
local PLAIN_POUND_SCALE = 0.7

-- A copy of a feel list with its smash-radius multiples scaled (the punch pound's full-size rings).
local function scaleRadii(list: FeelList, factor: number): FeelList
	local scaled = {}
	for _, entry in list do
		if entry.bySmashRadius then
			local copy = table.clone(entry)
			copy.radius = (copy.radius or 1) * factor
			table.insert(scaled, copy)
		else
			table.insert(scaled, entry)
		end
	end
	return scaled
end
local TOUCHDOWN: FeelList = {
	-- Every landing: a thud, a puff, a little camera dip.
	{ sound = "Land", volume = 1, bySpeed = true, minSpeed = 0, fullSpeed = 120 },
	{ spawn = "Dust", count = 40, bySpeed = true, minSpeed = 20, fullSpeed = 250 },
	{
		cam = "shake",
		kick = 1.4,
		freq = 40,
		dur = 0.5,
		curve = "expo",
		bySpeed = true,
		minSpeed = 60,
		fullSpeed = IMPACT_FULL,
	},
	{
		cam = "recoilDown",
		kick = 1.5,
		dur = 0.35,
		curve = "spring",
		bySpeed = true,
		minSpeed = 60,
		fullSpeed = IMPACT_FULL,
	},
	{ cam = "fovOffset", kick = -4, dur = 0.3, curve = "expo", bySpeed = true, minSpeed = 60, fullSpeed = IMPACT_FULL },
	-- A fast dive: the impact frame (hitstop, flash, desaturation), then the world reacts.
	{ sound = "HeavyLand", volume = 1, bySpeed = true, minSpeed = 150, fullSpeed = IMPACT_FULL },
	{ time = 0, dur = 0.18, durMin = 0.08, bySpeed = true, minSpeed = 150, fullSpeed = IMPACT_FULL },
	{ post = "Flash", kick = 0.75, dur = 0.3, curve = "expo", bySpeed = true, minSpeed = 150, fullSpeed = IMPACT_FULL },
	{ post = "Saturation", kick = -0.6, dur = 0.8, bySpeed = true, minSpeed = 150, fullSpeed = IMPACT_FULL },
	{ post = "Contrast", kick = 0.2, dur = 0.5, bySpeed = true, minSpeed = 150, fullSpeed = IMPACT_FULL },
	{ post = "Vignette", kick = 0.6, dur = 0.7, bySpeed = true, minSpeed = 150, fullSpeed = IMPACT_FULL },
	{ spawn = "Flash3D", size = 30, lift = 3, dur = 0.35, bySpeed = true, minSpeed = 150, fullSpeed = IMPACT_FULL },
	-- The ground pound's rings, crater and dust wall follow the real smash radius (review note: the AOE must
	-- visibly grow with speed), as multiples of it; bySpeed still scales their strength and counts.
	{
		spawn = "Shockwave",
		radius = 1,
		bySmashRadius = true,
		alpha = 0.9,
		dur = 0.45,
		bySpeed = true,
		minSpeed = 150,
		fullSpeed = IMPACT_FULL,
	},
	{
		spawn = "Shockwave",
		radius = 1.6,
		bySmashRadius = true,
		alpha = 0.45,
		dur = 0.7,
		delay = 0.08,
		bySpeed = true,
		minSpeed = 220,
		fullSpeed = IMPACT_FULL,
	},
	{
		spawn = "DustRing",
		radius = 0.7,
		bySmashRadius = true,
		count = 140,
		delay = 0.05,
		bySpeed = true,
		minSpeed = 150,
		fullSpeed = IMPACT_FULL,
	},
	{
		spawn = "Crater",
		radius = 0.45,
		bySmashRadius = true,
		dur = 12,
		bySpeed = true,
		minSpeed = 150,
		fullSpeed = IMPACT_FULL,
	},
	{
		spawn = "Debris",
		count = 28,
		speedMin = 30,
		speedMax = 75,
		upBias = 0.8,
		life = 2.4,
		bySpeed = true,
		minSpeed = 150,
		fullSpeed = IMPACT_FULL,
	},
	{ spawn = "Dust", count = 120, delay = 0.05, bySpeed = true, minSpeed = 150, fullSpeed = IMPACT_FULL },
	{ cam = "distanceOffset", kick = 6, dur = 0.9, bySpeed = true, minSpeed = 150, fullSpeed = IMPACT_FULL },
	{ bus = "Ambient", kick = 0.9, dur = 0.6, bySpeed = true, minSpeed = 150, fullSpeed = IMPACT_FULL },
	{ haptic = "Rumble", kick = 1, dur = 0.35, curve = "expo", bySpeed = true, minSpeed = 60, fullSpeed = IMPACT_FULL },
	-- The §4.8 silence: boom, then almost nothing for most of a second while the breaks arrive (Sfx stays open).
	{ bus = "Wind", kick = 0.95, dur = 0.7, curve = "hold", bySpeed = true, minSpeed = 150, fullSpeed = IMPACT_FULL },
	{ bus = "Music", kick = 0.95, dur = 0.7, curve = "hold", bySpeed = true, minSpeed = 150, fullSpeed = IMPACT_FULL },
	{ bus = "Ui", kick = 0.8, dur = 0.7, curve = "hold", bySpeed = true, minSpeed = 150, fullSpeed = IMPACT_FULL },
	-- The heavy layer: a hypersonic crash keeps growing past the ordinary one (the freeze below is the total).
	{
		cam = "roll",
		kick = 4,
		dur = 0.45,
		curve = "spring",
		randomSign = true,
		bySpeed = true,
		minSpeed = HEAVY_MIN,
		fullSpeed = HEAVY_FULL,
	},
	{ time = 0, dur = 0.38, durMin = 0.18, bySpeed = true, minSpeed = HEAVY_MIN, fullSpeed = HEAVY_FULL },
	{
		cam = "shake",
		kick = 1.6,
		freq = 30,
		dur = 1.3,
		curve = "expo",
		bySpeed = true,
		minSpeed = HEAVY_MIN,
		fullSpeed = HEAVY_FULL,
	},
	{
		post = "Flash",
		kick = 0.5,
		dur = 0.5,
		curve = "expo",
		bySpeed = true,
		minSpeed = HEAVY_MIN,
		fullSpeed = HEAVY_FULL,
	},
	{ post = "Vignette", kick = 0.5, dur = 1.2, bySpeed = true, minSpeed = HEAVY_MIN, fullSpeed = HEAVY_FULL },
	{
		spawn = "Shockwave",
		radius = 2.2,
		bySmashRadius = true,
		alpha = 0.7,
		dur = 0.95,
		delay = 0.12,
		bySpeed = true,
		minSpeed = HEAVY_MIN,
		fullSpeed = HEAVY_FULL,
	},
	{
		spawn = "DustRing",
		radius = 1.4,
		bySmashRadius = true,
		count = 200,
		delay = 0.12,
		bySpeed = true,
		minSpeed = HEAVY_MIN,
		fullSpeed = HEAVY_FULL,
	},
	{ spawn = "Flash3D", size = 60, lift = 6, dur = 0.5, bySpeed = true, minSpeed = HEAVY_MIN, fullSpeed = HEAVY_FULL },
	{
		spawn = "Debris",
		count = 30,
		speedMin = 60,
		speedMax = 140,
		upBias = 0.9,
		life = 3,
		bySpeed = true,
		minSpeed = HEAVY_MIN,
		fullSpeed = HEAVY_FULL,
	},
	{ cam = "distanceOffset", kick = 8, dur = 1.4, bySpeed = true, minSpeed = HEAVY_MIN, fullSpeed = HEAVY_FULL },
}

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
		Response = 8, -- 1/seconds; walking momentum eases toward the input, so starts and stops are weighted
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
		-- Lunge speed for an LMB hold of N seconds, geometric between points (the forward twin of Burst.HoldHeights):
		-- a jab on tap, a burst dash at the first charge, then climbing hard toward a lap of the planet.
		HoldBoosts = {
			{ 0, 45 }, -- review note: 80 on a tap added too much momentum
			{ 0.6, 220 },
			{ 3, 420 },
			{ 10, 1300 },
			{ 25, 4500 },
			{ 60, 14000 },
		},
		-- Seconds held where the charge steps up a tier: a chime, a new ring, bigger release juice. Each tier adds a
		-- ring to the punch wheel; the last ring ends at the last HoldBoosts point.
		Tiers = { 0.6, 5, 20 },
		GroundDashLift = 35, -- a ground dash always leaves the ground with at least this much upward speed
		GroundDashLiftShare = 0.15, -- or this share of the lunge, so a charged ground punch launches into a flight
		DashEnergyCost = 10,
		Cooldown = 0.25,
	},

	Burst = {
		BaseVelocity = 350,
		VelocityPerPower = 75, -- Power 25 reaches the top of HoldHeights (about 37,000)
		MaxVelocity = 2100,
		-- Height reached for a Space hold of N seconds (from the press), interpolated geometrically between points
		-- so it starts gentle and climbs harder the longer you hold. Power caps it.
		HoldHeights = {
			{ 1, 60 },
			{ 3, 300 },
			{ 5, 600 },
			{ 10, 1800 },
			{ 15, 3400 },
			{ 20, 6000 },
			{ 30, 13000 },
			{ 60, 36000 },
		},
		-- Seconds held where the Burst charge steps up a tier (into the clouds, above them). The jump wheel shows a
		-- hop ring, then one ring per tier, the last ending at the last HoldHeights point.
		Tiers = { 5, 20 },
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
		FallToForward = 1, -- share of the fall speed shed when levelling out that becomes forward speed
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
		ConeStart = 25,
		ConeEnd = 60,
		ConeWidenTime = 1,
		SteerRate = 35,
		MaxPitch = -10,
		MinHoldTime = 0.2, -- a tapped dive lasts this long
	},

	Swoop = {
		MinEntrySpeed = 150,
		LiftFraction = 0.55,
		MaxLift = 160,
		ExitSpeed = 90,
		Cooldown = 1.2,
		MaxAirGainFraction = 0.25,
		EnergyCost = 15,
		PullUpRate = 240, -- degrees per second the flight path rotates upward
		SteepFraction = 0.3, -- below this share of horizontal speed, pull up toward the camera look
		YawRate = 120,
	},

	-- Destruction (spec §4.8, §4.12, §15 milestone 4). Damage is in hits: contact speed / Smash.SpeedPerHit against
	-- the catalog's Health. A dive into the ground or a structure smashes everything in a radius that grows with
	-- speed (Impact.RadiusBase + speed / RadiusSpeedDivisor), breaking in a wave from the centre at WaveSpeed;
	-- anything else flying into a destructible hits just it (plus Smash.ContactRadius around it).
	Impact = {
		RadiusBase = 12, -- review note: the pound felt small at low charges (was 6 + speed / 8)
		RadiusSpeedDivisor = 7,
		PlainPoundScale = PLAIN_POUND_SCALE, -- a plain landing's share of the radius; a punch pound gets it all
		WaveSpeed = 200,
	},

	Smash = {
		-- Review notes: "destruction simulator": a glide (60) clears trees, a hop-dive (100) a house, a 250 dive a
		-- tower; a punch always breaks what it touches and knocks its neighbours.
		SpeedPerHit = 25,
		MinSpeed = 40, -- slower touchdowns and contacts don't count
		-- A contact's force in hits is speed / SpeedPerHit, times DiveMult in a dive and PunchMult while LMB is
		-- held or within PunchWindow of a punch firing; health decides (review note: a tap punch levelled towers
		-- while "a punch always finishes its target" was the rule). Health scales with size ^ HealthBySize.
		DiveMult = 1, -- review note: the plain dive pound was too strong (was 1.5); the punch is the amplifier
		PunchMult = 2.5,
		-- A rocket punch into the ground pounds with strength = (lunge + momentum) × closeness × PoundStrength,
		-- standing in for speed in the damage and radius formulas, so the charge sets the base and how close you
		-- fire sets the multiplier, like the knockback.
		PoundStrength = 1,
		PunchWindow = 1, -- seconds after a punch fires that it still counts as attacking (a dash reaching its target)
		PunchRadiusScale = 0.5, -- a punch contact smashes this share of a dive's radius around it
		MaxForceMult = 4, -- server cap on the multiplier a client reports
		HealthBySize = 0.5, -- a 4× building takes 2× the hits (and pays 4× the cash)
		BigBreakValue = 120, -- objects worth this much (catalog value) break with the BreakBig feel on top
		-- Breaking through costs speed: PassLoss × (health left / force), so a tree barely slows a dive and a
		-- tower you only just cracked takes most of your momentum (review note: collisions need weight).
		PassLoss = 0.65,
		EdgeDamageShare = 0.35, -- damage at the edge of the radius relative to the centre, so towns crumble from the hit side
		ContactRadius = 6, -- a non-dive contact breaks what it touched plus this much around it
		RehitTime = 0.5, -- seconds before the same object can be hit again while you pass through it
	},

	-- Chunks: client-only pooled parts copied from the broken prefab's own parts and flung from the smash centre
	-- (spec §4.8: 30 + (radius − distance) × 2, upward bias 0.4), one bounce off the globe, then fade.
	Chunks = {
		Pool = 120, -- at most this many alive per client (spec §4.12 said 40; a town wave needs more); past it, particles only
		RemoteRange = 300, -- other players' breaks show chunks only this close
		BaseSpeed = 45,
		SpeedPerStud = 2,
		SpeedByContact = 0.15, -- plus this share of the contact speed, so a hypersonic crash sends pieces everywhere
		UpBias = 0.55,
		Spin = 9, -- radians per second at launch
		SpinByContact = 0.004, -- extra spin per unit of contact speed
		Life = 4,
		Fade = 1,
		Bounce = 0.3, -- share of the fall speed kept on the ground bounce
		BounceFriction = 0.5,
		SizeScale = 0.6, -- chunk size relative to the prefab part it came from
		FlashTime = 0.12, -- chunks spawn white and settle to their colour over this (the "I connected" read)
		DebrisPerChunk = 4, -- small particle debris per chunk
	},

	Rebuild = {
		Delay = 75, -- seconds after a break before the prefab snaps back (spec §4.12)
	},

	-- World generation (server/WorldGen.luau, spec §15 milestone 4): the server lays the prefab templates out over
	-- the whole globe from a per-server seed, so everyone in a server sees the same world and no two servers
	-- match. Sections (town, hamlet, forest, cliff) are intentional clusters; the scatter fills everything between.
	WorldGen = {
		FirstTownDistance = 350, -- the first town is always this far from the altar (spec §8: the first target)
		AltarClear = 150, -- nothing spawns this close to the altar
		SectionClear = 600, -- minimum distance between big section centres (towns, hamlets, forests, cliffs)
		GroveClear = 220, -- groves only keep this far from anything else
		ScatterClear = 200, -- loose trees and rocks keep this far from a town or hamlet centre
		-- Review note: the first pass (6 towns, 12 forests, 2,500 loose trees) was still mostly empty; density
		-- comes from many more clusters as well as more scatter.
		-- Second density push (review note: still needs more density and bigger destructibles).
		Towns = 14,
		Hamlets = 20,
		Forests = 40,
		Groves = 260, -- small clumps of trees and a rock or two
		Cliffs = 8,
		ScatterTrees = 9000,
		ScatterRocks = 2200,
		ForestTrees = 120,
		ForestRocks = 24,
		ForestSize = 340, -- studs across (trees scatter over Size × Size × 0.75)
		GroveTreesMin = 10,
		GroveTreesMax = 24,
		GroveSize = 100,
		-- Towns vary in size: a grid of TownColsMin–Max by TownRowsMin–Max with towers nearest the centre
		-- (TownTowerShare of the slots), then shops (TownShopShare), then houses; cars and lamps per slot.
		TownColsMin = 5,
		TownColsMax = 10,
		TownRowsMin = 3,
		TownRowsMax = 7,
		TownTowerShare = 0.18,
		TownShopShare = 0.34,
		TownCarsPerSlot = 0.5,
		TownLampsPerSlot = 0.4,
		-- Size range per prefab, uniform between min and max (review note: the current buildings are the smallest
		-- they should ever be; the biggest should be much taller, and trees taller overall).
		Scale = {
			Tree = { 1.3, 3.2 },
			Rock = { 1, 3 },
			Fence = { 1, 1.4 },
			Lamp = { 1, 1.5 },
			Car = { 0.9, 1.3 },
			SmallHouse = { 1, 2.5 },
			Shop = { 1, 3 },
			Tower = { 1.2, 4.5 },
			RadioMast = { 1, 2.4 },
			-- Landmarks are monuments (review note: way bigger): the smallest is twice the template.
			Pyramid = { 2, 5 },
			Skyscraper = { 1.8, 4 },
			Silo = { 1.8, 3.5 },
			Windmill = { 1.8, 3.2 },
			Statue = { 2, 5 },
			Dome = { 1.8, 4 },
		},
		TownSkyscraperScale = { 1.2, 2.2 }, -- a town's centre skyscraper stays within its lot
		-- Landmarks: big silhouettes placed alone with a ring of lamps (review note: layers of things to smash),
		-- plus a chance of a skyscraper at a town's centre and a windmill at a hamlet's.
		Landmarks = 30,
		LandmarkKinds = { "Pyramid", "Skyscraper", "Silo", "Windmill", "Statue", "Dome" },
		LandmarkLamps = 6,
		LandmarkLampRing = 46, -- studs from the landmark (scaled by its size)
		TownSkyscraperChance = 0.6,
		HamletWindmillChance = 0.5,
		TownSpacing = 74, -- grid pitch in the town, wide enough for the biggest buildings
		TownStreet = 76, -- row pitch (the cars and lamps sit on the half rows)
		YieldEvery = 150, -- models placed per frame while generating
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
		-- Movement keeps a combo alive between targets (review note: tech and performing a Burst should extend it;
		-- not the charge itself, or you could hold a charge forever). While in one of these states the window
		-- keeps refilling, and a Burst release, a chain hop, a punch firing or a bounce refills it once; the
		-- client pings the server at most every PingInterval (Combat/Smash.luau).
		-- Nothing continuous ever refills the window (review note: only the release should count, not the Burst
		-- playing out over many seconds). Entering a dive, swoop or slide, a chain hop, a punch release and a
		-- bounce refill it once; a Burst release refills it by the window plus the flight it launches (ascent
		-- plus hang, capped at BurstExtendMax) so a big Burst can carry a combo to the next target.
		ExtendOnEnter = { Dive = true, Swoop = true, Slide = true },
		BurstExtendMax = 45,
		PingInterval = 0.75,
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
		-- Touch layout (Movement/TouchControls.luau, touch devices only): a dynamic thumbstick on the left, drag to
		-- look anywhere else, JUMP and PUNCH buttons bottom-right. Pixel sizes are at 1080p and scale with the screen.
		Touch = {
			StickZone = 0.45, -- share of the screen width (from the left) where a touch becomes the stick
			StickRadius = 70, -- pixels the knob travels for full input
			StickBase = 170, -- diameter of the stick's ring
			StickKnob = 64, -- diameter of the knob
			StickDeadzone = 0.12,
			JumpButton = { Size = 104, Right = 196, Bottom = 118 },
			PunchButton = { Size = 136, Right = 36, Bottom = 36 },
			MinScale = 0.75, -- the layout never scales below this on small screens (thumbs don't shrink)
			MaxScale = 1.25,
		},
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
		BounceSteerPause = 0.8, -- seconds a glide stops turning toward the look after a wall bounce
		MaxBounceSpeed = 260, -- fastest a bounce throws you out of a surface; speed along it is kept
		MinGroundBounceSpeed = 40, -- a punch-held dive hitting the ground slower than this lands instead of bouncing
		BounceProbe = 2, -- studs beyond this frame's travel to look for walls
		InsideSnap = 2, -- this far under the surface, the body is lifted straight back onto it
	},

	World = {
		FallOffDepth = 60, -- this far inside the globe's surface counts as fallen through: respawn at the altar
		SpawnProbe = 200, -- the spawn looks this far above the surface, in the altar's direction, for the altar's top
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
		TouchSensitivity = 0.3, -- degrees per pixel of a look drag on touch
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

	-- Trauma-style shake (Camera/CameraEffects.luau): a shake entry's amount is a trauma level; what the camera
	-- does is trauma^Exponent, split into a positional offset and a rotational wobble.
	-- Haptics (Feel/Haptics.luau): FeelTable `haptic = "Rumble"` kicks, 0–1 on the large motor.
	Haptics = {
		SmallShare = 0.5, -- the small motor runs at this share of the large one
	},

	CameraShake = {
		MaxTrauma = 2,
		Exponent = 1.6,
		PositionScale = 0.2, -- studs of offset per unit of shake power (review note: less intense across the board)
		RotationDegrees = 0.9, -- degrees of roll/pitch/yaw wobble per unit of shake power
	},

	-- FeelTable (spec §4, §12): every effect, keyed by event. Juice.luau documents the entry keys.
	-- Frame timings from §4 are at 60 fps: frame 2 = 0.033 s, frame 4 = 0.066 s, frame 8 = 0.133 s.
	Feel = {
		Grounded = { { loop = "Wind", to = 0.15, dur = 1 } },
		Landing = join({ { loop = "Wind", to = 0.15, dur = 0.6 } }, TOUCHDOWN),
		Slide = join({ { loop = "Wind", to = 0.5, dur = 0.3 }, { spawn = "Dust", count = 12 } }, TOUCHDOWN),
		-- §4.9: a small dust puff and a light whoosh on takeoff; the squash and stretch are in the animation.
		Hop = { { sound = "Hop" }, { loop = "Wind", to = 0.25, dur = 0.3 }, { spawn = "Dust", count = 6 } },
		Glide = { { loop = "Wind", to = 0.4, dur = 0.5 } },
		-- §4.6: the wings snap shut; speed does the rest through Tuning.Drive (FOV, shake, rush, lines, heat).
		Dive = {
			{ loop = "Wind", to = 0.85, dur = 0.3 },
			{ sound = "WingSnap" },
			{ cam = "fovOffset", kick = 4, dur = 0.2 },
		},
		-- §4.7: wings open with a crack, a short time dip, the FOV drags down then eases back.
		Swoop = {
			{ haptic = "Rumble", kick = 0.2, dur = 0.15 },
			{ loop = "Wind", to = 0.6, dur = 0.3 },
			{ sound = "WingCatch" },
			{ time = 0.4, dur = 0.1 },
			{ cam = "fovOffset", kick = -12, dur = 0.35 },
			{ cam = "tilt", kick = 5, dur = 0.4 },
			{ vfx = "Trails", to = 1, dur = 0 },
			{ vfx = "Trails", to = 0, dur = 0, delay = 0.5 },
		},

		-- §4.1: the hold narrows everything in. The crack and light are the charge bar. Ramps run over the
		-- first seconds of the hold; the Burst height keeps climbing after they finish. The camera zoom is
		-- driven by the hold itself (Tuning.Drive.Charge), not tweened here.
		Charging = {
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
			{ haptic = "Rumble", kick = 0.9, dur = 0.4, curve = "expo", byCharge = true },
			{ time = 0.15, dur = 0.12 },
			{ bus = "Ambient", to = 1, dur = 0 },
			{ bus = "Wind", to = 1, dur = 0 },
			{ bus = "Music", to = 1, dur = 0 },
			{ bus = "Ambient", to = 0, dur = 0.3, delay = 0.12 },
			{ bus = "Wind", to = 0, dur = 0.05, delay = 0.12 },
			{ bus = "Music", to = 0, dur = 0.3, delay = 0.12 },
			{ sound = "SubHit", minHeld = 5 },
			{ sound = "BurstHop", maxHeld = 5 },
			{ post = "Flash", kick = 0.9, dur = 0.3, curve = "expo", byCharge = true },
			{ spawn = "Flash3D", size = 36, lift = 2, dur = 0.4, byCharge = true },
			{ spawn = "Shockwave", radius = 60, alpha = 0.9, dur = 0.6, byCharge = true },
			{ spawn = "Shockwave", radius = 30, alpha = 0.6, dur = 0.35, byCharge = true },
			{ spawn = "DustRing", radius = 26, count = 110, byCharge = true },
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
			{ cam = "recoilDown", kick = 2, dur = 0.4, curve = "spring", delay = 0.033, byCharge = true },
			{ cam = "recoilBack", kick = 3, dur = 0.4, curve = "spring", delay = 0.033, byCharge = true },
			{ cam = "shake", kick = 1.3, freq = 35, dur = 0.7, curve = "expo", delay = 0.033, byCharge = true },
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

		-- Punch releases scale by tier (minHeld is the LMB hold in seconds); every release stops the charge hum.
		Dash = {
			{ cam = "roll", kick = 2.5, dur = 0.35, curve = "spring", randomSign = true },
			{ haptic = "Rumble", kick = 0.35, dur = 0.15, curve = "expo" },
			{ loop = "PunchHum", to = 0, dur = 0.1 },
			{ sound = "Dash" },
			{ spawn = "Sparks", count = 14 },
			{ spawn = "Flash3D", size = 5, dur = 0.2 },
			{ cam = "fovOffset", kick = 5, dur = 0.3, curve = "expo" },
			{ cam = "recoilBack", kick = 1, dur = 0.3, curve = "spring" },
			{ spawn = "Sparks", count = 30, minHeld = 0.6 },
			{ spawn = "Flash3D", size = 9, dur = 0.25, minHeld = 0.6 },
			{ cam = "shake", kick = 0.5, freq = 30, dur = 0.3, curve = "expo", minHeld = 0.6 },
			{ cam = "fovOffset", kick = 6, dur = 0.4, curve = "expo", minHeld = 0.6 },
			{ sound = "RocketPop", minHeld = 5 },
			{ post = "Flash", kick = 0.25, dur = 0.2, curve = "expo", minHeld = 5 },
			{ cam = "shake", kick = 0.9, freq = 30, dur = 0.5, curve = "expo", minHeld = 5 },
			{ spawn = "Shockwave", radius = 20, alpha = 0.6, dur = 0.4, minHeld = 5 },
			{ spawn = "Flash3D", size = 16, dur = 0.3, minHeld = 5 },
			{ sound = "BurstCrack", minHeld = 20 },
			{ post = "Flash", kick = 0.5, dur = 0.3, curve = "expo", minHeld = 20 },
			{ post = "Blur", kick = 8, dur = 0.4, minHeld = 20 },
			{ spawn = "Shockwave", radius = 40, alpha = 0.7, dur = 0.5, minHeld = 20 },
			{ spawn = "DustRing", radius = 16, count = 60, minHeld = 20 },
			{ time = 0.2, dur = 0.08, minHeld = 40 },
			{ sound = "SubHit", minHeld = 40 },
			{ cam = "shake", kick = 1.5, freq = 35, dur = 0.8, curve = "expo", minHeld = 40 },
		},
		Rocket = {
			{ haptic = "Rumble", kick = 0.7, dur = 0.3, curve = "expo" },
			{ loop = "PunchHum", to = 0, dur = 0.1 },
			{ sound = "RocketPop" },
			{ cam = "shake", kick = 0.6, freq = 30, dur = 0.35, curve = "expo" },
			{ cam = "fovOffset", kick = 6, dur = 0.3, curve = "expo" },
			{ cam = "recoilDown", kick = 1, dur = 0.3, curve = "spring" },
			{ spawn = "Dust", count = 30 },
			{ spawn = "Sparks", count = 24 },
			{ spawn = "Shockwave", radius = 10, alpha = 0.6, dur = 0.3 },
			{ spawn = "Flash3D", size = 10, lift = 1, dur = 0.25 },
			{ post = "Flash", kick = 0.12, dur = 0.15, curve = "expo" },
			{ post = "Flash", kick = 0.25, dur = 0.2, curve = "expo", minHeld = 5 },
			{ sound = "BurstCrack", minHeld = 20 },
			{ cam = "shake", kick = 1.2, freq = 35, dur = 0.6, curve = "expo", minHeld = 20 },
		},
		Fizzle = { { loop = "PunchHum", to = 0, dur = 0.1 } },
		-- Charging feedback: a hum that rises with the punch hold, and a chime that climbs a step per tier.
		PunchCharge = {
			{ loop = "PunchHum", from = 0, to = 1, dur = 0.2, pitchFrom = 0, pitchTo = 1.5, pitchDur = 30 },
		},
		PunchTier = {
			{ sound = "TierChime1", maxHeld = 5 },
			{ sound = "TierChime2", minHeld = 5, maxHeld = 20 },
			{ sound = "TierChime3", minHeld = 20 },
			{ cam = "fovOffset", kick = 3, dur = 0.25 },
			{ post = "Flash", kick = 0.08, dur = 0.15, minHeld = 5 },
		},
		BurstTier = {
			{ sound = "TierChime2", maxHeld = 20 },
			{ sound = "TierChime4", minHeld = 20 },
			{ cam = "shake", kick = 0.4, freq = 25, dur = 0.3 },
			{ post = "Flash", kick = 0.1, dur = 0.15 },
		},
		-- Bouncing off a wall that isn't destructible, or punching off the ground; harder hits hit harder.
		Bounce = {
			{
				cam = "roll",
				kick = 3,
				dur = 0.35,
				curve = "spring",
				randomSign = true,
				bySpeed = true,
				minSpeed = 40,
				fullSpeed = 400,
			},
			{
				haptic = "Rumble",
				kick = 0.6,
				dur = 0.25,
				curve = "expo",
				bySpeed = true,
				minSpeed = 40,
				fullSpeed = 400,
			},
			{ sound = "Bounce", volume = 1, bySpeed = true, minSpeed = 0, fullSpeed = 200 },
			{
				cam = "shake",
				kick = 1.2,
				freq = 30,
				dur = 0.35,
				curve = "expo",
				bySpeed = true,
				minSpeed = 0,
				fullSpeed = 300,
			},
			{
				cam = "recoilBack",
				kick = 1.5,
				dur = 0.3,
				curve = "spring",
				bySpeed = true,
				minSpeed = 40,
				fullSpeed = 300,
			},
			{ spawn = "Sparks", count = 20, bySpeed = true, minSpeed = 40, fullSpeed = 300 },
			{ spawn = "Dust", count = 30, bySpeed = true, minSpeed = 40, fullSpeed = 300 },
			{ spawn = "Flash3D", size = 12, dur = 0.25, bySpeed = true, minSpeed = 40, fullSpeed = 300 },
			{ time = 0.1, dur = 0.06, minSpeed = 200 },
			{ post = "Flash", kick = 0.3, dur = 0.2, curve = "expo", bySpeed = true, minSpeed = 150, fullSpeed = 400 },
		},
		-- Another player's burst (spec §7): the column everyone sees.
		-- A dive smashing into a structure mid-air: the same impact frame as a fast touchdown, at the contact point.
		Smash = TOUCHDOWN,
		-- A rocket punch pounding the ground: the touchdown impact frame with the full-size radius.
		Pound = scaleRadii(TOUCHDOWN, 1 / PLAIN_POUND_SCALE),
		-- Flying into a destructible without diving: a crunch, sparks and a small knock.
		Hit = {
			{ sound = "Hit", volume = 1, bySpeed = true, minSpeed = 40, fullSpeed = 600 },
			{ spawn = "Sparks", count = 14, bySpeed = true, minSpeed = 40, fullSpeed = 600 },
			{
				cam = "shake",
				kick = 0.8,
				freq = 40,
				dur = 0.35,
				curve = "expo",
				bySpeed = true,
				minSpeed = 40,
				fullSpeed = 900,
			},
			{ cam = "fovOffset", kick = -3, dur = 0.2, curve = "expo", bySpeed = true, minSpeed = 40, fullSpeed = 900 },
			{
				cam = "roll",
				kick = 2.5,
				dur = 0.35,
				curve = "spring",
				randomSign = true,
				bySpeed = true,
				minSpeed = 40,
				fullSpeed = 600,
			},
			{
				haptic = "Rumble",
				kick = 0.5,
				dur = 0.2,
				curve = "expo",
				bySpeed = true,
				minSpeed = 40,
				fullSpeed = 600,
			},
			-- Fast hits get an impact frame of their own.
			{ time = 0, dur = 0.08, durMin = 0.02, bySpeed = true, minSpeed = 250, fullSpeed = 1200 },
			{
				post = "Flash",
				kick = 0.4,
				dur = 0.25,
				curve = "expo",
				bySpeed = true,
				minSpeed = 250,
				fullSpeed = 1200,
			},
			{ spawn = "Flash3D", size = 14, lift = 2, dur = 0.3, bySpeed = true, minSpeed = 250, fullSpeed = 1200 },
		},
		-- One object breaking (fired at its position with the family it is made of and the contact speed of the
		-- smash that broke it; chunks come from Destruction). The bySpeed extras pile on for fast crashes.
		BreakWood = {
			{ sound = "BreakWood" },
			{ spawn = "Dust", count = 10 },
			{ spawn = "Debris", count = 6, speedMin = 15, speedMax = 40, upBias = 0.7, life = 1.6 },
			{ spawn = "Dust", count = 20, bySpeed = true, minSpeed = 200, fullSpeed = 1200 },
			{
				spawn = "Debris",
				count = 10,
				speedMin = 50,
				speedMax = 120,
				upBias = 0.8,
				life = 2.2,
				bySpeed = true,
				minSpeed = 200,
				fullSpeed = 1200,
			},
		},
		BreakStone = {
			{ sound = "BreakStone" },
			{ spawn = "Dust", count = 18 },
			{ spawn = "Debris", count = 10, speedMin = 15, speedMax = 45, upBias = 0.7, life = 1.8 },
			{ spawn = "Dust", count = 30, bySpeed = true, minSpeed = 200, fullSpeed = 1200 },
			{
				spawn = "Debris",
				count = 14,
				speedMin = 50,
				speedMax = 130,
				upBias = 0.8,
				life = 2.4,
				bySpeed = true,
				minSpeed = 200,
				fullSpeed = 1200,
			},
		},
		BreakGlass = {
			{ sound = "BreakGlass" },
			{ spawn = "Sparks", count = 14 },
			{ spawn = "Sparks", count = 24, bySpeed = true, minSpeed = 200, fullSpeed = 1200 },
		},
		BreakMetal = {
			{ sound = "BreakMetal" },
			{ spawn = "Sparks", count = 16 },
			{ spawn = "Dust", count = 6 },
			{ spawn = "Debris", count = 4, speedMin = 15, speedMax = 35, upBias = 0.6, life = 1.4 },
			{ spawn = "Sparks", count = 24, bySpeed = true, minSpeed = 200, fullSpeed = 1200 },
			{
				spawn = "Debris",
				count = 8,
				speedMin = 50,
				speedMax = 120,
				upBias = 0.7,
				life = 2,
				bySpeed = true,
				minSpeed = 200,
				fullSpeed = 1200,
			},
		},
		-- A cluster snapping back (spec §4.12).
		Rebuild = { { sound = "RebuildChime" } },
		-- Combo counter tick: a short rising arpeggio, one note per hit, resetting every 8 (the event's speed is the
		-- note index 0–7, so pitchBySpeed steps the pitch).
		-- The combo tick climbs a pentatonic scale (pitchSteps, in semitones, indexed by the event's speed) and the
		-- banner adds an octave per tier.
		ComboTick = { { sound = "ComboTick", pitchSteps = { 0, 2, 4, 7, 9, 12, 14, 16 } } },
		-- Combo over: the total slides into the cash readout with a soft chime.
		ComboEnd = {
			{ sound = "CashIn" },
			-- Bigger combos (the event's speed is the tier) pay off with a second note, a blink and a lean-in.
			{ sound = "TierChime4", delay = 0.08, minSpeed = 3 },
			{ post = "Flash", kick = 0.15, dur = 0.2, curve = "expo", minSpeed = 4 },
			{ cam = "fovOffset", kick = 3, dur = 0.3, curve = "spring", minSpeed = 4 },
		},
		-- A big object (Smash.BigBreakValue or more) falling: a flash, a ring, a dust wall, a boom and a jolt
		-- on top of its material break, so the valuable breaks pay off hardest.
		BreakBig = {
			{ spawn = "Flash3D", size = 18, lift = 6, dur = 0.3 },
			{ spawn = "Shockwave", radius = 22, alpha = 0.7, dur = 0.4 },
			{ spawn = "DustRing", radius = 12, count = 60 },
			{ sound = "HeavyLand", volume = 0.6 },
			{ cam = "shake", kick = 0.5, freq = 35, dur = 0.3, curve = "expo" },
			{ haptic = "Rumble", kick = 0.4, dur = 0.2, curve = "expo" },
		},
		-- A car popping half a second after it breaks (spec §4.12; visual only, no chain damage yet).
		CarPop = {
			{ sound = "SubHit", volume = 0.6 },
			{ spawn = "Shockwave", radius = 8, alpha = 0.6, dur = 0.3 },
			{ spawn = "Flash3D", size = 10, lift = 2, dur = 0.25 },
			{ spawn = "Sparks", count = 30 },
			{ spawn = "Debris", count = 8, speedMin = 30, speedMax = 70, upBias = 0.8, life = 1.6 },
			{ cam = "shake", kick = 0.3, freq = 40, dur = 0.25, curve = "expo" },
		},
		-- The combo's name steps up a tier (the event's speed is the tier index): a brighter chime and a blink.
		ComboTier = {
			{ sound = "TierChime2", pitchBySpeed = 0.08 },
			{ haptic = "Rumble", kick = 0.25, dur = 0.12 },
			{ post = "Flash", kick = 0.12, dur = 0.2, curve = "expo" },
		},
		RemoteBurst = {
			{ spawn = "LightColumn", height = 3000, width = 4, alpha = 0.7, dur = 3 },
			{ spawn = "Shockwave", radius = 60, alpha = 0.5, dur = 0.6 },
		},
	} :: { [string]: FeelList },

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
		PunchHum = { Id = "rbxasset://sounds/action_falling.ogg", Bus = "Sfx", Volume = 0.25, Pitch = 0.6, Loop = true },
		TierChime1 = { Id = "rbxasset://sounds/volume_slider.ogg", Bus = "Sfx", Volume = 0.5, Pitch = 1.2 },
		TierChime2 = { Id = "rbxasset://sounds/volume_slider.ogg", Bus = "Sfx", Volume = 0.55, Pitch = 1.5 },
		TierChime3 = { Id = "rbxasset://sounds/volume_slider.ogg", Bus = "Sfx", Volume = 0.6, Pitch = 1.8 },
		TierChime4 = { Id = "rbxasset://sounds/volume_slider.ogg", Bus = "Sfx", Volume = 0.65, Pitch = 2.2 },
		Bounce = { Id = "rbxasset://sounds/action_jump_land.mp3", Bus = "Sfx", Volume = 0.4, Pitch = 1.2 },
		Land = { Id = "rbxasset://sounds/action_jump_land.mp3", Bus = "Sfx", Volume = 0.5, Pitch = 0.9 },
		HeavyLand = { Id = "rbxasset://sounds/impact_explosion_03.mp3", Bus = "Sfx", Volume = 0.9, Pitch = 0.6 },
		WingSnap = { Id = "rbxasset://sounds/action_get_up.mp3", Bus = "Sfx", Volume = 0.35, Pitch = 1.6 },
		WingCatch = { Id = "rbxasset://sounds/action_get_up.mp3", Bus = "Sfx", Volume = 0.45, Pitch = 1.1 },
		-- Speed-driven air rush on top of the state wind (Tuning.Drive.Speed), never set by the FeelTable.
		Rush = { Id = "rbxasset://sounds/action_falling.ogg", Bus = "Wind", Volume = 0.7, Pitch = 1.3, Loop = true },
		-- Destruction placeholders (engine built-ins until the audio pass): one per break family, a contact hit,
		-- the rebuild chime, the combo arpeggio tick and the cash-in chime.
		-- Break sounds carry a wide pitch jitter so a wave of breaks doesn't sound copy-pasted.
		BreakWood = { Id = "rbxasset://sounds/snap.mp3", Bus = "Sfx", Volume = 0.7, Pitch = 0.8, Jitter = 0.18 },
		BreakStone = {
			Id = "rbxasset://sounds/impact_explosion_03.mp3",
			Bus = "Sfx",
			Volume = 0.6,
			Pitch = 0.5,
			Jitter = 0.18,
		},
		BreakGlass = {
			Id = "rbxasset://sounds/electronicpingshort.wav",
			Bus = "Sfx",
			Volume = 0.5,
			Pitch = 1.6,
			Jitter = 0.18,
		},
		BreakMetal = {
			Id = "rbxasset://sounds/action_jump_land.mp3",
			Bus = "Sfx",
			Volume = 0.7,
			Pitch = 0.5,
			Jitter = 0.18,
		},
		Hit = { Id = "rbxasset://sounds/snap.mp3", Bus = "Sfx", Volume = 0.5, Pitch = 1.1 },
		RebuildChime = { Id = "rbxasset://sounds/volume_slider.ogg", Bus = "Sfx", Volume = 0.35, Pitch = 1.4 },
		ComboTick = { Id = "rbxasset://sounds/volume_slider.ogg", Bus = "Ui", Volume = 0.4, Pitch = 1.2 },
		CashIn = { Id = "rbxasset://sounds/volume_slider.ogg", Bus = "Ui", Volume = 0.5, Pitch = 1.8 },
	},

	Audio = {
		BusVolume = 0.25,
		PitchJitter = 0.05,
		LowPassMidShare = 0.3, -- share of the altitude low-pass applied to mids
	},

	Vfx = {
		-- Textures made for the game (scratch generator in the milestone 3b notes): white on alpha, tinted in code.
		VignetteTexture = "rbxassetid://101754802395860", -- soft radial, clear middle
		GlowTexture = "rbxassetid://73442882754892", -- soft radial sprite
		RingTexture = "rbxassetid://128100182532027", -- soft annulus
		CrackTexture = "rbxassetid://135539312145448", -- radial fractures
		SpeedLineOverlay = "rbxassetid://90640540678701", -- radial streaks, clear middle
		StreakTexture = "rbxassetid://72140792466606", -- soft horizontal streak
		-- Screen overlays (Feel/Post.luau).
		VignetteScale = 1.35, -- overlay size relative to the longest screen edge
		HeatColor = Color3.fromRGB(255, 184, 128), -- warm rim at speed: pale amber, not orange
		HeatMaxAlpha = 0.5,
		HeatScale = 1.15,
		HeatTint = Color3.fromRGB(255, 238, 220), -- ColorCorrection tint at full heat
		FlashColor = Color3.fromRGB(255, 250, 240),
		SpeedLineScale = 1.3,
		SpeedLineMaxAlpha = 0.5,
		SpeedLineSpin = 25, -- degrees per second each overlay copy turns (they counter-rotate)
		SpeedLineFlicker = 9, -- Hz
		GroundProbe = 40,
		CrackColor = Color3.fromRGB(28, 26, 24),
		CrackTransparency = 0.1,
		-- Impact glow sprites (Flash3D): a soft burst of light that scales up and fades.
		FlashPool = 4,
		FlashColor3D = Color3.fromRGB(255, 240, 215),
		FlashGrow = 1.6, -- final size relative to the entry's size
		-- Dust ring: a wall of dust rising from the shockwave's edge.
		DustRingPool = 3,
		DustRingLifetimeMin = 0.8,
		DustRingLifetimeMax = 1.6,
		DustRingSpeedMin = 8,
		DustRingSpeedMax = 22,
		DustRingRise = 12, -- upward acceleration
		DustRingSizeStart = 4,
		DustRingSizeEnd = 10,
		-- Debris spin and ground bounce.
		DebrisSpin = 8, -- radians per second at launch
		DebrisBounce = 0.35, -- share of the fall speed kept on a ground bounce
		DebrisBounceFriction = 0.6, -- share of level speed kept on a bounce
		-- Trails: soft streak texture, width tapering off behind.
		TrailWidthEnd = 0.15,
		TrailColor = Color3.fromRGB(235, 240, 255),
		TrailSpeedOn = 0.45, -- the speed drive (0–1) above which trails stream on their own
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
		-- Shockwave rings: expo-out growth (higher snaps harder), then hang and fade.
		ShockwaveSnap = 4,
		-- Impact craters: a scorched soft disc under a ring of cracks, fading over the entry's dur.
		CraterPool = 4,
		CraterColor = Color3.fromRGB(22, 20, 18),
		CraterTransparency = 0.2,
		CraterScorchScale = 0.8, -- scorch disc radius relative to the crack radius
		CraterScorchTransparency = 0.45,
		-- Sparks: hot streaks at punches and bounces, white → amber, pulled down a little.
		SparkColor = Color3.fromRGB(255, 225, 170),
		SparkLifetimeMin = 0.25,
		SparkLifetimeMax = 0.55,
		SparkSpeedMin = 30,
		SparkSpeedMax = 80,
		SparkSize = 0.8,
		SparkSquash = -3, -- negative stretches each spark along its travel
		SparkGravity = 60,
		SparkDrag = 3,
		-- Fist glow sprite while a punch charges.
		FistGlowSize = 2.2, -- studs at full charge
		FistGlowAlpha = 0.85,
		EmberTail = Color3.fromRGB(200, 60, 20),
		-- Speed lines streaming back off the body (spec §4.3, §4.6), rate driven by speed; the screen overlay
		-- (SpeedLineOverlay) carries most of the read, so these stay sparse.
		SpeedLineRate = 70,
		SpeedLineSpeed = 90,
		SpeedLineLifetime = 0.35,
		SpeedLineSize = 0.6,
		SpeedLineSquash = -4, -- negative stretches each particle along its travel into a streak
		SpeedLineSpread = 22,
		SpeedLineTransparency = 0.4,
		-- Embers streaming back at high dive speed (spec §4.6 300+ stage).
		EmberRate = 90,
		EmberColor = Color3.fromRGB(255, 150, 60),
		EmberSpeed = 40,
		EmberLifetime = 0.6,
		EmberSize = 0.3,
		-- The fist glows while a punch charges: a light and orbiting motes on the punching hand.
		FistLight = 6,
		FistLightRange = 10,
		FistColor = Color3.fromRGB(255, 200, 120),
		FistRate = 40,
		FistSpeed = 3,
		FistLifetime = 0.5,
		FistSize = 0.35,
		-- Pebbles lifting off the ground crack while the Burst charges (spec §4.1).
		PebbleRate = 24,
		PebbleColor = Color3.fromRGB(120, 115, 105),
		PebbleSpeedMin = 1,
		PebbleSpeedMax = 3,
		PebbleLifetime = 2.5,
		PebbleSize = 0.25,
		PebbleSpread = 60, -- wide, so the motes rise from across the crack rather than one point
	},

	-- Per-frame driven effects (Feel/Drivers.luau): read live state every frame instead of firing on events.
	Drive = {
		-- Both charges pull the camera in the longer you hold (log-shaped over the whole hold curve, so the
		-- first seconds move it most). Zoom is studs closer; Fov is added to the base FOV (negative narrows).
		Charge = { Zoom = 5, Fov = -9 },
		PunchCharge = { Zoom = 4, Fov = -7 },
		ChargeSmooth = 10, -- 1/seconds the zoom follows the hold in
		ChargeRelease = 5, -- 1/seconds it eases back out after release
		-- FOV is the speed meter, shake is the danger meter (spec §4.10). Speed above Floor saturates toward
		-- the maximum with the given reference speeds (1 − e^(−speed/ref)).
		Speed = {
			Floor = 70, -- walking and cruising glides add nothing
			FovRef = 320,
			Fov = 34,
			ShakeRef = 500,
			Shake = 1.4,
			ShakeFreq = 30,
			RushRef = 280, -- the rush loop (Sounds.Rush) volume
			RushPitch = 0.5, -- added playback speed at full rush
			LinesRef = 220, -- speed lines emission
			LinesStart = 90, -- speed lines begin above this speed
			HeatStart = 260, -- warm rim, tint and embers from here (spec §4.6 300+ stage)
			HeatRange = 240, -- fully warm this much above HeatStart
			Heat = 1, -- heat rim alpha share (Vfx.HeatMaxAlpha caps it)
			Tint = 0.6, -- ColorCorrection warm tint share at full heat
			DiveBlur = 7, -- radial-blur stand-in, Dive only, scaled by speed
			DiveBlurRef = 350,
		},
		-- The fist glow follows the punch hold: half from the basic charge, half from the tiers beyond it.
		FistBaseShare = 0.5,
	},

	-- Character animation (Feel/Anim.luau). Stock Roblox clips for locomotion (R15 first, R6 fallback) plus
	-- the FALL poses in Tuning.Poses layered onto the joints.
	Anim = {
		Response = 16, -- 1/seconds joints ease toward their pose
		SnapResponse = 50, -- 1/seconds for SnapTime after a state change or punch (spec §4.10: cut in, fade out)
		SnapTime = 0.15,
		Fade = 0.12, -- clip crossfade seconds
		WalkMinSpeed = 1.5, -- below this the idle clip plays
		RunSpeed = 12, -- at or above this the run clip plays instead of the walk clip
		ClipRefSpeed = 16, -- ground speed at which the walk and run clips play at 1×
		MinClipRate = 0.5,
		MaxClipRate = 2.4,
		SquatHopDepth = 0.55, -- a hop hold squats up to this share of the full squat; Charging is the full squat
		SquatTremble = 2.5, -- degrees of root tremble at a full Burst charge
		WindOvercharge = 0.4, -- how much further the wind-back pulls past the basic charge over the tiers
		WindTremble = 2, -- degrees of tremble on the punching arm at the last tier
		TrembleFrequency = 18,
		DiveTightenTime = 1.2, -- seconds of dive hold until the second fist joins (DiveTight fully in)
		DiveShake = 0.12, -- studs of body vibration in a dive at full speed
		DiveShakeRef = 350,
		DiveShakeFrequency = 28,
		HangBreathPeriod = 2.5,
		SquashTime = 0.28, -- touchdown squash recovery
		SquashFullSpeed = 150, -- touchdown speed for a full squash
		SquashMin = 0.35, -- a hop landing still squashes this much
		StretchTime = 0.18, -- takeoff stretch recovery
		PunchOutTime = 0.3, -- the punch pose decays over this after release
		-- The flying punch (review note: after a release you looked like you were diving, not punching): in the
		-- air the PunchFlight pose holds for PunchFlightHold of Smash.PunchWindow, then eases out, and it
		-- overrides the state's own pose by PunchFlightOverride while it's in.
		PunchFlightHold = 0.55,
		PunchFlightOverride = 0.8,
		Clips = {
			R15 = {
				idle = "rbxassetid://507766666",
				walk = "rbxassetid://507777826",
				run = "rbxassetid://507767714",
				jump = "rbxassetid://507765000",
				fall = "rbxassetid://507767968",
			},
			R6 = {
				idle = "rbxassetid://180435571",
				walk = "rbxassetid://180426354",
				run = "rbxassetid://180426354",
				jump = "rbxassetid://125750702",
				fall = "rbxassetid://180436148",
			},
		},
	},

	-- Joint offsets per pose, layered onto the stock clips (not in the F2 panel). Keys are abstract joints that
	-- Anim maps to the rig (R15: Root, Waist, Neck, L/RShoulder, L/RElbow, L/RHip, L/RKnee; R6 has no Waist,
	-- elbows or knees and ignores them). Values are in the parent part's axes, in degrees and studs:
	--   P pitch: a hanging limb swings forward, the head tips up, the root leans back
	--   T twist around the vertical axis (positive turns the front to the character's left)
	--   S side: a hanging limb swings toward the character's right
	--   Up / Fwd: translation
	Poses = {
		-- Space held on the ground: a full-body squat that deepens with the hold; Charging holds it at depth.
		Squat = {
			Root = { Up = -1.1, P = -12 },
			LHip = { P = 70, S = -8 },
			RHip = { P = 70, S = 8 },
			LKnee = { P = -100 },
			RKnee = { P = -100 },
			LShoulder = { P = -25, S = -12 },
			RShoulder = { P = -25, S = 12 },
			Neck = { P = -15 },
		},
		-- LMB held: the upper body winds back for a right-handed punch, the left arm guards; the legs keep walking.
		Wind = {
			Waist = { T = -32 },
			Neck = { T = 30, P = 5 },
			Root = { P = -6, T = -6 },
			RShoulder = { P = -75, S = 30 },
			RElbow = { P = 110 },
			LShoulder = { P = 45, S = -15 },
			LElbow = { P = 60 },
		},
		-- The punch itself: kicked on release and left to decay.
		PunchOut = {
			Waist = { T = 35 },
			Neck = { T = -25 },
			Root = { P = -10, Fwd = 0.3 },
			RShoulder = { P = 95, S = -10 },
			RElbow = { P = 5 },
			LShoulder = { P = -30, S = -15 },
		},
		-- The flying punch, held through the attack window in the air: the lead fist straight out along the
		-- flight, the other arm pulled back, the body straight and twisted into the punch, head up.
		PunchFlight = {
			RShoulder = { P = 185, S = 6 },
			RElbow = { P = 0 },
			LShoulder = { P = -55, S = -14 },
			LElbow = { P = 45 },
			Waist = { T = 22, P = 4 },
			Neck = { P = -28, T = -10 },
			LHip = { P = 10 },
			RHip = { P = 10 },
			LKnee = { P = 0 },
			RKnee = { P = 0 },
		},
		-- Hop takeoff stretch and touchdown squash (spec §4.9), kicked on enter.
		Stretch = {
			Root = { Up = 0.25 },
			LShoulder = { P = -20 },
			RShoulder = { P = -20 },
			LKnee = { P = -25 },
			RKnee = { P = -25 },
		},
		Squash = {
			Root = { Up = -0.9, P = -10 },
			LHip = { P = 45, S = -6 },
			RHip = { P = 45, S = 6 },
			LKnee = { P = -70 },
			RKnee = { P = -70 },
			LShoulder = { P = 30, S = -20 },
			RShoulder = { P = 30, S = 20 },
			Neck = { P = -10 },
		},
		-- §4.2: full-body extension, arms back, head up.
		Burst = {
			Root = { P = 8 },
			LShoulder = { P = -50, S = -25 },
			RShoulder = { P = -50, S = 25 },
			Neck = { P = 25 },
			LHip = { P = -8 },
			RHip = { P = -8 },
			LKnee = { P = -15 },
			RKnee = { P = -15 },
		},
		-- §4.4: limp and weightless, arms out; HangBreath sways on top on a slow cycle.
		Hang = {
			Root = { P = 10 },
			LShoulder = { P = 15, S = -70 },
			RShoulder = { P = 15, S = 70 },
			LElbow = { P = 20 },
			RElbow = { P = 20 },
			LHip = { P = 10, S = -10 },
			RHip = { P = 10, S = 10 },
			LKnee = { P = -25 },
			RKnee = { P = -25 },
			Neck = { P = 15 },
		},
		HangBreath = {
			Root = { Up = 0.15 },
			LShoulder = { S = -8, P = 5 },
			RShoulder = { S = 8, P = 5 },
			Neck = { P = 4 },
		},
		-- §4.5: arms spread as wings, legs together, head up (the root is already pitched with the flight path).
		Glide = {
			LShoulder = { P = -15, S = -85 },
			RShoulder = { P = -15, S = 85 },
			LElbow = { P = 10 },
			RElbow = { P = 10 },
			Neck = { P = 35 },
			LHip = { P = -5, S = -3 },
			RHip = { P = -5, S = 3 },
		},
		-- Added per unit of bank (positive = rolling right): the outer arm lifts, the inner drops.
		GlideBank = {
			LShoulder = { S = -15 },
			RShoulder = { S = -15 },
		},
		-- §4.6: tuck, lead fist forward, head down behind it; DiveTight brings the second fist in with the hold.
		Dive = {
			RShoulder = { P = 170, S = 8 },
			RElbow = { P = 5 },
			LShoulder = { P = -15, S = -5 },
			Neck = { P = -20 },
			LKnee = { P = -5 },
			RKnee = { P = -5 },
		},
		DiveTight = {
			LShoulder = { P = 185, S = 8 },
			RShoulder = { P = 5, S = -5 },
			Neck = { P = -8 },
		},
		-- §4.7: full-body arch, arms back, catching air.
		Swoop = {
			Root = { P = 15 },
			LShoulder = { P = -60, S = -40 },
			RShoulder = { P = -60, S = 40 },
			Neck = { P = 30 },
			LHip = { P = -15 },
			RHip = { P = -15 },
			LKnee = { P = -35 },
			RKnee = { P = -35 },
		},
		-- Dive-slide: legs forward, arms back, head up (the body lean comes from the state).
		Slide = {
			LHip = { P = 60, S = -8 },
			RHip = { P = 60, S = 8 },
			LKnee = { P = -25 },
			RKnee = { P = -25 },
			LShoulder = { P = -35, S = -20 },
			RShoulder = { P = -35, S = 20 },
			Neck = { P = 20 },
		},
		-- Hop: knees tucked a little; the stock jump and fall clips do the rest.
		Hop = {
			LKnee = { P = -15 },
			RKnee = { P = -15 },
		},
	},

	Sky = {
		Smoothing = 0.5, -- seconds; band transitions ease with this time constant
	},

	Net = {
		BurstMinInterval = 5, -- spec §13 rate limit
		MaxPositionError = 40, -- reported positions further than this from the replicated character are ignored...
		PositionLag = 0.25, -- ...plus this many seconds of the contact speed (the replicated character lags at speed)
		-- Contacts are batched per frame (Combat/Smash.luau) and budgeted per player on the server, never dropped
		-- one by one: a fast dive through a town touches many things in a few frames (review note: at speed the
		-- destruction stopped happening; the old per-contact rate limits were throwing them away).
		MaxContactsPerBatch = 32,
		ContactBudgetPerSecond = 60,
		MaxOverlapParts = 600, -- parts a smash's radius query may return (the engine's default of 20 starved big pounds)
		MaxSpeed = 20000, -- reported contact speeds above this are dropped (a 60 s punch is 14,000)
		MaxFallPeak = 45000, -- reported dive start altitudes are clamped here (a full Burst is 36,000)
		HitMaxDistance = 20, -- the contact point must be within this of the hit object's bounding box
	},

	Ui = {
		AltitudeTop = 48,
		AltitudeAlpha = 0.5,
		RecordPulseTime = 1,
		-- Cash feedback (spec §4.8): a small readout top-left that counts up, floating numbers at each break in
		-- muted gold, and a combo counter top-right with a ring timer, shown from ×2.
		CashSize = 22,
		CashCountTime = 0.6, -- seconds the readout takes to count up to a new total
		FloatPool = 24,
		FloatSize = 20,
		FloatRise = 8, -- studs a floating number rises over its life
		FloatTime = 1.1,
		FloatAlpha = 0.85,
		FloatSizePerDecade = 0.3, -- numbers grow this much per decade of cash above $5, up to FloatMaxGrow
		FloatMaxGrow = 2,
		FloatPopTime = 0.15, -- pop in oversized and settle
		FloatPopScale = 1.6,
		FloatSpread = 3, -- studs of random sideways offset so a wave doesn't stack
		FloatBigCash = 300, -- worth this much or more, the number is white-gold
		-- Combo banner (UI/ComboBanner.luau): arcade style, top centre. The number pops on every credit, the name
		-- steps up through ComboNames (by count) with a bigger pop and a flash, a thin bar times the window, and
		-- the total slides down into the cash readout when the combo ends.
		ComboTop = 72,
		ComboNumberSize = 64,
		ComboNameSize = 22,
		ComboBarWidth = 180,
		ComboPop = 0.3, -- seconds the number scales back after a tick
		ComboPopScale = 1.35,
		ComboTierPop = 0.5,
		ComboTierPopScale = 1.8,
		ComboOutTime = 0.7, -- the total flies to the cash readout and fades over this
		ComboFlyScale = 0.4, -- its size when it lands on the readout
		ComboTilt = 6, -- degrees the number tilts on each pop (alternating sides)
		ComboWarnTime = 1, -- the bar turns hot and blinks for the last second of the window
		ComboPayoffPop = 0.3, -- extra readout pop per decade of combo cash above $100
		ComboNames = {
			{ 2, "NICE" },
			{ 4, "SWEET" },
			{ 6, "RAMPAGE" },
			{ 9, "WRECKING BALL" },
			{ 12, "DEMOLITION" },
			{ 16, "CATACLYSM" },
			{ 20, "GODFALL" },
		},
		-- Break toasts (UI/Toasts.luau): a short stack above the bottom centre, one card per object broken.
		ToastPool = 6,
		ToastTime = 1.8,
		ToastBottom = 150, -- pixels above the bottom edge for the newest card
		ToastHeight = 34,
		ToastGap = 6,
		ToastSize = 22,
		ToastBigCash = 300, -- a toast worth this much or more is big
		ToastBigScale = 1.3,
		ToastSlotResponse = 14, -- 1/seconds cards ease up the stack
		PrefabNames = {
			Tree = "TREE",
			Fence = "FENCE",
			Rock = "ROCK",
			Lamp = "LAMP",
			Car = "CAR",
			SmallHouse = "HOUSE",
			Shop = "SHOP",
			Tower = "TOWER",
			RadioMast = "MAST",
			Pyramid = "PYRAMID",
			Skyscraper = "SKYSCRAPER",
			Silo = "SILO",
			Windmill = "WINDMILL",
			Statue = "STATUE",
			Dome = "DOME",
		},
		-- Cash readout pop whenever it counts up.
		CashPop = 0.35,
		CashPopScale = 1.25,
		-- Charge rings (punch beside the crosshair, jump above the head): chunky, outlined, mobile-HUD style.
		RingThickness = 6,
		RingBorder = 2, -- dark outline on each side of the ring
		RingTrackTransparency = 0.35, -- the dark backing ring
		RingInnerScale = 0.38, -- innermost ring size relative to the outermost; the rest are spaced evenly between
		RingFade = 0.2,
		PunchWheelSize = 110,
		PunchWheelOffset = 80, -- pixels right of and below the crosshair
		JumpWheelSize = 130,
		JumpWheelHeight = 5, -- studs above the root
	},

	Dev = {
		ChargeSpeed = 2, -- test aid: every hold (hop, Burst, punch) charges this many times faster than real time
		TraceMovement = true, -- Studio only: print state transitions and bounces, expose Dbg* player attributes
		DropAltitudes = { 300, 1000, 3000, 10000 },
		TestSmashSpeed = 400, -- Studio only: F4 smashes the ground under the player at this speed
		WorldSeed = 0, -- 0 = a new seed per server (printed at start); set it to reproduce a layout
		PowerPresets = { 1, 6, 11, 18, 25 },
		ShowControlsHud = true, -- tester cheat sheet in every build; turn off when milestone 7 hints land
	},
}

return Tuning
