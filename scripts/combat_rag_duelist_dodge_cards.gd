class_name CombatRagDuelistDodgeCards
extends RefCounted
## Scene-free paid resolver for the Rag Duelist's cape self-Dodge printings (V3-1).
##
## Cape Slip is a v3 starter and Cape Flourish is a v3 reward-pool card. Both printings of each cost
## their card's printed cost (1, or 0 for the '+' upgrade), come from every seat the Duelist can hold
## (`from_positions: [1, 2, 3]`), name only the owner (`target_kind: "self"`, no enemy positions) and
## print exactly `{"dodge_next_attack": 1, "duration": 1}`: the Duelist's tattered cape slips the very
## next incoming attack aimed at him, once, during his own turn. No printing grants Block, damage, a
## draw or a permanent Dodge.
##
## Dodge stays the established actor-local one-shot token: an INTEGER 1 (armed) or 0 (inert) in the
## owner's authoritative statuses dictionary, never a stack, a duration counter or a bool. This service
## only applies/refreshes it to 1 and leaves every unrelated status exactly as it was. It deliberately
## implements no second consumer and no Dodge clock: `CombatStatuses.dodge_project_for_attempt` owns
## first-attempt consumption and `CombatStatuses.end_owner_turn` owns removal of an unspent one-turn
## token, unchanged.
##
## This service authenticates the exact held ID against the catalog that owns it (owner, ID, printed
## cost, FROM seats, self target, empty TO line, the complete effect dictionary and the base/'+' link)
## and never trusts caller-supplied cost or effects. It then resolves against the real shared CombatDeck
## and CombatParty: one printed energy charge, one held copy discarded and the one-shot Dodge written to
## the owning hero's own record. A refusal changes no deck, party, status or seeded RNG state.
##
## Callable rules service only. These four IDs are not yet admitted to the live battle hand, the reward
## pool or any app flow; that wiring is a later task. No scene, no art and no card definition lives here.

const OWNER := "rag_duelist"
const TARGET_KIND := "self"
const DODGE_STATUS_KEY := "dodge_next_attack"
const DODGE_TOKEN := 1

## The four authentic printings, the catalog that owns each one and the exact authored line each must
## still carry. All four are self-only capes from any seat; only the printed cost differs between a
## printing and its '+'.
const CARDS := {
	"rag_duelist_cape_slip": {
		"catalog": "starter", "cost": 1, "from_positions": [1, 2, 3],
		"upgrade_id": "rag_duelist_cape_slip_plus",
	},
	"rag_duelist_cape_slip_plus": {
		"catalog": "starter", "cost": 0, "from_positions": [1, 2, 3],
		"upgrade_of": "rag_duelist_cape_slip",
	},
	"rag_duelist_cape_flourish": {
		"catalog": "pool", "cost": 1, "from_positions": [1, 2, 3],
		"upgrade_id": "rag_duelist_cape_flourish_plus",
	},
	"rag_duelist_cape_flourish_plus": {
		"catalog": "pool", "cost": 0, "from_positions": [1, 2, 3],
		"upgrade_of": "rag_duelist_cape_flourish",
	},
}

## The status vocabulary the combat status rules accept as N-turn counters (int >= 0).
const COUNTER_STATUS_KEYS: Array[String] = ["bleed", "weak", "exposed", "tangled", "riposte"]
## One-shot integer tokens: absent or 0 is inert, 1 is armed. Nothing else is a legal shape.
const ONE_SHOT_STATUS_KEYS: Array[String] = ["dodge_next_attack", "blind_next_attack"]

var _starter_catalog := RagDuelistStarterCards.new()
var _pool_catalog := RagDuelistPoolCards.new()


