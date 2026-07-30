# The v29+ re-measurement: every lever re-run on a build that can throw

Every A/B between v12 and v27 was measured on a grenade-blind binary
(`NOTES-provenance.md`), so none of those numbers transfer. v28 established
that the restored `bot/nimby.lock` closes the gap and that the archive is a
faithful champion base again. This file is the re-run of every queued lever on
that base.

## The build these arms came from

Two images, both archive HEAD, both through the restored lock (bitworld
`5d229ac`, the only lineage that carries ButtonC / the grenade throw):

- `ctf-plain` — no extra defines.
- `ctf-shout` — `-d:shoutIntel`.

`bot/Dockerfile.sandbox` needed a fix before either was usable. It compiled
with `--out:baseline`, but this archive's layout already has a **directory**
called `baseline/` (the protocol client) in the build context. Nim will not
overwrite a directory: it silently retargeted the link to `baseline.out`,
exited 0, and the run stage then copied the *source directory* to
`/bin/baseline`. The image built clean, contained no binary at all, and would
have failed only when something tried to run it. Fixed by linking to
`bot.bin` and copying that. This is the same failure shape as the ButtonC
truncation — structurally valid, silent, and wrong — and it is worth saying
plainly that the recipe was committed in that state.

## Verify mechanically before spending an A/B

Three of the thirteen requested levers are **unreachable** in the
configuration an unwary control would have used. Running them that way would
have bought a guaranteed null on 80 episodes apiece.

| lever | gate | consequence |
|---|---|---|
| `CTF_LEVER_SHOUTSEEN` | inside `when defined(shoutIntel)` (baseline.nim:2051) | dead in `ctf-plain` |
| `CTF_LEVER_SPAWNINTEL` | inside `when defined(shoutIntel)` (2493, 2635) | dead in `ctf-plain` |
| `CTF_LEVER_CROSSFIRE` | nested inside `if CTF_LEVER_HOLDLINE …` (3684) and `if depth > HoldLineDepth` (3692) | inert unless `HOLDLINE=1` |
| `CTF_LEVER_HOLDEVEN` | only feeds `behindOrLevel` → `holdNow`, read solely by the `CTF_LEVER_HOLDLINE` condition (3681-3685) | inert unless `HOLDLINE=1` |

The first two are confirmed by the compiler itself — building `ctf-plain`
emits:

    baseline.nim(185, 3) Hint: 'CTF_LEVER_SPAWNINTEL' is declared but not used
    baseline.nim(194, 3) Hint: 'CTF_LEVER_SHOUTSEEN' is declared but not used

and `ctf-shout` emits no such hint for any lever. So `SHOUTSEEN` and
`SPAWNINTEL` are measured on the shoutIntel image, and `CROSSFIRE` and
`HOLDEVEN` are measured against a **`HOLDLINE=1` control** rather than the
plain one.

The rest were confirmed live at runtime with `-d:combatDebug`, one local
episode with every lever on and one with every lever off, counters summed
across all reporting seats:

| counter | all-on | all-off | lever |
|---|---|---|---|
| `duckLob` | 62 | 0 | NADEDUCK |
| `holdClamp` | 1437 | 0 | HOLDLINE |
| `hurtSweep` | 343 | 0 | HURTLOOK |
| `oddsDecline` | 5 | 0 | ODDS |
| `angleTry` / `anglePost` | 573 / 494 | 0 / 0 | CROSSFIRE |
| `stalled` | 0 | 10 | AIMBAND + STAREBREAK (fewer stalls is the intended direction) |
| `threw` | 1 | 2 | grenade throw — the ButtonC pin is live in these builds |

That table is also the proof that `--secret-env` actually reaches the bot: the
same binary produces both columns.

Two caveats recorded rather than hidden:

