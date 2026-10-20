class_name CombatIntentCues
extends RefCounted
## Fresh typed cues from the authoritative schedule; no model mutation.

func get_cues(selector: CombatEnemyIntents, roster: CombatEnemies) -> Array[Dictionary]:
	var cues: Array[Dictionary] = []
	if selector == null or roster == null or not selector.is_valid() or not roster.is_valid():
		return cues
	var intents := selector.get_intents()
	var enemies := roster.get_enemies()
	if not CombatStatusTurnBatch.new().tick_side("enemies", enemies).ok:
		return []
	for index in range(intents.size()):
		var intent: Dictionary = intents[index].duplicate(true)
		var source = intent.get("enemy_position")
		intent.erase("enemy_position")
		if not source is int or source < 1 or source > enemies.size() or not CombatEnemyIntents.valid_action(intent):
			return []
		if roster.is_slain(source):
			continue
		intent["enemy_position"] = source
		intent["enemy_id"] = enemies[source - 1].id
		intent["icon_key"] = intent.type
		intent.erase("type")
		cues.append(intent)
	return cues.duplicate(true)
