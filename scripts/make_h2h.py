#!/usr/bin/env python3
"""Emit an Experience Request putting two of our own builds directly against
each other, one per side of the same episodes.

A fixed opponent list holds the field still, but it cannot hold TIME still:
two arms run hours apart are still two measurements of a moving world, and a
drop between them can be our build getting worse or the world getting better.
A head-to-head cannot be fooled that way. Both builds meet the same opponent
(each other), on the same maps, in the same episodes, at the same moment, so
whatever is drifting drifts for both and cancels.

Sides are not free either: every earlier arm sat on red, so a single-direction
head-to-head would blend "which build is better" with "which side is better".
Run it once each way and pool.

Usage: python scripts/make_h2h.py <red_ref> <blue_ref> <arm> [episodes]
"""
import json, sys

LEAGUE = "league_3243d905-d32d-4ec6-978b-fa94751d4a37"
DIVISION = "div_37361341-2970-4dac-9528-55398bab0d1a"

def build(red, blue, arm, n=40):
    roster  = [{"player": {"policy_ref": red},  "slot": s} for s in range(0, 16, 2)]
    roster += [{"player": {"policy_ref": blue}, "slot": s} for s in range(1, 16, 2)]
    return {
        "target": {"league_id": LEAGUE, "division_id": DIVISION},
        "roster": roster,
        "num_episodes": n,
        "notes": f"ctf-h2h | arm={arm} | red={red} | blue={blue} | eps={n}",
    }

if __name__ == "__main__":
    r, b, arm = sys.argv[1], sys.argv[2], sys.argv[3]
    n = int(sys.argv[4]) if len(sys.argv) > 4 else 40
    print(json.dumps(build(r, b, arm, n), indent=2))
