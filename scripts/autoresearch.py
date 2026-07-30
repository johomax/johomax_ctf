#!/usr/bin/env python3
"""The auto-research loop: propose, build, measure, promote, repeat.

One iteration takes one experiment from `scripts/experiments.py`, builds it as
its own image, puts it in the same episodes as the current baseline build in
both directions, pools the mirror, and either promotes it (commit the source
change, submit the policy with --auto-champion always) or throws it away. Then
it asks the catalogue what the result suggests trying next and goes again.

Screening and shipping are separate questions. The control for an experiment is
the current TREE build, because that is what isolates the one variable the
experiment moves. Whether the result deserves the league is decided against the
CHAMPION, in one more mirror, and only for candidates that already survived a
confirmation run -- so the gate is cheap and nothing reaches the league on the
strength of beating a tree the league has never seen. A change that beats the
tree but does not clear the champion still lands in `bot/`: it is the better
build to keep building on, it is just not news.

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

import importlib
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
# The confirmation buys more than the screen because it is the decision that
# ships. Measured on this league, the 95% half-width of a pooled K/D gap runs
# about 0.63/sqrt(episodes) and of a win-rate gap about 1.90/sqrt(episodes):
# an 80-episode screen resolves 0.070 K/D, and pooling a 160-episode
# confirmation with it resolves 0.035 -- about the size of thing worth
# shipping. Captures cannot be bought at any plausible n (+-14 on a total of
# 27 at 160 episodes), which is why they only ever veto.
CONFIRM_EPISODES = int(os.environ.get("CTF_CONFIRM_EPISODES", "80"))
# Experiments screened together against the same control. At most one change
# lands per generation however many clear.
#
# The batch does NOT buy parallelism, which is worth writing down because it
# looks like it should. Measured on this league: the server runs ONE Experience
# Request at a time and about 23 episodes concurrently inside it, so six
# requests take about what six sequential requests take. What the batch
# actually buys is that the queue is never empty: preparing a candidate (build,
# smoke, upload) takes ~2.5 minutes against a ~8 minute request, and a loop
# that measures one at a time spends that gap with no request of its own
# queued, where somebody else's takes the slot. Worth about 20%, not 300%.
BATCH = int(os.environ.get("CTF_BATCH", "3"))
POLL_SECONDS = 60
# A positive point estimate whose lower bound sits within this of zero is a
# near miss, not a null: rule 5 says buy episodes rather than call it. Roughly
# a third of the K/D gap that has ever survived a confirmation run here.
# How far from zero a screen result must sit, in standard errors, to be worth
# a confirmation. 0.8 puts the probability that the true effect is positive at
# roughly 79% under a normal approximation -- weak on purpose, because the
# screen is triage and everything it admits still has to separate at ~240
# episodes and then not lose to the champion.
ESCALATE_Z = 0.8
# One episode can hang while the other thirty-nine finish. Stop waiting on a
# mirror that has produced no new terminal episode for this long once nearly
# all of them are in: a hung episode is worth no more than a failed one, and
# rule 7 says a failed episode is excluded rather than retried.
STALL_SECONDS = 1200
MIN_TERMINAL_FRACTION = 0.9


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


def request_progress(xreq: str) -> tuple[str, int, int]:
    """(status, terminal episodes, total episodes).

    Finished means every EPISODE is finished. The request-level `status` field
    is not a completion signal: a request has been seen sitting at "pending"
    with `started_at` null for over an hour after all of its episodes had
    completed, so a driver polling that field waits forever on work that is
    already done.
    """
    d = json.loads(cli("xp-request", "get", xreq, "--json"))
    eps = d.get("episodes") or []
    done = sum(1 for e in eps if e.get("status") in EP_TERMINAL)
    if eps and done == len(eps):
        status = "completed" if any(e.get("status") == "completed" for e in eps) \
            else "failed"
    else:
        status = d.get("status", "?")
    return status, done, len(eps)


def open_mirror(name: str, treatment: str, control: str, n: int) -> list[str]:
    """Create both directions back to back and return without waiting.

    Back to back matters as much as both-directions does: the point of the
    mirror is that the two builds meet in the same episodes at the same
    moment, so whatever the league is doing to one it is doing to the other.
    """
    arms = Path(os.environ.get("CTF_ARMS_DIR", str(ROOT / "arms")))
    a = create_request(treatment, control, f"{name}TreatRed", n,
                       arms / f"h2h-{name}-a.json")
    b = create_request(control, treatment, f"{name}CtrlRed", n,
                       arms / f"h2h-{name}-b.json")
    log(f"  {name}: XREQ_A={a}  XREQ_B={b}")
    return [a, b]


def await_mirrors(xreqs: list[str], label: str) -> None:
    """Block until every request given is finished, or has stopped moving.

    Waiting on a batch rather than on one mirror is what makes the batch worth
    anything: the requests are all in flight together, so the whole batch
    costs about what one mirror costs in wall-clock.
    """
    terminal = {"completed", "failed", "cancelled", "canceled", "error"}
    seen, since = -1, time.monotonic()
    while True:
        prog = [request_progress(x) for x in xreqs]
        done = sum(p[1] for p in prog)
        total = sum(p[2] for p in prog)
        log(f"  {label}: {done}/{total} episodes; "
            + " ".join(f"{x[5:13]}={p[0]}" for x, p in zip(xreqs, prog)))
        if all(p[0] in terminal for p in prog):
            return
        # A single episode can hang while every other one finishes. Rule 7
        # says a failed episode is excluded, not retried, and a hung one is
        # worth no more than a failed one -- so once the batch has stopped
        # producing terminal episodes for STALL_SECONDS and nearly all of
        # them are in, stop waiting and pool what actually ran. pool_h2h
        # prints every episode it skipped, so the sample loss stays visible.
        if done > seen:
            seen, since = done, time.monotonic()
        elif (time.monotonic() - since > STALL_SECONDS
              and done >= MIN_TERMINAL_FRACTION * total):
            log(f"  {label}: stalled at {done}/{total} terminal for "
                f"{STALL_SECONDS}s — pooling without the stragglers")
            return
        time.sleep(POLL_SECONDS)


# --- the decision ------------------------------------------------------------

def zscore(gap: dict) -> float:
    """The observed gap in standard errors, recovered from its interval.

    The bootstrap reports a 95% interval rather than a standard error, and a
    95% half-width is 1.96 standard errors, so this reads one off the other.
    It is what lets a single threshold mean the same thing on K/D and on win
    rate, whose units and noise differ by more than an order of magnitude.
    """
    half = (gap["ci_hi"] - gap["ci_lo"]) / 2.0
    return 0.0 if half <= 0 else gap["observed"] / (half / 1.96)


def decide(v: dict, stage: int) -> tuple[str, str]:
    """PROMOTE / ESCALATE / REJECT, and the sentence that says why.

    `v` comes from pool_h2h.verdict oriented so every gap reads
    (treatment - control).
    """
    kd, wr, cap = v["gaps"]["kd"], v["gaps"]["win_rate"], v["gaps"]["captures"]
    # An improvement is a positive separation on either scored quantity, with
    # neither of the others separating the other way. K/D is the sensitive
    # one -- win rate needs roughly a twelve point gap at n=40 to mean
    # anything -- so it is what usually moves first, but the league scores
    # WINS, and a change that separates on wins is an improvement whatever
    # K/D says about it.
    separates = kd["ci_lo"] > 0 or wr["ci_lo"] > 0
    # What buys a confirmation run. The screen is TRIAGE, not the verdict:
    # escalating claims nothing and costs 160 episodes, while the confirmation
    # and the champion gate are what stop a fake result shipping. So it is
    # tuned not to MISS a real effect, where the verdict is tuned not to admit
    # a false one -- tuning the screen like a verdict is how a real 0.04 gap
    # gets thrown away for looking like a 0.00 one.
    #
    # The bar is scaled to what the run could resolve, not to the sign. Each
    # metric gets a pseudo-z -- the observed gap over its own standard error,
    # recovered from the bootstrap half-width -- so the same rule means the
    # same thing at any episode count and on metrics whose units are nothing
    # alike. Escalate when neither scored quantity leans against the change
    # and at least one reaches ESCALATE_Z.
    #
    # Two earlier versions of this were wrong in opposite directions and both
    # are worth remembering. A margin on the K/D lower bound alone, with a
    # matching one on win rate, could never fire on wins: at 80 episodes the
    # win-rate half-width is 0.21, so `ci_lo > -0.05` demanded a 16-POINT
    # observed gap, by which point K/D would have triggered anyway -- the
    # documented "promote on wins as well as K/D" was unreachable. Replacing
    # it with "both lean positive" then went too far the other way: it fires
    # on any coin that lands heads twice, about one experiment in four under a
    # null, and would have spent 160 episodes on a +0.005 K/D, +2.5 point
    # result that was as flat as a measurement gets.
    near_miss = (min(zscore(kd), zscore(wr)) >= 0.0
                 and max(zscore(kd), zscore(wr)) >= ESCALATE_Z)
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


def clears_champion(v: dict) -> tuple[bool, str]:
    """Is this build at least level with the champion on all three metrics?

    Beating the baseline and beating the champion are different questions
    whenever the tree is not itself the champion, which is the normal state
    of affairs the moment anything lands here that the league has not seen.
    Screening against the tree is what isolates the change; this is what
    decides whether the result is worth the league's attention. The bar is
    "does not separate negative", not "separates positive": a change that is
    level with the champion and better than the tree is still the better
    build to be running.
    """
    kd, wr, cap = v["gaps"]["kd"], v["gaps"]["win_rate"], v["gaps"]["captures"]
    body = (f"vs champion: K/D {kd['observed']:+.4f} "
            f"[{kd['ci_lo']:+.4f}, {kd['ci_hi']:+.4f}], "
            f"win rate {wr['observed']:+.3f} [{wr['ci_lo']:+.3f}, {wr['ci_hi']:+.3f}], "
            f"captures {cap['observed']:+.0f} [{cap['ci_lo']:+.0f}, {cap['ci_hi']:+.0f}], "
            f"n={v['n']}")
    for name, g in (("K/D", kd), ("win rate", wr), ("captures", cap)):
        if g["ci_hi"] < 0:
            return False, f"{name} separates NEGATIVE against the champion; {body}"
    return True, body


# --- promotion ---------------------------------------------------------------

def git(*args: str) -> str:
    p = run(["git", *args], cwd=ROOT)
    if p.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)} failed: {p.stderr}")
    return p.stdout


def land(exp: cat.Experiment, edits: list[dict]) -> None:
    """Apply the measured change to `bot/`.

    Re-applied here rather than copied back from the build directory, so what
    gets committed is exactly the edit that was measured, expressed against
    the tree it was measured on.
    """
    for e in edits:
        path = BOT / e["file"]
        text = path.read_text()
        if text.count(e["find"]) != 1:
            raise RuntimeError(f"land {exp.name}: {e['file']} no longer "
                               f"contains {e['find']!r} exactly once")
        path.write_text(text.replace(e["find"], e["replace"]))


def submit(ref: str) -> None:
    log(f"  submitting {ref} to the league with --auto-champion always")
    try:
        out = cli("submit", ref, "-l", LEAGUE, "--auto-champion", "always",
                  "--no-open-browser")
        log(f"  {out.strip().splitlines()[-1] if out.strip() else 'submitted'}")
    except Exception as exc:                      # noqa: BLE001
        # A failed submission is a league problem, not a measurement one. The
        # result stands, the change belongs in the tree, and re-submitting a
        # ref later is one command; losing the verdict to an exception here
        # would cost another 160 episodes to recover.
        log(f"  SUBMIT FAILED (the result stands, the ref is uploaded): {exc}")


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


# --- one generation ----------------------------------------------------------

def prepare(exp: cat.Experiment, dry: bool) -> tuple[list[dict], str] | None:
    """Apply, build, smoke and upload one candidate. None if it cannot run.

    Everything here is local and cheap next to a mirror, and every one of the
    checks it runs is a check that would otherwise be paid for in league
    episodes: an edit that matched nothing, an image with the source directory
    where the binary should be, a binary that connects and does not play.
    """
    log(f"--- {exp.name} ({exp.kind}) ---")
    log(f"  {describe(exp)}")
    WORK.mkdir(parents=True, exist_ok=True)
    ctx = WORK / exp.name
    edits = apply_edits(exp, ctx)
    log(f"  {len(edits)} edit(s) applied to the build copy")
    if dry:
        for e in edits:
            log(f"    {e['file']}: {e['find'].strip()!r} -> "
                f"{e['replace'].strip()!r}")
        return None
    tag = f"ctf-cand:{exp.name}"
    build(tag, ctx)
    smoke(tag, WORK / f"smoke-{exp.name}")
    return edits, upload(tag, f"autoresearch-{exp.name}")


def record(exp: cat.Experiment, st: dict, outcome: str, why: str, ref: str,
           control: str, xreqs: list[str], v: dict | None,
           tree_value: str | None) -> None:
    st["done"][exp.name] = {
        "outcome": outcome, "why": why, "ref": ref, "control": control,
        "xreqs": xreqs, "kd_gap": (v or {}).get("gaps", {}).get("kd"),
        "when": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    }
    append_ledger(exp, outcome, why, ref, control, xreqs, v)
    if exp.kind == "knob" and tree_value is not None:
        observed = (v or {}).get("gaps", {}).get("kd", {}).get("observed", 0.0)
        for nxt in cat.followups(exp, outcome.startswith("PROMOTE"),
                                 tree_value, observed):
            if nxt.name not in st["done"] and not any(
                    q["name"] == nxt.name for q in st["queue"]):
                st["queue"].append(serialize(nxt))
                log(f"  queued follow-up: {nxt.name}")
    save_state(st)
    commit(exp, outcome, why)


def run_generation(exps: list[cat.Experiment], st: dict, dry: bool) -> int:
    """Screen a batch against the tree, confirm the survivors, land one.

    The batch exists to keep the request queue full, not for statistics and
    not for parallelism -- the server runs one request at a time (see BATCH).
    Every experiment in it is still its own self-contained both-directions
    mirror against the same control.

    What the batch must NOT do is land more than one change, because
    individually-level levers stacked into a bundle cost this repository 0.184
    K/D and 37.5 points of win rate. So the best survivor lands and every other
    survivor goes back in the queue to be re-measured against the tree it will
    actually be built on.
    """
    control = st["baseline"]
    log(f"=== generation {st['generation']}: {len(exps)} experiment(s) "
        f"against {control} ===")

    ready: list[tuple[cat.Experiment, list[dict], str]] = []
    for exp in exps:
        try:
            prep = prepare(exp, dry)
        except (Exception, SystemExit) as exc:     # noqa: BLE001
            log(f"  {exp.name} ABANDONED: {exc}")
            record(exp, st, "ABANDONED", str(exc)[:2000], "-", control, [],
                   None, None)
            continue
        if prep is not None:
            ready.append((exp, prep[0], prep[1]))
    if dry or not ready:
        return len(ready)

    # Screen: every mirror in flight at once, then pooled one at a time.
    open_at: dict[str, list[str]] = {}
    for exp, _, ref in ready:
        open_at[exp.name] = open_mirror(f"{exp.name}s1", ref, control, EPISODES)
    await_mirrors([x for v in open_at.values() for x in v],
                  f"gen{st['generation']} screen")

    survivors = []
    for exp, edits, ref in ready:
        v = verdict(open_at[exp.name], treatment=ref)
        outcome, why = decide(v, 1)
        log(f"  {exp.name} screen: {outcome} — {why}")
        if outcome == "ESCALATE":
            survivors.append((exp, edits, ref, v))
        else:
            record(exp, st, outcome, why, ref, control, open_at[exp.name], v,
                   tree_const(exp))

    if not survivors:
        st["generation"] += 1
        commit_state(st, f"generation {st['generation'] - 1}: nothing survived "
                         "the screen")
        return len(ready)

    # Confirm: rule 5 says a marginal call at 80 episodes is not a call, and
    # this is the decision that ships, so the confirmation buys more than the
    # screen did -- pooled with it, CONFIRM_EPISODES a side resolves a K/D gap
    # about half the size the screen can see.
    for exp, _, ref, _ in survivors:
        open_at[exp.name] += open_mirror(f"{exp.name}s2", ref, control,
                                         CONFIRM_EPISODES)
    await_mirrors([x for e, _, _, _ in survivors for x in open_at[e.name][2:]],
                  f"gen{st['generation']} confirm")

    confirmed = []
    for exp, edits, ref, _ in survivors:
        v = verdict(open_at[exp.name], treatment=ref)
        outcome, why = decide(v, 2)
        log(f"  {exp.name} confirm: {outcome} — {why}")
        if outcome == "PROMOTE":
            confirmed.append((exp, edits, ref, v, why))
        else:
            record(exp, st, outcome, why, ref, control, open_at[exp.name], v,
                   tree_const(exp))

    if not confirmed:
        st["generation"] += 1
        commit_state(st, f"generation {st['generation'] - 1}: nothing survived "
                         "confirmation")
        return len(ready)

    # One lands. Ordered by the lower bound rather than the point estimate:
    # the question is which improvement is best SUPPORTED, not which sample
    # happened to look biggest.
    confirmed.sort(key=lambda c: c[3]["gaps"]["kd"]["ci_lo"], reverse=True)
    (exp, edits, ref, v, why), rest = confirmed[0], confirmed[1:]
    tree_value = tree_const(exp)

    submit_it, gate = True, ""
    if st.get("champion") and st["champion"] != control:
        gate_reqs = open_mirror(f"{exp.name}chg", ref, st["champion"],
                                EPISODES)
        await_mirrors(gate_reqs, f"{exp.name} champion gate")
        open_at[exp.name] += gate_reqs
        submit_it, gate = clears_champion(verdict(gate_reqs, treatment=ref))
        log(f"  champion gate: {'PASS' if submit_it else 'HELD'} — {gate}")

    land(exp, edits)
    outcome = "PROMOTE"
    if submit_it:
        submit(ref)
        st["champion"] = ref
    else:
        outcome = "PROMOTE-LOCAL"
    st["baseline"] = ref
    st["generation"] += 1
    record(exp, st, outcome, f"{why}{'; ' + gate if gate else ''}", ref,
           control, open_at[exp.name], v, tree_value)

    for other, _, oref, ov, owhy in rest:
        # Measured against a tree that no longer exists. The result is real
        # and worth writing down, and it is not a licence to stack.
        log(f"  {other.name} also cleared; re-queued against the new baseline")
        append_ledger(other, "REQUEUED",
                      f"cleared against {control} ({owhy}) but {exp.name} "
                      f"landed first; must be re-measured against {ref}",
                      oref, control, open_at[other.name], ov)
        st["queue"].insert(0, serialize(other))
    save_state(st)
    return len(ready)


def tree_const(exp: cat.Experiment) -> str | None:
    """The constant's current literal, read before anything lands.

    land() rewrites it, and a follow-up computed against the new value would
    step by zero and vanish.
    """
    if exp.kind != "knob":
        return None
    return cat.read_const((BOT / cat.TUNING).read_text(), exp.knob)


def serialize(e: cat.Experiment) -> dict:
    return {"name": e.name, "rationale": e.rationale, "knob": e.knob,
            "value": e.value, "edits": e.edits, "parent": e.parent}


def deserialize(d: dict) -> cat.Experiment:
    return cat.Experiment(**d)


def commit_state(st: dict, subject: str) -> None:
    """Save and commit state.json on its own.

    The per-experiment paths commit through `commit`, but the generation
    counter also moves when a whole batch comes back level, and leaving that
    uncommitted means the working tree is dirty for as long as the loop runs
    -- which is indistinguishable, to anyone looking, from work in progress.
    """
    save_state(st)
    git("add", "-A", "research")
    if run(["git", "diff", "--cached", "--quiet"], cwd=ROOT).returncode:
        run(["git", "commit", "-m", f"Auto-research: {subject}"[:72],
             "-m", "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"],
            cwd=ROOT)


def commit(exp: cat.Experiment, outcome: str, why: str) -> None:
    # Stage the ledger always and `bot/` only on a promotion. Nothing else:
    # the loop runs for hours unattended and must never sweep up an unrelated
    # edit somebody is in the middle of making.
    paths = ["research"] + (["bot"] if outcome.startswith("PROMOTE") else [])
    git("add", "-A", *paths)
    if not run(["git", "diff", "--cached", "--quiet"], cwd=ROOT).returncode:
        return                                   # nothing staged, nothing to say
    subject = {
        "PROMOTE": f"Promote {exp.name}: it beats the champion",
        "PROMOTE-LOCAL": f"Land {exp.name}: better than the tree, held from the league",
        "REJECT": f"{exp.name} does not improve the policy",
    }.get(outcome, f"{exp.name}: {outcome}")
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


def next_batch(st: dict, size: int) -> list[cat.Experiment]:
    """The next `size` experiments not already decided, queue before seed."""
    out, seen = [], set()
    while st["queue"] and len(out) < size:
        e = deserialize(st["queue"].pop(0))
        if e.name not in st["done"] and e.name not in seen:
            out.append(e)
            seen.add(e.name)
    for e in cat.SEED:
        if len(out) >= size:
            break
        if e.name not in st["done"] and e.name not in seen:
            out.append(e)
            seen.add(e.name)
    return out


def main() -> None:
    dry = "--dry-run" in sys.argv
    once = "--once" in sys.argv
    limit = next((int(a.split("=", 1)[1]) for a in sys.argv
                  if a.startswith("--max-experiments")), 1000)
    global EPISODES, CONFIRM_EPISODES, BATCH
    for a in sys.argv:
        if a.startswith("--episodes"):
            EPISODES = int(a.split("=", 1)[1])
        elif a.startswith("--confirm-episodes"):
            CONFIRM_EPISODES = int(a.split("=", 1)[1])
        elif a.startswith("--batch"):
            BATCH = int(a.split("=", 1)[1])

    st = load_state()
    if not st.get("baseline"):
        sys.exit("research/state.json has no baseline policy ref; seed it with "
                 "the build every experiment is measured against")

    ran = 0
    while ran < limit:
        # Re-read the catalogue every generation. The loop runs for hours and
        # the most useful thing to do with a result is to queue the experiment
        # it suggests, which should not mean waiting for the queue to drain
        # first.
        importlib.reload(cat)
        batch = next_batch(st, min(BATCH, limit - ran))
        if not batch:
            log("queue empty — nothing left to measure")
            return
        try:
            run_generation(batch, st, dry)
        except (Exception, SystemExit) as exc:     # noqa: BLE001
            # SystemExit explicitly: it is not an Exception, and a library
            # function that calls sys.exit would otherwise end the loop rather
            # than the generation. Anything that escapes run_generation is a
            # driver fault rather than one experiment's, so the whole batch is
            # marked and the loop moves on instead of retrying it forever.
            log(f"  generation ABANDONED: {exc}")
            for exp in batch:
                if exp.name not in st["done"]:
                    st["done"][exp.name] = {
                        "outcome": "ABANDONED", "why": str(exc)[:2000],
                        "when": datetime.now(timezone.utc).isoformat(
                            timespec="seconds")}
            save_state(st)
        if dry:
            for exp in batch:
                st["done"].setdefault(exp.name, {"outcome": "DRY"})
        ran += len(batch)
        if once:
            return


if __name__ == "__main__":
    main()
