class_name CombatScarecrowReStuffCards
extends RefCounted
## Scene-free paid Re-Stuff resolver. Live hand/reward registration is separate.
## Target 0 means the authored self target, with no ally/enemy selection.

const CARDS := {"scarecrow_re_stuff": 10, "scarecrow_re_stuff_plus": 13}


func is_supported_card(card_id: Variant) -> bool:
	return typeof(card_id) == TYPE_STRING and CARDS.has(card_id)


func play_card(deck: CombatDeck, party: CombatParty, card_id: Variant,
		target_position: int = 0) -> Dictionary:
	var receipt := _prepare(deck, party, card_id, target_position)
	if not receipt["ok"]:
		return receipt
	# All operations are guaranteed by preflight; no callbacks or RNG draws intervene.
	deck.try_spend_energy(receipt["cost"])
	deck.discard_played(card_id)
	# Mutate the authoritative record, preserving Block, statuses and all metadata.
	var hero: Dictionary = party._heroes[receipt["owner_position"] - 1]
	hero["max_hp"] -= 2
	hero["hp"] = mini(hero["hp"], hero["max_hp"])
	hero["hp"] += mini(CARDS[card_id], hero["max_hp"] - hero["hp"])
	receipt["max_hp_after"] = hero["max_hp"]
	receipt["hp_after"] = hero["hp"]
	receipt["reason"] = "applied"
	return receipt


func _prepare(deck: CombatDeck, party: CombatParty, card_id: Variant,
		target_position: int) -> Dictionary:
	var receipt := {"ok": false, "reason": "unsupported_card", "card_id": null,
		"cost": 0, "owner_position": 0, "max_hp_before": null, "max_hp_after": null,
		"hp_before": null, "hp_after": null}
	# Never retain caller-owned containers in a refusal receipt.
	if not is_supported_card(card_id):
		if typeof(card_id) == TYPE_STRING:
			receipt["card_id"] = card_id
		return receipt
	receipt["card_id"] = card_id
	receipt["cost"] = 2
	var definition := ScarecrowPoolCards.new().get_definition(card_id)
	if definition.get("id") != card_id or definition.get("owner") != "scarecrow" \
			or definition.get("cost") != 2 or definition.get("target_kind") != "self" \
			or definition.get("from_positions") != [1, 2, 3] \
			or definition.get("to_positions") != [] \
			or definition.get("effects") != {"max_hp_loss": 2, "heal": CARDS[card_id]}:
		receipt["reason"] = "catalog_mismatch"
		return receipt
	if deck == null or party == null or not party.is_valid():
		receipt["reason"] = "invalid_request"
		return receipt
	if deck.combat_state == null or not deck.turn_active:
		receipt["reason"] = "inactive_turn"
		return receipt
	# Bind identity to the current authoritative slot and reject malformed rosters.
	var ids: Array[String] = []
	for index in range(CombatParty.PARTY_SIZE):
		var hero: Dictionary = party._heroes[index]
		var id = hero.get("id")
		var hp = hero.get("hp")
		var max_hp = hero.get("max_hp")
		if not id is String or id.is_empty() or ids.has(id) \
				or hero.get("position") != index + 1 \
				or not hp is int or not max_hp is int \
				or max_hp <= 0 or hp < 0 or hp > max_hp:
			receipt["reason"] = "invalid_party"
			return receipt
		ids.append(id)
		if id == "scarecrow":
			receipt["owner_position"] = index + 1
			receipt["hp_before"] = hp
			receipt["hp_after"] = hp
			receipt["max_hp_before"] = max_hp
			receipt["max_hp_after"] = max_hp
	if receipt["owner_position"] == 0:
		receipt["reason"] = "owner_missing"
	elif receipt["hp_before"] == 0:
		receipt["reason"] = "owner_downed"
	elif receipt["max_hp_before"] <= 2:
		receipt["reason"] = "max_hp_cost"
	elif target_position != 0:
		receipt["reason"] = "invalid_target"
	elif not deck.hand.has(card_id):
		receipt["reason"] = "card_not_held"
	elif deck.energy < 2:
		receipt["reason"] = "insufficient_energy"
	else:
		receipt["ok"] = true
	return receipt
