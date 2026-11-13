@@PLAN_START@@
TITLE: NONE — retire parallel part editing and event batches under the current owner order
MILESTONE: Design v4 S14/S15 acceptance; Review 2026-11-09 (cycle 657)
LANE: lane2 NONE; lane8 NONE
SIZE: small

## Goal
Do not assign obsolete or owner-prohibited content work to either small parallel lane. Preserve the owner-approved S14 fixed-signature ability/ability-patch model, the completed S4 hero-part catalogs, the active S14 x S15 public combat/resistance acceptance, and the owner-owned 3D corridor Events. Both lane areas are presently exhausted for independently authorized, useful SMALL work; do not disguise out-of-area work as a lane task.

## Current implementation and ownership
Read the cycle-668 CLAUDE_PLAN.md, STITCHED_DESIGN.md, MILESTONES.md, GAME_DESIGN.md, CHARACTER_DESIGNS.md, ART_STYLE.md, OWNER_ORDER.md, the current/reference screen indices and LIVE_WORK.md, and inspected real repository data. All eight data/parts/<hero_id>_parts.json catalogs (warden, seamstress, tinker, lantern_monk, rag_duelist, scarecrow, yarn_ranger, button_golem) and data/parts/enemy_parts.json already exist. The Warden sample still has old per-part ability/tier data, but the 2026-11-08 S14 owner choice replaces combat's per-part abilities with four fixed signature abilities per hero and separate found effects sewn onto those abilities. The explicit 2026-11-09 owner rule is: never edit or rename data/parts again; do not balance or extend retiring body-part stats/abilities. MILESTONES.md's latest stage audit marks S4 DONE (all eight hero catalogs/tests) and S5 DONE. A part-data-only or part-data-test-only assignment would either violate that freeze or merely re-prove retired gameplay, not produce a useful player-facing feature. S14 hero kits/patch effects are not lane2's HERO PARTS area.

The actual data/events/v3_roadside_events.json and data/events/v3_hero_vital_events.json contain existing routed-style, choice/outcome records, and many additional event catalogs already exist. Earlier lanes have appended repeated hero-vital and roadside batches. The 2026-11-09 cycle-657 review explicitly says to stop one-Event slices and, in its VIS-B done guidance, "no new small Event records"; the task's BAL NEXT MAIN STEPS also says "Never plan ... more small Events." Owner order makes all new event/visit presentation an in-corridor, floor-wares experience owned by the owner's Claude handoff. Lane8 is limited to at most four new Events in one catalog and one new test, without scripts or existing-test edits, so its ONLY allowed task shape is now explicitly disallowed. Inventing a data-only batch under a different catalog would not resolve this contradiction.

Cycle 668 main owns the S14/S15 effect matrix and stitched rule/session/save paths. NEXT main owns scripts/app.gd plus Peddler Save tests. The live board also lists lane3's enemy/intent work, lane4's stitched_route_effects.json/event consequence work, lane5's Patch Stall work and an accepted Behemoth merge. Those tasks are not available to these two lanes. No open "## TS" speed milestone exists. The current game has a first-person corridor shop and a title with New Run, Continue Run and Wren's Room; the owner, not these lanes, owns their presentation.

## Proposed change
lane2: NONE. Leave all hero/enemy part data and related tests unchanged. Do not turn the older STITCHED_DESIGN.md S3/S4 body-part ability format into a new task, because owner 11-09 supersedes it. Do not move lane2 into ability-patch effects, foes, or the live S15 acceptance matrix.

lane8: NONE. Do not append one more small roadside/hero-vital event to evade the current explicit no-more-small-Events direction. Do not touch the concurrently reserved stitched route-effects catalog, change event scripts, or create a new headless test for an unapproved batch. A later explicit owner change of priority would be a new planning input, not authority to act now.

## Files likely touched
NONE. Both scope blocks deliberately contain no write paths or read dependencies; no coder is launched, and no tests, catalogs, assets or shared contracts are reserved.

## Necessary existing-test corrections
NONE. Since no feature is assigned, no existing regression expectation changes. Preserve all existing authenticated record, no-duplicate, no-negative-wallet, stale-choice, LOST, resistance, seeded replay and no-card gates. The standing owner scope policy would authorize a dispatched coder's smallest necessary supporting code/test correction while maintaining negative/fail-closed coverage, but it does not authorize a forbidden goal or violation of concurrent ownership; here there is no dispatched coder.

## Acceptance criteria
- AC1 — Part ownership is respected: Given the eight existing hero-part catalogs plus enemy_parts.json, the completed S4/S5 milestone audit and the 2026-11-09 explicit data/parts freeze, lane2's brief is TITLE: NONE, has zero write paths, and cannot add, rebalance, rename or test new retired part abilities. Inspection of this plan and its lane2 task scope proves it.
- AC2 — Event direction is respected: Given the latest cycle-657 BAL ban on new small Event records, existing event catalogs, and lane8's strictly data-plus-one-new-test area, lane8's brief is TITLE: NONE and has zero write paths, event IDs or test additions. Inspection of this plan and its lane8 task scope proves it.
- AC3 — Parallel ownership is respected: Given the live board reread immediately before this answer is written, neither lane reserves or depends on a main, next-main, lane3, lane4 or lane5 file or feature. The two empty task scopes and unchanged code/test tree prove the plan introduces no collision or speculative live wiring.
@@PLAN_END@@

