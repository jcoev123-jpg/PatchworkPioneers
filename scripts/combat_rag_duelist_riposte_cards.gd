class_name CombatRagDuelistRiposteCards
extends RefCounted
## Scene-free paid resolver for the Rag Duelist's Block-and-Riposte self cards (V3-1).
##
## Cape Parry is a v3 starter and Cape Guard / Duelist Reprise are v3 reward-pool cards. Every
## printing costs 1, names only the owner's own seat (`target_kind: "self"`, no enemy positions) and
## prints a one-turn Riposte N; the Cape pair also prints Block. Riposte N is "when hit, strike
## back N": N counterdamage for every confirmed hit during its single owner turn, never an N-turn
## counter, and `CombatStatuses.end_owner_turn` clears it completely afterwards.
##
## This service authenticates the exact held ID against the catalog that owns it (owner, cost, FROM
## seats, self target, empty TO line, the complete effect dictionary and the base/'+' link) and
## never trusts caller-supplied effects. It then resolves against the real shared CombatDeck and
## CombatParty: one printed energy charge, one held copy discarded, the printed Block added to the
## owning hero and Riposte N written to that hero's authoritative statuses. A refusal changes no
## deck, party, status or seeded RNG state.
##
## Riposte stays the established actor-local status (an int N on the owner's statuses dictionary).
## This slice deliberately invents no combat-wide stacking or refresh lifecycle: a fresh active
## Riposte (N > 0) is rejected before payment, and an inert/absent Riposte 0 is replaced by the
## printed N. No timer, no replay of enemy hits and no turn-ownership change happens here.
##
## Callable rules service only. These six IDs are not yet admitted to a live party deck, the mounted
## hand, the reward pool or any app flow; that wiring is a later task.

const OWNER := "rag_duelist"
const TARGET_KIND := "self"

## The six authentic printings, the catalog that owns each one, and the exact authored line each
## must still carry. Block is the only difference between a Cape printing and its "+"; Reprise
## grants Riposte alone.
const CARDS := {
	"rag_duelist_cape_parry": {
		"catalog": "starter", "cost": 1, "from_positions": [1, 2, 3],
		"block": 4, "riposte": 2, "upgrade_id": "rag_duelist_cape_parry_plus",
	},
	"rag_duelist_cape_parry_plus": {
		"catalog": "starter", "cost": 1, "from_positions": [1, 2, 3],
		"block": 6, "riposte": 3, "upgrade_of": "rag_duelist_cape_parry",
	},
	"rag_duelist_cape_guard": {
		"catalog": "pool", "cost": 1, "from_positions": [1, 2, 3],
		"block": 5, "riposte": 3, "upgrade_id": "rag_duelist_cape_guard_plus",
	},
	"rag_duelist_cape_guard_plus": {
		"catalog": "pool", "cost": 1, "from_positions": [1, 2, 3],
		"block": 7, "riposte": 4, "upgrade_of": "rag_duelist_cape_guard",
	},
	"rag_duelist_duelist_reprise": {
		"catalog": "pool", "cost": 1, "from_positions": [1, 2],
		"block": 0, "riposte": 5, "upgrade_id": "rag_duelist_duelist_reprise_plus",
	},
	"rag_duelist_duelist_reprise_plus": {
		"catalog": "pool", "cost": 1, "from_positions": [1, 2],
		"block": 0, "riposte": 7, "upgrade_of": "rag_duelist_duelist_reprise",
	},
}

## The status vocabulary the combat status rules accept as N-turn counters (int >= 0).
const COUNTER_STATUS_KEYS: Array[String] = ["bleed", "weak", "exposed", "tangled", "riposte"]
## One-shot integer tokens: absent or 0 is inert, 1 is armed. Nothing else is a legal shape.
const ONE_SHOT_STATUS_KEYS: Array[String] = ["dodge_next_attack", "blind_next_attack"]

const RIPOSTE_STATUS_KEY := "riposte"

var _starter_catalog := RagDuelistStarterCards.new()
var _pool_catalog := RagDuelistPoolCards.new()


