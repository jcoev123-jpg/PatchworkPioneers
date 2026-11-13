TITLE: Fix mounted Peddler Save generation rejection after I/O fixes
MILESTONE: S6
@@PLAN_START@@
## Goal and current behavior
The S7/VIS-A whole gate remains deferred: the three owner-supplied dark title PNGs are still absent, so do not resubmit deferred 667 unchanged. Fix an evidenced S6 release-reliability regression instead. After accepted cycles 662 (bounded save I/O retry) and 665 (close read handles before replay), flaky_tests.json still records seven failures apiece in tests/stitched_s6_routed_{tonic,fresh_stuffing}_live_test.gd, including failures after those fixes: an authentic mounted Peddler Save leaves a file that does not match that visit's snapshot/journal. scripts/app.gd:5056-5062 silently guards Save by session, page, epoch and service before _stitched_run_save_file; determine whether the current-generation callback is skipped or whether a genuine publish fails.

## Changes and tests
In scripts/app.gd, keep stale generation refusal but make the mounted Save callback obey exactly the generation the current visible page represents; distinguish guard rejection from unsuccessful publish in the existing failure state, without allowing an old Save/Reload to touch a successor. Do not infer success from file existence. Extend tests/stitched_s6_peddler_save_generation_test.gd with repeatable real open-Shop Save presses, captured page/session/epoch/service ownership and exact post-press disk snapshot, journal, stock, wallet and RNG; prove stale callbacks have no effect. Update the two existing routed tonic/stuffing tests only as necessary to exercise the same bound callback and diagnose the first mismatching state field, retaining their earned-wallet purchases and onward Continue. If inspection proves the writer rather than the page boundary at fault, report the evidence and make no speculative callback relaxation.

## Acceptance criteria
AC1: A genuinely current, parented, enabled Peddler Save publishes the exact current visit and journal; repeated real mounted tonic/stuffing routes no longer read an older generation. Tests identify whether callback or publish failed.
AC2: A retired page/epoch Save or Reload cannot replace or restore a later session, spend stock, change RNG or overwrite sealed bytes; a genuinely failed Save never enables stale Reload.
AC3: Both routed suites and the Peddler generation suite retain authentic buttons, current snapshots, legal purchases, refusal/no-spend, mid-visit reload and title Continue witnesses; existing S6 save/load and full controller suites pass, with independent review.

## Out of scope
No owner-owned corridor/shop screen design, new services, PNGs, S14/S15 rules, card revival or duplicate 662/665 I/O retry/handle work. S7 title gate resumes only when its external art prerequisite lands.
@@PLAN_END@@
@@TASK_SCOPE_START@@
{"feature":"Current-generation mounted Peddler Save callback reliability","files":["scripts/app.gd","tests/stitched_s6_peddler_save_generation_test.gd","tests/stitched_s6_routed_tonic_live_test.gd","tests/stitched_s6_routed_fresh_stuffing_live_test.gd"],"depends_on":["scenes/app.tscn","tests/stitched_s6_save_load_test.gd","tests/stitched_s6_routed_vis_a_test.gd"],"size":"medium"}
@@TASK_SCOPE_END@@
@@BRIEF_START@@
# Objective
Eliminate post-662/665 stale-generation Peddler Save failures specifically at the mounted app callback boundary. The required S7 dark title art is absent; do not retry deferred 667.

# Files to change
scripts/app.gd; tests/stitched_s6_peddler_save_generation_test.gd; tests/stitched_s6_routed_tonic_live_test.gd; tests/stitched_s6_routed_fresh_stuffing_live_test.gd; Godot sidecars only if required.

# Implementation and tests
Read the real app.gd Peddler visit Save/Reload closure, panel epoch invalidation, and existing tests. Reproduce the current open-Peddler failure after the earlier disk-retry and handle fixes. On each pressed current button, prove whether the closure ran, which guard failed, whether its publish returned success, and whether authenticated disk replay matches the pre-press generation. Correct the smallest demonstrated mounted callback defect; keep fail-closed behavior. Use bounded repeated test executions, not sleeps or test-only forged session state. Extend the generation test and preserve the routed tonic/stuffing full wallet/pocket, post-purchase, Reload and Continue paths. Regress tests/stitched_s6_save_load_test.gd, all three targeted suites, then the full controller suite and independent review. Standing authority permits the smallest necessary supporting code and existing-test corrections without weakening any failure, negative, no-spend or replay check.

# Acceptance criteria
AC1: A genuinely current, parented, enabled Peddler Save publishes the exact current visit and journal; repeated real mounted tonic/stuffing routes no longer read an older generation. Tests identify whether callback or publish failed.
AC2: A retired page/epoch Save or Reload cannot replace or restore a later session, spend stock, change RNG or overwrite sealed bytes; a genuinely failed Save never enables stale Reload.
AC3: Both routed suites and the Peddler generation suite retain authentic buttons, current snapshots, legal purchases, refusal/no-spend, mid-visit reload and title Continue witnesses; existing S6 save/load and full controller suites pass, with independent review.

# Do NOT
Do not weaken assertions, add arbitrary wait/sleep, suppress a write failure, rework owner corridor/stop visuals, touch lane3 Behemoth work, retune combat, create/edit art, resurrect cards or split off a separate title-only build. If evidence locates the defect outside these owned files, document the blocking source precisely instead of guessing.
@@BRIEF_END@@
@@FILE_END@@