- **`CTF_LEVER_CARRIERSHY` was never caught firing.** It is compiler-live (no
  dead-code hint) but gated on `iCarry`, and no sampled seat was carrying at a
  dump tick. Carrying does happen (`carryTicks` 527 in the all-off run), so the
  lever is reachable — but it only acts during flag carries, which are rare,
  so this A/B has less power than the others and a null for it should be read
  as "no effect detected", not "no effect".
- **`CTF_LEVER_ARCRAID` has no debug counter.** It is compiler-live and was
  behaviourally measured before as v11.

## Arm table

Base config **C0** is the v9-equivalent champion configuration on a correctly
pinned build: `CTF_FIX_AIMBAND=0 CTF_FIX_STAREBREAK=0 CTF_LEVER_ARCRAID=0`,
every opt-in lever at its default off, every proven v2–v9 lever on. One
binary per image; the arms differ only in the secret env they carry.

| version | arm | image | env beyond C0 |
|---|---|---|---|
| v29 | ctrl | plain | — |
| v30 | arcraid | plain | `ARCRAID=1` |
| v31 | aimband | plain | `AIMBAND=1` |
| v32 | starebreak | plain | `STAREBREAK=1` |
| v33 | nadeduck | plain | `NADEDUCK=1` |
| v34 | holdline | plain | `HOLDLINE=1` |
| v35 | hurtlook | plain | `HURTLOOK=1` |
| v36 | carriershy | plain | `CARRIERSHY=1` |
| v37 | odds | plain | `ODDS=1` |
| v38 | crossfire | plain | `HOLDLINE=1 CROSSFIRE=1` |
| v39 | holdeven | plain | `HOLDLINE=1 HOLDEVEN=1` |
| v40 | shoutctrl | shout | `SHOUTSEEN=0` |
| v41 | shoutseen | shout | `SHOUTSEEN=1` |
| v42 | shoutspawn | shout | `SHOUTSEEN=1 SPAWNINTEL=1` |

Each experiment is a both-directions head-to-head, 40 episodes per direction,
both directions created back to back so they run at the same time. Only one
experiment is in flight at a time.

| # | experiment | treatment | control |
|---|---|---|---|
| 1 | `CTF_LEVER_ARCRAID` | v30 | v29 |
| 2 | `CTF_FIX_AIMBAND` | v31 | v29 |
| 3 | `CTF_FIX_STAREBREAK` | v32 | v29 |
| 4 | `CTF_LEVER_NADEDUCK` | v33 | v29 |
| 5 | `CTF_LEVER_HOLDLINE` | v34 | v29 |
| 6 | `CTF_LEVER_HURTLOOK` | v35 | v29 |
| 7 | `CTF_LEVER_CROSSFIRE` | v38 | **v34** |
| 8 | `CTF_LEVER_CARRIERSHY` | v36 | v29 |
| 9 | `CTF_LEVER_ODDS` | v37 | v29 |
| 10 | `CTF_LEVER_HOLDEVEN` | v39 | **v34** |
| 11 | `CTF_LEVER_SHOUTSEEN` | v41 | **v40** |
| 12 | `CTF_LEVER_SPAWNINTEL` | v42 | **v41** |
| 13 | `-d:shoutIntel` | v41 | v29 |

Experiment 13 tests the Shout-Intel family at its best-known send policy
(shout-only-when-seen on, spawn intel off), which is what the image defaults
to; it is the family question, not a send-policy question.

## The analysis path was checked against a known answer first

Before any new result was read, `pool_and_record.py` was pointed at the v28
mirror, whose verdict is already written down in `NOTES-provenance.md`. It
reproduces it exactly — K/D gap **+0.0207**, 95% CI **[−0.0564, +0.0983]**,
win-rate gap +0.050, capture gap −2, 80 episodes pooled, 0 skipped, against a
recorded +0.021 / [−0.056, +0.098] / 52.5-47.5 / 16-18. So the
fetch → re-key by seat → pool → bootstrap → sign-normalise path is not being
trusted on faith. Full output in `results/selftest_v28.txt`.

## `-d:shoutIntel` got 160 episodes, and needed them

