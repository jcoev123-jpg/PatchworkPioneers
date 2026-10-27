class_name CombatYarnRangerBolasCards
extends RefCounted
## Scene-free paid resolver for the Yarn Ranger's look-driven bolas families (V3-1/V3-2).
##
## Wool Bolas (starter) and Tangle Bolas (pool) are single-enemy attacks that deal printed
## damage and then add printed Tangled to that same target. Base and upgraded printings are
## all one energy, cast from the middle or back seat (FROM 2-3), and target one living enemy
## in positions 1-3 (TO 1-3).
##
## The catalogs stay authoritative: the caller supplies a held ID and a target seat, never a
## card record, damage value or Tangled count. Each ID is authenticated against its own
## catalog record before anything is paid, so a forged, rewritten, relinked or foreign record
## is refused instead of resolving as a bolas card.
##
## Damage is resolved through CombatStatusAttacks against the target's PRE-HIT statuses, so
## an enemy already Tangled confers its flat +2 even when the damage is fully absorbed by
## Block. The NEW Tangled added by this same hit never boosts it. After the hit, the printed
## Tangled count is added to that same authoritative enemy slot; a confirmed lethal hit
## therefore keeps its status on the nonmoving original slot.
##
## Every rejection is a pure no-op: no energy, hand, pile, party, enemy or RNG change. This
## is callable rules-layer behaviour only; registering these IDs in the live hand or reward
## flow is a later, separately owned wiring task. Real held-card app dispatch is a later
## task, not live playable cards.

const OWNER := "yarn_ranger"
const TARGET_KIND := "enemy_single"
const FROM_POSITIONS := [2, 3]
const TO_POSITIONS := [1, 2, 3]

## The four authentic printings and the exact catalog line each one must still carry. `name` is
## the printed display name, `damage` the printed damage, `tangled` the printed Tangled count
## added after the hit, and `catalog` the single catalog allowed to own that ID.
const CARDS := {
	"yarn_ranger_wool_bolas": {
		"name": "Wool Bolas",
		"cost": 1,
		"damage": 2,
		"tangled": 1,
		"effects": {"damage": 2, "tangled": 1},
		"catalog": "starter",
		"upgrade_id": "yarn_ranger_wool_bolas_plus",
	},
	"yarn_ranger_wool_bolas_plus": {
		"name": "Wool Bolas+",
		"cost": 1,
		"damage": 3,
		"tangled": 2,
		"effects": {"damage": 3, "tangled": 2},
		"catalog": "starter",
		"upgrade_of": "yarn_ranger_wool_bolas",
	},
	"yarn_ranger_tangle_bolas": {
		"name": "Tangle Bolas",
		"cost": 1,
		"damage": 2,
		"tangled": 2,
		"effects": {"damage": 2, "tangled": 2},
		"catalog": "pool",
		"upgrade_id": "yarn_ranger_tangle_bolas_plus",
	},
	"yarn_ranger_tangle_bolas_plus": {
		"name": "Tangle Bolas+",
		"cost": 1,
		"damage": 3,
		"tangled": 3,
		"effects": {"damage": 3, "tangled": 3},
		"catalog": "pool",
		"upgrade_of": "yarn_ranger_tangle_bolas",
	},
}

const _STARTER_CATALOG := preload("res://data/cards/yarn_ranger_starter_cards.gd")
const _POOL_CATALOG := preload("res://data/cards/yarn_ranger_pool_cards.gd")

var _batch := CombatStatusTurnBatch.new()
var _attacks := CombatStatusAttacks.new()


## True only for the four authentic catalog IDs. Pure lookup; nothing is charged or mutated.
func is_supported_card(card_id: Variant) -> bool:
	return typeof(card_id) == TYPE_STRING and CARDS.has(card_id)


## A detached, shape-checked bolas definition from the catalog that owns the ID, or {} for
## anything else. Unrelated cards, forged spellings and tampered records all resolve to {}.
static func bolas_definition(card_id: Variant) -> Dictionary:
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


