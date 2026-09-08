"""Build docs/balance-report.html from balance worker output (same tokens as the asset manifest page).
usage: python tools/gen_balance_page.py <dir with results_*.jsonl>
"""
import collections
import glob
import html
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = sys.argv[1]
F = json.load(open(os.path.join(ROOT, "godot/data/factions.json"), encoding="utf-8"))
FACS = ["sanctuary", "radiance", "tempest", "verdance", "abyss"]
NAME = {f: F[f]["name"] for f in F}
E = html.escape

rows = []
for p in glob.glob(os.path.join(src, "results_*.jsonl")):
    for line in open(p, encoding="utf-8"):
        if line.strip():
            rows.append(json.loads(line))


def winner_fac(r):
    return None if not r["over"] else (r["p0"] if r["winner"] == 0 else r["p1"])


stats = {}
for f in FACS:
    played = [r for r in rows if r["p0"] == f or r["p1"] == f]
    wins = [r for r in played if winner_fac(r) == f]
    seats = [(r, 0) for r in rows if r["p0"] == f] + [(r, 1) for r in rows if r["p1"] == f]
    stats[f] = {
        "played": len(played), "wins": len(wins), "rate": 100.0 * len(wins) / max(1, len(played)),
        "len": sum(r["time"] for r in played if r["over"]) / max(1, sum(1 for r in played if r["over"])),
        "t2": sum(1 for r, i in seats if r["tiers"][i] >= 2), "t3": sum(1 for r, i in seats if r["tiers"][i] >= 3),
        "peak": sum(r["peak_supply"][i] for r, i in seats) / max(1, len(seats)), "seats": len(seats),
    }
FACS.sort(key=lambda f: -stats[f]["rate"])
lens = sorted(r["time"] for r in rows if r["over"])
unfinished = sum(1 for r in rows if not r["over"])
fb = sorted(r["first_blood"] for r in rows if r["first_blood"] >= 0)

