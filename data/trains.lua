-- Generated from dps-trains-stock/data/trains.xml.
-- index is the ABSOLUTE variation number: TRAINCONFIGS_FILE appends after
-- the 28 vanilla configs, so these start at 28.
--
-- REGENERATE THIS WHENEVER A CONSIST CHANGES. client/main.lua preloads
-- exactly these models per variation; if the list is stale the client
-- loads the wrong stock and CREATE_MISSION_TRAIN fails with
-- "carriage hash '...' is not loaded".
return {
  {
   index = 28,   -- passenger_config01
   models = {
    `streakcoaster`,
    `streakcoasterc`,
    `streakcoastercab`,
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
