#!/usr/bin/env python3
"""How a four-team Paintbot game actually gets finished.

The third pass in `analysis/paintbot.md` says 71% of our four-team episodes
time out with us ahead on lives and paid nothing, and that a capture -- which
under GV32 eliminates the captured team outright -- is the cheapest
elimination in the game. This asks the winners how THEY end games: by taking
hearts, or by outlasting.

Reads the sampled resolved four-team replays in `replays/pb/` (metadata in
`meta.json`, event streams from the engine's own `tools/extract_events.nim`).

    nix shell nixpkgs#python3 -c python3 analysis/pb_finish.py

Read-only.
"""

import json
from collections import Counter, defaultdict
from pathlib import Path

PB = Path(__file__).resolve().parent.parent / "replays" / "pb"


def main():
    meta = json.loads((PB / "meta.json").read_text())
    per_winner = defaultdict(Counter)
    caps_by_winner = defaultdict(list)
    kills_by_winner = defaultdict(list)
    finish_tick = defaultdict(list)
    first_cap_tick = []
    rows = []

    for m in meta:
        evp = PB / (m["id"] + ".jsonl")
        if not evp.exists():
            continue
        evs = [json.loads(l) for l in evp.read_text().splitlines()]
        evs = [e for e in evs if e.get("type") != "summary"]
        seats = {int(k): v for k, v in m["seats"].items()}
        teams = 4
        # a seat's team is slot mod 4; a player owns the seats it was given
        owner_of_team = {}
        for slot, who in seats.items():
            owner_of_team.setdefault(slot % teams, who)

        caps = [e for e in evs if e["kind"] == "capture"]
        kills = [e for e in evs if e["kind"] == "kill"]
        last = max((e["tick"] for e in evs), default=0)
        w = m["winner"]

        # who captured what
        cap_by = Counter()
        for c in caps:
            t = seats.get(c["source"], "?")
            cap_by[t] += 1
        # the winner's own kill count
        wk = sum(1 for k in kills if seats.get(k["source"]) == w)

        per_winner[w]["episodes"] += 1
        per_winner[w]["captures_total"] += len(caps)
        per_winner[w]["captures_by_winner"] += cap_by.get(w, 0)
        caps_by_winner[w].append(cap_by.get(w, 0))
        kills_by_winner[w].append(wk)
        finish_tick[w].append(last)
        if caps:
            first_cap_tick.append(min(c["tick"] for c in caps))
        rows.append((m["id"][5:13], w, m["variant"][:20], len(caps),
                     cap_by.get(w, 0), wk, last))

    print("# how the winner finished, per episode\n")
    print(f"{'winner':18}{'eps':>5}{'caps/ep':>9}{'winner caps':>13}"
          f"{'winner kills':>14}{'finish tick':>13}")
    for w in sorted(per_winner, key=lambda x: -per_winner[x]["episodes"]):
        n = per_winner[w]["episodes"]
        c = caps_by_winner[w]
        k = kills_by_winner[w]
        t = sorted(finish_tick[w])
        print(f"{w:18}{n:>5}"
              f"{per_winner[w]['captures_total']/n:>9.2f}"
              f"{sum(c)/n:>13.2f}"
              f"{sum(k)/n:>14.1f}"
              f"{t[len(t)//2]:>13}")

    print()
    allcaps = [r[3] for r in rows]
    wincaps = [r[4] for r in rows]
    print(f"episodes sampled            : {len(rows)}")
    print(f"episodes with any capture   : {sum(1 for c in allcaps if c):>3}"
          f"  ({100*sum(1 for c in allcaps if c)/len(rows):.0f}%)")
    print(f"episodes the WINNER captured: {sum(1 for c in wincaps if c):>3}"
          f"  ({100*sum(1 for c in wincaps if c)/len(rows):.0f}%)")
    print(f"captures per episode        : {sum(allcaps)/len(rows):.2f}")
    if first_cap_tick:
        f = sorted(first_cap_tick)
        print(f"first capture tick (median) : {f[len(f)//2]}")

    print("\n# per episode")
    print(f"  {'id':10}{'winner':18}{'variant':22}{'caps':>5}{'w.caps':>8}"
          f"{'w.kills':>9}{'ticks':>8}")
    for r in sorted(rows, key=lambda x: x[1]):
        print(f"  {r[0]:10}{r[1]:18}{r[2]:22}{r[3]:>5}{r[4]:>8}{r[5]:>9}{r[6]:>8}")


if __name__ == "__main__":
    main()
