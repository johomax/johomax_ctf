## Invariant tests for the Shout-Intel protocol.
##
## Run: nim r bot/baseline/shoutintel_test.nim
##
## These cover the five properties the design cannot survive losing:
## codec fidelity through the server's sanitizer, observation-time
## reconstruction through N relay hops, order-insensitive merge, the absence
## of phantom freshening in a relay loop, and PICKUP dominance over GONE.

import std/[options, random, strformat]
import shoutintel

var failures = 0
var checks = 0

proc ok(cond: bool, what: string) =
  inc checks
  if not cond:
    inc failures
    echo "FAIL: ", what

proc section(name: string) =
  echo "\n-- ", name

# ---------------------------------------------------------------------------
# The server's sanitizer, reproduced so the codec can be tested against it.
# ---------------------------------------------------------------------------

proc sanitize(s: string): string =
  ## Non-printables dropped, then leading/trailing spaces stripped -- the two
  ## transformations the server applies before anyone hears the text.
  var kept = ""
  for c in s:
    if ord(c) >= 32 and ord(c) < 127:
      kept.add(c)
  var lo = 0
  var hi = kept.len - 1
  while lo <= hi and kept[lo] == ' ': inc lo
  while hi >= lo and kept[hi] == ' ': dec hi
  if lo > hi: "" else: kept[lo .. hi]

# ---------------------------------------------------------------------------

section "codec: extremes round-trip, and survive the sanitizer"

proc roundTrip(r: Record, seqNo: int): Record =
  ## Encode at age 0 and decode, so the observation tick comes back exactly and
  ## every payload field can be compared for equality.
  let now = r.obsTick
  let msg = Message(version: Version, seq: seqNo, recs: @[r])
  let text = encodeMessage(msg, now)
  ok(text.len == MsgLen, &"length is {MsgLen}, got {text.len}")
  ok(sanitize(text) == text, &"survives sanitizer unmodified: '{text}'")
  ok(text[0] != ' ' and text[^1] != ' ', "never starts or ends with a space")
  for c in text:
    ok(c >= AlphaLo and c <= AlphaHi, &"char '{c}' inside the alphabet")
  let got = decodeMessage(text, now + 1)
  ok(got.isSome, "decodes")
  got.get.recs[0]

block sightExtremes:
  for enemy in 0 ..< EnemyCount:
    for cell in [0, 1, CellCount div 2, CellCount - 1]:
      for flags in 0 ..< 8:
        let r = Record(kind: ikSight, obsTick: 1000, enemy: enemy, cell: cell,
                       heart: (flags and 4) != 0, shield: (flags and 2) != 0,
                       arc: (flags and 1) != 0)
        let g = roundTrip(r, 0)
        ok(g.kind == ikSight and g.enemy == enemy and g.cell == cell and
           g.heart == r.heart and g.shield == r.shield and g.arc == r.arc and
           g.obsTick == r.obsTick, &"SIGHT round-trip e={enemy} c={cell} f={flags}")

block deathExtremes:
  for enemy in 0 ..< EnemyCount:
    for lives in 0 .. 3:
      for known in [false, true]:
        let r = Record(kind: ikDeath, obsTick: 500, enemy: enemy,
                       cell: CellCount - 1, lives: lives, idKnown: known)
        let g = roundTrip(r, 7)
        ok(g.kind == ikDeath and g.enemy == enemy and g.lives == lives and
           g.idKnown == known and g.cell == CellCount - 1,
           &"DEATH round-trip e={enemy} l={lives} k={known}")

block pickupExtremes:
  for spawn in 0 ..< SpawnCount:
    for taker in 0 ..< PlayerCount:
      for known in [false, true]:
        let r = Record(kind: ikPickup, obsTick: 77, spawn: spawn,
                       taker: taker, takerKnown: known)
        let g = roundTrip(r, 3)
        ok(g.kind == ikPickup and g.spawn == spawn and g.taker == taker and
           g.takerKnown == known, &"PICKUP round-trip s={spawn} t={taker}")

block goneExtremes:
  for spawn in 0 ..< SpawnCount:
    let r = Record(kind: ikGone, obsTick: 12345, spawn: spawn)
    let g = roundTrip(r, 1)
    ok(g.kind == ikGone and g.spawn == spawn, &"GONE round-trip s={spawn}")

