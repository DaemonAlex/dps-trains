--- NOTE: This file does not store any configuration options.
local ENV = {
    vec = vec,
    vector = vector,
    vec3 = vec3,
    vec4 = vec4,
    vector4 = vec4,
    vec2 = vec2,
    vector2 = vector2,
    vector3 = vector3,
    table = table,

    gameBuild = IsDuplicityVersion() and GetConvarInt("sv_enforceGameBuild", 3258) or GetGameBuildNumber(),
    isServer = IsDuplicityVersion(),

    exports = exports,
    lib = lib
}

--- Load the file in a restricted environment
--- @param path string
local function loadConfigFile(path)
    local file = LoadResourceFile(cache.resource, path)
    local func, err = load(file, ("@@%s/%s"):format(cache.resource, path), "t", ENV)

    if not func or err then
        lib.print.error(("Unable to load config '%s', an error occurred\n^1%s^7"):format(path, err))
        return
    end

    local config = func()

    assert(config, ("Configuration file %s should return the table"):format(path))
    return config
end

local config = {
    general = loadConfigFile("configs/general.lua"),
    cablecar = loadConfigFile("configs/cablecar.lua"),
    freight = loadConfigFile("configs/freight.lua"),
    metro = loadConfigFile("configs/metro.lua")
}

-- don't set any metatables on this. as its done in the scripts
return config