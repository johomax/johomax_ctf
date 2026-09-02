# Season 2 play-seat shell: wire contract and migration note

Source basis: shell behavior and byte/layout citations below are from the pinned
engine snapshot `9d26cc26b4a1ca1f4d121d77688ae9ce99fc3e35` (abbreviated
`9d26cc26`). Publishing, default, and rollout statements are separately tied to
the named commits on `origin/main`, whose tip inspected here was
`27e9cac1e02beb1dffadb8f9c862737b4460ac47`. Project-history citations are
from this repository at `0b7377735295548b61a8f835e9370b573ff198fb` unless a
workspace capture is explicitly identified as uncommitted.

## 1. Raw Sprite input on a `control: "play"` seat

**No: the current Nim policy cannot control a play seat with Sprite v1 masks.**
A well-framed legacy input message whose leading opcode is `0x84` is accepted
by the WebSocket receive path, classified as `prIgnoredSpriteInput`, counted in
`playSpriteInputIgnored`, and otherwise discarded. It neither changes the
retained mask nor disconnects the socket. `0x85` ready and Sprite debug packets
are similarly ignored. Sprite `0x81` in-match chat and the mouse messages still
pass to the old Sprite parser. Unknown opcodes and malformed shell packets are
rejected and counted, but that ordinary rejection also does not itself close
the socket. [`.engine/src/shell/dispatch.nim:45-76` @ `9d26cc26`]
[`.engine/src/ctf/server.nim:1323-1381` @ `9d26cc26`]

This is tested at the state boundary: after a play seat sends mask `0xff`, its
input remains zero and the ignored counter becomes one; an input seat in the
same gate-on engine retains mask `0x5a`. A Sprite message containing legal chat
followed by an embedded mask delivers the chat but restores the play seat's old
mask. [`.engine/tests/test_shell_dispatch.nim:541-556` @ `9d26cc26`]
[`.engine/tests/test_shell_dispatch.nim:596-622` @ `9d26cc26`]

One wrinkle matters to this bot: it sends the nonstandard sprites-off byte
`0x87` immediately after connecting. `0x87` is not on the play-seat allowlist,
so it is a strict `prrUnknownOpcode` rejection, again normally without a
disconnect. The bot then sends `0x84` masks, which are ignored. Thus, if it
remains connected, the engine's safe default play drives the cog; none of the
Nim navigation/combat decisions do. [`.engine/tests/test_shell_dispatch.nim:624-649`
@ `9d26cc26`] [`bot/baseline.nim:147-199` @ project `0b737773`]

The disconnect case is abuse containment, not legacy incompatibility: the first
message beyond either `MaxMessagesClassifiedPerSeatPerTick = 64` or
`MaxBytesClassifiedPerSeatPerTick = 524288` returns `false` from dispatch and
records `classification_budget_exceeded`. [`.engine/src/shell/types.nim:293-323`
@ `9d26cc26`] [`.engine/src/ctf/server.nim:1331-1345` @ `9d26cc26`]

**There is a configuration seam, but no policy-controlled escape hatch.** A
seat is a play seat only when `season2Shell` is true, at least one configured
slot is play-controlled, and that seat's trusted `slots[seat].control` is
`"play"`. An all-`input` roster stays on the legacy Sprite path even with
`season2Shell` enabled; a mixed roster is decided seat by seat. The image cannot
request a downgrade over the wire. [`.engine/src/shell/seats.nim:79-88` @
`9d26cc26`] [`.engine/src/ctf/server.nim:1253-1260` @ `9d26cc26`]

The later “legacy-boot override” is `allowDeprecatedModes`, a game/league boot
configuration field. It lets operators start archived classic configurations;
it does not reinterpret `control: "play"` as `control: "input"`. Conversely,
the published S2 certification config can deliberately use all-input seats so
old baselines can certify the image, but that is a server manifest choice, not
a participant privilege. The default inversion (`season2Shell = true`) and
boot refusal for legacy modes landed in `origin/main` commit `8dfb1e60`; the
archived-mode override and S2-only publication landed in `e41e8922` and merge
`1cf6c6a3`. The regression proof that classic input seats still reach the sim is
commit `516d72a0`. None of those commits weakens the per-seat rule above.

## 2. Full play-seat wire contract

### Connection and lifecycle

The player still opens the ordinary binary WebSocket supplied by the platform.
For a local direct connection the reference client demonstrates
`ws://HOST:PORT/player?slot=N&token=T`; a hosted image should use the complete
injected `COWORLD_PLAYER_WS_URL`, as the existing bot does, rather than invent
the URL. [`.engine/policies/poc_llm_policy/README.md:21-31` @ `9d26cc26`]
[`bot/baseline.nim:215-219` @ project `0b737773`]

On registration the server assigns control generation 1, sends `PlayContext`
`0xB0`, and then sends control-only `PlayView` `0xB1` frames (`viewLen = 0`)
during pre-activation. Uploads, calls, status acknowledgements, reconnect, and
backpressure already work in this state. At activation the generation changes,
epoch zero gets a safe hold/empty-combat order, and the native default
controller runs until a valid ladder supersedes it. A client that uploads or
calls nothing therefore still moves under the engine default rather than
having an undefined mask. [`.engine/docs/designs/strategy-play-calling-shell-2026-08-29.md:525-547`
@ `9d26cc26`]

