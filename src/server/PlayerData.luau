--!strict
-- Per-player data (spec §13). Milestone 4: session only, no DataStore yet. Cash lives on the server and is
-- mirrored to every client as a `Cash` attribute on the Player, so the readout and the player list can show it.
-- Persistence, Power purchases and records arrive with the shrine.

local Players = game:GetService("Players")

local PlayerData = {}

export type Data = { Cash: number, Combo: number, ComboEndsAt: number, TotalDestroyed: number }

local data: { [Player]: Data } = {}

function PlayerData.get(player: Player): Data
	local existing = data[player]
	if existing then
		return existing
	end
	local fresh: Data = { Cash = 0, Combo = 0, ComboEndsAt = 0, TotalDestroyed = 0 }
	data[player] = fresh
	player:SetAttribute("Cash", 0)
	return fresh
end

function PlayerData.addCash(player: Player, amount: number)
	local entry = PlayerData.get(player)
	entry.Cash += amount
	player:SetAttribute("Cash", math.floor(entry.Cash))
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
end

return PlayerData
