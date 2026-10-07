--!strict
-- Tester HUD: a controls and movement-tech cheat sheet, shown in every build while Tuning.Dev.ShowControlsHud
-- is on (until milestone 7's onboarding hints replace it), plus a Studio-only live readout of state, speed,
-- height and glide energy. F3 toggles. Numbers come from Tuning so the sheet stays true while tuning.
--
-- KEEP THIS CURRENT: every new input, mechanic or tech gets a row in SECTIONS in the same change.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Tuning = require(game:GetService("ReplicatedStorage").Shared.Tuning)

local Controller = require(script.Parent.Parent.Movement.Controller)

local ControlsHud = {}

-- Layout and refresh rate for a test tool; not gameplay tuning.
local WIDTH = 440
local TEXT_SIZE = 14
local LABEL_WIDTH = 13
local REFRESH_INTERVAL = 0.1

local function percent(fraction: number): string
	return `{math.floor(fraction * 100 + 0.5)}%`
end

type Row = { string } -- { label, description }; a function lets the text read live Tuning values
type Section = { Title: string, Rows: () -> { Row } }

local SECTIONS: { Section } = {
	{
		Title = "CONTROLS",
		Rows = function()
			return {
				{ "Mouse", "look; glide turns toward where you look" },
				{ "WASD", "walk  ·  glide: W/S pitch, A/D turn" },
				{ "Space", "hop (hold = higher)  ·  in glide: flap" },
				{ "Hold LMB", "dive at the crosshair  ·  on ground: smash" },
				{ "Release LMB", "fast dive → swoop pull-up" },
			}
		end,
	},
	{
		Title = "TECH",
		Rows = function()
			local T = Tuning.Tech
			return {
				{ "Bunny hop", `hop within {Tuning.Hop.ChainWindow}s of landing: +{percent(T.PerfectHopBonus)} speed` },
				{ "Dive-slide", `dive into ground under {T.SlideMaxAngle}° at {T.SlideMinSpeed}+ speed` },
				{ "", "→ slide; hop out to keep the speed" },
				{ "Tap boost", `in glide, tap LMB (under {T.TapWindow}s): +{T.TapBoost} speed` },
				{ "Swoop skim", `pull-up within {T.SkimHeight} studs of ground: +{percent(T.SkimBoost)}` },
				{ "Chain", "dive → skim → slide → hop → tap → dive" },
			}
		end,
	},
}

local function pad(text: string): string
	return text .. string.rep(" ", math.max(1, LABEL_WIDTH - utf8.len(text) :: number))
end

local function sheet(): string
	local lines = {}
	for index, section in SECTIONS do
		if index > 1 then
			table.insert(lines, "")
		end
		table.insert(lines, `<b>{section.Title}</b>`)
		for _, row in section.Rows() do
			table.insert(lines, pad(row[1]) .. row[2])
		end
	end
	table.insert(lines, "")
	table.insert(lines, if RunService:IsStudio() then "F2 tuning panel  ·  F3 hide this" else "F3 hide this")
	return table.concat(lines, "\n")
end

function ControlsHud.start()
	if not Tuning.Dev.ShowControlsHud then
		return
	end
	local studio = RunService:IsStudio()

	local gui = Instance.new("ScreenGui")
	gui.Name = "FallControlsHud"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50

	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Color3.new(0, 0, 0)
	frame.BackgroundTransparency = 0.45
	frame.BorderSizePixel = 0
	frame.AnchorPoint = Vector2.new(0, 1)
	frame.Position = UDim2.new(0, 8, 1, -8)
	frame.Size = UDim2.fromOffset(WIDTH, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.Parent = gui

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = frame

	local function textLabel(order: number): TextLabel
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.Code
		label.TextSize = TEXT_SIZE
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.RichText = true
		label.Size = UDim2.fromScale(1, 0)
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.LayoutOrder = order
		label.Parent = frame
		return label
	end

	local live = textLabel(1)
	live.TextColor3 = Color3.fromRGB(255, 220, 120)
	live.Visible = studio
	local help = textLabel(2)
	help.Text = sheet()

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.F3 and not UserInputService:GetFocusedTextBox() then
			gui.Enabled = not gui.Enabled
		end
	end)

	if not studio then
		return -- Tuning can't change outside Studio, so the sheet is static there
	end
	task.spawn(function()
		while true do
			if gui.Enabled then
				local ctx = Controller.ctx
				if ctx then
					local v = ctx.Root.AssemblyLinearVelocity
					local flat = Vector3.new(v.X, 0, v.Z).Magnitude
					live.Text = string.format(
						"%-8s speed %3d  (flat %3d)  height %4d  energy %3d",
						ctx.State,
						math.floor(v.Magnitude),
						math.floor(flat),
						math.floor(ctx.Altitude),
						math.floor(ctx.GlideEnergy)
					)
				end
				help.Text = sheet()
			end
			task.wait(REFRESH_INTERVAL)
		end
	end)
end

return ControlsHud
