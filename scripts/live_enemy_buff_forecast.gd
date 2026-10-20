class_name LiveEnemyBuffForecast
extends RefCounted
## Read-only projection of announced self-Block actions. Never receives an RNG.


func forecast(party: CombatParty, enemies: CombatEnemies, announcements: Array) -> Array[Dictionary]:
	if party == null or enemies == null or not party.is_valid() or not enemies.is_valid():
		return []
	var heroes := party.get_heroes()
	var roster := enemies.get_enemies()
	var validator := CombatStatusTurnBatch.new()
	var hero_tick := validator.tick_side("heroes", heroes)
	if not hero_tick.ok or not validator.tick_side("enemies", roster).ok:
		return []
	var actions: Array = []
	var seen: Array[int] = []
	for raw in announcements:
		if not raw is Dictionary:
			return []
		var kind = raw.get("type")
		var source = raw.get("enemy_position")
		var amount = raw.get("amount")
		if not kind is String or kind not in ["attack", "block", "buff", "shove", "debuff"] \
			or not source is int or source < 1 or source > roster.size() or source in seen \
			or not amount is int or amount < 0:
			return []
		seen.append(source)
		var definition: Dictionary = raw.duplicate(true)
		definition.erase("enemy_position")
		if not CombatEnemyIntents.valid_action(definition):
			return []
		if kind in ["block", "buff"] and amount > 0 and roster[source - 1].hp > 0:
			if not roster[source - 1].get("name") is String or roster[source - 1].name.is_empty():
				return []
			actions.append(raw.duplicate(true))
	if actions.is_empty():
		return []
	# Constructors initialize fresh combatants; restore exact validated snapshots
	# afterwards so current HP, Block, positions and nested statuses are retained.
	var copied_party := CombatParty.new(heroes)
	var copied_enemies := CombatEnemies.new(roster)
	copied_party._heroes = hero_tick.actors.duplicate(true)
	copied_enemies._enemies = roster.duplicate(true)
	if copied_party.is_defeated() or copied_enemies.is_defeated():
		return []
	if not CombatEnemyPhase.new().execute_phase(copied_party, copied_enemies, announcements).ok:
		return []
	var result: Array[Dictionary] = []
	for action in actions:
		var source: int = action.enemy_position
		result.append({"enemy_position": source, "name": roster[source - 1].name,
			"before": roster[source - 1].block, "after": copied_enemies.get_enemy(source).block})
	return result
