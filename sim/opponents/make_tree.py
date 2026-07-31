#!/usr/bin/env python3
"""Materialize coworld-ctf's default player as a policy tree `sim/` can host.

`sim/build.sh` takes two policy trees and links them into one binary, and
`sim/host.nim` is the seat it drops into each of them. That host is
`bot/baseline.nim`'s `runBot` with the socket removed, so a tree it can drive
has to expose exactly what `runBot` used: a `Bot`, `roleForSeat`, `seedRng`,
`resetTransient`, `buildNavGrid`, `decide`, `AimRate`/`AimBrads`, and a
`ProtocolClient` that can be fed packet bytes instead of a websocket.

The upstream default player -- `players/baseline` in coworld-ctf, the bot the
league ships as `baseline` -- is the same game played from one 2850-line
module. It has all of that logic and none of that shape: nothing is exported
(one module needs no export markers), and its `protocols.nim` only ever
receives through `whisky`.

So this script rewrites it into the shape, and does nothing else. Every edit
is an exact string that must match exactly once, and a miss is fatal: an
adapter that silently stopped applying an edit would measure something other
than the policy it names, which is the one failure mode this repository's
whole measurement discipline exists to prevent. The rewrite is:

  * flatten `baseline/{protocols,artlog,taunts}` to the tree root, since
    build.sh copies `*.nim` from one directory;
  * export the eleven symbols and seven `Bot` fields the host touches;
  * cut the file at `proc runBot`, which is the websocket loop the host
    replaces (and everything below it: the `isMainModule` entry point);
  * add `seedRng`, which upstream spells inline in `runBot` as
    `randomize(slot * 7919 + 1)`;
  * add `deliverPacket`/`takeFrame` to its protocol client, the seam
    `bot/baseline/protocols.nim` already has and upstream's does not.

No line of judgement is touched: not a constant, not a branch, not a role.
`--diff` prints every change for eyeballing.

Read sim/opponents/README.md for what the resulting number does and does not
mean -- in particular the fifth simulator/hosted difference this tree adds,
which is that upstream draws from the process-wide RNG and sixteen seats now
share one process.

The player is read out of the engine checkout by default, so the policy and
the rules it is measured under come from the same commit -- `sim/engine.pin`.
Upstream's `players/baseline` moves on its own schedule (29 changed lines of
baseline.nim between the pin and coworld-ctf `main`, the day this was
written), and pairing a newer bot with older rules measures the pairing rather
than the bot.

    sim/opponents/make_tree.py                      # .engine/players/baseline
    sim/opponents/make_tree.py --player ../coworld-ctf/players/baseline
"""

import argparse
import os
import re
import shutil
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ENGINE = os.environ.get("CTF_ENGINE_DIR", os.path.join(REPO, ".engine"))
DEFAULT_PLAYER = os.path.join(ENGINE, "players", "baseline")
DEFAULT_OUT = os.path.join(REPO, ".opponents", "coworld-baseline")

# Symbols `sim/host.nim` names. Left side must appear exactly once in
# baseline.nim; right side is the same declaration, exported.
EXPORTS = [
    ("\n  Team = enum", "\n  Team* = enum"),
    ("\n  Role = enum", "\n  Role* = enum"),
    ("\n  Bot = ref object", "\n  Bot* = ref object"),
    ("\n  AimBrads = 256", "\n  AimBrads* = 256"),
    ("\n  AimRate = 5 ", "\n  AimRate* = 5 "),
    ("\nproc roleForSeat(", "\nproc roleForSeat*("),
    ("\nproc resetTransient(bot: Bot) =", "\nproc resetTransient*(bot: Bot) ="),
    ("\nproc buildNavGrid(bot: Bot, client: ProtocolClient) =",
     "\nproc buildNavGrid*(bot: Bot, client: ProtocolClient) ="),
    ("\nproc decide(bot: Bot, client: ProtocolClient): uint8 =",
     "\nproc decide*(bot: Bot, client: ProtocolClient): uint8 ="),
]

