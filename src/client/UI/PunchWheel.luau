--!strict
-- Punch charge rings beside the crosshair: one ring per punch circle (shared/Progression.luau), ending at each
-- of Punch.Tiers and finally at the longest charge in Punch.HoldBoosts. Locked circles show dim. Fades out on
-- release.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Progression = require(Shared.Progression)
local Tuning = require(Shared.Tuning)

local Controller = require(script.Parent.Parent.Movement.Controller)
local ChargeRings = require(script.Parent.ChargeRings)

local PunchWheel = {}

local rings: ChargeRings.ChargeRings

local function update(dt: number)
	local ctx = Controller.ctx
	local hold = if ctx then ctx.PunchHold else nil
	local level = if ctx then ctx.Level else 1
	local ends = Progression.circleEnds("Punch")
	local maxed = hold ~= nil and hold >= Progression.holdCap("Punch", level)
	rings:update(dt, hold, ends, Tuning.Ui.WheelShowAfter, maxed, Progression.circles(level))
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
	rings = ChargeRings.new(holder, #Progression.circleEnds("Punch"), "Punch")

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	RunService.RenderStepped:Connect(update)
end

return PunchWheel