@@TASK_SCOPE_START@@
{"feature":"NONE — no authorized independent small HERO PARTS or EVENT CONTENT edit under current owner freezes","files":[],"depends_on":[],"size":"small"}
@@TASK_SCOPE_END@@

@@LANE_lane2_START@@
TITLE: NONE
MILESTONE: Design v4 S14 fixed hero signatures supersede completed S4 body-part abilities
## Goal
Do not dispatch further HERO PARTS editing, balancing or retired ability-data work.
## Details (all rules/numbers/names needed, copied from the docs)
The eight hero part catalogs in data/parts/ are warden_parts.json, seamstress_parts.json, tinker_parts.json, lantern_monk_parts.json, rag_duelist_parts.json, scarecrow_parts.json, yarn_ranger_parts.json and button_golem_parts.json; enemy_parts.json also exists. These are completed S4/S5 historical part/limb resources. The earlier Design v4 S4 format provided eight parts per hero (two head, two arms, two torso, two legs), a one-ability-per-part move and three stitch tiers, but the owner's 2026-11-08 S14 change RETIRES those combat abilities in favor of four signature abilities per hero with found patches applied to their effects. Owner 2026-11-09 explicitly commands "never edit or rename data/parts again" and forbids body-part stat/tier tuning. A patch is an effect added onto an ability; a body part or an ability is not itself a patch. Do not use old card rules. Lane2's HERO PARTS area cannot move to the separate S14 hero-ability/patch-effect catalogs or into S15 main-owned code. There is no permitted bounded player-facing edit here. No coder is assigned; if a genuinely new goal requires owner approval, defer the goal rather than trying to implement an unchanged forbidden slice.
Standing authority applies to genuine future authorized work only: the smallest necessary supporting code/test corrections may be made to satisfy unchanged criteria while retaining negative/fail-closed coverage, but concurrent lanes and owner restrictions take precedence.
## Files likely touched
NONE. No owned write paths, shared test changes, scripts, assets or reservations.
## Tests to add or update (deterministic, headless)
NONE. Existing S4/S5 coverage stays intact; do not add tests premised on the retired ability model.
## Acceptance criteria
- AC1 — Given the eight shipped hero-part files and enemy_parts.json, the current S14 owner instruction, and S4/S5 marked DONE, no part file, code path or test is assigned; verify TITLE: NONE and an empty files list in this task scope.
@@TASK_SCOPE_START@@
{"feature":"NONE — frozen S4/S5 hero and enemy body-part data","files":[],"depends_on":[],"size":"small"}
@@TASK_SCOPE_END@@
@@LANE_lane2_END@@

@@LANE_lane8_START@@
TITLE: NONE
MILESTONE: Design v4 S6 Events built; cycle-657 BAL bans additional small Event batches
## Goal
Do not dispatch another catalog-only micro-batch of new roadside Events.
## Details (all rules/numbers/names needed, copied from the docs)
Lane8 is restricted to ONE existing data/events/*.json catalog, at most FOUR added events in about 60–100 data lines, and ONE NEW deterministic test; it may not edit scripts or existing tests. Current repository catalogs include v3_roadside_events.json and v3_hero_vital_events.json, which already contain existing authored records and choice/outcome payloads; another concurrent lane reserves stitched_route_effects.json. Earlier batches added three hero-gated nightroad and multiple other substantial house-prop events. Although the old owner-order item 3 requested more look-driven hero-specific Events, the later 2026-11-09 Review-657 directs the relay to stop one-Event cycles and accept the corridor/Wren integration without any new small Event records. The task's BAL instructions also explicitly prohibit more small Events. Events now appear IN a first-person corridor with choices as floor wares, presented by the owner's Claude handoff; lane8 cannot edit this wiring. Copying a catalog event's schema into another new batch is not an authorized loophole. No event ID, title, reward, choice text or new test is assigned.
Standing authority allows future authorized coders the minimum necessary supporting code/test corrections with negative/fail-closed coverage preserved; it cannot override the latest owner ban or concurrently reserved files. An owner decision to resume small event batches must come first.
## Files likely touched
NONE. No catalog, test, script, art or shared contract write paths.
## Tests to add or update (deterministic, headless)
NONE. Preserve existing event loading, affordability, one-use, missing/LOST hero and stale/invalid claim regression coverage without changing it.
## Acceptance criteria
- AC2 — Given the 2026-11-09 milestone prohibition on new small Event records and lane8's data-only task constraint, no new Event, effect field, catalog edit or test is assigned; verify TITLE: NONE and an empty files list in this task scope.
@@TASK_SCOPE_START@@
{"feature":"NONE — small event additions explicitly ruled out by cycle-657 BAL and owner corridor scope","files":[],"depends_on":[],"size":"small"}
@@TASK_SCOPE_END@@
@@LANE_lane8_END@@
@@FILE_END@@