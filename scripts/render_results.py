#!/usr/bin/env python3
"""Render results/summary.tsv into the results table in NOTES-abv2.md.

Replaces everything after the <!-- RESULTS-TABLE --> marker, so it is safe to
re-run as each experiment lands.
"""

import csv
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TSV = os.path.join(ROOT, "results", "summary.tsv")
NOTES = os.path.join(ROOT, "NOTES-abv2.md")
MARKER = "<!-- RESULTS-TABLE -->"

LEVER = {
    "arcraid": "CTF_LEVER_ARCRAID", "aimband": "CTF_FIX_AIMBAND",
    "starebreak": "CTF_FIX_STAREBREAK", "nadeduck": "CTF_LEVER_NADEDUCK",
    "holdline": "CTF_LEVER_HOLDLINE", "hurtlook": "CTF_LEVER_HURTLOOK",
    "crossfire": "CTF_LEVER_CROSSFIRE", "carriershy": "CTF_LEVER_CARRIERSHY",
    "odds": "CTF_LEVER_ODDS", "holdeven": "CTF_LEVER_HOLDEVEN",
    "shoutseen": "CTF_LEVER_SHOUTSEEN", "spawnintel": "CTF_LEVER_SPAWNINTEL",
    "shoutintel": "-d:shoutIntel",
}
ORDER = list(LEVER)


def main() -> None:
    rows = {}
    if os.path.exists(TSV):
        with open(TSV) as fh:
            for r in csv.DictReader(fh, delimiter="\t"):
                rows[r["experiment"]] = r

    out = [MARKER, ""]
    out.append("Gaps are **(treatment − control)**, so a positive number means "
               "the lever helped. A 95% CI that crosses zero is not a result.")
    out.append("")
    out.append("| experiment | vs | n | K/D gap | 95% CI | win-rate gap | "
               "captures gap | verdict |")
    out.append("|---|---|---|---|---|---|---|---|")
    for name in ORDER:
        r = rows.get(name)
        lev = f"`{LEVER[name]}`"
        if not r:
            out.append(f"| {lev} | — | — | — | — | — | — | _not yet run_ |")
            continue
        ctrl = r["control"].split(":")[-1]
        verdict = ("**SEPARATES**" if r["verdict"] == "SEPARATES"
                   else "level (CI crosses zero)")
        n = r["pooled"]
        if r["skipped"] and r["skipped"] != "0":
            n = f"{n} (−{r['skipped']})"
        out.append(
            f"| {lev} | {ctrl} | {n} | {r['kd_gap']} | {r['kd_ci']} | "
            f"{r['wr_gap']} {r['wr_ci']} | {r['cap_gap']} {r['cap_ci']} | "
            f"{verdict} |")
    out.append("")
    # Count only the queued experiments; follow-up runs (e.g. holdevenVsChamp)
    # also live in the TSV but are written up in prose, not this table.
    done = sum(1 for name in ORDER if name in rows)
    out.append(f"_{done} of {len(ORDER)} experiments pooled._ Per-experiment "
               "full pooled output, including the per-direction side split and "
               "every skipped episode, is in `results/<experiment>.txt`; the "
               "request bodies are in `xp-requests/h2h-<experiment>-{a,b}.json`.")
    out.append("")

    text = open(NOTES).read()
    head = text.split(MARKER)[0]
    open(NOTES, "w").write(head + "\n".join(out))
    print(f"rendered {done}/{len(ORDER)} experiments into NOTES-abv2.md")


if __name__ == "__main__":
    main()
