-- DPS: map blips for train stations (train blips themselves stay hidden)
local STATIONS = {
    -- main line (track 0)
    { name = 'Lumber Mill Station',   coords = vec3(-446.82, 5362.51, 80.67) },
    { name = 'Paleto Bay Station',    coords = vec3(111.85, 6317.60, 30.69) },
    { name = 'Quarry Station',        coords = vec3(2599.30, 2912.57, 38.57) },
    { name = 'Wind Farm Station',     coords = vec3(2450.27, 2482.35, 41.07) },
    { name = 'Power Plant Station',   coords = vec3(2610.99, 1649.71, 26.62) },
    { name = 'Downtown Station',      coords = vec3(669.27, -1104.79, 22.74) },
    { name = 'Port Depot Station',    coords = vec3(217.43, -2436.63, 6.21) },
    { name = 'Sandy Shores Depot',    coords = vec3(1870.67, 3544.59, 37.67) },
    -- metro (track 3) - surface entrances only, tunnels excluded
    { name = 'Metro: Strawberry',     coords = vec3(243.68, -1198.62, 37.05), metro = true },
    { name = 'Metro: Little Seoul',   coords = vec3(-549.43, -1290.78, 24.91), metro = true },
    { name = 'Metro: LSIA West',      coords = vec3(-1104.42, -2728.99, -9.32), metro = true },
    { name = 'Metro: LSIA East',      coords = vec3(-1067.23, -2708.14, -9.32), metro = true },
    { name = 'Metro: Burton',         coords = vec3(-287.12, -301.92, 8.15), metro = true },
    { name = 'Metro: Portola Drive',  coords = vec3(-848.52, -148.13, 18.04), metro = true },
}

CreateThread(function()
    for _, s in ipairs(STATIONS) do
        local blip = AddBlipForCoord(s.coords.x, s.coords.y, s.coords.z)
        SetBlipSprite(blip, 795)                     -- train icon
        SetBlipColour(blip, s.metro and 3 or 0)      -- metro blue, mainline white
        SetBlipScale(blip, 0.65)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(s.name)
        EndTextCommandSetBlipName(blip)
    end
end)


-- DPS seat-mapping tool: stand at a seat position inside a carriage, run
-- /seatmark - prints your offset relative to the nearest train carriage to the
-- server console so seat lists can be authored for passenger coaches.
RegisterCommand('seatmark', function()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local best, bestDist = nil, 30.0
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if GetVehicleClass(veh) == 21 then  -- trains
            local d = #(GetEntityCoords(veh) - pos)
            if d < bestDist then best, bestDist = veh, d end
        end
    end
    if not best then
        print('[seatmark] no train carriage within 30m')
        return
    end
    -- walk the chain to find the specific carriage we are closest to
    local carriage, ci = best, 0
    for i = 0, 12 do
        local c = GetTrainCarriage(best, i)
        if not c or c == 0 or not DoesEntityExist(c) then break end
        local d = #(GetEntityCoords(c) - pos)
        if d < #(GetEntityCoords(carriage) - pos) then carriage, ci = c, i end
    end
    local off = GetOffsetFromEntityGivenWorldCoords(carriage, pos.x, pos.y, pos.z)
    local relHeading = (GetEntityHeading(ped) - GetEntityHeading(carriage)) % 360.0
    local model = GetEntityArchetypeName(carriage) or 'unknown'
    TriggerServerEvent('dps-trains:seatmark',
        ('model=%s carriage=%d vec4(%.4f, %.4f, %.4f, %.4f)'):format(model, ci, off.x, off.y, off.z, relHeading))
    print(('[seatmark] logged: %s carriage %d offset %.2f %.2f %.2f'):format(model, ci, off.x, off.y, off.z))
end, false)


-- DPS: /board - put the player in the first free seat of the nearest coach.
-- Fallback for when native LAYOUT_BUS entry misbehaves; works while moving.
RegisterCommand('board', function()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local best, bestDist = nil, 12.0
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if GetVehicleClass(veh) == 21 then
            -- check each carriage of the chain, not just the engine
            for i = -1, 12 do
                local c = (i == -1) and veh or GetTrainCarriage(veh, i)
                if c and c ~= 0 and DoesEntityExist(c) then
                    local d = #(GetEntityCoords(c) - pos)
                    if d < bestDist then best, bestDist = c, d end
                end
            end
        end
    end
    if not best then
        print('[board] no train carriage within 12m')
        return
    end
    local seats = GetVehicleModelNumberOfSeats(GetEntityModel(best))
    for seat = 0, seats - 2 do
        if IsVehicleSeatFree(best, seat) then
            TaskWarpPedIntoVehicle(ped, best, seat)
            print(('[board] seated: seat %d of %d'):format(seat, seats - 1))
            return
        end
    end
    print('[board] no free seats in this carriage')
end, false)

-- and the exit: /disembark from wherever you are seated
RegisterCommand('disembark', function()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 0)
    end
end, false)
