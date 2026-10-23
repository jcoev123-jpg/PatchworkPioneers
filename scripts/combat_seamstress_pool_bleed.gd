class_name CombatSeamstressPoolBleed
extends RefCounted
## D2-1 scene-free resolution for the eight authored Seamstress Bleed pool cards.
## The real held-hand/stitched-half dispatch is deliberately a later integration.

const SUPPORTED_IDS := [
	"seamstress_running_stitch", "seamstress_running_stitch_plus",
	"seamstress_hemorrhage_hem", "seamstress_hemorrhage_hem_plus",
	"seamstress_blanket_stitch", "seamstress_blanket_stitch_plus",
	"seamstress_red_thread", "seamstress_red_thread_plus"
]

const BLOODLINE_PATH := "bloodline"
const UNPICKER_PATH := "unpicker"
const OWNER_ID := "seamstress"

var _attacks := CombatStatusAttacks.new()
var _patches: CombatPatchAttackRules = null
var _receipt: Dictionary = {}
var _selected_path: String = ""
var _path_selection_attempted: bool = false
var _path_selection_valid: bool = false
var _unravel: CombatUnravel = null


func _init(choice_or_receipt: Variant = null, unravel: CombatUnravel = null) -> void:
	if choice_or_receipt != null:
		bind_choice(choice_or_receipt)
	if unravel != null:
		bind_unravel(unravel)


## A failed explicit binding fails closed; an untouched service stays unbound.
func bind_patch_wardrobe(wardrobe: RunPatchWardrobe, torn: RunTornMending) -> bool:
	_patches = CombatPatchAttackRules.new()
	return _patches.bind_wardrobe(wardrobe, torn)


func bind_choice(choice_or_receipt: Variant) -> bool:
	return bind_path_choice(choice_or_receipt)


func bind_path_choice(choice_or_receipt: Variant) -> bool:
	_path_selection_attempted = true
	var validated: Dictionary = _validate_choice_or_receipt(choice_or_receipt)
	if not validated.get("ok", false):
		_path_selection_valid = false
		_selected_path = ""
		_receipt = {}
		return false
	_path_selection_valid = true
	_selected_path = validated["path_id"]
	_receipt = validated["receipt"]
	return true


func bind_unravel(unravel: CombatUnravel) -> void:
	_unravel = unravel


func set_unravel(unravel: CombatUnravel) -> void:
	bind_unravel(unravel)


func get_receipt() -> Dictionary:
	return _receipt.duplicate(true)


func get_path_id() -> String:
	return _selected_path


func is_valid_choice() -> bool:
	return _path_selection_valid


func get_unravel() -> CombatUnravel:
	return _unravel


## Side-effect-free projection of a legal, genuinely held enemy-single card.
## Applied Bleed is FUTURE owner-turn-end HP loss; no status ages here.
func forecast_single(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: String, target_position: int) -> Dictionary:
	if card_id not in SUPPORTED_IDS or card_id.begins_with("seamstress_blanket_stitch"):
		return {"ok": false}
	var plan: Dictionary = _prepare(deck, party, enemies, card_id, target_position)
	if not plan.get("ok", false) or plan.positions.size() != 1:
		return {"ok": false}
	var enemy: Dictionary = enemies.get_enemy(target_position)
	var current: Dictionary = enemy.get("statuses", {})
	var additions: Dictionary = plan.applications[target_position]
	var damage := 0
	if plan.is_running:
		damage = CombatStatuses.new().adjusted_attack_damage(
			plan.damage_value, plan.owner.get("statuses", {}), current)
	var blocked: int = mini(damage, enemy["block"])
	var hp_loss: int = mini(enemy["hp"], damage - blocked)
	return {"ok": true, "position": target_position, "cost": plan.cost,
		"damage": damage, "block_absorbed": blocked, "hp_loss": hp_loss,
		"bleed_before": current.get("bleed", 0),
		"bleed_after": current.get("bleed", 0) + additions.get("bleed", 0),
		"exposed_before": current.get("exposed", 0),
		"exposed_after": current.get("exposed", 0) + additions.get("exposed", 0)}


func play_card(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: String, target_position: int = 0) -> Dictionary:
	var plan: Dictionary = _prepare(deck, party, enemies, card_id, target_position)
	if not plan.get("ok", false):
		return _failure()
	# From here the authoritative models are guaranteed to accept operations.
	if not deck.try_spend_energy(plan.cost):
		return _failure()
	deck.discard_played(card_id)
	var hits: Array[Dictionary] = []
	for position in plan.positions:
		var event := {"damage": 0, "block_absorbed": 0, "hp_loss": 0}
		if plan.is_running:
			event = _attacks.resolve_vs_enemy(enemies, position, plan.damage_value,
				plan.owner.get("statuses", {}), plan.targets[position])
		hits.append({"position": position, "damage": event["damage"],
			"block_absorbed": event["block_absorbed"], "hp_loss": event["hp_loss"],
			"statuses": plan.applications[position].duplicate(true)})
	# A lethal Running Stitch still applies to its original slain slot.
	enemies.apply_statuses(plan.applications)
	if _selected_path == UNPICKER_PATH and _unravel != null:
		for position in plan.positions:
			if not enemies.is_slain(position) and plan.applications[position].get("bleed", 0) > 0:
				_unravel.apply_unravel(enemies, position, 2)
	if plan.is_running and _patches != null:
		_patches.record_successful_attack("seamstress")
	return {"ok": true, "hits": hits}


