class_name CombatButtonGolemPopCards
extends RefCounted
## V3-1 scene-free paid resolver for Button Golem's four Block-paid Pop Button printings.
##
## One successful call spends 1 energy, discards exactly one held copy, spends 5 of the
## Golem's own stored Block, deals the printed damage through the ordinary
## Block-before-HP and status-adjusted attack rules, and counts one popped button on
## that Golem's authoritative per-combat hero record.
##
## The file also owns the callable Button Plating start-of-turn rule (2 ordinary Block to the
## single living Golem) beside that paid Pop resolver. It is a preparatory rules entrypoint: the
## mounted turn flow must call it immediately AFTER CombatParty.start_player_turn() with that
## path's real turn ordinal, and no live caller does yet.
##
## Data only elsewhere: the starter and reward catalogs are descriptor-only and no live
## hand, party-picker, reward or map path registers these IDs yet. This helper is the
## callable combat rules layer a later wiring task must call, never a second live attack
## system and never a run-wallet/spend path.
##
## The four printings are intentionally split across two catalogs with different effect
## key names for the same Block-spending operation, so each card is authenticated against
## its own authored catalog record and printed magnitude, not a caller-supplied
## effect dictionary.

const OWNER_ID := "button_golem"
const COST := 1
const BLOCK_COST := 5
const BUTTONS_KEY := "buttons_popped"
## Authored Button Plating passive: start of each of the player's turns, gain 2 Block.
const PLATING_BLOCK := 2
## Combat-local marker on the Golem's own party record: the last turn ordinal it was granted.
const PLATING_TURN_KEY := "button_plating_turn"
const FROM_POSITIONS: Array[int] = [1, 2]
const TO_POSITIONS: Array[int] = [1, 2]

## Exact authored printings. Starter and reward catalogs keep distinct key names.
const STARTER_PRINTINGS := {
	"button_golem_starter_loose_pop": 9,
	"button_golem_starter_loose_pop_plus": 11,
}
const POOL_PRINTINGS := {
	"button_golem_pop_button": 9,
	"button_golem_pop_button_plus": 12,
}


## Pure query: an authentic Pop Button printing ID, never a malformed or aliased value.
func is_supported_card(card_id: Variant) -> bool:
	return typeof(card_id) == TYPE_STRING \
		and (STARTER_PRINTINGS.has(card_id) or POOL_PRINTINGS.has(card_id))


## Paid resolution against real model state. Refusals return a receipt with exactly the
## same field set, reason "..." and no state change at all: no energy, card, Block, HP,
## button count or seeded RNG draw.
func play_card(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: String, target_position: int) -> Dictionary:
	var plan: Dictionary = _prepare(deck, party, enemies, card_id, target_position)
	if not plan["ok"]:
		return plan
	# Every operation below is guaranteed by preflight and nothing here draws RNG.
	deck.try_spend_energy(plan["cost"])
	deck.discard_played(card_id)
	var owner: Dictionary = party._heroes[plan["owner_position"] - 1]
	owner["block"] -= BLOCK_COST
	var enemy: Dictionary = enemies.get_enemy(plan["target_position"])
	var absorbed: int = mini(enemy["block"], plan["damage"])
	var hp_loss: int = mini(enemy["hp"], plan["damage"] - absorbed)
	enemies.apply_damage(plan["target_position"], plan["damage"])
	# One successful Pop counts even when the enemy's Block absorbs the whole hit.
	owner[BUTTONS_KEY] = int(owner.get(BUTTONS_KEY, 0)) + 1
	plan["reason"] = "applied"
	plan["block_spent"] = BLOCK_COST
	plan["block_absorbed"] = absorbed
	plan["hp_loss"] = hp_loss
	plan["buttons_popped"] = owner[BUTTONS_KEY]
	return plan


