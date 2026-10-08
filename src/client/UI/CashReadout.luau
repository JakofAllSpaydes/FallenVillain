--!strict
-- Cash readout (spec §4.8, §6): always on, small, top-left, counts up on change. While a combo runs the combo's
-- total is held back (ComboCounter.setPending), so the readout jumps once when the combo ends instead of ticking
-- per object. The number itself is the server's `Cash` attribute on the player.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Tuning = require(game:GetService("ReplicatedStorage").Shared.Tuning)
local Layers = require(script.Parent.Parent.Feel.Layers)
local MathUtil = require(script.Parent.Parent.Movement.MathUtil)

local CashReadout = {}

-- Look; not gameplay tuning.
local FONT = Enum.Font.GothamBold
local GOLD = Color3.fromRGB(230, 195, 110)
local WHITE = Color3.new(1, 1, 1)
local OUTLINE = Color3.fromRGB(20, 20, 25)
local LEFT, TOP = 16, 12

local layers = Layers.new({ "Pop" })
local label: TextLabel
local scale: UIScale
local shown = 0
local pending = 0
local lastTarget = 0

local function withCommas(value: number): string
	local text = tostring(math.floor(value + 0.5))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

-- Cash credited but not yet shown (a running combo).
function CashReadout.setPending(amount: number)
	pending = amount
end

-- An extra pop (1 = the usual), for a combo paying off.
function CashReadout.pop(strength: number)
	layers:kick("Pop", strength, Tuning.Ui.CashPop, "spring")
end

-- Where the readout sits on screen, for things that fly into it.
function CashReadout.target(): UDim2
	return UDim2.new(0, LEFT + label.AbsoluteSize.X / 2, 0, TOP)
end

local function update(dt: number)
	local cash = Players.LocalPlayer:GetAttribute("Cash")
	local target = math.max(0, (if type(cash) == "number" then cash else 0) - pending)
	-- Count up quickly, never down past the target; pop whenever the total climbs.
	if target > lastTarget + 0.5 then
		layers:kick("Pop", 1, Tuning.Ui.CashPop, "spring")
	end
	lastTarget = target
	shown = MathUtil.approach(shown, target, 4 / math.max(Tuning.Ui.CashCountTime, 1e-3), dt)
	label.Text = "$" .. withCommas(shown)
	local pop = math.clamp(layers:get("Pop"), 0, 1)
	scale.Scale = 1 + (Tuning.Ui.CashPopScale - 1) * pop
	label.TextColor3 = GOLD:Lerp(WHITE, pop)
end

function CashReadout.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "FallCash"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 45

	label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = FONT
	label.TextSize = Tuning.Ui.CashSize
	label.TextColor3 = GOLD
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Position = UDim2.fromOffset(LEFT, TOP)
	label.Size = UDim2.new()
	label.Text = "$0"
	label.Parent = gui
	scale = Instance.new("UIScale")
	scale.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Color = OUTLINE
	stroke.Thickness = 2
	stroke.Parent = label

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	RunService.RenderStepped:Connect(update)
end

return CashReadout
