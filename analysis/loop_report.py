#!/usr/bin/env python3
"""Per-episode replay report for the loop's replay-analyst (stage 2).

Reads one extracted replay (extract_events --frames output) plus the
replay-watcher sidecar, prints a JSON stats block (funnel, carries, deaths,
per-seat activity), and renders PNGs:

    <prefix>-1.png  position heatmaps per entrant, deaths and pedestals
    <prefix>-2.png  kill timeline + carry gantt
    <prefix>-3.png  capture funnel per entrant

Usage:
    python loop_report.py --frames X.frames --events X.jsonl \
        --sidecar X.meta.json --prefix out/obs-...
"""

import argparse
import json
import struct
from collections import defaultdict
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.colors import LinearSegmentedColormap
from matplotlib.patches import Rectangle

REACH_PX = 120.0
DIE_PX = 150.0

# dataviz reference palette, light mode (validated 4 slots, adjacent).
SURFACE = "#fcfcfb"
INK = "#0b0b0b"
INK2 = "#52514e"
MUTED = "#898781"
GRID = "#e1e0d9"
SLOTS = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100",
         "#e87ba4", "#008300", "#4a3aa7", "#e34948"]
DEATH = "#e34948"          # slot-8 red, only used as the death mark
SEQ = ["#fcfcfb", "#cde2fb", "#9ec5f4", "#6da7ec",
       "#3987e5", "#256abf", "#184f95", "#0d366b"]


def read_frames(path):
    b = Path(path).read_bytes()
    magic, slots, mapw, maph, teams = struct.unpack_from("<8sHHHH", b, 0)
    assert magic == b"CTFFRM01", magic
    off = 16
    rec = 6 + slots * 10 + teams * 5
    ticks = []
    while off + rec <= len(b):
        tick, phase, _pad = struct.unpack_from("<IBB", b, off)
        o = off + 6
        seats = []
        for _ in range(slots):
            x, y, _aim, hp, lives, fl, _fw, _wb = struct.unpack_from(
                "<hhBBBBBB", b, o)
            seats.append((float(x), float(y), hp, lives, fl & 1, fl))
            o += 10
        flags = []
        for _ in range(teams):
            x, y, carrier = struct.unpack_from("<hhb", b, o)
            flags.append((float(x), float(y), carrier))
            o += 5
        ticks.append((tick, seats, flags))
        off += rec
    return slots, teams, mapw, maph, ticks


def load(args):
    slots, teams, mapw, maph, ticks = read_frames(args.frames)
    evs = []
    for line in Path(args.events).read_text().splitlines():
        e = json.loads(line)
        if e.get("type") != "summary":
            evs.append(e)
    meta = json.loads(Path(args.sidecar).read_text())

    entrant = {}
    for s in meta.get("our_seats", []):
        entrant[s] = "Jordan"
    for opp in meta.get("opponents", []):
        for s in opp.get("positions", []):
            entrant[s] = opp["player_name"]
    for s in range(slots):
        entrant.setdefault(s, f"seat{s}")
    return slots, teams, mapw, maph, ticks, evs, meta, entrant


def colour_for(names):
    """Stable entrant -> palette slot. Jordan is always slot 1."""
    fixed = {"Jordan": 0, "daveey": 1, "richard": 2, "Andre von Houck": 3}
    out, nxt = {}, 4
    for n in names:
        if n in fixed:
            out[n] = SLOTS[fixed[n]]
        else:
            out[n] = SLOTS[nxt % len(SLOTS)]
            nxt += 1
    return out


