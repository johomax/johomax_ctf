# Apex movement in Season 2 solo battle royale

## Scope and method

This is a deterministic re-simulation of all 28 replay files under
`research/s2_replays/{4469,4475,4478}_*` with engine
`/private/tmp/engine-main-v43`. The engine's `tools/extract_events.nim` emitted
one position/HP frame per tick and the event stream; every replay passed its
recorded hash checks. Policy identity and seat came from each round's
`report.json`, never from seat order. The sample contains 27 apex seat-episodes
(18,695 live ticks) and 28 `jordan-ctf-candidate` seat-episodes (26,427 live
ticks). Apex had an accepted `warden` call in 24 of its 27 episodes.

Positions below use the cog centre (the frame's top-left position plus 6 px).
Zone clearance is signed distance to the nearest edge of the engine's effective
(board-clamped) current rectangle: positive inside, negative outside. “Zone
centre” is the centre of that current rectangle, including its authored drift
toward the episode's random final centre. Quartiles and medians pool live ticks,
so late-phase rows describe only seats that survived that far.

## Ten findings

1. Apex held **246 px** from the current zone edge at the median (IQR 79–377), versus Jordan's **97 px** (39–266).
2. Apex was outside the effective rectangle for **3.08%** of live ticks, versus Jordan's **4.89%**.
3. Apex stayed **654 px** from the moving zone centre at the median (IQR 428–1,023); Jordan stayed **507 px** away (236–989).
4. Apex moved hard during the 259-tick opening hold (mean **1.53 px/tick**) and then was stationary for **99.0%** of the first 160-tick shrink.
5. There are no waits between authored shrinks: phases 2–6 begin immediately, so “between-shrink” motion is a sequence of bursts as edge clearance falls, not motion during intermissions.
6. Apex was stationary on **64.8%** of live tick transitions, with a median **14.3 s stationary per episode**; Jordan was stationary on **76.2%**, median **17.4 s**.
7. Apex's stationary body centre was a median **12.0 px** from an engine cover-atlas post; Jordan's was **81.3 px** away.
8. Within 8 px of a post accounted for **32.5%** of apex stationary ticks and **2.9%** of Jordan's; within 16 px, the shares were **59.8%** and **19.7%**.
9. At 127 apex gun releases the nearest live enemy was only **315 px** away at the median (IQR 241–402, maximum 573); apex was not maintaining a longshot stand-off.
10. Apex's 21 kills were at **298 px** median victim range (IQR 226–646; maximum 890), while its combat-attributed deaths put the killer **504 px** away at the median (IQR 361–563).

Restricting apex to the 24 episodes with an accepted `warden` preserves the
result: median edge clearance 259 px, stationary share 63.5%, stationary-post
distance 12.2 px, and 37.4% of stationary ticks within 8 px of a post.

## Zone-relative movement over time

The schedule is a 259-tick full-board hold followed by six consecutive shrinks
of 160, 183, 261, 450, 1,163, and 1,275 ticks. No sampled seat reached the
post-schedule final hold. `n` is pooled live ticks; speed includes zero-motion
ticks.

| Segment | Apex n | Apex edge median | Jordan edge median | Apex centre median | Jordan centre median | Apex stationary | Jordan stationary | Apex mean px/tick | Jordan mean px/tick |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Pre-shrink hold | 6,354 | 368 | 310 | 941 | 1,128 | 41.0% | 76.9% | 1.53 | 0.58 |
| Shrink 1 | 3,360 | 328 | 231 | 910 | 1,088 | 99.0% | 92.4% | 0.03 | 0.23 |
| Shrink 2 | 2,978 | 125 | 57 | 761 | 863 | 75.5% | 59.0% | 0.62 | 1.13 |
| Shrink 3 | 2,691 | 100 | 66 | 554 | 572 | 59.7% | 66.7% | 1.11 | 0.88 |
| Shrink 4 | 1,822 | 63 | 57 | 352 | 333 | 60.8% | 80.2% | 1.00 | 0.53 |
| Shrink 5 | 1,455 | 46 | 52 | 183 | 137 | 83.2% | 81.0% | 0.44 | 0.42 |
| Shrink 6 | 35 | 3 | 7 | 131 | 87 | 17.1% | 26.2% | 1.75 | 1.62 |

When moving, both policies traveled at about native speed: apex's opening
moving-tick mean was 2.59 px/tick and its shrink 2–5 means were 2.43–2.75;
Jordan's corresponding values were 2.21–2.75. The difference is therefore
when movement is switched on. Apex first selects a lane/post during the opening
hold, nearly freezes through shrink 1, then makes sustained inward bursts in
shrinks 2–4 as its median edge clearance compresses from 328 to 63 px.

## Cover parking

A cover post here means a point in the exact immutable atlas built by
`shell/body_map.nim` for that replay's generated map. A “park” is at least 24
consecutive live frames (one second) at exactly the same body position; an
8-px distance is arrival-radius scale, not a claim of exact coordinate
equality.

| Measure | Apex | Jordan candidate |
|---|---:|---:|
| Median nearest-post distance on stationary ticks | 12.0 px | 81.3 px |
| Stationary ticks within 8 px / 16 px | 32.5% / 59.8% | 2.9% / 19.7% |
| Parks of at least one second | 46 | 78 |
| Median park duration | 204 ticks / 8.5 s | 187 ticks / 7.8 s |
| Longest park | 1,102 ticks / 45.9 s | 1,317 ticks / 54.9 s |
| Live time belonging to parks | 60.1% | 71.8% |
| Park time within 8 px of a cover post | 34.7% | 2.7% |

Jordan parks more because its edge controller often leaves a stable goal, but
those stops are usually open-ground ring positions. Apex parks less often yet
parks at genuine cover far more often. The 24 accepted-warden episodes sharpen
that contrast: 40.5% of long-park time was within 8 px of an atlas post.

## Combat distances

“Nearest enemy” uses every enemy alive immediately before the event tick, not
only fog-visible tracks. Kill range is the killer-to-victim centre distance.
Killer distance is reported only for combat-attributed deaths; environmental
deaths have no killer. Values are median (IQR), in pixels.

| Event | Apex | Jordan candidate |
|---|---:|---:|
| Gun release → nearest enemy | n=127, **315** (241–402), range 57–573 | n=166, **310** (188–419), range 13–854 |
| Kill → victim | n=21, **298** (226–646), range 13–890 | n=27, **249** (146–380), range 14–548 |
| Kill → nearest live enemy | n=21, **292** (226–371) | n=27, **225** (127–373) |
| Death → nearest live enemy | n=25, **323** (230–449) | n=24, **369** (243–470) |
| Combat death → credited killer | n=17, **504** (361–563), range 57–1,013 | n=17, **445** (232–510), range 136–883 |

Only one apex kill reached the 866-px longshot threshold; no Jordan kill in
this 28-replay slice did. The observed `warden` signature is consequently
“claim a real cover lane early, stay still while safe, and move inward in
bursts,” not “hold every opponent at gun-range.” A new controller can retain
that cover/zone cadence while adding explicit 866–1,250 px separation, close
enemy retreat, and low-HP disengagement—the unexploited mechanism suggested by
the engine's accuracy and scoring rules.
