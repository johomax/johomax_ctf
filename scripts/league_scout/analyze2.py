"""Deeper pass: how episodes are actually WON, what the shout codes mean,
and what kills us."""
import json
from collections import Counter, defaultdict

import numpy as np

import corpus
from analyze import team_of, advance, PED_X


def win_conditions():
    """capture / wipe / timeout, per winner."""
    by = defaultdict(Counter)
    tot = Counter()
    dur = defaultdict(list)
    for bid in corpus.episode_ids():
        evs, summ = corpus.load_events(bid)
        sp = corpus.seat_player(bid)
        w = corpus.winner(bid)
        caps = [e for e in evs if e["kind"] == "capture"]
        ticks = summ.get("ticks", 0)
        if w is None:
            kind = "draw-timeout" if corpus.draw_kind(bid, summ) == "timeout" else "draw-wipe"
            for n in set(sp.values()):
                by[n][kind] += 1
            tot[kind] += 1
            continue
        # a capture by the winner ends it; otherwise it was a wipe
        wcaps = [e for e in caps if sp.get(e["source"]) == w]
        kind = "capture" if wcaps else "wipe"
        by[w][f"win-{kind}"] += 1
        loser = [n for n in set(sp.values()) if n != w][0]
        by[loser][f"loss-{kind}"] += 1
        tot[f"win-{kind}"] += 1
        dur[f"win-{kind}"].append(ticks)
    return by, tot, dur


def shout_decode():
    """Test the hypothesis that 'E<a> <b>' / 'K<seat><...>' encode positions."""
    hits = {"E": [], "G": []}
    ksamples = []
    for bid in corpus.episode_ids()[:40]:
        meta, F = corpus.load_frames(bid)
        evs, _ = corpus.load_events(bid)
        sp = corpus.seat_player(bid)
        tickidx = {int(t): i for i, t in enumerate(F["tick"])}
        for e in evs:
            if e["kind"] != "shout":
                continue
            c = (e.get("content") or "").strip()
            s = e["source"]
            i = tickidx.get(e["tick"])
            if i is None:
                continue
            if len(c) > 1 and c[0] in "EG" and " " in c[1:]:
                try:
                    a, b = c[1:].split()
                    a, b = int(a), int(b)
                except ValueError:
                    continue
                # candidate: enemy position in some scaled grid
                myteam = team_of(s)
                enemy_seats = [q for q in range(16) if team_of(q) != myteam]
                ex = F["x"][i][enemy_seats].astype(float)
                ey = F["y"][i][enemy_seats].astype(float)
                al = (F["flags"][i][enemy_seats] & 1) > 0
                if not al.any():
                    continue
                # try scale: a*8, b*8 (8px cells) and raw
                for scale, lab in ((8, "x8"), (1, "raw"), (4, "x4")):
                    d = np.hypot(ex - a * scale, ey - b * scale)
                    d = d[al]
                    hits[c[0]].append((lab, float(d.min())))
            if c.startswith("K") and len(c) >= 6:
                ksamples.append((bid, e["tick"], s, c,
                                 int(F["x"][i][s]), int(F["y"][i][s]),
                                 int(F["hp"][i][s]), int(F["aim"][i][s]),
                                 int(F["lives"][i][s])))
    return hits, ksamples


def death_profile():
    """What state are we in when we die, vs the top players."""
    prof = defaultdict(lambda: {"deaths": 0, "shielded": 0, "adv": [], "hp_before": [],
                                "alone": [], "tick": [], "lives_lost_by": []})
    for bid in corpus.episode_ids():
        meta, F = corpus.load_frames(bid)
        evs, _ = corpus.load_events(bid)
        sp = corpus.seat_player(bid)
        tickidx = {int(t): i for i, t in enumerate(F["tick"])}
        for e in evs:
            if e["kind"] != "death":
                continue
            s = e["source"]
            n = sp.get(s)
            if n is None:
                continue
            i = tickidx.get(e["tick"])
            if i is None or i == 0:
                continue
            p = prof[n]
            p["deaths"] += 1
            j = max(0, i - 1)
            if F["flags"][j][s] & 32:
                p["shielded"] += 1
            t = team_of(s)
            p["adv"].append(advance(float(F["x"][j][s]), t))
            p["tick"].append(e["tick"])
            mates = [q for q in range(16) if team_of(q) == t and q != s
                     and (F["flags"][j][q] & 1)]
            if mates:
                d = np.hypot(F["x"][j][mates].astype(float) - float(F["x"][j][s]),
                             F["y"][j][mates].astype(float) - float(F["y"][j][s]))
                p["alone"].append(float(d.min()))
    return prof