def analyse(slots, teams, ticks, evs, entrant):
    team_of = {s: s % teams for s in range(slots)}
    # Trim to the playing window stated by the phase events.
    play = next((e["tick"] for e in evs if e.get("kind") == "phase"
                 and e.get("weapon") == "playing"), None)
    over = next((e["tick"] for e in evs if e.get("kind") == "phase"
                 and e.get("weapon") == "gameover"), None)
    if play is not None:
        ticks = [t for t in ticks if t[0] >= play]
    else:
        start = next((i for i, (_t, s, _f) in enumerate(ticks)
                      if any(seat[4] for seat in s)), 0)
        ticks = ticks[start:]
    if over is not None:
        ticks = [t for t in ticks if t[0] <= over]
    t0 = ticks[0][0]
    last = ticks[-1][0]
    # First tick each team has a living seat: wipes only count after it.
    born = [None] * teams
    for tick, s, _f in ticks:
        for t in range(teams):
            if born[t] is None and any(
                    s[i][4] for i in range(slots) if i % teams == t):
                born[t] = tick
        if all(b is not None for b in born):
            break
    born = [b if b is not None else last + 1 for b in born]
    pedestal = [ticks[0][2][t][:2] for t in range(teams)]

    cap_ticks = [(e["tick"], e["source"]) for e in evs
                 if e.get("kind") == "capture"]

    # Carry intervals from the frames' carrier column.
    intervals = []            # (flag_team, seat, t0, t1, captured, end_xy)
    cur = [None] * teams
    for tick, s, flags in ticks:
        for t in range(teams):
            c = flags[t][2]
            if cur[t] is None and c >= 0:
                cur[t] = (c, tick)
            elif cur[t] is not None and c != cur[t][0]:
                c0, tt0 = cur[t]
                cap = any(abs(ct - tick) <= 2 and cs == c0
                          for ct, cs in cap_ticks)
                intervals.append((t, c0, tt0, tick, cap, flags[t][:2]))
                cur[t] = (c, tick) if c >= 0 else None
    for t in range(teams):
        if cur[t] is not None:
            c0, tt0 = cur[t]
            cap = any(cs == c0 and ct >= tt0 for ct, cs in cap_ticks)
            intervals.append((t, c0, tt0, last, cap, ticks[-1][2][t][:2]))

    # Flag retirement (capture or team wipe) bounds the reach stage.
    retired = [last + 1] * teams
    for t, c0, tt0, tt1, cap, _xy in intervals:
        if cap:
            retired[t] = min(retired[t], tt1)
    for t in range(teams):
        for tick, s, _f in ticks:
            if tick >= retired[t]:
                break
            if tick > born[t] and all(
                    s[i][3] == 0 and not s[i][4]
                    for i in range(slots) if i % teams == t):
                retired[t] = min(retired[t], tick)
                break

    # Deaths from the event stream (frames read (0,0) in the lobby).
    deaths = []               # (tick, seat, x, y, carrying, at_pocket)
    for ev in evs:
        if ev.get("kind") != "death":
            continue
        seat = ev["source"]          # death: source=victim, target=killer
        if seat not in team_of:
            continue
        x, y = ev.get("x", 0.0), ev.get("y", 0.0)
        pocket = any(
            ((x - pedestal[r][0]) ** 2
             + (y - pedestal[r][1]) ** 2) ** 0.5 <= DIE_PX
            for r in range(teams) if r != team_of[seat])
        carrying = any(tt0 <= ev["tick"] <= tt1 and c0 == seat
                       for _t, c0, tt0, tt1, _cap, _xy in intervals)
        deaths.append((ev["tick"], seat, x, y, carrying, pocket))

    # Reach + per-seat movement.
    near = defaultdict(lambda: defaultdict(lambda: 1e18))
    lastpos = [None] * slots
    moved = [0.0] * slots
    alive_ticks = [0] * slots
    still_ticks = [0] * slots
    pos_by_ent = defaultdict(lambda: ([], []))
    for tick, s, flags in ticks:
        for i in range(slots):
            x, y, _hp, _lv, alive, fl = s[i]
            if alive:
                alive_ticks[i] += 1
                pos_by_ent[entrant[i]][0].append(x)
                pos_by_ent[entrant[i]][1].append(y)
                if lastpos[i] is not None:
                    d = ((x - lastpos[i][0]) ** 2
                         + (y - lastpos[i][1]) ** 2) ** 0.5
                    moved[i] += d
                    if d < 0.5:
                        still_ticks[i] += 1
                lastpos[i] = (x, y)
                for r in range(teams):
                    if r != team_of[i] and tick < retired[r]:
                        fx, fy, _ = flags[r]
                        near[entrant[i]][r] = min(
                            near[entrant[i]][r],
                            ((x - fx) ** 2 + (y - fy) ** 2) ** 0.5)

    ents = sorted(set(entrant.values()))
    agg = {e: defaultdict(float) for e in ents}
    for e in ents:
        agg[e]["rivals_seen"] = sum(1 for r in near[e] if near[e][r] < 1e18)
        agg[e]["reached"] = sum(1 for r in near[e] if near[e][r] <= REACH_PX)
    for ev in evs:
        k = ev.get("kind")
        src = entrant.get(ev.get("source", -1))
        tgt = entrant.get(ev.get("target", -1))
        if k == "gun_trigger" and src:
            agg[src]["shots"] += 1
        elif k == "hit" and src:
            agg[src]["hits"] += 1
        elif k == "kill" and src:
            agg[src]["kills"] += 1
            if tgt:
                agg[tgt]["deaths"] += 1
    carries = defaultdict(list)
    for t, c0, tt0, tt1, cap, xy in intervals:
        if team_of.get(c0) == t:
            continue          # own-flag reset
        e = entrant[c0]
        agg[e]["touches"] += 1
        agg[e]["captures"] += int(cap)
        carries[e].append(dict(seat=c0, flag_team=t, t0=tt0, t1=tt1,
                               len=tt1 - tt0, captured=cap,
                               end=[round(v) for v in xy]))
    per_seat = []
    for i in range(slots):
        per_seat.append(dict(
            seat=i, entrant=entrant[i], team=team_of[i],
            alive_ticks=alive_ticks[i], moved_px=round(moved[i]),
            still_frac=round(still_ticks[i] / max(1, alive_ticks[i]), 3)))
    death_rows = [dict(tick=t, seat=s, entrant=entrant[s], x=x, y=y,
                       carrying=c, at_pocket=p)
                  for t, s, x, y, c, p in deaths]
    ending = "capture" if cap_ticks else None
    if ending is None:
        wiped = {t: retired[t] for t in range(teams) if retired[t] <= last}
        ending = f"wipe {wiped}" if wiped else "timeout"
    return dict(t0=t0, last=last, ending=ending, pedestal=pedestal,
                retired=retired,
                agg={e: dict(agg[e]) for e in ents},
                carries={e: carries[e] for e in carries},
                deaths=death_rows, per_seat=per_seat,
                near={e: {r: round(v) for r, v in near[e].items()
                          if v < 1e18} for e in ents},
                cap_ticks=cap_ticks), pos_by_ent, ticks


