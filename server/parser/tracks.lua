local config = require "config"
setmetatable(config, nil)

if not config.general.enableParser then
    return
end

local gmatch = string.gmatch

---@param str string
---@return table
local function splitLine(str)
    local r = {}
    for value in gmatch(str, "%S+") do
        r[#r+1] = value
    end
    return r
end
---@param f any
---@param fileName number
local function parseNodeFile(f, fileName)
    local numNodes = f:read("l")
    local nodes = {}

    local stations = {}

    while true do
        local line = f:read("l")
        if line == nil then
            break
        end
        local value = splitLine(line)
        nodes[#nodes+1] = {coords = vec3(tonumber(value[1]), tonumber(value[2]), tonumber(value[3])), station = tonumber(value[4] or "0")}
    end

    local output = ""
    local function write(data)
        output = output .. data
    end

    write("return {\n")
    write("    name = \"main freight line\",\n")
    write(("    numNodes = %i,\n"):format(numNodes))
    write("    nodes = {\n")

    for i=1, #nodes do
        local node = nodes[i]
        -- there looks to be a bitmask for train nodes that have tunnels. Toggle's behaviour in game code todo with tunnel/interiors
        -- We don't need this on the server side so remove the flag and check if there's also a station
        if node.station & (1 << 2) == (1 << 2) then
            node.station &= ~(1 << 2)
        end

        if node.station == 1 or node.station == 2 then
            node.node = i
            stations[#stations+1] = node
        end

        write(("        vec(%.4f, %.4f, %.4f),\n"):format(node.coords.x, node.coords.y, node.coords.z))
    end
    write(("    }%s"):format((#stations == 0 and "\n}" or ",\n")))

    if #stations > 0 then
        write("    stations = {\n")
        for i=1, #stations do
            local station = stations[i]
            write(("        { coords = vec(%.4f, %.4f, %.4f), node = %i, side = %i },\n"):format(station.coords.x, station.coords.y, station.coords.z, station.node, station.station))
        end
        write("    }\n}")
    end

    SaveResourceFile(cache.resource, ("data/tracks-%i.lua"):format(fileName), output, string.len(output))
    lib.print.info(("Successfully generated track data. The output is in data/tracks-%i.lua"):format(fileName))
end

local function getTrackId(fileName)
    local name = fileName:match("(%d+)%..*")

    if not name then
        return fileName
    end

    return name
end

RegisterCommand("parseTrainNode", function (source, args, raw)
    Wait(0) -- client doesn't need this input if ran from there
    if source ~= 0 then
        lib.print.error(("Cannot use track parser from the client."))
        return
    end

    if not args[1] then
        lib.print.error(("No file path provided."))
        return
    end

    local fileName = args[1]
    local f, err = io.open(("%s/%s"):format(GetResourcePath(cache.resource), fileName))

    if not f then
        lib.print.error(err)
        return
    end

    local trackId = getTrackId(fileName)
    parseNodeFile(f, trackId - 1)
end, true)