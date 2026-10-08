--!strict
-- RMB blast (spec §15 milestone 6; replaces the §3/§4.11 laser). Holding charges it anywhere, ground or air,
-- like the punch: nothing but releasing spends it. What fires depends on how many circles the hold filled
-- (review note): under Blast.ChargeTime a single shot; up to the second circle's end a chain of bigger shots;
-- up to the fourth a kamehameha beam; past the fourth the spirit bomb, which charges above the head as a
-- growing ball from then on and is thrown on release. Strengths follow the hold curve times the level's power
-- multiplier, and the unlocked circles cap the hold (shared/Progression.luau). Every release kicks you back a
-- little. The blast never changes the movement state; Combat/Blaster flies the shots, the beam and the bomb.
-- The controller calls `update` every frame after the punch.

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Progression = require(Shared.Progression)
local Signal = require(Shared.Signal)
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)
local MathUtil = require(script.Parent.MathUtil)

local Blast = {}

export type Kind = "Shot" | "Chain" | "Beam" | "Spirit" | "Fizzle"

-- (kind, seconds held (capped), aim direction, strength)
Blast.Fired = Signal.new() :: Signal.Signal<Kind, number, Vector3, number>
-- (seconds held) when a charge starts
Blast.ChargeStarted = Signal.new() :: Signal.Signal<number>
-- (seconds held) each time the hold crosses a Blast.Tiers threshold the level has unlocked
Blast.TierReached = Signal.new() :: Signal.Signal<number>

function Blast.strengthFor(seconds: number): number
	return MathUtil.holdCurve(Tuning.Blast.HoldStrengths, seconds)
end

function Blast.beamTimeFor(seconds: number): number
	return MathUtil.holdCurve(Tuning.Blast.HoldBeamTimes, seconds)
end

function Blast.beamWidthFor(seconds: number): number
	return MathUtil.holdCurve(Tuning.Blast.HoldBeamWidths, seconds)
end

function Blast.beamRangeFor(seconds: number): number
	return MathUtil.holdCurve(Tuning.Blast.HoldBeamRanges, seconds)
end

-- Which release a hold of `seconds` gives.
function Blast.kindFor(seconds: number): Kind
	local ends = Progression.circleEnds("Blast")
	if seconds < Tuning.Blast.ChargeTime then
		return "Shot"
	elseif seconds < ends[2] then
		return "Chain"
	elseif seconds < ends[4] then
		return "Beam"
	end
	return "Spirit"
end

-- Shots in a chain for a hold: ChainMinShots at ChargeTime, ChainMaxShots at the second circle's end.
function Blast.chainCount(seconds: number): number
	local L = Tuning.Blast
	local ends = Progression.circleEnds("Blast")
	local t = math.clamp((seconds - L.ChargeTime) / math.max(ends[2] - L.ChargeTime, 1e-3), 0, 1)
	return math.round(L.ChainMinShots + (L.ChainMaxShots - L.ChainMinShots) * t)
end

-- How far the spirit bomb has charged: 0 before the fourth circle's end, 1 at the fifth, and on past it (the
-- charge is uncapped once every circle is unlocked).
function Blast.spiritProgress(seconds: number): number
	local ends = Progression.circleEnds("Blast")
	return math.max(0, (seconds - ends[4]) / math.max(ends[5] - ends[4], 1e-3))
end

-- The hold this frame, capped by the level, or nil.
function Blast.cappedHold(ctx: Types.Ctx): number?
	local hold = ctx.BlastHold
	return if hold then Progression.capHold("Blast", hold, ctx.Level) else nil
end

-- Speed multiplier while a blast is charging.
function Blast.slow(ctx: Types.Ctx, mult: number): number
	return if ctx.BlastHold ~= nil then mult else 1
end

local function aimDirection(ctx: Types.Ctx): Vector3
	local toAim = ctx.AimPoint - ctx.Root.Position
	return if toAim.Magnitude > 1e-3 then toAim.Unit else ctx.LookDirection
end

-- Studio-only trace (Tuning.Dev.TraceMovement), like the controller's.
local function trace(message: string)
	if Tuning.Dev.TraceMovement and RunService:IsStudio() then
		print(`[FALL blast] {message}`)
	end
end

function Blast.update(ctx: Types.Ctx, dt: number)
	local L = Tuning.Blast
	-- A click pressed and released inside one frame is still a tap: give it a zero hold to release below.
	if ctx.BlastHold == nil and ctx.Input.SecondaryPressed and not ctx.Input.SecondaryHeld then
		ctx.BlastHold = 0
	end
	if ctx.Input.SecondaryHeld then
		local before = ctx.BlastHold
		local hold = (before or 0) + dt * Tuning.Dev.ChargeSpeed
		ctx.BlastHold = hold
		if before == nil then
			trace("charging")
			Blast.ChargeStarted:Fire(hold)
		else
			local after = MathUtil.tier(L.Tiers, hold)
			if after > MathUtil.tier(L.Tiers, before) and after <= Progression.circles(ctx.Level) - 1 then
				Blast.TierReached:Fire(hold)
			end
		end
		return
	end
	local hold = ctx.BlastHold
	if hold == nil then
		return
	end
	ctx.BlastHold = nil
	local direction = aimDirection(ctx)
	if ctx.Now < ctx.BlastReadyAt then
		Blast.Fired:Fire("Fizzle", hold, direction, 0)
		return
	end
	hold = Progression.capHold("Blast", hold, ctx.Level)
	local strength = Blast.strengthFor(hold) * Progression.power(ctx.Level)
	local kind = Blast.kindFor(hold)
	if kind == "Shot" or kind == "Chain" then
		ctx.Velocity -= direction * L.ShotRecoil
		ctx.BlastReadyAt = ctx.Now + L.Cooldown
		if kind == "Chain" then
			ctx.BlastReadyAt += Blast.chainCount(hold) * L.ChainInterval
		end
	elseif kind == "Beam" then
		ctx.Velocity -= direction * L.BeamRecoil
		ctx.BeamUntil = ctx.Now + Blast.beamTimeFor(hold)
		ctx.BlastReadyAt = ctx.BeamUntil + L.Cooldown
	else
		ctx.Velocity -= direction * L.BeamRecoil
		ctx.BlastReadyAt = ctx.Now + L.Cooldown
	end
	trace(string.format("%s: hold %.2f strength %.0f", kind, hold, strength))
	Blast.Fired:Fire(kind, hold, direction, strength)
end

return Blast
