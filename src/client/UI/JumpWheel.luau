--!strict
-- Jump charge rings above the character's head. The inner ring fills with the hop charge while Space is held
-- (full at Hop.HoldTime). Once Charging starts, an outer ring appears around it and fills toward the highest
-- Burst your Power allows. Both fade out on release.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Tuning = require(game:GetService("ReplicatedStorage").Shared.Tuning)
local Controller = require(script.Parent.Parent.Movement.Controller)
local JumpCheck = require(script.Parent.Parent.Movement.JumpCheck)
local Burst = require(script.Parent.Parent.Movement.States.Burst)
local Arc = require(script.Parent.Arc)

local JumpWheel = {}

-- Look of the rings; not gameplay tuning.
local HOP = Color3.new(1, 1, 1)
local BURST = Color3.fromRGB(175, 205, 255)
local FULL = Color3.fromRGB(240, 200, 90)

local gui: BillboardGui
local inner: Arc.Arc
local outer: Arc.Arc
local innerAlpha, outerAlpha = 0, 0
local innerFill, outerFill = 0, 0

local function fade(alpha: number, on: boolean, dt: number): number
	local step = dt / Tuning.Ui.JumpWheelFade
	return if on then math.min(1, alpha + step) else math.max(0, alpha - step)
end

local function update(dt: number)
	local U = Tuning.Ui
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
	local hop = JumpCheck.hopCharge()
	local showInner = hop ~= nil and held ~= nil and held >= Tuning.Hop.TapTime
	if showInner then
		innerFill = hop :: number
	end
	local charging = ctx.State == "Charging" and held ~= nil
	if charging then
		local ceiling = Burst.ceiling(ctx.Power)
		outerFill = math.min(Burst.heightForHold(held :: number), ceiling) / ceiling
	end
	innerAlpha = fade(innerAlpha, showInner, dt)
	outerAlpha = fade(outerAlpha, charging, dt)
	inner:set(innerFill, if innerFill >= 1 then FULL else HOP, innerAlpha, U.JumpWheelTrackTransparency)
	outer:set(outerFill, if outerFill >= 1 then FULL else BURST, outerAlpha, U.JumpWheelTrackTransparency)
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

	outer = Arc.new(gui, UDim2.fromScale(1, 1), U.JumpWheelThickness)
	inner = Arc.new(gui, UDim2.fromScale(U.JumpWheelInnerScale, U.JumpWheelInnerScale), U.JumpWheelThickness)
	inner:set(0, HOP, 0, U.JumpWheelTrackTransparency)
	outer:set(0, BURST, 0, U.JumpWheelTrackTransparency)

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	RunService.RenderStepped:Connect(update)
end

return JumpWheel
