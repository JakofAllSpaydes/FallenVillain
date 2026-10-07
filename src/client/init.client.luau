--!strict
-- Client entry point.

local Tuning = require(game:GetService("ReplicatedStorage").Shared.Tuning)

local AltitudeReadout = require(script.UI.AltitudeReadout)
local AtmosphereDriver = require(script.World.AtmosphereDriver)
local Audio = require(script.Feel.Audio)
local CameraRig = require(script.Camera.CameraRig)
local Controller = require(script.Movement.Controller)
local GroundShadow = require(script.World.GroundShadow)
local Juice = require(script.Feel.Juice)
local Post = require(script.Feel.Post)
local RemotePlayers = require(script.World.RemotePlayers)
local Vfx = require(script.Feel.Vfx)
local ControlsHud = require(script.UI.ControlsHud)
local DevPanel = require(script.UI.DevPanel)
local Reticle = require(script.UI.Reticle)

Controller.start()
CameraRig.start()
Reticle.start()
GroundShadow.start()
ControlsHud.start()
Audio.start()
Post.start()
Vfx.start()
AltitudeReadout.start()
Juice.start()
AtmosphereDriver.start()
RemotePlayers.start()

local actions: { DevPanel.Action } = {}
for _, altitude in Tuning.Dev.DropAltitudes do
	table.insert(actions, {
		Label = `Drop {altitude}`,
		Run = function()
			Controller.drop(altitude)
		end,
	})
end
table.insert(actions, {
	Label = "Full charge",
	Run = Controller.fillCharge,
})
for _, power in Tuning.Dev.PowerPresets do
	table.insert(actions, {
		Label = `Power {power}`,
		Run = function()
			Controller.setPower(power)
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
