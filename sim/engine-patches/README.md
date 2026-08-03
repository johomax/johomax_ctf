# Engine patches

Speed-only patches `sim/bootstrap.sh` applies to the managed `.engine`
checkout. The glob it applies is `*.patch`, so a file renamed out of that
suffix is parked rather than applied.

`UPSTREAM.md` extracts the hunks worth sending back to coworld-ctf, grouped
as landable PRs, with the adaptations each needs and the dead ends already
measured.

`perf.patch` is armed, rebased from 1047232f (GV30) onto the current pin
63ea0cb7 (GV35) and re-verified there: the six reference seeds (5000-5005)
hash identically with and without it, `selfcheck` passes, and the engine's
own suite passes patched (401 checks). It is worth 10.3x on those six seeds
and 4.7x end to end through `scripts/local_sim.py`; the patch's own header
carries the pass-by-pass argument, what the GV35 split and GV34's ranged
vision cone moved, and the recipe for re-checking the label vocabulary after
a pin move.

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
