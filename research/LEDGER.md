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

## chokehold-oneway — REJECT (local A/B)

- when: 2026-07-31T15:35:08+00:00
- change: `baseline/posts.nim`: `proc pickPost*(bot: Bot, client: ProtocolClient) =` -> `proc pickChoke*(bot: Bot, client: ProtocolClient): Vec =
  ## The defender's hold point, priced with the same one-way term scanPost
  ## gives an overwatch peek. The scan runs on `homeSign` — the mirrored
  ## direction findEnemyPosts already scores — because that is the way the
  ## defender's own guns point: its target band is the ground an intruder
  ## crosses toward our pedestal. Candidates are exactly snapToCover's (the
  ## cover cells of the same 6-cell box), so only the score changes. Only
  ## the HomeDefender seat ever reads chokeHold, so no other seat pays the
  ## scan.
  let p = chokeSpot(bot.team)
  if bot.role != HomeDefender or OneWayBonus == 0.0 or not oneWayFogReady():
    return bot.snapToCover(p)
  result = p
  let
    c0 = bot.nearestOpenCell(cellOf(p))
    cx = c0 mod GridW
    cy = c0 div GridW
  var
    bestScore = 1e18
    oneWay = bot.newOneWayScan(client, homeSign(bot.team))
  for dy in -6 .. 6:
    for dx in -6 .. 6:
      let
        nx = cx + dx
        ny = cy + dy
      if nx < 0 or ny < 0 or nx >= GridW or ny >= GridH:
        continue
      let nc = ny * GridW + nx
      if not bot.coverCell[nc]:
        continue
      let q = cellCenter(nc)
      let score = dist(q, p) -
        float(oneWay.oneWayCount(client, nc, q)) * OneWayBonus
      if score < bestScore:
        bestScore = score
        result = q

proc pickPost*(bot: Bot, client: ProtocolClient) =`; `baseline/navgrid.nim`: `bot.chokeHold = bot.snapToCover(chokeSpot(bot.team))` -> `bot.chokeHold = bot.pickChoke(client)`
- treatment: local build  control: `jordan-ctf-candidate:v79` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-chokehold-oneway.jsonl, seeds 253000-253059 both ways)
- verdict: REGRESSION: K/D -0.0612 CI [-0.1017, -0.0220], win rate -0.158 CI [-0.317, +0.008], captures -3 CI [-18, +12], n=120
- pooled: 120 episodes, 0 skipped; RED won 40.8% of episodes
  - treatment: K/D 0.9700 (2583/2663), captures 30, wins 45
  - control: K/D 1.0312 (2645/2565), captures 33, wins 64
- rationale: navgrid.nim:120 sets the defender's hold point as `bot.chokeHold = bot.snapToCover(chokeSpot(bot.team))` — nearest cover cell in a 6-cell box, scored on distance alone. This is the second customer the one-way plan named and never wired: OneWayBonus=40 is promoted but pays only inside scanPost, and HomeDefender is the seat that camps longest on one cell. The patch scores the SAME candidate set with the SAME term (posts.nim's newOneWayScan/oneWayCount), no new constant and no second mechanism, on eSign = homeSign(bot.team) — the direction findEnemyPosts already scans, whose target band is the ground an intruder crosses toward our pedestal. The defender would then prefer a choke cell that sees that approach one-way over one that merely sits nearest. Hypothesis only: the box caps displacement at ~147px, and the extra scan costs nav-build time on one seat of eight.

## peek-friendly-corridor — REJECT (local A/B)

- when: 2026-07-31T15:41:43+00:00
- change: `baseline/tuning.nim`: `PeekStandoffWeight* = 0.9    # px of extra walking each px of it is worth` -> `PeekStandoffWeight* = 0.9    # px of extra walking each px of it is worth
  PeekMateCorridorCost* = 140.0
                              # px of effective extra walking charged to a
                              # peek cell that opens the WALL ray but leaves
                              # a remembered mate in the bullet corridor: the
                              # shot it buys is one friendlyBlocked refuses.
                              # The stand-off term can move a score by at
                              # most PeekStandoffCap * PeekStandoffWeight
                              # (86.4), so this outranks it`; `baseline/navgrid.nim`: `let d = dist(p, me) -
        min(dist(p, corner), PeekStandoffCap) * PeekStandoffWeight
      if d >= bestD:
        continue
      if not bot.gridRayClear(me, p):
        continue
      if not client.pixelRayClear(p, aim):
        continue
      bestD = d` -> `let base = dist(p, me) -
        min(dist(p, corner), PeekStandoffCap) * PeekStandoffWeight
      if base >= bestD:
        continue
      if not bot.gridRayClear(me, p):
        continue
      if not client.pixelRayClear(p, aim):
        continue
      # The wall ray is only half of the firing line. A cell that opens it
      # but leaves a remembered mate inside the bullet corridor buys a shot
      # the fire gate will refuse -- the bullet is a corridor hitscan and
      # the server kills the NEAREST body in it -- so that peek spends the
      # exposure and returns no shot at all. Charge it, and the sidestep
      # prefers a cell whose FRIENDLY line is clear as well. Spelled like
      # tactics.friendlyBlocked, which sits one layer above this file and
      # so cannot be called from here.
      var d = base
      let
        aimD = dist(p, aim)
        fireDir = bradsDir(bradsOf(aim - p))
      for m in bot.mates:
        let
          age = float(bot.tick - m.lastSeen)
          rel = m.pos - p
          along = dot(rel, fireDir)
        if age <= 36.0 and along > 0.0 and along < aimD + 14.0 and
            abs(cross(rel, fireDir)) < CorridorHalfWidth + age * 0.35:
          d = base + PeekMateCorridorCost
          break
      if d >= bestD:
        continue
      bestD = d`
- treatment: local build  control: `jordan-ctf-candidate:v79` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-peek-friendly-corridor.jsonl, seeds 254000-254059 both ways)
- verdict: level: K/D +0.0413 CI [-0.0062, +0.0907], win rate -0.008 CI [-0.167, +0.150], captures +19 CI [+6, +32], n=120
- pooled: 120 episodes, 0 skipped; RED won 63.3% of episodes
  - treatment: K/D 1.0205 (2635/2582), captures 43, wins 58
  - control: K/D 0.9792 (2493/2546), captures 24, wins 59
- rationale: act.nim's peek branch calls `bot.findPeekCell(client, f.me, f.blockedAim)` and steps to whatever cell it returns. That scoring loop tests exactly two rays -- `gridRayClear(me, p)` and `pixelRayClear(p, aim)` -- and neither knows a teammate exists, so the sidestep can land on a cell whose bullet corridor a mate occupies. Next tick the wall ray is open, engage.nim's `friendlyBlocked` gate hits and does `continue`, dropping the target entirely: the peek has bought exposure in the open and no shot. This charges PeekMateCorridorCost to any candidate whose FRIENDLY corridor a remembered mate sits in, inside the same search box and scoring loop, so the search prefers a cell where the shot will actually be taken. It is a preference, not a veto -- with no clear cell the peek still happens. Hypothesis: six attackers in one pocket should make masked lines common, but nothing measures how often the chosen peek cell is one.

## peek-friendly-corridor-reask — REJECT (local A/B)

- when: 2026-07-31T15:54:42+00:00
- change: `baseline/tuning.nim`: `PeekStandoffWeight* = 0.9    # px of extra walking each px of it is worth` -> `PeekStandoffWeight* = 0.9    # px of extra walking each px of it is worth
  PeekMateCorridorCost* = 140.0
                              # px of effective extra walking charged to a
                              # peek cell that opens the WALL ray but leaves
                              # a remembered mate in the bullet corridor: the
                              # shot it buys is one friendlyBlocked refuses.
                              # The stand-off term can move a score by at
                              # most PeekStandoffCap * PeekStandoffWeight
                              # (86.4), so this outranks it`; `baseline/navgrid.nim`: `let d = dist(p, me) -
        min(dist(p, corner), PeekStandoffCap) * PeekStandoffWeight
      if d >= bestD:
        continue
      if not bot.gridRayClear(me, p):
        continue
      if not client.pixelRayClear(p, aim):
        continue
      bestD = d` -> `let base = dist(p, me) -
        min(dist(p, corner), PeekStandoffCap) * PeekStandoffWeight
      if base >= bestD:
        continue
      if not bot.gridRayClear(me, p):
        continue
      if not client.pixelRayClear(p, aim):
        continue
      # The wall ray is only half of the firing line. A cell that opens it
      # but leaves a remembered mate inside the bullet corridor buys a shot
      # the fire gate will refuse -- the bullet is a corridor hitscan and
      # the server kills the NEAREST body in it -- so that peek spends the
      # exposure and returns no shot at all. Charge it, and the sidestep
      # prefers a cell whose FRIENDLY line is clear as well. Spelled like
      # tactics.friendlyBlocked, which sits one layer above this file and
      # so cannot be called from here.
      var d = base
      let
        aimD = dist(p, aim)
        fireDir = bradsDir(bradsOf(aim - p))
      for m in bot.mates:
        let
          age = float(bot.tick - m.lastSeen)
          rel = m.pos - p
          along = dot(rel, fireDir)
        if age <= 36.0 and along > 0.0 and along < aimD + 14.0 and
            abs(cross(rel, fireDir)) < CorridorHalfWidth + age * 0.35:
          d = base + PeekMateCorridorCost
          break
      if d >= bestD:
        continue
      bestD = d`
- treatment: local build  control: `jordan-ctf-candidate:v79` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-peek-friendly-corridor-reask.jsonl, seeds 255000-255059 both ways)
- verdict: level: K/D +0.0055 CI [-0.0346, +0.0470], win rate -0.050 CI [-0.192, +0.092], captures +0 CI [-14, +15], n=120
- pooled: 120 episodes, 0 skipped; RED won 65.0% of episodes
  - treatment: K/D 1.0027 (2597/2590), captures 36, wins 54
  - control: K/D 0.9972 (2518/2525), captures 36, wins 60
- rationale: A RE-ASK, not a new idea: peek-friendly-corridor was measured on 2026-07-31 and thrown away by a decision-rule defect rather than by its numbers. It screened K/D +0.0413 CI [-0.0062, +0.0907] -- z = 1.67, twice the escalation threshold, missing zero by 0.006 -- with captures SEPARATING positive at +19 CI [+6, +32]. It was rejected because the near-miss gate demanded both metrics be non-negative and win rate read -0.008, a twentieth of its own noise (CI +-0.16). The gate now tolerates half a standard error (NEAR_MISS_TOLERANCE), so this buys the confirmation README.md always said it should. The generation counter has advanced, so it draws a DISJOINT seed batch: this is an independent sample, not a re-count of the same episodes. Underlying mechanism unchanged -- findPeekCell scores wall rays only, so teach it to prefer cells whose FRIENDLY firing corridor also clears.

## Two screens of one comparison, and what a 120-episode screen is worth

- when: 2026-07-31T15:56:00+00:00
- `peek-friendly-corridor` and `peek-friendly-corridor-reask` are the SAME
  change measured twice at n=120 on DISJOINT seed batches:
    batch A: K/D +0.0413 CI [-0.0062, +0.0907], captures +19 CI [+6, +32]
    batch B: K/D +0.0055 CI [-0.0346, +0.0470], captures +0  CI [-14, +15]
  Batch A's captures SEPARATED POSITIVE and its K/D missed zero by 0.006.
  Batch B is nothing. Neither batch is wrong; the screen is just weaker than
  its intervals claim.
- This independently reproduces the `medkitdetour` finding above -- seed-batch
  heterogeneity is real variance the seed-paired bootstrap cannot see -- and
  extends it to CAPTURES, which README.md already says should only ever veto.
  A captures interval that excludes zero at n=120 is not evidence of a
  capture benefit. Here it was +19 [+6, +32] on one batch and +0 on the next.
- Practical rule this supports: nothing is believed off one screen, whichever
  direction it points and however tidy the interval looks. The
  escalate-then-confirm design already encodes this; the episode above is
  what it is defending against.
- Note the order of events honestly. The near-miss gate was widened
  (NEAR_MISS_TOLERANCE) BECAUSE batch A looked strong, and the re-ask it
  bought then came back level. The rule change still stands on its own
  argument -- it aligns the code with README.md's stated policy, and a looser
  SCREEN can only cost episodes, never cause a promotion, because promotion
  still requires separation on the pooled confirmation. But the case that
  motivated it evaporated, and that belongs in the record next to it.

## scanarcblue32 — REJECT (local A/B)

- when: 2026-07-31T16:09:22+00:00
- change: `ScanArcBlue` -> `32`
- treatment: local build  control: `jordan-ctf-candidate:v79` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-scanarcblue32.jsonl, seeds 256000-256059 both ways)
- verdict: level: K/D +0.0039 CI [-0.0094, +0.0178], win rate +0.000 CI [-0.100, +0.100], captures +0 CI [-11, +10], n=120
- pooled: 120 episodes, 0 skipped; RED won 70.8% of episodes
  - treatment: K/D 1.0020 (2556/2551), captures 37, wins 59
  - control: K/D 0.9980 (2554/2559), captures 37, wins 59
- rationale: ScanArc is the knob that paid TWICE on this policy (24 -> 28 -> 36, +0.16 K/D between them), which makes it the right first axis to split by side. The plumbing landed inert in a direct commit -- 12 seeds, 24 episodes, every mirrored pair bit-identical on gameHash -- because the loop structurally cannot land an inert patch: apply_edits works on a scratch copy, land() runs only from promote(), and a no-op measures level and is discarded. Blue is the side whose sweep this moves; the other keeps 28. Read the DILUTION honestly: a seed-paired mirror puts the treatment build on blue in only ONE of the two directions, so the pooled gap is about HALF the true one-side effect and this needs roughly four times the episodes of a shared knob for equal power. A level result here is therefore weak evidence of no effect, not strong. Blue is also the side the operator's brief says concedes the fog and nav seams by construction, so it is the side with more to gain from a wider sweep.

## What a per-side knob actually measures, and a correction

- when: 2026-07-31T16:12:00+00:00
- `scanarcblue32` is the first side-specific experiment this repository has
  run. Its rationale (and the driver's note when it was queued) claimed a
  one-side knob needs "roughly four times the episodes of a shared knob for
  equal power". THAT IS WRONG, and the run itself shows why.
- The dilution half of the claim is right. A seed-paired mirror puts the
  treatment build on blue in only ONE of the two directions, so direction 1
  is baseline-vs-baseline and only direction 2 can differ. The pooled gap is
  therefore about HALF the true blue-only effect.
- The half that was wrong: the NOISE collapses with it. 35 of 60 seed pairs
  came back bit-identical on gameHash -- in 58% of episodes the knob changed
  no decision at all -- so those pairs contribute exactly zero to the paired
  bootstrap. The interval came out K/D +-0.0136 at n=120, roughly THREE TIMES
  TIGHTER than a shared knob's (corpseclear40 ran +-0.044 at the same n).
  This is the same collapsed-standard-error effect the module docstring
  already describes as the reason the practical-significance floors exist;
  nobody had noticed it cuts the other way for a side-specific ask.
- So read a per-side result by DOUBLING it. scanarcblue32 measured +0.0039
  CI [-0.0094, +0.0178] pooled, i.e. a blue-only effect of about +0.008 CI
  [-0.019, +0.036]. That is a normal-strength null, not a weak one: blue-side
  ScanArc 32 does nothing worth about +-0.036 K/D. The earlier claim that "a
  level result here is weak evidence of no effect" was too pessimistic.
- One thing this does NOT rescue: a change that trades a red gain for a blue
  loss inside ONE build still cancels exactly, because the treatment holds
  red in one direction and blue in the other. That trap is real and separate
  from the dilution arithmetic above.
- `scanarcred32` was already in flight when this was worked out, so its
  ledger entry carries the uncorrected rationale. This note is the
  correction for both.

## scanarcred32 — REJECT (local A/B)

- when: 2026-07-31T16:29:57+00:00
- change: `ScanArcRed` -> `32`
- treatment: local build  control: `jordan-ctf-candidate:v79` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-scanarcred32.jsonl, seeds 257000-257059 both ways, seeds 257200-257339 both ways)
- verdict: level: K/D -0.0101 CI [-0.0232, +0.0028], win rate -0.010 CI [-0.058, +0.040], captures +15 CI [-1, +32], n=400
- pooled: 400 episodes, 0 skipped; RED won 69.5% of episodes
  - treatment: K/D 0.9950 (8478/8521), captures 132, wins 190
  - control: K/D 1.0051 (8513/8470), captures 117, wins 194
- rationale: ScanArc is the knob that paid TWICE on this policy (24 -> 28 -> 36, +0.16 K/D between them), which makes it the right first axis to split by side. The plumbing landed inert in a direct commit -- 12 seeds, 24 episodes, every mirrored pair bit-identical on gameHash -- because the loop structurally cannot land an inert patch: apply_edits works on a scratch copy, land() runs only from promote(), and a no-op measures level and is discarded. Red is the side whose sweep this moves; the other keeps 28. Read the DILUTION honestly: a seed-paired mirror puts the treatment build on red in only ONE of the two directions, so the pooled gap is about HALF the true one-side effect and this needs roughly four times the episodes of a shared knob for equal power. A level result here is therefore weak evidence of no effect, not strong. Red wins ~63% of episodes whatever build holds it, so red's optimum need not be blue's: the side that is already ahead may want the sweep spent differently.

## Per-side ScanArc: both sides level, and a third screen that did not hold

- when: 2026-07-31T16:31:00+00:00
- The first two side-specific experiments this repository has ever run are
  both decided, and neither found a side difference:
    `scanarcblue32`  level  K/D +0.0039 CI [-0.0094, +0.0178]  n=120
    `scanarcred32`   level  K/D -0.0101 CI [-0.0232, +0.0028]  n=400
  Doubling for the one-side dilution: blue about +0.008, red about -0.020,
  both comfortably inside noise. ScanArc 28 is the right number on BOTH
  sides, and the hypothesis that the sides want different sweeps is not
  supported for this knob. That is a result about ScanArc, not about the
  per-side idea: the plumbing is landed and 66 other constants remain.
- `scanarcred32` is the session's THIRD screen that did not survive its own
  confirmation, and the most dramatic -- it changed SIGN:
    screen  n=120  K/D +0.0110, win rate +0.083, captures +9  -> ESCALATE
    pooled  n=400  K/D -0.0101, win rate -0.010, captures +15 -> REJECT
  With the other two (`peek-friendly-corridor` +0.0413 -> +0.0055 on a fresh
  batch; `duckrange260-reverse` +0.0282 at 120 -> +0.0136 at 400 -> +0.0102
  at 600), that is three for three today. A 120-episode screen on this
  instrument is triage and nothing more, whichever way it points.
- Worth stating because it cuts against the loop's own economics note: the
  README fits a K/D half-width of ~0.63/sqrt(episodes) hosted and this file
  records ~0.50/sqrt(episodes) locally, which at n=120 predicts +-0.046 --
  and the screens above sat inside that. The intervals are not obviously
  too narrow; what is happening is that a screen selected FOR looking good
  is a biased sample of screens, which is exactly why escalate-then-confirm
  exists and why nothing here is believed off one look.

## scanarcred32-reverse — REJECT (local A/B)

- when: 2026-07-31T16:50:30+00:00
- change: `ScanArcRed` -> `24`
- treatment: local build  control: `jordan-ctf-candidate:v79` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-scanarcred32-reverse.jsonl, seeds 258000-258059 both ways, seeds 258200-258339 both ways)
- verdict: level: K/D -0.0077 CI [-0.0285, +0.0120], win rate +0.033 CI [-0.048, +0.110], captures +18 CI [-10, +46], n=400
- pooled: 400 episodes, 0 skipped; RED won 59.5% of episodes
  - treatment: K/D 0.9961 (8513/8546), captures 128, wins 193
  - control: K/D 1.0039 (8561/8528), captures 110, wins 180
- rationale: Derived from scanarcred32: ScanArcRed measured worse at 32, so the constant is worth testing in the other direction at 24.

## stale-matecarry-fix — REJECT (local A/B)

- when: 2026-07-31T16:57:03+00:00
- change: `baseline/sense.nim`: `if enemyPlanted:
    discard                              # enemy flag sits home: nobody carries` -> `if enemyPlanted:
    # Nobody is carrying it, so any carry fix we hold is dead intel: pin it
    # to the pedestal and restamp the clock, so the dead-reckon below starts
    # from where the flag actually is on the tick it is next lifted.
    bot.mateFixPos = f.stealTarget
    bot.mateFixTick = bot.tick`
- treatment: local build  control: `jordan-ctf-candidate:v79` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-stale-matecarry-fix.jsonl, seeds 259000-259059 both ways)
- verdict: wins separate NEGATIVE: K/D -0.0235 CI [-0.0456, -0.0023], win rate -0.133 CI [-0.233, -0.025], captures -13 CI [-24, -3], n=120
- pooled: 120 episodes, 0 skipped; RED won 74.2% of episodes
  - treatment: K/D 0.9883 (2535/2565), captures 27, wins 49
  - control: K/D 1.0119 (2561/2531), captures 40, wins 65
- rationale: readFlagState's last branch fires whenever a mate carries the enemy flag outside our cone, and it dead-reckons that carrier from bot.mateFixPos advanced homeward by `elapsed = bot.tick - max(bot.mateFixTick, bot.gameStart)`. Neither field is invalidated when the flag returns to its pedestal. With no banner sighting this game mateFixTick is 0, so elapsed is the whole game and the min() clamp parks the phantom carrier on OUR OWN pedestal from the first frame of any steal past ~860 ticks (pedestal separation is 863px at CarrierEstSpeed 1.0); with a fix left over from an earlier failed steal it starts stale and runs just as far. Six seats escort that point. Pinning the fix to the pedestal and restamping the clock while the flag is planted makes elapsed mean "ticks since the flag was lifted", which is what the comment already claims. Hypothesis: the escort wave stops walking home to guard nobody.

## preaim-track-ttl-live — REJECT (local A/B)

- when: 2026-07-31T17:17:07+00:00
- change: `baseline/tactics.nim`: `maxRange = PreAimRange, maxAge = PreAimPingTtl): int =` -> `maxRange = PreAimRange, maxAge = PreAimTrackTtl): int =`
- treatment: local build  control: `jordan-ctf-candidate:v79` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-preaim-track-ttl-live.jsonl, seeds 260000-260059 both ways, seeds 260200-260339 both ways)
- verdict: level: K/D +0.0085 CI [-0.0061, +0.0230], win rate +0.018 CI [-0.037, +0.072], captures -3 CI [-23, +18], n=400
- pooled: 400 episodes, 0 skipped; RED won 66.8% of episodes
  - treatment: K/D 1.0042 (8521/8485), captures 125, wins 189
  - control: K/D 0.9958 (8493/8529), captures 128, wins 182
- rationale: `preAimBearing` defaults `maxAge = PreAimPingTtl` (60) and then gates remembered enemies on `min(PreAimTrackTtl, maxAge)`, so PreAimTrackTtl (90) can never bind: its only two callers are the keeper's watch (explicit PreAimWatchTtl, 30) and the cruising pre-aim (the default, 60). A constant whose own comment reads 'a remembered enemy this fresh still points' is inert, and asking it as a knob would measure exactly level -- the EscortScreenDist shape. Changing the default to PreAimTrackTtl leaves the ping loop untouched (it already mins against PreAimPingTtl) and the keeper untouched (it passes 30), so the one thing that moves is the cruising pre-aim's track window, 60 -> 90. Hypothesis only: aim-direction is the vein where ScanArc paid twice, couldTrade still vetoes tracks no shot could reach, and PreAimAgePx charges 1.2px of doubt per tick, so an old track only wins when nothing better exists.

## Five screens, five collapses — including one that SEPARATED

- when: 2026-07-31T17:20:00+00:00
- Every stage-1 result this session that looked good enough to buy episodes
  came back level or negative on its pooled confirmation. All five:

    peek-friendly-corridor   +0.0413 [-0.006, +0.091] -> +0.0055 (fresh batch)
                             captures +19 [+6, +32]   -> +0
    duckrange260-reverse     +0.0282 -> +0.0136 (n=400) -> +0.0102 (n=600)
    scanarcred32             +0.0110 -> -0.0101 (n=400)   SIGN FLIP
    scanarcred32-reverse     +0.0213 -> -0.0077 (n=400)   SIGN FLIP
    preaim-track-ttl-live    +0.0243, win rate +0.100 CI [+0.017, +0.192]
                             -> +0.0085, win rate +0.018 [-0.037, +0.072]

- The last one matters most. It did not merely NEAR-MISS: its win rate
  SEPARATED positive at n=120, which is the strongest evidence a screen can
  produce and the exact condition `decide()` treats as sufficient to escalate.
  It still evaporated. So "separates at the screen" is not weak evidence of
  an effect -- it is close to no evidence at all on this instrument.

- Why, mechanically. The seed-paired bootstrap resamples SEED PAIRS drawn in
  one batch, so it measures within-batch variance and is blind to
  between-batch variance -- the terrain and spawn draw that the batch itself
  fixes. `medkitdetour` recorded this in the small; five cases now say it is
  the rule. Note the screens above are not obviously too WIDE or too narrow
  against the fitted 0.50/sqrt(n) (+-0.046 at n=120); several ran TIGHTER
  than that, because pairs a change never fires in contribute zero. A tight
  interval computed over one batch is exactly the failure mode: confident
  about the seeds drawn, silent about which seeds were drawn.

- Nothing here indicts the loop. Escalate-then-confirm caught all five and
  promoted none of them; the design is doing precisely the job it exists for.
  What should change is how a SCREEN is talked about in this file and in any
  status report: it is triage, its point estimate is not a finding, and no
  screen result should be described as promising without the word "unconfirmed"
  next to it. The only number worth quoting is the pooled one.

## defender-stale-intruder — REJECT (local A/B)

- when: 2026-07-31T17:23:42+00:00
- change: `baseline/tuning.nim`: `ThiefFixTtl* = 40            # a thief position fix guides the chase this long` -> `ThiefFixTtl* = 40            # a thief position fix guides the chase this long
  IntruderTrackTtl* = 90       # the HomeDefender only leaves its choke for a
                              # remembered intruder this fresh; an older track
                              # is a place, not a body`; `baseline/objective.nim`: `if not onOurHalf:
        continue
      let d = dist(bot.enemies[i].pos, f.me)` -> `if not onOurHalf:
        continue
      if bot.tick - bot.enemies[i].lastSeen > IntruderTrackTtl:
        continue                         # stale: a place, not a body
      let d = dist(bot.enemies[i].pos, f.me)`
- treatment: local build  control: `jordan-ctf-candidate:v79` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-defender-stale-intruder.jsonl, seeds 261000-261059 both ways)
- verdict: level: K/D -0.0148 CI [-0.0537, +0.0236], win rate +0.092 CI [-0.050, +0.233], captures -9 CI [-23, +5], n=120
- pooled: 120 episodes, 0 skipped; RED won 73.3% of episodes
  - treatment: K/D 0.9926 (2541/2560), captures 31, wins 62
  - control: K/D 1.0074 (2580/2561), captures 40, wins 51
- rationale: chooseObjective's HomeDefender branch scans bot.enemies for the nearest track on our half and walks to `pos + vel * 6.0` with no freshness test at all, so a track still alive under TrackHoldTtl's 400 ticks (~17s, several hundred px of possible travel) drags the defender off chokeHold — and because act.nim's scan-sweep branch only runs while the seat is standing on its target, the phantom chase also switches off its vision sweep. Every other consumer of a remembered enemy gates itself: shooting at 24, ducking at 30, exposure at 60, pre-aim at 90, back-guard at 200. The seat that camps longest and stands last between an intruder and our pedestal gates at nothing. IntruderTrackTtl 90 matches PreAimTrackTtl, the freshness the bot already demands merely to point the gun. Hypothesis: fewer phantom chases, more time on the choke, fewer enemy captures.

## trackhold200 — REJECT (local A/B)

- when: 2026-07-31T17:30:05+00:00
- change: `TrackHoldTtl` -> `200`
- treatment: local build  control: `jordan-ctf-candidate:v79` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-trackhold200.jsonl, seeds 262000-262059 both ways)
- verdict: captures separate NEGATIVE: K/D -0.0369 CI [-0.0757, +0.0016], win rate -0.117 CI [-0.250, +0.017], captures -25 CI [-39, -11], n=120
- pooled: 120 episodes, 0 skipped; RED won 76.7% of episodes
  - treatment: K/D 0.9815 (2488/2535), captures 28, wins 50
  - control: K/D 1.0184 (2604/2557), captures 53, wins 64
- rationale: memory.nim's prune keeps a lost enemy for 400 ticks (~17s), and every consumer that shoots, ducks, bombs, routes or pre-aims applies a tighter gate of its own: FreshShotTicks 24, nearThreat 30, ExposureTrackTtl 60, PreAimTrackTtl 90, NadeMemTtl 150, BackGuardTtl 200. Four consumers read a track at ANY age -- the HomeDefender's intruder break-off, MidGuard's carrier screen, safestLaneY's lane count, and sense.nim's carrier attribution -- so shortening the window mainly stops the defender leaving its choke for a body last seen eight seconds ago. corpse-track- cleanup (+0.096 K/D, the largest promotion here) paid for deleting exactly this class of phantom. One SIDE EFFECT is not optional to state, because an earlier draft of this experiment claimed there was none: the prune runs before the next frame's matching, so it also decides whether a re-sighting MERGES into an existing track or CONSTRUCTS a new one, and the constructor does not set `vel` -- it zero-initialises. A pruned-then-re- sighted enemy therefore leads at zero velocity for a frame, which does reach the firing path. So this is not a clean isolation of the three age-blind consumers; it is that change plus a lead-estimate reset on long re-acquisitions. freshshot32-reverse (-0.092) is the standing warning that shortening a memory window can be a cliff.

## trackhold200-reverse — REJECT (local A/B)

- when: 2026-07-31T17:36:27+00:00
- change: `TrackHoldTtl` -> `600`
- treatment: local build  control: `jordan-ctf-candidate:v79` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-trackhold200-reverse.jsonl, seeds 263000-263059 both ways)
- verdict: level: K/D -0.0008 CI [-0.0417, +0.0406], win rate +0.025 CI [-0.117, +0.167], captures +10 CI [-3, +23], n=120
- pooled: 120 episodes, 0 skipped; RED won 70.0% of episodes
  - treatment: K/D 0.9996 (2549/2550), captures 42, wins 59
  - control: K/D 1.0004 (2538/2537), captures 32, wins 56
- rationale: Derived from trackhold200: TrackHoldTtl measured worse at 200, so the constant is worth testing in the other direction at 600.

## diamond-sweep-shots-only — REJECT (local A/B)

- when: 2026-07-31T17:42:55+00:00
- change: `baseline/tuning.nim`: `CorridorHalfWidth* = 15.0    # friendly-fire corridor half width along the ray` -> `CorridorHalfWidth* = 15.0    # friendly-fire corridor half width along the ray
  SpinShotSweepScale* = 1.0    # fraction of a spinning centre diamond's radius
                              # a SHOT ray must keep clear of, and nothing
                              # else. The eight diamonds are live geometry
                              # (fov.nim) but the walkability sprite arrives
                              # ONCE, so the mask pixelRayClear reads holds a
                              # single spin frame. 1.0 is the swept disc --
                              # everywhere the stone can be while the bullet
                              # is in the air. 0.0 is off, and anything at or
                              # below 1/sqrt(2) ~ 0.71 is a provable no-op:
                              # the ground that is stone at EVERY frame is
                              # already inside the one frame that was baked`; `baseline/fov.nim`: `proc crossesSpinSweep*(spins: openArray[SpinDiamond], a, b: Vec): bool =
  ## Whether the segment a-b passes within a turning diamond's reach: inside
  ## its swept disc (radius r — the rotated footprint never leaves it) plus
  ## SpinSweepSlack of quantization margin. A sightline that crosses is
  ## wrong for part of every rotation and disqualifies the pair.
  for d in spins:
    let
      c = vec(float(d.cx), float(d.cy))
      ab = b - a
      len2 = dot(ab, ab)
      t = if len2 < 1e-9: 0.0 else: clamp(dot(c - a, ab) / len2, 0.0, 1.0)
    if dist(a + ab * t, c) <= float(d.r) + SpinSweepSlack:` -> `proc crossesSpinSweep*(
    spins: openArray[SpinDiamond], a, b: Vec,
    rScale = 1.0, slack = SpinSweepSlack
): bool =
  ## Whether the segment a-b passes within a turning diamond's reach: inside
  ## `rScale` of its swept disc (radius r — the rotated footprint never
  ## leaves the whole disc) plus `slack` of margin. A sightline that crosses
  ## is wrong for part of every rotation and disqualifies the pair.
  ##
  ## The defaults are the FOG question, the one the one-way scan asks: the
  ## whole disc, widened by SpinSweepSlack because occlusion is quantized
  ## onto 8px cells. A BULLET is not quantized -- pixelRayClear walks the
  ## pixel mask itself -- so the shot gate asks for the same disc with no
  ## slack. Passing the defaults reproduces this proc exactly as it was.
  for d in spins:
    let
      c = vec(float(d.cx), float(d.cy))
      ab = b - a
      len2 = dot(ab, ab)
      t = if len2 < 1e-9: 0.0 else: clamp(dot(c - a, ab) / len2, 0.0, 1.0)
    if dist(a + ab * t, c) <= float(d.r) * rScale + slack:`; `baseline/engage.nim`: `import
  bitworld/profile,
  protocols,
  frame,
  grid,
  tactics,
  world,
  geometry,
  tuning` -> `import
  bitworld/profile,
  protocols,
  frame,
  fov,
  grid,
  tactics,
  world,
  geometry,
  tuning`; `baseline/engage.nim`: `f.engage = -1
  f.engageD = f.maxEngage
  f.engagePrio = f.maxEngage
  f.haveBlocked = false
  f.blockedD = f.maxEngage` -> `f.engage = -1
  f.engageD = f.maxEngage
  f.engagePrio = f.maxEngage
  f.haveBlocked = false
  f.blockedD = f.maxEngage
  # The shot gate below asks `client.pixelRayClear`, which reads the pixel
  # walkability mask (grid.nim) -- and that mask is ONE frozen frame. The
  # eight spinning centre diamonds are live geometry the engine restamps
  # into its own bullet mask as the spin advances, while the walkability
  # sprite is sent once at connect (fov.nim). So a ray threading the gap
  # between two blades reads clear here and can be solid by the time the
  # 5-tick windup releases the bullet. Ask instead whether the ray crosses
  # the swept DISC -- everywhere the stone can be during the turn -- and
  # treat a target behind one as wall-blocked, which is what it is for part
  # of every rotation. The mask itself is not touched: pathing, cover,
  # exposure and the duck/peek searches read exactly what they read today.
  # Empty, and free, at scale 0.0 and on any map but the arena.
  var spins: seq[SpinDiamond]
  if SpinShotSweepScale > 0.0:
    spins = spinDiamonds()`; `baseline/engage.nim`: `if client.pixelRayClear(f.me, predicted):` -> `if client.pixelRayClear(f.me, predicted) and
        not crossesSpinSweep(spins, f.me, predicted, SpinShotSweepScale, 0.0):`
- treatment: local build  control: `jordan-ctf-candidate:v79` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-diamond-sweep-shots-only.jsonl, seeds 264000-264059 both ways)
- verdict: REGRESSION: K/D -0.0775 CI [-0.1249, -0.0324], win rate -0.133 CI [-0.300, +0.025], captures -7 CI [-21, +7], n=120
- pooled: 120 episodes, 0 skipped; RED won 50.0% of episodes
  - treatment: K/D 0.9621 (2562/2663), captures 28, wins 47
  - control: K/D 1.0395 (2656/2555), captures 35, wins 63
- rationale: `diamond-sweep-paint` painted the swept discs into `client.walkabilityMask` itself and separated NEGATIVE on all three metrics (K/D -0.0815, n=120) — but that one mask feeds four consumers: `cellWalkable`, the cover model, the exposure cost field, and the shot gate at `engage.nim:106`. Adding wall makes routes detour, cover cells vanish and the duck/peek searches refuse ground that is open most of the turn; only the shot half can plausibly pay. This applies the correction to that half alone: a ray crossing a diamond's swept disc is treated as blocked, so the target falls to the peek branch instead of buying a phantom-clear shot into stone that swung back. The mask is not mutated, so nothing else sees a different world. Honest prior: the parent was decisive, and this may simply show the frozen frame was never costing many shots.

## Session close, 2026-07-31 — 16 experiments, one promotion

- Loop stopped deliberately at an experiment boundary. State: generation 65,
  74 experiments decided, queue empty, 23 seeds pending in the catalogue,
  `bothflags-race-escort` killed during startup and NOT recorded, so it
  re-runs intact on the next invocation.
- Shipped: `jordan-ctf-candidate:v79` (corpseclear40), submitted with
  --auto-champion always. That is the only policy change of the session.

### The one promotion

`corpseclear40` — CorpseClearRadius 80 -> 40, K/D +0.0307 CI [+0.0060,
+0.0567], captures +39 CI [+13, +65] at n=400. The knob shipped at 80 last
session and 160 measured level, which made the axis look one-sided; it is
not. The optimum of the largest promotion on record sits BELOW where it
originally shipped.

### The diamond band, and a conclusion reversed by its own follow-up

`diamond-sweep-paint` painted the eight swept discs into the walkability
mask and regressed hard (K/D -0.0815, all three metrics negative). The
reading recorded at the time was that the mask feeds FOUR consumers --
pathing, cover, exposure, shot clearance -- and that the routing cost had
probably swamped a real shot-honesty gain.

`diamond-sweep-shots-only` tested exactly that by applying the correction to
the shot gate ALONE, mutating no mask. It regressed by essentially the same
amount: K/D -0.0775 CI [-0.1249, -0.0324] against the parent's -0.0815.

So the earlier reading was WRONG. It was never the pathing cost. The shot
gate itself is what costs ~0.08 K/D, which means refusing rays that cross a
swept disc is much worse than taking them. The likely reason is that the
swept disc is a gross over-approximation of a spinning diamond -- the blade
occupies a small fraction of its own disc at any instant -- so blocking every
ray through the band discards far more shots that would have connected than
phantom shots it prevents. The frozen-snapshot world model is WRONG and
still better than the conservative one, in both scopes tested.

### What did not replicate, and the instrument finding

Five stage-1 screens bought episodes; all five came back level or negative,
one of them after its win rate SEPARATED positive at the screen. See the
note above. The practical consequence is recorded there: a screen is triage,
its point estimate is not a finding, and the pooled number is the only one
worth quoting.

### Corrections made to this repository's own record

- BACKLOG items 8-11 listed four knob axes that DO NOT EXIST in the tree --
  each was introduced by a patch that was then rejected. A knob edit against
  them matches nothing.
- The operator's asymmetry brief was audited against the engine: combat is
  explicitly order-independent ("no processing-order advantage", twice in the
  engine source), choke body-blocks have no lever and favour the attacker
  symmetrically, flags are never cross-team contested, and slots ALTERNATE so
  red wins 36 of 64 seat pairs rather than all. Only the centre-line med kits
  survive as a red-greed target.
- A per-side knob is measured at half effect but ALSO collapsed variance, so
  it should be read by doubling; an earlier claim in this file that it needs
  4x the episodes was wrong.
- The near-miss gate let noise on one metric veto a strong signal on the
  other; widened to half a standard error (NEAR_MISS_TOLERANCE). The
  experiment that motivated the change then came back level, which is
  recorded next to it.

### Structural finding: the loop cannot land inert plumbing

apply_edits works on a scratch copy, land() runs only from promote(), and
commit() stages bot/ only on a promotion. A provable no-op measures level,
is rejected, and is discarded -- so BACKLOG's "land inert + knob, like
fov.nim did" strategy is not executable BY the loop. The ScanArc per-side
split was therefore landed as a direct commit with its inertness proven by
gameHash equality over 12 seeds / 24 episodes. Any future per-side or
land-inert feature needs the same treatment.

### Where the policy stands

One promotion in sixteen. Both flagship backlog features regressed
decisively, and the anti-phantom batch that looked most promising on prior
evidence went 0 for 4 -- including `stale-matecarry-fix`, which regressed at
-0.133 win rate while deleting a belief that was demonstrably false. The
honest summary is that this policy is well-tuned and most single-variable
moves available to it are level; the deletions that paid previously were
about ENEMY tracks near a confirmed kill, and that does not generalise to
stale intel as a class.

## corpseclear40 — shipped late as `jordan-ctf-candidate:v80`

- when: 2026-07-31T18:40:00+00:00
- The promotion above landed in `bot/` but its upload failed: the amd64
  cross-compile needs `/workspace/.bot-deps` and a `zigcc-amd64` wrapper, and
  neither survived the session that created them. Both are now reproducible
  from the repository — `scripts/sync_deps.sh` clones either `nimby.lock` at
  its pinned SHAs (nimby's own release binary is glibc and will not run on this
  musl box), and `scripts/zigcc-amd64` is committed next to the build script
  that names it.
- The tree at `33bd859` was rebuilt, smoke-tested under qemu, uploaded as
  `jordan-ctf-candidate:v80` and submitted with `--auto-champion always`.
  `research/state.json`'s baseline and champion now name v80, so the next
  experiment is measured against the build the league is actually running.

## bothflags-race-escort — REJECT (local A/B)

- when: 2026-07-31T18:16:35+00:00
- change: `baseline/tuning.nim`: `ThiefFixTtl* = 40            # a thief position fix guides the chase this long` -> `ThiefFixTtl* = 40            # a thief position fix guides the chase this long
  RaceEscortMargin* = 120.0    # px our own carrier must be closer to home
                              # than the thief is to ITS home before the
                              # both-flags race counts as ours and the
                              # intercept gives way to the escort`; `baseline/objective.nim`: `elif f.ownStolen and (bot.role == HomeDefender or
      bot.tick - bot.carrierSeen <= ThiefFixTtl):` -> `elif f.ownStolen and (bot.role == HomeDefender or
      bot.tick - bot.carrierSeen <= ThiefFixTtl) and
      not (f.mateCarry and bot.carrierSeen > -100_000 and
        abs(f.mateCarryPos.x - homeDeepX(bot.team)) + RaceEscortMargin <
        abs(bot.carrierPos.x - homeDeepX(enemy(bot.team)))):`
- treatment: local build  control: `jordan-ctf-candidate:v80` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-bothflags-race-escort.jsonl, seeds 265000-265059 both ways)
- verdict: level: K/D +0.0023 CI [-0.0016, +0.0079], win rate +0.008 CI [-0.042, +0.058], captures +0 CI [-5, +4], n=120
- pooled: 120 episodes, 0 skipped; RED won 69.2% of episodes
  - treatment: K/D 1.0012 (2562/2559), captures 30, wins 54
  - control: K/D 0.9988 (2559/2562), captures 30, wins 53
- rationale: chooseObjective ranks the thief intercept above the escort unconditionally: `elif f.ownStolen and (bot.role == HomeDefender or bot.tick - bot.carrierSeen <= ThiefFixTtl):` sits above `elif f.mateCarry:`, so the moment both flags are up, the defender always and every other seat with a fresh fix drops our own carrier to chase theirs. Capture has no own-flag-home precondition, so both-flags is a pure race, and nothing in the tree asks who is winning it. Compare the two carriers' remaining x to their home columns and, when ours leads by RaceEscortMargin, let the intercept fall through to the escort branch it already sits above. Hypothesis: chasing a race we are already winning trades a capture for a coin flip. Honest risk: the thief fix can be stale, which under-counts its progress and biases toward escorting, and the margin is what pays for that.

## ahead-draw-push — REJECT (local A/B)

- when: 2026-07-31T18:17:29+00:00
- change: `baseline/tuning.nim`: `PushOutMinGame* = 2400       # ...this deep into the game breaks the posts` -> `PushOutMinGame* = 2400       # ...this deep into the game breaks the posts
  AheadPushTick* = 2400        # the clock all-in, brought forward to here
                              # while we are AHEAD on kills: a timeout
                              # draw scores exactly as badly as a loss,
                              # and holdNow is already false in that
                              # state, so act.nim's mid+80 clamp is off
                              # and the push can actually arrive`; `baseline/objective.nim`: `bot.tick - bot.gameStart > LatePushTick
  )` -> `bot.tick - bot.gameStart > LatePushTick or
    (bot.killsInit and
     bot.kills[bot.team] > bot.kills[enemy(bot.team)] and
     bot.tick - bot.gameStart > AheadPushTick)
  )`
- treatment: local build  control: `jordan-ctf-candidate:v80` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-ahead-draw-push.jsonl, seeds 266000-266059 both ways)
- verdict: level: K/D +0.0000 CI [-0.0156, +0.0148], win rate -0.008 CI [-0.075, +0.050], captures -1 CI [-7, +5], n=120
- pooled: 120 episodes, 0 skipped; RED won 64.2% of episodes
  - treatment: K/D 1.0000 (2576/2576), captures 34, wins 58
  - control: K/D 1.0000 (2578/2578), captures 35, wins 59
- rationale: The late all-in is a bare clock switch — `bot.tick - bot.gameStart > LatePushTick` — identical whether we are winning the attrition race or losing it. latepush3000 moved that switch 400 ticks earlier for every state and came back level, exactly what a lever that helps in one state and hurts in the other looks like. Condition it instead: fire at AheadPushTick (2400, the tick PushOutMinGame already calls deep into the game) only while bot.kills[us] > bot.kills[them]. Two reasons that is the state to push in: a timeout draw scores exactly as badly as a loss, so a lead the clock erases is worth nothing; and being ahead makes act.nim's holdNow false, so the mid+80 clamp is already off and the two post seats can actually reach the pocket. Hypothesis. Risk: it empties our half against a team that needs a steal.

## holdlinedepth160 — PROMOTE (local A/B)

- when: 2026-07-31T18:20:59+00:00
- change: `HoldLineDepth` -> `160`
- treatment: local build  control: `jordan-ctf-candidate:v80` (the tree)
- shipped as: `jordan-ctf-candidate:v81`
- measured on: the local simulator, seed-paired mirrors (episodes/exp-holdlinedepth160.jsonl, seeds 267000-267059 both ways, seeds 267200-267339 both ways)
- verdict: separates positive on the pooled sample: K/D +0.0685 CI [+0.0444, +0.0928], win rate +0.170 CI [+0.077, +0.263], captures +53 CI [+23, +83], n=400
- pooled: 400 episodes, 0 skipped; RED won 51.2% of episodes
  - treatment: K/D 1.0346 (8821/8526), captures 142, wins 217
  - control: K/D 0.9661 (8396/8691), captures 89, wins 149
- rationale: act.nim clamps every held-line goal to 80px past mid. fov.nim's spinDiamonds puts the eight live rotating obstacles at cx 565 and 669, r 30 -- |x - CenterX| from 22 to 82px on the 1235 arena -- so the staging line sits 2px inside the swept band, on the one strip of ground whose collision geometry the walkability snapshot froze at a single spin frame while the engine keeps turning it. That band arrived with the 0.7.136 re-pin; the constant has never been moved in either direction, and its sibling HoldLineKills has been swept twice. 160 stages the wave clear of the discs on both sides while staying 272px short of the pocket, so it is still a hold, not an all-in. pushout-hold- conflict, which lifted this same clamp in the endgame, regressed on K/D but separated +15 captures -- the line does something, and nobody has asked where it belongs.

## holdlinedepth160-further — REJECT (local A/B)

- when: 2026-07-31T18:21:49+00:00
- change: `HoldLineDepth` -> `240.0`
- treatment: local build  control: `jordan-ctf-candidate:v81` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-holdlinedepth160-further.jsonl, seeds 268000-268059 both ways)
- verdict: level: K/D -0.0419 CI [-0.0889, +0.0068], win rate -0.117 CI [-0.283, +0.058], captures +3 CI [-11, +17], n=120
- pooled: 120 episodes, 0 skipped; RED won 40.8% of episodes
  - treatment: K/D 0.9795 (2625/2680), captures 29, wins 49
  - control: K/D 1.0214 (2626/2571), captures 26, wins 63
- rationale: Derived from holdlinedepth160: HoldLineDepth paid at 160, so walk the same way again to 240 and find where it stops paying.

## holdlinedepth160-further-reverse — REJECT (local A/B)

- when: 2026-07-31T18:22:41+00:00
- change: `HoldLineDepth` -> `80.0`
- treatment: local build  control: `jordan-ctf-candidate:v81` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-holdlinedepth160-further-reverse.jsonl, seeds 269000-269059 both ways)
- verdict: wins separate NEGATIVE: K/D -0.0813 CI [-0.1278, -0.0345], win rate -0.300 CI [-0.450, -0.142], captures -21 CI [-34, -8], n=120
- pooled: 120 episodes, 0 skipped; RED won 55.8% of episodes
  - treatment: K/D 0.9599 (2540/2646), captures 18, wins 39
  - control: K/D 1.0412 (2676/2570), captures 39, wins 75
- rationale: Derived from holdlinedepth160-further: HoldLineDepth measured worse at 240.0, so the constant is worth testing in the other direction at 80.

## exposedcost6 — REJECT (local A/B)

- when: 2026-07-31T18:23:33+00:00
- change: `ExposedCost` -> `6`
- treatment: local build  control: `jordan-ctf-candidate:v81` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-exposedcost6.jsonl, seeds 270000-270059 both ways)
- verdict: wins separate NEGATIVE: K/D -0.0694 CI [-0.1146, -0.0239], win rate -0.192 CI [-0.367, -0.017], captures -30 CI [-45, -16], n=120
- pooled: 120 episodes, 0 skipped; RED won 49.2% of episodes
  - treatment: K/D 0.9652 (2493/2583), captures 18, wins 47
  - control: K/D 1.0346 (2694/2604), captures 48, wins 70
- rationale: Entering a threat-exposed cell adds 14 on top of a 5-cost orthogonal step, so a route pays up to 2.8 clean cells to dodge one watched cell. 14 -> 10 was bought twice, on two instruments and two engine pins, and leaned the same way both times without separating: hosted n=240 K/D +0.017 [-0.025, +0.060] with captures +15 [+0, +31], local n=400 K/D +0.010 [-0.020, +0.039] with captures +26 [-1, +52]. The catalogue's own reading of a null is that the effect sits under what the screen resolves, and the answer to that is a bigger move rather than more episodes on the same one. 6 more than doubles the cut, dropping the dodge budget to ~1.2 cells. Honestly, it could equally be where routing stops respecting watched lanes at all -- which is the other thing the mirror would show.

## exposedcost6-reverse — PROMOTE (local A/B)

- when: 2026-07-31T18:26:24+00:00
- change: `ExposedCost` -> `22`
- treatment: local build  control: `jordan-ctf-candidate:v81` (the tree)
- shipped as: `jordan-ctf-candidate:v82`
- measured on: the local simulator, seed-paired mirrors (episodes/exp-exposedcost6-reverse.jsonl, seeds 271000-271059 both ways, seeds 271200-271339 both ways)
- verdict: separates positive on the pooled sample: K/D +0.0937 CI [+0.0679, +0.1199], win rate +0.207 CI [+0.117, +0.295], captures +61 CI [+35, +87], n=400
- pooled: 400 episodes, 0 skipped; RED won 64.8% of episodes
  - treatment: K/D 1.0476 (8911/8506), captures 147, wins 234
  - control: K/D 0.9539 (8374/8779), captures 86, wins 151
- rationale: Derived from exposedcost6: ExposedCost measured worse at 6, so the constant is worth testing in the other direction at 22.

## exposedcost6-reverse-further — REJECT (local A/B)

- when: 2026-07-31T18:27:28+00:00
- change: `ExposedCost` -> `30`
- treatment: local build  control: `jordan-ctf-candidate:v82` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-exposedcost6-reverse-further.jsonl, seeds 272000-272059 both ways)
- verdict: wins separate NEGATIVE: K/D -0.1244 CI [-0.1819, -0.0693], win rate -0.258 CI [-0.433, -0.075], captures -10 CI [-25, +5], n=120
- pooled: 120 episodes, 0 skipped; RED won 40.8% of episodes
  - treatment: K/D 0.9396 (2506/2667), captures 24, wins 40
  - control: K/D 1.0641 (2674/2513), captures 34, wins 71
- rationale: Derived from exposedcost6-reverse: ExposedCost paid at 22, so walk the same way again to 30 and find where it stops paying.

## exposedcost6-reverse-further-reverse — REJECT (local A/B)

- when: 2026-07-31T18:28:29+00:00
- change: `ExposedCost` -> `14`
- treatment: local build  control: `jordan-ctf-candidate:v82` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-exposedcost6-reverse-further-reverse.jsonl, seeds 273000-273059 both ways)
- verdict: wins separate NEGATIVE: K/D -0.1431 CI [-0.1931, -0.0940], win rate -0.392 CI [-0.558, -0.225], captures -35 CI [-48, -22], n=120
- pooled: 120 episodes, 0 skipped; RED won 60.8% of episodes
  - treatment: K/D 0.9303 (2469/2654), captures 13, wins 34
  - control: K/D 1.0734 (2705/2520), captures 48, wins 81
- rationale: Derived from exposedcost6-reverse-further: ExposedCost measured worse at 30, so the constant is worth testing in the other direction at 14.

## defender-intruder-ttl — REJECT (local A/B)

- when: 2026-07-31T18:29:31+00:00
- change: `baseline/tuning.nim`: `LaneTop* = 40.0              # open corridor above the mirrored obstacles` -> `LaneTop* = 40.0              # open corridor above the mirrored obstacles
  DefenderIntruderTtl* = 60    # the home defender leaves its choke only for
                              # a remembered intruder this fresh; an older
                              # track is a memory, not a body at the door`; `baseline/objective.nim`: `var intruder = -1
    var intruderD = 1e18
    for i in 0 ..< bot.enemies.len:
      let onOurHalf =` -> `var intruder = -1
    var intruderD = 1e18
    for i in 0 ..< bot.enemies.len:
      if bot.tick - bot.enemies[i].lastSeen > DefenderIntruderTtl:
        continue                    # a memory, not a body at the door
      let onOurHalf =`
- treatment: local build  control: `jordan-ctf-candidate:v82` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-defender-intruder-ttl.jsonl, seeds 274000-274059 both ways)
- verdict: level: K/D +0.0008 CI [-0.0390, +0.0404], win rate -0.058 CI [-0.208, +0.092], captures +0 CI [-14, +14], n=120
- pooled: 120 episodes, 0 skipped; RED won 61.7% of episodes
  - treatment: K/D 1.0004 (2570/2569), captures 34, wins 51
  - control: K/D 0.9996 (2578/2579), captures 34, wins 58
- rationale: The HomeDefender branch scans `bot.enemies` with no freshness test at all, so the choke -- the one position the design says every steal has to pass -- is abandoned for a track `updateTracks` may have been holding for TrackHoldTtl (400 ticks, ~17s), at a position that old, dead-reckoned forward by six ticks. Every other consumer of the same memory gates it: nearThreat at 30, exposure at 60, the thief fix at 40. This is intel-driven timidity in its purest form, and the direction that has paid on this tree is removing phantom intel -- corpse-track- cleanup, the largest promotion on record at +0.096 K/D, deleted exactly this class of ghost. A DefenderIntruderTtl of 60 keeps the intercept for bodies that were there a moment ago and sends the defender back to the choke otherwise. Distinct from defender-intercept-by-flag, which moved the ranking metric and left the freshness question untouched.

## pocket-rush-mate-ttl — REJECT (local A/B)

- when: 2026-07-31T18:30:24+00:00
- change: `baseline/tuning.nim`: `PocketRushRange* = 210.0     # this close to the enemy pedestal, just GRAB` -> `PocketRushRange* = 210.0     # this close to the enemy pedestal, just GRAB
  PocketMateTtl* = 150         # a mate sighting this fresh still counts when
                              # deciding WHICH attacker commits to the touch.
                              # With no mate this fresh the comparison is
                              # trivially true and every eligible seat claims
                              # it, so the whole wave goes in unarmed`; `baseline/engage.nim`: `if bot.tick - t.lastSeen > 48:
      continue` -> `if bot.tick - t.lastSeen > PocketMateTtl:
      continue`
- treatment: local build  control: `jordan-ctf-candidate:v82` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-pocket-rush-mate-ttl.jsonl, seeds 275000-275059 both ways)
- verdict: level: K/D -0.0023 CI [-0.0288, +0.0228], win rate +0.008 CI [-0.075, +0.100], captures +3 CI [-5, +11], n=120
- pooled: 120 episodes, 0 skipped; RED won 65.8% of episodes
  - treatment: K/D 0.9988 (2553/2556), captures 34, wins 58
  - control: K/D 1.0012 (2558/2555), captures 31, wins 57
- rationale: engage.nim arbitrates the pocket touch by distance: `nearestMateToSteal` starts at 1e18 and only a mate seen within 48 ticks lowers it, then pocketRush requires `dist(f.me, f.stealTarget) < nearestMateToSteal + 8.0`. Mates are fogged, so whenever no mate has been seen for two seconds that test is trivially true and every eligible seat inside PocketRushRange claims the touch at once — and pocketRush sets `f.maxEngage = 0.0`, a bot that will not shoot at all, and is excluded from the jink, the duck and the serpentine. The comment above it wants exactly one attacker unarmed "while the rest of the wave keeps its guns up to cover the grab"; the fail-open default inverts that into up to five unarmed bodies at a pedestal that respawns enemies armed. 48 is the tightest mate-freshness in the tree — NadeMateTtl trusts a mate sighting for 150 — so lifting the literal into PocketMateTtl and moving it to 150 makes the arbitration decide on evidence far more often. The constant's introduction at 48 would be inert; only the move to 150 is the variable. Hypothesis: a stale mate fix could equally suppress a grab we should have made, which is what the mirror measures.

## plasma-no-duck — REJECT (local A/B)

- when: 2026-07-31T18:31:17+00:00
- change: `baseline/act.nim`: `elif not f.iCarry and not f.rushing and not f.pocketRush and not f.shotReady and
      f.nearThreat >= 0:` -> `elif not f.iCarry and not f.rushing and not f.pocketRush and not f.shotReady and
      not f.hasPlasma and f.nearThreat >= 0:`
- treatment: local build  control: `jordan-ctf-candidate:v82` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-plasma-no-duck.jsonl, seeds 276000-276059 both ways)
- verdict: level: K/D +0.0131 CI [-0.0348, +0.0603], win rate -0.050 CI [-0.200, +0.108], captures +2 CI [-11, +15], n=120
- pooled: 120 episodes, 0 skipped; RED won 60.8% of episodes
  - treatment: K/D 1.0066 (2600/2583), captures 32, wins 54
  - control: K/D 0.9935 (2580/2597), captures 30, wins 60
- rationale: sense.nim sets `f.shotReady = client.countOf(lkFireIcon) > 0 and not f.hasPlasma`, so a bot holding the spray can reads as not- shot-ready for as long as it carries it. act.nim's cooldown branch is guarded on `not f.shotReady`, which was written for the gun's 12-tick reload; a plasma carrier satisfies it permanently. With any remembered track inside DuckRange (340px) and no cone target inside `PlasmaReach + 6.0` (142px), the arc carrier ducks behind cover and holds — every frame, for the whole life of the pickup. The one weapon that only pays inside 136px is held by the one state that structurally refuses to close. Adding `not f.hasPlasma` drops it through to chooseMovement, so it keeps navigating (with the jink and serpentine still available) until the cone branch takes over inside reach. Hypothesis: the risk is a 3 hp body walking where it used to hide, and the mirror is what prices that.

## plasma-no-lead — REJECT (local A/B)

- when: 2026-07-31T18:32:13+00:00
- change: `baseline/tuning.nim`: `PlasmaDetour* = 70.0         # attacker detour budget for a plasma arc pickup` -> `PlasmaDetour* = 70.0         # attacker detour budget for a plasma arc pickup
  PlasmaLeadTicks* = 0.0       # ticks of velocity lead the CONE aims with.
                              # The gun leads LeadTicks for its 5-tick
                              # windup; the cone ignites instantly and
                              # re-resolves from the live aim every active
                              # tick, so it has no windup to lead for`; `baseline/act.nim`: `f.desiredAim = bradsOf(f.aim - f.me)
    let err = abs(bradsErr(f.desiredAim, bot.estAim))` -> `let
      pt = bot.enemies[f.engage]
      hit = pt.pos + pt.vel * (float(bot.tick - pt.lastSeen) + PlasmaLeadTicks)
    f.desiredAim = bradsOf(hit - f.me)
    let err = abs(bradsErr(f.desiredAim, bot.estAim))`
- treatment: local build  control: `jordan-ctf-candidate:v82` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-plasma-no-lead.jsonl, seeds 277000-277059 both ways)
- verdict: level: K/D +0.0094 CI [-0.0135, +0.0334], win rate +0.033 CI [-0.092, +0.158], captures +2 CI [-11, +15], n=120
- pooled: 120 episodes, 0 skipped; RED won 65.8% of episodes
  - treatment: K/D 1.0047 (2554/2542), captures 31, wins 57
  - control: K/D 0.9953 (2543/2555), captures 29, wins 53
- rationale: engage.nim leads every target by `t.vel * (age + LeadTicks)` and act.nim's plasma branch aims the turret at that lead point. LeadTicks 6 is derived from the gun: the engine holds a pulled trigger for FireWindupTicks 5 and fires along the angle locked at the pull. The cone has no windup — startArcFire is instant and selectArcVictims recomputes from the attacker's CURRENT position and aim every active tick — so for plasma the lead is pure error, and the 5-tick persistence cannot recover it because our aim re-leads ahead of the target each frame. The cone half- angle is 10 brads; a crossing enemy at the engine's 2.75 px/tick leaves 16.5px of lateral offset, which is 6.7 brads at 100px and 13 brads at 50px — outside the cone exactly when the target is closest. This adds PlasmaLeadTicks (inert at 6.0) and moves it to 0.0, aiming the cone at the un-led track estimate. Hypothesis: 6 ticks was never chosen for this weapon, it was inherited from the one with a windup.

## midbottom-seat-split — REJECT (local A/B)

- when: 2026-07-31T18:33:11+00:00
- change: `baseline/objective.nim`: `of MidBottom:
      if dist(f.me, f.stealTarget) > 90:
        f.target = f.stealTarget + vec(homeSign(bot.team) * 34.0, 26.0)` -> `of MidBottom:
      if dist(f.me, f.stealTarget) > 90:
        # Seats 2/3 and seat 4 are BOTH MidBottom, so one offset stacks two
        # bodies on one point: stagger the fourth mid clear of the blast.
        f.target = f.stealTarget + vec(homeSign(bot.team) * 34.0,
          (if bot.slot div 2 == 4: 78.0 else: 26.0))`
- treatment: local build  control: `jordan-ctf-candidate:v82` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-midbottom-seat-split.jsonl, seeds 278000-278059 both ways)
- verdict: captures separate NEGATIVE: K/D -0.0410 CI [-0.0891, +0.0069], win rate -0.150 CI [-0.300, +0.000], captures -20 CI [-35, -5], n=120
- pooled: 120 episodes, 0 skipped; RED won 58.3% of episodes
  - treatment: K/D 0.9794 (2525/2578), captures 20, wins 45
  - control: K/D 1.0204 (2648/2595), captures 40, wins 63
- rationale: `roleForSeat` hands MidBottom to seat 4 AND to whichever of seats 2/3 is not MidTop, on both teams -- two seats carry one role while MidTop carries one. In the attacker branch both then compute the identical goal, `stealTarget + vec(homeSign*34, 26)`. Two bodies aimed at one point sit inside MateSpacing (40), where chooseMovement's repulsion term fights the objective for both of them, and inside NadeBlast (52), which is exactly the pair the field's own grenade planner hunts. The role's own comment claims the trailing mid is 'offset so one enemy cone cannot kill the pair'; the fourth mid was bolted onto the same offset and got no stagger of its own. Moving seat 4 to y+78 keeps it on the bottom side of the pocket approach and puts a blast centred on either body out of reach of the other. Hypothesis: unstacking the pair costs no tempo and stops feeding two-for-one trades.

## red-kit-greed — REJECT (local A/B)

- when: 2026-07-31T18:34:10+00:00
- change: `baseline/tuning.nim`: `MedKitCriticalReach* = 180.0 # at 1 hp a heal outranks the current errand` -> `MedKitCriticalReach* = 180.0 # at 1 hp a heal outranks the current errand
  RedKitGreed* = 80.0          # extra px of med-kit detour budget RED, and
                              # only red, will pay. The two kits sit exactly
                              # on the map's vertical centre line, and the
                              # engine resolves pickups in player-index
                              # order with red on the even indices, so a
                              # same-tick touch goes to red against its own
                              # mirror seat. 0.0 restores the shared budget`; `baseline/memory.nim`: `result = -1
  var best = budget` -> `result = -1
  # RED-side greed: the engine steps players in slot order and slots
  # alternate red/blue, so red's even index resolves a same-tick pickup
  # before the mirror blue seat. Both kits sit on the centre line, so that
  # tie is red's by construction -- pay more path px for the trip.
  var best = budget + (if bot.team == Red: RedKitGreed else: 0.0)`
- treatment: local build  control: `jordan-ctf-candidate:v82` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-red-kit-greed.jsonl, seeds 279000-279059 both ways)
- verdict: level: K/D +0.0055 CI [-0.0377, +0.0505], win rate -0.025 CI [-0.192, +0.150], captures +6 CI [-10, +22], n=120
- pooled: 120 episodes, 0 skipped; RED won 58.3% of episodes
  - treatment: K/D 1.0027 (2570/2563), captures 37, wins 54
  - control: K/D 0.9973 (2563/2570), captures 31, wins 57
- rationale: `applyPickupDetours` and the carry branch both size their med- kit detour through `bestKitDetour`, whose budget is team-blind. The engine seats slots red/blue alternating, so red holds every even player index, and `step()` runs `tryPickupMedKits` over `0 ..< sim.players.len` after all movement has resolved: red seat k takes a contested touch before blue seat j whenever k <= j, and always before its own mirror seat. Both kits sit exactly on the map's vertical centre line, the only cross-team contested pickup on the map -- shields, spray cans and corner grenades are all side-local. Today both teams pay the same 120/180/90 px budgets. Hypothesis: the med-kit axis has read level across five two- sided sweeps because the two sides want different numbers, and a race red wins on ties is worth more to red. Honest risks: a seed-paired mirror measures a red-only change at half power, and the tie window is one tick with both racers hurt.

## oneway-band-near-mid — REJECT (local A/B)

- when: 2026-07-31T18:35:06+00:00
- change: `baseline/posts.nim`: `OneWayBandNear = 40.0        # the target band starts this far past mid —
                              # the enemy side of the flag ring, mirroring
                              # where scanPost's own candidates stand` -> `OneWayBandNear = -80.0       # where the target band starts, measured past
                              # mid. NEGATIVE on purpose: act.nim clamps a
                              # held wave to HoldLineDepth (80) past mid into
                              # the OPPOSING half, and the field is largely
                              # this lineage, so the enemy's own staging line
                              # stands 80px inside OUR half. The band is the
                              # ground the enemy wave can occupy, from that
                              # line back to its own ring -- not the mirror
                              # of where our candidates stand`
- treatment: local build  control: `jordan-ctf-candidate:v82` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-oneway-band-near-mid.jsonl, seeds 280000-280059 both ways)
- verdict: level: K/D +0.0000 CI [+0.0000, +0.0000], win rate +0.000 CI [+0.000, +0.000], captures +0 CI [+0, +0], n=120
- pooled: 120 episodes, 0 skipped; RED won 60.0% of episodes
  - treatment: K/D 1.0000 (2589/2589), captures 36, wins 59
  - control: K/D 1.0000 (2589/2589), captures 36, wins 59
- rationale: newOneWayScan targets every standable cell 40 to 320px past mid — the enemy's side only, mirroring where our own candidates stand. But act.nim's hold-line clamp parks a wave at HoldLineDepth 80px past mid INTO the opposing half, and the field is largely this lineage, so the enemy's staging line sits 80px inside OUR half, outside the band entirely — while the overwatch itself stands at fwd -160..-40 on our side with exactly that crossing to deny. Moving the near bound to -80 makes the target set "everywhere the enemy wave can stand, from its staging line back to its own ring" instead of the mirror of our candidate band. Deep is left alone: its own comment records that no clear-ray one-way pair has a target past 320. Risk: targets now overlap the candidate band, so a short-range quantization artefact 60px from a peek would count the same as a mid-range lane shot, and the scan gets ~43% more targets.

## oneway-peek-choice — REJECT (local A/B)

- when: 2026-07-31T18:35:59+00:00
- change: `baseline/posts.nim`: `var
        peek: Vec
        peekCell = -1
        peekLine = 0.0
      for dyc in [-2, 2, -1, 1]:
        let ny = cy + dyc
        if ny < 0 or ny >= GridH or not bot.cellWalkable[ny * GridW + cx]:
          continue
        let q = cellCenter(ny * GridW + cx)
        let line = openLineLen(client, q, vec(eSign, 0.0), FireRange, 6.0)
        if line > peekLine:
          peekLine = line
          peek = q
          peekCell = ny * GridW + cx
      if peekLine < PeekLineDist:
        continue
      # The firing-line length dominates; the position terms break near-ties
      # toward the wanted flank height and hugging the flag ring.
      var score = abs(p.y - wantY) + abs(fwd + 90.0) * 0.7 - peekLine * 0.7
      if OneWayBonus != 0.0 and oneWayFogReady():
        if not oneWay.ready:
          oneWay = bot.newOneWayScan(client, eSign)
        score -= float(oneWay.oneWayCount(client, peekCell, peek)) * OneWayBonus` -> `var
        peek: Vec
        peekCell = -1
        peekBest = 1e18
      for dyc in [-2, 2, -1, 1]:
        let ny = cy + dyc
        if ny < 0 or ny >= GridH or not bot.cellWalkable[ny * GridW + cx]:
          continue
        let
          nc = ny * GridW + cx
          q = cellCenter(nc)
          line = openLineLen(client, q, vec(eSign, 0.0), FireRange, 6.0)
        if line < PeekLineDist:
          continue
        # The peek is the cell the gun stands in, so the one-way term picks it
        # rather than merely grading whichever cell the firing line picked.
        # Fog is quantized to the 8px cell of BOTH ends, so one row over is a
        # different sightline; the currency is the score's own -- a px of
        # firing line trades at 0.7, a one-way cell at OneWayBonus.
        var pscore = -line * 0.7
        if OneWayBonus != 0.0 and oneWayFogReady():
          if not oneWay.ready:
            oneWay = bot.newOneWayScan(client, eSign)
          pscore -= float(oneWay.oneWayCount(client, nc, q)) * OneWayBonus
        if pscore < peekBest:
          peekBest = pscore
          peek = q
          peekCell = nc
      if peekCell < 0:
        continue
      # The firing-line length dominates; the position terms break near-ties
      # toward the wanted flank height and hugging the flag ring.
      let score = abs(p.y - wantY) + abs(fwd + 90.0) * 0.7 + peekBest`
- treatment: local build  control: `jordan-ctf-candidate:v82` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-oneway-peek-choice.jsonl, seeds 281000-281059 both ways)
- verdict: level: K/D +0.0000 CI [+0.0000, +0.0000], win rate +0.000 CI [+0.000, +0.000], captures +0 CI [+0, +0], n=120
- pooled: 120 episodes, 0 skipped; RED won 65.0% of episodes
  - treatment: K/D 1.0000 (2540/2540), captures 37, wins 57
  - control: K/D 1.0000 (2540/2540), captures 37, wins 57
- rationale: scanPost picks the peek by `openLineLen` alone and only then prices that one cell with the one-way term (posts.nim:126-144). So the cell the gun actually stands in — the cell whose fog verdict the term counts — was chosen for a different reason, and among the four candidates (±1, ±2 rows in the same column) ties fall to list order. The engine decides visibility purely from the 8px cell of viewer and target (`fovCellAt`, `playerVisibleTo`), so one row over is a different sightline entirely; the term's own table is the thing that says these flip cell to cell. This lets the term choose the peek in the currency the candidate score already spends — 0.7 per px of firing line, OneWayBonus per one-way cell — instead of only grading a winner picked without it. Risk: up to 4x the shadowcasts at nav build, and the term already measured +3% of an episode at OneWayBonus 40.

## post-vision-shield — REJECT (local A/B)

- when: 2026-07-31T18:36:57+00:00
- change: `baseline/posts.nim`: `var
    bestScore = 1e18
    oneWay: OneWayScan                   # built on the first scored candidate` -> `let fogBlocked =
    if oneWayFogReady(): buildFovBlocked(client)
    else: newSeq[bool]()
  var
    bestScore = 1e18
    oneWay: OneWayScan                   # built on the first scored candidate`; `baseline/posts.nim`: `if rayClearCoarse(client, p, p + vec(eSign * CoverShieldDist, 0.0), 4.0):
        continue                         # nothing shields us from the front` -> `# A VISION shield, not a bullet one. The walkability mask answers what
      # stops a bullet; the fog answers what stops a look, and the two are
      # not the same wall. A cell at least half wall is fully opaque to the
      # shadowcast while still passing bullets through its wall-free pixels,
      # and glass is the exact reverse: solid to every bullet, invisible to
      # the fog. Under fog nobody shoots what they have not seen, so what a
      # standing sniper needs in front of it is the first kind.
      var shielded = false
      if not oneWayFogReady():
        shielded = not rayClearCoarse(
          client, p, p + vec(eSign * CoverShieldDist, 0.0), 4.0)
      else:
        for step in 1 .. int(CoverShieldDist) div NavCell:
          let nx = cx + int(eSign) * step
          if nx < 0 or nx >= GridW:
            break
          if fogBlocked[cy * GridW + nx]:
            shielded = true
            break
      if not shielded:
        continue                         # nothing HIDES us from the front`
- treatment: local build  control: `jordan-ctf-candidate:v82` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-post-vision-shield.jsonl, seeds 282000-282059 both ways)
- verdict: captures separate NEGATIVE: K/D -0.0241 CI [-0.0748, +0.0234], win rate -0.125 CI [-0.292, +0.042], captures -24 CI [-40, -8], n=120
- pooled: 120 episodes, 0 skipped; RED won 43.3% of episodes
  - treatment: K/D 0.9879 (2524/2555), captures 26, wins 47
  - control: K/D 1.0120 (2614/2583), captures 50, wins 62
- rationale: posts.nim:120 accepts an overwatch hold only when `rayClearCoarse(p, p + eSign*CoverShieldDist)` finds a wall pixel within 42px in front — a BULLET shield, read out of the walkability mask. Under fog what keeps a sniper alive is not being seen: every bot fires only at tracks seen within FreshShotTicks (engage.nim:72), and the field is largely this lineage. Vision runs on a different mask — fov.nim's buildFovBlocked calls a cell opaque only at `walls * 2 >= pixels`, and exempts glass outright. So a hold shielded by a thin strut, or by the mid bracket's centre pane (479,312,12,36 and its 744 mirror, the one vendored window inside either candidate band), passes today's test while the enemy shadowcast sees straight through it. This moves the front-shield test onto the occlusion grid fov.nim already builds. The converse reading of this cousin — crediting posts that shoot into ground nobody can see — is dead, because the bot cannot fire at what it never saw. Risk: concealment bought with bullet cover.

## oneway-red-off — REJECT (local A/B)

- when: 2026-07-31T18:37:53+00:00
- change: `baseline/tuning.nim`: `OneWayBonus* = 40.0           # px of post-score credit per enemy-lane cell
                              # the peek can see that can NEVER see it back
                              # (the engine's quantized shadowcast is not
                              # reciprocal; see fov.nim) with a clear bullet
                              # ray. At 0.0 the term is off and scanPost
                              # never builds the one-way table at all` -> `OneWayBonusRed* = 0.0         # px of post-score credit per enemy-lane cell
  OneWayBonusBlue* = 40.0       # the peek can see that can NEVER see it back
                              # (the engine's quantized shadowcast is not
                              # reciprocal; see fov.nim) with a clear bullet
                              # ray. At 0.0 that side's term is off and
                              # scanPost never builds its one-way table at
                              # all. PER SIDE because the fog lattice does
                              # not mirror: the map mirrors as x' = MapW-1-x
                              # and 1234 is not a multiple of NavCell, so a
                              # cell's mirror image straddles two cells and
                              # the sides hold different one-way tables --
                              # 52 red candidates to 50 blue, 13 clear-ray
                              # pairs to 16. At 40 red's best peek buys ONE
                              # extra one-way cell for 8.4px of base score
                              # and blue's buys THREE (research/LEDGER.md)`; `baseline/posts.nim`: `var
    bestScore = 1e18
    oneWay: OneWayScan                   # built on the first scored candidate` -> `# The one-way credit is priced PER SIDE: the 8px fog lattice does not
  # mirror, so red and blue hold different one-way tables. `eSign` names
  # the side whose post is being scored -- +1 is the team whose guns point
  # east, i.e. Red -- for BOTH callers, so our own post and our model of
  # the enemy's are each scored with the value that side really plays with.
  let bonus = (if eSign > 0.0: OneWayBonusRed else: OneWayBonusBlue)
  var
    bestScore = 1e18
    oneWay: OneWayScan                   # built on the first scored candidate`; `baseline/posts.nim`: `if OneWayBonus != 0.0 and oneWayFogReady():
        if not oneWay.ready:
          oneWay = bot.newOneWayScan(client, eSign)
        score -= float(oneWay.oneWayCount(client, peekCell, peek)) * OneWayBonus` -> `if bonus != 0.0 and oneWayFogReady():
        if not oneWay.ready:
          oneWay = bot.newOneWayScan(client, eSign)
        score -= float(oneWay.oneWayCount(client, peekCell, peek)) * bonus`
- treatment: local build  control: `jordan-ctf-candidate:v82` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-oneway-red-off.jsonl, seeds 284000-284059 both ways)
- verdict: wins separate NEGATIVE: K/D -0.1345 CI [-0.1791, -0.0909], win rate -0.233 CI [-0.383, -0.083], captures -24 CI [-38, -9], n=120
- pooled: 120 episodes, 0 skipped; RED won 61.7% of episodes
  - treatment: K/D 0.9337 (2479/2655), captures 18, wins 44
  - control: K/D 1.0682 (2756/2580), captures 42, wins 72
- rationale: posts.nim:141 prices the one-way fog credit with ONE constant for both teams, and the arena does not warrant one number. The engine fogs on 8px cells anchored at x=0 (sim.nim: `x div FovCellSize`), while the map mirrors as x' = MapW-1-x = 1234-x, and 1234 is not a multiple of 8 — a cell's mirror image straddles two cells 5/3, so the sides hold genuinely different one-way tables: 52 red candidates against 50 blue, 13 clear-ray pairs against 16. The ledger records what each side buys at 40: red's chosen peek gains ONE extra one-way cell for 8.4px of base score, blue's gains THREE. This splits the constant per side, keyed off eSign so our model of the enemy sniper moves with it, and zeroes RED — asking whether red's one-cell trade paid or whether the promoted +0.027 K/D was blue's alone. Inert on blue, so the mirror measures it at half amplitude rather than cancelling it.

## preaimwatch320 — REJECT (local A/B)

- when: 2026-07-31T18:38:52+00:00
- change: `PreAimWatchRange` -> `320.0`
- treatment: local build  control: `jordan-ctf-candidate:v82` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-preaimwatch320.jsonl, seeds 285000-285059 both ways)
- verdict: level: K/D +0.0038 CI [-0.0184, +0.0297], win rate +0.017 CI [-0.083, +0.133], captures +7 CI [-3, +17], n=120
- pooled: 120 episodes, 0 skipped; RED won 62.5% of episodes
  - treatment: K/D 1.0019 (2613/2608), captures 34, wins 59
  - control: K/D 0.9981 (2608/2613), captures 27, wins 57
- rationale: A keeper abandons its scan sweep only for evidence inside 200px. The scan family is the one that has paid twice on this policy (ScanArc 24 -> 28 -> 36, +0.16 K/D between them) and its lesson was consistently that wider coverage beats tighter discipline. PreAimWatchRange is the gate on the same turret from the other side: at 320 it matches PreAimRange, so the keeper pre-aims at everything the pre-aim scorer is willing to rank at all instead of throwing away the outer two thirds of that evidence. The risk is the mirror image -- a keeper that chases distant pings stops sweeping its own approach -- which is exactly what the mirror measures.

## shout-channel — REJECT (local A/B)

- when: 2026-07-31T18:47:21+00:00
- change: `ShoutMode` -> `1`
- treatment: local build  control: `jordan-ctf-candidate:v82` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-shout-channel.jsonl, seeds 286000-286059 both ways)
- verdict: level: K/D -0.0224 CI [-0.0676, +0.0240], win rate +0.108 CI [-0.058, +0.275], captures +6 CI [-10, +22], n=120
- pooled: 120 episodes, 0 skipped; RED won 64.2% of episodes
  - treatment: K/D 0.9888 (2567/2596), captures 35, wins 64
  - control: K/D 1.0113 (2604/2575), captures 29, wins 51
- rationale: The shout channel, at its cheapest setting: broadcast the nearest enemy we can see as a 32px grid cell once a second, and let a mate's fix point the turret. The vision cone RIDES THE AIM, so pointing it where a teammate says a body is, is exactly how somebody else's sighting becomes our own -- and pre-aim can neither pull a trigger nor route a path, so this level cannot produce the two failures the archive warns about (a shot down the wrong corridor kills the mate who shouted; every intel addition so far made the bot more timid and deaths rose). Shouts carry ~247px through walls and fog, which is precisely the ground the cone cannot reach.

## shout-peek — PROMOTE (local A/B)

- when: 2026-07-31T18:50:03+00:00
- change: `ShoutMode` -> `3`
- treatment: local build  control: `jordan-ctf-candidate:v82` (the tree)
- shipped as: `jordan-ctf-candidate:v83`
- measured on: the local simulator, seed-paired mirrors (episodes/exp-shout-peek.jsonl, seeds 287000-287059 both ways, seeds 287200-287339 both ways)
- verdict: separates positive on the pooled sample: K/D +0.1635 CI [+0.1398, +0.1866], win rate +0.285 CI [+0.217, +0.352], captures +27 CI [+4, +51], n=400
- pooled: 400 episodes, 0 skipped; RED won 75.8% of episodes
  - treatment: K/D 1.0849 (8956/8255), captures 100, wins 246
  - control: K/D 0.9214 (8221/8922), captures 73, wins 132
- rationale: The same channel, wired to the peek branch as well: a fix BEHIND A WALL becomes a pre-lay candidate, so the bot steps to the cell that opens the line with the traverse already done. This is the level that can actually change where the bot stands, and it is the one with a mechanism the pre-aim level does not have -- a wall is exactly what makes a mate's eyes worth more than our own. Still never a fire target.

## shout-peek-further — REJECT (local A/B)

- when: 2026-07-31T18:51:03+00:00
- change: `ShoutMode` -> `6`
- treatment: local build  control: `jordan-ctf-candidate:v83` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-shout-peek-further.jsonl, seeds 288000-288059 both ways)
- verdict: level: K/D +0.0000 CI [+0.0000, +0.0000], win rate +0.000 CI [+0.000, +0.000], captures +0 CI [+0, +0], n=120
- pooled: 120 episodes, 0 skipped; RED won 48.3% of episodes
  - treatment: K/D 1.0000 (2602/2602), captures 28, wins 56
  - control: K/D 1.0000 (2602/2602), captures 28, wins 56
- rationale: Derived from shout-peek: ShoutMode paid at 3, so walk the same way again to 6 and find where it stops paying.

## shout-nades — REJECT (local A/B)

- when: 2026-07-31T18:52:02+00:00
- change: `ShoutMode` -> `2`
- treatment: local build  control: `jordan-ctf-candidate:v83` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-shout-nades.jsonl, seeds 289000-289059 both ways)
- verdict: wins separate NEGATIVE: K/D -0.1144 CI [-0.1594, -0.0690], win rate -0.283 CI [-0.433, -0.133], captures -21 CI [-35, -7], n=120
- pooled: 120 episodes, 0 skipped; RED won 69.2% of episodes
  - treatment: K/D 0.9444 (2513/2661), captures 17, wins 39
  - control: K/D 1.0588 (2665/2517), captures 38, wins 73
- rationale: The channel wired to the grenade planner instead: a lob clears every wall between here and there, which is the case a shout describes and the gun cannot answer. Priced like a foe sonar ping, which is the closest thing already in the tree -- both are second-hand marks on ground rather than a target we are looking at, and NadeFoePing is a term that has already paid.

## shout-nades-reverse — REJECT (local A/B)

- when: 2026-07-31T18:53:03+00:00
- change: `ShoutMode` -> `4`
- treatment: local build  control: `jordan-ctf-candidate:v83` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-shout-nades-reverse.jsonl, seeds 290000-290059 both ways)
- verdict: level: K/D +0.0000 CI [+0.0000, +0.0000], win rate +0.000 CI [+0.000, +0.000], captures +0 CI [+0, +0], n=120
- pooled: 120 episodes, 0 skipped; RED won 65.0% of episodes
  - treatment: K/D 1.0000 (2623/2623), captures 28, wins 55
  - control: K/D 1.0000 (2623/2623), captures 28, wins 55
- rationale: Derived from shout-nades: ShoutMode measured worse at 2, so the constant is worth testing in the other direction at 4.

## latticehold6 — PROMOTE (local A/B)

- when: 2026-07-31T18:55:56+00:00
- change: `LatticeHoldSlack` -> `6.0`
- treatment: local build  control: `jordan-ctf-candidate:v83` (the tree)
- shipped as: `jordan-ctf-candidate:v84`
- measured on: the local simulator, seed-paired mirrors (episodes/exp-latticehold6.jsonl, seeds 291000-291059 both ways, seeds 291200-291339 both ways)
- verdict: separates positive on the pooled sample: K/D +0.0800 CI [+0.0531, +0.1066], win rate +0.250 CI [+0.165, +0.338], captures +56 CI [+30, +82], n=400
- pooled: 400 episodes, 0 skipped; RED won 63.7% of episodes
  - treatment: K/D 1.0408 (8796/8451), captures 129, wins 243
  - control: K/D 0.9608 (8464/8809), captures 73, wins 143
- rationale: The engine keys a player's whole shadowcast on (originCell, aimBrads) and caches it there, so visibility is a step function of position with steps every 8px and two bodies in one cell see an identical map. HoldArriveDist is 6px against an 8px cell, so a watch keeper can come to rest one cell off the cell its post was SCORED in -- collecting none of the one-way sightlines OneWayBonus paid for, and none of the concealment either. 6.0 is the loudest version: fix every miss the existing tolerance can produce. Expect this to read level -- it reaches two seats and recovers a fraction of a term worth +0.027 K/D whole -- and read a level here as the instrument, not as the mechanism.

## latticehold6-further — REJECT (local A/B)

- when: 2026-07-31T18:56:57+00:00
- change: `LatticeHoldSlack` -> `12.0`
- treatment: local build  control: `jordan-ctf-candidate:v84` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-latticehold6-further.jsonl, seeds 292000-292059 both ways)
- verdict: level: K/D +0.0000 CI [+0.0000, +0.0000], win rate +0.000 CI [+0.000, +0.000], captures +0 CI [+0, +0], n=120
- pooled: 120 episodes, 0 skipped; RED won 78.3% of episodes
  - treatment: K/D 1.0000 (2557/2557), captures 32, wins 57
  - control: K/D 1.0000 (2557/2557), captures 32, wins 57
- rationale: Derived from latticehold6: LatticeHoldSlack paid at 6.0, so walk the same way again to 12 and find where it stops paying.

## duckarrive2 — REJECT (local A/B)

- when: 2026-07-31T18:58:01+00:00
- change: `DuckArriveDist` -> `2.0`
- treatment: local build  control: `jordan-ctf-candidate:v84` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-duckarrive2.jsonl, seeds 293000-293059 both ways)
- verdict: level: K/D -0.0297 CI [-0.0757, +0.0175], win rate -0.083 CI [-0.250, +0.083], captures -8 CI [-24, +8], n=120
- pooled: 120 episodes, 0 skipped; RED won 45.0% of episodes
  - treatment: K/D 0.9852 (2602/2641), captures 28, wins 51
  - control: K/D 1.0149 (2651/2612), captures 36, wins 61
- rationale: findDuckCell picks the cell whose CENTRE the threat's ray cannot reach, and act.nim stops 5px short of it -- from where the ray may be open again. Unlike the lattice pin this fires for all eight seats on every cooldown and the payoff per event is a hit point rather than a sightline, which is ~50x the events at a bigger stake.

## duckarrive2-reverse — REJECT (local A/B)

- when: 2026-07-31T19:00:44+00:00
- change: `DuckArriveDist` -> `8.0`
- treatment: local build  control: `jordan-ctf-candidate:v84` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-duckarrive2-reverse.jsonl, seeds 294000-294059 both ways, seeds 294200-294339 both ways)
- verdict: level: K/D -0.0007 CI [-0.0265, +0.0252], win rate +0.040 CI [-0.050, +0.133], captures +46 CI [+20, +71], n=400
- pooled: 400 episodes, 0 skipped; RED won 44.8% of episodes
  - treatment: K/D 0.9997 (8795/8798), captures 117, wins 192
  - control: K/D 1.0003 (8601/8598), captures 71, wins 176
- rationale: Derived from duckarrive2: DuckArriveDist measured worse at 2.0, so the constant is worth testing in the other direction at 8.

## peekarrive2 — REJECT (local A/B)

- when: 2026-07-31T19:03:42+00:00
- change: `PeekArriveDist` -> `2.0`
- treatment: local build  control: `jordan-ctf-candidate:v84` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-peekarrive2.jsonl, seeds 295000-295059 both ways, seeds 295200-295339 both ways)
- verdict: level: K/D -0.0091 CI [-0.0365, +0.0193], win rate -0.018 CI [-0.102, +0.070], captures -11 CI [-37, +16], n=400
- pooled: 400 episodes, 0 skipped; RED won 68.2% of episodes
  - treatment: K/D 0.9955 (8594/8633), captures 93, wins 184
  - control: K/D 1.0045 (8628/8589), captures 104, wins 191
- rationale: The mirror of duckarrive2 on the other arrival: findPeekCell picks the cell from which OUR ray reaches the target, and the step stops 4px short of it. The peek is the bot's default combat mode, so this is the arrival with the most events of the three.

## peekarrive2-reverse — PROMOTE (local A/B)

- when: 2026-07-31T19:06:42+00:00
- change: `PeekArriveDist` -> `6.0`
- treatment: local build  control: `jordan-ctf-candidate:v84` (the tree)
- shipped as: `jordan-ctf-candidate:v85`
- measured on: the local simulator, seed-paired mirrors (episodes/exp-peekarrive2-reverse.jsonl, seeds 296000-296059 both ways, seeds 296200-296339 both ways)
- verdict: separates positive on the pooled sample: K/D +0.0309 CI [+0.0046, +0.0577], win rate +0.125 CI [+0.040, +0.210], captures +18 CI [-8, +44], n=400
- pooled: 400 episodes, 0 skipped; RED won 68.2% of episodes
  - treatment: K/D 1.0156 (8663/8530), captures 112, wins 214
  - control: K/D 0.9847 (8538/8671), captures 94, wins 164
- rationale: Derived from peekarrive2: PeekArriveDist measured worse at 2.0, so the constant is worth testing in the other direction at 6.

## peekarrive2-reverse-further — REJECT (local A/B)

- when: 2026-07-31T19:07:44+00:00
- change: `PeekArriveDist` -> `8.0`
- treatment: local build  control: `jordan-ctf-candidate:v85` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-peekarrive2-reverse-further.jsonl, seeds 297000-297059 both ways)
- verdict: captures separate NEGATIVE: K/D +0.0161 CI [-0.0275, +0.0584], win rate -0.017 CI [-0.158, +0.133], captures -14 CI [-27, -1], n=120
- pooled: 120 episodes, 0 skipped; RED won 55.8% of episodes
  - treatment: K/D 1.0081 (2623/2602), captures 19, wins 51
  - control: K/D 0.9920 (2607/2628), captures 33, wins 53
- rationale: Derived from peekarrive2-reverse: PeekArriveDist paid at 6.0, so walk the same way again to 8 and find where it stops paying.

## onewayblue80 — REJECT (local A/B)

- when: 2026-07-31T19:08:45+00:00
- change: `OneWayBonusBlue` -> `80.0`
- treatment: local build  control: `jordan-ctf-candidate:v85` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-onewayblue80.jsonl, seeds 298000-298059 both ways)
- verdict: level: K/D +0.0000 CI [+0.0000, +0.0000], win rate +0.000 CI [+0.000, +0.000], captures +0 CI [+0, +0], n=120
- pooled: 120 episodes, 0 skipped; RED won 78.3% of episodes
  - treatment: K/D 1.0000 (2594/2594), captures 32, wins 60
  - control: K/D 1.0000 (2594/2594), captures 32, wins 60
- rationale: analysis/role_bleed.md, over 3160 post-re-pin local episodes: the side deficit is not team-wide, it is TWO SEATS pointing opposite ways, and the larger is Overwatch at +0.515 K/D red over blue (15 of 17 files agree in sign; the permutation null explains at most ~9% of it). Overwatch is the seat whose whole job is the post OneWayBonus scores, the fog lattice does not mirror (52 red candidates to 50 blue, 13 clear-ray pairs to 16), and turning red's term OFF cost -0.1345 K/D -- so the term is load-bearing and blue's half is the half that is losing. Read a per-side result by DOUBLING it (see LEDGER.md).

## shout-eavesdrop — PROMOTE (local A/B)

- when: 2026-07-31T19:11:36+00:00
- change: `ShoutHearFoe` -> `1`
- treatment: local build  control: `jordan-ctf-candidate:v85` (the tree)
- shipped as: `jordan-ctf-candidate:v86`
- measured on: the local simulator, seed-paired mirrors (episodes/exp-shout-eavesdrop.jsonl, seeds 299000-299059 both ways, seeds 299200-299339 both ways)
- verdict: separates positive on the pooled sample: K/D +0.0923 CI [+0.0678, +0.1170], win rate +0.297 CI [+0.205, +0.388], captures +33 CI [+5, +61], n=400
- pooled: 400 episodes, 0 skipped; RED won 55.8% of episodes
  - treatment: K/D 1.0477 (8804/8403), captures 112, wins 246
  - control: K/D 0.9554 (8592/8993), captures 79, wins 127
- rationale: The other half of the shout channel, and the half that needs no vocabulary at all: a hostile speech bubble is drawn hanging on the enemy who made it, so its ANCHOR is that enemy, within the same +-20px the engine fuzzes a shot ring by, delivered through walls and fog. This could not be measured before shout-peek landed — the other side of a local mirror is this same policy, so a silent tree meant a silent enemy and the gate measured a level that meant nothing. The tree now emits, so the enemy in every local episode is now a talker and the intel is real. Against the league it is strictly better than that: the players ranked above us broadcast constantly.

## shout-eavesdrop-further — REJECT (local A/B)

- when: 2026-07-31T19:12:37+00:00
- change: `ShoutHearFoe` -> `2`
- treatment: local build  control: `jordan-ctf-candidate:v86` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-shout-eavesdrop-further.jsonl, seeds 300000-300059 both ways)
- verdict: level: K/D +0.0000 CI [+0.0000, +0.0000], win rate +0.000 CI [+0.000, +0.000], captures +0 CI [+0, +0], n=120
- pooled: 120 episodes, 0 skipped; RED won 40.0% of episodes
  - treatment: K/D 1.0000 (2628/2628), captures 28, wins 54
  - control: K/D 1.0000 (2628/2628), captures 28, wins 54
- rationale: Derived from shout-eavesdrop: ShoutHearFoe paid at 1, so walk the same way again to 2 and find where it stops paying.

## shoutcell16 — REJECT (local A/B)

- when: 2026-07-31T19:15:27+00:00
- change: `ShoutCellPx` -> `16`
- treatment: local build  control: `jordan-ctf-candidate:v86` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-shoutcell16.jsonl, seeds 301000-301059 both ways, seeds 301200-301339 both ways)
- verdict: level: K/D +0.0059 CI [-0.0188, +0.0302], win rate -0.018 CI [-0.107, +0.072], captures -18 CI [-45, +9], n=400
- pooled: 400 episodes, 0 skipped; RED won 50.2% of episodes
  - treatment: K/D 1.0030 (8755/8729), captures 80, wins 181
  - control: K/D 0.9970 (8735/8761), captures 98, wins 188
- rationale: The vocabulary's resolution. A fix names a 32px cell, which is why a heard fix is a peek candidate and never a fire target — the fire gate is a ~14px corridor. Halving the cell to 16px still fits ten characters (two digits each at 78x42 cells) and roughly halves the error the peek branch pre-lays against. shout-peek is worth +0.164 K/D whole, so the fraction of it lost to cell error is worth asking about.

## holdarrive10 — PROMOTE (local A/B)

- when: 2026-07-31T19:19:00+00:00
- change: `HoldArriveDist` -> `10.0`
- treatment: local build  control: `jordan-ctf-candidate:v86` (the tree)
- shipped as: `jordan-ctf-candidate:v87`
- measured on: the local simulator, seed-paired mirrors (episodes/exp-holdarrive10.jsonl, seeds 303000-303059 both ways, seeds 303200-303339 both ways)
- verdict: separates positive on the pooled sample: K/D +0.0183 CI [-0.0061, +0.0427], win rate +0.117 CI [+0.025, +0.210], captures +36 CI [+11, +62], n=400
- pooled: 400 episodes, 0 skipped; RED won 54.0% of episodes
  - treatment: K/D 1.0092 (8888/8807), captures 101, wins 208
  - control: K/D 0.9909 (8784/8865), captures 65, wins 161
- rationale: The lattice pin only fires inside HoldArriveDist, so this radius now sets how much ground a keeper will claim its own post's cell from — before the pin landed, widening it only meant stopping sooner and further out, which is why 6 was never worth moving. latticehold6 is worth +0.080 K/D and the pin's own follow-up measured EXACTLY inert at 12 (a 6px tolerance cannot present an offset above 5.66), so the slack is saturated and this radius is the axis that is left.

## holdarrive10-further — REJECT (local A/B)

- when: 2026-07-31T19:20:11+00:00
- change: `HoldArriveDist` -> `14.0`
- treatment: local build  control: `jordan-ctf-candidate:v87` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-holdarrive10-further.jsonl, seeds 304000-304059 both ways)
- verdict: wins separate NEGATIVE: K/D -0.0898 CI [-0.1287, -0.0509], win rate -0.333 CI [-0.467, -0.192], captures -10 CI [-22, +2], n=120
- pooled: 120 episodes, 0 skipped; RED won 67.5% of episodes
  - treatment: K/D 0.9562 (2573/2691), captures 18, wins 36
  - control: K/D 1.0460 (2685/2567), captures 28, wins 76
- rationale: Derived from holdarrive10: HoldArriveDist paid at 10.0, so walk the same way again to 14 and find where it stops paying.

## holdarrive10-further-reverse — REJECT (local A/B)

- when: 2026-07-31T19:21:16+00:00
- change: `HoldArriveDist` -> `6.0`
- treatment: local build  control: `jordan-ctf-candidate:v87` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-holdarrive10-further-reverse.jsonl, seeds 305000-305059 both ways)
- verdict: level: K/D +0.0136 CI [-0.0367, +0.0631], win rate -0.008 CI [-0.192, +0.167], captures +6 CI [-8, +20], n=120
- pooled: 120 episodes, 0 skipped; RED won 50.8% of episodes
  - treatment: K/D 1.0068 (2669/2651), captures 28, wins 56
  - control: K/D 0.9932 (2633/2651), captures 22, wins 57
- rationale: Derived from holdarrive10-further: HoldArriveDist measured worse at 14.0, so the constant is worth testing in the other direction at 6.

## onewayblue0 — REJECT (local A/B)

- when: 2026-07-31T19:22:25+00:00
- change: `OneWayBonusBlue` -> `0.0`
- treatment: local build  control: `jordan-ctf-candidate:v87` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-onewayblue0.jsonl, seeds 306000-306059 both ways)
- verdict: wins separate NEGATIVE: K/D -0.1027 CI [-0.1475, -0.0587], win rate -0.300 CI [-0.458, -0.133], captures -23 CI [-36, -9], n=120
- pooled: 120 episodes, 0 skipped; RED won 65.0% of episodes
  - treatment: K/D 0.9499 (2502/2634), captures 16, wins 36
  - control: K/D 1.0526 (2643/2511), captures 39, wins 72
- rationale: A diagnostic, and the reason it is worth an experiment slot is what `onewayblue80` did: doubling blue's one-way credit measured EXACTLY inert — K/D +0.0000, CI [0, 0], every episode bit-identical. Meanwhile turning RED's term off cost -0.1345. So either blue's term is saturated (doubling cannot move an argmin it already wins) or blue's term is DEAD, and those two look identical from above. Zero tells them apart in one run: inert again means blue has been playing without the term the whole time, which is a mechanism for the +0.515 K/D Overwatch side gap in analysis/role_bleed.md and a bug to fix rather than a knob to turn. A real regression means the term is live and saturated, and the axis is closed.

## preaimwatchttl60 — PROMOTE (local A/B)

- when: 2026-07-31T19:25:18+00:00
- change: `PreAimWatchTtl` -> `60`
- treatment: local build  control: `jordan-ctf-candidate:v87` (the tree)
- shipped as: `jordan-ctf-candidate:v88`
- measured on: the local simulator, seed-paired mirrors (episodes/exp-preaimwatchttl60.jsonl, seeds 307000-307059 both ways, seeds 307200-307339 both ways)
- verdict: separates positive on the pooled sample: K/D +0.0098 CI [-0.0043, +0.0240], win rate +0.052 CI [+0.003, +0.105], captures +14 CI [-1, +29], n=400
- pooled: 400 episodes, 0 skipped; RED won 46.8% of episodes
  - treatment: K/D 1.0049 (8777/8734), captures 96, wins 193
  - control: K/D 0.9951 (8734/8777), captures 82, wins 172
- rationale: The other half of the keeper's leave-the-sweep gate, and the cheaper half to be wrong about: 30 ticks is ~1.25s, shorter than the turret needs to traverse the far half of its cone at AimRate 5. So the keeper can start a swing toward a fresh sighting and have the licence expire before the gun arrives, paying the traverse and getting neither the pre-aim nor the sweep. 60 matches PreAimPingTtl, the freshness the pre-aim scorer itself trusts, and makes the two gates agree.

## preaimwatchttl60-further — REJECT (local A/B)

- when: 2026-07-31T19:26:18+00:00
- change: `PreAimWatchTtl` -> `90`
- treatment: local build  control: `jordan-ctf-candidate:v88` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-preaimwatchttl60-further.jsonl, seeds 308000-308059 both ways)
- verdict: level: K/D +0.0015 CI [+0.0000, +0.0038], win rate +0.000 CI [+0.000, +0.000], captures +0 CI [+0, +0], n=120
- pooled: 120 episodes, 0 skipped; RED won 51.7% of episodes
  - treatment: K/D 1.0008 (2625/2623), captures 25, wins 55
  - control: K/D 0.9992 (2623/2625), captures 25, wins 55
- rationale: Derived from preaimwatchttl60: PreAimWatchTtl paid at 60, so walk the same way again to 90 and find where it stops paying.

## backguardarc128 — REJECT (local A/B)

- when: 2026-07-31T19:27:18+00:00
- change: `BackGuardArc` -> `128`
- treatment: local build  control: `jordan-ctf-candidate:v88` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-backguardarc128.jsonl, seeds 309000-309059 both ways)
- verdict: level: K/D -0.0008 CI [-0.0401, +0.0378], win rate -0.058 CI [-0.200, +0.083], captures -5 CI [-17, +7], n=120
- pooled: 120 episodes, 0 skipped; RED won 50.0% of episodes
  - treatment: K/D 0.9996 (2625/2626), captures 24, wins 51
  - control: K/D 1.0004 (2624/2623), captures 29, wins 58
- rationale: BackGuardRange is 260px, which on a 1235px arena covers most of any real fight, and inside it BackGuardArc clamps the aim to 96 brads of the known enemy -- so the constant that most often overrides the scan sweep is one nobody has ever moved. ScanArc paid twice by buying wider coverage, and this is the clamp that cancels it whenever a live enemy is anywhere nearby. 128 is a half-turn: the guard still forbids turning the back fully on a known body, and everything short of that becomes available to the sweep again.

## backguardarc128-reverse — REJECT (local A/B)

- when: 2026-07-31T19:28:19+00:00
- change: `BackGuardArc` -> `64`
- treatment: local build  control: `jordan-ctf-candidate:v88` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-backguardarc128-reverse.jsonl, seeds 310000-310059 both ways)
- verdict: level: K/D -0.0091 CI [-0.0478, +0.0297], win rate -0.075 CI [-0.217, +0.067], captures -1 CI [-14, +12], n=120
- pooled: 120 episodes, 0 skipped; RED won 56.7% of episodes
  - treatment: K/D 0.9955 (2633/2645), captures 22, wins 50
  - control: K/D 1.0046 (2640/2628), captures 23, wins 59
- rationale: Derived from backguardarc128: BackGuardArc measured worse at 128, so the constant is worth testing in the other direction at 64.

## hpfocus120 — REJECT (local A/B)

- when: 2026-07-31T19:29:25+00:00
- change: `HpFocusBonus` -> `120.0`
- treatment: local build  control: `jordan-ctf-candidate:v88` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-hpfocus120.jsonl, seeds 311000-311059 both ways)
- verdict: level: K/D +0.0076 CI [-0.0135, +0.0310], win rate +0.008 CI [-0.075, +0.092], captures +4 CI [-3, +12], n=120
- pooled: 120 episodes, 0 skipped; RED won 54.2% of episodes
  - treatment: K/D 1.0038 (2645/2635), captures 31, wins 58
  - control: K/D 0.9962 (2636/2646), captures 27, wins 57
- rationale: Listed in the backlog as considered and dropped on the timidity prior -- a prior that cuts the OTHER way for aim constants and was never actually tested on one. HpFocusBonus is px of credit per missing enemy hit point when choosing between targets: at 60 a two-pip-wounded enemy is worth 120px of effective distance against a healthy one, less than the width of one plasma cone reach, so the choice is usually made on geometry alone. A hurt enemy is one hit from a kill and a kill is the only thing that removes a body from the map; at 120 finishing the wounded one outbids a modestly closer healthy one, which is aggression, not timidity.

## traversepx24 — REJECT (local A/B)

- when: 2026-07-31T19:30:26+00:00
- change: `TraversePxPerBrad` -> `2.4`
- treatment: local build  control: `jordan-ctf-candidate:v88` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-traversepx24.jsonl, seeds 312000-312059 both ways)
- verdict: wins separate NEGATIVE: K/D -0.0189 CI [-0.0350, -0.0030], win rate -0.092 CI [-0.183, -0.008], captures -8 CI [-17, +0], n=120
- pooled: 120 episodes, 0 skipped; RED won 40.8% of episodes
  - treatment: K/D 0.9906 (2633/2658), captures 26, wins 48
  - control: K/D 1.0095 (2661/2636), captures 34, wins 59
- rationale: The third of the backlog's untested aim constants, and the one with a derivation to check rather than a taste to argue: 1.6 is 8px of enemy closing motion per tick divided by AimRate 5. That assumes the target closes at 8px/tick, which is the sprint speed of something running straight at us; a target that is strafing, holding a lane or walking away closes far slower, so the constant systematically UNDER-prices traverse for every target that is not charging. 2.4 says a cross-cone swing costs what half the map does, which is the honest price of arriving late to a fight the turret chose while a nearer target went unshot.

## traversepx24-reverse — REJECT (local A/B)

- when: 2026-07-31T19:31:27+00:00
- change: `TraversePxPerBrad` -> `0.8000000000000003`
- treatment: local build  control: `jordan-ctf-candidate:v88` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-traversepx24-reverse.jsonl, seeds 313000-313059 both ways)
- verdict: level: K/D -0.0015 CI [-0.0183, +0.0167], win rate -0.008 CI [-0.075, +0.058], captures -1 CI [-7, +5], n=120
- pooled: 120 episodes, 0 skipped; RED won 46.7% of episodes
  - treatment: K/D 0.9992 (2636/2638), captures 27, wins 54
  - control: K/D 1.0008 (2632/2630), captures 28, wins 55
- rationale: Derived from traversepx24: TraversePxPerBrad measured worse at 2.4, so the constant is worth testing in the other direction at 0.8.

## carrierfire180 — PROMOTE (local A/B)

- when: 2026-07-31T19:34:37+00:00
- change: `CarrierFireRange` -> `180.0`
- treatment: local build  control: `jordan-ctf-candidate:v88` (the tree)
- shipped as: `jordan-ctf-candidate:v89`
- measured on: the local simulator, seed-paired mirrors (episodes/exp-carrierfire180.jsonl, seeds 314000-314059 both ways, seeds 314200-314339 both ways)
- verdict: separates positive on the pooled sample: K/D +0.0287 CI [+0.0102, +0.0477], win rate +0.080 CI [+0.000, +0.160], captures +13 CI [-11, +37], n=400
- pooled: 400 episodes, 0 skipped; RED won 50.5% of episodes
  - treatment: K/D 1.0145 (8840/8714), captures 90, wins 199
  - control: K/D 0.9857 (8716/8842), captures 77, wins 167
- rationale: While carrying the flag the bot shoots only what is inside 110px -- under one plasma reach past its own footprint, and far inside the gun's real range. The intent is obvious (a carrier that stops to fight is a carrier that does not score) but the number was never measured, and it is the gate on the ONE seat whose death hands the flag straight back. 180 still refuses every distant duel and adds only the band where a chaser is about to be in plasma range anyway -- the shots that decide whether the run finishes.

## carrierfire180-further — REJECT (local A/B)

- when: 2026-07-31T19:35:37+00:00
- change: `CarrierFireRange` -> `250.0`
- treatment: local build  control: `jordan-ctf-candidate:v89` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-carrierfire180-further.jsonl, seeds 315000-315059 both ways)
- verdict: level: K/D -0.0176 CI [-0.0613, +0.0257], win rate -0.108 CI [-0.258, +0.042], captures -10 CI [-22, +2], n=120
- pooled: 120 episodes, 0 skipped; RED won 52.5% of episodes
  - treatment: K/D 0.9912 (2600/2623), captures 17, wins 48
  - control: K/D 1.0088 (2635/2612), captures 27, wins 61
- rationale: Derived from carrierfire180: CarrierFireRange paid at 180.0, so walk the same way again to 250 and find where it stops paying.

## carrierfire180-further-reverse — REJECT (local A/B)

- when: 2026-07-31T19:36:38+00:00
- change: `CarrierFireRange` -> `110.0`
- treatment: local build  control: `jordan-ctf-candidate:v89` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-carrierfire180-further-reverse.jsonl, seeds 316000-316059 both ways)
- verdict: level: K/D +0.0061 CI [-0.0361, +0.0478], win rate +0.017 CI [-0.125, +0.158], captures +2 CI [-10, +14], n=120
- pooled: 120 episodes, 0 skipped; RED won 60.0% of episodes
  - treatment: K/D 1.0031 (2616/2608), captures 28, wins 57
  - control: K/D 0.9969 (2610/2618), captures 26, wins 55
- rationale: Derived from carrierfire180-further: CarrierFireRange measured worse at 250.0, so the constant is worth testing in the other direction at 110.

## threatrange120 — REJECT (local A/B)

- when: 2026-07-31T19:37:39+00:00
- change: `ThreatRange` -> `120`
- treatment: local build  control: `jordan-ctf-candidate:v89` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-threatrange120.jsonl, seeds 317000-317059 both ways)
- verdict: wins separate NEGATIVE: K/D -0.0964 CI [-0.1405, -0.0527], win rate -0.242 CI [-0.367, -0.108], captures -18 CI [-29, -7], n=120
- pooled: 120 episodes, 0 skipped; RED won 73.3% of episodes
  - treatment: K/D 0.9528 (2522/2647), captures 14, wins 43
  - control: K/D 1.0492 (2667/2542), captures 32, wins 72
- rationale: chooseMovement's FIRST branch takes the whole frame for any visible enemy inside ThreatRange whose sprite side faces us, setting `f.moveMask = octantBits(side + away * 0.4)` and skipping the entire else-branch: navSteer's cost-field route, the mate repulsion, the hold-line clamp and the serpentine all go unused. The `facingMe` test is a left/right sprite flag (perception.nim:421 `facingRight: side == 0`), not an aim reading, so roughly half of everything visible inside 200px qualifies; the seats that land here are the ones that cannot engage — rushers on cooldown (the duck branch excludes `f.rushing`) and anyone whose visible enemy is outside its own maxEngage, i.e. largely the mid trio, which spends all three lives in 93-98% of episodes (analysis/role_bleed.md). The route it discards is the most expensive thing this tree owns: ExposedCost 14 -> 22 separated +0.0937 K/D [+0.0679, +0.1199] at n=400, with 30 and 6 both separating NEGATIVE. ThreatRange has one consumer (act.nim:98) and has never been moved since the initial commit; at 120 the 120-200px band goes back to the exposure-priced route, where the serpentine (SerpentineNear 100 / SerpentineFar 400, lateral blend 0.6) already supplies a weave whenever a fresh track has a clear ray. Expect the rushing mids to press along a route just proven worth ~0.09 K/D instead of sidestepping contact they were never going to trade — and if the jink was buying real dodges inside the engine's 5-tick fire windup, the loop's own reverse (280) reads the other side of the axis.

## threatrange120-reverse — PROMOTE (local A/B)

- when: 2026-07-31T19:43:02+00:00
- change: `ThreatRange` -> `280.0`
- treatment: local build  control: `jordan-ctf-candidate:v89` (the tree)
- shipped as: `jordan-ctf-candidate:v90`
- measured on: the local simulator, seed-paired mirrors (episodes/exp-threatrange120-reverse.jsonl, seeds 318000-318059 both ways, seeds 318200-318339 both ways)
- verdict: separates positive on the pooled sample: K/D +0.0519 CI [+0.0267, +0.0784], win rate +0.100 CI [+0.015, +0.188], captures -6 CI [-30, +18], n=400
- pooled: 400 episodes, 0 skipped; RED won 68.2% of episodes
  - treatment: K/D 1.0265 (8765/8539), captures 78, wins 209
  - control: K/D 0.9746 (8669/8895), captures 84, wins 169
- rationale: Derived from threatrange120: ThreatRange measured worse at 120, so the constant is worth testing in the other direction at 280.

## threatrange120-reverse-further — REJECT (local A/B)

- when: 2026-07-31T19:43:26+00:00
- change: `ThreatRange` -> `360.0`
- treatment: local build  control: `jordan-ctf-candidate:v90` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-threatrange120-reverse-further.jsonl, seeds 319000-319059 both ways)
- verdict: wins separate NEGATIVE: K/D -0.0659 CI [-0.1115, -0.0190], win rate -0.192 CI [-0.367, -0.017], captures -16 CI [-29, -3], n=120
- pooled: 120 episodes, 0 skipped; RED won 49.2% of episodes
  - treatment: K/D 0.9673 (2571/2658), captures 18, wins 45
  - control: K/D 1.0331 (2713/2626), captures 34, wins 68
- rationale: Derived from threatrange120-reverse: ThreatRange paid at 280.0, so walk the same way again to 360 and find where it stops paying.

## threatrange120-reverse-further-reverse — REJECT (local A/B)

- when: 2026-07-31T19:43:49+00:00
- change: `ThreatRange` -> `200.0`
- treatment: local build  control: `jordan-ctf-candidate:v90` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-threatrange120-reverse-further-reverse.jsonl, seeds 320000-320059 both ways)
- verdict: level: K/D -0.0446 CI [-0.0970, +0.0061], win rate -0.050 CI [-0.200, +0.100], captures +2 CI [-13, +17], n=120
- pooled: 120 episodes, 0 skipped; RED won 70.0% of episodes
  - treatment: K/D 0.9782 (2598/2656), captures 27, wins 55
  - control: K/D 1.0228 (2603/2545), captures 25, wins 61
- rationale: Derived from threatrange120-reverse-further: ThreatRange measured worse at 360.0, so the constant is worth testing in the other direction at 200.

## lookahead3 — REJECT (local A/B)

- when: 2026-07-31T19:44:12+00:00
- change: `LookaheadCells` -> `3`
- treatment: local build  control: `jordan-ctf-candidate:v90` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-lookahead3.jsonl, seeds 321000-321059 both ways)
- verdict: wins separate NEGATIVE: K/D -0.0990 CI [-0.1532, -0.0478], win rate -0.308 CI [-0.467, -0.142], captures -35 CI [-48, -21], n=120
- pooled: 120 episodes, 0 skipped; RED won 36.7% of episodes
  - treatment: K/D 0.9517 (2524/2652), captures 13, wins 37
  - control: K/D 1.0507 (2652/2524), captures 48, wins 74
- rationale: navSteer (navgrid.nim:291) walks up to LookaheadCells steps down the steepest-descent path and steers at the FURTHEST of those cells that still passes `bot.gridRayClear`, which samples `cellWalkable` only (grid.nim:183) and knows nothing about the exposure field — so wherever the cost field bends around watched ground (a watched cell is by definition not a wall) the lookahead cuts straight back across the bend, up to ~68px of it. ExposedCost was just re-priced upward on exactly that ground: 14 -> 22 separated +0.0937 K/D [+0.0679, +0.1199] at n=400, while 30 and 6 both separated negative, so the field now bends further than ever and the shortcut across the bend costs more than it ever has. The constant has one consumer and has never been moved since the initial commit; halving it makes the feet follow the route the field actually computed, every frame for every seat that is navigating. Expect the same cost field, more of it actually walked. The risk is what the lookahead was for: at 3 cells (~24px) the steering may flip between adjacent octants along a corridor and lose ground speed — which would show up first in captures — and `f.desiredAim = bradsOf(steer)` rides the same vector, so a wobblier steer is also a wobblier cruise aim.

## lookahead3-reverse — REJECT (local A/B)

- when: 2026-07-31T19:44:35+00:00
- change: `LookaheadCells` -> `9`
- treatment: local build  control: `jordan-ctf-candidate:v90` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-lookahead3-reverse.jsonl, seeds 322000-322059 both ways)
- verdict: level: K/D -0.0225 CI [-0.0733, +0.0281], win rate -0.033 CI [-0.225, +0.158], captures -7 CI [-19, +5], n=120
- pooled: 120 episodes, 0 skipped; RED won 38.3% of episodes
  - treatment: K/D 0.9888 (2646/2676), captures 19, wins 56
  - control: K/D 1.0113 (2686/2656), captures 26, wins 60
- rationale: Derived from lookahead3: LookaheadCells measured worse at 3, so the constant is worth testing in the other direction at 9.

## backguardttl90 — REJECT (local A/B)

- when: 2026-07-31T19:44:59+00:00
- change: `BackGuardTtl` -> `90`
- treatment: local build  control: `jordan-ctf-candidate:v90` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-backguardttl90.jsonl, seeds 323000-323059 both ways)
- verdict: wins separate NEGATIVE: K/D -0.0275 CI [-0.0583, +0.0015], win rate -0.092 CI [-0.183, -0.008], captures -5 CI [-14, +3], n=120
- pooled: 120 episodes, 0 skipped; RED won 53.3% of episodes
  - treatment: K/D 0.9863 (2599/2635), captures 24, wins 51
  - control: K/D 1.0139 (2632/2596), captures 29, wins 62
- rationale: assembleMask (act.nim) picks the nearest remembered enemy inside BackGuardRange 260 that passes couldTrade — called with `myDir = vec(0,0)`, so past FreshShotTicks it reduces to 'the remembered spot is inside maxEngage with a clear grid ray' — and clamps `f.desiredAim` to within BackGuardArc of it. Read the clamp honestly: BackGuardArc is 96 brads (135 degrees), well outside the 32-brad cone, so this is a rear LIMIT rather than a stare, and what it actually spends is up to 45 degrees of the heading — or of the Overwatch/HomeDefender scan sweep, which it overrides — on every frame a qualifying track sits behind us. Its only freshness gate is BackGuardTtl 200 ticks (~8.3s), while every other consumer of the same memory gates far tighter: FreshShotTicks 24, the duck's nearThreat 30, ExposureTrackTtl 60, PreAimTrackTtl 90, NadeMemTtl 150. The constant has one consumer, has never moved since the initial commit, and 90 puts the clamp on the same freshness the bot already demands merely to point the gun — the removal-of-stale-intel direction that produced corpse-track-cleanup (+0.096 K/D, the largest promotion on record). Expect more lane-facing and more sweep; the honest prior is discouraging, since trackhold200 separated negative on captures and both defender-freshness patches came back level — but all three of those moved the FEET, and this is the turret, the axis that paid twice on ScanArc (24 -> 28 -> 36).

## backguardttl90-reverse — REJECT (local A/B)

- when: 2026-07-31T19:46:00+00:00
- change: `BackGuardTtl` -> `310`
- treatment: local build  control: `jordan-ctf-candidate:v90` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-backguardttl90-reverse.jsonl, seeds 324000-324059 both ways, seeds 324200-324339 both ways)
- verdict: level: K/D -0.0016 CI [-0.0187, +0.0153], win rate +0.030 CI [-0.040, +0.100], captures +7 CI [-12, +26], n=400
- pooled: 400 episodes, 0 skipped; RED won 58.0% of episodes
  - treatment: K/D 0.9992 (8723/8730), captures 83, wins 186
  - control: K/D 1.0008 (8735/8728), captures 76, wins 174
- rationale: Derived from backguardttl90: BackGuardTtl measured worse at 90, so the constant is worth testing in the other direction at 310.

## steer-dither-quarter — PROMOTE (local A/B)

- when: 2026-07-31T19:47:12+00:00
- change: `baseline/act.nim`: `steer = steer + vec(
      rand(bot.rng, -0.12 .. 0.12), rand(bot.rng, -0.12 .. 0.12))` -> `steer = steer + vec(
      rand(bot.rng, -0.03 .. 0.03), rand(bot.rng, -0.03 .. 0.03))`
- treatment: local build  control: `jordan-ctf-candidate:v90` (the tree)
- shipped as: `jordan-ctf-candidate:v91`
- measured on: the local simulator, seed-paired mirrors (episodes/exp-steer-dither-quarter.jsonl, seeds 325000-325059 both ways, seeds 325200-325339 both ways)
- verdict: separates positive on the pooled sample: K/D +0.1018 CI [+0.0761, +0.1267], win rate +0.228 CI [+0.133, +0.320], captures +74 CI [+49, +98], n=400
- pooled: 400 episodes, 0 skipped; RED won 43.8% of episodes
  - treatment: K/D 1.0517 (9099/8652), captures 118, wins 230
  - control: K/D 0.9499 (8470/8917), captures 44, wins 139
- rationale: The last thing chooseMovement does before `f.moveMask = octantBits(steer)` is add an undocumented uniform +-0.12 jitter to each axis of a roughly unit-length steer vector — up to ~9.7 degrees of heading noise fed into a quantizer whose bins are 45 degrees wide, so it flips the chosen d-pad octant whenever the true heading lands within the perturbation of a bin boundary, on order one navigating frame in five. When it flips, the step goes into a neighbouring octant, and on a route the cost field bent around watched ground that is a step onto the ground it bent around: ExposedCost 14 -> 22 separated +0.0937 K/D [+0.0679, +0.1199] at n=400 with both 30 and 6 separating negative, which prices that mistake higher than anything else measured here recently. Quartering the amplitude keeps both `rand(bot.rng, ...)` calls, so the per-seat RNG stream is not re-phased and the tie-break that keeps the mask non-empty survives (0.03 is far above octantBits' 1e-6 floor); `f.desiredAim = bradsOf(steer)` rides the same vector, but the resulting <=7-brad wobble sits inside CruiseDeadband 8, so the turret barely notices and the only thing that really moves is how often the d-pad lands one octant off the steer. This fires every frame for every seat not in a combat branch — the highest event rate available in this area — and the dither has been in the tree since the initial commit, unmeasured. Risk: the plausible reason for it is dithering the 8-way quantizer so the mean heading over several frames approximates the true one, so damping it could let the bot commit up to 22.5 degrees off and grind along walls or wedge against a mate, with only the stuckTicks > 20 burst as a backstop; and being a patch, a null teaches nothing about a smaller or larger amplitude.

## pocketrush140 — REJECT (local A/B)

- when: 2026-07-31T19:48:12+00:00
- change: `PocketRushRange` -> `140`
- treatment: local build  control: `jordan-ctf-candidate:v91` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-pocketrush140.jsonl, seeds 326000-326059 both ways, seeds 326200-326339 both ways)
- verdict: level: K/D -0.0025 CI [-0.0187, +0.0135], win rate -0.035 CI [-0.102, +0.033], captures -5 CI [-25, +15], n=400
- pooled: 400 episodes, 0 skipped; RED won 45.8% of episodes
  - treatment: K/D 0.9987 (8714/8725), captures 93, wins 179
  - control: K/D 1.0013 (8720/8709), captures 98, wins 193
- rationale: engage.nim sets `f.pocketRush` for the attacker closest to the enemy pedestal across all five attacker roles once `dist(f.me, f.stealTarget) < PocketRushRange`, and pocketRush then means `f.maxEngage = 0.0` — a seat that will not shoot at anything — plus exclusion from act.nim's threat jink (108), cooldown duck (70) and serpentine (199) and from objective.nim's plasma, med- kit and grenade detours (215, 239, 248). At 210px that unarmed, un-jinking window is the last ~76 ticks of the approach at the engine's top speed (MaxSpeed 704 / MotionScale 256 = 2.75 px/tick) and considerably longer at the ~1px/tick OwnEstSpeed says a bot actually makes good, walking straight into the one place GV25 respawns enemies armed. The range itself has never been moved: the only experiment in this branch, pocket-rush- mate-ttl, changed the mate-freshness arbitration (level, K/D -0.0023) and left the window's DURATION alone, while recording that its fail-open arbitration can put up to five unarmed bodies in the pocket at once. analysis/role_bleed.md puts the four mid seats — the ones who spend their lives on this approach — at K/D 0.62-0.87 with all three lives spent in 93-99% of episodes. 140 keeps the commit-to-the-touch idea for the last ~50 ticks and gives the rest of the approach its gun, duck and jink back; the counter-hypothesis the mirror settles is the branch's own comment, which says duelling at the pocket edge is an infinite respawn grinder, so captures are the veto channel to read.

## pocketrush140-reverse — REJECT (local A/B)

- when: 2026-07-31T19:48:36+00:00
- change: `PocketRushRange` -> `280.0`
- treatment: local build  control: `jordan-ctf-candidate:v91` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-pocketrush140-reverse.jsonl, seeds 327000-327059 both ways)
- verdict: level: K/D -0.0250 CI [-0.0621, +0.0106], win rate -0.050 CI [-0.208, +0.108], captures -7 CI [-21, +7], n=120
- pooled: 120 episodes, 0 skipped; RED won 35.0% of episodes
  - treatment: K/D 0.9875 (2612/2645), captures 22, wins 53
  - control: K/D 1.0126 (2661/2628), captures 29, wins 59
- rationale: Derived from pocketrush140: PocketRushRange measured worse at 140, so the constant is worth testing in the other direction at 280.

## escortengage640 — REJECT (local A/B)

- when: 2026-07-31T19:49:37+00:00
- change: `EscortEngageRange` -> `640`
- treatment: local build  control: `jordan-ctf-candidate:v91` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-escortengage640.jsonl, seeds 328000-328059 both ways, seeds 328200-328339 both ways)
- verdict: level: K/D +0.0007 CI [-0.0099, +0.0111], win rate +0.007 CI [-0.030, +0.045], captures +1 CI [-11, +13], n=400
- pooled: 400 episodes, 0 skipped; RED won 50.2% of episodes
  - treatment: K/D 1.0003 (8637/8634), captures 95, wins 179
  - control: K/D 0.9997 (8635/8638), captures 94, wins 176
- rationale: engage.nim's maxEngage ladder reads `elif f.mateCarry: EscortEngageRange`, and `f.rushing` is itself defined as `not f.mateCarry and ...`, so this is not one role's cap: whenever mateCarry is true all eight seats — the Overwatch on its post and the HomeDefender at the choke included — have the gun cut from FireRange (1250px) to 320px. mateCarry is INFERRED, not observed: sense.nim's readFlagState sets it whenever the enemy flag is neither planted nor visible, so the cap also covers the whole tail of every failed steal, and stale-matecarry-fix (which moved the same branch's dead-reckoning) separating negative at n=120 is direct evidence that the state is common and consequential. Meanwhile posts.nim scores an overwatch hold by `openLineLen(client, q, vec(eSign, 0.0), FireRange, 6.0)` — the post is chosen for firing lines far longer than 320px, and during a steal the sniper is forbidden to take them. The constant has never been moved in either direction; 640 is still half the arena, so the anti-frag-chase intent the comment states survives. Read the risk first: act.nim's engage branch overrides movement toward the target (`f.moveMask = octantBits(f.aim - f.me)`), so a wider cap turns escorts and keepers into chasers, which would show up as lost captures rather than lost K/D.

## carrierest20 — REJECT (local A/B)

- when: 2026-07-31T19:50:01+00:00
- change: `CarrierEstSpeed` -> `2`
- treatment: local build  control: `jordan-ctf-candidate:v91` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-carrierest20.jsonl, seeds 329000-329059 both ways)
- verdict: level: K/D +0.0000 CI [-0.0062, +0.0062], win rate -0.008 CI [-0.025, +0.000], captures +0 CI [+0, +0], n=120
- pooled: 120 episodes, 0 skipped; RED won 53.3% of episodes
  - treatment: K/D 1.0000 (2600/2600), captures 29, wins 55
  - control: K/D 1.0000 (2600/2600), captures 29, wins 56
- rationale: sense.nim's readFlagState dead-reckons the fogged mate carrier with `est.x += homeSign(bot.team) * min(abs(f.ownHome.x - est.x), elapsed * CarrierEstSpeed)`, and that phantom point is what the four flank/mid escort offsets in objective.nim walk to, plus the med-kit right-of-way test. The engine caps a player at MaxSpeed 704 / MotionScale 256 = 2.75 px/tick and a carrier at CarrierSpeedPct 70 (1.93 px/tick), so at 1.0 the phantom is guaranteed to lag the real runner by up to ~0.9px per fogged tick — a few hundred px across one lost sighting, against 863px of pedestal separation — and the escort ring aims its 46px offsets off a point that is systematically behind the body it is covering. The one measured signpost on this branch points the same way: stale-matecarry-fix restamped this dead-reckoning so the phantom started at the enemy pedestal on every steal and separated NEGATIVE (wins -0.133, captures -13, K/D -0.0235), i.e. the tree does better with the escort wave heading home than pressing the pocket. 2.0 is the carrier's own top speed rounded up, so the estimate now errs homeward rather than behind; note it only bites while a fix is fresh, since a stale or never- stamped fix already saturates the min() clamp at our own pedestal. Expect the escort ring to disengage from the pocket sooner; captures are the channel that would show a carrier pinned mid-map being escorted by nobody.

## flankdepth360 — REJECT (local A/B)

- when: 2026-07-31T19:51:02+00:00
- change: `FlankDepth` -> `360`
- treatment: local build  control: `jordan-ctf-candidate:v91` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-flankdepth360.jsonl, seeds 330000-330059 both ways, seeds 330200-330339 both ways)
- verdict: level: K/D +0.0106 CI [-0.0127, +0.0336], win rate +0.025 CI [-0.060, +0.113], captures -12 CI [-36, +13], n=400
- pooled: 400 episodes, 0 skipped; RED won 41.2% of episodes
  - treatment: K/D 1.0053 (8714/8668), captures 86, wins 190
  - control: K/D 0.9947 (8656/8702), captures 98, wins 180
- rationale: FlankDepth appears twice, both in objective.nim: the sticky flip `if fwd >= FlankDepth - 50.0: bot.behindLines = true` and the wide-lane waypoint `vec(float(CenterX) - homeSign(bot.team) * FlankDepth, laneY)`. Because the turn-in test is `not bot.behindLines and dist(f.me, f.stealTarget) > 170.0`, it is behindLines that actually turns the flanker, at fwd 210 — x=827 against a pedestal column at x=1049 (world.nim's flagHome is CenterX ± 7/10 of the half width) — so the comment's 'run the extreme lanes deep past mid, then hit the pedestal pocket from behind' actually delivers a diagonal cut-in 222px in FRONT of the pocket. 360 moves the turn-in to fwd 310 (x=927, 122px in front) and the waypoint to x=977: a deeper lane run, not a reversed approach. The constant has never been swept in either direction, and these are the seats that convert — 0.064-0.113 caps/ep for the four flank seats against 0.004-0.035 for every mid seat, at 32-64% all-lives-spent against 93-99% — while analysis/role_bleed.md names 'LaneBottom plus FlankDepth' as its own untested suspect for FlankBottom, one of only two per-role gaps that survive its file bootstrap (note that gap is a side asymmetry, which a symmetric move cannot address). Amplitude dampener, stated honestly: act.nim's hold-line clamp caps the waypoint at HoldLineDepth 160 whenever holdNow (HoldLineKills 4), so the change bites only while we are strictly ahead on kills, while our own flag is out, or before killsInit — and it reaches two seats, which is the size latticehold6 separated at (+0.080 K/D).

## overwatch-peek-range — REJECT (local A/B)

- when: 2026-07-31T19:51:26+00:00
- change: `baseline/tuning.nim`: `PeekStandoffWeight* = 0.9    # px of extra walking each px of it is worth` -> `PeekStandoffWeight* = 0.9    # px of extra walking each px of it is worth
  PeekTriggerRange* = 420.0    # a keeper leaves its covered hold for the
                              # exposed peek cell only for a track this near
                              # the post. Was FireRange + 30 (1280px), which
                              # no two points on this arena can exceed`; `baseline/objective.nim`: `dist(t.pos, bot.postHold) < FireRange + 30.0:` -> `dist(t.pos, bot.postHold) < PeekTriggerRange:`
- treatment: local build  control: `jordan-ctf-candidate:v91` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-overwatch-peek-range.jsonl, seeds 331000-331059 both ways)
- verdict: level: K/D -0.0046 CI [-0.0408, +0.0313], win rate -0.058 CI [-0.200, +0.075], captures -6 CI [-18, +6], n=120
- pooled: 120 episodes, 0 skipped; RED won 44.2% of episodes
  - treatment: K/D 0.9977 (2617/2623), captures 25, wins 53
  - control: K/D 1.0023 (2620/2614), captures 31, wins 60
- rationale: objective.nim's Overwatch branch steps from the covered postHold onto the exposed postPeek whenever `f.shotReady` and any track fresher than 24 ticks satisfies `dist(t.pos, bot.postHold) < FireRange + 30.0`. That test cannot fail on this map: FireRange is MapW + 15 = 1250, posts.nim:126 only accepts candidates at fwd -160..-40, and the farthest standable point from a post that near the centre line is ~1020px away — so the live rule is 'somebody was seen anywhere in the last second, go stand in the open'. The frames where the gate actually moves the feet are the ones where no combat branch claimed the frame (actOn calls chooseMovement only `if not f.acted`), i.e. exactly the frames where the sniper could not shoot: blocked with no peek cell inside PeekSearchCells, or past a maxEngage the mateCarry escort cap has cut to 320. The record puts the value on this seat and the gap in this family: blue's Overwatch is the largest per-role deficit measured here (ΔK/D 0.515, all three lives spent in 95.5% of episodes against red's 81.6%), and the post family's last two experiments (oneway-peek-choice, exactly zero; post- vision-shield, captures -24) both moved the SCORING of the peek cell and never the trigger that sends the body to it. 420 restricts the step to the band where the enemy wave actually stands — their hold line sits ~160px inside our half, the post 40-160px inside ours — and if the branch turns out to fire mostly on close tracks the result reads level.

## rush-engage-340 — REJECT (local A/B)

- when: 2026-07-31T19:51:49+00:00
- change: `RushEngageRange` -> `340`
- treatment: local build  control: `jordan-ctf-candidate:v91` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-rush-engage-340.jsonl, seeds 332000-332059 both ways)
- verdict: level: K/D +0.0008 CI [-0.0403, +0.0403], win rate -0.008 CI [-0.175, +0.158], captures -5 CI [-19, +9], n=120
- pooled: 120 episodes, 0 skipped; RED won 35.8% of episodes
  - treatment: K/D 1.0004 (2632/2631), captures 23, wins 53
  - control: K/D 0.9996 (2626/2627), captures 28, wins 54
- rationale: engage.nim caps the mid quad's fire range at RushEngageRange whenever nobody is carrying (`f.rushing = ... bot.role in {MidTop, MidBottom, MidGuard}`, which roleForSeat spreads over seats 1-4, four of eight), and the target loop then drops every fresh track with `if d >= f.maxEngage: continue` — so those four seats refuse fire from 230px out while the gun reaches 1300px and every uncapped seat answers at any range. 340 is the radius the rest of the tree already treats as relevant to the same enemies (DuckRange 340, EscortEngageRange 320, ExposureRange 380), and the constant has never been moved in either direction: it is in no ledger entry, no done key and no SEED entry. analysis/role_bleed.md prices the seats it governs under the current pin: the mid quad runs K/D 0.622-0.868 and spends all three lives in 93-99% of episodes, against 1.14-2.09 for the flankers and the home defender, and because those seats are death-censored the kills channel is the only one that can move. Two couplings to read the result through: the engage branch walks AT its target (`f.moveMask = octantBits(f.aim - f.me)`), so a wider cap is also a wider chase for the seats running the steal race, and f.maxEngage is the `reach` argument to preAimBearing and couldTrade, so pre-aim and the back-guard clamp widen with it. Expect kills/ep on seats 1-4 to move if anything does; treat captures and win rate as vetoes, since a mid quad pulled off the steal shows there first.

## own-nade-no-flee — REJECT (local A/B)

- when: 2026-07-31T19:52:13+00:00
- change: `baseline/tuning.nim`: `NadeFullChargeTicks* = 24    # ~1s of holding C reaches max range` -> `NadeFullChargeTicks* = 24    # ~1s of holding C reaches max range
  NadeFlightTicks* = 10        # ticks our own orb is airborne after release
                              # (engine: GrenadeFlightMultiple * windup)`; `baseline/world.nim`: `nadeNeed*: int             # charge ticks required for the planned throw` -> `nadeNeed*: int             # charge ticks required for the planned throw
    nadeFlightUntil*: int      # tick our own thrown orb bursts`; `baseline/act.nim`: `bot.nadeCharge = 0           # release this tick = the throw` -> `bot.nadeCharge = 0           # release this tick = the throw
        bot.nadeFlightUntil = bot.tick + NadeFlightTicks`; `baseline/grenades.nim`: `if kind == lkThrowTarget and o.objectId == ownRingId:
          continue                       # our own charge preview` -> `if kind == lkThrowTarget and o.objectId == ownRingId:
          continue                       # our own charge preview
        if kind == lkGrenadeAir and bot.tick < bot.nadeFlightUntil:
          continue                       # our own orb, thrown from our body`
- treatment: local build  control: `jordan-ctf-candidate:v91` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-own-nade-no-flee.jsonl, seeds 333000-333059 both ways)
- verdict: level: K/D -0.0137 CI [-0.0536, +0.0281], win rate -0.050 CI [-0.217, +0.117], captures -1 CI [-14, +13], n=120
- pooled: 120 episodes, 0 skipped; RED won 48.3% of episodes
  - treatment: K/D 0.9932 (2631/2649), captures 27, wins 55
  - control: K/D 1.0069 (2639/2621), captures 28, wins 61
- rationale: scanNadeDanger flees anything within `NadeBlast + 18` (70px) and excludes only our own CHARGE PREVIEW ring, but the engine launches the orb from our own body (`sx = player.x + CollisionW div 2`) and interpolates it over a fixed `GrenadeFlightMultiple * fireWindupTicks` = 10 ticks, while global.nim streams that airborne orb to any viewer whose FOV covers it — which, inside the 90px vision bubble, is us for the first 3-9 ticks of every throw. So each lob is followed by several ticks of act.nim's `f.moveMask = octantBits(f.me - f.nadeDangerFrom)` sprinting back down our own throw line, overriding the engage approach, the hold and the duck. The tree already found and fixed exactly this artifact for the ring — read the comment above ownRingId, which then explicitly leaves airborne orbs counting — so this stamps the release tick in act.nim and skips airborne orbs for the fuse's length. It fires on 100% of throws by all eight seats, and grenades are where the two largest promotions on record sit (NadeFarmReach 340->420->500), so the throw rate is high; expect it in kills/ep on the grenade-farming seats rather than in deaths. Two costs the mirror is pricing: the flee is also what stops the engage branch walking us into our own blast during the fuse, and because this gate keys on TIME rather than identity it goes blind to an ENEMY orb for the same 10 ticks — the mutual-duel case the ring code deliberately solved by identity instead.

## engage-lead-clamp — REJECT (local A/B)

- when: 2026-07-31T19:52:37+00:00
- change: `baseline/engage.nim`: `let predicted = t.pos + t.vel * (float(bot.tick - t.lastSeen) + LeadTicks)` -> `let predicted = t.pos + t.vel *
      (min(float(bot.tick - t.lastSeen), LeadTicks) + LeadTicks)`
- treatment: local build  control: `jordan-ctf-candidate:v91` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-engage-lead-clamp.jsonl, seeds 334000-334059 both ways)
- verdict: level: K/D -0.0153 CI [-0.0634, +0.0336], win rate -0.025 CI [-0.192, +0.142], captures -7 CI [-21, +7], n=120
- pooled: 120 episodes, 0 skipped; RED won 34.2% of episodes
  - treatment: K/D 0.9923 (2592/2612), captures 25, wins 54
  - control: K/D 1.0077 (2625/2605), captures 32, wins 57
- rationale: engage.nim aims every target at `t.pos + t.vel * (age + LeadTicks)` for any track up to FreshShotTicks=24 old, and memory.nim clamps vel to +-3.0 px/axis, so a stale track is dead-reckoned up to 30 ticks — about 80px per axis into a ~14px bullet corridor — and act.nim's fire gate measures `perpMiss` against that predicted point rather than against the truth, so a bad extrapolation buys a confident shot into empty floor at 12 ticks of cooldown. The tree's own evasion says the extrapolation is mostly noise at that age: the serpentine flips on `bot.tick div 8` and the threat jink on `bot.tick div 12`, and the field is largely this lineage, so a 24-tick-old heading has reversed about three times. The population is known to be large and valuable — cutting FreshShotTicks 24->16, which removes only ages 17-24, cost -0.0921 K/D, the strongest single-knob result in the ledger — but whether those shots should be aimed at the extrapolation or nearer the remembered position has never been asked; LeadTicks itself is bracketed (8.0 -0.034, 4.0 +0.000) and stays untouched here. Expect it in accuracy (role_bleed reports 0.63-0.74 by seat). Risk: a target genuinely running a lane is led correctly today and will now be aimed behind, and `predicted` also feeds pixelRayClear and the plasma branch's aim, so a few targets shift between the engage and peek branches.

## repath5 — REJECT (local A/B)

- when: 2026-07-31T19:53:39+00:00
- change: `RepathTicks` -> `5`
- treatment: local build  control: `jordan-ctf-candidate:v91` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-repath5.jsonl, seeds 335000-335059 both ways, seeds 335200-335339 both ways)
- verdict: level: K/D +0.0058 CI [-0.0188, +0.0299], win rate -0.003 CI [-0.095, +0.090], captures +3 CI [-25, +31], n=400
- pooled: 400 episodes, 0 skipped; RED won 43.0% of episodes
  - treatment: K/D 1.0029 (8681/8656), captures 100, wins 184
  - control: K/D 0.9971 (8653/8678), captures 97, wins 185
- rationale: navSteer recomputes the cost field only on 'goal != navGoal or tick - navStamp >= RepathTicks' (navgrid.nim:298), and the exposure marks live inside that recompute — rebuildExposure runs from computeField and nowhere else. So for every seat whose goal is a FIXED point (a carrier's run home, a pedestal rush, a kit, a post) the 22-cost danger blob can sit ten ticks behind where the enemy actually is; tuning.nim prices closing motion at ~8px/tick, so up to 80px of misplaced toll that both fails to protect and detours us for nothing. Halving it costs nothing on quiet frames: computeField early-returns on 'not rebuildExposure(...) and fieldValid and goal == fieldGoal' and rebuildExposure returns false on 'spots == expSpots', so the extra pass is bought only when the spot list actually moved. Never swept in either direction, and the record's largest promotion — corpse-track-cleanup, +0.096 — was paid for deleting exactly this class of stale danger mark. The cost is real and the local instrument cannot see all of it: this doubles a ~12.8k-cell Dijkstra on threat-active frames for a policy already at ~half of sim wall clock (backlog 12), and hosted, a slower policy meets a server that stops waiting; behaviourally it also doubles the chances to flip sides of an obstacle at a near-tie.

## covershield64 — REJECT (local A/B)

- when: 2026-07-31T19:54:03+00:00
- change: `CoverShieldDist` -> `64`
- treatment: local build  control: `jordan-ctf-candidate:v91` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-covershield64.jsonl, seeds 336000-336059 both ways)
- verdict: level: K/D +0.0000 CI [+0.0000, +0.0000], win rate +0.000 CI [+0.000, +0.000], captures +0 CI [+0, +0], n=120
- pooled: 120 episodes, 0 skipped; RED won 43.3% of episodes
  - treatment: K/D 1.0000 (2568/2568), captures 32, wins 54
  - control: K/D 1.0000 (2568/2568), captures 32, wins 54
- rationale: posts.nim:128 is the only consumer: a candidate hold is dropped unless rayClearCoarse finds a wall within CoverShieldDist directly in front, so this constant — not the score — defines the whole candidate pool (52 red / 50 blue cells at 42, per the onewaybonus40 scan). The score that then runs never prices frontal cover at all ('abs(p.y - wantY) + abs(fwd + 90.0) * 0.7 - peekLine * 0.7'), so lane length decides among whatever the gate admits, and the one-way work recorded the top candidates sitting within ~8.4px of each other — dense enough that a dozen newly admitted cells can move the argmin. This picks for the biggest localized deficit on record: analysis/role_bleed.md puts blue's Overwatch 0.515 K/D behind red's, dying out in 95.5% of episodes against 81.6%, and names post selection as the suspect; and because findEnemyPosts runs the same scan mirrored into the static exposure, a moved post shifts all eight seats' cost field. The distance has never been swept — post-vision-shield changed which MASK this test reads, and its captures separating negative (-24) says the gate is load-bearing. Loosening it trades frontal cover for lane length, which is what the map-wide gun makes a post worth; the axis is informative either way, and the failure mode to watch for is exact inertness if the argmin does not move, as in onewaybonus40-further and oneway-peek- choice.

## peekstandoff12 — REJECT (local A/B)

- when: 2026-07-31T19:55:34+00:00
- change: `PeekStandoffWeight` -> `1.2`
- treatment: local build  control: `jordan-ctf-candidate:v91` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-peekstandoff12.jsonl, seeds 337000-337059 both ways, seeds 337200-337339 both ways, seeds 337400-337499 both ways)
- verdict: level: K/D +0.0187 CI [-0.0014, +0.0389], win rate +0.057 CI [-0.018, +0.128], captures +11 CI [-21, +43], n=600
- pooled: 600 episodes, 0 skipped; RED won 48.8% of episodes
  - treatment: K/D 1.0094 (13115/12993), captures 154, wins 296
  - control: K/D 0.9907 (12969/13091), captures 143, wins 262
- rationale: findPeekCell scores candidates 'dist(p, me) - min(dist(p, corner), PeekStandoffCap) * PeekStandoffWeight' and takes the minimum (navgrid.nim:430-431). On the away-ray from a corner D px off, dist(p, corner) = D + t, so the score is (1-W)t - WD: at any weight below 1.0 it RISES with depth, so the term can never buy a cell further back behind the same corner — it only breaks ties between candidates at different angles. 1.0 is the exact threshold at which depth starts being purchased; at 1.2 the score falls with depth until the 96px cap binds, which is what the proc's own header says the stand-off is for (a narrow wedge instead of the whole body swung into the room). Neither standoff constant has ever been swept: duck-standoff mirrored this term onto findDuckCell at 0.5 and read level-negative (-0.024), so the mirror was tested and the original never was, and the two peek-friendly-corridor rejects only quoted this line as an anchor. Expect the same shot taken from further back with less of us inside the room it opens; against it, the peek walks further before the line clears, so the pre-laid aim pays off later and the cooldown window may close first — and note the term is inert whenever the blocking corner is more than ~144px away, since the cap then binds for every candidate in the box.

## ducksearch5 — REJECT (local A/B)

- when: 2026-07-31T19:55:58+00:00
- change: `DuckSearchCells` -> `5`
- treatment: local build  control: `jordan-ctf-candidate:v91` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-ducksearch5.jsonl, seeds 338000-338059 both ways)
- verdict: level: K/D -0.0153 CI [-0.0552, +0.0243], win rate -0.042 CI [-0.192, +0.108], captures +1 CI [-13, +15], n=120
- pooled: 120 episodes, 0 skipped; RED won 49.2% of episodes
  - treatment: K/D 0.9924 (2605/2625), captures 30, wins 52
  - control: K/D 1.0077 (2631/2611), captures 29, wins 57
- rationale: findDuckCell searches a (2*DuckSearchCells+1)^2 box for the NEAREST cell the threat's pixel ray cannot reach and returns -1 when there is none. Because it is nearest-first, widening the box cannot change an answer that already exists: the only frames that move are those where 24px of reach found nothing — and those frames are not a worse duck, they are no duck, since act.nim:75-82 leaves f.acted false, the cooldown branch is abandoned, and the frame falls through to chooseMovement, which walks the seat at its objective with the gun down on exactly the open ground that has no cover within 24px. The constant has never been swept; the two measured duck constants are different variables (duckrange260 -0.017 at n=400, duck-standoff -0.024), but note DuckRange moved this branch's firing RATE in both directions and read level each time, which caps how big this can be. Expect more cooldown frames spent behind something that breaks the line; against it, 40px is a ~5-tick walk that can eat the cooldown, and the wider box costs roughly double the rays in findDuckCell because the outer ring is scanned first and sets the early minima.

## ducksearch5-reverse — PROMOTE (local A/B)

- when: 2026-07-31T19:57:07+00:00
- change: `DuckSearchCells` -> `1`
- treatment: local build  control: `jordan-ctf-candidate:v91` (the tree)
- shipped as: `jordan-ctf-candidate:v92`
- measured on: the local simulator, seed-paired mirrors (episodes/exp-ducksearch5-reverse.jsonl, seeds 339000-339059 both ways, seeds 339200-339339 both ways)
- verdict: separates positive on the pooled sample: K/D +0.0395 CI [+0.0150, +0.0635], win rate +0.095 CI [-0.003, +0.190], captures +1 CI [-25, +27], n=400
- pooled: 400 episodes, 0 skipped; RED won 39.8% of episodes
  - treatment: K/D 1.0200 (8839/8666), captures 88, wins 203
  - control: K/D 0.9804 (8668/8841), captures 87, wins 165
- rationale: Derived from ducksearch5: DuckSearchCells measured worse at 5, so the constant is worth testing in the other direction at 1.

## sonar-hot-radius-54 — REJECT (local A/B)

- when: 2026-07-31T19:58:09+00:00
- change: `SonarHotRadius` -> `54`
- treatment: local build  control: `jordan-ctf-candidate:v92` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-sonar-hot-radius-54.jsonl, seeds 340000-340059 both ways, seeds 340200-340339 both ways)
- verdict: level: K/D -0.0011 CI [-0.0244, +0.0225], win rate +0.007 CI [-0.083, +0.098], captures -19 CI [-44, +6], n=400
- pooled: 400 episodes, 0 skipped; RED won 35.8% of episodes
  - treatment: K/D 0.9994 (8729/8734), captures 86, wins 193
  - control: K/D 1.0006 (8749/8744), captures 105, wins 190
- rationale: rebuildExposure (navgrid.nim) turns every HOT sonar ping — a landing that coincided with a friendly death on the scoreboard — into a no-LOS disc of radius SonarHotRadius, and every walkable cell inside it pays ExposedCost in the single cost field all eight seats route on; the tighter SonarExactRadius (34) applies only to rings solved to one landing, which needs the clock lock first and then succeeds on a minority of rings, so 90 is the radius most hot marks actually use. The disc's job is to cover where the fuzz could have put the landing, and perception.nim bounds that at ±SonarJitterPx = 20 px per axis (28 px diagonally), so the geometry justifies about 34+28 = 62 px and the tree's 90 is half again as wide: ~400 nav cells at ExposedCost 22 against a StepCost of 5, which is enough to send a route the long way round. This cost channel is the most instrument-visible one on record — ExposedCost separated at every point measured (6: -0.069, 14: -0.143, 30: -0.124, 22: +0.094 K/D at n=400) — while SonarHotRadius itself has never been asked, and deleting the OTHER phantom the same death event manufactures is the largest promotion here (corpse-track- cleanup, +0.096 K/D). 54 steps to the far side of the 62 px bound, so a result either way brackets the honest value. Expect fewer detours around ground whose only sin is that somebody died near it; the risk is that the killer often still holds that sightline, and this cost channel has punished both directions before.

## sonar-hot-radius-54-reverse — REJECT (local A/B)

- when: 2026-07-31T19:59:10+00:00
- change: `SonarHotRadius` -> `126.0`
- treatment: local build  control: `jordan-ctf-candidate:v92` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-sonar-hot-radius-54-reverse.jsonl, seeds 341000-341059 both ways, seeds 341200-341339 both ways)
- verdict: level: K/D +0.0114 CI [-0.0119, +0.0346], win rate +0.020 CI [-0.072, +0.110], captures +7 CI [-17, +31], n=400
- pooled: 400 episodes, 0 skipped; RED won 38.2% of episodes
  - treatment: K/D 1.0057 (8767/8717), captures 94, wins 191
  - control: K/D 0.9943 (8728/8778), captures 87, wins 183
- rationale: Derived from sonar-hot-radius-54: SonarHotRadius measured worse at 54, so the constant is worth testing in the other direction at 126.

## pickup-absence-restamp — REJECT (local A/B)

- when: 2026-07-31T19:59:34+00:00
- change: `baseline/memory.nim`: `if dist(positions[i], me) <= MedKitSeenClear and absentAt[i] < 0:` -> `if dist(positions[i], me) <= MedKitSeenClear:`; `baseline/sense.nim`: `if dist(bot.kitPos[i], f.me) <= MedKitSeenClear and bot.kitAbsentAt[i] < 0:` -> `if dist(bot.kitPos[i], f.me) <= MedKitSeenClear:`
- treatment: local build  control: `jordan-ctf-candidate:v92` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-pickup-absence-restamp.jsonl, seeds 342000-342059 both ways)
- verdict: wins separate NEGATIVE: K/D -0.0741 CI [-0.1168, -0.0298], win rate -0.283 CI [-0.442, -0.117], captures -15 CI [-29, -1], n=120
- pooled: 120 episodes, 0 skipped; RED won 30.8% of episodes
  - treatment: K/D 0.9636 (2569/2666), captures 19, wins 39
  - control: K/D 1.0377 (2671/2574), captures 34, wins 73
- rationale: The absence stamp in memory.nim's trackPickups, and its copy for med kits in sense.nim, is guarded by `and absentAt[i] < 0`, so a spot can be marked taken only ONCE: afterwards the entry returns to -1 only by SIGHTING the item, while pickupAvailable/nadeAvailable/kitAvailable flip back to 'stocked' the moment the respawn timer elapses. Once a spot's first stamp ages out the bot therefore believes it stocked forever — it can stand on the empty ground and never correct itself, and since bestKitDetour scores a spot it is already standing on at ~zero extra path, a wounded seat can re-select the same empty kit frame after frame. Deleting the guard makes the rule 'while we are close enough to prove it empty, it stays empty', which is what the proc's own docstring already claims it does, and a genuine restock is still learned instantly by the sighting branch just above. Nothing in the pickup-memory path has ever been measured, and removing phantom belief is the direction of the largest promotion on record (corpse-track- cleanup, +0.096 K/D). Expect fewer errands to spots that have been empty the whole time; the risk is the mirror image — a spot that restocks while we are inside MedKitSeenClear but shadowcast-blocked now has its suppression clock reset every frame we stand there. It overlaps pickup-seen-clear-85 (both widen absence learning), so the two must be measured as separate arms, never together.

## pickup-seen-clear-85 — PROMOTE (local A/B)

- when: 2026-07-31T20:00:42+00:00
- change: `MedKitSeenClear` -> `85`
- treatment: local build  control: `jordan-ctf-candidate:v92` (the tree)
- shipped as: `jordan-ctf-candidate:v93`
- measured on: the local simulator, seed-paired mirrors (episodes/exp-pickup-seen-clear-85.jsonl, seeds 343000-343059 both ways, seeds 343200-343339 both ways)
- verdict: separates positive on the pooled sample: K/D +0.0354 CI [+0.0094, +0.0619], win rate +0.072 CI [-0.028, +0.172], captures +40 CI [+12, +69], n=400
- pooled: 400 episodes, 0 skipped; RED won 39.0% of episodes
  - treatment: K/D 1.0176 (8916/8762), captures 115, wins 204
  - control: K/D 0.9822 (8494/8648), captures 75, wins 175
- rationale: MedKitSeenClear is the radius inside which failing to see a pickup counts as proof it was taken; it gates memory.nim's shared trackPickups (spray cans, shields, the four corner grenades) and the med-kit copy in sense.nim, so it is consulted every frame by every seat across five pickup families. The engine number it stands in for is readable: both sim/league_config.json and .engine/config.json set visionBubble 90, and sim.nim's applyFovConeLit keeps any shadowcast-lit cell inside that bubble whatever the aim is doing, so a stocked pickup within ~90 px on open ground is always drawn to us and 55 under-claims the engine by 35 px. Widening to 85 multiplies the area of one teaching pass by 2.4x (85²/55²), so far more passes learn absence at all instead of leaving a spot on the 'available' list the detour budgets keep paying for — NadeFarmReach 500 and MedKitDetour 120 are the axes that made those trips long, and NadeFarmReach paid twice (+0.064, +0.068 K/D). Neither this constant nor anything else in the pickup- memory path has ever been measured. Expect fewer errands that end on empty ground; the honest risks are that between 55 and 90 px a wall can legitimately hide a STOCKED pickup — a false 'taken' suppresses it for NadeRespawn+24 (144 ticks) or PickupRespawn+48 (768 ticks) — and that the engine's bubble test runs on 8 px fog cells, so 85 leaves only ~5 px of quantisation margin.

## pickup-seen-clear-85-further — PROMOTE (local A/B)

- when: 2026-07-31T20:01:51+00:00
- change: `MedKitSeenClear` -> `115.0`
- treatment: local build  control: `jordan-ctf-candidate:v93` (the tree)
- shipped as: `jordan-ctf-candidate:v94`
- measured on: the local simulator, seed-paired mirrors (episodes/exp-pickup-seen-clear-85-further.jsonl, seeds 344000-344059 both ways, seeds 344200-344339 both ways)
- verdict: separates positive on the pooled sample: K/D +0.0300 CI [+0.0055, +0.0543], win rate +0.028 CI [-0.060, +0.115], captures +31 CI [+5, +57], n=400
- pooled: 400 episodes, 0 skipped; RED won 44.8% of episodes
  - treatment: K/D 1.0149 (8845/8715), captures 108, wins 193
  - control: K/D 0.9849 (8504/8634), captures 77, wins 182
- rationale: Derived from pickup-seen-clear-85: MedKitSeenClear paid at 85, so walk the same way again to 115 and find where it stops paying.

## pickup-seen-clear-85-further-further — PROMOTE (local A/B)

- when: 2026-07-31T20:03:06+00:00
- change: `MedKitSeenClear` -> `145.0`
- treatment: local build  control: `jordan-ctf-candidate:v94` (the tree)
- shipped as: `jordan-ctf-candidate:v95`
- measured on: the local simulator, seed-paired mirrors (episodes/exp-pickup-seen-clear-85-further-further.jsonl, seeds 345000-345059 both ways, seeds 345200-345339 both ways)
- verdict: separates positive on the pooled sample: K/D +0.0345 CI [+0.0078, +0.0608], win rate +0.072 CI [-0.025, +0.170], captures +36 CI [+11, +61], n=400
- pooled: 400 episodes, 0 skipped; RED won 43.2% of episodes
  - treatment: K/D 1.0173 (8823/8673), captures 106, wins 203
  - control: K/D 0.9828 (8584/8734), captures 70, wins 174
- rationale: Derived from pickup-seen-clear-85-further: MedKitSeenClear paid at 115.0, so walk the same way again to 145 and find where it stops paying.

## pickup-seen-clear-85-further-further-further — REJECT (local A/B)

- when: 2026-07-31T20:03:30+00:00
- change: `MedKitSeenClear` -> `175.0`
- treatment: local build  control: `jordan-ctf-candidate:v95` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-pickup-seen-clear-85-further-further-further.jsonl, seeds 346000-346059 both ways)
- verdict: level: K/D -0.0384 CI [-0.0837, +0.0060], win rate -0.075 CI [-0.233, +0.083], captures -4 CI [-16, +8], n=120
- pooled: 120 episodes, 0 skipped; RED won 31.7% of episodes
  - treatment: K/D 0.9810 (2632/2683), captures 20, wins 49
  - control: K/D 1.0194 (2676/2625), captures 24, wins 58
- rationale: Derived from pickup-seen-clear-85-further-further: MedKitSeenClear paid at 145.0, so walk the same way again to 175 and find where it stops paying.

## shoutevery48 — PROMOTE (local A/B)

- when: 2026-07-31T20:04:40+00:00
- change: `ShoutEveryTicks` -> `48`
- treatment: local build  control: `jordan-ctf-candidate:v95` (the tree)
- shipped as: `jordan-ctf-candidate:v96`
- measured on: the local simulator, seed-paired mirrors (episodes/exp-shoutevery48.jsonl, seeds 347000-347059 both ways, seeds 347200-347339 both ways)
- verdict: separates positive on the pooled sample: K/D +0.1454 CI [+0.1207, +0.1708], win rate +0.388 CI [+0.300, +0.475], captures +44 CI [+20, +68], n=400
- pooled: 400 episodes, 0 skipped; RED won 41.5% of episodes
  - treatment: K/D 1.0756 (8994/8362), captures 100, wins 263
  - control: K/D 0.9301 (8415/9047), captures 56, wins 108
- rationale: Every shout we make is also a fix on US for any enemy within 247px, through walls — and since `shout-eavesdrop` promoted, the enemy in every local mirror READS those bubbles, so the channel is now genuinely two-way and its airtime has a price for the first time. 24 ticks is the fastest the server will accept, which is why it was chosen; it was never chosen as a rate. Halving it to one call every two seconds trades a mate's freshness against how loudly we advertise ourselves.

## shoutevery48-further — REJECT (local A/B)

- when: 2026-07-31T20:05:04+00:00
- change: `ShoutEveryTicks` -> `72`
- treatment: local build  control: `jordan-ctf-candidate:v96` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-shoutevery48-further.jsonl, seeds 348000-348059 both ways)
- verdict: level: K/D +0.0227 CI [-0.0219, +0.0664], win rate -0.050 CI [-0.200, +0.100], captures +10 CI [-2, +22], n=120
- pooled: 120 episodes, 0 skipped; RED won 56.7% of episodes
  - treatment: K/D 1.0113 (2685/2655), captures 29, wins 52
  - control: K/D 0.9886 (2598/2628), captures 19, wins 58
- rationale: Derived from shoutevery48: ShoutEveryTicks paid at 48, so walk the same way again to 72 and find where it stops paying.

## shoutsee400 — PROMOTE (local A/B)

- when: 2026-07-31T20:06:11+00:00
- change: `ShoutSeeDist` -> `400.0`
- treatment: local build  control: `jordan-ctf-candidate:v96` (the tree)
- shipped as: `jordan-ctf-candidate:v97`
- measured on: the local simulator, seed-paired mirrors (episodes/exp-shoutsee400.jsonl, seeds 349000-349059 both ways, seeds 349200-349339 both ways)
- verdict: separates positive on the pooled sample: K/D +0.1158 CI [+0.0926, +0.1386], win rate +0.282 CI [+0.195, +0.367], captures +55 CI [+31, +79], n=400
- pooled: 400 episodes, 0 skipped; RED won 55.2% of episodes
  - treatment: K/D 1.0590 (9101/8594), captures 113, wins 243
  - control: K/D 0.9432 (8425/8932), captures 58, wins 130
- rationale: Which sightings are worth ten characters. 900px is over half the arena and was set to mean 'anything we can see'; earshot is only 247px, so a mate who can act on the call is by construction close to US, and an enemy we see 900px away is usually not near them. 400 keeps the calls that name ground a listener can reach.

## preaimshoutttl48 — REJECT (local A/B)

- when: 2026-07-31T20:06:34+00:00
- change: `PreAimShoutTtl` -> `48`
- treatment: local build  control: `jordan-ctf-candidate:v97` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-preaimshoutttl48.jsonl, seeds 350000-350059 both ways)
- verdict: level: K/D +0.0000 CI [+0.0000, +0.0000], win rate +0.000 CI [+0.000, +0.000], captures +0 CI [+0, +0], n=120
- pooled: 120 episodes, 0 skipped; RED won 58.3% of episodes
  - treatment: K/D 1.0000 (2595/2595), captures 34, wins 58
  - control: K/D 1.0000 (2595/2595), captures 34, wins 58
- rationale: How long a heard fix keeps pointing the turret. 72 ticks is the engine's own bubble lifetime (ShoutTicks), which is how long we can still SEE the call — not how long the body it names stays put. Every other freshness gate in the tree is tighter (the fire gate 24, the duck 30, exposure 60), and the record's one standing finding about intel is that stale intel is worse than none: corpse-track-cleanup, which threw stale tracks away, is still one of the largest promotions here.

## matespacing20 — REJECT (local A/B)

- when: 2026-07-31T20:06:57+00:00
- change: `MateSpacing` -> `20.0`
- treatment: local build  control: `jordan-ctf-candidate:v97` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-matespacing20.jsonl, seeds 351000-351059 both ways)
- verdict: captures separate NEGATIVE: K/D -0.0317 CI [-0.0762, +0.0121], win rate -0.133 CI [-0.292, +0.017], captures -16 CI [-26, -6], n=120
- pooled: 120 episodes, 0 skipped; RED won 51.7% of episodes
  - treatment: K/D 0.9841 (2605/2647), captures 15, wins 49
  - control: K/D 1.0159 (2690/2648), captures 31, wins 65
- rationale: Formation tightness, and it is now a multiplier rather than a preference. Shouts are audible for 247px, so how many teammates a call reaches is set by how tightly the wave travels — the hosted replay analysis measured the tightest formation in the field reaching 4.84 teammates per call against 2.3-2.7 for the spread-out players. MateSpacing is the soft repulsion radius that decides our spread and has never been moved. Halving it should widen the channel's reach; the risk it prices against is that a tight wave shares a grenade blast.

## matespacing20-reverse — PROMOTE (local A/B)

- when: 2026-07-31T20:08:02+00:00
- change: `MateSpacing` -> `60.0`
- treatment: local build  control: `jordan-ctf-candidate:v97` (the tree)
- shipped as: `jordan-ctf-candidate:v98`
- measured on: the local simulator, seed-paired mirrors (episodes/exp-matespacing20-reverse.jsonl, seeds 352000-352059 both ways, seeds 352200-352339 both ways)
- verdict: separates positive on the pooled sample: K/D +0.0069 CI [-0.0198, +0.0331], win rate +0.160 CI [+0.070, +0.250], captures -5 CI [-30, +20], n=400
- pooled: 400 episodes, 0 skipped; RED won 56.8% of episodes
  - treatment: K/D 1.0036 (8479/8449), captures 87, wins 217
  - control: K/D 0.9966 (8843/8873), captures 92, wins 153
- rationale: Derived from matespacing20: MateSpacing measured worse at 20.0, so the constant is worth testing in the other direction at 60.

## matespacing20-reverse-further — PROMOTE (local A/B)

- when: 2026-07-31T20:09:05+00:00
- change: `MateSpacing` -> `80.0`
- treatment: local build  control: `jordan-ctf-candidate:v98` (the tree)
- shipped as: `jordan-ctf-candidate:v99`
- measured on: the local simulator, seed-paired mirrors (episodes/exp-matespacing20-reverse-further.jsonl, seeds 353000-353059 both ways, seeds 353200-353339 both ways)
- verdict: separates positive on the pooled sample: K/D +0.0907 CI [+0.0660, +0.1153], win rate +0.263 CI [+0.172, +0.352], captures +36 CI [+9, +62], n=400
- pooled: 400 episodes, 0 skipped; RED won 54.8% of episodes
  - treatment: K/D 1.0464 (8912/8517), captures 111, wins 240
  - control: K/D 0.9557 (8521/8916), captures 75, wins 135
- rationale: Derived from matespacing20-reverse: MateSpacing paid at 60.0, so walk the same way again to 80 and find where it stops paying.

## matespacing20-reverse-further-further — REJECT (local A/B)

- when: 2026-07-31T20:09:28+00:00
- change: `MateSpacing` -> `100.0`
- treatment: local build  control: `jordan-ctf-candidate:v99` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-matespacing20-reverse-further-further.jsonl, seeds 354000-354059 both ways)
- verdict: wins separate NEGATIVE: K/D -0.1000 CI [-0.1456, -0.0551], win rate -0.325 CI [-0.475, -0.167], captures -11 CI [-24, +1], n=120
- pooled: 120 episodes, 0 skipped; RED won 40.8% of episodes
  - treatment: K/D 0.9513 (2579/2711), captures 14, wins 33
  - control: K/D 1.0513 (2704/2572), captures 25, wins 72
- rationale: Derived from matespacing20-reverse-further: MateSpacing paid at 80.0, so walk the same way again to 100 and find where it stops paying.

## thieffocus600 — REJECT (local A/B)

- when: 2026-07-31T20:09:51+00:00
- change: `ThiefFocusBonus` -> `600.0`
- treatment: local build  control: `jordan-ctf-candidate:v99` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-thieffocus600.jsonl, seeds 355000-355059 both ways)
- verdict: level: K/D +0.0000 CI [+0.0000, +0.0000], win rate +0.000 CI [+0.000, +0.000], captures +0 CI [+0, +0], n=120
- pooled: 120 episodes, 0 skipped; RED won 23.3% of episodes
  - treatment: K/D 1.0000 (2657/2657), captures 28, wins 57
  - control: K/D 1.0000 (2657/2657), captures 28, wins 57
- rationale: research/BACKLOG.md item 6: both siblings in its line (HpFocusBonus, TraversePxPerBrad) have been measured and this one was dropped on the timidity prior, which does not apply to an aim constant. It discounts the track carrying our flag in the engage priority, and a dead carrier returns the flag instantly — the fastest flag return there is. The hosted replay analysis says our biggest single loss bucket is enemy captures (19 of 60), which is exactly what this term is for.

## corpseclear20 — REJECT (local A/B)

- when: 2026-07-31T20:10:14+00:00
- change: `CorpseClearRadius` -> `20.0`
- treatment: local build  control: `jordan-ctf-candidate:v99` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-corpseclear20.jsonl, seeds 356000-356059 both ways)
- verdict: wins separate NEGATIVE: K/D -0.0924 CI [-0.1364, -0.0496], win rate -0.267 CI [-0.442, -0.083], captures -18 CI [-32, -4], n=120
- pooled: 120 episodes, 0 skipped; RED won 31.7% of episodes
  - treatment: K/D 0.9545 (2559/2681), captures 15, wins 40
  - control: K/D 1.0469 (2725/2603), captures 33, wins 72
- rationale: research/BACKLOG.md item 5: 40 is shipped and 160 measured level, so the axis is bracketed above and open below. This is the mechanism behind corpse-track-cleanup, one of the largest promotions on record, and its optimum has already moved downward once. The loop declines to propose 0 itself because that switches the mechanism off rather than tuning it.

## corpseclear20-reverse — REJECT (local A/B)

- when: 2026-07-31T20:10:37+00:00
- change: `CorpseClearRadius` -> `60.0`
- treatment: local build  control: `jordan-ctf-candidate:v99` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-corpseclear20-reverse.jsonl, seeds 357000-357059 both ways)
- verdict: level: K/D -0.0177 CI [-0.0620, +0.0280], win rate +0.042 CI [-0.142, +0.225], captures +2 CI [-15, +19], n=120
- pooled: 120 episodes, 0 skipped; RED won 34.2% of episodes
  - treatment: K/D 0.9911 (2572/2595), captures 33, wins 60
  - control: K/D 1.0088 (2628/2605), captures 31, wins 55
- rationale: Derived from corpseclear20: CorpseClearRadius measured worse at 20.0, so the constant is worth testing in the other direction at 60.

## preaimshoutcost60 — REJECT (local A/B)

- when: 2026-07-31T20:20:19+00:00
- change: `PreAimShoutCost` -> `60.0`
- treatment: local build  control: `jordan-ctf-candidate:v99` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-preaimshoutcost60.jsonl, seeds 358000-358059 both ways)
- verdict: level: K/D -0.0100 CI [-0.0542, +0.0385], win rate -0.050 CI [-0.192, +0.100], captures +0 CI [-14, +14], n=120
- pooled: 120 episodes, 0 skipped; RED won 21.7% of episodes
  - treatment: K/D 0.9950 (2592/2605), captures 32, wins 53
  - control: K/D 1.0050 (2626/2613), captures 32, wins 59
- rationale: What a mate's fix is worth against our own evidence in the pre-aim scorer: 100px of effective distance, chosen between a sighting (0) and a heard landing (120) on the argument that a shout names a body but through another seat's eyes. That was a guess made before any of it was measured, and the measurement since says the channel is the most valuable thing in the tree. 60 prices a mate's eyes closer to our own.

## preaimshoutcost60-reverse — REJECT (local A/B)

- when: 2026-07-31T20:20:41+00:00
- change: `PreAimShoutCost` -> `140.0`
- treatment: local build  control: `jordan-ctf-candidate:v99` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-preaimshoutcost60-reverse.jsonl, seeds 359000-359059 both ways)
- verdict: level: K/D -0.0107 CI [-0.0325, +0.0109], win rate -0.017 CI [-0.100, +0.067], captures -1 CI [-8, +7], n=120
- pooled: 120 episodes, 0 skipped; RED won 19.2% of episodes
  - treatment: K/D 0.9947 (2603/2617), captures 29, wins 58
  - control: K/D 1.0054 (2617/2603), captures 30, wins 60
- rationale: Derived from preaimshoutcost60: PreAimShoutCost measured worse at 60.0, so the constant is worth testing in the other direction at 140.

## matespacing100 — REJECT (local A/B)

- when: 2026-07-31T20:21:03+00:00
- change: `MateSpacing` -> `100.0`
- treatment: local build  control: `jordan-ctf-candidate:v99` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-matespacing100.jsonl, seeds 360000-360059 both ways)
- verdict: wins separate NEGATIVE: K/D -0.1350 CI [-0.1816, -0.0896], win rate -0.442 CI [-0.592, -0.283], captures -17 CI [-31, -2], n=120
- pooled: 120 episodes, 0 skipped; RED won 47.5% of episodes
  - treatment: K/D 0.9347 (2546/2724), captures 18, wins 30
  - control: K/D 1.0697 (2732/2554), captures 35, wins 83
- rationale: The spacing axis has now paid twice walking the SAME way, and the way is not the one the hosted replay analysis pointed at: 40 -> 20 was rejected on captures, 40 -> 60 promoted, 60 -> 80 promoted at K/D +0.0907. Tighter formation is what the field's best players run and what widens a 247px shout channel's reach; wider is what this mirror keeps paying for. Push it one more step and find where it stops.

## duckrange240 — REJECT (local A/B)

- when: 2026-07-31T20:21:26+00:00
- change: `DuckRange` -> `240.0`
- treatment: local build  control: `jordan-ctf-candidate:v99` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-duckrange240.jsonl, seeds 361000-361059 both ways)
- verdict: level: K/D -0.0441 CI [-0.0888, +0.0000], win rate -0.092 CI [-0.242, +0.058], captures +3 CI [-11, +17], n=120
- pooled: 120 episodes, 0 skipped; RED won 24.2% of episodes
  - treatment: K/D 0.9785 (2635/2693), captures 32, wins 53
  - control: K/D 1.0226 (2624/2566), captures 29, wins 64
- rationale: How near a remembered enemy has to be before a cooldown becomes a duck rather than a step. 340px has never been moved, and the two neighbours in its line have both just paid in the SAME direction — ThreatRange 200 -> 280 promoted (react to fewer things by reacting later) and ducksearch5-reverse promoted. The duck spends the whole cooldown standing behind cover; at 240 the seat spends fewer of them hiding from something a third of the map away.

## duckrange240-reverse — PROMOTE (local A/B)

- when: 2026-07-31T20:22:30+00:00
- change: `DuckRange` -> `440.0`
- treatment: local build  control: `jordan-ctf-candidate:v99` (the tree)
- shipped as: `jordan-ctf-candidate:v100`
- measured on: the local simulator, seed-paired mirrors (episodes/exp-duckrange240-reverse.jsonl, seeds 362000-362059 both ways, seeds 362200-362339 both ways)
- verdict: separates positive on the pooled sample: K/D +0.0415 CI [+0.0179, +0.0657], win rate +0.158 CI [+0.070, +0.245], captures +37 CI [+12, +63], n=400
- pooled: 400 episodes, 0 skipped; RED won 28.2% of episodes
  - treatment: K/D 1.0209 (8827/8646), captures 115, wins 224
  - control: K/D 0.9795 (8630/8811), captures 78, wins 161
- rationale: Derived from duckrange240: DuckRange measured worse at 240.0, so the constant is worth testing in the other direction at 440.

## duckrange240-reverse-further — REJECT (local A/B)

- when: 2026-07-31T20:22:53+00:00
- change: `DuckRange` -> `540.0`
- treatment: local build  control: `jordan-ctf-candidate:v100` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-duckrange240-reverse-further.jsonl, seeds 363000-363059 both ways)
- verdict: level: K/D +0.0069 CI [-0.0319, +0.0463], win rate +0.042 CI [-0.100, +0.183], captures +10 CI [-3, +22], n=120
- pooled: 120 episodes, 0 skipped; RED won 21.7% of episodes
  - treatment: K/D 1.0034 (2619/2610), captures 32, wins 60
  - control: K/D 0.9966 (2619/2628), captures 22, wins 55
- rationale: Derived from duckrange240-reverse: DuckRange paid at 440.0, so walk the same way again to 540 and find where it stops paying.

## corridorhalf12 — PROMOTE (local A/B)

- when: 2026-07-31T20:23:59+00:00
- change: `CorridorHalfWidth` -> `12.0`
- treatment: local build  control: `jordan-ctf-candidate:v100` (the tree)
- shipped as: `jordan-ctf-candidate:v101`
- measured on: the local simulator, seed-paired mirrors (episodes/exp-corridorhalf12.jsonl, seeds 364000-364059 both ways, seeds 364200-364339 both ways)
- verdict: separates positive on the pooled sample: K/D +0.0334 CI [+0.0096, +0.0573], win rate +0.003 CI [-0.077, +0.083], captures +24 CI [+0, +48], n=400
- pooled: 400 episodes, 0 skipped; RED won 23.2% of episodes
  - treatment: K/D 1.0166 (8929/8783), captures 97, wins 187
  - control: K/D 0.9832 (8540/8686), captures 73, wins 186
- rationale: The friendly-fire guard's half width: a shot is declined when a remembered teammate sits within this of the fire axis. The server kills the NEAREST player in a ~14px corridor, so 15.0 is a full corridor of margin and every px of it is shots not taken. The hosted replay analysis says accuracy is our best statistic and focus fire our worst — two seats declining to shoot the same body is one way that happens. Never swept.

## corridorhalf12-further — REJECT (local A/B)

- when: 2026-07-31T20:24:21+00:00
- change: `CorridorHalfWidth` -> `9.0`
- treatment: local build  control: `jordan-ctf-candidate:v101` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-corridorhalf12-further.jsonl, seeds 365000-365059 both ways)
- verdict: level: K/D -0.0167 CI [-0.0603, +0.0266], win rate -0.058 CI [-0.217, +0.092], captures +2 CI [-10, +14], n=120
- pooled: 120 episodes, 0 skipped; RED won 30.8% of episodes
  - treatment: K/D 0.9917 (2619/2641), captures 23, wins 52
  - control: K/D 1.0084 (2650/2628), captures 21, wins 59
- rationale: Derived from corridorhalf12: CorridorHalfWidth paid at 12.0, so walk the same way again to 9 and find where it stops paying.

## corridorhalf12-further-reverse — REJECT (local A/B)

- when: 2026-07-31T20:24:44+00:00
- change: `CorridorHalfWidth` -> `15.0`
- treatment: local build  control: `jordan-ctf-candidate:v101` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-corridorhalf12-further-reverse.jsonl, seeds 366000-366059 both ways)
- verdict: wins separate NEGATIVE: K/D -0.0702 CI [-0.1123, -0.0274], win rate -0.175 CI [-0.317, -0.025], captures -20 CI [-33, -7], n=120
- pooled: 120 episodes, 0 skipped; RED won 19.2% of episodes
  - treatment: K/D 0.9650 (2540/2632), captures 13, wins 45
  - control: K/D 1.0352 (2704/2612), captures 33, wins 66
- rationale: Derived from corridorhalf12-further: CorridorHalfWidth measured worse at 9.0, so the constant is worth testing in the other direction at 15.

## backguardrange180 — REJECT (local A/B)

- when: 2026-07-31T20:25:41+00:00
- change: `BackGuardRange` -> `180.0`
- treatment: local build  control: `jordan-ctf-candidate:v101` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-backguardrange180.jsonl, seeds 367000-367059 both ways, seeds 367200-367339 both ways)
- verdict: level: K/D +0.0014 CI [-0.0050, +0.0082], win rate +0.010 CI [-0.013, +0.033], captures +0 CI [-9, +8], n=400
- pooled: 400 episodes, 0 skipped; RED won 22.2% of episodes
  - treatment: K/D 1.0007 (8707/8701), captures 77, wins 191
  - control: K/D 0.9993 (8701/8707), captures 77, wins 187
- rationale: The rear-limit clamp's reach. Both its siblings have been measured this session — BackGuardArc level at 128 and 64, BackGuardTtl level at 90 — and the range is the one term of the three nobody has moved. It decides how far away a remembered enemy still costs us up to 45 degrees of heading; at 180 only a genuinely near threat does.

## shoutmerge20 — PROMOTE (local A/B)

- when: 2026-07-31T20:26:46+00:00
- change: `ShoutMergeDist` -> `20.0`
- treatment: local build  control: `jordan-ctf-candidate:v101` (the tree)
- shipped as: `jordan-ctf-candidate:v102`
- measured on: the local simulator, seed-paired mirrors (episodes/exp-shoutmerge20.jsonl, seeds 368000-368059 both ways, seeds 368200-368339 both ways)
- verdict: separates positive on the pooled sample: K/D +0.1034 CI [+0.0766, +0.1303], win rate +0.305 CI [+0.210, +0.395], captures +59 CI [+34, +84], n=400
- pooled: 400 episodes, 0 skipped; RED won 42.5% of episodes
  - treatment: K/D 1.0531 (8918/8468), captures 120, wins 250
  - control: K/D 0.9498 (8511/8961), captures 61, wins 128
- rationale: Two heard fixes within 40px of each other are merged into one, on the argument that they name the same body. Since shout-eavesdrop landed the list also carries HOSTILE bubble anchors, which are jittered by up to 20px each — so two calls about two different enemies standing 30px apart now collapse to one, and the peek branch only ever gets told about one of them. 20 is the jitter itself, which is the smallest radius that can still merge a genuine double-report.

## ghost-flag-thief — REJECT (local A/B)

- when: 2026-07-31T20:27:23+00:00
- change: `GhostFlagMode` -> `1`
- treatment: local build  control: `jordan-ctf-candidate:v102` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-ghost-flag-thief.jsonl, seeds 368000-368059 both ways)
- verdict: level: K/D +0.0000 CI [+0.0000, +0.0000], win rate +0.000 CI [+0.000, +0.000], captures +0 CI [+0, +0], n=120
- pooled: 120 episodes, 0 skipped; RED won 56.7% of episodes
  - treatment: K/D 1.0000 (2628/2628), captures 31, wins 59
  - control: K/D 1.0000 (2628/2628), captures 31, wins 59
- rationale: A dead viewer's frame carries BOTH flag banners with the carrier-visibility test bypassed (engine: global.nim addFlags, `if viewerIsGhost or flagVisibleTo(...)`), so a corpse can see exactly which enemy is running our heart. The dead branch has banked tracks off that frame since forever and never read the flags. That this matters is not a guess: `thieffocus600` measured EXACTLY zero — bit-identical episodes — and that term only applies while we hold a live fix on the thief, so the living path never has one. Instrumented, this branch fires 11867 times in four episodes. The consumers are already landed and are the most aggressive in the tree: every role converges on the thief, a live fix lifts every engage cap to FireRange, and ThiefFocusBonus discounts the carrier by 400px of priority.

## ghost-flag-mate — REJECT (local A/B)

- when: 2026-07-31T20:27:46+00:00
- change: `GhostFlagMode` -> `2`
- treatment: local build  control: `jordan-ctf-candidate:v102` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-ghost-flag-mate.jsonl, seeds 369000-369059 both ways)
- verdict: level: K/D -0.0008 CI [-0.0125, +0.0101], win rate +0.000 CI [-0.050, +0.050], captures -1 CI [-3, +0], n=120
- pooled: 120 episodes, 0 skipped; RED won 66.7% of episodes
  - treatment: K/D 0.9996 (2599/2600), captures 28, wins 58
  - control: K/D 1.0004 (2599/2598), captures 29, wins 58
- rationale: The same ghost frame's OTHER banner: a teammate running the enemy heart, which the living path only ever dead-reckons once the carrier fogs out. Second rung rather than first because the record argues against it: `stale-matecarry-fix`, which made that same estimate truthful on the LIVING path, separated NEGATIVE (K/D -0.0235, win rate -0.133). Worth asking anyway — a ghost fix is a sighting where that one was an inference — but ask it second.

## preaimrange480 — REJECT (local A/B)

- when: 2026-07-31T20:30:45+00:00
- change: `PreAimRange` -> `480.0`
- treatment: local build  control: `jordan-ctf-candidate:v102` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-preaimrange480.jsonl, seeds 370000-370059 both ways)
- verdict: level: K/D -0.0037 CI [-0.0149, +0.0060], win rate -0.008 CI [-0.075, +0.067], captures +1 CI [-5, +6], n=120
- pooled: 120 episodes, 0 skipped; RED won 64.2% of episodes
  - treatment: K/D 0.9981 (2676/2681), captures 22, wins 57
  - control: K/D 1.0019 (2682/2677), captures 21, wins 58
- rationale: How far off evidence has to be before the turret stops caring about it. The pre-aim scorer is now the single busiest consumer in the tree -- tracks, sonar landings AND shout fixes all price against this range -- and it has never been moved. Two of its neighbours have paid this session (preaimwatchttl60 promoted, shoutsee400 promoted) and both paid by changing WHAT the turret is allowed to look at rather than how it looks.

## preaimrange480-reverse — REJECT (local A/B)

- when: 2026-07-31T20:31:07+00:00
- change: `PreAimRange` -> `160.0`
- treatment: local build  control: `jordan-ctf-candidate:v102` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-preaimrange480-reverse.jsonl, seeds 371000-371059 both ways)
- verdict: level: K/D -0.0069 CI [-0.0466, +0.0325], win rate -0.033 CI [-0.192, +0.125], captures -1 CI [-15, +12], n=120
- pooled: 120 episodes, 0 skipped; RED won 60.8% of episodes
  - treatment: K/D 0.9966 (2620/2629), captures 27, wins 54
  - control: K/D 1.0034 (2625/2616), captures 28, wins 58
- rationale: Derived from preaimrange480: PreAimRange measured worse at 480.0, so the constant is worth testing in the other direction at 160.

## preaimarc32 — REJECT (local A/B)

- when: 2026-07-31T20:31:30+00:00
- change: `PreAimArc` -> `32`
- treatment: local build  control: `jordan-ctf-candidate:v102` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-preaimarc32.jsonl, seeds 372000-372059 both ways)
- verdict: level: K/D +0.0106 CI [-0.0350, +0.0566], win rate +0.033 CI [-0.142, +0.217], captures +2 CI [-12, +17], n=120
- pooled: 120 episodes, 0 skipped; RED won 48.3% of episodes
  - treatment: K/D 1.0053 (2652/2638), captures 23, wins 57
  - control: K/D 0.9947 (2639/2653), captures 21, wins 53
- rationale: While moving, the pre-aim may not stray more than 20 brads off the lane. 32 is exactly the vision cone's half-angle, which is the width that actually bounds the trade: past it the aim points somewhere the cone already covers from the lane heading, so 20 is a guess and 32 is the geometry. preaimarc28 was rejected under a much older tree, before the shout channel gave the pre- aim scorer something worth swinging onto.

## exposurerange280 — REJECT (local A/B)

- when: 2026-07-31T20:31:52+00:00
- change: `ExposureRange` -> `280.0`
- treatment: local build  control: `jordan-ctf-candidate:v102` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-exposurerange280.jsonl, seeds 373000-373059 both ways)
- verdict: wins separate NEGATIVE: K/D -0.1821 CI [-0.2243, -0.1395], win rate -0.517 CI [-0.650, -0.375], captures -19 CI [-30, -7], n=120
- pooled: 120 episodes, 0 skipped; RED won 38.3% of episodes
  - treatment: K/D 0.9130 (2508/2747), captures 13, wins 25
  - control: K/D 1.0951 (2751/2512), captures 32, wins 87
- rationale: The radius a remembered enemy is assumed to be able to shoot into, and the single biggest input to the routing cost field. ExposedCost -- the price of entering such a cell -- has been swept three times and settled at 22, but the SIZE of the region it prices has never been moved. 380px is over a quarter of the arena per threat, and with three threats marked the field can wall off most honest routes.

## exposurerange280-reverse — REJECT (local A/B)

- when: 2026-07-31T20:32:15+00:00
- change: `ExposureRange` -> `480.0`
- treatment: local build  control: `jordan-ctf-candidate:v102` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-exposurerange280-reverse.jsonl, seeds 374000-374059 both ways)
- verdict: wins separate NEGATIVE: K/D -0.1180 CI [-0.1645, -0.0727], win rate -0.325 CI [-0.483, -0.167], captures -14 CI [-27, -1], n=120
- pooled: 120 episodes, 0 skipped; RED won 56.7% of episodes
  - treatment: K/D 0.9429 (2558/2713), captures 18, wins 37
  - control: K/D 1.0609 (2700/2545), captures 32, wins 76
- rationale: Derived from exposurerange280: ExposureRange measured worse at 280.0, so the constant is worth testing in the other direction at 480.

## exposurethreats5 — REJECT (local A/B)

- when: 2026-07-31T20:32:37+00:00
- change: `ExposureThreats` -> `5`
- treatment: local build  control: `jordan-ctf-candidate:v102` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-exposurethreats5.jsonl, seeds 375000-375059 both ways)
- verdict: level: K/D +0.0153 CI [-0.0304, +0.0604], win rate +0.008 CI [-0.167, +0.175], captures +1 CI [-12, +14], n=120
- pooled: 120 episodes, 0 skipped; RED won 56.7% of episodes
  - treatment: K/D 1.0077 (2624/2604), captures 32, wins 58
  - control: K/D 0.9923 (2590/2610), captures 31, wins 57
- rationale: How many remembered enemies get marked into the exposure field. Three, of a possible eight, chosen when tracks were the only intel the bot had. The shout channel and the ghost frame now feed that same track table far more than they did, so the freshest three are a smaller share of what is known than they were.

## feashorizon120 — REJECT (local A/B)

- when: 2026-07-31T20:34:00+00:00
- change: `FeasHorizon` -> `120`
- treatment: local build  control: `jordan-ctf-candidate:v102` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-feashorizon120.jsonl, seeds 376000-376059 both ways, seeds 376200-376339 both ways, seeds 376400-376499 both ways)
- verdict: level: K/D +0.0103 CI [-0.0087, +0.0286], win rate +0.040 CI [-0.033, +0.110], captures +26 CI [-6, +57], n=600
- pooled: 600 episodes, 0 skipped; RED won 57.2% of episodes
  - treatment: K/D 1.0052 (13072/13005), captures 161, wins 293
  - control: K/D 0.9949 (13006/13073), captures 135, wins 269
- rationale: How far ahead couldTrade walks both bodies when asking whether a shot could ever happen. It gates the pre-aim scorer and the back-guard clamp, so it decides how much evidence is dismissed as scenery. 60 ticks is 2.5 seconds; at 120 the bot keeps pointing at threats whose line opens later.

## arcthreat140 — REJECT (local A/B)

- when: 2026-07-31T20:34:22+00:00
- change: `ArcThreatBonus` -> `140.0`
- treatment: local build  control: `jordan-ctf-candidate:v102` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-arcthreat140.jsonl, seeds 377000-377059 both ways)
- verdict: level: K/D +0.0015 CI [+0.0000, +0.0046], win rate +0.017 CI [+0.000, +0.050], captures +1 CI [+0, +3], n=120
- pooled: 120 episodes, 0 skipped; RED won 49.2% of episodes
  - treatment: K/D 1.0008 (2642/2640), captures 26, wins 58
  - control: K/D 0.9992 (2639/2641), captures 25, wins 56
- rationale: The engage-priority discount for an enemy holding the spray can. A cone weapon that out-ranges and out-damages the gun is the one that decides a fight, and this term is what swings the turret onto it first. It has never been moved, and its siblings in the same expression have both been measured (HpFocusBonus level, ShieldCostPenalty untouched).

## shieldcost90 — REJECT (local A/B)

- when: 2026-07-31T20:34:44+00:00
- change: `ShieldCostPenalty` -> `90.0`
- treatment: local build  control: `jordan-ctf-candidate:v102` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-shieldcost90.jsonl, seeds 378000-378059 both ways)
- verdict: level: K/D -0.0015 CI [-0.0046, +0.0000], win rate -0.017 CI [-0.050, +0.000], captures -1 CI [-3, +0], n=120
- pooled: 120 episodes, 0 skipped; RED won 50.8% of episodes
  - treatment: K/D 0.9992 (2622/2624), captures 26, wins 56
  - control: K/D 1.0008 (2624/2622), captures 27, wins 58
- rationale: The mirror of the above: an enemy carrying the endzone shield soaks a shot before any of them count, so an unshielded enemy beside a shielded one dies sooner for the same effort. Never moved. The hosted replay analysis says our shield uptime is 5.45% against the leader's 16.67% while we take more grenades than anyone -- the shield matters more in this game than this tree prices it.

## nadeblast64 — REJECT (local A/B)

- when: 2026-07-31T20:36:08+00:00
- change: `NadeBlast` -> `65.0`
- treatment: local build  control: `jordan-ctf-candidate:v102` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-nadeblast64.jsonl, seeds 379000-379059 both ways, seeds 379200-379339 both ways, seeds 379400-379499 both ways)
- verdict: level: K/D +0.0127 CI [-0.0075, +0.0328], win rate +0.042 CI [-0.037, +0.120], captures +23 CI [-11, +58], n=600
- pooled: 600 episodes, 0 skipped; RED won 55.0% of episodes
  - treatment: K/D 1.0064 (13132/13049), captures 160, wins 301
  - control: K/D 0.9937 (13051/13134), captures 137, wins 276
- rationale: The blast radius the grenade planner assumes, used both to decide whether two enemies share a throw and to flee our own. It is a model of the engine's number, not a copy of it, and it has never been checked against behaviour. Over-estimating pairs more targets and flees earlier; under-estimating does the reverse.

## serpentinefar560 — REJECT (local A/B)

- when: 2026-07-31T20:36:30+00:00
- change: `SerpentineFar` -> `560.0`
- treatment: local build  control: `jordan-ctf-candidate:v102` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-serpentinefar560.jsonl, seeds 380000-380059 both ways)
- verdict: level: K/D +0.0061 CI [-0.0379, +0.0521], win rate -0.017 CI [-0.167, +0.133], captures -2 CI [-15, +10], n=120
- pooled: 120 episodes, 0 skipped; RED won 52.5% of episodes
  - treatment: K/D 1.0030 (2643/2635), captures 25, wins 55
  - control: K/D 0.9970 (2633/2641), captures 27, wins 57
- rationale: The far edge of the band inside which the bot weaves rather than walking straight at a threat. steer-dither-quarter -- which QUARTERED the random steer noise -- is one of the largest promotions of this session, which says the feet were being wobbled more than they needed. The serpentine is the deliberate, threat-directed version of the same thing, and its band has never been moved.

## underfirettl40 — REJECT (local A/B)

- when: 2026-07-31T20:36:53+00:00
- change: `UnderFireTrackTtl` -> `40`
- treatment: local build  control: `jordan-ctf-candidate:v102` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-underfirettl40.jsonl, seeds 381000-381059 both ways)
- verdict: wins separate NEGATIVE: K/D -0.1213 CI [-0.1650, -0.0791], win rate -0.433 CI [-0.583, -0.283], captures -27 CI [-39, -15], n=120
- pooled: 120 episodes, 0 skipped; RED won 42.5% of episodes
  - treatment: K/D 0.9414 (2569/2729), captures 10, wins 30
  - control: K/D 1.0627 (2713/2553), captures 37, wins 82
- rationale: How long a track keeps counting as 'shooting at us right now'. 16 ticks is under a second and is the tightest freshness gate in the tree; every other one has been swept this session and two of them promoted by getting LOOSER (preaimwatchttl60, threatrange120-reverse).

## shout-kill-calls — REJECT (local A/B)

- when: 2026-07-31T20:47:46+00:00
- change: `ShoutKillCalls` -> `1`
- treatment: local build  control: `jordan-ctf-candidate:v102` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-shout-kill-calls.jsonl, seeds 382000-382059 both ways)
- verdict: level: K/D +0.0038 CI [-0.0325, +0.0401], win rate -0.075 CI [-0.225, +0.083], captures -4 CI [-17, +9], n=120
- pooled: 120 episodes, 0 skipped; RED won 60.8% of episodes
  - treatment: K/D 1.0019 (2654/2649), captures 22, wins 51
  - control: K/D 0.9981 (2646/2651), captures 26, wins 60
- rationale: The vocabulary's second word: `K<gx>,<gy>`, 'a body dropped here'. grenades.nim offers any track between FreshShotTicks and NadeMemTtl old as a lob target at its last known position, so a corpse draws grenades for about six seconds. The tree already defends against that by INFERENCE — the scoreboard delta paired with an unclaimed landing ring, dropping the nearest track within CorpseClearRadius — and that inference is `corpse-track-cleanup`, +0.096 K/D, one of the largest promotions on record, with its radius separately tuned to 40. But only the seat that heard the landing knows WHERE, so the other seven keep the track. This turns one seat's inference into seven seats' fact. The cost is real and is the reason this is one variable and not two: a kill call PREEMPTS the enemy fix for that slot, and airtime is the scarcest thing in the channel — halving the emit rate was worth +0.145 K/D. Instrumented, mode 1 emits 159 calls and clears 53 tracks in four episodes.
## AUDIT — the mirror pays a denial bonus that the league will not

- when: 2026-07-31T20:55:00+00:00
- measured on: the local simulator, seed-paired mirrors, n=400 episodes each
  (episodes/h2h--tmp-audit-48-vs--tmp-audit-24-20260731-205121.jsonl,
   episodes/h2h--tmp-aud2-400-vs--tmp-aud2-900-20260731-205410.jsonl)

`shout-eavesdrop` promoting put `ShoutHearFoe = 1` in the tree, which means
the OPPONENT in every local mirror reads our speech bubbles. From that moment
any experiment that reduces our own emissions is scored with a term the league
cannot pay: the treatment emits less AND still receives the control's full
stream, so the mirror hands it a one-sided denial advantage. Hosted, the
field's emit rate does not depend on ours at all.

Both promotions in that family were re-measured with `ShoutHearFoe = 0` on
BOTH sides, which removes exactly that term and nothing else:

| experiment | as promoted | with eavesdropping off | verdict |
|---|---|---|---|
| `shoutevery48` (24 -> 48) | +0.1454 [+0.1207, +0.1708] | **+0.0114 [-0.0142, +0.0376]** | the gain was the denial term |
| `shoutsee400` (900 -> 400) | +0.1158 [+0.0926, +0.1386] | **+0.1011 [+0.0762, +0.1249]** | real |

So `shoutevery48` is LEVEL on its merits and its ledger entry above overstates
it by an order of magnitude. It is not a regression -- level is level, and
against a field whose best players do read shouts some denial value is real --
so the tree keeps 48 and the champion is not rolled back. What is corrected is
the CLAIM.

`shoutsee400` survives the audit almost intact: restricting which sightings
are worth ten characters improves the channel's signal on its own.

**The standing rule this buys, which applies to every future experiment:**
anything that changes what this policy EMITS is measured in a mirror whose
opponent is this policy, so a reduction in emissions is scored partly as an
opponent handicap. Re-measure it with the opponent's ability to exploit the
channel switched off before believing the number.

## shieldsteal700 — REJECT (local A/B)

- when: 2026-07-31T20:56:40+00:00
- change: `ShieldStealDetour` -> `700.0`
- treatment: local build  control: `jordan-ctf-candidate:v102` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-shieldsteal700.jsonl, seeds 383000-383059 both ways)
- verdict: level: K/D +0.0000 CI [+0.0000, +0.0000], win rate +0.000 CI [+0.000, +0.000], captures +0 CI [+0, +0], n=120
- pooled: 120 episodes, 0 skipped; RED won 65.0% of episodes
  - treatment: K/D 1.0000 (2653/2653), captures 27, wins 57
  - control: K/D 1.0000 (2653/2653), captures 27, wins 57
- rationale: Item 7 of the replay programme, and the only one of its items that needs no new code. The hosted analysis measures our shield uptime at 5.45% against the leader's 16.67% while we take more grenades per episode than anyone in the corpus (9.65) and collect the fewest shields (1.37). This constant is the detour budget a seat will spend to pick one up, it has never been moved, and 480px against a 1235px arena is under half a map.

## peeklinedist220 — PROMOTE (local A/B)

- when: 2026-07-31T20:57:48+00:00
- change: `PeekLineDist` -> `220.0`
- treatment: local build  control: `jordan-ctf-candidate:v102` (the tree)
- shipped as: `jordan-ctf-candidate:v103`
- measured on: the local simulator, seed-paired mirrors (episodes/exp-peeklinedist220.jsonl, seeds 384000-384059 both ways, seeds 384200-384339 both ways)
- verdict: separates positive on the pooled sample: K/D +0.0400 CI [+0.0142, +0.0660], win rate +0.068 CI [-0.022, +0.160], captures +11 CI [-14, +37], n=400
- pooled: 400 episodes, 0 skipped; RED won 61.5% of episodes
  - treatment: K/D 1.0202 (8853/8678), captures 84, wins 200
  - control: K/D 0.9802 (8661/8836), captures 73, wins 173
- rationale: How far down the firing line the peek looks when scoring a cell to step to. The peek branch is now the tree's most valuable mechanism by a distance -- shout-peek (+0.164) feeds it, latticehold6 (+0.080) pins the cell it stands on, peekarrive2-reverse (+0.031) tuned its arrival -- and this, the length of the line it is scoring, has never been moved.

## peeklinedist220-further — REJECT (local A/B)

- when: 2026-07-31T20:58:12+00:00
- change: `PeekLineDist` -> `290.0`
- treatment: local build  control: `jordan-ctf-candidate:v103` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-peeklinedist220-further.jsonl, seeds 385000-385059 both ways)
- verdict: level: K/D +0.0000 CI [+0.0000, +0.0000], win rate +0.000 CI [+0.000, +0.000], captures +0 CI [+0, +0], n=120
- pooled: 120 episodes, 0 skipped; RED won 56.7% of episodes
  - treatment: K/D 1.0000 (2620/2620), captures 26, wins 58
  - control: K/D 1.0000 (2620/2620), captures 26, wins 58
- rationale: Derived from peeklinedist220: PeekLineDist paid at 220.0, so walk the same way again to 290 and find where it stops paying.

## peeksearch9 — PROMOTE (local A/B)

- when: 2026-07-31T20:59:24+00:00
- change: `PeekSearchCells` -> `9`
- treatment: local build  control: `jordan-ctf-candidate:v103` (the tree)
- shipped as: `jordan-ctf-candidate:v104`
- measured on: the local simulator, seed-paired mirrors (episodes/exp-peeksearch9.jsonl, seeds 386000-386059 both ways, seeds 386200-386339 both ways)
- verdict: separates positive on the pooled sample: K/D +0.1007 CI [+0.0733, +0.1288], win rate +0.190 CI [+0.098, +0.282], captures +72 CI [+47, +96], n=400
- pooled: 400 episodes, 0 skipped; RED won 43.8% of episodes
  - treatment: K/D 1.0510 (9050/8611), captures 120, wins 229
  - control: K/D 0.9502 (8385/8824), captures 48, wins 153
- rationale: How many cells outward findPeekCell will search for one that opens the line. Six cells is 48px. Same argument as peeklinedist220: three constants around this branch have paid this session and the branch's own search radius is not one of them.

## peeksearch9-further — REJECT (local A/B)

- when: 2026-07-31T20:59:50+00:00
- change: `PeekSearchCells` -> `12`
- treatment: local build  control: `jordan-ctf-candidate:v104` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-peeksearch9-further.jsonl, seeds 387000-387059 both ways)
- verdict: level: K/D -0.0083 CI [-0.0544, +0.0386], win rate -0.133 CI [-0.283, +0.017], captures +4 CI [-8, +16], n=120
- pooled: 120 episodes, 0 skipped; RED won 38.3% of episodes
  - treatment: K/D 0.9959 (2664/2675), captures 22, wins 49
  - control: K/D 1.0042 (2608/2597), captures 18, wins 65
- rationale: Derived from peeksearch9: PeekSearchCells paid at 9, so walk the same way again to 12 and find where it stops paying.

## peeksearch9-further-reverse — REJECT (local A/B)

- when: 2026-07-31T21:00:14+00:00
- change: `PeekSearchCells` -> `6`
- treatment: local build  control: `jordan-ctf-candidate:v104` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-peeksearch9-further-reverse.jsonl, seeds 388000-388059 both ways)
- verdict: wins separate NEGATIVE: K/D -0.1058 CI [-0.1594, -0.0518], win rate -0.217 CI [-0.383, -0.050], captures -24 CI [-36, -12], n=120
- pooled: 120 episodes, 0 skipped; RED won 40.0% of episodes
  - treatment: K/D 0.9477 (2518/2657), captures 8, wins 44
  - control: K/D 1.0535 (2737/2598), captures 32, wins 70
- rationale: Derived from peeksearch9-further: PeekSearchCells measured worse at 12, so the constant is worth testing in the other direction at 6.

## peekstandoff140 — REJECT (local A/B)

- when: 2026-07-31T21:00:39+00:00
- change: `PeekStandoffCap` -> `140.0`
- treatment: local build  control: `jordan-ctf-candidate:v104` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-peekstandoff140.jsonl, seeds 389000-389059 both ways)
- verdict: level: K/D -0.0184 CI [-0.0653, +0.0282], win rate -0.142 CI [-0.300, +0.025], captures -1 CI [-14, +13], n=120
- pooled: 120 episodes, 0 skipped; RED won 40.8% of episodes
  - treatment: K/D 0.9910 (2638/2662), captures 26, wins 47
  - control: K/D 1.0094 (2583/2559), captures 27, wins 64
- rationale: The cap on how much standoff distance is worth paying for in a peek cell. Its weight (PeekStandoffWeight) was swept this session and came back level at 1.2 -- a cap and a weight are different questions, and a level weight under a binding cap is what a binding cap looks like.

## peekstandoff140-reverse — REJECT (local A/B)

- when: 2026-07-31T21:01:04+00:00
- change: `PeekStandoffCap` -> `52.0`
- treatment: local build  control: `jordan-ctf-candidate:v104` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-peekstandoff140-reverse.jsonl, seeds 390000-390059 both ways)
- verdict: wins separate NEGATIVE: K/D -0.1432 CI [-0.2017, -0.0855], win rate -0.300 CI [-0.450, -0.133], captures -26 CI [-41, -11], n=120
- pooled: 120 episodes, 0 skipped; RED won 41.7% of episodes
  - treatment: K/D 0.9301 (2463/2648), captures 17, wins 39
  - control: K/D 1.0733 (2709/2524), captures 43, wins 75
- rationale: Derived from peekstandoff140: PeekStandoffCap measured worse at 140.0, so the constant is worth testing in the other direction at 52.

## medkitcrit280 — REJECT (local A/B)

- when: 2026-07-31T21:02:12+00:00
- change: `MedKitCriticalReach` -> `280.0`
- treatment: local build  control: `jordan-ctf-candidate:v104` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-medkitcrit280.jsonl, seeds 391000-391059 both ways, seeds 391200-391339 both ways)
- verdict: level: K/D +0.0130 CI [-0.0103, +0.0363], win rate +0.035 CI [-0.045, +0.113], captures -2 CI [-22, +18], n=400
- pooled: 400 episodes, 0 skipped; RED won 39.0% of episodes
  - treatment: K/D 1.0065 (8815/8758), captures 68, wins 195
  - control: K/D 0.9935 (8743/8800), captures 70, wins 181
- rationale: How far a hurt seat will go for a med kit. medkitdetour120 is one of the largest promotions on record (+0.097) and moved the ORDINARY detour budget; this is the separate, larger reach a critically wounded seat gets, and it has never been moved. The hosted analysis says we eat more grenades than anyone, which is the state this constant is for.

## pushout240 — REJECT (local A/B)

- when: 2026-07-31T21:02:37+00:00
- change: `PushOutTicks` -> `240`
- treatment: local build  control: `jordan-ctf-candidate:v104` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-pushout240.jsonl, seeds 392000-392059 both ways)
- verdict: level: K/D -0.0122 CI [-0.0430, +0.0183], win rate +0.125 CI [+0.000, +0.250], captures +12 CI [+2, +22], n=120
- pooled: 120 episodes, 0 skipped; RED won 40.0% of episodes
  - treatment: K/D 0.9939 (2621/2637), captures 27, wins 64
  - control: K/D 1.0061 (2636/2620), captures 15, wins 49
- rationale: How long the posts stay broken once the wave commits. The clock family has been swept from both ends this session (holdlinedepth160 promoted, LatePushTick 3000 rejected, ahead- draw-push level) and this is the duration of the commitment rather than its trigger.

## pushout240-reverse — REJECT (local A/B)

- when: 2026-07-31T21:03:03+00:00
- change: `PushOutTicks` -> `480`
- treatment: local build  control: `jordan-ctf-candidate:v104` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-pushout240-reverse.jsonl, seeds 393000-393059 both ways)
- verdict: level: K/D -0.0046 CI [-0.0257, +0.0168], win rate -0.017 CI [-0.133, +0.108], captures +0 CI [-10, +10], n=120
- pooled: 120 episodes, 0 skipped; RED won 43.3% of episodes
  - treatment: K/D 0.9977 (2621/2627), captures 26, wins 57
  - control: K/D 1.0023 (2626/2620), captures 26, wins 59
- rationale: Derived from pushout240: PushOutTicks measured worse at 240, so the constant is worth testing in the other direction at 480.

## cruisedead4 — REJECT (local A/B)

- when: 2026-07-31T21:03:28+00:00
- change: `CruiseDeadband` -> `4`
- treatment: local build  control: `jordan-ctf-candidate:v104` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-cruisedead4.jsonl, seeds 394000-394059 both ways)
- verdict: level: K/D -0.0397 CI [-0.0858, +0.0053], win rate -0.050 CI [-0.200, +0.100], captures +6 CI [-8, +20], n=120
- pooled: 120 episodes, 0 skipped; RED won 50.8% of episodes
  - treatment: K/D 0.9804 (2596/2648), captures 30, wins 52
  - control: K/D 1.0201 (2644/2592), captures 24, wins 58
- rationale: How close the aim has to be to its cruise heading before the turret stops correcting. 8 brads is four times the combat deadband; every brad of it is a cone pointed slightly off the lane while walking. Never moved, and the aim family is otherwise well explored -- which the hosted analysis says is where our best statistic already is, so expect level and read it as closing an axis.

## cruisedead4-reverse — PROMOTE (local A/B)

- when: 2026-07-31T21:04:42+00:00
- change: `CruiseDeadband` -> `12`
- treatment: local build  control: `jordan-ctf-candidate:v104` (the tree)
- shipped as: `jordan-ctf-candidate:v105`
- measured on: the local simulator, seed-paired mirrors (episodes/exp-cruisedead4-reverse.jsonl, seeds 395000-395059 both ways, seeds 395200-395339 both ways)
- verdict: separates positive on the pooled sample: K/D +0.0324 CI [+0.0062, +0.0598], win rate +0.075 CI [-0.022, +0.172], captures +49 CI [+23, +74], n=400
- pooled: 400 episodes, 0 skipped; RED won 41.5% of episodes
  - treatment: K/D 1.0161 (8874/8733), captures 116, wins 206
  - control: K/D 0.9837 (8522/8663), captures 67, wins 176
- rationale: Derived from cruisedead4: CruiseDeadband measured worse at 4, so the constant is worth testing in the other direction at 12.

## cruisedead4-reverse-further — PROMOTE (local A/B)

- when: 2026-07-31T21:05:54+00:00
- change: `CruiseDeadband` -> `16`
- treatment: local build  control: `jordan-ctf-candidate:v105` (the tree)
- shipped as: `jordan-ctf-candidate:v106`
- measured on: the local simulator, seed-paired mirrors (episodes/exp-cruisedead4-reverse-further.jsonl, seeds 396000-396059 both ways, seeds 396200-396339 both ways)
- verdict: separates positive on the pooled sample: K/D +0.0509 CI [+0.0281, +0.0745], win rate +0.185 CI [+0.098, +0.273], captures +13 CI [-14, +40], n=400
- pooled: 400 episodes, 0 skipped; RED won 54.8% of episodes
  - treatment: K/D 1.0260 (8719/8498), captures 99, wins 226
  - control: K/D 0.9751 (8670/8891), captures 86, wins 152
- rationale: Derived from cruisedead4-reverse: CruiseDeadband paid at 12, so walk the same way again to 16 and find where it stops paying.

## cruisedead4-reverse-further-further — REJECT (local A/B)

- when: 2026-07-31T21:06:19+00:00
- change: `CruiseDeadband` -> `20`
- treatment: local build  control: `jordan-ctf-candidate:v106` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-cruisedead4-reverse-further-further.jsonl, seeds 397000-397059 both ways)
- verdict: wins separate NEGATIVE: K/D -0.1003 CI [-0.1397, -0.0615], win rate -0.333 CI [-0.492, -0.175], captures -27 CI [-41, -13], n=120
- pooled: 120 episodes, 0 skipped; RED won 58.3% of episodes
  - treatment: K/D 0.9511 (2568/2700), captures 13, wins 36
  - control: K/D 1.0514 (2700/2568), captures 40, wins 76
- rationale: Derived from cruisedead4-reverse-further: CruiseDeadband paid at 16, so walk the same way again to 20 and find where it stops paying.

## serpnear160 — REJECT (local A/B)

- when: 2026-07-31T21:07:26+00:00
- change: `SerpentineNear` -> `160.0`
- treatment: local build  control: `jordan-ctf-candidate:v106` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-serpnear160.jsonl, seeds 398000-398059 both ways, seeds 398200-398339 both ways)
- verdict: level: K/D +0.0099 CI [-0.0101, +0.0300], win rate +0.020 CI [-0.055, +0.092], captures -4 CI [-26, +19], n=400
- pooled: 400 episodes, 0 skipped; RED won 37.0% of episodes
  - treatment: K/D 1.0050 (8695/8652), captures 91, wins 197
  - control: K/D 0.9950 (8629/8672), captures 95, wins 189
- rationale: The near edge of the weave band. steer-dither-quarter -- quartering the RANDOM steer noise -- was one of the largest promotions of the session, which says the feet were wobbling more than they needed; the serpentine is the deliberate version of the same motion and its near edge has never been moved.

## shout-kill-slot — REJECT (local A/B)

- when: 2026-07-31T21:17:03+00:00
- change: `ShoutKillCalls` -> `2`
- treatment: local build  control: `jordan-ctf-candidate:v106` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-shout-kill-slot.jsonl, seeds 399000-399059 both ways)
- verdict: level: K/D +0.0023 CI [-0.0477, +0.0520], win rate +0.008 CI [-0.183, +0.192], captures -1 CI [-17, +15], n=120
- pooled: 120 episodes, 0 skipped; RED won 38.3% of episodes
  - treatment: K/D 1.0012 (2606/2603), captures 29, wins 55
  - control: K/D 0.9989 (2608/2611), captures 30, wins 54
- rationale: The kill call with its OWN slot instead of displacing a sighting. The engine accepts a shout every 24 ticks and the fix cadence is 48, so every other slot goes unused; rung 2 spends those. This exists because the premise rung 1 was priced against did not survive: ShoutEveryTicks 24 -> 48 measured +0.145 but audited to +0.0114, level, once the opponent's eavesdropping was switched off. Instrumented, rung 2 emits 163 calls against rung 1's 158 while enemy fixes rise from 367 to 383 -- so rung 1's displacement was real but small, about 4% of fixes. That is itself informative: if rung 2 ALSO reads level, the explanation is not airtime but redundancy, because corpse-track-cleanup (+0.096) already infers the same deaths from the scoreboard delta and a landing ring.

## thieffixttl120 — REJECT (local A/B)

- when: 2026-07-31T21:17:28+00:00
- change: `ThiefFixTtl` -> `120`
- treatment: local build  control: `jordan-ctf-candidate:v106` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-thieffixttl120.jsonl, seeds 400000-400059 both ways)
- verdict: level: K/D +0.0030 CI [+0.0000, +0.0069], win rate +0.008 CI [-0.025, +0.050], captures -2 CI [-5, +0], n=120
- pooled: 120 episodes, 0 skipped; RED won 40.0% of episodes
  - treatment: K/D 1.0015 (2631/2627), captures 22, wins 57
  - control: K/D 0.9985 (2627/2631), captures 24, wins 56
- rationale: A thief fix guides the chase for 40 ticks. RespawnTicks is 72, so a fix banked by a seat that then dies is structurally dead before that seat plays again -- which is exactly what ghost- flag-thief measured: bit-identical episodes despite banking 11867 fixes. 120 outlives a respawn. This is the smallest change that makes the whole thief-hunt apparatus reachable, and two independent exact zeros (thieffocus600, ghost-flag-thief) say it currently is not.

## trackmatch28 — REJECT (local A/B)

- when: 2026-07-31T21:17:53+00:00
- change: `TrackMatchDist` -> `28.0`
- treatment: local build  control: `jordan-ctf-candidate:v106` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-trackmatch28.jsonl, seeds 401000-401059 both ways)
- verdict: level: K/D -0.0333 CI [-0.0750, +0.0107], win rate -0.133 CI [-0.300, +0.033], captures +7 CI [-7, +21], n=120
- pooled: 120 episodes, 0 skipped; RED won 31.7% of episodes
  - treatment: K/D 0.9835 (2562/2605), captures 35, wins 50
  - control: K/D 1.0168 (2601/2558), captures 28, wins 66
- rationale: How near a sighting has to be to claim a remembered track. 40px against a map where a body moves 2.75px/tick means a sighting can claim a track a full second stale and inherit its velocity. Named matching runs first, so this only governs unbadged bodies -- the case where a wrong match inverts the velocity we lead shots with.
## The kill call, settled: it was redundancy, not airtime

`shout-kill-calls` (rung 1, preempting) and `shout-kill-slot` (rung 2, its own
slot) both measure LEVEL — +0.0038 [−0.0325, +0.0401] and +0.0023 [−0.0477,
+0.0520]. The two rungs were built to tell two explanations apart, and they do:

- **Airtime is not the explanation.** Rung 2 pays no displacement tax at all —
  instrumented, it emits 163 calls against rung 1's 158 while enemy fixes RISE
  from 367 to 383 — and it reads level anyway. (Rung 1's displacement was
  measured at about 4% of fixes, which was already too small to hide an
  effect.)
- **Redundancy is.** The listener's benefit was already available:
  `corpse-track-cleanup` (+0.096 K/D, promoted) infers the same deaths from
  the scoreboard delta paired with a map-wide landing ring, and the ring is
  audible through walls and fog to every living player. A kill call tells the
  other seven seats something they had already worked out for themselves.

The vocabulary keeps one word. The general lesson is worth more than the
experiment: **a second word must carry information the listener cannot already
derive, not merely information it did not derive from the same source.** The
first word passed that test because a sighting is fog-limited and private to
one cone; a death is not, because the engine broadcasts a ring for every shot.

`thieffixttl120` in the same batch is the third exact-ish zero on the thief
machinery (+0.0030 [+0.0000, +0.0069]) — extending the fix past a 72-tick
respawn changes nothing either, which is now three independent measurements
saying the thief-hunt apparatus is not exercised in mirror play at all.

## trackmatch28-reverse — REJECT (local A/B)

- when: 2026-07-31T21:45:40+00:00
- change: `TrackMatchDist` -> `52.0`
- treatment: local build  control: `jordan-ctf-candidate:v106` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-trackmatch28-reverse.jsonl, seeds 401000-401059 both ways)
- verdict: level: K/D -0.0264 CI [-0.0713, +0.0195], win rate -0.067 CI [-0.233, +0.092], captures -2 CI [-17, +13], n=120
- pooled: 120 episodes, 0 skipped; RED won 28.3% of episodes
  - treatment: K/D 0.9869 (2566/2600), captures 27, wins 51
  - control: K/D 1.0133 (2592/2558), captures 29, wins 59
- rationale: Derived from trackmatch28: TrackMatchDist measured worse at 28.0, so the constant is worth testing in the other direction at 52.

## preaimtrackttl150 — REJECT (local A/B)

- when: 2026-07-31T21:46:56+00:00
- change: `PreAimTrackTtl` -> `150`
- treatment: local build  control: `jordan-ctf-candidate:v106` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-preaimtrackttl150.jsonl, seeds 402000-402059 both ways)
- verdict: level: K/D +0.0000 CI [+0.0000, +0.0000], win rate +0.000 CI [+0.000, +0.000], captures +0 CI [+0, +0], n=120
- pooled: 120 episodes, 0 skipped; RED won 43.3% of episodes
  - treatment: K/D 1.0000 (2594/2594), captures 34, wins 54
  - control: K/D 1.0000 (2594/2594), captures 34, wins 54
- rationale: How long a remembered enemy still points the turret. preaimwatchttl60 -- the keeper's version of the same question -- promoted this session by getting LOOSER, and this is the general one.

## preaimpingcost80 — REJECT (local A/B)

- when: 2026-07-31T21:48:10+00:00
- change: `PreAimPingCost` -> `80.0`
- treatment: local build  control: `jordan-ctf-candidate:v106` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-preaimpingcost80.jsonl, seeds 403000-403059 both ways)
- verdict: level: K/D +0.0000 CI [-0.0304, +0.0313], win rate +0.025 CI [-0.083, +0.133], captures +4 CI [-5, +14], n=120
- pooled: 120 episodes, 0 skipped; RED won 25.8% of episodes
  - treatment: K/D 1.0000 (2643/2643), captures 29, wins 56
  - control: K/D 1.0000 (2636/2636), captures 25, wins 53
- rationale: What a heard landing is worth against a sighting in the pre-aim scorer. 120px of effective distance, never moved, and the scorer around it has changed completely since: it now carries shout fixes too, and shoutsee400 survived an audit by improving the channel's signal quality.

## nademax300 — REJECT (local A/B)

- when: 2026-07-31T21:49:25+00:00
- change: `NadeMaxRange` -> `300.0`
- treatment: local build  control: `jordan-ctf-candidate:v106` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-nademax300.jsonl, seeds 404000-404059 both ways)
- verdict: wins separate NEGATIVE: K/D -0.0473 CI [-0.0929, -0.0015], win rate -0.200 CI [-0.367, -0.042], captures -11 CI [-23, +0], n=120
- pooled: 120 episodes, 0 skipped; RED won 50.0% of episodes
  - treatment: K/D 0.9768 (2610/2672), captures 16, wins 42
  - control: K/D 1.0241 (2638/2576), captures 27, wins 66
- rationale: The longest throw the planner will attempt. The grenade family has paid twice on reach already (NadeFarmReach 420 then 500, both promoted), and this is the throw itself rather than the errand that goes to fetch one.

## nademax300-reverse — REJECT (local A/B)

- when: 2026-07-31T21:50:42+00:00
- change: `NadeMaxRange` -> `180.0`
- treatment: local build  control: `jordan-ctf-candidate:v106` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-nademax300-reverse.jsonl, seeds 405000-405059 both ways)
- verdict: wins separate NEGATIVE: K/D -0.1756 CI [-0.2293, -0.1230], win rate -0.358 CI [-0.533, -0.183], captures -15 CI [-29, +0], n=120
- pooled: 120 episodes, 0 skipped; RED won 43.3% of episodes
  - treatment: K/D 0.9157 (2454/2680), captures 20, wins 35
  - control: K/D 1.0913 (2702/2476), captures 35, wins 78
- rationale: Derived from nademax300: NadeMaxRange measured worse at 300.0, so the constant is worth testing in the other direction at 180.

## plasmareach180 — REJECT (local A/B)

- when: 2026-07-31T21:51:57+00:00
- change: `PlasmaReach` -> `180.0`
- treatment: local build  control: `jordan-ctf-candidate:v106` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-plasmareach180.jsonl, seeds 406000-406059 both ways)
- verdict: level: K/D -0.0093 CI [-0.0454, +0.0278], win rate +0.017 CI [-0.117, +0.142], captures -1 CI [-12, +10], n=120
- pooled: 120 episodes, 0 skipped; RED won 33.3% of episodes
  - treatment: K/D 0.9954 (2575/2587), captures 29, wins 57
  - control: K/D 1.0046 (2595/2583), captures 30, wins 55
- rationale: The range the bot believes the spray can covers, which sets the engage cap while carrying it. Never moved, and it is a model of an engine number rather than a copy of one.

## plasmareach180-reverse — REJECT (local A/B)

- when: 2026-07-31T21:55:43+00:00
- change: `PlasmaReach` -> `92.0`
- treatment: local build  control: `jordan-ctf-candidate:v106` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-plasmareach180-reverse.jsonl, seeds 407000-407059 both ways, seeds 407200-407339 both ways)
- verdict: level: K/D -0.0005 CI [-0.0178, +0.0166], win rate -0.005 CI [-0.072, +0.062], captures -4 CI [-20, +12], n=400
- pooled: 400 episodes, 0 skipped; RED won 34.8% of episodes
  - treatment: K/D 0.9998 (8675/8677), captures 85, wins 188
  - control: K/D 1.0002 (8683/8681), captures 89, wins 190
- rationale: Derived from plasmareach180: PlasmaReach measured worse at 180.0, so the constant is worth testing in the other direction at 92.

## carryself40 — REJECT (local A/B)

- when: 2026-07-31T21:57:04+00:00
- change: `CarrySelfRadius` -> `40.0`
- treatment: local build  control: `jordan-ctf-candidate:v106` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-carryself40.jsonl, seeds 408000-408059 both ways)
- verdict: level: K/D +0.0000 CI [+0.0000, +0.0000], win rate +0.000 CI [+0.000, +0.000], captures +0 CI [+0, +0], n=120
- pooled: 120 episodes, 0 skipped; RED won 31.7% of episodes
  - treatment: K/D 1.0000 (2601/2601), captures 29, wins 58
  - control: K/D 1.0000 (2601/2601), captures 29, wins 58
- rationale: How near the carried banner has to be to count as ON us. 26px decides `iCarry`, which switches the whole policy between attacking and running home -- a wrong answer there is the most expensive single misread available, and the constant has never been checked.

## exposurettl30 — REJECT (local A/B)

- when: 2026-07-31T21:58:24+00:00
- change: `ExposureTrackTtl` -> `30`
- treatment: local build  control: `jordan-ctf-candidate:v106` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-exposurettl30.jsonl, seeds 409000-409059 both ways)
- verdict: wins separate NEGATIVE: K/D -0.0749 CI [-0.1215, -0.0261], win rate -0.175 CI [-0.342, -0.008], captures -15 CI [-30, +0], n=120
- pooled: 120 episodes, 0 skipped; RED won 55.8% of episodes
  - treatment: K/D 0.9633 (2543/2640), captures 22, wins 46
  - control: K/D 1.0381 (2641/2544), captures 37, wins 67
- rationale: How stale a track may be and still wall off ground in the routing field. ExposedCost has been swept three times and settled at 22, so the field is priced; how long a threat stays in it has never been asked. The record's standing finding is that stale intel costs more than it pays.

## exposurettl30-reverse — PROMOTE (local A/B)

- when: 2026-07-31T22:01:50+00:00
- change: `ExposureTrackTtl` -> `90`
- treatment: local build  control: `jordan-ctf-candidate:v106` (the tree)
- shipped as: `jordan-ctf-candidate:v110`
- measured on: the local simulator, seed-paired mirrors (episodes/exp-exposurettl30-reverse.jsonl, seeds 410000-410059 both ways, seeds 410200-410339 both ways)
- verdict: separates positive on the pooled sample: K/D +0.0309 CI [+0.0012, +0.0601], win rate +0.077 CI [-0.018, +0.170], captures +25 CI [-1, +52], n=400
- pooled: 400 episodes, 0 skipped; RED won 32.8% of episodes
  - treatment: K/D 1.0155 (8687/8554), captures 104, wins 204
  - control: K/D 0.9846 (8530/8663), captures 79, wins 173
- rationale: Derived from exposurettl30: ExposureTrackTtl measured worse at 30, so the constant is worth testing in the other direction at 90.

## exposurettl30-reverse-further — REJECT (local A/B)

- when: 2026-07-31T22:02:55+00:00
- change: `ExposureTrackTtl` -> `120`
- treatment: local build  control: `jordan-ctf-candidate:v110` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-exposurettl30-reverse-further.jsonl, seeds 411000-411059 both ways)
- verdict: level: K/D -0.0236 CI [-0.0684, +0.0221], win rate -0.167 CI [-0.325, +0.000], captures -5 CI [-18, +8], n=120
- pooled: 120 episodes, 0 skipped; RED won 40.8% of episodes
  - treatment: K/D 0.9884 (2641/2672), captures 24, wins 45
  - control: K/D 1.0120 (2606/2575), captures 29, wins 65
- rationale: Derived from exposurettl30-reverse: ExposureTrackTtl paid at 90, so walk the same way again to 120 and find where it stops paying.

## exposurettl30-reverse-further-reverse — REJECT (local A/B)

- when: 2026-07-31T22:03:59+00:00
- change: `ExposureTrackTtl` -> `60`
- treatment: local build  control: `jordan-ctf-candidate:v110` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-exposurettl30-reverse-further-reverse.jsonl, seeds 412000-412059 both ways)
- verdict: level: K/D -0.0122 CI [-0.0593, +0.0360], win rate -0.058 CI [-0.242, +0.125], captures +3 CI [-11, +17], n=120
- pooled: 120 episodes, 0 skipped; RED won 28.3% of episodes
  - treatment: K/D 0.9939 (2603/2619), captures 25, wins 51
  - control: K/D 1.0061 (2622/2606), captures 22, wins 58
- rationale: Derived from exposurettl30-reverse-further: ExposureTrackTtl measured worse at 120, so the constant is worth testing in the other direction at 60.

## weaveband400 — REJECT (local A/B)

- when: 2026-07-31T22:05:14+00:00
- change: `WeaveBand` -> `400.0`
- treatment: local build  control: `jordan-ctf-candidate:v110` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-weaveband400.jsonl, seeds 413000-413059 both ways)
- verdict: wins separate NEGATIVE: K/D -0.0544 CI [-0.1082, -0.0008], win rate -0.250 CI [-0.425, -0.075], captures -16 CI [-29, -3], n=120
- pooled: 120 episodes, 0 skipped; RED won 53.3% of episodes
  - treatment: K/D 0.9736 (2577/2647), captures 18, wins 43
  - control: K/D 1.0279 (2578/2508), captures 34, wins 73
- rationale: The band inside which the carrier weaves on the way home. steer- dither-quarter cut the random steer noise and was one of the largest promotions of the session, which says the feet were moving more than they needed to.

## weaveband400-reverse — PROMOTE (local A/B)

- when: 2026-07-31T22:08:52+00:00
- change: `WeaveBand` -> `160.0`
- treatment: local build  control: `jordan-ctf-candidate:v110` (the tree)
- shipped as: `jordan-ctf-candidate:v111`
- measured on: the local simulator, seed-paired mirrors (episodes/exp-weaveband400-reverse.jsonl, seeds 414000-414059 both ways, seeds 414200-414339 both ways)
- verdict: separates positive on the pooled sample: K/D +0.0392 CI [+0.0140, +0.0642], win rate +0.142 CI [+0.045, +0.237], captures +40 CI [+14, +66], n=400
- pooled: 400 episodes, 0 skipped; RED won 47.8% of episodes
  - treatment: K/D 1.0199 (8785/8614), captures 109, wins 216
  - control: K/D 0.9806 (8651/8822), captures 69, wins 159
- rationale: Derived from weaveband400: WeaveBand measured worse at 400.0, so the constant is worth testing in the other direction at 160.

## weaveband400-reverse-further — PROMOTE (local A/B)

- when: 2026-07-31T22:12:36+00:00
- change: `WeaveBand` -> `40.0`
- treatment: local build  control: `jordan-ctf-candidate:v111` (the tree)
- shipped as: `jordan-ctf-candidate:v112`
- measured on: the local simulator, seed-paired mirrors (episodes/exp-weaveband400-reverse-further.jsonl, seeds 415000-415059 both ways, seeds 415200-415339 both ways)
- verdict: separates positive on the pooled sample: K/D +0.0900 CI [+0.0661, +0.1143], win rate +0.295 CI [+0.207, +0.383], captures +45 CI [+20, +69], n=400
- pooled: 400 episodes, 0 skipped; RED won 41.2% of episodes
  - treatment: K/D 1.0461 (8938/8544), captures 115, wins 246
  - control: K/D 0.9561 (8585/8979), captures 70, wins 128
- rationale: Derived from weaveband400-reverse: WeaveBand paid at 160.0, so walk the same way again to 40 and find where it stops paying.

## lanetop80 — REJECT (local A/B)

- when: 2026-07-31T22:13:45+00:00
- change: `LaneTop` -> `80.0`
- treatment: local build  control: `jordan-ctf-candidate:v112` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-lanetop80.jsonl, seeds 416000-416059 both ways)
- verdict: level: K/D -0.0215 CI [-0.0640, +0.0207], win rate -0.017 CI [-0.192, +0.158], captures +11 CI [-5, +27], n=120
- pooled: 120 episodes, 0 skipped; RED won 50.8% of episodes
  - treatment: K/D 0.9893 (2587/2615), captures 37, wins 55
  - control: K/D 1.0108 (2625/2597), captures 26, wins 57
- rationale: The top lane's inset from the map edge. The hosted replay analysis measures our formation as the most spread in the field and the flankers as the seats furthest forward; this is the constant that places one of them.

## diagcost8 — PROMOTE (local A/B)

- when: 2026-07-31T22:17:24+00:00
- change: `DiagCost` -> `8`
- treatment: local build  control: `jordan-ctf-candidate:v112` (the tree)
- shipped as: `jordan-ctf-candidate:v113`
- measured on: the local simulator, seed-paired mirrors (episodes/exp-diagcost8.jsonl, seeds 417000-417059 both ways, seeds 417200-417339 both ways)
- verdict: separates positive on the pooled sample: K/D +0.0315 CI [+0.0060, +0.0571], win rate +0.068 CI [-0.022, +0.160], captures +38 CI [+12, +65], n=400
- pooled: 400 episodes, 0 skipped; RED won 38.0% of episodes
  - treatment: K/D 1.0157 (8803/8667), captures 110, wins 200
  - control: K/D 0.9842 (8492/8628), captures 72, wins 173
- rationale: The cost field's diagonal step against its orthogonal 5. 7/5 = 1.4 is the Euclidean ratio, which is right for distance and not necessarily right for a body that must clear corners with a 6px half-extent. 8 biases toward orthogonal approaches.

## diagcost8-further — REJECT (local A/B)

- when: 2026-07-31T22:18:38+00:00
- change: `DiagCost` -> `9`
- treatment: local build  control: `jordan-ctf-candidate:v113` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-diagcost8-further.jsonl, seeds 418000-418059 both ways)
- verdict: captures separate NEGATIVE: K/D -0.0312 CI [-0.0823, +0.0184], win rate -0.025 CI [-0.200, +0.142], captures -22 CI [-35, -9], n=120
- pooled: 120 episodes, 0 skipped; RED won 58.3% of episodes
  - treatment: K/D 0.9843 (2576/2617), captures 13, wins 57
  - control: K/D 1.0156 (2677/2636), captures 35, wins 60
- rationale: Derived from diagcost8: DiagCost paid at 8, so walk the same way again to 9 and find where it stops paying.

## diagcost8-further-reverse — REJECT (local A/B)

- when: 2026-07-31T22:19:51+00:00
- change: `DiagCost` -> `7`
- treatment: local build  control: `jordan-ctf-candidate:v113` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-diagcost8-further-reverse.jsonl, seeds 419000-419059 both ways)
- verdict: captures separate NEGATIVE: K/D -0.0685 CI [-0.1129, -0.0251], win rate -0.158 CI [-0.333, +0.017], captures -23 CI [-38, -9], n=120
- pooled: 120 episodes, 0 skipped; RED won 44.2% of episodes
  - treatment: K/D 0.9661 (2561/2651), captures 19, wins 48
  - control: K/D 1.0346 (2693/2603), captures 42, wins 67
- rationale: Derived from diagcost8-further: DiagCost measured worse at 9, so the constant is worth testing in the other direction at 7.

## ownest16 — REJECT (local A/B)

- when: 2026-07-31T22:21:03+00:00
- change: `OwnEstSpeed` -> `1.6`
- treatment: local build  control: `jordan-ctf-candidate:v113` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-ownest16.jsonl, seeds 420000-420059 both ways)
- verdict: wins separate NEGATIVE: K/D -0.0538 CI [-0.0940, -0.0145], win rate -0.225 CI [-0.383, -0.067], captures -24 CI [-39, -9], n=120
- pooled: 120 episodes, 0 skipped; RED won 47.5% of episodes
  - treatment: K/D 0.9734 (2561/2631), captures 20, wins 44
  - control: K/D 1.0272 (2647/2577), captures 44, wins 71
- rationale: The speed the bot assumes for ITSELF when asking whether a shot could ever happen (couldTrade). 1.0 px/tick against an engine maximum of 2.75 makes the bot systematically pessimistic about lines that would open if it kept walking.

## ownest16-reverse — REJECT (local A/B)

- when: 2026-07-31T22:22:15+00:00
- change: `OwnEstSpeed` -> `0.3999999999999999`
- treatment: local build  control: `jordan-ctf-candidate:v113` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-ownest16-reverse.jsonl, seeds 421000-421059 both ways)
- verdict: level: K/D -0.0193 CI [-0.0701, +0.0322], win rate -0.117 CI [-0.275, +0.042], captures +6 CI [-7, +20], n=120
- pooled: 120 episodes, 0 skipped; RED won 50.8% of episodes
  - treatment: K/D 0.9905 (2614/2639), captures 31, wins 50
  - control: K/D 1.0098 (2565/2540), captures 25, wins 64
- rationale: Derived from ownest16: OwnEstSpeed measured worse at 1.6, so the constant is worth testing in the other direction at 0.4.

## shout-kill-here — REJECT (local A/B)

- when: 2026-07-31T22:25:39+00:00
- change: `ShoutKillHere` -> `1`
- treatment: local build  control: `jordan-ctf-candidate:v113` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-shout-kill-here.jsonl, seeds 422000-422059 both ways, seeds 422200-422339 both ways)
- verdict: level: K/D -0.0062 CI [-0.0318, +0.0197], win rate +0.072 CI [-0.015, +0.158], captures -10 CI [-36, +16], n=400
- pooled: 400 episodes, 0 skipped; RED won 39.0% of episodes
  - treatment: K/D 0.9969 (8599/8626), captures 82, wins 203
  - control: K/D 1.0031 (8775/8748), captures 92, wins 174
- rationale: The lead player's actual word, read correctly. His `K<seat><xx><yy>` fires ON A KILL but its payload is HIS OWN position -- the seat digit was exact in 100% of 22976 decoded samples. That is a better design than either rung of our own kill call, and for a reason the record already proved: the death LOCATION is derivable by the listener, because the engine broadcasts a landing ring for every shot to every living player through walls and fog, which is exactly why both rungs of shout- kill-calls measured level. The SHOUTER'S position is not derivable at all -- the ruleset fogs teammates by construction. Rung 1 wires it to the friendly-fire guard, which is the consumer with the clearest cost: the bullet is a corridor hitscan and the server kills the NEAREST body in it, friend or foe, while the guard that declines those shots weighs only mates sighted in the last 36 ticks -- so it is blindest to exactly the fogged teammate it exists to protect. Instrumented over four episodes: 462 mate positions heard, 30 shots declined that would otherwise have been fired through a teammate.

## shout-kill-here-feet — REJECT (local A/B)

- when: 2026-07-31T22:28:49+00:00
- change: `ShoutKillHere` -> `2`
- treatment: local build  control: `jordan-ctf-candidate:v113` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-shout-kill-here-feet.jsonl, seeds 423000-423059 both ways, seeds 423200-423339 both ways)
- verdict: level: K/D +0.0041 CI [-0.0225, +0.0302], win rate +0.058 CI [-0.035, +0.152], captures +13 CI [-11, +37], n=400
- pooled: 400 episodes, 0 skipped; RED won 34.5% of episodes
  - treatment: K/D 1.0021 (8671/8653), captures 97, wins 204
  - control: K/D 0.9980 (8792/8810), captures 84, wins 181
- rationale: The second rung: a heard mate position also pushes the spacing repulsion, not just the trigger discipline. MateSpacing has paid twice this session walking the same way (40 -> 60 -> 80, +0.0907 on the last step), which says the formation's shape is worth real K/D -- and today that repulsion only works against teammates we can SEE, so it is strongest exactly where it is least needed. Second rung rather than first because it moves the feet, and the feet are where this tree's regressions have come from.

## preaimagepx3 — REJECT (local A/B)

- when: 2026-07-31T22:46:22+00:00
- change: `PreAimAgePx` -> `3.0`
- treatment: local build  control: `jordan-ctf-candidate:v113` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-preaimagepx3.jsonl, seeds 424000-424059 both ways)
- verdict: level: K/D -0.0053 CI [-0.0470, +0.0371], win rate -0.008 CI [-0.167, +0.150], captures +5 CI [-7, +18], n=120
- pooled: 120 episodes, 0 skipped; RED won 45.0% of episodes
  - treatment: K/D 0.9974 (2673/2680), captures 27, wins 57
  - control: K/D 1.0027 (2617/2610), captures 22, wins 58
- rationale: Px of doubt added to a piece of evidence per tick of staleness, in the pre-aim scorer. Three separate results this session say this tree over-trusts things that are no longer true and over- moves in response: corpse-track-cleanup (+0.096, throw stale tracks away), exposurettl30-reverse (+0.031, hold threats in the routing field for longer or shorter), and every calm-the-motion promotion below. This is the one term that prices staleness directly, and it has never been moved.

## sonarttl45 — REJECT (local A/B)

- when: 2026-07-31T22:47:31+00:00
- change: `SonarTtl` -> `45`
- treatment: local build  control: `jordan-ctf-candidate:v113` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-sonarttl45.jsonl, seeds 425000-425059 both ways)
- verdict: level: K/D -0.0331 CI [-0.0769, +0.0092], win rate +0.025 CI [-0.158, +0.200], captures +0 CI [-15, +15], n=120
- pooled: 120 episodes, 0 skipped; RED won 34.2% of episodes
  - treatment: K/D 0.9836 (2578/2621), captures 26, wins 60
  - control: K/D 1.0167 (2619/2576), captures 26, wins 57
- rationale: How long a heard shot landing stays in memory at all. 90 ticks is nearly four seconds, and a landing is evidence about where somebody WAS. Its two derived radii are both tuned (SonarHotRadius 90, SonarExactRadius 34) but the lifetime feeding them is not. Same axis as corpse-track-cleanup, which is the largest cleanup result on record.

## sonarttl45-reverse — REJECT (local A/B)

- when: 2026-07-31T22:48:39+00:00
- change: `SonarTtl` -> `135`
- treatment: local build  control: `jordan-ctf-candidate:v113` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-sonarttl45-reverse.jsonl, seeds 426000-426059 both ways)
- verdict: level: K/D +0.0000 CI [+0.0000, +0.0000], win rate +0.000 CI [+0.000, +0.000], captures +0 CI [+0, +0], n=120
- pooled: 120 episodes, 0 skipped; RED won 36.7% of episodes
  - treatment: K/D 1.0000 (2594/2594), captures 34, wins 58
  - control: K/D 1.0000 (2594/2594), captures 34, wins 58
- rationale: Derived from sonarttl45: SonarTtl measured worse at 45, so the constant is worth testing in the other direction at 135.

## feassteps5 — REJECT (local A/B)

- when: 2026-07-31T22:49:52+00:00
- change: `FeasSteps` -> `5`
- treatment: local build  control: `jordan-ctf-candidate:v113` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-feassteps5.jsonl, seeds 427000-427059 both ways)
- verdict: level: K/D -0.0373 CI [-0.0779, +0.0038], win rate -0.100 CI [-0.267, +0.067], captures -4 CI [-19, +11], n=120
- pooled: 120 episodes, 0 skipped; RED won 43.3% of episodes
  - treatment: K/D 0.9815 (2596/2645), captures 26, wins 49
  - control: K/D 1.0188 (2652/2603), captures 30, wins 61
- rationale: How many points along the horizon couldTrade samples when asking whether a shot could ever happen. Three samples over 60 ticks is one every 20 ticks, and a body covers 55px in that time -- a line that opens and closes between samples is invisible. couldTrade gates the pre-aim scorer and the back-guard clamp, so it decides how much evidence is dismissed as scenery.

## feassteps5-reverse — REJECT (local A/B)

- when: 2026-07-31T22:51:08+00:00
- change: `FeasSteps` -> `1`
- treatment: local build  control: `jordan-ctf-candidate:v113` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-feassteps5-reverse.jsonl, seeds 428000-428059 both ways)
- verdict: level: K/D +0.0137 CI [-0.0277, +0.0545], win rate +0.042 CI [-0.108, +0.192], captures -1 CI [-14, +13], n=120
- pooled: 120 episodes, 0 skipped; RED won 39.2% of episodes
  - treatment: K/D 1.0069 (2629/2611), captures 29, wins 60
  - control: K/D 0.9931 (2608/2626), captures 30, wins 55
- rationale: Derived from feassteps5: FeasSteps measured worse at 5, so the constant is worth testing in the other direction at 1.

## plasmahalf14 — REJECT (local A/B)

- when: 2026-07-31T22:52:22+00:00
- change: `PlasmaHalfBrads` -> `14`
- treatment: local build  control: `jordan-ctf-candidate:v113` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-plasmahalf14.jsonl, seeds 429000-429059 both ways)
- verdict: level: K/D -0.0139 CI [-0.0421, +0.0143], win rate -0.067 CI [-0.192, +0.050], captures -9 CI [-18, +0], n=120
- pooled: 120 episodes, 0 skipped; RED won 37.5% of episodes
  - treatment: K/D 0.9931 (2585/2603), captures 20, wins 51
  - control: K/D 1.0070 (2607/2589), captures 29, wins 59
- rationale: The half-angle the bot believes the spray can covers. It is a model of an engine number rather than a copy of one, it has never been checked, and it decides both when to fire the cone weapon and how much of the arc counts as covered. An under- estimate wastes the weapon's whole advantage.

## plasmahalf14-reverse — REJECT (local A/B)

- when: 2026-07-31T22:55:53+00:00
- change: `PlasmaHalfBrads` -> `6`
- treatment: local build  control: `jordan-ctf-candidate:v113` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-plasmahalf14-reverse.jsonl, seeds 430000-430059 both ways, seeds 430200-430339 both ways)
- verdict: level: K/D +0.0062 CI [-0.0078, +0.0202], win rate +0.005 CI [-0.048, +0.058], captures -3 CI [-19, +13], n=400
- pooled: 400 episodes, 0 skipped; RED won 34.0% of episodes
  - treatment: K/D 1.0031 (8693/8666), captures 88, wins 190
  - control: K/D 0.9969 (8662/8689), captures 91, wins 188
- rationale: Derived from plasmahalf14: PlasmaHalfBrads measured worse at 14, so the constant is worth testing in the other direction at 6.

## shoutcap4 — PROMOTE (local A/B)

- when: 2026-07-31T22:59:25+00:00
- change: `ShoutCap` -> `4`
- treatment: local build  control: `jordan-ctf-candidate:v113` (the tree)
- shipped as: `jordan-ctf-candidate:v114`
- measured on: the local simulator, seed-paired mirrors (episodes/exp-shoutcap4.jsonl, seeds 431000-431059 both ways, seeds 431200-431339 both ways)
- verdict: separates positive on the pooled sample: K/D +0.0162 CI [+0.0032, +0.0294], win rate +0.050 CI [+0.000, +0.102], captures +6 CI [-8, +20], n=400
- pooled: 400 episodes, 0 skipped; RED won 30.8% of episodes
  - treatment: K/D 1.0081 (8812/8741), captures 89, wins 205
  - control: K/D 0.9919 (8740/8811), captures 83, wins 185
- rationale: How many heard fixes the bot will hold at once. Eight is one per mate; the peek branch and the pre-aim scorer both walk the whole list every frame and take the best, so a longer list is more chances to be pulled toward the least useful call. AUDIT-SAFE: this changes only what we do with what we hear, never what we emit, so it carries no denial term.

## nadetap60 — REJECT (local A/B)

- when: 2026-07-31T23:00:38+00:00
- change: `NadeTapRange` -> `60.0`
- treatment: local build  control: `jordan-ctf-candidate:v114` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-nadetap60.jsonl, seeds 432000-432059 both ways)
- verdict: level: K/D -0.0191 CI [-0.0755, +0.0379], win rate -0.067 CI [-0.267, +0.125], captures -7 CI [-22, +7], n=120
- pooled: 120 episodes, 0 skipped; RED won 38.3% of episodes
  - treatment: K/D 0.9905 (2606/2631), captures 22, wins 52
  - control: K/D 1.0096 (2639/2614), captures 29, wins 60
- rationale: The range below which the grenade is tapped rather than charged. The grenade family has paid repeatedly (NadeFarmReach twice, corner farming) but the throw's own short end has never been moved, and a tap that is too short means a charged lob at a target close enough to walk away from the blast.

## pushoutmin1800 — REJECT (local A/B)

- when: 2026-07-31T23:01:51+00:00
- change: `PushOutMinGame` -> `1800`
- treatment: local build  control: `jordan-ctf-candidate:v114` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-pushoutmin1800.jsonl, seeds 433000-433059 both ways)
- verdict: level: K/D +0.0107 CI [-0.0168, +0.0387], win rate +0.042 CI [-0.092, +0.175], captures +3 CI [-8, +14], n=120
- pooled: 120 episodes, 0 skipped; RED won 34.2% of episodes
  - treatment: K/D 1.0053 (2631/2617), captures 30, wins 57
  - control: K/D 0.9947 (2624/2638), captures 27, wins 52
- rationale: The earliest tick the posts may break for a capture push. Its sibling PushOutTicks (the duration) was swept this session and holdlinedepth160 promoted on the same family, so the trigger's timing is the part of this mechanism nobody has asked about.

## stepcost4 — REJECT (local A/B)

- when: 2026-07-31T23:04:50+00:00
- change: `StepCost` -> `4`
- treatment: local build  control: `jordan-ctf-candidate:v114` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-stepcost4.jsonl, seeds 434000-434059 both ways, seeds 434200-434339 both ways)
- verdict: level: K/D +0.0048 CI [-0.0203, +0.0292], win rate +0.037 CI [-0.052, +0.128], captures -11 CI [-37, +15], n=400
- pooled: 400 episodes, 0 skipped; RED won 57.8% of episodes
  - treatment: K/D 1.0024 (8665/8644), captures 80, wins 196
  - control: K/D 0.9976 (8837/8858), captures 91, wins 181
- rationale: The cost field's orthogonal step against its diagonal 7. diagcost8 has just been measured from the other side of the same ratio, so this asks the same question with the other term -- and unlike DiagCost it also changes the field's absolute scale against ExposedCost 22, which is the term that prices watched ground.

## shieldsteal240 — REJECT (local A/B)

- when: 2026-07-31T23:06:17+00:00
- change: `ShieldStealDetour` -> `240.0`
- treatment: local build  control: `jordan-ctf-candidate:v114` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-shieldsteal240.jsonl, seeds 435000-435059 both ways)
- verdict: wins separate NEGATIVE: K/D -0.0594 CI [-0.0973, -0.0205], win rate -0.208 CI [-0.367, -0.050], captures -4 CI [-18, +9], n=120
- pooled: 120 episodes, 0 skipped; RED won 42.5% of episodes
  - treatment: K/D 0.9709 (2600/2678), captures 23, wins 43
  - control: K/D 1.0303 (2655/2577), captures 27, wins 68
- rationale: objective.nim:206 scores `dist(me,S) + dist(S,T) - dist(me,T)` against ShieldStealDetour, and by the triangle inequality that cost can never exceed `2*dist(S,T)`. sense.nim seeds the enemy shield at (MapW-50, 3*MapH/4) = (1185,494) and f.stealTarget is always flagHome(enemy) = (1049,329), so dist(S,T) = 213.8 px, the gate's ceiling is 427.6, and 480 cannot bind -- which is why `shieldsteal700` came back bit-identical and why the comment's '~270 path px against a 480 budget' misprices the trip. MidGuard therefore takes the endzone trip unconditionally whenever a shield is believed stocked; the cost runs 363-428 anywhere on its approach from our half, so 240 is the first value that actually binds and leaves the trip alive only as an opportunistic grab within roughly 150 px of the spot. Stated plainly: this is close to an ablation, which is the only informative direction left on a gate that cannot bind upward. If it reads level the family closes -- `shieldflank` (-0.0147) and `midguard-shield-not-during-escort` (-0.0085) already read level from the other two sides -- and if it pays we recover one seat's tempo plus its engage cap, which engage.nim:50 clamps to CarrierFireRange 180 for as long as the shield is held.

## shieldsteal240-reverse — REJECT (local A/B)

- when: 2026-07-31T23:07:35+00:00
- change: `ShieldStealDetour` -> `720.0`
- treatment: local build  control: `jordan-ctf-candidate:v114` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-shieldsteal240-reverse.jsonl, seeds 436000-436059 both ways)
- verdict: level: K/D +0.0000 CI [+0.0000, +0.0000], win rate +0.000 CI [+0.000, +0.000], captures +0 CI [+0, +0], n=120
- pooled: 120 episodes, 0 skipped; RED won 30.0% of episodes
  - treatment: K/D 1.0000 (2626/2626), captures 25, wins 55
  - control: K/D 1.0000 (2626/2626), captures 25, wins 55
- rationale: Derived from shieldsteal240: ShieldStealDetour measured worse at 240.0, so the constant is worth testing in the other direction at 720.

## covershield20 — REJECT (local A/B)

- when: 2026-07-31T23:08:52+00:00
- change: `CoverShieldDist` -> `20.0`
- treatment: local build  control: `jordan-ctf-candidate:v114` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-covershield20.jsonl, seeds 437000-437059 both ways)
- verdict: level: K/D +0.0000 CI [+0.0000, +0.0000], win rate +0.000 CI [+0.000, +0.000], captures +0 CI [+0, +0], n=120
- pooled: 120 episodes, 0 skipped; RED won 33.3% of episodes
  - treatment: K/D 1.0000 (2597/2597), captures 28, wins 55
  - control: K/D 1.0000 (2597/2597), captures 28, wins 55
- rationale: posts.nim:128 drops a cover cell from the post candidate pool unless a coarse ray CoverShieldDist px forward runs into something, so a bigger value admits MORE cells -- and `covershield64` (42 -> 64) was bit-identical, proving the extra candidates never once outscored the incumbent and that the gate cannot bind upward. Downward is the only measurement this constant can still produce: at 20 the test demands a wall within 20 px and starts EXCLUDING cells that are currently winning, which is the only way to find out whether the chosen post is shielded by a real obstacle or merely by something 40 px away. The leverage is unusually wide for one constant because scanPost is shared -- pickPost sets the Overwatch hold/peek pair and findEnemyPosts runs the same scan mirrored into enemyPosts, which feeds exposureStatic, the cost field all eight seats route on. Cover cells are walkable cells with a footprint-blocked neighbour 8 px away and PlayerHalf is 6, so a frontally-covered cell has wall pixels within ~14 px of its centre and the pool should tighten rather than empty. Honest risk, stated up front: this family punishes carelessly (`chokehold-oneway` -0.0612 K/D, `post-vision-shield` -24 captures), and if the set does empty on one side postReady goes false and the seat falls back to CenterX + homeSign*70, which is a different experiment than the one intended.

## preaimexact90 — REJECT (local A/B)

- when: 2026-07-31T23:10:06+00:00
- change: `PreAimExactBonus` -> `90.0`
- treatment: local build  control: `jordan-ctf-candidate:v114` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-preaimexact90.jsonl, seeds 438000-438059 both ways)
- verdict: level: K/D -0.0047 CI [-0.0360, +0.0263], win rate -0.033 CI [-0.158, +0.083], captures +0 CI [-9, +9], n=120
- pooled: 120 episodes, 0 skipped; RED won 35.8% of episodes
  - treatment: K/D 0.9977 (2577/2583), captures 28, wins 56
  - control: K/D 1.0023 (2578/2572), captures 28, wins 60
- rationale: `s.exact` is set in exactly one place (perception.nim hearShots) and needs two things at once: the 901-candidate clock calibration must lock (SonarCalMinRings = 30 rings with exactly one surviving offset inside -700..200) and then the 41x41 preimage search must return exactly one landing for that ring. Both are unmeasured -- bot.tick counts packets since the Bot object was built and resetTransient never clears it, so whether the true offset even lies inside the search window is an assumption, and the code says an emptied candidate list never locks and never recovers. If it never locks, PreAimExactBonus and SonarExactRadius are both dead and so is the whole ring- solving subsystem; the ledger's only statement on the matter ('succeeds on a minority of rings', in sonar-hot-radius-54's rationale) is an assertion, not a reading, and that experiment moved the OTHER radius. tactics.nim:120 is the highest-frequency consumer -- every seat, every frame with no engage target -- so a bit-identical result is strong evidence of deadness (not proof: the flag could fire and never flip the argmin), and a non-zero one measures a term nobody has swept. 90 prices a pinned landing level with PreAimHotBonus, the neighbouring value.

## weaveamp30 — REJECT (local A/B)

- when: 2026-07-31T23:14:54+00:00
- change: `baseline/act.nim`: `steer = norm(steer) + side * 0.6` -> `steer = norm(steer) + side * 0.3`
- treatment: local build  control: `jordan-ctf-candidate:v114` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-weaveamp30.jsonl, seeds 439000-439059 both ways, seeds 439200-439339 both ways, seeds 439400-439499 both ways)
- verdict: level: K/D +0.0122 CI [-0.0093, +0.0338], win rate -0.013 CI [-0.092, +0.063], captures +53 CI [+21, +85], n=600
- pooled: 600 episodes, 0 skipped; RED won 39.3% of episodes
  - treatment: K/D 1.0061 (13293/13213), captures 157, wins 277
  - control: K/D 0.9939 (12974/13054), captures 104, wins 285
- rationale: The weave's AMPLITUDE is the one term in `steer = norm(steer) + side * 0.6` never moved, while the tree has been paid twice for cutting the weave's SCOPE in the same direction (WeaveBand 160 -> 40, +0.0900; 400 separated -0.0544) and paid -0.1213 for widening its trigger, `UnderFireTrackTtl`, whose only consumer is this branch. At 0.6 against a unit steer the deflection is 31 degrees into octantBits' 45-degree bins, so the d-pad lands one octant off the routed heading on roughly two weaving ticks in three; at 0.3 (16.7 degrees) that falls to about one in three, and under ExposedCost 22 (+0.0937, with both 30 and 6 separating negative) each of those is a step off the exposure-priced route. `side` is built from the PRE-normalised steer (`var side = vec(-steer.y, steer.x)`), so its length rides the mate-repulsion sum and matespacing20-reverse-further (80.0, +0.0907) silently enlarged this amplitude as a side effect nobody measured. Halving keeps the weave and its per-seat 8-tick phase, so the branch fires on exactly the same frames: every rushing seat inside WeaveBand 40 of mid, and every seat with a <=16-tick clear-ray track at 100-400px. Risk: being a patch, a null teaches nothing about a larger or smaller amplitude, and if the evasion value IS the octant flip, damping it removes what the surviving band was kept for.

## jinkstrafe15 — REJECT (local A/B)

- when: 2026-07-31T23:19:38+00:00
- change: `baseline/act.nim`: `f.moveMask = octantBits(side + away * 0.4)` -> `f.moveMask = octantBits(side + away * 0.15)`
- treatment: local build  control: `jordan-ctf-candidate:v114` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-jinkstrafe15.jsonl, seeds 440000-440059 both ways, seeds 440200-440339 both ways, seeds 440400-440499 both ways)
- verdict: level: K/D +0.0027 CI [-0.0174, +0.0226], win rate +0.017 CI [-0.058, +0.092], captures -6 CI [-39, +27], n=600
- pooled: 600 episodes, 0 skipped; RED won 43.5% of episodes
  - treatment: K/D 1.0014 (13111/13093), captures 135, wins 287
  - control: K/D 0.9986 (13075/13093), captures 141, wins 277
- rationale: threatrange120-reverse promoted ThreatRange to 280 (+0.0519; 360 separated negative, 200 level), so chooseMovement's first branch claims the whole frame for any facing enemy inside its widest measured-optimal radius -- yet the literal deciding what the feet do inside it has never moved. `side` and `away` are both unit vectors, so `side + away * 0.4` sits 21.8 degrees off pure lateral against octantBits' 22.5-degree bin edge: on roughly half of all threat bearings the retreat term costs a full 45-degree bin (70.7% of the lateral rate) and on the other half it does nothing at all. The engine locks the fire angle at the pull and resolves the shot five ticks later against the moved body, so perpendicular displacement is what leaves the ~14px corridor while the radial component is nearly free to the shooter; at 0.15 (8.5 degrees) the bin flips on ~19% of bearings instead of ~48%, and the sidestep matches the 24px clear-ray test the branch already runs on `side` alone. Same discipline as steer-dither-quarter, which shrank rather than deleted a perturbation and measured +0.1018. Risk: the seats that land here are largely the ones that cannot shoot back (rushers on cooldown, targets beyond maxEngage), so a bot that stops giving ground holds contact longer than it wants to, and a patch null says nothing about a larger or smaller weight.

## matefresh36 — REJECT (local A/B)

- when: 2026-07-31T23:20:53+00:00
- change: `baseline/act.nim`: `if bot.tick - t.lastSeen > 12:` -> `if bot.tick - t.lastSeen > 36:`
- treatment: local build  control: `jordan-ctf-candidate:v114` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-matefresh36.jsonl, seeds 441000-441059 both ways)
- verdict: level: K/D -0.0299 CI [-0.0768, +0.0161], win rate -0.075 CI [-0.233, +0.075], captures +7 CI [-7, +20], n=120
- pooled: 120 episodes, 0 skipped; RED won 55.0% of episodes
  - treatment: K/D 0.9852 (2593/2632), captures 30, wins 53
  - control: K/D 1.0150 (2632/2593), captures 23, wins 62
- rationale: The constant deciding WHICH mates enter the repulsion is a bare 12-tick literal in the same loop MateSpacing was walked up (40 -> 60 -> 80, +0.0907; 100 rejected twice), and it is a different axis from that magnitude -- a gain change would only re-measure a point between two known results. Teammates are fogged and the vision cone rides the aim, so the mate this seat is blindest to is often the one right beside it: exactly the body the repulsion exists to keep out of one burst's (or our own shot's) corridor. The tree already holds a precedent for the same judgement one module over -- `friendlyBlocked` (tactics.nim:212) weighs mates up to 36 ticks old and widens its corridor by `age * 0.35` rather than dropping them -- and mate tracks live to TrackHoldTtl 400, so the 12-36 band is fully populated. Fires on every navigate tick with a remembered mate inside MateSpacing 80, which after matespacing80 is most of the formation most of the time. The honest risk is the strongest counter-prior in this batch: `updateTracks` does not extrapolate an unseen track, so a 36-tick position is up to ~100px stale, each spurious push is up to ~40 degrees of heading perturbation into the octant quantizer that steer-dither-quarter was paid +0.1018 to stop perturbing by 9.7, and it enlarges the same repulsion sum whose last enlargement (MateSpacing 100) measured -0.1000.

## peek-fix-costed — REJECT (local A/B)

- when: 2026-07-31T23:21:57+00:00
- change: `baseline/engage.nim`: `let d = dist(x.pos, f.me)
      if d >= f.blockedD:` -> `let d = dist(x.pos, f.me) + PreAimShoutCost
      if d >= f.blockedD:`
- treatment: local build  control: `jordan-ctf-candidate:v114` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-peek-fix-costed.jsonl, seeds 442000-442059 both ways)
- verdict: wins separate NEGATIVE: K/D -0.0967 CI [-0.1460, -0.0472], win rate -0.317 CI [-0.475, -0.158], captures -23 CI [-36, -10], n=120
- pooled: 120 episodes, 0 skipped; RED won 40.8% of episodes
  - treatment: K/D 0.9526 (2535/2661), captures 14, wins 36
  - control: K/D 1.0493 (2680/2554), captures 37, wins 74
- rationale: shout-peek (+0.164, the largest promotion on record) works by letting a heard fix become the blocked peek candidate, but the loop that does it (engage.nim:129-139) compares that fix to our OWN blocked sighting on raw distance: a 32px cell, seen through another seat's eyes, off a bubble up to 72 ticks old, wins whenever it is one pixel nearer than a track we saw ourselves within FreshShotTicks = 24. Everywhere else the tree prices second-hand evidence -- PreAimShoutCost 100px against a sighting, PreAimPingCost 120px against a landing -- and this gives the peek scorer the same price, reusing the tuned constant so no new number enters; blockedD is compared only inside engage.nim and act.nim reads blockedAim alone, so storing an effective distance is safe. The peek branch MOVES THE FEET, which is where this tree's regressions have come from, so acting on the weaker of two available candidates is exactly the failure this tests for, and it fires whenever a fresh blocked track and a live fix are both in play. Two honest notes: because f.blockedD starts at f.maxEngage the cost also trims 100px off the range at which a fix alone can raise a peek (the pre-aim scorer gates on raw distance and prices only its score), and sweeping this same constant in the pre-aim consumer read level in both directions, so the prior is that pricing is a weak axis -- in a different consumer. Emission-neutral: nothing about what we broadcast changes, so no eavesdrop-off audit is owed.

## preaimhot140 — REJECT (local A/B)

- when: 2026-07-31T23:24:52+00:00
- change: `PreAimHotBonus` -> `140.0`
- treatment: local build  control: `jordan-ctf-candidate:v114` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-preaimhot140.jsonl, seeds 443000-443059 both ways)
- verdict: wins separate NEGATIVE: K/D -0.0205 CI [-0.0407, -0.0023], win rate -0.092 CI [-0.183, -0.008], captures -6 CI [-13, +0], n=120 | endings: wipe 59%, capture 40%, timeout 1%
- endings: wipe 59%, capture 40%, timeout 1%
- pooled: 120 episodes, 0 skipped; RED won 42.5% of episodes
  - treatment: K/D 0.9898 (2620/2647), captures 21, wins 54
  - control: K/D 1.0103 (2650/2623), captures 27, wins 65
- rationale: The discount a landing gets in the pre-aim scorer for having coincided with one of OUR deaths. 90px against PreAimPingCost's 120 means a hot landing is worth nearly a sighting, and the pairing that produces the hot flag -- a scoreboard delta matched to an unclaimed ring -- is the same machinery corpse-track- cleanup promoted on. Never moved. Its sibling PreAimExactBonus is queued this round, so the pair gets asked together.

## preaimhot140-reverse — REJECT (local A/B)

- when: 2026-07-31T23:26:04+00:00
- change: `PreAimHotBonus` -> `40.0`
- treatment: local build  control: `jordan-ctf-candidate:v114` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-preaimhot140-reverse.jsonl, seeds 444000-444059 both ways)
- verdict: level: K/D +0.0083 CI [-0.0128, +0.0316], win rate +0.008 CI [-0.058, +0.075], captures +0 CI [-7, +6], n=120 | endings: wipe 59%, capture 35%, timeout 6%
- endings: wipe 59%, capture 35%, timeout 6%
- pooled: 120 episodes, 0 skipped; RED won 35.8% of episodes
  - treatment: K/D 1.0042 (2647/2636), captures 21, wins 56
  - control: K/D 0.9958 (2636/2647), captures 21, wins 55
- rationale: Derived from preaimhot140: PreAimHotBonus measured worse at 140.0, so the constant is worth testing in the other direction at 40.

## sonarcap12 — REJECT (local A/B)

- when: 2026-07-31T23:27:13+00:00
- change: `SonarCap` -> `12`
- treatment: local build  control: `jordan-ctf-candidate:v114` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-sonarcap12.jsonl, seeds 445000-445059 both ways)
- verdict: level: K/D +0.0023 CI [-0.0224, +0.0277], win rate +0.042 CI [-0.067, +0.150], captures +5 CI [-4, +15], n=120 | endings: wipe 55%, capture 41%, timeout 4%
- endings: wipe 55%, capture 41%, timeout 4%
- pooled: 120 episodes, 0 skipped; RED won 37.5% of episodes
  - treatment: K/D 1.0012 (2606/2603), captures 27, wins 60
  - control: K/D 0.9989 (2607/2610), captures 22, wins 55
- rationale: How many heard landings the bot keeps. 24 against a server that sends at most 16 at once means the list is never actually pruned by this cap, only by SonarTtl -- so this is a second, looser gate on the same memory that shoutcap4 just paid for tightening on the shout side (+0.016 K/D). The consumers walk the whole list every frame and take the best.

## nademate80 — REJECT (local A/B)

- when: 2026-07-31T23:28:22+00:00
- change: `NadeMateTtl` -> `80`
- treatment: local build  control: `jordan-ctf-candidate:v114` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-nademate80.jsonl, seeds 446000-446059 both ways)
- verdict: level: K/D -0.0384 CI [-0.0839, +0.0069], win rate -0.092 CI [-0.242, +0.058], captures -3 CI [-16, +10], n=120 | endings: wipe 51%, capture 42%, timeout 7%
- endings: wipe 51%, capture 42%, timeout 7%
- pooled: 120 episodes, 0 skipped; RED won 34.2% of episodes
  - treatment: K/D 0.9810 (2582/2632), captures 24, wins 50
  - control: K/D 1.0194 (2623/2573), captures 27, wins 61
- rationale: How long a remembered teammate still blocks a grenade throw. 150 ticks is over six seconds -- a teammate who was there six seconds ago is not evidence about now, and the same staleness argument has now paid three times (corpse-track-cleanup, exposurettl30-reverse, shoutcap4). The risk is the obvious one and is why this is a real experiment rather than a cleanup: the thing being forgotten is a mate we might blow up.

## nademate80-reverse — REJECT (local A/B)

- when: 2026-07-31T23:29:34+00:00
- change: `NadeMateTtl` -> `220`
- treatment: local build  control: `jordan-ctf-candidate:v114` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-nademate80-reverse.jsonl, seeds 447000-447059 both ways)
- verdict: level: K/D -0.0229 CI [-0.0696, +0.0229], win rate -0.050 CI [-0.200, +0.100], captures -6 CI [-18, +6], n=120 | endings: wipe 50%, capture 48%, timeout 2%
- endings: wipe 50%, capture 48%, timeout 2%
- pooled: 120 episodes, 0 skipped; RED won 44.2% of episodes
  - treatment: K/D 0.9886 (2599/2629), captures 26, wins 56
  - control: K/D 1.0115 (2641/2611), captures 32, wins 62
- rationale: Derived from nademate80: NadeMateTtl measured worse at 80, so the constant is worth testing in the other direction at 220.

## nademindrift — REJECT (local A/B)

- when: 2026-07-31T23:34:28+00:00
- change: `NadeMateDrift` -> `0.2`
- treatment: local build  control: `jordan-ctf-candidate:v114` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-nademindrift.jsonl, seeds 448000-448059 both ways, seeds 448200-448339 both ways, seeds 448400-448499 both ways)
- verdict: level: K/D +0.0107 CI [-0.0040, +0.0256], win rate +0.017 CI [-0.042, +0.077], captures -9 CI [-34, +16], n=600 | endings: wipe 52%, capture 44%, timeout 4%
- endings: wipe 52%, capture 44%, timeout 4%
- pooled: 600 episodes, 0 skipped; RED won 36.5% of episodes
  - treatment: K/D 1.0054 (13135/13065), captures 128, wins 292
  - control: K/D 0.9947 (13032/13102), captures 137, wins 282
- rationale: How far a remembered teammate is assumed to have drifted since we saw them, which widens the no-throw region around them. 0.45 px/tick against a 2.75 px/tick top speed is a middling guess nobody has checked, and it multiplies against NadeMateTtl -- at 150 ticks it inflates the exclusion by 67 px.

## ownnadering40 — REJECT (local A/B)

- when: 2026-07-31T23:35:36+00:00
- change: `OwnNadeRingSlack` -> `40.0`
- treatment: local build  control: `jordan-ctf-candidate:v114` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-ownnadering40.jsonl, seeds 449000-449059 both ways)
- verdict: level: K/D +0.0000 CI [-0.0023, +0.0023], win rate +0.000 CI [+0.000, +0.000], captures +0 CI [-3, +3], n=120 | endings: wipe 57%, capture 40%, timeout 3%
- endings: wipe 57%, capture 40%, timeout 3%
- pooled: 120 episodes, 0 skipped; RED won 38.3% of episodes
  - treatment: K/D 1.0000 (2620/2620), captures 24, wins 58
  - control: K/D 1.0000 (2620/2620), captures 24, wins 58
- rationale: How near a throw-target ring has to be to our predicted own landing point before we treat it as OURS and stop fleeing it. Too tight and the bot sprints away from its own grenade; too loose and it stands in somebody else's. The prediction it is matched against is itself a model, so the slack is doing real work and has never been moved.

## trackcap5 — PROMOTE (local A/B)

- when: 2026-07-31T23:39:06+00:00
- change: `TrackCap` -> `5`
- treatment: local build  control: `jordan-ctf-candidate:v114` (the tree)
- shipped as: `jordan-ctf-candidate:v115`
- measured on: the local simulator, seed-paired mirrors (episodes/exp-trackcap5.jsonl, seeds 450000-450059 both ways, seeds 450200-450339 both ways)
- verdict: separates positive on the pooled sample: K/D +0.0691 CI [+0.0428, +0.0949], win rate +0.195 CI [+0.102, +0.287], captures +9 CI [-17, +35], n=400 | endings: wipe 52%, capture 42%, timeout 6%
- endings: wipe 52%, capture 42%, timeout 6%
- pooled: 400 episodes, 0 skipped; RED won 42.0% of episodes
  - treatment: K/D 1.0352 (8860/8559), captures 89, wins 228
  - control: K/D 0.9661 (8567/8868), captures 80, wins 150
- rationale: How many remembered enemies the bot carries. Eight is one per opponent, but the list is sorted freshest-first and every consumer walks all of it -- the exposure field takes the freshest three, the pre-aim scorer takes the best, the grenade planner offers each one. shoutcap4 just showed that a shorter list of the same kind of evidence beats a longer one.

## trackcap5-further — REJECT (local A/B)

- when: 2026-07-31T23:42:15+00:00
- change: `TrackCap` -> `2`
- treatment: local build  control: `jordan-ctf-candidate:v115` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-trackcap5-further.jsonl, seeds 451000-451059 both ways, seeds 451200-451339 both ways)
- verdict: level: K/D -0.0072 CI [-0.0339, +0.0200], win rate +0.033 CI [-0.062, +0.128], captures +4 CI [-20, +28], n=400 | endings: wipe 54%, capture 42%, timeout 5%
- endings: wipe 54%, capture 42%, timeout 5%
- pooled: 400 episodes, 0 skipped; RED won 49.8% of episodes
  - treatment: K/D 0.9964 (8539/8570), captures 85, wins 197
  - control: K/D 1.0035 (8792/8761), captures 81, wins 184
- rationale: Derived from trackcap5: TrackCap paid at 5, so walk the same way again to 2 and find where it stops paying.

## trackcap5-further-reverse — REJECT (local A/B)

- when: 2026-07-31T23:43:30+00:00
- change: `TrackCap` -> `8`
- treatment: local build  control: `jordan-ctf-candidate:v115` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-trackcap5-further-reverse.jsonl, seeds 452000-452059 both ways)
- verdict: REGRESSION: K/D -0.0657 CI [-0.1154, -0.0169], win rate -0.108 CI [-0.267, +0.058], captures -4 CI [-17, +10], n=120 | endings: wipe 48%, capture 45%, timeout 8%
- endings: wipe 48%, capture 45%, timeout 8%
- pooled: 120 episodes, 0 skipped; RED won 40.0% of episodes
  - treatment: K/D 0.9677 (2547/2632), captures 25, wins 49
  - control: K/D 1.0334 (2627/2542), captures 29, wins 62
- rationale: Derived from trackcap5-further: TrackCap measured worse at 2, so the constant is worth testing in the other direction at 8.

## trackhold200b — REJECT (local A/B)

- when: 2026-07-31T23:45:35+00:00
- change: `TrackHoldTtl` -> `200`
- treatment: local build  control: `jordan-ctf-candidate:v115` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-trackhold200b.jsonl, seeds 453000-453059 both ways)
- verdict: level: K/D -0.0056 CI [-0.0478, +0.0376], win rate +0.017 CI [-0.133, +0.167], captures +13 CI [-1, +27], n=120 | endings: capture 51%, wipe 41%, timeout 8%
- endings: capture 51%, wipe 41%, timeout 8%
- pooled: 120 episodes, 0 skipped; RED won 60.0% of episodes
  - treatment: K/D 0.9972 (2513/2520), captures 37, wins 56
  - control: K/D 1.0028 (2512/2505), captures 24, wins 54
- rationale: How long a lost enemy stays in memory at all -- the root of the whole shorter-memory family, and the one term of it never successfully moved. trackcap5 has just promoted at +0.0691 K/D by carrying FEWER remembered enemies, shoutcap4 at +0.0162 by carrying fewer heard fixes, exposurettl30-reverse and corpse- track-cleanup by discarding stale ones sooner. `trackhold200` was tried once and rejected on captures under a tree six months of experiments older than this one, before any of those four results existed; the axis it names is now the best-supported direction in the record.

## exposurethreats2 — PROMOTE (local A/B)

- when: 2026-07-31T23:48:39+00:00
- change: `ExposureThreats` -> `2`
- treatment: local build  control: `jordan-ctf-candidate:v115` (the tree)
- shipped as: `jordan-ctf-candidate:v116`
- measured on: the local simulator, seed-paired mirrors (episodes/exp-exposurethreats2.jsonl, seeds 454000-454059 both ways, seeds 454200-454339 both ways)
- verdict: separates positive on the pooled sample: K/D +0.0543 CI [+0.0274, +0.0821], win rate +0.117 CI [+0.022, +0.210], captures +52 CI [+25, +79], n=400 | endings: wipe 49%, capture 48%, timeout 3%
- endings: wipe 49%, capture 48%, timeout 3%
- pooled: 400 episodes, 0 skipped; RED won 43.8% of episodes
  - treatment: K/D 1.0272 (8829/8595), captures 121, wins 217
  - control: K/D 0.9729 (8405/8639), captures 69, wins 170
- rationale: How many remembered enemies wall off ground in the routing field. Three was chosen when tracks were the only intel the bot had; the same cap-tightening argument has now paid twice on the two neighbouring caps (trackcap5 +0.069, shoutcap4 +0.016), and exposurettl30-reverse paid on this very field's freshness. exposurethreats5 -- the loosening direction -- was tried and is decided.

## exposurethreats2-further — PROMOTE (local A/B)

- when: 2026-07-31T23:51:39+00:00
- change: `ExposureThreats` -> `1`
- treatment: local build  control: `jordan-ctf-candidate:v116` (the tree)
- shipped as: `jordan-ctf-candidate:v117`
- measured on: the local simulator, seed-paired mirrors (episodes/exp-exposurethreats2-further.jsonl, seeds 455000-455059 both ways, seeds 455200-455339 both ways)
- verdict: separates positive on the pooled sample: K/D +0.0576 CI [+0.0294, +0.0850], win rate +0.190 CI [+0.102, +0.275], captures +43 CI [+14, +71], n=400 | endings: capture 51%, wipe 45%, timeout 4%
- endings: capture 51%, wipe 45%, timeout 4%
- pooled: 400 episodes, 0 skipped; RED won 58.2% of episodes
  - treatment: K/D 1.0291 (8515/8274), captures 124, wins 230
  - control: K/D 0.9715 (8230/8471), captures 81, wins 154
- rationale: Derived from exposurethreats2: ExposureThreats paid at 2, so walk the same way again to 1 and find where it stops paying.

## sonarhotttl12 — REJECT (local A/B)

- when: 2026-07-31T23:52:40+00:00
- change: `SonarHotTtl` -> `12`
- treatment: local build  control: `jordan-ctf-candidate:v117` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-sonarhotttl12.jsonl, seeds 456000-456059 both ways)
- verdict: level: K/D -0.0008 CI [-0.0239, +0.0222], win rate +0.000 CI [-0.075, +0.075], captures -3 CI [-9, +3], n=120 | endings: capture 49%, wipe 38%, timeout 13%
- endings: capture 49%, wipe 38%, timeout 13%
- pooled: 120 episodes, 0 skipped; RED won 65.8% of episodes
  - treatment: K/D 0.9996 (2453/2454), captures 28, wins 52
  - control: K/D 1.0004 (2455/2454), captures 31, wins 52
- rationale: How fresh a landing must be to be tied to a death by the scoreboard delta. This is the pairing that produces the `hot` and `foe` flags, and therefore the exposure marks and the grenade targets downstream. 20 ticks is nearly a second of slack on an inference that wants to be tight -- and preaimhot140, which made the hot flag MATTER more, separated negative, which is evidence the flag is being set too generously rather than priced too cheaply.

## sonarhotttl12-reverse — REJECT (local A/B)

- when: 2026-08-02T22:59:59+00:00
- change: `SonarHotTtl` -> `28`
- treatment: local build  control: `jordan-ctf-candidate:v117` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-sonarhotttl12-reverse.jsonl, seeds 457000-457059 both ways)
- verdict: level: K/D +0.0084 CI [-0.0066, +0.0242], win rate -0.008 CI [-0.050, +0.042], captures -1 CI [-7, +6], n=120 | endings: capture 64%, wipe 30%, timeout 6%
- endings: capture 64%, wipe 30%, timeout 6%
- pooled: 120 episodes, 0 skipped; RED won 83.3% of episodes
  - treatment: K/D 1.0042 (2392/2382), captures 38, wins 56
  - control: K/D 0.9958 (2388/2398), captures 39, wins 57
- rationale: Derived from sonarhotttl12: SonarHotTtl measured worse at 12, so the constant is worth testing in the other direction at 28.

## badgeslack8 — REJECT (local A/B)

- when: 2026-08-02T23:02:14+00:00
- change: `BadgeAnchorSlack` -> `8.0`
- treatment: local build  control: `jordan-ctf-candidate:v117` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-badgeslack8.jsonl, seeds 458000-458059 both ways)
- verdict: level: K/D +0.0000 CI [+0.0000, +0.0000], win rate +0.000 CI [+0.000, +0.000], captures +0 CI [+0, +0], n=120 | endings: wipe 48%, capture 47%, timeout 5%
- endings: wipe 48%, capture 47%, timeout 5%
- pooled: 120 episodes, 0 skipped; RED won 78.3% of episodes
  - treatment: K/D 1.0000 (2471/2471), captures 28, wins 57
  - control: K/D 1.0000 (2471/2471), captures 28, wins 57
- rationale: How far an identity badge may sit from a body centre and still be matched to it. The badge is the only thing that names WHICH enemy a sighting is, and memory.nim matches by name before proximity precisely because a wrong match inverts the velocity we lead shots with. 4px on sprites whose anchors the engine computes to the pixel is either exactly right or needlessly tight; nobody has checked which.

## hppip5 — REJECT (local A/B)

- when: 2026-08-02T23:04:37+00:00
- change: `HpPipAnchorSlack` -> `5.0`
- treatment: local build  control: `jordan-ctf-candidate:v117` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-hppip5.jsonl, seeds 459000-459059 both ways)
- verdict: level: K/D +0.0000 CI [+0.0000, +0.0000], win rate +0.000 CI [+0.000, +0.000], captures +0 CI [+0, +0], n=120 | endings: wipe 52%, capture 43%, timeout 5%
- endings: wipe 52%, capture 43%, timeout 5%
- pooled: 120 episodes, 0 skipped; RED won 81.7% of episodes
  - treatment: K/D 1.0000 (2513/2513), captures 26, wins 57
  - control: K/D 1.0000 (2513/2513), captures 26, wins 57
- rationale: The same question for the overhead health bar, which is how the bot reads an enemy's hit points -- the input to HpFocusBonus, the finish-the-wounded term. A bar matched to the wrong body reports the wrong hp for both. Never moved.

## nademin96 — REJECT (local A/B)

- when: 2026-08-02T23:13:18+00:00
- change: `NadeMinRange` -> `96.0`
- treatment: local build  control: `jordan-ctf-candidate:v117` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-nademin96.jsonl, seeds 460000-460059 both ways, seeds 460200-460339 both ways)
- verdict: level: K/D -0.0101 CI [-0.0266, +0.0061], win rate +0.005 CI [-0.055, +0.065], captures -7 CI [-26, +11], n=400 | endings: capture 63%, wipe 33%, timeout 4%
- endings: capture 63%, wipe 33%, timeout 4%
- pooled: 400 episodes, 0 skipped; RED won 74.8% of episodes
  - treatment: K/D 0.9950 (8105/8146), captures 122, wins 192
  - control: K/D 1.0051 (8157/8116), captures 129, wins 190
- rationale: The floor on how close the bot will lob, and the only term protecting it from its own grenade. GV17 grew the blast radius 40 -> 52 and this floor did not move with it: the margin over the blast fell from 32px to 20px, before drift, on a throw whose landing point is a prediction. The constant gates both the throw (grenades.nim) and the flee-your-own-blast test (tactics.nim), so it is one variable in the source and one question -- is 72 still a floor, or is it now inside the blast?

## nademin96-reverse — REJECT (local A/B)

- when: 2026-08-02T23:15:31+00:00
- change: `NadeMinRange` -> `48.0`
- treatment: local build  control: `jordan-ctf-candidate:v117` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-nademin96-reverse.jsonl, seeds 461000-461059 both ways)
- verdict: level: K/D -0.0083 CI [-0.0326, +0.0195], win rate +0.000 CI [-0.075, +0.075], captures -3 CI [-10, +5], n=120 | endings: capture 58%, wipe 38%, timeout 5%
- endings: capture 58%, wipe 38%, timeout 5%
- pooled: 120 episodes, 0 skipped; RED won 77.5% of episodes
  - treatment: K/D 0.9959 (2408/2418), captures 33, wins 57
  - control: K/D 1.0042 (2419/2409), captures 36, wins 57
- rationale: Derived from nademin96: NadeMinRange measured worse at 96.0, so the constant is worth testing in the other direction at 48.

## preaimping30 — REJECT (local A/B)

- when: 2026-08-02T23:17:46+00:00
- change: `PreAimPingTtl` -> `30`
- treatment: local build  control: `jordan-ctf-candidate:v117` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-preaimping30.jsonl, seeds 462000-462059 both ways)
- verdict: level: K/D +0.0049 CI [-0.0524, +0.0621], win rate +0.017 CI [-0.142, +0.167], captures +7 CI [-9, +23], n=120 | endings: capture 64%, wipe 31%, timeout 5%
- endings: capture 64%, wipe 31%, timeout 5%
- pooled: 120 episodes, 0 skipped; RED won 74.2% of episodes
  - treatment: K/D 1.0025 (2431/2425), captures 42, wins 58
  - control: K/D 0.9975 (2418/2424), captures 35, wins 56
- rationale: How long a heard landing keeps pointing the turret. The last untried term of the pre-aim family, and the family's own record says which way to push it: preaimhot140 -- pricing landings HIGHER -- separated negative, and preaimpingcost80 (pricing them lower) read exactly level. Both are about what a landing is worth; nobody has asked how long it stays worth anything. 60 ticks is 2.5s on evidence that names a bullet rather than a body, against SonarJitterPx 20 of deliberate fuzz.

## combatdeadband3 — REJECT (local A/B)

- when: 2026-08-02T23:20:01+00:00
- change: `CombatDeadband` -> `3`
- treatment: local build  control: `jordan-ctf-candidate:v117` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-combatdeadband3.jsonl, seeds 463000-463059 both ways)
- verdict: level: K/D -0.0188 CI [-0.0725, +0.0342], win rate -0.108 CI [-0.258, +0.050], captures -14 CI [-28, +0], n=120 | endings: capture 48%, wipe 48%, timeout 4%
- endings: capture 48%, wipe 48%, timeout 4%
- pooled: 120 episodes, 0 skipped; RED won 71.7% of episodes
  - treatment: K/D 0.9907 (2437/2460), captures 22, wins 51
  - control: K/D 1.0094 (2460/2437), captures 36, wins 64
- rationale: When the turret stops traversing in combat. Never moved, and it sits on the shortest path to a kill: act.nim gates the trigger on CombatDeadband + 2 and tactics.nim calls the aim laid on inside it. Tighter is not available -- the comment records that AimRate 5 cannot settle inside +-2 -- so 3 is the only ask, and it is a real one: the vision cone rides the aim, so a traverse that stops a brad early stops the cone sweeping too.

## combatdeadband3-reverse — REJECT (local A/B)

- when: 2026-08-02T23:22:18+00:00
- change: `CombatDeadband` -> `1`
- treatment: local build  control: `jordan-ctf-candidate:v117` (the tree)
- measured on: the local simulator, seed-paired mirrors (episodes/exp-combatdeadband3-reverse.jsonl, seeds 464000-464059 both ways)
- verdict: captures separate NEGATIVE: K/D -0.0458 CI [-0.0969, +0.0057], win rate -0.067 CI [-0.233, +0.100], captures -23 CI [-38, -8], n=120 | endings: capture 58%, wipe 38%, timeout 5%
- endings: capture 58%, wipe 38%, timeout 5%
- pooled: 120 episodes, 0 skipped; RED won 66.7% of episodes
  - treatment: K/D 0.9770 (2380/2436), captures 23, wins 53
  - control: K/D 1.0228 (2509/2453), captures 46, wins 61
- rationale: Derived from combatdeadband3: CombatDeadband measured worse at 3, so the constant is worth testing in the other direction at 1.

## The league moved and nobody here noticed: GV30 -> GV35

- when: 2026-08-03T00:20:00+00:00
- what: `sim/engine.pin` was at `1047232f` (coworld `ctf` v0.7.136, GameVersion
  30). The league has been running `63ea0cb7` (v0.7.173, **GameVersion 35**).
  Found by downloading replays: they would not parse at all — *"Replay game
  version does not match"*.
- consequence: every local A/B measured since the pin moved was stepping a game
  the league had stopped playing. `sim/league_config.json` had drifted too —
  the hosted variant now runs `visionConeDeg` **60**, not 45.
- what changed in between, read out of the engine, not the changelog:
  - **GV31** the grenade blast is a BODY test, not a position-point test: the
    on-axis reach is `GrenadeBlastRadius + PlayerHalf` = **58px**, not 52. And
    `PlasmaArcReach` grew from 4 squares to 5: **170px**, not 136.
    (`PlasmaArcMaxWidth` went 2 -> 2.5 squares with it, which leaves the cone
    half-angle at exactly 10 brads — so `PlasmaHalfBrads` is still right.)
  - **GV32** a capture eliminates its team; 2-team play keeps its outcome.
  - **GV33** a dead team's heart leaves play, even off a carrier's back.
  - **GV34** per-shot Gaussian aim jitter, plus a fixed 1050px gun range that
    the league config overrides back to 1300.
  - **GV35** elimination deaths are not combat deaths.
- also new on the wire, and unread by this policy: `game teams`, `endzone`
  (every capture region's corners at episode start) and `own aim`.
- landed in `2a55715`. `sim/engine-patches/perf.patch` is parked, not applied:
  GV35 split `sim.nim` into four modules and it fits nowhere. Speed only.

## What the daveey replays actually say

- when: 2026-08-03T00:40:00+00:00
- corpus: the 17 most recent completed league episodes against daveey
  (`ctf-focusfire:v66`), re-simulated at GV35 with the engine's own
  `tools/extract_events.nim`. Full write-up: `analysis/vs_daveey.md`.
- record: **0-17.** Nine wipes, six captures against us, two tick-limit draws
  (which pay -1, so they are losses in everything but name).
- the shape of it, per 1000 alive-ticks: we land hits at 1.08x their rate and
  kill at 1.04x their rate, and **die at 1.80x**. Our accuracy is materially
  BETTER than theirs (67.2% vs 51.3%).
- where: normalising the attack axis to 0 = own base edge, 1 = enemy's, daveey
  parks all eight seats in a flat band at 0.20-0.23 and stays there (75.5% of
  their alive time is in their own quarter). We spread 0.32-0.48 and **die at
  a median 0.623** — deep in their half, in front of that wall. They kill from
  0.213. Their median steal of our flag lands at tick 4119 of 5000: they do not
  raid, they grind the wave down and then walk in.
- ruled out: engagement range (both sides fight at ~220-260px; 0.9% of our
  shots go past 650px), and therefore GV34's aim jitter, which only bites past
  ~600px — at our median range it is 1.8px of lateral error against a 14px
  acceptance window.
- what it points at: the wave over-commits, and a seed-paired local mirror is
  structurally unable to price that, because it puts this policy against
  itself and never against a team that declines to come out.

## ownaim — REJECT (mechanism check, no episodes bought)

- when: 2026-08-03T00:55:00+00:00
- change: read the engine's `own aim <brads>` marker instead of dead-reckoning
  the turret angle from our own rotate inputs.
- rationale: the engine ships this marker precisely because "bots dead-reckoned
  their own aim open-loop, and the drift measurably cost accuracy"
  (global.nim). `sense.nim` dead-reckons and corrects only with a +-8 brad
  bound off the self sprite's rotation step, so the drift is real if it exists.
- verdict: **the drift does not exist here.** Implemented behind `-d:aimDebug`,
  logging `bradsErr(exact, estAim)` before the bucket correction: one full
  episode, **28122 samples, drift 0 on every single one**. The dead reckoning
  is already exact, so an exact readback cannot buy anything.
- the rule this obeys: verify the mechanism before buying episodes. This one
  cost a build and one episode instead of 160.

## nadeblast58 — REJECT (local A/B)

- when: 2026-08-03T01:05:00+00:00
- change: `NadeBlast` -> `58.0`
- treatment: local build  control: `jordan-ctf-candidate:v117` (the tree)
- measured on: the local simulator at the NEW GV35 pin, seed-paired mirrors
  (episodes/exp-nadeblast58.jsonl, seeds 471000-471029 both ways)
- verdict: level: K/D +0.0168 CI [-0.0423, +0.0779], n=60
- rationale: GV31 made the blast a BODY test — everyone whose solid box
  (+-PlayerHalf) touches the circle takes damage — so the on-axis reach is
  52 + 6 = 58px and the constant has been 6px short ever since. It is read
  three times: how many enemies one lob catches (grenades.nim), whether the
  landing clips US, and whether it clips a MATE (tactics.nim). Note the
  earlier `nadeblast64` measured +0.0127 [-0.0075, +0.0328] at n=600 under
  GV30 — same sign, and 58 is between the two.

## plasmareach170 — REJECT (local A/B)

- when: 2026-08-03T01:05:00+00:00
- change: `PlasmaReach` -> `170.0`
- treatment: local build  control: `jordan-ctf-candidate:v117` (the tree)
- measured on: the local simulator at the NEW GV35 pin, seed-paired mirrors
  (episodes/exp-plasmareach170.jsonl, seeds 472000-472029 both ways)
- verdict: level: K/D +0.0457 CI [-0.0230, +0.1127], n=60
- rationale: GV31 grew `PlasmaArcReach` from 4 squares to 5 — 136 -> 170px —
  and the tree still says 136. It gates both the cone's engage range
  (engage.nim, `PlasmaReach + 6`) and the trigger (act.nim, `PlasmaReach - 6`),
  so a spray carrier has been refusing 34px of reach it actually has. The
  earlier `plasmareach180` and `-reverse` (92) both measured level, but both
  were bought at GV30 where 136 was the TRUTH; this is the first time the
  constant has been asked to match a reach it does not already have.

## preaimarc28gv35 — REJECT (local A/B)

- when: 2026-08-03T01:05:00+00:00
- change: `PreAimArc` -> `28`
- treatment: local build  control: `jordan-ctf-candidate:v117` (the tree)
- measured on: the local simulator at the NEW GV35 pin, seed-paired mirrors
  (episodes/exp-preaimarc28.jsonl, seeds 472000-472029 both ways)
- verdict: K/D separates NEGATIVE: -0.0711 CI [-0.1258, -0.0167], n=60
- rationale: re-asked because the vision cone changed underneath it. The
  constant caps how far off-lane a moving seat will look, and the cone rides
  the aim; at `visionConeDeg` 45 the half-cone was ~16 brads, so a 28-brad
  look went blind to the lane. At 60 the half-cone is ~21, and 28 is the same
  overhang past the edge that 23 used to be. It is still worse, and now with
  a separating interval rather than the old level one — so 20 survives a
  re-ask under the new cone, which is worth more than the original result was.

## fireslack14 — REJECT (local A/B)

- when: 2026-08-03T01:05:00+00:00
- change: `FireSlackPx` -> `14.0`
- treatment: local build  control: `jordan-ctf-candidate:v117` (the tree)
- measured on: the local simulator at the NEW GV35 pin, seed-paired mirrors
  (episodes/exp-fireslack14.jsonl, seeds 472000-472029 both ways)
- verdict: level, leaning negative: K/D -0.0426 CI [-0.1215, +0.0331], n=60
- rationale: the daveey replays say they fire 1.66x as many shots as we do at
  two thirds of our hit rate and come out ahead on hits, which reads as a fire
  gate that is too tight. 14.0 is not an arbitrary loosening: it is exactly
  the engine's own acceptance half-window, `PlayerHalf + BulletHalfWidth`, so
  it is the widest slack that is not simply a miss. The measurement disagrees
  with the reading — accuracy fell 0.683 -> 0.650 and the K/D went with it, so
  the shots the tighter gate declines really are the bad ones. `FireSlackPx`
  is now measured at 11 (tree), 13 (level, GV30) and 14 (level-negative).

## gv31truth — PROMOTE-LOCAL (local A/B)

- when: 2026-08-03T01:20:00+00:00
- change: `NadeBlast` -> `58.0` AND `PlasmaReach` -> `170.0`
- treatment: `jordan-ctf-candidate:v118`  control: `jordan-ctf-candidate:v117`
- measured on: the local simulator at the GV35 pin, seed-paired mirrors
  (episodes/exp-gv31truth.jsonl, seeds 473000-473199 both ways;
   episodes/exp-gv31truth-confirm.jsonl, seeds 480000-480199 both ways)
- verdict: K/D separates POSITIVE: **+0.0424 CI [+0.0229, +0.0621], n=800**;
  win rate 430/800 vs 330/800 (+12.5 pts); captures 176 vs 138; accuracy
  0.689 vs 0.681
- the two mirrors independently: +0.0335 [+0.0058, +0.0616] at n=400, then
  +0.0513 [+0.0230, +0.0797] at n=400. Same sign, overlapping intervals, and
  the pooled interval is clear of zero rather than touching it.
- **why this is two constants and still one variable.** Every other bundle in
  this ledger stacked levers that were individually level, which is what cost
  the previous session 0.184 K/D. This is not that. Both numbers are the same
  edit — *the tree's copy of an engine constant was stale* — made necessary by
  the same upstream commit (GV31), and neither is a guess about what might
  help: `GrenadeBlastRadius + PlayerHalf` and `PlasmaArcReach` are read
  straight out of `sim_types.nim`. They were screened separately first
  (+0.0168 [-0.0423, +0.0779] and +0.0457 [-0.0230, +0.1127], n=60 each, both
  level and both leaning the same way), and the bundle was then required to
  separate on its own account over 800 episodes rather than inheriting their
  leans. It did.
- what it fixes, concretely:
  - `NadeBlast` gates three reads — how many enemies one lob catches
    (grenades.nim), whether the landing clips US, and whether it clips a MATE
    (tactics.nim). At 52 against a real 58 the bot under-counted its own
    blast in all three, which means throws that killed a teammate and pairs
    it declined to bomb.
  - `PlasmaReach` gates the cone's engage range (`+6`) and its trigger
    (`-6`). At 136 against a real 170 a spray carrier walked to within 130px
    of a target it could have hit at 164.
- next: submitted to the league only if the hosted head-to-head against
  daveey clears it.

## gv31truth, hosted gate vs daveey — NO RESULT, not submitted

- when: 2026-08-03T01:36:00+00:00
- design: both builds against the same opponent, `ctf-focusfire:v66` (daveey,
  the player one rank above us and the source of the replays), each as a
  both-directions head-to-head of 40 episodes. All four requests were created
  within 15 seconds of each other so the league could not drift between them.
  80 episodes total, which was the budget.
  - candidate: `xreq_29fee14f-a0a2` / `xreq_7b6ade6e-ac8d`
  - champion:  `xreq_f2b6314e-0894` / `xreq_cb36afcf-94ff`
- what each build did against daveey:

  |                | v118 (candidate) | v117 (champion) |
  |----------------|-----------------:|----------------:|
  | K/D            |           0.7767 |          0.7613 |
  | K/D gap        | -0.5045 [-0.644, -0.373] | -0.5451 [-0.674, -0.428] |
  | episode wins   |      2/40 (5.0%) |     2/40 (5.0%) |
  | captures       |                0 |               1 |

- the difference, which is the question that was asked:

  | metric    | v118 - v117 | 95% CI | crosses zero |
  |-----------|------------:|--------|--------------|
  | K/D       |     +0.0405 | [-0.1423, +0.2233] | YES |
  | win rate  |     -0.1000 | [-0.3129, +0.1129] | YES |
  | captures  |          +1 | [-8.2, +10.2] | YES |

- **verdict: no result, so no submission.** README rule 6 does not soften
  because the point estimate is the one we wanted. Note the K/D difference,
  +0.0405, sits almost exactly on the local measurement's +0.0424 — but this
  design cannot resolve it and was never going to: 80 episodes buys ~0.070
  K/D on a PAIRED mirror, and splitting them into two independent arms against
  a common opponent roughly doubles the standard error again. The honest
  reading is that the hosted run is consistent with the local result and
  independent of it, not that it confirms it.
- the change still lands in `bot/` and is recorded `PROMOTE-LOCAL`: it beat
  the tree over 800 seed-paired episodes, and the tree keeps climbing even
  when the league has not been shown the result (README, "Beating the tree is
  not beating the league").
- the other thing this measured, and it is the more useful number: **daveey
  beats both our builds about equally hard** — 5% of episodes won, K/D ~0.77,
  essentially zero captures out of 40 episodes each. The replay analysis said
  the gap is positional rather than mechanical, and a 0.04 K/D constant fix
  does not touch it. That is the problem worth working on, not this one.

## multiteam — PROMOTE (local A/B, Paintbot)

- when: 2026-08-03T03:05:00+00:00
- change: the policy plays four-team boards. The wire vocabulary gets four
  colours (`Colour` = red/blue/green/yellow, dealt `slot mod GameTeams` off the
  `game teams` marker and confirmed by the self marker on the first alive
  frame); the strategy frame keeps its two sides (us / the raid target) so
  every tuned constant, `objective.nim`, `engage.nim` and `act.nim` are
  untouched; and on multi-team boards the landmarks anchor on the stated
  `endzone` marks instead of the mirrored-arena math.
- measured on: the local simulator, `sim/paintbot_4ffa.json`, 40 seeds x a
  4-step colour rotation = 160 episodes (episodes/paint-4ffa-port.jsonl),
  lineup `abbb` — one candidate against a field of three, the league's own
  shape. Every build sits on every colour equally often: 160/160/160/160
  candidate seats, 480 each for the field.

  |                    | ported tree | pre-port tree |
  |--------------------|------------:|--------------:|
  | mean pot score     | **-0.3125** |       -1.0000 |
  | 95% CI             | [-0.5312, -0.0938] | [-1.0000, -1.0000] |
  | win share          |      0.1375 |        0.0000 |
  | K/D                |      3.0022 |        0.4311 |
  | captures           |          17 |             0 |
  | accuracy           |       0.814 |         0.646 |

- verdict: score gap **+0.6875 CI [+0.4688, +0.9062]**, does not cross zero.
- the pre-port arm measured exactly -1.0000 with a zero-width interval — every
  episode a loss — which is precisely the hosted record in
  `analysis/paintbot.md` (-1.00 over 18 four-team episodes). The harness
  reproduces reality before it is asked to measure a change to it.
- **the two-team path is bit-identical and that was checked, not asserted.**
  Seeds 471000, 471001, 473000, 473001, 480000 on `sim/league_config.json`,
  and five seeds each on `paintbot_default` and `paintbot_2v2`, all hash the
  same as the pre-port tree; so does a MIXED episode with the ported tree on
  even slots and the old one on odd. The CTF league cannot see this change.
- statues, the thing that started it: zero-shot seat-episodes on 4ffa fell
  from 203/320 to 13/320 in an independent 40-episode check here, and no seat
  is fully idle. The residual zeroes are spray-can carriers — `shotsFired`
  counts gun shots and the can REPLACES the gun — which the two-team boards
  do at 2.1-3.6% as well.
- **not finished.** 0.1375 win share is still below the 0.25 a fourth team
  gets by chance, and 100 of 120 four-team episodes still end with no winner.
  This buys the seats that were forfeit; it does not yet play the game well.

## multiteam, live confirmation — the green seats fight

- when: 2026-08-03T03:10:00+00:00
- `jordan-ctf-candidate:v119` was submitted to the Paintbot league
  (`sub_d457e86a`) and took the champion slot at 02:49Z; v117 is benched.
- round 452 seated it in a `4ffa` episode
  (`ereq_e0a6519f-9a12-4306-8e60-76df50f9c4f2`) on slots 2, 6, 10, 14 —
  `slot mod 4 == 2`, i.e. **GREEN**, the exact colour that stood at spawn all
  game before this change. Replay pulled and re-simulated:

  | seat | shots | kills | deaths | grenades |
  |-----:|------:|------:|-------:|---------:|
  |    2 |    16 |     2 |      3 |        2 |
  |    6 |     9 |     4 |      0 |        4 |
  |   10 |    28 |     8 |      3 |        1 |
  |   14 |     9 |     2 |      2 |        2 |
  | **total** | **62** | **16** | **8** | **9** |

  Shots by colour on that board: red 1, blue 30, **green 62**, yellow 0. We
  fired more than anyone, went 16-8 on kills, and yellow — somebody else's
  entrant — is still a statue.
- we lost the episode. n=1 says nothing about strength and this is not
  claimed as a strength result; it is the mechanism check, and the mechanism
  works in production.
- live score so far on v119 is 9 episodes (8 `default`, 1 `4ffa`), which is
  far too few to read. The number to watch is the four-team mean, which was
  **-1.00 over 18 episodes** before this.

## roles4 — PROMOTE (local A/B, Paintbot)

- when: 2026-08-03T04:20:00+00:00
- change: on four-team boards only, per-team seat 3 is HomeDefender instead of
  the trailing mid. One line in `dealSeat`, gated `GameTeams > 2`.
- **how it was found, which is the point.** The first experiment off the
  "four-team games do not finish" analysis was `MultiLatePushTick` 3400 ->
  2000 — push out earlier, because a clock draw pays -1 to everybody and only
  39-41% of hosted four-team episodes resolve at all. It measured an EXACT
  zero, and the paint harness said why: bit-identical episodes, one gameHash
  per seed. The constant was dead. Probing the gate showed `multiFrameOn()`
  true on all sixteen seats (`zones=4 ready=true`), so the gate was not the
  problem; `f.pushOut` is read by exactly two roles, **Overwatch (per-team
  seat 5) and HomeDefender (seat 7)** — and a 4ffa team holds seats 0..3.
  A four-seat team therefore fields four attackers, nobody guards the heart,
  and every line of push-out logic is unreachable. The null result WAS the
  finding.
- why seat 3 and not a size-dependent spread: the roster size is not on the
  wire. A seat knows its own slot and the stated team count, never how many
  seats its team holds. 3 is the last seat a four-of-four roster has and the
  first the mid quad can spare, so one rule serves 4ffa (3 attack + 1 guard,
  the eight-seat spread's own 75/25 split) and 4ffa8 (keeps its seat-7 guard,
  gains a second).
- why a guard is worth more here than in CTF: under GV32 an unguarded heart
  is not a conceded point, it is **elimination** — a capture removes the
  captured team from the game outright.
- measured on `sim/paintbot_4ffa.json`, 4-step colour rotation, lineup `abbb`:

  | run | n (seeds) | gap | 95% CI |
  |-----|----------:|----:|--------|
  | first | 48 | +0.2691 | [+0.0347, +0.5035] |
  | confirmation | 48 | +0.5382 | [+0.2517, +0.8247] |
  | **pooled** | **96** | **+0.4036** | **[+0.2214, +0.5990]** |

  pooled arms: mean pot score **-0.3333** [-0.4922, -0.1562] against
  **-0.7370** [-0.7917, -0.6806]; K/D 1.3653 vs 0.8825; captures 7 vs 2.
  Colour seats exactly balanced, 384 each for the candidate and 1152 each for
  the field.
- two-team path re-verified bit-identical after landing (seeds 471000,
  471001, 473000 on `sim/league_config.json`).
- still short of the 0.25 chance baseline. This is the second of the two
  structural gaps, not the last.

## The capture family — three REJECTs, and what they jointly say

Iteration 3 on Paintbot. The third-pass analysis said captures are the lever:
under GV32 a capture eliminates a whole team, **92% of hosted four-team
episodes that resolve contain one** (24 sampled resolved replays,
`analysis/pb_finish.py` — richard wins on 2.50 captures an episode, daveey on
1.57), and we take **3 in 384** local episodes. Three experiments went at it
and all three failed. The failures agree, which is worth more than any one of
them.

### multilatepush2000 — REJECT

- change: `MultiLatePushTick` 2000 on four-team boards (vs `LatePushTick`
  3400), i.e. commit to the all-in sooner because a clock draw pays -1 to
  everybody.
- verdict: **exact zero, bit-identical episodes.** `f.pushOut` is read by
  exactly two roles — Overwatch (per-team seat 5) and HomeDefender (seat 7) —
  and a 4ffa team holds seats 0..3. Dead code. This null produced `roles4`,
  which paid +0.4036.

### holdrelease — REJECT (local A/B)

- change: on four-team boards drop the `kills <= foeBest` half of the
  hold-line test, keeping only the `< HoldLineKills` floor. Against ONE
  opponent that clause releases about half the time; against THREE it means
  "lead the best of three", which pins the wave at `CenterX +- HoldLineDepth`.
- measured: `sim/paintbot_4ffa.json`, 48 seeds x 4-step rotation.
- verdict: level, leaning negative: **-0.2344 CI [-0.4861, +0.0434]**, n=48.
  **1 capture** in the treatment arm.

### pocketrush340 — REJECT (local A/B)

- change: `MultiPocketRush` 340 on four-team boards (vs `PocketRushRange`
  210) — the gate that turns an attacker into a thief, moved out to where the
  wave actually arrives.
- rationale, measured first: over 12000 decide-ticks on 4ffa **no seat ever
  came within 200px of the target heart and no seat ever carried one**;
  closest approaches were 260, 319 and 468px. So the grab gate sat behind a
  door the attackers never reach.
- verdict: level, leaning negative: **-0.1562 CI [-0.3472, +0.0260]**, n=48.
  **0 captures** in the treatment arm.

### what the three of them say together

Two independent interventions aimed straight at the raid — release the wave,
and lower the bar for committing to the grab — each moved the score slightly
NEGATIVE and neither produced captures. Both changed *what a seat does once
it is near the target*; neither changed *whether it goes there*. Combined
with the probe (never inside 200px, never carrying), the conclusion is that
captures are not gated by a tuned range at all: **the wave is not being
delivered to the pedestal.**

The suspect is geometry, and it was flagged during the port rather than found
now: the three lanes are **y-bands of a left-right arena**, and `FlankDepth`
and the hold-line clamp are measured along `CenterX`. On a generated corners
or plus board the home->target axis is not the map's x-axis, so a flanker's
lane hugs the map border and the depth tests measure the wrong direction.
That is a navigation rewrite, not a knob, and it is where iteration 4 goes.

No promotion this iteration. The tree stays at `jordan-ctf-candidate:v120`.

## CORRECTION to "The capture family": the probe that produced it was degenerate

The entry above states, as a measured fact, that on 4ffa "no seat ever came
within 200px of the target heart and no seat ever carried one", with closest
approaches of 260/319/468px. That measurement was real but it was taken with
`--assign aaaaaaaaaaaaaaaa` — **one build in all sixteen seats, all four teams
playing identically**. That is a degenerate board, and the number does not
survive the league-shaped lineup.

Re-measured on the `abbb` rotation (one candidate against a field of three,
which is what the division actually seats), 16 seeds / 64 episodes, both arms
inside the same episodes: **34 of 256 seat-episodes came within 200px and 8
seats carried a heart** on the current tree. Median closest approach 415px,
not "never". For calibration the same policy on the two-team arena it wins on
manages a 345px median, so the tree's four-team approach rate was already in
the same range as its two-team one.

So the diagnosis "the wave is not being delivered to the pedestal" was
overstated. The wave is delivered about as often as it is on the board this
policy was tuned for; it is just that neither number is enough. `holdrelease`
and `pocketrush340` remain rejected on their own measurements — those were
run on the rotation and stand — but the reason attached to them here was
built on the degenerate probe and should not be trusted as stated.

Lesson for the next probe: an all-same-build board is fine for a mechanism
check that asks "does this code path execute" and worthless for one that asks
"how often does this happen in a game", because every team plays the same
policy and the board stalemates in a way no real episode does.

## axisframe — REJECT (local A/B), kept on branch `axis-frame`

- when: 2026-08-03T05:40:00+00:00
- change: an ADVANCE FRAME. Depth and lateral offset are taken along the
  `multiHome -> multiTarget` axis with the midpoint as origin, replacing the
  map's x-axis, for four-team boards only. Converted readers: flank progress
  and waypoint, the hold clamp, the weave band, the keeper's watch sweep and
  its `on our half` test (which read `bot.team == Red`, a parity token that
  names nothing on a four-team board), the shield-side and grenade-corner
  tests, the fogged-carrier dead reckon, the carry-home target, and
  `findEnemyPosts`' respawn samples. One new constant, `MultiLaneFrac 0.335`,
  UNMEASURED.
- two-team bit-identity: **PASS**, fifteen hashes across `league_config`,
  `paintbot_default` and `paintbot_2v2`; 4ffa hashes differ, so the edit is
  live exactly where it should be. `selfcheck` passes.
- **the mechanism works.** Per seat-episode, tree vs axis frame: within 200px
  of the raid pedestal 9.5% -> **29.7%**, within 100px 7.2% -> **23.8%**,
  ever carried a heart 1.2% -> **5.5%**, median closest approach 415 -> 316px.
  Captures 26 per 384 candidate seat-teams (0.068) against 13 per 1152 field
  seat-teams (0.011) — a **6x rate**. K/D 1.2140 vs 0.9257. Both halves of the
  sample agree.
- **and it does not pay.** 96 seeds x 4-step rotation = 384 episodes:
  mean pot score **-0.5182 [-0.6484, -0.3750]** against **-0.5443 [-0.6224,
  -0.4661]**; gap **+0.0260 CI [-0.1562, +0.2083], crosses zero.** Halves
  +0.0868 and -0.0347. No result, so no promotion (rule 6).
- why the mechanism does not reach the score: **242 of the 384 episodes still
  timed out**, paying -1 to everyone. Mean pot score is an affine function of
  win share, and both arms win about a quarter of the episodes that resolve.
  Six times the captures does not move a number that is set by whether the
  episode finishes at all.
- three things the brief for this work got wrong, found by the agent doing it:
  - the degenerate-probe error above;
  - **`layoutPlus` is never drawn** — all 412 episodes and 28 hand-picked
    seeds produced `layoutCorners`, because `generateCtfMap` retries seed+1
    until a map validates and the free draw never lands on plus. Forcing
    `mapLayout: plus` does produce them, and a 4-seed smoke test there points
    the same way (48.4% vs 13.5% within 200px);
  - on a corners board **Red<->Blue are horizontal**, so their x-math was
    already right; only Green->Blue and Yellow->Red are diagonal. Half the
    seats, not all of them.
- kept on branch `axis-frame` rather than deleted: it is a strictly better
  model of the board, it is bit-identical where the league can see it, and its
  own diagnosis says the binding constraint is elsewhere. If episode
  resolution improves, this is the first thing to re-measure on top of it.

## endgamesweep — REJECT (local A/B), kept on branch `endgame-sweep`

- when: 2026-08-03T07:57:00+00:00
- change: the behaviour the fourth pass asked for. When the board is nearly
  empty the policy stops holding ground and searches it. Detector
  `rivalsStanding()` counts rival teams whose heart is still in play off the
  planted/carried banners — exact and fog-free (`flagVisibleTo` returns true
  unconditionally for an uncarried flag) and permanent (a heart retires on
  capture under GV32 or wipe under GV33). Behaviour in a new `sweep.nim`: a
  200px lattice remembers when this seat last had eyes on each cell; the
  search walks to a remembered enemy, then a heard landing, then the stalest
  reachable cell scored as staleness minus travel. Seats spread with ZERO
  communication — teammates are fogged — by each being born believing a
  different part of the map is stalest. Seven constants, all UNMEASURED.
- two-team bit-identity: **PASS, 15/15 hashes**; selfcheck passes.
- **it fires**, which `endgamepush` could not claim: 164 of 384 episodes
  (42.7%), median first-fire tick 2529 with 2471 of 5000 left. Probe build
  hashes match the measured build on all 384, so those are the measured
  episodes.
- **and it works on what it was aimed at.** 144 seeds x 4-step rotation, twice
  (candidate against a matched field):

  |            | timeout | wipe | capture | median ticks |
  |------------|--------:|-----:|--------:|-------------:|
  | control    | 292/576 (**50.7%**) | 276 | 8 | 5000 |
  | sweep      | 238/576 (**41.3%**) | 332 | 6 | 4022 |

  −9.4 points, replicated in every 48-seed block (−8.9, −8.3, −10.9).
- **and it does not pay.** Score gap **−0.0289 CI [−0.1591, +0.1013]**, n=576.
  No result.
- **why, and this is the finding of the whole Paintbot line so far.** The
  accounting is exact:
  - 72 episodes the sweep RESOLVED that timed out in control — we won **25
    (34.7%)**, against the 50% one of two survivors gets by chance;
  - 18 it UN-resolved — we had won 13 of those in control;
  - `+5x25 - 5x13 = +60 / 576 = +0.104`, which is what the bootstrap says our
    own score gained: -0.3837 -> -0.2882, **+0.0955 [-0.0260, +0.2170]**;
  - and the FIELD's score gained **more**: **+0.1244 [+0.0839, +0.1649],
    separated.**

  Under pot scoring a resolved episode pays +4/-1/-1/-1 = +1 where a draw pays
  -4. **Finishing an episode creates five points of score and hands them to
  whoever wins it — it is a PUBLIC GOOD.** We unlock the pot and collect a
  third of it. Resolving more games is therefore not a strategy on its own;
  the objective is winning the ones that resolve.
- next, and it is a knob rather than a behaviour: of the 18 episodes the sweep
  turned back into timeouts we were winning 13 — it pulls seats off a grind
  they had already won. `MultiSweepChaseTtl` 150 -> 400 on one exploratory
  block gave +0.1215 [-0.0694, +0.3299] against 150's +0.0955 on the same
  seeds and halved the un-resolved losses. Two episodes of difference, not a
  result, but it points the way the diagnosis does.
- also recorded: the scoreboard death column CANNOT detect elimination.
  Reading "out at seats x lives" needs the roster size, which is not on the
  wire, and GV35 deliberately does not count elimination deaths — so a
  captured team's death total stops short of its capacity forever.

## carryhome — a REAL BUG, and unmeasurable on this tree

- when: 2026-08-03T08:20:00+00:00
- reported by the operator from live play: *"when we pick up an enemy heart,
  our policies go the wrong way and don't bring it back to our base even when
  there is a clear and safe path"*.
- **the bug is real and confirmed by inspection.** `objective.nim`'s carrier
  branch runs home to `vec(bot.homeDeepX(bot.team), laneY)`.
  `homeDeepX` DOES answer with `bot.multiCapture.x` on a four-team board, so
  the column is right. The ROW comes from `safestLaneY`, which chooses among
  three constants — `LaneTop 40.0`, `LaneMid CenterY`, `LaneBottom
  MapH - 40` (tuning.nim) — that are **fixed y-bands of the mirrored arena**
  and know nothing about where our endzone is. On a corners or plus board our
  capture zone is not on any of those three rows, so the carrier runs to the
  correct x at the wrong end of the map and never scores. `safestLaneY`
  cannot rescue it: its own `towardHome` test reads `bot.team == Red`, the
  parity token that names nothing on a four-team board.
- **and it is unmeasurable on the current tree, because we essentially never
  carry.** The fix (target `bot.multiCapture` directly, gated on
  `multiFrameOn`) measured an EXACT zero over 48 seeds x the 4-step rotation
  (192 episodes) — the pooler detected identical builds. Probed directly with
  a stderr print inside the branch, over four episodes with a mixed field:
  **zero firings.** The tree takes 3 captures per 384 episodes; the branch is
  reached about that often.
- so this is not a null result about the fix, it is a measurement of
  something else: **on four-team boards we do not lose the heart on the way
  home, we never get it.** The operator's sighting is a live-game event rare
  enough that the local sim does not reproduce it in 192 episodes.
- where to measure it: branch `axis-frame` is the only build that produces
  carriers at a rate an A/B can see — it lifts "ever carried a heart" from
  1.2% to 5.5% of seat-episodes and takes 6x the captures — **and it already
  contains this fix**, which is likely part of why. The right experiment is
  `axis-frame` with and without the carry-home correction, not this one on
  its own.
- kept in mind rather than merged: a correctness fix that provably cannot
  execute is not worth a generation of the tree on its own.

## axisframe confirmation — VOID, the comparison was confounded

- when: 2026-08-03T08:45:00+00:00
- what was run: `axis-frame`'s `bot/baseline` against the current tree,
  144 seeds x the 4-step rotation (576 episodes) on the rebased simulator.
- what it printed: mean pot score **-0.9375 [-0.9826, -0.8854]** against
  **-0.0723 [-0.1400, -0.0046]**, gap **-0.8652 [-0.9549, -0.7726]**,
  separating hard negative.
- **it does not mean axis-frame is bad, and it should not be recorded as if it
  did.** Branch `axis-frame` was cut from `8449ab8`, which is BEFORE `roles4`
  (`7663fa3`, per-team seat 3 guards the heart) landed. `roles4` measured
  **+0.4036 [+0.2214, +0.5990]** on its own. So this ran "the axis frame MINUS
  roles4" against "the tree WITH roles4" — two variables moving in opposite
  directions, which is exactly the thing the one-variable rule exists to stop.
  The agent that built the branch said its HEAD was `8449ab8` in its own
  report; that was written into this ledger and then not acted on when the
  comparison was set up. My mistake, not the branch's.
- what a clean answer needs: rebase `axis-frame` onto the current tree so it
  carries `roles4`, then re-run. Until then the only defensible number for the
  axis frame remains its own author's, measured against ITS own base:
  **+0.0260 [-0.1562, +0.2083]**, level.
- the same caution applies to `endgame-sweep`, which was cut from `a5d703d`
  and DOES carry `roles4` — but check before comparing it, rather than after.

## axisframe, rebased onto the tree — a real regression, and the fix it bundles is worth extracting

- when: 2026-08-03T09:35:00+00:00
- what was fixed first: `axis-frame` rebased onto `88b158b`. The rebase applied
  cleanly and the result carries both changes — `roles4` at world.nim:582 and
  the branch's own `carryHome`/raid-axis work. One variable at last.
- what it printed, two independent seed blocks, 144 seeds x the 4-step
  rotation each (576 episodes per block):
  - seeds 1000000+: gap **-0.2228 [-0.3762, -0.0666]**
  - seeds 2000000+: gap **-0.2459 [-0.4051, -0.0839]**
  - pooled, n=288: **-0.2344 [-0.3458, -0.1201]**, clear of zero
- the second block was bought under rule 5, not as decoration: the first
  block's near edge sat at -0.0666, which is the "barely excluded zero" shape
  that rule 5 says comes back level. It did not come back level. The two
  blocks' point estimates land within 0.023 of each other.
- **verdict: reject the axis frame.** On its own base it was level
  (+0.0260 [-0.1562, +0.2083]); on the current tree it costs -0.23. Level then
  negative now is not noise between two runs, it is an interaction: `roles4`
  pins seat 3 to the heart, and the axis frame re-derives targets for every
  seat, which is a plausible way to pull the new guard back off it. Not chased
  further — the branch is rejected either way.
- **what survives the rejection:** the branch contains the four-team
  carry-home correction as `world.carryHome()`, and that is correct by
  inspection independent of everything else on the branch. Extract it alone
  onto the tree rather than merging the branch to get it.

## carry-home, extracted onto the tree alone — correct, inert, merged anyway

- when: 2026-08-03T10:05:00+00:00
- what it is: `world.carryHome()` lifted off the rejected `axis-frame` branch
  and nothing else. Two-team boards keep `vec(homeDeepX, laneY)` exactly;
  four-team boards get `multiCapture`, the endzone centre, which is inside the
  zone for every shape in the vocabulary. The pocket-bugout branch above it is
  now gated to two-team boards, because its whole argument is about an
  east-west spawn cone and north-south lane bands that a four-team board does
  not have.
- inert on CTF, by construction and by hash: with `multiFrameOn()` false the
  new call returns the identical expression and the added conjunct
  short-circuits, and the selfcheck episode hashes **8392779197353060349**
  before and after the edit.
- what it measured on Paintbot, 144 seeds x the 4-step rotation:
  **-0.0058 [-0.0203, +0.0087]**, crosses zero. No result, per rule 6.
- that null is the expected one and is worth reading carefully: the interval is
  not wide-and-centred-on-zero, it is *tight* and centred on zero — +/-0.02
  where a live effect on this board measures +/-0.3. That is the shape of a
  branch that almost never executes, which matches the earlier count of 1.2%
  of seat-episodes ever carrying a heart. The A/B is not saying the fix is
  wrong; it is saying we never get far enough to use it.
- **merged anyway, and the earlier "not worth a generation" note is not
  contradicted.** That note was about spending a submission generation on this
  alone, which is still not worth doing. Committing it costs a measured zero,
  is provably inert on the league we actually rank in, and means the carrier
  goes to the right place the moment anything else raises the carry rate.

## sweep chase TTL 400 — the exploratory block did not survive a rotation

- when: 2026-08-03T10:40:00+00:00
- setup, done in the order the last mistake taught: `endgame-sweep` rebased
  onto the tree FIRST, then checked — `roles4` present, `carryHome` present,
  `buildSweepGrid` present — and only then compared. One variable:
  `MultiSweepChaseTtl` 150 -> 400.
- what it printed, 144 seeds x the 4-step rotation: **+0.0087
  [-0.1186, +0.1389]**, crosses zero. No result.
- the lead that motivated this was **+0.1215 [-0.0694, +0.3299]** from a single
  exploratory block on the same seeds as TTL 150's +0.0955. It was already an
  interval crossing zero; a full rotation moved the point estimate from +0.12
  to +0.01. That is what an exploratory block is for and what it is worth.
- **the sweep family is closed.** TTL 150 measured -0.0289 [-0.1591, +0.1013]
  and TTL 400 measures +0.0087 [-0.1186, +0.1389]. Two settings, both level,
  and the public-good result says why: the sweep's real achievement is cutting
  the timeout rate 9.4 points, and a resolved episode pays +5 into a pot we
  collect 34.7% of. We are buying finishes for the field.
- what iteration 7 needs instead: something that raises OUR share of the pots
  that already resolve, not something that resolves more of them. The sweep
  was the last idea inherited from the "make episodes resolve" objective the
  public-good finding retired, and it should be treated as retired with it.

## bannerdrop — MERGED: the steal aimpoint was 28px off the heart, level on score, kept for correctness

- when: 2026-08-03T21:10:00+00:00
- where it came from: the fifth pass (`analysis/paintbot.md`). pb_finish.py on
  the refetched 24-replay sample says the winner of a resolved four-team
  episode CAPTURED in 75% of them — richard wins on 2.5 captures and as few
  as 6 kills. The new `pb_funnel.py` walks the frame streams: we REACH
  standing rival hearts at daveey's rate (6/9 vs his 25/37) and then never
  touch. Retirement-filtered minimum approach: richard and daveey bottom out
  at 0px on every heart they engage; ours read **13px, 13px, 30px** — twice
  we stood 13px from a standing heart and walked away.
- the arithmetic: `FlagPickupRange = 12` (sim_types.nim:377) against the flag
  POINT. The planted banner sprite is BOTTOM-anchored (global.nim: top-left
  at `flag.y - (PlantedFlagH - 2)`, height 60), and our `mapPos` returns the
  sprite centre — so the anchor `refineMultiFrame` hands `multiTarget` sits
  at `(flag.x, flag.y - 28)`, 16px outside the only circle a steal completes
  in. Every four-team steal this tree ever completed was combat jitter
  closing 28px by accident. Two-team CTF never sees it: its stealTarget is
  mirrored geometry, not a sprite read.
- the change: `PlantedBannerDrop* = 28.0` (tuning.nim), added to the three
  planted-banner reads in `refineMultiFrame` (multiHome, multiTarget, the
  re-target loop). Gated under `multiFrameOn()`; selfcheck episode hash
  **8392779197353060349** unchanged, so CTF provably cannot see it.
- measured, three independent blocks of 144 seeds x the 4-step rotation:
  - seeds 1000000+: **+0.1360 [-0.0029, +0.2778]**
  - seeds 2000000+: **+0.0926 [-0.0666, +0.2546]**
  - seeds 3000000+: **-0.0145 [-0.1678, +0.1331]**
  - pooled, n=432 seeds / 1728 episodes: **+0.0714 [-0.0135, +0.1601]**,
    crosses zero. **No result** (rule 6). Worth recording: at two blocks the
    pooled read HAD separated ([+0.0087, +0.2228]) and the harness printed
    the rule-5 warning verbatim; the third block did exactly what rule 5
    says marginal intervals do. The rule is not decoration.
- the mechanism is not level. Captures per team-episode **27/1728 (1.56%) vs
  31/5184 (0.60%) — 2.6x**; K/D 1.0177 vs 0.9941; accuracy 0.731 vs 0.712;
  win share 0.1389 vs 0.1246. A 2.6x on a 0.6% base is still only ~2% of
  episodes ending in our capture, which is why the score channel cannot see
  it at this n.
- **merged under the carryhome precedent**: provably correct by the engine's
  own constants, hash-inert on the league we rank in, level-not-negative
  locally, and the PRECONDITION for the capture family — with the aimpoint
  outside FlagPickupRange, any raid experiment measures the fluke rate, not
  itself. `carryHome()` stops being dead code the moment touches exist. No
  submission generation spent on this alone.
- next stage of the funnel is now the CARRY: hosted, our 3 carries died at
  median 170 ticks with zero completions; richard completes 25/53 at median
  193 ticks. Candidates: shield-then-steal's two-team `homeSign` geometry on
  multi boards, escort roles for a multi carrier, the pocketRush unarmed
  window on generated terrain. A 4ffa8 mechanism check of this fix is in
  flight (`episodes/exp-bannerdrop-4ffa8.jsonl`).

## bannerdrop on 4ffa8 — PROMOTE, shipped as v121

- when: 2026-08-03T22:30:00+00:00
- why 4ffa8 was measured at all: the 4ffa harness said level (+0.0714,
  crosses zero, n=1728) and the fix was merged for correctness only. But
  4ffa8 — 8 per team, giant terrain, 7500 ticks — is 64% of division traffic
  and the variant we score −1.00 on hosted, and nothing local had ever
  measured it. A 24-seed mechanism check separated at +0.4688 [+0.0000,
  +0.9201], which bought the rule-5 second block.
- **one void block, and the trap that made it.** The first confirmation ran
  against a control materialized from `main` AFTER the fix had been committed
  — an A/A. The pooler caught it exactly: gap +0.0000, zero-width CI, over 24
  seeds x 4 rotation steps. Two lessons re-learned: check what the control
  REF contains before comparing (the axisframe lesson in a new costume), and
  the harness is bit-deterministic on 4ffa8 — 96 giant-board episodes
  reproduced hash-identical across two independently-materialized trees.
- the valid confirmation, control pinned to `b6940c7` (pre-fix by
  inspection): **+0.4167 [−0.0868, +0.9028]** alone; pooled with the first
  block, two independent 24-seed blocks, n=48 seeds / 192 episodes:
  - **score gap +0.4427 [+0.1042, +0.7812]**, clear of zero with the near
    edge at a quarter of the point estimate. Block points +0.4688 / +0.4167.
  - mean pot score **+0.4062 vs −0.0365**: the fix takes the candidate from
    a losing team to a winning one on the board that pays 64% of the pots.
  - win share 0.2708 vs 0.1771 in block 1 (chance 0.25) — we are ABOVE
    chance on the giant board for the first time in any measurement.
- why the effect lives here and not on 4ffa: a giant board resolves locally
  by wipe-grind (71/96 wipes, 19.8% timeouts) and the steal window is long;
  28px of unreachable aimpoint costs a capture-shaped win where the small
  board's brawls decide before a carry matters. Not proven, recorded as the
  working story.
- **shipped**: `scripts/build_amd64.sh` → qemu smoke (demands
  COWORLD_PLAYER_WS_URL) → uploaded as **jordan-ctf-candidate:v121** (tags
  change=bannerdrop, evidence=4ffa8-pooled-n48) → submitted to the Paintbot
  league, `--auto-champion always`, placement pending
  (policy-version 43bf4fd5). A third 24-seed block (seeds 6000000+) is
  running to tighten the recorded estimate; it does not gate the ship.
- the number to watch hosted: the 4ffa8 per-episode mean, **−1.00 over 12
  episodes** pre-fix. It will take a few hundred episodes to read (the
  two-team column's 0.78 spread is what zero looks like at n≈15).

## bannerdrop 4ffa8, third block — the promotion estimate at n=72

- when: 2026-08-03T23:20:00+00:00
- seeds 6000000+, 24 x 4-step rotation: **+0.2951 [-0.2604, +0.8854]** alone.
- pooled over the three valid blocks, n=72 seeds / 288 episodes:
  **+0.3935 [+0.1100, +0.6887]**, clear of zero; block points
  +0.4688 / +0.4167 / +0.2951. Mean pot score +0.3542 [+0.1285, +0.5972]
  against the pre-fix tree's -0.0394 [-0.1262, +0.0475]. This is the number
  the v121 submission rests on. A fourth block runs at 7000000+ for the
  live-confirmation prior; nothing further gates on it.

## bannerdrop 4ffa8, fourth block — the estimate is settled

- when: 2026-08-03T23:55:00+00:00
- seeds 7000000+, pooled over four independent 24-seed blocks, n=96 seeds /
  384 episodes: **+0.3559 [+0.0955, +0.6250]**. Four blocks, four positive
  points; the 4ffa8 family is closed as measured. Idle cores move to the one
  open question: a fourth 144-seed 4ffa block (seeds 8000000+, control
  pinned pre-fix) toward n=576, to say whether the small board's read is
  "level" or "positive but under +0.07".

## bannerdrop on 4ffa, fourth block — the small board separates at n=576

- when: 2026-08-04T00:20:00+00:00
- seeds 8000000+, 144 x 4-step rotation, control pinned pre-fix:
  **+0.1505 [-0.0058, +0.3096]** alone. Pooled across the four blocks,
  n=576 seeds / 2304 episodes: **+0.0911 [+0.0159, +0.1678]**, clear of
  zero. Block points +0.1360 / +0.0926 / -0.0145 / +0.1505.
- read: the fix pays on the small board too, at roughly a quarter of the
  4ffa8 effect (+0.09 vs +0.36) — consistent with the working story that the
  capture channel matters most where wipe-grinds are long. The "MERGED,
  level" verdict at n=432 was the honest call at that n and is superseded,
  not contradicted: the effect was under the +0.07 resolution floor the
  entry itself named. A fifth block (seeds 9000000+) runs to firm the
  margin; nothing gates on it (v121 already shipped).

## bannerdrop 4ffa, fifth block — the n=576 separation did not survive; the small board is LEVEL

- when: 2026-08-04T00:50:00+00:00
- seeds 9000000+, 144 x 4-step rotation: **-0.0521 [-0.1910, +0.0868]**.
- pooled, five blocks, n=720 seeds / 2880 episodes:
  **+0.0625 [-0.0052, +0.1319]**, crosses zero. **No result** (rule 6).
  Block points +0.1360 / +0.0926 / -0.0145 / +0.1505 / -0.0521.
- the previous entry's "separates at n=576" is hereby superseded the same way
  it superseded its predecessor: the near edge sat at +0.0159, which is the
  marginal shape rule 5 exists for, and the bought block did what bought
  blocks do. Third time this session. The rule is undefeated.
- **final 4ffa verdict: level; the merge stands on correctness grounds
  alone.** The effect, if any, is bounded roughly [-0.005, +0.13] at this n
  and is not worth further seeds. The v121 promotion rests entirely on
  4ffa8, where four blocks read all-positive and pooled
  **+0.3559 [+0.0955, +0.6250]** — untouched by this correction.
- the 4ffa family is closed. Cores idle pending the carry-stage instrument
  design (iteration 8's next lever).

## 2026-09-01 — the league became a battle royale; the tree is a statue in it

- when: 2026-09-01T19:20:00+00:00 (league scheduler flipped to
  `variant_rotation: ["battle-royale"]`, 12 episodes/round, 4 entrants x 8
  seats; first BR round was 3549). Engine coworld `paintbot` 0.7.263..266,
  coworld-ctf 9d26cc26 (GameVersion 50); `src/ctf` is identical across those
  four package versions. `sim/engine.pin` moved 63ea0cb7 -> 9d26cc26,
  `bot/nimby.lock` follows the engine lock (bitworld 9af28b41 is a descendant
  of the 8-bit-mask pin; the ButtonC tripwire still passes), labels.nim
  re-synced.
- scoring changed under us: a seat's league score is its team's Glory if the
  team won, else 0 (roster.nim `ctfPlayerResultsJson`); the leaderboard is
  mean-per-round, MAX over rounds. Classic-era winners banked 618-706; v121's
  706 standing is one pre-flip round and persists under max.
- local BR smoke of the tree (sim/paintbot_br.json, seed 1, 32 seats):
  0 shots by any seat, 30/32 dead to the zone by tick 1436. Hosted, rounds
  3549-3552 (48 episodes) plus two 1-episode probes: **zero kills and zero
  damage by ANY seat of ANY policy in the division**; every "win" is the
  zone-lottery survivor banking 18 (one tier-IV achievement). v121 sits at
  0 kills / 0.88 deaths per seat like everyone else.
- shipped tooling: `analysis/br_rounds.py` (hosted round collector/ranker),
  `scripts/br_xp.py` (32-seat rostered XP requests at 0.5 credits/episode,
  colour-group rotation, results pooler), `scripts/local_sim.py br` (local
  16-duo A/B with glory/placement; A/A level over 8 seeds).
- next: the BR port (16 colours, zone safety, duo cohesion, engagement
  discipline) is being built; the first build that survives the zone and
  shoots should win most episodes against a field that does neither.

## 2026-09-01 — why the whole hosted BR field is inert: the giant map's walkability never reaches a policy

- hosted game log (round 3559, ereq_8ada0300): `game started: players=32`,
  then every cog "caught outside the zone", zero shots, 45% late frames,
  59.7 MB of images sent (~1.9 MB per player). Our seats' logs: connect,
  then "game over, exiting: WebSocket closed" — no decision ever ran.
- reproduced locally over a REAL websocket: the engine server
  (coworld-ctf 9d26cc26, `src/ctf.nim`) + 32 copies of the committed bot on
  sim/paintbot_br.json: all connect, nobody fires, all 32 die to the zone.
  The in-process simulator (no websocket) plays the same tree fine once
  seats are sprites-off viewers. So the 3211x1713 walkability sprite — one
  message, ~1.9 MB — is lost between server and client; server.nim's
  `MaxWsFrameBytes = 900_000` chunker admits "a single message larger than
  maxBytes is emitted as its own (oversized) chunk", and whisky's receiver
  does a single `recv(payloadLen)`.
- consequence: every policy that navigates from the wire mask (ours and
  every stock-baseline derivative) stands at spawn; today's hosted 4ffa8
  giant-map games also paid nobody. 191 hosted BR episodes, 0 kills.
- workaround shipped as data: `sim/walkdump.nim` dumps the pinned map's
  `walkMask`; `scripts/br_mask_to_nim.py` embeds it as
  `bot/baseline/brmap.nim` (19,047 runs, FNV-1a checked). The policy-side
  fallback (use it when BR is stated and no sprite arrived) is the next
  change; any bot that can walk on this map wins against a field that
  cannot.

## BR port v1 vs the stock reference bot — local, 8 rotated seeds: wins 8/8, but passively

- when: 2026-09-01T20:50:00+00:00; `scripts/local_sim.py br HEAD sim/stock
  -n 8 --first-seed 101` (b7b0bfc as build a, sim/stock as build b, 8 duos
  each, every colour held 4 times by each build; fixed sprites-off sim).
- endings: 8 wipes, median 1992 ticks. **win share +1.0000 [+1.0000, +1.0000]**;
  league score (glory-if-won averaged over a build's 8 duos) +14.42
  [+11.30, +17.27], i.e. the winning duo banks ~58 glory.
- kills/duo 0.92 vs 2.44 (gap -1.52 [-2.00, -1.06]); deaths/duo 1.81 vs
  2.00; aliveTicks +115 [-6, +237]. The stock bots kill each other and die to
  the zone; ours survive and take the win with few kills. P(win) is the
  objective, but at ~58 glory per win the score channel has room: kills
  taken when the target cannot answer (a duo that has not fired, a cog
  facing away, a 2v1) are nearly free glory, and heat pays streaks x2..x8.
- records: episodes/br-HEAD-b7b0bfc-vs-sim-stock-20260901-134923.jsonl
- caveat: local only. Hosted, no policy (ours included) receives the map on
  this variant yet — the transport fix and the embedded-map fallback gate the
  ship; a hosted A/B follows them.

## v122 — BR port v1 + embedded-map fallback + hardened websocket client: SHIPPED, submitted auto-champion

- when: 2026-09-01T21:12:00+00:00. Tree def5221 (port b7b0bfc + fallback
  b06fc95 + whisky_fixed). Built static amd64 via nix nim+zig, smoked under
  amd64 Docker, uploaded as `jordan-ctf-candidate:v122` through
  `coworld upload-policy` from a minimal image (the docker-save uploader
  no longer matches coworld 0.1.44's OCI push). Submission
  sub_83521d0d, auto-champion always, placement pending.
- why now, before a hosted A/B: the deployed engine (0.7.266) discards every
  policy's socket inputs on this board (upstream "squad-mode mis-arm
  discarded real seat inputs", fixed on coworld-ctf main, not yet deployed),
  so no hosted number can distinguish policies today. v122 is the build
  that navigates the giant map (opts into the policy stream, decodes the
  1.06 MB walkability frame, carries the map as a fallback) and fights;
  being placed before the server fix lands is the point.
- hosted smoke: xreq_211f27b4 (4 episodes, v122 in slot group 0 vs
  focusfire:v52 / claude-paintbot-baseline:v2 / luis-paintbot-baseline:v4)
  to read our own policy logs ("nav built" line) on the hosted wire.
- proof over the real wire: 32 copies of the v122 binary against a server
  built from coworld-ctf origin/main (27e9cac1, squad-mode de-armed,
  cogsPerTeam default 1) on the BR config: every seat logs
  `nav built tick=123 map=3211x1713 teams=16`, and the server log fills with
  kills, clean tags, shield and spray pickups. Against the DEPLOYED engine
  (9d26cc26..334e6d25) the same binary decides but its inputs are discarded,
  exactly like every other entrant's.
- hosted smoke xreq_211f27b4 (4 episodes, 2 credits): every v122 seat logs
  `nav built tick=137..163 map=3211x1713 teams=16` on the league's own wire
  (ereq_0cf0e28a, agents 0/16), then runs to game over; 0 kills for all four
  policies, as the deployed engine (0.7.267 = 398dd598, still
  cogsPerTeam 4) discards inputs. The gate is the engine train, not us.

## BR port v2 — the review's fixes: kills up, win share level vs v1, still 8/8 vs stock

- when: 2026-09-01T21:45:00+00:00. Fixes findings 1-9 and 11 of
  analysis/br_port_review_v1.md (pixel-exact zone routing, own-colour death
  deltas, release-time friendly-fire prediction, partner-capsule grenade
  safety, defensive vs voluntary fire with an advantage predicate,
  fresh-track trailing-only hunt, amortised sonar calibration and stable
  route fields, role-phased jink, 642px grenade range on BR). Worst decide
  frame 14.0 ms on a full BR episode.
- v2 vs v1 (16 seeds, 8 duos each, colour-rotated): win share 0.500 vs
  0.500, gap +0.000 [-0.500, +0.500]; league score +8.60 [-7.82, +25.62]
  (19.79 vs 11.19); kills/duo **+1.89 [+1.54, +2.25]** (2.82 vs 0.93);
  deaths/duo -0.02 [-0.12, +0.08]. Placement and alive ticks were worse.
- v2 vs stock (seeds 201-208): win share 1.000, league score 23.94
  [16.45, 31.44] (v1 on the same seeds: 16.64 [11.11, 23.12]).
- verdict: LEVEL on the primary (win share), positive on kills, glory
  point estimate up. Landed as the new base because the changes are
  correctness fixes to zone routing and friendly fire that the review
  found, not tuning; shipped as v123 so the placed build is the one with
  the fixes when the engine train lands. Classic hashes unchanged.

## 2026-09-01 21:30Z — the engine train landed (0.7.268 = 13972f10, input fix in); v122 wins 3 of 3

- the league's coworld became 0.7.268 at 21:30Z; its source contains upstream
  3de6e794 (squad-mode de-armed). Rounds through 3583 still show 0 kills for
  every seat; from round 3584 kills appear.
- v122 since the fix: r3584 ereq_0cf187dd win, 13 kills, 32.8/seat;
  r3584 ereq_868a5836 win, 10 kills, 58.2/seat; r3585 ereq_4198b862 win
  (field included codex-paintbot-champion:v19, the one visibly fighting
  entrant), 8 kills, 41.8/seat. 3/3 episodes, 31 kills, 0 team kills.
- v123 (BR port v2) uploaded and submitted 21:48Z (sub_123274a0,
  auto-champion always, pending). Hosted rotated A/B of v122 vs
  focusfire:v52 / claude-paintbot-baseline:v2 / luis-paintbot-baseline:v4
  (4 groups x 4 episodes, 8 credits): xreq_cc53c421, xreq_ccd21c87,
  xreq_10f3d00f, xreq_a2dff83b.
- v123 placed as champion 21:52Z. Matching rotated hosted A/B for v123
  (same three opponents, 4 groups x 4 episodes, 8 credits): xreq_007e8100,
  xreq_ac2711e2, xreq_6f8b6a8a, xreq_84805263. Credits spent today so far:
  1 (probes) + 2 (v122 smoke) + 8 (v122 A/B) + 8 (v123 A/B) = 19.

## br-zone-margin120 — PROMOTE (local BR A/B)

- when: 2026-09-01T14:43:25-07:00; one variable: `BrZoneMargin 220 ->
  120`. Hypothesis: retain more loot/contact room without giving up the
  doctrine's >=66px ring buffer.
- measure: `br bot/baseline HEAD -n 24 --first-seed 401 --workers 12`, then
  the marginal-call extension at `--first-seed 425`; 48 paired, colour-rotated
  seeds, zero lost, all wipes. The first block's win-share gap was +0.3333
  [-0.0833, +0.6667]. Pooled treatment vs control: win share 0.6875 vs
  0.2917, **gap +0.3958 [+0.1458, +0.6458]**; league score 18.29 vs 8.04,
  **gap +10.25 [+2.91, +17.60]**; kills/duo +0.16 [-0.08, +0.41];
  deaths/duo -0.07 [-0.13, -0.02]; placement -0.55 [-0.98, -0.14];
  aliveTicks +46.0 [+15.8, +79.4].
- gate: vs `sim/stock`, seeds 201-208, win share 1.0000 [1.0000, 1.0000]
  and league score 20.34 [16.31, 24.94]. Classic seed 5000 remained
  `3769900552187605975` (4191 ticks).
- records: `episodes/br-zone-margin120-vs-head-s401-n24.jsonl`,
  `episodes/br-zone-margin120-vs-head-s425-n24.jsonl`, and
  `episodes/br-zone-margin120-vs-stock-s201-n8.jsonl`.
- verdict: **PROMOTE**. Win share separates positive in the pooled interval;
  score, deaths, placement and survival move consistently with it.

## br-engage650 — LEVEL (local BR A/B)

- when: 2026-09-01T14:45:54-07:00; one variable relative to promoted
  `br-zone-margin120`: `BrEngageRange 900 -> 650`.
- measure: `br bot/baseline <zone-margin120 snapshot> -n 24 --first-seed
  501 --workers 12`; 24 paired, colour-rotated seeds, zero lost, all wipes.
  Treatment vs control: win share 0.3750 vs 0.6250, gap -0.2500 [-0.5833,
  +0.1667]; league score 10.83 vs 14.49, gap -3.67 [-13.60, +7.35];
  kills/duo -0.20 [-0.45, +0.05]; deaths/duo +0.05 [-0.03, +0.13];
  placement +0.35 [-0.15, +0.89]; aliveTicks -0.5 [-43.0, +42.2].
- record: `episodes/br-engage650-vs-margin120-s501-n24.jsonl`.
- verdict: **LEVEL**. Every interval covers zero; do not promote. Per the
  knob rule, test the opposite direction once (`900 -> 1300`).

## br-engage1300 — LEVEL (local BR A/B)

- when: 2026-09-01T14:47:37-07:00; opposite-direction retry of the same
  variable relative to promoted `br-zone-margin120`: `BrEngageRange 900 ->
  1300`.
- measure: `br bot/baseline <zone-margin120 snapshot> -n 24 --first-seed
  525 --workers 12`; 24 paired, colour-rotated seeds, zero lost, all wipes.
  Treatment vs control: win share 0.5417 vs 0.4583, gap +0.0833 [-0.3333,
  +0.5000]; league score 16.37 vs 11.01, gap +5.36 [-6.45, +16.94];
  kills/duo +0.49 [+0.14, +0.82]; deaths/duo -0.03 [-0.09, +0.05];
  placement -0.10 [-0.68, +0.52]; aliveTicks +18.0 [-21.7, +56.5].
- record: `episodes/br-engage1300-vs-margin120-s525-n24.jsonl`.
- verdict: **LEVEL**. Win share and league score both cross zero, so the
  separating kill gain is diagnostic only; restore 900.

## br-partner-min120 — LEVEL (local BR A/B)

- when: 2026-09-01T14:49:11-07:00; one variable relative to promoted
  `br-zone-margin120`: `BrPartnerMin 80 -> 120`.
- measure: `br bot/baseline <zone-margin120 snapshot> -n 24 --first-seed
  601 --workers 12`; 24 paired, colour-rotated seeds, zero lost, all wipes.
  Treatment vs control: win share 0.4583 vs 0.5417, gap -0.0833 [-0.5000,
  +0.3333]; league score 14.02 vs 15.05, gap -1.03 [-13.26, +11.53];
  kills/duo +0.08 [-0.31, +0.46]; deaths/duo +0.00 [-0.08, +0.08];
  placement +0.22 [-0.39, +0.83]; aliveTicks -19.2 [-62.6, +22.3].
- record: `episodes/br-partner-min120-vs-margin120-s601-n24.jsonl`.
- verdict: **LEVEL**. Every interval covers zero; do not promote. Per the
  knob rule, test the opposite direction once (`80 -> 60`).

## br-partner-min60 — LEVEL (local BR A/B)

- when: 2026-09-01T14:51:04-07:00; opposite-direction retry of the same
  variable relative to promoted `br-zone-margin120`: `BrPartnerMin 80 -> 60`.
- measure: `br bot/baseline <zone-margin120 snapshot> -n 24 --first-seed
  625 --workers 12`; 24 paired, colour-rotated seeds, zero lost, all wipes.
  Treatment vs control: win share 0.5417 vs 0.4583, gap +0.0833 [-0.3333,
  +0.5000]; league score 17.68 vs 14.70, gap +2.98 [-11.09, +16.46];
  kills/duo -0.21 [-0.56, +0.14]; deaths/duo -0.04 [-0.12, +0.05];
  placement -0.30 [-0.96, +0.31]; aliveTicks +20.4 [-13.9, +57.3].
- record: `episodes/br-partner-min60-vs-margin120-s625-n24.jsonl`.
- verdict: **LEVEL**. Every interval covers zero; restore 80.

## br-endgame-split200 — VOID (wired to urgent rotation, not endgame)

- when: 2026-09-01T14:52:50-07:00; intended variable relative to promoted
  `br-zone-margin120`: widen only a leading two-cog endgame hold from 120px
  to 200px. The post-run isolation audit found the parameter was passed to
  the urgent zone-rotation call instead; the endgame call retained 120px.
- measure: `br bot/baseline <zone-margin120 snapshot> -n 24 --first-seed
  701 --workers 12`; 24 paired, colour-rotated seeds, zero lost, all wipes.
  Treatment vs control: win share 0.5417 vs 0.4583, gap +0.0833 [-0.3333,
  +0.5000]; league score 17.30 vs 12.43, gap +4.86 [-7.80, +17.40];
  kills/duo -0.01 [-0.37, +0.37]; deaths/duo -0.06 [-0.14, +0.02];
  placement +0.23 [-0.47, +0.92]; aliveTicks -10.9 [-79.5, +47.5].
- record: `episodes/br-endgame-split200-vs-margin120-s701-n24.jsonl`.
- verdict: **VOID** for the stated endgame hypothesis. The numbers describe
  an unplanned urgent-rotation split and cannot decide endgame posture.

## br-endgame-split80 — VOID (wired to urgent rotation, not endgame)

- when: 2026-09-01T14:54:35-07:00; the intended opposite-direction retry
  also parameterized urgent rotation rather than the leader endgame branch.
- measure: `br bot/baseline <zone-margin120 snapshot> -n 24 --first-seed
  725 --workers 12`; 24 paired, colour-rotated seeds, zero lost, all wipes.
  Treatment vs control: win share 0.5833 vs 0.4167, gap +0.1667 [-0.2500,
  +0.5833]; league score 13.32 vs 11.14, gap +2.18 [-9.14, +12.60];
  kills/duo +0.25 [-0.12, +0.61]; deaths/duo -0.03 [-0.11, +0.05];
  placement -0.12 [-0.80, +0.54]; aliveTicks +13.5 [-37.5, +64.2].
- record: `episodes/br-endgame-split80-vs-margin120-s725-n24.jsonl`.
- verdict: **VOID** for the stated endgame hypothesis. The call is now moved
  to the leader-only branch and the experiment restarts on fresh seeds.

## br-endgame-split200-correct — LEVEL (local BR A/B)

- when: 2026-09-01T14:56:19-07:00; one correctly wired behavior variable
  relative to promoted `br-zone-margin120`: widen only the
  `scores.ok and not trailing and ownLives == 2` endgame hold from 120px to
  200px. Urgent rotation and ordinary holds retain the behavior-identical
  120px default.
- measure: `br bot/baseline <zone-margin120 snapshot> -n 24 --first-seed
  749 --workers 12`; 24 paired, colour-rotated seeds, zero lost, all wipes.
  Treatment vs control: win share 0.4167 vs 0.5833, gap -0.1667 [-0.5833,
  +0.2500]; league score 11.00 vs 15.62, gap -4.62 [-15.64, +6.90];
  kills/duo -0.18 [-0.58, +0.22]; deaths/duo +0.04 [-0.04, +0.12];
  placement -0.16 [-0.84, +0.55]; aliveTicks +2.0 [-47.3, +50.2].
- record:
  `episodes/br-endgame-split200-correct-vs-margin120-s749-n24.jsonl`.
- verdict: **LEVEL**. Every interval covers zero; do not promote. Test the
  correctly wired opposite direction once (120px -> 80px).

## br-endgame-split80-correct — LEVEL (local BR A/B)

- when: 2026-09-01T14:57:57-07:00; correctly wired opposite-direction retry
  relative to promoted `br-zone-margin120`: tighten only the leading two-cog
  endgame hold from 120px to 80px. Urgent rotation and ordinary holds retain
  their original 120px split.
- measure: `br bot/baseline <zone-margin120 snapshot> -n 24 --first-seed
  773 --workers 12`; 24 paired, colour-rotated seeds, zero lost, all wipes.
  Treatment vs control: win share 0.5000 vs 0.5000, gap +0.0000 [-0.4167,
  +0.4167]; league score 14.51 vs 13.59, gap +0.92 [-11.12, +12.84];
  kills/duo +0.03 [-0.33, +0.40]; deaths/duo +0.02 [-0.07, +0.10];
  placement +0.33 [-0.32, +0.94]; aliveTicks -7.4 [-51.3, +38.5].
- record: `episodes/br-endgame-split80-correct-vs-margin120-s773-n24.jsonl`.
- verdict: **LEVEL**. Every interval covers zero; restore the original 120px
  endgame split and remove the experimental parameter.

## br-trackcap16 — LEVEL (local BR A/B)

- when: 2026-09-01T15:03:53-07:00; one variable relative to promoted
  `br-zone-margin120`: `TrackCap 5 -> 16`. The larger memory was meant to
  retain more of the 30-enemy field for late acquisition.
- measure: `br bot/baseline HEAD -n 24 --first-seed 801 --workers 12`;
  24 paired, colour-rotated seeds, zero lost, all wipes. Treatment vs control:
  win share 0.5000 vs 0.5000, gap +0.0000 [-0.4167, +0.4167]; league score
  17.40 vs 12.43, gap +4.97 [-7.59, +17.39]; kills/duo +0.97 [+0.48,
  +1.43]; deaths/duo -0.01 [-0.08, +0.07]; placement +0.08 [-0.80,
  +0.94]; aliveTicks +13.5 [-51.9, +83.0].
- record: `episodes/br-trackcap16-vs-margin120-s801-n24.jsonl`.
- verdict: **LEVEL**. Win share and league score both cover zero broadly;
  the separating kill gain is diagnostic only. Restore `TrackCap = 5`.
- shipped as **jordan-ctf-candidate:v124** (zone margin 120), submitted
  sub_38f2b215 auto-champion always. Rotated hosted A/B (same three
  opponents, 4 x 4 episodes, 8 credits): xreq_e0d48dba, xreq_4a6c1e07,
  xreq_c3e44af1, xreq_10e4c3e5. Credits today: 27.
- hosted ladder since the fix (rounds 3584-3588, engine 0.7.268/269): v122
  3/3 wins, v123 2/2 wins (r3588: 11 kills 31.8/seat; 5 kills 36.5/seat).
  Seat win rate 25% = one winning duo per episode, the ceiling for a
  four-duo entrant. Live-field runners-up: claude-t1-hybrid:v1 (19.8/seat,
  18.8% seat wins) and codex-paintbot-champion:v19 (13.1/seat); everyone
  else under 6/seat.

## 2026-09-01 ~22:10Z — the league cut over to battle-royale-s2 (play seats); orchestrator shipped as v125

- scheduler now `team_count: 16, variant_rotation: ["battle-royale-s2"],
  insufficient_players: filler_policy`; coworld 0.7.270 (4b1cf10f). On a
  play seat our input masks are ignored (analysis/s2_shell.md §1).
- v125 = HEAD c… "Season-2 play-seat orchestrator" (mode detection, six
  embedded reference plays, survival ladder, 4 Hz re-calls) on top of v124.
  Live proof on a wasmtime server from upstream main: 192 module_ready,
  32/32 calls accepted by tick ~170, standing orders installed. Known
  defect: a later packet fails JSON parsing and the client reconnects in a
  loop (calls persist server-side); being diagnosed. Submitted
  sub_df0500d2, auto-champion always.

## br-zone-margin90-150 — LEVEL (local BR A/B)

- when: 2026-09-01T15:07:33-07:00; one variable relative to promoted
  `br-zone-margin120`: first `BrZoneMargin 120 -> 90`, then the requested
  opposite-direction fallback `120 -> 150` after 90 was level.
- 90px measure: `br bot/baseline HEAD -n 24 --first-seed 901 --workers 12`;
  24 paired, colour-rotated seeds, zero lost, all wipes. Treatment vs control:
  win share 0.5000 vs 0.5000, gap +0.0000 [-0.4167, +0.4167]; league score
  13.38 vs 15.05, gap -1.67 [-13.62, +10.27]; kills/duo -0.05 [-0.36,
  +0.28]; deaths/duo -0.01 [-0.09, +0.08]; placement -0.43 [-1.12,
  +0.28]; aliveTicks +16.6 [-32.8, +67.8]. `HEAD@ca61144` was bot-identical
  to the starting `59ead7f`; the ref advanced only through ledger commits.
- 150px measure: `br /tmp/johomax-k2-exp2-margin150
  /tmp/johomax-k2-exp2-control -n 24 --first-seed 925 --workers 12`;
  immutable snapshots differed only in `BrZoneMargin`. Treatment vs control:
  win share 0.3750 vs 0.6250, gap -0.2500 [-0.5833, +0.1667]; league score
  9.73 vs 17.43, gap -7.70 [-18.25, +3.48]; kills/duo +0.04 [-0.34,
  +0.43]; deaths/duo +0.02 [-0.07, +0.09]; placement +0.66 [+0.15,
  +1.19]; aliveTicks -26.6 [-61.3, +6.9].
- records: `episodes/br-zone-margin90-vs-margin120-s901-n24.jsonl` and
  `episodes/br-zone-margin150-vs-margin120-s925-n24.jsonl`.
- verdict: **LEVEL**. Both primary metrics cover zero for both values; the
  separating placement regression at 150px is diagnostic only. Keep 120px.

## br-engage-passive-isolated — LEVEL (local BR A/B)

- when: 2026-09-01T15:10:09-07:00; one behavior variable relative to
  `br-zone-margin120`: after defensive-fire overrides and the range cap,
  voluntary initiation required either `target.lastFired >= 240 ticks ago`
  or no second fresh enemy within 400px. This replaced the existing
  wounded/unshielded, local-2v1 and covered-pre-aim voluntary advantages.
- measure: `br /tmp/johomax-k2-exp3-passive-isolated
  /tmp/johomax-k2-exp3-control -n 24 --first-seed 1001 --workers 12`;
  immutable snapshots differed only in `brAdvantage`; 24 paired,
  colour-rotated seeds, zero lost, all wipes. Treatment vs control: win share
  0.4583 vs 0.5417, gap -0.0833 [-0.5000, +0.3333]; league score 12.64 vs
  16.83, gap -4.19 [-16.42, +8.38]; kills/duo -0.19 [-0.49, +0.10];
  deaths/duo +0.01 [-0.07, +0.09]; placement -0.04 [-0.52, +0.40];
  aliveTicks +7.9 [-24.7, +42.1].
- record:
  `episodes/br-engage-passive-isolated-vs-margin120-s1001-n24.jsonl`.
- verdict: **LEVEL**. Every interval covers zero broadly; keep the current
  voluntary-advantage mix.

## br-shield-role — LEVEL (local BR four-arm A/B)

- when: 2026-09-01T15:12:24-07:00; one behavior variable relative to
  `br-zone-margin120`: nearby safe shield pickup by both BR seats, the
  current anchor-only rule, or neither seat. A duplicate anchor control gave
  each candidate an equal four-duo comparator in one shared episode field.
- measure: `br /tmp/johomax-k2-exp4-both /tmp/johomax-k2-exp4-anchor
  /tmp/johomax-k2-exp4-neither /tmp/johomax-k2-exp4-anchor-copy -n 24
  --first-seed 1101 --workers 12`; 24 paired, colour-rotated seeds, zero lost,
  all wipes; every arm held all 16 colours six times.
- both vs anchor: win share 0.2917 vs 0.2500, gap +0.0417 [-0.2500,
  +0.3333]; league score 19.97 vs 12.90, gap +7.07 [-11.25, +26.78];
  kills/duo -0.04 [-0.60, +0.47]; deaths/duo -0.02 [-0.15, +0.09];
  placement +0.12 [-0.65, +0.97]; aliveTicks +10.5 [-37.5, +56.1].
- neither vs anchor-copy: win share 0.2500 vs 0.2083, gap +0.0417
  [-0.2500, +0.2917]; league score 15.91 vs 14.83, gap +1.07 [-18.83,
  +19.93]; kills/duo +0.05 [-0.40, +0.52]; deaths/duo -0.03 [-0.15,
  +0.08]; placement +0.50 [-0.51, +1.45]; aliveTicks -17.6 [-73.6,
  +41.7]. The standard report was re-keyed in memory only to print this
  second paired gap; the saved episode records were not changed.
- record: `episodes/br-shield-role-vs-anchor-s1101-n24.jsonl`.
- verdict: **LEVEL**. Both primary intervals cover zero broadly for both
  alternatives, as do all diagnostic intervals. Keep anchor-only pickup.
- first S2 ladder round 3591 (22:05Z, 9 entrants + the three `starter-*`
  fillers): one episode, FAILED — "Player pod job-…-player-12 for slot 12
  terminated with exit code 1". A 32-seat S2 episode needs every pod alive;
  a crashing classic bot fails the round for everyone. v125 was not seated.
  Requirement for us: never exit non-zero on a play seat.

## Hosted rotated A/Bs on the classic battle-royale variant (engine 0.7.268-270), 16 episodes each, same three opponents

| build | wins/16 | league score per episode (95% CI over episodes) | kills/seat | opponents' wins |
|---|---:|---:|---:|---:|
| v122 (port v1) | 15 | 31.8 [25.5, 37.4] | 0.97 | 0 |
| v123 (port v2) | 16 | 48.5 [36.2, 63.7] | 1.08 | 0 |
| v124 (v2 + zone margin 120) | 16 | 42.7 [33.5, 52.8] | 1.16 | 0 |

- opponents paintbot-focusfire:v52, claude-paintbot-baseline:v2,
  luis-paintbot-baseline:v4: 0 wins, 0 score in all 48 episodes; each of
  our four slot groups held once per build (colour rotation).
- read: on the classic variant the port is decisively above the placed
  field; v123 vs v124 is level on score (intervals overlap) and both win
  every episode. The league moved to battle-royale-s2 at 22:10Z, so these
  measure the legacy path only.
- S2 ladder state 22:20-22:30Z (engine 0.7.271): rounds 3593-3595 seat ONE
  entrant (e.g. codex-paintbot-t1-s2-collaborative-target:v1) plus 30 filler
  seats from the three `starter-*` policies, and fail on a filler pod
  exiting with code 1 (round 3594: "player-5 for slot 5 terminated with
  exit code 1"). v125 (submitted 22:08Z, just before the flip) has not been
  planned into any S2 round; the next ship is resubmitted after the flip.
- v125 S2 hosted smoke xreq_8cf7f255 (2 episodes, 1 credit): both FAILED —
  "player slot 5/2 never joined the lobby within 7200 lobby ticks": the
  classic opponents in the roster (play seats) never bind. OUR seats' hosted
  logs show `module_accepted`/`module_ready` for edge_ride, target_law,
  supply_run… on the platform wire, i.e. the upload path works hosted. A
  hosted S2 measurement needs every seat to be an S2-capable policy.

## S2 orchestrator v2 (hardening + PV1 binary views) — live wire proof, 32 seats

- when: 2026-09-01T22:35:00+00:00; wasmtime server built from coworld-ctf
  origin/main (/private/tmp/engine-main-v40, WASMTIME_C_API), battle-royale-s2
  config with 32 play seats, 32 native bots of tree 6d9f… (this commit).
- every seat: 6 modules ready, survival call accepted at tick ~162
  (`decision=uploads_settled`), 0 reconnects during the game, 0 dropped
  messages, frame pacing waited 1394/1394 (100%), late 0; the game resolved
  ("blue win") at 1394 playing frames with 4 kills — the ladder's
  target_law holdTrigger {aliveTeams: 8} keeps every duo from firing until
  eight teams remain, so with 16 identical passive duos the zone decides.
- read: the transport and protocol layer is done; strategy tuning (hold
  trigger, edge_ride margin, when to crossfire/jackal) is the next loop and
  needs opponents that fight (the engine's three starters) in the local S2
  harness (scripts/s2_local.py, in progress).
- shipped as **jordan-ctf-candidate:v126** (tree 073992b), submitted 22:38Z
  after the flip, sub_cf43a16e, auto-champion always. Hosted S2 self-mirror
  smoke (all 32 seats v126, 2 episodes) requested to prove the hosted game
  completes and to read per-duo glory — a pipeline check, not a
  measurement.

## 2026-09-01 22:45Z — the S2 rounds disqualified the field; scheduler flipped back to classic battle-royale

- rounds 3591-3601 (battle-royale-s2, 0.7.270/271): every episode failed on
  a filler `starter-*` pod exiting 1. The division's
  `disqualify_after_consecutive_failures: 3` then retired 633 of 636
  memberships; three remain `competing` (us, codex-paintbot-t1, one more).
  The player leaderboard has two rows: Jordan 706, codex-paintbot-t1 18.
- rounds 3600-3601 seated v126 (2 seats) beside codex-paintbot-t1's
  `…-s2-collaborative-target:v1`; both failed on starter pods; our seats
  were not the failing ones.
- the league scheduler is back to `variant_rotation: ["battle-royale"],
  team_count 4, insufficient_players: do_not_run` — classic rounds need four
  competing entrants, so the ladder is quiet until players re-qualify.
  v126 plays both variants (legacy loop on input seats, orchestrator on
  play seats).
- local S2 harness validated: self-mirror episode completed at 1208 ticks,
  192 module_ready, 32 accepted calls, 9 kills; the starters' playbook and
  venv built (`scripts/s2_build_starters.sh`).
- hosted S2 self-mirror smoke xreq_bc65d673 (v126 in all 32 seats, 2
  episodes, 1 credit): BOTH COMPLETED on the platform ("lime win"), so the
  orchestrator runs end to end hosted. Content: 1 kill, deaths 0.95/seat
  (zone), and 6 TEAM KILLS across 64 seats → mean league score -0.6
  [-2.2, +1.1]: with everyone holding fire until eight teams remain, the
  zone decides, and whatever fired hit its own partner. Strategy defects
  for the S2 loop: hold-fire too long, partner in the corridor.
- local S2 vs the engine's canned starters (scripts/s2_local.py run, seed
  1200, our duo + 5/5/5 starter duos): completed; starter-collaborative won
  with the game's ONLY kill; our duo died to the zone with 0 kills. In the
  local self-mirror 7 of 9 kills were partner kills. Two defects for the S2
  loop: (1) hold-fire until 8 teams remain makes the game a zone lottery;
  (2) the engine body under our ladder shoots the partner. E2 (ladder
  parameters) and E3 (partner kills) briefs prepared.

## S2 partner kills — mechanism found (engine body read, cited in the E3 report)

- the deployed shell feeds the ladder guards a ZERO-valued context every
  tick (episode.nim:437/982 on origin/main 27e9cac1): `self.hp_frac < 0.67`
  reads `0 < 0.67` (always true) and `220 < partner.dist` reads `220 < 0`
  (never). So `supply_run` wins the ladder on every seat and, at full hp,
  emits Hold — shadowing bodyguard and edge_ride entirely
  (server log: `supply_run:hold` installed on all 32 seats). Movement came
  only from the zone reflex, which has no partner input, so both cogs of a
  duo took identical paths and stood on the same pixel.
- the body's bullet-corridor check scans fresh visible tracks, and the
  server strips teammates from visible tracks; `partnerGrant` (exact
  partner telemetry) is never consulted, so a cog fires through its
  co-located partner (body.nim:732, server.nim:3523/3540). No feud: the
  return-fire path is not wired in this adapter.
- consequences: (1) every E2 parameter of edge_ride/bodyguard was inert
  behind the supply_run shadow; (2) `never: ["duo:<team>"]` alone cannot
  stop the corridor hit on this engine; (3) variants under test: A
  never-duo, B edge-leader, C no-supply (drop supply_run so edge_ride
  drives); self-mirror batches seeds 1400-1403 on ports 2021-2024.

## S2 E2 screens (local, 8 rotated seeds, 8/8 duos vs HEAD build /tmp/e2-bot-head): all LEVEL — and inert by construction

| variant | win share (treatment) | win share (HEAD) | kills/duo T vs H |
|---|---:|---:|---:|
| hold12 (holdTrigger aliveTeams 12) | 0.625 [0.25, 0.875] | 0.375 [0.125, 0.75] | 0.25 vs 0.19 |
| hold4 | 0.625 [0.25, 0.875] | 0.375 [0.0, 0.75] | 0.16 vs 0.08 |
| crossfire-any650 | 0.500 | 0.500 | 0.17 vs 0.13 |
| margin120 | 0.375 | 0.625 | 0.16 vs 0.09 |
| phase-partner-recall | 0.500 | 0.500 | 0.17 vs 0.13 |
| jackal-never | 0.500 | 0.500 | 0.19 vs 0.09 |

- every interval covers zero at n=8; kills per duo 0.08-0.25 in every arm —
  the games are zone lotteries. Per the E3 mechanism the edge_ride/bodyguard
  parameters (margin120, coverbias) never executed (supply_run's always-true
  guard shadows them), so these screens measure noise. Superseded by the
  guard-free ladder (E4).

## S2 E3 self-mirror batches (16 duos of one build, seeds 1400-1403): partner kills vs enemy kills

| build | partner kills (4 games) | enemy kills | game ticks |
|---|---:|---:|---|
| HEAD (v126 ladder) | 12 | 8 | 1922, 1281, 1806, 1793 |
| A never:["duo:<own team>"] | 0 | **0** | 1835, 1842, 1833, 3397 |
| B edge-leader (lower seat puts edge_ride first) | 11 | 8 | 1835, 1264, 1252, 1202 |
| C no-supply (drop supply_run: edge_ride drives) | 9 | 13 | 1207, 1268, 1796, 1206 |

- read: A's call was REJECTED by the engine (`unknownReference:
  call.plays[0].params.never[0]` for `duo:red`), the hardened fallback sent
  edge_ride alone, and with no target_law overlay nobody fired at all — so
  the `never` spelling is wrong on this engine AND a call without target_law
  never shoots. C proves the shadow: with supply_run removed the
  duos move and enemy kills rise (13 vs 8), but partner kills persist
  because both cogs still take identical routes and the body fires through
  a co-located partner. The fix must be geometric (asymmetric routes,
  no fight phase while stacked) — the E4 guard-free ladder brief.

### 2026-09-01 — E4 guard-free ladder: reference spelling settled
- `never:["duo:<team>"]` is rejected by the deployed validator (`unknownReference`, duo lookup unconfigured at call time); `never:["seat:<a>","seat:<b>"]` for the duo's two seats is accepted (`call_accepted` at tick 84, local server built from engine-main-v40).
- The first E4 self-mirror batch (16:05) ran a stale `/tmp/e4-bot-e4-base` built before the worker's seat-ref fix (binary rebuilt 16:06:16, batch launched 16:05): every call rejected, edge_ride-only fallback, no fire. Batch discarded; rerun launched with the final binaries (seeds 1400-1403, ports 2031/2032).

### 2026-09-01 — hosted rotated A/Bs pooled (classic battle-royale, post engine fix)
- v122 vs focusfire:v52 / claude-paintbot-baseline:v2 / luis-paintbot-baseline:v4, 4 rotated groups x 4 episodes: **15/16 wins**, league score 31.8/seat [25.5, 37.4], 0.97 kills/seat, 0 team kills. Opponents 0 wins, <=0.25 kills/seat.
- v123 (BR port v2) same design, fresh episodes: **16/16 wins**, 48.5/seat [36.2, 63.7], 1.08 kills/seat, 0 team kills. Intervals do not overlap; matches the local promotion of port v2.
- The waiters' pool step passed the four ids as one argument (422); pooled by hand afterwards.

### 2026-09-01 — E4 self-mirror gate FAILED; mechanism refined
- e4-base (M=220, offset 80): same-colour kills 9, enemy kills 7 over seeds 1400-1403. e4-m120: 7 vs 6. HEAD was 12 vs 8. Calls accepted (seat refs), low_hp/zone_urgent re-calls accepted.
- seed 1402 server log: ticks 0-700 nobody moves; from ~700 ~25/32 seats aim, 2-7 move. First gunfire at tick 1461 is duo pale-blue's two seats hitting each other on the same tick, again at 1480/1499 (gun cadence), both dead 1499; red identical 1479/1498/1517. The duo is still stacked on its spawn pixel when the hold releases: edge_ride holds when already inside its margin band, so the margin asymmetry never separates the partners.
- bodyguard pushes away from the ward below leashMin (bodyguard.nim:116) → E5: asymmetric formation (leader edge_ride-first, follower bodyguard-first with leash [128,260]) plus a geometry log line.
- Addendum: E4's low-HP rule (`hp_frac < 0.67`) misfired on 1190 of 128 seats' games at tick ~742: zone phase 1 (dps 3 from ~tick 558) takes one point from stationary 3-hp cogs and 2/3 = 0.667 < 0.67, so every seat ran supply_run-first from tick ~749 — the HEAD shadow again. The E4 gate therefore never measured the formation. E5 brief amended (hp <= 1 only; geo log with partner_d, zone_next, ticks_to_shrink). Nobody moves in ticks 0-700 although edge_ride should enter the next rect at ticksToShrink <= 120: view may lack next/ticksToShrink — E5 checks.

### 2026-09-01 — E5 formation: partner is invisible to plays
- E5 worker (8 min): leader edge_ride-first, follower bodyguard-first leash [128,260], low HP = hp<=1, `[s2] geo` log. Binaries /tmp/e5-bot-{e4base,e5-sep128,e5-sep200,e5-sym128}, patches /tmp/e5-*.patch, runbook /tmp/e5-runbook.md. Tests 11/11 + 3/3.
- Gate seed 1400 (sep128), first 96 geo lines across all 32 seats: `partner_d=-1` everywhere. server.nim:3536-3541 skips same-team players when building visibleTracks (the partner reaches the body only as a separate PartnerSample), and the play view serialises only tracks, so bodyguard/crossfire never see their ward and hold. Formation via bodyguard cannot work on this engine; the only separation lever left is edge_ride's margin asymmetry (220 vs 300), which E5 also carries because zone_urgent (inside the margin band) is the phase from tick 740 onward. Also: ticks_to_shrink=344 at tick 740, zone_next=1 — the view does carry the next rect.
- v124 rotated hosted A/B (same three opponents, 4 groups x 4 episodes): **16/16 wins**, 42.7/seat, 1.16 kills/seat, 0 team kills (xreq_10e4c3e5, xreq_4a6c1e07, xreq_c3e44af1, xreq_e0d48dba). Classic path: v122 15/16, v123 16/16, v124 16/16. Note: zsh does not word-split unquoted variables, which is why every scripted pool call passed the ids as one argument (422).
- E5 gates (seeds 1400-1403, 16:39): e5-sep128 partner kills 9 / enemy 9; e5-sym128 10 / 11. FAILED. Seed 1402 reproduces E4's pattern exactly (pale blue seats hit each other 1464/1483/1502; red 1476/1495/1514) — the follower's margin 300 vs leader 220 does not separate them. Enemy kills per game 1-5; most seats die to the zone.
- Stopped 2026-09-01 16:42 PDT (user leaving); tree restored to HEAD, E5 sep128 kept as research/s2_patches/e5-sep128.patch. Codex worker done; local server processes killed; watchers stopped.

## 2026-09-02 00:00-00:40 PDT — Season 2 went live overnight; we were disqualified on a wrong diagnosis
- League renamed "Paintbot (Season 2)", coworld cow_201c865a (engine 0.7.287 = 4fad9987; 83 commits past our pin). Variant `battle-royale-s2`: **8 duos / 16 seats** (partner k/k+8), fresh certified map per episode from a 64-map pool (`mapPath: brpool`, no fixed map any more), socket 0xB1 views are JSON (12d3ab74), 0xB0 roster carries display names (09e9b902), the body's navigation was fixed (75fceb5a: cogs stood still until the zone killed them — reflex candidate lattice, planning budget, cancelled plans; league round 3633 evidence), starters no longer die on LLM failures (59a765d4). Rounds every ~10 min since ~06:00Z, 3-4 entrants.
- Our v126 membership (lpm_822dc768) disqualified at 03:41Z with note: "Image ignores injected endpoint (dials baked-in ws://127.0.0.1:21815) -> connection refused, exit 1, episode-fatal pre-connect. Evidence: rounds 3614-3622 slots 1/9. Resubmit a fixed image to return." Checked every round we played (3608-3622, 15 rounds, all `failed`): the failing pod was never ours — starters (slots 2/4/7/14/25), lessandro v2 (slot 1) or focusfire-s2 (slot 1). Our bot reads COWORLD_PLAYER_WS_URL and has no baked-in address (bot/baseline.nim:276; no "21815" anywhere in the repo). Local `coworld run-episode` of the v126 image on the new coworld (default variant) connected, played and exited cleanly in all 16 seats.
- Competing now: lessandro-forum-power-user-envoy:v3 (champion, 31.5/seat, 25% win over 24 eps), Monet:v4, paintbot-huddle:v2, paintbot-focusfire-s2, codex-paintbot-t1-s2-collaborative(-target), starters v3 as fillers. 639 memberships disqualified, 9 competing.
- Harness: scripts/s2_local.py now derives SEATS/DUOS from the config (16 or 32); /tmp/johomax-s2-config-16.json = round 3643's game_config + 16 tokens. Local server rebuild from origin/main (6a913ebb) → /tmp/johomax-ctf-server-runtime3 in progress; E3-E5 findings were measured on the OLD body (v40) and must be re-measured.
- Local `coworld run-episode --variant battle-royale-s2` with the v126 image (16 seats ours): mode season2, partner=9 from the 0xB0 context, first call accepted at tick 53, then EVERY seat logged "Error receiving WebSocket frame (received 0 of 2 bytes)" and a reconnect loop with "Name does not resolve"; the server printed "Dropped message to disconnected client" and ran the game on default plays (moving=0 all game, 8 team kills, seats 1/9 "won" with -41). Suspects: the amd64 image under Rosetta/OrbStack (the default-variant smoke showed the same read error at game end), not the server. Control: same run with the engine's own baseline player (running). Hosted truth: xreq_84c6885e (v126 self-mirror x4) and xreq_113c1677 (v126 vs starters v3 x4), 4 credits, policy logs available for own requests.
- scripts/br_xp.py SEATS 32 -> 16 (4 groups still hold slots g, g+4, g+8, g+12 = two duos each). Local server rebuild from origin/main is blocked: the engine now needs a newer wasmtime C API (wasmtime_config_wasm_threads_set / gc_support_set / branch_hinting_set are absent from the 40.0.2 headers at /tmp/wasmtime40-c-api).
- Hosted checks on 0.7.287 (16 seats): self-mirror xreq_84c6885e 4/4 episodes completed, 5.3/seat, **14 team kills**; vs starters v3 xreq_113c1677 4/4 completed, v126 **0 wins, 0.0/seat**, starter-aggressive 21.6/seat (37.5% win). No pod failures — the image runs on hosted. Policy log (agent 1): call accepted at tick 110, then "view ignored kind=json_shape" (the empty `{}` sentinel view), then "Error receiving WebSocket frame (received 0 of 2 bytes)" and "Connection refused" on reconnect — the SERVER closes our socket right after the first accepted call, so v126 plays the whole game on the engine's default play. Reproduced natively on the rebuilt local server (episodes/e6-head-s1500: all 16 seats dropped at tick 52; 7 partner / 2 enemy kills). Candidate mechanism: server.nim dispatchPlaySeatMessage disconnects on `piiDisconnect` = MaxMessagesClassifiedPerSeatPerTick 64 / MaxBytesClassifiedPerSeatPerTick 512 KiB ("first past disconnects"); instrumented server run in progress to confirm.
- Instrumented local server: the per-tick classification budget (64 msgs / 512 KiB) is never hit and neither `disconnectWebSocket` nor the main-loop close list fires for our seats (stack-trace build, seed 1500); the client sees a raw EOF (no websocket Close frame). Remaining suspect: the mummy transport limits on the play socket (MaxOutboundEvents 256 / MaxOutboundBytes 2 MiB, MaxPendingSocketEvents 128 / 1 MiB) — a queue overflow closes the connection below the server code. Wire-probe client build running to record the frames just before the cut.
- Wire probe (client -d:wireProbe, seed 1500): the frames before the EOF are the periodic 159-byte lobby view packets; no Close frame, no oversized frame. The cut coincides with "game started". `git bisect run` launched between the old worktree's commit (engine-main-v40, kept sockets all game) and origin/main 6a913ebb, test = one local 16-seat (fallback 32-seat) self-mirror and grep for "received 0 of 2 bytes" after "call accepted".
- Why we were disqualified (engine docs/coordination/agents-notes.md, 2026-09-01 22:1xZ-22:5xZ): James ordered ALL 583 classic Paintbot memberships retired ("their bots cannot drive play seats"); our v126 submitted at 22:28Z was a post-retirement "straggler" and was retired again at 03:41Z with a note copied from the starters' own bug (starter harness dialled a baked-in localhost; fixed in 86699ce5). "No shim; porting via policies/starters/ is the path." League settings: scheduler team_n 8, variant battle-royale-s2 only, disqualify after 3 consecutive failures, qualification = 1 self-play episode, daily credits by rank 200/100/50 at 14:00 PT.
- Bisect result: every tested commit from 4c8df343 (the first after v40's 27e9cac1) to origin/main dropped the sockets, with the 32-seat config where brpool did not exist — so the "first bad commit" is the range start and 27e9cac1 itself was never tested. Suspect the setup rather than the engine: cross-test running (today's bot vs the old runtime2 server; yesterday's /tmp/e4-bot-head vs the new runtime3 server).
- Cross-test (seed 1500): today's bot vs the OLD runtime2 server AND yesterday's /tmp/e4-bot-head vs the new runtime3 server both drop right after call_accepted — yet yesterday's E4/E5 logs (seeds 1400-1403) show the same bot binary keeping its socket through the whole game (re-calls accepted at ticks 751/974, "received 0 of 2 bytes" only at game over). Prepared configs differ only in the seed. Testing seeds 1400/1401 on both servers.
- Replay of yesterday's exact command (old harness file from a9ed25f, /tmp/johomax-ctf-server-runtime2 built 14:59 Sep 1, /tmp/e4-bot-head, seed 1400, 32 seats, --seconds 900, port 2031) DROPS today at tick 85, while the same command kept the socket for the whole game yesterday. Load 1.1, nothing else running. Seed-independent (1400/1401/1500), server-independent (v40/v41), client-build-independent. => timing / machine-state dependent; instrumenting the mummy websocket close sites next.

### 2026-09-02 01:05 PDT — CORRECTION: there is no socket drop
- Codex read of the probe evidence: the EOF after "call accepted" is the normal end of the one-game episode (maxGames 1 → httpServer.close() → mummy destroys every client socket without a Close frame; server.nim:5370, mummy.nim:1501). Our seat logs nothing between the accepted call and the EOF because valid views are silent and no phase change fired; the 774-793-byte Playing views DID arrive (probe bot_0.log:166), the 159-byte packets afterwards are status-only views sent to a DEAD seat, and the hosted "json_shape" line is the `{}` no-source sentinel after our death. Yesterday's E4/E5 logs show the same EOF at game end. ~1.5 h of bisect/instrumentation chased a non-bug; lesson: check the server's winner line and tick count before calling an EOF a drop.
- Fixes in the tree: `{}` view now decodes as ignore (shell_view.nim, engine-generated JSON fixtures in shell_view_test, 6/6); season-2 reconnects bounded to 12 x 250 ms then `quit(0)` like the legacy path (bot/baseline.nim) so hosted pods exit cleanly. No 32-seat assumptions remain in shell_seat.nim (partner from `duo_partner`).
- Starters' recipes (local canned run, seed 1400; 16 starters: 1 partner kill / 3 enemy kills, 4697 ticks): aggressive = edge_ride{margin 60, enterLead 40, coverBias .25} then + target_law{prefer weakened,isolated} (no hold); cautious = edge_ride{margin 420, enterLead 320, coverBias 1.0} + target_law{holdTrigger aliveTeams 6}, recall supply_run{whenHpBelow 5, detourMax 900} + edge_ride{margin 340, enterLead 300}; collaborative = pact{partners:["seat:N"], protect true, onBetrayal disengage} + bodyguard{ward "seat:N", interpose true, leash [60,180], peelHp 3} + crossfire{minAngle 40, spacing [100,260]}. Hosted (xreq_113c1677): starter-aggressive 21.6/seat and 37.5% wins vs our v126 0.
- Public replays carry every seat's accepted play calls in clear text (`grep -a -o '{"plays":...}'` on episodes/replays/*.replay from round 3649 shows the starters' recipes and a jackal-based ladder `edge_ride{margin 100-140, enterLead 60-80, coverBias .3-.5} + jackal{earshot 500-600, exitAfter kills 1, joinWhen afterKill} + target_law{prefer weakened,isolated}` from another entrant). E8 launched: (a) replay miner (worktree /tmp/johomax-replay → analysis/s2_replays.py, report on rounds 3630-3649 per policy), (b) env-configurable opening call / re-call schedule (S2_OPENING_CALL, S2_RECALLS, `$PARTNER`) + embedded `pact`, with a runbook of one-duo-vs-starters batches per recipe.
- v127 candidate (clean exit + `{}` sentinel) local sanity, seed 1400, new server: self-mirror 16 seats → 2 partner / 7 enemy kills, 1831 ticks, exit path "reconnect 1/12" then quit; one duo vs 14 starter seats → our duo 1 death / 3 kills, silver (a starter duo) won at tick 4591. Ship after the E8 env-override worker lands (same files).
- E8 landed (uncommitted → this commit): S2_OPENING_CALL / S2_RECALLS env overrides with $PARTNER/$SELF placeholders, selective module upload, `pact` embedded as the 7th play (31,725 B), s2_local.py `--bot-env-file LABEL=PATH` + team-kills/ep column; tests 6/6 + 6/6 + harness 9/9. Runbook /tmp/e8-runbook.md (R1 aggressive, R2 cautious, R3 collaborative pact+bodyguard+crossfire, R4 control, R5 collaborative+target_law hold 6; one duo vs 14 starter seats n=6; self-mirrors n=2). Replay miner analysis/s2_replays.py in worktree /tmp/johomax-replay (decoded 86 accepted calls from the two round-3649 replays; network fetch to be run by me).
- **v127 uploaded and submitted** 2026-09-02 ~08:10Z (auto-champion always; policy-version 34778b52): v126 strategy + clean exit at episode end + `{}` sentinel decode + env-configurable ladder (inert by default) + pact embedded. Purpose: re-enter the ladder; strategy changes follow E8.
- Replay mining (rounds 3630-3636, 52 episodes, 832 seats; analysis/s2_replays.py in worktree /tmp/johomax-replay, report research/s2_replays/report_3630_3649.md there): win rate / mean score / kills / team kills — starter-aggressive 16.5% / 4.90 / 38 / 25; starter-cautious 16.2% / 2.92 / 0 / 0 (never fires); codex-t1-collaborative-target 9.6% / 2.42 / 20 / 21; paintbot-huddle:v2 12.5% / 2.25 / 6 / 3; starter-collaborative 9.0% / 1.88 / 55 / 41 (pact+bodyguard+crossfire kills partners most); Monet v3/v4 16%/4% with a custom `hold_vs_gun` play carrying a `when` guard on world.nearest_enemy_dist / partner.in_combat. Hosted ladders: aggressive = edge_ride{margin 140, enterLead 80, coverBias .5} + jackal{earshot 600, exitAfter kills 1, joinWhen afterKill} + target_law{prefer}; huddle v2 = target_law{holdTrigger aliveTeams 4 (or 8), prefer} + edge_ride{280, 220, .85}; codex-t1 = pact{$partner, protect} + target_law{never partner, prefer weakened/isolated/revenge} + edge_ride{260,180,.85}, re-call + bodyguard{leash 60-180, interpose} + crossfire{minAngle 40, spacing 100-260}. lessandro v3 (champion) is in rounds >= 3641 — second fetch running. New env recipes: R6 hosted-aggressive, R7 huddle-v2, R8 codex-t1 opening.
- **Champion ladder (lessandro-forum-power-user-envoy:v3, rounds 3641-3644, 56 seats: 25% wins, 29.0 mean score, 41 kills / 47 deaths / 10 team kills)**: an LLM "envoy" that negotiates ALLIANCES in the huddle — `pact{partners:[own partner + another duo's seats], protect true, onBetrayal returnFire}` + `target_law{holdTrigger aliveTeams 3, never [all allies], prefer revenge, weakened}` + `bodyguard{ward own partner, interpose true, leash [0,400-1300], peelHp 64}` (stick to the partner, always peel), later + `edge_ride{margin 240, enterLead 120, coverBias 0.8}`; re-calls at ~t700/1030/1357 shrink the partner list as allies die. Holds fire until 3 teams remain, then collects kills (~116 glory per win). Monet:v4 (12.5%, 5.6) also pacts with two other seats. Our client never chats and has no allies. New recipes: R9 champion-like (own-duo pact + hold 3 + bodyguard peel, edge_ride re-call at t1300), R10 same with edge_ride from the start.
- Timing (92 mined episodes): mean alive seats 15.0 @t1000, 9.9 @t1500, 5.2 @t2000, 2.8 @t2500; final tick median 2656. Median death tick ~1500-1740 for every policy (zone phases 2-3). Winning seats' kills: champion 1.93, Monet v4 1.00, codex 1.00, aggressive 0.91, huddle 0.71, cautious 0.00. => the game is decided between t1500 and t2500; holding fire until few teams remain and staying alive through the zone squeeze is what the score rewards.
- **v127 qualified and competing** (08:25Z: "All 1 qualification episodes passed the gate", champion of our memberships). First round with us: 3652 (6 entrants). Harness now counts `survived` seats and `draw` episodes from the clear_on_death annotations (R1 seed 1400 was a draw at tick 5478 with zero gun kills; our duo survived to the end but a draw scores nobody).
- E8 wave 1 (one duo vs 14 starter seats, seeds 1400-1405, local): R1 aggressive recipe 0/5 wins, R2 cautious 1/6, R3 collaborative 0/5; starter-aggressive duos won 50-60% of games (≈17-20% per duo), collaborative ≈10-17%, cautious 0-10%. Our duo matches the starter running the same recipe within noise (n≈5 is far too small: one win = 17%). Local games have 7 gun kills each; FIRST_LIGHT_MOVEMENT moving/aiming counters read 0 on this engine (ignore them). Next: 4 of our duos per game vs 4 starter duos, n=8, to quadruple duo-samples per hour.
- **Round 3652 (first with v127, 12 episodes, 6 entrants + fillers): v127 31.6/seat, 25% wins (3/12), 0.75 kills/seat, 12.5% alive at end — top of the round**; nancy-paintbot-s2:v3 (new) 24.8, lessandro v3 13.5 (25% wins but fewer kills), Monet v4 4.0, huddle v4 0, codex-t1 0. The existing ladder works on the fixed engine.
- Division leaderboard 08:40Z (standing = max round mean): 1 softmaxwell/Monet 36.75 (24 rounds), 2 lessandro 32.67 (12), **3 Jordan/v127 31.58 (2 rounds)**, 4 codex-t1 26.67, 5 NanosaurusX/nancy 24.83, 6 daveey 11.17. A round with 4 wins of 12 at ~126 glory per win ≈ 42/seat would take rank 1; every extra round is another draw from the distribution.
- Round 3652 per seat (replay miner): our 3 wins scored 158 (3+2 kills), 45 (1 kill), 176 (7 kills); 4 partner kills in 12 episodes; deaths mostly at ticks 1229-1860 (zone phases 2-3); placements 4-7 when losing; 1 call per seat (we never re-call), lessandro 3, Monet 3.5. Glory per win is driven by kills, so the levers are: no partner kills, survive the t1200-1900 squeeze, and hunt late.
- E8 R9 (champion-like: pact + target_law hold 3/never partner + bodyguard peelHp 64, edge_ride re-call t1300; one duo vs starters, n=6): 1/6 wins, 0 kills, 0 team kills, survival 0.25/seat (best label); aggressive starters 3/6. Locally only the collaborative starters (crossfire) ever shoot; aggressive starters and every edge_ride-first recipe score 0 kills, unlike hosted (aggressive starters 0.33 kills/seat). Local screening is informative for survival and partner kills, not for kills; hosted rounds are the arbiter.
- **E8 wave 1 is VOID**: every env-configured opening call was rejected `nonCanonical:call` (the override sent the JSON verbatim with unsorted keys); the seats then ran the edge_ride-only rejection fallback, so R1/R2/R3/R9 all measured the same thing. The 4-duo R6/R7 batches were stopped. Fix: canonicalize the configured JSON (sorted keys, compact) before sending.
- Canonical fix verified (seed 1421, 16 seats R9): opening accepted id=1 tick 36, re-call accepted id=2 at tick 1301. E8 relaunched with 4 of our duos vs 4 starter duos, n=8 (seeds 1410-1417): R9 champion-like, R6 hosted-aggressive, R4 control (v127 ladder), then R7/R10/R8.
- **v128 is broken**: Docker expands `$PARTNER` inside `ENV` at build time, so the baked recipe carries `"partners":[""]`/`"never":[""]` — rejected on the server, edge_ride-only fallback. ship.sh now escapes `$`; v129 rebuilt from the same recipe replaces it (auto-champion).
- v129 uploaded 09:00Z with the placeholders intact (image env verified: `"partners":["$PARTNER"]`) and submitted (auto-champion always); v128's membership retired while still qualifying.
- v129 placed champion 08:59Z (v127 benched). v127's hosted baseline: rounds 3652/3653/3654 → 31.6 / 5.0 / 0.0 per seat (4 wins in 36 episodes, 12.2 mean). analysis/s2_rounds.py prints per-round means per version.
- v127 per round (analysis/s2_rounds.py): 3652 31.6 (3 wins, 18 kills, tk 4); 3653 5.0 (1, 15, tk 6); 3654 0.0 (0, 2, tk 10); 3655 0.0 (0, 8, tk 14). Team kills climb to more than one per episode — the partner-kill mechanism dominates hosted results; v129 (pact protect + never partner) is the direct test.
- Hosted mechanism confirmed (rounds 3654-3655 replays): 11 of 24 of our duos died on the SAME tick with tk 1/1 — mutual partner kills at ticks 883-1781, mostly right after the hold releases (aliveTeams ≤ 8 ≈ t900-1300). Same stacked-duo corridor as local. Lever: separate the seats before the hold releases (per-seat asymmetric opening: `S2_UPPER_OPENING_CALL` for the upper seat) and/or hold longer.
- Leaderboard 09:00Z: codex-t1 53.58 (r27), lessandro 45.33 (r14), NanosaurusX 42.50 (r5), Monet 36.75, **Jordan 31.58 (rank 5)**, daveey 11.17. Standing = max round mean, so the leaders' big rounds (4-5 wins of 12) set the bar at ~54/seat; the way up is a consistently strong champion in every round.
- v129 round 3656: 4.8/seat, 1 win, 11 kills, **tk 12** — pact protect + never partner does not stop the mutual kills on hosted. Local self-mirror A/B (seeds 1430-1433, 16 seats): control (v127 ladder) tk 1/1/1/2, v129 recipe tk 2/1/1/5, v131 (upper seat edge_ride margin 320) byte-identical to v129 in kills/tk/ticks → the movement controller's margin changes nothing (reflex zone-escape dominates movement); pact/never changes nothing for partner kills. Next: make only ONE seat of the duo fire (upper seat holdTrigger aliveTeams 2 = never) so simultaneous corridor shots cannot happen (v132), and v133 = same plus supply_run-first for the upper seat.
- E8 four-duo sweep (4 of our duos vs 2 aggressive + 1 cautious + 1 collaborative starter duos, seeds 1410-1417, n=8; win share = any of our duos won): R4 control (v127 ladder) 0.75, 1.63 kills/duo, 1.50 team kills/ep; R6 hosted-aggressive (edge_ride 140/80/.5 + jackal + target_law no hold) 0.75, 1.69, 1.88; R9 champion-like (pact + hold 3 + bodyguard peel) 0.50, 0.28 kills/duo, 0.25 tk/ep. Locally our ladder already beats the canned starters; the champion-like hold trades kills (glory) for fewer partner kills.
- Engine blind spot (body.nim:369-382 `pointBlocksSegment`): a protected point blocks a shot only when `0 < along < range`; a partner on the same pixel (along ≈ 0) never blocks, so `pact protect`/`never` cannot prevent the stacked-duo mutual kill. Only geometry (partners apart before the first shot) or a single shooter per duo can, from our side.
- Single-shooter self-mirrors (seeds 1430-1433): v132 (upper seat hold 2 = never fires) tk 2/3/1/2, kills 10/12/5/10; v133 (+ supply_run-first for the upper seat) byte-identical. The upper seat's installs carry `hold_fire:true` all game, so the remaining partner kills are the LOWER seat's own bullets hitting its co-located partner (any shot from a stacked cog can hit the overlapping partner). Both seats' movement is the reflex zone-escape ~170 installs vs 1-2 controller installs: reflexes.nim triggers when `zoneTicksUntilOutside <= 72` and releases at > 96, so a cog riding the edge at margin 220 is reflex-driven all game and the two seats follow identical paths. Test: upper seat margin 600 / 420 to keep it deep enough for the controller to drive it apart.
- v129 round 3657: 9.2/seat, **4 wins** of 12, 12 kills, tk 4 (wins worth ~55 each — survival wins with few kills). v129 so far: 4.8, 9.2.
- Why no play moves the duo apart: episode.nim:805-816 `zoneTicksUntilOutside(point)` is 0 outside the rect and otherwise `ticksToShrink` regardless of position, so once the zone shrinks continuously (phases 1+, waitTicks 0) the escape reflex is on for every cog every tick and controllers only drive during the lobby/phase-0 wait; spawns are central, inside every edge_ride band, so edge_ride holds; supply_run/jackal/bodyguard/crossfire hold without a known item/gunfire/partner track. => write our own play (`spread_out`: the upper seat walks a fixed 150-200 px away at game start), E9.
- v136/v137 (upper seat edge_ride margin 600 / 420) self-mirrors byte-identical to v129's (seat 9: 177 reflex installs, 2 controller installs). Confirms the controller never drives once the zone shrinks; E9 (custom `spread_out` play acting during the lobby/phase-0 window) is the separation path.
- v129 round 3658: 0.0, 5 kills, tk 8. v129 over 3 rounds: 4.8 / 9.2 / 0.0 (kills 11/12/5, tk 12/4/8) vs v127's 31.6 / 5.0 / 0 / 0 (kills 18/15/2/8). Leaderboard 09:30Z: codex 53.58, lessandro 45.33, nancy 42.50, Monet 36.75, daveey 33.25, **Jordan 31.58 (rank 6)**. Rotating in v138 = hosted-aggressive recipe (edge_ride 140/80/.5 + jackal{earshot 600, exitAfter kills 1, joinWhen afterKill} + target_law{prefer}, no hold) + pact/never partner — the local sweep's highest-kill recipe.
- v130 uploaded and submitted 09:38Z (aggressive jackal recipe + pact/never; placeholders verified in the image).
- v130 placed champion 09:36Z (v129 benched after rounds 3656-3658).
- E8 four-duo R7 (huddle-v2 recipe: target_law{holdTrigger aliveTeams 4, prefer} + edge_ride{280,220,.85}; seeds 1410-1417): win share **0.875** [0.625, 1.0], 0.88 kills/duo, 0.50 tk/ep — vs control 0.75 / 1.63 / 1.50. Holding fire until 4 teams remain wins more games locally with a third of the partner kills. Extending both arms to seeds 1418-1425; hosted candidate v131h = R7 + pact/never.
- E9 landed: custom play `spread_out` (bot/plays/spread_out.nim → playbook_spread_out.nim, 11 KB wasm via the freestanding Zig path; params distance/bearing_brads/mirror; navigates to first-step position + distance·unit(bearing) then holds), build_playbook.sh discovers bot/plays/, shell_seat gates uploads on it. Gates running: e9-a (upper seat spread_out{180} first, then edge_ride) and e9-b (both seats spread_out mirrored 120) self-mirrors seeds 1430-1433 vs control tk 1/1/1/2.
- v129 round 3659 (its last before v130): 9.9, 2 wins, 16 kills, tk 4. v129 over 4 rounds: 4.8 / 9.2 / 0.0 / 9.9 (mean 6.0; v127's 4-round mean 9.2 carried by its 31.6 opener).
- E8 four-duo R10 (champion-like with edge_ride from the start): 0.50 win share, 0.31 kills/duo, 0.25 tk/ep — same as R9. Local ranking by win share: hold-4 (R7) 0.875 > control 0.75 ≈ hosted-aggressive (R6) 0.75 > hold-3 (R9/R10) 0.50.
- v131 uploaded 09:42Z (hold-4 huddle recipe + pact/never; env verified), NOT submitted yet: rotation scheduled for ~10:15Z after v130 has three rounds.
- **E9 gate PASSED**: e9-a (upper seat opens `spread_out{distance 180}` then overlays + edge_ride; lower seat = v129 recipe) self-mirrors seeds 1430-1433: **tk 0/0/0/0**, kills 12/7/6/8 (control tk 1/1/1/2); e9-b (both seats spread mirrored 120) tk 0/3/0/0. The upper seat's installs show spread_out driving before the reflex takes over. Rotation plan changed: v132 = e9-a recipe ships now (v131 hold-4 stays unsubmitted); v133 = spread + hold 4 follows.
- **v130 round 3660: 40.4/seat** (2 wins, 18 kills, tk 3) — our best round; the aggressive jackal recipe converts kills into glory. v132 (spread_out upper seat on the v129 base) was submitted 09:49Z and will replace v130 shortly; next: v134 = v130's jackal recipe + spread_out for the upper seat.
- Version map (server-assigned): v131 = hold-4 huddle recipe + pact/never (uploaded, unsubmitted); v132 = spread_out upper seat on the v129 base (submitted 09:49Z); **v133** = jackal recipe + spread_out (uploaded 09:55Z, unsubmitted; the ledger's "v134" above means this one).
- Hold-4 vs control pooled over 16 games (4 duos vs starters, seeds 1410-1425): win share 0.875 vs 0.875; kills/duo 0.73 vs 1.53; team kills/ep 0.56 vs 1.50; survived/seat 0.18 vs 0.16. Same wins, half the kills — on hosted the glory comes from kills (v130's 40.4), so v131 (hold-4) stays unsubmitted.
- v132 placed champion 09:56Z (spread_out upper seat on the v129 base); v130 benched.
- v133-recipe (jackal + spread_out) self-mirror gate seeds 1430-1433: tk 0/1/0/1, kills 12/9/4/8, games shorter (1191/1228 ticks on two seeds). Partner kills mostly gone with the kill-oriented base; rotation to v133 scheduled for ~10:26Z after v132's third round.
- **v132 round 3661: 50.9/seat, 5 wins of 12, 39 kills, tk 5 → division rank 2 (50.92 vs codex-t1 53.58)**. The spread_out upper seat on the v129 base (hold 8, pact/never, edge_ride 220) both survives and kills. v133 rotation still scheduled for 10:26Z.
- e9-a (v132 recipe) four duos vs starters, seeds 1410-1417: win share 0.75, 1.31 kills/duo, 0.63 tk/ep (control pooled 0.875 / 1.53 / 1.50). Same fighting strength with less than half the partner kills.
- Round 3661 per duo (v132): wins scored 57 / 6 / 122 / 186 / 240 (kills 2, 3, 8, 2, 6 per duo); four losses placed 2nd; team kills 5, all from the lower (shooting) seat; same-tick duo deaths late (t1457-2671) with tk 0 = both killed by enemies/zone, not each other.
- v132 round 3662: 27.5, 3 wins, 24 kills, tk 1. v132 so far 50.9 / 27.5 (mean 39.2) — the best two consecutive rounds we have had.
- spread_out distance 300 self-mirror (seeds 1430-1433): tk 0/1/1/0, kills 12/9/9/11 — no better than 180 (tk 0/0/0/0); keep 180.
- Hold-6 variant of the v132 recipe, self-mirror seeds 1430-1433: tk 1/0/0/1, kills 7/5/2/7 (vs 12/7/6/8 at hold 8). Four-duo vs starters running.
- v132 three rounds: 50.9 / 27.5 / 20.2 (wins 5/3/4, kills 39/24/20, tk 5/1/2) — mean 32.9, the best version so far. v133 (jackal + spread) submitted 10:26Z for a three-round trial; if it underperforms, v132 is re-submitted.
- Hold-6 variant of the v132 recipe, four duos vs starters (seeds 1410-1417): win share 0.8750, kills/duo 1.188, tk/ep 0.625, survive/seat 0.188 — vs v132 recipe 0.75 / 1.31 / 0.63 / 0.19.
- Uploading the hold-6 spread recipe (both seats holdTrigger aliveTeams 6, upper seat spread_out 180) as the next queued version (unsubmitted) — candidate after v133's trial: locally 0.875 win share vs the v132 recipe's 0.75 with similar kills and partner kills.
- v134 = hold-6 spread recipe (uploaded 10:30Z, unsubmitted). Version map: v131 hold-4 (unsubmitted), v132 spread on v129 base (champion 09:56Z), v133 jackal + spread (submitted 10:26Z), v134 spread + hold 6 (unsubmitted).
- v133 placed champion 10:31Z (jackal + spread_out); v132 benched after 50.9 / 27.5 / 20.2. Checkpoint at 11:06Z compares v133's first rounds with v132's mean 32.9.
- Jackal + spread (v133 recipe) four duos vs starters, seeds 1410-1417: 0.75 win share, 1.25 kills/duo, 0.50 tk/ep, survive 0.22 (v132 recipe 0.75 / 1.31 / 0.63 / 0.19; hold-6 0.875 / 1.19 / 0.63 / 0.19). Hosted: v132 round 3664 26.9 (3 wins) → v132 four rounds 50.9 / 27.5 / 20.2 / 26.9 (mean 31.4); **v133 round 3665: 31.2, 5 wins, 26 kills, tk 3**. Extending the three recipes to seeds 1426-1433 locally.
- v133 three rounds: 31.2 / 18.4 / 12.6 (mean 20.7; wins 5/3/2, kills 26/18/25, tk 3/2/1) — below v132's 31.4. Standing unchanged (Jordan 50.92, rank 2). Next trial: v134 (spread + hold 6) for three rounds, then the best of v132/v134 stays.
- Local ranking pooled over 16 games (4 duos vs starters, seeds 1410-1417 + 1426-1433): **hold-6 spread 0.938** win share (1.16 kills/duo, 0.56 tk/ep) > v132 recipe 0.812 (1.23, 0.44) > jackal + spread 0.688 (1.19, 0.44). Consistent with hosted (v133 jackal < v132). v134 (hold-6 spread) is on its hosted trial; bracketing hold 4 and 5 with spread locally.
- v134 (spread + hold 6) placed champion 11:10Z; v133 benched after 31.2 / 18.4 / 12.6.
- Hold bracket (4 duos vs starters, seeds 1410-1417): hold-5 spread 0.875 win share, 1.00 kills/duo, 0.63 tk/ep; hold-4 spread 0.714 (7 games), 0.71 kills, 0.43 tk. Hold-6 stays the local best (0.938 over 16). Hosted: v133 round 3668 3.0 (4-round mean 16.3); **v134 round 3669: 25.0, 5 wins, 19 kills, tk 3**.
- Revenge preference on the hold-6 spread recipe (seeds 1410-1417): 0.875 win share, 1.19 kills/duo — no gain. Hosted v134 trial: 25.0 / 10.6 / 6.5 (mean 14.0; wins 5/2/1) — below v132's 31.4. A new entrant (co-gas-paint…) scored 24.2 in round 3671. **Re-submitting v132 (hold 8 + spread) as the long-run champion**; local rankings vs canned starters do not transfer to the hosted field, so future rotations need a stronger reason.
- Re-submitting v132 fails (409: the version already has an active, benched membership); shipping the identical recipe as v135 instead.
- v135 (identical to v132: spread_out upper seat, hold 8, pact/never, edge_ride 220) uploaded and submitted 11:46Z to restore the best recipe as champion.
- v134 mined: round 3670 placements [1,1,2,2,3,3,4,4,4,5,5,8], median death t2043; round 3671 placements [1,3,4,5,5,6,6,7,7,7,8,8], median death t1532 — holding until 6 teams remain leaves the duo to die in the mid-game squeeze without kills more often than hold 8.
- Huddle line (S2_LOBBY_CHAT, sent at the first 0xB0 context): rejected `lobby_chat:lcrClosed` — the chat window opens later (the starters' lines arrive at ordinals 1-34 during the lobby); adding a retry on the lobby views until our own text is echoed.
- v135 (= v132 recipe) placed champion 11:52Z; v134 benched after 25.0 / 10.6 / 6.5 (+ its fourth round if any).
- Huddle line works with retries: each of our seats saw its own broadcast after two lcrClosed rejections (local, seed 1440). v136 = v132 recipe + S2_LOBBY_CHAT truce offer ("we hold fire on everyone who holds fire on us until 4 teams remain; add us to your never list and we add you") — uploading now, submit after v135's three rounds (~12:26Z).
- v134 fourth round 3672: 13.2 (mean over 4: 13.8). Standings 11:52Z unchanged (codex 53.58, Jordan 50.92). v135 champion since 11:52Z; v136 (truce huddle line) submit scheduled 12:26Z.
- v135 (= v132 recipe) rounds 3673-3675: 13.4 / 8.5 / 3.8 (wins 1/1/1, kills 13/14/22, tk 5/2/1) — far below v132's 31.4 with the same recipe: the field changed. A new entrant **co-gas-paint…** posted 18.6 / 41.3 / 39.1 and appears with two memberships (two duos?) in round 3675. v136 (truce huddle line) submitted 12:26Z.
- Competing set 12:27Z: co-gas-paintbot-s2-cautious-relhalpha:v11 (relh, champion since 11:24Z) and co-gas-paintbot-s2-cautious-richard:v1 (richard, 11:46Z) — the "co-gas-paint…" rows are two players with a cautious recipe; Monet:v4; paintbot-huddle:v13 (daveey iterating every ~40 min); lessandro v3 benched; nancy v2 benched. Our v135 fell to 13.4 / 8.5 / 3.8 in that field.
- **richard's recipe (co-gas-paintbot-s2-cautious-richard:v1, 3 rounds: 18 wins of 36 duo-episodes, 32.5 mean, 69 kills, tk 2)**: a custom `edge_ride` module with a `scatterHeading` param (per-seat headings e.g. 20 vs 204 = opposite directions; margin 438-513, enterLead 378-402, coverBias 0.8) + `crossfire{minAngle 40, spacing [140,300]}` + `target_law{holdTrigger {tick: 1000}, never partner, prefer weakened/isolated}`, re-called at ~t700 with coverBias 0.9 (sometimes + supply_run whenHpBelow 4). The public engine's edge_ride has no scatterHeading (origin/main 6668d893), so it is their own separation play — the same idea as our spread_out. Transferable pieces: holdTrigger by TICK (1000) instead of aliveTeams 8, crossfire spacing, deep margin. relh v11 (same family, 14.4 mean) and nancy v3 (9.3) trail; lessandro v4 0.4.
- Round 3676: v135 10.7 (2 wins); co-gas-paint (richard) **54.9** — likely the new standing leader. v136 qualifying at 12:27Z.
- v137 uploaded 12:30Z (richard-like: pact + target_law{holdTrigger tick 1000, never partner} + crossfire{40, [140,300]} + edge_ride{438, 378, .8}; upper seat spread_out first), unsubmitted pending the local gate. Leaderboard 12:30Z: 1 richard 54.92 | 2 soft-codexter- 53.58 | 3 Jordan 50.92 | 4 @lessandro-for 45.33 | 5 NanosaurusX 42.50 | 6 softmaxwell 36.75 | 7 daveey 33.25 | 8 relh 24.17
- v136 (truce huddle line) placed champion 12:31Z. Standings 12:30Z: richard 54.92, codex 53.58, **Jordan 50.92 (rank 3)**, lessandro 45.33, nancy 42.50, Monet 36.75, daveey 33.25, relh 24.17.
- Tick-hold gates (seeds 1430-1433, 16-seat self-mirrors): v137a (v132 recipe with holdTrigger tick 1000) and v137b (richard-like + spread) both tk 0/0/0/0, kills 8/8/4/7, byte-identical games (crossfire/edge_ride params are inert under the reflex; the tick hold and spread_out are what act). Submitting v137 now; v136's truce trial is cut to one round and the truce line will be re-tested on top of v137 as v138.
- v137 submitted 12:38Z (auto-champion); v138 (v137 + truce huddle line) uploading as the next trial. Rotation rule stays three rounds per candidate; the current field (richard/relh cautious duos, huddle v13, Monet v4, nancy, codex) is the reference.
- v138 (v137 recipe + truce huddle line) uploaded 12:39Z, unsubmitted; rotation scheduled ~13:26Z after v137's three rounds.
- v137 placed champion 12:42Z (richard-like on spread_out); v136 benched after one round.
- v136 (truce line on the v132 recipe) round 3677: 4.5, 2 wins, 10 kills, tk 0 — the two co-gas duos scored 49.0 and 46.5 in the same round.
- Within the co-gas family: relh v11 (edge_ride scatter margin 280 + crossfire [150,320] + target_law never/prefer, NO holdTrigger) 14.4 mean vs richard v1 (same + holdTrigger tick 1000, margin 438-513) 32.5 — the tick hold is the difference. Mining round 3676-3677 for the duel between their duos and ours.
- Rounds 3676-3677 per policy (replay miner): richard 5 wins (33 kills, places 1×5) then 3 wins; relh 1 then 3; our v135 2 wins (21 kills, places 1,1,2,2,2,2,3,5×5) and v136 2 wins (10 kills). Median death ticks 1500-1900 for everyone; richard's edge is converting 2nd places into wins (kills late).
- v137 recipe (richard-like on spread_out) four duos vs starters, seeds 1410-1417: 0.75 win share, 1.19 kills/duo, 0.50 tk/ep — same as the v132 recipe locally (the canned field never tests the tick hold). Bracketing the release tick (800 / 1000 / 1300) locally anyway.
- Tick bracket vs starters (seeds 1410-1417): tick 1300 → 0.875 win share, 1.09 kills/duo, 0.63 tk/ep; tick 1000 → 0.75 / 1.19 / 0.50; tick 800 running. Hosted v137 round 3678: 7.2, 3 wins, 15 kills, tk 4.
- jordan-ctf-candidate:v139 uploaded 13:00Z = v137 recipe with holdTrigger tick 1300 (unsubmitted). Version map: v136 truce on v132 base; v137 richard-like (champion); v138 richard-like + truce (rotates 13:26Z); jordan-ctf-candidate:v139 tick 1300.
- v137 round 3679: 25.8, 4 wins, 22 kills, tk 1 (co-gas duos 16.3 / 16.2 in that round). v137 so far 7.2 / 25.8.
- Tick 800 vs starters (seeds 1410-1417): win share 0.8750, kills/duo 1.312, tk/ep 0.625. Bracket: 800 vs 1000 (0.75) vs 1300 (0.875) — the local field rewards later release.
- Correction: tick 800 gave 0.875 win share / 1.31 kills per duo, so the local bracket (800: 0.875, 1000: 0.75, 1300: 0.875) is inconclusive at n=8; the canned field cannot rank release ticks. Local recipe sweeps paused; hosted rotations (v137 → v138 → v139) are the measurement.
- Hosted engine now 0.7.289 (cow_84ae8404) — our images keep completing rounds across the 0.7.287→289 bumps.
- v137 three rounds: 7.2 / 25.8 / 17.2 (mean 16.7; wins 3/4/2, kills 15/22/17, tk 4/1/1). Standings 13:12Z: richard 54.92, codex 53.58, Jordan 50.92, relh 49.00, lessandro 45.33, nancy 42.50, Monet 36.75. v138 rotates in at 13:26Z.
- v137 round 3681: 26.6 (2 wins of 10 recorded, 18 kills, tk 2). v137 over four rounds 7.2 / 25.8 / 17.2 / 26.6 (mean 19.2) — the best in the co-gas field so far. v138 (truce line on v137) submitted 13:26Z.
- v138 placed champion 13:31Z (v137 + truce huddle line); v137 benched after 7.2 / 25.8 / 17.2 / 26.6.
- v137 fifth round 3682: 12.8 (3 wins) → v137 mean over 5 rounds 17.9. v138 first round 3683: 6.8, 1 win, 10 kills, tk 0.
- jordan-ctf-candidate:v140 uploaded 13:50Z = clone of the v137 recipe (unsubmitted), ready for the rotation back after the v138/v139 trials.
- Truce line verified on hosted: "Truce offer…" appears in 12/12 replays of rounds 3683-3684. v138 rounds: 6.8 / 3.8 (wins 1/1, kills 10/17) — worse than v137 (17.9); the huddle line does not help and may mark us as passive. Dropped: v139 (tick 1300, no truce) rotates in at 14:12Z; the 15:06Z auto-decision falls back to the v137 clone (v140) unless v139 beats it.
- v138 four rounds: 6.8 / 3.8 / -1.8 / 1.5 (mean 2.6) — the truce line is harmful. v139 (tick 1300) submitted 14:12Z. co-gas duos posted 54.2 and 56.2 in rounds 3685-3686. Leaderboard 14:13Z: 1 richard 56.17 | 2 soft-codexter- 53.58 | 3 Jordan 50.92 | 4 relh 49.00 | 5 @lessandro-for 45.33 | 6 NanosaurusX 42.50 | 7 softmaxwell 36.75 | 8 daveey 33.25
- v139 (tick 1300) placed champion 14:17Z; v138 benched.
- 15:04Z decision checkpoint (means since 3661): v132 31.4 (4 rounds, old field), v137 17.9 (5), v133 16.3, v139 14.7 (5: 6.8/20.7/15.3/15.9/14.7), v134 13.8, v135 9.1, v138 2.6. richard now 59.67. Rule: keep the best mean since 3676 (v137) → the 15:06Z auto-decision rotates to v140 (v137 clone).
- 15:06Z auto-decision: best mean since round 3676 with >=2 rounds = v137 (17.9) > v139 (14.7) > v133 … → v140 (clone of v137) submitted as the rest-of-day champion.
- v140 (clone of v137) placed champion 15:10Z; v139 benched. Hold mode until the 18:00Z evaluation.
- **Stopped 2026-09-02 16:10Z (user sleeping the laptop).** All watchers, checkpoints and the auto-decision timers were stopped; no Codex workers, local servers or bots remain. Live on the platform: v140 (clone of v137) is the competing champion and keeps playing rounds unattended. Standing at stop: richard 59.67, codex 53.58, **Jordan 50.92 (rank 3)**, relh 49.00. Daily credits by rank are awarded 21:00Z. Queued uploads (unsubmitted): v131 hold-4, v133/v134/v139 trialled, none better than the v137 recipe.

## 2026-09-02 20:10Z — resumed
- The coworld CLI's `rounds` command now fails (its model expects `offset`; the API returns `entries`/`next_cursor`); analysis/br_rounds.py reads the API directly (`/v2/rounds?league_id&limit&cursor`, `/v2/rounds/{id}/episode-requests`).
- v140 played 28 rounds while stopped: mean 14.8/seat (per the old mean rule), 47 wins; best rounds 41.4 (partial) and 36.5.
- **Scoring rule changed**: league settings now `round_scoring_rule: max` (was mean), `standing_aggregation: max` → the standing is a player's best single seat score in any round. Leaderboard 20:08Z: richard 375, **Jordan 363 (rank 2, 69 rounds)**, NanosaurusX 337, Eckstar 333 (new, 12 rounds), relh 246, codex-t2 170, Monet 156, daveey 152, lessandro 106, softmaxclaudius 89. Daily credits at 21:00Z (rank 2 = 100).
- New engine coworld id cow_c8807811; new entrants: eckstar-paintbot-s2-bounding:v1, apex:v9 (softmaxclaudius-t2), soft-codexter-t2-collaborative-jackal:v1, Monet:v7, nancy v5, huddle v27, lessandro v7, relh v14.
- /tmp was cleared while stopped (server binaries, bots, engine worktrees, recipe env files gone); recipes restored from research/s2_patches/recipes/, the 16-seat config regenerated from round 3720. Engine since 6668d893: a84b92cc "seats re-sharing one spawn point stand 24 px apart" (GV52) — the engine now separates stacked spawns slightly; starters retuned (aggressive rides the edge at 140-260 px, scatter in the spawn phase, cautious holds until zone phase 1); starters are filler-only now. Our best-ever episode (462, round 3660, v130 jackal recipe, 6 kills + win) predates the scoring window; the standing 363 is v140's best episode (round 3720).
- Under the max-episode rule our best episodes by recipe: v130 (jackal, no hold, no spread) 462 in 24 seats; v140/v137 (tick-1000 hold + spread) 363 over 648 seats; v132 240; v139 191. Variance wins now: uploading a v130 clone (v141) to rotate in right after the 21:00Z award.
- Local harness rebuilt on engine b672ea8c (server /tmp/johomax-ctf-server-runtime4, bot /tmp/e12-bot, starters rebuilt); smoke with the v137 recipe: tk 1, kills 10, winner. v141 uploaded 20:18Z = clone of v130 (jackal, no hold, pact/never, no spread); rotation scheduled 21:05Z after the award.
- Rounds 3715-3719 mined (68 episodes): richard 38.1 mean/seat (26 wins of 54 duo-episodes, best 375 = win + 7 duo kills), relh 24.5 (best 228), Eckstar 22.6 (custom `bounding_overwatch` + `duo_guard` plays, hold tick 1200; best 227), codex-t2 jackal 12.3, **our v140 9.2** (best 156 in this window), Monet/lessandro/huddle/nancy < 3. A 400+ episode needs a win with 6-8 duo kills; the jackal clone (v141) maximizes kill volume for the max-episode rule.
- Self-mirrors on the new engine (seeds 1430-1433): jackal without spread (v130 recipe) kills 4/4/3/1, tk 0/1/1/0; jackal + spread_out (v133 recipe) kills 8/6/5/10, tk 0/1/0/0 — the spread doubles kill volume. Switching the post-award rotation from v141 (v130 clone) to v142 = clone of the v133 recipe.
- Jackal recipes vs the retuned starters (seeds 1410-1417, four duos): without spread 0.875 win share, 0.75 kills/duo; with spread (v133/v142 recipe) 0.875, **1.50 kills/duo**, 0.63 tk/ep. The retuned aggressive starters now kill (0.69/duo). Next local sweep for kill volume: jackal earshot 900, exitAfter kills 2, and prefer bounty.
- Kill-volume variants of the jackal + spread recipe vs starters (seeds 1410-1417): earshot 900 → 1.41 kills/duo (0.75 win share); exitAfter kills 2 → 1.53 (0.75); prefer bounty → 1.25 (0.625); baseline 1.50 (0.875). No variant beats the baseline; v142 stays as is.
- 21:00Z scoring anatomy (rounds 3661-3725, research/br_rounds): score is winner-takes-all per duo — both seats of the winning duo get the duo's glory, every other seat 0 (5114 losers all 0; 66 winners at 0). Top scores are win + 6-8 duo kills (413 = 6 kills, 375 = 7, our 363 = 7, 357 = 6); achievements pay 9-23 (TierGlory) so 'silent'/'sniper' hardly matter. Lever = P(win with ≥5 duo kills) per duo-episode: v133 jackal+spread 6.25% (48 eps), v132 6.25% (48), richard 5.37% (1267), Eckstar 3.66%, v137 3.45%, v140 3.19% (376), nancy 1.70%. So v142 (= v133 recipe) is the right rotation for the max rule; v140's richard-like recipe wins less (13.6%) in the new field than richard himself (17.9%).
- 21:03Z post-award standings unchanged: richard 375, Jordan 363 (rank 2), NanosaurusX 357, Eckstar 333, relh 246. Rank 2 → 100 credits.
- 21:05:57Z v142 (jackal + spread_out, clone of the v133 recipe) submitted with auto-champion; placement pending. Judge by P(win with ≥5 duo kills) and best seat score per round (analysis/s2_rounds.py --since 3726).
- 21:09:32Z v142 qualified and is champion; v140 benched (28 rounds, best 363).
- v132 recipe (edge_ride 220 + hold aliveTeams 8 + supply_run + spread) vs starters, seeds 1410-1417: 1.22 kills/duo, 0.75 win share — below the v142 recipe (1.50, 0.875). Not a rotation candidate.
- Round 3727 (v142 first round): 3 duo wins of 12 (scores 107 = 4 kills, 100 = 5 kills − 1 tk, 45 = 1 kill), 21 kills over 24 seats (0.88/seat), tk 2; mean 21.0 vs v140's last three rounds 0.0/7.8/2.3. Field: co-gas 51.2, soft-codexter 24.1.
- Round 3727 replays (research/s2_replays/3727_*): v142 seats median death tick 1932, 1.06 kills/seat, placement 1 in 3 of 9 matched episodes, placement 6-8 (deaths at ticks ~1000-1470) in 3; richard 1916 / 0.89 / 21% wins; episodes end ~2650-2760 ticks. Monet:v7 casts a `pact` "truce" with its partner plus the neighbouring duo (protect false, target_law never those seats) — one-sided, Monet 0 wins in the round; not a threat.
- 21:35Z upstream check: engine origin/main 11b1f1c = b672ea8 + 3 starter-only commits (cautious hold releases at the drop; aggressive scatters until the first shrink; aggressive v19) — no engine mechanics change; local starters rebuilt from 11b1f1c. Round 3727 replays: v142 leads the round on wins and kills.
- Round 3728: v142 mean 47.0, best 191, 4 duo wins of 12, 25 kills, tk 0 — top of the round (Monet 12.5, richard 11.9).
- 21:50Z engine GV52 evaluates ladder `when` guards over the live view (episode.nim playGuardContext; paths self.hp_frac, partner.alive/dist/in_combat, world.enemy_count/in_zone/item_dist/medkit_dist/nearest_enemy_dist/weakest_enemy_hp/zone_dist; ops < <= > >= == and or not if). The 2026-09-01 "guards zero-valued" fact is obsolete. Codex reports: research/s2_glory_report.md (score = team glory, winners only; kill deeds ace 40 / splash 35 / longshot ≥866 px 30 / honorable 10, first blood +12, team kill −60, heat ×2 for kills 2-4 and ×4 for 5-6 when gaps <45 ticks, 150% on enemy ground) and research/s2_play_catalogue.md. Sweep queued vs rebuilt starters: v144-cross1400/1800 (recall to crossfire [120,260] at tick 1400/1800), v144-heal (guarded supply_run before edge_ride).
- Round 3729: v142 mean 16.1, best 193, 1 duo win of 12, 31 kills (1.29/seat, highest yet), tk 3. Three rounds: means 21.0/47.0/16.1, best 107/191/193, duo wins 3/4/1 of 12. Leaderboard 21:32Z: richard 375, Jordan 363, NanosaurusX 357, Eckstar 333, soft-codexter 289 (rising), softmaxclaudius 278.
- Round 3729 detail: the v142 win had 8 duo kills (6+2) but scored only 193 — spread-out plain kills pay ~10 each; richard's 375 came from 7 kills with heat/longshot/ace deeds. Confirms the lever is kill TYPE and timing, not count alone. Three of the losses carried a team kill (lower seat twice, upper once).
- 3729 replay of the 193 win (ereq_9192980): our duo made 8 of 9 kills; enemy deaths at ticks 949-1481 one at a time (gaps 60-130 ticks → no heat), then a zone cluster 1668-1672 and the last duo at 2164. Kills from early jackal hunting pay ~10-12 each; heat needs <45-tick gaps.
- 21:55Z ladder semantics (src/shell/ladder.nim:562-630, verified): the FIRST live controller whose guard passes owns movement; a live controller with no intent falls to the native default play, and only a faulted controller advances to the next entry. So in v142 `edge_ride` always owns movement and `jackal` never runs; on the upper seat `spread_out` emits a cached hold after arriving, so the upper seat CAMPS 180 px from spawn all game (reflexes aside). v142 = edge_ride lower + camper upper. The earshot/exitAfter "jackal variants" were inert by construction. Codex designs (research/s2_ladder_designs.md) put guarded supply_run/jackal BEFORE edge_ride. Queued after the v144 sweep: v145-d1 (longshot ambush), d2 (4-kill heat ride), d4 (hold to tick 1000 then burst), d2camp (d2 ladder with the camper kept), bothcamp (both seats camp apart).
- Round 3730: v142 mean 18.5, best 222, 1 duo win of 12, 19 kills, tk 3. Four v142 rounds: best 107/191/193/222, duo wins 3/4/1/1. Standings unchanged (richard 375, Jordan 363).
- Baseline vs the rebuilt starters (engine 11b1f1c, seeds 1410-1417): v142 recipe 0.625 win share, 1.59 kills/duo, 0.375 tk/ep (the new aggressive starter wins 0.25). Basis for the v144/v145 sweeps.
- Local sweeps vs rebuilt starters (seeds 1410-1417; baseline v142 0.625 wins / 1.59 kills/duo / tk 0.375): v144-cross1400 0.75 / 1.28 / 0.375; v144-cross1800 0.625 / 1.28 / 0.25; v144-heal 0.75 / 1.19 / 0.375; v145-bothcamp 0.75 / 1.375 / 0.25; v145-d1 (longshot ambush) 0.875 / 1.16 / 0.5. All within the 8-episode noise; no variant raises kill volume. Local kills/duo is not the objective anyway — the score is the winner's deed glory.
- Rounds 3731-3735 (v142): best 72/0/130/257/104, duo wins 3/0/2/1/4 of 12, tk 1/0/2/1/1. Nine v142 rounds: best ≤257; richard 375 still unbeaten; Eckstar up to 347 (22:17Z).
- 22:50Z local WINNER GLORY (analysis/s2_local_glory.py; results.json carries hosted-style scores): baseline v142 meanWin 87 max 151; v132 52/114; v144-cross1400 71/148; v144-cross1800 104/169; v144-heal 68/216 (1 win ≥200); v145-bothcamp 74/113; **v145-d1 (longshot ambush: guarded supply_run + guarded jackal{earshot 900, bothWeakened, hpFloor 2} before edge_ride 140/120/0.6, target_law prefer weakened/isolated/bounty, pact holdFire tick 10000, camper removed by a tick-160 recall) meanWin 137 max 443, 2 wins ≥200 of 7**. d1 is the first recipe to reproduce a 400+ score; uploading it for hosted rotation.
- 22:49Z v143 = d1 longshot-ambush recipe uploaded and submitted (sub_8459dedb, auto-champion); placement pending.
- v145-d2 (4-kill heat ride) local: 0.75 win share, meanWin 74, max 240 (1 win ≥200), tk 0.75/ep — below d1 (137/443) with more friendly fire.
- 22:53:56Z v143 (d1 longshot ambush) qualified and is champion; v142 benched after 9 rounds (best 257, duo wins 3/4/1/1/3/0/2/1/4 of 12).
- 23:10Z STOP (user request). All background tasks stopped; local harness processes killed; no Codex jobs running. Local partials: v145-d2camp 8/8 seeds meanWin 95 max 127 (0 ≥200); v145-d1 seeds 1420-1427 7/8 seeds meanWin 56 max 143 (0 ≥200) — the 443 on seeds 1410-1417 did not repeat; d4 and d1camp not run.
- **HOSTED BREAK at round 3736: coworld bumped 0.7.302 → 0.7.303 and from that round every one of our seats deals ZERO damage (v142 in 3736: 0 kills, 0 hitDamage, 2 zone wins at 18; v143 in 3737: 0/0/0). Calls are recorded in the replays (ladder accepted, epoch 1, tick 94; v143's tick-160 recall present), so the seats move but never fire. Other policies score normally (soft-codexter 10 kills in one episode). Suspect the 0.7.303 engine changed combat arming or the module ABI for our bundled playbook wasm (pact/target_law/edge_ride built from an older SDK). Standing unaffected (max rule: 363 stays). v143 is still the live champion.**
- 2026-09-04 20:30Z RESUMED after two days. The game moved under us: (1) loot-at-start armed at 0.7.303 (round 3736): seats spawn unarmed and must walk over a `gun` and a `hopper` before firing; spawn clusters seeded with 3+3 within 48 px since round 3849; perception of ground items/loadout armed at 0.7.318 (round 3854) for plays built on the current SDK; (2) downed state: a lethal hit downs, a partner within 40 px for 48 ticks revives to 1 hp, both downed = eliminated; no revives on painted (zone) ground; (3) Glory (Season 2) is a PRODUCT of whole-number factors (wiki research/wiki/glory-season-2.md): ×1 TAG/SPRAYED/POINT-BLANK, ×2 FIRST!/CHASE/PAYBACK/DUO DOWN/TAG BACK/JOINT ACT/ASSIST, ×3 LONGSHOT/MULTI!/CLOSING TIME, ×4 BOUNTY/LAST LIGHT/Tier V, ×8 VICTORY/WIPEOUT; heat ×1/2/4/8; enemy ground +1 rung; friendly fire ÷2; every seat banks its duo's product win or lose (since round 3849); (4) league: round score = sum of best 12 episode scores, standing = EMA (k=0.05) of round scores seeded with the first round (leaderboard shows it); consistency beats jackpots; winAsMultiplier ×4 was on 3871-3952 and rolled back 17:34Z today. Our v143 has dealt ZERO damage since 3736 (never armed) yet sits rank 3 (590,580) from pre-rollback rounds decaying. New starters (`*-s2`) arm themselves via walk-over loot since tonight. Fix in progress: rebuild all bundled plays on the current SDK (+ loot, scatter), add a guarded `loot` first in the ladder, rebuild the server/starters/bot locally on 9f17087, re-upload.
- 20:45Z hosted snapshot (rounds 3953-3965 = clean rounds after the winAsMultiplier rollback, coworld 0.7.323): our v143 (unarmed) round sums 400-2,400 typical with one fluke 1.68M; leaders' median round sums are in the tens of thousands. Standings (EMA): daveey 703,783, pawchuck 680,347, Jordan 583,028 (decaying), daveey-1 562,024, Aaron 305,062.
- 20:50Z local smoke on engine 9f17087 (new server/starters/bot): v147a (guarded reference loot first) → each seat grabbed exactly ONE crate (lower seats a gun, upper seats a hopper; reference loot fetches the nearest item and then parks), 0 damage. Both halves must be on the same seat. Fix in progress: custom arm_up play (Codex) that seeks gun then hopper and retires; interim v147b test = loot re-calls every 50 ticks in the spawn phase. Also fixed: our PV1 decoder rejected views carrying the new downed/loadout flag bits (commit 084977c).
- Root cause of the one-crate stall (sim.nim tryPickupWeapons/tryPickupHoppers): a cog already holding a marker walks over further marker crates untouched, so the reference loot play (nearest item of any kind) targets an untakeable same-kind crate and parks on it. Spawn geometry gives lower seats a gun first and upper seats a hopper first. The kind-aware arm_up play (in progress) skips the held kind. Spray cans fire without the gun halves (a seat with a spray can made kills in seed 1412; canFire only gates the marker).
- v147b (loot re-calls every 50 ticks): same one-crate pattern (lower gun, upper hopper), 0 damage — confirms the untakeable same-kind crate stall; arm_up is required.
- 20:58Z arm_up (bot/plays/arm_up.nim, Codex) built and embedded (sha e246c1b9…); harness test 3/3: `cd bot && ARM_UP_WASM=/tmp/arm_up.wasm WASMTIME_C_API=<engine>/tools/runtime_spike/.deps/installed/aarch64-macos/wasmtime-c-api nim c -r -d:release -d:noSignalHandler --threads:on --mm:orc --path:. --path:<engine>/src tests/arm_up_harness_test.nim` (extract the wasm from bot/baseline/playbook_arm_up.nim). Local v148a/v148b runs in progress with /tmp/e12-bot-v3 on server runtime5 (engine 9f17087) and config /tmp/johomax-s2-config-16-v2.json.
- 20:56:18Z v144 = arm_up + hold fire until zonePhase 1 + shelter edge_ride 420 (recall 1000: posture 180; recall 1550: crossfire + tight 120) uploaded and submitted (sub_3d6e8a0d, auto-champion). First local episode: 8/8 armed, 8 kills, 0 tk, one duo 331,776.
- Zone schedule (config zonePhases, playing starts ~tick 735): shrink 1 runs ~1080-1293 (dps 0), 2: 1293-1537 (dps 3), 3: 1537-1885 (dps 6), 4: 1885-2485 (dps 10), 5: 2485-4035 (dps 15), 6: 4035-5735 (dps 20); maxTicks 10000. holdTrigger zonePhase 1 releases ~1080. CLOSING TIME (×3) covers any kill during an active shrink; LAST LIGHT (×4) needs phase 6 (≥4035). Local episodes now run to ~4000 ticks.
- Smoke on engine 9f17087 vs new starters (4 eps): v147a (reference loot first) 0 kills/duo, 0.50 win share (zone wins); v142 control 0 kills/duo, 0.25. Unarmed recipes only win by outlasting the zone.
- 21:03Z v144 is ACTIVE (champion); v143 benched. Local v148a/b (4 eps each): arming 7-8/8, but two episodes show a SELF-INFLICTED REVIVE LOOP: in the packed endgame (tick ≥2500, zone phase 5) our seat downs its own partner every 57 ticks (revive 48 ticks + shot) — 26 team kills, score → 0 (÷2 each). v148a meanWin 141,744 max 331,776 (3 wins/16 duo-eps); v148b meanWin 3,674 max 12,960 (4 wins). The loop is gun collateral on an adjacent 1-hp partner, not targeting (never/protect are set). Must stop firing with the partner adjacent or avoid adjacency late.
- Loop geometry (1413): shooter and partner frozen 13 px apart, heading 56° off the partner — the shell's protect check tests a point against an 8 px corridor and ignores the 17 px body radius, so an adjacent partner is hit. Field tk/seat: apex 0.003, paintbot-huddle 0.010, bruce 0.414. v149 = v148a with the pact and target_law overlays guarded by partner-not-adjacent (partner dead or partner.dist > 32): no overlay folded → the seat does not fire while the partner is within 32 px.
- v148c (hold until zonePhase 2): tk 1/3/1/1, meanWin 11,796 max 110,592; v148d (late jackal chain + wide crossfire): tk 0/0/7/1, meanWin 11,934 max 46,656. All arm_up recipes win every local episode; friendly fire (÷2 each) is the remaining score killer.
- Round 3971 (v144 first hosted round): 32 kills (armed at last), but 12 team kills, 2 duo wins, mean 244.8/seat, best 1,458 — friendly fire is the score killer on hosted too.
- 21:15Z v149 local (seeds 1410-1412): tk 0/0/0, kills 7/6/13, wins 3/3, duo scores up to 93,312. Shipping as v145 (arm_up + hold + shelter + overlays guarded by partner-not-adjacent). v144 benched once v145 qualifies.
- 21:13:56Z v145 (v149 recipe) submitted (sub_29437d04, auto-champion). Local deed mix of our kills (v148/v149 runs): DUO DOWN ×2 and CLOSING TIME ×3 dominate, FIRST BLOOD ×2 sometimes, LONGSHOT ×3 rare (1 per 4 episodes), no BOUNTY; team kills (÷2) were the only negative. v150 = v149 with hold until zonePhase 2 running locally.
- Round 3971 per episode (v144): 3 wins of 12 with scores 432/1296/144; the losses bank 2-18; tk 5+5+1 in three episodes (lower seats). Winning scores are 10-100× below the field's typical 10^4-10^5 wins: our kills come one at a time (no heat), DUO DOWN/CLOSING TIME only.
- 21:20Z score composition (local events glory_deed amounts): a duo's score ≈ product of kill-deed factors × heat; e.g. 93,312 = LONGSHOT×4 · FIRST BLOOD×3 · DUO DOWN×9 · CLOSING TIME×6 · DUO DOWN×6 (× heat), earned by a LOSING duo; the winners banked 2 (VICTORY ×8 on a seed of 1). Kills during shrinks (CLOSING TIME ×3, +1 rung on enemy ground) that finish duos (DUO DOWN ×2, +1) are the engine; winning barely matters. Strategy pivot: hunt during the shrink phases, chain kills (<45 ticks), keep the adjacency guard.
- Local score vs product of logged deed rungs: ratio 2-192× (heat ×2/4/8, achievement tiers, first-claim ×3); e.g. 331,776 = rungs 1,728 × 192. Chained kills (<45 ticks) correlate with the larger ratios. Crossfire/bodyguard now find the partner via the duo-grant track row, so the late crossfire is functional.
- 21:19Z v145 (adjacency-guarded v149 recipe) is ACTIVE; v144 benched after one round (3971: 32 kills, 12 tk).
- Round 3972 (v144, 2nd round): mean 1,776/seat, best 34,992, 30 kills, 5 tk, 1 duo win — round sum ≈ 37k, within the field's leading medians. v145 (guarded) takes over from 3973/3974.
- v149b (guard + late jackal chain + wide crossfire), seeds 1410-1413: kills 8/6/11/2, tk 0/0/1/1, duo scores max 8,748, sum ~10k — well below v149 (sum 146k) on the same seeds.
- v150 (guard + hold until zonePhase 2), seeds 1410-1413: kills 9/5/9/6, tk 0/0/1/0, duo scores 2,519,424 (seed 1412) and 23,328 — sum ≈ 2.54M vs v149's 146k on the same seeds (single jackpot; extending both to seeds 1414-1421).
- The 2.5M local episode (v150 seed 1412): the upper seat made 7 kills across ticks 1318-2703 (all in shrink phases): CLOSING TIME ×6/×3/×3/×3/×3, DUO DOWN ×6/×3/×3, FIRST BLOOD ×3, REVENGE ×3 → rungs 78,732 × 32 (heat/claims) = 2,519,424. Kill volume during shrinks compounds geometrically; one prolific seat is enough.
- 21:28Z multiplier rules (research/s2_multipliers.md, Codex, file:line cited): glory_deed.amount already includes territory (+1 rung when the VICTIM lies in another team's spawn-anchor Voronoi cell), heat and ally-stack; the remaining ×24/×192 were ACHIEVEMENT claims (Tier III/IV ×2, Tier V ×4, first Tier V ×12; Clean Sheet IV ×2 for zero teamKills at conclusion, winners and losers). Heat: kills (even ×1 commons) and DUO DOWN and VICTORY add embers; ×2 at 2-4 embers, ×4 at 5-9, ×8 at 10-11; cooling −2 embers per 45 quiet ticks. Ally-stack: k = distinct seats that damaged the victim in the last 120 ticks (partner counts only if it hit the victim) → both partners hitting the same target doubles the kill factor. CLOSING TIME/LAST LIGHT carry no heat. Friendly fire divides only on a finalized death by a friendly downer (a revived down costs nothing in glory but forfeits Clean Sheet). DUO DOWN = finalizing the last living seat of a duo, whoever downed the other. LAST LIGHT from elapsed 3300 (tick ~4035).
- v151 (guard + hunt lane + guarded jackal from the first shrink), seeds 1410-1413: tk 0/0/0/0, kills 7/8/11/10, duo scores max 90,000, sum ≈ 100k. v152 (same, bothWeakened + bounty-first): tk 0, kills 9/6/9/9, max 36,864, sum ≈ 42k. Seeds 1410-1413 sums: v150 2.54M (one 2.5M episode), v149 146k, v151 100k, v152 42k, v149b 10k. Extending v149/v150/v151 to seeds 1414-1421.
- 21:28Z ROUND 3973 (v145 first round): mean 161,026/seat, best 3,359,232, 4 duo wins of 12, 27 kills, 1 tk. Leaderboard 21:26:48Z: **Jordan 652,857 rank 1**, daveey 587,455, pawchuck 536,713, daveey-1 449,326.
- 21:30Z HOSTED DUOS ARE MIXED (scheduler distinct_teammates: true): in the 3.36M episode our seat 12 (v145, 3 kills) was paired with daf-paintbot-s2 (seat 4, 5 kills, 1 tk); the duo score is shared. Our partner on hosted is always another player's policy, so local same-policy duos overstate partner coordination; pact/guard/arm_up still apply per seat.
- 21:32Z scripts/s2_local.py --mixed deals bots per seat (every duo = our seat + a starter, like hosted distinct_teammates); analysis/s2_seat_glory.py reports per-seat glory. Running v149 mixed on seeds 1410-1417.
- v150 seeds 1414-1421: wins 6/8, tk 0/1/0/1/1/0/0/0, duo scores max 31,104, sum ≈ 70k (no jackpot). v150 over 12 seeds ≈ 2.61M total, almost all from the one 2.5M episode.
- Round 3974 (v145 2nd): mean 13,644/seat, best 279,936, 2 duo wins, 28 kills, 2 tk (round sum ≈ 290k). Leaderboard 21:41Z: Jordan 634,540 (rank 1, decaying toward the round sums), pawchuck 595,700, daveey 558,146. Holding rank 1 needs round sums ≳ 600k, i.e. a 10^5-10^6 episode most rounds.
- v149 seeds 1414-1421: wins 6/8, duo scores max 60,000, sum ≈ 86k; tk 0/0/0/0/1/1/1/10 (seed 1421: 19 kills, 10 tk — the 32 px guard did not stop a loop there; scores 2592/4608 so revived downs did not divide). 12-seed sums: v150 2.61M (91k without its 2.5M episode), v149 232k.
- Seed-1421 loop under the 32 px guard: our seat downed its partner every 57 ticks at 35 px (just outside the guard, inside the 40 px revive range). v154 = v150 with the guard widened to 48 px (no fire while within revive range).
- Replays 3973-3974 (v145, 42 seats): all 3 calls per seat accepted; median seat score 18, 3 seats ≥10k (3.36M with 3 kills + partner daf 5 kills; 280k with 5 kills; 11,664 with 6 kills), median death tick 2075. Miner now decodes the 0.7.32x coded play-fault annotation (kind 4). Upstream engine moved to fad3029 (item-drop chord, structured fault codes); local rebuild deferred until the batches finish.
- v151 seeds 1414-1421: kills/ep 10.8 (highest of all recipes), tk/ep 0.5, one 8,957,952 duo episode plus 5 more seats ≥10k; duo-score sum ≈ 9.2M. v151 over 12 seeds ≈ 9.3M vs v150 2.61M vs v149 232k. Hunting from the first shrink (edge_ride 140 + guarded jackal afterKill) produces the kill volume that compounds. Next: v151 mixed-duo run, then v155 = v151 with the 48 px guard.
- 21:46:54Z v146 uploaded (v155 recipe: hunt lane + guarded jackal from the first shrink + 48 px adjacency guard), NOT submitted; decision after the v155 mixed-duo run.
- v153 (crossfire from the first shrink + bounty-first late), seeds 1410-1417: kills/ep 7.5, tk 3/8 eps, max 13,824, sum ≈ 35k — below v151 (kills/ep ~10.8, jackpots). Focus-fire via crossfire did not raise kill volume.
- Round 3975 (v145 3rd): mean 728/seat, best 11,664, 2 duo wins, 24 kills, 0 tk (round sum ≈ 15k; huge round-to-round variance). Rebuilt on fad3029: server /tmp/johomax-ctf-server-runtime6; every play wasm sha unchanged (SDK identical), bot /tmp/e12-bot-v4 ≡ v3. dropItem is armed on the variant. Local v151 ext: 13 of 64 seats picked up a spray can by touch (gun disabled while carried).
- Drop lever (fad3029, armed): a controller intent may carry "drop": true (emit_validator/finisher); the standing order emits the B+Select chord and spills the highest-priority carried item (spray first, else marker/hopper — so only safe while carrying spray). Reference plays never emit it; a custom play would need to detect self-carrying-spray. Deferred: spray seats still kill at 170 px (one activation = 3 damage).
- v149 MIXED (starter partners, 8 eps, 64 seats): meanSeat 3,991, max 221,184, 2 seats ≥10k, kills/seat 1.33, tk/seat 0.05, win 12%. With a starter partner our seats still win every episode's duo once per episode and score mostly small.
- v150 MIXED (8 eps): meanSeat 26,900 (one 1,679,616 seat), kills/seat 1.12, tk/seat 0.17; v155 MIXED after 6 eps: meanSeat 48,682 (one 2,332,800), kills/seat 1.27, tk/seat 0.04; v149 MIXED 3,991. All dominated by single jackpots.
- Round 3976 (v145 4th): mean 4,611/seat, best 69,984, 3 duo wins, 36 kills (most yet), 1 tk (round sum ≈ 97k). Standings 21:56Z: Jordan 578,238 (rank 1), pawchuck 541,570, daveey 504,040 — every standing decays between jackpots.
- 22:03Z DECISION: submit v146 (hunt recipe: edge_ride 140 + guarded jackal from the first shrink, 48 px guard). Evidence: same-duo 12 seeds duo-score sum ≈ 9.3M vs v149 232k; MIXED (starter partners) meanSeat 49,349 (7 eps; seats 2,332,800 and 419,904, both from 7-kill seats) vs v149 mixed 3,991; tk/seat 0.04 vs 0.05; kills/seat 1.29 vs 1.33. v145 stays the fallback (rounds 3973-3976 sums 3.4M/290k/15k/97k).
- 22:05Z JACKPOT ANATOMY: the 8,957,952 local episode (v151 seed 1420) was a seat with 3 kills — two of them one GRENADE at tick 2558 killing both members of a duo at ~230 px (CLOSING TIME ×6, DUO DOWN ×6, MULTI!, plus grenade-tree achievement tiers). The 2.5M episode was 7 gun kills. Grenades auto-throw at targets ≥90 px when carried; our seats only pick them up by accident (9 of 64 seats). v156 = v155 + guarded loot{detourMax 250, avoid, no medkits} after the first shrink (before jackal/edge_ride) to collect grenades deliberately.
- v155 MIXED final (8 eps, 64 seats): meanSeat 43,728, max 2,332,800, 3 seats ≥10k, kills/seat 1.31, tk/seat 0.03 — vs v149 mixed 3,991 / 221k / 2 / 1.33 / 0.05. v146 (v155 recipe) qualifying since 22:03Z.
- 22:06Z v146 (hunt recipe) is ACTIVE; v145 benched after 4 rounds (sums ≈ 3.4M / 290k / 15k / 97k).
- Field scan rounds 3965-3976 (sum of best 12 seats per round): paintbot-huddle median 131,854 with 6 of 11 rounds ≥100k (kills/seat 0.82, tk 0.013) — the consistency leader; ours median 37,272, 4 rounds ≥100k, max 3.38M, tk/seat 0.108 (v143/v144 era). bruce median 16.7k (kills 1.43/seat but tk 0.59). Target: match huddle's consistency (their ladder: loot 'arm_fast' with prefer grenade, scatter, edge_ride hunt lane 140, chain jackal, late bodyguard wait_revive).
- paintbot-huddle's 'loot' is a CUSTOM module (sha 421f9446…, not the reference f0ada4ec…) with prefer:grenade, guarded by item within 400 px, first in every ladder (entry ids arm_up/arm_fast/arm_grenade) — kind-aware looting with a grenade preference is the leader's arming path. Our arm_up grenade phase (Codex, in progress) is the equivalent.
- 22:10Z arm_up grenade phase built (sha 9eb0cbf0…, harness 5/5). v157 = v155 + arm_up{grenades:true, grenadeDetourMax 300}; running same-duo 12 seeds and mixed 8 seeds with /tmp/e12-bot-v5.
- Round 3977 (v145 5th/last): mean 158/seat, best 1,728, 0 duo wins, 25 kills, 2 tk (round sum ≈ 3k). v145's five rounds: 3.4M / 290k / 15k / 97k / 3k. v146 starts at 3978.
- v154 (48 px guard + hold until zonePhase 2), 12 seeds: kills/ep 7.4, tk 4 total, wins 9/12, duo-score sum 352k (two ~150k episodes). v157 first episode: two lower seats stalled after the gun pickup (navigated toward a hopper, then no emissions, no fault, never armed) — same seed armed fully under v155; investigating the grenade-phase build.
- v151 MIXED (32 px guard; 8 eps, 64 seats): meanSeat 421, max 14,400, kills/seat 1.19, tk/seat 0.00 — vs v155 mixed (48 px) 43,728 on the same seeds; jackpot luck dominates, tk ≈ 0 in both. Leaderboard 22:11Z: Jordan 549,489 (rank 1), pawchuck 514,525, daveey 478,847.
- v155 (hunt + 48 px guard), 12 seeds same-duo: kills/ep 9.4, tk 0.25/ep, wins 10/12, duo-score sum 396k (max 186,624). 12-seed same-duo sums: v151 9.3M (one 8.96M grenade episode), v150 2.61M (one 2.5M), v155 396k, v154 352k, v149 232k — jackpots are rare and decide the sums; kills/ep is the steadier signal (v155 9.4, v151 10.8, v154 7.4, v149 8.8).
- 22:19Z ROUND 3978 (v146 FIRST round): mean 480,437/seat, best 10,077,696 (a 10M episode), 2 duo wins, 14 kills, 0 tk. Leaderboard: **Jordan 1,026,473 rank 1**, daveey-1 865,669, pawchuck 490,553, daveey 457,190.
- The 10,077,696 episode (round 3978, ereq_4b4498b): our seat 10 (3 kills, 7 damage) paired with paintbot-huddle seat 2 (4 kills); win, 0 tk. Partner quality matters — the duo score is shared, so a strong random partner can carry.
- 22:21Z arm_up stall root cause (Codex): a seat could stop ~12 px from a still-present crate; the goal-only decision cache then suppressed re-emission while the shell kept the satisfied navigate order, so the seat parked unarmed. Fix 7f83f02: after three stationary steps within 20 px of the target it re-emits with arrive radius 4 (harness 6/6, sha 9dfb786e…). Bot /tmp/e12-bot-v6; v157 (hunt + grenade phase) rerunning same-duo 12 seeds and mixed 8 seeds.
- v156 (hunt + guarded loot{250, avoid} after the first shrink), 12 seeds same-duo: kills/ep 8.6, tk 0.17/ep (lowest), wins 11/12, duo-score sum 404k with SEVEN episodes ≥15k (46k/15k/93k/74k/62k/93k/15k) — the most consistent recipe; grenade pickups 27% of seats (v155 ~15%), spray 18%.
- v158 MIXED (hunt + hold until zonePhase 2, 48 px guard; 8 eps): meanSeat 1,072, max 55,296, kills/seat 1.17, tk/seat 0.02 — below v155 mixed (43,728) on the same seeds; the later hold does not help the hunt lane.
- v156 MIXED final (8 eps, 64 seats): meanSeat 28,545 (one 1,119,744), 2 seats ≥10k, kills/seat 1.30, tk/seat 0.05 (v155 mixed 43,728 / 3 / 1.31 / 0.03). v157 mixed interim (40 seats, fixed arm_up): meanSeat 4,976, kills/seat 1.43, tk 0, armed 97%, grenade pickups 31%.
- 22:37Z ROUND 3980 (v146 2nd real round; 3979 failed/skipped): mean 1,629,144/seat, best 35,831,808 (a 35.8M episode), 1 duo win, 33 kills, 1 tk. Leaderboard: **Jordan 2,767,206 rank 1**, Ari Sklar 1,948,864, daveey-1 822,613, pawchuck 466,027.
- v157 (hunt + arm_up grenade phase, fixed build v6): same-duo 12 seeds kills/ep 9.2, tk 0.33, armed 98%, grenade pickups 36%, duo-score sum ≈ 1.52M (max 933k, 9 wins ≥200); MIXED 8 eps: meanSeat 4,591, max 172,800, kills/seat 1.41 (highest), tk 0.00, grenade 47%. Uploading as v147 (unsubmitted) pending v159 and the v155 fresh-seed mixed run.
- Round 3981 (v146 3rd): mean 2,969/seat, best 62,208, 1 duo win, 25 kills, 2 tk (round sum ≈ 68k). Standings 22:52Z: Jordan 2,632,259 (rank 1), Ari Sklar 1,851,486, daveey-1 784,234.
- 22:53Z v147 uploaded (= v157 recipe, unsubmitted). v155 MIXED on fresh seeds 1418-1425: meanSeat 4,208, max 209,952, kills/seat 1.42, tk 0.03 — the 43,728 on seeds 1410-1417 was seed luck. Mixed meanSeat is jackpot noise; steadier signals: kills/seat (v157 1.41-1.43 best), tk (v157 0.00), grenade pickups (v157 47% vs ~15%). Decision rule: rotate to v147 if v157's fresh-seed mixed run (1418-1425) matches or beats v155's on kills/seat and tk.
- v159 MIXED (hunt + loot + grenade phase; seeds 1410-1417): meanSeat 686, max 24,000, kills/seat 1.30, tk/seat 0.03 (no jackpot).
- 22:57Z pushed to origin (github.com:johomax/johomax_ctf, 9140571..ea7d9bc); a background loop pushes new commits every 15 min. Standings 22:56Z: Jordan 2,501,618 (rank 1), Ari Sklar 1,758,933, daveey-1 747,033.
- v159 (hunt + loot + grenade phase), 12 seeds same-duo: kills/ep 8.3, tk 3, wins 10/12, armed 95%, grenade 35%; duo scores include 816,293,376 (seed 1416) and 2,160,000 — duo-score sum ≈ 409M. Round 3982 (v146 4th): mean 847/seat, best 11,664, 2 wins, 29 kills, 1 tk.
- 23:07Z 816M ANATOMY (v159 seed 1416, duo 7): seat 15 armed, then picked up a SPRAY CAN at tick 1708 and made 9 spray kills including two double-kills in one activation (ticks 2058, 2085) → DUO DOWN ×3/×6 ×4, CLOSING TIME ×3 ×4, Spray tree Tier V first claim ×12, Gun tier ×2; seat 7 grenade double-kill at 1261 (treeGrenade ×2). Spray cans are NOT a trap under the recut: one activation kills (3 dmg) and double-kills mint MULTI + Tier V. Formula: arm → collect grenades and spray cans → hunt during shrinks. v159 (hunt + guarded loot after the first shrink + arm_up grenade phase) is the candidate; uploading as v148.
- 23:07Z v148 uploaded (= v159 recipe, unsubmitted). Fresh-seed MIXED interim: v157 meanSeat 5,030 / kills 1.23 / tk 0.06 (48 seats); v159 2,693 / 1.50 / 0.05 (40 seats); v155 4,208 / 1.42 / 0.03 (64 seats).
- 23:10Z ALERT: round 3983 ran on coworld 0.7.328 (3982 was 0.7.327) and ALL 23 of our v146 seats dealt zero damage (0 kills, 0 hitDamage, all died). Suspect the arm_up retire-by-fault path or arming changed in 0.7.328. Testing the live recipe on the fad3029 server locally and mining a 3983 replay.
- 23:15Z DIAGNOSIS (round 3983 replay, 0.7.328): arm_up retired correctly (fault code 14 at t938) but then supply_run took the ladder emitting supply_run:hold — its guard (hp<0.67 and medkit_dist ≥ 0 and < 400) passes when guard readings are zero-valued, so the seat camped at spawn and died in the zone. Hardened recipes v161 (= v155) and v162 (= v159): supply_run needs medkit_dist > 0 and 0 < hp_frac < 0.67; loot needs item_dist > 0. With dead guards, jackal/loot/supply_run all fail and edge_ride runs; overlays still fold (fire on).
- 3983 replays (3 seats): two seats retired arm_up (fault code 14) then sat in supply_run:hold until the zone reflex dragged them (64 and 24 reflex moves, 0 kills); the third never retired arm_up (the old stall, 4 navigates, no fault) and never armed. Conclusion: on 0.7.328 the guard readings let supply_run win the ladder at full HP; v161 (hardened guards + the stall-fixed arm_up build) is uploading and will be submitted as soon as it lands — v146 is dead on the live engine.
- 23:11Z jordan-ctf-candidate:v149 (= v161: v146 recipe with guard-hardened supply_run + stall-fixed arm_up build) uploaded and SUBMITTED (auto-champion) to replace the dead v146 on 0.7.328.
- 23:13Z STOP (user request). All background tasks stopped, harness processes killed, Codex idle. v157 mixed on seeds 1418-1425 final: meanSeat 4,020, max 209,952, kills/seat 1.22, tk 0.05 (≈ v155's 4,208). Membership rows at stop:  lpm_07321e4… Jordan jordan-ct… Competition qualifying - ; lpm_a7d59d8… Jordan jordan-ct… Competition competing active ; lpm_73c26e4… Jordan jordan-ct… Competition disqualif… inactive ; lpm_822dc76… Jordan jordan-ct… Competition disqualif… inactive ; lpm_0bf56cc… Jordan jordan-ct… Competition disqualif… inactive ; lpm_52c4638… Jordan jordan-ct… Competition disqualif… inactive ; lpm_d021da1… Jordan jordan-ct… Competition disqualif… inactive ; lpm_026537f… Jordan jordan-ct… Competition disqualif… inactive ; lpm_bb1e5c5… Jordan jordan-ct… Competition disqualif… inactive ; lpm_28206e9… Jordan jordan-ct… Competition disqualif… inactive ; lpm_4515265… Jordan jordan-ct… Competition disqualif… inactive ; lpm_4ccc615… Jordan jordan-ct… Competition disqualif… inactive ; lpm_6f2194f… Jordan jordan-ct… Competition disqualif… inactive ; lpm_2cd908c… Jordan jordan-ct… Competition disqualif… inactive ; lpm_8d07717… Jordan jordan-ct… Competition disqualif… inactive ; lpm_944c2bc… Jordan jordan-ct… Competition disqualif… inactive ; lpm_db8aef8… Jordan jordan-ct… Competition disqualif… inactive ; lpm_612291b… Jordan jordan-ct… Competition disqualif… inactive ; lpm_32fd7f2… Jordan jordan-ct… Competition disqualif… inactive ; lpm_6a61031… Jordan jordan-ct… Competition disqualif… inactive ; lpm_f374175… Jordan jordan-ct… Competition disqualif… inactive ; lpm_3d12049… Jordan jordan-ct… Competition disqualif… inactive ; lpm_53bd927… Jordan jordan-ct… Competition disqualif… inactive ; lpm_331c122… Jordan jordan-ct… Competition disqualif… inactive ; lpm_a6586db… Jordan jordan-ct… Competition disqualif… inactive ; lpm_ad83d06… Jordan jordan-ct… Competition disqualif… inactive ; lpm_3c54aaa… Jordan jordan-ct… Competition disqualif… inactive ; lpm_7c113d8… Jordan jordan-ct… Competition disqualif… inactive ; lpm_a220a8f… Jordan jordan-ct… Competition disqualif… inactive ; lpm_f038468… Jordan jordan-ct… Competition disqualif… inactive ; lpm_5cbd553… Jordan jordan-ct… Qualifiers disqualif… inactive ; lpm_2fbf72a… Jordan jordan-ct… Qualifiers disqualif… inactive ;. Field check: other policies kept their kills on 0.7.328 (apex 1.52/seat, huddle 1.33), so the 3983 collapse was ours alone (supply_run hold + arm_up stall).
- 2026-09-08 17:35Z RESUMED after 4 days. State: v149 active but rank 15/16 (202,146, decaying); rounds 4440-4469 our median round sum 303, kills/seat 0.38, win 4.2% vs apex/co-gas/Monet medians 75-89k with capped 16.8M legs. What changed (wiki changelogs 09-05/07/08, forum): (1) 2026-09-05 build 0.7.334 round 4003: SOLO seats — 16 one-policy teams, no partner, no shared score; loot-at-start, marker/hopper split, downed state, drop/give all OFF (seats spawn armed); (2) pacts between solo players are real (mutual pact registry), and since 0.7.347 (round 4374) a downed solo whose pact partner stands can be revived; (3) build 0.7.344 (round 4257) rescaled the ladder: a win with zero tags pays 384 (bare loss 2), win bonus ×192 at zero tags decaying to ~1.1× at 6 tags; hard per-leg ceiling 2^24 = 16,777,216 reached from 3-6 tags (one capped leg ≈ 838,861 into the EMA standing); (4) coworld 0.7.351 at round 4469; rated_clamp_multiple 150 added to the ranking config. Our ladder still starts with arm_up (nothing to collect in solo mode) and a pact on a non-existent duo partner — suspect our seats run the native default all game.
- 17:45Z Round 4469 replay (solo, game_version 59, 16 teams, downedMode+winAsMultiplier+deedMintCaps on): our v149 seat's accepted ladder was just edge_ride{220} — the configured recipe (arm_up/pact with $PARTNER) cannot resolve without a duo partner, so the bot fell back to a movement-only ladder that never fires. Field ladders: target_law > scatter > edge_ride (most), huddle loot > scatter > edge_ride > jackal, apex warden > loot, bruce target_law > farm_hold > edge_ride. v170 = solo recipe: target_law(hold to first shrink) + hardened supply_run + guarded loot + shelter; recall 900: hunt lane + guarded jackal; recall 1500: tight. Shipping immediately.
- Solo-mode field ladders (round 4469 replay): co-gas (richard/relh, median 88k) = edge_ride with new scatterHeading/scatterSteps params (margin 293-331, enterLead 345-402, coverBias 0.8-0.9) + target_law never:[3 seats] (truces) + supply_run whenHpBelow 4; bruce = target_law + custom farm_hold + edge_ride 180 + custom anchor12; Monet = target_law prefer weakened/revenge/bounty/isolated + scatter + loot + custom fire_superiority; lw-pax = pact with 3 partners + target_law never them + scatter + jackal; huddle = custom loot(prefer grenade) + scatter + hunt lane 140 + jackal; apex = custom warden + loot 2500. Alliances via pact/never lists are common. Our bundled edge_ride predates scatterHeading; rebuilding the playbook on the new engine.
- 17:46:32Z v150 (v170 solo recipe) uploaded and submitted (sub_3896a307, auto-champion). Engine clone c3f7781b (2026-09-08) at /private/tmp/engine-main-v43; harness rebuild in progress (server runtime7, bot v7, solo config /tmp/johomax-s2-config-solo-v2.json); harness patched for solo seats.
- Forum (lessandro, 09-06/07): removing a truce/holdFire (no more 'don't shoot until zone phase 3') raised their tags/ep 0.37 → 0.90 (z +4.8, out-of-sample replicated) — the field median stayed ~0.75; early engagement pays tags in solo mode. Episode rows carry participants[].version (exact build per seat) and coworld_version + manifest_hash; failed episodes name failed_policy_index/error (lobby join timeout ~300 s).
- 17:52Z local SOLO smoke (engine c3f7781b, runtime7, 2 eps): v170 kills/seat 0.38, meanSeat 64, 0 wins vs starter:cautious 1.12 / 111,485 (legs 884,736 and 663,552) and starter:collaborative 1.00 / 84,246. The cautious starter shelters at margin 420 all game after a scatter; our recall to the hunt lane at 900 (the zone now starts shrinking ~tick 260+wait) gets us killed early. v171 = cautious-like shelter all game (scatter + shelter 420 → posture 180 at 1200 → tight 120 at 2000), guarded supply_run/loot.
- 17:52Z v150 (v170 solo recipe) is ACTIVE; v149 benched. First hosted rounds from ~4472. Local v170 vs v171 (shelter all game) running on the solo harness.
- 17:53Z v151 uploaded (= v171 solo shelter recipe), unsubmitted pending the local v170-vs-v171 comparison.
- 17:56Z Codex changelog fad3029..c3f7781b (research/s2_changelog_fad3029_c3f7781b.md): solo = 16 teams, no duo_partner, partner.* guards read alive=false/dist=-1; pacts register from the first pact entry's static partners (mutual → revive, ally stack, ghost protection; peace only via local noShoot/never); SCORING: placement ×2/×3/×4 at final 8/4/2 + solo win ×8 (=×192), product cap 2^24 (a pre-placement product ≈87k caps after ×192), heat ×2/×4/×8 at embers 1/2/4 (much easier), Closing Time ×3, Last Light ×4, territory +1 rung, ace ×4, achievements III/IV ×2, V ×4 (first ×12), mint caps on DuoDown/TagBack/JointAct/ShieldSoak; empty combat policy = shoot everything visible; jackal/loot/supply_run now get real kill-feed/item inputs; crossfire/bodyguard hold forever in solo; 4 HP per seat; zone: gameplay ticks 259-419 phase 1 (dps 0), 419-602, 602-863, 863-1313, 1313-2476, 2476-3751; 11 maps of 3211×1713 with 16 spawn groups; gun range 1300 (longshot ≥ ~867 px); 6 sprays + 22 grenades per map.
- 17:58Z local solo interim: v171 (shelter all game) after 4 eps meanSeat 8,404, win 19%, kills/seat 0.75 (starter:cautious 10,728 / 6% / 0.69 in the same episodes); v170 (hunt lane, live as v150) after 3 eps 1,607 / 8% / 0.67. Rounds 4470-4472 still v149 (sums ≈ 1k). Standing 182,565 rank 15.
- 18:07Z local solo 8 eps (4 of our seats as separate teams vs 12 starter seats): v170 (hunt lane, live as v150) meanSeat 424,954 (legs 13.3M and 276k), win 12%, kills/seat 0.91; v171 (shelter all game, uploaded as v151) meanSeat 528,519 (one capped 16,777,216 leg + 110k), win 12%, kills 0.75; starters 2-14k. Both win 4/8 episodes; the 5-kill wins are the jackpots (seed 1416 for both). Difference within noise; keep v150 live and let hosted rounds arbitrate; v151 ready as a swap.
- Capped local leg anatomy (v171 seed 1416): LONGSHOT ×4 (enemy ground) at tick 956 + Gun Tier V first claim ×12, Joint Act ×3 ×2, Closing Time ×3/×4 ×3 more kills (5 kills total), then the win (placement ×24 × win ×8) → 16,777,216 (cap). The formula: survive, take one long-range opener, then a few closing-time tags, then win.
- 18:12Z rounds 4471 and 4473 failed with 2-3 failed episodes each, no failed_policy_index/error attribution (platform-side); 4471 predates v150's activation, so neither is ours. v150's first real round is 4474+.
- v172 (hold to 2nd shrink, bounty first, shelter) 8 eps: meanSeat 525,957 (one capped leg), win 9%, kills/seat 0.66. Local 8-episode solo comparison: v170 425k / 12% / 0.91, v171 529k / 12% / 0.75, v172 526k / 9% / 0.66 — each caps once (seed 1416); within noise. Keep v150 live; extending v170/v171 to seeds 1418-1433.
- Hosted cap statistics (rounds 4440-4479, ~5.8k seat-episodes): 9 capped legs (16.8M), needing 4-6 kills (2 with a win once); median score by (kills, win): 0/L 4, 1/L 36, 2/L 384, 3/L 4,608, 4/L 55k, 5/L 4.0M; 0/W 384, 1/W 1,920, 2/W 18k, 3/W 74k, 4/W 295k, 5/W 393k, 6/W 8.0M. Leaders' 75-89k round medians ≈ one 3-kill win plus a 4-kill loss per 12 episodes. Kill count per episode (2-4) with survival is the lever.
- v174 (shelter + bounty + late guarded jackal) 7 eps: meanSeat 18,423 (max 414,720), win 14% (best so far), kills/seat 0.79, no capped leg. ROUND 4474 = v150's first real hosted round: mean 4,828/seat, best 55,296, 1 win, 10 kills, 0 tk (round sum ≈ 58k vs v149's ≈1k; leaders 80-110k this round). Standing 176,334 rank 15 (decaying until the new sums accumulate).
- 18:40Z local 24 eps: v170 meanSeat 145k (median 16, win 7%, kills 0.73), v171 179k (median 12, win 8%, kills 0.64); seeds 1418-1433 alone: v170 5,317 / 5%, v171 4,345 / 6% vs starter:cautious 14k / 5k — no clear winner locally. HOSTED: round 4475 (v150 2nd): mean 71,714/seat, best 663,552, 1 win, 15 kills (round sum ≈ 860k, TOP of the round; daf 65,830 next); round 4476: mean 2,059, 0 wins, 8 kills (≈25k). v150 sums so far 58k / 860k / 25k — competitive; keep v150.
- 18:47Z HOSTED DIAGNOSIS (round 4475 replays, 11 episodes of v150): in most episodes our seat's only controller intents were supply_run:hold (×2) followed by reflex_zone_escape — the guarded supply_run wins the ladder at full HP on hosted (hp_frac/medkit_dist readings pass) and emits a hold, so the seat camps at spawn and only the zone reflex moves it; kills come from return fire. Wins (663k, 69k) were outlasting. v175 = v170 without supply_run, v176 = v171 without supply_run. Shipping v175.
- 18:42Z v152 (= v175: v170 without supply_run) uploaded and submitted (auto-champion). Local replays confirm the same supply_run:hold pattern on runtime7 (hp_frac guard passes at full HP).
- 18:48Z ROOT CAUSE of the supply_run holds (server.nim:3668): self.hp_frac = hp / (maxHp + ShieldLayerHp) — full health without a shield reads 4/7 = 0.571 (duo era: 3/6 = 0.5), so every guard of the form hp_frac < 0.6/0.67 passed at full HP and supply_run took the ladder. Correct 'hurt' guard: hp_frac < 0.3 (hp ≤ 2 of 4). This also explains the 0.7.328 'dead guard' collapse (round 3983): it was the same arithmetic, not dead readings.
- 18:47:32Z jordan-ctf-candidate:v152 (= recipe v175: v170 minus supply_run) is ACTIVE (lpm_7f7f7ba…); v150 benched. First v152 rounds expected from ~4478. Codex workers launched 18:48Z: task-mtt0vfji-8qp1v1 (engine combat/perception model → research/s2_combat_model.md), task-mtt0vfo1-ewfzh8 (leader analysis from rounds ≥4440 + replays 4469/4475 → research/s2_leaders_solo.md).
- round 4477 (v150, last before v152): mean 21.5k best 221,184 wins 1 kills 8 → sum ≈258k; apex 143.9k mean.
- 18:50Z local v174 seeds 1418-1433 (15 eps, 60 seats): meanSeat 10.9k max 368,640 win 8% kills/seat 0.70; pooled with seeds 1410-1417 (28 seats): 22 eps, win ~10%, kills ~0.73. v177 (corrected hp guards: supply_run < 0.3, jackal >= 0.4) first 3 eps: meanSeat 668k (one 7.96M leg), win 25% — tiny sample; seeds 1418-1433 running for v177 (buwypcn5t) and v175 (beqcdyokh).
- 18:55Z coworld check: engine main = dbd80a34 (c3f7781b + #456 'default cover-hold from fresh threats' — native fallback only, no wire change; #457 renames epoch→call number, wire byte-identical). Hosted round 4477 already ran on 0.7.352; v150 kills normal (8). No parser/bot change needed. Forum (Solbiati 'lessandro', 09-08 12:34Z, r4378-4439 on 0.7.349, 11,615 seat rows): MEDIAN LEG BY TAG COUNT win/loss = 0: 384/4; 1: 1,536/36; 2: 17,856/432; 3: 65,280/4,608; 4: 294,912/36,864; 5: 1.18M/166k; 6: 11.8M/11.0M; 7: 16.8M. Win multiplier decays 96x→1.1x; 11 of 59 capped rows DIED. Nine of 16 entrants banked a 2^24 leg in r4378-4421; one such leg pays 838,861 into the standing (EMA k=0.05). ⇒ tags per episode are the lever; survival matters only below ~4 tags. His v29 'keep duelling after a won round' edit was falsified (t|win 2.06→1.55). Snapshot research/forum/paintbot_new_2026-09-08T18.json.
- 18:55Z local seeds 1410-1417 (8 eps, 32 seats each): v175 (=live v152) meanSeat 2.9k win 6% kills 0.81 | v176 9.2k win 3% kills 0.69 | v177 (6 eps) 334k (one 7.96M leg) win 12% kills 0.75 | v174 (7 eps) 18k win 14% kills 0.79. All within noise except v177's early lead; same-seed 1418-1433 runs pending for v177/v175 (v174-1418: 10.9k, win 8%, kills 0.70).
- 19:03Z local v177 seeds 1410-1417 done (8 eps, 32 seats): meanSeat 316,838 (max 7.96M) >=10k 4 win 12% kills/seat 0.88 — best of v174/v175/v176/v177 on these seeds (v175 2.9k/6%/0.81; v176 9.2k/3%/0.69; v174 18k/14%/0.79). Hosted 4478 (v152 first round, 0.7.353 = engine dbd80a34): mean 220 best 2,304 wins 0 kills 6 over 13 eps — weak; replays fetched to check behaviour.
- 19:12Z ROUND 4478 ANALYSIS (13 replays mined): a quiet round for the whole field (per-seat medians 5-27 glory; only bruce banked a 2^24 leg, sum 16.8M). Sums: bruce 16.8M, nancy 251k, huddle:159 177k, glory-warden 137k (3 wins), Monet 130k, co-gas-relhal 42k, huddle:160 38k, ... jordan v152 2,868 (6 kills, 1 win at 2,304), apex 2.2k, lessandro 196. Median death tick: field 1408-1779, ours 1473 (3rd earliest). Our intents: 97% reflex_zone_escape (1535 of 1589 intent changes) — the native zone reflex owns movement during every shrink for EVERYONE (field 36-95%; Monet 81%, huddle 79%, apex 95%); our own controller intents were only 13 edge_ride:cover, 12 edge_ride:hold (seats stand still at spawn ~180 ticks), 13 jackal:join, 4 loot:fetch, 9 default:cover (engine #456). NO supply_run holds (fix confirmed). Leaders emit ~2x more intent changes per seat (aaron 249, lessandro 241, arisk 236 vs ours 122): their controllers move seats between shrinks; ours camp. Kills/seat this round: huddle 1.3-1.6, Monet 1.0, co-gas 0.8, aaron 0.75, ours 0.46. Zone reflex = greedy per-tick step maximising (insideNext, safeTicks, -distNext) within ReflexCandidateRadiusPx; it triggers when zoneTicksUntilOutside(self) is small and releases when > ReflexZoneReleaseTicks.
- 19:04Z jordan-ctf-candidate:v153 (= recipe v177: v175 + supply_run guarded hp_frac<0.3 & medkit_dist in (0,500), whenHpBelow 3; jackal guard hp_frac>=0.4) uploaded 19:03Z and submitted with auto-champion (pending). Local 8-ep evidence favours it (win 12%, kills 0.88, meanSeat 317k).
- 19:10Z FIELD LADDER CENSUS (round 4478, all 16 entrants): nearly everyone opens target_law(prefer …) > scatter(320,300) > edge_ride(margin 180-300, enterLead 120-260, coverBias 0.75-0.9); recalls 5-13 per seat add per-episode pacts/never-lists (lw-pax pacts 3 seats, nancy 1 with protect, lessandro 1-4, glory-warden never-lists 1 seat) and jackal. Custom plays: Monet fire_superiority(breakDeficit 2, coverMax 260, engageDist 600, finishRange 140, pressRange 400, woundedPct 50); apex warden(holdTeams 0, lanePx 90, preferMode 3, protectOwn) > loot(detourMax 2500); bruce farm_hold + anchor12 (+ target_law never one seat, edge_ride 180/140/0.75) — banked the round's only 2^24 leg; co-gas custom edge_ride with scatterHeading/scatterSteps; huddle (most kills, 1.3-1.6/seat) loot(contested race, prefer grenade, detourMax 400) > scatter > edge_ride 220/160/0.75 > jackal(600, hpFloor 2) > crossfire, some with supply_run(race, 500, whenHpBelow 2). Ours: 3 fixed calls, no scatter, margin 420. Shouts are 10 chars within 247 px (no long-range negotiation channel).
- 19:20Z THE BLOC (round 4478 pact/never census, 13 replays): lw-pax (Lawrence) pacts at tick ~160-290 with, every episode, one huddle seat (daveey/daveey-1), one co-gas seat (relh/richard) and OUR seat (Jordan) — chosen by roster display name (play_context.roster carries names). lessandro pacts with huddle+lw-pax+jordan+co-gas; co-gas pacts (t~650-1050) with huddle, lw-pax, lessandro, jordan; Monet once with lw-pax+huddle+jordan; nancy pacts 1 seat (bruce/aaron/huddle/daf); glory-warden, arisk, macromackie only add never-lists mid-game (often including us). Mutual pacts seen: co-gas<->lw-pax 10/12, co-gas<->lessandro 6. Edges toward us: co-gas 14, lw-pax 11, glory-warden 5, macromackie 3, arisk 2 — all one-sided (we reciprocate 0). Plan: add a roster-name placeholder ($NAMES:Lawrence|relh|richard|daveey|lessandro|softmaxwell) to the bot (Codex task-… launched 19:20Z) and ship a recipe with pact(partners=$NAMES, protect, onBetrayal returnFire) + target_law(never=$NAMES) so we join the bloc: peace with up to 7 of 15 opponents, revive eligibility, ally-stack multipliers, and a place in the bloc's late game (placement x2/x3/x4).
- 19:08Z round 4479 (v152's 2nd): mean 608 best 5,184 wins 0 kills 7 → sum 7.3k (apex 689k mean, soft-codexter 277k). v152 two rounds: 2.9k + 7.3k, kills 6-7 per 12 eps — the no-supply_run change did not lift tags; the structural problem is ~0.5 kills/seat and mid-game deaths.
- 19:09Z jordan-ctf-candidate:v153 (= v177) ACTIVE (lpm_e0bb5b4…); v152 benched after rounds 4478-4479.
- Naming-us frequency (4478): lw-pax pacts us 11/12 at tick ~160-205 (before play starts); co-gas never-lists us 14/25, pacts 6/25 (t 650-1050); glory-warden never 5/12; macromackie 3/12; lessandro 2/12 (pact); Monet 2/12; arisk 2/13; nancy 1/12. pact manifest: partners set 1-8 refs required, holdFire default {aliveTeams:2} (dissolves at 2 teams), onBetrayal returnFire|disengage, protect bool. Decision for v178: pact partners = $NAMES:Lawrence|relh|richard (onBetrayal returnFire), target_law never = $NAMES:Lawrence only; keep pact in every call.
- 19:20Z CODEX REPORTS landed (research/s2_combat_model.md, research/s2_leaders_solo.md; analysis/s2_replay_positions.py re-simulates replays hash-exactly for per-tick positions). Engine facts: vision = 120° cone to 1950 px + 90 px bubble, walls block; gun 1300 px hitscan, 1 HP/hit, 4 HP seats, native release every 19 ticks, hit prob 80% @1300 / 99% @650; longshot >= 866 px (x3), point-blank <= 136; prefer tags: isolated is a no-op in solo (all 1.0), weakened = 1-hp/7, bounty = veteran (level>=3) fresh track, revenge = identified attacker < 120 ticks; native target scalar rewards 220-300 px range band; medkits 41 (heal to 4 on walkover), shields 13 (+3 HP layer, gun cooldown x3), sprays 6 (REPLACE the gun: 170 px cone, 3 HP), grenades 22 (2 HP splash 52 px, thrown natively at targets >= 90 px); zone phases at 0/419/602/863/1313/2476 elapsed with DPS 0/3/6/10/15/20 per 24 unsafe ticks; speed 2.75 px/tick per axis; solo downed seats die immediately unless a MUTUAL pact ally is upright (360-tick bleed, revive within 40 px for 48 ticks). Leaders (408 eps each): apex K/ep 0.963 win 12% D/ep 4.76 (static warden>loot, no recalls); Monet 0.816/7.1% (custom fire_superiority, ring_walker, hold_vs_gun); daveey 0.809; docxology 0.873/9.1%; Lawrence 0.777; relh 0.848; Jordan v149 0.411/3.9%, v150 0.854/14.6% (48 eps). 1M+ rounds (41 of 544) = one jackpot episode (best episode = 99.3% of the sum). Realized factors: Final 8/4/2 x2/x3/x4, win x8, longshot x3, closing x3, last light x4, territory +1 rung, heat x1/2/4/8, first Tier-V x12, clean sheet x2, JointAct x3. Our deaths: median killer distance 232 px (136-565), never at longshot; supply_run:hold was the last controller in 7/9 v150 losses. Ranked advice: (1) drop/fix supply_run [done: v153], (2) recalled margin 120-140 → 240, (3) custom lane_warden controller modeled on apex, (4) prefer bounty (drop isolated), (5) custom longshot standoff play. Report advises AGAINST reciprocal pacts (Lawrence already no-shoots us 14/15, relh 7/15; only 1 of 9 combat deaths came from them) → v178 shelved as a functional test only.
- 19:18Z ROUND 4480 (v153's first): mean 33,154 best 331,776 wins 0 KILLS 16 (1.33/ep — our best hosted kill count; v150 rounds had 10/15/8/8, v152 6/7) → sum ≈398k; co-gas 408k mean. Same-seed local 1418-1433 (15 eps, 60 seats): v177 K/seat 0.92 win 10% mean 7.1k vs v175 0.77 / 7% / 4.9k — the corrected supply_run helps on both axes. v178 local check: roster parsed from play_context (names match hosted display names).
- 19:25Z v178 local check: the pact call was REJECTED (notSorted:call.plays[0].params.partners) — engine 'set' params must be lexicographically sorted ("seat:11" < "seat:2"); the bot fell back to bare edge_ride. Fixed the expansion to sort refs; the field's calls confirm the order (never=[seat:12,seat:13,seat:3]).
- 19:25Z ROUND 4480 REPLAYS (v153): our 12 seats — win with 3 kills (331,776), 2nd with 3 kills (41,472), 3rd with 4 kills (20,736), 2nd with 2 kills (2,304, died t3341), then 1,296/144/48/36/18/12/6/2; median death tick 1650 (v152 in 4478: 1473). Intents: reflex_zone_escape 1911, jackal:join 248 (the hunt now runs), loot:fetch 16, edge_ride:cover 12, supply_run:medkit 6 (no holds — the hp_frac fix works), reflex_clear_grenade 7. Standing 19:17Z: Jordan 195,358 rank 15 (leaders softmaxclaudius 1.58M, softmaxwell 1.38M, daveey 1.04M, pawchuck 949k).
- 19:27Z v178 (bloc) local check with the sorted expansion: all 3 calls ACCEPTED (partners [seat:11,seat:2], never [seat:10] resolved from roster names); 4 eps: K/seat 0.69 win 12%. Shelved for hosted use per the leader report (one-sided truces already protect us); available as research/s2_patches/recipes/v178-solo-bloc.env.
- 19:27Z round 4481 (v153 2nd): mean 30,784 best 368,640 wins 0 kills 11 → sum ≈369k (huddle 1.41M mean = a capped leg). v153 so far: 398k + 369k. v179 local (5 eps): K/seat 0.55 win 0% — early sign the bundled changes (scatter+bounty+margin 240) do not help; isolating scatter (v181) and jackal reach/margin (v182) locally.
- 19:30Z v179 local (8 eps, seeds 1410-1417, same seeds as v177): K/seat 0.53 win 0% meanSeat 535 vs v177 0.88 / 12% / 317k → REJECTED; the bundle (scatter opener + prefer bounty + margin 240 recalls + loot medkits=true) hurts. Isolation batches v181 (scatter only) and v182 (jackal 900 + margin 240) running.
- 19:41Z round 4482 (v153 3rd): mean 18,664 best 221,184 wins 0 kills 10 → sum ≈224k. v153 rounds: 398k / 369k / 224k with 16/11/10 kills (v152: 2.9k/7.3k, 6/7 kills). Local isolation (7 eps each, seeds 1410-1416): v181 scatter-only K 0.71 win 11% mean 1.5k; v182 jackal900+mid240 K 0.71 win 4% mean 4.6k; v177 on the same seeds K 0.88 win 12% mean 317k — neither change helps so far. Codex delivered bot/plays/lane_warden.nim (cover-hugging zone controller: hold at cover inside margin, enter next rect when ticksToShrink<=120, retreat below standoffMin / when hp<=enemy inside 500 px, approach beyond standoffMax, flee below hpFloor; 33.7 KB wasm; harness tests pass; committed ad62453) plus research/s2_apex_behaviour.md: apex parks at cover posts (12 px median vs our 81 px; 60% of stationary ticks within 16 px of a post vs our 20%), keeps 246 px zone-edge clearance (ours 97), moves hard in the opening (1.53 px/tick vs our 0.58), freezes through shrink 1, and fights at ordinary range (gun releases at 315 px median, kills at 298 px; only 1 of 21 kills >= 866 px). Smoke (v180: standoff 866/1250, margin 420) and v180b (apex-like: margin 240, standoffMin 300, standoffMax 1300) running locally.
- 19:55Z LADDER SEMANTICS (src/shell/ladder.nim stepSeat, verified on the v180 smoke replays): the FIRST live controller whose guard passes is stepped; if it has a CACHED intent (from any earlier step) that intent is the base and selection STOPS; if it has no cache and did not fault → native default (NOT the next rung); only a FAULTED entry advances selection. Consequences: (1) reference scatter 'yields' by emitting nothing after its 300 ticks, but its last navigate stays cached → every rung below scatter never runs until the next call (the field's 'scatter > edge_ride' ladders are really 'scatter burst, then stand there + zone reflex', and leaders re-call 5-13x per episode to re-trigger scatter); (2) a guarded controller that passes and emits a hold (jackal:hold when no fresh kill) freezes the seat while its guard passes; (3) v180 smoke never ran lane_warden (0 installs) — it measured scatter+hold: 4 eps K 0.75 win 19% incl. one 16.8M leg; v181 (scatter-only) similarly. Testing lane_warden as the sole controller (v180c).
- 19:51Z round 4483 (v153 4th): mean 2,567 best 20,736 wins 0 kills 13 → sum ≈31k (co-gas 664k mean). v153 four rounds: sums 398k/369k/224k/31k, kills 16/11/10/13 = 50 in 48 eps = 1.04 K/ep (apex 0.96, Monet 0.82) — tag rate is now leader-level; the gap is the jackpot legs (one 4-6 tag episode with placement/win/heat/longshot factors). Killed the v180b batch (it could not exercise lane_warden — scatter owned the ladder).
- 19:55Z v180c (lane_warden as sole controller, 2 eps): the play runs — intents cover 48, enter 23, flee 16, hold 5, margin 3, hold_cover 3 (+457 zone reflex); outcomes 0-1 kills per seat. Running v180d (target_law > supply_run(g) > lane_warden, recall 900 same; no scatter/loot/jackal) and v180e (v180d + guarded jackal above lane_warden at 900), 8 eps each on seeds 1410-1417 vs v177 (K 0.88 win 12%).
- 19:57Z isolation batches final (seeds 1410-1425): v181 scatter-opening (16 eps, 64 seats) K 0.69 win 8% mean 25.8k (one 1.33M leg); v182 jackal900+mid240 (15 eps) K 0.75 win 5% mean 4.7k; v177 pooled 23 eps K ~0.90 win ~11%. Neither beats v177 → v153 stays live. Next: lane_warden ladders v180d/v180e (running) and v180f (= v180d with standoffMin 866: keep enemies at longshot range from cover).
- 20:08Z ROUNDS 4484-4485 (v153): 4484 mean 39,060 best 294,912 WINS 2 kills 15 (sum ≈469k); 4485 mean 1,481,629 best 16,777,216 (OUR FIRST CAPPED 2^24 LEG) wins 1 kills 18 (1.5/ep) → sum ≈17.8M. v153 six rounds: 398k/369k/224k/31k/469k/17.8M; kills 16/11/10/13/15/18 = 83 in 72 eps = 1.15 K/ep. Expect the standing to jump ≈ +0.05 x 17.6M ≈ +880k (from 195k). Local lane_warden ladders (seeds 1410-1417 vs v177 K 0.88 win 12% mean 317k): v180d clean K 0.82 win 7% mean 44.6k (7 eps); v180e +jackal K 0.82 win 14% mean 15.6k (7 eps); v180f longshot standoff K 0.88 win 12% mean 116k (max 3.54M) — all within noise of v177; no reason to replace v153 while it banks.
- 20:10Z 4485 capped leg anatomy: seat 8 (ereq_bc2ef00e) 4 kills, win, 0 deaths, hitDamage 17, achievements sniper+silent → 16,777,216. Same round: 3 kills + 4th place → 995,328; 2 kills + win → 1,536; 4 kills + 2nd (died t3320) → 5,184. Field kills in the capped episode: Jordan 4, relh 2, daveey 2, others ≤1.
- 20:31Z LEADERBOARD 20:17Z: Jordan 1,045,860 RANK 3 (softmaxclaudius 1,208,998; daveey-1 1,203,051; softmaxwell 1,028,644; richard 782,163). Round 4486 (v153): mean 19.7k best 221k wins 1 kills 16 (sum ≈237k); 4487 in progress (7 eps: 50k mean, 276k best, 1 win, 6 kills). CODEX v153 ANALYSIS (research/s2_v153_hosted_analysis.md, 72 eps): 83 kills = 1.153/ep — highest in the field (apex 0.724, Monet 0.595, daveey 0.877 in the same rounds; paired bootstrap beats apex and Monet); every jackpot (7 eps >= 100k, 9.7%) had 3-4 kills; kills median 302 px, 6 longshots (4 of 19 jackpot kills vs 2 of 54 others); zone reflex owns 81% of live ticks, jackal:hold only 0.31% (4 bouts, harmless); deaths 21/52 to ZONE, 19 of them already outside — phase-5 dud survivors ran at 3 px clearance (jackpots 71 px) because the recalls ask for margin 140/120. Ranked one-variable tests: (1) recalled margin 240/240 (prior +0.03-0.10 K/ep, +1-3 pp jackpots), (2) prefer bounty instead of isolated, (3) lane_warden(240,866,1250,260,2) as the bottom rung. Shipping (1) as v183. Local v180f-1418 (11 eps): K 0.75 win 9% mean 72k vs v177-1418 K 0.88 win 9% mean 6.7k — level.
- 20:32Z jordan-ctf-candidate:v154 (= recipe v183: v177 with recalled edge_ride margins 140/120 → 240/240, nothing else) uploaded and submitted with auto-champion (pending). Standing 20:32Z: Jordan 1,011,080 rank 3 (softmaxclaudius 1,148,951; daveey-1 1,143,299).
- 20:36Z jordan-ctf-candidate:v154 (= v183, recalled margins 240) ACTIVE (lpm_93d6d21…); v153 benched after rounds 4480-4487. Judge v154 after ≥6 rounds (from ~4489): kills per 12 eps (v153 baseline 1.15/ep), zone-death share (v153 40%), jackpot rate (v153 9.7% of eps ≥100k).
- 20:40Z round 4487: 6 of 13 episodes FAILED platform-side (failed_policy_index null, none ours); the 7 completed had our seats at mean 50k, best 276k, 1 win, 6 kills. Next recipe queued: v184 (= v183 + prefer bounty) after v154 has ≥6 rounds.
- 20:40Z round 4488 (v153 last): mean 225 best 1,728 wins 0 kills 12 → sum 2.7k (kills stay ≥10/round). v153 final: 8 rounds 4480-4488 (4487 partial), 111 kills in 91 eps = 1.22/ep. Local v180f-1418 done — see next line.
- 20:41Z local v180f-1418 (16 eps, 64 seats): K 0.70 win 6% mean 49.8k (max 2.65M) vs v177-1418 K 0.88 win 9% mean 6.7k; pooled v180f 24 eps K 0.76 win 8% vs v177 K 0.88 win 10% — lane_warden longshot standoff trades kills/wins for a fatter tail; not a hosted candidate ahead of v183/v184.
- 20:48Z round 4489 (v154 first): mean 6,583 best 36,864 wins 1 KILLS 18 in 13 eps (1.38/ep) → sum ≈86k. Standing 20:47Z: Jordan 960,863 rank 3 (daveey-1 1,459,677 after a capped leg; softmaxclaudius 1,114,663; softmaxwell 929,212).
- 20:52Z v154 deployment verified from round 4489 replays: opening margin 420, recalls at 900/1500 carry margin 240. Engine main moved to 20a3d01b (#461 hazard guard paths for escape plays; #459 reflex-plays decision record) — additive; watch for a coworld bump.
- 20:55Z round 4489 ran on coworld 0.7.355. Engine #461 adds guard paths world.zone_ticks_until_outside (0 outside, else ticks to next shrink, -1 none), world.grenade_threat/grenade_ticks_to_blast, world.spray_threat/spray_impact_count — usable once deployed (unknown-path guards are REJECTED on older builds, so do not use them until a hosted round confirms the build). #459/#461 are 'the first half of the reflex-removal plan': the native zone-escape reflex (81% of our live ticks) may be replaced by guard-gated escape plays in a future build — when that lands our ladder must carry its own zone escape (edge_ride enter/margin or lane_warden enter) or seats will die in the gas. Watch the changelog every session.
- 21:38Z *** RANK 1 *** at 21:32Z: Jordan 1,251,542 (daveey-1 1,182,432; softmaxclaudius 995,202; softmaxwell 830,776; docxology 823,042). v154 six rounds 4489-4494: sums ≈86k / 1.34M / 4.98M / 4.06M / 592k / 1.06M; kills 18/18/9/23/12/19 = 99 in 76 eps = 1.30/ep (v153 1.22); wins 1/0/1/1/0/2; best legs 4.98M (4491), 3.98M (4492), 1.33M, 664k, 590k. The recalled-margin-240 change looks like a genuine tail improvement (5 of 6 rounds with a ≥590k leg vs v153's 2 of 8). Decision: keep v154 live for ≥6 more rounds before the bounty test (v184); now doing the rank-1 duties — threat scan of rising entrants and a weakness analysis of v154's replays.
- 21:40Z THREAT SCAN (sums over rounds 4489-4494, 6 rounds): Jordan 12.11M (2.02M/round, K/ep 1.30) | docxology (daf-paintbot-s2-v4) 9.73M (1.62M/round, K/ep 0.68, standing 823k — RISING FASTEST; its ladder: target_law prefer [bounty,revenge,weakened,isolated] > scatter > edge_ride 240/260/0.8, recalls add jackal 900 bothWeakened hpFloor 0 + loot medkits) | NanosaurusX 4.66M (777k/round) | pawchuck 4.31M | softmaxclaudius 2.94M (standing 995k) | softmaxwell 2.68M | daveey-1 1.16M (standing 1.18M, decaying). Our lead is real but docxology's jackpot rate on 0.68 K/ep is worth understanding (Codex v154 analysis launched 21:40Z).
- 22:06Z CODEX v154 ANALYSIS (research/s2_v154_hosted_analysis.md, 76 eps): 1.303 K/ep, 15 three-plus-kill eps (19.7%), 13 wins, 7 jackpots (9.2%), 0 capped; paired kills higher than daveey-1 (+0.69), apex (+0.54), docxology (+0.58), bruce (+0.61), Aaron (+0.58), level with Monet (+0.42, CI touches 0). Margin 240 landed: zone deaths 40%→25%, phase-5 dud clearance 3→63 px, outside share 33.6%→0.5%. Remaining: 16 zone deaths all moving+outside, 12 in phases 2-3; supply_run owned the cached intent at 13 of 47 combat deaths (6 medkit pickups); jackal:hold 1.04% of ticks (no deaths); tail conversion unchanged (9 of 15 three-plus eps and 9 of 13 wins below 100k); longshot association weakened (OR 3.1, p 0.20). Rivals in the same rounds: Monet 0.92 K/ep, apex 0.78, bruce 0.74, Aaron 0.73, docxology 0.69 (9.73M sum incl. an 8.86M round — bounty-first ladder), daveey-1 0.64; no version changes in 4489-4494. Ranked next tests: (1) v184 bounty, (2) supply_run guard + (no enemy or nearest_enemy > 650), (3) recalled enterLead 80→160, (4) jackal bothWeakened, (5) v185 lane_warden. Round 4495 (v154 7th): mean 7.8k best 82.9k wins 0 kills 13 (sum 94k). Standing 22:02Z: Jordan 1,184,494 rank 1 (daveey-1 1,074,155). Shipping v184 now; v186 (supply clearance) and v187 (enterLead 160) recipes written.
- 22:07Z jordan-ctf-candidate:v155 (= recipe v184: v183 with prefer [weakened,bounty] in every call, nothing else) uploaded and submitted with auto-champion (pending). v154 baseline: 7 rounds 4489-4495, 112 kills in 88 eps = 1.27/ep, 7 jackpots.
- 22:11Z jordan-ctf-candidate:v155 (= v184 bounty) ACTIVE (lpm_f07d82f…); v154 benched after rounds 4489-4497 (4496 missing/failed). Round 4497 (v154 last): mean 1,110 best 6,144 wins 0 kills 9 (sum 13k); docxology mean 1.29M (a ≥15M round — its standing will jump ≈ +720k to ~1.47M and likely overtake us at the next tick). v154 final: 8 rounds, 121 kills in 100 eps = 1.21/ep.
- 22:13Z round 4496 FAILED platform-side. Jackpot anatomy (recent rounds): docxology 16.8M = 6 kills + win (4497); ours 4.98M = 3 kills + win (4491), 3.98M = 6 kills no win (4492); pawchuck 3.98M = 5 kills + win; NanosaurusX 4.42M = 5 kills + win. Capped legs need ~6 tags with the win, or the win plus 3-4 tags with heat/longshot/Tier-V stacking.
- 22:15Z v186 (supply_run guard + enemy clearance) local syntax check: all 3 calls accepted; ready to ship after v155's six rounds.
- 22:22Z leaderboard (division endpoint /divisions/div_aa7825db…/leaderboard; watcher restarted, script /tmp/lb_tick.py): docxology 1,372,639 (rank 1 after its 16.8M leg), soft-codexter-t2 1,090,472, Jordan 1,035,639 (rank 3), daveey-1 972,868, lessandro 878,525.
- 22:48Z v155 (bounty) first rounds: 4499 mean 58 best 432 wins 0 kills 7 (sum 0.8k); 4500 mean 26.8k best 345.6k wins 1 kills 12 (sum 349k); 4501 in progress. Rivals: soft-codexter-t2 capped 16.8M in 4499 (5 kills + win) after 2.65M in 4498; lessandro 1.12M mean in 4500. Note: do not run manual br_rounds fetches while a waiter loop is fetching (tmp-file rename race).
- 22:49Z correction: v155's first round was 4498: mean 96.9k best 884,736 wins 1 kills 16 (sum 1.16M). v155 after 3 rounds: 35 kills in 38 eps (0.92/ep, v154 1.27), sums 1.16M / 0.8k / 349k. Standing 22:48Z: docxology 1,304,465; soft-codexter 1,036,312; Jordan 985,455 (rank 3); daveey-1 924,549.
- 22:53Z round 4501 (v155 4th): mean 2,458 best 23,040 wins 1 kills 12 (sum 32k). v155 after 4 rounds: 47 kills in 51 eps = 0.92/ep (v154 1.27), sums 1.16M / 0.8k / 349k / 32k, wins 1/0/1/1.
- 22:54Z jordan-ctf-candidate:v156 (= recipe v186: v183 + supply_run guard requiring no tracked enemy or nearest_enemy > 650) uploaded, NOT submitted — next in the queue after v155's six rounds.
- 23:19Z v155 (bounty) VERDICT after 6 rounds 4498-4504 (4502 failed): kills 16/7/12/12/14/11 = 72 in 75 eps = 0.96/ep vs v154 1.30; wins 3 vs 13; legs ≥100k 3 vs 7; sums 1.16M/0.8k/349k/32k/1.11M/9k. REJECTED — prefer bounty loses ordinary kills (bounty = veteran level ≥3, rare; the target ordering evidently hurts). Submitting v156 (= v186: v183 recipe + supply_run enemy-clearance guard) with auto-champion. Standing 23:18Z: docxology 1,178,747; Jordan 942,590 (rank 2); soft-codexter 940,080; daveey-1 843,172.
- 23:20Z jordan-ctf-candidate:v157 (= recipe v187: v183 + recalled edge_ride enterLead 80→160) uploaded, NOT submitted — queued after v156. v156 qualifying (lpm_9acc28d…).
- 23:22Z jordan-ctf-candidate:v156 (= v186 supply clearance) ACTIVE (lpm_9acc28d…); v155 benched. First v156 round expected ~4506.
- 00:06Z 2026-09-09 STOP (user request). All watchers, loops, local batches and Codex jobs stopped. v156 (supply clearance) ACTIVE with 3 rounds: 4506 mean 439 best 3,456 kills 7 (sum 5k); 4507 mean 141k best 1,658,880 wins 2 kills 15 (sum 1.70M); 4508 mean 17.6k best 207k kills 10 (sum 211k) — 32 kills in 36 eps = 0.89/ep so far (v154 1.30; judge after ≥6 rounds). Standing 00:05Z: docxology 1,923,636; softmaxclaudius 1,328,314; daveey 1,148,361; daveey-1 930,703; Jordan 860,448 (rank 5). RESUME: (1) restart watchers (leaderboard: python3 /tmp/lb_tick.py — recreate from research/LEDGER.md 22:22Z if /tmp is gone; rounds: analysis/br_rounds.py fetch --since 4509 + analysis/s2_rounds.py --since 4506; push loop); (2) judge v156 after 6 rounds by kills/12 eps (v154 baseline ~14-15) and legs ≥100k; if worse, ship recipe v183 again (or submit v157 = enterLead 160, already uploaded); (3) queue: v157 → jackal bothWeakened → v185 lane_warden; (4) re-check engine main/coworld_version and the reflex-removal plan (#459/#461) before any ship.
- 2026-09-09 18:07Z RESUME (17.9 h after the stop). v156 still ACTIVE and played all night. LEADERBOARD COLLAPSED: soft-codexter 236,971; macromackie 139,582; daveey 127,494; softmaxwell 126,369; Lawrence 117,093; Jordan 112,647 (rank 6) — every standing fell from ~1M to ~100-240k, consistent with a standings re-seed when GLORYVERSION 17 shipped (engine #504 'S6 SHIP — catalog v3 default ON, GLORYVERSION 16→17, GameVersion 61→62' on the battle-royale-s2 manifest: kills/heat/territory/stack repriced UP (percent-scaled), placement ramp v3 with CONTINUOUS survival credit, BR assists/rescues score, pact-scoped wipe-down, fixed-point accumulator). Forum (Solbiati 09-09): payout ladder is 2^a·3^b with a = 1 + 2·kills + 6·win (each tag ×4 in a win, ×8 in a LOSS: loss rungs 2/12/96/768/9,216/147,456; win rungs 384/1,536/6,144/24,576/122,880/393,216, 6 tags caps); standing = s += 0.05·(clamp(round_sum, s/150, 150·s) − s), reconciles to the cent; latest build 0.7.374 (rounds 4582-4599 one tree). Fetching rounds 4506+ (background), rebuilding the engine clone at origin/main (/private/tmp/engine-main-v44, server /tmp/johomax-ctf-server-runtime8), watchers restarted.
- 18:12Z v156 (supply clearance) VERDICT over 28 fetched overnight rounds (4506-4508, 4590-4613; 336 eps): 0.86 K/ep (v154 1.30), 12 wins (3.6%), mean round sum 195k, 2 legs ≥1M, 0 capped → REJECTED (the guard declines medkits under fire, as the report warned). Under GLORYVERSION 17 (from ~4590, build 0.7.374; now 0.7.377) legs look smaller (e.g. 22 kills → best 491k; wins with 1-2 kills ≈ 16-30k). Restoring the v183 recipe (= v154) as a fresh upload with auto-champion to re-baseline under the new economy; v157 (enterLead 160) stays queued. Engine clone v44 (origin/main e6807465, GloryVersion 17) built: server /tmp/johomax-ctf-server-runtime8.
- 18:12Z jordan-ctf-candidate:v158 (= recipe v183, the v154 baseline) uploaded and submitted with auto-champion (pending). Playbook rebuilt on engine v44: every reference play byte-identical (play_sdk unchanged), bot /tmp/e12-bot-v10.
- 18:16Z version tags: paintbot-v0.7.377 = e6807465 (origin/main), 0.7.374 = #504 S6 ship → the live ladder runs current main: GLORYVERSION 17 AND the #461 guard paths (world.zone_ticks_until_outside, grenade_threat, grenade_ticks_to_blast, spray_threat, spray_impact_count) are available now. Local harness rebuilt on engine v44 (starters, playbook, bot v10, config v3); smoke batch running.
- 18:18Z FIELD UNDER GLORYVERSION 17 (rounds ≥4590 fetched so far, 24 rounds): soft-codexter mean round sum 404k (K/ep 0.72, best leg 7.08M); Games Bond 175k (3.54M); Lawrence 172k (3.15M); Jordan/v156 148k (K/ep 0.88 = field-best tie, win 11.4% = field-best, best leg 1.47M); docxology 69k; softmaxclaudius 50k; daveey 47k. New entrant 'Andre von Houck' (5 rounds, win 12.9%). Under v17 our kill/win engine is still top but our legs are smaller — need the v17 factor table (Codex running) to see what soft-codexter's 7M legs are made of.
- 18:17Z jordan-ctf-candidate:v158 (= v183 baseline) ACTIVE (lpm_ffe0dc5…); v156 benched. Judge under GLORYVERSION 17 after ≥6 rounds: kills/12 eps, win%, best legs vs soft-codexter (404k/round).
- 18:20Z local harness on engine v44 (GV62/GLORYVERSION 17) works: v183 recipe calls accepted, 4 eps; local legs are small under v17 (win with 1 kill ≈ 16,384).
- 18:22Z v156 full overnight record (62 rounds fetched): pre-v17 rounds 4506-4589 (38 rounds, 468 eps) K/ep 0.94, wins 3.2%, mean sum 174k, 2 legs ≥1M; v17 era ≥4590 (24 rounds, 295 eps) K/ep 0.86, wins 3.4%, mean sum 148k, 1 leg ≥1M. v154 in 4489-4494 had K/ep 1.30 and 17% wins → the supply clearance guard cut wins fivefold; rejected for good.
- 18:30Z GLORYVERSION 17 DIGEST (research/s2_glory_v17.md + hosted rounds ≥4590, 4,941 seat rows): deed bases tag x2.2, first blood x4, longshot x6, ace x9, closing time x1.2 (below the small-factor gate → usually a no-op), last light x8, splash x6, point-blank x2.5, rundown/revenge x4; heat rungs x1/x5/x14/x36 (same 1/2/4 ember thresholds, 270-tick cooling); placement final 8/4 x1, final 2 x1.3, win x8 flat; survival x1.02 per 720 alive ticks but skipped from small products (a hider scores 1); fixed-point accumulator with a cap bug that clamps the combat product at 16,384 early. EMPIRICAL LADDER (median score by kills, loss/win): 0: 2/384; 1: 12/1,536; 2: 64/6,144; 3: 768/24,576; 4: 3,072/73,728; 5: 10,752/491,520; legs ≥1M: soft-codexter 7.08M (4 kills+win, spotless+sniper+silent), Games Bond 3.54M (5+win), Lawrence 3.15M (6+win), Jordan 1.47M (4+win, banksy+silent). ⇒ same lever as before: 4-6 tags AND the win (achievement multipliers sniper/spotless separate the 7M legs from our 1.5M). Codex-ranked tests: (1) drop the opening holdTrigger (first blood x4 sees x5 heat), (2) jackal recall at 420 instead of 900, (3) reciprocal pact (ally stack x5, JOINT ACT x2, revive). v188 (no hold) and v189 (jackal 420) screening locally on the v17 engine.
- 18:33Z PACT CHECK (rounds 4612-4613 replays, 26 eps): lw-pax names our seat as a pact partner in every call (131 declarations), Monet in 55, nancy 20, lessandro 9, co-gas 5. Under v17 a MUTUAL pact pays: ally stack x5 on co-damaged kills, JOINT ACT x2, a real revive window, pact-scoped wipe-down. Recipe v190 = v183 + pact(partners $NAMES:Lawrence|softmaxwell, onBetrayal returnFire, protect false) in every call (no never-list, so betrayal is answered). Local acceptance check running; ship after v158's six-round baseline.
- 18:30Z jordan-ctf-candidate:v159 (= recipe v190: v183 + pact with Lawrence and softmaxwell) uploaded, NOT submitted (awaiting the local acceptance check and v158's baseline). Round 4617 (v158 first): mean 1,372 best 16,384 wins 0 kills 11.
- 18:32Z v190 (pact) local check: all 3 calls accepted, partners resolved from roster names (seat:15 = softmaxwell locally). v159 is ready to submit after v158's six rounds (~19:15Z).
- 18:39Z local screens on the v17 engine (8 eps each, seeds 1410-1417): v188 no-hold K/seat 0.62 win 9%; v189 jackal@420 K 0.72 win 9%; v183 smoke (4 eps) K 0.56 win 6% — no red flags, all calls accepted, within noise. Round 4618 (v158 2nd): mean 13 best 99 wins 1 kills 17 — a WIN with 17 team kills paid only 99: under v17 the combat product caps at 16,384 and the leg size is decided by post-cap multipliers (win x8, achievements, first Tier-V, clean sheet, JointAct). Launching a Codex decode of the 7.08M / 3.54M / 1.47M legs.
- 19:15Z V17 LEG DECODE (research/s2_glory_v17_legs.md): the million-point legs in rounds 4594-4603 were still v16 (coworld 0.7.374 = GameVersion 61 without the five flags; e.g. 7,077,888 = deeds 1,536 x first Gun-V x12 x placement x24 x clean x2 x win x8). The REAL v17 ladder starts at 0.7.377 (round ~4611): every factor (deeds, heat, placement, survival, clean sheet, win x8) folds inside one fixed-point product whose cap is still the raw 2^24 on a 1024-scaled accumulator → a seat reports AT MOST 16,384; losers bank it too (4617: our 16,384 leg with 0 wins); only friendly-fire halving acts outside the cap. Round sums therefore max at 12 x 16,384 = 196,608 and the ladder now rewards HOW OFTEN a seat caps: ~3 chained tags inside heat windows (x2.2 → x11 → x30.8), or a longshot (x6, +first Gun-V x3.46) plus first blood (x4 at heat x5). Result badges (sniper/spotless/silent) are worth x1. Codex ranking: remove the opening hold, jackal recall early, reciprocal pact (ally stack x5, Joint Act x2; but a pact ally downing us halves the bank). v158 under v17: 5 rounds 4617-4621, best legs 16,384/99/46/144/483 = 1 capped leg in 60 eps (field: ~1 per round). DECISION: ship v191 = v183 minus the opening holdTrigger with the guarded-jackal recall at tick 760 (both aggression levers), judge by capped legs (score = 16,384) per round; v159 pact next.
- 19:17Z CAP RATE since 4611 (analysis/s2_caps.py, capped legs per 12 eps): Andre von Auto 0.86 (new entrant, 98 eps), Ari Sklar 0.61, docxology 0.52, softmaxclaudius 0.52, daveey 0.43, Jordan 0.36 (4/134), richard/relh/macromackie/soft-codexter/Aaron 0.35, Lawrence/softmaxwell/pawchuck/daveey-1 0.26. Round sums will converge to ~5-15k for everyone; current standings are pre-v17 remnants decaying 5%/round. Objective: most capped legs per round.
- 19:18Z v158 under v17 (rounds 4617-4622, 71 eps): 1 capped leg (0.17 per 12), kills 11/17/14/11/14/9, wins 3 — the v154 recipe does not cap. v160 (= v191 cap hunter) submitted, qualifying. Codex cap-routes analysis running (task-mtuhc8da-p38mt1; a duplicate launch was cancelled).
- 19:20Z jordan-ctf-candidate:v160 (= v191 cap hunter) ACTIVE (lpm_6ea85e0…); v158 benched. First rounds from ~4623; metric: capped legs per round (analysis/s2_caps.py --since 4623).
- 19:37Z CAP ROUTES (research/s2_v17_cap_routes.md, rounds 4611-4621): 74 caps in 2,464 seats (3.0%); 82% of cappers LOST (cap ≠ win); all 18 trace-verified caps came on the 1st or 2nd kill: 12/18 used First Blood (tag x2.2 then First Blood x21.2 at heat), 11/18 a longshot (x6.24, +first Gun-V claim x3.46 which triggered 7 caps), e.g. tag+FirstBlood then any heated deed within 270 ticks; longshot+FirstBlood+GunV caps on ONE kill. Our failures: 65/134 seats died with 0 kills; consecutive kill gaps median 351 ticks (5/8 > 270); kills during shrinks minted as CLOSING TIME x1.27 (below the small-factor gate → worthless) — a 4-kill win scored 8; only 1 of 18 local kills was a longshot; First Blood in 2/24. Ranked tests on top of v191: (1) jackal above loot at 760 (+0.3-0.8 pp caps), (2) tightly guarded longshot lane_warden rung (enemy_count==1, 866-1300 px, hp>=0.5, in_zone, zone_ticks_until_outside>120, no grenade/spray threat) (+0.3-1.0 pp), (3) reciprocal pact overlay (+0.5-1.5 pp, risk: an ally down halves the bank). Round 4623 (v160 first): mean 1.3, 0 caps, 8 kills. Recipes v192 (jackal above loot) and v193 (v192 + guarded longshot lane) written; v193 guard syntax checking locally, then pre-upload.
- 19:40Z v193 (v191 + jackal above loot + guarded longshot lane_warden using the #461 guard paths) accepted locally on engine v44 (all 3 calls); uploaded as jordan-ctf-candidate:v161, NOT submitted — decision after v160's six rounds (~20:20Z). Ladders: 760 = target_law > supply_run(g) > lane_warden(g) > jackal(g) > loot(g) > edge_ride; 1500 = target_law > supply_run(g) > jackal(g) > lane_warden(g) > edge_ride.
- 20:18Z v160 (v191 cap hunter) six rounds 4623-4628: 3 caps in 75 eps = 0.48 per 12 (v158 0.17, v156 0.36; window leaders Aaron/lessandro 0.64), kills 8/12/9/9/10/18, wins 3. Submitting v161 (= v193: v191 + jackal above loot + guarded 866-1300 px lane_warden rung) for a ≥12-round window; standing 20:17Z Jordan 60,801 rank 6 (soft-codexter 126,820, all decaying).
- 20:22Z engine main moved to 1fbb6b83 (docs + #512 achievements as lightable modes, dark by default, not armed); latest tag still paintbot-v0.7.377 — no cap-bug fix yet. v194 (= v193 + reciprocal pact) written; local check + pre-upload running.
- 20:21Z jordan-ctf-candidate:v161 (= v193 longshot-lane bundle) ACTIVE (lpm_9dd1c74…); v160 benched after rounds 4623-4628. Judge over ≥12 rounds by caps per 12 (v160: 0.48).
- 20:22Z v194 (= v193 + reciprocal pact with Lawrence|softmaxwell) accepted locally; uploaded as jordan-ctf-candidate:v162, NOT submitted — next after v161's 12-round window.
- 22:28Z v161 (v193 longshot-lane bundle) 12 rounds 4630-4641: 3 caps / 152 eps = 0.24 per 12 (v160 0.48), K/ep 0.91, 5 wins; window cap leaders daveey 0.64, daveey-1 0.56, Aaron 0.55, Games Bond 0.47, relh 0.41. Not better than v160. v162 (= v194: v193 + reciprocal pact Lawrence|softmaxwell) submitted with auto-champion; 12-round window next. Standing 22:27Z: Jordan 35,100 rank 7 (soft-codexter 71,759; everything still decaying toward the ~10k v17 steady state).
- 22:31Z jordan-ctf-candidate:v162 (= v194 lane + pact) ACTIVE; v161 benched. 12-round window from ~4643.
- 22:43Z V161 DIAGNOSIS (research/s2_v161_window.md): v161 0.24 caps/12 vs rivals 0.55-0.64 (all intervals cross zero — level, but under-capping); kills/seat 0.91 (v160 0.88), 0-kill deaths 45% (49%), wins 10.5%; cap conversion among killful seats 3.7% vs v160 7.9%. Static analysis of the guarded lane_warden: with the guard active its flee/retreat branches are unreachable, world.enemy_count counts REMEMBERED tracks (~5 s memory) so a stale track can own movement (cover/hold) and pre-empt loot/edge, and there is a 701-865 px hand-off band with no finisher → likely inert-to-harmful. Recommendation: test v192 (v191 + jackal above loot, NO lane) next rather than reverting to v191. DECISION: replace v162 (which keeps the lane) with v195 = v192 + reciprocal pact — the pact test on the clean base; v192 without pact is the fallback; v191 after that.
- 22:51Z jordan-ctf-candidate:v163 (= v195: v192 no-lane + jackal above loot + reciprocal pact) ACTIVE (lpm_6b1e63f…); v162 benched after ~2 rounds. 12-round cap window from ~4645.
- 00:15Z 2026-09-10 STOP (user request). All watchers, loops, batches and Codex jobs stopped. v163 (= v195: v191 + jackal above loot + reciprocal pact) ACTIVE since 22:51Z with 7 rounds 4645-4651: 3 caps in 88 eps = 0.41 per 12 (v160 0.48, v161 0.24), kills 7-12 per round, e.g. 4649 mean 9 best 46, 4650 1 win, 4651 best 65. Standing 00:15Z: soft-codexter 45,273; macromackie 28,344; softmaxwell 27,557; daveey 27,075; Lawrence 23,511; Jordan 23,173 (rank 6) — all decaying toward the v17 steady state (~1-10k). RESUME: (1) restart watchers (leaderboard python3 /tmp/lb_tick.py every 15 min — recreate from LEDGER 22:22Z 09-09 if /tmp is gone; rounds: br_rounds.py fetch --since <last> then s2_rounds.py and analysis/s2_caps.py --since <round>; push loop); (2) judge v163 after ≥12 rounds by caps per 12 vs v160's 0.48 and the field (0.4-0.6); if level or worse, ship v192 (no pact) then v191; (3) check engine main/tags for the 16,384 cap fix (GLORY_CAP / recutProductCap) — if fixed, the economy reverts to big legs where wins/placement matter and the v183/v154 recipe family is the baseline again; (4) uploaded-unsubmitted versions: v157 (enterLead 160), v159 (v183+pact), v161 (lane, rejected), v162 (lane+pact). Reports: research/s2_glory_v17.md, s2_glory_v17_legs.md, s2_v17_cap_routes.md, s2_v161_window.md.
