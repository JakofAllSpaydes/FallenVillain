--!strict
-- Client entry point.

local Tuning = require(game:GetService("ReplicatedStorage").Shared.Tuning)

local CameraRig = require(script.Camera.CameraRig)
local Controller = require(script.Movement.Controller)
local GroundShadow = require(script.World.GroundShadow)
local ControlsHud = require(script.UI.ControlsHud)
local DevPanel = require(script.UI.DevPanel)
local Reticle = require(script.UI.Reticle)

Controller.start()
CameraRig.start()
Reticle.start()
GroundShadow.start()
ControlsHud.start()

local actions: { DevPanel.Action } = {}
for _, altitude in Tuning.Dev.DropAltitudes do
	table.insert(actions, {
		Label = `Drop {altitude}`,
		Run = function()
			Controller.drop(altitude)
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
