# Season 2 play-seat orchestrator

Date: 2026-09-01. Policy worktree: `johomax_ctf` at `3d3a999` plus the
uncommitted changes described here. Pinned league engine: `9d26cc26`; the
provided upstream-main checkout is `27e9cac1`.

## What was built

`bot/baseline.nim` is still one process and one static executable. It now
waits for the first binary WebSocket message before sending anything
mode-specific:

- a version-1 `0xB0` PlayContext or `0xB2` lobby broadcast selects the Season
  2 play-seat path;
- any other first binary message selects the existing Sprite v1 path, which
  sends `0x87` only after that decision;
- the play-seat path never calls the Sprite ready or input-mask encoders, so it
  cannot send `0x87` or `0x84`.

The new `bot/baseline/shell_wire.nim` owns only the shell byte layouts. The new
`bot/baseline/shell_seat.nim` owns recovery, uploads, status acknowledgement,
the standing call, and the small 4 Hz strategy. It does the following:

1. Reads the `0xB0` recovery floors/generation and play context, and deduplicates
   replayed `0xB2` lobby messages and durable status ordinals.
2. Uploads one embedded module at a time with increasing per-seat IDs. It waits
   for a terminal `module_ready` or `module_rejected`; a ready result must match
   both the manifest name and server SHA-256, while a rejection makes only that
   module unavailable and advances the upload sequence.
3. Acknowledges exactly the highest consumed durable status. On reconnect it
   resends an outstanding operation only when its ID is above the corresponding
   admission floor.
4. Builds the survival ladder from the ready subset in priority order:
   `target_law`, guarded `supply_run`, guarded `bodyguard`, then `edge_ride`.
   It sends immediately when all uploads have terminal outcomes, or at the
   tick-552 deadline with the best subset then ready. A view can replace it
   with crossfire or jackal only when that controller is ready and the strategy
   changes; zone urgency, low HP, partner death, a completed kill, or loss of
   the visible fight restores survival.
5. Logs the selected mode, every status, every verified module, every sent and
   accepted call, every phase change, and lobby replay.

The survival call contains `target_law`, guarded `supply_run`, guarded
`bodyguard`, and `edge_ride`. The temporary calls contain `target_law` plus
`crossfire` or `jackal`.

The three `reflex_clear_*` names shown in `analysis/s2_shell.md` cannot legally
appear in a call on either engine revision tested. The production call
validator returned:

```text
accepted=false reason=playUnknown path=call.plays[0].play
detail=call.plays[0].play is not bound
```

This is a documentation/runtime mismatch, not a missing upload: uploaded
manifests beginning `reflex_` are forbidden, and the episode applies grenade,
spray, and zone reflexes as native observers outside the guest ladder
(`src/shell/manifest.nim`, `src/shell/episode.nim`). Omitting those three
impossible entries preserves the intended behavior. With that correction, the
engine validator accepted all three exact calls:

```text
survival accepted=true
crossfire accepted=true
jackal accepted=true
```

## Hardening after the live rejection test

The first live upload exposed a client lifecycle bug rather than a module bug:
the stale server emitted `module_rejected reason=manifestProbe`, and the client
raised that ordinary durable result into the outer reconnect loop. A freshly
built server accepted the same bytes. Rejections now remain inside the seat
state machine:

- `module_rejected` logs the upload ID, module name, and reason, marks only that
  module unavailable, acknowledges the status, and starts the next upload. It
  never tears down the socket.
- `call_rejected` logs proposal ID, reason, path, and detail. Current engines
  encode `reason:path` in the reason field, so the client splits that form while
  also accepting future separate `path` and `detail` fields. It retries exactly
  once with the smallest call, `edge_ride` alone, when that module is ready. A
  rejection of the retry is logged and does not loop.
- Decode/schema `ValueError`s are logged as protocol errors without leaving the
  connection. The outer Season 2 reconnect path is reserved for failures that
  escape WebSocket receive/send, and the existing `0xB0` admission-floor resend
  rules are unchanged.
