--!strict
-- Tester HUD: a mobile-game style controls and tricks list (keycap chips + one or two words), shown in every
-- build while Tuning.Dev.ShowControlsHud is on (until milestone 7's onboarding hints replace it), plus a
-- Studio-only live readout of state, speed, height and glide energy. F3 toggles.
--
-- KEEP THIS CURRENT: every new input, mechanic or trick gets a row in SECTIONS in the same change.
-- Rows are a key (or action) chip sequence and a label of at most two words.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Tuning = require(game:GetService("ReplicatedStorage").Shared.Tuning)

local Controller = require(script.Parent.Parent.Movement.Controller)

local ControlsHud = {}

type Row = { Keys: { string }, Label: string }
type Section = { Title: string?, Rows: { Row } }

-- Compact (review note at milestone 6: 40% smaller, no move/look rows, tap and hold combined per button).
local SECTIONS: { Section } = {
	{
		Title = "CONTROLS",
		Rows = {
			{ Keys = { "TAP / HOLD", "SPACE" }, Label = "Hop / Burst" },
			{ Keys = { "AIR", "SPACE" }, Label = "Dive / Swoop" },
			{ Keys = { "TAP / HOLD", "LMB" }, Label = "Punch / Charge" },
			{ Keys = { "TAP / HOLD", "RMB" }, Label = "Blast / Charge" },
		},
	},
	{
		Title = "TRICKS",
		Rows = {
			{ Keys = { "DIVE", "LAND" }, Label = "Slide" },
			{ Keys = { "LMB", "AT GROUND" }, Label = "Rocket jump" },
		},
	},
}

-- On touch devices the keycaps become the touch layout's controls (Movement/TouchControls.luau); runs of the
-- same chip collapse, so W A S D reads as one STICK chip.
local TOUCH_KEYS: { [string]: string } = {
	W = "STICK",
	A = "STICK",
	S = "STICK",
	D = "STICK",
	MOUSE = "DRAG",
	SPACE = "JUMP",
	LMB = "PUNCH",
	RMB = "BLAST",
}

local function touchKeys(keys: { string }): { string }
	local mapped = {}
	for _, key in keys do
		local value = TOUCH_KEYS[key] or key
		if mapped[#mapped] ~= value then
			table.insert(mapped, value)
		end
	end
	return mapped
end

-- Chips that describe an action or timing rather than a physical key get the accent style.
local ACTION_CHIPS = {
	HOLD = true,
	TAP = true,
	["TAP / HOLD"] = true,
	AIR = true,
	GROUND = true,
	SWOOP = true,
	["AT GROUND"] = true,
	["LET GO"] = true,
	LAND = true,
	DIVE = true,
	FLAT = true,
	LOW = true,
	["AT STUFF"] = true,
	FLY = true,
	INTO = true,
}

-- Look and layout of a test tool; not gameplay tuning. Sizes are at 1080p and scale with the screen.
local FONT = Enum.Font.FredokaOne
local LABEL_SIZE = 26
local CHIP_SIZE = 20
local TITLE_SIZE = 18
local LIVE_SIZE = 18
local CHIP_HEIGHT = 34
local ROW_GAP = 6
local REFERENCE_HEIGHT = 1080
local HUD_SCALE = 0.75 -- review notes at milestone 6: 40% smaller, then 25% back up
local MIN_SCALE, MAX_SCALE = 0.6 * HUD_SCALE, 1.25 * HUD_SCALE
local REFRESH_INTERVAL = 0.1
local KEY_COLOR = Color3.fromRGB(245, 245, 245)
local KEY_TEXT = Color3.fromRGB(30, 30, 35)
local ACTION_COLOR = Color3.fromRGB(255, 196, 60)
local ACTION_TEXT = Color3.fromRGB(60, 35, 0)
local TITLE_COLOR = Color3.fromRGB(255, 220, 120)
local OUTLINE = Color3.fromRGB(20, 20, 25)

local function outlined(label: TextLabel, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.Color = OUTLINE
	stroke.Thickness = thickness
	stroke.Parent = label
end

local function text(parent: Instance, value: string, size: number, order: number): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = FONT
	label.Text = value
	label.TextSize = size
	label.TextColor3 = Color3.new(1, 1, 1)
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Size = UDim2.new()
	label.LayoutOrder = order
	label.Parent = parent
	outlined(label, 2)
	return label
end

-- A TextLabel, or a TextButton when the chip is tappable (touch footer); both share every property used here.
local function chip(parent: Instance, value: string, order: number, tappable: boolean?): GuiObject
	local action = ACTION_CHIPS[value] == true
	local label: TextLabel = if tappable then Instance.new("TextButton") :: any else Instance.new("TextLabel")
	if label:IsA("TextButton") then
		label.AutoButtonColor = false
	end
	label.Font = FONT
	label.Text = value
	label.TextSize = CHIP_SIZE
	label.TextColor3 = if action then ACTION_TEXT else KEY_TEXT
	label.BackgroundColor3 = if action then ACTION_COLOR else KEY_COLOR
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromOffset(CHIP_HEIGHT, CHIP_HEIGHT)
	label.LayoutOrder = order
	label.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, if action then CHIP_HEIGHT / 2 else 8)
	corner.Parent = label
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 9)
	padding.PaddingRight = UDim.new(0, 9)
	padding.Parent = label
	local border = Instance.new("UIStroke")
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Color = OUTLINE
	border.Thickness = 2
	border.Parent = label
	return label
end

local function horizontal(parent: Instance, gap: number, order: number): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.AutomaticSize = Enum.AutomaticSize.XY
	frame.Size = UDim2.new()
	frame.LayoutOrder = order
	frame.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, gap)
	layout.Parent = frame
	return frame
