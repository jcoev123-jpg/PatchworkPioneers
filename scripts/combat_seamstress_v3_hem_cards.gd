class_name CombatSeamstressV3HemCards
extends RefCounted
## Scene-free paid resolver for the Seamstress's v3 Shielding Hem and Patchwork Poultice (V3-1).
##
## Shielding Hem is a v3 starter and Patchwork Poultice a v3 reward-pool card; both print one energy
## onto ONE explicitly chosen living ally and then grant that ally its printed Block plus capped
## healing. The tall purple patched dress's look is exactly that: she protects a teammate with a
## stitched hem and patches the same ally's wounds, so this service authenticates the exact held
## catalog record before it touches any state.
##
## The catalogs stay authoritative: the caller cannot supply effects, costs, seats or a catalog.
## CombatDeck and CombatParty own the real state (hand, energy, piles and hero HP/Block), and only
## the selected ally changes. Nothing here draws, shuffles, cleanses, revives, applies a status,
## touches enemies or discounts the cost, and no run RNG draw is consumed; a refusal is strictly
## inert.
##
## This is callable rules-layer behaviour only. It does not register these IDs in the live hand,
## rewards, run deck or the app flow; that wiring is a later task.

const OWNER := "seamstress"
const TARGET_KIND := "ally_single"

## The four authentic IDs, the catalog that owns each one, and the exact printed line it must still
## carry. A base card and its "+" differ only in Block/heal magnitude; the starter printings are one
## starting copy of the base only, while the reward-pool base is the eligible printing.
const CARDS := {
	"seamstress_v3_shielding_hem": {
		"catalog": "starter",
		"cost": 1,
		"block": 4,
		"heal": 2,
		"from_positions": [1, 2, 3],
		"starting_copies": 1,
		"reward_eligible": false,
		"upgrade_id": "seamstress_v3_shielding_hem_plus",
	},
	"seamstress_v3_shielding_hem_plus": {
		"catalog": "starter",
		"cost": 1,
		"block": 6,
		"heal": 3,
		"from_positions": [1, 2, 3],
		"starting_copies": 0,
		"reward_eligible": false,
		"upgrade_of": "seamstress_v3_shielding_hem",
	},
	"seamstress_v3_patchwork_poultice": {
		"catalog": "pool",
		"cost": 1,
		"block": 3,
		"heal": 3,
		"from_positions": [2, 3],
		"starting_copies": 0,
		"reward_eligible": true,
		"upgrade_id": "seamstress_v3_patchwork_poultice_plus",
	},
	"seamstress_v3_patchwork_poultice_plus": {
		"catalog": "pool",
		"cost": 1,
		"block": 4,
		"heal": 4,
		"from_positions": [2, 3],
		"starting_copies": 0,
		"reward_eligible": false,
		"upgrade_of": "seamstress_v3_patchwork_poultice",
	},
}


## The single paid transaction: authenticate, preflight every input, then charge the printed cost,
## discard exactly the held copy, grant the chosen ally its printed Block and heal that same ally
## up to its max HP. A refusal changes no deck, party or RNG state.
func play_card(deck: CombatDeck, party: CombatParty, card_id: Variant,
		target_position: int = 0) -> Dictionary:
	var plan: Dictionary = _prepare(deck, party, card_id, target_position)
	if not plan.get("ok", false):
		return _refusal(str(plan.get("reason", "refused")))
	# Every operation below is guaranteed by the complete preflight above: the turn is active, the
	# exact held ID is affordable, the owner sits in a printed seat, the chosen ally lives and its
	# Block cannot overflow. Keep the defensive returns so an unexpected model change fails closed.
	if not deck.try_spend_energy(plan["cost"]):
		return _refusal("insufficient_energy")
	if not deck.discard_played(plan["card_id"]):
		return _refusal("card_not_held")
	if not party.gain_block(plan["target_position"], plan["block"]):
		return _refusal("block_failed")
	if not party.heal(plan["target_position"], plan["heal"]):
		return _refusal("heal_failed")

	var hero_after: Dictionary = party.get_hero(plan["target_position"])
	return {
		"ok": true,
		"reason": "applied",
		"card_id": plan["card_id"],
		"cost": plan["cost"],
		"owner_position": plan["owner_position"],
		"target_position": plan["target_position"],
		"block": plan["block"],
		"block_before": plan["block_before"],
		"block_after": int(hero_after["block"]),
		"heal": plan["heal"],
		"healed": int(hero_after["hp"]) - plan["hp_before"],
		"hp_before": plan["hp_before"],
		"hp_after": int(hero_after["hp"]),
	}


