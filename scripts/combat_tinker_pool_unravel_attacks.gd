class_name CombatTinkerPoolUnravelAttacks
extends RefCounted
## Scene-free resolution for Tinker's three D2-1 Unravel pool attacks (Spool Launcher,
## Shrapnel Seam, Snip the Seam) and their upgrades.
##
## Spends 1 or 2 energy, discards once, and resolves hits via CombatStatusAttacks.
## Spool Launcher and Shrapnel Seam apply Unravel only to surviving hit enemies.
## Snip the Seam deals empowered conditional damage if the target is Unravelled
## or its gauge is at least half its current threshold; it never applies Unravel.
## Shares a CombatTinkerFirstAttack instance with other Tinker attack resolvers.

const BASE_IDS: Array[String] = [
	"tinker_spool_launcher",
	"tinker_shrapnel_seam",
	"tinker_snip_the_seam",
]

const SUPPORTED_CARD_IDS: Array[String] = [
	"tinker_spool_launcher",
	"tinker_spool_launcher_plus",
	"tinker_shrapnel_seam",
	"tinker_shrapnel_seam_plus",
	"tinker_snip_the_seam",
	"tinker_snip_the_seam_plus",
]

var _first_attack: CombatTinkerFirstAttack
var _unravel: CombatUnravel = null
var _damage := CombatStatusAttacks.new()
var _statuses := CombatStatuses.new()


func _init(arg1: Variant = null, arg2: Variant = null) -> void:
	if arg1 is CombatTinkerFirstAttack:
		_first_attack = arg1
	elif arg1 is CombatUnravel:
		_unravel = arg1
	if arg2 is CombatTinkerFirstAttack:
		_first_attack = arg2
	elif arg2 is CombatUnravel:
		_unravel = arg2
	if _first_attack == null:
		_first_attack = CombatTinkerFirstAttack.new()


func is_supported_card(card_id: String) -> bool:
	return SUPPORTED_CARD_IDS.has(card_id)


func get_supported_card_ids() -> Array[String]:
	return SUPPORTED_CARD_IDS.duplicate()


func set_unravel(unravel: CombatUnravel) -> void:
	_unravel = unravel


func get_unravel() -> CombatUnravel:
	return _unravel


func get_first_attack() -> CombatTinkerFirstAttack:
	return _first_attack


func can_play(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: String, target_position: int = 0, unravel: CombatUnravel = null) -> bool:
	var unravel_service: CombatUnravel = unravel if unravel != null else _unravel
	var plan: Dictionary = _prepare(deck, party, enemies, unravel_service, card_id, target_position)
	return plan.get("ok", false)


func play_attack(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		arg4: Variant = "", arg5: Variant = 0, arg6: Variant = null) -> Dictionary:
	var unravel_service: CombatUnravel = _unravel
	var card_id: String = ""
	var target_position: int = 0

	if arg4 is CombatUnravel:
		unravel_service = arg4
		if arg5 is String:
			card_id = arg5
		if arg6 is int:
			target_position = arg6
	elif arg4 is String:
		card_id = arg4
		if arg5 is int:
			target_position = arg5
			if arg6 is CombatUnravel:
				unravel_service = arg6
		elif arg5 is CombatUnravel:
			unravel_service = arg5
			if arg6 is int:
				target_position = arg6

	var plan: Dictionary = _prepare(deck, party, enemies, unravel_service, card_id, target_position)
	if not plan.get("ok", false):
		return _failure()

	deck.try_spend_energy(plan["cost"])
	var hits: Array[Dictionary] = []
	var positions: Array[int] = plan["positions"]
	var attack_damage: int = plan["attack_damage"]
	var owner_statuses: Dictionary = plan["owner_statuses"]
	var unravel_amount: int = plan["unravel_amount"]

	for position in positions:
		var defender: Dictionary = enemies.get_enemy(position)
		var event: Dictionary = _damage.resolve_vs_enemy(enemies, position,
			attack_damage, owner_statuses, defender.get("statuses", {}))
		var applied_unravel: int = 0
		if not enemies.is_slain(position) and unravel_amount > 0:
			if unravel_service.apply_unravel(enemies, position, unravel_amount):
				applied_unravel = unravel_amount
		hits.append({
			"position": position,
			"damage": event["damage"],
			"block_absorbed": event["block_absorbed"],
			"hp_loss": event["hp_loss"],
			"statuses": {},
			"unravel": applied_unravel,
		})

	deck.discard_played(card_id)
	_first_attack.record_successful_attack(card_id)
	return {"ok": true, "hits": hits}


