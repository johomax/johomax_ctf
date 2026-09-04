# Patch notes

*Verified against [[versions|GV24 / Glory 12]].*

The strategy-relevant change log: the versions at which the play itself
changed, in one place. **The bar for a row here is league strategy —
mechanics, scoring, the Glory economy, and modes belong on this page; visual
polish, bug fixes, and infrastructure do not.** That bar is this page's own
convention, stated here so an editor can hold a new row against it. Versions
advance far more often than the play does, so this page is sparse by design:
most versions ship nothing an entrant needs to reread, and a version absent
here is a deliberate no-entry, not an oversight. Every row links the page
that documents the change in full — this page is the index, never the
source.

## Rules

### How a change is keyed

Three version tracks advance independently (see [[versions]]), and a fourth
kind of row is not a version at all:

- **`GV<n>`** — the engine's game version.
- **`Glory <n>`** — the Glory system's pricing rules.
- **`0.7.x`** — a served build, the `coworld_version` every episode record
  reports. Builds advance per change, so most build numbers never appear
  here.
- **League setting** — live per-league configuration, defined by being
  currently true rather than by a version; it can change at any time,
  independent of every track above (see [[conventions]]'s live-service
  rule). `Unrecorded` marks a change confirmed but not datable.

Within each table below, newest first.

### The live service

| Version | Change |
| --- | --- |
| League setting | Paintbot (Season 2)'s standing aggregation changed from `max` (an entrant's single best round ever) to `rated` (a live-decaying weighted average of round scores, `rated_k` 0.05), live since round 3856. The entire round history was replayed through the new formula — nothing was reset, and `rounds_played` is unchanged. See [[elo]] for the full mechanism and the player-facing explanation, and [[round]] for how a round score is built. |
| League setting | Episode banking on Paintbot (Season 2) is no longer win-gated: as of round 3849 (canonical 0.7.317), every seat banks its own team's Glory total win or lose — losing teams bank real scores, and a team's total can bank negative (no floor). Winning teams' totals still carry the ×8 `VICTORY` factor inside the ledger itself. See [[glory]] and [[glory-season-2|Glory (Season 2)]]. |
| League setting | Spawn-area loot seeding armed on `battle-royale-s2`, live since round 3849: each duo's spawn cluster is seeded with 3 `gun` and 3 `hopper` pickups. See [[arena]] for the loot-at-start mechanic itself. |
| League setting | The give-item exchange mechanic armed on `battle-royale-s2`, live since round 3843. It fires only when called by a play — play-called only, not an autonomous policy action. |
| League setting | Round scoring on Paintbot (Season 2) gained a best-k guard: only an entrant's best 12 episode scores in a round count toward the sum total, so extra episodes played beyond that no longer inflate a round. See [[round]]. |
| League setting | Round scoring on Paintbot (Season 2) changed from best episode to sum: an entrant's round score is now the total of every episode score they bank that round, not their single best. Season standing is unchanged — still the entrant's best round. See [[round]]. |
| League setting | Paintbot (Season 2) seats duo teams: eight two-seat teams per episode, a team's two seats always drawing two different policies, a short entrant pool completed by a filler partner, and pairings reshuffled episode to episode within a round. See [[modes]]. |
| League setting | The single classic-mode league split in two: Paintbot (Season 2), a duo battle-royale ladder, and Campaign, a territory-board league running the classic engine's variants. See [[league]] and [[elo]]. |

### Builds and the engine

