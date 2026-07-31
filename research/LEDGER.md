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