- View decoding is separately fail-closed: JSON syntax/shape, unknown encoding,
  binary header, binary section, and unexpected internal failures are each
  logged once, then that observation is ignored. No view failure raises out of
  `handleView`; the current ladder remains installed.
- The initial call is constructed only from verified ready modules. The final
  terminal upload status and call decision are processed in the same `0xB1`, so
  the terminal-to-call bound is **N = 0 ticks**. If compilation is still pending,
  tick 552 is the last normal six-tick view boundary used to send the currently
  available subset before the required tick-560 limit. The ladder schema has
  `minItems: 1`, so if zero modules are ready there is no valid call to send;
  that case is logged explicitly and the engine's native default remains active.

The proposed six-upload burst was measured against the production ingress.
The exact packets are 123,079 classified bytes across six messages, safely
below the per-seat/tick classification limits of 524,288 bytes and 64 messages.
However, the independent `MaxUploadsPerSeatPerTick = 1` admission quota makes
the burst unsafe: the focused ingress check queued/admitted one upload and
dropped five. The client therefore keeps terminal-paced uploads; the previous
32-seat episode result reached all six ready at tick 416, inside the new
deadline.

Synthetic state checks cover the requested transitions:

```text
module_accepted -> module_rejected -> next upload index
three module_ready + three module_rejected -> three-entry survival call
call_rejected -> one-entry edge_ride retry -> rejected retry stops
pending upload at tick 551 -> no call; tick 552 -> ready-subset call
shell_seat synthetic state checks passed
```

The release native build completed with the requested command. The focused
engine-ingress check printed:

```text
burst classified_bytes=123079 messages=6 queued=1 dropped=5 admitted=1
```

The existing `/tmp/engine-main-v40/tools/johomax_s2_episode_harness.nim` was
also retried. Its source still passes Nim semantic analysis, but this sandbox
currently has only the Wasmtime 40 runtime library output and no `wasmtime.h`;
the Nix daemon socket is denied. The rebuild therefore stops at
`wasmtime_shim.h:6:10: fatal error: 'wasmtime.h' file not found`. The earlier
successful 32-seat production-path result below remains the applicable module
and call validation evidence; this hardening changes only the socket client
state machine and call construction.

## Guard-free ladder

> Status 2026-09-01: designed and built (E4/E5, patches in `research/s2_patches/`), NOT merged: both self-mirror gates failed because plays never see the duo partner (server.nim:3536-3541 drops same-team players from visibleTracks), so bodyguard/crossfire hold and the duo keeps shooting itself at spawn. See LEDGER.

The deployed engine supplies `noGuardContext()` both when accepting a call and
on every ladder tick (`episode.nim:437-444,626-628,982-990`). Every numeric
guard path therefore resolves to zero: the old HP guard was always true, the
partner-distance guard was always false, and the first controller entry
shadowed every controller below it. Calls now contain no `when` fields. The
4 Hz strategist replaces the ordered ladder instead; an accepted call replaces
the seat's entry list and advances its epoch immediately
(`ladder.nim:297-365`).

Every call carries the `target_law` overlay with `prefer:
["weakened","isolated"]` and the semantic equivalent of
`never:["duo:<own team>"]`; survival calls retain the existing `holdTrigger`.
E3 proved that the deployed validator rejects every literal team spelling
(`duo:red`, and so on) as `unknownReference` because its duo lookup is not
configured at call validation. The client therefore expands its own duo to
the two accepted direct references, `never:["seat:<lower>","seat:<upper>"]`.
This preserves the requested overlay without rejecting the whole ladder. A
future negotiated `pact` can use the second overlay slot. The controller order
is:

| Situation | Controller order |
|---|---|
| survival | `edge_ride`, `bodyguard`, `supply_run` |
| zone urgent | `edge_ride`, `bodyguard`, `supply_run` |
| low HP (`hp_frac < 0.67` or `hp <= 1`) | `supply_run`, `edge_ride`, `bodyguard` |
| fresh live partner farther than 220 px | `bodyguard`, `edge_ride`, `supply_run` |
| favourable fight | `crossfire` or `jackal` as before |

