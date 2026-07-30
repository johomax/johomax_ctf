#!/usr/bin/env python3
"""The auto-research loop: propose, build, measure, promote, repeat.

One iteration takes one experiment from `scripts/experiments.py`, builds it as
its own image, puts it in the same episodes as the current baseline build in
both directions, pools the mirror, and either promotes it (commit the source
change, submit the policy with --auto-champion always) or throws it away. Then
it asks the catalogue what the result suggests trying next and goes again.

Everything expensive about this problem is a measurement-discipline problem,
so the loop is built around the rules in README.md rather than around the
search:

- **The control is a build, not a memory.** Every comparison is a hosted
  head-to-head between two images running in the same episodes at the same
  moment, because the league drifts about thirty times the concurrent
  reproducibility over a few hours.
- **Both directions, always**, pooled by `pool_h2h.py` with the seats read out
  of the episode participants. RED won 70.9% of episodes in a measured mirror
  whatever build held it; a one-direction run reads that as a build effect.
- **A promotion needs a confirmation run.** A marginal call at 80 episodes is
  not a call: a "regression" whose CI barely excluded zero at 80 came back
  level at 160. Anything that separates positive at stage 1 is re-run and
  decided on the pooled ~160.
- **K/D is necessary and not sufficient.** A change can be level on K/D and a
  decisive regression on wins and captures, and the league scores wins, so a
  promotion also requires that neither of those separates negative.
- **A silently unapplied edit is the failure mode to fear**, not a crashing
  one. Every edit must match exactly once, the built image must contain a real
  binary at /bin/baseline, and that binary must play a local episode before a
  single league episode is bought.

State lives in `research/state.json` and the record in `research/LEDGER.md`.
Both are committed: the ledger is the loop's memory, and an experiment whose
result nobody wrote down will be run again.

Usage:
  python scripts/autoresearch.py [--max-experiments=N] [--episodes=40]
                                 [--dry-run] [--once]
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import experiments as cat  # noqa: E402
from pool_h2h import verdict  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
BOT = ROOT / "bot"
RESEARCH = ROOT / "research"
STATE_PATH = RESEARCH / "state.json"
LEDGER_PATH = RESEARCH / "LEDGER.md"

BIN = os.environ.get("COWORLD_BIN", "coworld")
LEAGUE = "league_3243d905-d32d-4ec6-978b-fa94751d4a37"
POLICY_NAME = os.environ.get("CTF_POLICY_NAME", "jordan-ctf-candidate")
WORK = Path(os.environ.get(
    "CTF_WORK_DIR",
    "/tmp/claude-0/-home-user-johomax-ctf/"
    "226011ce-5737-5a27-8c92-56fcef09dedb/scratchpad/autoresearch"))

EPISODES = int(os.environ.get("CTF_EPISODES", "40"))   # per direction
POLL_SECONDS = 60
# A positive point estimate whose lower bound sits within this of zero is a
# near miss, not a null: rule 5 says buy episodes rather than call it. Roughly
# a third of the K/D gap that has ever survived a confirmation run here.
ESCALATE_MARGIN = 0.03


def log(msg: str) -> None:
    print(f"[{datetime.now().strftime('%H:%M:%S')}] {msg}", flush=True)


def run(cmd: list[str], **kw) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


def cli(*args: str, attempts: int = 4, timeout: int = 1800) -> str:
    """The coworld CLI, retried: a transient failure must not lose a run."""
    last = None
    for i in range(attempts):
        p = run([BIN, *args], timeout=timeout)
        if p.returncode == 0:
            return p.stdout
        last = p
        time.sleep(2 ** i)
    raise RuntimeError(
        f"coworld {' '.join(args)} failed: {last.stderr[-2000:] if last else ''}")


# --- state ------------------------------------------------------------------

def load_state() -> dict:
    if STATE_PATH.exists():
        return json.loads(STATE_PATH.read_text())
    return {"generation": 0, "baseline": None, "champion": None,
            "done": {}, "queue": [], "in_flight": None}


def save_state(st: dict) -> None:
    RESEARCH.mkdir(exist_ok=True)
    STATE_PATH.write_text(json.dumps(st, indent=2) + "\n")


# --- build ------------------------------------------------------------------

def apply_edits(exp: cat.Experiment, dest: Path) -> list[dict]:
    """Copy `bot/` to `dest` and apply the experiment's edits there.

    The edits are computed against the tree as it reads now and applied to a
    copy, so the git working tree stays clean while a candidate is in flight
    and a rejected experiment needs no revert at all. A `find` that does not
    match exactly once aborts: an edit that quietly does nothing is measured
    as "level", which looks like a finished experiment and is not one.
    """
    if dest.exists():
        shutil.rmtree(dest)
    shutil.copytree(BOT, dest)

    edits = list(exp.edits)
    if exp.knob is not None:
        src = (BOT / cat.TUNING).read_text()
        edits.append(cat.knob_edit(src, exp.knob, exp.value))

    for e in edits:
        path = dest / e["file"]
        text = path.read_text()
        hits = text.count(e["find"])
        if hits != 1:
            raise ValueError(
                f"{exp.name}: {e['file']} contains {hits} occurrences of "
                f"{e['find']!r}, expected exactly 1")
        path.write_text(text.replace(e["find"], e["replace"]))
    return edits


def build(tag: str, context: Path) -> None:
    """Build the image, and prove the image contains a runnable binary.

    The output-name trap in Dockerfile.sandbox produces an image that builds
    cleanly with the SOURCE DIRECTORY copied to /bin/baseline and fails only
    when something runs it, so the check is that /bin/baseline is a regular
    file and that it executes.
    """
    ca = context / "ccr-agent-proxy.crt"
    shutil.copy("/root/.ccr/ca-bundle.crt", ca)   # the CA changes every session
    p = run(["docker", "build", "--network=host",
             "--build-arg", f"PROXY={os.environ.get('HTTPS_PROXY', '')}",
             "-f", "Dockerfile.sandbox", "-t", tag, "."],
            cwd=context, timeout=3600)
    if p.returncode != 0:
        raise RuntimeError(f"docker build failed:\n{p.stdout[-4000:]}\n{p.stderr[-4000:]}")
    chk = run(["docker", "run", "--rm", "--entrypoint", "/bin/sh", tag, "-c",
               "test -f /bin/baseline && test -x /bin/baseline && echo ok"])
    if "ok" not in chk.stdout:
        raise RuntimeError(f"{tag}: /bin/baseline is not an executable file "
                           f"(the Nim output-name trap): {chk.stdout}{chk.stderr}")


def smoke(tag: str, outdir: Path) -> None:
    """One local all-slots episode: does this build actually play?

    A local run seats the same image in all sixteen slots, so it says nothing
    about strength -- but a build that cannot connect, cannot see, or dies on
    the first frame produces an episode with no kills in it, and finding that
    out here costs one local episode instead of eighty league ones.
    """
    manifest = next((ROOT / "cwpkg").glob("*/coworld_manifest.json"))
    if outdir.exists():
        shutil.rmtree(outdir)
    p = run([BIN, "run-episode", str(manifest), *([tag] * 16),
             "-o", str(outdir), "-n", "1", "--timeout-seconds", "400"],
            timeout=1800)
    res = outdir / "results.json"
    if not res.exists():
        raise RuntimeError(f"{tag}: local smoke produced no results.json\n"
                           f"{p.stdout[-2000:]}\n{p.stderr[-2000:]}")
    d = json.loads(res.read_text())
    kills = sum(d.get("kills") or [])
    if kills <= 0:
        raise RuntimeError(f"{tag}: local smoke episode recorded {kills} kills; "
                           "the build connected but is not playing")
    log(f"  smoke ok: {kills} kills over 16 seats")


def upload(tag: str, purpose: str) -> str:
    """Upload the image and return the policy ref the SERVER assigned.

    The server picks the next sequential version regardless of the local
    Docker tag, so the returned ref -- not the tag -- is what identifies this
    build from here on.
    """
    out = cli("upload-policy", tag, "-n", POLICY_NAME, "--tag", f"purpose={purpose}")
    m = re.search(rf"({re.escape(POLICY_NAME)}:v\d+)", out)
    if not m:
        raise RuntimeError(f"could not read a policy ref out of: {out!r}")
    return m.group(1)


# --- hosted measurement -----------------------------------------------------

EP_TERMINAL = {"completed", "failed", "cancelled", "canceled", "error", "skipped"}


def request_body(red: str, blue: str, arm: str, n: int) -> dict:
    roster = [{"player": {"policy_ref": red}, "slot": s} for s in range(0, 16, 2)]
    roster += [{"player": {"policy_ref": blue}, "slot": s} for s in range(1, 16, 2)]
    return {
        "target": {"league_id": LEAGUE,
                   "division_id": "div_37361341-2970-4dac-9528-55398bab0d1a"},
        "roster": roster,
        "num_episodes": n,
        "notes": f"ctf-h2h | arm={arm} | red={red} | blue={blue} | eps={n}",
    }


def create_request(red: str, blue: str, arm: str, n: int, path: Path) -> str:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(request_body(red, blue, arm, n), indent=2))
    d = json.loads(cli("xp-request", "create", str(path), "--json"))
    return d.get("id") or d["experience_request"]["id"]


def request_status(xreq: str) -> str:
    """Finished means every EPISODE is finished.

    The request-level `status` field is not a completion signal: a request has
    been seen sitting at "pending" with `started_at` null for over an hour
    after all of its episodes had completed, so a driver polling that field
    waits forever on work that is already done.
    """
    d = json.loads(cli("xp-request", "get", xreq, "--json"))
    eps = d.get("episodes") or []
    if eps and all(e.get("status") in EP_TERMINAL for e in eps):
        return "completed" if any(e.get("status") == "completed" for e in eps) \
            else "failed"
    return d.get("status", "?")


def mirror(name: str, treatment: str, control: str, n: int) -> tuple[str, str]:
    """Create both directions back to back, then block until both finish.

    Back to back matters as much as both-directions does: the point of the
    mirror is that the two builds meet in the same episodes at the same
    moment, so whatever the league is doing to one it is doing to the other.
    """
    arms = Path(os.environ.get("CTF_ARMS_DIR", str(ROOT / "arms")))
    a = create_request(treatment, control, f"{name}TreatRed", n,
                       arms / f"h2h-{name}-a.json")
    b = create_request(control, treatment, f"{name}CtrlRed", n,
                       arms / f"h2h-{name}-b.json")
    log(f"  XREQ_A={a}  XREQ_B={b}")
    terminal = {"completed", "failed", "cancelled", "canceled", "error"}
    while True:
        sa, sb = request_status(a), request_status(b)
        log(f"  {name}: A={sa} B={sb}")
        if sa in terminal and sb in terminal:
            break
        time.sleep(POLL_SECONDS)
    if sa != "completed" or sb != "completed":
        raise RuntimeError(f"{name}: mirror ended A={sa} B={sb}")
    return a, b


# --- the decision ------------------------------------------------------------

def decide(v: dict, stage: int) -> tuple[str, str]:
    """PROMOTE / ESCALATE / REJECT, and the sentence that says why.

    `v` comes from pool_h2h.verdict oriented so every gap reads
    (treatment - control).
    """
    kd, wr, cap = v["gaps"]["kd"], v["gaps"]["win_rate"], v["gaps"]["captures"]
    separates = kd["ci_lo"] > 0
    near_miss = kd["observed"] > 0 and kd["ci_lo"] > -ESCALATE_MARGIN
    wins_ok = wr["ci_hi"] > 0
    caps_ok = cap["ci_hi"] > 0
    body = (f"K/D {kd['observed']:+.4f} CI [{kd['ci_lo']:+.4f}, {kd['ci_hi']:+.4f}], "
            f"win rate {wr['observed']:+.3f} CI [{wr['ci_lo']:+.3f}, {wr['ci_hi']:+.3f}], "
            f"captures {cap['observed']:+.0f} CI [{cap['ci_lo']:+.0f}, {cap['ci_hi']:+.0f}], "
            f"n={v['n']}")

    if not wins_ok:
        return "REJECT", f"wins separate NEGATIVE: {body}"
    if not caps_ok:
        return "REJECT", f"captures separate NEGATIVE: {body}"
    if separates:
        if stage == 1:
            return "ESCALATE", f"separates positive at n={v['n']}; confirming: {body}"
        return "PROMOTE", f"separates positive on the pooled sample: {body}"
    if stage == 1 and near_miss:
        return "ESCALATE", f"near miss, buying episodes rather than calling it: {body}"
    if kd["ci_hi"] < 0:
        return "REJECT", f"REGRESSION: {body}"
    return "REJECT", f"level: {body}"


# --- promotion ---------------------------------------------------------------

def git(*args: str) -> str:
    p = run(["git", *args], cwd=ROOT)
    if p.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)} failed: {p.stderr}")
    return p.stdout


def promote(exp: cat.Experiment, edits: list[dict], ref: str, why: str) -> None:
    """Land the change in the tree and put the build in the league.

    The source edit is re-applied to `bot/` here rather than copied back from
    the build directory, so what gets committed is exactly the edit that was
    measured, expressed against the tree it was measured on.
    """
    for e in edits:
        path = BOT / e["file"]
        text = path.read_text()
        if text.count(e["find"]) != 1:
            raise RuntimeError(f"promote {exp.name}: {e['file']} no longer "
                               f"contains {e['find']!r} exactly once")
        path.write_text(text.replace(e["find"], e["replace"]))
    log(f"  submitting {ref} to the league with --auto-champion always")
    out = cli("submit", ref, "-l", LEAGUE, "--auto-champion", "always",
              "--no-open-browser")
    log(f"  {out.strip().splitlines()[-1] if out.strip() else 'submitted'}")


# --- the ledger --------------------------------------------------------------

def append_ledger(exp: cat.Experiment, outcome: str, why: str, ref: str,
                  control: str, xreqs: list[str], v: dict | None) -> None:
    RESEARCH.mkdir(exist_ok=True)
    if not LEDGER_PATH.exists():
        LEDGER_PATH.write_text(LEDGER_HEADER)
    with LEDGER_PATH.open("a") as fh:
        fh.write(f"\n## {exp.name} — {outcome}\n\n")
        fh.write(f"- when: {datetime.now(timezone.utc).isoformat(timespec='seconds')}\n")
        fh.write(f"- change: {describe(exp)}\n")
        fh.write(f"- treatment: `{ref}`  control: `{control}`\n")
        fh.write(f"- requests: {', '.join('`%s`' % x for x in xreqs)}\n")
        fh.write(f"- verdict: {why}\n")
        if v:
            fh.write(f"- pooled: {v['n']} episodes, "
                     f"{len(v['skipped'])} skipped; RED won "
                     f"{v['red_win_rate']:.1%} of episodes\n")
            for b, s in v["builds"].items():
                fh.write(f"  - `{b}`: K/D {s['kd']:.4f} "
                         f"({s['kills']:.0f}/{s['deaths']:.0f}), "
                         f"captures {s['captures']:.0f}, wins {s['wins']}\n")
        fh.write(f"- rationale: {exp.rationale}\n")


def describe(exp: cat.Experiment) -> str:
    if exp.knob:
        return f"`{exp.knob}` -> `{exp.value}`"
    return "; ".join(f"`{e['file']}`: `{e['find'].strip()}` -> "
                     f"`{e['replace'].strip()}`" for e in exp.edits) or "(no edit)"


LEDGER_HEADER = """# Auto-research ledger

