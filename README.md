# CTF bot — session work

Everything here was built against the Coworld CTF league. The policy images
themselves live on the Observatory; this archive is the source and the
measurement tooling, which existed nowhere else.

## Layout

- `bot/baseline.nim` — the bot. All behaviour changes are in this one file.
- `bot/baseline/` — protocol client it imports.
- `bot/Dockerfile.sandbox` — how the image is built.
- `diffs/` — unified diffs against the upstream stock bot, which is the fastest
  way to see what was actually changed rather than reading 3000 lines.
- `scripts/` — the measurement tooling. `ab_by_seat.py` and `make_h2h.py` are
  the two that matter; see below.
- `xp-requests/` — the request bodies for every arm that was run.
- `NOTES-dejitter.md` — the sound-ring jitter inversion, plus the measurement
  traps found the hard way. Read this before trusting any A/B number.

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
| v11 | + enemy-side arc taken by attackers — under test when this was packaged |

## How to measure anything here

The one hard-won rule: **only compare builds that ran at the same time, in the
same episodes, on both sides.**

    python scripts/make_h2h.py <buildA> <buildB> armName 40 > a.json
    python scripts/make_h2h.py <buildB> <buildA> armName 40 > b.json
    # create both, then:
    python scripts/ab_by_seat.py "a=<xreq_id>" "b=<xreq_id>"

Read the `RED_is` / `BLUE_is` fields in the output rather than the arm name —
the name is a label chosen at creation, `RED_is` is what actually played.

Read K/D. Win rate needs about a 12 point gap at n=40 before it means
anything, and captures turn on five to thirteen events per arm, so neither
settles a close call on its own.
