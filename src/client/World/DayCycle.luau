--!strict
-- Day/night cycle (spec §15 milestone 6; Tuning.DayCycle). The server stamps the world's start time on the
-- workspace (DayCycleStart, server clock); every client turns the shared elapsed time into a clock hour (day
-- 6:00–18:00 over DayShare of the cycle, night over the rest) and blends the keyed looks around that hour with a
-- smoothstep. The result is a set of multipliers and adds that the atmosphere driver folds into the altitude
-- band's look each frame, plus the sun's ClockTime, the exposure and the sun tint, written here. Client-only.

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local Tuning = require(game:GetService("ReplicatedStorage").Shared.Tuning)

local DayCycle = {}

export type Look = {
	Clock: number,
	Ambient: Color3,
	Outdoor: Color3,
	Brightness: number,
	Exposure: number,
	Atmosphere: Color3,
	Decay: Color3,
	Haze: number,
	Bloom: number,
	ShiftTop: Color3,
}

local START_ATTRIBUTE = "DayCycleStart"
local HOURS = 24

local current: Look

local function mix(a: Look, b: Look, t: number): Look
	local s = t * t * (3 - 2 * t)
	return {
		Clock = a.Clock + (b.Clock - a.Clock) * s,
		Ambient = a.Ambient:Lerp(b.Ambient, s),
		Outdoor = a.Outdoor:Lerp(b.Outdoor, s),
		Brightness = a.Brightness + (b.Brightness - a.Brightness) * s,
		Exposure = a.Exposure + (b.Exposure - a.Exposure) * s,
		Atmosphere = a.Atmosphere:Lerp(b.Atmosphere, s),
		Decay = a.Decay:Lerp(b.Decay, s),
		Haze = a.Haze + (b.Haze - a.Haze) * s,
		Bloom = a.Bloom + (b.Bloom - a.Bloom) * s,
		ShiftTop = a.ShiftTop:Lerp(b.ShiftTop, s),
	}
end

-- The clock hour for the shared elapsed time.
local function clockFor(elapsed: number): number
	local D = Tuning.DayCycle
	-- The cycle starts at StartClock: work out where in the cycle that hour sits, then advance.
	local startP = if D.StartClock >= 6 and D.StartClock < 18
		then (D.StartClock - 6) / 12 * D.DayShare
		else D.DayShare + ((D.StartClock - 18) % HOURS) / 12 * (1 - D.DayShare)
	local p = (startP + elapsed / math.max(D.CycleLength, 1e-3)) % 1
	if p < D.DayShare then
		return 6 + 12 * (p / D.DayShare)
	end
	return (18 + 12 * ((p - D.DayShare) / (1 - D.DayShare))) % HOURS
end

-- The look at a clock hour: the two keys around it (wrapping past midnight), blended.
local function lookAt(clock: number): Look
	local keys = Tuning.DayCycle.Keys :: { Look }
	local count = #keys
	for index = 1, count do
		local a = keys[index]
		local b = keys[index % count + 1]
		local span = (b.Clock - a.Clock) % HOURS
		local offset = (clock - a.Clock) % HOURS
		if span > 0 and offset <= span then
			local look = mix(a, b, offset / span)
			look.Clock = clock
			return look
		end
	end
	local look = table.clone(keys[1])
	look.Clock = clock
	return look
end

-- The blended look this frame, for the atmosphere driver.
function DayCycle.current(): Look
	return current
end

local function update()
	local start = workspace:GetAttribute(START_ATTRIBUTE)
	local elapsed = if type(start) == "number" then workspace:GetServerTimeNow() - start else 0
	current = lookAt(clockFor(elapsed))
	Lighting.ClockTime = current.Clock
	Lighting.ExposureCompensation = current.Exposure
	Lighting.ColorShift_Top = current.ShiftTop
end

function DayCycle.start()
	current = lookAt(Tuning.DayCycle.StartClock)
	update()
	RunService.RenderStepped:Connect(update)
end

return DayCycle
