--!strict
-- Hop (spec §3, §4.9): fires when the ground tap-or-hold check (JumpCheck) resolves to a tap, rises to
-- its height, then a short low-gravity float. With Hop.GlideClearance of air below it opens into a Glide;
-- closer to the ground it just falls back like a jump. Space in the air dives.
-- A punch rocket jump also enters here with the launch velocity already set.

local Shared = game:GetService("ReplicatedStorage").Shared
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)
local MathUtil = require(script.Parent.Parent.MathUtil)
local Punch = require(script.Parent.Parent.Punch)

local Hop = { Air = true, Punch = "Air" }

local floating = false
local falling = false -- past the float without room to glide: plain fall until touchdown
local high = false
local floatTime = 0

local function launch(ctx: Types.Ctx)
	ctx.HopChain = 0
	local vy = math.max(0, ctx.Velocity.Y)
	ctx.FallPeak = ctx.Altitude + vy * vy / (2 * Tuning.Gravity.Hop)
end

local function hop(ctx: Types.Ctx, pressedAt: number)
	local T = Tuning.Hop
	if pressedAt - ctx.LastLandTime <= T.ChainWindow then
		ctx.HopChain = math.min(ctx.HopChain + 1, T.MaxChain)
	else
		ctx.HopChain = 0
	end
	local chainMult = 1 + T.ChainBonus * ctx.HopChain
	local height = T.Height * chainMult * Punch.slow(ctx, Tuning.Punch.ChargeHopMult)

	-- Perfect bunny hop: a chain hop keeps the speed you landed with (or are sliding with) plus a bonus and a
	-- forward kick, so a good rhythm builds speed. Capped by Tech.MaxCarrySpeed.
	local horizontal = MathUtil.flat(ctx.Velocity)
	if ctx.HopChain > 0 then
		local carried = if ctx.LandVelocity.Magnitude > horizontal.Magnitude then ctx.LandVelocity else horizontal
		local wish = MathUtil.cameraMove(ctx.Input.Move)
		local forward = if carried.Magnitude > 1
			then carried.Unit
			elseif wish.Magnitude > 1e-3 then wish.Unit
			else ctx.Heading
		local speed = carried.Magnitude * (1 + Tuning.Tech.PerfectHopBonus) + T.ChainForwardBoost
		speed = math.min(speed, math.max(Tuning.Tech.MaxCarrySpeed, horizontal.Magnitude))
		horizontal = forward * math.max(speed, horizontal.Magnitude)
	end
	ctx.Velocity = horizontal + Vector3.yAxis * math.sqrt(2 * Tuning.Gravity.Hop * height)
	ctx.FallPeak = ctx.Altitude + height
end

function Hop.enter(ctx: Types.Ctx, payload: any)
	if payload ~= nil and payload.Launch then
		launch(ctx)
	else
		hop(ctx, if payload ~= nil and payload.PressedAt then payload.PressedAt else ctx.Now)
	end
	floating = false
	falling = false
	high = false
	floatTime = 0
	ctx.GlideEnergy = Tuning.GlideEnergy.Max
	ctx.BodyDirection = nil
	ctx.Bank = 0
end

function Hop.update(ctx: Types.Ctx, dt: number): (Types.MovementState?, any)
	local T = Tuning.Hop
	if ctx.Input.JumpPressed then
		return "Dive", nil
	end

	local probe = -Vector3.yAxis * (ctx.StandHeight + T.GlideClearance)
	local vy = ctx.Velocity.Y
	if falling then
		vy -= Tuning.Gravity.Hop * dt
		-- Fell off a ledge: open the wings after all.
		if not workspace:Raycast(ctx.Root.Position, probe, ctx.RaycastParams) then
			return "Glide", nil
		end
	elseif not floating then
		vy -= Tuning.Gravity.Hop * dt
		if vy <= 0 then
			floating = true
			high = workspace:Raycast(ctx.Root.Position, probe, ctx.RaycastParams) == nil
		end
	else
		floatTime += dt
		vy -= Tuning.Gravity.HopApexFloat * dt
		if floatTime >= T.ApexFloatTime then
			if high then
				return "Glide", nil
			end
			falling = true
			floating = false
		end
	end

	-- Air control only adds speed along the input, up to AirControlSpeed in that direction; it never brakes.
	-- Strafing bends the path without eating momentum, and can't push total speed past what it already was.
	local horizontal = MathUtil.flat(ctx.Velocity)
	local wish = MathUtil.cameraMove(ctx.Input.Move)
	if wish.Magnitude > 1e-3 then
		local before = horizontal.Magnitude
		local along = horizontal:Dot(wish.Unit)
		local add = math.clamp(T.AirControlSpeed * wish.Magnitude - along, 0, T.AirControlAccel * dt)
		horizontal += wish.Unit * add
		local cap = math.max(before, T.AirControlSpeed)
		if horizontal.Magnitude > cap then
			horizontal = horizontal.Unit * cap
		end
	end
	if horizontal.Magnitude > 1 then
		ctx.Heading = horizontal.Unit
	end

	ctx.Velocity = horizontal + Vector3.yAxis * vy
	return nil
end

return Hop
