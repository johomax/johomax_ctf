# Auto-research ledger

Every experiment the loop has run, in order, with the request ids behind each
verdict. Written by `scripts/autoresearch.py`; see that file for the rules a
verdict is reached under, and README.md for why those are the rules.

A gap is always (treatment - control) and always pooled over both directions of
a mirror that ran at the same moment. "level" means the 95% bootstrap interval
crosses zero, which is a result: it says the change is not worth shipping, not
that the run failed.

The sections below the divider are appended by the loop. Anything above it was
run by hand to set the loop up, and is recorded here for the same reason the
loop records its own: a measured result nobody wrote down gets measured again.

## gen0 — is this tree still the champion?

`jordan-ctf-candidate:v48`, a fresh build of HEAD (`a33fc9b`-era `bot/`),
against the shipped champion `jordan-ctf-candidate:v45`. Both directions,
40 episodes a side, 0 skipped.

- requests: `xreq_b3566f7c`, `xreq_0cfc7db0` (confirmation: `xreq_25697d8d`,
  `xreq_804d8eea`)

| | v48 (tree) | v45 (champion) |
|---|---|---|
| K/D | 0.9887 | 1.0115 |
| kills / deaths | 1749 / 1769 | 1756 / 1736 |
| captures | 13 | 12 |
| wins | 32/80 (40.0%) | 47/80 (58.8%) |

- K/D gap **−0.0228**, 95% CI [−0.0956, +0.0518] — crosses zero
- Win-rate gap **−0.188**, 95% CI [−0.400, **+0.025**] — crosses zero, barely
- Capture gap **+1**, 95% CI [−9, +11] — crosses zero

Nothing separated, but the win-rate interval only just included zero and the
sign was not a side artifact: v45 won on both sides. That is rule 5's case
exactly — an interval that nearly touches zero buys episodes rather than a
verdict — so a confirmation mirror was run and pooled with it.

### Confirmed at n=160: LEVEL

| | v48 (tree) | v45 (champion) |
|---|---|---|
| K/D | 0.9893 | 1.0109 |
| kills / deaths | 3502 / 3540 | 3529 / 3491 |
| captures | 28 | 27 |
| wins | 69/160 (43.1%) | 86/160 (53.8%) |

- K/D gap −0.0216, 95% CI [−0.0697, +0.0272]
- Win-rate gap **−0.106**, 95% CI [−0.256, +0.044]
- Capture gap +1, 95% CI [−14, +15]

The win-rate gap moved **toward** zero as episodes were added, −0.188 to
−0.106, and its interval pulled clear of zero rather than closing on it. That
is what noise does; a real effect resolves the other way. **The tree is level
with the shipped champion**, and this is the fourth time in this repository's
record that a marginal call at 80 episodes has evaporated at 160.

The scare was still worth what it cost. It made the difference between
"beats the tree" and "beats the league" concrete, and the loop gained a
champion gate as a result: screening runs against the tree, because that is
what isolates one variable, but shipping is decided by one more mirror against
the champion. That distinction does not depend on gen0's answer — it becomes
real the moment anything lands in the tree that the league has not seen.

## The refactor arms, created last session and never read

`5814d5e` recorded two request ids for the pre-split/post-split validation and
no verdict. The episodes were already bought, so they were pooled here for
free: **v47 (post-split) vs v46 (pre-split), 80 episodes, 0 skipped.**

- K/D gap −0.0615, 95% CI [−0.1285, +0.0045]
- Win-rate gap −0.062, 95% CI [−0.275, +0.150]
- Capture gap +1, 95% CI [−10, +11]

All three cross zero. The split is not measurably a regression, and a
line-level comparison agrees: normalising export markers and the locals that
became `Frame` fields, the pre-split file loses 22 lines against the modules
and every one of them is an import, a `let`/`var` block keyword, or a
declaration that moved into the `Frame` type. No logic line is missing, and
1 of 89 shared procs differs — `decide`, which became the stage dispatcher.

So the split is clean. Between the shipped champion and this tree that leaves
the fold (`0a3e922`) and `f590681`, neither measured against v45 — and with
gen0 confirming level at n=160, neither needs to be: whatever they changed,
the sum of it is not separable from the champion.

`f590681` is still worth one experiment on its own merits. GV25 made the
respawn ground a zone, so the single virtual threat at the enemy pedestal
became `EnemyRespawnSamples` points down their endzone column, and three
permanent threats cost more ground than one. That is a routing change nobody
has measured in either direction. `respawnsamples1` asks it.

---

## holdline4 — REJECT

- when: 2026-07-30T22:30:54+00:00
- change: `HoldLineKills` -> `4`
- treatment: `jordan-ctf-candidate:v49`  control: `jordan-ctf-candidate:v48`
- requests: `xreq_e070e70d-a849-410f-9589-3562cec9950d`, `xreq_8f0d005b-4c65-49d4-a55c-f2f6d1c985fe`
- verdict: level: K/D +0.0295 CI [-0.0410, +0.1008], win rate +0.075 CI [-0.138, +0.287], captures +2 CI [-9, +13], n=80
- pooled: 80 episodes, 0 skipped; RED won 68.8% of episodes
  - `jordan-ctf-candidate:v48`: K/D 0.9853 (1744/1770), captures 15, wins 36
  - `jordan-ctf-candidate:v49`: K/D 1.0148 (1777/1751), captures 17, wins 42
- rationale: The wave holds its own half until six enemy deaths, two players' worth of lives out of 24. The threshold has never been swept. Four commits the push a third earlier, which is either a faster capture clock or a wave that walks into a healthy defence.

## respawnsamples1 — REJECT

- when: 2026-07-30T23:18:55+00:00
- change: `EnemyRespawnSamples` -> `1`
- treatment: `jordan-ctf-candidate:v50`  control: `jordan-ctf-candidate:v48`
- requests: `xreq_27579a15-09d8-4521-adb3-b8ebc9d9a256`, `xreq_5a2772de-279f-48d1-a517-6d7fcd253045`
- verdict: level: K/D -0.0578 CI [-0.1177, +0.0022], win rate -0.150 CI [-0.362, +0.062], captures +2 CI [-9, +13], n=80
- pooled: 80 episodes, 0 skipped; RED won 60.0% of episodes
  - `jordan-ctf-candidate:v48`: K/D 1.0294 (1785/1734), captures 15, wins 44
  - `jordan-ctf-candidate:v50`: K/D 0.9716 (1745/1796), captures 17, wins 32
- rationale: `f590681` replaced the single virtual threat at the enemy pedestal with three samples down their endzone column, to match GV25 making the respawn ground a zone rather than a point. The geometry is right and the routing consequence has never been measured in either direction: three permanent threats cost more ground than one, and this repository's one standing finding about perception is that every intel addition made the bot more timid and deaths rose. One sample is the pre-GV25 behaviour on the post-GV25 code path, which asks the timidity question without reopening the geometry one.

## latepush3000 — REJECT

- when: 2026-07-30T23:20:52+00:00
- change: `LatePushTick` -> `3000`
- treatment: `jordan-ctf-candidate:v51`  control: `jordan-ctf-candidate:v48`
- requests: `xreq_54a411ca-9ad9-4e1e-ae79-e1d12b49d02e`, `xreq_87091daf-8f79-4254-8fe7-af3282e0e673`
- verdict: level: K/D +0.0160 CI [-0.0594, +0.0921], win rate +0.113 CI [-0.100, +0.325], captures +4 CI [-5, +13], n=80
- pooled: 80 episodes, 0 skipped; RED won 67.5% of episodes
  - `jordan-ctf-candidate:v48`: K/D 0.9920 (1747/1761), captures 9, wins 35
  - `jordan-ctf-candidate:v51`: K/D 1.0080 (1757/1743), captures 13, wins 44
- rationale: Past LatePushTick a draw is the default outcome, so the posts break and everything commits to the capture. A draw scores as badly as a loss and the game hard-stops at 5000, so 3400 leaves 1600 ticks of all-in play. Starting 400 ticks earlier buys another capture attempt at the cost of holding the line longer.

## jinkengaged — REJECT

- when: 2026-07-30T23:22:55+00:00
- change: `baseline/act.nim`: `if bot.stuckTicks > 20 and f.engage < 0:` -> `if bot.stuckTicks > 20 and (f.engage < 0 or bot.stuckTicks > 60):`
- treatment: `jordan-ctf-candidate:v52`  control: `jordan-ctf-candidate:v48`
- requests: `xreq_cf676874-cece-4539-bc72-661cc087b9cb`, `xreq_30e2acf9-fe6d-4413-8df4-7519e0d8d73f`
- verdict: level: K/D +0.0114 CI [-0.0665, +0.0904], win rate +0.000 CI [-0.225, +0.225], captures -1 CI [-11, +9], n=80
- pooled: 80 episodes, 0 skipped; RED won 67.5% of episodes
  - `jordan-ctf-candidate:v48`: K/D 0.9943 (1754/1764), captures 13, wins 40
  - `jordan-ctf-candidate:v52`: K/D 1.0058 (1749/1739), captures 12, wins 40
- rationale: The unstick burst is gated `stuckTicks > 20 and engage < 0`, so while a target is held the burst is disabled and anything that pins the bot keeps it pinned for the rest of the fight. This is the second of the two causes of staring contests identified in the archive and the only one never touched. Letting the burst fire while engaged after 60 pinned ticks trades a settled aim for movement, and 60 ticks is long enough that a legitimate hold-and-shoot never reaches it.

## respawnsamples1-reverse — REJECT

- when: 2026-07-30T23:58:36+00:00
- change: `EnemyRespawnSamples` -> `5`
- treatment: `jordan-ctf-candidate:v53`  control: `jordan-ctf-candidate:v48`
- requests: `xreq_6e00f29c-b3f0-4692-bb28-24f915441a66`, `xreq_e938e301-a16d-4f6b-821d-649f05de18ed`
- verdict: level: K/D +0.0046 CI [-0.0574, +0.0662], win rate +0.025 CI [-0.188, +0.237], captures +1 CI [-9, +11], n=80
- pooled: 80 episodes, 0 skipped; RED won 68.8% of episodes
  - `jordan-ctf-candidate:v48`: K/D 0.9977 (1759/1763), captures 14, wins 38
  - `jordan-ctf-candidate:v53`: K/D 1.0023 (1757/1753), captures 15, wins 40
- rationale: Derived from respawnsamples1: EnemyRespawnSamples measured worse at 1, so the constant is worth testing in the other direction at 5.

## leadticks8 — REJECT

- when: 2026-07-31T00:00:33+00:00
- change: `LeadTicks` -> `8.0`
- treatment: `jordan-ctf-candidate:v54`  control: `jordan-ctf-candidate:v48`
- requests: `xreq_81230606-dd75-4cb3-a085-8d05b5726f83`, `xreq_d1cc8be0-6010-4449-b528-d8e276490480`
- verdict: level: K/D -0.0342 CI [-0.1115, +0.0410], win rate +0.100 CI [-0.125, +0.325], captures +6 CI [-4, +16], n=80
- pooled: 80 episodes, 0 skipped; RED won 72.5% of episodes
  - `jordan-ctf-candidate:v48`: K/D 1.0172 (1771/1741), captures 10, wins 36
  - `jordan-ctf-candidate:v54`: K/D 0.9830 (1737/1767), captures 16, wins 44
- rationale: The aim leads a moving enemy by six ticks to cover the five-tick windup. That accounts for the windup and nothing for the traverse the turret still has to make at 5 brads/tick, so the lead is arguably a tick or two short on anything crossing.

## fireslack13 — REJECT

- when: 2026-07-31T00:02:36+00:00
- change: `FireSlackPx` -> `13.0`
- treatment: `jordan-ctf-candidate:v55`  control: `jordan-ctf-candidate:v48`
- requests: `xreq_7c849cb7-3287-40ea-92c7-8b49cd9917c2`, `xreq_a9e9853a-e555-40ea-86f1-9cd52d4d81f5`
- verdict: level: K/D +0.0160 CI [-0.0575, +0.0923], win rate -0.013 CI [-0.225, +0.212], captures -1 CI [-11, +9], n=80
- pooled: 80 episodes, 0 skipped; RED won 68.8% of episodes
  - `jordan-ctf-candidate:v48`: K/D 0.9920 (1742/1756), captures 13, wins 40
  - `jordan-ctf-candidate:v55`: K/D 1.0080 (1766/1752), captures 12, wins 39
