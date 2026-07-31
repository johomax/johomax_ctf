# Idea backlog — proposed this session, never measured

Everything below was raised on 2026-07-31 and did NOT get an experiment: no
mirror was bought, no verdict exists. Nothing here is evidence of anything;
that is exactly why it is written down. Sources: the operator's asymmetry
brief, two deep-read ideation passes (the second steered by the operator),
replay analysis of 31 v76 games against the ladder, and driver-session notes.
The decided record stays in LEDGER.md; when one of these runs, it moves there.

## Features (bigger than one variable; land inert + knob, like fov.nim did)

1. **Shout channel, emit + parse.** The single biggest known gap. Every
   player ranked above us broadcasts constantly (James Boggs 464 shouts in 2
   games; daveey and NanosaurusX share an "E<gx> <gy>" enemy-fix vocabulary);
   nobody we beat shouts at all. Shouts are <=10 chars, ~247px audible
   through walls and fog, 1/sec, sent as `SpriteClientChatMessage` on the
   existing websocket, and readable via the team-prefixed label already in
   the vendored labels.nim. All 8 seats run one policy, so a private
   vocabulary works immediately: emit fresh enemy sightings, parse teammates'
   shouts into `memory.updateTracks`. ~150 lines.
2. **Shout eavesdropping.** The shout label carries the speaker's team, and
   the top players' vocabularies are cleartext grid coordinates — an enemy
   "E12 4" within earshot is free intel about where THEY think WE are (and
   where their attention is). Parse hostile shouts too; no emit required, so
   this may be a smaller first slice than (1).
3. ~~**Diamond-band mitigation.**~~ **MEASURED 2026-07-31, REJECTED.** The
   premise was verified true against the pinned engine (GV30: eight diamonds,
   r 30, cx 565/669, restamped every 4 ticks, walkability sprite sent once at
   connect) — the bot really does fight mid against a frozen silhouette. The
   fix is still worse than the flaw: painting the swept discs measured K/D
   −0.0815 CI [−0.1258, −0.0351], win rate −0.183, captures −17 at n=120,
   all three separating negative. See `diamond-sweep-paint` in LEDGER.md.
   The lesson is about SCOPE, not about the geometry: the walkability mask
   is read by pathing, cover/duck/peek selection, exposure costing AND shot
   clearance, so painting wall made four things conservative at once and the
   routing cost swamped the shot-honesty gain — in the middle third, which
   is exactly where the replays put 73–90% of our deaths. What is still
   open is the shot-clearance half ALONE. Note also that any paint scale
   below ~0.71 is a provable no-op: the intersection over all spin frames is
   a subset of the single frame that was baked, so the snapshot already
   contains it.
4. **One-way fog, remaining cousins** (v78 shipped only the post-scoring
   term): shoot-through-cover posts (cells >=50% wall block VISION entirely
   but pass bullets through their wall-free slivers); 1px "lattice peeking"
   (visibility flips discretely at 8px cell boundaries, so a one-pixel step
   can grant a sightline the reverse position lacks); and target-set geometry
   for the existing term (the diagonal mid-range retarget was the first
   thing that worked, not the best thing — lane bands, choke exits and
   pedestal approaches were never scored).
   `chokeHold` — the fourth cousin, and the one the plan named and the
   implementation never wired — is **MEASURED 2026-07-31, REJECTED**: K/D
   −0.0612 CI [−0.1017, −0.0220] at n=120, a regression. The one-way term
   pays for PEEK posts (OneWayBonus 40 promoted) and costs on the defender's
   hold point, so "the term is good, apply it everywhere it could apply" is
   not supported. See `chokehold-oneway` in LEDGER.md.

## Side asymmetry (operator brief, parts 2 and 3 — untouched)

