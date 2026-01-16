local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local DAY_LENGTH = 180
local WEATHER_TYPES = {"Sunny","Rain","Snow"}
local WEATHER_CHANGE_INTERVAL = 45
local TWEEN_TIME = 3

local LIGHTING_PRESETS = {
	Day = {ClockTime=9, Brightness=2, FogEnd=1000, Ambient=Color3.fromRGB(220,220,220)},
	Afternoon = {ClockTime=15, Brightness=1.8, FogEnd=900, Ambient=Color3.fromRGB(200,180,160)},
	Night = {ClockTime=21, Brightness=0.8, FogEnd=500, Ambient=Color3.fromRGB(50,50,70)}
}

local WEATHER_PRESETS = {
	Sunny = {BrightnessOffset=0,FogOffset=0,AmbientOffset=Color3.new(0,0,0)},
	Rain = {BrightnessOffset=-0.3,FogOffset=-100,AmbientOffset=Color3.new(-0.1,-0.1,-0.1)},
	Snow = {BrightnessOffset=-0.1,FogOffset=-50,AmbientOffset=Color3.new(0.05,0.05,0.05)}
}

local WeatherSystem = {}
WeatherSystem.__index = WeatherSystem

function WeatherSystem.new()
	local self = setmetatable({}, WeatherSystem)
	self.Time = 0
	self.DayPhase = "Day"
	self.CurrentWeather = "Sunny"
	self.NextWeatherChange = WEATHER_CHANGE_INTERVAL
	self.PresetCache = {}
	self.CurrentClock = 0
	self.CurrentBrightness = 0
	self.CurrentFogEnd = 0
	self.CurrentAmbient = Color3.new(0,0,0)
	self.TargetClock = 0
	self.TargetBrightness = 0
	self.TargetFogEnd = 0
	self.TargetAmbient = Color3.new(0,0,0)
	self.Ratio = 0
	self.LerpSpeed = 0.01
	return self
end

function WeatherSystem:incrementTime(dt)
	self.Time = self.Time + dt
	if self.Time >= DAY_LENGTH then
		self.Time = self.Time - DAY_LENGTH
	end
end

function WeatherSystem:updateDayPhase()
	self.Ratio = (self.Time % DAY_LENGTH)/DAY_LENGTH
	if self.Ratio < 0.33 then
		self.DayPhase = "Day"
	elseif self.Ratio < 0.66 then
		self.DayPhase = "Afternoon"
	else
		self.DayPhase = "Night"
	end
end

function WeatherSystem:getPreset()
	local preset = LIGHTING_PRESETS[self.DayPhase]
	local weatherOffset = WEATHER_PRESETS[self.CurrentWeather]
	self.TargetClock = preset.ClockTime
	self.TargetBrightness = preset.Brightness + weatherOffset.BrightnessOffset
	self.TargetFogEnd = preset.FogEnd + weatherOffset.FogOffset
	self.TargetAmbient = Color3.new(
		preset.Ambient.R + weatherOffset.AmbientOffset.R,
		preset.Ambient.G + weatherOffset.AmbientOffset.G,
		preset.Ambient.B + weatherOffset.AmbientOffset.B
	)
end

function WeatherSystem:lerpValues()
	self.CurrentClock = self.CurrentClock + (self.TargetClock - self.CurrentClock)*self.LerpSpeed
	self.CurrentBrightness = self.CurrentBrightness + (self.TargetBrightness - self.CurrentBrightness)*self.LerpSpeed
	self.CurrentFogEnd = self.CurrentFogEnd + (self.TargetFogEnd - self.CurrentFogEnd)*self.LerpSpeed
	self.CurrentAmbient = Color3.new(
		self.CurrentAmbient.R + (self.TargetAmbient.R - self.CurrentAmbient.R)*self.LerpSpeed,
		self.CurrentAmbient.G + (self.TargetAmbient.G - self.CurrentAmbient.G)*self.LerpSpeed,
		self.CurrentAmbient.B + (self.TargetAmbient.B - self.CurrentAmbient.B)*self.LerpSpeed
	)
