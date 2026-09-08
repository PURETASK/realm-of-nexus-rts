# Realm of Nexus — Visual Asset List

Generated from the shared game data by `tools/gen_asset_list.py` on 2026-09-07. Every entry is something the game already references, so nothing here is optional decoration: the placeholders currently drawn as coloured glyphs are exactly this list.

## How to use this list with Meshy (or similar)

- The game is a top-down 2D RTS with a 32 px tile. Recommended pipeline: generate a 3D model in Meshy from the prompt, retopologize to the tri budget, rig and animate (Meshy's auto-rig covers humanoids), then either render to 8-direction sprite sheets at 64 px (units) / 96-192 px (buildings) for the current 2D renderer, or keep the meshes for a later 3D-camera version of the Godot build. Rendering to sprites keeps the current art theme and the current renderer.
- Silhouette first. Units are 20 to 28 px across on screen, so each unit type in a faction must read from its outline alone: workers hunched with tools, infantry with shields, ranged with bows, casters with staffs, fliers with wings, siege with launchers.
- One material palette per faction (given in each faction's style line). Player colour is applied by the engine as a tint on a mask, so leave a 15 to 25 percent area of each unit and building in neutral grey for the team-colour mask.
- Buildings need three states: under construction (scaffold or half-grown), complete, destroyed rubble. Main bases additionally need three tier variants. Radiance building tiers are specified in detail in `docs/buildings/radiance-buildings.md`; the other factions follow the same three-tier pattern.
- Priority: P1 = needed for a playable vertical slice (Tier 1 content and heroes), P2 = Tier 2, P3 = Tier 3 and ultimates.

## Abyss

*Abyss style: bone, obsidian and rusted iron, purple void-fire, rot and chains, jagged gothic silhouettes, palette violet #8b3cff / bone white / black*

Tier names for the main base: Necropolis of Shades → Profane Citadel → Oblivion Spire.
Resources to depict on nodes and in icons: Soul Essence (primary), Voidstone (secondary), Oblivion Shard (catalyst).

### Heroes (3)

| Id | Name | Role | Size | Animations | Priority |
|---|---|---|---|---|---|
| `tyvaris` | Warlord Tyvaris | Hulking melee champion | hero (1.5 tiles, radius 14 px, distinctive silhouette) | idle, walk, attack, 4 ability casts (Q W E R), victory pose, death | P1 |
| `neratha` | Neratha Soulweaver | Frail necromancer crone | hero (1.5 tiles, radius 14 px, distinctive silhouette) | idle, walk, attack, 4 ability casts (Q W E R), victory pose, death | P1 |
| `malazar` | Malazar the Voidcaller | Ranged lich sorcerer | hero (1.5 tiles, radius 14 px, distinctive silhouette) | idle, walk, attack, 4 ability casts (Q W E R), victory pose, death | P1 |

Meshy prompts:

- **Warlord Tyvaris** — Abyss style: bone, obsidian and rusted iron, purple void-fire, rot and chains, jagged gothic silhouettes, palette violet #8b3cff / bone white / black, Warlord Tyvaris: Hulking melee champion. Spreads blight as he walks; undead near him rise once more after death, unique champion, more detail and a stronger colour accent than regular troops, distinct head/weapon silhouette, top-down readable, game-ready low poly (8-12k tris), 1024 PBR texture, rigged humanoid or creature rig
  - Ability VFX to pair with the casts: Soulcleaver Blade (enemy), Dread Banner (none), Sacrificial Surge (none), Aura of the Pale King (none).
- **Neratha Soulweaver** — Abyss style: bone, obsidian and rusted iron, purple void-fire, rot and chains, jagged gothic silhouettes, palette violet #8b3cff / bone white / black, Neratha Soulweaver: Frail necromancer crone. Harvests souls, spreads blight and hastens production with blood pacts, unique champion, more detail and a stronger colour accent than regular troops, distinct head/weapon silhouette, top-down readable, game-ready low poly (8-12k tris), 1024 PBR texture, rigged humanoid or creature rig
  - Ability VFX to pair with the casts: Harvest Soul (enemy), Corruption Ward (point), Dark Pact (ally), Undying Devotion (none).
- **Malazar the Voidcaller** — Abyss style: bone, obsidian and rusted iron, purple void-fire, rot and chains, jagged gothic silhouettes, palette violet #8b3cff / bone white / black, Malazar the Voidcaller: Ranged lich sorcerer. Void bolts, terror veils, portals and the Curse of Undeath, unique champion, more detail and a stronger colour accent than regular troops, distinct head/weapon silhouette, top-down readable, game-ready low poly (8-12k tris), 1024 PBR texture, rigged humanoid or creature rig
  - Ability VFX to pair with the casts: Void Bolt (enemy), Nightmare Veil (point), Nether Portal (point), Curse of Undeath (point).

### Units (12)

| Id | Name | Type | Tier | Size | Animations | Priority |
|---|---|---|---|---|---|---|
| `acolyte` | Acolyte | worker | 1 | small (1 tile, radius 10 px) | idle, walk, gather (swing/pick), carry-walk, build (hammer), death | P1 |
| `skeleton_warrior` | Skeleton Warrior | infantry | 1 | small (1 tile, radius 10 px) | idle, walk, attack (melee), death | P1 |
| `gravebow_archer` | Gravebow Archer | ranged | 1 | small (1 tile, radius 10 px) | idle, walk, attack (draw and release), death | P1 |
| `shadow_adept` | Shadow Adept | caster | 1 | small (1 tile, radius 10 px) | idle, walk, cast (channel), attack, death | P1 |
| `necromancer` | Necromancer | caster | 2 | small (1 tile, radius 10 px) | idle, walk, cast (channel), attack, death | P2 |
| `banshee` | Banshee | flying | 2 | small (1 tile, radius 10 px) | idle hover, fly, attack, death (fall) | P2 |
| `flesh_abomination` | Flesh Abomination | infantry | 2 | medium (1.5 tiles, radius 12 px) | idle, walk, attack (melee), death | P2 |
| `bone_catapult` | Bone Catapult | siege | 2 | medium (1.5 tiles, radius 12 px) | idle, move, fire (recoil), death (break apart) | P2 |
| `void_knight` | Void Knight | infantry | 3 | medium (1.5 tiles, radius 12 px) | idle, walk, attack (melee), death | P3 |
| `nether_dragon` | Nether Dragon | flying | 3 | large (2 tiles, radius 14 px) | idle hover, fly, attack, death (fall) | P3 |
| `shade` | Shade | infantry | 3 | small (1 tile, radius 10 px) | idle, walk, attack (melee), death | P3 |
| `deathlord` | The Deathlord | infantry | 3 | colossal (2.5 tiles, radius 14 px, towers over units) | idle, walk, attack (melee), death | P3 |

Meshy prompts:

- **Acolyte** — Abyss style: bone, obsidian and rusted iron, purple void-fire, rot and chains, jagged gothic silhouettes, palette violet #8b3cff / bone white / black, Acolyte: Worker. Gathers Soul Essence from soul fonts and builds structures, carries a tool and a small resource container, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Skeleton Warrior** — Abyss style: bone, obsidian and rusted iron, purple void-fire, rot and chains, jagged gothic silhouettes, palette violet #8b3cff / bone white / black, Skeleton Warrior: Cheap melee fodder. Dies easily, but every death feeds the Abyss, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Gravebow Archer** — Abyss style: bone, obsidian and rusted iron, purple void-fire, rot and chains, jagged gothic silhouettes, palette violet #8b3cff / bone white / black, Gravebow Archer: Ranged skeleton. Fires bone arrows at ground and air, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Shadow Adept** — Abyss style: bone, obsidian and rusted iron, purple void-fire, rot and chains, jagged gothic silhouettes, palette violet #8b3cff / bone white / black, Shadow Adept: Cultist caster with a life-drain bolt that heals the adept, robed figure with a glowing focus object, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Necromancer** — Abyss style: bone, obsidian and rusted iron, purple void-fire, rot and chains, jagged gothic silhouettes, palette violet #8b3cff / bone white / black, Necromancer: Raises Skeleton Warriors from nearby corpses (auto). Weak in direct combat, robed figure with a glowing focus object, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Banshee** — Abyss style: bone, obsidian and rusted iron, purple void-fire, rot and chains, jagged gothic silhouettes, palette violet #8b3cff / bone white / black, Banshee: Flying ghost. Fast harasser whose wail strikes ground and air, winged or hovering flier, seen from above, wings readable in silhouette, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Flesh Abomination** — Abyss style: bone, obsidian and rusted iron, purple void-fire, rot and chains, jagged gothic silhouettes, palette violet #8b3cff / bone white / black, Flesh Abomination: Stitched monstrosity. Tanky frontline melee brute, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Bone Catapult** — Abyss style: bone, obsidian and rusted iron, purple void-fire, rot and chains, jagged gothic silhouettes, palette violet #8b3cff / bone white / black, Bone Catapult: Siege artillery lobbing putrid skulls. Splash damage, double vs structures, wheeled or legged war machine with an obvious launcher, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Void Knight** — Abyss style: bone, obsidian and rusted iron, purple void-fire, rot and chains, jagged gothic silhouettes, palette violet #8b3cff / bone white / black, Void Knight: Elite shock cavalry wreathed in shadow. Fast and armored, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Nether Dragon** — Abyss style: bone, obsidian and rusted iron, purple void-fire, rot and chains, jagged gothic silhouettes, palette violet #8b3cff / bone white / black, Nether Dragon: Flying drake exhaling corrupting breath. Splash damage against ground and air, winged or hovering flier, seen from above, wings readable in silhouette, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Shade** — Abyss style: bone, obsidian and rusted iron, purple void-fire, rot and chains, jagged gothic silhouettes, palette violet #8b3cff / bone white / black, Shade: Minor void shade spawned freely by the Void Gate. Scout and harasser, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **The Deathlord** — Abyss style: bone, obsidian and rusted iron, purple void-fire, rot and chains, jagged gothic silhouettes, palette violet #8b3cff / bone white / black, The Deathlord: Avatar of Virexus. One may exist. Colossal necrotic titan with a death aura, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig

### Buildings (14)

| Id | Name | Footprint | Tier | Extra states | Priority |
|---|---|---|---|---|---|
| `necropolis` | Necropolis of Shades | 3x3 | 1 | construction, destroyed, 3 tier variants, active glow / emitter | P1 |
| `grim_crypt` | Grim Crypt | 2x2 | 1 | construction, destroyed | P1 |
| `occult_den` | Occult Den | 2x2 | 1 | construction, destroyed | P1 |
| `soul_well` | Soul Well | 2x2 | 1 | construction, destroyed, active glow / emitter | P1 |
| `soul_obelisk` | Soul Obelisk | 1x1 | 1 | construction, destroyed, active glow / emitter | P1 |
| `corruption_spire` | Corruption Spire | 1x1 | 1 | construction, destroyed, active glow / emitter | P1 |
| `bone_wall` | Bone Wall | 1x1 | 1 | construction, destroyed | P1 |
| `plague_mine` | Plague Mine | 1x1 | 1 | construction, destroyed | P1 |
| `necromancer_spire` | Necromancer's Spire | 2x2 | 2 | construction, destroyed | P2 |
| `flesh_forge` | Flesh Forge | 3x3 | 2 | construction, destroyed | P2 |
| `reliquary` | Reliquary of Darkness | 2x2 | 2 | construction, destroyed | P2 |
| `corruption_crucible` | Corruption Crucible | 2x2 | 2 | construction, destroyed, active glow / emitter | P2 |
| `void_gate` | Void Gate | 3x3 | 3 | construction, destroyed | P3 |
| `cathedral_of_decay` | Cathedral of Decay | 3x3 | 3 | construction, destroyed | P3 |

Meshy prompts:

- **Necropolis of Shades** — Abyss style: bone, obsidian and rusted iron, purple void-fire, rot and chains, jagged gothic silhouettes, palette violet #8b3cff / bone white / black, Necropolis of Shades: Your main base. Trains Acolytes and heroes, drops off souls, spreads blight, footprint 3x3 tiles, seen from above at a slight angle, strong roof silhouette, main base, three visual tiers (Tier 1 modest, Tier 2 expanded, Tier 3 monumental with a crowning light or spire), defensive tower with a clear emitter at the top, built over a resource node, with intake channels, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Grim Crypt** — Abyss style: bone, obsidian and rusted iron, purple void-fire, rot and chains, jagged gothic silhouettes, palette violet #8b3cff / bone white / black, Grim Crypt: Animates Skeleton Warriors and Gravebow Archers. +8 supply, footprint 2x2 tiles, seen from above at a slight angle, strong roof silhouette, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Occult Den** — Abyss style: bone, obsidian and rusted iron, purple void-fire, rot and chains, jagged gothic silhouettes, palette violet #8b3cff / bone white / black, Occult Den: Cultist temple. Trains Acolytes and Shadow Adepts, researches dark blessings. +8 supply. Required for Tier 2, footprint 2x2 tiles, seen from above at a slight angle, strong roof silhouette, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Soul Well** — Abyss style: bone, obsidian and rusted iron, purple void-fire, rot and chains, jagged gothic silhouettes, palette violet #8b3cff / bone white / black, Soul Well: Built on a soul font. Channels 0.8 souls/s from the font automatically; Acolytes may still mine it. Can sacrifice a friendly unit for a burst of Soul Essence. Spreads blight, footprint 2x2 tiles, seen from above at a slight angle, strong roof silhouette, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Soul Obelisk** — Abyss style: bone, obsidian and rusted iron, purple void-fire, rot and chains, jagged gothic silhouettes, palette violet #8b3cff / bone white / black, Soul Obelisk: Defensive tower. Necrotic bolts leech life to nearby undead. Longer range on blight, footprint 1x1 tiles, seen from above at a slight angle, strong roof silhouette, defensive tower with a clear emitter at the top, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Corruption Spire** — Abyss style: bone, obsidian and rusted iron, purple void-fire, rot and chains, jagged gothic silhouettes, palette violet #8b3cff / bone white / black, Corruption Spire: No attack. Rapidly spreads blight; enemies on blight nearby are slowed and decay, footprint 1x1 tiles, seen from above at a slight angle, strong roof silhouette, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Bone Wall** — Abyss style: bone, obsidian and rusted iron, purple void-fire, rot and chains, jagged gothic silhouettes, palette violet #8b3cff / bone white / black, Bone Wall: Wall of fused bone. Regenerates when anything dies beside it, footprint 1x1 tiles, seen from above at a slight angle, strong roof silhouette, modular wall segment that tiles in a line, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Plague Mine** — Abyss style: bone, obsidian and rusted iron, purple void-fire, rot and chains, jagged gothic silhouettes, palette violet #8b3cff / bone white / black, Plague Mine: Invisible trap. Erupts in disease when enemies approach, weakening and sapping them, footprint 1x1 tiles, seen from above at a slight angle, strong roof silhouette, nearly flush with the ground, revealed only by a faint glow, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Necromancer's Spire** — Abyss style: bone, obsidian and rusted iron, purple void-fire, rot and chains, jagged gothic silhouettes, palette violet #8b3cff / bone white / black, Necromancer's Spire: Trains Necromancers and Banshees. Researches Grave March, footprint 2x2 tiles, seen from above at a slight angle, strong roof silhouette, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Flesh Forge** — Abyss style: bone, obsidian and rusted iron, purple void-fire, rot and chains, jagged gothic silhouettes, palette violet #8b3cff / bone white / black, Flesh Forge: Abomination pit. Trains Flesh Abominations and Bone Catapults. Researches Blight Plague, footprint 3x3 tiles, seen from above at a slight angle, strong roof silhouette, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Reliquary of Darkness** — Abyss style: bone, obsidian and rusted iron, purple void-fire, rot and chains, jagged gothic silhouettes, palette violet #8b3cff / bone white / black, Reliquary of Darkness: Crafts Dark Relics: vampiric and armor augmentations. Required for Tier 3, footprint 2x2 tiles, seen from above at a slight angle, strong roof silhouette, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Corruption Crucible** — Abyss style: bone, obsidian and rusted iron, purple void-fire, rot and chains, jagged gothic silhouettes, palette violet #8b3cff / bone white / black, Corruption Crucible: Condenses Soul Essence into Voidstone (2 souls → 1 void per second while active). Spreads blight, footprint 2x2 tiles, seen from above at a slight angle, strong roof silhouette, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Void Gate** — Abyss style: bone, obsidian and rusted iron, purple void-fire, rot and chains, jagged gothic silhouettes, palette violet #8b3cff / bone white / black, Void Gate: Portal to the Void. Trains Void Knights and Nether Dragons. Periodically spawns free Shades, footprint 3x3 tiles, seen from above at a slight angle, strong roof silhouette, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Cathedral of Decay** — Abyss style: bone, obsidian and rusted iron, purple void-fire, rot and chains, jagged gothic silhouettes, palette violet #8b3cff / bone white / black, Cathedral of Decay: Ultimate tech. Summons the Deathlord (needs an Oblivion Shard). Researches Death Fog, footprint 3x3 tiles, seen from above at a slight angle, strong roof silhouette, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants

## Tempest

*Tempest style: storm-grey steel and brass, sailcloth and rigging, lightning-blue crystal, sky-ship technology, palette sky blue #5fc8ff / brass / slate*

Tier names for the main base: Stormspire Outpost → Skybreaker Citadel → Maelstrom Nexus.
Resources to depict on nodes and in icons: Stormsteel (primary), Aether Crystals (secondary), Tempest Pearl (catalyst).

### Heroes (3)

| Id | Name | Role | Size | Animations | Priority |
|---|---|---|---|---|---|
| `rykan` | Stormlord Rykan | Gryphon-riding frontline hero | hero (1.5 tiles, radius 14 px, distinctive silhouette) | idle, walk, attack, 4 ability casts (Q W E R), victory pose, death | P1 |
| `lyrian` | Skybreaker Lyrian | Council engineer | hero (1.5 tiles, radius 14 px, distinctive silhouette) | idle, walk, attack, 4 ability casts (Q W E R), victory pose, death | P1 |
| `alyssia` | Stormcaller Alyssia | Fragile storm mage | hero (1.5 tiles, radius 14 px, distinctive silhouette) | idle, walk, attack, 4 ability casts (Q W E R), victory pose, death | P1 |

Meshy prompts:

- **Stormlord Rykan** — Tempest style: storm-grey steel and brass, sailcloth and rigging, lightning-blue crystal, sky-ship technology, palette sky blue #5fc8ff / brass / slate, Stormlord Rykan: Gryphon-riding frontline hero. Thunderstrikes, rallies the winds, and becomes the eye of a storm, winged or hovering flier, seen from above, wings readable in silhouette, unique champion, more detail and a stronger colour accent than regular troops, distinct head/weapon silhouette, top-down readable, game-ready low poly (8-12k tris), 1024 PBR texture, rigged humanoid or creature rig
  - Ability VFX to pair with the casts: Thunderstrike (enemy), Wind Rally (none), Skyfury Aura (none), Eye of the Storm (none).
- **Skybreaker Lyrian** — Tempest style: storm-grey steel and brass, sailcloth and rigging, lightning-blue crystal, sky-ship technology, palette sky blue #5fc8ff / brass / slate, Skybreaker Lyrian: Council engineer. Boosts tribute, shields allies from projectiles, and calls the Armada, unique champion, more detail and a stronger colour accent than regular troops, distinct head/weapon silhouette, top-down readable, game-ready low poly (8-12k tris), 1024 PBR texture, rigged humanoid or creature rig
  - Ability VFX to pair with the casts: Trade Winds (none), Zephyr Ward (point), Aerial Logistik (none), Call of the Armada (point).
- **Stormcaller Alyssia** — Tempest style: storm-grey steel and brass, sailcloth and rigging, lightning-blue crystal, sky-ship technology, palette sky blue #5fc8ff / brass / slate, Stormcaller Alyssia: Fragile storm mage. Chain lightning, cloudbursts, map-wide clarity and the Hurricane Maelstrom, unique champion, more detail and a stronger colour accent than regular troops, distinct head/weapon silhouette, top-down readable, game-ready low poly (8-12k tris), 1024 PBR texture, rigged humanoid or creature rig
  - Ability VFX to pair with the casts: Chain Lightning (enemy), Cloudburst (point), Eye of Clarity (none), Hurricane Maelstrom (point).

### Units (11)

| Id | Name | Type | Tier | Size | Animations | Priority |
|---|---|---|---|---|---|---|
| `windcaster` | Windcaster | worker | 1 | small (1 tile, radius 10 px) | idle, walk, gather (swing/pick), carry-walk, build (hammer), death | P1 |
| `stormblade` | Stormblade | infantry | 1 | small (1 tile, radius 10 px) | idle, walk, attack (melee), death | P1 |
| `wind_archer` | Wind Archer | ranged | 1 | small (1 tile, radius 10 px) | idle, walk, attack (draw and release), death | P1 |
| `skywing` | Skywing | flying | 1 | small (1 tile, radius 10 px) | idle hover, fly, attack, death (fall) | P1 |
| `thunderhawk` | Thunderhawk | flying | 2 | small (1 tile, radius 10 px) | idle hover, fly, attack, death (fall) | P2 |
| `tempest_rider` | Tempest Rider | flying | 2 | medium (1.5 tiles, radius 12 px) | idle hover, fly, attack, death (fall) | P2 |
| `storm_golem` | Storm Golem | infantry | 2 | medium (1.5 tiles, radius 12 px) | idle, walk, attack (melee), death | P2 |
| `lightning_cannon` | Lightning Cannon | siege | 2 | medium (1.5 tiles, radius 12 px) | idle, move, fire (recoil), death (break apart) | P2 |
| `tempest_weaver` | Tempest Weaver | caster | 3 | medium (1.5 tiles, radius 12 px) | idle, walk, cast (channel), attack, death | P3 |
| `sky_leviathan` | Sky Leviathan | flying | 3 | large (2 tiles, radius 14 px) | idle hover, fly, attack, death (fall) | P3 |
| `armada_trooper` | Armada Shocktrooper | infantry | 1 | small (1 tile, radius 10 px) | idle, walk, attack (melee), death | P1 |

Meshy prompts:

- **Windcaster** — Tempest style: storm-grey steel and brass, sailcloth and rigging, lightning-blue crystal, sky-ship technology, palette sky blue #5fc8ff / brass / slate, Windcaster: Worker. Builds structures. Income comes from tribute, not gathering, carries a tool and a small resource container, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Stormblade** — Tempest style: storm-grey steel and brass, sailcloth and rigging, lightning-blue crystal, sky-ship technology, palette sky blue #5fc8ff / brass / slate, Stormblade: Lightning-charged swordsman. Each hit adds shock damage that ignores armor, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Wind Archer** — Tempest style: storm-grey steel and brass, sailcloth and rigging, lightning-blue crystal, sky-ship technology, palette sky blue #5fc8ff / brass / slate, Wind Archer: Long-range crossbowman guided by wind spirits. Hits air, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Skywing** — Tempest style: storm-grey steel and brass, sailcloth and rigging, lightning-blue crystal, sky-ship technology, palette sky blue #5fc8ff / brass / slate, Skywing: Flying scout with excellent vision. Minimal combat value, winged or hovering flier, seen from above, wings readable in silhouette, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Thunderhawk** — Tempest style: storm-grey steel and brass, sailcloth and rigging, lightning-blue crystal, sky-ship technology, palette sky blue #5fc8ff / brass / slate, Thunderhawk: Flying fighter with a stormrifle. Strikes ground and air, winged or hovering flier, seen from above, wings readable in silhouette, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Tempest Rider** — Tempest style: storm-grey steel and brass, sailcloth and rigging, lightning-blue crystal, sky-ship technology, palette sky blue #5fc8ff / brass / slate, Tempest Rider: Elite drake cavalry. Devastating dives against ground targets, winged or hovering flier, seen from above, wings readable in silhouette, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Storm Golem** — Tempest style: storm-grey steel and brass, sailcloth and rigging, lightning-blue crystal, sky-ship technology, palette sky blue #5fc8ff / brass / slate, Storm Golem: Stormsteel construct. Heavy melee bruiser for holding the line, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Lightning Cannon** — Tempest style: storm-grey steel and brass, sailcloth and rigging, lightning-blue crystal, sky-ship technology, palette sky blue #5fc8ff / brass / slate, Lightning Cannon: Siege artillery firing arcing bolts. Splash, double vs structures, wheeled or legged war machine with an obvious launcher, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Tempest Weaver** — Tempest style: storm-grey steel and brass, sailcloth and rigging, lightning-blue crystal, sky-ship technology, palette sky blue #5fc8ff / brass / slate, Tempest Weaver: Master sorcerer. Attacks chain lightning to 3 extra targets, robed figure with a glowing focus object, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Sky Leviathan** — Tempest style: storm-grey steel and brass, sailcloth and rigging, lightning-blue crystal, sky-ship technology, palette sky blue #5fc8ff / brass / slate, Sky Leviathan: Capital airship: a flying artillery platform bristling with lightning cannons, winged or hovering flier, seen from above, wings readable in silhouette, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Armada Shocktrooper** — Tempest style: storm-grey steel and brass, sailcloth and rigging, lightning-blue crystal, sky-ship technology, palette sky blue #5fc8ff / brass / slate, Armada Shocktrooper: Reinforcement summoned by Call of the Armada, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig

### Buildings (15)

| Id | Name | Footprint | Tier | Extra states | Priority |
|---|---|---|---|---|---|
| `stormspire` | Stormspire Outpost | 3x3 | 1 | construction, destroyed, 3 tier variants, active glow / emitter | P1 |
| `gale_barracks` | Gale Barracks | 2x2 | 1 | construction, destroyed | P1 |
| `aerie` | Aerie / Skyworks | 2x2 | 1 | construction, destroyed | P1 |
| `aetherforge` | Aetherforge | 2x2 | 1 | construction, destroyed | P1 |
| `stormcall_array` | Stormcall Array | 2x2 | 1 | construction, destroyed | P1 |
| `stormcall_tower` | Stormcall Tower | 1x1 | 1 | construction, destroyed, active glow / emitter | P1 |
| `thunderhead_tower` | Thunderhead Tower | 1x1 | 1 | construction, destroyed, active glow / emitter | P1 |
| `cyclone_totem` | Cyclone Totem | 1x1 | 1 | construction, destroyed, active glow / emitter | P1 |
| `tempest_barrier` | Tempest Barrier | 1x1 | 1 | construction, destroyed | P1 |
| `storm_beacon` | Storm Beacon | 1x1 | 1 | construction, destroyed | P1 |
| `tempest_forge` | Tempest Forge | 3x3 | 2 | construction, destroyed | P2 |
| `stratosanct` | Stratosanct | 2x2 | 2 | construction, destroyed | P2 |
| `stormseer_conclave` | Stormseer Conclave | 2x2 | 3 | construction, destroyed | P3 |
| `celestial_bastion` | Celestial Bastion | 3x3 | 3 | construction, destroyed | P3 |
| `maelstrom_altar` | Maelstrom Altar | 2x2 | 3 | construction, destroyed | P3 |

Meshy prompts:

- **Stormspire Outpost** — Tempest style: storm-grey steel and brass, sailcloth and rigging, lightning-blue crystal, sky-ship technology, palette sky blue #5fc8ff / brass / slate, Stormspire Outpost: Your floating base. Trains Windcasters and heroes, pays Stormsteel tribute, zaps nearby ground foes. Can relocate, footprint 3x3 tiles, seen from above at a slight angle, strong roof silhouette, main base, three visual tiers (Tier 1 modest, Tier 2 expanded, Tier 3 monumental with a crowning light or spire), defensive tower with a clear emitter at the top, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Gale Barracks** — Tempest style: storm-grey steel and brass, sailcloth and rigging, lightning-blue crystal, sky-ship technology, palette sky blue #5fc8ff / brass / slate, Gale Barracks: Trains Stormblades and Wind Archers. Researches Stormsteel Weapons. +8 supply, footprint 2x2 tiles, seen from above at a slight angle, strong roof silhouette, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Aerie / Skyworks** — Tempest style: storm-grey steel and brass, sailcloth and rigging, lightning-blue crystal, sky-ship technology, palette sky blue #5fc8ff / brass / slate, Aerie / Skyworks: Sky-pads for fliers. Trains Skywings; at Tier 2 becomes a Skyworks training Thunderhawks and Tempest Riders. +6 supply, footprint 2x2 tiles, seen from above at a slight angle, strong roof silhouette, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Aetherforge** — Tempest style: storm-grey steel and brass, sailcloth and rigging, lightning-blue crystal, sky-ship technology, palette sky blue #5fc8ff / brass / slate, Aetherforge: Built on a stormglass node. Refines ore into Stormsteel tribute automatically (2/s). +6 supply, footprint 2x2 tiles, seen from above at a slight angle, strong roof silhouette, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Stormcall Array** — Tempest style: storm-grey steel and brass, sailcloth and rigging, lightning-blue crystal, sky-ship technology, palette sky blue #5fc8ff / brass / slate, Stormcall Array: Built on an aether vent. Siphons Aether Crystals (0.5/s, doubled during storms), footprint 2x2 tiles, seen from above at a slight angle, strong roof silhouette, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Stormcall Tower** — Tempest style: storm-grey steel and brass, sailcloth and rigging, lightning-blue crystal, sky-ship technology, palette sky blue #5fc8ff / brass / slate, Stormcall Tower: Lightning tower (chains to 2) and weather-tech hub. Researches Forecast and Static Shield. Required for Tier 2, footprint 1x1 tiles, seen from above at a slight angle, strong roof silhouette, defensive tower with a clear emitter at the top, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Thunderhead Tower** — Tempest style: storm-grey steel and brass, sailcloth and rigging, lightning-blue crystal, sky-ship technology, palette sky blue #5fc8ff / brass / slate, Thunderhead Tower: Heavy lightning tower. Prioritizes fliers, chains to 2 targets, footprint 1x1 tiles, seen from above at a slight angle, strong roof silhouette, defensive tower with a clear emitter at the top, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Cyclone Totem** — Tempest style: storm-grey steel and brass, sailcloth and rigging, lightning-blue crystal, sky-ship technology, palette sky blue #5fc8ff / brass / slate, Cyclone Totem: No attack. Allies nearby take 50% less ranged damage; enemies are slowed by the gale, footprint 1x1 tiles, seen from above at a slight angle, strong roof silhouette, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Tempest Barrier** — Tempest style: storm-grey steel and brass, sailcloth and rigging, lightning-blue crystal, sky-ship technology, palette sky blue #5fc8ff / brass / slate, Tempest Barrier: Wall of solidified wind. Blocks ground AND air movement, footprint 1x1 tiles, seen from above at a slight angle, strong roof silhouette, modular wall segment that tiles in a line, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Storm Beacon** — Tempest style: storm-grey steel and brass, sailcloth and rigging, lightning-blue crystal, sky-ship technology, palette sky blue #5fc8ff / brass / slate, Storm Beacon: Sensor outpost with enormous vision. Reveals invisible units, footprint 1x1 tiles, seen from above at a slight angle, strong roof silhouette, sensor structure with a large eye, lens, or beacon, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Tempest Forge** — Tempest style: storm-grey steel and brass, sailcloth and rigging, lightning-blue crystal, sky-ship technology, palette sky blue #5fc8ff / brass / slate, Tempest Forge: Workshop. Trains Storm Golems and Lightning Cannons. Researches Overcharge Capacitors, footprint 3x3 tiles, seen from above at a slight angle, strong roof silhouette, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Stratosanct** — Tempest style: storm-grey steel and brass, sailcloth and rigging, lightning-blue crystal, sky-ship technology, palette sky blue #5fc8ff / brass / slate, Stratosanct: Floating sanctum. Trickles Aether (0.3/s), researches Tribute Efficiency. Required for Tier 3, footprint 2x2 tiles, seen from above at a slight angle, strong roof silhouette, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Stormseer Conclave** — Tempest style: storm-grey steel and brass, sailcloth and rigging, lightning-blue crystal, sky-ship technology, palette sky blue #5fc8ff / brass / slate, Stormseer Conclave: Ultimate mage guild. Trains Tempest Weavers. Researches Storm Amplification, footprint 2x2 tiles, seen from above at a slight angle, strong roof silhouette, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Celestial Bastion** — Tempest style: storm-grey steel and brass, sailcloth and rigging, lightning-blue crystal, sky-ship technology, palette sky blue #5fc8ff / brass / slate, Celestial Bastion: Capital shipyard. Builds Sky Leviathans. +8 supply, footprint 3x3 tiles, seen from above at a slight angle, strong roof silhouette, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Maelstrom Altar** — Tempest style: storm-grey steel and brass, sailcloth and rigging, lightning-blue crystal, sky-ship technology, palette sky blue #5fc8ff / brass / slate, Maelstrom Altar: Channels a Tempest Pearl every 150s (holds 1). Spend a Pearl to unleash the Eye of Auranth — a map-wide storm, footprint 2x2 tiles, seen from above at a slight angle, strong roof silhouette, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants

## Radiance (provisional roster)

*Radiance style: gilded bronze and white marble, sun-disc motifs, warm gold light, clean heroic shapes, palette gold #ffcc44 / bronze / ivory*

Tier names for the main base: Sunforge Citadel → Sunforge Citadel — Solar Crown → Sunforge Citadel — Zenith.
Resources to depict on nodes and in icons: Sunstone (primary), Dawnlight (secondary), Phoenix Feather (catalyst).

### Heroes (3)

| Id | Name | Role | Size | Animations | Priority |
|---|---|---|---|---|---|
| `aurelian` | Aurelian Dawnblade | Frontline paladin | hero (1.5 tiles, radius 14 px, distinctive silhouette) | idle, walk, attack, 4 ability casts (Q W E R), victory pose, death | P1 |
| `seraphine` | Seraphine Lightkeeper | Healer and steward | hero (1.5 tiles, radius 14 px, distinctive silhouette) | idle, walk, attack, 4 ability casts (Q W E R), victory pose, death | P1 |
| `solaris` | Solaris | Ranged sun-mage | hero (1.5 tiles, radius 14 px, distinctive silhouette) | idle, walk, attack, 4 ability casts (Q W E R), victory pose, death | P1 |

Meshy prompts:

- **Aurelian Dawnblade** — Radiance style: gilded bronze and white marble, sun-disc motifs, warm gold light, clean heroic shapes, palette gold #ffcc44 / bronze / ivory, Aurelian Dawnblade: Frontline paladin. Smites, rallies and calls down the judgment of the sun, unique champion, more detail and a stronger colour accent than regular troops, distinct head/weapon silhouette, top-down readable, game-ready low poly (8-12k tris), 1024 PBR texture, rigged humanoid or creature rig
  - Ability VFX to pair with the casts: Sun Smite (enemy), Rally of Dawn (none), Blinding Flare (point), Judgment of the Sun (point).
- **Seraphine Lightkeeper** — Radiance style: gilded bronze and white marble, sun-disc motifs, warm gold light, clean heroic shapes, palette gold #ffcc44 / bronze / ivory, Seraphine Lightkeeper: Healer and steward. Blesses the tithe, sanctifies ground, and raises the fallen, unique champion, more detail and a stronger colour accent than regular troops, distinct head/weapon silhouette, top-down readable, game-ready low poly (8-12k tris), 1024 PBR texture, rigged humanoid or creature rig
  - Ability VFX to pair with the casts: Healing Light (ally), Sanctified Ground (point), Blessed Tithe (none), Resurrection (point).
- **Solaris** — Radiance style: gilded bronze and white marble, sun-disc motifs, warm gold light, clean heroic shapes, palette gold #ffcc44 / bronze / ivory, Solaris: Ranged sun-mage. Lances of light, dawn bursts, light-steps and the Supernova, unique champion, more detail and a stronger colour accent than regular troops, distinct head/weapon silhouette, top-down readable, game-ready low poly (8-12k tris), 1024 PBR texture, rigged humanoid or creature rig
  - Ability VFX to pair with the casts: Solar Lance (enemy), Dawnstrike (point), Light Step (point), Supernova (none).

### Units (10)

| Id | Name | Type | Tier | Size | Animations | Priority |
|---|---|---|---|---|---|---|
| `sunbearer` | Sunbearer | worker | 1 | small (1 tile, radius 10 px) | idle, walk, gather (swing/pick), carry-walk, build (hammer), death | P1 |
| `dawn_legionary` | Dawn Legionary | infantry | 1 | small (1 tile, radius 10 px) | idle, walk, attack (melee), death | P1 |
| `solar_archer` | Solar Archer | ranged | 1 | small (1 tile, radius 10 px) | idle, walk, attack (draw and release), death | P1 |
| `sun_priest` | Sun Priest | caster | 1 | small (1 tile, radius 10 px) | idle, walk, cast (channel), attack, death | P1 |
| `sunforged_knight` | Sunforged Knight | infantry | 2 | medium (1.5 tiles, radius 12 px) | idle, walk, attack (melee), death | P2 |
| `phoenix_herald` | Phoenix Herald | flying | 2 | small (1 tile, radius 10 px) | idle hover, fly, attack, death (fall) | P2 |
| `pyrestorm_engine` | Pyrestorm Engine | siege | 2 | medium (1.5 tiles, radius 12 px) | idle, move, fire (recoil), death (break apart) | P2 |
| `radiant_angel` | Radiant Angel | flying | 3 | large (2 tiles, radius 14 px) | idle hover, fly, attack, death (fall) | P3 |
| `solar_titan` | Solar Titan | infantry | 3 | large (2 tiles, radius 14 px) | idle, walk, attack (melee), death | P3 |
| `avatar_of_dawn` | Avatar of Dawn | infantry | 3 | colossal (2.5 tiles, radius 14 px, towers over units) | idle, walk, attack (melee), death | P3 |

Meshy prompts:

- **Sunbearer** — Radiance style: gilded bronze and white marble, sun-disc motifs, warm gold light, clean heroic shapes, palette gold #ffcc44 / bronze / ivory, Sunbearer: Worker. Gathers Sunstone and builds structures, carries a tool and a small resource container, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Dawn Legionary** — Radiance style: gilded bronze and white marble, sun-disc motifs, warm gold light, clean heroic shapes, palette gold #ffcc44 / bronze / ivory, Dawn Legionary: Disciplined shield infantry. Sturdy line-holder, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Solar Archer** — Radiance style: gilded bronze and white marble, sun-disc motifs, warm gold light, clean heroic shapes, palette gold #ffcc44 / bronze / ivory, Solar Archer: Ranged. Arrows of focused light strike ground and air, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Sun Priest** — Radiance style: gilded bronze and white marble, sun-disc motifs, warm gold light, clean heroic shapes, palette gold #ffcc44 / bronze / ivory, Sun Priest: Healer. Mends wounded allies with sunlight (auto). Weak attack, robed figure with a glowing focus object, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Sunforged Knight** — Radiance style: gilded bronze and white marble, sun-disc motifs, warm gold light, clean heroic shapes, palette gold #ffcc44 / bronze / ivory, Sunforged Knight: Heavy cavalry in blazing plate. Fast, armored charge, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Phoenix Herald** — Radiance style: gilded bronze and white marble, sun-disc motifs, warm gold light, clean heroic shapes, palette gold #ffcc44 / bronze / ivory, Phoenix Herald: Flying firebird. Splash fire on ground and air. Rises again once after death, winged or hovering flier, seen from above, wings readable in silhouette, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Pyrestorm Engine** — Radiance style: gilded bronze and white marble, sun-disc motifs, warm gold light, clean heroic shapes, palette gold #ffcc44 / bronze / ivory, Pyrestorm Engine: Siege engine hurling solar fire. Splash, double vs structures, wheeled or legged war machine with an obvious launcher, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Radiant Angel** — Radiance style: gilded bronze and white marble, sun-disc motifs, warm gold light, clean heroic shapes, palette gold #ffcc44 / bronze / ivory, Radiant Angel: Celestial flier. Smites with holy light and mends allies between strikes, winged or hovering flier, seen from above, wings readable in silhouette, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Solar Titan** — Radiance style: gilded bronze and white marble, sun-disc motifs, warm gold light, clean heroic shapes, palette gold #ffcc44 / bronze / ivory, Solar Titan: Colossal sun-forged construct. Splash melee, carries sunlight with it, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Avatar of Dawn** — Radiance style: gilded bronze and white marble, sun-disc motifs, warm gold light, clean heroic shapes, palette gold #ffcc44 / bronze / ivory, Avatar of Dawn: One may exist. The sun made flesh: burns enemies and heals allies around it, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig

### Buildings (11)

| Id | Name | Footprint | Tier | Extra states | Priority |
|---|---|---|---|---|---|
| `sunforge_citadel` | Sunforge Citadel | 3x3 | 1 | construction, destroyed, 3 tier variants | P1 |
| `solar_crucible` | Solar Crucible | 2x2 | 1 | construction, destroyed, active glow / emitter | P1 |
| `sunstone_vault` | Sunstone Vault | 2x2 | 1 | construction, destroyed, active glow / emitter | P1 |
| `radiant_shrine` | Radiant Shrine | 2x2 | 1 | construction, destroyed, active glow / emitter | P1 |
| `blazing_bastion` | Blazing Bastion | 1x1 | 1 | construction, destroyed, active glow / emitter | P1 |
| `emberline_gate` | Emberline Gate | 1x1 | 1 | construction, destroyed | P1 |
| `dawnwatch_beacon` | Dawnwatch Beacon | 1x1 | 1 | construction, destroyed, active glow / emitter | P1 |
| `heliarch_spire` | Heliarch Spire | 2x2 | 2 | construction, destroyed, active glow / emitter | P2 |
| `phoenix_roost` | Phoenix Roost | 2x2 | 2 | construction, destroyed, active glow / emitter | P2 |
| `pyrestorm_battery` | Pyrestorm Battery | 2x2 | 2 | construction, destroyed, active glow / emitter | P2 |
| `solar_relay` | Solar Relay | 2x2 | 2 | construction, destroyed, active glow / emitter | P2 |

Meshy prompts:

- **Sunforge Citadel** — Radiance style: gilded bronze and white marble, sun-disc motifs, warm gold light, clean heroic shapes, palette gold #ffcc44 / bronze / ivory, Sunforge Citadel: Your main base. Trains Sunbearers and heroes, receives Sunstone, radiates sunlight, footprint 3x3 tiles, seen from above at a slight angle, strong roof silhouette, main base, three visual tiers (Tier 1 modest, Tier 2 expanded, Tier 3 monumental with a crowning light or spire), built over a resource node, with intake channels, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Solar Crucible** — Radiance style: gilded bronze and white marble, sun-disc motifs, warm gold light, clean heroic shapes, palette gold #ffcc44 / bronze / ivory, Solar Crucible: Unit and weapon production. Trains Legionaries and Solar Archers; at Tier 2 forges Sunforged Knights and Pyrestorm Engines. Researches Blessed Steel and Sunforged Plate. +8 supply, footprint 2x2 tiles, seen from above at a slight angle, strong roof silhouette, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Sunstone Vault** — Radiance style: gilded bronze and white marble, sun-disc motifs, warm gold light, clean heroic shapes, palette gold #ffcc44 / bronze / ivory, Sunstone Vault: Built on a Sunstone node. Drop-off for Sunbearers; refines a trickle (0.5/s) on its own. +4 supply, footprint 2x2 tiles, seen from above at a slight angle, strong roof silhouette, built over a resource node, with intake channels, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Radiant Shrine** — Radiance style: gilded bronze and white marble, sun-disc motifs, warm gold light, clean heroic shapes, palette gold #ffcc44 / bronze / ivory, Radiant Shrine: Trains Sun Priests, heals nearby units (3/s) and generates Dawnlight (0.4/s). Spreads sunlight. Required for Tier 2, footprint 2x2 tiles, seen from above at a slight angle, strong roof silhouette, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Blazing Bastion** — Radiance style: gilded bronze and white marble, sun-disc motifs, warm gold light, clean heroic shapes, palette gold #ffcc44 / bronze / ivory, Blazing Bastion: Defensive tower. Beams of concentrated sunlight; +25% damage when standing in sunlight, footprint 1x1 tiles, seen from above at a slight angle, strong roof silhouette, defensive tower with a clear emitter at the top, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Emberline Gate** — Radiance style: gilded bronze and white marble, sun-disc motifs, warm gold light, clean heroic shapes, palette gold #ffcc44 / bronze / ivory, Emberline Gate: Wall segment of sun-tempered stone. Burns melee attackers, footprint 1x1 tiles, seen from above at a slight angle, strong roof silhouette, modular wall segment that tiles in a line, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Dawnwatch Beacon** — Radiance style: gilded bronze and white marble, sun-disc motifs, warm gold light, clean heroic shapes, palette gold #ffcc44 / bronze / ivory, Dawnwatch Beacon: Sensor tower with long sight. Reveals hidden units and spreads sunlight, footprint 1x1 tiles, seen from above at a slight angle, strong roof silhouette, sensor structure with a large eye, lens, or beacon, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Heliarch Spire** — Radiance style: gilded bronze and white marble, sun-disc motifs, warm gold light, clean heroic shapes, palette gold #ffcc44 / bronze / ivory, Heliarch Spire: Technology centre. Researches Daybreak, Radiant Wards and Eternal Dawn; trickles Dawnlight (0.5/s). Required for Tier 3. At Tier 3 forges Solar Titans and, with a Phoenix Feather, the Avatar of Dawn. Channels a Feather every 150s, footprint 2x2 tiles, seen from above at a slight angle, strong roof silhouette, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Phoenix Roost** — Radiance style: gilded bronze and white marble, sun-disc motifs, warm gold light, clean heroic shapes, palette gold #ffcc44 / bronze / ivory, Phoenix Roost: (addition to the canon list) Roost of solar fire for Phoenix Heralds and, at Tier 3, Radiant Angels. +6 supply, footprint 2x2 tiles, seen from above at a slight angle, strong roof silhouette, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Pyrestorm Battery** — Radiance style: gilded bronze and white marble, sun-disc motifs, warm gold light, clean heroic shapes, palette gold #ffcc44 / bronze / ivory, Pyrestorm Battery: Long-range artillery structure. Slow, heavy solar shells with splash, footprint 2x2 tiles, seen from above at a slight angle, strong roof silhouette, defensive tower with a clear emitter at the top, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Solar Relay** — Radiance style: gilded bronze and white marble, sun-disc motifs, warm gold light, clean heroic shapes, palette gold #ffcc44 / bronze / ivory, Solar Relay: Map-wide power projection. Solar Surge: for 15s all Radiance units gain +20% damage and towers +50%, footprint 2x2 tiles, seen from above at a slight angle, strong roof silhouette, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants

## Sanctuary (provisional roster)

*Sanctuary style: white and silver plate, pale blue-violet glow, stained-glass and halo motifs, angelic and orderly, palette ivory #e8e4ff / silver / soft blue*

Tier names for the main base: Luminarch Citadel → Luminarch Citadel — Cathedral → Luminarch Citadel — Celestial Sanctum.
Resources to depict on nodes and in icons: Sacred Crystals (primary), Holy Light (secondary), Seraph's Tear (catalyst).

### Heroes (3)

| Id | Name | Role | Size | Animations | Priority |
|---|---|---|---|---|---|
| `isolde` | Commander Isolde Vale | Frontline commander | hero (1.5 tiles, radius 14 px, distinctive silhouette) | idle, walk, attack, 4 ability casts (Q W E R), victory pose, death | P1 |
| `adaline` | Mother Adaline | Healer and steward | hero (1.5 tiles, radius 14 px, distinctive silhouette) | idle, walk, attack, 4 ability casts (Q W E R), victory pose, death | P1 |
| `cassiel` | Oracle Cassiel | Ranged oracle | hero (1.5 tiles, radius 14 px, distinctive silhouette) | idle, walk, attack, 4 ability casts (Q W E R), victory pose, death | P1 |

Meshy prompts:

- **Commander Isolde Vale** — Sanctuary style: white and silver plate, pale blue-violet glow, stained-glass and halo motifs, angelic and orderly, palette ivory #e8e4ff / silver / soft blue, Commander Isolde Vale: Frontline commander. Holy strikes, shield walls, banners of order and divine intervention, unique champion, more detail and a stronger colour accent than regular troops, distinct head/weapon silhouette, top-down readable, game-ready low poly (8-12k tris), 1024 PBR texture, rigged humanoid or creature rig
  - Ability VFX to pair with the casts: Holy Strike (enemy), Shield Wall (none), Banner of Order (none), Divine Intervention (none).
- **Mother Adaline** — Sanctuary style: white and silver plate, pale blue-violet glow, stained-glass and halo motifs, angelic and orderly, palette ivory #e8e4ff / silver / soft blue, Mother Adaline: Healer and steward. Mends wounds, consecrates ground, blesses the tithe and raises the fallen, unique champion, more detail and a stronger colour accent than regular troops, distinct head/weapon silhouette, top-down readable, game-ready low poly (8-12k tris), 1024 PBR texture, rigged humanoid or creature rig
  - Ability VFX to pair with the casts: Mend Wounds (ally), Consecrate (point), Tithe of Faith (none), Mass Resurrection (point).
- **Oracle Cassiel** — Sanctuary style: white and silver plate, pale blue-violet glow, stained-glass and halo motifs, angelic and orderly, palette ivory #e8e4ff / silver / soft blue, Oracle Cassiel: Ranged oracle. Smites, banishes corruption, steps through light and calls the wrath of heaven, unique champion, more detail and a stronger colour accent than regular troops, distinct head/weapon silhouette, top-down readable, game-ready low poly (8-12k tris), 1024 PBR texture, rigged humanoid or creature rig
  - Ability VFX to pair with the casts: Smite (enemy), Banish Corruption (point), Celestial Step (point), Wrath of Heaven (point).

### Units (11)

| Id | Name | Type | Tier | Size | Animations | Priority |
|---|---|---|---|---|---|---|
| `pilgrim` | Pilgrim | worker | 1 | small (1 tile, radius 10 px) | idle, walk, gather (swing/pick), carry-walk, build (hammer), death | P1 |
| `temple_guard` | Temple Guard | infantry | 1 | small (1 tile, radius 10 px) | idle, walk, attack (melee), death | P1 |
| `seraphic_archer` | Seraphic Archer | ranged | 1 | small (1 tile, radius 10 px) | idle, walk, attack (draw and release), death | P1 |
| `cleric` | Cleric | caster | 1 | small (1 tile, radius 10 px) | idle, walk, cast (channel), attack, death | P1 |
| `celestial_paladin` | Celestial Paladin | infantry | 2 | medium (1.5 tiles, radius 12 px) | idle, walk, attack (melee), death | P2 |
| `divine_griffin` | Divine Griffin | flying | 2 | medium (1.5 tiles, radius 12 px) | idle hover, fly, attack, death (fall) | P2 |
| `inquisitor` | Inquisitor | caster | 2 | small (1 tile, radius 10 px) | idle, walk, cast (channel), attack, death | P2 |
| `blessed_trebuchet` | Blessed Trebuchet | siege | 2 | medium (1.5 tiles, radius 12 px) | idle, move, fire (recoil), death (break apart) | P2 |
| `seraph` | Seraph | flying | 3 | large (2 tiles, radius 14 px) | idle hover, fly, attack, death (fall) | P3 |
| `exemplar` | Exemplar | infantry | 3 | large (2 tiles, radius 14 px) | idle, walk, attack (melee), death | P3 |
| `archangel` | Archangel | flying | 3 | colossal (2.5 tiles, radius 14 px, towers over units) | idle hover, fly, attack, death (fall) | P3 |

Meshy prompts:

- **Pilgrim** — Sanctuary style: white and silver plate, pale blue-violet glow, stained-glass and halo motifs, angelic and orderly, palette ivory #e8e4ff / silver / soft blue, Pilgrim: Worker. Gathers Sacred Crystals and builds structures, carries a tool and a small resource container, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Temple Guard** — Sanctuary style: white and silver plate, pale blue-violet glow, stained-glass and halo motifs, angelic and orderly, palette ivory #e8e4ff / silver / soft blue, Temple Guard: Warded shield infantry. Steady and hard to break, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Seraphic Archer** — Sanctuary style: white and silver plate, pale blue-violet glow, stained-glass and halo motifs, angelic and orderly, palette ivory #e8e4ff / silver / soft blue, Seraphic Archer: Ranged. Blessed arrows strike ground and air, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Cleric** — Sanctuary style: white and silver plate, pale blue-violet glow, stained-glass and halo motifs, angelic and orderly, palette ivory #e8e4ff / silver / soft blue, Cleric: Healer. Mends allies with Holy Light (auto). Weak attack, strong vs undead, robed figure with a glowing focus object, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Celestial Paladin** — Sanctuary style: white and silver plate, pale blue-violet glow, stained-glass and halo motifs, angelic and orderly, palette ivory #e8e4ff / silver / soft blue, Celestial Paladin: Heavily warded holy knight. The wall of the faithful, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Divine Griffin** — Sanctuary style: white and silver plate, pale blue-violet glow, stained-glass and halo motifs, angelic and orderly, palette ivory #e8e4ff / silver / soft blue, Divine Griffin: Flying beast of heaven. Dives on ground and air targets, winged or hovering flier, seen from above, wings readable in silhouette, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Inquisitor** — Sanctuary style: white and silver plate, pale blue-violet glow, stained-glass and halo motifs, angelic and orderly, palette ivory #e8e4ff / silver / soft blue, Inquisitor: Holy caster. Searing light, double damage to the undead, robed figure with a glowing focus object, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Blessed Trebuchet** — Sanctuary style: white and silver plate, pale blue-violet glow, stained-glass and halo motifs, angelic and orderly, palette ivory #e8e4ff / silver / soft blue, Blessed Trebuchet: Consecrated siege engine. Splash, double vs structures, wheeled or legged war machine with an obvious launcher, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Seraph** — Sanctuary style: white and silver plate, pale blue-violet glow, stained-glass and halo motifs, angelic and orderly, palette ivory #e8e4ff / silver / soft blue, Seraph: Winged celestial. Smites with light and heals allies between strikes, winged or hovering flier, seen from above, wings readable in silhouette, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Exemplar** — Sanctuary style: white and silver plate, pale blue-violet glow, stained-glass and halo motifs, angelic and orderly, palette ivory #e8e4ff / silver / soft blue, Exemplar: Champion of the Concord. Immense ward, splash strikes, carries holy ground, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Archangel** — Sanctuary style: white and silver plate, pale blue-violet glow, stained-glass and halo motifs, angelic and orderly, palette ivory #e8e4ff / silver / soft blue, Archangel: One may exist. Heaven's general: an aura that shields allies and burns the unholy, winged or hovering flier, seen from above, wings readable in silhouette, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig

### Buildings (13)

| Id | Name | Footprint | Tier | Extra states | Priority |
|---|---|---|---|---|---|
| `luminarch_citadel` | Luminarch Citadel | 3x3 | 1 | construction, destroyed, 3 tier variants | P1 |
| `beaconwright_hall` | Beaconwright Hall | 2x2 | 1 | construction, destroyed, active glow / emitter | P1 |
| `sanctified_vault` | Sanctified Vault | 2x2 | 1 | construction, destroyed, active glow / emitter | P1 |
| `sacrosanct_shrine` | Sacrosanct Shrine | 2x2 | 1 | construction, destroyed, active glow / emitter | P1 |
| `radiant_tower` | Radiant Tower | 1x1 | 1 | construction, destroyed, active glow / emitter | P1 |
| `refuge_gatehouse` | Refuge Gatehouse | 1x1 | 1 | construction, destroyed, active glow / emitter | P1 |
| `lightborne_relay` | Lightborne Relay | 1x1 | 1 | construction, destroyed, active glow / emitter | P1 |
| `concord_hall` | Concord Hall | 2x2 | 2 | construction, destroyed, active glow / emitter | P2 |
| `hall_of_luminaries` | Hall of Luminaries | 3x3 | 2 | construction, destroyed, active glow / emitter | P2 |
| `griffin_aerie` | Griffin Aerie | 2x2 | 2 | construction, destroyed, active glow / emitter | P2 |
| `siege_chapel` | Siege Chapel | 2x2 | 2 | construction, destroyed, active glow / emitter | P2 |
| `eternal_bell_spire` | Eternal Bell Spire | 2x2 | 2 | construction, destroyed, active glow / emitter | P2 |
| `altar_of_tears` | Altar of Tears | 2x2 | 3 | construction, destroyed, active glow / emitter | P3 |

Meshy prompts:

- **Luminarch Citadel** — Sanctuary style: white and silver plate, pale blue-violet glow, stained-glass and halo motifs, angelic and orderly, palette ivory #e8e4ff / silver / soft blue, Luminarch Citadel: Your main base. Trains Pilgrims and heroes, receives crystals, consecrates the ground, footprint 3x3 tiles, seen from above at a slight angle, strong roof silhouette, main base, three visual tiers (Tier 1 modest, Tier 2 expanded, Tier 3 monumental with a crowning light or spire), built over a resource node, with intake channels, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Beaconwright Hall** — Sanctuary style: white and silver plate, pale blue-violet glow, stained-glass and halo motifs, angelic and orderly, palette ivory #e8e4ff / silver / soft blue, Beaconwright Hall: Unit production. Trains Temple Guards and Seraphic Archers. Researches Blessed Arms. +8 supply, footprint 2x2 tiles, seen from above at a slight angle, strong roof silhouette, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Sanctified Vault** — Sanctuary style: white and silver plate, pale blue-violet glow, stained-glass and halo motifs, angelic and orderly, palette ivory #e8e4ff / silver / soft blue, Sanctified Vault: Built on a crystal node. Drop-off for Pilgrims; refines a trickle (0.5/s). +4 supply, footprint 2x2 tiles, seen from above at a slight angle, strong roof silhouette, built over a resource node, with intake channels, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Sacrosanct Shrine** — Sanctuary style: white and silver plate, pale blue-violet glow, stained-glass and halo motifs, angelic and orderly, palette ivory #e8e4ff / silver / soft blue, Sacrosanct Shrine: Healing and blessing. Trains Clerics, heals nearby (3/s), generates Holy Light (0.4/s). Consecrates ground. Required for Tier 2, footprint 2x2 tiles, seen from above at a slight angle, strong roof silhouette, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Radiant Tower** — Sanctuary style: white and silver plate, pale blue-violet glow, stained-glass and halo motifs, angelic and orderly, palette ivory #e8e4ff / silver / soft blue, Radiant Tower: Defensive tower. Beams of holy light against ground and air; +25% on holy ground, footprint 1x1 tiles, seen from above at a slight angle, strong roof silhouette, defensive tower with a clear emitter at the top, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Refuge Gatehouse** — Sanctuary style: white and silver plate, pale blue-violet glow, stained-glass and halo motifs, angelic and orderly, palette ivory #e8e4ff / silver / soft blue, Refuge Gatehouse: Wall segment of white marble. Consecrates the ground beside it, footprint 1x1 tiles, seen from above at a slight angle, strong roof silhouette, modular wall segment that tiles in a line, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Lightborne Relay** — Sanctuary style: white and silver plate, pale blue-violet glow, stained-glass and halo motifs, angelic and orderly, palette ivory #e8e4ff / silver / soft blue, Lightborne Relay: Map-wide illumination. Long sight, reveals hidden units, spreads holy ground, footprint 1x1 tiles, seen from above at a slight angle, strong roof silhouette, sensor structure with a large eye, lens, or beacon, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Concord Hall** — Sanctuary style: white and silver plate, pale blue-violet glow, stained-glass and halo motifs, angelic and orderly, palette ivory #e8e4ff / silver / soft blue, Concord Hall: Technology centre. Researches Greater Wards and Divine Favor; trickles Holy Light (0.5/s). Required for Tier 3, footprint 2x2 tiles, seen from above at a slight angle, strong roof silhouette, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Hall of Luminaries** — Sanctuary style: white and silver plate, pale blue-violet glow, stained-glass and halo motifs, angelic and orderly, palette ivory #e8e4ff / silver / soft blue, Hall of Luminaries: Hero and champion command. Trains Celestial Paladins and Inquisitors; at Tier 3 Exemplars. +6 supply, footprint 3x3 tiles, seen from above at a slight angle, strong roof silhouette, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Griffin Aerie** — Sanctuary style: white and silver plate, pale blue-violet glow, stained-glass and halo motifs, angelic and orderly, palette ivory #e8e4ff / silver / soft blue, Griffin Aerie: (invented) Eyrie of Divine Griffins; at Tier 3 Seraphs. +6 supply, footprint 2x2 tiles, seen from above at a slight angle, strong roof silhouette, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Siege Chapel** — Sanctuary style: white and silver plate, pale blue-violet glow, stained-glass and halo motifs, angelic and orderly, palette ivory #e8e4ff / silver / soft blue, Siege Chapel: (invented) Consecrates Blessed Trebuchets. +4 supply, footprint 2x2 tiles, seen from above at a slight angle, strong roof silhouette, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Eternal Bell Spire** — Sanctuary style: white and silver plate, pale blue-violet glow, stained-glass and halo motifs, angelic and orderly, palette ivory #e8e4ff / silver / soft blue, Eternal Bell Spire: Global rally. Toll the Bell: for 15s every Sanctuary unit gains +20% damage and +15% speed. Nearby allies attack faster, footprint 2x2 tiles, seen from above at a slight angle, strong roof silhouette, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Altar of Tears** — Sanctuary style: white and silver plate, pale blue-violet glow, stained-glass and halo motifs, angelic and orderly, palette ivory #e8e4ff / silver / soft blue, Altar of Tears: (invented) Gathers a Seraph's Tear every 150s (holds 1). Calls the Archangel. Researches Martyrdom, footprint 2x2 tiles, seen from above at a slight angle, strong roof silhouette, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants

## Verdance (provisional roster)

*Verdance style: living wood, bark and moss, antler and leaf shapes, bioluminescent green accents, organic asymmetry, palette forest green #48d67f / bark brown / moss*

Tier names for the main base: Everwood Spire → Everwood Spire — Silver Bloom → Everwood Spire — Luminous Canopy.
Resources to depict on nodes and in icons: Silver Sap (primary), Everwood Essence (secondary), World Seed (catalyst).

### Heroes (3)

| Id | Name | Role | Size | Animations | Priority |
|---|---|---|---|---|---|
| `kael` | Kael Thornwarden | Frontline warden | hero (1.5 tiles, radius 14 px, distinctive silhouette) | idle, walk, attack, 4 ability casts (Q W E R), victory pose, death | P1 |
| `elowen` | Elowen | Keeper of the grove | hero (1.5 tiles, radius 14 px, distinctive silhouette) | idle, walk, attack, 4 ability casts (Q W E R), victory pose, death | P1 |
| `sylvara` | Sylvara | Spirit mage | hero (1.5 tiles, radius 14 px, distinctive silhouette) | idle, walk, attack, 4 ability casts (Q W E R), victory pose, death | P1 |

Meshy prompts:

- **Kael Thornwarden** — Verdance style: living wood, bark and moss, antler and leaf shapes, bioluminescent green accents, organic asymmetry, palette forest green #48d67f / bark brown / moss, Kael Thornwarden: Frontline warden. Briar charges, bark skin, thorn bursts and the wrath of the wild, unique champion, more detail and a stronger colour accent than regular troops, distinct head/weapon silhouette, top-down readable, game-ready low poly (8-12k tris), 1024 PBR texture, rigged humanoid or creature rig
  - Ability VFX to pair with the casts: Briar Charge (enemy), Bark Skin (none), Thorn Burst (point), Wrath of the Wild (point).
- **Elowen** — Verdance style: living wood, bark and moss, antler and leaf shapes, bioluminescent green accents, organic asymmetry, palette forest green #48d67f / bark brown / moss, Elowen: Keeper of the grove. Mends, seeds the land, blesses the harvest and calls the bloom of life, unique champion, more detail and a stronger colour accent than regular troops, distinct head/weapon silhouette, top-down readable, game-ready low poly (8-12k tris), 1024 PBR texture, rigged humanoid or creature rig
  - Ability VFX to pair with the casts: Mend (ally), Seed the Land (point), Bountiful Harvest (none), Bloom of Life (none).
- **Sylvara** — Verdance style: living wood, bark and moss, antler and leaf shapes, bioluminescent green accents, organic asymmetry, palette forest green #48d67f / bark brown / moss, Sylvara: Spirit mage. Spirit bolts, entangling vines, spirit-walks and awakens the Everwood, unique champion, more detail and a stronger colour accent than regular troops, distinct head/weapon silhouette, top-down readable, game-ready low poly (8-12k tris), 1024 PBR texture, rigged humanoid or creature rig
  - Ability VFX to pair with the casts: Spirit Bolt (enemy), Entangle (point), Spirit Walk (point), Everwood Awakening (none).

### Units (11)

| Id | Name | Type | Tier | Size | Animations | Priority |
|---|---|---|---|---|---|---|
| `tender` | Tender | worker | 1 | small (1 tile, radius 10 px) | idle, walk, gather (swing/pick), carry-walk, build (hammer), death | P1 |
| `thornguard` | Thornguard | infantry | 1 | small (1 tile, radius 10 px) | idle, walk, attack (melee), death | P1 |
| `briar_archer` | Briar Archer | ranged | 1 | small (1 tile, radius 10 px) | idle, walk, attack (draw and release), death | P1 |
| `forest_nymph` | Forest Nymph | caster | 1 | small (1 tile, radius 10 px) | idle, walk, cast (channel), attack, death | P1 |
| `verdant_sentinel` | Verdant Sentinel | infantry | 2 | medium (1.5 tiles, radius 12 px) | idle, walk, attack (melee), death | P2 |
| `everwood_spirit` | Spirit of the Everwood | flying | 2 | small (1 tile, radius 10 px) | idle hover, fly, attack, death (fall) | P2 |
| `dire_stag` | Dire Stag | infantry | 2 | small (1 tile, radius 10 px) | idle, walk, attack (melee), death | P2 |
| `rootcrusher` | Rootcrusher | siege | 2 | medium (1.5 tiles, radius 12 px) | idle, move, fire (recoil), death (break apart) | P2 |
| `ancient_treant` | Ancient Treant | infantry | 3 | large (2 tiles, radius 14 px) | idle, walk, attack (melee), death | P3 |
| `great_owl` | Great Owl | flying | 3 | medium (1.5 tiles, radius 12 px) | idle hover, fly, attack, death (fall) | P3 |
| `heart_of_the_everwood` | Heart of the Everwood | infantry | 3 | colossal (2.5 tiles, radius 14 px, towers over units) | idle, walk, attack (melee), death | P3 |

Meshy prompts:

- **Tender** — Verdance style: living wood, bark and moss, antler and leaf shapes, bioluminescent green accents, organic asymmetry, palette forest green #48d67f / bark brown / moss, Tender: Worker. Gathers Silver Sap and plants structures, carries a tool and a small resource container, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Thornguard** — Verdance style: living wood, bark and moss, antler and leaf shapes, bioluminescent green accents, organic asymmetry, palette forest green #48d67f / bark brown / moss, Thornguard: Bark-armoured infantry with thorn spears, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Briar Archer** — Verdance style: living wood, bark and moss, antler and leaf shapes, bioluminescent green accents, organic asymmetry, palette forest green #48d67f / bark brown / moss, Briar Archer: Ranged. Thorn-tipped arrows strike ground and air, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Forest Nymph** — Verdance style: living wood, bark and moss, antler and leaf shapes, bioluminescent green accents, organic asymmetry, palette forest green #48d67f / bark brown / moss, Forest Nymph: Healer spirit. Mends allies with living sap (auto), robed figure with a glowing focus object, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Verdant Sentinel** — Verdance style: living wood, bark and moss, antler and leaf shapes, bioluminescent green accents, organic asymmetry, palette forest green #48d67f / bark brown / moss, Verdant Sentinel: Soulborn guardian of living wood. Tanky, regenerates on the grove, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Spirit of the Everwood** — Verdance style: living wood, bark and moss, antler and leaf shapes, bioluminescent green accents, organic asymmetry, palette forest green #48d67f / bark brown / moss, Spirit of the Everwood: Flying nature spirit. Fast, ethereal, strikes ground and air, winged or hovering flier, seen from above, wings readable in silhouette, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Dire Stag** — Verdance style: living wood, bark and moss, antler and leaf shapes, bioluminescent green accents, organic asymmetry, palette forest green #48d67f / bark brown / moss, Dire Stag: Light cavalry of the wild. Fast antlered charge, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Rootcrusher** — Verdance style: living wood, bark and moss, antler and leaf shapes, bioluminescent green accents, organic asymmetry, palette forest green #48d67f / bark brown / moss, Rootcrusher: Siege beast hurling seed-bombs. Splash, double vs structures, wheeled or legged war machine with an obvious launcher, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Ancient Treant** — Verdance style: living wood, bark and moss, antler and leaf shapes, bioluminescent green accents, organic asymmetry, palette forest green #48d67f / bark brown / moss, Ancient Treant: Walking elder tree. Splash melee, spreads the grove as it walks, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Great Owl** — Verdance style: living wood, bark and moss, antler and leaf shapes, bioluminescent green accents, organic asymmetry, palette forest green #48d67f / bark brown / moss, Great Owl: Silent flying hunter with enormous sight. Strikes ground and air, winged or hovering flier, seen from above, wings readable in silhouette, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig
- **Heart of the Everwood** — Verdance style: living wood, bark and moss, antler and leaf shapes, bioluminescent green accents, organic asymmetry, palette forest green #48d67f / bark brown / moss, Heart of the Everwood: One may exist. The forest itself risen to war; heals allies and roots enemies around it, top-down readable, game-ready low poly (3-6k tris), 1024 PBR texture, rigged humanoid or creature rig

### Buildings (13)

| Id | Name | Footprint | Tier | Extra states | Priority |
|---|---|---|---|---|---|
| `everwood_spire` | Everwood Spire | 3x3 | 1 | construction, destroyed, 3 tier variants | P1 |
| `bloomforge` | Bloomforge | 2x2 | 1 | construction, destroyed, active glow / emitter, growth stages instead of scaffold | P1 |
| `groveheart_nexus` | Groveheart Nexus | 2x2 | 1 | construction, destroyed, active glow / emitter, growth stages instead of scaffold | P1 |
| `verdant_sigil_hall` | Verdant Sigil Hall | 2x2 | 1 | construction, destroyed, active glow / emitter, growth stages instead of scaffold | P1 |
| `rootwarden_bastion` | Rootwarden Bastion | 1x1 | 1 | construction, destroyed, active glow / emitter, growth stages instead of scaffold | P1 |
| `thornwall_gatehouse` | Thornwall Gatehouse | 1x1 | 1 | construction, destroyed, active glow / emitter, growth stages instead of scaffold | P1 |
| `cycle_sanctuary` | Cycle Sanctuary | 2x2 | 2 | construction, destroyed, active glow / emitter, growth stages instead of scaffold | P2 |
| `sylvan_waystone` | Sylvan Waystone | 1x1 | 2 | construction, destroyed, active glow / emitter, growth stages instead of scaffold | P2 |
| `wild_den` | Wild Den | 2x2 | 2 | construction, destroyed, active glow / emitter, growth stages instead of scaffold | P2 |
| `spirit_tree` | Spirit Tree | 3x3 | 2 | construction, destroyed, active glow / emitter, growth stages instead of scaffold | P2 |
| `sapwood_granary` | Sapwood Granary | 2x2 | 1 | construction, destroyed, active glow / emitter, growth stages instead of scaffold | P1 |
| `everglen_outpost` | Everglen Outpost | 2x2 | 2 | construction, destroyed, active glow / emitter, growth stages instead of scaffold | P2 |
| `world_seed_altar` | World Seed Altar | 2x2 | 3 | construction, destroyed, active glow / emitter, growth stages instead of scaffold | P3 |

Meshy prompts:

- **Everwood Spire** — Verdance style: living wood, bark and moss, antler and leaf shapes, bioluminescent green accents, organic asymmetry, palette forest green #48d67f / bark brown / moss, Everwood Spire: Your main base: a titanic living tree. Trains Tenders and heroes, receives sap, spreads the grove, footprint 3x3 tiles, seen from above at a slight angle, strong roof silhouette, main base, three visual tiers (Tier 1 modest, Tier 2 expanded, Tier 3 monumental with a crowning light or spire), built over a resource node, with intake channels, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Bloomforge** — Verdance style: living wood, bark and moss, antler and leaf shapes, bioluminescent green accents, organic asymmetry, palette forest green #48d67f / bark brown / moss, Bloomforge: Flowering armoury. Trains Thornguards and Briar Archers; at Tier 2 Dire Stags. Forges Sharpened Thorns. +8 supply, footprint 2x2 tiles, seen from above at a slight angle, strong roof silhouette, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Groveheart Nexus** — Verdance style: living wood, bark and moss, antler and leaf shapes, bioluminescent green accents, organic asymmetry, palette forest green #48d67f / bark brown / moss, Groveheart Nexus: Built on a sap node. Refines Silver Sap (0.5/s), drop-off for Tenders. Spreads the grove. +4 supply, footprint 2x2 tiles, seen from above at a slight angle, strong roof silhouette, built over a resource node, with intake channels, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Verdant Sigil Hall** — Verdance style: living wood, bark and moss, antler and leaf shapes, bioluminescent green accents, organic asymmetry, palette forest green #48d67f / bark brown / moss, Verdant Sigil Hall: Soulborn training centre. Trains Forest Nymphs; at Tier 2 Verdant Sentinels. Generates Everwood Essence (0.4/s). Required for Tier 2, footprint 2x2 tiles, seen from above at a slight angle, strong roof silhouette, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Rootwarden Bastion** — Verdance style: living wood, bark and moss, antler and leaf shapes, bioluminescent green accents, organic asymmetry, palette forest green #48d67f / bark brown / moss, Rootwarden Bastion: Defensive tower of living roots. Thorn volleys against ground and air; +25% on the grove, footprint 1x1 tiles, seen from above at a slight angle, strong roof silhouette, defensive tower with a clear emitter at the top, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Thornwall Gatehouse** — Verdance style: living wood, bark and moss, antler and leaf shapes, bioluminescent green accents, organic asymmetry, palette forest green #48d67f / bark brown / moss, Thornwall Gatehouse: Living wall of thornroots. Entangles and lacerates enemies that press against it, footprint 1x1 tiles, seen from above at a slight angle, strong roof silhouette, modular wall segment that tiles in a line, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Cycle Sanctuary** — Verdance style: living wood, bark and moss, antler and leaf shapes, bioluminescent green accents, organic asymmetry, palette forest green #48d67f / bark brown / moss, Cycle Sanctuary: Sacred sap spring. Heals nearby units (4/s) and regenerates Everwood Essence (0.5/s). Required for Tier 3, footprint 2x2 tiles, seen from above at a slight angle, strong roof silhouette, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Sylvan Waystone** — Verdance style: living wood, bark and moss, antler and leaf shapes, bioluminescent green accents, organic asymmetry, palette forest green #48d67f / bark brown / moss, Sylvan Waystone: Teleportation monolith. Waystep: send allies within 3 tiles to another of your Waystones. Grants vision, footprint 1x1 tiles, seen from above at a slight angle, strong roof silhouette, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Wild Den** — Verdance style: living wood, bark and moss, antler and leaf shapes, bioluminescent green accents, organic asymmetry, palette forest green #48d67f / bark brown / moss, Wild Den: (invented) Beast lair. Trains Rootcrushers; at Tier 3 Great Owls. +6 supply, footprint 2x2 tiles, seen from above at a slight angle, strong roof silhouette, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Spirit Tree** — Verdance style: living wood, bark and moss, antler and leaf shapes, bioluminescent green accents, organic asymmetry, palette forest green #48d67f / bark brown / moss, Spirit Tree: (invented) Trains Spirits of the Everwood; at Tier 3 Ancient Treants. +6 supply, footprint 3x3 tiles, seen from above at a slight angle, strong roof silhouette, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Sapwood Granary** — Verdance style: living wood, bark and moss, antler and leaf shapes, bioluminescent green accents, organic asymmetry, palette forest green #48d67f / bark brown / moss, Sapwood Granary: Resource storage. +12 supply and a small sap trickle (0.3/s), footprint 2x2 tiles, seen from above at a slight angle, strong roof silhouette, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **Everglen Outpost** — Verdance style: living wood, bark and moss, antler and leaf shapes, bioluminescent green accents, organic asymmetry, palette forest green #48d67f / bark brown / moss, Everglen Outpost: Forward base. Drop-off for sap, wide vision, spreads the grove far from home, footprint 2x2 tiles, seen from above at a slight angle, strong roof silhouette, built over a resource node, with intake channels, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants
- **World Seed Altar** — Verdance style: living wood, bark and moss, antler and leaf shapes, bioluminescent green accents, organic asymmetry, palette forest green #48d67f / bark brown / moss, World Seed Altar: (invented) Cradles a World Seed every 150s (holds 1). Wakes the Heart of the Everwood, footprint 2x2 tiles, seen from above at a slight angle, strong roof silhouette, game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants

## Shared world assets

| Asset | Count | Notes | Priority |
|---|---|---|---|
| Ground tile set | 1 set (8-12 tiles) | Neutral grassland base with variation tiles; the map is 80x60 tiles. Currently procedural noise. | P1 |
| Rock / cliff tiles | 1 set (6-9 tiles incl. edges) | Impassable terrain. Needs edge and corner pieces so blocks read as cliffs. | P1 |
| Decor props | 8-12 | Bushes, boulders, dead trees, ruins; two families (green decor, stone decor) as in the map generator. | P2 |
| Primary resource node | 5 (one per faction resource) | Soul font, Stormsteel deposit, Sunstone crystal, Sacred Crystal cluster, Verdance heartwood. The node is neutral on the map, so one neutral crystal cluster plus 5 faction extraction-building skins also works. | P1 |
| Secondary resource node | 1 (+ depleted state) | Currently a green pulsing ring. A glowing ley-well or shrine. | P1 |
| Depleted node state | 6 | Cracked, dark version of each node. | P2 |
| Terrain layer textures | 3 tiling textures + 3 edge masks | Blight (purple rot), Sunlight (gold glow), Grove (moss and roots). Drawn by a shader over the ground, so seamless tiling textures with soft alpha edges. | P1 |
| Corpse sprites | 1 per unit family (about 12) | Unit death leaves a corpse that necromancers raise. Generic per family (skeleton, humanoid, beast, machine, flier) is enough. | P2 |
| Wall segments | 5 (one per faction) | Straight segment plus corner and end caps. | P2 |

## Projectiles and effects

| Asset | Used by | Notes | Priority |
|---|---|---|---|
| Bolt projectile | towers, ranged units | One neutral mesh/sprite tinted per faction, with a trail. | P1 |
| Shell projectile | siege units, artillery towers | Arcing lob with shadow on the ground. Skull (Abyss), sun-orb (Radiance), boulder (Verdance), brass shell (Tempest), holy sphere (Sanctuary). | P2 |
| Arrow / light-arrow / bone-arrow | archers | Three variants cover all factions. | P1 |
| Lightning beam | Tempest towers, chain lightning, heal beams | Segmented animated bolt, two colours (storm blue, holy white). | P1 |
| Burst | deaths, rebirth, impacts | Radial burst, 5 tints. | P1 |
| Ring | ward placement, raise dead, level up | Expanding ring, 5 tints. | P1 |
| Slash | melee hits | Arc slash decal. | P1 |
| Spark | building damage, sacrifice | Small particle burst. | P2 |
| Floating text | level up, resource gain | Font treatment only. | P3 |
| Storm weather overlay | Tempest Eye of Auranth, Eye of the Storm | Rain streaks, dark tint, lightning flashes. | P2 |
| Cloud (Cloudburst) | Alyssia | Drifting storm cloud with rain column. | P2 |

### Ward and area-effect visuals

| Ward | Faction | Look |
|---|---|---|
| Corruption Ward totem | Abyss | Bone totem, purple mist radius. |
| Nightmare Veil | Abyss | Dark dome of shadow, 10 s. |
| Curse of Undeath area | Abyss | Wide violet sigil on the ground. |
| Zephyr Ward | Tempest | Swirling wind barrier ring. |
| Hurricane Maelstrom | Tempest | Rotating storm column, 6-tile radius. |
| Sanctified Ground / Consecrate | Radiance, Sanctuary | Golden or white glowing circle with runes. |
| Judgment of the Sun | Radiance | Pillar of sunfire. |
| Blinding Flare / Dawnstrike / Supernova | Radiance | Flash, burst, and a full-screen sun burst. |
| Seed the Land / Thorn Burst / Entangle | Verdance | Grove spreading, vines erupting, roots holding units. |
| Bloom of Life | Verdance | Rising petals and green light. |
| Shield Wall / Divine Intervention | Sanctuary | Ward bubbles on units, gold invulnerability aura. |
| Wrath of Heaven | Sanctuary | Repeating beams from above. |
| Banish Corruption | Sanctuary | White wave that scours blight. |
| Nether Portal / Light Step / Spirit Walk / Celestial Step | all | Teleport in and out effect, one per faction tint. |

## UI and 2D art

| Asset | Count | Notes | Priority |
|---|---|---|---|
| Unit and hero icons | 70 | 48 px command-card icons, one per unit and hero. | P1 |
| Building icons | 66 | 48 px build-menu icons. | P1 |
| Ability icons | 67 | 48 px, one per ability in `abilities.json`. | P1 |
| Research icons | 31 | One per research item across factions. | P2 |
| Resource icons | 15 | Primary, secondary, catalyst for each faction (top bar). | P1 |
| Faction emblems | 5 | Menu cards, minimap markers, loading screen. | P1 |
| Hero portraits | 15 | Selection panel portraits, painted or rendered bust. | P2 |
| Faction select card art | 5 | Key art per faction for the menu. | P2 |
| Cursors | 6 | Default, move, attack, gather, build, target. | P2 |
| HUD frame | 1 set | Top bar, bottom panel, minimap frame, command card buttons, in a dark theme matching the current palette. | P2 |
| Menu background | 1 | Title screen. | P3 |
| Victory / defeat screens | 2 | End panel art. | P3 |

## Totals

| Category | Count |
|---|---|
| Heroes | 15 |
| Units | 55 |
| Buildings (each with construction and destroyed states) | 66 |
| Main-base tier variants | 15 |
| Shared world assets | about 40 |
| Projectiles and effects | about 25 |
| Ward visuals | 15 |
| Icons | 223 |

Suggested order of work: 1) Abyss and Tempest P1 units, heroes, and buildings (these two factions are canon-complete), 2) shared ground, rock, node, and layer textures, 3) P1 effects and icons, 4) the three provisional factions once their Volume 1 sheets are confirmed, 5) Tier 2 and Tier 3 content.
