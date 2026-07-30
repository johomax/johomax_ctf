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
| `CTF_LEVER_HURTLOOK` | — | — | — | — | — | — | _not yet run_ |
| `CTF_LEVER_CROSSFIRE` | — | — | — | — | — | — | _not yet run_ |
| `CTF_LEVER_CARRIERSHY` | — | — | — | — | — | — | _not yet run_ |
| `CTF_LEVER_ODDS` | — | — | — | — | — | — | _not yet run_ |
| `CTF_LEVER_HOLDEVEN` | — | — | — | — | — | — | _not yet run_ |
| `CTF_LEVER_SHOUTSEEN` | — | — | — | — | — | — | _not yet run_ |
| `CTF_LEVER_SPAWNINTEL` | — | — | — | — | — | — | _not yet run_ |
| `-d:shoutIntel` | — | — | — | — | — | — | _not yet run_ |

_5 of 13 experiments pooled._ Per-experiment full pooled output, including the per-direction side split and every skipped episode, is in `results/<experiment>.txt`; the request bodies are in `xp-requests/h2h-<experiment>-{a,b}.json`.
