"""
ChatGPT chat-mode bridge. Drives chatgpt.com in your own logged-in Chrome over CDP.
Each ask() opens a fresh chat in a new tab, sends the prompt, waits for the reply
to finish streaming, returns its text, and closes the tab.
"""
from __future__ import annotations

import json
import os
import re
import threading
import time
from pathlib import Path
from typing import Callable

from playwright.sync_api import Error as PWError
from playwright.sync_api import sync_playwright


# "Connection interrupted. Waiting for the complete answer" is recoverable: ChatGPT keeps working server-side, so
# it is not an error; the idle/frozen timers (and file mode's done check) handle a reply that really stalls.
ERROR_RE = re.compile(r"Something went wrong|A network error occurred|"
                      r"There was an error generating a response|Error in message stream", re.I)


COMPARE_RE = re.compile(r"Which (option|response) do you prefer", re.I)

# Owner 2026-10-16: cycle 331's final review prompt was never delivered ("Message delivery timed out. Please try
# again." with a Retry button). Nothing streamed, so the bridge waited its 15-min idle limit and then reloaded, which
# never resends the prompt: ~25 min lost on the critical path. Now the page's own Retry resends it.
UNDELIVERED_RE = re.compile(r"Message delivery timed out|Message (failed to send|not sent)|Failed to send message", re.I)


def resend_undelivered(page, log) -> bool:
    """Click Retry when ChatGPT says the prompt was not delivered. True if it clicked."""
    try:
        if not page.get_by_text(UNDELIVERED_RE).count():
            return False
        retry = page.get_by_role("button", name="Retry", exact=True)
        if not retry.count():
            return False
        retry.last.click(timeout=10_000)   # the banner's own button is the last one on the page
    except PWError:
        return False
    log("chatgpt did not deliver the prompt (\"Message delivery timed out\"); clicked Retry")
    return True


USER_SEL = '[data-content-search-unit-key$=":user"]'


def prompt_posted(page, sel: dict, n: int, before: int, streaming: bool) -> bool:
    """True once the chat shows any sign of our prompt: a reply, streaming, a /c/ conversation URL or a user turn."""
    if n > before or streaming or "/c/" in (page.url or ""):
        return True
    try:
        return page.locator(sel.get("user", USER_SEL)).count() > 0
    except PWError:
        return True   # cannot tell; never fail an ask on a page that is mid-navigation

# Work mode has its own usage cap. When ChatGPT says it ran out, Work runs fall back to Chat mode for a few hours
# (owner 2026-10-08: "fall back to chat mode if it runs out, then back to work after 5 hours"). The pause is kept in
# a file so every lane thread and a relay restart see it.
# Real notice (owner screenshot 2026-10-08): "You're out of Work usage for now / Upgrade or add credits to keep using
# Work now, or wait for your usage to reset at 5:14 PM".
WORK_LIMIT_RE = re.compile(
    r"out of work usage|usage to reset at|"
    r"you(?:'|\u2019)?ve (?:hit|reached|used)[^.\n]{0,60}limit|"
    r"(?:usage|work|agent)[^.\n]{0,20}limit (?:reached|resets|will reset)|limit resets|"
    r"out of (?:work|agent)[^.\n]{0,30}(?:usage|uses|messages|tasks|runs)|try again (?:after|in) \d", re.I)
WORK_RESET_RE = re.compile(r"reset(?:s)? at (\d{1,2}):(\d{2})\s*([AP]\.?M\.?)?", re.I)
WORK_LIMIT_FILE = Path(__file__).resolve().parent / "logs" / "chatgpt_work_limited_until.txt"


def work_reset_time(notice: str, now: float | None = None) -> float | None:
    """The epoch time of "reset at 5:14 PM" in the notice (today, or tomorrow if that time has passed), or None."""
    import datetime
    m = WORK_RESET_RE.search(notice or "")
    if not m:
        return None
    hour, minute, ampm = int(m.group(1)), int(m.group(2)), (m.group(3) or "").upper().replace(".", "")
    if ampm == "PM" and hour < 12:
        hour += 12
    elif ampm == "AM" and hour == 12:
        hour = 0
    if hour > 23 or minute > 59:
        return None
    base = datetime.datetime.fromtimestamp(now if now is not None else time.time())
    at = base.replace(hour=hour, minute=minute, second=0, microsecond=0)
    if at <= base:
        at += datetime.timedelta(days=1)
    return at.timestamp() + 120   # a little after the reset


def work_limited_until() -> float:
    try:
        return float(WORK_LIMIT_FILE.read_text(encoding="utf-8").strip())
    except (OSError, ValueError):
        return 0.0


# One tab at a time goes from choosing Chat/Work to pressing Send. ChatGPT keeps the Chat/Work choice per account, so a
# second tab picking Work (lane4) a second after another picked Chat (lane3) flipped the first tab to Work before it
# sent (owner saw lanes 3 and 4 both in Work, 2026-10-09).
_MODE_LOCK = threading.RLock()

# Owner 2026-10-10: many more parallel Chat messages (planners, coders, reviewers). A cap on open conversations keeps
# Chrome and ChatGPT from being flooded; extra asks wait for a free slot (chatgpt.max_concurrent).
_SLOTS: threading.BoundedSemaphore | None = None
_SLOTS_LOCK = threading.Lock()
CHROME_HANGS = Path(__file__).resolve().with_name("chrome_hangs.json")   # hung-Chrome restarts (controller: PC restart)
_RESTART_LOCK = threading.Lock()   # one hung-Chrome restart at a time across the per-thread bridges
_LAST_RESTART = [0.0]


# Owner 2026-10-10: 15 tabs piled up. Tabs of asks cut off by a halt/restart were never closed. Every open ask
# registers its tab here; close_stale_tabs() closes ChatGPT tabs no ask in this process owns.
_ACTIVE_TARGETS: set = set()
_STALE_SEEN: dict = {}

# Owner 2026-10-17: ChatGPT images (art_runner, a separate process) take up to 7 min, longer than the janitor's 4-min
# grace for other processes' tabs. Such a tab is held in this file (target id -> expiry) and never closed meanwhile.
HELD_TABS = Path(__file__).resolve().with_name("chatgpt_held_tabs.json")


# Owner 2026-10-21 "I dont think the archiving is working": finished chats were archived, but a chat whose ask
# failed, timed out or was cut off by a halt never was, and they piled up in the sidebar. Every relay chat left
# unarchived is listed here (chat id -> first seen, tries); later asks archive a few (sweep_unarchived). Only ids
# the relay itself opened are ever listed, so the owner's own chats are never touched.
UNARCHIVED = Path(__file__).resolve().parent / "logs" / "chatgpt_unarchived.json"
_UNARCHIVED_LOCK = threading.Lock()