block twoRecords:
  # Both records in one shout must survive together.
  let
    a = Record(kind: ikSight, obsTick: 900, enemy: 5, cell: 3000, heart: true)
    b = Record(kind: ikGone, obsTick: 900, spawn: 9)
    text = encodeMessage(Message(version: Version, seq: 2, recs: @[a, b]), 900)
  ok(text.len == MsgLen, "two-record message is still 10 chars")
  let got = decodeMessage(text, 901)
  ok(got.isSome and got.get.recs.len == 2, "two records decode")
  ok(got.get.recs[0].enemy == 5 and got.get.recs[0].heart, "record 0 intact")
  ok(got.get.recs[1].kind == ikGone and got.get.recs[1].spawn == 9,
     "record 1 intact")
  ok(got.get.seq == 2, "sequence survives")

block rejects:
  ok(decodeMessage("go go go!!", 10).isNone, "human chatter rejected")
  ok(decodeMessage("", 10).isNone, "empty rejected")
  ok(decodeMessage("~short", 10).isNone, "short payload rejected")
  ok(decodeMessage("~ abcdefgh", 10).isNone, "space in payload rejected")
  # A version we do not speak must be ignored rather than misparsed.
  var bumped = Message(version: Version, seq: 0,
                       recs: @[Record(kind: ikGone, obsTick: 0, spawn: 1)])
  let good = encodeMessage(bumped, 0)
  ok(decodeMessage(good, 1).isSome, "our own version decodes")

# ---------------------------------------------------------------------------

section "time: observation tick reconstructs through N relay hops"

proc hop(r: Record, sendTick, firstSeen: int): Record =
  ## One agent re-emits a held record; the next agent decodes it.
  let text = encodeMessage(
    Message(version: Version, seq: 0, recs: @[r]), sendTick)
  decodeMessage(text, firstSeen).get.recs[0]

block oneHop:
  let origin = Record(kind: ikSight, obsTick: 1000, enemy: 2, cell: 500)
  for delay in 0 .. 40:
    let got = hop(origin, 1000 + delay, 1000 + delay + 1)
    ok(got.obsTick <= origin.obsTick,
       &"never fresher than origin (delay {delay})")
    ok(origin.obsTick - got.obsTick <= AgeUnit,
       &"within one quantum of truth (delay {delay})")

block saturationIsNotBelieved:
  # The regression this suite was written to catch. A 6-bit age saturates at
  # 63 quanta; if a relayer emits a record older than that, the age it writes
  # understates the truth and the receiver reconstructs `sendTick - 253` -- a
  # time that advances with the RELAYER's clock. Left unguarded, such a record
  # gets fresher on every hop and never dies.
  let origin = Record(kind: ikSight, obsTick: 1000, enemy: 2, cell: 500)
  ok(sendable(1000 + MaxAgeTicks - AgeUnit, origin.obsTick),
     "a record inside the horizon is sendable")
  ok(not sendable(1000 + MaxAgeTicks, origin.obsTick),
     "a record at the horizon is not sendable")
  # Even if some other agent ignores that and emits it anyway, we refuse it.
  for lateness in [MaxAgeTicks, MaxAgeTicks + 200, MaxAgeTicks + 5000]:
    let sendTick = 1000 + lateness
    let text = encodeMessage(
      Message(version: Version, seq: 0, recs: @[origin]), sendTick)
    ok(decodeMessage(text, sendTick + 1).isNone,
       &"an over-age record is refused, not believed (late by {lateness})")

