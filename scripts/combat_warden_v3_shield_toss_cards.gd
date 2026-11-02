class_name CombatWardenV3ShieldTossCards
extends RefCounted
## Scene-free paid resolver for the Warden's look-driven Block-scaling tosses (V3-1).
##
## Rim Toss is a v3 starter card and Shield Toss a v3 reward-pool card; both print
## `damage_equal_to_owner_block`, so one hit deals damage equal to the Warden's OWN current Block
## (plus the authored `bonus_damage` of the "+") and that Block is never spent. The huge patch
## shield is the whole mechanic, not a flat attack number.
##
## The catalogs stay authoritative: this service authenticates the exact held ID and its printed
## metadata, then reads the live Warden Block and enemy Block/HP from the real models. It reuses
## CombatStatusAttacks so supplied Weak (-25%) / Exposed (+50%) snapshots keep the existing
## floor-once rounding and enemy Block absorbs before HP.
##
## This is a callable combat rules slice only. It does not register these IDs in live rewards, a
## run deck, the mounted hand or any app flow; that wiring is a later task. It also never touches
## the run RNG: no draw, shuffle or target selection happens here.

const OWNER := "warden"
const TARGET_KIND := "enemy_single"
const FROM_POSITIONS := [1, 2]
const TO_POSITIONS := [1, 2, 3]

## The four authentic IDs and the exact catalog line each one must still carry.
## `bonus_damage` is the only difference between a base card and its "+".
const CARDS := {
	"warden_v3_rim_toss": {
		"catalog": "starter",
		"cost": 1,
		"bonus_damage": 0,
		"effects": {"damage_equal_to_owner_block": true},
	},
	"warden_v3_rim_toss_plus": {
		"catalog": "starter",
		"cost": 1,
		"bonus_damage": 2,
		"effects": {"damage_equal_to_owner_block": true, "bonus_damage": 2},
	},
	"warden_v3_shield_toss": {
		"catalog": "pool",
		"cost": 1,
		"bonus_damage": 0,
		"effects": {"damage_equal_to_owner_block": true},
	},
	"warden_v3_shield_toss_plus": {
		"catalog": "pool",
		"cost": 1,
		"bonus_damage": 3,
		"effects": {"damage_equal_to_owner_block": true, "bonus_damage": 3},
	},
}

var _damage := CombatStatusAttacks.new()
var _keywords := CombatEnemyKeywordRules.new()


## The single paid transaction: authenticate, preflight every input, then charge 1 energy, discard
## exactly the held copy and land one hit. A rejection changes no deck, party, enemy or RNG state.
## `attacker_statuses` describes the Warden and `defender_statuses` the chosen enemy for this
## resolution; both default to no active statuses.
func play_card(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: String, target_position: int = 0, attacker_statuses: Dictionary = {},
		defender_statuses: Dictionary = {},
		needle_rules: CombatHeirloomPatchTriggers = null,
		needle_quote: Dictionary = {}) -> Dictionary:
	var needle_bonus := 0
	if needle_rules != null or not needle_quote.is_empty():
		if needle_rules == null or not needle_rules.authorizes_needle_hit(
				needle_quote, party, enemies, card_id, target_position):
			if needle_rules != null:
				needle_rules.cancel_needle_hit()
			return _failure()
		needle_bonus = 1
	var plan: Dictionary = _prepare(deck, party, enemies, card_id, target_position,
		attacker_statuses, defender_statuses, needle_bonus)
	if not plan.get("ok", false):
		if needle_rules != null:
			needle_rules.cancel_needle_hit()
		return _failure()
	# Every operation below is guaranteed by the complete preflight above: the turn is active,
	# the held ID exists, the cost is affordable and the target is a living roster slot. Keep the
	# defensive returns so an unexpected model change still fails closed.
	var pre_hit_enemy: Dictionary = enemies.get_enemy(plan["target_position"])
	if not deck.try_spend_energy(plan["cost"]):
		if needle_rules != null:
			needle_rules.cancel_needle_hit()
		return _failure()
	if not deck.discard_played(card_id):
		if needle_rules != null:
			needle_rules.cancel_needle_hit()
		return _failure()
	var event: Dictionary = _damage.resolve_vs_enemy(enemies, plan["target_position"],
		plan["base_damage"], plan["attacker_statuses"], plan["defender_statuses"])
	if not event.get("ok", false):
		if needle_rules != null:
			needle_rules.cancel_needle_hit()
		return _failure()
	_keywords.commit_enrage_after_hit(enemies, plan["target_position"], pre_hit_enemy, event)
	_keywords.resolve_thorns_retaliation(party, plan["owner_position"], pre_hit_enemy, event)
	var receipt := {
		"ok": true,
		"card_id": card_id,
		"cost": plan["cost"],
		"owner_position": plan["owner_position"],
		"owner_block": plan["owner_block"],
		"bonus_damage": plan["bonus_damage"],
		"base_damage": plan["base_damage"],
		"target_position": plan["target_position"],
		"damage": event["damage"],
		"block_absorbed": event["block_absorbed"],
		"hp_loss": event["hp_loss"],
	}
	if needle_rules != null:
		needle_rules.finish_needle_hit(needle_quote, receipt)
	return receipt


