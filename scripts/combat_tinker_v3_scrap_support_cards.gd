class_name CombatTinkerV3ScrapSupportCards
extends RefCounted
## Scene-free paid resolver for Tinker's Gear Brace and Spare Screws (V3-1) plus his authored
## starter support pair Casing Ward and Tune Up.
##
## Gear Brace / Gear Brace+ fold a gear shield over the hunched goggled scrap-tinker's own body:
## both print one energy, are cast from any seat (FROM 1-3), target self and grant printed Block
## plus exactly one Combat Scrap (5 / 7 Block). Spare Screws / Spare Screws+ dig two screws out of
## the scrap backpack and rattle one loose part onto the table: cast only from the middle or back
## seat (FROM 2-3), target self, gain exactly two Combat Scrap and draw one card; Spare Screws
## costs one and Spare Screws+ costs zero.
##
## Casing Ward / Casing Ward+ are the V3TinkerStarterCards self ward: one energy from any seat
## (FROM 1-3), targeting self, granting 5 / 7 Block and exactly one Combat Scrap. Tune Up /
## Tune Up+ are the starter's free tune: zero energy from any seat, no target picker (the helper's
## sentinel 0 stands in for `target_kind: "none"`), no Block, exactly one Combat Scrap and a shared
## draw of 1 / 2 cards. Starter printings authenticate against their own catalog while the four
## reward-pool printings above keep authenticating against V3TinkerPoolCards, so neither schema can
## masquerade as the other.
##
## Combat Scrap is Tinker's COMBAT counter stored on his own authoritative hero record
## (`combat_scrap`, an optional non-negative int that is absent—read as zero—on a fresh party).
## It is never the run-wallet `scraps` currency, and this service never invents wallet state,
## a second hand or a second RNG. New runs and freshly constructed parties start without the key,
## so no counter is inherited.
##
## The authored catalogs stay authoritative: the caller supplies a held ID and nothing else, never
## a card record, a cost, a Block amount, a draw count or a scrap amount. Each ID is authenticated
## against the catalog that owns it (V3TinkerPoolCards for the reward printings, V3TinkerStarterCards
## for the starter pair) before anything is paid, so a forged, rewritten, relinked, substituted or
## foreign record is refused instead of resolving as one of these cards.
##
## A play pays the printed cost once, grants the printed Block only to the living Tinker at his
## ACTUAL current slot, adds the printed Combat Scrap to that same hero record, draws through the
## already-seeded shared CombatDeck (zero cards is a legitimate result when the supply is empty)
## and then discards exactly one held copy. Drawing first matters: the played copy is still in the
## hand during the draw, so a reshuffle can never refill it into its own draw.
##
## Every rejection is a pure no-op: no energy, hand, pile, party, counter or RNG change. This is
## callable rules-layer behaviour only; registering these IDs in the live hand or reward flow is a
## later, separately owned wiring task, and Overload's spending of the counter is a later task too.

const OWNER := "tinker"
const TARGET_KIND := "self"
const SELF_TARGET := 0
const _STARTER_ART_DIR := "res://assets/paper/cards/"

## The four authentic printings and the exact catalog line each one must still carry.
## `effects` is the complete authored effect dictionary (no extra or missing keys); `block` is the
## printed Block (0 when the card grants none), `combat_scrap_gain` the printed counter gain and
## `draw` the printed shared-hand draw. A "+" only raises Gear Brace's Block or drops Spare Screws'
## cost.
const CARDS := {
	"tinker_v3_gear_brace": {
		"cost": 1,
		"from_positions": [1, 2, 3],
		"target_kind": "self",
		"block": 5,
		"combat_scrap_gain": 1,
		"draw": 0,
		"effects": {"block": 5, "combat_scrap_gain": 1},
		"upgrade_id": "tinker_v3_gear_brace_plus",
	},
	"tinker_v3_gear_brace_plus": {
		"cost": 1,
		"from_positions": [1, 2, 3],
		"target_kind": "self",
		"block": 7,
		"combat_scrap_gain": 1,
		"draw": 0,
		"effects": {"block": 7, "combat_scrap_gain": 1},
		"upgrade_of": "tinker_v3_gear_brace",
	},
	"tinker_v3_spare_screws": {
		"cost": 1,
		"from_positions": [2, 3],
		"target_kind": "self",
		"block": 0,
		"combat_scrap_gain": 2,
		"draw": 1,
		"effects": {"combat_scrap_gain": 2, "draw": 1},
		"upgrade_id": "tinker_v3_spare_screws_plus",
	},
	"tinker_v3_spare_screws_plus": {
		"cost": 0,
		"from_positions": [2, 3],
		"target_kind": "self",
		"block": 0,
		"combat_scrap_gain": 2,
		"draw": 1,
		"effects": {"combat_scrap_gain": 2, "draw": 1},
		"upgrade_of": "tinker_v3_spare_screws",
	},
}

