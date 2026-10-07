--!strict
-- Punch charge rings beside the crosshair. The inner ring fills over Punch.ChargeTime (a full basic punch);
-- past that the outer ring fills toward the longest charge in Punch.HoldBoosts, stepping colour at each of
-- Punch.Tiers. Both fade out on release.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Tuning = require(game:GetService("ReplicatedStorage").Shared.Tuning)
local Controller = require(script.Parent.Parent.Movement.Controller)
local MathUtil = require(script.Parent.Parent.Movement.MathUtil)
local Punch = require(script.Parent.Parent.Movement.Punch)
local ChargeRings = require(script.Parent.ChargeRings)

local PunchWheel = {}

local rings: ChargeRings.ChargeRings

local function update(dt: number)
	local P = Tuning.Punch
	local ctx = Controller.ctx
	local hold = if ctx then ctx.PunchHold else nil
	local inner, outer = nil, nil
	if hold then
		inner = math.clamp(hold / P.ChargeTime, 0, 1)
		if hold >= P.ChargeTime then
			local base = Punch.boostFor(P.ChargeTime)
			local top = P.HoldBoosts[#P.HoldBoosts][2]
			outer = (Punch.boostFor(hold) - base) / math.max(top - base, 1e-3)
		end
	end
	rings:update(dt, inner, outer, MathUtil.tier(P.Tiers, hold or 0))
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
	rings = ChargeRings.new(holder)

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	RunService.RenderStepped:Connect(update)
end

return PunchWheel
