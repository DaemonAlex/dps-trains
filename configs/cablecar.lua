local config = {}

--- Cable cars (requires Ehbw-Cablecars)
--- Should cablecars be enabled. Disabled if Ehbw-Cablecars is missing regardless of config value
config.enabled = false  -- needs Ehbw-Cablecars (absent); variation 28 is out of range and would crash clients

config.variation = 16

config.count = 2

--- Should Freight trains have a blip on the map
config.showTrainBlips = true

--- What blip sprite should be used for freight trains
config.trainBlipSprite = 36

--- The size of the sprite on the map
config.trainBlipScale = 1.0

--- The color of the sprite on the map
config.trainBlipColor = 15

--- Refer to https://docs.fivem.net/natives/?_0x9029B2F3DA924928
--- Default: nil
config.trainBlipDisplay = nil

config.trainBlipName = "Cablecar"

--- Only coordinates, direction, speed and trackIndex can be modified here
config.startLocations = {
    {coords = vec3(-740.911, 5599.0, 47.25), direction = true, index = 13},
    {coords = vec3(-741.2000, 5590.691, 47.27551), index = 12}
}

return config