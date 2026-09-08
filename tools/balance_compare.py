"""Compare two balance runs: python tools/balance_compare.py <baseline dir> <new dir>"""
import glob, json, os, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
F = json.load(open(os.path.join(ROOT, "godot/data/factions.json"), encoding="utf-8"))
FACS = ["sanctuary", "radiance", "tempest", "verdance", "abyss"]
def load(d):
    rows = []
    for p in glob.glob(os.path.join(d, "results_*.jsonl")):
        rows += [json.loads(l) for l in open(p, encoding="utf-8") if l.strip()]
    return rows
def summarize(rows):
    out = {}
    for f in FACS:
        played = [r for r in rows if r["p0"] == f or r["p1"] == f]
        wins = [r for r in played if r["over"] and (r["p0"] if r["winner"] == 0 else r["p1"]) == f]
        seats = [(r, i) for r in rows for i in (0, 1) if (r["p0"] if i == 0 else r["p1"]) == f]
        t2 = sum(1 for r, i in seats if r["tiers"][i] >= 2)
        t2u = sum(v for r, i in seats for k, v in r["produced"][i]["units"].items() if F[f]["units"].get(k, {}).get("tier", 1) >= 2)
        out[f] = (100.0 * len(wins) / max(1, len(played)), t2, t2u)
    lens = [r["time"] for r in rows if r["over"]]
    out["_len"] = sum(lens) / max(1, len(lens)); out["_unf"] = sum(1 for r in rows if not r["over"]); out["_n"] = len(rows)
    return out
a, b = summarize(load(sys.argv[1])), summarize(load(sys.argv[2]))
print("%-10s %8s %8s %6s | %6s %6s | %8s %8s" % ("faction", "win%%old", "win%%new", "delta", "T2old", "T2new", "T2u old", "T2u new"))
for f in FACS:
    print("%-10s %8.0f %8.0f %+6.0f | %6d %6d | %8d %8d" % (F[f]["name"], a[f][0], b[f][0], b[f][0] - a[f][0], a[f][1], b[f][1], a[f][2], b[f][2]))
print("matches %d -> %d, avg length %.0f -> %.0f s, stand-offs %d -> %d" % (a["_n"], b["_n"], a["_len"], b["_len"], a["_unf"], b["_unf"]))
