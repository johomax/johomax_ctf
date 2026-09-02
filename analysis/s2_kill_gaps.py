#!/usr/bin/env python3
"""Death-tick timeline of our winning episodes from mined replay reports.

Usage: analysis/s2_kill_gaps.py research/s2_replays/<round dir> [...]
Prints, per episode our duo won: score, duo kills, enemy death ticks and the
number of <45-tick gaps (the engine's heat window) as a proxy for chained kills.
"""
import json, sys, os

NAME = "jordan-ctf-candidate"

for d in sys.argv[1:]:
    rep = json.load(open(os.path.join(d, "report.json")))
    for ep in rep["episodes"]:
        ours = [s for s in ep["seats"] if (s.get("policy_name") or "") == NAME]
        if not ours or not all(s.get("placement") == 1 for s in ours):
            continue
        deaths = sorted(s["death_tick"] for s in ep["seats"]
                        if s.get("death_tick") is not None and (s.get("policy_name") or "") != NAME)
        gaps = [b - a for a, b in zip(deaths, deaths[1:])]
        chained = sum(1 for g in gaps if g < 45)
        print(f"{os.path.basename(d.rstrip('/'))[:10]} {ep['id'][:12]} score {ours[0].get('score')} "
              f"duo kills {sum(s.get('kills') or 0 for s in ours)} enemy deaths {deaths} chained(<45) {chained}")
