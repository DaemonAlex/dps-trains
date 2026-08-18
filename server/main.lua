if not lib.checkDependency('ox_lib', '3.21.0', true) then return end

if not (cache.resource == "Ehbw-Trains-dev" or cache.resource == "Ehbw-Trains" or cache.resource == "dps-trains") then
    lib.print.warn(("Ehbw-Trains resource name has been changed, No addons will work until the name is reverted"))
end

local GetResourceState = GetResourceState
local table_remove = table.remove

lib.locale()

local config = require "config"
setmetatable(config, nil)

---@type table<number>
clients = {}

---@type table<number, CTracks>
tracks = {}
---@type table<number, CTrainE>
local trackingTrains = {}
---@type boolean
local sv_enableNetEventReassembly = GetConvar("sv_enableNetEventReassembly", "true") == "true"

---@param id number
local function getTrainById(id)
    for i=1, #trackingTrains do
        if trackingTrains[i].id == id then
            return trackingTrains[i]
        end
    end
end

---@param id number
---@return boolean
local function removeTrainWithId(id)
    for i=1, #trackingTrains do
        if trackingTrains[i].id == id then
            table.remove(trackingTrains, i)
            return true
        end
    end
    return false
end

---Checks if the entity ID is associated with a running train. Assumes entity is not nil and is valid
---@param entity number
---@return number?
local function getTrainIDByEntity(entity)
    for i=1, #trackingTrains do
        local train = trackingTrains[i]

        if not train.handle or not DoesEntityExist(train.handle) then
            goto skip
        end

        if entity == train.handle then
            return train.id
        end

        if train.carriages then
            for l=1, #train.carriages do
                local carriage = train.carriages[l]
                if carriage == entity then
                    return train.id
                end
            end
        end

        ::skip::
    end
    return nil
end

---Ensure that the netID exists
---@param netId number
local function GetEntityFromNetworkId(netId)
    local count = 0
    local entity = NetworkGetEntityFromNetworkId(netId)

    --- 200ms to resolve network id before bailing
    while entity == 0 do
        if count > 2 then
            break
        end
        entity = NetworkGetEntityFromNetworkId(netId)
        Wait(100)
        count += 1
    end

    if entity == 0 then
        lib.print.warn(("Trying to delete net id %i, however it is not valid!"))
        return -1
    end

    return entity
end
local function RemoveTrains(data)
    local train = GetEntityFromNetworkId(data.train)

    if DoesEntityExist(train) then
        if DeleteTrain then
            DeleteEntity(train)
            --DeleteTrain(train)
        else
            DeleteEntity(train)
            if data.carriages then
                for i=1, #data.carriages do
                    local carriageId = data.carriages[i]
                    if carriageId then
                        local carriage = GetEntityFromNetworkId(data.carriages[i])
                        if DoesEntityExist(carriage) then
                            DeleteEntity(carriage)
                        end
                    end
                end
            end

        end
    end
end


