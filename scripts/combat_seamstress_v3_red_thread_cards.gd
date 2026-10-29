class_name CombatSeamstressV3RedThreadCards
extends RefCounted
## Scene-free paid resolver for the Seamstress's six v3 red-thread printings (V3-1).
##
## Thread Prick (v3 starter), Needle Rain and Scarlet Knot (v3 reward pool), each with its "+".
## The tall patched-dress Seamstress wields a giant needle trailing red thread, so Prick and
## Needle Rain puncture ONE chosen living enemy for their printed damage and leave red thread
## behind (Bleed), while Scarlet Knot only ties Bleed and Weak around that enemy and never
## strikes at all. The Bleed these printings apply is the printed amount plus her authored
## passive (+1 whenever she applies Bleed); the catalogs keep the printed amount only and the
## passive is added here, at resolution time.
##
## The caller supplies only a held card ID and one target slot, never a card dictionary, a
## damage magnitude, a status count, an owner or a position list. CombatDeck, CombatParty and
## CombatEnemies own the real state (hand, energy, piles, hero records and enemy HP/Block/
## statuses). The two attacks resolve exactly one hit through CombatStatusAttacks with the
## PRE-HIT status snapshots of the attacking Seamstress and the defending enemy, so Weak/Exposed
## keep CombatStatuses' single floor rounding, Tangled keeps its flat +2, and the defender's
## Block is consumed before HP. The printed Bleed (and Scarlet Knot's printed Weak) is laid
## afterwards on that same original enemy slot through CombatEnemies.can_apply_statuses /
## apply_statuses, so it lands even when Block soaked the whole hit, never boosts the hit that
## just happened, and stays on a slot that the hit confirmed as slain. No status is aged, ticked
## or removed by a card, and no draw, shuffle or random target can advance the run RNG.
##
## Authoritative status maps may legitimately carry the one-shot Dodge token
## (`dodge_next_attack: 0|1`, e.g. a Rag Duelist cape), the one-shot Blind token
## (`blind_next_attack: 0|1`, e.g. a Lantern Monk Moth Cloud) or the Scarecrow's Fear
## (`cannot_buff_next_turn: true`). Every hero and enemy status map is validated here against
## that canonical schema, then ONLY the damage-status subset is handed to CombatStatusAttacks,
## which models none of those tokens. A legal token therefore never turns a paid cast into a
## phantom turn, and no token is ever mutated, spent or dropped from its actor.
##
## This is callable rules-layer behaviour only. It does not register these IDs in the live hand,
## rewards, run deck or the app flow; that mounted enemy-targeted hand wiring is a later task.

const OWNER := "seamstress"
const TARGET_KIND := "enemy_single"

## GAME_DESIGN.md's authored Seamstress passive: when she applies Bleed, add one more Bleed.
## It is applied here at resolution and is never baked into the printed catalog entries.
const PASSIVE_BLEED := 1

## The status keys whose counters modify one attack, exactly as CombatStatusAttacks accepts them.
const ATTACK_STATUS_KEYS: Array[String] = ["bleed", "weak", "exposed", "tangled", "riposte"]

