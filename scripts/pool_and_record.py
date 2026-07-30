#!/usr/bin/env python3
"""Pool one experiment's two directions and append a normalised row.

Wraps pool_h2h.py, whose gap sign is oriented by the alphabetical order of the
two build labels rather than by which one is the treatment. That is fine when
a human reads the header line, and a trap when thirteen results are collected
into one table -- "positive favours v29" and "positive favours v41" would sit
in the same column meaning opposite things. This re-orients every gap to
(treatment - control) so the sign always means "the lever helped".

Takes any number of requests, not just two, so several direction-balanced
pairs of the same comparison can be pooled into one higher-powered verdict.

Usage:
  python scripts/pool_and_record.py <name> <treatment_ref> <control_ref> \
      <xreq> [<xreq> ...]
"""

import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
RESULTS = os.path.join(os.path.dirname(HERE), "results")
TSV = os.path.join(RESULTS, "summary.tsv")


def parse(text: str, treat: str, ctrl: str) -> dict:
    m = re.search(r"gaps are \((\S+) - (\S+)\)", text)
    if not m:
        raise SystemExit("could not find the orientation line in pool output")
    x, y = m.group(1), m.group(2)
    treat_tag, ctrl_tag = treat.split(":")[-1], ctrl.split(":")[-1]
    if x.endswith(treat_tag) and y.endswith(ctrl_tag):
        flip = 1.0
    elif x.endswith(ctrl_tag) and y.endswith(treat_tag):
        flip = -1.0
    else:
        raise SystemExit(f"pooled builds {x}/{y} are not {treat}/{ctrl}")

    out = {"pooled": None, "skipped": None}
    m = re.search(r"scored episodes pooled\s*:\s*(\d+)", text)
    if m:
        out["pooled"] = int(m.group(1))
    m = re.search(r"skipped\s*:\s*(\d+)", text)
    if m:
        out["skipped"] = int(m.group(1))

    for key, label in (("kd", "K/D gap"), ("wr", "Win-rate gap"),
                       ("cap", "Capture gap")):
        blk = re.search(
            rf"{re.escape(label)}\n\s*observed\s*:\s*([-+0-9.]+)\n"
            rf"\s*95% CI \(bootstrap\)\s*:\s*\[([-+0-9.]+),\s*([-+0-9.]+)\]",
            text)
        if not blk:
            raise SystemExit(f"could not parse {label}")
        obs, lo, hi = (float(blk.group(i)) for i in (1, 2, 3))
        if flip < 0:
            obs, lo, hi = -obs, -hi, -lo
        out[key] = (obs, lo, hi)
    return out


def verdict(kd, wr, cap) -> str:
    """Summarise across ALL THREE metrics, not just K/D.

    Keying the verdict on K/D alone mislabelled the all-features-minus-ODDS
    bundle as "level": its K/D interval does cross zero, but its win rate
    (-0.263, CI [-0.463, -0.050]) and its captures (-23, CI [-35, -11]) both
    sit entirely below it. The league scores WINS, so a row that reads "level"
    while win rate separates is exactly backwards. Name every metric that
    separates and which way it points.
    """
    def sep(t):
        return "+" if t[1] > 0 else ("-" if t[2] < 0 else None)
    parts = [f"{s}{name}" for name, s in
             (("K/D", sep(kd)), ("win", sep(wr)), ("cap", sep(cap))) if s]
    return "SEPARATES:" + ",".join(parts) if parts else "level"


def main() -> None:
    name, treat, ctrl = sys.argv[1:4]
    xreqs = sys.argv[4:]
    if len(xreqs) < 2:
        raise SystemExit("need at least two requests (one per direction)")
    os.makedirs(RESULTS, exist_ok=True)
    proc = subprocess.run(
        [sys.executable, os.path.join(HERE, "pool_h2h.py"), *xreqs],
        capture_output=True, text=True)
    text = proc.stdout
    with open(os.path.join(RESULTS, f"{name}.txt"), "w") as fh:
        fh.write(text)
        if proc.stderr:
            fh.write("\n--- stderr ---\n" + proc.stderr)
    if proc.returncode != 0:
        print(proc.stdout[-2000:])
        print(proc.stderr[-2000:])
        raise SystemExit(f"pool_h2h failed for {name}")

    r = parse(text, treat, ctrl)
    kd, wr, cap = r["kd"], r["wr"], r["cap"]
    sep = verdict(kd, wr, cap)
    row = (f"{name}\t{treat}\t{ctrl}\t{r['pooled']}\t{r['skipped']}\t"
           f"{kd[0]:+.4f}\t[{kd[1]:+.4f},{kd[2]:+.4f}]\t"
           f"{wr[0]:+.3f}\t[{wr[1]:+.3f},{wr[2]:+.3f}]\t"
           f"{cap[0]:+.0f}\t[{cap[1]:+.0f},{cap[2]:+.0f}]\t{sep}\t"
           + " ".join(xreqs))
    new = not os.path.exists(TSV)
    with open(TSV, "a") as fh:
        if new:
            fh.write("experiment\ttreatment\tcontrol\tpooled\tskipped\t"
                     "kd_gap\tkd_ci\twr_gap\twr_ci\tcap_gap\tcap_ci\t"
                     "verdict\txreqs\n")
        fh.write(row + "\n")
    print(row)
    print(f"\nK/D gap (treatment - control): {kd[0]:+.4f}  "
          f"95% CI [{kd[1]:+.4f}, {kd[2]:+.4f}]  -> {sep}")


if __name__ == "__main__":
    main()
