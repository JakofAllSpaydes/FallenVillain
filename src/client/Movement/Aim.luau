--!strict
-- Aim ray (spec §10): from the camera through the screen-center crosshair, against the world, excluding
-- characters. Magnet and smash preview arrive with destructibles in milestone 3.

local Shared = game:GetService("ReplicatedStorage").Shared
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)

local Aim = {}

function Aim.update(ctx: Types.Ctx)
	local view = workspace.CurrentCamera.CFrame
	local reach = view.LookVector * Tuning.Aim.MaxDistance
	local hit = workspace:Raycast(view.Position, reach, ctx.RaycastParams)
	ctx.LookDirection = view.LookVector
	ctx.AimPoint = if hit then hit.Position else view.Position + reach
end

return Aim
