--!strict
-- XP bar (spec §15 milestone 6): a thin bar across the top of the screen with the level beside it. The server
-- owns XP and levels (Player attributes Level, Xp, XpNext); the bar shows them with the toasts' share held back
-- until each toast flies in (UI/Toasts calls `pend` as cash is credited and `absorb` as its card lands), so the
-- bar fills as the cards arrive, pulsing on each. Filling it plays the level-up celebration: a banner slams in
-- under the bar with the new level (and NEW CIRCLE when one unlocks) and the FeelTable LevelUp / CircleUnlocked
-- events fire at the player. A jump of several levels at once (the dev buttons) snaps and celebrates once.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Net = require(Shared.Net)
local Progression = require(Shared.Progression)
local Tuning = require(Shared.Tuning)

local Juice = require(script.Parent.Parent.Feel.Juice)
local Layers = require(script.Parent.Parent.Feel.Layers)
local MathUtil = require(script.Parent.Parent.Movement.MathUtil)

local XpBar = {}

-- Look; not gameplay tuning.
local FONT = Enum.Font.FredokaOne
local GOLD = Color3.fromRGB(230, 195, 110)
local WHITE = Color3.new(1, 1, 1)
local HOT = Color3.fromRGB(255, 150, 80)
local OUTLINE = Color3.fromRGB(20, 20, 25)
local TRACK = Color3.fromRGB(30, 30, 36)
local BANNER_GAP = 34 -- pixels under the bar the banner sits

local layers = Layers.new({ "Pulse", "Flash", "Banner" })

local frame: Frame
local scale: UIScale
local fill: Frame
local levelLabel: TextLabel
local nextLabel: TextLabel
local banner: Frame
local bannerScale: UIScale
local bannerTitle: TextLabel
local bannerLevel: TextLabel
local bannerCircle: TextLabel

local shownTotal = -1 -- total XP shown (all levels), -1 until the first read
local shownLevel = 1
local pending = 0
local bannerUntil = -math.huge

