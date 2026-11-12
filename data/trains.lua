-- Generated from dps-trains-stock/data/trains.xml.
-- DPS 2026-11-02: metro_config01 now loads facametrotrain (Rags metro; carriage swapped in dps-trains-stock trains.xml same day).
-- DPS 2026-11-01: EVERY index here is +1 from the 10-29 values. Those were written
-- for game build 3095; the server moved to 3570 on 10-30, which has one more vanilla
-- consist before the metro, and nobody moved this file - the metro then loaded the
-- passenger consist's models and the tram loaded nothing ("carriage hash not loaded").
-- configs/metro.lua computes its indices from the build; this file must match it:
-- at 3570 the vanilla metro is 28 and lrt_config01 is 33.
-- REGENERATE WHENEVER A CONSIST CHANGES OR THE GAME BUILD MOVES THE VANILLA TABLE.
return {
  {
   -- Vanilla metro on game build 3095 (3570 had it at 28). configs/metro.lua
   -- computes this index; the custom consists below start one after it
   -- because TRAINCONFIGS_FILE appends after the vanilla table.
   index = 28,   -- vanilla metro (DPS 2026-10-29: shifted down one for build 3095; the 3889 table had one more vanilla config)
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
    `facametrotrain`,
   },
  },
  {
   -- DPS 2026-11-10 (Damon: "use the default tram and we'll repaint it"): lrt_config01 in dps-trains-stock now runs the game's
   -- own tram, two cars; the Flexity set (elrt-tram) left the server over the asset limit.
   index = 33,   -- lrt_config01
   models = {
    `tram`,
   },
  },
}
