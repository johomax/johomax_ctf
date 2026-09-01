## Season 2 play-seat lifecycle and a deliberately small 4 Hz strategist.

import
  std/[json, strutils],
  whisky_fixed,
  playbook_bodyguard,
  playbook_crossfire,
  playbook_edge_ride,
  playbook_jackal,
  playbook_supply_run,
  playbook_target_law,
  shell_view,
  shell_wire

const
  # The body applies all three native safety reflexes outside the guest ladder;
  # their reserved names are not call bindings and the validator rejects them.
  TargetLawSurvivalEntry =
    "{\"params\":{\"holdTrigger\":{\"aliveTeams\":8},\"prefer\":[\"weakened\",\"isolated\"]},\"play\":\"target_law\"}"
  TargetLawFightEntry =
    "{\"params\":{\"prefer\":[\"weakened\",\"isolated\"]},\"play\":\"target_law\"}"
  SupplyRunEntry =
    "{\"params\":{\"contested\":\"avoid\",\"detourMax\":500,\"whenHpBelow\":3},\"play\":\"supply_run\",\"when\":[\"<\",[\"get\",\"self.hp_frac\"],0.67]}"
  BodyguardEntry =
    "{\"params\":{\"interpose\":false,\"leash\":[80,220],\"peelHp\":2},\"play\":\"bodyguard\",\"when\":[\"<\",220,[\"get\",\"partner.dist\"]]}"
  EdgeRideEntry =
    "{\"params\":{\"coverBias\":1.0,\"enterLead\":120,\"margin\":220},\"play\":\"edge_ride\"}"
  CrossfireEntry =
    "{\"params\":{\"minAngle\":32,\"spacing\":[120,320]},\"play\":\"crossfire\"}"
  JackalEntry =
    "{\"params\":{\"earshot\":500,\"exitAfter\":{\"kills\":1},\"joinWhen\":\"bothWeakened\"},\"play\":\"jackal\"}"
  EdgeRideCall = "{\"plays\":[" & EdgeRideEntry & "]}"
  # Views normally arrive every six ticks, making 552 the last regular
  # decision point before the hard tick-560 standing-call deadline.
  StartupCallDeadlineTick = 552
  ZoneUrgencyTicks = 120
  VisibleFreshTicks = 12

static:
  doAssert PlaybookEdgeRideBytes.len <= MaxModuleBytes
  doAssert PlaybookTargetLawBytes.len <= MaxModuleBytes
  doAssert PlaybookSupplyRunBytes.len <= MaxModuleBytes
  doAssert PlaybookBodyguardBytes.len <= MaxModuleBytes
  doAssert PlaybookCrossfireBytes.len <= MaxModuleBytes
  doAssert PlaybookJackalBytes.len <= MaxModuleBytes
  # A six-message burst fits classification, but the engine admits only one
  # upload per seat per tick. Keep the terminal-paced sender below so uploads
  # are not rejected by that stricter quota.
  doAssert 6 < 64
  doAssert PlaybookEdgeRideBytes.len + PlaybookTargetLawBytes.len +
    PlaybookSupplyRunBytes.len + PlaybookBodyguardBytes.len +
    PlaybookCrossfireBytes.len + PlaybookJackalBytes.len + 6 * 14 < 524_288

type
  ModuleState = enum
    msUnsent
    msPending
    msReady
    msUnavailable

  EmbeddedModule = object
    name: string
    sha256: string
    wasm: string
    state: ModuleState
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
    pendingCallJson: string
    pendingCallSmallest: bool
    activePhase: StrategyPhase
    standingAccepted: bool
    initialCallSent: bool
    retrySmallest: bool
    noReadyLogged: bool
    phaseStartTick: int
    highestStatus: uint64
    ackMark: uint64
    highestChat: uint64
    partnerSeat: int
    selfTeam: int
    gunRange: float
    partnerDead: bool
    viewDecodeLogged: set[ViewDecodeErrorKind]

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
    partnerSeat: -1, selfTeam: -1, gunRange: 700.0)
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

