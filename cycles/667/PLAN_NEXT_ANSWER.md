TITLE: Prove every S15 resistance family through live sewn abilities
MILESTONE: BAL — S14 x S15 live acceptance
@@PLAN_START@@
## Goal and current behavior
After cycle 667's assumed S7/VIS-A acceptance, finish the next BAL gate without repeating cycle 666. `tests/stitched_s14_effect_matrix_test.gd` now covers all validated signature/patch combinations and routed ally/self/foe witnesses, but its live coverage accepts only two distinct effect families; `tests/stitched_s15_deeper_seams_test.gd` still proves much rarity resistance with direct `_resisted` probes. The unproven boundary is actual run-mounted S15 resistance across stun, bleed, rot, move and debuff.

## Changes and tests
Extend those two existing tests, reusing their seeded catalog loops, real `StitchedRunSession` Fight/Elite entries, legal `use_ability` actions and receipt/state oracles. For each of the five S15 groups, witness a live resisted and a landed sewn effect on an actual S15-transformed foe; compare status/HP/rank and the committed receipt, not just a private helper result. Cover cotton/wool/silk/gold piercing using authored patches (gold's no-roll case), recipient-side harmful ally effects, Wren's unresisted hand, misses and deterministic mid-Fight journal/Continue where applicable. Fix only a demonstrated rules/application/save defect. Preserve existing matrix, refusal, LOST, gold-socket and replay assertions. Run focused suites, full controller tests and independent review.

## Acceptance criteria
AC1: The catalog matrix still proves every authored four-signature hero kit against every validated patch; run-entered S15 foes now produce publicly committed resisted AND landed effects for each of stun, bleed, rot, move and debuff, with the correct actual target and state change.
AC2: Public receipts demonstrate authored rarity piercing (cotton/wool/silk/gold), including gold's guaranteed landing without a resistance RNG draw; ally/self harmful patches still affect their recipients and Wren's hand remains unresisted. A miss, illegal action or stale command cannot apply a patch or consume RNG.
AC3: Rot bypasses PROT and halves healing; torn/LOST and ordered gold-socket termination remain correct. Mid-Fight save/fresh Continue reproduces status, socket order, receipts, journal and RNG exactly. Existing focused and full controller suites pass.

## Out of scope
No S15 percentage or stat retuning, new enemies/patches, card code, owner-controlled corridor/visit/battle UI, title work, authored art, Events or other lanes' files.
@@PLAN_END@@
@@TASK_SCOPE_START@@
{"feature":"S14/S15 full five-family public sewn-patch resistance acceptance","files":["tests/stitched_s14_effect_matrix_test.gd","tests/stitched_s15_deeper_seams_test.gd","scripts/stitched/stitched_rules.gd","scripts/stitched/stitched_deeper_seams.gd","scripts/stitched/stitched_run_session.gd"],"depends_on":["AGENTS.md","data/stitched/s14_hero_abilities.json","data/stitched/s14_ability_patches.json","data/stitched/s15_deeper_seams.json","scripts/stitched/stitched_s14_abilities.gd","tests/stitched_s8s9_live_combat_continue_test.gd","tests/stitched_s14_heal_patch_target_test.gd","tests/stitched_s14_side_door_departure_test.gd","tests/stitched_50_seed_cohort_test.gd"],"size":"medium"}
@@TASK_SCOPE_END@@
@@BRIEF_START@@
# Objective
Close the remaining five-family public S14/S15 resistance acceptance gap after the accepted cycle-666 matrix work; do not rebuild existing side/patch witnesses.

# Files to change
Extend `tests/stitched_s14_effect_matrix_test.gd` and `tests/stitched_s15_deeper_seams_test.gd`. Correct `scripts/stitched/stitched_rules.gd`, `stitched_deeper_seams.gd`, or `stitched_run_session.gd` ONLY for a defect the new public witnesses actually expose.

# Implementation and tests
Read the existing matrix's `_live_run_matrix` / `_routed_resistance_witnesses` and S15 routed witnesses first. Derive representative legal target/foe/patch cases from current catalogs (no absolute catalog-count assertion); take real seeded run entries into Fight/Elite, not handcrafted resist dictionaries. Reuse genuine public turn actions, patch receipts, same-seed unsocketed comparisons, and existing mid-Fight Save/Continue witness. Strengthen coverage from "at least two" families to all five, proving each family both resists and lands; test pierce ordering and gold without an extra RNG draw, with no false-green on misses. Preserve all existing negative, no-spend, LOST, ordered-socket and replay checks; change any existing expected value only when correcting demonstrated incorrect behavior. Run `tests/stitched_s14_effect_matrix_test.gd`, `tests/stitched_s15_deeper_seams_test.gd`, `tests/stitched_s8s9_live_combat_continue_test.gd`, `tests/stitched_s14_heal_patch_target_test.gd`, `tests/stitched_s14_side_door_departure_test.gd`, `tests/stitched_50_seed_cohort_test.gd`, full controller suite, and independent review. Standing authority: make the smallest necessary supporting code/test correction, including shared regressions, without weakening failures.

# Acceptance criteria
AC1: All authored signature/patch combinations remain covered; actual run-entered S15 foes have correct committed landed/resisted receipts and recipient mutations for all five resistance groups.
AC2: Cotton/wool/silk/gold pierce and gold RNG purity, harmful ally/self effects, Wren bypass, and miss/illegal/stale refusal purity are proven through real actions.
AC3: Rot/PROT/heal, LOST and ordered sockets are preserved; independent fresh Continue matches the saved journal, receipts, statuses and RNG; all focused and full tests pass.

# Do NOT
Do not change S15 balance constants, create content, replace owner's corridor/visit/fight presentation, touch cards/title/art, or overlap active lane files. Do not delete or relax existing tests.
@@BRIEF_END@@
@@FILE_END@@