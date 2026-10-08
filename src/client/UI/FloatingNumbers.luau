--!strict
-- Floating cash numbers (spec §4.8): each object the local player breaks spawns a small rising number at its
-- position in muted gold. Pooled BillboardGuis (Tuning.Ui.FloatPool); past the pool the oldest is reused.

local RunService = game:GetService("RunService")

local Tuning = require(game:GetService("ReplicatedStorage").Shared.Tuning)

local Destruction = require(script.Parent.Parent.Feel.Destruction)
local MathUtil = require(script.Parent.Parent.Movement.MathUtil)

local FloatingNumbers = {}

-- Look; not gameplay tuning.
local FONT = Enum.Font.GothamBold
local GOLD = Color3.fromRGB(230, 195, 110)
local WHITE_GOLD = Color3.fromRGB(255, 240, 200)
local OUTLINE = Color3.fromRGB(20, 20, 25)
local WIDTH = 160

type Float = { Gui: BillboardGui, Label: TextLabel, Scale: UIScale, Start: number, Origin: Vector3, Up: Vector3 }

local floats: { Float } = {}
local nextFloat = 1

-- Weighted by cash: bigger numbers for bigger payouts, white-gold past FloatBigCash, spread sideways.
local function show(position: Vector3, cash: number)
	local U = Tuning.Ui
	local item = floats[nextFloat]
	nextFloat = nextFloat % #floats + 1
	local up = MathUtil.upAt(position)
	local side = MathUtil.upright(Vector3.zero, Vector3.xAxis, up).RightVector
	item.Start = os.clock()
	item.Origin = position + side * ((math.random() * 2 - 1) * U.FloatSpread)
	item.Up = up
	item.Label.Text = `+${math.floor(cash + 0.5)}`
	local grow = math.clamp(1 + U.FloatSizePerDecade * math.log10(math.max(cash, 5) / 5), 1, U.FloatMaxGrow)
	item.Label.TextSize = U.FloatSize * grow
	item.Label.TextColor3 = if cash >= U.FloatBigCash then WHITE_GOLD else GOLD
	item.Gui.Size = UDim2.fromOffset(WIDTH, (U.FloatSize + 4) * grow)
	item.Gui.StudsOffsetWorldSpace = item.Origin
	item.Gui.Enabled = true
end

local function update()
	local U = Tuning.Ui
	local now = os.clock()
	for _, item in floats do
		if item.Gui.Enabled then
			local p = (now - item.Start) / U.FloatTime
			if p >= 1 then
				item.Gui.Enabled = false
			else
				local rise = 1 - (1 - p) ^ 2
				item.Gui.StudsOffsetWorldSpace = item.Origin + item.Up * (U.FloatRise * rise)
				item.Label.TextTransparency = 1 - U.FloatAlpha * (1 - p * p)
				item.Label.TextStrokeTransparency = item.Label.TextTransparency
				-- Slam in oversized, squash, settle (the Layers slam shape).
				local q = (now - item.Start) / math.max(U.FloatPopTime, 1e-3)
				local pop = if q >= 1 then 0 else math.exp(-5 * q) * math.cos(2 * math.pi * 1.75 * q)
				item.Scale.Scale = math.max(0.2, 1 + (U.FloatPopScale - 1) * pop)
			end
		end
	end
end

function FloatingNumbers.start()
	local U = Tuning.Ui
	for _ = 1, U.FloatPool do
		local gui = Instance.new("BillboardGui")
		gui.AlwaysOnTop = true
		gui.Size = UDim2.fromOffset(WIDTH, U.FloatSize + 4)
		gui.LightInfluence = 0
		gui.Enabled = false
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Font = FONT
		label.TextSize = U.FloatSize
		label.TextColor3 = GOLD
		label.TextStrokeColor3 = OUTLINE
		label.TextStrokeTransparency = 0.3
		label.Size = UDim2.fromScale(1, 1)
		label.Parent = gui
		local scale = Instance.new("UIScale")
		scale.Parent = label
		gui.Parent = workspace.Terrain
		table.insert(floats, {
			Gui = gui,
			Label = label,
			Scale = scale,
			Start = 0,
			Origin = Vector3.zero,
			Up = Vector3.yAxis,
		})
	end
	Destruction.Credited:Connect(function(position, cash, _combo)
		show(position, cash)
	end)
	RunService.RenderStepped:Connect(update)
end

return FloatingNumbers
