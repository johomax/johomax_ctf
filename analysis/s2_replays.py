#!/usr/bin/env python3
"""Fetch and mine Paintbot Season 2 replay records.

    analysis/s2_replays.py fetch --since ROUND --limit N
    analysis/s2_replays.py mine DIR [--json-out PATH]

The miner is a standard-library implementation of the engine's CTF replay
format 2. It verifies the shell-record manifest before reporting accepted
play calls. Matching request/results JSON may be either the bundle written by
``fetch`` or raw request and results documents whose filenames contain the
episode-request id.
"""

import argparse
import gzip
import hashlib
import json
import os
import re
import struct
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
import zlib
from collections import Counter, defaultdict
from pathlib import Path


REPO = Path(__file__).resolve().parent.parent
STORE = REPO / "research" / "s2_replays"
LEAGUE = "league_b8fa9b35-ac22-48cf-a03f-07b397aff1c7"
API = "https://softmax.com/api/observatory/v2"
MAGIC = b"COWLDCTF"
REPLAY_FPS = 24
EREQ_RE = re.compile(r"ereq_[0-9a-f-]{36}")


class ReplayError(ValueError):
    """A malformed or unsupported replay."""


class Reader:
    def __init__(self, data, path):
        self.data = data
        self.path = path
        self.offset = 0

    def take(self, size):
        if size < 0 or self.offset + size > len(self.data):
            raise ReplayError(
                f"{self.path}: truncated at byte {self.offset} (need {size})")
        value = self.data[self.offset:self.offset + size]
        self.offset += size
        return value

    def unpack(self, fmt):
        size = struct.calcsize(fmt)
        return struct.unpack(fmt, self.take(size))[0]

    def u8(self):
        return self.unpack("<B")

    def u16(self):
        return self.unpack("<H")

    def i16(self):
        return self.unpack("<h")

    def u32(self):
        return self.unpack("<I")

    def u64(self):
        return self.unpack("<Q")

    def string16(self):
        raw = self.take(self.u16())
        try:
            return raw.decode("utf-8")
        except UnicodeDecodeError as exc:
            raise ReplayError(
                f"{self.path}: invalid UTF-8 at byte {self.offset - len(raw)}") from exc


def replay_bytes(path):
    data = path.read_bytes()
    if data.startswith(MAGIC):
        return data
    for decompress in (gzip.decompress, zlib.decompress):
        try:
            payload = decompress(data)
        except (gzip.BadGzipFile, OSError, zlib.error):
            continue
        if payload.startswith(MAGIC):
            return payload
    raise ReplayError(f"{path}: replay magic does not match")


def replay_tick(replay_time_ms):
    """Invert floor(tick * 1000 / 24), which is one-to-one at 24 Hz."""
    return (replay_time_ms * REPLAY_FPS + 999) // 1000


def read_code_identity(reader):
    kind = reader.u8()
    if kind == 0:
        return {"kind": "module", "sha256": reader.take(32).hex()}
    if kind == 1:
        return {
            "kind": "native",
            "name": reader.string16(),
            "game_version": reader.string16(),
        }
    raise ReplayError(
        f"{reader.path}: unknown code identity {kind} at byte {reader.offset - 1}")


def read_provenance(reader):
    kind = reader.u8()
    if kind == 0:
        base = {
            "kind": "entry",
            "entry_id": reader.string16(),
            "module_sha256": reader.take(32).hex(),
            "emit_tick": reader.u32(),
        }
    elif kind == 1:
        base = {"kind": "default"}
    elif kind == 2:
        base = {"kind": "reflex", "name": reader.string16()}
    else:
        raise ReplayError(
            f"{reader.path}: unknown provenance {kind} at byte {reader.offset - 1}")
    overlays = []
    count = reader.u8()
    if count > 2:
        raise ReplayError(f"{reader.path}: too many annotation overlays")
    for _ in range(count):
        overlays.append({
            "entry_id": reader.string16(),
            "module_sha256": reader.take(32).hex(),
            "accepted_tick": reader.u32(),
            "policy_sha256": reader.take(32).hex(),
        })
    return {"base": base, "overlays": overlays}


