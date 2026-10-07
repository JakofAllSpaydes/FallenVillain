--!strict
-- Hang altitude readout (spec §4.4): one thin number at top center, faded in by FeelTable while hanging. A new
-- best altitude this session pulses gold once with a small "RECORD" under it. Records persist in milestone 5.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Tuning = require(game:GetService("ReplicatedStorage").Shared.Tuning)
local Controller = require(script.Parent.Parent.Movement.Controller)
local Layers = require(script.Parent.Parent.Feel.Layers)

local AltitudeReadout = {}

local layers = Layers.new({ "Altitude", "Record" })
local best = 0

-- Look of the label; not gameplay tuning.
local FONT = Enum.Font.Gotham
local NUMBER_SIZE = 28
local RECORD_SIZE = 14
local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(230, 195, 110)

local number: TextLabel
local record: TextLabel

local function label(parent: Instance, size: number, y: number): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Font = FONT
	item.TextSize = size
	item.TextColor3 = WHITE
	item.TextTransparency = 1
	item.AnchorPoint = Vector2.new(0.5, 0)
	item.Position = UDim2.new(0.5, 0, 0, y)
	item.Size = UDim2.fromOffset(200, size)
	item.Parent = parent
	return item
end

local function withCommas(value: number): string
	local text = tostring(math.floor(value))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

function AltitudeReadout.apply(entry: { [string]: any }, duration: number)
	layers:apply(entry.ui, entry, duration)
end

-- Called when the readout appears: a new best pulses once.
function AltitudeReadout.checkRecord(altitude: number)
	if altitude > best then
		if best > 0 then
			layers:kick("Record", 1, Tuning.Ui.RecordPulseTime)
		end
		best = altitude
	end
end

local function update()
	local ctx = Controller.ctx
	local alpha = layers:get("Altitude")
	local pulse = math.clamp(layers:get("Record"), 0, 1)
	if ctx and alpha > 0.01 then
		number.Text = withCommas(ctx.Altitude)
	end
	number.TextTransparency = 1 - alpha * Tuning.Ui.AltitudeAlpha
	number.TextColor3 = WHITE:Lerp(GOLD, pulse)
	record.TextTransparency = 1 - pulse
end

function AltitudeReadout.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "FallAltitude"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	number = label(gui, NUMBER_SIZE, Tuning.Ui.AltitudeTop)
	record = label(gui, RECORD_SIZE, Tuning.Ui.AltitudeTop + NUMBER_SIZE + 2)
	record.Text = "RECORD"
	record.TextColor3 = GOLD
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	RunService.RenderStepped:Connect(update)
end

return AltitudeReadout