block lateListenerDoesNotOverDate:
  # A listener who drifts into earshot part-way through a bubble's ~3s life
  # sees it for the first time long after it was said. Dating it from that
  # first sight would make the fact look up to 3s fresher than it is, and
  # because the merge keeps the freshest copy, the inflated one wins and then
  # gets relayed onward. Declaring the uncertainty is what prevents it.
  let origin = Record(kind: ikSight, obsTick: 1000, enemy: 1, cell: 200)
  let sendTick = 1002
  let text = encodeMessage(
    Message(version: Version, seq: 0, recs: @[origin]), sendTick)

  # In range from the start: exact dating, no penalty needed.
  let prompt = decodeMessage(text, sendTick + 1, 0).get.recs[0]
  ok(prompt.obsTick <= origin.obsTick, "on-time listener is not over-fresh")

  # Wandering in 50 ticks late, but honest about not having been there.
  let late = decodeMessage(text, sendTick + 51, BubbleLifeTicks).get.recs[0]
  ok(late.obsTick <= origin.obsTick,
     &"late listener is not over-fresh ({late.obsTick} vs {origin.obsTick})")

  # And the inflated reading must never beat the honest one in a merge.
  var s: IntelStore
  s.merge(prompt)
  s.merge(late)
  ok(s.sight[1].rec.obsTick <= origin.obsTick,
     "the merged result is still no fresher than the original observation")

  # The unguarded reading is exactly the bug: it dates the fact 50 ticks late,
  # i.e. FRESHER than it really is. Pin that so the guard cannot be dropped.
  let unguarded = decodeMessage(text, sendTick + 51, 0).get.recs[0]
  ok(unguarded.obsTick > origin.obsTick,
     "without the penalty the late reading really would be over-fresh")

block manyHops:
  # Six agents relay the same fact down a chain, each holding it a while.
  var rec = Record(kind: ikSight, obsTick: 1000, enemy: 4, cell: 77)
  var t = 1000
  var prev = rec.obsTick
  for hopNo in 1 .. 6:
    t += 9                                   # held ~9 ticks before re-emitting
    rec = hop(rec, t, t + 1)
    ok(rec.obsTick <= prev, &"hop {hopNo} did not freshen the record")
    prev = rec.obsTick
  ok(1000 - rec.obsTick <= 6 * AgeUnit,
     &"6 hops drifted {1000 - rec.obsTick} ticks, bounded by {6 * AgeUnit}")
  ok(rec.enemy == 4 and rec.cell == 77, "payload intact after 6 hops")

# ---------------------------------------------------------------------------

section "merge: idempotent and order-insensitive"

proc digest(s: IntelStore): string =
  ## A total, order-free description of a store, for comparing outcomes.
  template dump(arr: untyped, tag: string) =
    for i in 0 ..< arr.len:
      if arr[i].has:
        let r = arr[i].rec
        result.add(tag & $i & ":" & $r.obsTick & ":" & $packPayload(r) & " ")
  dump(s.sight, "S")
  dump(s.death, "D")
  dump(s.pickup, "P")
  dump(s.gone, "G")

block permutations:
  var rng = initRand(20260728)
  for trial in 1 .. 200:
    # A pile of facts, deliberately including same-key collisions and exact
    # duplicates -- the cases where arrival order could plausibly matter.
    var recs: seq[Record] = @[]
    for i in 0 .. 11:
      let kind = IntelKind(rng.rand(3))
      var r = Record(kind: kind, obsTick: rng.rand(400))
      case kind
      of ikSight:
        r.enemy = rng.rand(EnemyCount - 1)
        r.cell = rng.rand(CellCount - 1)
        r.heart = rng.rand(1) == 1
      of ikDeath:
        r.enemy = rng.rand(EnemyCount - 1)
        r.cell = rng.rand(CellCount - 1)
        r.lives = rng.rand(3)
        r.idKnown = true
      of ikPickup:
        r.spawn = rng.rand(SpawnCount - 1)
        r.taker = rng.rand(PlayerCount - 1)
        r.takerKnown = true
      of ikGone:
        r.spawn = rng.rand(SpawnCount - 1)
      recs.add(r)
    recs.add(recs[0])            # exact duplicate
    recs.add(recs[3])            # and another

    var base: IntelStore
    for r in recs: base.merge(r)
    let want = digest(base)

    for shuffleNo in 1 .. 6:
      var perm = recs
      rng.shuffle(perm)
      var s: IntelStore
      for r in perm: s.merge(r)
      ok(digest(s) == want, &"trial {trial} shuffle {shuffleNo} converged")

    # Idempotence: replaying the whole set again changes nothing.
    var again = base
    for r in recs: again.merge(r)
    ok(digest(again) == want, &"trial {trial} replay is a no-op")

block duplicateIsNoop:
  var s: IntelStore
  let r = Record(kind: ikSight, obsTick: 100, enemy: 1, cell: 9)
  ok(s.merge(r), "first merge changes the store")
  ok(not s.merge(r), "second merge of the same record does not")

