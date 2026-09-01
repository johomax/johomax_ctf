## Season 2 play-seat lifecycle and a deliberately small 4 Hz strategist.

import
  std/[json, math, strutils],
  whisky_fixed,
  playbook_bodyguard,
  playbook_crossfire,
  playbook_edge_ride,
  playbook_jackal,
  playbook_supply_run,
  playbook_target_law,
  shell_wire

const
  # The body applies all three native safety reflexes outside the guest ladder;
  # their reserved names are not call bindings and the validator rejects them.
  SurvivalCall =
    "{\"plays\":[{\"params\":{\"holdTrigger\":{\"aliveTeams\":8},\"prefer\":[\"weakened\",\"isolated\"]},\"play\":\"target_law\"},{\"params\":{\"contested\":\"avoid\",\"detourMax\":500,\"whenHpBelow\":3},\"play\":\"supply_run\",\"when\":[\"<\",[\"get\",\"self.hp_frac\"],0.67]},{\"params\":{\"interpose\":false,\"leash\":[80,220],\"peelHp\":2},\"play\":\"bodyguard\",\"when\":[\"<\",220,[\"get\",\"partner.dist\"]]},{\"params\":{\"coverBias\":1.0,\"enterLead\":120,\"margin\":220},\"play\":\"edge_ride\"}]}"
  CrossfireCall =
    "{\"plays\":[{\"params\":{\"prefer\":[\"weakened\",\"isolated\"]},\"play\":\"target_law\"},{\"params\":{\"minAngle\":32,\"spacing\":[120,320]},\"play\":\"crossfire\"}]}"
  JackalCall =
    "{\"plays\":[{\"params\":{\"prefer\":[\"weakened\",\"isolated\"]},\"play\":\"target_law\"},{\"params\":{\"earshot\":500,\"exitAfter\":{\"kills\":1},\"joinWhen\":\"bothWeakened\"},\"play\":\"jackal\"}]}"
  ZoneUrgencyTicks = 120
  VisibleFreshTicks = 12

static:
  doAssert PlaybookEdgeRideBytes.len <= MaxModuleBytes
  doAssert PlaybookTargetLawBytes.len <= MaxModuleBytes
  doAssert PlaybookSupplyRunBytes.len <= MaxModuleBytes
  doAssert PlaybookBodyguardBytes.len <= MaxModuleBytes
  doAssert PlaybookCrossfireBytes.len <= MaxModuleBytes
  doAssert PlaybookJackalBytes.len <= MaxModuleBytes

type
  EmbeddedModule = object
    name: string
    sha256: string
    wasm: string
    ready: bool
    uploadId: uint64

  StrategyPhase = enum
    phaseSurvival
    phaseCrossfire
    phaseJackal

  ShellSeat* = ref object
    slot: int
    modules: seq[EmbeddedModule]
    contextSeen: bool
    generation: uint64
    nextUploadId: uint64
    nextProposalId: uint64
    pendingUploadId: uint64
    pendingProposalId: uint64
    pendingPhase: StrategyPhase
    activePhase: StrategyPhase
    standingAccepted: bool
    phaseStartTick: int
    highestStatus: uint64
    ackMark: uint64
    highestChat: uint64
    partnerSeat: int
    selfTeam: string
    gunRange: float
    partnerDead: bool

proc log(message: string) =
  echo "[s2] ", message
  flushFile(stdout)

proc bytesString[T](values: openArray[T]): string =
  result = newString(values.len)
  for index, value in values:
    result[index] = char(value)

proc addModule[T](modules: var seq[EmbeddedModule]; name, sha256: string;
                  values: openArray[T]) =
  modules.add(EmbeddedModule(
    name: name, sha256: sha256, wasm: bytesString(values)))

proc newShellSeat*(slot: int): ShellSeat =
  result = ShellSeat(slot: slot, nextUploadId: 1, nextProposalId: 1,
    partnerSeat: -1, gunRange: 700.0)
  result.modules.addModule(
    PlaybookEdgeRideName, PlaybookEdgeRideSha256, PlaybookEdgeRideBytes)
  result.modules.addModule(
    PlaybookTargetLawName, PlaybookTargetLawSha256, PlaybookTargetLawBytes)
  result.modules.addModule(
    PlaybookSupplyRunName, PlaybookSupplyRunSha256, PlaybookSupplyRunBytes)
  result.modules.addModule(
    PlaybookBodyguardName, PlaybookBodyguardSha256, PlaybookBodyguardBytes)
  result.modules.addModule(
    PlaybookCrossfireName, PlaybookCrossfireSha256, PlaybookCrossfireBytes)
  result.modules.addModule(
    PlaybookJackalName, PlaybookJackalSha256, PlaybookJackalBytes)

