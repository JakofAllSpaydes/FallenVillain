--!strict
-- Other players' presence (spec §7, §9). Milestone 2: the burst column. Our own Burst reports to the server,
-- which rate-limits and broadcasts it; everyone else's column renders through the FeelTable "RemoteBurst".
-- Milestone 5 adds highlights, trails, impacts and lasers here.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local Net = require(Shared.Net)

local Controller = require(script.Parent.Parent.Movement.Controller)
local Juice = require(script.Parent.Parent.Feel.Juice)
local Vfx = require(script.Parent.Parent.Feel.Vfx)

local RemotePlayers = {}

function RemotePlayers.start()
	local burstStarted = Net.event("BurstStarted")
	local burstColumn = Net.event("BurstColumn")

	Controller.StateChanged:Connect(function(_from, to, _payload)
		local ctx = Controller.ctx
		if to == "Burst" and ctx then
			burstStarted:FireServer(ctx.Power, ctx.Root.Position)
		end
	end)

	burstColumn.OnClientEvent:Connect(function(player: Player, position: Vector3)
		if player ~= Players.LocalPlayer then
			Juice.fire("RemoteBurst", Vfx.groundBelow(position))
		end
	end)
end

return RemotePlayers
