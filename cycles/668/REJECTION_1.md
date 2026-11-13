## Defects
- tests/stitched_s14_effect_matrix_test.gd: _family_attempt copies _live_decision_coverage's landed_resistant flag into a five-family landed witness even when a fresh matching status/HP/rank mutation is unproved; _family_decisions can then skip _family_decision_cast. Require each of the five landed flags to come only from a confirmed patch receipt and its recipient-specific fresh-state or valid-shift oracle.

## Notes
FIX_REQUIRED — one AC1 coverage defect in the five-family test, not a runtime-rule defect.

The staged diff touches only tests/stitched_s14_effect_matrix_test.gd and tests/stitched_s15_deeper_seams_test.gd. The matrix, legal run-owned Sewing Circle sockets, transformed Fight/Elite foes, dedicated receipt/RNG oracles, gold's non-resistible public steal, bleed-only ally tick, LOST fallback and fresh Continue checks are present. The death-door adjustment matches StitchedRules._death_door_hit's exhausted-limb fallback. The controller reports 380/380 passed; the six named focused tests were reported passing. The latest 15 master commits do not implement the same five-family witness.

However, _family_attempt feeds _live_decision_coverage's absence-based "landed_resistant" into coverage[group]["landed"]. That helper sets the flag whenever a hit has net resistance and no resisted entry, without requiring a landed patch entry, a fresh recipient, or a successful move. Once that flag and "resisted" are true, _family_decisions exits before its stronger _family_decision_cast oracle runs. _assert_effects checks patch receipts, but can accept a pre-existing status or a refused boundary shift; it does not close the fresh-mutation requirement. Thus AC1 can go green without the specifically required distinct landed target mutation.

Reachability: the new test path uses actual run-entered battles, owned sockets and public casts, so it is live-game reachable; the defect is the coverage gate, not missing wiring. AC2/AC3 have no additional identified blocker.
