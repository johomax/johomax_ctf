## Shout-Intel: timestamped tactical facts over the 10-character shout channel.
##
## Teammates share four kinds of observation -- an enemy sighting, an enemy
## death, a witnessed resource pickup, and a resource seen missing -- each
## stamped with WHEN it was observed. Every one of those is a fact, not a
## decision, so the whole protocol is: broadcast facts, merge freshest-wins,
## optionally relay. No leader, no acknowledgements, no agreement round. A lost
## shout costs freshness, never correctness.
##
## This module is deliberately free of any game or protocol import: it is pure
## arithmetic over ints and strings, which is what makes the invariants at the
## bottom of the file testable without a server.
##
## Two engine facts drive the whole encoding and are worth stating up front,
## because violating either silently corrupts every message:
##
## 1. The server strips leading and trailing SPACES from a shout. So space is
##    excluded from the alphabet outright -- base-94 over '!'..'~'. A payload
##    can then never begin or end with a stripped character, and the text that
##    arrives is byte-identical to the text that was sent.
## 2. The bubble's on-screen position is jittered +-20px. The payload carries
##    the position; the bubble's own coordinates are never read except to
##    recognise our own bubble.

import std/[options, algorithm]

const
  MagicChar* = '~'
    ## Marks a payload as intel rather than human chatter. Any taunt or canned
    ## phrase MUST NOT start with this character or it will be parsed as intel.
  AlphaLo* = '!'            # 33
  AlphaHi* = '~'            # 126
  Base* = 94
  PayloadDigits* = 9
  MsgLen* = 10              # magic + 9 digits; the hard server cap

  Version* = 1              # 2 bits: bump if the record layout ever changes
  MaxVersion* = 3

  # Time. The game runs 24 ticks/second; age is quantised to 4-tick (~167ms)
  # units in 6 bits, covering 252 ticks (~10.5s). Older intel is stale anyway,
  # so saturation is the natural expiry rather than a special case.
  AgeUnit* = 4
  AgeMax* = 63
  MaxAgeTicks* = AgeUnit * AgeMax        # 252

  BubbleLifeTicks* = 72
    ## How long a shout bubble stays on screen (~3s). This is the size of the
    ## dating error available to a listener who was NOT already watching the
    ## sender: the bubble they are seeing for the first time may have gone up
    ## at any point in the last 3 seconds. See `decodeMessage`.

  # Map geometry. Must match the values baseline.nim compiles against.
  MapW* = 1235
  MapH* = 659
  CellPx* = 16
  CellsX* = (MapW + CellPx - 1) div CellPx   # 78
  CellsY* = (MapH + CellPx - 1) div CellPx   # 42
  CellCount* = CellsX * CellsY               # 3276, fits 12 bits

  EnemyCount* = 8           # 8 stable per-team identity names
  PlayerCount* = 16         # 8 per team; the badge id names all of them
  SpawnCount* = 10          # 2 med kits, 2 arcs, 2 shields, 4 nade corners

  # Respawn timers, in ticks. Witnessed pickups pin these exactly.
  RespawnSlowTicks* = 30 * 24   # med kits, shields, plasma arcs
  RespawnNadeTicks* = 5 * 24    # the four grenade corners

type
  IntelKind* = enum
    ikSight = 0             ## enemy E was at cell C, carrying X
    ikDeath = 1             ## enemy E died at cell C
    ikPickup = 2            ## spawn S was taken by T (witnessed transition)
    ikGone = 3              ## spawn S observed empty (weaker than a pickup)

  Record* = object
    ## One fact. `obsTick` is the absolute LOCAL tick at which the ORIGINAL
    ## observer saw it, reconstructed on receipt. It is the only field that
    ## decides freshness, and it is never refreshed by relaying -- that is what
    ## stops a relay echo from circulating as a phantom sighting forever.
    kind*: IntelKind
    obsTick*: int
    enemy*: int             ## SIGHT/DEATH: per-team enemy seat, 0..7
    cell*: int              ## SIGHT/DEATH: 16px grid cell, 0..CellCount-1
    heart*, shield*, arc*: bool  ## SIGHT loadout flags
    lives*: int             ## DEATH: lives left after this death, 0..3
    idKnown*: bool          ## DEATH: false when the corpse was anonymous
    spawn*: int             ## PICKUP/GONE: canonical spawn index, 0..9
    taker*: int             ## PICKUP: global player index, 0..15
    takerKnown*: bool       ## PICKUP: false when nobody was seen taking it

  Message* = object
    version*: int
    seq*: int               ## 0..7, distinguishes a new shout from the same
                            ## bubble persisting across frames
    recs*: seq[Record]      ## 1 or 2 records

  Slot* = object
    has*: bool
    rec*: Record

  IntelStore* = object
    ## One slot per key per kind. SIGHT and DEATH are separate slots for the
    ## same enemy, and PICKUP and GONE are separate slots for the same spawn,
    ## rather than one slot that they fight over. See `spawnState` for why:
    ## a single contested slot cannot be made order-insensitive, and
    ## order-insensitivity is the property the whole gossip design rests on.
    sight*: array[EnemyCount, Slot]
    death*: array[EnemyCount, Slot]
    pickup*: array[SpawnCount, Slot]
    gone*: array[SpawnCount, Slot]
    relayedAt*: array[4, array[SpawnCount * 2, int]]
      ## Per kind, per key: the obsTick of the freshest record we have already
      ## shouted for that key. Sized to the widest key space.

