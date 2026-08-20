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
-- stuck-train tracking, keyed by train id (see stranded-train recovery below)
local stuckWatch = {}
-- physical-separation holds, keyed by train id. Cannot live on train.private:
-- that is a protected ox_lib class field and rejects new keys.
local physHoldState = {}
-- headway holds and dwell-regulation bookkeeping, keyed by train id. Same
-- reason as physHoldState: train.private rejects writes from outside the class.
local headwayState = {}
local dwellRegulated = {}

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
            if blocked and not headwayState[a.id] then
                headwayState[a.id] = true
                if state then state:set("trainSpeed", 0.0, true) end
                lib.print.debug(("Train %i holding for headway"):format(a.id))
            elseif not blocked and headwayState[a.id] then
                headwayState[a.id] = nil
                local resumeSpeed = DPS_ZoneSpeed and DPS_ZoneSpeed(a.trackIndex, a.currentNode, a.speed) or a.speed
                if state then state:set("trainSpeed", resumeSpeed, true) end
                lib.print.debug(("Train %i resuming, headway clear"):format(a.id))
            end
        end
    end

    -- DPS stranded-train recovery.
    --
    -- A materialised train is driven by the game engine client-side; the server
    -- only derives its node from the entity's real position. UpdatePosition -
    -- which contains the wrap back to node 1 - runs for GHOST trains only. So a
    -- materialised train that reaches the final node has nothing to wrap it: the
    -- engine parks it at the end of the line and it sits there forever, while
    -- the server keeps believing it is cruising because the zone-speed block
    -- only sends a command when the target CHANGES.
    --
    -- Observed: train 7 pinned at node 4226 (the last node on track 0) for an
    -- entire session while every other train advanced, with a player catching
    -- and overtaking it.
    --
    -- State is held in a local table, NOT on train.private - that is a protected
    -- ox_lib class field and rejects new keys ("cannot set value of private
    -- field").
    local STUCK_AFTER_MS = 120000  -- generous: a real strand sits forever, so there is no hurry
    local nowMs = GetGameTimer()
    for i = 1, #trackingTrains do
        local tr = trackingTrains[i]
        if tr and tr.id then
            local held = (tr.private and tr.private.dwellUntil) or headwayState[tr.id]
                         or physHoldState[tr.id]
            -- A train legitimately standing at a platform has not "advanced"
            -- either, and it does not always carry dwellUntil - the ghost dwell
            -- happens before it materialises, so the handover can leave it
            -- stopped at a station with no flag set. Culling those deleted a
            -- train a player was about to board. Anything near a station node is
            -- therefore exempt, and the deadline is generous enough that a real
            -- strand still gets caught.
            -- Read stations from the track itself. STATION_NAMES is declared
            -- further down this file, so referencing it here resolves to a nil
            -- global.
            local nearStation = false
            local trk = tracks[tr.trackIndex]
            if trk and tr.currentNode and trk.hasStationInformation and trk:hasStationInformation() then
                local okS, info = pcall(function() return trk:getStationInformation() end)
                if okS and info then
                    for si = 1, #info do
                        local sn = info[si] and info[si].node
                        if sn and math.abs(tr.currentNode - sn) <= 40 then
                            nearStation = true
                            break
                        end
                    end
                end
            end

            if tr.handle and tr.currentNode and not held and not tr.isPlayerDriven and not nearStation then
                local rec = stuckWatch[tr.id]
                if not rec or rec.node ~= tr.currentNode then
                    stuckWatch[tr.id] = { node = tr.currentNode, since = nowMs }
                elseif (nowMs - rec.since) > STUCK_AFTER_MS then
                    lib.print.warn(("Train %i has not advanced from node %s for %ds - culling for respawn")
                        :format(tr.id, tostring(tr.currentNode), math.floor(STUCK_AFTER_MS / 1000)))
                    stuckWatch[tr.id] = nil
                    if tr.Remove then tr:Remove() end
                end
            else
                stuckWatch[tr.id] = nil
            end
        end
    end

    -- Physical separation check REMOVED.
    --
    -- It held a train whenever another was within 60m on the ground, to stop
    -- trains driving through each other. But track 0 folds back on itself, so
    -- services legitimately pass on parallel rails 40-60m apart - and the check
    -- cannot tell a parallel pass from a head-on one. The result was a train
    -- stopping dead every time it met another going the other way.
    --
    -- The pass-through it was written for turned out to be a different bug: a
    -- train stranded at node 4226 that the server had lost track of, because
    -- getClosestTrackNodeWithinRange could not wrap past the final node. That is
    -- fixed at source, along with orphan cleanup on resource stop, so this
    -- workaround is not needed.
    --
    -- Same-direction following is still covered by the node-based headway hold
    -- above, which is the real collision risk.

    -- DPS schedule regulation. The headway hold above only prevents a rear-end;
    -- it does nothing about bunching, where two trains orbit the loop a few
    -- hundred metres apart and the line effectively runs one fewer service.
    -- So each train, once stopped at a station, compares its gap to the train
    -- ahead against the ideal even spacing for its track and uses dwell as the
    -- correction: bunched trains hold longer and drop back into their slot, a
    -- train with an oversized gap ahead cuts its dwell short and catches up.
    -- Dwell stays within 0.4x-2.0x the configured base so this reads as normal
    -- variation in stop length rather than a train parked at a platform.
    -- Applied once per station stop (keyed on servedStation) so it cannot
    -- oscillate as the gap changes while sitting.
    local baseDwell = (config.general and config.general.stationDwellTime) or 180000
    local perTrack = {}
    for i=1, #trackingTrains do
        local t = trackingTrains[i]
        if t and t.trackIndex then perTrack[t.trackIndex] = (perTrack[t.trackIndex] or 0) + 1 end
    end
    for i=1, #trackingTrains do
        local a = trackingTrains[i]
        if a and a.private and a.private.dwellUntil and a.currentNode
           and dwellRegulated[a.id] ~= a.private.servedStation then
            local trk = tracks[a.trackIndex]
            local num = trk and trk.numNodes or 0
            local n = perTrack[a.trackIndex] or 1
            if num > 0 and n > 1 then
                local gapAhead
                for j=1, #trackingTrains do
                    local b = trackingTrains[j]
                    if b and j ~= i and b.trackIndex == a.trackIndex and b.currentNode then
                        local gap = (b.currentNode - a.currentNode) % num
                        if gap > 0 and (not gapAhead or gap < gapAhead) then gapAhead = gap end
                    end
                end
                if gapAhead then
                    local ideal = num / n
                    local scale = 2.0 - (gapAhead / ideal)
                    if scale < 0.4 then scale = 0.4 elseif scale > 2.0 then scale = 2.0 end
                    if a.SetDwellUntil then
                        a:SetDwellUntil(GetGameTimer() + math.floor(baseDwell * scale))
                    end
                    dwellRegulated[a.id] = a.private.servedStation
                    lib.print.debug(("Train %i regulating: gap %d of ideal %.0f nodes, dwell x%.2f"):format(
                        a.id, gapAhead, ideal, scale))
                end
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
-- Prints `count` evenly spaced node coordinates around a track, formatted ready
-- to paste into a configs/*.lua startLocations table. Spawning trains at depots
-- that happen to sit near each other bunches them: two trains a couple of km
-- apart on a 30 km loop arrive together and the line reads as one fewer service
-- than it has. Spacing by node index avoids guessing from map positions.
RegisterCommand('trainspace', function(source, args)
    if source ~= 0 then return end
    local trackIndex = tonumber(args[1])
    local count = tonumber(args[2]) or 4
    local track = trackIndex and tracks[trackIndex]
    if not track or not track.numNodes then
        print('[trainspace] usage: trainspace <trackIndex> <count>')
        return
    end
    local step = math.floor(track.numNodes / count)
    print(('[trainspace] track %d has %d nodes, step %d'):format(trackIndex, track.numNodes, step))
    for i = 0, count - 1 do
        local idx = 1 + i * step
        local c = track:getNodeCoords(idx)
        if c then
            print(('[trainspace] node %d -> {coords = vec3(%.3f, %.3f, %.3f), direction = true},'):format(idx, c.x, c.y, c.z))
        end
    end
end, true)

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


-- ============================================
-- ARRIVAL BOARD (DPS) - feeds the phone transit app
-- ============================================
local STATION_NAMES = {
    [0] = {  -- main line, keyed by stop node
        -- Downtown and Quarry each appear TWICE because the line calls at them
        -- in both directions, not because they are duplicates. Measured from
        -- live train positions:
        --   Downtown 2434 (680,-1236) running south, 2865 (664,-988) north
        --   Quarry   1481 (2552,2846) running south-west, 3891 (2496,2786) north-east
        -- Roughly 250m apart at Downtown and 50m at Quarry - the same station,
        -- opposite platforms. Naming them by direction tells a passenger which
        -- way the train is going; east/west would be meaningless here.
        [462] = 'Lumber Mill', [651] = 'Paleto Bay',
        [1481] = 'Quarry (Southbound)',
        [1555] = 'Wind Farm',                 -- skipped, see config.skipStations
        [1701] = 'Power Plant',
        [2434] = 'Davis Interchange (Southbound)',   -- ~400m to the metro's Davis platform
        [2667] = 'Port Depot',
        [2865] = 'Davis Interchange (Northbound)',   -- ~400m to the metro's Davis platform
        [3891] = 'Quarry (Northbound)',
        [4159] = 'Sandy Shores',
    },
    [3] = {
        [179] = 'Strawberry', [271] = 'Little Seoul', [388] = 'Puerto Del Sol',
        [434] = 'LSIA West', [530] = 'LSIA East', [578] = 'Rockford South',
        [689] = 'Little Seoul East', [782] = 'Davis', [1078] = 'Burton',
        [1162] = 'Portola Drive',
    },
}
local TRAIN_LABELS = {
    metro = { label = 'Metro', color = '#4aa3ff' },
}
local function trainLabel(train)
    -- Named the way a passenger reads a departure board. Brown Streak Railroad
    -- is the GTA rail company the streak model family is named for; Axsellya
    -- Express is the DPS name for the coaster set.
    if train.type == 'metro' then return 'Metro', '#4aa3ff' end
    if train.variation == 28 then return 'Axsellya Express', '#3ad06a' end
    if train.variation == 29 then return 'Brown Streak', '#e8d24a' end
    return 'Freight', '#f08a3c'
end

local cumCache = {}
local function cumDist(trackIndex)
    if cumCache[trackIndex] then return cumCache[trackIndex] end
    local track = tracks[trackIndex]
    if not track or not track.numNodes then return nil end
    -- Use the accessor, not track.nodes: that field is not populated at runtime,
    -- so cumDist returned nil for every track, distAhead always returned nil and
    -- the phone board showed "no service" at every station.
    local getNode = track.getNodeCoords
    if not getNode then return nil end
    local cum, total = { [1] = 0.0 }, 0.0
    local prev = track:getNodeCoords(1)
    if not prev then return nil end
    for i = 2, track.numNodes do
        local b = track:getNodeCoords(i)
        if not b then break end
        total = total + #(vector3(prev.x, prev.y, prev.z) - vector3(b.x, b.y, b.z))
        cum[i] = total
        prev = b
    end
    cumCache[trackIndex] = { cum = cum, total = total }
    return cumCache[trackIndex]
end

local function distAhead(trackIndex, fromNode, toNode)
    local c = cumDist(trackIndex)
    if not c then return nil end
    local a = c.cum[math.max(1, math.min(fromNode, #c.cum))] or 0
    local b = c.cum[math.max(1, math.min(toNode, #c.cum))] or 0
    if b >= a then return b - a end
    return (c.total - a) + b  -- wraps the loop
end

exports('getArrivalBoard', function()
    local board = {}
    for trackIndex, names in pairs(STATION_NAMES) do
        local track = tracks[trackIndex]
        if track and track.hasStationInformation and track:hasStationInformation() then
            local ok, stations = pcall(function() return track:getStationInformation() end)
            if ok and stations then
                local skipB = (config.general.skipStations or {})[trackIndex] or {}
                for si, st in ipairs(stations) do
                    if skipB[st.node] then goto nextStation end
                    local entry = {
                        station = names[st.node] or ('Stop ' .. si),
                        node = st.node,
                        track = trackIndex,
                        coords = { x = st.coords.x, y = st.coords.y },
                        arrivals = {},
                    }
                    for i = 1, #trackingTrains do
                        local tr = trackingTrains[i]
                        if tr and tr.trackIndex == trackIndex and tr.currentNode then
                            local dist = distAhead(trackIndex, tr.currentNode, st.node)
                            if dist then
                                -- count intervening station dwells
                                local stopsBetween = 0
                                for _, st2 in ipairs(stations) do
                                    local d2 = distAhead(trackIndex, tr.currentNode, st2.node)
                                    if d2 and d2 > 1.0 and d2 < dist then stopsBetween = stopsBetween + 1 end
                                end
                                -- Use the train's real speed. This was hardcoded to 22 m/s
                                -- while ghosts actually ran at ~7 (one node per 1s tick) and
                                -- materialised trains at 30, so every ETA was wrong and the
                                -- board's countdown drifted against real time.
                                local avgSpeed = tr.speed or config.general.defaultSpeed or 20.0
                                local eta = dist / avgSpeed + stopsBetween * ((config.general.stationDwellTime or 60000) / 1000)
                                local status = 'en route'
                                if tr.private and tr.private.dwellUntil then
                                    status = 'boarding'
                                    eta = eta + math.max(0, (tr.private.dwellUntil - GetGameTimer()) / 1000)
                                elseif tr.private and tr.private.headwayHold then
                                    status = 'delayed'
                                end
                                local label, color = trainLabel(tr)
                                entry.arrivals[#entry.arrivals + 1] = {
                                    train = label, color = color,
                                    eta = math.floor(eta), status = status,
                                    stopsAway = stopsBetween,
                                }
                            end
                        end
                    end
                    table.sort(entry.arrivals, function(a, b) return a.eta < b.eta end)
                    board[#board + 1] = entry
                    ::nextStation::
                end
            end
        end
    end
    return board
end)


-- why is the phone board empty? print what each stage of getArrivalBoard sees.
RegisterCommand('boarddebug', function(src)
    if src ~= 0 then return end
    print('[boarddebug] trackingTrains = ' .. tostring(#trackingTrains))
    for trackIndex, names in pairs(STATION_NAMES) do
        local track = tracks[trackIndex]
        local nNames = 0
        for _ in pairs(names) do nNames = nNames + 1 end
        if not track then
            print(('[boarddebug] track %s: NOT LOADED (%d names configured)'):format(tostring(trackIndex), nNames))
        else
            local hasFn = track.hasStationInformation ~= nil
            local has   = hasFn and track:hasStationInformation() or false
            local cnt   = 0
            if has then
                local ok, st = pcall(function() return track:getStationInformation() end)
                if ok and st then cnt = #st end
            end
            print(('[boarddebug] track %s: hasFn=%s has=%s stations=%d names=%d')
                :format(tostring(trackIndex), tostring(hasFn), tostring(has), cnt, nNames))
        end
    end
    -- why are all arrivals empty?
    for ti = 0, 3 do
        local c = cumDist(ti)
        if c then
            print(('[boarddebug] cumDist(%d): nodes=%d total=%.0f'):format(ti, #c.cum, c.total))
        end
    end
    for i = 1, #trackingTrains do
        local tr = trackingTrains[i]
        print(('[boarddebug] train %d: trackIndex=%s currentNode=%s')
            :format(i, tostring(tr and tr.trackIndex), tostring(tr and tr.currentNode)))
    end
    local board = exports['dps-trains']:getArrivalBoard()
    local withArr = 0
    for _, e in ipairs(board) do if #e.arrivals > 0 then withArr = withArr + 1 end end
    print(('[boarddebug] board entries = %d, with arrivals = %d'):format(#board, withArr))
end, true)