block staleLoses:
  var s: IntelStore
  s.merge(Record(kind: ikSight, obsTick: 200, enemy: 1, cell: 5))
  ok(not s.merge(Record(kind: ikSight, obsTick: 150, enemy: 1, cell: 6)),
     "an older sighting cannot displace a newer one")
  ok(s.sight[1].rec.cell == 5, "the newer sighting is still what we hold")

# ---------------------------------------------------------------------------

section "relay loop: no phantom intel"

block twoAgentLoop:
  # A and B relay to each other for ten seconds. If freshness ever derived
  # from receipt instead of observation, the record would be immortal and its
  # obsTick would keep climbing. It must instead decay out of the store.
  let originTick = 1000
  var a: IntelStore
  var b: IntelStore
  a.merge(Record(kind: ikSight, obsTick: originTick, enemy: 3, cell: 42))

  var t = originTick
  # Long enough that the fact must age past MaxAgeTicks WHILE it is still
  # being actively relayed -- that is the point, not that it dies once we stop.
  for round in 1 .. 60:
    t += 6
    # A shouts whatever it holds; B hears it.
    if a.sight[3].has:
      let text = encodeMessage(
        Message(version: Version, seq: round mod 8, recs: @[a.sight[3].rec]), t)
      let got = decodeMessage(text, t + 1)
      if got.isSome:
        b.merge(got.get.recs[0])
    # B shouts back; A hears it.
    if b.sight[3].has:
      let text = encodeMessage(
        Message(version: Version, seq: round mod 8, recs: @[b.sight[3].rec]),
        t + 2)
      let got = decodeMessage(text, t + 3)
      if got.isSome:
        a.merge(got.get.recs[0])
    ok(not a.sight[3].has or a.sight[3].rec.obsTick <= originTick,
       &"round {round}: A's copy never became fresher than the original")
    ok(not b.sight[3].has or b.sight[3].rec.obsTick <= originTick,
       &"round {round}: B's copy never became fresher than the original")
    a.expire(t)
    b.expire(t)

  ok(not a.sight[3].has and not b.sight[3].has,
     "the fact expired out of both stores instead of circulating forever")

block threeAgentRing:
  # Same question with a ring, where a record can come back around having been
  # re-encoded twice rather than once.
  let originTick = 500
  var s: array[3, IntelStore]
  s[0].merge(Record(kind: ikDeath, obsTick: originTick, enemy: 6, cell: 100,
                    lives: 2, idKnown: true))
  var t = originTick
  for round in 1 .. 60:
    for i in 0 .. 2:
      t += 2
      let nxt = (i + 1) mod 3
      if s[i].death[6].has:
        let text = encodeMessage(
          Message(version: Version, seq: round mod 8,
                  recs: @[s[i].death[6].rec]), t)
        let got = decodeMessage(text, t + 1)
        if got.isSome:
          s[nxt].merge(got.get.recs[0])
      ok(not s[nxt].death[6].has or s[nxt].death[6].rec.obsTick <= originTick,
         &"ring round {round} agent {nxt}: no phantom freshening")
    for i in 0 .. 2:
      s[i].expire(t)
  ok(not s[0].death[6].has and not s[1].death[6].has and not s[2].death[6].has,
     "the death expired out of the whole ring")

# ---------------------------------------------------------------------------

section "GONE never downgrades a fresher-or-equal PICKUP"

block goneVsPickup:
  let spawn = 0                       # a med kit: 30s respawn
  let r = respawnTicks(spawn)
  ok(r == RespawnSlowTicks, "med kit uses the slow respawn")

  # A GONE observed after the pickup but BEFORE the item is due back says
  # nothing new -- the pickup already implies the spot is empty.
  for order in 0 .. 1:
    var s: IntelStore
    let
      pick = Record(kind: ikPickup, obsTick: 1000, spawn: spawn,
                    taker: 4, takerKnown: true)
      gone = Record(kind: ikGone, obsTick: 1000 + r - 10, spawn: spawn)
    if order == 0:
      s.merge(pick); s.merge(gone)
    else:
      s.merge(gone); s.merge(pick)
    let st = s.spawnState(spawn)
    ok(st.witnessed, &"order {order}: the witnessed pickup still governs")
    ok(st.readyAt == 1000 + r, &"order {order}: respawn stays pinned exactly")

  # A GONE observed AFTER the item was due back is genuinely new: it was taken
  # a second time, unwitnessed.
  for order in 0 .. 1:
    var s: IntelStore
    let
      pick = Record(kind: ikPickup, obsTick: 1000, spawn: spawn,
                    taker: 4, takerKnown: true)
      gone = Record(kind: ikGone, obsTick: 1000 + r + 50, spawn: spawn)
    if order == 0:
      s.merge(pick); s.merge(gone)
    else:
      s.merge(gone); s.merge(pick)
    let st = s.spawnState(spawn)
    ok(not st.witnessed, &"order {order}: the later GONE takes over")
    ok(st.takenAt == 1000 + r + 50, &"order {order}: and dates from itself")