All shell packets are one **binary WebSocket message per packet**, little
endian, with `u8 opcode, u8 version`; version is exactly 1, reserved bytes must
be zero, length equations must match exactly, and trailing bytes reject the
packet. [`.engine/src/shell/types.nim:218-253` @ `9d26cc26`]

| Packet | Direction | Exact payload after `op,ver` | Maximum total bytes |
|---|---|---|---:|
| `ModuleUpload` `0xA0` | client → server | `u64 uploadId, u32 len, wasm[len]` | `14 + 262144 = 262158` |
| `PlayCall` `0xA1` | client → server | `u64 proposalId, u32 len, canonical ladder JSON[len]` | `14 + 4096 = 4110` |
| `StatusAck` `0xA2` | client → server | six zero reserved bytes, `u64 mark` | 16 exactly |
| Sprite shout `0x81` | client → server | legacy Sprite framing; in-match only | legacy limit, then sanitized to 10 characters |
| `LobbyChat` `0xA3` | client → server | `u32 len, UTF-8[len]` | `6 + 512 = 518` |
| `PlayContext` `0xB0` | server → client | `u32 controlLen, control JSON, u32 ctxLen, context JSON` | `10 + 20480 + 65536` |
| `PlayView` `0xB1` | server → client | `u32 tick, u32 controlLen, control JSON, u32 viewLen, view JSON` | `14 + 20480 + 32768` |
| `LobbyChat` `0xB2` | server → client | `u64 ordinal, u32 tick, u8 seat, u8 team, u32 len, UTF-8[len]` | `20 + 512 = 532` |

The normative table and exact length checks are in
`.engine/docs/designs/strategy-play-calling-shell-2026-08-29.md:472-520` at
`9d26cc26`; the implemented opcode and cap constants are in
`.engine/src/shell/types.nim:218-323` at `9d26cc26`.

The socket can also receive legacy Sprite broadcasts. The reference decoder
deliberately ignores unknown leading bytes after handling `0xB0`, `0xB1`, and
`0xB2`; a migrated policy must not feed those binary shell packets into its
Sprite frame parser. [`.engine/policies/poc_llm_policy/wire.py:239-250` @
`9d26cc26`]

### Lobby chat

The published variant sets `lobbyChatTicks: 600`, so at the engine's 24 Hz tick
rate the open lobby lasts **25 seconds**, after all required play seats are
bound and before the normal `startWaitTicks` countdown. Its cumulative
pre-activation presence budget is `playSeatBindTicks: 7200`, or **300 seconds**;
absence pauses neither the budget nor resets it, while a successful rebind
pauses further consumption and never restarts chat. [`.engine/coworld_manifest_paintbot.json:6608-6611`
@ `9d26cc26`] [`.engine/docs/designs/strategy-play-calling-shell-2026-08-29.md:2461-2486`
@ `9d26cc26`] [`.engine/docs/RULES.md:1003` @ `9d26cc26`]

A client sends `0xA3`; accepted messages are broadcast as separate `0xB2`
packets to every play seat, including the sender. The server, not the client,
stamps monotonically increasing episode `ordinal`, `tick`, `seat`, and `team`.
The usable identities are `seat:N` and `duo:<team>`; display names are absent.
The payload rules are exact:

- raw UTF-8 is at most 512 bytes and must be strictly valid;
- C0/C1 controls are forbidden except LF `U+000A`; `U+2028` and `U+2029` are
  also forbidden;
- bytes are not normalized or altered;
- empty text or text composed only of ASCII space and LF rejects;
- at most 16 accepted messages per seat per phase, with at least 24 ticks
  (one second) between messages;
- outside the chatting substate it rejects as `lobbyClosed`.

The exact validation order and limits are specified at
`.engine/docs/designs/strategy-play-calling-shell-2026-08-29.md:2488-2530` at
`9d26cc26`; constants are in `.engine/src/shell/types.nim:321-323` at
`9d26cc26`.

Delivery is ordered and at-least-once. On bind/rebind, `0xB0` carries transcript
high-water `H`; the server replays `1..H` as `0xB2` before opening the live
stream. The client must remember its highest applied lobby ordinal and ignore
duplicates. The maximum transcript is 32 seats × 16 messages = 512 packets;
replay is pumped in batches of 64 rather than enqueued at once. In-match chat is
instead Sprite `0x81`, limited after sanitization to 10 characters, one per
second, and audible only within `ShoutRange`; received shouts appear as fogged
facts in `PlayView`. [`.engine/docs/designs/strategy-play-calling-shell-2026-08-29.md:2532-2595`
@ `9d26cc26`] [`.engine/docs/designs/strategy-play-calling-shell-2026-08-29.md:472-484`
@ `9d26cc26`]

### Uploading the playbook

