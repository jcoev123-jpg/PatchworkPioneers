class_name CombatButtonGolemRollCards
extends RefCounted
## V3-1 scene-free paid resolver for Button Golem's four Roll printings.
##
## One successful call spends 1 energy, discards exactly one held copy, exchanges the real actor
## dictionaries of the casting Golem and the selected living ally (updating both position fields)
## and gives the printed Block to the Golem alone in its NEW seat. The chosen ally keeps its own
## Block and gains nothing from this card.
##
## Data only elsewhere: the starter and reward catalogs are descriptor-only and no live hand,
## party-picker, reward or map path registers these IDs yet. This helper is the callable combat
## rules layer a later wiring task must call, never a second live hand and never a run-wallet
## or standalone spell-currency path.
##
## The four printings are split across two catalogs that name the same Roll behaviour with
## different effect keys (swap_with_ally/block_self and swap_with_target_ally/block), so every
## card is authenticated against its own authored record and printed magnitude, never a
## caller-supplied effect dictionary.
##
## Roll is not an ordinary adjacent move: both catalogs choose any other living ally with an
## empty TO list, so a deliberate 1<->3 swap is legal. The existing V3-2 Tangled protection for
## hero-initiated allied movement still applies: a positive Tangled count on either participant
## refuses the play. No seeded RNG is consulted; the caller supplies the ally's CURRENT seat.

const OWNER_ID := "button_golem"
const COST := 1
const FROM_POSITIONS: Array[int] = [1, 2, 3]
const TO_POSITIONS: Array[int] = []

## Exact authored printings and the Block each gives its caster. Starter and reward catalogs
## keep their own IDs and their own effect key names.
const STARTER_PRINTINGS := {
	"button_golem_starter_threadwheel_roll": 5,
	"button_golem_starter_threadwheel_roll_plus": 7,
}
const POOL_PRINTINGS := {
	"button_golem_button_roll": 5,
	"button_golem_button_roll_plus": 8,
}


## Pure query: an authentic Roll printing ID, never a malformed or aliased value.
func is_supported_card(card_id: Variant) -> bool:
	return typeof(card_id) == TYPE_STRING \
		and (STARTER_PRINTINGS.has(card_id) or POOL_PRINTINGS.has(card_id))


## Paid resolution against real model state. Refusals return a receipt with exactly the same
## field set, reason "...", and no state change at all: no energy, card, Block, HP, position,
## status, counter, deck pile or seeded RNG draw.
func play_card(deck: CombatDeck, party: CombatParty, card_id: Variant,
		target_position: int) -> Dictionary:
	var plan: Dictionary = _prepare(deck, party, card_id, target_position)
	if not plan["ok"]:
		return plan
	# Every operation below is guaranteed by preflight and nothing here draws RNG.
	var id: String = plan["card_id"]
	var from_position: int = plan["from_position"]
	var to_position: int = plan["target_position"]
	deck.try_spend_energy(plan["cost"])
	deck.discard_played(id)
	# Exchange the authoritative actor dictionaries themselves, then correct both position
	# fields. HP, Block, statuses, buttons_popped and every other property follow each actor.
	var mover: Dictionary = party._heroes[from_position - 1]
	var ally: Dictionary = party._heroes[to_position - 1]
	party._heroes[from_position - 1] = ally
	party._heroes[to_position - 1] = mover
	mover["position"] = to_position
	ally["position"] = from_position
	# The Golem alone gains the printed Block, in its new seat.
	party.gain_block(to_position, plan["block_gained"])
	plan["reason"] = "applied"
	plan["block_after"] = int(party.get_hero(to_position).get("block", 0))
	return plan