func _prepare(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: String, target_position: int = 0) -> Dictionary:
	# No mutation until the entire party, enemy roster, target set and status
	# batch have been validated. Do not substitute caller-supplied status maps.
	if deck == null or party == null or enemies == null or not SUPPORTED_IDS.has(card_id):
		return _failure()
	if _path_selection_attempted and not _path_selection_valid:
		return _failure()
	if _patches != null and not _patches.is_valid():
		return _failure()
	if not deck.turn_active or not deck.hand.has(card_id) or not party.is_valid():
		return _failure()
	if not enemies.can_apply_statuses({}) or enemies.is_victorious():
		return _failure()

	if _selected_path == UNPICKER_PATH:
		if _unravel == null or not (_unravel is CombatUnravel):
			return _failure()
		if _unravel._bound_enemies != enemies or not enemies.is_valid():
			return _failure()

	var definition: Dictionary = SeamstressPoolCards.new().get_definition(card_id)
	if definition.get("id") != card_id or definition.get("owner") != "seamstress":
		return _failure()
	var cost_value: Variant = definition.get("cost")
	var from_positions: Variant = definition.get("from_positions")
	var to_positions: Variant = definition.get("to_positions")
	var target_kind: Variant = definition.get("target_kind")
	var effects: Variant = definition.get("effects")
	if not cost_value is int or cost_value < 0 or deck.energy < cost_value:
		return _failure()
	if not from_positions is Array or not to_positions is Array or not effects is Dictionary:
		return _failure()
	if target_kind != "enemy_single" and target_kind != "enemy_all":
		return _failure()
	var heroes: Array[Dictionary] = party.get_heroes()
	if not CombatStatusTurnBatch.new().tick_side("heroes", heroes)["ok"]:
		return _failure()
	var owner_count := 0
	var owner: Dictionary = {}
	for hero in heroes:
		if hero["id"] == "seamstress":
			owner_count += 1
			owner = hero
	if owner_count != 1 or owner["hp"] <= 0 or not from_positions.has(owner["position"]):
		return _failure()

	# A target-free card selects every living original roster slot, never a
	# compacted index after a death. A single must name exactly one live slot.
	var positions: Array[int] = []
	if target_kind == "enemy_single":
		if not to_positions.has(target_position):
			return _failure()
		var selected: Dictionary = enemies.get_enemy(target_position)
		if selected.is_empty() or enemies.is_slain(target_position):
			return _failure()
		positions.append(target_position)
	else:
		if target_position != 0:
			return _failure()
		for enemy in enemies.get_enemies():
			if enemy["hp"] > 0 and to_positions.has(enemy["position"]):
				positions.append(enemy["position"])
	if positions.is_empty():
		return _failure()

	if _selected_path == UNPICKER_PATH:
		for position in positions:
			if _unravel.get_snapshot(position).is_empty():
				return _failure()

	var is_running := card_id.begins_with("seamstress_running_stitch")
	var is_hem := card_id.begins_with("seamstress_hemorrhage_hem")
	var is_blanket := card_id.begins_with("seamstress_blanket_stitch")
	var damage_value := 0
	var patch_exposed := 0
	if is_running:
		if target_kind != "enemy_single" or not _valid_effect(effects, ["damage", "bleed"]):
			return _failure()
		damage_value = effects["damage"]
		var patch_damage: int = 0 if _patches == null else _patches.damage_bonus("seamstress")
		if damage_value > CombatStatuses.MAX_INT - patch_damage:
			return _failure()
		damage_value += patch_damage
		var patch_statuses: Dictionary = {} if _patches == null else _patches.exposed_for_first_hit("seamstress")
		patch_exposed = patch_statuses.get("exposed", 0)
	elif is_hem:
		if target_kind != "enemy_single" or not _valid_effect(effects, ["bleed_multiplier"]) \
				or effects["bleed_multiplier"] != 2:
			return _failure()
	elif is_blanket:
		if target_kind != "enemy_all" or not _valid_effect(effects, ["bleed"]):
			return _failure()
	elif target_kind != "enemy_single" or not _valid_effect(effects, ["bleed", "exposed"]):
		return _failure()

	var applications: Dictionary = {}
	var targets: Dictionary = {}
	for position in positions:
		var enemy: Dictionary = enemies.get_enemy(position)
		if enemy.is_empty() or enemy["hp"] <= 0 or enemy["position"] != position:
			return _failure()
		var statuses: Dictionary = enemy.get("statuses", {})
		targets[position] = statuses
		var additions: Dictionary = {}
		if is_hem:
			# The delta is the current stack, not a fresh application: N + N.
			var current: int = statuses.get("bleed", 0)
			if current > CombatEnemies.MAX_INT - current:
				return _failure()
			additions["bleed"] = current
		else:
			var bleed_amount: int = effects["bleed"]
			var passive_bonus: int = 0 if _selected_path == UNPICKER_PATH else 1
			var patch_bleed: int = 0 if _patches == null else _patches.card_bleed_bonus("seamstress", card_id)
			if bleed_amount > CombatEnemies.MAX_INT - (passive_bonus + patch_bleed):
				return _failure()
			additions["bleed"] = bleed_amount + passive_bonus + patch_bleed
			if effects.has("exposed"):
				additions["exposed"] = effects["exposed"]
			elif is_running and patch_exposed > 0:
				additions["exposed"] = patch_exposed
		applications[position] = additions
	# Checks every member together, including overflowing later area targets.
	if not enemies.can_apply_statuses(applications):
		return _failure()

	return {"ok": true, "cost": cost_value, "positions": positions,
		"owner": owner, "is_running": is_running, "damage_value": damage_value,
		"targets": targets, "applications": applications}


