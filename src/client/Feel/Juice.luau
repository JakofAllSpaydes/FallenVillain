--!strict
-- Runs the FeelTable (spec §12): every effect in the game is a data entry in Tuning.Feel, keyed by event, and
-- this module routes each entry to its sink. States never call effects; they only change state.
--
-- Events: the state entered ("Burst"), "Exit<State>" for the state left, punch results, "Bounce"
-- ("Rocket", "Dash"), and anything fired with Juice.fire (e.g. "RemoteBurst").
--
-- Entry keys: one sink key (cam, post, bus, loop, sound, vfx, spawn, time, ui) plus timing:
--   to / from / kick   the value (tween target, start, or one-shot amount)
--   dur                seconds; durAscent = fraction of this Burst's ascent time instead
--   delay              seconds; atApex = seconds relative to the predicted apex instead (negative = before)
-- byCharge = true scales the amounts (to, kick, radius, count, height) by the last Burst charge.
-- Delayed entries from a state's event are skipped if that state has already ended.

local Tuning = require(game:GetService("ReplicatedStorage").Shared.Tuning)

local CameraEffects = require(script.Parent.Parent.Camera.CameraEffects)
local Controller = require(script.Parent.Parent.Movement.Controller)
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

local SCALED_BY_CHARGE = { "to", "kick", "radius", "count", "height" }

local function scaledByCharge(entry: Entry): Entry
	local ctx = Controller.ctx
	if not entry.byCharge or not ctx then
		return entry
	end
	local scaled = table.clone(entry)
	for _, key in SCALED_BY_CHARGE do
		if type(scaled[key]) == "number" then
			scaled[key] *= ctx.BurstCharge
		end
	end
	if scaled.count then
		scaled.count = math.max(1, math.round(scaled.count))
	end
	return scaled
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
-- `whileState` cancels delayed entries once the player has left that state.
function Juice.fire(event: string, position: Vector3?, whileState: string?)
	local entries = Tuning.Feel[event]
	if not entries then
		return
	end
	local ascent = ascentTime()
	for _, raw: Entry in entries do
		local entry = scaledByCharge(raw)
		local duration = entry.dur or (if entry.durAscent then entry.durAscent * ascent else 0)
		local delay = entry.delay or (if entry.atApex then ascent + entry.atApex else 0)
		if delay <= 0 then
			run(entry, duration, position)
		else
			task.delay(delay, function()
				local ctx = Controller.ctx
				if whileState and (not ctx or ctx.State ~= whileState) then
					return
				end
				run(entry, duration, position)
			end)
		end
	end
end

function Juice.start()
	Controller.StateChanged:Connect(function(from, to, _payload)
		Juice.fire(`Exit{from}`)
		Juice.fire(to, nil, to)
	end)
	Punch.Fired:Connect(function(kind, _power, position)
		Juice.fire(kind, position)
	end)
	Controller.Bounced:Connect(function(position)
		Juice.fire("Bounce", position)
	end)
	Juice.fire("Grounded")
end

return Juice
