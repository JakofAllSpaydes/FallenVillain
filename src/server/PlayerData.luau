--!strict
-- Per-player data (spec §13; §15 milestone 6). Session only, no DataStore yet. Cash, level and XP live on the
-- server and are mirrored to every client as attributes on the Player (`Cash`, `Level`, `Xp`, `XpNext`), so the
-- readouts, the XP bar and the charge caps read them. XP comes from the destruction payouts (shared/Progression
-- holds the curve); levels are applied here. In Studio the DevLevel remote jumps levels for testing.
-- Persistence and records arrive with the shrine.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Net = require(Shared.Net)
local Progression = require(Shared.Progression)
local Tuning = require(Shared.Tuning)

local PlayerData = {}

export type Data = {
	Cash: number,
	Combo: number,
	ComboEndsAt: number,
	TotalDestroyed: number,
	Level: number,
	Xp: number, -- into the current level
}

local data: { [Player]: Data } = {}

local function publish(player: Player, entry: Data)
	player:SetAttribute("Cash", math.floor(entry.Cash))
	player:SetAttribute("Level", entry.Level)
	player:SetAttribute("Xp", math.floor(entry.Xp))
	player:SetAttribute("XpNext", Progression.xpForLevel(entry.Level))
end

function PlayerData.get(player: Player): Data
	local existing = data[player]
	if existing then
		return existing
	end
	local fresh: Data = { Cash = 0, Combo = 0, ComboEndsAt = 0, TotalDestroyed = 0, Level = 1, Xp = 0 }
	data[player] = fresh
	publish(player, fresh)
	return fresh
end

function PlayerData.addCash(player: Player, amount: number)
	local entry = PlayerData.get(player)
	entry.Cash += amount
	player:SetAttribute("Cash", math.floor(entry.Cash))
end

-- XP toward the next level; levels up as many times as it fills. At MaxLevel the bar just sits full.
function PlayerData.addXp(player: Player, amount: number)
	local entry = PlayerData.get(player)
	local max = Tuning.Progression.MaxLevel
	entry.Xp += amount
	while entry.Level < max and entry.Xp >= Progression.xpForLevel(entry.Level) do
		entry.Xp -= Progression.xpForLevel(entry.Level)
		entry.Level += 1
	end
	if entry.Level >= max then
		entry.Xp = math.min(entry.Xp, Progression.xpForLevel(max))
	end
	publish(player, entry)
end

function PlayerData.setLevel(player: Player, level: number)
	local entry = PlayerData.get(player)
	entry.Level = math.clamp(math.floor(level), 1, Tuning.Progression.MaxLevel)
	entry.Xp = 0
	publish(player, entry)
end

function PlayerData.start()
	Players.PlayerAdded:Connect(function(player)
		PlayerData.get(player)
	end)
	for _, player in Players:GetPlayers() do
		PlayerData.get(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		data[player] = nil
	end)
	-- Test aid (the F2 panel's Level buttons): Studio only.
	Net.event("DevLevel").OnServerEvent:Connect(function(player, delta: unknown)
		if RunService:IsStudio() and type(delta) == "number" and delta == delta then
			PlayerData.setLevel(player, PlayerData.get(player).Level + math.floor(delta))
		end
	end)
end

return PlayerData
