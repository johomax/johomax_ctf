## Baseline capture-the-flag bot for Coworld CTF (8v8, classic two-flag,
## dense-cover arena, FOG-OF-WAR full-map vision).
##
## There are no experimental levers and no compile switches: this is exactly
## one policy with one behaviour, and nothing about it is configurable at
## run time. A variant is a source change, built and measured as its own
## image; see README.md.
##
## It also plays the FOUR-TEAM boards (the Paintbot 4ffa variants: four teams
## on generated corner or plus terrain). Every tuned number below was measured
## on the two-team mirrored arena and stays exactly where it was; what the
## four-team boards change is upstream of the tuning. The seat's colour is
## dealt round however many teams the `game teams` marker states rather than
## by red/blue parity; every colour that is not ours is tracked as a threat;
## and the mirrored-arena landmarks swap onto a frame anchored on the stated
## `endzone` marks, since generated terrain has no mirror to compute from.
## See `baseline/world.nim` for that split. A two-team board takes none of
## those paths and is byte-identical to the build before they landed.
##
## Speaks the Bitworld Sprite v1 protocol over a websocket. The observation is
## the FULL map in map coordinates, but entities are fogged: an enemy (and an
## enemy carrying our flag) is only streamed while it sits inside OUR vision —
## a forward cone (half-angle ~60 degrees around our AIM ANGLE, unlimited
## range, walls block) plus a small omnidirectional bubble (~90px). Always
## visible: the static map, BOTH flag pedestals (teammates are fogged too),
## our own flag's state (an empty own pedestal means it is stolen), and
## ourselves via the distinct "self <color> right|left" marker. AIM IS
## DECOUPLED FROM MOVEMENT: a continuous per-player aim angle (0..255 brads,
## 0 = east, counter-clockwise on screen) turns while B (CCW) or Select (CW)
## is held at ~5 brads/tick; the d-pad never touches it. The aim drives the
## gun, the vision cone, and the sprite flip, so pointing it is THE core
## tactical decision. The bot keeps a persistent world model on top of that:
##
## - **Nav grid**: the full walkability mask normally arrives once at init;
##   pinned BR can validate and expand its embedded mask when the hosted wire
##   drops the oversized sprite. We erode it by the player footprint into an
##   8px cell grid and run a cost field (Dijkstra) to any goal, then follow the
##   path with waypoint lookahead.
## - **Cover model**: walkable cells adjacent to an obstacle are "cover
##   cells". Cells a remembered enemy could shoot into (range + coarse LOS)
##   get a soft path cost, so movement naturally advances cover-to-cover and
##   keeps obstacles between us and known threats.
## - **Flag model** (two flags): pedestals are STATIC known positions and
##   pedestal flags are never fogged. Only OUR team can carry the enemy flag,
##   so the "<enemy color> heart" sprite is always visible and fully describes
##   our attack (pedestal / on me / on a mate). Only the enemy can carry OUR
##   heart: the "<my color> heart" sprite on its pedestal means safe, visible
##   off-pedestal is a live thief fix, and ABSENT means stolen by a fogged
##   carrier somewhere between our pedestal and its home edge.
## - **Memory**: visible players are matched to tracks (position, velocity,
##   last-seen tick) that persist through fog, and the last thief fix guides
##   the hunt after the carrier fogs out.
## - **Roles** (deterministic from the per-team seat, 8 seats): a mid QUAD
##   races lanes to the ENEMY pedestal, two flankers route wide and hit the
##   pocket from behind, one overwatch sniper holds a shielded cover post
##   whose peek cell owns the longest firing line over mid — under fog a lane
##   watcher SEES map-wide down its open lane, so overwatch is also the radar
##   — and one home defender guards the choke before our pedestal. The attack
##   wave is deliberately six strong: with no global flag tracking, a carrier
##   that slips the contest is hard to reacquire, so committed offense turns
##   steals into captures. While our flag is stolen the back line hunts the
##   thief along its predicted route toward ITS home edge; attackers press on
##   — captures are instant wins both ways, so the race stays on.
## - **Turret controller**: the bot dead-reckons its own aim (spawn aim is
##   toward the enemy side; each held rotate button turns it 5 brads/tick)
##   and bounds it every frame by the rotation step the server renders our own
##   soldier at, which pins the true aim to a 16-brad bucket.
##   Each tick it outputs the rotate button that traverses toward the desired
##   aim by the shortest arc, and fires only when the bullet corridor
##   (~14px half-width) covers the target at its range.
## - **Scanning**: units holding a position (overwatch posts, the defender's
##   choke, cooldown ducks) sweep the aim back and forth across the watch arc
##   with genuine rotate-button sweeps, raking the vision cone over it while
##   standing perfectly still. On the move, the aim leads the movement
##   direction when no target demands it, so attackers watch down-lane.
## - **Peek-and-shoot**: the default combat mode. With the gun up and a
##   remembered enemy blocked by a wall, PRE-LAY the aim on the firing line
##   while stepping sideways to the nearest cell that opens it — the shot is
##   ready the moment the ray clears; during the 12-tick cooldown, duck
##   behind the nearest cover that breaks the threat's line and hold there.
## - **Fire discipline**: the bullet is a corridor hitscan along the aim, so
##   the fire gate is geometric: shoot when the aim error's perpendicular
##   miss at the target's range is inside the corridor. Skip targets with a
##   remembered teammate near the fire axis (friendly fire is on; the server
##   kills the NEAREST player in the corridor).
##
## Coordinate model: the map object sits at (0, 0), so object positions ARE
## map coordinates; we find ourselves via the self marker. Only a fresh A
## press fires, and the aim angle locks at the pull (the bullet leaves after
## a short windup), so we stop rotating on the tick we pull.
##
## ## Where the code lives
##
## This file is only the process: connect, advance the clock, hand each frame
## to the policy, send the mask that comes back. The policy itself is
## `baseline/`, layered so that nothing below can reach anything above it:
##
## - `baseline/labels.nim` — the sprite-label vocabulary, vendored verbatim
##   from the engine. Every string the bot scans for comes from here.
## - `baseline/labelkind.nim` — those labels as an enum, resolved once per
##   sprite definition so that no frame ever compares a label string, plus
##   `Colour`: the wire's sixteen team colours, in the engine's seat-deal order.
## - `baseline/protocols.nim` — the websocket sprite-protocol client, trimmed
##   to the headless half, plus the compile-time bitworld-pin tripwire and the
##   socket-free delivery seam the local simulator feeds packets through.
## - `baseline/tuning.nim` — every tuned constant, and the episode parameters
##   the bot adopts off the wire: the map dimensions and the team count.
## - `baseline/geometry.nim` — map-space vectors and the brad angle system.
## - `baseline/world.nim` — the two-sided strategy frame, roles, tracks, the
##   `Bot` state that survives a frame, and the arena's landmarks in their
##   two forms: mirrored on a two-team board, endzone-anchored on a
##   four-team one.
## - `baseline/perception.nim` — reading the wire: the self marker, identity
##   badges, hp pips, the scoreboard, the heard shot landings, and the init
##   markers stating the team count and every team's endzone.
## - `baseline/memory.nim` — track matching and fog-honest pickup memory.
## - `baseline/fov.nim` — the engine's fog occlusion model rebuilt from the
##   walkability mask, for the one-way visibility term in post scoring
##   (inert while tuning's OneWayBonus is 0.0).
## - `baseline/grid.nim`, `posts.nim`, `navgrid.nim` — the walkability mask,
##   the cover posts derived from it, and the cost field the bot walks on.
## - `baseline/tactics.nim` — the shared judgement calls: could this fight
##   happen, where will contact come from, which lane runs home, whose shot is
##   safe to take.
## - `baseline/frame.nim` — the per-frame decision context the stages share.
## - `baseline/sense.nim`, `objective.nim`, `engage.nim`, `grenades.nim`,
##   `act.nim` — the five stages of a decision, in that order.
## - `baseline/decide.nim` — the front door that runs them.