- rationale: The fire gate demands the aim error's perpendicular miss be inside 11px when the corridor is ~14px wide. That 3px of margin is bought with shots not taken; at 13 the gate still sits inside the corridor but the bot shoots sooner in a traverse.

## leadticks8-reverse — REJECT

- when: 2026-07-31T00:42:22+00:00
- change: `LeadTicks` -> `4.0`
- treatment: `jordan-ctf-candidate:v56`  control: `jordan-ctf-candidate:v48`
- requests: `xreq_8603733a-ea66-441b-bdd3-c51df56357b5`, `xreq_2232a2c1-32da-454e-9f4e-f4dadde204f7`
- verdict: level: K/D +0.0000 CI [-0.0685, +0.0689], win rate +0.037 CI [-0.175, +0.250], captures -2 CI [-12, +8], n=80
- pooled: 80 episodes, 0 skipped; RED won 56.2% of episodes
  - `jordan-ctf-candidate:v48`: K/D 1.0000 (1763/1763), captures 14, wins 37
  - `jordan-ctf-candidate:v56`: K/D 1.0000 (1780/1780), captures 12, wins 40
- rationale: Derived from leadticks8: LeadTicks measured worse at 8.0, so the constant is worth testing in the other direction at 4.

## latepush3000 — REJECT

- when: 2026-07-31T00:46:22+00:00
- change: `LatePushTick` -> `3000`
- treatment: `jordan-ctf-candidate:v58`  control: `jordan-ctf-candidate:v48`
- requests: `xreq_79b06599-bb41-4828-9259-09eeefa2d3d5`, `xreq_bd6f4ad6-fb54-4898-9003-96defdca2cf5`
- verdict: level: K/D +0.0148 CI [-0.0652, +0.0936], win rate +0.037 CI [-0.175, +0.250], captures +0 CI [-9, +9], n=80
- pooled: 80 episodes, 0 skipped; RED won 62.5% of episodes
  - `jordan-ctf-candidate:v48`: K/D 0.9926 (1755/1768), captures 10, wins 37
  - `jordan-ctf-candidate:v58`: K/D 1.0074 (1764/1751), captures 10, wins 40
- rationale: Past LatePushTick a draw is the default outcome, so the posts break and everything commits to the capture. A draw scores as badly as a loss and the game hard-stops at 5000, so 3400 leaves 1600 ticks of all-in play. Starting 400 ticks earlier buys another capture attempt at the cost of holding the line longer.

## holdline4 — REJECT

- when: 2026-07-31T00:59:54+00:00
- change: `HoldLineKills` -> `4`
- treatment: `jordan-ctf-candidate:v57`  control: `jordan-ctf-candidate:v48`
- requests: `xreq_17c7ab5c-d8f5-4a03-ac4b-b7ccbabe7d6a`, `xreq_5a18d8f4-3309-43ce-a0b8-a8820aed7ed7`, `xreq_7b1f5e64-83c1-4784-b1ed-4d263c8d0c03`, `xreq_96455067-2451-4c63-bda1-441fb0194b04`
- verdict: level: K/D +0.0382 CI [-0.0027, +0.0795], win rate +0.083 CI [-0.042, +0.208], captures -7 CI [-24, +9], n=240
- pooled: 240 episodes, 0 skipped; RED won 70.4% of episodes
  - `jordan-ctf-candidate:v48`: K/D 0.9811 (5251/5352), captures 39, wins 107
  - `jordan-ctf-candidate:v57`: K/D 1.0193 (5321/5220), captures 32, wins 127
- rationale: The wave holds its own half until six enemy deaths, two players' worth of lives out of 24. The threshold has never been swept. Four commits the push a third earlier, which is either a faster capture clock or a wave that walks into a healthy defence.

## preaimarc28 — REJECT

- when: 2026-07-31T01:31:16+00:00
- change: `PreAimArc` -> `28`
- treatment: `jordan-ctf-candidate:v64`  control: `jordan-ctf-candidate:v48`
- requests: `xreq_faa93457-e781-4389-939c-9b6897febf92`, `xreq_0784987b-2aae-4e1d-94ff-644678934acf`
- verdict: level: K/D -0.0605 CI [-0.1306, +0.0068], win rate -0.113 CI [-0.325, +0.100], captures -4 CI [-15, +7], n=80
- pooled: 80 episodes, 0 skipped; RED won 72.5% of episodes
  - `jordan-ctf-candidate:v48`: K/D 1.0307 (1782/1729), captures 18, wins 44
  - `jordan-ctf-candidate:v64`: K/D 0.9702 (1724/1777), captures 14, wins 35
- rationale: While moving, the pre-aim may not stray more than 20 brads off the lane, because the vision cone rides the aim and a wide licence buys a faster swing with blindness to the ground ahead. The value has never been swept against the cone's 32-brad half-angle, which is the width that actually bounds the trade.

## exposedcost10 — REJECT

- when: 2026-07-31T02:06:46+00:00
- change: `ExposedCost` -> `10`
- treatment: `jordan-ctf-candidate:v63`  control: `jordan-ctf-candidate:v48`
- requests: `xreq_20f3ae26-3265-406f-9ebc-374325c8fcef`, `xreq_8a6f2286-444f-471d-8837-77d19f52c806`, `xreq_3fdfb9dc-6bd9-44c2-9405-ae9eee242429`, `xreq_42128b38-767c-485d-9b3f-bc7ebd4817f2`
- verdict: level: K/D +0.0174 CI [-0.0247, +0.0595], win rate +0.092 CI [-0.037, +0.217], captures +15 CI [+0, +31], n=240
- pooled: 240 episodes, 0 skipped; RED won 69.2% of episodes
  - `jordan-ctf-candidate:v48`: K/D 0.9913 (5265/5311), captures 24, wins 108
  - `jordan-ctf-candidate:v63`: K/D 1.0087 (5309/5263), captures 39, wins 130
- rationale: Entering a threat-exposed cell costs 14 against a 5-cost orthogonal step, so a route will walk almost three cells out of its way to dodge one watched cell. The archive's standing finding is that every intel addition made the bot more timid and deaths rose; loosening the routing penalty tests the same claim from the other end.

## holdline4 — PROMOTE (shipped as jordan-ctf-candidate:v57)

`HoldLineKills` 6 -> 4: the wave commits forward after four enemy deaths
instead of six. The first change this loop has shipped, and the only one of
fifteen experiments to survive a confirmation.

**Five separately-bought samples, and what each cost to learn:**

| sample | n | K/D gap |
|---|---|---|
| screen 1 (build v49, under the first screen rule) | 80 | +0.0295 |
| screen 2 (rebuild v57, under the z-scaled rule) | 80 | +0.0341 |
| confirmation alone | 160 | ~ +0.040 |
| extension alone | 158 | ~ +0.028 |
| **pooled** | **398** | **+0.0343, CI [+0.0009, +0.0672]** |

Win rate leaned positive in every one (+7.5, +11.3, +8.3, +8.8 points) and
separated in none. Captures never separated at any n.

**Champion gate: PASS.** v57 against the shipped champion v45, 80 episodes,
both directions: K/D +0.0034 CI [-0.0671, +0.0712], win rate -0.013, captures
+0 -- level on all three, which is the bar. The three measurements are
mutually consistent: gen0 put v48 at v45 - 0.022, this puts v57 at v48 +
0.034, predicting v57 = v45 + 0.012 against a measured +0.0034.

Requests: `xreq_17c7ab5c`, `xreq_5a18d8f4` (screen), `xreq_7b1f5e64`,
`xreq_96455067` (confirm), `xreq_d0bf0c75`, `xreq_cf34e5e9` (extend),
`xreq_fa5f375d`, `xreq_db4d9519` (champion gate). Submission
`sub_06dc828c-c565-4da2-bb62-69c9ffbcd95d`; the server promoted it to champion
and benched v45.

**What to distrust here.** The interval clears zero by 0.0009, and it took
three looks at the same comparison to get there -- optional stopping inflates
the true type-I error above the nominal 5%. The SIZE is soft. What is not soft
is the sign: four independently purchased samples ran +0.028 to +0.040 without
wandering, and a spurious effect wanders. Read this as "a real improvement of
roughly +0.03 K/D, possibly less", not as a measured +0.0343.

## The three that did not survive their own screens

Recorded because the pattern is the point: a striking screen is not a result,
and the confirmation stage exists to say so.

| experiment | screen | confirmation | verdict |
|---|---|---|---|
| `latepush3000` | +0.016 K/D, **+11.3** pts wins, +4 caps | re-screened +0.015, **+3.7** pts, 0 caps | level |
| `exposedcost10` | **+0.060** K/D, **+22.5** pts, +8 caps | +0.017 [-0.025, +0.060], +9.2 pts, +15 caps | level |
| `holdline4` | +0.030 K/D, +7.5 pts | held at +0.034 over 398 | **shipped** |

`exposedcost10` was the strongest screen of the session and halved under
confirmation. `latepush3000`'s win-rate lean, which looked like the most
promising signal of the early runs, came back at a third of its size on an
independent rebuild.

Its captures are worth one line of honesty: +15 with CI [+0, +31] at 240
episodes is the most capture-positive result recorded here, and this loop
cannot act on it. Captures turn on tens of events and cannot be resolved at
any sample size worth buying, so they only ever veto. If loosened routing
really does buy captures, this design is blind to it.

## What the constants say so far

Three of them are now bracketed on both sides, which is worth more than any
single verdict:

- `EnemyRespawnSamples` = 3 is a local optimum: 1 measures -0.058, 5 measures
  +0.005. The GV25 repair in `f590681`, never measured when it landed, is
  earning its routing cost.
- `LeadTicks` = 6 is fine: 8.0 measures -0.034, 4.0 measures +0.000.
- `HoldLineKills` moved 6 -> 4 (above). Its follow-up at 2 is queued.

And a coherent story across three rejects: the bot's aim-and-vision budget is
tight and must not be spent more freely (`preaimarc28` +8 brads of pre-aim
licence: -0.061; `respawnsamples1` fewer remembered threats: -0.058), while
its routing caution may be overpriced (`exposedcost10`: +0.060 on the screen,
+0.017 confirmed). Aim and routing are separable resources. Nobody told the
loop that; it fell out of the sweep.

## preaimarc28-reverse — REJECT

- when: 2026-07-31T02:42:50+00:00
- change: `PreAimArc` -> `12`
- treatment: `jordan-ctf-candidate:v65`  control: `jordan-ctf-candidate:v57`
- requests: `xreq_264c022d-a37e-4c9d-b000-64d7b753844e`, `xreq_2d1d2cce-0574-4640-9598-788ce40a51d6`
- verdict: level: K/D -0.0238 CI [-0.0874, +0.0407], win rate -0.100 CI [-0.312, +0.113], captures -2 CI [-11, +8], n=80
- pooled: 80 episodes, 0 skipped; RED won 62.5% of episodes
  - `jordan-ctf-candidate:v57`: K/D 1.0119 (1786/1765), captures 13, wins 43
  - `jordan-ctf-candidate:v65`: K/D 0.9881 (1748/1769), captures 11, wins 35
- rationale: Derived from preaimarc28: PreAimArc measured worse at 28, so the constant is worth testing in the other direction at 12.

## nadefarm420 — ESCALATE

- when: 2026-07-31T02:46:34+00:00
- change: `NadeFarmReach` -> `420.0`
- treatment: `jordan-ctf-candidate:v66`  control: `jordan-ctf-candidate:v57`
- requests: `xreq_bc8f289e-4f4e-425d-8f56-8aa89a721b8d`, `xreq_a4e40c84-69c2-4691-a215-a6772d6ac199`
- verdict: near miss, buying episodes rather than calling it: K/D +0.0148 CI [-0.0488, +0.0773], win rate +0.125 CI [-0.087, +0.338], captures +3 CI [-8, +14], n=80
- pooled: 80 episodes, 0 skipped; RED won 56.2% of episodes
  - `jordan-ctf-candidate:v57`: K/D 0.9927 (1759/1772), captures 14, wins 33
  - `jordan-ctf-candidate:v66`: K/D 1.0074 (1760/1747), captures 17, wins 43
- rationale: Corner grenades refill every 5s and are the densest pickup on the map by an order of magnitude (~80 a match against ~7 of everything else), and grenades ignore walls, cover and teams alike. A flanker will currently detour 340px to arm; the supply says the detour is cheap.

## medkitcrit240 — REJECT