5. **Red-specific greed.** ⚠️ **THE BRIEF'S PREMISE IS PARTLY FALSE — audited
   against the pinned engine (1047232, GV30) on 2026-07-31.** The claim was
   "red wins every same-tick contested tie (processed first)". What the
   engine actually does:
   - Slots **alternate** red/blue (`teamForSlot` returns
     `Team(order mod teamCount)`, and `league_config.json` alternates), and
     `players[]` index equals slot order. So red seat k is index 2k and blue
     seat j is index 2j+1: red wins a tie **iff k <= j**, which is 36 of 64
     seat pairs (56%), not all of them. Red does always beat its own mirror
     seat.
   - **Pickups are** index-ordered (`tryPickupFlags/Grenades/MedKits/...`
     over `0 ..< players.len`, resolved after all movement), so the edge is
     real *here*.
   - **Combat is explicitly NOT.** The engine resolves every shot released
     on a tick against one post-movement snapshot, and says so in two
     comments: "no processing-order advantage". So "guaranteed 50/50 races"
     cannot be cashed in a firefight at all.
   - **Choke body-blocks: no lever, and the sign is backwards.** Body-block
     is index-ordered, but the bot never enters enemy bodies into its nav
     grid (only posts and remembered tracks as exposure cost), so it already
     takes every shove the engine grants. And `roleForSeat` puts HomeDefender
     at seat 7 on both teams, so red's index-14 defender is shoved by all
     eight blue players — the effect favours the attacker on both sides,
     symmetrically.
   - **Flags are never cross-team contested**: `tryPickupFlags` skips a flag
     of the player's own team, so the two teams never race for one object.
   - What survives: the **two med kits are the only centre-line, cross-team
     contested pickup on the map** (both at `x = width div 2`; shields and
     plasma arcs are one-per-team in the endzones, grenades are corners).
   Queued as `red-kit-greed` on that surviving basis. The choke-body-block
   half of the brief is retired.
6. **Blue-specific unmirrored play.** The bot mirrors its landmarks and
   plays the "same" game both sides, conceding the fog/nav seams by
   construction. Side-specific post tables, lane weights and peek cells
   against the ACTUAL asymmetric visibility. Prerequisite: the per-role /
   per-seat K/D bleed table below.
7. **Per-role bleed instrumentation.** The sim records per-seat kills and
   deaths already; aggregate by role and side to localize where blue's
   deficit concentrates. Measurement tooling, not a policy change — it gates
   (6) and sharpens everything else.
8. **Per-side knob values.** The general mechanism behind (5) and (6): let
   any existing tuning constant take a different value per team —
   HoldLineKills, the detour budgets, ScanArc, the hold-line depth — since
   red's tie-priority and the asymmetric fog seams mean the optimum need
   not be the same number on both sides. Plumbing: tuning.nim constants are
   compile-time consts and the bot learns its team at spawn from slot
   parity, so a side-conditional knob needs a small refactor (a
   `NameRed*`/`NameBlue*` pair plus a team-indexed selector, spelled so the
   catalogue's knob regex still matches each side's literal). Each
   experiment stays one variable — move ONE side's value, leave the other
   at the shared default — and the seed-paired mirror measures it as usual
   because every mirror puts the build on both teams. Every knob the loop
   has ever promoted doubles into two askable axes the moment this lands.

## Knob axes introduced but swept at exactly one value

**CORRECTION (2026-07-31): items 8–11 are NOT runnable as written, and the
entries below were wrong to list them as axes.** A knob experiment edits a
constant in `tuning.nim`. `EngageStrafeBlend`, `CooldownSweepArc`,
`DuckStandoffWeight` and `WipePushKills` were each introduced BY a patch that
was then REJECTED — so the constant never landed, it is not in the tree, and
a knob edit against it matches nothing and abandons the run. To sweep any of
them, the introducing patch has to be re-proposed carrying the new value, as
one experiment. Listing a rejected patch's parameter as an available axis is
a trap this file set for its own reader; it cost nothing only because the
loop's dry-run catches an edit that matches zero times.

8.  ~~`EngageStrafeBlend`~~ — not in the tree (combat-strafe rejected).
9.  ~~`CooldownSweepArc`~~ — not in the tree (cooldown-sweep rejected).
10. ~~`DuckStandoffWeight`~~ — not in the tree (duck-standoff rejected).
11. ~~`WipePushKills`~~ — not in the tree (wipe-push rejected).
12. `CorpseClearRadius` — **40 MEASURED AND SHIPPED 2026-07-31**: K/D +0.0307
    CI [+0.0060, +0.0567], captures +39 CI [+13, +65] at n=400, shipped as
    v79. So the axis is 40 (best so far) < 80 (previous ship) with 160 level,
    and the promotion's own direction is now DOWNWARD. 20 and 120 unasked;
    the loop declines to auto-propose 0 because that switches the mechanism
    off rather than tuning it.
13. `EscortScreenDist` — measured "level" at 70 with EXACTLY-ZERO gaps: the
    escort-screen-with-remembered-threat branch never fired in 240 episodes.
    The idea here is not another value — it is finding out why the branch is
    dead (threat memory empty during escorts?) and whether the screen can be
    made real.
