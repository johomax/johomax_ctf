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

## Deliberately deferred

- The fixed-map ring route still has seed-dependent duration: two smoke seeds
  resolve before tick 1436 even though the five-seed mean is much later. A
  later pass should tune phase-transition waypoints against a larger seed set.
- Loot routing is intentionally local (250px) and sight-memory based; there is
  no global pickup tour or weapon-specific map route.
- Endgame hunting uses the nearest remembered enemy rather than coordinated
  pincer assignments or opponent-specific threat models.