# ---------------------------------------------------------------------------
# Geometry helpers: canonical, derivable by every teammate without talking
# ---------------------------------------------------------------------------

proc cellOf*(x, y: int): int =
  ## Position -> 16px grid cell. +-8px is finer than the +-20px jitter the game
  ## itself applies to the bubble, so nothing tactical is lost here.
  let
    cx = clamp(x div CellPx, 0, CellsX - 1)
    cy = clamp(y div CellPx, 0, CellsY - 1)
  cy * CellsX + cx

proc cellCentre*(cell: int): (int, int) =
  ## Cell -> the centre pixel of that cell.
  let c = clamp(cell, 0, CellCount - 1)
  ((c mod CellsX) * CellPx + CellPx div 2, (c div CellsX) * CellPx + CellPx div 2)

proc enemySeat*(pid: int): int =
  ## Global player index -> per-team seat. Slots alternate team by parity
  ## (baseline.nim derives its own team the same way), so `pid div 2` is a
  ## canonical 0..7 ordering of one team that every teammate computes
  ## identically from the badge object id alone. No agreement round needed.
  clamp(pid div 2, 0, EnemyCount - 1)

proc respawnTicks*(spawn: int): int =
  ## Grenade corners restock in 5s; everything else takes 30s.
  if spawn >= 6: RespawnNadeTicks else: RespawnSlowTicks

# ---------------------------------------------------------------------------
# Field packing
# ---------------------------------------------------------------------------

proc ageFor*(nowTick, obsTick: int): int =
  ## Age in 4-tick units, rounded UP.
  ##
  ## Rounding direction is not cosmetic. Rounding down would make the decoded
  ## observation time up to 3 ticks LATER than the truth, and a record that
  ## gains 3 ticks of apparent freshness per relay hop is exactly the phantom
  ## the design forbids. Rounding up can only ever age a record, which is
  ## safe: a too-old record is discarded, a too-fresh one is believed.
  let d = nowTick - obsTick
  if d <= 0: return 0
  clamp((d + AgeUnit - 1) div AgeUnit, 0, AgeMax)

proc sendable*(nowTick, obsTick: int): bool =
  ## Whether this record can still be put on the wire TRUTHFULLY.
  ##
  ## A saturated age is a lie: it says "63 quanta old" for a fact that may be
  ## far older, and the receiver would reconstruct `now - 253` -- a time that
  ## marches forward with the relayer's clock instead of standing still at the
  ## original observation. That is the phantom this design exists to prevent,
  ## so the saturated value is never emitted and never believed (see
  ## `decodeMessage`). A record this old is about to expire anyway.
  ageFor(nowTick, obsTick) < AgeMax

