--!strict
-- Screen post (spec §4, §12): ColorCorrection saturation and contrast, blur, bloom and sun rays, a vignette and
-- a white flash. Each is a layer set by FeelTable entries; Bloom and SunRays add to a base the atmosphere driver
-- sets by altitude. All client-local.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Layers = require(script.Parent.Layers)

local Post = {}

local layers = Layers.new({ "Saturation", "Contrast", "Blur", "Bloom", "SunRays", "Vignette", "Flash" })
local base = { Bloom = 0, SunRays = 0 }

-- Placeholder vignette shape, not a feel value: each edge band covers this share of the screen.
local VIGNETTE_DEPTH = 0.3

local color: ColorCorrectionEffect
local blur: BlurEffect
local bloom: BloomEffect?
local sunRays: SunRaysEffect?
local flash: Frame
local vignette: { UIGradient } = {}
local shownVignette = -1

function Post.apply(entry: { [string]: any }, duration: number)
	layers:apply(entry.post, entry, duration)
end

-- Altitude-driven base for Bloom and SunRays; layers add on top.
function Post.setBase(name: string, value: number)
	base[name] = value
end

local function edge(parent: Instance, rotation: number, size: UDim2, position: UDim2, anchor: Vector2)
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Color3.new(0, 0, 0)
	frame.BorderSizePixel = 0
	frame.Size = size
	frame.Position = position
	frame.AnchorPoint = anchor
	frame.Parent = parent
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = rotation
	gradient.Parent = frame
	table.insert(vignette, gradient)
end

local function setVignette(strength: number)
	if math.abs(strength - shownVignette) < 0.005 then
		return
	end
	shownVignette = strength
	local sequence = NumberSequence.new(1 - math.clamp(strength, 0, 1), 1)
	for _, gradient in vignette do
		gradient.Transparency = sequence
	end
end

local function update()
	color.Saturation = layers:get("Saturation")
	color.Contrast = layers:get("Contrast")
	local blurSize = layers:get("Blur")
	blur.Size = math.max(0, blurSize)
	blur.Enabled = blurSize > 0.05
	if bloom then
		bloom.Intensity = math.max(0, base.Bloom + layers:get("Bloom"))
	end
	if sunRays then
		sunRays.Intensity = math.max(0, base.SunRays + layers:get("SunRays"))
	end
	flash.BackgroundTransparency = 1 - math.clamp(layers:get("Flash"), 0, 1)
	setVignette(layers:get("Vignette"))
end

function Post.start()
	color = Instance.new("ColorCorrectionEffect")
	color.Name = "FallPost"
	color.Parent = Lighting
	blur = Instance.new("BlurEffect")
	blur.Name = "FallBlur"
	blur.Size = 0
	blur.Enabled = false
	blur.Parent = Lighting
	bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	sunRays = Lighting:FindFirstChildOfClass("SunRaysEffect")
	base.Bloom = if bloom then bloom.Intensity else 0
	base.SunRays = if sunRays then sunRays.Intensity else 0

	local gui = Instance.new("ScreenGui")
	gui.Name = "FallPost"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -10

	local d = VIGNETTE_DEPTH
	edge(gui, 0, UDim2.fromScale(d, 1), UDim2.fromScale(0, 0), Vector2.zero)
	edge(gui, 180, UDim2.fromScale(d, 1), UDim2.fromScale(1, 0), Vector2.new(1, 0))
	edge(gui, 90, UDim2.fromScale(1, d), UDim2.fromScale(0, 0), Vector2.zero)
	edge(gui, 270, UDim2.fromScale(1, d), UDim2.fromScale(0, 1), Vector2.new(0, 1))
	setVignette(0)

	flash = Instance.new("Frame")
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Size = UDim2.fromScale(1, 1)
	flash.Parent = gui

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	RunService.RenderStepped:Connect(update)
end

return Post
