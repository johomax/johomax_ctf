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
  flatty/binny,
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
    walkabilitySerial*: int    ## which decoded mask this client holds. Two
                               ## clients on the same nonzero serial hold
                               ## byte-identical masks, so everything derived
                               ## from the mask alone — the whole nav-grid
                               ## build — is shareable between them. 0 until
                               ## a walkability sprite has arrived.
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

type
  MapMemo*[K, V] = object
    ## An association list of things derived from the walkability mask and
    ## nothing else, dropped whole the moment a different mask arrives.
    ##
    ## The whole nav-grid build is map-shaped in this way — the eroded grid,
    ## the cover cells, the overwatch post scan, the static exposure field —
    ## and every seat of an episode derives the same answers from the same
    ## mask. This is where "same mask, same answer" is spelled, ONCE: three
    ## hand-rolled copies of it disagreed about what to do before a map has
    ## arrived, which is the kind of drift a shared shape exists to prevent.
    serial: int
    keys: seq[K]
    vals: seq[V]

template mapMemoized*(
  memo: untyped,
  client: ProtocolClient,
  key: untyped,
  build: untyped
): untyped =
  ## `build`, evaluated once per (walkability mask, key) and copied after.
  ##
  ## `build` is untyped and only touched on a miss, so a caller pays for the
  ## computation exactly when the answer is not already here.
  ##
  ## A serial of 0 means no mask has arrived yet. It needs no special case:
  ## the reset below fires on ANY change, so an entry computed without a map
  ## is dropped the moment a real one lands. (In practice it never happens —
  ## `host.nim` only builds the nav grid behind `walkabilityReady`.)
  block:
    if client.walkabilitySerial != memo.serial:
      memo.serial = client.walkabilitySerial
      memo.keys.setLen(0)
      memo.vals.setLen(0)
    var at = -1
    for i in 0 ..< memo.keys.len:
      if memo.keys[i] == key:
        at = i
        break
    if at < 0:
      memo.keys.add(key)
      memo.vals.add(build)
      at = memo.keys.high
    memo.vals[at]

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
  client.walkabilitySerial = 0
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

proc chatBlob*(text: string): string =
  ## Builds one sprite client chat packet — the shout channel's send half.
  ## The server sanitizes what arrives (printable ASCII, ShoutMaxChars, one
  ## per second per player), so this does not pre-check anything: a message
  ## the server would refuse is a bug in the caller, not something to hide.
  blobFromSpriteChat(text)

proc spritesOffBlob*(): string =
  ## Requests the label-only policy stream before the first server frame.
  result = newString(1)
  result[0] = char(0x87)

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

var
  ## One decoded walkability mask, shared by every client in this module set.
  ## The sprite is identical for all sixteen seats of an episode and costs
  ## ~4.5 ms to decompress; a seat whose payload byte-matches the last decode
  ## copies the mask instead. Pure function of the payload, so sharing cannot
  ## change what any seat observes. In the tournament build one process holds
  ## one seat and this is simply that seat's own last decode.
  sharedWalkWidth = -1
  sharedWalkHeight = -1
  sharedWalkComp: seq[uint8]
  sharedWalkMask: seq[bool]
  sharedWalkSerial = 0
    ## Bumped on every decode that actually ran, i.e. exactly when the shared
    ## mask changes. A client stamps it into `walkabilitySerial`, so equal
    ## nonzero serials prove equal masks — never the reverse, which would let
    ## a stale derivation through. (A seat that re-decodes a mask the shared
    ## copy has since replaced gets a fresh serial for the old mask: a missed
    ## cache hit, never a wrong one.)