Every experiment the loop has run, in order, with the request ids behind each
verdict. Written by `scripts/autoresearch.py`; see that file for the rules a
verdict is reached under, and README.md for why those are the rules.

A gap is always (treatment - control) and always pooled over both directions of
a mirror that ran at the same moment. "level" means the 95% bootstrap interval
crosses zero, which is a result: it says the change is not worth shipping, not
that the run failed.
"""


# --- one experiment ----------------------------------------------------------

def run_one(exp: cat.Experiment, st: dict, dry: bool) -> str:
    log(f"=== {exp.name} ({exp.kind}) ===")
    log(f"  {describe(exp)}")

    WORK.mkdir(parents=True, exist_ok=True)
    ctx = WORK / exp.name
    edits = apply_edits(exp, ctx)
    log(f"  {len(edits)} edit(s) applied to the build copy")
    if dry:
        for e in edits:
            log(f"    {e['file']}: {e['find'].strip()!r} -> {e['replace'].strip()!r}")
        return "DRY"

    tag = f"ctf-cand:{exp.name}"
    build(tag, ctx)
    smoke(tag, WORK / f"smoke-{exp.name}")
    ref = upload(tag, f"autoresearch-{exp.name}")
    control = st["baseline"]
    log(f"  treatment {ref} vs control {control}")

    xreqs: list[str] = []
    v = None
    for stage in (1, 2):
        a, b = mirror(f"{exp.name}s{stage}", ref, control, EPISODES)
        xreqs += [a, b]
        v = verdict(xreqs, treatment=ref)
        outcome, why = decide(v, stage)
        log(f"  stage {stage}: {outcome} — {why}")
        if outcome != "ESCALATE":
            break
    else:
        outcome, why = decide(v, 2)

    if outcome == "PROMOTE":
        promote(exp, edits, ref, why)
        st["baseline"] = ref
        st["champion"] = ref
        st["generation"] += 1

    st["done"][exp.name] = {
        "outcome": outcome, "why": why, "ref": ref, "control": control,
        "xreqs": xreqs, "kd_gap": v["gaps"]["kd"] if v else None,
        "when": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    }
    append_ledger(exp, outcome, why, ref, control, xreqs, v)

    if exp.kind == "knob":
        tree_value = cat.read_const((BOT / cat.TUNING).read_text(), exp.knob)
        for nxt in cat.followups(exp, outcome == "PROMOTE", tree_value):
            if nxt.name not in st["done"] and not any(
                    q["name"] == nxt.name for q in st["queue"]):
                st["queue"].append(serialize(nxt))
                log(f"  queued follow-up: {nxt.name}")

    save_state(st)
    commit(exp, outcome, why)
    return outcome


def serialize(e: cat.Experiment) -> dict:
    return {"name": e.name, "rationale": e.rationale, "knob": e.knob,
            "value": e.value, "edits": e.edits, "parent": e.parent}


def deserialize(d: dict) -> cat.Experiment:
    return cat.Experiment(**d)


def commit(exp: cat.Experiment, outcome: str, why: str) -> None:
    # Stage the ledger always and `bot/` only on a promotion. Nothing else:
    # the loop runs for hours unattended and must never sweep up an unrelated
    # edit somebody is in the middle of making.
    paths = ["research"] + (["bot"] if outcome == "PROMOTE" else [])
    git("add", "-A", *paths)
    if not run(["git", "diff", "--cached", "--quiet"], cwd=ROOT).returncode:
        return                                   # nothing staged, nothing to say
    subject = {"PROMOTE": f"Promote {exp.name}: {exp.knob or 'patch'} improves the policy",
               "REJECT": f"{exp.name} does not improve the policy"}.get(
                   outcome, f"{exp.name}: {outcome}")
    body = f"{why}\n\n{exp.rationale}\n"
    run(["git", "commit", "-m", subject[:72], "-m", body,
         "-m", "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"], cwd=ROOT)


# --- the loop ----------------------------------------------------------------

def next_experiment(st: dict) -> cat.Experiment | None:
    while st["queue"]:
        e = deserialize(st["queue"].pop(0))
        if e.name not in st["done"]:
            return e
    for e in cat.SEED:
        if e.name not in st["done"]:
            return e
    return None


def main() -> None:
    dry = "--dry-run" in sys.argv
    once = "--once" in sys.argv
    limit = next((int(a.split("=", 1)[1]) for a in sys.argv
                  if a.startswith("--max-experiments")), 1000)
    global EPISODES
    for a in sys.argv:
        if a.startswith("--episodes"):
            EPISODES = int(a.split("=", 1)[1])

    st = load_state()
    if not st.get("baseline"):
        sys.exit("research/state.json has no baseline policy ref; seed it with "
                 "the build every experiment is measured against")

    ran = 0
    while ran < limit:
        exp = next_experiment(st)
        if exp is None:
            log("queue empty — nothing left to measure")
            return
        try:
            outcome = run_one(exp, st, dry)
            if dry:
                # A dry run proves every edit still matches the tree exactly
                # once, which is the check worth having before a night of
                # unattended builds. Nothing is measured, so nothing is
                # recorded -- mark it seen in memory only and move on.
                st["done"][exp.name] = {"outcome": outcome}
        except Exception as exc:                 # noqa: BLE001
            log(f"  {exp.name} ABANDONED: {exc}")
            st["done"][exp.name] = {
                "outcome": "ABANDONED", "why": str(exc)[:2000],
                "when": datetime.now(timezone.utc).isoformat(timespec="seconds")}
            save_state(st)
            append_ledger(exp, "ABANDONED", str(exc)[:500], "-",
                          st.get("baseline", "-"), [], None)
            commit(exp, "ABANDONED", str(exc)[:500])
        ran += 1
        if once:
            return


if __name__ == "__main__":
    main()
