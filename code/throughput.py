"""Task ownership, revalidation and report checks; no agents or git mutations."""
from __future__ import annotations

import hashlib
import datetime
import json
import re
from pathlib import Path, PurePosixPath


def block(text: str, name: str) -> str | None:
    m = re.search(rf"@@{name}_START@@(.*?)@@{name}_END@@", text, re.S)
    return m.group(1).strip() if m else None


def scope(text: str, title: str = "") -> dict:
    """Explicit write/read ownership; legacy tasks get conservative inferred paths."""
    raw = block(text, "TASK_SCOPE")
    if raw is not None:
        value = json.loads(raw)
        if not isinstance(value, dict) or not isinstance(value.get("feature"), str) or not value["feature"].strip():
            raise ValueError("TASK_SCOPE needs a feature")
        for field in ("files", "depends_on"):
            paths = value.get(field, [])
            if not isinstance(paths, list) or any(not isinstance(p, str) for p in paths):
                raise ValueError(f"TASK_SCOPE {field} must be a list of paths")
            if field == "depends_on":
                # 2026-10-22: cycle 132's battle HUD plan named .review/relay_v2/playtests/PLAYTEST_125.md as a file it
                # read, and the whole plan was rejected twice ("cannot own relay or other worktree files"). Reading a
                # relay report owns nothing, so such dependencies are dropped; owned files still may not be relay files.
                paths = [p for p in paths if not relay_path(p)]
            value[field] = sorted(set(clean_path(p) for p in paths))
        if not value["files"]:
            raise ValueError("TASK_SCOPE needs owned files")
        return {"feature": value["feature"].strip(), "files": value["files"],
                "depends_on": value["depends_on"], "explicit": True, "title": title.strip(),
                "size": size(value.get("size"), value["files"])}
    owned = re.search(r'(?ims)^#{1,3}\s+Files(?: likely touched| to change| changed)?\s*\n(.*?)(?=^#{1,3}\s|\Z)', text)
    source = owned.group(1) if owned else text
    paths = re.findall(r"(?:scripts|tests|data|scenes|assets)/[a-zA-Z0-9_./-]+\.(?:gd(?:\.uid)?|tres|tscn|json|png|md)", source)
    files = sorted(set(paths))
    return {"feature": title.strip(), "files": files, "depends_on": [], "explicit": False, "size": size(None, files)}


SIZES = ("small", "medium", "large")


def size(value, files: list) -> str:
    """Owner 2026-10-20: "make the free models do easier things and let go deepseek do harder things and codex even
    harder". The planner rates each task small/medium/large in TASK_SCOPE; without a rating the owned file count
    decides (up to 3 small, up to 6 medium). controller.fallback_model routes by it."""
    v = str(value or "").strip().lower()
    if v in SIZES:
        return v
    return "small" if len(files) <= 3 else "medium" if len(files) <= 6 else "large"


def relay_path(value: str) -> bool:
    v = value.strip().replace("\\", "/").removeprefix("res://").lower()
    return v.startswith((".review/relay_v2/", ".lanes/", ".git/"))


def clean_path(value: str) -> str:
    value = value.strip().replace("\\", "/").removeprefix("res://")
    path = PurePosixPath(value)
    if not value or path.is_absolute() or ".." in path.parts or ":" in value or any(c in value for c in "*?[]"):
        raise ValueError(f"TASK_SCOPE needs a concrete repository-relative path: {value}")
    if path.parts[0].lower() in (".git", ".lanes") or value.lower().startswith(".review/relay_v2/"):
        raise ValueError("TASK_SCOPE cannot own relay or other worktree files")
    return path.as_posix()


# Owner 2026-10-11: hub files every feature hooks into (scripts/main.gd, 9k lines) are SHARED: no coder owns them,
# so one lane reserving main.gd no longer bars every other coder from wiring its feature into the game. Parallel
# small edits merge with git; a clash there requeues the task (controller._merge_one).
SHARED: set = set()


def _unit(p: str) -> str:
    return p.lower().removesuffix(".uid").removesuffix(".import")


def set_shared(paths: list[str]) -> None:
    global SHARED
    SHARED = {_unit(clean_path(p)) for p in paths}


