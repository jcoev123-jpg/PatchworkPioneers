class_name CombatButtonGolemSewCards
extends RefCounted
## V3-1 scene-free paid resolver for Button Golem's four counted-button Sew printings.
##
## One successful call spends 1 energy, discards exactly one held copy and gives Block to the
## casting Golem only: Seam Re-Sew and Sew On add one Block per button popped earlier in this
## combat, Seam Re-Sew+ adds two flat Block on top of that, and Sew On+ adds two Block per pop.
## The per-combat buttons_popped counter written by CombatButtonGolemPopCards is read, never
## consumed or incremented, and no attack, card draw, status, enemy change or seeded RNG draw
## happens here.
##
## Data only elsewhere: the starter and reward catalogs are descriptor-only and no live hand,
## party-picker, reward or map path registers these IDs yet. This helper is the callable combat
## rules layer a later wiring task must call, never a second live hand and never a run-wallet
## or standalone spell-currency path.
##
## The four printings are split across two catalogs (the two starter IDs and the two reward-pool
## IDs) with different printed magnitudes, so every card is authenticated against its own
## authored record and base/plus upgrade link, never a caller-supplied effect dictionary or
## a caller-supplied popped-button count.

const OWNER_ID := "button_golem"
const COST := 1
const BUTTONS_KEY := "buttons_popped"
const SELF_TARGET := 0
const FROM_POSITIONS: Array[int] = [1, 2, 3]
const TO_POSITIONS: Array[int] = []

## Exact authored printings: Block per earlier pop, plus any flat Block. Starter and reward
## catalogs keep their own IDs; each is authenticated against the catalog it was authored in.
const PRINTINGS := {
	"button_golem_starter_seam_resew": {"catalog": "starter", "per_button": 1, "flat": 0},
	"button_golem_starter_seam_resew_plus": {"catalog": "starter", "per_button": 1, "flat": 2},
	"button_golem_sew_on": {"catalog": "pool", "per_button": 1, "flat": 0},
	"button_golem_sew_on_plus": {"catalog": "pool", "per_button": 2, "flat": 0},
}


## Pure query: an authentic Sew printing ID, never a malformed or aliased value.
func is_supported_card(card_id: Variant) -> bool:
	return typeof(card_id) == TYPE_STRING and PRINTINGS.has(card_id)


## Paid resolution against real model state. Refusals return a receipt with exactly the same
## field set, reason "...", and no state change at all: no energy, card, Block, HP, counter,
## deck pile, enemy record or seeded RNG draw.
func play_card(deck: CombatDeck, party: CombatParty, card_id: Variant,
		target_position: int = 0) -> Dictionary:
	var plan: Dictionary = _prepare(deck, party, card_id, target_position)
	if not plan["ok"]:
		return plan
	# Every operation below is guaranteed by preflight and nothing here draws RNG.
	var id: String = plan["card_id"]
	deck.try_spend_energy(plan["cost"])
	deck.discard_played(id)
	party.gain_block(plan["owner_position"], plan["block_gained"])
	plan["reason"] = "applied"
	plan["block_after"] = int(party.get_hero(plan["owner_position"]).get("block", 0))
	return plan


## Read-only preflight: authenticate the card, bind the Golem to its actual seat, read the
## authoritative counter and compute the exact Block gain before anything is charged.
func _prepare(deck: CombatDeck, party: CombatParty, card_id: Variant,
		target_position: int) -> Dictionary:
	var plan := {
		"ok": false, "reason": "unsupported_card",
		"card_id": card_id if typeof(card_id) == TYPE_STRING else "",
		"cost": 0, "owner_position": 0, "buttons_popped": 0,
		"block_gained": 0, "block_after": 0,
	}
	if not is_supported_card(card_id):
		return plan
	var printed: Dictionary = _authenticate(card_id)
	if printed.is_empty():
		plan["reason"] = "catalog_mismatch"
		return plan
	plan["cost"] = COST
	if deck == null or party == null:
		plan["reason"] = "invalid_request"
		return plan
	if deck.combat_state == null:
		plan["reason"] = "invalid_deck"
		return plan
	if not _valid_roster(party):
		plan["reason"] = "invalid_roster"
		return plan
	if not deck.turn_active:
		plan["reason"] = "inactive_turn"
		return plan

	# Bind the Golem to its actual current ID/seat; never assume a fixed slot.
	var owner_position := 0
	for hero: Dictionary in party._heroes:
		if hero.get("id") != OWNER_ID:
			continue
		if owner_position != 0:
			plan["reason"] = "duplicate_owner"
			return plan
		owner_position = int(hero["position"])
	if owner_position == 0:
		plan["reason"] = "owner_missing"
		return plan
	if not _distinct_hero_ids(party):
		plan["reason"] = "invalid_roster"
		return plan
	if not FROM_POSITIONS.has(owner_position):
		plan["reason"] = "invalid_owner_position"
		return plan
	plan["owner_position"] = owner_position
	var owner: Dictionary = party._heroes[owner_position - 1]
	if owner["hp"] <= 0:
		plan["reason"] = "owner_torn"
		return plan
	var block_value: Variant = owner.get("block")
	if not block_value is int or block_value < 0:
		plan["reason"] = "malformed_block"
		return plan
	var block_now: int = block_value
	var button_count: Variant = owner.get(BUTTONS_KEY, 0)
	if not button_count is int or button_count < 0:
		plan["reason"] = "malformed_button_count"
		return plan
	plan["buttons_popped"] = button_count
	if not deck.hand.has(card_id):
		plan["reason"] = "card_not_held"
		return plan
	if deck.energy < COST:
		plan["reason"] = "insufficient_energy"
		return plan
	if target_position != SELF_TARGET:
		plan["reason"] = "invalid_target"
		return plan
	var gain: Variant = _checked_gain(printed["per_button"], printed["flat"], button_count)
	if gain == null:
		plan["reason"] = "arithmetic_overflow"
		return plan
	var gain_value: int = gain
	if gain_value > CombatParty.MAX_INT - block_now:
		plan["reason"] = "block_overflow"
		return plan
	plan["block_gained"] = gain_value
	plan["block_after"] = block_now + gain_value
	plan["ok"] = true
	plan["reason"] = "ready"
	return plan


