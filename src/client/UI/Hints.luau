--!strict
-- Contextual hints (spec §4.1, §8). For now the RELEASE hint: after Ui.ReleaseHintAfter seconds of a Charging
-- hold, "RELEASE" fades in above the jump wheel with a slow pulse, for the first Ui.ReleaseHintBursts Bursts of
-- the session only. Milestone 7's onboarding adds the rest here.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Tuning = require(game:GetService("ReplicatedStorage").Shared.Tuning)

local Controller = require(script.Parent.Parent.Movement.Controller)
local JumpCheck = require(script.Parent.Parent.Movement.JumpCheck)
local MathUtil = require(script.Parent.Parent.Movement.MathUtil)

local Hints = {}

-- Look; not gameplay tuning.
local FONT = Enum.Font.FredokaOne
local COLOR = Color3.fromRGB(255, 196, 60)
local OUTLINE = Color3.fromRGB(20, 20, 25)
local FADE_RATE = 10 -- 1/seconds
local PULSE_HZ = 1.6
local PULSE_SCALE = 0.07

local gui: BillboardGui
local label: TextLabel
local scale: UIScale
local alpha = 0
local bursts = 0

local function update(dt: number)
	local U = Tuning.Ui
	local ctx = Controller.ctx
	local held = JumpCheck.held()
	local show = ctx ~= nil
		and ctx.State == "Charging"
		and held ~= nil
		and held >= U.ReleaseHintAfter
		and bursts < U.ReleaseHintBursts
	alpha = MathUtil.approach(alpha, if show then 1 else 0, FADE_RATE, dt)
	if ctx and gui.Adornee ~= ctx.Root then
		gui.Adornee = ctx.Root
	end
	gui.Enabled = alpha > 0.01
	if gui.Enabled then
		label.TextTransparency = 1 - alpha
		label.TextStrokeTransparency = 1 - alpha
		scale.Scale = 1 + PULSE_SCALE * math.sin(os.clock() * 2 * math.pi * PULSE_HZ)
	end
end

function Hints.start()
	local U = Tuning.Ui
	gui = Instance.new("BillboardGui")
	gui.Name = "FallHints"
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Size = UDim2.fromOffset(200, U.ReleaseHintSize + 8)
	gui.StudsOffset = Vector3.yAxis * U.ReleaseHintHeight
	gui.ResetOnSpawn = false
	gui.Enabled = false
	label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = FONT
	label.Text = "RELEASE"
	label.TextSize = U.ReleaseHintSize
	label.TextColor3 = COLOR
	label.TextStrokeColor3 = OUTLINE
	label.TextStrokeTransparency = 1
	label.TextTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Parent = gui
	scale = Instance.new("UIScale")
	scale.Parent = label
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	Controller.StateChanged:Connect(function(_from, to)
		if to == "Burst" then
			bursts += 1
		end
	end)
	RunService.RenderStepped:Connect(update)
end

return Hints
