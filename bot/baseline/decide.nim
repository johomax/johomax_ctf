## One frame, start to finish.
##
## `decide` is the policy's front door: the server hands us a frame, this hands
## back an input mask. It owns nothing except the ORDER of the stages, which is
## load-bearing — the engage stage reads the objective's range caps, the pickup
## detours rewrite a target the objective already chose, and the blast scan has
## to run after the grenade plan so it can recognise our own charge preview.
## Everything each stage works out is carried in the `Frame` and nothing else.
##
## The two cases that never reach the stages live here: being dead, which still
## banks a full-map ghost frame, and the tick after respawning, which the aim
## sync picks up.

import
  bitworld/profile,
  protocols,
  frame, sense, royale, objective, engage, grenades, act,
  labelkind, memory, perception, world, tuning

proc decide*(bot: Bot, client: ProtocolClient): uint8 {.measure.} =
  ## Core CTF policy for one frame.
  # The init snapshot can deliver its tiny game marker after the large
  # walkability definition that triggers nav construction. Adopt and re-deal
  # here as soon as the marker is actually indexed; dealtTeams makes this a
  # one-time operation for every seat even though GameTeams is module-wide.
  let statedTeams = client.readGameTeams()
  if statedTeams > 0 and
      (statedTeams != GameTeams or bot.dealtTeams != statedTeams):
    GameTeams = statedTeams
    bot.brMode = bot.brMode or GameTeams > 4
    bot.dealSeat()
    bot.deriveMultiFrame()
  if not bot.brMode and client.isBattleRoyale():
    bot.brMode = true
    bot.dealSeat()
    bot.deriveMultiFrame()
  if not bot.colourLocked:
    # Confirm the dealt colour against the one sprite only WE ever see. The
    # deal is arithmetic off the slot and the stated team count, which is
    # right for every board the league runs — but a config free to name each
    # slot's team can deal them in any order, and a wrong colour makes every
    # scan below blind rather than wrong, which is the failure mode that is
    # hardest to see. Costs one extra self scan per frame until the first
    # alive frame, and nothing after it.
    for c in activeColours():
      if client.findSelf(c).alive:
        bot.colourLocked = true
        if c != bot.colour:
          bot.colour = c
          bot.dealSeat()               # the lock above pins the colour; this
          bot.deriveMultiFrame()       # re-derives everything downstream of it
        break
  var f = Frame(myColour: bot.colour, foeColour: bot.foeColour)
  let (alive, me) = client.findSelf(f.myColour)
  if not alive:
    # Dead: inputs are ignored, so there is nothing to steer. But a dead
    # viewer is a GHOST viewer — the server sends no fog at all and streams
    # every living BODY on the map, every colour, so the respawn wait is three
    # seconds of free full-map positions. Bank them before dropping the frame.
    # Only the "player <color>" bodies are alive: our own body and every other
    # corpse ship under the distinct "corpse <color>" label and never enter a
    # track. We have no self marker while dead, so nothing here may use our
    # position; the track update does not need one.
    #
    # Update BOTH sides, never the enemy alone. The friendly-fire guard only
    # weighs mates seen recently, so refreshing enemies by themselves would
    # leave every mate stale at exactly the moment we respawn holding eight
    # fresh enemy fixes — the guard would wave through every shot and we would
    # cut down our own escorts along the spawn axis.
    #
    # Bodies are all that arrive. The overhead hp bars are gated on ordinary
    # visibility with no ghost exemption, and vision reports nothing at all for
    # a dead viewer, so a ghost frame carries no pips at all. updateTracks
    # reads a missing pip as "no news" and keeps the last value — which, on a
    # track the ghost refreshes every tick, would pin a stale reading in place
    # indefinitely, leaving a wounded enemy that reached a med kit still
    # marked as nearly dead. Drop what we cannot see rather than preserve it.
    var ghostFoes: seq[Actor]
    for foe in bot.foes:
      ghostFoes.add(client.actorsFor(foe))
    bot.updateTracks(bot.enemies, ghostFoes)
    bot.updateTracks(bot.mates, client.actorsFor(f.myColour))
    # The same frame carries both flag banners with the carrier-visibility
    # test bypassed, which is the one thing a living seat most often cannot
    # see. Read it after the tracks, so the carrier's velocity can be
    # attributed against a picture that is complete for once.
    if not bot.brMode:
      bot.readGhostFlags(client, f)
    for t in bot.enemies.mitems:
      t.hp = 0
    for t in bot.mates.mitems:
      t.hp = 0
    # The server drops a carried charge on death; keep our mirror of it in
    # step, or the next life predicts a throw preview that does not exist
    # and waves off a real grenade landing near that phantom point.
    bot.nadeCharge = 0
    bot.firedLast = false
    bot.rotSign = 0
    bot.wasDead = true
    return 0
  f.me = me
  bot.syncAim(client, f)
  bot.updateSenses(client, f)
  if bot.brMode:
    bot.chooseRoyaleObjective(client, f)
  else:
    bot.readFlagState(client, f)
    bot.chooseObjective(f)
  bot.selectEngagement(client, f)
  bot.planGrenade(client, f)
  if not bot.brMode:
    bot.applyPickupDetours(client, f)
  bot.scanNadeDanger(client, f)
  bot.actOn(client, f)
