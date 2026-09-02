#!/usr/bin/env python3
"""Winner glory per local batch: the hosted objective is the best single winning score.

Usage: analysis/s2_local_glory.py episodes/s2-*-vs-starters [...]
Per batch and bot label: duo-episodes, duo wins, mean/max winning score, wins >= 200.
"""
import glob, json, os, sys, collections

for d in sys.argv[1:]:
    st = collections.defaultdict(lambda: {"eps": 0, "wins": 0, "ws": [], "kills": 0})
    for seed in sorted(glob.glob(os.path.join(d, "seed_*"))):
        try:
            a = json.load(open(os.path.join(seed, "assign.json")))
            r = json.load(open(os.path.join(seed, "results.json")))
        except FileNotFoundError:
            continue
        n = len(r["scores"]); half = n // 2
        for i in range(half):
            lab = a.get(str(i), "?"); s = st[lab]; s["eps"] += 1
            s["kills"] += (r["kills"][i] or 0) + (r["kills"][i + half] or 0)
            if r["win"][i]:
                s["wins"] += 1; s["ws"].append(r["scores"][i] or 0)
    print(f"== {os.path.basename(d.rstrip('/'))}")
    for lab, s in sorted(st.items(), key=lambda kv: -kv[1]["wins"]):
        ws = s["ws"]
        print(f"  {lab:24} duo-eps {s['eps']:3d} wins {s['wins']:2d} ({100*s['wins']/max(s['eps'],1):4.0f}%) "
              f"meanWin {sum(ws)/len(ws) if ws else 0:5.0f} max {max(ws) if ws else 0:4.0f} wins>=200 {sum(1 for x in ws if x >= 200)} kills/duo {s['kills']/max(s['eps'],1):.2f}")
