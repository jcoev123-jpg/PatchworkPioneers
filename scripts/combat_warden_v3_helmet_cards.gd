class_name CombatWardenV3HelmetCards
extends RefCounted
## Scene-free paid resolver for the Warden's look-driven pot-helmet bonks (V3-1).
##
## Pot Helm Bonk is a v3 starter card and Helmet Rattle a v3 reward-pool card; both print a
## flat hit plus `weak: 1`, so one bonk off the dented pot helmet hurts the chosen foe and leaves
## it hitting 25% softer. The two catalogs stay authoritative: this service authenticates the
## exact held ID and its printed metadata, then resolves against the real deck, party and enemy
## models.
##
## Damage and Block/HP follow the shared CombatStatusAttacks bridge, so supplied Weak (-25%
## outgoing) / Exposed (+50% incoming) snapshots keep the existing floor-once rounding and enemy
## Block absorbs before HP. The Weak 1 is preflighted through CombatEnemies.can_apply_statuses and
## persisted through CombatEnemies.apply_statuses, so no new status system, lifecycle or time
## boundary is introduced here.
##
## The chosen foe's authentic Thorns and Enrage metadata is read from the same roster snapshot and
## validated before any paid change. One confirmed positive-damage hit then runs the shared
## CombatEnemyKeywordRules reactions exactly once each, against the genuine Warden slot: the Enrage
## commit must land before the Weak write (it compares the pre-hit and current enemy records), and
## Thorns retaliates through the Warden's own Block before HP. A plain foe, an enemy miss or a
## forged receipt never triggers either reaction.
##
## This scene-free service is the paid transaction behind the mounted hand's helmet cards (the live
## presenter calls it with the real deck, party and enemy roster). It never touches the run RNG:
## no draw, shuffle or target selection happens here.

const OWNER := "warden"
const TARGET_KIND := "enemy_single"
const FROM_POSITIONS := [1, 2]
const TO_POSITIONS := [1, 2]

## The four authentic IDs, the catalog that owns each one, and the exact effects line it must
## still print. The two starter printings and the two pool printings share the same look effect;
## a base card strikes for 4 and its "+" for 6, always with exactly Weak 1.
const CARDS := {
	"warden_v3_pot_helm_bonk": {
		"catalog": "starter",
		"cost": 1,
		"effects": {"damage": 4, "weak": 1},
	},
	"warden_v3_pot_helm_bonk_plus": {
		"catalog": "starter",
		"cost": 1,
		"effects": {"damage": 6, "weak": 1},
	},
	"warden_v3_helmet_rattle": {
		"catalog": "pool",
		"cost": 1,
		"effects": {"damage": 4, "weak": 1},
	},
	"warden_v3_helmet_rattle_plus": {
		"catalog": "pool",
		"cost": 1,
		"effects": {"damage": 6, "weak": 1},
	},
}

var _damage := CombatStatusAttacks.new()


## The single paid transaction: authenticate, preflight every input, then charge 1 energy, discard
## exactly the held copy, land one hit and add exactly Weak 1 to that same enemy. A rejection
## changes no deck, party, enemy or RNG state.
## `attacker_statuses` describes the Warden and `defender_statuses` the chosen enemy for this
## resolution; both default to no active statuses.
func play_card(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: String, target_position: int = 0, attacker_statuses: Dictionary = {},
		defender_statuses: Dictionary = {}) -> Dictionary:
	var plan: Dictionary = _prepare(deck, party, enemies, card_id, target_position,
		attacker_statuses, defender_statuses)
	if not plan.get("ok", false):
		return _failure()
	# Every operation below is guaranteed by the complete preflight above: the turn is active,
	# the held ID exists, the cost is affordable, the target is a living legal slot with valid
	# keyword metadata and the Weak addition is accepted by the enemy roster. Keep the defensive
	# returns so an unexpected model change still fails closed.
	if not deck.try_spend_energy(plan["cost"]):
		return _failure()
	if not deck.discard_played(card_id):
		return _failure()
	# The foe's authentic full pre-hit record was captured during preflight, BEFORE any damage.
	var pre_hit_enemy: Dictionary = plan["pre_hit_enemy"]
	var event: Dictionary = _damage.resolve_vs_enemy(enemies, plan["target_position"],
		plan["base_damage"], plan["attacker_statuses"], plan["defender_statuses"])
	if not event.get("ok", false):
		return _failure()
	var keywords := CombatEnemyKeywordRules.new()
	# Enrage compares the pre-hit and current enemy records, so it must be committed after the
	# confirmed hit and BEFORE the Weak status write changes the same slot. Thorns retaliates once
	# against the real Warden position through his own Block; both ignore plain, missed and
	# zero-damage hits inside the shared rules.
	var enrage: Dictionary = keywords.commit_enrage_after_hit(enemies,
		plan["target_position"], pre_hit_enemy, event)
	var thorns: Dictionary = keywords.resolve_thorns_retaliation(party,
		plan["owner_position"], pre_hit_enemy, event)
	# A confirmed hit Weakens the target even when its Block absorbed the whole strike, and even
	# when the strike was lethal: slain slots stay valid status recipients.
	if not enemies.apply_statuses({plan["target_position"]: {"weak": plan["weak"]}}):
		return _failure()
	var target: Dictionary = enemies.get_enemy(plan["target_position"])
	return {
		"ok": true,
		"card_id": card_id,
		"cost": plan["cost"],
		"owner_position": plan["owner_position"],
		"target_position": plan["target_position"],
		"base_damage": plan["base_damage"],
		"damage": event["damage"],
		"block_absorbed": event["block_absorbed"],
		"hp_loss": event["hp_loss"],
		"weak": plan["weak"],
		"thorns": thorns,
		"enrage": enrage,
		"target_statuses": target.get("statuses", {}).duplicate(true),
	}