def fig_style(ax):
    ax.set_facecolor(SURFACE)
    for sp in ax.spines.values():
        sp.set_color(GRID)
    ax.tick_params(colors=MUTED, labelsize=8)
    ax.grid(color=GRID, linewidth=0.5)


def plot_heat(res, pos, mapw, maph, entrant, colours, path, title):
    ents = sorted(pos, key=lambda e: (e != "Jordan", e))
    n = len(ents)
    cols = 2
    rows = (n + 1) // 2
    fig, axes = plt.subplots(rows, cols, figsize=(9, 4 * rows),
                             facecolor=SURFACE, squeeze=False)
    cmap = LinearSegmentedColormap.from_list("seq", SEQ)
    for k, e in enumerate(ents):
        ax = axes[k // cols][k % cols]
        fig_style(ax)
        xs, ys = pos[e]
        ax.hist2d(xs, ys, bins=[max(10, mapw // 24), max(10, maph // 24)],
                  range=[[0, mapw], [0, maph]], cmap=cmap)
        for t, (px, py) in enumerate(res["pedestal"]):
            ax.plot(px, py, marker="*", ms=12, mfc="none", mec=INK, mew=1.2)
            ax.annotate(f"flag t{t}", (px, py), textcoords="offset points",
                        xytext=(5, 5), fontsize=7, color=INK2)
        dx = [d["x"] for d in res["deaths"] if d["entrant"] == e]
        dy = [d["y"] for d in res["deaths"] if d["entrant"] == e]
        ax.plot(dx, dy, "x", color=DEATH, ms=6, mew=1.5, ls="none",
                label=f"deaths ({len(dx)})")
        ax.set_title(e, fontsize=10, color=INK)
        ax.invert_yaxis()
        ax.set_xlim(0, mapw)
        ax.legend(loc="upper right", fontsize=7, framealpha=0.9)
    for k in range(n, rows * cols):
        axes[k // cols][k % cols].axis("off")
    fig.suptitle(title, fontsize=11, color=INK)
    fig.tight_layout()
    fig.savefig(path, dpi=110, facecolor=SURFACE)
    plt.close(fig)


def plot_timeline(res, evs, entrant, colours, path, title):
    fig, (ax1, ax2) = plt.subplots(
        2, 1, figsize=(9, 6), facecolor=SURFACE,
        gridspec_kw={"height_ratios": [2, 1]}, sharex=True)
    fig_style(ax1)
    fig_style(ax2)
    ents = sorted(set(entrant.values()), key=lambda e: (e != "Jordan", e))
    for e in ents:
        ks = sorted(ev["tick"] for ev in evs
                    if ev.get("kind") == "kill"
                    and entrant.get(ev.get("source", -1)) == e)
        xs = [res["t0"]] + ks + [res["last"]]
        ys = list(range(len(ks) + 1)) + [len(ks)]
        ax1.step(xs, [0] + ys[1:], where="post", color=colours[e], lw=2)
        ax1.annotate(f"{e} ({len(ks)})", (xs[-1], ys[-1]),
                     textcoords="offset points", xytext=(4, 0),
                     fontsize=8, color=colours[e], fontweight="bold")
    ax1.set_ylabel("cumulative kills", fontsize=9, color=INK2)
    ax1.set_title(title, fontsize=11, color=INK)
    row = 0
    ylabels = []
    for e in ents:
        for c in res["carries"].get(e, []):
            ax2.add_patch(Rectangle((c["t0"], row - 0.35),
                                    max(c["len"], 8), 0.7,
                                    color=colours[e], lw=0))
            mark = "CAP" if c["captured"] else "lost"
            ax2.annotate(f'{mark} {c["len"]}t', (c["t1"], row),
                         textcoords="offset points", xytext=(4, -3),
                         fontsize=7,
                         color=INK if c["captured"] else INK2)
            ylabels.append((row, f'{e} s{c["seat"]}'))
            row += 1
    for ct, _cs in res["cap_ticks"]:
        ax2.axvline(ct, color=INK, lw=0.8, ls=":")
    ax2.set_ylim(-0.6, max(row - 0.4, 0.6))
    ax2.set_yticks([r for r, _ in ylabels])
    ax2.set_yticklabels([l for _, l in ylabels], fontsize=7)
    ax2.set_xlabel("tick", fontsize=9, color=INK2)
    ax2.set_ylabel("carries", fontsize=9, color=INK2)
    fig.tight_layout()
    fig.savefig(path, dpi=110, facecolor=SURFACE)
    plt.close(fig)


def plot_funnel(res, colours, path, title):
    ents = sorted(res["agg"], key=lambda e: (e != "Jordan", e))
    stages = ["reached", "touches", "captures"]
    fig, ax = plt.subplots(figsize=(7, 4), facecolor=SURFACE)
    fig_style(ax)
    w = 0.8 / max(1, len(ents))
    for j, e in enumerate(ents):
        vals = [res["agg"][e].get(s, 0) for s in stages]
        xs = [i + j * w for i in range(len(stages))]
        ax.bar(xs, vals, width=w * 0.92, color=colours[e], label=e)
        for x, v in zip(xs, vals):
            ax.annotate(f"{v:.0f}", (x, v), ha="center", va="bottom",
                        fontsize=8, color=INK)
    ax.set_xticks([i + w * (len(ents) - 1) / 2 for i in range(len(stages))])
    ax.set_xticklabels(["reached flag (<=120px)", "touches", "captures"],
                       fontsize=9, color=INK2)
    ax.legend(fontsize=8, framealpha=0.9)
    ax.set_title(title, fontsize=11, color=INK)
    fig.tight_layout()
    fig.savefig(path, dpi=110, facecolor=SURFACE)
    plt.close(fig)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--frames", required=True)
    ap.add_argument("--events", required=True)
    ap.add_argument("--sidecar", required=True)
    ap.add_argument("--prefix", required=True)
    ap.add_argument("--no-plots", action="store_true")
    args = ap.parse_args()

    slots, teams, mapw, maph, ticks, evs, meta, entrant = load(args)
    res, pos, ticks = analyse(slots, teams, ticks, evs, entrant)
    colours = colour_for(set(entrant.values()))
    title = (f'{meta.get("variant", "?")}  ep {meta["episode_id"][:8]}  '
             f'our score {meta.get("our_score")}')
    if not args.no_plots:
        plot_heat(res, pos, mapw, maph, entrant, colours,
                  args.prefix + "-1.png", "where each entrant played — " + title)
        plot_timeline(res, evs, entrant, colours,
                      args.prefix + "-2.png", "kills and carries — " + title)
        plot_funnel(res, colours, args.prefix + "-3.png",
                    "capture funnel — " + title)
    out = dict(episode=meta["episode_id"], variant=meta.get("variant"),
               source=meta.get("source"), our_score=meta.get("our_score"),
               slots=slots, teams=teams, map=[mapw, maph], **res)
    print(json.dumps(out, indent=1))


if __name__ == "__main__":
    main()
