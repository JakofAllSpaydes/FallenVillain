--!strict
-- Wings (spec §1, §4.1–4.9; §15 milestone 5): two procedural demon wings on the local character's back. Each
-- is a fan of three dark panels with a glowing leading edge, hung from a pivot behind the shoulder blade.
-- Three values per wing follow the state on a damped spring (Tuning.Wings): spread (0 folded along the back,
-- 1 fanned out), sweep (0 straight out to the side, 1 swept back along the body) and flex (degrees of
-- elevation added), so the wings fold on the ground, open with the Burst charge, throw up in a V on ignition,
-- spread wide in the last moments before the apex, flutter and flex with the climb in a glide, bank with the
-- turn, shake when glide energy strains, snap shut for a dive and crack open on a swoop. The leading edges
-- glow with the charge, flash on ignition and run hot at dive speed. The wingtip trails (Feel/Vfx) hang from
-- the outer panels. Client-only parts under the camera; other players' wings are a RemotePlayers job later.

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Tuning = require(Shared.Tuning)
local Types = require(Shared.Types)

local Controller = require(script.Parent.Parent.Movement.Controller)
local JumpCheck = require(script.Parent.Parent.Movement.JumpCheck)
local Vfx = require(script.Parent.Vfx)

local Wings = {}

type Panel = { Part: Part, Edge: Part, Length: number, Depth: number }
type Wing = {
	Sign: number, -- +1 right, -1 left
	Panels: { Panel },
	Value: { number }, -- spread, sweep, flex
	Velocity: { number },
	Tip0: Attachment,
	Tip1: Attachment,
}

local TORSO_PARTS = { "UpperTorso", "Torso" } -- R15 first, R6 fallback
local PANEL_STAGGER = 0.1 -- studs between panels along the body, against z-fighting; not a feel value
local SPRING_SUBSTEP = 1 / 120
local SPRING_MAX_SUBSTEPS = 4
local NOISE_SEEDS = { 7.3, 43.9 }
local HOP_APEX_CLIMB = 15 -- studs/s of climb within which a hop counts as at its apex; not a feel value
local HOP_APEX_SPREAD = 0.85

local folder: Folder
local wings: { Wing } = {}
local character: Model? = nil
local torso: BasePart? = nil
local snapUntil = 0
local burstGlowAt = -math.huge