## True only for the four authentic catalog IDs. Pure lookup; nothing is charged or mutated.
func is_supported_card(card_id: Variant) -> bool:
	return typeof(card_id) == TYPE_STRING and CARDS.has(card_id)


## Read-only preflight of the whole transaction. Returns a detached plan or a failure record.
func _prepare(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: String, target_position: int, attacker_statuses: Dictionary,
		defender_statuses: Dictionary) -> Dictionary:
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
	# The card must be genuinely held and affordable before any state changes.
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
	# A downed Warden is torn and cannot swing; the card prints FROM 1-2 only.
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
		seen_enemy_ids.append(enemy_id)
	# The printed TO line is 1-2 and never widens to a third slot, even when one exists.
	if not TO_POSITIONS.has(target_position) or target_position > enemy_records.size():
		return _failure()
	var pre_hit_enemy: Dictionary = enemy_records[target_position - 1]
	if pre_hit_enemy["hp"] == 0:
		return _failure()
	# Thorns N and Enrage (+n stacks, 0..3) are authoritative enemy metadata, not hero status
	# counters. Read and validate the chosen foe's fields here, before any spend, discard, damage,
	# status or keyword reaction; the captured record is the real pre-hit snapshot.
	if not _valid_keyword_metadata(pre_hit_enemy):
		return _failure()

	# Validate both supplied snapshots and preflight the Weak addition here, before any spend,
	# discard or damage. The reused status bridge applies the existing Weak/Exposed math and its
	# floor-once rounding to the printed base damage.
	if not _valid_statuses(attacker_statuses) or not _valid_statuses(defender_statuses):
		return _failure()
	var effects: Dictionary = card["effects"]
	var base_damage: int = effects["damage"]
	var weak: int = effects["weak"]
	if not enemies.can_apply_statuses({target_position: {"weak": weak}}):
		return _failure()
	return {
		"ok": true,
		"cost": cost_value,
		"owner_position": owner_position,
		"target_position": target_position,
		"base_damage": base_damage,
		"weak": weak,
		"attacker_statuses": attacker_statuses.duplicate(true),
		"defender_statuses": defender_statuses.duplicate(true),
		"pre_hit_enemy": pre_hit_enemy,
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


## The record must still carry exactly the authored line, so a rewritten catalog (extra damage,
## a different Weak count, another target line or a dropped print effect) can never be paid for as
## this effect.
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


## Thorns N is a nonnegative int and Enrage is a literal boolean with 0..3 integer stacks,
## exactly as CombatEnemyKeywordRules reads them. An absent key is a plain foe; any other shape
## is malformed metadata that must refuse the play before payment or faction damage.
func _valid_keyword_metadata(enemy: Dictionary) -> bool:
	if enemy.has("thorns"):
		var thorns = enemy["thorns"]
		if not thorns is int or thorns < 0:
			return false
	if enemy.has("enrage"):
		var enrage = enemy["enrage"]
		if not enrage is bool:
			return false
	if enemy.has("enrage_stacks"):
		var stacks = enemy["enrage_stacks"]
		if not stacks is int or stacks < 0 \
				or stacks > CombatEnemyKeywordRules.ENRAGE_MAX_STACKS:
			return false
	return true


func _failure() -> Dictionary:
	return {
		"ok": false,
		"damage": 0,
		"block_absorbed": 0,
		"hp_loss": 0,
		"weak": 0,
		"thorns": {"ok": false, "applied": false, "thorns": 0,
			"block_absorbed": 0, "hp_loss": 0},
		"enrage": {"ok": false, "applied": false, "enrage_stacks": 0, "attack_bonus": 0},
	}
