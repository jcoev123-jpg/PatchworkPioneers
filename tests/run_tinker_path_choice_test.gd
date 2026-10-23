extends SceneTree
## D2-5 Tinker-only Path and pre-run shared-deck regression.

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	_test_authored_choices()
	_test_exact_deck_selection()
	_test_rejections_and_rng()
	for failure in failures:
		printerr(failure)
	print("run_tinker_path_choice_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _base_deck() -> Array:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/cards/starter_deck.json"))
	return raw if raw is Array else []


func _counts(deck: Array) -> Dictionary:
	var counts: Dictionary = {}
	for id in deck:
		counts[id] = int(counts.get(id, 0)) + 1
	return counts


func _test_authored_choices() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/heroes/tinker_paths.json"))
	_check(raw is Dictionary, "Path JSON parses")
	if not (raw is Dictionary):
		return
	_check(raw.get("hero_id") == "tinker", "Tinker is the sole Path owner")
	var rows: Variant = raw.get("paths")
	_check(rows is Array and rows.size() == 2, "exactly two Path records")
	if not (rows is Array) or rows.size() != 2:
		return
	var choice := RunTinkerPathChoice.new()
	var offers: Array[Dictionary] = choice.get_offers()
	_check(offers.size() == 2, "valid fresh offers")
	var expected: Dictionary = {
		"sharpshot": {"name": "Sharpshot", "passive": "tinker_first_successful_attack",
			"card": "tinker_scope", "card_name": "Scope", "cost": 0, "from": [3],
			"effects": {"next_attack_damage_bonus": 4, "expires": "end_of_player_turn"},
			"passive_effects": {"trigger": "first_successful_tinker_attack_each_player_turn",
				"bonus_damage": 3}},
		"clockwork": {"name": "Clockwork", "passive": "tinker_first_expensive_card_discount",
			"card": "tinker_wind_up", "card_name": "Wind-up", "cost": 1, "from": [2, 3],
			"effects": {"next_turn_energy": 1},
			"passive_effects": {"trigger": "first_successful_tinker_card_with_printed_cost_at_least_2_each_player_turn",
				"minimum_printed_cost": 2, "discount": 1}}
	}
	var seen: Dictionary = {}
	var seen_cards: Dictionary = {}
	for offer in offers:
		var path_id: String = str(offer.get("id", ""))
		_check(expected.has(path_id) and not seen.has(path_id), "only distinct authored path IDs")
		if not expected.has(path_id):
			continue
		var want: Dictionary = expected[path_id]
		seen[path_id] = true
		_check(offer == choice.get_definition(path_id), path_id + " JSON catalog parity")
		_check(offer.get("display_name") == want["name"] and offer.get("owner") == "tinker",
			path_id + " Path display and owner")
		_check(offer.get("passive_id") == want["passive"] and
			offer.get("passive") == want["passive_effects"], path_id + " full passive rule")
		var card: Dictionary = offer.get("card", {})
		var id: String = str(card.get("id", ""))
		_check(id == want["card"] and not seen_cards.has(id), path_id + " distinct card ID")
		seen_cards[id] = true
		_check(card.get("display_name") == want["card_name"] and
			card.get("owner") == "tinker" and card.get("cost") == want["cost"] and
			card.get("from_positions") == want["from"] and
			card.get("target_kind") == "none" and card.get("to_positions") == [] and
			card.get("effects") == want["effects"] and
			card.get("starting_copies") == 0 and
			card.get("illustration_path") == "res://assets/paper/cards/" + id + ".png",
			path_id + " full StarterCards-compatible descriptor")
		_check(choice.get_card_definition(id) == card, path_id + " per-ID Path card lookup")
		_check(StarterCards.new().get_definition(id).is_empty() and
			TinkerPoolCards.new().get_definition(id).is_empty() and
			not TinkerPoolCards.new().get_pool_card_ids().has(id),
			path_id + " excluded from shared starter and reward pool")
		card["effects"]["forged"] = 100
		card["from_positions"].clear()
		_check(choice.get_definition(path_id)["card"]["effects"] == want["effects"] and
			choice.get_card_definition(id)["from_positions"] == want["from"],
			path_id + " nested definition lookups detached")
	_check(seen.size() == 2 and seen_cards.size() == 2, "both separate choices exercised")
	_check(choice.get_definition("other").is_empty() and
		choice.get_card_definition("tinker_not_a_path").is_empty(),
		"unknown catalog IDs fail closed")
	if not offers.is_empty():
		offers[0]["passive"]["bonus_damage"] = -88
		offers.clear()
		_check(choice.get_offers().size() == 2 and
			choice.get_definition("sharpshot")["passive"]["bonus_damage"] == 3,
			"offers freshly deep-copied")