func _prepare(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		unravel: CombatUnravel, card_id: String, target_position: int) -> Dictionary:
	if deck == null or party == null or enemies == null or unravel == null or deck._rng == null:
		return _failure()
	if unravel._bound_enemies != enemies or not enemies.is_valid():
		return _failure()
	if not SUPPORTED_CARD_IDS.has(card_id):
		return _failure()
	var base_id: String = card_id.trim_suffix("_plus")
	if not BASE_IDS.has(base_id) or (card_id != base_id and card_id != base_id + "_plus"):
		return _failure()
	if not deck.turn_active or not deck.hand.has(card_id):
		return _failure()
	if not party.is_valid():
		return _failure()
	var heroes: Array[Dictionary] = party.get_heroes()
	if not CombatStatusTurnBatch.new().tick_side("heroes", heroes)["ok"]:
		return _failure()
	if not enemies.can_apply_statuses({}) or enemies.is_victorious():
		return _failure()

	var definition: Dictionary = TinkerPoolCards.new().get_definition(card_id)
	if definition.is_empty() or definition.get("id") != card_id or definition.get("owner") != "tinker":
		return _failure()
	var cost_value: Variant = definition.get("cost")
	var from_value: Variant = definition.get("from_positions")
	var to_value: Variant = definition.get("to_positions")
	var kind_value: Variant = definition.get("target_kind")
	var effects_value: Variant = definition.get("effects")
	if not cost_value is int or cost_value < 0 or cost_value > deck.energy \
			or not from_value is Array or not to_value is Array \
			or not kind_value is String or not effects_value is Dictionary:
		return _failure()
	var effects: Dictionary = effects_value

	var expected_kind: String = "enemy_single"
	if base_id == "tinker_shrapnel_seam":
		expected_kind = "enemy_all"
	if kind_value != expected_kind:
		return _failure()

	if to_value.is_empty() or from_value.is_empty():
		return _failure()
	for val in from_value:
		if not val is int or val < 1 or val > CombatParty.PARTY_SIZE:
			return _failure()
	for val in to_value:
		if not val is int or val < 1 or val > CombatEnemies.MAX_ENEMIES:
			return _failure()

	if base_id == "tinker_spool_launcher":
		if not effects.get("damage") is int or effects["damage"] <= 0:
			return _failure()
		if not effects.get("unravel") is int or effects["unravel"] <= 0:
			return _failure()
	elif base_id == "tinker_shrapnel_seam":
		if not effects.get("damage") is int or effects["damage"] <= 0:
			return _failure()
		if not effects.get("unravel") is int or effects["unravel"] <= 0:
			return _failure()
		if effects.get("living_targets_only") != true:
			return _failure()
	elif base_id == "tinker_snip_the_seam":
		if not effects.get("damage") is int or effects["damage"] <= 0:
			return _failure()
		var cond: Variant = effects.get("conditional_damage")
		if not cond is Dictionary or not cond.get("damage") is int or cond["damage"] <= 0:
			return _failure()
		if cond.get("operator") != "or" or not cond.get("conditions") is Array:
			return _failure()

	var owner_count: int = 0
	var owner_statuses: Dictionary = {}
	for hero in heroes:
		if hero.get("id") != "tinker":
			continue
		owner_count += 1
		var hero_position: Variant = hero.get("position")
		if not hero_position is int or not from_value.has(hero_position) \
				or party.is_downed(hero_position) or hero.get("hp", 0) <= 0:
			return _failure()
		owner_statuses = hero.get("statuses", {})
	if owner_count != 1:
		return _failure()

	var roster: Array[Dictionary] = enemies.get_enemies()
	for index in range(roster.size()):
		if roster[index].get("position") != index + 1:
			return _failure()

	var living: Array[int] = _living_positions(roster, to_value)
	if living.is_empty():
		return _failure()

	var positions: Array[int] = []
	if expected_kind == "enemy_single":
		if not living.has(target_position):
			return _failure()
		positions.append(target_position)
	else:
		if target_position != 0:
			return _failure()
		positions.assign(living)

	for pos in positions:
		if unravel.get_snapshot(pos).is_empty():
			return _failure()

	var raw_damage: int = effects["damage"]
	var unravel_amount: int = 0

	if base_id == "tinker_snip_the_seam":
		var snap: Dictionary = unravel.get_snapshot(target_position)
		var is_unravelled: bool = bool(snap.get("unravelled", false)) or bool(snap.get("skip_pending", false))
		var threshold: int = int(snap.get("threshold", 0))
		var gauge: int = int(snap.get("gauge", 0))
		var at_least_half: bool = (threshold > 0 and gauge * 2 >= threshold)
		if is_unravelled or at_least_half:
			raw_damage = effects["conditional_damage"]["damage"]
		unravel_amount = 0
	else:
		unravel_amount = int(effects.get("unravel", 0))

	var bonus: int = _first_attack.bonus_for_attack(card_id)
	if raw_damage > CombatStatuses.MAX_INT - bonus:
		return _failure()

	return {
		"ok": true,
		"positions": positions,
		"to_positions": to_value,
		"target_kind": expected_kind,
		"attack_damage": raw_damage + bonus,
		"owner_statuses": owner_statuses,
		"cost": cost_value,
		"unravel_amount": unravel_amount,
	}


func _living_positions(roster: Array[Dictionary], to_positions: Array) -> Array[int]:
	var positions: Array[int] = []
	for index in range(roster.size()):
		var slot: int = index + 1
		if to_positions.has(slot) and roster[index].get("hp", 0) > 0:
			positions.append(slot)
	return positions


func _failure() -> Dictionary:
	return {"ok": false, "hits": []}