## The single paid transaction: authenticate, preflight every input, then charge the printed cost,
## discard exactly the held copy, add the printed Block (Cape printings only) and set the printed
## Riposte N on the owning hero. A refusal changes no deck, party or RNG state.
func play_card(deck: CombatDeck, party: CombatParty, card_id: Variant) -> Dictionary:
	var plan: Dictionary = _prepare(deck, party, card_id)
	if not plan.get("ok", false):
		return _refusal(str(plan.get("reason", "refused")))
	# Every operation below is guaranteed by the complete preflight above: the turn is active, the
	# exact held ID is affordable, the unique living owner sits in a printed seat, the whole roster
	# and every status map are well formed, and won Block/Riposte are representable. Keep the
	# defensive returns so an unexpected model change still fails closed.
	if not deck.try_spend_energy(int(plan["cost"])):
		return _refusal("insufficient_energy")
	if not deck.discard_played(plan["card_id"]):
		return _refusal("card_not_held")
	var block: int = int(plan["block"])
	if block > 0 and not party.gain_block(int(plan["owner_position"]), block):
		return _refusal("block_failed")

	# The real authoritative record, never a detached get_hero copy. Only the owner's Riposte key
	# changes; every unrelated status and every other hero stays exactly as it was.
	var record: Dictionary = party._heroes[int(plan["owner_position"]) - 1]
	var statuses: Dictionary = record.get("statuses", {})
	statuses[RIPOSTE_STATUS_KEY] = int(plan["riposte"])
	record["statuses"] = statuses

	return {
		"ok": true,
		"reason": "applied",
		"card_id": plan["card_id"],
		"cost": int(plan["cost"]),
		"owner_position": int(plan["owner_position"]),
		"owner_id": OWNER,
		"block": block,
		"block_before": int(plan["block_before"]),
		"block_after": int(record["block"]),
		"riposte": int(plan["riposte"]),
		"riposte_before": int(plan["riposte_before"]),
		"riposte_after": int(statuses[RIPOSTE_STATUS_KEY]),
		"energy_before": int(plan["energy_before"]),
		"energy_after": deck.energy,
		"statuses": statuses.duplicate(true),
	}


## True only for the six authentic catalog printings. Pure lookup; nothing is charged or mutated
## and no RNG is touched.
func is_supported_card(card_id: Variant) -> bool:
	if typeof(card_id) != TYPE_STRING:
		return false
	var id: String = card_id
	if not CARDS.has(id):
		return false
	return _authentic_pair(id, CARDS[id])


## Read-only preflight of the whole transaction. Returns a detached plan or a refusal receipt.
func _prepare(deck: CombatDeck, party: CombatParty, card_id: Variant) -> Dictionary:
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

	var block_gain: int = int(card["block"])
	if block_gain < 0:
		return _refusal("catalog_mismatch")
	# gain_block must be guaranteed before charging: overflow otherwise rejects after payment.
	if block_gain > CombatParty.MAX_INT - int(owner["block"]):
		return _refusal("block_overflow")

	var riposte: int = int(card["riposte"])
	if riposte <= 0:
		return _refusal("catalog_mismatch")
	var riposte_before: int = int(owner.get("statuses", {}).get(RIPOSTE_STATUS_KEY, 0))
	# A fresh/inert Riposte 0 is replaced by the printed N. An already active Riposte is a real owner
	# decision (stack or refresh) this slice must not invent, so it fails closed instead.
	if riposte_before > 0:
		return _refusal("riposte_already_active")

	return {
		"ok": true,
		"card_id": id,
		"cost": cost,
		"owner_position": owner_position,
		"block": block_gain,
		"block_before": int(owner["block"]),
		"riposte": riposte,
		"riposte_before": riposte_before,
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


## Reads the exact authored record from the catalog that owns this ID and proves both printings of
## the pair still carry their authored line, so a rewritten catalog (extra effect, another seat,
## target, cost or a broken upgrade link) can never be paid for as this effect.
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
## record is refused rather than paid for. Production always reads the real Rag Duelist catalogs.
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
	var expected_effects: Dictionary = {"riposte": int(card["riposte"]), "duration": 1}
	if int(card["block"]) > 0:
		expected_effects["block"] = int(card["block"])
	if not _same_value(definition.get("effects"), expected_effects):
		return false
	# The base and "+" records must still point at each other, so a copied or relinked record
	# cannot be paid for under the other printing's ID.
	if card.has("upgrade_id"):
		return definition.get("upgrade_id") == card["upgrade_id"] \
			and not definition.has("upgrade_of")
	return definition.get("upgrade_of") == card["upgrade_of"] \
		and not definition.has("upgrade_id")


## Typed equality rejects coercible metadata (e.g. a String "4" or a bool standing in for an int)
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
