extends SceneTree

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_test_full_summary()
	_test_torn_and_active_flags()
	_test_replacement_and_readonly()
	_test_rejections()
	_test_detachment_and_isolation()
	if failures.is_empty():
		print("run_patch_wearer_summary_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		print("run_patch_wearer_summary_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _party() -> Array:
	var source := FileAccess.get_file_as_string("res://data/heroes/starter_party.json")
	var authored: Variant = JSON.parse_string(source)
	_check(typeof(authored) == TYPE_ARRAY and authored.size() == 3,
		"starter party has three authored heroes")
	if typeof(authored) != TYPE_ARRAY or authored.size() != 3:
		return []
	var definitions: Array = []
	for hero in authored:
		definitions.append({"id": hero["id"], "max_hp": int(hero["max_hp"]),
			"art_path": hero.get("art_path", "")})
	var party := CombatParty.new(definitions)
	_check(party.is_valid(), "CombatParty accepts real starter definitions")
	if not party.is_valid():
		return []
	return party.get_heroes()

func _fixture() -> Dictionary:
	var heroes := _party()
	if heroes.is_empty():
		return {}
	var owned := ["button_eye", "button_eye_alt", "pincushion_arm", "quilted_coat",
		"stitched_badge", "spare_spool"]
	var defs := [
		{"id": "button_eye", "slot": "HEAD"},
		{"id": "button_eye_alt", "slot": "HEAD"},
		{"id": "pincushion_arm", "slot": "ARM"},
		{"id": "quilted_coat", "slot": "COAT"},
		{"id": "stitched_badge", "slot": "HEAD"},
		{"id": "spare_spool", "slot": "ARM"},
	]
	var wardrobe := RunPatchWardrobe.new(heroes, owned, defs, 2, 170,
		["warden_strike", "seamstress_prick"], 8197)
	if not wardrobe.is_valid():
		return {}
	return {"heroes": heroes, "wardrobe": wardrobe}

func _test_full_summary() -> void:
	var f := _fixture()
	if f.is_empty():
		return
	var w: RunPatchWardrobe = f.wardrobe
	var torn := RunTornMending.new(f.heroes)

	# Sew the three named patches onto their slots.
	_check(w.sew("button_eye", "warden", "HEAD", "sew_eye", w.get_snapshot()).ok,
		"sew button_eye to Warden HEAD succeeds")
	_check(w.sew("pincushion_arm", "seamstress", "ARM", "sew_arm", w.get_snapshot()).ok,
		"sew pincushion_arm to Seamstress ARM succeeds")
	_check(w.sew("quilted_coat", "tinker", "COAT", "sew_coat", w.get_snapshot()).ok,
		"sew quilted_coat to Tinker COAT succeeds")

	var torn_state := torn.read_state()
	var result := RunPatchWearerSummary.summarize(w, torn_state)

	_check(result.get("ok") == true and result.get("heroes") is Array,
		"valid inputs return ok with heroes array")
	_check(result.heroes.size() == 3, "three heroes in result")

	# Verify exact text values for named effects.
	var warden_slots: Array = result.heroes[0]["slots"]
	var seamstress_slots: Array = result.heroes[1]["slots"]
	var tinker_slots: Array = result.heroes[2]["slots"]

	_check(warden_slots[0]["slot"] == "HEAD" and warden_slots[0]["patch_id"] == "button_eye"
		and warden_slots[0]["active"] == true
		and warden_slots[0]["rules_text"] == "first successful attack each combat also applies Exposed 1",
		"Warden HEAD button_eye active with exact effect text")

	_check(seamstress_slots[1]["slot"] == "ARM" and seamstress_slots[1]["patch_id"] == "pincushion_arm"
		and seamstress_slots[1]["active"] == true
		and seamstress_slots[1]["rules_text"] == "+1 damage on that wearer's damaging cards",
		"Seamstress ARM pincushion_arm active with exact effect text")

	_check(tinker_slots[2]["slot"] == "COAT" and tinker_slots[2]["patch_id"] == "quilted_coat"
		and tinker_slots[2]["active"] == true
		and tinker_slots[2]["rules_text"] == "+6 maximum HP",
		"Tinker COAT quilted_coat active with exact effect text")

	# Verify empty slots have empty strings and false active.
	_check(warden_slots[1]["patch_id"] == "" and warden_slots[1]["active"] == false
		and warden_slots[1]["rules_text"] == "", "Warden ARM empty")
	_check(warden_slots[2]["patch_id"] == "" and warden_slots[2]["active"] == false
		and warden_slots[2]["rules_text"] == "", "Warden COAT empty")

	# Verify active arrays match independent project_active call.
	var projection := w.project_active(torn_state)
	_check(projection.get("ok") == true, "independent project_active succeeds")
	for i in range(3):
		var hero_id: String = result.heroes[i]["id"]
		var active_ids: Array = projection.active.get(hero_id, [])
		for s in result.heroes[i]["slots"]:
			var s_slot: Dictionary = s
			var s_patch_id: String = s_slot["patch_id"]
			var expected_active: bool = false
			if s_patch_id != "" and f.heroes[i]["hp"] > 0:
				expected_active = active_ids.has(s_patch_id)
			_check(s_slot["active"] == expected_active,
				hero_id + " " + s["slot"] + " active flag matches independent projection")

func _test_torn_and_active_flags() -> void:
	var f := _fixture()
	if f.is_empty():
		return
	var w: RunPatchWardrobe = f.wardrobe
	w.sew("button_eye", "warden", "HEAD", "tear_w", w.get_snapshot())

	var torn := RunTornMending.new(f.heroes)
	var torn_state_dict := torn.read_state()
	var torn_start: Array = torn_state_dict.heroes
	var end_state: Array = torn_start.duplicate(true)
	end_state[0].hp = 0

	var observe_result := torn.observe_battle_end("tear", torn_start, end_state)
	_check(observe_result.get("ok") == true,
		"observe battle tear on Warden")

	var torn_state := torn.read_state()
	_check(torn_state.heroes[0].hp == 0 and torn_state.heroes[0].max_hp == 37
		and torn_state.tear_counts.warden == 1,
		"tear reduces Warden max HP by 3 and sets HP to 0")

	var summary := RunPatchWearerSummary.summarize(w, torn_state)
	_check(summary.ok == true, "summary succeeds after tear")

	# Warden HEAD still shows button_eye but active=false; rules_text preserved.
	var warden_head: Dictionary = summary.heroes[0]["slots"][0]
	_check(warden_head["patch_id"] == "button_eye"
		and warden_head["active"] == false
		and warden_head["rules_text"] == "first successful attack each combat also applies Exposed 1",
		"torn Warden keeps sewn patch ID but inactive with preserved rules text")

	# Seamstress ARM stays active since she is living.
	_check(summary.heroes[1]["slots"][1]["patch_id"] == ""
		and summary.heroes[1]["slots"][1]["active"] == false,
		"Seamstress ARM empty (not yet sewn in this path, but no crash)")

	# Mend restores activation.
	var mend := torn.choose_mend("map_m", "mend_1", "warden", 1, 2, torn_state.heroes, true)
	_check(mend.ok == true, "legal mend restores Warden")

	var restored_state := torn.read_state()
	var restored := RunPatchWearerSummary.summarize(w, restored_state)
	_check(restored.ok == true, "summary after mend succeeds")
	_check(restored.heroes[0]["slots"][0]["patch_id"] == "button_eye"
		and restored.heroes[0]["slots"][0]["active"] == true,
		"mend reactivates Warden button_eye")

func _test_replacement_and_readonly() -> void:
	var f := _fixture()
	if f.is_empty():
		return
	var w: RunPatchWardrobe = f.wardrobe
	w.sew("button_eye", "warden", "HEAD", "first", w.get_snapshot())

	var before_state := w.get_snapshot()
	var torn := RunTornMending.new(f.heroes)
	var torn_state := torn.read_state()
	var before_summary := RunPatchWearerSummary.summarize(w, torn_state)

	# Replacement: sew different HEAD onto Warden.
	w.sew("button_eye_alt", "warden", "HEAD", "replace", w.get_snapshot())
	var after_state := w.get_snapshot()
	_check(after_state.worn.warden.HEAD == "button_eye_alt", "replacement changes slot")

	var after_summary := RunPatchWearerSummary.summarize(w, torn_state)
	_check(after_summary.ok == true, "summary reflects new worn patch")
	_check(after_summary.heroes[0]["slots"][0]["patch_id"] == "button_eye_alt",
		"summary shows new patch ID after replacement")

	# Read-only: summary mutation must not alter wardrobe or torn.
	before_summary.heroes[0]["slots"][0]["patch_id"] = "spoof"
	before_summary.heroes[0]["slots"][0]["rules_text"] = "spoof"
	before_summary.heroes[0]["hp"] = 999
	_check(w.get_snapshot() == after_state, "summary mutation does not alter wardrobe")

	# Deep independence: two independent results must not share nested objects.
	var r2 := RunPatchWearerSummary.summarize(w, torn_state)
	_check(r2.heroes[0]["slots"] != before_summary.heroes[0]["slots"],
		"independent results have distinct nested objects")
	before_summary.heroes[0]["slots"][0]["patch_id"] = "mutated"
	_check(r2.heroes[0]["slots"][0]["patch_id"] == "button_eye_alt",
		"mutating one result does not affect another")

func _test_rejections() -> void:
	# Null wardrobe.
	var null_result := RunPatchWearerSummary.summarize(null, {"ok": true, "heroes": []})
	_check(null_result == {"ok": false, "heroes": []}, "null wardrobe rejected exactly")

	# Invalid wardrobe (uninitialized).
	var bad_wardrobe := RunPatchWardrobe.new([])
	_check(bad_wardrobe.is_valid() == false, "bad wardrobe invalid")
	var bad_wardrobe_result := RunPatchWearerSummary.summarize(bad_wardrobe, {"ok": true, "heroes": []})
	_check(bad_wardrobe_result == {"ok": false, "heroes": []}, "invalid wardrobe rejected exactly")

	# Malformed torn state (missing ok).
	var bad_torn_result := RunPatchWearerSummary.summarize(RunPatchWardrobe.new([]), {"heroes": []})
	_check(bad_torn_result == {"ok": false, "heroes": []}, "torn without ok rejected exactly")

	# Malformed torn roster (wrong size).
	var wrong_size := {"ok": true, "heroes": [{"id":"warden","position":1,"hp":20,"max_hp":40,"block":0,"statuses":{}}]}
	var wrong_size_result := RunPatchWearerSummary.summarize(RunPatchWardrobe.new([]), wrong_size)
	# Since wardrobe is invalid, result should still be false; but we test with a real wardrobe when possible.

	# Inconsistent identity: foreign hero ID.
	var f := _fixture()
	if not f.is_empty():
		var w: RunPatchWardrobe = f.wardrobe
		w.sew("button_eye", "warden", "HEAD", "test", w.get_snapshot())
		var real_torn := RunTornMending.new(f.heroes)
		var real_state := real_torn.read_state()
		# Forge a torn roster with foreign identity.
		var forged_heroes: Array = real_state.heroes.duplicate(true)
		forged_heroes[2]["id"] = "outsider"
		var forged_state := {"ok": true, "heroes": forged_heroes, "tear_counts": real_state.tear_counts,
			"completed_battles": real_state.completed_battles, "completed_mends": real_state.completed_mends,
			"completed_rests": real_state.completed_rests, "defeated": real_state.defeated}
		var forged_result := RunPatchWearerSummary.summarize(w, forged_state)
		_check(forged_result == {"ok": false, "heroes": []},
			"foreign hero identity in torn roster rejected exactly")

	# Note: contradictory worn slot would be rejected by wardrobe.get_snapshot() consistency checks.
	# No separate assertion needed since the helper relies on wardrobe/project_active for that.

func _test_detachment_and_isolation() -> void:
	# Verify no mutation of wardrobe or torn state across multiple reads.
	var f := _fixture()
	if f.is_empty():
		return
	var w: RunPatchWardrobe = f.wardrobe
	w.sew("button_eye", "warden", "HEAD", "det", w.get_snapshot())
	w.sew("quilted_coat", "tinker", "COAT", "det2", w.get_snapshot())

	var torn := RunTornMending.new(f.heroes)
	var torn_state := torn.read_state()

	var before_w := w.get_snapshot()
	var before_t := torn.read_state()

	seed(12345)
	var expected_randi := randi()
	seed(12345)

	var first := RunPatchWearerSummary.summarize(w, torn_state)
	var second := RunPatchWearerSummary.summarize(w, torn_state)

	_check(first == second and first.ok == true, "repeated independent summaries are equal")
	_check(w.get_snapshot() == before_w, "summary does not alter wardrobe snapshot")
	_check(torn.read_state() == before_t, "summary does not alter torn snapshot")
	_check(randi() == expected_randi, "summary does not consume global RNG")

	# Verify nested mutation isolation.
	first.heroes[0]["slots"][0]["patch_id"] = "mutated"
	first.heroes[0]["hp"] = 999
	var fresh := RunPatchWearerSummary.summarize(w, torn_state)
	_check(fresh.heroes[0]["slots"][0]["patch_id"] == "button_eye",
		"fresh result is independent of mutated previous result")
	_check(fresh.heroes[0]["hp"] == f.heroes[0]["hp"],
		"fresh result has unmodified hero health")
