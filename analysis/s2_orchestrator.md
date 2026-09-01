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
   for `module_ready`, then verifies both the manifest name and the server's
   SHA-256 before continuing.
3. Acknowledges exactly the highest consumed durable status. On reconnect it
   resends an outstanding operation only when its ID is above the corresponding
   admission floor.
4. Sends the survival call once all six modules are ready. A view can replace
   it with crossfire or jackal only on a strategy phase change; zone urgency,
   low HP, partner death, a completed kill, or loss of the visible fight
   restores survival.
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

## Wire facts checked

The encoders were checked byte-for-byte with fixed vectors, and the decoders
were exercised for all three server packet types:

```text
0xA0: u8 op, u8 version, u64 upload_id, u32 length, wasm
0xA1: u8 op, u8 version, u64 proposal_id, u32 length, canonical call JSON
0xA2: u8 op, u8 version, six zero bytes, u64 status mark
0xA3: u8 op, u8 version, u32 length, UTF-8 lobby text
0xB0: header, length-prefixed control JSON, length-prefixed context JSON
0xB1: header, u32 tick, length-prefixed control JSON, length-prefixed view JSON
0xB2: header, u64 ordinal, u32 tick, u8 seat, u8 team, length-prefixed text
```

The decoder rejects short fields, over-cap payloads, wrong versions, unknown
owned opcodes, and trailing bytes. Unknown binary packets on an established
play socket are ignored because the legacy broadcast stream shares that
socket. The socket view's points are `[x,y]` and zone rectangles are
`[x,y,w,h]`; the strategist reads those array forms.

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