## True only for the four authentic catalog IDs. Pure lookup; nothing is charged or mutated.
func is_supported_card(card_id: Variant) -> bool:
	return typeof(card_id) == TYPE_STRING and CARDS.has(card_id)


## Read-only preflight of the whole transaction. Returns a detached plan or a failure record.
func _prepare(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: String, target_position: int, attacker_statuses: Dictionary,
		defender_statuses: Dictionary, needle_bonus: int = 0) -> Dictionary:
	if deck == null or party == null or enemies == null:
		return _failure()
	if deck.combat_state == null or deck._rng == null or not deck.turn_active:
		return _failure()
	if not party.is_valid() or not enemies.is_valid() or enemies.is_victorious():
		return _failure()

	var card: Dictionary = CARDS.get(card_id, {})
	if card.is_empty():
		return _failure()
	var definition: Dictionary = _catalog_definition(card_id)
	if not _authentic(definition, card_id, card):
		return _failure()
	# The cards must be genuinely held and affordable before any state changes.
	if not deck.hand.has(card_id):
		return _failure()
	var cost_value: int = card["cost"]
	if cost_value > deck.energy:
		return _failure()

	# Verify the complete hero roster, then bind the owner by ID to its actual current slot.
	var heroes: Array[Dictionary] = party.get_heroes()
	var owner_position := 0
	var seen_ids: Array[String] = []
	for index in range(CombatParty.PARTY_SIZE):
		var hero: Dictionary = heroes[index]
		var id = hero.get("id")
		var position = hero.get("position")
		var hp = hero.get("hp")
		var max_hp = hero.get("max_hp")
		var block = hero.get("block")
		if not id is String or id.is_empty() or seen_ids.has(id):
			return _failure()
		if not position is int or position != index + 1:
			return _failure()
		if not hp is int or not max_hp is int or max_hp <= 0 or hp < 0 or hp > max_hp:
			return _failure()
		if not block is int or block < 0:
			return _failure()
		seen_ids.append(id)
		if id == OWNER:
			owner_position = index + 1
	# A downed Warden is torn and cannot cast; the card prints FROM 1-2 only.
	if owner_position == 0 or not FROM_POSITIONS.has(owner_position):
		return _failure()
	if heroes[owner_position - 1]["hp"] == 0:
		return _failure()

	# Verify the whole enemy roster and the chosen original slot; positions never compact.
	var enemy_records: Array[Dictionary] = enemies.get_enemies()
	var seen_enemy_ids: Array[String] = []
	for index in range(enemy_records.size()):
		var enemy: Dictionary = enemy_records[index]
		var enemy_id = enemy.get("id")
		var enemy_position = enemy.get("position")
		var enemy_hp = enemy.get("hp")
		var enemy_max_hp = enemy.get("max_hp")
		var enemy_block = enemy.get("block")
		if not enemy_id is String or enemy_id.is_empty() or seen_enemy_ids.has(enemy_id):
			return _failure()
		if not enemy_position is int or enemy_position != index + 1:
			return _failure()
		if not enemy_max_hp is int or enemy_max_hp <= 0:
			return _failure()
		if not enemy_hp is int or enemy_hp < 0 or enemy_hp > enemy_max_hp:
			return _failure()
		if not enemy_block is int or enemy_block < 0:
			return _failure()
		if enemy.has("thorns"):
			var thorns = enemy["thorns"]
			if not thorns is int or thorns < 0:
				return _failure()
		if enemy.has("enrage") and not enemy["enrage"] is bool:
			return _failure()
		if enemy.has("enrage_stacks"):
			var stacks = enemy["enrage_stacks"]
			if not stacks is int or stacks < 0 or stacks > CombatEnemyKeywordRules.ENRAGE_MAX_STACKS:
				return _failure()
		seen_enemy_ids.append(enemy_id)
	if not TO_POSITIONS.has(target_position) or target_position > enemy_records.size():
		return _failure()
	var target_enemy: Dictionary = enemy_records[target_position - 1]
	if target_enemy["hp"] == 0:
		return _failure()
	if not _keywords.quote_enrage_after_hit(target_enemy,
			{"ok": true, "damage": 0, "block_absorbed": 0, "hp_loss": 0}).get("ok", false):
		return _failure()

	# Validate both supplied snapshots here, before any mutation; the reused status bridge applies
	# the existing Weak/Exposed math and its floor-once rounding to the Block-based base damage.
	if not _valid_statuses(attacker_statuses) or not _valid_statuses(defender_statuses):
		return _failure()

	if needle_bonus not in [0, 1]:
		return _failure()
	var owner_block: int = heroes[owner_position - 1]["block"]
	var bonus_damage: int = card["bonus_damage"]
	if owner_block > CombatParty.MAX_INT - bonus_damage - needle_bonus:
		return _failure()
	return {
		"ok": true,
		"cost": cost_value,
		"owner_position": owner_position,
		"owner_block": owner_block,
		"bonus_damage": bonus_damage,
		"base_damage": owner_block + bonus_damage + needle_bonus,
		"target_position": target_position,
		"attacker_statuses": attacker_statuses.duplicate(true),
		"defender_statuses": defender_statuses.duplicate(true),
	}


