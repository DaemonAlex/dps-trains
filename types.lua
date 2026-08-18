---@meta

---@class CTracks
---@field private CTrackPrivate
---@field trackId number
---@field name string
---@field numNodes number
---@field pingPongTrack boolean
---@field constructor fun(self: CTracks, data: TrackConstructor)
---@field getNodeCoords fun(self: CTracks, node: number): vector3
---@field getClosestStation fun(self: CTracks, node: number, direction: boolean, useCurrentNode: boolean?)
---@field getClosestTrackNode fun(self: CTracks, coords: vector3)
---@field isPingPongTrack fun(self: CTracks): boolean
---@field getClosestTrackNodeWithinRange fun(self: CTracks, coords: vector3, node: number, direction: boolean): number
---@field hasStationInformation fun(self: CTracks): boolean
---@field getStationInformation fun(self: CTracks): table

---@class CreateTrainClassData
---@field type 'metro' | 'freight' | 'cablecar' Will this train be a metrotrain
---@field trackIndex number usually 0 (main train line) or 3 (metro train line), however can be set to any valid track index (including custom)
---@field variation number Train variation (be careful, invalid variations will crash clients)
---@field direction boolean? The direction the train travels in (default: false)
---@field speed number? The trains starting speed (between 0 - 30)
---@field useHighPrecisionBlending boolean? Should the train entity use the High Precision Net Blender for interpolation (b2372 required)
---@field coords vector3? The trains starting coordinates (can be null if a trackNode is provided instead)
---@field trackNode number? The starting tracknode for the train (can be null if a coordinate relative to a tracknode is provided)
---@field routingBucket number? The routingBucket the train is located in (default 0)
---@field shouldStopAtStations boolean? Should this train stop at stations defined in the track data
---@field hasBlip boolean? Should this train render a blip?
---@field createNPC boolean? Should this train have a NPC Driver
---@field yieldSpawn boolean? Should the spawn wait a second (instead of attempting on class creation)

---@class ExportedTrainInformation A subset of the information used on the server side
---@field type 'metro' | 'freight' | 'cablecar'
---@field routingBucket number
---@field direction boolean
---@field speed number
---@field useHighPrecisionBlending boolean
---@field variation number
---@field trackIndex number
---@field currentNode number
---@field currentCoords vector3
---@field stopsAtStation boolean
---@field id number
---@field handle number?
---@field netId number?
---@field track CTracks

---@class TrainData
---@field id number trainIdentifier
---@field netId number? the entity netID (if exists)

--- `server`
---Creates a train to be managed under the resource
---@param data CreateTrainData
---@return number trainIdentifier
function exports['Ehbw-Trains']:createTrain(data) end

--- `server`
---Deletes a train and its client entities. Returns false if failed
---Returns false if failed or trainIdentifier provided is invalid
---@param trainIdentifier number
---@return boolean
function exports['Ehbw-Trains']:removeTrain(trainIdentifier) end

--- `server`
---Gets all managed metro trains (including those being calculated by the server and not as an client entity)
---@return TrainData[]
function exports['Ehbw-Trains']:getMetroTrains() end

--- `server`
---Gets all managed freight trains (including those being calculated by the server and not as an client entity)
---@return TrainData[]
function exports['Ehbw-Trains']:getFreightTrains() end

--- `server`
---Sets the trains speed, Speed is capped between 0 and 30
---Returns false if failed or trainIdentifier provided is invalid
---@param trainIdentifier number
---@param speed number
---@return boolean
function exports['Ehbw-Trains']:setSpeed(trainIdentifier, speed) end

--- `server`
--- Gets the closest track index and track node based on coordinates. Can be used to create custom trains on
---@param coords vector3
function exports['Ehbw-Trains']:getClosestTrackAndNode(coords) end

--- `server`
---Retrieves information about a train with the specified Identifier
---@return ExportedTrainInformation
function exports['Ehbw-Trains']:getTrainById(id) end

--- `server`
---Gets a trains identifier by train handle (supports engine and carriages + caboose)
---@param entity number
---@return number?
function exports['Ehbw-Trains']:getTrainIDByEntity(entity) end

---`server`
---Sets a trains current velocity. This isn't reliable to prevent potential issues with statebag handlers
---(e.g. the velocity being randomly changed when a player enters scope and claims ownership before the statebag is triggered)
---@param id integer
---@param speed number
function exports['Ehbw-Trains']:setTrainVelocity(id, speed) end

---`server`
---Gets the closest station on a trackindex
---@param trackIndex number
---@param coords vector3
---@param direction boolean
---@param useCurrentNode boolean?
function exports['Ehbw-Trains']:getClosestStation(trackIndex, coords, direction, useCurrentNode) end

---@deprecated
---THIS WILL NOT FUNCTION UNTIL TRAIN DIRECTIONS CAN BE CHANGED
---THIS FUNCTION IS CURRENTLY A NOOP UNTIL THEN
---@param trainIdentifier any
---@param direction any
function exports['Ehbw-Trains']:setDirection(trainIdentifier, direction) end

---`client`
---Sets player into the specified train and allows the player to control it
---@param trainEntity number the trains entityID (not trainId)
function exports['Ehbw-Trains']:driveTrain(trainEntity) end

---`client`
---Places player into seat on the specified metrotrain.
---@param trainID number
---@param index number
function exports['Ehbw-Trains']:sitInSeat(trainID, index) end

---`server`
--- Called when the train entity is being deleted (when no players are nearby, or owner is gone)
--- RegisterNetEvent("Ehbw-Trains:deleteTrainEntity", function(trainId)

---`server`
---Called when the train can be created, at this point the train has not been created or registered with this train identifier. Use the event below if you need that information
---RegisterNetEvent("Ehbw-Trains:creatingTrainEntity", function(trainId))

--- `server`
--- Called when the train entity has been recreated
--- RegisterNetEvent("Ehbw-Trains:createdTrainEntity", function(trainId, trainEntity, carriages, npc))

--- `server`
--- Called when a train has their speed changed
--- RegisterNetEvent("Ehbw-Trains:trainSpeedChanged", function(trainId, oldSpeed, newSpeed))

--- `server`
--- Called when a player begins driving a train
--- RegisterNetEvent("Ehbw-Trains:drivingTrain", function(trainNetId))

--- `server`
--- Called when a player stops driving a train
--- RegisterNetEvent("Ehbw-Trains:stoppedDrivingTrain", function(trainNetId))