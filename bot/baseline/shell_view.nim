## Transport-neutral Season 2 view facts used by the socket strategist.

import std/[json, math, strutils]

const
  BinaryMagic = "PV1\0"
  BinaryVersion = 1'u16
  BinaryHeaderBytes = 32
  BinarySectionBytes = 12
  MaxBinaryViewBytes = 8_192
  MaxTracks = 32
  MaxKillFeed = 32

  BvSelf = 1'u16
  BvWorld = 2'u16
  BvZone = 3'u16
  BvTracks = 4'u16
  BvKillFeed = 6'u16

  SelfStride = 32
  WorldStride = 272
  ZoneStride = 48
  TrackStride = 32
  KillFeedStride = 12

  SelfAliveFlag = 1'u32
  SelfDownedFlag = 8'u32
  SelfKnownFlags = 7'u32 or SelfDownedFlag
  ZoneNextPresentFlag = 1'u32
  ZoneDpsPresentFlag = 2'u32
  ZoneKnownFlags = ZoneNextPresentFlag or ZoneDpsPresentFlag
  TrackAimPresentFlag = 1'u32
  TrackHpPresentFlag = 2'u32
  TrackBountyFlag = 4'u32
  TrackDownedFlag = 8'u32
  TrackHasGunFlag = 16'u32
  TrackHasHopperFlag = 32'u32
  TrackKnownFlags = TrackAimPresentFlag or TrackHpPresentFlag or
    TrackBountyFlag or TrackDownedFlag or TrackHasGunFlag or TrackHasHopperFlag

  TeamNames = [
    "red", "blue", "green", "yellow", "black", "silver", "ivory",
    "pink", "umber", "rust", "orange", "plum", "lime", "navy",
    "azure", "peach"]

type
  StrategyPoint* = object
    x*, y*: int

  StrategyRect* = object
    x*, y*, w*, h*: int

  StrategySelf* = object
    pos*: StrategyPoint
    hp*: int
    hpFrac*: float
    alive*: bool

  StrategyPartner* = object
    seat*: int
    pos*: StrategyPoint
    positionKnown*: bool
    fresh*: bool
    alive*: bool
    aliveKnown*: bool
    distance*: float

  StrategyEnemy* = object
    seat*: int
    team*: int
    pos*: StrategyPoint
    freshTick*: uint32
    distance*: float
    hp*: int
    hpKnown*: bool
    weakened*: bool

  StrategyKill* = object
    tick*: uint32
    killerTeam*: int
    victimSeat*: int

  StrategyZone* = object
    present*: bool
    phase*: int
    ticksToShrink*: int
    dps*: int
    current*: StrategyRect
    nextPresent*: bool
    next*: StrategyRect

  StrategyView* = object
    tick*: uint32
    epoch*: uint64
    self*: StrategySelf
    partner*: StrategyPartner
    visibleEnemies*: seq[StrategyEnemy]
    killFeed*: seq[StrategyKill]
    zone*: StrategyZone
    aliveTeams*: int

  ViewEncoding* = enum
    veJson
    veBinary

  ViewDecodeErrorKind* = enum
    vdeNone
    vdeUnknownEncoding
    vdeJsonSyntax
    vdeJsonShape
    vdeBinaryHeader
    vdeBinarySection
    vdeInternal

  ViewDecodeResult* = object
    ok*: bool
    ignored*: bool
    encoding*: ViewEncoding
    errorKind*: ViewDecodeErrorKind
    detail*: string
    view*: StrategyView

  RawTrack = object
    seat: int
    team: int
    pos: StrategyPoint
    freshTick: uint32
    hp: int
    hpKnown: bool

  RawView = object
    tick: uint32
    epoch: uint64
    self: StrategySelf
    tracks: seq[RawTrack]
    killFeed: seq[StrategyKill]
    zone: StrategyZone
    aliveTeams: int

  BinarySection = object
    kind: uint16
    count: int
    stride: int
    offset: int

proc teamId*(name: string): int =
  for id, candidate in TeamNames:
    if name == candidate:
      return id
  -1

proc viewDecodeErrorName*(kind: ViewDecodeErrorKind): string =
  case kind
  of vdeNone: "none"
  of vdeUnknownEncoding: "unknown_encoding"
  of vdeJsonSyntax: "json_syntax"
  of vdeJsonShape: "json_shape"
  of vdeBinaryHeader: "binary_header"
  of vdeBinarySection: "binary_section"
  of vdeInternal: "internal"

