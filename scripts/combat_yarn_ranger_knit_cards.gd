class_name CombatYarnRangerKnitCards
extends RefCounted
## Scene-free paid resolver for the Yarn Ranger's knitted ally supports (V3-1).
##
## Hood Knit / Hood Knit+ are the hero's starters; Knit Shield / Knit Shield+ are common pool
## rewards. All four print one energy, are cast from any seat (FROM 1-3), target one living ally
## (self included) and grant printed Block plus exactly one shared-hand draw:
## Hood Knit 4 / Hood Knit+ 6, Knit Shield 6 / Knit Shield+ 8.
##
## The authored catalogs stay authoritative: the caller supplies a held ID and a recipient seat,
## never a card record, a Block amount or a draw count. Each ID is authenticated against its own
## catalog record before anything is paid, so a forged, rewritten, relinked or foreign record is
## refused instead of resolving as a knitted card.
##
## A play charges the printed cost once, adds Block only to the chosen recipient, draws through the
## already-seeded CombatDeck (zero cards is a legitimate result when the supply is empty) and then
## discards exactly one held copy. Drawing first matters: the played copy is still in hand during
## the draw, so a reshuffle can never refill it into its own draw.
##
## Every rejection is a pure no-op: no energy, hand, pile, party or RNG change. This is callable
## rules-layer behaviour only; registering these IDs in the live hand or reward flow is a later,
## separately owned wiring task.

const OWNER := "yarn_ranger"
const TARGET_KIND := "ally_single"
const FROM_POSITIONS := [1, 2, 3]
const TO_POSITIONS := []
const DRAW := 1

## The four authentic printings and the exact catalog line each one must still carry. `block` is the
## printed Block; `catalog` names the single catalog allowed to own that ID; a "+" only raises Block.
const CARDS := {
	"yarn_ranger_hood_knit": {
		"cost": 1,
		"block": 4,
		"effects": {"block": 4, "draw": 1},
		"catalog": "starter",
		"upgrade_id": "yarn_ranger_hood_knit_plus",
	},
	"yarn_ranger_hood_knit_plus": {
		"cost": 1,
		"block": 6,
		"effects": {"block": 6, "draw": 1},
		"catalog": "starter",
		"upgrade_of": "yarn_ranger_hood_knit",
	},
	"yarn_ranger_knit_shield": {
		"cost": 1,
		"block": 6,
		"effects": {"block": 6, "draw": 1},
		"catalog": "pool",
		"upgrade_id": "yarn_ranger_knit_shield_plus",
	},
	"yarn_ranger_knit_shield_plus": {
		"cost": 1,
		"block": 8,
		"effects": {"block": 8, "draw": 1},
		"catalog": "pool",
		"upgrade_of": "yarn_ranger_knit_shield",
	},
}

const _STARTER_CATALOG := preload("res://data/cards/yarn_ranger_starter_cards.gd")
const _POOL_CATALOG := preload("res://data/cards/yarn_ranger_pool_cards.gd")


## True only for the four authentic catalog IDs. Pure lookup; nothing is charged or mutated.
func is_supported_card(card_id: Variant) -> bool:
	return typeof(card_id) == TYPE_STRING and CARDS.has(card_id)


## A detached, shape-checked knitted definition from the catalog that owns the ID, or {} for
## anything else. Unrelated cards, forged spellings and tampered records all resolve to {}.
static func knit_definition(card_id: Variant) -> Dictionary:
	if typeof(card_id) != TYPE_STRING:
		return {}
	var id: String = card_id
	var card: Dictionary = CARDS.get(id, {})
	if card.is_empty():
		return {}
	var definition: Dictionary = {}
	if card["catalog"] == "starter":
		definition = _STARTER_CATALOG.new().get_definition(id)
	else:
		definition = _POOL_CATALOG.new().get_definition(id)
	if not is_authentic_definition(definition, id):
		return {}
	return definition


## The record must still carry exactly the authored line: id, owner, printed one-energy cost, the
## any-seat FROM line, the single-ally target, the empty TO line, exactly the printed Block plus one
## draw (integer types only, no extra keys) and the base/"+" link in its own catalog.
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


## The single paid transaction: authenticate, preflight the whole request, then charge once, add
## the printed Block to the chosen living ally, draw one shared card and discard the held copy.
## `target_position` is the recipient seat 1-3 (self is allowed); it is never a 0 "auto" value
## because the printed target is ally_single. A refusal changes no deck, party or RNG state.
func play_card(deck: CombatDeck, party: CombatParty, card_id: Variant,
		target_position: int) -> Dictionary:
	if deck == null or party == null or deck.combat_state == null or deck._rng == null:
		return _refusal("invalid_request")
	if typeof(card_id) != TYPE_STRING:
		return _refusal("unsupported_card")
	var id: String = card_id
	if not CARDS.has(id):
		return _refusal("unsupported_card")
	var definition := knit_definition(id)
	if definition.is_empty():
		return _refusal("catalog_mismatch")

	if not deck.turn_active:
		return _refusal("inactive_turn")
	if not party.is_valid():
		return _refusal("invalid_roster")

	# Validate the real roster before touching it: distinct nonempty IDs in fixed seats with
	# well-formed HP, max HP and Block. A malformed party can never authorize a paid play.
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

	# Hand membership is the actual held copy, never just a catalog lookup.
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

	# Every operation below is guaranteed by the complete preflight above. Keep the defensive
	# returns so an unexpected model change still fails closed before Block is written.
	if not deck.try_spend_energy(cost):
		return _refusal("insufficient_energy")
	if not party.gain_block(target_position, block):
		return _refusal("block_overflow")
	# The played copy is still in the hand here, so a reshuffle cannot draw it back.
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