proc moduleIndex(seat: ShellSeat; name: string): int =
  for index, module in seat.modules:
    if module.name == name:
      return index
  -1

proc moduleReady(seat: ShellSeat; name: string): bool =
  let index = seat.moduleIndex(name)
  index >= 0 and seat.modules[index].state == msReady

proc moduleUnavailable(seat: ShellSeat; name: string): bool =
  let index = seat.moduleIndex(name)
  index >= 0 and seat.modules[index].state == msUnavailable

proc addCallEntry(entries: var seq[string]; seat: ShellSeat;
                  name, entry: string) =
  if seat.moduleReady(name):
    entries.add(entry)

proc phaseCall(seat: ShellSeat; phase: StrategyPhase): string =
  var entries: seq[string]
  case phase
  of phaseSurvival:
    entries.addCallEntry(seat, PlaybookTargetLawName,
      TargetLawSurvivalEntry)
    entries.addCallEntry(seat, PlaybookSupplyRunName, SupplyRunEntry)
    entries.addCallEntry(seat, PlaybookBodyguardName, BodyguardEntry)
    entries.addCallEntry(seat, PlaybookEdgeRideName, EdgeRideEntry)
  of phaseCrossfire:
    entries.addCallEntry(seat, PlaybookTargetLawName, TargetLawFightEntry)
    entries.addCallEntry(seat, PlaybookCrossfireName, CrossfireEntry)
  of phaseJackal:
    entries.addCallEntry(seat, PlaybookTargetLawName, TargetLawFightEntry)
    entries.addCallEntry(seat, PlaybookJackalName, JackalEntry)
  if entries.len > 0:
    result = "{\"plays\":[" & entries.join(",") & "]}"

proc readyModuleNames(seat: ShellSeat): string =
  var names: seq[string]
  for module in seat.modules:
    if module.state == msReady:
      names.add(module.name)
  if names.len == 0: "none" else: names.join(",")

proc uploadsSettled(seat: ShellSeat): bool =
  for module in seat.modules:
    if module.state notin {msReady, msUnavailable}:
      return false
  true

proc startupCallDecision(seat: ShellSeat; tick: int): tuple[
    send: bool, callJson: string, reason: string] =
  if seat.initialCallSent or seat.pendingProposalId != 0 or
      (not seat.uploadsSettled and tick < StartupCallDeadlineTick):
    return
  result.callJson = seat.phaseCall(phaseSurvival)
  result.send = result.callJson.len > 0
  result.reason =
    if seat.uploadsSettled: "uploads_settled"
    else: "lobby_deadline_tick_" & $tick

proc smallestRetryCall(seat: ShellSeat): string =
  if seat.retrySmallest and seat.moduleReady(PlaybookEdgeRideName):
    EdgeRideCall
  else:
    ""

proc nextUploadIndex(seat: ShellSeat): int =
  if seat.pendingUploadId != 0:
    return -1
  for index, module in seat.modules:
    if module.state == msUnsent:
      return index
  -1

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
  seat.modules[index].state = msPending
  ws.send(moduleUploadBlob(uploadId, seat.modules[index].wasm), BinaryMessage)
  log("upload name=" & seat.modules[index].name & " id=" & $uploadId &
    " bytes=" & $seat.modules[index].wasm.len)

proc sendCall(seat: ShellSeat; ws: WebSocket; phase: StrategyPhase;
              callJson, decision: string; smallest = false) =
  let proposalId = seat.nextProposalId
  inc seat.nextProposalId
  seat.pendingProposalId = proposalId
  seat.pendingPhase = phase
  seat.pendingCallJson = callJson
  seat.pendingCallSmallest = smallest
  seat.initialCallSent = true
  ws.send(playCallBlob(proposalId, callJson), BinaryMessage)
  log("call sent phase=" & phase.phaseName & " id=" & $proposalId &
    " decision=" & decision & " ready=" & seat.readyModuleNames &
    " json=" & callJson)