Zone urgency wins over every other situation and means outside the current
rectangle, inside the seat's desired margin band, or at most 120 ticks before
shrink. Low HP is next. A partner track must be fresh and explicitly live to
trigger the distance rule. A partner closer than 40 px suppresses fight entry
and restores survival; so does a partner lying within a conservative 16 px
half-width of the segment to any visible target. Fight entry otherwise keeps
the existing weak-enemy and recent-kill classifiers. Partner death, an own-team
kill after phase entry, loss of the enemy track, or loss of safe partner
geometry restores a non-fight order.

A change must be present in two consecutive valid views before a proposal is
sent. Candidate changes, clearances, unchanged-order applications, calls, and
acceptances are each logged once. If two semantic states produce identical
JSON (currently calm survival and zone urgency), the client records the state
change without replacing an already-correct standing order. Ordinary
rejections still stay on the socket and get exactly the existing one-entry
`edge_ride` fallback attempt.

The duo has a deterministic margin asymmetry. Seats 0-15 use base margin `M`;
their partners in seats 16-31 use `M + PartnerMarginOffset`, where the offset
is the single sweepable constant 80 px. E2 cannot choose a new margin or
`coverBias`: all of those batches ran with `supply_run` shadowing `edge_ride`,
so their controller parameters were inert. E4 therefore keeps
`coverBias=1.0`, measures `M=220` as the base, and carries `M=120` only as a
separate arm. There is no evidence-backed tighter zone-urgent variant yet.

## Binary view

The live origin/main server does not follow `binary_view.nim`'s stale opening
comment that the socket copy remains JSON. During play,
`episode.firstLightViewBytes` returns `buildBinaryPlayView(source)` and the
server places those bytes directly in the `0xB1` view field
(`src/shell/episode.nim:205-230`, `src/ctf/server.nim:1677-1690` at
`27e9cac1`). `outbound.nim` determines the initial/status-dirty/six-tick send
cadence but does not choose an encoding (`src/shell/outbound.nim:228-240`).
Lobby/control-only views can still be empty or JSON. The client now selects
JSON only when the payload starts with `{`, and the fixed binary decoder when
it starts with `PV1`.

The decoded frame layout follows the upstream encoder exactly. All integers
are little-endian. The 32-byte header is:

| Offset | Field |
|---:|---|
| 0 | four-byte magic `PV1\0` |
| 4 | `u16` frame version, exactly 1 |
| 6 | `u8` mode (`0` CTF, `1` KOTH, `2` BR) |
| 7 | `u8` section count |
| 8 | `u32` tick |
| 12 | reserved `u32`, zero |
| 16 | `u64` epoch |
| 24 | `u32` total frame bytes, exactly the payload length |
| 28 | reserved `u32`, zero |

It is followed by `section_count` 12-byte directory entries: `u16 kind`,
`u16 record_count`, `u16 record_stride`, reserved zero `u16`, and `u32`
payload offset. The decoder bounds-checks the complete table, alignment,
monotonic offsets, multiplication, duplicate relevant sections, exact known
strides, row caps, identities, flags, and the required one-row self/world
sections before reading a record. These constants and frame writes are in
`src/shell/binary_view.nim:28-87,400-436`.

The strategist consumes these sections:

| Kind | Stride | Decoded record fields |
|---:|---:|---|
| 1 self | 32 | flags, `i32 x/y`, `i32 hp`, `f64 hp_frac`, aim, optional lives |
| 2 world | 272 | reserved, `u32 alive_teams`, objective count, 16 fixed objective slots |
| 3 zone | 48 | next/DPS flags, phase, ticks-to-shrink, DPS, current and next `i32 x/y/w/h` |
| 4 tracks | 32 | aim/HP/bounty flags, seat, team ID, `i32 x/y`, fresh tick, optional aim/HP |
| 6 kill feed | 12 | tick, killer team ID, victim seat |

