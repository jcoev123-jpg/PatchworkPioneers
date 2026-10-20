class_name CombatIntentCues
extends RefCounted
## Scene-free helper that exposes per-enemy attack/Block intent cues as stable typed dictionaries.
## Observes CombatEnemyIntents and CombatEnemies; never mutates either.

func get_cues(selector: CombatEnemyIntents, roster: CombatEnemies) -> Array[Dictionary]:
	## Returns a fresh array of copied cue dictionaries in ascending enemy position.
	## Each cue contains: enemy_position (int), enemy_id (String), icon_key ("attack" or "block"), amount (int).
	## Attack cues also include target_position (int). Dead/slain enemies are omitted.
	## Returns [] for invalid selector, invalid roster, or inconsistent source/roster correspondence.
	var cues: Array[Dictionary] = []

	# Validate selector and roster
	if not selector or not selector.is_valid():
		return cues
	if not roster or not roster.is_valid():
		return cues

	var intents: Array[Dictionary] = selector.get_intents()
	var enemies: Array[Dictionary] = roster.get_enemies()

	# Build a lookup of ALL enemies by position (not just living)
	var enemies_by_position: Dictionary = {}
	for enemy in enemies:
		var pos: int = enemy["position"]
		enemies_by_position[pos] = enemy

	# Build a lookup of living enemies by position
	var living_by_position: Dictionary = {}
	for enemy in enemies:
		var pos: int = enemy["position"]
		if not roster.is_slain(pos):
			living_by_position[pos] = enemy

	# Validate that every intent maps to an enemy at the same position in roster
	# (dead or alive - dead ones will just be omitted from cues)
	# and that each action has the expected fields
	for intent in intents:
		var enemy_pos: int = intent["enemy_position"]
		var action_type: String = intent["type"]
		var amount_raw = intent["amount"]

		# Check that the enemy exists in roster at this position
		if not enemies_by_position.has(enemy_pos):
			return []  # Inconsistent: intent for position not in roster

		var enemy: Dictionary = enemies_by_position[enemy_pos]

		# Validate and convert amount (JSON may parse as float)
		var amount: int = _to_int(amount_raw)
		if amount < 0:
			return []

		# Validate action structure matches expectations
		if action_type == "attack":
			if not intent.has("target_position"):
				return []
			var target_pos_raw = intent["target_position"]
			var target_pos: int = _to_int(target_pos_raw)
			if target_pos < 1 or target_pos > 3:
				return []
		elif action_type == "block":
			# Block must not have target_position; enemy_position is added by selector
			if intent.has("target_position"):
				return []
			# Expect exactly 3 keys: type, amount, enemy_position
			if intent.size() != 3:
				return []
		else:
			return []  # Unknown action type

	# All validations passed - build cues for LIVING enemies only
	for intent in intents:
		var enemy_pos: int = intent["enemy_position"]
		var action_type: String = intent["type"]

		# Only include cues for living enemies
		if not living_by_position.has(enemy_pos):
			continue  # Dead/slain enemy - omit cue

		var enemy: Dictionary = living_by_position[enemy_pos]
		var amount: int = _to_int(intent["amount"])

		var cue: Dictionary = {
			"enemy_position": enemy_pos,
			"enemy_id": enemy["id"],
			"icon_key": action_type,  # "attack" or "block"
			"amount": amount
		}

		if action_type == "attack":
			cue["target_position"] = _to_int(intent["target_position"])

		cues.append(cue)

	# Sort by enemy_position ascending (intents already sorted, but ensure)
	cues.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["enemy_position"] < b["enemy_position"])

	# Return a deep copy to ensure caller cannot mutate internal state
	return cues.duplicate(true)

func _to_int(value) -> int:
	if value is int:
		return value
	if value is float:
		return int(value)
	return -1  # Invalid, will cause validation to fail