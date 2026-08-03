#!/usr/bin/env python3
"""What daveey does to us: the 17 recent league episodes, read out of replays.

Reads the event stream and the per-tick frame stream `tools/extract_events.nim`
writes for each downloaded replay, keys every seat to the player that held it
(from the episode participants, never from the seat number), and reports the
contrasts that a policy change could act on.

    nix shell nixpkgs#python3 -c python3 analysis/vs_daveey.py

Read-only.
"""

import json
import math
import struct
import sys
from collections import Counter, defaultdict
from pathlib import Path

REPLAYS = Path(__file__).resolve().parent.parent / "replays"
SEAT_BYTES = 10
HEADER_BYTES = 16


def load_frames(path):
    """Yields (tick, phase, seats, flags) per record; seats are dicts."""
    data = path.read_bytes()
    assert data[:8] == b"CTFFRM01", data[:8]
    slots, w, h, teams = struct.unpack_from("<HHHH", data, 8)
    rec = 6 + slots * SEAT_BYTES + teams * 5
    off = HEADER_BYTES
    while off + rec <= len(data):
        tick, phase, _ = struct.unpack_from("<IBB", data, off)
        o = off + 6
        seats = []
        for _ in range(slots):
            x, y, aim, hp, lives, flags, fw, wb = struct.unpack_from("<hhBBBBBB", data, o)
            seats.append(dict(x=x, y=y, aim=aim, hp=hp, lives=lives, flags=flags,
                              fw=fw, wb=wb, alive=bool(flags & 1),
                              carry=bool(flags & 2)))
            o += SEAT_BYTES
        flagsv = []
        for _ in range(teams):
            fx, fy, carrier = struct.unpack_from("<hhb", data, o)
            flagsv.append(dict(x=fx, y=fy, carrier=carrier))
            o += 5
        yield tick, phase, seats, flagsv
        off += rec
    return


