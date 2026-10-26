class_name CombatYarnRangerUnspoolCards
extends RefCounted
## Scene-free paid resolver for Yarn Ranger's Unspool (damage 7) and Unspool+
## (damage 10). Only hits living enemies with an authoritative Tangled counter.
## No status mutation, no RNG use, no scene dependency.

const CARD_IDS := [
	"yarn_ranger_unspool",
	"yarn_ranger_unspool_plus"
]

var _catalog := preload("res://data/cards/yarn_ranger_pool_cards.gd").new()
var _attacks := CombatStatusAttacks.new()


func play_card(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: String) -> Dictionary:
	# Fail-closed: every preflight must pass before any mutation.
	if deck == null or party == null or enemies == null:
		return {"ok": false}
	if not CARD_IDS.has(card_id):
		return {"ok": false}

	# Catalog authentication (immutable descriptors only).
	var definition: Dictionary = _catalog.get_definition(card_id)
	if definition.is_empty() or definition.get("id") != card_id:
		return {"ok": false}
	if definition.get("owner") != "yarn_ranger":
		return {"ok": false}
	if definition.get("cost") != 2:
		return {"ok": false}
	if definition.get("from_positions") != [2, 3]:
		return {"ok": false}
	if definition.get("to_positions") != [1, 2, 3]:
		return {"ok": false}
	if definition.get("target_kind") != "enemy_all":
		return {"ok": false}
	var effects: Dictionary = definition.get("effects", {})
	if effects.get("requires_target_status") != "tangled" \
			or effects.get("living_targets_only") != true:
		return {"ok": false}

	# Active turn and genuine hand copy.
	if deck == null or not deck.turn_active:
		return {"ok": false}
	if not deck.hand.has(card_id):
		return {"ok": false}

	# Energy budget.
	if deck.energy < 2:
		return {"ok": false}

	# Party: exactly one living Yarn Ranger at position 2 or 3.
	if not party.is_valid():
		return {"ok": false}
	var heroes: Array[Dictionary] = party.get_heroes()
	var yr_positions: Array[int] = []
	var yr_statuses: Dictionary = {}
	for hero in heroes:
		if hero.get("id") == "yarn_ranger" and not hero.get("id").is_empty():
			var pos := int(hero.get("position", 0))
			if pos == 2 or pos == 3:
				if not party.is_downed(pos):
					yr_positions.append(pos)
				# Read real status snapshot from the hero record.
				yr_statuses = hero.get("statuses", {})
	if yr_positions.size() != 1:
		return {"ok": false}
	var owner_position: int = yr_positions[0]

	# Enemy roster must be valid.
	if enemies == null or not enemies.is_valid():
		return {"ok": false}

	# Identify eligible targets: living slots 1-3 with authoritative tangled > 0.
	var eligible: Array[int] = []
	for pos in [1, 2, 3]:
		if not enemies.is_slain(pos):
			var enemy_dict: Dictionary = enemies.get_enemy(pos)
			if not enemy_dict.is_empty():
				var statuses: Dictionary = enemy_dict.get("statuses", {})
				var tangled_val: Variant = statuses.get("tangled", 0)
				if tangled_val is int and tangled_val > 0:
					eligible.append(pos)

	# No eligible target -> reject before any spend or change.
	if eligible.is_empty():
		return {"ok": false}

	# Preflight status validation (same rules as CombatStatusAttacks).
	if not _valid_statuses(yr_statuses):
		return {"ok": false}
	for pos in eligible:
		var enemy_pre: Dictionary = enemies.get_enemy(pos)
		var defender_statuses: Dictionary = enemy_pre.get("statuses", {})
		if not _valid_statuses(defender_statuses):
			return {"ok": false}

	# Determine base damage from the printed descriptor.
	var base_damage: int = int(effects.get("damage", 0))

	# Charge and discard: exactly once after preflight succeeds.
	if not deck.try_spend_energy(2):
		return {"ok": false}
	if not deck.discard_played(card_id):
		# Should not fail after preflight; fail closed regardless.
		return {"ok": false}

	# Resolve each eligible target independently in original slot order.
	# Read real defender statuses directly from the authoritative roster.
	var hits: Array[Dictionary] = []
	for pos in eligible:
		var defender_dict: Dictionary = enemies.get_enemy(pos)
		var defender_statuses: Dictionary = defender_dict.get("statuses", {})
		# Re-read attacker statuses from the real party hero.
		var hero_dict: Dictionary = party.get_hero(owner_position)
		var attacker_statuses: Dictionary = hero_dict.get("statuses", {})

		var event: Dictionary = _attacks.resolve_vs_enemy(
			enemies, pos, base_damage,
			attacker_statuses, defender_statuses)
		if not event.get("ok", false):
			# A validated target should never fail here, but fail closed.
			return {"ok": false, "hits": []}
		hits.append({
			"position": pos,
			"damage": event.get("damage", 0),
			"block_absorbed": event.get("block_absorbed", 0),
			"hp_loss": event.get("hp_loss", 0)
		})

	return {"ok": true, "hits": hits}


## Replicates CombatStatusAttacks' private validation exactly, without
## mutating any input dictionary.
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
