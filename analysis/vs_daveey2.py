#!/usr/bin/env python3
"""Second pass on the daveey replays: rate-normalised, and how each game ended.

The first pass (`vs_daveey.py`) counted events. Counts confound "does more per
second" with "is alive longer", and we die more, so everything here is per
alive-tick. It also reads the terminal events so an ending is named rather
than inferred from a team ordinal.

    nix shell nixpkgs#python3 -c python3 analysis/vs_daveey2.py

Read-only.
"""

import json
import math
import sys
from collections import Counter, defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from vs_daveey import load_frames, REPLAYS  # noqa: E402

US, THEM = "Jordan", "daveey"


def main():
    eps = json.loads((REPLAYS / "daveey_eps.json").read_text())
    alive = Counter()
    carry = Counter()
    shots = Counter()
    hits = Counter()
    kills = Counter()
    deaths = Counter()
    endings = Counter()
    # spatial: mean x normalised so "toward the enemy base" is positive
    adv = defaultdict(list)
    home_time = Counter()
    enemy_half = Counter()
    steal_ticks = defaultdict(list)
    ep_rows = []

    for e in eps:
        base = REPLAYS / "ev" / e["id"]
        evp, frp = base.with_suffix(".jsonl"), base.with_suffix(".frames")
        if not evp.exists():
            continue
        owner = {p["position"]: p["player_name"] for p in e["participants"]}
        # red = even slots (config alternates red/blue); red base is the left
        # edge, blue the right.
        side = {pos: ("red" if pos % 2 == 0 else "blue") for pos in owner}
        evs = [json.loads(l) for l in evp.read_text().splitlines()]
        evs = [x for x in evs if x.get("type") != "summary"]

        ep_alive = Counter()
        last_tick = 0
        for tick, phase, seats, flags in load_frames(frp):
            if phase != 1:  # Lobby=0, Playing=1, GameOver=2
                continue
            last_tick = tick
            for s, st in enumerate(seats):
                who = owner.get(s)
                if not who or not st["alive"]:
                    continue
                alive[who] += 1
                ep_alive[who] += 1
                if st["carry"]:
                    carry[who] += 1
                # advance: 0 at own base edge, 1 at the enemy base edge
                a = st["x"] / 1235.0 if side[s] == "red" else 1.0 - st["x"] / 1235.0
                adv[who].append(a)
                if a < 0.25:
                    home_time[who] += 1
                elif a > 0.75:
                    enemy_half[who] += 1

        for x in evs:
            who = owner.get(x["source"])
            if x["kind"] == "shot" and who:
                shots[who] += 1
            elif x["kind"] == "hit" and who:
                hits[who] += 1
            elif x["kind"] == "kill" and who:
                kills[who] += 1
                v = owner.get(x["target"])
                if v:
                    deaths[v] += 1
            elif x["kind"] == "flag_steal" and who:
                steal_ticks[who].append(x["tick"])

        tail = [x for x in evs if x["kind"] in ("phase", "capture", "flag_capture")]
        gameover = [x for x in tail if x.get("weapon") == "gameover"]
        cap = [x for x in evs if "captur" in x["kind"]]
        # A capture ends a 2-team game outright; otherwise it is a wipe or the
        # 5000-tick limit.
        if cap:
            endings["capture"] += 1
        elif last_tick >= 4900:
            endings["timeout"] += 1
        else:
            endings["wipe"] += 1
        ep_rows.append((e["id"][5:13], last_tick, ep_alive[US], ep_alive[THEM]))

    def rate(c, per=1000):
        return {w: per * c[w] / max(1, alive[w]) for w in (US, THEM)}

    print("# rate-normalised, per 1000 alive-ticks\n")
    print(f"{'':26}{US:>10}{THEM:>10}   ratio")
    rows = [("alive ticks (total)", alive, 1),
            ("shots", shots, 1000), ("hits", hits, 1000),
            ("kills", kills, 1000), ("deaths", deaths, 1000),
            ("flag-carry ticks", carry, 1000)]
    for name, c, per in rows:
        if per == 1:
            a, b = c[US], c[THEM]
            print(f"{name:26}{a:>10}{b:>10}   {a/max(1,b):.3f}")
        else:
            r = rate(c, per)
            print(f"{name:26}{r[US]:>10.2f}{r[THEM]:>10.2f}   "
                  f"{r[US]/max(1e-9,r[THEM]):.3f}")
    print()
    print("## where the seats stand (0 = own base edge, 1 = enemy base edge)")
    for w in (US, THEM):
        v = adv[w]
        v.sort()
        print(f"{w:10} mean={sum(v)/len(v):.3f} median={v[len(v)//2]:.3f} "
              f"p10={v[len(v)//10]:.3f} p90={v[9*len(v)//10]:.3f}")
    print(f"{'':10} own quarter: "
          f"{US} {100*home_time[US]/alive[US]:.1f}%  "
          f"{THEM} {100*home_time[THEM]/alive[THEM]:.1f}%")
    print(f"{'':10} enemy quarter: "
          f"{US} {100*enemy_half[US]/alive[US]:.1f}%  "
          f"{THEM} {100*enemy_half[THEM]/alive[THEM]:.1f}%")
    print()
    print("## endings", dict(endings))
    print("## steals", {w: len(v) for w, v in steal_ticks.items()})
    print("## first steal tick (median)")
    for w, v in steal_ticks.items():
        v = sorted(v)
        print(f"  {w:10} n={len(v)} median tick={v[len(v)//2]}")
    print()
    print("## per episode: ticks, our alive-ticks, their alive-ticks")
    for r in ep_rows:
        print(f"  {r[0]}  ticks={r[1]:>5}  us={r[2]:>6}  them={r[3]:>6}")


if __name__ == "__main__":
    main()
