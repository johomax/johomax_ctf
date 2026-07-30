#!/usr/bin/env python3
"""Emit an Experience Request body for one A/B arm against a FIXED opponent field.

The request format also accepts a `top_n` opponent pool, which asks the league
for its current best. Do not use it once your own policy is in the league: the
pool can then seat your policy opposite your policy, and a mirror is not a
measurement (the score is reported per policy version, so with the same version
on both sides there is no way to say which side it belongs to). Worse, it lands
unevenly -- an arm running the submitted version mirrors constantly while an arm
running an unsubmitted one never does, so two arms stop facing comparable fields.

Naming the opponents removes the question. Every arm then meets the same
policies, in the same seats, and none can be dealt itself.

Name the opponents on the command line; there is no default field, because a
list of "the current top policies" goes stale the moment somebody uploads.
Read the division's standings off the Observatory first and pass what is
actually there.

This measures a policy against the field. It does NOT settle whether one of
your builds beats another -- for that use scripts/run_experiment.py plus
scripts/pool_h2h.py, which put both builds in the same episodes.

Usage:
  python scripts/make_xp_request.py <policy_ref> <arm-name> <eps> <opp_ref>...
"""

import json
import sys

LEAGUE = "league_3243d905-d32d-4ec6-978b-fa94751d4a37"
DIVISION = "div_37361341-2970-4dac-9528-55398bab0d1a"

RED_SLOTS = list(range(0, 16, 2))
BLUE_SLOTS = list(range(1, 16, 2))


def build(policy_ref: str, arm: str, num_episodes: int, opponents: list) -> dict:
    assert opponents, "name at least one opponent policy_ref"
    own = policy_ref.split(":")[0]
    assert not any(o.split(":")[0] == own for o in opponents), (
        "no self in the field: a mirror is not a measurement, because the "
        "score is reported per policy VERSION -- with the same version on "
        "both sides there is no way to say which side it belongs to"
    )
    roster = [{"player": {"policy_ref": policy_ref}, "slot": s} for s in RED_SLOTS]
    roster += [
        {"player": {"policy_ref": opponents[i % len(opponents)]}, "slot": s}
        for i, s in enumerate(BLUE_SLOTS)
    ]
    return {
        "target": {"league_id": LEAGUE, "division_id": DIVISION},
        "roster": roster,
        "num_episodes": num_episodes,
        "notes": (
            f"ctf-ab | arm={arm} | policy={policy_ref} | seats=red-pinned "
            f"| opp=fixed{len(opponents)} | eps={num_episodes}"
        ),
    }


if __name__ == "__main__":
    ref, arm, n, opps = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4:]
    print(json.dumps(build(ref, arm, n, opps), indent=2))
