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

-- Registers the custom consists. Without this the game only knows the 28
-- vanilla train configs (0-27) and CREATE_MISSION_TRAIN rejects any variation
-- above 27, so every mainline spawn failed with "Invalid train variation index
-- was passed to CREATE_MISSION_TRAIN (28)". The resource parses trains.xml
-- itself server-side, so it believed the consists existed while the game did
-- not - which is why trains tracked fine but never materialised.
--
-- TRAINCONFIGS_FILE APPENDS to the vanilla table, so our 18 configs land at
-- 28-45: 28 = passenger_config01 (Amtrak), 29 = passenger_config02
-- (brownstreak), 30 = freight_config01 (mixed freight).
data_file 'TRAINCONFIGS_FILE' 'trains.xml'

shared_script '@ox_lib/init.lua'

client_scripts {
    'client/main.lua',
    'client/stationblips.lua',  -- DPS: small short-range STOP blips only; no moving vehicle blips
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