proc advanceStartup(seat: ShellSeat; ws: WebSocket; tick = -1) =
  if not seat.contextSeen:
    return

  if seat.retrySmallest and seat.pendingProposalId == 0:
    let callJson = seat.smallestRetryCall
    if callJson.len > 0:
      seat.retrySmallest = false
      seat.sendCall(ws, phaseSurvival, callJson,
        "rejection_fallback", true)
    elif seat.moduleUnavailable(PlaybookEdgeRideName):
      seat.retrySmallest = false
      log("call fallback skipped reason=edge_ride_unavailable")

  let startup = seat.startupCallDecision(tick)
  if startup.send:
    seat.sendCall(ws, phaseSurvival, startup.callJson, startup.reason)
  elif startup.reason.len > 0 and not seat.noReadyLogged:
    seat.noReadyLogged = true
    log("call unavailable decision=" & startup.reason & " tick=" & $tick &
      " ready=none native_default_remains=true")

  let nextUpload = seat.nextUploadIndex
  if nextUpload >= 0:
    seat.sendUpload(ws, nextUpload)

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
    seat.selfTeam = own.stringValue("team").teamId
    if seat.selfTeam < 0:
      raise newException(ValueError, "invalid S2 context self team")
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
      seat.pendingProposalId, seat.pendingCallJson), BinaryMessage)
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
      log("module ready ignored reason=unknown_upload id=" & $uploadId)
      return
    if status.stringValue("name") != seat.modules[index].name or
        status.stringValue("sha256") != seat.modules[index].sha256:
      seat.modules[index].state = msUnavailable
      if seat.pendingUploadId == uploadId:
        seat.pendingUploadId = 0
      log("module unavailable name=" & seat.modules[index].name &
        " reason=ready_identity_mismatch")
      return
    seat.modules[index].state = msReady
    if seat.pendingUploadId == uploadId:
      seat.pendingUploadId = 0
    log("module ready name=" & seat.modules[index].name & " sha256=" &
      seat.modules[index].sha256)
  of "module_rejected":
    let
      uploadId = status.uintValue("upload_id")
      index = seat.findModule(uploadId)
      reason = status.stringValue("reason")
    if index >= 0:
      seat.modules[index].state = msUnavailable
      if seat.pendingUploadId == uploadId:
        seat.pendingUploadId = 0
      log("module unavailable name=" & seat.modules[index].name & " id=" &
        $uploadId & " reason=" & reason)
    else:
      log("module rejection ignored id=" & $uploadId &
        " reason=unknown_upload detail=" & reason)
  of "call_accepted":
    let proposalId = status.uintValue("proposal_id")
    if proposalId == seat.pendingProposalId:
      seat.pendingProposalId = 0
      seat.pendingCallJson.setLen(0)
      seat.pendingCallSmallest = false
      seat.retrySmallest = false
      seat.activePhase = seat.pendingPhase
      seat.standingAccepted = true
      seat.phaseStartTick = status.intValue("tick")
      log("call accepted phase=" & seat.activePhase.phaseName & " id=" &
        $proposalId & " epoch=" & $status.uintValue("epoch") & " tick=" &
        $status.intValue("tick"))
    else:
      log("call acceptance ignored id=" & $proposalId &
        " reason=not_pending")
  of "call_rejected":
    let proposalId = status.uintValue("proposal_id")
    var
      reason = status.stringValue("reason")
      path = status.stringValue("path")
      detail = status.stringValue("detail")
    # Current engines serialize reason:path into `reason`; tolerate the
    # separate forward-compatible fields too.
    if path.len == 0:
      let separator = reason.find(':')
      if separator >= 0:
        path = reason[separator + 1 .. ^1]
        reason.setLen(separator)
    if detail.len == 0:
      detail = "unavailable"
    log("call rejected id=" & $proposalId & " reason=" & reason &
      " path=" & path & " detail=" & detail)
    if proposalId == seat.pendingProposalId:
      let wasSmallest = seat.pendingCallSmallest
      seat.pendingProposalId = 0
      seat.pendingCallJson.setLen(0)
      seat.pendingCallSmallest = false
      if wasSmallest:
        log("call fallback stopped reason=edge_ride_retry_rejected")
      else:
        seat.retrySmallest = true
        log("call fallback queued play=edge_ride")
    else:
      log("call fallback skipped reason=not_pending")
  of "play_faulted", "retune_refused":
    discard
  else:
    log("status ignored kind=" & kind)