## The four authentic V3TinkerStarterCards support printings. They carry the starter schema
## (`upgrade_id` on the base, `upgrade_of` on the "+", one starting copy/reward-ineligible flags and
## an art path) instead of the reward pool's base_id/upgrade_id/is_upgrade triple. `block` is 0 for
## Tune Up, whose printed target is `none`: the helper's sentinel 0 is the only legal target.
const STARTER_CARDS := {
	"tinker_v3_casing_ward": {
		"cost": 1,
		"from_positions": [1, 2, 3],
		"target_kind": "self",
		"display_name": "Casing Ward",
		"starting_copies": 1,
		"block": 5,
		"combat_scrap_gain": 1,
		"draw": 0,
		"effects": {"block": 5, "combat_scrap_gain": 1},
		"upgrade_id": "tinker_v3_casing_ward_plus",
	},
	"tinker_v3_casing_ward_plus": {
		"cost": 1,
		"from_positions": [1, 2, 3],
		"target_kind": "self",
		"display_name": "Casing Ward+",
		"starting_copies": 0,
		"block": 7,
		"combat_scrap_gain": 1,
		"draw": 0,
		"effects": {"block": 7, "combat_scrap_gain": 1},
		"upgrade_of": "tinker_v3_casing_ward",
	},
	"tinker_v3_tune_up": {
		"cost": 0,
		"from_positions": [1, 2, 3],
		"target_kind": "none",
		"display_name": "Tune Up",
		"starting_copies": 1,
		"block": 0,
		"combat_scrap_gain": 1,
		"draw": 1,
		"effects": {"draw": 1, "combat_scrap_gain": 1},
		"upgrade_id": "tinker_v3_tune_up_plus",
	},
	"tinker_v3_tune_up_plus": {
		"cost": 0,
		"from_positions": [1, 2, 3],
		"target_kind": "none",
		"display_name": "Tune Up+",
		"starting_copies": 0,
		"block": 0,
		"combat_scrap_gain": 1,
		"draw": 2,
		"effects": {"draw": 2, "combat_scrap_gain": 1},
		"upgrade_of": "tinker_v3_tune_up",
	},
}

const _CATALOG := preload("res://data/cards/v3_tinker_pool_cards.gd")
const _STARTER_CATALOG := preload("res://data/cards/v3_tinker_starter_cards.gd")

var _catalog := _CATALOG.new()
var _starter_catalog := _STARTER_CATALOG.new()


## The printed specification of a supported ID: the pool line for the four reward printings, the
## starter line for the four authored starters, {} for anything else.
static func _spec(card_id: String) -> Dictionary:
	if CARDS.has(card_id):
		return CARDS[card_id]
	return STARTER_CARDS.get(card_id, {})


## True only for the eight authentic printings (four pool, four starter). Pure lookup; nothing is
## charged or mutated and no RNG is touched. Each ID is authenticated against the catalog that owns
## it.
func is_supported_card(card_id: Variant) -> bool:
	if typeof(card_id) != TYPE_STRING:
		return false
	var id: String = card_id
	if STARTER_CARDS.has(id):
		return is_authentic_starter_definition(_starter_catalog.get_definition(id), id)
	if not CARDS.has(id):
		return false
	return is_authentic_definition(_catalog.get_definition(id), id)


## A detached, shape-checked scrap-support definition from the catalog that owns the ID, or {} for
## anything else. Unrelated cards, forged spellings, tampered records, cross-catalog substitutes and
## the v2 Tinker pool all resolve to {}.
static func scrap_support_definition(card_id: Variant) -> Dictionary:
	if typeof(card_id) != TYPE_STRING:
		return {}
	var id: String = card_id
	if STARTER_CARDS.has(id):
		var starter_definition: Dictionary = _STARTER_CATALOG.new().get_definition(id)
		if not is_authentic_starter_definition(starter_definition, id):
			return {}
		return starter_definition
	if not CARDS.has(id):
		return {}
	var definition: Dictionary = _CATALOG.new().get_definition(id)
	if not is_authentic_definition(definition, id):
		return {}
	return definition


