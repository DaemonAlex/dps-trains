local config = {}

-- A fallback list if a train variation is not loaded in data/tracks.lua.
-- You should aim to add all train models in your server.
config.trainModels = {
    -- MUST match what [dps]/dps-trains-stock actually streams.
    -- client/main.lua falls back to this whole list when a variation is
    -- not in its per-variation table, and loadModels blocks on each entry
    -- until it times out. Listing a model the server does not ship makes
    -- every train creation exceed the server's 10s window, which surfaces
    -- as "failed to create train in time" with no other error.
    -- The stock pack shipped 30 models; only these are streamed now.
    `freightcaboose`,
    `freightflat`,
    `freightflatlogs`,
    `freightgondola`,
    `freighttanklong`,
    `sd70mac`,
    `streak`,
    `streakc`,
    `streakcab`,
    `streakcoaster`,
    `metrotrain`,
}

if not isServer then
    -- Include freightcar2 if exists (added in b2372)
    if gameBuild >= 2372 then
        config.trainModels[#config.trainModels+1] = `freightcar2`
    end

    -- Include freightcar3 if exists (added in b3407)
    if gameBuild >= 3407 then
        config.trainModels[#config.trainModels+1] = `freightcar3`
    end
end

--- DEVELOPMENT OPTION 
--- Should we enable the parser. This is used to generate track data for the server to consume. Needed if you have custom addon tracks
config.enableParser = true

--- SHOULD BE TREATED AS A DEVELOPMENT OPTION
--- Should commands such as /driveTrain be enabled 
--- This allows for easy use of certain features or to ensure features work as intended on your server
--- List of example commands (and their usage)
--- /driveTrain (attempts to drive the closest train)
--- /setTrainSpeed <trainId> <speed> Sets the speed of the specified train ID (default: group.admin)
--- /sitInSeat <index> Sits the player in the seat index of the metro they are riding
config.enableExampleCommands = true

--- WARNING: cruise speeds above 30 *will* cause issues with remote (other) clients
--- This allows for player driven trains to well exceed the 30 (67ish mph) speed limit imposed by game limitation
config.unlimitSpeed = false

-- Tracks that trains should not even attempt to spawn on
config.disabledTracks = {1, 2, 4, 5, 6, 7, 8, 9, 10, 11}

-- Tracks that used be used for the server, used with getClosestTrackAndNode exports
config.usedTracks = {0, 3}

-- Allows players to drive trains. By default all trains can be driven (metro and freight), however this can be changed.
config.enablePlayerDriving = true

-- Should we create the entity directly on the server. This will only work when train server-setters get implemented
-- This is required for entity lockdown and is automatically enabled (if the artifact version contains train server-setters)
-- When implemented, this removes all requirements for a client to create the train, this should resolve several issues
config.useServerSetter = false

config.playerControls = {
    ['forward'] = 71,
    ['backward'] = 72,
    ['handbrake'] = 76,
    ['leftDoors'] = 63,
    ['rightDoors'] = 64
}

--- Every 100ms the speed will increase/decrease based on the values below if one of the buttons is actively being pressed
config.playerDrivingAcceleration = {
    ['acceleration'] = 0.6,
    ['breaking'] = 0.3,
}

--- Should we use a bridge to support 3rd party resources such as ox_target?
config.enableBridge = true

--- Which bridges should be used.
--- NOTE: This must be the resource's name and the bridge file must also match.
config.enabledBridges = {
    'ox_target'
    --'sleepless-interact' -- WIP
}

-- Disables improvements to trains that help them in most scenarios. 
---Only disable if you are having issues with train spawning or anticheat conflicts
config.disableTrainFixes = false

-- Should we look for and identify rouge trains (e.g. trains that aren't from this resource, or are messed up in some way)
-- Set this to false if you have another script that spawns trains as this will remove those
-- This functionality is disabled on the server-side pending 
--- Models that must NEVER be treated as rouge trains.
--- GetVehicleType() reports "train" for the GTA cable car, so both the
--- entityCreating block and the rouge sweeps would otherwise cancel its
--- creation and then delete it - which is exactly what killed rtx_cablecar
--- under the previous train script. Add any third-party train-type model here.
config.protectedTrainModels = {
    `cablecar`,
}

--- Resources whose train entities are left alone entirely.
--- Any entity created while one of these is the owner is exempt.
config.protectedTrainResources = {
    'rtx_cablecar',
}

config.purgeRougeTrains = true

-- Should we deny clients from being able to create any train entities unless they have the right to (they are a chosen candidate of one or more trains that they are trying to create)
-- This listens to entityCreating, which is a frequently called event for small and big servers (triggered on any client-created network entity)
-- While this shouldn't have any noticeable performance impact. This can still be disabled if you believe it is impacting server performance
config.blockCreationOfNonScriptOwnedTrains = true

-- Toggles the behavior of SET_TRAINS_FORCE_DOORS_OPEN
-- GTA:O default is true. 
config.openDoorsWhenInsideTrain = false

-- How often should we check for rouge trains on the server side (this is more intensive as it checks all networked vehicles and not just relevant)
config.svRougeInterval = 60000

-- How often should we check for rouge trains on the client side
config.clRougeInterval = 60000

-- How close should a player be before we recreate the train entity for them (Max is 424.f)
config.recreateTrainDistance = 400.0

-- Use the high precision net blender. Can help in some situations, not too much harm in having this enabled
config.useHighPrecisionBlending = true

--- Should each train show blips
config.showTrainBlips = false  -- DPS: map decluttered; station blips (short-range) remain

--- How long a train holds at each station before departing (ms). DPS: 1 minute.
-- 10s. Long enough to board if you are waiting on the platform, short enough
-- that a stopped train does not read as broken.
--
-- It is also the main lever on train spacing. Station stops only happen for
-- MATERIALISED trains (the logic sits inside `if self.handle`), so a train near
-- a player loses this much time per station while ghost trains elsewhere run
-- non-stop. Across 10 mainline stations that divergence is:
--     60s dwell -> 10   min drift per lap
--     30s dwell ->  5   min
--     10s dwell ->  1.7 min
-- At 1.7 min the dwell regulation in server/main.lua can actually correct the
-- drift; at 10 min it never could.
config.stationDwellTime = 30000

--- The sprite for the train blip
config.trainBlipSprite = 795

-- The color for the train blip
config.trainBlipColor = 0

-- The scale for the train blip
config.trainBlipScale = 1.0

-- The name of the blip on the map legend
config.trainBlipName = "Train"

-- If the train blip should be shortrange
config.trainBlipShortRange = false

--- Refer to https://docs.fivem.net/natives/?_0x9029B2F3DA924928
--- Default: nil
config.trainBlipDisplay = nil

--- What ace permission should commands be restricted to 
config.adminCommandGroup = "group.admin"

--- Should the train entity be deleted if the owner is too far. Default: false
--- There are instances where with orphan mode the train can exist on the owner permanently causing ownership transfer issues
--- This is ignored if useServerSetter is enabled
config.shouldDeleteTrainIfFarAway = true

--- Only used if shouldDeleteTrainIfFarAway is enabled. Ignored with server-setter trains
--- Technically the onesync scope distance is 424. However trains can exceed this massively.
config.deleteDistance = 500.0

--- The default speed of metro and trains, between 0 - 30
--- Trains cannot have a negative speed without having a negative effect for remote (other) players
--- Trains also cannot have a speed above 30 without potentially desynchronizing between clients (as 30.f is the max cruiseSpeed value in CTrainGameStateDataNode)
config.defaultSpeed = 30  -- m/s (~67mph). This is the HARD ceiling: 30.0 is the max
-- cruiseSpeed representable in CTrainGameStateDataNode, so anything above it
-- desyncs trains between clients regardless of unlimitSpeed. server/main.lua
-- reads THIS value (freight.speed or config.general.defaultSpeed), NOT
-- config.freight.speed - setting that one has no effect.

--- Candidate Selection options (only used when server-setters are disabled)
--- Should the best candidate (those within config.recreateTrainDistance or 424.0 units of the trains respawn location)
--- be selected based on the lowest ping
config.selectBestCandidateByPing = false

--- How long (in milliseconds) should a blocked client be blocked for 
config.unblockBadCandidatesAfterTime = 20000

--- Should logs related to candidate abdication be a debug print or warn?
config.warnOnCandidateAbdication = true

--- Used for third party support for certain elements of the resource
---@param text string
config.showTextHelp = function (text)
    lib.showTextUI(text)
end

config.clearTextHelp = function()
    lib.hideTextUI()
end

return config