# For agents working in this repository

This is one Nim policy for the Softmax **Paintbot** league
(`league_b8fa9b35-ac22-48cf-a03f-07b397aff1c7`, coworld `paintbot`, engine
[Metta-AI/coworld-ctf](https://github.com/Metta-AI/coworld-ctf)), plus the
tooling to build it, measure a change, and ship it. Read in this order:

1. `README.md` — layout, the build recipes, and the seven measurement rules.
   Numbers that were not measured under those rules are not results.
2. `bot/baseline.nim`'s header — the policy's design, then `bot/baseline/`
   bottom-up (nothing imports upward).
3. `sim/README.md` — the local simulator: the real engine, in process, with
   up to four policy trees per episode. `sim/engine.pin` names the engine
   commit the league runs; move it when the league does, then re-sync
   `bot/baseline/labels.nim` from the engine.
4. `analysis/paintbot.md`, `analysis/br_doctrine.md` — what the game is and
   what wins it. Since 2026-09-01 the league runs the 32-seat
   **battle-royale** variant (`sim/paintbot_br.json`): 16 duos, one life,
   a shrink zone, no flags. League score is the winning duo's Glory; losers
   bank 0. `analysis/br_rounds.py fetch && analysis/br_rounds.py report`
   ranks the live field on it.
5. `research/LEDGER.md` and `research/state.json` — every experiment ever
   run and its verdict. A result nobody wrote down gets run again.

Upstream docs the league points at: the
[Coworld README](https://github.com/Metta-AI/coworld/blob/main/README.md)
(CLI and player contract) and the
[Paintbot README](https://github.com/Metta-AI/coworld-ctf/blob/master/README.md)
→ `docs/RULES.md` (the authoritative rules; a checkout is at `.engine/docs`).
The participate page for the league is
`https://softmax.com/api/observatory/v2/participate?league_id=league_b8fa9b35-ac22-48cf-a03f-07b397aff1c7`.

## Working agreement

- One variable per experiment; verify the mechanism locally before buying
  hosted episodes; both seat directions (or a full colour rotation on
  multi-team boards); a 95% interval that crosses zero is "level", not a win.
- Hosted A/B: `coworld xp-request create <body.json>` targeting the league
  with `variant_id: battle-royale` and a 32-entry roster; keep opponent set,
  episode count and notes comparable between candidate and previous best.
  Never seat a policy against another version of itself.
- Ship: `scripts/build_amd64.sh bot <out>` (static linux/amd64 via nix
  nim+zig; set `CTF_BOT_DEPS=$PWD/.bot-deps`), smoke it under
  `docker run --platform linux/amd64`, upload with
  `scripts/upload_amd64_policy.py`, submit with `--auto-champion always`.
- Commit each landed change with the measurement behind it; record verdicts
  in `research/LEDGER.md`.
- When docs, commands, runtime behaviour, logs or replays disagree, keep the
  evidence and file an issue at https://github.com/Metta-AI/coworld/issues.
