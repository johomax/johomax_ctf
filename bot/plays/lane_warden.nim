## Solo BR controller: hold a safe cover lane and manage gun-range spacing.

import ../play

const
  ManifestBytes =
    "{\"abi\":1,\"class\":\"controller\",\"doc\":\"hold safe cover while preserving a longshot lane and disengaging when weak\",\"modes\":[\"br\"],\"name\":\"lane_warden\",\"params\":{\"coverRadius\":{\"default\":260,\"integer\":true,\"kind\":\"number\",\"max\":331,\"min\":0},\"hpFloor\":{\"default\":2,\"integer\":true,\"kind\":\"number\",\"max\":3,\"min\":0},\"margin\":{\"default\":240,\"integer\":true,\"kind\":\"number\",\"max\":600,\"min\":40},\"standoffMax\":{\"default\":1250,\"integer\":true,\"kind\":\"number\",\"max\":1300,\"min\":900},\"standoffMin\":{\"default\":866,\"integer\":true,\"kind\":\"number\",\"max\":900,\"min\":300}},\"retune\":true}"
  TrackRangePx = 1950'i32
  CloseThreatPx = 500'i32
  ShrinkLeadTicks = 120'i32
  ArriveRadiusPx = 24'i32

type
  LaneParams = object
    valid: bool
    margin: int32
    standoffMin: int32
    standoffMax: int32
    coverRadius: int32
    hpFloor: int32

  ParamSlice = object
    start, len: int32

  ParamReader = object
    base: ptr UncheckedArray[byte]
    len, pos: int32
    ok: bool

  DecisionKind = enum
    dkNone
    dkHold
    dkHoldCover
    dkCornered
    dkEnter
    dkMargin
    dkRetreat
    dkFlee
    dkApproach
    dkCover

  RawDecision = object
    kind: DecisionKind
    x, y: int32

var
  params: LaneParams
  selfTeam: SdkTeam
  lastKind: DecisionKind
  lastX, lastY: int32

proc play_manifest*() {.exportc, cdecl.} =
  discard emitRaw(ManifestBytes)

{.push checks: off.}

proc initReader(ctx: PlayContext): ParamReader =
  result.base = cast[ptr UncheckedArray[byte]](ctx.data)
  result.len = ctx.len
  result.ok = ctx.data >= 0 and ctx.len >= 0

proc atEnd(reader: ParamReader): bool {.inline.} =
  reader.pos >= reader.len

proc current(reader: ParamReader): char {.inline.} =
  if reader.atEnd: '\0' else: char(reader.base[reader.pos])

proc take(reader: var ParamReader; expected: char): bool =
  if not reader.ok or reader.atEnd or reader.current != expected:
    reader.ok = false
    return false
  inc reader.pos
  true

proc readString(reader: var ParamReader): ParamSlice =
  if not reader.take('"'):
    return
  result.start = reader.pos
  while reader.ok and not reader.atEnd and reader.current != '"':
    if reader.current == '\\':
      reader.ok = false
      return
    inc reader.pos
  result.len = reader.pos - result.start
  discard reader.take('"')

proc equals(reader: ParamReader; value: ParamSlice;
            expected: static[string]): bool =
  if value.len != expected.len.int32:
    return false
  for index in 0 ..< expected.len:
    if char(reader.base[value.start + index.int32]) != expected[index]:
      return false
  true

proc readInt(reader: var ParamReader; value: var int32): bool =
  var
    parsed = 0'i64
    seen = false
  while reader.ok and not reader.atEnd and reader.current in {'0' .. '9'}:
    seen = true
    parsed = parsed * 10 + int64(ord(reader.current) - ord('0'))
    if parsed > int64(high(int32)):
      reader.ok = false
      return false
    inc reader.pos
  if not seen or (not reader.atEnd and reader.current notin {',', '}'}):
    reader.ok = false
    return false
  value = int32(parsed)
  true

