## The per-frame decision context.
##
## `decide` used to be one proc a thousand lines long whose locals were its
## only interface: what the sensors read, what the flags were doing, where we
## were walking, what we were shooting at and which buttons came out were all
## the same pile of `var`s. This object is that pile, named, so the policy can
## be read and changed one stage at a time.
##
## It is deliberately memoryless. Everything that has to survive to the next
## frame lives on `Bot`; a `Frame` is built from nothing at the top of every
## tick and thrown away at the bottom, so nothing here can quietly become
## state. The stages fill it in the order they are listed below, and each one
## sets its own starting values (`engage = -1`, `desiredAim = -1`, and so on)
## exactly where the original set them.

import geometry, world

type
  Frame* = object
    # Identity and position, worked out before any stage runs.
    myColor*, enemyColor*: string
    me*: Vec                     ## our own body, from the self marker

    # sense: what the wire says about us and the field this frame.
    hasPlasma*: bool             ## carrying the spray can (it replaces the gun)
    hasShield*: bool             ## carrying the endzone shield (6 hp, 3x cooldown)
    shotReady*: bool             ## the fire icon is up and the gun is ours
    seenEnemies*: seq[Actor]     ## enemies inside our vision RIGHT NOW
    seenMates*: seq[Actor]       ## teammates inside our vision right now

    # sense: the two flags.
    stealTarget*: Vec            ## the enemy pedestal, a static known position
    ownHome*: Vec                ## our own pedestal
    iCarry*: bool                ## the enemy flag is on US
    mateCarry*: bool             ## a teammate is running it (possibly fogged)
    mateCarryPos*: Vec           ## where that teammate is, seen or dead-reckoned
    ownStolen*: bool             ## our own flag is off its pedestal

    # objective: where we are walking.
    pushOut*: bool               ## the posts are broken: go and win by capture
    target*: Vec                 ## the movement goal, before path steering

    # engage: what we are fighting, and how far we are willing to reach.
    rushing*: bool               ## a mid racing for the steal, guns secondary
    pocketRush*: bool            ## the closest attacker, committed to the touch
    maxEngage*: float            ## engage range cap for this role and errand
    engage*: int                 ## index into bot.enemies, -1 = nothing shootable
    engageD*: float              ## its range
    engagePrio*: float           ## its priority score (distance plus traverse)
    aim*: Vec                    ## the lead point on the engage target
    haveBlocked*: bool           ## a fresh track sits behind a wall
    blockedAim*: Vec             ## the lead point on it, for the peek pre-lay
    blockedD*: float             ## its range
    nearThreat*: int             ## nearest enemy worth ducking, -1 = none
    nearThreatD*: float          ## its range

    # grenades: the planned throw, and somebody else's incoming one.
    carryingNade*: bool
    nadeAim*: int                ## bearing of the planned lob, -1 = no throw
    nadeThrowD*: float           ## how far it has to fly, which sets the charge
    nadeDanger*: bool            ## a blast is about to land on us
    nadeDangerFrom*: Vec         ## where, so we can run the other way

    # act: the buttons, before they are packed into the input mask.
    moveMask*: uint8             ## d-pad bits
    desiredAim*: int             ## where the turret should point, -1 = nowhere
    deadband*: int               ## how close the aim has to be before it stops
    wantFire*: bool              ## pull A this tick
    acted*: bool                 ## a combat branch already claimed the frame
    holdStill*: bool             ## stand perfectly still (scanning, charging)
    nadeC*: bool                 ## hold C this tick to keep charging
