# CTF bot — session work

Everything here was built against the Coworld CTF league. The policy images
themselves live on the Observatory; this archive is the source and the
measurement tooling, which existed nowhere else.

## Layout

- `bot/baseline.nim` — the bot. All behaviour changes are in this one file.
- `bot/nimby.lock` — the dependency lock, RESTORED after being lost with the
  original project (it is `Metta-AI/coworld-ctf`'s own lock). Its first line
  pins the `bitworld` engine to a commit that is NOT on master; building
  without it silently deletes the grenade throw and costs ~0.4 K/D. Load
  bearing. See `NOTES-provenance.md`.
- `bot/baseline/` — protocol client it imports, plus `shoutintel.nim`, the
  teammate gossip protocol (`-d:shoutIntel`; see `NOTES-shoutintel.md`) and its
  test suite, which runs without a server:

      nim r bot/baseline/shoutintel_test.nim
- `bot/Dockerfile.sandbox` — how the image is built.
- `diffs/` — unified diffs against the upstream stock bot, which is the fastest
  way to see what was actually changed rather than reading 3000 lines.
- `scripts/` — the measurement tooling. `ab_by_seat.py` and `make_h2h.py` are
  the two that matter; see below.
- `xp-requests/` — the request bodies for every arm that was run.
- `NOTES-dejitter.md` — the sound-ring jitter inversion, plus the measurement
  traps found the hard way. Read this before trusting any A/B number.
- `NOTES-provenance.md` — why every v12–v27 rebuild measured ~0.4 K/D below
  v9 (a lost engine pin amputated the grenade throw), the wire-level proof,
  and the guards that now make the wrong engine fail the build.
  `scripts/buttonc_probe.nim` is the replay audit used for the proof.
- `NOTES-shoutintel.md` — the shout gossip protocol: wire format, merge rules,
  and the two phantom-freshness bugs its invariant tests caught.
- `NOTES-holdline.md` — the one change measured as an improvement.

## Server version map

Local Docker tags and Observatory versions drifted apart, because the server
assigns the next sequential version on upload regardless of local tag.

| server tag | contents |
|---|---|
| v2 | five correctness fixes over the stock bot |
| v7 | + identity badges, sonar, jitter inversion, feasible pre-aim, memory, back-guard |
| v8 | + carrier free-aim, stand-off peek (measured level with v7) |
| **v9** | **+ grenade memory, friendly-fire guard, grenade farming — CHAMPION** |
| v10 | + plasma arc farmed by the keeper — REGRESSION, do not ship |
| v11 | + enemy-side arc taken by attackers — measured LEVEL with v9, not shipped |
| v12 | control arm for the Shout-Intel A/B (champion config, `CTF_LEVER_ARCRAID=0`) |
| v13 | v12 + `-d:shoutIntel` — REGRESSION, −0.083 K/D, do not ship |
| v14 | v13 + heard sightings feeding grenade targeting — still behind v12, captures 15 vs 29 |
| v15 | v12 + range-derived aim deadband (`CTF_FIX_AIMBAND`) — +0.072 K/D, NOT established (p~0.07) |
| v16 | control for the quiet-shout A/B (v15-equivalent, same commit as v17) |
| v17 | v16 + quiet `-d:shoutIntel` — REGRESSION, −0.162 K/D, p<0.001, both directions agree |
| v18/v19 | same binary, `CTF_LEVER_NADEDUCK` on/off — disengage-and-lob is a REGRESSION, −0.124 K/D, p~0.007 |
| v20/v21 | shout-only-when-seen vs no shouting — REGRESSION, −0.139 K/D and −28.7 pts win rate, p~0.0005 |
| v22/v23 | Shout-Intel with spawn-intel DISABLED — still a REGRESSION, −0.121 K/D; refutes the staleness theory |
| **v24** | **v23 + `CTF_LEVER_HOLDLINE` — +0.125 K/D vs a HEAD control, but see v27** |
| v25 | v24 stack + look-around vs REAL v9 — −0.355 K/D, 12.5% win rate |
| v26 | v25 minus look-around, plus stare-break/cross-fire/carrier-shy vs v9 — −0.309 |
| v27 | plain archive HEAD, ALL new levers off, vs v9 — **−0.401**: the gap is the archive, not the changes |
| **v28** | **v27's source rebuilt through the restored `nimby.lock` (bitworld `5d229ac`), same config — pooled LEVEL with v9: +0.021 K/D, 95% CI [−0.056, +0.098]. The gap was the engine pin; see `NOTES-provenance.md`** |

**Caveat on v12–v27:** all of them were built without `nimby.lock`, against
bitworld master, which strips the grenade-throw bit from every input packet —
so every one of these builds was GRENADE-BLIND and every v12+ number above was
measured in a gun-only meta (`NOTES-provenance.md` has the proof). The
comparisons are internally valid (both arms equally blind) but do not
transfer to a correctly built bot. v2–v11 were built through the lock and are
unaffected. The lock is restored at `bot/nimby.lock`; the source now fails to
compile against the wrong engine.

## How to measure anything here

The one hard-won rule: **only compare builds that ran at the same time, in the
same episodes, on both sides.**

    python scripts/make_h2h.py <buildA> <buildB> armName 40 > a.json
    python scripts/make_h2h.py <buildB> <buildA> armName 40 > b.json
    # create both, then read each direction:
    python scripts/ab_by_seat.py "a=<xreq_id>" "b=<xreq_id>"
    # ...and pool them into one verdict, which is what actually decides it:
    python scripts/pool_h2h.py <xreq_id_a> <xreq_id_b>

Read the `RED_is` / `BLUE_is` fields in the output rather than the arm name —
the name is a label chosen at creation, `RED_is` is what actually played.

**`ab_by_seat.py` alone cannot settle a head-to-head.** It reports one request
relative to RED, and RED is not a neutral seat: in the v11/v9 mirror, whoever
held RED won 70.9% of episodes. Read it per direction, then run `pool_h2h.py`,
which re-keys every seat to the build that held it, sums across both directions
so the side cancels, and bootstraps the remaining gap over episodes. If the 95%
CI crosses zero, there is no result — no matter how good one direction looked.

Read K/D. Win rate needs about a 12 point gap at n=40 before it means
anything, and captures turn on five to thirteen events per arm, so neither
settles a close call on its own.

Failed episodes are excluded, not retried — a request can legitimately pool 39
of 40. `pool_h2h.py` prints every skipped episode with its error so the sample
loss is visible rather than silent.
