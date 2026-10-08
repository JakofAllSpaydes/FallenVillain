--!strict
-- Break toasts (spec §4.8 money feedback, §15 milestone 5): a short stack above the bottom centre, one card per
-- object the local player breaks ("TOWER  +$1,069"), coloured by its material family, big when it pays big.
-- A new card pops in at the bottom and pushes the rest up; after Ui.ToastTime each flies up into the XP bar
-- (UI/XpBar), shrinking, and lands its XP there with a pulse (spec §15 milestone 6). Pooled.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Destructibles = require(Shared.Destructibles)
local Tuning = require(Shared.Tuning)

local Destruction = require(script.Parent.Parent.Feel.Destruction)
local MathUtil = require(script.Parent.Parent.Movement.MathUtil)
local XpBar = require(script.Parent.XpBar)

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
local SLAM_CYCLES, SLAM_DECAY = 1.75, 5 -- the Layers slam curve, inlined for per-card timing

-- A card's whole life: on display, then in flight to the XP bar.
local function lifetime(): number
	return Tuning.Ui.ToastTime + Tuning.Ui.ToastFlyTime
end

-- Lands at 1, squashes below zero, settles (the same shape as the Layers "slam" curve).
local function slam(p: number): number
	if p >= 1 then
		return 0
	end
	return math.exp(-SLAM_DECAY * p) * math.cos(2 * math.pi * SLAM_CYCLES * p)
end

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
	Landed: boolean, -- its XP has been handed to the bar
	From: UDim2, -- where its flight to the bar began
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
		if other.Prefab == prefab and now - other.Start < U.ToastTime and not other.Landed then
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
		if now - candidate.Start >= lifetime() then
			card = candidate
			break
		end
	end
	if not card then
		card = table.remove(active) :: Card
		if card and not card.Landed then
			XpBar.absorb(card.Total * Tuning.Progression.XpPerCash) -- a card cut short still pays its XP in
		end
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
	item.Landed = false
	item.Name.TextColor3 = FAMILY_COLORS[family] or FAMILY_COLORS.stone
	render(item)
	item.Frame.Visible = true
end

local function update(dt: number)
	local U = Tuning.Ui
	local now = os.clock()
	local life = lifetime()
	for index, card in active do
		local age = now - card.Start
		if age >= life then
			card.Frame.Visible = false
			if not card.Landed then
				card.Landed = true
				XpBar.absorb(card.Total * Tuning.Progression.XpPerCash)
			end
			continue
		end
		local big = if card.Big then U.ToastBigScale else 1
		if age < U.ToastTime then
			card.Slot = MathUtil.approach(card.Slot, index - 1, U.ToastSlotResponse, dt)
			-- Slam in: oversized and from below, squash, settle.
			local p = age / math.max(U.ToastPopTime, 1e-3)
			local pop = slam(p)
			card.Scale.Scale = big * math.max(0.2, 1 + (U.ToastPopScale - 1) * pop)
			local slide = U.ToastSlideIn * math.max(0, 1 - p) ^ 2
			local y = U.ToastBottom + math.max(card.Slot, 0) * (U.ToastHeight + U.ToastGap) - slide
			card.Frame.Position = UDim2.new(0.5, 0, 1, -y)
			card.From = card.Frame.Position
			card.Name.TextTransparency = 0
			card.Cash.TextTransparency = 0
			card.Name.TextStrokeTransparency = 0
			card.Cash.TextStrokeTransparency = 0
		else
			-- In flight to the XP bar: ease in, shrink, fade at the very end.
			local q = math.clamp((age - U.ToastTime) / math.max(U.ToastFlyTime, 1e-3), 0, 1)
			local ease = q * q * (3 - 2 * q)
			card.Frame.Position = card.From:Lerp(XpBar.target(), ease)
			card.Scale.Scale = big * (1 + (U.ToastFlyScale - 1) * ease)
			local alpha = 1 - math.clamp((q - 0.8) / 0.2, 0, 1)
			card.Name.TextTransparency = 1 - alpha
			card.Cash.TextTransparency = 1 - alpha
			card.Name.TextStrokeTransparency = 1 - alpha
			card.Cash.TextStrokeTransparency = 1 - alpha
		end
	end
	for index = #active, 1, -1 do
		if now - active[index].Start >= life then
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
			Landed = true,
			From = UDim2.new(),
		})
	end

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	Destruction.Credited:Connect(function(_position, cash, _combo, prefab)
		XpBar.pend(cash * Tuning.Progression.XpPerCash)
		show(prefab, cash)
	end)
	RunService.RenderStepped:Connect(update)
end

return Toasts
