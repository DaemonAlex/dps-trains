if not lib.checkDependency('ox_lib', '3.21.0', true) then return end

lib.locale()

local config = require "config"

local variations = {}

local trains = {}
local creatingTrains = {}

IsDuplicityVersion = IsDuplicityVersion()

--- Localise variables
local RequestModel = RequestModel
local HasModelLoaded = HasModelLoaded
local NetworkRegisterEntityAsNetworked = NetworkRegisterEntityAsNetworked
local NetworkIsInTutorialSession = NetworkIsInTutorialSession
local NetworkGetEntityIsNetworked = NetworkGetEntityIsNetworked
local NetworkGetNetworkIdFromEntity = NetworkGetNetworkIdFromEntity
local GetEntityCoords = GetEntityCoords
local TriggerServerEvent = TriggerServerEvent
local SetTrainSpeed = SetTrainSpeed
local SetTrainCruiseSpeed = SetTrainCruiseSpeed
local NetworkUseHighPrecisionVehicleBlending = NetworkUseHighPrecisionVehicleBlending
local CreatePedInsideVehicle = CreatePedInsideVehicle
local DoesEntityExist = DoesEntityExist
local GetTrainCarriage = GetTrainCarriage
local SetTrainStopAtStations = SetTrainStopAtStations
local GetTrainDoorCount = GetTrainDoorCount
local GetEntityFromStateBagName = GetEntityFromStateBagName
local AddBlipForEntity = AddBlipForEntity
local SetEntityProofs = SetEntityProofs
local SetVehicleCanBreak = SetVehicleCanBreak
local SetMissionTrainCoords = SetMissionTrainCoords
local RemoveBlip = RemoveBlip
local SetBlipCoords = SetBlipCoords
local AddBlipForCoord = AddBlipForCoord
local SetBlipSprite = SetBlipSprite
local SetBlipScale = SetBlipScale
local SetBlipColour = SetBlipColour
local AddTextEntry = AddTextEntry
local SetBlipNameFromTextFile = SetBlipNameFromTextFile
local SetBlipDisplay = SetBlipDisplay
local GetPedInVehicleSeat = GetPedInVehicleSeat
local GetPedConfigFlag = GetPedConfigFlag
local SetEntityLodDist = SetEntityLodDist
local pairs = pairs

--- CREATE_MISSION_TRAIN
local _in = Citizen.InvokeNative
local _ri = Citizen.ResultAsInteger()

---@param models number[]
---@return boolean loaded true if every model is resident
local function loadModels(models)
    for i = 1, #models do
        local model = models[i]
        if not HasModelLoaded(model) then
            lib.print.debug(("Loading model %i"):format(model))

            RequestModel(model)

            -- Bail out rather than spin forever. Without a deadline an unregistered
            -- model hash permanently wedges this client: activeCreation is never
            -- cleared, so every later train request queues behind it for good.
            local deadline = GetGameTimer() + 10000
            while not HasModelLoaded(model) do
                if GetGameTimer() > deadline then
                    lib.print.warn(("Timed out loading train model %s - abandoning"):format(model))
                    return false
                end
                Wait(0)
            end
        end
    end
end

local function releaseModels(models)
    lib.print.debug("Releasing models")
    for i = 1, #models do
        local model = models[i]

        if HasModelLoaded(model) then
            SetModelAsNoLongerNeeded(model)
        end
    end
end

--- Loads all train models
local function requestTrainModels(variation)
    -- Force load all models
    if not variation then
        loadModels(config.general.trainModels)
        return
    end

    if variations[variation] then
        loadModels(variations[variation])
        return
    end

    loadModels(config.general.trainModels)
end


local activeCreation = nil

---Native declaration for CREATE_MISSION_TRAIN providing missing params to ensure the entity is networked
---@param variation number
---@param coords vector3
---@param direction boolean
---@param isNetwork boolean
---@param netMissionEntity boolean
local function N_CreateMissionTrain(variation, coords, direction, isNetwork, netMissionEntity)
    local native = _in(0x63C6CCA8E68AE8C8, variation, coords.x, coords.y, coords.z, direction, isNetwork, netMissionEntity, _ri)
    return native
end

