class_name CombatScarecrowStrawWrapCards
extends RefCounted
## Scene-free paid resolver for the Scarecrow's Straw Wrap ally Block-and-draw
## cards (V3-1). Only the two pool-authorized printings resolve here.
##
## Straw Wrap (base, block 6) and Straw Wrap+ (upgrade, block 8) each print
## one energy, are cast from any hero seat (FROM [1,2,3]), target one living
## ally (self included), grant the printed Block and draw exactly one shared
## card. The played copy is drawn before being discarded, so it cannot
## redraw itself through a reshuffle.

const OWNER := "scarecrow"
const TARGET_KIND := "ally_single"
const FROM_POSITIONS := [1, 2, 3]
const TO_POSITIONS := []
const DRAW := 1

const CARDS := {
	"scarecrow_straw_wrap": {
		"cost": 1,
		"block": 6,
		"effects": {"block": 6, "draw": 1},
		"catalog": "pool",
		"upgrade_id": "scarecrow_straw_wrap_plus",
	},
	"scarecrow_straw_wrap_plus": {
		"cost": 1,
		"block": 8,
		"effects": {"block": 8, "draw": 1},
		"catalog": "pool",
		"upgrade_of": "scarecrow_straw_wrap",
	},
}

const _POOL_CATALOG := preload("res://data/cards/scarecrow_pool_cards.gd")


func is_supported_card(card_id: Variant) -> bool:
	return typeof(card_id) == TYPE_STRING and CARDS.has(card_id)


static func wrap_definition(card_id: Variant) -> Dictionary:
	if typeof(card_id) != TYPE_STRING:
		return {}
	var id: String = card_id
	var card: Dictionary = CARDS.get(id, {})
	if card.is_empty():
		return {}
	var definition := _POOL_CATALOG.new().get_definition(id)
	if not is_authentic_definition(definition, id):
		return {}
	return definition


static func is_authentic_definition(definition: Variant, card_id: Variant) -> bool:
	if typeof(definition) != TYPE_DICTIONARY or typeof(card_id) != TYPE_STRING:
		return false
	var id: String = card_id
	var card: Dictionary = CARDS.get(id, {})
	if card.is_empty():
		return false
	if definition.get("id") != id or definition.get("owner") != OWNER:
		return false
	if typeof(definition.get("cost")) != TYPE_INT or definition["cost"] != card["cost"]:
		return false
	if definition.get("target_kind") != TARGET_KIND:
		return false
	if typeof(definition.get("from_positions")) != TYPE_ARRAY \
			or definition["from_positions"] != FROM_POSITIONS:
		return false
	var to_positions: Variant = definition.get("to_positions")
	if typeof(to_positions) != TYPE_ARRAY or not (to_positions as Array).is_empty():
		return false
	var effects: Variant = definition.get("effects")
	if typeof(effects) != TYPE_DICTIONARY or (effects as Dictionary).size() != 2:
		return false
	var block: Variant = (effects as Dictionary).get("block")
	var draw: Variant = (effects as Dictionary).get("draw")
	if typeof(block) != TYPE_INT or typeof(draw) != TYPE_INT:
		return false
	if block != card["block"] or draw != DRAW:
		return false
	if effects != card["effects"]:
		return false
	if card.has("upgrade_id"):
		return definition.get("upgrade_id") == card["upgrade_id"] \
			and not definition.has("upgrade_of")
	return definition.get("upgrade_of") == card["upgrade_of"] \
		and not definition.has("upgrade_id")


func play_card(deck: CombatDeck, party: CombatParty, card_id: Variant,
		target_position: int) -> Dictionary:
	if deck == null or party == null or deck.combat_state == null or deck._rng == null:
		return _refusal("invalid_request")
	if typeof(card_id) != TYPE_STRING:
		return _refusal("unsupported_card")
	var id: String = card_id
	if not CARDS.has(id):
		return _refusal("unsupported_card")
	var definition := wrap_definition(id)
	if definition.is_empty():
		return _refusal("catalog_mismatch")

	if not deck.turn_active:
		return _refusal("inactive_turn")
	if not party.is_valid():
		return _refusal("invalid_roster")

	var heroes: Array[Dictionary] = party.get_heroes()
	var seen_ids: Array[String] = []
	var owner_position := 0
	for index in range(CombatParty.PARTY_SIZE):
		var hero: Dictionary = heroes[index]
		var hero_id: Variant = hero.get("id")
		var position: Variant = hero.get("position")
		var hp: Variant = hero.get("hp")
		var max_hp: Variant = hero.get("max_hp")
		var current_block: Variant = hero.get("block")
		if typeof(hero_id) != TYPE_STRING or (hero_id as String).is_empty() \
				or seen_ids.has(hero_id):
			return _refusal("invalid_party")
		if typeof(position) != TYPE_INT or position != index + 1:
			return _refusal("invalid_party")
		if typeof(hp) != TYPE_INT or typeof(max_hp) != TYPE_INT \
				or max_hp <= 0 or hp < 0 or hp > max_hp:
			return _refusal("invalid_party")
		if typeof(current_block) != TYPE_INT \
				or current_block < 0 or current_block > CombatParty.MAX_INT:
			return _refusal("invalid_party")
		seen_ids.append(hero_id)
		if hero_id == OWNER:
			owner_position = index + 1
	if owner_position == 0:
		return _refusal("owner_missing")
	if heroes[owner_position - 1]["hp"] == 0:
		return _refusal("owner_downed")
	if not FROM_POSITIONS.has(owner_position):
		return _refusal("owner_illegal_position")

	if not deck.hand.has(id):
		return _refusal("card_not_held")
	var cost: int = definition["cost"]
	if cost < 0 or deck.energy < cost:
		return _refusal("insufficient_energy")

	if target_position < 1 or target_position > CombatParty.PARTY_SIZE:
		return _refusal("invalid_target")
	if heroes[target_position - 1]["hp"] == 0:
		return _refusal("target_downed")
	var block: int = definition["effects"]["block"]
	if block > CombatParty.MAX_INT - int(heroes[target_position - 1]["block"]):
		return _refusal("block_overflow")

	if not deck.try_spend_energy(cost):
		return _refusal("insufficient_energy")
	if not party.gain_block(target_position, block):
		return _refusal("block_overflow")
	var drawn: int = deck.draw_extra(DRAW)
	if not deck.discard_played(id):
		return _refusal("card_not_held")
	return {
		"ok": true,
		"reason": "applied",
		"card_id": id,
		"cost": cost,
		"owner_position": owner_position,
		"target_position": target_position,
		"block_gained": block,
		"drawn": drawn,
	}


func _refusal(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
