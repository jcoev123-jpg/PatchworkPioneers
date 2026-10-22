class_name CombatTinkerPoolAttacks
extends RefCounted
## Six catalog-authored Tinker direct-fire attacks, including upgrades and Spring Trap.
## The caller must reuse the same first-attack latch as starter attack play.

const BASE_IDS := [
	"tinker_rivet_shot", "tinker_spring_trap", "tinker_scatter_bolts",
	"tinker_long_barrel", "tinker_ricochet", "tinker_bobbin_cannon"
]

var _first_attack: CombatTinkerFirstAttack
var _pinned: CombatPinned
var _damage := CombatStatusAttacks.new()
var _statuses := CombatStatuses.new()


func _init(first_attack: Variant = null, pinned: Variant = null) -> void:
	if first_attack is CombatTinkerFirstAttack:
		_first_attack = first_attack
	elif first_attack is CombatPinned:
		_pinned = first_attack
	if pinned is CombatTinkerFirstAttack:
		_first_attack = pinned
	elif pinned is CombatPinned:
		_pinned = pinned
	if _first_attack == null:
		_first_attack = CombatTinkerFirstAttack.new()


func get_first_attack() -> CombatTinkerFirstAttack:
	return _first_attack


func set_pinned(pinned: CombatPinned) -> void:
	_pinned = pinned


func get_pinned() -> CombatPinned:
	return _pinned


func is_supported_card(card_id: String) -> bool:
	var base_id: String = card_id.trim_suffix("_plus")
	return BASE_IDS.has(base_id) and (card_id == base_id or card_id == base_id + "_plus")


func play_attack(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: String, target_position: int = 0, pinned: CombatPinned = null) -> Dictionary:
	var active_pinned: CombatPinned = pinned if pinned != null else _pinned
	var plan: Dictionary = _prepare(deck, party, enemies, card_id, target_position, active_pinned)
	if not plan.get("ok", false):
		return _failure()

	# Preflight has checked every downstream operation, including every future
	# Ricochet recipient against a detached roster and cloned run RNG.
	deck.try_spend_energy(plan["cost"])
	var hits: Array[Dictionary] = []
	var positions: Array[int] = plan["positions"]
	var to_positions: Array = plan["to_positions"]
	var base_id: String = plan["base_id"]
	for planned_position in positions:
		var position: int = planned_position
		if plan["target_kind"] == "enemy_random":
			var living: Array[int] = _living_positions(enemies.get_enemies(), to_positions)
			position = living[deck._rng.randi_range(0, living.size() - 1)]
		var defender: Dictionary = enemies.get_enemy(position)
		var pin_bonus: int = 0
		if active_pinned != null:
			pin_bonus = active_pinned.bonus_for_attack(enemies, position, "tinker")
		var hit_damage_before_status: int = plan["base_damage"] + pin_bonus
		var event: Dictionary = _damage.resolve_vs_enemy(enemies, position,
			hit_damage_before_status, plan["owner_statuses"], defender.get("statuses", {}))
		if active_pinned != null:
			active_pinned.consume_after_attack(position, "tinker", true)
		var applied: Dictionary = {}
		if plan["exposed"] > 0:
			applied = {"exposed": plan["exposed"]}
			# Rivet Shot applies Exposed *after* this hit's status math.
			enemies.apply_statuses({position: applied})
		var hit_record: Dictionary = {
			"position": position,
			"damage": event["damage"],
			"block_absorbed": event["block_absorbed"],
			"hp_loss": event["hp_loss"],
			"statuses": applied
		}
		if base_id == "tinker_spring_trap":
			var pin_applied: bool = false
			if not enemies.is_slain(position) and active_pinned != null:
				pin_applied = active_pinned.pin_enemy(enemies, position, "tinker")
			hit_record["pinned"] = pin_applied
		hits.append(hit_record)
	deck.discard_played(card_id)
	_first_attack.record_successful_attack(card_id)
	return {"ok": true, "hits": hits}


