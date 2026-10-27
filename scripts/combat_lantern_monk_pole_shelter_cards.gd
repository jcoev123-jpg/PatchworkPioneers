class_name CombatLanternMonkPoleShelterCards
extends RefCounted
## Scene-free paid Block and explicit single-debuff cleanse. Live hand wiring is separate.

const OWNER := "lantern_monk"
const TARGET_KIND := "ally_single"
const CLEANSE_COUNT := 1

const ELIGIBLE_DEBUFFS: Array[String] = ["bleed", "weak", "exposed"]

## Both printings belong only to the Lantern Monk starter catalog.
const CARDS := {
	"lantern_monk_pole_shelter": {
		"cost": 1, "block": 5, "from_positions": [1, 2, 3],
		"upgrade_id": "lantern_monk_pole_shelter_plus",
	},
	"lantern_monk_pole_shelter_plus": {
		"cost": 1, "block": 7, "from_positions": [1, 2, 3],
		"upgrade_of": "lantern_monk_pole_shelter",
	},
}


func play_card(deck: CombatDeck, party: CombatParty, card_id: Variant,
		target_position: int = 0, cleanse_debuff: Variant = "") -> Dictionary:
	var plan: Dictionary = _prepare(deck, party, card_id, target_position, cleanse_debuff)
	if not plan.get("ok", false):
		return _refusal(str(plan.get("reason", "refused")))
	if not deck.try_spend_energy(plan["cost"]):
		return _refusal("insufficient_energy")
	if not deck.discard_played(plan["card_id"]):
		return _refusal("card_not_held")
	if not party.gain_block(plan["target_position"], plan["block"]):
		return _refusal("block_failed")

	var selection: String = plan["cleanse_debuff"]
	var cleansed_count := 0
	if selection != "":
		var record: Dictionary = party._heroes[plan["target_position"] - 1]
		var statuses: Dictionary = record.get("statuses", {})
		cleansed_count = int(statuses[selection])
		statuses.erase(selection)
		record["statuses"] = statuses

	var block_after: int = party.get_hero(plan["target_position"])["block"]
	return {
		"ok": true,
		"reason": "applied",
		"card_id": plan["card_id"],
		"cost": plan["cost"],
		"owner_position": plan["owner_position"],
		"target_position": plan["target_position"],
		"block": plan["block"],
		"block_before": plan["block_before"],
		"block_after": block_after,
		"cleansed_debuff": selection,
		"cleansed_count": cleansed_count,
	}


func is_supported_card(card_id: Variant) -> bool:
	return typeof(card_id) == TYPE_STRING and CARDS.has(card_id)


