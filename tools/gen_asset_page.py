"""Build the shareable HTML version of the asset list (docs/asset-list.html).
Run after gen_asset_list.py:  python tools/gen_asset_page.py
"""
import html
import importlib.util
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
spec = importlib.util.spec_from_file_location("gal", os.path.join(ROOT, "tools/gen_asset_list.py"))
gal = importlib.util.module_from_spec(spec); spec.loader.exec_module(gal)
F, A = gal.F, gal.A
ORDER = ["abyss", "tempest", "radiance", "sanctuary", "verdance"]
COLOR = {f: F[f]["color"] for f in ORDER}
E = html.escape

parts = []
w = parts.append
w("""<title>Nexus Asset Manifest</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Cinzel:wght@500;700&family=Source+Sans+3:ital,wght@0,400;0,600;1,400&family=IBM+Plex+Mono:wght@400;500&display=swap">
<style>
:root{--bg:#f1f2f6;--panel:#ffffff;--ink:#171a26;--muted:#5a6078;--line:#d5d9e6;--accent:#8a6410;--accent-soft:#fff3cf;--code:#eceef5;--gold:#ffd479}
@media (prefers-color-scheme: dark){:root:not([data-theme="light"]){--bg:#0b0e1a;--panel:#0f1220;--ink:#dfe2ec;--muted:#8f97b3;--line:#2c3145;--accent:#ffd479;--accent-soft:#2a2410;--code:#161a2b}}
:root[data-theme="dark"]{--bg:#0b0e1a;--panel:#0f1220;--ink:#dfe2ec;--muted:#8f97b3;--line:#2c3145;--accent:#ffd479;--accent-soft:#2a2410;--code:#161a2b}
*{box-sizing:border-box}
body{background:var(--bg);color:var(--ink);font-family:"Source Sans 3","Segoe UI",system-ui,sans-serif;font-size:15px;line-height:1.5;margin:0}
a{color:var(--accent)}
.wrap{display:grid;grid-template-columns:230px minmax(0,1fr);gap:32px;max-width:1380px;margin:0 auto;padding:32px 24px 80px}
@media (max-width:900px){.wrap{grid-template-columns:minmax(0,1fr)}nav.side{position:static}}
nav.side{position:sticky;top:24px;align-self:start;display:flex;flex-direction:column;gap:6px}
nav.side a{display:flex;justify-content:space-between;align-items:center;text-decoration:none;color:var(--ink);padding:6px 10px;border-left:3px solid var(--fc,var(--line));border-radius:0 6px 6px 0;font-weight:600}
nav.side a:hover,nav.side a:focus-visible{background:var(--panel);outline:none}
nav.side a small{font-family:"IBM Plex Mono",monospace;font-weight:400;color:var(--muted);font-size:12px}
nav.side .grp{margin-top:14px;font-size:11px;letter-spacing:.12em;text-transform:uppercase;color:var(--muted)}
header.top{grid-column:1/-1;border-bottom:1px solid var(--line);padding-bottom:20px;display:grid;grid-template-columns:minmax(0,1fr) auto;gap:24px;align-items:end}
header.top h1{font-family:Cinzel,Georgia,serif;font-weight:700;font-size:34px;letter-spacing:.04em;margin:0 0 6px;text-wrap:balance}
header.top p{margin:0;max-width:64ch;color:var(--muted)}
.totals{display:grid;grid-template-columns:repeat(4,auto);gap:10px 22px;font-variant-numeric:tabular-nums}
.totals div{display:flex;flex-direction:column}
.totals b{font-family:"IBM Plex Mono",monospace;font-size:22px;font-weight:500;line-height:1.1}
.totals span{font-size:11px;letter-spacing:.1em;text-transform:uppercase;color:var(--muted)}
main{min-width:0;display:flex;flex-direction:column;gap:44px}
section.fac{scroll-margin-top:16px}
.band{display:flex;align-items:baseline;gap:16px;border-bottom:2px solid var(--fc);padding-bottom:8px;margin-bottom:6px;flex-wrap:wrap}
.band h2{font-family:Cinzel,Georgia,serif;font-weight:500;font-size:26px;letter-spacing:.06em;margin:0;color:var(--fc)}
.band .prov{font-size:11px;letter-spacing:.12em;text-transform:uppercase;color:var(--accent);background:var(--accent-soft);padding:2px 8px;border-radius:3px}
.style{color:var(--muted);max-width:80ch;margin:0 0 4px;font-style:italic}
.meta{color:var(--muted);margin:0 0 14px;font-size:14px}
h3{font-size:12px;letter-spacing:.14em;text-transform:uppercase;color:var(--muted);margin:22px 0 8px;font-weight:600}
h3 span{font-family:"IBM Plex Mono",monospace;letter-spacing:0;color:var(--ink);margin-left:6px}
.tbl{overflow-x:auto;border:1px solid var(--line);border-radius:6px;background:var(--panel)}
table{border-collapse:collapse;width:100%;font-size:14px}
th{text-align:left;font-size:11px;letter-spacing:.1em;text-transform:uppercase;color:var(--muted);padding:9px 12px;border-bottom:1px solid var(--line);white-space:nowrap}
td{padding:8px 12px;border-bottom:1px solid var(--line);vertical-align:top}
tr:last-child td{border-bottom:0}
td.id{font-family:"IBM Plex Mono",monospace;font-size:12.5px;color:var(--muted);white-space:nowrap}
td.n{font-weight:600;white-space:nowrap}
td.num{font-variant-numeric:tabular-nums;text-align:center}
.pri{display:inline-block;font-family:"IBM Plex Mono",monospace;font-size:11.5px;padding:1px 7px;border-radius:3px;border:1px solid var(--line)}
.pri.P1{color:var(--accent);border-color:var(--accent);background:var(--accent-soft)}
details{border-top:1px dashed var(--line)}
details summary{cursor:pointer;color:var(--accent);font-size:13px;padding:6px 12px;list-style:none}
details summary::before{content:"▸ ";font-size:11px}
details[open] summary::before{content:"▾ "}
.prompt{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:12px;padding:0 12px 12px;align-items:start}
.prompt pre{margin:0;white-space:pre-wrap;font-family:"IBM Plex Mono",monospace;font-size:12.5px;line-height:1.5;background:var(--code);padding:10px 12px;border-radius:4px}
.prompt .vfx{grid-column:1/-1;font-size:13px;color:var(--muted)}
button.copy{font:inherit;font-size:12px;padding:6px 10px;border:1px solid var(--line);background:var(--panel);color:var(--ink);border-radius:4px;cursor:pointer}
button.copy:hover,button.copy:focus-visible{border-color:var(--accent);outline:none}
.note{background:var(--panel);border:1px solid var(--line);border-left:3px solid var(--gold);padding:14px 18px;border-radius:0 6px 6px 0;max-width:80ch}
.note ul{margin:8px 0 0;padding-left:20px}
.note li{margin:4px 0}
.order{max-width:80ch}
.order ol{padding-left:22px}
</style>
<div class="wrap">
<header class="top">
<div><h1>Nexus Asset Manifest</h1><p>Every visual asset Realm of Nexus references, generated from the game data. Each row opens into a prompt you can paste into Meshy or a similar generator. Ids are the exact keys the engine uses.</p></div>
""")
tot_units = sum(len(F[f]["units"]) for f in ORDER)
tot_heroes = sum(len(F[f]["heroes"]) for f in ORDER)
tot_blds = sum(len(F[f]["buildings"]) for f in ORDER)
tot_icons = tot_units + tot_heroes + tot_blds + len(A) + 20
w('<div class="totals"><div><b>%d</b><span>heroes</span></div><div><b>%d</b><span>units</span></div><div><b>%d</b><span>buildings</span></div><div><b>%d</b><span>icons</span></div></div></header>' % (tot_heroes, tot_units, tot_blds, tot_icons))
w('<nav class="side"><div class="grp">Factions</div>')
for f in ORDER:
    w('<a href="#%s" style="--fc:%s">%s<small>%d</small></a>' % (f, COLOR[f], E(F[f]["name"]), len(F[f]["units"]) + len(F[f]["heroes"]) + len(F[f]["buildings"])))
