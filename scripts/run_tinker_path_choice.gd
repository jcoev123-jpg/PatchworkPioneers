class_name RunTinkerPathChoice
extends RefCounted
## D2-5 detached pre-run Tinker-only Path choice. No RNG, live deck or registry writes.

const PATH_DATA := "res://data/heroes/tinker_paths.json"
const STARTING_DECK_DATA := "res://data/cards/starter_deck.json"

var _chosen: Dictionary = {}


## Two new, detached offers; fail closed if the authored Path data is invalid.
func get_offers() -> Array[Dictionary]:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH_DATA))
	if not (raw is Dictionary) or raw.get("hero_id") != "tinker":
		return []
	var paths: Variant = raw.get("paths")
	if not (paths is Array) or paths.size() != 2:
		return []
	var ids: Dictionary = {}
	var card_ids: Dictionary = {}
	var offers: Array[Dictionary] = []
	for entry in paths:
		if not (entry is Dictionary):
			return []
		var path: Dictionary = entry
		var id: String = str(path.get("id", ""))
		var card: Variant = path.get("card")
		if (id != "sharpshot" and id != "clockwork") or ids.has(id) 				or path.get("owner") != "tinker" or not (card is Dictionary):
			return []
		var card_id: String = str(card.get("id", ""))
		if card_id.is_empty() or card_ids.has(card_id) or card.get("owner") != "tinker" 				or not _valid_card(card):
			return []
		var passive: Variant = path.get("passive")
		if not (passive is Dictionary):
			return []
		# Godot JSON parses every number as float; normalize numeric rules
		# and nested card effects before exposing StarterCards-style definitions.
		for key in ["bonus_damage", "minimum_printed_cost", "discount"]:
			if passive.has(key):
				var number: Variant = passive[key]
				if not (number is float or number is int) or float(number) != floorf(float(number)):
					return []
				passive[key] = int(number)
		var effects: Dictionary = card["effects"]
		for key in ["next_attack_damage_bonus", "next_turn_energy"]:
			if effects.has(key):
				var number: Variant = effects[key]
				if not (number is float or number is int) or float(number) != floorf(float(number)):
					return []
				effects[key] = int(number)
		if id == "sharpshot":
			if path.get("passive_id") != "tinker_first_successful_attack" 					or passive.get("bonus_damage") != 3 or card_id != "tinker_scope" 					or card.get("effects") != {"next_attack_damage_bonus": 4,
						"expires": "end_of_player_turn"}:
				return []
		else:
			if path.get("passive_id") != "tinker_first_expensive_card_discount" 					or passive.get("minimum_printed_cost") != 2 					or passive.get("discount") != 1 or card_id != "tinker_wind_up" 					or card.get("effects") != {"next_turn_energy": 1}:
				return []
		# JSON numbers are floats; expose integer-valued authored card descriptors.
		card["cost"] = int(card["cost"])
		card["starting_copies"] = int(card["starting_copies"])
		var from_positions: Array[int] = []
		for value in card["from_positions"]:
			if not (value is float or value is int) or float(value) != floorf(float(value)):
				return []
			from_positions.append(int(value))
		card["from_positions"] = from_positions
		ids[id] = true
		card_ids[card_id] = true
		offers.append(path.duplicate(true))
	return offers if ids.has("sharpshot") and ids.has("clockwork") else []


func _valid_card(card: Dictionary) -> bool:
	for key in ["id", "display_name", "owner", "cost", "from_positions",
			"target_kind", "to_positions", "effects", "illustration_path", "starting_copies"]:
		if not card.has(key):
			return false
	if not (card["id"] is String) or not (card["display_name"] is String):
		return false
	if not (card["cost"] is float or card["cost"] is int):
		return false
	if not (card["starting_copies"] is float or card["starting_copies"] is int):
		return false
	if not (card["from_positions"] is Array) or not (card["to_positions"] is Array):
		return false
	if not (card["effects"] is Dictionary) or not (card["illustration_path"] is String):
		return false
	if card["target_kind"] != "none" or not card["to_positions"].is_empty():
		return false
	if float(card["cost"]) != floorf(float(card["cost"])) or int(card["starting_copies"]) != 0:
		return false
	var expected_positions: Array = []
	var expected_name: String = ""
	var expected_cost: int = -1
	if card["id"] == "tinker_scope":
		expected_positions = [3]
		expected_name = "Scope"
		expected_cost = 0
	elif card["id"] == "tinker_wind_up":
		expected_positions = [2, 3]
		expected_name = "Wind-up"
		expected_cost = 1
	else:
		return false
	if card["display_name"] != expected_name or int(card["cost"]) != expected_cost:
		return false
	if card["from_positions"].size() != expected_positions.size():
		return false
	for i in range(expected_positions.size()):
		var value: Variant = card["from_positions"][i]
		if not (value is float or value is int):
			return false
		if float(value) != float(expected_positions[i]):
			return false
	return true


func get_definition(path_id: String) -> Dictionary:
	for offer in get_offers():
		if offer["id"] == path_id:
			return offer.duplicate(true)
	return {}


## Path cards are addressable ONLY here, never in StarterCards or reward pools.
func get_card_definition(card_id: String) -> Dictionary:
	for offer in get_offers():
		var card: Dictionary = offer["card"]
		if card["id"] == card_id:
			return card.duplicate(true)
	return {}


func has_selection() -> bool:
	return not _chosen.is_empty()


func get_selection() -> Dictionary:
	return _chosen.duplicate(true)


## The deck must be exactly the authored starter multiset (any order).
## The unused RNG argument makes non-consumption explicit to run callers.
## Result has a new deck; rejects never mutate the supplied deck or choice.
func choose(path_id: String, deck: Variant, _rng: RandomNumberGenerator = null) -> Dictionary:
	if has_selection() or not (deck is Array) or not _valid_starter_deck(deck):
		return {"ok": false}
	var path: Dictionary = get_definition(path_id)
	if path.is_empty():
		return {"ok": false}
	var fresh_deck: Array[String] = []
	for id in deck:
		fresh_deck.append(id)
	var card: Dictionary = path["card"]
	fresh_deck.append(card["id"])
	_chosen = {
		"path_id": path["id"],
		"passive_id": path["passive_id"],
		"card_id": card["id"]
	}
	var result: Dictionary = _chosen.duplicate(true)
	result["ok"] = true
	result["deck"] = fresh_deck
	return result


func _valid_starter_deck(deck: Array) -> bool:
	var authored: Variant = JSON.parse_string(FileAccess.get_file_as_string(STARTING_DECK_DATA))
	if not (authored is Array) or authored.is_empty() or deck.size() != authored.size():
		return false
	var catalog := StarterCards.new()
	var counts: Dictionary = {}
	for id in authored:
		if not (id is String) or not catalog.has_card(id):
			return false
		counts[id] = int(counts.get(id, 0)) + 1
	for id in deck:
		if not (id is String) or not counts.has(id) or int(counts[id]) == 0:
			return false
		counts[id] = int(counts[id]) - 1
	for remaining in counts.values():
		if remaining != 0:
			return false
	return true
