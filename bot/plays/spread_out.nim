## BR opening controller: walk away from the first position this instance sees.

import ../play

const
  ManifestBytes =
    "{\"abi\":1,\"class\":\"controller\",\"doc\":\"walk a fixed distance from the first-step position\",\"modes\":[\"br\"],\"name\":\"spread_out\",\"params\":{\"bearing_brads\":{\"default\":0,\"integer\":true,\"kind\":\"number\",\"max\":255,\"min\":0},\"distance\":{\"default\":180,\"integer\":true,\"kind\":\"number\",\"max\":600,\"min\":40},\"mirror\":{\"default\":false,\"kind\":\"bool\"}},\"retune\":true}"
  AimBradsTurn = 256'i32
  ArriveRadiusPx = 24'i32
  UnitScale = 65_536'i64
  CosQuarter: array[65, int32] = [
    65536, 65516, 65457, 65358, 65220, 65043, 64827, 64571, 64277,
    63944, 63572, 63162, 62714, 62228, 61705, 61145, 60547, 59914,
    59244, 58538, 57798, 57022, 56212, 55368, 54491, 53581, 52639,
    51665, 50660, 49624, 48559, 47464, 46341, 45190, 44011, 42806,
    41576, 40320, 39040, 37736, 36410, 35062, 33692, 32303, 30893,
    29466, 28020, 26558, 25080, 23586, 22078, 20557, 19024, 17479,
    15924, 14359, 12785, 11204, 9616, 8022, 6424, 4821, 3216, 1608, 0]

type
  SpreadParams = object
    valid: bool
    distance: int32
    bearing: int32
    mirror: bool

  ParamSlice = object
    start, len: int32

  ParamReader = object
    base: ptr UncheckedArray[byte]
    len, pos: int32
    ok: bool

  DecisionKind = enum
    dkNone
    dkHold
    dkWalk

var
  params: SpreadParams
  spawnKnown: bool
  spawn: SdkPoint
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

proc readKey(reader: var ParamReader): ParamSlice =
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

proc startsWith(reader: ParamReader; expected: static[string]): bool =
  if reader.pos + expected.len.int32 > reader.len:
    return false
  for index in 0 ..< expected.len:
    if char(reader.base[reader.pos + index.int32]) != expected[index]:
      return false
  true

proc readBool(reader: var ParamReader; value: var bool): bool =
  if reader.startsWith("true"):
    reader.pos += 4
    value = true
  elif reader.startsWith("false"):
    reader.pos += 5
    value = false
  else:
    reader.ok = false
    return false
  if not reader.atEnd and reader.current notin {',', '}'}:
    reader.ok = false
    return false
  true

proc readParams(ctx: PlayContext): SpreadParams =
  result = SpreadParams(valid: true, distance: 180, bearing: 0, mirror: false)
  var
    reader = initReader(ctx)
    seenBearing, seenDistance, seenMirror: bool
  if not reader.take('{'):
    result.valid = false
    return
  if reader.current == '}':
    inc reader.pos
  else:
    while reader.ok:
      let key = reader.readKey()
      if not reader.take(':'):
        break
      if reader.equals(key, "bearing_brads") and not seenBearing:
        seenBearing = true
        result.valid = result.valid and reader.readInt(result.bearing) and
          result.bearing >= 0 and result.bearing < AimBradsTurn
      elif reader.equals(key, "distance") and not seenDistance:
        seenDistance = true
        result.valid = result.valid and reader.readInt(result.distance) and
          result.distance >= 40 and result.distance <= 600
      elif reader.equals(key, "mirror") and not seenMirror:
        seenMirror = true
        result.valid = result.valid and reader.readBool(result.mirror)
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

proc roundedUnitProduct(distance, unit: int32): int32 =
  let value = int64(distance) * int64(unit)
  if value >= 0:
    int32((value + UnitScale div 2) div UnitScale)
  else:
    -int32((-value + UnitScale div 2) div UnitScale)

proc unitVector(bearing: int32): tuple[x, y: int32] =
  let
    quadrant = bearing div 64
    offset = int(bearing mod 64)
  var cosine, sine: int32
  case quadrant
  of 0:
    cosine = CosQuarter[offset]
    sine = CosQuarter[64 - offset]
  of 1:
    cosine = -CosQuarter[64 - offset]
    sine = CosQuarter[offset]
  of 2:
    cosine = -CosQuarter[offset]
    sine = -CosQuarter[64 - offset]
  else:
    cosine = CosQuarter[64 - offset]
    sine = -CosQuarter[offset]
  (cosine, -sine)

proc chooseRaw(view: EdgeRideView): SdkPoint =
  if not spawnKnown:
    spawn = view.selfPos
    spawnKnown = true
  let
    bearing = (params.bearing + (if params.mirror: 128 else: 0)) mod
      AimBradsTurn
    unit = unitVector(bearing)
  SdkPoint(present: true,
    x: spawn.x + roundedUnitProduct(params.distance, unit.x),
    y: spawn.y + roundedUnitProduct(params.distance, unit.y))

proc sameDecision(kind: DecisionKind; x = 0'i32; y = 0'i32): bool =
  lastKind == kind and (kind == dkHold or (lastX == x and lastY == y))

proc remember(kind: DecisionKind; x = 0'i32; y = 0'i32) =
  lastKind = kind
  lastX = x
  lastY = y

proc emitHoldIfChanged(): int32 =
  if sameDecision(dkHold):
    resetArena()
    return 0
  let code = emitHoldController("spread_out:hold")
  if code < 0:
    return code
  remember(dkHold)
  resetArena()
  0

proc loadParams(dataPtr, dataLen: int32; resetState: bool): int32 =
  let decoded = readParams(context(dataPtr, dataLen))
  if not decoded.valid:
    return 1
  params = decoded
  lastKind = dkNone
  if resetState:
    spawnKnown = false
    spawn = default(SdkPoint)
  0

proc play_init*(paramsPtr, paramsLen, ctxPtr, ctxLen: int32): int32 {.
    exportc, cdecl.} =
  discard ctxPtr
  discard ctxLen
  resetArena()
  loadParams(paramsPtr, paramsLen, true)

proc play_step*(viewPtr, viewLen: int32): int32 {.exportc, cdecl.} =
  var decoded: EdgeRideView
  if not readEdgeRideBinaryViewInto(view(viewPtr, viewLen), decoded):
    return 1

  let raw = chooseRaw(decoded)
  let goal = nearestReachable(raw.x, raw.y)
  if not goal.ok:
    return emitHoldIfChanged()
  let
    dx = int64(decoded.selfPos.x) - int64(goal.x)
    dy = int64(decoded.selfPos.y) - int64(goal.y)
  if dx * dx + dy * dy <= int64(ArriveRadiusPx * ArriveRadiusPx):
    return emitHoldIfChanged()
  if sameDecision(dkWalk, goal.x, goal.y):
    resetArena()
    return 0
  let code = emitNavigateController(goal, "24.0", "spread_out:walk")
  if code < 0:
    return code
  remember(dkWalk, goal.x, goal.y)
  resetArena()
  0

proc play_retune*(oldPtr, oldLen, newPtr, newLen: int32): int32 {.
    exportc, cdecl.} =
  discard oldPtr
  discard oldLen
  resetArena()
  loadParams(newPtr, newLen, false)
