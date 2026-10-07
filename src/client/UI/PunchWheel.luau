--!strict
-- Punch charge wheel: a small ring beside the crosshair that fills clockwise while LMB charges and turns gold
-- when full, then fades out on release.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Tuning = require(game:GetService("ReplicatedStorage").Shared.Tuning)
local Controller = require(script.Parent.Parent.Movement.Controller)
local Arc = require(script.Parent.Arc)

local PunchWheel = {}

-- Look of the wheel; not gameplay tuning.
local FILL = Color3.new(1, 1, 1)
local FULL = Color3.fromRGB(240, 200, 90)

local arc: Arc.Arc
local alpha = 0
local shownFill = 0 -- last fill, kept while fading out after release

local function update(dt: number)
	local U = Tuning.Ui
	local ctx = Controller.ctx
	local hold = if ctx then ctx.PunchHold else nil
	local fill = if hold then math.clamp(hold / Tuning.Punch.ChargeTime, 0, 1) else nil
	local fadeStep = dt / U.PunchWheelFade
	alpha = if fill then math.min(1, alpha + fadeStep) else math.max(0, alpha - fadeStep)
	if fill then
		shownFill = fill
	end
	arc:set(shownFill, if shownFill >= 1 then FULL else FILL, alpha, U.PunchWheelTrackTransparency)
end

function PunchWheel.start()
	local U = Tuning.Ui
	local gui = Instance.new("ScreenGui")
	gui.Name = "FallPunchWheel"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false

	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Size = UDim2.fromOffset(U.PunchWheelSize, U.PunchWheelSize)
	holder.Position = UDim2.new(0.5, U.PunchWheelOffset, 0.5, U.PunchWheelOffset)
	holder.Parent = gui
	arc = Arc.new(holder, UDim2.fromScale(1, 1), U.PunchWheelThickness)
	arc:set(0, FILL, 0, U.PunchWheelTrackTransparency)

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	RunService.RenderStepped:Connect(update)
end

return PunchWheel
