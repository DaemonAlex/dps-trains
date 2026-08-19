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

-- NO data_file 'TRAINCONFIGS_FILE' HERE, deliberately.
--
-- Registering trains.xml from this resource crashed clients on join with an
-- access violation inside the game's parser:
--   "An exception occurred (c0000005) during loading of
--    resources:/dps-trains/trains.xml in data file mounter"
--
-- The file itself is sound - all 31 models it names are declared in
-- trainsoverhauled/data/vehicles.meta. The difference from the working setup
-- is WHERE it is registered: the pack ships TRAINCONFIGS_FILE inside the same
-- map resource as its models, while this is a plain script resource in a
-- category that loads earlier.
--
-- Without a registered consist table the game only knows its own 28 vanilla
-- configs (0-27), so configs/*.lua must use variation indices in that range.
-- configs/metro.lua puts it plainly: an invalid variation index crashes
-- clients that are not on canary.


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