def is_shared(path: str) -> bool:
    return _unit(path.strip().replace("\\", "/")) in SHARED


def writes(contract: dict) -> set[str]:
    # Treat required sidecars as the same ownership unit as their source.
    return {_unit(p) for p in contract.get("files", [])} - SHARED


def conflict(candidate: dict, active: dict) -> str | None:
    own = writes(candidate)
    reads = {_unit(p) for p in candidate.get("depends_on", [])} - SHARED
    for owner, other in active.items():
        overlap = (own | reads) & writes(other)
        # A writer may not invalidate another active task's declared read dependencies.
        overlap |= own & writes({'files': other.get('depends_on', [])})
        if overlap:
            return f"{owner} owns or depends on {', '.join(sorted(overlap))}"
        feature = candidate.get("feature", "").casefold()
        if feature and feature == other.get("feature", "").casefold():
            return f"{owner} owns feature {candidate['feature']}"
        if similar_feature(candidate, other):
            return (f"{owner} is already building the same feature "
                    f"({other.get('title') or other.get('feature', '')})")
    return None


# Owner 2026-10-10: three coders built Ragwheel's sprint at once in DIFFERENT new files, so path ownership never
# saw it. Two tasks whose titles/features share several distinctive words are the same feature.
_GENERIC = set("""give make implement apply with from that their they this into when while after before live real exact
existing only each combat battle test tests wave waves enemy enemies ground route routes bounded capped expansion player
players standard opening saves save profile more than also across between nearby along under over upon them have does
your will must should could would within without other same every first second third card cards tower towers lane
behaviour behavior system state data logic support allow allowed using uses used keep keeps hold prove zero training
fourth defense defence isolated adapter
cast casts paid locked hand hands mixed mana gold deck decks five spell spells hero heroes exclusive upgrade upgrades
upgraded shop shops sell sells purchase purchasable replacement replacements replace persist persistent retire retired
stage stages battle battles boss bosses elite elites branching branch rank ranks path paths authored charge charges
play plays playing card round rounds wave waves cleared clear real legacy runs""".split())
# Owner 2026-10-10: template words that repeat across many task titles ("Cast X from a paid locked hand") are not a
# feature; words seen in >= COMMON_MIN recent titles are ignored too (set by the controller from task history).
COMMON_MIN = 5
_COMMON: set = set()


def set_common_titles(titles: list[str]) -> None:
    """Treat stems that appear in COMMON_MIN or more recent task titles as template words."""
    global _COMMON
    import collections
    counts = collections.Counter(stem for t in dict.fromkeys(titles) for stem in _stems(t))
    _COMMON = {stem for stem, n in counts.items() if n >= COMMON_MIN}


def _stems(text: str) -> set[str]:
    return {w[:6] for w in re.findall(r"[a-z]{4,}", text.lower()) if w not in _GENERIC}


def feature_words(text: str) -> set[str]:
    return _stems(text) - _COMMON


def _alike(wa: set, wb: set) -> bool:
    shared = wa & wb
    return len(shared) >= 4 or (len(shared) >= 3 and len(shared) / max(1, len(wa | wb)) >= 0.45)


def similar_feature(a: dict, b: dict) -> bool:
    """Titles alone, or titles plus feature descriptions, share several distinctive words."""
    ta, tb = feature_words(a.get('title', '')), feature_words(b.get('title', ''))
    return (bool(ta and tb) and _alike(ta, tb)) or _alike(
        ta | feature_words(a.get('feature', '')), tb | feature_words(b.get('feature', '')))


def fingerprints(root: Path, contract: dict) -> dict:
    result = {}
    root = root.resolve()
    for name in sorted(set(contract.get("files", []) + contract.get("depends_on", []))):
        p = (root / clean_path(name)).resolve()
        if not p.is_relative_to(root):
            raise ValueError("task path leaves repository")
        result[name] = hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else None
    return result


def changed_read_dependencies(manifest: dict, current: dict) -> list[str] | None:
    """Refresh only read drift; missing hashes or changed write/sidecar paths require replanning."""
    previous = manifest.get('fingerprints')
    contract = manifest.get('scope', {})
    if not isinstance(previous, dict) or previous.keys() != current.keys():
        return None
    changed = sorted(p for p in current if current[p] != previous[p])
    owned = writes(contract)
    reads = set(contract.get('depends_on', []))
    if not changed or any(p not in reads or writes({'files': [p]}) & owned for p in changed):
        return None
    return changed


