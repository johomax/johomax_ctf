# Battle-royale policy port

## What changed

- Expanded the wire colour and label-kind tables to all 16 BR colours while
  retaining the four classic flag families.
- Re-deal every seat from the stated team count, with BR anchor/scout roles,
  and keep all endzone, pedestal, lane, post, respawn and mirrored-landmark
  logic out of flagless BR frames.
- Added a BR objective layer: current/next-zone routing through the nav cost
  field, duo cohesion and long-lived friendly-fire memory, cover holding and
  aim sweeps, bounded med/shield detours, and scoreboard-driven endgame hunts.
- Added BR-only dynamic `hp <hp>/<max>[ shield <s>]` parsing. The legacy exact
  HP groups remain the only groups consumed on classic boards.
- Added conservative BR combat timing/ranges, cover ducking, urgent-zone foot
  priority, and delayed spray/grenade use. The websocket client now requests
  the engine's sprites-off policy stream before the first frame.

## BR smoke

Command:

```text
.sim-build/simulate --engine .engine --config sim/paintbot_br.json --assign aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa --seed 1 --count 5
```

Before (original tree): every one of 32 seats fired 0 shots in every episode,
team kills were 0, and all 150 recorded deaths were environmental. Ticks were
1436, 1545, 1202, 1378 and 1084 (mean 1329).

After:

| Seed | Ticks | Seats firing | Shots | Team kills | Deaths |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 1736 | 21/32 | 151 | 30 | 31 |
| 2 | 3372 | 22/32 | 123 | 31 | 31 |
| 3 | 1458 | 20/32 | 135 | 30 | 31 |
| 4 | 1266 | 23/32 | 124 | 30 | 30 |
| 5 | 1381 | 21/32 | 125 | 28 | 31 |

The mean duration is 1842.6 ticks (+38.6%). A mean 21.4 seats fired per
episode, and 149 kill credits account for 154 deaths. No negative/team-kill
glory penalty appeared in the five records.

## Classic regression

The archived `HEAD` tree was build `b` and this tree build `a` in the same
simulator binary, so both sides used identical engine and simulator code.
All before/after `gameHash` values are identical:

| Config | Seed 5000 | Seed 5001 | Seed 5002 |
| --- | ---: | ---: | ---: |
| `league_config.json` | 3769900552187605975 | 13240903769640498421 | 10801269181771482796 |
| `paintbot_4ffa.json` | 2657845227391962075 | 3990130261539393420 | 8605069616958348474 |
| `paintbot_2v2.json` | 12177306700235300726 | 12447157721624795063 | 16258902863378571925 |

## Walkability fallback

The hosted websocket path drops the pinned BR map's 1,064,474-byte
walkability frame, so the policy now expands `baseline/brmap.nim` after the
camera appears when (and only when) the init marker states 16 teams and
3211x1713. The decoder verifies every row totals 3211 pixels, all 1713 row
terminators and all 19,047 runs are consumed, and the row-major FNV-1a is
`0xC174DA56C64D940B` before publishing the mask. A different stated size logs
one line and stays blind. Readiness is first-writer-wins, so a late real
sprite cannot replace the fallback or rebuild navigation.

`CTF_DROP_WALKABILITY=1` drops the real sprite in `protocols.nim`. On the
first pinned-map packet it independently decoded both sources, asserted all
5,500,443 bits equal, and printed the equality once.
Both policy hosts call the fallback before the existing nav-build gate;
the simulator call is compile-time additive for older policy trees.

Fixed-sprite BR, before and after, using `.sim-build-f/simulate`:

| Seed | gameHash | Ticks | Winner | Seats firing | Shots | Kills / deaths |
| ---: | ---: | ---: | --- | ---: | ---: | ---: |
| 1 | 8944053255938626735 | 1736 | navy | 21/32 | 151 | 30 / 31 |
| 2 | 8841109428881483721 | 3372 | ivory | 22/32 | 123 | 31 / 31 |

The same two runs with `CTF_DROP_WALKABILITY=1` produced the same hashes and
every number in the table. Thus the fallback still moves and fights, while
the real-sprite path is behavior-identical and never invokes it.