func _prepare(deck: CombatDeck, party: CombatParty, card_id: Variant,
		target_position: int, cleanse_debuff: Variant) -> Dictionary:
	if deck == null or party == null:
		return _refusal("invalid_request")
	if deck.combat_state == null or deck._rng == null or not deck.turn_active:
		return _refusal("inactive_turn")
	if not party.is_valid() or party._heroes.size() != CombatParty.PARTY_SIZE:
		return _refusal("invalid_party")
	if typeof(card_id) != TYPE_STRING:
		return _refusal("unsupported_card")
	var id: String = card_id
	var card: Dictionary = CARDS.get(id, {})
	if card.is_empty():
		return _refusal("unsupported_card")
	var definition: Dictionary = _catalog_definition(id)
	if not _authentic(definition, id, card):
		return _refusal("catalog_mismatch")
	if not deck.hand.has(id):
		return _refusal("card_not_held")
	var cost: int = card["cost"]
	if cost < 0 or deck.energy < cost:
		return _refusal("insufficient_energy")

	var heroes: Array[Dictionary] = party.get_heroes()
	var owner_position := 0
	var seen_ids: Array[String] = []
	for index in range(CombatParty.PARTY_SIZE):
		var hero: Dictionary = heroes[index]
		var hero_id = hero.get("id")
		var position = hero.get("position")
		var hp = hero.get("hp")
		var max_hp = hero.get("max_hp")
		var block = hero.get("block")
		if not hero_id is String or hero_id.is_empty() or seen_ids.has(hero_id):
			return _refusal("invalid_party")
		if not position is int or position != index + 1:
			return _refusal("invalid_party")
		if not max_hp is int or max_hp <= 0:
			return _refusal("invalid_party")
		if not hp is int or hp < 0 or hp > max_hp:
			return _refusal("invalid_party")
		if not block is int or block < 0:
			return _refusal("invalid_party")
		var statuses_value = hero.get("statuses", {})
		if not statuses_value is Dictionary:
			return _refusal("malformed_statuses")
		for name in statuses_value:
			if not name is String or name.is_empty():
				return _refusal("malformed_statuses")
			var count = statuses_value[name]
			if not count is int or count < 0:
				return _refusal("malformed_statuses")
		seen_ids.append(hero_id)
		if hero_id == OWNER:
			owner_position = index + 1

	if owner_position == 0:
		return _refusal("owner_missing")
	if not card["from_positions"].has(owner_position):
		return _refusal("owner_illegal_position")
	if int(heroes[owner_position - 1]["hp"]) == 0:
		return _refusal("owner_downed")
	if target_position < 1 or target_position > CombatParty.PARTY_SIZE:
		return _refusal("invalid_target")
	if int(heroes[target_position - 1]["hp"]) == 0:
		return _refusal("target_downed")

	# gain_block must be guaranteed before charging: overflow otherwise rejects after payment.
	if int(card["block"]) > CombatParty.MAX_INT - int(heroes[target_position - 1]["block"]):
		return _refusal("block_overflow")

	var statuses: Variant = _statuses_of(party, target_position)
	if not statuses is Dictionary:
		return _refusal("malformed_statuses")
	var present: Array[String] = []
	for debuff: String in ELIGIBLE_DEBUFFS:
		if int(statuses.get(debuff, 0)) > 0:
			present.append(debuff)
	if typeof(cleanse_debuff) != TYPE_STRING:
		return _refusal("invalid_cleanse")
	var selection: String = cleanse_debuff
	if present.is_empty():
		if selection != "":
			return _refusal("cleanse_not_present")
	elif selection.is_empty() or not present.has(selection):
		return _refusal("cleanse_required")

	return {
		"ok": true,
		"card_id": id,
		"cost": cost,
		"owner_position": owner_position,
		"target_position": target_position,
		"block": int(card["block"]),
		"cleanse_debuff": selection,
		"block_before": int(heroes[target_position - 1]["block"]),
	}


func _statuses_of(party: CombatParty, position: int) -> Variant:
	if party == null or party._heroes.size() != CombatParty.PARTY_SIZE:
		return null
	if position < 1 or position > CombatParty.PARTY_SIZE:
		return null
	var record: Dictionary = party._heroes[position - 1]
	if not record.has("statuses"):
		return {}
	return record["statuses"]


func _catalog_definition(card_id: String) -> Dictionary:
	return LanternMonkStarterCards.new().get_definition(card_id)


## Typed equality rejects coercible metadata as well as changed effects or upgrade links.
func _same_value(actual: Variant, expected: Variant) -> bool:
	if typeof(actual) != typeof(expected):
		return false
	if expected is Dictionary:
		if actual.size() != expected.size():
			return false
		for key in expected:
			if not actual.has(key) or not _same_value(actual[key], expected[key]):
				return false
		return true
	if expected is Array:
		if actual.size() != expected.size():
			return false
		for index in range(expected.size()):
			if not _same_value(actual[index], expected[index]):
				return false
		return true
	return actual == expected


func _authentic(definition: Dictionary, card_id: String, card: Dictionary) -> bool:
	var expected := {
		"id": card_id, "owner": OWNER, "cost": card["cost"],
		"target_kind": TARGET_KIND, "from_positions": card["from_positions"],
		"to_positions": [], "effects": {"block": card["block"], "cleanse_debuff": CLEANSE_COUNT},
		"reward_eligible": false, "starting_copies": 0 if card.has("upgrade_of") else 1,
	}
	var link := "upgrade_of" if card.has("upgrade_of") else "upgrade_id"
	expected[link] = card[link]
	if definition.has("upgrade_id" if link == "upgrade_of" else "upgrade_of"):
		return false
	for field in expected:
		if not definition.has(field) or not _same_value(definition[field], expected[field]):
			return false
	return true


func _refusal(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
