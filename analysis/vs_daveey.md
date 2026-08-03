# What daveey does to us

**Corpus:** the 17 most recent completed league episodes in which Jordan
(`jordan-ctf-candidate:v117`) faced daveey (`ctf-focusfire:v66`), played
2026-08-02 23:02Z–23:58Z, downloaded to `replays/` and re-simulated with the
engine's own `tools/extract_events.nim` at the pin the league runs
(63ea0cb7, GV35).

**We lost all 17.** Nine by being wiped, six to a capture, two at the tick
limit (a limit draw pays −1 to both sides, so it is a loss in everything but
name).

Reproduce:

```bash
nix shell nixpkgs#python3 -c python3 analysis/vs_daveey.py    # counts
nix shell nixpkgs#python3 -c python3 analysis/vs_daveey2.py   # rates
nix shell nixpkgs#python3 -c python3 analysis/vs_daveey3.py   # geometry
```

---

## The first thing that came out of it was not about daveey

The replays would not parse: *"Replay game version does not match"*. The
league runs **GameVersion 35**; `sim/engine.pin` was at **GV30**. Every local
A/B measured since that pin moved was stepping a game the league had stopped
playing five rule changes ago, and the hosted config had drifted too —
`visionConeDeg` 45 → 60, a third more vision cone on a policy whose cone
rides its aim. Fixed in `2a55715`; everything below is read at GV35.

## Totals, 17 episodes

|                  |  Jordan |  daveey |
|------------------|--------:|--------:|
| kills            |     295 |     389 |
| deaths           |     389 |     295 |
| K/D              |   0.758 |   1.319 |
| shots fired      |    1310 |    2169 |
| hits             |     880 |    1112 |
| hit rate         |   67.2% |   51.3% |
| flag steals      |       4 |      28 |
| grenades thrown  |     152 |     129 |
| spray uses       |      15 |      35 |

Per 1000 alive-ticks (we are alive less, so counts flatter us):

|              | Jordan | daveey | ratio |
|--------------|-------:|-------:|------:|
| shots        |   3.96 |   4.80 | 0.82  |
| hits         |   2.66 |   2.46 | 1.08  |
| kills        |   0.89 |   0.86 | 1.04  |
| **deaths**   | **1.18** | **0.65** | **1.80** |
| carry ticks  |   2.97 |  11.51 | 0.26  |

**We land hits at the same rate they do and die 1.8× as fast.** Our shooting
is not the problem — our accuracy is materially better (67% vs 51%) and our
kills-per-alive-tick is level with theirs. What separates the two sides is
entirely on the dying side of the ledger.

## Where the dying happens

Positions are normalised along the attack axis: **0 = your own base edge,
1 = the enemy's**. 0.5 is the centre line.

| per-team seat | Jordan mean | daveey mean |
|---------------|------------:|------------:|
| 0             |       0.345 |       0.225 |
| 1             |       0.479 |       0.231 |
| 2             |       0.454 |       0.232 |
| 3             |       0.445 |       0.215 |
| 4             |       0.440 |       0.197 |
| 5             |       0.409 |       0.231 |
| 6             |       0.413 |       0.234 |
| 7             |       0.319 |       0.205 |

|                        | Jordan | daveey |
|------------------------|-------:|-------:|
| median death position  |  0.623 |  0.311 |
| median kill position   |  0.547 |  0.213 |
| time in own quarter    |  18.9% |  75.5% |

daveey parks **all eight seats** in a flat band at 0.20–0.23 — a wall about
270px in front of their own pedestal — and never leaves it. We spread across
0.32–0.48 and **die at 0.62, deep inside their half, in front of that wall.**
They kill from 0.21: they are shooting from inside their own formation at
things walking into it.

This is not a fight we are losing. It is a fight we are travelling to.

## What that does not explain, and what it does

The obvious objection is that a team sitting at home cannot steal 28 flags.
It can, and the mechanism is in the timings: their median steal lands at tick
**4119** of a 5000-tick game. They do not raid. They grind our attack wave
down for three quarters of the match, and then walk into an undefended base.
Twenty-eight steals, six captures, nine wipes — the steals are the *symptom*
of the attrition being over, not the cause of the loss.

Our own attack wave is six seats of eight (`roleForSeat`: four mids, two
flankers, one Overwatch, one HomeDefender). That is the shape being priced
here.

## Things this rules out

- **Engagement range.** Both sides fight at the same distance — our median
  shot goes out with the nearest live enemy 217px away, theirs 263px. Neither
  side takes long shots: 0.9% of our shots and 0.3% of theirs are fired past
  650px.
- **GV34's aim jitter**, therefore, is a non-event for this matchup. The
  jitter is calibrated to cost 20% of hits at max range (1300px) and
  σ scales with distance: at our median 217px the lateral error is ~1.8px
  against a 14px acceptance window, over 7σ. It cannot be reached from here.
- **Our own accuracy.** 67% vs 51%. If anything we are buying precision we
  are not being paid for.

## What it points at

1. **The wave over-commits.** We die 0.31 of the field further forward than
   they do. Every constant governing how far a held wave goes and when it
   releases (`HoldLineDepth`, `HoldLineKills`, `FlankDepth`) was tuned in
   self-play mirrors, where both sides advance — never against a wall.
2. **Volume of fire.** They fire 1.66× as many shots as we do at two thirds
   of our hit rate, and come out ahead on hits. A miss costs a 12-tick
   cooldown; being late to shoot costs a life.
3. **The local mirror cannot see any of this.** A seed-paired mirror puts
   this policy against itself, so "how do we play a team that does not come
   out" is a question the simulator is structurally unable to ask. It can
   price a fire gate; it cannot price a formation choice against a camper.
   That is what the hosted head-to-head against daveey is for.

## Killed before it cost anything

`own aim` — GV34-era engines state the turret angle outright on the player
stream, and the engine's own note says policies that dead-reckon it instead
"measurably cost accuracy". Implemented, instrumented, and measured against
the tree's dead reckoning over one episode: **28,122 samples, drift zero on
every one of them.** This policy's dead reckoning is already exact, so the
readback is worth nothing here. No episodes bought.
