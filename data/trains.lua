-- Generated from dps-trains-stock/data/trains.xml.
-- REGENERATE WHENEVER A CONSIST CHANGES OR THE GAME BUILD MOVES THE VANILLA TABLE.
return {
  {
   -- Vanilla metro on game build 3095 (3570 had it at 28). configs/metro.lua
   -- computes this index; the custom consists below start one after it
   -- because TRAINCONFIGS_FILE appends after the vanilla table.
   index = 28,   -- vanilla metro (2026-10-21, build 3889: one more vanilla config since 3407)
   models = {
    `metrotrain`,
   },
  },
  {
   index = 29,   -- passenger_config01
   models = {
    `streakcoaster`,
    `streakc`,
    `streakcab`,
   },
  },
  {
   index = 30,   -- passenger_config02
   models = {
    `streak`,
    `streakcoastercab`,
   },
  },
  {
   index = 31,   -- freight_config01
   models = {
    `sd70mac`,
    `freightflat`,
    `freightcaboose`,
   },
  },
  {
   index = 32,   -- metro_config01
   models = {
    `metrotrain`,
   },
  },
  {
   -- Roxwood regional passenger (2026-09-15). The models stream from
   -- [maps]/[roxwood-county]/amb-roxwood-trains (escrowed); the consist is
   -- defined in dps-trains-stock as the fifth appended consist.
   index = 33,   -- rox_passenger_config01
   models = {
    `amb_statrac_loc`,
    `streakc`,
    `streakcab`,
   },
  },
}
