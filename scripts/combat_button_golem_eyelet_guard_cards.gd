class_name CombatButtonGolemEyeletGuardCards
extends RefCounted
## V3-1 scene-free paid resolver for Button Golem's two Eyelet Guard reward-pool printings.
##
## One successful call spends 1 energy, discards exactly one genuinely held copy, gives the casting
## Golem the printed Block (6 base / 9 upgraded) and arms its printed Thorns (2 / 3) for one turn.
## The Golem is bound by IDENTITY, never by a fixed seat: Eyelet Guard plays from any of the
## catalog's FROM seats 1-3 and the armed effect follows the same actor after a legal Button Roll.
## A torn (0 HP) Golem can neither cast nor retaliate.
##
## V3-2 Thorns N is NOT a CombatStatuses counter. The shared status vocabulary has no hero Thorns
## stack, so this helper never writes a `thorns` key into a hero's status map. Instead it keeps a
## fight-scoped armed mode on the instance that owns one battle (the future wiring step creates one
## per fight and calls expire_on_next_player_turn at the next player-turn boundary). Duration 1
## means armed through the ensuing enemy turn and cleared on the NEXT player turn; re-arming
## refreshes (replaces) the value instead of summing stacks.
##
## The armed bearer does not apply its own retaliation here. project_contact() is a READ-ONLY
## projection for the future enemy-attack owner: it reports N for every confirmed positive-damage
## hit against the armed, living bearer, and zero for hits on any other hero, on an unarmed bearer,
## on a torn bearer or for a contact the caller has not confirmed. It never mutates HP, Block,
## energy, piles, the armed mode or the seeded RNG, and it invents no second CombatEnemies attack
## path.
##
## Data only elsewhere: button_golem_pool_cards.gd owns the two IDs, their base/"+" link and their
## art paths, but no live hand, reward, party-picker, map or app path registers them yet. This
## helper is the callable combat rules layer a later wiring task must call, never a second live
## hand and never a run-wallet or standalone spell-currency path.
##
## Every failing precondition is refused by a complete read-only preflight BEFORE the energy charge,
## and no resolution path draws seeded RNG.

const OWNER_ID := "button_golem"
const COST := 1
const TARGET_KIND := "self"
## A self card selects no seat; the Golem's own bound seat is the only legal recipient.
const SELF_TARGET := 0
const FROM_POSITIONS: Array[int] = [1, 2, 3]
const TO_POSITIONS: Array[int] = []
const DURATION := 1

## The two authentic pool printings, each with the exact line it must still carry. The complete
## printed effect set is base {"block": 6, "thorns": 2, "duration": 1} and upgraded
## {"block": 9, "thorns": 3, "duration": 1}; both cost one energy and are authored `self`.
const PRINTINGS := {
	"button_golem_eyelet_guard": {
		"name": "Eyelet Guard",
		"block": 6,
		"thorns": 2,
		"upgrade_id": "button_golem_eyelet_guard_plus",
	},
	"button_golem_eyelet_guard_plus": {
		"name": "Eyelet Guard+",
		"block": 9,
		"thorns": 3,
		"upgrade_of": "button_golem_eyelet_guard",
	},
}

## Fight-scoped armed Thorns: one battle owns one resolver instance. The value is never a status
## stack and is refreshed, not summed, by a second Eyelet Guard.
var _armed: bool = false
var _armed_thorns: int = 0


## Pure query: an authentic Eyelet Guard printing ID, never a malformed or aliased value.
func is_supported_card(card_id: Variant) -> bool:
	return typeof(card_id) == TYPE_STRING and PRINTINGS.has(card_id)


## True while this fight's armed Thorns is live (after a successful play, before the next
## player-turn boundary).
func is_armed() -> bool:
	return _armed and _armed_thorns > 0


## The live armed retaliation value, or 0 when the mode is not live.
func get_armed_thorns() -> int:
	return _armed_thorns if _armed else 0


## Clear the armed mode for a new fight. A fresh battle never inherits an old arming.
func reset_fight() -> void:
	_armed = false
	_armed_thorns = 0


## Duration 1: called at the NEXT player-turn boundary, the arming expires. Idempotent and
## read-only towards the deck, party and RNG; it only clears this helper's armed mode.
func expire_on_next_player_turn() -> Dictionary:
	var was_armed: bool = _armed
	var expired: int = _armed_thorns if _armed else 0
	_armed = false
	_armed_thorns = 0
	return {"ok": true, "expired": was_armed, "thorns_expired": expired}


