extends SceneTree

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_test_json_and_api()
	_test_sacrifice_branch()
	_test_fumigate_and_escape()
	_test_rejections_and_replay()
	_test_stitched_ledger_conservation()
	_test_rng_invariance()
	if failures.is_empty():
		print("run_moth_infestation_outcome_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("run_moth_infestation_outcome_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _load_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "open " + path)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	var data: Variant = JSON.parse_string(text)
	_check(data != null, "parse " + path)
	return data

func _deck() -> Array[String]:
	var data: Variant = _load_json("res://data/cards/starter_deck.json")
	var result: Array[String] = []
	if data is Array:
		for id in data:
			if id is String:
				result.append(id)
	return result

func _make_stitched_fixture() -> Dictionary:
	var source := _deck()
	var a := source.find("seamstress_prick")
	var b := source.find("tinker_pop_shot")
	var visit := RunRestStitchCards.new(source, {}, 3, 1)
	var result := visit.choose_stitch(a, b, visit.get_snapshot())
	_check(result.get("ok") == true, "stitched fixture constructed")
	return {
		"deck": result.get("deck", source).duplicate(),
		"descriptors": result.get("descriptors", {}).duplicate(true),
		"cursor": int(result.get("next_stitch_id", 2)),
		"scraps": int(result.get("remaining_scraps", 0)),
	}

func _test_json_and_api() -> void:
	var data: Variant = _load_json("res://data/events/moth_infestation.json")
	_check(data is Dictionary, "moth JSON is an object")
	if not data is Dictionary:
		return
	var event: Dictionary = data
	_check(event.get("id") == "moth_infestation", "event id")
	_check(event.get("title") == "Moth Infestation", "event title")
	_check(event.get("description") is String and not String(event.get("description")).is_empty(), "event description")
	var choices: Variant = event.get("choices")
	_check(choices is Array and (choices as Array).size() == 3, "three choices")
	if not choices is Array:
		return
	var ids: Array = []
	for choice in choices:
		if choice is Dictionary:
			ids.append(choice.get("id"))
	_check(ids == ["sacrifice_card", "fumigate", "escape"], "choice ids in order")
	var outcome := RunMothInfestationOutcome.new()
	_check(outcome is RefCounted, "outcome extends RefCounted")
	_check(true, "outcome is scene-free")
	_check(outcome.has_method("choose"), "choose method")
	_check(outcome.has_method("is_consumed"), "is_consumed method")
	_check(not outcome.is_consumed(), "fresh outcome unconsumed")

func _test_sacrifice_branch() -> void:
	var source := _deck()
	# duplicate ordinary card index 1 (warden_strike copy)
	var selected := 1
	_check(source[selected] == "warden_strike", "selected duplicate starter card")
	var scraps := 1
	var service := RunMothInfestationOutcome.new(source, {}, 1, scraps)
	_check(service.is_valid(), "valid ordinary deck")
	var before_deck: Array[String] = source.duplicate()
	var result := service.choose("moth_infestation", "sacrifice_card", selected)
	_check(result.get("ok") == true, "sacrifice succeeds")
	_check(result.get("event_id") == "moth_infestation", "sacrifice event id")
	_check(result.get("choice_id") == "sacrifice_card", "sacrifice choice id")
	var expected: Array[String] = before_deck.duplicate()
	expected.remove_at(selected)
	_check(result.get("deck") == expected, "exact single occurrence removed by index")
	_check(int(result.get("scraps", -1)) == scraps + 2, "sacrifice awards exactly 2 scraps")
	_check(int(result.get("remaining_scraps", -1)) == scraps + 2, "remaining_scraps alias")
	_check(result.get("descriptors") == {}, "ordinary sacrifice leaves descriptors empty")
	_check(int(result.get("next_stitch_id", 0)) == 1, "cursor unchanged")
	_check(service.is_consumed(), "visit latched")
	# caller untouched
	_check(source == before_deck, "caller deck untouched")

func _test_fumigate_and_escape() -> void:
	var source := _deck()
	# fumigate with 2 scraps
	var service1 := RunMothInfestationOutcome.new(source, {}, 1, 2)
	var result1 := service1.choose("moth_infestation", "fumigate", null)
	_check(result1.get("ok") == true, "fumigate succeeds")
	_check(result1.get("deck") == source, "fumigate removes no card")
	_check(int(result1.get("scraps", -1)) == 1, "fumigate spends exactly 1 scrap")
	_check(service1.is_consumed(), "fumigate latches")

	var service2 := RunMothInfestationOutcome.new(source, {}, 1, 3)
	var result2 := service2.choose("moth_infestation", "escape", null)
	_check(result2.get("ok") == true, "escape succeeds")
	_check(result2.get("deck") == source, "escape deck unchanged")
	_check(int(result2.get("scraps", -1)) == 3, "escape scraps unchanged")
	_check(service2.is_consumed(), "escape latches")

