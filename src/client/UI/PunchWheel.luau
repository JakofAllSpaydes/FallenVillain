--!strict
-- Punch charge rings beside the crosshair: one ring per stretch of the hold, ending at each of Punch.Tiers and
-- finally at the longest charge in Punch.HoldBoosts. Fades out on release.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Tuning = require(game:GetService("ReplicatedStorage").Shared.Tuning)
local Controller = require(script.Parent.Parent.Movement.Controller)
local ChargeRings = require(script.Parent.ChargeRings)

local PunchWheel = {}

local rings: ChargeRings.ChargeRings

local function ringEnds(): { number }
	local P = Tuning.Punch
	local ends = table.clone(P.Tiers)
	table.insert(ends, P.HoldBoosts[#P.HoldBoosts][1])
	return ends
end

local function update(dt: number)
	local ctx = Controller.ctx
	local hold = if ctx then ctx.PunchHold else nil
	local ends = ringEnds()
	rings:update(dt, hold, ends, 0, hold ~= nil and hold >= ends[#ends])
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
	rings = ChargeRings.new(holder, #ringEnds())

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	RunService.RenderStepped:Connect(update)
end

return PunchWheel
