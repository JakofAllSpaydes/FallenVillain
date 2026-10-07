--!strict
-- Placeholder aim reticle: a dot at screen center where the aim ray goes. Milestone 3 adds the magnet
-- brightening and the smash preview (spec §4.6).

local Players = game:GetService("Players")

local Reticle = {}

-- Placeholder art sizes, not gameplay tuning.
local DOT_SIZE = 6
local DOT_TRANSPARENCY = 0.2

local gui: ScreenGui? = nil

function Reticle.start()
	local screen = Instance.new("ScreenGui")
	screen.Name = "FallReticle"
	screen.IgnoreGuiInset = true
	screen.ResetOnSpawn = false

	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(DOT_SIZE, DOT_SIZE)
	dot.BackgroundColor3 = Color3.new(1, 1, 1)
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

	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = screen
end

function Reticle.setVisible(visible: boolean)
	if gui then
		gui.Enabled = visible
	end
end

return Reticle