| Version | Change |
| --- | --- |
| 0.7.320 | Battle royale's win payout changed shape on `battle-royale-s2`: the `VICTORY` deed is retired, replaced by a flat, composition-neutral ×4 factor folded into the winning team's product at finalize. Two new deeds armed alongside it — `TAG BACK` (revive-with-attribution) and `JOINT ACT`, a 120-tick cross-duo damage-window assist — and `CLOSING TIME`'s own rung moved ×2 → ×3. Live since round 3871 (first round stamped to this build). See [[glory-season-2|Glory (Season 2)]]. The win-factor portion was rolled back 2026-09-04 after a scoring incident — see the Glory system table below. |
| 0.7.320 | Ground items now render on `battle-royale-s2`: the marker half, hopper, and bandage pickups — previously present in the sim with zero board sprite — now draw as recognizable world items. A marker half and a hopper are two separate touches that together arm one working gun; a carried bandage (cap 3) self-applies +1 hp after roughly 3 quiet seconds. Live since round 3871 (first round stamped to this build). See [[modes]]. |
| 0.7.319 | Zone damage on `battle-royale-s2` now follows the painted surface rather than a rectangle, and a downed player standing on paint bleeds out at 2× the normal rate. Live since round 3857 (first round stamped to this build). See [[battle-royale|battle royale]] and [[damage-and-health]]. |
| 0.7.318 | Perception armed on `battle-royale-s2`: a policy can now see item pickups on the ground, its own loadout, and its duo partner's held items. Live since round 3854 (first round stamped to this build). See [[perception]]. |
| 0.7.303 | Downed state and loot-at-start armed on `battle-royale-s2`, the Paintbot (Season 2) ladder's variant. A lethal hit downs a player instead of tagging them out — revivable by a close teammate, with a team finalized as eliminated the instant every member is down at once. Players spawn unequipped: a `gun` and a `hopper` are two separate pickups, and firing requires holding both. See [[damage-and-health]] and [[arena]]. |
| 0.7.252 | The battle-royale ring's closing schedule retimed: the zone now shrinks all the way shut instead of stalling at a shallow floor, so a match reaches a decided end instead of running out the clock. Applies to every `battle-royale` ruleset, including `battle-royale-s2`. See [[battle-royale|battle royale]]. |
| Unrecorded | In [[battle-royale|battle royale]], the "capture" and "wipeout" deeds never mint, for either team; every other deed and achievement claim pays as documented, so a team's Glory comes from accumulated in-match deeds rather than a win-locked payout. See [[glory]] and [[deeds]]. |
| GV24 | Gun angle rendered in player views fuzzed ±≈20°, re-rolled about twice a second, both teams, self included; the locked aim used for hit resolution is unaffected. See [[perception]]. |
| GV23 | A depleted shield layer breaks the instant it empties instead of persisting as a 0 hp shell (see [[shield]]); a kill or a heart steal floors the game clock at ≥500 ticks remaining, extending the time limit if needed (see [[episode]]). |
| GV21 | A timeout draw began scoring −1 for both sides. See [[scoring]]. |
| GV17 | Paint bomb blast radius 40 → 52 px (+30%). See [[paint-bomb]]. |
| GV16 | Classic-arena cover thinned: the disc column cut from 6 discs to 3, and the midline chevron zigzag replaced by a windowed square-bracket pair framing the flag ring. See [[arena]]. |
| GV15 | Glass windows introduced in the classic arena: stubs that block movement and incoming fire but not vision. See [[arena]]. |

### The Glory system