## The four authentic starter printings and the two reward printings, each with the exact
## catalog line it must still carry. `catalog` names the one catalog allowed to own the ID, so a
## copied record in another catalog is never paid for. `damage` is the printed positive base (0
## for Scarlet Knot, which never attacks), `bleed` the printed stack before the +1 passive and
## `weak` the printed Weak stack.
const CARDS := {
	"seamstress_v3_thread_prick": {
		"catalog": "starter", "name": "Thread Prick", "cost": 1,
		"damage": 3, "bleed": 2, "weak": 0,
		"from_positions": [1, 2, 3], "to_positions": [1, 2, 3],
		"starting_copies": 1, "reward_eligible": false,
		"upgrade_id": "seamstress_v3_thread_prick_plus",
	},
	"seamstress_v3_thread_prick_plus": {
		"catalog": "starter", "name": "Thread Prick+", "cost": 1,
		"damage": 4, "bleed": 3, "weak": 0,
		"from_positions": [1, 2, 3], "to_positions": [1, 2, 3],
		"starting_copies": 0, "reward_eligible": false,
		"upgrade_of": "seamstress_v3_thread_prick",
	},
	"seamstress_v3_needle_rain": {
		"catalog": "pool", "name": "Needle Rain", "cost": 1,
		"damage": 2, "bleed": 3, "weak": 0,
		"from_positions": [1, 2, 3], "to_positions": [1, 2, 3],
		"starting_copies": 0, "rarity": "common", "reward_eligible": true,
		"upgrade_id": "seamstress_v3_needle_rain_plus",
	},
	"seamstress_v3_needle_rain_plus": {
		"catalog": "pool", "name": "Needle Rain+", "cost": 1,
		"damage": 3, "bleed": 4, "weak": 0,
		"from_positions": [1, 2, 3], "to_positions": [1, 2, 3],
		"starting_copies": 0, "rarity": "common", "reward_eligible": false,
		"upgrade_of": "seamstress_v3_needle_rain",
	},
	"seamstress_v3_scarlet_knot": {
		"catalog": "pool", "name": "Scarlet Knot", "cost": 1,
		"damage": 0, "bleed": 2, "weak": 1,
		"from_positions": [1, 2, 3], "to_positions": [1, 2, 3],
		"starting_copies": 0, "rarity": "common", "reward_eligible": true,
		"upgrade_id": "seamstress_v3_scarlet_knot_plus",
	},
	"seamstress_v3_scarlet_knot_plus": {
		"catalog": "pool", "name": "Scarlet Knot+", "cost": 1,
		"damage": 0, "bleed": 3, "weak": 1,
		"from_positions": [1, 2, 3], "to_positions": [1, 2, 3],
		"starting_copies": 0, "rarity": "common", "reward_eligible": false,
		"upgrade_of": "seamstress_v3_scarlet_knot",
	},
}

const _STARTER_CATALOG := preload("res://data/cards/v3_seamstress_starter_cards.gd")
const _POOL_CATALOG := preload("res://data/cards/v3_seamstress_pool_cards.gd")

var _attacks := CombatStatusAttacks.new()
var _statuses := CombatStatuses.new()


## True only for the six authentic catalog IDs. Pure lookup; nothing is charged or mutated.
func is_supported_card(card_id: Variant) -> bool:
	return typeof(card_id) == TYPE_STRING and CARDS.has(card_id)


## True only when the ID is one of the six AND the catalog that owns it still carries the exact
## authored line. Pure lookup; nothing is charged or mutated.
func is_authentic_card(card_id: Variant) -> bool:
	if not is_supported_card(card_id):
		return false
	var id: String = card_id
	return _authentic(_catalog_definition(id), id, CARDS[id])


