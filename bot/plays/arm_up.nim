## BR Season 2 opening controller: collect both weapon crates, in order.

import ../play

const
  ManifestBytes =
    "{\"abi\":1,\"class\":\"controller\",\"doc\":\"collect both Season 2 weapon crates before yielding permanently\",\"modes\":[\"br\"],\"name\":\"arm_up\",\"params\":{\"detourMax\":{\"default\":600,\"integer\":true,\"kind\":\"number\",\"max\":2000,\"min\":40},\"order\":{\"default\":\"gun_first\",\"kind\":\"enum\",\"of\":[\"gun_first\",\"hopper_first\"]}},\"retune\":true}"
  PickupInferRadiusPx = 14'i32
  # The ABI has no retire/yield export or intent. A nonzero play_step return
  # faults the instance; the ladder clears its cached intent and immediately
  # advances to the next passing controller. Use that terminal path only once
  # both inferred pickups are complete.
  RetireCode = -1'i32

type
  ArmOrder = enum
    aoGunFirst
    aoHopperFirst

  ArmParams = object
    valid: bool
    detourMax: int32
    order: ArmOrder

  ParamSlice = object
    start, len: int32

  ParamReader = object
    base: ptr UncheckedArray[byte]
    len, pos: int32
    ok: bool

  Candidate = object
    found: bool
    x, y: int32
    distSq: int64

  DecisionKind = enum
    dkNone
    dkRun

var
  params: ArmParams
  hasGun, hasHopper: bool
  targetKnown: bool
  targetKind: SdkItemKind
  target: SdkPoint
  previousKind: SdkItemKind
  previousCount: int32
  previous: array[MaxViewItems, SdkPoint]
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
  var parsed = 0'i64
  var seen = false
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

proc readParams(ctx: PlayContext): ArmParams =
  result = ArmParams(valid: true, detourMax: 600, order: aoGunFirst)
  var
    reader = initReader(ctx)
    seenDetour, seenOrder: bool
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
      if reader.equals(key, "detourMax") and not seenDetour:
        seenDetour = true
        result.valid = result.valid and reader.readInt(result.detourMax) and
          result.detourMax >= 40 and result.detourMax <= 2000
      elif reader.equals(key, "order") and not seenOrder:
        seenOrder = true
        let value = reader.readString()
        if reader.equals(value, "gun_first"):
          result.order = aoGunFirst
        elif reader.equals(value, "hopper_first"):
          result.order = aoHopperFirst
        else:
          reader.ok = false
          result.valid = false
      else:
        reader.ok = false
        result.valid = false
      if not reader.ok or reader.current == '}':
        discard reader.take('}')
        break
      if not reader.take(','):
        break
  result.valid = result.valid and reader.ok and reader.pos == reader.len

{.pop.}

proc sq(value: int32): int64 {.inline.} =
  int64(value) * int64(value)

proc distSq(a, b: SdkPoint): int64 {.inline.} =
  let
    dx = int64(a.x) - int64(b.x)
    dy = int64(a.y) - int64(b.y)
  dx * dx + dy * dy

proc visible(item: SdkItem; kind: SdkItemKind): bool {.inline.} =
  item.kindPresent and item.kind == kind and item.pos.present and
    (not item.presentKnown or item.present)

proc visibleAt(view: SupplyRunView; kind: SdkItemKind;
               point: SdkPoint): bool =
  for index in 0 ..< view.itemCount:
    let item = view.items[index]
    if item.visible(kind) and item.pos.x == point.x and item.pos.y == point.y:
      return true

proc near(a, b: SdkPoint): bool {.inline.} =
  a.distSq(b) <= sq(PickupInferRadiusPx)

proc neededKind(): SdkItemKind =
  case params.order
  of aoGunFirst:
    if not hasGun: sikGun
    elif not hasHopper: sikHopper
    else: sikUnknown
  of aoHopperFirst:
    if not hasHopper: sikHopper
    elif not hasGun: sikGun
    else: sikUnknown

proc markAcquired(kind: SdkItemKind) =
  case kind
  of sikGun: hasGun = true
  of sikHopper: hasHopper = true
  else: discard

