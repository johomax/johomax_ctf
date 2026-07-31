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
    # --- derived from the nadefarm420 result -------------------------------
    #
    # NadeFarmReach 340 -> 420 separated on K/D, win rate AND captures, the
    # only result in this repository where captures have ever separated. The
    # inference is not "grenades are good" -- it is that a DETOUR to arm was
    # underpriced against a resource that refills every five seconds and that
    # cover does nothing against. There are two detour constants and only one
    # of them has been tested.
    Experiment(
        name="nadepickup130",
        knob="NadePickupDetour", value=130.0,
        rationale=(
            "The sibling of the constant that just paid. `NadeFarmReach` "
            "governs the flanker's dedicated trip and moved 340 -> 420 for "
            "+0.064 K/D, +25 points of win rate and +22 captures; "
            "`NadePickupDetour` governs everyone else's opportunistic grab "
            "and still sits at 90. If the dedicated trip was underpriced "
            "against ~80 grenades a match, the opportunistic one is a "
            "stronger candidate still, because it is bought at a fraction of "
            "the tempo."
        ),
    ),
    Experiment(
        name="nadeheld40",
        knob="NadeHeldCost", value=40.0,
        rationale=(
            "px of doubt charged against bombing a target we cannot currently "
            "see. The grenade is the only weapon that collects value from a "
            "remembered position rather than a visible body -- it flies over "
            "every wall and the blast has no wall test -- so this constant "
            "prices the one thing the weapon is uniquely for. 60px of doubt "
            "was set before any grenade result existed; the one that does "
            "exist says the weapon is worth more than the tree assumes."
        ),
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
    # --- added 2026-07-31, after the move to local measurement --------------
    #
    # The standing finding is that DETOURS TO RESOURCES were systematically
    # underpriced: NadeFarmReach paid twice, each step against the champion
    # the last one produced. The entries below push the same generalization
    # through the remaining detour constants and the grenade-evidence prices,
    # one variable each. The last one re-asks a hosted near-miss under the
    # local instrument, whose seed-paired mirrors resolve about half the gap
    # the hosted screen could.
    Experiment(
        name="nadememttl240",
        knob="NadeMemTtl", value=240,
        rationale=(
            "A remembered enemy stays a throw target for 150 ticks. The "
            "grenade is the only weapon that collects value from a memory, "
            "TrackHoldTtl already believes a lost enemy for 400 ticks, and "
            "both grenade promotions said the weapon was underpriced; 240 "
            "keeps bombing positions the tracker still believes in."
        ),
    ),
    Experiment(
        name="nadefoepingcost100",
        knob="NadeFoePingCost", value=100.0,
        rationale=(
            "A heard-landing spot is charged 150px of doubt against a throw, "
            "the largest single price in the grenade scorer. The sonar is the "
            "bot's one map-wide sense and the throw its one map-wide answer; "
            "if grenade evidence has been overpriced everywhere else, the "
            "spot price is the next place the same error would hide."
        ),
    ),
    Experiment(
        name="plasmadetour110",
        knob="PlasmaDetour", value=110.0,
        rationale=(
            "An attacker detours at most 70px for a plasma arc that the "
            "engagement scorer itself values at 70px of threat credit "
            "(ArcThreatBonus), refills in 30s, and triples close-range "
            "lethality. The same detour-underpricing that paid twice on "
            "grenades, on the other weapon pickup."
        ),
    ),
    Experiment(
        name="medkitdetour120",
        knob="MedKitDetour", value=120.0,
        rationale=(
            "The merely-wounded heal detour is 80px. medkitcrit240 tested "
            "the CRITICAL reach and came back level, but a 1hp bot is "
            "already half lost; the wounded case is where a cheap top-up "
            "still converts into fights won, and it has never been moved."
        ),
    ),
    Experiment(
        name="carrierbudget140",
        knob="MedKitCarrierBudget", value=140.0,
        rationale=(
            "A hurt carrier spends at most 90 extra path px to heal, and a "
            "full-heal carrier survives pocket exits that kill a 1hp one. "
            "The flag run is the scoring unit the league actually counts, "
            "so buying carrier survivability is the most direct capture "
            "purchase on the board."
        ),
    ),
    Experiment(
        name="exposedcost10-local",
        knob="ExposedCost", value=10,
        rationale=(
            "Re-ask of exposedcost10 under the local paired instrument. "
            "Hosted at n=240 it leaned positive without separating: K/D "
            "+0.017 [-0.025, +0.060], captures +15 [+0, +31]. That interval "
            "is exactly the shape a real ~0.02 effect leaves at hosted "
            "resolution, and the anti-timidity prior (every intel addition "
            "made the bot more timid and deaths rose) points the same way."
        ),
    ),
    # --- structural pass, 2026-07-31 ----------------------------------------
    #
    # A deep-read ideation pass over the five decision stages and the pinned
    # engine, hunting mechanisms rather than values: gates that cannot fire,
    # stages that fight each other, geometry the field's own weapons punish,
    # and information the bot gives away. Verified engine facts these rest
    # on: a timeout is a SCORELESS LOSE-LOSE DRAW (no kills tiebreak; wins
    # come only from capture or wiping 24 team lives); movement is full-speed
    # while charging a grenade; capture has no own-flag-home precondition.
    # Ranked best-first. combat-strafe and carrier-run-and-gun edit
    # overlapping lines: whichever lands first breaks the other's find
    # string, which the loop reports as ABANDONED rather than measuring a
    # stale edit -- re-derive the survivor against the new tree if so.
    Experiment(
        name="pushout-hold-conflict",
        rationale=(
            "act.nim's hold-line clamp has no pushOut exemption, and holdNow "
            "is true whenever we are behind OR TIED on kills. Past "
            "LatePushTick, pushOut breaks the defensive posts and sends "
            "every seat through the attacker branch -- but the clamp caps "
            "every target 80px past mid, ~350px short of the pocket, so the "
            "all-in can never arrive: defense abandoned, offense forbidden, "
            "and the timeout it drifts into is lose-lose. The field is "
            "largely this lineage carrying the same bug, so fixing it "
            "unilaterally wins the tied endgame race."
        ),
        edits=[{
            "file": "baseline/act.nim",
            "find": "    if bot.killsInit and not f.iCarry and not "
                    "f.ownStolen and holdNow:",
            "replace": "    if bot.killsInit and not f.iCarry and not "
                       "f.ownStolen and not f.pushOut and holdNow:",
        }],
    ),
    Experiment(
        name="combat-strafe",
        rationale=(
            "While engaged, the bot closes dead straight at its target -- "
            "zero crossing motion, zero lead error, the easiest body for "
            "the field's own linear-lead fire gate (largely this lineage: "
            "LeadTicks velocity lead, fire at perpMiss <= 11px). Blend in a "
            "perpendicular strafe flipping every 10 ticks, exactly what the "
            "serpentine already does when unengaged. Information denial in "
            "the one state where the bot currently denies nothing."
        ),
        edits=[{
            "file": "baseline/act.nim",
            "find": "    f.wantFire = perpMiss <= FireSlackPx\n"
                    "    f.moveMask = octantBits(f.aim - f.me)",
            "replace": "    f.wantFire = perpMiss <= FireSlackPx\n"
                       "    let adv = norm(f.aim - f.me)\n"
                       "    var strafe = vec(-adv.y, adv.x)\n"
                       "    if (bot.tick div 10 + bot.slot div 2) mod 2 == 0:\n"
                       "      strafe = strafe * -1.0\n"
                       "    f.moveMask = octantBits(adv + strafe * 0.6)",
        }],
    ),
    Experiment(
        name="nade-charge-on-move",
        rationale=(
            "The grenade charge branch holds the bot STILL for up to 24 "
            "ticks while the server draws our landing-preview ring for "
            "every enemy that can see us: a motionless, telegraphing "
            "target. The engine applies d-pad movement at full speed "
            "regardless of the C bit, and a perpendicular strafe preserves "
            "the throw range the charge was computed from. Grenades are the "
            "tree's most-promoted weapon; the per-throw exposure tax is "
            "paid constantly."
        ),
        edits=[{
            "file": "baseline/act.nim",
            "find": "    f.holdStill = true\n    f.acted = true",
            "replace": "    if bot.nadeCharge > 0:\n"
                       "      let fwd = bradsDir(bot.estAim)\n"
                       "      var strafe = vec(-fwd.y, fwd.x)\n"
                       "      if (bot.tick div 12 + bot.slot div 2) mod 2 == 0:\n"
                       "        strafe = strafe * -1.0\n"
                       "      f.moveMask = octantBits(strafe)\n"
                       "    else:\n"
                       "      f.holdStill = true\n"
                       "    f.acted = true",
        }],
    ),
    Experiment(
        name="carrier-run-and-gun",
        rationale=(
            "When the carrier engages inside CarrierFireRange, the engage "
            "branch overrides its movement to walk TOWARD the attacker -- "
            "abandoning the run home to duel at 70% speed with a gun GV26 "
            "slows 3x for carriers (unmodeled here). Turret and legs ride "
            "separate mask bits: keep the aim and fire, let chooseMovement "
            "keep navigating home. Captures are the scoring unit."
        ),
        edits=[{
            "file": "baseline/act.nim",
            "find": "    f.wantFire = perpMiss <= FireSlackPx\n"
                    "    f.moveMask = octantBits(f.aim - f.me)\n"
                    "    f.acted = true",
            "replace": "    f.wantFire = perpMiss <= FireSlackPx\n"
                       "    if not f.iCarry:\n"
                       "      f.moveMask = octantBits(f.aim - f.me)\n"
                       "      f.acted = true",
        }],
    ),
    Experiment(
        name="thief-hunt-role-split",
        rationale=(
            "On a fresh thief fix every role walks the intercept, "
            "contradicting the design doc ('the back line hunts... "
            "attackers press on'). Fixes refresh in 40-tick pulses, so "
            "distant attackers flap between intercept and pedestal, "
            "draining the wave for chases they never arrive at. Restrict "
            "the walk to the back line; the engage stage still lifts every "
            "role's range cap and applies ThiefFocusBonus, so everyone "
            "with a line still shoots the thief."
        ),
        edits=[{
            "file": "baseline/objective.nim",
            "find": "  elif f.ownStolen and (bot.role == HomeDefender or\n"
                    "      bot.tick - bot.carrierSeen <= ThiefFixTtl):",
            "replace": "  elif f.ownStolen and (bot.role == HomeDefender or\n"
                       "      (bot.role in {Overwatch, MidGuard} and\n"
                       "       bot.tick - bot.carrierSeen <= ThiefFixTtl)):",
        }],
    ),
    Experiment(
        name="preaim-foe-pings",
        rationale=(
            "preAimBearing bonuses only HOT pings -- landings that mark OUR "
            "OWN side's death; the shooter is elsewhere along an unseen "
            "line. A foe ping marks ground an enemy verifiably stood on a "
            "moment ago, which is why the grenade planner throws at foe "
            "pings and not hot ones. The idle gun is currently pulled "
            "toward our own corpses instead of the enemy's last confirmed "
            "position -- the same aim-direction vein where ScanArc paid "
            "+0.16 K/D."
        ),
        edits=[{
            "file": "baseline/tactics.nim",
            "find": "    if s.hot:\n      score -= PreAimHotBonus",
            "replace": "    if s.hot or s.foe:\n      score -= PreAimHotBonus",
        }],
    ),
    Experiment(
        name="escort-screen-unpair",
        rationale=(
            "MidGuard's carrier screen stands 30px from the carrier -- "
            "inside MateSpacing (40), so repulsion fights the objective, "
            "and inside NadeBlast (52), so screen and carrier die to one "
            "grenade. The field's own planGrenade explicitly targets pairs "
            "within one blast; the current geometry manufactures that "
            "target on the body whose death ends the run. 70px sits "
            "outside both while covering more of the bullet corridor."
        ),
        edits=[{
            "file": "baseline/objective.nim",
            "find": "norm(bot.enemies[threat].pos - f.mateCarryPos) * 30.0",
            "replace": "norm(bot.enemies[threat].pos - f.mateCarryPos) * 70.0",
        }],
    ),
    Experiment(
        name="mate-masked-peek",
        rationale=(
            "A fresh clear-ray target whose corridor a teammate occupies "
            "is skipped outright -- it neither engages nor becomes the "
            "peek candidate, so with six attackers in one pocket the "
            "nearest kill is frequently dropped. Recording it as a blocked "
            "candidate makes the peek branch pre-lay the aim and sidestep, "
            "releasing the shot when the corridor clears instead of "
            "re-acquiring from scratch."
        ),
        edits=[{
            "file": "baseline/engage.nim",
            "find": "      if bot.friendlyBlocked(f.me, predicted, d):\n"
                    "        continue                        "
                    "# prefer a target with an empty corridor",
            "replace": "      if bot.friendlyBlocked(f.me, predicted, d):\n"
                       "        if d < f.blockedD:\n"
                       "          f.blockedD = d\n"
                       "          f.blockedAim = predicted\n"
                       "          f.haveBlocked = true\n"
                       "        continue"
                       "                        "
                       "# prefer a target with an empty corridor",
        }],
    ),
    Experiment(
        name="defender-intercept-by-flag",
        rationale=(
            "The HomeDefender breaks off its choke for the intruder "
            "nearest to ITSELF -- classic kiting bait: one attacker drags "
            "it off the choke while a second runs the pocket. Rank "
            "intruders by distance to OUR PEDESTAL instead, so the "
            "defender intercepts whichever body is actually about to "
            "steal. Enemy captures end episodes."
        ),
        edits=[{
            "file": "baseline/objective.nim",
            "find": "      let d = dist(bot.enemies[i].pos, f.me)",
            "replace": "      let d = dist(bot.enemies[i].pos, f.ownHome)",
        }],
    ),
    Experiment(
        name="midguard-shield-not-during-escort",
        rationale=(
            "The MidGuard shield trip vetoes iCarry and the thief chase "
            "but not mateCarry, and it runs AFTER chooseObjective assigned "
            "the carrier screen -- so the moment a mate lifts the flag, "
            "the designated screen walks the wrong way to shop a shield. "
            "The med kit and plasma detours both already veto mateCarry; "
            "this is the one that forgot."
        ),
        edits=[{
            "file": "baseline/objective.nim",
            "find": "  if not f.iCarry and not f.hasShield and "
                    "bot.role == MidGuard and",
            "replace": "  if not f.iCarry and not f.mateCarry and not "
                       "f.hasShield and bot.role == MidGuard and",
        }],
    ),
    Experiment(
        name="wipe-push",
        rationale=(
            "Wins come only from capture or wiping the enemy's 24 lives, "
            "and our kill total says exactly how many they have left. At "
            "kills >= 20 the enemy has at most 4 lives over 8 seats, yet "
            "two posts still hold ground against an attack that can barely "
            "exist. Break the posts and swarm with all eight when the "
            "enemy is four deaths from elimination; mean team kills is "
            "~21.6/episode, so the state is reached in roughly half of "
            "games."
        ),
        edits=[{
            "file": "baseline/objective.nim",
            "find": "    bot.tick - bot.gameStart > LatePushTick\n  )",
            "replace": "    bot.tick - bot.gameStart > LatePushTick or\n"
                       "    (bot.killsInit and bot.kills[bot.team] >= 20)\n"
                       "  )",
        }],
    ),
    # --- batch 3: combat-state information geometry, in knob form ----------
    #
    # Where a mechanism has a natural scalar axis, it is introduced as a new
    # tuning.nim constant plus its one use site, so a win immediately hands
    # the hill-climb a walkable knob -- the shape the three biggest
    # promotions compounded through.
    Experiment(
        name="cooldown-sweep",
        rationale=(
            "During the 12-tick cooldown duck the aim is parked dead on the "
            "threat bearing. The cone half-angle is 32 brads, so wiggling "
            "the aim +-15 brads keeps the threat in view at all times while "
            "raking the cone edge across +-47 -- wider contact warning at "
            "zero cost. The ScanArc trick, applied to the combat-cooldown "
            "state it never touched."
        ),
        edits=[{
            "file": "baseline/tuning.nim",
            "find": "  LaneTop* = 40.0              "
                    "# open corridor above the mirrored obstacles",
            "replace": "  LaneTop* = 40.0              "
                       "# open corridor above the mirrored obstacles\n"
                       "  CooldownSweepArc* = 15       "
                       "# brads of aim wiggle either side of the threat\n"
                       "                              "
                       "# bearing during the cooldown duck; the cone\n"
                       "                              "
                       "# half-angle is 32, so the threat stays in view",
        }, {
            "file": "baseline/act.nim",
            "find": "      f.desiredAim = "
                    "bradsOf(bot.enemies[f.nearThreat].pos - f.me)",
            "replace": "      f.desiredAim = "
                       "floorMod(bradsOf(bot.enemies[f.nearThreat].pos - "
                       "f.me) +\n"
                       "        (if (bot.tick div 6) mod 2 == 0: "
                       "CooldownSweepArc else: -CooldownSweepArc), AimBrads)",
        }],
    ),
    Experiment(
        name="duck-standoff",
        rationale=(
            "The corner-distance principle is already in the tree for PEEK "
            "cells (PeekStandoffCap/Weight, whose comment makes exactly "
            "this argument), but findDuckCell still picks the NEAREST "
            "line-breaking cell -- hugging the corner, where one enemy "
            "step re-opens the line. Mirror the standoff term so ducks go "
            "deeper behind cover within the same search box."
        ),
        edits=[{
            "file": "baseline/tuning.nim",
            "find": "  LaneTop* = 40.0              "
                    "# open corridor above the mirrored obstacles",
            "replace": "  LaneTop* = 40.0              "
                       "# open corridor above the mirrored obstacles\n"
                       "  DuckStandoffWeight* = 0.5    "
                       "# px of extra walking each px of corner standoff\n"
                       "                              "
                       "# is worth when picking a duck cell (peek's copy\n"
                       "                              "
                       "# of the same idea runs 0.9)",
        }, {
            "file": "baseline/navgrid.nim",
            "find": "      let d = dist(p, me)\n      if d >= bestD:",
            "replace": "      let d = dist(p, me) - "
                       "min(dist(p, threat), PeekStandoffCap) * "
                       "DuckStandoffWeight\n      if d >= bestD:",
        }],
    ),
    Experiment(
        name="clock-phased-wave",
        rationale=(
            "Teammates are fogged, so the only sync channels are the "
            "scoreboard (HoldLineKills already uses it) and the SHARED "
            "CLOCK, which nothing uses. While holding the line, release "
            "the clamp for all eight seats simultaneously in periodic "
            "pulses -- every seat computes the same phase from (tick - "
            "gameStart), so the staged attackers surge across mid "
            "together instead of never. Attacks the drift-to-draw failure "
            "that timeout-equals-lose-lose makes expensive."
        ),
        edits=[{
            "file": "baseline/act.nim",
            "find": "      holdNow = bot.kills[bot.team] < HoldLineKills or\n"
                    "        bot.kills[bot.team] <= bot.kills[foeSide]",
            "replace": "      holdNow = (bot.kills[bot.team] < "
                       "HoldLineKills or\n"
                       "        bot.kills[bot.team] <= bot.kills[foeSide]) "
                       "and\n"
                       "        ((bot.tick - bot.gameStart) div 300) "
                       "mod 3 != 2",
        }],
    ),
    Experiment(
        name="corpse-track-cleanup",
        rationale=(
            "When OUR kill registers next to a fresh landing, the enemy "
            "who died there keeps its track for up to 400 ticks -- the bot "
            "ducks from, routes around, and pre-aims at dead men. Delete "
            "the nearest track to a foe-marked landing. This REMOVES "
            "phantom intel, the direction the anti-timidity finding has "
            "paid in every time it was tested."
        ),
        edits=[{
            "file": "baseline/tuning.nim",
            "find": "  LaneTop* = 40.0              "
                    "# open corridor above the mirrored obstacles",
            "replace": "  LaneTop* = 40.0              "
                       "# open corridor above the mirrored obstacles\n"
                       "  CorpseClearRadius* = 80.0    "
                       "# a foe-marked landing wipes the nearest track\n"
                       "                              "
                       "# within this: that enemy is dead and respawning,\n"
                       "                              "
                       "# and a kept track is a phantom to duck from",
        }, {
            "file": "baseline/sense.nim",
            "find": "          bot.sonar[i].foe = true\n          dec want",
            "replace": "          bot.sonar[i].foe = true\n"
                       "          var ci = -1\n"
                       "          var cd = CorpseClearRadius\n"
                       "          for j in 0 ..< bot.enemies.len:\n"
                       "            let dj = dist(bot.enemies[j].pos, "
                       "bot.sonar[i].pos)\n"
                       "            if dj < cd:\n"
                       "              cd = dj\n"
                       "              ci = j\n"
                       "          if ci >= 0:\n"
                       "            bot.enemies[ci] = bot.enemies[^1]\n"
                       "            bot.enemies.setLen(bot.enemies.len - 1)\n"
                       "          dec want",
        }],
    ),
    Experiment(
        name="nade-farm-not-during-thief-chase",
        rationale=(
            "During a live thief fix -- the one state the code says "
            "outranks everything -- the grenade branch still rewrites the "
            "intercept into a detour of up to NadeFarmReach (500px!) to "
            "shop a corner grenade while the enemy runs our flag home. "
            "The med kit and shield branches both veto the thief chase; "
            "the grenade branch never got the veto and the farm "
            "promotions silently widened the hole."
        ),
        edits=[{
            "file": "baseline/objective.nim",
            "find": "  if not f.carryingNade and not f.iCarry and not "
                    "f.mateCarry and not f.pocketRush:",
            "replace": "  if not f.carryingNade and not f.iCarry and not "
                       "f.mateCarry and\n      not f.pocketRush and\n"
                       "      not (f.ownStolen and bot.tick - "
                       "bot.carrierSeen <= ThiefFixTtl):",
        }],
    ),
    # --- one-way fog vision, 2026-07-31 -------------------------------------
    #
    # The engine fogs entities by a recursive shadowcast over quantized 8px
    # cells, and quantized shadowcasting is not reciprocal: some standable
    # cell pairs are ONE-WAY visible -- A sees B while B can never see A
    # whatever it aims. The fog rule is deterministic from the walkability
    # mask the bot already receives at init, so baseline/fov.nim rebuilds the
    # engine's occlusion model client-side (verified cell-for-cell against
    # the engine's own buildFovBlocked, and against computeFovVisible at 16
    # origins) and scanPost prices each candidate peek by how many enemy
    # approach-band cells it sees one-way with a clear bullet ray, excluding
    # any sightline the spinning center diamonds ever sweep. The plumbing is
    # inert at OneWayBonus 0.0 (identical gameHash, seeds 5000-5005) and
    # reaches behavior at any value past ~9 (all six hashes diverge at 300).
    Experiment(
        name="onewaybonus40",
        knob="OneWayBonus", value=40.0,
        rationale=(
            "A post on the seeing end of a one-way pair over an enemy lane "
            "gets shots the victim cannot answer with vision -- the closest "
            "thing to a free kill the fog model offers, and the current "
            "scorer prices it at zero. The table is real and asymmetric on "
            "the arena: 6 of 52 red candidates and 5 of 50 blue hold such "
            "cells (13 and 16 clear-ray pairs), the sides do not mirror, "
            "and at any bonus past ~9 both sides trade 8.4px of base score "
            "for a peek holding one more (red 2 to 3) or three more (blue "
            "3 to 6) one-way cells. 40px per cell prices one unanswerable "
            "sightline like ~57px of extra firing line (the line trades at "
            "0.7) and half a PeekStandoffCap of safety credit, so a couple "
            "of cells can move the post between near-tied peeks but cannot "
            "outbid a genuinely longer lane. Nav-build cost at the test "
            "value measured +3 percent of an episode; zero at 0.0."
        ),
    ),

    # --- batch 5: verified proposals from the ideation workflow -------------
    #
    # Mined by eight parallel deep-reads of the source, the backlog and the
    # ledger, then each one adversarially verified against the tree: the
    # mechanism re-read at source, every find-string counted (exactly one
    # match), the knob values checked against every value already recorded
    # in state.json. One proposal (a second TrackHoldTtl draft) was killed
    # by that pass and one had its rationale rewritten -- see trackhold200.

    Experiment(
        name="diamond-sweep-paint",
        edits=[
            {"file": "baseline/tuning.nim",
             "find": '  NavCell* = 8                 # nav grid cell size in px',
             "replace": "  NavCell* = 8                 # nav grid cell size in px\n  SpinPaintScale* = 1.0        # fraction of a spinning center diamond's\n                              # radius painted as wall into our walkability\n                              # copy at nav-grid build. 0.0 keeps the frozen\n                              # snapshot frame; 1.0 is the swept disc the\n                              # turn can ever cover (the engine's spinSwept);\n                              # ~0.71 would paint only what is stone at EVERY\n                              # frame (spinAlways). Past 1.0 the paint escapes\n                              # the disc fov.nim erases and would move the\n                              # one-way fog table too"},
            {"file": "baseline/navgrid.nim",
             "find": 'import\n  bitworld/profile,\n  protocols,\n  posts,\n  grid,\n  world,\n  geometry,\n  tuning',
             "replace": 'import\n  bitworld/profile,\n  protocols,\n  posts,\n  fov,\n  grid,\n  world,\n  geometry,\n  tuning'},
            {"file": "baseline/navgrid.nim",
             "find": 'proc buildNavGrid*(bot: Bot, client: ProtocolClient) {.measure.} =\n  ## Erodes the pixel walkability mask into a footprint-safe nav grid, then\n  ## derives the cover model (cover cells, overwatch post, defender choke).\n  adoptMapSize(client)',
             "replace": "proc paintSpinDiscs(client: ProtocolClient) =\n  ## The eight spinning center diamonds are LIVE geometry (fov.nim): the\n  ## bake leaves them out and the engine restamps their rotated footprint\n  ## into the movement, bullet and vision masks every time the spin frame\n  ## advances, while the walkability sprite is sent ONCE -- so our mask\n  ## holds one frozen frame of a shape that keeps turning. Paint each\n  ## diamond's swept disc into our copy: the rotated L1 footprint never\n  ## leaves the L2 disc of its own radius, so this only ever ADDS wall and\n  ## the model becomes conservative rather than wrong -- no clear line, and\n  ## no cover, through ground the stone is about to swing back into.\n  ##\n  ## fov.nim's occlusion build erases exactly this disc, so at scale <= 1.0\n  ## the one-way fog table is untouched. A no-op on any map but the arena,\n  ## for which alone spinDiamonds() vendors geometry.\n  if SpinPaintScale <= 0.0:\n    return\n  let\n    w = client.walkabilityWidth\n    h = client.walkabilityHeight\n  for d in spinDiamonds():\n    let\n      r = int(float(d.r) * SpinPaintScale)\n      r2 = r * r\n    for py in max(0, d.cy - r) .. min(h - 1, d.cy + r):\n      for px in max(0, d.cx - r) .. min(w - 1, d.cx + r):\n        let\n          dx = px - d.cx\n          dy = py - d.cy\n        if dx * dx + dy * dy <= r2:\n          client.walkabilityMask[py * w + px] = false\n\nproc buildNavGrid*(bot: Bot, client: ProtocolClient) {.measure.} =\n  ## Erodes the pixel walkability mask into a footprint-safe nav grid, then\n  ## derives the cover model (cover cells, overwatch post, defender choke).\n  adoptMapSize(client)\n  paintSpinDiscs(client)"},
        ],
        rationale=(
            "`engage.nim:106` gates every shot on `client.pixelRayClear(f.me, "
            "predicted)`, and `grid.nim:24` answers that ray out of "
            "`client.walkabilityMask` \u2014 one walkability sprite, built once "
            "per seat at connect and never resent, holding ONE frame of eight "
            "diamonds the engine restamps into its movement/bullet/vision "
            "masks every 4 ticks. So today the bot fires, paths, ducks and "
            "picks cover posts through mid against a frozen silhouette: "
            "phantom-clear shots into stone that swung back, phantom cover "
            "behind stone that swung away. This paints each diamond's swept "
            "disc (radius 30, the union over the turn \u2014 the rotated L1 "
            "footprint never leaves it) into the mask at `buildNavGrid`, "
            "before the footprint erosion, so rays, `cellWalkable`, "
            "`coverCell` and exposure all read stone wherever stone can be. "
            "It only ever ADDS wall, and `fov.nim`'s occlusion build already "
            "erases exactly this disc, so the one-way fog table does not "
            "move. Hypothesis, not a result: the conservative model may cost "
            "more real openings than the false ones it removes."
        ),
    ),
    Experiment(
        name="chokehold-oneway",
        edits=[
            {"file": "baseline/posts.nim",
             "find": 'proc pickPost*(bot: Bot, client: ProtocolClient) =\n',
             "replace": "proc pickChoke*(bot: Bot, client: ProtocolClient): Vec =\n  ## The defender's hold point, priced with the same one-way term scanPost\n  ## gives an overwatch peek. The scan runs on `homeSign` — the mirrored\n  ## direction findEnemyPosts already scores — because that is the way the\n  ## defender's own guns point: its target band is the ground an intruder\n  ## crosses toward our pedestal. Candidates are exactly snapToCover's (the\n  ## cover cells of the same 6-cell box), so only the score changes. Only\n  ## the HomeDefender seat ever reads chokeHold, so no other seat pays the\n  ## scan.\n  let p = chokeSpot(bot.team)\n  if bot.role != HomeDefender or OneWayBonus == 0.0 or not oneWayFogReady():\n    return bot.snapToCover(p)\n  result = p\n  let\n    c0 = bot.nearestOpenCell(cellOf(p))\n    cx = c0 mod GridW\n    cy = c0 div GridW\n  var\n    bestScore = 1e18\n    oneWay = bot.newOneWayScan(client, homeSign(bot.team))\n  for dy in -6 .. 6:\n    for dx in -6 .. 6:\n      let\n        nx = cx + dx\n        ny = cy + dy\n      if nx < 0 or ny < 0 or nx >= GridW or ny >= GridH:\n        continue\n      let nc = ny * GridW + nx\n      if not bot.coverCell[nc]:\n        continue\n      let q = cellCenter(nc)\n      let score = dist(q, p) -\n        float(oneWay.oneWayCount(client, nc, q)) * OneWayBonus\n      if score < bestScore:\n        bestScore = score\n        result = q\n\nproc pickPost*(bot: Bot, client: ProtocolClient) =\n"},
            {"file": "baseline/navgrid.nim",
             "find": '  bot.chokeHold = bot.snapToCover(chokeSpot(bot.team))\n',
             "replace": '  bot.chokeHold = bot.pickChoke(client)\n'},
        ],
        rationale=(
            "navgrid.nim:120 sets the defender's hold point as `bot.chokeHold "
            "= bot.snapToCover(chokeSpot(bot.team))` \u2014 nearest cover cell in "
            "a 6-cell box, scored on distance alone. This is the second "
            "customer the one-way plan named and never wired: OneWayBonus=40 "
            "is promoted but pays only inside scanPost, and HomeDefender is "
            "the seat that camps longest on one cell. The patch scores the "
            "SAME candidate set with the SAME term (posts.nim's "
            "newOneWayScan/oneWayCount), no new constant and no second "
            "mechanism, on eSign = homeSign(bot.team) \u2014 the direction "
            "findEnemyPosts already scans, whose target band is the ground an "
            "intruder crosses toward our pedestal. The defender would then "
            "prefer a choke cell that sees that approach one-way over one "
            "that merely sits nearest. Hypothesis only: the box caps "
            "displacement at ~147px, and the extra scan costs nav-build time "
            "on one seat of eight."
        ),
    ),
    Experiment(
        name="peek-friendly-corridor",
        edits=[
            {"file": "baseline/tuning.nim",
             "find": '  PeekStandoffWeight* = 0.9    # px of extra walking each px of it is worth\n',
             "replace": '  PeekStandoffWeight* = 0.9    # px of extra walking each px of it is worth\n  PeekMateCorridorCost* = 140.0\n                              # px of effective extra walking charged to a\n                              # peek cell that opens the WALL ray but leaves\n                              # a remembered mate in the bullet corridor: the\n                              # shot it buys is one friendlyBlocked refuses.\n                              # The stand-off term can move a score by at\n                              # most PeekStandoffCap * PeekStandoffWeight\n                              # (86.4), so this outranks it\n'},
            {"file": "baseline/navgrid.nim",
             "find": '      let d = dist(p, me) -\n        min(dist(p, corner), PeekStandoffCap) * PeekStandoffWeight\n      if d >= bestD:\n        continue\n      if not bot.gridRayClear(me, p):\n        continue\n      if not client.pixelRayClear(p, aim):\n        continue\n      bestD = d\n',
             "replace": '      let base = dist(p, me) -\n        min(dist(p, corner), PeekStandoffCap) * PeekStandoffWeight\n      if base >= bestD:\n        continue\n      if not bot.gridRayClear(me, p):\n        continue\n      if not client.pixelRayClear(p, aim):\n        continue\n      # The wall ray is only half of the firing line. A cell that opens it\n      # but leaves a remembered mate inside the bullet corridor buys a shot\n      # the fire gate will refuse -- the bullet is a corridor hitscan and\n      # the server kills the NEAREST body in it -- so that peek spends the\n      # exposure and returns no shot at all. Charge it, and the sidestep\n      # prefers a cell whose FRIENDLY line is clear as well. Spelled like\n      # tactics.friendlyBlocked, which sits one layer above this file and\n      # so cannot be called from here.\n      var d = base\n      let\n        aimD = dist(p, aim)\n        fireDir = bradsDir(bradsOf(aim - p))\n      for m in bot.mates:\n        let\n          age = float(bot.tick - m.lastSeen)\n          rel = m.pos - p\n          along = dot(rel, fireDir)\n        if age <= 36.0 and along > 0.0 and along < aimD + 14.0 and\n            abs(cross(rel, fireDir)) < CorridorHalfWidth + age * 0.35:\n          d = base + PeekMateCorridorCost\n          break\n      if d >= bestD:\n        continue\n      bestD = d\n'},
        ],
        rationale=(
            "act.nim's peek branch calls `bot.findPeekCell(client, f.me, "
            "f.blockedAim)` and steps to whatever cell it returns. That "
            "scoring loop tests exactly two rays -- `gridRayClear(me, p)` and "
            "`pixelRayClear(p, aim)` -- and neither knows a teammate exists, "
            "so the sidestep can land on a cell whose bullet corridor a mate "
            "occupies. Next tick the wall ray is open, engage.nim's "
            "`friendlyBlocked` gate hits and does `continue`, dropping the "
            "target entirely: the peek has bought exposure in the open and no "
            "shot. This charges PeekMateCorridorCost to any candidate whose "
            "FRIENDLY corridor a remembered mate sits in, inside the same "
            "search box and scoring loop, so the search prefers a cell where "
            "the shot will actually be taken. It is a preference, not a veto "
            "-- with no clear cell the peek still happens. Hypothesis: six "
            "attackers in one pocket should make masked lines common, but "
            "nothing measures how often the chosen peek cell is one."
        ),
    ),
    Experiment(
        name="peek-friendly-corridor-reask",
        parent="peek-friendly-corridor",
        edits=[
            {"file": "baseline/tuning.nim",
             "find": '  PeekStandoffWeight* = 0.9    # px of extra walking each px of it is worth\n',
             "replace": '  PeekStandoffWeight* = 0.9    # px of extra walking each px of it is worth\n  PeekMateCorridorCost* = 140.0\n                              # px of effective extra walking charged to a\n                              # peek cell that opens the WALL ray but leaves\n                              # a remembered mate in the bullet corridor: the\n                              # shot it buys is one friendlyBlocked refuses.\n                              # The stand-off term can move a score by at\n                              # most PeekStandoffCap * PeekStandoffWeight\n                              # (86.4), so this outranks it\n'},
            {"file": "baseline/navgrid.nim",
             "find": '      let d = dist(p, me) -\n        min(dist(p, corner), PeekStandoffCap) * PeekStandoffWeight\n      if d >= bestD:\n        continue\n      if not bot.gridRayClear(me, p):\n        continue\n      if not client.pixelRayClear(p, aim):\n        continue\n      bestD = d\n',
             "replace": '      let base = dist(p, me) -\n        min(dist(p, corner), PeekStandoffCap) * PeekStandoffWeight\n      if base >= bestD:\n        continue\n      if not bot.gridRayClear(me, p):\n        continue\n      if not client.pixelRayClear(p, aim):\n        continue\n      # The wall ray is only half of the firing line. A cell that opens it\n      # but leaves a remembered mate inside the bullet corridor buys a shot\n      # the fire gate will refuse -- the bullet is a corridor hitscan and\n      # the server kills the NEAREST body in it -- so that peek spends the\n      # exposure and returns no shot at all. Charge it, and the sidestep\n      # prefers a cell whose FRIENDLY line is clear as well. Spelled like\n      # tactics.friendlyBlocked, which sits one layer above this file and\n      # so cannot be called from here.\n      var d = base\n      let\n        aimD = dist(p, aim)\n        fireDir = bradsDir(bradsOf(aim - p))\n      for m in bot.mates:\n        let\n          age = float(bot.tick - m.lastSeen)\n          rel = m.pos - p\n          along = dot(rel, fireDir)\n        if age <= 36.0 and along > 0.0 and along < aimD + 14.0 and\n            abs(cross(rel, fireDir)) < CorridorHalfWidth + age * 0.35:\n          d = base + PeekMateCorridorCost\n          break\n      if d >= bestD:\n        continue\n      bestD = d\n'},
        ],
        rationale=(
            "A RE-ASK, not a new idea: peek-friendly-corridor was measured on "
            "2026-07-31 and thrown away by a decision-rule defect rather than "
            "by its numbers. It screened K/D +0.0413 CI [-0.0062, +0.0907] -- "
            "z = 1.67, twice the escalation threshold, missing zero by 0.006 "
            "-- with captures SEPARATING positive at +19 CI [+6, +32]. It was "
            "rejected because the near-miss gate demanded both metrics be "
            "non-negative and win rate read -0.008, a twentieth of its own "
            "noise (CI +-0.16). The gate now tolerates half a standard error "
            "(NEAR_MISS_TOLERANCE), so this buys the confirmation README.md "
            "always said it should. The generation counter has advanced, so "
            "it draws a DISJOINT seed batch: this is an independent sample, "
            "not a re-count of the same episodes. Underlying mechanism "
            "unchanged -- findPeekCell scores wall rays only, so teach it to "
            "prefer cells whose FRIENDLY firing corridor also clears."
        ),
    ),
    Experiment(
        name="scanarcblue32",
        knob="ScanArcBlue", value=32,
        rationale=(
            "ScanArc is the knob that paid TWICE on this policy (24 -> 28 -> "
            "36, +0.16 K/D between them), which makes it the right first axis "
            "to split by side. The plumbing landed inert in a direct commit "
            "-- 12 seeds, 24 episodes, every mirrored pair bit-identical on "
            "gameHash -- because the loop structurally cannot land an inert "
            "patch: apply_edits works on a scratch copy, land() runs only "
            "from promote(), and a no-op measures level and is discarded. "
            "Blue is the side whose sweep this moves; the other keeps 28. "
            "Read the DILUTION honestly: a seed-paired mirror puts the "
            "treatment build on blue in only ONE of the two directions, so "
            "the pooled gap is about HALF the true one-side effect -- DOUBLE "
            "it to read it. Power does NOT halve with it: pairs the knob "
            "never fires in come back bit-identical and add zero variance, "
            "so the paired interval collapses too (scanarcblue32 ran +-0.0136 "
            "at n=120, three times tighter than a shared knob at the same n). "
            "See the per-side note in LEDGER.md. Blue is also the side the operator's brief "
            "says concedes the fog and nav seams by construction, so it is "
            "the side with more to gain from a wider sweep."
        ),
    ),
    Experiment(
        name="scanarcred32",
        knob="ScanArcRed", value=32,
        rationale=(
            "ScanArc is the knob that paid TWICE on this policy (24 -> 28 -> "
            "36, +0.16 K/D between them), which makes it the right first axis "
            "to split by side. The plumbing landed inert in a direct commit "
            "-- 12 seeds, 24 episodes, every mirrored pair bit-identical on "
            "gameHash -- because the loop structurally cannot land an inert "
            "patch: apply_edits works on a scratch copy, land() runs only "
            "from promote(), and a no-op measures level and is discarded. Red "
            "is the side whose sweep this moves; the other keeps 28. Read the "
            "DILUTION honestly: a seed-paired mirror puts the treatment build "
            "on red in only ONE of the two directions, so the pooled gap is "
            "about HALF the true one-side effect and this needs roughly four "
            "times the episodes of a shared knob for equal power. A level "
            "result here is therefore weak evidence of no effect, not strong. "
            "Red wins ~63% of episodes whatever build holds it, so red's "
            "optimum need not be blue's: the side that is already ahead may "
            "want the sweep spent differently."
        ),
    ),
    Experiment(
        name="stale-matecarry-fix",
        edits=[
            {"file": "baseline/sense.nim",
             "find": '  if enemyPlanted:\n    discard                              # enemy flag sits home: nobody carries',
             "replace": '  if enemyPlanted:\n    # Nobody is carrying it, so any carry fix we hold is dead intel: pin it\n    # to the pedestal and restamp the clock, so the dead-reckon below starts\n    # from where the flag actually is on the tick it is next lifted.\n    bot.mateFixPos = f.stealTarget\n    bot.mateFixTick = bot.tick'},
        ],
        rationale=(
            "readFlagState's last branch fires whenever a mate carries the "
            "enemy flag outside our cone, and it dead-reckons that carrier "
            "from bot.mateFixPos advanced homeward by `elapsed = bot.tick - "
            "max(bot.mateFixTick, bot.gameStart)`. Neither field is "
            "invalidated when the flag returns to its pedestal. With no "
            "banner sighting this game mateFixTick is 0, so elapsed is the "
            "whole game and the min() clamp parks the phantom carrier on OUR "
            "OWN pedestal from the first frame of any steal past ~860 ticks "
            "(pedestal separation is 863px at CarrierEstSpeed 1.0); with a "
            "fix left over from an earlier failed steal it starts stale and "
            "runs just as far. Six seats escort that point. Pinning the fix "
            "to the pedestal and restamping the clock while the flag is "
            "planted makes elapsed mean \"ticks since the flag was lifted\", "
            "which is what the comment already claims. Hypothesis: the escort "
            "wave stops walking home to guard nobody."
        ),
    ),
    Experiment(
        name="preaim-track-ttl-live",
        edits=[
            {"file": "baseline/tactics.nim",
             "find": '    maxRange = PreAimRange, maxAge = PreAimPingTtl): int =',
             "replace": '    maxRange = PreAimRange, maxAge = PreAimTrackTtl): int ='},
        ],
        rationale=(
            "`preAimBearing` defaults `maxAge = PreAimPingTtl` (60) and then "
            "gates remembered enemies on `min(PreAimTrackTtl, maxAge)`, so "
            "PreAimTrackTtl (90) can never bind: its only two callers are the "
            "keeper's watch (explicit PreAimWatchTtl, 30) and the cruising "
            "pre-aim (the default, 60). A constant whose own comment reads 'a "
            "remembered enemy this fresh still points' is inert, and asking "
            "it as a knob would measure exactly level -- the EscortScreenDist "
            "shape. Changing the default to PreAimTrackTtl leaves the ping "
            "loop untouched (it already mins against PreAimPingTtl) and the "
            "keeper untouched (it passes 30), so the one thing that moves is "
            "the cruising pre-aim's track window, 60 -> 90. Hypothesis only: "
            "aim-direction is the vein where ScanArc paid twice, couldTrade "
            "still vetoes tracks no shot could reach, and PreAimAgePx charges "
            "1.2px of doubt per tick, so an old track only wins when nothing "
            "better exists."
        ),
    ),
    Experiment(
        name="defender-stale-intruder",
        edits=[
            {"file": "baseline/tuning.nim",
             "find": '  ThiefFixTtl* = 40            # a thief position fix guides the chase this long',
             "replace": '  ThiefFixTtl* = 40            # a thief position fix guides the chase this long\n  IntruderTrackTtl* = 90       # the HomeDefender only leaves its choke for a\n                              # remembered intruder this fresh; an older track\n                              # is a place, not a body'},
            {"file": "baseline/objective.nim",
             "find": '      if not onOurHalf:\n        continue\n      let d = dist(bot.enemies[i].pos, f.me)',
             "replace": '      if not onOurHalf:\n        continue\n      if bot.tick - bot.enemies[i].lastSeen > IntruderTrackTtl:\n        continue                         # stale: a place, not a body\n      let d = dist(bot.enemies[i].pos, f.me)'},
        ],
        rationale=(
            "chooseObjective's HomeDefender branch scans bot.enemies for the "
            "nearest track on our half and walks to `pos + vel * 6.0` with no "
            "freshness test at all, so a track still alive under "
            "TrackHoldTtl's 400 ticks (~17s, several hundred px of possible "
            "travel) drags the defender off chokeHold \u2014 and because act.nim's "
            "scan-sweep branch only runs while the seat is standing on its "
            "target, the phantom chase also switches off its vision sweep. "
            "Every other consumer of a remembered enemy gates itself: "
            "shooting at 24, ducking at 30, exposure at 60, pre-aim at 90, "
            "back-guard at 200. The seat that camps longest and stands last "
            "between an intruder and our pedestal gates at nothing. "
            "IntruderTrackTtl 90 matches PreAimTrackTtl, the freshness the "
            "bot already demands merely to point the gun. Hypothesis: fewer "
            "phantom chases, more time on the choke, fewer enemy captures."
        ),
    ),
    Experiment(
        name="trackhold200",
        knob="TrackHoldTtl", value=200,
        rationale=(
            "memory.nim's prune keeps a lost enemy for 400 ticks (~17s), and "
            "every consumer that shoots, ducks, bombs, routes or pre-aims "
            "applies a tighter gate of its own: FreshShotTicks 24, nearThreat "
            "30, ExposureTrackTtl 60, PreAimTrackTtl 90, NadeMemTtl 150, "
            "BackGuardTtl 200. Four consumers read a track at ANY age -- the "
            "HomeDefender's intruder break-off, MidGuard's carrier screen, "
            "safestLaneY's lane count, and sense.nim's carrier attribution -- "
            "so shortening the window mainly stops the defender leaving its "
            "choke for a body last seen eight seconds ago. corpse-track- "
            "cleanup (+0.096 K/D, the largest promotion here) paid for "
            "deleting exactly this class of phantom. One SIDE EFFECT is not "
            "optional to state, because an earlier draft of this experiment "
            "claimed there was none: the prune runs before the next frame's "
            "matching, so it also decides whether a re-sighting MERGES into "
            "an existing track or CONSTRUCTS a new one, and the constructor "
            "does not set `vel` -- it zero-initialises. A pruned-then-re- "
            "sighted enemy therefore leads at zero velocity for a frame, "
            "which does reach the firing path. So this is not a clean "
            "isolation of the three age-blind consumers; it is that change "
            "plus a lead-estimate reset on long re-acquisitions. "
            "freshshot32-reverse (-0.092) is the standing warning that "
            "shortening a memory window can be a cliff."
        ),
    ),
    Experiment(
        name="diamond-sweep-shots-only",
        parent="diamond-sweep-paint",
        edits=[
            {"file": "baseline/tuning.nim",
             "find": '  CorridorHalfWidth* = 15.0    # friendly-fire corridor half width along the ray\n',
             "replace": "  CorridorHalfWidth* = 15.0    # friendly-fire corridor half width along the ray\n  SpinShotSweepScale* = 1.0    # fraction of a spinning centre diamond's radius\n                              # a SHOT ray must keep clear of, and nothing\n                              # else. The eight diamonds are live geometry\n                              # (fov.nim) but the walkability sprite arrives\n                              # ONCE, so the mask pixelRayClear reads holds a\n                              # single spin frame. 1.0 is the swept disc --\n                              # everywhere the stone can be while the bullet\n                              # is in the air. 0.0 is off, and anything at or\n                              # below 1/sqrt(2) ~ 0.71 is a provable no-op:\n                              # the ground that is stone at EVERY frame is\n                              # already inside the one frame that was baked\n"},
            {"file": "baseline/fov.nim",
             "find": "proc crossesSpinSweep*(spins: openArray[SpinDiamond], a, b: Vec): bool =\n  ## Whether the segment a-b passes within a turning diamond's reach: inside\n  ## its swept disc (radius r — the rotated footprint never leaves it) plus\n  ## SpinSweepSlack of quantization margin. A sightline that crosses is\n  ## wrong for part of every rotation and disqualifies the pair.\n  for d in spins:\n    let\n      c = vec(float(d.cx), float(d.cy))\n      ab = b - a\n      len2 = dot(ab, ab)\n      t = if len2 < 1e-9: 0.0 else: clamp(dot(c - a, ab) / len2, 0.0, 1.0)\n    if dist(a + ab * t, c) <= float(d.r) + SpinSweepSlack:\n",
             "replace": "proc crossesSpinSweep*(\n    spins: openArray[SpinDiamond], a, b: Vec,\n    rScale = 1.0, slack = SpinSweepSlack\n): bool =\n  ## Whether the segment a-b passes within a turning diamond's reach: inside\n  ## `rScale` of its swept disc (radius r — the rotated footprint never\n  ## leaves the whole disc) plus `slack` of margin. A sightline that crosses\n  ## is wrong for part of every rotation and disqualifies the pair.\n  ##\n  ## The defaults are the FOG question, the one the one-way scan asks: the\n  ## whole disc, widened by SpinSweepSlack because occlusion is quantized\n  ## onto 8px cells. A BULLET is not quantized -- pixelRayClear walks the\n  ## pixel mask itself -- so the shot gate asks for the same disc with no\n  ## slack. Passing the defaults reproduces this proc exactly as it was.\n  for d in spins:\n    let\n      c = vec(float(d.cx), float(d.cy))\n      ab = b - a\n      len2 = dot(ab, ab)\n      t = if len2 < 1e-9: 0.0 else: clamp(dot(c - a, ab) / len2, 0.0, 1.0)\n    if dist(a + ab * t, c) <= float(d.r) * rScale + slack:\n"},
            {"file": "baseline/engage.nim",
             "find": 'import\n  bitworld/profile,\n  protocols,\n  frame,\n  grid,\n  tactics,\n  world,\n  geometry,\n  tuning\n',
             "replace": 'import\n  bitworld/profile,\n  protocols,\n  frame,\n  fov,\n  grid,\n  tactics,\n  world,\n  geometry,\n  tuning\n'},
            {"file": "baseline/engage.nim",
             "find": '  f.engage = -1\n  f.engageD = f.maxEngage\n  f.engagePrio = f.maxEngage\n  f.haveBlocked = false\n  f.blockedD = f.maxEngage\n',
             "replace": '  f.engage = -1\n  f.engageD = f.maxEngage\n  f.engagePrio = f.maxEngage\n  f.haveBlocked = false\n  f.blockedD = f.maxEngage\n  # The shot gate below asks `client.pixelRayClear`, which reads the pixel\n  # walkability mask (grid.nim) -- and that mask is ONE frozen frame. The\n  # eight spinning centre diamonds are live geometry the engine restamps\n  # into its own bullet mask as the spin advances, while the walkability\n  # sprite is sent once at connect (fov.nim). So a ray threading the gap\n  # between two blades reads clear here and can be solid by the time the\n  # 5-tick windup releases the bullet. Ask instead whether the ray crosses\n  # the swept DISC -- everywhere the stone can be during the turn -- and\n  # treat a target behind one as wall-blocked, which is what it is for part\n  # of every rotation. The mask itself is not touched: pathing, cover,\n  # exposure and the duck/peek searches read exactly what they read today.\n  # Empty, and free, at scale 0.0 and on any map but the arena.\n  var spins: seq[SpinDiamond]\n  if SpinShotSweepScale > 0.0:\n    spins = spinDiamonds()\n'},
            {"file": "baseline/engage.nim",
             "find": '    if client.pixelRayClear(f.me, predicted):\n',
             "replace": '    if client.pixelRayClear(f.me, predicted) and\n        not crossesSpinSweep(spins, f.me, predicted, SpinShotSweepScale, 0.0):\n'},
        ],
        rationale=(
            "`diamond-sweep-paint` painted the swept discs into "
            "`client.walkabilityMask` itself and separated NEGATIVE on all "
            "three metrics (K/D -0.0815, n=120) \u2014 but that one mask feeds "
            "four consumers: `cellWalkable`, the cover model, the exposure "
            "cost field, and the shot gate at `engage.nim:106`. Adding wall "
            "makes routes detour, cover cells vanish and the duck/peek "
            "searches refuse ground that is open most of the turn; only the "
            "shot half can plausibly pay. This applies the correction to that "
            "half alone: a ray crossing a diamond's swept disc is treated as "
            "blocked, so the target falls to the peek branch instead of "
            "buying a phantom-clear shot into stone that swung back. The mask "
            "is not mutated, so nothing else sees a different world. Honest "
            "prior: the parent was decisive, and this may simply show the "
            "frozen frame was never costing many shots."
        ),
    ),
    Experiment(
        name="bothflags-race-escort",
        edits=[
            {"file": "baseline/tuning.nim",
             "find": '  ThiefFixTtl* = 40            # a thief position fix guides the chase this long',
             "replace": '  ThiefFixTtl* = 40            # a thief position fix guides the chase this long\n  RaceEscortMargin* = 120.0    # px our own carrier must be closer to home\n                              # than the thief is to ITS home before the\n                              # both-flags race counts as ours and the\n                              # intercept gives way to the escort'},
            {"file": "baseline/objective.nim",
             "find": '  elif f.ownStolen and (bot.role == HomeDefender or\n      bot.tick - bot.carrierSeen <= ThiefFixTtl):',
             "replace": '  elif f.ownStolen and (bot.role == HomeDefender or\n      bot.tick - bot.carrierSeen <= ThiefFixTtl) and\n      not (f.mateCarry and bot.carrierSeen > -100_000 and\n        abs(f.mateCarryPos.x - homeDeepX(bot.team)) + RaceEscortMargin <\n        abs(bot.carrierPos.x - homeDeepX(enemy(bot.team)))):'},
        ],
        rationale=(
            "chooseObjective ranks the thief intercept above the escort "
            "unconditionally: `elif f.ownStolen and (bot.role == HomeDefender "
            "or bot.tick - bot.carrierSeen <= ThiefFixTtl):` sits above `elif "
            "f.mateCarry:`, so the moment both flags are up, the defender "
            "always and every other seat with a fresh fix drops our own "
            "carrier to chase theirs. Capture has no own-flag-home "
            "precondition, so both-flags is a pure race, and nothing in the "
            "tree asks who is winning it. Compare the two carriers' remaining "
            "x to their home columns and, when ours leads by "
            "RaceEscortMargin, let the intercept fall through to the escort "
            "branch it already sits above. Hypothesis: chasing a race we are "
            "already winning trades a capture for a coin flip. Honest risk: "
            "the thief fix can be stale, which under-counts its progress and "
            "biases toward escorting, and the margin is what pays for that."
        ),
    ),
    Experiment(
        name="ahead-draw-push",
        edits=[
            {"file": "baseline/tuning.nim",
             "find": '  PushOutMinGame* = 2400       # ...this deep into the game breaks the posts',
             "replace": "  PushOutMinGame* = 2400       # ...this deep into the game breaks the posts\n  AheadPushTick* = 2400        # the clock all-in, brought forward to here\n                              # while we are AHEAD on kills: a timeout\n                              # draw scores exactly as badly as a loss,\n                              # and holdNow is already false in that\n                              # state, so act.nim's mid+80 clamp is off\n                              # and the push can actually arrive"},
            {"file": "baseline/objective.nim",
             "find": '    bot.tick - bot.gameStart > LatePushTick\n  )',
             "replace": '    bot.tick - bot.gameStart > LatePushTick or\n    (bot.killsInit and\n     bot.kills[bot.team] > bot.kills[enemy(bot.team)] and\n     bot.tick - bot.gameStart > AheadPushTick)\n  )'},
        ],
        rationale=(
            "The late all-in is a bare clock switch \u2014 `bot.tick - "
            "bot.gameStart > LatePushTick` \u2014 identical whether we are winning "
            "the attrition race or losing it. latepush3000 moved that switch "
            "400 ticks earlier for every state and came back level, exactly "
            "what a lever that helps in one state and hurts in the other "
            "looks like. Condition it instead: fire at AheadPushTick (2400, "
            "the tick PushOutMinGame already calls deep into the game) only "
            "while bot.kills[us] > bot.kills[them]. Two reasons that is the "
            "state to push in: a timeout draw scores exactly as badly as a "
            "loss, so a lead the clock erases is worth nothing; and being "
            "ahead makes act.nim's holdNow false, so the mid+80 clamp is "
            "already off and the two post seats can actually reach the "
            "pocket. Hypothesis. Risk: it empties our half against a team "
            "that needs a steal."
        ),
    ),
    Experiment(
        name="holdlinedepth160",
        knob="HoldLineDepth", value=160,
        rationale=(
            "act.nim clamps every held-line goal to 80px past mid. fov.nim's "
            "spinDiamonds puts the eight live rotating obstacles at cx 565 "
            "and 669, r 30 -- |x - CenterX| from 22 to 82px on the 1235 arena "
            "-- so the staging line sits 2px inside the swept band, on the "
            "one strip of ground whose collision geometry the walkability "
            "snapshot froze at a single spin frame while the engine keeps "
            "turning it. That band arrived with the 0.7.136 re-pin; the "
            "constant has never been moved in either direction, and its "
            "sibling HoldLineKills has been swept twice. 160 stages the wave "
            "clear of the discs on both sides while staying 272px short of "
            "the pocket, so it is still a hold, not an all-in. pushout-hold- "
            "conflict, which lifted this same clamp in the endgame, regressed "
            "on K/D but separated +15 captures -- the line does something, "
            "and nobody has asked where it belongs."
        ),
    ),
    Experiment(
        name="exposedcost6",
        knob="ExposedCost", value=6,
        rationale=(
            "Entering a threat-exposed cell adds 14 on top of a 5-cost "
            "orthogonal step, so a route pays up to 2.8 clean cells to dodge "
            "one watched cell. 14 -> 10 was bought twice, on two instruments "
            "and two engine pins, and leaned the same way both times without "
            "separating: hosted n=240 K/D +0.017 [-0.025, +0.060] with "
            "captures +15 [+0, +31], local n=400 K/D +0.010 [-0.020, +0.039] "
            "with captures +26 [-1, +52]. The catalogue's own reading of a "
            "null is that the effect sits under what the screen resolves, and "
            "the answer to that is a bigger move rather than more episodes on "
            "the same one. 6 more than doubles the cut, dropping the dodge "
            "budget to ~1.2 cells. Honestly, it could equally be where "
            "routing stops respecting watched lanes at all -- which is the "
            "other thing the mirror would show."
        ),
    ),
    Experiment(
        name="defender-intruder-ttl",
        edits=[
            {"file": "baseline/tuning.nim",
             "find": '  LaneTop* = 40.0              # open corridor above the mirrored obstacles',
             "replace": '  LaneTop* = 40.0              # open corridor above the mirrored obstacles\n  DefenderIntruderTtl* = 60    # the home defender leaves its choke only for\n                              # a remembered intruder this fresh; an older\n                              # track is a memory, not a body at the door'},
            {"file": "baseline/objective.nim",
             "find": '    var intruder = -1\n    var intruderD = 1e18\n    for i in 0 ..< bot.enemies.len:\n      let onOurHalf =',
             "replace": '    var intruder = -1\n    var intruderD = 1e18\n    for i in 0 ..< bot.enemies.len:\n      if bot.tick - bot.enemies[i].lastSeen > DefenderIntruderTtl:\n        continue                    # a memory, not a body at the door\n      let onOurHalf ='},
        ],
        rationale=(
            "The HomeDefender branch scans `bot.enemies` with no freshness "
            "test at all, so the choke -- the one position the design says "
            "every steal has to pass -- is abandoned for a track "
            "`updateTracks` may have been holding for TrackHoldTtl (400 "
            "ticks, ~17s), at a position that old, dead-reckoned forward by "
            "six ticks. Every other consumer of the same memory gates it: "
            "nearThreat at 30, exposure at 60, the thief fix at 40. This is "
            "intel-driven timidity in its purest form, and the direction that "
            "has paid on this tree is removing phantom intel -- corpse-track- "
            "cleanup, the largest promotion on record at +0.096 K/D, deleted "
            "exactly this class of ghost. A DefenderIntruderTtl of 60 keeps "
            "the intercept for bodies that were there a moment ago and sends "
            "the defender back to the choke otherwise. Distinct from "
            "defender-intercept-by-flag, which moved the ranking metric and "
            "left the freshness question untouched."
        ),
    ),
    Experiment(
        name="pocket-rush-mate-ttl",
        edits=[
            {"file": "baseline/tuning.nim",
             "find": '  PocketRushRange* = 210.0     # this close to the enemy pedestal, just GRAB',
             "replace": '  PocketRushRange* = 210.0     # this close to the enemy pedestal, just GRAB\n  PocketMateTtl* = 150         # a mate sighting this fresh still counts when\n                              # deciding WHICH attacker commits to the touch.\n                              # With no mate this fresh the comparison is\n                              # trivially true and every eligible seat claims\n                              # it, so the whole wave goes in unarmed'},
            {"file": "baseline/engage.nim",
             "find": '    if bot.tick - t.lastSeen > 48:\n      continue',
             "replace": '    if bot.tick - t.lastSeen > PocketMateTtl:\n      continue'},
        ],
        rationale=(
            "engage.nim arbitrates the pocket touch by distance: "
            "`nearestMateToSteal` starts at 1e18 and only a mate seen within "
            "48 ticks lowers it, then pocketRush requires `dist(f.me, "
            "f.stealTarget) < nearestMateToSteal + 8.0`. Mates are fogged, so "
            "whenever no mate has been seen for two seconds that test is "
            "trivially true and every eligible seat inside PocketRushRange "
            "claims the touch at once \u2014 and pocketRush sets `f.maxEngage = "
            "0.0`, a bot that will not shoot at all, and is excluded from the "
            "jink, the duck and the serpentine. The comment above it wants "
            "exactly one attacker unarmed \"while the rest of the wave keeps "
            "its guns up to cover the grab\"; the fail-open default inverts "
            "that into up to five unarmed bodies at a pedestal that respawns "
            "enemies armed. 48 is the tightest mate-freshness in the tree \u2014 "
            "NadeMateTtl trusts a mate sighting for 150 \u2014 so lifting the "
            "literal into PocketMateTtl and moving it to 150 makes the "
            "arbitration decide on evidence far more often. The constant's "
            "introduction at 48 would be inert; only the move to 150 is the "
            "variable. Hypothesis: a stale mate fix could equally suppress a "
            "grab we should have made, which is what the mirror measures."
        ),
    ),
    Experiment(
        name="plasma-no-duck",
        edits=[
            {"file": "baseline/act.nim",
             "find": '  elif not f.iCarry and not f.rushing and not f.pocketRush and not f.shotReady and\n      f.nearThreat >= 0:',
             "replace": '  elif not f.iCarry and not f.rushing and not f.pocketRush and not f.shotReady and\n      not f.hasPlasma and f.nearThreat >= 0:'},
        ],
        rationale=(
            "sense.nim sets `f.shotReady = client.countOf(lkFireIcon) > 0 and "
            "not f.hasPlasma`, so a bot holding the spray can reads as not- "
            "shot-ready for as long as it carries it. act.nim's cooldown "
            "branch is guarded on `not f.shotReady`, which was written for "
            "the gun's 12-tick reload; a plasma carrier satisfies it "
            "permanently. With any remembered track inside DuckRange (340px) "
            "and no cone target inside `PlasmaReach + 6.0` (142px), the arc "
            "carrier ducks behind cover and holds \u2014 every frame, for the "
            "whole life of the pickup. The one weapon that only pays inside "
            "136px is held by the one state that structurally refuses to "
            "close. Adding `not f.hasPlasma` drops it through to "
            "chooseMovement, so it keeps navigating (with the jink and "
            "serpentine still available) until the cone branch takes over "
            "inside reach. Hypothesis: the risk is a 3 hp body walking where "
            "it used to hide, and the mirror is what prices that."
        ),
    ),
    Experiment(
        name="plasma-no-lead",
        edits=[
            {"file": "baseline/tuning.nim",
             "find": '  PlasmaDetour* = 70.0         # attacker detour budget for a plasma arc pickup',
             "replace": '  PlasmaDetour* = 70.0         # attacker detour budget for a plasma arc pickup\n  PlasmaLeadTicks* = 0.0       # ticks of velocity lead the CONE aims with.\n                              # The gun leads LeadTicks for its 5-tick\n                              # windup; the cone ignites instantly and\n                              # re-resolves from the live aim every active\n                              # tick, so it has no windup to lead for'},
            {"file": "baseline/act.nim",
             "find": '    f.desiredAim = bradsOf(f.aim - f.me)\n    let err = abs(bradsErr(f.desiredAim, bot.estAim))',
             "replace": '    let\n      pt = bot.enemies[f.engage]\n      hit = pt.pos + pt.vel * (float(bot.tick - pt.lastSeen) + PlasmaLeadTicks)\n    f.desiredAim = bradsOf(hit - f.me)\n    let err = abs(bradsErr(f.desiredAim, bot.estAim))'},
        ],
        rationale=(
            "engage.nim leads every target by `t.vel * (age + LeadTicks)` and "
            "act.nim's plasma branch aims the turret at that lead point. "
            "LeadTicks 6 is derived from the gun: the engine holds a pulled "
            "trigger for FireWindupTicks 5 and fires along the angle locked "
            "at the pull. The cone has no windup \u2014 startArcFire is instant "
            "and selectArcVictims recomputes from the attacker's CURRENT "
            "position and aim every active tick \u2014 so for plasma the lead is "
            "pure error, and the 5-tick persistence cannot recover it because "
            "our aim re-leads ahead of the target each frame. The cone half- "
            "angle is 10 brads; a crossing enemy at the engine's 2.75 px/tick "
            "leaves 16.5px of lateral offset, which is 6.7 brads at 100px and "
            "13 brads at 50px \u2014 outside the cone exactly when the target is "
            "closest. This adds PlasmaLeadTicks (inert at 6.0) and moves it "
            "to 0.0, aiming the cone at the un-led track estimate. "
            "Hypothesis: 6 ticks was never chosen for this weapon, it was "
            "inherited from the one with a windup."
        ),
    ),
    Experiment(
        name="midbottom-seat-split",
        edits=[
            {"file": "baseline/objective.nim",
             "find": '    of MidBottom:\n      if dist(f.me, f.stealTarget) > 90:\n        f.target = f.stealTarget + vec(homeSign(bot.team) * 34.0, 26.0)',
             "replace": '    of MidBottom:\n      if dist(f.me, f.stealTarget) > 90:\n        # Seats 2/3 and seat 4 are BOTH MidBottom, so one offset stacks two\n        # bodies on one point: stagger the fourth mid clear of the blast.\n        f.target = f.stealTarget + vec(homeSign(bot.team) * 34.0,\n          (if bot.slot div 2 == 4: 78.0 else: 26.0))'},
        ],
        rationale=(
            "`roleForSeat` hands MidBottom to seat 4 AND to whichever of "
            "seats 2/3 is not MidTop, on both teams -- two seats carry one "
            "role while MidTop carries one. In the attacker branch both then "
            "compute the identical goal, `stealTarget + vec(homeSign*34, "
            "26)`. Two bodies aimed at one point sit inside MateSpacing (40), "
            "where chooseMovement's repulsion term fights the objective for "
            "both of them, and inside NadeBlast (52), which is exactly the "
            "pair the field's own grenade planner hunts. The role's own "
            "comment claims the trailing mid is 'offset so one enemy cone "
            "cannot kill the pair'; the fourth mid was bolted onto the same "
            "offset and got no stagger of its own. Moving seat 4 to y+78 "
            "keeps it on the bottom side of the pocket approach and puts a "
            "blast centred on either body out of reach of the other. "
            "Hypothesis: unstacking the pair costs no tempo and stops feeding "
            "two-for-one trades."
        ),
    ),

    # --- batch 6: side asymmetry and the remaining one-way fog cousins ------
    #
    # From the second ideation workflow. Its most valuable output was not an
    # experiment: the red-greed miner audited the operator's asymmetry brief
    # against the pinned engine and found two of its three claims false --
    # combat is explicitly order-independent, and choke body-blocks have no
    # lever and favour the attacker on both sides. See BACKLOG.md item 5.
    # Three proposals were rejected outright, one of them for a reason worth
    # keeping: an INERT plumbing patch cannot land through this loop at all.

    Experiment(
        name="red-kit-greed",
        edits=[
            {"file": "baseline/tuning.nim",
             "find": '  MedKitCriticalReach* = 180.0 # at 1 hp a heal outranks the current errand',
             "replace": "  MedKitCriticalReach* = 180.0 # at 1 hp a heal outranks the current errand\n  RedKitGreed* = 80.0          # extra px of med-kit detour budget RED, and\n                              # only red, will pay. The two kits sit exactly\n                              # on the map's vertical centre line, and the\n                              # engine resolves pickups in player-index\n                              # order with red on the even indices, so a\n                              # same-tick touch goes to red against its own\n                              # mirror seat. 0.0 restores the shared budget"},
            {"file": "baseline/memory.nim",
             "find": '  result = -1\n  var best = budget\n',
             "replace": "  result = -1\n  # RED-side greed: the engine steps players in slot order and slots\n  # alternate red/blue, so red's even index resolves a same-tick pickup\n  # before the mirror blue seat. Both kits sit on the centre line, so that\n  # tie is red's by construction -- pay more path px for the trip.\n  var best = budget + (if bot.team == Red: RedKitGreed else: 0.0)\n"},
        ],
        rationale=(
            "`applyPickupDetours` and the carry branch both size their med- "
            "kit detour through `bestKitDetour`, whose budget is team-blind. "
            "The engine seats slots red/blue alternating, so red holds every "
            "even player index, and `step()` runs `tryPickupMedKits` over `0 "
            "..< sim.players.len` after all movement has resolved: red seat k "
            "takes a contested touch before blue seat j whenever k <= j, and "
            "always before its own mirror seat. Both kits sit exactly on the "
            "map's vertical centre line, the only cross-team contested pickup "
            "on the map -- shields, spray cans and corner grenades are all "
            "side-local. Today both teams pay the same 120/180/90 px budgets. "
            "Hypothesis: the med-kit axis has read level across five two- "
            "sided sweeps because the two sides want different numbers, and a "
            "race red wins on ties is worth more to red. Honest risks: a "
            "seed-paired mirror measures a red-only change at half power, and "
            "the tie window is one tick with both racers hurt."
        ),
    ),
    Experiment(
        name="oneway-band-near-mid",
        edits=[
            {"file": "baseline/posts.nim",
             "find": "  OneWayBandNear = 40.0        # the target band starts this far past mid —\n                              # the enemy side of the flag ring, mirroring\n                              # where scanPost's own candidates stand\n",
             "replace": "  OneWayBandNear = -80.0       # where the target band starts, measured past\n                              # mid. NEGATIVE on purpose: act.nim clamps a\n                              # held wave to HoldLineDepth (80) past mid into\n                              # the OPPOSING half, and the field is largely\n                              # this lineage, so the enemy's own staging line\n                              # stands 80px inside OUR half. The band is the\n                              # ground the enemy wave can occupy, from that\n                              # line back to its own ring -- not the mirror\n                              # of where our candidates stand\n"},
        ],
        rationale=(
            "newOneWayScan targets every standable cell 40 to 320px past mid "
            "\u2014 the enemy's side only, mirroring where our own candidates "
            "stand. But act.nim's hold-line clamp parks a wave at "
            "HoldLineDepth 80px past mid INTO the opposing half, and the "
            "field is largely this lineage, so the enemy's staging line sits "
            "80px inside OUR half, outside the band entirely \u2014 while the "
            "overwatch itself stands at fwd -160..-40 on our side with "
            "exactly that crossing to deny. Moving the near bound to -80 "
            "makes the target set \"everywhere the enemy wave can stand, from "
            "its staging line back to its own ring\" instead of the mirror of "
            "our candidate band. Deep is left alone: its own comment records "
            "that no clear-ray one-way pair has a target past 320. Risk: "
            "targets now overlap the candidate band, so a short-range "
            "quantization artefact 60px from a peek would count the same as a "
            "mid-range lane shot, and the scan gets ~43% more targets."
        ),
    ),
    Experiment(
        name="oneway-peek-choice",
        edits=[
            {"file": "baseline/posts.nim",
             "find": '      var\n        peek: Vec\n        peekCell = -1\n        peekLine = 0.0\n      for dyc in [-2, 2, -1, 1]:\n        let ny = cy + dyc\n        if ny < 0 or ny >= GridH or not bot.cellWalkable[ny * GridW + cx]:\n          continue\n        let q = cellCenter(ny * GridW + cx)\n        let line = openLineLen(client, q, vec(eSign, 0.0), FireRange, 6.0)\n        if line > peekLine:\n          peekLine = line\n          peek = q\n          peekCell = ny * GridW + cx\n      if peekLine < PeekLineDist:\n        continue\n      # The firing-line length dominates; the position terms break near-ties\n      # toward the wanted flank height and hugging the flag ring.\n      var score = abs(p.y - wantY) + abs(fwd + 90.0) * 0.7 - peekLine * 0.7\n      if OneWayBonus != 0.0 and oneWayFogReady():\n        if not oneWay.ready:\n          oneWay = bot.newOneWayScan(client, eSign)\n        score -= float(oneWay.oneWayCount(client, peekCell, peek)) * OneWayBonus\n',
             "replace": "      var\n        peek: Vec\n        peekCell = -1\n        peekBest = 1e18\n      for dyc in [-2, 2, -1, 1]:\n        let ny = cy + dyc\n        if ny < 0 or ny >= GridH or not bot.cellWalkable[ny * GridW + cx]:\n          continue\n        let\n          nc = ny * GridW + cx\n          q = cellCenter(nc)\n          line = openLineLen(client, q, vec(eSign, 0.0), FireRange, 6.0)\n        if line < PeekLineDist:\n          continue\n        # The peek is the cell the gun stands in, so the one-way term picks it\n        # rather than merely grading whichever cell the firing line picked.\n        # Fog is quantized to the 8px cell of BOTH ends, so one row over is a\n        # different sightline; the currency is the score's own -- a px of\n        # firing line trades at 0.7, a one-way cell at OneWayBonus.\n        var pscore = -line * 0.7\n        if OneWayBonus != 0.0 and oneWayFogReady():\n          if not oneWay.ready:\n            oneWay = bot.newOneWayScan(client, eSign)\n          pscore -= float(oneWay.oneWayCount(client, nc, q)) * OneWayBonus\n        if pscore < peekBest:\n          peekBest = pscore\n          peek = q\n          peekCell = nc\n      if peekCell < 0:\n        continue\n      # The firing-line length dominates; the position terms break near-ties\n      # toward the wanted flank height and hugging the flag ring.\n      let score = abs(p.y - wantY) + abs(fwd + 90.0) * 0.7 + peekBest\n"},
        ],
        rationale=(
            "scanPost picks the peek by `openLineLen` alone and only then "
            "prices that one cell with the one-way term (posts.nim:126-144). "
            "So the cell the gun actually stands in \u2014 the cell whose fog "
            "verdict the term counts \u2014 was chosen for a different reason, and "
            "among the four candidates (\u00b11, \u00b12 rows in the same column) ties "
            "fall to list order. The engine decides visibility purely from "
            "the 8px cell of viewer and target (`fovCellAt`, "
            "`playerVisibleTo`), so one row over is a different sightline "
            "entirely; the term's own table is the thing that says these flip "
            "cell to cell. This lets the term choose the peek in the currency "
            "the candidate score already spends \u2014 0.7 per px of firing line, "
            "OneWayBonus per one-way cell \u2014 instead of only grading a winner "
            "picked without it. Risk: up to 4x the shadowcasts at nav build, "
            "and the term already measured +3% of an episode at OneWayBonus "
            "40."
        ),
    ),
    Experiment(
        name="post-vision-shield",
        edits=[
            {"file": "baseline/posts.nim",
             "find": '  var\n    bestScore = 1e18\n    oneWay: OneWayScan                   # built on the first scored candidate\n',
             "replace": '  let fogBlocked =\n    if oneWayFogReady(): buildFovBlocked(client)\n    else: newSeq[bool]()\n  var\n    bestScore = 1e18\n    oneWay: OneWayScan                   # built on the first scored candidate\n'},
            {"file": "baseline/posts.nim",
             "find": '      if rayClearCoarse(client, p, p + vec(eSign * CoverShieldDist, 0.0), 4.0):\n        continue                         # nothing shields us from the front\n',
             "replace": '      # A VISION shield, not a bullet one. The walkability mask answers what\n      # stops a bullet; the fog answers what stops a look, and the two are\n      # not the same wall. A cell at least half wall is fully opaque to the\n      # shadowcast while still passing bullets through its wall-free pixels,\n      # and glass is the exact reverse: solid to every bullet, invisible to\n      # the fog. Under fog nobody shoots what they have not seen, so what a\n      # standing sniper needs in front of it is the first kind.\n      var shielded = false\n      if not oneWayFogReady():\n        shielded = not rayClearCoarse(\n          client, p, p + vec(eSign * CoverShieldDist, 0.0), 4.0)\n      else:\n        for step in 1 .. int(CoverShieldDist) div NavCell:\n          let nx = cx + int(eSign) * step\n          if nx < 0 or nx >= GridW:\n            break\n          if fogBlocked[cy * GridW + nx]:\n            shielded = true\n            break\n      if not shielded:\n        continue                         # nothing HIDES us from the front\n'},
        ],
        rationale=(
            "posts.nim:120 accepts an overwatch hold only when "
            "`rayClearCoarse(p, p + eSign*CoverShieldDist)` finds a wall "
            "pixel within 42px in front \u2014 a BULLET shield, read out of the "
            "walkability mask. Under fog what keeps a sniper alive is not "
            "being seen: every bot fires only at tracks seen within "
            "FreshShotTicks (engage.nim:72), and the field is largely this "
            "lineage. Vision runs on a different mask \u2014 fov.nim's "
            "buildFovBlocked calls a cell opaque only at `walls * 2 >= "
            "pixels`, and exempts glass outright. So a hold shielded by a "
            "thin strut, or by the mid bracket's centre pane (479,312,12,36 "
            "and its 744 mirror, the one vendored window inside either "
            "candidate band), passes today's test while the enemy shadowcast "
            "sees straight through it. This moves the front-shield test onto "
            "the occlusion grid fov.nim already builds. The converse reading "
            "of this cousin \u2014 crediting posts that shoot into ground nobody "
            "can see \u2014 is dead, because the bot cannot fire at what it never "
            "saw. Risk: concealment bought with bullet cover."
        ),
    ),
    Experiment(
        name="exposure-fog-honest",
        edits=[
            {"file": "baseline/navgrid.nim",
             "find": 'import\n  bitworld/profile,\n  protocols,\n  posts,\n  grid,\n  world,\n  geometry,\n  tuning',
             "replace": 'import\n  bitworld/profile,\n  protocols,\n  posts,\n  fov,\n  grid,\n  world,\n  geometry,\n  tuning'},
            {"file": "baseline/navgrid.nim",
             "find": 'proc buildStaticExposure*(bot: Bot, client: ProtocolClient) =\n',
             "replace": "proc markExposedFogged(\n  bot: Bot,\n  client: ProtocolClient,\n  field: var seq[bool],\n  spot: Vec,\n  vis: openArray[bool]\n) =\n  ## markExposedFrom, narrowed to the cells the ENGINE'S FOG lets `spot`\n  ## see. `vis` is fov.nim's shadowcast from the spot's own cell -- the\n  ## same non-reciprocal, 8px-quantized cast the server fogs entities\n  ## with. A sniper cannot aim at ground it can never see, whatever a\n  ## pixel ray says, so this only ever REMOVES marks.\n  let\n    x0 = max(0, int(spot.x - ExposureRange) div NavCell)\n    x1 = min(GridW - 1, int(spot.x + ExposureRange) div NavCell)\n    y0 = max(0, int(spot.y - ExposureRange) div NavCell)\n    y1 = min(GridH - 1, int(spot.y + ExposureRange) div NavCell)\n  for cy in y0 .. y1:\n    let py = float(cy * NavCell + NavCell div 2)\n    for cx in x0 .. x1:\n      let c = cy * GridW + cx\n      if field[c] or not bot.cellWalkable[c] or not vis[c]:\n        continue\n      let p = vec(float(cx * NavCell + NavCell div 2), py)\n      if dist(p, spot) <= ExposureRange and\n          rayClearCoarse(client, spot, p, 8.0):\n        field[c] = true\n\nproc buildStaticExposure*(bot: Bot, client: ProtocolClient) =\n"},
            {"file": "baseline/navgrid.nim",
             "find": '  bot.exposureStatic = newSeq[bool](GridW * GridH)\n  for spot in bot.enemyPosts:\n    bot.markExposedFrom(client, bot.exposureStatic, spot)\n',
             "replace": "  bot.exposureStatic = newSeq[bool](GridW * GridH)\n  if oneWayFogReady() and bot.enemyPosts.len > 0:\n    # What the enemy sniper can HIT is bounded by what the engine's fog\n    # lets it SEE, and the fog is a shadowcast over 8px cells anchored at\n    # x = 0 while the map mirrors as x' = MapW - 1 - x -- so the lattice\n    # does not mirror and the two sides watch differently-shaped ground\n    # from mirror-image posts. Ask fov.nim rather than a symmetric ray.\n    let blocked = buildFovBlocked(client)\n    var vis = newSeq[bool](GridW * GridH)\n    for spot in bot.enemyPosts:\n      let c = cellOf(spot)\n      shadowcastFrom(blocked, c mod GridW, c div GridW, vis)\n      bot.markExposedFogged(client, bot.exposureStatic, spot, vis)\n  else:\n    for spot in bot.enemyPosts:\n      bot.markExposedFrom(client, bot.exposureStatic, spot)\n"},
        ],
        rationale=(
            "navgrid.nim:79 charges ExposedCost to every walkable cell within "
            "ExposureRange of the predicted enemy sniper peek that "
            "`rayClearCoarse` reaches \u2014 a symmetric pixel ray standing in for "
            "a rule the engine states in CELLS: an entity is fogged unless "
            "the viewer's quantized shadowcast reaches its cell. The two "
            "answers differ, and differ by side, because that lattice is "
            "anchored at x=0 while the map mirrors about 1234-x, two pixels "
            "off every cell boundary. So both teams route around ground their "
            "own sniper can never see, each around a differently-shaped set. "
            "Gating the post's exposure on fov.nim's own cast only ever "
            "REMOVES marks \u2014 the anti-timidity direction corpse-track-cleanup "
            "paid on \u2014 with the same sign on both sides, so the mirror sums "
            "the two gains instead of cancelling them. Risks: chokehold- "
            "oneway says this machinery does not transfer to every consumer, "
            "and the gate may barely bite."
        ),
    ),
    Experiment(
        name="oneway-red-off",
        edits=[
            {"file": "baseline/tuning.nim",
             "find": "  OneWayBonus* = 40.0           # px of post-score credit per enemy-lane cell\n                              # the peek can see that can NEVER see it back\n                              # (the engine's quantized shadowcast is not\n                              # reciprocal; see fov.nim) with a clear bullet\n                              # ray. At 0.0 the term is off and scanPost\n                              # never builds the one-way table at all",
             "replace": "  OneWayBonusRed* = 0.0         # px of post-score credit per enemy-lane cell\n  OneWayBonusBlue* = 40.0       # the peek can see that can NEVER see it back\n                              # (the engine's quantized shadowcast is not\n                              # reciprocal; see fov.nim) with a clear bullet\n                              # ray. At 0.0 that side's term is off and\n                              # scanPost never builds its one-way table at\n                              # all. PER SIDE because the fog lattice does\n                              # not mirror: the map mirrors as x' = MapW-1-x\n                              # and 1234 is not a multiple of NavCell, so a\n                              # cell's mirror image straddles two cells and\n                              # the sides hold different one-way tables --\n                              # 52 red candidates to 50 blue, 13 clear-ray\n                              # pairs to 16. At 40 red's best peek buys ONE\n                              # extra one-way cell for 8.4px of base score\n                              # and blue's buys THREE (research/LEDGER.md)"},
            {"file": "baseline/posts.nim",
             "find": '  var\n    bestScore = 1e18\n    oneWay: OneWayScan                   # built on the first scored candidate',
             "replace": "  # The one-way credit is priced PER SIDE: the 8px fog lattice does not\n  # mirror, so red and blue hold different one-way tables. `eSign` names\n  # the side whose post is being scored -- +1 is the team whose guns point\n  # east, i.e. Red -- for BOTH callers, so our own post and our model of\n  # the enemy's are each scored with the value that side really plays with.\n  let bonus = (if eSign > 0.0: OneWayBonusRed else: OneWayBonusBlue)\n  var\n    bestScore = 1e18\n    oneWay: OneWayScan                   # built on the first scored candidate"},
            {"file": "baseline/posts.nim",
             "find": '      if OneWayBonus != 0.0 and oneWayFogReady():\n        if not oneWay.ready:\n          oneWay = bot.newOneWayScan(client, eSign)\n        score -= float(oneWay.oneWayCount(client, peekCell, peek)) * OneWayBonus',
             "replace": '      if bonus != 0.0 and oneWayFogReady():\n        if not oneWay.ready:\n          oneWay = bot.newOneWayScan(client, eSign)\n        score -= float(oneWay.oneWayCount(client, peekCell, peek)) * bonus'},
        ],
        rationale=(
            "posts.nim:141 prices the one-way fog credit with ONE constant "
            "for both teams, and the arena does not warrant one number. The "
            "engine fogs on 8px cells anchored at x=0 (sim.nim: `x div "
            "FovCellSize`), while the map mirrors as x' = MapW-1-x = 1234-x, "
            "and 1234 is not a multiple of 8 \u2014 a cell's mirror image "
            "straddles two cells 5/3, so the sides hold genuinely different "
            "one-way tables: 52 red candidates against 50 blue, 13 clear-ray "
            "pairs against 16. The ledger records what each side buys at 40: "
            "red's chosen peek gains ONE extra one-way cell for 8.4px of base "
            "score, blue's gains THREE. This splits the constant per side, "
            "keyed off eSign so our model of the enemy sniper moves with it, "
            "and zeroes RED \u2014 asking whether red's one-cell trade paid or "
            "whether the promoted +0.027 K/D was blue's alone. Inert on blue, "
            "so the mirror measures it at half amplitude rather than "
            "cancelling it."
        ),
    ),

    # --- batch 4: the knob axes BACKLOG.md records as swept at one value ----
    #
    # Every entry below names a constant that is IN the tree right now and has
    # never been moved. Two of the backlog's knob candidates are deliberately
    # absent: `EngageStrafeBlend`, `CooldownSweepArc`, `WipePushKills` and
    # `DuckStandoffWeight` were introduced by patches that were REJECTED, so
    # they do not exist in `tuning.nim` and a knob edit against them would
    # match nothing and abandon the run.
    Experiment(
        name="corpseclear40",
        knob="CorpseClearRadius", value=40.0,
        rationale=(
            "corpse-track-cleanup shipped at radius 80 for +0.096 K/D, the "
            "largest promotion in this repository, and 160 came back level. "
            "That brackets the axis on one side only: 40 is the other end, "
            "and it asks the question the promotion left open -- is 80 the "
            "optimum, or is it merely the first value tried on a knob whose "
            "benefit saturates well below it? A tighter radius deletes a "
            "track only when the landing is nearly on top of it, which is "
            "the conservative reading of the same mechanism: fewer phantom "
            "tracks removed, but also no chance of deleting a LIVE second "
            "enemy standing near the casualty. If 40 is level with 80 the "
            "knob is flat and the promotion was the mechanism, not the "
            "number; if 40 is worse, 80 is a real peak."
        ),
    ),
    Experiment(
        name="duckrange260",
        knob="DuckRange", value=260.0,
        rationale=(
            "The anti-timidity bet the backlog records as dropped in favour "
            "of exposedcost10 and never re-queued. DuckRange 340 is the "
            "radius within which a REMEMBERED threat makes the bot break off "
            "and duck on cooldown -- a reaction to intel, not to a body, and "
            "every measured result here that removed phantom intel has paid "
            "(corpse-track-cleanup +0.096, the strongest single finding on "
            "record). 340px is over a quarter of the map width, so a stale "
            "track anywhere in the neighbourhood can park the bot behind "
            "cover; 260 keeps the duck for threats that could plausibly be "
            "on us within the cooldown and stops paying ground for the rest."
        ),
    ),
    Experiment(
        name="preaimwatch320",
        knob="PreAimWatchRange", value=320.0,
        rationale=(
            "A keeper abandons its scan sweep only for evidence inside 200px. "
            "The scan family is the one that has paid twice on this policy "
            "(ScanArc 24 -> 28 -> 36, +0.16 K/D between them) and its lesson "
            "was consistently that wider coverage beats tighter discipline. "
            "PreAimWatchRange is the gate on the same turret from the other "
            "side: at 320 it matches PreAimRange, so the keeper pre-aims at "
            "everything the pre-aim scorer is willing to rank at all instead "
            "of throwing away the outer two thirds of that evidence. The "
            "risk is the mirror image -- a keeper that chases distant pings "
            "stops sweeping its own approach -- which is exactly what the "
            "mirror measures."
        ),
    ),
    Experiment(
        name="preaimwatchttl60",
        knob="PreAimWatchTtl", value=60,
        rationale=(
            "The other half of the keeper's leave-the-sweep gate, and the "
            "cheaper half to be wrong about: 30 ticks is ~1.25s, shorter "
            "than the turret needs to traverse the far half of its cone at "
            "AimRate 5. So the keeper can start a swing toward a fresh "
            "sighting and have the licence expire before the gun arrives, "
            "paying the traverse and getting neither the pre-aim nor the "
            "sweep. 60 matches PreAimPingTtl, the freshness the pre-aim "
            "scorer itself trusts, and makes the two gates agree."
        ),
    ),
    Experiment(
        name="backguardarc128",
        knob="BackGuardArc", value=128,
        rationale=(
            "BackGuardRange is 260px, which on a 1235px arena covers most of "
            "any real fight, and inside it BackGuardArc clamps the aim to 96 "
            "brads of the known enemy -- so the constant that most often "
            "overrides the scan sweep is one nobody has ever moved. ScanArc "
            "paid twice by buying wider coverage, and this is the clamp that "
            "cancels it whenever a live enemy is anywhere nearby. 128 is a "
            "half-turn: the guard still forbids turning the back fully on a "
            "known body, and everything short of that becomes available to "
            "the sweep again."
        ),
    ),
    Experiment(
        name="hpfocus120",
        knob="HpFocusBonus", value=120.0,
        rationale=(
            "Listed in the backlog as considered and dropped on the timidity "
            "prior -- a prior that cuts the OTHER way for aim constants and "
            "was never actually tested on one. HpFocusBonus is px of credit "
            "per missing enemy hit point when choosing between targets: at "
            "60 a two-pip-wounded enemy is worth 120px of effective distance "
            "against a healthy one, less than the width of one plasma cone "
            "reach, so the choice is usually made on geometry alone. A hurt "
            "enemy is one hit from a kill and a kill is the only thing that "
            "removes a body from the map; at 120 finishing the wounded one "
            "outbids a modestly closer healthy one, which is aggression, not "
            "timidity."
        ),
    ),
    Experiment(
        name="traversepx24",
        knob="TraversePxPerBrad", value=2.4,
        rationale=(
            "The third of the backlog's untested aim constants, and the one "
            "with a derivation to check rather than a taste to argue: 1.6 is "
            "8px of enemy closing motion per tick divided by AimRate 5. That "
            "assumes the target closes at 8px/tick, which is the sprint "
            "speed of something running straight at us; a target that is "
            "strafing, holding a lane or walking away closes far slower, so "
            "the constant systematically UNDER-prices traverse for every "
            "target that is not charging. 2.4 says a cross-cone swing costs "
            "what half the map does, which is the honest price of arriving "
            "late to a fight the turret chose while a nearer target went "
            "unshot."
        ),
    ),
    Experiment(
        name="carrierfire180",
        knob="CarrierFireRange", value=180.0,
        rationale=(
            "While carrying the flag the bot shoots only what is inside "
            "110px -- under one plasma reach past its own footprint, and far "
            "inside the gun's real range. The intent is obvious (a carrier "
            "that stops to fight is a carrier that does not score) but the "
            "number was never measured, and it is the gate on the ONE seat "
            "whose death hands the flag straight back. 180 still refuses "
            "every distant duel and adds only the band where a chaser is "
            "about to be in plasma range anyway -- the shots that decide "
            "whether the run finishes."
        ),
    ),
]


