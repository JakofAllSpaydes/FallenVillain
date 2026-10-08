--!strict
-- Touch controls (spec §15 milestone 3b): the phone layout, shown only on touch devices. Everything feeds the
-- same input snapshot as the keyboard (Movement/Input.luau), so no state knows which it was.
--   * Left of the screen (Input.Touch.StickZone): a dynamic thumbstick that appears where the thumb lands. Move.
--   * Anywhere else: drag to look, the same yaw and pitch the mouse drives (Camera.TouchSensitivity).
--   * Bottom-right: JUMP (everything Space does: tap hops, hold charges a Burst, in the air dives, release
--     swoops) and PUNCH (everything LMB does) buttons.
-- Every touch is tracked on its own InputObject, so the stick, the look drag and both buttons work at once.
-- Roblox's own TouchGui is hidden if it ever appears; the controller owns movement.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Tuning = require(game:GetService("ReplicatedStorage").Shared.Tuning)

local Input = require(script.Parent.Input)

local TouchControls = {}

-- Look of a test-stage control layer; not gameplay tuning. Sizes are at 1080p and scale with the screen.
local FONT = Enum.Font.FredokaOne
local REFERENCE_HEIGHT = 1080
local BUTTON_COLOR = Color3.fromRGB(245, 245, 245)
local BUTTON_HELD_COLOR = Color3.fromRGB(255, 196, 60)
local BUTTON_TEXT = Color3.fromRGB(30, 30, 35)
local OUTLINE = Color3.fromRGB(20, 20, 25)
local BUTTON_TRANSPARENCY = 0.4
local HELD_TRANSPARENCY = 0.1
local STICK_BASE_TRANSPARENCY = 0.6
local STICK_KNOB_TRANSPARENCY = 0.25
local LABEL_SHARE = 0.22 -- text size relative to the button

local scale = 1
local stickTouch: InputObject? = nil
local stickOrigin = Vector2.zero
local lookTouch: InputObject? = nil
local lookLast = Vector2.zero

local function position2(input: InputObject): Vector2
	return Vector2.new(input.Position.X, input.Position.Y)
end

local function round(frame: GuiObject, strokeTransparency: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = OUTLINE
	stroke.Thickness = 2
	stroke.Transparency = strokeTransparency
	stroke.Parent = frame
end

type ButtonSpec = { Size: number, Right: number, Bottom: number }

local function button(parent: Instance, label: string, spec: ButtonSpec, onHeld: (boolean) -> ())
	local b = Instance.new("TextButton")
	b.Name = label
	b.Text = label
	b.Font = FONT
	b.TextSize = spec.Size * LABEL_SHARE
	b.TextColor3 = BUTTON_TEXT
	b.AutoButtonColor = false
	b.AnchorPoint = Vector2.new(1, 1)
	b.Position = UDim2.new(1, -spec.Right, 1, -spec.Bottom)
	b.Size = UDim2.fromOffset(spec.Size, spec.Size)
	b.BackgroundColor3 = BUTTON_COLOR
	b.BackgroundTransparency = BUTTON_TRANSPARENCY
	b.BorderSizePixel = 0
	b.Parent = parent
	round(b, 0.2)

	local touch: InputObject? = nil
	b.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if touch == nil and (kind == Enum.UserInputType.Touch or kind == Enum.UserInputType.MouseButton1) then
			touch = input
			b.BackgroundColor3 = BUTTON_HELD_COLOR
			b.BackgroundTransparency = HELD_TRANSPARENCY
			onHeld(true)
		end
	end)
	-- Released through the service, not the button: the thumb may slide off before it lifts.
	UserInputService.InputEnded:Connect(function(input)
		if input == touch then
			touch = nil
			b.BackgroundColor3 = BUTTON_COLOR
			b.BackgroundTransparency = BUTTON_TRANSPARENCY
			onHeld(false)
		end
	end)
end