## Paid resolution against real model state. Refusals return a receipt with exactly the same field
## set, reason "...", and no state change at all: no energy, card, Block, HP, status, deck pile,
## armed mode or seeded RNG draw.
func play_card(deck: CombatDeck, party: CombatParty, card_id: Variant,
		target_position: int = SELF_TARGET) -> Dictionary:
	var plan: Dictionary = _prepare(deck, party, card_id, target_position)
	if not plan["ok"]:
		return plan
	# Every operation below is guaranteed by preflight and nothing here draws RNG.
	deck.try_spend_energy(int(plan["cost"]))
	plan["energy_spent"] = int(plan["cost"])
	deck.discard_played(plan["card_id"])
	party.gain_block(int(plan["owner_position"]), int(plan["block_gained"]))
	# Re-arm refreshes the printed value and the one-turn duration; it never sums stacks.
	_armed = true
	_armed_thorns = int(plan["thorns_gained"])
	plan["thorns_active"] = _armed_thorns
	plan["block_after"] = int(party.get_hero(int(plan["owner_position"])).get("block", 0))
	plan["reason"] = "applied"
	return plan


## Read-only projection for the future enemy-attack owner. A confirmed positive-damage hit
## against the armed, living bearer reports the armed N; every other contact reports zero. The
## caller applies the reported retaliation through its own attack path. No state is consumed.
func project_contact(party: CombatParty, target_position: int, damage: int,
		confirmed: bool = true) -> Dictionary:
	var receipt := {
		"ok": false, "applied": false, "reason": "invalid_roster",
		"thorns": 0, "target_position": target_position, "bearer_position": 0,
		"duration": 0,
	}
	if party == null or not _valid_roster(party):
		return receipt
	var owner_position := _owner_position(party)
	if owner_position < 0:
		receipt["reason"] = "duplicate_owner"
		return receipt
	if owner_position == 0:
		receipt["reason"] = "owner_missing"
		return receipt
	receipt["bearer_position"] = owner_position
	receipt["ok"] = true
	# A hit on any other (or impossible) seat is never the bearer's contact.
	if target_position != owner_position:
		receipt["reason"] = "not_bearer"
		return receipt
	if not is_armed():
		receipt["reason"] = "not_armed"
		return receipt
	if party.is_downed(owner_position):
		receipt["reason"] = "owner_torn"
		return receipt
	if not confirmed or damage <= 0:
		receipt["reason"] = "no_contact"
		return receipt
	receipt["applied"] = true
	receipt["thorns"] = _armed_thorns
	receipt["duration"] = DURATION
	receipt["reason"] = "applied"
	return receipt