w('<div class="grp">Shared</div><a href="#world">World</a><a href="#fx">Effects</a><a href="#ui">Icons and UI</a><a href="#order">Order of work</a></nav>')
w('<main>')
w('<div class="note"><b>Pipeline.</b> Tile is 32 px; units are 20 to 28 px on screen, so silhouette carries everything. Generate the mesh from the prompt, retopologize to the tri budget, rig and animate, then render 8-direction sprite sheets (64 px units, 96 to 192 px buildings) for the current 2D renderer, or keep the meshes for a later 3D camera.<ul><li>Leave 15 to 25 percent of each model in neutral grey as the team-colour mask; the engine tints it.</li><li>Buildings need construction, complete, and destroyed states. Main bases need three tier variants (Radiance tiers are specified in docs/buildings/radiance-buildings.md).</li><li>P1 is the playable vertical slice: Tier 1 content and heroes. P2 is Tier 2. P3 is Tier 3 and ultimates.</li></ul></div>')

def pri(p):
    return '<span class="pri %s">%s</span>' % (p, p)

def prompt_block(text, vfx=None):
    s = '<details><summary>Meshy prompt</summary><div class="prompt"><pre>%s</pre><button class="copy" type="button">Copy</button>' % E(text)
    if vfx:
        s += '<div class="vfx">Ability VFX to pair with the casts: %s</div>' % E(vfx)
    return s + '</div></details>'

