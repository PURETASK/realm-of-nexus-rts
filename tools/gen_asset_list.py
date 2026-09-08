"""Generate docs/asset-list.md: every visual asset the game needs, with Meshy-ready prompts.

Reads the shared data (godot/data/factions.json, abilities.json) so the list always matches the game.
Run:  python tools/gen_asset_list.py
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
F = json.load(open(os.path.join(ROOT, "godot/data/factions.json"), encoding="utf-8"))
A = json.load(open(os.path.join(ROOT, "godot/data/abilities.json"), encoding="utf-8"))

STYLE = {
    "radiance": "Radiance style: gilded bronze and white marble, sun-disc motifs, warm gold light, clean heroic shapes, palette gold #ffcc44 / bronze / ivory",
    "sanctuary": "Sanctuary style: white and silver plate, pale blue-violet glow, stained-glass and halo motifs, angelic and orderly, palette ivory #e8e4ff / silver / soft blue",
    "verdance": "Verdance style: living wood, bark and moss, antler and leaf shapes, bioluminescent green accents, organic asymmetry, palette forest green #48d67f / bark brown / moss",
    "abyss": "Abyss style: bone, obsidian and rusted iron, purple void-fire, rot and chains, jagged gothic silhouettes, palette violet #8b3cff / bone white / black",
    "tempest": "Tempest style: storm-grey steel and brass, sailcloth and rigging, lightning-blue crystal, sky-ship technology, palette sky blue #5fc8ff / brass / slate",
}
STYLE_NAME = {"radiance": "Radiance", "sanctuary": "Sanctuary", "verdance": "Verdance", "abyss": "Abyss", "tempest": "Tempest"}

UNIT_ANIMS = {
    "worker": "idle, walk, gather (swing/pick), carry-walk, build (hammer), death",
    "infantry": "idle, walk, attack (melee), death",
    "ranged": "idle, walk, attack (draw and release), death",
    "caster": "idle, walk, cast (channel), attack, death",
    "flying": "idle hover, fly, attack, death (fall)",
    "siege": "idle, move, fire (recoil), death (break apart)",
    "hero": "idle, walk, attack, 4 ability casts (Q W E R), victory pose, death",
}
SIZE_BY_SUPPLY = [(0, "small (1 tile, radius 10 px)"), (3, "medium (1.5 tiles, radius 12 px)"), (5, "large (2 tiles, radius 14 px)"), (8, "colossal (2.5 tiles, radius 14 px, towers over units)")]


def size_for(u):
    sup = float(u.get("supply", 1))
    label = SIZE_BY_SUPPLY[0][1]
    for th, lab in SIZE_BY_SUPPLY:
        if sup >= th:
            label = lab
    if u.get("type") == "hero":
        label = "hero (1.5 tiles, radius 14 px, distinctive silhouette)"
    return label


def priority_for(tier, kind):
    if kind == "hero":
        return "P1"
    return {1: "P1", 2: "P2", 3: "P3"}.get(int(tier or 1), "P2")


def prompt_unit(fid, u, is_hero=False):
    parts = [STYLE[fid]]
    parts.append("%s: %s" % (u["name"], (u.get("desc") or "").rstrip(".")))
    if u.get("flying"):
        parts.append("winged or hovering flier, seen from above, wings readable in silhouette")
    t = u.get("type", "")
    if t == "worker":
        parts.append("carries a tool and a small resource container")
    elif t == "siege":
        parts.append("wheeled or legged war machine with an obvious launcher")
    elif t == "caster":
        parts.append("robed figure with a glowing focus object")
    if is_hero:
        parts.append("unique champion, more detail and a stronger colour accent than regular troops, distinct head/weapon silhouette")
    parts.append("top-down readable, game-ready low poly (%s tris), 1024 PBR texture, rigged humanoid or creature rig" % ("8-12k" if is_hero else "3-6k"))
    return ", ".join(parts)


def prompt_building(fid, b):
    parts = [STYLE[fid]]
    parts.append("%s: %s" % (b["name"], (b.get("desc") or "").rstrip(".")))
    parts.append("footprint %sx%s tiles, seen from above at a slight angle, strong roof silhouette" % (b.get("w", 2), b.get("h", 2)))
    if b.get("isBase"):
        parts.append("main base, three visual tiers (Tier 1 modest, Tier 2 expanded, Tier 3 monumental with a crowning light or spire)")
    if b.get("tower"):
        parts.append("defensive tower with a clear emitter at the top")
    if b.get("wall"):
        parts.append("modular wall segment that tiles in a line")
    if b.get("detector"):
        parts.append("sensor structure with a large eye, lens, or beacon")
    if b.get("invisible"):
        parts.append("nearly flush with the ground, revealed only by a faint glow")
    if b.get("dropoff"):
        parts.append("built over a resource node, with intake channels")
    parts.append("game-ready low poly (6-15k tris), 2048 PBR texture, plus construction (scaffold) and destroyed variants")
    return ", ".join(parts)


lines = []
w = lines.append
w("# Realm of Nexus — Visual Asset List")
w("")
w("Generated from the shared game data by `tools/gen_asset_list.py` on 2026-09-07. Every entry is something the game already references, so nothing here is optional decoration: the placeholders currently drawn as coloured glyphs are exactly this list.")
w("")
w("## How to use this list with Meshy (or similar)")
w("")
w("- The game is a top-down 2D RTS with a 32 px tile. Recommended pipeline: generate a 3D model in Meshy from the prompt, retopologize to the tri budget, rig and animate (Meshy's auto-rig covers humanoids), then either render to 8-direction sprite sheets at 64 px (units) / 96-192 px (buildings) for the current 2D renderer, or keep the meshes for a later 3D-camera version of the Godot build. Rendering to sprites keeps the current art theme and the current renderer.")
w("- Silhouette first. Units are 20 to 28 px across on screen, so each unit type in a faction must read from its outline alone: workers hunched with tools, infantry with shields, ranged with bows, casters with staffs, fliers with wings, siege with launchers.")
w("- One material palette per faction (given in each faction's style line). Player colour is applied by the engine as a tint on a mask, so leave a 15 to 25 percent area of each unit and building in neutral grey for the team-colour mask.")
w("- Buildings need three states: under construction (scaffold or half-grown), complete, destroyed rubble. Main bases additionally need three tier variants. Radiance building tiers are specified in detail in `docs/buildings/radiance-buildings.md`; the other factions follow the same three-tier pattern.")
w("- Priority: P1 = needed for a playable vertical slice (Tier 1 content and heroes), P2 = Tier 2, P3 = Tier 3 and ultimates.")
w("")

total = {"heroes": 0, "units": 0, "buildings": 0}
for fid in ["abyss", "tempest", "radiance", "sanctuary", "verdance"]:
    f = F[fid]
    w("## %s%s" % (f["name"], " (provisional roster)" if f.get("provisional") else ""))
    w("")
    w("*%s*" % STYLE[fid])
    w("")
    w("Tier names for the main base: %s." % " → ".join(t["name"] for t in f["tiers"]))
    w("Resources to depict on nodes and in icons: %s (primary), %s (secondary), %s (catalyst)." % (f["resources"]["primary"]["name"], f["resources"]["secondary"]["name"], f["resources"]["catalyst"]["name"]))
    w("")
    w("### Heroes (%d)" % len(f["heroes"]))
    w("")
    w("| Id | Name | Role | Size | Animations | Priority |")
    w("|---|---|---|---|---|---|")
    for hid, h in f["heroes"].items():
        hh = dict(h); hh["type"] = "hero"
        w("| `%s` | %s | %s | %s | %s | P1 |" % (hid, h["name"], (h.get("desc") or "").split(".")[0], size_for(hh), UNIT_ANIMS["hero"]))
        total["heroes"] += 1
    w("")
    w("Meshy prompts:")
    w("")
    for hid, h in f["heroes"].items():
        w("- **%s** — %s" % (h["name"], prompt_unit(fid, h, True)))
        w("  - Ability VFX to pair with the casts: %s." % ", ".join("%s (%s)" % (A[a]["name"], A[a].get("target", "none")) for a in h.get("abilities", []) if a in A))
    w("")
    w("### Units (%d)" % len(f["units"]))
    w("")
    w("| Id | Name | Type | Tier | Size | Animations | Priority |")
    w("|---|---|---|---|---|---|---|")
    for uid, u in f["units"].items():
        w("| `%s` | %s | %s%s | %s | %s | %s | %s |" % (uid, u["name"], u.get("type", ""), " (flying)" if u.get("flying") and u.get("type") != "flying" else "", u.get("tier", 1), size_for(u), UNIT_ANIMS.get(u.get("type", ""), UNIT_ANIMS["infantry"]), priority_for(u.get("tier", 1), u.get("type"))))
        total["units"] += 1
    w("")
    w("Meshy prompts:")
    w("")
    for uid, u in f["units"].items():
        w("- **%s** — %s" % (u["name"], prompt_unit(fid, u)))
    w("")
    w("### Buildings (%d)" % len(f["buildings"]))
    w("")
    w("| Id | Name | Footprint | Tier | Extra states | Priority |")
    w("|---|---|---|---|---|---|")
    for bid, b in f["buildings"].items():
        extra = ["construction", "destroyed"]
        if b.get("isBase"):
            extra.append("3 tier variants")
        if b.get("tower") or b.get("aura") or b.get("light") or b.get("corrupt") or b.get("grow"):
            extra.append("active glow / emitter")
        if b.get("relocatable"):
            extra.append("lift-off (flying) variant")
        if b.get("grows"):
            extra.append("growth stages instead of scaffold")
        w("| `%s` | %s | %sx%s | %s | %s | %s |" % (bid, b["name"], b.get("w", 2), b.get("h", 2), b.get("tier", 1), ", ".join(extra), priority_for(b.get("tier", 1), "building")))
        total["buildings"] += 1
    w("")
    w("Meshy prompts:")
    w("")
    for bid, b in f["buildings"].items():
        w("- **%s** — %s" % (b["name"], prompt_building(fid, b)))
    w("")

w("## Shared world assets")
w("")
w("| Asset | Count | Notes | Priority |")
w("|---|---|---|---|")
w("| Ground tile set | 1 set (8-12 tiles) | Neutral grassland base with variation tiles; the map is 80x60 tiles. Currently procedural noise. | P1 |")
w("| Rock / cliff tiles | 1 set (6-9 tiles incl. edges) | Impassable terrain. Needs edge and corner pieces so blocks read as cliffs. | P1 |")
w("| Decor props | 8-12 | Bushes, boulders, dead trees, ruins; two families (green decor, stone decor) as in the map generator. | P2 |")
w("| Primary resource node | 5 (one per faction resource) | Soul font, Stormsteel deposit, Sunstone crystal, Sacred Crystal cluster, Verdance heartwood. The node is neutral on the map, so one neutral crystal cluster plus 5 faction extraction-building skins also works. | P1 |")
w("| Secondary resource node | 1 (+ depleted state) | Currently a green pulsing ring. A glowing ley-well or shrine. | P1 |")
w("| Depleted node state | 6 | Cracked, dark version of each node. | P2 |")
w("| Terrain layer textures | 3 tiling textures + 3 edge masks | Blight (purple rot), Sunlight (gold glow), Grove (moss and roots). Drawn by a shader over the ground, so seamless tiling textures with soft alpha edges. | P1 |")
w("| Corpse sprites | 1 per unit family (about 12) | Unit death leaves a corpse that necromancers raise. Generic per family (skeleton, humanoid, beast, machine, flier) is enough. | P2 |")
w("| Wall segments | 5 (one per faction) | Straight segment plus corner and end caps. | P2 |")
w("")
w("## Projectiles and effects")
w("")
w("| Asset | Used by | Notes | Priority |")
w("|---|---|---|---|")
w("| Bolt projectile | towers, ranged units | One neutral mesh/sprite tinted per faction, with a trail. | P1 |")
w("| Shell projectile | siege units, artillery towers | Arcing lob with shadow on the ground. Skull (Abyss), sun-orb (Radiance), boulder (Verdance), brass shell (Tempest), holy sphere (Sanctuary). | P2 |")
w("| Arrow / light-arrow / bone-arrow | archers | Three variants cover all factions. | P1 |")
w("| Lightning beam | Tempest towers, chain lightning, heal beams | Segmented animated bolt, two colours (storm blue, holy white). | P1 |")
w("| Burst | deaths, rebirth, impacts | Radial burst, 5 tints. | P1 |")
w("| Ring | ward placement, raise dead, level up | Expanding ring, 5 tints. | P1 |")
w("| Slash | melee hits | Arc slash decal. | P1 |")
w("| Spark | building damage, sacrifice | Small particle burst. | P2 |")
w("| Floating text | level up, resource gain | Font treatment only. | P3 |")
w("| Storm weather overlay | Tempest Eye of Auranth, Eye of the Storm | Rain streaks, dark tint, lightning flashes. | P2 |")
w("| Cloud (Cloudburst) | Alyssia | Drifting storm cloud with rain column. | P2 |")
w("")
w("### Ward and area-effect visuals")
w("")
w("| Ward | Faction | Look |")
w("|---|---|---|")
w("| Corruption Ward totem | Abyss | Bone totem, purple mist radius. |")
w("| Nightmare Veil | Abyss | Dark dome of shadow, 10 s. |")
w("| Curse of Undeath area | Abyss | Wide violet sigil on the ground. |")
w("| Zephyr Ward | Tempest | Swirling wind barrier ring. |")
w("| Hurricane Maelstrom | Tempest | Rotating storm column, 6-tile radius. |")
w("| Sanctified Ground / Consecrate | Radiance, Sanctuary | Golden or white glowing circle with runes. |")
w("| Judgment of the Sun | Radiance | Pillar of sunfire. |")
w("| Blinding Flare / Dawnstrike / Supernova | Radiance | Flash, burst, and a full-screen sun burst. |")
w("| Seed the Land / Thorn Burst / Entangle | Verdance | Grove spreading, vines erupting, roots holding units. |")
w("| Bloom of Life | Verdance | Rising petals and green light. |")
w("| Shield Wall / Divine Intervention | Sanctuary | Ward bubbles on units, gold invulnerability aura. |")
w("| Wrath of Heaven | Sanctuary | Repeating beams from above. |")
w("| Banish Corruption | Sanctuary | White wave that scours blight. |")
w("| Nether Portal / Light Step / Spirit Walk / Celestial Step | all | Teleport in and out effect, one per faction tint. |")
w("")
w("## UI and 2D art")
w("")
w("| Asset | Count | Notes | Priority |")
w("|---|---|---|---|")
w("| Unit and hero icons | %d | 48 px command-card icons, one per unit and hero. | P1 |" % (total["units"] + total["heroes"]))
w("| Building icons | %d | 48 px build-menu icons. | P1 |" % total["buildings"])
w("| Ability icons | %d | 48 px, one per ability in `abilities.json`. | P1 |" % len(A))
w("| Research icons | %d | One per research item across factions. | P2 |" % sum(len(F[f].get("research", {})) for f in F))
w("| Resource icons | 15 | Primary, secondary, catalyst for each faction (top bar). | P1 |")
w("| Faction emblems | 5 | Menu cards, minimap markers, loading screen. | P1 |")
w("| Hero portraits | 15 | Selection panel portraits, painted or rendered bust. | P2 |")
w("| Faction select card art | 5 | Key art per faction for the menu. | P2 |")
w("| Cursors | 6 | Default, move, attack, gather, build, target. | P2 |")
w("| HUD frame | 1 set | Top bar, bottom panel, minimap frame, command card buttons, in a dark theme matching the current palette. | P2 |")
w("| Menu background | 1 | Title screen. | P3 |")
w("| Victory / defeat screens | 2 | End panel art. | P3 |")
w("")
w("## Totals")
w("")
w("| Category | Count |")
w("|---|---|")
w("| Heroes | %d |" % total["heroes"])
w("| Units | %d |" % total["units"])
w("| Buildings (each with construction and destroyed states) | %d |" % total["buildings"])
w("| Main-base tier variants | 15 |")
w("| Shared world assets | about 40 |")
w("| Projectiles and effects | about 25 |")
w("| Ward visuals | 15 |")
w("| Icons | %d |" % (total["units"] + total["heroes"] + total["buildings"] + len(A) + 15 + 5))
w("")
w("Suggested order of work: 1) Abyss and Tempest P1 units, heroes, and buildings (these two factions are canon-complete), 2) shared ground, rock, node, and layer textures, 3) P1 effects and icons, 4) the three provisional factions once their Volume 1 sheets are confirmed, 5) Tier 2 and Tier 3 content.")

out = os.path.join(ROOT, "docs/asset-list.md")
open(out, "w", encoding="utf-8").write("\n".join(lines) + "\n")
print("wrote", out, "heroes", total["heroes"], "units", total["units"], "buildings", total["buildings"], "abilities", len(A))
