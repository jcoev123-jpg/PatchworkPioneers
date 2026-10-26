class_name CombatScarecrowCrowCards
extends RefCounted
## Scene-free paid resolver for the Scarecrow's shoulder-crow strikes (V3-1).
##
## Crow Dive is a dedicated v3 starter and Crow Peck a v3 reward-pool card; both print one energy,
## the backmost LIVING enemy and `ignore_block: true`. The look is one black crow perched on the
## burlap sack body: it flies over the enemy line and strikes the rearmost survivor, straight through
## Block. This service authenticates the exact held catalog record, resolves the real backmost living
## slot (enemy positions stay fixed when an enemy dies) and then lowers only that enemy's HP by
## min(current HP, adjusted damage). Enemy Block never changes, even when it exceeds the hit.
##
## The catalogs stay authoritative: the caller supplies only a held ID and a target slot, never a
## card dictionary or a damage magnitude. CombatDeck, CombatParty and CombatEnemies own the real
## state (hand, energy, piles, hero HP/Block/statuses and enemy HP/Block/statuses). Damage uses
## CombatStatuses.adjusted_attack_damage on the printed positive base with the authoritative status
## records, so Weak/Exposed/Tangled keep their existing rounding. Nothing here draws, shuffles,
## ages or removes a status, or otherwise advances the run RNG; a refusal is strictly inert.
##
## This is callable rules-layer behaviour only. It does not register these IDs in the live hand,
## rewards, run deck or the app flow; that wiring is a later task.

const OWNER := "scarecrow"
const TARGET_KIND := "enemy_back"
const BLOCK_PIERCE := true

## The four authentic printings and the exact catalog line each one must still carry.
## `damage` is the printed positive base; a "+" only raises it. `catalog` names the one catalog
## that is allowed to own the ID, so a copied record in the other catalog is never paid for.
const CARDS := {
	"scarecrow_crow_dive": {
		"catalog": "starter", "cost": 1, "damage": 3,
		"from_positions": [1, 2, 3], "to_positions": [1, 2, 3],
		"upgrade_id": "scarecrow_crow_dive_plus",
	},
	"scarecrow_crow_dive_plus": {
		"catalog": "starter", "cost": 1, "damage": 5,
		"from_positions": [1, 2, 3], "to_positions": [1, 2, 3],
		"upgrade_of": "scarecrow_crow_dive",
	},
	"scarecrow_crow_peck": {
		"catalog": "pool", "cost": 1, "damage": 4,
		"from_positions": [1, 2, 3], "to_positions": [1, 2, 3],
		"upgrade_id": "scarecrow_crow_peck_plus",
	},
	"scarecrow_crow_peck_plus": {
		"catalog": "pool", "cost": 1, "damage": 6,
		"from_positions": [1, 2, 3], "to_positions": [1, 2, 3],
		"upgrade_of": "scarecrow_crow_peck",
	},
}

## CombatStatuses owns this vocabulary; a status map with any other key, type or negative count is
## malformed and refuses the play instead of being coerced into a legal stack.
const STATUS_KEYS: Array[String] = ["bleed", "weak", "exposed", "tangled", "riposte"]

var _statuses := CombatStatuses.new()


## True only for the four authentic catalog IDs. Pure lookup; nothing is charged or mutated.
func is_supported_card(card_id: Variant) -> bool:
	return typeof(card_id) == TYPE_STRING and CARDS.has(card_id)


