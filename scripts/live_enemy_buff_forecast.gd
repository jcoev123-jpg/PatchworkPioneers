class_name LiveEnemyBuffForecast
extends RefCounted
## Read-only projection of announced self-Block actions. Never receives an RNG.


func forecast(party: CombatParty, enemies: CombatEnemies, announcements: Array) -> Array[Dictionary]:
	if party == null or enemies == null or not party.is_valid() or not enemies.is_valid():
		return []
	var heroes := party.get_heroes()
	var roster := enemies.get_enemies()
	var validator := CombatStatusTurnBatch.new()
	if not validator.tick_side("heroes", heroes).ok or not validator.tick_side("enemies", roster).ok:
		return []
	var actions: Array = []
	var seen: Array[int] = []
	for raw in announcements:
		if not raw is Dictionary:
			return []
		var kind = raw.get("type")
		var source = raw.get("enemy_position")
		var amount = raw.get("amount")
		if not kind is String or kind not in ["attack", "block"] \
			or not source is int or source < 1 or source > roster.size() or source in seen \
			or not amount is int or amount < 0:
			return []
		seen.append(source)
		if kind == "attack":
			var target = raw.get("target_position")
			if raw.size() != 4 or not target is int or target < 1 or target > CombatParty.PARTY_SIZE:
				return []
		else:
			if raw.size() != 3:
				return []
			if amount > 0 and roster[source - 1].hp > 0:
				if not roster[source - 1].get("name") is String or roster[source - 1].name.is_empty():
					return []
				actions.append({"type": "buff", "enemy_position": source, "amount": amount})
	if actions.is_empty():
		return []
	# Constructors initialize fresh combatants; restore exact validated snapshots
	# afterwards so current HP, Block, positions and nested statuses are retained.
	var copied_party := CombatParty.new(heroes)
	var copied_enemies := CombatEnemies.new(roster)
	copied_party._heroes = heroes.duplicate(true)
	copied_enemies._enemies = roster.duplicate(true)
	if not CombatEnemySpecialActions.new().execute_actions(copied_party, copied_enemies, actions).ok:
		return []
	var result: Array[Dictionary] = []
	for action in actions:
		var source: int = action.enemy_position
		result.append({"enemy_position": source, "name": roster[source - 1].name,
			"before": roster[source - 1].block, "after": copied_enemies.get_enemy(source).block})
	return result
