# Coworld Paintbot policy

One Nim policy for the Softmax Paintbot league, plus the tooling to build it,
measure a change, and ship it.

Since 2026-09-01 the league runs the 32-seat **BATTLE ROYALE** variant: 16
colour-fixed duos, one life, no flags, a shrink zone, and the pinned
3211x1713 `br-gen-1339` map. The same binary still supports the classic
two-team CTF arena and the two- and four-team Paintbot boards; those paths
remain bit-identical to the pre-BR tree.

A seat's league score is its duo's Glory when that duo wins and 0 otherwise.
The leaderboard takes each policy's mean score per round and keeps its maximum
over rounds. A high-Glory loss therefore banks nothing, and an old classic
round can remain the displayed best after the league changes variant.

The policy has exactly one behaviour and no run-time configuration. A variant
is a source change, built as its own image and measured against the tree it
came from.

## Layout

```text
bot/
  baseline.nim            process entry point: connect, advance the clock,
                          run the policy, send back the input mask
  baseline/               the policy itself, in layers
    royale.nim            flagless BR zone, duo, loot and hunt objectives
    brmap.nim              generated pinned-map walkability fallback
    whisky_fixed.nim       vendored websocket client with complete reads
  nimby.lock              dependency lock; follows the engine lock
  Dockerfile              upstream coworld-ctf project-layout recipe
  Dockerfile.sandbox      repository-local, proxy-aware recipe
  coplayer_manifest.json  upstream player manifest and entrypoint
sim/
  README.md               the in-process real-engine simulator
  paintbot_br.json        the hosted battle-royale config
  stock/                  the engine's stock reference bot as an opponent
  walkdump.nim            dump a pinned map's engine walkability mask
scripts/
  local_sim.py            local classic, Paintbot and BR measurements
  br_xp.py                create and pool hosted BR A/B requests
  ship.sh                 static amd64 build, smoke and upload
  br_mask_to_nim.py       turn a walkdump into baseline/brmap.nim
analysis/
  paintbot.md             classic Paintbot mechanics and measurements
  br_doctrine.md          audited BR rules, scoring and tactics
  br_rounds.py            fetch and rank hosted BR rounds
  br_port_notes.md        the BR port and regression evidence
research/
  LEDGER.md               measurements and verdicts; the repository's memory
  state.json              CTF-era autoresearch state and queue
```

`bot/baseline.nim` opens with the full policy design and a map of the modules.
Read that before reading `bot/baseline/`. The modules are layered so that
nothing below imports anything above it. `decide.nim` runs `sense.nim`, one
objective branch, `engage.nim`, `grenades.nim` and `act.nim` in order.
`royale.nim` is the flagless BR branch; `objective.nim` retains the pedestal,
lane and endzone strategy for classic boards.

Some files deliberately track upstream or generated data:

- `baseline/labels.nim` is the engine's sprite-label vocabulary copied
  verbatim. Re-sync it whenever `sim/engine.pin` moves; its header has the
  command. `labelkind.nim` is this repository's enum over that vocabulary.
- `baseline/protocols.nim` is the headless half of the engine's sprite client,
  with the input-mask tripwire and the socket-free delivery seam used by the
  simulator.
- `baseline/whisky_fixed.nim` is vendored from whisky because the stock client
  assumed one socket read returned a whole requested field. The local copy
  reads headers and payloads to completion, validates the full RFC 6455
  length, and terminates fragmented messages on the continuation frame's FIN.
- `baseline/brmap.nim` is generated data, not policy code. It embeds the
  pinned BR map's engine `walkMask`, with a checked row-major FNV-1a, for the
  case where the hosted wire does not deliver the walkability sprite.

Regenerate `brmap.nim` after moving the engine pin:

```bash
mkdir -p .sim-build
(cd .engine && nim c -d:release \
  --out:../.sim-build/walkdump ../sim/walkdump.nim)
.sim-build/walkdump --engine .engine --config sim/paintbot_br.json \
  --out /tmp/br-mask.txt
scripts/br_mask_to_nim.py /tmp/br-mask.txt bot/baseline/brmap.nim
```

## Building and deploying

### `nimby.lock` is not optional

Its first line currently follows the dependency lock used by the pinned
engine:

```text
bitworld 0.1.0 https://github.com/Metta-AI/bitworld 9af28b41ba2c92081d49cb27f2421492b85ead8d
```

That bitworld commit is a descendant of the 8-bit input-mask pin. The broken
lineage ANDed the input byte with `0x7f`, deleting **ButtonC** (bit 128, the
grenade charge/throw) while leaving a structurally valid packet: no error, no
log line, just a bot that never throws.

Two guards keep that failure loud:

- `bot/baseline/act.nim` imports `ButtonC` from the engine instead of defining
  it locally.
- `bot/baseline/protocols.nim` has a compile-time assertion that round-trips
  `0x80` through the engine's mask encoder.

Do not update `bot/nimby.lock` independently. Move `sim/engine.pin`, follow the
engine's dependency lock, re-sync `labels.nim` and `brmap.nim`, and let the
ButtonC tripwire prove the resulting build still carries all 8 bits.

The local simulator does not use `bot/nimby.lock`: it links engine and policy
into one binary, so it must use the engine's bitworld. The same ButtonC static
assertion still runs there.

### Ship the linux/amd64 policy

The supported release path is:

```bash
scripts/ship.sh <bot-dir> <name> --tag purpose=<why>
# prints <name>:vN
coworld submit <ref> -l league_b8fa9b35-ac22-48cf-a03f-07b397aff1c7 \
  --auto-champion always
```