## The single paid transaction: authenticate the printing, preflight every input, then charge the
## printed one energy, discard exactly the held copy, resolve the printed hit (attack printings
## only) and lay the printed Bleed plus the +1 passive (and Scarlet Knot's printed Weak) on the
## same original enemy slot. A refusal changes no deck, party, enemy or RNG state.
##
## `target_position` must name a living original enemy slot in the printed TO window; a slain or
## out-of-range slot fails closed and is never replaced by a surviving "compacted" slot.
func play_card(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: Variant, target_position: int = 0) -> Dictionary:
	var plan: Dictionary = _prepare(deck, party, enemies, card_id, target_position)
	if not plan.get("ok", false):
		return plan
	# Every operation below is guaranteed by the complete preflight above: the turn is active, the
	# exact held ID is affordable, the unique living owner sits in a printed seat, the target is a
	# living original enemy slot and both printed status additions are admissible. Keep the
	# defensive returns so an unexpected model change still fails closed.
	if not deck.try_spend_energy(plan["cost"]):
		return _refusal("insufficient_energy")
	if not deck.discard_played(plan["card_id"]):
		return _refusal("card_not_held")

	var damage := 0
	var block_absorbed := 0
	var hp_loss := 0
	if int(plan["base_damage"]) > 0:
		# Exactly one hit, with the actual pre-hit attacker/defender damage-status snapshots. The
		# bridge owns Block-before-HP and the shared status math; nothing here re-implements it.
		var hit: Dictionary = _attacks.resolve_vs_enemy(enemies, plan["target_position"],
			plan["base_damage"], plan["attacker_statuses"], plan["defender_statuses"])
		if not hit.get("ok", false):
			# Preflight proved the bridge accepts these detached maps. If a model change still
			# refuses, never publish an applied receipt for a hit no event backs: report the truth.
			return {
				"ok": false, "reason": "bridge_rejected", "card_id": plan["card_id"],
				"cost": plan["cost"], "owner_position": plan["owner_position"],
				"target_position": plan["target_position"], "damage": 0, "base_damage": 0,
				"passive_bleed": PASSIVE_BLEED, "bleed_applied": 0, "weak_applied": 0,
				"block_absorbed": 0, "hp_loss": 0,
			}
		damage = int(hit["damage"])
		block_absorbed = int(hit["block_absorbed"])
		hp_loss = int(hit["hp_loss"])

	# The new red thread is laid only AFTER the hit, so it can never change the strike that just
	# happened, and it stays on the original slot even when that strike was confirmed lethal.
	if not enemies.apply_statuses({plan["target_position"]: plan["additions"]}):
		return _refusal("malformed_statuses")

	var after: Dictionary = enemies.get_enemy(plan["target_position"])
	var after_statuses: Dictionary = _live_statuses(after)
	return {
		"ok": true,
		"reason": "applied",
		"card_id": plan["card_id"],
		"cost": plan["cost"],
		"owner_position": plan["owner_position"],
		"target_position": plan["target_position"],
		"printed_damage": plan["printed_damage"],
		"base_damage": plan["base_damage"],
		"damage": damage,
		"hp_before": plan["hp_before"],
		"hp_after": int(after.get("hp", 0)),
		"hp_loss": hp_loss,
		"block_before": plan["block_before"],
		"block_after": int(after.get("block", 0)),
		"block_absorbed": block_absorbed,
		"passive_bleed": PASSIVE_BLEED,
		"bleed_applied": int(plan["additions"]["bleed"]),
		"bleed_before": int(plan["bleed_before"]),
		"bleed_after": int(after_statuses.get("bleed", 0)),
		"weak_applied": int(plan["additions"].get("weak", 0)),
		"weak_before": int(plan["weak_before"]),
		"weak_after": int(after_statuses.get("weak", 0)),
	}


