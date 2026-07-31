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
  protocols,
  frame, sense, objective, engage, grenades, act,
  memory, perception, world

proc decide*(bot: Bot, client: ProtocolClient): uint8 =
  ## Core CTF policy for one frame.
  var f = Frame(myTeam: bot.team, enemyTeam: enemy(bot.team))
  let (alive, me) = client.findSelf(f.myTeam)
  if not alive:
    # Dead: inputs are ignored, so there is nothing to steer. But a dead
    # viewer is a GHOST viewer — the server sends no fog at all and streams
    # every living BODY on the map, both teams, so the respawn wait is three
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
    bot.updateTracks(bot.enemies, client.actorsFor(f.enemyTeam))
    bot.updateTracks(bot.mates, client.actorsFor(f.myTeam))
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
  bot.readFlagState(client, f)
  bot.chooseObjective(f)
  bot.selectEngagement(client, f)
  bot.planGrenade(client, f)
  bot.applyPickupDetours(client, f)
  bot.scanNadeDanger(client, f)
  bot.actOn(client, f)
