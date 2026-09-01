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

## Deliberately deferred

- The fixed-map ring route still has seed-dependent duration: two smoke seeds
  resolve before tick 1436 even though the five-seed mean is much later. A
  later pass should tune phase-transition waypoints against a larger seed set.
- Loot routing is intentionally local (250px) and sight-memory based; there is
  no global pickup tour or weapon-specific map route.
- Endgame hunting uses the nearest remembered enemy rather than coordinated
  pincer assignments or opponent-specific threat models.
