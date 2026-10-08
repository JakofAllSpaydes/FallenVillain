--!strict
-- The Space hold, tracked on its own so nothing else (a punch, a state change, leaving the ground) loses it;
-- only releasing acts. The controller calls `track` every frame; ground states call `update`.
--   * The charge is the whole time held, in the air as much as on the ground (review note at milestone 5: the
--     Burst charge should build in the air past the first ring): hold Space through a long dive and the
--     touchdown drops you straight into Charging with all of it, so a high dive can bounce straight back up.
--   * Released on the ground before Hop.HoldTime, it hops: Hop.Height for a tap up to Hop.ChargedHeight.
--     At Hop.HoldTime the ground state hands over to Charging, which Bursts on release.
--   * A punch out of Charging keeps the hold; land still holding and it resumes.
--   * Released in the air, the hold is spent (in the air Space is the dive).
-- The hop keeps the press time, so a chain hop is judged by when you pressed (a pre-held landing counts).

local Shared = game:GetService("ReplicatedStorage").Shared
local Progression = require(Shared.Progression)
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)
local Signal = require(Shared.Signal)
local MathUtil = require(script.Parent.MathUtil)

local JumpCheck = {}

-- (seconds held) each time a hold on the ground crosses a Burst.Tiers threshold
JumpCheck.TierReached = Signal.new() :: Signal.Signal<number>

local pressedAt: number? = nil
local airHeld = 0
local groundHeld = 0

function JumpCheck.clear()
	pressedAt = nil
	airHeld = 0
	groundHeld = 0
end

function JumpCheck.track(ctx: Types.Ctx, dt: number, onGround: boolean)
	if ctx.Input.JumpPressed then
		JumpCheck.clear()
		pressedAt = ctx.Now
	end
	if pressedAt == nil then
		return
	end
	if ctx.Input.JumpHeld then
		local charge = dt * Tuning.Dev.ChargeSpeed
		local before = JumpCheck.held() or 0
		if onGround then
			groundHeld += charge
		else
			airHeld += charge
		end
		local after = JumpCheck.held() or 0
		local tier = MathUtil.tier(Tuning.Burst.Tiers, after)
		-- Tier chimes only for circles the level has unlocked (shared/Progression.luau).
		if tier > MathUtil.tier(Tuning.Burst.Tiers, before) and tier <= Progression.circles(ctx.Level) - 1 then
			JumpCheck.TierReached:Fire(after)
		end
	elseif not onGround then
		JumpCheck.clear()
	end
end

-- Seconds of charge in the current hold, air and ground alike, or nil when Space isn't held.
function JumpCheck.held(): number?
	if pressedAt == nil then
		return nil
	end
	return airHeld + groundHeld
end

-- 0–1 hop charge of the current hold, or nil when Space isn't held.
function JumpCheck.hopCharge(): number?
	local held = JumpCheck.held()
	if held == nil then
		return nil
	end
	local T = Tuning.Hop
	return math.clamp((held - T.TapTime) / math.max(T.HoldTime - T.TapTime, 1e-3), 0, 1)
end

function JumpCheck.update(ctx: Types.Ctx): (Types.MovementState?, any)
	local started = pressedAt
	local held = JumpCheck.held()
	if started == nil or held == nil then
		return nil
	end
	if not ctx.Input.JumpHeld then
		local charge = JumpCheck.hopCharge() or 0
		JumpCheck.clear()
		return "Hop", { PressedAt = started, Charge = charge }
	end
	if held >= Tuning.Hop.HoldTime then
		return "Charging", nil
	end
	return nil
end

return JumpCheck
