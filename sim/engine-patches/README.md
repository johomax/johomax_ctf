# Engine patches

Speed-only patches `sim/bootstrap.sh` considers for the managed `.engine`
checkout. The glob is `*.patch`; an incompatible patch is skipped loudly, and
a file renamed out of that suffix is parked.

`perf.patch` awaits a rebase from its GV35 base (63ea0cb7) to the current
GV50 pin (9d26cc26). Its arena.nim, global.nim, map_art.nim, sim.nim, and
sim_types.nim hunks do not apply there. `bootstrap.sh` therefore prints a
prominent warning and leaves the managed checkout on the stock pinned engine;
correctness is unchanged, but simulation is slower. The last verified version
was bit-identical on `gameHash` for seeds 5000-5005 of `league_config.json`.

Its seventh pass is the first aimed at the **Paintbot** boards rather than
the arena, and was re-verified the same way there: identical `gameHash` on
`paintbot_{default,2v2,4ffa,4ffa8}` as well as `league_config`, patched
against a stock unpatched checkout.

Re-run that comparison whenever the pin moves or a hunk changes — it is
`sim/stock_compare.sh`, which builds the simulator against `.engine` and
against a pristine copy of the same commit with this patch reverted, runs
every config through both, and fails on the first differing `gameHash`. It
used to be a manual ritual, which is how a claim like this quietly ages.
Nothing here is allowed to be fast on the strength of looking harmless: the
fifth pass deliberately shortens the packet, so bit-identical `gameHash` is
the only thing standing between it and a silently different measurement.