proc handleControl(seat: ShellSeat; ws: WebSocket; controlBytes: string;
                   tick = -1) =
  if controlBytes.len == 0:
    return
  let control = parseJson(controlBytes)
  if control.kind == JObject and control.hasKey("statuses"):
    for status in control["statuses"]:
      seat.handleStatus(status)
  if seat.highestStatus > seat.ackMark:
    seat.ackMark = seat.highestStatus
    ws.send(statusAckBlob(seat.ackMark), BinaryMessage)
  seat.advanceStartup(ws, tick)

proc desiredPhase(seat: ShellSeat; view: StrategyView): StrategyPhase =
  if not view.self.alive:
    return phaseSurvival

  let hpLow = view.self.hpFrac < 0.67
  var zoneUrgent = false
  if view.zone.present:
    let
      zone = view.zone
      pos = view.self.pos
      rect = zone.current
    zoneUrgent = zone.ticksToShrink <= ZoneUrgencyTicks or
      pos.x < rect.x or pos.x >= rect.x + rect.w or
      pos.y < rect.y or pos.y >= rect.y + rect.h

  var
    weakEnemies = 0
    freshKill = false
    ownKill = false
  for row in view.killFeed:
    if row.victimSeat == seat.partnerSeat:
      seat.partnerDead = true
    if row.tick <= view.tick and view.tick - row.tick <= 240:
      freshKill = true
    if int(row.tick) > seat.phaseStartTick and row.killerTeam == seat.selfTeam:
      ownKill = true
  if view.partner.aliveKnown and not view.partner.alive:
    seat.partnerDead = true
  for enemy in view.visibleEnemies:
    if enemy.weakened:
      inc weakEnemies

  let
    visibleEnemy = view.visibleEnemies.len > 0
    partnerInShape = view.partner.positionKnown and view.partner.fresh and
      view.partner.alive and view.partner.distance <= 600.0
  if seat.activePhase != phaseSurvival and
      (zoneUrgent or hpLow or seat.partnerDead or ownKill or not visibleEnemy):
    return phaseSurvival
  if zoneUrgent or hpLow or seat.partnerDead:
    return phaseSurvival
  if freshKill and weakEnemies >= 2 and
      seat.moduleReady(PlaybookJackalName):
    return phaseJackal
  if visibleEnemy and weakEnemies >= 1 and partnerInShape and
      seat.moduleReady(PlaybookCrossfireName):
    return phaseCrossfire
  phaseSurvival

proc handleView(seat: ShellSeat; ws: WebSocket; packet: ShellPacket) =
  seat.handleControl(ws, packet.control, packet.tick.int)
  if packet.view.len == 0 or not seat.standingAccepted or
      seat.pendingProposalId != 0:
    return
  let decoded = decodeStrategyView(packet.view, packet.tick, seat.partnerSeat,
    seat.selfTeam, seat.partnerDead, seat.gunRange, VisibleFreshTicks.uint32)
  if not decoded.ok:
    if decoded.errorKind notin seat.viewDecodeLogged:
      seat.viewDecodeLogged.incl(decoded.errorKind)
      log("view ignored kind=" & decoded.errorKind.viewDecodeErrorName &
        " detail=" & decoded.detail)
    return
  let wanted = seat.desiredPhase(decoded.view)
  if wanted != seat.activePhase:
    let callJson = seat.phaseCall(wanted)
    if callJson.len == 0:
      log("phase skipped from=" & seat.activePhase.phaseName & " to=" &
        wanted.phaseName & " tick=" & $packet.tick &
        " reason=no_ready_modules")
    else:
      log("phase " & seat.activePhase.phaseName & " -> " & wanted.phaseName &
        " at tick=" & $packet.tick)
      seat.sendCall(ws, wanted, callJson, "phase_change")

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
