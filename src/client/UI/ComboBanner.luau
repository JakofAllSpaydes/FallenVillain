--!strict
-- Combo banner (spec §4.8, §15 milestone 5): arcade style, top centre. "×N" pops in on every credit, the combo's
-- name (Tuning.Ui.ComboNames, by count) sits under it and steps up with a bigger pop, a blink and a chime
-- (FeelTable ComboTier), a thin bar times the Combo.Window, and when the window lapses the held total shows as
-- "+$X" and slides down into the cash readout (ComboEnd). Counts come from the server's credits
-- (Feel/Destruction.Credited); the window is timed here for display only.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Tuning = require(game:GetService("ReplicatedStorage").Shared.Tuning)

local Smash = require(script.Parent.Parent.Combat.Smash)
local Destruction = require(script.Parent.Parent.Feel.Destruction)
local Juice = require(script.Parent.Parent.Feel.Juice)
local Layers = require(script.Parent.Parent.Feel.Layers)
local CashReadout = require(script.Parent.CashReadout)

local ComboBanner = {}

-- Look; not gameplay tuning.
local FONT = Enum.Font.FredokaOne
local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(230, 195, 110)
local HOT = Color3.fromRGB(255, 120, 70)
local OUTLINE = Color3.fromRGB(20, 20, 25)
local BAR_HEIGHT = 4
local NOTES = 8 -- arpeggio length before the pitch resets

local layers = Layers.new({ "Pop", "TierPop", "Flash", "Tilt", "Drop", "NamePop" })
local tiltSign = 1

local frame: Frame
local number: TextLabel
local name: TextLabel
local bar: Frame
local track: Frame
local scale: UIScale
local nameScale: UIScale
local strokes: { UIStroke } = {}

local count = 0
local tier = 0
local endsAt = -math.huge
local pending = 0
local outUntil = -math.huge
local outTotal = 0

local function withCommas(value: number): string
	local text = tostring(math.floor(value + 0.5))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

-- Index into ComboNames for a count (0 = unnamed).
local function tierFor(combo: number): number
	local reached = 0
	for index, entry in Tuning.Ui.ComboNames do
		if combo >= entry[1] then
			reached = index
		end
	end
	return reached
end

local function onCredited(_position: Vector3, cash: number, combo: number, _prefab: string)
	local U = Tuning.Ui
	local now = os.clock()
	-- Credits arrive in wave order, not count order (a "1" can land after a "3"), so only a lapsed window
	-- starts a new combo; otherwise keep the highest count seen.
	local fresh = now >= endsAt
	count = if fresh then combo else math.max(count, combo)
	endsAt = now + Tuning.Combo.Window
	if fresh then
		tier = 0
	end
	if combo < 2 then
		return
	end
	pending += cash
	CashReadout.setPending(pending)
	-- The number slams in from above, oversized, squashes and settles (the slam curve), tilting side to side.
	layers:kick("Pop", 1, U.ComboPop, "slam")
	layers:kick("Drop", 1, U.ComboPop, "expo")
	tiltSign = -tiltSign
	layers:kick("Tilt", tiltSign, U.ComboPop, "slam")
	-- The tick climbs the scale within a tier and an octave per tier (the note index carries both).
	Juice.fire("ComboTick", nil, nil, nil, (combo - 1) % NOTES + NOTES * tier)
	local reached = tierFor(count)
	if reached > tier then
		tier = reached
		layers:kick("TierPop", 1, U.ComboTierPop, "slam")
		layers:kick("Flash", 1, U.ComboTierPop, "expo")
		layers:kick("NamePop", 1, U.ComboNamePop, "slam")
		Juice.fire("ComboTier", nil, nil, nil, reached)
	end
end

local function setAlpha(alpha: number)
	number.TextTransparency = 1 - alpha
	name.TextTransparency = 1 - alpha
	for _, stroke in strokes do
		stroke.Transparency = 1 - alpha
	end
	track.BackgroundTransparency = 1 - 0.6 * alpha
	bar.BackgroundTransparency = 1 - alpha
end

