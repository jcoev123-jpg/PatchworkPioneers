class_name CombatEnemySpecialActions
extends RefCounted
## Scene-free transaction for announced shove, status debuff and self-Block buff.
## This service does not select intents, age statuses, spend cards or draw RNG.

const MAX_INT := 9223372036854775807


## Resolve at most one action per existing enemy source, in source-slot order.
## All validation and sequential effects occur on detached rosters first.
## There is no authoritative write at all if any action is malformed or illegal.
func execute_actions(party: CombatParty, enemies: CombatEnemies, actions: Array) -> Dictionary:
	var failure := {"ok": false, "events": []}
	if party == null or enemies == null or not party.is_valid() or not enemies.is_valid():
		return failure

	var staged_heroes: Array[Dictionary] = party.get_heroes()
	var staged_enemies: Array[Dictionary] = enemies.get_enemies()
	var turn_batch := CombatStatusTurnBatch.new()
	if not turn_batch.tick_side("heroes", staged_heroes)["ok"] \
			or not turn_batch.tick_side("enemies", staged_enemies)["ok"]:
		return failure

	var ordered: Array[Dictionary] = []
	var seen: Array[int] = []
	for raw_action in actions:
		if not raw_action is Dictionary:
			return failure
		var action: Dictionary = raw_action
		if not action.has("type") or not action.has("enemy_position") or not action.has("amount"):
			return failure
		var kind = action["type"]
		var source = action["enemy_position"]
		var amount = action["amount"]
		if not kind is String or kind not in ["shove", "debuff", "buff"]:
			return failure
		if not source is int or source < 1 or source > staged_enemies.size() or source in seen:
			return failure
		if not amount is int:
			return failure
		match kind:
			"shove":
				if action.size() != 5 or amount != 0 \
						or not action.has("target_position") or not action.has("direction"):
					return failure
				var target = action["target_position"]
				var direction = action["direction"]
				if not target is int or target < 1 or target > CombatParty.PARTY_SIZE \
						or not direction is int or (direction != -1 and direction != 1) \
						or target + direction < 1 or target + direction > CombatParty.PARTY_SIZE:
					return failure
			"debuff":
				if action.size() != 5 or amount <= 0 \
						or not action.has("target_position") or not action.has("status"):
					return failure
				var target = action["target_position"]
				var status = action["status"]
				if not target is int or target < 1 or target > CombatParty.PARTY_SIZE \
						or not status is String or status not in ["bleed", "weak", "exposed"]:
					return failure
			"buff":
				if action.size() != 3 or amount <= 0:
					return failure
		seen.append(source)
		ordered.append(action.duplicate(true))

	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["enemy_position"] < b["enemy_position"])

	# preview_adjacent_swap reads an actual CombatParty, but this is a detached
	# party carrying the exact current state (including earlier staged swaps).
	var staged_party := CombatParty.new(staged_heroes)
	staged_party._heroes = staged_heroes
	var events: Array[Dictionary] = []
	for action in ordered:
		var kind: String = action["type"]
		var source: int = action["enemy_position"]
		var applied: bool = staged_enemies[source - 1]["hp"] > 0
		var event: Dictionary = {"type": kind, "enemy_position": source, "applied": applied}
		if kind == "shove":
			event["target_position"] = action["target_position"]
			event["direction"] = action["direction"]
			if applied:
				var preview := CombatPositionSwaps.preview_adjacent_swap(
					staged_party, action["target_position"], action["direction"])
				if not preview["ok"]:
					return failure
				staged_party._heroes = preview["heroes"]
		elif kind == "debuff":
			event["target_position"] = action["target_position"]
			event["status"] = action["status"]
			if applied:
				var hero: Dictionary = staged_party._heroes[action["target_position"] - 1]
				if hero["hp"] == 0:
					return failure
				var statuses: Dictionary = hero.get("statuses", {})
				var previous: int = statuses.get(action["status"], 0)
				if action["amount"] > MAX_INT - previous:
					return failure
				if not hero.has("statuses"):
					hero["statuses"] = {}
				hero["statuses"][action["status"]] = previous + action["amount"]
		else:  # buff
			if applied:
				var enemy: Dictionary = staged_enemies[source - 1]
				if action["amount"] > MAX_INT - enemy["block"]:
					return failure
				enemy["block"] += action["amount"]
		events.append(event)

	# Publish only after the *last* action passed. Reuse original actor
	# dictionaries, so swaps preserve identity and all unrelated nested fields.
	var originals_by_id: Dictionary = {}
	for original in party._heroes:
		originals_by_id[original["id"]] = original
	for index in range(CombatParty.PARTY_SIZE):
		var staged: Dictionary = staged_party._heroes[index]
		var original: Dictionary = originals_by_id[staged["id"]]
		original["position"] = index + 1
		if staged.has("statuses") and staged["statuses"] != original.get("statuses", {}):
			original["statuses"] = staged["statuses"].duplicate(true)
		party._heroes[index] = original
	for index in range(staged_enemies.size()):
		if enemies._enemies[index]["block"] != staged_enemies[index]["block"]:
			enemies._enemies[index]["block"] = staged_enemies[index]["block"]
	return {"ok": true, "events": events}