proc readParams(ctx: PlayContext): LaneParams =
  result = LaneParams(valid: true, margin: 240, standoffMin: 866,
    standoffMax: 1250, coverRadius: 260, hpFloor: 2)
  var
    reader = initReader(ctx)
    seenMargin, seenMin, seenMax, seenCover, seenHp: bool
  if not reader.take('{'):
    result.valid = false
    return
  if reader.current == '}':
    inc reader.pos
  else:
    while reader.ok:
      let key = reader.readString()
      if not reader.take(':'):
        break
      if reader.equals(key, "margin") and not seenMargin:
        seenMargin = true
        result.valid = result.valid and reader.readInt(result.margin) and
          result.margin >= 40 and result.margin <= 600
      elif reader.equals(key, "standoffMin") and not seenMin:
        seenMin = true
        result.valid = result.valid and reader.readInt(result.standoffMin) and
          result.standoffMin >= 300 and result.standoffMin <= 900
      elif reader.equals(key, "standoffMax") and not seenMax:
        seenMax = true
        result.valid = result.valid and reader.readInt(result.standoffMax) and
          result.standoffMax >= 900 and result.standoffMax <= 1300
      elif reader.equals(key, "coverRadius") and not seenCover:
        seenCover = true
        result.valid = result.valid and reader.readInt(result.coverRadius) and
          result.coverRadius >= 0 and result.coverRadius <= 331
      elif reader.equals(key, "hpFloor") and not seenHp:
        seenHp = true
        result.valid = result.valid and reader.readInt(result.hpFloor) and
          result.hpFloor >= 0 and result.hpFloor <= 3
      else:
        reader.ok = false
        result.valid = false
      if not reader.ok or reader.current == '}':
        discard reader.take('}')
        break
      if not reader.take(','):
        break
  result.valid = result.valid and reader.ok and reader.pos == reader.len and
    result.standoffMin <= result.standoffMax

{.pop.}

proc minI(a, b: int32): int32 {.inline.} =
  if a < b: a else: b

proc maxI(a, b: int32): int32 {.inline.} =
  if a > b: a else: b

proc clampI(value, lo, hi: int32): int32 {.inline.} =
  if value < lo: lo
  elif value > hi: hi
  else: value

proc sq(value: int32): int64 {.inline.} =
  int64(value) * int64(value)

proc distSq(a, b: SdkPoint): int64 {.inline.} =
  sq(a.x - b.x) + sq(a.y - b.y)

proc rectMinX(rect: SdkRect): int32 {.inline.} = minI(rect.x1, rect.x2)
proc rectMaxX(rect: SdkRect): int32 {.inline.} = maxI(rect.x1, rect.x2)
proc rectMinY(rect: SdkRect): int32 {.inline.} = minI(rect.y1, rect.y2)
proc rectMaxY(rect: SdkRect): int32 {.inline.} = maxI(rect.y1, rect.y2)

proc insetBounds(lo, hi, margin: int32): tuple[lo, hi: int32] =
  let effective = minI(margin, (hi - lo) div 4)
  (lo + effective, hi - effective)

proc clampToInset(rect: SdkRect; point: SdkPoint; margin: int32): SdkPoint =
  result = point
  if not rect.present:
    return
  let
    xs = insetBounds(rect.rectMinX, rect.rectMaxX, margin)
    ys = insetBounds(rect.rectMinY, rect.rectMaxY, margin)
  result.x = clampI(point.x, xs.lo, xs.hi)
  result.y = clampI(point.y, ys.lo, ys.hi)

proc insideInset(rect: SdkRect; point: SdkPoint; margin: int32): bool =
  if not rect.present or not point.present:
    return false
  let
    xs = insetBounds(rect.rectMinX, rect.rectMaxX, margin)
    ys = insetBounds(rect.rectMinY, rect.rectMaxY, margin)
  point.x >= xs.lo and point.x <= xs.hi and
    point.y >= ys.lo and point.y <= ys.hi

proc integerSqrt(value: int64): int32 =
  if value <= 0:
    return 0
  var
    root = value
    next = (root + 1) div 2
  while next < root:
    root = next
    next = (root + value div root) div 2
  int32(root)

proc atDistanceFrom(threat, self: SdkPoint; distance: int32): SdkPoint =
  let
    dx = int64(self.x) - int64(threat.x)
    dy = int64(self.y) - int64(threat.y)
    length = integerSqrt(dx * dx + dy * dy)
  if length <= 0:
    return SdkPoint(present: true, x: self.x + distance, y: self.y)
  SdkPoint(present: true,
    x: threat.x + int32(dx * int64(distance) div int64(length)),
    y: threat.y + int32(dy * int64(distance) div int64(length)))

