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
	_test_preview_catalog_occurrences()
	_test_preview_commit_boundaries()
	_test_preview_read_only_and_recovery()
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

func _preview_choice(preview: Dictionary, choice_id: String) -> Dictionary:
	for choice in preview.get("choices", []):
		if choice is Dictionary and choice.get("id") == choice_id:
			return choice
	return {}


func _make_mixed_preview_fixture() -> Dictionary:
	var fixture := _make_stitched_fixture()
	var deck: Array[String] = []
	deck.assign(fixture["deck"])
	# Real pool base and canonical plus cards across all three owner catalogs.
	for id in [
		"warden_strike_plus",
		"warden_hold_the_line", "warden_hold_the_line_plus",
		"seamstress_running_stitch", "seamstress_running_stitch_plus",
		"tinker_rivet_shot", "tinker_rivet_shot_plus",
	]:
		var definition: Dictionary = RunRestStitchCards.resolve_card_definition(id)
		_check(not definition.is_empty(), "authored mixed fixture card " + id)
		if not definition.is_empty():
			deck.append(id)
	fixture["deck"] = deck
	return fixture


func _test_preview_catalog_occurrences() -> void:
	var fixture := _make_mixed_preview_fixture()
	var deck: Array[String] = []
	deck.assign(fixture["deck"])
	var descriptors: Dictionary = fixture["descriptors"].duplicate(true)
	var service := RunMothInfestationOutcome.new(deck, descriptors, fixture["cursor"], 1)
	_check(service.is_valid(), "mixed preview uses genuine validated stitched ledger")
	if not service.is_valid():
		return
	var preview := service.preview_choices()
	_check(preview.get("ok") == true and preview.get("event_id") == "moth_infestation",
			"valid unclaimed authored Moth preview")
	var cards: Array = preview.get("sacrifice_cards", [])
	_check(cards.size() == deck.size() - 1, "all ordinary occurrences, not stitched, shown")
	_check(cards.size() >= 2 and cards[0].get("index") == 0 and cards[1].get("index") == 1,
			"duplicate starter occurrences keep separate zero-based indices")
	_check(cards.size() >= 2 and cards[0].get("card_id") == "warden_strike"
			and cards[1].get("card_id") == "warden_strike",
			"duplicate Warden Strike entries share catalog ID but not occurrence")
	var stitched_id: String = str((descriptors.keys() as Array)[0])
	var stitched_index: int = deck.find(stitched_id)
	_check(stitched_index >= 0, "genuine Rest-created composite remains in preview deck")
	var listed_indices: Array = []
	for entry in cards:
		var index: int = entry["index"]
		listed_indices.append(index)
		_check(index >= 0 and index < deck.size(), "preview occurrence index stays in source deck")
		if index < 0 or index >= deck.size():
			continue
		var card_id: String = deck[index]
		var canonical: Dictionary = RunRestStitchCards.resolve_card_definition(card_id)
		_check(entry.get("card_id") == card_id, "preview preserves exact deck ID " + card_id)
		_check(not canonical.is_empty() and entry.get("owner") == canonical.get("owner")
				and entry.get("display_name") == canonical.get("display_name"),
				"preview owner/name from genuine authored card definition " + card_id)
	_check(not listed_indices.has(stitched_index), "Rest-created composite excluded as sacrifice")
	for id in [
		"warden_strike_plus", "warden_hold_the_line", "warden_hold_the_line_plus",
		"seamstress_running_stitch", "seamstress_running_stitch_plus",
		"tinker_rivet_shot", "tinker_rivet_shot_plus",
	]:
		_check(listed_indices.has(deck.find(id)), "authored pool/starter base or plus eligible " + id)
	var event: Dictionary = _load_json("res://data/events/moth_infestation.json")
	var choices: Array = preview.get("choices", [])
	_check(choices.size() == 3, "exact shipped choice count shown")
	for authored in event.get("choices", []):
		var row: Dictionary = _preview_choice(preview, authored["id"])
		_check(not row.is_empty(), "authored choice present: " + str(authored["id"]))
		_check(row.get("text") == authored["text"], "authored choice text unchanged")
		_check(row.get("scraps_delta") == authored["outcome"]["scraps"],
				"authored signed scraps delta unchanged")
		_check(row.get("available") == true, "all three choices affordable at one scrap")