---There can be a few cases where the train doesn't recieve a netID immediately.
---Or in rare cases has a netID (and is registered on the server), however the client still complains
---Onesync fun.
---@param trainID number
local function AwaitUntilTrainIsValidNetEnt(trainID)
    if not DoesEntityExist(trainID) then
        error(("Train doesn't exist. It may have been blocked from creation by an 'anti-cheat'"))
    end

    local timer = GetGameTimer()
    NetworkRegisterEntityAsNetworked(trainID)
    while not NetworkGetEntityIsNetworked(trainID) and GetGameTimer() - timer < 10000 do
        if not DoesEntityExist(trainID) then
            lib.print.warn(("Entity %i was deleted while waiting for it to network, bailing"):format(trainID))
            return -1
        end
        Wait(0)
    end

    if GetGameTimer() - timer > 10000 then
        lib.print.warn(("Entity %i took too long to become networked, bailing"):format(trainID))
        return -1
    end

    return NetworkGetNetworkIdFromEntity(trainID)
end

---@class TrainData
---@field type "metro" | "freight" | "cablecar"
---@field isMetro boolean
---@field variation number
---@field direction boolean
---@field speed number
---@field useHighPrecisionBlending boolean

---@param coordinates vector3
---@param data TrainData
---@param train number?
---@return boolean
local function shouldCreationProceed(coordinates, data, train)
    if not coordinates and not train then
        lib.print.warn(("Server request train creation, missing data for creation. Bailing"))
        TriggerServerEvent("Ehbw-Trains:releaseCandidate", data.id, 1)
        return false
    end

    local coords = GetEntityCoords(cache.ped)
    if coordinates and #(coords - coordinates) > 424.0 then
        lib.print.warn(("Server request train creation outside of our scope. Bailing"))
        TriggerServerEvent("Ehbw-Trains:releaseCandidate", data.id, 2)
        return false
    end

    if train and not DoesEntityExist(train) then
        lib.print.warn(("Server request train creation, train is invalid. Bailing"))
        TriggerServerEvent("Ehbw-Trains:releaseCandidate", data.id, 3)
        return false
    end

    Wait(10)
    if train and #(GetEntityCoords(train) - coords) > 424.0 + 66 then -- 500
        DeleteMissionTrain(train)
        lib.print.warn(("Server request train creation. Train has far exceeded our scope. Deleting and releasing candidacy"))
        TriggerServerEvent("Ehbw-Trains:releaseCandidate", data.id, 4)
        return false
    end

    return true
end

local function IterateChainLink(train, cb)
    local carriageIndex = 1
    local carriage = GetTrainCarriage(train, carriageIndex)
    while DoesEntityExist(carriage) do
        cb(carriage)
        carriageIndex += 1
        carriage = GetTrainCarriage(train, carriageIndex)
        Wait(0)
    end
end

local function ApplyTrainFixes(train)
    SetVehicleCanBreak(train, false)
    SetEntityProofs(train, true, true, true, true, true, true, true, true)
    SetVehicleExplodesOnHighExplosionDamage(train, false)
end

