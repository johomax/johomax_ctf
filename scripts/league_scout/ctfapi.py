"""Shared CTF league API helper — sandbox port of coworld-ctf/tools/ladder/ctfapi.py.

Uses the installed coworld package + the token from `softmax exchange-code`.
"""
import sys
import time

from coworld.api_client import CoworldApiClient  # noqa: E402
from coworld.config import DEFAULT_SUBMIT_SERVER  # noqa: E402

_client = None
_headers = None


def gid(o):
    """Membership records nest league/division/policy_version as objects."""
    return (o or {}).get("id") if isinstance(o, dict) else o


def client():
    global _client, _headers
    if _client is None:
        _client = CoworldApiClient.from_login(server_url=DEFAULT_SUBMIT_SERVER)
        _headers = _client._headers()
    return _client, _headers


def get(path, tries=5):
    c, h = client()
    for i in range(tries):
        try:
            r = c._http_client.get(path, headers=h, timeout=60.0)
            r.raise_for_status()
            return r.json()
        except Exception as e:  # noqa: BLE001
            if i == tries - 1:
                raise
            print(f"  [retry {i+1}/{tries}] {type(e).__name__} on {path}: {e}",
                  file=sys.stderr)
            time.sleep(2 * (i + 1))


def leaderboard(div, include_recent_rounds=32):
    r = get(f"/v2/divisions/{div}/leaderboard?include_recent_rounds={include_recent_rounds}")
    return r if isinstance(r, list) else (r.get("entries") or r.get("rows") or [])


def episodes(round_id, limit=1000):
    """default limit is 50 but a round holds ~110 episodes."""
    r = get(f"/v2/rounds/{round_id}/episodes?limit={limit}")
    if isinstance(r, list):
        return r
    return (r.get("entries") or r.get("episodes") or r.get("data")
            or r.get("items") or [])


def rounds(div, limit=50):
    r = get(f"/v2/divisions/{div}/rounds?limit={limit}")
    if isinstance(r, list):
        return r
    return (r.get("entries") or r.get("rounds") or r.get("data") or r.get("items") or [])
