# Realm of Nexus — Godot 4 port

A faithful port of the browser game to Godot 4.2+ (GDScript). Same rules, same five factions, same art theme (faction-tinted bodies with gold / purple / green terrain layers).

## Open it

1. Install Godot 4.2 or newer (4.2.1 works; 4.3+ also fine).
2. In the Godot Project Manager choose **Import** and pick `godot/project.godot`.
3. Press **F5** (Run Project). The main scene is `main.tscn`.

## Data is shared with the web build

All faction, unit, hero, building, research and ability definitions live in the JavaScript files under `../js/data/`. They are exported to JSON for Godot:

```bash
node tools/export_data.js
```

This writes `godot/data/factions.json`, `abilities.json` and `difficulty.json`. Run it after any change to the JS data so both builds stay identical. Ability *logic* is ported by hand in `scripts/abilities.gd`; ability *metadata* (name, hotkey, target type, range, cooldown, description) comes from the JSON.

## Headless test

With Godot on your PATH (or use the full path to the executable):

```bash
godot --headless --path godot -s tools/sim_test.gd
```

It casts every ability of every faction, runs three AI-versus-AI matches, prints a summary and writes `godot/sim_result.txt`.

## Layout

| File | Role |
|---|---|
| `scripts/cfg.gd` | constants and helpers |
| `scripts/gdata.gd` | loads the JSON data |
| `scripts/gmap.gd` | terrain, resource nodes, blight / sunlight / grove layers, `AStarGrid2D` pathfinding (ground and air grids) |
| `scripts/gplayer.gd`, `unit.gd`, `building.gd`, `corpse.gd` | game objects (plain `RefCounted`, not nodes) |
| `scripts/game.gd` | simulation: economy, production, orders, movement, combat, vision, area wards |
| `scripts/abilities.gd` | all 67 hero and structure abilities |
| `scripts/ai.gd` | opponent |
| `scripts/world_view.gd` | `Node2D` that draws the world with `_draw()`; fog and storm on a child node with linear filtering |
| `scripts/hud.gd` | top bar, selection panel, command card, minimap, message log (built in code, dark theme) |
| `scripts/main.gd` | menu, game loop, camera, mouse and keyboard input |
| `scripts/sfx.gd` | procedural sound effects and event-to-sound mapping |
| `tools/sim_test.gd` | headless smoke test |

## Status

Verified on Godot 4.2.1 (2026-09-07): all 13 scripts compile, the headless test casts 62/62 active abilities, and three full AI-versus-AI matches run to a winner with no script errors. The main scene also boots and runs headlessly (`AUTOSTART=1 godot --headless --path godot --quit-after 400` auto-starts a match and prints stats every 100 frames).

Notes for running it:

- If Godot reports `Identifier "GData" not declared`, the project has never been opened in the editor, so the global class cache does not exist. Open the project in the editor once, or run `python tools/gen_class_cache.py`, which regenerates `.godot/global_script_class_cache.cfg` from the `class_name` lines.
- `tools/run_check.sh [sim_seconds] [timeout]` runs the smoke test with a timeout and prints deduplicated errors. Set `GODOT` to the executable path. `SIM_SECONDS` caps each match.
- `tools/compile_check.gd` loads every script so compile errors in the UI scripts (which the sim test never touches) show up.
- Godot warns about leaked ObjectDB instances at exit. The game objects reference each other in cycles (game <-> units); harmless at runtime.

Performance (after the 2026-09-07 optimization pass): a simulation tick averages about 1.2 ms with 60 to 80 entities and stays under 10 ms in the worst case, down from 5 to 10 ms average and 70 ms spikes. What changed:

- `game.gd` keeps a spatial hash (`_grid`, 128 px cells) rebuilt every tick; `nearby()` only visits nearby cells.
- Idle and attack-moving units look for targets a few times per second (`scan_timer`) instead of every tick.
- `unit.stat()` is cached per tick, and terrain-layer lookups only happen for stats that use them.
- Terrain layers step every 0.1 s over an active-tile set instead of sweeping all 4800 tiles every tick.
- Vision uses precomputed disc offsets, skips duplicate marks, and keeps a persistent `explored` array instead of resetting.
- The renderer uploads the vision and layer arrays as textures and composes fog and layer colours in two small shaders; no per-tile GDScript loops remain on the frame path. The minimap uses the same shaders.

Balance tooling: `tools/balance.gd` plays a list of AI-versus-AI matches (env `JOBS="p0:p1:difficulty:seed;..."`, `OUT=results.jsonl`) and `python tools/balance_report.py <dir>` (repo root) aggregates the JSON lines into `docs/balance-report.md`. The 2026-09-07 run (150 matches) is the baseline: Sanctuary 78 percent win rate, Abyss 35 percent, and the AI never reaches Tier 3.

Sound and game feel: `scripts/sfx.gd` synthesizes every sound at startup (hits, shots, deaths, production ready, tier up, casts, ultimates, selection and order acknowledgements, under-attack alarm). Drop real files in `assets/sfx/<name>.wav` to replace any of them. The simulation emits events (`game.events`) that `main.gd` turns into positional audio, screen shake on heavy hits, deaths of large units and buildings, and ultimates, and a white hit flash on damaged units and buildings. Press M in game to mute.

Pause menu and settings: Esc with nothing selected opens the pause menu (Resume, Settings, Quit to menu). Settings has master volume, sound, screen shake and edge scrolling toggles, and remappable hotkeys (global keys and the A / S / H / Q / W / E / R commands). Settings persist in `user://settings.cfg`. The main menu has a Settings button too.

Windows build: `export_presets.cfg` defines a "Windows Desktop" preset writing `../dist/win/RealmOfNexus.exe` with the pack embedded. It needs the Godot 4.2.1 export templates installed once (Editor > Manage Export Templates, or unzip `Godot_v4.2.1-stable_export_templates.tpz` into `%APPDATA%\Godot\export_templates.2.1.stable`). Then:

```
godot --headless --path godot --export-release "Windows Desktop" dist/win/RealmOfNexus.exe
```

`tools/profile.gd` prints a per-section breakdown of one match (`SIM_SECONDS=400 godot --headless --path godot -s tools/profile.gd`). Add `SCREENSHOT=path.png` to an `AUTOSTART=1` windowed run to capture frame 240 and quit.