def followups(exp: Experiment, promoted: bool, tree_value: str,
              observed: float = 0.0,
              tried: dict[str, set[float]] | None = None) -> list[Experiment]:
    """What a finished knob experiment suggests trying next.

    A hill-climb, deliberately shallow. A knob that paid gets pushed the same
    way again -- the step that won is rarely the biggest step that wins. A
    knob that measured WORSE gets tried once in the opposite direction, since
    a wrong sign is evidence about the constant either way.

    `observed` is the point estimate of the K/D gap, and it decides that
    second case. Reversing on the sign of the *decision* rather than the sign
    of the *measurement* would walk the wrong way after every level-but-
    positive result: a knob that came back +0.03 and did not separate is a
    knob to push further if it is anything, and reversing it spends 80
    episodes proving the direction nobody proposed is worse.

    A level result that leans the way it was pushed suggests nothing either --
    the honest reading of a null is that the effect is under what the screen
    resolves, and spending more episodes to confirm a null is how the previous
    session lost a day. Only a level result that leans the OTHER way earns the
    reverse.

    `tried` maps a knob to every value already measured on it, and a proposal
    landing on one of them is dropped. Walking a knob from both ends converges
    on values already bought: a reverse of a reverse steps back to where the
    first experiment was, and the loop would spend 80 episodes re-measuring an
    answer it has written down. PreAimArc did exactly that -- 20 -> 28 failed,
    20 -> 12 failed, and the second failure proposed 28 again.

    Patch experiments derive nothing: there is no axis to walk along.
    """
    if exp.kind != "knob" or exp.value is None:
        return []
    base = float(tree_value)
    if promoted:
        step = float(exp.value) - base
        nxt = float(exp.value) + step
        tag = "further"
    elif observed < 0:
        step = base - float(exp.value)
        nxt = base + step
        tag = "reverse"
    else:
        return []
    seen = (tried or {}).get(exp.knob, set())
    if nxt <= 0 or abs(nxt - base) < 1e-9 or any(abs(nxt - t) < 1e-9 for t in seen):
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
