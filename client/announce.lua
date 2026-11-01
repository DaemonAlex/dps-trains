-- CLIENT. Station announcements, tied to the LINE rather than to the train.
--
-- The old version listened for the Flexity's own models, so the announcements
-- belonged to the vehicle: move that tram to another line and the metro station
-- names went with it. Now any train counts, and the station you hear is the one you
-- are actually approaching. Swapping stock between lines needs no change here.
--
-- Only the passenger's own client does this work, and it sends a station number,
-- never any text. An empty platform costs nothing.

local NEXT_AT   = 170.0   -- metres: "next station"
local ARRIVE_AT = 32.0    -- metres: "now arriving"
local COOLDOWN  = 25000   -- ms before the same station may be announced again

local CLASS_TRAIN = 21    -- GTA's own vehicle class for trains

-- Addon trams do not always declare themselves as class 21, so the models we ship
-- are named as well. Either test passing is enough.
local RIDING = {}
for _, m in ipairs({ 'elrtcab', 'elrtpassenger', 'elrtmiddle', 'elrtcabrear',
                     'metrotrain', 'streakcoaster', 'streakc', 'streakcab', 'streak' }) do
    RIDING[GetHashKey(m)] = true
end

local said = {}           -- "index:phase" -> GetGameTimer() when it was asked for

local function onTrain()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return false end
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then return false end
    if GetVehicleClass(veh) == CLASS_TRAIN then return true end
    return RIDING[GetEntityModel(veh)] == true
end

local function ask(index, phase)
    local key = index .. ':' .. phase
    local now = GetGameTimer()
    if said[key] and (now - said[key]) < COOLDOWN then return end
    said[key] = now
    TriggerServerEvent('dps-trains:announce', index, phase)
end

CreateThread(function()
    while true do
        local wait = 2000

        if onTrain() then
            wait = 700
            local me = GetEntityCoords(PlayerPedId())
            -- Nearest station wins, so two platforms close together cannot both fire.
            local bestIndex, bestDist
            for i = 1, #Stations do
                local d = #(me - Stations[i].coords)
                if not bestDist or d < bestDist then
                    bestIndex, bestDist = i, d
                end
            end
            if bestIndex then
                if bestDist <= ARRIVE_AT then
                    ask(bestIndex, 'arriving')
                elseif bestDist <= NEXT_AT then
                    ask(bestIndex, 'next')
                end
            end
        end

        Wait(wait)
    end
end)
