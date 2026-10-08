--!strict
-- Blast charge rings on the crosshair (review note: that is where the blast is going): one ring per blast circle
-- (shared/Progression.luau), ending at each of Blast.Tiers and finally at the longest hold in
-- Blast.HoldStrengths. Locked circles show dim. Fades out on release.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Progression = require(Shared.Progression)
local Tuning = require(Shared.Tuning)

local Controller = require(script.Parent.Parent.Movement.Controller)
local ChargeRings = require(script.Parent.ChargeRings)

local BlastWheel = {}

local rings: ChargeRings.ChargeRings

local function update(dt: number)
	local ctx = Controller.ctx
	local hold = if ctx then ctx.BlastHold else nil
	local level = if ctx then ctx.Level else 1
	local ends = Progression.circleEnds("Blast")
	local maxed = hold ~= nil and hold >= Progression.holdCap("Blast", level)
	rings:update(dt, hold, ends, Tuning.Ui.WheelShowAfter, maxed, Progression.circles(level))
end

function BlastWheel.start()
	local U = Tuning.Ui
	local gui = Instance.new("ScreenGui")
	gui.Name = "FallBlastWheel"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false

	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Size = UDim2.fromOffset(U.PunchWheelSize, U.PunchWheelSize)
	holder.Position = UDim2.fromScale(0.5, 0.5) -- on the crosshair: that is where the blast goes
	holder.Parent = gui
	rings = ChargeRings.new(holder, #Progression.circleEnds("Blast"), "Blast")

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	RunService.RenderStepped:Connect(update)
end

return BlastWheel
