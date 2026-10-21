class_name CombatEnemyPhase
extends RefCounted
## Stage every source in order, then publish once. No turn or RNG ownership.

func execute_phase(party: CombatParty, enemies: CombatEnemies, intents: Array) -> Dictionary:
	var failure := {"ok": false, "events": []}
	if party == null or enemies == null or not party.is_valid() or not enemies.is_valid():
		return failure
	var heroes := party.get_heroes()
	var roster := enemies.get_enemies()
	var validator := CombatStatusTurnBatch.new()
	if not validator.tick_side("heroes", heroes).ok or not validator.tick_side("enemies", roster).ok:
		return failure
	var ordered: Array[Dictionary] = []
	var seen: Array[int] = []
	for raw in intents:
		if not raw is Dictionary:
			return failure
		var source = raw.get("enemy_position")
		if not source is int or source < 1 or source > roster.size() or source in seen:
			return failure
		var action: Dictionary = raw.duplicate(true)
		action.erase("enemy_position")
		if not CombatEnemyIntents.valid_action(action):
			return failure
		seen.append(source)
		ordered.append(raw.duplicate(true))
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.enemy_position < b.enemy_position)
	var staged_party := CombatParty.new(heroes)
	staged_party._heroes = heroes
	var staged_enemies := CombatEnemies.new(roster)
	staged_enemies._enemies = roster
	var events: Array[Dictionary] = []
	for action in ordered:
		var source: int = action.enemy_position
		var event := {"type": action.type, "enemy_position": source, "applied": false}
		for field in ["target_position", "status", "direction"]:
			if action.has(field):
				event[field] = action[field]
		if not staged_enemies.is_slain(source):
			if action.type == "attack":
				var damage := CombatStatuses.new().adjusted_attack_damage(action.amount,
					staged_enemies.get_enemy(source).get("statuses", {}),
					staged_party.get_hero(action.target_position).get("statuses", {}))
				var attack: Dictionary = action.duplicate(true)
				attack.erase("type")
				attack.amount = damage
				var result := CombatEnemyAttacks.new().execute_attacks(staged_party, [attack])
				if not result.ok:
					return failure
				event.applied = result.events[0].applied
			elif action.type == "block":
				var result := CombatEnemyBlocks.execute_blocks(staged_enemies, [action])
				if not result.ok:
					return failure
				event.applied = result.events[0].applied
			else:
				var result := CombatEnemySpecialActions.new().execute_actions(staged_party, staged_enemies, [action])
				if not result.ok:
					return failure
				event.applied = result.events[0].applied
		events.append(event)
	# Preserve dictionaries and unrelated metadata; actor identity follows swaps.
	var originals: Dictionary = {}
	for hero in party._heroes:
		originals[hero.id] = hero
	for index in range(heroes.size()):
		var next: Dictionary = staged_party._heroes[index]
		var original: Dictionary = originals[next.id]
		for field in ["position", "hp", "block", "statuses"]:
			if next.has(field):
				original[field] = next[field]
		party._heroes[index] = original
	for index in range(roster.size()):
		enemies._enemies[index].block = staged_enemies._enemies[index].block
	return {"ok": true, "events": events}
