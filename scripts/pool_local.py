#!/usr/bin/env python3
"""Pool a LOCAL two-direction head-to-head, by seat parity.

Same discipline as scripts/pool_h2h.py: every seat is re-keyed to the build
that actually held it, both directions are summed so the side advantage
cancels, and the remaining gap is bootstrapped over EPISODES (the eight seats
in one game share a single game and are not independent).

Local runs are small, so the interval is what matters here, not the point
estimate. A local all-slots episode cannot measure strength at hosted-league
sample sizes and is not meant to.
"""
import glob
import json
import random
import sys
from collections import defaultdict


def load(root, even_build, odd_build):
    """Every episode under `root`, with each seat labelled by its build."""
    out = []
    for f in sorted(glob.glob(f"{root}/**/results.json", recursive=True)):
        d = json.load(open(f))
        k, dd = d.get("kills") or [], d.get("deaths") or []
        cc, sc = d.get("captures") or [], d.get("scores") or []
        if not k or not dd:
            continue
        ep = defaultdict(lambda: defaultdict(float))
        for i in range(len(k)):
            b = even_build if i % 2 == 0 else odd_build
            ep[b]["kills"] += k[i]
            ep[b]["deaths"] += dd[i]
            if i < len(cc):
                ep[b]["captures"] += cc[i]
        # Score is per seat and symmetric (+1 winners, -1 losers).
        win = None
        if sc:
            ev = sum(sc[i] for i in range(len(sc)) if i % 2 == 0)
            od = sum(sc[i] for i in range(len(sc)) if i % 2 == 1)
            if ev > od:
                win = even_build
            elif od > ev:
                win = odd_build
        out.append((dict((b, dict(v)) for b, v in ep.items()), win))
    return out


def pool(eps):
    tot = defaultdict(lambda: defaultdict(float))
    wins = defaultdict(int)
    for ep, win in eps:
        for b, v in ep.items():
            for key, n in v.items():
                tot[b][key] += n
        if win:
            wins[win] += 1
    return tot, wins


def kd(tot, b):
    return tot[b]["kills"] / tot[b]["deaths"] if tot[b]["deaths"] else 0.0


def main():
    root, a, b = sys.argv[1], sys.argv[2], sys.argv[3]
    eps = load(f"{root}/dir1", a, b) + load(f"{root}/dir2", b, a)
    if not eps:
        sys.exit(f"no episodes under {root}")
    tot, wins = pool(eps)
    n = len(eps)
    print(f"episodes pooled : {n}   ({a} vs {b})\n")
    for x in (a, b):
        print(f"{x}")
        print(f"  kills    : {tot[x]['kills']:.0f}")
        print(f"  deaths   : {tot[x]['deaths']:.0f}")
        print(f"  captures : {tot[x]['captures']:.0f}")
        print(f"  K/D      : {kd(tot, x):.4f}")
        print(f"  wins     : {wins[x]} / {n}")
    obs = kd(tot, a) - kd(tot, b)
    random.seed(20260729)
    s = []
    for _ in range(10000):
        smp = [random.choice(eps) for _ in eps]
        t, _w = pool(smp)
        s.append(kd(t, a) - kd(t, b))
    s.sort()
    lo, hi = s[int(0.025 * len(s))], s[int(0.975 * len(s))]
    print(f"\nK/D gap ({a} - {b})")
    print(f"  observed           : {obs:+.4f}")
    print(f"  95% CI (bootstrap) : [{lo:+.4f}, {hi:+.4f}]")
    print(f"  crosses zero       : {'YES' if lo <= 0 <= hi else 'no'}")


if __name__ == "__main__":
    main()
