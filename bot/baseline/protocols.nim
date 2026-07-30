## Sprite-protocol websocket client, trimmed to what the CTF bot reads.
##
## The bot is headless: it never renders a frame, never decodes sprite pixels
## and never sends chat, so the viewer half of this client (framebuffer,
## palette blitting, 4bpp pack/unpack, frame copying) is not here. The one
## payload that IS decoded is the walkability map, which the nav grid is built
## from.

import
  std/[options, strutils],
  bitworld/[profile, spriteprotocol],
  supersnappy, whisky,
  labels

const
  MaxFrameDrain = 128
  MapSpriteId = 1
  MapObjectId = 1

type
  SpriteInfo = ref object
    defined: bool
    width: int
    height: int
    label: string

  ObjectState = object
    present: bool
    x: int
    y: int
    spriteId: int

  SpriteState = ref object
    sprites: seq[SpriteInfo]
    objects: seq[ObjectState]

  SpriteObjectInfo* = object
    objectId*: int
    x*: int
    y*: int
    width*: int
    height*: int
    spriteId*: int            ## which sprite the object currently shows;
                              ## pre-rotated sprite pools encode an angle in
                              ## the id itself, which the label cannot carry

  ProtocolClient* = ref object
    sprite: SpriteState
    spritePending: int
    frameAdvance*: int
    mapCameraReady*: bool
    mapCameraX*: int
    mapCameraY*: int
    walkabilityReady*: bool
    walkabilityWidth*: int
    walkabilityHeight*: int
    walkabilityMask*: seq[bool]
    packetBytes: seq[uint8]

proc initSpriteState(): SpriteState =
  ## Builds the initial sprite protocol state.
  SpriteState()

proc initProtocolClient*(): ProtocolClient =
  ## Builds protocol state for one websocket connection.
  ProtocolClient(sprite: initSpriteState())

proc reset*(client: ProtocolClient) =
  ## Clears queued wire data between connections.
  client.sprite = initSpriteState()
  client.spritePending = 0
  client.frameAdvance = 0
  client.mapCameraReady = false
  client.mapCameraX = 0
  client.mapCameraY = 0
  client.walkabilityReady = false
  client.walkabilityWidth = 0
  client.walkabilityHeight = 0
  client.walkabilityMask.setLen(0)

proc ensureWsPath*(url: string, defaultPath: string): string =
  ## Inserts `defaultPath` when a websocket URL has no path.
  let scheme = url.find("://")
  let start =
    if scheme < 0:
      0
    else:
      scheme + 3
  for i in start ..< url.len:
    case url[i]
    of '/':
      return url
    of '?', '#':
      return url[0 ..< i] & defaultPath & url[i .. ^1]
    else:
      discard
  url & defaultPath

static:
  # Compile-time tripwire for an input-mask truncation that is otherwise
  # invisible: bitworld master ANDs the input byte with 0x7f, deleting
  # ButtonC (bit 128, the grenade charge/throw) from every packet while
  # leaving it structurally valid — no error, no log line, just a bot that
  # can never throw, at a cost of roughly 0.4 K/D. Only the lineage pinned
  # in nimby.lock (5d229ac, branch daveey/hd-client-pin) passes all 8 bits.
  # If this assert fires, the build is using the wrong bitworld commit.
  doAssert blobFromSpriteMask(0x80'u8)[1] == char(0x80'u8),
    "this bitworld strips input bit 128 (ButtonC / grenade throw) — " &
    "wrong engine commit; sync nimby.lock (bitworld 5d229ac, branch " &
    "daveey/hd-client-pin) instead of cloning master"

proc inputBlob*(mask: uint8): string =
  ## Builds one sprite player input packet.
  blobFromSpriteMask(mask)

proc ensureSprite(state: SpriteState, spriteId: int) =
  ## Ensures the sprite table can hold one sprite id.
  if spriteId >= state.sprites.len:
    state.sprites.setLen(spriteId + 1)

proc ensureObject(state: SpriteState, objectId: int) =
  ## Ensures the object table can hold one object id.
  if objectId >= state.objects.len:
    state.objects.setLen(objectId + 1)

proc spriteInfo(state: SpriteState, spriteId: int): SpriteInfo =
  ## Returns sprite metadata or nil for an unknown sprite.
  if spriteId >= 0 and spriteId < state.sprites.len:
    return state.sprites[spriteId]

proc spriteObjectsWithLabel*(
  client: ProtocolClient,
  label: string
): seq[SpriteObjectInfo] =
  ## Returns present sprite objects whose sprite label matches exactly.
  if client.sprite.isNil:
    return
  for objectId, objectState in client.sprite.objects:
    if not objectState.present:
      continue
    let sprite = client.sprite.spriteInfo(objectState.spriteId)
    if sprite.isNil or not sprite.defined or sprite.label != label:
      continue
    result.add(SpriteObjectInfo(
      objectId: objectId,
      x: objectState.x,
      y: objectState.y,
      width: sprite.width,
      height: sprite.height,
      spriteId: objectState.spriteId
    ))

