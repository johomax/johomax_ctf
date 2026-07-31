# Idea backlog — ideas with NO experiment behind them

Everything in this file is untried: no experiment exists for it, in either
`research/state.json`'s `done` or `scripts/experiments.py`'s SEED. Nothing here
is evidence of anything; that is exactly why it is written down.

Three places hold the work, and an idea lives in exactly one of them:

| where | what it holds |
|---|---|
| **this file** | ideas nobody has turned into an experiment |
| `scripts/experiments.py` | experiments that exist — queued or already run (name, rationale, exact edits) |
| `research/LEDGER.md` | verdicts, with the request ids and episode files behind them |

An idea that becomes an experiment leaves this file. A decided experiment is in
the ledger, not here. Last reconciled 2026-07-31 against 95 experiment names.

Sources: the operator's asymmetry brief, deep-read ideation passes, replay
analysis of 31 v76 games against the ladder, and driver-session notes.

---

## Features — bigger than one variable

Each needs to land as its own commit before it can be measured. Note the
constraint in "How a feature has to land" below: the loop cannot land these
for you.

Items 1, 2 and 3 left this file on 2026-07-31: the scaffolds are landed
(`d362bf1`, inert on 12 seeds) and the gates are experiments. What they bought
is in LEDGER.md — `shout-peek` +0.164 K/D and `latticehold6` +0.080 K/D, the
two largest promotions on record. What is left of them is knob work and is in
`scripts/experiments.py`, not here. Read the surviving lesson instead:

> **The consumer, not the sense, was the variable.** The same shout channel
> read level wired to the pre-aim scorer (`shout-channel`, K/D −0.022) and
> paid +0.164 wired to the peek branch. A new sense is not one experiment; it
> is one experiment per thing that can consume it, and the cheapest consumer
> is not the informative one. Whatever the next sense is, plan the ladder
> before landing it.

1. **A private vocabulary richer than one enemy fix.** `E<gx>,<gy>` spends 6 of
   the 10 characters the engine allows on one enemy's cell, once a second, and
   the channel has now been shown to be the most valuable thing in the tree.
   Untried: a second word. Candidates, each its own commit and gate — "I am
   carrying, escort me here", "our flag went out through this cell" (the
   thief-hunt fix is the bot's worst blind spot and the only one every seat
   already wants), "this ground is clear", a wounded-target call so two seats
   focus the same body. The cost of a word is not bytes, it is that a listener
   must be able to act on it differently from a fix.

2. **Shout a fix a mate can FIRE on.** Every consumer today refuses to make a
   heard fix a fire target, and for a good reason (a 32px cell against a ~14px
   corridor, and the server kills the nearest player in it — which on a guess
   is as likely to be the mate who shouted). But a fix CONFIRMED by our own
   fresh sighting of the same cell is not a guess, and two seats firing on one
   body is the focus fire this policy lost when GV24 fuzzed the aim dots.
   Needs a confirmation rule, not a looser gate.

3. **Lattice pin on the cells nobody pinned.** `latticehold6` pins the two
   standing seats to the cell their post was scored in and pays +0.080. The
   duck cell and the peek cell are chosen the same way — `findDuckCell` picks
   the cell whose CENTRE the threat's ray cannot reach — and are not pinned.
   `duckarrive2` and `peekarrive2` moved the ARRIVAL distance and both read
   level, which is a different question: an arrival tolerance decides when the
   feet stop, a pin decides which cell they stop in. Note the honest caveat:
   the duck's value is a pixel ray, not a cell, so the mechanism is weaker
   there than at the post.

4. **Blue-specific unmirrored play.** ~~Gated on (9).~~ **(9) is done and the
   premise did not survive it.** `analysis/role_bleed.md`, over 3160 post-
   re-pin episodes: there is no team-wide blue deficit (ΔK/D +0.036, and the
   file-level interval includes zero). It is TWO SEATS pointing opposite ways
   — Overwatch +0.515 K/D red over blue, FlankBottom −0.396 — and everything
   else is inside the noise. So the ask is no longer "unmirror the policy". It
   is: **why is blue's Overwatch post worse than red's, and why is red's
   FlankBottom worse than blue's?** The first has an axis already plumbed
   (`OneWayBonusRed`/`Blue` split, `0eb4c83`; `onewayblue80` is queued) and a
   mechanism worth reading before more knobs — `findEnemyPosts`/`pickPost`
   choose from 52 red candidates and 50 blue, with 13 clear-ray one-way pairs
   against 16. The second has no candidate mechanism at all and wants an
   episode read, not an experiment.

## Knobs never asked

5. **`CorpseClearRadius` 20 and 120.** 40 is shipped (v79) and 160 measured
   level, so the axis is bracketed above and open below. This is the biggest
   promotion on record and its optimum has moved downward once already.
   The loop declines to auto-propose 0: that switches the mechanism off rather
   than tuning it.

6. **`ThiefFocusBonus` sweep.** Both siblings in its line (`HpFocusBonus`,
   `TraversePxPerBrad`) are in the catalogue; this one was dropped on the
   timidity prior, which cuts the other way for aim constants and has never
   actually been tested on one.

7. **Per-side splits of any constant other than `ScanArc` and `OneWayBonus`.**
   The `NameRed`/`NameBlue` plumbing plus team-indexed selector is landed and
   proven inert twice over, so splitting another constant is a direct commit
   plus a plain knob experiment. `ScanArc` is done and found NO side
   difference (blue 32, red 32, red 24 all level); `OneWayBonus` is split as
   of `0eb4c83` and its blue half is queued. Pick a constant with a reason to
   differ by side, and now there is a way to have one: `analysis/role_bleed.md`
   says which SEAT is losing on which side, so split a constant that seat's
   role actually reads. Read a per-side result by DOUBLING it; see LEDGER.md.

8. **The four axes whose introducing patch was rejected**, each of which needs
   that patch RE-PROPOSED carrying the new value, as one experiment — the
   constants are not in the tree and a knob edit naming them matches nothing:
   `EngageStrafeBlend` (0.6, from combat-strafe), `CooldownSweepArc` (15, from
   cooldown-sweep), `DuckStandoffWeight` (0.5, from duck-standoff),
   `WipePushKills` (20, from wipe-push).

## Tooling and investigation — not single-variable experiments

The loop has no verdict to give these; they need doing by hand. An ideation
pass proposed (9) as an experiment and a verifier rejected it on exactly that
ground.

