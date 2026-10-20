class_name CombatIncomingAttackPreview
extends RefCounted
## Pure End Turn attack forecast after hero owner ticks. HP loss excludes Bleed;
## remaining HP includes it. Block reset belongs to the NEXT player turn.

const MAX_INT := 9223372036854775807


func forecast(heroes: Array, enemies: Array, intents: Array) -> Dictionary:
	var invalid := {"ok": false, "heroes": []}
	if heroes.size() != CombatParty.PARTY_SIZE or enemies.is_empty() or enemies.size() > 3 or intents.size() != enemies.size():
		return invalid
	var batch := CombatStatusTurnBatch.new()
	var tick := batch.tick_side("heroes", heroes)
	if not tick["ok"] or not batch.tick_side("enemies", enemies)["ok"]:
		return invalid
	var next_heroes: Array = tick["actors"]
	var result: Array[Dictionary] = []
	for index in range(heroes.size()):
		var record = next_heroes[index]
		if not _valid_actor(record, index + 1):
			return invalid
		result.append({"position": index + 1, "downed": record["hp"] == 0,
			"incoming": 0, "block_absorbed": 0, "hp_lost": 0,
			"hp_remaining": record["hp"], "block_remaining": record["block"]})
	for index in range(enemies.size()):
		if not _valid_actor(enemies[index], index + 1):
			return invalid
	var seen: Array[int] = []
	var ordered: Array[Dictionary] = []
	for raw_intent in intents:
		if not raw_intent is Dictionary:
			return invalid
		for key in ["type", "enemy_position", "amount"]:
			if not raw_intent.has(key):
				return invalid
		var kind = raw_intent["type"]
		var source = raw_intent["enemy_position"]
		var amount = raw_intent["amount"]
		if not kind is String or (kind != "attack" and kind != "block") or not source is int or source < 1 or source > enemies.size() or source in seen or not amount is int or amount < 0:
			return invalid
		if kind == "attack":
			if raw_intent.size() != 4 or not raw_intent.has("target_position"):
				return invalid
			var target = raw_intent["target_position"]
			if not target is int or target < 1 or target > CombatParty.PARTY_SIZE:
				return invalid
		else:
			if raw_intent.size() != 3:
				return invalid
			var enemy: Dictionary = enemies[source - 1]
			if enemy["hp"] > 0 and amount > MAX_INT - enemy["block"]:
				return invalid
		seen.append(source)
		ordered.append(raw_intent)
	if seen.size() != enemies.size():
		return invalid
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["enemy_position"] < b["enemy_position"])

	for intent in ordered:
		var source: int = intent["enemy_position"]
		if enemies[source - 1]["hp"] == 0 or intent["type"] != "attack":
			continue
		var target: int = intent["target_position"]
		var hero: Dictionary = result[target - 1]
		# A downed slot remains empty, even if an earlier hit downed it.
		if hero["hp_remaining"] == 0:
			continue
		var amount := CombatStatuses.new().adjusted_attack_damage(intent["amount"],
			enemies[source - 1].get("statuses", {}), next_heroes[target - 1]["statuses"])
		if amount > MAX_INT - hero["incoming"]:
			return invalid
		hero["incoming"] += amount
		var absorbed: int = mini(hero["block_remaining"], amount)
		hero["block_remaining"] -= absorbed
		hero["block_absorbed"] += absorbed
		var loss: int = mini(hero["hp_remaining"], amount - absorbed)
		hero["hp_remaining"] -= loss
		hero["hp_lost"] += loss
	return {"ok": true, "heroes": result}


func _valid_actor(actor: Variant, expected_position: int) -> bool:
	if not actor is Dictionary:
		return false
	for field in ["position", "max_hp", "hp", "block"]:
		if not actor.has(field) or not actor[field] is int:
			return false
	return actor["position"] == expected_position and actor["max_hp"] > 0 and actor["hp"] >= 0 and actor["hp"] <= actor["max_hp"] and actor["block"] >= 0
