"""
Visual playtest for the relay: export the game for the Web from a throwaway clone, load it in
headless Chrome (Playwright), and capture full-resolution screenshots of fixed scenarios.

The clone (cfg["clone"]) is reset to the given commit every run and gets the relay's generic
playtest_overlay/ (a Web export preset) on top, then the GAME's own overlay from
.review/full_game/playtest_overlay/ if it exists (a playtest/showcase.tscn main scene with JS hooks,
a playtest/tour.gd autoload). Nothing is ever written to the game repo. Without a game overlay only
the title scenario runs (the real main scene).

JS hooks are window.<hook_prefix>Ready, <hook_prefix>Damage(f), <hook_prefix>Status(),
<hook_prefix>LastStatus, <hook_prefix>TourReady/TourError/TourWave()/TourWaveStarted
(relay.json playtest.hook_prefix, default "relay").

    python playtest.py [commit]      # standalone run, prints the result JSON

Scenarios:
  title          ?mode=game   the real boot flow (export smoke test: console errors land here)
  boss:<id>      ?boss=<id>   every <boss_dir>/*.tres (default data/bosses); spawn, 69% HP (+1s, +3s),
                              34% HP (+1s, +3s)
  roster_*       cfg rosters  [[name, query], ...] lineup screens the game's showcase offers
  tour_*         ?tour=...    the real app via the game's playtest/tour.gd: map, a briefing,
                              cfg tour_battles (READY, then a start hook) and the ending screen
"""
from __future__ import annotations

import functools
import http.server
import json
import re
import shutil
import subprocess
import sys
import threading
import time
from pathlib import Path

import game as G

HERE = Path(__file__).resolve().parent
OVERLAY = HERE / "playtest_overlay"
GAME_OVERLAY = HERE.parent / "full_game" / "playtest_overlay"

# Known export-only bug: DirAccess.get_files() sees "*.tres.remap" in exported builds. Applied to the
# clone only when the boot smoke test shows the catalog failing, so boss scenarios can still run;
# the smoke result still reports the bug.
CATALOG_FIX = (
    "for file_name in da.get_files():",
    "for file_name in ResourceLoader.list_directory(dir_path):",
)

# Missions shown by the tour (relay.json playtest.tour_battles).
TOUR_BATTLES: list[str] = []
TOUR_AUTOLOAD = 'PlaytestTour="*res://playtest/tour.gd"'

ROSTERS: list[tuple[str, str]] = []   # relay.json playtest.rosters

CATALOG_FAIL_RE = re.compile(r"ContentCatalog validation failed|is missing or failed to load", re.I)


class PlaytestError(Exception):
    pass


def _run(argv, cwd, timeout=900):
    r = subprocess.run(argv, cwd=cwd, capture_output=True, text=True, encoding="utf-8",
                       errors="replace", timeout=timeout)
    return r.returncode, (r.stdout or "") + (r.stderr or "")


