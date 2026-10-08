--!strict
-- Jump charge rings above the character's head: the first ring is the hop charge (full at Hop.HoldTime, where
-- Charging starts), then one ring per Burst circle (shared/Progression.luau), ending at each of Burst.Tiers and
-- finally at the longest hold in Burst.HoldHeights. Circles the level hasn't unlocked show as dim locked
-- rings; everything turns gold once the hold has reached the last unlocked one. Fades out on release.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Progression = require(Shared.Progression)
local Tuning = require(Shared.Tuning)

local Controller = require(script.Parent.Parent.Movement.Controller)
local JumpCheck = require(script.Parent.Parent.Movement.JumpCheck)
local ChargeRings = require(script.Parent.ChargeRings)

local JumpWheel = {}

local gui: BillboardGui
local rings: ChargeRings.ChargeRings

local function ringEnds(): { number }
	local ends = { Tuning.Hop.HoldTime }
	for _, circleEnd in Progression.circleEnds("Burst") do
		table.insert(ends, circleEnd)
	end
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
	local maxed = held ~= nil and held >= Progression.holdCap("Burst", ctx.Level)
	rings:update(dt, held, ringEnds(), Tuning.Ui.WheelShowAfter, maxed, 1 + Progression.circles(ctx.Level))
end

function JumpWheel.start()
	local U = Tuning.Ui
	gui = Instance.new("BillboardGui")
	gui.Name = "FallJumpWheel"
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Size = UDim2.fromOffset(U.JumpWheelSize, U.JumpWheelSize)
	gui.StudsOffset = Vector3.yAxis * U.JumpWheelHeight -- in the root's frame, so it is above the head anywhere on the globe
	gui.ResetOnSpawn = false
	gui.Enabled = false
	rings = ChargeRings.new(gui, #ringEnds())
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	RunService.RenderStepped:Connect(update)
end

return JumpWheel
