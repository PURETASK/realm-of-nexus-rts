# Realm of Nexus – RTS

A browser real-time strategy game built from the *Realm of Nexus RTS Design Bible, Volume 1: Core Faction Mechanics*. Plain HTML5 Canvas and JavaScript, no build step, no dependencies.

## Play it

- **Live:** https://claude.ai/code/artifact/fbc0401d-cf1e-4683-807e-cb207a0f4df8 (private until shared from the page's share menu)
- **Offline:** `dist/realm-of-nexus.html` is a single self-contained file. Double-click it.
- **Rebuild the bundles** after editing source: `python build.py` and `python build.py --fragment`
- **Develop:** `python serve.py 8765` serves the source with caching disabled; bump the `?v=` on the script tags in `index.html` when scripts change

## Run from source

Any static file server works. From this folder:

```bash
python -m http.server 8765
```

Then open http://localhost:8765 in a browser. (Opening `index.html` directly from disk also works in most browsers.)

## What is implemented

All five domains are playable against the AI. Abyss and Tempest are built from their complete Volume 1 mechanical sheets. Radiance, Verdance and Sanctuary are **provisional**: their structure and unit names, resources and roles come from your domain overview and the unified building list, but heroes, tiers, stats and research were invented to fill the gaps and are marked `(invented)` in the data files.

| | Abyss | Tempest | Radiance (prov.) | Verdance (prov.) | Sanctuary (prov.) |
|---|---|---|---|---|---|
| Theme | Death, corruption | Storms, skies | The Sun | The Everwood | Divine light |
| Base | Necropolis of Shades | Stormspire Outpost | Sunforge Citadel | Everwood Spire | Luminarch Citadel |
| Resources | Soul Essence, Voidstone, Oblivion Shard | Stormsteel, Aether Crystals, Tempest Pearl | Sunstone, Dawnlight, Phoenix Feather | Silver Sap, Everwood Essence, World Seed | Sacred Crystals, Holy Light, Seraph's Tear |
| Ground | Blight: undead heal, enemies weaken | none (weather instead) | Sunlight: heals, burns blight, reveals | Grove: heals, speeds allies, vines slow foes | Holy ground: allies shielded, undead weakened, reveals |
| Signature | Souls from every death, raise the dead, sacrifice | Tribute economy, fliers, weather, base relocation | Phoenix rebirth, Solar Relay surge, healers | Buildings grow on their own, Sylvan Waystone teleports, thorn walls, summons | Regenerating wards on every unit, Eternal Bell rally, banish corruption |
| Heroes | Tyvaris, Neratha, Malazar | Rykan, Lyrian, Alyssia | Aurelian, Seraphine, Solaris | Kael, Elowen, Sylvara | Isolde, Adaline, Cassiel |
| Units / structures | 11 / 13 | 11 / 15 | 11 / 15 | 12 / 15 | 12 / 15 |

Each hero has four abilities (Q/W/E/R); ultimates unlock at hero level 5. One hero per tier may be summoned. Heroes gain XP from kills and are resummoned after a 60 second delay if they fall.

Shared systems: fog of war, A* pathfinding with air and ground layers, three terrain layers (blight, sunlight, grove) that spread from structures and fight each other, unit shields, healers, supply, production queues, rally points, tier upgrades with prerequisite structures, data-driven research, control groups, minimap, and an AI opponent with three difficulty levels that follows a faction build order, teches up, uses hero and structure abilities, defends, and launches escalating attacks.

## Godot 4 port

The game is also ported to Godot 4 in [`godot/`](godot/README.md). Import `godot/project.godot` in Godot 4.2+ and press F5. Faction data is shared with the web build through `node tools/export_data.js`, so there is one source of truth for units, buildings, heroes and research. Building design specs (three-tier visuals) live in `docs/buildings/`.

## Art pipeline

The Godot renderer loads sprites from `godot/assets/sprites/units/<id>.png` and `godot/assets/sprites/buildings/<id>.png` when they exist and keeps the placeholder glyph otherwise, so art lands one asset at a time (see `godot/assets/sprites/README.md`). `tools/render_sprites.py` turns any 3D model (Meshy output, .glb/.fbx/.obj) into the 8-direction strips and building images the renderer expects, using Blender in background mode. The full asset list with Meshy prompts is `docs/asset-list.md`.

## Controls

- Left-click select, drag to box-select, Shift to add. Double-click selects all of a type on screen.
- Right-click: move, attack an enemy, gather from a soul font (Abyss Acolytes), help construct a building, or set a rally point when a production building is selected.
- `A` attack-move, `S` stop, `H` hold, `M` move, `B` build menu (workers), `G` gather (Abyss).
- `Q W E R` hero abilities. `U` tier upgrade at the base. `X` relocate the Stormspire.
- `Ctrl+1..9` assign group, `1..9` recall, press twice to jump the camera. `F1` select army, `F2` hero, `Tab` idle worker, `Space` jump to the last attack.
- Arrow keys, edge scrolling, or the minimap move the camera. `P` pauses. `Esc` cancels.
- Destroy every enemy structure to win.

## Making the provisional factions canon

Open `js/data/radiance.js`, `verdance.js` and `sanctuary.js`. Every line marked `(invented)` or the faction-level `provisional: true` flag is a placeholder. Replace names, stats and abilities from the Volume 1 PDF when it is available; abilities live in `js/abilities_domains.js`. See `docs/README.md` for the two open naming conflicts in the source material.

## Code layout

- `js/config.js`, `js/util.js` – constants and helpers
- `js/data/` – faction definitions (data-driven)
- `js/map.js` – terrain generation, resource nodes, blight layer
- `js/pathfinding.js` – A* with smoothing, ground and air modes
- `js/entities.js` – Unit, Building, Corpse; stat computation with buffs, research and weather
- `js/game.js` – simulation: economy, production, orders, movement, vision
- `js/combat.js` – attacks, damage, deaths, souls, towers, projectiles, hero passives
- `js/abilities.js` – Abyss and Tempest abilities, area wards, global storm
- `js/abilities_domains.js` – Radiance, Verdance and Sanctuary abilities and auras
- `js/ai.js` – opponent controller
- `js/render.js`, `js/ui.js`, `js/input.js`, `js/main.js` – presentation and control
- `docs/` – the recovered design sheets