-- Total XP at the start of `level` (the sum of every earlier level's requirement).
local function totalAt(level: number): number
	local P = Tuning.Progression
	local n = level - 1
	return P.XpBase * n + P.XpPerLevel * n * (n - 1) / 2
end

-- Level and XP into it for a total.
local function split(total: number): (number, number)
	local level = 1
	local max = Tuning.Progression.MaxLevel
	while level < max and total >= totalAt(level + 1) do
		level += 1
	end
	return level, total - totalAt(level)
end

local function withCommas(value: number): string
	local text = tostring(math.floor(value + 0.5))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

-- XP credited but not yet shown (a toast in flight).
function XpBar.pend(amount: number)
	pending += amount
end

-- A toast landed: its XP joins the bar with a pulse.
function XpBar.absorb(amount: number)
	pending = math.max(0, pending - amount)
	layers:kick("Pulse", 1, Tuning.Ui.XpPulse, "slam")
	layers:kick("Flash", 1, Tuning.Ui.XpPulse, "expo")
end

-- Where toasts fly to: the bar's centre.
function XpBar.target(): UDim2
	return UDim2.new(0.5, 0, 0, Tuning.Ui.XpBarTop + Tuning.Ui.XpBarHeight / 2)
end

local function celebrate(from: number, to: number)
	local U = Tuning.Ui
	local unlocked = false
	for _, at in Tuning.Progression.CircleLevels do
		if at > from and at <= to then
			unlocked = true
		end
	end
	bannerUntil = os.clock() + U.XpBannerTime
	bannerLevel.Text = `LV {to}`
	bannerCircle.Visible = unlocked
	layers:kick("Banner", 1, U.XpBannerPop, "slam")
	layers:kick("Flash", 1.5, 0.5, "expo")
	layers:kick("Pulse", 1.4, U.XpPulse * 1.5, "slam")
	Juice.fire("LevelUp", nil, nil, nil, to)
	if unlocked then
		Juice.fire("CircleUnlocked", nil, nil, nil, to)
	end
end

local function update(dt: number)
	local U = Tuning.Ui
	local player = Players.LocalPlayer
	local serverLevel = Progression.levelOf(player)
	local xp = player:GetAttribute("Xp")
	local serverTotal = totalAt(serverLevel) + (if type(xp) == "number" then xp else 0)
	local target = math.max(0, serverTotal - pending)
	local now = os.clock()

	if shownTotal < 0 then
		shownTotal = target
		shownLevel = split(shownTotal)
	elseif target < shownTotal - 1 then
		-- Levels went down (a dev jump): snap quietly.
		shownTotal = target
		shownLevel = split(shownTotal)
		pending = 0
	else
		local targetLevel = split(target)
		if targetLevel > shownLevel + 1 then
			-- Several levels at once (a dev jump): snap and celebrate the arrival once.
			local from = shownLevel
			shownTotal = target
			shownLevel = targetLevel
			celebrate(from, targetLevel)
		else
			shownTotal = MathUtil.approach(shownTotal, target, U.XpFillResponse, dt)
			local level = split(shownTotal)
			if level > shownLevel then
				celebrate(shownLevel, level)
				shownLevel = level
			end
		end
	end

	local into = shownTotal - totalAt(shownLevel)
	local need = Progression.xpForLevel(shownLevel)
	local share = if shownLevel >= Tuning.Progression.MaxLevel then 1 else math.clamp(into / need, 0, 1)
	local pulse = math.clamp(layers:get("Pulse"), -0.4, 1.6)
	local flash = math.clamp(layers:get("Flash"), 0, 1)
	scale.Scale = math.max(0.5, 1 + (U.XpPulseScale - 1) * pulse)
	fill.Size = UDim2.new(share, 0, 1, 0)
	fill.BackgroundColor3 = GOLD:Lerp(WHITE, flash)
	levelLabel.Text = `LV {shownLevel}`
	nextLabel.Text = if shownLevel >= Tuning.Progression.MaxLevel
		then "MAX"
		else `{withCommas(into)} / {withCommas(need)}`
	levelLabel.TextColor3 = GOLD:Lerp(WHITE, flash)

	-- The banner: slams in, holds, slides up and fades.
	local showing = now < bannerUntil
	banner.Visible = showing
	if showing then
		local pop = math.clamp(layers:get("Banner"), -0.5, 1)
		local left = bannerUntil - now
		local out = math.clamp(1 - left / 0.3, 0, 1) -- the last 0.3 s
		bannerScale.Scale = math.max(0.1, 1 + (U.XpBannerPopScale - 1) * pop) * (1 - 0.3 * out)
		local alpha = 1 - out * out
		for _, label in { bannerTitle, bannerLevel, bannerCircle } do
			label.TextTransparency = 1 - alpha
			label.TextStrokeTransparency = 1 - alpha
		end
		banner.Position = UDim2.new(0.5, 0, 0, U.XpBarTop + U.XpBarHeight + BANNER_GAP - 24 * out)
		bannerLevel.TextColor3 = HOT:Lerp(WHITE, flash)
	end
end

local function label(parent: Instance, size: number, color: Color3, order: number): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Font = FONT
	item.TextSize = size
	item.TextColor3 = color
	item.TextStrokeColor3 = OUTLINE
	item.TextStrokeTransparency = 0
	item.AutomaticSize = Enum.AutomaticSize.XY
	item.Size = UDim2.new()
	item.LayoutOrder = order
	item.Parent = parent
	return item
end

function XpBar.start()
	local U = Tuning.Ui
	local gui = Instance.new("ScreenGui")
	gui.Name = "FallXp"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 46

	frame = Instance.new("Frame")
	frame.BackgroundColor3 = TRACK
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, U.XpBarTop)
	frame.Size = UDim2.fromOffset(U.XpBarWidth, U.XpBarHeight)
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = OUTLINE
	stroke.Thickness = 2
	stroke.Parent = frame
	scale = Instance.new("UIScale")
	scale.Parent = frame

	fill = Instance.new("Frame")
	fill.BackgroundColor3 = GOLD
	fill.BorderSizePixel = 0
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.Parent = frame
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0.5, 0)
	fillCorner.Parent = fill

	levelLabel = label(frame, U.XpLevelSize, GOLD, 1)
	levelLabel.AnchorPoint = Vector2.new(1, 0.5)
	levelLabel.Position = UDim2.new(0, -10, 0.5, 0)
	nextLabel = label(frame, U.XpLevelSize * 0.7, WHITE, 2)
	nextLabel.AnchorPoint = Vector2.new(0, 0.5)
	nextLabel.Position = UDim2.new(1, 10, 0.5, 0)
	nextLabel.TextTransparency = 0.25

	banner = Instance.new("Frame")
	banner.BackgroundTransparency = 1
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, U.XpBarTop + U.XpBarHeight + BANNER_GAP)
	banner.Size = UDim2.fromOffset(400, U.XpBannerSize * 2 + 30)
	banner.Visible = false
	banner.Parent = gui
	bannerScale = Instance.new("UIScale")
	bannerScale.Parent = banner
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = banner
	bannerTitle = label(banner, U.XpBannerSize * 0.5, GOLD, 1)
	bannerTitle.Text = "LEVEL UP"
	bannerLevel = label(banner, U.XpBannerSize, HOT, 2)
	bannerLevel.Text = "LV 2"
	bannerCircle = label(banner, U.XpBannerSize * 0.45, WHITE, 3)
	bannerCircle.Text = "NEW CIRCLE UNLOCKED"
	bannerCircle.Visible = false

	-- Studio test aids beside the bar: RESET to level 1, MAX to the top (the server honours DevLevel in Studio).
	if RunService:IsStudio() then
		local function devButton(text: string, offset: number, target: () -> number)
			local button = Instance.new("TextButton")
			button.Font = FONT
			button.Text = text
			button.TextSize = U.XpLevelSize * 0.6
			button.TextColor3 = WHITE
			button.BackgroundColor3 = TRACK
			button.BackgroundTransparency = 0.2
			button.BorderSizePixel = 0
			button.AnchorPoint = Vector2.new(0, 0.5)
			button.Position = UDim2.new(1, offset, 0.5, 0)
			button.Size = UDim2.fromOffset(U.XpDevButton, U.XpBarHeight + 12)
			button.Parent = frame
			local buttonCorner = Instance.new("UICorner")
			buttonCorner.CornerRadius = UDim.new(0, 6)
			buttonCorner.Parent = button
			button.Activated:Connect(function()
				Net.event("DevLevel"):FireServer(target() - Progression.levelOf(Players.LocalPlayer))
			end)
		end
		local gap = 150
		devButton("RESET", gap, function()
			return 1
		end)
		devButton("MAX", gap + U.XpDevButton + 6, function()
			return Tuning.Progression.MaxLevel
		end)
	end

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	RunService.RenderStepped:Connect(update)
end

return XpBar