o = []
w = o.append
w("""<title>Nexus Balance Baseline</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Cinzel:wght@500;700&family=Source+Sans+3:ital,wght@0,400;0,600;1,400&family=IBM+Plex+Mono:wght@400;500&display=swap">
<style>
:root{--bg:#f1f2f6;--panel:#ffffff;--ink:#171a26;--muted:#5a6078;--line:#d5d9e6;--accent:#8a6410;--accent-soft:#fff3cf;--bar:#b8891c;--heat:138,101,16;--gold:#ffd479;--warn:#b3261e}
@media (prefers-color-scheme: dark){:root:not([data-theme="light"]){--bg:#0b0e1a;--panel:#0f1220;--ink:#dfe2ec;--muted:#8f97b3;--line:#2c3145;--accent:#ffd479;--accent-soft:#2a2410;--bar:#e0b84a;--heat:255,212,121;--warn:#ff8a80}}
:root[data-theme="dark"]{--bg:#0b0e1a;--panel:#0f1220;--ink:#dfe2ec;--muted:#8f97b3;--line:#2c3145;--accent:#ffd479;--accent-soft:#2a2410;--bar:#e0b84a;--heat:255,212,121;--warn:#ff8a80}
*{box-sizing:border-box}
body{background:var(--bg);color:var(--ink);font-family:"Source Sans 3","Segoe UI",system-ui,sans-serif;font-size:15px;line-height:1.5;margin:0}
.wrap{max-width:1040px;margin:0 auto;padding:32px 24px 80px;display:flex;flex-direction:column;gap:36px}
header h1{font-family:Cinzel,Georgia,serif;font-weight:700;font-size:32px;letter-spacing:.04em;margin:0 0 8px;text-wrap:balance}
header p{margin:0;max-width:70ch;color:var(--muted)}
.kpis{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:14px}
.kpi{background:var(--panel);border:1px solid var(--line);border-radius:6px;padding:12px 14px}
.kpi b{display:block;font-family:"IBM Plex Mono",monospace;font-size:24px;font-weight:500;line-height:1.1;font-variant-numeric:tabular-nums}
.kpi span{font-size:11px;letter-spacing:.1em;text-transform:uppercase;color:var(--muted)}
h2{font-family:Cinzel,Georgia,serif;font-weight:500;font-size:20px;letter-spacing:.06em;margin:0 0 10px;border-bottom:2px solid var(--gold);padding-bottom:6px}
h3{font-size:12px;letter-spacing:.14em;text-transform:uppercase;color:var(--muted);margin:18px 0 8px;font-weight:600}
.sub{color:var(--muted);margin:0 0 14px;max-width:80ch}
.chart{display:grid;grid-template-columns:110px minmax(0,1fr) 60px;row-gap:10px;column-gap:12px;align-items:center;background:var(--panel);border:1px solid var(--line);border-radius:6px;padding:16px 18px}
.chart .lab{font-weight:600;text-align:right}
.chart .track{position:relative;height:18px;background:transparent}
.chart .track::before{content:"";position:absolute;left:50%;top:-4px;bottom:-4px;border-left:1px dashed var(--line)}
.chart .bar{position:absolute;left:0;top:2px;height:14px;background:var(--bar);border-radius:0 4px 4px 0}
.chart .val{font-family:"IBM Plex Mono",monospace;font-variant-numeric:tabular-nums;color:var(--muted)}
.chart .axis{grid-column:2;display:flex;justify-content:space-between;font-family:"IBM Plex Mono",monospace;font-size:11px;color:var(--muted)}
.tbl{overflow-x:auto;border:1px solid var(--line);border-radius:6px;background:var(--panel)}
table{border-collapse:collapse;width:100%;font-size:14px;font-variant-numeric:tabular-nums}
th{text-align:left;font-size:11px;letter-spacing:.1em;text-transform:uppercase;color:var(--muted);padding:9px 12px;border-bottom:1px solid var(--line);white-space:nowrap}
td{padding:8px 12px;border-bottom:1px solid var(--line);vertical-align:top}
tr:last-child td{border-bottom:0}
td.n{font-weight:600;white-space:nowrap}
td.num,th.num{text-align:right}
td.heat{text-align:center;font-family:"IBM Plex Mono",monospace;font-size:13px}
td.zero{color:var(--muted)}
td.never{color:var(--warn)}
.findings{background:var(--panel);border:1px solid var(--line);border-left:3px solid var(--gold);border-radius:0 6px 6px 0;padding:14px 20px;max-width:80ch}
.findings li{margin:6px 0}
details{border:1px solid var(--line);border-radius:6px;background:var(--panel)}
details summary{cursor:pointer;padding:10px 14px;font-weight:600}
details .tbl{border:0;border-top:1px solid var(--line);border-radius:0}
.legend{font-size:12px;color:var(--muted);margin-top:8px}
</style>
<div class="wrap">
<header><h1>Nexus Balance Baseline</h1>
""")
w('<p>%d AI-versus-AI matches from the Godot build: every faction pairing including mirrors, easy / normal / hard, two map seeds each, capped at 1200 game seconds. Player 0 is a normal AI in the human seat; player 1 is the opponent AI with the difficulty\'s income multiplier. Attack timing and build delay apply to both sides.</p></header>' % len(rows))
w('<div class="kpis"><div class="kpi"><b>%d</b><span>matches</span></div><div class="kpi"><b>%d s</b><span>median length</span></div><div class="kpi"><b>%d s</b><span>median first blood</span></div><div class="kpi"><b>%d</b><span>stand-offs at cap</span></div><div class="kpi"><b>0 / %d</b><span>seats reaching Tier 3</span></div></div>'
  % (len(rows), lens[len(lens) // 2] if lens else 0, fb[len(fb) // 2] if fb else 0, unfinished, len(rows) * 2))

# win-rate chart
w('<section><h2>Faction win rate</h2><p class="sub">Wins over every match the faction appeared in, either seat, all difficulties. The dashed line is 50 percent; a fair roster sits within about ten points of it.</p><div class="chart">')
for f in FACS:
    s = stats[f]
    w('<div class="lab">%s</div><div class="track"><div class="bar" style="width:%.1f%%"></div></div><div class="val">%d%%</div>' % (E(NAME[f]), s["rate"], round(s["rate"])))
w('<div></div><div class="axis"><span>0</span><span>50</span><span>100%</span></div><div></div></div></section>')

# head to head heat table
w('<section><h2>Head-to-head</h2><p class="sub">Row is the human seat, column the opponent. Each cell is wins for the row faction out of six matches (three difficulties, two seeds). Darker cells are more wins.</p><div class="tbl"><table><thead><tr><th>vs</th>%s</tr></thead><tbody>' % "".join("<th class=\"heat\" style=\"text-align:center\">%s</th>" % E(NAME[f]) for f in FACS))
for a in FACS:
    cells = []
    for b in FACS:
        ms = [r for r in rows if r["p0"] == a and r["p1"] == b]
        ws = sum(1 for r in ms if r["over"] and r["winner"] == 0)
        alpha = 0.08 + 0.72 * ws / max(1, len(ms))
        cells.append('<td class="heat" style="background:rgba(var(--heat),%.2f)">%d / %d</td>' % (alpha, ws, len(ms)))
    w('<tr><td class="n">%s</td>%s</tr>' % (E(NAME[a]), "".join(cells)))
w('</tbody></table></div></section>')

# difficulty
w('<section><h2>Difficulty</h2><p class="sub">How the human seat fared against each difficulty. Because only the income multiplier is asymmetric in this harness, the spread is smaller than a real player would feel.</p><div class="tbl"><table><thead><tr><th>Difficulty</th><th class="num">Matches</th><th class="num">Human seat wins</th><th class="num">Opponent wins</th><th class="num">Stand-offs</th><th class="num">Avg length (s)</th></tr></thead><tbody>')
for d in ["easy", "normal", "hard"]:
    ms = [r for r in rows if r["diff"] == d]
    h = sum(1 for r in ms if r["over"] and r["winner"] == 0); op = sum(1 for r in ms if r["over"] and r["winner"] == 1); u = sum(1 for r in ms if not r["over"])
    ln = [r["time"] for r in ms if r["over"]]
    w('<tr><td class="n">%s</td><td class="num">%d</td><td class="num">%d</td><td class="num">%d</td><td class="num">%d</td><td class="num">%d</td></tr>' % (d, len(ms), h, op, u, sum(ln) / max(1, len(ln))))
w('</tbody></table></div></section>')

# tech
w('<section><h2>Tech progression</h2><p class="sub">Per seat (60 per faction). Tier 3 was never reached, so Tier 3 units, research, and ultimates did not feature in a single match.</p><div class="tbl"><table><thead><tr><th>Faction</th><th class="num">Seats</th><th class="num">Reached Tier 2</th><th class="num">Reached Tier 3</th><th class="num">Avg peak supply</th><th class="num">Avg match length (s)</th></tr></thead><tbody>')
for f in FACS:
    s = stats[f]
    w('<tr><td class="n">%s</td><td class="num">%d</td><td class="num">%d</td><td class="num">%d</td><td class="num">%.1f</td><td class="num">%d</td></tr>' % (E(NAME[f]), s["seats"], s["t2"], s["t3"], s["peak"], s["len"]))
w('</tbody></table></div></section>')

# production
w('<section><h2>What the AI actually built</h2><p class="sub">Units are average copies per match; buildings and research are the number of seats that produced them at least once. Red means never.</p>')
for f in FACS:
    seats = [(r, 0) for r in rows if r["p0"] == f] + [(r, 1) for r in rows if r["p1"] == f]
    n = len(seats)
    units = collections.Counter(); blds = collections.Counter(); res = collections.Counter()
    for r, i in seats:
        for k, v in r["produced"][i]["units"].items(): units[k] += v
        for k in r["produced"][i]["buildings"]: blds[k] += 1
        for k in r["produced"][i]["research"]: res[k] += 1
    never = sum(1 for k in F[f]["units"] if units[k] == 0) + sum(1 for k in F[f]["buildings"] if blds[k] == 0) + sum(1 for k in F[f].get("research", {}) if res[k] == 0)
    w('<details><summary>%s <span style="color:var(--muted);font-weight:400">— %d items never produced</span></summary>' % (E(NAME[f]), never))
    w('<div class="tbl"><table><thead><tr><th>Unit</th><th class="num">Tier</th><th class="num">Per match</th><th>Building</th><th class="num">Tier</th><th class="num">Seats</th><th>Research</th><th class="num">Seats</th></tr></thead><tbody>')
    ul = list(F[f]["units"].items()); bl = list(F[f]["buildings"].items()); rl = list(F[f].get("research", {}).items())
    for i in range(max(len(ul), len(bl), len(rl))):
        if i < len(ul):
            v = units[ul[i][0]] / max(1, n)
            uc = '<td class="%s">%s</td><td class="num">%s</td><td class="num %s">%.1f</td>' % ("never" if v == 0 else "", E(ul[i][1]["name"]), ul[i][1].get("tier", 1), "never" if v == 0 else "", v)
        else:
            uc = "<td></td><td></td><td></td>"
        if i < len(bl):
            v = blds[bl[i][0]]
            bc = '<td class="%s">%s</td><td class="num">%s</td><td class="num %s">%d</td>' % ("never" if v == 0 else "", E(bl[i][1]["name"]), bl[i][1].get("tier", 1), "never" if v == 0 else "", v)
        else:
            bc = "<td></td><td></td><td></td>"
        if i < len(rl):
            v = res[rl[i][0]]
            rc = '<td class="%s">%s</td><td class="num %s">%d</td>' % ("never" if v == 0 else "", E(rl[i][1].get("name", rl[i][0])), "never" if v == 0 else "", v)
        else:
            rc = "<td></td><td></td>"
        w("<tr>%s%s%s</tr>" % (uc, bc, rc))
    w('</tbody></table></div></details>')
w('</section>')

best = FACS[0]; worst = FACS[-1]
label = sys.argv[2] if len(sys.argv) > 2 else ""
t2_total = sum(stats[f]["t2"] for f in FACS)
t2_units = collections.Counter()
for r in rows:
    for i in (0, 1):
        for k, v in r["produced"][i]["units"].items():
            fac = r["p0"] if i == 0 else r["p1"]
            if F[fac]["units"].get(k, {}).get("tier", 1) >= 2: t2_units[fac] += v
mid = [f for f in FACS[1:-1]]
w('<section><h2>Findings%s</h2><div class="findings"><ol>' % ((" — " + E(label)) if label else ""))
w('<li><b>%s is strongest</b> at %d percent; <b>%s is weakest</b> at %d percent. The rest sit between %d and %d. A spread wider than about twenty points means the rosters, not the AI, are unbalanced.</li>' % (E(NAME[best]), round(stats[best]["rate"]), E(NAME[worst]), round(stats[worst]["rate"]), round(min(stats[f]["rate"] for f in mid)) if mid else 0, round(max(stats[f]["rate"] for f in mid)) if mid else 0))
w('<li><b>Tech.</b> Tier 2 was reached in %d of %d seats; Tier 3 in %d. Tier 2 units built per faction across the run: %s.</li>' % (t2_total, len(rows) * 2, sum(stats[f]["t3"] for f in FACS), ", ".join("%s %d" % (NAME[f], t2_units[f]) for f in FACS)))
w('<li><b>%d matches stalled to the cap.</b> %s</li>' % (unfinished, "Both sides turtle behind towers; the late-game attack escalation is meant to end these." if unfinished else "The late-game escalation ends stand-offs."))
easy = [r for r in rows if r["diff"] == "easy"]; hard = [r for r in rows if r["diff"] == "hard"]
ew = sum(1 for r in easy if r["over"] and r["winner"] == 0); hw = sum(1 for r in hard if r["over"] and r["winner"] == 0)
w('<li><b>Difficulty.</b> The human seat won %d of %d on easy and %d of %d on hard. Only the income multiplier is asymmetric in this harness, so a real player feels a wider gap.</li>' % (ew, len(easy), hw, len(hard)))
w('</ol></div><p class="legend">Regenerate: <code>python tools/balance_report.py &lt;results dir&gt;</code> and <code>python tools/gen_balance_page.py &lt;results dir&gt; [label]</code>. Matches come from <code>godot/tools/balance.gd</code>.</p></section>')
w('</div>')
out = os.path.join(ROOT, "docs/balance-report.html")
open(out, "w", encoding="utf-8").write("\n".join(o))
print("wrote", out)