block goneAlone:
  var s: IntelStore
  s.merge(Record(kind: ikGone, obsTick: 300, spawn: 7))
  let st = s.spawnState(7)
  ok(st.known and not st.witnessed, "a lone GONE is knowledge, but weak")
  ok(st.readyAt == 300 + RespawnNadeTicks, "nade corner uses the 5s respawn")

# ---------------------------------------------------------------------------

section "geometry and helpers"

block cells:
  ok(CellCount <= 4096, &"cell index fits 12 bits ({CellCount})")
  for (x, y) in [(0, 0), (MapW - 1, MapH - 1), (617, 329), (1234, 658)]:
    let c = cellOf(x, y)
    ok(c >= 0 and c < CellCount, &"cell in range for ({x},{y})")
    let (bx, by) = cellCentre(c)
    ok(abs(bx - x) <= CellPx and abs(by - y) <= CellPx,
       &"cell centre within a cell of ({x},{y}) -- got ({bx},{by})")

block seats:
  # Slots alternate team by parity, so both teams' seats land in 0..7 and the
  # ordering is identical for every teammate.
  for pid in 0 ..< PlayerCount:
    let s = enemySeat(pid)
    ok(s >= 0 and s < EnemyCount, &"seat in range for pid {pid}")
  ok(enemySeat(0) == 0 and enemySeat(2) == 1 and enemySeat(14) == 7,
     "red seats map 0,2,..,14 -> 0..7")
  ok(enemySeat(1) == 0 and enemySeat(3) == 1 and enemySeat(15) == 7,
     "blue seats map 1,3,..,15 -> 0..7")

block ageRounding:
  ok(ageFor(100, 100) == 0, "no elapsed time is age 0")
  ok(ageFor(101, 100) == 1, "1 tick rounds UP to one quantum")
  ok(ageFor(104, 100) == 1, "exactly one quantum stays one")
  ok(ageFor(105, 100) == 2, "just over rounds up")
  ok(ageFor(100_000, 100) == AgeMax, "saturates at the field width")

block priorities:
  let
    heart = Record(kind: ikSight, heart: true)
    death = Record(kind: ikDeath)
    pick = Record(kind: ikPickup)
    sight = Record(kind: ikSight)
    gone = Record(kind: ikGone)
  ok(priority(heart) < priority(death), "heart carrier outranks a death")
  ok(priority(death) < priority(pick), "death outranks a pickup")
  ok(priority(pick) < priority(sight), "pickup outranks a plain sighting")
  ok(priority(sight) < priority(gone), "a sighting outranks a GONE")

block pendingOrder:
  var s: IntelStore
  s.merge(Record(kind: ikGone, obsTick: 100, spawn: 2))
  s.merge(Record(kind: ikSight, obsTick: 100, enemy: 1, cell: 10))
  s.merge(Record(kind: ikSight, obsTick: 100, enemy: 2, cell: 20, heart: true))
  s.merge(Record(kind: ikDeath, obsTick: 100, enemy: 3, cell: 30, idKnown: true))
  let p = s.pending(120)
  ok(p.len == 4, &"all four are pending, got {p.len}")
  ok(p[0].kind == ikSight and p[0].heart, "heart carrier is sent first")
  ok(p[1].kind == ikDeath, "then the death")
  ok(p[3].kind == ikGone, "the GONE goes last")

block shoutedSuppression:
  var s: IntelStore
  let r = Record(kind: ikSight, obsTick: 100, enemy: 1, cell: 10)
  s.merge(r)
  ok(s.pending(110).len == 1, "fresh intel is pending")
  s.markShouted(r)
  ok(s.pending(110).len == 0, "already shouted, so no longer pending")
  # A genuinely fresher fix for the same enemy is worth the slot again.
  s.merge(Record(kind: ikSight, obsTick: 140, enemy: 1, cell: 11))
  ok(s.pending(150).len == 1, "a fresher fix for the same key is pending again")