def shield_uptake():
    """Fraction of live player-ticks spent holding a shield charge."""
    out = defaultdict(lambda: [0, 0])
    for bid in corpus.episode_ids():
        meta, F = corpus.load_frames(bid)
        sp = corpus.seat_player(bid)
        play = np.where(F["phase"] == 1)[0]
        if not len(play):
            continue
        lo, hi = play[0], play[-1] + 1
        fl = F["flags"][lo:hi]
        alive = (fl & 1) > 0
        shield = (fl & 32) > 0
        for s, n in sp.items():
            out[n][0] += int((shield[:, s] & alive[:, s]).sum())
            out[n][1] += int(alive[:, s].sum())
    return out


if __name__ == "__main__":
    by, tot, dur = win_conditions()
    print("=== HOW EPISODES END (whole corpus) ===")
    for k, v in tot.most_common():
        d = dur.get(k)
        extra = f"  median {np.median(d):.0f} ticks" if d else ""
        print(f"  {k:14} {v:>4}{extra}")

    print(f"\n=== PER PLAYER ===")
    hdr = f"{'player':17} {'win-cap':>8} {'win-wipe':>9} {'loss-cap':>9} {'loss-wipe':>10} {'dTimeout':>9}"
    print(hdr); print("-" * len(hdr))
    order = sorted(by, key=lambda n: -(by[n]["win-capture"] + by[n]["win-wipe"]))
    for n in order:
        c = by[n]
        print(f"{n[:17]:17} {c['win-capture']:>8} {c['win-wipe']:>9} {c['loss-capture']:>9} "
              f"{c['loss-wipe']:>10} {c['draw-timeout']:>9}")

    print("\n=== SHOUT CODE DECODE ===")
    hits, ks = shout_decode()
    for pfx, rows in hits.items():
        if not rows:
            continue
        for lab in ("raw", "x4", "x8"):
            d = [v for l2, v in rows if l2 == lab]
            if d:
                print(f"  '{pfx}<a> <b>' as {lab:>3}: n={len(d):>5} median nearest-enemy "
                      f"distance = {np.median(d):>7.1f}px   (<40px => it IS a position)")
    print("\n  sample 'K......' shouts with the shouter's true state:")
    print(f"  {'code':10} {'x':>5} {'y':>5} {'hp':>3} {'aim':>4} {'lives':>5}")
    for row in ks[:14]:
        _, _, s, c, x, y, hp, aim, lv = row
        print(f"  {c:10} {x:>5} {y:>5} {hp:>3} {aim:>4} {lv:>5}  seat={s}")

    print("\n=== DEATH PROFILE ===")
    prof = death_profile()
    hdr = (f"{'player':17} {'deaths':>7} {'%shielded':>10} {'adv@death':>10} "
           f"{'nearest mate':>13} {'median tick':>12}")
    print(hdr); print("-" * len(hdr))
    su = shield_uptake()
    for n in sorted(prof, key=lambda k: -prof[k]["deaths"]):
        p = prof[n]
        print(f"{n[:17]:17} {p['deaths']:>7} {100*p['shielded']/max(p['deaths'],1):>9.1f}% "
              f"{np.mean(p['adv']):>10.3f} {np.median(p['alone']) if p['alone'] else 0:>13.0f} "
              f"{np.median(p['tick']):>12.0f}")

    print("\n=== SHIELD UPTIME (share of live ticks holding shield hp) ===")
    for n, (a, b) in sorted(su.items(), key=lambda kv: -kv[1][0] / max(kv[1][1], 1)):
        print(f"  {n[:17]:17} {100*a/max(b,1):>6.2f}%")