proc bearing8Brads(fromPoint, toPoint: SdkPoint): int32 =
  let
    dx = toPoint.x - fromPoint.x
    dy = toPoint.y - fromPoint.y
    ax = if dx < 0: -dx else: dx
    ay = if dy < 0: -dy else: dy
  if ax == 0 and ay == 0:
    return -1
  if ay * 2 <= ax:
    return if dx >= 0: 0'i32 else: 128'i32
  if ax * 2 <= ay:
    return if dy >= 0: 64'i32 else: 192'i32
  if dx >= 0 and dy >= 0: 32'i32
  elif dx < 0 and dy >= 0: 96'i32
  elif dx < 0 and dy < 0: 160'i32
  else: 224'i32

proc activeRect(view: JackalView): tuple[rect: SdkRect; entering: bool] =
  if view.zone.next.present and view.zone.ticksToShrinkPresent and
      view.zone.ticksToShrink <= ShrinkLeadTicks:
    return (view.zone.next, true)
  (view.zone.current, false)

proc freshEnemy(view: JackalView): bool =
  view.candidateFound and view.candidate.pos.present and
    view.candidate.freshTickPresent and
    view.candidate.freshTick == view.tick and not view.candidate.downed

proc chooseRaw(view: JackalView): RawDecision =
  if not view.self.pos.present or not view.zone.current.present:
    return RawDecision(kind: dkHold)
  let
    safe = view.activeRect()
    selfInside = safe.rect.insideInset(view.self.pos, params.margin)
    enemyFresh = view.freshEnemy()
  if enemyFresh:
    let
      distanceSq = view.self.pos.distSq(view.candidate.pos)
      weak = view.self.hpPresent and view.self.hp < params.hpFloor
      notWinning = not view.self.hpPresent or not view.candidate.hpPresent or
        view.self.hp <= view.candidate.hp
    var target: SdkPoint
    if weak:
      let currentDistance = integerSqrt(distanceSq)
      target = view.candidate.pos.atDistanceFrom(view.self.pos,
        currentDistance + params.standoffMax)
      target = safe.rect.clampToInset(target, params.margin)
      return RawDecision(kind: dkFlee, x: target.x, y: target.y)
    if distanceSq < sq(CloseThreatPx) and notWinning:
      target = view.candidate.pos.atDistanceFrom(view.self.pos,
        maxI(params.standoffMin, CloseThreatPx))
      target = safe.rect.clampToInset(target, params.margin)
      return RawDecision(kind: dkRetreat, x: target.x, y: target.y)
    if distanceSq < sq(params.standoffMin):
      target = view.candidate.pos.atDistanceFrom(view.self.pos,
        params.standoffMin)
      target = safe.rect.clampToInset(target, params.margin)
      return RawDecision(kind: dkRetreat, x: target.x, y: target.y)
    if distanceSq > sq(params.standoffMax):
      target = view.candidate.pos.atDistanceFrom(view.self.pos,
        params.standoffMax)
      target = safe.rect.clampToInset(target, params.margin)
      return RawDecision(kind: dkApproach, x: target.x, y: target.y)

  if not selfInside:
    let target = safe.rect.clampToInset(view.self.pos, params.margin)
    return RawDecision(kind: if safe.entering: dkEnter else: dkMargin,
      x: target.x, y: target.y)
  RawDecision(kind: dkCover, x: view.self.pos.x, y: view.self.pos.y)

proc coverKeepsDecision(kind: DecisionKind; self, enemy: SdkPoint;
                        enemyFresh: bool; reachable,
                        cover: ValidatedGoal): bool =
  if not enemyFresh:
    return true
  let
    coverPoint = SdkPoint(present: true, x: cover.x, y: cover.y)
    reachablePoint = SdkPoint(present: true, x: reachable.x, y: reachable.y)
    coverDistance = coverPoint.distSq(enemy)
  case kind
  of dkFlee, dkRetreat:
    coverDistance >= self.distSq(enemy) and
      coverDistance >= reachablePoint.distSq(enemy)
  of dkApproach:
    coverDistance <= self.distSq(enemy) and
      coverDistance >= sq(params.standoffMin) and
      coverDistance <= sq(params.standoffMax)
  else:
    coverDistance >= sq(params.standoffMin) and
      coverDistance <= sq(params.standoffMax)

proc sameDecision(kind: DecisionKind; x = 0'i32; y = 0'i32): bool =
  lastKind == kind and
    (kind in {dkHold, dkHoldCover, dkCornered} or
      (lastX == x and lastY == y))

proc remember(kind: DecisionKind; x = 0'i32; y = 0'i32) =
  lastKind = kind
  lastX = x
  lastY = y

