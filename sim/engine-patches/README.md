# Engine patches

Speed-only patches `sim/bootstrap.sh` applies to the managed `.engine`
checkout. The glob it applies is `*.patch`, so a file renamed out of that
suffix is parked rather than applied.

`perf.patch.stale-gv30` is parked. It was written against `sim.nim` as one
module and GV30's geometry; the GV35 pin (63ea0cb7) split the engine into
`sim.nim` / `sim_types.nim` / `sim_state.nim` / `sim_config.nim` and moved
every hunk's context, so it no longer applies in either direction. It is
speed-only and was verified gameHash-identical, so parking it costs wall
clock and changes no measurement. Rebase it onto the current pin before
re-arming it, and re-check the six reference seeds (5000-5005) hash the same
with and without.
