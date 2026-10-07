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

-- Shared physics context passed to every movement state (spec §10).
export type Ctx = {
	Player: Player,
	Character: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Gravity: VectorForce,
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
	Altitude: number,
	Heading: Vector3, -- horizontal unit vector the body faces
	BodyDirection: Vector3?, -- head direction in air; nil = upright facing Heading
	Bank: number, -- degrees, positive = roll right

	GlideEnergy: number,
	Charge: number,
	HopChain: number,
	LastLandTime: number,
	LandVelocity: Vector3, -- horizontal velocity at the last touchdown; chain hops keep it
	SwoopReadyAt: number,
	FlapReadyAt: number,
	FallPeak: number, -- highest altitude this fall; caps air gain
}

export type StateModule = {
	Air: boolean,
	SkipTouchdown: boolean?, -- controller-driven on the ground (Slide): no touchdown check
	enter: (ctx: Ctx, payload: any) -> (),
	update: (ctx: Ctx, dt: number) -> (MovementState?, any),
	exit: ((ctx: Ctx) -> ())?,
}

return {}