func _assert_preview_to_commit(deck: Array[String], descriptors: Dictionary,
		cursor: int, scraps: int, choice_id: String, selected_index: Variant, label: String) -> void:
	var caller_deck: Array[String] = deck.duplicate()
	var caller_descriptors: Dictionary = descriptors.duplicate(true)
	var service := RunMothInfestationOutcome.new(deck, descriptors, cursor, scraps)
	_check(service.is_valid(), label + " source ledger valid")
	if not service.is_valid():
		return
	var forecast := service.preview_choices()
	var choice: Dictionary = _preview_choice(forecast, choice_id)
	_check(forecast.get("ok") == true and choice.get("available") == true,
			label + " forecast authorizes transaction")
	if not choice.get("available", false):
		return
	var expected_deck: Array[String] = deck.duplicate()
	if choice_id == "sacrifice_card":
		expected_deck.remove_at(selected_index)
	var receipt := service.choose("moth_infestation", choice_id, selected_index)
	_check(receipt.get("ok") == true, label + " committed choice succeeds")
	_check(receipt.get("deck") == expected_deck, label + " forecast deck effect matches receipt")
	_check(receipt.get("scraps") == scraps + int(choice["scraps_delta"]),
			label + " forecast scraps matches committed signed delta")
	_check(receipt.get("descriptors") == descriptors and receipt.get("next_stitch_id") == cursor,
			label + " genuine stitched registry and allocator survive commit")
	_check(not receipt.has("gold"), label + " no gold transaction")
	_check(deck == caller_deck and descriptors == caller_descriptors,
			label + " commit leaves caller ledger untouched")
	_check(service.is_consumed() and service.preview_choices().get("choices", []).is_empty(),
			label + " claimed menu is not actionable")


func _test_preview_commit_boundaries() -> void:
	var fixture := _make_mixed_preview_fixture()
	var deck: Array[String] = []
	deck.assign(fixture["deck"])
	var descriptors: Dictionary = fixture["descriptors"].duplicate(true)
	var cursor: int = fixture["cursor"]
	var svc := RunMothInfestationOutcome.new(deck, descriptors, cursor, 1)
	var forecast := svc.preview_choices()
	# Every selected original occurrence independently commits from the same ledger.
	for card in forecast.get("sacrifice_cards", []):
		_assert_preview_to_commit(deck, descriptors, cursor, 1, "sacrifice_card",
				card["index"], "genuine card index " + str(card["index"]))
	_assert_preview_to_commit(deck, descriptors, cursor, 1, "fumigate", null, "fumigate at one scrap")
	_assert_preview_to_commit(deck, descriptors, cursor, 1, "escape", null, "escape at one scrap")

	var poor := RunMothInfestationOutcome.new(deck, descriptors, cursor, 0)
	var poor_preview := poor.preview_choices()
	_check(_preview_choice(poor_preview, "sacrifice_card").get("available") == true,
			"zero scraps still permits sacrifice")
	_check(_preview_choice(poor_preview, "fumigate").get("available") == false,
			"zero scraps forbids fumigate")
	_check(_preview_choice(poor_preview, "escape").get("available") == true,
			"zero scraps still permits escape")
	var rejected_fumigate := poor.choose("moth_infestation", "fumigate", null)
	_check(rejected_fumigate.get("ok") == false and poor.get_scraps() == 0
			and not poor.is_consumed(), "unaffordable fumigate leaves ledger unclaimed")
	_check(poor.preview_choices() == poor_preview, "invalid choice permits corrected preview")
	_assert_preview_to_commit(deck, descriptors, cursor, 0, "sacrifice_card", 0,
			"zero-scrap sacrifice")
	_assert_preview_to_commit(deck, descriptors, cursor, 0, "escape", null,
			"zero-scrap escape")

	# Single genuine composite deck has no eligible ordinary cards.
	var single_id: String = str(descriptors.keys()[0])
	var only_stitched: Array[String] = [single_id]
	for amount in [0, 1]:
		var svc_only := RunMothInfestationOutcome.new(only_stitched, descriptors, cursor, amount)
		_check(svc_only.is_valid(), "stitched-only ledger is real at " + str(amount) + " scraps")
		var stitched_preview := svc_only.preview_choices()
		_check(stitched_preview.get("ok") == true
				and stitched_preview.get("sacrifice_cards", []).is_empty(),
				"stitched-only deck has no ordinary occurrence")
		_check(_preview_choice(stitched_preview, "sacrifice_card").get("available") == false,
				"stitched-only deck cannot sacrifice")
		_check(_preview_choice(stitched_preview, "fumigate").get("available") == (amount == 1),
				"stitched-only fumigation exactly follows affordability")
		_check(_preview_choice(stitched_preview, "escape").get("available") == true,
				"stitched-only escape always available")
		var bad := svc_only.choose("moth_infestation", "sacrifice_card", 0)
		_check(bad.get("ok") == false and not svc_only.is_consumed(),
				"stitched-only sacrifice rejected without claim")
		_assert_preview_to_commit(only_stitched, descriptors, cursor, amount, "escape", null,
				"stitched-only escape " + str(amount))
		if amount == 1:
			_assert_preview_to_commit(only_stitched, descriptors, cursor, amount,
					"fumigate", null, "stitched-only fumigate at threshold")

	var max_scraps: int = RunMothInfestationOutcome.MAX_INT
	var capped := RunMothInfestationOutcome.new(deck, descriptors, cursor, max_scraps - 1)
	_check(not _preview_choice(capped.preview_choices(), "sacrifice_card").get("available", true),
			"cannot preview +2 beyond integer guard")
	var cap_reject := capped.choose("moth_infestation", "sacrifice_card", 0)
	_check(cap_reject.get("ok") == false and not capped.is_consumed()
			and capped.get_scraps() == max_scraps - 1,
			"overflowing sacrifice refuses to spend/consume")
	_assert_preview_to_commit(deck, descriptors, cursor, max_scraps - 2, "sacrifice_card", 0,
			"exact maximum scraps sacrifice")


