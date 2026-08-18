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