def chat_id(url: str) -> str:
    return url.split("/c/", 1)[1].split("?")[0].split("#")[0].split("/")[0] if "/c/" in (url or "") else ""


def _unarchived() -> dict:
    try:
        d = json.loads(UNARCHIVED.read_text(encoding="utf-8"))
        return d if isinstance(d, dict) else {}
    except (OSError, ValueError):
        return {}


def note_unarchived(cid: str, tried: bool = False, open_: bool = False) -> None:
    """open_: the ask is still running in this process (listed as soon as its chat exists, so an ask that never
    gets to archive - a killed lane, a halt - is still listed); the sweep leaves it alone while this process lives."""
    if not cid or cid.startswith("local-"):   # an unsaved chat's placeholder id: nothing to archive
        return
    with _UNARCHIVED_LOCK:
        d = _unarchived()
        e = d.setdefault(cid, {"t": time.time(), "tries": 0})
        if tried:
            e["tries"] = int(e.get("tries", 0)) + 1
        if open_:
            e["open"] = os.getpid()
        else:
            e.pop("open", None)
        try:
            UNARCHIVED.parent.mkdir(parents=True, exist_ok=True)
            UNARCHIVED.write_text(json.dumps(d, indent=1), encoding="utf-8")
        except OSError:
            pass


def _still_open(e: dict) -> bool:
    """A listed chat whose ask is still running in a live process (never stopped or archived under it)."""
    pid = e.get("open")
    if not pid or time.time() - float(e.get("t", 0)) > 3 * 3600:
        return False
    try:
        import psutil
        return psutil.pid_exists(int(pid))
    except Exception:   # noqa: BLE001 - unknown: assume it runs; the 3 h limit still frees it
        return True


def drop_unarchived(cid: str) -> None:
    with _UNARCHIVED_LOCK:
        d = _unarchived()
        if d.pop(cid, None) is not None:
            try:
                UNARCHIVED.write_text(json.dumps(d, indent=1), encoding="utf-8")
            except OSError:
                pass


def record_chrome_hang(path: Path | None = None) -> None:
    """Note a hung-Chrome restart (last 24 h kept); repeated hangs make the controller restart the PC."""
    path = path or CHROME_HANGS
    now = time.time()
    try:
        hangs = [t for t in json.loads(path.read_text(encoding="utf-8")) if isinstance(t, (int, float))]
    except (OSError, ValueError, TypeError):
        hangs = []
    try:
        path.write_text(json.dumps([t for t in hangs if now - t < 86400] + [now]), encoding="utf-8")
    except OSError:
        pass


def _held() -> dict:
    try:
        return {k: v for k, v in json.loads(HELD_TABS.read_text(encoding="utf-8")).items() if v > time.time()}
    except (OSError, ValueError, AttributeError):
        return {}


def hold_tab(page, seconds: float) -> str:
    """Keep close_stale_tabs (in any process) off this page for `seconds`; returns its target id ("" if unknown)."""
    try:
        tid = page.context.new_cdp_session(page).send("Target.getTargetInfo")["targetInfo"]["targetId"]
    except Exception:   # noqa: BLE001 - best effort, like _ACTIVE_TARGETS
        return ""
    held = _held()
    held[tid] = time.time() + seconds
    try:
        HELD_TABS.write_text(json.dumps(held), encoding="utf-8")
    except OSError:
        pass
    return tid


def release_tab(tid: str) -> None:
    held = _held()
    if tid and held.pop(tid, None) is not None:
        try:
            HELD_TABS.write_text(json.dumps(held), encoding="utf-8")
        except OSError:
            pass


def is_blank(url: str) -> bool:
    """A tab that shows nothing: about:blank, Chrome's new tab page, or no URL yet."""
    return not url or url.startswith(("about:blank", "chrome://newtab", "chrome://new-tab-page"))


def close_stale_tabs(cdp_url: str, startup: bool = False) -> int:
    """Close ChatGPT tabs not used by a running ask. At startup every ChatGPT tab is stale (no ask is running);
    later any ChatGPT tab no ask here owns is closed once it has looked stale for over 4 minutes (owner 2026-11-02:
    14 blank https://chatgpt.com/ tabs of asks cut off by a network drop had piled up; only /c/ tabs were closed).
    One page is always kept so the relay Chrome window stays open."""
    import json
    import urllib.request
    base = cdp_url.rstrip("/")
    try:
        with urllib.request.urlopen(base + "/json/list", timeout=5) as r:
            tabs = [t for t in json.load(r) if t.get("type") == "page"]
    except OSError:
        return 0
    held = _held()
    # Owner 2026-11-04: blank tabs (about:blank, new tab) of web coders whose page never loaded and of asks cut off
    # mid-open piled up too, on 9223/9224 as well; they count as leftovers like ChatGPT tabs.
    stale = [t for t in tabs if ("chatgpt.com" in t.get("url", "") or is_blank(t.get("url", "")))
             and t.get("id") not in _ACTIVE_TARGETS and t.get("id") not in held]
    if not startup:
        # Tabs of other processes (art design asks, <= 150 s) are not registered here: close a tab only after it
        # has looked stale for over 4 minutes.
        now = time.time()
        ids = {t["id"] for t in stale}
        for t in tabs:   # a tab that went on to load a page starts its 4 minutes again if it turns stale later
            if t.get("id") not in ids:
                _STALE_SEEN.pop(t.get("id"), None)
        for t in stale:
            _STALE_SEEN.setdefault(t["id"], now)
        stale = [t for t in stale if now - _STALE_SEEN[t["id"]] > 240]
    # Keep one page that no running ask will close: when only an ask's own tab survived, that ask closed it
    # on finishing and Chrome quit with its last window (cycle 201's health check found it gone, 2026-10-13).
    if stale and not [t for t in tabs if t not in stale and t.get("id") not in _ACTIVE_TARGETS]:
        stale = stale[1:]
    closed = 0
    for t in stale:
        note_unarchived(chat_id(t.get("url", "")))   # an ask cut off by a halt: archive its chat later
        try:
            with urllib.request.urlopen(f"{base}/json/close/{t['id']}", timeout=5):
                closed += 1
        except OSError:
            pass
    return closed


def same_profile(cmdline: str, udd: str) -> bool:
    """True when a Chrome command line uses exactly the profile `udd` (C:\\relay-chrome, not C:\\relay-chrome-ds2)."""
    import re
    m = re.search(r'--user-data-dir=(?:"([^"]*)"|(\S+))', cmdline or "")

    def norm(p: str) -> str:
        return p.strip().strip('"').rstrip("\\/").replace("/", "\\").lower()
    return bool(m) and norm(m.group(1) or m.group(2)) == norm(udd)


