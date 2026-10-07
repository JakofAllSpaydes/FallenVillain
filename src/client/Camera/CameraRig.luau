--!strict
-- Base follow camera (spec §11), mouse-look: the cursor is locked to the screen center and only the player's
-- mouse or right stick turns the camera. The crosshair is the aim point; states only change follow distance.
-- CameraEffects layers stack on top; the aim ray uses the base rig without them.

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local UserGameSettings = UserSettings():GetService("UserGameSettings")

local Shared = game:GetService("ReplicatedStorage").Shared
local Tuning = require(Shared.Tuning)

local Aim = require(script.Parent.Parent.Movement.Aim)
local CameraEffects = require(script.Parent.CameraEffects)
local Controller = require(script.Parent.Parent.Movement.Controller)
local MathUtil = require(script.Parent.Parent.Movement.MathUtil)

local CameraRig = {}

local yaw, pitch = 0, Tuning.Camera.StartPitch
local distance = Tuning.Camera.Distance.Grounded
local mouseLookEnabled = true
local initialized = false

local function readLook(dt: number)
	local C = Tuning.Camera
	if mouseLookEnabled then
		local delta = UserInputService:GetMouseDelta() * C.MouseSensitivity * UserGameSettings.MouseSensitivity
		yaw -= delta.X
		pitch -= delta.Y
	end
	if UserInputService.GamepadEnabled then
		for _, state in UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) do
			if state.KeyCode == Enum.KeyCode.Thumbstick2 and state.Position.Magnitude > Tuning.Input.StickDeadzone then
				yaw -= state.Position.X * C.StickYawRate * dt
				pitch += state.Position.Y * C.StickPitchRate * dt
			end
		end
	end
	yaw = (yaw + 180) % 360 - 180
	pitch = math.clamp(pitch, C.PitchMin, C.PitchMax)
end

local function update(dt: number)
	local ctx = Controller.ctx
	local camera = workspace.CurrentCamera
	if not ctx then
		return
	end
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	-- Core scripts and the escape menu may change these; reassert every frame.
	UserInputService.MouseBehavior = if mouseLookEnabled
		then Enum.MouseBehavior.LockCenter
		else Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = not mouseLookEnabled

	local C = Tuning.Camera
	if not initialized then
		initialized = true
		yaw = MathUtil.yawOf(ctx.Heading)
	end
	readLook(dt)

	local wantedDistance = C.Distance[ctx.State] or C.Distance.Grounded
	distance = MathUtil.approach(distance, wantedDistance, C.DistanceResponse, dt)

	local effects = CameraEffects.sample()
	local rotation = CFrame.fromOrientation(math.rad(pitch), math.rad(yaw), 0)
	local focus = ctx.Root.Position + Vector3.yAxis * C.FocusHeight + rotation.RightVector * C.ShoulderOffset
	local offset = -rotation.LookVector * math.max(0, distance + effects.Distance)
	local blocked = workspace:Raycast(focus, offset, ctx.RaycastParams)
	local position = if blocked then blocked.Position - offset.Unit * C.CollisionMargin else focus + offset

	local base = CFrame.new(position) * rotation
	Aim.view = base
	local shaken = base * CFrame.new(effects.Offset)
	camera.CFrame = shaken * effects.Rotation
	camera.Focus = CFrame.new(focus)
	camera.FieldOfView = math.clamp(C.BaseFov + effects.Fov, 1, 120)
end

function CameraRig.setMouseLookEnabled(enabled: boolean)
	mouseLookEnabled = enabled
end

function CameraRig.start()
	RunService:BindToRenderStep("FallCameraRig", Enum.RenderPriority.Camera.Value + 1, update)
end

return CameraRig
