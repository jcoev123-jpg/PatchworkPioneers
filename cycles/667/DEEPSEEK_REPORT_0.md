# Cycle 667 — S7/VIS-A release gate: S7 completed, gate DEFERRED on missing owner art

## Files changed
- `scripts/app.gd`
  - `_open_base()`: disconnected the three retired bedroom card-Path signal wirings
    (`path_choice_requested`, `tinker_path_choice_requested`, `warden_path_choice_requested`).
    The hidden Path boards' option presentation stays as unpublished data so shared village
    regressions keep their fixtures; a comment records that no app callback can claim a Path.
  - Eliminated the obsolete callbacks `_base_path_choice`, `_base_tinker_path_choice` and
    `_base_warden_path_choice`. This removes both remaining `StarterCards.new()` callables
    (the stated blocker) and every reachable card/deck entry point on the bedroom route.
- `tests/stitched_s7_no_cards_test.gd` (additive strengthening only; no check removed or weakened)
  - Added `StarterCards` to the dormant-only legacy class audit.
  - New source check: no `StarterCards.new(`, none of the three retired callback names, and no
    `path_choice_requested.connect(` may appear in `app.gd`.
  - Compiled-method audit now also rejects any method whose name contains `path_choice`;
    tree-wide connection audit now also flags connections binding a `path_choice` method.
  - New live checks while the room is mounted: full `_audit_no_card_sources(app)` re-run plus
    proof that the mounted bedroom's three retired card-Path signals have zero connections.

## How tested (run_test, all PASS)
stitched_s7_no_cards (151 checks, up from 124), stitched_s7_title_continue (153),
live_base_screen_entry (100), base_warden_path_picker (172), base_village_house_shortcuts (36),
stitched_s4_village_combat_guide (380), stitched_s6_village_part_atlas (561),
stitched_gothic_title_menu (676), patchwork_ui_shell (939), live_web_playtest_boot (305),
stitched_s6_full_run (217), stitched_s6_save_load (267), stitched_s9d_bedroom (1134),
playtest_cheats (24), base_village_backdrop_motion (44), smoke_test.
No scratch files were created; only the two reserved files were edited.

## Known issues
- The VIS-A half is not implemented: the three owner-supplied dark title PNGs (dark logo and
  distinct sewn primary/secondary planks) plus their `.import` sidecars have not landed under
  `assets/paper/ui/` (complete sidecar inventory shows no such ids, and no authored paths are
  named in the repo or design docs). The brief forbids generating or altering art and requires
  deferring when prerequisites are absent, so no speculative asset paths were wired into
  `scripts/patchwork_ui_shell.gd` or the title/shell tests. When the art lands, only the VIS-A
  wiring and its test expectations remain.
- Suggested follow-up (not done, out of scope while deferred): once the planks land, retire the
  now data-only bedroom Path board presentation entirely.

@@ACCEPTANCE_CHECK_START@@
[{"criterion":"AC1","code":"scripts/app.gd _open_base() card-Path signal wirings removed; _base_path_choice/_base_tinker_path_choice/_base_warden_path_choice eliminated (both StarterCards.new() callables gone)","verification":"tests/stitched_s7_no_cards_test.gd _audit_no_card_sources: source (StarterCards dormant-only, no callback names, no path_choice connects), compiled methods (no card/path_choice), tree connections, plus new mounted-bedroom audit and unwired retired-signal checks; 151 checks, 0 failures","result":"PASS"},
{"criterion":"AC2","code":"scripts/patchwork_ui_shell.gd untouched: required owner-supplied dark logo and primary/secondary plank PNGs are absent from assets/paper/ui (no .import sidecars or authored ids anywhere)","verification":"asset inventory inspection; brief forbids generating art and mandates deferral when prerequisites are absent, so mounting/capture checks cannot run","result":"DEFERRED"},
{"criterion":"AC3","code":"S7 scope green with exact Continue/restart state and unregressed rejection behavior preserved by the unchanged title/shell tests","verification":"16 run_test files PASS incl. the six named suites and full controller suite to follow after DONE; independent review pending; gate not claimable while AC2 art is missing","result":"DEFERRED"}]
@@ACCEPTANCE_CHECK_END@@