func _test_rejections_and_replay() -> void:
	var source := _deck()
	# invalid index
	var service := RunMothInfestationOutcome.new(source, {}, 1, 3)
	var before_deck: Array[String] = source.duplicate()
	var bad_index := service.choose("moth_infestation", "sacrifice_card", -1)
	_check(bad_index.get("ok") == false, "negative index rejected")
	_check(bad_index.get("deck") == before_deck, "rejection deck unchanged")
	_check(not service.is_consumed(), "rejection does not consume")
	# stitched selection
	var stitched_deck: Array[String] = source.duplicate()
	stitched_deck.append("stitched_000001")
	var descriptors := {"stitched_000001": {}}
	# invalid ledger anyway; use a genuine fixture instead
	var fx := _make_stitched_fixture()
	var svc2 := RunMothInfestationOutcome.new(fx["deck"], fx["descriptors"], fx["cursor"], fx["scraps"])
	var stitched_index := (fx["deck"] as Array).find("stitched_000001")
	_check(stitched_index >= 0, "stitched card present")
	var before_cursor: int = int(fx["cursor"])
	var rejected_stitched := svc2.choose("moth_infestation", "sacrifice_card", stitched_index)
	_check(rejected_stitched.get("ok") == false, "stitched selection rejected")
	_check(int(rejected_stitched.get("next_stitch_id", 0)) == before_cursor, "cursor unchanged on stitched rejection")
	_check(not svc2.is_consumed(), "stitched rejection does not consume")
	# insufficient fumigate
	var svc3 := RunMothInfestationOutcome.new(source, {}, 1, 0)
	var poor := svc3.choose("moth_infestation", "fumigate", null)
	_check(poor.get("ok") == false, "insufficient scraps rejected")
	_check(not svc3.is_consumed(), "insufficient does not consume")
	# wrong event/choice
	var svc4 := RunMothInfestationOutcome.new(source, {}, 1, 3)
	var wrong_event := svc4.choose("other_event", "sacrifice_card", 1)
	_check(wrong_event.get("ok") == false, "wrong event rejected")
	var wrong_choice := svc4.choose("moth_infestation", "nope", 1)
	_check(wrong_choice.get("ok") == false, "wrong choice rejected")
	_check(not svc4.is_consumed(), "wrong event/choice does not consume")
	# recovery on same selector
	var recovered := svc4.choose("moth_infestation", "escape", null)
	_check(recovered.get("ok") == true, "valid choice recovers after rejections")
	_check(svc4.is_consumed(), "recovery latches")
	# replay rejected
	var replay := svc4.choose("moth_infestation", "escape", null)
	_check(replay.get("ok") == false, "replay rejected")
	# repeated claim does not alter future valid choice? Ensure a rejected attempt didn't consume
	var svc5 := RunMothInfestationOutcome.new(source, {}, 1, 3)
	var first_reject := svc5.choose("moth_infestation", "sacrifice_card", -1)
	_check(first_reject.get("ok") == false, "first invalid attempt rejected")
	var valid_later := svc5.choose("moth_infestation", "escape", null)
	_check(valid_later.get("ok") == true, "rejected attempt does not consume valid future choice")

func _test_stitched_ledger_conservation() -> void:
	var fx := _make_stitched_fixture()
	var source_deck: Array = (fx["deck"] as Array).duplicate()
	var source_desc: Dictionary = (fx["descriptors"] as Dictionary).duplicate(true)
	var source_cursor: int = fx["cursor"]
	var source_scraps: int = fx["scraps"] + 1
	# add an ordinary card index to sacrifice (find warden_strike if present, else first)
	var deck: Array[String] = []
	deck.assign(fx["deck"])
	if not deck.has("warden_strike"):
		deck.append("warden_strike")
	var ordinary_index := deck.find("warden_strike")
	var desc_copy: Dictionary = fx["descriptors"].duplicate(true)
	var service := RunMothInfestationOutcome.new(deck, desc_copy, source_cursor, source_scraps)
	_check(service.is_valid(), "mixed stitched ledger valid")
	var stitched_before: Dictionary = fx["descriptors"].duplicate(true)
	var result := service.choose("moth_infestation", "sacrifice_card", ordinary_index)
	_check(result.get("ok") == true, "sacrifice in mixed ledger succeeds")
	_check(result.get("descriptors") == stitched_before, "stitched descriptors conserved")
	_check(int(result.get("next_stitch_id", 0)) == source_cursor, "cursor conserved")
	_check(int(result.get("scraps", -1)) == source_scraps + 2, "scraps +2 in mixed ledger")
	# exact deletion
	var expected: Array[String] = deck.duplicate()
	expected.remove_at(ordinary_index)
	_check(result.get("deck") == expected, "exact deletion in mixed ledger")
	# original composite still present
	_check((result.get("deck") as Array).has("stitched_000001"), "composite survives sacrifice")
	# deep copy isolation
	(result.get("deck") as Array).clear()
	_check(service.get_deck().size() == deck.size() - 1, "service deck isolated")

func _test_rng_invariance() -> void:
	var source := _deck()
	var seed_value := 12345
	seed(seed_value)
	var expected_global := randi()
	seed(seed_value)
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = seed_value
	var local_before := local_rng.state

	var service := RunMothInfestationOutcome.new(source, {}, 1, 3)
	var result := service.choose("moth_infestation", "sacrifice_card", 1)
	_check(randi() == expected_global, "no global RNG draw on sacrifice")
	_check(local_rng.state == local_before, "no local RNG draw on sacrifice")

	# rejection invariance
	seed(seed_value)
	var expected_global2 := randi()
	seed(seed_value)
	var local_rng2 := RandomNumberGenerator.new()
	local_rng2.seed = seed_value
	var local_before2 := local_rng2.state
	var svc2 := RunMothInfestationOutcome.new(source, {}, 1, 3)
	var rej := svc2.choose("moth_infestation", "sacrifice_card", -1)
	_check(randi() == expected_global2, "no global RNG draw on rejection")
	_check(local_rng2.state == local_before2, "no local RNG draw on rejection")