- when: 2026-07-31T03:04:05+00:00
- change: `MedKitCriticalReach` -> `240.0`
- treatment: `jordan-ctf-candidate:v67`  control: `jordan-ctf-candidate:v57`
- requests: `xreq_d5a142da-b18c-44b5-a390-ed28871dd7d0`, `xreq_c9e3f39a-642a-4eab-9d4f-00382c71e03a`
- verdict: level: K/D +0.0056 CI [-0.0643, +0.0757], win rate +0.000 CI [-0.212, +0.212], captures -6 CI [-14, +2], n=80
- pooled: 80 episodes, 0 skipped; RED won 55.0% of episodes
  - `jordan-ctf-candidate:v57`: K/D 0.9972 (1766/1771), captures 12, wins 38
  - `jordan-ctf-candidate:v67`: K/D 1.0028 (1777/1772), captures 6, wins 38
- rationale: At 1 hp a heal outranks the current errand only within 180px. Two kits sit on the centre line and refill every 30s, and a one-hit bot is worth a fraction of a full one in every fight it then takes; 240 lets it break off from further out.

## nadefoeping90 — REJECT

- when: 2026-07-31T03:06:21+00:00
- change: `NadeFoePingTtl` -> `90`
- treatment: `jordan-ctf-candidate:v68`  control: `jordan-ctf-candidate:v57`
- requests: `xreq_8eada125-99fa-4875-9a6c-227b04550956`, `xreq_59f29db2-e2e0-4983-b029-bea619dbd6dc`
- verdict: level: K/D -0.0068 CI [-0.0737, +0.0595], win rate +0.075 CI [-0.138, +0.287], captures +2 CI [-8, +12], n=80
- pooled: 80 episodes, 0 skipped; RED won 75.0% of episodes
  - `jordan-ctf-candidate:v57`: K/D 1.0034 (1775/1769), captures 12, wins 35
  - `jordan-ctf-candidate:v68`: K/D 0.9966 (1767/1773), captures 14, wins 41
- rationale: A grenade is the only weapon that collects value from a place rather than a body, and the only one cover does nothing against, but a spot the sonar heard a fight at stops being a throw target after 45 ticks. Landings are audible map-wide through walls and fog, so this is the bot's one map-wide sense and the throw is its one map-wide answer; 90 ticks is still inside SonarTtl.

## nadefarm420 — PROMOTE (shipped as jordan-ctf-candidate:v66)

`NadeFarmReach` 340 -> 420: how far a flanker will detour to arm with a corner
grenade. **The strongest result in this repository's record, and the only one
where captures have ever separated.**

Measured directly against the champion (`v57`, which this loop had shipped an
hour earlier), 240 episodes, 0 skipped:

| | K/D | captures | wins |
|---|---|---|---|
| `v57` | 0.9683 | 33 | 84/240 (35.0%) |
| `v66` | **1.0327** | **56** | **145/240 (60.4%)** |

- K/D gap **+0.0635**, 95% CI [+0.0262, +0.1001]
- Win-rate gap **+0.251**, 95% CI [+0.130, +0.372]
- Capture gap **+22**, 95% CI [+4, +40]

All three exclude zero. And it wins on BOTH sides of the mirror -- 72.5% of
episodes holding RED, and 62% holding BLUE, in a league where RED wins ~63%
regardless of build. A side artifact cannot do that. The control was the
champion itself, so no separate gate applies.

Submission `sub_bd75b5c7-852e-4f56-b8d4-47167f1be732`. Requests
`xreq_bc8f289e`, `xreq_a4e40c84` (screen), `xreq_741a2392`, `xreq_528ad5c9`
(confirmation).

**Why it was there to find.** The supply argument was in the archive the whole
time and nobody had priced the detour against it: corner grenades refill every
5 seconds, ~80 a match against ~7 of everything else, and the blast ignores
walls, cover and teams alike -- it is the one weapon cover is worth nothing
against. The bot simply would not walk another 80 pixels for the densest and
most cover-proof resource on the map.

**How much to believe it.** Much more than holdline4. This one separated on
its first confirmation with no extension, on every metric, in one direction of
travel, with the largest effect and the tightest relative interval of anything
measured here. `nadefarm420-further` (500) is queued to find where it stops
paying -- the detour competes with the flanker's actual errand, so there is a
value past which arming costs more than it buys.

## nadecarrier — REJECT

- when: 2026-07-31T03:33:10+00:00
- change: `baseline/grenades.nim`: `if f.carryingNade and not f.iCarry:` -> `if f.carryingNade:`
- treatment: `jordan-ctf-candidate:v69`  control: `jordan-ctf-candidate:v57`
- requests: `xreq_5bd742f7-a72d-472a-886d-142838922000`, `xreq_4470539d-1218-4a6a-9e4e-13349184131a`
- verdict: level: K/D -0.0186 CI [-0.0848, +0.0452], win rate +0.013 CI [-0.205, +0.231], captures +11 CI [-1, +23], n=78
- pooled: 78 episodes, 2 skipped; RED won 62.8% of episodes
  - `jordan-ctf-candidate:v57`: K/D 1.0093 (1729/1713), captures 13, wins 37
  - `jordan-ctf-candidate:v69`: K/D 0.9907 (1713/1729), captures 24, wins 38
- rationale: `planGrenade` refuses to throw while carrying the flag, so the one player who cannot afford to be caught is the one player forbidden the weapon that reaches through walls. A carrier being chased has exactly one job, and a chaser it cannot shoot is exactly what a grenade is for. `nadeSafe` already vetoes a landing that would clip us, so the risk this gate was written against is covered twice; what it really costs is the aim, and the aim is the carrier's vision.

## freshshot32 — REJECT

- when: 2026-07-31T03:37:48+00:00
- change: `FreshShotTicks` -> `32`
- treatment: `jordan-ctf-candidate:v70`  control: `jordan-ctf-candidate:v57`
- requests: `xreq_5cce151a-fbd7-47ca-b999-5ec25bc3c9e9`, `xreq_3fdd6beb-f666-431c-8348-a331ba03545c`
- verdict: level: K/D -0.0254 CI [-0.0975, +0.0484], win rate -0.051 CI [-0.266, +0.165], captures +2 CI [-9, +13], n=79
- pooled: 79 episodes, 1 skipped; RED won 73.4% of episodes
  - `jordan-ctf-candidate:v57`: K/D 1.0127 (1748/1726), captures 14, wins 39
  - `jordan-ctf-candidate:v70`: K/D 0.9873 (1716/1738), captures 16, wins 35
- rationale: Only tracks seen within 24 ticks may be fired at. The gun is map-wide hitscan and the turret traverses at 5 brads/tick, so a target that fogs out mid-swing is dropped just as the swing finishes paying for itself. Every gate downstream tests freshness for itself, so the risk of a wider window is wasted shots at a place nobody is standing, not a shot into a wall.

## In flight when the session ended

Two mirrors were bought and running when work stopped. The episodes exist on
the server; nothing has pooled them. To recover rather than re-buy:

```bash
python scripts/pool_h2h.py xreq_f576245f-667d-4695-9c91-5436f665f569 \
    xreq_a10e7cd8-0f6a-4d52-93b7-f1c6c9c5e537 --treatment=<the non-v66 build>
```

- **nadefarm420-further** (`NadeFarmReach` 420 -> 500, vs `v66`):
  `xreq_f576245f`, `xreq_a10e7cd8` — both directions complete.
- **nadecarrier**, re-run against `v66`: `xreq_71e10dd4`, `xreq_5f4859bf` —
  one straggler episode outstanding. Note it was already measured against
  `v57` and came back level on K/D with captures +11, CI [-1, +23].

`scripts/pool_h2h.py` reports every episode it skips, so a partial pool is
visible rather than silent. Read the treatment label out of the mirror itself
(`coworld xp-request episodes <id> --json`) rather than assuming it.

## Resuming

`research/state.json` is the resume point: baseline and champion are both
`jordan-ctf-candidate:v66`, sixteen experiments are decided, and the queue
holds `nadefarm420-further` and `freshshot32-reverse` ahead of the untried
seeds. Restart with:

```bash
python scripts/autoresearch.py --batch=2
```

It picks up from the queue, re-reads the catalogue, and measures everything
against `v66`. Run `python scripts/autoresearch.py --dry-run` first after any
change to `bot/` — it proves every queued edit still matches the tree exactly
once, which is the failure this repository keeps paying for.

## nadecarrier — REJECT

- when: 2026-07-31T04:03:48+00:00
- change: `baseline/grenades.nim`: `if f.carryingNade and not f.iCarry:` -> `if f.carryingNade:`
- treatment: `jordan-ctf-candidate:v72`  control: `jordan-ctf-candidate:v66`
- requests: `xreq_71e10dd4-763f-4fd4-b5f1-798794d36a07`, `xreq_5f4859bf-4ab7-4edd-a71b-efda7ff4865c`
- verdict: level: K/D -0.0011 CI [-0.0553, +0.0530], win rate +0.125 CI [-0.087, +0.338], captures +6 CI [-5, +17], n=80
- pooled: 80 episodes, 0 skipped; RED won 51.2% of episodes
  - `jordan-ctf-candidate:v66`: K/D 1.0006 (1777/1776), captures 13, wins 34
  - `jordan-ctf-candidate:v72`: K/D 0.9994 (1763/1764), captures 19, wins 44
- rationale: `planGrenade` refuses to throw while carrying the flag, so the one player who cannot afford to be caught is the one player forbidden the weapon that reaches through walls. A carrier being chased has exactly one job, and a chaser it cannot shoot is exactly what a grenade is for. `nadeSafe` already vetoes a landing that would clip us, so the risk this gate was written against is covered twice; what it really costs is the aim, and the aim is the carrier's vision.

## nadefarm420-further — PROMOTE (shipped as jordan-ctf-candidate:v71)

`NadeFarmReach` 420 -> 500, measured against `v66` — the champion the previous
step produced. 240 episodes, 0 skipped.

| | K/D | captures | wins |
|---|---|---|---|
| `v66` | 0.9666 | 60 | 91/240 (37.9%) |
| `v71` | **1.0348** | 52 | **131/240 (54.6%)** |

- K/D gap **+0.0682**, 95% CI [+0.0349, +0.1005]
- Win-rate gap **+0.167**, 95% CI [+0.046, +0.287]
- Capture gap **-8**, 95% CI [-29, +13] — crosses zero, so it does not veto

It separated on K/D at the SCREEN (+0.0663, CI [+0.0046, +0.1289]) and got
stronger on the confirmation, which is the opposite of what the three failed
candidates did. Submission `sub_a84ab672-8448-43a2-b413-0fde6da045bd`.

**The captures are the interesting part, and they reversed.** At 420 the
capture gap was +22 with CI [+4, +40] — the only separating capture result in
this repository. At 500 it is -8 and crosses zero, while K/D and win rate both
grew. Read together, the detour keeps paying but stops paying in captures
somewhere below 500 and starts paying in kills instead: a flanker 500px off
its errand is arming rather than arriving. That is a real trade and not
obviously monotonic, so **580 was deliberately not queued.**

Two measured steps, each against the champion the last one produced:

| step | K/D | win rate | captures |
|---|---|---|---|
| 340 -> 420 | +0.064 [+0.026, +0.100] | +25.1 pts | **+22 [+4, +40]** |
| 420 -> 500 | +0.068 [+0.035, +0.101] | +16.7 pts | -8 [-29, +13] |

## Final state of this session

Champion: **`jordan-ctf-candidate:v71`**, reached `v45 -> v57 -> v66 -> v71`.
21 experiments decided, ~5,200 league episodes, three promotions.

The loop is STOPPED and no Experience Requests are outstanding. Nothing in the
queue. `scripts/autoresearch.py --batch=2` resumes it against `v71`; run
`--dry-run` first after any change to `bot/`.

Untried in the catalogue: `shieldflank`, `scanarc36`, `freshshot32-reverse`,
`nadepickup130`, `nadeheld40`. The last two are the ones the grenade result
argues for -- `NadePickupDetour` is still 90 and is the same underpriced-detour
bet at a fraction of the tempo.

## Methodology change: measurement moves to the local simulator

