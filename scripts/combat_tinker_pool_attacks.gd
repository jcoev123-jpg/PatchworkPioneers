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
var _patches: CombatPatchAttackRules = null
var _head_patches: CombatM05HeadPatchRules = null


## Failed explicit binding stays unusable; never fall back to an unpatched cast.
func bind_patch_wardrobe(wardrobe: Variant, torn: Variant) -> bool:
	_patches = CombatPatchAttackRules.new()
	_head_patches = CombatM05HeadPatchRules.new()
	if not (wardrobe is RunPatchWardrobe) or not (torn is RunTornMending):
		return false
	var attack_ok := _patches.bind_wardrobe(wardrobe, torn)
	var head_ok := _head_patches.bind_wardrobe(wardrobe, torn)
	return attack_ok and head_ok


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


func get_head_patches() -> CombatM05HeadPatchRules:
	return _head_patches


## Bind the EXACT battle-authenticated M05 HEAD projection the live hand already
## uses for starter attacks, so one sewn projection prices every resolver. Null
## leaves this resolver honestly unpatched; a present but invalid or stale
## projection rejects every cast instead of silently reverting to vanilla.
func bind_head_patch_rules(rules: CombatM05HeadPatchRules) -> bool:
	_head_patches = rules
	return rules != null and rules.read_projection().get("ok", false)


func is_supported_card(card_id: String) -> bool:
	var base_id: String = card_id.trim_suffix("_plus")
	return BASE_IDS.has(base_id) and (card_id == base_id or card_id == base_id + "_plus")


func play_attack(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: String, target_position: int = 0, pinned: CombatPinned = null,
		cost_discount: int = 0) -> Dictionary:
	var active_pinned: CombatPinned = pinned if pinned != null else _pinned
	var plan: Dictionary = _prepare(deck, party, enemies, card_id, target_position,
		active_pinned, cost_discount)
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
			if living.is_empty():
				break
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
	# Button Eye is a once-per-combat rider on the first *confirmed* hit.
	# Apply only after the entire card: later Ricochet hits must not benefit
	# from the Exposed this card creates.
	if plan["patch_exposed"] > 0:
		var first_position: int = plan["first_hit_position"]
		enemies.apply_statuses({first_position: {"exposed": plan["patch_exposed"]}})
		var first_statuses: Dictionary = hits[0]["statuses"]
		first_statuses["exposed"] = first_statuses.get("exposed", 0) + plan["patch_exposed"]
	deck.discard_played(card_id)
	_first_attack.record_successful_attack(card_id)
	if _patches != null:
		_patches.record_successful_attack("tinker")
	return {"ok": true, "hits": hits}


func _prepare(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: String, target_position: int, active_pinned: CombatPinned,
		cost_discount: int = 0) -> Dictionary:
	if deck == null or party == null or enemies == null or deck._rng == null:
		return _failure()
	if _patches != null and not _patches.is_valid():
		return _failure()
	if _head_patches != null and not _head_patches.read_projection().get("ok", false):
		return _failure()
	if _head_patches != null:
		for hero in _head_patches._torn_snapshot.get("heroes", []):
			if hero.get("id") == "tinker" and hero.get("hp", 0) <= 0:
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
			or not cost_value is int or cost_value < 0 \
			or not from_value is Array or not to_value is Array \
			or not kind_value is String or not effects_value is Dictionary:
		return _failure()
	# The one authored Clockwork point only ever reduces a PRINTED cost of two or
	# more; anything else fails closed rather than under-charging the battle.
	if cost_discount < 0 or cost_discount > 1 \
			or (cost_discount > 0 and cost_value < 2):
		return _failure()
	var effective_cost: int = cost_value - cost_discount
	if effective_cost > deck.energy:
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
		var head_exposed: int = 0 if _head_patches == null else _head_patches.get_bonus("tinker", card_id, "exposed")
		if head_exposed < 0 or head_exposed > CombatEnemies.MAX_INT - effects["exposed"]:
			return _failure()
		exposed = effects["exposed"] + head_exposed

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

	var patch_damage: int = 0 if _patches == null else _patches.damage_bonus("tinker")
	var patch_first_status: Dictionary = {} if _patches == null else _patches.exposed_for_first_hit("tinker")
	var patch_exposed: int = patch_first_status.get("exposed", 0)
	var bonus: int = _first_attack.bonus_for_attack(card_id)
	# Reserve both Pinned's possible +5 and the bound wearer bonus.
	if damage_value > CombatStatuses.MAX_INT - bonus - 5 - patch_damage:
		return _failure()
	var base_damage: int = damage_value + bonus + patch_damage

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
		if expected_kind == "enemy_all":
			positions.assign(living)
		else:
			# Simulation plans up to hit_count random selections sequentially.
			# If early hits slay every enemy, stop remaining hits without rejection.
			var simulated: Array[Dictionary] = roster.duplicate(true)
			var rng_copy := RandomNumberGenerator.new()
			rng_copy.state = deck._rng.state
			# Ricochet simulation and the real sequential hits use this same raw base.
			var simulated_pins: Dictionary = {}
			if active_pinned != null:
				for pos in range(1, roster.size() + 1):
					var pinner: String = active_pinned.pinner_for_enemy(pos)
					if not pinner.is_empty():
						simulated_pins[pos] = pinner
			for hit in range(effects["hit_count"]):
				var candidates: Array[int] = _living_positions(simulated, to_value)
				if candidates.is_empty():
					break
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
			if positions.is_empty():
				return _failure()
	# Check the combined first-hit additions BEFORE energy, discards, pins or
	# run RNG move. Rivet must reserve both its authored +1 and Button Eye +1.
	var first_position: int = positions[0]
	if exposed + patch_exposed > 0 and not enemies.can_apply_statuses(
			{first_position: {"exposed": exposed + patch_exposed}}):
		return _failure()
	return {"ok": true, "base_id": base_id, "positions": positions, "to_positions": to_value,
		"target_kind": expected_kind, "base_damage": base_damage,
		"attack_damage": base_damage, "first_hit_position": first_position,
		"patch_exposed": patch_exposed,
		"owner_statuses": owner_statuses, "cost": effective_cost,
		"printed_cost": cost_value, "exposed": exposed}


func _living_positions(roster: Array[Dictionary], to_positions: Array) -> Array[int]:
	var positions: Array[int] = []
	for index in range(roster.size()):
		var slot := index + 1
		if to_positions.has(slot) and roster[index].get("hp", 0) > 0:
			positions.append(slot)
	return positions


func _failure() -> Dictionary:
	return {"ok": false, "hits": []}
