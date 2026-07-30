# Coworld CTF policy

One capture-the-flag policy for the Coworld CTF league, plus the tooling to
build it into an image, upload it, and find out whether a change to it is
actually an improvement.

There is nothing else here: no experiment scaffolding, no run logs, no result
archive. The policy has exactly one behaviour and no run-time configuration. A
variant is a source change, built as its own image and measured against the one
it came from.

## Layout

```
bot/
  baseline.nim            entry point: connect, advance the clock, hand each
                          frame to the policy, send back the input mask
  baseline/               the policy itself, in layers
  nimby.lock              dependency + ENGINE pin (load bearing, see below)
  Dockerfile              upstream recipe, coworld-ctf project layout
  Dockerfile.sandbox      recipe that builds from bot/ behind an egress proxy
  coplayer_manifest.json  upstream player manifest: name, entrypoint, games,
                          and a placeholder image URI to fill in on publish
scripts/                  measurement tooling (see "Evaluating a change")
```

`bot/baseline.nim` opens with a full description of the design — the protocol,
the fog model, the world model, the roles, the turret controller — and a map of
which module owns which part. Read that before reading any of `bot/baseline/`.

The policy modules are layered so that nothing below may import anything above
it. Bottom to top: `tuning.nim` (every tuned constant, and the map size adopted
off the wire), `geometry.nim`, `world.nim` (teams, roles, the arena landmarks,
and `Bot` — everything that survives from one frame to the next; the
per-frame context is `frame.nim`, which is deliberately memoryless),
`perception.nim` (reading the wire), `memory.nim` (tracks and
pickups), `grid.nim` / `posts.nim` / `navgrid.nim` (walkability, cover posts,
the cost field), `tactics.nim` (shared judgement calls), then the five stages of
one decision — `sense.nim`, `objective.nim`, `engage.nim`, `grenades.nim`,
`act.nim` — which share the `frame.nim` context and are run in order by
`decide.nim`.

Two modules are vendored rather than written here:

- `bot/baseline/protocols.nim` — the websocket sprite-protocol client, trimmed
  to the headless half (the bot never renders, so the framebuffer, palette
  blitting and 4bpp pack/unpack are gone). The walkability decode and the
  compile-time engine tripwire stay.
- `bot/baseline/labels.nim` — the sprite-label vocabulary, copied verbatim from
  the engine so that a rename upstream becomes a compile error here instead of a
  scan that silently finds nothing. Re-sync it before every tournament build;
  its own header says how.

## Building

### `nimby.lock` is not optional

Its first line pins the engine itself:

```
bitworld 0.1.0 https://github.com/Metta-AI/bitworld 5d229acd1a5eb311bee831b35dd60e9fc0091cac
```

That commit is on branch `daveey/hd-client-pin` and is **not on bitworld
master**. It is the only lineage whose input mask carries all 8 bits. Master
ANDs the input byte with `0x7f`, which deletes **ButtonC (bit 128, the grenade
charge/throw)** from every packet while leaving the packet structurally valid —
no error, no log line, just a bot that presses the throw button all match and
never throws. That is worth roughly 0.4 K/D, and it is invisible unless you
audit the wire.

Two guards make that failure loud instead of silent, and both must stay:

- `bot/baseline/act.nim` imports `ButtonC` from the engine instead of defining
  it locally. A local `ButtonC = 1'u8 shl 7` compiles cleanly against the wrong
  engine, which is exactly what made the truncation invisible.
- `bot/baseline/protocols.nim` carries a `static:` assert that round-trips
  `0x80` through the engine's mask encoder and fails the build if the bit does
  not survive.

So: sync `nimby.lock`, never clone bitworld master.

### The two recipes

`bot/Dockerfile.sandbox` builds from this repository's `bot/` directory and is
the one to use inside a Claude Code sandbox, where all egress goes through a
local CONNECT proxy with its own CA:

```bash
cd bot
cp /root/.ccr/ca-bundle.crt ccr-agent-proxy.crt     # the CA changes every session
docker build --network=host \
  --build-arg PROXY="$HTTPS_PROXY" \
  -f Dockerfile.sandbox -t candidate .
```

`--network=host` is required so the build can reach the proxy on `127.0.0.1`.
The build stage is `gcc:12-bookworm` rather than `debian:bookworm-slim` + apt,
because apt cannot reach the Debian mirrors through a CONNECT-only proxy (405)
and the gcc image already carries what the compile needs. The run stage is
still `debian:bookworm-slim` and installs nothing — the binary links nothing
outside libc.

`bot/Dockerfile` is the upstream recipe and expects the **coworld-ctf project
layout** as its build context (`players/baseline/baseline.nim`), not this
repository's `bot/`. Use it by laying these files into a coworld-ctf checkout.

Note the output-name trap recorded in `Dockerfile.sandbox`: this layout has a
*directory* named `baseline/` in the build context, so `--out:baseline` does not
overwrite it — Nim silently retargets the link to `baseline.out`, exits 0, and
the run stage then copies the source directory into `/bin/baseline`. The image
builds cleanly, contains no binary, and fails only when something runs it. Hence
`--out:/workspace/ctf/bot.bin`. Same shape as the ButtonC truncation:
valid-looking, silent, wrong.

`dockerd` is not running at session start and dies with the container. Start it
before building.

## Deploying

Upload the built image; the CLI prints the policy ref (`<name>:<version>`) that
every request below refers to:

```bash
coworld upload-policy candidate -n <policy-name> --tag purpose=<why>
```

The server assigns the next sequential version on upload regardless of what you
called the image locally, so a local Docker tag and a server version are not the
same thing. Record the ref the upload prints — that string, not your tag, is
what identifies the build from here on.