- when: 2026-07-31T05:50:00+00:00
- by operator instruction: the local sim is now much faster than hosted A/B
  (PR #14 made it 3.3x faster still), so experiments are measured as
  seed-paired local mirrors and NEVER as hosted Experience Requests. A
  promotion ships immediately: land in bot/, cross-compile static
  linux/amd64, upload, submit with --auto-champion always. No hosted A/B
  before submission.
- driver: `scripts/autoresearch_local.py`. Same catalogue, state, ledger and
  decision rules as `autoresearch.py`; only the episode source changed.
  Screen 60 seeds (120 eps), confirm +140 (400 eps pooled), one extension
  +100. K/D half-width fits ~0.50/sqrt(episodes) locally, so the pooled
  confirmation resolves ~0.025 K/D.
- calibration, before trusting any of it: the one hosted result that can be
  replayed is v66 -> v71 (`NadeFarmReach` 420 -> 500). Hosted: K/D +0.0682
  CI [+0.0349, +0.1005] at n=240. Local, same one-variable diff on today's
  tree: **K/D +0.0945 CI [+0.0489, +0.1400]**, wins 70-41, n=120
  (`episodes/cal-500-vs-420.jsonl`, seeds 1000-1059 both ways). Same sign,
  overlapping intervals. The sim also passed `selfcheck` (determinism, seat
  independence, tree separation) on this machine first.
- what local cannot see, and is accepted: dropped frames under hosted pacing
  (flatters CPU-expensive changes -- none queued move compute), and the
  standing field (the control is the reigning build, which is the same
  control the hosted loop used).
- shipping without Docker: this box is arm64 with no daemon, so a promotion
  is cross-compiled with zig cc to a STATIC x86_64-musl binary
  (`scripts/build_amd64.sh`), smoke-tested under qemu-x86_64 (it must demand
  COWORLD_PLAYER_WS_URL, and a live websocket handshake was proven once by
  hand), wrapped as a single-layer docker-save archive and pushed through the
  CLI's own registry client (`scripts/upload_amd64_policy.py`). The whole
  path was validated end to end: the current tree (v71 source) uploaded as
  `jordan-ctf-candidate:v73`, tagged purpose=upload-path-check-no-docker,
  deliberately NOT submitted.
- state repair: `freshshot32`'s REJECT was in the ledger but missing from
  state.json's done map; backfilled so the loop cannot re-buy it. The queue
  was reseeded to lead with `nadepickup130` and `nadeheld40` (the two
  experiments the grenade results argue for), then `freshshot32-reverse`.

## nadepickup130 — REJECT (local A/B)

- when: 2026-07-31T05:53:28+00:00
- change: `NadePickupDetour` -> `130.0`
- treatment: local build  control: `jordan-ctf-candidate:v71` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-nadepickup130.jsonl, seeds 208000-208059 both ways, seeds 208200-208339 both ways, seeds 208400-208499 both ways)
- verdict: level: K/D +0.0043 CI [-0.0045, +0.0132], win rate +0.015 CI [-0.020, +0.052], captures +6 CI [-11, +24], n=600
- pooled: 600 episodes, 0 skipped; RED won 36.5% of episodes
  - treatment: K/D 1.0022 (12948/12920), captures 188, wins 282
  - control: K/D 0.9978 (12907/12935), captures 182, wins 273
- rationale: front of queue: the sibling of the constant that paid twice

## nadeheld40 — REJECT (local A/B)

- when: 2026-07-31T05:54:53+00:00
- change: `NadeHeldCost` -> `40.0`
- treatment: local build  control: `jordan-ctf-candidate:v71` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-nadeheld40.jsonl, seeds 209000-209059 both ways)
- verdict: wins separate NEGATIVE: K/D -0.0054 CI [-0.0145, +0.0000], win rate -0.033 CI [-0.083, +0.000], captures -1 CI [-7, +4], n=120
- pooled: 120 episodes, 0 skipped; RED won 33.3% of episodes
  - treatment: K/D 0.9973 (2576/2583), captures 37, wins 53
  - control: K/D 1.0027 (2585/2578), captures 38, wins 57
- rationale: front of queue: the grenade result argues the weapon is underpriced

## freshshot32-reverse — REJECT (local A/B)

- when: 2026-07-31T05:56:05+00:00
- change: `FreshShotTicks` -> `16`
- treatment: local build  control: `jordan-ctf-candidate:v71` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-freshshot32-reverse.jsonl, seeds 210000-210059 both ways)
- verdict: wins separate NEGATIVE: K/D -0.0921 CI [-0.1362, -0.0492], win rate -0.267 CI [-0.442, -0.092], captures -23 CI [-41, -4], n=120
- pooled: 120 episodes, 0 skipped; RED won 42.5% of episodes
  - treatment: K/D 0.9550 (2527/2646), captures 31, wins 41
  - control: K/D 1.0471 (2646/2527), captures 54, wins 73
- rationale: Derived from freshshot32: FreshShotTicks measured worse at 32 (K/D -0.0254), so the constant is worth testing in the other direction at 16.

## nadeheld40-reverse — REJECT (local A/B)

- when: 2026-07-31T05:57:19+00:00
- change: `NadeHeldCost` -> `80.0`
- treatment: local build  control: `jordan-ctf-candidate:v71` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-nadeheld40-reverse.jsonl, seeds 211000-211059 both ways)
- verdict: wins separate NEGATIVE: K/D +0.0008 CI [+0.0000, +0.0023], win rate +0.000 CI [+0.000, +0.000], captures +0 CI [+0, +0], n=120
- pooled: 120 episodes, 0 skipped; RED won 30.0% of episodes
  - treatment: K/D 1.0004 (2590/2589), captures 37, wins 56
  - control: K/D 0.9996 (2588/2589), captures 37, wins 56
- rationale: Derived from nadeheld40: NadeHeldCost measured worse at 40.0, so the constant is worth testing in the other direction at 80.

## shieldflank — REJECT (local A/B)

- when: 2026-07-31T05:58:32+00:00
- change: `baseline/objective.nim`: `bot.role == MidGuard and` -> `bot.role in {MidGuard, FlankTop} and`
- treatment: local build  control: `jordan-ctf-candidate:v71` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-shieldflank.jsonl, seeds 212000-212059 both ways)
- verdict: level: K/D -0.0147 CI [-0.0626, +0.0337], win rate +0.075 CI [-0.083, +0.233], captures +3 CI [-12, +18], n=120
- pooled: 120 episodes, 0 skipped; RED won 34.2% of episodes
  - treatment: K/D 0.9926 (2559/2578), captures 33, wins 59
  - control: K/D 1.0073 (2624/2605), captures 30, wins 50
- rationale: Exactly one seat (MidGuard) will ever pick up a shield, so the 6 hp on offer is taken about 13% of the time. Doubling a body's health for a 3x slower gun is the most lopsided trade on the map for anyone whose job is to arrive rather than to shoot, and the flankers hit the pocket from behind, which is the arriving job. This is the ambiguous one the archive left unmeasured.

## scanarc36 — PROMOTE (local A/B)

- when: 2026-07-31T06:03:51+00:00
- change: `ScanArc` -> `36`
- treatment: local build  control: `jordan-ctf-candidate:v71` (the tree)
- shipped as: `jordan-ctf-candidate:v74`
- measured on: the local simulator, seed-paired mirrors (episodes/exp-scanarc36.jsonl, seeds 213000-213059 both ways, seeds 213200-213339 both ways)
- verdict: separates positive on the pooled sample: K/D +0.0840 CI [+0.0621, +0.1058], win rate +0.220 CI [+0.138, +0.300], captures +58 CI [+30, +86], n=400
- pooled: 400 episodes, 0 skipped; RED won 30.2% of episodes
  - treatment: K/D 1.0430 (8740/8380), captures 143, wins 227
  - control: K/D 0.9590 (8417/8777), captures 85, wins 139
- rationale: Held positions sweep 44 brads either side of the watch heading with a 32-brad cone half-angle, so the sweep overshoots what the cone covers and the far edge is only ever swept through. A 36-brad sweep re-crosses the covered ground more often, which is what actually catches a crossing enemy.

## scanarc36-further — PROMOTE (local A/B)

- when: 2026-07-31T06:07:28+00:00
- change: `ScanArc` -> `28`
- treatment: local build  control: `jordan-ctf-candidate:v74` (the tree)
- shipped as: `jordan-ctf-candidate:v75`
- measured on: the local simulator, seed-paired mirrors (episodes/exp-scanarc36-further.jsonl, seeds 214000-214059 both ways, seeds 214200-214339 both ways)
- verdict: separates positive on the pooled sample: K/D +0.0790 CI [+0.0558, +0.1032], win rate +0.102 CI [+0.013, +0.195], captures +63 CI [+34, +91], n=400
- pooled: 400 episodes, 0 skipped; RED won 27.5% of episodes
  - treatment: K/D 1.0398 (8900/8559), captures 137, wins 206
  - control: K/D 0.9608 (8358/8699), captures 74, wins 165
- rationale: Derived from scanarc36: ScanArc paid at 36, so walk the same way again to 28 and find where it stops paying.

## scanarc36-further-further — REJECT (local A/B)

- when: 2026-07-31T06:08:42+00:00
- change: `ScanArc` -> `20`
- treatment: local build  control: `jordan-ctf-candidate:v75` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-scanarc36-further-further.jsonl, seeds 215000-215059 both ways)
- verdict: wins separate NEGATIVE: K/D -0.1435 CI [-0.1931, -0.0916], win rate -0.350 CI [-0.500, -0.192], captures -11 CI [-26, +4], n=120
- pooled: 120 episodes, 0 skipped; RED won 32.5% of episodes
  - treatment: K/D 0.9318 (2485/2667), captures 29, wins 37
  - control: K/D 1.0753 (2600/2418), captures 40, wins 79
- rationale: Derived from scanarc36-further: ScanArc paid at 28, so walk the same way again to 20 and find where it stops paying.

## nadememttl240 — REJECT (local A/B)

- when: 2026-07-31T06:09:56+00:00
- change: `NadeMemTtl` -> `240`
- treatment: local build  control: `jordan-ctf-candidate:v75` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-nadememttl240.jsonl, seeds 216000-216059 both ways)
- verdict: level: K/D +0.0129 CI [-0.0213, +0.0468], win rate +0.025 CI [-0.125, +0.183], captures -1 CI [-15, +13], n=120
- pooled: 120 episodes, 0 skipped; RED won 42.5% of episodes
  - treatment: K/D 1.0065 (2645/2628), captures 30, wins 59
  - control: K/D 0.9936 (2624/2641), captures 31, wins 56
- rationale: A remembered enemy stays a throw target for 150 ticks. The grenade is the only weapon that collects value from a memory, TrackHoldTtl already believes a lost enemy for 400 ticks, and both grenade promotions said the weapon was underpriced; 240 keeps bombing positions the tracker still believes in.

## nadefoepingcost100 — REJECT (local A/B)

- when: 2026-07-31T06:11:14+00:00
- change: `NadeFoePingCost` -> `100.0`
- treatment: local build  control: `jordan-ctf-candidate:v75` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-nadefoepingcost100.jsonl, seeds 217000-217059 both ways)
- verdict: level: K/D +0.0008 CI [-0.0015, +0.0031], win rate +0.017 CI [+0.000, +0.050], captures +2 CI [-2, +7], n=120
- pooled: 120 episodes, 0 skipped; RED won 45.8% of episodes
  - treatment: K/D 1.0004 (2628/2627), captures 33, wins 59
  - control: K/D 0.9996 (2627/2628), captures 31, wins 57
- rationale: A heard-landing spot is charged 150px of doubt against a throw, the largest single price in the grenade scorer. The sonar is the bot's one map-wide sense and the throw its one map-wide answer; if grenade evidence has been overpriced everywhere else, the spot price is the next place the same error would hide.

## plasmadetour110 — REJECT (local A/B)

- when: 2026-07-31T06:12:30+00:00
- change: `PlasmaDetour` -> `110.0`
- treatment: local build  control: `jordan-ctf-candidate:v75` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-plasmadetour110.jsonl, seeds 218000-218059 both ways)
- verdict: level: K/D -0.0231 CI [-0.0691, +0.0245], win rate -0.058 CI [-0.233, +0.117], captures -4 CI [-20, +12], n=120
- pooled: 120 episodes, 0 skipped; RED won 55.0% of episodes
  - treatment: K/D 0.9885 (2585/2615), captures 27, wins 54
  - control: K/D 1.0116 (2613/2583), captures 31, wins 61
- rationale: An attacker detours at most 70px for a plasma arc that the engagement scorer itself values at 70px of threat credit (ArcThreatBonus), refills in 30s, and triples close-range lethality. The same detour-underpricing that paid twice on grenades, on the other weapon pickup.

## plasmadetour110-reverse — REJECT (local A/B)