proc beginConnection*(seat: ShellSeat) =
  seat.contextSeen = false

proc uintValue(node: JsonNode; key: string): uint64 =
  if node.kind != JObject or not node.hasKey(key):
    return 0
  let value = node[key]
  case value.kind
  of JString:
    try:
      parseBiggestUInt(value.getStr).uint64
    except ValueError:
      0
  of JInt:
    max(0'i64, value.getBiggestInt).uint64
  else:
    0

proc intValue(node: JsonNode; key: string; fallback = 0): int =
  if node.kind == JObject and node.hasKey(key) and node[key].kind == JInt:
    node[key].getInt
  else:
    fallback

proc floatValue(node: JsonNode; key: string; fallback = 0.0): float =
  if node.kind != JObject or not node.hasKey(key):
    return fallback
  case node[key].kind
  of JFloat: node[key].getFloat
  of JInt: float(node[key].getInt)
  else: fallback

proc stringValue(node: JsonNode; key: string): string =
  if node.kind == JObject and node.hasKey(key) and node[key].kind == JString:
    node[key].getStr
  else:
    ""

proc phaseName(phase: StrategyPhase): string =
  case phase
  of phaseSurvival: "survival"
  of phaseCrossfire: "crossfire"
  of phaseJackal: "jackal"

proc phaseCall(phase: StrategyPhase): string =
  case phase
  of phaseSurvival: SurvivalCall
  of phaseCrossfire: CrossfireCall
  of phaseJackal: JackalCall

proc findModule(seat: ShellSeat; uploadId: uint64): int =
  for index, module in seat.modules:
    if module.uploadId == uploadId:
      return index
  -1

proc sendUpload(seat: ShellSeat; ws: WebSocket; index: int) =
  let uploadId = seat.nextUploadId
  inc seat.nextUploadId
  seat.pendingUploadId = uploadId
  seat.modules[index].uploadId = uploadId
  ws.send(moduleUploadBlob(uploadId, seat.modules[index].wasm), BinaryMessage)
  log("upload name=" & seat.modules[index].name & " id=" & $uploadId &
    " bytes=" & $seat.modules[index].wasm.len)

proc sendCall(seat: ShellSeat; ws: WebSocket; phase: StrategyPhase) =
  let proposalId = seat.nextProposalId
  inc seat.nextProposalId
  seat.pendingProposalId = proposalId
  seat.pendingPhase = phase
  let callJson = phase.phaseCall
  ws.send(playCallBlob(proposalId, callJson), BinaryMessage)
  log("call sent phase=" & phase.phaseName & " id=" & $proposalId &
    " json=" & callJson)

proc advanceStartup(seat: ShellSeat; ws: WebSocket) =
  if not seat.contextSeen or seat.pendingUploadId != 0:
    return
  for index, module in seat.modules:
    if not module.ready:
      seat.sendUpload(ws, index)
      return
  if not seat.standingAccepted and seat.pendingProposalId == 0:
    seat.sendCall(ws, phaseSurvival)

proc handleContext(seat: ShellSeat; ws: WebSocket; packet: ShellPacket) =
  let
    control = parseJson(packet.control)
    context = parseJson(packet.context)
  if control.stringValue("schema") != "control_context" or
      context.stringValue("schema") != "play_context":
    raise newException(ValueError, "invalid S2 context schema")
  seat.contextSeen = true
  seat.generation = control.uintValue("gen")
  seat.ackMark = max(seat.ackMark, control.uintValue("ack_mark"))
  seat.highestStatus = max(seat.highestStatus, seat.ackMark)
  if control.hasKey("floors"):
    let floors = control["floors"]
    seat.nextUploadId = max(seat.nextUploadId,
      floors.uintValue("upload_id") + 1)
    seat.nextProposalId = max(seat.nextProposalId,
      floors.uintValue("proposal_id") + 1)
  if context.hasKey("self"):
    let own = context["self"]
    seat.partnerSeat = own.intValue("duo_partner", -1)
    seat.selfTeam = own.stringValue("team")
  seat.gunRange = context.floatValue("gun_range", seat.gunRange)
  log("context gen=" & $seat.generation & " upload_floor=" &
    $(seat.nextUploadId - 1) & " proposal_floor=" &
    $(seat.nextProposalId - 1) & " partner=" & $seat.partnerSeat)

  # A send may have lost its socket before admission. Recovery floors say
  # whether replay will contain its durable outcome; resend only when it did
  # not cross the admission boundary.
  let floors = control["floors"]
  if seat.pendingUploadId > floors.uintValue("upload_id"):
    let index = seat.findModule(seat.pendingUploadId)
    if index >= 0:
      ws.send(moduleUploadBlob(
        seat.pendingUploadId, seat.modules[index].wasm), BinaryMessage)
      log("upload resent id=" & $seat.pendingUploadId)
  elif seat.pendingProposalId > floors.uintValue("proposal_id"):
    ws.send(playCallBlob(
      seat.pendingProposalId, seat.pendingPhase.phaseCall), BinaryMessage)
    log("call resent id=" & $seat.pendingProposalId)
  seat.advanceStartup(ws)

proc handleStatus(seat: ShellSeat; status: JsonNode) =
  let ordinal = status.uintValue("ordinal")
  if ordinal <= seat.highestStatus:
    return
  seat.highestStatus = ordinal
  log("status " & $status)
  let kind = status.stringValue("kind")
  case kind
  of "module_accepted":
    discard
  of "module_ready":
    let
      uploadId = status.uintValue("upload_id")
      index = seat.findModule(uploadId)
    if index < 0:
      raise newException(ValueError,
        "module_ready names unknown upload id " & $uploadId)
    if status.stringValue("name") != seat.modules[index].name or
        status.stringValue("sha256") != seat.modules[index].sha256:
      raise newException(ValueError,
        "module_ready identity mismatch for " & seat.modules[index].name)
    seat.modules[index].ready = true
    if seat.pendingUploadId == uploadId:
      seat.pendingUploadId = 0
    log("module ready name=" & seat.modules[index].name & " sha256=" &
      seat.modules[index].sha256)
  of "module_rejected":
    raise newException(ValueError, "module rejected: " &
      status.stringValue("reason"))
  of "call_accepted":
    let proposalId = status.uintValue("proposal_id")
    if proposalId == seat.pendingProposalId:
      seat.pendingProposalId = 0
      seat.activePhase = seat.pendingPhase
      seat.standingAccepted = true
      seat.phaseStartTick = status.intValue("tick")
    log("call accepted phase=" & seat.activePhase.phaseName & " epoch=" &
      $status.uintValue("epoch") & " tick=" & $status.intValue("tick"))
  of "call_rejected":
    raise newException(ValueError, "call rejected: " &
      status.stringValue("reason"))
  of "play_faulted", "retune_refused":
    discard
  else:
    raise newException(ValueError, "unknown S2 status kind " & kind)

proc handleControl(seat: ShellSeat; ws: WebSocket; controlBytes: string) =
  if controlBytes.len == 0:
    return
  let control = parseJson(controlBytes)
  if control.kind == JObject and control.hasKey("statuses"):
    for status in control["statuses"]:
      seat.handleStatus(status)
  if seat.highestStatus > seat.ackMark:
    seat.ackMark = seat.highestStatus
    ws.send(statusAckBlob(seat.ackMark), BinaryMessage)
  seat.advanceStartup(ws)

proc arrayInt(node: JsonNode; index: int): int =
  if node.kind == JArray and index in 0 ..< node.len and
      node[index].kind == JInt:
    node[index].getInt
  else:
    0

proc distance(a, b: JsonNode): float =
  let
    dx = float(a.arrayInt(0) - b.arrayInt(0))
    dy = float(a.arrayInt(1) - b.arrayInt(1))
  sqrt(dx * dx + dy * dy)

proc desiredPhase(seat: ShellSeat; view: JsonNode): StrategyPhase =
  if view.kind != JObject or not view.hasKey("self") or
      not view.hasKey("world"):
    return phaseSurvival
  let
    tick = view.intValue("tick")
    own = view["self"]
    world = view["world"]
  if own.hasKey("alive") and not own["alive"].getBool:
    return phaseSurvival

  let hpLow = own.floatValue("hp_frac", 1.0) < 0.67
  var zoneUrgent = false
  if world.hasKey("zone"):
    let zone = world["zone"]
    zoneUrgent = zone.intValue("ticks_to_shrink", high(int)) <=
      ZoneUrgencyTicks
    if zone.hasKey("current") and own.hasKey("pos"):
      let
        rect = zone["current"]
        pos = own["pos"]
        x = pos.arrayInt(0)
        y = pos.arrayInt(1)
        zoneX = rect.arrayInt(0)
        zoneY = rect.arrayInt(1)
        zoneW = rect.arrayInt(2)
        zoneH = rect.arrayInt(3)
      zoneUrgent = zoneUrgent or x < zoneX or x >= zoneX + zoneW or
        y < zoneY or y >= zoneY + zoneH

  var
    partnerKnown = false
    partnerPos: JsonNode
    weakEnemies = 0
    visibleEnemy = false
    freshKill = false
    ownKill = false
  if view.hasKey("kill_feed"):
    for row in view["kill_feed"]:
      let rowTick = row.intValue("tick", -1)
      if row.intValue("victim_seat", -1) == seat.partnerSeat:
        seat.partnerDead = true
      if rowTick >= tick - 240:
        freshKill = true
      if rowTick > seat.phaseStartTick and
          row.stringValue("killer_team") == seat.selfTeam:
        ownKill = true
  if view.hasKey("tracks") and own.hasKey("pos"):
    for track in view["tracks"]:
      if track.intValue("seat", -1) == seat.partnerSeat:
        if track.hasKey("pos") and
            track.intValue("fresh_tick", -1) >= tick - VisibleFreshTicks:
          partnerKnown = true
          partnerPos = track["pos"]
        continue
      if track.stringValue("team") == seat.selfTeam or
          track.intValue("fresh_tick", -1) < tick - VisibleFreshTicks or
          not track.hasKey("pos"):
        continue
      if distance(own["pos"], track["pos"]) <= seat.gunRange:
        visibleEnemy = true
        if track.intValue("hp", high(int)) <= 2:
          inc weakEnemies

  let partnerInShape = partnerKnown and own.hasKey("pos") and
    distance(own["pos"], partnerPos) <= 600.0
  if seat.activePhase != phaseSurvival and
      (zoneUrgent or hpLow or seat.partnerDead or ownKill or not visibleEnemy):
    return phaseSurvival
  if zoneUrgent or hpLow or seat.partnerDead:
    return phaseSurvival
  if freshKill and weakEnemies >= 2:
    return phaseJackal
  if visibleEnemy and weakEnemies >= 1 and partnerInShape:
    return phaseCrossfire
  phaseSurvival

proc handleView(seat: ShellSeat; ws: WebSocket; packet: ShellPacket) =
  seat.handleControl(ws, packet.control)
  if packet.view.len == 0 or not seat.standingAccepted or
      seat.pendingProposalId != 0:
    return
  let wanted = seat.desiredPhase(parseJson(packet.view))
  if wanted != seat.activePhase:
    log("phase " & seat.activePhase.phaseName & " -> " & wanted.phaseName &
      " at tick=" & $packet.tick)
    seat.sendCall(ws, wanted)

proc handleShellMessage*(seat: ShellSeat; ws: WebSocket; message: Message) =
  case message.kind
  of Ping:
    ws.send(message.data, Pong)
  of TextMessage, Pong:
    discard
  of BinaryMessage:
    if message.data.len == 0 or message.data[0].uint8 notin
        {OpPlayContext, OpPlayView, OpLobbyChatBroadcast}:
      return                    # legacy broadcasts can share a play socket
    let packet = decodeShellPacket(message.data)
    case packet.kind
    of spPlayContext:
      seat.handleContext(ws, packet)
    of spPlayView:
      seat.handleView(ws, packet)
    of spLobbyChat:
      if packet.ordinal > seat.highestChat:
        seat.highestChat = packet.ordinal
        log("lobby chat ordinal=" & $packet.ordinal & " seat=" &
          $packet.seat & " team=" & $packet.team & " text=" & packet.text)
