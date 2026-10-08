--!strict
-- Other players' presence (spec §7, §9). Milestone 2: the burst column. Our own Burst reports to the server,
-- which rate-limits and broadcasts it; everyone else's column renders through the FeelTable "RemoteBurst".
-- Milestone 5/6 (review note: always show other players with their name and a distance marker): every other
-- character carries an outline Highlight drawn on top, and a marker above the head with the display name and
-- the distance to you ("340 m", "1.2 km"; studs, close enough) at any range. The engine's own name tag is
-- turned off for them. Trails, impacts, shots and beams for others later.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Net = require(Shared.Net)
local Tuning = require(Shared.Tuning)

local Controller = require(script.Parent.Parent.Movement.Controller)
local Juice = require(script.Parent.Parent.Feel.Juice)
local Vfx = require(script.Parent.Parent.Feel.Vfx)

local RemotePlayers = {}

-- Look; not gameplay tuning.
local FONT = Enum.Font.FredokaOne
local OUTLINE = Color3.fromRGB(20, 20, 25)
local MARKER_WIDTH = 220

type Marker = { Player: Player, Gui: BillboardGui, Distance: TextLabel, Scale: UIScale }

local markers: { [Player]: Marker } = {}

local function label(parent: Instance, size: number, color: Color3, order: number): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Font = FONT
	item.TextSize = size
	item.TextColor3 = color
	item.TextStrokeColor3 = OUTLINE
	item.TextStrokeTransparency = 0.1
	item.Size = UDim2.new(1, 0, 0, size + 4)
	item.LayoutOrder = order
	item.Parent = parent
	return item
end

local function dress(player: Player, character: Model)
	local U = Tuning.Ui
	local highlight = Instance.new("Highlight")
	highlight.Name = "FallOutline"
	highlight.FillTransparency = 1
	highlight.OutlineColor = U.RemoteOutline
	highlight.OutlineTransparency = U.RemoteOutlineTransparency
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Adornee = character
	highlight.Parent = character

	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "FallMarker"
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = math.huge
	gui.Size = UDim2.fromOffset(MARKER_WIDTH, U.RemoteNameSize + U.RemoteDistanceSize + 12)
	gui.StudsOffset = Vector3.yAxis * U.RemoteMarkerHeight
	gui.Adornee = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart or character
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = gui
	local name = label(gui, U.RemoteNameSize, U.RemoteOutline, 1)
	name.Text = player.DisplayName
	local distance = label(gui, U.RemoteDistanceSize, Color3.new(1, 1, 1), 2)
	distance.TextTransparency = 0.15
	local scale = Instance.new("UIScale")
	scale.Parent = gui
	gui.Parent = character
	markers[player] = { Player = player, Gui = gui, Distance = distance, Scale = scale }
end

local function watch(player: Player)
	if player == Players.LocalPlayer then
		return
	end
	if player.Character then
		dress(player, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		dress(player, character)
	end)
end

local function distanceText(studs: number): string
	if studs >= 1000 then
		return string.format("%.1f km", studs / 1000)
	end
	return string.format("%d m", math.floor(studs))
end

local function update()
	local ctx = Controller.ctx
	if not ctx then
		return
	end
	for player, marker in markers do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") or marker.Gui.Parent ~= character then
			continue
		end
		local U = Tuning.Ui
		local studs = (root.Position - ctx.Root.Position).Magnitude
		marker.Distance.Text = distanceText(studs)
		-- Full size up close, shrinking with distance to a readable floor.
		marker.Scale.Scale = math.clamp(U.RemoteMarkerRefDistance / math.max(studs, 1), U.RemoteMarkerMinScale, 1)
	end
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
	Players.PlayerRemoving:Connect(function(player)
		markers[player] = nil
	end)
	RunService.RenderStepped:Connect(update)
end

return RemotePlayers
