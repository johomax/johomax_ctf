# Hold the line — the first measured improvement

`CTF_LEVER_HOLDLINE`. Do not push more than `HoldLineDepth` (80px) past the
centre line until the scoreboard shows `HoldLineKills` (6) enemy deaths — two
players' worth of lives out of twenty-four — then play normally.

It needs **no communication at all**. The scoreboard is drawn for everyone
with no fog test, so our team's kill total *is* their death count, already
read every frame by `readScoreboard`. This is independent of Shout-Intel and
was measured independently of it.

## Result

v24 against v23: the **same uploaded binary**, lever set by secret env, so
nothing else can differ between the arms. 80 episodes, zero failures.

- **K/D: 1.0645 with the line held vs 0.9394 without**, gap **+0.125**,
  95% CI [+0.037, +0.215]
- Win rate 53.8% vs 46.2% — crosses zero
- Captures 21 vs 27 — crosses zero, and pointing the other way

40 of 40 bootstrap seeds exclude zero, one-sided p ≈ 0.0022, and **both
directions agree in sign** (1.032 vs 0.968 in one, 1.099 vs 0.911 in the
other). That combination — same binary, both directions, every seed — is the
strongest evidence produced in this repo for anything.

## What it is actually buying

K/D moves and captures do not, which is what the mechanism predicts: holding
ground trades capture attempts for a better attrition rate. The bot stops
feeding attackers piecemeal into a full enemy team and instead fights the
opening exchanges from its own half, where its own respawns are close and the
enemy's are far.

Note the capture number moved *down* (21 vs 27, not separable from noise). If
a later build wants captures rather than attrition, this lever is the first
place to look — `HoldLineKills` is the knob, and 6 was picked by reasoning
rather than by measurement. Nobody has swept it.

## Design notes

The clamp is applied to the navigation **goal**, not to the step, so
cover-aware routing, mate spacing and the whole nav stack stay intact and are
simply never aimed deeper than the line. Two exemptions matter:

- **Carriers**, because a carrier runs toward our home anyway and the clamp
  would never bind, but making it explicit keeps a future change honest.
- **While our own flag is out**, because recovering it means chasing a thief
  who is heading exactly where the rule would forbid us to follow. Without
  this the lever would trade a hard-won steal for a permanent deficit.

Roles that already sit behind the line are untouched, so the defence pays
nothing for it.

## Not yet done

v24 is v9's configuration plus the aim deadband fix plus this. It has **not**
been measured against v9 itself, so it is not yet a promotion candidate — the
next run should be v24 against the champion, both directions, to find out
whether the two stack.
