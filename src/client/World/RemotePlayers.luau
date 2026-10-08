--!strict
-- Other players' presence (spec §7, §9). Milestone 2: the burst column. Our own Burst reports to the server,
-- which rate-limits and broadcasts it; everyone else's column renders through the FeelTable "RemoteBurst".
-- Milestone 5: every other character carries an outline Highlight (spec §4.3: "people on the ground watch you
-- go"), drawn on top so a diver reads through fog and distance. Trails, impacts and wings for others later.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local Net = require(Shared.Net)
local Tuning = require(Shared.Tuning)

local Controller = require(script.Parent.Parent.Movement.Controller)
local Juice = require(script.Parent.Parent.Feel.Juice)
local Vfx = require(script.Parent.Parent.Feel.Vfx)

local RemotePlayers = {}

local function outline(character: Model)
	local U = Tuning.Ui
	local highlight = Instance.new("Highlight")
	highlight.Name = "FallOutline"
	highlight.FillTransparency = 1
	highlight.OutlineColor = U.RemoteOutline
	highlight.OutlineTransparency = U.RemoteOutlineTransparency
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Adornee = character
	highlight.Parent = character
end

local function watch(player: Player)
	if player == Players.LocalPlayer then
		return
	end
	if player.Character then
		outline(player.Character)
	end
	player.CharacterAdded:Connect(outline)
end

function RemotePlayers.start()
	local burstStarted = Net.event("BurstStarted")
	local burstColumn = Net.event("BurstColumn")

	Controller.StateChanged:Connect(function(_from, to, _payload)
		local ctx = Controller.ctx
		if to == "Burst" and ctx then
			burstStarted:FireServer(ctx.Level, ctx.Root.Position)
		end
	end)

	burstColumn.OnClientEvent:Connect(function(player: Player, position: Vector3)
		if player ~= Players.LocalPlayer then
			Juice.fire("RemoteBurst", Vfx.groundBelow(position))
		end
	end)

	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
end

return RemotePlayers
