@@REVIEW_START@@
FIX_REQUIRED — one AC1 coverage defect in the five-family test, not a runtime-rule defect.

The staged diff touches only tests/stitched_s14_effect_matrix_test.gd and tests/stitched_s15_deeper_seams_test.gd. The matrix, legal run-owned Sewing Circle sockets, transformed Fight/Elite foes, dedicated receipt/RNG oracles, gold's non-resistible public steal, bleed-only ally tick, LOST fallback and fresh Continue checks are present. The death-door adjustment matches StitchedRules._death_door_hit's exhausted-limb fallback. The controller reports 380/380 passed; the six named focused tests were reported passing. The latest 15 master commits do not implement the same five-family witness.

However, _family_attempt feeds _live_decision_coverage's absence-based "landed_resistant" into coverage[group]["landed"]. That helper sets the flag whenever a hit has net resistance and no resisted entry, without requiring a landed patch entry, a fresh recipient, or a successful move. Once that flag and "resisted" are true, _family_decisions exits before its stronger _family_decision_cast oracle runs. _assert_effects checks patch receipts, but can accept a pre-existing status or a refused boundary shift; it does not close the fresh-mutation requirement. Thus AC1 can go green without the specifically required distinct landed target mutation.

Reachability: the new test path uses actual run-entered battles, owned sockets and public casts, so it is live-game reachable; the defect is the coverage gate, not missing wiring. AC2/AC3 have no additional identified blocker.
@@REVIEW_END@@
@@VERDICT_START@@
{"verdict":"FIX_REQUIRED","defects":["tests/stitched_s14_effect_matrix_test.gd: _family_attempt copies _live_decision_coverage's landed_resistant flag into a five-family landed witness even when a fresh matching status/HP/rank mutation is unproved; _family_decisions can then skip _family_decision_cast. Require each of the five landed flags to come only from a confirmed patch receipt and its recipient-specific fresh-state or valid-shift oracle."],"summary":"Five-family live coverage is wired and controller tests pass (380/380), but AC1's non-vacuous landed proof is not guaranteed because the collector still treats absence of resistance as a landing. No duplicate feature identified on recent master."}
@@VERDICT_END@@
@@DIAGNOSIS_START@@
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
@@DIAGNOSIS_END@@
