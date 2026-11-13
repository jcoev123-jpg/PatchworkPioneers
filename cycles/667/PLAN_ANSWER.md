TITLE: Finish S7 card-free admission and the dark gothic title as one gate
MILESTONE: S7 / VIS-A
@@PLAN_START@@
## Goal and current behavior
Finish the stalled whole S7/VIS-A gate, not another title or legacy-symbol slice. The owner's s7-card-purge commit 8a5046b1 is marked landed, but `scripts/app.gd:4033,4056` still calls `StarterCards.new()` from two connected bedroom Path callbacks. `scenes/app.tscn` already mounts the Gothic Theme. The latest relay `title_boot.png` retains a cheerful multicolour wordmark and reused reward planks. Deferred 656 commit `1c79aa77` contains accepted partial title wiring; reuse it, do not rebuild it. The required dark wordmark and two dark plank PNGs are not yet present: owner/art-pipeline supply is an explicit launch/acceptance dependency, never a coder-generated substitute.

## Changes and tests
Cherry-pick/reconcile saved `1c79aa77` on the coding worktree once its context is checked, retaining current S7 route/Continue improvements. Remove both callable legacy Path methods and their `app.gd` signal hookups, plus any remaining reachable retired-card entry points identified by the source/compiled-tree audit; do not perform the owner's separate broad card-file purge. Strengthen `tests/stitched_s7_no_cards_test.gd` to fail on dormant callable `StarterCards`/card/deck paths, not just visible card screens. Wire externally supplied `assets/paper/ui/title_dark_logo.png`, `title_primary_plank.png`, and `title_secondary_plank.png` into `scripts/patchwork_ui_shell.gd` and title-only `scripts/app.gd` skins; keep moon/fog/lantern framing, readable bone/brass contrast, distinct primary/secondary hover/focus/disabled states and subtle authored-layer sway. Update the existing image-path assertions in `tests/patchwork_ui_shell_test.gd`, `tests/stitched_gothic_title_menu_test.gd`, and `tests/stitched_s7_title_continue_test.gd` without weakening mouse, keyboard, disabled or replay checks.

## Acceptance criteria
AC1: Actual compiled/source `app.gd` and `app.tscn` expose no callable retired-card, `StarterCards`, deck or legacy route admission across New Run, Continue, Wren's Room, routed Fight/visit, loss and restart; the strengthened `stitched_s7_no_cards_test.gd` proves it.
AC2: Three externally authored dark title images are installed and wired, without drawing/editing PNGs in code. `stitched_gothic_title_menu_test.gd`, `stitched_s7_title_continue_test.gd` and `patchwork_ui_shell_test.gd` prove real three-button mouse/keyboard/focus/disabled behavior. The relay's own 1280x720 `title_boot.png` visually confirms a coherent dark hierarchy.
AC3: `stitched_s6_full_run_test.gd`, `stitched_s6_save_load_test.gd`, `stitched_s7_no_cards_test.gd`, `stitched_s7_title_continue_test.gd` and `live_web_playtest_boot_test.gd` prove legal Stitched-only route and authentic Save/Continue/restart without regression; full controller suite and independent review pass.

## Out of scope
No owner-owned corridor/junction/visit/fight UI, S14/S15 tuning, new Events, other lane files, code-drawn visuals, PNG modification by coders, card-only gameplay revival or new legacy-card cleanup beyond the live S7 admission boundary. If the three dark assets are unavailable, defer this whole gate rather than claiming VIS-A or shipping another partial slice.
@@PLAN_END@@
@@TASK_SCOPE_START@@
{"feature":"S7 complete public card-free admission and dark gothic title VIS-A","files":["scripts/app.gd","scripts/patchwork_ui_shell.gd","tests/stitched_s7_no_cards_test.gd","tests/stitched_s7_title_continue_test.gd","tests/stitched_gothic_title_menu_test.gd","tests/patchwork_ui_shell_test.gd"],"depends_on":["scenes/app.tscn","themes/gothic_theme.tres","scripts/base_screen.gd","tests/stitched_s6_full_run_test.gd","tests/stitched_s6_save_load_test.gd","tests/live_web_playtest_boot_test.gd","assets/paper/backgrounds/title.png","assets/paper/ui/title_logo.png","assets/paper/ui/reward_button.png","assets/paper/ui/reward_banner.png"],"size":"large"}
@@TASK_SCOPE_END@@
@@BRIEF_START@@
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
@@BRIEF_END@@
@@FILE_END@@