## The record must still carry exactly the authored line: id, printed name, owner, printed
## one-energy cost, the middle/back FROM line, the single-enemy target, the 1-3 TO line, exactly
## the printed damage and Tangled (integer types only, no extra keys) and the base/"+" link in its
## own catalog.
static func is_authentic_definition(definition: Variant, card_id: Variant) -> bool:
	if typeof(definition) != TYPE_DICTIONARY or typeof(card_id) != TYPE_STRING:
		return false
	var id: String = card_id
	var card: Dictionary = CARDS.get(id, {})
	if card.is_empty():
		return false
	if definition.get("id") != id or definition.get("owner") != OWNER:
		return false
	if definition.get("display_name") != card["name"]:
		return false
	if typeof(definition.get("cost")) != TYPE_INT or definition["cost"] != card["cost"]:
		return false
	if definition.get("target_kind") != TARGET_KIND:
		return false
	if typeof(definition.get("from_positions")) != TYPE_ARRAY \
			or definition["from_positions"] != FROM_POSITIONS:
		return false
	var to_positions: Variant = definition.get("to_positions")
	if typeof(to_positions) != TYPE_ARRAY or to_positions != TO_POSITIONS:
		return false
	var effects: Variant = definition.get("effects")
	if typeof(effects) != TYPE_DICTIONARY or (effects as Dictionary).size() != 2:
		return false
	var damage: Variant = (effects as Dictionary).get("damage")
	var tangled: Variant = (effects as Dictionary).get("tangled")
	if typeof(damage) != TYPE_INT or typeof(tangled) != TYPE_INT:
		return false
	if damage != card["damage"] or tangled != card["tangled"]:
		return false
	if effects != card["effects"]:
		return false
	if card.has("upgrade_id"):
		return definition.get("upgrade_id") == card["upgrade_id"] \
			and not definition.has("upgrade_of")
	return definition.get("upgrade_of") == card["upgrade_of"] \
		and not definition.has("upgrade_id")


## The single paid transaction: authenticate, preflight the whole request, then charge once, resolve
## printed damage against the target's pre-hit statuses through CombatStatusAttacks, add the printed
## Tangled to that same enemy and discard the held copy. A refusal changes no deck, party, enemy
## or RNG state.
func play_card(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: Variant, target_position: int) -> Dictionary:
	var plan: Dictionary = _prepare(deck, party, enemies, card_id, target_position)
	if not plan.get("ok", false):
		return _refusal(str(plan.get("reason", "refused")))
	# Every operation below is guaranteed by the complete preflight above. Keep the defensive
	# returns so an unexpected model change still fails closed before any status is written.
	if not deck.try_spend_energy(plan["cost"]):
		return _refusal("insufficient_energy")
	if not deck.discard_played(plan["card_id"]):
		return _refusal("card_not_held")
	var hit: Dictionary = _attacks.resolve_vs_enemy(
		enemies, target_position, plan["base_damage"],
		plan["attacker_statuses"], plan["defender_statuses"])
	if not hit.get("ok", false):
		return _refusal("invalid_target")
	# Add the NEW Tangled after the hit; it never boosts this same hit. The slot is retained
	# even on a confirmed lethal hit, so the status lands on the nonmoving original slot.
	var record: Dictionary = enemies._enemies[target_position - 1]
	if not record.has("statuses"):
		record["statuses"] = {}
	var statuses: Dictionary = record["statuses"]
	var added: int = plan["tangled_added"]
	statuses["tangled"] = int(statuses.get("tangled", 0)) + added
	return {
		"ok": true,
		"reason": "applied",
		"card_id": plan["card_id"],
		"cost": plan["cost"],
		"owner_position": plan["owner_position"],
		"target_position": target_position,
		"damage": hit.get("damage", 0),
		"block_absorbed": hit.get("block_absorbed", 0),
		"hp_loss": hit.get("hp_loss", 0),
		"tangled_added": added,
	}


