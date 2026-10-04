local config = {}

--- Metro (trams)
--- Will we create metrotrains
config.enabled = true

-- Can player drive metro trains (requires enablePlayerDriving to be enabled in general.lua)
config.enablePlayerDriving = true

--- How many metrotrains can run at once
config.count = 20

--- Should the metro train have a blip on the map
config.showTrainBlips = false  -- DPS: no map blips; the Transit app is the source of truth

--- What blip sprite should be used for the metrotrain
config.trainBlipSprite = 795

--- The size of the sprite on the map
config.trainBlipScale = 1.0

--- The color of the sprite on the map
config.trainBlipColor = 1

--- The name of the blip. Used with map legend
--- nil will fallback to the value of config.general.trainBlipName
config.trainBlipName = "Metro"

--- Refer to https://docs.fivem.net/natives/?_0x9029B2F3DA924928
--- Default: nil
config.trainBlipDisplay = nil

-- If the train blip should be short range
config.trainBlipShortRange = false

--- Should metros bother to stop at stations. If false the metro train will skip all stations and never stop to let passengers in/out
--- This may not function until SET_TRAIN_STOP_AT_STATIONS is merged onto production
config.shouldStopAtStations = true

-- This can either be the track node or a rough coordinate to the node
config.startLocations = {
    -- Both stock spawns sat ~20m apart at Davis, which starts the line bunched.
    -- These are evenly spaced by node index around track 3 (2244 nodes) via
    -- /trainspace 3 3, so the subway runs a real headway from the first lap.
    --
    -- Four trains as of 2026-08-30: quarters are 561 nodes apart, so the whole
    -- set moved rather than squeezing a fourth into an existing gap. Keeping the
    -- spacing exact is what stops the line bunching after a lap or two.
    -- speed is set per train here because config.general.defaultSpeed is 20.1
    -- (45 mph) for the surface lines; the subway runs at the 30 m/s ceiling.
    {coords = vec3(193.196, -603.836, 16.756), direction = true, speed = 20.1},    -- node 1
    {coords = vec3(-174.688, -1217.670, 36.550), direction = true, speed = 20.1},  -- metro 2 (node 749)
    {coords = vec3(-2.146, -1630.470, 28.304), direction = true, speed = 20.1},  -- metro 3 (node 1497)
    -- Mainline = Roxwood regional passenger since 2026-09-15 (variation 32 on build 3095 = rox_passenger_config01, see data/trains.lua).
    {index = 0, variation = 32, coords = vec3(1084.480, 3231.450, 39.256), direction = true, speed = 23.1},  -- MAINLINE regional 1 (track 0)
    {index = 0, variation = 32, coords = vec3(2811.730, 3256.310, 49.762), direction = true, speed = 23.1},  -- MAINLINE regional 2 (track 0)
    {index = 0, variation = 32, coords = vec3(627.972, -1309.900, 20.642), direction = true, speed = 23.1},  -- MAINLINE regional 3 (track 0)
    -- Roxwood passenger line (track 24). Consist 29 = passenger_config02, OUR Brown Streak set (streak + streakcoastercab); the Roxwood models are escrow-encrypted and cannot leave their resource.
    -- Line from south LS to Roxwood, ping-pong. Start points from /trainspace 24 2 (2900 nodes, step 1450). Added 2026-09-05.
    -- UNPARKED 2026-09-21 07:50: /trackprobe now reports 12:on/415, so the line really is in the engine (it never was as 'track 24' - see fxmanifest TRAINTRACK_FILE fix in dps-traintracks).
    {index = 12, variation = 31, coords = vec3(-483.949, 7657.527, 5.363), direction = true, speed = 14.0},  -- ROXWOOD shuttle spawns AT Roxwood station, now node 1 of the cut line: METRO stock (metro_config01 = 2x metrotrain, second flipped) per Damon 2026-09-21 - a single-ended loco shoving its coaches backwards on the return leg looked wrong; metro is double-ended. (node 1, ROXWOOD end) - Damon's pick: starts at Roxwood, reaches the junction ~2.5 min after a boot.
    -- SINGLE-TRACK SHUTTLE: only one train on the Roxwood line (2026-09-21). Old second spawn:
    -- {index = 24, variation = 32, coords = vec3(2687.050, 3055.110, 41.156), direction = true, speed = 20.1},   -- ROXWOOD line 2 (node 1451, Grand Senora)  ON 2026-09-21 (rox_passenger_config01 = 32)
}


