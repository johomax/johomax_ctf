# Paintbot: the league this repository does not mention

`jordan-ctf-candidate` is entered in two leagues. Everything in `README.md`,
`research/LEDGER.md` and `scripts/` is written as though CTF were the only
one. The other is **Paintbot** — `league_b8fa9b35-ac22-48cf-a03f-07b397aff1c7`,
division `div_aa7825db-262f-4a62-b01a-177c1b48f7ee` — and the same two-team,
fixed-arena policy is what plays there.

## What the game is

Same engine commit as CTF (63ea0cb7, GV35). Same core rules. Four differences
that matter, all of them structural:

- **Every episode seats FOUR entrant policies**, and the division rotates three
  shapes: `2v2` (16 seats, two teams, each team split between two policies —
  you get four allies you do not control), `4ffa` (16 seats, four teams of
  four, one policy per team), and `4ffa8` (32 seats, four teams of eight, on a
  giant map, 7500 ticks).
- **Four teams**: red, blue, green, yellow. A seat's colour is `slot mod 4`.
- **Generated terrain** (`mapPath: "gen"`), square-corner or plus-shaped —
  not the mirrored arena every landmark in `world.nim` is written against.
- **Pot scoring**: +4 to the winner, −1 to each loser (2v2 pays +2/−2). A
  timeout draw pays −1 to everybody, as in CTF.

## Our record

| variant | n | mean score |
|---------|--:|-----------:|
| 2v2 | 4 | **+2.00** (won all four) |
| default (2-team arena) | 6 | −0.33 |
| 4ffa | 6 | **−1.00** |
| 4ffa8 | 12 | **−1.00** |

**Zero wins in eighteen four-team episodes.** Those variants are 61% of the
division's traffic (122 of 200 recent episodes).

## Why — and it is not tuning

Three independent breakages, each sufficient on its own:

1. `baseline.nim` deals the seat's colour as `slot mod 2`. On a four-team
   board it is `slot mod 4`, so every green seat believes it is red and every
   yellow seat believes it is blue.
2. `labelkind.nim` has `LabelKind` arms for red and blue only. Green and
   yellow sprites classify as `lkOther`, and `protocols.nim` drops `lkOther`
   from the frame index entirely — so a green seat never finds its own self
   marker, `findSelf` reports not-alive, and it stands at spawn all game.
   Even a correctly-coloured seat cannot see half the enemies on the board.
3. `roleForSeat` is handed `clamp(slot div 2, 0, 7)`. With 32 slots that
   assigns HomeDefender to sixteen seats at once.

Upstream hit exactly this in their own baseline and fixed it in the commit
this repo is pinned to (63ea0cb, *"green/yellow seats were statues"* — 16 of
32 seats frozen at 99.2% of alive time in their prod Paintbot campaign).

**Reproduced locally.** `sim/paintbot_4ffa.json` (extracted from the live
manifest), seed 900001, current tree in all sixteen seats:

```
team 0 (red)    slots  0, 4, 8,12   shots 23, 5, 1, 0
team 1 (blue)   slots  1, 5, 9,13   shots 22, 1, 2, 0
team 2 (green)  slots  2, 6,10,14   shots  0, 0, 0, 0
team 3 (yellow) slots  3, 7,11,15   shots  0, 0, 0, 0
```

Eight of sixteen seats fired nothing, took nothing and dealt nothing, and the
episode timed out as a draw — which under pot scoring pays −1 to everyone.

## How much it is worth

Mean score per episode across the recent division traffic:

| player | overall | 4-team only | n (4-team) |
|--------|--------:|------------:|-----------:|
| daveey | +0.62 | **+0.59** | 104 |
| richard | +0.20 | +0.21 | 29 |
| Rohit Mukherjee | −0.41 | −0.12 | 17 |
| **Jordan** | **−0.43** | **−1.00** | 18 |
| Andre von Houck | −0.65 | −0.64 | 14 |
| Aaron | −0.68 | −0.75 | 20 |
| James Botts | −0.71 | −1.00 | 27 |
| Ari Sklar | −0.86 | −1.00 | 12 |
| RowDaBoat | −1.00 | −1.00 | 23 |
| NanosaurusX | −1.06 | −1.00 | 30 |
| softmaxwell | −1.07 | −1.00 | 20 |
| Andrew Brower | −1.13 | −1.00 | 9 |

**Seven of twelve entrants sit at exactly −1.00 on four-team boards** — they
have never won one either. Only daveey is meaningfully above the field, and
+0.59 under +4/−1 scoring is about a 32% win rate against a 25% chance
baseline. He is not solving the game; he is the only one showing up to it.

That sets the target. Merely *fielding sixteen live seats instead of eight*
should move us off −1.00 toward the chance baseline, and every point of that
is a point nobody has to out-play daveey to win. Tuning comes after.

---

# Second pass: four-team games mostly do not finish, and only finishers score

Read off 400 recent division episodes (metadata only, no re-simulation).

## How often an episode has a winner at all

