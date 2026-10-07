--!strict
-- Punch charge wheel: a small ring beside the crosshair that fills clockwise while LMB charges and turns gold
-- when full, then fades out on release.
-- The arc is two clipped halves of a ring stroke, each masked by a hard-edged UIGradient whose rotation sweeps
-- the visible half-plane: rotation θ shows the arc from 12 o'clock clockwise to θ within that half.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Tuning = require(game:GetService("ReplicatedStorage").Shared.Tuning)
local Controller = require(script.Parent.Parent.Movement.Controller)

local PunchWheel = {}

-- Look of the wheel; not gameplay tuning.
local FILL = Color3.new(1, 1, 1)
local FULL = Color3.fromRGB(240, 200, 90)
local HALF_MASK = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.5, 0),
	NumberSequenceKeypoint.new(0.501, 1),
	NumberSequenceKeypoint.new(1, 1),
})

local container: Frame
local track: UIStroke
local halves: { { Stroke: UIStroke, Mask: UIGradient, Min: number, Max: number } } = {}
local alpha = 0
local shownFill = 0 -- last fill, kept while fading out after release

local function ring(parent: Instance, size: UDim2, position: UDim2): UIStroke
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.Size = size
	frame.Position = position
	frame.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = Tuning.Ui.PunchWheelThickness
	stroke.Color = FILL
	stroke.Parent = frame
	return stroke
end

local function half(min: number, max: number, clipPosition: UDim2, ringPosition: UDim2)
	local clip = Instance.new("Frame")
	clip.BackgroundTransparency = 1
	clip.ClipsDescendants = true
	clip.Size = UDim2.fromScale(0.5, 1)
	clip.Position = clipPosition
	clip.Parent = container
	local stroke = ring(clip, UDim2.fromScale(2, 1), ringPosition)
	local mask = Instance.new("UIGradient")
	mask.Transparency = HALF_MASK
	mask.Parent = stroke
	table.insert(halves, { Stroke = stroke, Mask = mask, Min = min, Max = max })
end

local function update(dt: number)
	local U = Tuning.Ui
	local ctx = Controller.ctx
	local hold = if ctx then ctx.PunchHold else nil
	local fill = if hold then math.clamp(hold / Tuning.Punch.ChargeTime, 0, 1) else nil

	local fadeStep = dt / U.PunchWheelFade
	alpha = if fill then math.min(1, alpha + fadeStep) else math.max(0, alpha - fadeStep)
	container.Visible = alpha > 0
	if not container.Visible then
		return
	end

	if fill then
		shownFill = fill
	end
	local full = shownFill >= 1
	local angle = shownFill * 360
	track.Transparency = 1 - (1 - U.PunchWheelTrackTransparency) * alpha
	for _, part in halves do
		part.Mask.Rotation = math.clamp(angle, part.Min, part.Max)
		part.Stroke.Color = if full then FULL else FILL
		part.Stroke.Transparency = 1 - alpha
	end
end

function PunchWheel.start()
	local U = Tuning.Ui
	local gui = Instance.new("ScreenGui")
	gui.Name = "FallPunchWheel"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false

	container = Instance.new("Frame")
	container.BackgroundTransparency = 1
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.Size = UDim2.fromOffset(U.PunchWheelSize, U.PunchWheelSize)
	container.Position = UDim2.new(0.5, U.PunchWheelOffset, 0.5, U.PunchWheelOffset)
	container.Visible = false
	container.Parent = gui

	track = ring(container, UDim2.fromScale(1, 1), UDim2.new())
	half(0, 180, UDim2.fromScale(0.5, 0), UDim2.fromScale(-1, 0))
	half(180, 360, UDim2.new(), UDim2.new())

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	RunService.RenderStepped:Connect(update)
end

return PunchWheel