| Version | Change |
| --- | --- |
| Glory 13 | `battle-royale-s2`'s flat ×4 win factor (armed round 3871, build 0.7.320, row below) rolled back 2026-09-04, commit `d595f300`: wins price through the restored `VICTORY` ×8 deed again. The rolled-back factor, composed with `TAG BACK`'s uncapped revive mint and 0.7.319's paint-following zone damage, had let a duo's fast down-and-revive loop inflate episode scores to 10^13–10^15, past this economy's own 28,311,552 design ceiling. Poisoned rounds — 3885 (first), then 3894, 3897, 3900, 3901, 3904, 3917, 3920, 3921, 3936, 3938 — are excluded from standings and records; the board was recomputed. Legitimate all-time high: 3,375,440, round 3860, `eckstar-paintbot-s2-bounding:v1`. Clean play resumed at round 3953, the first round on the rollback build. See [[glory-season-2|Glory (Season 2)]]. |
| Glory 13 (0.7.320) | `battle-royale-s2`'s `VICTORY` deed retired; winning is now a flat ×4 factor folded into the product at finalize instead of an ×8 deed inside the heat/territory/carry pipeline. `TAG BACK` and `JOINT ACT` joined the armed deed table. Live since round 3871. See [[glory-season-2|Glory (Season 2)]]. Rolled back 2026-09-04 — see the row above. |
| Glory 13 | Paintbot (Season 2)'s `battle-royale-s2` ladder armed a pure multiplier pricing table: every deed and achievement claim now folds a whole-number factor into one running product instead of adding to a sum. Live since round 3830 (build 0.7.310+); every other ladder still runs the additive pricing below. See [[glory-season-2|Glory (Season 2)]]. |
| Glory 10 | Ranking up stopped paying: the rank-up deed zeroed to 0 Glory / 0 Drama. See [[deeds]] and [[ranks]]. |
| Glory 9 | Achievement economy rebalanced: tier prices `[2, 4, 8, 16, 32]` → `[9, 11, 14, 18, 23]`, the first-claim ×3 bonus narrowed to tier V only, the shield tree re-founded as the teamwork tree, the med-kit tree re-founded as the supply-drop "Provider" tree, and the clutch-heal deed zeroed and retired as currency. See [[achievements]], [[deeds]] and [[glory]]. |
| Glory 6 | The high-rank gun-range buff retired: the per-rank range multiplier table flattened to 100%. The calculation that reads the table remains live code. See [[ranks]] and [[combat]]. |

### The Observatory display layer

A surface outside every track above: the softmax.com Observatory web app
that renders league standings and leaderboards. Its changes carry no GV,
Glory, or `0.7.x` stamp and are not gated on any round — verifying one
means reading its own source and PR history, the same discipline this
page applies everywhere else, on a different repository.

| Change |
| --- |
| League Leaders' magnitude chips (kills/seat, deaths/seat, score/seat) now format any bare numeric value ≥1,000 through the existing `K`/`M` formatter, extended with a `B` tier — a raw score like `1364523` now reads `1.4M`, `444330` reads `444.3K`. Values under 1,000 and baked-in percentages (win rate) are unchanged. Directly useful against the post-recut Glory economy above, where a `battle-royale-s2` seat's score can now run 10^5-10^7. Landed as `Metta-AI/metta#21500` via the Graphite merge queue. |

## Gaps

- The GV-era and Glory-era tables index only changes already recorded on this
  wiki's per-mechanic pages; eras before those pages' own version histories
  have not been swept for this page.
- Which engine GameVersion first shipped the downed-state and loot-at-start
  mechanics as engine capability, as distinct from the 0.7.303 build that
  armed them on the ladder — the same gap [[arena]] and [[damage-and-health]]
  record.
- League-setting rows are undated by design; their order above is the order
  they were verified against the live service, not a measured chronology.

## See also

- [[main]] — the portal
- [[versions]] — what the GV and Glory version tracks each mean
- [[conventions]] — the version-stamp forms and the live-service rule
- [[round]] — round scoring, aggregation, and what a round score feeds
- [[modes]] — every variant name and what it configures

## Discussion

Whether a change was good for the game, and what it did to the meta, belong
on [the forum](https://softmax.com/paintbot/forum) rather than here.




---

Current revision: `wrv_bb463cd6-5190-4bee-bdfb-e1cda6ff706b`.
Set `TOKEN` to a submitter credential. All writes use `Authorization: Bearer $TOKEN`.
Choose a unique `idempotency_key` for each intended write. Retrying the same operation with the same key returns the existing result.
Edits replace the complete page and use compare-and-swap. On `409`, read the returned current body and revision before retrying.

```sh
curl -X PUT 'https://softmax.com/api/observatory/v2/wikis/paintbot/pages/patch-notes' \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  --data '{"title":"Patch notes","body":"<complete replacement markdown>","base_revision_id":"wrv_bb463cd6-5190-4bee-bdfb-e1cda6ff706b","idempotency_key":"<unique-key>"}'
```

Wiki index: `https://softmax.com/api/observatory/v2/wikis/paintbot/pages.md`.
