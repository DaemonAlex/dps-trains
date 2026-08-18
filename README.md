# dps-trains

The Del Perro Sands railway system: scheduled metro, passenger, and freight
service with real station stops across the whole map.

Originally forked from [Ehbw-Trains](https://github.com/Ehbw); substantially
modified for DPS. Credit to the upstream author for the core train tracking
and track-node architecture.

## The DPS glossary

| Term | Meaning |
|---|---|
| **Metro train** | Light rail on the city line (track 3, `metrotrain` model) |
| **Passenger train** | Streak/coaster consists on the main heavy-rail loop (track 0) |
| **Freight train** | Mixed-manifest cargo consist, also on the main loop |

Service pattern: **2 metros** on the city line, **2 passenger + 1 freight**
rotating the main loop. All consists are capped at **9 cars** (longer trains
destabilize under OneSync — they visibly blink in and out).

## What DPS added over upstream

- **Full station-stop cycle** (`server/CTrain.lua`): upstream only slowed
  trains near stations. DPS trains now decelerate, stop at the platform,
  open doors (passenger/metro only — set per spawn via `doors = true` in
  `configs/freight.lua`), hold for `config.stationDwellTime`
  (`configs/general.lua`, default 3 minutes), close up, and depart.
  Each train tracks its last-served station so it cannot re-trigger on
  itself while pulling away.
- **Custom stations on the main loop** (`data/tracks-0.lua`): Lumber Mill,
  Paleto Bay, Quarry, Wind Farm, Power Plant, Downtown, Depot.
- **Custom consists** via the BigDaddy trains pack (`dps-trains-stock`).
- Train map blips disabled (`config.showTrainBlips` in `general.lua`).

## Sharp edges (read before editing)

1. **`TRAINCONFIGS_FILE` APPENDS to the vanilla consist table — it does not
   replace it.** On gamebuild 3258 the vanilla table is indices 0-28, so the
   custom consists in `dps-trains-stock/data/trains.xml` start at **29**:
   `29` = passenger 1, `30` = passenger 2, `31` = freight. The metro uses the
   *vanilla* metro index, computed per-gamebuild in `configs/metro.lua`.
2. **trains.xml changes require players to RELOG.** The game ingests train
   configs once at join; resource restarts do not reload consists for
   connected clients.
3. **Trains are client-created** (`useServerSetter = false`): a train only
   spawns once a player is within ~424m of its start location
   (`configs/freight.lua` / `configs/metro.lua` startLocations). After
   creation it persists and runs its loop.
4. **CfxLua syntax** (backtick hashes, `+=`) appears in the configs — vanilla
   `luac` cannot parse these files; mask before syntax-checking.

## Admin / debug

- `setr ox:printlevel:dps-trains debug` — verbose train lifecycle logging.
- `parseTrainNode` / `parseTrainConfig` — upstream track-authoring tools.
- Players can drive trains where `enablePlayerDriving` allows it.
