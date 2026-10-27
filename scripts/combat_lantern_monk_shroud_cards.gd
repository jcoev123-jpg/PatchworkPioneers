class_name CombatLanternMonkShroudCards
extends RefCounted
## Scene-free paid resolver for the Lantern Monk's ally-targeting Moth Shroud printings (V3-1).
##
## Moth Shroud is a v3 UNCOMMON reward; both printings cost 1, come only from the Monk's middle or
## rear seat (FROM [2, 3]) and print `target_kind: "ally_single"` with no enemy positions. The round
## lantern-bearing monk's moths wrap ONE chosen living ally: that ally gains a little Block (6, or 8
## upgraded) and the one-shot Dodge token, so the very next incoming attack aimed at that ally misses
## and spends the token. Casting the card never spends Dodge: the token stays armed until the real
## attack-owner rule (`CombatWardenGuardReactions`, Guard redirect included) resolves an attempt.
##
## The catalog stays authoritative: the caller supplies only the held card ID and the ally's party
## seat, never a cost, Block amount or Dodge token. This service authenticates the exact ID against
## LanternMonkPoolCards (owner, ID, printed cost, FROM seats, empty TO seats, `ally_single`, the
## complete effect dictionary and the base/'+' link) before it charges anything.
##
## Dodge is an integer 0/1 token on the bearer's authoritative statuses dictionary. Re-applying Moth
## Shroud while Dodge is already active keeps it at 1 (`set`/keep, never a stack) and still awards
## the printed Block. Torn (0 HP) heroes are never a legal target and are never revived. Every other
## status, every hero's HP and seat, the draw/reshuffle piles and the injected run RNG stay exactly
## as they were.
##
## This is callable rules-layer behaviour only. It does not register these IDs in the live held-hand
## dispatcher, rewards or run deck, and no view is changed; that wiring is a later task.

const OWNER := "lantern_monk"
const TARGET_KIND := "ally_single"
const DODGE_STATUS_KEY := "dodge_next_attack"
const DODGE_TOKEN := 1

## The two authentic printings and the exact catalog line each one must still carry. Block is the
## only difference between a printing and its "+"; nothing else is supported.
const CARDS := {
	"lantern_monk_moth_shroud": {
		"cost": 1, "from_positions": [2, 3], "block": 6,
		"upgrade_id": "lantern_monk_moth_shroud_plus",
	},
	"lantern_monk_moth_shroud_plus": {
		"cost": 1, "from_positions": [2, 3], "block": 8,
		"upgrade_of": "lantern_monk_moth_shroud",
	},
}

## The status vocabulary the combat status rules accept as N-turn counters (int >= 0).
const COUNTER_STATUS_KEYS: Array[String] = ["bleed", "weak", "exposed", "tangled", "riposte"]
## One-shot integer tokens: absent or 0 is inert, 1 is armed. Nothing else is a legal shape.
const ONE_SHOT_STATUS_KEYS: Array[String] = ["dodge_next_attack", "blind_next_attack"]

var _catalog := LanternMonkPoolCards.new()


