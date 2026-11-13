# Objective
Complete the ENTIRE S7/VIS-A release gate, using deferred cycle-656 commit `1c79aa77`, now that the owner's purge handoff is marked landed. Verify the exact present checkout first: two `StarterCards.new()` paths remain callable and the dark replacement artwork is not yet installed. Never mark the gate done while either blocker survives.

# Files to change
`scripts/app.gd`, `scripts/patchwork_ui_shell.gd`; `tests/stitched_s7_no_cards_test.gd`, `tests/stitched_s7_title_continue_test.gd`, `tests/stitched_gothic_title_menu_test.gd`, `tests/patchwork_ui_shell_test.gd`. External art pipeline supplies the three new title PNGs and sidecars before VIS-A can pass. `scenes/app.tscn` and `themes/gothic_theme.tres` are read contracts already wired, not invitations to change the root Theme.

# Implementation and tests
Reconcile/cherry-pick the saved 656 work without overwriting newer merged title/route code. Disconnect and eliminate obsolete bedroom card Path callbacks in `app.gd`; audit compiled methods, connections and source for all remaining reachable card entry points. Keep three accessible title actions and guarded Continue. Wire authored dark logo/primary/secondary planks as texture-backed nine-slices; preserve the 1280x720 centered composition and keyboard ring, darkening neither the background nor focus affordance into illegibility. Do not generate or alter art; request owner-supplied files and defer if unavailable. Change existing title/shell test expectations only for intentional new asset paths and remove no negative, disabled, replay or stale-callback checks. Run the six named S7/S6/web tests in the plan plus the full controller suite; inspect the relay-produced title capture and require independent review. Smallest necessary supporting code/test corrections within these scoped files are authorized, but no unrelated edits.

# Acceptance criteria
AC1: Live and source S7 audit proves no callable card/StarterCards/deck entry points across the listed real routes.
AC2: Supplied dark logo and distinct sewn primary/secondary planks are actually mounted; title interaction tests and the relay 1280x720 capture prove readable dark hierarchy and input/focus behavior.
AC3: Named S6/S7/public boot tests, full controller suite and independent review pass with exact Continue/restart state and no regressed rejection behavior.

# Do NOT
Do not rebuild deferred title work from scratch, remove owner-owned card files, create/edit images, touch another lane's files, add controls or service forecasts, change corridor presentation, weaken tests, or claim success with missing required art. If prerequisites remain absent, save/defer the whole task without a partial merge.

---
## Relay rules (enforced by the controller; these override anything above)
- Never run: git commit, git push, git reset, git checkout, git switch, git stash, git rebase, git merge, git branch.
- Never modify anything under .review/relay_v2 except writing the report file below, and never run the relay's own
  Python unit tests (.review/relay_v2/tests); they test the relay, not the game, and only cost you time.
- Read .review/relay_v2/LESSONS.md first if it exists: lessons from earlier cycles on this codebase. Follow them.
- You may run any shell command you need to build and check your work: Godot, python, powershell, cmd,
  your own scripts, file listing, chained commands. Use them freely to run single tests, inspect scenes, or check
  behaviour instead of guessing. Only the git commands listed above are blocked.
- Put throwaway scratch, probe or debug scripts OUTSIDE the repository (for example in %TEMP%) and delete them
  when you are done; never leave them in the repository.
- The working tree may already contain partial work from an earlier attempt. Run `git status` and `git diff` first and continue from it rather than starting over.
- Do not delete, skip, or weaken existing tests to make them pass.
- Run the test suite before finishing: python .review/relay_v2/run_tests.py
- Run Godot only with --headless (tests, probes, imports). Never open a Godot window or the editor: the owner
  is using this PC.
- Audio is out of scope. Do not start any other task.
- When finished, write .review/relay_v2/cycles/667/DEEPSEEK_REPORT_0.md containing: files changed, what each change does, how you tested, the final test result, known issues. Then stop.
- Write that report with your file write tool, never through a shell command (no echo, heredoc, here-string or powershell -Command): broken quoting runs report lines as commands, and a file path run as a command pops up a Windows 'choose an app' box on the owner's screen.


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


## Live work board (other coders working right now)
Other coders work on this game at the same time, each in its own copy. C:/Users/jcoev/GodotGames/PatchworkPioneers/.review/relay_v2/LIVE_WORK.md shows, refreshed about every
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


## Reference images (owner 2026-11-04)
This task touches a screen. If you can view images, look at these before you lay it out (web chat coders: call the view_image tool with each file name):
- C:/Users/jcoev/GodotGames/PatchworkPioneers/.review/full_game/refs/mock/mock_gothic_ui.jpg
- C:/Users/jcoev/GodotGames/PatchworkPioneers/.review/full_game/refs/dd/dd_event_panel.jpg
- C:/Users/jcoev/GodotGames/PatchworkPioneers/.review/full_game/refs/dd/dd_shop.jpg
mock_*.jpg is OUR rough mockup in our own art style (mood and layout only). dd_*.jpg are screenshots of another dark gothic ranked roguelike, for layout and readability only: copy no art, text, icons or names, never name that game, never copy these files into the repository. The brief and STITCHED_DESIGN.md win where they differ.