@@CODER_STATUS_START@@
{"status":"DEFERRED","reason":"VIS-A requires three owner-supplied dark title PNGs (dark logo, distinct sewn primary/secondary planks) and their sidecars, which the external art pipeline has not landed under assets/paper/ui; the brief forbids generating or altering art and mandates deferring the whole gate while that prerequisite is absent. The S7 card-free admission half is complete, tested and preserved in the worktree: both StarterCards.new() callables and all three bedroom card-Path callbacks are disconnected and eliminated, with the strengthened audit passing."}
@@CODER_STATUS_END@@

## Changed files (git status)
```
 M scripts/app.gd
 M tests/stitched_s7_no_cards_test.gd
```

## Full suite (run by the Mistral web coder)
```
exit code 0

--- last lines ---
PASS stitched_s6_kid_fear_loss_live_test.gd (rc=0, 31.6s)
PASS stitched_s6_one_step_party_replace_live_test.gd (rc=0, 4.9s)
PASS stitched_s6_party_pick_live_test.gd (rc=0, 8.8s)
PASS stitched_s6_peddler_bandage_live_test.gd (rc=0, 17.1s)
PASS stitched_s6_peddler_candle_live_test.gd (rc=0, 18.9s)
PASS stitched_s6_peddler_part_live_test.gd (rc=0, 15.1s)
PASS stitched_s6_peddler_patch_live_test.gd (rc=0, 64.5s)
PASS stitched_s6_peddler_save_generation_test.gd (rc=0, 16.4s)
PASS stitched_s6_routed_fresh_stuffing_live_test.gd (rc=0, 45.1s)
PASS stitched_s6_routed_pins_live_test.gd (rc=0, 27.8s)
PASS stitched_s6_routed_replacement_live_test.gd (rc=0, 18.5s)
PASS stitched_s6_routed_tonic_live_test.gd (rc=0, 46.8s)
PASS stitched_s6_routed_vis_a_test.gd (rc=0, 40.1s)
PASS stitched_s6_run_party_picker_live_test.gd (rc=0, 8.8s)
PASS stitched_s6_save_load_test.gd (rc=0, 21.9s)
PASS stitched_s6_sewing_mend_live_test.gd (rc=0, 13.9s)
PASS stitched_s6_sewing_upgrade_live_test.gd (rc=0, 7.4s)
PASS stitched_s6_torn_carry_live_test.gd (rc=0, 13.6s)
PASS stitched_s6_unpicker_live_test.gd (rc=0, 32.3s)
PASS stitched_s6_warden_vital_event_live_test.gd (rc=0, 5.5s)
PASS stitched_s7_moth_sacrifice_live_test.gd (rc=0, 38.8s)
PASS stitched_s7_no_cards_test.gd (rc=0, 10.4s)
PASS stitched_s7_routed_dye_live_test.gd (rc=0, 45.3s)
PASS stitched_s7_title_continue_test.gd (rc=0, 8.4s)
PASS stitched_s8b_walk_screen_test.gd (rc=0, 7.6s)
PASS stitched_s8f_app_walk_test.gd (rc=0, 5.8s)
PASS stitched_s8f_corridor_save_gate_test.gd (rc=0, 6.4s)
PASS stitched_s8f_peddler_walk_supplies_live_test.gd (rc=0, 12.8s)
PASS stitched_s8s9_corridor_victory_handoff_test.gd (rc=0, 15.0s)
PASS stitched_s8s9_live_combat_continue_test.gd (rc=0, 8.7s)
PASS stitched_s9c_story_frame_test.gd (rc=0, 4.8s)
PASS stitched_s9d_bedroom_test.gd (rc=0, 6.7s)
PASS v3_hero_choice_events_test.gd (rc=0, 2.2s)
PASS v3_warden_starter_cards_test.gd (rc=0, 2.1s)
PASS stitched_50_seed_cohort_test.gd (rc=0, 37.3s)

slowest: stitched_s6_peddler_patch_live_test.gd 64.5s, stitched_s6_routed_tonic_live_test.gd 46.8s, stitched_s7_routed_dye_live_test.gd 45.3s, stitched_s6_routed_fresh_stuffing_live_test.gd 45.1s, stitched_s6_candle_admission_live_test.gd 41.6s, stitched_s6_routed_vis_a_test.gd 40.1s, stitched_s6_ferry_event_live_test.gd 38.9s, stitched_s7_moth_sacrifice_live_test.gd 38.8s

378/378 passed
(314 slow-tier tests deferred to the relay's background slow check)
```
