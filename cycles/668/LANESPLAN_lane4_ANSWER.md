@@PLAN_START@@
TITLE: Skip impossible Elite side-door rolls without shifting the run seed
MILESTONE: S14 — ability patches, limb loss and side-door deals
LANE: lane4 (Gemini 4 Argon via Antigravity)
SIZE: small

## Goal
Fix a real event-rule discrepancy in StitchedS14SideDoors.offer: an Elite currently consumes the 70%-door chance roll even if the filtered door pool is empty and no choice could ever be offered. A run that cannot pay any Underbed deal and is ineligible for Attic therefore advances its one seeded RNG for an event that never occurs. Decide whether any legal door exists before drawing the Elite door chance. No new event, screen, quote, art, probability or deal is added.

## Existing source and ownership
- scripts/stitched/stitched_s14_side_doors.gd: catalog validates the six authored deals; offer(rng, kind, underbed_taken, leg_payer_available, stuffing_payer_available, fear_payer_available, attic_candle_available, attic_mend_available, attic_head_guard_available) filters Underbed by payer and Attic by both no prior Underbed deal and useful reward. Currently the Elite randi_range(1, 100) > 70 rejection occurs before those filters.
- data/stitched/s14_side_doors.json: Underbed: underbed_stuffing_trade, max_hp 6 for gold_patch; underbed_leg_trade, limb 1 for silk_patch; underbed_fear_trade, fear 15 for wren_gift. Attic: attic_waxlight (candle), attic_rethread (mend), attic_headward (head_guard), all free, amount 0. Do not change them.
- Underbed reward weights must remain gold_patch 1, silk_patch 5, wren_gift 4. An eligible Elite still has a 70% chance to offer a door; a Boss skips this chance test. If both kinds have eligible entries, the kind choice is a seeded 0/1 draw; then select uniformly from the existing sorted, weighted pool. Prior Underbed acceptance still excludes Attic.
- Already-active main 668 owns Stitched rules/session/save and S14/S15 effect tests; next main owns app.gd. Accepted lane4 Moonblack work owns the route-event catalog, consequence script and its tests. This task owns none of those paths. All six door records and battle/session ownership stay unchanged.

## Acceptance criteria
AC1: With an authentic six-record door catalog, an Elite or Boss with underbed_taken=true and all three Underbed payer flags=false returns {}, leaves rng.state unchanged, and cannot offer a fictitious bargain. Prove with deterministic Godot test on StitchedS14SideDoors.offer and a seeded RNG. (Attic is forbidden by the prior deal.)
AC2: An Elite with at least one eligible Underbed or Attic record still applies the unchanged 70% gate, sorted reward pools and weighted odds. Bosses still skip the 70% gate. Prove seeded positive and declined cases against the pre-change legal-pool algorithm: same records or no offer, same subsequent RNG state, both kinds where applicable. Do not replace probabilities with invented balancing.
AC3: Keep false payer flags excluding only their matching Underbed cost, false Attic flags excluding only matching blessings, and underbed_taken excluding Attic. Existing genuine Elite-door choice/decline and save/restore tests remain green, including stale refusal and once-only payment. Run the focused new test, existing tests/stitched_s14_side_door_departure_test.gd, and the available full Stitched suite; no weakened/removed negative checks.

## Scope and limits
Move only the empty-pool check relative to the Elite chance draw and its necessary pure test. Preserve 70%, all costs and rewards, the signature and result shape, deterministic sorting, ordinary valid-pool draw order, genuine public run integration and owner-owned corridor UI. There is no live wiring change: the existing run already invokes this offer helper. Keep the existing departure regression intact unless a newly demonstrated direct conflict requires the smallest necessary correction; that correction must not overlap any active reserved path. Coder has standing authority for the smallest necessary supporting code/test corrections, including existing tests when legitimately affected, while preserving their negative coverage; concurrent ownership, unrelated features, tests and relay files are protected. If an unanticipated change requires a new owner decision, defer it rather than altering the goal.