## The single paid transaction: authenticate, preflight every input, then charge the printed cost,
## discard exactly the held copy, add the printed Block to the chosen living ally and arm its
## one-shot Dodge token (kept at 1 if it was already armed). A refusal changes no deck, party or
## RNG state.
func play_card(deck: CombatDeck, party: CombatParty, card_id: Variant,
		target_position: int = 0) -> Dictionary:
	var plan: Dictionary = _prepare(deck, party, card_id, target_position)
	if not plan.get("ok", false):
		return _refusal(str(plan.get("reason", "refused")))
	# Every operation below is guaranteed by the complete preflight above: the turn is active, the
	# exact held ID is affordable, the owner sits in its authored seat, the whole roster and every
	# status map are well formed and the chosen ally is living with representable Block. Keep the
	# defensive returns so an unexpected model change still fails closed.
	if not deck.try_spend_energy(int(plan["cost"])):
		return _refusal("insufficient_energy")
	if not deck.discard_played(plan["card_id"]):
		return _refusal("card_not_held")
	if not party.gain_block(int(plan["target_position"]), int(plan["block"])):
		return _refusal("block_failed")

	# The real authoritative record, never a detached get_hero copy.
	var record: Dictionary = party._heroes[int(plan["target_position"]) - 1]
	var statuses: Dictionary = record.get("statuses", {})
	# Sets or keeps the one-shot token at 1; never a second stack, and never spent by this cast.
	statuses[DODGE_STATUS_KEY] = DODGE_TOKEN
	record["statuses"] = statuses

	return {
		"ok": true,
		"reason": "applied",
		"card_id": plan["card_id"],
		"cost": int(plan["cost"]),
		"owner_position": int(plan["owner_position"]),
		"target_kind": TARGET_KIND,
		"target_position": int(plan["target_position"]),
		"target_id": str(record["id"]),
		"self_target": int(plan["target_position"]) == int(plan["owner_position"]),
		"block": int(plan["block"]),
		"block_before": int(plan["block_before"]),
		"block_after": int(record["block"]),
		"dodge_before": int(plan["dodge_before"]),
		"dodge_after": DODGE_TOKEN,
		"dodge_already_active": int(plan["dodge_before"]) == DODGE_TOKEN,
		"energy_before": int(plan["energy_before"]),
		"energy_after": deck.energy,
	}


## True only for the two authentic catalog printings. Pure lookup; nothing is charged or mutated
## and no RNG is touched.
func is_supported_card(card_id: Variant) -> bool:
	if typeof(card_id) != TYPE_STRING:
		return false
	var id: String = card_id
	if not CARDS.has(id):
		return false
	return _authentic_pair(id, CARDS[id])


## Read-only preflight of the whole transaction. Returns a detached plan or a refusal receipt.
func _prepare(deck: CombatDeck, party: CombatParty, card_id: Variant,
		target_position: int) -> Dictionary:
	if deck == null or party == null:
		return _refusal("invalid_request")
	if deck.combat_state == null or deck._rng == null or not deck.turn_active:
		return _refusal("inactive_turn")
	if not party.is_valid() or party._heroes.size() != CombatParty.PARTY_SIZE:
		return _refusal("invalid_party")
	if typeof(card_id) != TYPE_STRING:
		return _refusal("unsupported_card")
	var id: String = card_id
	if not CARDS.has(id):
		return _refusal("unsupported_card")
	var card: Dictionary = CARDS[id]
	if not _authentic_pair(id, card):
		return _refusal("catalog_mismatch")
	# Hand membership is the actual held copy, never just a catalog lookup.
	if not deck.hand.has(id):
		return _refusal("card_not_held")
	var cost: int = int(card["cost"])
	if cost < 0 or deck.energy < cost:
		return _refusal("insufficient_energy")

	# Verify the complete roster and every hero's authoritative status shape, then bind the owner
	# by hero ID to its actual current slot. Swapping seats grants no false authority.
	var heroes: Array[Dictionary] = party.get_heroes()
	if heroes.size() != CombatParty.PARTY_SIZE:
		return _refusal("invalid_party")
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
		if not _valid_status_shape(hero.get("statuses", {})):
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

	# An ally_single card names exactly one living hero seat; the Monk may also veil itself.
	if target_position < 1 or target_position > CombatParty.PARTY_SIZE:
		return _refusal("invalid_target")
	var target: Dictionary = heroes[target_position - 1]
	if int(target["hp"]) == 0:
		return _refusal("target_downed")

	var block: int = int(card["block"])
	if block <= 0:
		return _refusal("catalog_mismatch")
	# gain_block must be guaranteed before charging: overflow otherwise rejects after payment.
	if block > CombatParty.MAX_INT - int(target["block"]):
		return _refusal("block_overflow")

	var target_statuses: Dictionary = target.get("statuses", {})
	return {
		"ok": true,
		"card_id": id,
		"cost": cost,
		"owner_position": owner_position,
		"target_position": target_position,
		"block": block,
		"block_before": int(target["block"]),
		"dodge_before": int(target_statuses.get(DODGE_STATUS_KEY, 0)),
		"energy_before": deck.energy,
	}