proc emitHoldIfChanged(kind: DecisionKind): int32 =
  if sameDecision(kind):
    resetArena()
    return 0
  let code =
    case kind
    of dkHoldCover: emitHoldController("lane_warden:hold_cover")
    of dkCornered: emitHoldController("lane_warden:cornered")
    else: emitHoldController("lane_warden:hold")
  if code < 0:
    return code
  remember(kind)
  resetArena()
  0

proc emitNavigate(goal: ValidatedGoal; kind: DecisionKind): int32 =
  case kind
  of dkEnter: emitNavigateController(goal, "24.0", "lane_warden:enter")
  of dkMargin: emitNavigateController(goal, "24.0", "lane_warden:margin")
  of dkRetreat: emitNavigateController(goal, "24.0", "lane_warden:retreat")
  of dkFlee: emitNavigateController(goal, "24.0", "lane_warden:flee")
  of dkApproach: emitNavigateController(goal, "24.0", "lane_warden:approach")
  of dkCover: emitNavigateController(goal, "24.0", "lane_warden:cover")
  else: emitHoldController("lane_warden:hold")

proc resetDecisionCache() =
  lastKind = dkNone
  lastX = 0
  lastY = 0

proc loadParams(dataPtr, dataLen: int32; clearCache: bool): int32 =
  let decoded = readParams(context(dataPtr, dataLen))
  if not decoded.valid:
    return 1
  params = decoded
  if clearCache:
    resetDecisionCache()
  0

proc loadContext(ctxPtr, ctxLen: int32) =
  var decoded: SdkContext
  selfTeam = stUnknown
  if readBinaryContextInto(context(ctxPtr, ctxLen), decoded) and
      decoded.selfTeamPresent:
    selfTeam = decoded.selfTeam

proc play_init*(paramsPtr, paramsLen, ctxPtr, ctxLen: int32): int32 {.
    exportc, cdecl.} =
  resetArena()
  loadContext(ctxPtr, ctxLen)
  loadParams(paramsPtr, paramsLen, true)

proc play_step*(viewPtr, viewLen: int32): int32 {.exportc, cdecl.} =
  var decoded: JackalView
  if not readJackalBinaryViewInto(view(viewPtr, viewLen), decoded, selfTeam,
      TrackRangePx, -1, false):
    return 1

  let raw = chooseRaw(decoded)
  if raw.kind == dkHold:
    return emitHoldIfChanged(dkHold)

  let reachable = nearestReachable(raw.x, raw.y)
  if not reachable.ok:
    return emitHoldIfChanged(
      if raw.kind == dkFlee: dkCornered else: dkHold)

  let
    reachablePoint = SdkPoint(present: true, x: reachable.x, y: reachable.y)
    moveDistance = reachablePoint.distSq(decoded.self.pos)
  if raw.kind == dkFlee and moveDistance <= sq(ArriveRadiusPx):
    return emitHoldIfChanged(dkCornered)

  var
    goal = reachable
    kind = raw.kind
  let safe = decoded.activeRect()
  if params.coverRadius > 0:
    let bearing = if decoded.freshEnemy():
        bearing8Brads(reachablePoint, decoded.candidate.pos)
      else: -1'i32
    let cover = nearestCover(reachable.x, reachable.y, params.coverRadius,
      bearing)
    let coverPoint = SdkPoint(present: cover.ok, x: cover.x, y: cover.y)
    if cover.ok and safe.rect.insideInset(coverPoint, params.margin) and
        coverKeepsDecision(raw.kind, decoded.self.pos, decoded.candidate.pos,
          decoded.freshEnemy(), reachable, cover):
      goal = cover
      kind = dkCover

  let goalPoint = SdkPoint(present: true, x: goal.x, y: goal.y)
  if goalPoint.distSq(decoded.self.pos) <= sq(ArriveRadiusPx):
    return emitHoldIfChanged(
      if kind == dkCover: dkHoldCover else: dkHold)
  if sameDecision(kind, goal.x, goal.y):
    resetArena()
    return 0
  let code = emitNavigate(goal, kind)
  if code < 0:
    return code
  remember(kind, goal.x, goal.y)
  resetArena()
  0

proc play_retune*(oldPtr, oldLen, newPtr, newLen: int32): int32 {.
    exportc, cdecl.} =
  discard oldPtr
  discard oldLen
  resetArena()
  loadParams(newPtr, newLen, true)