## The single paid transaction: authenticate, preflight every input, then charge the printed cost,
## discard exactly the held copy and pierce the backmost living enemy's HP.
##
## `target_position` must name the current highest living enemy slot, so a front choice is refused
## while a farther-back enemy lives. `attacker_statuses` and `enemy_statuses_by_position` are
## optional caller snapshots: when supplied they are validated and must equal the authoritative
## records, so a stale or forged snapshot refuses instead of silently changing the damage.
func play_card(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: Variant, target_position: int = 0,
		attacker_statuses: Dictionary = {},
		enemy_statuses_by_position: Dictionary = {}) -> Dictionary:
	var plan: Dictionary = _prepare(deck, party, enemies, card_id, target_position,
		attacker_statuses, enemy_statuses_by_position)
	if not plan.get("ok", false):
		return _refusal(str(plan.get("reason", "refused")))
	# Every operation below is guaranteed by the complete preflight above: the turn is active, the
	# exact held ID is affordable, the owner sits in an authored seat, the requested slot is the
	# current backmost survivor and both status records are the authoritative ones. Keep the
	# defensive returns so an unexpected model change still fails closed.
	if not deck.try_spend_energy(plan["cost"]):
		return _refusal("insufficient_energy")
	if not deck.discard_played(plan["card_id"]):
		return _refusal("card_not_held")
	# The real selected enemy record, never a detached get_enemy copy. Block is deliberately left
	# alone: the crow pierces it instead of spending it. apply_damage() would absorb Block, so this
	# hit writes the HP loss directly.
	var record: Dictionary = enemies._enemies[plan["target_position"] - 1]
	var hp_before: int = record["hp"]
	var hp_loss: int = mini(hp_before, int(plan["damage"]))
	record["hp"] = hp_before - hp_loss
	return {
		"ok": true,
		"reason": "applied",
		"card_id": plan["card_id"],
		"cost": plan["cost"],
		"owner_position": plan["owner_position"],
		"target_position": plan["target_position"],
		"base_damage": plan["base_damage"],
		"damage": plan["damage"],
		"hp_before": hp_before,
		"hp_after": hp_before - hp_loss,
		"hp_loss": hp_loss,
		"block_before": plan["block_before"],
		"block_after": plan["block_before"],
		"block_absorbed": 0,
		"pierced_block": BLOCK_PIERCE,
	}


## Read-only preflight of the whole transaction. Returns a detached plan or a refusal receipt.
func _prepare(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: Variant, target_position: int, attacker_statuses: Dictionary,
		enemy_statuses_by_position: Dictionary) -> Dictionary:
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
	var owner_statuses: Dictionary = _live_statuses(heroes[owner_position - 1])
	if int(heroes[owner_position - 1]["hp"]) == 0:
		return _refusal("owner_downed")

	# Hand membership is the actual held copy, never just a catalog lookup.
	if not deck.hand.has(id):
		return _refusal("card_not_held")
	var cost: int = card["cost"]
	if cost < 0 or deck.energy < cost:
		return _refusal("insufficient_energy")

	# Verify every enemy slot's authoritative shape before the backmost query, so a malformed roster
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

	# The crow always seeks the highest-position LIVING enemy. Positions stay fixed when an enemy
	# dies, so a dead rear slot is skipped rather than read as the array's last entry.
	var backmost := _backmost_living_position(roster)
	if backmost == 0:
		return _refusal("no_living_target")
	if target_position != backmost:
		return _refusal("invalid_target")
	var target_statuses: Dictionary = _live_statuses(roster[backmost - 1])

	# Caller snapshots are assertions, never authority: a stale or forged one refuses.
	if not attacker_statuses.is_empty() and attacker_statuses != owner_statuses:
		return _refusal("stale_status_snapshot")
	for position in enemy_statuses_by_position:
		if not position is int or position < 1 or position > roster.size():
			return _refusal("invalid_snapshot")
		var snapshot: Variant = enemy_statuses_by_position[position]
		if not snapshot is Dictionary or not _valid_status_map(snapshot):
			return _refusal("malformed_statuses")
		if snapshot != _live_statuses(roster[position - 1]):
			return _refusal("stale_status_snapshot")

	# CombatStatuses owns the Weak/Exposed/Tangled rounding: integer floor once, then a positive-base
	# Tangled defender adds its flat +2. The status maps are read, never consumed.
	var base_damage: int = card["damage"]
	var damage: int = _statuses.adjusted_attack_damage(base_damage, owner_statuses,
		target_statuses)
	if damage < 0:
		return _refusal("damage_overflow")

	return {
		"ok": true,
		"card_id": id,
		"cost": cost,
		"owner_position": owner_position,
		"target_position": backmost,
		"base_damage": base_damage,
		"damage": damage,
		"block_before": int(roster[backmost - 1]["block"]),
	}


## The highest-position enemy still above zero HP, or 0 when every slot is slain.
func _backmost_living_position(roster: Array[Dictionary]) -> int:
	for index in range(roster.size() - 1, -1, -1):
		var hp = roster[index].get("hp")
		if hp is int and hp > 0:
			return index + 1
	return 0


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


## The record must still carry exactly the authored line: owner, cost, seats, backmost target, the
## one printed damage plus the Block bypass, and the base/"+" link in its own catalog.
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
	if definition.get("effects") != {"damage": card["damage"], "ignore_block": BLOCK_PIERCE}:
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
		if not count is int or count < 0:
			return false
	return true


func _refusal(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
