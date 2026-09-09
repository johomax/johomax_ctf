#!/usr/bin/env python3
"""Capped legs (score == 16384) per round per entrant under GLORYVERSION 17. Usage: s2_caps.py --since N"""
import argparse, glob, json, collections
CAP = 16384
ap = argparse.ArgumentParser(); ap.add_argument('--since', type=int, required=True); ap.add_argument('--top', type=int, default=8)
a = ap.parse_args()
per_round = collections.defaultdict(lambda: collections.Counter()); eps = collections.defaultdict(lambda: collections.Counter())
for d in sorted(glob.glob('research/br_rounds/*_round_*')):
    rn = int(d.split('/')[-1][:4])
    if rn < a.since: continue
    for f in glob.glob(d + '/ereq_*.json'):
        try: j = json.load(open(f))
        except Exception: continue
        res = j.get('results') or {}; req = j.get('request') or {}
        if 'scores' not in res: continue
        pol = {p['position']: p.get('player_name') for p in req.get('participants', [])}
        for i, sc in enumerate(res['scores']):
            n = pol.get(i, '?'); eps[rn][n] += 1
            if sc >= CAP: per_round[rn][n] += 1
tot = collections.Counter(); tot_eps = collections.Counter()
for rn in sorted(per_round):
    line = ' '.join(f"{n[:10]}:{c}" for n, c in per_round[rn].most_common(a.top))
    ours = per_round[rn].get('Jordan', 0)
    print(f"round {rn} Jordan {ours}/{eps[rn].get('Jordan',0)} | {line}")
    for n, c in per_round[rn].items(): tot[n] += c
    for n, c in eps[rn].items(): tot_eps[n] += c
print('--- capped legs per 12 episodes since', a.since)
for n, c in sorted(tot.items(), key=lambda kv: -kv[1] / max(1, tot_eps[kv[0]]))[:17]:
    print(f"{n[:28]:28s} {c:4d} / {tot_eps[n]:4d} eps = {12*c/max(1,tot_eps[n]):.2f} per 12")