## Button Plating: the authored start-of-player-turn passive of the Button Golem.
##
## Call immediately after a successful CombatParty.start_player_turn(), which is the reset
## boundary that clears the previous turn's Block for every hero. A valid, unique and living
## Golem may sit in any of the three real seats; it is bound by its unique ID, never by the
## canonical default seat 1. One successful call adds exactly 2 ordinary Block to that Golem
## and nothing to either other hero, and remembers the applied turn ordinal on that Golem's
## own combat-local party record. The same or an older ordinal can never grant Block twice.
##
## This helper never resets Block, spends energy, moves a card, draws, touches an enemy, pops a
## button, adds a Quilt contribution or consumes RNG: it only gains Block and marks the turn,
## and it marks the turn only when that gain actually succeeded. Every refusal returns the same
## field set with reason "..." and changes nothing at all.
func apply_button_plating_start_turn(party: CombatParty, turn_ordinal: int) -> Dictionary:
	var receipt := {
		"ok": false, "reason": "invalid_request", "owner_position": 0,
		"turn_ordinal": turn_ordinal, "block_gained": 0, "block_after": 0,
		"previous_turn_ordinal": 0,
	}
	if party == null:
		return receipt
	receipt["reason"] = "invalid_roster"
	if not _valid_roster(party):
		return receipt
	# Bind the Golem to its actual current ID/seat; never assume the canonical seat 1.
	var owner_position := 0
	for hero: Dictionary in party._heroes:
		if hero.get("id") != OWNER_ID:
			continue
		if owner_position != 0:
			receipt["reason"] = "duplicate_owner"
			return receipt
		owner_position = int(hero["position"])
	if owner_position == 0:
		receipt["reason"] = "owner_missing"
		return receipt
	if not _distinct_hero_ids(party):
		receipt["reason"] = "invalid_roster"
		return receipt
	var owner: Dictionary = party._heroes[owner_position - 1]
	if owner["hp"] <= 0:
		receipt["reason"] = "owner_torn"
		return receipt
	if turn_ordinal <= 0:
		receipt["reason"] = "invalid_turn_ordinal"
		return receipt
	var marker: Variant = owner.get(PLATING_TURN_KEY, 0)
	if not marker is int or marker < 0:
		receipt["reason"] = "malformed_turn_marker"
		return receipt
	receipt["previous_turn_ordinal"] = marker
	# The same ordinal, or any older one, is a replayed/stale request.
	if turn_ordinal <= marker:
		receipt["reason"] = "duplicate_turn"
		return receipt
	var block_value: Variant = owner.get("block")
	if not block_value is int or block_value < 0:
		receipt["reason"] = "malformed_block"
		return receipt
	var block_now: int = block_value
	if PLATING_BLOCK > CombatParty.MAX_INT - block_now:
		receipt["reason"] = "block_overflow"
		return receipt
	# gain_block is the authoritative writer; the turn marker follows a real gain only.
	if not party.gain_block(owner_position, PLATING_BLOCK):
		receipt["reason"] = "block_refused"
		return receipt
	owner[PLATING_TURN_KEY] = turn_ordinal
	receipt["ok"] = true
	receipt["reason"] = "applied"
	receipt["owner_position"] = owner_position
	receipt["block_gained"] = PLATING_BLOCK
	receipt["block_after"] = block_now + PLATING_BLOCK
	return receipt