iterator spriteObjects*(
  client: ProtocolClient
): tuple[
  objectId: int,
  x: int,
  y: int,
  width: int,
  height: int,
  label: string
] =
  ## Iterates present sprite objects with their sprite metadata.
  if not client.sprite.isNil:
    for objectId, objectState in client.sprite.objects:
      if not objectState.present:
        continue
      let sprite = client.sprite.spriteInfo(objectState.spriteId)
      if sprite.isNil or not sprite.defined:
        continue
      yield (
        objectId: objectId,
        x: objectState.x,
        y: objectState.y,
        width: sprite.width,
        height: sprite.height,
        label: sprite.label
      )

proc decodeWalkabilityPixels(
  width,
  height: int,
  compressed: string,
  mask: var seq[bool]
): bool {.measure.} =
  ## Decodes the sprite protocol walkability payload into a bool mask.
  var rawPixels = ""
  try:
    rawPixels = supersnappy.uncompress(compressed)
  except CatchableError:
    return false
  if width <= 0 or height <= 0 or rawPixels.len != width * height * 4:
    return false
  mask.setLen(width * height)
  for i in 0 ..< mask.len:
    mask[i] = rawPixels[i * 4 + 3].uint8 > 0
  true

proc applySpritePacket(
  client: ProtocolClient,
  packet: string
): bool {.measure.} =
  ## Applies sprite protocol messages to the retained scene state.
  blobToBytes(packet, client.packetBytes)
  try:
    for message in parseSpritePacket(client.packetBytes):
      case message.kind
      of spkSprite:
        let sprite = message.sprite
        if sprite.label == LabelWalkabilityMap:
          if not decodeWalkabilityPixels(
            sprite.width,
            sprite.height,
            blobFromBytes(sprite.compressedPixels),
            client.walkabilityMask
          ):
            return false
          client.walkabilityReady = true
          client.walkabilityWidth = sprite.width
          client.walkabilityHeight = sprite.height
        client.sprite.ensureSprite(sprite.id)
        client.sprite.sprites[sprite.id] = SpriteInfo(
          defined: true,
          width: sprite.width,
          height: sprite.height,
          label: sprite.label
        )
      of spkObject:
        let objectDef = message.objectDef
        client.sprite.ensureObject(objectDef.id)
        client.sprite.objects[objectDef.id] = ObjectState(
          present: true,
          x: objectDef.x,
          y: objectDef.y,
          spriteId: objectDef.spriteId
        )
        if objectDef.id == MapObjectId and objectDef.spriteId == MapSpriteId:
          client.mapCameraReady = true
          client.mapCameraX = -objectDef.x
          client.mapCameraY = -objectDef.y
      of spkDeleteObject:
        let objectId = message.objectId
        if objectId >= 0 and objectId < client.sprite.objects.len:
          client.sprite.objects[objectId].present = false
        if objectId == MapObjectId:
          client.mapCameraReady = false
      of spkClearObjects:
        for item in client.sprite.objects.mitems:
          item.present = false
        client.mapCameraReady = false
      of spkViewport, spkLayer:
        discard
  except SpriteProtocolError:
    return false
  true

proc acceptPlayerMessage(
  ws: WebSocket,
  message: Message,
  client: ProtocolClient
) {.measure.} =
  ## Handles one websocket message and updates the active parser.
  case message.kind
  of BinaryMessage:
    if not client.applySpritePacket(message.data):
      raise newException(ValueError, "Malformed sprite protocol packet.")
    inc client.spritePending
  of Ping:
    ws.send(message.data, Pong)
  of TextMessage, Pong:
    discard

proc receiveLatestFrame*(
  client: ProtocolClient,
  ws: WebSocket
): bool {.measure.} =
  ## Blocks for wire data, then drains whatever else has already arrived, so
  ## `frameAdvance` reports how many sim ticks this frame covers.
  client.frameAdvance = 0
  if client.spritePending == 0:
    let firstMessage = ws.receiveMessage(-1)
    if firstMessage.isNone:
      return false
    ws.acceptPlayerMessage(firstMessage.get, client)

  var drained = 0
  while drained < MaxFrameDrain:
    let message = ws.receiveMessage(0)
    if message.isNone:
      break
    ws.acceptPlayerMessage(message.get, client)
    inc drained

  if client.spritePending == 0:
    return false
  client.frameAdvance = client.spritePending
  client.spritePending = 0
  true
