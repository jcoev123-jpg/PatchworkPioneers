"""Prompt templates for the relay. string.Template syntax ($name).

Game-agnostic (owner 2026-10-20): @TOKENS@ are filled once at import from relay.json "game" (game.py)."""
from pathlib import Path
from string import Template

import game as G

# Owner policy, 2026-10-09. Appended to tasks so it also covers older narrow briefs.
CODER_SCOPE_POLICY = """
## Owner standing authority for supporting changes (2026-10-09)
The task's goal and acceptance criteria remain fixed. Its initial file list is a starting
boundary, not a prohibition on a small change needed to implement that same goal correctly.
You may update existing regression tests when the authorized behavior makes an old expectation
obsolete, and make the smallest necessary supporting code changes outside the initial list.
This permission supersedes historical blanket 'no shared test edits' or read-only-test rules.
Explain each supporting path, why it is necessary, and what coverage you preserved in your report.
Keep negative, fail-closed, no-spend, replay and regression coverage; never skip/delete/weaken
tests, special-case a test fixture, or claim success without the required checks.
Hard boundaries still apply: do not change goals, acceptance rules, unrelated balance or features,
relay instructions/configuration, or files/features assigned to another active coding lane.
Keep git/branch/merge permissions exactly as assigned by the controller; never grant acceptance
or merge into master yourself. Cloud tasks may commit/push only their expressly assigned branch.
Omit optional expansion and finish the bounded task. If completion actually requires crossing a
hard boundary, preserve the work and explain the decision in your assigned report instead of
asking an interactive question or repeating the same repair. Include exactly:
@@CODER_STATUS_START@@
{"status":"DEFERRED","reason":"specific hard boundary and why the task cannot finish without it"}
@@CODER_STATUS_END@@
The controller saves deferred work and continues other approved tasks; this creates no pause.
For completed work use the same markers with {"status":"COMPLETED"}.
"""

PLANNER_SCOPE_POLICY = """
## Owner scope policy for plans and briefs (2026-10-09)
Plan a bounded goal with unchanged acceptance rules. Name existing regression tests whose
expectations must change with that goal, and preserve their failure/negative coverage.
Coders have standing authority for the smallest necessary supporting code/test corrections,
including existing shared tests; do not generate a blanket prohibition contradicting the goal.
Concurrent lane ownership, unrelated balance/features and relay instructions remain protected.
Include this standing authority in generated coding tasks. A task requiring a new owner decision
is deferred and saved, not sent through more coding/rescue attempts and not paused automatically.
Do not choose an unchanged deferred task again; select another already-authorized bounded task
or a smaller slice that avoids the recorded decision. Deferral never authorizes a new goal.
Task size (owner 2026-11-05): a task that would fill in a whole roster, catalog or set at once (every hero's parts,
all foes of a region, a full ability table) is split: plan only the first piece, touching 1-2 code/data files plus
their tests, and leave the rest for the next tasks. Such whole-set tasks ran 50-80 min instead of under 30.
"""

REVIEW_SCOPE_POLICY = """
## Owner review policy for supporting changes (2026-10-09)
Judge the actual diff against the goal and acceptance criteria. A necessary small supporting
code/test correction outside the initial list is owner-authorized: do not reject it solely for
its file path, including historical 'no shared test edits' restrictions. Verify necessity, its
report explanation, preserved negative/regression coverage and all required tests yourself.
Goals, acceptance rules, unrelated balance/features, relay instructions and active lane ownership
remain hard boundaries. Optional unrelated changes are FIX_REQUIRED with concrete removal steps.
If the task itself cannot finish without a new hard-boundary decision, return DEFERRED with a
specific summary instead of requesting another coder/rescue. Never accept deferred work.
Protocol amendment: verdict may be ACCEPTED, FIX_REQUIRED or DEFERRED in the existing JSON/markers.
Report/checklist formatting is diagnostic, not an implementation defect. If ACCEPTANCE_CHECK JSON
is missing or malformed, verify EVERY original criterion directly using code and controller tests;
do not request a coding attempt solely to reformat a report. Unsupported claims or actually unmet
criteria still require correction. A coder's PASS claim never grants acceptance.
DEFERRED needs a nonblank summary naming the decision and why a bounded repair cannot solve it.
The controller preserves that work and continues other approved tasks; it adds no pause.

## Owner severity bar (2026-10-10): reject only real problems
FIX_REQUIRED only for: an unmet acceptance criterion, failing/skipped/weakened tests, a regression of existing
behaviour, a crash or script error, scope violations above, or a bug a player can realistically hit in normal play
(including saves/progression). Theoretical edge cases are NOT defects: pathological numeric input (sub-pixel or
1e-3 tolerances, NaN/inf from finite data), malformed data the game itself never produces, races that cannot occur
in the single-threaded game loop, or style/naming preferences. Mention those in the summary as follow-ups and ACCEPT.
Every rejection costs a full extra coding round, so make each defect concrete and player-relevant.
Reachability (owner 2026-10-11): state in the summary whether the new behaviour is reachable in real play (called from
the live game, its UI or data) or only from tests. When the task's own criteria require live play (e.g. "in live
battles", "at a stop", "on the run map") and only tests reach it, that is FIX_REQUIRED, unless the brief itself
forbids the file that live wiring needs (for example a shared wiring file reserved by another coder). Then, if everything
else is met and it introduces no player-visible bug, ACCEPT and name the missing live wiring as a follow-up in the
summary; do not DEFER for that alone, since a deferral leaves a whole cycle's working code unmerged.

## Duplicate features (owner 2026-10-10)
Other coders work in parallel. Before accepting, check the main branch (git log -15 and the scripts/tests it adds)
for an implementation of the SAME feature that is already merged (three coders once built the
same feature in separate new files). If the main branch already has it, return DEFERRED with a summary starting "duplicate of"
and naming the existing file/commit; the work is kept on its branch but not merged. Similar or related features that
add different behaviour are not duplicates.
"""


CODER_ACCEPTANCE_POLICY = """
## Coder acceptance check
Before submitting, check EVERY acceptance criterion against your actual diff and tests, within
this same coding session. Check real preconditions first so null objects, empty collections or
unexercised callbacks cannot make a test pass vacuously. Repair unmet requirements before reporting.
In your assigned report give a concise criterion-by-criterion checklist with code and verification.
Prefer one row per criterion between these markers (valid JSON):
@@ACCEPTANCE_CHECK_START@@
[{"criterion":"AC1","code":"repository path and function implementing it",
"verification":"test path and assertion, or concrete source inspection when that is the approved check",
"result":"PASS"}]
@@ACCEPTANCE_CHECK_END@@
Use the original criterion IDs; if absent, assign AC1, AC2, ... in the brief's original order.
Include every criterion, the full-suite result and necessary supporting changes. Missing JSON
formatting is a review warning, not a separate repair run; actual unmet requirements must be fixed.
This is evidence
for an independent reviewer, never permission to accept or merge your own work. If a hard boundary
prevents completion, report DEFERRED using the owner policy rather than claiming PASS.
Live reachability (owner 2026-10-11; the reviewer rejects on it): when a criterion says the behaviour happens in
real play (live battles, the run map, a stop or visit, saves), wire it into the real game path the player
uses (for example the app flow script or the scene/UI that calls it) and pass real objects there, never nulls or
test-only stand-ins; prove it with a test that drives that real path. Code reachable only from tests does not meet
such a criterion. If the brief forbids the file the wiring needs, say so in the checklist instead of claiming PASS.
Shared catalogs (owner 2026-10-13; other coders add entries to the same catalogs at the same time): in validators
and tests never hard-code a catalog's total ("exactly sixteen", size() == 16) or its full ordered ID list; check that
the required IDs are present instead. When you touch an existing total or full-list check, replace it with an
ID-presence check rather than bumping the number: those totals made parallel merges clash and redo accepted work.
Stop as soon as every criterion passes and the full suite is green: write the report and end the session; do not
keep polishing. Make that full-suite run your last step, after your final edit, and wait for it in the foreground
(never start it detached, and never run two at once; OpenCode's shell tool stops a command after 2 minutes unless
you pass a timeout, so give that command a timeout of 1800000 ms): when no file changes after it passes, the relay reuses it
instead of running the ~13 minute suite again. Do your own review BEFORE that run. Once it has started, edit again
only if it fails or an acceptance criterion is unmet; put any extra hardening you notice while waiting in the report
as a suggested follow-up (owner 2026-10-14: cycle 250's suite passed 531/531, then a hardening edit made beyond the
brief during the wait cost a second full run of ~14 minutes).
"""

TASK_PREPARATION_POLICY = """
## Ready-task contract and ownership
Prepare one coherent bounded task with its complete coding brief in this same response.
Label the acceptance criteria AC1, AC2, ... identically in plan and brief. For each criterion name
the intended behavior, the real preconditions and the test/inspection that can prove it.
List necessary existing-test corrections and preserve negative/fail-closed coverage.
Include this machine-readable block AFTER the main PLAN block, and INSIDE each lane task block:
@@TASK_SCOPE_START@@
{"feature":"specific feature or shared subsystem owned by this task",
"files":["concrete repository-relative paths this task may need to edit, including companions"],
"depends_on":["concrete source/resource paths whose contents the task depends on"],
"size":"small|medium|large"}
@@TASK_SCOPE_END@@
size picks the coder: small = one focused change in a few files (data entry, tuning, a small UI or
test fix); medium = a feature across several files with new tests; large = a cross-system change,
a new subsystem, or core lifecycle/save/combat logic. Free models take small tasks, stronger coders
the rest, so rate honestly.
Use concrete paths, no globs, absolute paths or directory-wide reservations. Include new files.
Do not assign overlapping write paths or a write path another active task depends on. Shared
lifecycle/catalog changes belong to ONE designated task, including main, at a time. Different
lanes can read the same stable file. Avoid artificially splitting one feature into dependent
parallel edits. A ready task's scope and file fingerprints are revalidated before launch.
Catalog appends (owner 2026-10-13): other tasks append entries to the same catalogs, tables and
their tests in parallel. When a task adds an entry, its criteria and test instructions check THIS
task's own entry (ID, fields, behaviour) and that the named earlier entries still exist, never
the exact total size, the full ordered ID list or a position ("the eighth pair", "size()==8").
Where an existing test asserts such a total or ordered list, tell the coder to replace it with
those per-entry checks, not to bump the number: exact totals make every parallel append clash
at merge, and the accepted work is then redone (19 redos on 2026-10-12/13).
Shared definitions (owner 2026-10-14): when a task changes an existing shared definition (an
enemy, hero, body part, ability or item: HP, damage, speed, cost), search the repository for its ID and name in
the brief every encounter, level and test that uses it. Then either confine the change to the
intended content, or allow the smallest setup correction in those tests that keeps what they
assert. Never list a test the change will affect under Do NOT. Cycle 252 changed a shared enemy,
forbade the suites using it, and was DEFERRED after 20 min when one of them failed.
Authored content lists (2026-10-15): when a task adds entries to an existing authored list (an
encounter, a spawn list, a parts table, a shop table), read that list first. State the change relative
to it ("two more X in group 3; every other entry unchanged"), never as a new absolute total, and
never require an order or timing relation that the prescribed entries contradict. Cycles 280 and
283 were DEFERRED with the work done for exactly that.
"""


