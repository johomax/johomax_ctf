# The v9 discrepancy, resolved: rebuilds could not throw grenades

The −0.401 K/D floor under every build from this archive (v25/v26/v27 vs the
uploaded v9) was a build-provenance defect, not behaviour, not dependency
versions, and not source drift. One engine commit was lost with `nimby.lock`,
and without it **every rebuilt bot silently lost the ability to throw
grenades** — the champion's headline weapon.

## The mechanism, in four lines of code

The bot presses the grenade button by setting bit 128 of the input mask
(`ButtonC`) and sending it through `inputBlob` → bitworld's
`blobFromSpriteMask`:

| bitworld lineage | `blobFromSpriteMask` | result |
|---|---|---|
| `5d229ac` (branch `daveey/hd-client-pin`) — **the nimby.lock pin** | `result[1] = char(mask and 0xff'u8)` | all 8 bits reach the server |
| `e47559c` (master HEAD, what a plain `git clone` gets) | `result[1] = char(mask and 0x7f'u8)` | **bit 128 deleted from every packet** |

Server-side (`coworld-ctf/src/ctf/sim.nim`, throw handling): `input.c` must
be true to charge and `prev.c` to release. With the bit stripped,
`throwGrenade` is never called — in any episode, for any rebuilt bot. The
packet stays structurally valid, so there is no error, no log line, and no
malformed-protocol disconnect. Just a bot that plans throws forever and never
delivers one.

Master never had the 8-bit mask: commit `a5db801` ("input: eighth button
(ButtonC, bit 128) end to end", 2026-07-14) exists **only** on
`daveey/hd-client-pin`, and its commit body names the consumer — "Games use
it for a fourth action (coworld-ctf: grenade throw)". The CTF authors even
left a standing warning, one day before this archive was written
(`coworld-ctf/src/ctf/server.nim`): *"The pinned bitworld predates it (newer
bitworld drops ButtonC, which the grenade input bit needs), so the id is
declared here rather than imported."*

## Why it was invisible

