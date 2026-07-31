# What the top of the CTF ladder actually does — 179 re-simulated league replays

**Date:** 2026-07-31 · **Corpus:** league rounds r2080–r2085 · **Engine:** GV31
(`coworld_version` 0.7.137; every replay hash-validated on re-simulation, 179/179 clean)

Nothing here is a result. This is *observational* — it says what the top of the
field does, not what would help us. Every candidate in the last section still
owes a both-directions hosted mirror before it means anything (README, "The
rules that decide whether a number means anything"). It is written down because
several of these gaps are large, cheap to test, and currently invisible in
`LEDGER.md`.

## Method

Two layers, both reproducible from `scripts/league_scout/`:

1. **Form table (cheap, no download).** All 1440 episodes of r2080–r2085 from
   `/v2/rounds/{id}/episodes?limit=1000`, scored from the episode's own
   `scores` array and keyed to the player who actually held each seat via
   `participants` — never an arm name (rule 3). 187 failed episodes excluded
   and counted, not retried (rule 7).
2. **Deep corpus (179 replays).** Every r2080–r2085 episode among the top five
   and every top-five-vs-us episode, re-simulated with
   `coworld-ctf/tools/extract_events.nim --frames`, which yields the full
   tier-2 event stream plus per-tick, per-seat position / aim / HP / carry
   state. Seat parity is the team (even = RED, spawns left; odd = BLUE); API
   `position` == replay join slot, verified against spawn coordinates.

Spatial numbers are folded to **advance**: 0 at your own pedestal, 1 at the
enemy's, so RED and BLUE are comparable.

**Corpus bias, stated up front.** The 179 replays are deliberately *not* a
random sample — they are our games against the top five plus the top five
against each other. So "Jordan 5–42" below is our record *against the top five
only*; our record against the whole field over the same rounds is 0.449 (75–65,
27 draws). Read the deep-corpus numbers as "how the strong teams play and how we
fare against them", never as a league-wide rate.

## Where the league actually stands (1440 episodes, all 15 entrants)

The leaderboard's `win_rate` column is cumulative over a policy slot's whole
history and blends every predecessor version. Recomputed over these six rounds
only:

| player | policy | n | W | L | D | winrate |
|---|---|---:|---:|---:|---:|---:|
| RowDaBoat | reardenr-ctf-heist:v10 | 165 | 114 | 46 | 5 | .691 |
| James Boggs | beacon:v56 | 168 | 115 | 40 | 13 | .685 |
| daveey | ctf-focusfire:v66 | 167 | 109 | 55 | 3 | .653 |
| Andre von Houck | alphashot:v347 | 168 | 108 | 14 | 46 | .643 |
| NanosaurusX | nancy-ctf-solo:v1 | 168 | 107 | 58 | 3 | .637 |
| Alex Smith | ctf-h050:v1 | 166 | 87 | 76 | 3 | .524 |
| Ari Sklar | arisk-ctf-nadecal:v1 | 167 | 80 | 82 | 5 | .479 |
| **Jordan (us)** | **jordan-ctf-candidate:v79** | **167** | **75** | **65** | **27** | **.449** |
| richard | co-gas-ctf-simple-richard:v45 | 168 | 75 | 89 | 4 | .446 |
| Rohit Mukherjee | attrition:v12 | 167 | 74 | 43 | 50 | .443 |

Against the top five we are 5–42 with 13 timeout draws. The Elo gap is not an
artefact of the field re-arming underneath us; we lose the head-to-heads.

## Finding 1 — the league is won by WIPING, not by capturing

Across all 179 episodes:

| ending | n | median length |
|---|---:|---:|
| win by **wipe** | 105 | 4847 ticks |
| win by **capture** | 49 | 4891 ticks |
| timeout draw (−1 both sides) | 25 | — |

Per player, wins by capture vs by wipe:

| player | win-cap | win-wipe | loss-cap | loss-wipe | timeout |
|---|---:|---:|---:|---:|---:|
| RowDaBoat | 16 | 21 | 4 | 18 | 0 |
| James Boggs | 4 | **27** | 7 | 12 | 10 |
| Andre von Houck | 2 | **28** | 3 | 3 | 24 |
| NanosaurusX | 13 | 15 | 5 | 25 | 2 |
| daveey | 11 | 12 | 11 | 24 | 1 |
| **Jordan (us)** | **3** | **2** | **19** | **23** | **13** |

Two things follow.

**The attrition fight is the game.** The two players who win almost exclusively
by wipe (James Boggs 27/31, Andre 28/30) are ranked 2nd and 4th. `baseline.nim`'s
design note argues the opposite — *"The attack wave is deliberately six strong…
committed offense turns steals into captures"* — and commits six of eight seats
to offense on that basis. Against this field that premise is not supported: the
field kills you before the capture lands.

**Our largest single loss bucket is the enemy capturing our flag** — 19 of 60,
more than any other outcome. See Finding 2 for the mechanism.

## Finding 2 — we are the only team in the corpus with no home presence

Mean advance per team-relative seat, averaged over each player's episodes:

| seat | Jordan (us) | James Boggs | Andre | RowDaBoat |
|---:|---:|---:|---:|---:|
| 0 | 0.321 | 0.433 | −0.181 | 0.116 |
| 1 | 0.463 | 0.420 | **0.326** | 0.144 |
| 2 | 0.449 | 0.408 | −0.180 | 0.105 |
| 3 | 0.462 | 0.357 | −0.151 | 0.105 |
| 4 | 0.443 | 0.394 | −0.149 | 0.073 |
| 5 | 0.360 | 0.440 | −0.153 | 0.135 |
| 6 | 0.338 | 0.447 | −0.166 | 0.142 |
| 7 | 0.262 | 0.451 | −0.045 | 0.185 |

Three distinct winning shapes, and ours is a fourth that resembles none of them:

- **Deathball (James Boggs).** All eight seats parked in a tight block at
  0.36–0.45 — the midfield. Lowest team spread in the corpus (225px mean
  pairwise distance vs our 278 and daveey's 316). No roles, one mass.
- **Turtle + solo raider (Andre).** Seven seats behind their own pedestal
  (negative advance), one seat (seat 1) raiding to 0.776. 95% of his live
  player-ticks are in his own tenth of the field. Result: 30 wins, **6 losses**,
  24 timeouts.
- **Home base + rotating sorties (RowDaBoat, #1 Elo).** Low mean advance
  (0.07–0.19) but high *max* advance (0.56–0.84) on every seat — they hold home
  and take turns going deep. Best of both: 16 captures *and* 21 wipes.
- **Ours.** Every seat between 0.26 and 0.46 mean advance, and
  `max advance < 0.34` on **zero** of eight seats — no seat stays home for the
  match. 41% of our live player-ticks sit in the single band at advance 0.5:
  we stall on the centre line.

The design describes a home defender at the choke and an overwatch sniper. In
production neither seat holds: our most rearward seat (7) still averages 0.262
and peaks at 0.577. Whatever the intent, the measured behaviour is an eight-seat
push that leaves the pedestal open — which is what 19 capture-losses look like.

## Finding 3 — every player above us runs a shout channel; we send zero

This confirms `BACKLOG.md` items 1–2 at much larger n, and decodes the
vocabularies against ground truth.

| player | shouts/episode | distinct strings | mean teammates in earshot | ≥1 heard |
|---|---:|---:|---:|---:|
| James Boggs | 514.0 | 4371 | 4.84 | 98.3% |
| Andre von Houck | 448.6 | **4** | 4.26 | 99.9% |
| RowDaBoat | 105.1 | 1724 | 2.65 | 88.3% |
| daveey | 99.8 | 1787 | 2.44 | 86.0% |
| NanosaurusX | 76.7 | 1596 | 2.34 | 83.1% |
| **Jordan (us)** | **0.0** | — | — | — |

Both code families decode cleanly against the re-simulated state:

- **`E<a> <b>` = an enemy position, in 8px cells.** Over 2003 calls the median
  distance from `(a*8, b*8)` to the nearest live enemy is **6.0px** (vs 245px at
  ×4 and 458px raw). Used by RowDaBoat, daveey and NanosaurusX. This is a direct
  fog-of-war defeat: eight ±60° cones pooled into one picture.
- **`K<d><xx><yy>` = "I am seat *d*, at (x, y)".** The digit equals the
  shouter's team-relative seat in **100.0%** of 22 976 samples; the two base-36
  pairs times 8 land a median **10.8px** from the shouter's true position. This
  is James Boggs rebuilding *teammate* awareness — the thing the ruleset
  deliberately removes ("teammates are NOT [visible] — no team radio").
- **Andre's entire vocabulary is four tokens** — `go`, `go1`, `back`, `back1` —
  a formation controller. Team mean advance 2s after the call moves in the
  commanded direction every time: `go` **+0.0101**, `go1` +0.0053, `back`
  **−0.0098**, `back1` −0.0051.
- **RowDaBoat and daveey also shout at the humans**: `WOW RUDE`, `PEACE PLS`,
  `IM HURT :(`, `HUGS?`, `DONT SHOOT`, `I COME IN [PEACE]`, `WHY U MEAN`. Shouts
  are heard by *anyone* in range, enemies included, and the bubble is labelled
  with the speaker's team. Whether this is aimed at LLM-driven opponents or is
  just flavour, it costs them nothing — shouting is free and never delays an
  action.

**Earshot depends on formation.** The channel is only ~247px. James Boggs's
tight block puts 4.84 teammates in range of every call; the spread-out players
reach 2.3–2.7. If we build the channel, it pays roughly in proportion to how
concentrated we are — which couples Finding 3 to Finding 2.

## Finding 4 — we are 3× short on shields, and long on grenades

Share of live player-ticks holding shield HP, and pickups per episode:

| player | shield uptime | grenade | shield | med_kit | spray_can |
|---|---:|---:|---:|---:|---:|
| RowDaBoat | **16.67%** | 8.73 | 3.64 | 0.95 | 1.10 |
| NanosaurusX | 14.31% | 8.47 | 3.62 | 1.93 | 1.05 |
| daveey | 13.04% | 7.20 | 3.58 | 2.15 | 1.22 |
| Andre von Houck | 12.01% | 6.65 | 2.07 | 0.28 | 2.65 |
| James Boggs | 10.14% | 4.90 | 2.12 | **6.55** | 0.17 |
| **Jordan (us)** | **5.45%** | **9.65** | **1.37** | 3.02 | 1.73 |

We take more grenades per episode than anyone and the fewest shields. A shield
is flat effective HP in a game whose dominant win condition is the attrition
fight (Finding 1); we are under-buying the one item that directly buys survival.

## Finding 5 — accuracy is not our problem

| player | accuracy | K/D | kills | team-kills |
|---|---:|---:|---:|---:|
| **Jordan (us)** | **0.688** | **0.74** | 898 | 22 |
| James Boggs | 0.686 | 1.06 | 1112 | 19 |
| NanosaurusX | 0.563 | 0.92 | 1179 | 25 |
| daveey | 0.525 | 0.91 | 1138 | 28 |
| RowDaBoat | 0.503 | 1.08 | 1267 | 46 |
| Andre von Houck | 0.477 | 1.25 | 1036 | 28 |

We have the **best accuracy in the corpus and the worst K/D**. RowDaBoat lands
barely half his shots and still runs 1.08. The turret controller, fire gate and
corridor geometry are doing their job; we lose the fight on *how many guns are
pointed at the same target*, on positioning, and on effective HP — not on aim.

This is a useful negative result: it argues against spending the next
generations on the aim/scan/fire-discipline knob family (`ScanArc`,
`PreAimWatch*`, `CooldownSweepArc`, `TraversePxPerBrad`).

Focus fire — distinct teammates who damaged a victim in the 2s before it died:

| player | mean attackers | % multi-attacker |
|---|---:|---:|
| Andre von Houck | 1.57 | **44.1%** |
| James Boggs | 1.35 | 31.6% |
| RowDaBoat | 1.24 | 22.4% |
| **Jordan (us)** | 1.23 | 21.0% |
| NanosaurusX | 1.19 | 17.9% |
| daveey | 1.18 | 16.6% |

The two wipe-winners are the two focus-firers. (Note daveey's policy is *named*
`ctf-focusfire` and measures the least focused in the corpus — another instance
of rule 3: never read behaviour out of an arm name.)

## Finding 6 — the timeout draw is an Elo strategy, and it is being farmed

Andre takes 24 timeout draws in 60 episodes and loses only 6. A timeout pays
**−1 to every player on both teams**, so on the *score* it is a lose-lose; on the
*Elo ladder* it is neither a win nor a loss, and refusing to lose is worth 1784
Elo and rank 5. We take 13 timeouts against the top five ourselves, and our
draws cluster exactly where you would expect: all 12 of our games against Andre
and all 12 against Rohit (`attrition:v12`, 50 draws in 167) were draws.

Worth deciding deliberately which of the two we are optimizing, because they
disagree. `BACKLOG.md` item 18 ("draw-conditional endgame") is the existing entry
for this and it now has a named opponent archetype behind it.

## Candidates, ranked by (evidence × cheapness)

Each is one variable, in the repo's sense, and none is evidence of anything until
a both-directions mirror says so.

1. **Home-guard that actually holds** (Finding 2, 19 capture-losses). Before
   building anything new: find out why the defender and overwatch seats leave.
   If a knob already governs it, this is a knob sweep; if the hold is being
   overridden by the wipe-push or late-push switch, that is the one variable.
   Highest evidence-to-cost ratio in this document.
2. **Shout emit + parse** (Finding 3; `BACKLOG.md` 1–2). `E<gx> <gy>` on fresh
   enemy sightings into `memory.updateTracks`, and parse both teams' calls
   (hostile calls are free intel and need no emit — the smaller first slice).
   All eight seats run one policy, so a private vocabulary works immediately.
3. **Shield priority over grenade** (Finding 4). We take 9.65 grenades and 1.37
   shields per episode; the field's best take 3.6 shields. A pickup-preference
   reorder is a small, single-variable change.
4. **Tighten the formation** (Finding 2/3). Our 278px spread sits between the
   deathball's 225 and the sortie players' 310+; we get neither the focus-fire
   concentration of the former nor the map coverage of the latter, and the
   centre-line stall at advance 0.5 (41% of our live ticks) is where we die.
   Pulling the wave together is also the multiplier on candidate 2.
5. **Focus-fire target selection** (Finding 5). 21.0% multi-attacker vs Andre's
   44.1%. `HpFocusBonus` / `ThiefFocusBonus` already exist and were dropped
   without measurement (`BACKLOG.md` 20); shared target selection is what the
   shout channel would make possible.
6. **Do not spend generations on aim** (Finding 5). Explicitly de-prioritize the
   scan/fire-discipline family until K/D and accuracy stop disagreeing.

## Reproducing this

```sh
cd scripts/league_scout
softmax exchange-code <code>            # or `softmax login`
python index_eps.py 6                   # rounds -> episodes  (cached)
python form.py                          # the 1440-episode form table
python fetch_replays.py                 # public S3, no auth
#   build the extractor once, from a coworld-ctf checkout at the matching GV:
#   nim c -d:release -o:bin/extract_events tools/extract_events.nim
ls ~/.ctf/scout/replays/*.replay | xargs -P 8 -I{} sh -c \
  'b=$(basename {} .replay); bin/extract_events {} \
     --out ~/.ctf/scout/ev/$b.jsonl --frames ~/.ctf/scout/fr/$b.bin'
python analyze.py && python analyze2.py && python analyze3.py && python analyze4.py
```

179 replays extract in ~76s on 8 cores. Caches under `~/.ctf/scout/`, so
re-slicing an existing corpus is free.

**The GameVersion horizon is real.** A replay only re-simulates on the engine
that recorded it; this corpus is GV31 and was extracted against coworld-ctf
`38938f5`. When the hosted build churns, re-pin before re-running rather than
overriding `GameVersion`.