@@PLAN_END@@
@@TASK_SCOPE_START@@
{"feature":"S14 Elite side-door eligibility-before-RNG event rule","files":["scripts/stitched/stitched_s14_side_doors.gd","tests/stitched_s14_side_door_empty_pool_rng_test.gd","tests/stitched_s14_side_door_empty_pool_rng_test.gd.uid"],"depends_on":["data/stitched/s14_side_doors.json"],"size":"small"}
@@TASK_SCOPE_END@@

@@LANE_lane4_START@@
TITLE: Skip impossible Elite side-door rolls without shifting the run seed
MILESTONE: S14
## Goal
In the existing S14 side-door event provider, do not roll the 70% Elite-door chance if no door could legally open. At present StitchedS14SideDoors.offer draws the Elite chance before it filters unpayable Underbed deals and unusable Attic blessings, moving the run's seeded RNG even when it necessarily returns {}. Fix only that ordering and prove that all viable door offers remain byte-for-byte and RNG-for-RNG compatible.

## Details (all rules/numbers/names needed, copied from the docs)
The game is Godot 4.7.2, Design v4 Stitched: a 12-floor run of four ragdoll heroes with found ability-effect patches, fray, candle and limb loss. After an Elite or Boss, the existing S14 provider may offer a side door, not an extra map node. Underbed (Hell in the internal design) costs a limb, stuffing/max HP or Wren fear; Attic (Heaven in the internal design) is free but unavailable after an Underbed deal. Screens, corridor and player art belong to the owner; do not add or edit any visuals or player text.

Actual production API: static StitchedS14SideDoors.offer(rng: RandomNumberGenerator, kind: String, underbed_taken: bool, leg_payer_available: bool = true, stuffing_payer_available: bool = true, fear_payer_available: bool = true, attic_candle_available: bool = true, attic_mend_available: bool = true, attic_head_guard_available: bool = true) -> Dictionary, in scripts/stitched/stitched_s14_side_doors.gd. The provider loads data/stitched/s14_side_doors.json and its catalog returns keyed authentic records. Current authored records:
- underbed_stuffing_trade: kind underbed, cost max_hp, amount 6, reward gold_patch (pool weight 1);
- underbed_leg_trade: kind underbed, cost limb, amount 1, reward silk_patch (weight 5);
- underbed_fear_trade: kind underbed, cost fear, amount 15, reward wren_gift (weight 4);
- attic_waxlight: kind attic, cost none, amount 0, reward candle;
- attic_rethread: kind attic, cost none, amount 0, reward mend;
- attic_headward: kind attic, cost none, amount 0, reward head_guard.

Underbed candidates are excluded by the matching payer=false flag. Attic candidates are excluded when underbed_taken=true or when the matching candle/mend/head-guard availability flag is false. Preserve the existing weighted repeated-ID Underbed pool and its sort(), the sorted Attic pool, and the existing 50/50 side selection when both nonempty. On an ELIGIBLE Elite offer: draw randi_range(1,100), show no door for 71..100, then use existing side and entry draws for 1..70. Boss offers do not use the 70% chance roll. An invalid kind or null RNG still returns {}. When both candidate pools are empty, return {} BEFORE any Elite chance draw, without advancing rng.state. No changes to rates, entries, prices, catalog, public signature or other behavior.

Make this small in the event-rule layer. Do not edit scripts/stitched/stitched_run_session.gd, scripts/stitched/stitched_rules.gd, scripts/app.gd, data/stitched/s14_ability_patches.json, scripts/run_stitched_event_consequence.gd or any main/lane-reserved files. No new events, service forecasts, status UI, card mechanics, body-part stats, player buttons or S15 balance. Existing real game path already consumes the provider; do not add a fake wiring path.

