---@class CTrainPrivate

-- ============================================
-- DPS SPEED ZONES (track 0 main line)
-- Open country runs near the cap; the urban corridor slows down.
-- Node ranges from data/tracks-0.lua geography.
-- ============================================
local SPEED_ZONES = {
    [0] = {
        { from = 2150, to = 3350, speed = 16.0, name = 'city corridor' },
        -- everything else on track 0 runs the open-country speed below
    },
}
local OPEN_SPEED = 28.0

function DPS_ZoneSpeed(trackIndex, node, fallback)
    local zones = SPEED_ZONES[trackIndex]
    if not zones or not node then return fallback end
    for i = 1, #zones do
        local z = zones[i]
        if node >= z.from and node <= z.to then return z.speed end
    end
    return OPEN_SPEED
end

---@field isCreating boolean
---@field isDeleting boolean
---@field lastUpdate number
---@field entitySettled boolean
---@field blockedCandidates string[]
---@field lastValidationCheck number

---@class CTrainE : ExportedTrainInformation
---@field private CTrainPrivate
---@field carriages number[]?
---@field npc number
---@field script string
---@field hasTrainBlip boolean
---@field wantsNPC boolean

---@class CreateTrainDataPrivate : CreateTrainClassData
---@field script string?

local config = require "config"
setmetatable(config, nil)

---@class CTrainE
Train = lib.class("CTrainE")

local GetGameTimer = GetGameTimer

local ONESYNC_CULLING_DISTANCE <const> = 424.0

local zero <const> = 0

-- Mirrors the deceleration rate on the client. 
-- Ref: CTrain::Update? / 0x140FD21DC (b3258)
local DECELERATION_RATE <const> = 8

--- Funny magic number to add on to distance
local DISTANCE_MAGIC_NUMBER <const> = config.general.distanceMagicNumber or 20.0

local trainId = 0

---@param data CreateTrainDataPrivate
function Train:constructor(data)
    self.script = data.script
    assert(data.type, ("Train needs a valid type"))
    assert(data.trackIndex, ("TrackIndex must not be nil"))

    self.type = data.type

    self.isMetro = data.type == "metro"

    self.routingBucket = data.routingBucket or 0

    self.direction = data.direction or false

    self.speed = data.speed or config.general.defaultSpeed
    self.useHighPrecisionBlending = data.useHighPrecisionBlending or false
    self.variation = data.variation or config[self.type].variation -- (self.isMetro and config.metro.index or 1)

    self.trackIndex = data.trackIndex or 0
    self.currentNode = data.trackNode or -1

    self.track = tracks[self.trackIndex]

    if not self.track then
        lib.print.error(("Train id %i attempted to use trackIndex %i, however track information was nil"):format(trainId + 1, (self.trackIndex or -1)))
        return
    end

    if self.currentNode == -1 then
        self.currentNode = self:GetTrackNodeFromWorldPos(data.coords or vec3(0.0, 0.0, 0.0))
    end

    self.currentCoords = self.track:getNodeCoords(self.currentNode)

    self.stopsAtStation = data.shouldStopAtStations
    self.doors = data.doors == true

    self.hasTrainBlip = data.hasBlip
    trainId += 1

    self.wantsNPC = data.createNPC or false

    self.private.lastUpdate = GetGameTimer()
    self.private.isDeleting = false
    self.private.isCreating = false
    self.private.createTimeStamp = GetGameTimer()
    self.private.blockedCandidates = {}
    self.private.settleCounter = 0

    self.id = trainId

    if not data.yieldSpawn then
        self:CreateEntity()
    end

    if self.hasTrainBlip then
        TriggerClientEvent("Ehbw-Trains:registerTrainInfo", -1, self:GetClientInfo())
    end
end

function Train:GetClientInfo()
    return {
        id = self.id,
        type = self.type
    }
end

-- Micro-optimisations
local GetPlayerRoutingBucket = GetPlayerRoutingBucket
local GetEntityCoords = GetEntityCoords
local GetPlayerPed = GetPlayerPed
local math_abs = math.abs

