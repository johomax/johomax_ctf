## Season 2 play-seat packet framing. Payload JSON remains opaque here.

const
  ShellVersion* = 1'u8
  OpModuleUpload* = 0xA0'u8
  OpPlayCall* = 0xA1'u8
  OpStatusAck* = 0xA2'u8
  OpLobbyChatSend* = 0xA3'u8
  OpPlayContext* = 0xB0'u8
  OpPlayView* = 0xB1'u8
  OpLobbyChatBroadcast* = 0xB2'u8
  MaxModuleBytes* = 262_144
  MaxCallBytes* = 4_096
  MaxControlBytes = 20_480
  MaxContextBytes = 65_536
  MaxViewBytes = 32_768
  MaxLobbyChatBytes = 512

type
  ShellPacketKind* = enum
    spPlayContext
    spPlayView
    spLobbyChat

  ShellPacket* = object
    kind*: ShellPacketKind
    control*: string
    context*: string
    view*: string
    tick*: uint32
    ordinal*: uint64
    seat*: uint8
    team*: uint8
    text*: string

proc putU8(bytes: var string; cursor: var int; value: uint8) {.inline.} =
  bytes[cursor] = char(value)
  inc cursor

proc putU32(bytes: var string; cursor: var int; value: uint32) =
  for shift in countup(0, 24, 8):
    bytes.putU8(cursor, uint8((value shr shift) and 0xff'u32))

proc putU64(bytes: var string; cursor: var int; value: uint64) =
  for shift in countup(0, 56, 8):
    bytes.putU8(cursor, uint8((value shr shift) and 0xff'u64))

proc putPayload(bytes: var string; cursor: var int; payload: string) =
  if payload.len > 0:
    copyMem(addr bytes[cursor], unsafeAddr payload[0], payload.len)
    cursor += payload.len

proc readU8(bytes: string; cursor: var int): uint8 =
  if cursor >= bytes.len:
    raise newException(ValueError, "short shell packet")
  result = bytes[cursor].uint8
  inc cursor

proc readU32(bytes: string; cursor: var int): uint32 =
  for shift in countup(0, 24, 8):
    result = result or (uint32(bytes.readU8(cursor)) shl shift)

proc readU64(bytes: string; cursor: var int): uint64 =
  for shift in countup(0, 56, 8):
    result = result or (uint64(bytes.readU8(cursor)) shl shift)

proc readPayload(bytes: string; cursor: var int; cap: int): string =
  let length = bytes.readU32(cursor)
  if length > uint32(cap) or int(length) > bytes.len - cursor:
    raise newException(ValueError, "invalid shell payload length")
  result = bytes[cursor ..< cursor + int(length)]
  cursor += int(length)

proc putHeader(bytes: var string; cursor: var int; opcode: uint8) =
  bytes.putU8(cursor, opcode)
  bytes.putU8(cursor, ShellVersion)

proc isS2FirstPacket*(bytes: string): bool =
  bytes.len >= 2 and bytes[1].uint8 == ShellVersion and
    bytes[0].uint8 in {OpPlayContext, OpLobbyChatBroadcast}

proc moduleUploadBlob*(uploadId: uint64; wasm: string): string =
  if wasm.len > MaxModuleBytes:
    raise newException(ValueError, "play module exceeds 256 KiB")
  result = newString(14 + wasm.len)
  var cursor = 0
  result.putHeader(cursor, OpModuleUpload)
  result.putU64(cursor, uploadId)
  result.putU32(cursor, uint32(wasm.len))
  result.putPayload(cursor, wasm)

proc playCallBlob*(proposalId: uint64; callJson: string): string =
  if callJson.len > MaxCallBytes:
    raise newException(ValueError, "play call exceeds 4096 bytes")
  result = newString(14 + callJson.len)
  var cursor = 0
  result.putHeader(cursor, OpPlayCall)
  result.putU64(cursor, proposalId)
  result.putU32(cursor, uint32(callJson.len))
  result.putPayload(cursor, callJson)

proc statusAckBlob*(mark: uint64): string =
  result = newString(16)
  var cursor = 0
  result.putHeader(cursor, OpStatusAck)
  for _ in 0 ..< 6:
    result.putU8(cursor, 0)
  result.putU64(cursor, mark)

proc lobbyChatBlob*(text: string): string =
  if text.len > MaxLobbyChatBytes:
    raise newException(ValueError, "lobby chat exceeds 512 bytes")
  result = newString(6 + text.len)
  var cursor = 0
  result.putHeader(cursor, OpLobbyChatSend)
  result.putU32(cursor, uint32(text.len))
  result.putPayload(cursor, text)

proc decodeShellPacket*(bytes: string): ShellPacket =
  if bytes.len < 2:
    raise newException(ValueError, "short shell packet header")
  if bytes[1].uint8 != ShellVersion:
    raise newException(ValueError, "unsupported shell packet version")
  var cursor = 2
  case bytes[0].uint8
  of OpPlayContext:
    result.kind = spPlayContext
    result.control = bytes.readPayload(cursor, MaxControlBytes)
    result.context = bytes.readPayload(cursor, MaxContextBytes)
  of OpPlayView:
    result.kind = spPlayView
    result.tick = bytes.readU32(cursor)
    result.control = bytes.readPayload(cursor, MaxControlBytes)
    result.view = bytes.readPayload(cursor, MaxViewBytes)
  of OpLobbyChatBroadcast:
    result.kind = spLobbyChat
    result.ordinal = bytes.readU64(cursor)
    result.tick = bytes.readU32(cursor)
    result.seat = bytes.readU8(cursor)
    result.team = bytes.readU8(cursor)
    result.text = bytes.readPayload(cursor, MaxLobbyChatBytes)
  else:
    raise newException(ValueError, "unknown shell packet opcode")
  if cursor != bytes.len:
    raise newException(ValueError, "trailing bytes in shell packet")
