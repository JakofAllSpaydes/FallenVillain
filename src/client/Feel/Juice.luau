--!strict
-- Runs the FeelTable (spec §12): every effect in the game is a data entry in Tuning.Feel, keyed by event, and
-- this module routes each entry to its sink. States never call effects; they only change state.
--
-- Events: the state entered ("Burst"), "Exit<State>" for the state left, "Bounce", punch results
-- ("Rocket", "Dash", "Fizzle"), the charge events ("PunchCharge", "PunchTier", "BurstTier"),
-- and anything fired with Juice.fire (e.g. "RemoteBurst").
--
-- Entry keys: one sink key (cam, post, bus, loop, sound, vfx, spawn, time, ui) plus timing:
--   to / from / kick   the value (tween target, start, or one-shot amount)
--   dur                seconds; durAscent = fraction of this Burst's ascent time instead
--   delay              seconds; atApex = seconds relative to the predicted apex instead (negative = before)
-- minHeld / maxHeld: only play when the hold (the last Burst's Space hold, or the punch's LMB hold for punch
-- events) was at least / under that many seconds.
-- byCharge = true scales the amounts (to, kick, radius, count, height) by the last Burst charge.
-- minSpeed gates an entry on the event's speed (a touchdown or bounce speed); bySpeed = true scales the same
-- amounts, plus `volume` for sounds, by how far the speed is from minSpeed to fullSpeed, and `dur` from
-- durMin (if given) to dur.
-- Delayed entries from a state's event are skipped if that state has already ended.

local Tuning = require(game:GetService("ReplicatedStorage").Shared.Tuning)

local CameraEffects = require(script.Parent.Parent.Camera.CameraEffects)
local Controller = require(script.Parent.Parent.Movement.Controller)
local JumpCheck = require(script.Parent.Parent.Movement.JumpCheck)
local Punch = require(script.Parent.Parent.Movement.Punch)
local AltitudeReadout = require(script.Parent.Parent.UI.AltitudeReadout)
local Audio = require(script.Parent.Audio)
local Post = require(script.Parent.Post)
local TimeScale = require(script.Parent.TimeScale)
local Vfx = require(script.Parent.Vfx)

local Juice = {}

type Entry = { [string]: any }

local function ascentTime(): number
	local ctx = Controller.ctx
	return if ctx then ctx.BurstAscentTime else 0
end

local SCALED_AMOUNTS = { "to", "kick", "radius", "count", "height", "volume", "size" }

local function scaleAmounts(entry: Entry, factor: number): Entry
	local scaled = table.clone(entry)
	for _, key in SCALED_AMOUNTS do
		if type(scaled[key]) == "number" then
			scaled[key] *= factor
		end
	end
	if scaled.count then
		scaled.count = math.max(1, math.round(scaled.count))
	end
	return scaled
end

-- byCharge scales by the last Burst charge; bySpeed by where `speed` sits between minSpeed and fullSpeed.
local function scaled(entry: Entry, speed: number?): Entry
	local ctx = Controller.ctx
	local result = entry
	if entry.byCharge and ctx then
		result = scaleAmounts(result, ctx.BurstCharge)
	end
	if entry.bySpeed and speed then
		local low = entry.minSpeed or 0
		local factor = math.clamp((speed - low) / math.max((entry.fullSpeed or low) - low, 1e-3), 0, 1)
		result = scaleAmounts(result, factor)
		if result.durMin and result.dur then
			result.dur = result.durMin + (result.dur - result.durMin) * factor
		end
	end
	return result
end

local function run(entry: Entry, duration: number, position: Vector3?)
	if entry.cam then
		CameraEffects.apply(entry, duration)
	elseif entry.post then
		Post.apply(entry, duration)
	elseif entry.bus or entry.loop or entry.sound then
		Audio.apply(entry, duration)
	elseif entry.vfx then
		Vfx.apply(entry, duration)
	elseif entry.spawn then
		local at = position or Vfx.playerGround()
		if at then
			Vfx.spawn(entry, duration, at)
		end
	elseif entry.time then
		TimeScale.push(entry.time, duration)
	elseif entry.ui then
		if entry.record then
			local ctx = Controller.ctx
			if ctx then
				AltitudeReadout.checkRecord(ctx.Altitude)
			end
		end
		AltitudeReadout.apply(entry, duration)
	end
end

-- Fire a FeelTable event. `position` places spawns (default: the ground under the local player);
-- `whileState` cancels delayed entries once the player has left that state. `held` is the hold minHeld and
-- maxHeld compare against (default: the last Burst's Space hold). `speed` is what minSpeed and bySpeed use.
function Juice.fire(event: string, position: Vector3?, whileState: string?, held: number?, speed: number?)
	local entries = Tuning.Feel[event]
	if not entries then
		return
	end
	local ascent = ascentTime()
	local ctx = Controller.ctx
	local against = held or (if ctx then ctx.BurstHeld else 0)
	for _, raw: Entry in entries do
		if (raw.minHeld and against < raw.minHeld) or (raw.maxHeld and against >= raw.maxHeld) then
			continue
		end
		if raw.minSpeed and (speed or 0) < raw.minSpeed then
			continue
		end
		local entry = scaled(raw, speed)
		local duration = entry.dur or (if entry.durAscent then entry.durAscent * ascent else 0)
		local delay = entry.delay or (if entry.atApex then ascent + entry.atApex else 0)
		if delay <= 0 then
			run(entry, duration, position)
		else
			task.delay(delay, function()
				local now = Controller.ctx
				if whileState and (not now or now.State ~= whileState) then
					return
				end
				run(entry, duration, position)
			end)
		end
	end
end

function Juice.start()
	Controller.StateChanged:Connect(function(from, to, payload)
		local speed = if type(payload) == "table" then payload.Speed else nil
		Juice.fire(`Exit{from}`)
		Juice.fire(to, nil, to, nil, speed)
	end)
	Punch.Fired:Connect(function(kind, held, position)
		Juice.fire(kind, position, nil, held)
	end)
	Punch.ChargeStarted:Connect(function(held)
		Juice.fire("PunchCharge", nil, nil, held)
	end)
	Punch.TierReached:Connect(function(held)
		Juice.fire("PunchTier", nil, nil, held)
	end)
	JumpCheck.TierReached:Connect(function(held)
		Juice.fire("BurstTier", nil, nil, held)
	end)
	Controller.Bounced:Connect(function(position, speed)
		Juice.fire("Bounce", position, nil, nil, speed)
	end)
	Juice.fire("Grounded")
end

return Juice
