## One policy seat, hosted in-process instead of in its own container.
##
## This file is copied INTO a policy tree by `sim/build.sh`, so its
## `import decide, ...` binds to that tree's own modules. Two trees built side
## by side therefore get two independent copies of this host, of the policy,
## and of the policy's module-level state — which is what lets one simulator
## binary put build A and build B in the same episode.
##
## It is the websocket-free half of `baseline.nim`'s `runBot`, and it must stay
## a faithful copy of it. Three details carry over verbatim because they live
## in the host loop rather than in the policy, and dropping any of them
## silently changes behaviour:
##
## - **Seat identity.** slot -> team (even Red, odd Blue) -> seat -> role, the
##   same derivation `slotFromUrl` feeds. The engine seats players by join
##   order with the same parity, so seat i here is player i there.
## - **Aim dead reckoning.** The last mask keeps rotating the turret on the
##   server for every elapsed tick until a different one arrives, so the bot
##   advances its own estimate by `rotSign * AimRate * advance` every frame.
## - **The retained mask.** `baseline.nim` only sends on change and the server
##   holds the last one, so a frame the bot skips (lobby, game over, nothing
##   arrived) leaves the previously applied mask in force. `onPacket` returns
##   the retained mask on exactly those paths.

import
  bitworld/profile, bitworld/spriteprotocol,
  std/[math],
  decide, navgrid, protocols, tuning, world

type
  Seat* = ref object
    ## One hosted policy instance: its cross-frame state, its decoder, and the
    ## mask the server is currently applying on its behalf.
    bot: Bot
    client: ProtocolClient
    mask: uint8

proc newSeat*(slot: int): Seat =
  ## Builds the seat that `baseline.nim` would have built for this slot.
  let
    team = (if slot mod 2 == 0: Team.Red else: Team.Blue)
    role = roleForSeat(clamp(slot div 2, 0, 7), team)
    bot = Bot(slot: slot, team: team, role: role)
  bot.seedRng()
  bot.resetTransient()
  Seat(bot: bot, client: initProtocolClient(), mask: 0)

proc reset*(seat: Seat) =
  ## The reconnect path: drop wire state, rebuild the nav grid, forget the
  ## round. Mirrors `baseline.nim`'s post-connect reset.
  seat.client.reset()
  seat.bot.navBuilt = false
  seat.bot.resetTransient()
  seat.mask = 0

proc describe*(seat: Seat): string =
  ## `slot/team/role`, for the run log.
  $seat.bot.slot & "/" & $seat.bot.team & "/" & $seat.bot.role

proc onPacket*(seat: Seat, packet: seq[uint8]): uint8 {.measure.} =
  ## Hands one server frame to the policy and returns the mask to apply.
  ##
  ## The frame arrives as the raw bytes the engine built -- no websocket, so
  ## no blob wrapping. A tree whose protocols.nim predates `deliverPacketBytes`
  ## still builds: the `when compiles` below falls back to wrapping the bytes
  ## into the blob string form `deliverPacket` has always taken.
  ##
  ## A packet that fails to decode is fatal here rather than a reconnect. On
  ## the wire a malformed packet means a damaged stream and `baseline.nim`
  ## reconnects; in process the producer is the engine we just called, so a
  ## decode failure means the two disagree about the protocol -- exactly the
  ## kind of silent wrongness this tool exists to catch, and not something to
  ## paper over by replaying the last mask for the rest of the episode.
  let delivered =
    when compiles(seat.client.deliverPacketBytes(packet)):
      seat.client.deliverPacketBytes(packet)
    else:
      seat.client.deliverPacket(blobFromBytes(packet))
  if not delivered:
    raise newException(
      ValueError, "seat " & seat.describe() & " could not decode a packet " &
      "built by the engine: policy and engine disagree on the protocol")
  if not seat.client.takeFrame():
    return seat.mask
  let advance = max(1, seat.client.frameAdvance)
  seat.bot.tick += advance
  seat.bot.estAim = floorMod(
    seat.bot.estAim + seat.bot.rotSign * AimRate * advance, AimBrads)
  if not seat.client.mapCameraReady:
    seat.bot.resetTransient()          # lobby / game-over interstitial
    return seat.mask
  if not seat.bot.navBuilt and seat.client.walkabilityReady:
    seat.bot.buildNavGrid(seat.client)
  seat.mask = seat.bot.decide(seat.client)
  seat.mask