Classic `league_config.json` also remained hash-identical before/after:
seed 5000 was `3769900552187605975` (4191 ticks, blue wipe) and seed 5001 was
`13240903769640498421` (4413 ticks, red wipe). The decoder suite reported
138 bytes, 11 valid boundaries, and 128 rejected truncations. A focused
packet test additionally installed the exact fallback, delivered a later
2x2 walkability sprite and confirmed it was ignored, then stated a
16-team 3210x1713 map and confirmed the policy logged once and remained
without a mask.

Release setup profiling (`SIM_TRACE_FROM=-1`, tick cap 3, forced drop) measured
the first full `buildNavGrid` at **20.223 ms**. The other 31 in-process seats
hit the map memo at 0.155-0.204 ms each (0.170 ms mean); all 32 calls totaled
25.500 ms. The validated embedded decode took 6.532 ms and the independent
wire-comparison decode took 6.553 ms. This is far below the roughly 2-second
hosted-clock budget, so no cover/post work was deferred.

Both requested native release binaries built. The websocket episode itself
could not run in this sandbox: `/tmp/ctf_server` failed while binding
`127.0.0.1:2000` with `Operation not permitted`, before any bot could connect.
Consequently there is no honest native websocket kill/tag count from this
environment; the receiver-loop patch remains the separately owned transport
change described in the task.

## Deliberately deferred in v1

- The fixed-map ring route still has seed-dependent duration: two smoke seeds
  resolve before tick 1436 even though the five-seed mean is much later. A
  later pass should tune phase-transition waypoints against a larger seed set.
- Loot routing is intentionally local (250px) and sight-memory based; there is
  no global pickup tour or weapon-specific map route.
- Endgame hunting uses the nearest remembered enemy rather than coordinated
  pincer assignments or opponent-specific threat models.

## v2 fixes

The v2 pass addresses review findings 1-9 and 11 in the policy layers:

- Urgent movement now keeps the exact pixel endpoint, constrains cost-field
  cells to quantized inward bounds of the current rectangle, and falls back
  to a real path toward the reachable in-zone cell nearest the requested
  endpoint. Stable role-separated next-zone points and four-cell goal
  hysteresis avoid rebuilding the field for frame-to-frame target movement.
- Friendly-casualty exposure uses only our colour's death delta. BR sonar
  clock calibration tests at most eight offset candidates per frame.
- Gun targets and every visible or communicated partner fix are projected to
  the five-tick release time. The partner veto covers its reachable capsule
  through the full 1300px corridor and is never waived merely because the
  partner begins beyond the intended target. Grenades use a recent-fix
  reachable-position capsule; a partner fix older than 24 ticks vetoes the
  throw.
- Defensive fire is admitted for a clear threat inside 400px or for 48 ticks
  after damage. Voluntary fire has no opening zero-range or tick-1400 cliff:
  it requires a local 2v1, a covered pre-laid shot with a duck cell, a
  wounded/unshielded target, or a target watched without a plausible shot for
  240 ticks.
- Endgame tracks must be at most 90 ticks old, have a known still-living team,
  and are hunted only while trailing the best living rival in cogs or kills.
  A leading two-cog duo holds separate covered next-zone angles. Anchor/scout
  roles also use opposite jink and weave phases.
- The grenade range is `MapW div 5` only on BR frames (642px on the pinned
  3211px map); classic frames retain the 240px constant and their old paths.

Finding 10 was not changed: `bot/baseline.nim` is transport-owned and was an
explicit do-not-touch file for this pass. Its current assignment remains
after the initial sprites-off send, rather than immediately after
`newWebSocket`.

### Measurement setup

The committed v1 at the start was `def5221`. `main` advanced to `fb79190`
during the work, but `git diff --quiet def5221 fb79190 -- bot/baseline`
confirmed that those commits changed no policy source, so `HEAD@fb79190` in
the v2-v1 output is the same v1 policy. Every BR run had zero lost episodes,
ended in a wipe, and used colour-balanced rotations.

The requested literal stock command does not currently compile because
`sim/host.nim` imports `perception`, while `sim/stock` has no such module.
Both stock measurements therefore used a temporary copy whose only diff from
`sim/stock` was an empty `perception.nim`; no repository file in `sim/` or
`scripts/` was changed.

### Before: v1 versus stock

Eight seeds from 201, eight duos per arm per episode; median length 1442
ticks. Values are means with paired 95% bootstrap confidence intervals.

