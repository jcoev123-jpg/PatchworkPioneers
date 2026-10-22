class_name CombatWardenPoolHeavyAttacks
extends RefCounted
## Resolves Warden's two heavy-hit pool attack cards and upgrades (D2-1).
## Scene-free, atomic rule service for Heavy Thimble and Pin and Pound plays against
## authoritative CombatDeck, CombatParty, and CombatEnemies instances.

const WARDEN_ID: String = "warden"

const HEAVY_THIMBLE_ID: String = "warden_heavy_thimble"
const HEAVY_THIMBLE_PLUS_ID: String = "warden_heavy_thimble_plus"
const PIN_AND_POUND_ID: String = "warden_pin_and_pound"
const PIN_AND_POUND_PLUS_ID: String = "warden_pin_and_pound_plus"

const SUPPORTED_CARD_IDS: Array[String] = [
	"warden_heavy_thimble",
	"warden_heavy_thimble_plus",
	"warden_pin_and_pound",
	"warden_pin_and_pound_plus",
]


## Returns true if the card ID is one of the four heavy attack cards handled here.
func is_supported_card(card_id: String) -> bool:
	return SUPPORTED_CARD_IDS.has(card_id)


## Returns a duplicate of the supported card IDs list.
func get_supported_card_ids() -> Array[String]:
	return SUPPORTED_CARD_IDS.duplicate()


## Non-mutating preflight check for whether an attack can be legally played.
func can_play(
	deck: CombatDeck,
	party: CombatParty,
	enemies: CombatEnemies,
	card_id: String,
	target_position: int
) -> bool:
	if deck == null or party == null or enemies == null:
		return false
	if not deck.turn_active:
		return false
	if not party.is_valid() or not enemies.is_valid():
		return false
	if enemies.is_victorious() or party.is_defeated():
		return false
	if not SUPPORTED_CARD_IDS.has(card_id):
		return false

	var catalog: WardenPoolCards = WardenPoolCards.new()
	var definition: Dictionary = catalog.get_definition(card_id)
	if definition.is_empty():
		return false

	var owner_id: String = str(definition.get("owner", ""))
	if owner_id != WARDEN_ID:
		return false
	var cost: int = int(definition.get("cost", 2))
	if not deck.hand.has(card_id):
		return false
	if deck.energy < cost:
		return false

	var from_positions: Array = definition.get("from_positions", []) as Array
	var to_positions: Array = definition.get("to_positions", []) as Array

	var warden_hero: Dictionary = {}
	var warden_pos: int = 0
	var warden_count: int = 0
	var heroes: Array[Dictionary] = party.get_heroes()
	for hero: Dictionary in heroes:
		if hero.get("id") == WARDEN_ID:
			warden_count += 1
			warden_pos = int(hero.get("position", 0))
			warden_hero = hero

	if warden_count != 1 or warden_pos <= 0:
		return false
	if party.is_downed(warden_pos) or not from_positions.has(warden_pos):
		return false
	var hero_statuses: Variant = warden_hero.get("statuses", {})
	if hero_statuses is Dictionary and not _valid_statuses(hero_statuses as Dictionary):
		return false

	if not to_positions.has(target_position):
		return false
	var enemy_count: int = enemies.get_enemies().size()
	if target_position < 1 or target_position > enemy_count:
		return false
	if enemies.is_slain(target_position):
		return false
	var enemy_rec: Dictionary = enemies.get_enemy(target_position)
	if enemy_rec.is_empty() or int(enemy_rec.get("hp", 0)) <= 0:
		return false
	var enemy_statuses: Variant = enemy_rec.get("statuses", {})
	if enemy_statuses is Dictionary and not _valid_statuses(enemy_statuses as Dictionary):
		return false

	return true


## Returns legal living enemy positions for the given card.
func get_valid_targets(party: CombatParty, enemies: CombatEnemies, card_id: String) -> Array[int]:
	var targets: Array[int] = []
	if party == null or enemies == null or not party.is_valid() or not enemies.is_valid():
		return targets
	if not SUPPORTED_CARD_IDS.has(card_id):
		return targets

	var catalog: WardenPoolCards = WardenPoolCards.new()
	var definition: Dictionary = catalog.get_definition(card_id)
	if definition.is_empty():
		return targets

	var from_positions: Array = definition.get("from_positions", []) as Array
	var to_positions: Array = definition.get("to_positions", []) as Array

	var warden_pos: int = 0
	for hero: Dictionary in party.get_heroes():
		if hero.get("id") == WARDEN_ID:
			warden_pos = int(hero.get("position", 0))
			break

	if warden_pos <= 0 or party.is_downed(warden_pos) or not from_positions.has(warden_pos):
		return targets

	var enemy_count: int = enemies.get_enemies().size()
	for pos: Variant in to_positions:
		var p: int = int(pos)
		if p >= 1 and p <= enemy_count and not enemies.is_slain(p):
			var enemy_rec: Dictionary = enemies.get_enemy(p)
			if not enemy_rec.is_empty() and int(enemy_rec.get("hp", 0)) > 0:
				targets.append(p)

	return targets


