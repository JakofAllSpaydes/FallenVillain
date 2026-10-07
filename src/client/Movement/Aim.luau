--!strict
-- Aim ray (spec §10): from the camera through the screen-center crosshair, against the world, excluding
-- characters. Magnet and smash preview arrive with destructibles in milestone 3.

local Shared = game:GetService("ReplicatedStorage").Shared
local Globe = require(Shared.Globe)
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)

local Aim = {}

-- The camera rig writes its base view here each frame (without shake, tilt or roll), so effects never move the aim.
Aim.view = nil :: CFrame?

function Aim.update(ctx: Types.Ctx)
	local view = Aim.view or workspace.CurrentCamera.CFrame
	local reach = view.LookVector * Tuning.Aim.MaxDistance
	local hit = Globe.raycast(view.Position, reach, ctx.RaycastParams)
	ctx.LookDirection = view.LookVector
	ctx.AimPoint = if hit then hit.Position else view.Position + reach
end

return Aim