Each `0xA0` contains one raw **WebAssembly 1 core module**, not a bundle or JSON
description. `uploadId` is client-chosen and monotonically increasing. At the
tick boundary the server emits durable JSON status `kind` values
`module_accepted`, then either `module_ready` (including the manifest-declared
`name` and server SHA-256) or `module_rejected`. A call must wait for
`module_ready`; a merely accepted/compiling name is not callable. The module's
`play_manifest()` export emits its ABI/name/class/modes/retune/typed-parameter
JSON during the server probe. [`.engine/docs/designs/strategy-play-calling-shell-2026-08-29.md:548-597`
@ `9d26cc26`] [`.engine/tests/fixtures/shell/status_module_ready.golden.json:1`
@ `9d26cc26`]

Bindings are immutable within one episode: `(seat, name) -> sha256`. Identical
bytes are a no-op ready result; different bytes claiming the same name reject
as `nameBound`, so a replacement must use a new name such as `edge_ride_v2`.
Uploads are legal throughout the episode, though pregame is the sensible time.
Limits per seat are 16 modules, 256 KiB per raw module, 2 MiB admitted raw bytes
per episode, and one admitted upload per tick. IDs commit in admission order
even if compile workers finish out of order. [`.engine/src/shell/types.nim:293-304`
@ `9d26cc26`] [`.engine/docs/designs/strategy-play-calling-shell-2026-08-29.md:563-596`
@ `9d26cc26`]

The validation pipeline is size/budget/ID, SHA-256, Wasmtime validation,
interface inspection, compile, a fuel-bounded manifest probe, manifest schema
validation, and ordered binding commit. It disallows WASI and any undeclared
import/export surface; the exact ABI is in section 3 below.

### Calling plays, cadence, and statuses

`0xA1` carries the **complete replacement ladder**, not a delta:

```json
{"plays":[{"play":"edge_ride","params":{"margin":220,"coverBias":1.0,"enterLead":120}}]}
```

An entry may also have `when`, `entry_id`, and `retune`. The entire call is
validated atomically. Acceptance creates the next epoch and applies from that
tick; `call_accepted` reports `proposal_id`, `epoch`, and `tick`. A
`call_rejected` leaves the old ladder untouched. `proposalId` is monotonically
increasing; at most two calls per seat per tick are admitted; canonical call
JSON is at most 4096 bytes with at most 16 entries. [`.engine/src/shell/schemas/ladder_call.schema.json:1-24`
@ `9d26cc26`] [`.engine/docs/designs/strategy-play-calling-shell-2026-08-29.md:598-616`
@ `9d26cc26`] [`.engine/src/shell/types.nim:299-304` @ `9d26cc26`]

Every sim tick, all passing overlays fold in ladder order, then the first
passing controller wins; the native default controller is the unguarded floor.
Only two overlays and one controller can step, so guest execution is capped at
three steps per seat per tick. An unguarded controller that emits `Hold` still
shadows every controller below it—important for `supply_run` and `jackal`.
[`.engine/docs/designs/strategy-play-calling-shell-2026-08-29.md:2074-2138`
@ `9d26cc26`] [`.engine/src/shell/types.nim:301-304,343-359` @ `9d26cc26`]

The external policy does **not** call once per engine tick. The server steps the
resident play instances at 24 Hz and publishes socket views every
`viewIntervalTicks: 6`, i.e. **4 Hz**, plus an immediate/control-only frame when
status state becomes dirty. A call persists until replaced, so call on a real
strategy change. [`.engine/src/shell/outbound.nim:228-240` @ `9d26cc26`]
[`.engine/coworld_manifest_paintbot.json:6608-6611` @ `9d26cc26`]

Statuses are durable, cumulative JSON entries in the `0xB1` control envelope:
`module_accepted`, `module_ready`, `module_rejected`, `call_accepted`,
`call_rejected`, `play_faulted`, and `retune_refused`. Each has monotonic
`ordinal` and origin `gen`; retain/apply it once, then send `0xA2` with the
highest ordinal observed. Up to 64 entries × 256 bytes are retained, with 16
reserved for faults. The acknowledgement high-water must be nondecreasing and
not beyond the highest issued ordinal. [`.engine/src/shell/schemas/status_entry.schema.json:1-70`
@ `9d26cc26`] [`.engine/docs/designs/strategy-play-calling-shell-2026-08-29.md:629-668`
@ `9d26cc26`] [`.engine/src/shell/types.nim:305-310` @ `9d26cc26`]

### Observation delivered to a play seat

The policy-facing observation is **structured canonical JSON**, not the Sprite
render frame. `0xB0` context contains schema/version, mode, map name/width/
height, full roster with seat/team/control, own seat/team/duo partner, gun
range, and view interval. [`.engine/src/shell/view.nim:612-647` @ `9d26cc26`]

Each nonempty `0xB1` view contains schema/version, tick, epoch, `self`, `world`
(`alive_teams`, zone, mode objectives where applicable), and when present
`tracks`, `items`, `aggressors`, `kill_feed`, `shouts`, `hazards`, and standing
`intent`. It is a fog-filtered knowledge model, not omniscient sim state; it
does not expose hidden enemies, a partner's selected order, or the raw map
raster. The deterministic row caps are tracks 32, items 32, aggressors 16,
kill-feed 32, shouts 32, grenades 8, blast cues 4, and sprays 8.
[`.engine/src/shell/view.nim:150-180,213-221` @ `9d26cc26`]
[`.engine/src/shell/view.nim:564-610` @ `9d26cc26`]

