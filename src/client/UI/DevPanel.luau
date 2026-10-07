--!strict
-- Studio-only tuning panel (spec §9, §14). F2 toggles. Every number in Tuning gets a slider and a text box that
-- write straight into the shared Tuning table, so changes apply on the next frame. "Print changes" dumps the
-- edited values to Output for pasting back into Tuning.luau.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Tuning = require(game:GetService("ReplicatedStorage").Shared.Tuning)

local DevPanel = {}

export type Action = { Label: string, Run: () -> () }
export type Options = { Actions: { Action }, OnToggle: (open: boolean) -> () }

-- Layout constants for a debug-only tool; not gameplay tuning.
local WIDTH = 380
local ROW_HEIGHT = 22
local NAME_WIDTH = 170
local BOX_WIDTH = 64
local TEXT_SIZE = 13
local SLIDER_RANGE_FACTOR = 3
local SKIPPED_SECTIONS = { Dev = true }

type Entry = {
	Path: string,
	Parent: { [string]: any },
	Key: string,
	Default: number,
	Min: number,
	Max: number,
	Refresh: (() -> ())?,
}

local function collect(node: { [string]: any }, prefix: string, out: { Entry })
	local keys = {}
	for key in node do
		table.insert(keys, key)
	end
	table.sort(keys)
	for _, key in keys do
		local value = node[key]
		local path = if prefix == "" then key else `{prefix}.{key}`
		if type(value) == "table" then
			if not SKIPPED_SECTIONS[path] then
				collect(value, path, out)
			end
		elseif type(value) == "number" then
			local low, high = 0, 1
			if value > 0 then
				high = value * SLIDER_RANGE_FACTOR
			elseif value < 0 then
				low = value * SLIDER_RANGE_FACTOR
				high = 0
			end
			table.insert(out, { Path = path, Parent = node, Key = key, Default = value, Min = low, Max = high })
		end
	end
end

local function format(value: number): string
	return string.format("%.4g", value)
end

local function label(parent: Instance, text: string, size: UDim2, position: UDim2): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Text = text
	item.TextColor3 = Color3.new(1, 1, 1)
	item.TextSize = TEXT_SIZE
	item.Font = Enum.Font.Code
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.TextTruncate = Enum.TextTruncate.AtEnd
	item.Size = size
	item.Position = position
	item.Parent = parent
	return item
end

local function button(parent: Instance, text: string, onClick: () -> ()): TextButton
	local item = Instance.new("TextButton")
	item.AutomaticSize = Enum.AutomaticSize.X
	item.Size = UDim2.fromOffset(0, ROW_HEIGHT)
	item.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	item.TextColor3 = Color3.new(1, 1, 1)
	item.TextSize = TEXT_SIZE
	item.Font = Enum.Font.Code
	item.Text = ` {text} `
	item.Parent = parent
	item.Activated:Connect(onClick)
	return item
end

local function buildRow(list: Instance, entry: Entry, order: number)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	row.LayoutOrder = order
	row.Parent = list

	local name = label(row, entry.Path, UDim2.fromOffset(NAME_WIDTH, ROW_HEIGHT), UDim2.new())

	local bar = Instance.new("Frame")
	bar.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	bar.BorderSizePixel = 0
	bar.Position = UDim2.new(0, NAME_WIDTH + 4, 0.5, -4)
	bar.Size = UDim2.new(1, -(NAME_WIDTH + BOX_WIDTH + 12), 0, 8)
	bar.Active = true
	bar.Parent = row

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
	fill.BorderSizePixel = 0
	fill.Parent = bar

	local box = Instance.new("TextBox")
	box.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	box.TextColor3 = Color3.new(1, 1, 1)
	box.TextSize = TEXT_SIZE
	box.Font = Enum.Font.Code
	box.ClearTextOnFocus = false
	box.Size = UDim2.fromOffset(BOX_WIDTH, ROW_HEIGHT - 2)
	box.Position = UDim2.new(1, -BOX_WIDTH, 0, 1)
	box.Parent = row

	local function refresh()
		local value = entry.Parent[entry.Key]
		local alpha = math.clamp((value - entry.Min) / (entry.Max - entry.Min), 0, 1)
		fill.Size = UDim2.fromScale(alpha, 1)
		box.Text = format(value)
		name.TextColor3 = if value == entry.Default then Color3.new(1, 1, 1) else Color3.fromRGB(255, 200, 90)
	end
	entry.Refresh = refresh

	local function setFromX(x: number)
		local alpha = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
		entry.Parent[entry.Key] = entry.Min + (entry.Max - entry.Min) * alpha
		refresh()
	end

	local dragging = false
	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)
	box.FocusLost:Connect(function()
		local value = tonumber(box.Text)
		if value then
			entry.Parent[entry.Key] = value
		end
		refresh()
	end)
	refresh()
end

function DevPanel.start(options: Options)
	if not RunService:IsStudio() then
		return
	end

	local entries: { Entry } = {}
	collect(Tuning :: any, "", entries)

	local gui = Instance.new("ScreenGui")
	gui.Name = "FallDevPanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100
	gui.Enabled = false

	local panel = Instance.new("Frame")
	panel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	panel.BackgroundTransparency = 0.15
	panel.BorderSizePixel = 0
	panel.Active = true -- swallow clicks so they don't dive
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -8, 0, 8)
	panel.Size = UDim2.new(0, WIDTH, 1, -16)
	panel.Parent = gui

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.Parent = panel

	local toolbar = Instance.new("Frame")
	toolbar.BackgroundTransparency = 1
	toolbar.AutomaticSize = Enum.AutomaticSize.Y
	toolbar.Size = UDim2.fromScale(1, 0)
	toolbar.Parent = panel
	local toolbarLayout = Instance.new("UIListLayout")
	toolbarLayout.FillDirection = Enum.FillDirection.Horizontal
	toolbarLayout.Wraps = true
	toolbarLayout.Padding = UDim.new(0, 4)
	toolbarLayout.Parent = toolbar

	button(toolbar, "Print changes", function()
		local lines = {}
		for _, entry in entries do
			local value = entry.Parent[entry.Key]
			if value ~= entry.Default then
				table.insert(lines, `Tuning.{entry.Path} = {format(value)}  -- was {format(entry.Default)}`)
			end
		end
		print(if #lines > 0 then "[FALL] Tuning changes:\n" .. table.concat(lines, "\n") else "[FALL] No changes")
	end)
	button(toolbar, "Reset all", function()
		for _, entry in entries do
			entry.Parent[entry.Key] = entry.Default
			if entry.Refresh then
				entry.Refresh()
			end
		end
	end)
	for _, action in options.Actions do
		button(toolbar, action.Label, action.Run)
	end

	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = scroll

	local function fitScroll()
		local top = toolbar.AbsoluteSize.Y + 6
		scroll.Position = UDim2.fromOffset(0, top)
		scroll.Size = UDim2.new(1, 0, 1, -top)
	end
	toolbar:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitScroll)
	fitScroll()

	for index, entry in entries do
		buildRow(scroll, entry, index)
	end

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.F2 and not UserInputService:GetFocusedTextBox() then
			gui.Enabled = not gui.Enabled
			options.OnToggle(gui.Enabled)
		end
	end)
end

return DevPanel