## Files likely touched
- scripts/stitched/stitched_s14_side_doors.gd — relocate the existing Elite chance test to after building/checking the eligible pools, before drawing side or offer.
- tests/stitched_s14_side_door_empty_pool_rng_test.gd — one short deterministic headless test for the exact rule; if generated, include its tests/stitched_s14_side_door_empty_pool_rng_test.gd.uid sidecar.
Read-only resources: data/stitched/s14_side_doors.json for the actual six rows and AGENTS.md for headless test conventions. Existing tests/stitched_s14_side_door_departure_test.gd is a regression to RUN, not an edit target. No file another live task reserves or is changing is required, even as a task dependency.

## Tests to add or update (deterministic, headless)
1. Use a seeded RandomNumberGenerator. Underbed taken=true and all three payer flags=false makes both pools empty; assert Elite and Boss both return {} and their rng.state is precisely unchanged. Distinguish this from a legitimate 71..100 Elite decline, which consumes the chance draw.
2. For valid pools, compare the new provider with an explicit in-test oracle of the OLD legal-pool draw sequence, using identical RNG seeds before calls and comparing full returned record plus post-call rng.state: cover an eligible Elite declined by its 70% gate, an eligible Elite that offers a record, a Boss with Underbed options, an Attic-eligible Boss without an Underbed deal, and an only-one-side-eligible case. Test a bounded deterministic set of seeds to find both <=70 and >70 witnesses; never assert a fixed total count of offers.
3. Confirm distinct false payer flags suppress only underbed_stuffing_trade, underbed_leg_trade or underbed_fear_trade respectively, and Attic flags suppress the matching reward only; unchanged positive choices and negative/invalid admission retain their existing behavior. Run godot --headless --path . --import then godot --headless --path . -s res://tests/stitched_s14_side_door_empty_pool_rng_test.gd; run the existing tests/stitched_s14_side_door_departure_test.gd and full available test suite. A successful command alone does not excuse SCRIPT ERROR or Parse Error. No removal/weakening of existing tests.

## Acceptance criteria
AC1: Given the authentic six-door catalog and underbed_taken=true with leg_payer_available=false, stuffing_payer_available=false and fear_payer_available=false, both Elite and Boss offer {} and rng.state remains exactly equal to before the call. Demonstrate using a seeded direct provider test; neither side has a legitimate candidate.
AC2: Given any nonempty filtered pool, Elite still has a 70% chance of a door (roll 1..70) and Boss has no chance gate. Seeded positive and declined cases compare the unchanged ranked/sorted/weighted selection and resulting RNG state to the pre-change legal-pool algorithm. The three Underbed reward weights are 1/5/4, and no authored deal or reward changes.
AC3: Given mixed payer/Attic availability, the established eligible alternatives remain eligible, impossible alternatives remain excluded and prior Underbed deals still prevent Attic. Existing genuine Elite offer, decline, stale claim, once-only payment and save/restore replay in tests/stitched_s14_side_door_departure_test.gd remain green, alongside the new direct test and the rest of the Stitched suite. Preserve all negative/fail-closed coverage.

The coder has standing authority for the smallest necessary supporting code/test corrections, including existing tests only where this goal actually affects them and without weakening negative coverage; concurrent ownership, unrelated feature/balance changes and relay instructions remain protected. A requirement for a new owner decision is deferred instead of changing the acceptance goal. The only active work touched should be this task's own paths.

@@TASK_SCOPE_START@@
{"feature":"S14 Elite side-door eligibility-before-RNG event rule","files":["scripts/stitched/stitched_s14_side_doors.gd","tests/stitched_s14_side_door_empty_pool_rng_test.gd","tests/stitched_s14_side_door_empty_pool_rng_test.gd.uid"],"depends_on":["data/stitched/s14_side_doors.json"],"size":"small"}
@@TASK_SCOPE_END@@
@@LANE_lane4_END@@
@@FILE_END@@