There are two encodings of the same selected facts: socket/replay gets the JSON
above (view cap 32768, context cap 65536), while guest `play_init`/`play_step`
receives an engine-defined fixed-layout binary context/view, each capped at
8192 bytes. A custom module must use the SDK/binary ABI, not parse the socket
JSON inside `play_step`. [`.engine/src/shell/types.nim:390-403` @ `9d26cc26`]
[`.engine/docs/designs/play-view-binary-frame-2026-08-31.md:1-6,33-75,119-134`
@ `9d26cc26`]

### How execution stays deterministic

The server embeds Wasmtime `48.0.1` with Cranelift, fuel consumption, epoch
interruption, NaN canonicalization, one-memory pooling, no moving memory, and a
5 ms epoch ticker with deadline 4 (about a 20 ms wall-clock backstop).
[`.engine/src/shell/runtime.nim:18-32,99-160` @ `9d26cc26`]

Seat stepping is in stable seat order and ladder order. Guest instruction work
is fuel-bounded; floating NaNs are canonicalized; spatial-query candidates and
ties have deterministic ordering. Replays do not rerun policy code, Wasmtime,
the body, network, or lobby decisions: they record/replay the final per-tick
input masks plus the hash-coupled calls/annotations. A trap, fuel exhaustion,
bad emit, or deadline faults that ladder instance and falls through to the next
entry/default; it does not give the client a raw-input path.
[`.engine/docs/designs/strategy-play-calling-shell-2026-08-29.md:1744-1795,2293-2306,2351-2381`
@ `9d26cc26`]

### Actual seven-play reference menu

The table below follows the **module manifests actually emitted at
`9d26cc26`**, not stale prose in Appendix P.

| Play | Class | Exact parameter schema (defaults in bold) |
|---|---|---|
| `pact` | overlay, BR | `partners`: required set of 1..8 `seat_or_duo_ref`; `holdFire`: union `aliveTeams` int 2..16 / `zonePhase` int 1..8 / `tick` int ≥0, **`{"aliveTeams":2}`**; `protect`: bool **false**; `onBetrayal`: `disengage` or **`returnFire`** |
| `edge_ride` | controller, BR | `margin` int 40..600 px **220**; `coverBias` number 0..1 **0.8**; `enterLead` int 0..600 ticks **120** |
| `bodyguard` | controller, BR | optional `ward`: `seat_or_duo_ref` (duo partner from context when absent); `leash`: two ints each 0..4096, **`[80,220]`**; `interpose`: bool **true**; `peelHp`: int 0..64 **2** |
| `jackal` | controller, BR | `earshot` int 100..1200 px **500**; `joinWhen`: **`afterKill`** or `bothWeakened`; `exitAfter`: `kills` int 1..4 or `hpFloor` int 0..3, **`{"kills":1}`** |
| `target_law` | overlay, BR/CTF | `never`: set 0..8 `seat_or_duo_ref`, **`[]`**; `prefer`: ordered list 0..4 of `bounty`, `isolated`, `revenge`, `weakened`, **`[]`**; optional `holdTrigger`: same three-arm union as `pact` (no arbitrary condition expression) |
| `supply_run` | controller, BR | `whenHpBelow` int 0..64 **3** (strictly below); `detourMax` int 0..4096 px **500**; `contested`: **`avoid`** or `race` |
| `crossfire` | controller, BR | `spacing`: two ints each 0..600 px, **`[120,320]`**; `minAngle`: int 0..128 brads, **32** |

Manifest citations at `9d26cc26`: `.engine/play_sdk/reference/pact.nim:9-12`,
`.engine/play_sdk/reference/edge_ride.nim:10-13`,
`.engine/play_sdk/reference/bodyguard.nim:13-16`,
`.engine/play_sdk/reference/jackal.nim:15-18`,
`.engine/play_sdk/reference/target_law.nim:14-16`,
`.engine/play_sdk/reference/supply_run.nim:16-19`, and
`.engine/play_sdk/reference/crossfire.nim:13-16`.

There is real documentation drift. Appendix P still says bodyguard defaults
`[60,220]`, `false`, `1` with smaller ranges and says supply-run is BR/CTF with
HP default 2/range 1..3 and detour maximum 1500. It also describes
`target_law.holdTrigger` as general `ConditionSpec`. Those disagree with the
compiled manifests above; the server validates against the uploaded manifest,
so the runtime manifests are authoritative. [`.engine/docs/designs/strategy-play-calling-shell-2026-08-29.md:2958-2989`
@ `9d26cc26`]

## 3. Can we ship our own play bodies?

