--- SHARED. Every station on every passenger line, in one list.
---
--- Announcements used to be tied to the tram's own models, which meant they followed
--- the vehicle rather than the route: move the tram to another line and the metro
--- stations went with it. They are tied to PLACE instead now. Whatever train you are
--- riding, you hear the station you are actually approaching, so swapping stock
--- between lines changes nothing here.
---
--- The client reads coords to find the station it is nearing and sends only its
--- number. The server reads the name for that number. No text crosses the wire.

Stations = {
    --- Light rail / downtown metro (track 3)
    { line = 'metro',   name = 'Strawberry',               coords = vec3(243.68, -1198.62, 37.05) },
    { line = 'metro',   name = 'Davis',                    coords = vec3(284.76, -1209.94, 37.12) },
    { line = 'metro',   name = 'Little Seoul',             coords = vec3(-549.43, -1290.78, 24.91) },
    { line = 'metro',   name = 'Little Seoul East',        coords = vec3(-528.64, -1267.25, 24.90) },
    { line = 'metro',   name = 'Puerto Del Sol',           coords = vec3(-900.24, -2343.76, -13.65) },
    { line = 'metro',   name = 'Industrial',               coords = vec3(-876.27, -2432.50, -13.65) },
    { line = 'metro',   name = 'Rockford South',           coords = vec3(-866.52, -2294.89, -13.63) },
    { line = 'metro',   name = 'LSIA West',                coords = vec3(-1104.42, -2728.99, -9.32) },
    { line = 'metro',   name = 'LSIA East',                coords = vec3(-1067.23, -2708.14, -9.32) },
    { line = 'metro',   name = 'Burton',                   coords = vec3(-287.12, -301.92, 8.15) },
    { line = 'metro',   name = 'Portola Drive',            coords = vec3(-848.52, -148.13, 18.04) },
    { line = 'metro',   name = 'Del Perro',                coords = vec3(-1342.68, -495.26, 13.13) },
    { line = 'metro',   name = 'Vespucci Boulevard',       coords = vec3(-472.72, -680.61, 9.90) },
    { line = 'metro',   name = 'Pillbox South',            coords = vec3(-222.64, -1044.90, 28.33) },

    --- Country mainline (track 0). Duplicate passes through the same platform are one
    --- station here: a passenger does not want to hear Downtown twice in a lap.
    { line = 'country', name = 'Lumber Mill',              coords = vec3(-446.82, 5362.51, 80.67) },
    { line = 'country', name = 'Paleto Bay',               coords = vec3(183.54, 6357.59, 31.72) },
    { line = 'country', name = 'The Quarry',               coords = vec3(2610.66, 2928.04, 39.84) },
    { line = 'country', name = 'Wind Farm',                coords = vec3(2450.27, 2482.35, 41.07) },
    { line = 'country', name = 'Power Plant',              coords = vec3(2610.99, 1649.71, 26.62) },
    { line = 'country', name = 'Downtown',                 coords = vec3(669.273, -1104.79, 22.74) },
    { line = 'country', name = 'Port Depot',               coords = vec3(217.427, -2436.63, 6.21) },
    { line = 'country', name = 'Downtown Los Santos',      coords = vec3(680.07, -617.98, 25.50) },
    { line = 'country', name = 'Market Square',            coords = vec3(553.82, -1441.37, 21.78) },
    { line = 'country', name = 'Sandy Shores Depot',       coords = vec3(1870.67, 3544.59, 37.67) },
}
