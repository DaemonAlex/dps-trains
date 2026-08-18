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

client_scripts {
    'client/main.lua',
    'client/drive.lua'
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
    'server/parser/trains.lua'
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