**Yes, we may upload our own WASM plays, but “play body” needs a precise
qualification.** Player-authored core-WASM modules may be built from Nim, C,
Rust, or another compiler that can obey this freestanding ABI. They implement
new named controllers/overlays and can carry our strategic state and decision
logic. We are not restricted to composing the seven reference modules.
`BR_PLAYS.md` is an older hard-coded-play proposal; the later strategy-shell
design explicitly supersedes it and makes play WASM player-authored.
[`.engine/docs/designs/BR_PLAYS.md:1-24` @ `9d26cc26`]
[`.engine/docs/designs/strategy-play-calling-shell-2026-08-29.md:3-8,21-67`
@ `9d26cc26`]

**But custom WASM cannot replace the engine's low-level body.** A controller
emits a high-level `Intent` such as NavigateTo/Hold plus point, arrival radius,
moving-goal/profile/micro/idle-aim fields; an overlay emits `CombatPolicy` such
as no-shoot/protect/preference/hold-fire policy. The engine validates/folds
those values, performs navigation, aim, target selection, firing and hazard
reflexes, then writes the final Sprite-equivalent input mask. There is no host
function or emit type for raw movement/aim/fire bits. Therefore our present Nim
nav grid, ray logic, aim controller, and mask generator cannot simply be
compiled to WASM unchanged; only their strategic layer can be ported under ABI
v1. [`.engine/docs/designs/strategy-play-calling-shell-2026-08-29.md:354-421,1655-1700`
@ `9d26cc26`] [`.engine/src/shell/body.nim:1117-1274` @ `9d26cc26`]

### Exact guest ABI

One module must export exactly one linear memory and these functions:

```text
memory
play_alloc(i32 len) -> i32
play_manifest() -> ()
play_init(i32 paramsPtr, i32 paramsLen, i32 contextPtr, i32 contextLen) -> i32
play_step(i32 viewPtr, i32 viewLen) -> i32
play_retune(i32 oldParamsPtr, i32 oldParamsLen, i32 newParamsPtr, i32 newParamsLen) -> i32  # optional
```

No other export is allowed. [`.engine/src/shell/module_interface.nim:206-248`
@ `9d26cc26`]

Imports are an optional subset of namespace `play`, with no WASI:

```text
play.emit(i32 ptr, i32 len) -> i32
play.log(i32 level, i32 ptr, i32 len) -> ()
play.nearest_reachable(i32 x, i32 y) -> i64
play.nearest_cover(i32 x, i32 y,
                   i32 radius, i32 bearingBrads,
                   i32 threatsPtr, i32 threatsLen) -> i64
```

Signatures and namespace enforcement are in
`.engine/src/shell/module_interface.nim:86-93,195-204` at `9d26cc26`.
Positions, tracks, self/partner facts, zone, items and kill feed are read from
the fixed-layout binary context/view buffers; they are **not** omniscient host
getters. `nearest_reachable` and `nearest_cover` are the only world-query
imports, and the play supplies any threat positions to the latter. `emit`
returns an ABI result code and is used for the manifest during probe, then
`Intent` or `CombatPolicy` during execution; `log` is diagnostic only.

### Resource and feature envelope

- Raw module ≤262144 bytes; exactly one memory with declared maximum ≤16
  64-KiB pages (**1 MiB**); ≤4096 functions and ≤4096 table elements; no start
  function; ≤16 instances per seat.
- Fuel: `play_manifest` 1,000,000; `play_init` 500,000; `play_step` 50,000.
  Initialization quotas are one per seat/tick and two server-wide/tick.
- Per invocation: ≤2 allocations; per step ≤2 emits of ≤4096 bytes each; ≤2
  total spatial calls; ≤4 logs of ≤256 bytes.
- `nearest_cover`: radius ≤331 px, ≤8 threats, ≤1024 cover posts examined.
- Guest stack 262144 bytes; wall-clock epoch backstop 5 ms × 4; binary context
  and view ≤8192 bytes each.
- Core Wasm 2.0 subset only: threads/shared memory, tail calls, function
  references, GC, relaxed SIMD, multi-memory, memory64, exceptions, custom page
  sizes, and stack switching are off. Ordinary reference types, SIMD, bulk
  memory, and multivalue are on.

The numeric caps are implemented in `.engine/src/shell/types.nim:331-447` at
`9d26cc26`; Wasmtime feature switches are in
`.engine/src/shell/runtime.nim:99-160` at `9d26cc26`; memory/export validation is
in `.engine/src/shell/module_interface.nim:189-248` at `9d26cc26`.

Instances bind per ladder entry and per seat. Compiled code is cached globally
by SHA-256, but names, memory, mutable globals, PRNG/decision state, and outcomes
are isolated. Entries instantiate lazily under the initialization quotas;
state persists while that ladder remains installed, parks on death, and is
dropped on replacement unless valid retune adoption applies. A fault disables
that instance for the life of the ladder and falls through to later entries or
the native default. [`.engine/docs/designs/strategy-play-calling-shell-2026-08-29.md:563-577,2140-2200`
@ `9d26cc26`]

## 4. Timeline and seating

### What is published versus what was demonstrably live

