--!strict
-- Hop (spec §3, §4.9): fires when the ground tap-or-hold check (JumpCheck) resolves to a tap, rises to
-- its height, then a short low-gravity float. With Hop.GlideClearance of air below it opens into a Glide;
-- closer to the ground it just falls back like a jump. Space in the air dives.
-- A punch rocket jump, a ground bounce and walking off a ledge also enter here with the velocity already set.

local Shared = game:GetService("ReplicatedStorage").Shared
local Globe = require(Shared.Globe)
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)
local MathUtil = require(script.Parent.Parent.MathUtil)
local Punch = require(script.Parent.Parent.Punch)

local Hop = { Punch = "Air" }

local floating = false
local falling = false -- past the float without room to glide: plain fall until touchdown
local high = false
local floatTime = 0

local function launch(ctx: Types.Ctx)
	ctx.HopChain = 0
	local vy = math.max(0, ctx.Velocity:Dot(ctx.Up))
	ctx.FallPeak = ctx.Altitude + vy * vy / (2 * Tuning.Gravity.Hop)
end

local function hop(ctx: Types.Ctx, pressedAt: number, charge: number)
	local T = Tuning.Hop
	local up = ctx.Up
	if pressedAt - ctx.LastLandTime <= T.ChainWindow then
		ctx.HopChain = math.min(ctx.HopChain + 1, T.MaxChain)
	else
		ctx.HopChain = 0
	end
	local chainMult = 1 + T.ChainBonus * ctx.HopChain
	local height = (T.Height + (T.ChargedHeight - T.Height) * charge)
		* chainMult
		* Punch.slow(ctx, Tuning.Punch.ChargeHopMult)

	-- Perfect bunny hop: a chain hop keeps the speed you landed with (or are sliding with) plus a bonus and a
	-- forward kick, so a good rhythm builds speed. Capped by Tech.MaxCarrySpeed.
	local level = MathUtil.flat(ctx.Velocity, up)
	if ctx.HopChain > 0 then
		local carried = if ctx.LandVelocity.Magnitude > level.Magnitude then ctx.LandVelocity else level
		local wish = MathUtil.cameraMove(ctx.Input.Move, up)
		local forward = if carried.Magnitude > 1
			then carried.Unit
			elseif wish.Magnitude > 1e-3 then wish.Unit
			else ctx.Heading
		local speed = carried.Magnitude * (1 + Tuning.Tech.PerfectHopBonus) + T.ChainForwardBoost
		speed = math.min(speed, math.max(Tuning.Tech.MaxCarrySpeed, level.Magnitude))
		level = forward * math.max(speed, level.Magnitude)
	end
	ctx.Velocity = level + up * math.sqrt(2 * Tuning.Gravity.Hop * height)
	ctx.FallPeak = ctx.Altitude + height
end

function Hop.enter(ctx: Types.Ctx, payload: any)
	if payload ~= nil and payload.Launch then
		launch(ctx)
	else
		local pressedAt = if payload ~= nil and payload.PressedAt then payload.PressedAt else ctx.Now
		hop(ctx, pressedAt, if payload ~= nil and payload.Charge then payload.Charge else 0)
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

	local up = ctx.Up
	local probe = -up * (ctx.StandHeight + T.GlideClearance)
	local vy = ctx.Velocity:Dot(up)
	if falling then
		vy -= Tuning.Gravity.Hop * dt
		-- Fell off a ledge: open the wings after all.
		if not Globe.raycast(ctx.Root.Position, probe, ctx.RaycastParams) then
			return "Glide", nil
		end
	elseif not floating then
		vy -= Tuning.Gravity.Hop * dt
		if vy <= 0 then
			floating = true
			high = Globe.raycast(ctx.Root.Position, probe, ctx.RaycastParams) == nil
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
	local level = MathUtil.flat(ctx.Velocity, up)
	local wish = MathUtil.cameraMove(ctx.Input.Move, up)
	if wish.Magnitude > 1e-3 then
		local before = level.Magnitude
		local along = level:Dot(wish.Unit)
		local add = math.clamp(T.AirControlSpeed * wish.Magnitude - along, 0, T.AirControlAccel * dt)
		level += wish.Unit * add
		local cap = math.max(before, T.AirControlSpeed)
		if level.Magnitude > cap then
			level = level.Unit * cap
		end
	end
	if level.Magnitude > 1 then
		ctx.Heading = level.Unit
	end

	ctx.Velocity = level + up * vy
	return nil
end

return Hop