The exact record writes are `src/shell/binary_view.nim:197-274`; section
selection and caps are `src/shell/binary_view.nim:438-488`. Team IDs are the
locked ordinal order red, blue, green, yellow, black, silver, ivory, pink,
umber, rust, orange, plum, lime, navy, azure, peach
(`src/ctf/sim_types.nim:1299-1325,3785-3819`).

`shell_view.nim` normalizes both encodings into one small strategy record:
self position/HP/HP fraction/alive, partner position/freshness/inferred alive
and distance, fresh in-range enemy tracks with known HP and the existing
`hp <= 2` weakened classification, kill feed, current/next zone rectangles,
alive teams, tick, and epoch. `desiredPhase` reads only this record. The phase
tests confirm survival selects crossfire for a nearby weak visible fight,
selects jackal after a recent kill with two weak visible enemies, and recalls
to survival independently for zone urgency, low HP, partner death, an own-team
kill after phase entry, and loss of all fresh in-range enemy tracks.

Three values used by the strategy are derived rather than carried. Tracks have
no alive bit, so partner death remains a persistent inference from kill-feed
victim rows; a fresh partner track supplies position and the positive alive
inference. Distance is Euclidean from self/track positions. `weakened` is
derived from optional known HP. The binary kill-feed record also omits the JSON
model's internal event ID, which this strategy does not use.

The capture test imports the engine encoder via
`--path:/tmp/engine-main-v40/src`, creates a typed synthetic BR view with a
partner exactly 150 px away, two enemies, two kill-feed rows, and current/next
zone rectangles, then decodes the engine-produced `PV1` bytes and asserts every
field. The same source encoded by `buildPlayView` must produce an identical
normalized record. Separate cases pass `PV1` plus garbage and the three-byte
payload `PV1`; both return a typed failure without raising. The command and
result were:

```sh
nim c -r --hints:off --warning:UnusedImport:off \
  --nimcache:/tmp/johomax-view-test-cache \
  --out:/tmp/johomax-shell-view-test \
  --path:/tmp/johomax-j/bot --path:/tmp/engine-main-v40/src \
  /tmp/johomax-j/bot/tests/shell_view_test.nim
```

```text
[Suite] Season 2 strategy view decoder
  [OK] engine binary capture exposes every strategy field
  [OK] engine JSON and binary views normalize identically
  [OK] truncated and garbage PV1 payloads are ignored without raising
```

The socket-free phase suite also passed all three cases. The release native
build completed with the requested command. The 32-seat engine episode harness
was retried with threads, `-d:noSignalHandler`, and the available Wasmtime 40
library; Nim semantic analysis again completed, then C compilation stopped at
`wasmtime_shim.h:6:10` because that library output contains no `wasmtime.h`.
It therefore could not be extended to hand its episode-produced view to this
decoder in this sandbox; the direct upstream-encoder capture test covers that
byte boundary without Wasmtime or sockets.

## Wire facts checked

The encoders were checked byte-for-byte with fixed vectors, and the decoders
were exercised for all three server packet types:

```text
0xA0: u8 op, u8 version, u64 upload_id, u32 length, wasm
0xA1: u8 op, u8 version, u64 proposal_id, u32 length, canonical call JSON
0xA2: u8 op, u8 version, six zero bytes, u64 status mark
0xA3: u8 op, u8 version, u32 length, UTF-8 lobby text
0xB0: header, length-prefixed control JSON, length-prefixed context JSON
0xB1: header, u32 tick, length-prefixed control JSON, length-prefixed view bytes
0xB2: header, u64 ordinal, u32 tick, u8 seat, u8 team, length-prefixed text
```

The decoder rejects short fields, over-cap payloads, wrong versions, unknown
owned opcodes, and trailing bytes. Unknown binary packets on an established
play socket are ignored because the legacy broadcast stream shares that
socket. JSON view points are `[x,y]` and zone rectangles are `[x,y,w,h]`;
binary views carry the corresponding fixed-width fields described above.