Uploading does not enter a policy in the league. That is a separate submission
step, and `--auto-champion always` makes the submission take the champion slot
when it qualifies. Run `coworld --help` for the current form; the CLI is not
vendored here, so this file does not pin its flags.

Four scripts shell out to the CLI. `run_experiment.py`, `pool_h2h.py` and
`ab_by_seat.py` take `$COWORLD_BIN` if it is set and otherwise fall back to
`coworld` on `PATH`; `local_h2h.sh` always wants it on `PATH`. (`pool_h2h.py`
and `ab_by_seat.py` will also use `uv run coworld` inside a coworld player
project if `$COWORLD_PROJECT` points at one.) The remaining scripts either
emit JSON or read files off disk and need no CLI at all.

## Evaluating a change

### The rules that decide whether a number means anything

These are the expensive part. The tooling exists to enforce them.

1. **Only compare builds that ran at the same time.** The league drifts. The
   same policy against the same version-pinned field moved K/D 0.823 to 0.852
   in a few hours — about thirty times the concurrent reproducibility. A
   candidate-today-versus-baseline-yesterday comparison is noise wearing a
   number.
2. **Head-to-head, both directions, always.** Put both builds in the same
   episodes, one per side, then swap and repeat. Everything that drifts drifts
   for both and cancels. The side is worth a lot: in a measured 79-episode
   mirror, **RED won 70.9% of episodes whatever build held it**. A
   one-direction result has that baked in and will read as a ~20 point build
   effect that does not exist.
3. **Read the seats out of the episode, never out of the arm name.** The name
   is a label chosen at creation time, and reading it once had a 33-7 arm
   scored backwards. `ab_by_seat.py` reports `RED_is` / `BLUE_is` read from the
   episode participants — trust those fields over the name. `pool_h2h.py` goes
   further and reports everything keyed to the build that actually held each
   seat, so the name cannot enter the verdict at all.
4. **Read K/D, but never K/D alone.** Two identical binaries scored 17.5% and
   30.0% win rate over 40 episodes each, so win rate needs roughly a twelve
   point gap at n=40 to mean anything — but the league scores wins, and a
   change can be level on K/D and a decisive regression on wins and captures.
   Captures turn on five to thirteen events per arm; never settle a close call
   on them.
5. **n=80 is not enough for a marginal call.** A "regression" whose CI barely
   excluded zero at 80 episodes has come back level at 160. If the interval
   nearly touches zero, buy more episodes or call it level.
6. **If the 95% CI crosses zero, there is no result** — no matter how good one
   direction looked.
7. **Failed episodes are excluded, not retried.** A request can legitimately
   pool 39 of 40. `pool_h2h.py` prints every skipped episode with its error so
   the sample loss is visible rather than silent.

### Verify the mechanism before buying episodes

An A/B is expensive and answers only "is it better". Confirm the change does
what you think it does first, on a local run, with logging in the hot path. A
local `coworld run-episode` puts your policy in all 16 slots on both teams: good
for mechanism, useless for strength.

```bash
coworld download ctf -o cwpkg          # once; the manifest local runs need
scripts/local_h2h.sh <imageA> <imageB> <episodes> <outdir>
python scripts/pool_local.py <outdir> <buildA> <buildB>
```

`local_h2h.sh` runs image A on the eight red slots against B on the eight blue
slots, then swaps them, writing the two directions to `<outdir>/dir1` and
`<outdir>/dir2`; `pool_local.py` pools those with the same discipline as the
hosted analyzer. Local samples are small, so read the interval, not the point
estimate — a local run cannot measure strength at hosted-league sample sizes
and is not meant to.

### The hosted head-to-head

This is what actually settles a change. One command creates both directions
back to back — so they are in flight at the same moment — and blocks until both
finish:

```bash
python scripts/run_experiment.py <name> <treatment_ref> <control_ref> 40
# -> XREQ_A=xreq_...
#    XREQ_B=xreq_...
```

The generated request bodies land in `arms/`, which is gitignored — a request
body is a record of a run, not source. (`$CTF_ARMS_DIR` moves them; anywhere
else is yours to keep out of git.) Then pool the two directions into one
verdict:

```bash
python scripts/pool_h2h.py <xreq_a> <xreq_b>
```

`pool_h2h.py` re-keys every seat to the build that actually held it, sums across
both directions so the side cancels, and bootstraps the remaining gap over
**episodes** — the eight seats inside one game are not independent, and treating
them as independent is what makes a standard error look reassuringly tiny when
it is not.

To read one direction on its own, per seat:

```bash
python scripts/ab_by_seat.py "a=<xreq_a>" "b=<xreq_b>"
```

That is the right unit for inspecting a single arm and **cannot settle a
head-to-head** — see rule 2.

### Against the standing field

To measure a policy against the league rather than against another of your
builds, name the opponents explicitly — read the division's current standings
off the Observatory, since any list written down here goes stale the moment
somebody uploads:

```bash
python scripts/make_xp_request.py <policy_ref> <arm-name> 40 <opp> <opp> ... > arm.json
coworld xp-request create arm.json --json
```

Never use the request format's `top_n` opponent pool once your own policy is in
the league: the pool can seat your policy opposite itself, and a mirror is not a
measurement — the score is reported per policy *version*, so with the same
version on both sides there is no way to say which side it belongs to. The
script refuses a field containing your own policy name.

`scripts/make_h2h.py` emits a head-to-head body the same way, for when you want
to create and manage the two directions by hand instead of through
`run_experiment.py`.

## A note on the prose here

The mechanisms described in this file and in the source comments were read out
of the engine and the server source, and are reliable. Claims about what will
*help* are not, unless a both-directions head-to-head is cited next to them.
Trust the code and the measurements over the narrative, including this file.
