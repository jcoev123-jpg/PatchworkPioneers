"""Run every res://tests/*_test.gd headless. Exit 1 if any test fails, errors, or hangs.

Tests run in parallel (WORKERS Godot processes). A test that fails in the parallel pass is re-run on its own
first, so contention between parallel tests is never reported as a failure.
A test that also fails alone and then passes unchanged on a retry is nondeterministic: it is reported as FLAKY,
recorded in flaky_tests.json (the relay planner reads it), and does not block the run.
Options: --repo <path> (a parallel lane's worktree; runs at below-normal priority unless --normal-priority),
--serial (one test at a time), --full (never a partial run; needs RELAY_FULL_OK=1, see force_full).
Owner 2026-10-13 (cycles under 30 min): lane suites share a machine-wide cap on concurrent tests (LANE_SLOTS_BUSY while
a main or merge-check suite runs, LANE_SLOTS_IDLE otherwise); a suite whose parent died stops itself; a passing main
run on an unchanged tree is recorded in suite_passes.json so the relay's TEST phase can reuse it.
Owner 2026-10-14 (partial runs): a main run whose only differences from the last full run on the same commit are
test files re-runs just those tests and the tests that failed there (last_full_runs.json).
Owner 2026-10-16 (related tests first): cycles 329 and 330 changed one level file and learned only after a ~17-min
full run that tests naming that level broke. A full run first runs the tests tied to the changed files (changed tests,
and tests naming a changed file's path, file name or class_name); if any fail it stops there and the rest do not run.
2026-10-18 (resumable runs): a relay restart killed lane6's lane-checker suite after 52 min and it started over; chat
lanes' suites are stopped by SentinelX after 600 s. Each run journals the tests that pass (suite_progress/, checked
against the tree fingerprint every minute), and a later run on the identical tree skips them.
Owner 2026-10-18 (slow tier, cycles under 30 min): the 14 tests over SLOW_TIER_S took ~39% of the ~17-min suite that
every cycle waits on. A main-checkout run leaves them out (unless they use a changed file or are owed, below); the
relay runs them with --slow-only on each accepted commit in its own worktree alongside the next cycle. Tests that fail
there are recorded in slow_owed.json: main runs always include them (the next cycle must fix them), while lane, merge
and baseline runs (--repo, or RELAY_EXCUSE_OWED=1) do not fail on them, since they already fail on the main branch.
Owner 2026-11-05 ("is there a way to speed it up", "do we need testing"): a lane run (--repo without
--normal-priority) runs only the tests tied to the files the lane changed since it left the main branch; the relay's
merge check runs the full suite on the merged result and backs out a lane that fails it. Nothing related -> the full
suite; RELAY_LANE_FULL=1 forces it.
"""
import datetime
import hashlib
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

GODOT = r"C:\Users\jcoev\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"
REPO = Path(__file__).resolve().parents[2]
if "--repo" in sys.argv:   # a parallel lane's worktree (e.g. the second DeepSeek) runs the same suite on its copy
    REPO = Path(sys.argv[sys.argv.index("--repo") + 1]).resolve()
