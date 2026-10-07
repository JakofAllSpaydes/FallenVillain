--!strict
-- Collects the four inputs (space, hold space, left, right) plus move and aim into a per-frame snapshot.
-- Edge flags (Pressed/Released) accumulate between snapshots so a tap shorter than a frame is never lost.

local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)

local Input = {}

local JUMP_KEYS = { [Enum.KeyCode.Space] = true, [Enum.KeyCode.ButtonA] = true }
local PRIMARY_INPUTS = { [Enum.UserInputType.MouseButton1] = true, [Enum.KeyCode.ButtonR2] = true }
local SECONDARY_INPUTS = { [Enum.UserInputType.MouseButton2] = true, [Enum.KeyCode.ButtonL2] = true }

local jumpHeld, jumpPressed, jumpReleased = false, false, false
local primaryHeld, primaryPressed, primaryReleased = false, false, false
local secondaryHeld = false

local function matches(set: { [any]: boolean }, input: InputObject): boolean
	return set[input.KeyCode] == true or set[input.UserInputType] == true
end

local MOVE_KEYS: { [Enum.KeyCode]: Vector3 } = {
	[Enum.KeyCode.W] = -Vector3.zAxis,
	[Enum.KeyCode.Up] = -Vector3.zAxis,
	[Enum.KeyCode.S] = Vector3.zAxis,
	[Enum.KeyCode.Down] = Vector3.zAxis,
	[Enum.KeyCode.A] = -Vector3.xAxis,
	[Enum.KeyCode.Left] = -Vector3.xAxis,
	[Enum.KeyCode.D] = Vector3.xAxis,
	[Enum.KeyCode.Right] = Vector3.xAxis,
}

-- Same convention as the old ControlModule move vector: x right, z back. Read directly because the core
-- control scripts are no longer forked into PlayerScripts.
local function readMove(): Vector3
	if UserInputService:GetFocusedTextBox() then
		return Vector3.zero
	end
	local move = Vector3.zero
	for key, direction in MOVE_KEYS do
		if UserInputService:IsKeyDown(key) then
			move += direction
		end
	end
	if UserInputService.GamepadEnabled then
		for _, state in UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) do
			if state.KeyCode == Enum.KeyCode.Thumbstick1 and state.Position.Magnitude > Tuning.Input.StickDeadzone then
				move += Vector3.new(state.Position.X, 0, -state.Position.Y)
			end
		end
	end
	return if move.Magnitude > 1 then move.Unit else move
end

local function onBegan(input: InputObject, processed: boolean)
	if UserInputService:GetFocusedTextBox() then
		return
	end
	-- Space is bound by the core control scripts, which mark it processed; only GUI clicks should block mouse.
	if matches(JUMP_KEYS, input) then
		jumpHeld, jumpPressed = true, true
	elseif processed then
		return
	elseif matches(PRIMARY_INPUTS, input) then
		primaryHeld, primaryPressed = true, true
	elseif matches(SECONDARY_INPUTS, input) then
		secondaryHeld = true
	end
end

local function onEnded(input: InputObject)
	if matches(JUMP_KEYS, input) and jumpHeld then
		jumpHeld, jumpReleased = false, true
	elseif matches(PRIMARY_INPUTS, input) and primaryHeld then
		primaryHeld, primaryReleased = false, true
	elseif matches(SECONDARY_INPUTS, input) then
		secondaryHeld = false
	end
end

function Input.start()
	UserInputService.InputBegan:Connect(onBegan)
	UserInputService.InputEnded:Connect(onEnded)
	UserInputService.WindowFocusReleased:Connect(function()
		if jumpHeld then
			jumpHeld, jumpReleased = false, true
		end
		if primaryHeld then
			primaryHeld, primaryReleased = false, true
		end
		secondaryHeld = false
	end)
end

function Input.snapshot(): Types.InputSnapshot
	local snapshot: Types.InputSnapshot = {
		JumpHeld = jumpHeld,
		JumpPressed = jumpPressed,
		JumpReleased = jumpReleased,
		PrimaryHeld = primaryHeld,
		PrimaryPressed = primaryPressed,
		PrimaryReleased = primaryReleased,
		SecondaryHeld = secondaryHeld,
		Move = readMove(),
	}
	jumpPressed, jumpReleased = false, false
	primaryPressed, primaryReleased = false, false
	return snapshot
end

return Input
