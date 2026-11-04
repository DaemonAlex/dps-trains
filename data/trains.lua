-- Generated from dps-trains-stock/data/trains.xml.
-- REGENERATE WHENEVER A CONSIST CHANGES OR THE GAME BUILD MOVES THE VANILLA TABLE.
return {
  {
   -- Vanilla metro on game build 3095 (3570 had it at 28). configs/metro.lua
   -- computes this index; the custom consists below start one after it
   -- because TRAINCONFIGS_FILE appends after the vanilla table.
   index = 27,   -- vanilla metro (DPS 2026-10-29: shifted down one for build 3095; the 3889 table had one more vanilla config)
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
   -- DPS 2026-10-29: Bombardier Flexity tram, lrt_config01 in dps-trains-stock (models in [vehicles]/elrt-tram).
   index = 32,   -- lrt_config01 (was 33: the Roxwood consist above it was removed 31 Oct)
   models = {
    `elrtcab`,
    `elrtpassenger`,
    `elrtmiddle`,
    `elrtcabrear`,
   },
  },
}
