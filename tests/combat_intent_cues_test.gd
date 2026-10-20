extends SceneTree

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_test_happy_path_first_turn()
	_test_happy_path_after_advance()
	_test_copy_isolation_and_repeat_calls()
	_test_slain_enemy_omitted()
	_test_all_slain_returns_empty()
	_test_invalid_selector()
	_test_invalid_roster()
	_test_inconsistent_selector_roster()
	_test_partial_invalid_action_fields()
	if failures.is_empty():
		print("combat_intent_cues_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("combat_intent_cues_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _load_starter_enemies() -> Array:
	var file = FileAccess.open("res://data/enemies/starter_enemies.json", FileAccess.READ)
	var text = file.get_as_text()
	file.close()
	var result = JSON.parse_string(text)
	return _normalize_enemies(result)

func _load_starter_attacks() -> Array:
	var file = FileAccess.open("res://data/encounters/starter_attacks.json", FileAccess.READ)
	var text = file.get_as_text()
	file.close()
	var result = JSON.parse_string(text)
	return _normalize_attacks(result)

func _normalize_enemies(enemies: Array) -> Array:
	var normalized: Array = []
	for enemy in enemies:
		var norm: Dictionary = {}
		for key in enemy:
			var value = enemy[key]
			if value is float:
				norm[key] = int(value)
			else:
				norm[key] = value
		normalized.append(norm)
	return normalized

func _normalize_attacks(attacks: Array) -> Array:
	var normalized: Array = []
	for attack in attacks:
		var norm: Dictionary = {}
		for key in attack:
			var value = attack[key]
			if key == "pattern":
				norm[key] = _normalize_pattern(value)
			elif value is float:
				norm[key] = int(value)
			else:
				norm[key] = value
		normalized.append(norm)
	return normalized

func _normalize_pattern(pattern: Array) -> Array:
	var normalized: Array = []
	for action in pattern:
		var norm: Dictionary = {}
		for key in action:
			var value = action[key]
			if value is float:
				norm[key] = int(value)
			else:
				norm[key] = value
		normalized.append(norm)
	return normalized

func _make_selector(definitions: Array) -> CombatEnemyIntents:
	return CombatEnemyIntents.new(definitions)

func _make_roster(definitions: Array) -> CombatEnemies:
	return CombatEnemies.new(definitions)

func _snapshot_selector(selector: CombatEnemyIntents) -> Dictionary:
	return {
		"valid": selector.is_valid(),
		"intents": selector.get_intents().duplicate(true),
		"turn_index": _get_turn_index(selector)
	}

func _snapshot_roster(roster: CombatEnemies) -> Dictionary:
	return {
		"valid": roster.is_valid(),
		"enemies": roster.get_enemies().duplicate(true)
	}

func _get_turn_index(selector: CombatEnemyIntents) -> int:
	# Access private _turn_index via a workaround - call advance_turn and track
	# Actually, we can't access private. We'll just verify behavior.
	return -1

func _test_happy_path_first_turn() -> void:
	var enemy_defs = _load_starter_enemies()
	var attack_defs = _load_starter_attacks()

	var selector = _make_selector(attack_defs)
	var roster = _make_roster(enemy_defs)

	_check(selector.is_valid(), "selector is valid")
	_check(roster.is_valid(), "roster is valid")

	var cues = CombatIntentCues.new().get_cues(selector, roster)

	_check(cues.size() == 2, "first turn returns two cues (Ragling attack, Guard block)")

	# Find by position/ID, not by array index
	var ragling_cue = _find_cue(cues, 1, "ragling")
	var guard_cue = _find_cue(cues, 2, "ragling_guard")

	_check(ragling_cue != null, "Ragling cue exists at position 1")
	_check(guard_cue != null, "Guard Ragling cue exists at position 2")

	# Ragling: attack amount 1 targeting hero position 1
	_check(ragling_cue["icon_key"] == "attack", "Ragling icon_key is attack")
	_check(ragling_cue["amount"] == 1, "Ragling attack amount is 1")
	_check(ragling_cue.has("target_position"), "Ragling attack has target_position")
	_check(ragling_cue["target_position"] == 1, "Ragling targets hero position 1")
	_check(not ragling_cue.has("target_position") == false, "Ragling has target_position")

	# Guard: block amount 1, no target_position
	_check(guard_cue["icon_key"] == "block", "Guard icon_key is block")
	_check(guard_cue["amount"] == 1, "Guard block amount is 1")
	_check(not guard_cue.has("target_position"), "Guard block has no target_position")

	# Verify cues are sorted by position
	_check(cues[0]["enemy_position"] == 1 and cues[1]["enemy_position"] == 2, "cues sorted by enemy_position ascending")

func _test_happy_path_after_advance() -> void:
	var enemy_defs = _load_starter_enemies()
	var attack_defs = _load_starter_attacks()

	var selector = _make_selector(attack_defs)
	var roster = _make_roster(enemy_defs)

	_check(selector.advance_turn(), "advance_turn succeeds")

	var cues = CombatIntentCues.new().get_cues(selector, roster)

	_check(cues.size() == 2, "after advance, still two cues")

	var ragling_cue = _find_cue(cues, 1, "ragling")
	var guard_cue = _find_cue(cues, 2, "ragling_guard")

	_check(ragling_cue != null, "Ragling cue exists after advance")
	_check(guard_cue != null, "Guard cue exists after advance")

	# Ragling now targets hero position 2
	_check(ragling_cue["icon_key"] == "attack", "Ragling still attack")
	_check(ragling_cue["amount"] == 1, "Ragling attack amount still 1")
	_check(ragling_cue["target_position"] == 2, "Ragling now targets hero position 2")

	# Guard still blocks
	_check(guard_cue["icon_key"] == "block", "Guard still block")
	_check(guard_cue["amount"] == 1, "Guard block amount still 1")
	_check(not guard_cue.has("target_position"), "Guard still no target_position")

	# Verify selector advanced but roster unchanged
	_check(selector.is_valid(), "selector still valid after advance")
	_check(roster.is_valid(), "roster still valid")

func _test_copy_isolation_and_repeat_calls() -> void:
	var enemy_defs = _load_starter_enemies()
	var attack_defs = _load_starter_attacks()

	var selector = _make_selector(attack_defs)
	var roster = _make_roster(enemy_defs)

	var helper = CombatIntentCues.new()

	# First call
	var cues1 = helper.get_cues(selector, roster)
	# Second call
	var cues2 = helper.get_cues(selector, roster)

	# Deep equality
	_check(cues1 == cues2, "repeated calls produce equal deep values")

	# Mutate first result
	cues1[0]["amount"] = 999
	cues1[0]["enemy_position"] = 99
	if cues1[0].has("target_position"):
		cues1[0]["target_position"] = 99
	cues1.append({"mutated": true})

	# Third call should be unaffected
	var cues3 = helper.get_cues(selector, roster)
	_check(cues3 == cues2, "mutating returned array doesn't affect subsequent calls")
	_check(cues3[0]["amount"] == 1, "original amount preserved after mutation of previous result")
	_check(cues3[0]["enemy_position"] == 1, "original position preserved")
	_check(cues3.size() == 2, "original size preserved")

	# Verify selector and roster unchanged
	_check(selector.is_valid(), "selector unchanged after cue reads")
	_check(roster.is_valid(), "roster unchanged after cue reads")
	_check(selector.get_intents().size() == 2, "selector intents unchanged")
	_check(roster.get_enemies().size() == 2, "roster enemies unchanged")

func _test_slain_enemy_omitted() -> void:
	var enemy_defs = _load_starter_enemies()
	var attack_defs = _load_starter_attacks()

	var selector = _make_selector(attack_defs)
	var roster = _make_roster(enemy_defs)

	# Kill Ragling at position 1 (12 HP)
	_check(roster.apply_damage(1, 12), "lethal damage to Ragling succeeds")
	_check(roster.is_slain(1), "Ragling is slain")
	_check(not roster.is_slain(2), "Guard still alive")

	var cues = CombatIntentCues.new().get_cues(selector, roster)

	_check(cues.size() == 1, "only Guard cue remains after Ragling slain")
	var guard_cue = _find_cue(cues, 2, "ragling_guard")
	_check(guard_cue != null, "Guard cue at position 2")
	_check(guard_cue["icon_key"] == "block", "Guard still block")
	_check(guard_cue["amount"] == 1, "Guard block amount 1")

	# Verify position keys don't shift - Guard still at position 2
	_check(guard_cue["enemy_position"] == 2, "Guard position key unchanged at 2")

	# Advance selector - should not affect cue generation for dead enemy
	_check(selector.advance_turn(), "advance works with dead enemy in selector")
	var cues2 = CombatIntentCues.new().get_cues(selector, roster)
	_check(cues2.size() == 1, "still only Guard cue after advance")
	_check(_find_cue(cues2, 2, "ragling_guard") != null, "Guard cue persists")

func _test_all_slain_returns_empty() -> void:
	var enemy_defs = _load_starter_enemies()
	var attack_defs = _load_starter_attacks()

	var selector = _make_selector(attack_defs)
	var roster = _make_roster(enemy_defs)

	# Kill both
	_check(roster.apply_damage(1, 12), "kill Ragling")
	_check(roster.apply_damage(2, 12), "kill Guard")
	_check(roster.is_defeated(), "roster defeated")

	var cues = CombatIntentCues.new().get_cues(selector, roster)
	_check(cues.is_empty(), "empty cues when all enemies slain")

	# Advance and check again
	_check(selector.advance_turn(), "advance works")
	var cues2 = CombatIntentCues.new().get_cues(selector, roster)
	_check(cues2.is_empty(), "still empty after advance")

func _test_invalid_selector() -> void:
	var enemy_defs = _load_starter_enemies()
	var attack_defs = _load_starter_attacks()

	var roster = _make_roster(enemy_defs)

	# Null selector
	var cues = CombatIntentCues.new().get_cues(null, roster)
	_check(cues.is_empty(), "null selector returns empty")

	# Invalid selector (empty definitions)
	var bad_selector = CombatEnemyIntents.new([])
	_check(not bad_selector.is_valid(), "bad selector is invalid")
	cues = CombatIntentCues.new().get_cues(bad_selector, roster)
	_check(cues.is_empty(), "invalid selector returns empty")

	# Verify roster untouched
	_check(roster.is_valid(), "roster still valid after invalid selector")
	_check(roster.get_enemies().size() == 2, "roster unchanged")

func _test_invalid_roster() -> void:
	var attack_defs = _load_starter_attacks()

	var selector = _make_selector(attack_defs)

	# Null roster
	var cues = CombatIntentCues.new().get_cues(selector, null)
	_check(cues.is_empty(), "null roster returns empty")

	# Invalid roster (empty definitions)
	var bad_roster = CombatEnemies.new([])
	_check(not bad_roster.is_valid(), "bad roster is invalid")
	cues = CombatIntentCues.new().get_cues(selector, bad_roster)
	_check(cues.is_empty(), "invalid roster returns empty")

	# Verify selector untouched
	_check(selector.is_valid(), "selector still valid after invalid roster")
	_check(selector.get_intents().size() == 2, "selector unchanged")

func _test_inconsistent_selector_roster() -> void:
	# Selector has enemy at position 1, but roster has enemy at position 2 only
	var enemy_defs_1 = _load_starter_enemies()  # ragling at 1, guard at 2
	var enemy_defs_2 = [enemy_defs_1[1]]  # Only guard (will be at position 1 in new roster)
	var attack_defs = _load_starter_attacks()  # Has positions 1 and 2

	var selector = _make_selector(attack_defs)
	var roster = _make_roster(enemy_defs_2)  # Only one enemy at position 1 (was guard)

	_check(selector.is_valid(), "selector valid")
	_check(roster.is_valid(), "roster valid")

	# Selector expects enemy at position 2, but roster only has position 1
	var cues = CombatIntentCues.new().get_cues(selector, roster)
	_check(cues.is_empty(), "inconsistent positions returns empty")

	# Reverse: roster has extra position that selector doesn't cover
	var enemy_defs_3 = _load_starter_enemies()
	var attack_defs_2 = [attack_defs[0]]  # Only position 1

	var selector2 = _make_selector(attack_defs_2)
	var roster2 = _make_roster(enemy_defs_3)

	_check(selector2.is_valid(), "selector2 valid")
	_check(roster2.is_valid(), "roster2 valid")

	cues = CombatIntentCues.new().get_cues(selector2, roster2)
	# This should work - selector has position 1, roster has position 1 alive
	_check(cues.size() == 1, "partial selector with matching roster position works")
	_check(cues[0]["enemy_position"] == 1, "cue at position 1")

	# Now kill position 1 in roster
	_check(roster2.apply_damage(1, 12), "kill position 1")
	cues = CombatIntentCues.new().get_cues(selector2, roster2)
	_check(cues.is_empty(), "selector position 1 dead returns empty")

func _test_partial_invalid_action_fields() -> void:
	var enemy_defs = _load_starter_enemies()
	var roster = _make_roster(enemy_defs)

	# Attack missing target_position - CombatEnemyIntents rejects this
	var bad_attacks_1 = [
		{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 1}]},  # missing target_position
		{"enemy_position": 2, "pattern": [{"type": "block", "amount": 1}]}
	]
	var selector1 = CombatEnemyIntents.new(bad_attacks_1)
	_check(not selector1.is_valid(), "CombatEnemyIntents rejects attack missing target_position")
	# Helper also rejects (empty cues)
	var cues = CombatIntentCues.new().get_cues(selector1, roster)
	_check(cues.is_empty(), "helper rejects attack without target_position")

	# Attack with invalid target_position (out of range) - CombatEnemyIntents rejects this
	var bad_attacks_2 = [
		{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 1, "target_position": 0}]},
		{"enemy_position": 2, "pattern": [{"type": "block", "amount": 1}]}
	]
	var selector2 = CombatEnemyIntents.new(bad_attacks_2)
	_check(not selector2.is_valid(), "CombatEnemyIntents rejects invalid target_position")
	cues = CombatIntentCues.new().get_cues(selector2, roster)
	_check(cues.is_empty(), "helper rejects attack with invalid target_position")

	# Block with target_position (should not have it) - CombatEnemyIntents rejects this
	var bad_attacks_3 = [
		{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 1, "target_position": 1}]},
		{"enemy_position": 2, "pattern": [{"type": "block", "amount": 1, "target_position": 1}]}
	]
	var selector3 = CombatEnemyIntents.new(bad_attacks_3)
	_check(not selector3.is_valid(), "CombatEnemyIntents rejects block with target_position")
	cues = CombatIntentCues.new().get_cues(selector3, roster)
	_check(cues.is_empty(), "helper rejects block with target_position")

	# Block with extra field - CombatEnemyIntents rejects this (block must have exactly 2 keys in pattern)
	var bad_attacks_4 = [
		{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 1, "target_position": 1}]},
		{"enemy_position": 2, "pattern": [{"type": "block", "amount": 1, "extra": "field"}]}
	]
	var selector4 = CombatEnemyIntents.new(bad_attacks_4)
	_check(not selector4.is_valid(), "CombatEnemyIntents rejects block with extra field")
	cues = CombatIntentCues.new().get_cues(selector4, roster)
	_check(cues.is_empty(), "helper rejects block with extra field")

	# Unknown action type - CombatEnemyIntents rejects this
	var bad_attacks_5 = [
		{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 1, "target_position": 1}]},
		{"enemy_position": 2, "pattern": [{"type": "heal", "amount": 5}]}
	]
	var selector5 = CombatEnemyIntents.new(bad_attacks_5)
	_check(not selector5.is_valid(), "CombatEnemyIntents rejects unknown type")
	cues = CombatIntentCues.new().get_cues(selector5, roster)
	_check(cues.is_empty(), "helper rejects unknown action type")

	# Negative amount - CombatEnemyIntents rejects this
	var bad_attacks_6 = [
		{"enemy_position": 1, "pattern": [{"type": "attack", "amount": -1, "target_position": 1}]},
		{"enemy_position": 2, "pattern": [{"type": "block", "amount": 1}]}
	]
	var selector6 = CombatEnemyIntents.new(bad_attacks_6)
	_check(not selector6.is_valid(), "CombatEnemyIntents rejects negative amount")
	cues = CombatIntentCues.new().get_cues(selector6, roster)
	_check(cues.is_empty(), "helper rejects negative amount")

func _find_cue(cues: Array[Dictionary], position: int, enemy_id: String) -> Variant:
	for cue in cues:
		if cue["enemy_position"] == position and cue["enemy_id"] == enemy_id:
			return cue
	return null