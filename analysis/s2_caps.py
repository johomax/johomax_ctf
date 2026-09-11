#!/usr/bin/env python3
"""Big legs (>= 16384) and capped legs (>= 2097152, GLORYVERSION 18 ceiling) per round per entrant. Usage: s2_caps.py --since N [--cap 2097152]"""
import argparse, glob, json, collections
BIG = 16384
ap = argparse.ArgumentParser(); ap.add_argument('--since', type=int, required=True); ap.add_argument('--top', type=int, default=8); ap.add_argument('--cap', type=int, default=2097152)
a = ap.parse_args()
per_round = collections.defaultdict(lambda: collections.Counter()); eps = collections.defaultdict(lambda: collections.Counter()); big = collections.defaultdict(lambda: collections.Counter())
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
            if sc >= BIG: big[rn][n] += 1
            if sc >= a.cap: per_round[rn][n] += 1
tot = collections.Counter(); tot_eps = collections.Counter(); tot_big = collections.Counter()
for rn in sorted(per_round):
    line = ' '.join(f"{n[:10]}:{c}" for n, c in per_round[rn].most_common(a.top))
    ours = per_round[rn].get('Jordan', 0)
    print(f"round {rn} Jordan {ours}/{eps[rn].get('Jordan',0)} | {line}")
    for n, c in per_round[rn].items(): tot[n] += c
    for n, c in eps[rn].items(): tot_eps[n] += c
    for n, c in big[rn].items(): tot_big[n] += c
print('--- capped (>=%d) and big (>=16384) legs per 12 episodes since %d' % (a.cap, a.since))
names = set(tot) | set(tot_big)
for n in sorted(names, key=lambda k: (-tot[k] / max(1, tot_eps[k]), -tot_big[k]))[:17]:
    c = tot[n]; b = tot_big[n]
    print(f"{n[:28]:28s} capped {c:4d} / {tot_eps[n]:4d} eps = {12*c/max(1,tot_eps[n]):.2f} per 12 | big {b:4d} = {12*b/max(1,tot_eps[n]):.2f} per 12")