## Authoritative execution of Heavy Thimble or Pin and Pound card play.
## Debits energy and discards precisely once, then applies one or two sequential hits.
## If hit 1 kills the enemy, hit 2 is skipped without roll back or retargeting.
func play_attack(
	deck: CombatDeck,
	party: CombatParty,
	enemies: CombatEnemies,
	card_id: String,
	target_position: int,
	attacker_statuses: Dictionary = {},
	enemy_statuses_by_position: Dictionary = {}
) -> Dictionary:
	if deck == null or party == null or enemies == null:
		return _failure(card_id, target_position)
	if not deck.turn_active:
		return _failure(card_id, target_position)
	if not party.is_valid() or not enemies.is_valid():
		return _failure(card_id, target_position)
	if enemies.is_victorious() or party.is_defeated():
		return _failure(card_id, target_position)
	if not SUPPORTED_CARD_IDS.has(card_id):
		return _failure(card_id, target_position)

	var catalog: WardenPoolCards = WardenPoolCards.new()
	var definition: Dictionary = catalog.get_definition(card_id)
	if definition.is_empty():
		return _failure(card_id, target_position)

	var owner_id: String = str(definition.get("owner", ""))
	if owner_id != WARDEN_ID:
		return _failure(card_id, target_position)
	var cost: int = int(definition.get("cost", 2))
	if cost < 0 or cost > CombatState.TURN_ENERGY:
		return _failure(card_id, target_position)

	var from_positions: Array = definition.get("from_positions", []) as Array
	var to_positions: Array = definition.get("to_positions", []) as Array
	var target_kind: String = str(definition.get("target_kind", ""))
	if target_kind != "enemy_single":
		return _failure(card_id, target_position)

	var effects: Dictionary = definition.get("effects", {}) as Dictionary
	if not effects.has("damage"):
		return _failure(card_id, target_position)
	var base_damage: int = int(effects.get("damage", 0))
	if base_damage <= 0:
		return _failure(card_id, target_position)
	var hits_count: int = int(effects.get("hits", 1))
	if hits_count < 1:
		return _failure(card_id, target_position)

	# Precondition: held copy in hand and sufficient energy
	if not deck.hand.has(card_id):
		return _failure(card_id, target_position)
	if deck.energy < cost:
		return _failure(card_id, target_position)

	# Precondition: living Warden in legal FROM position
	var warden_hero: Dictionary = {}
	var warden_pos: int = 0
	var warden_count: int = 0
	var heroes: Array[Dictionary] = party.get_heroes()
	for hero: Dictionary in heroes:
		if hero.get("id") == WARDEN_ID:
			warden_count += 1
			warden_pos = int(hero.get("position", 0))
			warden_hero = hero

	if warden_count != 1 or warden_pos <= 0:
		return _failure(card_id, target_position)
	if party.is_downed(warden_pos):
		return _failure(card_id, target_position)
	if not from_positions.has(warden_pos):
		return _failure(card_id, target_position)

	# Precondition: legal living enemy in allowed TO position
	if not to_positions.has(target_position):
		return _failure(card_id, target_position)
	var enemy_count: int = enemies.get_enemies().size()
	if target_position < 1 or target_position > enemy_count:
		return _failure(card_id, target_position)
	if enemies.is_slain(target_position):
		return _failure(card_id, target_position)
	var target_enemy: Dictionary = enemies.get_enemy(target_position)
	if target_enemy.is_empty() or int(target_enemy.get("hp", 0)) <= 0:
		return _failure(card_id, target_position)

	# Validate any caller-supplied statuses without letting them determine damage
	if not _valid_statuses(attacker_statuses):
		return _failure(card_id, target_position)
	if not _validate_enemy_statuses(enemy_statuses_by_position, enemies):
		return _failure(card_id, target_position)

	# Authoritative owner statuses from the unique Warden hero record
	var owner_statuses: Dictionary = {}
	var hero_statuses: Variant = warden_hero.get("statuses", {})
	if hero_statuses is Dictionary:
		for k: Variant in (hero_statuses as Dictionary):
			owner_statuses[str(k)] = int(hero_statuses[k])
	if not _valid_statuses(owner_statuses):
		return _failure(card_id, target_position)

	# Validate authoritative target enemy statuses before debiting
	var initial_target_statuses: Dictionary = {}
	var initial_foe_statuses: Variant = target_enemy.get("statuses", {})
	if initial_foe_statuses is Dictionary:
		for k: Variant in (initial_foe_statuses as Dictionary):
			initial_target_statuses[str(k)] = int(initial_foe_statuses[k])
	if not _valid_statuses(initial_target_statuses):
		return _failure(card_id, target_position)

	# Commit transaction: debit energy and discard card once
	if not deck.try_spend_energy(cost):
		return _failure(card_id, target_position)
	if not deck.discard_played(card_id):
		return _failure(card_id, target_position)

	# Execute sequential hits using CombatStatusAttacks
	var hits: Array[Dictionary] = []
	var damage_resolver: CombatStatusAttacks = CombatStatusAttacks.new()
	for i: int in range(hits_count):
		# If the target was slain by hit 1, skip hit 2 without error or redirect
		if enemies.is_slain(target_position):
			break
		var current_enemy: Dictionary = enemies.get_enemy(target_position)
		if current_enemy.is_empty() or int(current_enemy.get("hp", 0)) <= 0:
			break

		# Authoritative defender statuses from the current targeted enemy record
		var target_statuses: Dictionary = {}
		var foe_statuses: Variant = current_enemy.get("statuses", {})
		if foe_statuses is Dictionary:
			for k: Variant in (foe_statuses as Dictionary):
				target_statuses[str(k)] = int(foe_statuses[k])
		if not _valid_statuses(target_statuses):
			break

		var hit_result: Dictionary = damage_resolver.resolve_vs_enemy(
			enemies, target_position, base_damage, owner_statuses, target_statuses
		)
		if not hit_result.get("ok", false):
			break

		hits.append({
			"position": target_position,
			"damage": int(hit_result.get("damage", 0)),
			"block_absorbed": int(hit_result.get("block_absorbed", 0)),
			"hp_loss": int(hit_result.get("hp_loss", 0)),
			"statuses": {},
		})

	return {
		"ok": true,
		"card_id": card_id,
		"target_position": target_position,
		"hits": hits,
	}