- when: 2026-07-31T06:13:43+00:00
- change: `PlasmaDetour` -> `30.0`
- treatment: local build  control: `jordan-ctf-candidate:v75` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-plasmadetour110-reverse.jsonl, seeds 219000-219059 both ways)
- verdict: level: K/D +0.0069 CI [-0.0209, +0.0351], win rate -0.008 CI [-0.108, +0.092], captures -6 CI [-16, +4], n=120
- pooled: 120 episodes, 0 skipped; RED won 45.8% of episodes
  - treatment: K/D 1.0035 (2598/2589), captures 31, wins 57
  - control: K/D 0.9965 (2586/2595), captures 37, wins 58
- rationale: Derived from plasmadetour110: PlasmaDetour measured worse at 110.0, so the constant is worth testing in the other direction at 30.

## medkitdetour120 — PROMOTE (local A/B)

- when: 2026-07-31T06:17:29+00:00
- change: `MedKitDetour` -> `120.0`
- treatment: local build  control: `jordan-ctf-candidate:v75` (the tree)
- shipped as: `jordan-ctf-candidate:v76`
- measured on: the local simulator, seed-paired mirrors (episodes/exp-medkitdetour120.jsonl, seeds 220000-220059 both ways, seeds 220200-220339 both ways)
- verdict: separates positive on the pooled sample: K/D +0.0971 CI [+0.0727, +0.1208], win rate +0.247 CI [+0.163, +0.330], captures +55 CI [+30, +79], n=400
- pooled: 400 episodes, 0 skipped; RED won 31.2% of episodes
  - treatment: K/D 1.0498 (8798/8381), captures 142, wins 240
  - control: K/D 0.9527 (8399/8816), captures 87, wins 141
- rationale: The merely-wounded heal detour is 80px. medkitcrit240 tested the CRITICAL reach and came back level, but a 1hp bot is already half lost; the wounded case is where a cheap top-up still converts into fights won, and it has never been moved.

## medkitdetour120-further — REJECT (local A/B)

- when: 2026-07-31T06:18:45+00:00
- change: `MedKitDetour` -> `160.0`
- treatment: local build  control: `jordan-ctf-candidate:v76` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-medkitdetour120-further.jsonl, seeds 221000-221059 both ways)
- verdict: level: K/D -0.0039 CI [-0.0314, +0.0247], win rate +0.017 CI [-0.092, +0.133], captures +3 CI [-7, +13], n=120
- pooled: 120 episodes, 0 skipped; RED won 16.7% of episodes
  - treatment: K/D 0.9981 (2583/2588), captures 34, wins 58
  - control: K/D 1.0019 (2581/2576), captures 31, wins 56
- rationale: Derived from medkitdetour120: MedKitDetour paid at 120.0, so walk the same way again to 160 and find where it stops paying.

## medkitdetour120-further-reverse — REJECT (local A/B)

- when: 2026-07-31T06:19:58+00:00
- change: `MedKitDetour` -> `80.0`
- treatment: local build  control: `jordan-ctf-candidate:v76` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-medkitdetour120-further-reverse.jsonl, seeds 222000-222059 both ways)
- verdict: REGRESSION: K/D -0.0627 CI [-0.1054, -0.0212], win rate -0.158 CI [-0.333, +0.025], captures -12 CI [-26, +2], n=120
- pooled: 120 episodes, 0 skipped; RED won 42.5% of episodes
  - treatment: K/D 0.9691 (2573/2655), captures 26, wins 49
  - control: K/D 1.0318 (2662/2580), captures 38, wins 68
- rationale: Derived from medkitdetour120-further: MedKitDetour measured worse at 160.0, so the constant is worth testing in the other direction at 80.

## medkitdetour120-further-reverse-reverse — REJECT (local A/B)

- when: 2026-07-31T06:21:13+00:00
- change: `MedKitDetour` -> `160.0`
- treatment: local build  control: `jordan-ctf-candidate:v76` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-medkitdetour120-further-reverse-reverse.jsonl, seeds 223000-223059 both ways)
- verdict: level: K/D +0.0061 CI [-0.0271, +0.0389], win rate -0.008 CI [-0.133, +0.117], captures +2 CI [-7, +11], n=120
- pooled: 120 episodes, 0 skipped; RED won 22.5% of episodes
  - treatment: K/D 1.0031 (2623/2615), captures 34, wins 57
  - control: K/D 0.9969 (2613/2621), captures 32, wins 58
- rationale: Derived from medkitdetour120-further-reverse: MedKitDetour measured worse at 80.0, so the constant is worth testing in the other direction at 160.

## carrierbudget140 — REJECT (local A/B)

- when: 2026-07-31T06:22:28+00:00
- change: `MedKitCarrierBudget` -> `140.0`
- treatment: local build  control: `jordan-ctf-candidate:v76` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-carrierbudget140.jsonl, seeds 224000-224059 both ways)
- verdict: level: K/D +0.0031 CI [-0.0008, +0.0078], win rate +0.008 CI [+0.000, +0.025], captures +1 CI [+0, +3], n=120
- pooled: 120 episodes, 0 skipped; RED won 12.5% of episodes
  - treatment: K/D 1.0016 (2571/2567), captures 34, wins 56
  - control: K/D 0.9984 (2567/2571), captures 33, wins 55
- rationale: A hurt carrier spends at most 90 extra path px to heal, and a full-heal carrier survives pocket exits that kill a 1hp one. The flag run is the scoring unit the league actually counts, so buying carrier survivability is the most direct capture purchase on the board.

## scanarc24 — REJECT (local A/B)

- when: 2026-07-31T06:28:23+00:00
- change: `ScanArc` -> `24`
- treatment: local build  control: `jordan-ctf-candidate:v76` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-scanarc24.jsonl, seeds 225000-225059 both ways)
- verdict: wins separate NEGATIVE: K/D -0.0736 CI [-0.1194, -0.0292], win rate -0.317 CI [-0.467, -0.167], captures -19 CI [-33, -5], n=120
- pooled: 120 episodes, 0 skipped; RED won 34.2% of episodes
  - treatment: K/D 0.9644 (2574/2669), captures 26, wins 37
  - control: K/D 1.0380 (2594/2499), captures 45, wins 75
- rationale: Probe the interior of the bracket the walk left: 36 paid +0.084, 28 paid +0.079 more, 20 was a -0.144 cliff. The cone half-angle is 32 brads; 24 asks where between 20 and 28 the sweep stops covering its own cone.

## nadefarm580 — REJECT (local A/B)

- when: 2026-07-31T06:29:44+00:00
- change: `NadeFarmReach` -> `580.0`
- treatment: local build  control: `jordan-ctf-candidate:v76` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-nadefarm580.jsonl, seeds 226000-226059 both ways)
- verdict: level: K/D +0.0015 CI [-0.0310, +0.0344], win rate -0.017 CI [-0.142, +0.108], captures -5 CI [-18, +8], n=120
- pooled: 120 episodes, 0 skipped; RED won 15.0% of episodes
  - treatment: K/D 1.0008 (2581/2579), captures 32, wins 55
  - control: K/D 0.9992 (2583/2585), captures 37, wins 57
- rationale: The hosted session deliberately did not queue this: at 500 the capture gap reversed sign while K/D kept climbing, so the next step was not obviously free. Local episodes are two orders of magnitude cheaper and the captures veto guards the downside, so the question is now worth its price. 340->420 paid, 420->500 paid; the step that won is rarely the biggest step that wins.

## scanarc24-reverse — REJECT (local A/B)

- when: 2026-07-31T06:31:06+00:00
- change: `ScanArc` -> `32`
- treatment: local build  control: `jordan-ctf-candidate:v76` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-scanarc24-reverse.jsonl, seeds 227000-227059 both ways)
- verdict: level: K/D +0.0093 CI [-0.0145, +0.0358], win rate -0.033 CI [-0.133, +0.067], captures -1 CI [-9, +7], n=120
- pooled: 120 episodes, 0 skipped; RED won 25.0% of episodes
  - treatment: K/D 1.0046 (2601/2589), captures 35, wins 55
  - control: K/D 0.9954 (2585/2597), captures 36, wins 59
- rationale: Derived from scanarc24: ScanArc measured worse at 24, so the constant is worth testing in the other direction at 32.

## exposedcost10-local — REJECT (local A/B)

- when: 2026-07-31T06:34:58+00:00
- change: `ExposedCost` -> `10`
- treatment: local build  control: `jordan-ctf-candidate:v76` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-exposedcost10-local.jsonl, seeds 228000-228059 both ways, seeds 228200-228339 both ways)
- verdict: level: K/D +0.0104 CI [-0.0197, +0.0390], win rate +0.043 CI [-0.045, +0.130], captures +26 CI [-1, +52], n=400
- pooled: 400 episodes, 0 skipped; RED won 24.5% of episodes
  - treatment: K/D 1.0052 (8638/8593), captures 124, wins 203
  - control: K/D 0.9948 (8602/8647), captures 98, wins 186
- rationale: Re-ask of exposedcost10 under the local paired instrument. Hosted at n=240 it leaned positive without separating: K/D +0.017 [-0.025, +0.060], captures +15 [+0, +31]. That interval is exactly the shape a real ~0.02 effect leaves at hosted resolution, and the anti-timidity prior (every intel addition made the bot more timid and deaths rose) points the same way.

## pushout-hold-conflict — REJECT (local A/B)

- when: 2026-07-31T07:33:39+00:00
- change: `baseline/act.nim`: `if bot.killsInit and not f.iCarry and not f.ownStolen and holdNow:` -> `if bot.killsInit and not f.iCarry and not f.ownStolen and not f.pushOut and holdNow:`
- treatment: local build  control: `jordan-ctf-candidate:v76` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-pushout-hold-conflict.jsonl, seeds 229000-229059 both ways)
- verdict: REGRESSION: K/D -0.0160 CI [-0.0274, -0.0054], win rate +0.050 CI [-0.042, +0.142], captures +15 CI [+6, +24], n=120
- pooled: 120 episodes, 0 skipped; RED won 26.7% of episodes
  - treatment: K/D 0.9920 (2606/2627), captures 43, wins 62
  - control: K/D 1.0081 (2628/2607), captures 28, wins 56
- rationale: act.nim's hold-line clamp has no pushOut exemption, and holdNow is true whenever we are behind OR TIED on kills. Past LatePushTick, pushOut breaks the defensive posts and sends every seat through the attacker branch -- but the clamp caps every target 80px past mid, ~350px short of the pocket, so the all-in can never arrive: defense abandoned, offense forbidden, and the timeout it drifts into is lose-lose. The field is largely this lineage carrying the same bug, so fixing it unilaterally wins the tied endgame race.

## combat-strafe — REJECT (local A/B)

- when: 2026-07-31T07:35:00+00:00
- change: `baseline/act.nim`: `f.wantFire = perpMiss <= FireSlackPx
    f.moveMask = octantBits(f.aim - f.me)` -> `f.wantFire = perpMiss <= FireSlackPx
    let adv = norm(f.aim - f.me)
    var strafe = vec(-adv.y, adv.x)
    if (bot.tick div 10 + bot.slot div 2) mod 2 == 0:
      strafe = strafe * -1.0
    f.moveMask = octantBits(adv + strafe * 0.6)`
- treatment: local build  control: `jordan-ctf-candidate:v76` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-combat-strafe.jsonl, seeds 230000-230059 both ways)
- verdict: level: K/D -0.0085 CI [-0.0572, +0.0382], win rate -0.100 CI [-0.258, +0.058], captures -3 CI [-17, +11], n=120
- pooled: 120 episodes, 0 skipped; RED won 63.3% of episodes
  - treatment: K/D 0.9958 (2628/2639), captures 33, wins 49
  - control: K/D 1.0043 (2575/2564), captures 36, wins 61
- rationale: While engaged, the bot closes dead straight at its target -- zero crossing motion, zero lead error, the easiest body for the field's own linear-lead fire gate (largely this lineage: LeadTicks velocity lead, fire at perpMiss <= 11px). Blend in a perpendicular strafe flipping every 10 ticks, exactly what the serpentine already does when unengaged. Information denial in the one state where the bot currently denies nothing.

## nade-charge-on-move — REJECT (local A/B)

- when: 2026-07-31T07:36:22+00:00
- change: `baseline/act.nim`: `f.holdStill = true
    f.acted = true` -> `if bot.nadeCharge > 0:
      let fwd = bradsDir(bot.estAim)
      var strafe = vec(-fwd.y, fwd.x)
      if (bot.tick div 12 + bot.slot div 2) mod 2 == 0:
        strafe = strafe * -1.0
      f.moveMask = octantBits(strafe)
    else:
      f.holdStill = true
    f.acted = true`
