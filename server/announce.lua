-- SERVER. Turns a station number from a passenger's client into one spoken line,
-- addressed to that passenger only. The text is ours; nothing a player types gets here.
--
-- The names live in shared/stations.lua alongside their coordinates, so the list the
-- client measures against and the list the server reads from cannot drift apart.

local ROLE     = 'transit'   -- the voice itself lives in dps-voice Config.roleVoices
local COOLDOWN = 20          -- seconds per player per station per phase

local said = {}              -- src -> { [key] = os.time() }

local PHRASES = {
    next     = function(name) return ('Next station, %s.'):format(name) end,
    arriving = function(name) return ('Now arriving at %s.'):format(name) end,
}

RegisterNetEvent('dps-trains:announce', function(index, phase)
    local src = source
    if type(index) ~= 'number' then return end
    index = math.floor(index)
    local station = Stations[index]
    if not station then return end
    local phrase = PHRASES[phase]
    if not phrase then return end

    local key = index .. ':' .. phase
    said[src] = said[src] or {}
    local now = os.time()
    if said[src][key] and (now - said[src][key]) < COOLDOWN then return end
    said[src][key] = now

    exports['dps-voice']:Say({
        text    = phrase(station.name),
        role    = ROLE,
        targets = src,
        volume  = 0.85,
    })
end)

AddEventHandler('playerDropped', function()
    said[source] = nil
end)
