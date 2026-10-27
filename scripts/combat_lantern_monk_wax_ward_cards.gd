class_name CombatLanternMonkWaxWardCards
extends RefCounted
## Scene-free paid self-Block resolver for the Lantern Monk's Wax Ward printings (V3-1).
##
## Wax Ward is the v3 COMMON reward-pool card that carries the Monk's lantern/wax protection look:
## the round, robed healer cups the warm wax over himself instead of swinging at anyone. Both
## printings cost 1, come from every seat the Monk can hold (`from_positions: [1, 2, 3]`), name
## only the owner (`target_kind: "self"`, no enemy positions) and print exactly `{"block": 5}`
## (base) or `{"block": 7}` ('+'). Nothing else is included: no damage, heal, draw, cleanse, Blind,
## Dodge, Exhaust, enemy effect or status change.
##
## The catalog stays authoritative: the caller supplies only the held card ID, never a cost, Block
## amount, seat or effect map. This service authenticates the exact ID against LanternMonkPoolCards
## (owner, printed cost, FROM seats, empty TO line, `self` target, the complete effect dictionary,
## the base/'+' upgrade link and the reward flags) before it charges anything.
##
## A self card names exactly one recipient: its owner. The self target is the sentinel 0 and always
## resolves to the Monk's CURRENT seat, so moving him between seats 1-3 never changes the effect.
## A position 1-3 argument is not a target choice here and is always refused, as is every other
## explicit nonzero target. A prior Block total adds to the printed amount instead of resetting it.
##
## This is callable rules-layer behaviour only. It does not register these IDs in the live
## held-hand dispatcher, rewards or run deck, and no view is changed; that wiring is a later task.

const OWNER := "lantern_monk"
const TARGET_KIND := "self"
const SELF_TARGET := 0

## The two authentic printings and the exact catalog line each one must still carry. Block is the
## only difference between a printing and its "+"; nothing else is supported.
const CARDS := {
	"lantern_monk_wax_ward": {
		"cost": 1, "block": 5, "from_positions": [1, 2, 3],
		"starting_copies": 0, "reward_eligible": true,
		"upgrade_id": "lantern_monk_wax_ward_plus",
	},
	"lantern_monk_wax_ward_plus": {
		"cost": 1, "block": 7, "from_positions": [1, 2, 3],
		"starting_copies": 0, "reward_eligible": false,
		"upgrade_of": "lantern_monk_wax_ward",
	},
}

## Kept as a dynamic handle so a test double can prove that a rewritten catalog record is
## refused; production always reads the real Lantern Monk pool.
var _catalog: Variant = LanternMonkPoolCards.new()


## The single paid transaction: authenticate, preflight every input, then charge the printed cost,
## discard exactly the held copy and add the printed Block to the Monk's own current seat. A
## refusal changes no deck, party, status or RNG state.
##
## `target_position` must stay the self sentinel 0: a self card selects no ally, enemy or seat.
## Any nonzero value (including the Monk's own seat) is an invalid request and is refused before
## payment.
func play_card(deck: CombatDeck, party: CombatParty, card_id: Variant,
		target_position: int = 0) -> Dictionary:
	var plan: Dictionary = _prepare(deck, party, card_id, target_position)
	if not plan.get("ok", false):
		return _refusal(str(plan.get("reason", "refused")))
	# Every operation below is guaranteed by the complete preflight above: the turn is active, the
	# exact held ID is affordable, the unique living Monk sits in an authored seat, the whole roster
	# and every status map are well formed and the resulting Block is representable. Keep the
	# defensive returns so an unexpected model change still fails closed.
	if not deck.try_spend_energy(int(plan["cost"])):
		return _refusal("insufficient_energy")
	if not deck.discard_played(plan["card_id"]):
		return _refusal("card_not_held")
	if not party.gain_block(int(plan["owner_position"]), int(plan["block_gained"])):
		return _refusal("block_failed")

	# The real authoritative record, never a detached get_hero copy.
	var record: Dictionary = party._heroes[int(plan["owner_position"]) - 1]
	return {
		"ok": true,
		"reason": "applied",
		"card_id": plan["card_id"],
		"cost": int(plan["cost"]),
		"owner_position": int(plan["owner_position"]),
		"target_kind": TARGET_KIND,
		"target_position": SELF_TARGET,
		"block_gained": int(plan["block_gained"]),
		"block_before": int(plan["block_before"]),
		"block_after": int(record["block"]),
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

	# Verify the complete roster and every hero's authoritative status shape, then bind the unique
	# owner by hero ID to its actual current slot. Swapping seats grants no false authority.
	var heroes: Array[Dictionary] = party.get_heroes()
	if heroes.size() != CombatParty.PARTY_SIZE:
		return _refusal("invalid_party")
	var owner_position := 0
	var owners := 0
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
			owners += 1
			owner_position = index + 1

	if owners != 1:
		return _refusal("owner_missing" if owners == 0 else "duplicate_owner")
	if not card["from_positions"].has(owner_position):
		return _refusal("owner_illegal_position")
	var owner: Dictionary = heroes[owner_position - 1]
	if int(owner["hp"]) == 0:
		return _refusal("owner_downed")

	# A self card has exactly one legal target request: the implicit self sentinel. An explicit
	# seat is not a target choice, so 1-3 and every out-of-range value fail closed before payment.
	if target_position != SELF_TARGET:
		return _refusal("invalid_target")

	var block_gained: int = int(card["block"])
	if block_gained <= 0:
		return _refusal("catalog_mismatch")
	# gain_block must be guaranteed before charging: overflow otherwise rejects after payment.
	if block_gained > CombatParty.MAX_INT - int(owner["block"]):
		return _refusal("block_overflow")

	return {
		"ok": true,
		"card_id": id,
		"cost": cost,
		"owner_position": owner_position,
		"block_gained": block_gained,
		"block_before": int(owner["block"]),
		"energy_before": deck.energy,
	}


## Reads the exact authored record from LanternMonkPoolCards and proves both printings of the pair
## still carry their authored line, so a rewritten catalog (extra effect, another seat, another
## target, another cost, changed flags or a broken upgrade link) can never be paid for as this
## effect.
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
	var expected := {
		"id": card_id,
		"owner": OWNER,
		"cost": int(card["cost"]),
		"target_kind": TARGET_KIND,
		"from_positions": card["from_positions"],
		"to_positions": [],
		"effects": {"block": int(card["block"])},
		"starting_copies": int(card["starting_copies"]),
		"reward_eligible": bool(card["reward_eligible"]),
	}
	for field in expected:
		if not definition.has(field) or not _same_value(definition[field], expected[field]):
			return false
	# The base and '+' records must still point at each other, so a copied or relinked record
	# cannot be paid for under the other printing's ID.
	if card.has("upgrade_id"):
		return definition.get("upgrade_id") == card["upgrade_id"] \
			and not definition.has("upgrade_of")
	return definition.get("upgrade_of") == card["upgrade_of"] \
		and not definition.has("upgrade_id")


## Typed equality rejects coercible metadata (e.g. a String "5" or a bool standing in for an int)
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