def read_annotation(reader):
    tick = reader.u32()
    seat = reader.u8()
    kind = reader.u8()
    if kind == 0:
        return {
            "tick": tick,
            "seat": seat,
            "kind": "intent_change",
            "effective_epoch": reader.u64(),
            "provenance": read_provenance(reader),
            "intent": reader.string16(),
        }
    if kind == 1:
        return {
            "tick": tick,
            "seat": seat,
            "kind": "death",
            "generation": reader.u64(),
        }
    if kind == 2:
        return {
            "tick": tick,
            "seat": seat,
            "kind": "safe_intent",
            "generation": reader.u64(),
            "reason": reader.string16(),
            "intent": reader.string16(),
        }
    if kind == 3:
        return {
            "tick": tick,
            "seat": seat,
            "kind": "play_fault",
            "epoch": reader.u64(),
            "entry_id": reader.string16(),
            "reason": reader.string16(),
        }
    raise ReplayError(
        f"{reader.path}: unknown annotation kind {kind} at byte {reader.offset - 1}")


def read_manifest(reader):
    seat_count = reader.u16()
    if seat_count > 256:
        raise ReplayError(f"{reader.path}: shell manifest has too many seats")
    seats = []
    for expected in range(seat_count):
        seat = reader.u8()
        if seat != expected:
            raise ReplayError(f"{reader.path}: non-contiguous manifest seats")
        seats.append({
            "seat": seat,
            "call_count": reader.u32(),
            "call_chain_sha256": reader.take(32).hex(),
            "annotation_count": reader.u32(),
            "annotation_chain_sha256": reader.take(32).hex(),
        })
    return {
        "seats": seats,
        "transcript_count": reader.u32(),
        "transcript_chain_sha256": reader.take(32).hex(),
    }


def chain_hash(records):
    state = bytes(32)
    for record in records:
        state = hashlib.sha256(state + record).digest()
    return state.hex()


def verify_manifest(path, manifest, call_records, annotation_records,
                    transcript_records):
    if manifest is None:
        raise ReplayError(f"{path}: shell replay manifest is missing")
    seat_count = len(manifest["seats"])
    extra_seats = (set(call_records) | set(annotation_records)) - set(range(seat_count))
    if extra_seats:
        raise ReplayError(f"{path}: shell record seat is outside the manifest")
    for arm in manifest["seats"]:
        seat = arm["seat"]
        calls = call_records.get(seat, [])
        annotations = annotation_records.get(seat, [])
        if (arm["call_count"] != len(calls)
                or arm["call_chain_sha256"] != chain_hash(calls)):
            raise ReplayError(f"{path}: play-call manifest failed for seat {seat}")
        if (arm["annotation_count"] != len(annotations)
                or arm["annotation_chain_sha256"] != chain_hash(annotations)):
            raise ReplayError(f"{path}: annotation manifest failed for seat {seat}")
    if (manifest["transcript_count"] != len(transcript_records)
            or manifest["transcript_chain_sha256"] != chain_hash(transcript_records)):
        raise ReplayError(f"{path}: lobby transcript manifest failed")