# `Bot` fields the host reads or writes. Exported inside the `Bot` block only,
# so a same-named field on another object cannot be caught by accident.
BOT_FIELDS = ["slot", "team", "role", "tick", "navBuilt", "estAim", "rotSign"]

# The subdirectory imports, flattened. build.sh copies one directory's *.nim.
IMPORTS = [
    ("\n  baseline/protocols,", "\n  protocols,"),
    ("\n  baseline/artlog", "\n  artlog"),
    ("\n  import baseline/taunts", "\n  import taunts"),
]

# Where the websocket half starts. Everything from here down is what the host
# replaces, including the `isMainModule` entry point below it.
CUT_AT = "\nproc runBot(url: string) =\n"

SEED_RNG = '''

proc seedRng*(bot: Bot) =
  ## `runBot`'s own `randomize(slot * 7919 + 1)`, called by the host where
  ## `runBot` called it: once per seat, before the first frame.
  ##
  ## This is `std/random`'s PROCESS-WIDE generator, which is what upstream
  ## uses (`rand` at the jink and steer-jitter sites, `sample` at the shout
  ## sites). Hosted, that process holds one seat; here it holds sixteen, so
  ## the seats share one stream instead of owning one each. Deterministic
  ## either way -- seats are stepped in a fixed order -- but not the same
  ## draws a container would have made. See sim/opponents/README.md.
  randomize(bot.slot * 7919 + 1)
'''

# The seam bot/baseline/protocols.nim carries and upstream's does not: a way
# in for bytes that never crossed a socket. Appended verbatim -- it is the
# same pair, calling upstream's own `applySpritePacket` with the `decodePixels`
# the headless path passes (`receiveLatestFrame(ws, gui = false)`).
PROTOCOL_SEAM = '''

# ---------------------------------------------------------------------------
# Local simulator seam (sim/opponents/make_tree.py).
#
# `receiveLatestFrame` above is the only way into this client, and it wants a
# websocket. The simulator has the packet bytes the engine just built and no
# socket in front of them, so it needs the same door without the transport:
# apply one packet, then close the frame. Nothing else here is touched, and
# the frame accounting is the same arithmetic `receiveLatestFrameInto` does --
# `frameAdvance` is the number of packets that arrived, which in process is
# always exactly one.
# ---------------------------------------------------------------------------

proc deliverPacket*(client: ProtocolClient, packet: string): bool =
  ## Feeds one sprite packet in, as a BinaryMessage would have arrived.
  ## `decodePixels = false` is what the headless bot passes (`gui = false`).
  if not client.applySpritePacket(packet, false):
    return false
  inc client.spritePending
  true

proc takeFrame*(client: ProtocolClient): bool =
  ## Closes the frame, publishing `frameAdvance`. False when nothing arrived.
  client.frameAdvance = 0
  if client.spritePending == 0:
    return false
  client.frameAdvance = client.spritePending
  client.framesDropped = max(0, client.spritePending - 1)
  client.spritePending = 0
  true
'''

SHIM = '''## Import shim: `sim/host.nim` imports the five modules a `bot/baseline`
## tree is layered into, and this tree is one module. Re-exporting `decide`
## under those names is what lets the one host drive both trees unchanged.
import decide
export decide
'''


def edit_once(text, before, after, what):
    """Apply one edit that must match exactly once."""
    n = text.count(before)
    if n != 1:
        sys.exit(
            f"make_tree: {what} matched {n} times, expected exactly 1.\n"
            f"  looking for: {before!r}\n"
            "  Upstream moved under this adapter. Fix the edit rather than "
            "loosening it: an adapter that half-applies measures a policy "
            "nobody described.")
    return text.replace(before, after, 1)


