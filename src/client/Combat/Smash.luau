--!strict
-- Reports destruction to the server (spec §9, §15 milestone 4): Smashes (a dive into the ground or a structure)
-- and Hits (flying into one object), with the contact speed, the fall's start altitude and the attack force.
-- Contacts are collected and sent as one batch per frame, never dropped one by one: a fast dive through a town
-- touches many things in a few frames and every one must count. The server budgets batches per player, then
-- validates, applies damage and pays out, and broadcasts Broken and Rebuilt lists that Feel/Destruction plays.

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Net = require(Shared.Net)
local Signal = require(Shared.Signal)
local Tuning = require(Shared.Tuning)

local Controller = require(script.Parent.Parent.Movement.Controller)
local Punch = require(script.Parent.Parent.Movement.Punch)

local Smash = {}

-- (extra seconds) fired whenever a movement event refills the combo (Tuning.Combo.ExtendOnEnter, chain hops,
-- punches, bounces, a Burst release with its flight time as the extra); the banner refills its window on it
-- and the server hears the same through ComboAlive.
Smash.ComboExtended = Signal.new() :: Signal.Signal<number>

local lastPing = -math.huge
local comboAlive: RemoteEvent

export type Contact = {
	Kind: "Smash" | "Hit" | "Blast",
	Position: Vector3,
	Speed: number, -- the contact speed, or a blast's strength in the same units
	FallPeak: number,
	Force: number,
	Model: Model?, -- the object touched (always set for a Hit; a ground Smash has none)
}

local pending: { Contact } = {}

local function queue(contact: Contact)
	if #pending < Tuning.Net.MaxContactsPerBatch then
		table.insert(pending, contact)
	end
end

-- A shot landing or a beam tick (Combat/Blaster): a smash at `position` with `strength` standing in for speed.
function Smash.queueBlast(position: Vector3, strength: number, model: Model?)
	local ctx = Controller.ctx
	if ctx then
		queue({
			Kind = "Blast",
			Position = position,
			Speed = strength,
			FallPeak = ctx.FallPeak,
			Force = 1,
			Model = model,
		})
	end
end

function Smash.start()
	local contacts = Net.event("Contacts")

	Controller.Smashed:Connect(function(position, speed, _radius, direct, force)
		local ctx = Controller.ctx
		if ctx then
			queue({
				Kind = "Smash",
				Position = position,
				Speed = speed,
				FallPeak = ctx.FallPeak,
				Force = force,
				Model = direct,
			})
		end
	end)

	Controller.HitObject:Connect(function(model, position, speed, force)
		local ctx = Controller.ctx
		if ctx then
			queue({
				Kind = "Hit",
				Position = position,
				Speed = speed,
				FallPeak = ctx.FallPeak,
				Force = force,
				Model = model,
			})
		end
	end)

	-- Combo refills: one-shot events only, rate-limited to PingInterval (a Burst's extra always goes through).
	comboAlive = Net.event("ComboAlive")
	local function extend(extra: number)
		local now = os.clock()
		if extra <= 0 and now - lastPing < Tuning.Combo.PingInterval then
			return
		end
		lastPing = now
		comboAlive:FireServer(extra)
		Smash.ComboExtended:Fire(extra)
	end
	Controller.StateChanged:Connect(function(_from, to, _payload)
		local ctx = Controller.ctx
		if not ctx then
			return
		end
		if to == "Burst" then
			-- The release counts for the flight it launches: ascent plus hang.
			extend(math.min(ctx.BurstAscentTime + Tuning.Hang.Time, Tuning.Combo.BurstExtendMax))
		elseif Tuning.Combo.ExtendOnEnter[to] or (to == "Hop" and ctx.HopChain >= 1) then
			extend(0)
		end
	end)
	Punch.Fired:Connect(function(kind)
		if kind == "Dash" or kind == "Rocket" then
			extend(0)
		end
	end)
	Controller.Bounced:Connect(function()
		extend(0)
	end)

	RunService.Heartbeat:Connect(function()
		if #pending > 0 then
			contacts:FireServer(pending)
			pending = {}
		end
	end)
end

return Smash