14. `PreAimWatchRange` (200) / `PreAimWatchTtl` (30) — the keeper's
    leave-the-sweep gates, siblings of the scan family that paid twice
    (ScanArc +0.16 K/D total); noted as candidates when ScanArc promoted,
    never queued.
15. **clock-phased-wave's parameter plane.** The patch ran level at exactly
    one point (period 300, one phase in three released) and the two
    parameters are coupled, which is why it stayed a patch. One level point
    does not clear a plane; a couple more (period 150/600, duty 1/2) would.

## Re-asks the engine move invalidated

16. **pushout-hold-conflict under the current engine.** Rejected under GV27
    (K/D −0.016, win rate leaning +0.050 unresolved) — but the replay record
    shows the failure it targets happening in production: 4/4 timeout draws
    against Rohit while behind on kills, zero enemy-third deaths. The one
    GV27 reject with hosted evidence pointing the other way.
17. ~~**DuckRange 340→260**~~ — **MEASURED 2026-07-31, REJECTED IN BOTH
    DIRECTIONS.** 260 was level (K/D −0.0169 CI [−0.0416, +0.0069], n=400);
    the loop then auto-proposed 420, which escalated on a near miss, bought
    its one extension, and came back level too (K/D +0.0102 CI [−0.0097,
    +0.0297], n=600). Worth reading as a warning about point estimates: 420
    showed +0.028 at n=120 and decayed to +0.010 by n=600. The knob is flat
    either side of 340 and needs no further episodes.
18. **ScanArc interior probes** (26, 30) — 28 stands on cliffs at 24/20 and
    a level 32; the optimum was bracketed, never localized. Low value; listed
    for completeness.

## Refinements implied by measured rejects

19. **findPeekCell, friendly-corridor aware.** mate-masked-peek rejected
    level, and its own risk note says why it could not work: the peek-cell
    search tests wall rays only, so the sidestep it buys is unguided with
    respect to the blocking mate. Teaching findPeekCell to score candidate
    cells by whether the FRIENDLY corridor clears is the version the reject
    did not test.
20. **Considered and dropped without a measurement**, one line each:
    `CarrierFireRange` sweep (dropped on the prior that carrier changes ran
    level twice); `BackGuardArc` (96) sweep; the engagement-scoring bonuses
    `HpFocusBonus` / `ThiefFocusBonus` / `TraversePxPerBrad` (dropped on the
    timidity prior, which cuts the other way for AIM constants and was never
    actually tested on them).

## Engine facts verified but never exploited

17. **Both-flags-stolen is a pure race** (capture deliberately has no
    own-flag-must-be-home precondition): when both flags are up, nothing in
    the policy re-weights escort-our-carrier vs intercept-theirs by the two
    carriers' distances-to-home. The race is winnable on purpose.
18. **Draw-conditional endgame.** Timeout is a scoreless lose-lose; the tree
    treats the late game uniformly (LatePushTick, wipe-push both level as
    unconditional switches). Conditioning the all-in on "a draw is otherwise
    likely AND we are not feeding a wipe" was never tried — the two level
    results are consistent with the unconditional versions being wrong in
    both directions at once.

## Instrument and tooling

21. **RED-bias localization.** Local seed-paired mirrors ran RED at 16–40%
    under the stale GV27 pin and 51–65% after the re-pin (hosted ~65%), so
    the inversion is mostly explained — but nobody ever localized which
    seats/phases lose RED's episodes locally, and the residual gap is
    unmeasured.
22. **Policy-side sim speed.** After the GV-current perf patch the policy is
    ~half of remaining sim wall clock; a profile-guided pass over the bot
    (same gameHash discipline) would roughly double iteration speed again.
23. **Paintbot league seating.** The bot is also seated in the new Paintbot
    league (2v2 split-team and 4-team FFA variants, shouts as a game
    mechanic) where the slot-parity team derivation may simply be WRONG.
    Nobody has looked at a single Paintbot episode.
## Confirmed dead ends — do not re-derive

- **Banking sonar while dead**: ghost (dead-viewer) frames carry no
  shot-impact rings (`addShotImpactRings` is gated on not viewerIsGhost);
  hearing the map from the respawn queue is a no-op by construction.
- **Trench awareness**: trenches are cosmetic floor art — no sprite label,
  absent from walkability; unreadable by a headless policy.