--- Should the Metro have a NPC Driver
config.spawnNPCDriver = true

--- What model should the Metro driver have (don't worry this is cleaned up when unused)
config.npcModel = `S_M_M_LSMetro_01`

config.seatAnimDict = "amb@prop_human_seat_chair_mp@male@generic@base"
config.seatAnimName = "base"

-- Seat map rebuilt 2026-09-22 (Damon: "the seating map is all messed up").
-- The old list was 15 seats crammed into a 7m stretch - it covered about a
-- third of the car, so riders bunched in the middle and anyone boarding at an
-- end door was nowhere near a seat. A metrotrain car is roughly 18m, so this
-- runs 9 rows down both walls at 1.6m spacing, facing inward like the old
-- entries did. If any land in a wall, stand on the right spot and run
-- /seatmark - it prints the exact offset to paste in here.
config.seatOffsets = {
    vec4(-0.92, 6.40, 1.0, 270.0),
    vec4( 0.92, 6.40, 1.0,  90.0),
    vec4(-0.92, 4.80, 1.0, 270.0),
    vec4( 0.92, 4.80, 1.0,  90.0),
    vec4(-0.92, 3.20, 1.0, 270.0),
    vec4( 0.92, 3.20, 1.0,  90.0),
    vec4(-0.92, 1.60, 1.0, 270.0),
    vec4( 0.92, 1.60, 1.0,  90.0),
    vec4(-0.92, 0.00, 1.0, 270.0),
    vec4( 0.92, 0.00, 1.0,  90.0),
    vec4(-0.92, -1.60, 1.0, 270.0),
    vec4( 0.92, -1.60, 1.0,  90.0),
    vec4(-0.92, -3.20, 1.0, 270.0),
    vec4( 0.92, -3.20, 1.0,  90.0),
    vec4(-0.92, -4.80, 1.0, 270.0),
    vec4( 0.92, -4.80, 1.0,  90.0),
    vec4(-0.92, -6.40, 1.0, 270.0),
    vec4( 0.92, -6.40, 1.0,  90.0),
}

config.seatResetCoords = {
    vec4(0.007265, 1.319092, 0.6, 2.904224),
    vec4(0.007265, 1.319092, 0.6, 2.904224),

    vec4(-0.014481, 1.565186, 1.565849, 357.674622),
    vec4(-0.014481, 1.565186, 1.565849, 357.674622),

    vec4(-0.011662, 0.854614, 1.565826, 0.146208),
    vec4(-0.011662, 0.854614, 1.565826, 0.146208),

    vec4(-0.003204, 0.104004, 1.565804, 3.082657),
    vec4(-0.003204, 0.104004, 1.565804, 3.082657),

    vec4(0.019968, -0.617310, 1.565777, 1.721481),
    vec4(0.019968, -0.617310, 1.565777, 1.721481),

    vec4(0.029971, -1.534302, 1.565746, 6.884667),
    vec4(0.029971, -1.534302, 1.565746, 6.884667),

    vec4(0.022483, -3.788452, 1.565639, 1.080160),
    vec4(0.022483, -3.788452, 1.565639, 1.080160),

    vec4(-0.028672, -4.713623, 1.565540, 359.732819),
    vec4(-0.028672, -4.713623, 1.565540, 359.732819)
}

--- Set's the track index used for metros defined in config.metro.startLocations
config.trackIndex = 3

--- 24 is the index in 1604. Future gamebuilds add variations before the metro train so we just increment it
local metroVariation = 24

if gameBuild >= 2372 then
    metroVariation += 1
end

if gameBuild >= 2802 then
    metroVariation += 1
end

if gameBuild >= 3095 then
    metroVariation += 1
end

if gameBuild >= 3407 then
    metroVariation += 1
end

--- The Metro train config variation. This can vary between gamebuilds or if trains.xml is modified.
--- Be aware, putting an invalid variation index will crash clients if not on canary.
-- TRAINCONFIGS_FILE *appends* custom consists after the vanilla table - it
-- does not replace it. Vanilla metro on this build is the computed index above;
-- the custom consists start at 29 (vanilla 0-28 on b3258).
config.variation = metroVariation

--- Should the metrotrain ignore any obstructions on the track and continue through it
--- Obstructions such as vehicles (that aren't trains, bikes or submarines), players, objects etc
--- Depends on client having SET_VEHICLE_FLAG available
config.ignoreObstructions = false

return config