for f in ORDER:
    fac = F[f]; c = COLOR[f]
    w('<section class="fac" id="%s" style="--fc:%s"><div class="band"><h2>%s</h2>%s</div>' % (f, c, E(fac["name"]), '<span class="prov">provisional roster</span>' if fac.get("provisional") else ""))
    w('<p class="style">%s</p>' % E(gal.STYLE[f]))
    w('<p class="meta">Base tiers: %s. Resources: %s, %s, %s.</p>' % (E(" → ".join(t["name"] for t in fac["tiers"])), E(fac["resources"]["primary"]["name"]), E(fac["resources"]["secondary"]["name"]), E(fac["resources"]["catalyst"]["name"])))
    # heroes
    w('<h3>Heroes<span>%d</span></h3><div class="tbl"><table><thead><tr><th>Id</th><th>Name</th><th>Role</th><th>Animations</th><th>Priority</th></tr></thead><tbody>' % len(fac["heroes"]))
    for hid, h in fac["heroes"].items():
        vfx = ", ".join("%s (%s)" % (A[a]["name"], A[a].get("target", "none")) for a in h.get("abilities", []) if a in A)
        w('<tr><td class="id">%s</td><td class="n">%s</td><td>%s</td><td>%s</td><td>%s</td></tr>' % (hid, E(h["name"]), E((h.get("desc") or "").split(".")[0]), gal.UNIT_ANIMS["hero"], pri("P1")))
        w('<tr><td colspan="5" style="padding:0">%s</td></tr>' % prompt_block(gal.prompt_unit(f, h, True), vfx))
    w('</tbody></table></div>')
    # units
    w('<h3>Units<span>%d</span></h3><div class="tbl"><table><thead><tr><th>Id</th><th>Name</th><th>Type</th><th>Tier</th><th>Size</th><th>Animations</th><th>Priority</th></tr></thead><tbody>' % len(fac["units"]))
    for uid, u in fac["units"].items():
        t = u.get("type", "")
        w('<tr><td class="id">%s</td><td class="n">%s</td><td>%s%s</td><td class="num">%s</td><td>%s</td><td>%s</td><td>%s</td></tr>' % (uid, E(u["name"]), t, " (flying)" if u.get("flying") and t != "flying" else "", u.get("tier", 1), gal.size_for(u), gal.UNIT_ANIMS.get(t, gal.UNIT_ANIMS["infantry"]), pri(gal.priority_for(u.get("tier", 1), t))))
        w('<tr><td colspan="7" style="padding:0">%s</td></tr>' % prompt_block(gal.prompt_unit(f, u)))
    w('</tbody></table></div>')
    # buildings
    w('<h3>Buildings<span>%d</span></h3><div class="tbl"><table><thead><tr><th>Id</th><th>Name</th><th>Footprint</th><th>Tier</th><th>Extra states</th><th>Priority</th></tr></thead><tbody>' % len(fac["buildings"]))
    for bid, b in fac["buildings"].items():
        extra = ["construction", "destroyed"]
        if b.get("isBase"): extra.append("3 tier variants")
        if b.get("tower") or b.get("aura") or b.get("light") or b.get("corrupt") or b.get("grow"): extra.append("active glow")
        if b.get("relocatable"): extra.append("lift-off variant")
        if b.get("grows"): extra.append("growth stages")
        w('<tr><td class="id">%s</td><td class="n">%s</td><td class="num">%sx%s</td><td class="num">%s</td><td>%s</td><td>%s</td></tr>' % (bid, E(b["name"]), b.get("w", 2), b.get("h", 2), b.get("tier", 1), ", ".join(extra), pri(gal.priority_for(b.get("tier", 1), "building"))))
        w('<tr><td colspan="6" style="padding:0">%s</td></tr>' % prompt_block(gal.prompt_building(f, b)))
    w('</tbody></table></div></section>')

