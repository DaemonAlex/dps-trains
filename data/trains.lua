-- Generated from dps-trains-stock/data/trains.xml.
-- REGENERATE WHENEVER A CONSIST CHANGES OR THE GAME BUILD MOVES THE VANILLA TABLE.
return {
  {
   -- Vanilla metro on game build 3095 (3570 had it at 28). configs/metro.lua
   -- computes this index; the custom consists below start one after it
   -- because TRAINCONFIGS_FILE appends after the vanilla table.
   index = 27,   -- vanilla metro (2026-09-15, build 3095)
   models = {
    `metrotrain`,
   },
  },
  {
   index = 28,   -- passenger_config01
   models = {
    `streakcoaster`,
    `streakc`,
    `streakcab`,
   },
  },
  {
   index = 29,   -- passenger_config02
   models = {
    `streak`,
    `streakcoastercab`,
   },
  },
  {
   index = 30,   -- freight_config01
   models = {
    `sd70mac`,
    `freightflat`,
    `freightcaboose`,
   },
  },
  {
   index = 31,   -- metro_config01
   models = {
    `metrotrain`,
   },
  },
  {
   -- Roxwood regional passenger (2026-09-15). The models stream from
   -- [maps]/[roxwood-county]/amb-roxwood-trains (escrowed); the consist is
   -- defined in dps-trains-stock as the fifth appended consist.
   index = 32,   -- rox_passenger_config01
   models = {
    `amb_statrac_loc`,
    `streakc`,
    `streakcab`,
   },
  },
}