## The single paid transaction: authenticate, preflight every input, then charge the printed cost,
## discard exactly the held copy and arm the owning hero's one-shot Dodge token (kept at 1 if it was
## already armed). A refusal changes no deck, party or RNG state.
##
## `target_position` is optional because a self card names nobody else: 0 means "its own self target"
## and resolves to the owner's current seat; the owner's own seat is also accepted explicitly. Any
## other seat (an ally or an enemy slot) is an invalid target and is refused before payment.
func play_card(deck: CombatDeck, party: CombatParty, card_id: Variant,
		target_position: Variant = 0) -> Dictionary:
	var plan: Dictionary = _prepare(deck, party, card_id, target_position)
	if not plan.get("ok", false):
		return _refusal(str(plan.get("reason", "refused")))
	# Every operation below is guaranteed by the complete preflight above: the turn is active, the
	# exact held ID is affordable, the unique living owner sits in a printed seat, the whole roster and
	# every status map are well formed and the requested target is the owner himself. Keep the
	# defensive returns so an unexpected model change still fails closed.
	if not deck.try_spend_energy(int(plan["cost"])):
		return _refusal("insufficient_energy")
	if not deck.discard_played(plan["card_id"]):
		return _refusal("card_not_held")

	# The real authoritative record, never a detached get_hero copy. Only the owner's one-shot Dodge
	# key changes; every unrelated status and every other hero stays exactly as it was.
	var record: Dictionary = party._heroes[int(plan["owner_position"]) - 1]
	var statuses: Dictionary = record.get("statuses", {})
	# Sets or keeps the one-shot token at integer 1; never a second stack, and never spent by this cast.
	statuses[DODGE_STATUS_KEY] = DODGE_TOKEN
	record["statuses"] = statuses

	return {
		"ok": true,
		"reason": "applied",
		"card_id": plan["card_id"],
		"cost": int(plan["cost"]),
		"owner_position": int(plan["owner_position"]),
		"owner_id": OWNER,
		"target_position": int(plan["target_position"]),
		"self_target": true,
		"dodge_before": int(plan["dodge_before"]),
		"dodge_after": DODGE_TOKEN,
		"dodge_already_active": int(plan["dodge_before"]) == DODGE_TOKEN,
		"energy_before": int(plan["energy_before"]),
		"energy_after": deck.energy,
		"statuses": statuses.duplicate(true),
	}


## True only for the four authentic catalog printings. Pure lookup; nothing is charged or mutated and
## no RNG is touched.
func is_supported_card(card_id: Variant) -> bool:
	if typeof(card_id) != TYPE_STRING:
		return false
	var id: String = card_id
	if not CARDS.has(id):
		return false
	return _authentic_pair(id, CARDS[id])


## Read-only preflight of the whole transaction. Returns a detached plan or a refusal receipt.
func _prepare(deck: CombatDeck, party: CombatParty, card_id: Variant,
		target_position: Variant) -> Dictionary:
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

	# Verify the complete roster and every hero's authoritative status shape, then bind the owner by
	# hero ID to its actual current slot. Swapping seats grants no false authority.
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
		if not _valid_status_shape(hero.get("statuses", {})):
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

	# A self card has exactly one legal target: the owner's own current seat. 0 is the implicit self
	# target; anything else is an invalid target argument and fails closed before payment.
	if typeof(target_position) != TYPE_INT:
		return _refusal("invalid_target")
	var target: int = target_position
	if target != 0 and target != owner_position:
		return _refusal("invalid_target")

	var owner_statuses: Dictionary = owner.get("statuses", {})
	return {
		"ok": true,
		"card_id": id,
		"cost": cost,
		"owner_position": owner_position,
		"target_position": owner_position if target == 0 else target,
		"dodge_before": int(owner_statuses.get(DODGE_STATUS_KEY, 0)),
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


## Reads the exact authored record from the catalog that owns this ID and proves both printings of the
## pair still carry their authored line, so a rewritten catalog (extra effect, another seat, another
## target, another cost or a broken upgrade link) can never be paid for as this effect.
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


## The one catalog read of this service, so a test double can prove that a rewritten catalog record is
## refused rather than paid for. Production always reads the real Rag Duelist catalogs.
func _catalog_definition(card_id: String) -> Dictionary:
	var card: Dictionary = CARDS.get(card_id, {})
	var source: Variant = card.get("catalog", "")
	if source == "starter":
		return _starter_catalog.get_definition(card_id)
	if source == "pool":
		return _pool_catalog.get_definition(card_id)
	return {}


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
	var expected_effects: Dictionary = {DODGE_STATUS_KEY: DODGE_TOKEN, "duration": 1}
	if not _same_value(definition.get("effects"), expected_effects):
		return false
	# The base and '+' records must still point at each other, so a copied or relinked record cannot be
	# paid for under the other printing's ID.
	if card.has("upgrade_id"):
		return definition.get("upgrade_id") == card["upgrade_id"] \
			and not definition.has("upgrade_of")
	return definition.get("upgrade_of") == card["upgrade_of"] \
		and not definition.has("upgrade_id")


## Typed equality rejects coercible metadata (e.g. a String "1" or a bool standing in for an int) as
## well as changed effects or upgrade links.
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