proc failure(encoding: ViewEncoding; kind: ViewDecodeErrorKind;
             detail: string): ViewDecodeResult =
  ViewDecodeResult(encoding: encoding, errorKind: kind, detail: detail)

proc hasBytes(bytes: string; offset, length: int): bool {.inline.} =
  offset >= 0 and length >= 0 and offset <= bytes.len - length

proc u8At(bytes: string; offset: int): uint8 {.inline.} =
  bytes[offset].uint8

proc u16At(bytes: string; offset: int): uint16 =
  uint16(bytes.u8At(offset)) or (uint16(bytes.u8At(offset + 1)) shl 8)

proc u32At(bytes: string; offset: int): uint32 =
  for byteIndex in 0 ..< 4:
    result = result or
      (uint32(bytes.u8At(offset + byteIndex)) shl (byteIndex * 8))

proc u64At(bytes: string; offset: int): uint64 =
  for byteIndex in 0 ..< 8:
    result = result or
      (uint64(bytes.u8At(offset + byteIndex)) shl (byteIndex * 8))

proc i32At(bytes: string; offset: int): int {.inline.} =
  int(cast[int32](bytes.u32At(offset)))

proc f64At(bytes: string; offset: int): float =
  var bits = bytes.u64At(offset)
  copyMem(addr result, addr bits, sizeof(result))

proc pointAt(bytes: string; offset: int): StrategyPoint =
  StrategyPoint(x: bytes.i32At(offset), y: bytes.i32At(offset + 4))

proc rectAt(bytes: string; offset: int): StrategyRect =
  StrategyRect(x: bytes.i32At(offset), y: bytes.i32At(offset + 4),
    w: bytes.i32At(offset + 8), h: bytes.i32At(offset + 12))

proc section(sections: openArray[BinarySection]; kind: uint16;
             expectedStride, maxCount: int; required: bool;
             found: var BinarySection; detail: var string): bool =
  var matches = 0
  for item in sections:
    if item.kind == kind:
      inc matches
      found = item
  if matches == 0:
    if required:
      detail = "missing section " & $kind
      return false
    return true
  if matches != 1:
    detail = "duplicate section " & $kind
    return false
  if found.stride != expectedStride or found.count < 1 or
      found.count > maxCount:
    detail = "invalid section " & $kind & " shape"
    return false
  true