def _chrome_cmdlines() -> list[tuple[int, str]]:
    """(pid, command line) of every chrome.exe."""
    import subprocess
    ps = ("Get-CimInstance Win32_Process -Filter \"Name='chrome.exe'\" | "
          "ForEach-Object { \"$($_.ProcessId)`t$($_.CommandLine)\" }")
    try:
        out = subprocess.run(["powershell.exe", "-NoProfile", "-Command", ps], capture_output=True, text=True,
                             timeout=60).stdout
    except (OSError, subprocess.SubprocessError):
        return []
    rows = [line.split("\t", 1) for line in out.splitlines() if "\t" in line]
    return [(int(p), c) for p, c in rows if p.strip().isdigit()]


# Owner 2026-11-04 ("is there a way to stop it from happening", the about:blank tabs): the relay Chrome grew to 3 GB
# within minutes of a restart and hung about every 2 h (00:45 02:52 05:06 07:28 09:27), each time after new tabs sat on
# about:blank for 1-2 min. It is restarted every 90 min while nothing is attached, before it hangs.
CHROME_REFRESH_S = 90 * 60


def _cdp_clients(port: int) -> int:
    """Open DevTools connections to the Chrome on `port`, from any process (asks, art design asks, probes)."""
    import psutil
    return sum(1 for c in psutil.net_connections(kind="tcp")
               if c.raddr and c.raddr.port == port and c.status == psutil.CONN_ESTABLISHED)


def refresh_idle_chrome(cfg: dict, log: Callable[[str], None], max_age_s: float = CHROME_REFRESH_S) -> bool:
    """Restart the relay Chrome (cfg: the chatgpt section) once it has run for max_age_s, only while no ask holds a
    tab and no client is attached. The profile keeps the ChatGPT login. True when it was restarted."""
    import psutil
    udd = next((a.split("=", 1)[1] for a in cfg.get("chrome_launch") or [] if a.startswith("--user-data-dir=")), "")
    port = int(cfg.get("cdp_url", "http://127.0.0.1:9222").rstrip("/").rsplit(":", 1)[-1])
    if not udd.strip() or _ACTIVE_TARGETS or _held() or _cdp_clients(port):
        return False
    main = [p for p, cmd in _chrome_cmdlines() if same_profile(cmd, udd) and "--type=" not in cmd]
    try:
        age = time.time() - min(psutil.Process(p).create_time() for p in main)
    except (ValueError, psutil.Error):
        return False
    if age < max_age_s:
        return False
    with _RESTART_LOCK:
        if _ACTIVE_TARGETS or _cdp_clients(port):   # an ask started meanwhile
            return False
        quiet = ChatGPTBridge(cfg, lambda m: None)
        quiet._kill_relay_chrome()
        time.sleep(3)
        ok = quiet._launch_chrome()
        _LAST_RESTART[0] = time.time()
    log(f"chrome: restarted the idle relay Chrome after {age / 60:.0f} min (it hangs after ~2 h, leaving tabs on "
        f"about:blank)" + ("" if ok else "; it did not come back, the next ask launches it"))
    return True


# Owner 2026-11-04 ("speed things up without adding extra coders"): after a failed ask on a hung relay Chrome, the
# cleanup (screenshot, Stop, closing the tab) blocked until something else killed Chrome: 26 stalls of 5-70 min on
# 11-02..04, the cycle waiting on them. A cleanup still running after HUNG_CLEANUP_S restarts the relay Chrome.
HUNG_CLEANUP_S = 120


def _loopback_listeners(port: int) -> list[str]:
    """The loopback addresses (127.0.0.1, ::1) that accept a TCP connection on port."""
    import socket
    up = []
    for fam, host in ((socket.AF_INET, "127.0.0.1"), (socket.AF_INET6, "::1")):
        s = socket.socket(fam, socket.SOCK_STREAM)
        s.settimeout(1)
        try:
            if s.connect_ex((host, port)) == 0:
                up.append(host)
        except OSError:
            pass
        finally:
            s.close()
    return up


def _hang_guard(cfg: dict, log: Callable[[str], None]) -> threading.Timer:
    """A started timer that restarts the relay Chrome (kill + launch, only its own profile) unless cancelled within
    HUNG_CLEANUP_S. Killing Chrome makes the blocked Playwright call fail, so the ask returns its error."""
    def fire():
        with _RESTART_LOCK:
            if time.time() - _LAST_RESTART[0] < HUNG_CLEANUP_S:   # restarted meanwhile: that freed the call
                return
            quiet = ChatGPTBridge(cfg, lambda m: None)
            n = quiet._kill_relay_chrome()
            record_chrome_hang()
            time.sleep(3)
            ok = quiet._launch_chrome()
            _LAST_RESTART[0] = time.time()
        log(f"chrome: an ask was stuck closing its tab for {HUNG_CLEANUP_S} s (hung relay Chrome); restarted it "
            f"({n} processes killed)" + ("" if ok else "; it did not come back, the next ask launches it"))

    t = threading.Timer(HUNG_CLEANUP_S, fire)
    t.daemon = True
    t.start()
    return t


def _slots(n: int) -> threading.BoundedSemaphore:
    global _SLOTS
    with _SLOTS_LOCK:
        if _SLOTS is None:
            _SLOTS = threading.BoundedSemaphore(max(1, n))
        return _SLOTS


def reload_cap(errored: bool, max_reloads: int, idle_reloads: int) -> int:
    """Reloads allowed before a stuck reply is given up on (the caller then retries in a fresh chat).

    2026-10-25: an error banner clears within a reload or three, seconds apart. A silent tab is different: across
    2026-10-24/25 every tab that went silent again after one reload stayed silent through the rest (two episodes,
    ~30 min each, cycle 233 waited 27 min for its plan), so a silent tab gets idle_reloads reloads, not max_reloads.
    """
    return max_reloads if errored else min(max_reloads, idle_reloads)


class BridgeError(Exception):
    pass


class WorkLimitReached(Exception):
    """ChatGPT reported that Work mode's usage ran out (not a BridgeError: ask() handles it itself)."""