# Owner 2026-10-10: every coder and planner sees the others working, in real time, so nobody overlaps.
LIVE_BOARD = (Path(__file__).resolve().parent / "LIVE_WORK.md").as_posix()

# Owner 2026-10-19: the periodic design review moved from Claude to ChatGPT (controller.design_review). Its ordered
# BAL NEXT MAIN STEPS sentence lives in DESIGN_NEXT.md (a data file the review rewrites) instead of four hard-coded
# copies in the planner prompts; DEFAULT_DESIGN_NEXT (relay.json game.design_next_default) is used when that file
# is missing or empty.
DESIGN_NEXT = Path(__file__).resolve().parent / "DESIGN_NEXT.md"
DEFAULT_DESIGN_NEXT = G.DESIGN_NEXT_DEFAULT
# Owner 2026-10-27: "change the design review so you dont need to keep updating it with my notes". Every review
# rewrote DESIGN_NEXT.md and dropped the owner's order, so the monitor re-merged it by hand after each one. The
# owner's standing order now lives in its own data file that only the owner/monitor edits; planners read it before
# the review's steps and the review reads it as input. Both files are read live (no restart needed).
OWNER_ORDER = Path(__file__).resolve().parent / "OWNER_ORDER.md"
OWNER_ORDER_MAX = 16000  # 11-04: was 2000, which cut the order after item (0); 11-08: 4000 cut the order
#                          mid item (6), so planners never saw items (7)-(10) ("look simpler", S12, S13).


def owner_order() -> str:
    """The owner's standing order as one paragraph, or "" when OWNER_ORDER.md is missing or empty."""
    try:
        return " ".join(OWNER_ORDER.read_text(encoding="utf-8").split())[:OWNER_ORDER_MAX]
    except OSError:
        return ""


def design_next() -> str:
    """The owner's standing order (if any), then the review's ordered BAL NEXT MAIN STEPS sentence for planners."""
    try:
        text = " ".join(DESIGN_NEXT.read_text(encoding="utf-8").split())
    except OSError:
        text = ""
    steps = text[:2500] if text.startswith("BAL NEXT MAIN STEPS") else DEFAULT_DESIGN_NEXT
    if "FINISH NOW" in steps:   # owner 2026-11-02: a top step that led two reviews is built whole, not in slices
        steps += (" PLANNER RULE: the step marked FINISH NOW has stalled across design reviews. While it is open, the"
                  " main cycle plans the WHOLE step as one build (as many files as it needs; the cycle size limit"
                  " does not apply) and meets its done test; never plan a slice it rules out. Side lanes keep their"
                  " own areas.")
    owner = owner_order()
    if not owner:
        return steps
    return ("OWNER ORDER (the owner's standing priorities, OWNER_ORDER.md; they outrank the review steps below, so "
            "plan the first open item first; a design review never changes them): " + owner + "\n" + steps)


class DesignTemplate(Template):
    """A planner template that fills $design_next from DESIGN_NEXT.md unless the caller passes it."""

    def substitute(self, mapping=None, /, **kws):
        return super().substitute({"design_next": design_next(), **(mapping or {}), **kws})

    def safe_substitute(self, mapping=None, /, **kws):
        return super().safe_substitute({"design_next": design_next(), **(mapping or {}), **kws})

LIVE_WORK_POLICY = f"""
## Live work board (other coders working right now)
Other coders work on this game at the same time, each in its own copy. {LIVE_BOARD} shows, refreshed about every
20 seconds, each one's task, the files it reserved and the files it is changing right now. Read it before you
edit any file outside the files your task names (a supporting change), and again before you finish. Never edit a
file another coder reserved or is changing: find another way, or leave it and explain in your report. Do not
overlap their features either.
What locks a file: only the "reserved" and "changing now" lists of a coder that is RUNNING (the main cycle, or a
lane that is coding, in a fix round, waiting for review or reviewing). A "reads" list is what that coder depends
on, not a lock, and a task "Claimed by planners" or in the queue has not started: it is re-checked against merged
code when it launches. So you may make a small necessary supporting edit (for example a test fixture your change
legitimately breaks) to a file that is listed only under "reads", or only by a queued or claimed task, even when
the brief calls such files read-owned. Name each in your report. Never DEFER only for that (owner 2026-10-13: cycle
205 was parked at 457/459 tests because a queued lane listed one fixture under "reads").
Exception: the SHARED files named at the top of the board (if any) may be edited by several coders at
once, so you may wire your feature into them. Keep such an edit to a few small hook lines that call into your own
script (put the logic there); never reformat, reorder, rename or move existing code in a shared file, so parallel
edits merge cleanly.
"""


ART_LATER_POLICY = """
## Art (owner 2026-10-24: visuals are AI-generated images, animated in Godot)
Characters, body parts, enemies, backgrounds, atmosphere (haze, light pools, motes, vignettes), hit effects and UI dressing
are AI-generated images from the relay's art pipeline (planners request them in an assets block; they land at
assets/paper/<category>/<id>.png before the tests run). Code places, layers and animates those images (tweens, drift,
sway, fade, scale, frame swaps), the way the heroes are animated. Never draw visuals in code (owner 2026-11-04: "make
sure that art isnt done with code since it looks bad"): no new _draw() overrides, draw_* calls, StyleBoxFlat.new(),
Gradient textures or particle nodes; panels, text boxes, frames, bars and buttons are ui images (NinePatchRect,
StyleBoxTexture, TextureProgressBar). The relay sends such changes back, and reviewers count new code-drawn visuals as
a defect. If a needed image is not there yet, reuse existing art or a
simple placeholder and keep the element's art path/id in its data so the image replaces it without code changes.
Never create or edit PNG files yourself. Reviewers: a missing image or a placeholder is never a defect, as long as the
element is readable and identifiable in play.
"""


def _shared_note() -> str:
    """relay.json shared_files: hub files several coders may edit at once (empty: none)."""
    if not G.SHARED_FILES:
        return ""
    return (f"{', '.join(G.SHARED_FILES)} {'is' if len(G.SHARED_FILES) == 1 else 'are'} SHARED (owner 2026-10-11): any "
            "task may list and edit it even when another coder lists it too, so never forbid it in a Do NOT. ")


def live_board_note() -> str:
    """For planners: check the live board just before answering."""
    return (f"\nLIVE WORK BOARD: {LIVE_BOARD} lists, in real time (about every 20 s), every coder's task, reserved "
            "files and the files it is changing right now, plus tasks other planners have just claimed. Read it "
            "again immediately before writing your final answer, and choose tasks whose files and features appear "
            "nowhere on it (no overlap). Do not even READ (list in depends_on) a file another coder reserved or is "
            "changing: such a task is rejected at launch, because that file will change under it. Build on merged "
            "code only.\n"
            # Owner 2026-10-11: cycles 161 and 162 were each DEFERRED (a whole cycle's work unmerged) because the
            # brief demanded live play while its Do NOT forbade scripts/main.gd, which another coder had reserved.
            "LIVE PLAY NEEDS ITS WIRING FILE: " + _shared_note() + "Never write a task whose "
            "objective or acceptance criteria need live play (in battle, at a stop, on the run map, in a "
            "shop/rest screen) while its Do NOT forbids, or another coder reserves, another file that must call the "
            "new code (the app/battle flow). Either choose a task whose wiring files are free and list them in the "
            "task's files, or scope the criteria to the service/data layer and its tests and write 'live wiring "
            "follows in a later task'.\n")


def coder_scope(text: str) -> str:
    """Apply current owner authority and acceptance checks to new tasks and repairs."""
    if '## Owner standing authority for supporting changes' not in text:
        text += '\n' + CODER_SCOPE_POLICY
    if '## Coder acceptance check' not in text:
        text += '\n' + CODER_ACCEPTANCE_POLICY
    if '## Live work board' not in text:
        text += '\n' + LIVE_WORK_POLICY
    if '## Art (owner' not in text:
        text += '\n' + ART_LATER_POLICY
    return text

