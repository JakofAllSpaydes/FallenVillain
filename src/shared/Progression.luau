--!strict
-- Progression (spec §15 milestone 6): levels fed by the combo scoring. Every credit's cash is XP; each level
-- needs more. A level raises the power multiplier on every charge (Burst height, punch lunge, blast strength),
-- and set levels unlock the next charge "circle": the rings of the charge wheels, each a stretch of hold time.
-- Level Progression.MaxLevel has every circle and a multiplier of 1, which is the game as tuned. Shared by the
-- server (which owns XP and levels) and the client (which caps holds and draws the wheels).

local Tuning = require(script.Parent.Tuning)

local Progression = {}

export type Charge = "Burst" | "Punch" | "Blast"

-- XP needed to go from `level` to the next.
function Progression.xpForLevel(level: number): number
	local P = Tuning.Progression
	return P.XpBase + P.XpPerLevel * (level - 1)
end

-- Charge circles unlocked at a level.
function Progression.circles(level: number): number
	local count = 0
	for _, at in Tuning.Progression.CircleLevels do
		if level >= at then
			count += 1
		end
	end
	return math.max(count, 1)
end

-- The level that unlocks circle `index`, or nil.
function Progression.circleLevel(index: number): number?
	return Tuning.Progression.CircleLevels[index]
end

-- Power multiplier on every charge: PowerMin at level 1, 1 at MaxLevel.
function Progression.power(level: number): number
	local P = Tuning.Progression
	local t = math.clamp((level - 1) / math.max(P.MaxLevel - 1, 1), 0, 1)
	return P.PowerMin + (1 - P.PowerMin) * t
end

-- Seconds of hold where each circle of a charge ends (its wheel's ring ends).
function Progression.circleEnds(charge: Charge): { number }
	if charge == "Burst" then
		local B = Tuning.Burst
		local ends = table.clone(B.Tiers)
		table.insert(ends, B.HoldHeights[#B.HoldHeights][1])
		return ends
	elseif charge == "Punch" then
		local P = Tuning.Punch
		local ends = table.clone(P.Tiers)
		table.insert(ends, P.HoldBoosts[#P.HoldBoosts][1])
		return ends
	end
	local L = Tuning.Blast
	local ends = table.clone(L.Tiers)
	table.insert(ends, L.HoldStrengths[#L.HoldStrengths][1])
	return ends
end

-- The longest hold a charge honours at this level: the end of the last unlocked circle, or no limit once every
-- circle is open (the spirit bomb's charge is uncapped).
function Progression.holdCap(charge: Charge, level: number): number
	local ends = Progression.circleEnds(charge)
	local count = Progression.circles(level)
	if count >= #ends then
		return math.huge
	end
	return ends[count]
end

-- A hold clamped to what the level allows.
function Progression.capHold(charge: Charge, held: number, level: number): number
	return math.min(held, Progression.holdCap(charge, level))
end

-- The level a Player attribute reports, or 1.
function Progression.levelOf(player: Player): number
	local level = player:GetAttribute("Level")
	return if type(level) == "number" then level else 1
end

return Progression