proc packPayload*(r: Record): uint32 =
  ## The 24-bit body of a record. Layouts are fixed per kind; every unused bit
  ## is written as zero so that two records with equal content always pack to
  ## an equal integer (the merge tie-break depends on that).
  case r.kind
  of ikSight:
    # enemy(3) | cell(12) | age(6) | flags(3)
    # `age` is filled in by encodeMessage, which alone knows the send tick.
    (uint32(r.enemy and 7) shl 21) or
      (uint32(r.cell and 0xFFF) shl 9) or
      (uint32(if r.heart: 1 else: 0) shl 2) or
      (uint32(if r.shield: 1 else: 0) shl 1) or
      uint32(if r.arc: 1 else: 0)
  of ikDeath:
    # enemy(3) | cell(12) | age(6) | lives(2) | idKnown(1)
    (uint32(r.enemy and 7) shl 21) or
      (uint32(r.cell and 0xFFF) shl 9) or
      (uint32(r.lives and 3) shl 1) or
      uint32(if r.idKnown: 1 else: 0)
  of ikPickup:
    # spawn(4) | taker(4) | age(6) | takerKnown(1) | spare(9)
    #
    # `taker` is the GLOBAL player index straight off the identity badge, so
    # all 16 players encode losslessly; one spare bit carries "nobody was
    # actually seen taking it", which a 4-bit field alone cannot express.
    (uint32(r.spawn and 15) shl 20) or
      (uint32(r.taker and 15) shl 16) or
      (uint32(if r.takerKnown: 1 else: 0) shl 9)
  of ikGone:
    # spawn(4) | age(6) | spare(14)
    uint32(r.spawn and 15) shl 20

proc withAge(payload: uint32, kind: IntelKind, age: int): uint32 =
  ## Drop the age bits into the slot this record kind reserves for them.
  let a = uint32(age and AgeMax)
  case kind
  of ikSight, ikDeath: payload or (a shl 3)
  of ikPickup, ikGone: payload or (a shl 10)

proc ageOf(payload: uint32, kind: IntelKind): int =
  case kind
  of ikSight, ikDeath: int((payload shr 3) and uint32(AgeMax))
  of ikPickup, ikGone: int((payload shr 10) and uint32(AgeMax))

proc unpackPayload(kind: IntelKind, payload: uint32, obsTick: int): Record =
  result = Record(kind: kind, obsTick: obsTick)
  case kind
  of ikSight:
    result.enemy = int((payload shr 21) and 7)
    result.cell = int((payload shr 9) and 0xFFF)
    result.heart = ((payload shr 2) and 1) == 1
    result.shield = ((payload shr 1) and 1) == 1
    result.arc = (payload and 1) == 1
  of ikDeath:
    result.enemy = int((payload shr 21) and 7)
    result.cell = int((payload shr 9) and 0xFFF)
    result.lives = int((payload shr 1) and 3)
    result.idKnown = (payload and 1) == 1
  of ikPickup:
    result.spawn = int((payload shr 20) and 15)
    result.taker = int((payload shr 16) and 15)
    result.takerKnown = ((payload shr 9) and 1) == 1
  of ikGone:
    result.spawn = int((payload shr 20) and 15)

# ---------------------------------------------------------------------------
# Wire codec
# ---------------------------------------------------------------------------

proc encodeMessage*(msg: Message, nowTick: int): string =
  ## Render a message as exactly 10 printable characters.
  ##
  ## Ages are computed here, at send time, from each record's absolute
  ## observation tick -- which is what makes relaying exact: a relayer emits a
  ## larger age for the same obsTick, and the receiver reconstructs the same
  ## original observation time no matter how many hops it took.
  var value: uint64 = 0
  let
    count = if msg.recs.len >= 2: 1 else: 0
    header = (uint64(msg.version and 3) shl 4) or
             (uint64(msg.seq and 7) shl 1) or uint64(count)
  value = header shl 52
  for i in 0 ..< 2:
    var rec: uint64 = 0
    if i < msg.recs.len:
      let r = msg.recs[i]
      let p = withAge(packPayload(r), r.kind, ageFor(nowTick, r.obsTick))
      rec = (uint64(ord(r.kind)) shl 24) or uint64(p)
    value = value or (rec shl (26 - 26 * i))
  result = newString(MsgLen)
  result[0] = MagicChar
  var v = value
  for i in countdown(PayloadDigits, 1):
    result[i] = chr(ord(AlphaLo) + int(v mod uint64(Base)))
    v = v div uint64(Base)