block expiry:
  var s: IntelStore
  s.merge(Record(kind: ikSight, obsTick: 100, enemy: 0, cell: 1))
  s.expire(100 + MaxAgeTicks)
  ok(s.sight[0].has, "still held at exactly the age limit")
  s.expire(100 + MaxAgeTicks + 1)
  ok(not s.sight[0].has, "dropped one tick past it")

block lives:
  var s: IntelStore
  ok(s.enemyLivesLeft(2) == 3, "unknown enemies are assumed to have 3 lives")
  s.merge(Record(kind: ikDeath, obsTick: 10, enemy: 2, cell: 0, lives: 1,
                 idKnown: true))
  ok(s.enemyLivesLeft(2) == 1, "the ledger follows the freshest death")
  s.merge(Record(kind: ikDeath, obsTick: 20, enemy: 2, cell: 0, lives: 0,
                 idKnown: false))
  ok(s.enemyLivesLeft(2) == 3,
     "an anonymous corpse does not claim a specific enemy's life")

block heartLookup:
  var s: IntelStore
  ok(s.heartCarrier().isNone, "no carrier known yet")
  s.merge(Record(kind: ikSight, obsTick: 50, enemy: 1, cell: 5))
  ok(s.heartCarrier().isNone, "a plain sighting is not a carrier")
  s.merge(Record(kind: ikSight, obsTick: 60, enemy: 4, cell: 9, heart: true))
  ok(s.heartCarrier().isSome and s.heartCarrier().get.enemy == 4,
     "the flagged sighting is found")

# ---------------------------------------------------------------------------

section "gossip end to end: eight agents, one shout per second, 247px range"