| variant | n | resolved | no winner |
|---------|--:|---------:|----------:|
| Default (2 teams) | 113 | 84.1% | 18 |
| 2v2 (2 teams) | 64 | 82.8% | 11 |
| **4ffa** | 83 | **38.6%** | 51 |
| **4ffa8** | 128 | **41.4%** | 75 |

Two-team boards finish five times out of six. **Four-team boards finish two
times out of five.** The other three-fifths time out, and a clock draw pays
`TimeoutReward = -1` to every seat on every team — so the median four-team
episode is a four-way loss.

## Who wins the ones that do finish

Wins / appearances, four-team variants:

| player | 4ffa | 4ffa8 |
|--------|-----:|------:|
| daveey | 29/82 (35.4%) | 35/99 (35.4%) |
| richard | 12/37 (32.4%) | 2/18 (11.1%) |
| Rohit Mukherjee | 4/27 (14.8%) | 1/10 (10.0%) |
| Andre von Houck | 1/23 (4.3%) | 0/6 |
| Aaron | 1/35 (2.9%) | 0/9 |
| **everyone else (7 entrants)** | **0** | **0** |

Only ~40% of episodes resolve, and daveey takes 35.4% of *all* appearances —
which is **85-92% of every four-team episode that resolves at all.** Nine of
twelve entrants have never won one.

So the division is not a contest of margins. It is a contest of *finishing*.
A team that cannot close a four-team game scores −1 forever, and that
described us exactly until v119.

## Why finishing is a different problem here than in CTF

GV32 changed what a capture does. In two-team play the first capture ends the
game and wins it. In four-team play **a capture eliminates the captured team
and play continues** — the game ends when at most one team still stands. So a
winner either captures all three rival hearts or outlives the field.

Every instinct this policy has is calibrated to the two-team rule. Its own
`LatePushTick` comment says it outright: *"past this tick a draw is the
default outcome, so commit to the capture."* On a four-team board one capture
is a third of the job, and the clock is 5000 ticks on 4ffa but **7500** on
4ffa8 — where a constant tuned at 3400 fires at 45% of the match instead of
68%.

That is the next experiment family, and it is a strategy question rather than
a tuning one: what "commit" should mean when a capture buys elimination of one
rival rather than the win.

---

# Third pass: we are winning the clock and being paid nothing for it

Read off the 384 banked `roles4` episodes (`episodes/paint-roles4*.jsonl`,
4ffa, colour-rotated, candidate on one team against a field of three).

## How they end

| ending | n | share |
|--------|--:|------:|
| timeout | 272 | **70.8%** |
| wipe | 109 | 28.4% |
| capture | 3 | **0.8%** |

Only 28.9% resolve. And of the ones that do, **wipes outnumber captures 109
to 3** — this game is being decided by outlasting, essentially never by
taking a heart.

## The number that matters

Mean lives left per team at the final tick:

| ending | candidate | field |
|--------|----------:|------:|
| timeout | **2.00** | 1.74 |
| wipe | 1.88 | 0.58 |
| capture | 4.67 | 0.67 |

**At timeout we are ahead on lives and paid nothing for it.** A clock draw is
`TimeoutReward = -1` to every seat on every team regardless of who was
winning, and it is how seven episodes in ten end. Per team, the candidate
takes 13.3% of episodes against the field's 5.2% — already 2.5x — and still
scores −0.33, because being ahead is not a scoring state.

## Where the next lever is, and why it is captures

Under GV32 a capture **eliminates the captured team outright**. Killing a team
instead costs 12 lives of work (4 seats x 3). A capture is therefore the
cheapest elimination in the game by a wide margin — and we are executing 3 of
them in 384 episodes while executing 109 wipes.

The raid machinery exists (`multiTarget`, re-anchored on the stated endzone
marks) but it points at exactly one rival, chosen by largest horizontal
offset, and every constant behind the approach — `PocketRushRange`,
`RushEngageRange`, `CarrierFireRange`, `FlankDepth` — was tuned on the
hand-authored two-team arena against one opponent who had to come to us.

That is the next experiment family: make a capture the thing this policy is
trying to do on a four-team board, and price the raid constants on generated
terrain. It is a bigger piece of work than either of the two structural fixes
so far, and it is where the remaining 0.58 of pot score to the chance
baseline is most likely to live.

---

# How much the live Paintbot numbers can be read: not much, yet

Live per-episode mean score by champion version, division episodes to date:

| version | four-team | n | two-team | n |
|---------|----------:|--:|---------:|--:|
| v117 (pre-port) | −1.00 | 8 | +0.45 | 20 |
| v119 (colour port) | +1.50 | 2 | −0.29 | 14 |
| v120 (+ heart guard) | −1.00 | 5 | −0.33 | 12 |

**Read the two-team column first, because it is a control we did not have to
build.** Every one of these changes is gated on `GameTeams > 2` and verified
bit-identical on two-team boards — v117, v119 and v120 are *the same
behaviour* there, hash for hash. They scored +0.45, −0.29 and −0.33.

So a spread of 0.78 in mean score across 12–20 hosted episodes is what
**zero** looks like in this division. The four-team column has n of 2 and 5.
Neither confirms nor contradicts the local measurements (+0.6875 and +0.4036,
at n=160 and n=384 episodes with the colour rotation), and it will take a few
hundred hosted episodes before it can.

