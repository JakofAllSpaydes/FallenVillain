--!strict
-- Broadcasts arc events to every client (spec §7, §9, §13). Milestone 2: burst columns. The server takes the
-- launch spot from the client only if it is within Net.MaxPositionError of the replicated character, and drops
-- bursts faster than the rate limit.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local Net = require(Shared.Net)
local Tuning = require(Shared.Tuning)

local Presence = {}

local lastBurst: { [Player]: number } = {}

function Presence.start()
	local burstStarted = Net.event("BurstStarted")
	local burstColumn = Net.event("BurstColumn")

	burstStarted.OnServerEvent:Connect(function(player: Player, _power: unknown, position: unknown)
		local now = os.clock()
		if now - (lastBurst[player] or -math.huge) < Tuning.Net.BurstMinInterval then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return
		end
		local at = root.Position
		if typeof(position) == "Vector3" and (position - at).Magnitude <= Tuning.Net.MaxPositionError then
			at = position
		end
		lastBurst[player] = now
		burstColumn:FireAllClients(player, at)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastBurst[player] = nil
	end)
end

return Presence
