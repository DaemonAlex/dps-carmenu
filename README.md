# dps-carmenu

Admin vehicle browser and spawner for the DPSRP (Qbox) server. `/carmenu` opens an ox_lib
context menu of every vehicle in the live `qbx_core` vehicle registry, grouped by category,
and spawns the selected vehicle server-side — the same path `/car` uses.

Because the menu reads the registry live, curation edits to the vehicle list show up on the
next server restart with no changes to this resource.

## Features

- Category browser (race, super, sports, … trains, cycles) built from `qbx_core:GetVehiclesByName()`
- Server-side spawn through `qbx.spawnVehicle` with warp-in
- Admin-gated: the `/carmenu` command is `group.admin`, and the spawn callback re-checks
  ace permission server-side so a modified client cannot spawn through it
- Gives the spawner keys via `wasabi_carlock` when that resource is running (optional)

## Dependencies

- [ox_lib](https://github.com/CommunityOx/ox_lib)
- [qbx_core](https://github.com/Qbox-project/qbx_core)
- wasabi_carlock — optional; keys are skipped if not started

## Install

1. Place the resource in your resources folder, e.g. `resources/[dps]/dps-carmenu`.
2. Ensure it loads **after** `ox_lib` and `qbx_core` in your `server.cfg`:

   ```cfg
   ensure ox_lib
   ensure qbx_core
   ensure dps-carmenu
   ```

3. No config file and no database — there is nothing else to set up.

## Usage

- `/carmenu` (admin only) → pick a category → pick a vehicle → it spawns on you with keys.

## Files

| File | Purpose |
| --- | --- |
| `client.lua` | Builds the category/vehicle menus and requests spawns |
| `server.lua` | `/carmenu` command + ace-checked spawn callback |
| `fxmanifest.lua` | Manifest (cerulean, gta5) |
