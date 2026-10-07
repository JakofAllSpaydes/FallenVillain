--!strict
-- Hop (spec §3, §4.9): instant takeoff, holding space raises the apex up to the charged height,
-- then a short low-gravity float before handing off to Glide. Ground smash is a tiny hop into a forced dive.

local Shared = game:GetService("ReplicatedStorage").Shared
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)
local MathUtil = require(script.Parent.Parent.MathUtil)

local Hop = { Air = true }

local smash = false
local charging = false
local floating = false
local holdTime = 0
local floatTime = 0
local startY = 0
local baseHeight = 0
local chargedHeight = 0

function Hop.enter(ctx: Types.Ctx, payload: any)
	local T = Tuning.Hop
	smash = payload ~= nil and payload.Smash == true

	if not smash and ctx.Now - ctx.LastLandTime <= T.ChainWindow then
		ctx.HopChain = math.min(ctx.HopChain + 1, T.MaxChain)
	else
		ctx.HopChain = 0
	end
	local chainMult = 1 + T.ChainBonus * ctx.HopChain

	baseHeight = if smash then Tuning.Impact.GroundSmashHopHeight else T.Height * chainMult
	chargedHeight = T.ChargedHeight * chainMult
	charging = not smash and ctx.Input.JumpHeld
	floating = false
	holdTime = 0
	floatTime = 0
	startY = ctx.Root.Position.Y

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
	local vy = math.sqrt(2 * Tuning.Gravity.Hop * baseHeight)
	ctx.Velocity = horizontal + Vector3.yAxis * vy
	ctx.GlideEnergy = Tuning.GlideEnergy.Max
	ctx.FallPeak = ctx.Altitude + baseHeight
	ctx.Charge = math.min(1, ctx.Charge + T.BurstChargeGain)
	ctx.BodyDirection = nil
	ctx.Bank = 0
end

function Hop.update(ctx: Types.Ctx, dt: number): (Types.MovementState?, any)
	local T = Tuning.Hop
	if ctx.Input.PrimaryPressed and not smash then
		return "Dive", nil
	end

	local vy = ctx.Velocity.Y
	if not floating then
		if charging and ctx.Input.JumpHeld and holdTime < T.ChargeTime then
			holdTime = math.min(holdTime + dt, T.ChargeTime)
			local height = baseHeight + (chargedHeight - baseHeight) * (holdTime / T.ChargeTime)
			local remaining = math.max(0, startY + height - ctx.Root.Position.Y)
			vy = math.max(vy, math.sqrt(2 * Tuning.Gravity.Hop * remaining))
			ctx.FallPeak = math.max(ctx.FallPeak, ctx.Altitude + remaining)
		else
			charging = false
		end
		vy -= Tuning.Gravity.Hop * dt
		if vy <= 0 then
			if smash then
				return "Dive", { Forced = true, StraightDown = true }
			end
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