func _prepare(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: String, target_position: int, active_pinned: CombatPinned) -> Dictionary:
	if deck == null or party == null or enemies == null or deck._rng == null:
		return _failure()
	var base_id: String = card_id.trim_suffix("_plus")
	if not BASE_IDS.has(base_id) or (card_id != base_id and card_id != base_id + "_plus"):
		return _failure()
	if base_id == "tinker_spring_trap" and (active_pinned == null or not active_pinned is CombatPinned):
		return _failure()
	if active_pinned != null and not active_pinned is CombatPinned:
		return _failure()
	if not deck.turn_active or not deck.hand.has(card_id) or not party.is_valid():
		return _failure()
	if not enemies.is_valid() or not enemies.can_apply_statuses({}) or enemies.is_victorious():
		return _failure()
	var heroes: Array[Dictionary] = party.get_heroes()
	if not CombatStatusTurnBatch.new().tick_side("heroes", heroes)["ok"]:
		return _failure()

	var definition: Dictionary = TinkerPoolCards.new().get_definition(card_id)
	var cost_value: Variant = definition.get("cost")
	var from_value: Variant = definition.get("from_positions")
	var to_value: Variant = definition.get("to_positions")
	var kind_value: Variant = definition.get("target_kind")
	var effects_value: Variant = definition.get("effects")
	if definition.get("id") != card_id or definition.get("owner") != "tinker" \
			or not cost_value is int or cost_value < 0 or cost_value > deck.energy \
			or not from_value is Array or not to_value is Array \
			or not kind_value is String or not effects_value is Dictionary:
		return _failure()
	var effects: Dictionary = effects_value
	var damage_value: Variant = effects.get("damage")
	if not damage_value is int or damage_value <= 0:
		return _failure()
	var expected_kind := "enemy_single"
	if base_id == "tinker_scatter_bolts":
		expected_kind = "enemy_all"
	elif base_id == "tinker_ricochet":
		expected_kind = "enemy_random"
	if kind_value != expected_kind:
		return _failure()
	if to_value.is_empty():
		return _failure()
	for value in from_value:
		if not value is int or value < 1 or value > CombatParty.PARTY_SIZE:
			return _failure()
	for value in to_value:
		if not value is int or value < 1 or value > CombatEnemies.MAX_ENEMIES:
			return _failure()
	if base_id == "tinker_ricochet":
		if effects.get("hit_count") != 3 or effects.get("random_target_each_hit") != true \
				or effects.get("rng_source") != "run" or effects.get("living_targets_only") != true:
			return _failure()
	elif base_id == "tinker_scatter_bolts" and effects.get("living_targets_only") != true:
		return _failure()
	elif base_id == "tinker_spring_trap":
		var pin_rule: Variant = effects.get("pinned")
		if not pin_rule is Dictionary:
			return _failure()
		var pdict: Dictionary = pin_rule
		if pdict.get("pinner_identity") != "source_hero" \
				or pdict.get("bonus_damage") != 5 \
				or pdict.get("bonus_timing") != "before_weak_exposed" \
				or pdict.get("consume_once") != true \
				or pdict.get("same_hero_consumes") != false:
			return _failure()

	var exposed := 0
	if base_id == "tinker_rivet_shot":
		if not effects.get("exposed") is int or effects["exposed"] <= 0:
			return _failure()
		exposed = effects["exposed"]

	var owner_count := 0
	var owner_statuses: Dictionary = {}
	for hero in heroes:
		if hero.get("id") != "tinker":
			continue
		owner_count += 1
		var hero_position: Variant = hero.get("position")
		if not hero_position is int or not from_value.has(hero_position) \
				or party.is_downed(hero_position):
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
		if exposed > 0 and not enemies.can_apply_statuses(
				{target_position: {"exposed": exposed}}):
			return _failure()
	else:
		if target_position != 0:
			return _failure()
		if expected_kind == "enemy_all":
			positions.assign(living)
		else:
			# Simulation is deliberately detached: if early hits kill every
			# enemy, reject before charging or consuming the real RNG.
			var simulated: Array[Dictionary] = roster.duplicate(true)
			var rng_copy := RandomNumberGenerator.new()
			rng_copy.state = deck._rng.state
			var base_damage: int = damage_value + _first_attack.bonus_for_attack(card_id)
			var simulated_pins: Dictionary = {}
			if active_pinned != null:
				for pos in range(1, roster.size() + 1):
					var pinner: String = active_pinned.pinner_for_enemy(pos)
					if not pinner.is_empty():
						simulated_pins[pos] = pinner
			for hit in range(effects["hit_count"]):
				var candidates: Array[int] = _living_positions(simulated, to_value)
				if candidates.is_empty():
					return _failure()
				var picked: int = candidates[rng_copy.randi_range(0, candidates.size() - 1)]
				positions.append(picked)
				var actor: Dictionary = simulated[picked - 1]
				var pin_bonus := 0
				if simulated_pins.get(picked, "") != "" and simulated_pins[picked] != "tinker":
					pin_bonus = 5
					simulated_pins.erase(picked)
				var hit_damage: int = base_damage + pin_bonus
				var adjusted: int = _statuses.adjusted_attack_damage(hit_damage,
					owner_statuses, actor.get("statuses", {}))
				var absorbed: int = mini(actor["block"], adjusted)
				actor["block"] -= absorbed
				actor["hp"] = maxi(0, actor["hp"] - (adjusted - absorbed))
	var bonus: int = _first_attack.bonus_for_attack(card_id)
	if damage_value > CombatStatuses.MAX_INT - bonus - 5:
		return _failure()
	return {"ok": true, "base_id": base_id, "positions": positions, "to_positions": to_value,
		"target_kind": expected_kind, "base_damage": damage_value + bonus,
		"attack_damage": damage_value + bonus,
		"owner_statuses": owner_statuses, "cost": cost_value, "exposed": exposed}


func _living_positions(roster: Array[Dictionary], to_positions: Array) -> Array[int]:
	var positions: Array[int] = []
	for index in range(roster.size()):
		var slot := index + 1
		if to_positions.has(slot) and roster[index].get("hp", 0) > 0:
			positions.append(slot)
	return positions


func _failure() -> Dictionary:
	return {"ok": false, "hits": []}
