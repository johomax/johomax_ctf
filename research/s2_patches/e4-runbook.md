# E4 local Season-2 runbook

Built from local `HEAD` `a9ed25f`:

- `/tmp/e4-bot-head`: unchanged control
- `/tmp/e4-bot-e4-base`: guard-free ladder, base margin 220, partner offset 80
- `/tmp/e4-bot-e4-m120`: same ladder, base margin 120, partner offset 80

The deployed validator rejects literal `duo:<team>` references, so both E4
calls expand the own-duo `target_law.never` entry to the two direct seat refs.

The sandbox did not run these socket-opening commands. Run the two self-mirror
gates first. The expected same-colour kill count is zero; investigate any
non-zero count before spending time on the A/B or starter batches.

```bash
scripts/s2_local.py batch \
  --bot /tmp/e4-bot-e4-base:16 \
  -n 4 --first-seed 1600 --port 2031 --seconds 900 \
  --server /tmp/johomax-ctf-server-runtime2 \
  --engine /private/tmp/engine-main-v40 \
  --config /tmp/johomax-s2-config.json \
  --out episodes/e4-base-self-s1600-n4

scripts/s2_local.py batch \
  --bot /tmp/e4-bot-e4-m120:16 \
  -n 4 --first-seed 1600 --port 2032 --seconds 900 \
  --server /tmp/johomax-ctf-server-runtime2 \
  --engine /private/tmp/engine-main-v40 \
  --config /tmp/johomax-s2-config.json \
  --out episodes/e4-m120-self-s1600-n4
```

Count the partner-kill signature in each self-mirror:

```bash
for run in e4-base-self-s1600-n4 e4-m120-self-s1600-n4; do
  awk -F ' killed by ' '
    NF == 2 {
      victim = $1
      killer = $2
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", victim)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", killer)
      if (victim == killer) {
        print FILENAME ":" FNR ":" $0
        count++
      }
    }
    END { print "same-colour kills:", count + 0 }
  ' episodes/"$run"/seed_*/server.log
done
```

If both gates pass, run the 8/8 candidate-vs-HEAD colour rotations on the same
eight seeds:

```bash
scripts/s2_local.py batch \
  --bot /tmp/e4-bot-e4-base:8 \
  --bot /tmp/e4-bot-head:8 \
  -n 8 --first-seed 1610 --port 2033 --seconds 900 \
  --server /tmp/johomax-ctf-server-runtime2 \
  --engine /private/tmp/engine-main-v40 \
  --config /tmp/johomax-s2-config.json \
  --out episodes/e4-base-vs-head-s1610-n8

scripts/s2_local.py batch \
  --bot /tmp/e4-bot-e4-m120:8 \
  --bot /tmp/e4-bot-head:8 \
  -n 8 --first-seed 1610 --port 2034 --seconds 900 \
  --server /tmp/johomax-ctf-server-runtime2 \
  --engine /private/tmp/engine-main-v40 \
  --config /tmp/johomax-s2-config.json \
  --out episodes/e4-m120-vs-head-s1610-n8
```

Then run each 1/5/5/5 starter screen on the same eight seeds:

```bash
scripts/s2_local.py batch \
  --bot /tmp/e4-bot-e4-base:1 \
  --bot starter:aggressive:5 \
  --bot starter:cautious:5 \
  --bot starter:collaborative:5 \
  -n 8 --first-seed 1620 --port 2035 --seconds 900 \
  --server /tmp/johomax-ctf-server-runtime2 \
  --engine /private/tmp/engine-main-v40 \
  --config /tmp/johomax-s2-config.json \
  --out episodes/e4-base-starters-s1620-n8

scripts/s2_local.py batch \
  --bot /tmp/e4-bot-e4-m120:1 \
  --bot starter:aggressive:5 \
  --bot starter:cautious:5 \
  --bot starter:collaborative:5 \
  -n 8 --first-seed 1620 --port 2036 --seconds 900 \
  --server /tmp/johomax-ctf-server-runtime2 \
  --engine /private/tmp/engine-main-v40 \
  --config /tmp/johomax-s2-config.json \
  --out episodes/e4-m120-starters-s1620-n8
```