`<bot-dir>` is the full `bot/` context, containing `baseline.nim` and
`baseline/`. `ship.sh` builds a static linux/amd64 binary with the pinned
dependencies via nix, Nim and zig; smokes that binary under amd64 Docker; puts
it in a minimal image; and uploads it through `coworld upload-policy`. It
prints the server-assigned policy ref. Uploading and submitting are separate,
deliberate steps.

`scripts/upload_amd64_policy.py` is retired. It wrote docker-save archives,
but coworld 0.1.44 uploads OCI-layout archives. `ship.sh` uses the official CLI
path that v122 was shipped through.

The two Dockerfiles remain useful for development. `Dockerfile.sandbox` builds
from this repository's `bot/` directory through the sandbox CONNECT proxy;
`Dockerfile` expects the upstream coworld-ctf project layout. Keep the
`Dockerfile.sandbox` output-name guard: because `baseline/` is already a
directory, a relative `--out:baseline` can silently produce `baseline.out`.

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

### Battle-royale harness

Set up the pinned engine and prove the local wiring once, then use the BR front
door:

```bash
sim/bootstrap.sh
scripts/local_sim.py selfcheck
```

```bash
scripts/local_sim.py br <treeA> <treeB> [<treeC> <treeD>] \
  -n N --first-seed S --workers W
```

A tree can be a git ref or a policy directory. Every episode contains every
build. The harness rotates builds through the 16 colours over the seed block,
requires a complete rotation, records Glory and placement as well as combat
and survival diagnostics, and reports treatment-minus-control gaps with
paired seed-bootstrap intervals. This is the BR form of rule 2: colour takes
the place of red/blue side.

The in-process simulator has no league drift, so rule 1 is retired locally.
Rules 2 through 7 still hold; the shared seed and colour rotation make rule 2
stricter, not weaker.

The standing local opponent is the engine's stock reference policy:

```bash
scripts/local_sim.py br HEAD sim/stock -n N \
  --first-seed S --workers W
```

Use the previous tree as the control to isolate a code change, then run the
same candidate against `sim/stock` so a locally improving lineage does not
become detached from the standing reference. `sim/stock/sync.sh` re-syncs that
copy when the engine pin moves.

The simulator is the real engine in process, but there are two wire traps:

- Every simulated policy seat must be a sprites-off viewer. The engine emits
  the walkability mask only on that stream at the pinned GameVersion;
  `sim/simulate.nim` now seats every policy with `spritesOff = true`.
- A successful in-process result proves nothing about the hosted websocket.
  Prove transport with the real engine server (build it with
  `cd .engine && nim c ... src/ctf.nim`) and native policy binaries connected
  over websockets. That path exposed the giant-frame receive bug that the
  in-process simulator necessarily bypassed.

There is a separate server gate: a deployed engine without upstream
`3de6e794` discards every policy's inputs on this board. Until the deployed
engine contains that fix, hosted episodes can prove connection and map
delivery but cannot distinguish policy behaviour.

### Hosted battle-royale A/B

Once the deployed engine plays policy inputs, create a colour-rotated hosted
block with named opponents:

```bash
scripts/br_xp.py create <ref> --opps A B C -n N --rotate
# collect the xreq ids printed above
scripts/br_xp.py pool <xreq> [<xreq> ...]
```

Each request has a 32-seat roster. Each of the four policy refs owns one slot
group, hence four enemy-colour duos; `--rotate` creates one request with the
candidate in each group so the fixed spawn deal cancels over the block. The
request targets this league with `variant_id: battle-royale`. The hosted price
recorded on 2026-09-01 is 0.5 credits per episode. `pool` re-keys seats to the
policy that actually held them, reports the league score and diagnostics, and
bootstraps the focus policy over episodes rather than treating the seats inside
an episode as independent.

Never let a policy face another version of itself. Keep the opponent set,
episode count and notes comparable between candidate and previous best.

For the live field rather than one A/B:

```bash
python3 analysis/br_rounds.py fetch
python3 analysis/br_rounds.py report
```

`fetch` stores completed hosted round data under `research/br_rounds/` and
skips records already present. `report` is offline and ranks the stored field
on the actual banked league score, with kills, deaths and survival as
diagnostics.

The classic harnesses still exist for the boards the policy still supports:
`local_sim.py h2h` for a two-side mirror, `local_sim.py paint` for a four-colour
rotation, and the older `run_experiment.py` / `pool_h2h.py` hosted path. See
`sim/README.md` for their exact shapes and the simulator's remaining gaps.

## The auto-research loop

`scripts/autoresearch.py` and `scripts/experiments.py` are the CTF-era knob
loop. They still exist and still encode the old both-directions build, hosted
measurement, confirmation and promotion workflow, but they are not the BR
driver.

BR iteration currently runs as measured code changes:

1. Change one variable and verify the mechanism locally.
2. Run a colour-rotated local BR A/B against the previous tree.
3. Run the same candidate against `sim/stock`.
4. Once the deployed engine accepts policy inputs, run a hosted rotated A/B
   with `br_xp.py` before promoting the verdict.

One change lands per generation. A local result is not a hosted result, and a
95% interval that crosses zero is level. Record the commands, tree refs,
episode records, request ids and verdict in `research/LEDGER.md`; it remains
the loop's memory. A result nobody wrote down gets run again.

## A note on the prose here

The mechanisms described in this file and in the source comments were read out
of the engine and the server source, and are reliable. Claims about what will
*help* are not, unless a both-directions head-to-head is cited next to them.
Trust the code and the measurements over the narrative, including this file.
