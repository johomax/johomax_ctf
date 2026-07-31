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
3. **Diamond-band mitigation.** The eight live spinning diamonds at mid
   (x 537–697) are collision/bullet/vision geometry EXCLUDED from the
   walkability bake, so the bot fights mid with a false world model — replays
   show opponents land 30–39% of impacts inside the band vs our 16–24%, and
   73–90% of our deaths against the top four are in the middle third. Paint
   the eight swept discs into the bot's walkability copy at nav-grid build:
   restores a truthful (conservative) model, stops phantom-clear shots and
   phantom cover. Small, one-variable-shaped, high prior.
4. **One-way fog, remaining cousins** (v78 shipped only the post-scoring
   term): shoot-through-cover posts (cells >=50% wall block VISION entirely
   but pass bullets through their wall-free slivers); 1px "lattice peeking"
   (visibility flips discretely at 8px cell boundaries, so a one-pixel step
   can grant a sightline the reverse position lacks); target-set geometry
   for the existing term (the diagonal mid-range retarget was the first
   thing that worked, not the best thing — lane bands, choke exits and
   pedestal approaches were never scored); and **the second customer the
   plan named and the implementation never wired**: `chokeHold` — the
   defender hold point is snapped to cover with no one-way term at all, and
   a defender is the seat that camps longest on one cell.

## Side asymmetry (operator brief, parts 2 and 3 — untouched)

5. **Red-specific greed.** Red wins every same-tick contested tie (processed
   first): lean in at guaranteed 50/50 races — center-line medkit grabs,
   choke body-blocks. Marginal by the brief's own estimate; cheap to ask.
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

8.  `EngageStrafeBlend` — combat-strafe was level at 0.6 only; 0.3–1.0 unswept.
9.  `CooldownSweepArc` — level at 15 only; 8–24 unswept (cone bound is 32).
10. `DuckStandoffWeight` — level at 0.5 only; 0.3–0.9 unswept.
11. `WipePushKills` — level at 20 only; 16–22 unswept.
12. `CorpseClearRadius` — 80 shipped (+0.096 K/D), 160 level; 40 and 120
    never asked. The biggest promotion of the session deserves both ends of
    its axis.
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
17. **DuckRange 340→260** — the anti-timidity bet dropped in favour of
    exposedcost10-local and never queued.
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
