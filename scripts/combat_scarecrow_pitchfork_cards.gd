class_name CombatScarecrowPitchforkCards
extends RefCounted
## Scene-free paid resolver for the Scarecrow's puncturing pitchfork strikes (V3-1).
##
## Fork Jab is a dedicated v3 starter and Pitchfork Prick a v3 reward-pool card; both print one
## energy, an enemy slot 1-2 reached from hero seat 1-2, and damage plus Bleed. The look is the
## burlap sack body driving a pitchfork through cloth, so every puncture leaves a rip that keeps
## bleeding. This service authenticates the exact held catalog record, then resolves the printed
## damage through the real CombatEnemies damage path (Block absorbs first, HP after) and finally
## adds the printed Bleed to that same enemy's authoritative status map.
##
## The catalogs stay authoritative: the caller supplies only a held ID and a target slot, never a
## card dictionary, a damage magnitude, an owner or a position. CombatDeck, CombatParty and
## CombatEnemies own the real state (hand, energy, piles, hero HP/Block/statuses and enemy
## HP/Block/statuses). Damage uses CombatStatuses.adjusted_attack_damage on the printed positive
## base with the authoritative status records, so Weak/Exposed/Tangled keep their existing
## rounding and Tangled's flat +2. Bleed is applied exactly as printed: the Seamstress-only
## +1 passive never applies here, and nothing ticks, ages or removes a status.
##
## Every rejection is a strict no-op: the complete roster, the target slot, the affordability and
## the status addition are preflighted before the first mutation, and no shuffle, draw or random
## target can advance the run RNG.
##
## This is callable rules-layer behaviour only. It does not register these IDs in the live hand,
## rewards, run deck or the app flow; a later wiring task owns that integration.

const OWNER := "scarecrow"
const TARGET_KIND := "enemy_single"

## The four authentic printings and the exact catalog line each one must still carry.
## `damage` is the printed positive base; `bleed` is the printed stack count. `catalog` names the
## one catalog allowed to own the ID, so a copied record in the other catalog is never paid for.
const CARDS := {
	"scarecrow_fork_jab": {
		"catalog": "starter", "cost": 1, "damage": 4, "bleed": 1,
		"from_positions": [1, 2], "to_positions": [1, 2],
		"upgrade_id": "scarecrow_fork_jab_plus",
	},
	"scarecrow_fork_jab_plus": {
		"catalog": "starter", "cost": 1, "damage": 6, "bleed": 2,
		"from_positions": [1, 2], "to_positions": [1, 2],
		"upgrade_of": "scarecrow_fork_jab",
	},
	"scarecrow_pitchfork_prick": {
		"catalog": "pool", "cost": 1, "damage": 5, "bleed": 1,
		"from_positions": [1, 2], "to_positions": [1, 2],
		"upgrade_id": "scarecrow_pitchfork_prick_plus",
	},
	"scarecrow_pitchfork_prick_plus": {
		"catalog": "pool", "cost": 1, "damage": 7, "bleed": 2,
		"from_positions": [1, 2], "to_positions": [1, 2],
		"upgrade_of": "scarecrow_pitchfork_prick",
	},
}

## CombatStatuses owns this vocabulary; a status map with any other key, type or negative count is
## malformed and refuses the play instead of being coerced into a legal stack.
const STATUS_KEYS: Array[String] = [
	"bleed", "weak", "exposed", "tangled", "riposte",
	"dodge_next_attack", "blind_next_attack", "cannot_buff_next_turn"
]
const COUNTED_STATUS_KEYS: Array[String] = ["bleed", "weak", "exposed", "tangled", "riposte"]
const ONE_SHOT_STATUS_KEYS: Array[String] = ["dodge_next_attack", "blind_next_attack"]
const FEAR_STATUS_KEY := "cannot_buff_next_turn"

var _statuses := CombatStatuses.new()


## True only for the four authentic catalog IDs. Pure lookup; nothing is charged or mutated.
func is_supported_card(card_id: Variant) -> bool:
	return typeof(card_id) == TYPE_STRING and CARDS.has(card_id)


