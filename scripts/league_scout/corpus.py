"""Load the extracted corpus: events + frames, keyed to the player who held each seat."""
import json
import os
import struct

import numpy as np

ROOT = os.path.expanduser("~/.ctf/scout")
MAN = {k.replace(".replay", ""): v for k, v in json.load(open(f"{ROOT}/manifest.json")).items()}

SEAT_BYTES = 10
HDR = 16


def load_frames(bid):
    """-> (meta, arr) where arr is a structured per-tick view."""
    p = f"{ROOT}/fr/{bid}.bin"
    raw = open(p, "rb").read()
    magic = raw[:8]
    assert magic == b"CTFFRM01", magic
    slots, mapw, maph, teams = struct.unpack_from("<HHHH", raw, 8)
    rec = 6 + slots * SEAT_BYTES + teams * 5
    n = (len(raw) - HDR) // rec
    body = np.frombuffer(raw, dtype=np.uint8, offset=HDR, count=n * rec).reshape(n, rec)
    tick = body[:, 0:4].copy().view(np.uint32).ravel()
    phase = body[:, 4]
    seats = body[:, 6:6 + slots * SEAT_BYTES].reshape(n, slots, SEAT_BYTES)
    x = seats[:, :, 0:2].copy().view(np.int16).reshape(n, slots)
    y = seats[:, :, 2:4].copy().view(np.int16).reshape(n, slots)
    aim = seats[:, :, 4]
    hp = seats[:, :, 5]
    lives = seats[:, :, 6]
    flags = seats[:, :, 7]
    fw = seats[:, :, 8]
    wb = seats[:, :, 9]
    fo = 6 + slots * SEAT_BYTES
    fl = body[:, fo:fo + teams * 5].reshape(n, teams, 5)
    flx = fl[:, :, 0:2].copy().view(np.int16).reshape(n, teams)
    fly = fl[:, :, 2:4].copy().view(np.int16).reshape(n, teams)
    carrier = fl[:, :, 4].copy().view(np.int8).reshape(n, teams)
    meta = dict(slots=slots, mapw=mapw, maph=maph, teams=teams, ticks=n)
    return meta, dict(tick=tick, phase=phase, x=x, y=y, aim=aim, hp=hp, lives=lives,
                      flags=flags, fw=fw, wb=wb, flagx=flx, flagy=fly, carrier=carrier)


def load_events(bid):
    rows = []
    with open(f"{ROOT}/ev/{bid}.jsonl") as f:
        for line in f:
            line = line.strip()
            if line:
                rows.append(json.loads(line))
    summary = rows[-1] if rows and rows[-1].get("type") == "summary" else {}
    return [r for r in rows if r.get("type") != "summary"], summary


def seat_player(bid):
    """seat index -> player_name, using API position == replay join slot."""
    m = MAN[bid]
    out = {}
    for p in m["participants"]:
        out[p["position"]] = p["player_name"]
    return out


def episode_ids():
    return sorted(MAN)


def winner(bid):
    """player_name that scored +1, or None on a draw."""
    m = MAN[bid]
    pv2name = {p["policy_version_id"]: p["player_name"] for p in m["participants"]}
    best, bs = None, None
    scores = m.get("scores") or []
    if len(scores) != 2:
        return None
    a, b = scores
    if a["score"] == b["score"]:
        return None
    w = a if a["score"] > b["score"] else b
    return pv2name.get(w["policy_version_id"])


def draw_kind(bid, summary):
    """'timeout' (-1 both) vs 'wipe' (0 both) vs None."""
    m = MAN[bid]
    scores = m.get("scores") or []
    if len(scores) != 2 or scores[0]["score"] != scores[1]["score"]:
        return None
    return "timeout" if scores[0]["score"] < 0 else "wipe"
