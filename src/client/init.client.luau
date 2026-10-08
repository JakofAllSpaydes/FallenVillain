--!strict
-- Client entry point.

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Tuning = require(game:GetService("ReplicatedStorage").Shared.Tuning)

local AltitudeReadout = require(script.UI.AltitudeReadout)
local CashReadout = require(script.UI.CashReadout)
local ComboBanner = require(script.UI.ComboBanner)
local Damage = require(script.Feel.Damage)
local Destruction = require(script.Feel.Destruction)
local FloatingNumbers = require(script.UI.FloatingNumbers)
local Haptics = require(script.Feel.Haptics)
local Smash = require(script.Combat.Smash)
local Blaster = require(script.Combat.Blaster)
local BlastWheel = require(script.UI.BlastWheel)
local XpBar = require(script.UI.XpBar)
local Net = require(game:GetService("ReplicatedStorage").Shared.Net)
local Toasts = require(script.UI.Toasts)
local Anim = require(script.Feel.Anim)
local AtmosphereDriver = require(script.World.AtmosphereDriver)
local DayCycle = require(script.World.DayCycle)
local Audio = require(script.Feel.Audio)
local CameraRig = require(script.Camera.CameraRig)
local Controller = require(script.Movement.Controller)
local GroundShadow = require(script.World.GroundShadow)
local Hints = require(script.UI.Hints)
local Juice = require(script.Feel.Juice)
local Music = require(script.Feel.Music)
local Pulse = require(script.Feel.Pulse)
local JumpWheel = require(script.UI.JumpWheel)
local Post = require(script.Feel.Post)
local PunchWheel = require(script.UI.PunchWheel)
local RemotePlayers = require(script.World.RemotePlayers)
local Vfx = require(script.Feel.Vfx)
local ControlsHud = require(script.UI.ControlsHud)
local DevPanel = require(script.UI.DevPanel)
local Drivers = require(script.Feel.Drivers)
local Reticle = require(script.UI.Reticle)
local TouchControls = require(script.Movement.TouchControls)

Controller.start()
TouchControls.start()
CameraRig.start()
Reticle.start()
GroundShadow.start()
ControlsHud.start()
Audio.start()
Music.start()
Haptics.start()
Post.start()
Vfx.start()
AltitudeReadout.start()
PunchWheel.start()
BlastWheel.start()
JumpWheel.start()
Juice.start()
Drivers.start()
Anim.start()
Pulse.start()
Hints.start()
DayCycle.start()
AtmosphereDriver.start()
RemotePlayers.start()
Smash.start()
Blaster.start()
Damage.start()
Destruction.start()
CashReadout.start()
XpBar.start()
ComboBanner.start()
Toasts.start()
FloatingNumbers.start()

-- Studio test aid: F4 smashes the ground under the player at Dev.TestSmashSpeed.
if RunService:IsStudio() then
	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.F4 and not UserInputService:GetFocusedTextBox() then
			Controller.testSmash()
		end
	end)
end

local actions: { DevPanel.Action } = {}
for _, altitude in Tuning.Dev.DropAltitudes do
	table.insert(actions, {
		Label = `Drop {altitude}`,
		Run = function()
			Controller.drop(altitude)
		end,
	})
end
-- Level jumps for testing the progression (the server honours these in Studio only).
for _, delta in { Tuning.Dev.LevelStep, -Tuning.Dev.LevelStep } do
	table.insert(actions, {
		Label = if delta > 0 then `Level +{delta}` else `Level {delta}`,
		Run = function()
			Net.event("DevLevel"):FireServer(delta)
		end,
	})
end
DevPanel.start({
	Actions = actions,
	OnToggle = function(open)
		CameraRig.setMouseLookEnabled(not open)
		Reticle.setVisible(not open)
	end,
})