9.  ~~**Per-role bleed instrumentation.**~~ **DONE** — `analysis/role_bleed.py`
    and `analysis/role_bleed.md`, 9140 banked episodes, no change to `bot/`.
    Read the report before quoting any per-side number; three of its findings
    change what the rest of this file is allowed to assume:
    - **The corpus is two different games.** 65% of the banked episodes
      predate the GV27 → `1047232f` re-pin, and the two eras disagree about
      which role bleeds AND in which direction. A pooled number over all of
      them is an average of two questions. Quote the post-re-pin slice.
    - **The premise inverted.** No team-wide side deficit survives the re-pin,
      and RED wins 50.6% of episodes locally — not the ~63–71% the READMEs
      still record from the hosted league. That number is the basis of rule 2
      in README.md; it is still right about the HOSTED league and is now known
      to be wrong about the local mirror.
    - **The binding constraint is not episodes, it is experiments.** Every
      per-role gap except the two named in (4) is resolvable against seed
      noise and NOT against between-batch variation, at 17 batches. Buying
      more episodes inside a batch cannot fix that.

10. **`EscortScreenDist`, why the branch is dead.** It measured "level" at 70
    with EXACTLY-ZERO gaps: the escort-screen-with-remembered-threat branch
    never fired in 240 episodes. ⚠️ The constant is now GONE from the tree
    entirely, so this was never a knob ask. Re-establish where the screen
    lives before proposing anything.

11. **RED-bias localization.** Local seed-paired mirrors ran RED at 16–40%
    under the stale GV27 pin and 51–65% after the re-pin (hosted ~65%), so the
    inversion is mostly explained — but nobody localized which seats and phases
    lose RED's episodes, and the residual is unmeasured.

12. **Policy-side sim speed.** After the GV-current perf patch the policy is
    ~half of remaining sim wall clock; a profile-guided pass over the bot (same
    gameHash discipline) would roughly double iteration speed again.

13. **Paintbot league seating.** The bot is also seated in the Paintbot league
    (2v2 split-team and 4-team FFA, shouts as a game mechanic) where the
    slot-parity team derivation may simply be WRONG. Nobody has looked at a
    single Paintbot episode.

## Re-asks the record justifies

14. **pushout-hold-conflict under the current engine.** Rejected under GV27
    (K/D −0.016, win rate leaning +0.050 unresolved) — but the replay record
    shows the failure it targets happening in production: 4/4 timeout draws
    against Rohit while behind on kills, zero enemy-third deaths. The one GV27
    reject with hosted evidence pointing the other way, and the engine has
    moved twice since.

15. **clock-phased-wave's parameter plane.** The patch ran level at exactly one
    point (period 300, one phase in three released) and its two parameters are
    coupled, which is why it stayed a patch. One level point does not clear a
    plane; period 150/600 and duty 1/2 would.

## Unused engine mechanics — found 2026-07-31 by a source hunt, each verified twice
These came out of a workflow that read the engine region by region and asked,
for every mechanic in it, whether `bot/` mentions it at all — then had a second
agent check each claim against the source, against `bot/`, against the ledger
and against the recorded dead ends. That hunt exists because the largest
improvement in this record (`shout-peek`, K/D +0.164) came from exactly this
shape of gap: a fully documented mechanic the policy simply never read.

Every one below is a FEATURE, not a knob: it needs an inert scaffold landed by
a direct commit behind a constant that reads 0, gameHash-proven over a batch of
seeds, before the loop can measure anything. Each carries its own ladder and
its first rung. **Read the risk line before starting one — several of these
name a neighbouring experiment that already measured negative.**

### 1. `ghost-flag-read`
**Ghost frames carry both flag banners; the dead branch never reads them.** A dead viewer gets a GHOST frame: `viewerIsGhost = not player.alive` (`global.nim:5193`), no fog overlay (`if not viewerIsGhost: sim.addFogRuns(...)`, :5203), every living body streamed (:5259-5262), and BOTH banners emitted on `if viewerIsGhost or sim.flagVisibleTo(playerIndex, team)` (:5213) — the ghost arm bypasses the carrier-visibility test. A carried banner is drawn at `flag.x/flag.y` as `FlagSpriteBase + ord(team)`, labelled `"<color> flag"` (:3449, :5234-5240), and `updateFlags` glues the flag to `players[carrier].x/y` every tick (`sim.nim:8419-8431`). So a corpse sees exactly which enemy runs our heart and where. Nothing else is added: pips (:4887), badges (:4940), shot rings (:5376) and shouts (`shoutAudibleTo`, `sim.nim:8367`) are all dead-blind.

Today `decide.nim:24-60` banks enemy and mate tracks off that frame and `return 0` — it never calls `readFlagState`. `carrierPos/carrierVel/carrierSeen` and `mateFixPos/mateFixTick` have exactly two writers, both `sense.nim:277-309`, both alive-only. The consumers are already landed and are the tree's most aggressive: `objective.nim:69-86` (every role converges on the thief), `engage.nim:55` (fix lifts the cap to FireRange), `:101-105` (`ThiefFocusBonus` 400.0).

Ladder — `GhostFlagMode*` in `tuning.nim`, cumulative, landed at 0 (nothing parsed, gameHash-identical over seeds; ScanArc-split pattern). 1 = bank the thief fix only. 2 = + the mate-carrier fix. 3 = force the respawner onto the intercept. 4 = shout it. **Measure 1 first**: no new branch, only real data on a promoted path.

Risk: `Lives* = 3` (`sim.nim:166`) and the third death is terminal (:7426-7432, :9530). 80.1% of 271,680 banked seat-records die 3 times, so only 1.91 of 2.71 deaths ever respawn (~15 usable windows/episode/build, 72 ticks each) and rung 4 is dead on the terminal one — `applyShout` is living-players-only (`sim.nim:8321-8325`). And `stale-matecarry-fix`, which made the OTHER carrier estimate truthful, separated NEGATIVE (K/D −0.0235, win rate −0.133, n=120). Truer flag intel is not free on this tree.

*Event rate (the verifier's own estimate, which decides whether a 120-episode screen could see it):* Banked corpus: 93 files, 16,980 episodes, 271,680 seat-records, mean 3,537 gameTicks. Deaths per seat: 3 = 80.1%, 2 = 12.2%, 1 = 5.8%, 0 = 1.8%; mean 2.71. Correcting for Lives = 3, mean RESPAWNING ghost windows per seat = 1.91, so ~15.3 per episode per build (8 own seats), each RespawnTicks = 72 long — about 1,100 seat-ticks of actionable full-map flag truth per episode against 28,300 alive-or-dead seat-ticks. At ~15 firings per episode a 120-episode screen sees ~1,800 events, far above any 'does it ever run' bar. What is NOT measurable from the bank is the overlap: how often our own heart is off its pedestal during those 72-tick windows. The banked summaries carry no flag events. The only bound available: 8,937 of 16,980 episodes (52.6%) end in a capture and a capture ends the game (captures sum exactly equals capture-endings), so live steals are strictly more common than captures but 

### 2. `peek-prefire-windup`
**The trigger pull has no LOS or target test; only the release does.** `startFireWindup` (`sim.nim:7950-7962`) guards on `canFire` and `fireWindup > 0` and nothing else — it locks `windupBrads` and arms a 5-tick timer (`FireWindupTicks* = 5`, :180). Target selection, the ray origin and every LOS test happen at RELEASE, from the shooter's post-movement position: `step` decrements the windup at the top of its loop, runs `applyInput` inside the same loop, and calls `resolveSimultaneousFire` after it (:9586-9614, and the engine's own comment at :9579-9583). `selectFireTarget` reads `sx/sy` and calls `lineOfSightClear` from the release position (:7677-7701) while `fireDirection` uses the locked angle (:7648-7655). At MaxSpeed 704 / MotionScale 256 = 2.75 px/tick the pull leads the shot by ~14px of walking. `killPlayer` zeroes `fireWindup` (:7376) — a dying pull never releases, so windup ticks spent exposed are ticks a shot can be cancelled.