block simulation:
  ## The unit tests above check each rule in isolation. This runs the whole
  ## thing as a system: agents see part of the map, shout on the real 1/s
  ## budget, hear only what is within earshot, and relay. It is the test that
  ## would catch a send policy that never fires, a merge that never converges,
  ## or a record that outlives its origin once the pieces are combined.
  const
    Agents = 8
    Enemies = 8
    Audible = 247.0
    ShoutGap = 26          # ticks; the server allows one shout per second
    Vision = 260.0
    Ticks = 900

  type Agent = object
    x, y: float
    store: IntelStore
    lastShout: int
    seqNo: int
    bubble: string         # what this agent is currently saying
    bubbleAt: int          # the tick it started saying it

  var rng = initRand(4242)
  var agents: array[Agents, Agent]
  for i in 0 ..< Agents:
    agents[i] = Agent(x: 120.0 + float(i) * 130.0, y: 100.0 + float(i mod 3) * 200.0,
                      lastShout: -100)

  # Ground truth the agents are trying to learn: where each enemy really is,
  # and the tick that truth was established.
  var enemyX, enemyY: array[Enemies, float]
  var enemyAt: array[Enemies, int]
  for e in 0 ..< Enemies:
    enemyX[e] = 300.0 + float(e) * 100.0
    enemyY[e] = 300.0
    enemyAt[e] = 0

  # What each agent last heard from each other agent, so a persisting bubble
  # is read once rather than re-dated every frame.
  var heard: array[Agents, array[Agents, string]]
  # The last tick each agent had each other agent's bubble in view, which is
  # what tells it whether a newly-visible payload is newly-SAID.
  var watching: array[Agents, array[Agents, int]]
  for i in 0 ..< Agents:
    for j in 0 ..< Agents:
      watching[i][j] = low(int) div 2

  var everRelayed = false
  # The freshest moment ANY agent genuinely laid eyes on each enemy. Nothing
  # in anybody's store may ever claim to be newer than this -- that is the
  # phantom-intel invariant stated in terms the simulation can check.
  var trueSeenAt: array[Enemies, int]
  for e in 0 ..< Enemies:
    trueSeenAt[e] = low(int) div 2

  for t in 1 .. Ticks:
    # Enemies drift; every move is a new fact with a new observation time.
    for e in 0 ..< Enemies:
      if t mod (40 + e * 7) == 0:
        enemyX[e] = 60.0 + rng.rand(1100).float
        enemyY[e] = 60.0 + rng.rand(520).float
        enemyAt[e] = t

    # Agents drift too, so who can hear whom keeps changing.
    for i in 0 ..< Agents:
      if t mod 31 == 0:
        agents[i].x = clamp(agents[i].x + rng.rand(120).float - 60.0, 20.0, 1200.0)
        agents[i].y = clamp(agents[i].y + rng.rand(120).float - 60.0, 20.0, 640.0)

    # See: first-hand sightings enter the store at the true observation tick.
    for i in 0 ..< Agents:
      for e in 0 ..< Enemies:
        let dx = agents[i].x - enemyX[e]
        let dy = agents[i].y - enemyY[e]
        if dx * dx + dy * dy <= Vision * Vision:
          trueSeenAt[e] = t
          agents[i].store.merge(Record(
            kind: ikSight, obsTick: t, enemy: e,
            cell: cellOf(int(enemyX[e]), int(enemyY[e]))))

    # Hear: any bubble within earshot, read once per distinct payload.
    for i in 0 ..< Agents:
      for j in 0 ..< Agents:
        if i == j or agents[j].bubble.len == 0:
          continue
        if t - agents[j].bubbleAt > 72:      # bubbles live ~3s
          continue
        let dx = agents[i].x - agents[j].x
        let dy = agents[i].y - agents[j].y
        if dx * dx + dy * dy > Audible * Audible:
          continue
        # Were we already watching this sender last tick? If not, this bubble
        # may have gone up as long as BubbleLifeTicks ago and we cannot date
        # it -- so we say so, and the decoder ages it accordingly.
        let continuous = watching[i][j] == t - 1
        watching[i][j] = t
        if heard[i][j] == agents[j].bubble:
          continue
        heard[i][j] = agents[j].bubble
        let msg = decodeMessage(agents[j].bubble, t,
                                if continuous: 0 else: BubbleLifeTicks)
        if msg.isSome:
          for r in msg.get.recs:
            if agents[i].store.merge(r):
              everRelayed = true

    # Speak: the real budget, the real priority order.
    for i in 0 ..< Agents:
      if t - agents[i].lastShout < ShoutGap:
        continue
      let want = agents[i].store.pending(t)
      if want.len == 0:
        continue
      var recs = @[want[0]]
      if want.len > 1: recs.add(want[1])
      agents[i].seqNo = (agents[i].seqNo + 1) and 7
      agents[i].bubble = encodeMessage(
        Message(version: Version, seq: agents[i].seqNo, recs: recs), t)
      agents[i].bubbleAt = t
      agents[i].lastShout = t
      for r in recs:
        agents[i].store.markShouted(r)
      ok(agents[i].bubble.len == MsgLen, &"tick {t}: shout is 10 chars")
      ok(sanitize(agents[i].bubble) == agents[i].bubble,
         &"tick {t}: shout survives the sanitizer")

    for i in 0 ..< Agents:
      agents[i].store.expire(t)

    # The invariant that matters most, checked every single tick: nobody holds
    # a sighting dated later than the freshest moment that enemy was actually
    # seen by anyone. Relaying can only ever age a record, so any violation
    # means freshness leaked from receipt time -- the phantom.
    for i in 0 ..< Agents:
      for e in 0 ..< Enemies:
        if agents[i].store.sight[e].has:
          ok(agents[i].store.sight[e].rec.obsTick <= trueSeenAt[e],
             &"tick {t}: agent {i}'s sighting of {e} is not newer than the " &
             &"real observation ({agents[i].store.sight[e].rec.obsTick} vs " &
             &"{trueSeenAt[e]})")

  ok(everRelayed, "intel actually propagated between agents")

  # Second-hand knowledge must genuinely exceed first-hand vision: count the
  # enemies each agent knows about versus the ones it could see itself.
  var known = 0
  var visible = 0
  for i in 0 ..< Agents:
    for e in 0 ..< Enemies:
      if agents[i].store.sight[e].has:
        inc known
        let dx = agents[i].x - enemyX[e]
        let dy = agents[i].y - enemyY[e]
        if dx * dx + dy * dy <= Vision * Vision:
          inc visible
  ok(known > visible,
     &"the team knows more than it can see ({known} known vs {visible} visible)")

# ---------------------------------------------------------------------------

echo &"\n{checks - failures}/{checks} checks passed"
if failures > 0:
  echo &"{failures} FAILURES"
  quit(1)
echo "all invariants hold"