def main():
    eps = json.loads((REPLAYS / "daveey_eps.json").read_text())
    us, them = "Jordan", "daveey"

    agg = {us: Counter(), them: Counter()}
    shot_ranges = {us: [], them: []}
    hit_ranges = {us: [], them: []}
    death_x = {us: [], them: []}
    endings = Counter()
    first_steal = []
    kill_dist = {us: [], them: []}
    per_ep = []

    for e in eps:
        base = REPLAYS / "ev" / e["id"]
        evp, frp = base.with_suffix(".jsonl"), base.with_suffix(".frames")
        if not evp.exists():
            continue
        seat_owner = {}
        for p in e["participants"]:
            seat_owner[p["position"]] = p["player_name"]
        evs = [json.loads(l) for l in evp.read_text().splitlines()]
        summary = evs[-1] if evs[-1].get("type") == "summary" else None
        evs = [x for x in evs if x.get("type") != "summary"]

        frames = list(load_frames(frp))
        # seat -> position by spawn side: verify even seats are red (left).
        pos_by_tick = {t: seats for t, _, seats, _ in frames}
        ep_stat = Counter()

        for x in evs:
            k, s, tgt = x["kind"], x["source"], x["target"]
            who = seat_owner.get(s)
            vic = seat_owner.get(tgt)
            if k == "shot" and who:
                agg[who]["shots"] += 1
                ep_stat[(who, "shots")] += 1
            elif k == "gun_trigger" and who:
                agg[who]["triggers"] += 1
            elif k == "hit" and who:
                agg[who]["hits"] += 1
                ep_stat[(who, "hits")] += 1
                seats = pos_by_tick.get(x["tick"])
                if seats and 0 <= s < len(seats) and 0 <= tgt < len(seats):
                    d = math.dist((seats[s]["x"], seats[s]["y"]),
                                  (seats[tgt]["x"], seats[tgt]["y"]))
                    hit_ranges[who].append(d)
            elif k == "kill" and who:
                agg[who]["kills"] += 1
                agg[who][f"kill_{x['weapon']}"] += 1
                ep_stat[(who, "kills")] += 1
                if vic:
                    agg[vic]["deaths"] += 1
                seats = pos_by_tick.get(x["tick"])
                if seats and 0 <= s < len(seats) and 0 <= tgt < len(seats):
                    kill_dist[who].append(math.dist(
                        (seats[s]["x"], seats[s]["y"]),
                        (seats[tgt]["x"], seats[tgt]["y"])))
                death_x[vic].append(x["x"]) if vic else None
            elif k == "grenade_throw" and who:
                agg[who]["nades"] += 1
            elif k == "spray_use" and who:
                agg[who]["sprays"] += 1
            elif k == "item_pickup" and who:
                agg[who][f"pick_{x['item'] or 'x'}"] += 1
                agg[who]["picks"] += 1
            elif k == "shout" and who:
                agg[who]["shouts"] += 1
            elif k == "flag_steal" and who:
                agg[who]["steals"] += 1
                first_steal.append((who, x["tick"]))
            elif k == "capture" and who:
                agg[who]["captures"] += 1
            elif k == "phase" and x["weapon"] == "gameover":
                endings[x["amount"]] += 1

        # shot ranges: pair each `shot` with the shooter's nearest live enemy
        for x in evs:
            if x["kind"] != "shot":
                continue
            who = seat_owner.get(x["source"])
            seats = pos_by_tick.get(x["tick"])
            if not who or not seats or not (0 <= x["source"] < len(seats)):
                continue
            me = seats[x["source"]]
            best = None
            for s2, st in enumerate(seats):
                if seat_owner.get(s2) == who or not st["alive"]:
                    continue
                d = math.dist((me["x"], me["y"]), (st["x"], st["y"]))
                best = d if best is None or d < best else best
            if best is not None:
                shot_ranges[who].append(best)

        per_ep.append((e["id"], dict(ep_stat), summary))

    def pct(a, b):
        return f"{100.0*a/b:5.1f}%" if b else "  n/a"

    print(f"# {len(per_ep)} league episodes, Jordan vs daveey "
          f"(all 17 lost by Jordan)\n")
    print("## Totals")
    print(f"{'':22}{us:>12}{them:>12}")
    for key in ["kills", "deaths", "shots", "hits", "triggers", "nades",
                "sprays", "picks", "shouts", "steals"]:
        print(f"{key:22}{agg[us][key]:>12}{agg[them][key]:>12}")
    print(f"{'K/D':22}{agg[us]['kills']/max(1,agg[us]['deaths']):>12.3f}"
          f"{agg[them]['kills']/max(1,agg[them]['deaths']):>12.3f}")
    print(f"{'hit rate':22}{pct(agg[us]['hits'],agg[us]['shots']):>12}"
          f"{pct(agg[them]['hits'],agg[them]['shots']):>12}")
    print()
    print("## kills by weapon")
    for w in ["gun", "grenade", "spray", "trench", "elimination"]:
        k = f"kill_{w}"
        if agg[us][k] or agg[them][k]:
            print(f"{w:22}{agg[us][k]:>12}{agg[them][k]:>12}")
    print()

    def dist_table(name, d):
        print(f"## {name}")
        print(f"{'bucket':22}{us:>12}{them:>12}")
        buckets = [(0, 200), (200, 400), (400, 650), (650, 900), (900, 1300),
                   (1300, 9999)]
        for lo, hi in buckets:
            a = sum(1 for v in d[us] if lo <= v < hi)
            b = sum(1 for v in d[them] if lo <= v < hi)
            print(f"{f'{lo}-{hi}':22}{a:>12}{b:>12}"
                  f"   {pct(a,len(d[us]))} {pct(b,len(d[them]))}")
        for who in (us, them):
            v = sorted(d[who])
            if v:
                print(f"  {who}: n={len(v)} median={v[len(v)//2]:.0f} "
                      f"mean={sum(v)/len(v):.0f}")
        print()

    dist_table("range to nearest live enemy when firing", shot_ranges)
    dist_table("range at which our shots connected (hit events)", hit_ranges)
    dist_table("range at which kills landed", kill_dist)

    print("## endings (phase gameover amount = winning team ordinal)")
    print(dict(endings))
    print()
    print("## first flag steals")
    print(Counter(w for w, _ in first_steal))


if __name__ == "__main__":
    main()