That is not an argument for trusting the local harness blindly — it is an
argument for reading the hosted column at the sample size it actually has.
The one hosted fact that IS solid is the one the port was aimed at, and it
came from a replay rather than a score: on a live 4ffa board our green seats
fired 62 shots to the next-best colour's 30 and went 16–8, where before the
port they fired none at all.

---

# Fourth pass: the anatomy of a timeout, and why the aggression levers are spent

384 banked four-team episodes (`episodes/paint-roles4*.jsonl`). 272 timed out.
Lives remaining per team at the cap, sorted lowest-first within each episode
and averaged across episodes (a team starts with 12 — four seats, three lives):

| rank | mean lives left |
|------|----------------:|
| lowest | **0.22** |
| 2nd | **0.62** |
| 3rd | 2.72 |
| 4th | 3.65 |

**In 90% of timeouts, two of the four teams are already at zero lives.** The
single most common spread is (0, 0, 2, 3) — 74 of 272 — followed by (0, 0, 3,
3) and (0, 0, 2, 2).

So the four-way phase resolves itself perfectly well. What does not resolve is
what follows: **a two-team endgame between survivors on 2-4 lives each, which
runs out the clock.** Every team is ground down — the survivors have spent
about nine of their twelve lives too — and the 5000-tick cap simply arrives
first. A timeout pays −1 to every seat on every team, so that last duel is the
entire game.

## Four experiments say the aggression levers are already saturated

| experiment | result |
|------------|--------|
| `multilatepush2000` | bit-identical episodes |
| `holdrelease` | −0.2344 [−0.4861, +0.0434] |
| `pocketrush340` | −0.1562 [−0.3472, +0.0260], 0 captures |
| `endgamepush` (last rival standing ⇒ push) | **bit-identical episodes** |
| `axisframe` (branch) | +0.0260 [−0.1562, +0.2083], 6× captures |

`endgamepush` counted standing rival hearts off the pedestal banners
(`rivalsStanding()`) and forced `f.pushOut` once only one rival remained. It
changed nothing at all, for the same reason `multilatepush2000` did:
**`pushOut` is already true from mid-game.** Probed directly, it first fires at
a median tick of **2664**, via the quiet-field clause rather than the clock —
so every lever that makes it fire *earlier* is a no-op, and the two that
genuinely loosened the wave (`holdrelease`, `pocketrush340`) both measured
slightly negative.

`axisframe` is the sharpest evidence: it delivers the wave three times as
often and takes six times the captures, and the score does not move, because
242 of its 384 episodes still timed out and mean pot score is an affine
function of win share alone.

## What is actually missing

Not aggression. The policy has no behaviour for *the board being nearly
empty*. Its whole vocabulary — posts, cover, lanes, hold lines, duck cells —
is written for a board with sixteen bodies on it. In the endgame there are two
or three, on generated terrain up to `giant`, under fog, and two seats that
never meet cannot finish a game no matter how willing either is.

The next thing to build is therefore a **sweep**: when the count of live
enemies (or standing rival hearts) falls to one team's worth, abandon posts
and search the map systematically rather than holding ground. That is a new
behaviour, not a knob, and it is the first thing on this list that none of the
five experiments above was able to express.


---

# The carry-home bug, found from live play

Reported by the operator: *"when we pick up an enemy heart, our policies go
the wrong way and don't bring it back to our base even when there is a clear
and safe path"*. It is real, and the code says exactly why.

`objective.nim` runs a carrier home to `vec(bot.homeDeepX(bot.team), laneY)`.
`homeDeepX` answers correctly with `multiCapture.x` on a four-team board, so
the **column** is right. The **row** comes from `safestLaneY`, which chooses
among three constants — `LaneTop 40`, `LaneMid CenterY`, `LaneBottom
MapH - 40` — that are fixed y-bands of the mirrored two-team arena and know
nothing about where our endzone is. `safestLaneY` cannot rescue it either:
its `towardHome` test reads `bot.team == Red`, the parity token that names
nothing with four colours.

Concretely, on seed 900001 green's capture zone is the wedge around
(188, 1031). `vec(homeDeepX, laneY)` sends its carrier to (188, 40) or
(188, 624) on two of the three lanes — **and (188, 40) is RED'S PEDESTAL.**
The carrier walks the heart to an enemy base.

Two things follow, and the second is the more important:

1. The fix is one line — target `bot.multiCapture`, which is inside the zone
   for every shape in the endzone vocabulary. Branch `axis-frame` already
   carries it, as `world.carryHome()`.
2. **It is unmeasurable on the current tree, because we almost never carry.**
   The fix measured an exact zero over 192 episodes (the pooler detected
   identical builds), and a print inside the branch fired **zero times** in
   four episodes with a mixed field. The tree takes 3 captures per 384
   episodes and reaches the branch about that often. Measured from the other
   side: 1181 ticks carrying and ONE capture over eight seeds.

So on four-team boards we do not lose the heart on the way home — we never
get it. The operator's sighting is a live event the local sim does not
reproduce in 192 episodes, which makes the sim's rate an underestimate if
anything.