---@param coordinates vector3
---@param data TrainData
RegisterNetEvent("Ehbw-Trains:createTrainEntity", function (coordinates, data)
    if not data or not data.id or not data.variation then
        lib.print.error(("Malformed data about train. This is unrecoverable."))
        return
    end

    if not coordinates then
        lib.print.error(("Malformed coordinates when trying to create train id %i"):format(data?.id or "Missing ID"))
        if data.id then
            TriggerServerEvent("Ehbw-Trains:releaseCandidate", data.id, 9)
        end
        return
    end

    if activeCreation and activeCreation == data.id then
        lib.print.error(("Server attempted to create train %i, however we are already processing it"):format(data.id))
        return
    end

    while activeCreation do
        lib.print.debug(("Waiting for creation to clear"))
        Wait(1000)
    end

    if NetworkIsInTutorialSession() then
        activeCreation = nil
        TriggerServerEvent("Ehbw-Trains:releaseCandidate", data.id, 8)
        return
    end

    activeCreation = data.id
    lib.print.debug(("New request to create train %i at vec3(%.3f, %.3f, %.3f)"):format(data.id, coordinates.x, coordinates.y, coordinates.z))
    requestTrainModels(data.variation)

    if not shouldCreationProceed(coordinates, data, nil) then
        lib.print.warn("creation invalid after model loading")
        activeCreation = nil
        return
    end

    -- Check again just incase we have been put into a tutorial session during model loading and before creating the train
    if NetworkIsInTutorialSession() then
        activeCreation = nil
        TriggerServerEvent("Ehbw-Trains:releaseCandidate", data.id, 8)
        return
    end

    local train = N_CreateMissionTrain(data.variation, coordinates, data.direction, true, true)
    if not train or train == 0 then
        lib.print.warn(("Failed to create train!"))
        activeCreation = nil
        TriggerServerEvent("Ehbw-Trains:releaseCandidate", data.id, 5)
        return
    end

    lib.print.debug(("Train created with client id %i"):format(train))
    SetMissionTrainCoords(train, coordinates.x, coordinates.y, coordinates.z)

    local carriageCount = 0
    creatingTrains[train] = true
    IterateChainLink(train, function(carriage)
        creatingTrains[carriage] = true
        carriageCount += 1
    end)

    if data.speed and data.type ~= 'cablecar' then
        SetTrainCruiseSpeed(train, data.speed)
    end

    local serverData = {
        train = AwaitUntilTrainIsValidNetEnt(train),
        carriages = {},
        id = data.id
    }

    if serverData.train == -1 then
        lib.print.error(("Failed to network train engine"))
        TriggerServerEvent("Ehbw-Trains:releaseCandidate", data.id, 7)
        activeCreation = nil
        return
    end

    if data.useHighPrecisionBlending then
        NetworkUseHighPrecisionVehicleBlending(NetworkGetNetworkIdFromEntity(train), true)
    end

    -- native station stops disabled: the game only knows the vanilla power
    -- station stop, which double-stopped trains there. All stops are handled
    -- by the DPS dwell cycle server-side.
    if false and data.shouldStopAtStations and SetTrainStopAtStations then
        lib.print.debug("Setting stops at station to true")
        SetTrainStopAtStations(train, true)
    end

    if not config.general.disableTrainFixes then
        ApplyTrainFixes(train)
        SetTrainSpeed(train, 0.0)
    end

    if data.hasNPC and config[data.type].npcModel then
        lib.print.debug("Train creating npc driver")
        lib.requestModel(config[data.type].npcModel)
        local npcDriver = CreatePedInsideVehicle(train, 0, config[data.type].npcModel, -1, true, true)
        lib.print.debug(("Created npc driver with id %i"):format(train))
        serverData.npc = AwaitUntilTrainIsValidNetEnt(npcDriver)
        lib.print.debug(("NPC driver assigned network id %i"):format(serverData.npc))
    end

    if not shouldCreationProceed(coordinates, data, train) then
        activeCreation = nil
        DeleteMissionTrain(train)
        return
    end

    SetEntityLodDist(train, 500)
    IterateChainLink(train, function (carriage)
        local ent = AwaitUntilTrainIsValidNetEnt(carriage)
        if ent ~= -1 then
            serverData.carriages[#serverData.carriages+1] = ent
            SetEntityLodDist(carriage, 500)
            ApplyTrainFixes(carriage)
        end
    end)

    serverData.carriageCount = carriageCount
    if #serverData.carriages ~= carriageCount then
        activeCreation = nil
        lib.print.debug(("One or more train carriages failed to network, expected %i carriages, got %i carriages"):format(carriageCount, #serverData.carriages))
        TriggerServerEvent("Ehbw-Trains:releaseCandidate", data.id, 6)
        return
    end

    lib.print.debug(("Registering train on server side"))
    TriggerServerEvent("Ehbw-Trains:registerTrain", serverData)

    activeCreation = nil
    creatingTrains[train] = nil
    IterateChainLink(train, function(carriage)
        creatingTrains[carriage] = nil
    end)
    TriggerEvent("Ehbw-Trains:createTrain", train, data.id)

    if variations[data.variation] then
        releaseModels(variations[data.variation])
        return
    end
end)

RegisterNetEvent("Ehbw-Trains:setTrainVelocity", function(train, speed)
    lib.print.debug(("Setting train velocity %i, netId %i\n"):format(speed, train))
    local trn = NetworkGetEntityFromNetworkId(train)
    SetTrainSpeed(trn, speed)
end)

AddStateBagChangeHandler("trainSpeed", nil, function(bagName, _, value)
    local train = lib.waitFor(function ()
        local entity = GetEntityFromStateBagName(bagName)
        if entity ~= 0 and DoesEntityExist(entity) then
            return entity
        end
    end, ("Train took too long to load"), 10000)

    if not config.general.unlimitSpeed then
        value = value and math.min(math.abs(value), 30) or 0
    end

    value = value or 0
    lib.print.debug(("Setting train (%i) speed to %.3f"):format(train, value))
    SetTrainCruiseSpeed(train, value)
    --SetTrainSpeed(train, value)
end)

AddStateBagChangeHandler("trainState", nil, function(bagName, _, value, _, replicated)
    local train = lib.waitFor(function ()
        local entity = GetEntityFromStateBagName(bagName)
        if entity ~= 0 and DoesEntityExist(entity) then
            return entity
        end
    end, ("Train took too long to load"), 10000)


    if not GetTrainState then
        return
    end

    if not value then
        return
    end

    if GetTrainState(train) == value then
        return
    end

    if value then
        SetTrainState(train, value)
    end
end)

AddStateBagChangeHandler("e_trn", nil, function (bagName, _, value)
    local train = lib.waitFor(function ()
        local entity = GetEntityFromStateBagName(bagName)
        if entity ~= 0 and DoesEntityExist(entity) then
            return entity
        end
    end, ("Train took too long to load"), 10000)

    if not trains[value] then
        lib.print.warn("Invalid train state")
        return
    end

    trains[value].entity = train

    if GetGameBuildNumber() >= 3717 then
      Citizen.InvokeNative(0x559B6073DB7FFFF9, train, not config[trains[value].type].ignoreObstructions) 
    else
        SetVehicleFlag(train, 43, not config[trains[value].type].ignoreObstructions)
    end

    if config.general.enabledBridges then
        TriggerEvent("Ehbw-Trains:trainEnteredScope", train, trains[value])
    end
end)

local function toggleDoors(side, train, state)
    if not DoesEntityExist(train) then
        return
    end

    local doorCount = GetTrainDoorCount(train)
    local doorIndexs = {}
    for i=0, doorCount - 1 do
        if i % 2 == 0 then
            if side == 1 then
                doorIndexs[#doorIndexs+1] = i
            end
        elseif side == 0 then
            doorIndexs[#doorIndexs+1] = i
        end
    end

    for i=1, #doorIndexs do
        SetTrainDoorOpenRatio(train, doorIndexs[i], state and 1.0 or 0.0)
    end
end

local function toggleDoorForChain(train, side, open)
    if not DoesEntityExist(train) then
        lib.print.debug(("Train stopped existing aborting toggleDoorForChain"))
        return
    end

    local carriageIndex = 1
    local carriage = train
    while DoesEntityExist(carriage) do
        if carriageIndex > 1 and carriage == train then
            break
        end
        if side == 2 then
            toggleDoors(0, carriage, open)
            toggleDoors(1, carriage, open)
        else
            toggleDoors(side == 1 and 0 or 1, carriage, false)
            toggleDoors(side, carriage, open)
        end

        carriage = GetTrainCarriage(train, carriageIndex)
        carriageIndex += 1
    end
end

AddStateBagChangeHandler("trainDoors", nil, function (bagName, _, value)
    local train = lib.waitFor(function ()
        local entity = GetEntityFromStateBagName(bagName)
        if entity ~= 0 and DoesEntityExist(entity) then
            return entity
        end
    end, ("Train took too long to load"), 10000)

    lib.print.debug(("Opening doors %s on train %i"):format(value or "nil", train))

    if not value then
        toggleDoorForChain(train, 2, false)
        return
    end
    toggleDoorForChain(train, value, true)
end)

local SetRandomTrains = SetRandomTrains
local SwitchTrainTrack = SwitchTrainTrack
local SetTrainTrackSpawnFrequency = SetTrainTrackSpawnFrequency

CreateThread(function()
    do
        local gameBuild = GetGameBuildNumber()
        local index = 0
        local trainConfigs = require 'data.trains'

        for i=1, #trainConfigs do
            local train = trainConfigs[i]

            if train.gameBuild and train.gameBuild > gameBuild then
                goto skip
            end

            variations[index] = train.models
            index += 1
            ::skip::
        end
    end

local protectedModels = {}
for _, h in ipairs(config.general.protectedTrainModels or {}) do
    protectedModels[h] = true
end

    local rougeTrainCheck = GetGameTimer()
    while true do
        if config.general.showTrainBlips then
            for trainId, data in pairs(trains) do
                if data.entity and not DoesEntityExist(data.entity) then
                    data.entityBlip = RemoveBlip(data.entityBlip)
                    data.entity = nil
                end
            end
        end

        if config.general.purgeRougeTrains then
            local timer = GetGameTimer()
            if rougeTrainCheck + config.general.clRougeInterval < timer then
                rougeTrainCheck = timer
                -- Spread the sweep across frames. GetGamePool("CVehicle") returns every
                -- vehicle in the world and this used to test all of them in a single
                -- frame, which stalls the client on a busy server. Trains are rare, so
                -- yielding every 40 entities costs nothing and removes the hitch.
                local vehPool = GetGamePool("CVehicle")
                for i=1, #vehPool do
                    if i % 40 == 0 then Wait(0) end
                    local ent = vehPool[i]
                    if ent and DoesEntityExist(ent) and GetVehicleTypeRaw(ent) == 14
                       and not protectedModels[GetEntityModel(ent)] then
                        if not creatingTrains[ent] then
                            local shouldDelete = false
                            if not NetworkGetEntityIsNetworked(ent) then
                                lib.print.debug(("Found rouge non-networked train %i"):format(ent))
                                shouldDelete = true
                            end

                            if not shouldDelete and (not Entity(ent).state.e_trn and not Entity(ent).state.e_trncrg) then
                                lib.print.debug(("Found rouge networked train %i"):format(ent))
                                shouldDelete = true
                            end

                            if shouldDelete then
                                SetEntityAsMissionEntity(ent, true, true)
                                if IsMissionTrain(ent) then
                                    SetMissionTrainAsNoLongerNeeded(ent, false)
                                    DeleteMissionTrain(ent)
                                else
                                    DeleteEntity(ent)
                                end
                            end
                        end
                    end
                end
            end
        end

        for _, train in pairs(trains) do
            if not train.entity or not DoesEntityExist(train.entity) then
                train.entity = nil
                goto skip
            end

            local entity = train.entity

            local isOwner = NetworkGetEntityOwner(entity) == cache.playerId

            if GetTrainState then
                if GetTrainState(entity) ~= Entity(train.entity).state.trainState and isOwner then
                    Entity(entity).state:set("trainState", GetTrainState(entity), true)
                end
            end

            if train.type == "cablecar" then
                if GetTrainState then
                    local state = GetTrainState(entity)
                    if state == 2 or state == 3 then
                        toggleDoorForChain(entity, 2, true)
                    end

                    if state == 0 or (state == 4 or state == 5) then
                        toggleDoorForChain(entity, 2, false)
                    end
                end
            end
            ::skip::
        end

        -- Ambient suppression WITHOUT disabling the tracks. CREATE_MISSION_TRAIN
        -- refuses to spawn on a disabled track ("no tracks enabled"), so the
        -- original SwitchTrainTrack(x, false) here blocked this script from
        -- creating its own trains. The 864000ms spawn interval already stops
        -- ambient trains on its own.
        -- SET_RANDOM_TRAINS is the master switch: with it false the engine reports
        -- "no tracks enabled" and CREATE_MISSION_TRAIN refuses to spawn, no matter
        -- what SwitchTrainTrack says afterwards. Leave it on and suppress ambient
        -- traffic purely with the 864000ms spawn interval below (~10 days).
        -- This artifact uses the NEW train natives (SET_TRACK_ENABLED). The script
        -- disables tracks via SetTrackEnabled but was enabling them with the old
        -- SwitchTrainTrack, which does not feed the same state - so the enable never
        -- registered and CREATE_MISSION_TRAIN kept reporting "no tracks enabled".
        -- SET_TRACK_ENABLED writes CTrainTrack::m_enabled, which is the ONLY field
        -- CREATE_MISSION_TRAIN's guard (AreAllTracksDisabled) reads. SWITCH_TRAIN_TRACK
        -- writes m_disableAmbientTrains, which controls vanilla ambient spawning only.
        -- So: enable the track for our own trains, switch ambient traffic off. Ambient
        -- trains spawn in both directions and are the head-on collision vector.
        SetRandomTrains(true)
        if SetTrackEnabled then
            SetTrackEnabled(0, true)
            SetTrackEnabled(3, true)
        end
        SwitchTrainTrack(0, false)
        SwitchTrainTrack(3, false)
        Wait(1000)
    end
end)

RegisterNetEvent("Ehbw-Trains:registerTrainInfo", function (data)
    if trains[data.id] then
        return
    end
    trains[data.id] = data
end)

RegisterNetEvent("Ehbw-Trains:registerTrains", function(trainData)
    if not trainData then
        return
    end
    trains = {}

    for i=1, #trainData do
        local data = trainData[i]
        trains[data.id] = data
    end
end)

TriggerServerEvent("Ehbw-Trains:fetchTrainData")

CreateThread(function()
    if IsTrackEnabled and SetTrackEnabled then
        for i=1, #config.general.disabledTracks do
            local disabledTrack = config.general.disabledTracks[i]
            SetTrackEnabled(disabledTrack, false)
        end
    end
end)

if config.general.showTrainBlips then
    ---@param blip number
    ---@param type string
    -- DPS: style blips per SERVICE, not just track type. Passenger consists are
    -- variations 29/30 (see dps-trains-glossary): metro=blue, passenger=green,
    -- freight=orange, all small.
    local function setupBlipData(blip, trainData)
        local svc = trainData.type  -- both call sites pass the full table now
        local variation = trainData.variation
        local id = trainData.id
        -- every train gets its OWN color so the map reads at a glance:
        -- Metro 1 blue, Metro 2 purple, Passenger 1 green, Passenger 2 yellow,
        -- Freight orange (id order follows config spawn order)
        local BY_ID = {
            [1] = { 'Metro 1',           3 },
            [2] = { 'Metro 2',           27 },
            [3] = { 'Passenger Train 1', 2 },
            [4] = { 'Passenger Train 2', 5 },
            [5] = { 'Freight Train',     17 },
        }
        local label, color
        local hit = id and BY_ID[id]
        if hit then
            label, color = hit[1], hit[2]
        elseif svc == 'metro' then
            label, color = 'Metro', 3
        elseif variation == 28 or variation == 29 then
            label, color = 'Passenger Train', 2
        elseif svc == 'cablecar' then
            label, color = 'Cable Car', 5
        else
            label, color = 'Freight Train', 17
        end
        SetBlipSprite(blip, (config[svc] and config[svc].trainBlipSprite or config.general.trainBlipSprite))
        SetBlipScale(blip, 0.5)
        SetBlipColour(blip, color)
        AddTextEntry(("EHBW-TRAINS-%s"):format(label), label)
        SetBlipNameFromTextFile(blip, ("EHBW-TRAINS-%s"):format(label))
        SetBlipAsShortRange(blip, false)  -- trains show map-wide: the map IS the tracker
        if config[svc] and (config[svc].trainBlipDisplay or config.general.trainBlipDisplay) then
            SetBlipDisplay(blip, config[svc].trainBlipDisplay or config.general.trainBlipDisplay)
        end
    end

    RegisterNetEvent("Ehbw-Trains:updBlipCoords", function (data)
        if not data then
            lib.print.debug(("No train blips to update this tick"))
            return
        end

        for i=1, #data do
            local trainData = data[i]

            if not trainData then
                lib.print.debug(("Malformed train blip data, index %i is missing data"):format(i))
                goto skip
            end

            local id = trainData[1]
            local train = trains[id]
            local xy = trainData[2]

            if not train then
                lib.print.debug(("Malformed train blip coordinates, index %i is missing data"):format(i))
                goto skip
            end

            -- Check if an entity is associated with this train. If there is but it doesn't exist for our client remove the blip and move on
            if train.entity then
                if not DoesEntityExist(train.entity) then
                    train.entity = nil
                    if train.entityBlip then
                        train.entityBlip = RemoveBlip(train.entityBlip)
                    end
                end

                if train.blip then
                    train.blip = RemoveBlip(train.blip)
                end
                goto skip
            end

            if train.blip and DoesBlipExist(train.blip) then
                SetBlipCoords(train.blip, xy.x, xy.y, 0)
            else
                local blip = AddBlipForCoord(xy.x, xy.y, 0.0)
                trains[id].blip = blip
                setupBlipData(blip, train)
            end
            ::skip::
        end
    end)

    AddStateBagChangeHandler("trainBlips", nil, function (bagName, _, value, _, _)
        local train = lib.waitFor(function ()
            local entity = GetEntityFromStateBagName(bagName)
            if entity ~= 0 and DoesEntityExist(entity) then
                return entity
            end
        end, ("Train took too long to load"), 10000)

        if not value or type(value) ~= "number" then
            lib.print.warn(("Invalid value attached to train statebag"))
            return
        end

        if not trains[value] then
            lib.print.warn(("Attempted to register trainBlips on a train that isn't registered on our client"))
            return
        end

        -- quickly cull blips incase
        local trainData = trains[value]
        local blip = AddBlipForEntity(train)
        setupBlipData(blip, trainData)
        trainData.entity = train

        if trainData.entityBlip then
            trainData.entityBlip = RemoveBlip(trainData.entityBlip)
        end

        if trainData.blip then
            trainData.blip = RemoveBlip(trainData.blip)
        end
        trainData.entityBlip = blip
    end)
end

local seatInterval, currentSeat, currentMetro = nil, -1,  nil

local function clearSeatInterval()
    if seatInterval then
        seatInterval = ClearInterval(seatInterval)
        currentMetro = nil
        currentSeat = -1
    end
end

local function setSeatInterval()
    if seatInterval then
        return
    end

    local metroTrain = currentMetro
    local currentSeat = currentSeat

    config.general.showTextHelp(locale("leave_train_seat"))

    seatInterval = SetInterval(function()
        if IsControlJustReleased(0, 49) or IsDisabledControlJustReleased(0,49) then
            ClearPedTasks(cache.ped)
            clearSeatInterval()

            config.general.clearTextHelp()
            if metroTrain and DoesEntityExist(metroTrain) then
                local seatOffset = config.metro.seatResetCoords[currentSeat]

                local off = GetOffsetFromEntityInWorldCoords(metroTrain, seatOffset.x, seatOffset.y, seatOffset.z) --(metroTrain, 0.0, -5.0, 1.6)

                SetEntityCoords(cache.ped, off.x, off.y, off.z, false, false, false, false)
                DetachEntity(cache.ped, false, false)
                SetPedConfigFlag(cache.ped, 74, true)
            else
                local plrCoords = GetEntityCoords(cache.ped)

                SetEntityCoords(cache.ped, plrCoords.x, plrCoords.y, plrCoords.z, false, false, false, false)
                DetachEntity(cache.ped, false, false)
                SetPedConfigFlag(cache.ped, 74, true)

                lib.print.warn(("Attempted to leave seat in metrotrain. Entity is nil or doesn't exist (%s)"):format(metroTrain or "nil"))
            end
        end
    end, 0)
end

---@param train number
---@param index number | vector3
local function sitInSeat(train, index)
    if not train or not DoesEntityExist(train) then
        return
    end

    if type(index) == "vector3" then
        local closestIndex = -1
        local closestDist = 50
        for i=1, #config.metro.seatOffsets do
            local seatOffset = config.metro.seatOffsets[i]
            local coords = GetOffsetFromEntityInWorldCoords(train, seatOffset.x, seatOffset.y, seatOffset.z)

            local distance = #(index - coords)
            if distance < closestDist then
                closestIndex = i
                closestDist = distance
            end
        end
        --[[CreateThread(function()
            while true do
                for i=1, #config.metro.seatOffsets do
                    local seatOffset = config.metro.seatOffsets[i]

                    local coords = GetOffsetFromEntityInWorldCoords(train, seatOffset.x, seatOffset.y, seatOffset.z)

                    DrawMarker(2, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 0, 255, 0, 255, true, true, 2, true, nil, nil, true)                    
                end
                Wait(0)
            end
        end)]]
        index = closestIndex
    end

    if index == -1 then
        lib.print.warn(("Attempted to sit in seat, however no seat was close enough. (Metro entity is bugged?)"))
        return
    end

    local seatOffset = config.metro.seatOffsets[index]
    if not seatOffset then
        lib.print.warn(("Invalid seat offset: %i"):format(index))
        return
    end

    currentMetro = train
    currentSeat = index

    AttachEntityToEntity(cache.ped, train, 0, seatOffset.x, seatOffset.y, seatOffset.z, 0.0, 0.0, seatOffset.w, false, true, false, true, 2, true)
    lib.requestAnimDict(config.metro.seatAnimDict)
    TaskPlayAnim(cache.ped, config.metro.seatAnimDict, config.metro.seatAnimName, 8.0, 8.0, -1, 1, 1.0, false, false, false)
    RemoveAnimDict(config.metro.seatAnimDict)

    setSeatInterval()
end
exports("sitInSeat", sitInSeat)

if config.general.enableExampleCommands then
    local function getClosestTrain()
        local coords = GetEntityCoords(cache.ped)
        local vehicle = lib.getClosestVehicle(coords, 10.0, false)
        return vehicle
    end

    RegisterCommand("sitInSeat", function(source, args, raw)
        local train = getClosestTrain()
        if not train then
            return
        end
        sitInSeat(train, tonumber(args[1] or "1"))
    end)
end

SetTrainsForceDoorsOpen(config.general.openDoorsWhenInsideTrain)

--- Bridge helper functions
---@param entity number
local function canDriveTrain(entity, bones, distance)
    local seatEnt = GetPedInVehicleSeat(entity, -1)
    if seatEnt ~= 0 and not IsPedDeadOrDying(seatEnt, true) then
        return false
    end

    if bones then
        for i=1, #bones do
            local index = GetEntityBoneIndexByName(entity, bones[i])
            local bonePosition = GetEntityBonePosition_2(entity, index)
            local coords = GetEntityCoords(cache.ped)

            if #(coords - bonePosition) > (distance or 10.0) then
                return false
            end
        end
    end

    return GetPedConfigFlag(cache.ped, 138, true)
end

local function canSitInSeat()
    return GetPedConfigFlag(cache.ped, 138, true)
end

--- Handle bridge
--- Strict data environment to prevent malicious use
local ENV <const> = {
    vec = vec,
    vector = vector,
    vec3 = vec3,
    vec4 = vec4,
    vector4 = vec4,
    vec2 = vec2,
    vector2 = vector2,
    vector3 = vector3,
    table = table,
    string = string,
    math = math,
    exports = exports,
    print = lib.print.info,
    warn = lib.print.warn,
    error = lib.print.error,
    debug = lib.print.debug,
    locale = locale,
    config = config,
    cache = cache,
    checkDependency = lib.checkDependency,

    RegisterNetEvent = RegisterNetEvent,
    AddEventHandler = AddEventHandler,

    -- Some iteration
    DoesEntityExist = DoesEntityExist,
    GetTrainCarriage = GetTrainCarriage,
    Wait = Wait,

    canSitInSeat = canSitInSeat,
    canDriveTrain = canDriveTrain
}

local function handleBridgeSupport()
    if not config.general.enableBridge then
        return
    end

    for i=1, #config.general.enabledBridges do
        local resource = config.general.enabledBridges[i]
        lib.print.debug(("Checking bridge '%s'"):format(resource))

        if not resource then
            lib.print.error("Malformed configuration for ``config.general.enabledBridges``, there is a gap in the array")
            break
        end

        local state = GetResourceState(resource)
        if state ~= "started" then
            lib.print.warn(("Attempted to load bridge support for '%s' however the resource is not loaded and is %s."):format(resource, state))
            goto skip
        end

        local path = ("client/bridge/%s.lua"):format(resource)
        local file = LoadResourceFile(cache.resource, path)

        if not file then
            lib.print.warn(("Attempted to load bridge support for '%s', however the client bridge file is missing"):format(resource))
            goto skip
        end

        local func, err = load(file, ("@@%s/%s"):format(cache.resource, path), "t", ENV)

        if not func or err then
            lib.print.error(("Unable to load bridge support for '%s', an error occurred\n^1%s^7"):format(resource, err))
            goto skip
        end

        func()

        lib.print.debug(("Successfully loaded bridge support for resource '%s'"):format(resource))
        ::skip::
    end
end

handleBridgeSupport()
TriggerServerEvent("Ehbw-Trains:registerCandidacy")