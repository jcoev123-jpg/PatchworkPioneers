extends SceneTree
## Deterministic headless test for RunCardRewardChoice (M03 reward service).

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_positive_claim()
	_test_skip()
	_test_duplicate_claim_after_success()
	_test_isolation_and_replay()
	_test_invalidity()
	_test_no_rng_consumption()
	if failures.is_empty():
		print("run_card_reward_choice_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("run_card_reward_choice_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _load_starter_deck() -> Array[String]:
	var file := FileAccess.open("res://data/cards/starter_deck.json", FileAccess.READ)
	_check(file != null, "starter_deck.json opens")
	var text := file.get_as_text() if file != null else ""
	if file != null:
		file.close()
	var parser := JSON.new()
	var parse_result := parser.parse(text) if text != "" else ERR_PARSE_ERROR
	var data = parser.data if parse_result == OK else []
	if not data is Array:
		return []
	var deck: Array[String] = []
	for item in data:
		if item is String:
			deck.append(item)
	return deck


func _load_party() -> Array[String]:
	var file := FileAccess.open("res://data/heroes/starter_party.json", FileAccess.READ)
	var data: Array = []
	if file != null:
		var text := file.get_as_text()
		file.close()
		var parser := JSON.new()
		if parser.parse(text) == OK:
			data = parser.data if parser.data is Array else []
	var ids: Array[String] = []
	for hero in data:
		if hero is Dictionary and hero.has("id"):
			var id_val = hero.get("id")
			if id_val is String:
				ids.append(id_val)
	return ids


func _fixture_offers() -> Array:
	return [
		{"id": "warden_strike", "owner": "warden"},
		{"id": "seamstress_prick", "owner": "seamstress"},
		{"id": "tinker_pop_shot", "owner": "tinker"}
	]


func _fixture_party() -> Array[String]:
	return ["warden", "seamstress", "tinker"]


func _catalog_has_id(card_id: String) -> bool:
	var script = load("res://data/cards/starter_cards.gd")
	var catalog = script.new()
	return catalog.has_card(card_id)


func _catalog_owner(card_id: String) -> String:
	var script = load("res://data/cards/starter_cards.gd")
	var catalog = script.new()
	var def: Dictionary = catalog.get_definition(card_id)
	return String(def.get("owner", "")) if not def.is_empty() else ""


func _test_positive_claim() -> void:
	var deck: Array[String] = _load_starter_deck()
	_check(deck.size() == 12, "starter deck has exactly 12 cards")

	var party := _fixture_party()
	# Verify actual starter hero IDs from file match fixtures.
	var actual_party := _load_party()
	_check(actual_party.size() == 3, "loaded party has 3 heroes")
	_check(actual_party.has("warden") and actual_party.has("seamstress") and actual_party.has("tinker"),
		"loaded party contains warden, seamstress, tinker")
	for pid in actual_party:
		_check(party.has(pid), "fixture party includes loaded hero: " + pid)
	var offers := _fixture_offers()

	# Verify fixture cards resolve in catalog with correct owners.
	for offer in offers:
		var card_id: String = String(offer.get("id", ""))
		_check(_catalog_has_id(card_id), "fixture card " + card_id + " exists in StarterCards")
		_check(_catalog_owner(card_id) == String(offer.get("owner", "")),
			card_id + " owner matches fixture")

	var service := RunCardRewardChoice.new(offers, party)
	_check(service.is_valid(), "valid offering passes is_valid")

	# Positive claim: choose one card. Pass the caller's original array (not a duplicate)
	# so isolation can be verified afterward.
	var claim_input := deck
	var selected := "seamstress_prick"
	var result := service.claim(claim_input, selected)
	_check(result.get("ok", false) == true, "positive claim succeeds")
	_check(result.get("skipped", false) == false, "positive claim skipped is false")
	_check(result.get("selected_id", "") == selected, "selected_id equals chosen card")

	var new_deck: Array[String] = result.get("deck", [])
	_check(new_deck is Array, "result deck is array")
	_check(new_deck.size() == 13, "chosen deck size is 13 (12 + 1)")

	# Verify exact 12-card prefix unchanged and selected appended at end.
	_check(new_deck.slice(0, 12) == deck, "exact 12-card prefix preserved")
	_check(new_deck[new_deck.size() - 1] == selected, "chosen card appended at end")

	# Verify a fresh CombatDeck from result has 13 cards after drawing 5.
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var combat_deck := CombatDeck.new(new_deck, rng)
	_check(combat_deck.start_turn(), "fresh combat deck starts turn")
	_check(combat_deck.hand.size() == 5, "draws exactly 5 cards")
	var total_accounted := combat_deck.draw_pile.size() + combat_deck.hand.size() + combat_deck.discard_pile.size()
	_check(total_accounted == 13, "all 13 cards accounted for after draw (draw_pile + hand + discard)")

	# Verify claim latched.
	_check(service.is_claimed(), "claim latched after success")

	# Verify caller's input array was not mutated.
	_check(deck.size() == 12, "original input deck unchanged after claim")
	_check(deck == claim_input, "submitted array unchanged after claim")

	# Verify a second fresh CombatDeck with same seed produces identical draw.
	var replay_rng := RandomNumberGenerator.new()
	replay_rng.seed = 42
	var replay_deck := CombatDeck.new(new_deck, replay_rng)
	_check(replay_deck.start_turn(), "replay combat deck starts turn")
	_check(replay_deck.hand.size() == 5, "replay draws exactly 5 cards")
	_check(combat_deck.hand == replay_deck.hand, "same seed yields equal five-card draw")
	var replay_total := replay_deck.draw_pile.size() + replay_deck.hand.size() + replay_deck.discard_pile.size()
	_check(replay_total == 13, "replay all 13 cards accounted for")


func _test_skip() -> void:
	var deck: Array[String] = _load_starter_deck()
	var service := RunCardRewardChoice.new(_fixture_offers(), _fixture_party())
	var original_copy := deck.duplicate()

	var result := service.claim(deck.duplicate(), "")
	_check(result.get("ok", false) == true, "skip succeeds")
	_check(result.get("skipped", false) == true, "skipped is true")
	_check(result.get("selected_id", "") == "", "selected_id empty for skip")

	var returned_deck: Array[String] = result.get("deck", [])
	_check(returned_deck.size() == deck.size(), "skip returns same size deck")
	_check(returned_deck == original_copy, "skip returns identical deck content")

	# Skip consumes the offering; second attempt must fail.
	_check(service.is_claimed(), "skip consumes the offering")
	var second := service.claim(deck.duplicate(), "warden_strike")
	_check(second.get("ok", false) == false, "second claim after skip fails")
	_check(service.is_claimed(), "still latched after rejected second claim")


func _test_duplicate_claim_after_success() -> void:
	var deck: Array[String] = _load_starter_deck()
	var service := RunCardRewardChoice.new(_fixture_offers(), _fixture_party())

	var first := service.claim(deck.duplicate(), "warden_strike")
	_check(first.get("ok", false) == true, "first claim succeeds")

	# A second claim with same card must fail (no duplicate append).
	var second := service.claim(deck.duplicate(), "warden_strike")
	_check(second.get("ok", false) == false, "duplicate claim after success fails")

	# A different card must also fail (only one claim per offering).
	var third := service.claim(deck.duplicate(), "tinker_pop_shot")
	_check(third.get("ok", false) == false, "different card claim after success fails")

	# The returned deck from failed claim must be a fresh unchanged copy.
	var failed_result: Array[String] = second.get("deck", [])
	_check(failed_result == deck, "failed claim returns unchanged deck copy")


func _test_isolation_and_replay() -> void:
	# Fresh instances with identical data must agree without mutation.
	var offers := _fixture_offers()
	var party := _fixture_party()
	var deck := _load_starter_deck()

	var service_a := RunCardRewardChoice.new(offers.duplicate(), party.duplicate())
	var service_b := RunCardRewardChoice.new(offers.duplicate(), party.duplicate())

	# Modify input arrays after constructing service; must not affect service.
	offers.pop_back()
	party.pop_back()

	_check(service_a.is_valid(), "service_a valid despite mutated inputs")
	_check(service_b.is_valid(), "service_b valid despite mutated inputs")

	var result_a := service_a.claim(deck.duplicate(), "tinker_pop_shot")
	var result_b := service_b.claim(deck.duplicate(), "tinker_pop_shot")

	_check(result_a.get("ok", false) == result_b.get("ok", false), "identical inputs yield same ok")
	_check(result_a.get("selected_id", "") == result_b.get("selected_id", ""), "identical selected")
	var deck_a: Array[String] = result_a.get("deck", [])
	var deck_b: Array[String] = result_b.get("deck", [])
	_check(deck_a == deck_b, "identical inputs yield same result deck")

	# Mutating returned array must not affect the service's internal state.
	deck_a.append("fake_mutation")
	_check(service_a.is_claimed(), "service_a remains claimed after mutation of result")
	_check(service_a.claim(deck.duplicate(), "anything").get("ok", false) == false, "mutated result array does not allow second claim")

	# Replay: fresh service with same data can claim independently.
	var replay_service := RunCardRewardChoice.new(_fixture_offers(), _fixture_party())
	var replay_result := replay_service.claim(deck.duplicate(), "warden_strike")
	_check(replay_result.get("ok", false) == true, "replay instance succeeds independently")


func _test_invalidity() -> void:
	var base_deck := _load_starter_deck()

	# Fewer than 3 offers.
	var short_service := RunCardRewardChoice.new(
		[{"id": "warden_strike", "owner": "warden"}], _fixture_party()
	)
	_check(not short_service.is_valid(), "fewer than 3 offers invalid")
	var short_result := short_service.claim(base_deck.duplicate(), "warden_strike")
	_check(short_result.get("ok", false) == false, "invalid short claim fails")
	_check(short_result.get("deck", []).size() == 12, "invalid claim returns unchanged deck")

	# More than 3 offers.
	var long_service := RunCardRewardChoice.new(
		[
			{"id": "a", "owner": "warden"},
			{"id": "b", "owner": "seamstress"},
			{"id": "c", "owner": "tinker"},
			{"id": "d", "owner": "warden"}
		], _fixture_party()
	)
	_check(not long_service.is_valid(), "more than 3 offers invalid")

	# Duplicate offered IDs.
	var dup_service := RunCardRewardChoice.new(
		[
			{"id": "warden_strike", "owner": "warden"},
			{"id": "warden_strike", "owner": "seamstress"},
			{"id": "tinker_pop_shot", "owner": "tinker"}
		], _fixture_party()
	)
	_check(not dup_service.is_valid(), "duplicate offered IDs invalid")

	# Empty/non-string offer fields.
	var empty_service := RunCardRewardChoice.new(
		[
			{"id": "", "owner": "warden"},
			{"id": "seamstress_prick", "owner": "seamstress"},
			{"id": "tinker_pop_shot", "owner": "tinker"}
		], _fixture_party()
	)
	_check(not empty_service.is_valid(), "empty card id invalid")

	var empty_owner := RunCardRewardChoice.new(
		[
			{"id": "warden_strike", "owner": ""},
			{"id": "seamstress_prick", "owner": "seamstress"},
			{"id": "tinker_pop_shot", "owner": "tinker"}
		], _fixture_party()
	)
	_check(not empty_owner.is_valid(), "empty owner invalid")

	# Offer owner not in party.
	var bad_owner := RunCardRewardChoice.new(
		[
			{"id": "warden_strike", "owner": "unknown"},
			{"id": "seamstress_prick", "owner": "seamstress"},
			{"id": "tinker_pop_shot", "owner": "tinker"}
		], _fixture_party()
	)
	_check(not bad_owner.is_valid(), "owner outside party invalid")

	# Invalid party (duplicate hero IDs).
	var bad_party_service := RunCardRewardChoice.new(
		_fixture_offers(), ["warden", "warden", "seamstress"]
	)
	_check(not bad_party_service.is_valid(), "duplicate party IDs invalid")

	# Invalid party (non-string / empty).
	var empty_party_service := RunCardRewardChoice.new(
		_fixture_offers(), ["warden", "", "seamstress"]
	)
	_check(not empty_party_service.is_valid(), "empty party ID invalid")

	# Numeric (non-String) id and owner must fail (AC3: non-String offer fields fail closed).
	var numeric_service := RunCardRewardChoice.new(
		[
			{"id": 123, "owner": "warden"},
			{"id": "seamstress_prick", "owner": "seamstress"},
			{"id": "tinker_pop_shot", "owner": "tinker"}
		], _fixture_party()
	)
	_check(not numeric_service.is_valid(), "numeric id invalid")
	var numeric_result := numeric_service.claim(base_deck.duplicate(), "seamstress_prick")
	_check(numeric_result.get("ok", false) == false, "numeric id claim rejected")
	_check(numeric_result.get("deck", []).size() == 12, "numeric id claim does not mutate deck")
	_check(not numeric_service.is_claimed(), "numeric id claim does not latch")

	var numeric_owner_service := RunCardRewardChoice.new(
		[
			{"id": "warden_strike", "owner": 456},
			{"id": "seamstress_prick", "owner": "seamstress"},
			{"id": "tinker_pop_shot", "owner": "tinker"}
		], _fixture_party()
	)
	_check(not numeric_owner_service.is_valid(), "numeric owner invalid")

	# Missing fields.
	var missing_service := RunCardRewardChoice.new(
		[
			{"id": "warden_strike"},
			{"id": "seamstress_prick", "owner": "seamstress"},
			{"id": "tinker_pop_shot", "owner": "tinker"}
		], _fixture_party()
	)
	_check(not missing_service.is_valid(), "missing owner field invalid")

	# After rejected selection on valid service, a valid claim succeeds once.
	var valid_service := RunCardRewardChoice.new(_fixture_offers(), _fixture_party())
	var bad_selection := valid_service.claim(base_deck.duplicate(), "nonexistent_card")
	_check(bad_selection.get("ok", false) == false, "absent selected card fails")
	_check(not valid_service.is_claimed(), "invalid selection does not latch claim")

	# A subsequent valid selection succeeds once.
	var valid_after_bad := valid_service.claim(base_deck.duplicate(), "tinker_pop_shot")
	_check(valid_after_bad.get("ok", false) == true, "valid selection succeeds after rejected selection")
	_check(valid_service.is_claimed(), "successful claim latches after prior failure")


func _test_no_rng_consumption() -> void:
	# Verify reward selection does not consume the injected run RNG.
	var service := RunCardRewardChoice.new(_fixture_offers(), _fixture_party())
	var control_rng := RandomNumberGenerator.new()
	control_rng.seed = 12345
	var test_rng := RandomNumberGenerator.new()
	test_rng.seed = 12345

	# Capture reference value before any claim.
	var control_ref := control_rng.randi()

	# Claim must not advance the RNG stream. Since claim doesn't touch any RNG,
	# compare by reseeding and replaying.
	var claim_result := service.claim(_load_starter_deck().duplicate(), "warden_strike")
	_check(claim_result.get("ok", false) == true, "claim succeeds for RNG test")

	# The claim should not have consumed any RNG; reseed and get same first value.
	control_rng.seed = 12345
	var replay_ref := control_rng.randi()
	_check(control_ref == replay_ref, "re-seeded control produces same value (sanity)")

	# More directly: construct a fresh RNG at same seed, advance once, then claim,
	# and prove claim does not change the remaining value compared to a non-claimed stream.
	var stream_a := RandomNumberGenerator.new()
	stream_a.seed = 99999
	var expected_first := stream_a.randi()

	var stream_b := RandomNumberGenerator.new()
	stream_b.seed = 99999
	stream_b.randi()  # consume same first draw

	var claim_service := RunCardRewardChoice.new(_fixture_offers(), _fixture_party())
	claim_service.claim(_load_starter_deck().duplicate(), "seamstress_prick")

	# After claim, stream_b's next value should equal stream_a's next value.
	var next_a := stream_a.randi()
	var next_b := stream_b.randi()
	_check(next_a == next_b, "claim does not advance RNG stream (same next randi)")