## The status shape the combat rules accept: named N-turn counters with non-negative int counts and
## the two one-shot tokens as integer 0/1. Anything else fails closed before any mutation.
func _valid_status_shape(statuses: Variant) -> bool:
	if not statuses is Dictionary:
		return false
	var values: Dictionary = statuses
	for name in values:
		if not name is String or (name as String).is_empty():
			return false
		var count = values[name]
		if not count is int:
			return false
		if name in ONE_SHOT_STATUS_KEYS:
			if int(count) != 0 and int(count) != 1:
				return false
			continue
		if not COUNTER_STATUS_KEYS.has(name) or int(count) < 0:
			return false
	return true


## Reads the exact authored record from LanternMonkPoolCards and proves both printings of the pair
## still carry their authored line, so a rewritten catalog (extra effect, another seat, target,
## cost or a broken upgrade link) can never be paid for as this effect.
func _authentic_pair(card_id: String, card: Dictionary) -> bool:
	var definition: Dictionary = _catalog_definition(card_id)
	if not _authentic_record(definition, card_id, card):
		return false
	if card.has("upgrade_id"):
		var plus_id: String = str(card["upgrade_id"])
		if not CARDS.has(plus_id):
			return false
		var plus: Dictionary = _catalog_definition(plus_id)
		if plus.get("upgrade_of") != card_id or plus.has("upgrade_id"):
			return false
		var plus_card: Dictionary = CARDS[plus_id]
		return _authentic_record(plus, plus_id, plus_card)
	var base_id: String = str(card["upgrade_of"])
	if not CARDS.has(base_id):
		return false
	var base: Dictionary = _catalog_definition(base_id)
	if base.get("upgrade_id") != card_id or base.has("upgrade_of"):
		return false
	var base_card: Dictionary = CARDS[base_id]
	return _authentic_record(base, base_id, base_card)


## The one catalog read of this service, so a test double can prove that a rewritten catalog
## record is refused rather than paid for. Production always reads the real Lantern Monk pool.
func _catalog_definition(card_id: String) -> Dictionary:
	return _catalog.get_definition(card_id)


func _authentic_record(definition: Dictionary, card_id: String, card: Dictionary) -> bool:
	if definition.get("id") != card_id or definition.get("owner") != OWNER:
		return false
	if not definition.get("cost") is int or int(definition.get("cost")) != int(card["cost"]):
		return false
	if definition.get("target_kind") != TARGET_KIND:
		return false
	if not _same_value(definition.get("from_positions"), card["from_positions"]):
		return false
	var to_positions = definition.get("to_positions")
	if not to_positions is Array or not (to_positions as Array).is_empty():
		return false
	var expected_effects: Dictionary = {
		"block": int(card["block"]),
		DODGE_STATUS_KEY: DODGE_TOKEN,
	}
	if not _same_value(definition.get("effects"), expected_effects):
		return false
	# The base and "+" records must still point at each other, so a copied or relinked record
	# cannot be paid for under the other printing's ID.
	if card.has("upgrade_id"):
		return definition.get("upgrade_id") == card["upgrade_id"] \
			and not definition.has("upgrade_of")
	return definition.get("upgrade_of") == card["upgrade_of"] \
		and not definition.has("upgrade_id")


## Typed equality rejects coercible metadata (e.g. a String "6" or a bool standing in for an int)
## as well as changed effects or upgrade links.
func _same_value(actual: Variant, expected: Variant) -> bool:
	if typeof(actual) != typeof(expected):
		return false
	if expected is Dictionary:
		var expected_dict: Dictionary = expected
		if actual.size() != expected_dict.size():
			return false
		for key in expected_dict:
			if not (actual as Dictionary).has(key):
				return false
			if not _same_value(actual[key], expected_dict[key]):
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


func _refusal(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
