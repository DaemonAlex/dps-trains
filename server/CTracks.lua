local config = lib.require "config"

---@class CTrackPrivate
---@field nodes table
---@field stations table

---@type CTracks
Tracks = lib.class("CTracks")

local function loadDataFile(data)
    local path = ("data/%s.lua"):format(data)
    local file = LoadResourceFile(cache.resource, path)
    local func, err = load(file, ("@@%s/%s"):format(cache.resource, path), "t")

    if not func or err then
        lib.print.error(("Unable to load data file '%s', an error occurred\n^1%s^7"):format(path, err))
        return
    end

    local dataFile = func()
    if not dataFile then
        lib.print.error(("Track file %s should return a table"):format(path))
        return
    end
    return dataFile
end

---@class TrackConstructor
---@field trackId number

function Tracks:constructor(data)
    if not lib.table.contains(config.general.usedTracks, data.trackId) then
        lib.print.error(("Attempted to use track %i, however track is not enabled in config.general.usedTracks"):format(data.trackId))
        return
    end

    local trackData = loadDataFile(("tracks-%i"):format(data.trackId))
    if not trackData then
        lib.print.error(("Invalid track index provided %i"):format(data.trackId))
        return
    end

    if not trackData.nodes or not trackData.numNodes then
        lib.print.error(("Track %i data file is missing track nodes"):format(data.trackId))
        return
    end

    self.trackId = data.trackId
    self.name = trackData.name
    self.private.nodes = trackData.nodes
    self.numNodes = trackData.numNodes
    self.pingPongTrack = trackData.isPingPongTrack

    self.private.stations = trackData.stations or {}

    self.private.hasStations = trackData.stations and true or false

    trackData = nil
    lib.print.debug(("Initialized track %i"):format(self.trackId))
end

---@param node number
---@return vector3
function Tracks:getNodeCoords(node)
    assert(node > 0 and node <= self.numNodes, ("Node %i exceeds boundary of track"):format(node))

    local data = self.private.nodes[node]
    if not data then
        lib.print.error(("Attempted to get node coords for track %i, but node %i does not exist"):format(self.trackId, node))
        return nil
    end

    return data
end

function Tracks:hasStationInformation()
    return self.private.hasStations
end

---@param node number
---@param direction boolean
---@param useCurrentNode boolean? should the provided node also be considered
---@return number
---@return number?
function Tracks:getClosestStation(node, direction, useCurrentNode)
    if not self.private.hasStations then
        lib.print.error(("This track %i does not have any stations"):format(self.trackId))
        return -1, 0
    end
    local coords = self:getNodeCoords(node)
    -- Pick the NEAREST station AHEAD in the travel direction (min node delta),
    -- not the first table entry. The old break-on-first logic returned the
    -- lowest-node station for direction=false, so southbound trains never
    -- braked and blew through every platform.
    local bestNode, bestDelta, bestStation = -1, math.huge, nil
    for i = 1, #self.private.stations do
        local station = self.private.stations[i]
        if station then
            local sn = station.node
            local delta
            if not (node == sn and not useCurrentNode) then
                if direction then
                    if sn >= node then delta = sn - node end
                else
                    if sn <= node then delta = node - sn end
                end
            end
            if delta and delta < bestDelta then
                bestDelta = delta; bestNode = sn; bestStation = station
            end
        end
    end
    if bestNode == -1 or not bestStation then return -1, 0 end
    return bestNode, #(coords - bestStation.coords)
end

---@param coords vector3
---@return integer
---@return integer
function Tracks:getClosestTrackNode(coords)
    local closestNode, closestDist = -1, math.huge
    for l=1, self.numNodes do
        local node = self.private.nodes[l]

        local dist = #(node - coords)
        if dist < closestDist then
            closestNode = l
            closestDist = dist
        end
    end

    return closestNode, closestDist
end

function Tracks:getClosestTrackNodeWithinRange(coords, currentNode, direction)
    -- Search a 100-node window ahead of the train, WRAPPING past the final node.
    --
    -- This used to clamp with math.min(currentNode + 100, self.numNodes), so on
    -- the last node of a track the loop ran exactly once - over the node the
    -- train was already on - and could never reach node 1. A materialised train
    -- is positioned by the game engine and the server derives its node from the
    -- real coordinates through this function, so once a train passed the final
    -- node its reported position froze there permanently while the train itself
    -- carried on down the line.
    --
    -- Everything downstream reads currentNode: station stops, arrival times, and
    -- the stuck detector - which saw a number that never changed, declared the
    -- train stranded and culled it, dumping its passenger out mid-route.
    -- Observed: train 8 pinned at node 4226 while its coordinates travelled from
    -- (520, 3190) to (-546, 4968).
    --
    -- DPS 2026-09-21: the window has to follow the train's DIRECTION. On a
    -- ping-pong line the return leg runs backwards - the true node DECREASES -
    -- but a forward-only search cannot see those nodes, so the reported node
    -- climbed away from reality (observed: the Roxwood shuttle sitting at the
    -- Roxwood platform, coords -486,7660, reporting node 281 instead of 81).
    -- Station stops, arrival times and the stuck detector all read that number,
    -- which is why the shuttle ran straight through its own station on the way
    -- back. Ping-pong tracks therefore search BOTH ways and clamp at the ends -
    -- they have no wrap - while loop tracks keep the original forward wrap.
    local n = self.numNodes
    local minCoords = math.huge
    local node = -1
    local pingPong = self.pingPongTrack == true
    local from = pingPong and -100 or 0

    for step = from, 100 do
        local i = currentNode + step
        if pingPong then
            if i < 1 or i > n then i = nil end   -- no wrap on a there-and-back line
        elseif i > n then
            i = i - n                            -- wrap around the end of the loop
        end
        local p = (i and i >= 1 and i <= n) and self.private.nodes[i] or nil
        if p then
            local dist = #(p - coords)
            if dist < minCoords then
                minCoords = dist
                node = i
            end
        end
    end

    return node
end

function Tracks:isPingPongTrack()
    return self.pingPongTrack
end

function Tracks:getStationInformation()
    return self.private.stations
end