The check command was:

```sh
export PATH=/Users/jordan/.nimby/nim/bin:$PATH
nim c -r --hints:off --nimcache:/tmp/johomax-shell-wire-cache \
  --path:bot /tmp/johomax_shell_wire_test.nim
```

Result: `shell wire checks passed`.

## Embedded playbook and toolchain

`scripts/build_playbook.sh` compiles these pinned reference sources and runs
`scripts/playbook_to_nim.py` to emit repository `const array[..., uint8]`
modules. The generator records SHA-256 and rejects output above 256 KiB.

The machine had no wasi-sdk 33 checkout and the sandbox could not contact the
Nix daemon, so this run used the script's freestanding Zig path. It supplies
only the five libc primitives generated Nim needs; it does not add WASI or a
runtime dependency. The exact build was:

```sh
export PATH=/Users/jordan/.nimby/nim/bin:$PATH
CTF_ENGINE_DIR=/Users/jordan/Desktop/Projects/johomax/johomax_ctf/.engine \
ZIG=/nix/store/028ijby1w76fyi94xwanqp74czbw7iw3-zig-0.16.0/bin/zig \
./scripts/build_playbook.sh
```

The copied engine SDK supplies `--os:standalone --cpu:wasm32`, `-nostdlib`,
`--no-entry`, the exact play exports, exported memory, and
`--max-memory=1048576`. The Zig shim uses `wasm32-freestanding`, a 262,144-byte
stack, stripped output, and an `-O3` freestanding builtins object. `-O3` is
material: an unoptimized first draft passed admission but exhausted the
500,000-step fuel budget in four reference plays; the checked-in recipe makes
all six init and step successfully.

| Module | Bytes | SHA-256 |
|---|---:|---|
| `edge_ride` | 20,016 | `341af1b216e8268f6577d6d9dbc362b4a9921a51ec68017cb5973bc992f6419d` |
| `target_law` | 21,401 | `1f003e4606d892cd419030f4ca4118447d274682a1e5e2c4d6b9cdd63130da1d` |
| `supply_run` | 15,223 | `b41d2383c4273119080e5504dc6b1ec5122d42278b24696b5b7cca834f8dae45` |
| `bodyguard` | 22,299 | `c388dfaa6b99cd6221492ea18076d6001ea14377e7e9b0d85e42e79c105e0dab` |
| `crossfire` | 21,604 | `f440587ec350128b0aec238813f57e3a6ce890218aa8b27dfb58e3318740c1b6` |
| `jackal` | 22,452 | `70042514ce55e4a3757e3ce2b9b78fb2db12d5436d8322c9a0de0b1c004799d1` |

All six passed the engine's production `validateUploadedModule` stages: byte
limit, core-Wasm validation, interface/import/export/memory checks, Wasmtime
compilation, metered manifest invocation, and manifest parsing. Full harness
cases then called `play_init` with the real call parameters and `play_step`
with an engine-encoded binary BR view. Every call returned zero, every emitted
intent/policy was accepted, and none faulted or exhausted fuel.

## Local proof and numbers

### Upstream 32-seat episode path

The supplied server executable was built without play runtime support. For a
stronger socket-free check, a temporary copy of upstream main was linked to the
locally available Wasmtime 40.0.2 C library. Only the temporary copy disabled
four v48-only config calls; the upload validation, compile plane, call
validator, ladder, body, and episode sources were unmodified upstream-main
code. This is not a substitute for the requested v48 server run, but it tests
the production path rather than a policy-side mock.

One episode was configured with 32 `scPlay` seats. Every seat uploaded the six
exact embedded blobs sequentially and verified the ready identity. Ready
completion by module was:

| Module | Ready seats | Episode tick |
|---|---:|---:|
| `edge_ride` | 32 | 81 |
| `target_law` | 32 | 178 |
| `supply_run` | 32 | 235 |
| `bodyguard` | 32 | 297 |
| `crossfire` | 32 | 364 |
| `jackal` | 32 | 416 |