import
  std/[math, os, strutils],
  baseline/[decide, navgrid, perception, protocols, tuning, whisky_fixed, world]

proc slotFromUrl(url: string): int =
  ## Reads the `slot` query parameter from the websocket URL.
  let key = "slot="
  let at = url.find(key)
  if at < 0:
    return 0
  var i = at + key.len
  var digits = ""
  while i < url.len and url[i] in {'0' .. '9'}:
    digits.add(url[i])
    inc i
  if digits.len == 0: 0 else: digits.parseInt()

proc runBot(url: string) =
  ## Connects, then loops frames forever, reconnecting on disconnect.
  ##
  ## The seat is dealt twice. Here, on two-team parity, because that is all a
  ## process knows before a frame arrives; then again inside the nav-grid
  ## build, once the `game teams` marker has stated how many teams share the
  ## board — which is the deal that is actually right on a four-team one.
  ## `resetTransient` runs the second deal too, so nothing here has to.
  let
    slot = slotFromUrl(url)
    team = (if slot mod 2 == 0: Team.Red else: Team.Blue)
    role = roleForSeat(clamp(slot div 2, 0, 7), team)
    endpoint = ensureWsPath(url, WebSocketPath)
  let bot = Bot(slot: slot, team: team, role: role)
  bot.seedRng()
  bot.resetTransient()
  echo "baseline slot=", slot, " team=", team, " colour=", bot.colour,
    " role=", role, " -> ", endpoint
  let client = initProtocolClient()
  var everConnected = false
  while true:
    try:
      let ws = newWebSocket(endpoint)
      ws.send(spritesOffBlob(), BinaryMessage)
      echo "connected ", endpoint
      everConnected = true
      client.reset()
      bot.navBuilt = false
      bot.resetTransient()
      var lastMask = 0xff'u8
      while true:
        if not client.receiveLatestFrame(ws):
          continue
        let advance = max(1, client.frameAdvance)
        bot.tick += advance
        # Dead-reckon the aim: the last sent mask keeps rotating on the
        # server for every elapsed sim tick until we change it.
        bot.estAim = floorMod(
          bot.estAim + bot.rotSign * AimRate * advance, AimBrads)
        if not client.mapCameraReady:
          bot.resetTransient()             # lobby / game-over interstitial
          continue
        if not bot.navBuilt and not client.walkabilityReady:
          discard client.ensureBattleRoyaleWalkability()
        if not bot.navBuilt and client.walkabilityReady:
          bot.buildNavGrid(client)
          echo "nav built tick=", bot.tick, " map=", client.walkabilityWidth, "x",
            client.walkabilityHeight, " teams=", GameTeams, " colour=", bot.colour,
            " role=", bot.role
        let mask = bot.decide(client)
        if mask != lastMask:
          ws.send(inputBlob(mask), BinaryMessage)
          lastMask = mask
        # The shout channel's send half. Unlike the mask, a chat packet is an
        # event rather than a retained state, so it is sent whenever the
        # policy produced one and never repeated. Empty until ShoutMode is on.
        let shout = bot.takeShout()
        if shout.len > 0:
          ws.send(chatBlob(shout), BinaryMessage)
    except Exception as e:
      if everConnected:
        # The game ended and the server went away: exit so the episode
        # runner sees a clean player shutdown.
        echo "game over, exiting: ", e.msg
        quit(0)
      echo "connect retry: ", e.msg
      sleep(250)

when isMainModule:
  let url = getEnv("COWORLD_PLAYER_WS_URL", getEnv("COGAMES_ENGINE_WS_URL"))
  if url.len == 0:
    raise newException(ValueError, "COWORLD_PLAYER_WS_URL is required.")
  runBot(url)