An accident produced a second, independently timed, direction-balanced pair
for this one comparison: a driver process survived a kill, resumed, and
created its own copy of the last experiment alongside the intended one. Both
pairs are internally valid — each has v41 and v29 on both sides — so all four
requests pool into one 160-episode verdict. It is worth reading what the extra
80 episodes did.

| sample | K/D gap (v41 − v29) | 95% CI | verdict |
|---|---|---|---|
| first pair, 80 eps | −0.0758 | [−0.1503, **−0.0011**] | SEPARATES, barely |
| all four, 160 eps | −0.0385 | [−0.0909, **+0.0138**] | level |

The 80-episode result cleared the bar by 0.0011 K/D and would have been
written down as a confirmed regression. It does not survive doubling the
sample. The per-direction win rates show where it came from:

    xreq_8b478c34  RED=v41  20/40 (50.0%)   <- the outlier
    xreq_7da11fb8  RED=v29  29/40 (72.5%)
    xreq_28f665d5  RED=v41  30/40 (75.0%)
    xreq_b457a9b6  RED=v29  29/40 (72.5%)

RED wins 67.5% of these 160 episodes. Three of the four directions sit near
that; one direction, v41 on RED, returned 50.0%. That single unlucky direction
is the whole of the first pair's "separation" — and a both-directions design
does not protect against it, because the pooling is only as good as the noise
in each direction. So the shipped rule in this repo ("run both directions,
then pool") is necessary and still not sufficient at n=80 for effects this
small.

The recorded verdict for `-d:shoutIntel` is the 160-episode one: **level**.
Read together with the two send-policy experiments — `SHOUTSEEN` level,
`SPAWNINTEL` level — the honest summary of the whole Shout-Intel family on a
correctly built bot is that it neither helps nor hurts measurably, which
retires the earlier "marginal but real" −0.083 regression finding rather than
confirming it.

One consequence for everything else in this table: **every other row here is
n=80**, and a marginal separation at n=80 is exactly what just failed to
replicate. The `ODDS` regression is comfortably clear of that bar
(CI [−0.218, −0.061], upper bound 0.061 from zero). `HOLDEVEN` is not as
comfortable (CI [+0.030, +0.189], upper bound 0.030 from zero) and deserves
the same skepticism until it is re-measured.

## Follow-up: HOLDEVEN against the champion, 160 episodes

`HOLDEVEN` had to be measured against a `HOLDLINE=1` control because it is
unreachable without it, and that control is not the champion. Two
direction-balanced pairs were then run against the champion config directly
(v39 against v29), 160 episodes, 0 skipped:

| metric | v39 (HOLDLINE+HOLDEVEN) | v29 (champion cfg) | gap | 95% CI | |
|---|---|---|---|---|---|
| K/D | 1.0422 | 0.9596 | **+0.0826** | [+0.0275, +0.1357] | **separates** |
| win rate | 55.6% | 44.4% | +0.113 | [−0.050, +0.263] | crosses zero |
| captures | 24 | 41 | **−17** | [−33, −1] | **separates** |

Unlike the shoutIntel case, this one got *stronger* under doubling — the K/D
lower bound moved from 0.0057 away from zero at n=80 to 0.0275 at n=160 — and
no direction is an outlier: v39 on RED took 72.5% and 75.0% against a 68.1%
baseline, v29 on RED took 67.5% and 57.5%. Better in every seat it held.

**But read the captures row.** The same 160 episodes say, with the same
confidence as the K/D gain, that this lever costs captures — 41 down to 24, a
41% drop. That is not a side effect to wave through:

- The game scores **wins**, not K/D, and a time-limit draw scores exactly as
  badly as a loss. Capturing less means more clock running out.
- Win rate is the metric that decides it, and it is **+11.3 points but not
  separable** (CI [−0.050, +0.263]). So the K/D gain does appear to be
  converting into wins — the bot is winning by wiping rather than by stealing
  — but that conversion is not established at n=160, and win rate is the
  noisiest of the three.

So `HOLDEVEN` is the one candidate worth taking seriously and it is not a
clean win. What is established: it trades captures for kill efficiency. What
is not established: whether that trade produces more league points. Deciding
it means measuring win rate to a much tighter interval than 160 episodes buys,
and that is a judgement call about how many episodes the answer is worth —
which is why nothing here has been submitted to the league.

## Results

Filled in as each pooled verdict lands. A gap whose 95% CI crosses zero is not
a result, however good one direction looked.

<!-- RESULTS-TABLE -->

Gaps are **(treatment − control)**, so a positive number means the lever helped. A 95% CI that crosses zero is not a result.

| experiment | vs | n | K/D gap | 95% CI | win-rate gap | captures gap | verdict |
|---|---|---|---|---|---|---|---|
| `CTF_LEVER_ARCRAID` | v29 | 80 | +0.0452 | [-0.0290,+0.1171] | +0.100 [-0.125,+0.300] | +1 [-12,+14] | level (CI crosses zero) |
| `CTF_FIX_AIMBAND` | v29 | 80 | +0.0290 | [-0.0432,+0.0999] | +0.150 [-0.050,+0.375] | +8 [-5,+21] | level (CI crosses zero) |
| `CTF_FIX_STAREBREAK` | v29 | 80 | -0.0035 | [-0.0710,+0.0631] | -0.000 [-0.225,+0.225] | -4 [-18,+10] | level (CI crosses zero) |
| `CTF_LEVER_NADEDUCK` | v29 | 80 | +0.0300 | [-0.0513,+0.1154] | -0.025 [-0.250,+0.200] | -2 [-14,+10] | level (CI crosses zero) |
| `CTF_LEVER_HOLDLINE` | v29 | 80 | +0.0092 | [-0.0679,+0.0870] | +0.050 [-0.175,+0.275] | -2 [-14,+10] | level (CI crosses zero) |
| `CTF_LEVER_HURTLOOK` | v29 | 80 | -0.0600 | [-0.1309,+0.0104] | -0.150 [-0.375,+0.075] | -3 [-16,+10] | level (CI crosses zero) |
| `CTF_LEVER_CROSSFIRE` | v34 | 80 | -0.0288 | [-0.1004,+0.0461] | +0.025 [-0.200,+0.250] | +12 [-0,+24] | level (CI crosses zero) |
| `CTF_LEVER_CARRIERSHY` | v29 | 80 | -0.0161 | [-0.0884,+0.0560] | -0.000 [-0.225,+0.225] | +4 [-10,+17] | level (CI crosses zero) |
| `CTF_LEVER_ODDS` | v29 | 80 | -0.1387 | [-0.2180,-0.0605] | -0.225 [-0.425,-0.000] | +1 [-11,+14] | **SEPARATES** |
| `CTF_LEVER_HOLDEVEN` | v34 | 80 | +0.1087 | [+0.0299,+0.1893] | +0.200 [-0.025,+0.400] | -4 [-13,+5] | **SEPARATES** |
| `CTF_LEVER_SHOUTSEEN` | v40 | 80 | -0.0415 | [-0.1197,+0.0345] | +0.025 [-0.200,+0.250] | -0 [-13,+13] | level (CI crosses zero) |
| `CTF_LEVER_SPAWNINTEL` | v41 | 80 | -0.0070 | [-0.0830,+0.0693] | -0.150 [-0.375,+0.075] | -2 [-14,+10] | level (CI crosses zero) |
| `-d:shoutIntel` | v29 | 160 | -0.0385 | [-0.0909,+0.0138] | -0.100 [-0.250,+0.050] | -3 [-21,+15] | level (CI crosses zero) |

_14 of 13 experiments pooled._ Per-experiment full pooled output, including the per-direction side split and every skipped episode, is in `results/<experiment>.txt`; the request bodies are in `xp-requests/h2h-<experiment>-{a,b}.json`.