class ChatGPTBridge:
    def __init__(self, cfg: dict, log: Callable[[str], None]):
        self.cfg = cfg
        self.sel = cfg["selectors"]
        self.log = log
        self._pw = None
        self._browser = None
        self._login_logged = 0.0
        self._archived = 0

    def _context(self):
        if self._browser is None or not self._browser.is_connected():
            if self._pw is None:
                self._pw = sync_playwright().start()
            last = None
            for wait in (0, 10, 30):   # under load Chrome answers slowly: retry before assuming it is gone
                time.sleep(wait)
                try:
                    self._browser = self._pw.chromium.connect_over_cdp(self.cfg["cdp_url"], timeout=90_000)
                    last = None
                    break
                except PWError as e:
                    last = e
            if last is not None:
                self._recover_chrome(last)
        if not self._browser.contexts:
            raise BridgeError("Chrome has no browser context")
        return self._browser.contexts[0]

    def new_tab(self):
        """A new tab for one ask. Plain new_page: each thread's own connection gets exactly the tab it made.
        2026-10-20: tabs opened in the background (CDP createTarget + expect_page) raced when two asks started in
        the same second (cycle 005: both threads caught the same tab, net::ERR_ABORTED then "Target page ... has
        been closed"); the owner said "you dont need to open it in background", so that version is gone."""
        return self._context().new_page()

    def _recover_chrome(self, e: PWError) -> None:
        """Connecting failed. 2026-10-19 (twice): Chrome still answered /json/version and the websocket connected,
        but Playwright never finished attaching; launching again only handed off to the hung instance. So a Chrome
        that answers but cannot be attached is killed (only the relay profile's processes) and relaunched."""
        with _RESTART_LOCK:
            if time.time() - _LAST_RESTART[0] < 300:   # another thread just restarted it: use that one
                try:
                    self._browser = self._pw.chromium.connect_over_cdp(self.cfg["cdp_url"], timeout=90_000)
                    return
                except PWError as e1:
                    e = e1
            if self._cdp_answers():
                n = self._kill_relay_chrome()
                self.log(f"relay Chrome answers but cannot be attached (hung); killed {n} of its processes")
                record_chrome_hang()
                time.sleep(3)
            if not self._launch_chrome():
                raise BridgeError(
                    f"cannot reach Chrome at {self.cfg['cdp_url']} "
                    "(is it running with --remote-debugging-port?)"
                ) from e
            _LAST_RESTART[0] = time.time()
            try:
                self._browser = self._pw.chromium.connect_over_cdp(self.cfg["cdp_url"], timeout=120_000)
            except PWError as e2:
                raise BridgeError(f"launched Chrome but cannot connect: {e2}") from e2

    def _cdp_answers(self) -> bool:
        import urllib.request
        try:
            urllib.request.urlopen(self.cfg["cdp_url"].rstrip("/") + "/json/version", timeout=5).read()
            return True
        except OSError:
            return False

    def _kill_relay_chrome(self) -> int:
        """Force-kill the chrome.exe processes started with the relay profile (--user-data-dir from chrome_launch);
        never any other Chrome. Returns how many were killed."""
        import subprocess
        udd = next((a.split("=", 1)[1] for a in self.cfg.get("chrome_launch") or []
                    if a.startswith("--user-data-dir=")), "")
        if not udd.strip():
            return 0
        pids = [p for p, cmd in _chrome_cmdlines() if same_profile(cmd, udd)]
        if not pids:
            return 0
        ps = "Stop-Process -Id " + ",".join(map(str, pids)) + " -Force -ErrorAction SilentlyContinue"
        try:
            subprocess.run(["powershell.exe", "-NoProfile", "-Command", ps], capture_output=True, timeout=60)
        except (OSError, subprocess.SubprocessError) as e:
            self.log(f"could not stop the hung relay Chrome: {e}")
            return 0
        return len(pids)

    def _launch_chrome(self) -> bool:
        """Start the dedicated relay Chrome (same profile, so the ChatGPT login is kept)."""
        argv = self.cfg.get("chrome_launch")
        if not argv:
            return False
        import subprocess
        import urllib.request
        # Owner 2026-11-05 ("something isnt working in the relay"): launched 3 s after a hang kill, before Windows
        # freed 127.0.0.1:9222, Chrome bound its DevTools port to [::1] only; the relay never reached it again and
        # each later launch handed off to it (17:00-17:04, every ChatGPT ask lost). Kill such a Chrome and wait
        # until the port is free before launching.
        port = int(self.cfg.get("cdp_url", "http://127.0.0.1:9222").rstrip("/").rsplit(":", 1)[-1])
        if _loopback_listeners(port) == ["::1"]:
            n = self._kill_relay_chrome()
            self.log(f"relay Chrome listens on [::1]:{port} only, not 127.0.0.1; killed {n} of its processes")
        for _ in range(15):
            if not _loopback_listeners(port):
                break
            time.sleep(1)
        self.log("relay Chrome not reachable; launching it")
        try:
            subprocess.Popen(argv, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except OSError as e:
            self.log(f"could not launch Chrome: {e}")
            return False
        for _ in range(30):
            time.sleep(1)
            try:
                urllib.request.urlopen(self.cfg["cdp_url"].rstrip("/") + "/json/version", timeout=2).read()
                time.sleep(3)   # let the first tab finish loading
                return True
            except OSError:
                continue
        return False

    def ask(self, text: str, timeout_s: int, debug_dir: Path | None = None,
            should_stop: Callable[[], bool] = lambda: False, mode: str = "chat",
            done: Callable[[], bool] | None = None, files: list | None = None,
            effort: str | None = None) -> str:
        """done: optional completion check (file mode: the output file was written). When it turns true the
        ask returns immediately, whatever the chat page looks like."""
        """mode: "chat" (normal ChatGPT) or "work" (the Chat/Work toggle's agent mode)."""
        if len(text) > self.cfg["max_chars"]:
            raise BridgeError(f"prompt is {len(text)} chars, over max_chars")
        if mode == "work" and time.time() < work_limited_until():
            mode = "chat"
            self.log("chatgpt: Work mode is paused after hitting its usage limit; using Chat mode")
        slots = _slots(int(self.cfg.get("max_concurrent", 8)))
        while not slots.acquire(timeout=5):
            if should_stop():
                raise BridgeError("stop requested")
        try:
            return self._ask_slot(text, timeout_s, debug_dir, should_stop, mode, done, files, effort)
        finally:
            slots.release()

    def _ask_slot(self, text, timeout_s, debug_dir, should_stop, mode, done, files, effort) -> str:
        try:
            return self._ask_once(text, timeout_s, debug_dir, should_stop, mode, done, files, effort)
        except WorkLimitReached as e:
            # Back to Work when ChatGPT says the usage resets; without a reset time, after work_limit_pause_h.
            until = work_reset_time(str(e)) or time.time() + float(self.cfg.get("work_limit_pause_h", 5)) * 3600
            try:
                WORK_LIMIT_FILE.parent.mkdir(parents=True, exist_ok=True)
                WORK_LIMIT_FILE.write_text(str(until), encoding="utf-8")
            except OSError:
                pass
            self.log(f"chatgpt: Work mode usage limit reached ({str(e)[:120]}); using Chat mode until "
                     f"{time.strftime('%H:%M', time.localtime(until))}")
            return self._ask_once(text, timeout_s, debug_dir, should_stop, "chat", done, files, effort)

    def _work_limit_text(self, page, reply: str | None = None) -> str:
        """The usage-limit notice ChatGPT shows when Work mode ran out, or "". After a reply only a short reply
        counts (a real answer can quote anything); after a failure the page itself is checked (a banner, or a
        Work page that never started)."""
        if reply is not None:
            return reply.strip()[:200] if len(reply) < 1500 and WORK_LIMIT_RE.search(reply) else ""
        try:
            body = page.locator("body").first.inner_text(timeout=5_000)   # the notice is a dialog outside main
        except PWError:
            return ""
        m = WORK_LIMIT_RE.search(body)
        return body[max(0, m.start() - 60):m.end() + 200].replace("\n", " ") if m else ""

    def _ask_once(self, text, timeout_s, debug_dir, should_stop, mode, done, files, effort) -> str:
        page = self.new_tab()
        tid = None
        try:
            tid = page.context.new_cdp_session(page).send("Target.getTargetInfo")["targetInfo"]["targetId"]
            _ACTIVE_TARGETS.add(tid)
        except Exception:   # noqa: BLE001 - tracking is best effort; the janitor only closes /c/ tabs anyway
            pass
        archived = False
        guard = None
        try:
            reply = self._ask(page, text, timeout_s, should_stop, mode, done, files, effort)
            if mode == "work" and not (done is not None and done()):
                notice = self._work_limit_text(page, reply)
                if notice:
                    raise WorkLimitReached(notice)
            archived = self._archive_chat(page, debug_dir)
            if archived:
                self.sweep_unarchived(page, debug_dir)
            return reply
        except (PWError, BridgeError) as e:
            guard = _hang_guard(self.cfg, self.log)
            if mode == "work":
                notice = self._work_limit_text(page)
                if notice:
                    raise WorkLimitReached(notice) from e
            if debug_dir:
                try:
                    page.screenshot(path=str(Path(debug_dir) / f"chatgpt_fail_{int(time.time())}.png"))
                except PWError:
                    pass
            # Closing the tab does NOT stop ChatGPT: the run goes on server-side and still writes its answer file
            # through SentinelX, so a retry ended up racing it (owner saw two plans running, 2026-10-07).
            self._press_stop(page)
            raise BridgeError(str(e)) from e
        finally:
            guard = guard or _hang_guard(self.cfg, self.log)
            if not archived and self.cfg.get("archive_chats", True):
                try:
                    note_unarchived(chat_id(page.url) or getattr(page, "_relay_cid", ""))
                except Exception:   # noqa: BLE001 - best effort
                    pass
            try:
                if len(page.context.pages) > 1:
                    page.close()
                else:   # the last tab: closing it would quit the relay Chrome
                    page.goto("about:blank")
            except Exception:   # noqa: BLE001 - any failure here used to leave the tab open
                pass
            _ACTIVE_TARGETS.discard(tid)
            self.disconnect()
            guard.cancel()

    def disconnect(self) -> None:
        """Drop the CDP session. While a Playwright client stays attached but idle,
        Chrome pauses every newly opened tab waiting for it, freezing the window."""
        try:
            if self._browser is not None:
                self._browser.close()
        except PWError:
            pass
        try:
            if self._pw is not None:
                self._pw.stop()
        except Exception:
            pass
        self._browser = None
        self._pw = None

    def ensure_chatgpt_product(self, page) -> bool:
        """If the app is in Codex mode, switch it to ChatGPT and reload the new-chat page. True if switched."""
        sw = page.locator('button[aria-label^="Switch mode"]')
        try:
            if not sw.count() or "ChatGPT" in (sw.first.get_attribute("aria-label") or ""):
                return False
            sw.first.click()
            time.sleep(2)
            page.locator('[role="menuitem"]').filter(has_text="ChatGPT").first.click()
            time.sleep(4)
            page.goto(self.cfg["new_chat_url"], wait_until="domcontentloaded", timeout=60_000)
            page.locator(self.sel["composer"]).first.wait_for(state="visible", timeout=60_000)
            self.log("chatgpt: app was in Codex mode; switched back to ChatGPT")
            return True
        except PWError:
            return False

    def _select_mode(self, page, mode: str) -> None:
        label = {"chat": "Chat", "work": "Work"}.get(mode)
        if label is None:
            raise BridgeError(f"unknown chatgpt mode {mode!r}")
        toggle = page.get_by_role("button", name=label, exact=True).first
        try:
            toggle.wait_for(state="visible", timeout=15_000)
        except PWError as e:
            # The app remembers the last product used: after Codex work, chatgpt.com opens Codex. Switch back.
            if self.ensure_chatgpt_product(page):
                return self._select_mode(page, mode)
            raise BridgeError(f"{label} toggle not found (ChatGPT UI changed?)") from e
        toggle.click()
        if mode == "work":
            # Confirm the switch took: these only render on the Work start page.
            marker = page.get_by_role("button", name="Choose Work pet")
            try:
                marker.first.wait_for(state="visible", timeout=15_000)
            except PWError as e:
                raise BridgeError("could not switch ChatGPT to Work mode") from e
        time.sleep(1)

    @staticmethod
    def _in_work_mode(page) -> bool:
        try:
            marker = page.get_by_role("button", name="Choose Work pet")
            return marker.count() > 0 and marker.first.is_visible()
        except PWError:
            return False

    EFFORT_WORDS = {"low": ("light", "low", "minimal"), "light": ("light", "low", "minimal"),
                    "medium": ("medium",), "high": ("high",), "extra high": ("extra high",), "max": ("max",)}

    def _set_effort(self, page, level: str) -> None:
        """Effort slider behind the "Select ChatGPT model" button. It is chosen by its label ("High, 3 of 5."):
        Chat mode has 3 levels, Work mode 5 (Light, Medium, High, Extra High, Max). Falls back to positions
        (0 low, 1 medium, 2 high) when no label is readable."""
        level = (level or "").lower()
        words = self.EFFORT_WORDS.get(level, (level,))
        if not level:
            return
        try:
            btn = page.locator('button[aria-label="Select ChatGPT model"]').first
            if not btn.count():
                return
            btn.click()
            slider = page.locator('[role="slider"]').first
            slider.wait_for(state="attached", timeout=5_000)

            def label():
                m = re.search(r"([A-Za-z][A-Za-z ]*?), \d+ of \d+",
                              page.locator('[role="menu"]').first.inner_text(timeout=3_000))
                return m.group(1).strip().lower() if m else None

            if label() is not None:
                slider.focus()
                slider.press("Home")
                time.sleep(0.3)
                for _ in range(int(slider.get_attribute("aria-valuemax") or 4) + 1):
                    if label() in words:
                        break
                    slider.press("ArrowRight")
                    time.sleep(0.35)
                else:
                    self.log(f"chatgpt: effort level {level!r} not found on the slider")
                return
            want = {"low": 0, "light": 0, "medium": 1, "high": 2}.get(level)
            for _ in range(4):
                if want is None:
                    break
                cur = int(slider.get_attribute("aria-valuenow") or want)
                if cur == want:
                    break
                slider.focus()
                slider.press("ArrowLeft" if cur > want else "ArrowRight")
                time.sleep(0.4)
        except (PWError, ValueError) as e:
            self.log(f"chatgpt: could not set thinking effort to {level} ({str(e)[:80]})")
        finally:
            try:
                page.keyboard.press("Escape")
                time.sleep(0.5)
            except PWError:
                pass

    def sweep_unarchived(self, page, debug_dir=None) -> None:
        """Archive up to archive_sweep_max relay chats left unarchived earlier (see UNARCHIVED), each given
        archive_sweep_tries attempts. Runs in this ask's tab after its own chat was archived; never raises."""
        try:
            n = int(self.cfg.get("archive_sweep_max", 3))
            min_age = float(self.cfg.get("archive_sweep_min_age_s", 600))   # a failed ask may still be finishing
            todo = sorted((float(v.get("t", 0)), k) for k, v in _unarchived().items()
                          if time.time() - float(v.get("t", 0)) > min_age and not _still_open(v))[:n]
            opts = self.cfg["selectors"].get("chat_options", 'header button[aria-label="More"]:visible, '
                                                             '[data-testid="conversation-options-button"]:visible')
            done = 0
            for _, cid in todo:
                try:
                    page.goto(f"https://chatgpt.com/c/{cid}", wait_until="domcontentloaded", timeout=60_000)
                    page.locator(opts).first.wait_for(timeout=30_000)
                except PWError:
                    pass
                if chat_id(page.url) != cid:   # deleted or not openable
                    drop_unarchived(cid)
                    continue
                if self._archive_chat(page, debug_dir, wait_s=30):
                    done += 1
                    continue
                note_unarchived(cid, tried=True)
                if int(_unarchived().get(cid, {}).get("tries", 0)) >= int(self.cfg.get("archive_sweep_tries", 3)):
                    drop_unarchived(cid)
                    self.log(f"chatgpt: gave up archiving leftover chat {cid} after repeated failures")
            if done:
                self.log(f"chatgpt: archived {done} leftover relay chat(s); {len(_unarchived())} still listed")
        except Exception as e:   # noqa: BLE001 - housekeeping must never fail an ask whose answer is saved
            self.log(f"chatgpt: leftover-chat sweep stopped ({type(e).__name__}: {str(e)[:120]})")

    def _archive_chat(self, page, debug_dir=None, wait_s: float | None = None) -> bool:
        """Owner 2026-10-19: archive each relay chat once its reply is saved, so the ChatGPT sidebar is not filled
        with relay chats (Settings > Data controls > Archived chats brings one back). A chat still running (file
        mode hands its answer file over early) gets archive_wait_s to finish, then is stopped; a failure only costs
        a log line."""
        if not self.cfg.get("archive_chats", True) or "/c/" not in page.url:
            return False
        s = self.cfg["selectors"]
        step = "options button"
        try:
            # 2026-10-20: no chat was archived after the fix. File-mode asks return as soon as the answer file is
            # written, while ChatGPT is still writing its closing message, so the Stop check skipped every one
            # silently. Wait for it to finish; past archive_wait_s the answer is already saved, so stop it.
            # 2026-10-21: a leftover chat showed "Working for 59m" with no aria-label="Stop" button: check every
            # Stop variant and that label too.
            stop = page.locator(s["stop"] + ', button[data-testid="stop-button"], button[aria-label="Stop streaming"]')
            working = page.get_by_text(re.compile(r"^\s*Working for\b"))
            running = lambda: (any(stop.nth(i).is_visible() for i in range(stop.count()))  # noqa: E731
                               or any(working.nth(i).is_visible() for i in range(min(working.count(), 5))))
            wait = self.cfg.get("archive_wait_s", 90) if wait_s is None else wait_s
            for _ in range(int(wait) // 3):
                if not running():
                    break
                page.wait_for_timeout(3000)
            if running():
                step = "Stop button"
                if any(stop.nth(i).is_visible() for i in range(stop.count())):
                    stop.locator("visible=true").first.click(timeout=10_000)
                    page.wait_for_timeout(2000)
                if running():
                    self.log("chatgpt: left the chat unarchived for now (still running; archived later)")
                    return False
            # :visible - the first live archive (2026-10-19) timed out on a click; a hidden copy of the button
            # (narrow/mobile header) matched first.
            page.locator(s.get("chat_options", 'header button[aria-label="More"]:visible, '
                                               '[data-testid="conversation-options-button"]:visible')).first.click(
                timeout=15_000)
            cid = chat_id(page.url)
            link = f'nav a[href*="/c/{cid}"]'
            link_before = page.locator(link).count()
            step = "Archive menu item"
            # 2026-10-21: some leftover chats were already archived, so their menu offers "Unarchive" and the
            # sweep retried them until it gave up. Count those as done.
            page.get_by_role("menuitem", name=re.compile(r"^\s*(Un)?archive\s*$", re.I)).first.wait_for(
                timeout=10_000)
            unarchive = page.get_by_role("menuitem", name=re.compile(r"^\s*Unarchive\s*$", re.I))
            if unarchive.count() and unarchive.first.is_visible():
                page.keyboard.press("Escape")
                drop_unarchived(cid)
                return True
            archive = re.compile(r"^\s*Archive\s*$", re.I)
            page.get_by_role("menuitem", name=archive).first.click(timeout=10_000)
            page.wait_for_timeout(1500)
            # Owner 2026-10-20 "i dont think it is archiving the chats": a click that archived nothing passed
            # silently, so confirm a dialog if one asks, then check the chat really went.
            step = "confirm dialog"
            confirm = page.get_by_role("dialog").get_by_role("button", name=archive)
            if confirm.count():
                confirm.first.click(timeout=10_000)
                page.wait_for_timeout(1500)
            link_after = page.locator(link).count()
            left = not (cid in page.url and not (link_before and not link_after))
            # Owner 2026-10-21 "the archiving isnt working again": the sidebar filled up while every archive passed
            # the check above (the page left the chat, but the chat was not archived), and ChatGPT's sidebar keeps
            # listing archived chats for a while. Reopen the chat: its menu (Unarchive vs Archive) is the answer;
            # the page/link check above only decides when the menu cannot be read.
            step = "archive check"
            verdict = self._menu_offers_unarchive(page, cid) if self.cfg.get("archive_verify", True) else None
            if verdict is False or (verdict is None and not left):
                why = "still offers Archive" if verdict is False else                     f"chat still open; sidebar link {link_before}->{link_after}"
                self.log(f"chatgpt: archive did not take (chat {cid[:8]} {why}; retried later)")
                if debug_dir:
                    page.screenshot(path=str(Path(debug_dir) / f"chatgpt_archive_fail_{int(time.time())}.png"))
                return False
            self._archived += 1
            drop_unarchived(cid)
            return True
        except PWError as e:
            self.log(f"chatgpt: could not archive the finished chat ({step}: {str(e).splitlines()[0][:120]})")
            if debug_dir:
                try:
                    page.screenshot(path=str(Path(debug_dir) / f"chatgpt_archive_fail_{int(time.time())}.png"))
                except PWError:
                    pass
            return False

    def _menu_offers_unarchive(self, page, cid: str) -> bool | None:
        """Open the chat and look at its options menu: True when it offers Unarchive (archived), False when it
        offers Archive, None when that could not be told."""
        opts = self.cfg["selectors"].get("chat_options", 'header button[aria-label="More"]:visible, '
                                                         '[data-testid="conversation-options-button"]:visible')
        # 2026-10-24: 106 "archive did not take" against 93 archived in a day and a half, yet a probe of the same
        # click showed the chat archived (its menu offered Unarchive) when reopened a few seconds later. Reopened
        # at once, the page still showed the old menu. Wait before reading it, and read it twice before saying no.
        wait_ms = int(self.cfg.get("archive_verify_wait_ms", 4000))
        archived = None
        for _ in range(2):
            try:
                page.wait_for_timeout(wait_ms)
                page.goto(f"https://chatgpt.com/c/{cid}", wait_until="domcontentloaded", timeout=60_000)
                if chat_id(page.url) != cid:
                    return None
                page.locator(opts).first.wait_for(timeout=30_000)
                page.wait_for_timeout(2000)   # the header renders before the chat's own state loads
                page.locator(opts).first.click(timeout=30_000)
                page.get_by_role("menuitem", name=re.compile(r"^\s*(Un)?archive\s*$", re.I)).first.wait_for(
                    timeout=10_000)
                un = page.get_by_role("menuitem", name=re.compile(r"^\s*Unarchive\s*$", re.I))
                archived = bool(un.count() and un.first.is_visible())
                page.keyboard.press("Escape")
            except PWError:
                archived = None
            if archived:
                return True
        return archived

    def _press_stop(self, page) -> None:
        """Stop a reply that is still running (best effort)."""
        try:
            stop = page.locator('button[data-testid="stop-button"], button[aria-label="Stop"], '
                                'button[aria-label="Stop streaming"]')
            for i in range(stop.count()):
                if stop.nth(i).is_visible():
                    stop.nth(i).click(timeout=5_000)
                    self.log("chatgpt: stopped the unfinished reply before giving up on it")
                    time.sleep(2)
                    return
        except PWError:
            pass

    def _logged_out(self, page) -> bool:
        """The relay Chrome shows ChatGPT's logged-out page (a "Log in" button)."""
        try:
            # Exact text and no links: a sidebar chat titled "Log in ..." must not look like the logged-out page.
            b = page.locator(self.sel.get("login_button", '[data-testid="login-button"], button:text-is("Log in")'))
            return any(b.nth(i).is_visible() for i in range(min(b.count(), 4)))
        except PWError:
            return False

    def _wait_for_login(self, page, deadline: float, should_stop) -> None:
        """2026-10-19 22:29: after a hung Chrome was killed the relay Chrome came back logged out, and every ChatGPT
        step failed "composer not found" every two minutes. Only the owner signs in, so wait for that (reloading
        every minute) until the step's own deadline, instead of failing and retrying."""
        if time.time() - self._login_logged > 1800:
            self._login_logged = time.time()
            self.log("chatgpt: logged out in the relay Chrome; waiting for the owner to sign in")
        while True:
            for _ in range(12):
                if should_stop():
                    raise BridgeError("stop requested")
                if time.time() > deadline:
                    raise BridgeError("composer not found: logged out (waited for the owner to sign in)")
                time.sleep(5)
            page.goto(self.cfg["new_chat_url"], wait_until="domcontentloaded", timeout=60_000)
            if not self._logged_out(page):
                self.log("chatgpt: signed in again; carrying on")
                return

    def _ask(self, page, text, timeout_s, should_stop, mode="chat", done=None, files=None, effort=None) -> str:
        s = self.sel
        deadline = time.time() + timeout_s

        def check():
            if should_stop():
                raise BridgeError("stop requested")
            if time.time() > deadline:
                raise BridgeError("reply timed out")

        # 2026-10-19 13:42-14:18: five "composer not found" failures while four ChatGPT tabs loaded at once; the
        # failure screenshots show the logged-in page still loading. One more load before giving up.
        # Owner 2026-11-02 ("stop the tabs from not loading"): a load that hit the 60 s domcontentloaded timeout
        # failed the whole ask (18 times on 11-01/02). Wait only for the response to start; the composer wait below
        # covers the rest, and a timed-out load gets the second load too.
        for load in range(2):
            try:
                page.goto(self.cfg["new_chat_url"], wait_until="commit", timeout=60_000)
            except PWError as e:
                if load or should_stop() or page.is_closed():
                    raise
                self.log(f"chatgpt: the new-chat page did not load ({str(e).splitlines()[0][:80]}); loading it once more")
                continue
            if self._logged_out(page):
                self._wait_for_login(page, deadline, should_stop)
            composer = page.locator(s["composer"]).first
            try:
                composer.wait_for(state="visible", timeout=60_000)
                break
            except PWError as e:
                if self._logged_out(page):   # drawn only after the early return of a "commit" load
                    self._wait_for_login(page, deadline, should_stop)
                    composer.wait_for(state="visible", timeout=60_000)
                    break
                if load or should_stop():
                    raise BridgeError("composer not found: logged out, Cloudflare check, or selector changed") from e
                self.log("chatgpt: no composer on the new-chat page after 60 s; loading it once more")

        with _MODE_LOCK:
            self._select_mode(page, mode)
            composer = page.locator(s["composer"]).first
            composer.wait_for(state="visible", timeout=30_000)
            if effort:
                self._set_effort(page, effort)
            if mode == "work" and not self._in_work_mode(page):
                # Closing the effort menu (Escape) can drop the Work page back to Chat (GPT-6 UI, 2026-10-08): lane4
                # ran in Chat mode. Re-select Work and keep ChatGPT's default effort rather than send in Chat.
                self.log("chatgpt: Work mode was lost after setting the effort; selecting Work again")
                self._select_mode(page, "work")
                if not self._in_work_mode(page):
                    raise BridgeError("could not keep ChatGPT in Work mode")
                composer = page.locator(s["composer"]).first
                composer.wait_for(state="visible", timeout=30_000)
            if files:   # attachments (context zip): upload first; Send stays disabled until uploads finish
                # The page also has a single-file camera input ("Take a photo", 2026-10-10) that broke multi-file
                # uploads (smoke check); use the general attachment input, or one file per input as a fallback.
                multi = next((loc for sel in ('input[type="file"][aria-label="Attach files"]',
                                              'input[type="file"][multiple][accept=""]', 'input[type="file"][multiple]')
                              if (loc := page.locator(sel)).count()), None)
                if multi is not None:
                    multi.first.set_input_files([str(f) for f in files])
                else:
                    general = page.locator('input[type="file"]:not([capture])').first
                    for f in files:
                        general.set_input_files([str(f)])
                        time.sleep(2)
                time.sleep(3)
            if self._in_work_mode(page) != (mode == "work"):
                # Another tab switched the shared Chat/Work setting: select ours again rather than send in the wrong mode.
                self.log(f"chatgpt: the page left {mode} mode before sending; selecting it again")
                self._select_mode(page, mode)
                if self._in_work_mode(page) != (mode == "work"):
                    raise BridgeError(f"could not keep ChatGPT in {mode} mode")
                composer = page.locator(s["composer"]).first
                composer.wait_for(state="visible", timeout=30_000)
            composer.click()
            composer.fill(text)
            before = page.locator(s["assistant"]).count()

            send = page.locator(s["send"]).first
            try:
                send.wait_for(state="visible", timeout=15_000)
                for _ in range(240 if files else 30):
                    if send.is_enabled():
                        break
                    time.sleep(0.5)
                send.click()
            except PWError:
                composer.press("Enter")

        # Wait for the reply. ChatGPT keeps working server-side when the tab loses its stream
        # ("Connection interrupted", error banners, a frozen reply), so a stuck tab is reloaded
        # instead of waiting out the whole timeout.
        idle_s = self.cfg.get("stuck_idle_s", 240)          # nothing streaming, nothing new
        frozen_s = self.cfg.get("stuck_frozen_s", 900)      # "streaming" but no visible change
        max_reloads = self.cfg.get("max_reloads", 3)
        idle_reloads = self.cfg.get("stuck_idle_reloads", 1)   # see reload_cap
        last_sig, last_change, reloads, resends = None, time.time(), 0, 0
        # Owner 2026-10-16: cycle 339's LANESPLAN prompt never reached the chat (the tab stayed on the empty new-chat
        # page beside "Unable to load history" errors). The bridge idled 15 min, reloaded onto the same empty page and
        # would have idled 3 x 15 min more. A prompt with no sign of arriving after unposted_s fails the ask, so the
        # controller's retry opens a fresh tab and sends it again.
        unposted_s = self.cfg.get("unposted_s", 300)
        sent_at, posted = time.time(), False
        last, stable = None, 0
        listed = not self.cfg.get("archive_chats", True)
        while True:
            check()
            # "local-chatgpt%3A..." is ChatGPT's placeholder until the chat is saved (2026-10-21); wait for the real id
            if not listed and chat_id(page.url) and not chat_id(page.url).startswith("local-"):
                # Owner 2026-10-21 "the archiving isnt working again": asks that never reached _ask_once's finally
                # (a lane process ended, a halt killed the run) left their chats unlisted, so no sweep found them.
                note_unarchived(chat_id(page.url), open_=True)
                listed = True
                try:
                    page._relay_cid = chat_id(page.url)   # the finally below lists it even if the page moved on
                except Exception:   # noqa: BLE001
                    pass
            time.sleep(2)
            if done is not None and done():
                return "@@DONE_START@@ok@@DONE_END@@"
            if mode == "work":
                try:
                    limited = page.get_by_text(WORK_LIMIT_RE).count() > 0
                except PWError:
                    limited = False
                if limited:
                    raise WorkLimitReached(self._work_limit_text(page) or "out of Work usage")
            try:
                # A/B "Which option do you prefer?" screen hides the normal reply: skip it (no preference given).
                if page.get_by_text(COMPARE_RE).count():
                    skip = page.get_by_role("button", name="Skip", exact=True)
                    if skip.count():
                        self.log("chatgpt showed a response comparison; skipping it")
                        skip.first.click(timeout=5_000)
                        last_sig, last_change = None, time.time()
                        continue
            except PWError:
                pass
            if resends < max_reloads and resend_undelivered(page, self.log):
                resends += 1
                last_sig, last_change, sent_at = None, time.time(), time.time()
                continue
            try:
                n = page.locator(s["assistant"]).count()
                streaming = page.locator(s["stop"]).count() > 0
                cur = page.locator(s["assistant"]).last.inner_text(timeout=10_000) if n > before else ""
                errored = page.get_by_text(ERROR_RE).count() > 0
                convo = len(page.locator("main").first.inner_text(timeout=10_000))  # tool steps count too
            except PWError:
                continue   # page mid-navigation; the idle clock still runs
            if not posted:
                posted = prompt_posted(page, s, n, before, streaming)
                if not posted and time.time() - sent_at > unposted_s:
                    raise BridgeError(f"the prompt never reached the chat ({time.time() - sent_at:.0f}s after "
                                      "sending: no user turn, conversation URL or reply)")
            sig = (n, len(cur), streaming, convo)
            if sig != last_sig:
                last_sig, last_change = sig, time.time()
            idle = time.time() - last_change
            if errored or (not streaming and idle > idle_s) or idle > frozen_s:
                if reloads >= reload_cap(errored, max_reloads, idle_reloads):
                    raise BridgeError(f"reply stuck after {reloads} reloads "
                                      f"({'error banner' if errored else f'no change for {idle:.0f}s'})")
                reloads += 1
                self.log(f"chatgpt tab looks stuck ({'error banner' if errored else f'idle {idle:.0f}s'}); "
                         f"reloading ({reloads}/{max_reloads})")
                try:
                    page.reload(wait_until="domcontentloaded", timeout=60_000)
                except PWError:
                    pass
                time.sleep(5)
                last_sig, last_change, last, stable = None, time.time(), None, 0
                continue
            if n <= before:
                continue
            stable = stable + 1 if (not streaming and cur and cur == last) else 0
            if stable >= 3:
                return cur
            last = cur