PLAN = DesignTemplate("""\
You are the PLANNER in an automated build relay for @GAME@, @GAME_DESC@.
Repository root: $repo   (current branch: $branch, branched from $main)
Cycle: $cycle
Last accepted commit: $last_good
Recently accepted cycles:
$history

Task:
1. Inspect the repository: design docs, existing plans/roadmaps, scenes, scripts, tests, and `git log --oneline -30`.
2. Choose the single highest-priority BOUNDED improvement that moves the game toward a complete, shippable release.

Priority order (never choose a lower tier while a higher-tier blocker exists):
1. Broken or incomplete release-critical systems
2. Current milestone commitments
3. Gameplay depth
4. Usability / UI
5. Visual quality
6. Balancing / polish

Constraints:
- Audio is out of scope.
- One coding agent must be able to implement it in roughly 60 minutes, touching a focused set of files.
- It must be verifiable by automated tests run headless.
- Acceptance criteria may only require what `python .review/relay_v2/run_tests.py` or reading the code can prove. The
  coding agent's sandbox cannot run Godot, exports or a game boot directly; never require that. The relay itself runs
  the full suite and, after every accept, exports the game for the Web and boots it in a browser (the playtest).
- Do not redo or undo recently accepted work unless it is broken.
- When a planned behavior change makes an existing regression expectation obsolete, inspect that test and
  explicitly include the smallest necessary correction in both the plan and brief allowed-file lists.
  Preserve negative, fail-closed and no-spend coverage. Do not forbid a required test correction while demanding
  the new behavior and a passing full suite; unrelated files stay outside scope.
- Follow the owner focus below for what to plan now; a new feature brings its own visuals.
- Fixes that did not show: compare the newest playtest report ("Fixed since previous report" and the defects marked
  "still" or "unchanged") with the recently accepted cycles above. If a recently accepted cycle's own goal is reported
  unchanged or only partly fixed, that is the TOP priority, above everything except release blockers. Read that
  cycle's plan (.review/relay_v2/cycles/<NNN>/CLAUDE_PLAN.md) and the code it changed, find why the fix did not reach
  the screenshots (for example a second code path or anchor that still drives what is drawn), and plan the
  correction. Its tests must check what is actually drawn (the final position/size of the real nodes in the real
  battle view), not a helper or data value.
- Godot-generated sidecars (`*.import` for new images/assets, `*.gd.uid` for new scripts) are required companions of the files they belong to: they are always in scope, must be committed, and are never a defect. Never list them as forbidden in acceptance criteria.
- Do NOT modify any files. Read only.

Art: the game's art style is in .review/full_game/ART_STYLE.md. Coding agents cannot create or edit images. If your
task needs new images, list them (at most 6) in an assets block after @@PLAN_END@@; the relay generates them with
image AI into assets/paper/<category>/<id>.png WHILE the coding agent works (they are in place before the tests run).
Check assets/paper first and never request an asset that already exists, EXCEPT to fix a look-alike: suffix the id
with "!" (e.g. enemies/example_id!: ...) to have the relay write a new contrasting design and regenerate that image
(at most 3 per cycle; give the new palette and silhouette in the description; the code usually needs no change
because the file path stays the same). Use "backgrounds" ONLY for full-canvas scenes with no transparency; any object
with an outline is "props" (or its character category) and gets a transparent background.
Categories: @ART_CATEGORIES@. Each line: <category>/<snake_case_id>: <one-line visual description with subject, pose
and accent colour>. The plan must say exactly where and how each asset is used.
Owner 2026-10-24: visual dressing is AI art, not code. Atmosphere (felt motes, haze, warm light pools, thread wisps),
hit/heal effects, backgrounds and UI art are images requested here ("vfx" for small transparent pieces placed and
repeated in Godot; put a vignette or haze that fills the screen into the "backgrounds" image itself), then animated
in Godot (drift, sway, fade, scale, frame swaps) like the heroes. Never plan visual dressing drawn in code: panels,
text boxes, frames, bars and buttons are "ui" images too (NinePatchRect/StyleBoxTexture), never StyleBoxFlat or _draw();
the relay sends back changes that draw visuals in code (owner 2026-11-04).

@OWNER_FOCUS@
$design_next

Output exactly this, with nothing before the TITLE line:
TITLE: <short imperative title, or NONE if no improvement is warranted>
MILESTONE: <the STITCHED_DESIGN.md stage this work belongs to, e.g. S6 or S7, or OWNER for an owner-order item>
@@PLAN_START@@
## Goal
## Current state (relevant files and behaviour, with paths)
## Changes required
## Tests to add or update
## Acceptance criteria (each objectively checkable)
## Out of scope
@@PLAN_END@@
(optional, when the task needs new images: characters, part icons, backgrounds, atmosphere, effects, UI art)
@@ASSETS_START@@
bosses/example_id: one-line visual description
@@ASSETS_END@@
@@BRIEF_START@@
(the implementation brief for the coding agent, written from your plan; see below)
@@BRIEF_END@@

The brief is handed directly to the coding agent (DeepSeek via OpenCode): it can read and edit files and run commands,
it cannot commit, and it cannot create or edit images. Make it self-contained, keep every path exact, make every
acceptance criterion objectively testable, and leave out anything vague, oversized or out of scope (audio is out of
scope). Refer to requested images by their final paths (assets/paper/<category>/<id>.png). Use these sections:
# Objective
# Files to change
# Step-by-step implementation
# Tests to write or update
# Acceptance criteria
# Do NOT
""")

PLAN_FAST = DesignTemplate("""\
You are the read-only PLANNER for the @GAME@ Godot relay.
Repository: $repo; branch: $branch; main: $main; cycle: $cycle.
Last accepted commit: $last_good.
Recent work, blockers and active ownership:
$history

Target: under 30 minutes from cycle start through independent acceptance and merge, including
planning, coding, full controller tests and review. Choose ONE useful, cohesive behavior that an
existing coder can implement and check in about 12 minutes. Prefer 1-3 production files plus
focused regression tests/required sidecars and 3-4 concrete criteria. These are estimates, not
permission to omit a necessary supporting correction, weaken coverage or claim early acceptance.
Split a large feature into usable, independently correct increments. Live-wiring work (UNWIRED FEATURES) counts:
wire ONE player entry point per cycle (one caller in the live flow plus its end-to-end test), not a whole system.
If the recent active cycle times above show the target missed twice or more, choose a smaller increment than those
cycles did; when they show the build alone over 20 minutes (ChatGPT Chat builds about half as fast as Codex),
aim for half this size: 1-2 production files and 2-3 criteria. Never choose a cosmetic,
report-only or contrived task just to inflate cycle counts. Necessary real bug fixes are useful.

Inspect only the current milestone, newest relevant audit/playtest blockers, the targeted code
and existing tests needed to choose and specify the change. Use recent history above; avoid
re-reading the whole repository/roadmap or a general audit. Batch related reads. Planning target
is 3-5 minutes; total plan plus brief at most 600 words, excluding TASK_SCOPE. Do not plan lanes
in this reply: they are prepared separately during coding.

Priority: release-critical broken systems, current milestone commitments, gameplay depth, then
usability, as the owner focus below orders them. If a recently accepted fix still fails in the
latest playtest, correct its real rendered/runtime path ahead of other non-release work.
Read the relevant prior plan and test the public behavior, not only private helpers.
Audio and unrelated balance/features are out of scope. Do not redo accepted/deferred work
unchanged or overlap another lane's files, read dependencies or feature. Keep existing failure,
negative, no-spend and replay tests; explicitly name required existing-test updates. Required
Godot sidecars are permitted companions. Coders cannot create/edit images. Follow AGENTS.md.
Do not modify files. Every criterion must be provable by headless automated tests or source
inspection; full tests and independent review remain required. Omit optional scope expansion.

@OWNER_FOCUS@
$design_next

Output without code fences or preamble:
TITLE: <short imperative title, or NONE if no authorized improvement remains>
MILESTONE: <current milestone ID>
@@PLAN_START@@
## Goal and current behavior
<small useful goal, exact relevant paths and why it is next>
## Changes and tests
<concrete implementation and public-behavior/negative regression checks>
## Acceptance criteria
AC1: ...
AC2: ...
AC3: ...
## Out of scope
...
@@PLAN_END@@
@@TASK_SCOPE_START@@
{"feature":"specific owned behavior","files":["exact write paths"],"depends_on":["necessary read contracts"],"size":"small|medium|large"}
@@TASK_SCOPE_END@@
@@BRIEF_START@@
# Objective
# Files to change
# Implementation and tests
<self-contained exact paths, steps, required test corrections and verification>
# Acceptance criteria
<the same AC IDs and requirements>
# Do NOT
<hard boundaries; omit optional expansion>
@@BRIEF_END@@
""")

PLAN_REFRESH = Template("""\
Read-only dependency refresh for an already prepared @GAME@ task. Repository: $repo.
Prepared task: $plan_path. Ownership was checked (no other coder owns its files).
$changed

Target 2-3 minutes (a few more only to write a corrected task, see the end). Read the
prepared plan/brief, changed contracts and just the affected code
needed to decide whether the SAME small task, paths, steps and acceptance criteria remain valid
against current source. Do not re-research the roadmap or plan lanes. No source edits.
Return READY only if the unchanged brief is still complete and correct; otherwise REPLAN with
the concrete incompatibility. Do not silently change goals, criteria, paths or implementation.
This confirms dispatch readiness only; coding, full tests and independent review still follow.
Reply exactly, without code fences:
@@REFRESH_START@@
{"decision":"READY or REPLAN","reason":"specific evidence including changed contracts"}
@@REFRESH_END@@

On REPLAN you already know what is wrong, and a fresh plan costs 15-20 minutes while the cycle
waits (owner 2026-10-13). So after the REFRESH block, write the corrected task whenever a small
task toward the same goal still fits one cycle: the prepared plan's complete format, not a diff
(its TITLE and MILESTONE lines, then its PLAN, TASK_SCOPE and BRIEF blocks with the same markers).
Fix exactly the gaps you found: add the missing files and tests to the steps and to TASK_SCOPE
(every file it writes or reads), correct the criteria, or narrow it to a slice that still fits.
Keep it under 30 minutes of coding. Leave the corrected task out when the goal itself is done,
blocked or no longer right; the relay then plans afresh. The relay re-checks the corrected task's
scope and file ownership before any coding.
""")

BRIEF = Template("""\
You are turning a plan into an implementation brief for a coding agent (DeepSeek via OpenCode) working in a Godot project. The agent can read and edit files and run commands. It cannot commit.

First validate the plan: remove anything vague, oversized, or out of scope (audio is out of scope). Make every acceptance criterion objectively testable. Keep file paths exactly as given in the plan.

Reply in plain text. Do NOT put the markers inside code fences. Put the brief between the markers:

@@BRIEF_START@@
# Objective
# Files to change
# Step-by-step implementation
# Tests to write or update
# Acceptance criteria
# Do NOT
@@BRIEF_END@@

PLAN:
$plan
""")

# Owner 2026-10-20: a Windows "select an app to open this .gd file" box popped up. lane2 (cycle 448) wrote its
# report through `powershell -Command "..."`; the quoting broke and PowerShell ran report lines as commands, and a
# bare file path run as a command opens it through Windows' file associations.
REPORT_TOOL_RULE = ("- Write the report with your file write tool, never through a shell command (no echo, heredoc, "
                    "here-string or `powershell -Command`): broken quoting runs report lines as commands, and a file "
                    "path run as a command pops up a Windows 'choose an app' box on the owner's screen.\n")

