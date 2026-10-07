--!strict
-- Hop (spec §3, §4.9): fires when Grounded's tap-or-hold check resolves (or instantly on a chain hop), rises to
-- its height, then a short low-gravity float before handing off to Glide. Space in the air dives.
-- A punch rocket jump also enters here with the launch velocity already set.

local Shared = game:GetService("ReplicatedStorage").Shared
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)
local MathUtil = require(script.Parent.Parent.MathUtil)
local Punch = require(script.Parent.Parent.Punch)

local Hop = { Air = true, Punch = "Air" }

local floating = false
local floatTime = 0

local function launch(ctx: Types.Ctx)
	ctx.HopChain = 0
	local vy = math.max(0, ctx.Velocity.Y)
	ctx.FallPeak = ctx.Altitude + vy * vy / (2 * Tuning.Gravity.Hop)
end

local function hop(ctx: Types.Ctx, charge: number)
	local T = Tuning.Hop
	if ctx.Now - ctx.LastLandTime <= T.ChainWindow then
		ctx.HopChain = math.min(ctx.HopChain + 1, T.MaxChain)
	else
		ctx.HopChain = 0
	end
	local chainMult = 1 + T.ChainBonus * ctx.HopChain
	local height = (T.Height + (T.ChargedHeight - T.Height) * charge)
		* chainMult
		* Punch.slow(ctx, Tuning.Punch.ChargeHopMult)

	-- Perfect bunny hop: a chain hop keeps the speed you landed with (or are sliding with) plus a bonus,
	-- so a good rhythm builds speed. Capped by Tech.MaxCarrySpeed.
	local horizontal = MathUtil.flat(ctx.Velocity)
	if ctx.HopChain > 0 then
		local carried = if ctx.LandVelocity.Magnitude > horizontal.Magnitude then ctx.LandVelocity else horizontal
		if carried.Magnitude > 1e-3 then
			local speed = math.min(carried.Magnitude * (1 + Tuning.Tech.PerfectHopBonus), Tuning.Tech.MaxCarrySpeed)
			horizontal = carried.Unit * math.max(speed, horizontal.Magnitude)
		end
	end
	ctx.Velocity = horizontal + Vector3.yAxis * math.sqrt(2 * Tuning.Gravity.Hop * height)
	ctx.FallPeak = ctx.Altitude + height
	ctx.Charge = math.min(1, ctx.Charge + T.BurstChargeGain)
end

function Hop.enter(ctx: Types.Ctx, payload: any)
	if payload ~= nil and payload.Launch then
		launch(ctx)
	else
		hop(ctx, if payload ~= nil and payload.Charge then payload.Charge else 0)
	end
	floating = false
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

	local vy = ctx.Velocity.Y
	if not floating then
		vy -= Tuning.Gravity.Hop * dt
		if vy <= 0 then
			floating = true
		end
	else
		floatTime += dt
		vy -= Tuning.Gravity.HopApexFloat * dt
		if floatTime >= T.ApexFloatTime then
			return "Glide", nil
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