The policy models the AIM half of this (`baseline.nim:77`; `act.nim:290-294` drops the rotate bits on a fire tick) and none of the POSITION half. `act.nim:83-91`, the peek branch, never sets `f.wantFire`; the only fire gate reached is `act.nim:67`, and `engage.nim:106` grants `f.engage` only when `pixelRayClear(f.me, predicted)` already holds. Every peek shot therefore stands in the open for the whole windup.

Ladder — `PeekPrefirePx*` in `tuning.nim`, landed at 0.0 with `> 0.0` gating the block (provable no-op, gameHash over seeds). 1 = pre-fire at 8px only when the blocked candidate is a real remembered enemy track; 2 = the full 14px; 3 = the re-peek case; 4 = shout-derived fixes — probably never, `engage.nim:119-128` refuses heard fixes as fire targets on purpose. **Measure 1 first.**

Risk, and it is not small: the fire icon reads cooldown while `fireWindup > 0` (`global.nim:5389-5396`), so `f.shotReady` goes false the frame after the pull, the peek branch is skipped, and `act.nim:70-82` DUCKS the bot back behind the corner for the whole windup. This needs a windup counter that suppresses the duck, not twelve lines. And the residual walk is mostly perpendicular to the firing line, which shifts the ray by its full length against an effective half-width of only BulletHalfWidth 8 + PlayerHalf 6 = 14px.