## Read-only preflight of the whole transaction. Returns a detached plan or a refusal receipt.
func _prepare(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: Variant, target_position: int) -> Dictionary:
	if deck == null or party == null or enemies == null:
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
	# Fetch the authored record from the one catalog that owns this ID; a rewritten, relinked or
	# copied record can never be paid for as this effect.
	var definition: Dictionary = _catalog_definition(id)
	if not _authentic(definition, id, card):
		return _refusal("catalog_mismatch")
	if not enemies.is_valid():
		return _refusal("invalid_enemies")

	# Verify the complete hero roster and bind the owner by hero ID to its actual current slot.
	# Swapping seats grants no false authority, and the duplicate check keeps the owner unique.
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
		seen_ids.append(hero_id)
		if hero_id == OWNER:
			owner_position = index + 1
	# The canonical status schema, over the COMPLETE rosters: an unknown key, a wrong Variant
	# type, a negative counter or a non-0/1 one-shot token refuses before anything is charged.
	if not CombatStatusTurnBatch.new().tick_side("heroes", heroes).get("ok", false):
		return _refusal("malformed_statuses")

	if owner_position == 0:
		return _refusal("owner_missing")
	if not card["from_positions"].has(owner_position):
		return _refusal("owner_illegal_position")
	if int(heroes[owner_position - 1]["hp"]) == 0:
		return _refusal("owner_downed")
	# Hand membership is the actual held copy, never just a catalog lookup.
	if not deck.hand.has(id):
		return _refusal("card_not_held")
	var cost: int = card["cost"]
	if cost < 0 or deck.energy < cost:
		return _refusal("insufficient_energy")

	# Verify every enemy slot's authoritative shape before the target query, so a malformed roster
	# never masquerades as a legal target.
	var roster: Array[Dictionary] = enemies.get_enemies()
	for index in range(roster.size()):
		var enemy: Dictionary = roster[index]
		var enemy_position = enemy.get("position")
		var enemy_hp = enemy.get("hp")
		var enemy_max_hp = enemy.get("max_hp")
		var enemy_block = enemy.get("block")
		if not enemy_position is int or enemy_position != index + 1:
			return _refusal("invalid_enemies")
		if not enemy_max_hp is int or enemy_max_hp <= 0:
			return _refusal("invalid_enemies")
		if not enemy_hp is int or enemy_hp < 0 or enemy_hp > enemy_max_hp:
			return _refusal("invalid_enemies")
		if not enemy_block is int or enemy_block < 0:
			return _refusal("invalid_enemies")
	if not CombatStatusTurnBatch.new().tick_side("enemies", roster).get("ok", false):
		return _refusal("malformed_statuses")

	# The chosen enemy must be a LIVING actor in this card's printed TO window, addressed by its
	# original roster slot. A slain slot is refused, never replaced by a surviving neighbour.
	if target_position < 1 or target_position > roster.size():
		return _refusal("invalid_target")
	if not card["to_positions"].has(target_position):
		return _refusal("invalid_target")
	var target_record: Dictionary = roster[target_position - 1]
	if int(target_record["position"]) != target_position or int(target_record["hp"]) == 0:
		return _refusal("invalid_target")
	var target_statuses: Dictionary = _live_statuses(target_record)

	# Only the damage-status subset reaches the bridge; the authoritative maps keep every valid
	# token, so Dodge/Blind/Fear can never block a paid cast or be consumed by it.
	var attacker_statuses: Variant = _attack_statuses(heroes[owner_position - 1].get("statuses", {}))
	if attacker_statuses == null:
		return _refusal("malformed_statuses")
	var defender_statuses: Variant = _attack_statuses(target_record.get("statuses", {}))
	if defender_statuses == null:
		return _refusal("malformed_statuses")

	# Size the exact hit before payment: a positive printed base that the shared status rules
	# collapse to zero is an arithmetic overflow, never a silent free hit.
	var printed_damage: int = int(card["damage"])
	var base_damage := printed_damage
	var damage := 0
	if base_damage > 0:
		damage = _statuses.adjusted_attack_damage(base_damage, attacker_statuses,
			defender_statuses)
		if damage <= 0:
			return _refusal("damage_overflow")

	# The printed Bleed plus her +1 passive, and Scarlet Knot's printed Weak. Preflight the exact
	# cumulative counters so a malformed or overflowing stack refuses BEFORE anything is charged.
	var bleed_applied: int = int(card["bleed"]) + PASSIVE_BLEED
	var weak_applied: int = int(card["weak"])
	var bleed_before: int = int(target_statuses.get("bleed", 0))
	var weak_before: int = int(target_statuses.get("weak", 0))
	if bleed_applied > CombatEnemies.MAX_INT - bleed_before:
		return _refusal("status_overflow")
	if weak_applied > CombatEnemies.MAX_INT - weak_before:
		return _refusal("status_overflow")
	var additions := {"bleed": bleed_applied}
	if weak_applied > 0:
		additions["weak"] = weak_applied
	if not enemies.can_apply_statuses({target_position: additions}):
		return _refusal("malformed_statuses")

	return {
		"ok": true,
		"card_id": id,
		"cost": cost,
		"owner_position": owner_position,
		"target_position": target_position,
		"printed_damage": printed_damage,
		"damage": damage,
		"base_damage": base_damage,
		"hp_before": int(target_record["hp"]),
		"block_before": int(target_record["block"]),
		"bleed_before": bleed_before,
		"weak_before": weak_before,
		"additions": additions,
		"attacker_statuses": attacker_statuses,
		"defender_statuses": defender_statuses,
	}