proc applySpritePacketBytes(
  client: ProtocolClient,
  bytes: seq[uint8]
): bool {.measure.} =
  ## Applies sprite protocol messages to the retained scene state, decoding
  ## the wire bytes IN PLACE. `parseSpritePacket` first copied the packet
  ## into a string, then materialized every message — a label string and a
  ## compressed-pixels seq per sprite, an object per placement — only for
  ## this loop to read each field once and throw the lot away. The framing
  ## below is the same decode with the same bounds checks (a short read
  ## fails the packet, exactly like parseSpritePacket's checkRead), minus
  ## the allocations.
  ##
  ## Anything below can add, move or drop objects, so the frame index this
  ## packet's predecessor left behind is stale from here on. Invalidate FIRST:
  ## a packet that fails mid-parse still leaves the table partly written, and a
  ## stale index over a mutated table is exactly the kind of quietly-wrong
  ## observation that never announces itself.
  client.frameReady = false
  let size = bytes.len
  var offset = 0
  # Thin wrappers over flatty/binny — the same readers the engine's own
  # decoder uses — so the wire format is spelled in exactly one library.
  template rdU16(off: int): int = int(bytes.readUint16(off))
  template rdI16(off: int): int = int(bytes.readInt16(off))
  template rdU32(off: int): int = int(bytes.readUint32(off))
  while offset < size:
    let messageType = bytes[offset]
    inc offset
    case messageType
    of SpriteMessageSprite:
      if offset + 10 > size:
        return false
      let
        spriteId = rdU16(offset)
        width = rdU16(offset + 2)
        height = rdU16(offset + 4)
        compressedLen = rdU32(offset + 6)
      offset += 10
      if offset + compressedLen > size:
        return false
      let compressedStart = offset
      offset += compressedLen
      if offset + 2 > size:
        return false
      let labelLen = rdU16(offset)
      offset += 2
      if offset + labelLen > size:
        return false
      let label = bytes.readStr(offset, labelLen)
      offset += labelLen
      let kind = classify(label)
      if kind == lkWalkabilityMap:
        # Decompressing this sprite is the single dearest decode of an
        # episode and its payload is the same for every seat: byte-compare
        # against the shared copy before paying for it again.
        if width == sharedWalkWidth and height == sharedWalkHeight and
            compressedLen == sharedWalkComp.len and
            (compressedLen == 0 or equalMem(
              addr bytes[compressedStart],
              addr sharedWalkComp[0], compressedLen)):
          client.walkabilityMask = sharedWalkMask
        else:
          if not decodeWalkabilityPixels(
            width, height, bytes.readStr(compressedStart, compressedLen),
            client.walkabilityMask):
            return false
          sharedWalkWidth = width
          sharedWalkHeight = height
          sharedWalkComp.setLen(compressedLen)
          if compressedLen > 0:
            copyMem(addr sharedWalkComp[0], addr bytes[compressedStart],
              compressedLen)
          sharedWalkMask = client.walkabilityMask
          inc sharedWalkSerial
        client.walkabilitySerial = sharedWalkSerial
        client.walkabilityReady = true
        client.walkabilityWidth = width
        client.walkabilityHeight = height
      client.sprite.ensureSprite(spriteId)
      client.sprite.sprites[spriteId] = SpriteInfo(
        defined: true,
        width: width,
        height: height,
        kind: kind,
        label: label
      )
    of SpriteMessageObject:
      if offset + 11 > size:
        return false
      let
        objectId = rdU16(offset)
        x = rdI16(offset + 2)
        y = rdI16(offset + 4)
        spriteId = rdU16(offset + 9)
      offset += 11
      client.ensureObject(objectId)
      client.sprite.objects[objectId] = ObjectState(
        x: x,
        y: y,
        spriteId: spriteId
      )
      client.markPresent(objectId)
      if objectId == MapObjectId and spriteId == MapSpriteId:
        client.mapCameraReady = true
        client.mapCameraX = -x
        client.mapCameraY = -y
    of SpriteMessageDeleteObject:
      if offset + 2 > size:
        return false
      let objectId = rdU16(offset)
      offset += 2
      if objectId < client.sprite.objects.len:
        client.markAbsent(objectId)
      if objectId == MapObjectId:
        client.mapCameraReady = false
    of SpriteMessageClearObjects:
      for word in client.presentBits.mitems:
        word = 0
      client.mapCameraReady = false
    of SpriteMessageViewport:
      if offset + 5 > size:
        return false
      offset += 5
    of SpriteMessageLayer:
      if offset + 3 > size:
        return false
      offset += 3
    else:
      return false
  true

proc applySpritePacket(
  client: ProtocolClient,
  packet: string
): bool =
  ## The wire entry: unwraps the websocket blob, then decodes in place.
  ## Not `{.measure.}`d: the inner decode is, and measuring the one-line
  ## wrapper too would double-attribute the time in a fluffy profile.
  blobToBytes(packet, client.packetBytes)
  client.applySpritePacketBytes(client.packetBytes)

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
## `receiveLatestFrame`: `deliverPacketBytes` is `acceptPlayerMessage`'s
## BinaryMessage arm, `takeFrame` is the frame-boundary bookkeeping. Both
## paths run the SAME `applySpritePacketBytes` decode — the wire entry only
## unwraps the blob first — so the policy decodes real packets either way and
## there is no second implementation to drift.

proc deliverPacketBytes*(client: ProtocolClient, packet: seq[uint8]): bool =
  ## Feeds one sprite packet in, exactly as a BinaryMessage would arrive —
  ## for a caller that already holds raw bytes (the local simulator, whose
  ## packets never cross a websocket).
  if not client.applySpritePacketBytes(packet):
    return false
  inc client.spritePending
  true

proc deliverPacket*(client: ProtocolClient, packet: string): bool =
  ## `deliverPacketBytes` behind the websocket blob wrapping.
  blobToBytes(packet, client.packetBytes)
  client.deliverPacketBytes(client.packetBytes)

proc takeFrame*(client: ProtocolClient): bool =
  ## Closes the frame, publishing `frameAdvance`. False when nothing arrived.
  client.frameAdvance = 0
  if client.spritePending == 0:
    return false
  client.frameAdvance = client.spritePending
  client.spritePending = 0
  true