The intended league target is unequivocally `battle-royale-s2`: 32
`control:"play"` slots, 16 teams, two cogs per team, `season2Shell:true`,
`viewIntervalTicks:6`, `lobbyChatTicks:600`, and
`playSeatBindTicks:7200`. The slot list repeats the same team ordering at seats
0..15 and 16..31, and the config requires `num_agents:32` and `minPlayers:32`.
[`.engine/coworld_manifest_paintbot.json:4417-4567` @ `9d26cc26`]
[`.engine/coworld_manifest_paintbot.json:6608-6611` @ `9d26cc26`]

On `origin/main`, commit `e41e8922` changed the published manifest to S2 only
and archived nine variants; merge `1cf6c6a3` landed that train at
**2026-09-01 20:25:44Z** (13:25:44 PDT). Commit `8dfb1e60`, one minute earlier,
made `season2Shell` default true and put deprecated-mode boot behind
`allowDeprecatedModes`. Commit `2653b7cc` is the subsequent “default live boot
to season two” change. The later docs truth audit is `c11accd8`/`e8160934`, and
the final ruling record is `27e9cac1` at **20:57:04Z**.

That source publication is not proof that the Observatory league had already
switched. The coordination record first proposed upload → certification →
canonical image → one S2 dress rehearsal → league cut-over; later it records
that deployed `0.7.259` lacked S2 and, at **18:55Z**, that rounds were healthy
but the new image was still the remaining gate.
[`.engine/docs/coordination/agents-notes.md:338-356` @ `9d26cc26`]
[`.engine/docs/coordination/agents-notes.md:444-475` @ `9d26cc26`]
Commit `750d1321` recorded an estimate of source-image push around **21:00Z**
and dispatch around **21:30Z**, not a completion event.

The latest local live-league evidence inspected during this task still shows
classic BR: the project ledger records the 19:20Z switch to
`variant_rotation:["battle-royale"]`, four entrants repeated across 32 seats,
not S2. [ `research/LEDGER.md:5464-5473` @ project `0b737773` ] A captured round
3574 request created against `paintbot 0.7.267` names variant “Battle Royale,”
lists four non-filler participants followed by repeated filler placements, and
does not contain the S2 config. That round directory is an **uncommitted
workspace capture**, so it is evidence but has no commit citation:
`research/br_rounds/3574_round_c2700aaf-6082-4821-afa0-4f9e91910b1a/ereq_2090c1de-a924-4765-bbaa-e63696fa5464.json:1`.

**Conclusion on timing:** S2-only was landed in source and advertised as the
next published manifest, but this repository contains no positive evidence
that the production league cut-over completed by the latest inspected capture.
Treat the cut-over as imminent/rolling, not as safely postponed and not as
proven complete. Querying production was outside this read-only repository
task.

### `team_count: 16` and fillers

The coordination answer is explicit: S2 planning uses `team_count: 16`, and an
underfilled plan without configured fillers fails the planner gate as
`insufficient_players` (`origin/main` commit `627db9b9`, 2026-09-01
20:26:51Z). Here `team_count` is the platform's number of entrant policies, not
the engine's 16 color teams.

Given 32 seats and the manifest's pair layout, the natural planner mapping is
one entrant image per duo: entrant `i` occupies the two same-team seats `i` and
`i+16`. This is an inference from `team_count:16` plus the repeated team blocks,
not a mapping algorithm stated in coworld-ctf itself. It means one submitted
policy runs as two independent processes/cogs for its duo; each process must
bind, upload, and call for its own seat.

If fewer than 16 eligible entrants exist, the league needs filler policies to
reach all 16 entrant positions/32 required seats. With a sufficient configured
filler pool the planner can populate the missing positions; without it, no
round is planned and the named gate is `insufficient_players`. The repository
does not identify the post-cut-over filler roster, so do not assume starter
personas, duplicates, or any particular opponent distribution. At the engine
boundary there is no partial game: S2 still requires all 32 configured seats to
bind, or the 7200-tick presence budget eventually attributes failure to the
lowest absent play slot.

## 5. Shortest path for this policy

### (a) If legacy masks remain usable

They remain usable only when the league assigns this process a
`control:"input"` slot (including an operator-created all-input certification
or mixed roster). In that case the current Sprite path and masks need no S2
wire changes; the regression test explicitly preserves it. A published
`battle-royale-s2` participant slot is `control:"play"`, however, so this is
not a viable league migration plan. Do not key behavior merely on
`season2Shell`; key it on receiving `0xB0`/`0xB1`, or on trusted launch
configuration if the platform exposes control mode.

### (b) Minimal viable S2 policy

The shortest implementation path is a small socket orchestrator derived from
`policies/poc_llm_policy`, not a port of the whole Nim actuator:

1. Connect using `COWORLD_PLAYER_WS_URL`; decode `0xB0`, `0xB1`, `0xB2`; ignore
   legacy broadcasts; deduplicate lobby ordinals.
2. Upload the needed reference `.wasm` modules once per seat with increasing
   IDs; wait for and verify every `module_ready` name/SHA; acknowledge durable
   statuses.
3. Send one standing call before activation, then replace it only when a 4-Hz
   structured view justifies a tactical phase change. Let resident plays run at
   24 Hz.