## The record must still carry exactly the authored line in the catalog that owns its ID: id,
## Tinker owner, the printed integer cost, the printed target, the exact FROM seats, an empty TO
## line, exactly the printed effect dictionary (integer values only, no extra keys) and the
## catalog's own base/"+" link. Pool and starter schemas never authenticate as each other.
static func is_authentic_definition(definition: Variant, card_id: Variant) -> bool:
	if typeof(definition) != TYPE_DICTIONARY or typeof(card_id) != TYPE_STRING:
		return false
	var id: String = card_id
	if STARTER_CARDS.has(id):
		return is_authentic_starter_definition(definition, id)
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
			or definition["from_positions"] != card["from_positions"]:
		return false
	var to_positions: Variant = definition.get("to_positions")
	if typeof(to_positions) != TYPE_ARRAY or not (to_positions as Array).is_empty():
		return false
	var effects: Variant = definition.get("effects")
	if typeof(effects) != TYPE_DICTIONARY:
		return false
	var effect_map: Dictionary = effects
	if effect_map.size() != (card["effects"] as Dictionary).size():
		return false
	for key in card["effects"]:
		if not effect_map.has(key) or typeof(effect_map[key]) != TYPE_INT:
			return false
		if effect_map[key] != card["effects"][key]:
			return false
	# V3TinkerPoolCards links a printing to its pair with base_id/upgrade_id/is_upgrade, never an
	# `upgrade_of` key; a stray one is a foreign record shape.
	if definition.has("upgrade_of"):
		return false
	if card.has("upgrade_id"):
		return definition.get("base_id") == id \
			and definition.get("upgrade_id") == card["upgrade_id"] \
			and definition.get("is_upgrade") == false
	return definition.get("base_id") == card["upgrade_of"] \
		and definition.get("upgrade_id") == id \
		and definition.get("is_upgrade") == true


## The V3TinkerStarterCards schema: id, Tinker owner, the printed display name, integer cost, the
## printed target (`self` or `none`), the exact FROM seats, an empty TO line, exactly the printed
## effect dictionary, the starter copy/reward flags, the starter art path, and a link using
## `upgrade_id` on the base or `upgrade_of` on the "+". Pool-only keys are a foreign record shape.
static func is_authentic_starter_definition(definition: Variant, card_id: Variant) -> bool:
	if typeof(definition) != TYPE_DICTIONARY or typeof(card_id) != TYPE_STRING:
		return false
	var id: String = card_id
	var card: Dictionary = STARTER_CARDS.get(id, {})
	if card.is_empty():
		return false
	if definition.get("id") != id or definition.get("owner") != OWNER:
		return false
	if definition.get("display_name") != card["display_name"]:
		return false
	if typeof(definition.get("cost")) != TYPE_INT or definition["cost"] != card["cost"]:
		return false
	if definition.get("target_kind") != card["target_kind"]:
		return false
	if typeof(definition.get("from_positions")) != TYPE_ARRAY \
			or definition["from_positions"] != card["from_positions"]:
		return false
	var to_positions: Variant = definition.get("to_positions")
	if typeof(to_positions) != TYPE_ARRAY or not (to_positions as Array).is_empty():
		return false
	var effects: Variant = definition.get("effects")
	if typeof(effects) != TYPE_DICTIONARY:
		return false
	var effect_map: Dictionary = effects
	if effect_map.size() != (card["effects"] as Dictionary).size():
		return false
	for key in card["effects"]:
		if not effect_map.has(key) or typeof(effect_map[key]) != TYPE_INT:
			return false
		if effect_map[key] != card["effects"][key]:
			return false
	if typeof(definition.get("starting_copies")) != TYPE_INT \
			or definition["starting_copies"] != card["starting_copies"]:
		return false
	if typeof(definition.get("reward_eligible")) != TYPE_BOOL \
			or definition["reward_eligible"] != false:
		return false
	if definition.get("illustration_path") != _STARTER_ART_DIR + id.trim_suffix("_plus") + ".png":
		return false
	# V3TinkerStarterCards carries no reward-pool metadata and no rarity or hero statistics.
	for pool_key: String in ["base_id", "is_upgrade", "rarity", "max_hp", "passive"]:
		if definition.has(pool_key):
			return false
	if card.has("upgrade_id"):
		return definition.get("upgrade_id") == card["upgrade_id"] \
			and not definition.has("upgrade_of")
	return definition.get("upgrade_of") == card["upgrade_of"] \
		and not definition.has("upgrade_id")


## A detached, shape-checked definition from this instance's catalogs, or {}. This is the play
## path's authority: a caller-supplied or swapped catalog record is refused here even when the
## static lookup still knows the authentic printing.
func _definition(card_id: String) -> Dictionary:
	if STARTER_CARDS.has(card_id):
		var starter_definition: Dictionary = _starter_catalog.get_definition(card_id)
		if not is_authentic_starter_definition(starter_definition, card_id):
			return {}
		return starter_definition
	if not CARDS.has(card_id):
		return {}
	var definition: Dictionary = _catalog.get_definition(card_id)
	if not is_authentic_definition(definition, card_id):
		return {}
	return definition