proc decodeBinary(payload: string; envelopeTick: uint32;
                  raw: var RawView; detail: var string;
                  errorKind: var ViewDecodeErrorKind): bool =
  errorKind = vdeBinaryHeader
  if payload.len < BinaryHeaderBytes or payload.len > MaxBinaryViewBytes:
    detail = "binary frame length is out of range"
    return false
  if payload[0 ..< BinaryMagic.len] != BinaryMagic:
    detail = "binary frame magic does not match"
    return false
  if payload.u16At(4) != BinaryVersion:
    detail = "binary frame version is unsupported"
    return false
  if payload.u8At(6) > 2:
    detail = "binary frame mode is invalid"
    return false
  let
    sectionCount = int(payload.u8At(7))
    embeddedTick = payload.u32At(8)
    frameBytes = payload.u32At(24)
    tableBytes = BinaryHeaderBytes + sectionCount * BinarySectionBytes
  if embeddedTick != envelopeTick:
    detail = "binary and envelope ticks differ"
    return false
  if payload.u32At(12) != 0 or payload.u32At(28) != 0:
    detail = "binary frame reserved field is nonzero"
    return false
  if frameBytes != uint32(payload.len) or tableBytes > payload.len:
    detail = "binary frame length or section table is invalid"
    return false

  errorKind = vdeBinarySection
  var sections: seq[BinarySection]
  var previousEnd = tableBytes
  for index in 0 ..< sectionCount:
    let entry = BinaryHeaderBytes + index * BinarySectionBytes
    if not payload.hasBytes(entry, BinarySectionBytes):
      detail = "short binary section entry"
      return false
    let item = BinarySection(
      kind: payload.u16At(entry),
      count: int(payload.u16At(entry + 2)),
      stride: int(payload.u16At(entry + 4)),
      offset: int(payload.u32At(entry + 8)))
    if payload.u16At(entry + 6) != 0 or item.count < 1 or
        item.stride < 1 or item.stride mod 4 != 0 or
        item.offset mod 4 != 0 or item.offset < previousEnd or
        item.count > (payload.len - item.offset) div item.stride:
      detail = "invalid binary section directory"
      return false
    sections.add(item)
    previousEnd = item.offset + item.count * item.stride

  var selfSection, worldSection, zoneSection, tracksSection, killSection:
    BinarySection
  if not sections.section(BvSelf, SelfStride, 1, true, selfSection, detail) or
      not sections.section(BvWorld, WorldStride, 1, true, worldSection, detail) or
      not sections.section(BvZone, ZoneStride, 1, false, zoneSection, detail) or
      not sections.section(BvTracks, TrackStride, MaxTracks, false,
        tracksSection, detail) or
      not sections.section(BvKillFeed, KillFeedStride, MaxKillFeed, false,
        killSection, detail):
    return false

  let selfFlags = payload.u32At(selfSection.offset)
  if (selfFlags and not SelfKnownFlags) != 0:
    detail = "unknown self flags"
    return false
  raw.tick = embeddedTick
  raw.epoch = payload.u64At(16)
  raw.self = StrategySelf(
    pos: payload.pointAt(selfSection.offset + 4),
    hp: payload.i32At(selfSection.offset + 12),
    hpFrac: payload.f64At(selfSection.offset + 16),
    alive: (selfFlags and SelfAliveFlag) != 0)
  if raw.self.hpFrac.classify in {fcNan, fcInf, fcNegInf}:
    detail = "self hp fraction is not finite"
    return false

  if payload.u32At(worldSection.offset) != 0 or
      payload.u32At(worldSection.offset + 12) != 0:
    detail = "world reserved field is nonzero"
    return false
  let aliveTeams = payload.u32At(worldSection.offset + 4)
  if aliveTeams > 16:
    detail = "alive team count is invalid"
    return false
  raw.aliveTeams = int(aliveTeams)

  if zoneSection.count == 1:
    let flags = payload.u32At(zoneSection.offset)
    if (flags and not ZoneKnownFlags) != 0:
      detail = "unknown zone flags"
      return false
    raw.zone = StrategyZone(
      present: true,
      phase: payload.i32At(zoneSection.offset + 4),
      ticksToShrink: payload.i32At(zoneSection.offset + 8),
      dps: payload.i32At(zoneSection.offset + 12),
      current: payload.rectAt(zoneSection.offset + 16),
      nextPresent: (flags and ZoneNextPresentFlag) != 0,
      next: payload.rectAt(zoneSection.offset + 32))
    if ((flags and ZoneDpsPresentFlag) != 0) != (raw.zone.dps != 0):
      detail = "zone dps flag is inconsistent"
      return false

  for index in 0 ..< tracksSection.count:
    let offset = tracksSection.offset + index * tracksSection.stride
    let flags = payload.u32At(offset)
    if (flags and not TrackKnownFlags) != 0:
      detail = "unknown track flags"
      return false
    let
      seat = payload.u32At(offset + 4)
      team = payload.u32At(offset + 8)
    if seat >= 32 or team >= uint32(TeamNames.len):
      detail = "track identity is invalid"
      return false
    raw.tracks.add(RawTrack(
      seat: int(seat),
      team: int(team),
      pos: payload.pointAt(offset + 12),
      freshTick: payload.u32At(offset + 20),
      hp: payload.i32At(offset + 28),
      hpKnown: (flags and TrackHpPresentFlag) != 0))

  for index in 0 ..< killSection.count:
    let offset = killSection.offset + index * killSection.stride
    let
      killerTeam = payload.u32At(offset + 4)
      victimSeat = payload.u32At(offset + 8)
    if killerTeam >= uint32(TeamNames.len) or victimSeat >= 32:
      detail = "kill feed identity is invalid"
      return false
    raw.killFeed.add(StrategyKill(
      tick: payload.u32At(offset), killerTeam: int(killerTeam),
      victimSeat: int(victimSeat)))
  true

proc intField(node: JsonNode; key: string; value: var int): bool =
  if node.kind != JObject or not node.hasKey(key) or node[key].kind != JInt:
    return false
  value = node[key].getInt
  true

proc uint32Field(node: JsonNode; key: string; value: var uint32): bool =
  var parsed: int
  if not node.intField(key, parsed) or parsed < 0 or
      uint64(parsed) > uint64(high(uint32)):
    return false
  value = uint32(parsed)
  true

proc uint64Field(node: JsonNode; key: string; value: var uint64): bool =
  if node.kind != JObject or not node.hasKey(key):
    return false
  case node[key].kind
  of JInt:
    let parsed = node[key].getBiggestInt
    if parsed < 0:
      return false
    value = uint64(parsed)
    true
  of JString:
    try:
      value = parseBiggestUInt(node[key].getStr).uint64
      true
    except ValueError:
      false
  else:
    false

