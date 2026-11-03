class_name CombatTinkerV3StarterAttackCards
extends RefCounted
## Scene-free paid starter attacks; shared-hand dispatch reuses this preflight.
## enemy_all uses target 0; original enemy slots are never compacted.

const CATALOG := preload("res://data/cards/v3_tinker_starter_cards.gd")
const CARDS := {
	"tinker_v3_cog_shot": {"name": "Cog Shot", "cost": 1, "from": [2, 3], "damage": 5},
	"tinker_v3_cog_shot_plus": {"name": "Cog Shot+", "cost": 1, "from": [2, 3], "damage": 7},
	"tinker_v3_scrap_bomb": {"name": "Scrap Bomb", "cost": 2, "from": [3], "damage": 4},
	"tinker_v3_scrap_bomb_plus": {"name": "Scrap Bomb+", "cost": 2, "from": [3], "damage": 6},
}
var _catalog := CATALOG.new()


static func is_authentic_definition(definition: Variant, card_id: Variant) -> bool:
	if not card_id is String or not CARDS.has(card_id):
		return false
	var spec: Dictionary = CARDS[card_id]
	var base: String = card_id.trim_suffix("_plus")
	var plus: bool = card_id.ends_with("_plus")
	var area: bool = spec["cost"] == 2
	var effects := {"damage": spec["damage"], "combat_scrap_gain": 1}
	if area:
		effects["living_targets_only"] = true
	var expected := {
		"id": card_id, "display_name": spec["name"], "owner": "tinker",
		"cost": spec["cost"], "from_positions": spec["from"],
		"target_kind": "enemy_all" if area else "enemy_single", "to_positions": [1, 2, 3],
		"effects": effects, "starting_copies": 0 if plus else 1, "reward_eligible": false,
		"illustration_path": "res://assets/paper/cards/" + base + ".png",
	}
	expected["upgrade_of" if plus else "upgrade_id"] = base if plus else base + "_plus"
	return _typed_equal(definition, expected)


static func _typed_equal(actual: Variant, expected: Variant) -> bool:
	if typeof(actual) != typeof(expected):
		return false
	if expected is Dictionary:
		if actual.size() != expected.size():
			return false
		for key in expected:
			if not actual.has(key) or not _typed_equal(actual[key], expected[key]):
				return false
	elif expected is Array:
		if actual.size() != expected.size():
			return false
		for i in range(expected.size()):
			if not _typed_equal(actual[i], expected[i]):
				return false
	else:
		return actual == expected
	return true


func is_supported_card(card_id: Variant) -> bool:
	return is_authentic_definition(_catalog.get_definition(card_id), card_id)


func preflight(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: Variant, target_position: int = 0, cost_discount: int = 0) -> Dictionary:
	if deck == null or party == null or enemies == null:
		return _refusal("invalid_request")
	if deck.combat_state == null or deck._rng == null or not deck.turn_active:
		return _refusal("inactive_turn")
	if not is_supported_card(card_id):
		return _refusal("unsupported_card")
	var spec: Dictionary = CARDS[card_id]
	if cost_discount < 0 or cost_discount > 1 or (cost_discount > 0 and spec.cost < 2):
		return _refusal("invalid_discount")
	if not _valid_roster(party._heroes, 3, 3, true):
		return _refusal("invalid_party")
	# Do not call enemy readers here: they settle revivals, even on refused requests.
	if not _valid_roster(enemies._enemies, 1, 3, false):
		return _refusal("invalid_enemies")
	var owner := 0
	for hero in party._heroes:
		if hero["id"] == "tinker":
			owner = hero["position"]
	if owner == 0:
		return _refusal("owner_missing")
	if not spec["from"].has(owner):
		return _refusal("owner_illegal_position")
	var hero: Dictionary = party._heroes[owner - 1]
	if hero["hp"] == 0:
		return _refusal("owner_downed")
	var scrap: int = hero.get("combat_scrap", 0)
	if scrap == CombatParty.MAX_INT:
		return _refusal("combat_scrap_overflow")
	var area: bool = spec["cost"] == 2
	if (area and target_position != 0) or (not area and target_position not in [1, 2, 3]):
		return _refusal("invalid_target")
	var targets: Array[Dictionary] = []
	for enemy in enemies._enemies:
		if enemy["hp"] > 0 and (area or enemy["position"] == target_position):
			targets.append(enemy.duplicate(true))
	if targets.is_empty():
		return _refusal("no_living_target")
	if not deck.hand.has(card_id):
		return _refusal("card_not_held")
	if deck.energy < spec["cost"] - cost_discount:
		return _refusal("insufficient_energy")
	return {"ok": true, "card_id": card_id, "owner_position": owner,
		"target_kind": "enemy_all" if area else "enemy_single", "targets": targets,
		"cost": spec["cost"] - cost_discount, "raw_damage": spec["damage"],
		"combat_scrap_before": scrap, "energy_before": deck.energy}


func play_card(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: Variant, target_position: int = 0) -> Dictionary:
	var plan := preflight(deck, party, enemies, card_id, target_position)
	if not plan["ok"]:
		return plan
	# All operations are synchronous and guaranteed by preflight before any payment.
	deck.try_spend_energy(plan["cost"])
	deck.discard_played(card_id)
	party._heroes[plan["owner_position"] - 1]["combat_scrap"] = plan["combat_scrap_before"] + 1
	var hits: Array[Dictionary] = []
	for before in plan["targets"]:
		var position: int = before["position"]
		enemies.apply_damage(position, plan["raw_damage"])
		var after: Dictionary = enemies._enemies[position - 1]
		hits.append({"position": position, "raw_damage": plan["raw_damage"],
			"block_before": before["block"], "block_after": after["block"],
			"block_absorbed": before["block"] - after["block"],
			"hp_before": before["hp"], "hp_after": after["hp"],
			"hp_loss": before["hp"] - after["hp"]})
	return {"ok": true, "reason": "applied", "card_id": card_id,
		"owner_position": plan["owner_position"], "target_position": target_position,
		"target_kind": plan["target_kind"], "hits": hits, "cost": plan["cost"],
		"raw_damage": plan["raw_damage"], "energy_before": plan["energy_before"],
		"energy_after": deck.energy, "combat_scrap_before": plan["combat_scrap_before"],
		"combat_scrap_gain": 1, "combat_scrap_after": plan["combat_scrap_before"] + 1}


static func _valid_roster(records: Array[Dictionary], minimum: int, maximum: int,
		heroes: bool) -> bool:
	if records.size() < minimum or records.size() > maximum:
		return false
	var ids: Array[String] = []
	for i in range(records.size()):
		var actor: Dictionary = records[i]
		if not actor.get("id") is String or actor["id"].is_empty() or actor["id"] in ids:
			return false
		ids.append(actor["id"])
		for key in ["position", "max_hp", "hp", "block"]:
			if not actor.get(key) is int:
				return false
		if actor["position"] != i + 1 or actor["max_hp"] <= 0 or actor["hp"] < 0 \
				or actor["hp"] > actor["max_hp"] or actor["block"] < 0:
			return false
		if heroes:
			var scrap: Variant = actor.get("combat_scrap", 0)
			if not scrap is int or scrap < 0:
				return false
		elif not CombatEnemies.valid_revive_flags(actor) or not CombatEnemies.valid_split_flags(actor):
			return false
		# Damage's target validation settles the whole roster. Refuse an unsettled
		# revival rather than changing an unrelated slain actor during this cast.
		elif actor["hp"] == 0 and CombatEnemies.revive_pending(actor):
			return false
	return true


static func _refusal(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
