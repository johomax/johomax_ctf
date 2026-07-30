## Counts server-received input records carrying ButtonC (bit 128) in a CTF
## .bitreplay. This is the wire-level discriminator for the bitworld
## input-mask truncation that produced the v25-v27 "archive is ~0.4 K/D
## below v9" mystery (see NOTES-provenance.md): a bot built against
## bitworld MASTER can never deliver bit 128, because blobFromSpriteMask
## there ANDs the byte with 0x7f. The replay stores the raw inputs the
## server actually received, so zero here is proof the throws died on the
## client, not proof the bot never tried.
##
## Run it from a Metta-AI/coworld-ctf checkout (it imports the game's
## replay reader): copy this file to <coworld-ctf>/tools/ and
##
##     nim r tools/buttonc_probe.nim <episode>/replay
##
## Measured 2026-07-29, same source, same episode config, one variable
## (the bitworld commit):
##   bitworld 5d229ac (nimby.lock pin): inputs_with_ButtonC=38 of 8608
##   bitworld e47559c (master HEAD):    inputs_with_ButtonC=0  of 8396
import std/[os, strutils], ../src/ctf/replays

let data = loadReplay(paramStr(1))
var total = 0
var withC = 0
var perPlayer: array[16, int]
for inp in data.inputs:
  inc total
  if (inp.keys and 0x80'u8) != 0:
    inc withC
    if int(inp.player) < 16: inc perPlayer[int(inp.player)]
echo "inputs_total=", total, " inputs_with_ButtonC=", withC
echo "per_player_ButtonC=", $(@perPlayer)