- treatment: local build  control: `jordan-ctf-candidate:v76` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-nade-charge-on-move.jsonl, seeds 231000-231059 both ways)
- verdict: wins separate NEGATIVE: K/D -0.0807 CI [-0.1225, -0.0395], win rate -0.192 CI [-0.342, -0.033], captures -15 CI [-29, -1], n=120
- pooled: 120 episodes, 0 skipped; RED won 22.5% of episodes
  - treatment: K/D 0.9604 (2546/2651), captures 24, wins 43
  - control: K/D 1.0411 (2659/2554), captures 39, wins 66
- rationale: The grenade charge branch holds the bot STILL for up to 24 ticks while the server draws our landing-preview ring for every enemy that can see us: a motionless, telegraphing target. The engine applies d-pad movement at full speed regardless of the C bit, and a perpendicular strafe preserves the throw range the charge was computed from. Grenades are the tree's most-promoted weapon; the per-throw exposure tax is paid constantly.

## carrier-run-and-gun — REJECT (local A/B)

- when: 2026-07-31T07:40:03+00:00
- change: `baseline/act.nim`: `f.wantFire = perpMiss <= FireSlackPx
    f.moveMask = octantBits(f.aim - f.me)
    f.acted = true` -> `f.wantFire = perpMiss <= FireSlackPx
    if not f.iCarry:
      f.moveMask = octantBits(f.aim - f.me)
      f.acted = true`
- treatment: local build  control: `jordan-ctf-candidate:v76` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-carrier-run-and-gun.jsonl, seeds 232000-232059 both ways, seeds 232200-232339 both ways)
- verdict: level: K/D -0.0002 CI [-0.0117, +0.0115], win rate +0.013 CI [-0.028, +0.055], captures +5 CI [-8, +18], n=400
- pooled: 400 episodes, 0 skipped; RED won 19.0% of episodes
  - treatment: K/D 0.9999 (8554/8555), captures 124, wins 194
  - control: K/D 1.0001 (8550/8549), captures 119, wins 189
- rationale: When the carrier engages inside CarrierFireRange, the engage branch overrides its movement to walk TOWARD the attacker -- abandoning the run home to duel at 70% speed with a gun GV26 slows 3x for carriers (unmodeled here). Turret and legs ride separate mask bits: keep the aim and fire, let chooseMovement keep navigating home. Captures are the scoring unit.

## thief-hunt-role-split — REJECT (local A/B)

- when: 2026-07-31T07:41:17+00:00
- change: `baseline/objective.nim`: `elif f.ownStolen and (bot.role == HomeDefender or
      bot.tick - bot.carrierSeen <= ThiefFixTtl):` -> `elif f.ownStolen and (bot.role == HomeDefender or
      (bot.role in {Overwatch, MidGuard} and
       bot.tick - bot.carrierSeen <= ThiefFixTtl)):`
- treatment: local build  control: `jordan-ctf-candidate:v76` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-thief-hunt-role-split.jsonl, seeds 233000-233059 both ways)
- verdict: level: K/D -0.0145 CI [-0.0400, +0.0120], win rate +0.017 CI [-0.108, +0.142], captures -3 CI [-14, +8], n=120
- pooled: 120 episodes, 0 skipped; RED won 26.7% of episodes
  - treatment: K/D 0.9928 (2613/2632), captures 29, wins 58
  - control: K/D 1.0073 (2631/2612), captures 32, wins 56
- rationale: On a fresh thief fix every role walks the intercept, contradicting the design doc ('the back line hunts... attackers press on'). Fixes refresh in 40-tick pulses, so distant attackers flap between intercept and pedestal, draining the wave for chases they never arrive at. Restrict the walk to the back line; the engage stage still lifts every role's range cap and applies ThiefFocusBonus, so everyone with a line still shoots the thief.

## preaim-foe-pings — REJECT (local A/B)

- when: 2026-07-31T07:42:32+00:00
- change: `baseline/tactics.nim`: `if s.hot:
      score -= PreAimHotBonus` -> `if s.hot or s.foe:
      score -= PreAimHotBonus`
- treatment: local build  control: `jordan-ctf-candidate:v76` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-preaim-foe-pings.jsonl, seeds 234000-234059 both ways)
- verdict: level: K/D +0.0086 CI [-0.0197, +0.0381], win rate -0.042 CI [-0.142, +0.058], captures -8 CI [-17, +0], n=120
- pooled: 120 episodes, 0 skipped; RED won 15.8% of episodes
  - treatment: K/D 1.0043 (2555/2544), captures 29, wins 54
  - control: K/D 0.9957 (2555/2566), captures 37, wins 59
- rationale: preAimBearing bonuses only HOT pings -- landings that mark OUR OWN side's death; the shooter is elsewhere along an unseen line. A foe ping marks ground an enemy verifiably stood on a moment ago, which is why the grenade planner throws at foe pings and not hot ones. The idle gun is currently pulled toward our own corpses instead of the enemy's last confirmed position -- the same aim-direction vein where ScanArc paid +0.16 K/D.

## escort-screen-unpair — REJECT (local A/B)

- when: 2026-07-31T07:43:48+00:00
- change: `baseline/objective.nim`: `norm(bot.enemies[threat].pos - f.mateCarryPos) * 30.0` -> `norm(bot.enemies[threat].pos - f.mateCarryPos) * 70.0`
- treatment: local build  control: `jordan-ctf-candidate:v76` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-escort-screen-unpair.jsonl, seeds 235000-235059 both ways)
- verdict: level: K/D +0.0000 CI [+0.0000, +0.0000], win rate +0.000 CI [+0.000, +0.000], captures +0 CI [+0, +0], n=120
- pooled: 120 episodes, 0 skipped; RED won 21.7% of episodes
  - treatment: K/D 1.0000 (2589/2589), captures 34, wins 56
  - control: K/D 1.0000 (2589/2589), captures 34, wins 56
- rationale: MidGuard's carrier screen stands 30px from the carrier -- inside MateSpacing (40), so repulsion fights the objective, and inside NadeBlast (52), so screen and carrier die to one grenade. The field's own planGrenade explicitly targets pairs within one blast; the current geometry manufactures that target on the body whose death ends the run. 70px sits outside both while covering more of the bullet corridor.

## mate-masked-peek — REJECT (local A/B)

- when: 2026-07-31T07:45:04+00:00
- change: `baseline/engage.nim`: `if bot.friendlyBlocked(f.me, predicted, d):
        continue                        # prefer a target with an empty corridor` -> `if bot.friendlyBlocked(f.me, predicted, d):
        if d < f.blockedD:
          f.blockedD = d
          f.blockedAim = predicted
          f.haveBlocked = true
        continue                        # prefer a target with an empty corridor`
- treatment: local build  control: `jordan-ctf-candidate:v76` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-mate-masked-peek.jsonl, seeds 236000-236059 both ways)
- verdict: level: K/D -0.0284 CI [-0.0785, +0.0211], win rate -0.058 CI [-0.225, +0.117], captures -6 CI [-20, +8], n=120
- pooled: 120 episodes, 0 skipped; RED won 32.5% of episodes
  - treatment: K/D 0.9858 (2565/2602), captures 28, wins 53
  - control: K/D 1.0141 (2652/2615), captures 34, wins 60
- rationale: A fresh clear-ray target whose corridor a teammate occupies is skipped outright -- it neither engages nor becomes the peek candidate, so with six attackers in one pocket the nearest kill is frequently dropped. Recording it as a blocked candidate makes the peek branch pre-lay the aim and sidestep, releasing the shot when the corridor clears instead of re-acquiring from scratch.

## defender-intercept-by-flag — REJECT (local A/B)

- when: 2026-07-31T07:46:22+00:00
- change: `baseline/objective.nim`: `let d = dist(bot.enemies[i].pos, f.me)` -> `let d = dist(bot.enemies[i].pos, f.ownHome)`
- treatment: local build  control: `jordan-ctf-candidate:v76` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-defender-intercept-by-flag.jsonl, seeds 237000-237059 both ways)
- verdict: level: K/D +0.0093 CI [-0.0309, +0.0500], win rate +0.017 CI [-0.125, +0.158], captures +10 CI [-3, +23], n=120
- pooled: 120 episodes, 0 skipped; RED won 16.7% of episodes
  - treatment: K/D 1.0047 (2579/2567), captures 43, wins 59
  - control: K/D 0.9953 (2558/2570), captures 33, wins 57
- rationale: The HomeDefender breaks off its choke for the intruder nearest to ITSELF -- classic kiting bait: one attacker drags it off the choke while a second runs the pocket. Rank intruders by distance to OUR PEDESTAL instead, so the defender intercepts whichever body is actually about to steal. Enemy captures end episodes.

## midguard-shield-not-during-escort — REJECT (local A/B)

- when: 2026-07-31T07:47:36+00:00
- change: `baseline/objective.nim`: `if not f.iCarry and not f.hasShield and bot.role == MidGuard and` -> `if not f.iCarry and not f.mateCarry and not f.hasShield and bot.role == MidGuard and`
- treatment: local build  control: `jordan-ctf-candidate:v76` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-midguard-shield-not-during-escort.jsonl, seeds 238000-238059 both ways)
- verdict: level: K/D -0.0085 CI [-0.0259, +0.0071], win rate -0.008 CI [-0.058, +0.033], captures +1 CI [-4, +6], n=120
- pooled: 120 episodes, 0 skipped; RED won 19.2% of episodes
  - treatment: K/D 0.9957 (2570/2581), captures 35, wins 56
  - control: K/D 1.0043 (2582/2571), captures 34, wins 57
- rationale: The MidGuard shield trip vetoes iCarry and the thief chase but not mateCarry, and it runs AFTER chooseObjective assigned the carrier screen -- so the moment a mate lifts the flag, the designated screen walks the wrong way to shop a shield. The med kit and plasma detours both already veto mateCarry; this is the one that forgot.

## wipe-push — REJECT (local A/B)

- when: 2026-07-31T07:48:52+00:00
- change: `baseline/objective.nim`: `bot.tick - bot.gameStart > LatePushTick
  )` -> `bot.tick - bot.gameStart > LatePushTick or
    (bot.killsInit and bot.kills[bot.team] >= 20)
  )`
- treatment: local build  control: `jordan-ctf-candidate:v76` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-wipe-push.jsonl, seeds 239000-239059 both ways)
- verdict: level: K/D -0.0115 CI [-0.0374, +0.0152], win rate -0.008 CI [-0.142, +0.125], captures -3 CI [-15, +9], n=120
- pooled: 120 episodes, 0 skipped; RED won 23.3% of episodes
  - treatment: K/D 0.9943 (2595/2610), captures 34, wins 57
  - control: K/D 1.0058 (2612/2597), captures 37, wins 58
- rationale: Wins come only from capture or wiping the enemy's 24 lives, and our kill total says exactly how many they have left. At kills >= 20 the enemy has at most 4 lives over 8 seats, yet two posts still hold ground against an attack that can barely exist. Break the posts and swarm with all eight when the enemy is four deaths from elimination; mean team kills is ~21.6/episode, so the state is reached in roughly half of games.

## nade-farm-not-during-thief-chase — REJECT (local A/B)

- when: 2026-07-31T07:50:07+00:00
- change: `baseline/objective.nim`: `if not f.carryingNade and not f.iCarry and not f.mateCarry and not f.pocketRush:` -> `if not f.carryingNade and not f.iCarry and not f.mateCarry and
      not f.pocketRush and
      not (f.ownStolen and bot.tick - bot.carrierSeen <= ThiefFixTtl):`
- treatment: local build  control: `jordan-ctf-candidate:v76` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-nade-farm-not-during-thief-chase.jsonl, seeds 240000-240059 both ways)
- verdict: level: K/D +0.0016 CI [-0.0165, +0.0203], win rate +0.000 CI [-0.075, +0.075], captures -3 CI [-12, +6], n=120
- pooled: 120 episodes, 0 skipped; RED won 19.2% of episodes
  - treatment: K/D 1.0008 (2554/2552), captures 36, wins 58
  - control: K/D 0.9992 (2554/2556), captures 39, wins 58
- rationale: During a live thief fix -- the one state the code says outranks everything -- the grenade branch still rewrites the intercept into a detour of up to NadeFarmReach (500px!) to shop a corner grenade while the enemy runs our flag home. The med kit and shield branches both veto the thief chase; the grenade branch never got the veto and the farm promotions silently widened the hole.