proc floatField(node: JsonNode; key: string; value: var float): bool =
  if node.kind != JObject or not node.hasKey(key):
    return false
  case node[key].kind
  of JInt:
    value = float(node[key].getInt)
    true
  of JFloat:
    value = node[key].getFloat
    true
  else:
    false

proc boolField(node: JsonNode; key: string; value: var bool): bool =
  if node.kind != JObject or not node.hasKey(key) or node[key].kind != JBool:
    return false
  value = node[key].getBool
  true

proc point(node: JsonNode; value: var StrategyPoint): bool =
  if node.kind != JArray or node.len != 2 or
      node[0].kind != JInt or node[1].kind != JInt or
      node[0].getBiggestInt notin int64(low(int32)) .. int64(high(int32)) or
      node[1].getBiggestInt notin int64(low(int32)) .. int64(high(int32)):
    return false
  value = StrategyPoint(x: node[0].getInt, y: node[1].getInt)
  true

proc rect(node: JsonNode; value: var StrategyRect): bool =
  if node.kind != JArray or node.len != 4:
    return false
  for item in node:
    if item.kind != JInt or
        item.getBiggestInt notin int64(low(int32)) .. int64(high(int32)):
      return false
  value = StrategyRect(x: node[0].getInt, y: node[1].getInt,
    w: node[2].getInt, h: node[3].getInt)
  true

proc decodeJson(node: JsonNode; envelopeTick: uint32;
                raw: var RawView; detail: var string): bool =
  if node.kind != JObject or not node.hasKey("schema") or
      node["schema"].kind != JString or node["schema"].getStr != "play_view":
    detail = "JSON view schema is invalid"
    return false
  if not node.uint32Field("tick", raw.tick) or raw.tick != envelopeTick:
    detail = "JSON and envelope ticks differ"
    return false
  if not node.uint64Field("epoch", raw.epoch):
    detail = "JSON view epoch is invalid"
    return false
  if not node.hasKey("self") or not node.hasKey("world"):
    detail = "JSON view is missing self or world"
    return false
  let
    own = node["self"]
    world = node["world"]
  if own.kind != JObject or not own.hasKey("pos") or
      not own["pos"].point(raw.self.pos) or
      not own.intField("hp", raw.self.hp) or
      not own.floatField("hp_frac", raw.self.hpFrac) or
      not own.boolField("alive", raw.self.alive) or
      not world.intField("alive_teams", raw.aliveTeams):
    detail = "JSON self or world fields are invalid"
    return false
  if raw.self.hpFrac.classify in {fcNan, fcInf, fcNegInf}:
    detail = "JSON self hp fraction is not finite"
    return false
  if raw.aliveTeams < 0 or raw.aliveTeams > 16:
    detail = "JSON alive team count is invalid"
    return false

  if world.hasKey("zone"):
    let zone = world["zone"]
    raw.zone.present = true
    if zone.kind != JObject or not zone.hasKey("current") or
        not zone["current"].rect(raw.zone.current) or
        not zone.intField("phase", raw.zone.phase) or
        not zone.intField("ticks_to_shrink", raw.zone.ticksToShrink):
      detail = "JSON zone fields are invalid"
      return false
    if zone.hasKey("dps") and not zone.intField("dps", raw.zone.dps):
      detail = "JSON zone dps is invalid"
      return false
    if zone.hasKey("next"):
      raw.zone.nextPresent = true
      if not zone["next"].rect(raw.zone.next):
        detail = "JSON next zone is invalid"
        return false

  if node.hasKey("tracks"):
    if node["tracks"].kind != JArray or node["tracks"].len > MaxTracks:
      detail = "JSON tracks are invalid"
      return false
    for track in node["tracks"]:
      var row: RawTrack
      var teamName: string
      if track.kind == JObject and track.hasKey("team") and
          track["team"].kind == JString:
        teamName = track["team"].getStr
      row.team = teamName.teamId
      if not track.intField("seat", row.seat) or row.seat notin 0 ..< 32 or
          row.team < 0 or not track.hasKey("pos") or
          not track["pos"].point(row.pos) or
          not track.uint32Field("fresh_tick", row.freshTick):
        detail = "JSON track fields are invalid"
        return false
      if track.hasKey("hp"):
        row.hpKnown = true
        if not track.intField("hp", row.hp):
          detail = "JSON track hp is invalid"
          return false
      raw.tracks.add(row)

  if node.hasKey("kill_feed"):
    if node["kill_feed"].kind != JArray or
        node["kill_feed"].len > MaxKillFeed:
      detail = "JSON kill feed is invalid"
      return false
    for kill in node["kill_feed"]:
      var row: StrategyKill
      var killerName: string
      if kill.kind == JObject and kill.hasKey("killer_team") and
          kill["killer_team"].kind == JString:
        killerName = kill["killer_team"].getStr
      row.killerTeam = killerName.teamId
      if row.killerTeam < 0 or not kill.uint32Field("tick", row.tick) or
          not kill.intField("victim_seat", row.victimSeat) or
          row.victimSeat notin 0 ..< 32:
        detail = "JSON kill feed fields are invalid"
        return false
      raw.killFeed.add(row)
  true

