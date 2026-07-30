#!/usr/bin/env python3
"""The experiment catalogue the auto-research loop draws from.

An experiment is a named, single-variable change to `bot/`. Two kinds:

- A **knob**: one constant in `baseline/tuning.nim` moved to a new value. The
  edit is computed against whatever the constant reads in the tree RIGHT NOW,
  not against a value written down here, because a promoted experiment rewrites
  the tree and every value in this file goes stale the moment it lands.
- A **patch**: an explicit list of (find, replace) edits for changes that are
  not a single number. Each `find` must occur exactly once in its file; a
  find-string that matches nothing is treated as a broken experiment and the
  run is abandoned rather than measured. A silently unapplied edit would
  otherwise be measured as "level", which is this repository's most expensive
  recurring failure (see the ButtonC truncation in README.md).

Only ONE variable moves per experiment. Bundling is not a shortcut here: all
twelve levers of the previous session were individually level and the bundle
was -0.184 K/D and -37.5 points of win rate.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field

TUNING = "baseline/tuning.nim"


@dataclass
class Experiment:
    name: str                       # slug: policy tag, arm name, ledger key
    rationale: str                  # why this could plausibly help
    knob: str | None = None         # constant name in TUNING, for knob runs
    value: float | int | None = None   # what to move it to
    edits: list[dict] = field(default_factory=list)  # for patch runs
    parent: str | None = None       # the experiment this was derived from

    @property
    def kind(self) -> str:
        return "knob" if self.knob else "patch"


# --- reading and writing a constant in the tree -----------------------------

# `Name* = 3400` / `Name* = 240.0`, up to the trailing comment. Anchored to the
# start of the line so a mention inside a comment cannot be mistaken for the
# definition.
def _const_re(name: str) -> re.Pattern:
    return re.compile(rf"^(\s*{re.escape(name)}\*?\s*=\s*)([-\d.]+)", re.M)


def read_const(source: str, name: str) -> str:
    """The literal a constant is currently defined as, as written."""
    hits = _const_re(name).findall(source)
    if len(hits) != 1:
        raise ValueError(f"{name}: expected one definition, found {len(hits)}")
    return hits[0][1]


def format_value(current: str, value: float | int) -> str:
    """Render `value` in the same shape the constant already uses.

    Nim will not silently coerce: writing `240` where the type is float is a
    compile error, and writing `240.0` where an int is expected is another.
    Following the literal already in the tree keeps the edit type-correct
    without carrying a type table alongside the values.
    """
    if "." in current:
        return f"{float(value):.1f}" if float(value) == int(float(value)) \
            else f"{float(value)}"
    return str(int(value))


def knob_edit(source: str, name: str, value: float | int) -> dict:
    """The (find, replace) pair that moves one constant, against this tree."""
    current = read_const(source, name)
    if format_value(current, value) == current:
        raise ValueError(f"{name} already reads {current}: nothing to measure")
    m = _const_re(name).search(source)
    assert m is not None
    return {
        "file": TUNING,
        "find": m.group(0),
        "replace": m.group(1) + format_value(current, value),
    }


# --- the seed queue ---------------------------------------------------------
#
# Ordered by (expected information) / (cost), which at a fixed 80 episodes an
# experiment just means expected information. The mechanism of each is read out
# of the source it touches; whether it HELPS is exactly what the run answers,
# so the rationales below are hypotheses and nothing more.

SEED: list[Experiment] = [
    Experiment(
        name="respawnsamples1",
        knob="EnemyRespawnSamples", value=1,
        rationale=(
            "`f590681` replaced the single virtual threat at the enemy "
            "pedestal with three samples down their endzone column, to match "
            "GV25 making the respawn ground a zone rather than a point. The "
            "geometry is right and the routing consequence has never been "
            "measured in either direction: three permanent threats cost more "
            "ground than one, and this repository's one standing finding "
            "about perception is that every intel addition made the bot more "
            "timid and deaths rose. One sample is the pre-GV25 behaviour on "
            "the post-GV25 code path, which asks the timidity question "
            "without reopening the geometry one."
        ),
    ),
    Experiment(
        name="holdline4",
        knob="HoldLineKills", value=4,
        rationale=(
            "The wave holds its own half until six enemy deaths, two players' "
            "worth of lives out of 24. The threshold has never been swept. "
            "Four commits the push a third earlier, which is either a faster "
            "capture clock or a wave that walks into a healthy defence."
        ),
    ),
    Experiment(
        name="latepush3000",
        knob="LatePushTick", value=3000,
        rationale=(
            "Past LatePushTick a draw is the default outcome, so the posts "
            "break and everything commits to the capture. A draw scores as "
            "badly as a loss and the game hard-stops at 5000, so 3400 leaves "
            "1600 ticks of all-in play. Starting 400 ticks earlier buys "
            "another capture attempt at the cost of holding the line longer."
        ),
    ),
    Experiment(
        name="jinkengaged",
        rationale=(
            "The unstick burst is gated `stuckTicks > 20 and engage < 0`, so "
            "while a target is held the burst is disabled and anything that "
            "pins the bot keeps it pinned for the rest of the fight. This is "
            "the second of the two causes of staring contests identified in "
            "the archive and the only one never touched. Letting the burst "
            "fire while engaged after 60 pinned ticks trades a settled aim "
            "for movement, and 60 ticks is long enough that a legitimate "
            "hold-and-shoot never reaches it."
        ),
        edits=[{
            "file": "baseline/act.nim",
            "find": "  if bot.stuckTicks > 20 and f.engage < 0:",
            "replace": ("  if bot.stuckTicks > 20 and "
                        "(f.engage < 0 or bot.stuckTicks > 60):"),
        }],
    ),
    Experiment(
        name="leadticks8",
        knob="LeadTicks", value=8.0,
        rationale=(
            "The aim leads a moving enemy by six ticks to cover the five-tick "
            "windup. That accounts for the windup and nothing for the "
            "traverse the turret still has to make at 5 brads/tick, so the "
            "lead is arguably a tick or two short on anything crossing."
        ),
    ),
    Experiment(
        name="fireslack13",
        knob="FireSlackPx", value=13.0,
        rationale=(
            "The fire gate demands the aim error's perpendicular miss be "
            "inside 11px when the corridor is ~14px wide. That 3px of margin "
            "is bought with shots not taken; at 13 the gate still sits inside "
            "the corridor but the bot shoots sooner in a traverse."
        ),
    ),
    Experiment(
        name="exposedcost10",
        knob="ExposedCost", value=10,
        rationale=(
            "Entering a threat-exposed cell costs 14 against a 5-cost "
            "orthogonal step, so a route will walk almost three cells out of "
            "its way to dodge one watched cell. The archive's standing "
            "finding is that every intel addition made the bot more timid and "
            "deaths rose; loosening the routing penalty tests the same claim "
            "from the other end."
        ),
    ),
    Experiment(
        name="preaimarc28",
        knob="PreAimArc", value=28,
        rationale=(
            "While moving, the pre-aim may not stray more than 20 brads off "
            "the lane, because the vision cone rides the aim and a wide "
            "licence buys a faster swing with blindness to the ground ahead. "
            "The value has never been swept against the cone's 32-brad "
            "half-angle, which is the width that actually bounds the trade."
        ),
    ),
    Experiment(
        name="nadefarm420",
        knob="NadeFarmReach", value=420.0,
        rationale=(
            "Corner grenades refill every 5s and are the densest pickup on "
            "the map by an order of magnitude (~80 a match against ~7 of "
            "everything else), and grenades ignore walls, cover and teams "
            "alike. A flanker will currently detour 340px to arm; the supply "
            "says the detour is cheap."
        ),
    ),
    Experiment(
        name="medkitcrit240",
        knob="MedKitCriticalReach", value=240.0,
        rationale=(
            "At 1 hp a heal outranks the current errand only within 180px. "
            "Two kits sit on the centre line and refill every 30s, and a "
            "one-hit bot is worth a fraction of a full one in every fight it "
            "then takes; 240 lets it break off from further out."
        ),
    ),
    Experiment(
        name="nadefoeping90",
        knob="NadeFoePingTtl", value=90,
        rationale=(
            "A grenade is the only weapon that collects value from a place "
            "rather than a body, and the only one cover does nothing against, "
            "but a spot the sonar heard a fight at stops being a throw target "
            "after 45 ticks. Landings are audible map-wide through walls and "
            "fog, so this is the bot's one map-wide sense and the throw is "
            "its one map-wide answer; 90 ticks is still inside SonarTtl."
        ),
    ),
    Experiment(
        name="nadecarrier",
        rationale=(
            "`planGrenade` refuses to throw while carrying the flag, so the "
            "one player who cannot afford to be caught is the one player "
            "forbidden the weapon that reaches through walls. A carrier being "
            "chased has exactly one job, and a chaser it cannot shoot is "
            "exactly what a grenade is for. `nadeSafe` already vetoes a "
            "landing that would clip us, so the risk this gate was written "
            "against is covered twice; what it really costs is the aim, and "
            "the aim is the carrier's vision."
        ),
        edits=[{
            "file": "baseline/grenades.nim",
            "find": "  if f.carryingNade and not f.iCarry:",
            "replace": "  if f.carryingNade:",
        }],
    ),
    Experiment(
        name="freshshot32",
        knob="FreshShotTicks", value=32,
        rationale=(
            "Only tracks seen within 24 ticks may be fired at. The gun is "
            "map-wide hitscan and the turret traverses at 5 brads/tick, so a "
            "target that fogs out mid-swing is dropped just as the swing "
            "finishes paying for itself. Every gate downstream tests "
            "freshness for itself, so the risk of a wider window is wasted "
            "shots at a place nobody is standing, not a shot into a wall."
        ),
    ),
    Experiment(
        name="shieldflank",
        rationale=(
            "Exactly one seat (MidGuard) will ever pick up a shield, so the "
            "6 hp on offer is taken about 13% of the time. Doubling a body's "
            "health for a 3x slower gun is the most lopsided trade on the "
            "map for anyone whose job is to arrive rather than to shoot, and "
            "the flankers hit the pocket from behind, which is the arriving "
            "job. This is the ambiguous one the archive left unmeasured."
        ),
        edits=[{
            "file": "baseline/objective.nim",
            "find": "bot.role == MidGuard and",
            "replace": "bot.role in {MidGuard, FlankTop} and",
        }],
    ),
    Experiment(
        name="scanarc36",
        knob="ScanArc", value=36,
        rationale=(
            "Held positions sweep 44 brads either side of the watch heading "
            "with a 32-brad cone half-angle, so the sweep overshoots what the "
            "cone covers and the far edge is only ever swept through. A "
            "36-brad sweep re-crosses the covered ground more often, which is "
            "what actually catches a crossing enemy."
        ),
    ),
]


def followups(exp: Experiment, promoted: bool, tree_value: str) -> list[Experiment]:
    """What a finished knob experiment suggests trying next.

    A hill-climb, deliberately shallow: a knob that paid gets pushed the same
    way again (the step that won is rarely the biggest step that wins), and a
    knob that measured as a regression gets tried once in the opposite
    direction, since a wrong sign is evidence about the constant either way.
    A level result suggests nothing -- it is the answer, and spending another
    80 episodes to confirm a null is how the previous session lost a day.

    Patch experiments derive nothing: there is no axis to walk along.
    """
    if exp.kind != "knob" or exp.value is None:
        return []
    base = float(tree_value)
    if promoted:
        step = float(exp.value) - base
        nxt = float(exp.value) + step
        tag = "further"
    else:
        step = base - float(exp.value)
        nxt = base + step
        tag = "reverse"
    if nxt <= 0 or abs(nxt - base) < 1e-9:
        return []
    return [Experiment(
        name=f"{exp.name}-{tag}",
        knob=exp.knob,
        value=int(nxt) if "." not in tree_value else nxt,
        parent=exp.name,
        rationale=(
            f"Derived from {exp.name}: {exp.knob} "
            + (f"paid at {exp.value}, so walk the same way again to {nxt:g} "
               "and find where it stops paying."
               if promoted else
               f"measured worse at {exp.value}, so the constant is worth "
               f"testing in the other direction at {nxt:g}.")
        ),
    )]