## The single paid transaction: authenticate, preflight every input, then charge the printed cost,
## discard exactly the held copy, resolve the Block/HP hit and add the printed Bleed.
##
## `target_position` must name a live enemy in the authored 1-2 window; slots outside it fail
## closed even when the roster has room.
func play_card(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: Variant, target_position: int = 0) -> Dictionary:
	var plan: Dictionary = _prepare(deck, party, enemies, card_id, target_position)
	if not plan.get("ok", false):
		return _refusal(str(plan.get("reason", "refused")))
	# Every operation below is guaranteed by the complete preflight above: the turn is active, the
	# exact held ID is affordable, the owner sits in an authored seat, the target is a living enemy
	# in the printed window and the printed Bleed stack is admissible. Keep the defensive returns so
	# an unexpected model change still fails closed.
	if not deck.try_spend_energy(plan["cost"]):
		return _refusal("insufficient_energy")
	if not deck.discard_played(plan["card_id"]):
		return _refusal("card_not_held")
	var target_position_value: int = plan["target_position"]
	if not enemies.apply_damage(target_position_value, plan["damage"]):
		return _refusal("invalid_target")
	# Block absorbed the hit before HP (CombatEnemies owns that split); the rip still opens, so the
	# printed Bleed lands even when Block soaked the entire puncture.
	if not enemies.apply_statuses({target_position_value: {"bleed": plan["bleed"]}}):
		return _refusal("malformed_statuses")
	var after: Dictionary = enemies.get_enemy(target_position_value)
	return {
		"ok": true,
		"reason": "applied",
		"card_id": plan["card_id"],
		"cost": plan["cost"],
		"owner_position": plan["owner_position"],
		"target_position": target_position_value,
		"base_damage": plan["base_damage"],
		"damage": plan["damage"],
		"hp_before": plan["hp_before"],
		"hp_after": after["hp"],
		"hp_loss": plan["hp_before"] - int(after["hp"]),
		"block_before": plan["block_before"],
		"block_after": after["block"],
		"block_absorbed": plan["block_before"] - int(after["block"]),
		"bleed_applied": plan["bleed"],
		"bleed_before": plan["bleed_before"],
		"bleed_after": int(after.get("statuses", {}).get("bleed", 0)),
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
	if not enemies.is_valid():
		return _refusal("invalid_enemies")
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

	# Verify the complete roster and every hero's authoritative status shape, then bind the owner
	# by hero ID to its actual current slot. Swapping seats grants no false authority.
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
		if not _valid_status_map(hero.get("statuses", {})):
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
	var owner_statuses: Dictionary = _live_statuses(heroes[owner_position - 1])

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
		var hp = enemy.get("hp")
		var max_hp = enemy.get("max_hp")
		var block = enemy.get("block")
		if not enemy_position is int or enemy_position != index + 1:
			return _refusal("invalid_enemies")
		if not max_hp is int or max_hp <= 0:
			return _refusal("invalid_enemies")
		if not hp is int or hp < 0 or hp > max_hp:
			return _refusal("invalid_enemies")
		if not block is int or block < 0:
			return _refusal("invalid_enemies")
		if not _valid_status_map(enemy.get("statuses", {})):
			return _refusal("malformed_statuses")

	# The pitchfork only reaches the authored front two enemy slots, and only a living one.
	if not target_position is int or target_position < 1 or target_position > roster.size():
		return _refusal("invalid_target")
	if not card["to_positions"].has(target_position):
		return _refusal("invalid_target")
	if int(roster[target_position - 1]["hp"]) == 0:
		return _refusal("invalid_target")
	var target_statuses: Dictionary = _live_statuses(roster[target_position - 1])

	# CombatStatuses owns the Weak/Exposed/Tangled rounding: integer floor once, then a positive-
	# base Tangled defender adds its flat +2. The status maps are read, never consumed.
	var base_damage: int = card["damage"]
	var damage: int = _statuses.adjusted_attack_damage(base_damage, owner_statuses,
		target_statuses)
	if damage < 0:
		return _refusal("damage_overflow")

	# The printed Bleed is an enemy-side stack; preflight the exact addition so a malformed or
	# overflowing counter refuses BEFORE anything is charged.
	var bleed: int = card["bleed"]
	if not enemies.can_apply_statuses({target_position: {"bleed": bleed}}):
		return _refusal("malformed_statuses")

	return {
		"ok": true,
		"card_id": id,
		"cost": cost,
		"owner_position": owner_position,
		"target_position": target_position,
		"base_damage": base_damage,
		"damage": damage,
		"bleed": bleed,
		"hp_before": int(roster[target_position - 1]["hp"]),
		"block_before": int(roster[target_position - 1]["block"]),
		"bleed_before": int(target_statuses.get("bleed", 0)),
	}


## Reads the exact authored record from the catalog that owns this ID (never the other hero
## catalogs) and returns a detached copy, or {} when the ID is not in that catalog.
func _catalog_definition(card_id: String) -> Dictionary:
	var card: Dictionary = CARDS.get(card_id, {})
	var source: Variant = card.get("catalog", "")
	if source == "starter":
		return ScarecrowStarterCards.new().get_definition(card_id)
	if source == "pool":
		return ScarecrowPoolCards.new().get_definition(card_id)
	return {}


## The record must still carry exactly the authored line: owner, cost, seats, single-enemy target,
## the one printed damage plus Bleed pair, and the base/"+" link in its own catalog.
func _authentic(definition: Dictionary, card_id: String, card: Dictionary) -> bool:
	if definition.get("id") != card_id or definition.get("owner") != OWNER:
		return false
	if definition.get("cost") != card["cost"]:
		return false
	if definition.get("target_kind") != TARGET_KIND:
		return false
	if definition.get("from_positions") != card["from_positions"]:
		return false
	var to_positions = definition.get("to_positions")
	if not to_positions is Array or to_positions != card["to_positions"]:
		return false
	if definition.get("effects") != {"damage": card["damage"], "bleed": card["bleed"]}:
		return false
	if card.has("upgrade_id"):
		return definition.get("upgrade_id") == card["upgrade_id"] \
			and not definition.has("upgrade_of")
	return definition.get("upgrade_of") == card["upgrade_of"] \
		and not definition.has("upgrade_id")


## The authoritative status dictionary stored on a real actor record. An absent key means no active
## counters; any other non-dictionary value was already rejected by the roster validation.
func _live_statuses(record: Dictionary) -> Dictionary:
	var value = record.get("statuses", {})
	if not value is Dictionary:
		return {}
	return value


## CombatStatuses' own vocabulary and counter shape; anything else is malformed.
func _valid_status_map(statuses: Variant) -> bool:
	if not statuses is Dictionary:
		return false
	for name in statuses:
		if not name is String or not STATUS_KEYS.has(name):
			return false
		var count = statuses[name]
		if name == FEAR_STATUS_KEY:
			if typeof(count) != TYPE_BOOL or count != true:
				return false
			continue
		if typeof(count) != TYPE_INT:
			return false
		if ONE_SHOT_STATUS_KEYS.has(name):
			if count != 0 and count != 1:
				return false
			continue
		if count < 0:
			return false
	return true


func _refusal(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
