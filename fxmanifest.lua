fx_version 'cerulean'
use_experimental_fxv2_oal 'yes'
lua54 'yes'
game 'gta5'

name 'dps-trains'
author 'Ehbw (ethan@ehbw.uk)'  -- upstream engine, integrated for DPS
version '1.0.0'

description 'DPS train system - Ehbw engine driving BigDaddy Trains Overhauled rolling stock'

dependencies
{
    '/server:10188',
    '/onesync',
    'ox_lib'
}

shared_script '@ox_lib/init.lua'

shared_script 'shared/stations.lua'  -- DPS 2026-10-31: one station list for both the client's proximity test and the server's names, so they cannot drift apart

client_scripts {
    'client/main.lua',
    'client/stationblips.lua',  -- DPS: small short-range STOP blips only; no moving vehicle blips
    'client/drive.lua',
    'client/announce.lua'   -- DPS 2026-10-31: metro station announcements, spoken through dps-voice
}

files {
    'configs/*.lua',
    'config.lua',
    'client/bridge/*.lua',
    'data/trains.lua',
    "locales/*.json"
}

server_scripts
{
    'server/CTracks.lua',
    'server/CTrain.lua',
    'server/main.lua',
    'server/parser/tracks.lua',
    'server/parser/trains.lua',
    'server/announce.lua'   -- DPS 2026-10-31: turns a station number into one spoken line
}

escrow_ignore
{
    'server/parser/xmlparser.lua',
    'configs/*.lua',
    'config.lua',
    'data/*.lua',
    'types.lua',
    'client/bridge/*.lua'
}