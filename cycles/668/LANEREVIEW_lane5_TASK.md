Review finished work from the parallel coding lanes of an automated Godot 4.7.2 relay (Patchwork Pioneers, repository
C:\Users\jcoev\GodotGames\PatchworkPioneers). Each lane worked on its own git branch and its full test suite already passes. Decide for EACH lane whether its
branch may be merged into master. Be strict about correctness and scope, not style. Godot-generated sidecars
(`*.import`, `*.gd.uid`) are required companions and never a defect.

### Lane id lane5 (Claude/Mistral web lane 5): Price the Wool Patch Cloak as the mid-tier Patch Stall button
- task: C:\Users\jcoev\GodotGames\PatchworkPioneers\.review\relay_v2\lanes\668-lane5-1794206681\BRIEF.md
- branch: lane/deepseek-668-lane5-1794206681 (worktree C:\pioneers-lane5)
- diff vs master: C:\Users\jcoev\GodotGames\PatchworkPioneers\.review\relay_v2\lanes\668-lane5-1794206681\DIFF_vs_main.patch
- test output: C:\Users\jcoev\GodotGames\PatchworkPioneers\.review\relay_v2\lanes\668-lane5-1794206681\TESTS_1794207007.txt
- coder report: C:\Users\jcoev\GodotGames\PatchworkPioneers\.review\relay_v2\lanes\668-lane5-1794206681\REPORT.md
- prior defects: []
- repair baseline commit: first review
- repair brief: C:\Users\jcoev\GodotGames\PatchworkPioneers\.review\relay_v2\lanes\668-lane5-1794206681\BRIEF.md

For each lane read its task, its diff (patch file) and, where needed, the changed files in its worktree. Check that
the task is really done, that no test was weakened, skipped or deleted, that nothing outside the task changed, and
that the lanes do not conflict with each other (the same files or data edited in incompatible ways, duplicated
features). Only list defects that must be fixed before merging. Updating shared audit-test totals (content counts,
catalog lists) exactly as the lane's task specifies is in scope: check the new values, never ask for them to be reverted.
For EACH lane output exactly (JSON inside the markers, lane id in both markers):
@@LANE_REVIEW_<lane id>_START@@
{"verdict": "ACCEPTED or FIX_REQUIRED or DEFERRED", "defects": ["specific, actionable defect with file path"], "summary": "one sentence", "diagnosis": "for FIX_REQUIRED: file/function, root cause, exact bounded correction and concrete verification per defect; otherwise empty"}
@@LANE_REVIEW_<lane id>_END@@
Read the coder's acceptance evidence, but verify its claims against actual code and tests.
For a repaired lane, use the prior defects, repair brief and repair baseline commit supplied
above: check the listed defects and regressions from the repair. Inspect the changes since
that commit in the worktree. Broaden to a full review when scope/shared behavior expanded or
the earlier reviewed implementation cannot be verified. Never waive original acceptance or tests.


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