proc distance(a, b: StrategyPoint): float =
  let
    dx = float(a.x) - float(b.x)
    dy = float(a.y) - float(b.y)
  sqrt(dx * dx + dy * dy)

proc isFresh(now, observed: uint32; window: uint32): bool {.inline.} =
  observed <= now and now - observed <= window

proc normalize(raw: RawView; partnerSeat, selfTeam: int;
               partnerDead: bool; gunRange: float;
               visibleFreshTicks: uint32): StrategyView =
  result.tick = raw.tick
  result.epoch = raw.epoch
  result.self = raw.self
  result.killFeed = raw.killFeed
  result.zone = raw.zone
  result.aliveTeams = raw.aliveTeams
  result.partner.seat = partnerSeat

  var inferredPartnerDead = partnerDead
  for kill in raw.killFeed:
    if kill.victimSeat == partnerSeat:
      inferredPartnerDead = true

  for track in raw.tracks:
    let separation = raw.self.pos.distance(track.pos)
    if track.seat == partnerSeat:
      result.partner.positionKnown = true
      result.partner.fresh = raw.tick.isFresh(track.freshTick, visibleFreshTicks)
      result.partner.pos = track.pos
      result.partner.distance = separation
      result.partner.aliveKnown = true
      result.partner.alive = not inferredPartnerDead
    elif track.team != selfTeam and
        raw.tick.isFresh(track.freshTick, visibleFreshTicks) and
        separation <= gunRange:
      result.visibleEnemies.add(StrategyEnemy(
        seat: track.seat, team: track.team, pos: track.pos,
        freshTick: track.freshTick, distance: separation,
        hp: track.hp, hpKnown: track.hpKnown,
        weakened: track.hpKnown and track.hp <= 2))
  if inferredPartnerDead:
    result.partner.aliveKnown = true
    result.partner.alive = false

proc decodeStrategyViewImpl(payload: string; envelopeTick: uint32;
                            partnerSeat, selfTeam: int; partnerDead: bool;
                            gunRange: float; visibleFreshTicks: uint32):
                            ViewDecodeResult =
  var
    raw: RawView
    detail: string
    errorKind = vdeNone
  if payload.startsWith(BinaryMagic[0 .. 2]):
    result.encoding = veBinary
    if not decodeBinary(payload, envelopeTick, raw, detail, errorKind):
      return failure(veBinary, errorKind, detail)
  elif payload.len > 0 and payload[0] == '{':
    result.encoding = veJson
    var node: JsonNode
    try:
      node = parseJson(payload)
    except CatchableError as error:
      return failure(veJson, vdeJsonSyntax, error.msg)
    if node.kind == JObject and node.len == 0:
      result.ignored = true
      return
    if not decodeJson(node, envelopeTick, raw, detail):
      return failure(veJson, vdeJsonShape, detail)
  else:
    return failure(veJson, vdeUnknownEncoding,
      "view payload is neither JSON nor PV1")

  result.ok = true
  result.view = raw.normalize(partnerSeat, selfTeam, partnerDead, gunRange,
    visibleFreshTicks)

proc decodeStrategyView*(payload: string; envelopeTick: uint32;
                         partnerSeat, selfTeam: int; partnerDead: bool;
                         gunRange: float; visibleFreshTicks: uint32 = 12):
                         ViewDecodeResult =
  ## View bytes are untrusted. A bad view is a dropped observation, never a
  ## reason for the socket owner to reconnect.
  try:
    result = decodeStrategyViewImpl(payload, envelopeTick, partnerSeat,
      selfTeam, partnerDead, gunRange, visibleFreshTicks)
  except CatchableError as error:
    result = failure(
      if payload.startsWith(BinaryMagic[0 .. 2]): veBinary else: veJson,
      vdeInternal, error.msg)
