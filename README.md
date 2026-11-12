# dps-carmenu

The DPS fleet browser for the Del Perro Sands (Qbox) server. `F7` or `/carmenu` opens a
panel over the live `qbx_core` vehicle registry: search it, read what a car actually is,
spawn it in place of the one you sit in (or beside it), and copy a clean text card to paste
into an LLM.

Because it reads the registry live, curation edits to the vehicle list show up on the next
server restart with no changes to this resource.

## Status

Not running on DelPerroSands. It was merged into
[dps-fleet](https://github.com/DaemonAlex/dps-fleet) on 28 September 2026 (dps-fleet 3.0.0). Use
dps-fleet. This repo is kept for its history.

## What it is for

Staff and testers need to find a vehicle fast, see what it really is, and spawn it. This script
is a searchable browser over every vehicle the server has registered. It is a staff tool. Players
do not see it.

## On its own, and with other scripts

**On its own.** It needs `ox_lib` and `qbx_core`, so it is Qbox only. A staff member with the
`dps.carmenu` ace presses `F7` or types `/carmenu`. They search, read the car's facts, and spawn
it in place of the car they sit in or beside it. They can copy a text card of the car or its
handling numbers.

**With a paid key script (wasabi_carlock).** The staff member gets keys to the spawned car. With
no key script the car spawns without keys.

**With jg-vehiclestudio.** The list shows a photo of each vehicle. Without it the list has no
photos.

**With dps-EVM.** The Workshop button opens the emergency vehicle workshop on the selected car.
dps-EVM was merged into dps-fleet at the same time as this script.

## What it does

- **Search** across name, brand, model code, category and pack, with tokens:
  `cat:sports` `pack:dpsveh-race` `type:bike` `brand:pegassi` `price:<50000` `speed:>200`
  `sort:price-desc` (sort by `name`, `price`, `speed`, `category`, `model`).
- **Rail** of categories with counts; **Recent** (last 15 spawned) and **Favorites** (per player, KVP).
- **Info** in layers: registry (name, brand, category, price, type), source pack and game class
  (from the fleet state file the registry builder writes each boot), model facts read from the
  game (top speed, acceleration, braking, traction, seats, size), and the handling numbers once
  the vehicle exists (spawned, or the one you sit in).
- **Spawn** replaces the vehicle you are in (same spot and heading, you stay in the seat, keys via
  wasabi_carlock when present) or, with **Spawn beside** / `Shift+Enter`, puts it next to you.
- **Copy card** puts a plain-text `DPS VEHICLE CARD` on the clipboard; **Copy handling** copies every
  handling field in `handling.meta` order. **Remove mine** deletes the vehicle you sit in or last spawned. **Workshop** opens dps-EVM (liveries, extras, mods, repairs) on that vehicle.
- Keyboard: type to search, `↑` `↓` move, `Enter` spawn, `Shift+Enter` spawn beside, `C` copy card,
  `F` favorite, `Esc` close.

## Access

The ace `dps.carmenu`. In `server.cfg`:

```cfg
add_ace group.admin dps.carmenu allow
add_ace group.tester dps.carmenu allow
```

Give a player the tester group with qbx_core's `/addpermission <id> tester`. Every callback
re-checks the ace server-side, so a modified client cannot spawn through this resource.

## Dependencies

- [ox_lib](https://github.com/CommunityOx/ox_lib)
- [qbx_core](https://github.com/Qbox-project/qbx_core)
- wasabi_carlock: optional. Keys are skipped if it is not started
- `data/fleet_state.json`: optional. A copy of the fleet state file that `registry-refresh.sh` drops in before every start. Without it every pack shows as `vanilla`

## Files

| File | Purpose |
| --- | --- |
| `client.lua` | Opens the panel, feeds it the registry, reads model and handling natives, spawns through callbacks, keeps Recent and Favorites in KVP |
| `server.lua` | Ace-checked callbacks: open, spawn (replace / beside), delete; loads the fleet state file once |
| `shared/search.lua` | Pure Lua search (parse, match, sort, counts) and card formatters |
| `shared/fields.lua` | Handling field list (same as dps-handlingdump) |
| `html/` | The panel: `index.html`, `style.css` (DPS in-game tokens), `app.js` |
| `tests/` | `lua5.4 tests/run.lua` runs every `tests/test_*.lua` with no natives |

## Tests

```sh
lua5.4 tests/run.lua
```

## Recent changes

- **12 November 2026.** README: status, what it is for, how it works alone and with paid scripts, other DPS scripts.
- **28 September 2026.** Merged into dps-fleet 3.0.0 (date from the dps-fleet changelog).
- **27 September 2026.** Fleet panel version 3: search bar over a grouped photo list, departments
  and kinds, Workshop button, pack info read from the fleet state file.
- **10 September 2026.** Every spawn is logged with model, plate and timing.
- **28 August 2026.** First version: staff vehicle browser and spawner over the Qbox vehicle list.

## Author

Made by [DaemonAlex](https://github.com/DaemonAlex) for DelPerroSands.

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
| [dps-trains](https://github.com/DaemonAlex/dps-trains) | The train system. Pairs with dps-trains-stock, dps-traintools and dps-transitapp. |
| [dps-transitapp](https://github.com/DaemonAlex/dps-transitapp) | Live train arrival boards on the lb-phone. |
| [dps-faceplant](https://github.com/DaemonAlex/dps-faceplant) | City help, reports and staff tools on the lb-phone and lb-tablet. |
| [dps-chat](https://github.com/DaemonAlex/dps-chat) | A command box for voice-only servers. No chat feed. |
| [dps-filmmode](https://github.com/DaemonAlex/dps-filmmode) | One key hides every HUD layer and gives a smooth free camera for recording. |