class Playtest:
    def __init__(self, cfg: dict, repo: Path, log=print):
        self.cfg = cfg
        self.repo = Path(repo)
        self.clone = Path(cfg.get("clone", G.tmp_dir("playtest")))
        self.godot = cfg["godot"]
        self.log = log
        self.hp = re.sub(r"[^A-Za-z0-9_]", "", cfg.get("hook_prefix", "relay")) or "relay"
        self.rosters = [tuple(r) for r in cfg.get("rosters", ROSTERS)]
        self.boss_dir = cfg.get("boss_dir", "data/bosses")
        self.level_dir = cfg.get("level_dir", "data/levels")

    def has_showcase(self) -> bool:
        return (self.clone / "playtest" / "showcase.tscn").exists()

    # ---- clone + export

    def sync(self, commit: str) -> None:
        if not (self.clone / ".git").exists():
            rc, out = _run(["git", "clone", "-q", str(self.repo), str(self.clone)], cwd=self.repo.parent)
            if rc:
                raise PlaytestError(f"clone failed: {out[-300:]}")
        for argv in (["git", "fetch", "-q", str(self.repo), "+refs/heads/*:refs/remotes/src/*"],
                     ["git", "reset", "-q", "--hard", commit],
                     ["git", "clean", "-q", "-fd", "-e", "shots"]):
            rc, out = _run(argv, cwd=self.clone)
            if rc:
                raise PlaytestError(f"{' '.join(argv[:2])} failed: {out[-300:]}")
        shutil.copytree(OVERLAY, self.clone, dirs_exist_ok=True)
        if GAME_OVERLAY.is_dir():
            shutil.copytree(GAME_OVERLAY, self.clone, dirs_exist_ok=True)
        proj = self.clone / "project.godot"
        s = proj.read_text(encoding="utf-8")
        if self.has_showcase():
            s = re.sub(r'run/main_scene="[^"]*"', 'run/main_scene="res://playtest/showcase.tscn"', s)
        if (self.clone / "playtest" / "tour.gd").exists() and TOUR_AUTOLOAD not in s:
            s = (s.replace("[autoload]\n", f"[autoload]\n\n{TOUR_AUTOLOAD}\n", 1) if "[autoload]\n" in s
                 else s.rstrip("\n") + f"\n\n[autoload]\n\n{TOUR_AUTOLOAD}\n")
        if "window/stretch/mode" not in s:
            s = s.replace("[display]\n", '[display]\n\nwindow/stretch/mode="canvas_items"\nwindow/stretch/aspect="keep"\n', 1)
        proj.write_text(s, encoding="utf-8")

    def export(self) -> None:
        _run([self.godot, "--headless", "--path", str(self.clone), "--import"], cwd=self.clone, timeout=900)
        out_dir = self.clone / "build" / "web"
        out_dir.mkdir(parents=True, exist_ok=True)
        rc, out = _run([self.godot, "--headless", "--path", str(self.clone), "--export-debug", "Web",
                        str(out_dir / "index.html")], cwd=self.clone, timeout=900)
        if not (out_dir / "index.wasm").exists() or not (out_dir / "index.pck").exists():
            raise PlaytestError(f"web export failed (rc={rc}): {out[-600:]}")

    def apply_catalog_workaround(self) -> bool:
        p = self.clone / "scripts" / "content" / "content_catalog.gd"
        if not p.exists():
            return False
        s = p.read_text(encoding="utf-8")
        if CATALOG_FIX[0] not in s:
            return False
        p.write_text(s.replace(CATALOG_FIX[0], CATALOG_FIX[1]), encoding="utf-8")
        return True

    # ---- browser

    def _serve(self):
        handler = functools.partial(_QuietHandler, directory=str(self.clone / "build" / "web"))
        srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
        threading.Thread(target=srv.serve_forever, daemon=True).start()
        return srv, f"http://127.0.0.1:{srv.server_address[1]}/index.html"

    def _capture(self, url: str, shots: Path, scenarios: list[tuple[str, str]]) -> dict:
        from playwright.sync_api import sync_playwright
        results = {}
        with sync_playwright() as p:
            browser = p.chromium.launch(channel="chrome", headless=True, args=[
                "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"])
            try:
                for name, query in scenarios:
                    results[name] = self._scenario(browser, url + query, name, shots)
            finally:
                browser.close()
        return results

    def _scenario(self, browser, url: str, name: str, shots: Path) -> dict:
        page = browser.new_page(viewport={"width": 1280, "height": 720})
        errors: list[str] = []
        page.on("console", lambda m: errors.append(m.text) if m.type == "error" else None)
        page.on("pageerror", lambda e: errors.append(f"pageerror: {e}"))
        files: list[str] = []
        safe = re.sub(r"[^A-Za-z0-9_-]", "_", name)

        def shot(tag):
            f = shots / f"{safe}_{tag}.png"
            page.screenshot(path=str(f))
            files.append(str(f))

        try:
            page.goto(url, wait_until="load", timeout=60_000)
            if name.startswith("title"):
                time.sleep(8)
                shot("boot")
            elif name.startswith("tour_"):   # real app screens on other stages (tour.gd)
                try:
                    page.wait_for_function(f"window.{self.hp}TourReady === true || !!window.{self.hp}TourError",
                                           timeout=90_000)
                except Exception:
                    shot("not_ready")
                    return {"ok": False, "errors": errors[-40:], "shots": files}
                err = page.evaluate(f"window.{self.hp}TourError || ''")
                if err:
                    shot("error")
                    return {"ok": False, "errors": errors[-40:] + [f"tour: {err}"], "shots": files}
                time.sleep(3)
                if name.startswith("tour_battle"):
                    shot("ready")
                    page.evaluate(f"window.{self.hp}TourWave()")
                    time.sleep(7)   # about 14 game seconds at 2x: wave 1 on the road
                    shot("wave")
                    started = page.evaluate(f"window.{self.hp}TourWaveStarted === true")
                    return {"ok": True, "errors": errors[-40:], "shots": files,
                            "status": "wave 1 started" if started else "wave 1 did NOT start"}
                shot("screen")
            elif name.startswith("roster"):   # a lineup screen from the game's showcase
                try:
                    page.wait_for_function(f"window.{self.hp}Ready === true", timeout=60_000)
                except Exception:
                    shot("not_ready")
                    return {"ok": False, "errors": errors[-40:], "shots": files}
                time.sleep(3)
                shot("lineup")
            else:
                try:
                    page.wait_for_function(f"window.{self.hp}Ready === true", timeout=60_000)
                except Exception:
                    shot("not_ready")
                    return {"ok": False, "errors": errors[-40:], "shots": files}
                time.sleep(2)
                shot("spawn")
                for frac, label in ((0.69, "p2"), (0.34, "p3")):
                    page.evaluate(f"window.{self.hp}Damage({frac})")
                    time.sleep(1)
                    shot(f"{label}_t1")
                    time.sleep(2)
                    shot(f"{label}_t3")
                page.evaluate(f"window.{self.hp}Status()")
                status = page.evaluate(f"window.{self.hp}LastStatus || ''")
                return {"ok": True, "errors": errors[-40:], "shots": files, "status": status}
            return {"ok": True, "errors": errors[-40:], "shots": files}
        except Exception as e:
            return {"ok": False, "errors": errors[-40:] + [f"harness: {e!r}"], "shots": files}
        finally:
            page.close()

    # ---- entry

    def tour_scenarios(self) -> list[tuple[str, str]]:
        if not (self.clone / "playtest" / "tour.gd").exists():
            return []
        battles = self.cfg.get("tour_battles", TOUR_BATTLES)
        return ([("tour_map", "?tour=map"), (f"tour_briefing_{battles[-1]}", f"?tour=briefing&mission={battles[-1]}")]
                + [(f"tour_battle_{m}", f"?tour=battle&mission={m}") for m in battles]
                + [("tour_ending", "?tour=ending")]) if battles else []

    def scenario_query(self, name: str) -> str | None:
        """The URL query of a named scenario (as the full run names them), or None. tour_battle_<mission> and
        tour_briefing_<mission> work for any mission, not only the full run's tour battles."""
        if name == "title":
            return "?mode=game"
        if (name.startswith("boss_") and self.has_showcase()
                and (self.clone / self.boss_dir / f"{name[5:]}.tres").exists()):
            return f"?boss={name[5:]}"
        if name in dict(self.rosters):
            return dict(self.rosters)[name]
        if (self.clone / "playtest" / "tour.gd").exists():
            if name in ("tour_map", "tour_ending"):
                return f"?tour={name[5:]}"
            for kind in ("battle", "briefing"):
                mission = name[len(f"tour_{kind}_"):] if name.startswith(f"tour_{kind}_") else ""
                if mission and (self.clone / self.level_dir / f"{mission}.tres").exists():
                    return f"?tour={kind}&mission={mission}"
        return None

    def capture(self, commit: str, shots: Path, names: list[str]) -> dict:
        """Screenshots of only the named scenarios at one commit (the visual lane's before/after check)."""
        shots.mkdir(parents=True, exist_ok=True)
        self.sync(commit)
        self.export()
        chosen = [(n, q) for n in dict.fromkeys(names) if (q := self.scenario_query(n))]
        if not chosen:
            return {}
        srv, url = self._serve()
        try:
            res = self._capture(url, shots, chosen)
            failed = [r for r in res.values() if not r.get("ok")]
            if any(CATALOG_FAIL_RE.search(e) for r in failed for e in r["errors"]) and self.apply_catalog_workaround():
                self.export()
                res = self._capture(url, shots, chosen)
        finally:
            srv.shutdown()
        return res

    def run(self, commit: str, shots: Path) -> dict:
        t0 = time.time()
        shots.mkdir(parents=True, exist_ok=True)
        self.sync(commit)
        self.export()
        srv, url = self._serve()
        try:
            res = {"commit": commit, "workaround": False}
            res["title"] = self._capture(url, shots, [("title", "?mode=game")])["title"]
            bosses = ([(f"boss_{b}", f"?boss={b}")
                       for b in sorted(p.stem for p in (self.clone / self.boss_dir).glob("*.tres"))]
                      if self.has_showcase() else [])
            res["scenarios"] = self._capture(url, shots, bosses) if bosses else {}
            res["scenarios"].update(self._capture(url, shots, self.rosters) if self.rosters else {})
            res["scenarios"].update(self._capture(url, shots, self.tour_scenarios()))
            failed = [r for r in res["scenarios"].values() if not r.get("ok")]
            if any(CATALOG_FAIL_RE.search(e) for r in failed for e in r["errors"]):
                res["export_catalog_broken"] = True
                if self.apply_catalog_workaround():
                    res["workaround"] = True
                    self.export()
                    res["title_workaround"] = self._capture(url, shots, [("title_wa", "?mode=game")])["title_wa"]
                    res["scenarios"] = self._capture(url, shots, bosses) if bosses else {}
                    res["scenarios"].update(self._capture(url, shots, self.tour_scenarios()))
        finally:
            srv.shutdown()
        res["seconds"] = round(time.time() - t0)
        return res


