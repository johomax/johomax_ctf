## Sprite-protocol websocket client, trimmed to what the CTF bot reads.
##
## The bot is headless: it never renders a frame, never decodes sprite pixels
## and never sends chat, so the viewer half of this client (framebuffer,
## palette blitting, 4bpp pack/unpack, frame copying) is not here. The one
## payload that IS decoded is the walkability map, which the nav grid is built
## from.

import
  std/[bitops, options, strutils],
  bitworld/[profile, spriteprotocol],
  supersnappy, whisky,
  labelkind

const
  MaxFrameDrain = 128
  MapSpriteId = 1
  MapObjectId = 1

type
  SpriteInfo = object
    ## Sprite metadata, held by VALUE. It used to be a ref, which put a
    ## pointer chase between every object and the label it had to be compared
    ## against — once per object per query, thousands of times a frame.
    defined: bool
    width: int
    height: int
    kind: LabelKind           ## resolved once, here, instead of per query
    label: string             ## only the interpolating families read the tail

  ObjectState = object
    ## Presence is NOT a field here. It lives in `presentBits` instead: a
    ## frame has ~180 objects spread over ~22k ids, so a presence flag inside
    ## the table means reading 22k padded structs to find them. The same
    ## answer as a bitmap is 344 words, which is one cache line per 8 of them.
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
    presentBits: seq[uint64]   ## one bit per object id: is it on screen now
    # The frame index: this frame's objects, resolved against their sprites
    # and grouped by label kind. See `refreshFrame`.
    frameObjects: seq[SpriteObjectInfo]   ## groups laid end to end
    frameStart: array[LabelKind, int32]   ## where each group begins
    frameLen: array[LabelKind, int32]     ## and how long it is
    scanObjects: seq[SpriteObjectInfo]    ## ungrouped, in object-id order
    scanKinds: seq[LabelKind]             ## the kind of each of those
    frameReady: bool           ## false until refreshFrame runs for a frame

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
  client.presentBits.setLen(0)
  client.frameObjects.setLen(0)
  client.scanObjects.setLen(0)
  client.scanKinds.setLen(0)
  client.frameReady = false

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

proc ensureObject(client: ProtocolClient, objectId: int) =
  ## Ensures the object table and the presence bitmap can hold one object id.
  if objectId >= client.sprite.objects.len:
    client.sprite.objects.setLen(objectId + 1)
  let words = (objectId shr 6) + 1
  if words > client.presentBits.len:
    client.presentBits.setLen(words)