-- Hide the engine's own thumbstick and jump button if the core scripts ever add them.
local function hideCoreTouchGui(playerGui: PlayerGui)
	local function hide(child: Instance)
		if child.Name == "TouchGui" and child:IsA("ScreenGui") then
			child.Enabled = false
		end
	end
	playerGui.ChildAdded:Connect(hide)
	for _, child in playerGui:GetChildren() do
		hide(child)
	end
end

function TouchControls.enabled(): boolean
	return UserInputService.TouchEnabled
end

function TouchControls.start()
	if not TouchControls.enabled() then
		return
	end
	local T = Tuning.Input.Touch
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	hideCoreTouchGui(playerGui)

	local gui = Instance.new("ScreenGui")
	gui.Name = "FallTouchControls"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 40

	local uiScale = Instance.new("UIScale")
	uiScale.Parent = gui
	local function rescale()
		local height = workspace.CurrentCamera.ViewportSize.Y
		scale = math.clamp(height / REFERENCE_HEIGHT, T.MinScale, T.MaxScale)
		uiScale.Scale = scale
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	rescale()

	-- Thumbstick: a ring that appears under the thumb and a knob that follows it within StickRadius.
	local base = Instance.new("Frame")
	base.Name = "Stick"
	base.AnchorPoint = Vector2.new(0.5, 0.5)
	base.Size = UDim2.fromOffset(T.StickBase, T.StickBase)
	base.BackgroundColor3 = BUTTON_COLOR
	base.BackgroundTransparency = STICK_BASE_TRANSPARENCY
	base.BorderSizePixel = 0
	base.Visible = false
	base.Parent = gui
	round(base, 0.5)
	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.fromScale(0.5, 0.5)
	knob.Size = UDim2.fromOffset(T.StickKnob, T.StickKnob)
	knob.BackgroundColor3 = BUTTON_COLOR
	knob.BackgroundTransparency = STICK_KNOB_TRANSPARENCY
	knob.BorderSizePixel = 0
	knob.Parent = base
	round(knob, 0.2)

	button(gui, "PUNCH", T.PunchButton, Input.setTouchPrimary)
	button(gui, "JUMP", T.JumpButton, Input.setTouchJump)

	gui.Parent = playerGui

	local function endStick()
		stickTouch = nil
		base.Visible = false
		knob.Position = UDim2.fromScale(0.5, 0.5)
		Input.setTouchMove(Vector3.zero)
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType ~= Enum.UserInputType.Touch or processed then
			return
		end
		local position = position2(input)
		local viewport = workspace.CurrentCamera.ViewportSize
		if stickTouch == nil and position.X < viewport.X * T.StickZone then
			stickTouch = input
			stickOrigin = position
			base.Position = UDim2.fromOffset(position.X / scale, position.Y / scale)
			knob.Position = UDim2.fromScale(0.5, 0.5)
			base.Visible = true
		elseif lookTouch == nil then
			lookTouch = input
			lookLast = position
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local position = position2(input)
		if input == stickTouch then
			local radius = T.StickRadius * scale
			local offset = position - stickOrigin
			if offset.Magnitude > radius then
				offset = offset.Unit * radius
			end
			knob.Position = UDim2.new(0.5, offset.X / scale, 0.5, offset.Y / scale)
			local raw = offset / radius
			local magnitude = raw.Magnitude
			if magnitude < T.StickDeadzone then
				Input.setTouchMove(Vector3.zero)
			else
				local strength = (magnitude - T.StickDeadzone) / (1 - T.StickDeadzone)
				local direction = raw / magnitude
				-- Screen down is "back" in the move vector's convention (x right, z back).
				Input.setTouchMove(Vector3.new(direction.X, 0, direction.Y) * strength)
			end
		elseif input == lookTouch then
			Input.addTouchLook(position - lookLast)
			lookLast = position
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input == stickTouch then
			endStick()
		elseif input == lookTouch then
			lookTouch = nil
		end
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		endStick()
		lookTouch = nil
	end)
end

return TouchControls
