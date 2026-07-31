## Malformed-packet tests for the policy's in-place sprite decoder.
##
## `protocols.nim` decodes wire bytes with hand-rolled framing where it used
## to lean on `parseSpritePacket`, whose bounds checks were library code. The
## framing therefore needs its own tests, and the properties worth pinning
## are exactly the ones nothing else exercises:
##
## - a well-formed packet decodes to the expected retained state, through
##   BOTH public entries (raw bytes and the websocket blob form);
## - the framing is prefix-exact: cutting the packet at ANY byte that is not
##   a message boundary must fail the packet, and cutting at any boundary
##   must succeed — swept exhaustively, not sampled;
## - an unknown message type fails the packet;
## - the shared walkability cache never leaks one client's mask to a client
##   that was sent different bytes, and does share when the bytes match.
##
## Compiled by `sim/test_decoder.sh` inside a copy of the policy tree (the
## same layout `build.sh` gives `host.nim`), so `import protocols` below
## binds to the tree under test. Run by `local_sim.py selfcheck`.

import
  std/[options],
  bitworld/spriteprotocol,
  labelkind, labels, protocols

const
  # protocols.nim's private map-camera contract: object id 1 showing sprite
  # id 1 is THE map placement, and its position is the camera.
  MapObjectId = 1
  MapSpriteId = 1
  WalkW = 12
  WalkH = 5

proc walkabilityPixels(walkable: seq[bool]): seq[uint8] =
  ## RGBA pixels for a walkability sprite: alpha > 0 marks a walkable cell,
  ## mirroring the engine's buildWalkabilitySpritePixels contract.
  result = newSeq[uint8](walkable.len * 4)
  for i, w in walkable:
    result[i * 4 + 3] = if w: 255'u8 else: 0'u8

proc checkerMask(phase: int): seq[bool] =
  ## A WalkW x WalkH checkerboard; `phase` flips it, so two phases are
  ## different at every cell.
  result = newSeq[bool](WalkW * WalkH)
  for i in 0 ..< result.len:
    result[i] = (i + phase) mod 2 == 0

proc medKitPixels(): seq[uint8] =
  ## Any small non-empty payload; the decoder never reads sprite pixels
  ## except for the walkability map.
  newSeq[uint8](4 * 3 * 4)

proc buildReferencePacket(mask: seq[bool]): tuple[
  bytes: seq[uint8], boundaries: seq[int]
] =
  ## One packet of every message kind the decoder handles, with the offset
  ## after each message recorded — the only valid truncation points.
  var packet: seq[uint8]
  var boundaries: seq[int] = @[0]      # the empty packet is a valid packet
  template mark() = boundaries.add(packet.len)
  packet.addLayer(0, 0, 1); mark()
  packet.addViewport(0, 320, 200); mark()
  packet.addSprite(7, 4, 3, medKitPixels(), LabelMedKit); mark()
  packet.addSprite(2, WalkW, WalkH, walkabilityPixels(mask),
    LabelWalkabilityMap); mark()
  packet.addObject(400, 10, 12, 3, 0, 7); mark()      # a med kit on screen
  packet.addObject(MapObjectId, 5, 9, 0, 0, MapSpriteId); mark()
  packet.addDeleteObject(400); mark()
  packet.addClearObjects(); mark()                    # drops the camera too
  packet.addObject(MapObjectId, 6, 2, 0, 0, MapSpriteId); mark()
  packet.addObject(401, 30, 40, 3, 0, 7); mark()
  (packet, boundaries)

proc checkDecodedState(client: ProtocolClient, mask: seq[bool]) =
  ## The retained state the reference packet must leave behind.
  doAssert client.takeFrame()
  doAssert client.mapCameraReady
  doAssert client.mapCameraX == -6 and client.mapCameraY == -2
  doAssert client.walkabilityReady
  doAssert client.walkabilityWidth == WalkW
  doAssert client.walkabilityHeight == WalkH
  doAssert client.walkabilityMask == mask
  # Of the two med kit objects, only the post-clear one survives.
  doAssert client.countOf(lkMedKit) == 1
  let kit = client.firstOf(lkMedKit)
  doAssert kit.isSome and kit.get.objectId == 401 and
    kit.get.x == 30 and kit.get.y == 40

when isMainModule:
  let
    maskA = checkerMask(0)
    maskB = checkerMask(1)
    (packet, boundaries) = buildReferencePacket(maskA)

  # A well-formed packet decodes identically through both public entries.
  let viaBytes = initProtocolClient()
  doAssert viaBytes.deliverPacketBytes(packet)
  viaBytes.checkDecodedState(maskA)
  let viaBlob = initProtocolClient()
  doAssert viaBlob.deliverPacket(blobFromBytes(packet))
  viaBlob.checkDecodedState(maskA)

  # Prefix-exact framing, every cut point swept.
  var rejected = 0
  for cut in 0 .. packet.len:
    let ok = initProtocolClient().deliverPacketBytes(packet[0 ..< cut])
    if cut in boundaries:
      doAssert ok, "valid prefix rejected at boundary " & $cut
    else:
      doAssert not ok, "truncated packet accepted at byte " & $cut
      inc rejected

  # An unknown message type fails the packet.
  doAssert not initProtocolClient().deliverPacketBytes(@[0x7f'u8])
  doAssert not initProtocolClient().deliverPacketBytes(packet & @[0x7f'u8])

  # The shared walkability cache isolates clients on different bytes and
  # shares on identical ones. maskB differs from maskA at every cell, and
  # the third client re-sends maskA, exercising the byte-compare hit path.
  let clientB = initProtocolClient()
  doAssert clientB.deliverPacketBytes(buildReferencePacket(maskB).bytes)
  doAssert clientB.walkabilityMask == maskB
  doAssert viaBytes.walkabilityMask == maskA   # untouched by B's decode
  let clientC = initProtocolClient()
  doAssert clientC.deliverPacketBytes(packet)
  doAssert clientC.walkabilityMask == maskA

  echo "decoder ok: ", packet.len, " bytes, ", boundaries.len,
    " boundaries accepted, ", rejected, " truncations rejected"
