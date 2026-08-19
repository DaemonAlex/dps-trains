-- DPS: map blips for train stations (train blips themselves stay hidden)
local STATIONS = {
    -- names MATCH the Transit phone app exactly
    { name = 'Lumber Mill',       coords = vec3(-446.82, 5362.51, 80.67) },
    { name = 'Paleto Bay',        coords = vec3(111.85, 6317.60, 30.69) },
    { name = 'Quarry',            coords = vec3(2599.30, 2912.57, 38.57) },
    { name = 'Wind Farm',         coords = vec3(2450.27, 2482.35, 41.07) },
    { name = 'Power Plant',       coords = vec3(2610.99, 1649.71, 26.62) },
    { name = 'Downtown',          coords = vec3(669.27, -1104.79, 22.74) },
    { name = 'Port Depot',        coords = vec3(217.43, -2436.63, 6.21) },
    { name = 'Sandy Shores',      coords = vec3(1870.67, 3544.59, 37.67) },
    { name = 'Strawberry',        coords = vec3(243.68, -1198.62, 37.05), metro = true },
    { name = 'Little Seoul',      coords = vec3(-549.43, -1290.78, 24.91), metro = true },
    { name = 'Puerto Del Sol',    coords = vec3(-900.24, -2343.76, -13.65), metro = true },
    { name = 'LSIA West',         coords = vec3(-1104.42, -2728.99, -9.32), metro = true },
    { name = 'LSIA East',         coords = vec3(-1067.23, -2708.14, -9.32), metro = true },
    { name = 'Rockford South',    coords = vec3(-866.52, -2294.89, -13.63), metro = true },
    { name = 'Little Seoul East', coords = vec3(-528.64, -1267.25, 24.90), metro = true },
    { name = 'Davis',             coords = vec3(284.76, -1209.94, 37.12), metro = true },
    { name = 'Burton',            coords = vec3(-287.12, -301.92, 8.15), metro = true },
    { name = 'Portola Drive',     coords = vec3(-848.52, -148.13, 18.04), metro = true },
}

-- Declared BEFORE the thread that fills it. It was previously declared further
-- down the file, so the thread indexed a nil global and every station blip
-- failed with "attempt to get length of a nil value".
local stationBlips = {}

CreateThread(function()
    for _, s in ipairs(STATIONS) do
        local blip = AddBlipForCoord(s.coords.x, s.coords.y, s.coords.z)
        stationBlips[#stationBlips + 1] = blip
        SetBlipSprite(blip, 795)                     -- train icon
        SetBlipColour(blip, s.metro and 3 or 0)      -- metro blue, mainline white
        SetBlipScale(blip, 0.5)   -- small: wayfinding, not map furniture
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(s.name)
        EndTextCommandSetBlipName(blip)
    end
end)

-- track blips so a resource restart (without a client reconnect) doesn't orphan them
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, b in ipairs(stationBlips) do if DoesBlipExist(b) then RemoveBlip(b) end end
end)
