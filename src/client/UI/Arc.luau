--!strict
-- A ring that fills clockwise from 12 o'clock, with a faint full-circle track behind it. Used by the punch and
-- jump charge wheels. The arc is two clipped halves of a ring stroke, each masked by a hard-edged UIGradient
-- whose rotation sweeps the visible half-plane: rotation θ shows the arc from 12 o'clock to θ within that half.

local Arc = {}
Arc.__index = Arc

local HALF_MASK = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.5, 0),
	NumberSequenceKeypoint.new(0.501, 1),
	NumberSequenceKeypoint.new(1, 1),
})

type Half = { Stroke: UIStroke, Mask: UIGradient, Min: number, Max: number }
export type Arc = typeof(setmetatable({} :: { Frame: Frame, Track: UIStroke, Halves: { Half } }, Arc))

local function ring(parent: Instance, size: UDim2, position: UDim2, thickness: number): UIStroke
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
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Parent = frame
	return stroke
end

-- `size` is the ring's frame size within `parent`, centered.
function Arc.new(parent: Instance, size: UDim2, thickness: number): Arc
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = size
	frame.Parent = parent

	local track = ring(frame, UDim2.fromScale(1, 1), UDim2.new(), thickness)
	local halves = {}
	for _, spec in
		{ { 0, 180, UDim2.fromScale(0.5, 0), UDim2.fromScale(-1, 0) }, { 180, 360, UDim2.new(), UDim2.new() } }
	do
		local clip = Instance.new("Frame")
		clip.BackgroundTransparency = 1
		clip.ClipsDescendants = true
		clip.Size = UDim2.fromScale(0.5, 1)
		clip.Position = spec[3]
		clip.Parent = frame
		local stroke = ring(clip, UDim2.fromScale(2, 1), spec[4], thickness)
		local mask = Instance.new("UIGradient")
		mask.Transparency = HALF_MASK
		mask.Parent = stroke
		table.insert(halves, { Stroke = stroke, Mask = mask, Min = spec[1], Max = spec[2] })
	end
	return setmetatable({ Frame = frame, Track = track, Halves = halves }, Arc)
end

-- fill 0–1; alpha 0–1 fades the whole ring; trackTransparency is the faint track's own transparency.
function Arc.set(self: Arc, fill: number, color: Color3, alpha: number, trackTransparency: number)
	self.Frame.Visible = alpha > 0
	if alpha <= 0 then
		return
	end
	local angle = math.clamp(fill, 0, 1) * 360
	self.Track.Transparency = 1 - (1 - trackTransparency) * alpha
	for _, half in self.Halves do
		half.Mask.Rotation = math.clamp(angle, half.Min, half.Max)
		half.Stroke.Color = color
		half.Stroke.Transparency = 1 - alpha
	end
end

return Arc