proc vanishedNear(view: SupplyRunView; kind: SdkItemKind): bool =
  if targetKnown and targetKind == kind and view.self.pos.near(target) and
      not view.visibleAt(kind, target):
    return true
  if previousKind == kind:
    for index in 0 ..< previousCount:
      let point = previous[index]
      if view.self.pos.near(point) and not view.visibleAt(kind, point):
        return true

proc rememberVisible(view: SupplyRunView; kind: SdkItemKind) =
  previousKind = kind
  previousCount = 0
  for index in 0 ..< view.itemCount:
    let item = view.items[index]
    if item.visible(kind):
      previous[previousCount] = item.pos
      inc previousCount

proc chooseNearest(view: SupplyRunView; kind: SdkItemKind): Candidate =
  let maxSq = sq(params.detourMax)
  for index in 0 ..< view.itemCount:
    let item = view.items[index]
    if not item.visible(kind):
      continue
    let distance = view.self.pos.distSq(item.pos)
    if distance > maxSq:
      continue
    if not result.found or distance < result.distSq or
        (distance == result.distSq and (item.pos.y < result.y or
          (item.pos.y == result.y and item.pos.x < result.x))):
      result = Candidate(found: true, x: item.pos.x, y: item.pos.y,
        distSq: distance)

proc clearTarget() =
  targetKnown = false
  targetKind = sikUnknown
  target = default(SdkPoint)

proc resetDecisionCache() =
  lastKind = dkNone
  lastX = 0
  lastY = 0

proc clearObservation() =
  clearTarget()
  previousKind = sikUnknown
  previousCount = 0
  resetDecisionCache()

proc resetEpisodeState() =
  hasGun = false
  hasHopper = false
  clearObservation()

proc sameDecision(kind: DecisionKind; x, y: int32): bool =
  lastKind == kind and lastX == x and lastY == y

proc remember(kind: DecisionKind; x, y: int32) =
  lastKind = kind
  lastX = x
  lastY = y

proc sameParams(a, b: ArmParams): bool =
  a.detourMax == b.detourMax and a.order == b.order

proc loadParams(dataPtr, dataLen: int32; resetState: bool): int32 =
  let decoded = readParams(context(dataPtr, dataLen))
  if not decoded.valid:
    return 1
  let changed = not params.sameParams(decoded)
  params = decoded
  if resetState:
    resetEpisodeState()
  elif changed:
    # Pickups remain true facts for this episode; only selection state depends
    # on detourMax/order. An unchanged retune preserves every cached fact.
    clearObservation()
  0

proc play_init*(paramsPtr, paramsLen, ctxPtr, ctxLen: int32): int32 {.
    exportc, cdecl.} =
  discard ctxPtr
  discard ctxLen
  resetArena()
  loadParams(paramsPtr, paramsLen, true)

proc play_step*(viewPtr, viewLen: int32): int32 {.exportc, cdecl.} =
  var decoded: SupplyRunView
  if not readSupplyRunBinaryViewInto(view(viewPtr, viewLen), decoded):
    return 1

  var kind = neededKind()
  if kind == sikUnknown:
    return RetireCode
  if decoded.vanishedNear(kind):
    markAcquired(kind)
    clearTarget()
    resetDecisionCache()
    kind = neededKind()
    if kind == sikUnknown:
      return RetireCode

  let raw = decoded.chooseNearest(kind)
  decoded.rememberVisible(kind)
  if not raw.found:
    clearTarget()
    resetDecisionCache()
    resetArena()
    return 0

  targetKnown = true
  targetKind = kind
  target = SdkPoint(present: true, x: raw.x, y: raw.y)
  let goal = nearestReachable(raw.x, raw.y)
  if not goal.ok:
    resetDecisionCache()
    resetArena()
    return 0
  if sameDecision(dkRun, goal.x, goal.y):
    resetArena()
    return 0
  let code =
    if kind == sikGun:
      emitNavigateController(goal, "12.0", "arm_up:gun")
    else:
      emitNavigateController(goal, "12.0", "arm_up:hopper")
  if code < 0:
    return code
  remember(dkRun, goal.x, goal.y)
  resetArena()
  0

proc play_retune*(oldPtr, oldLen, newPtr, newLen: int32): int32 {.
    exportc, cdecl.} =
  discard oldPtr
  discard oldLen
  resetArena()
  loadParams(newPtr, newLen, false)