## Authenticate one printing through its own authored catalog. Returns
## {"per_button": N, "flat": M} or {}.
func _authenticate(card_id: String) -> Dictionary:
	var spec: Dictionary = PRINTINGS.get(card_id, {})
	if spec.is_empty():
		return {}
	var catalog
	if str(spec["catalog"]) == "starter":
		catalog = ButtonGolemStarterCards.new()
	else:
		catalog = ButtonGolemPoolCards.new()
	var expected_effects: Dictionary = {"block_per_button_popped": int(spec["per_button"])}
	if int(spec["flat"]) > 0:
		expected_effects["block"] = int(spec["flat"])
	if not _matches_authored(catalog.get_definition(card_id), card_id, expected_effects):
		return {}
	if not _matching_upgrade_link(catalog, card_id):
		return {}
	return {"per_button": int(spec["per_button"]), "flat": int(spec["flat"])}


## Exact contract for one record: identity, owner, energy cost, self target with no enemy slot,
## FROM slots 1-3, empty TO and the complete printed effect set with integer magnitudes.
func _matches_authored(definition: Dictionary, card_id: String,
		expected_effects: Dictionary) -> bool:
	if definition.is_empty() or definition.get("id") != card_id:
		return false
	if definition.get("owner") != OWNER_ID:
		return false
	var cost: Variant = definition.get("cost")
	if not cost is int or cost != COST:
		return false
	if definition.get("target_kind") != "self":
		return false
	if not _exact_positions(definition.get("from_positions"), FROM_POSITIONS):
		return false
	if not _exact_positions(definition.get("to_positions"), TO_POSITIONS):
		return false
	var effects_value: Variant = definition.get("effects")
	if not effects_value is Dictionary:
		return false
	var effects: Dictionary = effects_value
	if effects.size() != expected_effects.size():
		return false
	for key: String in expected_effects:
		if not effects.has(key):
			return false
		var value: Variant = effects[key]
		if not value is int or value != expected_effects[key]:
			return false
	return true


## Both printings must still point at each other inside the same catalog.
func _matching_upgrade_link(catalog, card_id: String) -> bool:
	var base_id: String = card_id.trim_suffix("_plus")
	var plus_id: String = base_id + "_plus"
	if not catalog.has_card(base_id) or not catalog.has_card(plus_id):
		return false
	if catalog.get_upgrade_id(base_id) != plus_id:
		return false
	return catalog.get_definition(plus_id).get("upgrade_of") == base_id


func _exact_positions(value: Variant, expected: Array[int]) -> bool:
	if not value is Array or value.size() != expected.size():
		return false
	for index in range(expected.size()):
		if not value[index] is int or value[index] != expected[index]:
			return false
	return true


## Three genuine seats in order with nonempty string IDs and sane per-combat HP records.
## ID uniqueness is checked separately so a second Golem reports duplicate_owner first.
func _valid_roster(party: CombatParty) -> bool:
	if not party.is_valid() or party._heroes.size() != CombatParty.PARTY_SIZE:
		return false
	for index in range(CombatParty.PARTY_SIZE):
		var hero: Variant = party._heroes[index]
		if not hero is Dictionary:
			return false
		var hero_dict: Dictionary = hero
		if hero_dict.get("position") != index + 1:
			return false
		var hero_id: Variant = hero_dict.get("id")
		if not hero_id is String or hero_id.is_empty():
			return false
		var max_hp: Variant = hero_dict.get("max_hp")
		if not max_hp is int or max_hp <= 0:
			return false
		var hp: Variant = hero_dict.get("hp")
		if not hp is int or hp < 0 or hp > max_hp:
			return false
	return true


func _distinct_hero_ids(party: CombatParty) -> bool:
	var seen: Dictionary = {}
	for hero: Dictionary in party._heroes:
		var hero_id: String = hero["id"]
		if seen.has(hero_id):
			return false
		seen[hero_id] = true
	return true


## Checked N * per_button + flat. Returns the gain, or null when the product or sum would
## overflow the signed 64-bit combat integer range.
func _checked_gain(per_button: int, flat: int, count: int) -> Variant:
	if per_button <= 0 or flat < 0 or count < 0:
		return null
	@warning_ignore("integer_division")
	var max_count: int = CombatParty.MAX_INT / per_button
	if count > max_count:
		return null
	var gain: int = count * per_button
	if flat > CombatParty.MAX_INT - gain:
		return null
	return gain + flat