## The single paid transaction: authenticate, preflight the whole request, then charge once, add
## the printed Block (if any) to the living Tinker at his actual seat, add the printed Combat Scrap
## to his own authoritative record, draw the printed number of shared cards and discard the held
## copy. `target_position` must stay 0: these cards print `target_kind: "self"` or `"none"`, so the
## Tinker himself is the only recipient and no other slot is ever named. A refusal changes no deck,
## party, counter or RNG state.
func play_card(deck: CombatDeck, party: CombatParty, card_id: Variant,
		target_position: int = SELF_TARGET) -> Dictionary:
	var plan: Dictionary = _prepare(deck, party, card_id, target_position)
	if not plan.get("ok", false):
		return _refusal(str(plan.get("reason", "refused")))
	# Every operation below is guaranteed by the complete preflight above: the turn is active, the
	# exact held ID is affordable, the unique living owner sits in an authored seat and both the
	# Block and the counter gain fit. Keep the defensive returns so an unexpected model change
	# still fails closed before the next write.
	var owner_position: int = int(plan["owner_position"])
	var cost: int = int(plan["cost"])
	if not deck.try_spend_energy(cost):
		return _refusal("insufficient_energy")
	var block: int = int(plan["block"])
	if block > 0 and not party.gain_block(owner_position, block):
		return _refusal("block_overflow")
	# Mutate only the real authoritative hero record, never the detached get_hero copy.
	var record: Dictionary = party._heroes[owner_position - 1]
	var counter_before: int = int(plan["combat_scrap_before"])
	record["combat_scrap"] = counter_before + int(plan["combat_scrap_gain"])
	# The played copy is still in the hand here, so a reshuffle cannot draw it back.
	var drawn: int = deck.draw_extra(int(plan["draw"]))
	if not deck.discard_played(str(plan["card_id"])):
		return _refusal("card_not_held")
	return {
		"ok": true,
		"reason": "applied",
		"card_id": str(plan["card_id"]),
		"cost": cost,
		"owner_position": owner_position,
		"target_position": int(plan["target_position"]),
		"block_gained": block,
		"draw_requested": int(plan["draw"]),
		"drawn": drawn,
		"combat_scrap_before": counter_before,
		"combat_scrap_gained": int(plan["combat_scrap_gain"]),
		"combat_scrap_after": counter_before + int(plan["combat_scrap_gain"]),
		"energy_before": int(plan["energy_before"]),
		"energy_after": deck.energy,
	}


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
	if not CARDS.has(id) and not STARTER_CARDS.has(id):
		return _refusal("unsupported_card")
	# Fetch the authored record from the catalog that owns this ID before anything is paid.
	var definition: Dictionary = _definition(id)
	if definition.is_empty():
		return _refusal("catalog_mismatch")
	var card: Dictionary = _spec(id)

	# Validate the complete roster before touching it, then bind the owner by hero ID to its
	# ACTUAL current slot. Swapping seats grants no false authority, and a second Tinker is never
	# resolved as the owner.
	var heroes: Array[Dictionary] = party.get_heroes()
	var seen_ids: Array[String] = []
	var owner_position := 0
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
		# A fresh party has no counter at all; only an explicit non-negative integer is state.
		var counter = hero.get("combat_scrap", 0)
		if not counter is int or counter < 0:
			return _refusal("malformed_combat_scrap")
		seen_ids.append(hero_id)
		if hero_id == OWNER:
			owner_position = index + 1

	if owner_position == 0:
		return _refusal("owner_missing")
	if not card["from_positions"].has(owner_position):
		return _refusal("owner_illegal_position")
	if int(heroes[owner_position - 1]["hp"]) == 0:
		return _refusal("owner_downed")

	# Both starter targets (`self` and `none`) and both pool targets (`self`) live on this helper's
	# sentinel 0: no other slot is ever a legal recipient or picker.
	if target_position != SELF_TARGET:
		return _refusal("invalid_target")

	# Hand membership is the actual held copy, never just a catalog lookup.
	if not deck.hand.has(id):
		return _refusal("card_not_held")
	var cost: int = int(card["cost"])
	if cost < 0 or deck.energy < cost:
		return _refusal("insufficient_energy")

	var owner_record: Dictionary = heroes[owner_position - 1]
	var block: int = int(card["block"])
	if block > 0 and block > CombatParty.MAX_INT - int(owner_record["block"]):
		return _refusal("block_overflow")
	var counter_before: int = int(owner_record.get("combat_scrap", 0))
	var gain: int = int(card["combat_scrap_gain"])
	if gain < 0 or gain > CombatParty.MAX_INT - counter_before:
		return _refusal("combat_scrap_overflow")

	return {
		"ok": true,
		"card_id": id,
		"cost": cost,
		"owner_position": owner_position,
		"target_kind": str(card["target_kind"]),
		"target_position": owner_position if card["target_kind"] == TARGET_KIND else SELF_TARGET,
		"block": block,
		"draw": int(card["draw"]),
		"combat_scrap_before": counter_before,
		"combat_scrap_gain": gain,
		"energy_before": deck.energy,
	}


func _refusal(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