def export_bot_fields(text):
    """Export the host-facing fields, scoped to the `Bot` object block."""
    start = text.index("\n  Bot* = ref object")
    lines = text[start:].split("\n")
    end = len(lines)
    for i, line in enumerate(lines[2:], start=2):
        if line.strip() and not line.startswith("    "):
            end = i
            break
    block = "\n".join(lines[:end])
    rewritten = block
    for field in BOT_FIELDS:
        pattern = re.compile(r"^    %s:" % re.escape(field), re.M)
        found = pattern.findall(rewritten)
        if len(found) != 1:
            sys.exit(f"make_tree: Bot field {field} matched {len(found)} "
                     "times in the Bot block, expected exactly 1")
        rewritten = pattern.sub("    %s*:" % field, rewritten, count=1)
    return text[:start] + rewritten + text[start + len(block):]


def build_tree(player, out, keep_diff):
    policy = os.path.join(player, "baseline.nim")
    modules = os.path.join(player, "baseline")
    for path in (policy, modules):
        if not os.path.exists(path):
            sys.exit(f"make_tree: {path} is missing -- is {player} a coworld-ctf "
                     "players/baseline directory? (the default is the engine "
                     "checkout's, which needs sim/bootstrap.sh first)")

    if os.path.isdir(out):
        shutil.rmtree(out)
    os.makedirs(out)

    # The submodules, flattened and otherwise untouched. protocols.nim gets
    # the simulator seam appended; artlog.nim and taunts.nim are copied so the
    # tree is complete (taunts only compiles under -d:taunt).
    seamed = False
    for name in sorted(os.listdir(modules)):
        if not name.endswith(".nim"):
            continue
        text = open(os.path.join(modules, name)).read()
        if name == "protocols.nim":
            text += PROTOCOL_SEAM
            seamed = True
        open(os.path.join(out, name), "w").write(text)
    if not seamed:
        sys.exit(f"make_tree: no protocols.nim under {modules} to give the "
                 "simulator seam to")

    original = open(policy).read()
    text = original
    for before, after in IMPORTS:
        text = edit_once(text, before, after, "import flatten")
    for before, after in EXPORTS:
        text = edit_once(text, before, after, "export marker")
    text = export_bot_fields(text)

    if text.count(CUT_AT) != 1:
        sys.exit("make_tree: could not find `proc runBot` to cut at")
    text = text[:text.index(CUT_AT)].rstrip("\n") + "\n" + SEED_RNG
    open(os.path.join(out, "decide.nim"), "w").write(text)

    # host.nim imports the five modules a layered tree has. Two of them are
    # real here -- decide.nim and protocols.nim -- and three are shims onto
    # decide, because this policy is one module.
    for name in ("world.nim", "tuning.nim", "navgrid.nim"):
        open(os.path.join(out, name), "w").write(SHIM)

    if keep_diff:
        diff = subprocess.run(
            ["diff", "-u", "--label", "players/baseline/baseline.nim",
             "--label", "decide.nim", "/dev/stdin",
             os.path.join(out, "decide.nim")],
            input=original, capture_output=True, text=True)
        print(diff.stdout)

    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--player", default=DEFAULT_PLAYER,
                        help="coworld-ctf players/baseline directory")
    parser.add_argument("--out", default=DEFAULT_OUT,
                        help="policy tree to write (wiped first)")
    parser.add_argument("--diff", action="store_true",
                        help="print every change made to baseline.nim")
    args = parser.parse_args()

    out = build_tree(os.path.abspath(args.player), os.path.abspath(args.out),
                     args.diff)
    source = subprocess.run(
        ["git", "-C", os.path.abspath(args.player), "rev-parse", "--short", "HEAD"],
        capture_output=True, text=True)
    print(f"wrote {out}")
    print(f"  from   {os.path.abspath(args.player)}"
          + (f" @ {source.stdout.strip()}" if source.returncode == 0 else ""))
    print(f"  files  {' '.join(sorted(os.listdir(out)))}")


if __name__ == "__main__":
    main()
