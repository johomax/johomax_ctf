# Stock reference adapter

This tree seats the engine's own `players/baseline/baseline.nim` in the local
simulator. `stockbot.nim`, `stockprotocols.nim`, and `stocktaunts.nim` are
generated upstream copies; the other Nim modules adapt them to `sim/host.nim`.
Artifact telemetry is replaced by no-ops, so simulator builds neither write
artifacts nor link libcurl.

Re-sync after moving the engine pin:

```bash
sim/stock/sync.sh
```

At the GV50 engine pin the walkability mask is emitted only to sprites-off
(policy) viewers; `sim/simulate.nim` passes `spritesOff = true` for every
seat, which is also what every league bot negotiates on the real wire.

The adapter preserves per-seat RNG and multi-team geometry that upstream keeps
as one-process globals. It intentionally accepts every sprite label because the
stock bot scans dynamic label families. Transport timing, dropped frames, and
the other simulator gaps in `sim/README.md` still apply.