## The league moved: GV27 -> current (ctf 0.7.136), and what survives it

- when: 2026-07-31T08:10:00+00:00
- The engine pin verified yesterday (beae1614, GV27, ctf v0.7.124) no longer
  describes production: the canonical ctf package is now **0.7.136**, sourced
  from `1047232f` -- live rotating diamond obstacles at mid, compact
  endzones, paint stains. Validated against PROD, not just the package
  registry: competition episode requests created at 08:03Z run 0.7.136.
  game_config and labels.nim are byte-identical across the move; the rules
  changes are all engine-side. sim/engine.pin now points at 1047232f,
  selfcheck passes, and the GV27 perf patch is retired as .gv27-stale
  (regenerate against the new tree; sim runs ~3x slower meanwhile).
- Consequence: every local verdict recorded earlier today (22 experiments,
  3 promotions) was measured under GV27 rules. Re-verified under the new
  pin, seed-paired mirrors at n=120 each
  (episodes/verify-gv29-*.jsonl, seeds 300000-/301000-):
  - ScanArc 28 vs 36: **level** (K/D -0.011 CI [-0.056, +0.033]). The +0.079
    GV27 edge does not reproduce, and does not reverse. v74/v75 stand.
  - MedKitDetour 120 vs 80: **REVERSED** -- the current tree's 120 measures
    K/D -0.050 CI [-0.083, -0.019] against 80. The v76 promotion (+0.097
    under GV27) looks like a GV27 artifact. `medkitdetour-gv29-revert` is
    queued to confirm at full sample and ship the revert if it holds.
- The hosted A/B era never had this failure mode: the league IS the
  instrument there. A pinned local engine can silently measure a game the
  league no longer plays, so the pin now gets validated against the
  canonical package's source_url before every session's first experiment.

## medkitdetour-gv29-revert — REJECT (local A/B)

- when: 2026-07-31T08:45:27+00:00
- change: `MedKitDetour` -> `80.0`
- treatment: local build  control: `jordan-ctf-candidate:v76` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-medkitdetour-gv29-revert.jsonl, seeds 241000-241059 both ways)
- verdict: REGRESSION: K/D -0.0293 CI [-0.0570, -0.0022], win rate -0.108 CI [-0.250, +0.033], captures +0 CI [-12, +12], n=120
- pooled: 120 episodes, 0 skipped; RED won 42.5% of episodes
  - treatment: K/D 0.9854 (2640/2679), captures 34, wins 51
  - control: K/D 1.0148 (2680/2641), captures 34, wins 64
- rationale: The v76 promotion measured +0.097 K/D under the GV27 sim, but the league now runs 0.7.136 (live mid diamonds, compact endzones) and under the re-pinned engine the current 120 measures K/D -0.050 CI [-0.083, -0.019] against 80 at n=120 (episodes/verify-gv29-medkit120-vs-80.jsonl). Confirm at full sample and revert the shipped regression if it holds.

## cooldown-sweep — REJECT (local A/B)

- when: 2026-07-31T08:49:08+00:00
- change: `baseline/tuning.nim`: `LaneTop* = 40.0              # open corridor above the mirrored obstacles` -> `LaneTop* = 40.0              # open corridor above the mirrored obstacles
  CooldownSweepArc* = 15       # brads of aim wiggle either side of the threat
                              # bearing during the cooldown duck; the cone
                              # half-angle is 32, so the threat stays in view`; `baseline/act.nim`: `f.desiredAim = bradsOf(bot.enemies[f.nearThreat].pos - f.me)` -> `f.desiredAim = floorMod(bradsOf(bot.enemies[f.nearThreat].pos - f.me) +
        (if (bot.tick div 6) mod 2 == 0: CooldownSweepArc else: -CooldownSweepArc), AimBrads)`
- treatment: local build  control: `jordan-ctf-candidate:v76` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-cooldown-sweep.jsonl, seeds 242000-242059 both ways)
- verdict: level: K/D -0.0328 CI [-0.0783, +0.0107], win rate +0.000 CI [-0.158, +0.158], captures -6 CI [-22, +10], n=120
- pooled: 120 episodes, 0 skipped; RED won 37.5% of episodes
  - treatment: K/D 0.9835 (2569/2612), captures 27, wins 52
  - control: K/D 1.0163 (2680/2637), captures 33, wins 52
- rationale: During the 12-tick cooldown duck the aim is parked dead on the threat bearing. The cone half-angle is 32 brads, so wiggling the aim +-15 brads keeps the threat in view at all times while raking the cone edge across +-47 -- wider contact warning at zero cost. The ScanArc trick, applied to the combat-cooldown state it never touched.

## duck-standoff — REJECT (local A/B)

- when: 2026-07-31T08:52:58+00:00
- change: `baseline/tuning.nim`: `LaneTop* = 40.0              # open corridor above the mirrored obstacles` -> `LaneTop* = 40.0              # open corridor above the mirrored obstacles
  DuckStandoffWeight* = 0.5    # px of extra walking each px of corner standoff
                              # is worth when picking a duck cell (peek's copy
                              # of the same idea runs 0.9)`; `baseline/navgrid.nim`: `let d = dist(p, me)
      if d >= bestD:` -> `let d = dist(p, me) - min(dist(p, threat), PeekStandoffCap) * DuckStandoffWeight
      if d >= bestD:`
- treatment: local build  control: `jordan-ctf-candidate:v76` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-duck-standoff.jsonl, seeds 243000-243059 both ways)
- verdict: level: K/D -0.0236 CI [-0.0538, +0.0061], win rate -0.158 CI [-0.317, +0.000], captures -9 CI [-26, +7], n=120
- pooled: 120 episodes, 0 skipped; RED won 39.2% of episodes
  - treatment: K/D 0.9883 (2615/2646), captures 30, wins 46
  - control: K/D 1.0119 (2644/2613), captures 39, wins 65
- rationale: The corner-distance principle is already in the tree for PEEK cells (PeekStandoffCap/Weight, whose comment makes exactly this argument), but findDuckCell still picks the NEAREST line-breaking cell -- hugging the corner, where one enemy step re-opens the line. Mirror the standoff term so ducks go deeper behind cover within the same search box.

## clock-phased-wave — REJECT (local A/B)

- when: 2026-07-31T08:56:29+00:00
- change: `baseline/act.nim`: `holdNow = bot.kills[bot.team] < HoldLineKills or
        bot.kills[bot.team] <= bot.kills[foeSide]` -> `holdNow = (bot.kills[bot.team] < HoldLineKills or
        bot.kills[bot.team] <= bot.kills[foeSide]) and
        ((bot.tick - bot.gameStart) div 300) mod 3 != 2`
- treatment: local build  control: `jordan-ctf-candidate:v76` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-clock-phased-wave.jsonl, seeds 244000-244059 both ways)
- verdict: level: K/D -0.0393 CI [-0.0779, +0.0000], win rate +0.008 CI [-0.158, +0.183], captures +6 CI [-9, +21], n=120
- pooled: 120 episodes, 0 skipped; RED won 50.0% of episodes
  - treatment: K/D 0.9806 (2625/2677), captures 36, wins 60
  - control: K/D 1.0198 (2673/2621), captures 30, wins 59
- rationale: Teammates are fogged, so the only sync channels are the scoreboard (HoldLineKills already uses it) and the SHARED CLOCK, which nothing uses. While holding the line, release the clamp for all eight seats simultaneously in periodic pulses -- every seat computes the same phase from (tick - gameStart), so the staged attackers surge across mid together instead of never. Attacks the drift-to-draw failure that timeout-equals-lose-lose makes expensive.

## corpse-track-cleanup — PROMOTE (local A/B)

- when: 2026-07-31T09:08:39+00:00
- change: `baseline/tuning.nim`: `LaneTop* = 40.0              # open corridor above the mirrored obstacles` -> `LaneTop* = 40.0              # open corridor above the mirrored obstacles
  CorpseClearRadius* = 80.0    # a foe-marked landing wipes the nearest track
                              # within this: that enemy is dead and respawning,
                              # and a kept track is a phantom to duck from`; `baseline/sense.nim`: `bot.sonar[i].foe = true
          dec want` -> `bot.sonar[i].foe = true
          var ci = -1
          var cd = CorpseClearRadius
          for j in 0 ..< bot.enemies.len:
            let dj = dist(bot.enemies[j].pos, bot.sonar[i].pos)
            if dj < cd:
              cd = dj
              ci = j
          if ci >= 0:
            bot.enemies[ci] = bot.enemies[^1]
            bot.enemies.setLen(bot.enemies.len - 1)
          dec want`
- treatment: local build  control: `jordan-ctf-candidate:v76` (the tree)
- shipped as: `jordan-ctf-candidate:v77`
- measured on: the local simulator, seed-paired mirrors (episodes/exp-corpse-track-cleanup.jsonl, seeds 245000-245059 both ways, seeds 245200-245339 both ways)
- verdict: separates positive on the pooled sample: K/D +0.0962 CI [+0.0718, +0.1215], win rate +0.318 CI [+0.233, +0.405], captures +69 CI [+41, +97], n=400
- pooled: 400 episodes, 0 skipped; RED won 51.5% of episodes
  - treatment: K/D 1.0499 (8713/8299), captures 149, wins 247
  - control: K/D 0.9537 (8523/8937), captures 80, wins 120
- rationale: When OUR kill registers next to a fresh landing, the enemy who died there keeps its track for up to 400 ticks -- the bot ducks from, routes around, and pre-aims at dead men. Delete the nearest track to a foe-marked landing. This REMOVES phantom intel, the direction the anti-timidity finding has paid in every time it was tested.

## onewaybonus40 — PROMOTE (local A/B)

- when: 2026-07-31T09:20:38+00:00
- change: `OneWayBonus` -> `40.0`
- treatment: local build  control: `jordan-ctf-candidate:v77` (the tree)
- shipped as: `jordan-ctf-candidate:v78`
- measured on: the local simulator, seed-paired mirrors (episodes/exp-onewaybonus40.jsonl, seeds 246000-246059 both ways, seeds 246200-246339 both ways)
- verdict: separates positive on the pooled sample: K/D +0.0272 CI [+0.0037, +0.0510], win rate +0.018 CI [-0.072, +0.105], captures +50 CI [+22, +78], n=400
- pooled: 400 episodes, 0 skipped; RED won 31.2% of episodes
  - treatment: K/D 1.0134 (8919/8801), captures 125, wins 191
  - control: K/D 0.9862 (8415/8533), captures 75, wins 184
- rationale: A post on the seeing end of a one-way pair over an enemy lane gets shots the victim cannot answer with vision -- the closest thing to a free kill the fog model offers, and the current scorer prices it at zero. The table is real and asymmetric on the arena: 6 of 52 red candidates and 5 of 50 blue hold such cells (13 and 16 clear-ray pairs), the sides do not mirror, and at any bonus past ~9 both sides trade 8.4px of base score for a peek holding one more (red 2 to 3) or three more (blue 3 to 6) one-way cells. 40px per cell prices one unanswerable sightline like ~57px of extra firing line (the line trades at 0.7) and half a PeekStandoffCap of safety credit, so a couple of cells can move the post between near-tied peeks but cannot outbid a genuinely longer lane. Nav-build cost at the test value measured +3 percent of an episode; zero at 0.0.

## onewaybonus40-further — REJECT (local A/B)

- when: 2026-07-31T09:24:19+00:00
- change: `OneWayBonus` -> `80.0`
- treatment: local build  control: `jordan-ctf-candidate:v78` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-onewaybonus40-further.jsonl, seeds 247000-247059 both ways)
- verdict: level: K/D +0.0000 CI [+0.0000, +0.0000], win rate +0.000 CI [+0.000, +0.000], captures +0 CI [+0, +0], n=120
- pooled: 120 episodes, 0 skipped; RED won 65.0% of episodes
  - treatment: K/D 1.0000 (2612/2612), captures 27, wins 56
  - control: K/D 1.0000 (2612/2612), captures 27, wins 56
- rationale: Derived from onewaybonus40: OneWayBonus paid at 40.0, so walk the same way again to 80 and find where it stops paying.

## medkitdetour, both directions, and what two contradicting screens teach