def parse_replay(path):
    reader = Reader(replay_bytes(path), path)
    if reader.take(len(MAGIC)) != MAGIC:
        raise ReplayError(f"{path}: replay magic does not match")
    format_version = reader.u16()
    if format_version != 2:
        raise ReplayError(
            f"{path}: replay format {format_version}, expected shell format 2")
    game_name = reader.string16()
    game_version = reader.string16()
    opened_at_ms = reader.u64()
    config_text = reader.string16()
    try:
        config = json.loads(config_text)
    except json.JSONDecodeError as exc:
        raise ReplayError(f"{path}: invalid config JSON") from exc

    calls = []
    annotations = []
    joins = []
    lifecycle = []
    hashes = []
    call_records = defaultdict(list)
    annotation_records = defaultdict(list)
    transcript_records = []
    manifest = None

    while reader.offset < len(reader.data):
        start = reader.offset
        record_type = reader.u8()
        if record_type == 0x01:
            hashes.append({"tick": reader.u32(), "hash": reader.u64()})
        elif record_type == 0x02:
            reader.u32()
            reader.u8()
            reader.u8()
        elif record_type == 0x03:
            time_ms = reader.u32()
            player = reader.u8()
            name = reader.string16()
            slot = reader.i16()
            reader.string16()  # Never retain the bearer-like replay token.
            joins.append({
                "replay_time_ms": time_ms,
                "player": player,
                "name": name,
                "slot": slot,
            })
        elif record_type == 0x04:
            reader.u32()
            reader.u8()
        elif record_type == 0x05:
            reader.u32()
            reader.u8()
            reader.string16()
        elif record_type == 0x06:
            reader.u32()
            reader.u8()
            reader.take(reader.u32())
        elif record_type == 0x10:
            time_ms = reader.u32()
            seat = reader.u8()
            epoch = reader.u64()
            ladder = reader.string16()
            try:
                ladder_json = json.loads(ladder)
            except json.JSONDecodeError as exc:
                raise ReplayError(f"{path}: invalid ladder JSON for seat {seat}") from exc
            entries = []
            entry_count = reader.u8()
            if entry_count > 16:
                raise ReplayError(f"{path}: play call has too many entries")
            for _ in range(entry_count):
                entries.append({
                    "entry_id": reader.string16(),
                    "code": read_code_identity(reader),
                })
            calls.append({
                "replay_time_ms": time_ms,
                "tick": replay_tick(time_ms),
                "seat": seat,
                "epoch": epoch,
                "ladder": ladder,
                "plays": ladder_json.get("plays", []),
                "entries": entries,
            })
            call_records[seat].append(reader.data[start:reader.offset])
        elif record_type == 0x11:
            annotation = read_annotation(reader)
            annotations.append(annotation)
            annotation_records[annotation["seat"]].append(
                reader.data[start:reader.offset])
        elif record_type == 0x12:
            if manifest is not None:
                raise ReplayError(f"{path}: duplicate shell replay manifest")
            manifest = read_manifest(reader)
            if reader.offset != len(reader.data):
                raise ReplayError(f"{path}: shell manifest is not the final record")
        elif record_type == 0x13:
            reader.u32()
            reader.u64()
            reader.u8()
            reader.u8()
            reader.string16()
            transcript_records.append(reader.data[start:reader.offset])
        elif record_type in (0x14, 0x15, 0x16):
            lifecycle.append({
                "kind": {0x14: "disconnect", 0x15: "kick", 0x16: "rebind"}[
                    record_type],
                "replay_time_ms": reader.u32(),
                "seat": reader.u8(),
            })
        elif record_type == 0x17:
            reader.take(16)  # u32 time, u8 kind, u64 ordinal, three u8 fields
        else:
            raise ReplayError(
                f"{path}: unknown replay record 0x{record_type:02x} at byte {start}")

    verify_manifest(path, manifest, call_records, annotation_records,
                    transcript_records)
    if config.get("slots") and len(manifest["seats"]) != len(config["slots"]):
        raise ReplayError(f"{path}: manifest seat count does not match config")
    death_ticks = defaultdict(list)
    for annotation in annotations:
        if annotation["kind"] == "death":
            death_ticks[annotation["seat"]].append(annotation["tick"])
    return {
        "format_version": format_version,
        "game_name": game_name,
        "game_version": game_version,
        "opened_at_ms": opened_at_ms,
        "config": config,
        "joins": joins,
        "calls": calls,
        "death_ticks": dict(death_ticks),
        "lifecycle": lifecycle,
        "final_tick": hashes[-1]["tick"] if hashes else None,
        "hash_count": len(hashes),
        "manifest_verified": True,
    }


def episode_id(path):
    match = EREQ_RE.search(str(path))
    return match.group(0) if match else path.stem


def load_json_index(directory):
    bundles = defaultdict(dict)
    for path in directory.rglob("*.json"):
        try:
            value = json.loads(path.read_text())
        except (OSError, UnicodeDecodeError, json.JSONDecodeError):
            continue
        if not isinstance(value, dict):
            continue
        if isinstance(value.get("request"), dict):
            request = value["request"]
            ident = request.get("id") or episode_id(path)
            bundles[ident]["request"] = request
            if isinstance(value.get("results"), dict):
                bundles[ident]["results"] = value["results"]
            for key in ("round", "round_id"):
                if key in value:
                    bundles[ident][key] = value[key]
        elif isinstance(value.get("participants"), list) and value.get("id"):
            bundles[value["id"]]["request"] = value
        elif (isinstance(value.get("scores"), list)
              and isinstance(value.get("deaths"), list)):
            bundles[episode_id(path)]["results"] = value
    return bundles


def array_value(mapping, key, index):
    values = mapping.get(key) if isinstance(mapping, dict) else None
    if isinstance(values, list) and 0 <= index < len(values):
        return values[index]
    return None


