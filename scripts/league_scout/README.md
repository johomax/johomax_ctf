# league_scout — read the field out of free public replays

Every completed league round holds ~240 episodes whose replays are public,
downloadable without auth, and re-simulable to ground truth. This reads them.

Produced `research/REPLAY_SCOUT_2026-07-31.md`; the raw output of one full run
is checked in beside it as `REPLAY_SCOUT_2026-07-31_output.txt`.

| script | what it does |
|---|---|
| `ctfapi.py` | `/v2` helper — token from `softmax exchange-code` / `softmax login`, retry with backoff |
| `index_eps.py` | recent completed rounds → episodes, cached JSON |
| `form.py` | current-form W/L and the H2H matrix, from episode `scores` |
| `fetch_replays.py` | download the replays worth reading (public S3) |
| `corpus.py` | decode the frame stream + event stream, keyed to the player who held each seat |
| `analyze.py` | per-player profile: combat, flag play, positioning, shouts, pickups |
| `analyze2.py` | how episodes END (capture/wipe/timeout), shout decode, death profile, shield uptime |
| `analyze3.py` | shout code fitting, earshot, command-channel effect |
| `analyze4.py` | focus fire and per-seat role profile |

## Run it

```sh
pip install numpy 'coworld[auth]'
softmax exchange-code <code>          # or: softmax login
python index_eps.py 6                 # 6 most recent completed rounds
python form.py
python fetch_replays.py
```

Then build `extract_events` once from a **coworld-ctf checkout at the same
GameVersion the replays carry** and run it over the corpus:

```sh
cd <coworld-ctf>
nimby use 2.2.10 && nimby sync -g nimby.lock
nim c -d:release --hints:off -o:bin/extract_events tools/extract_events.nim
ls ~/.ctf/scout/replays/*.replay | xargs -P 8 -I{} sh -c \
  'b=$(basename {} .replay); bin/extract_events {} \
     --out ~/.ctf/scout/ev/$b.jsonl --frames ~/.ctf/scout/fr/$b.bin'
```

```sh
python analyze.py && python analyze2.py && python analyze3.py && python analyze4.py
```

## Gotchas this encodes — do not relearn them

- **`limit=1000`, always.** `/v2/rounds/{id}/episodes` defaults to `limit=50`;
  a round holds ~240. The default truncates silently.
- **Read the seats out of the episode, never out of the arm name.** Every
  number here is keyed through `participants[].player_name`. `daveey`'s policy
  is *named* `ctf-focusfire` and measures the least focused in the corpus.
- **Seat parity is the team.** Even seats spawn left (RED), odd spawn right
  (BLUE); API `position` == replay join slot. Verified against spawn
  coordinates, not assumed.
- **Fold x into "advance"** (0 = own pedestal, 1 = enemy pedestal) or RED and
  BLUE numbers are not comparable.
- **`damage` carries its victim in `target`.** The `damages[]` array is only
  populated for multi-victim weapons (grenade, spray); reading only `damages[]`
  silently drops every gun hit.
- **`Heal` records the healed player in `source`, not `target`.**
- **A replay only re-simulates on the engine that recorded it.** Check the
  replay's `gameVersion` (the extractor's summary row reports it) against the
  checkout. Do not "fix" a mismatch by overriding `GameVersion` — that trades a
  clean refusal for a hash mismatch at tick 1.
- **The leaderboard `win_rate` is cumulative** over a policy slot's whole
  history and blends every predecessor version. Use `form.py`.