func _prepare(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: Variant, target_position: int) -> Dictionary:
	if deck == null or party == null or enemies == null:
		return _refusal("invalid_request")
	if typeof(card_id) != TYPE_STRING:
		return _refusal("unsupported_card")
	var id: String = card_id
	var card: Dictionary = CARDS.get(id, {})
	if card.is_empty():
		return _refusal("unsupported_card")
	# The authored catalog that owns this ID must still carry the exact printed line.
	var definition: Dictionary = {}
	if card["catalog"] == "starter":
		definition = _STARTER_CATALOG.new().get_definition(id)
	else:
		definition = _POOL_CATALOG.new().get_definition(id)
	if not is_authentic_definition(definition, id):
		return _refusal("catalog_mismatch")

	if deck.combat_state == null or not deck.turn_active:
		return _refusal("inactive_turn")
	if not party.is_valid() or not enemies.is_valid():
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
		seen_ids.append(hero_id as String)
		if hero_id == OWNER:
			owner_position = index + 1
	if owner_position == 0:
		return _refusal("owner_missing")
	if heroes[owner_position - 1]["hp"] == 0:
		return _refusal("owner_downed")
	if not FROM_POSITIONS.has(owner_position):
		return _refusal("owner_illegal_position")

	# Shared validator for the whole party, including status maps.
	if not _batch.tick_side("heroes", heroes).get("ok", false):
		return _refusal("invalid_party")

	var roster: Array[Dictionary] = enemies.get_enemies()
	if not _batch.tick_side("enemies", roster).get("ok", false):
		return _refusal("invalid_enemies")

	# Hand membership is the actual held copy, never just a catalog lookup.
	if not deck.hand.has(id):
		return _refusal("card_not_held")
	var cost: int = card["cost"]
	if cost < 0 or deck.energy < cost:
		return _refusal("insufficient_energy")

	# Target must be a living enemy in a legal slot.
	if target_position < 1 or target_position > roster.size():
		return _refusal("invalid_target")
	if enemies.is_slain(target_position):
		return _refusal("target_downed")

	var base_damage: int = card["damage"]
	var added: int = card["tangled"]

	# Pre-hit statuses: attacker from the Yarn Ranger, defender from the chosen enemy.
	var attacker_raw: Variant = _read_statuses(heroes[owner_position - 1])
	if not attacker_raw is Dictionary:
		return _refusal("invalid_party")
	var attacker_statuses: Dictionary = attacker_raw
	var defender_record: Dictionary = enemies.get_enemy(target_position)
	var defender_raw: Variant = _read_statuses(defender_record)
	if not defender_raw is Dictionary:
		return _refusal("invalid_enemies")
	var defender_statuses: Dictionary = defender_raw
	if not _valid_statuses(attacker_statuses) or not _valid_statuses(defender_statuses):
		return _refusal("invalid_statuses")

	# Preflight Tangled overflow against the pre-hit counter.
	var current_tangled: int = int(defender_statuses.get("tangled", 0))
	if added > CombatStatuses.MAX_INT - current_tangled:
		return _refusal("status_overflow")

	return {
		"ok": true,
		"card_id": id,
		"cost": cost,
		"owner_position": owner_position,
		"target_position": target_position,
		"base_damage": base_damage,
		"tangled_added": added,
		"attacker_statuses": attacker_statuses.duplicate(true),
		"defender_statuses": defender_statuses.duplicate(true),
	}


func _read_statuses(actor: Dictionary) -> Variant:
	if not actor.has("statuses"):
		return {}
	return actor.get("statuses")


## Mirrors CombatStatusAttacks' own status vocabulary exactly, so a map that passes this preflight
## can never make the paid hit fail after the charge. Any broader shared vocabulary stays with the
## status owners; this card only ever adds Tangled after the hit.
func _valid_statuses(statuses: Dictionary) -> bool:
	if not statuses is Dictionary:
		return false
	for name in statuses:
		if not name is String or name not in ["bleed", "weak", "exposed", "tangled", "riposte"]:
			return false
		var count = statuses[name]
		if not count is int or count < 0:
			return false
	return true


func _refusal(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}