extends SceneTree
## Walk feedback is a plain sentence: every event kind reads without ids, braces or underscores.
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	var dolls := [{"id": "warden", "name": "Warden"}, {"id": "lantern_monk", "name": "Lantern Monk"}]
	var events := [
		{"kind": "tug_torn", "source": "thread_tug", "target": "lantern_monk", "slot": "head",
			"part": {"id": "lantern_monk_head_moth_wink", "tier": 1, "torn": true}},
		{"kind": "tug_saved", "source": "thread_tug", "actor": "warden", "item": "spare_spool"},
		{"kind": "tug_no_part", "source": "thread_tug"}, {"kind": "mimic_removed", "target": "mimic_1"},
		{"kind": "wrong_snip", "target": "warden", "fray": 20}, {"kind": "mimic_pending"},
		{"kind": "mannequins_stage", "source": "m"}, {"kind": "mannequins_pending", "source": "m"},
		{"kind": "shadow_revealed", "shadow": {}, "targets": []}, {"kind": "heal", "target": "warden", "amount": 4},
		{"kind": "whirr_warning"}, {"kind": "machine_pending"}, {"kind": "dummy_inspected", "source": "c1"},
		{"kind": "curio_choice", "source": "c1", "choice": "reach_in", "resolved": true}]
	for event in events:
		var line := StitchedWalkScreen.describe("forward", {}, {"ok": true, "events": [event]}, dolls)
		_check(not line.is_empty() and not "{" in line and not "_" in line, "%s reads plainly: %s" % [event.kind, line])
	_check(StitchedWalkScreen.describe("forward", {}, {"ok": true, "events": [events[0]]}, dolls).contains("Lantern Monk"),
		"a torn part names the doll")
	_check(StitchedWalkScreen.describe("switch", {"target": "warden"}, {"ok": true, "events": []}, dolls)
		== "You borrow Warden's eyes.", "a quiet switch names the borrowed eyes")
	_check(not "_" in StitchedWalkScreen.describe("snip", {}, {"ok": false, "error": "no_shadow"}, dolls),
		"a refusal reads plainly")
	for failure in failures:
		printerr(failure)
	print("stitched_walk_feedback_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, why: String) -> void:
	checks += 1
	if not ok:
		failures.append(why)
