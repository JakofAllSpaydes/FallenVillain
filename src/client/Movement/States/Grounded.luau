--!strict
-- Grounded: the Humanoid walks; the controller watches Space and walking off ledges.
-- Space is a tap-or-hold check: released within Hop.TapTime it hops. Held longer with a full Burst charge it
-- starts Charging; without one it charges a higher hop that fires on release (or when fully charged).

local Shared = game:GetService("ReplicatedStorage").Shared
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)
local MathUtil = require(script.Parent.Parent.MathUtil)
local Punch = require(script.Parent.Parent.Punch)

local Grounded = { Air = false, Punch = "Ground" }

local airborneTime = 0
local jumpHold: number? = nil

function Grounded.enter(ctx: Types.Ctx, payload: any)
	airborneTime = 0
	-- Landing hands over a Space press that came too late to chain, so the tap-or-hold check still runs.
	jumpHold = if payload ~= nil and payload.JumpPending and ctx.Input.JumpHeld then 0 else nil
end

local function hopCharge(hold: number): number
	local T = Tuning.Hop
	return math.clamp((hold - T.TapTime) / T.ChargeTime, 0, 1)
end

function Grounded.update(ctx: Types.Ctx, dt: number): (Types.MovementState?, any)
	ctx.Humanoid.WalkSpeed = Tuning.Walk.Speed * Punch.slow(ctx, Tuning.Punch.ChargeWalkMult)
	local look = MathUtil.flat(ctx.Root.CFrame.LookVector)
	if look.Magnitude > 1e-3 then
		ctx.Heading = look.Unit
	end

	if ctx.Input.JumpPressed then
		jumpHold = 0
	end
	if jumpHold ~= nil then
		local hold = jumpHold + dt
		jumpHold = hold
		if not ctx.Input.JumpHeld then
			jumpHold = nil
			return "Hop", { Charge = hopCharge(hold) }
		end
		if hold >= Tuning.Hop.TapTime then
			if ctx.Charge >= 1 then
				jumpHold = nil
				return "Charging", { Held = hold }
			end
			if hopCharge(hold) >= 1 then
				jumpHold = nil
				return "Hop", { Charge = 1 }
			end
		end
	end

	if ctx.Humanoid.FloorMaterial == Enum.Material.Air then
		airborneTime += dt
		if airborneTime >= Tuning.Physics.AirborneGraceTime then
			local probe = -Vector3.yAxis * (ctx.StandHeight + Tuning.Physics.GroundRayLength)
			if not workspace:Raycast(ctx.Root.Position, probe, ctx.RaycastParams) then
				jumpHold = nil
				return "Glide", nil
			end
		end
	else
		airborneTime = 0
	end
	return nil
end

return Grounded
