# What perf.patch should give back to coworld-ctf

`perf.patch` exists to make the local simulator cheap, but most of its hunks
fix costs the HOSTED server pays too — per-connection work repeated sixteen
times, quadratic sweeps, rasters rebuilt for sends the dedup then drops, and
one genuine memory leak. This file extracts the hunks worth sending upstream
(https://github.com/Metta-AI/coworld-ctf, patch verified at 63ea0cb7 / GV35),
grouped as independently landable PRs, with what each needs adapted and what
was measured so nobody re-measures it.

Ground rules for reading it:

- Every bundle below is **byte-identical on the wire** except bundle G, which
  is inert until a caller opts in. All of it was verified together: identical
  `gameHash` on every config this repo carries (`sim/stock_compare.sh`,
  patched against a pristine checkout), and the engine's own suite passing
  patched (401 checks at this pin).
- The numbers quoted are LOCAL-SIM measurements (headless, fog overlay off,
  one process). Hosted shares will differ — rendering is on, connections are
  real sockets — but every mechanism named is per-connection or per-viewer
  work the hosted server performs more of, not less.
- The `{.measure.}` marks scattered through the patch are profiling
  annotations for bitworld/profile. Harmless to keep, trivial to strip;
  they are not part of any candidate.

## The one adaptation every stateful bundle needs

`sim_types.nim` states that `SimServer` is flatty-serialized POSITIONALLY
into replay keyframes. The patch adds five fields to it (`gameId`,
`stainEpoch`, `fovShadowCache`, `fovChangedCells`, `diamondStamps`) and grows
`PlayerFov`, so a keyframe written by a patched engine reads back only in a
patched engine. This repo never records replays, so the patch just accepts
that; upstream cannot. Landing bundles B, D, E or F upstream means either
excluding the cache fields from serialization (they are all reconstructible —
every one is a pure-function cache or an epoch counter) or taking a
GameVersion bump. That decision is upstream's and gates nothing else here.

Three pieces of shared infrastructure travel with more than one bundle:

- `memoized` (sim_types.nim) — the lookup-or-build template every raster
  cache uses. Lands with the first of B/E/F.
- `spriteDefinitionIndex` bisect + `insertDefinition` (bundle A) — later
  bundles assume def lookups are cheap, but do not require it.
- `knownTextDefSize` (bundle C) — the "would the dedup drop this send"
  predicate the gating bundles are built on.

## A — wire encoding and small sweeps (global.nim, roster.nim)

No new state that reaches a replay, no behaviour surface, each hunk local.

- **Sprite-def cache bisect.** `spriteDefinitionIndex` linearly scanned a few
  hundred heap refs and is called from every emitter; summed over its callers
  it was the single dearest line of the observation build. Kept sorted by
  spriteId (`insertDefinition`) and bisected. All four insertion sites at
  this pin go through `insertDefinition` — an unsorted append breaks the
  bisect for every emitter, so the sweep for insertion sites must be redone
  on whatever commit this lands on.
- **`addBoardObject` encodes in place.** The `addObject` path is six
  cross-module calls with a `setLen` each, paid per object per viewer per
  frame; now one `setLen` plus twelve byte stores, bottoming out in the same
  `copyMem`.
- **Object-delete sweep.** `notin` over a seq made it quadratic in the object
  count (~300 ids per viewer per frame with fog runs). Player stream: a
  generation stamp per object id (`idStamp`/`idGen` on the viewer state).
  Board stream: `toHashSet` once per frame.
- **`teamForSlot` reads in place.** Binding the slot copied its two string
  fields; `slotIdentityIndex` fans it out O(order) per identity badge.
- **Self-marker def gate.** The outlined self sprite was re-rasterized every
  frame per viewer — ~41% of a headless tick at GV27, and it is per-viewer
  work on a hosted server too — only for `addSpriteChanged` to dedup the
  send. Gated on the def-exists check, as is the spinning diamond's
  cached-pixel copy (~14%).
- **`currentIds` presized** to last frame's object count.

## B — memoize the pure rasters (global.nim, rig_art.nim)

Every one is a pure function of a small key that each of the sixteen
connections rasterized independently. Needs `memoized`; the diamond cache
needs `gameId`/`stainEpoch` (see the adaptation note).

- **`loadRgbaSprite`**: each connection re-read and re-decoded the same
  pickup PNG from disk (~10 ms per sprite family, per connection).
- **Cosmetic builders**: hp bar, identity badge, tracer dot/head, splatter,
  hit spark, floating pop — the tracer pair built eagerly as call arguments
  the def dedup then discarded. Memoized process-wide; keys are their full
  argument lists, all game-bounded.
- **Shout bubble (1x pixel variant)**: had no cache while its supersampled
  sibling did. Bounded like its sibling (`ShoutBubbleCacheMax`) because the
  key carries policy-chosen text — churn drops the table rather than growing
  it.
- **Painted diamonds**: every viewer rasterized the repainted stone per spin
  advance — stain composited per pixel, per stain, per spin step, ~680 ms of
  a 1.28 s trace. Pure in (diamond's stain list, frame, boardScale); within
  one (gameId, stainEpoch) the APPEND-ONLY stain list is pinned by its
  length, so `paintCount` closes the key. `stainEpoch` bumps exactly where
  the stain lists reset (startGame / resetToLobby) and is never hashed.

## C — do not rasterize what the dedup will drop (global.nim)

The recurring defect, found five separate times: an emitter builds a raster
as the eagerly evaluated argument of a send whose (id, dims, label) dedup
then drops it. The fix is one predicate plus one call shape:

- **`knownTextDefSize(defs, spriteId, label, scale)`** — the dedup asked
  ahead of time. Sound wherever the label determines the pixels, which is
  true of rendered text and equally of an hp bar or a badge. The `scale`
  divide is exact by construction (`addBoardSpriteChanged` stores
  `width * boardScale`), and upstream's own `tests/test_damage_pop.nim`
  builds a board packet at RenderScale, so a mis-divide fails their suite.
- **`addBoardSpriteGated`** — `addBoardSpriteChanged` with the raster taken
  `untyped`, evaluated only on the branch that ships it. The gate lives
  INSIDE the send, not at the emitters, deliberately: an emitter-level `if`
  is one a later edit can slide `currentIds.add` into, which renumbers the
  object pool — the object stream must never be a function of what gets
  rasterized. This invariant is documented at the template and is the part
  most worth carrying upstream verbatim.
- **Takers**: `addShouts` (the largest — a bubble stays up for ShoutTicks and
  every viewer in earshot rebuilt it every frame; ~15% of a Paintbot `4ffa`
  tick's instructions), `addHpPips`, `addIdentityBadges`, `addSplatters`,
  `addDamagePops` (reads its placement dims off the def, since the label
  fixes the pixels), and the lives / weapon / team-scoreboard HUD text.
- **The unfinished twin, only upstream can land**: `addBoardShouts`, the
  broadcast-view sibling, has the same defect and would take the same gate —
  its zoomed variant returns a full raster copy k² the 1x area, per bubble
  per frame. This repo never builds a board stream, so no local gameHash can
  verify it, and the patch's rule is that a hunk is only allowed to be fast
  when a hash says it changed nothing. Upstream has the board stream and its
  tests; `knownTextDefSize`'s `scale` parameter was written for exactly this.

## D — per-connection and per-episode setup computed once (global.nim, sim.nim)

- **Init snapshot cache.** `buildSpriteProtocolPlayerInit` names no player,
  yet every connection rebuilt it: ~58 ms each of map raster + compression,
  flag sprites, the soldier pool — about a second per sixteen-seat episode.
  Cached per (gameId, tick); sibling connections copy, defs included. The
  cache-hit path requires an empty def cache and falls back to a plain build
  otherwise, so an unexpected caller costs a redundant rebuild, never a
  wrong packet.
- **Static assets once per process.** Fonts, palette, sprite sheet, crew
  sprites are files on disk, identical for every game a process runs.
- **`MapBake`.** The art bake plus three per-pixel passes over the board plus
  `buildFovBlocked` are a pure function of the resolved `CtfMap`, ~430 ms
  paid per episode. Cached on the map BY VALUE, so a generated-terrain draw
  that differs rebuilds — the cache can miss but cannot be wrong about which
  map it holds. Marginal setup per episode fell ~1.16 s → ~0.05 s. Pays for
  any process that runs more than one game (lobby cycles, tests, replay
  tooling); needs `gameId`.

## E — fog and the shadowcast (sim.nim, sim_types.nim)

The largest bundle, and the one carrying its own audit. All of it is
byte-identical on the wire: the ulp discipline throughout is that no
comparison is restated in a cheaper form, because one flipped fog cell is a
different episode.

- **One cone expression.** `FovCone` holds what the cone loop used to hoist
  out of itself; `keeps(cone, cell)` is THE test — the whole-grid pass and
  the single-point query both call it, so they cannot drift by an ulp. Cone
  geometry (vx/vy/d2/sqrt) is tabulated per grid size; the same IEEE sqrt of
  the same value gives the same bits. The sqrt is skipped when `dot < 0`
  already decides.
- **Per-origin-cell shadow cache with EXACT invalidation.** The
  aim-independent shadowcast is pure in (fovBlocked, origin), so a viewer
  that only turned re-uses it, and viewers share entries (`FovShadow` refs).
  `refreshFovCells` records which occlusion values actually FLIPPED, and
  `applyDiamondGeometry` drops precisely the cached shadows that lit a
  flipped cell — exact, not heuristic, because `castFovOctant` reads exactly
  the cells it lights. A cast that never reached the diamonds keeps its
  cache where upstream recomputes the identical grid.
- **The cache bound is a leak fix, not a speedup.** `fovShadowCache` holds
  one entry per origin cell ever stood on, forever. Invisible on the arena
  (13 kB/entry, small grid); on a `4ffa8`-class generated board it grew
  ~0.19 MB/tick — 707 MB by tick 2000, ~1.6 GB by the 7500-tick cap, per
  process. `FovShadowCacheBytes` (48 MB) bounds it in bytes; full drops the
  table whole, which is behaviour-neutral by construction since every entry
  is a pure function. 707 → 454 MB at tick 2000, wall clock unchanged. **A
  hosted Paintbot server on generated terrain has this leak today**; this
  hunk is worth upstreaming even if nothing else is.
- **The cast stops at the vision range.** GV34 capped the cone at 1.5x gun
  range, yet the cast still walked rows to the grid edge lighting cells
  `keeps` then discarded. `fovReach` is the single statement of how far any
  term of `keeps` can accept; `fovShadowRows` converts it to a row bound in
  CELL space — integer reasoning, deliberately not derived from the same
  `rangeSq` the cone compares, so there is no ulp boundary to disagree
  across. Inert where reach outruns the board (the arena); the whole point
  on big generated maps.
- **`castFovOctant` takes its octant transform as static parameters.** That
  is what lets the cell index become a running sum (in every octant
  (xx, yx) is a unit vector, so the flat index advances by a constant
  stride), the row's in-grid span become an interval that BOUNDS the walk
  rather than filtering it, and the second slope division be skipped on the
  prefix the start bound discards. The arithmetic is upstream's operand for
  operand. 1.265 G → 0.677 G instructions over a 400-tick `4ffa` window.
- **The audit ships with it.** The span bound is the one hunk whose
  correctness is an argument (two monotone slope tests) rather than a
  rearrangement, so `-d:fovSpanAudit` runs the same proc both ways — span
  walked, and whole-row-filtered, upstream's shape — and requires identical
  lit cells. One implementation, no second copy to drift; a pure observer
  (audit builds hash identically); known to be able to fail (narrowing the
  span by one cell trips it, naming the origin and cell).
- **Lazy visibility grid — worth taking, with honest expectations.**
  `refreshPlayerFov` now updates shadow + cone and stops;
  `ensureFovVisible` materializes the grid, `fovVisibleAt` answers point
  queries from `shadow[cell] and keeps(cell)`. On a hosted server the fog
  overlay runs every frame, so the grid is still built exactly when it
  always was — the hosted win is the cone pass walking the shadow's lit-cell
  list instead of sweeping all ~12.9k cells, plus the shared shadow cache
  above, not the grid elision itself. (The elision pays fully only behind
  bundle G.) Both fov accessors take `var SimServer` so reaching the grid
  builds the grid — a later reader cannot land on an unfilled `visible`.
- **Fog-run emit caching.** The run list is a pure function of the
  visibility grid, cached and rebuilt only when the fov actually changed;
  the run scan reads 8 cells per `uint64` where runs are uniform; the object
  block (~150 objects per viewer per frame) is pre-encoded once and
  re-appended as one memcpy, with per-connection def tracking
  (`fogWidthsSeen`) reduced to a subset test. Note `set[uint16]`, not
  `uint8`: GV31's colossal maps put run widths past 255.

## F — the diamond restamp (sim.nim, map_art.nim, sim_types.nim)

Invisible to a `{.measure.}` profile and found by callgrind: the restamp —
`stampDiamondPatch`, `rotatedDiamondCovers`, `refreshFovCells` — was 20% of a
tick's instructions, larger than the shadowcast, and it runs on the hosted
server every four ticks forever.

- The stone a window writes is pure in (baseWall, the diamonds sharing the
  window, their frames), and a diamond only ever visits `DiamondSpinFrames`
  angles: cached per (window, folded frame vector) as the two masks
  (`DiamondStamp`), so a match rasterizes each window sixteen times total
  instead of ~4k pixels of trigonometry every four ticks. A restamp is now
  `h` pairs of memcpy. The frame vector folds into an int64; a window shared
  by more than `DiamondStampGroupMax` diamonds computes uncached rather than
  risking a key collision, and a `static:` assert fails the BUILD if
  `DiamondSpinFrames` ever grows past what the fold can hold.
- `refreshFovCells` counts wall pixels eight at a time out of a `uint64`
  (bools are exactly 0/1, so `(wall and not window) * 0x0101...01 shr 56`
  sums the bytes). Same count, same pixels.
- Together: 4.75 billion instructions per episode down to 0.50.
- Depends on bundle E's `fovChangedCells` only for the exact-invalidation
  half; the stamp cache itself stands alone with `diamondStamps` on the
  server.

## G — the headless observation hook (global.nim), a feature, not a fix

Different character from everything above: `spriteObservedHook` is nil by
default and every hosted server, replay and test emits byte-for-byte what it
always did. A headless host installs a predicate naming the sprite labels
its reader can use, and definitions nobody can read stop being rasterized,
upscaled, compressed and shipped — the single largest reason the local
simulator is 10.3x faster than stock. Upstream's own RL-training and
evaluation loops are the same shape of consumer, which is why it is offered.

What makes it sound, and must travel with it:

- Suppression drops the DEFINITION send while updating `spriteDefs` exactly
  as if it had been sent, so every dedup and def gate branches identically;
  objects are still placed, and the client already drops an object whose
  sprite is undefined.
- THE OBJECT STREAM IS NOT A FUNCTION OF THE PREDICATE. An emitter that
  skipped a whole item would renumber the object pool — invisible to any
  hash while a family is uniformly unread, and a static obstacle vanishing
  mid-episode the moment it is not. Emitters gate rasters only;
  `addFogRuns` is the lone exception (it may skip its objects too) and earns
  it structurally: it emits exactly one label, so its skip cannot be
  partial.
- `-d:dumpLabels` is the verification tool: dump the wire vocabulary with
  the hook off, classify with the consumer's own predicate, and require the
  difference to be exactly the unread families.

## Measured dead ends — do not retry these upstream

- **Memoizing `spriteObserved`.** A `Table[string, bool]` in front of it
  measured SLOWER (0.72 → 0.76 ms/tick): a hash probe hashes the string and
  compares on hit, no cheaper than the switch Nim compiles `classify` into.
  Keying on sprite id is unavailable — one painted-diamond id carries many
  labels.
- **Keying the shadow cache on diamond angle** (entries become inapplicable
  rather than stale): 1.035 → 1.065 ms/tick. Viewers keep entering cells
  nobody has stood in at this angle, so the reuse is not there to collect.
- **`memoized` returning `lent`** to make hits copy-free: priced after
  bundle C's gates and the remaining hits land only on def changes, so the
  prize is now small.

## What is deliberately NOT here

The policy-side passes (`bot/baseline/grid.nim`, `navgrid.nim`,
`geometry.nim`, `fov.nim`) and the driver-side work (`sim/simulate.nim`'s
`parseConfig`, seed batching, `build.sh`'s warm nimcache, worker-per-core)
are this repository's code, not the engine's — nothing to upstream. The
`sim/` harness itself (hosts, seat assignment, gameHash) is likewise local.

## Cutting the PRs

The patch applies clean to 63ea0cb7. To extract a bundle: apply the whole
patch to a checkout, revert the hunks of the other bundles (`git add -p` in
reverse), and diff. Order A → B → C → D independently; E before F if taking
F's exact invalidation; G last and optional. Per-bundle verification is what
this repo already runs, and all of it transfers: the engine suite
(`nim c -r -d:release tests/tests.nim`, 401 checks at this pin),
`sim/stock_compare.sh` from a consumer of the pinned engine (every bundle
must hold gameHash identical against pristine), and `-d:fovSpanAudit` for
bundle E. The replay-keyframe decision from the adaptation note above is the
one question to settle with upstream before B/D/E/F.