## Reads the exact authored record from the catalog that owns this ID (never the other hero
## catalogs) and returns a detached copy, or {} when the ID is not in that catalog.
func _catalog_definition(card_id: String) -> Dictionary:
	var card: Dictionary = CARDS.get(card_id, {})
	var source: Variant = card.get("catalog", "")
	if source == "starter":
		return _STARTER_CATALOG.new().get_definition(card_id)
	if source == "pool":
		return _POOL_CATALOG.new().get_definition(card_id)
	return {}


## The record must still carry exactly the authored line: the printed name and owner, one energy,
## the single-living-enemy target with both printed position arrays, the complete printed effect
## dictionary, the authored copy/reward metadata (and pool rarity), and the base/"+" link inside
## its own catalog. A starter record carries no rarity at all.
func _authentic(definition: Dictionary, card_id: String, card: Dictionary) -> bool:
	if definition.is_empty():
		return false
	var expected := {
		"id": card_id,
		"display_name": card["name"],
		"owner": OWNER,
		"cost": card["cost"],
		"target_kind": TARGET_KIND,
		"from_positions": card["from_positions"],
		"to_positions": card["to_positions"],
		"effects": _printed_effects(card),
		"starting_copies": card["starting_copies"],
		"reward_eligible": card["reward_eligible"],
	}
	if card.has("rarity"):
		expected["rarity"] = card["rarity"]
	elif definition.has("rarity"):
		return false
	var link := "upgrade_of" if card.has("upgrade_of") else "upgrade_id"
	expected[link] = card[link]
	for other: String in ["upgrade_id", "upgrade_of"]:
		if other != link and definition.has(other):
			return false
	for field in expected:
		if not definition.has(field) or not _same_value(definition[field], expected[field]):
			return false
	return true


## The complete printed effect dictionary for one printing, stated independently of the catalog.
## Scarlet Knot prints no `damage` key at all: it is a status-only card.
func _printed_effects(card: Dictionary) -> Dictionary:
	var effects := {"bleed": card["bleed"]}
	if int(card["damage"]) > 0:
		effects["damage"] = card["damage"]
	if int(card["weak"]) > 0:
		effects["weak"] = card["weak"]
	return effects


## Typed equality rejects coercible metadata (for example a float cost or a string Bleed) as well
## as altered seats, effects or upgrade links.
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


## The authoritative status dictionary stored on a real actor record. An absent key means no
## active counters; any other non-dictionary value was already rejected by the roster check.
func _live_statuses(record: Dictionary) -> Dictionary:
	var value = record.get("statuses", {})
	if not value is Dictionary:
		return {}
	return value


## A detached copy of one authoritative status map holding only the counters that modify attack
## damage. Returns null for a non-Dictionary map, a non-String key or a malformed counter. The
## authoritative map itself is never modified, so a valid Dodge/Blind/Fear token stays on its
## actor for the resolvers that own it.
func _attack_statuses(statuses: Variant) -> Variant:
	if not statuses is Dictionary:
		return null
	var authoritative: Dictionary = statuses
	var detached := {}
	for name in authoritative:
		if not name is String or not ATTACK_STATUS_KEYS.has(name):
			continue
		var count: Variant = authoritative[name]
		if not count is int or count < 0:
			return null
		detached[name] = count
	return detached


func _refusal(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
