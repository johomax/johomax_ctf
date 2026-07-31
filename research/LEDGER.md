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
