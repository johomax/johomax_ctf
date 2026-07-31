"""Current-form table from the indexed episodes: per-player W/L, and H2H matrix."""
import json
from collections import defaultdict

import os

CACHE = os.path.expanduser("~/.ctf/scout")

eps = json.load(open(f"{CACHE}/episodes.json"))

rec = defaultdict(lambda: {"w": 0, "l": 0, "d": 0, "n": 0})
h2h = defaultdict(lambda: {"w": 0, "l": 0, "d": 0})
versions = defaultdict(set)
skipped = defaultdict(int)

for e in eps:
    if e.get("status") != "completed":
        skipped[e.get("status") or e.get("error_type") or "not-completed"] += 1
        continue
    scores = {s["policy_version_id"]: s["score"] for s in (e.get("scores") or [])}
    if len(scores) != 2:
        skipped[f"scores={len(scores)}"] += 1
        continue
    # map policy_version_id -> player name (grounded in participants, not the label)
    pv2name = {}
    for p in e.get("participants") or []:
        pv2name[p["policy_version_id"]] = p.get("player_name")
        versions[p.get("player_name")].add(f"{p.get('policy_name')}:v{p.get('version')}")
    if len(pv2name) != 2:
        skipped["mirror-or-odd-participants"] += 1
        continue
    (a, sa), (b, sb) = scores.items()
    na, nb = pv2name.get(a), pv2name.get(b)
    if not na or not nb:
        skipped["unmapped-pv"] += 1
        continue
    for n in (na, nb):
        rec[n]["n"] += 1
    if sa > sb:
        rec[na]["w"] += 1; rec[nb]["l"] += 1
        h2h[(na, nb)]["w"] += 1; h2h[(nb, na)]["l"] += 1
    elif sb > sa:
        rec[nb]["w"] += 1; rec[na]["l"] += 1
        h2h[(nb, na)]["w"] += 1; h2h[(na, nb)]["l"] += 1
    else:
        rec[na]["d"] += 1; rec[nb]["d"] += 1
        h2h[(na, nb)]["d"] += 1; h2h[(nb, na)]["d"] += 1

rnds = sorted({e["_round_number"] for e in eps})
print(f"=== CURRENT FORM: r{rnds[0]}..r{rnds[-1]}, {len(eps)} episodes indexed ===")
if skipped:
    print("skipped:", dict(skipped))
print(f"\n{'player':20} {'n':>5} {'W':>5} {'L':>5} {'D':>5} {'winrate':>8}   versions fielded")
order = sorted(rec.items(), key=lambda kv: -(kv[1]["w"] / max(kv[1]["n"], 1)))
for name, r in order:
    wr = r["w"] / max(r["n"], 1)
    print(f"{str(name)[:20]:20} {r['n']:>5} {r['w']:>5} {r['l']:>5} {r['d']:>5} {wr:>8.3f}   "
          f"{','.join(sorted(versions[name]))}")

names = [n for n, _ in order]
print(f"\n=== H2H win rate (row vs col) ===")
print(f"{'':18}" + "".join(f"{str(n)[:7]:>8}" for n in names))
for a in names:
    row = f"{str(a)[:18]:18}"
    for b in names:
        if a == b:
            row += f"{'-':>8}"
            continue
        h = h2h.get((a, b))
        if not h or (h["w"] + h["l"] + h["d"]) == 0:
            row += f"{'.':>8}"
        else:
            tot = h["w"] + h["l"] + h["d"]
            row += f"{h['w']/tot:>8.2f}"
    print(row)

print(f"\n=== H2H sample sizes ===")
for a in names:
    row = f"{str(a)[:18]:18}"
    for b in names:
        h = h2h.get((a, b))
        tot = (h["w"] + h["l"] + h["d"]) if h else 0
        row += f"{tot:>8}"
    print(row)
