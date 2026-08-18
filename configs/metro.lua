local config = {}

--- Metro (trams)
--- Will we create metrotrains
config.enabled = true

-- Can player drive metro trains (requires enablePlayerDriving to be enabled in general.lua)
config.enablePlayerDriving = true

--- How many metrotrains can run at once
config.count = 2

--- Should the metro train have a blip on the map
config.showTrainBlips = true

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
    {coords = vec3(282.394, -1194.563, 37.101), direction = true},
    {coords = vec3(281.678, -1214.649, 37.130), direction = true}
}

--- Should the Metro have a NPC Driver
config.spawnNPCDriver = true

--- What model should the Metro driver have (don't worry this is cleaned up when unused)
config.npcModel = `S_M_M_LSMetro_01`

config.seatAnimDict = "amb@prop_human_seat_chair_mp@male@generic@base"
config.seatAnimName = "base"

config.seatOffsets = {
    vec4(-0.886257, 2.306824, 1.0, 269.807465),
    vec4(0.901825, 2.144073, 1.0, 90.463196),
    vec4(-0.897377, 1.445557, 1.0, 271.888855),
    vec4(0.812458, 1.499298, 1.0, 89.758827),
    vec4(-0.957165, 0.527008, 1.0, 272.062347),
    vec4(0.915848, 0.772308, 1.0, 89.411926),
    vec4(0.818874, -0.006226, 1.0, 90.799545),
    vec4(-0.825672, -0.976959, 1.0, 271.097748),
    vec4(0.870419, -0.776703, 1.0, 90.712807),
    vec4(-0.926239, -1.626373, 1.0, 269.796875),
    vec4(0.813835, -1.547729, 1.0,  88.794296),
    vec4(-0.925842, -3.851990, 1.0, 266.057251),
    vec4(0.832500, -3.824921, 1.0, 88.967751),
    vec4(-0.905621, -4.834839, 1.0, 269.786377),
    vec4(0.863285, -4.728607, 1.0, 90.615524)
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