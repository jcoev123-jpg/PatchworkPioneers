## Root cause (one per defect; name the file and function)
- tests/stitched_s14_effect_matrix_test.gd: _family_attempt calls _live_decision_coverage, which sets landed_resistant in its `elif net > 0` branch on receipt silence, then copies it to coverage[group]["landed"]. _family_decisions stops if both group flags are set, potentially bypassing _family_decision_cast's explicit patch receipt, pre-state and rank/status checks.

## Exact fix (concrete steps; the smallest change that satisfies the brief)
- Do not promote _live_decision_coverage's landed_resistant into the five-family coverage flags. Prefer letting only _family_decision_cast mark resisted and landed once its strict receipt/d100 and recipient before/after checks succeed. Alternatively add a strict, patch-specific fresh-state/shift oracle to the initial _matrix_cast and promote only a result proven by it.
- Preserve the original routed/matrix checks and bounded real seeded hunt. Re-run enough legal public casts to establish both outcomes for all five group keys; do not inflate flags, fabricate receipts or widen balance.

## Verification (specific test/precondition/assertion that proves each correction)
- Focused tests/stitched_s14_effect_matrix_test.gd: assert all five keys attain separately verified resisted and landed entries after real sockets on S15-transformed foes, with landed flag set only after successful recipient-specific mutation/shift.
- Add a negative check: an enemy-targeted confirmed cast with a pre-existing same status, or a resisted/nonmoving/boundary push/pull, must not mark the family landed solely because no resisted patch entry appears.
- Re-run tests/stitched_s15_deeper_seams_test.gd and the named replay, heal-target, side-door and seed-cohort regressions; let controller check full suite.

## Do not touch (code or tests that must stay as they are)
- Do not modify runtime balance, S15 resist odds, gold catalog, save logic, corridor/title/UI/assets, relay files or unrelated lanes. Preserve negative, miss RNG, Wren, harmful bleed tick, LOST and Continue test coverage.