- when: 2026-07-31T09:30:00+00:00
- Under the re-pinned engine, the same comparison was measured twice at
  n=120 with different seed batches and SEPARATED IN OPPOSITE DIRECTIONS:
  the ad-hoc verification read 120 as -0.050 [-0.083, -0.019] against 80
  (seeds 301000-), and the loop's `medkitdetour-gv29-revert` read 80 as
  -0.029 [-0.057, -0.002] against 120 (fresh seeds). Both intervals exclude
  zero; both cannot be right. The honest reading: MedKitDetour under the
  current engine is LEVEL, the tree correctly keeps 120, and a screen-size
  separation whose bound sits within ~0.03 of zero is weaker evidence than
  its interval claims -- seed-batch heterogeneity is real variance the
  seed-paired bootstrap cannot see. The loop's own escalate-then-confirm
  design already defends promotions against this; the earlier ledger claim
  that v76 "reversed" was a one-screen overread and is retracted.

## corpseclear160 — REJECT (local A/B)

- when: 2026-07-31T09:30:58+00:00
- change: `CorpseClearRadius` -> `160.0`
- treatment: local build  control: `jordan-ctf-candidate:v78` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-corpseclear160.jsonl, seeds 248000-248059 both ways)
- verdict: level: K/D -0.0062 CI [-0.0536, +0.0416], win rate -0.050 CI [-0.225, +0.125], captures +1 CI [-13, +15], n=120
- pooled: 120 episodes, 0 skipped; RED won 58.3% of episodes
  - treatment: K/D 0.9970 (2624/2632), captures 32, wins 56
  - control: K/D 1.0031 (2579/2571), captures 31, wins 62
- rationale: corpse-track-cleanup landed at radius 80 for +0.096 K/D, +32 points of win rate and +69 captures -- the largest promotion in this repository. The knob that shipped with it has never been swept: 160 deletes more phantom tracks per foe-marked landing, the same direction that just paid, at the risk of deleting a live second enemy who stood near the casualty.

## Backlog

Ideas raised on 2026-07-31 that never got an experiment live in
[BACKLOG.md](BACKLOG.md) — features (shout channel, diamond-band
mitigation, one-way fog cousins), the untouched side-asymmetry work, knob
axes swept at one value, GV-invalidated re-asks, and unexploited engine
facts. A backlog entry that gets measured moves into this ledger.

## corpseclear40 — PROMOTE-LOCAL (local A/B)

- when: 2026-07-31T14:27:31+00:00
- change: `CorpseClearRadius` -> `40.0`
- treatment: local build  control: `jordan-ctf-candidate:v78` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-corpseclear40.jsonl, seeds 249000-249059 both ways, seeds 249200-249339 both ways)
- verdict: separates positive on the pooled sample: K/D +0.0307 CI [+0.0060, +0.0567], win rate +0.065 CI [-0.015, +0.145], captures +39 CI [+13, +65], n=400; SHIP FAILED: amd64 build failed:

no /workspace/.bot-deps/paths.cfg -- clone bot deps first

- pooled: 400 episodes, 0 skipped; RED won 71.5% of episodes
  - treatment: K/D 1.0153 (8782/8650), captures 131, wins 205
  - control: K/D 0.9846 (8441/8573), captures 92, wins 179
- rationale: corpse-track-cleanup shipped at radius 80 for +0.096 K/D, the largest promotion in this repository, and 160 came back level. That brackets the axis on one side only: 40 is the other end, and it asks the question the promotion left open -- is 80 the optimum, or is it merely the first value tried on a knob whose benefit saturates well below it? A tighter radius deletes a track only when the landing is nearly on top of it, which is the conservative reading of the same mechanism: fewer phantom tracks removed, but also no chance of deleting a LIVE second enemy standing near the casualty. If 40 is level with 80 the knob is flat and the promotion was the mechanism, not the number; if 40 is worse, 80 is a real peak.

## Tree and league diverged here — read the control labels with care

- when: 2026-07-31T14:35:00+00:00
- `corpseclear40` promoted into `bot/` but could NOT be shipped: the session's
  Softmax auth code was already spent (the exchange endpoint answered
  `410 Gone`), and the loop process in flight still held the pre-Docker
  `ship()`, which looked for a nix/zig cross-compile toolchain this amd64
  container does not have.
- Consequence: `research/state.json` still names `jordan-ctf-candidate:v78`
  as baseline and champion, but the TREE is past it (CorpseClearRadius 80 ->
  40). Every ledger entry from `corpseclear40` onward carries
  `control: jordan-ctf-candidate:v78` as a LABEL only. The build actually
  measured against is always `bot/` as it stood at the time, which is what
  the local loop compares and what makes the one-variable isolation real --
  so the VERDICTS are unaffected. Only the ref in the control line is stale.
- The module docstring's claim that "the tree and the submitted lineage never
  diverge" holds only while shipping works. It did not here.
- To repair: get a fresh auth code, restart the loop (it picks up the Docker
  ship path added in 4eac9b0), and ship the tree once. The next promotion
  re-ships the WHOLE tree, so no landed change is lost -- the league just
  skips the intermediate versions.

## duckrange260 — REJECT (local A/B)

- when: 2026-07-31T14:48:46+00:00
- change: `DuckRange` -> `260.0`
- treatment: local build  control: `jordan-ctf-candidate:v78` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-duckrange260.jsonl, seeds 250000-250059 both ways, seeds 250200-250339 both ways)
- verdict: level: K/D -0.0169 CI [-0.0416, +0.0069], win rate -0.005 CI [-0.090, +0.080], captures -10 CI [-39, +20], n=400
- pooled: 400 episodes, 0 skipped; RED won 70.0% of episodes
  - treatment: K/D 0.9916 (8454/8526), captures 123, wins 188
  - control: K/D 1.0085 (8563/8491), captures 133, wins 190
- rationale: The anti-timidity bet the backlog records as dropped in favour of exposedcost10 and never re-queued. DuckRange 340 is the radius within which a REMEMBERED threat makes the bot break off and duck on cooldown -- a reaction to intel, not to a body, and every measured result here that removed phantom intel has paid (corpse-track-cleanup +0.096, the strongest single finding on record). 340px is over a quarter of the map width, so a stale track anywhere in the neighbourhood can park the bot behind cover; 260 keeps the duck for threats that could plausibly be on us within the cooldown and stops paying ground for the rest.

## duckrange260-reverse — REJECT (local A/B)

- when: 2026-07-31T15:20:59+00:00
- change: `DuckRange` -> `420.0`
- treatment: local build  control: `jordan-ctf-candidate:v78` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-duckrange260-reverse.jsonl, seeds 251000-251059 both ways, seeds 251200-251339 both ways, seeds 251400-251499 both ways)
- verdict: level: K/D +0.0102 CI [-0.0097, +0.0297], win rate -0.008 CI [-0.075, +0.057], captures -13 CI [-47, +20], n=600
- pooled: 600 episodes, 0 skipped; RED won 68.5% of episodes
  - treatment: K/D 1.0051 (12818/12753), captures 175, wins 281
  - control: K/D 0.9949 (12764/12829), captures 188, wins 286
- rationale: Derived from duckrange260: DuckRange measured worse at 260.0, so the constant is worth testing in the other direction at 420.

## Tree and league re-synced at v79

- when: 2026-07-31T15:25:00+00:00
- A fresh auth code arrived, so the tree as of `corpseclear40` was built
  through bot/Dockerfile.sandbox, both image guards passed (/bin/baseline an
  executable REGULAR FILE, and the run demands COWORLD_PLAYER_WS_URL), and it
  uploaded as `jordan-ctf-candidate:v79` and submitted to the league with
  `--auto-champion always` (submission sub_40b41fc5-0e2b-4c75-80e3-fad727759d44).
- `research/state.json` baseline and champion now read v79, which is the ref
  that actually corresponds to the tree. The stale-label window opened at
  `corpseclear40` and closes here: the entries for `corpseclear40`,
  `duckrange260` and `duckrange260-reverse` name v78 as control, and for those
  three the label is one promotion behind the build they were really measured
  against. The verdicts are unaffected -- the control build is always `bot/`
  as it stood -- but do not read those three refs as exact.
- The loop was restarted at this boundary so it picks up the Docker ship path
  (4eac9b0); the process in flight before it still held the pre-fix `ship()`.

## diamond-sweep-paint — REJECT (local A/B)

- when: 2026-07-31T15:28:37+00:00
- change: `baseline/tuning.nim`: `NavCell* = 8                 # nav grid cell size in px` -> `NavCell* = 8                 # nav grid cell size in px
  SpinPaintScale* = 1.0        # fraction of a spinning center diamond's
                              # radius painted as wall into our walkability
                              # copy at nav-grid build. 0.0 keeps the frozen
                              # snapshot frame; 1.0 is the swept disc the
                              # turn can ever cover (the engine's spinSwept);
                              # ~0.71 would paint only what is stone at EVERY
                              # frame (spinAlways). Past 1.0 the paint escapes
                              # the disc fov.nim erases and would move the
                              # one-way fog table too`; `baseline/navgrid.nim`: `import
  bitworld/profile,
  protocols,
  posts,
  grid,
  world,
  geometry,
  tuning` -> `import
  bitworld/profile,
  protocols,
  posts,
  fov,
  grid,
  world,
  geometry,
  tuning`; `baseline/navgrid.nim`: `proc buildNavGrid*(bot: Bot, client: ProtocolClient) {.measure.} =
  ## Erodes the pixel walkability mask into a footprint-safe nav grid, then
  ## derives the cover model (cover cells, overwatch post, defender choke).
  adoptMapSize(client)` -> `proc paintSpinDiscs(client: ProtocolClient) =
  ## The eight spinning center diamonds are LIVE geometry (fov.nim): the
  ## bake leaves them out and the engine restamps their rotated footprint
  ## into the movement, bullet and vision masks every time the spin frame
  ## advances, while the walkability sprite is sent ONCE -- so our mask
  ## holds one frozen frame of a shape that keeps turning. Paint each
  ## diamond's swept disc into our copy: the rotated L1 footprint never
  ## leaves the L2 disc of its own radius, so this only ever ADDS wall and
  ## the model becomes conservative rather than wrong -- no clear line, and
  ## no cover, through ground the stone is about to swing back into.
  ##
  ## fov.nim's occlusion build erases exactly this disc, so at scale <= 1.0
  ## the one-way fog table is untouched. A no-op on any map but the arena,
  ## for which alone spinDiamonds() vendors geometry.
  if SpinPaintScale <= 0.0:
    return
  let
    w = client.walkabilityWidth
    h = client.walkabilityHeight
  for d in spinDiamonds():
    let
      r = int(float(d.r) * SpinPaintScale)
      r2 = r * r
    for py in max(0, d.cy - r) .. min(h - 1, d.cy + r):
      for px in max(0, d.cx - r) .. min(w - 1, d.cx + r):
        let
          dx = px - d.cx
          dy = py - d.cy
        if dx * dx + dy * dy <= r2:
          client.walkabilityMask[py * w + px] = false

proc buildNavGrid*(bot: Bot, client: ProtocolClient) {.measure.} =
  ## Erodes the pixel walkability mask into a footprint-safe nav grid, then
  ## derives the cover model (cover cells, overwatch post, defender choke).
  adoptMapSize(client)
  paintSpinDiscs(client)`
- treatment: local build  control: `jordan-ctf-candidate:v79` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-diamond-sweep-paint.jsonl, seeds 252000-252059 both ways)
- verdict: wins separate NEGATIVE: K/D -0.0815 CI [-0.1258, -0.0351], win rate -0.183 CI [-0.350, -0.008], captures -17 CI [-32, -2], n=120
- pooled: 120 episodes, 0 skipped; RED won 46.7% of episodes
  - treatment: K/D 0.9593 (2497/2603), captures 26, wins 44
  - control: K/D 1.0408 (2703/2597), captures 43, wins 66
- rationale: `engage.nim:106` gates every shot on `client.pixelRayClear(f.me, predicted)`, and `grid.nim:24` answers that ray out of `client.walkabilityMask` — one walkability sprite, built once per seat at connect and never resent, holding ONE frame of eight diamonds the engine restamps into its movement/bullet/vision masks every 4 ticks. So today the bot fires, paths, ducks and picks cover posts through mid against a frozen silhouette: phantom-clear shots into stone that swung back, phantom cover behind stone that swung away. This paints each diamond's swept disc (radius 30, the union over the turn — the rotated L1 footprint never leaves it) into the mask at `buildNavGrid`, before the footprint erosion, so rays, `cellWalkable`, `coverCell` and exposure all read stone wherever stone can be. It only ever ADDS wall, and `fov.nim`'s occlusion build already erases exactly this disc, so the one-way fog table does not move. Hypothesis, not a result: the conservative model may cost more real openings than the false ones it removes.