HARD_RULES = Template("""

---
## Relay rules (enforced by the controller; these override anything above)
- Never run: git commit, git push, git reset, git checkout, git switch, git stash, git rebase, git merge, git branch.
- Never modify anything under $relay_dir except writing the report file below, and never run the relay's own
  Python unit tests ($relay_dir/tests); they test the relay, not the game, and only cost you time.
- Read $lessons first if it exists: lessons from earlier cycles on this codebase. Follow them.
- You may run any shell command you need to build and check your work: Godot, python, powershell, cmd,
  your own scripts, file listing, chained commands. Use them freely to run single tests, inspect scenes, or check
  behaviour instead of guessing. Only the git commands listed above are blocked.
- Put throwaway scratch, probe or debug scripts OUTSIDE the repository (for example in %TEMP%) and delete them
  when you are done; never leave them in the repository.
- The working tree may already contain partial work from an earlier attempt. Run `git status` and `git diff` first and continue from it rather than starting over.
- Do not delete, skip, or weaken existing tests to make them pass.
- Run the test suite before finishing: $test_cmd
- Run Godot only with --headless (tests, probes, imports). Never open a Godot window or the editor: the owner
  is using this PC.
- Audio is out of scope. Do not start any other task.
- When finished, write $report_path containing: files changed, what each change does, how you tested, the final test result, known issues. Then stop.
- Write that report with your file write tool, never through a shell command (no echo, heredoc, here-string or powershell -Command): broken quoting runs report lines as commands, and a file path run as a command pops up a Windows 'choose an app' box on the owner's screen.
""")

FIX = Template("""\
# FIX BRIEF: cycle $cycle, attempt $attempt of $max_attempts

The previous implementation was rejected. Fix ONLY the defects below. Do not add features.

## Defects
$defects

## Reviewer notes
$notes

## Original brief (reference)
$original
""")

REVIEW = Template("""\
You are reviewing an automated implementation in a Godot project. Be strict and specific.

Check whether the diff meets every acceptance criterion in the brief. Look for regressions, scope creep, weakened or deleted tests, dead code, obvious runtime errors, and claims in the agent report that the diff does not support.

Automated tests (run by the controller, not the agent): $tests

Reply in plain text. Do NOT put the markers or the JSON inside code fences:
@@REVIEW_START@@
<findings>
@@REVIEW_END@@
@@VERDICT_START@@
{"verdict": "ACCEPTED or FIX_REQUIRED", "defects": ["specific, actionable defect with file path"], "summary": "one sentence"}
@@VERDICT_END@@

=== PLAN ===
$plan

=== BRIEF ===
$brief

=== AGENT REPORT ===
$report

=== TEST OUTPUT (tail) ===
$test_tail

=== DIFF STAT vs $main ===
$stat

=== DIFF vs $main $truncated===
$diff
""")

FINAL = Template("""\
You are the INDEPENDENT FINAL REVIEWER in an automated build relay for a Godot game. You decide whether this cycle's work is accepted. Do NOT modify any files.

Read:
- Plan: $plan_path
- Implementation brief: $brief_path
- Agent report: $report_path
- Second-opinion review (may say unavailable): $review_path
- Test output (controller-run, result: $tests): $test_path

Then inspect the actual changes yourself: `git diff --cached $main --stat`, `git diff --cached $main`, and open any changed or affected files.
Keep findings concise (normally under 350 words, excluding actionable diagnosis). Inspect every
criterion and affected behavior; avoid an unrelated whole-project audit or retelling the plan.

Accept only if every acceptance criterion is met, tests pass, there are no regressions or weakened tests, scope is respected, and there are no obvious runtime errors. Treat the second-opinion review as input, not authority: verify its claims.

Defects must be specific and actionable (file path + wrong behaviour + expected behaviour). Style nitpicks are not defects.
Godot-generated sidecars (`*.import` for new images/assets, `*.gd.uid` for new scripts) are required companions of the files they belong to: they are always in scope, must be committed, and are never a defect.

Output exactly:
@@REVIEW_START@@
<your findings>
@@REVIEW_END@@
@@VERDICT_START@@
{"verdict": "ACCEPTED" or "FIX_REQUIRED", "defects": [...], "summary": "..."}
@@VERDICT_END@@
Only for FIX_REQUIRED, also add a diagnosis for the coding agent's fix attempt (under 60 lines; no code patches longer
than a few lines; never advise weakening or deleting tests):
@@DIAGNOSIS_START@@
## Root cause (one per defect; name the file and function)
## Exact fix (concrete steps; the smallest change that satisfies the brief)
## Verification (specific test/precondition/assertion that proves each correction)
## Do not touch (code or tests that must stay as they are)
@@DIAGNOSIS_END@@
""")

PING = "Reply with exactly this and nothing else: @@PING_START@@ok@@PING_END@@"

FINAL_PARALLEL = """

## Tests run in parallel with this review
The controller is running the full test suite right now, so the test output file may be missing or incomplete. Do NOT
run the full suite and do not wait for it (single focused tests are fine). Judge everything else: the controller
rejects the work itself if the suite fails, so do not reject only because test results are not available yet.
Suite results reported earlier (the agent report, an older test output) are not evidence either way: master
can change during the cycle (lane merges that break the suite are taken off it). Never report a failing,
missing or not-yet-green full suite as a defect or as a reason to defer; the controller's own run decides.
A failing single focused test you ran yourself on this tree is still a defect.
"""

FINAL_PRE = Template("""

## Review started during the coder's own test run
The coder has not finished yet, so its changes are NOT staged and `git diff --cached` shows nothing. Wherever this
task says diff or staged diff, use the snapshot $patch instead: every change against $main (new files included),
taken when the coder started its full test run on this exact tree. Open changed files in the working tree as usual.
The coder's report may not exist yet; judge the code and tests against the brief directly. The controller uses this
review only if the tree is still exactly this snapshot when the coder finishes.
""")

FINAL_DELTA = Template("""

## Follow-up review: only a small change since the last review
A review of this same task already finished on an earlier snapshot of this tree; its full answer is $previous.
Since that snapshot the coder changed only what is in $delta (a --stat, then the diff). Start from that answer
instead of reviewing everything again: re-check every part of the work the change touches and every defect the
earlier answer listed, and keep its judgements on parts the change does not touch unless you see they were wrong.
Still write a complete answer in the required format, covering every acceptance criterion.
""")

FINAL_REPAIR = Template("""

## Focused independent repair review
A full review of this task already exists: $previous_review.
Original acceptance criteria: $original_brief. Rejected requirements: $rejection.
Prior reviewed diff (when present): $previous_diff.
For this repair, first verify every listed defect using real preconditions and the new code/tests.
Then compare the current staged diff with the previously reviewed implementation and inspect
regressions from the repair, especially shared lifecycle and negative/fail-closed behavior.
Carry forward verified unchanged criteria; do not repeat an unrelated whole-project audit.
Broaden to a full review if scope expanded, shared behavior changed substantially, the baseline
is unavailable, or previous claims cannot be verified. Full passing controller tests and all
original acceptance criteria remain mandatory. Use the same verdict and diagnosis format above.
""")


# ---- file mode: ChatGPT reads/writes files itself (Desktop Commander) ----

_FILE_RULES = """
Rules for this task:
- Use the Desktop Commander tools for every file read, file write and command, because they run on this
  Windows PC where the repository lives. Do not use SentinelX or any other remote-host connector.
  Repository root: $repo
- Write ONLY the output file named below. Do not modify, create, or delete any other file.
- Read-only git only (status, diff, log, show). Never commit, checkout, reset, stash, or switch branches.
- Write the output file in one write if you can; if you write it in parts, append them in order. Its LAST
  line must be exactly @@FILE_END@@ : the relay treats the file as unfinished until that line is there.
- When the output file is written, reply with exactly: @@DONE_START@@ok@@DONE_END@@
"""

FILE_END = "@@FILE_END@@"

BRIEF_FILE = Template("""\
Read the plan at: $plan_path

Turn it into an implementation brief for a coding agent (DeepSeek via OpenCode) working in this Godot project. The agent can read and edit files and run commands. It cannot commit.

First validate the plan: remove anything vague, oversized, or out of scope (audio is out of scope). Make every acceptance criterion objectively testable. Check referenced files exist and keep paths exact.

Write the brief as Markdown to: $out_path
Sections: Objective, Files to change, Step-by-step implementation, Tests to write or update, Acceptance criteria, Do NOT.
""" + _FILE_RULES)

REVIEW_FILE = Template("""\
Review an automated implementation in the Godot project. Be strict and specific.
Godot-generated sidecars (`*.import` for new images/assets, `*.gd.uid` for new scripts) are required companions of the files they belong to: they are always in scope, must be committed, and are never a defect.

Read:
- Plan: $plan_path
- Brief: $brief_path
- Agent report: $report_path
- Test output (controller-run, result: $tests): $test_path

Inspect the changes yourself: `git -C "$repo" diff --cached $main --stat`, `git -C "$repo" diff --cached $main`, and open changed or affected files.

Check whether every acceptance criterion is met. Look for regressions, scope creep, weakened or deleted tests, dead code, obvious runtime errors, and report claims the diff does not support.

Write to: $out_path
with exactly this structure:
@@REVIEW_START@@
<findings>
@@REVIEW_END@@
@@VERDICT_START@@
{"verdict": "ACCEPTED or FIX_REQUIRED", "defects": ["specific, actionable defect with file path"], "summary": "one sentence"}
@@VERDICT_END@@
""" + _FILE_RULES)


# ---- local Claude rescue builder and milestone audit ----

RESCUE = Template("""\
You are the RESCUE BUILDER in an automated build relay for @GAME@, @GAME_DESC@.
Repository root: $repo   (branch: $branch)
A cheaper coding agent failed this cycle ($reason). The working tree holds its partial work.

Read, in order:
- Implementation brief: $brief_path
- Why it was rejected: $defects_path
- Last test output: $test_path
Then run `git status` and `git diff` to see the partial work, and continue from it.

Finish the brief completely and fix every listed defect. Keep scope exactly to the brief.
$rules
""")

DELEGATE_FILE = Template("""\
Read the task file at: $task_path

It was written for an assistant with Read/Grep/Glob and read-only git tools. You have the same
abilities through Desktop Commander: read files, search, list directories, and run read-only git
commands (status, diff, log, show) on this Windows PC. Do the task exactly as it says, including
reading every file it asks you to read and checking the actual code rather than guessing.

Then write your COMPLETE final answer, in exactly the output format the task specifies (keep every
@@..._START@@ / @@..._END@@ marker and every required line such as TITLE: or MILESTONE:), to:
$out_path
""" + _FILE_RULES)


