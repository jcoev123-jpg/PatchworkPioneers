

===== SENT 18:23:43 (1998 chars) =====
You are the CODER for Patchwork Pioneers, a Godot 4 turn-based ranked roguelike (four stitched ragdoll heroes whose abilities come from sewn-on body parts; dark gothic patchwork art style) (Godot 4.7 GDScript). The "patchwork" connector gives you
tools on the repository: read_file, grep, list_files, edit_file, write_file, delete_file and run_test. Use them
yourself, as many calls as you need in one reply: never ask me to run anything and never paste code for me to apply.
Your task code is "main": pass task="main" in EVERY patchwork tool call.
Wherever the brief says to run a command, read a file or run a test, call a tool instead. Paths are
repository-relative (scripts/..., tests/..., data/...).

When the change is finished and run_test passes on the tests it touches, end your reply with ONE fenced code block
that opens with ```text and has DONE on its first line, followed by your final report (markdown): files changed, what
each change does, how you tested, known issues (real problems with the change only), the brief's acceptance-check JSON block, and the
@@CODER_STATUS_START@@ block only if the brief asks for one. I then run the full test suite; if it fails I send you
the failures to fix.

Rules: read_file before edit_file (never guess file contents; copy the search text without line numbers). Never edit
anything under .review/, never touch PNG/art files, keep tabs as tabs in GDScript. Do not weaken, skip or delete
tests. Never leave scratch/debug files behind: delete_file them before DONE. Keep your text brief; no long essays.
If the tools answer "no coding task is running" or fail to connect, say so in one line and stop there.

# Your task
My task for you (THE BRIEF, the lessons, AGENTS.md and the work already in the tree) is in the patchwork get_task tool, so this message stays short. Call get_task(task="main") now (then part=2, 3, ... until a part ends with [end of the task]) and follow it as my instructions; then read the files it names and make the change.


===== REPLY 18:33:31 (5824 chars) =====
Now let me read the full _family_decision_cast in the actual file:
Now let me look at the rules' S15 patch application logic:
Let me check the second modified file for related landed-flag logic:
Now I have the full picture. Let me make the core fix, removing the absence-based flag promotion in _family_attempt:
Now extract the landed oracle into a shared helper. First, replace the tail of _family_decision_cast:
Now add the shared _family_lands oracle function before _family_decisions:
Now add the negative probe. First wire it into _initialize:
Let me verify the edited regions:
All edits are in place. Now run the focused test:
The s14 matrix test passes (3599 checks, 0 failures). Now the named regressions:
All focused tests pass. Let me do a final review of the new probe code:
DONE
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
