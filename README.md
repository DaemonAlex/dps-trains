# dps-trains

The Del Perro Sands railway: a scheduled passenger service on the heavy-rail
loop and a metro on the city line, with real station stops, live arrival times
on the phone, and trains that run to a timetable whether or not anyone is
watching them.
Credit: Walter (https://www.gta5-mods.com/vehicles/overhauled-trains-lore-friendly-liveries)
Credit: Forked (https://github.com/Ehbw) and substantially rewritten and polsished. With input from several past train scripts 
Credit: to the upstream author (https://github.com/VenomXNL/XNL-FiveM-Trains-U3)  for the track-node architecture and traintracking that everything here is              built on.
Credit: Big Daddy Scripts for the open Source work on Walters trains :-)
## Service

| | |
|---|---|
| **Mainline** (track 0) | 6 passenger trains, spaced 704 nodes apart |
| **Metro** (track 3) | 3 trains |
| **Consists** | engine + 3 carriages |
| **Line speed** | 30 m/s (~67 mph) |
| **Station dwell** | 30 s |
| **Calling points** | 9 on the mainline |
| **Headway** | ~3.5 minutes |

Two liveries alternate around the loop: the **Axsellya Express** (blue) and the
**Brown Streak** (brown). There is no freight service — every train stops and
opens doors, where a freight consist stopped but never opened, which reads as
broken to a player who does not know why.

### Calling points

```
 462  Lumber Mill                 2434  Davis Interchange (Southbound)
 651  Paleto Bay                  2667  Port Depot
1481  Quarry (Southbound)         2865  Davis Interchange (Northbound)
1701  Power Plant                 3891  Quarry (Northbound)
                                  4159  Sandy Shores
```

Davis and Quarry each appear twice because the line calls at them **in both
directions** — they are the same station, not duplicates. Davis Interchange is
about 400 m from the metro's Davis platform and is the connection between the
two networks.

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
station **node**, within 5 nodes and only on the approach side.

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
  gap clears.
- **Physical separation** — the headway check compares track *sequence*, and
  track 0 folds back on itself, so two trains 44 m apart on the ground can be
  1,300 nodes apart in the node list. A ground-distance test catches that; only
  one train of a pair is ever held, so a fold-back meeting cannot deadlock.
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
| `traindebug` | every train: id, type, track, node, handle, dwell, coords |
| `boarddebug` | arrival-board internals: stations, cumulative distances |
| `trainspace <track> <count>` | evenly spaced node coordinates for start locations |
| `setr ox:printlevel:dps-trains debug` | verbose lifecycle logging |

`handle=nil` means ghost, a number means materialised. Positions are given as
**node indices** in `configs/freight.lua`, not coordinates — `CTrain` derives
`currentCoords` from the node, so spacing is exact rather than eyeballed off a
map.

## Related resources

| | |
|---|---|
| `dps-trains-stock` | rolling stock, consists, station builds, `TRAINCONFIGS_FILE` |
| `dps-traintools` | boarding, seating, ambient riders, `/traindoors` |
| `dps-transitapp` | Los Santos Transit — live arrivals on the lb-phone |
