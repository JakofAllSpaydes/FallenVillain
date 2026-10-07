--!strict
-- Jump charge rings above the character's head. The inner ring fills with the hop charge while Space is held
-- (full at Hop.HoldTime). Once Charging starts, the outer ring fills toward the highest Burst your Power
-- allows, stepping colour at each of Burst.Tiers. Both fade out on release.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Tuning = require(game:GetService("ReplicatedStorage").Shared.Tuning)
local Controller = require(script.Parent.Parent.Movement.Controller)
local JumpCheck = require(script.Parent.Parent.Movement.JumpCheck)
local MathUtil = require(script.Parent.Parent.Movement.MathUtil)
local Burst = require(script.Parent.Parent.Movement.States.Burst)
local ChargeRings = require(script.Parent.ChargeRings)

local JumpWheel = {}

local gui: BillboardGui
local rings: ChargeRings.ChargeRings

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
	local inner = if held ~= nil and held >= Tuning.Hop.TapTime then JumpCheck.hopCharge() else nil
	local outer = nil
	if held ~= nil and ctx.State == "Charging" then
		local ceiling = Burst.ceiling(ctx.Power)
		outer = math.min(Burst.heightForHold(held), ceiling) / ceiling
	end
	rings:update(dt, inner, outer, MathUtil.tier(Tuning.Burst.Tiers, held or 0) + 1)
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
	rings = ChargeRings.new(gui)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	RunService.RenderStepped:Connect(update)
end

return JumpWheel
