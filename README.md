# dps-carmenu

The DPS fleet browser for the Del Perro Sands (Qbox) server. `F7` or `/carmenu` opens a
panel over the live `qbx_core` vehicle registry: search it, read what a car actually is,
spawn it in place of the one you sit in (or beside it), and copy a clean text card to paste
into an LLM.

Because it reads the registry live, curation edits to the vehicle list show up on the next
server restart with no changes to this resource.

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
  handling field in `handling.meta` order. **Remove mine** deletes the vehicle you sit in or last spawned.
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
- wasabi_carlock — optional; keys are skipped if not started
- `/opt/fivem/tools/state/vehicles_found.json` — optional; without it every pack shows as `vanilla`

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
