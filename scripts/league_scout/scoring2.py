"""Does the mean round score drive the Elo ladder, and what do OUR draws cost?"""
from collections import defaultdict

import numpy as np

import ctfapi
from index_eps import recent_rounds
from scoring import tally

D = "div_37361341-2970-4dac-9528-55398bab0d1a"
N = 20


def main():
    rs = recent_rounds(N)
    agg = defaultdict(lambda: {"w": 0, "l": 0, "dT": 0, "dW": 0, "failed": 0,
                               "sched": 0, "scores": []})
    exact = [0, 0]
    for r in rs:
        detail = ctfapi.get(f"/v2/rounds/{r['id']}")
        t = tally(r["id"])
        for row in (detail.get("results") or []):
            n = (row.get("player") or {}).get("name")
            md = row.get("result_metadata") or {}
            sched = md.get("episodes_scored") or 0
            c = t.get(n)
            if not c or not sched:
                continue
            a = agg[n]
            for k in ("w", "l", "dT", "dW", "failed"):
                a[k] += c[k]
            a["sched"] += sched
            a["scores"].append(row["score"])
            pred = (c["w"] - c["l"] - c["dT"]) / sched
            exact[0] += 1
            exact[1] += abs(pred - row["score"]) < 1e-9

    print(f"round score == (W - L - dTimeout) / episodes_scored: "
          f"{exact[1]}/{exact[0]} player-rounds exact\n")

    lb = {e["player_name"]: e for e in ctfapi.leaderboard(D, include_recent_rounds=0)}
    rows = []
    for n, a in agg.items():
        if not a["scores"]:
            continue
        rows.append((n, np.mean(a["scores"]), lb.get(n, {}).get("score"),
                     lb.get(n, {}).get("rank"), a))
    rows.sort(key=lambda r: -r[1])

    hdr = (f"{'player':17} {'mean round score':>17} {'Elo':>8} {'Elo rank':>9} "
           f"{'| W':>6} {'L':>5} {'dTimeout':>9} {'dWipe':>6} {'failed':>7} "
           f"{'| draws as %':>13}")
    print(hdr); print("-" * len(hdr))
    for i, (n, ms, elo, rk, a) in enumerate(rows, 1):
        tot = a["w"] + a["l"] + a["dT"] + a["dW"]
        print(f"{n[:17]:17} {ms:>17.4f} {elo if elo else 0:>8.0f} {rk if rk else 0:>9} "
              f"{a['w']:>6} {a['l']:>5} {a['dT']:>9} {a['dW']:>6} {a['failed']:>7} "
              f"{100*a['dT']/max(tot,1):>12.1f}%")

    sr = [r[1] for r in rows]
    el = [r[2] for r in rows if r[2] is not None]
    if len(el) == len(sr):
        print(f"\nSpearman(mean round score, Elo) = "
              f"{np.corrcoef(np.argsort(np.argsort(sr)), np.argsort(np.argsort(el)))[0,1]:.3f}")

    print("\n=== WHAT OUR TIMEOUT DRAWS COST (last "
          f"{len(rs)} rounds) ===")
    a = agg.get("Jordan")
    if a:
        sched = a["sched"]
        actual = (a["w"] - a["l"] - a["dT"]) / sched
        if_win = (a["w"] + a["dT"] - a["l"]) / sched
        if_wipe = (a["w"] - a["l"]) / sched          # a mutual-wipe draw pays 0
        print(f"  actual mean round score              {actual:+.4f}")
        print(f"  if every timeout draw were a WIN     {if_win:+.4f}   "
              f"(+{if_win-actual:.4f})")
        print(f"  if every timeout draw were a mutual-wipe draw (0) {if_wipe:+.4f}   "
              f"(+{if_wipe-actual:.4f})")
        print(f"  timeout draws: {a['dT']} of {a['w']+a['l']+a['dT']+a['dW']} episodes")
        # where does the leaderboard put those scores?
        better = [r[0] for r in rows if r[1] > if_win]
        print(f"  a score of {if_win:+.4f} would sit behind only: "
              f"{', '.join(better) if better else '(nobody — top of the table)'}")


if __name__ == "__main__":
    main()
