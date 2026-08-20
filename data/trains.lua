-- Generated from dps-trains-stock/data/trains.xml.
-- index is the ABSOLUTE variation number the game uses: TRAINCONFIGS_FILE
-- appends after the 28 vanilla configs, so these are 28+.
-- client/main.lua reads variations[data.variation], so if these indices do
-- not match, every lookup misses and it falls back to loading EVERY model
-- in config.trainModels - which stalls creation on any model not streamed.
return {
  {
   index = 28,   -- passenger_config01
   models = {
    `streakcoaster`,
    `streakc`,
   },
  },
  {
   index = 29,   -- passenger_config02
   models = {
    `streak`,
    `streakc`,
    `streakcab`,
   },
  },
  {
   index = 30,   -- freight_config01
   models = {
    `sd70mac`,
    `freightflat`,
    `freightflatlogs`,
    `freighttanklong`,
    `freightgondola`,
    `freightcaboose`,
   },
  },
  {
   index = 31,   -- metro_config01
   models = {
    `metrotrain`,
   },
  },
}
