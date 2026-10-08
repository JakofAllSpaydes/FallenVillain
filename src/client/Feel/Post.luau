--!strict
-- Screen post (spec §4, §12): ColorCorrection saturation, contrast and warm tint, blur, bloom and sun rays, a
-- radial vignette, a warm "heat" rim at speed, a white flash and a screen-space radial speed-line overlay.
-- Each is a layer set by FeelTable entries (tweens and kicks) or driven per frame by Feel/Drivers. Bloom and
-- SunRays add to a base the atmosphere driver sets by altitude. All client-local.
--
-- The vignette and heat rim are one soft radial texture (Tuning.Vfx.VignetteTexture) tinted black or warm;
-- the speed lines are two copies of a radial streak texture counter-rotating and flickering, the anime
-- speed-line convention, with a clear centre so the crosshair and target stay readable.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Tuning = require(game:GetService("ReplicatedStorage").Shared.Tuning)
local Layers = require(script.Parent.Layers)

local Post = {}

local layers = Layers.new({
	"Saturation",
	"Contrast",
	"Tint",
	"Blur",
	"BlurDrive",
	"Bloom",
	"BloomDrive",
	"SunRays",
	"Vignette",
	"Heat",
	"Flash",
	"SpeedLines",
})
local base = { Bloom = 0, SunRays = 0 }

local color: ColorCorrectionEffect
local blur: BlurEffect
local bloom: BloomEffect?
local sunRays: SunRaysEffect?
local flash: Frame
local vignette: ImageLabel
local heat: ImageLabel
local speedLines: { ImageLabel } = {}
local overlayRoot: Frame

function Post.apply(entry: { [string]: any }, duration: number)
	layers:apply(entry.post, entry, duration)
end

-- Per-frame value for a driven layer (set, never tweened).
function Post.drive(name: string, value: number)
	layers:set(name, value, 0)
end

-- Altitude-driven base for Bloom and SunRays; layers add on top.
function Post.setBase(name: string, value: number)
	base[name] = value
end

-- A full-screen radial image, oversized so its clear centre covers the middle of any aspect ratio.
local function radial(parent: Instance, texture: string, tint: Color3, scale: number, order: number): ImageLabel
	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Image = texture
	image.ImageColor3 = tint
	image.ImageTransparency = 1
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Position = UDim2.fromScale(0.5, 0.5)
	image.Size = UDim2.fromScale(scale, scale)
	image.ScaleType = Enum.ScaleType.Stretch
	image.ZIndex = order
	image.Parent = parent
	return image
end

local function fit()
	-- Keep the radial overlays square (the widest screen edge), centred, so the vignette is a circle not an oval.
	local viewport = workspace.CurrentCamera.ViewportSize
	local side = math.max(viewport.X, viewport.Y)
	overlayRoot.Size = UDim2.fromOffset(side, side)
end

local function update()
	local V = Tuning.Vfx
	color.Saturation = layers:get("Saturation")
	color.Contrast = layers:get("Contrast")
	local warmth = math.clamp(layers:get("Tint"), 0, 1)
	color.TintColor = Color3.new(1, 1, 1):Lerp(V.HeatTint, warmth)
	local blurSize = layers:get("Blur") + layers:get("BlurDrive")
	blur.Size = math.max(0, blurSize)
	blur.Enabled = blurSize > 0.05
	if bloom then
		bloom.Intensity = math.max(0, base.Bloom + layers:get("Bloom") + layers:get("BloomDrive"))
	end
	if sunRays then
		sunRays.Intensity = math.max(0, base.SunRays + layers:get("SunRays"))
	end
	flash.BackgroundTransparency = 1 - math.clamp(layers:get("Flash"), 0, 1)
	vignette.ImageTransparency = 1 - math.clamp(layers:get("Vignette"), 0, 1)
	heat.ImageTransparency = 1 - math.clamp(layers:get("Heat"), 0, 1) * V.HeatMaxAlpha

	local lines = math.clamp(layers:get("SpeedLines"), 0, 1)
	local t = os.clock()
	for index, image in speedLines do
		local direction = if index % 2 == 0 then -1 else 1
		local flicker = 0.5 + 0.5 * math.noise(t * V.SpeedLineFlicker, index * 13.7)
		image.Rotation = direction * t * V.SpeedLineSpin + index * 37
		image.ImageTransparency = 1 - lines * V.SpeedLineMaxAlpha * (0.6 + 0.4 * flicker)
		image.Visible = lines > 0.02
	end
end

function Post.start()
	local V = Tuning.Vfx
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

	overlayRoot = Instance.new("Frame")
	overlayRoot.BackgroundTransparency = 1
	overlayRoot.AnchorPoint = Vector2.new(0.5, 0.5)
	overlayRoot.Position = UDim2.fromScale(0.5, 0.5)
	overlayRoot.Parent = gui
	for index = 1, 2 do
		table.insert(speedLines, radial(overlayRoot, V.SpeedLineOverlay, Color3.new(1, 1, 1), V.SpeedLineScale, index))
	end
	heat = radial(overlayRoot, V.VignetteTexture, V.HeatColor, V.HeatScale, 3)
	vignette = radial(overlayRoot, V.VignetteTexture, Color3.new(0, 0, 0), V.VignetteScale, 4)

	flash = Instance.new("Frame")
	flash.BackgroundColor3 = V.FlashColor
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Size = UDim2.fromScale(1, 1)
	flash.ZIndex = 5
	flash.Parent = gui

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	fit()
	RunService.RenderStepped:Connect(update)
end

return Post