end

local function row(parent: Instance, data: Row, order: number, touch: boolean)
	local line = horizontal(parent, 10, order)
	local keys = horizontal(line, 4, 1)
	local shown: { string } = if touch then touchKeys(data.Keys) else data.Keys
	for index, key in shown do
		chip(keys, key, index)
	end
	text(line, data.Label, LABEL_SIZE, 2)
end

function ControlsHud.start()
	if not Tuning.Dev.ShowControlsHud then
		return
	end
	local studio = RunService:IsStudio()
	local touch = UserInputService.TouchEnabled

	local gui = Instance.new("ScreenGui")
	gui.Name = "FallControlsHud"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50

	local scale = Instance.new("UIScale")
	scale.Parent = gui
	local function rescale()
		local height = workspace.CurrentCamera.ViewportSize.Y
		scale.Scale = math.clamp(height / REFERENCE_HEIGHT * HUD_SCALE, MIN_SCALE, MAX_SCALE)
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	rescale()

	-- Bottom-left on desktop; top-left on touch (under the cash readout), clear of the thumbstick zone.
	local column = Instance.new("Frame")
	column.BackgroundTransparency = 1
	column.AnchorPoint = if touch then Vector2.new(0, 0) else Vector2.new(0, 1)
	column.Position = if touch then UDim2.new(0, 16, 0, 52) else UDim2.new(0, 16, 1, -16)
	column.AutomaticSize = Enum.AutomaticSize.XY
	column.Size = UDim2.new()
	column.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, ROW_GAP)
	layout.Parent = column

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	local live = text(column, "", LIVE_SIZE, nextOrder())
	live.TextColor3 = TITLE_COLOR
	live.Visible = studio

	for _, section in SECTIONS do
		if section.Title then
			local title = text(column, section.Title, TITLE_SIZE, nextOrder())
			title.TextColor3 = TITLE_COLOR
		end
		for _, data in section.Rows do
			row(column, data, nextOrder(), touch)
		end
	end
	local footer = horizontal(column, 10, nextOrder())
	if studio then
		row(footer, { Keys = { "F2" }, Label = "Tuning" }, 1, false)
		row(footer, { Keys = { "F4" }, Label = "Test smash" }, 3, false)
	end
	if touch then
		-- No keyboard: a tappable HIDE chip folds the sheet down to a HELP chip in the same corner.
		local help = chip(gui, "HELP", 1, true)
		help.Position = column.Position
		help.Visible = false
		local hide = chip(footer, "HIDE", 2, true)
		local function fold(hidden: boolean)
			column.Visible = not hidden
			help.Visible = hidden
		end
		if hide:IsA("GuiButton") then
			hide.Activated:Connect(function()
				fold(true)
			end)
		end
		if help:IsA("GuiButton") then
			help.Activated:Connect(function()
				fold(false)
			end)
		end
	else
		row(footer, { Keys = { "F3" }, Label = "Hide" }, 2, false)
	end

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.F3 and not UserInputService:GetFocusedTextBox() then
			gui.Enabled = not gui.Enabled
		end
	end)

	if not studio then
		return
	end
	task.spawn(function()
		while true do
			local ctx = Controller.ctx
			if gui.Enabled and ctx then
				local v = ctx.Root.AssemblyLinearVelocity
				live.Text = string.format(
					"%s  ·  speed %d  ·  height %d  ·  energy %d",
					ctx.State,
					math.floor(v.Magnitude),
					math.floor(ctx.Altitude),
					math.floor(ctx.GlideEnergy)
				)
			end
			task.wait(REFRESH_INTERVAL)
		end
	end)
end

return ControlsHud
