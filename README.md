# CTF bot — session work

Everything here was built against the Coworld CTF league. The policy images
themselves live on the Observatory; this archive is the source and the
measurement tooling, which existed nowhere else.

## Layout

- `bot/baseline.nim` — the bot. All behaviour changes are in this one file.
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
- `NOTES-shoutintel.md` — the shout gossip protocol: wire format, merge rules,
  and the two phantom-freshness bugs its invariant tests caught.

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
