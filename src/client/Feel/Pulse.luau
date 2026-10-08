--!strict
-- Pulses (spec §4.1, §4.3, §4.6; Tuning.Pulse): one beat timer whose rate and strength follow the moment, each
-- beat firing a FeelTable event with its strength as the event's speed, so what a beat does (the thump, the
-- vignette squeeze, the haptic tap) stays in Tuning.Feel.
--   * Charging: the §4.1 sub-bass pulse, every 0.5 s tightening toward 0.2 s with the hold (ChargePulse).
--   * Burst: a slow heartbeat from BurstShare of the ascent (Heartbeat).
--   * Falling: a heartbeat that quickens and loudens with speed past Drive.Speed.HeatStart (Heartbeat); its
--     vignette and heat kicks are the §4.6 screen pulse.
-- Reads the controller; never drives movement.

local RunService = game:GetService("RunService")

local Tuning = require(game:GetService("ReplicatedStorage").Shared.Tuning)

local Controller = require(script.Parent.Parent.Movement.Controller)
local JumpCheck = require(script.Parent.Parent.Movement.JumpCheck)
local Juice = require(script.Parent.Juice)

local Pulse = {}

local GROUND_STATES: { [string]: boolean } = { Grounded = true, Landing = true, Slide = true }
local READY_PHASE = 0.85 -- an idle timer waits here so the first beat lands soon after a pulse starts

local phase = READY_PHASE

local function lastBurstTier(): number
	local heights = Tuning.Burst.HoldHeights
	return heights[#heights][1]
end

-- Beats per minute, strength 0–1 and the event for this frame; bpm 0 means no pulse.
local function current(ctx: any): (number, number, string)
	local P = Tuning.Pulse
	local state = ctx.State
	if state == "Charging" then
		local held = JumpCheck.held() or 0
		local progress = math.clamp(math.log(1 + held) / math.log(1 + lastBurstTier()), 0, 1)
		return P.ChargeBpmMin + (P.ChargeBpmMax - P.ChargeBpmMin) * progress, 0.5 + 0.5 * progress, "ChargePulse"
	elseif state == "Burst" then
		if ctx.StateTime >= P.BurstShare * ctx.BurstAscentTime then
			return P.BurstBpm, 0.6, "Heartbeat"
		end
		return 0, 0, ""
	elseif GROUND_STATES[state] then
		return 0, 0, ""
	end
	local over = ctx.Velocity.Magnitude - Tuning.Drive.Speed.HeatStart
	if over <= 0 then
		return 0, 0, ""
	end
	local p = math.clamp(over / math.max(P.FallRange, 1e-3), 0, 1)
	return P.FallBpmMin + (P.FallBpmMax - P.FallBpmMin) * p, p, "Heartbeat"
end

local function update(dt: number)
	local ctx = Controller.ctx
	if not ctx then
		phase = READY_PHASE
		return
	end
	local bpm, strength, event = current(ctx)
	if bpm <= 0 then
		phase = READY_PHASE
		return
	end
	phase += dt * bpm / 60
	if phase >= 1 then
		phase -= 1
		Juice.fire(event, nil, nil, nil, strength)
	end
end

function Pulse.start()
	RunService.RenderStepped:Connect(update)
end

return Pulse