## Read-only preflight: authenticate the card, bind the Golem to its actual seat, validate the
## selected ally, both Tangled counters and the post-Block overflow before anything is charged.
func _prepare(deck: CombatDeck, party: CombatParty, card_id: Variant,
		target_position: int) -> Dictionary:
	var plan := {
		"ok": false, "reason": "unsupported_card",
		"card_id": card_id if typeof(card_id) == TYPE_STRING else "",
		"cost": 0, "from_position": 0, "target_position": target_position,
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
	plan["from_position"] = owner_position
	if not FROM_POSITIONS.has(owner_position):
		plan["reason"] = "invalid_owner_position"
		return plan
	var owner: Dictionary = party._heroes[owner_position - 1]
	if owner["hp"] <= 0:
		plan["reason"] = "owner_torn"
		return plan
	if not _distinct_hero_ids(party):
		plan["reason"] = "invalid_roster"
		return plan
	# The shared turn-batch validator applies the exact CombatStatuses keys and counts.
	if not _valid_statuses(party):
		plan["reason"] = "malformed_statuses"
		return plan
	if not deck.hand.has(card_id):
		plan["reason"] = "card_not_held"
		return plan
	if deck.energy < COST:
		plan["reason"] = "insufficient_energy"
		return plan

	# The selected ally is the caller's CURRENT seat for that living, distinct hero. Neither
	# catalog restricts the choice to adjacent seats or to an authored TO list.
	if target_position < 1 or target_position > CombatParty.PARTY_SIZE:
		plan["reason"] = "invalid_target"
		return plan
	if target_position == owner_position:
		plan["reason"] = "invalid_target"
		return plan
	var ally: Dictionary = party._heroes[target_position - 1]
	if ally["hp"] <= 0:
		plan["reason"] = "target_torn"
		return plan

	# V3-2 Tangled: a hero afflicted by its own side cannot move itself or be moved by its team,
	# so both participants are inspected before any charge, discard or roster edit.
	if _tangled_blocks(owner) or _tangled_blocks(ally):
		plan["reason"] = "tangled"
		return plan

	var block_now: int = owner["block"]
	var gain: int = int(printed["block"])
	if gain > CombatParty.MAX_INT - block_now:
		plan["reason"] = "block_overflow"
		return plan
	plan["block_gained"] = gain
	plan["block_after"] = block_now + gain
	plan["ok"] = true
	plan["reason"] = "ready"
	return plan


## Authenticate one printing through its own authored catalog. Returns {"block": N} or {}.
func _authenticate(card_id: String) -> Dictionary:
	if STARTER_PRINTINGS.has(card_id):
		var starter_block: int = STARTER_PRINTINGS[card_id]
		var starter_effects := {"swap_with_ally": 1, "block_self": starter_block}
		var starter_catalog := ButtonGolemStarterCards.new()
		if _matches_authored(starter_catalog.get_definition(card_id), card_id, starter_effects) \
				and _matching_upgrade_link(starter_catalog, card_id):
			return {"block": starter_block}
		return {}
	if POOL_PRINTINGS.has(card_id):
		var pool_block: int = POOL_PRINTINGS[card_id]
		var pool_effects := {"swap_with_target_ally": true, "block": pool_block}
		var pool_catalog := ButtonGolemPoolCards.new()
		if _matches_authored(pool_catalog.get_definition(card_id), card_id, pool_effects) \
				and _matching_upgrade_link(pool_catalog, card_id):
			return {"block": pool_block}
	return {}


## Exact contract for one record: identity, owner, energy cost, ally-single FROM slots 1-3 with
## empty TO and the complete printed effect set with exact Variant types and magnitudes.
func _matches_authored(definition: Dictionary, card_id: String,
		expected_effects: Dictionary) -> bool:
	if definition.is_empty() or definition.get("id") != card_id:
		return false
	if definition.get("owner") != OWNER_ID:
		return false
	var cost: Variant = definition.get("cost")
	if not cost is int or cost != COST:
		return false
	if definition.get("target_kind") != "ally_single":
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
		var expected: Variant = expected_effects[key]
		if typeof(value) != typeof(expected) or value != expected:
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


## Three genuine seats in order with nonempty string IDs and sane per-combat records.
## ID uniqueness is checked separately so a second Golem reports duplicate_owner first.
func _valid_roster(party: CombatParty) -> bool:
	if not party.is_valid() or party._heroes.size() != CombatParty.PARTY_SIZE:
		return false
	for index in range(CombatParty.PARTY_SIZE):
		var hero: Variant = party._heroes[index]
		if not hero is Dictionary:
			return false
		var hero_dict: Dictionary = hero
		var hero_position: Variant = hero_dict.get("position")
		if not hero_position is int or hero_position != index + 1:
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
		var block: Variant = hero_dict.get("block")
		if not block is int or block < 0:
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


## Fail closed on a malformed authoritative status map anywhere in the shared party.
func _valid_statuses(party: CombatParty) -> bool:
	return CombatStatusTurnBatch.new().tick_side("heroes", party.get_heroes()).get("ok", false)


## V3-2 Tangled N: a positive integer count blocks this allied move for the actor whether it is
## the mover or the one being moved. Absent statuses or an absent key mean no active Tangled,
## and zero means expired. Any other stored value is malformed and rejects the play instead of
## being coerced into a legal stack.
func _tangled_blocks(actor: Dictionary) -> bool:
	var statuses = actor.get("statuses")
	if statuses == null:
		return false
	if not statuses is Dictionary:
		return true
	if not statuses.has("tangled"):
		return false
	var count = statuses["tangled"]
	if not count is int:
		return true
	return count != 0
