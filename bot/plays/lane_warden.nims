import std/os

let playDir = currentSourcePath().parentDir()

switch("define", "danger")
include "../play.nims"

switch("out", playDir.parentDir() / ".build" / "lane_warden.wasm")
switch("nimcache", playDir.parentDir() / ".build" / "lane-warden-nimcache")
