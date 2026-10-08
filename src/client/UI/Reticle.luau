--!strict
-- Aim reticle (spec §4.6): a dot at screen centre where the aim ray goes. Over or near a destructible the
-- magnet shows: a ring grows around the dot (sized by how strongly the aim is pulled) and both warm toward the
-- preview's hot colour, so you can see the aim settle on a target before you commit to the dive.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Tuning = require(game:GetService("ReplicatedStorage").Shared.Tuning)

local Controller = require(script.Parent.Parent.Movement.Controller)
local MathUtil = require(script.Parent.Parent.Movement.MathUtil)

local Reticle = {}

-- Placeholder art sizes, not gameplay tuning.
local DOT_SIZE = 6
local DOT_TRANSPARENCY = 0.2
local RING_THICKNESS = 2
local WHITE = Color3.new(1, 1, 1)

local gui: ScreenGui? = nil
local dot: Frame
local ring: Frame
local ringStroke: UIStroke
local magnet = 0

local function update(dt: number)
	local ctx = Controller.ctx
	local target = if ctx then ctx.AimMagnet else 0
	magnet = MathUtil.approach(magnet, target, Tuning.Preview.ReticleResponse, dt)
	local size = DOT_SIZE + (Tuning.Preview.ReticleRing - DOT_SIZE) * magnet
	ring.Size = UDim2.fromOffset(size, size)
	ringStroke.Transparency = 1 - 0.85 * magnet
	local color = WHITE:Lerp(Tuning.Preview.HotColor, magnet)
	ringStroke.Color = color
	dot.BackgroundColor3 = color
end

function Reticle.start()
	local screen = Instance.new("ScreenGui")
	screen.Name = "FallReticle"
	screen.IgnoreGuiInset = true
	screen.ResetOnSpawn = false

	dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(DOT_SIZE, DOT_SIZE)
	dot.BackgroundColor3 = WHITE
	dot.BackgroundTransparency = DOT_TRANSPARENCY
	dot.BorderSizePixel = 0
	dot.Parent = screen
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = dot
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Transparency = 0.5
	stroke.Parent = dot

	ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromOffset(DOT_SIZE, DOT_SIZE)
	ring.BackgroundTransparency = 1
	ring.BorderSizePixel = 0
	ring.Parent = screen
	local ringCorner = Instance.new("UICorner")
	ringCorner.CornerRadius = UDim.new(0.5, 0)
	ringCorner.Parent = ring
	ringStroke = Instance.new("UIStroke")
	ringStroke.Thickness = RING_THICKNESS
	ringStroke.Transparency = 1
	ringStroke.Parent = ring

	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = screen
	RunService.RenderStepped:Connect(update)
end

function Reticle.setVisible(visible: boolean)
	if gui then
		gui.Enabled = visible
	end
end

return Reticle