*Event rate (the verifier's own estimate, which decides whether a 120-episode screen could see it):* Not countable from the bank, and I will not claim otherwise: the banked summaries record shotsFired/shotsHit but nothing about which act.nim branch produced a mask. What is measurable: 275,520 seat-records give mean 10.38 shotsFired and 6.99 shotsHit per seat per episode (accuracy 0.673) and mean 2.71 kills per seat, so a shot is worth roughly 0.26 kills and the whole seat's output is ~10 trigger pulls. Moving K/D by the instrument's 0.046 at a 120-episode screen needs about 0.15 extra kills per seat per episode, i.e. converting roughly half a shot per seat per episode from 'refused/late' to 'landed'. That is a 5% change in shot productivity — reachable if the peek branch runs at all often, and hopeless if it does not. The indirect evidence that it runs often is that `shout-peek`, which did nothing but add candidates to this exact branch, is the largest promotion on record (+0.164 K/D, L

### 3. `grenade-finisher-hp`
**A blast can only ever finish; the grenade planner does not know what hp is.** `GrenadeDamage* = 2` (`sim.nim:265`) against `HitPoints* = 3` (:167), and `explodeGrenade` (:8092-8123) reaches `if sim.players[i].hp <= 0: sim.killPlayer(...)` only when the victim's effective hp was 2 or less. Walking `absorbDamage` (:7434-7450) against the pip formula in `addHpPips` (`global.nim:4890-4903`, lit == min(3, hp + shieldHp) at maxHp 3) makes the predicate EXACT: a body reading 2 pips or fewer dies to one blast — (hp 2, shield 0) and (hp 1, shield 1) both go to zero, and (hp 2, shield 1) reads 3 pips and survives. So the kill condition is directly readable off a label the policy already parses into `t.hp` (`perception.nim:452-464`, `memory.nim:66-79`).

Today `grenades.nim:47-58` scores every landing as `d + cost` — distance plus a fixed doubt penalty — with no hp term anywhere in `planGrenade`. One module over, `engage.nim:87-88` does `if t.hp in 1 ..< MaxHp: prio -= float(MaxHp - t.hp) * HpFocusBonus` (60.0, `tuning.nim:213`). The weapon that can kill a healthy target prices woundedness; the weapon that can only kill a wounded one ignores it. Ten grenade experiments are in `state.json`; none touches hp.

Ladder — `NadeFinisherBonus*` in `tuning.nim`, landed at 0.0 (the term multiplies to zero; `d + (-0.0) == d`, so gameHash-identical over seeds). 1 = the discount only, at the two track call sites (`:78`, `:85`), mirroring HpFocusBonus. 2 = also relax the `blocked or paired` gate for a 1-pip target. 3 = veto lobbing at a lone full-hp body. **Measure 1 first**: it reorders candidates the bot already considers and cannot make it throw where it would not have thrown; rung 3 is timidity-shaped and this tree's record punishes that.

Risk: `t.hp` is a REMEMBERED pip and `offer` accepts tracks up to `NadeMemTtl` old, so the discount prices a memory — the exact class of intel `corpse-track-cleanup` paid +0.096 K/D for deleting. Med kits heal in between. And note `decide.nim:50-53` zeroes `t.hp` on every ghost frame, so tracks last refreshed while dead are invisible to this term and to HpFocusBonus alike.

*Event rate (the verifier's own estimate, which decides whether a 120-episode screen could see it):* Throw volume is not in the bank — the seat records carry shotsFired/shotsHit and nothing about grenades — so this cannot be settled from disk. The available anchor is `nadefarm420`'s own rationale in LEDGER.md:341, measured upstream: corner grenades refill every 5s and are 'the densest pickup on the map by an order of magnitude (~80 a match against ~7 of everything else)'. That supply supports several throws per seat per episode across 16 seats, which puts the throw count in the same order as the 10.38 shots/seat/episode measured over 275,520 seat-records. Rung 1 is a pure REORDER, so the event count is not 'throws' but 'throws where a wounded and a healthy candidate scored within NadeFinisherBonus of each other'. That subset is bounded by the candidate spread: `NadeMinRange* = 72.0` to `NadeMaxRange* = 240.0` is only 168px of range, so a 60px bonus mirroring HpFocusBonus reorders a larg

### 4. `silhouette-exposure-shot`
**The bullet samples the silhouette; the policy's fire gate samples only the centre.** `selectFireTarget` (`sim.nim:7690-7706`) walks `for off in countup(-PlayerHalf, PlayerHalf, ExposureSampleStep)`, offsets each sample perpendicular to the ray, and connects on the first sample that is both inside the corridor (`abs(vx*uy - vy*ux) > BulletHalfWidth` rejects) AND has its OWN line of sight (`not sim.lineOfSightClear(sx, sy, px, py)` rejects). PlayerHalf 6 (:140), ExposureSampleStep 3 (:173), BulletHalfWidth 8.0 (:176) — five samples over 12px of body, and the doc at :7669-7674 says it outright: 'Cover is therefore partial, not binary.'

What the policy already does, so the next reader does not re-derive it: it models the effective corridor WIDTH correctly — `CorridorHalfWidth* = 15.0` and `FireSlackPx* = 11.0` are set against BulletHalfWidth 8, i.e. they already contain the ±6 silhouette. What it does not do is the per-sample LOS. `engage.nim:106` is one `client.pixelRayClear(f.me, predicted)`; its `elif` at :114-117 demotes any centre-blocked target to `f.blockedD/blockedAim` and answers with a peek walk. The error is one-sided: centre-clear is always hittable, edge-only is refused.

Ladder — `SilhouetteProbePx*` in `tuning.nim`, landed at 0.0, where both probes ARE the centre ray already cast (provable no-op, gameHash over seeds). 1 = 6.0, edge probes in `selectEngagement`'s fire gate only; 2 = carry the accepted edge into `f.aim` so the gun lays on the exposed half; 3 = the mirror question for `findDuckCell`/`findPeekCell`. **Measure 1 first**: it only converts refusals into shots, so its failure mode is legible — more shots, lower accuracy. Rung 3 makes the bot MORE timid, which this tree's record punishes.

Risk, unresolved: the event is a ±6px band around a shadow boundary, ~4 ticks per transit at 2.75 px/tick against a 12-tick cooldown, and I could not count it. Worse, when only one edge shows, the connecting sample sits at perp 6 against BulletHalfWidth 8 — about 2px of surviving aim tolerance, not the 11px `FireSlackPx` authorises — so rung 1 probably has to tighten the gate with the probe or it will buy misses. Missed shots also paint an impact ring the enemy reads. Separately: `engage.nim:105` rays to a LEAD point up to 16.5px ahead of the body, so some refusals are a lead artefact, not cover; do not let edge probes take credit for fixing that.

*Event rate (the verifier's own estimate, which decides whether a 120-episode screen could see it):* Not countable from the bank, and geometrically small. The window is the ±6px band around a wall's shadow boundary. A body crossing that boundary at MaxSpeed 2.75 px/tick spends ~4 ticks in it, and against `FireCooldownTicks` 12 that yields at most one extra pull per transit. The static case is larger — a corner-hugger parked with a shoulder out — but a mirror opponent runs this same policy, and `findPeekCell` (navgrid.nim:391-439) selects cells where the CENTRE ray is clear (:436), so a mirrored opponent parks centre-exposed, not edge-exposed; the state is a league-opponent phenomenon more than a mirror one, and the local simulator only measures the mirror. Sizing it against the instrument: 275,520 seat-records give 10.38 shotsFired, 6.99 shotsHit and 2.71 kills per seat per episode, so a shot is worth ~0.26 kills and 0.046 K/D at 120 episodes needs ~0.15 extra kills per seat — about hal

### 5. `shot-leaves-from-the-release-position`
**The gun's shot leaves from the body five ticks after the pull; the fire gate is evaluated at the pull.** `sim.nim:7649-7656` takes the shot direction from `windupBrads`, locked at the trigger pull, while `sim.nim:7678` takes its ORIGIN from the live body (`sx = shooter.x + CollisionW div 2`) and `sim.nim:7701` runs the LOS test from that release point; `FireWindupTicks` is 5 (`sim.nim:180`). RULES.md:295-299 says it outright: "Strafe-firing works. The shot line translates with your movement (new position, old angle), so lead your own strafe when you pull."

Today: `act.nim:58-69` computes `perpMiss = f.engageD * sin(err)`, fires on `perpMiss <= FireSlackPx` (11.0), then sets `f.moveMask = octantBits(f.aim - f.me)` -- the gate is measured at the pull position and that same branch guarantees the feet move through the windup. `LeadTicks` 6.0 corrects for the target's motion over the windup and for none of ours. A perpendicular origin shift translates the whole ray one-for-one at every range, so closing cannot shrink it; the move octant is up to 22.5 degrees off the locked aim, and at 2.75 px/tick per axis (`sim.nim:146-151`) 5 ticks reaches ~5px cardinal / ~7px diagonal against an 11px gate and 14px of corridor+body (`sim.nim:7690-7699`).

Ladder: add `WindupLeadTicks* = 0.0`, landing inert (gameHash over a seed batch). **Rung 1, the fire gate only** -- measure perpMiss from `f.me + (f.me - bot.lastPos) * WindupLeadTicks`; `bot.lastPos` (world.nim:106) is written after `arbitrateCombat`, so own displacement is free. Flips one mask bit, never the feet, turret or target choice. Rung 2 aims from the predicted release point (moves the cone). Rung 3 asks `pixelRayClear` from it (the fire-and-duck self-block). Rung 4 holds still through the windup.

Rate: ~96 shots per team per episode (role_bleed.md: 21.9 kills/ep at 0.687 accuracy). Risk: `fireslack13` moved this gate 2px and read level at n=80, and the correction's sign varies with geometry -- rung 1 removes a systematic term, it does not promise accuracy.

*Event rate (the verifier's own estimate, which decides whether a 120-episode screen could see it):* analysis/role_bleed.md (gv-current, 3160 episodes): 21.939 kills/ep per side at 0.687 accuracy, so with HitPoints 3 that is roughly 96 shots per team per episode, ~190 per episode, ~11,000 per arm at 120 episodes. Ample events. The bar is effect size, not rate: 0.046 K/D needs about 4.5% more kills, and the nearest measured analogue -- fireslack13, a 2px move of this same gate -- read level at n=80 (K/D +0.016 CI [-0.058, +0.092]).

### 6. `square-velocity-envelope`
**The velocity envelope is a SQUARE, so engine travel time is Chebyshev and the cost field prices it Euclidean.** `applyInput` clamps velX and velY to their own plus/minus maxSpeed bounds with no cross-axis normalisation (`sim.nim:8487-8490`, `8502-8540`) and `applyMomentumAxis` steps both axes every tick (`8552-8553`): 2.75 px/tick on a cardinal, 3.889 on a diagonal, so an 8px nav cell costs 2.91 ticks entered either way. Lateral motion taken while already running on the other axis is FREE in arrival time. RULES.md:161-163 says only "acceleration, friction, max speed"; `sim/league_config.json` overrides no motion field.

Today: `tuning.nim:351-352` reads `StepCost* = 5` / `DiagCost* = 7   # ~sqrt(2) * StepCost`, consumed at `navgrid.nim:271`. `DiagCost` appears zero times in scripts/experiments.py, research/LEDGER.md, research/state.json and this file. The duck and peek searches score candidates by Euclidean `dist(p, me)` (`navgrid.nim:369`, `:430`).

Ladder: no scaffold -- `DiagCost` is already a knob. **Rung 1: `DiagCost` 7 -> 5**, which changes only which route Dijkstra picks; `NavMaxStep`/`NavBuckets` derive (`tuning.nim:357-361`) and the `step <= NavMaxStep` assert still holds at 27. Rung 2: score `findDuckCell`/`findPeekCell` by `max(|dx|,|dy|)`. Rung 3: per-axis sign locomotion in place of `octantBits` -- note it is not faster (arrival is `max(|dx|,|dy|)/vmax` either way), it only frees the minor axis early, and it collides with the queued `steer-dither-quarter`.

Rate: every field build for eight seats, all episode. Risk, and read it before buying: `DiagCost` also re-prices a diagonal against `ExposedCost` 22 (29 -> 27), and `ExposedCost` 14->22 is the strongest knob on record (+0.0937 K/D, with both 30 and 6 negative), so part of rung 1 is an exposure re-price rather than geometry. Chebyshev also makes large sets of routes exactly tie, handing path shape to neighbour iteration order.

*Event rate (the verifier's own estimate, which decides whether a 120-episode screen could see it):* Every cost-field build, for eight seats, all episode: computeField runs at least every RepathTicks 10 and on every goal change, and every navigating tick's steer is drawn from it. This is the highest event rate available anywhere in the policy -- the same population steer-dither-quarter calls 'the highest event rate available in this area'. A 120-episode screen resolves 0.046 K/D and the comparable route-metric knob, ExposedCost 14->22, separated +0.094 at n=400, so the channel is demonstrably visible if the metric matters at all.

### 7. `weave-below-the-accel-floor`
**The d-pad commands acceleration, and both evasion routines flip inside the time constant.** `applyInput` adds `inputX * accel` to the axis velocity and applies friction only in the ELSE branch (`sim.nim:8506-8540`), so a held direction never decays: Accel 76, MaxSpeed 704, MotionScale 256 (`sim.nim:146-151`) means ~10 ticks to zero an axis and ~19 to reverse it. Integrating the engine's exact integer update: a lateral d-pad flipped every 8 ticks moves the body ~5.8px peak-to-peak (period 12 ~11px, 20 ~29px), plus a ~1.2px/tick one-sided drift, because from rest with symmetric holds the velocity triangle never crosses zero. (My integration, not an episode; the drift disappears by period 20.) A body centre up to 14px off the ray is still hit (`sim.nim:7690-7699`: BulletHalfWidth 8 plus samples across plus/minus PlayerHalf 6).

Today: `act.nim:214` `(bot.tick div 8 + bot.slot div 2)` (serpentine) and `act.nim:111` `(bot.tick div 12 ...)` (threat jink) are bare literals, in no experiment and no ledger entry; no module holds our own velocity (`world.nim:106` keeps `lastPos` for stuck detection only). Three rationales quote top speed 2.75 px/tick; none quotes Accel.

Ladder: lift `WeaveFlipTicks* = 8` and `JinkFlipTicks* = 12` at today's values (inert; gameHash batch). **Rung 1, WeaveFlipTicks alone** -- the serpentine lives in chooseMovement's navigate branch and touches no gun, goal or turret. Rung 2, JinkFlipTicks (the ThreatRange branch claims the whole frame). Rung 3, centre the first half-period to kill the drift.

Risk: the physics does not pick a direction. The bullet is hitscan, so the only dodge window is the shooter's 5-tick windup against a linear lead, where deviation is accel-bound near 4.5px whatever the period -- a longer hold is more predictable, a shorter one puts a reversal inside more windows. Measure one, then the reverse.

*Event rate (the verifier's own estimate, which decides whether a 120-episode screen could see it):* The weave gate is `abs(f.me.x - CenterX) < WeaveBand` (280.0) for any rushing seat -- the middle 560px of a 1235px map, crossed by six attacking seats on every one of three lives. Order 10^3 weaving ticks per team per episode, i.e. hundreds of sign flips per seat; comparable to steer-dither-quarter's population, which experiments.py calls the highest event rate in this area. A 120-episode screen (0.046 K/D) can see it if the per-flip effect is not ~0.

### 8. `self-loadout-is-guessed-from-other-players-markers`
**Self loadout is guessed from other players' markers.** The engine publishes each seat's own hands twice and authoritatively: the HUD readout `weapon gun|spray` (`.engine/src/ctf/global.nim:5428-5435`, whose own comment says a bot inferring its weapon from floating markers "gets it wrong at the worst moments"), and the identity badge, which is exempt from the fog gate for its owner (`global.nim:4940`, `i != viewerIndex`) and carries `[ shield][ nade] <weapon>` on object id `IdentityBadgeObjectBase + i`.

Today `labelkind.nim:131-174` has no `LabelPrefixWeapon` arm, so the readout is `lkOther` and never reaches the frame index. Loadout is inferred by radius: `sense.nim:116-120` and `grenades.nim:31-35` both accept any `*Carried` marker within 30.0px. The marker centre sits at owner + (7,-26) = 26.93px, so 3.07px of slack — any VISIBLE carrier in a 30px disc centred ~27px below-left reads as us (`PlayerHalf` is 6; `MateSpacing` 40 is a soft steer term). `perception.nim:84-118` already parses these tokens off the badge for everyone else; ours never matches because `actorsFor` pairs badges to `player <color>` sprites and our body ships as `self <color>` (`global.nim:5285-5295`).

Ladder, gated by `SelfLoadoutMode = 0`. Rung 0 need not be the badge: the markers are object-id keyed (`PaintBombCarryObjectBase = 19360 + i`), so `o.objectId == base + bot.slot` is exact. **Measure `f.carryingNade` first** — ~80 grenade pickups a match against ~7 of everything else (LEDGER `nadefarm420`). `f.hasPlasma` is the rare one. There is no `f.hasShield` rung: `bot.hp > MaxHp` is already exact and `shield carried` is unreachable (`sim.nim:7446`).

Risk: a phantom nade is not self-correcting — `act.nim:25` re-enters on `bot.nadeCharge`, buying up to 24 ticks of `holdStill`. Count disagreement frames in a logging run before buying episodes; near zero makes this a cleanup, not an experiment.

*Event rate (the verifier's own estimate, which decides whether a 120-episode screen could see it):* Grenade markers are the densest carry family on the map: LEDGER's `nadefarm420` rationale prices corner grenades at ~80 pickups a match against ~7 of everything else, and both nade-farm promotions widened the flankers' appetite further. So carrier-visible frames are plentiful; what is unmeasured is the geometric coincidence rate — a visible carrier inside the disc dx in [-37,+23], dy in [-4,+56] relative to us. Even a 1% rate over the carrier-visible frames of eight seats is several phantom charges an episode, each up to 24 ticks of standing still, which is inside what a 120-episode screen resolves (0.046 K/D). The spray half is not: two experiments that rewrote the ENTIRE plasma-carrier state (`plasma-no-duck` +0.013 CI [-0.035,+0.060]; `plasma-no-lead` +0.009 CI [-0.014,+0.033]) both read level at n=120, which bounds how much of an episode that state occupies. So a 120-episode screen c

### 9. `own-remaining-lives`
**Own remaining lives are printed and never parsed.** Three lives per seat, the third death permanent: `sim.nim:7426-7431` decrements then writes `respawnTimer = 0` at zero, `respawnPlayers` skips `lives <= 0` (`sim.nim:9528-9530`), and a team with no live-or-respawnable player loses outright (`teamHasLivePlayers`, `sim.nim:8996-9001`; wipe branch of `checkWinCondition`, `sim.nim:9038-9052`). The count is in the same HUD string the policy already parses for hit points: `livesText = $(hp + shieldHp) & "hp x" & $lives` (`global.nim:5403-5404`), emitted alive or dead.

`sense.nim:198-208` cuts the string at `"hp"` and throws the rest away. `grep -rn lives bot/baseline` finds no other reader; `Bot` has no lives field and no constant depends on one. The policy plays its third life exactly as its first.

The state is not rare. `analysis/role_bleed.md` (gv-current, 3160 episodes): 78.7% red / 81.7% blue of seat-episodes spend all three lives, 93-99% for the five mid seats.

Ladder, behind `LastLifeMode = 0` (parse landed, consumed nowhere, gameHash-identical). **Do not start with the med-kit reach.** Making a last-life seat use `MedKitCriticalReach` 180 instead of `MedKitDetour` 120 is a smaller dose of `medkitdetour120-further` (120 -> 160 for everyone), which read level at n=120, CI [-0.031,+0.025], on the most-swept axis in the tree. Start with a consumer that has no measured sibling and fires on ordinary combat frames: a wider `DuckRange` for a last-life seat, or declining the peek step. `f.pocketRush` exclusion (`engage.nim:37-40`) is the cheap-consumer trap — it fires for one seat inside 210px.

Risk: last-life is confounded with late game, so a 'play safer' rung may only move the moment of a loss already decided.

*Event rate (the verifier's own estimate, which decides whether a 120-episode screen could see it):* The STATE is the most common thing in this batch. `analysis/role_bleed.md` (gv-current, 3160 episodes) puts 'spent all 3 lives' at 78.7% red / 81.7% blue of seat-episodes and 93-99% for the five mid seats, with mean deaths/seat ~2.7 — so effectively every seat enters `lives == 1` and stays there for the last stretch of its episode. Across eight seats that is thousands of last-life frames an episode. A consumer that reads on those frames (duck range, peek decline, target demotion) is comfortably inside a 120-episode screen's 0.046 K/D. A consumer gated on the two centre-line med kits is not: it fires a handful of times an episode across eight seats, on an axis already measured flat between 120 and 160. The state is free; the whole question is which consumer.

### 10. `the-shield-is-a-resource-nobody-collects`
**The own-side shield is a resource nobody collects.** `tryPickupShields` (`sim.nim:8259-8287`): either team may take either endzone's shield, and a carrier whose layer is worn (`shieldHp < ShieldLayerHp`) may top it up. The layer absorbs before base hp (`absorbDamage`, `sim.nim:7434-7449`) — 3 extra hp on a 3 hp body — at `ShieldFireSlowdown = 3`, which does not stack with the carrier penalty (max, not product, `sim.nim:289-299`). Each team's spot sits at `(ArenaBorder + GrenadeSpawnInset, 3 * height div 4)` = x 50 (`sim.nim:6848-6878`), inside that team's own capture zone — the same zone `randomEndzonePosition` draws every respawn from (`sim.nim:5990-6018`).

`objective.nim:192-212` is the whole of the policy's shield code: one role (`MidGuard`), one spot (`if homeSign(team) * (shieldPos[i].x - CenterX) > 0.0: continue` skips ours), one budget (`ShieldStealDetour = 480`), and `not f.hasShield`, which declines the top-up in the only state the engine allows. `sense.nim:74-105` already seeds and tracks both spots, so nothing is missing but the clause.

Supply is ~10 shield-lives an episode (2 spots, `ShieldRespawnTicks = 720`); LEDGER `shieldflank` records uptake at 'about 13% of the time'.

Ladder: `OwnShieldDetour = 0.0` in tuning (no budget = the clause cannot fire = gameHash-identical, the `OneWayBonus` shape), then widen. **The seat-set rung is closed** — `shieldflank` added FlankTop to the enemy-side trip and read level, K/D -0.0147 CI [-0.063,+0.034], n=120. Budget against the column's HEIGHT: `layoutSides` capture zones are full-height (`sim.nim:2444-2449`), MapH 659, shield at y ~= 494, so 120 only reaches a respawn drawn low.

Risk, and it is known and adverse: `f.hasShield` clamps `f.maxEngage` to `CarrierFireRange = 180` (`engage.nim:50-51`), so every seat this arms also stops fighting at range. Whether the layer beats the 3x cooldown has never been measured; the same constant that turns the clause on turns it off.

*Event rate (the verifier's own estimate, which decides whether a 120-episode screen could see it):* Supply: 2 spots x `ShieldRespawnTicks = 720` over a ~3500-3900 tick episode is ~10 shield-lives an episode. Uptake today: LEDGER `shieldflank` says the shield is taken 'about 13% of the time', and `nadefarm420`'s rationale prices ALL non-grenade pickups at ~7 a match combined against ~80 grenades — so most of that supply expires, and our own side's spot claims none of it by construction. An own-side clause is capped by the respawn cadence at ~5 claims an episode for our team and would realistically make 2-4, each worth 3 hp of absorb against a team total of ~21.6 deaths x 3 hp. That is a 10-20% swing in effective team hp, comfortably inside the 0.046 K/D a 120-episode screen resolves — in either direction, because the same seats stop fighting past 180px. The nearest measured point (`shieldflank`, one extra seat on the enemy-side trip) sat at -0.015 +/- 0.048.

### 11. `fog-run-visibility-mask`
**The per-frame visibility mask the server already ships.** Every living viewer receives the exact complement of its own fog grid as labelled `"fog"` run objects: `global.nim:5203` calls `addFogRuns`, which (`global.nim:2757-2792`) emits one object per maximal DARK run per grid row at `(run.cx*8, run.cy*8)` with sprite width `run.width*8` and def label `"fog"` (`global.nim:2841`). It is the same grid the entity gates read — `fovVisibleAt` (`sim.nim:8836-8845`) indexes `fovCaches[i].visible`, and `playerVisibleTo` (`sim.nim:8847`) is that call on the target's centre — so "this cell carries no fog run" is exactly "a living player standing there would be in this frame's packet". 83 rows on the arena, so ~150-350 objects a frame against `FogMaxRuns = 2048` (`global.nim:431`).

Today: no `"fog"` arm in `classify`, so `protocols.nim:268` drops every run — `perf.patch:200`'s measured label diff lists `fog` as unread. The bot has no negative information at all: `memory.nim:82-89` prunes tracks on `TrackHoldTtl = 400` alone, and `fov.nim` runs only at nav-build (`posts.nim:149`).

Ladder behind `VisionMaskMode = 0`, `when`-gating the classify arm so the wire stays byte-identical: (1) track disproof — lit cell, no sighting, track deleted; (2) same test on sonar pings and heard shout fixes before `PreAim*Cost` weighs them; (3) invert the cone edge for true `aimBrads`; (4) sweep toward the largest dark region. Measure (1) first: same consumer shape as `corpse-track-cleanup` (+0.096 K/D, LEDGER.md:1088-1114) with an exact trigger needing neither the scoreboard nor the sonar clock.

Risks: a ghost frame carries NO runs and decodes as "all lit" — gate the reader on `alive`, and note `decide.nim` calls `updateTracks` while dead. A disproved track may have moved, not died. Skip the disproof when `countOf(lkFog) == FogMaxRuns`. Hosted cost is the frame-index append only (the objects are already walked and dropped at `protocols.nim:268`); LOCAL cost is large and new, since `perf.patch:707` suppresses the overlay entirely today — expect materially slower sim throughput at mode > 0, on both arms, since `simulate.nim:118-120` ORs both builds' `readsLabel`.

*Event rate (the verifier's own estimate, which decides whether a 120-episode screen could see it):* Fires on literally every frame of every living seat: ~1747 ticks x 8 seats ~= 14k mask reads per episode (mean episode length measured over episodes/exp-corpse-track-cleanup.jsonl, 400 records — note the finder's "~3494 ticks" double-counts ticks+gameTicks). Rung-1 disproof events are bounded by track count (<=8, TrackCap) times the frames a stale track's cell falls in the cone; with the scan sweep raking the arc continuously and tracks held 400 ticks, that is tens to hundreds per seat per episode — strictly more often than corpse-track-cleanup's trigger (~2.7 own kills per seat per episode) which moved K/D +0.096. A 120-episode screen resolving 0.046 K/D can see this comfortably; frequency is not the risk here, consumer choice and per-frame CPU are.

### 12. `damage-pop-death-and-hit-events`
**Deaths and hit points are announced on the wire; the policy infers them from the scoreboard instead.** Every HP loss inside the viewer's vision arrives as a floating sprite whose label carries the VICTIM's team colour and the amount — `"damage pop <color> -N stage <s>"`, and for a fatal hit `"damage pop <color> KO stage <s>"` at the exact death centre (`global.nim:5117,5136`; payload semantics `sim.nim:855-864`; fog gate `global.nim:5105`). Emitted for every weapon: `sim.nim:7403` (KO in `killPlayer`), `7888` (gun), `7599` (spray), `8118` (grenade). A second marker, `"splatter <color> stage <s>"` (`sim.nim:7390-7396`, `global.nim:5020`), sits at the same spot for `SplatterFxTicks = 120`.

Today `classify` has no arm for either — `perf.patch:200`'s measured label diff lists `damage pop *` and `splatter *`. Instead `sense.nim:152-196` diffs the map-wide scoreboard and, on our kill count rising, marks the freshest unclaimed heard landing `foe` and deletes the nearest track within `CorpseClearRadius` (40px). `sim.nim:7820` is the ONLY `recentShots.add`, so spray and grenade kills leave no ring, and the scoreboard delta then consumes an unrelated shot's ring.

Ladder behind `DeathPopMode = 0`: (1) enemy-colour KO clears the nearest enemy track — the consumer that already paid +0.096 K/D (LEDGER.md:1088-1114), now exactly located, weapon-agnostic, and needing neither the scoreboard nor the sonar clock, so the radius can drop from 40px toward ~16; (2) own-colour KO marks that spot hot; (3) enemy `-N` banks a zero-doubt fix for the pre-aim scorer and the shout payload; (4) own-colour `-N` in view as a threat-direction cue into the peek branch; (5) the 120-tick splatter as a walk-up-later marker. Measure (1) first.

Rates from the banked corpus (400 episodes): 43.1 kills and 116.1 gun hits per episode over ~1747 ticks. Risks: these labels are chrome, not contract — `labels.nim:57-65` explicitly refuses them a stability promise, so the arms need local constants and get no rename guard. The seen-fraction of other players' deaths is not instrumented. Spell the arms as full prefixes (`"damage pop red KO"`) so no frame compares a string.

*Event rate (the verifier's own estimate, which decides whether a 120-episode screen could see it):* Measured off the banked corpus (episodes/exp-corpse-track-cleanup.jsonl, 400 episodes, awk over the seat records): 43.09 kills and 43.09 deaths per episode, 46458 shotsHit / 400 = 116.1 gun hits per episode, over a mean 1747 ticks — the finder's kill and hit numbers are right, its tick count (3494) double-counts ticks+gameTicks, which makes the event DENSITY twice what it claimed. Per seat that is ~2.7 own kills plus witnessed ones for rung 1, and ~7 own gun hits plus spray/grenade damage for rung 3. Rung 1 therefore fires at least as often as corpse-track-cleanup's trigger and strictly more (weapon-agnostic, no scoreboard delta and no sonar clock lock required), and that mechanism moved K/D +0.096 at n=400. A 120-episode screen resolving 0.046 K/D can see a consumer of this rate; the open question is the seen-fraction of OTHER players' deaths, which nobody has instrumented.

### 13. `grenade-sound-and-blast-rings`
**The through-wall grenade channel: heard landings.** A blast the viewer could NOT see is still delivered, as a jittered `"grenade sound"` ring: `global.nim:4755-4799` emits `"blast stage <n>"` at the exact landing when `mapVisible`, and otherwise (`elif viewer >= 0`) the sound ring at `blast.x + dx, blast.y + dy` with `|dx|,|dy| <= SoundRingJitter = 20` (`global.nim:244`). The proc says so itself (`global.nim:4652`).

Today the policy sees grenades only when it can see them: `grenades.nim:140-149` scans `lkThrowTarget` and `lkGrenadeAir` for `f.nadeDanger`. `LabelGrenadeSound` and `LabelBlastStagePrefix` sit in the vendored vocabulary (`labels.nim:104,109`) with no `classify` arm and no consumer — `perf.patch:200` lists both as unread. The only through-wall sense the bot has is the gun's landing ring, whose shooter is anywhere on a clear line; a grenade ring's thrower is within `GrenadeMaxRange = MapWidth div 5` = 247px of the mark, and the mark is where an enemy believed one of ours was standing.

Ladder behind `NadeSonarMode = 0`: (1) bank the ring as a `Ping` with its own flag and its own cost beside `PreAimPingCost`, reusing `hearShots`' position-dedupe (`perception.nim:201-232`); (2) larger hot radius, shorter TTL, on the throw-range argument; (3) feed `grenades.nim` as counter-battery; (4) `blast stage` as a landing confirm for our own lobs. Measure (1) first: it moves one weight in an already-tuned scorer, so a level result is interpretable.

Risks, in order. Frequency is unmeasured — supply bounds it at ~62 grenades per episode (`sim.nim:254`, four corners, mean 1747 ticks; `tuning.nim:290` says ~80 a match) but nobody has counted blasts; count them locally before buying episodes. `BlastFxTicks = 12` (`sim.nim:266`) means the ring lives ~0.5s, so it needs its own TTL rather than the shot ring's. And our OWN unseen landings ring too: the existing `OwnNadeRingSlack` filter works off the charge preview, which is gone by detonation, so a new remembered release point is required or every seat manufactures an enemy fix on its own throw.

*Event rate (the verifier's own estimate, which decides whether a 120-episode screen could see it):* NOT measured, and this is the weak leg — the banked episode records carry `shotsFired`/`shotsHit` but no grenade counts, and I ran nothing. Bound from supply: 4 corner spawns with `GrenadeRespawnTicks = 5*ReplayFps` (sim.nim:254) over a measured mean 1747-tick episode gives at most 4 + 4*(1747/120) ~= 62 grenades available per episode, and the policy's own note (tuning.nim:290) puts it at "~80 grenades a match against ~7 of everything else"; the farm behaviour is real and was promoted twice (`nadefarm420`, `nadefarm420-further`). At even a third conversion that is ~20 blasts per episode, and each blast is invisible to most of the 16 viewers, so ~200 seat-events per episode — well inside what a 120-episode screen could see. But the count is inferred from supply, not observed. Instrument a blast counter in one local episode before buying anything: if it comes back in single digits, this is

---

# Constraints on ideas — not ideas themselves

These exist so the next reader does not spend a slot re-deriving them. Every
one was paid for.

## Confirmed dead ends — do not re-derive

- **Banking sonar while dead.** Ghost (dead-viewer) frames carry no shot-impact
  rings (`addShotImpactRings` is gated on not viewerIsGhost); hearing the map
  from the respawn queue is a no-op by construction.
- **Trench awareness.** Trenches are cosmetic floor art — no sprite label,
  absent from walkability; unreadable by a headless policy.
- **Reading a mate's aim direction.** GV24 fuzzes every other soldier's
  rendered gun rotation by ±14 brads; unreadable BY DESIGN. See tuning.nim.

## Premise corrections — the source was wrong

- **The operator's asymmetry brief overstates red's tie advantage.** Audited
  against the pinned engine (1047232, GV30): slots ALTERNATE red/blue and
  `players[]` index is slot order, so red seat k beats blue seat j only when
  k <= j — 36 of 64 seat pairs, not all. Pickups ARE index-ordered, so the edge
  is real there. **Combat is explicitly NOT** ("no processing-order advantage",
  twice in the engine source), so it cannot be cashed in a firefight.
  **Choke body-blocks have no lever** — the bot never enters enemy bodies into
  its nav grid, so it already takes every shove — and the sign is backwards
  anyway, since HomeDefender sits at seat 7 on both teams. **Flags are never
  cross-team contested.** The two centre-line med kits are the only contested
  cross-team pickup on the map.
- **The diamond band is real and correcting it is worse.** The frozen
  walkability snapshot genuinely misrepresents eight live spinning diamonds,
  and BOTH scopes tested regressed by ~0.08 K/D — the full mask paint and the
  shot-gate-only version. Any paint scale below ~0.71 is a provable no-op. Do
  not re-propose this without a mechanism that is not "block rays through the
  swept disc".
- **The one-way fog term does not generalise.** It is promoted and paying for
  PEEK posts and it REGRESSED on the defender's hold point. "The mechanism is
  good, apply it everywhere it could apply" is not supported here.

## Traps in the machinery

- **A knob experiment naming a constant that is not in `tuning.nim` matches
  nothing and abandons its slot.** Currently absent despite appearing in older
  notes: `ScanArc` (split into `ScanArcRed`/`ScanArcBlue` on 2026-07-31),
  `EscortScreenDist`, and the four in (8). Check with grep before proposing.
- **The loop cannot land an inert patch.** `apply_edits` works on a scratch
  copy, `land()` runs only from `promote()`, and `commit()` stages `bot/` only
  on a promotion — so a provable no-op measures level, is rejected, and is
  discarded. Every feature in this file that wants to "land inert + knob" must
  be landed by a DIRECT COMMIT, with inertness proven by gameHash equality
  over a batch of seeds (see the ScanArc split for the pattern).
- **A screen is triage, not a finding.** Five stage-1 screens on 2026-07-31
  bought episodes and all five came back level or negative — one after its win
  rate SEPARATED positive. The seed-paired bootstrap sees within-batch variance
  and is blind to the terrain and spawn draw the batch fixes. Quote pooled
  numbers only.

## A null worth more than most promotions: `ghost-flag-thief`

Mechanic 1 of the source hunt above is landed (`GhostFlagMode`, `db7eca1`),
its premise is confirmed, and its first rung measured **exactly zero — every
episode bit-identical**. That combination is rare and it localizes something
no amount of tuning would have found:

- The mechanic is real. A ghost frame carries our own flag's carried banner
  with the carrier-visibility test bypassed, and an instrumented build at mode
  1 took **11867 thief fixes in four episodes**. The intel arrives.
- Nothing consumes it. Every consumer gates on
  `bot.tick - bot.carrierSeen <= ThiefFixTtl` **and** `f.ownStolen`, and
  `f.ownStolen` is recomputed on the first live frame from the planted banner.
  Bit-identical episodes mean the pair of conditions never once differed from
  the control's — i.e. by the time a seat is alive again, our flag is back on
  its pedestal essentially always.
- Mode 2 is the control for that argument: banking the MATE-carrier fix off
  the same frames was NOT bit-identical (K/D −0.0008, captures −1), so the
  ghost path itself works and it is specifically the thief fix that has no
  reader.

What that says about the policy is bigger than the experiment: **the whole
thief-hunt apparatus — `ThiefFixTtl`, `ThiefFocusBonus`, the every-role
convergence in `objective.nim`, the engage-cap lift in `engage.nim` — is
tuned for a situation that resolves faster than a 72-tick respawn.**
`thieffocus600` measuring exactly zero said the same thing from the other
side. Two independent exact zeros on one mechanism is not noise.

So the open question is no longer "how do we see the thief" — it is whether
a steal against this policy is ever live long enough for any of that
machinery to matter, and the honest next step is an episode read (how long
does our flag stay off its pedestal, and how often is a seat dead at the
time?) rather than another experiment. Note the hosted replay analysis
disagrees with the local mirror here: it makes enemy captures our single
biggest loss bucket against the FIELD. Both can be true — in a mirror both
sides run the same defence.
