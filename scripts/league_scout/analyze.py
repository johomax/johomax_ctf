"""Per-player behavioural profile over the extracted corpus.

Seat parity is the team: even seats spawn left (RED), odd spawn right (BLUE).
Every spatial number is folded to "advance toward the enemy" so RED and BLUE
are comparable, and every per-player number is keyed to the player who actually
held the seat (never to an arm name).
"""
import json
from collections import Counter, defaultdict

import numpy as np

import corpus

MAPW = 1235
PED_X = {0: 186, 1: 1049}          # team -> own pedestal x
FWD = {0: +1, 1: -1}               # team -> direction of the enemy


def team_of(seat):
    return seat % 2


def advance(x, team):
    """0 at own pedestal, ~1 at the enemy pedestal."""
    return (x - PED_X[team]) * FWD[team] / abs(PED_X[1] - PED_X[0])


class Agg:
    def __init__(self):
        self.eps = 0
        self.wins = 0
        self.losses = 0
        self.draw_timeout = 0
        self.draw_wipe = 0
        self.shots = 0
        self.hits = 0
        self.kills = 0
        self.team_kills = 0
        self.deaths = 0
        self.dmg_dealt = 0
        self.dmg_taken = 0
        self.steals = 0
        self.captures = 0
        self.carrier_ticks = 0
        self.carrier_deaths = 0
        self.shouts = 0
        self.shout_vocab = Counter()
        self.shouters = set()
        self.pickups = Counter()
        self.grenades = 0
        self.sprays = 0
        self.hit_dists = []
        self.steal_ticks = []
        self.cap_ticks = []
        self.adv_mean = []          # per-episode mean advance across seats
        self.adv_hist = np.zeros(10)
        self.adv_n = 0
        self.max_adv_p50 = []
        self.n_crossers = []        # seats that ever crossed midfield
        self.n_homeguard = []       # seats that never left own third
        self.aim_change = []        # mean |aim delta| per tick
        self.spread = []            # mean pairwise dist between own live seats
        self.first_blood = 0
        self.kill_ticks = []
        self.death_ticks = []


