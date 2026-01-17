-- ProfileService-based persistent data with validation, debugging, and leaderstats (basically a simulator game system)
local Players = game:GetService("Players") -- Service to manage players
local RunService = game:GetService("RunService") -- Service for frame-based updates
local ServerStorage = game:GetService("ServerStorage") -- Storage for modules and assets

-- Require ProfileService module from ServerStorage
-- ProfileService handles DataStore management, session locking, etc
local ProfileService = require(ServerStorage:WaitForChild("ProfileService"))

-- Debugging toggle: set to true to enable console debug messages
local DEBUG_ENABLED = true

-- Helper function to log debug info with timestamp
local function debugLog(message)
	if DEBUG_ENABLED then
		print("[DATA DEBUG]", os.time(), message)
	end
end

-- Helper function to log warnings with timestamp
local function debugWarn(message)
	if DEBUG_ENABLED then
		warn("[DATA WARNING]", os.time(), message)
	end
end

-- Default player data template
-- ProfileService will reconcile any missing keys with this structure
local ProfileTemplate = {
	Cash = 100,       -- Player currency
	Level = 1,        -- Player level
	Experience = 0,   -- XP progress toward next level
	PlayTime = 0,     -- Total playtime (in seconds)
	LastLogin = 0     -- Timestamp of last join
}

-- Create ProfileStore using ProfileService
-- Changing the name versions the data
local ProfileStore = ProfileService.GetProfileStore(
	"ProfileService_Validated_V1",
	ProfileTemplate
)

-- Table to track active player profiles in memory
local ActiveProfiles = {}

-- Table to hold runtime-only objects (leaderstats, proxy wrappers)
local RuntimeObjects = {}

-- Validation rules for each field
-- Each function returns true if the new value is valid
local ValidationRules = {
	Cash = function(value)
		-- Must be a non-negative integer
		return typeof(value) == "number" and value >= 0 and value % 1 == 0
	end,
	Level = function(value)
		-- Must be integer >= 1
		return typeof(value) == "number" and value >= 1 and value % 1 == 0
	end,
	Experience = function(value)
		-- Non-negative number allowed
		return typeof(value) == "number" and value >= 0
	end,
	PlayTime = function(value)
		-- Non-negative number allowed
		return typeof(value) == "number" and value >= 0
	end,
	LastLogin = function(value)
		-- Must be integer timestamp
		return typeof(value) == "number" and value >= 0 and value % 1 == 0
	end
}

-- Metatable for controlled access to profile data
-- Intercepts reads and writes to enforce validation
local DataProxy = {}
DataProxy.__index = function(self, key)
	local profile = rawget(self, "_profile") -- Get underlying Profile object
	if profile then
		return profile.Data[key] -- Return the data value
	end
	return nil
end

DataProxy.__newindex = function(self, key, value)
	local profile = rawget(self, "_profile")
	if not profile then return end

	-- Enforce validation rules if defined
	local validator = ValidationRules[key]
	if validator then
		if validator(value) then
			profile.Data[key] = value
			debugLog(string.format("Validated write: %s = %s", key, tostring(value)))
		else
			debugWarn(string.format("Rejected invalid write: %s = %s", key, tostring(value)))
		end
	else
		-- Allow keys without rules (optional fields)
		profile.Data[key] = value
		debugLog(string.format("Write (no validation): %s = %s", key, tostring(value)))
	end
end

-- Creates leaderstats folder and binds IntValues to profile data
local function createLeaderstats(player, profile)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	-- Cash value
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = profile.Data.Cash
	cash.Parent = leaderstats

	-- Level value
	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Value = profile.Data.Level
	level.Parent = leaderstats

	return {Cash = cash, Level = level}
end

-- Sync leaderstats UI values with profile data
local function syncLeaderstats(profile, stats)
	stats.Cash.Value = profile.Data.Cash
	stats.Level.Value = profile.Data.Level
end

-- Load a player profile
local function loadProfile(player)
	-- Attempt to load or force load the profile
	local profile = ProfileStore:LoadProfileAsync(
		"Player_" .. player.UserId,
		"ForceLoad"
	)

	if not profile then
		player:Kick("Failed to load profile data")
		debugWarn("Failed to load profile for player " .. player.Name)
		return
	end

	-- Ensure profile is released if the player leaves unexpectedly
	profile:ListenToRelease(function()
		ActiveProfiles[player] = nil
		player:Kick("Data session ended")
		debugLog("Profile released for " .. player.Name)
	end)

	-- Prevent duplicate sessions
	if not player:IsDescendantOf(Players) then
		profile:Release()
		debugWarn("Player not in Players, profile released immediately")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile() -- Fill missing fields with template

	ActiveProfiles[player] = profile

	-- Wrap profile in a proxy for controlled access
	local proxy = setmetatable({_profile = profile}, DataProxy)
	RuntimeObjects[player] = proxy

	-- Create leaderstats and store runtime reference
	local stats = createLeaderstats(player, profile)
	RuntimeObjects[player .. "_stats"] = stats

	-- Record login timestamp
	proxy.LastLogin = os.time()
	debugLog("Profile loaded for " .. player.Name)
end

-- Release profile safely when player leaves
local function unloadProfile(player)
	local profile = ActiveProfiles[player]
	if profile then
		profile:Release()
		debugLog("Profile released on leave for " .. player.Name)
	end
	ActiveProfiles[player] = nil
	RuntimeObjects[player] = nil
	RuntimeObjects[player .. "_stats"] = nil
end

-- Increment playtime each frame
RunService.Heartbeat:Connect(function(deltaTime)
	for player, profile in pairs(ActiveProfiles) do
		if profile and profile.Data then
			profile.Data.PlayTime += deltaTime
		end
	end
end)

-- Adds cash safely through proxy (server-authoritative)
local function addCash(player, amount)
	local proxy = RuntimeObjects[player]
	if proxy then
		proxy.Cash += amount
		local stats = RuntimeObjects[player .. "_stats"]
		if stats then
			stats.Cash.Value = proxy.Cash
		end
		debugLog(string.format("Added %d cash to %s", amount, player.Name))
	end
end

-- Adds experience and handles leveling
local function addExperience(player, amount)
	local proxy = RuntimeObjects[player]
	if not proxy then return end

	proxy.Experience += amount

	-- Level up if experience exceeds 100
	while proxy.Experience >= 100 do
		proxy.Experience -= 100
		proxy.Level += 1
	end

	local stats = RuntimeObjects[player .. "_stats"]
	if stats then
		stats.Level.Value = proxy.Level
	end
	debugLog(string.format("Added %d XP to %s", amount, player.Name))
end

-- Player event handlers
Players.PlayerAdded:Connect(loadProfile)
Players.PlayerRemoving:Connect(unloadProfile)

-- Ensure all profiles are released if server shuts down
game:BindToClose(function()
	for player, profile in pairs(ActiveProfiles) do
		profile:Release()
	end
	debugLog("All profiles released on server close")
end)

-- Example gameplay simulation
task.spawn(function()
	while true do
		task.wait(10) -- every 10 seconds
		for player in pairs(ActiveProfiles) do
			addCash(player, 5)
			addExperience(player, 10)
		end
	end
end)