-- Don't register this even if clients can't create the train
if GetConvar("sv_entityLockdown", "inactive") == "inactive" then
    RegisterNetEvent("Ehbw-Trains:registerTrain", function (data)
        local source = source

        if config.general.useServerSetter then
            lib.print.warn(("User %s (%i) attempted to register train, however server-setters are used instead"):format(GetPlayerName(source), source))
            RemoveTrains(data)
            return
        end

        if not data then
            lib.print.warn(("User %i sent registerTrain event to server with no data"):format(source))
            return
        end

        if not data.train then
            lib.print.warn(("User %i sent registerTrain event to server with no train entities"):format(source))
            return
        end

        -- Trains are expected to have a registering id
        if not data.id then
            lib.print.warn(("User %i sent registerTrain event to server with no id. Culling trains"):format(source))
            return RemoveTrains(data)
        end

        local train
        for i=1, #trackingTrains do
            if trackingTrains[i].id == data.id then
                train = trackingTrains[i]
                break
            end
        end

        if not train then
            lib.print.warn(("User %i sent registerTrain event to server with an id that doesn't exist. Culling trains"))
            return RemoveTrains(data)
        end

        train:RegisterEntity(source, data.train, data.carriages or {}, data.npc, data.carriageCount)
    end)

    RegisterNetEvent("Ehbw-Trains:releaseCandidate", function (trainId, reason)
        local source = source

        if not trainId or type(trainId) ~= "number" then
            return
        end

        local train = getTrainById(trainId)
        if not train then
            return
        end

        if config.general.warnOnCandidateAbdication then
            lib.print.warn(("Client released candidacy of train %i, reason %s"):format(trainId, locale(("candidate.reasons.%s"):format(reason))))
        else
            lib.print.debug(("Client released candidacy of train %i, reason %s"):format(trainId, locale(("candidate.reasons.%s"):format(reason))))
        end
        train:ReleaseClient(source)
    end)

    RegisterNetEvent("Ehbw-Trains:registerCandidacy", function()
        local source = source

        -- We don't want double registration
        for i=1, #clients do
            if clients[i] == source then
                return
            end
        end

        clients[#clients+1] = source
    end)

    AddEventHandler("playerDropped", function()
        local source = source
        for i=1, #clients do
            if clients[i] == source then
                table_remove(clients, i)
                break
            end
        end
    end)
end

local function iterateTrains()
    local blipData = {}
    for i=1, #trackingTrains do
        local train = trackingTrains[i]
        if train then
            local blipCoords = train:Update()

            if blipCoords then
                blipData[#blipData+1] = {train.id, blipCoords}
            end
        else
            lib.print.debug(("An issued occurred while updating trains, gap in array index %i"):format(i))
        end
    end

    -- DPS headway: trains stop at stations now, so a follower on the same track
    -- must hold short instead of rear-ending the train ahead. 40 nodes ~ 300m.
    local HEADWAY_NODES = 40
    for i=1, #trackingTrains do
        local a = trackingTrains[i]
        if a and a.currentNode and a.private and not a.private.dwellUntil then
            local blocked = false
            for j=1, #trackingTrains do
                local b = trackingTrains[j]
                if b and j ~= i and b.trackIndex == a.trackIndex and b.currentNode then
                    local trk = tracks[a.trackIndex]
                    local num = trk and trk.numNodes or 0
                    if num > 0 then
                        local gap = (b.currentNode - a.currentNode) % num
                        if gap > 0 and gap < HEADWAY_NODES then
                            blocked = true
                            break
                        end
                    end
                end
            end
            local state = a.getState and a:getState()
            if blocked and not a.private.headwayHold then
                a.private.headwayHold = true
                if state then state:set("trainSpeed", 0.0, true) end
                lib.print.debug(("Train %i holding for headway"):format(a.id))
            elseif not blocked and a.private.headwayHold then
                a.private.headwayHold = nil
                local resumeSpeed = DPS_ZoneSpeed and DPS_ZoneSpeed(a.trackIndex, a.currentNode, a.speed) or a.speed
                if state then state:set("trainSpeed", resumeSpeed, true) end
                a.private.appliedZoneSpeed = resumeSpeed
                lib.print.debug(("Train %i resuming, headway clear"):format(a.id))
            end
        end
    end

    if blipData and config.general.showTrainBlips then
        if sv_enableNetEventReassembly then
            lib.triggerClientEvent("Ehbw-Trains:updBlipCoords", clients, blipData)
            --TriggerLatentClientEvent("Ehbw-Trains:updBlipCoords", -1, (config.general.blipBPS or 300), blipData)
        else
            lib.triggerClientEvent("Ehbw-Trains:updBlipCoords", clients, blipData)
        end
    end
end

CreateThread(function ()
    assert(config.general, "config/general.lua configuration is invalid, please fix")
    assert(config.cablecar, "config/cablecars.lua configuration is invalid, please fix")
    assert(config.metro, "config/metro.lua configuration is invalid, please fix")
    assert(config.freight, "config/freight.lua configuration is invalid, please fix")

    assert(Train, "Bad CTrain.lua file")

    if GetConvar("sv_entityLockdown", "inactive") ~= "inactive" then
        if not CreateTrain then
            lib.print.error(("Due to a lack of train server-setters, Entity Lockdown has to be disabled before this script can be used."))
            return
        else
            -- Force enable this
            config.general.useServerSetter = true
        end
    end

    if config.general.useServerSetter and not CreateTrain then
        lib.print.error("configuration error, useServerSetter enabled but CREATE_TRAIN native is not found on this artifact version")
        return
    end

    for i=1, #config.general.usedTracks do
        local trackIndex = config.general.usedTracks[i]
        local track = Tracks:new({
            trackId = trackIndex
        })

        tracks[trackIndex] = track
    end

    Wait(1000) -- Mandatory wait just to ensure if theres a connected client nearby the metro coordinates it can register the client script in time to handle the event
    if config.metro.enabled then
        if config.metro.count < #config.metro.startLocations then
            lib.print.warn(("Misconfiguration found with metro trains, there are more metros to be created then what is allowed (%i to be created, %i max)"):format(#config.metro.startLocation, config.metro.count))
            return
        end

        for i=1, #config.metro.startLocations do
            local metro = config.metro.startLocations[i]
            if not metro then
                break
            end

            trackingTrains[#trackingTrains+1] = Train:new({
                type = "metro",
                variation = metro.variation or config.metro.variation,
                direction = metro.direction or false,
                speed = metro.speed or config.general.defaultSpeed,
                useHighPrecisionBlending = config.general.useHighPrecisionBlending,
                shouldStopAtStations = config.metro.shouldStopAtStations,
                doors = true,  -- metros always open doors at stops
                trackIndex = metro.index or (config.metro.trackIndex or 3),
                coords = metro.coords,
                trackNode = metro.node,
                createNPC = config.metro.spawnNPCDriver,
                hasBlip = config.general.showTrainBlips and config.metro.showTrainBlips
            })
        end
    end

    if config.freight.enabled then
        if config.freight.count < #config.freight.startLocations then
            lib.print.warn(("Misconfiguration found with freight trains, there are more freight trains to be created then what is allowed (%i to be created, %i max)"):format(#config.freight.startLocations, config.freight.count))
            return
        end

        for i=1, #config.freight.startLocations do
            local freight = config.freight.startLocations[i]
            if not freight then
                lib.print.warn("Misconfiguration with freight, nil value in ``config.freight.startLocations``")
                break
            end

            trackingTrains[#trackingTrains+1] = Train:new({
                type = "freight",
                variation = freight.variation or config.freight.variation,
                direction = freight.direction or false,
                speed = freight.speed or config.general.defaultSpeed,
                useHighPrecisionBlending = config.general.useHighPrecisionBlending,
                trackIndex = freight.index or (config.freight.index or config.general.index),
                coords = freight.coords,
                trackNode = freight.node,
                createNPC = config.freight.spawnNPCDriver,
                shouldStopAtStations = freight.shouldStopAtStations ~= nil and freight.shouldStopAtStations or  config.freight.shouldStopAtStations,
                doors = freight.doors == true,  -- passenger consists open doors, freight does not
                hasBlip = config.general.showTrainBlips and config.freight.showTrainBlips
            })
        end
    end

    if config.cablecar.enabled and GetResourceState("Ehbw-CableCars") == "started" then
        for i=1, #config.cablecar.startLocations do
            local cablecar = config.cablecar.startLocations[i]
            if not cablecar then
                warn("Misconfiguration with cablecar")
                break
            end

            trackingTrains[#trackingTrains+1] = Train:new({
                type = "cablecar",
                variation = cablecar.variation,
                direction = cablecar.direction or false,
                speed = cablecar.speed or config.general.defaultSpeed,
                useHighPrecisionBlending = config.general.useHighPrecisionBlending,
                shouldStopAtStations = true,
                trackIndex = cablecar.index or 13,
                coords = cablecar.coords,
                createNPC = false,
                hasBlip = config.general.showTrainBlips and config.cablecar.showTrainBlips
            })
        end
    end

    SetInterval(iterateTrains, 1000)
end)

AddEventHandler("onResourceStop", function(resourceName)
    if cache.resource ~= resourceName then
        return
    end

    for i=1, #trackingTrains do
        trackingTrains[i]:Remove()
    end
    trackingTrains = {}
end)

RegisterNetEvent("Ehbw-Trains:fetchTrainData", function ()
    local source = source
    lib.print.debug(("Ehbw-Trains:fetchTrainData %i"):format(source))
    local data = {}
    for i=1, #trackingTrains do
        local train = trackingTrains[i]
        if train then
            data[#data+1] = train:GetClientInfo()
        end
    end

    lib.print.debug(("Sending %i trains to player %s (%s)"):format(#data, GetPlayerName(source), source))
    TriggerClientEvent("Ehbw-Trains:registerTrains", source, data)
end)

local GetEntityType = GetEntityType
local GetVehicleType = GetVehicleType
local GetEntityModel = GetEntityModel
local DoesEntityExist = DoesEntityExist
local GetGamePool = GetGamePool

--- A list just to ensure that trains that we want to exist don't get culled by rouge train checks
---@type table<number, boolean>
local tempSafe = {}

--- Is this model explicitly protected from rouge-train handling?
local protectedModels = {}
for _, h in ipairs(config.general.protectedTrainModels or {}) do
    protectedModels[h] = true
end
local function isProtectedModel(entity)
    return protectedModels[GetEntityModel(entity)] == true
end

if config.general.blockCreationOfNonScriptOwnedTrains then
    AddEventHandler("entityCreating", function (entity)
        if GetEntityType(entity) ~= 2 then
            return
        end

        if GetVehicleType(entity) ~= "train" then
            return
        end

        -- never block a protected model (e.g. rtx_cablecar's cable car)
        if isProtectedModel(entity) then
            tempSafe[entity] = true
            return
        end

        local owner = NetworkGetFirstEntityOwner(entity)
        local entityModel = GetEntityModel(entity)

        local isValidCreation = false
        for i=1, #trackingTrains do
            local train = trackingTrains[i]
            if train then
                local isCreating, creationCandidate = train:getCreationCandidate()
                if isCreating and tonumber(creationCandidate) == owner then
                    isValidCreation = true
                    tempSafe[entity] = true
                    break
                end
            end
        end

        if not isValidCreation then
            lib.print.warn(("Client %s attempted to create train (%i) with model %i, however is not meant to"):format(owner, entity, entityModel))
            CancelEvent()
        end
    end)
end

if config.general.purgeRougeTrains then
    SetInterval(function()
        local vehiclePool = GetGamePool("CVehicle")

        local validEntities = {}
        for i=1, #trackingTrains do
            local train = trackingTrains[i]
            if train and train.handle then
                validEntities[train.handle] = true
                if train.carriages then
                    for l=1, #train.carriages do
                        validEntities[train.carriages[l]] = true
                    end
                end
            end
        end

        for i=1, #vehiclePool do
            local entity = vehiclePool[i]

            if entity and DoesEntityExist(entity) then
                if GetVehicleType(entity) == "train" and not isProtectedModel(entity) then
                    if not validEntities[entity] then
                        if not tempSafe[entity] then
                            lib.print.warn(("[ROUGE] Found rouge train %i, train is not associated with any Ehbw-Trains created trains, deleting"):format(entity))
                            if DeleteTrain then
                                DeleteTrain(entity)
                            else
                                DeleteEntity(entity)
                            end
                        end
                    else
                        if tempSafe[entity] then
                            tempSafe[entity] = nil
                        end
                    end
                end
            end
        end
    end, config.general.svRougeInterval)
end

if config.general.enablePlayerDriving then
    lib.callback.register("Ehbw-Trains:removeTrainDriver", function (source, trainNet)
        local id = getTrainIDByEntity(NetworkGetEntityFromNetworkId(trainNet))

        if id then
            local train = getTrainById(id)

            if train.npc and DoesEntityExist(train.npc) then
                DeleteEntity(train.npc)
                Wait(20)
                return true
            end
        end

        return false
    end)

    RegisterNetEvent("Ehbw-Trains:drivingTrain", function (netId)
        local source = source
        local entity = NetworkGetEntityFromNetworkId(netId)

        if GetEntityType(entity) ~= 2 or GetVehicleType(entity) ~= "train" then
            return
        end

        local id = getTrainIDByEntity(entity)
        if not id then
            lib.print.warn(("Player %i tried driving train that wasn't created by us"):format(source))
            return
        end

        local train = getTrainById(id)

        if not train then
            lib.print.warn(("Attempted to drive train with id %i, but it doesn't exist"):format(id))
            return
        end

        train:setPlayerDriven(source, true)
    end)

    RegisterNetEvent("Ehbw-Trains:stoppedDrivingTrain", function (netId)
        local source = source
        local entity = NetworkGetEntityFromNetworkId(netId)

        if GetEntityType(entity) ~= 2 or GetVehicleType(entity) ~= "train" then
            return
        end

        local id = getTrainIDByEntity(entity)
        if not id then
            lib.print.warn(("Player %i tried driving train that wasn't created by us"):format(source))
            return
        end

        local train = getTrainById(id)
        if not train then
            lib.print.warn(("Attempted to drive train with id %i, but it doesn't exist"):format(id))
            return
        end

        train:setPlayerDriven(source, false)
    end)
end

exports("getMetroTrains", function()
    local metros = {}
    for i=1, #trackingTrains do
        local train = trackingTrains[i]
        if train.isMetro then
            metros[#metros+1] = {
                id = train.id,
                netId = train.netId
            }
        end
    end

    return metros
end)

exports("getFreightTrains", function()
    local freight = {}
    for i=1, #trackingTrains do
        local train = trackingTrains[i]
        if not train.isMetro then
            freight[#freight+1] = {
                id = train.id,
                netId = train.netId
            }
        end
    end
    return freight
end)

---@param data CreateTrainData
exports("createTrain", function (data)
    data.script = GetInvokingResource()
    local train = Train:new(data)

    trackingTrains[#trackingTrains+1] = train
    return train.id
end)

exports("removeTrain", function (identifier)
    if not identifier then
        lib.print.error(("train identifier passed to removeTrain export is nil"))
        return
    end

    local train = getTrainById(identifier)
    if not train then
        lib.print.warn(("No train with identifier %i exists"):format(identifier))
        return false
    end
end)

exports("getClosestTrackAndNode", function(coords)
    local trackIndex = -1
    local trackNode = -1
    local dist = math.huge

    for i=1, #config.general.usedTracks do
        local index = config.general.usedTracks[i]
        local track = tracks[index]

        if track then
            local closestNode, closestDist = track:getClosestTrackNode(coords)
            if closestDist < dist then
                trackIndex = index
                trackNode = closestNode
                dist = closestDist
            end
        end
    end

    return trackIndex, trackNode
end)

exports("getClosestStation", function(trackIndex, coords, direction, useCurrentNode)
    local track = tracks[trackIndex]
    if not track then
        lib.print.error(("Track index %i is invalid"):format(trackIndex))
        return
    end

    if not track:hasStationInformation() then
        lib.print.error(("Track index %i has no stations"):format(trackIndex))
        return
    end

    local node = track:getClosestTrackNode(coords)
    local station, dist = track:getClosestStation(node, direction, useCurrentNode)

    return station, dist
end)

exports("getStationInformation", function(trackIndex)
    local track = tracks[trackIndex]

    if not track then
        lib.print.error(("Track index %i is invalid"):format(trackIndex))
        return nil
    end

    if not track:hasStationInformation() then
        lib.print.error(("Track index %i has no stations"):format(trackIndex))
        return nil
    end

    return track:getStationInformation()
end)

exports("getTrainIDByEntity", function(entity)
    if not DoesEntityExist(entity) then
        lib.print.warn(("Entity %i passed to getTrainIDByEntity does not exist"):format(entity))
        return nil
    end

    if GetEntityType(entity) ~= 2 then
        lib.print.warn(("Entity %i passed to getTrainIDByEntity is not a train"):format(entity))
        return nil
    end

    if GetVehicleType(entity) ~= "train" then
        lib.print.warn(("Entity %i passed to getTrainIDByEntity is not a train"):format(entity))
        return nil
    end

    local id = getTrainIDByEntity(entity)
    return id
end)
exports("getTrainById", getTrainById)

exports("setSpeed", function (id, speed)
    local train = getTrainById(id)
    if not train then
        lib.print.warn(("Attempt to set speed of an train that doesn't exist"))
        return
    end

    lib.print.debug(("Setting train speed to %i"):format(speed))
    train:setSpeed(speed)
end)

exports("setTrainVelocity", function (id, speed)
    local train = getTrainById(id)
    if not train then
        lib.print.warn(("Attempted to set velocity of train %i. But it doesn't exist"):format(id))
        return
    end

    lib.print.debug(("Setting train (%i) velocity to %.3f"):format(id, speed))
    train:setVelocity(speed)
end)

exports("removeTrain", function(id)
    local train = getTrainById(id)

    if not train then
        lib.print.warn(("Attempted to remove train with id %i, but the train does not exist!"):format(id))
        return false
    end

    train:Remove()
    removeTrainWithId(id)
end)

if config.general.enableExampleCommands then
    lib.addCommand("setTrainSpeed", {
        help = "sets train speed",
        restricted = "group.admin",
        params = {
            {
                name = "trainId",
                type = "number",
                help = "The trains ID or handle"
            },
            {
                name = "speed",
                type = "number",
                help = "The new speed (0-30)"
            }
        }
    }, function (_, args)
        local train = getTrainById(args.trainId)
        if train then
            train:setSpeed(args.speed)
        end
    end)
end

lib.addCommand("trainStats", {
    help = "Print information about all trains",
    restricted = config.general.adminCommandGroup or "group.admin"
}, function (source)
    local stats = ""
    for i=1, #trackingTrains do
        local train = trackingTrains[i]
        stats = stats .. ("ID: %i, Type: %s, Entity: %s\n"):format(train.id, (train.isMetro and "Metro" or "Freight"), train.handle and 'Created' or 'Waiting')
    end

    TriggerClientEvent("chat:addMessage", source, {
        color = {255, 0, 0},
        multiline = true,
        args = {"TRAINS", stats}
    })
end)

lib.addCommand("findTrain", {
    help = "Finds a train current location",
    restricted = config.general.adminCommandGroup or "group.admin",
    params = {
        {
            name = "trainId",
            type = "number",
            help = "The trains ID or handle"
        }
    }
}, function (source, args)
    local train = getTrainById(args.trainId)

    if not train then
        TriggerClientEvent("chat:addMessage", source, {
            color = {255, 0, 0},
            args = {"TRAINS", ("No train with identifier %i exists!"):format(args.trainId)}
        })
        return
    end

    local coords = train.currentCoords
    TriggerClientEvent("chat:addMessage", source, {
        color = {255, 0, 0},
        args = {"TRAINS", ("Location: %.3f, %.3f, %.3f"):format(coords.x, coords.y, coords.z)}
    })
end)

-- DPS diagnostic: dump every tracked train's ground truth to console
RegisterCommand('traindebug', function(source)
    if source ~= 0 then return end
    local n = 0
    for i = 1, #trackingTrains do
        local tr = trackingTrains[i]
        if tr then
            n = n + 1
            print(('[traindebug] id=%s type=%s track=%s node=%s handle=%s dwell=%s coords=%s'):format(
                tostring(tr.id), tostring(tr.type), tostring(tr.trackIndex),
                tostring(tr.currentNode), tostring(tr.handle),
                tostring(tr.private and tr.private.dwellUntil),
                tr.currentCoords and ('%.0f,%.0f'):format(tr.currentCoords.x, tr.currentCoords.y) or 'nil'))
        end
    end
    print(('[traindebug] %d trains tracked'):format(n))
end, true)


RegisterNetEvent('dps-trains:seatmark', function(line)
    if type(line) ~= 'string' or #line > 200 then return end
    print(('[seatmark] %s: %s'):format(GetPlayerName(source), line))
end)