def participant_score(request, index):
    for item in request.get("participant_scores", []):
        if item.get("position") == index:
            return item.get("score")
    return None


def config_slots(parsed, request):
    slots = parsed["config"].get("slots", [])
    if slots:
        return slots
    config = request.get("game_config", {})
    return config.get("slots", []) if isinstance(config, dict) else []


def make_episode(path, bundle, root):
    parsed = parse_replay(path)
    request = bundle.get("request", {})
    results = bundle.get("results", {})
    participants = {
        item["position"]: item for item in request.get("participants", [])
        if isinstance(item, dict) and isinstance(item.get("position"), int)
    }
    slots = config_slots(parsed, request)
    joins = {}
    for join in parsed["joins"]:
        index = join["slot"] if join["slot"] >= 0 else join["player"]
        joins[index] = join["name"]
    calls = defaultdict(list)
    for call in parsed["calls"]:
        calls[call["seat"]].append(call)
    deaths = parsed["death_ticks"]
    result_lengths = [
        len(value) for value in results.values() if isinstance(value, list)
    ]
    candidates = [len(slots), len(participants), len(joins)] + result_lengths
    candidates += [max(calls, default=-1) + 1, max(deaths, default=-1) + 1]
    seat_count = max(candidates, default=0)
    seats = []
    for seat in range(seat_count):
        participant = participants.get(seat, {})
        name = participant.get("policy_name")
        version = participant.get("version")
        policy = f"{name}:v{version}" if name is not None and version is not None else None
        team = array_value(results, "team", seat)
        if team is None and seat < len(slots) and isinstance(slots[seat], dict):
            team = slots[seat].get("team")
        death_count = array_value(results, "deaths", seat)
        seat_deaths = deaths.get(seat, [])
        if death_count is not None:
            alive = death_count == 0
        elif parsed["config"].get("brMode") and parsed["config"].get("lives") == 1:
            alive = not seat_deaths
            death_count = len(seat_deaths)
        else:
            alive = None
        score = array_value(results, "scores", seat)
        if score is None:
            score = participant_score(request, seat)
        seats.append({
            "seat": seat,
            "display_name": joins.get(seat) or participant.get("player_name"),
            "policy_name": name,
            "policy_version": version,
            "policy": policy,
            "team": team,
            "duo_seats": [],
            "alive_at_end": alive,
            "death_count": death_count,
            "death_tick": seat_deaths[0] if seat_deaths else None,
            "death_ticks": seat_deaths,
            "kills": array_value(results, "kills", seat),
            "team_kills": array_value(results, "teamKills", seat),
            "score": score,
            "win": array_value(results, "win", seat),
            "placement": None,
            "calls": sorted(calls.get(seat, []), key=lambda item: (
                item["tick"], item["epoch"])),
        })

    teams = defaultdict(list)
    for seat in seats:
        teams[seat["team"]].append(seat)
    for members in teams.values():
        duo = [member["seat"] for member in members]
        for member in members:
            member["duo_seats"] = duo

    winners = {
        team for team, members in teams.items()
        if team is not None and any(member["win"] is True for member in members)
    }
    if not winners and parsed["config"].get("brMode"):
        surviving = {
            team for team, members in teams.items()
            if team is not None and any(member["alive_at_end"] is True for member in members)
        }
        if len(surviving) == 1:
            winners = surviving
            for member in teams[next(iter(winners))]:
                member["win"] = True
            for team, members in teams.items():
                if team not in winners:
                    for member in members:
                        member["win"] = False

    eliminated = {}
    complete_order = True
    for team, members in teams.items():
        if team in winners:
            continue
        ticks = [member["death_tick"] for member in members]
        if ticks and all(tick is not None for tick in ticks):
            eliminated[team] = max(ticks)
        else:
            complete_order = False
    if winners:
        for team in winners:
            for member in teams[team]:
                member["placement"] = 1
    if complete_order and len(winners) == 1:
        for team, tick in eliminated.items():
            placement = 2 + sum(other > tick for other in eliminated.values())
            for member in teams[team]:
                member["placement"] = placement

    try:
        replay_name = str(path.relative_to(root))
    except ValueError:
        replay_name = str(path)
    ident = request.get("id") or episode_id(path)
    return {
        "id": ident,
        "round": bundle.get("round"),
        "round_id": bundle.get("round_id") or request.get("round_id"),
        "replay": replay_name,
        "request_matched": bool(request),
        "results_matched": bool(results),
        "game_version": parsed["game_version"],
        "final_tick": parsed["final_tick"],
        "manifest_verified": parsed["manifest_verified"],
        "seats": seats,
    }