RESCUE_CHATGPT = Template("""\
You are the rescue builder for an automated Godot game-development relay. Read the task file at:
$task_path
and do it: fix the code in the working tree of $repo so the tests pass and the brief is met.

How to work (Desktop Commander tools on this Windows PC; do not use SentinelX or other remote hosts):
- Read and edit files inside $repo. Never edit anything under .review/ except the report below.
- Run the tests with: $test_cmd   (from the repository root; it prints PASS/FAIL per test file).
  Iterate until they pass. Do not delete or weaken tests to make them pass.
  If the connector refuses a command as not allowlisted (python, Godot), run it inside a PowerShell script
  (script_run) that first does Set-Location to the repository root. Run Godot only with --headless.
- Read-only git only (status, diff, log, show), as `git -c safe.directory=* ...`. Never commit, checkout, reset,
  stash, merge, or switch branches.
- Do not leave scratch or debug files in the repository.
When done, write a short report (what was wrong, what you changed, final test result) to:
$report_path
(with your file write tool, never through a shell command: a broken quote runs report lines as commands)
and reply with exactly: @@DONE_START@@ok@@DONE_END@@
""")


LANE_AREAS_RULE = ("\nLANE AREAS (owner 2026-10-25): give each lane a task ONLY inside its own AREA above, even when another area has more open work; never give two lanes the same feature, content type or file. Plain data files of another area are off limits; when a task needs a change in another area, leave that part out and say so in the task. If a lane's area has nothing useful left, answer TITLE: NONE for it.")

LANES_SECTION = DesignTemplate("""

PARALLEL LANES (answer in this same reply; it replaces separate planning messages)
These builders work at the same time as the main task, each in its own copy of the repository. They follow
AGENTS.md and CANNOT see the .review/ folder, so every lane task must be fully self-contained.
Plan ONE task for each of these lanes$note:
$lanes
Work running right now in other lanes (do NOT overlap it in files or feature): $busy
Parallel-lane work already merged:
$recent
Parallel-lane attempts that failed (do not repeat unchanged):
$failed
Each lane task is one bounded gameplay/system change that moves the game toward release and does NOT overlap with
your main plan or with any other lane task (different files and features): e.g. remaining content and rules from the
design docs, non-visual logic and tests for later milestones, or a later MILESTONES.md step that does not depend on
unfinished work. A task that adds a new visible thing also gives it its visuals (see ART below); no restyles unless
the owner focus below allows them. Size: finishable and testable in under an hour.
GAMEPLAY OVER SAFETY (owner 2026-10-09): prefer work a player would notice: unfinished rules and effects,
synergies and interactions, abilities, enemies/bosses/elites, economy and shop rules, and content and
progression from the docs. Defensive-only hardening (input validation, "reject invalid/malformed", atomicity,
finite/overflow guards, refactors with no new behaviour) is allowed for at most ONE lane per round and only when it
fixes a bug a player could actually hit; otherwise plan a gameplay task. Tests cover the new behaviour and stay short.
Copy every number, rule and name the builder needs from the docs into the task.
Size each task for its builder (see the lane list): DeepSeek lanes get SMALL, tightly scoped tasks (1-3 files, about
20-30 minutes); Codex lanes get the BIGGER multi-file features (a whole hero kit, a new
mechanic, or a content set with its rules; up to about 90 minutes). The size limit above applies to DeepSeek.
@OWNER_FOCUS@
$design_next
TEST SPEED (workflow, 2026-10-18): the full suite is the critical path of every cycle (owner target: a cycle under
30 minutes). Only when MILESTONES.md has a "TS" section with an open step and no lane holds a TS step, give exactly ONE
DeepSeek lane per round the next TS step: make the slowest remaining test file (largest seconds in @TEST_TIMES@) at
least 1.3x faster (aim for 2x; never DEFER only because 2x was missed) with the SAME assertions and the same real code
paths (boot the app once per file where the cases allow it, drop duplicate loops that re-check what an earlier case
proved). Never delete a check, weaken an assertion or stub the real app. Copy the file name and its current seconds
into the task and require the before/after seconds in the report. Use milestone ID TS. A TS step counts as allowed
work under GAMEPLAY OVER SAFETY, it requests no images, and it touches only that one test file.
If a task adds catalog content (parts, abilities, foes, encounters, events, items) that changes totals asserted by shared audit tests
(for example a content scan or validation test), name those tests and their exact new
totals in the task, and give at most one lane such a task per round.
After your other blocks, output for EACH lane (put the lane id in both markers, e.g. LANE_lane2).
Each LANE block is the coder's WHOLE brief: the coder never sees your plan or any text outside its block. Put every exact
text, ID, number and record IN the block; never write 'see PLAN', 'from the PLAN block', 'as above' or 'the exact ... above':
@@LANE_<lane id>_START@@
TITLE: <short imperative title, or NONE if nothing suitable>
## Goal
## Details (all rules/numbers/names needed, copied from the docs)
## Files likely touched
## Tests to add or update (deterministic, headless)
## Acceptance criteria (each objectively checkable by the tests)
@@LANE_<lane id>_END@@
""")


LANES_PLAN = Template("""\
You plan work for the PARALLEL coding lanes of an automated build relay on @GAME@,
@GAME_DESC@ (repository $repo). They work at the same time as the main relay cycle. Do NOT modify any files.
Read with your file tools: the main cycle's plan at $main_plan (no lane may touch the same files or feature), and the
design docs in $docs (@DOCS@).
No two lane tasks may edit the same shared file (content registries or catalogs, shared contract or scan tests): lanes
are merged one after another and such overlaps end in merge conflicts or stale tests. If two good tasks would
overlap, give one lane a different task or NONE.
""")


VISUAL_LANE = Template("""
VISUAL-FIX LANE: lane id $lane is the visual-fix lane. Its task is NOT gameplay: it fixes the top 1-3 open defects of
the newest visual playtest report, $report (read it, and the screenshots it cites when useful). This overrides the
"never visual polish" rule for $lane only. Pick defects that are still listed (not fixed), visible in the report's
screenshots, and fixable in presentation code (positions, anchors, draw order, sizes, labels, colours,
procedural shapes). Never PNG/art files, never HUD/screen restyles (those are the HUD section's patchwork UI theme steps), never gameplay
numbers. Copy each defect's exact screenshot coordinates and expected result into the task, name the scripts/scenes
that draw it, and require a deterministic test that checks the drawn result (final node positions/sizes/visibility in
the real view), not a helper value. Do not overlap the main plan's files.
""")


VISUAL_SHOTS = """

## Screenshot check (visual-fix lane)
Before changing code, open the playtest screenshots this task cites (PNG files under .review/relay_v2/playtests/) and
look at the defect yourself; the coordinates in the task are approximate. After your tests pass, the relay screenshots the exported Web build before and after your change, and Claude checks that
the fix is visible and nothing else got worse. In your report, add ONE line naming the 1-3 scenarios that show your
change best, exactly in this form:
SHOTS: <name> <name> <name>
and ONE line saying whether you could actually see the cited screenshots (the relay uses it to choose who fixes visuals):
IMAGES: viewed <how many>   or   IMAGES: could not open (<why, e.g. the tool returned no image>)
Names: @SCENARIOS@
"""


VISUAL_CHECK = Template("""\
You are checking ONE visual fix in @GAME@ (@GAME_DESC@) before it is
merged. Do not modify any files.

The coding agent's task: $brief (read it).
Its change (diff against its base commit): $diff
Screenshots of the same scenarios from the exported Web build at 1280x720, BEFORE (base $base) and AFTER (its branch
$head). Scenario names: @SCENARIOS@
$pairs

Open EVERY screenshot listed above with the Read tool and compare each BEFORE with its AFTER. Judge only what a player
sees:
1. Does the AFTER show the change the task asked for? If none of these scenarios can show it, say so: that alone is
   not a failure.
2. Did anything else visibly get worse (new overlap or clipping, something missing, broken layout, an error screen)?
Small pixel shifts from animation timing are not regressions.

Reply with exactly this block:
@@VERDICT_START@@
PASS or FAIL
(1-5 lines: what visibly changed; for FAIL, what is wrong, where (screenshot name and coordinates), and the fix)
@@VERDICT_END@@
""")


VISUAL_CHECK_ATTACH = Template("""\
You are checking ONE visual fix in @GAME@ (@GAME_DESC@) before it is
merged. The attached PNG screenshots come from the exported Web build at 1280x720: files named BEFORE_<scenario>_<shot>
are from the base commit, AFTER_<scenario>_<shot> from the coding agent's branch. Scenario names: @SCENARIOS@
$errors
## The coding agent's task
$brief

## Its change (diff, may be shortened)
$diff

Look at EVERY attached image and compare each BEFORE with its AFTER. Judge only what a player sees:
1. Does the AFTER show the change the task asked for? If none of these scenarios can show it, say so: that alone is
   not a failure.
2. Did anything else visibly get worse (new overlap or clipping, something missing, broken layout, an error screen)?
Small pixel shifts from animation timing are not regressions.

Reply with exactly this block:
@@VERDICT_START@@
PASS or FAIL
(1-5 lines: what visibly changed; for FAIL, what is wrong, where (image name and coordinates), and the fix)
@@VERDICT_END@@
""")


SMOKE_CHECK = Template("""\
Quick smoke check of @GAME@ (@GAME_DESC@) after cycle $cycle (commit $commit). An automated
harness exported the game for the Web, played through a few screens in headless Chrome at 1280x720 and attached the
screenshots: @SCENARIOS@
$errors
Look at every attached image. Under Blockers report ONLY things that are CLEARLY BROKEN: an error or crash screen, a
blank or black screen, a battle or play screen with nothing in play, a missing HUD, text so garbled or overlapped it
cannot be read, a screen that is obviously the wrong one.
Under Look and feel (owner 2026-10-22: "polish now") list the worst visible polish problems against the drawn
patchwork theme in .review/full_game/MILESTONES.md "VIS": default grey Godot widgets or background, overlapping or
clipped text, raw ids or debug-looking controls and hint lines, cramped or squeezed elements, empty unused space,
screens that do not match each other's style. Name the image and the area. Do NOT suggest balance, gameplay or
new-content changes.

Reply with exactly this block:
@@REPORT_START@@
# Smoke check after cycle $cycle ($commit)
## Blockers
(one line each: what is broken - which image - likely area; or "none")
## Look and feel
(at most 8 lines, worst first: what looks unpolished - which image - where - the fix; or "none")
@@REPORT_END@@
""")


