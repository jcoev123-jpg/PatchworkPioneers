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

var _attacks := CombatStatusAttacks.new()


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
	return {"ok": true, "hits": hits}


func _prepare(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: String, target_position: int = 0) -> Dictionary:
	# No mutation until the entire party, enemy roster, target set and status
	# batch have been validated. Do not substitute caller-supplied status maps.
	if deck == null or party == null or enemies == null or not SUPPORTED_IDS.has(card_id):
		return _failure()
	if not deck.turn_active or not deck.hand.has(card_id) or not party.is_valid():
		return _failure()
	if not enemies.can_apply_statuses({}) or enemies.is_victorious():
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

	var is_running := card_id.begins_with("seamstress_running_stitch")
	var is_hem := card_id.begins_with("seamstress_hemorrhage_hem")
	var is_blanket := card_id.begins_with("seamstress_blanket_stitch")
	var damage_value := 0
	if is_running:
		if target_kind != "enemy_single" or not _valid_effect(effects, ["damage", "bleed"]):
			return _failure()
		damage_value = effects["damage"]
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
			if effects["bleed"] == CombatEnemies.MAX_INT:
				return _failure()
			additions["bleed"] = effects["bleed"] + 1 # Seamstress passive.
			if effects.has("exposed"):
				additions["exposed"] = effects["exposed"]
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