def aggregate(episodes):
    policies = defaultdict(lambda: {
        "episodes": set(),
        "duos": set(),
        "known_duos": set(),
        "winning_duos": set(),
        "seats": 0,
        "scores": [],
        "known_alive": 0,
        "alive": 0,
        "known_deaths": 0,
        "deaths": 0,
        "known_kills": 0,
        "kills": 0,
        "known_team_kills": 0,
        "team_kills": 0,
        "calls": 0,
        "ladders": Counter(),
    })
    for episode in episodes:
        for seat in episode["seats"]:
            display = re.sub(r" \(\d+\)$", "", seat["display_name"] or "unknown")
            key = seat["policy"] or f"unmatched:{display}"
            item = policies[key]
            item["episodes"].add(episode["id"])
            duo = (episode["id"], seat["team"] if seat["team"] is not None
                   else f"seat:{seat['seat']}")
            item["duos"].add(duo)
            item["seats"] += 1
            if seat["win"] is not None:
                item["known_duos"].add(duo)
                if seat["win"]:
                    item["winning_duos"].add(duo)
            if seat["score"] is not None:
                item["scores"].append(seat["score"])
            if seat["alive_at_end"] is not None:
                item["known_alive"] += 1
                item["alive"] += int(seat["alive_at_end"])
            if seat["death_count"] is not None:
                item["known_deaths"] += 1
                item["deaths"] += seat["death_count"]
            if seat["kills"] is not None:
                item["known_kills"] += 1
                item["kills"] += seat["kills"]
            if seat["team_kills"] is not None:
                item["known_team_kills"] += 1
                item["team_kills"] += seat["team_kills"]
            item["calls"] += len(seat["calls"])
            item["ladders"].update(call["ladder"] for call in seat["calls"])
    output = []
    for policy, item in policies.items():
        seats = item["seats"]
        output.append({
            "policy": policy,
            "episodes": len(item["episodes"]),
            "duos": len(item["duos"]),
            "seats": seats,
            "wins": len(item["winning_duos"]),
            "win_rate": (len(item["winning_duos"]) / len(item["known_duos"])
                         if item["known_duos"] else None),
            "mean_score": (sum(item["scores"]) / len(item["scores"])
                           if item["scores"] else None),
            "alive_rate": (item["alive"] / item["known_alive"]
                           if item["known_alive"] else None),
            "deaths": item["deaths"] if item["known_deaths"] else None,
            "kills": item["kills"] if item["known_kills"] else None,
            "team_kills": (item["team_kills"]
                           if item["known_team_kills"] else None),
            "calls": item["calls"],
            "calls_per_seat": item["calls"] / seats if seats else None,
            "ladders": [
                {"count": count, "ladder": ladder}
                for ladder, count in item["ladders"].most_common()
            ],
        })
    output.sort(key=lambda item: (
        item["mean_score"] is not None,
        item["mean_score"] if item["mean_score"] is not None else float("-inf"),
        item["policy"],
    ), reverse=True)
    return output


def cell(value):
    if value is None:
        return "—"
    return str(value).replace("|", "\\|")


def decimal(value, places=2):
    return "—" if value is None else f"{value:.{places}f}"


def percent(value):
    return "—" if value is None else f"{value * 100:.1f}%"


def outcome(seat):
    pieces = []
    if seat["win"] is True:
        pieces.append("win")
    elif seat["placement"] is not None:
        pieces.append(f"place {seat['placement']}")
    if seat["alive_at_end"] is True:
        pieces.append("alive")
    elif seat["death_tick"] is not None:
        pieces.append(f"died @ {seat['death_tick']}")
    elif seat["death_count"]:
        pieces.append("died (tick unavailable)")
    return ", ".join(pieces) if pieces else "—"