| Arm | Win share | League score | Kills/duo | Deaths/duo | Placement | Alive ticks |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| v1 (`def5221`) | 1.0000 [1.0000, 1.0000] | 16.64 [11.11, 23.12] | 0.86 [0.62, 1.06] | 1.81 [1.77, 1.86] | 7.83 [7.16, 8.48] | 790.5 [732.8, 853.0] |
| stock | 0.0000 [0.0000, 0.0000] | 0.00 [0.00, 0.00] | 2.70 [2.42, 2.97] | 2.00 [2.00, 2.00] | 9.17 [8.52, 9.84] | 671.7 [590.3, 761.8] |
| v1 - stock | +1.0000 [+1.0000, +1.0000] | +16.64 [+11.11, +23.12] | -1.84 [-2.31, -1.38] | -0.19 [-0.23, -0.14] | -1.34 [-2.69, -0.03] | +118.8 [-6.0, +214.9] |

### After: v2 versus v1

Sixteen seeds from 301, eight duos per arm per episode; median length 1261
ticks. Values are means with paired 95% bootstrap confidence intervals.

| Arm | Win share | League score | Kills/duo | Deaths/duo | Placement | Alive ticks |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| v2 | 0.5000 [0.2500, 0.7500] | 19.79 [8.60, 32.28] | 2.82 [2.66, 2.99] | 1.89 [1.84, 1.95] | 8.94 [8.59, 9.28] | 724.0 [680.3, 772.5] |
| v1 | 0.5000 [0.2500, 0.7500] | 11.19 [5.61, 16.95] | 0.93 [0.73, 1.12] | 1.91 [1.87, 1.96] | 8.06 [7.72, 8.41] | 790.9 [734.4, 850.9] |
| v2 - v1 | +0.0000 [-0.5000, +0.5000] | +8.60 [-7.82, +25.62] | +1.89 [+1.54, +2.25] | -0.02 [-0.12, +0.08] | +0.88 [+0.19, +1.56] | -66.9 [-116.6, -21.0] |

The win-share bar is met: the gap is zero and its interval does not exclude
zero on the negative side. League score rises by 8.60 in the point estimate,
though its interval crosses zero. The kill gain excludes zero; placement and
survival time are worse, so this result supports the aggression change but
does not establish a survival improvement. No v2 duo in the 128 observations
had negative Glory (minimum 18); v1 had one.

### After: v2 versus stock on the before seeds

Eight seeds from 201, eight duos per arm per episode; median length 1576
ticks. Values are means with paired 95% bootstrap confidence intervals.

| Arm | Win share | League score | Kills/duo | Deaths/duo | Placement | Alive ticks |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| v2 | 1.0000 [1.0000, 1.0000] | 23.94 [16.45, 31.44] | 1.72 [1.39, 2.00] | 1.81 [1.77, 1.86] | 8.42 [8.16, 8.67] | 556.8 [536.1, 581.5] |
| stock | 0.0000 [0.0000, 0.0000] | 0.00 [0.00, 0.00] | 1.91 [1.61, 2.22] | 2.00 [2.00, 2.00] | 8.58 [8.33, 8.84] | 581.1 [528.2, 634.6] |
| v2 - stock | +1.0000 [+1.0000, +1.0000] | +23.94 [+16.45, +31.44] | -0.19 [-0.83, +0.38] | -0.19 [-0.23, -0.14] | -0.16 [-0.69, +0.34] | -24.4 [-76.5, +29.1] |

Against stock on identical seeds, v2 retains the 8/8 win share, raises
winning score from 16.64 to 23.94, and raises kills/duo from 0.86 to 1.72
without changing deaths/duo (1.81 in both runs). No v2 duo in these 64
observations had negative Glory (minimum 18).

### Cost and classic regression

A temporary monotonic timer around `decide` was used for one complete BR
episode, then removed. Seed 1 ended at tick 1077; the worst of all 32 seat
frames was 14,044,333ns (14.044333ms), at tick 62 for slot 18.

The final working tree was build `a` and an explicit `def5221` archive was
build `b` in one clean simulator binary. Both classic seeds were identical:

| Seed | v2 ticks/hash | v1 ticks/hash |
| ---: | --- | --- |
| 5000 | 4191 / `3769900552187605975` | 4191 / `3769900552187605975` |
| 5001 | 4413 / `13240903769640498421` | 4413 / `13240903769640498421` |