def changed_task_paths(manifest: dict, current: dict) -> tuple[list[str], list[str]] | None:
    """Owner 2026-10-13: (owned write paths, read dependencies) that changed since planning, or None when the
    baseline is missing. Owned-file drift used to force a fresh 15-24 min plan (cycles 189, 195, 196: lane merges
    touched scripts/main.gd); a short refresh check decides instead."""
    previous = manifest.get('fingerprints')
    if not isinstance(previous, dict) or previous.keys() != current.keys():
        return None
    changed = sorted(p for p in current if current[p] != previous[p])
    owned = writes(manifest.get('scope', {}))
    return ([p for p in changed if writes({'files': [p]}) & owned],
            [p for p in changed if not writes({'files': [p]}) & owned])


def cycle_timing(timeline: list, ended_at: str, target_minutes: float) -> dict:
    """Measure active phases separately from owner pause/down time; never enforce an acceptance deadline."""
    fmt = '%Y-%m-%d %H:%M:%S'
    end = datetime.datetime.strptime(ended_at, fmt)
    phases = {}
    for i, (phase, at) in enumerate(timeline):
        stop = datetime.datetime.strptime(timeline[i + 1][1], fmt) if i + 1 < len(timeline) else end
        minutes = max(0, (stop - datetime.datetime.strptime(at, fmt)).total_seconds() / 60)
        if phase not in ('IDLE', 'HALTED'):
            phases[phase] = phases.get(phase, 0) + minutes
    active = sum(phases.values())
    wall = max(0, (end - datetime.datetime.strptime(timeline[0][1], fmt)).total_seconds() / 60) if timeline else 0
    # Owner 2026-10-27 (relay improvements): 18 of 46 cycles were logged as overruns and the planner was told to
    # shrink the next task, but in 6 of them the build took 12-20 min and the rest was START/PLAN waiting for the
    # next plan (cycle 298: 27 min START, 12 min BUILD). The task size only changes the build, so the target is
    # judged on build_minutes; the planning wait is reported apart as wait_minutes.
    wait = sum(phases.get(p, 0) for p in WAIT_PHASES)
    return {'active_minutes': round(active, 2), 'wall_minutes': round(wall, 2),
            'build_minutes': round(active - wait, 2), 'wait_minutes': round(wait, 2),
            'phase_minutes': {p: round(v, 2) for p, v in phases.items()},
            'target_minutes': target_minutes, 'target_met': bool(timeline) and active - wait < target_minutes}


WAIT_PHASES = ('START', 'PLAN', 'BRIEF')


def acceptance_error(report: str, brief: str) -> str | None:
    """Check submitted evidence structure, never grant acceptance from a coder claim."""
    if "## Coder acceptance check" not in brief:
        return None  # keep already-running legacy tasks compatible
    raw = block(report, "ACCEPTANCE_CHECK")
    try:
        checks = json.loads(raw) if raw is not None else None
    except ValueError:
        return "ACCEPTANCE_CHECK is not valid JSON"
    if not isinstance(checks, list) or not checks:
        return "report needs an ACCEPTANCE_CHECK list mapping every criterion to code and verification"
    ids = []
    for row in checks:
        if not isinstance(row, dict) or any(not isinstance(row.get(k), str) or not row[k].strip()
                                           for k in ("criterion", "code", "verification", "result")):
            return "every acceptance check needs criterion, code, verification and result"
        if row["result"] != "PASS":
            return "completed report contains an unmet acceptance criterion"
        ids.append(row["criterion"])
    if len(ids) != len(set(ids)):
        return "duplicate acceptance criteria in report"
    # Stable IDs are assigned by new plans. Legacy prose remains reviewable.
    required = set(re.findall(r"(?m)^\s*(?:(?:[-*]|\d+[.)])\s*)?(AC\d+)\s*[:.)-]", brief))
    if required and not required <= set(ids):
        return "missing acceptance criteria: " + ", ".join(sorted(required - set(ids)))
    return None
