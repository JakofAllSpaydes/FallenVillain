--!strict
-- Base follow camera (spec §11), mouse-look: the cursor is locked to the screen center and only the player's
-- mouse or right stick turns the camera. The crosshair is the aim point; states only change follow distance.
-- CameraEffects layers stack on top; the aim ray uses the base rig without them.
--
-- On the globe the camera's "up" is the player's up. Yaw is measured from a reference direction that is
-- rolled with the planet as the player moves (parallel transport), so walking or flying in a straight line
-- never turns the view, and there is no pole to spin around.

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local UserGameSettings = UserSettings():GetService("UserGameSettings")

local Shared = game:GetService("ReplicatedStorage").Shared
local Globe = require(Shared.Globe)
local Tuning = require(Shared.Tuning)

local Aim = require(script.Parent.Parent.Movement.Aim)
local CameraEffects = require(script.Parent.CameraEffects)
local Controller = require(script.Parent.Parent.Movement.Controller)
local Input = require(script.Parent.Parent.Movement.Input)
local MathUtil = require(script.Parent.Parent.Movement.MathUtil)

local CameraRig = {}

local yaw, pitch = 0, Tuning.Camera.StartPitch
local distance = Tuning.Camera.Distance.Grounded
local mouseLookEnabled = true
local initialized = false
local up = Vector3.yAxis
local reference = -Vector3.zAxis -- level direction yaw 0 looks along

local function readLook(dt: number)
	local C = Tuning.Camera
	if mouseLookEnabled then
		local delta = UserInputService:GetMouseDelta() * C.MouseSensitivity * UserGameSettings.MouseSensitivity
		yaw -= delta.X
		pitch -= delta.Y
	end
	-- Touch look drag (TouchControls): same directions as the mouse.
	local touch = Input.takeTouchLook() * C.TouchSensitivity
	yaw -= touch.X
	pitch -= touch.Y
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
		up = ctx.Up
		reference = MathUtil.tangent(ctx.Heading, up, -Vector3.zAxis)
	end
	-- Roll the yaw reference with the planet, then keep it level and unit length against drift.
	local roll = MathUtil.transport(up, ctx.Up)
	up = ctx.Up
	reference = MathUtil.tangent(roll * reference, up, reference)
	readLook(dt)

	local wantedDistance = C.Distance[ctx.State] or C.Distance.Grounded
	distance = MathUtil.approach(distance, wantedDistance, C.DistanceResponse, dt)

	local effects = CameraEffects.sample()
	local forward = MathUtil.yawRight(reference, -yaw, up)
	local look = MathUtil.pathDirection(forward, pitch, up)
	local rotation = CFrame.lookAlong(Vector3.zero, look, up)
	local focus = ctx.Root.Position + up * C.FocusHeight + rotation.RightVector * C.ShoulderOffset
	local offset = -look * math.max(0, distance + effects.Distance)
	local blocked = Globe.raycast(focus, offset, ctx.RaycastParams)
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
