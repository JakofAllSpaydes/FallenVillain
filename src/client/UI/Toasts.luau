--!strict
-- Break toasts (spec §4.8 money feedback, §15 milestone 5): a short stack above the bottom centre, one card per
-- object the local player breaks ("TOWER  +$1,069"), coloured by its material family, big when it pays big.
-- A new card pops in at the bottom and pushes the rest up; each fades out after Ui.ToastTime. Pooled.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Destructibles = require(Shared.Destructibles)
local Tuning = require(Shared.Tuning)

local Destruction = require(script.Parent.Parent.Feel.Destruction)
local MathUtil = require(script.Parent.Parent.Movement.MathUtil)

local Toasts = {}

-- Look; not gameplay tuning.
local FONT = Enum.Font.FredokaOne
local OUTLINE = Color3.fromRGB(20, 20, 25)
local GOLD = Color3.fromRGB(230, 195, 110)
local FAMILY_COLORS: { [string]: Color3 } = {
	wood = Color3.fromRGB(205, 150, 95),
	stone = Color3.fromRGB(190, 190, 185),
	glass = Color3.fromRGB(170, 215, 240),
	metal = Color3.fromRGB(150, 160, 180),
}
local POP_TIME = 0.25
local POP_SCALE = 1.3
local FADE_SHARE = 0.25 -- last share of a card's life spent fading

type Card = {
	Frame: Frame,
	Name: TextLabel,
	Cash: TextLabel,
	Scale: UIScale,
	Start: number,
	Slot: number,
	Big: boolean,
	Prefab: string,
	Count: number,
	Total: number,
}

local cards: { Card } = {}
local active: { Card } = {} -- newest first

local function render(item: Card)
	local U = Tuning.Ui
	local label = U.PrefabNames[item.Prefab] or string.upper(item.Prefab)
	item.Name.Text = if item.Count > 1 then `{label} ×{item.Count}` else label
	item.Cash.Text = `+${math.floor(item.Total + 0.5)}`
	item.Big = item.Total >= U.ToastBigCash
end

local function show(prefab: string, cash: number)
	local U = Tuning.Ui
	local now = os.clock()
	-- The same kind again while its card is up: count up on that card (a wave of trees is one card, re-popped).
	for _, other in active do
		if other.Prefab == prefab and now - other.Start < U.ToastTime then
			other.Count += 1
			other.Total += cash
			other.Start = now
			render(other)
			return
		end
	end
	-- Otherwise a free card, or the oldest one when every card is busy.
	local card: Card? = nil
	for _, candidate in cards do
		if now - candidate.Start >= U.ToastTime then
			card = candidate
			break
		end
	end
	if not card then
		card = table.remove(active) :: Card
	end
	local item = card :: Card
	for index, other in active do
		if other == item then
			table.remove(active, index)
			break
		end
	end
	table.insert(active, 1, item)

	local entry = Destructibles.Catalog[prefab]
	local family = if entry then entry.Families[1] else "stone"
	item.Start = now
	item.Slot = -1 -- slides up into slot 0
	item.Prefab = prefab
	item.Count = 1
	item.Total = cash
	item.Name.TextColor3 = FAMILY_COLORS[family] or FAMILY_COLORS.stone
	render(item)
	item.Frame.Visible = true
end

local function update(dt: number)
	local U = Tuning.Ui
	local now = os.clock()
	for index, card in active do
		local age = now - card.Start
		if age >= U.ToastTime then
			card.Frame.Visible = false
			continue
		end
		card.Slot = MathUtil.approach(card.Slot, index - 1, U.ToastSlotResponse, dt)
		local pop = math.clamp(1 - age / POP_TIME, 0, 1)
		local size = (if card.Big then U.ToastBigScale else 1) * (1 + (POP_SCALE - 1) * pop * pop)
		card.Scale.Scale = size
		local fade = math.clamp((age - U.ToastTime * (1 - FADE_SHARE)) / (U.ToastTime * FADE_SHARE), 0, 1)
		local alpha = 1 - fade * fade
		card.Name.TextTransparency = 1 - alpha
		card.Cash.TextTransparency = 1 - alpha
		card.Name.TextStrokeTransparency = 1 - alpha
		card.Cash.TextStrokeTransparency = 1 - alpha
		local y = U.ToastBottom + math.max(card.Slot, 0) * (U.ToastHeight + U.ToastGap)
		card.Frame.Position = UDim2.new(0.5, 0, 1, -y)
	end
	for index = #active, 1, -1 do
		if now - active[index].Start >= U.ToastTime then
			table.remove(active, index)
		end
	end
end

local function label(parent: Instance, size: number, color: Color3, xAlign: Enum.TextXAlignment): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Font = FONT
	item.TextSize = size
	item.TextColor3 = color
	item.TextStrokeColor3 = OUTLINE
	item.TextStrokeTransparency = 0
	item.TextXAlignment = xAlign
	item.Size = UDim2.fromScale(0.5, 1)
	item.Parent = parent
	return item
end

function Toasts.start()
	local U = Tuning.Ui
	local gui = Instance.new("ScreenGui")
	gui.Name = "FallToasts"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 44

	for _ = 1, U.ToastPool do
		local frame = Instance.new("Frame")
		frame.BackgroundTransparency = 1
		frame.AnchorPoint = Vector2.new(0.5, 1)
		frame.Size = UDim2.fromOffset(260, U.ToastHeight)
		frame.Visible = false
		frame.Parent = gui
		local scale = Instance.new("UIScale")
		scale.Parent = frame
		local nameLabel = label(frame, U.ToastSize, GOLD, Enum.TextXAlignment.Right)
		nameLabel.Position = UDim2.fromScale(0, 0)
		nameLabel.Size = UDim2.new(0.5, -6, 1, 0)
		local cashLabel = label(frame, U.ToastSize, GOLD, Enum.TextXAlignment.Left)
		cashLabel.Position = UDim2.new(0.5, 6, 0, 0)
		cashLabel.Size = UDim2.new(0.5, -6, 1, 0)
		table.insert(cards, {
			Frame = frame,
			Name = nameLabel,
			Cash = cashLabel,
			Scale = scale,
			Start = -math.huge,
			Slot = 0,
			Big = false,
			Prefab = "",
			Count = 0,
			Total = 0,
		})
	end

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	Destruction.Credited:Connect(function(_position, cash, _combo, prefab)
		show(prefab, cash)
	end)
	RunService.RenderStepped:Connect(update)
end

return Toasts