## Alias for play_attack.
func play(
	deck: CombatDeck,
	party: CombatParty,
	enemies: CombatEnemies,
	card_id: String,
	target_position: int,
	attacker_statuses: Dictionary = {},
	enemy_statuses_by_position: Dictionary = {}
) -> Dictionary:
	return play_attack(deck, party, enemies, card_id, target_position, attacker_statuses, enemy_statuses_by_position)


## Alias for play_attack.
func play_card(
	deck: CombatDeck,
	party: CombatParty,
	enemies: CombatEnemies,
	card_id: String,
	target_position: int,
	attacker_statuses: Dictionary = {},
	enemy_statuses_by_position: Dictionary = {}
) -> Dictionary:
	return play_attack(deck, party, enemies, card_id, target_position, attacker_statuses, enemy_statuses_by_position)


func _valid_statuses(statuses: Dictionary) -> bool:
	for name: Variant in statuses:
		if not name is String or name not in ["bleed", "weak", "exposed"]:
			return false
		var count: Variant = statuses[name]
		if not count is int or int(count) < 0:
			return false
	return true


func _validate_enemy_statuses(statuses_data: Dictionary, enemies: CombatEnemies = null) -> bool:
	for key: Variant in statuses_data:
		if key is int:
			var pos: int = int(key)
			if pos < 1 or pos > CombatEnemies.MAX_ENEMIES:
				return false
			if enemies != null and enemies.get_enemy(pos).is_empty():
				return false
			var pos_statuses: Variant = statuses_data[key]
			if not pos_statuses is Dictionary or not _valid_statuses(pos_statuses as Dictionary):
				return false
		elif key is String:
			if not _valid_statuses(statuses_data):
				return false
			break
		else:
			return false
	return true


func _failure(card_id: String = "", target_position: int = 0) -> Dictionary:
	return {
		"ok": false,
		"card_id": card_id,
		"target_position": target_position,
		"hits": [],
	}