WORKFLOW_REVIEW = Template("""\
You are the WORKFLOW ENGINEER for an automated multi-agent build relay that develops @GAME@
(@GAME_DESC@). Milestone $milestone just finished. Find ways to make the relay faster and better.
Material:
- $relay : the relay's source (controller.py = phase state machine with background threads, prompts.py,
  chatgpt_bridge.py, art_gen.py, art_runner.py, lane_local.py, run_tests.py, playtest.py, relay.json,
  run_relay.ps1) and LESSONS.md
- $metrics : per-cycle step timings, fix attempts, failures, lane results and log-event counts for $milestone
- $log : the most recent relay log
- $priorities : what the owner wants optimized and which constraints are fixed
This reviews the relay, not the game: do not change game files.

Write $out with:
## Where the time goes (numbers from the metrics: per step, per cycle, waiting, retries, failures)
## Problems and waste (each with evidence from the metrics or the log)
## Recommendations (ranked by expected minutes saved per cycle or quality gained; for each: the change, expected
   effect, risk, effort)
## Ideas to try later
$patch_rule
""")


LANE_REVIEW = Template("""\
Review finished work from the parallel coding lanes of an automated Godot 4.7.2 relay (@GAME@, repository
$repo). Each lane worked on its own git branch and its full test suite already passes. Decide for EACH lane whether its
branch may be merged into $main. Be strict about correctness and scope, not style. Godot-generated sidecars
(`*.import`, `*.gd.uid`) are required companions and never a defect.

$lanes

For each lane read its task, its diff (patch file) and, where needed, the changed files in its worktree. Check that
the task is really done, that no test was weakened, skipped or deleted, that nothing outside the task changed, and
that the lanes do not conflict with each other (the same files or data edited in incompatible ways, duplicated
features). Only list defects that must be fixed before merging. Updating shared audit-test totals (content counts,
catalog lists) exactly as the lane's task specifies is in scope: check the new values, never ask for them to be reverted.
For EACH lane output exactly (JSON inside the markers, lane id in both markers):
@@LANE_REVIEW_<lane id>_START@@
{"verdict": "ACCEPTED or FIX_REQUIRED", "defects": ["specific, actionable defect with file path"], "summary": "one sentence", "diagnosis": "for FIX_REQUIRED: file/function, root cause, exact bounded correction and concrete verification per defect; otherwise empty"}
@@LANE_REVIEW_<lane id>_END@@
Read the coder's acceptance evidence, but verify its claims against actual code and tests.
For a repaired lane, use the prior defects, repair brief and repair baseline commit supplied
above: check the listed defects and regressions from the repair. Inspect the changes since
that commit in the worktree. Broaden to a full review when scope/shared behavior expanded or
the earlier reviewed implementation cannot be verified. Never waive original acceptance or tests.
""")


CODEX_PLAN = DesignTemplate("""\
You plan work for a PARALLEL coding agent ($agent) that works at the same time as the main relay cycle on the
same Godot game (@GAME@, repository $repo). It works in its own copy of the repository with Godot 4.7.2
and follows AGENTS.md. It CANNOT see the .review/ folder, so your task text must be fully self-contained.
Other work running right now that you must NOT overlap (files or feature): $avoid

Read with your file tools: the main cycle's plan at $main_plan (Codex must not touch the same files or feature),
and the design docs in $docs (@DOCS@, ART_STYLE.md).
Parallel-lane work already merged:
$recent
Parallel-lane attempts that failed (do not repeat unchanged):
$failed

Choose ONE bounded gameplay/system task that moves
the game toward release and does NOT overlap with the main plan: e.g. remaining content and rules from the design
docs, non-visual logic and tests for later milestones, or a later MILESTONES.md step that does not depend on unfinished
work. A task that adds a new visible thing also gives it its visuals; no restyles unless the owner focus allows them. Size: one focused change Codex can finish and
test in under an hour (a Codex builder may take a bigger multi-file feature, up to about 90 minutes; a DeepSeek builder
gets a small 1-3 file task). Copy every number, rule and name the builder needs from the docs into the task.
@OWNER_FOCUS@
$design_next
GAMEPLAY OVER SAFETY (owner 2026-10-09): prefer work a player would notice: unfinished rules and effects,
synergies and interactions, abilities, enemies/bosses/elites, economy and shop rules, and content and
progression from the docs. Defensive-only hardening (input validation, "reject invalid/malformed", atomicity,
finite/overflow guards, refactors with no new behaviour) is allowed for rare and only when it
fixes a bug a player could actually hit; otherwise plan a gameplay task. Tests cover the new behaviour and stay short.

Output exactly:
TITLE: <short imperative title, or NONE if nothing suitable>
@@CODEX_TASK_START@@
## Goal
## Details (all rules/numbers/names needed, copied from the docs)
## Files likely touched
## Tests to add or update (deterministic, headless)
## Acceptance criteria (each objectively checkable by the tests)
@@CODEX_TASK_END@@
""")


ATTACH_RULES = Template("""\
How to work (attached-file mode; there is NO desktop/file connector, do not try to use one):
- The attached context zip is a snapshot of the project. Every path in this task under $repo, or
  under .review/, is the SAME relative path inside the zip (for example $repo/scripts/main.gd -> scripts/main.gd,
  any Windows path ending in .review/relay_v2/cycles/033/PLAN_TASK.md -> .review/relay_v2/cycles/033/PLAN_TASK.md). Open it with your
  file-analysis tools and read everything the task asks you to read. Check the actual code; do not guess.
- Files outside $repo that the task names (lane worktrees, for example) are under _ext/ with the drive letter as
  the first folder (C:\\@SLUG@-lane2\\scripts\\a.gd -> _ext/C/@SLUG@-lane2/scripts/a.gd); _refs/INDEX.txt lists
  every such file. For a lane worktree only the files that lane changed are included; read its diff patch too.
- Git information is in the zip under _git/: branch.txt, log.txt (last 40 commits), status.txt,
  diff_vs_main.patch (working tree vs main) and diff_staged_vs_main.patch. Use these instead of running git.
- Instead of writing the output file $out_path, put its COMPLETE content in your reply between the lines
  @@OUTPUT_START@@ and @@OUTPUT_END@@, keeping every marker and line format the task requires inside that block.
""")


PLAYTEST = Template("""\
You are the GAMEPLAY QA reviewer for @GAME@, @GAME_DESC@. You run about every 4 hours. The owner's priority now is
FINISHING THE GAMEPLAY the design docs describe AND (owner 2026-10-22, "polish now") the MILESTONES.md VIS look and
feel: the game must stop looking like default grey Godot widgets. Do not modify any files.

1. Playability (screenshots). An automated harness exported commit $commit (accepted cycle $cycle: "$title") for the
Web, ran it in headless Chrome at 1280x720 and captured screenshots. Scenario names: @SCENARIOS@
Harness facts (scenarios, screenshot paths, console errors):
$facts
Open the screenshots with the Read tool. Look for what stops or confuses PLAY: error screens or console errors,
screens that do not load, wrong or missing HUD values, controls that look unusable, text that cannot be read. Also
judge the look against ART_STYLE.md and the VIS steps: default-looking widgets, cramped or overlapping layout, clipped
text, flat screens with no patchwork theme. The console errors in the facts are authoritative.

2. Gameplay completeness (code). Read the design docs in $docs (@DOCS@) and the game's code and tests (scripts/,
data/, tests/, `git log --oneline -40`). Current milestone: $milestone. Find what is missing, unfinished or broken in
the gameplay systems compared with the docs. Prefer concrete gaps you verified in the code (file and function) over
guesses.

The previous report (compare against it; may be "none"): $prev_report
Do not call something fixed unless the evidence clearly changed.

Reply with exactly this block (under 80 lines):
@@REPORT_START@@
# Gameplay check after cycle $cycle ($commit)
## Blockers
(things that make the game unplayable or crash; each with screenshot or file, and the concrete fix; or "none")
## Gameplay problems
(one line each, most important first: G<n>. what is missing/broken - where (file/function or screenshot) - fix;
or "none")
## Fixed since previous report
(or "n/a")
## Look and feel
(one line each, worst first: V<n>. what looks clunky - screenshot - the concrete fix; or "none")
## Suggested next gameplay task
(one bounded task a coding agent can finish in one cycle, from the current milestone unless a blocker comes first)
@@REPORT_END@@
""")



AUDIT = Template("""\
You are the MILESTONE AUDITOR in an automated build relay for @GAME@, @GAME_DESC@.
Repository root: $repo. Do NOT modify any files.
Milestone $milestone appears complete: the planner has just moved on to $next_milestone.

Read the gate for $milestone in $docs/MILESTONES.md and the relevant rules in the other design docs in $docs (@DOCS@).
The accepted cycles for this milestone were:
$cycles
Their plans are in $cycles_dir/<NNN>/CLAUDE_PLAN.md.

Inspect the actual code, data and tests (git log, git show, and file reads). Judge the milestone against its gate.

Output exactly this, with nothing before the first marker:
@@AUDIT_START@@
## Gate items
(each: MET / NOT MET / NOT VERIFIABLE, with file paths)
## Release blockers
## Regressions or weakened tests
## Contracts skipped or only partly done
## Next tasks
(up to 5, highest priority first, each small enough for one ~60 minute coding cycle)
@@AUDIT_END@@
""")


# ---- cloud sessions (claude --cloud); local RESCUE/AUDIT above are the fallback ----

CLOUD_GODOT = Template("""\
Godot is not preinstalled. Install the headless Linux build once:
  curl -fsSL -o /tmp/godot.zip $godot_url && unzip -o -q /tmp/godot.zip -d /tmp/godot && chmod +x /tmp/godot/*
Then import once and run each suite the same way the local runner does:
  G=$$(ls /tmp/godot/Godot_*linux*)
  "$$G" --headless --path . --import
  for t in tests/*_test.gd; do "$$G" --headless --path . -s "res://$$t"; done
A suite fails on a nonzero exit code or any of: SCRIPT ERROR, Parse Error, Failed to load script.
If Godot cannot be downloaded, still finish the work and say so in the result file.""")