def simple_table(id_, title, headers, rows):
    w('<section class="fac" id="%s" style="--fc:var(--gold)"><div class="band"><h2>%s</h2></div><div class="tbl"><table><thead><tr>%s</tr></thead><tbody>' % (id_, title, "".join("<th>%s</th>" % h for h in headers)))
    for r in rows:
        cells = []
        for i, cell in enumerate(r):
            if cell in ("P1", "P2", "P3"):
                cells.append("<td>%s</td>" % pri(cell))
            elif i == 0:
                cells.append('<td class="n">%s</td>' % E(cell))
            else:
                cells.append("<td>%s</td>" % E(str(cell)))
        w("<tr>%s</tr>" % "".join(cells))
    w('</tbody></table></div></section>')

simple_table("world", "Shared world assets", ["Asset", "Count", "Notes", "Priority"], [
    ("Ground tile set", "8-12 tiles", "Neutral grassland base with variation tiles; the map is 80x60 tiles. Currently procedural noise.", "P1"),
    ("Rock / cliff tiles", "6-9 incl. edges", "Impassable terrain. Edge and corner pieces so blocks read as cliffs.", "P1"),
    ("Decor props", "8-12", "Bushes, boulders, dead trees, ruins; a green family and a stone family as in the map generator.", "P2"),
    ("Primary resource node", "5", "Soul font, Stormsteel deposit, Sunstone crystal, Sacred Crystal cluster, Verdance heartwood. One neutral crystal cluster plus five extraction-building skins also works.", "P1"),
    ("Secondary resource node", "1 + depleted", "Currently a pulsing green ring. A glowing ley-well or shrine.", "P1"),
    ("Depleted node states", "6", "Cracked, dark version of each node.", "P2"),
    ("Terrain layer textures", "3 + edge masks", "Blight (purple rot), Sunlight (gold glow), Grove (moss and roots). Drawn by a shader, so seamless tiling with soft alpha edges.", "P1"),
    ("Corpse sprites", "about 12", "Deaths leave corpses that necromancers raise. One per family: skeleton, humanoid, beast, machine, flier.", "P2"),
    ("Wall segments", "5", "Straight segment plus corner and end caps, one per faction.", "P2"),
])
simple_table("fx", "Projectiles and effects", ["Asset", "Used by", "Notes", "Priority"], [
    ("Bolt projectile", "towers, ranged units", "One neutral mesh tinted per faction, with a trail.", "P1"),
    ("Shell projectile", "siege, artillery towers", "Arcing lob with ground shadow: skull (Abyss), sun-orb (Radiance), boulder (Verdance), brass shell (Tempest), holy sphere (Sanctuary).", "P2"),
    ("Arrow variants", "archers", "Plain, light, and bone arrows cover all factions.", "P1"),
    ("Lightning beam", "Tempest towers, chain lightning, heal beams", "Segmented animated bolt in storm blue and holy white.", "P1"),
    ("Burst", "deaths, rebirth, impacts", "Radial burst, five tints.", "P1"),
    ("Ring", "ward placement, raise dead, level up", "Expanding ring, five tints.", "P1"),
    ("Slash", "melee hits", "Arc slash decal.", "P1"),
    ("Spark", "building damage, sacrifice", "Small particle burst.", "P2"),
    ("Storm weather overlay", "Eye of Auranth, Eye of the Storm", "Rain streaks, dark tint, lightning flashes.", "P2"),
    ("Cloud", "Cloudburst", "Drifting storm cloud with a rain column.", "P2"),
    ("Corruption Ward totem", "Neratha", "Bone totem with a purple mist radius.", "P2"),
    ("Nightmare Veil", "Malazar", "Dark dome of shadow.", "P2"),
    ("Curse of Undeath sigil", "Malazar", "Wide violet sigil on the ground.", "P3"),
    ("Zephyr Ward", "Lyrian", "Swirling wind barrier ring.", "P2"),
    ("Hurricane Maelstrom", "Alyssia", "Rotating storm column, 6-tile radius.", "P3"),
    ("Sanctified / Consecrated ground", "Seraphine, Adaline", "Gold or white glowing circle with runes.", "P2"),
    ("Judgment of the Sun", "Aurelian", "Pillar of sunfire.", "P3"),
    ("Blinding Flare, Dawnstrike, Supernova", "Aurelian, Solaris", "Flash, burst, and a full-screen sun burst.", "P2"),
    ("Seed the Land, Thorn Burst, Entangle", "Elowen, Kael, Sylvara", "Grove spreading, vines erupting, roots holding units.", "P2"),
    ("Bloom of Life", "Elowen", "Rising petals and green light.", "P3"),
    ("Shield Wall, Divine Intervention", "Isolde", "Ward bubbles on units, gold invulnerability aura.", "P2"),
    ("Wrath of Heaven", "Cassiel", "Repeating beams from above.", "P3"),
    ("Banish Corruption", "Cassiel", "White wave that scours blight.", "P2"),
    ("Teleport in/out", "Nether Portal, Light Step, Spirit Walk, Celestial Step", "One effect, five faction tints.", "P2"),
])
research_count = sum(len(F[f].get("research", {})) for f in ORDER)
simple_table("ui", "Icons and UI", ["Asset", "Count", "Notes", "Priority"], [
    ("Unit and hero icons", str(tot_units + tot_heroes), "48 px command-card icons, one per unit and hero.", "P1"),
    ("Building icons", str(tot_blds), "48 px build-menu icons.", "P1"),
    ("Ability icons", str(len(A)), "48 px, one per ability.", "P1"),
    ("Research icons", str(research_count), "One per research item.", "P2"),
    ("Resource icons", "15", "Primary, secondary, and catalyst for each faction (top bar).", "P1"),
    ("Faction emblems", "5", "Menu cards, minimap markers, loading screen.", "P1"),
    ("Hero portraits", "15", "Selection panel busts, painted or rendered.", "P2"),
    ("Faction select card art", "5", "Key art per faction for the menu.", "P2"),
    ("Cursors", "6", "Default, move, attack, gather, build, target.", "P2"),
    ("HUD frame", "1 set", "Top bar, bottom panel, minimap frame, command-card buttons in the current dark theme.", "P2"),
    ("Menu background", "1", "Title screen.", "P3"),
    ("Victory and defeat screens", "2", "End panel art.", "P3"),
])
w('<section class="fac order" id="order" style="--fc:var(--gold)"><div class="band"><h2>Order of work</h2></div><ol><li>Abyss and Tempest P1 units, heroes, and buildings. These two factions are canon-complete.</li><li>Shared ground, rock, node, and layer textures.</li><li>P1 effects and icons.</li><li>The three provisional factions once their Volume 1 sheets are confirmed.</li><li>Tier 2 and Tier 3 content.</li></ol></section>')
w('</main></div>')
w("""<script>
document.querySelectorAll('button.copy').forEach(function(b){
  b.addEventListener('click', function(){
    var pre = b.parentElement.querySelector('pre');
    var done = function(){ b.textContent = 'Copied'; setTimeout(function(){ b.textContent = 'Copy'; }, 1500); };
    if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(pre.textContent).then(done, function(){ selectText(pre); });
    else selectText(pre);
  });
});
function selectText(el){ var r = document.createRange(); r.selectNodeContents(el); var s = window.getSelection(); s.removeAllRanges(); s.addRange(r); }
</script>""")
out = os.path.join(ROOT, "docs/asset-list.html")
open(out, "w", encoding="utf-8").write("\n".join(parts))
print("wrote", out, len("\n".join(parts)) // 1024, "KB")