local function update()
	local U = Tuning.Ui
	local now = os.clock()
	local active = count >= 2 and now < endsAt
	if not active and pending > 0 then
		-- Combo over: the total flies into the readout, which pops in proportion; big tiers pay off louder.
		outTotal = pending
		outUntil = now + U.ComboOutTime
		pending = 0
		CashReadout.setPending(0)
		Juice.fire("ComboEnd", nil, nil, nil, tier)
		task.delay(U.ComboOutTime, CashReadout.pop, 1 + U.ComboPayoffPop * math.max(0, math.log10(outTotal / 100)))
	end
	local out = now < outUntil
	frame.Visible = active or out
	if not frame.Visible then
		return
	end
	-- Slam pops swing below zero (the squash), so they are clamped from below only by what reads well.
	local pop = math.clamp(layers:get("Pop"), -0.4, 1)
	local tierPop = math.clamp(layers:get("TierPop"), -0.3, 1)
	local flash = math.clamp(layers:get("Flash"), 0, 1)
	local namePop = math.clamp(layers:get("NamePop"), -0.5, 1)
	local entry = Tuning.Ui.ComboNames[tier]
	name.Text = if entry then entry[2] else ""
	name.TextColor3 = GOLD:Lerp(WHITE, flash)
	-- The name flips in: squashed flat at the pop, overshooting past full, settling.
	nameScale.Scale = math.max(0.05, 1 + 0.6 * namePop)
	number.TextColor3 = WHITE:Lerp(HOT, math.min(tier / #Tuning.Ui.ComboNames, 1)):Lerp(WHITE, flash)
	if active then
		number.Text = `×{count}`
		scale.Scale = math.max(0.2, 1 + (U.ComboPopScale - 1) * pop + (U.ComboTierPopScale - 1) * tierPop)
		frame.Rotation = layers:get("Tilt") * U.ComboTilt
		local remaining = math.clamp((endsAt - now) / Tuning.Combo.Window, 0, 1)
		bar.Size = UDim2.new(remaining, 0, 0, BAR_HEIGHT)
		-- The last second: the bar runs hot and blinks.
		local warn = endsAt - now < U.ComboWarnTime
		bar.BackgroundColor3 = if warn and math.sin(now * 20) > 0 then WHITE else (if warn then HOT else GOLD)
		frame.Position = UDim2.new(0.5, 0, 0, U.ComboTop - U.ComboDrop * math.clamp(layers:get("Drop"), 0, 1))
		setAlpha(1)
	else
		local q = math.clamp(1 - (outUntil - now) / U.ComboOutTime, 0, 1)
		local ease = q * q
		number.Text = `+${withCommas(outTotal)}`
		bar.Size = UDim2.new(0, 0, 0, BAR_HEIGHT)
		frame.Rotation = 0
		scale.Scale = 1 + (U.ComboFlyScale - 1) * ease
		frame.Position = UDim2.new(0.5, 0, 0, U.ComboTop):Lerp(CashReadout.target(), ease)
		setAlpha(1 - ease * ease)
	end
end

local function outlined(label: TextLabel): TextLabel
	local stroke = Instance.new("UIStroke")
	stroke.Color = OUTLINE
	stroke.Thickness = 3
	stroke.Parent = label
	table.insert(strokes, stroke)
	return label
end

function ComboBanner.start()
	local U = Tuning.Ui
	local gui = Instance.new("ScreenGui")
	gui.Name = "FallCombo"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 45

	frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, U.ComboTop)
	frame.Size = UDim2.fromOffset(U.ComboBarWidth * 2, U.ComboNumberSize + U.ComboNameSize + BAR_HEIGHT + 12)
	frame.Visible = false
	frame.Parent = gui
	scale = Instance.new("UIScale")
	scale.Parent = frame

	number = Instance.new("TextLabel")
	number.BackgroundTransparency = 1
	number.Font = FONT
	number.TextSize = U.ComboNumberSize
	number.TextColor3 = WHITE
	number.Size = UDim2.new(1, 0, 0, U.ComboNumberSize)
	number.Parent = frame
	outlined(number)

	name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Font = FONT
	name.TextSize = U.ComboNameSize
	name.TextColor3 = GOLD
	name.Position = UDim2.new(0, 0, 0, U.ComboNumberSize - 4)
	name.Size = UDim2.new(1, 0, 0, U.ComboNameSize)
	name.Parent = frame
	outlined(name)
	nameScale = Instance.new("UIScale")
	nameScale.Parent = name

	track = Instance.new("Frame")
	track.BackgroundColor3 = OUTLINE
	track.BackgroundTransparency = 0.4
	track.BorderSizePixel = 0
	track.AnchorPoint = Vector2.new(0.5, 0)
	track.Position = UDim2.new(0.5, 0, 0, U.ComboNumberSize + U.ComboNameSize + 4)
	track.Size = UDim2.new(0, U.ComboBarWidth, 0, BAR_HEIGHT)
	track.Parent = frame
	bar = Instance.new("Frame")
	bar.BackgroundColor3 = GOLD
	bar.BorderSizePixel = 0
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.fromScale(0.5, 0)
	bar.Size = UDim2.new(1, 0, 0, BAR_HEIGHT)
	bar.Parent = track

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	Destruction.Credited:Connect(onCredited)
	-- Movement tech and charging refill the window while a combo runs (the bar visibly refills).
	Smash.ComboExtended:Connect(function(extra)
		local now = os.clock()
		if count >= 2 and now < endsAt then
			endsAt = now + Tuning.Combo.Window + extra
		end
	end)
	RunService.RenderStepped:Connect(update)
end

return ComboBanner