def render(report):
    lines = [
        "# Paintbot Season 2 replay report",
        "",
        (f"Episodes: {len(report['episodes'])}; seats: "
         f"{sum(len(episode['seats']) for episode in report['episodes'])}. "
         "Calls are accepted format-2 `0x10` records; death ticks are "
         "`clear-on-death` annotations. All listed replay manifests verified."),
        "",
        "## Per-policy aggregates",
        "",
        "| policy | episodes | duos | seats | wins | win rate | mean score | kills | deaths | team kills | calls | calls/seat |",
        "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for item in report["policies"]:
        lines.append(
            f"| {cell(item['policy'])} | {item['episodes']} | {item['duos']} | "
            f"{item['seats']} | {item['wins']} | {percent(item['win_rate'])} | "
            f"{decimal(item['mean_score'], 2)} | {cell(item['kills'])} | "
            f"{cell(item['deaths'])} | {cell(item['team_kills'])} | "
            f"{item['calls']} | {decimal(item['calls_per_seat'], 2)} |")

    lines += ["", "## Per-seat episodes", ""]
    for episode in report["episodes"]:
        label = episode["id"]
        if episode["round"] is not None:
            label += f" (round {episode['round']})"
        lines += [
            f"### {label}",
            "",
            (f"Replay `{episode['replay']}`; final tick "
             f"{cell(episode['final_tick'])}; request "
             f"{'matched' if episode['request_matched'] else 'missing'}; results "
             f"{'matched' if episode['results_matched'] else 'missing'}."),
            "",
            "| seat | policy | team / duo | outcome | kills | team kills | score | calls |",
            "|---:|---|---|---|---:|---:|---:|---:|",
        ]
        for seat in episode["seats"]:
            policy = seat["policy"] or f"unmatched ({seat['display_name'] or 'unknown'})"
            duo = (f"{seat['team']} / "
                   f"{','.join(map(str, seat['duo_seats']))}")
            lines.append(
                f"| {seat['seat']} | {cell(policy)} | {cell(duo)} | "
                f"{outcome(seat)} | {cell(seat['kills'])} | "
                f"{cell(seat['team_kills'])} | {cell(seat['score'])} | "
                f"{len(seat['calls'])} |")
        lines += ["", "Accepted calls:", ""]
        episode_calls = [
            (seat["seat"], call) for seat in episode["seats"]
            for call in seat["calls"]
        ]
        episode_calls.sort(key=lambda item: (
            item[1]["tick"], item[0], item[1]["epoch"]))
        if not episode_calls:
            lines.append("- None.")
        for seat, call in episode_calls:
            lines.append(
                f"- seat {seat}, tick {call['tick']}, epoch {call['epoch']}: "
                f"`{call['ladder']}`")
        lines.append("")

    lines += ["## Ladder usage by policy", ""]
    for item in report["policies"]:
        lines += [f"### {item['policy']}", ""]
        if not item["ladders"]:
            lines.append("- No matched accepted calls.")
        for ladder in item["ladders"]:
            lines.append(f"- {ladder['count']} × `{ladder['ladder']}`")
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
            "w", encoding="utf-8", dir=path.parent, delete=False) as handle:
        json.dump(value, handle, indent=2, sort_keys=True)
        handle.write("\n")
        temporary = Path(handle.name)
    os.replace(temporary, path)


def mine(args):
    directory = Path(args.directory).resolve()
    replay_paths = sorted(directory.rglob("*.replay"))
    if not replay_paths:
        raise SystemExit(f"no .replay files under {directory}")
    bundles = load_json_index(directory)
    episodes = []
    for path in replay_paths:
        ident = episode_id(path)
        try:
            episodes.append(make_episode(path, bundles.get(ident, {}), directory))
        except ReplayError as exc:
            raise SystemExit(str(exc)) from exc
    episodes.sort(key=lambda item: (
        item["round"] is None,
        item["round"] if item["round"] is not None else 0,
        item["id"],
    ))
    report = {
        "schema_version": 1,
        "source_directory": str(directory),
        "episodes": episodes,
        "policies": aggregate(episodes),
    }
    output = Path(args.json_out).resolve() if args.json_out else directory / "report.json"
    write_json(output, report)
    print(render(report), end="")
    print(f"wrote {output}", file=sys.stderr)


def token():
    path = Path("~/.softmax/credentials.yaml").expanduser()
    try:
        text = path.read_text()
    except OSError as exc:
        raise SystemExit(f"cannot read {path}: {exc}") from exc
    match = re.search(
        r'''["']?https://softmax\.com/api["']?\s*:\s*["']?([^\s"']+)''', text)
    if not match:
        raise SystemExit(
            f"no https://softmax.com/api token in {path}")
    return match.group(1)