## Read-only preflight: authenticate the card against its authored pool pair, bind the Golem to
## its actual seat, validate the shared status vocabulary and the post-Block overflow before
## anything is charged.
func _prepare(deck: CombatDeck, party: CombatParty, card_id: Variant,
		target_position: int) -> Dictionary:
	var plan := {
		"ok": false, "reason": "unsupported_card",
		"card_id": card_id if typeof(card_id) == TYPE_STRING else "",
		"cost": 0, "energy_spent": 0, "owner_position": 0,
		"target_position": target_position,
		"block_gained": 0, "block_after": 0,
		"thorns_gained": 0, "thorns_active": 0, "duration": 0,
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
	var owner_position: int = _owner_position(party)
	if owner_position < 0:
		plan["reason"] = "duplicate_owner"
		return plan
	if owner_position == 0:
		plan["reason"] = "owner_missing"
		return plan
	plan["owner_position"] = owner_position
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
	# Authored `self` with an empty TO list: an extra selected seat is unlawful.
	if target_position != SELF_TARGET:
		plan["reason"] = "invalid_target"
		return plan

	var block_now: int = int(owner["block"])
	var gain: int = int(printed["block"])
	if gain > CombatParty.MAX_INT - block_now:
		plan["reason"] = "block_overflow"
		return plan
	plan["block_gained"] = gain
	plan["block_after"] = block_now + gain
	plan["thorns_gained"] = int(printed["thorns"])
	plan["duration"] = DURATION
	plan["ok"] = true
	plan["reason"] = "ready"
	return plan


## Authenticate the Eyelet Guard pair through the authored pool catalog. Both records of the pair
## must still carry their exact authored line and point at each other, so a rewritten, relinked or
## unauthentic record is never paid for. Returns {"block": N, "thorns": M} or {}.
func _authenticate(card_id: String) -> Dictionary:
	var base_id: String = card_id.trim_suffix("_plus")
	var plus_id: String = base_id + "_plus"
	if not PRINTINGS.has(base_id) or not PRINTINGS.has(plus_id):
		return {}
	var base_record: Dictionary = _catalog_definition(base_id)
	var plus_record: Dictionary = _catalog_definition(plus_id)
	if not _matches_authored(base_record, base_id, false):
		return {}
	if not _matches_authored(plus_record, plus_id, true):
		return {}
	if base_record.get("upgrade_id") != plus_id:
		return {}
	if plus_record.get("upgrade_of") != base_id:
		return {}
	var spec: Dictionary = PRINTINGS[card_id]
	return {"block": int(spec["block"]), "thorns": int(spec["thorns"])}


## The one authored record for an ID, detached. A subclass may serve a forged record so a
## rewritten catalog can be proven inert before any energy, hand, Block or RNG state moves.
func _catalog_definition(card_id: String) -> Dictionary:
	return ButtonGolemPoolCards.new().get_definition(card_id)


## Exact contract for one record: identity, printed name, Golem owner, one-energy cost, the
## `self` target with FROM 1-3 and empty TO, the complete printed effect set with exact Variant
## types and magnitudes, no starter copies, authored reward eligibility and the pair link the
## catalog authors. Rarity is deliberately not part of the combat contract.
func _matches_authored(definition: Dictionary, card_id: String, upgraded: bool) -> bool:
	if definition.is_empty() or definition.get("id") != card_id:
		return false
	if definition.get("owner") != OWNER_ID:
		return false
	var base_id: String = card_id.trim_suffix("_plus")
	var spec: Dictionary = PRINTINGS[card_id]
	if definition.get("display_name") != str(spec["name"]):
		return false
	var cost: Variant = definition.get("cost")
	if not cost is int or cost != COST:
		return false
	if definition.get("target_kind") != TARGET_KIND:
		return false
	if not _exact_positions(definition.get("from_positions"), FROM_POSITIONS):
		return false
	if not _exact_positions(definition.get("to_positions"), TO_POSITIONS):
		return false
	var effects_value: Variant = definition.get("effects")
	if not effects_value is Dictionary:
		return false
	var effects: Dictionary = effects_value
	var expected_effects: Dictionary = {
		"block": int(spec["block"]),
		"thorns": int(spec["thorns"]),
		"duration": DURATION,
	}
	if effects.size() != expected_effects.size():
		return false
	for key: String in expected_effects:
		if not effects.has(key):
			return false
		var value: Variant = effects[key]
		var expected: Variant = expected_effects[key]
		if typeof(value) != typeof(expected) or value != expected:
			return false
	var starting_copies: Variant = definition.get("starting_copies")
	if not starting_copies is int or starting_copies != 0:
		return false
	var reward_eligible: Variant = definition.get("reward_eligible")
	if not reward_eligible is bool or reward_eligible != (not upgraded):
		return false
	if upgraded:
		return definition.get("upgrade_of") == base_id and not definition.has("upgrade_id")
	var plus_id: String = base_id + "_plus"
	return definition.get("upgrade_id") == plus_id and not definition.has("upgrade_of")


func _exact_positions(value: Variant, expected: Array[int]) -> bool:
	if not value is Array or value.size() != expected.size():
		return false
	for index in range(expected.size()):
		if not value[index] is int or value[index] != expected[index]:
			return false
	return true


## The bound Golem's current seat, 0 when absent and -1 when the roster carries a second one.
func _owner_position(party: CombatParty) -> int:
	var owner_position := 0
	for hero: Dictionary in party._heroes:
		if hero.get("id") != OWNER_ID:
			continue
		if owner_position != 0:
			return -1
		owner_position = int(hero["position"])
	return owner_position


## Three genuine seats in order with nonempty string IDs and sane per-combat records.
## ID uniqueness is checked separately so a second Golem reports duplicate_owner first.
func _valid_roster(party: CombatParty) -> bool:
	if not party.is_valid() or party._heroes.size() != CombatParty.PARTY_SIZE:
		return false
	for index in range(CombatParty.PARTY_SIZE):
		var hero: Variant = party._heroes[index]
		if not hero is Dictionary:
			return false
		var record: Dictionary = hero
		var hero_id: Variant = record.get("id")
		if not hero_id is String or hero_id.is_empty():
			return false
		var position: Variant = record.get("position")
		if not position is int or position != index + 1:
			return false
		var max_hp: Variant = record.get("max_hp")
		if not max_hp is int or max_hp <= 0:
			return false
		var hp: Variant = record.get("hp")
		if not hp is int or hp < 0 or hp > max_hp:
			return false
		var block: Variant = record.get("block")
		if not block is int or block < 0:
			return false
		var statuses: Variant = record.get("statuses", {})
		if not statuses is Dictionary:
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