ERR_MARKERS = ("SCRIPT ERROR", "Parse Error", "Failed to load script")
PER_TEST_TIMEOUT = 180
FLAKY_PATH = Path(__file__).resolve().parent / "flaky_tests.json"
TIMES_PATH = Path(__file__).resolve().parent / "test_times.json"
DURATIONS = {}
KNOWN = {}        # test -> seconds from earlier runs (test_times.json)
TIMED_OUT = set()
RETRIES = 2
# 2026-10-18: a main suite beside 3 lane suites averaged 65% CPU on 16 threads (5 workers), so 7 fit.
WORKERS = 1 if "--serial" in sys.argv else max(1, min(7, (os.cpu_count() or 4) // 2))
LANE = "--repo" in sys.argv and "--normal-priority" not in sys.argv
# 2026-10-13: four suites at once (two lanes, the merge check and the coder's) ran ~20 Godot tests on 16 threads, and
# the critical-path suite took ~9.5 min instead of ~6.
SLOTS_DIR = Path(__file__).resolve().parent / "test_slots"
LANE_SLOTS_BUSY, LANE_SLOTS_IDLE = 4, 10
# 2026-10-18: the background slow check shared the 4 busy lane slots with four lane suites and ran ~2 tests at a
# time (28 min for 17 tests); its own slots let its results land within about one cycle.
SLOW_SLOTS = 3
PASSES_PATH = Path(__file__).resolve().parent / "suite_passes.json"
LAST_FULL_PATH = Path(__file__).resolve().parent / "last_full_runs.json"
STARTS_PATH = Path(__file__).resolve().parent / "suite_starts.json"
PARTIAL_MAX_AGE_S = 3 * 3600
RELATED_MAX_SHARE = 0.35   # a related set longer than this share of the suite's time runs as one ordinary pass
_MAIN_MARK = []
RESUME_DIR = Path(__file__).resolve().parent / "suite_progress"
RESUME_MAX_AGE_S = 6 * 3600
JOURNAL = [None]
SLOW_TIER_S = 60
OWED_PATH = Path(__file__).resolve().parent / "slow_owed.json"
PENDING_PATH = Path(__file__).resolve().parent / "slow_pending.json"
PROGRESS_PATH = os.environ.get("RELAY_PROGRESS_FILE")
_PROGRESS_LOCK = threading.Lock()
_DONE = [0]


def note_progress(name=None, path=None):
    """Lane 2's MoodState (2026-10-18) was given up after its lane suite "did not finish within 2700s. A test hangs":
    nothing hung. Four lanes shared the lane test slots with the cycle's and the merge check's suites, so ~700 tests
    could not finish in 45 min, and a fix round spent 70 min hunting a hang. The lane checker now stops a suite only
    when this file stops changing: it is rewritten after every finished test (name given) and while a test waits for
    a slot, so waiting is progress and only a stuck runner goes quiet."""
    path = path or PROGRESS_PATH
    if not path:
        return
    with _PROGRESS_LOCK:
        if name:
            _DONE[0] += 1
        try:
            Path(path).write_text(f"{_DONE[0]} {name or '(waiting for a test slot)'}\n", encoding="utf-8")
        except OSError:
            pass


def _try_lock(path):
    """An open fd holding an exclusive lock on the file's first byte, or None. Windows releases it when the
    process exits, so a killed suite never leaves a slot taken."""
    try:
        import msvcrt
    except ImportError:
        return None
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        fd = os.open(path, os.O_RDWR | os.O_CREAT)
    except OSError:   # another suite is deleting this stale marker
        return None
    try:
        msvcrt.locking(fd, msvcrt.LK_NBLCK, 1)
        return fd
    except OSError:
        os.close(fd)
        return None


def _unlock(fd):
    import msvcrt
    os.lseek(fd, 0, 0)
    msvcrt.locking(fd, msvcrt.LK_UNLCK, 1)
    os.close(fd)


FLAGS = ("--repo", "--serial", "--full", "--normal-priority", "--slow-only")


def arg_problem(argv, cwd):
    """(exit code, message) when the run must not start, else None. Owner 2026-10-15 (cycle 291): a lane coder in
    C:/ironvale-lane3 ran `run_tests.py --help`; the script ignored the flag and started a full suite on the main
    coder's half-edited tree, which started the relay's early final review on the wrong tree (thrown away 20 min
    later) and took CPU from the cycle's own suite."""
    if "-h" in argv or "--help" in argv:
        return 0, __doc__
    unknown = [a for i, a in enumerate(argv) if a not in FLAGS and not (i and argv[i - 1] == "--repo")]
    if unknown or (argv and argv[-1] == "--repo"):
        return 2, f"run_tests.py: unknown arguments {unknown or ['--repo needs a path']}; options: {', '.join(FLAGS)}"
    if "--repo" in argv:
        return None
    try:
        top = subprocess.run(["git", "rev-parse", "--show-toplevel"], cwd=cwd, capture_output=True, text=True,
                             timeout=30).stdout.strip()
    except Exception:   # noqa: BLE001 - not in a checkout: nothing to confuse
        return None
    if top and Path(top).resolve() != REPO:
        return 2, (f"run_tests.py: you are in the worktree {top}, but without --repo this runs the main checkout "
                   f"{REPO}. Run: python {Path(__file__).resolve().as_posix()} --repo {Path(top).as_posix()}")
    return None


def mark_main_suite():
    """Main and merge-check suites hold main_<pid>.lock while they run, so lane suites take fewer slots."""
    fd = _try_lock(SLOTS_DIR / f"main_{os.getpid()}.lock")
    if fd is not None:
        _MAIN_MARK.append(fd)


def main_suite_running():
    for p in SLOTS_DIR.glob("main_*.lock"):
        if p.name == f"main_{os.getpid()}.lock":
            continue
        fd = _try_lock(p)
        if fd is None:
            if p.exists():
                return True
            continue
        _unlock(fd)
        try:
            p.unlink()   # its suite has ended
        except OSError:
            pass
    return False


def lane_slot():
    """Block until one of the shared lane test slots is free; returns its fd (None off Windows)."""
    if not LANE:
        return None
    try:
        import msvcrt  # noqa: F401
    except ImportError:
        return None
    waited = 0
    slow_only = "--slow-only" in sys.argv
    while True:
        n = SLOW_SLOTS if slow_only else LANE_SLOTS_BUSY if main_suite_running() else LANE_SLOTS_IDLE
        for i in range(n):
            fd = _try_lock(SLOTS_DIR / f"{'slow' if slow_only else 'lane'}_{i}.lock")
            if fd is not None:
                return fd
        time.sleep(1)
        waited += 1
        if waited % 30 == 0:
            note_progress()


def tree_fp(repo):
    """The same working-content fingerprint as controller.Relay.tree_fp (tests/test_suite_reuse.py keeps them equal)."""
    def git(*args):
        r = subprocess.run(["git", *args], cwd=repo, capture_output=True, text=True, encoding="utf-8",
                           errors="replace")
        return r.stdout.rstrip()
    h = hashlib.sha256(b'working-content-v2\0' + git("rev-parse", "HEAD").encode())
    changed = git('diff', 'HEAD', '--name-only', '-z').split('\0')
    untracked = git('ls-files', '--others', '--exclude-standard', '-z').split('\0')
    for rel in sorted(set(changed + untracked) - {''}):
        p = Path(repo) / rel
        h.update(rel.encode() + b'\0')
        h.update(b'FILE\0' + p.read_bytes() if p.is_file() else b'DELETED\0')
    return h.hexdigest()


def tree_state(repo):
    """(HEAD, {path: content sha256, or None if deleted}) for every file that differs from HEAD (changed or
    untracked), the same set tree_fp hashes."""
    def git(*args):
        r = subprocess.run(["git", *args], cwd=repo, capture_output=True, text=True, encoding="utf-8",
                           errors="replace")
        return r.stdout.rstrip()
    changed = git('diff', 'HEAD', '--name-only', '-z').split('\0')
    untracked = git('ls-files', '--others', '--exclude-standard', '-z').split('\0')
    files = {}
    for rel in sorted(set(changed + untracked) - {''}):
        p = Path(repo) / rel
        files[rel] = hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else None
    return git("rev-parse", "HEAD"), files


def declares_class(path):
    try:
        return bool(re.search(r"(?m)^\s*class_name\s", Path(path).read_text(encoding="utf-8", errors="replace")))
    except OSError:
        return False


def lane_state(repo):
    """Like tree_state, but the files also include everything committed on the lane branch since it left the main
    branch (relay.json main_branch), so a lane that committed its work still finds its related tests."""
    head, files = tree_state(repo)
    try:
        cfg = json.loads((Path(__file__).resolve().parent / "relay.json").read_text(encoding="utf-8"))
        main = cfg.get("main_branch", "master")
    except (OSError, ValueError):
        main = "master"
    r = subprocess.run(["git", "merge-base", "HEAD", main], cwd=repo, capture_output=True, text=True)
    base = r.stdout.strip()
    if r.returncode or not base:
        return head, files
    r = subprocess.run(["git", "diff", "--name-only", "-z", base, "HEAD"], cwd=repo, capture_output=True, text=True,
                       encoding="utf-8", errors="replace")
    out = dict.fromkeys(n for n in r.stdout.split("\0") if n)
    out.update(files)
    return head, out


def recent_merge_breakers(hours=24, min_fails=3, cap=10):
    """Tests that failed (rc=1) at least `min_fails` lane merge checks (cycles/_lane*/merge_*.txt) in the last
    `hours`, most frequent first. 2026-11-08: lane runs skipped them (the 50-seed cohort alone broke lanes 3, 6
    and 8 in cycles 603-606, each costing ~20 min of one-at-a-time merging), so lane runs now include them."""
    counts, cutoff = {}, time.time() - hours * 3600
    for f in (Path(__file__).resolve().parent / "cycles").glob("_lane*/merge_*.txt"):
        try:
            if f.stat().st_mtime < cutoff:
                continue
            text = f.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        for name in set(re.findall(r"^FAIL (\S+\.gd) \(rc=1,", text, re.M)):
            counts[name] = counts.get(name, 0) + 1
    picked = [n for n, c in sorted(counts.items(), key=lambda kv: -kv[1]) if c >= min_fails]
    return picked[:cap]


def lane_related_only(argv, env):
    """Owner 2026-11-05: lane runs leave the unrelated tests to the relay's merge check."""
    return LANE and "--slow-only" not in argv and env.get("RELAY_LANE_FULL") != "1" and not force_full(argv, env)


def main_related_only(argv, env):
    """Owner 2026-11-08: main-cycle runs leave the unrelated tests to the background slow check."""
    return (not LANE and "--repo" not in argv and "--slow-only" not in argv and env.get("RELAY_MAIN_FULL") != "1"
            and not force_full(argv, env))


def force_full(argv, env):
    """Owner 2026-10-18 (cycles under 30 min): coders in cycles 383, 385 and 386 added --full to "force a genuine full
    run" after a partial run, costing ~13 min each (386's build timed out in it). A partial run already reports the
    whole suite for the tree, so --full only counts with RELAY_FULL_OK=1 (a person debugging the runner)."""
    return "--full" in argv and env.get("RELAY_FULL_OK") == "1"


def load_last_full(repo):
    try:
        return json.loads(LAST_FULL_PATH.read_text(encoding="utf-8")).get(str(Path(repo).resolve()))
    except (OSError, ValueError, AttributeError):
        return None


def save_last_full(repo, state, failed, keep=10):
    """The last run's verdict for this repo's tree: every test passed except `failed`."""
    try:
        data = json.loads(LAST_FULL_PATH.read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            data = {}
    except (OSError, ValueError):
        data = {}
    tests = Path(repo) / "tests"
    data[str(Path(repo).resolve())] = {
        "head": state[0], "files": state[1], "failed": sorted(failed),
        "classes": sorted(t.name for t in tests.glob("*_test.gd") if declares_class(t)),
        "at": datetime.datetime.now().isoformat(timespec="seconds")}
    data = dict(sorted(data.items(), key=lambda kv: kv[1].get("at", ""))[-keep:])
    try:
        tmp = LAST_FULL_PATH.with_suffix(f".{os.getpid()}.tmp")
        tmp.write_text(json.dumps(data, indent=1), encoding="utf-8")
        os.replace(tmp, LAST_FULL_PATH)
    except OSError:
        pass


def used_elsewhere(repo, name):
    """Another test or script names this test file, so its change could alter their results: tests extend or
    preload other tests (mpw_live_party_low_lamp_crease_test extends mpw_live_party_crease_leak_test; comments
    naming it also count, to stay safe)."""
    pat = re.compile(r"(?<!\w)" + re.escape(name))
    for root in ("tests", "scripts"):
        for f in (Path(repo) / root).rglob("*.gd"):
            if f.name != name and pat.search(f.read_text(encoding="utf-8", errors="replace")):
                return True
    return False


def rerun_set(repo, state, rec, now=None):
    """The tests a partial run needs, or None when only a full run is sound. Owner 2026-10-14: cycle 234's coder
    fixed one test file after a 512/513 run and waited ~11 min for a full run of 513 tests to confirm it. Each test
    is its own script, so editing, adding or deleting a test file (one that names no class another test could use)
    changes only that test's result; anything else, a new commit or a record over 3 h old needs a full run."""
    try:
        if not rec or rec["head"] != state[0]:
            return None
        age = ((now or datetime.datetime.now()) - datetime.datetime.fromisoformat(rec["at"])).total_seconds()
        if not 0 <= age <= PARTIAL_MAX_AGE_S:
            return None
        old, new = rec["files"], state[1]
        tests = {n for n in rec["failed"] if (Path(repo) / "tests" / n).is_file()}
        for rel in set(old) | set(new):
            if old.get(rel) == new.get(rel):
                continue
            m = re.fullmatch(r"tests/([^/]+_test\.gd)(\.uid)?", rel)
            if not m or m.group(1) in rec["classes"] or used_elsewhere(repo, m.group(1)):
                return None
            q = Path(repo) / "tests" / m.group(1)
            if q.is_file():
                if declares_class(q):
                    return None
                tests.add(m.group(1))
        return sorted(tests)
    except (KeyError, TypeError, ValueError, AttributeError):
        return None


def related_tests(repo, state, all_tests, known, max_share=RELATED_MAX_SHARE):
    """The tests most likely to break from the uncommitted changes, to run before the rest: changed test files, and
    tests naming a changed file by res:// path, file stem (word-bounded: rootgate_hollow, not rootgate_hollow_2) or
    the class_name it declares. [] when nothing matches, everything matches, or the set would take more than
    max_share of the suite's time (then splitting the run gains little)."""
    try:
        names, terms = set(), set()
        for rel in state[1]:
            if rel.startswith((".review/", ".godot/")):
                continue
            base = rel[:-4] if rel.endswith(".uid") else rel
            m = re.fullmatch(r"tests/([^/]+_test\.gd)", base)
            if m and m.group(1) in all_tests:
                names.add(m.group(1))
            p = Path(repo) / base   # a test's own name too: other tests extend or preload it
            terms.add(re.escape("res://" + base))
            terms.add(r"(?<![A-Za-z0-9_])" + re.escape(p.stem) + r"(?![A-Za-z0-9_])")
            if base.endswith(".gd") and p.is_file():
                c = re.search(r"(?m)^\s*class_name\s+(\w+)", p.read_text(encoding="utf-8", errors="replace"))
                if c:
                    terms.add(r"(?<![A-Za-z0-9_])" + re.escape(c.group(1)) + r"(?![A-Za-z0-9_])")
        if terms:
            pat = re.compile("|".join(sorted(terms)))
            for n in all_tests:
                if n not in names and pat.search((Path(repo) / "tests" / n).read_text(encoding="utf-8",
                                                                                       errors="replace")):
                    names.add(n)
        cost = lambda ns: sum(known.get(n, 10.0) for n in ns)   # noqa: E731
        if not names or len(names) >= len(all_tests) or cost(names) > max_share * cost(all_tests):
            return []
        return sorted(names)
    except (OSError, TypeError, IndexError, re.error):
        return []


def parent_chain(depth=5):
    """Executable names above this process, nearest first (Windows; [] elsewhere). Owner 2026-10-14: cycle 238 had
    a second main-suite start on the coder's tree that the coder never ran; this says who starts them."""
    try:
        import ctypes
        from ctypes import wintypes

        class Entry(ctypes.Structure):
            _fields_ = [("dwSize", wintypes.DWORD), ("cntUsage", wintypes.DWORD), ("th32ProcessID", wintypes.DWORD),
                        ("th32DefaultHeapID", ctypes.c_size_t), ("th32ModuleID", wintypes.DWORD),
                        ("cntThreads", wintypes.DWORD), ("th32ParentProcessID", wintypes.DWORD),
                        ("pcPriClassBase", ctypes.c_long), ("dwFlags", wintypes.DWORD),
                        ("szExeFile", ctypes.c_char * 260)]
        k = ctypes.windll.kernel32
        k.CreateToolhelp32Snapshot.restype = wintypes.HANDLE
        k.Process32First.argtypes = k.Process32Next.argtypes = [wintypes.HANDLE, ctypes.POINTER(Entry)]
        k.CloseHandle.argtypes = [wintypes.HANDLE]
        snap = k.CreateToolhelp32Snapshot(2, 0)   # TH32CS_SNAPPROCESS
        procs, e = {}, Entry()
        e.dwSize = ctypes.sizeof(Entry)
        ok = k.Process32First(snap, ctypes.byref(e))
        while ok:
            procs[e.th32ProcessID] = (e.th32ParentProcessID, e.szExeFile.decode(errors="replace"))
            ok = k.Process32Next(snap, ctypes.byref(e))
        k.CloseHandle(snap)
    except Exception:   # noqa: BLE001 - diagnostics only
        return []
    out, pid = [], os.getpid()
    for _ in range(depth):
        pid = procs.get(pid, (0, ""))[0]
        if not pid or pid not in procs:
            break
        out.append(procs[pid][1])
    return out


def note_suite_start(repo, keep=20):
    """Owner 2026-10-14: the relay starts its final review when the coder starts a full main-suite run on the tree
    it will hand over (controller.start_pre_final_watch reads suite_starts.json)."""
    try:
        data = json.loads(STARTS_PATH.read_text(encoding="utf-8"))
        if not isinstance(data, list):
            data = []
    except (OSError, ValueError):
        data = []
    try:
        data.append({"repo": str(Path(repo).resolve()), "fp": tree_fp(repo), "pid": os.getpid(),
                     "at": datetime.datetime.now().isoformat(timespec="seconds"), "parents": parent_chain()})
        tmp = STARTS_PATH.with_suffix(f".{os.getpid()}.tmp")
        tmp.write_text(json.dumps(data[-keep:], indent=1), encoding="utf-8")
        os.replace(tmp, STARTS_PATH)
    except Exception:   # noqa: BLE001 - an optimisation only
        pass


def record_pass(fp, repo, summary, keep=80):
    try:
        data = json.loads(PASSES_PATH.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        data = {}
    data[fp] = {"repo": str(Path(repo).resolve()), "at": datetime.datetime.now().isoformat(timespec="seconds"),
                "summary": summary}
    data = dict(sorted(data.items(), key=lambda kv: kv[1].get("at", ""))[-keep:])
    tmp = PASSES_PATH.with_suffix(f".{os.getpid()}.tmp")
    tmp.write_text(json.dumps(data, indent=1), encoding="utf-8")
    os.replace(tmp, PASSES_PATH)


def watch_parent(interval=15):
    """Stop when the parent dies: nobody reads the result, and the orphan competes for CPU. A lane7 suite kept
    running after a controller restart beside its replacement (2026-10-13). A run whose stdout is a file (started
    detached on purpose) keeps going, except the slow check: its log is a file too, and after a restart it ran on
    beside the restarted check in the same worktree (2026-10-18)."""
    try:
        import psutil
        if stat.S_ISREG(os.fstat(sys.stdout.fileno()).st_mode) and "--slow-only" not in sys.argv:
            return
        parent = psutil.Process(os.getppid())
    except ImportError:
        return
    except psutil.NoSuchProcess:   # 2026-10-19: the parent halted a second after starting this slow check
        os._exit(3)
    except Exception:   # noqa: BLE001 - best effort
        return

    def loop():
        while True:
            time.sleep(interval)
            try:
                alive = parent.is_running() and parent.status() != psutil.STATUS_ZOMBIE
            except psutil.Error:
                alive = False
            if not alive:
                for c in psutil.Process().children(recursive=True):
                    try:
                        c.kill()
                    except psutil.Error:
                        pass
                os._exit(3)

    threading.Thread(target=loop, name="watch-parent", daemon=True).start()


def kill_tree(pid):
    subprocess.run(["taskkill", "/F", "/T", "/PID", str(pid)], capture_output=True)


# 2026-11-09: every worktree's tests shared one user:// (APPDATA/Godot/app_userdata/Patchwork Pioneers), so the same
# live test running in the main suite and a lane merge check at once overwrote each other's save between Save and
# read-back (fresh_stuffing 7, tonic 5, dye/moth 2 "flaky" failures; 8/8 clean alone). Each test now gets its own
# fresh APPDATA per worktree, so user:// never carries state between tests or between parallel suites.
USER_DIRS = Path("C:/rtg/g/pp/godot_appdata/tests")


def test_env(name):
    """os.environ with APPDATA pointing at a fresh user:// for this test in this worktree."""
    tag = hashlib.sha1(str(REPO).lower().encode()).hexdigest()[:10]
    root = USER_DIRS / tag / Path(name).stem
    shutil.rmtree(root, ignore_errors=True)
    root.mkdir(parents=True, exist_ok=True)
    return dict(os.environ, APPDATA=str(root))


def run_capped(argv, timeout, env=None):
    """(returncode or None on timeout, output). On a timeout the whole process TREE is killed: Godot's _console.exe
    wrapper starts the real Godot as a child that holds the output pipes, so subprocess.run killed only the wrapper
    and then waited forever for the pipes to close. One hung test hung the suite for good and leaked a Godot per
    retry (lane4 m08f_rest_fortify_live_battle_test, 2026-10-11)."""
    p = subprocess.Popen(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, encoding="utf-8",
                         errors="replace", env=env)
    try:
        out, err = p.communicate(timeout=timeout)
        return p.returncode, out + err
    except subprocess.TimeoutExpired:
        kill_tree(p.pid)
        try:
            out, err = p.communicate(timeout=30)
        except subprocess.TimeoutExpired:
            out, err = "", ""
        return None, (out or "") + (err or "")


def limit(name):
    """A test known to take 136 s alone timed out at 180 s under a busy CPU and deferred cycle 196 (2026-10-13), so a
    known-slow test gets 3x its usual time (at most 600 s). Timed-out runs are never recorded, so a real hang keeps
    the plain limit. 2026-10-19: the slow check runs in the background beside a cycle's build and merge suites;
    mpw_live_desk_curio_selection_test (57-80 s alone) hit 180 s there twice (parallel, then alone) and was owed to
    cycle 426 although it passed alone in 77 s. The slow check is off the critical path, so its limits are doubled."""
    base = max(PER_TEST_TIMEOUT, min(600, round(3 * KNOWN.get(name, 0))))
    return min(900, 2 * base) if "--slow-only" in sys.argv else base


def lower_priority():
    """Lane suites (--repo) run below normal priority, inherited by Godot, so the main cycle's suite (the critical
    path) gets the CPU first when lanes and main test at once (CPU at 97%, 2026-10-13)."""
    if os.name == "nt":
        try:
            import ctypes
            k = ctypes.windll.kernel32
            k.GetCurrentProcess.restype = ctypes.c_void_p
            k.SetPriorityClass.argtypes = (ctypes.c_void_p, ctypes.c_uint32)
            k.SetPriorityClass(k.GetCurrentProcess(), 0x4000)   # BELOW_NORMAL_PRIORITY_CLASS
        except (AttributeError, OSError):
            pass


class PassJournal:
    """The tests that passed on one tree (by tree_fp), so an interrupted run's successor on the identical tree skips
    them. Passes are written at most every `interval` seconds and only while the tree still has the fingerprint the
    run started with; once it changes (a coder editing mid-run) the journal stops for this run."""

    def __init__(self, fp, repo, interval=60.0):
        self.fp, self.repo, self.interval = fp, repo, interval
        self.path = RESUME_DIR / f"{fp[:40]}.json" if fp else None
        self.pending, self.lock, self.last, self.off = [], threading.Lock(), time.monotonic(), not fp

    def done_before(self):
        if self.off:
            return set()
        try:
            d = json.loads(self.path.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            return set()
        if d.get("fp") != self.fp or time.time() - float(d.get("at", 0)) > RESUME_MAX_AGE_S:
            return set()
        return set(d.get("passed", []))

    def add(self, name):
        if self.off:
            return
        with self.lock:
            self.pending.append(name)
            if time.monotonic() - self.last >= self.interval:
                self._flush()

    def flush(self):
        with self.lock:
            self._flush()

    def _flush(self):
        self.last = time.monotonic()
        if self.off or not self.pending:
            return
        try:
            if tree_fp(self.repo) != self.fp:
                self.off = True
                return
            RESUME_DIR.mkdir(exist_ok=True)
            tmp = self.path.with_suffix(f".{os.getpid()}.tmp")
            tmp.write_text(json.dumps({"fp": self.fp, "at": time.time(),
                                       "passed": sorted(self.done_before() | set(self.pending))}), encoding="utf-8")
            os.replace(tmp, self.path)
            self.pending = []
        except Exception:   # noqa: BLE001 - resuming is an optimisation only
            self.off = True


def prune_journals(now=None):
    now = now or time.time()
    try:
        for p in RESUME_DIR.glob("*.json"):
            if now - p.stat().st_mtime > RESUME_MAX_AGE_S:
                p.unlink()
    except OSError:
        pass


def slow_tier(known, all_tests, cutoff=SLOW_TIER_S):
    """Tests whose last measured time is over `cutoff` seconds; new tests (no time yet) are never in it."""
    return sorted(n for n in all_tests if float(known.get(n, 0) or 0) > cutoff)


def load_pending():
    """slow_pending.json: tests a main-checkout suite deferred to the slow check that it has not run since.
    2026-10-18: cycle 405's suite deferred the ink-price test, then lane runs lowered its stored time, so the slow
    check's own tier (recomputed from the times) was empty: it ran 0 tests, passed, and master's real failure surfaced
    only as lane merges failing one after another."""
    try:
        d = json.loads(PENDING_PATH.read_text(encoding="utf-8"))
        return [n for n in d if isinstance(n, str)] if isinstance(d, list) else []
    except (OSError, ValueError):
        return []


def update_pending(add=(), remove=()):
    names = (set(load_pending()) | set(add)) - set(remove)
    try:
        tmp = PENDING_PATH.with_suffix(f".{os.getpid()}.tmp")
        tmp.write_text(json.dumps(sorted(names), indent=1) + "\n", encoding="utf-8")
        os.replace(tmp, PENDING_PATH)
    except OSError:
        pass


def load_owed():
    """slow_owed.json: {"tests": [...], "commit", "cycle", "log", "at"}; {} when nothing is owed."""
    try:
        d = json.loads(OWED_PATH.read_text(encoding="utf-8"))
        return d if isinstance(d, dict) and d.get("tests") else {}
    except (OSError, ValueError):
        return {}


def excuses_owed(argv, env):
    return "--repo" in argv or env.get("RELAY_EXCUSE_OWED") == "1"


def run_one(name):
    slot = lane_slot()   # waiting for a slot is not test time
    try:
        start = time.monotonic()
        cap = limit(name)
        rc, out = run_capped([GODOT, "--headless", "--path", str(REPO), "-s", f"res://tests/{name}"], cap,
                             test_env(name))
        DURATIONS[name] = round(time.monotonic() - start, 1)
    finally:
        if slot is not None:
            _unlock(slot)
        note_progress(name)
    if rc is None:
        TIMED_OUT.add(name)
        return True, f"timeout after {cap}s (hung: a loop that never ends or a missing quit())", out
    bad = rc != 0 or any(m in out for m in ERR_MARKERS)
    if not bad and JOURNAL[0] is not None:
        JOURNAL[0].add(name)
    return bad, f"rc={rc}, {DURATIONS[name]}s", out


REGRESSION_AT = 3


def settle(tests, results):
    """Print each test's verdict and return the failed names. A parallel failure is confirmed alone first. Owner
    2026-10-13: cycle 231's coder broke 11 tests; each was run alone and then retried twice more, one at a time,
    ~8 min before the coder saw the result. When REGRESSION_AT or more tests also fail alone, that is a real
    regression, not flakiness, so they are not retried."""
    for name in tests:
        bad, why, out = results[name]
        if bad and WORKERS > 1:   # parallel failure: confirm it alone before believing it
            bad, why2, out2 = run_one(name)
            results[name] = ((False, f"passed when re-run alone; failed in the parallel pass with {why}", out2)
                             if not bad else (True, why2, out2))
    real = [n for n in tests if results[n][0]]
    retries = RETRIES if len(real) < REGRESSION_AT else 0
    if real and not retries:
        print(f"{len(real)} tests fail when run alone: a real regression, so they are not retried", flush=True)
    failed = []
    for name in tests:
        bad, why, out = results[name]
        if not bad:
            print(f"PASS {name} ({why})", flush=True)
            continue
        # A test that hung twice is a real hang, not flakiness: two more 180 s retries pushed the lane suite past its
        # 20-minute cap, so the coder never saw the failure (lane4, 2026-10-11).
        hung = why.startswith("timeout") and WORKERS > 1
        if not hung and any(not run_one(name)[0] for _ in range(retries)):   # stops at the first passing retry
            print(f"FLAKY {name} (failed with {why}, passed on retry)", flush=True)
            print(indent(out, 15), flush=True)
            record_flaky(name, out)
            continue
        print(f"FAIL {name} ({why})", flush=True)
        failed.append(name)
        print(indent(out, 40), flush=True)
    return failed


def load_times():
    try:
        return json.loads(TIMES_PATH.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def save_times(measured):
    """Merge this run's per-test seconds into test_times.json (lanes and main share it; a lost race only drops
    one run's update)."""
    data = load_times()
    # 2026-10-18: lane3's sped-up copy of m08f_live_psychology_ink_prices_test.gd recorded 22 s over master's
    # 160-240 s, so master's cap fell from 3x to the plain 180 s and the test timed out (cycle 406 deferred). A
    # faster run lowers the known time by at most 30% per run; a real speedup still settles within a few runs.
    for name, sec in measured.items():
        old = data.get(name)
        data[name] = max(sec, round(0.7 * old, 1)) if isinstance(old, (int, float)) and sec < old else sec
    try:
        tmp = TIMES_PATH.with_suffix(f".{os.getpid()}.tmp")
        tmp.write_text(json.dumps(data, indent=1, sort_keys=True), encoding="utf-8")
        os.replace(tmp, TIMES_PATH)
    except OSError:
        pass


def record_flaky(name, out):
    try:
        data = json.loads(FLAKY_PATH.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        data = {}
    entry = data.get(name, {"count": 0})
    entry["count"] += 1
    entry["last"] = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    entry["failure_tail"] = out.strip().splitlines()[-25:]
    data[name] = entry
    FLAKY_PATH.write_text(json.dumps(data, indent=2), encoding="utf-8")


def indent(text, n):
    return "\n".join("    " + l for l in text.strip().splitlines()[-n:])


if __name__ == "__main__":
    _bad = arg_problem(sys.argv[1:], Path.cwd())
    if _bad:
        print(_bad[1], flush=True)
        sys.exit(_bad[0])
    if LANE:   # the lane-merge check is not a lane
        lower_priority()
    else:
        mark_main_suite()
    watch_parent()
    try:
        fp_start = tree_fp(REPO)
        state = tree_state(REPO)
    except Exception:   # noqa: BLE001 - reuse is an optimisation only
        fp_start = state = None
    # Refresh the global class cache so newly added `class_name` scripts resolve.
    if run_capped([GODOT, "--headless", "--path", str(REPO), "--import"], 300)[0] is None:
        print("WARN: class cache import timed out", flush=True)

    main_run = not LANE and "--repo" not in sys.argv
    # Owner 2026-11-07 ("speed it up"): the in-cycle lane-merge check (--repo --normal-priority) ran the slow tier too
    # and hit its 30-min cap (cycle 574: 3 lanes taken off master, +60 min); it defers them like a main run.
    merge_check = "--repo" in sys.argv and "--normal-priority" in sys.argv
    all_tests = sorted(t.name for t in (REPO / "tests").glob("*_test.gd"))
    tests, partial = all_tests, None
    if "--full" in sys.argv and not force_full(sys.argv, os.environ):
        print("NOTE: --full is ignored; a partial run below is the full-suite result for this tree (the relay "
              "accepts it), so do not try to force a complete run.", flush=True)
    if not LANE and state and not force_full(sys.argv, os.environ) and all_tests:
        rec = load_last_full(REPO)
        partial = rerun_set(REPO, state, rec)
        if partial is not None:
            tests = partial
            print(f"PARTIAL RUN: only test files changed since the full run at {rec['at'][11:16]} on this commit, so "
                  f"only {len(partial)} tests run (changed, or failed there): {', '.join(partial) or 'none'}. The "
                  f"other {len(all_tests) - len(partial)} passed there and nothing they run has changed. "
                  "This is the full-suite result for this tree; report it as the full-suite run.", flush=True)
    if fp_start and not force_full(sys.argv, os.environ):
        prune_journals()
        JOURNAL[0] = PassJournal(fp_start, REPO)
        done = JOURNAL[0].done_before() & set(tests)
        if done and "--slow-only" not in sys.argv:   # the slow check prints its own resume note below
            tests = [t for t in tests if t not in done]
            print(f"RESUMED: {len(done)} tests already passed on this identical tree in an earlier run that was "
                  f"interrupted (nothing has changed since), so only the other {len(tests)} run. Re-running on an "
                  "unchanged tree always resumes like this. This is the full-suite result for this tree.", flush=True)
    # Longest first (unknown = new tests, assumed slow): a 2-minute test started last stretched the whole suite.
    known = load_times()
    KNOWN.update(known)
    owed = load_owed()
    owed_tests = [n for n in owed.get("tests", []) if n in set(all_tests)]
    slow_only = "--slow-only" in sys.argv
    deferred = []
    if slow_only:
        pending = [n for n in load_pending() if n in set(all_tests)]
        slow_set = sorted(set(slow_tier(known, all_tests)) | set(owed_tests) | set(pending))
        # 2026-10-19: the slow checks of cycles 428, 429 and 432 each timed out after 30 min beside a busy main suite;
        # the retries started all ~20 tests again, because this list replaced the resumed one. Tests that already
        # passed on this identical commit in an interrupted check are skipped, so each retry gets further.
        done = JOURNAL[0].done_before() & set(slow_set) if JOURNAL[0] is not None else set()
        tests = [n for n in slow_set if n not in done]
        partial = []   # never recorded as a full-suite result
        print(f"SLOW CHECK: running the {len(tests)} slow-tier tests (over {SLOW_TIER_S}s) and owed tests"
              + (f" ({len(done)} more already passed on this commit in an interrupted check)." if done else "."),
              flush=True)
    elif main_run and owed_tests and not excuses_owed(sys.argv, os.environ):
        print(f"OWED SLOW TESTS: {', '.join(owed_tests)} failed on {owed.get('commit', '?')[:8]} (cycle "
              f"{owed.get('cycle', '?')}) in the relay's background slow check ({owed.get('log', 'no log')}). They "
              "run in this suite and must pass before this cycle can be accepted: fix them as part of this cycle.",
              flush=True)

    def drop_owed(failed):
        """Lane, merge and baseline runs do not fail on tests the slow check found failing on main already."""
        if not (failed and owed_tests and not slow_only and excuses_owed(sys.argv, os.environ)):
            return failed
        excused = [n for n in failed if n in set(owed.get("tests", []))]
        if excused:
            print(f"\nEXCUSED: {', '.join(excused)} already fail on the main branch ({owed.get('commit', '?')[:8]}, "
                  "found by the relay's slow check); they do not fail this run.", flush=True)
        return [n for n in failed if n not in set(excused)]

    def run_pass(names):
        order = sorted(names, key=lambda n: -known.get(n, 1e9))
        with ThreadPoolExecutor(max_workers=WORKERS) as pool:
            got = dict(zip(order, pool.map(run_one, order)))
        return got, {n: s for n, s in DURATIONS.items() if n not in TIMED_OUT}

    # Owner 2026-11-08: main runs keep any related set (max_share 1.0); the rest go to the background check.
    related = (related_tests(REPO, state, all_tests, known, max_share=1.0 if main_related_only(sys.argv, os.environ)
                             else RELATED_MAX_SHARE) if partial is None and state else [])
    related = [n for n in related if n in set(tests)]
    lane_rel = []
    if lane_related_only(sys.argv, os.environ) and partial is None and all_tests:
        try:
            lane_rel = related_tests(REPO, lane_state(REPO), all_tests, known, max_share=1.0)
        except Exception:   # noqa: BLE001 - fall back to the full suite
            lane_rel = []
    breakers = []
    if lane_rel:
        try:
            breakers = [n for n in recent_merge_breakers() if n in set(all_tests) and n not in set(lane_rel)]
        except Exception:   # noqa: BLE001 - the lane-related set alone still runs
            breakers = []
        lane_rel += breakers
    if lane_rel:
        todo = [n for n in lane_rel if n in set(tests)]
        if breakers:
            print(f"LANE RUN: also running {len(breakers)} tests that broke recent lane merges: "
                  f"{', '.join(breakers)}. Fix them here if they fail; they fail the merge check otherwise.",
                  flush=True)
        print(f"LANE RUN: {len(lane_rel)} tests use files this lane changed; only they run here ({len(todo)} not "
              f"already passed on this tree). The other {len(all_tests) - len(lane_rel)} run in the relay's merge "
              "check on the merged result after the lane is accepted, so do not run them yourself or try to force "
              "them. This is the lane's full test result.", flush=True)
        results, first_pass = run_pass(todo)
        failed = drop_owed(settle(todo, results))
        if JOURNAL[0] is not None:
            JOURNAL[0].flush()
        save_times(first_pass)
        print(f"\n{len(lane_rel) - len(failed)}/{len(lane_rel)} lane-related tests passed "
              f"({len(all_tests) - len(lane_rel)} left to the merge check)")
        if fp_start and not failed:
            try:
                if tree_fp(REPO) == fp_start:
                    record_pass(fp_start, REPO, f"{len(lane_rel)}/{len(lane_rel)} lane-related tests passed")
            except Exception:   # noqa: BLE001
                pass
        sys.exit(1 if failed else 0)
    if ((main_run or merge_check) and partial is None and not force_full(sys.argv, os.environ)
            and os.environ.get("RELAY_DEFER_SLOW", "1") != "0"):
        deferred = [n for n in slow_tier(known, tests) if n not in set(related) | set(owed_tests)]
        if deferred:
            update_pending(add=deferred)
            tests = [n for n in tests if n not in set(deferred)]
            print(f"SLOW TIER DEFERRED: {len(deferred)} slow tests that use none of the files you changed run in the "
                  "relay's background slow check after this cycle is accepted, not here: "
                  f"{', '.join(deferred)}. This run is the full-suite result for this tree; do not run them yourself "
                  "or try to force them.", flush=True)
    if main_run and related and partial is None and main_related_only(sys.argv, os.environ):
        # Owner 2026-11-08 ("it should be faster than 30 min since its not testing the entire game"): cycle 619
        # took 109 min with ~9 min full suites per try. A main run now tests only the files it changed (plus owed
        # tests and recent lane-merge breakers); the other tests run in the background slow check on the accepted
        # commit, and their failures become owed tests the next cycle must fix.
        try:
            extra = [n for n in recent_merge_breakers() if n in set(tests) and n not in set(related)]
        except Exception:   # noqa: BLE001 - the related set alone still runs
            extra = []
        keep = set(related) | set(owed_tests) | set(extra)
        left_out = [n for n in tests if n not in keep]
        if left_out:
            update_pending(add=left_out)
            tests = [n for n in tests if n in keep]
            deferred = list(deferred or []) + left_out
            print(f"MAIN RELATED ONLY: {len(related)} tests use files you changed; they run here with "
                  f"{len(tests) - len(related)} owed or recent-breaker tests. The other {len(left_out)} run in the "
                  "relay's background check after this cycle is accepted, so do not run them yourself or try to "
                  "force them. This run is the cycle's full test result.", flush=True)
    if main_run and not related:   # after the import, which can add .uid files
        note_suite_start(REPO)
    if related:
        print(f"RELATED FIRST: {len(related)} tests use files you changed, so they run before the other "
              f"{len(tests) - len(related)}: {', '.join(related)}", flush=True)
        results, first_pass = run_pass(related)
        failed = drop_owed(settle(related, results))
        if JOURNAL[0] is not None:
            JOURNAL[0].flush()
        if failed:
            save_times(first_pass)
            print(f"\nRELATED TESTS FAILED FIRST: {len(failed)} of the {len(related)} tests that use files you changed "
                  f"failed, so the other {len(tests) - len(related)} tests did not run. Fix these, then run the "
                  "full suite again.", flush=True)
            print(f"\n{len(related) - len(failed)}/{len(related)} related tests passed "
                  f"({len(tests) - len(related)} not run)")
            sys.exit(1)
        if main_run:   # the review of the finished tree starts once the tests most likely to break pass
            note_suite_start(REPO)
        rest = [n for n in tests if n not in set(related)]
        more, first_pass = run_pass(rest)
        failed = settle(rest, more)
    else:
        results, first_pass = run_pass(tests)
        failed = settle(tests, results)

    if JOURNAL[0] is not None:
        JOURNAL[0].flush()
    failed = drop_owed(failed)
    save_times(first_pass)
    slow = sorted(first_pass.items(), key=lambda kv: -kv[1])[:8]
    if slow:
        print("\nslowest: " + ", ".join(f"{n} {s}s" for n, s in slow), flush=True)
    if slow_only:
        update_pending(remove=slow_set)   # ran on the accepted commit: its failures go to slow_owed.json
        print(f"\nSLOW CHECK: {len(slow_set) - len(failed)}/{len(slow_set)} slow tests passed")
        print("SLOW FAILED: " + " ".join(failed), flush=True)
        sys.exit(1 if failed else 0)
    # a partial run reports the whole suite: the tests it skipped passed on this commit and are unchanged
    print(f"\n{len(all_tests) - len(failed)}/{len(all_tests)} passed")
    if deferred:
        print(f"({len(deferred)} slow-tier tests deferred to the relay's background slow check)", flush=True)
    if not all_tests:
        print("no tests found")
        sys.exit(1)
    if fp_start:
        try:
            if tree_fp(REPO) == fp_start:
                if not LANE:
                    save_last_full(REPO, state, failed)
                # Owner 2026-10-14: lane runs too, so the lane checker reuses the lane coder's last passing run.
                if not failed:
                    record_pass(fp_start, REPO, f"{len(all_tests)}/{len(all_tests)} passed")
        except Exception:   # noqa: BLE001
            pass
    sys.exit(1 if failed else 0)
