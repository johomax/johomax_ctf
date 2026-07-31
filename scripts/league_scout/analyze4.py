"""Focus fire, and our own per-seat role profile vs the design's claim."""
from collections import defaultdict

import numpy as np

import corpus
from analyze import team_of, advance


def focus_fire(window=48):
    """For each kill, how many DISTINCT teammates damaged the victim in the
    preceding `window` ticks (2s)? >1 means the kill was focused."""
    out = defaultdict(list)
    ttk = defaultdict(list)
    for bid in corpus.episode_ids():
        evs, _ = corpus.load_events(bid)
        sp = corpus.seat_player(bid)
        dmg = []  # (tick, attacker_seat, victim_seat)
        for e in evs:
            if e["kind"] == "damage":
                ds = e.get("damages") or []
                if ds:  # multi-victim (grenade / spray) fans out here
                    for d in ds:
                        dmg.append((e["tick"], e.get("source", -1), d.get("slot", -1)))
                else:   # single-victim (gun) carries the victim in `target`
                    dmg.append((e["tick"], e.get("source", -1), e.get("target", -1)))
        by_victim = defaultdict(list)
        for t, a, v in dmg:
            by_victim[v].append((t, a))
        for e in evs:
            if e["kind"] != "death":
                continue
            v = e["source"]
            killer = e.get("target", -1)
            n = sp.get(killer)
            if n is None:
                continue
            t = e["tick"]
            recent = [a for (tt, a) in by_victim.get(v, [])
                      if t - window <= tt <= t and a >= 0 and team_of(a) == team_of(killer)]
            if recent:
                out[n].append(len(set(recent)))
                first = min(tt for (tt, a) in by_victim.get(v, []) if t - window <= tt <= t)
                ttk[n].append(t - first)
    return out, ttk


def seat_profile(player):
    """Per team-relative seat: mean advance, share of live ticks, kills."""
    adv = defaultdict(list)
    for bid in corpus.episode_ids():
        sp = corpus.seat_player(bid)
        if player not in sp.values():
            continue
        meta, F = corpus.load_frames(bid)
        play = np.where(F["phase"] == 1)[0]
        if not len(play):
            continue
        lo, hi = play[0], play[-1] + 1
        seats = sorted(s for s, n in sp.items() if n == player)
        t = team_of(seats[0])
        for k, s in enumerate(seats):
            live = (F["flags"][lo:hi, s] & 1) > 0
            if not live.any():
                continue
            a = advance(F["x"][lo:hi, s].astype(float), t)[live]
            adv[k].append((float(a.mean()), float(a.max())))
    return adv


if __name__ == "__main__":
    print("=== FOCUS FIRE: distinct attackers on a victim in the 2s before it died ===")
    ff, ttk = focus_fire()
    hdr = f"{'player':17} {'kills':>7} {'mean attackers':>15} {'%multi':>8} {'median ticks-to-kill':>21}"
    print(hdr); print("-" * len(hdr))
    for n in sorted(ff, key=lambda k: -np.mean(ff[k])):
        v = ff[n]
        print(f"{n[:17]:17} {len(v):>7} {np.mean(v):>15.2f} "
              f"{100*np.mean([x > 1 for x in v]):>7.1f}% {np.median(ttk[n]):>21.0f}")

    print("\n=== PER-SEAT ROLE PROFILE (team-relative seat 0..7) ===")
    for player in ("Jordan", "James Boggs", "Andre von Houck", "RowDaBoat"):
        prof = seat_profile(player)
        if not prof:
            continue
        print(f"\n  {player}")
        print(f"    {'seat':>5} {'mean adv':>9} {'max adv':>9}")
        for k in sorted(prof):
            m = np.mean([a for a, _ in prof[k]])
            mx = np.mean([b for _, b in prof[k]])
            print(f"    {k:>5} {m:>9.3f} {mx:>9.3f}")
