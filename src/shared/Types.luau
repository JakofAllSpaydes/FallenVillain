--!strict

export type MovementState =
	"Grounded"
	| "Charging"
	| "Burst"
	| "Hang"
	| "Hop"
	| "Glide"
	| "Dive"
	| "Swoop"
	| "Impact"
	| "Landing"
	| "Slide"

export type InputSnapshot = {
	JumpHeld: boolean,
	JumpPressed: boolean,
	JumpReleased: boolean,
	PrimaryHeld: boolean,
	PrimaryPressed: boolean,
	PrimaryReleased: boolean,
	SecondaryHeld: boolean,
	Move: Vector3, -- ControlModule move vector: x right, z back (W = -1)
}

-- Shared physics context passed to every movement state (spec §10). The world is a globe: Up points away from
-- the planet's center at the player and every state measures "level" and "vertical" against it.
export type Ctx = {
	Player: Player,
	Character: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Align: AlignOrientation,
	RaycastParams: RaycastParams,
	StandHeight: number,

	Input: InputSnapshot,
	AimPoint: Vector3,
	LookDirection: Vector3, -- camera look; Glide and Swoop steer toward it
	Now: number,

	State: MovementState,
	StateTime: number,
	Velocity: Vector3,
	Up: Vector3, -- away from the planet's center at the player
	Altitude: number,
	Heading: Vector3, -- level unit vector the body faces
	BodyDirection: Vector3?, -- head direction in air; nil = upright facing Heading
	Bank: number, -- degrees, positive = roll right

	GlideEnergy: number,
	BurstCharge: number, -- 0–1 strength of the last Burst for effects (height / Burst.FeelFullHeight)
	BurstHeld: number, -- seconds Space was held for the last Burst
	BurstAscentTime: number, -- seconds from ignition to apex of the last Burst
	HopChain: number,
	LastLandTime: number,
	LandVelocity: Vector3, -- level velocity at the last touchdown; chain hops keep it
	SwoopReadyAt: number,
	FallPeak: number, -- highest altitude this fall; caps air gain
	Power: number, -- upgrade level 1–25; sets Burst velocity
	PunchHold: number?, -- seconds LMB has been held, nil when not charging a punch
	PunchReadyAt: number,
	LookFollowAfter: number, -- Glide and Swoop don't turn toward the camera look until this time (after a bounce)
	TimeScale: number, -- hitstop and slow-mo multiplier on dt this frame
}

-- Every state is controller-driven: it sets ctx.Velocity each frame and the controller hands it to physics.
export type StateModule = {
	OnGround: boolean?, -- a ground state: holds the floor itself (no touchdown check) and Space holds here count toward the Burst charge
	NoBounce: boolean?, -- walls don't bounce this state (walking into one just stops)
	Punch: ("Ground" | "Air")?, -- what an LMB release does here; nil = the punch is dropped
	enter: (ctx: Ctx, payload: any) -> (),
	update: (ctx: Ctx, dt: number) -> (MovementState?, any),
	exit: ((ctx: Ctx) -> ())?,
}

return {}
