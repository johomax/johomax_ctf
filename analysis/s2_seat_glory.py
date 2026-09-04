#!/usr/bin/env python3
"""Per-seat glory per local batch (works for --mixed duos).

Usage: analysis/s2_seat_glory.py episodes/<batch> [...]
Per bot label: seats, mean seat score, max, seats >= 10000, kills/seat, tk/seat, win%.
"""
import glob, json, os, sys, collections

for d in sys.argv[1:]:
    st = collections.defaultdict(lambda: {"seats": 0, "score": 0.0, "max": 0.0, "big": 0, "kills": 0, "tk": 0, "wins": 0})
    for seed in sorted(glob.glob(os.path.join(d, "seed_*"))):
        try:
            a = json.load(open(os.path.join(seed, "assign.json")))
            r = json.load(open(os.path.join(seed, "results.json")))
        except FileNotFoundError:
            continue
        for i, sc in enumerate(r["scores"]):
            s = st[a.get(str(i), "?")]; sc = sc or 0
            s["seats"] += 1; s["score"] += sc; s["max"] = max(s["max"], sc); s["big"] += sc >= 10000
            s["kills"] += r["kills"][i] or 0; s["tk"] += r["teamKills"][i] or 0; s["wins"] += 1 if r["win"][i] else 0
    print(f"== {os.path.basename(d.rstrip('/'))}")
    for lab, s in sorted(st.items(), key=lambda kv: -kv[1]["score"] / max(kv[1]["seats"], 1)):
        n = max(s["seats"], 1)
        print(f"  {lab:24} seats {s['seats']:3d} meanSeat {s['score']/n:9.0f} max {s['max']:9.0f} >=10k {s['big']:2d} kills/seat {s['kills']/n:.2f} tk/seat {s['tk']/n:.2f} win% {100*s['wins']/n:4.0f}")
