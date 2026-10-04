local config = {}

--- Freight trains
config.enabled = false  -- docks land on track 0 (mainline); need real dock siding track

-- Can players drive freight trains (required enablePlayingDriving to be enabled in general.lua)
config.enablePlayerDriving = true

--- The freight trains
config.count = 6

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
    -- 6 passenger trains, alternating the two consists. No freight - every
    -- train stops and opens doors.
    --
    -- Positions are NODE indices, not coordinates: CTrain derives currentCoords
    -- from the node, so spacing is exact. Track 0 has 4226 nodes, so even
    -- sixths are 704 apart.
    --
    -- Headway:
    --     running        29,680 m at 30 m/s = 16.5 min
    --     10 stops @30s                     =  5.0 min
    --     effective loop                    = 21.5 min
    --     / 6 trains                        = ~3.6 min between trains
    --
    -- Six holds its spacing because ghost and materialised trains now run the
    -- SAME schedule physics (2026-08-28, server/CTrain.lua):
    --   * ghosts advance at the zone cruise (28), observe station dwells AND
    --     headway holds, and pay a brake/accel penalty per stop like a real
    --     train does;
    --   * every stop - ghost or materialised - sets a gap-regulated dwell
    --     (bunched trains hold up to 2x, gapped trains cut to 0.4x), so the
    --     fleet self-spaces continuously, not just when someone is watching.
    -- Check the line's health any time with `traindebug` in the server
    -- console: the per-track gap table should sit near the ideal (704 here).
    -- DOCK FREIGHT: default consist (variation 0), slow (10 mph = ~4.5 m/s), no passenger doors.
    {coords = vec3(692.36, -2678.37, 10.76), direction = true, variation = 0, speed = 4.5, doors = false}, -- dock route 1 A
    {coords = vec3(-8.09, -2582.12, 6.01),  direction = true, variation = 0, speed = 4.5, doors = false}, -- dock route 1 B
    {coords = vec3(877.39, -3248.93, 5.88), direction = true, variation = 0, speed = 4.5, doors = false}, -- dock route 2 A
    {coords = vec3(221.80, -2818.49, 6.10), direction = true, variation = 0, speed = 4.5, doors = false}, -- dock route 2 B
}





--- The default cruise speed for all default freight trains
-- Single line speed, m/s. 28 ~= 62 mph.
-- Set once at creation; every later change goes through the trainSpeed state
-- bag, and the client's SetTrainSpeed call is commented out - so changes are
-- advisory. One speed means the value is applied at spawn and never needs
-- updating, which avoids that path entirely.
config.speed = 28

return config