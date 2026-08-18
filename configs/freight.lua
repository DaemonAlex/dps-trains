local config = {}

--- Freight trains
config.enabled = true

-- Can players drive freight trains (required enablePlayingDriving to be enabled in general.lua)
config.enablePlayerDriving = true

--- The freight trains
config.count = 3

--- Should Freight trains have a blip on the map
config.showTrainBlips = true

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
    -- TRAINCONFIGS_FILE appends: custom consists live AFTER the 29 vanilla
    -- entries (b3258): vanilla is 0-27 (metro last at 27), customs start at 28.
    -- 28 = passenger_config01, 29 = passenger_config02, 30 = freight_config01. Rotation: two passenger, one freight.
    {coords = vec3(-378.860, 3845.750, 74.095), direction = true, variation = 28, doors = true},  -- passenger (streak coaster)
    {coords = vec3(2592.550, 2141.790, 31.265), direction = true, variation = 29, doors = true},  -- passenger
    {coords = vec3(1260.960, -805.591, 45.301), direction = true, variation = 30, doors = false},  -- freight
}

--- The default cruise speed for all default freight trains
config.speed = 11

return config