proc decodeMessage*(text: string, firstSeenTick: int,
                    uncertaintyTicks = 0): Option[Message] =
  ## Parse a heard shout. Returns none for anything that is not ours: human
  ## chatter, a truncated payload, an out-of-range character, or a version we
  ## do not speak.
  ##
  ## `firstSeenTick` must be the tick the bubble was FIRST seen, not the
  ## current tick -- bubbles persist ~3s, and reading a persisting bubble as if
  ## it had just arrived would make every record look 3s fresher than it is.
  ##
  ## `uncertaintyTicks` covers the harder version of that same mistake. "First
  ## seen" is only the moment the bubble APPEARED if we were already watching
  ## the sender. An agent that drifts into earshot part-way through a bubble's
  ## life sees it for the first time long after it went up, and would date
  ## every fact inside it up to BubbleLifeTicks too fresh. That inflated copy
  ## then beats the honest one in the merge and gets relayed on, re-inflating
  ## at every listener who was also out of range -- an unbounded phantom, which
  ## is the one failure this design must not have.
  ##
  ## So the caller passes what it does not know: 0 when the sender was under
  ## continuous observation, BubbleLifeTicks when it was not. Erring old is
  ## always safe -- an over-aged record simply loses a merge or expires early.
  ## Erring young is the bug.
  if text.len != MsgLen or text[0] != MagicChar:
    return none(Message)
  var value: uint64 = 0
  for i in 1 ..< MsgLen:
    let c = text[i]
    if c < AlphaLo or c > AlphaHi:
      return none(Message)
    value = value * uint64(Base) + uint64(ord(c) - ord(AlphaLo))
  if value >= (1'u64 shl 58):
    return none(Message)          # 94^9 overshoots 2^58; reject the excess
  let header = int((value shr 52) and 0x3F)
  var msg = Message(
    version: (header shr 4) and 3,
    seq: (header shr 1) and 7,
    recs: @[])
  if msg.version != Version:
    return none(Message)
  let count = (header and 1) + 1
  for i in 0 ..< count:
    let raw = (value shr (26 - 26 * i)) and 0x3FFFFFF'u64
    let
      kind = IntelKind((raw shr 24) and 3)
      payload = uint32(raw and 0xFFFFFF'u64)
      age = ageOf(payload, kind)
    if age >= AgeMax:
      # Saturated: the true age is "at least 252 ticks", so the observation
      # time we would reconstruct is an upper bound, not a fact. Believing it
      # would peg the record to `now - 253` and re-freshen it on every hop --
      # a fact that never dies and drifts forward forever. Drop it instead; at
      # this age it is past the expiry horizon regardless.
      continue
    # Absolute observation time on OUR clock. The -1 is the one tick the shout
    # spends in flight between the sender's send and our first sight of it.
    msg.recs.add(unpackPayload(kind, payload,
                               firstSeenTick - 1 - AgeUnit * age -
                                 uncertaintyTicks))
  if msg.recs.len == 0:
    return none(Message)      # every record was too old to be believed
  some(msg)

# ---------------------------------------------------------------------------
# Merge
# ---------------------------------------------------------------------------

proc fresher*(a, b: Record): bool =
  ## Strict, deterministic total order on records sharing a key.
  ##
  ## Ties on obsTick are broken by the packed payload rather than by arrival,
  ## so that a set of records has ONE winner regardless of the order it is
  ## merged in. Without the tie-break, two distinct records observed on the
  ## same tick would converge to whichever happened to arrive last, and the
  ## store would stop being order-insensitive.
  if a.obsTick != b.obsTick: a.obsTick > b.obsTick
  else: packPayload(a) > packPayload(b)

proc keyOf*(r: Record): int =
  case r.kind
  of ikSight, ikDeath: clamp(r.enemy, 0, EnemyCount - 1)
  of ikPickup, ikGone: clamp(r.spawn, 0, SpawnCount - 1)

proc slotFor(store: var IntelStore, r: Record): ptr Slot =
  let k = keyOf(r)
  case r.kind
  of ikSight: addr store.sight[k]
  of ikDeath: addr store.death[k]
  of ikPickup: addr store.pickup[k]
  of ikGone: addr store.gone[k]

proc merge*(store: var IntelStore, r: Record): bool {.discardable.} =
  ## Fold one record in. Returns true if the store changed.
  ##
  ## This is a max over a total order, so it is commutative, associative and
  ## idempotent: the same set of records in any order, with any duplication,
  ## converges to the same store. Receiving a record twice is a no-op;
  ## receiving them backwards is a no-op for the older one.
  let s = slotFor(store, r)
  if not s.has or fresher(r, s.rec):
    s.has = true
    s.rec = r
    return true
  false

proc expire*(store: var IntelStore, nowTick: int) =
  ## Forget anything past the age field's reach. A record we could no longer
  ## encode truthfully is a record we should not be acting on either.
  template sweep(arr: untyped) =
    for i in 0 ..< arr.len:
      if arr[i].has and nowTick - arr[i].rec.obsTick > MaxAgeTicks:
        arr[i].has = false
  sweep(store.sight)
  sweep(store.death)
  sweep(store.pickup)
  sweep(store.gone)

# ---------------------------------------------------------------------------
# Reading the store
# ---------------------------------------------------------------------------

type SpawnState* = object
  known*: bool
  witnessed*: bool    ## true when a PICKUP pins the timer exactly
  takenAt*: int       ## observation tick the item was (or was seen) gone
  readyAt*: int       ## tick it is expected back; exact iff `witnessed`

proc spawnState*(store: IntelStore, spawn: int): SpawnState =
  ## Reconcile the PICKUP and GONE slots for one spawn.
  ##
  ## A GONE only ever ADDS to what a PICKUP already says, and only when it
  ## post-dates the respawn that PICKUP implies -- otherwise it is just a
  ## weaker restatement of the same disappearance and is ignored. Because the
  ## two live in separate slots, a GONE can never overwrite a PICKUP; the rule
  ## is applied here, at read time, where it cannot depend on arrival order.
  let k = clamp(spawn, 0, SpawnCount - 1)
  let
    p = store.pickup[k]
    g = store.gone[k]
    r = respawnTicks(k)
  if p.has:
    result = SpawnState(known: true, witnessed: true,
                        takenAt: p.rec.obsTick, readyAt: p.rec.obsTick + r)
    if g.has and g.rec.obsTick > p.rec.obsTick + r:
      # Seen empty AFTER the pickup's item should have been back: it was taken
      # again, and this time we did not see by whom.
      result = SpawnState(known: true, witnessed: false,
                          takenAt: g.rec.obsTick, readyAt: g.rec.obsTick + r)
  elif g.has:
    # Only an upper bound: it was taken at some unknown point BEFORE this.
    result = SpawnState(known: true, witnessed: false,
                        takenAt: g.rec.obsTick, readyAt: g.rec.obsTick + r)

proc heartCarrier*(store: IntelStore): Option[Record] =
  ## The freshest sighting flagged as holding our heart. The highest-value
  ## message in the game, and the one worth re-broadcasting on a cadence.
  var best: Record
  var found = false
  for i in 0 ..< EnemyCount:
    if store.sight[i].has and store.sight[i].rec.heart:
      if not found or fresher(store.sight[i].rec, best):
        best = store.sight[i].rec
        found = true
  if found: some(best) else: none(Record)

proc enemyLivesLeft*(store: IntelStore, enemy: int): int =
  ## Shared lives ledger, from the freshest identified DEATH for that enemy.
  ## 3 lives each; tracking it measures progress toward the wipe win.
  let k = clamp(enemy, 0, EnemyCount - 1)
  if store.death[k].has and store.death[k].rec.idKnown:
    store.death[k].rec.lives
  else:
    3

# ---------------------------------------------------------------------------
# Send policy
# ---------------------------------------------------------------------------

proc priority*(r: Record): int =
  ## heart-carrier SIGHT > DEATH > PICKUP > SIGHT > GONE. Lower sorts first.
  case r.kind
  of ikSight: (if r.heart: 0 else: 3)
  of ikDeath: 1
  of ikPickup: 2
  of ikGone: 4

proc relayIndex(kind: IntelKind, key: int): int = key

proc markShouted*(store: var IntelStore, r: Record) =
  ## Remember that this key has been broadcast at this freshness, so we do not
  ## spend the 1/s slot repeating intel the team already has.
  let i = relayIndex(r.kind, keyOf(r))
  if r.obsTick > store.relayedAt[ord(r.kind)][i]:
    store.relayedAt[ord(r.kind)][i] = r.obsTick

proc worthShouting*(store: IntelStore, r: Record): bool =
  ## Only if it beats what we last put on the wire for that key. Staleness is
  ## the TTL, so no hop counter is needed: a record stops propagating when
  ## everyone holding it has already said it.
  r.obsTick > store.relayedAt[ord(r.kind)][relayIndex(r.kind, keyOf(r))]

proc pending*(store: IntelStore, nowTick: int): seq[Record] =
  ## Everything we hold that is fresher than what we last shouted for its key,
  ## in send priority order. The caller takes the first one or two.
  template gather(arr: untyped) =
    for i in 0 ..< arr.len:
      if arr[i].has and sendable(nowTick, arr[i].rec.obsTick) and
          store.worthShouting(arr[i].rec):
        result.add(arr[i].rec)
  gather(store.sight)
  gather(store.death)
  gather(store.pickup)
  gather(store.gone)
  result.sort(proc (a, b: Record): int =
    let (pa, pb) = (priority(a), priority(b))
    if pa != pb: cmp(pa, pb)
    else: cmp(b.obsTick, a.obsTick))    # freshest first within a priority