end

function WeatherSystem:applyLighting()
	Lighting.ClockTime = self.CurrentClock
	Lighting.Brightness = self.CurrentBrightness
	Lighting.FogEnd = self.CurrentFogEnd
	Lighting.Ambient = self.CurrentAmbient
end

function WeatherSystem:updateWeather(dt)
	self.NextWeatherChange = self.NextWeatherChange - dt
	if self.NextWeatherChange <= 0 then
		local nextWeather = WEATHER_TYPES[math.random(1,#WEATHER_TYPES)]
		self.CurrentWeather = nextWeather
		self.NextWeatherChange = WEATHER_CHANGE_INTERVAL
	end
end

function WeatherSystem:runStep(dt)
	self:incrementTime(dt)
	self:updateDayPhase()
	self:getPreset()
	self:lerpValues()
	self:applyLighting()
	self:updateWeather(dt)
end

function WeatherSystem:runLoop(dt)
	for i=1,5 do
		self:runStep(dt/5)
	end
end

local system = WeatherSystem.new()

RunService.Heartbeat:Connect(function(dt)
	system:runLoop(dt)
end)

function WeatherSystem:debuggingandPrint()
	print("Time:",math.floor(self.Time))
	print("DayPhase:",self.DayPhase)
	print("Weather:",self.CurrentWeather)
	print("Clock:",self.CurrentClock)
	print("Brightness:",self.CurrentBrightness)
	print("FogEnd:",self.CurrentFogEnd)
	print("Ambient:",self.CurrentAmbient)
end

function WeatherSystem:simulateExtraSteps(dt)
	for i=1,3 do
		self:runStep(dt/3)
	end
end

function WeatherSystem:fullUpdate(dt)
	self:simulateExtraSteps(dt)
	self:runStep(dt)
	self:debuggingandPrint()
end

RunService.Heartbeat:Connect(function(dt)
	system:fullUpdate(dt)
end)

for i=1,3 do
	RunService.Heartbeat:Connect(function(dt)
		system:runStep(dt/2)
	end)
end

for i=1,2 do
	RunService.Heartbeat:Connect(function(dt)
		system:runLoop(dt/3)
	end)
end

function WeatherSystem:computeRatio()
	local r = (self.Time % DAY_LENGTH)/DAY_LENGTH
	return r
end

function WeatherSystem:updatePhaseByRatio()
	local r = self:computeRatio()
	if r < 0.33 then
		self.DayPhase = "Day"
	elseif r < 0.66 then
		self.DayPhase = "Afternoon"
	else
		self.DayPhase = "Night"
	end
end

function WeatherSystem:updateLightingValues()
	local preset = LIGHTING_PRESETS[self.DayPhase]
	local weather = WEATHER_PRESETS[self.CurrentWeather]
	self.TargetClock = preset.ClockTime
	self.TargetBrightness = preset.Brightness + weather.BrightnessOffset
	self.TargetFogEnd = preset.FogEnd + weather.FogOffset
	self.TargetAmbient = Color3.new(
		preset.Ambient.R + weather.AmbientOffset.R,
		preset.Ambient.G + weather.AmbientOffset.G,
		preset.Ambient.B + weather.AmbientOffset.B
	)
end

function WeatherSystem:applyAllLighting()
	Lighting.ClockTime = self.CurrentClock
	Lighting.Brightness = self.CurrentBrightness
	Lighting.FogEnd = self.CurrentFogEnd
	Lighting.Ambient = self.CurrentAmbient
end

function WeatherSystem:runExtraSteps(dt)
	self:updatePhaseByRatio()
	self:updateLightingValues()
	self:lerpValues()
	self:applyAllLighting()
	self:updateWeather(dt)
end

RunService.Heartbeat:Connect(function(dt)
	system:runExtraSteps(dt)
end)