local function lastBurstTier(): number
	local heights = Tuning.Burst.HoldHeights
	return heights[#heights][1]
end

local function holdProgress(held: number): number
	return math.clamp(math.log(1 + held) / math.log(1 + lastBurstTier()), 0, 1)
end

local function makePart(size: Vector3, color: Color3, material: Enum.Material, shadow: boolean): Part
	local part = Instance.new("Part")
	part.Size = size
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = shadow
	part.Parent = folder
	return part
end

local function build()
	local W = Tuning.Wings
	for _, wing in wings do
		for _, panel in wing.Panels do
			panel.Part:Destroy()
			panel.Edge:Destroy()
		end
	end
	wings = {}
	for _, sign in { -1, 1 } do
		local panels: { Panel } = {}
		for index, length in W.PanelLengths do
			local l = length * W.Scale
			local d = W.PanelDepths[index] * W.Scale
			local part = makePart(Vector3.new(l, W.PanelThickness, d), W.Color, Enum.Material.Fabric, true)
			local edge = makePart(Vector3.new(l, 0.14, 0.14), W.EdgeColor, Enum.Material.Neon, false)
			edge.Transparency = 1
			table.insert(panels, { Part = part, Edge = edge, Length = l, Depth = d })
		end
		local tip = panels[#panels]
		local tip0 = Instance.new("Attachment")
		tip0.Position = Vector3.new(sign * tip.Length / 2, 0, -tip.Depth / 2)
		tip0.Parent = tip.Part
		local tip1 = Instance.new("Attachment")
		tip1.Position = Vector3.new(sign * tip.Length / 2, 0, tip.Depth / 2)
		tip1.Parent = tip.Part
		table.insert(wings, {
			Sign = sign,
			Panels = panels,
			Value = { 0.1, 0.9, 0 },
			Velocity = { 0, 0, 0 },
			Tip0 = tip0,
			Tip1 = tip1,
		})
	end
	Vfx.setTrailAttachments(wings[1].Tip0, wings[1].Tip1, wings[2].Tip0, wings[2].Tip1)
end

local function bind(ctx: Types.Ctx)
	character = ctx.Character
	torso = nil
	for _, name in TORSO_PARTS do
		local part = ctx.Character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			torso = part
			break
		end
	end
	build()
end

-- Target { spread, sweep, flex } for one wing this frame.
local function targets(ctx: Types.Ctx, wing: Wing, now: number): (number, number, number)
	local W = Tuning.Wings
	local state = ctx.State
	local pose = W.Poses[state] or W.Poses.Grounded
	if state == "Burst" and ctx.StateTime >= ctx.BurstAscentTime - W.ApexSpread then
		pose = W.Poses.BurstLate
	end
	local spread, sweep, flex = pose[1], pose[2], pose[3]
	local climb = ctx.Velocity:Dot(ctx.Up)
	if state == "Charging" then
		spread += W.ChargeSpread * holdProgress(JumpCheck.held() or 0)
	elseif state == "Hop" and math.abs(climb) < HOP_APEX_CLIMB then
		spread = HOP_APEX_SPREAD
	elseif state == "Glide" or state == "Swoop" then
		flex += W.FlexByClimb * math.clamp(climb / math.max(Tuning.Anim.GlideFlexRef, 1e-3), -1, 1)
		flex += W.Flutter * math.sin(now * 2 * math.pi * W.FlutterHz + wing.Sign * 0.4)
		-- Banking right (positive) lifts the left wing and drops the right.
		flex -= wing.Sign * ctx.Bank * W.FlexByBank
		local E = Tuning.GlideEnergy
		if ctx.GlideEnergy < E.StrainThreshold then
			local strain = 1 - ctx.GlideEnergy / math.max(E.StrainThreshold, 1e-3)
			local seed = NOISE_SEEDS[if wing.Sign > 0 then 1 else 2]
			flex += math.noise(now * W.StrainHz, seed) * 2 * W.StrainShake * strain
		end
	end
	return spread, sweep, flex
end

-- The leading edge glow this frame, 0–1, and how hot it runs.
local function glow(ctx: Types.Ctx, now: number): (number, number)
	local W = Tuning.Wings
	local value = 0
	if ctx.State == "Charging" then
		value = holdProgress(JumpCheck.held() or 0)
	end
	local punch = ctx.PunchHold
	if punch then
		local boosts = Tuning.Punch.HoldBoosts
		value = math.max(value, math.clamp(math.log(1 + punch) / math.log(1 + boosts[#boosts][1]), 0, 1))
	end
	value = math.max(value, 1 - math.clamp((now - burstGlowAt) / math.max(W.BurstGlowTime, 1e-3), 0, 1))
	local S = Tuning.Drive.Speed
	local heat = math.clamp((ctx.Velocity.Magnitude - S.HeatStart) / math.max(S.HeatRange, 1e-3), 0, 1)
	return math.max(value, heat), heat
end

local function update(dt: number)
	local ctx = Controller.ctx
	if not ctx or not ctx.Root.Parent then
		return
	end
	if ctx.Character ~= character then
		bind(ctx)
	end
	local body = torso
	if not body then
		return
	end
	local W = Tuning.Wings
	local now = os.clock()
	local snapping = now < snapUntil
	local omega = 2 * math.pi * (if snapping then W.SnapFrequency else W.SpringFrequency)
	local damping = if snapping then W.SnapDamping else W.SpringDamping
	local steps = math.clamp(math.ceil(dt / SPRING_SUBSTEP), 1, SPRING_MAX_SUBSTEPS)
	local h = dt / steps
	local edgeGlow, heat = glow(ctx, now)
	local edgeColor = W.EdgeColor:Lerp(W.EdgeHeatColor, heat)
	local edgeTransparency = 1 - edgeGlow * W.EdgeMaxGlow

	for _, wing in wings do
		local target = { targets(ctx, wing, now) }
		local value, velocity = wing.Value, wing.Velocity
		for index = 1, 3 do
			local x, v = value[index], velocity[index]
			for _ = 1, steps do
				v += (omega * omega * (target[index] - x) - 2 * damping * omega * v) * h
				x += v * h
			end
			value[index], velocity[index] = x, v
		end
		local spread = math.clamp(value[1], -0.2, 1.2)
		local sweep = math.clamp(value[2], -0.2, 1.2)
		local sign = wing.Sign
		local pivot = body.CFrame * CFrame.new(sign * W.PivotOffset.X, W.PivotOffset.Y, W.PivotOffset.Z)
		local swept = CFrame.Angles(0, -sign * math.rad(sweep * W.FoldSweep), 0)
		for index, panel in wing.Panels do
			local elevation = W.FoldElevation + (W.FanElevations[index] - W.FoldElevation) * spread + value[3]
			local frame = pivot
				* swept
				* CFrame.Angles(0, 0, sign * math.rad(elevation))
				* CFrame.new(sign * panel.Length / 2, 0, index * PANEL_STAGGER)
			panel.Part.CFrame = frame
			panel.Edge.CFrame = frame * CFrame.new(0, W.PanelThickness / 2 + 0.07, -panel.Depth / 2 + 0.07)
			panel.Edge.Color = edgeColor
			panel.Edge.Transparency = edgeTransparency
		end
	end
end

function Wings.start()
	folder = Instance.new("Folder")
	folder.Name = "FallWings"
	folder.Parent = workspace.CurrentCamera
	Controller.StateChanged:Connect(function(_from, to)
		snapUntil = os.clock() + Tuning.Wings.SnapTime
		if to == "Burst" then
			burstGlowAt = os.clock()
		end
	end)
	-- After the character's parts are posed for this frame.
	RunService:BindToRenderStep("FallWings", Enum.RenderPriority.Character.Value + 1, update)
end

return Wings
