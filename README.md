# dps-trains

The DelPerroSands railway: a scheduled passenger service on the heavy-rail
loop and a metro on the city line, with real station stops, live arrival times
on the phone, and trains that run to a timetable whether or not anyone is
watching them.

Forked from [Ehbw-Trains](https://github.com/Ehbw) and substantially rewritten.
Credit to the upstream author for the track-node architecture and train
tracking that everything here is built on.

## What it is for

GTA trains in FiveM are scenery. They pass at random, they do not stop for you,
and nobody can say when the next one comes. This script turns them into public
transport. Trains run to a timetable, stop at every station, open their doors
and wait. A player can plan a trip across the map without a car.

## The four resources

The railway is four resources with one job each. Only `dps-trains` and
`dps-trains-stock` are required; the other two are optional layers on top.

```
dps-trains-stock   assets      models, consists, TRAINCONFIGS_FILE
       │
dps-trains         engine      scheduling, movement, station stops   <- you are here
       ├──────────────────────▶ dps-traintools    players     boarding, seating, riders
       └──getArrivalBoard()───▶ dps-transitapp    passengers  live arrivals on the phone
```

| Resource | Needs | Works without the others? |
|---|---|---|
| `dps-trains-stock` | nothing | yes — it is pure assets |
| `dps-trains` | `ox_lib`, `dps-trains-stock` | yes, but with no custom rolling stock |
| `dps-traintools` | `ox_lib` | yes — it works on any train entity, vanilla included |
| `dps-transitapp` | `lb-phone`, `ox_lib`, `dps-trains` | no — it is a view of `getArrivalBoard` |

There is a fifth, small one: `dps-traintracks`. It holds extra track data and
has no scripts. See below.

## On its own, and with other scripts

**On its own.** With `ox_lib` and `dps-trains-stock` you get the whole service.
Light rail trains run on the city line and trains run on the country mainline.
They stop at stations, open their doors, and carry an NPC driver. Small station
blips show on the map. Staff get `traindebug`, `boarddebug` and `trainspace` in
the server console.

**With a paid train pack (BigDaddy Trains Overhauled).** `dps-trains-stock` is
the models and carriage sets from that pack, with the pack's own scripts taken
out. dps-trains only asks the game for a carriage set by number. It calls no
code from the pack. When the pack updates its models, copy the new files into
`dps-trains-stock`. The engine keeps working as long as the carriage sets stay
in the same order in `data/trains.xml`.

**With dps-traintools.** Players get an "[E] Board Train" prompt at stations, a
seat on the carriage, and NPC passengers in the coaches. dps-traintools does
not call dps-trains. It works on any train it can see, so you can restart it
without resetting the trains.

**With a paid phone (lb-phone) and dps-transitapp.** Players get a Transit app
with live arrival times for every station. The app reads one export from this
script, `getArrivalBoard`. dps-trains never calls lb-phone, so a phone update
cannot break the trains.

**With dps-voice.** A rider hears "Next station, Davis" and "Now arriving at
Davis". Only the rider hears it. dps-trains sends the line to `dps-voice`
through its `Say` export. Without dps-voice there is no announcement, and the
server console logs an export error each time one is asked for.

**With ox_target.** The third eye shows "drive train" at the cab and "sit" in a
metro carriage. The bridge in `client/bridge/ox_target.lua` loads only when
`ox_target` is started.

**With a paid cable car (rtx_cablecar).** The game counts a cable car as a
train, and dps-trains deletes trains it did not create. The `cablecar` model
and the `rtx_cablecar` resource are on a protected list in
`configs/general.lua`, so the cable car is left alone. dps-trains calls nothing
in that script.

**With dps-traintracks.** That resource adds one extra track to the game.
dps-trains can run trains on it when the track number is in
`config.usedTracks`. Since 29 October 2026 it is not in the list, so no train
runs there now.

**How the rail scripts fit together.** `dps-trains-stock` says what a train is
made of. `dps-traintracks` adds track. `dps-trains` moves the trains and stops
them at stations. `dps-traintools` puts players on board. `dps-transitapp`
shows arrival times on the phone.

## Requirements

| | |
|---|---|
| Server artifact | **10188 or newer** |
| OneSync | **required** — declared in the manifest |
| `ox_lib` | required |
| `lb-phone` | only for `dps-transitapp` |
| Game build | 3258 or newer |

`useServerSetter` **cannot** be enabled on current artifacts — the `CREATE_TRAIN`
native is absent, and turning it on makes this resource refuse to start. Trains
are therefore created by nearby clients; see [How a train actually works](#how-a-train-actually-works).

## Installation

1. **Drop all four resources** into your resources folder. `dps-trains-stock` is
   ~300 MB of models — expect a first-join download.

2. **Start them in this order.** `dps-trains-stock` must register the consist
   table before `dps-trains` reads it:

   ```cfg
   ensure ox_lib
   ensure dps-trains-stock
   ensure dps-trains
   ensure dps-traintools     # optional
   ensure lb-phone
   ensure dps-transitapp     # optional
   ```

   If they live in a category folder that is `ensure`d as a whole, alphabetical
   order already puts `dps-trains` before `dps-trains-stock` — which is the wrong
   way round. Start them explicitly.

3. **Check the consist indices line up.** `configs/metro.lua` references
   variations by number, and those numbers come from
   `dps-trains-stock/data/trains.xml`. An index the game does not have **crashes
   clients**. The file works the numbers out from the game build: first the
   vanilla metro, then the custom sets counted on from it. If you add or remove
   a set in `trains.xml`, change the offsets at the top of `startLocations`.

4. **Reboot and rejoin.** Consist data is ingested by the client at join —
   resource restarts do not reload it.

5. **Verify** with `traindebug` in the server console. You should see one line
   per train with a node that advances between calls. `handle=nil` is normal for
   a train with no player near it.

## Configuration

| File | What it controls |
|---|---|
| `configs/metro.lua` | every running train: where it starts, which consist, which track. An entry with `index = 0` runs on the country mainline. The rest run on the light rail (track 3). |
| `configs/freight.lua` | freight trains. Off (`config.enabled = false`). |
| `configs/general.lua` | line speed, dwell time, skipped stations, model preload list |
| `server/main.lua` | station names, keyed by node |

A start location is a coordinate (`coords`) or a node index (`node`). The train
snaps to the nearest track node, so spacing is exact. Use
`trainspace <track> <count>` to generate evenly spaced ones.

To change the number of trains, edit `startLocations` in `configs/metro.lua`.
`config.count` is the upper limit. It must not be lower than the number of
entries.

## Service

| | |
|---|---|
| **Country mainline** (track 0) | 3 trains, the tram set (`lrt_config01` in `dps-trains-stock`), 23.1 m/s (~52 mph) |
| **Light rail** (track 3) | 3 trains, the yellow Los Santos metro (vanilla), 20.1 m/s (~45 mph) |
| **Freight** | off |
| **Speed ceiling** | 30 m/s (~67 mph) |
| **Station dwell** | 30 s |
| **Calling points** | 10 on the mainline |

All six trains are set in `configs/metro.lua`. The **Axsellya Express** (blue)
and **Brown Streak** (brown) sets are still in `dps-trains-stock`, but no train
runs them now. There is no freight service. Every train stops and opens its
doors. A freight consist stopped but never opened, which reads as broken to a
player who does not know why.

### Calling points

Node numbers are from `data/tracks-0.lua`.

```
 462  Lumber Mill                 2667  Port Depot
 659  Paleto Bay                  2792  Market Square (northbound only)
1464  Quarry                      2925  Downtown LS (Northbound)
1701  Power Plant                 3891  Quarry (return pass)
2357  Downtown LS (Southbound)    4159  Sandy Shores
```

Quarry and Downtown LS each appear twice because the line calls at them **in
both directions**. They are the same station, not duplicates. Downtown LS and
Market Square were added on 29 September 2026. The two older Downtown passes
(nodes 2434 and 2865, named Davis Interchange on the arrival board) were
removed the same day and are skipped the same way as Wind Farm.

**Wind Farm (node 1555) is skipped**, via `config.general.skipStations`. It sat
520 m from Quarry, so with braking starting 500 m out a train decelerated across
the entire gap and never reached line speed between them. Stations come from the
game's own track data and cannot be deleted — only ignored.

## How a train actually works

A train exists in one of two states, and the difference is the source of most
bugs in this resource.

**Ghost** — no entity, just a position the server advances. This is what makes
the timetable honest: a train is somewhere specific even when nobody is near it,
so when you reach a platform the service is where it should be.

**Materialised** — a real entity, created by a nearby client. FiveM has no
server-side entity ownership for trains on this artifact (`CREATE_TRAIN` is
absent — `useServerSetter` cannot be enabled), so a train can only exist while a
player is within ~424 m to own it.

The two states must behave identically or the service falls apart:

- **Ghosts advance by distance covered**, not one node per tick. One node per
  tick on a 1-second interval is ~7 m/s, against a materialised train's 30 — the
  same service ran four times faster whenever somebody watched it.
- **Ghosts observe station dwells too.** The station cycle lives inside
  `if self.handle`, so ghosts used to skip every platform. That made trains
  materialise *past* the station a player was standing at, and meant only
  observed trains lost dwell time — which is what made the fleet bunch.
- **Ghosts obey headway holds** (2026-08-28). A held ghost simply stops
  advancing. Before this, a ghost could drive straight through the (usually
  dwelling) train ahead, swapping running order and permanently pairing
  services.
- **Ghosts pay the braking bill.** A materialised train loses ~25 s per stop to
  the 500 m braking ramp and the acceleration back to line speed; a ghost stops
  instantly, so it holds that long extra at each platform to stay on the same
  clock.
- **Every stop is gap-regulated** — ghost or materialised, `DPS_RegulatedDwell`
  scales the dwell at the moment the stop begins: bunched trains hold up to 2×
  and drop back into slot, a train with an oversized gap ahead cuts to 0.4× and
  catches up. The old regulation only ever saw materialised trains, so the
  fleet ran unregulated whenever nobody was near it — which is most of the
  time.

## Sharp edges

**Regenerate `data/trains.lua` whenever a consist changes.** It is generated
from `dps-trains-stock/data/trains.xml` and tells the client which models to
preload per variation. A stale list makes the client load the wrong stock and
train creation fails with `carriage hash '...' is not loaded`.

**Model names do not match liveries.** Established in game, not inferred:

```
BLUE (Amtrak)   streakcoaster (loco) · streakc · streakcab
BROWN           streak (loco) · streakcoastercab
```

The `coaster`-named cab car is the **brown** coach; plain `streakc`/`streakcab`
are Amtrak stock. Pairing carriages with the similarly-named locomotive gives a
mismatched rake every time.

**`TRAINCONFIGS_FILE` appends to the vanilla table.** Vanilla is indices 0–27,
so the custom consists start at **28**: `28` Axsellya, `29` Brown Streak,
`30` freight (unused), `31` metro. **It is registered by `dps-trains-stock`, not
here** — registering it from this resource crashes clients on join with an
access violation inside the game's parser.

Those numbers are for a game build where the vanilla metro is 27 (builds 3095
to 3406). From build 3407 the game has one more vanilla set, so every number
moves up one. `configs/metro.lua` computes the numbers from the build, so the
trains follow a build change without an edit.

**An invalid variation index crashes clients** that are not on canary. There is
no graceful failure.

**Speed control is asymmetric.** `SetTrainCruiseSpeed` sets a target the engine
works toward, giving natural acceleration and braking. `SetTrainSpeed` forces
velocity instantly. Applied to every change it makes trains leap off the mark
and slam to lower speeds; applied *only* to a commanded stop it is
imperceptible, because staged braking has the train at ~3 m/s by then. A cruise
target of zero does not stop a moving train — that single fact caused station
stops, headway holds and bunching to fail simultaneously.

**Station coordinates sit well off the rails** — 51 m at Lumber Mill, 76 m at
Davis Interchange Northbound even at closest approach. A pure distance test for
"at the platform" is unreachable at some stops, so the trigger also matches the
station **node**, within **1 node** and only on the approach side (was 5 nodes
/ 22 m, which parked trains up to ~35 m short of city platforms — by trigger
time staged braking has the train at 3 m/s, so the 1-second server sampling
covers ~3 m per tick and cannot step over the window).

**Private fields are not writable from outside the class.** `server/main.lua`
cannot assign to `train.private.*`; doing so throws and aborts that pass of the
update loop. Headway holds and dwell regulation both did this and had never
executed successfully. Keep per-train flags in module-local tables keyed by id.

**30 m/s is a hard ceiling.** `CTrainGameStateDataNode` cannot represent a
higher cruise speed, so anything above it desyncs trains between clients
regardless of `unlimitSpeed`. Note `server/main.lua` reads
`config.general.defaultSpeed`, **not** `config.freight.speed`.

**Reboot rather than restarting the resource.** There is an `onResourceStop`
handler that deletes this resource's trains, but data-file changes
(`TRAINCONFIGS_FILE`, `VEHICLE_METADATA_FILE`) are cached and need a full boot
plus a client rejoin.

**CfxLua syntax** (backtick hashes, `+=`) appears throughout — vanilla `luac`
cannot parse these files, so mask before syntax-checking:

```sh
sed 's/`[A-Za-z0-9_]*`/0x1234/g; s/+=/=/g; s/?\./\./g' file.lua > /tmp/x.lua
luac5.4 -p /tmp/x.lua
```

## Safeguards

- **Headway hold** — a train within 40 nodes of the one ahead stops until the
  gap clears. Applies to ghosts too (they hold by not advancing), and the hold
  is visible on `private.headwayHold` via `Train:SetHeadwayHold`, so the
  arrival board can show "delayed" and the speed logic cannot fight it.
- **Physical separation — removed.** It held a train whenever another was
  within 60 m on the ground, but track 0 folds back on itself and the check
  could not tell a legitimate parallel pass from a head-on one, so it stopped
  trains dead every time services met on adjacent rails. The pass-through it
  guarded against was actually the node-4226 stranding bug, fixed at source in
  `getClosestTrackNodeWithinRange`; same-direction following is covered by the
  headway hold.
- **Stranded-train recovery** — a materialised train that has not advanced for
  120 s is culled and respawned. Trains within 40 nodes of a station are exempt:
  the ghost dwell happens *before* materialisation, so a train can be legitimately
  stopped at a platform with no dwell flag set.
- **Orphan cleanup** — `onResourceStop` deletes this resource's train entities.
  Without it every restart left untracked trains running that ignored every
  command, because the rogue sweep only culls trains *missing* the `e_trn` state
  bag and an orphan still carries it.

## Admin / debug

| | |
|---|---|
| `traindebug` | every train: id, type, track, node, handle, dwell (mat *and* ghost), hold, coords — plus a per-track **gap table** vs the ideal spacing (the one-line health check for bunching) |
| `boarddebug` | arrival-board internals: stations, cumulative distances |
| `trainspace <track> <count>` | evenly spaced node coordinates for start locations |
| `setr ox:printlevel:dps-trains debug` | verbose lifecycle logging |

`handle=nil` means ghost, a number means materialised. `traindebug` gives
positions as **node indices**. `CTrain` derives `currentCoords` from the node,
so spacing is exact rather than eyeballed off a map.

`/trackprobe` (in game) prints which train tracks the game engine has loaded to
the server console. Use it after adding track data.

## Related resources

| | |
|---|---|
| `dps-trains-stock` | rolling stock, consists, station builds, `TRAINCONFIGS_FILE` |
| `dps-traintools` | boarding, seating, ambient riders, `/traindoors` |
| `dps-transitapp` | Los Santos Transit — live arrivals on the lb-phone |
| `dps-traintracks` | extra track data, no scripts |

## Recent changes

- **12 November 2026.** README: what it is for, how it works alone and with paid scripts, other DPS scripts.
- **1 November 2026.** The yellow metro runs the light rail and the tram set
  runs the country mainline. Station announcements follow the line you are on,
  so swapping trains between lines changes nothing. Roxwood Junction is no
  longer a mainline stop.
- **31 October 2026.** One shared station list (`shared/stations.lua`) for the
  client and the server. Station announcements are spoken through dps-voice.
  Consist numbers are worked out from the game build (build 3570).
- **29 October 2026.** The Roxwood line is off: track 12 is out of
  `config.usedTracks` and the Roxwood shuttle no longer spawns. Tram consist
  added.
- **4 October 2026.** Trains reverse at a terminus. Only tracks the game has
  are enabled. `/trackprobe` added.
- **29 September 2026.** Downtown LS and Market Square stops added. The old
  Downtown stop removed. Regional line speed set to 23.1 m/s.
- **22 September 2026.** Metro seat map rebuilt: 18 seats along both walls.
  Gentler departure from stations.

## Author

Made by [DaemonAlex](https://github.com/DaemonAlex) for DelPerroSands.

The engine is forked from [Ehbw-Trains](https://github.com/Ehbw) by Ehbw. The
rolling stock in `dps-trains-stock` comes from Trains Overhauled by Big Daddy.

## Other DPS scripts

All of these are made for DelPerroSands and run together on one Qbox server. Each one works on
its own. The ones marked "pairs with" do more when both are running.

| Script | What it does |
|---|---|
| [dps-inventory](https://github.com/DaemonAlex/dps-inventory) | The inventory: ox_inventory with equipment slots, backpacks, armour plates and a self status panel, in the DelPerroSands colours. |
| [dps-medical](https://github.com/DaemonAlex/dps-medical) | Patient records, illness and diagnostic tests. A companion to wasabi_ambulance. Pairs with dps-inventory: symptoms and diagnoses show on the status panel. |
| [dps-insurance](https://github.com/DaemonAlex/dps-insurance) | Ties m-Insurance into the MDT, impound, hospital and medical chart. Pairs with dps-medical. |
| [dps-studio](https://github.com/DaemonAlex/dps-studio) | Build rooms, doors and portals in game from one panel (`/studio`), with owners and managers so staff do not have to support them. |
| [dps-shops](https://github.com/DaemonAlex/dps-shops) | Shop clerks who greet and react to a robbery, then player-owned shops. |
| [dps-fleet](https://github.com/DaemonAlex/dps-fleet) | Vehicle browser and workshop on one panel: extras, liveries and mods for emergency vehicles. |
| [dps-parking](https://github.com/DaemonAlex/dps-parking) | Parking with valet, impound, violations and reserved spots. |
| [dps-vehiclepersistence](https://github.com/DaemonAlex/dps-vehiclepersistence) | Vehicles stay where they were parked. Pairs with dps-parking. |
| [dps-towjob](https://github.com/DaemonAlex/dps-towjob) | Queue-based tow job with jg-mechanic integration. |
| [dps-services](https://github.com/DaemonAlex/dps-services) | Request a tow and follow it live on the lb-phone and lb-tablet. Pairs with dps-towjob. |
| [dps-autoshops](https://github.com/DaemonAlex/dps-autoshops) | Self-service repair shops when no mechanic is on duty. |
| [dps-cityworker](https://github.com/DaemonAlex/dps-cityworker) | City infrastructure job and career. |
| [dps-ainpcs](https://github.com/DaemonAlex/dps-ainpcs) | NPCs you can talk to, with trust, quests and intel. |
| [dps-badpeds](https://github.com/DaemonAlex/dps-badpeds) | Police interaction with NPCs: stops, arrests, intel and jail records. |
| [dps-gangwars](https://github.com/DaemonAlex/dps-gangwars) | Ambient gang NPCs, territory population and war reinforcements. |
| [dps-rotations](https://github.com/DaemonAlex/dps-rotations) | Moves dealers, harvests and other spots on a fixed schedule. |
| [dps-transitapp](https://github.com/DaemonAlex/dps-transitapp) | Live train arrival boards on the lb-phone. |
| [dps-faceplant](https://github.com/DaemonAlex/dps-faceplant) | City help, reports and staff tools on the lb-phone and lb-tablet. |
| [dps-chat](https://github.com/DaemonAlex/dps-chat) | A command box for voice-only servers. No chat feed. |
| [dps-filmmode](https://github.com/DaemonAlex/dps-filmmode) | One key hides every HUD layer and gives a smooth free camera for recording. |
