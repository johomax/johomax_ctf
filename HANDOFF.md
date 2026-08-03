# Handoff

State that lives outside the repo and would otherwise be lost. Everything with a
measurement behind it is in `research/LEDGER.md` and `research/state.json`; this
file is only the things a new machine cannot reconstruct.

## Live state

| | |
| --- | --- |
| CTF champion | **v117**, rank 6. Untouched this session; v118 was PROMOTE-LOCAL only. |
| Paintbot champion | **v120**. Nothing has beaten it locally since. |
| CTF league / div | `league_3243d905-...` / `div_37361341-2970-4dac-9528-55398bab0d1a` |
| Paintbot league / div | `league_b8fa9b35-ac22-48cf-a03f-07b397aff1c7` / `div_aa7825db-262f-4a62-b01a-177c1b48f7ee` |
| Campaign standing, r100 | daveey 80, richard 9, us (Jordan) 7, James Botts 4. Third. |
| Our campaign player id | `ply_bcb80069-fb0c-4ba5-a45c-06b647870aeb` |
| Engine pin | `sim/engine.pin` = GV35, coworld ctf v0.7.173 |

10 commits on `main` are **unpushed** as of this file.

## The loop

1. Download replays vs the player ranked just above us. 2. Analyse. 3. Design
experiments. 4. Local A/B. 5. Combine winners, re-verify. 6. Hosted A/B,
**never more than 80 episodes**. 7. If it improves, submit with
`--auto-champion always`. 8. Wait for a round. 9. Goto 1. **10. `/compact`** —
added by the user; run it at the iteration boundary only, never with a
measurement in flight. It cannot be self-invoked (built-in CLI command, the
Skill tool rejects it), so end the iteration by asking the user to run it.

A recurring hourly job fires "update campaign orders based on current
standings". It is machine-local and will not follow to a new host — recreate it
if the campaign work continues.

## Open work

**Task #18 — Paintbot iteration 8: raise our share of the pots that already
resolve.** Do *not* pursue anything that raises the resolve rate: under pot
scoring a resolved episode creates +5 and we collect 34.7%, so finishing is a
public good we buy for the field. That result killed the whole sweep family.
Target instead: conditional on an episode resolving, be the team taking the +4.
`analysis/pb_finish.py` has the winner-finish data. GV32 elimination order may
be an unused target-selection lever.

## Branches, with verdicts

- `axis-frame` — **rejected**, −0.2344 [−0.3458, −0.1201] over 288 seeds once
  rebased so it carried `roles4`. Its `carryHome` fix was extracted to `main`.
- `endgame-sweep` — **rejected**, level at both chase TTL 150 and 400.
- `feature/scaffolds`, `backup-pre-merge-main`, `claude/...autoresearch` — older,
  not part of current work.

## Traps this session actually hit

- **Check a branch's base before comparing it, not after.** One confounded run
  was voided for comparing "branch minus `roles4`" against "tree with `roles4`".
- **README rule 5 is real.** A gap whose CI near-edge sits at −0.07 needs a
  second seed block. Buy it.
- **Campaign: count `transfers`, nothing else.** `winner` is null on conquests
  so it undercounts; `outcome: "conquered"` includes cells that fell to a
  *different* attacker in a contested cell, so it overcounts. A cell is ours
  when a transfer says `to: <us>`. I got this wrong twice in opposite directions.
- **`modes` is a positional list over the 100 cells**, not a dict.
- **The campaign strategist treats any permission as a default.** "daveey is a
  last resort" became "daveey every round". Write hard prohibitions and one
  ranked target list; avoid "prefer X but Y is acceptable".
- **It also cannot reliably turn a player name into a coordinate.** It gets an
  ASCII letter grid; making it quote the grid row and name the letter at its
  chosen column before committing is what produced the only two gains.
- Campaign API: `{server}/api/observatory/v2/leagues/{id}/campaign`, bearer
  token from `~/.softmax/credentials.yaml`. Orders are POSTed to
  `.../campaign/prompt`, max 4000 chars, effective next round.
