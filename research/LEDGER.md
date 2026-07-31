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