class _QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


def facts_text(res: dict) -> str:
    """Plain summary of a run for the reviewer prompt."""
    lines = [f"commit {res['commit']}, {res.get('seconds', '?')}s"]
    t = res.get("title", {})
    lines.append(f"- title (boot flow): ok={t.get('ok')} shots={t.get('shots')}")
    if t.get("errors"):
        lines.append("  console errors:\n" + "\n".join(f"    {e}" for e in t["errors"][:25]))
    if res.get("title_workaround"):
        lines.append(f"- title with workaround: shots={res['title_workaround'].get('shots')}")
    if res.get("export_catalog_broken"):
        lines.append("- EXPORT BUG: the exported build's ContentCatalog failed to load content"
                     + (" (playtest applied a local workaround for the scenarios below)" if res.get("workaround") else ""))
    for name, r in (res.get("scenarios") or {}).items():
        lines.append(f"- {name}: ok={r.get('ok')} status={r.get('status', '')}")
        lines.append("  shots: " + ", ".join(r.get("shots", [])))
        if r.get("errors"):
            lines.append("  console errors:\n" + "\n".join(f"    {e}" for e in r["errors"][:15]))
    return "\n".join(lines)


if __name__ == "__main__":
    cfg = json.loads((HERE / "relay.json").read_text(encoding="utf-8"))
    repo = Path(cfg["repo"])
    commit = sys.argv[1] if len(sys.argv) > 1 else cfg.get("main_branch", "master")
    pcfg = cfg.get("playtest") or {}
    if "godot" not in pcfg:   # run_tests.py executes on import, so read its constant as text
        pcfg["godot"] = re.search(r'^GODOT = r"([^"]+)"', (HERE / "run_tests.py").read_text(encoding="utf-8"),
                                  re.M).group(1)
    pt = Playtest(pcfg, repo)
    result = pt.run(commit, HERE / "playtests" / "manual" / "shots")
    print(json.dumps(result, indent=2))
    print(facts_text(result))
