local config = {}

--- Freight trains
config.enabled = true

-- Can players drive freight trains (required enablePlayingDriving to be enabled in general.lua)
config.enablePlayerDriving = true

--- The freight trains
config.count = 3

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
    -- 3 passenger trains, no freight. Every train now behaves identically:
    -- all stop, all open doors. The freight consist stopped but never opened
    -- doors, which reads as broken to a player who does not know why.
    --
    -- Positions are given as NODE indices, not coordinates. CTrain derives
    -- currentCoords from the node (self.currentCoords = track:getNodeCoords),
    -- so this is exact - no picking points off a map and hoping. Track 0 has
    -- 4226 nodes, so even thirds are 1 / 1410 / 2819.
    --
    -- Spacing matters because station stops only happen for MATERIALISED trains
    -- (the logic lives inside `if self.handle`), so a train near a player loses
    -- dwell time that ghost trains elsewhere do not. 3 trains gives a 7 min
    -- headway against ~200s worst-case drift per lap at a 30s dwell - a wide
    -- enough margin that the dwell regulation can hold it.
    {node = 1,    direction = true, variation = 28, doors = true},   -- Axsellya Express
    {node = 1410, direction = true, variation = 29, doors = true},   -- Brown Streak
    {node = 2819, direction = true, variation = 28, doors = true},   -- Axsellya Express
}



--- The default cruise speed for all default freight trains
-- Single line speed, m/s. 28 ~= 62 mph.
-- Set once at creation; every later change goes through the trainSpeed state
-- bag, and the client's SetTrainSpeed call is commented out - so changes are
-- advisory. One speed means the value is applied at spawn and never needs
-- updating, which avoids that path entirely.
config.speed = 28

return config