CLOUD_RESCUE = Template("""\
You are the RESCUE BUILDER for an automated build relay on @GAME@, @GAME_DESC@.
A cheaper coding agent failed this cycle ($reason). This branch holds its partial work in the commit before
the `.cloud/` commit, plus your context in `.cloud/`.

Read, in order: .cloud/TASK_BRIEF.md (the implementation brief), .cloud/LAST_DEFECTS.md (why it was rejected),
.cloud/LAST_TEST_OUTPUT.txt. Inspect the partial work with `git log -3 --stat` and `git show HEAD~1`.

Finish the brief completely and fix every listed defect. Keep scope exactly to the brief; audio is out of scope.
Do not delete, skip or weaken existing tests. Do not change anything under `.cloud/` except creating the result file.

$godot

When done:
1. Write .cloud/RESULT.md: files changed, what each change does, how you tested, final test result
   (pass/fail counts), known issues.
2. Commit everything, including .cloud/RESULT.md, and push it to a new branch named exactly `$result_branch`.
   Do not open a pull request. Do not push to any other branch.
""")

CLOUD_AUDIT = Template("""\
You are the MILESTONE AUDITOR for an automated build relay on @GAME@, @GAME_DESC@.
Milestone $milestone appears complete: the planner has moved on to $next_milestone.
Design docs are in `.cloud/` (@DOCS@, where present)
along with ACCEPTED_CYCLES.md (the plans of the cycles accepted for this milestone).
This is a READ-ONLY review: do not change game files.

Audit $milestone against its gate in .cloud/MILESTONES.md and the relevant design-doc rules.
Inspect the actual code, data and tests.

$godot

Write .cloud/AUDIT.md with these sections:
## Gate items (each MET / NOT MET / NOT VERIFIABLE, with file paths)
## Release blockers
## Regressions or weakened tests
## Contracts skipped or only partly done
## Next tasks (up to 5, highest priority first, each small enough for one ~60 minute coding cycle)

Commit only that file and push it to a new branch named exactly `$result_branch`.
Do not open a pull request. Do not push to any other branch.
""")


# ---- fix triage (ChatGPT chat mode, file tools): diagnose before DeepSeek's fix attempt ----

TRIAGE_FILE = Template("""\
A coding agent's implementation in this Godot project was rejected. Diagnose why, so its next fix attempt is precise.

Read:
- Implementation brief: $brief_path
- Rejection (failing tests and/or reviewer defects): $defects_path
- Its own report: $report_path
Inspect the current changes: `git -C "$repo" status` and `git -C "$repo" diff HEAD`, and open the files involved.

Write to: $out_path
A short Markdown diagnosis (under 60 lines):
## Root cause (one per defect or failing test; name the file and function)
## Exact fix (concrete steps; the smallest change that satisfies the brief)
## Do not touch (code or tests that must stay as they are)
Do not write code patches longer than a few lines. Do not weaken or delete tests in your advice.
""" + _FILE_RULES)


# ---- lessons loop (ChatGPT chat mode): general lessons from cycles that needed fixes ----

LESSONS_FILE = Template("""\
An automated coding agent (DeepSeek) needed fixes before its work on this Godot project was accepted.
Extract general lessons so future cycles avoid the same mistakes.

Read the cycle folder $cycle_dir: the brief (DEEPSEEK_BRIEF.md), each REJECTION_n.md and TRIAGE_n.md, and the
verdict_n.json files. Also read the existing lessons file $lessons_path if it exists, so you do not repeat it.

Write to: $out_path
0 to 2 Markdown bullet points, nothing else, each at most 2 sentences. Each bullet is one general, reusable rule
about this codebase or its test harness that most future tasks would need (for example how a system must be wired,
a recurring API pitfall, or a test convention). No rules about one ability, status, Boss, seed, screen or fixture, no
file-by-file fix notes, no duplicates of existing lessons (including its "Always" section).
Most tasks teach nothing general; if in doubt, write exactly: (none)
""" + _FILE_RULES)

# Owner 2026-10-10: lanes (DeepSeek, Codex, ChatGPT coders) learn from their review rejections too.
LANE_LESSONS_FILE = Template("""\
A parallel coding lane ($builder) on this Godot project $outcome: "$title".
Extract general lessons so all coding agents (DeepSeek, Codex, ChatGPT) avoid the same mistakes.

Read the lane run folders: $run_dirs
Each has BRIEF.md (the first is the task; the -fixN ones list the review defects to fix) and REPORT.md (the coder's
report). Also read the existing lessons file $lessons_path if it exists, so you do not repeat it.

Write to: $out_path
0 to 2 Markdown bullet points, nothing else, each at most 2 sentences. Each bullet is one general, reusable rule
about this codebase or its test harness that most future tasks would need (for example how a system must be wired,
a recurring API pitfall, or a test convention). No rules about one ability, status, Boss, seed, screen or fixture, no
file-by-file fix notes, no duplicates of existing lessons (including its "Always" section).
Most tasks teach nothing general; if in doubt, write exactly: (none)
""" + _FILE_RULES)


# Owner 2026-10-19: "transfer the design review to chatgpt chat mode instead of you doing it to save claude usage".
# Every design_review.every cycles (default 12) ChatGPT reads the plan docs and recent work and writes an ordered
# balance review plus at most one patchwork feature; the controller inserts them into MILESTONES.md and DESIGN_NEXT.md.
DESIGN_REVIEW_FILE = Template("""\
You are the GAME DESIGNER doing the periodic design review (every ~24 relay cycles) for @GAME@,
@GAME_DESC@.
Automated coders build one main step per ~20-minute cycle plus side lanes; planners pick steps from MILESTONES.md.

Plan only STITCHED_DESIGN.md (Design v4). The card game (cards, deck, hand, energy, card BAL steps, MPW P1-P13) is
retired: never schedule, port or polish it.

Read (all on this PC):
- the design docs in $docs (@DOCS@): STITCHED_DESIGN.md first (section 12's build stages S1a-S9 and their done
  tests), then ART_STYLE.md and CHARACTER_DESIGNS.md; MILESTONES.md only for the earlier "Review ..." blocks in BAL
  and the MPW list
- the current planner order: $design_next_path
- the OWNER ORDER, the owner's standing priorities: $owner_order_path. Read-only for you: planners always see it
  before your steps, so never copy or reword it into @@NEXT@@. Order your NEXT MAIN-CYCLE STEPS so they build its
  first open items first (split a big owner item into cycle-sized steps), then the rest of your review.
- the newest playtest reports: $playtests
- what was built recently. Accepted main cycles (newest last):
$history
  Side-lane merges (newest last):
$lanes
  You may also run read-only git in $repo (git log --oneline -60, git show --stat <commit>) and read data/ and tests/.

Do three things.
1. STAGES. Check every STITCHED_DESIGN.md build stage (S1a-S9; S8 The Walk, section 9b, and S9 The Kid, section 9c, come after S7) and every open OWNER ORDER item against the code,
   data, tests and git log: done, partly built (which parts are missing) or not started; and find where planners split
   a batched step into one item per cycle (the most common waste). Write the NEXT MAIN-CYCLE STEPS: at most 5, in
   order: the open OWNER ORDER items first, then the first unfinished stages in stage order; each one step sized for
   one ~20-minute cycle, naming the data files, scripts and tests it touches, and batching small items (never "one foe
   / one stop / one part per cycle"). Base it on evidence (data, tests, playtests, git log), not guesses. Check that
   every step fits STITCHED_DESIGN.md. Do not repeat finished work. A card-era step is never a NEXT step.
   STALLED STEP (owner 2026-11-02): if your step 1 is the same work as step 1 of the newest earlier "Review ..."
   block in BAL, it has stalled: planners kept building slices of it. Start that step with exactly "FINISH NOW:",
   size it for ONE whole main build however many files it needs (the 20-minute size does not apply to it), state
   its done test (the exact test names or live-play observation that prove it is finished), and name the slices
   planners must not plan again. Never mark more than step 1.
2. FEATURES (fun and replayability; owner 2026-10-24, 2026-11-02 "the game keeps growing", 2026-11-05 Stitched
   only). MPW P1-P13 are retired card-game features: ignore them. TRIMMED (owner 2026-11-05): while any
   STITCHED_DESIGN.md stage S1a-S9 is not done in live play, add no feature: write exactly (none) under @@MPW@@,
   make no MPW step a NEXT MAIN-CYCLE STEP (P14 and up wait until S9 is done) and go on to 3. Once S9 is done:
   first check every MPW step numbered P14 or higher
   against the code, data, tests and git log. If two or more are not built in live
   play yet, write exactly (none) under @@MPW@@ and make building them one of the NEXT MAIN-CYCLE STEPS. If exactly
   one is unbuilt, make building it a NEXT step and still list ONE new MPW step. Otherwise list 2 to 4 new MPW steps
   that make the Stitched game more fun and more replayable: what makes a player start another run (which four of
   eight heroes, body-part builds and foreign parts torn from foes, fray quirks and resolve moments, candle
   risk/reward routes, stop and event choices, rare finds, a difficulty climb). @FEATURE_INSPIRATION@Each built on
   the Stitched rules (ranks, part abilities, fray, candle, the thread; no cards, deck, hand or energy), in
   the game's style (@FEATURE_STYLE@), its visuals AI-generated images (requested by planners in an assets block,
   animated in Godot; never drawn in code), numbers in data, its tests listed, power in line with existing content,
   sized for one to three cycles, scheduled after the stage it needs. Number them on from the highest existing MPW
   P-number in MILESTONES.md (P14 at the lowest), most fun per cycle of work first.
3. VISUALS (owner 2026-10-24). Look at every attached screenshot ($shots): the relay's newest capture of each
   screen. List what needs improving, worst first, naming screen, element and fix: characters standing too high or
   floating above the floor, sprites off the ground line or wrongly sized, overlapping or clipped text and tags, raw
   ids or developer text, cramped or empty layouts, tiny art windows, plain controls, flat or missing atmosphere,
   screens whose style does not match the rest. Judge the Stitched screens (the Stitched battle, map and stops); a
   screen that still shows cards, a deck or a hand is replaced by S6/S7: say so in one line, never polish it.
   Put the fixes into the NEXT MAIN-CYCLE STEPS as batched VIS steps
   (one or two, many fixes each; the relay's own screenshots verify them, never a coder screenshot criterion).
   Atmosphere, effects, backgrounds and UI dressing are AI-generated art (ChatGPT/Flow, requested in an assets block)
   animated in Godot, not drawn in code: say which images to request. If no screenshot is attached, judge from the
   newest playtest report's Look and feel section.

Hard rules: never change the game's locked rules (@LOCKED_RULES@), the gates, or the game's name.
@DESIGN_RULES@Write for automated planners: concrete, ordered, short.

Write to: $out_path, in exactly this format (the three marker lines must appear, each alone on its line):
@@BAL_REVIEW@@
Review $date (cycle $cycle), NEXT MAIN-CYCLE STEPS in this order. <one or two sentences: what is done since the last
    review and what pattern to stop>
    1. <step>
    2. <step>
@@MPW@@
P<n>. <Name> (ChatGPT periodic design review $date cycle $cycle; <why it is allowed now>): <rules, mood dressing,
    tests>
P<n+1>. <Name> (...): <...>
(or exactly: (none))
@@NEXT@@
BAL NEXT MAIN STEPS (design review cycle $cycle, MILESTONES.md BAL "Review $date (cycle $cycle)"), in order: (1) ...,
(2) ..., <one paragraph, at most 120 words, that planners read every cycle>
Indent continuation lines in the first two sections with four spaces, as above. Plain text, no Markdown headings.
""" + _FILE_RULES)


