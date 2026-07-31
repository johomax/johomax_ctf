"""Decode the remaining shout codes, and measure whether the channel is usable:
how many teammates are actually in earshot when a contact call goes out."""
from collections import Counter, defaultdict

import numpy as np

import corpus
from analyze import team_of, advance

SHOUT_RANGE = 1235 // 5  # 247px, RULES.md


def b36(s):
    try:
        return int(s, 36)
    except ValueError:
        return None


def decode_k():
    """K<teamseat><4 chars>: fit what the 4 chars track."""
    rows = []
    for bid in corpus.episode_ids():
        meta, F = corpus.load_frames(bid)
        evs, _ = corpus.load_events(bid)
        sp = corpus.seat_player(bid)
        if "James Boggs" not in sp.values():
            continue
        ti = {int(t): i for i, t in enumerate(F["tick"])}
        for e in evs:
            if e["kind"] != "shout":
                continue
            c = (e.get("content") or "")
            if not c.startswith("K") or len(c) != 6:
                continue
            s = e["source"]
            i = ti.get(e["tick"])
            if i is None:
                continue
            a, b = b36(c[2:4]), b36(c[4:6])
            if a is None or b is None:
                continue
            t = team_of(s)
            enemy = [q for q in range(16) if team_of(q) != t and (F["flags"][i][q] & 1)]
            mate = [q for q in range(16) if team_of(q) == t and q != s and (F["flags"][i][q] & 1)]
            rows.append(dict(seatdigit=c[1], seat=s, a=a, b=b,
                             sx=float(F["x"][i][s]), sy=float(F["y"][i][s]),
                             hp=int(F["hp"][i][s]), lives=int(F["lives"][i][s]),
                             ex=[float(F["x"][i][q]) for q in enemy],
                             ey=[float(F["y"][i][q]) for q in enemy]))
        if len(rows) > 30000:
            break
    return rows


def fit(rows):
    print(f"  n={len(rows)}")
    ok = sum(1 for r in rows if r["seatdigit"] == str(r["seat"] // 2))
    print(f"  digit == seat//2 (team-relative seat): {100*ok/max(len(rows),1):.1f}%")
    for scale in (4, 6, 8, 10, 12, 16):
        ds, de = [], []
        for r in rows[:6000]:
            px, py = r["a"] * scale, r["b"] * scale
            ds.append(np.hypot(px - r["sx"], py - r["sy"]))
            if r["ex"]:
                d = np.hypot(np.array(r["ex"]) - px, np.array(r["ey"]) - py)
                de.append(d.min())
        print(f"  scale x{scale:>2}: median dist to SELF = {np.median(ds):>7.1f}px | "
              f"to nearest ENEMY = {np.median(de) if de else -1:>7.1f}px")


def earshot():
    """When a contact call goes out, how many teammates can hear it?"""
    out = defaultdict(lambda: {"calls": 0, "heard_by": [], "any": 0})
    for bid in corpus.episode_ids():
        meta, F = corpus.load_frames(bid)
        evs, _ = corpus.load_events(bid)
        sp = corpus.seat_player(bid)
        ti = {int(t): i for i, t in enumerate(F["tick"])}
        for e in evs:
            if e["kind"] != "shout":
                continue
            s = e["source"]
            n = sp.get(s)
            if n is None:
                continue
            i = ti.get(e["tick"])
            if i is None:
                continue
            t = team_of(s)
            mates = [q for q in range(16) if team_of(q) == t and q != s
                     and (F["flags"][i][q] & 1)]
            if not mates:
                continue
            d = np.hypot(F["x"][i][mates].astype(float) - float(F["x"][i][s]),
                         F["y"][i][mates].astype(float) - float(F["y"][i][s]))
            k = int((d <= SHOUT_RANGE).sum())
            o = out[n]
            o["calls"] += 1
            o["heard_by"].append(k)
            o["any"] += 1 if k else 0
    return out


def andre_commands():
    """Does the team actually move after 'go' / 'back'?"""
    res = defaultdict(list)
    for bid in corpus.episode_ids():
        meta, F = corpus.load_frames(bid)
        evs, _ = corpus.load_events(bid)
        sp = corpus.seat_player(bid)
        if "Andre von Houck" not in sp.values():
            continue
        ti = {int(t): i for i, t in enumerate(F["tick"])}
        for e in evs:
            if e["kind"] != "shout":
                continue
            n = sp.get(e["source"])
            if n != "Andre von Houck":
                continue
            c = (e.get("content") or "").strip()
            if c not in ("go", "go1", "back", "back1"):
                continue
            i = ti.get(e["tick"])
            if i is None or i + 48 >= len(F["tick"]):
                continue
            s = e["source"]
            t = team_of(s)
            seats = [q for q in range(16) if team_of(q) == t]
            live = (F["flags"][i][seats] & 1) > 0
            if not live.any():
                continue
            a0 = advance(F["x"][i][seats].astype(float), t)[live]
            a1 = advance(F["x"][i + 48][seats].astype(float), t)[live]
            res[c].append(float(a1.mean() - a0.mean()))
    return res


if __name__ == "__main__":
    print("=== 'K' CODE (James Boggs, 514 shouts/episode) ===")
    rows = decode_k()
    fit(rows)

    print("\n=== EARSHOT: teammates within 247px when a shout goes out ===")
    hdr = f"{'player':17} {'calls':>8} {'mean heard-by':>14} {'>=1 teammate':>14}"
    print(hdr); print("-" * len(hdr))
    for n, o in sorted(earshot().items(), key=lambda kv: -kv[1]["calls"]):
        print(f"{n[:17]:17} {o['calls']:>8} {np.mean(o['heard_by']):>14.2f} "
              f"{100*o['any']/max(o['calls'],1):>13.1f}%")

    print("\n=== ANDRE'S COMMAND CHANNEL: team mean advance 48 ticks (2s) after the call ===")
    for c, v in sorted(andre_commands().items()):
        print(f"  {c:>6} n={len(v):>6}  delta advance = {np.mean(v):+.4f}")
