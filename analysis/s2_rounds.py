#!/usr/bin/env python3
"""Per-round means for our policy versions from research/br_rounds/*.json.

usage: analysis/s2_rounds.py [--since N] [--name jordan-ctf-candidate]
Each round file holds one episode request (participants + scores); a round
is 12 files. Prints, per round and version: episodes, seats, mean score,
wins, kills, team kills.
"""
import argparse, collections, glob, json, os

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--since", type=int, default=3652)
    ap.add_argument("--name", default="jordan-ctf-candidate")
    a = ap.parse_args()
    rounds = collections.defaultdict(lambda: collections.defaultdict(lambda: {"eps": 0, "seats": 0, "score": 0.0, "wins": 0, "kills": 0, "tk": 0}))
    others = collections.defaultdict(lambda: collections.defaultdict(lambda: {"seats": 0, "score": 0.0, "wins": 0}))
    for f in glob.glob("research/br_rounds/*/*.json"):
        d = json.load(open(f)); rn = d.get("round")
        if rn is None or rn < a.since: continue
        r = d["request"]; parts = r.get("participants") or []; scores = r.get("scores") or []
        res = (d.get("results") or {})
        kills = res.get("kills") or []; tks = res.get("teamKills") or []; wins = res.get("win") or []
        seen = set()
        for p in parts:
            i = p.get("position"); label = f"{p.get('policy_name')}:v{p.get('version')}"
            sc = scores[i] if i is not None and i < len(scores) else 0
            if p.get("policy_name") == a.name:
                row = rounds[rn][label]; row["seats"] += 1; row["score"] += sc or 0
                row["kills"] += (kills[i] if i < len(kills) else 0) or 0
                row["tk"] += (tks[i] if i < len(tks) else 0) or 0
                row["wins"] += 1 if (i < len(wins) and wins[i]) else 0
                if label not in seen: row["eps"] += 1; seen.add(label)
            else:
                o = others[rn][label]; o["seats"] += 1; o["score"] += sc or 0; o["wins"] += 1 if (i < len(wins) and wins[i]) else 0
    for rn in sorted(rounds):
        for label, row in rounds[rn].items():
            n = max(1, row["seats"])
            top = sorted(others[rn].items(), key=lambda kv: -kv[1]["score"] / max(1, kv[1]["seats"]))[:2]
            top_s = ", ".join(f"{l.split(':')[0][:12]} {v['score']/max(1,v['seats']):.1f}" for l, v in top)
            print(f"round {rn} {label:>28} eps {row['eps']:2d} seats {row['seats']:2d} mean {row['score']/n:6.1f} wins {row['wins']//2:2d} kills {row['kills']:2d} tk {row['tk']:2d} | top others: {top_s}")

if __name__ == "__main__":
    main()
