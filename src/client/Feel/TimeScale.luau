--!strict
-- Hitstop and slow-mo (spec §12). A stack of timed multipliers; the lowest active one wins, so overlapping
-- hitstops resolve to the strongest without cutting each other short. Read by the movement controller (on dt
-- and the velocity handed to physics) and by effects that should freeze with it. Timers run in real time.

local TimeScale = {}

type Entry = { Scale: number, Until: number }

local stack: { Entry } = {}

function TimeScale.push(scale: number, duration: number)
	table.insert(stack, { Scale = scale, Until = os.clock() + duration })
end

function TimeScale.get(): number
	local now = os.clock()
	local scale = 1
	for index = #stack, 1, -1 do
		local entry = stack[index]
		if now >= entry.Until then
			table.remove(stack, index)
		else
			scale = math.min(scale, entry.Scale)
		end
	end
	return scale
end

return TimeScale
