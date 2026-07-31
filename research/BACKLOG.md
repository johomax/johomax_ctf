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

1. **Shout channel, emit + parse.** The single biggest known gap, and still
   nothing is written. Every player ranked above us broadcasts constantly
   (James Boggs 464 shouts in 2 games; daveey and NanosaurusX share an
   "E<gx> <gy>" enemy-fix vocabulary); nobody we beat shouts at all. Shouts
   are <=10 chars, ~247px audible through walls and fog, 1/sec, sent as
   `SpriteClientChatMessage` on the existing websocket, and readable via the
   team-prefixed label already in the vendored labels.nim. All 8 seats run one
   policy, so a private vocabulary works immediately: emit fresh enemy
   sightings, parse teammates' shouts into `memory.updateTracks`. ~150 lines.

2. **Shout eavesdropping.** The shout label carries the speaker's team, and the
   top players' vocabularies are cleartext grid coordinates — an enemy "E12 4"
   within earshot is free intel about where THEY think WE are, and where their
   attention is. Parse hostile shouts only; no emit, so this is a smaller
   first slice than (1).

3. **1px "lattice peeking".** Visibility flips discretely at 8px cell
   boundaries, so a one-pixel step can grant a sightline the reverse position
   lacks. The last of the four one-way fog cousins with no experiment — the
   other three are in the catalogue, and `chokeHold` is decided (it regressed;
   see LEDGER.md, and read the warning under "Premise corrections" below
   before assuming the one-way term generalises).

4. **Blue-specific unmirrored play.** The bot mirrors its landmarks and plays
   the "same" game on both sides, conceding the fog/nav seams by construction.
   What this asks for is side-specific post tables, lane weights and peek cells
   against the ACTUAL asymmetric visibility — NOT per-side knob values, which
   are now plumbed and measured for one constant. **Gated on (9).**

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

7. **Per-side splits of any constant other than `ScanArc`.** The
   `NameRed`/`NameBlue` plumbing plus team-indexed selector is landed and
   proven inert, so splitting another constant is a direct commit plus a plain
   knob experiment. `ScanArc` is done and found NO side difference (blue 32,
   red 32, red 24 all level), so pick a constant with a reason to differ by
   side — the detour budgets and the hold-line depth are the brief's
   candidates. Read a per-side result by DOUBLING it; see LEDGER.md.

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

9.  **Per-role bleed instrumentation.** The sim records per-seat kills and
    deaths already; aggregate by role and side to localize where blue's deficit
    concentrates. Gates (4) and sharpens everything else. Must not change
    `bot/` — a policy change would make every banked episode non-comparable.

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
