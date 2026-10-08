--!strict
-- Haptics (spec §4.1, §4.2, §4.6–4.8): a FeelTable sink. Entries `{ haptic = "Rumble", kick = 0–1, dur, curve }`
-- kick a layer; each frame the summed value drives the large motor of every vibrating input the device has
-- (a gamepad, or the phone itself on touch devices), with the small motor at a share of it. Nothing here
-- runs without a supported device, so desktop pays nothing.

local HapticService = game:GetService("HapticService")
local RunService = game:GetService("RunService")

local Tuning = require(game:GetService("ReplicatedStorage").Shared.Tuning)
local Layers = require(script.Parent.Layers)

local Haptics = {}

local layers = Layers.new({ "Rumble" })
local devices: { Enum.UserInputType } = {}
local last = -1

function Haptics.apply(entry: { [string]: any }, duration: number)
	layers:apply(entry.haptic, entry, duration)
end

local function update()
	local value = math.clamp(layers:get("Rumble"), 0, 1)
	if math.abs(value - last) < 0.01 then
		return
	end
	last = value
	local H = Tuning.Haptics
	for _, device in devices do
		pcall(HapticService.SetMotor, HapticService, device, Enum.VibrationMotor.Large, value)
		pcall(HapticService.SetMotor, HapticService, device, Enum.VibrationMotor.Small, value * H.SmallShare)
	end
end

function Haptics.start()
	for _, device in { Enum.UserInputType.Gamepad1, Enum.UserInputType.Touch } do
		local ok, supported = pcall(HapticService.IsVibrationSupported, HapticService, device)
		if ok and supported then
			table.insert(devices, device)
		end
	end
	if #devices == 0 then
		return
	end
	RunService.RenderStepped:Connect(update)
end

return Haptics
