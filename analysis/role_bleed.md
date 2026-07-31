# Per-role bleed: where the RED/BLUE gap actually sits

Backlog item 9. Instrumentation only — nothing under `bot/`, `sim/`,
`scripts/` or `research/` was touched, so every banked episode stays
comparable.

**Tool:** `analysis/role_bleed.py` (python3, standard library only).
**Corpus:** the banked local-simulator episodes in `episodes/*.jsonl`, frozen
at files modified on or before `2026-07-31T18:27:00Z` — 52 files, 9140
episodes, 0 records carrying an `error`.

Reproduce exactly:

```bash
nix shell nixpkgs#python3 -c python3 analysis/role_bleed.py \
    --draws 10000 --until 2026-07-31T18:27:00
```

`episodes/` is written into by a running research loop, so the `--until`
cutoff is load bearing: without it a re-run reads a larger corpus and prints
different numbers. The per-file table in the generated output below is the
record of exactly what was read.

---

## Findings

Every claim is labelled **VERIFIED** (with the data or source behind it) or
**ASSUMED**.

### 0. Read the era split before anything else

**VERIFIED** — The corpus straddles the engine re-pin of 2026-07-31T08:10Z,
GV27 (`beae1614`, ctf v0.7.124) → `1047232f` (ctf 0.7.136): live mid
diamonds, compact endzones, paint stains (`research/LEDGER.md`, "The league
moved: GV27 → current"). **5980 of the 9140 banked episodes (65%) are GV27**,
and the ledger's own verdict on that pin is that it "can silently measure a
game the league no longer plays".

**VERIFIED** — The two eras do not merely differ in magnitude, they disagree
about *which role bleeds and in which direction* (generated output, the two
"RED minus BLUE, by role" tables):

| role, ΔK/D (red − blue) | gv-current, n=3160 | gv27, n=5980 |
|---|---|---|
| Overwatch | **+0.515** | −0.265 |
| FlankTop | +0.055 | **+0.893** |
| FlankBottom | **−0.396** | −0.008 |
| MidBottom | −0.046 | −0.573 |
| MidTop | −0.029 | −0.418 |
| team (all eight) | +0.036 | −0.148 |

So the pooled corpus is not a bigger sample of one question, it is two
different questions averaged. **Everything below is the gv-current era only:
17 files, 3160 episodes, 1580 seed blocks.** The pooled tables are printed for
completeness and should not be quoted.

### 1. The premise inverts: there is no blue team-level deficit to localize

**VERIFIED** — Under the current pin, red is *slightly ahead*, not blue behind:
red K/D 1.0179 (69327/68106), blue 0.9823 (67637/68858), ΔK/D **+0.0357**.

**VERIFIED** — And that team gap is not resolvable as a stable fact:

- 95% CI over seed pairs: `[+0.0254, +0.0460]` — excludes zero;
- 95% CI over **experiment files**: `[−0.0157, +0.0824]` — **includes zero**;
- only **10 of 17** files agree with the pooled sign (median per-file
  +0.0390, range −0.125 to +0.175).

The seed-pair interval is the noise *inside* this corpus; the file interval
asks whether a different set of experiments would say the same, and it says
no. Per README rule 6, **there is no team-level side result here.** For
scale, the whole gap is half of what an 80-episode screen can resolve
(0.070 K/D, README "How many episodes").

**VERIFIED** — Episode wins tell the same story: red took 1599 of 3160
(50.6%; 54.0% of the 2960 decisive episodes, 200 draws). That is a long way
from the ~63–71% RED bias `README.md` and `sim/README.md` record, and it is
consistent with backlog item 11's note that the re-pin mostly explains the
inversion. Under GV27 the same corpus has red at 29.8%.

### 2. Where the deficit does concentrate: exactly two roles, pointing opposite ways

**VERIFIED** — Two role contrasts are an order of magnitude larger than the
team gap, clear the Bonferroni correction for the whole family of seven, sit
far outside the side-relabelling null, survive the file bootstrap, and
reproduce on both halves of the corpus:

| | **Overwatch** (seat 5) | **FlankBottom** (seat 0) |
|---|---|---|
| ΔK/D (red − blue) | **+0.5150** | **−0.3964** |
| 95% CI, seed pairs | [+0.4733, +0.5567] | [−0.4801, −0.3147] |
| 99.29% CI (Bonferroni /7) | [+0.4573, +0.5734] | [−0.5098, −0.2807] |
| 95% CI, **files** | [+0.3255, +0.7145] | [−0.7143, −0.1338] |
| null band (side relabelled) | [−0.048, +0.048] | [−0.086, +0.086] |
| permutation p | 0.0001 | 0.0001 |
| files agreeing in sign | 15/17 | 12/17 |
| split half A / half B | +0.5024 / +0.5277 | −0.3859 / −0.4069 |
| Δkills/ep | +1.298 | −0.250 |
| Δdeaths/ep | −0.166 | +0.279 |

**BLUE's bleed is its Overwatch seat, and it is large.** **VERIFIED** from
the levels table: blue's Overwatch takes 2.447 kills/episode against red's
3.745, dies out completely (all three lives spent) in **95.5% of episodes
against red's 81.6%**, and shoots at 0.655 accuracy against red's 0.690. It
is the worst-performing non-mid seat blue owns; red's is one of its best.

**RED's bleed is its FlankBottom seat**, and it is the mirror-image finding —
red's bottom flanker dies out in 47.7% of episodes against blue's 31.8%, and
takes 3.547 kills to blue's 3.797. Note that FlankTop is nearly level
(+0.055, fails Bonferroni), so this is a bottom-lane effect and not a
flanker effect.

**ASSUMED (mechanism, not measured here)** — the natural suspects are the
mirrored constructions each of those two roles depends on: `posts.nim`'s
`findEnemyPosts`/`pickPost` for Overwatch, and `LaneBottom` plus
`FlankDepth` in `objective.nim` for FlankBottom. Nothing in this analysis
looks inside an episode, so which of them is responsible is untested.

### 3. Nothing else clears the bar

**VERIFIED** — every remaining role contrast:

| role | ΔK/D | 95% CI, seed pairs | 95% CI, files | verdict |
|---|---|---|---|---|
| MidGuard | +0.0772 | [+0.0518, +0.1024] | [−0.0550, +0.2286] | tight in-corpus, **crosses zero across experiments**; 8/17 files agree |
| MidBottom | −0.0455 | [−0.0629, −0.0278] | [−0.1443, +0.0522] | same shape, smaller |
| MidTop | −0.0293 | [−0.0552, −0.0045] | [−0.1850, +0.0976] | fails Bonferroni already |
| FlankTop | +0.0552 | [+0.0126, +0.0981] | [−0.0508, +0.1592] | fails Bonferroni |
| HomeDefender | −0.0463 | [−0.0928, +0.0007] | [−0.1744, +0.1156] | crosses zero outright |

None of these is resolvable at this n *in the sense that matters* — they are
resolvable against seed noise and not against the variation between
experiments, which is the variation a new experiment would be drawn from.
Treat all five as level.

### 4. The seat-2/seat-3 gaps are the role swap, not a side effect

**VERIFIED** — By seat, seats 2 and 3 look like large, opposite,
highly-significant side effects (ΔK/D −0.134 and +0.143). Re-paired by role
they collapse to −0.029 (MidTop) and −0.046 (MidBottom). That is exactly what
`world.nim:143-144` predicts: seat 2 is MidBottom for Red and MidTop for Blue,
seat 3 the reverse, because the un-mirrored ±6px spawn offset puts a different
seat closest to the flag on each side. MidTop out-kills MidBottom by ~0.4–0.5
kills/episode **on both sides**, so a seat-indexed reading manufactures a side
effect out of a role difference.

This is why the deliverable reports both pairings, and it is a working check
on the role table itself: had the mapping been transcribed backwards,
re-pairing would have *widened* those two rows instead of collapsing them.

### 5. How much of all this is noise

Quantitatively, for the gv-current era:

- **The side-relabelling null** (relabel which side is "red", per seed block,
  50/50 — an exact null for a ratio statistic) puts 95% of its mass inside
  ±0.048 K/D for the Overwatch contrast and ±0.086 for FlankBottom. Observed:
  +0.515 and −0.396. **Sampling noise accounts for at most ~9% and ~22% of
  those two magnitudes respectively.** For the team gap the null band is
  ±0.010 against an observed +0.036.
- **The clustering matters and is respected.** Resampling loose seat-episodes
  would treat 16 seats in one game as independent and shrink every interval by
  roughly 4×; the intervals here resample whole seed blocks (both directions
  of a seed, which share a terrain and spawn draw), the same unit
  `scripts/local_sim.py`'s `report` uses.
- **Multiplicity is corrected.** Eight seat contrasts and seven role
  contrasts each get a Bonferroni column. Only Overwatch, FlankBottom,
  MidGuard and MidBottom survive it, and only the first two also survive the
  file bootstrap.
- **The binding constraint is not n, it is 17.** 3160 episodes is a lot of
  episodes and only 17 experiments. For every contrast except the two
  headliners, the file interval is 3–6× wider than the seed-pair interval,
  and that ratio — not the episode count — is what decides whether a number
  will still be there next week.

**So: per-seat samples are NOT too small to say anything, but they are only
large enough to say two things.** Blue's Overwatch and red's FlankBottom are
real and big. Everything else in the table, including the team gap itself,
is inside the between-experiment noise and should be reported as level.

### 6. What this gates

- **Backlog item 4 ("blue-specific unmirrored play") — gated, and narrowed.**
  The premise the item rests on — that blue plays the mirrored game at a
  general disadvantage — is **not supported**: under the current pin the team
  gap is +0.036 in *red's* favour and does not survive the file bootstrap.
  What is supported is a single, well-localized target: **blue's Overwatch
  post selection**, worth 0.515 K/D on that seat, ~1.3 kills/episode, and 14
  points of "spent all three lives". A side-specific post table for one role
  is a much smaller change than the item describes and has a measured effect
  size behind it. The mirror-image ask — red's bottom lane — is the second
  candidate. Anything broader than those two is not gated by this analysis.
- **Backlog item 11 (RED-bias localization) — partially answered.** Under the
  current pin the local red episode-win rate is 50.6% (54.0% of decisive), not
  the 63–71% the READMEs record; the K/D side gap is +0.036 and unresolvable.
  What is left of the bias does not concentrate in any one seat.
- **Anything that quotes a per-role number must re-measure it after a pin
  move.** The GV27-vs-current table in §0 is the evidence: the same
  instrument, the same policy family, a different engine, and the answer
  moves by 0.78 K/D on Overwatch and reverses sign.

### 7. Limits of this instrument

- **VERIFIED — Deaths are censored at 3.** `sim/league_config.json` sets
  `lives: 3`, and 93–99% of episodes see the five mid seats spend all three.
  For those seats per-seat K/D is very nearly `kills/3` and the deaths channel
  carries almost no information; only FlankTop, FlankBottom and HomeDefender
  have real variation in deaths. The "spent all 3 lives" column is the
  uncensored read and is reported alongside.
- **VERIFIED — `kills` includes team kills.** The engine calls `recordKill`
  on the shooter unconditionally and *then* `recordTeamKill`
  (`.engine/src/ctf/sim.nim:7897-7898`), so a friendly-fire kill credits the
  shooter. Only the net asymmetry is identifiable, and it is small: total
  kills equal total deaths exactly (136964 each), and blue kills minus red
  deaths is −469 over 3160 episodes — **0.148 kills/episode**, against the
  1.298 kills/episode Overwatch gap. Friendly fire cannot explain the
  headline; it is not separable per seat.
- **VERIFIED — the build cancels, by construction and by check.** Every file
  runs both mirror directions on the same seeds in equal number
  (`mirrored_assign`), so each side is held by the treatment build in half its
  episodes. `role_bleed.py` verifies that balance per file rather than
  assuming it, and reports all 52 files balanced.
- **VERIFIED — the seat→role mapping is fixed and read out of the source.**
  `world.nim:131 roleForSeat(seat, team)` with team = `slot mod 2` (Red even)
  and seat = `slot div 2`; both entry points derive it identically
  (`bot/baseline.nim:135-138`, `sim/host.nim:41-43`) and `bot.role` is
  assigned exactly once, at `Bot(...)` construction, in the whole tree — so
  it cannot change mid-episode.
- **ASSUMED — files after 2026-07-31T07:56Z ran on the current pin.** Era is
  read from file mtime against a cutoff sitting in the gap between the last
  GV27 experiment (07:50) and the first post-re-pin verification run (08:02).
  For the ten files `research/LEDGER.md` names explicitly this is VERIFIED and
  cross-checked in the script; for the seven written after the ledger's last
  entry it is an assumption from the mtime and the unchanged `sim/engine.pin`.
- **ASSUMED — the policy family is close to constant.** The 17 files are 17
  one-knob A/Bs around the v76–v80 tree, several of them follow-ups on the
  same axis. The gaps here are a property of that family, not of any single
  build, and the file bootstrap is the only place that uncertainty is priced.
- **VERIFIED — this is the simulator, not the league.** All four caveats in
  `sim/README.md` apply, in particular: the field is the other build, and a
  local number is not evidence about the standing field.

---

## Generated output

Everything below is the verbatim output of the command at the top of this file.

# Per-role bleed: RED vs BLUE over the banked local-sim episodes

Generated by `analysis/role_bleed.py` (backlog item 9). 10000 bootstrap /
permutation draws, resampling seed 20260731. Corpus frozen at files modified <= 2026-07-31T18:27:00 UTC.

## Corpus

| era | files | episodes | seed blocks | RED win % | draws |
|---|---|---|---|---|---|
| gv-current | 17 | 3160 | 1580 | 50.6 | 200 |
| gv27 | 35 | 5980 | 3000 | 29.8 | 340 |
| **all** | 52 | 9140 | 4580 | 37.0 | 540 |

Files read: 52. Records carrying an `error` (excluded, README rule 7): 0.

<details><summary>per-file snapshot (episodes/ is a live directory; this is what was read)</summary>

| file | mtime (UTC) | era | in ledger | episodes | RED win % |
|---|---|---|---|---|---|
| run-bot-baseline-20260731-052209.jsonl | 2026-07-31 05:22 | gv27 | - | 20 | 50.0 |
| cal-500-vs-420.jsonl | 2026-07-31 05:36 | gv27 | - | 120 | 35.0 |
| exp-nadepickup130.jsonl | 2026-07-31 05:53 | gv27 | - | 600 | 36.5 |
| exp-nadeheld40.jsonl | 2026-07-31 05:54 | gv27 | - | 120 | 33.3 |
| exp-freshshot32-reverse.jsonl | 2026-07-31 05:56 | gv27 | - | 120 | 42.5 |
| exp-nadeheld40-reverse.jsonl | 2026-07-31 05:57 | gv27 | - | 120 | 30.0 |
| exp-shieldflank.jsonl | 2026-07-31 05:58 | gv27 | - | 120 | 34.2 |
| exp-scanarc36.jsonl | 2026-07-31 06:03 | gv27 | - | 400 | 30.2 |
| exp-scanarc36-further.jsonl | 2026-07-31 06:07 | gv27 | - | 400 | 27.5 |
| exp-scanarc36-further-further.jsonl | 2026-07-31 06:08 | gv27 | - | 120 | 32.5 |
| exp-nadememttl240.jsonl | 2026-07-31 06:09 | gv27 | - | 120 | 42.5 |
| exp-nadefoepingcost100.jsonl | 2026-07-31 06:11 | gv27 | - | 120 | 45.8 |
| exp-plasmadetour110.jsonl | 2026-07-31 06:12 | gv27 | - | 120 | 55.0 |
| exp-plasmadetour110-reverse.jsonl | 2026-07-31 06:13 | gv27 | - | 120 | 45.8 |
| exp-medkitdetour120.jsonl | 2026-07-31 06:17 | gv27 | - | 400 | 31.2 |
| exp-medkitdetour120-further.jsonl | 2026-07-31 06:18 | gv27 | - | 120 | 16.7 |
| exp-medkitdetour120-further-reverse.jsonl | 2026-07-31 06:19 | gv27 | - | 120 | 42.5 |
| exp-medkitdetour120-further-reverse-reverse.jsonl | 2026-07-31 06:21 | gv27 | - | 120 | 22.5 |
| exp-carrierbudget140.jsonl | 2026-07-31 06:22 | gv27 | - | 120 | 12.5 |
| exp-scanarc24.jsonl | 2026-07-31 06:28 | gv27 | - | 120 | 34.2 |
| exp-nadefarm580.jsonl | 2026-07-31 06:29 | gv27 | - | 120 | 15.0 |
| exp-scanarc24-reverse.jsonl | 2026-07-31 06:31 | gv27 | - | 120 | 25.0 |
| exp-exposedcost10-local.jsonl | 2026-07-31 06:34 | gv27 | - | 400 | 24.5 |
| exp-pushout-hold-conflict.jsonl | 2026-07-31 07:33 | gv27 | - | 120 | 26.7 |
| exp-combat-strafe.jsonl | 2026-07-31 07:34 | gv27 | - | 120 | 63.3 |
| exp-nade-charge-on-move.jsonl | 2026-07-31 07:36 | gv27 | - | 120 | 22.5 |
| exp-carrier-run-and-gun.jsonl | 2026-07-31 07:40 | gv27 | - | 400 | 19.0 |
| exp-thief-hunt-role-split.jsonl | 2026-07-31 07:41 | gv27 | - | 120 | 26.7 |
| exp-preaim-foe-pings.jsonl | 2026-07-31 07:42 | gv27 | - | 120 | 15.8 |
| exp-escort-screen-unpair.jsonl | 2026-07-31 07:43 | gv27 | - | 120 | 21.7 |
| exp-mate-masked-peek.jsonl | 2026-07-31 07:45 | gv27 | - | 120 | 32.5 |
| exp-defender-intercept-by-flag.jsonl | 2026-07-31 07:46 | gv27 | - | 120 | 16.7 |
| exp-midguard-shield-not-during-escort.jsonl | 2026-07-31 07:47 | gv27 | - | 120 | 19.2 |
| exp-wipe-push.jsonl | 2026-07-31 07:48 | gv27 | - | 120 | 23.3 |
| exp-nade-farm-not-during-thief-chase.jsonl | 2026-07-31 07:50 | gv27 | - | 120 | 19.2 |
| verify-gv29-scanarc28-vs-36.jsonl | 2026-07-31 08:02 | gv-current | yes | 120 | 52.5 |
| verify-gv29-medkit120-vs-80.jsonl | 2026-07-31 08:05 | gv-current | yes | 120 | 45.8 |
| exp-medkitdetour-gv29-revert.jsonl | 2026-07-31 08:45 | gv-current | yes | 120 | 42.5 |
| exp-cooldown-sweep.jsonl | 2026-07-31 08:49 | gv-current | yes | 120 | 37.5 |
| exp-duck-standoff.jsonl | 2026-07-31 08:52 | gv-current | yes | 120 | 39.2 |
| exp-clock-phased-wave.jsonl | 2026-07-31 08:56 | gv-current | yes | 120 | 50.0 |
| exp-corpse-track-cleanup.jsonl | 2026-07-31 09:08 | gv-current | yes | 400 | 51.5 |
| exp-onewaybonus40.jsonl | 2026-07-31 09:20 | gv-current | yes | 400 | 31.2 |
| exp-onewaybonus40-further.jsonl | 2026-07-31 09:24 | gv-current | yes | 120 | 65.0 |
| exp-corpseclear160.jsonl | 2026-07-31 09:30 | gv-current | yes | 120 | 58.3 |
| exp-bothflags-race-escort.jsonl | 2026-07-31 18:16 | gv-current | - | 120 | 69.2 |
| exp-ahead-draw-push.jsonl | 2026-07-31 18:17 | gv-current | - | 120 | 64.2 |
| exp-holdlinedepth160.jsonl | 2026-07-31 18:20 | gv-current | - | 400 | 51.2 |
| exp-holdlinedepth160-further.jsonl | 2026-07-31 18:21 | gv-current | - | 120 | 40.8 |
| exp-holdlinedepth160-further-reverse.jsonl | 2026-07-31 18:22 | gv-current | - | 120 | 55.8 |
| exp-exposedcost6.jsonl | 2026-07-31 18:23 | gv-current | - | 120 | 49.2 |
| exp-exposedcost6-reverse.jsonl | 2026-07-31 18:26 | gv-current | - | 400 | 64.8 |

</details>

## Build balance across sides

A red-minus-blue contrast is build-neutral only if each file ran both directions
in equal number. Checked, per file:

All 52 files balanced (equal `abab...` and `baba...` counts, or a single
all-one-build assign). The build cancels out of every red-minus-blue number below.

## Era: gv-current

3160 episodes, 1580 seed blocks, 17 files.

| side | kills | deaths | K/D | kills/ep | accuracy | spent all 3 lives |
|---|---|---|---|---|---|---|
| red | 69327 | 68106 | 1.0179 | 21.939 | 0.687 | 78.7% |
| blue | 67637 | 68858 | 0.9823 | 21.404 | 0.674 | 81.7% |

A seat holds `lives: 3` (sim/league_config.json), so deaths saturate at 3 and the
last column is the uncensored read on how hard a seat is dying.

### Levels, per side and seat

| side | seat | role | kills/ep | deaths/ep | K/D | accuracy | spent all 3 lives | caps/ep |
|---|---|---|---|---|---|---|---|---|
| red | 0 | FlankBottom | 3.547 | 2.101 | 1.689 | 0.683 | 47.7% | 0.102 |
| red | 1 | MidGuard | 2.085 | 2.971 | 0.702 | 0.711 | 97.2% | 0.012 |
| red | 2 | MidBottom | 2.184 | 2.973 | 0.734 | 0.704 | 97.3% | 0.014 |
| red | 3 | MidTop | 2.456 | 2.928 | 0.839 | 0.698 | 93.3% | 0.035 |
| red | 4 | MidBottom | 1.847 | 2.968 | 0.622 | 0.742 | 97.0% | 0.012 |
| red | 5 | Overwatch | 3.745 | 2.787 | 1.344 | 0.690 | 81.6% | 0.013 |
| red | 6 | FlankTop | 2.826 | 2.361 | 1.197 | 0.628 | 54.0% | 0.100 |
| red | 7 | HomeDefender | 3.249 | 2.463 | 1.319 | 0.646 | 61.2% | 0.030 |
| blue | 0 | FlankBottom | 3.797 | 1.821 | 2.085 | 0.681 | 31.8% | 0.113 |
| blue | 1 | MidGuard | 1.869 | 2.993 | 0.625 | 0.743 | 99.3% | 0.004 |
| blue | 2 | MidTop | 2.570 | 2.960 | 0.868 | 0.705 | 96.3% | 0.015 |
| blue | 3 | MidBottom | 2.075 | 2.984 | 0.695 | 0.642 | 98.4% | 0.009 |
| blue | 4 | MidBottom | 2.239 | 2.976 | 0.752 | 0.711 | 97.6% | 0.010 |
| blue | 5 | Overwatch | 2.447 | 2.953 | 0.829 | 0.655 | 95.5% | 0.002 |
| blue | 6 | FlankTop | 2.871 | 2.515 | 1.142 | 0.675 | 64.4% | 0.064 |
| blue | 7 | HomeDefender | 3.537 | 2.590 | 1.366 | 0.630 | 70.3% | 0.011 |

### Levels, per side and role

(MidBottom pools two seats a side; every other role is one seat. The role split is
symmetric between the sides, so this is an apples-to-apples pairing.)

| role | seats (red/blue) | red kills/ep | blue kills/ep | red K/D | blue K/D | red acc | blue acc |
|---|---|---|---|---|---|---|---|
| FlankBottom | 0/0 | 3.547 | 3.797 | 1.689 | 2.085 | 0.683 | 0.681 |
| MidGuard | 1/1 | 2.085 | 1.869 | 0.702 | 0.625 | 0.711 | 0.743 |
| MidTop | 3/2 | 2.456 | 2.570 | 0.839 | 0.868 | 0.698 | 0.705 |
| MidBottom | 2,4/3,4 | 2.015 | 2.157 | 0.678 | 0.724 | 0.724 | 0.675 |
| Overwatch | 5/5 | 3.745 | 2.447 | 1.344 | 0.829 | 0.690 | 0.655 |
| FlankTop | 6/6 | 2.826 | 2.871 | 1.197 | 1.142 | 0.628 | 0.675 |
| HomeDefender | 7/7 | 3.249 | 3.537 | 1.319 | 1.366 | 0.646 | 0.630 |

### RED minus BLUE, by seat

Seat `s` is engine slots `2s` (red) and `2s+1` (blue) -- the mirrored spawn
position. Positive = red ahead, negative = red bleeding there.

| contrast | ΔK/D | 95% CI (seed pairs) | 99.38% CI (Bonferroni /8) | 95% CI (files) | Δkills/ep | Δdeaths/ep | perm p |
|---|---|---|---|---|---|---|---|
| **seat 0 (FlankBottom/FlankBottom)** | -0.3964 | [-0.4801, -0.3147] | [-0.5114, -0.2799] | [-0.7143, -0.1338] | -0.250 | +0.279 | 0.0001 |
| **seat 1 (MidGuard/MidGuard)** | +0.0772 | [+0.0518, +0.1024] | [+0.0430, +0.1127] | [-0.0550, +0.2286] | +0.216 | -0.022 | 0.0001 |
| **seat 2 (MidBottom/MidTop)** | -0.1335 | [-0.1579, -0.1096] | [-0.1681, -0.1009] | [-0.2489, -0.0189] | -0.386 | +0.013 | 0.0001 |
| **seat 3 (MidTop/MidBottom)** | +0.1432 | [+0.1108, +0.1753] | [+0.0986, +0.1885] | [-0.0864, +0.4129] | +0.381 | -0.055 | 0.0001 |
| **seat 4 (MidBottom/MidBottom)** | -0.1302 | [-0.1549, -0.1053] | [-0.1654, -0.0949] | [-0.2475, -0.0041] | -0.392 | -0.008 | 0.0001 |
| **seat 5 (Overwatch/Overwatch)** | +0.5150 | [+0.4733, +0.5567] | [+0.4561, +0.5745] | [+0.3255, +0.7145] | +1.298 | -0.166 | 0.0001 |
| seat 6 (FlankTop/FlankTop) | +0.0552 | [+0.0126, +0.0981] | [-0.0043, +0.1160] | [-0.0508, +0.1592] | -0.045 | -0.154 | 0.0109 |
| seat 7 (HomeDefender/HomeDefender) | -0.0463 | [-0.0928, +0.0007] | [-0.1095, +0.0192] | [-0.1744, +0.1156] | -0.287 | -0.127 | 0.0517 |

Bold = the seed-pair interval excludes zero at 95% **and** after the Bonferroni
correction for this whole family. `perm p` is the two-sided share of the
side-relabelling null at least this extreme. The file interval is the one that
asks whether the gap survives a different set of experiments -- read it before
acting on any row.

### RED minus BLUE, by role

Re-paired by ROLE, which swaps seats 2 and 3 relative to the table above
(world.nim:143-144). This is the pairing backlog item 4 would act on. The
permutation null here relabels the sides ROLE for role, so the MidTop-vs-
MidBottom difference cannot leak into it.

| contrast | ΔK/D | 95% CI (seed pairs) | 99.29% CI (Bonferroni /7) | 95% CI (files) | Δkills/ep | Δdeaths/ep | perm p |
|---|---|---|---|---|---|---|---|
| **FlankBottom** | -0.3964 | [-0.4801, -0.3147] | [-0.5098, -0.2807] | [-0.7143, -0.1338] | -0.250 | +0.279 | 0.0001 |
| **MidGuard** | +0.0772 | [+0.0518, +0.1024] | [+0.0435, +0.1119] | [-0.0550, +0.2286] | +0.216 | -0.022 | 0.0001 |
| MidTop | -0.0293 | [-0.0552, -0.0045] | [-0.0657, +0.0051] | [-0.1850, +0.0976] | -0.114 | -0.032 | 0.0231 |
| **MidBottom** | -0.0455 | [-0.0629, -0.0278] | [-0.0690, -0.0218] | [-0.1443, +0.0522] | -0.283 | -0.018 | 0.0001 |
| **Overwatch** | +0.5150 | [+0.4733, +0.5567] | [+0.4573, +0.5734] | [+0.3255, +0.7145] | +1.298 | -0.166 | 0.0001 |
| FlankTop | +0.0552 | [+0.0126, +0.0981] | [-0.0033, +0.1155] | [-0.0508, +0.1592] | -0.045 | -0.154 | 0.0104 |
| HomeDefender | -0.0463 | [-0.0928, +0.0007] | [-0.1090, +0.0179] | [-0.1744, +0.1156] | -0.287 | -0.127 | 0.0507 |

Bold = the seed-pair interval excludes zero at 95% **and** after the Bonferroni
correction for this whole family. `perm p` is the two-sided share of the
side-relabelling null at least this extreme. The file interval is the one that
asks whether the gap survives a different set of experiments -- read it before
acting on any row.

### The team gap, and which seats carry it

- team ΔK/D (red - blue): **+0.0357**
  - 95% CI over seed pairs: [+0.0254, +0.0460]
  - 95% CI over files: [-0.0157, +0.0824]
  - null band: [-0.0104, +0.0105], permutation p = 0.0001
- team Δkills/ep: +0.535 (the sum of the eight per-seat Δkills/ep)

| seat | role (red/blue) | Δkills/ep | share of the team gap |
|---|---|---|---|
| 0 | FlankBottom/FlankBottom | -0.250 | -47% |
| 1 | MidGuard/MidGuard | +0.216 | +40% |
| 2 | MidBottom/MidTop | -0.386 | -72% |
| 3 | MidTop/MidBottom | +0.381 | +71% |
| 4 | MidBottom/MidBottom | -0.392 | -73% |
| 5 | Overwatch/Overwatch | +1.298 | +243% |
| 6 | FlankTop/FlankTop | -0.045 | -8% |
| 7 | HomeDefender/HomeDefender | -0.287 | -54% |

A share over 100% means other seats pull the other way. When the team gap is
near zero the percentages are meaningless -- read the signs.

### What zero looks like

The side-relabelling null through exactly the same clustering and statistic.
A gap inside this band is indistinguishable from no side effect at all.

| contrast | null 95% band, ΔK/D | null 95% band, Δkills/ep |
|---|---|---|
| seat 0 | [-0.0856, +0.0857] | [-0.096, +0.099] |
| seat 1 | [-0.0254, +0.0258] | [-0.075, +0.077] |
| seat 2 | [-0.0253, +0.0257] | [-0.074, +0.074] |
| seat 3 | [-0.0336, +0.0337] | [-0.096, +0.096] |
| seat 4 | [-0.0257, +0.0259] | [-0.075, +0.077] |
| seat 5 | [-0.0479, +0.0483] | [-0.124, +0.124] |
| seat 6 | [-0.0428, +0.0429] | [-0.084, +0.084] |
| seat 7 | [-0.0457, +0.0475] | [-0.093, +0.096] |
| all eight seats | [-0.0104, +0.0105] | [-0.128, +0.134] |

### Does each experiment file agree?

The same contrast recomputed inside each of the 17 files on its own. Every
file is a different treatment build and a different seed block, so agreement here
is the closest thing to replication this corpus has.

| contrast | median ΔK/D | min | max | files with the pooled sign |
|---|---|---|---|---|
| seat 0 (FlankBottom/FlankBottom) | -0.3230 | -1.6378 | +0.6414 | 12/17 |
| seat 1 (MidGuard/MidGuard) | -0.0183 | -0.4982 | +0.6465 | 8/17 |
| seat 2 (MidBottom/MidTop) | -0.2038 | -0.5227 | +0.2108 | 12/17 |
| seat 3 (MidTop/MidBottom) | +0.3172 | -0.7299 | +0.8555 | 11/17 |
| seat 4 (MidBottom/MidBottom) | -0.1529 | -0.5003 | +0.4752 | 14/17 |
| seat 5 (Overwatch/Overwatch) | +0.4004 | -0.1106 | +1.3207 | 15/17 |
| seat 6 (FlankTop/FlankTop) | -0.0080 | -0.3317 | +0.4029 | 8/17 |
| seat 7 (HomeDefender/HomeDefender) | -0.0532 | -0.3758 | +0.6753 | 10/17 |
| all eight seats | +0.0390 | -0.1247 | +0.1746 | 10/17 |

### Split-half reproducibility

Alternate seed blocks into two disjoint halves (1580 and 1580 episodes) and
recompute. A gap that flips sign between halves is noise however tight its CI.

| contrast | role (red/blue) | ΔK/D half A | ΔK/D half B | same sign |
|---|---|---|---|---|
| seat 0 | FlankBottom/FlankBottom | -0.3859 | -0.4069 | yes |
| seat 1 | MidGuard/MidGuard | +0.0628 | +0.0915 | yes |
| seat 2 | MidBottom/MidTop | -0.1210 | -0.1460 | yes |
| seat 3 | MidTop/MidBottom | +0.1578 | +0.1286 | yes |
| seat 4 | MidBottom/MidBottom | -0.1353 | -0.1251 | yes |
| seat 5 | Overwatch/Overwatch | +0.5024 | +0.5277 | yes |
| seat 6 | FlankTop/FlankTop | +0.0561 | +0.0542 | yes |
| seat 7 | HomeDefender/HomeDefender | -0.0505 | -0.0421 | yes |
| **all eight** | -- | +0.0354 | +0.0359 | yes |

## Era: gv27

5980 episodes, 3000 seed blocks, 35 files.

| side | kills | deaths | K/D | kills/ep | accuracy | spent all 3 lives |
|---|---|---|---|---|---|---|
| red | 122377 | 131932 | 0.9276 | 20.464 | 0.647 | 84.0% |
| blue | 135472 | 125917 | 1.0759 | 22.654 | 0.643 | 75.1% |

A seat holds `lives: 3` (sim/league_config.json), so deaths saturate at 3 and the
last column is the uncensored read on how hard a seat is dying.

### Levels, per side and seat

| side | seat | role | kills/ep | deaths/ep | K/D | accuracy | spent all 3 lives | caps/ep |
|---|---|---|---|---|---|---|---|---|
| red | 0 | FlankBottom | 3.967 | 1.903 | 2.084 | 0.672 | 40.4% | 0.062 |
| red | 1 | MidGuard | 1.421 | 2.993 | 0.475 | 0.675 | 99.3% | 0.003 |
| red | 2 | MidBottom | 1.446 | 2.991 | 0.483 | 0.601 | 99.1% | 0.005 |
| red | 3 | MidTop | 1.903 | 2.980 | 0.638 | 0.687 | 98.1% | 0.009 |
| red | 4 | MidBottom | 1.431 | 2.995 | 0.478 | 0.612 | 99.5% | 0.003 |
| red | 5 | Overwatch | 2.486 | 2.891 | 0.860 | 0.636 | 90.7% | 0.003 |
| red | 6 | FlankTop | 4.255 | 2.467 | 1.725 | 0.635 | 59.3% | 0.077 |
| red | 7 | HomeDefender | 3.557 | 2.842 | 1.252 | 0.658 | 85.9% | 0.006 |
| blue | 0 | FlankBottom | 3.482 | 1.664 | 2.093 | 0.642 | 27.8% | 0.168 |
| blue | 1 | MidGuard | 1.613 | 2.983 | 0.541 | 0.683 | 98.4% | 0.009 |
| blue | 2 | MidTop | 3.091 | 2.928 | 1.056 | 0.682 | 93.1% | 0.025 |
| blue | 3 | MidBottom | 3.553 | 2.910 | 1.221 | 0.746 | 91.6% | 0.037 |
| blue | 4 | MidBottom | 2.591 | 2.923 | 0.887 | 0.638 | 92.7% | 0.034 |
| blue | 5 | Overwatch | 2.957 | 2.628 | 1.125 | 0.573 | 69.5% | 0.018 |
| blue | 6 | FlankTop | 2.258 | 2.714 | 0.832 | 0.638 | 75.2% | 0.074 |
| blue | 7 | HomeDefender | 3.110 | 2.306 | 1.349 | 0.594 | 52.7% | 0.041 |

### Levels, per side and role

(MidBottom pools two seats a side; every other role is one seat. The role split is
symmetric between the sides, so this is an apples-to-apples pairing.)

| role | seats (red/blue) | red kills/ep | blue kills/ep | red K/D | blue K/D | red acc | blue acc |
|---|---|---|---|---|---|---|---|
| FlankBottom | 0/0 | 3.967 | 3.482 | 2.084 | 2.093 | 0.672 | 0.642 |
| MidGuard | 1/1 | 1.421 | 1.613 | 0.475 | 0.541 | 0.675 | 0.683 |
| MidTop | 3/2 | 1.903 | 3.091 | 0.638 | 1.056 | 0.687 | 0.682 |
| MidBottom | 2,4/3,4 | 1.439 | 3.072 | 0.481 | 1.053 | 0.606 | 0.691 |
| Overwatch | 5/5 | 2.486 | 2.957 | 0.860 | 1.125 | 0.636 | 0.573 |
| FlankTop | 6/6 | 4.255 | 2.258 | 1.725 | 0.832 | 0.635 | 0.638 |
| HomeDefender | 7/7 | 3.557 | 3.110 | 1.252 | 1.349 | 0.658 | 0.594 |

### RED minus BLUE, by seat

Seat `s` is engine slots `2s` (red) and `2s+1` (blue) -- the mirrored spawn
position. Positive = red ahead, negative = red bleeding there.

| contrast | ΔK/D | 95% CI (seed pairs) | 99.38% CI (Bonferroni /8) | 95% CI (files) | Δkills/ep | Δdeaths/ep | perm p |
|---|---|---|---|---|---|---|---|
| seat 0 (FlankBottom/FlankBottom) | -0.0083 | [-0.0817, +0.0629] | [-0.1108, +0.0897] | [-0.2505, +0.2070] | +0.485 | +0.239 | 0.8199 |
| **seat 1 (MidGuard/MidGuard)** | -0.0659 | [-0.0844, -0.0479] | [-0.0919, -0.0415] | [-0.1417, +0.0022] | -0.192 | +0.010 | 0.0001 |
| **seat 2 (MidBottom/MidTop)** | -0.5725 | [-0.5917, -0.5532] | [-0.5999, -0.5453] | [-0.6406, -0.5028] | -1.646 | +0.063 | 0.0001 |
| **seat 3 (MidTop/MidBottom)** | -0.5824 | [-0.6061, -0.5577] | [-0.6158, -0.5491] | [-0.7743, -0.4057] | -1.650 | +0.070 | 0.0001 |
| **seat 4 (MidBottom/MidBottom)** | -0.4086 | [-0.4297, -0.3873] | [-0.4382, -0.3792] | [-0.5442, -0.2755] | -1.160 | +0.072 | 0.0001 |
| **seat 5 (Overwatch/Overwatch)** | -0.2652 | [-0.2944, -0.2360] | [-0.3058, -0.2248] | [-0.3442, -0.1804] | -0.471 | +0.263 | 0.0001 |
| **seat 6 (FlankTop/FlankTop)** | +0.8928 | [+0.8589, +0.9272] | [+0.8454, +0.9390] | [+0.8253, +0.9493] | +1.997 | -0.247 | 0.0001 |
| **seat 7 (HomeDefender/HomeDefender)** | -0.0971 | [-0.1341, -0.0613] | [-0.1475, -0.0498] | [-0.2085, +0.0315] | +0.447 | +0.536 | 0.0001 |

Bold = the seed-pair interval excludes zero at 95% **and** after the Bonferroni
correction for this whole family. `perm p` is the two-sided share of the
side-relabelling null at least this extreme. The file interval is the one that
asks whether the gap survives a different set of experiments -- read it before
acting on any row.

### RED minus BLUE, by role

Re-paired by ROLE, which swaps seats 2 and 3 relative to the table above
(world.nim:143-144). This is the pairing backlog item 4 would act on. The
permutation null here relabels the sides ROLE for role, so the MidTop-vs-
MidBottom difference cannot leak into it.

| contrast | ΔK/D | 95% CI (seed pairs) | 99.29% CI (Bonferroni /7) | 95% CI (files) | Δkills/ep | Δdeaths/ep | perm p |
|---|---|---|---|---|---|---|---|
| FlankBottom | -0.0083 | [-0.0817, +0.0629] | [-0.1093, +0.0890] | [-0.2505, +0.2070] | +0.485 | +0.239 | 0.8264 |
| **MidGuard** | -0.0659 | [-0.0844, -0.0479] | [-0.0916, -0.0419] | [-0.1417, +0.0022] | -0.192 | +0.010 | 0.0001 |
| **MidTop** | -0.4175 | [-0.4403, -0.3945] | [-0.4485, -0.3853] | [-0.5906, -0.2408] | -1.189 | +0.053 | 0.0001 |
| **MidBottom** | -0.5726 | [-0.5884, -0.5566] | [-0.5945, -0.5504] | [-0.6880, -0.4610] | -3.267 | +0.152 | 0.0001 |
| **Overwatch** | -0.2652 | [-0.2944, -0.2360] | [-0.3053, -0.2250] | [-0.3442, -0.1804] | -0.471 | +0.263 | 0.0001 |
| **FlankTop** | +0.8928 | [+0.8589, +0.9272] | [+0.8464, +0.9386] | [+0.8253, +0.9493] | +1.997 | -0.247 | 0.0001 |
| **HomeDefender** | -0.0971 | [-0.1341, -0.0613] | [-0.1471, -0.0503] | [-0.2085, +0.0315] | +0.447 | +0.536 | 0.0001 |

Bold = the seed-pair interval excludes zero at 95% **and** after the Bonferroni
correction for this whole family. `perm p` is the two-sided share of the
side-relabelling null at least this extreme. The file interval is the one that
asks whether the gap survives a different set of experiments -- read it before
acting on any row.

### The team gap, and which seats carry it

- team ΔK/D (red - blue): **-0.1483**
  - 95% CI over seed pairs: [-0.1564, -0.1404]
  - 95% CI over files: [-0.1807, -0.1157]
  - null band: [-0.0097, +0.0094], permutation p = 0.0001
- team Δkills/ep: -2.190 (the sum of the eight per-seat Δkills/ep)

| seat | role (red/blue) | Δkills/ep | share of the team gap |
|---|---|---|---|
| 0 | FlankBottom/FlankBottom | +0.485 | -22% |
| 1 | MidGuard/MidGuard | -0.192 | +9% |
| 2 | MidBottom/MidTop | -1.646 | +75% |
| 3 | MidTop/MidBottom | -1.650 | +75% |
| 4 | MidBottom/MidBottom | -1.160 | +53% |
| 5 | Overwatch/Overwatch | -0.471 | +21% |
| 6 | FlankTop/FlankTop | +1.997 | -91% |
| 7 | HomeDefender/HomeDefender | +0.447 | -20% |

A share over 100% means other seats pull the other way. When the team gap is
near zero the percentages are meaningless -- read the signs.

### What zero looks like

The side-relabelling null through exactly the same clustering and statistic.
A gap inside this band is indistinguishable from no side effect at all.

| contrast | null 95% band, ΔK/D | null 95% band, Δkills/ep |
|---|---|---|
| seat 0 | [-0.0713, +0.0700] | [-0.080, +0.079] |
| seat 1 | [-0.0179, +0.0181] | [-0.053, +0.054] |
| seat 2 | [-0.0274, +0.0283] | [-0.079, +0.082] |
| seat 3 | [-0.0314, +0.0312] | [-0.089, +0.089] |
| seat 4 | [-0.0255, +0.0256] | [-0.073, +0.074] |
| seat 5 | [-0.0307, +0.0296] | [-0.074, +0.071] |
| seat 6 | [-0.0460, +0.0460] | [-0.101, +0.100] |
| seat 7 | [-0.0359, +0.0361] | [-0.076, +0.078] |
| all eight seats | [-0.0097, +0.0094] | [-0.130, +0.129] |

### Does each experiment file agree?

The same contrast recomputed inside each of the 35 files on its own. Every
file is a different treatment build and a different seed block, so agreement here
is the closest thing to replication this corpus has.

| contrast | median ΔK/D | min | max | files with the pooled sign |
|---|---|---|---|---|
| seat 0 (FlankBottom/FlankBottom) | +0.2526 | -1.5723 | +0.9224 | 13/35 |
| seat 1 (MidGuard/MidGuard) | -0.0096 | -0.5092 | +0.3448 | 20/35 |
| seat 2 (MidBottom/MidTop) | -0.6162 | -0.8446 | +0.0912 | 34/35 |
| seat 3 (MidTop/MidBottom) | -0.6983 | -1.1941 | +0.0853 | 34/35 |
| seat 4 (MidBottom/MidBottom) | -0.5188 | -0.9144 | +0.0805 | 30/35 |
| seat 5 (Overwatch/Overwatch) | -0.3022 | -0.5930 | +0.5995 | 29/35 |
| seat 6 (FlankTop/FlankTop) | +0.9034 | +0.0044 | +1.2760 | 35/35 |
| seat 7 (HomeDefender/HomeDefender) | -0.1690 | -0.6436 | +0.9274 | 26/35 |
| all eight seats | -0.1680 | -0.2794 | +0.1561 | 34/35 |

### Split-half reproducibility

Alternate seed blocks into two disjoint halves (2990 and 2990 episodes) and
recompute. A gap that flips sign between halves is noise however tight its CI.

| contrast | role (red/blue) | ΔK/D half A | ΔK/D half B | same sign |
|---|---|---|---|---|
| seat 0 | FlankBottom/FlankBottom | -0.0204 | +0.0042 | **NO** |
| seat 1 | MidGuard/MidGuard | -0.0758 | -0.0560 | yes |
| seat 2 | MidBottom/MidTop | -0.5758 | -0.5692 | yes |
| seat 3 | MidTop/MidBottom | -0.5835 | -0.5813 | yes |
| seat 4 | MidBottom/MidBottom | -0.4076 | -0.4096 | yes |
| seat 5 | Overwatch/Overwatch | -0.2594 | -0.2710 | yes |
| seat 6 | FlankTop/FlankTop | +0.8876 | +0.8980 | yes |
| seat 7 | HomeDefender/HomeDefender | -0.0978 | -0.0964 | yes |
| **all eight** | -- | -0.1491 | -0.1475 | yes |

## Era: pooled (BOTH pins -- see the caveat above)

9140 episodes, 4580 seed blocks, 52 files.

| side | kills | deaths | K/D | kills/ep | accuracy | spent all 3 lives |
|---|---|---|---|---|---|---|
| red | 191704 | 200038 | 0.9583 | 20.974 | 0.661 | 82.2% |
| blue | 203109 | 194775 | 1.0428 | 22.222 | 0.654 | 77.4% |

A seat holds `lives: 3` (sim/league_config.json), so deaths saturate at 3 and the
last column is the uncensored read on how hard a seat is dying.

### Levels, per side and seat

| side | seat | role | kills/ep | deaths/ep | K/D | accuracy | spent all 3 lives | caps/ep |
|---|---|---|---|---|---|---|---|---|
| red | 0 | FlankBottom | 3.822 | 1.971 | 1.939 | 0.675 | 42.9% | 0.076 |
| red | 1 | MidGuard | 1.650 | 2.986 | 0.553 | 0.689 | 98.6% | 0.006 |
| red | 2 | MidBottom | 1.701 | 2.985 | 0.570 | 0.633 | 98.5% | 0.008 |
| red | 3 | MidTop | 2.094 | 2.962 | 0.707 | 0.690 | 96.4% | 0.018 |
| red | 4 | MidBottom | 1.575 | 2.985 | 0.528 | 0.658 | 98.6% | 0.006 |
| red | 5 | Overwatch | 2.921 | 2.855 | 1.023 | 0.657 | 87.5% | 0.006 |
| red | 6 | FlankTop | 3.761 | 2.430 | 1.547 | 0.633 | 57.5% | 0.085 |
| red | 7 | HomeDefender | 3.451 | 2.711 | 1.273 | 0.654 | 77.4% | 0.014 |
| blue | 0 | FlankBottom | 3.591 | 1.718 | 2.090 | 0.659 | 29.2% | 0.149 |
| blue | 1 | MidGuard | 1.701 | 2.987 | 0.570 | 0.702 | 98.7% | 0.007 |
| blue | 2 | MidTop | 2.911 | 2.939 | 0.990 | 0.690 | 94.2% | 0.021 |
| blue | 3 | MidBottom | 3.042 | 2.936 | 1.036 | 0.710 | 93.9% | 0.027 |
| blue | 4 | MidBottom | 2.469 | 2.941 | 0.840 | 0.661 | 94.4% | 0.026 |
| blue | 5 | Overwatch | 2.780 | 2.740 | 1.015 | 0.598 | 78.5% | 0.012 |
| blue | 6 | FlankTop | 2.470 | 2.645 | 0.934 | 0.649 | 71.4% | 0.070 |
| blue | 7 | HomeDefender | 3.257 | 2.404 | 1.355 | 0.607 | 58.8% | 0.031 |

### Levels, per side and role

(MidBottom pools two seats a side; every other role is one seat. The role split is
symmetric between the sides, so this is an apples-to-apples pairing.)

| role | seats (red/blue) | red kills/ep | blue kills/ep | red K/D | blue K/D | red acc | blue acc |
|---|---|---|---|---|---|---|---|
| FlankBottom | 0/0 | 3.822 | 3.591 | 1.939 | 2.090 | 0.675 | 0.659 |
| MidGuard | 1/1 | 1.650 | 1.701 | 0.553 | 0.570 | 0.689 | 0.702 |
| MidTop | 3/2 | 2.094 | 2.911 | 0.707 | 0.990 | 0.690 | 0.690 |
| MidBottom | 2,4/3,4 | 1.638 | 2.756 | 0.549 | 0.938 | 0.645 | 0.685 |
| Overwatch | 5/5 | 2.921 | 2.780 | 1.023 | 1.015 | 0.657 | 0.598 |
| FlankTop | 6/6 | 3.761 | 2.470 | 1.547 | 0.934 | 0.633 | 0.649 |
| HomeDefender | 7/7 | 3.451 | 3.257 | 1.273 | 1.355 | 0.654 | 0.607 |

### RED minus BLUE, by seat

Seat `s` is engine slots `2s` (red) and `2s+1` (blue) -- the mirrored spawn
position. Positive = red ahead, negative = red bleeding there.

| contrast | ΔK/D | 95% CI (seed pairs) | 99.38% CI (Bonferroni /8) | 95% CI (files) | Δkills/ep | Δdeaths/ep | perm p |
|---|---|---|---|---|---|---|---|
| **seat 0 (FlankBottom/FlankBottom)** | -0.1513 | [-0.2073, -0.0963] | [-0.2297, -0.0726] | [-0.3418, +0.0271] | +0.231 | +0.253 | 0.0001 |
| seat 1 (MidGuard/MidGuard) | -0.0169 | [-0.0316, -0.0020] | [-0.0372, +0.0045] | [-0.0884, +0.0563] | -0.051 | -0.001 | 0.0244 |
| **seat 2 (MidBottom/MidTop)** | -0.4206 | [-0.4364, -0.4039] | [-0.4420, -0.3975] | [-0.5120, -0.3254] | -1.210 | +0.046 | 0.0001 |
| **seat 3 (MidTop/MidBottom)** | -0.3294 | [-0.3510, -0.3077] | [-0.3594, -0.2984] | [-0.4994, -0.1646] | -0.948 | +0.027 | 0.0001 |
| **seat 4 (MidBottom/MidBottom)** | -0.3121 | [-0.3288, -0.2949] | [-0.3354, -0.2883] | [-0.4190, -0.2114] | -0.895 | +0.044 | 0.0001 |
| seat 5 (Overwatch/Overwatch) | +0.0085 | [-0.0174, +0.0349] | [-0.0280, +0.0460] | [-0.1372, +0.1615] | +0.141 | +0.115 | 0.5291 |
| **seat 6 (FlankTop/FlankTop)** | +0.6137 | [+0.5843, +0.6430] | [+0.5744, +0.6535] | [+0.4755, +0.7418] | +1.291 | -0.215 | 0.0001 |
| **seat 7 (HomeDefender/HomeDefender)** | -0.0821 | [-0.1110, -0.0533] | [-0.1214, -0.0418] | [-0.1723, +0.0191] | +0.193 | +0.307 | 0.0001 |

Bold = the seed-pair interval excludes zero at 95% **and** after the Bonferroni
correction for this whole family. `perm p` is the two-sided share of the
side-relabelling null at least this extreme. The file interval is the one that
asks whether the gap survives a different set of experiments -- read it before
acting on any row.

### RED minus BLUE, by role

Re-paired by ROLE, which swaps seats 2 and 3 relative to the table above
(world.nim:143-144). This is the pairing backlog item 4 would act on. The
permutation null here relabels the sides ROLE for role, so the MidTop-vs-
MidBottom difference cannot leak into it.

| contrast | ΔK/D | 95% CI (seed pairs) | 99.29% CI (Bonferroni /7) | 95% CI (files) | Δkills/ep | Δdeaths/ep | perm p |
|---|---|---|---|---|---|---|---|
| **FlankBottom** | -0.1513 | [-0.2073, -0.0963] | [-0.2288, -0.0734] | [-0.3418, +0.0271] | +0.231 | +0.253 | 0.0001 |
| MidGuard | -0.0169 | [-0.0316, -0.0020] | [-0.0370, +0.0042] | [-0.0884, +0.0563] | -0.051 | -0.001 | 0.0251 |
| **MidTop** | -0.2836 | [-0.3016, -0.2653] | [-0.3086, -0.2584] | [-0.4222, -0.1534] | -0.817 | +0.023 | 0.0001 |
| **MidBottom** | -0.3891 | [-0.4031, -0.3746] | [-0.4087, -0.3696] | [-0.5000, -0.2830] | -2.236 | +0.093 | 0.0001 |
| Overwatch | +0.0085 | [-0.0174, +0.0349] | [-0.0275, +0.0452] | [-0.1372, +0.1615] | +0.141 | +0.115 | 0.5163 |
| **FlankTop** | +0.6137 | [+0.5843, +0.6430] | [+0.5749, +0.6529] | [+0.4755, +0.7418] | +1.291 | -0.215 | 0.0001 |
| **HomeDefender** | -0.0821 | [-0.1110, -0.0533] | [-0.1204, -0.0424] | [-0.1723, +0.0191] | +0.193 | +0.307 | 0.0001 |

Bold = the seed-pair interval excludes zero at 95% **and** after the Bonferroni
correction for this whole family. `perm p` is the two-sided share of the
side-relabelling null at least this extreme. The file interval is the one that
asks whether the gap survives a different set of experiments -- read it before
acting on any row.

### The team gap, and which seats carry it

- team ΔK/D (red - blue): **-0.0844**
  - 95% CI over seed pairs: [-0.0913, -0.0775]
  - 95% CI over files: [-0.1228, -0.0456]
  - null band: [-0.0073, +0.0072], permutation p = 0.0001
- team Δkills/ep: -1.248 (the sum of the eight per-seat Δkills/ep)

| seat | role (red/blue) | Δkills/ep | share of the team gap |
|---|---|---|---|
| 0 | FlankBottom/FlankBottom | +0.231 | -18% |
| 1 | MidGuard/MidGuard | -0.051 | +4% |
| 2 | MidBottom/MidTop | -1.210 | +97% |
| 3 | MidTop/MidBottom | -0.948 | +76% |
| 4 | MidBottom/MidBottom | -0.895 | +72% |
| 5 | Overwatch/Overwatch | +0.141 | -11% |
| 6 | FlankTop/FlankTop | +1.291 | -103% |
| 7 | HomeDefender/HomeDefender | +0.193 | -15% |

A share over 100% means other seats pull the other way. When the team gap is
near zero the percentages are meaningless -- read the signs.

### What zero looks like

The side-relabelling null through exactly the same clustering and statistic.
A gap inside this band is indistinguishable from no side effect at all.

| contrast | null 95% band, ΔK/D | null 95% band, Δkills/ep |
|---|---|---|
| seat 0 | [-0.0553, +0.0537] | [-0.062, +0.064] |
| seat 1 | [-0.0147, +0.0149] | [-0.043, +0.044] |
| seat 2 | [-0.0200, +0.0200] | [-0.058, +0.058] |
| seat 3 | [-0.0234, +0.0237] | [-0.067, +0.068] |
| seat 4 | [-0.0189, +0.0189] | [-0.055, +0.055] |
| seat 5 | [-0.0266, +0.0264] | [-0.066, +0.066] |
| seat 6 | [-0.0339, +0.0343] | [-0.071, +0.071] |
| seat 7 | [-0.0288, +0.0286] | [-0.060, +0.060] |
| all eight seats | [-0.0073, +0.0072] | [-0.096, +0.095] |

### Does each experiment file agree?

The same contrast recomputed inside each of the 52 files on its own. Every
file is a different treatment build and a different seed block, so agreement here
is the closest thing to replication this corpus has.

| contrast | median ΔK/D | min | max | files with the pooled sign |
|---|---|---|---|---|
| seat 0 (FlankBottom/FlankBottom) | +0.1190 | -1.6378 | +0.9224 | 25/52 |
| seat 1 (MidGuard/MidGuard) | -0.0096 | -0.5092 | +0.6465 | 29/52 |
| seat 2 (MidBottom/MidTop) | -0.5010 | -0.8446 | +0.2108 | 46/52 |
| seat 3 (MidTop/MidBottom) | -0.3821 | -1.1941 | +0.8555 | 40/52 |
| seat 4 (MidBottom/MidBottom) | -0.2798 | -0.9144 | +0.4752 | 44/52 |
| seat 5 (Overwatch/Overwatch) | -0.1218 | -0.5930 | +1.3207 | 21/52 |
| seat 6 (FlankTop/FlankTop) | +0.8409 | -0.3317 | +1.2760 | 43/52 |
| seat 7 (HomeDefender/HomeDefender) | -0.1357 | -0.6436 | +0.9274 | 36/52 |
| all eight seats | -0.0653 | -0.2794 | +0.1746 | 40/52 |

### Split-half reproducibility

Alternate seed blocks into two disjoint halves (4570 and 4570 episodes) and
recompute. A gap that flips sign between halves is noise however tight its CI.

| contrast | role (red/blue) | ΔK/D half A | ΔK/D half B | same sign |
|---|---|---|---|---|
| seat 0 | FlankBottom/FlankBottom | -0.1537 | -0.1488 | yes |
| seat 1 | MidGuard/MidGuard | -0.0283 | -0.0054 | yes |
| seat 2 | MidBottom/MidTop | -0.4186 | -0.4226 | yes |
| seat 3 | MidTop/MidBottom | -0.3253 | -0.3335 | yes |
| seat 4 | MidBottom/MidBottom | -0.3132 | -0.3110 | yes |
| seat 5 | Overwatch/Overwatch | +0.0081 | +0.0089 | yes |
| seat 6 | FlankTop/FlankTop | +0.6107 | +0.6167 | yes |
| seat 7 | HomeDefender/HomeDefender | -0.0847 | -0.0796 | yes |
| **all eight** | -- | -0.0851 | -0.0838 | yes |

