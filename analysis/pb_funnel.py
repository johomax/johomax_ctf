#!/usr/bin/env python3
"""Where a capture dies, per entrant: the funnel behind pb_finish.py.

pb_finish.py says the winner of a resolved four-team episode captured in 75%
of them, and that richard wins on 2.5 captures with as few as 6 kills. We take
3 captures per 384 local episodes. This walks the frame streams to find WHICH
stage of the capture separates us from the entrants who complete them:

    reach   a seat gets within ReachPx of a standing rival heart
    touch   a seat picks the heart up (the frames' carrier column)
    carry   the touch survives to a capture, or dies/drops on the way

Reads `replays/pb/*.frames` + `*.jsonl` (extract_events --frames) keyed by
`meta.json`.

    nix shell nixpkgs#python3 -c python3 analysis/pb_funnel.py

Read-only.
"""

import json
import struct
from collections import defaultdict
from pathlib import Path

PB = Path(__file__).resolve().parent.parent / "replays" / "pb"
REACH_PX = 120.0
DIE_PX = 150.0


def read_frames(path):
    """(slots, teams, ticks): ticks = [(tick, seats, flags)] with
    seats = [(x, y, hp, lives, alive)], flags = [(x, y, carrier)]."""
    b = path.read_bytes()
    magic, slots, mapw, maph, teams = struct.unpack_from("<8sHHHH", b, 0)
    assert magic == b"CTFFRM01", magic
    off = 16
    rec = 6 + slots * 10 + teams * 5
    ticks = []
    while off + rec <= len(b):
        tick, _phase, _pad = struct.unpack_from("<IBB", b, off)
        o = off + 6
        seats = []
        for _ in range(slots):
            x, y, _aim, hp, lives, fl, _fw, _wb = struct.unpack_from(
                "<hhBBBBBB", b, o)
            seats.append((float(x), float(y), hp, lives, fl & 1))
            o += 10
        flags = []
        for _ in range(teams):
            x, y, carrier = struct.unpack_from("<hhb", b, o)
            flags.append((float(x), float(y), carrier))
            o += 5
        ticks.append((tick, seats, flags))
        off += rec
    return slots, teams, ticks


def main():
    meta = json.loads((PB / "meta.json").read_text())
    agg = defaultdict(lambda: defaultdict(float))
    carries = defaultdict(list)

    for m in meta:
        fp = PB / (m["id"] + ".frames")
        if not fp.exists():
            continue
        slots, teams, ticks = read_frames(fp)
        # Drop the lobby: before the playing phase every seat reads dead at
        # zero lives, which the wipe detector would call four instant
        # eliminations.
        start = next((i for i, (_t, s, _f) in enumerate(ticks)
                      if any(seat[4] for seat in s)), 0)
        ticks = ticks[start:]
        seats = {int(k): v for k, v in m["seats"].items()}
        owner_of_team = {}
        for slot, who in seats.items():
            owner_of_team.setdefault(slot % teams, who)
        team_of_seat = {s: s % teams for s in range(slots)}

        # Pedestals: each flag's position on the first playing tick.
        pedestal = [ticks[0][2][t][:2] for t in range(teams)]

        # A heart stands until its carrier-interval ends in a capture event
        # (GV32) or its team's last life is spent (GV33, wipe).
        evs = [json.loads(l) for l in (PB / (m["id"] + ".jsonl"))
               .read_text().splitlines() if '"summary"' not in l]
        cap_ticks = [(e["tick"], e["source"]) for e in evs
                     if e.get("kind") == "capture"]

        last = ticks[-1][0]
        retired_at = [last + 1] * teams

        # Carry intervals per flag out of the carrier column.
        # interval: (flag_team, carrier_seat, t0, t1, ended_in_capture)
        intervals = []
        cur = [None] * teams          # (carrier, t0) while carried
        for tick, _s, flags in ticks:
            for t in range(teams):
                c = flags[t][2]
                if cur[t] is None and c >= 0:
                    cur[t] = (c, tick)
                elif cur[t] is not None and c != cur[t][0]:
                    c0, t0 = cur[t]
                    cap = any(abs(ct - tick) <= 2 and cs == c0
                              for ct, cs in cap_ticks)
                    intervals.append((t, c0, t0, tick, cap))
                    cur[t] = (c, tick) if c >= 0 else None
        for t in range(teams):
            if cur[t] is not None:
                c0, t0 = cur[t]
                cap = any(cs == c0 and ct >= t0 for ct, cs in cap_ticks)
                intervals.append((t, c0, t0, last, cap))
        for t, c0, t0, t1, cap in intervals:
            if cap:
                retired_at[t] = min(retired_at[t], t1)

        # Wipe retirement: all of a team's seats out of lives and dead.
        for t in range(teams):
            for tick, s, _f in ticks:
                if tick >= retired_at[t]:
                    break
                if all(s[i][3] == 0 and not s[i][4]
                       for i in range(slots) if i % teams == t):
                    retired_at[t] = min(retired_at[t], tick)
                    break

        # Funnel, per entrant.
        near = defaultdict(lambda: defaultdict(lambda: 1e18))
        deaths_at_pocket = defaultdict(int)
        was_alive = [True] * slots
        for tick, s, flags in ticks:
            for i in range(slots):
                ti = team_of_seat[i]
                me = owner_of_team[ti]
                x, y, _hp, _lv, alive = s[i]
                for r in range(teams):
                    if r == ti or tick >= retired_at[r]:
                        continue
                    fx, fy, fc = flags[r]
                    d = ((x - fx) ** 2 + (y - fy) ** 2) ** 0.5
                    if alive:
                        near[me][r] = min(near[me][r], d)
                    if was_alive[i] and not alive and d <= DIE_PX:
                        deaths_at_pocket[me] += 1
                was_alive[i] = bool(alive)

        for me in set(owner_of_team.values()):
            agg[me]["episodes"] += 1
            agg[me]["rivals_standing_seen"] += sum(
                1 for r in near[me] if near[me][r] < 1e18)
            agg[me]["reached"] += sum(
                1 for r in near[me] if near[me][r] <= REACH_PX)
            agg[me]["deaths_at_pocket"] += deaths_at_pocket[me]

        for t, c0, t0, t1, cap in intervals:
            me = owner_of_team.get(team_of_seat.get(c0, -1), "?")
            if team_of_seat.get(c0) == t:
                continue                       # own flag reset, not a raid
            agg[me]["touches"] += 1
            agg[me]["captures"] += int(cap)
            carries[me].append((t1 - t0, cap))

    print("# the capture funnel, per entrant\n")
    print(f"{'entrant':18}{'eps':>4}{'rivals':>7}{'reached':>8}"
          f"{'touches':>8}{'caps':>6}{'die@pocket':>11}")
    for me in sorted(agg, key=lambda x: -agg[x]["captures"]):
        a = agg[me]
        print(f"{me:18}{a['episodes']:>4.0f}{a['rivals_standing_seen']:>7.0f}"
              f"{a['reached']:>8.0f}{a['touches']:>8.0f}{a['captures']:>6.0f}"
              f"{a['deaths_at_pocket']:>11.0f}")
    print("\n# carries: length in ticks (median), completion")
    for me in sorted(carries, key=lambda x: -len(carries[x])):
        cs = sorted(carries[me])
        lens = sorted(l for l, _ in cs)
        done = sum(1 for _, cap in cs if cap)
        med = lens[len(lens) // 2] if lens else 0
        print(f"{me:18} {len(cs):>3} carries, {done:>3} captured, "
              f"median {med} ticks")


if __name__ == "__main__":
    main()