# ---- focused re-review after a fix round (ChatGPT chat mode) ----

REVIEW_FIX_FILE = Template("""\
Re-review a FIX to an implementation in the Godot project. A full review of the earlier attempt already exists;
Godot-generated sidecars (`*.import` for new images/assets, `*.gd.uid` for new scripts) are required companions of the files they belong to: they are always in scope, must be committed, and are never a defect.
do not redo it. Check only the fix.

Read:
- Defects the fix had to address: $defects_path
- Earlier full review: $prev_review_path
- Fix brief: $brief_path
- Agent report for the fix: $report_path
- Test output (controller-run, result: $tests): $test_path
Inspect the changes: `git -C "$repo" diff --cached $main --stat`, `git -C "$repo" diff --cached $main`,
and open the files the defects name.

For EACH listed defect, state FIXED or NOT FIXED with evidence (file path, function, what changed).
Then check that the fix did not weaken or delete tests, add scope, or break something the earlier review accepted.
Do not raise new style nitpicks. Only raise a new defect if the fix introduced it or it blocks an acceptance criterion.

Write to: $out_path
with exactly this structure:
@@REVIEW_START@@
<findings>
@@REVIEW_END@@
@@VERDICT_START@@
{"verdict": "ACCEPTED or FIX_REQUIRED", "defects": ["specific, actionable defect with file path"], "summary": "one sentence"}
@@VERDICT_END@@
""" + _FILE_RULES)

# ---- file tool switch: the same file-mode prompts, pointed at the SentinelX connector ----

_SENTINEL_SWAPS = (
    ("- Use the Desktop Commander tools for every file read, file write and command, because they run on this\n"
     "  Windows PC where the repository lives. Do not use SentinelX or any other remote-host connector.",
     "- Use the SentinelX connector on host $host for every file read, file write and command; that host is this\n"
     "  Windows PC where the repository lives. Do not use Desktop Commander (its quota is used up)."),
    ("(Desktop Commander tools on this Windows PC; do not use SentinelX or other remote hosts)",
     "(SentinelX connector on host $host, which is this Windows PC; do not use Desktop Commander)"),
    ("through Desktop Commander", "through the SentinelX connector (host $host)"),
    ("Use the Desktop Commander tools", "Use the SentinelX connector (host $host)"),
)


def refs_note(images) -> str:
    """Owner 2026-11-04: planners see reference shots of the screens they plan."""
    names = ", ".join(Path(str(i)).name for i in images)
    kinds = {Path(str(i)).name.split("_", 1)[0] for i in images}
    return ("\n\nREFERENCE IMAGES attached to this message (" + names + ")."
            + (" now_*.jpg are screenshots of OUR game as it is today (.review/full_game/refs/now/INDEX.md): the "
               "truth about what each screen looks like now. Plan changes against them, not against older "
               "descriptions." if "now" in kinds else "")
            + (" dd_*.jpg are screenshots of a dark gothic ranked "
               "turn-based roguelike, described in .review/full_game/refs/dd/INDEX.md. Use them for screen layout, "
               "framing, readability and mood when you plan UI, combat flow or stops; copy no art, icons, text or "
               "names, and keep our own twists (body-part abilities, the thread, fray, the candle). Never name that "
               "game in game text or art prompts." if "dd" in kinds else "")
            + (" mock_*.jpg is different: OUR rough mockup of this screen in our own art style, a mood and layout "
               "sketch only; the design doc wins where they differ." if any(Path(str(i)).name.startswith("mock_")
                                                                          for i in images) else "")
            + (" mock_req_*.jpg are pictures a planner asked for with @@REF@@ lines, drawn the same way."
               if any(Path(str(i)).name.startswith("mock_req_") for i in images) else "")
            + "\n")


# Owner 2026-11-04 ("yes, make sure that art isnt done with code since it looks bad"): planners may ask for a picture.
REF_REQUEST_NOTE = """

NEED A PICTURE? If seeing a screen, layout or look would help you or the next planner, ask for a reference picture:
at the very end of the answer you write, after everything else, add at most 2 lines, each exactly
@@REF@@ <snake_case_key>: <one line saying what to draw: the screen or element, its layout, what is in it>
The relay draws it in our dark gothic ragdoll style (Google Flow image mode, free) and attaches it to the next
planning message as mock_req_<key>.jpg. It is a planning reference only and never ships; describe only what to show
and never name another game. The game's own images still come from the assets block: the game never draws visuals in
code.
"""


def code_art_defect(found) -> str:
    """Owner 2026-11-04: the fix request for a change that draws visuals in code."""
    return ("The change draws visuals in code, which the owner forbids (2026-11-04: \"make sure that art isnt done with "
            "code since it looks bad\"): " + "; ".join(found) + ". Remove these code-drawn shapes, flat panels, "
            "gradients and particles and show authored images instead: the art in assets/paper/ (ui/ frames, plates, "
            "bars and buttons; vfx/; backgrounds/) through TextureRect, NinePatchRect, StyleBoxTexture or "
            "TextureProgressBar, placed, tinted (modulate) and animated with tweens. If no image fits yet, use the "
            "closest existing one and keep the art path in data so a requested image can replace it; never draw a "
            "stand-in in code. Keep every test passing.")


def coder_refs_note(images) -> str:
    """Owner 2026-11-04: coders that can see images get the screen's reference images too."""
    if not images:
        return ""
    return ("\n\n## Reference images (owner 2026-11-04)\nThis task touches a screen. If you can view images, look at "
            "these before you lay it out (web chat coders: call the view_image tool with each file name):\n"
            + "".join(f"- {Path(str(i)).as_posix()}\n" for i in images)
            + "now_*.jpg are screenshots of OUR game as it is today: what the screen looks like before your "
            "change. mock_*.jpg is OUR rough mockup in our own art style (mood and layout only). dd_*.jpg are screenshots of "
            "another dark gothic ranked roguelike, for layout and readability only: copy no art, text, icons or "
            "names, never name that game, never copy these files into the repository. The brief and "
            "STITCHED_DESIGN.md win where they differ.\n")


# Owner 2026-11-05: "most of the information for the planners should live inside the sentinelx folders".
SENTINEL_ASK = """Use the SentinelX connector on host @HOST@ (this Windows PC) for every file read, file write and command.
Your whole task for this chat is in the file @PATH@ on that host. Read it in full with SentinelX now and do
exactly what it says: the files to read, the files to write, and what to put in your chat reply.@FILES@"""


def sentinel_ask(path, host: str, files=None) -> str:
    """The short chat message for an ask whose full prompt was written to `path`."""
    names = ", ".join(Path(str(f)).name for f in files or [])
    extra = f"\nThe attached images ({names}) belong to that task." if names else ""
    return SENTINEL_ASK.replace("@HOST@", host).replace("@PATH@", str(path)).replace("@FILES@", extra)


def use_sentinelx(text: str, host: str) -> str:
    """Rewrite a Desktop Commander file-mode prompt to use SentinelX on `host`."""
    for a, b in _SENTINEL_SWAPS:
        text = text.replace(a, b.replace("$host", host))
    return text.replace("Desktop Commander tools", "SentinelX connector tools")


# Keep the transport/output markers intact while making the policy apply to every
# planner, coder, retry and reviewer, including cloud builders.
for _name in ('PLAN', 'PLAN_FAST', 'BRIEF', 'BRIEF_FILE', 'LANES_SECTION', 'LANES_PLAN', 'CODEX_PLAN'):
    _template = globals()[_name]
    globals()[_name] = type(_template)(_template.template + '\n' + PLANNER_SCOPE_POLICY + '\n' + TASK_PREPARATION_POLICY)
for _name in ('HARD_RULES', 'FIX', 'RESCUE', 'RESCUE_CHATGPT', 'CLOUD_RESCUE'):
    _template = globals()[_name]
    globals()[_name] = Template(coder_scope(_template.template))
for _name in ('REVIEW', 'FINAL', 'REVIEW_FILE', 'REVIEW_FIX_FILE', 'LANE_REVIEW'):
    _text = globals()[_name].template
    _text = _text.replace('ACCEPTED or FIX_REQUIRED', 'ACCEPTED or FIX_REQUIRED or DEFERRED')
    _text = _text.replace('"ACCEPTED" or "FIX_REQUIRED"', '"ACCEPTED" or "FIX_REQUIRED" or "DEFERRED"')
    globals()[_name] = Template(_text + '\n' + REVIEW_SCOPE_POLICY + '\n' + ART_LATER_POLICY)

OWNER_FOCUS = G.FOCUS


def _fill(text: str, template: bool) -> str:
    for token, value in G.tokens().items():
        text = text.replace(token, value.replace("$", "$$") if template else value)
    return text


# Owner 2026-10-20: the relay is game-agnostic; fill every @TOKEN@ from relay.json "game" (game.py) once.
for _name, _value in list(globals().items()):
    if _name.startswith("_") and _name not in ("_FILE_RULES",):
        continue
    if isinstance(_value, Template):
        globals()[_name] = type(_value)(_fill(_value.template, True))
    elif isinstance(_value, str) and "@" in _value:
        globals()[_name] = _fill(_value, False)