---Checks if there isw a player in range to create the metro for us.
---@return string[]?
function Train:GetPlayersInRange()
    local players = clients
    local closestPlayers = {}

    for i = 1, #players do
        local player = players[i]
        if not player then
            goto skip
        end

        if self.private.blockedCandidates and self.private.blockedCandidates[player] then
            goto skip
        end

        if GetPlayerRoutingBucket(player) ~= self.routingBucket then
            goto skip
        end

        local coords = GetEntityCoords(GetPlayerPed(player))
        if #(self.currentCoords - coords) < (config.general.recreateTrainDistance or ONESYNC_CULLING_DISTANCE) then
            closestPlayers[#closestPlayers + 1] = {player = player, coords = coords}
        end
        ::skip::
    end
    return closestPlayers
end

function Train:GetBestCreationCandidate()
    local candidates = self:GetPlayersInRange()
    local bestCandidate = nil
    local latestMessage, closestDist = math.huge, math.huge
    for i = 1, #candidates do
        local player = candidates[i]
        if not player or not player.player or not player.coords then
            lib.print.debug("Skipping broken player in candidate creation")
            goto skip
        end

        if config.selectBestCandidateByPing then
            local lastMessage = GetPlayerLastMsg(player.player)
            if lastMessage < latestMessage then
                latestMessage = lastMessage
                bestCandidate = player
            end
        else
            --Find just based on closest location
            local dist = #(self.currentCoords - player.coords)
            if dist < closestDist then
                bestCandidate = player
                closestDist = dist
            end
        end
        ::skip::
    end

    return bestCandidate and bestCandidate.player or nil
end

function Train:blockPlayerFromCandidate(source)
    if self.private.blockedCandidates[source] then
        lib.print.debug(("Player %s (%i) is already blocked from candidacy selection"):format(GetPlayerName(source), source))
        return
    end
    lib.print.debug(("Blocking player %s (%i) from candidate selection"):format(GetPlayerName(source), source))
    self.private.blockedCandidates[source] = GetGameTimer()
end

local pairs = pairs
function Train:checkBlockedPlayers()
    if not self.private.blockedCandidates then
        lib.print.error(("Train %i, candidate table is corrupted"):format(self.id))
        self.private.blockedCandidates = {}
        return
    end

    local curTimer = GetGameTimer()
    for source, timer in pairs(self.private.blockedCandidates) do
        if source and timer then
            if curTimer - timer > (config.general.unblockBadCandidatesAfterTime or 60000) then
                lib.print.debug(("Unblocking client %i"):format(source))
                self.private.blockedCandidates[source] = nil
            end
        end
    end
end

---@param source number
function Train:ReleaseClient(source)
    if not self.private.isCreating or not self.private.creationCandidate then
        return
    end

    if not source then
        lib.print.warn("Invalid CTrain:ReleaseClient usage called, client source is nil")
        return
    end

    if tonumber(self.private.creationCandidate) == source then
        lib.print.debug(("Client %i has released themselves from the creation candidacy"):format(source))
        self.private.isCreating = false
        self.private.creationCandidate = nil
        self:blockPlayerFromCandidate(source)
    end
end

---@param trackIndex integer
---@param trainVariation integer
---@param x number
---@param y number
---@param z number
---@param direction boolean
---@param stopAtStations boolean
---@param cruiseSpeed number
---@return unknown
local function createTrain(trackIndex, trainVariation, x, y, z, direction, stopAtStations, cruiseSpeed)
    return Citizen.InvokeNative(`CREATE_TRAIN` & 0xFFFFFFFF, trackIndex, trainVariation, x, y, z, direction, stopAtStations, cruiseSpeed)
end

function Train:CreateServerEntity()
    TriggerEvent("Ehbw-Trains:creatingTrainEntity", self.id)
    self.handle = createTrain(self.trackIndex, self.variation, self.currentCoords.x, self.currentCoords.y, self.currentCoords.z, self.direction, self.stopsAtStation, self.speed)
    lib.print.debug(("Created train entity (%i) for train %i"):format(self.handle, self.id))

    if not self.handle then
        lib.print.error(("Failed to create server-setter entity for train %i"):format(self.id))
        return
    end

    self.private.lastValidationCheck = GetGameTimer()

    self.netId = NetworkGetNetworkIdFromEntity(self.handle)

    local carriages = {}
    local carriage = GetTrainBackwardCarriage(self.handle)
    while DoesEntityExist(carriage) do
        carriages[#carriages+1] = NetworkGetNetworkIdFromEntity(carriage)
        carriage = GetTrainBackwardCarriage(carriage)
    end

    self:RegisterEntity(-1, self.netId, carriages, nil)
    return self.handle and true or false
end

---@return boolean
function Train:CreateEntity()
    if self.handle and DoesEntityExist(self.handle) then
        lib.print.warn(("Attempted to create entity for train %i, however train already has an assigned and existing entity"):format(self.id))
        return false
    end

    if not config.general.useServerSetter then
        self:checkBlockedPlayers()
    end

    local source = self:GetBestCreationCandidate()
    if not source then
        return false
    end

    if config.general.useServerSetter then
        return self:CreateServerEntity()
    end

    if self.private.isCreating then
        return false
    end

    TriggerEvent("Ehbw-Trains:creatingTrainEntity", self.id)
    self.private.isCreating = true
    self.private.createTimeStamp = GetGameTimer()
    self.private.creationCandidate = source

    lib.print.debug(("Sending creation request for train %i to player %s (%i)"):format(self.id, GetPlayerName(source), source))
    TriggerClientEvent("Ehbw-Trains:createTrainEntity", source --[[@as number]], self.currentCoords, {
        type = self.type,
        variation = self.variation,
        direction = self.direction,
        speed = self.speed,
        useHighPrecisionBlending = self.useHighPrecisionBlending,
        shouldStopAtStations = self.stopsAtStation,
        id = self.id,
        hasNPC = self.wantsNPC
    })
    return true
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
    return entity
end

---@param train number
---@param carriages number[]
local function RemoveTrains(train, carriages)
    local id = GetEntityFromNetworkId(train)

    if DoesEntityExist(id) then
        if DeleteTrain then
            DeleteTrain(id)
        else
            DeleteEntity(id)
            if carriages then
                for i=1, #carriages do
                    local carriage = GetEntityFromNetworkId(carriages[i])
                    if DoesEntityExist(carriage) then
                        DeleteEntity(carriage)
                    end
                end
            end
        end 
    end
end

---@param source number
---@param trainNetId number
---@param carriagesNetIds number[]
---@param npc number?
function Train:RegisterEntity(source, trainNetId, carriagesNetIds, npc, reportedCount)
    if not self.private.isCreating then
        lib.print.warn(("Client %i attempted to register train for id %i, however the train isn't expecting any to be created"):format(source, self.id))
        RemoveTrains(trainNetId, carriagesNetIds)
        return
    end

    self.private.isCreating = false

    local selectedCandidate = self.private.creationCandidate
    self.private.creationCandidate = nil

    local train = GetEntityFromNetworkId(trainNetId)

    if not config.general.useServerSetter then
        if tonumber(selectedCandidate) ~= source then
            lib.print.warn(("Client %i attempted to register train for id %i, however this client wasn't the elected candidate"):format(source, self.id))
            RemoveTrains(trainNetId, carriagesNetIds)
            return
        end

        if self.handle and DoesEntityExist(self.handle) then
            lib.print.warn(("Client %i attempted to register train, however a train already exists for id %i"):format(source, self.id))
            RemoveTrains(trainNetId, carriagesNetIds)
            return
        end
    end

    self.handle = train
    self.netId = trainNetId

    local state = self:getState()

    if not state then
        lib.print.error("Impossible case hit. Entity statebag is nil with a valid entity.")
        return
    end

    if not config.general.useServerSetter then
        SetEntityOrphanMode(train, 2)
    end

    local carriages = {}
    local carriageCount = 0
    for i = 1, #carriagesNetIds do
        local carriage = GetEntityFromNetworkId(carriagesNetIds[i])

        if carriage ~= 0 then
            if not config.general.useServerSetter then
                SetEntityOrphanMode(carriage, 2)
            end

            Entity(carriage).state:set("e_trncrg", self.id, true)
            carriageCount += 1
            carriages[carriageCount] = carriage
        end
    end
    self.carriages = carriages

    if carriageCount < reportedCount then
        lib.print.warn(("Reported train count for train %i does not match actual train count, one or more carriages failed to network from the client."):format(self.id))
        RemoveTrains(trainNetId, carriagesNetIds)
        self.handle = nil
        return
    end

    state:set("e_trn", self.id, true)

    if self.type == "metro" then
        state:set("e_mto", true, true)
    end

    if self.hasTrainBlip then
        state:set("trainBlips", self.id, true)
    end

    state:set("trainSpeed", self.speed, true)
    state:set("trainState", 0, true)

    if npc and not config.general.useServerSetter then
        local npcID = GetEntityFromNetworkId(npc)
        if not config[self.type].spawnNPCDriver then
            lib.print.warn(("Attempted to register npc, when npc drivers are disabled in the config!"))
            DeleteEntity(npcID)
            return
        end

        --[[if GetEntityModel(npcID) ~= config[self.type].npcModel then
            lib.print.warn(("Attempted to register npc, but npc model mismatches the config!"))
            DeleteEntity(npcID)
        end]]

        if self.wantsNPC then
            self.npc = npcID
        else
            DeleteEntity(npcID)
        end
    end

    TriggerEvent("Ehbw-Trains:createdTrainEntity", self.id, self.handle, self.carriages, self.npc)
    lib.print.debug(("Registered train and %i carriages"):format(carriageCount))
end

---@param coords vector3
---@return number
function Train:GetTrackNodeFromWorldPos(coords)
    if self.currentNode == -1 then
        local closestNode, closestDist = self.track:getClosestTrackNode(coords)
        return closestNode
    end

    return self.track:getClosestTrackNodeWithinRange(self.currentCoords, self.currentNode, self.direction)
end

function Train:UpdatePosition()
    local currentIndex
    if self.direction then
        currentIndex = self.currentNode + 1
        if currentIndex > self.track.numNodes then
            if self.track:isPingPongTrack() then
                self.direction = false
                currentIndex = self.track.numNodes - 1
            else
                lib.print.debug("going back to last node for train loop completed forward", self.id)
                currentIndex = 1
            end
        end
    else
        currentIndex = self.currentNode - 1
        if currentIndex < 1 then
            if self.track:isPingPongTrack() then
                self.direction = true
                currentIndex = 1
            else
                lib.print.debug("going back to last node index for train loop completed backwards", self.id)
                currentIndex = self.track.numNodes -- Go back to the last node
            end
        end
    end

    self.currentNode = currentIndex
    self.currentCoords = self.track:getNodeCoords(currentIndex)

    currentIndex = nil
end


---@return StateBag?
function Train:getState()
    if self.handle then
        return Entity(self.handle).state
    end
    return nil
end

---Handle train updates (e.g. if the train needs to still exist, calculating its new position for respawn and updating stats)
---@param time number
---@return vector2?
function Train:Update(time)
    if self.handle then
        if not DoesEntityExist(self.handle) then
            lib.print.warn(("Train %i. Train Handle %i was forcefully deleted. This is usually caused by an 'anti-cheat' breaking train functionality with their malicious code"):format(self.id, self.handle))
            self.handle = nil
            return nil
        end
        self.currentCoords = GetEntityCoords(self.handle)

        -- This should literally never be hit
        if not self.currentCoords then
            lib.print.error(("Entity %i has no valid coordinates"):format(self.handle))
            return
        end

        --- Check if we have switched track
        local trackIndex = GetTrainTrackIndex(self.handle)

        if trackIndex ~= self.trackIndex then
            lib.print.debug(("Detected track switch, updating track data"))

            if not tracks[trackIndex] then
                lib.print.error(("Train %i (handle: %i) switched track to track %i, but we don't have servfer information for this track"):format(self.id, self.handle, trackIndex))
                return
            end
            self.trackIndex = trackIndex
            self.track = tracks[self.trackIndex]
        end


        self.currentNode = self:GetTrackNodeFromWorldPos(self.currentCoords)
        local owner = NetworkGetEntityOwner(self.handle)

        if owner == -1 or (GetPlayerRoutingBucket(owner) ~= self.routingBucket) then
            if config.general.useServerSetter and not self.private.entitySettled then
                self.private.settleCounter += 1
                lib.print.debug(("Train %i has no owner, but hasn't settled yet"):format(self.id))
                -- Next update the entity should get an owner

                if self.private.settleCounter > 4 then
                    self:Remove()
                end
                return self.hasTrainBlip and self.currentCoords.xy or nil
            end
            self.private.settleCounter = 0
            lib.print.debug(("Train %i has left all player scopes, deleting"):format(self.id))
            self:Remove()
            return nil
        elseif owner ~= -1 and not self.private.entitySettled then
            self.private.entitySettled = true
        end

        if config.general.shouldDeleteTrainIfFarAway and not config.general.useServerSetter then
            local dist = #(GetEntityCoords(GetPlayerPed(owner)) - self.currentCoords)

            if dist > config.general.deleteDistance then
                lib.print.debug(("The owner of train (%i) is too far away. Culling entity for a quick respawn"):format(self.id))
                self:Remove()
                return nil
            end
        end

        -- speed zones: while free-running (no dwell/brake), hold the zone speed
        if not self.isPlayerDriven and not self.private.dwellUntil and not self.private.approachSlow and not self.private.headwayHold then
            local zoneSpeed = DPS_ZoneSpeed(self.trackIndex, self.currentNode, self.speed)
            if self.private.appliedZoneSpeed ~= zoneSpeed then
                local zstate = self:getState()
                if zstate then
                    zstate:set("trainSpeed", zoneSpeed, true)
                    self.private.appliedZoneSpeed = zoneSpeed
                end
            end
        end

        if self.stopsAtStation and not self.isPlayerDriven and self.track:hasStationInformation() then
            local stationIndex, distanceToStation = self.track:getClosestStation(self.currentNode, self.direction, self.direction)
            local now = GetGameTimer()

            -- DPS station-stop cycle: upstream only slowed trains near stations;
            -- this adds the actual stop, dwell, doors and departure.
            if self.private.dwellUntil then
                if now >= self.private.dwellUntil then
                    local state = self:getState()
                    if state then
                        if self.doors then state:set("trainDoors", false, true) end
                        local resumeSpeed = DPS_ZoneSpeed(self.trackIndex, self.currentNode, self.speed)
                        state:set("trainSpeed", resumeSpeed, true)
                        state:set("trainState", 0, true)
                        self.private.appliedZoneSpeed = resumeSpeed
                    end
                    lib.print.debug(("Train %i departing station"):format(self.id))
                    self.private.dwellUntil = nil
                end
                if self.hasTrainBlip then return self.currentCoords.xy end
                return nil
            end

            if stationIndex == -1 then
                if self.hasTrainBlip then
                    return self.currentCoords.xy
                end
                return nil -- we skip
            end

            -- once a NEW station is the next target, the previous one is behind us
            if self.private.servedStation and self.private.servedStation ~= stationIndex then
                self.private.servedStation = nil
            end

            local trainSpeed = GetEntitySpeed(self.handle)
            -- Calculate the stopping distance
            local stoppingDistance = math_abs((zero^2 - trainSpeed^2) / (2 * -DECELERATION_RATE))

            -- 22m window: the server samples position coarsely and a fast train
            -- can step OVER a narrow trigger between updates (observed blow-through)
            if distanceToStation <= 22.0 then
                if not self.private.servedStation then
                    self.private.servedStation = stationIndex
                    self.private.approachSlow = nil
                    self.private.dwellUntil = now + (config.general.stationDwellTime or 180000)
                    local state = self:getState()
                    if state then
                        state:set("trainSpeed", 0.0, true)
                        if self.doors then
                            local side = 1
                            local okS, info = pcall(function() return self.track:getStationInformation() end)
                            if okS and info and info[stationIndex] and info[stationIndex].side then
                                side = info[stationIndex].side
                            end
                            state:set("trainDoors", side, true)
                        end
                    end
                    lib.print.debug(("Train %i holding at station %i"):format(self.id, stationIndex))
                end
                if self.hasTrainBlip then
                    return self.currentCoords.xy
                end
                return nil
            end

            local state = self:getState()
            -- Staged braking under OUR control: GetTrainState is unreliable
            -- server-side for client-created trains, so relying on the game's
            -- own station slow-down let trains hit the stop window at full
            -- cruise and glide far past the platform. Crawl from 180m out.
            if state and not self.private.servedStation then
                if distanceToStation <= 180.0 and not self.private.approachSlow then
                    self.private.approachSlow = true
                    state:set("trainSpeed", 4.0, true)
                    lib.print.debug(("Train %i braking for station %i"):format(self.id, stationIndex))
                end
            end
            -- recovery: if we somehow got past the station without stopping,
            -- do not crawl forever - restore speed once the next stop is far
            if self.private.approachSlow and self.private.servedStation == nil and distanceToStation > 300.0 then
                self.private.approachSlow = nil
                local resumeSpeed = DPS_ZoneSpeed(self.trackIndex, self.currentNode, self.speed)
                if state then state:set("trainSpeed", resumeSpeed, true) end
                self.private.appliedZoneSpeed = resumeSpeed
            end
        end

        if self.hasTrainBlip then
            return self.currentCoords.xy
        end
        return nil -- we skip
    end

    self.private.lastUpdate = GetGameTimer()

    if self.private.isCreating then
        if not self.private.creationCandidate or not DoesPlayerExist(self.private.creationCandidate) then
            lib.print.debug(("Player source %i left while being elected as creation candidate, releasing"):format(self.private.creationCandidate))
            self.private.isCreating = false
            self.private.creationCandidate = nil
            return nil
        end

        if self.private.createTimeStamp + 10000 < self.private.lastUpdate then
            lib.print.warn(("The allocated user %s (%i) failed to create train %i in time, releasing lock for another candidate to attempt"):format(GetPlayerName(self.private.creationCandidate), self.private.creationCandidate, self.id))
            self.private.isCreating = false
            self:blockPlayerFromCandidate(self.private.creationCandidate)
            self.private.creationCandidate = nil
            return nil -- we skip
        end

        lib.print.debug(("Blocking update for train %i while train entity is being created by %i"):format(self.id, self.private.creationCandidate))
        return nil
    end

    -- Attempt to create entity
    if self:CreateEntity() then
        return nil -- we skip -- We still need to wait for the train to be registered. This should be instant for server-setter in 2030
    end

    if not self.currentNode then
        lib.print.debug(("No current node for train %i"):format(self.id))
        return nil -- we skip
    end

    -- Calculate the new position
    self:UpdatePosition()

    if not self.currentCoords then
        lib.print.error(("New coordinates is invalid, train id %i, track index %i, track node %i, numNodes %i"):format(
        self.id, self.trackIndex, self.currentNode, tracks[self.trackIndex].numNodes))
        return nil
    end

    if self.hasTrainBlip then
        return self.currentCoords.xy
    end
end

---@param speed number
function Train:setSpeed(speed)
    -- Validation (can't be negative due to interpolation and double negative not playing well with remote clients, and can't be above 30.0f without causing issues on remote clients)
    if not config.general.unlimitSpeed then
        speed = math.abs(math.min(speed, 30.0))
    end
    TriggerEvent("Ehbw-Trains:trainSpeedChanged", self.id, self.speed, speed)
    self.speed = speed
    if self.handle and DoesEntityExist(self.handle) then
        Entity(self.handle).state:set("trainSpeed", speed, true)
    end
end

function Train:getCreationCandidate()
    return self.private.isCreating, self.private.creationCandidate
end

---@param speed number
function Train:setVelocity(speed)
    -- Validation (can't be negative due to interpolation and double negative not playing well with remote clients, and can't be above 30.0f without causing issues on remote clients)
    if not config.general.unlimitSpeed then
        speed = math.abs(math.min(speed, 30.0))
    end

    if not self.handle or not DoesEntityExist(self.handle) then
        return
    end

    TriggerEvent("Ehbw-Trains:trainVelocityChanged", self.id, GetEntitySpeed(self.handle), speed)
    TriggerClientEvent("Ehbw-Trains:setTrainVelocity", NetworkGetEntityOwner(self.handle), NetworkGetNetworkIdFromEntity(self.handle), speed)
end

function Train:Remove()
    TriggerEvent("Ehbw-Trains:deletedTrainEntity", self.id)
    if self.handle then
        if DeleteTrain then
            DeleteTrain(self.handle)
        else
            DeleteEntity(self.handle)
        end
        self.handle = nil
        self.netId = nil
    end

    self.private.entitySettled = false

    if not DeleteTrain then
        if self.carriages then
            for i = 1, #self.carriages do
                local carriage = self.carriages[i]
                if carriage and DoesEntityExist(carriage) then
                    DeleteEntity(carriage)
                end
            end
        end
    end
    self.carriages = nil


    if self.npc and DoesEntityExist(self.npc) then
        DeleteEntity(self.npc)
        self.npc = nil
    end
end

---@param source any
---@param state any
function Train:setPlayerDriven(source, state)
    self.isPlayerDriven = state
    self.drivenBy = state and source or false

    if config.general.setTrainSpeedOnDriverExit and not state then
        self:setSpeed(8.0)
    end
end