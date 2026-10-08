--!strict
-- Hitstop and slow-mo (spec §12). A stack of timed multipliers; the lowest active one wins, so overlapping
-- hitstops resolve to the strongest without cutting each other short. An eased entry starts at its scale and
-- climbs back to 1 over its duration (quadratic ease-in: it holds slow, then speeds up), so a freeze can hand
-- over to a slow-motion tail that releases smoothly. Read by the movement controller (on dt and the velocity
-- handed to physics) and by effects that should freeze with it. Timers run in real time.

local TimeScale = {}

type Entry = { Scale: number, Start: number, Until: number, Ease: boolean }

local stack: { Entry } = {}

function TimeScale.push(scale: number, duration: number, ease: boolean?)
	local now = os.clock()
	table.insert(stack, { Scale = scale, Start = now, Until = now + duration, Ease = ease == true })
end

function TimeScale.get(): number
	local now = os.clock()
	local scale = 1
	for index = #stack, 1, -1 do
		local entry = stack[index]
		if now >= entry.Until then
			table.remove(stack, index)
		else
			local value = entry.Scale
			if entry.Ease then
				local p = (now - entry.Start) / math.max(entry.Until - entry.Start, 1e-3)
				value = entry.Scale + (1 - entry.Scale) * p * p
			end
			scale = math.min(scale, value)
		end
	end
	return scale
end

return TimeScale