proc markPresent(client: ProtocolClient, objectId: int) {.inline.} =
  client.presentBits[objectId shr 6] =
    client.presentBits[objectId shr 6] or (1'u64 shl (objectId and 63))

proc markAbsent(client: ProtocolClient, objectId: int) {.inline.} =
  client.presentBits[objectId shr 6] =
    client.presentBits[objectId shr 6] and not (1'u64 shl (objectId and 63))

proc refreshFrame(client: ProtocolClient) =
  ## Builds this frame's object index: every present object resolved against
  ## its sprite once, grouped by label kind.
  ##
  ## The object table is indexed BY object id and the ids are sparse -- badges
  ## live at 19040+ and sonar rings at 19120+ -- so it runs to ~22k slots to
  ## hold the ~180 objects actually on screen. A scan of it is therefore 99%
  ## empty, and one decision asks for objects about 28 times (21 label lookups
  ## plus the four full iterations, several of them once per team colour).
  ## Paying that as 28 sweeps of the sparse table costs roughly 615k slot
  ## visits and 20 MB of memory traffic per seat per frame -- and every visit
  ## chased a sprite ref and compared a string on the far end of it.
  ##
  ## Paying it here costs one sweep and one sprite lookup per object. What a
  ## query then reads is only the objects that CAN match it: the groups sit
  ## end to end in one array and `frameStart` / `frameLen` bound each one, so
  ## asking for med kits touches the two med kits and nothing else.
  ##
  ## Two things this must not change. Order inside a group stays ascending
  ## object id, which is what the old sweep produced and what the callers that
  ## take the first match depend on -- the counting sort below is stable, so
  ## it holds. And `lkOther` is dropped rather than grouped: nothing scans it,
  ## and a query names a kind, so there is no way to ask for it.
  ##
  ## The counting sort needs the kind totals before it can place anything, so
  ## the objects are gathered once into `scanObjects` and then dealt out. The
  ## alternative is to walk the bitmap twice -- cheap in itself, but the second
  ## walk would repeat the random-access sprite lookup that is the expensive
  ## part of a visit. Two scratch fields buys one walk.
  client.scanObjects.setLen(0)
  client.scanKinds.setLen(0)
  var counts: array[LabelKind, int32]
  if not client.sprite.isNil:
    # Walk the presence bitmap, not the object table: 344 words instead of
    # 22k structs, and the ids come out ascending for free — words in order,
    # and the lowest set bit taken first inside each one.
    for word in 0 ..< client.presentBits.len:
      var bits = client.presentBits[word]
      while bits != 0:
        let objectId = (word shl 6) + countTrailingZeroBits(bits)
        bits = bits and (bits - 1)        # drop the bit just taken
        let objectState = client.sprite.objects[objectId]
        let spriteId = objectState.spriteId
        if spriteId < 0 or spriteId >= client.sprite.sprites.len:
          continue
        # `spr`, not `sprite`: the body of this reads through the field of the
        # same name, and a template shadowing what it dereferences is a trap
        # laid for whoever edits this scope next.
        template spr: untyped = client.sprite.sprites[spriteId]
        if not spr.defined or spr.kind == lkOther:
          continue
        client.scanObjects.add(SpriteObjectInfo(
          objectId: objectId,
          x: objectState.x,
          y: objectState.y,
          width: spr.width,
          height: spr.height,
          spriteId: spriteId
        ))
        client.scanKinds.add(spr.kind)
        inc counts[spr.kind]
  var
    at: array[LabelKind, int32]
    total = 0'i32
  for kind in LabelKind:
    client.frameStart[kind] = total
    client.frameLen[kind] = counts[kind]
    at[kind] = total
    total += counts[kind]
  client.frameObjects.setLen(total)
  for i in 0 ..< client.scanObjects.len:
    let kind = client.scanKinds[i]
    client.frameObjects[at[kind]] = client.scanObjects[i]
    inc at[kind]
  client.frameReady = true

iterator objectsOf*(
  client: ProtocolClient,
  kind: LabelKind
): SpriteObjectInfo =
  ## Present objects of one label kind, in ascending object id.
  if not client.frameReady:
    client.refreshFrame()
  let start = client.frameStart[kind]
  for i in start ..< start + client.frameLen[kind]:
    yield client.frameObjects[i]

proc countOf*(client: ProtocolClient, kind: LabelKind): int =
  ## How many objects of one kind this frame carries.
  if not client.frameReady:
    client.refreshFrame()
  int(client.frameLen[kind])

proc firstOf*(
  client: ProtocolClient,
  kind: LabelKind
): Option[SpriteObjectInfo] =
  ## The lowest-id object of one kind, when there is one.
  if not client.frameReady:
    client.refreshFrame()
  if client.frameLen[kind] == 0:
    return none(SpriteObjectInfo)
  some(client.frameObjects[client.frameStart[kind]])

proc labelOf*(client: ProtocolClient, spriteId: int): lent string =
  ## One sprite's raw label, for the families whose TAIL carries data: an
  ## identity badge's loadout, the own-hp readout, the scoreboard digits.
  ## Finding those objects is the kind's job; only reading them needs this.
  ##
  ## PRECONDITION: `spriteId` must come from an object this frame index handed
  ## out -- `objectsOf` or `firstOf`. Those are the ids `refreshFrame` already
  ## bounds-checked and proved `defined`, so there is no check here and an id
  ## from anywhere else is not safe to pass.
  client.sprite.sprites[spriteId].label

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
  ##
  ## Anything below can add, move or drop objects, so the frame index this
  ## packet's predecessor left behind is stale from here on. Invalidate FIRST:
  ## a packet that fails mid-parse still leaves the table partly written, and a
  ## stale index over a mutated table is exactly the kind of quietly-wrong
  ## observation that never announces itself.
  client.frameReady = false
  blobToBytes(packet, client.packetBytes)
  try:
    for message in parseSpritePacket(client.packetBytes):
      case message.kind
      of spkSprite:
        let sprite = message.sprite
        let kind = classify(sprite.label)
        if kind == lkWalkabilityMap:
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
          kind: kind,
          label: sprite.label
        )
      of spkObject:
        let objectDef = message.objectDef
        client.ensureObject(objectDef.id)
        client.sprite.objects[objectDef.id] = ObjectState(
          x: objectDef.x,
          y: objectDef.y,
          spriteId: objectDef.spriteId
        )
        client.markPresent(objectDef.id)
        if objectDef.id == MapObjectId and objectDef.spriteId == MapSpriteId:
          client.mapCameraReady = true
          client.mapCameraX = -objectDef.x
          client.mapCameraY = -objectDef.y
      of spkDeleteObject:
        let objectId = message.objectId
        if objectId >= 0 and objectId < client.sprite.objects.len:
          client.markAbsent(objectId)
        if objectId == MapObjectId:
          client.mapCameraReady = false
      of spkClearObjects:
        for word in client.presentBits.mitems:
          word = 0
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

## ---------------------------------------------------------------------------
## In-process delivery, for the local simulator (`sim/`).
##
## The simulator links the engine and the policy into one binary and calls the
## server's own `buildSpriteProtocolPlayerUpdates` to get the bytes a socket
## would have carried. These two procs are the websocket-free half of
## `receiveLatestFrame`: `deliverPacket` is `acceptPlayerMessage`'s
## BinaryMessage arm, `takeFrame` is the frame-boundary bookkeeping. Both run
## the SAME `applySpritePacket` the wire path runs, so the policy decodes real
## packets either way and there is no second implementation to drift.

proc deliverPacket*(client: ProtocolClient, packet: string): bool =
  ## Feeds one sprite packet in, exactly as a BinaryMessage would arrive.
  if not client.applySpritePacket(packet):
    return false
  inc client.spritePending
  true

proc takeFrame*(client: ProtocolClient): bool =
  ## Closes the frame, publishing `frameAdvance`. False when nothing arrived.
  client.frameAdvance = 0
  if client.spritePending == 0:
    return false
  client.frameAdvance = client.spritePending
  client.spritePending = 0
  true
