# E5 Season 2 local batches

All commands run from `/Users/jordan/Desktop/Projects/johomax/johomax_ctf`.
The self-mirror gate passes only when same-colour `killed by` lines are near
zero across the four games and enemy kills are at least 7.

## Self-mirror mechanism gate (seeds 1400-1403)

```bash
scripts/s2_local.py batch \
  --bot /tmp/e5-bot-e5-sep128:16 \
  -n 4 --first-seed 1400 --port 2041 --seconds 900 \
  --server /tmp/johomax-ctf-server-runtime2 \
  --engine /private/tmp/engine-main-v40 \
  --config /tmp/johomax-s2-config.json \
  --out episodes/e5-sep128-self-mirror-s1400-n4

scripts/s2_local.py batch \
  --bot /tmp/e5-bot-e5-sep200:16 \
  -n 4 --first-seed 1400 --port 2042 --seconds 900 \
  --server /tmp/johomax-ctf-server-runtime2 \
  --engine /private/tmp/engine-main-v40 \
  --config /tmp/johomax-s2-config.json \
  --out episodes/e5-sep200-self-mirror-s1400-n4

scripts/s2_local.py batch \
  --bot /tmp/e5-bot-e5-sym128:16 \
  -n 4 --first-seed 1400 --port 2043 --seconds 900 \
  --server /tmp/johomax-ctf-server-runtime2 \
  --engine /private/tmp/engine-main-v40 \
  --config /tmp/johomax-s2-config.json \
  --out episodes/e5-sym128-self-mirror-s1400-n4
```

Inspect each bot log's `[s2] geo` lines as well as the server kill lines.
`partner_d` should reach the configured separation within roughly 100 ticks
of the first accepted formation call. A missing partner track is logged as
`partner_d=-1 partner_fresh=0`.

## 8/8 colour-rotated comparisons against E4

```bash
scripts/s2_local.py batch \
  --bot /tmp/e5-bot-e5-sep128:8 --bot /tmp/e5-bot-e4base:8 \
  -n 8 --first-seed 1400 --port 2044 --seconds 900 \
  --server /tmp/johomax-ctf-server-runtime2 \
  --engine /private/tmp/engine-main-v40 \
  --config /tmp/johomax-s2-config.json \
  --out episodes/e5-sep128-v-e4-s1400-n8

scripts/s2_local.py batch \
  --bot /tmp/e5-bot-e5-sep200:8 --bot /tmp/e5-bot-e4base:8 \
  -n 8 --first-seed 1400 --port 2045 --seconds 900 \
  --server /tmp/johomax-ctf-server-runtime2 \
  --engine /private/tmp/engine-main-v40 \
  --config /tmp/johomax-s2-config.json \
  --out episodes/e5-sep200-v-e4-s1400-n8

scripts/s2_local.py batch \
  --bot /tmp/e5-bot-e5-sym128:8 --bot /tmp/e5-bot-e4base:8 \
  -n 8 --first-seed 1400 --port 2046 --seconds 900 \
  --server /tmp/johomax-ctf-server-runtime2 \
  --engine /private/tmp/engine-main-v40 \
  --config /tmp/johomax-s2-config.json \
  --out episodes/e5-sym128-v-e4-s1400-n8
```

## Starter field (1/5/5/5)

```bash
scripts/s2_local.py batch \
  --bot /tmp/e5-bot-e5-sep128:1 \
  --bot starter:aggressive:5 \
  --bot starter:cautious:5 \
  --bot starter:collaborative:5 \
  -n 8 --first-seed 1400 --port 2047 --seconds 900 \
  --server /tmp/johomax-ctf-server-runtime2 \
  --engine /private/tmp/engine-main-v40 \
  --config /tmp/johomax-s2-config.json \
  --out episodes/e5-sep128-starters-s1400-n8

scripts/s2_local.py batch \
  --bot /tmp/e5-bot-e5-sep200:1 \
  --bot starter:aggressive:5 \
  --bot starter:cautious:5 \
  --bot starter:collaborative:5 \
  -n 8 --first-seed 1400 --port 2048 --seconds 900 \
  --server /tmp/johomax-ctf-server-runtime2 \
  --engine /private/tmp/engine-main-v40 \
  --config /tmp/johomax-s2-config.json \
  --out episodes/e5-sep200-starters-s1400-n8

scripts/s2_local.py batch \
  --bot /tmp/e5-bot-e5-sym128:1 \
  --bot starter:aggressive:5 \
  --bot starter:cautious:5 \
  --bot starter:collaborative:5 \
  -n 8 --first-seed 1400 --port 2049 --seconds 900 \
  --server /tmp/johomax-ctf-server-runtime2 \
  --engine /private/tmp/engine-main-v40 \
  --config /tmp/johomax-s2-config.json \
  --out episodes/e5-sym128-starters-s1400-n8
```