Totals: 192 `module_ready`, 32/32 survival calls accepted, 768 masks over 24
post-call ticks, 48 standing-order installs, and 0 play faults or retune
refusals. The last module was ready well before the configured 600-tick lobby
boundary in this run.

### Static shipped binary

Both the native development binary and the requested static target compile.
The static command was:

```sh
env \
  PATH=/Users/jordan/.nimby/nim/bin:/nix/store/028ijby1w76fyi94xwanqp74czbw7iw3-zig-0.16.0/bin:/usr/bin:/bin \
  CTF_BOT_DEPS=/Users/jordan/Desktop/Projects/johomax/johomax_ctf/.bot-deps \
  BUILD_AMD64_CACHE=/tmp/johomax-amd64-cache \
  ./scripts/build_amd64.sh bot /tmp/johomax-bot-amd64
```

Result: statically linked x86-64 ELF, 5,686,744 bytes, SHA-256
`1a8cb99aaa324d149d387015e50a146e397ecf63172917f9235220133815e261`.
There are no new runtime files or dynamic dependencies.

### Classic in-process smoke

The classic simulator still builds because it links `decide`/`host`, not the
new process loop. A complete four-seed BR color rotation ran with no lost
episodes:

```sh
CTF_ENGINE_DIR=/Users/jordan/Desktop/Projects/johomax/johomax_ctf/.engine \
SIM_BINARY=/tmp/johomax-simulate SIM_WORK=/tmp/johomax-sim-work \
CTF_SIM_WORKERS=4 \
python3 scripts/local_sim.py br bot/baseline HEAD -n 4
```

All four episodes ended by wipe at 1,219, 1,320, 1,378, and 1,822 ticks
(median 1,349). They produced 116 kills, 122 deaths, 541 shots, and 431 hits.
This was a mechanism smoke, not a strength result; four seeds are far below
the repository's measurement standard.

### Requested socket tests blocked by the sandbox

`/tmp/johomax-s2-config.json` was generated from the upstream
`battle-royale-s2` `game_config`, with 32 named players and tokens
`0xBADA55_0` through `0xBADA55_31`. It has 32 play-control slots,
`season2Shell=true`, `viewIntervalTicks=6`, `lobbyChatTicks=600`, and
`playSeatBindTicks=7200`.

The provided `ctf_server_main` stopped before bind because it has no play
runtime:

```text
Config selects play-control seats, but this binary was built without the play runtime.
```

A runtime-enabled upstream-main server was then built in `/tmp`. It reached
`starting ctf on 127.0.0.1:2010`, but this execution sandbox denies local
socket creation:

```text
mummy.nim(1718) serve
Operation not permitted [MummyError]
```

All 32 native bots independently received `connect retry: Operation not
permitted`. The supplied classic server/config on port 2011 failed at the same
bind call. Docker smoke was also unavailable because access to the local
Docker API socket was denied.

Consequently this environment cannot produce the requested network-only
artifacts: live bot stdout showing mode selection/acks, server-side accepted
call lines, classic `nav built` stdout, or a network game's kill breakdown.
The byte codecs, exact calls, modules, 32-seat production episode path, classic
simulator path, and shipped static binary were verified independently above.

## What is still missing to play well

- None of the recall thresholds is measured. The fight classifier is only a
  deterministic first pass over recent visible tracks, partner geometry, kill
  feed, HP, and zone state.
- Crossfire currently means one weak visible enemy plus a fresh nearby partner;
  it does not prove that both guns share the same target.
- Jackal currently means a recent kill plus two weakened visible enemies; it
  does not reconstruct a fight cluster.
- There is no lobby negotiation or `pact` module yet.
- The reference controllers inherit their documented limitations: ordinary
  fog/last-known partner tracks, visible-only medkit memory, and the degraded
  jackal fight model.
- The native-reflex call example should be corrected upstream, and the full
  v48 network test must be rerun in an environment that permits loopback
  sockets before shipping.