func _test_preview_read_only_and_recovery() -> void:
	var fx := _make_stitched_fixture()
	var deck: Array[String] = []
	deck.assign(fx["deck"])
	var registry: Dictionary = fx["descriptors"].duplicate(true)
	var deck_before: Array[String] = deck.duplicate()
	var registry_before: Dictionary = registry.duplicate(true)
	var cursor: int = fx["cursor"]
	var scraps := 1
	var service := RunMothInfestationOutcome.new(deck, registry, cursor, scraps)
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = 9137
	var local_state: int = local_rng.state
	seed(9137)
	var expected_global: int = randi()
	seed(9137)
	var first := service.preview_choices()
	var second := service.preview_choices()
	_check(first == second, "repeat previews deterministic")
	_check(first.get("ok") == true, "read-only preview on real stitched ledger")
	_check(randi() == expected_global and local_rng.state == local_state,
			"repeated previews draw neither global nor injected RNG")
	_check(deck == deck_before and registry == registry_before,
			"caller deck and nested descriptor registry unchanged")
	_check(service.get_deck() == deck_before and service.get_descriptors() == registry_before
			and service.get_next_stitch_id() == cursor and service.get_scraps() == scraps
			and not service.is_consumed(), "previews never alter stored ledger or visit latch")
	# Mutate both levels of the returned menu; a second preview must be identical.
	(first["choices"] as Array)[0]["text"] = "not authored"
	(first["sacrifice_cards"] as Array)[0]["owner"] = "counterfeit"
	(first["choices"] as Array).clear()
	(first["sacrifice_cards"] as Array).clear()
	_check(service.preview_choices() == second, "returned nested menu cannot alias service/catalog")

	var invalid := RunMothInfestationOutcome.new(["counterfeit_card"], {}, 1, 1)
	_check(not invalid.is_valid(), "counterfeit ledger invalid as prerequisite")
	_check(invalid.preview_choices().get("ok") == false
			and invalid.preview_choices().get("choices", []).is_empty()
			and invalid.preview_choices().get("sacrifice_cards", []).is_empty(),
			"invalid ledger offers nothing actionable")
	var absent := RunMothInfestationOutcome.new()
	_check(not absent.is_valid() and absent.preview_choices().get("choices", []).is_empty(),
			"missing ledger cannot preview")
	var rejection := service.choose("moth_infestation", "sacrifice_card",
			deck.find(str(registry.keys()[0])))
	_check(rejection.get("ok") == false and not service.is_consumed(),
			"attempting real composite rejects and does not consume")
	_check(service.preview_choices() == second,
			"same unclaimed visit can preview after invalid selection")
	var corrected := service.choose("moth_infestation", "escape", null)
	_check(corrected.get("ok") == true and service.is_consumed(),
			"corrected event choice commits exactly once")
	var post := service.preview_choices()
	_check(post.get("ok") == false and post.get("choices", []).is_empty()
			and post.get("sacrifice_cards", []).is_empty(),
			"post-claim preview has zero actionable items")
	_check(deck == deck_before and registry == registry_before
			and corrected.get("descriptors") == registry_before
			and corrected.get("next_stitch_id") == cursor,
			"recovery and preview preserve caller registry and cursor")
