local config = require "config"

if not config.general.enablePlayerDriving then
    return
end

---Micro optimisations
local IsControlJustReleased = IsControlJustReleased
local IsControlPressed = IsControlPressed
local GetGameTimer = GetGameTimer
--end

local isDrivingTrain = false

local function getClosestTrain()
    local coords = GetEntityCoords(cache.ped)
    local vehicle = lib.getClosestVehicle(coords, 10.0, false)
    return vehicle
end

---@param train number
---@param stateBag string
---@param value any
---@param check boolean Should we check if the state is already set as this to prevent spamming requests
local function setTrainState(train, stateBag, value, check)
    if not DoesEntityExist(train) then
        return
    end

    local entity = Entity(train).state

    if check and entity[stateBag] == value then
        return
    end
    Entity(train).state:set(stateBag, value, true)
end

local trainDrivingInterval = nil

local lDoorOpen = false
local rDoorOpen = false

local function clamp(val, lower, upper) -- credit https://love2d.org/forums/viewtopic.php?t=1856
    if lower > upper then lower, upper = upper, lower end
    return math.max(lower, math.min(upper, val))
end

local curState = false
local function driveTrainInterval()
    if trainDrivingInterval then
        return
    end

    if DoesTrainStopAtStations then
        curState = DoesTrainStopAtStations(cache.vehicle)
    end

    if SetTrainStopAtStations then
        SetTrainStopAtStations(cache.vehicle, false)
    end

    -- If the train isn't in state 0. Game code restricts speed to track max.
    if GetTrainState(cache.vehicle) ~= 0 then
        SetTrainState(cache.vehicle, 0)
        end

    local cruiseSpeed = not GetTrainSpeed and Entity(cache.vehicle).state.trainSpeed or GetTrainSpeed(cache.vehicle)

    local function setCruiseSpeed(value)
        if config.general.unlimitSpeed then
            cruiseSpeed = cruiseSpeed + value
        else
            cruiseSpeed = clamp(cruiseSpeed + value, 0, 30)
        end
    end

    local delay = 100
    local lastPressedL, lastPressedR = 0,0

    trainDrivingInterval = SetInterval(function()
        if IsControlPressed(0, config.general.playerControls.forward or 71)
        or IsDisabledControlPressed(0, config.general.playerControls.forward or 71) then
            if lastPressedL + delay > GetGameTimer() then
                return
            end
            lastPressedL = GetGameTimer()

            SetTrainCruiseSpeed(cache.vehicle, cruiseSpeed + config.general.playerDrivingAcceleration.acceleration)
            setCruiseSpeed(config.general.playerDrivingAcceleration.acceleration)
            setTrainState(cache.vehicle, "trainSpeed", cruiseSpeed, true)
        end

        if IsControlPressed(0, config.general.playerControls.backward or 72)
        or IsDisabledControlPressed(0, config.general.playerControls.backward or 72) then
            if lastPressedR + delay > GetGameTimer() then
                return
            end
            lastPressedR = GetGameTimer()
            SetTrainCruiseSpeed(cache.vehicle, cruiseSpeed - config.general.playerDrivingAcceleration.breaking)
            setCruiseSpeed(-config.general.playerDrivingAcceleration.breaking)
            setTrainState(cache.vehicle, "trainSpeed", cruiseSpeed, true)
        end

        if IsControlJustReleased(0, config.general.playerControls.handbrake or 76)
        or IsDisabledControlJustReleased(0, config.general.playerControls.handbrake or 72) then
            SetTrainCruiseSpeed(cache.vehicle, 0.0)
            cruiseSpeed = 0
        end

        if IsControlJustReleased(0, config.general.playerControls.leftDoors or 63)
        or IsDisabledControlJustReleased(0, config.general.playerControls.leftDoors or 63) then
            if rDoorOpen and not lDoorOpen then
                lDoorOpen = not lDoorOpen
                setTrainState(cache.vehicle, "trainDoors", 2, true)
                return
            end

            setTrainState(cache.vehicle, "trainDoors", (not lDoorOpen and 1 or nil), true)
            lDoorOpen = not lDoorOpen
        end

        if IsControlJustReleased(0, config.general.playerControls.rightDoors or 64)
        or IsDisabledControlJustReleased(0, config.general.playerControls.rightDoors or 64) then
            if lDoorOpen and not rDoorOpen then
                rDoorOpen = not rDoorOpen
                setTrainState(cache.vehicle, "trainDoors", 2, true)
                return
            end

            setTrainState(cache.vehicle, "trainDoors", (not rDoorOpen and 0 or nil), true)
            rDoorOpen = not rDoorOpen
        end
    end, 0)
end

lib.onCache("vehicle", function (value)
    if not value and isDrivingTrain then
        isDrivingTrain = false

        if SetTrainStopAtStations and curState then
            SetTrainStopAtStations(cache.vehicle, curState)
        end

        if trainDrivingInterval then
            trainDrivingInterval = ClearInterval(trainDrivingInterval)
        end

        TriggerServerEvent("Ehbw-Trains:stoppedDrivingTrain", NetworkGetNetworkIdFromEntity(cache.vehicle))
        return
    end
end)

lib.onCache("seat", function(value)
    if value == -1 and GetVehicleTypeRaw(cache.vehicle) == 14 then
        if not Entity(cache.vehicle).state.e_trn  then
            return
        end
        isDrivingTrain = true
        driveTrainInterval()
    end
end)

---comment
---@param trainID any
local function driveTrain(trainID)
    if not trainID or not DoesEntityExist(trainID) then
        warn(("No train entity was passed to 'driveTrain' export or the entity does not exist"))
        return
    end

    if not Entity(trainID).state.e_trn then
        error(("Train %i passed to export 'driveTrain' is not the engine or is not managed by Ehbw-Trains"):format(trainID))
        return
    end

    if trainID ~= 0 and not IsPedDeadOrDying(trainID, true) then
        return
    end

    local seatEnt = GetPedInVehicleSeat(trainID, -1)
    if seatEnt ~= 0 and config.general.enablePlayerDriving then
        if NetworkGetEntityOwner(seatEnt) ~= cache.playerId then
            lib.callback.await("Ehbw-Trains:removeTrainDriver", false, NetworkGetNetworkIdFromEntity(trainID))
            local timer = GetGameTimer()
            while DoesEntityExist(seatEnt) or timer - GetGameTimer() < 5000 do
                Wait(0)
            end
        else
            DeleteEntity(seatEnt)
        end
    end

    SetPedIntoVehicle(cache.ped, trainID, -1)
    --TaskEnterVehicle(cache.ped, trainID, 0, -1, 8.0, 16, false)
    TriggerServerEvent("Ehbw-Trains:drivingTrain", NetworkGetNetworkIdFromEntity(trainID))
end
exports("driveTrain", driveTrain)

if config.general.enableExampleCommands then
    RegisterCommand("driveTrain", function()
        local train = getClosestTrain()
        driveTrain(train)
    end, false)
end