def api_get(path, bearer):
    request = urllib.request.Request(
        API + path,
        headers={
            "Authorization": "Bearer " + bearer,
            "Accept": "application/json",
            "User-Agent": "paintbot-s2-replay-miner/1",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return json.load(response)
    except (urllib.error.URLError, json.JSONDecodeError) as exc:
        raise RuntimeError(f"GET {path} failed: {exc}") from exc


def json_rows(text, noun):
    try:
        value = json.loads(text)
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"coworld returned invalid {noun} JSON") from exc
    if isinstance(value, list):
        return value
    if isinstance(value, dict):
        for key in (noun, "entries", "items", "data"):
            if isinstance(value.get(key), list):
                return value[key]
    raise RuntimeError(f"coworld returned no {noun} list")


def coworld(*arguments):
    environment = os.environ.copy()
    environment.setdefault(
        "UV_CACHE_DIR", str(Path(tempfile.gettempdir()) / "paintbot-replay-uv"))
    command = ["uvx", "coworld@latest", *map(str, arguments)]
    try:
        completed = subprocess.run(
            command, check=True, capture_output=True, text=True, env=environment)
    except FileNotFoundError as exc:
        raise RuntimeError("uvx is not installed") from exc
    except subprocess.CalledProcessError as exc:
        detail = (exc.stderr or exc.stdout or "coworld failed").strip()
        raise RuntimeError(f"{' '.join(command)}: {detail}") from exc
    return completed.stdout


def fetch(args):
    STORE.mkdir(parents=True, exist_ok=True)
    bearer = token()
    try:
        rows = json_rows(coworld(
            "rounds", "-l", LEAGUE, "--limit", max(40, args.limit), "--json"),
            "rounds")
    except RuntimeError as exc:
        raise SystemExit(str(exc)) from exc
    rounds = [
        row for row in rows
        if row.get("status") == "completed"
        and int(row.get("round_number", -1)) >= args.since
    ]
    rounds.sort(key=lambda row: int(row["round_number"]))
    downloaded = 0
    for round_row in rounds:
        if downloaded >= args.limit:
            break
        number = int(round_row["round_number"])
        round_id = round_row["id"]
        round_dir = STORE / f"{number}_{round_id}"
        round_dir.mkdir(parents=True, exist_ok=True)
        remaining = args.limit - downloaded
        try:
            metadata = json_rows(coworld(
                "replays", "-r", round_id, "-o", round_dir,
                "--limit", remaining, "--json"), "replays")
        except RuntimeError as exc:
            raise SystemExit(str(exc)) from exc
        for item in metadata:
            ident = item.get("episode_request_id") or item.get("id")
            if not ident:
                continue
            replay = round_dir / f"{ident}.replay"
            if not replay.exists():
                print(f"warning: coworld did not write {replay}", file=sys.stderr)
                continue
            bundle_path = round_dir / f"{ident}.json"
            if not bundle_path.exists():
                try:
                    request = api_get(f"/episode-requests/{ident}", bearer)
                    results = api_get(
                        f"/episode-requests/{ident}/artifacts/results", bearer)
                except RuntimeError as exc:
                    raise SystemExit(str(exc)) from exc
                write_json(bundle_path, {
                    "round": number,
                    "round_id": round_id,
                    "request": request,
                    "results": results,
                })
            downloaded += 1
            if downloaded >= args.limit:
                break
        print(
            f"round {number}: {len(metadata)} replay(s), {downloaded}/{args.limit} total",
            file=sys.stderr)
    print(f"downloaded {downloaded} replay(s) under {STORE}")
    if downloaded == 0:
        raise SystemExit("no completed replay-bearing episodes matched")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    fetch_parser = commands.add_parser("fetch", help="download replays and metadata")
    fetch_parser.add_argument("--since", type=int, required=True,
                              help="earliest round number")
    fetch_parser.add_argument("--limit", type=int, default=100,
                              help="maximum episodes in total (default: 100)")
    fetch_parser.set_defaults(function=fetch)
    mine_parser = commands.add_parser("mine", help="decode replays and report")
    mine_parser.add_argument("directory")
    mine_parser.add_argument("--json-out",
                             help="JSON output (default: DIR/report.json)")
    mine_parser.set_defaults(function=mine)
    args = parser.parse_args()
    if getattr(args, "limit", 1) < 1:
        parser.error("--limit must be positive")
    args.function(args)


if __name__ == "__main__":
    main()