## True only for the four authentic catalog IDs. Pure lookup; nothing is charged or mutated.
func is_supported_card(card_id: Variant) -> bool:
	return typeof(card_id) == TYPE_STRING and CARDS.has(card_id)


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
	var card: Dictionary = CARDS.get(id, {})
	if card.is_empty():
		return _refusal("unsupported_card")
	var definition: Dictionary = _catalog_definition(id)
	if not _authentic(definition, id, card):
		return _refusal("catalog_mismatch")
	# Hand membership is the actual held copy, never just a catalog lookup.
	if not deck.hand.has(id):
		return _refusal("card_not_held")
	var cost: int = card["cost"]
	if cost < 0 or deck.energy < cost:
		return _refusal("insufficient_energy")

	# Verify the complete roster and every hero's authoritative record, then bind the owner by hero
	# ID to its actual current slot. Swapping seats grants no false authority.
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
	# A torn Seamstress cannot stitch: the card cannot be cast by a downed hero.
	if int(heroes[owner_position - 1]["hp"]) == 0:
		return _refusal("owner_downed")
	# A living recipient in 1-3 (self is legal); this card never revives a torn (0 HP) ally.
	if target_position < 1 or target_position > CombatParty.PARTY_SIZE:
		return _refusal("invalid_target")
	if int(heroes[target_position - 1]["hp"]) == 0:
		return _refusal("target_downed")

	# gain_block must be guaranteed before charging: overflow otherwise rejects after payment.
	var block_before: int = int(heroes[target_position - 1]["block"])
	if int(card["block"]) > CombatParty.MAX_INT - block_before:
		return _refusal("block_overflow")

	return {
		"ok": true,
		"card_id": id,
		"cost": cost,
		"owner_position": owner_position,
		"target_position": target_position,
		"block": int(card["block"]),
		"heal": int(card["heal"]),
		"block_before": block_before,
		"hp_before": int(heroes[target_position - 1]["hp"]),
	}


## Reads the exact authored record from the catalog that owns this ID (never the other hero
## catalogs) and returns a detached copy, or {} when the ID is not in that catalog.
func _catalog_definition(card_id: String) -> Dictionary:
	var card: Dictionary = CARDS.get(card_id, {})
	var source: Variant = card.get("catalog", "")
	if source == "starter":
		return V3SeamstressStarterCards.new().get_definition(card_id)
	if source == "pool":
		return V3SeamstressPoolCards.new().get_definition(card_id)
	return {}


## The record must still carry exactly the authored printed line, so a rewritten catalog (an extra
## Block or heal, another effect, a different seat or target, altered copy/reward metadata) can
## never be paid for as this effect. The base and "+" records must also still point at each other,
## so a copied or relinked record cannot be played under the other printing's ID.
func _authentic(definition: Dictionary, card_id: String, card: Dictionary) -> bool:
	var expected := {
		"id": card_id,
		"owner": OWNER,
		"cost": card["cost"],
		"target_kind": TARGET_KIND,
		"from_positions": card["from_positions"],
		"to_positions": [],
		"effects": {"block": card["block"], "heal": card["heal"]},
		"starting_copies": card["starting_copies"],
		"reward_eligible": card["reward_eligible"],
	}
	var link := "upgrade_of" if card.has("upgrade_of") else "upgrade_id"
	expected[link] = card[link]
	for other: String in ["upgrade_id", "upgrade_of"]:
		if other != link and definition.has(other):
			return false
	for field in expected:
		if not definition.has(field) or not _same_value(definition[field], expected[field]):
			return false
	return true


## Typed equality rejects coercible metadata (for example a float cost) as well as altered effects,
## seats or upgrade links.
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


func _refusal(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
