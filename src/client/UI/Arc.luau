--!strict
-- A chunky ring that fills clockwise from 12 o'clock over a dark outlined backing ring, in the mobile-HUD style
-- of the controls cheat sheet. Used by the punch and jump charge rings.
-- A UIStroke draws outside its frame, so each ring frame is inset by its stroke band: the backing fills the
-- outer `thickness + 2 × border` pixels of the arc's box and the fill sits centred in it.
-- The fill is two clipped halves of a ring stroke, each masked by a hard-edged UIGradient whose rotation sweeps
-- the visible half-plane: rotation θ shows the arc from 12 o'clock to θ within that half.

local Arc = {}
Arc.__index = Arc

local BACKING = Color3.fromRGB(20, 20, 25)
local HALF_MASK = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.5, 0),
	NumberSequenceKeypoint.new(0.501, 1),
	NumberSequenceKeypoint.new(1, 1),
})

type Half = { Stroke: UIStroke, Mask: UIGradient, Min: number, Max: number }
export type Arc = typeof(setmetatable(
	{} :: { Frame: Frame, Backing: UIStroke, Halves: { Half }, BackingTransparency: number },
	Arc
))

local function ring(parent: Instance, size: UDim2, position: UDim2, thickness: number, color: Color3): UIStroke
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.Size = size
	frame.Position = position
	frame.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness
	stroke.Color = color
	stroke.Parent = frame
	return stroke
end

-- `size` is the ring's frame size within `parent`, centered. The backing ring is `border` wider on each side.
function Arc.new(parent: Instance, size: UDim2, thickness: number, border: number, backingTransparency: number): Arc
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = size
	frame.Visible = false
	frame.Parent = parent

	local band = thickness + border * 2
	local inset = thickness + border
	local backing = ring(frame, UDim2.new(1, -band * 2, 1, -band * 2), UDim2.fromOffset(band, band), band, BACKING)
	local halves = {}
	-- { min angle, max angle, clip position, ring position within the clip }
	local specs = {
		{ 0, 180, UDim2.fromScale(0.5, 0), UDim2.new(-1, inset, 0, inset) },
		{ 180, 360, UDim2.new(), UDim2.fromOffset(inset, inset) },
	}
	for _, spec in specs do
		local clip = Instance.new("Frame")
		clip.BackgroundTransparency = 1
		clip.ClipsDescendants = true
		clip.Size = UDim2.fromScale(0.5, 1)
		clip.Position = spec[3]
		clip.Parent = frame
		local stroke = ring(clip, UDim2.new(2, -inset * 2, 1, -inset * 2), spec[4], thickness, Color3.new(1, 1, 1))
		local mask = Instance.new("UIGradient")
		mask.Transparency = HALF_MASK
		mask.Parent = stroke
		table.insert(halves, { Stroke = stroke, Mask = mask, Min = spec[1], Max = spec[2] })
	end
	return setmetatable(
		{ Frame = frame, Backing = backing, Halves = halves, BackingTransparency = backingTransparency },
		Arc
	)
end

-- fill 0–1; alpha 0–1 fades the whole ring in and out.
function Arc.set(self: Arc, fill: number, color: Color3, alpha: number)
	self.Frame.Visible = alpha > 0
	if alpha <= 0 then
		return
	end
	local angle = math.clamp(fill, 0, 1) * 360
	self.Backing.Transparency = 1 - (1 - self.BackingTransparency) * alpha
	for _, half in self.Halves do
		half.Mask.Rotation = math.clamp(angle, half.Min, half.Max)
		half.Stroke.Color = color
		half.Stroke.Transparency = 1 - alpha
	end
end

return Arc
