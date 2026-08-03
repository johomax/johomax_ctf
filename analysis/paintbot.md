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