func _valid_effect(effects: Dictionary, required: Array[String]) -> bool:
	if effects.size() != required.size():
		return false
	for key in required:
		if not effects.has(key) or not effects[key] is int or effects[key] < 0:
			return false
	return true


func _failure() -> Dictionary:
	return {"ok": false, "hits": []}


func _validate_choice_or_receipt(candidate: Variant) -> Dictionary:
	var receipt: Dictionary = {}
	var choice_instance: RunSeamstressPathChoice = null
	if candidate is RunSeamstressPathChoice:
		if not candidate.is_claimed():
			return {"ok": false}
		choice_instance = candidate
		receipt = candidate.get_receipt()
	elif candidate is Dictionary:
		receipt = candidate
	else:
		return {"ok": false}

	if receipt.is_empty() or receipt.get("ok") != true:
		return {"ok": false}
	if receipt.get("owner") != OWNER_ID:
		return {"ok": false}
	var path_id = receipt.get("path_id")
	if not path_id is String:
		return {"ok": false}
	if path_id != BLOODLINE_PATH and path_id != UNPICKER_PATH:
		return {"ok": false}

	var choice := choice_instance if choice_instance != null else RunSeamstressPathChoice.new()
	if choice_instance == null and not choice.is_valid():
		return {"ok": false}
	var expected_path: Dictionary = choice.get_path(path_id)
	if expected_path.is_empty():
		return {"ok": false}

	if receipt.get("display_name") != expected_path.get("display_name"):
		return {"ok": false}
	if not _deep_equal(receipt.get("passive"), expected_path.get("passive")):
		return {"ok": false}
	if not _deep_equal(receipt.get("card"), expected_path.get("card")):
		return {"ok": false}

	var deck_val: Variant = receipt.get("deck")
	if not deck_val is Array:
		return {"ok": false}
	var candidate_deck: Array = deck_val
	var base_deck: Array[String] = choice.get_base_deck()
	if candidate_deck.size() != base_deck.size() + 1:
		return {"ok": false}

	var card_id: String = String(expected_path.get("card", {}).get("id", ""))
	var expected_counts: Dictionary = {}
	for base_id in base_deck:
		expected_counts[base_id] = int(expected_counts.get(base_id, 0)) + 1
	expected_counts[card_id] = int(expected_counts.get(card_id, 0)) + 1

	var candidate_counts: Dictionary = {}
	for item in candidate_deck:
		if not item is String:
			return {"ok": false}
		var item_id: String = item
		candidate_counts[item_id] = int(candidate_counts.get(item_id, 0)) + 1

	if candidate_counts != expected_counts:
		return {"ok": false}

	var other_path_card: String = "seamstress_fray" if path_id == BLOODLINE_PATH else "seamstress_leech_stitch"
	if candidate_counts.get(other_path_card, 0) > 0:
		return {"ok": false}

	return {"ok": true, "path_id": path_id, "receipt": receipt.duplicate(true)}


func _deep_equal(a: Variant, b: Variant) -> bool:
	var norm_a: Variant = _normalize(a)
	var norm_b: Variant = _normalize(b)
	if typeof(norm_a) != typeof(norm_b):
		return false
	if norm_a is Array:
		var arr_a: Array = norm_a
		var arr_b: Array = norm_b
		if arr_a.size() != arr_b.size():
			return false
		for i in range(arr_a.size()):
			if not _deep_equal(arr_a[i], arr_b[i]):
				return false
		return true
	if norm_a is Dictionary:
		var dict_a: Dictionary = norm_a
		var dict_b: Dictionary = norm_b
		if dict_a.size() != dict_b.size():
			return false
		for key in dict_a:
			if not dict_b.has(key):
				return false
			if not _deep_equal(dict_a[key], dict_b[key]):
				return false
		return true
	return norm_a == norm_b


func _normalize(value: Variant) -> Variant:
	if typeof(value) == TYPE_FLOAT:
		var f: float = value
		if is_finite(f) and floor(f) == f:
			return int(f)
		return f
	if value is Array:
		var res: Array = []
		for item in value:
			res.append(_normalize(item))
		return res
	if value is Dictionary:
		var res: Dictionary = {}
		for k in value:
			res[k] = _normalize(value[k])
		return res
	return value
