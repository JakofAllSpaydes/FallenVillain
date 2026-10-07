--!strict
-- Blob shadow straight below the player so height above the ground is always readable. It shrinks and fades
-- with height and is gone above MaxHeight. Client-only, one pooled part under the camera.

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Globe = require(Shared.Globe)
local Tuning = require(Shared.Tuning)

local Controller = require(script.Parent.Parent.Movement.Controller)
local MathUtil = require(script.Parent.Parent.Movement.MathUtil)

local GroundShadow = {}

-- Thin enough to sit on the ground without z-fighting; not a feel value.
local THICKNESS = 0.05
local LIFT = 0.06

local blob: Part

local function update()
	local ctx = Controller.ctx
	if not ctx then
		blob.Transparency = 1
		return
	end
	local T = Tuning.GroundShadow
	local origin = ctx.Root.Position
	local hit = Globe.raycast(origin, -ctx.Up * T.MaxHeight, ctx.RaycastParams)
	if not hit then
		blob.Transparency = 1
		return
	end
	local height = math.max(0, (origin - hit.Position):Dot(ctx.Up) - ctx.StandHeight)
	local t = math.clamp(height / T.MaxHeight, 0, 1)
	local diameter = T.Diameter * (1 + (T.MinScale - 1) * t)
	blob.Size = Vector3.new(THICKNESS, diameter, diameter)
	blob.CFrame = MathUtil.onSurface(hit.Position + hit.Normal * LIFT, hit.Normal)
	blob.Transparency = T.Transparency + (1 - T.Transparency) * t
end

function GroundShadow.start()
	blob = Instance.new("Part")
	blob.Name = "GroundShadow"
	blob.Shape = Enum.PartType.Cylinder
	blob.Anchored = true
	blob.CanCollide = false
	blob.CanQuery = false
	blob.CanTouch = false
	blob.CastShadow = false
	blob.Material = Enum.Material.SmoothPlastic
	blob.Color = Color3.new(0, 0, 0)
	blob.Transparency = 1
	blob.Parent = workspace.CurrentCamera
	RunService:BindToRenderStep("FallGroundShadow", Enum.RenderPriority.Camera.Value + 2, update)
end

return GroundShadow