def analyse():
    agg = defaultdict(Agg)
    pair = defaultdict(lambda: defaultdict(int))
    ids = corpus.episode_ids()
    bad = 0
    for bid in ids:
        try:
            meta, F = corpus.load_frames(bid)
            evs, summ = corpus.load_events(bid)
        except Exception:
            bad += 1
            continue
        sp = corpus.seat_player(bid)
        names = sorted(set(sp.values()))
        if len(names) != 2:
            bad += 1
            continue
        w = corpus.winner(bid)
        dk = corpus.draw_kind(bid, summ)
        for nm in names:
            a = agg[nm]
            a.eps += 1
            if w == nm:
                a.wins += 1
            elif w is None:
                if dk == "timeout":
                    a.draw_timeout += 1
                else:
                    a.draw_wipe += 1
            else:
                a.losses += 1

        # ---- events -------------------------------------------------------
        first_kill_done = False
        for e in evs:
            k = e["kind"]
            s = e.get("source", -1)
            t = e.get("target", -1)
            sn = sp.get(s)
            tn = sp.get(t)
            if k == "shot" and sn:
                agg[sn].shots += 1
            elif k == "hit" and sn:
                agg[sn].hits += 1
                if e.get("distance"):
                    agg[sn].hit_dists.append(e["distance"])
            elif k == "kill" and sn:
                if tn == sn:
                    agg[sn].team_kills += 1
                else:
                    agg[sn].kills += 1
                agg[sn].kill_ticks.append(e["tick"])
                if not first_kill_done:
                    agg[sn].first_blood += 1
                    first_kill_done = True
            elif k == "death" and sn:
                agg[sn].deaths += 1
                agg[sn].death_ticks.append(e["tick"])
            elif k == "damage":
                for d in (e.get("damages") or []):
                    vn = sp.get(d.get("slot", -1))
                    if vn:
                        agg[vn].dmg_taken += d.get("amount", 0)
                if sn:
                    agg[sn].dmg_dealt += sum(d.get("amount", 0) for d in (e.get("damages") or []))
            elif k == "flag_steal" and sn:
                agg[sn].steals += 1
                agg[sn].steal_ticks.append(e["tick"])
            elif k == "capture" and sn:
                agg[sn].captures += 1
                agg[sn].cap_ticks.append(e["tick"])
            elif k == "shout" and sn:
                agg[sn].shouts += 1
                agg[sn].shout_vocab[e.get("content", "")] += 1
                agg[sn].shouters.add(s)
            elif k == "item_pickup" and sn:
                agg[sn].pickups[e.get("item", "?")] += 1
            elif k == "grenade_throw" and sn:
                agg[sn].grenades += 1
            elif k == "spray_use" and sn:
                agg[sn].sprays += 1

        # ---- frames -------------------------------------------------------
        play = np.where(F["phase"] == 1)[0]
        if len(play) == 0:
            continue
        lo, hi = play[0], play[-1] + 1
        x = F["x"][lo:hi]
        alive = (F["flags"][lo:hi] & 1) > 0
        aim = F["aim"][lo:hi].astype(np.int16)
        carry = (F["flags"][lo:hi] & 2) > 0
        for nm in names:
            seats = [s for s, n2 in sp.items() if n2 == nm]
            team = team_of(seats[0])
            adv = advance(x[:, seats].astype(np.float64), team)
            live = alive[:, seats]
            a = agg[nm]
            if live.any():
                v = adv[live]
                a.adv_mean.append(float(v.mean()))
                h, _ = np.histogram(np.clip(v, 0, 0.999), bins=10, range=(0, 1))
                a.adv_hist += h
                a.adv_n += h.sum()
                # per-seat furthest advance, median across the 8 seats
                per_seat_max = [adv[live[:, i], i].max() if live[:, i].any() else 0.0
                                for i in range(len(seats))]
                a.max_adv_p50.append(float(np.median(per_seat_max)))
                a.n_crossers.append(int(sum(1 for m in per_seat_max if m > 0.5)))
                a.n_homeguard.append(int(sum(1 for m in per_seat_max if m < 0.34)))
            a.carrier_ticks += int(carry[:, seats].sum())
            # aim churn while alive
            d = np.abs(np.diff(aim[:, seats], axis=0))
            d = np.minimum(d, 256 - d)
            m = live[1:, :]
            if m.any():
                a.aim_change.append(float(d[m].mean()))
            # team spread: mean pairwise distance among live seats, sampled
            step = max(1, (hi - lo) // 200)
            xs = F["x"][lo:hi:step][:, seats].astype(np.float64)
            ys = F["y"][lo:hi:step][:, seats].astype(np.float64)
            lv = live[::step]
            ds = []
            for ti in range(xs.shape[0]):
                idx = np.where(lv[ti])[0]
                if len(idx) < 2:
                    continue
                px, py = xs[ti, idx], ys[ti, idx]
                dd = np.hypot(px[:, None] - px[None, :], py[:, None] - py[None, :])
                ds.append(dd[np.triu_indices(len(idx), 1)].mean())
            if ds:
                a.spread.append(float(np.mean(ds)))
        if w:
            loser = [n2 for n2 in names if n2 != w][0]
            pair[w][loser] += 1
    return agg, pair, bad


def fmt(agg):
    order = sorted(agg, key=lambda n: -(agg[n].wins / max(agg[n].eps, 1)))
    print(f"corpus: {sum(a.eps for a in agg.values()) // 2} episodes\n")
    hdr = (f"{'player':17} {'ep':>4} {'W':>4} {'L':>4} {'dT':>4} {'dW':>4} "
           f"{'acc':>6} {'K/D':>6} {'kills':>6} {'TK':>4} {'steal':>6} {'cap':>5} "
           f"{'cap/st':>7} {'shout':>7} {'nade':>5} {'spray':>6}")
    print(hdr)
    print("-" * len(hdr))
    for n in order:
        a = agg[n]
        acc = a.hits / max(a.shots, 1)
        kd = a.kills / max(a.deaths, 1)
        print(f"{n[:17]:17} {a.eps:>4} {a.wins:>4} {a.losses:>4} {a.draw_timeout:>4} "
              f"{a.draw_wipe:>4} {acc:>6.3f} {kd:>6.2f} {a.kills:>6} {a.team_kills:>4} "
              f"{a.steals:>6} {a.captures:>5} {a.captures/max(a.steals,1):>7.3f} "
              f"{a.shouts/max(a.eps,1):>7.1f} {a.grenades/max(a.eps,1):>5.1f} "
              f"{a.sprays/max(a.eps,1):>6.1f}")

    print("\n=== POSITIONING (advance: 0 = own pedestal, 1 = enemy pedestal) ===")
    hdr2 = (f"{'player':17} {'mean':>7} {'p50max':>7} {'cross>.5':>9} {'home<.34':>9} "
            f"{'spread':>7} {'aimchurn':>9} {'hitdist':>8}")
    print(hdr2)
    print("-" * len(hdr2))
    for n in order:
        a = agg[n]
        mu = np.mean(a.adv_mean) if a.adv_mean else 0
        p50 = np.mean(a.max_adv_p50) if a.max_adv_p50 else 0
        cr = np.mean(a.n_crossers) if a.n_crossers else 0
        hg = np.mean(a.n_homeguard) if a.n_homeguard else 0
        sp = np.mean(a.spread) if a.spread else 0
        ac = np.mean(a.aim_change) if a.aim_change else 0
        hd = np.median(a.hit_dists) if a.hit_dists else 0
        print(f"{n[:17]:17} {mu:>7.3f} {p50:>7.3f} {cr:>9.2f} {hg:>9.2f} "
              f"{sp:>7.0f} {ac:>9.2f} {hd:>8.0f}")

    print("\n=== ADVANCE HISTOGRAM (share of live player-ticks by tenth of the field) ===")
    print(f"{'player':17} " + "".join(f"{i/10:>6.1f}" for i in range(10)))
    for n in order:
        a = agg[n]
        if a.adv_n:
            h = a.adv_hist / a.adv_n
            print(f"{n[:17]:17} " + "".join(f"{v:>6.2f}" for v in h))

    print("\n=== SHOUT VOCABULARY ===")
    for n in order:
        a = agg[n]
        if not a.shouts:
            continue
        top = a.shout_vocab.most_common(12)
        print(f"{n[:17]:17} {a.shouts:>6} shouts, {len(a.shout_vocab):>4} distinct, "
              f"{len(a.shouters)} seats | " + ", ".join(f"{k!r}x{v}" for k, v in top))

    print("\n=== PICKUPS per episode ===")
    for n in order:
        a = agg[n]
        if not a.pickups:
            continue
        tot = ", ".join(f"{k}={v/max(a.eps,1):.2f}" for k, v in a.pickups.most_common())
        print(f"{n[:17]:17} {tot}")


if __name__ == "__main__":
    agg, pair, bad = analyse()
    if bad:
        print(f"[skipped {bad} episodes]\n")
    fmt(agg)