`bot/baseline.nim` used to declare its own `ButtonC = 1'u8 shl 7` instead of
importing the symbol from `bitworld/spriteprotocol`. Against master — which
has no `ButtonC` — the build therefore compiled cleanly and the truncation
happened one call later. Had the symbol been imported, the follow-up session
would have died on "undeclared identifier: ButtonC" instead of spending a day
measuring a 0.4 K/D ghost. Both guards are now in the tree (see "What was
fixed" below).

## Where the lock went, and where it came back from

The original project was a `Metta-AI/coworld-ctf` checkout (public GitHub)
with this bot at `players/baseline/` — the archive's `diffs/*.diff` headers
say so, and reverse-applying `diffs/baseline.nim.diff` to the archive base
reproduces coworld-ctf's stock bot at commit `5997098` (2026-07-22)
byte-for-byte. That repo's own `/nimby.lock` (unchanged since 2026-07-14) IS
the lost lock: its other 27 lines match bitworld's pins exactly, and its
first line is the one nobody knew to look for:

    bitworld 0.1.0 https://github.com/Metta-AI/bitworld 5d229acd1a5eb311bee831b35dd60e9fc0091cac

`5d229ac` is **not an ancestor of bitworld master** — a default clone does
not even contain it (`git fetch origin daveey/hd-client-pin` first). The
follow-up session cloned master, per the build note it recorded in
`NOTES-shoutintel.md`, and that single substitution is the whole defect.

The lock is restored at `bot/nimby.lock` (byte-for-byte copy).

## What was measured, all local, zero league episodes

Two images, same archive source, same game (coworld-ctf @ `5997098`), same
episode config, one variable — the bitworld commit:

1. **Client counters** (`-d:combatDebug`, slot 0 at tick 1920):
   - pinned: `carry=559 aimed=32 threw=3` — throws release, carrying ends.
   - master: `carry=1269 aimed=591 threw=35` — 35 "releases" and the grenade
     never leaves the bot's hands; it re-aims for a third of the match.
2. **Wire truth** (`scripts/buttonc_probe.nim` over the server-written
   replay, which records the raw inputs the server received):
   - pinned: `inputs_with_ButtonC=38 of 8608`
   - master: **`inputs_with_ButtonC=0 of 8396`**
3. **Compile-time tripwire** (now in `bot/baseline/protocols.nim`): the
   pinned build compiles; the master build fails with "this bitworld strips
   input bit 128".

Magnitude fits the hole: grenades deal 2 of 3 HP through walls and teams
within 52px, and supply ~80 pickups per match against ~7 for everything
else. v9's version-map line is literally "+ grenade memory, friendly-fire
guard, grenade farming — CHAMPION".

The dependency theory (pixie/supersnappy/whisky/curly versions) was checked
first and is **refuted**: the packages on the live decode path have zero
source-file differences between the lock's pins and what `nimble install`
fetches, and the one large delta (pixie 6.0.0 → 6.1.0) sits entirely in code
this bot never executes headless (`receiveLatestFrame(ws, false)` disables
pixel decoding; `loadPalette` is never called). Don't re-spend time there.

## What this invalidates, and what it retro-explains

**Every follow-up upload (v12–v27) was built from this archive against
bitworld master and is grenade-blind.** All follow-up A/Bs were
grenade-less-vs-grenade-less: internally valid, but measured in a different
game — a gun-only meta — and none of their numbers transfer:

- `CTF_LEVER_HOLDLINE` +0.125: holding your half is much cheaper when
  neither side can lob over walls. Must be re-measured on a fixed build
  before it is believed, let alone stacked on v9.
- `CTF_LEVER_NADEDUCK` −0.124 "disengage-and-lob": retro-explained — the
  disengage cost was real, the lob was a no-op. The mechanism was never
  actually tested.
- `CTF_FIX_AIMBAND` +0.072: measured gun-only; plausibly still real (it is a
  defect repair) but the number needs re-confirming.
- The Shout-Intel regressions (v13/v14/v17/v20-v23): same floor on both
  sides. The proposed mechanism (shouting broadcasts position) is
  independent of grenades, but the sizes are unreliable.
- "Grenade farming verified as pickups 4 to 16" passed on broken builds
  because pickup is server-side; only the throw was dead.

The v9/v10/v11 results are untouched — those images were built through the
lock in the original session.

## What was fixed in this archive

- `bot/nimby.lock` — restored (== coworld-ctf `/nimby.lock`).
- `bot/baseline.nim` — `ButtonC` is now imported from
  `bitworld/spriteprotocol`, not redefined: the wrong engine no longer
  compiles.
- `bot/baseline/protocols.nim` — compile-time assert that
  `blobFromSpriteMask` round-trips bit 128, with the fix spelled out in the
  failure message (belt-and-braces for a future master that re-adds the
  symbol but keeps the truncation).
- `bot/Dockerfile.sandbox` — rewritten to the recipe actually verified in
  this sandbox (gcc:12-bookworm base since apt cannot cross the CONNECT-only
  proxy; proxy address as a build arg; builds from `bot/` as context;
  verified end-to-end 2026-07-29 including a full local episode).
- `bot/Dockerfile` — annotated: it is the upstream-layout recipe and needs a
  coworld-ctf checkout as context.
- `scripts/buttonc_probe.nim` — the replay wire-audit used above.

## Local reproduction protocol (no Observatory auth needed)

The game and both engine lineages are public GitHub; the whole proof runs
from source:

1. `git clone https://github.com/Metta-AI/coworld-ctf` and check out
   `5997098` (the archive's fork base; HEAD also works but has moved the
   meta: GV24 aim fuzz, GV25 random respawns).
2. Overlay this archive's bot: `bot/baseline.nim` →
   `players/baseline/baseline.nim`, `bot/baseline/*` →
   `players/baseline/baseline/*`.
3. Build the game and the bot with `nimby --global sync nimby.lock` (the
   repo's lock; in a sandbox see `bot/Dockerfile.sandbox` for the proxy/CA
   incantation, and build with `--network=host`).
4. For the broken variant, rewrite the lock's bitworld line to
   `e47559c90d92ff25c748ecdb41cd5695c10c65b2` (master HEAD as of
   2026-07-24) and rebuild — with the new tripwire this now fails at
   compile time, which is itself the reproduction; to reproduce the
   *runtime* silence, also drop the assert and the import.
5. `coworld run-episode <manifest> <image> -o out -n 1 --timeout-seconds
   400` — the repo ships `coworld_manifest.json`; substitute
   `{{GAME_IMAGE}}` with the local game tag, set
   `certification.game_config = variants[0].game_config` (the shipped
   certification config is a 300-tick smoke, too short to see anything),
   and add a `game.version` field (the current CLI schema requires it).
6. `nim r tools/buttonc_probe.nim out/replay` from the coworld-ctf root.

## CONFIRMED on the Observatory: the pin closes the whole gap

Run 2026-07-29/30 after auth arrived. `jordan-ctf-candidate:v28` is
`ctf-bot:pinned-guarded` — archive HEAD source (v27's source plus the build
guards above, which change no behaviour), built through the restored lock,
uploaded with v27's exact configuration (`CTF_FIX_AIMBAND=0
CTF_FIX_STAREBREAK=0` as secret env; everything else off by default;
`CTF_LEVER_ARCRAID` at its default ON, i.e. v11 config, same as v27).
Both directions vs v9, 40 episodes each
(`xreq_f727811a-68c3-41ca-8813-e35776e47171` pinnedRebuildRed,
`xreq_ee04dc1f-c6a2-4256-8d60-9ab4bec01865` championRed), 80 scored, zero
failures, pooled by `scripts/pool_h2h.py`:

| build | engine | K/D vs v9, pooled both directions |
|---|---|---|
| v27 | bitworld master, no lock | **−0.401**, 95% CI [−0.485, −0.318] |
| v28 | bitworld `5d229ac`, restored lock | **+0.021**, 95% CI [−0.056, +0.098] |

Same source, same config, one variable. The v28 detail: K/D 1.0104 vs
0.9897, win rate 52.5% vs 47.5% (CI [−17.5, +27.5] pts, crosses zero),
captures 16 vs 18 (crosses zero), and each direction's RED won its record
(62.5% and 57.5% — the familiar side effect, no build signal behind it).
That is the same "level" signature the original v11-vs-v9 mirror showed,
which is exactly what a correct rebuild of v11-config source should show.

**The discrepancy is closed.** The archive plus `bot/nimby.lock` is a
faithful champion base again. The interesting next question is re-measuring
`CTF_LEVER_HOLDLINE` (and the aim fixes) on a build that can actually
throw — every follow-up number remains suspect until re-run on this floor.

One more thing the next hosted run will meet: the game itself moved on
2026-07-29 — GV24 fuzzes rendered gun rotation ±20° (breaks the bot's
"bound dead-reckoned aim by own rendered rotation" trick) and GV25
randomises endzone respawns. Those hit both sides of a head-to-head
equally, but absolute numbers against the pinned field will drift, and the
aim-clamp lever (`CTF_FIX_AIMCLAMP`) may now be dead weight — mechanism
before A/B, as always.
