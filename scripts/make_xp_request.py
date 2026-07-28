#!/usr/bin/env python3
"""Emit an Experience Request body for one arm of an A/B test.

Every knob except the policy under test is fixed here on purpose: the whole
point of an A/B batch is that the candidate and the previous best meet the same
opponents, on the same side, over the same number of episodes, with notes in the
same shape. Vary anything else and the comparison stops meaning anything.

Usage:
  python scripts/make_xp_request.py <policy_ref> <arm-name> [num_episodes] > xp/body.json
"""

import json
import sys

LEAGUE = "league_3243d905-d32d-4ec6-978b-fa94751d4a37"
DIVISION = "div_37361341-2970-4dac-9528-55398bab0d1a"

# Slots alternate red/blue by parity (variant config, slots[]). We take the 8
# red seats and let the division's top-5 champions hold the 8 blue seats.
RED_SLOTS = list(range(0, 16, 2))
BLUE_SLOTS = list(range(1, 16, 2))
OPPONENT_TOP_N = 5


def build(policy_ref: str, arm: str, num_episodes: int = 20) -> dict:
    roster = [{"player": {"policy_ref": policy_ref}, "slot": s} for s in RED_SLOTS]
    roster += [{"player": {"top_n": OPPONENT_TOP_N}, "slot": s} for s in BLUE_SLOTS]
    return {
        "target": {"league_id": LEAGUE, "division_id": DIVISION},
        "roster": roster,
        "num_episodes": num_episodes,
        "notes": (
            f"ctf-ab | arm={arm} | policy={policy_ref} | seats=red-pinned "
            f"| opp=top_n{OPPONENT_TOP_N} | eps={num_episodes}"
        ),
    }


if __name__ == "__main__":
    ref, arm = sys.argv[1], sys.argv[2]
    n = int(sys.argv[3]) if len(sys.argv) > 3 else 20
    print(json.dumps(build(ref, arm, n), indent=2))
