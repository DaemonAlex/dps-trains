local config = {}

--- Freight trains
config.enabled = true

-- Can players drive freight trains (required enablePlayingDriving to be enabled in general.lua)
config.enablePlayerDriving = true

--- The freight trains
config.count = 4

--- Should Freight trains have a blip on the map
config.showTrainBlips = false  -- DPS: no map blips; the Transit app is the source of truth

--- What blip sprite should be used for freight trains
config.trainBlipSprite = 795

--- The size of the sprite on the map
config.trainBlipScale = 1.0

--- The color of the sprite on the map
config.trainBlipColor = 0

--- Refer to https://docs.fivem.net/natives/?_0x9029B2F3DA924928
--- Default: nil
config.trainBlipDisplay = nil

-- If the train blip should be shortrange
config.trainBlipShortRange = false

-- Should freight trains have NPC drivers
config.spawnNPCDriver = true

--- What model should the driver have (don't worry this is cleaned up when unused)
config.npcModel = `S_M_M_LSMetro_01`

-- TRACK index these trains run on (0 = main line). NOT the consist variation -
-- the upstream comment calling this Train variation is wrong; cablecar.lua uses
-- index 12/13 for the cablecar tracks.
config.index = 0

--- The name of the blip. Used with map legend
--- nil will fallback to the default blip name
config.trainBlipName = "Train"

--- Should freight trains bother to stop at stations defined on the track (there is only one in base GTA 5, At the power station)
--- If false the trains will never stop at this (or other defined) stations 
config.shouldStopAtStations = true

config.startLocations = {
    -- VANILLA consist variations only. 15 and 20 are the two the upstream Ehbw
    -- resource ships with, so they are known to exist in the base game's table
    -- and are proven in the wild. Anything above 27 requires a registered
    -- TRAINCONFIGS_FILE, and an index the game does not have crashes the client
    -- outright rather than failing gracefully.
    --
    -- Spawn points are chosen by NODE INDEX via the /trainspace command, not by
    -- picking depots off the map. Track 0 is 4226 nodes and folds back on
    -- itself, so map distance is not sequence distance, and it is sequence
    -- distance that decides how often a train reaches a platform.
    --
    -- doors = false: these are freight consists with no door components.
    {coords = vec3(1084.480, 3231.450, 39.256), direction = true, variation = 15, doors = false},  -- node 1    Sandy Shores
    {coords = vec3(2580.920, 5572.750, 60.652), direction = true, variation = 20, doors = false},  -- node 1057 north east
    {coords = vec3(2104.020, -680.388, 95.890), direction = true, variation = 15, doors = false},  -- node 2113 east LS
    {coords = vec3(1914.500, 2152.840, 61.154), direction = true, variation = 20, doors = false},  -- node 3697 Grapeseed
}



--- The default cruise speed for all default freight trains
config.speed = 11

return config