func _prepare(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: String, target_position: int) -> Dictionary:
	var plan := {
		"ok": false, "reason": "unsupported_card", "card_id": card_id,
		"target_position": target_position, "cost": 0, "owner_position": 0,
		"damage": 0, "block_spent": 0, "block_absorbed": 0, "hp_loss": 0,
		"buttons_popped": 0,
	}
	if not is_supported_card(card_id):
		return plan
	var printed: Dictionary = _authenticate(card_id)
	if printed.is_empty():
		plan["reason"] = "catalog_mismatch"
		return plan
	plan["cost"] = COST
	if deck == null or party == null or enemies == null:
		plan["reason"] = "invalid_request"
		return plan
	if deck.combat_state == null:
		plan["reason"] = "invalid_deck"
		return plan
	if not party.is_valid() or not enemies.is_valid():
		plan["reason"] = "invalid_roster"
		return plan
	# Authoritative status/roster data must be well formed before any payment. The
	# shared turn-batch validator applies the exact CombatStatuses keys and counts.
	if not _valid_status_rosters(party, enemies):
		plan["reason"] = "malformed_statuses"
		return plan
	if not deck.turn_active:
		plan["reason"] = "inactive_turn"
		return plan

	# Bind the Golem to its actual ID/position; never assume a fixed slot.
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
	plan["owner_position"] = owner_position
	var owner: Dictionary = party._heroes[owner_position - 1]
	if owner["hp"] <= 0:
		plan["reason"] = "owner_torn"
		return plan
	if not FROM_POSITIONS.has(owner_position):
		plan["reason"] = "invalid_owner_position"
		return plan
	if owner["block"] < BLOCK_COST:
		plan["reason"] = "insufficient_block"
		return plan
	var button_count: Variant = owner.get(BUTTONS_KEY, 0)
	if not button_count is int or button_count < 0 \
			or button_count > CombatParty.MAX_INT - 1:
		plan["reason"] = "malformed_button_count"
		return plan
	if not deck.hand.has(card_id):
		plan["reason"] = "card_not_held"
		return plan
	if deck.energy < COST:
		plan["reason"] = "insufficient_energy"
		return plan

	if not TO_POSITIONS.has(target_position):
		plan["reason"] = "invalid_target"
		return plan
	var target: Dictionary = enemies.get_enemy(target_position)
	if target.is_empty() or enemies.is_slain(target_position):
		plan["reason"] = "invalid_target"
		return plan
	plan["damage"] = CombatStatuses.new().adjusted_attack_damage(
		printed["damage"], owner.get("statuses", {}), target.get("statuses", {}))
	if plan["damage"] <= 0:
		plan["reason"] = "invalid_damage"
		return plan
	plan["ok"] = true
	plan["reason"] = "ready"
	return plan


## Authenticate one printing through its own authored catalog. Returns {"damage": N} or {}.
func _authenticate(card_id: String) -> Dictionary:
	if STARTER_PRINTINGS.has(card_id):
		var starter_damage: int = STARTER_PRINTINGS[card_id]
		var starter_effects := {"spend_block": BLOCK_COST, "damage": starter_damage,
			"buttons_popped": 1}
		if _matches_authored(ButtonGolemStarterCards.new().get_definition(card_id),
				card_id, starter_effects):
			return {"damage": starter_damage}
		return {}
	if POOL_PRINTINGS.has(card_id):
		var pool_damage: int = POOL_PRINTINGS[card_id]
		var pool_effects := {"require_owner_block": BLOCK_COST,
			"spend_owner_block": BLOCK_COST, "damage": pool_damage,
			"buttons_popped_gain": 1}
		if _matches_authored(ButtonGolemPoolCards.new().get_definition(card_id),
				card_id, pool_effects):
			return {"damage": pool_damage}
	return {}


## Exact contract for one record: identity, owner, energy cost, enemy-single FROM/TO
## slots 1-2 and the complete printed effect set with integer magnitudes.
func _matches_authored(definition: Dictionary, card_id: String,
		expected_effects: Dictionary) -> bool:
	if definition.is_empty() or definition.get("id") != card_id:
		return false
	if definition.get("owner") != OWNER_ID:
		return false
	var cost: Variant = definition.get("cost")
	if not cost is int or cost != COST:
		return false
	if definition.get("target_kind") != "enemy_single":
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


func _exact_positions(value: Variant, expected: Array[int]) -> bool:
	if not value is Array or value.size() != expected.size():
		return false
	for index in range(expected.size()):
		if not value[index] is int or value[index] != expected[index]:
			return false
	return true


## Fail closed on a malformed authoritative status map on either side.
func _valid_status_rosters(party: CombatParty, enemies: CombatEnemies) -> bool:
	var batch := CombatStatusTurnBatch.new()
	if not batch.tick_side("heroes", party.get_heroes()).get("ok", false):
		return false
	return batch.tick_side("enemies", enemies.get_enemies()).get("ok", false)


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

