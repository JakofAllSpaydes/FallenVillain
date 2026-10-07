--!strict
-- Jump charge rings above the character's head: the first ring is the hop charge (full at Hop.HoldTime, where
-- Charging starts), then one ring per Burst tier, ending at each of Burst.Tiers and finally at the longest hold
-- in Burst.HoldHeights. All gold once the Burst has reached your Power's ceiling. Fades out on release.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Tuning = require(game:GetService("ReplicatedStorage").Shared.Tuning)
local Controller = require(script.Parent.Parent.Movement.Controller)
local JumpCheck = require(script.Parent.Parent.Movement.JumpCheck)
local Burst = require(script.Parent.Parent.Movement.States.Burst)
local ChargeRings = require(script.Parent.ChargeRings)

local JumpWheel = {}

local gui: BillboardGui
local rings: ChargeRings.ChargeRings

local function ringEnds(): { number }
	local B = Tuning.Burst
	local ends = { Tuning.Hop.HoldTime }
	for _, tier in B.Tiers do
		table.insert(ends, tier)
	end
	table.insert(ends, B.HoldHeights[#B.HoldHeights][1])
	return ends
end

local function update(dt: number)
	local ctx = Controller.ctx
	if not ctx then
		gui.Enabled = false
		return
	end
	if gui.Adornee ~= ctx.Root then
		gui.Adornee = ctx.Root
	end
	gui.Enabled = true

	local held = JumpCheck.held()
	local maxed = held ~= nil and Burst.heightForHold(held) >= Burst.ceiling(ctx.Power)
	rings:update(dt, held, ringEnds(), Tuning.Hop.TapTime, maxed)
end

function JumpWheel.start()
	local U = Tuning.Ui
	gui = Instance.new("BillboardGui")
	gui.Name = "FallJumpWheel"
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Size = UDim2.fromOffset(U.JumpWheelSize, U.JumpWheelSize)
	gui.StudsOffset = Vector3.yAxis * U.JumpWheelHeight
	gui.ResetOnSpawn = false
	gui.Enabled = false
	rings = ChargeRings.new(gui, #ringEnds())
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	RunService.RenderStepped:Connect(update)
end

return JumpWheel