4. On reconnect, consume the `0xB0` recovery envelope, transcript replay and
   retained statuses before deciding whether an upload/call is already in
   force. The reference policy demonstrates the accepted → ready → call flow.
   [`.engine/policies/poc_llm_policy/poc_policy.py:272-326,412-475` @
   `9d26cc26`] [`.engine/policies/poc_llm_policy/README.md:21-31,118-134` @
   `9d26cc26`]

For “zone-safe, cover-first, duo-cohesive, fight only with advantage,” start
with the three native reflexes, one engagement overlay, guarded recovery/
cohesion controllers, and `edge_ride` as the controller floor:

```json
{
  "plays": [
    {"play":"reflex_clear_grenade"},
    {"play":"reflex_clear_spray"},
    {"play":"reflex_zone_escape"},
    {"play":"target_law","params":{"holdTrigger":{"aliveTeams":8},"prefer":["weakened","isolated"]}},
    {"play":"supply_run","when":["<",["get","self.hp_frac"],0.67],"params":{"whenHpBelow":3,"detourMax":500,"contested":"avoid"}},
    {"play":"bodyguard","when":["<",220,["get","partner.dist"]],"params":{"leash":[80,220],"interpose":false,"peelHp":2}},
    {"play":"edge_ride","params":{"margin":220,"coverBias":1.0,"enterLead":120}}
  ]
}
```

The guard expression shape and registered `self.hp_frac` path are normative in
the design example. [`.engine/docs/designs/strategy-play-calling-shell-2026-08-29.md:2074-2088,2920-2930`
@ `9d26cc26`] This ladder has these deliberate semantics:

- grenade/spray/zone reflexes preempt ordinary movement;
- `target_law` forbids first fire until alive teams fall to 8, but still allows
  engine-defined return fire; after release it latches until ladder replacement;
- `supply_run` only takes controller priority at roughly ≤2/3 HP and itself
  confirms raw HP is below 3;
- `bodyguard` only takes priority when the last-known partner distance exceeds
  220 px; the `-1` unknown sentinel will not pass that guard;
- otherwise `edge_ride` seeks the zone margin with maximum cover bias.

This is a **mechanism-valid starting hypothesis, not a measured winner**.
`aliveTeams:8`, `coverBias:1.0`, and the guard thresholds each require a
one-variable local experiment under the repository's measurement rules.
`target_law` is a coarse global advantage gate, not a local numerical-force
test.

On a favorable visible fight, replace the ladder temporarily so the controller
floor is either:

- `crossfire` with `{"spacing":[120,320],"minAngle":32}` when both guns have a
  common visible target and partner geometry is known; or
- `jackal` with `{"earshot":500,"joinWhen":"bothWeakened","exitAfter":{"kills":1}}`
  when the view shows the cheap third-party opportunity its degraded
  implementation can actually recognize.

Then restore the survival ladder after one kill, loss of the track/partner, or
zone urgency. Do not put guardless `jackal`, `crossfire`, or `supply_run` above
`edge_ride` permanently: their valid `Hold` output still consumes the one
controller slot. The reference modules themselves document that bodyguard and
crossfire use ordinary fog/last-known partner tracks, jackal lacks the planned
fight-cluster query, and supply-run forgets medkits once they leave its current
view. [`.engine/play_sdk/reference/bodyguard.nim:3-9` @ `9d26cc26`]
[`.engine/play_sdk/reference/jackal.nim:3-11` @ `9d26cc26`]
[`.engine/play_sdk/reference/supply_run.nim:3-12` @ `9d26cc26`]
[`.engine/play_sdk/reference/crossfire.nim:3-9` @ `9d26cc26`]

**Lobby `pact`: low initial priority.** It is mechanically meaningful—the
overlay can add no-shoot/protect rules and dissolve on an agreed condition—but
chat is unauthenticated negotiation, not a contract, and `pact` only constrains
our body. An opponent may lie or simply not implement it; the public broadcast
also reveals the coalition, and winner-take-all endgame incentives favor
betrayal. Do not pact with our own duo: team identity/body behavior already
handles that relationship. If the field actually responds, have the lower of
our two seats send one deterministic offer and install, for example,
`{"play":"pact","params":{"partners":["duo:navy"],"holdFire":{"aliveTeams":4},"protect":false,"onBetrayal":"returnFire"}}` only after an exact reciprocal
message. This occupies one of two overlay slots alongside `target_law`; it
dissolves once alive teams ≤4 and latches betrayal handling. Pact timing and
betrayal semantics are specified at
`.engine/docs/designs/strategy-play-calling-shell-2026-08-29.md:2934-2951` at
`9d26cc26`.

### (c) Risks to close before shipping

1. **Cut-over ambiguity:** source is S2-only, but the latest stored live round
   evidence is still classic BR. Build both a legacy-capable artifact and the
   S2 orchestrator only if one image can safely protocol-detect; do not assume
   an ETA is a completed deployment.
2. **Silent loss of control:** `0x84` is ignored, not disconnected. The current
   bot can look healthy while the default play—not our policy—earns the result.
   Treat the first valid `0xB0` as a hard mode switch and alert if uploads/calls
   never reach ready/accepted.
