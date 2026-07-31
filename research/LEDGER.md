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
