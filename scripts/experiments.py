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
