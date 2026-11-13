# Cycle 668 fix report: five-family landed-witness false green

## Files changed
- `tests/stitched_s14_effect_matrix_test.gd` (only file changed; it is this lane's reserved/changing file)

## What each change does
1. **`_family_attempt`**: removed the shim that ran the initial matrix cast's results through
   `_live_decision_coverage` and copied its flags into the five-family witness. That helper sets
   `landed_resistant` in its `elif net > 0` branch on receipt silence (no resisted entry), without
   proving a fresh recipient mutation or a legal shift, and the copy could let `_family_decisions`
   exit before `_family_decision_cast` ever ran. Now only the strict decision-cast oracle may mark
   a family `resisted` or `landed`; the initial matrix cast, its twin replay and `_assert_effects`
   oracle are preserved unchanged.
2. **`_family_decision_cast`**: its landed decision (fresh-state/prior==0 check for statuses, exact
   one-rank shift check for movement) was extracted verbatim into the shared `_family_lands`
   helper; the cast now consumes that helper and keeps its original check messages. The now-unused
   `amount` local was removed.
3. **New `_family_lands`**: the single landed gate for the five families: a confirmed patch receipt
   lands only through a landed, unrefused patch entry resting its authored amount on a recipient
   whose pre-cast state lacked that status, or a valid shift of its actual target by exactly one
   legal rank. Absence of a resisted entry alone never lands.
4. **New negative gate `_family_negative_landing`** (called from `_initialize` after
   `_routed_family_witnesses`), driving the same shared oracle through real public Command casts on
   S15-transformed foes:
   - `_family_negative_status`: a cotton Red Lint bleed first lands on a genuinely fresh foe
     (positive control: the oracle accepts it), then a confirmed restrike on that same
     still-bleeding foe shows a landed entry with no resisted entry and must NOT mark the family
     landed (pre-existing same status).
   - `_family_negative_boundary`: a wool Hook Stitch pull that beats its resist draw at the front
     rank is boundary-refused, leaving a landed patch id, no resisted entry and an unmoved actual
     target; the shift oracle must NOT mark the family landed (nonmoving/boundary push/pull).

Untouched: `_live_decision_coverage` still serves the accepted live/routed sections; matrix, twin,
gold non-resistible, LOST/Continue, miss-purity, replay and S15 test coverage unchanged. No runtime
code, balance or other files modified; no scratch files created.

## How I tested (all green)
- `tests/stitched_s14_effect_matrix_test.gd`: PASS, 3599 checks, 0 failures. All five family keys
  attained separately verified resisted and landed entries strictly through the decision-cast
  oracle (the final five resisted/landed assertions cannot pass otherwise), and both negative
  probes reached their assertions (their bounded-search fallback `_check(false, ...)` did not fire).
- `tests/stitched_s15_deeper_seams_test.gd`: PASS, 1182 checks, 0 failures.
- `tests/stitched_s14_heal_patch_target_test.gd`: PASS, 107 checks, 0 failures.
- `tests/stitched_s8s9_live_combat_continue_test.gd`: PASS, 155 checks, 0 failures.
- `tests/stitched_s14_side_door_departure_test.gd`: PASS, 63 checks, 0 failures.
- `tests/stitched_50_seed_cohort_test.gd`: PASS (rc=0).

## Known issues
- None. The controller's full-suite run follows this report per the relay flow.

@@ACCEPTANCE_CHECK_START@@
[{"criterion":"AC1","code":"tests/stitched_s14_effect_matrix_test.gd _family_attempt (shim promotion removed), _family_decisions/_family_decision_cast, _family_lands","verification":"stitched_s14_effect_matrix_test.gd: five family keys each prove a real run-owned socketed patch resisted (honest d100 under rarity-pierced net resist) and landed (fresh recipient mutation or exact one-rank shift) only through the decision-cast oracle; 3599 checks, 0 failures","result":"PASS"},
{"criterion":"AC2","code":"tests/stitched_s14_effect_matrix_test.gd matrix/_assert_effects, gold sections, routed sections (preserved unchanged) + new _family_negative_landing","verification":"stitched_s14_effect_matrix_test.gd passes: cotton/wool/silk pierce and gold's non-resistible no-extra-draw contract in the matrix; negative probes prove a pre-existing-status restrike and a boundary pull never mark a family landed absent a resisted entry","result":"PASS"},
{"criterion":"AC3","code":"tests/stitched_s15_deeper_seams_test.gd (rot PROT bypass / halved heal), ordered gold sockets, LOST and fresh Continue sections (preserved unchanged)","verification":"stitched_s15_deeper_seams_test.gd 1182/0, stitched_s8s9_live_combat_continue_test.gd 155/0, stitched_s14_heal_patch_target_test.gd 107/0, stitched_s14_side_door_departure_test.gd 63/0, stitched_50_seed_cohort_test.gd PASS; full suite is the controller's post-DONE run","result":"PASS"}]
@@ACCEPTANCE_CHECK_END@@

@@CODER_STATUS_START@@
{"status":"COMPLETED"}
@@CODER_STATUS_END@@

## Changed files (git status)
```
MM tests/stitched_s14_effect_matrix_test.gd
M  tests/stitched_s15_deeper_seams_test.gd
```

## Full suite (run by the Mistral web coder)
```
exit code 0

--- last lines ---
PARTIAL RUN: only test files changed since the full run at 18:11 on this commit, so only 1 tests run (changed, or failed there): stitched_s14_effect_matrix_test.gd. The other 379 passed there and nothing they run has changed. This is the full-suite result for this tree; report it as the full-suite run.
PASS stitched_s14_effect_matrix_test.gd (rc=0, 78.3s)

slowest: stitched_s14_effect_matrix_test.gd 78.3s

380/380 passed
```