func _test_exact_deck_selection() -> void:
	var raw_roster: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/heroes/starter_party.json"))
	_check(raw_roster is Array and raw_roster.size() == 3, "three actual starting heroes")
	if not (raw_roster is Array):
		return
	var heroes: Dictionary = {}
	for hero in raw_roster:
		heroes[hero["id"]] = hero
	_check(heroes.has("warden") and heroes.has("seamstress") and heroes.has("tinker"),
		"authored Warden/Seamstress/Tinker party")
	_check(heroes.get("tinker", {}).get("max_hp") == 26, "authored Tinker HP 26")
	var original: Array = _base_deck()
	_check(original.size() == 12, "actual pre-Path deck has 12 cards")
	var counts: Dictionary = _counts(original)
	_check(counts.get("warden_strike") == 2 and counts.get("seamstress_prick") == 2
		and counts.get("tinker_pop_shot") == 2, "authored starter duplicate counts")
	_check(original.count("tinker_scope") == 0 and original.count("tinker_wind_up") == 0,
		"no Path cards in pre-run deck")
	for path_id in ["sharpshot", "clockwork"]:
		var choice := RunTinkerPathChoice.new()
		var before: Array = original.duplicate(true)
		var rng := RandomNumberGenerator.new()
		rng.seed = 162
		var state: int = rng.state
		var result: Dictionary = choice.choose(path_id, before, rng)
		_check(result.get("ok") == true and choice.has_selection(), path_id + " selected once")
		_check(rng.state == state, path_id + " selection uses no RNG")
		_check(before == original, path_id + " caller deck untouched")
		var fresh: Array = result.get("deck", [])
		_check(fresh.size() == 13, path_id + " 13-card output")
		var appended: String = "tinker_scope" if path_id == "sharpshot" else "tinker_wind_up"
		var absent: String = "tinker_wind_up" if path_id == "sharpshot" else "tinker_scope"
		var want: Dictionary = counts.duplicate(true)
		want[appended] = 1
		_check(_counts(fresh) == want and fresh.count(absent) == 0,
			path_id + " preserves original exact multiset plus one Path card")
		_check(choice.get_selection() == {"path_id": path_id,
			"passive_id": choice.get_definition(path_id)["passive_id"],
			"card_id": appended}, path_id + " passive replaces instead of stacks")
		fresh.clear()
		var selected: Dictionary = choice.get_selection()
		selected["card_id"] = "forgery"
		_check(choice.get_selection()["card_id"] == appended,
			path_id + " detached choice receipt")
		_check(not choice.choose("clockwork" if path_id == "sharpshot" else "sharpshot", original, rng).get("ok", false) and
			rng.state == state, path_id + " repeat selection refuses RNG-free")
		_check(choice.get_selection()["card_id"] == appended, "repeat leaves path intact")


func _test_rejections_and_rng() -> void:
	var deck: Array = _base_deck()
	var bad_inputs: Array = [[], deck.slice(1), deck + ["unknown_card"],
		deck + [null], [123, "tinker_pop_shot"], null, "not a deck"]
	var replaced: Array = deck.duplicate()
	replaced[0] = "unknown_card"
	bad_inputs.append(replaced)
	var mutated: Array = deck.duplicate()
	mutated[0] = "tinker_pop_shot"
	bad_inputs.append(mutated)
	for id in ["", "other_hero", "tinker_scope", "TINKER", "wind_up"]:
		var choice := RunTinkerPathChoice.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 999
		var before_state: int = rng.state
		var result: Dictionary = choice.choose(id, deck, rng)
		_check(result.get("ok") == false and result.get("deck", []).is_empty() and
			not choice.has_selection(), "unknown Path refuses: " + id)
		_check(rng.state == before_state and deck == _base_deck(),
			"unknown Path leaves RNG and deck: " + id)
	for invalid in bad_inputs:
		var choice := RunTinkerPathChoice.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 87
		var initial_state: int = rng.state
		var snapshot: Variant = invalid.duplicate(true) if invalid is Array else invalid
		var result: Dictionary = choice.choose("clockwork", invalid, rng)
		_check(result.get("ok") == false and not choice.has_selection(),
			"invalid deck refused")
		_check(invalid == snapshot and rng.state == initial_state,
			"invalid deck doesn't mutate or advance RNG")
	var new_choice := RunTinkerPathChoice.new()
	_check(new_choice.choose("clockwork", deck).get("ok", false),
		"rejections do not poison subsequent independent fresh choice")