3. **Current startup incompatibility:** remove/suppress `0x87` on play seats and
   keep Sprite parsing separate from `0xB0`/`0xB1`/`0xB2`.
4. **ABI mismatch:** WASM is high-level strategy only. The competitive value of
   the existing Nim navigation, cover, aiming and fire logic is lost unless
   translated into Intent/CombatPolicy or the upstream ABI grows.
5. **Manifest/doc drift:** generated/runtime module manifests, not Appendix P,
   decide validation. Pin module hashes and test the exact engine version.
6. **WASM toolchain fit:** Nim's runtime/startup/allocation behavior may violate
   no-WASI, 256-KiB module, 1-MiB memory, 256-KiB stack, or 50k-step-fuel limits.
   Start from the SDK/reference build shape and containment harness.
7. **Per-seat lifecycle:** the duo's two processes upload/call independently.
   Global SHA caching saves compilation but does not share binding or instance
   state. Handle reconnect generations, monotonic IDs, durable status ack, and
   at-least-once lobby replay.
8. **Startup burst:** 32 seats may upload simultaneously, but only two
   initializations occur server-wide per tick; `module_accepted` is not
   `module_ready`. Never call by name before ready.
9. **Ladder shadowing:** only two overlays and one controller execute. Guardless
   or over-broad controllers can freeze later movement while appearing valid.
10. **Observation rate and fog:** socket logic sees 4 Hz structured views,
    while resident modules/body run 24 Hz. Partner/enemy tracks are incomplete
    and sometimes stale; there is no partner-order channel.
11. **Fail-safe masks bugs:** faults fall through to the native default. That
    prevents a dead cog but can conceal a broken custom play unless
    `play_faulted` and counters are surfaced.
12. **Lobby misuse:** `0xA3` after the 600-tick phase is `lobbyClosed`; use
    Sprite `0x81` for the much smaller/range-limited in-match shout channel.
13. **Fillers/opponent mix:** `team_count:16` needs fillers below 16 entrants,
    but their identities and duplication policy are not established here.
    Measure against the actual roster once published.

## Mining replays

`analysis/s2_replays.py` joins the engine's format-2 replay records to the
episode request's participant positions and results artifact. It uses only the
Python standard library.

Fetch recent completed league episodes, then mine the directory:

```bash
export PATH="$HOME/.nimby/nim/bin:$PATH"
analysis/s2_replays.py fetch --since 3630 --limit 200
analysis/s2_replays.py mine research/s2_replays \
  > research/s2_replays/report_3630_3649.md
```

`--limit` is the maximum number of episodes in total, not the number per
round. Fetch lists at least the 40 most recent rounds, keeps completed rounds
at or above `--since`, invokes the supported `uvx coworld@latest replays`
download path, and gets each matching request plus its `artifacts/results`
JSON from the Observatory API. Existing request/result bundles are retained,
so an interrupted fetch can be rerun. The bearer token is read from
`~/.softmax/credentials.yaml` under `https://softmax.com/api` and is never
written to the report.

`mine DIR` recursively finds `.replay` files. For each `ereq_*.replay`, it
accepts either the fetcher's adjacent `ereq_*.json` bundle:

```json
{"round":3649,"round_id":"round_...","request":{},"results":{}}
```

or raw request/results JSON files whose paths contain the same `ereq_...` id.
It prints Markdown to stdout and writes the complete machine-readable form to
`DIR/report.json`; use `--json-out PATH` to put that elsewhere.

The decoder walks the real `COWLDCTF` record stream. An accepted call is the
format-2 `0x10` record, whose canonical `{"plays":[...]}` bytes are preserved
verbatim. Its stored replay milliseconds are converted back to the exact
accepted simulation tick with `ceil(milliseconds * 24 / 1000)`, the inverse of
the engine's `floor(tick * 1000 / 24)`. Death ticks come from `0x11`
`clear-on-death` annotations. The final `0x12` manifest's counts and ordered
SHA-256 chains are verified for every call, annotation, and lobby record before
anything is reported. Replay join tokens are parsed only to advance the
stream; the miner deliberately never retains them.

Kills, team kills, engine score, and the authoritative win bits come from the
results artifact. On one-life BR replays, alive/dead and death tick also come
from the replay, and team placement is reconstructed from the order in which
each duo lost its last member. A winner is the one remaining duo when the
results artifact is absent. Missing request JSON is loud: seats are shown as
`unmatched (<replay display name>)`, calls/deaths still print, and unavailable
combat totals remain `—` rather than being treated as zero.

The current restricted sandbox cannot resolve PyPI or the Softmax/S3 hosts.
On an ordinary shell with network access, the exact recovery commands are:

```bash
cd /tmp/johomax-replay
export PATH="$HOME/.nimby/nim/bin:$PATH"
export UV_CACHE_DIR=/tmp/coworld-replay-uv
analysis/s2_replays.py fetch --since 3630 --limit 200
analysis/s2_replays.py mine research/s2_replays \
  > research/s2_replays/report_3630_3649.md
```
