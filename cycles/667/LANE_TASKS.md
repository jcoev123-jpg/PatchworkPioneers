## lane2: Name Tinker's starter head and arm patches as sewn cloth

MILESTONE: STITCHED S14 / S13
## Goal
Make two visible Tinker patch labels describe objects a doll wears, not actions it can cast. Two entries, two files, no new combat abilities, no art and no new interface. The player's Tinker patch list must distinguish the wearable piece from its separately authored fixed signature move.

## Details (all rules/numbers/names needed, copied from the docs)
Design v4 S13: part records and their icon IDs remain as doll-worn cloth patches in head, arms, torso and legs slots; the doll's picture does not change. Stitch tiers I/II/III remain border finishes, thread maker colours and break-in/ill-fitting effects are unchanged. S14 supersedes the old body-part-grants-ability model: four fixed signature abilities per hero live in data/stitched/s14_hero_abilities.json, one per slot. The historical nested ability dictionaries in data/parts remain compatibility data, not new promises from wearing cloth. Never retune old part stats, tier effects, rank rules or S15 resistance numbers; never change fixed S14 ability names. The part inspector already uses part["name"] for visible rows and details and hides retired ability/numeric fields.

Current Tinker source (data/parts/tinker_parts.json, version 1) contains exactly the two entries in this task:
- id "tinker_head_cog_shot", owner "tinker", slot "head", top-level name "Cog Shot". Set ONLY that top-level name to "Cog-Girded Goggles". Retain its exact text: "Three chipped copper cogs are stitched around the Tinker's mismatched goggle lenses, their teeth caught in mustard thread." Retain stat {"acc":4}, nested ability id "tinker_cog_shot_move", nested ability name "Cog Shot", every launch/target/pose/effect and both existing tier overrides.
- id "tinker_arms_scrap_bomb", owner "tinker", slot "arms", top-level name "Scrap Bomb". Set ONLY that top-level name to "Washer-Pinned Sleeve". Retain its exact text: "Brass washers and bent pins bulge from the Tinker's stitched sleeve; its rust-red seams hold the scrap in place." Retain stat {"dmg":1}, nested ability id "tinker_scrap_bomb_move", nested ability name "Scrap Bomb", every launch/target/pose/effect and both existing tier overrides.

The other six Tinker parts and all their fields remain unchanged. Do not use a global string replacement. In the S14 fixed-ability catalog Tinker has independent names "Cog Shot" (id tinker_head_cog_shot, head, ranged, enemy target, launch 2-4, target 1-4, Mark 2) and "Scrap Bomb" (id tinker_arms_scrap_bomb, arms, ranged multi-target, enemy target, launch 2-4, target 1-4, Exposed 1); these fixed skill records remain unchanged. Note these S14 IDs coincide with the *part* IDs, but the namespaces/catalogs and top-level name purposes differ.

Use Art v3's dark, gothic, painted ragdoll mood and existing ID-keyed patch icons; no new picture or asset is justified for a text-only correction. The screenshots provided to the planner are layout/mood references only; do not reproduce their words, art or branding.

## Files likely touched
WRITE ONLY:
1. data/parts/tinker_parts.json — precisely the two stated top-level "name" fields.
2. tests/stitched_s4_tinker_gear_test.gd — fix expectations for those two part names and add focused semantic assertions.

Read-only references (do NOT edit): data/stitched/s14_hero_abilities.json; scripts/stitched/stitched_parts.gd; scripts/stitched/stitched_part_inspector.gd; tests/stitched_s4_part_inspector_test.gd. Search for both part IDs and both old names in tests, encounters and code before changing them; the existing Tinker test has expected "Cog Shot" / "Scrap Bomb" for top-level names as well as deliberately frozen nested ability names. Correct only top-level name checks. Do not edit the Lantern Monk, Warden or enemy-parts catalogs, shared run/combat rules, active S14/S15 matrix tests, any event data or screens. No separate test file/UID needed.

## Tests to add or update (deterministic, headless)
Extend tests/stitched_s4_tinker_gear_test.gd, reusing its real catalog fixture and existing deterministic scene-tree test runner:
- Positive: StitchedParts.load_catalog("res://data/parts/tinker_parts.json") succeeds; "by_id" names of the two specified records are the new cloth labels and match exact owner, slot and original appearance descriptions.
- Contrast: the same entries' nested ability names still read "Cog Shot" and "Scrap Bomb"; the S14 fixed Tinker signature records still have those names and unchanged IDs. Avoid asserting a total number of *other* shared catalog entries.
- Preserve the test's existing raw record snapshots and appearance checks by changing only expected top-level names where appropriate. Retain all eight original IDs, all tiers, positive combat witness assertions, invalid rank/tier/text tests, torn/unequipped and stale/spent-action rejection. Assert the other six Tinker entries remain untouched, and inspect git diff for only the two file changes.
- Run the focused Tinker headless test with Godot 4.7.2, e.g. godot --headless --path . --script res://tests/stitched_s4_tinker_gear_test.gd; run tests/stitched_s4_part_inspector_test.gd too. Run the available lane regression suite per AGENTS.md. Do not replace these with static grep-only checks.

Existing-test correction authority: you have standing authority for the smallest necessary supporting code/test corrections, including an existing shared regression if its expectation is truly invalidated, while preserving its negative/fail-closed cases. That authority is not permission to touch another active lane's owned file or to change the objective. If completing the change requires a new owner decision, defer and report it rather than inventing a goal.

## Acceptance criteria (each objectively checkable by the tests)
AC1: Given the shipped Tinker JSON, the validated two named records expose "Cog-Girded Goggles" (head) and "Washer-Pinned Sleeve" (arms), each with its unchanged ID, owner, slot and stated exact cloth text; test the loaded entries and inspect the two-field JSON diff.
AC2: Given the same validated records and the separate fixed-ability catalog, the nested historical part ability names remain "Cog Shot" and "Scrap Bomb" and the live S14 signature names/IDs are unchanged; assert both independently, not by replacing all occurrences of those phrases.
AC3: Given the shipped eight-part Tinker catalog and its three legacy stitch tiers, every other authored field and entry is unchanged, and existing full deterministic combat/rank/tier witnesses and invalid-input/fail-closed cases still pass; run the existing Tinker test and inspect diff.
AC4: Given the validated Tinker catalog mounted into StitchedPartInspector, part["name"] is the label source, so its two wearable labels change without editing UI or overriding fixed abilities; inspect scripts/stitched/stitched_part_inspector.gd and run tests/stitched_s4_part_inspector_test.gd.

No live combat wiring is being added: existing catalog/inspector presentation consumes the names. S14 battles continue to use their preexisting independent fixed abilities. Report the focused test outcomes, total suite outcome if run, and exact files changed.

@@TASK_SCOPE_START@@
{"feature":"Tinker starter head-and-arms wearable patch display names (S14 versus fixed signature abilities)","files":["data/parts/tinker_parts.json","tests/stitched_s4_tinker_gear_test.gd"],"depends_on":["data/stitched/s14_hero_abilities.json","scripts/stitched/stitched_parts.gd","scripts/stitched/stitched_part_inspector.gd","tests/stitched_s4_part_inspector_test.gd"],"size":"small"}
@@TASK_SCOPE_END@@