## Reads the exact authored record from the catalog that owns this ID (never the other hero
## catalogs) and returns a detached copy, or {} when the ID is not in that catalog.
func _catalog_definition(card_id: String) -> Dictionary:
	var card: Dictionary = CARDS.get(card_id, {})
	var source: Variant = card.get("catalog", "")
	if source == "starter":
		return V3WardenStarterCards.new().get_definition(card_id)
	if source == "pool":
		return V3WardenPoolCards.new().get_definition(card_id)
	return {}


## The record must still carry exactly the authored base line, so a rewritten catalog (extra
## damage, a Block cost or a different target) can never be paid for as this effect.
func _authentic(definition: Dictionary, card_id: String, card: Dictionary) -> bool:
	if definition.get("id") != card_id or definition.get("owner") != OWNER:
		return false
	if definition.get("cost") != card["cost"]:
		return false
	if definition.get("target_kind") != TARGET_KIND:
		return false
	if definition.get("from_positions") != FROM_POSITIONS:
		return false
	if definition.get("to_positions") != TO_POSITIONS:
		return false
	return definition.get("effects") == card["effects"]


func _valid_statuses(statuses: Dictionary) -> bool:
	# Same accepted names as CombatStatusAttacks: anything else is malformed for this resolution.
	for name in statuses:
		if not name is String or name not in ["bleed", "weak", "exposed", "tangled"]:
			return false
		var count = statuses[name]
		if not count is int or count < 0:
			return false
	return true


func _failure() -> Dictionary:
	return {"ok": false, "damage": 0, "block_absorbed": 0, "hp_loss": 0}
