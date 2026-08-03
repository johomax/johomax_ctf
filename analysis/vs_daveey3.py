#!/usr/bin/env python3
"""Third pass: role split per seat, and where each side dies.

Pass two said we push and they camp, and that we die 1.8x faster per
alive-tick. This asks where that happens: per-seat station (how far up the
field each seat lives), death positions on the same axis, and what a flag
steal costs each side.

    nix shell nixpkgs#python3 -c python3 analysis/vs_daveey3.py

Read-only.
"""

import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from vs_daveey import load_frames, REPLAYS  # noqa: E402

US, THEM = "Jordan", "daveey"
W = 1235.0


def advance(x, red):
    return x / W if red else 1.0 - x / W


def main():
    eps = json.loads((REPLAYS / "daveey_eps.json").read_text())
    seat_adv = defaultdict(list)      # (who, seat_in_team) -> advances
    death_adv = defaultdict(list)     # who -> advance where they died
    kill_adv = defaultdict(list)      # who -> advance where they got a kill
    steal_out = Counter()             # steals that became captures
    carry_len = defaultdict(list)
    hp_at_death = defaultdict(list)
    outnumber = Counter()             # local 2v1s won
    sides = Counter()

    for e in eps:
        base = REPLAYS / "ev" / e["id"]
        evp, frp = base.with_suffix(".jsonl"), base.with_suffix(".frames")
        if not evp.exists():
            continue
        owner = {p["position"]: p["player_name"] for p in e["participants"]}
        red = {pos: pos % 2 == 0 for pos in owner}
        sides[(owner[0], "red")] += 1
        evs = [json.loads(l) for l in evp.read_text().splitlines()]
        evs = [x for x in evs if x.get("type") != "summary"]

        frames = {}
        for tick, phase, seats, flags in load_frames(frp):
            if phase != 1:
                continue
            frames[tick] = (seats, flags)
            for s, st in enumerate(seats):
                if not st["alive"]:
                    continue
                who = owner.get(s)
                seat_adv[(who, s // 2)].append(advance(st["x"], red[s]))

        for x in evs:
            if x["kind"] == "kill":
                k, v = owner.get(x["source"]), owner.get(x["target"])
                seats = frames.get(x["tick"], (None, None))[0]
                if seats is None:
                    continue
                if v is not None:
                    death_adv[v].append(advance(seats[x["target"]]["x"],
                                                red[x["target"]]))
                if k is not None:
                    kill_adv[k].append(advance(seats[x["source"]]["x"],
                                               red[x["source"]]))
            elif x["kind"] == "flag_steal":
                who = owner.get(x["source"])
                if who:
                    steal_out[who] += 1

        # how long a stolen flag survived, per side
        carrier_start = {}
        for tick in sorted(frames):
            seats, flags = frames[tick]
            for ti, fl in enumerate(flags):
                c = fl["carrier"]
                key = ti
                if c >= 0 and key not in carrier_start:
                    carrier_start[key] = (tick, owner.get(c))
                elif c < 0 and key in carrier_start:
                    t0, who = carrier_start.pop(key)
                    if who:
                        carry_len[who].append(tick - t0)
        for key, (t0, who) in carrier_start.items():
            if who:
                carry_len[who].append(max(frames) - t0)

    def stat(v):
        v = sorted(v)
        if not v:
            return "n=0"
        return (f"n={len(v):<5} mean={sum(v)/len(v):.3f} med={v[len(v)//2]:.3f} "
                f"p90={v[9*len(v)//10]:.3f}")

    print("# per-seat station (0 = own base edge, 1 = enemy base edge)")
    print(f"{'seat pair':10}{'Jordan mean':>14}{'daveey mean':>14}")
    for i in range(8):
        a = seat_adv[(US, i)]
        b = seat_adv[(THEM, i)]
        print(f"{i:<10}{sum(a)/max(1,len(a)):>14.3f}{sum(b)/max(1,len(b)):>14.3f}")
    print()
    print("# where each side dies, on the same axis")
    for w in (US, THEM):
        print(f"  {w:8} {stat(death_adv[w])}")
    print("# where each side gets its kills")
    for w in (US, THEM):
        print(f"  {w:8} {stat(kill_adv[w])}")
    print()
    print("# stolen-flag carry length in ticks (per steal)")
    for w in (US, THEM):
        print(f"  {w:8} {stat(carry_len[w])}")
    print()
    print("# steals", dict(steal_out))
    print("# episodes where seat 0 belonged to:", dict(sides))


if __name__ == "__main__":
    main()
