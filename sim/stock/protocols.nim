import bitworld/spriteprotocol
import stockprotocols

export stockprotocols

proc deliverPacketBytes*(client: ProtocolClient, packet: seq[uint8]): bool =
  try:
    client.applyFrame(blobFromBytes(packet))
    true
  except ValueError:
    false

proc takeFrame*(client: ProtocolClient): bool =
  true
