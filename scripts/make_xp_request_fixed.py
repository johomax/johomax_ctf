#!/usr/bin/env python3
"""Emit an Experience Request body for one A/B arm against a FIXED opponent field.

The top_n form of this request asks the league for its current best, which was
fine while our own policy was not in the league. Once it is, the pool can seat
our policy opposite our policy, and a mirror is not a measurement: the score is
reported per policy version, so with the same version on both sides there is no
way to say which side it belongs to. Worse, it lands unevenly -- an arm running
the submitted version mirrors constantly while an arm running an unsubmitted one
never does, so the two arms stop facing comparable fields.

Naming the opponents removes the question. Both arms then meet the same five
policies, in the same seats, and neither can be dealt itself.

Usage:
  python scripts/make_xp_request_fixed.py <policy_ref> <arm-name> [num_episodes]
"""

import json
import sys

LEAGUE = "league_3243d905-d32d-4ec6-978b-fa94751d4a37"
DIVISION = "div_37361341-2970-4dac-9528-55398bab0d1a"

RED_SLOTS = list(range(0, 16, 2))
BLUE_SLOTS = list(range(1, 16, 2))

# The division's standing field, named explicitly. Anything here must NOT be
# our own policy.
OPPONENTS = [
    "ctf-focusfire:v56",
    "ctf-h050:v1",
    "alphashot-ghost-red-ca3e95f:v1",
    "swarm:v1",
    "Picasso:v26",
]


def build(policy_ref: str, arm: str, num_episodes: int = 40) -> dict:
    assert not any(o.startswith("jordan-") for o in OPPONENTS), "no self in the field"
    roster = [{"player": {"policy_ref": policy_ref}, "slot": s} for s in RED_SLOTS]
    roster += [
        {"player": {"policy_ref": OPPONENTS[i % len(OPPONENTS)]}, "slot": s}
        for i, s in enumerate(BLUE_SLOTS)
    ]
    return {
        "target": {"league_id": LEAGUE, "division_id": DIVISION},
        "roster": roster,
        "num_episodes": num_episodes,
        "notes": (
            f"ctf-ab | arm={arm} | policy={policy_ref} | seats=red-pinned "
            f"| opp=fixed5 | eps={num_episodes}"
        ),
    }


if __name__ == "__main__":
    ref, arm = sys.argv[1], sys.argv[2]
    n = int(sys.argv[3]) if len(sys.argv) > 3 else 40
    print(json.dumps(build(ref, arm, n), indent=2))
