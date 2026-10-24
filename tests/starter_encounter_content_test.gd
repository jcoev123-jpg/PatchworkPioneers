extends SceneTree

## Read-only live roster resolver: the authored idle art must agree with the same ID's
## already-working puppet mapping, without mounting or changing the app.
const ROSTER_ART := preload("res://scripts/live_enemy_roster.gd")

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_json_readable_and_entries()
	_test_encounter_patterns()
	_test_services_and_announcements()
	_test_isolation_and_corruption()
	if failures.is_empty():
		print("starter_encounter_content_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("starter_encounter_content_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _load_enemies_json() -> Array:
	var file = FileAccess.open("res://data/enemies/starter_enemies.json", FileAccess.READ)
	var text = file.get_as_text()
	file.close()
	return _normalize_enemies(JSON.parse_string(text))


func _load_attacks_json() -> Array:
	var file = FileAccess.open("res://data/encounters/starter_attacks.json", FileAccess.READ)
	var text = file.get_as_text()
	file.close()
	return _normalize_attacks(JSON.parse_string(text))


func _normalize_enemies(enemies: Array) -> Array:
	var normalized: Array = []
	for enemy in enemies:
		var norm: Dictionary = {}
		for key in enemy:
			var value = enemy[key]
			if value is float:
				if not _is_integral(value):
					norm[key] = value  # keep as float so comparison fails
				else:
					norm[key] = int(value)
			else:
				norm[key] = value
		normalized.append(norm)
	return normalized


func _is_integral(value: float) -> bool:
	return value == int(value)


func _normalize_attacks(attacks: Array) -> Array:
	var normalized: Array = []
	for attack in attacks:
		var norm: Dictionary = {}
		for key in attack:
			var value = attack[key]
			if key == "pattern":
				norm[key] = _normalize_pattern(value)
			elif value is float:
				if not _is_integral(value):
					norm[key] = value
				else:
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
				if not _is_integral(value):
					norm[key] = value
				else:
					norm[key] = int(value)
			else:
				norm[key] = value
		normalized.append(norm)
	return normalized


func _deep_copy(value) -> Variant:
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_deep_copy(item))
		return result
	elif value is Dictionary:
		var result: Dictionary = {}
		for key in value:
			result[key] = _deep_copy(value[key])
		return result
	else:
		return value


func _find_enemy_by_id(enemies: Array, id: String) -> Dictionary:
	var matches: Array = []
	for enemy in enemies:
		if enemy is Dictionary and enemy.get("id") == id:
			matches.append(enemy)
	if matches.size() != 1:
		return {}
	return matches[0].duplicate(true)


func _find_attack_by_position(attacks: Array, position: int) -> Dictionary:
	var matches: Array = []
	for attack in attacks:
		if attack is Dictionary and attack.get("enemy_position") == position:
			matches.append(attack)
	if matches.size() != 1:
		return {}
	return matches[0].duplicate(true)


func _test_json_readable_and_entries() -> void:
	# AC1 prerequisite: both files readable.
	var enemies_raw = _load_enemies_json()
	var attacks_raw = _load_attacks_json()
	_check(enemies_raw is Array, "enemies JSON is array")
	_check(attacks_raw is Array, "attacks JSON is array")

	# Deep-copy before constructing services.
	var enemies_copy = _deep_copy(enemies_raw)
	var attacks_copy = _deep_copy(attacks_raw)

	# Find by ID, not full ordered list or count.
	var ragling_raw = _find_enemy_by_id(enemies_raw, "ragling")
	var guard_raw = _find_enemy_by_id(enemies_raw, "ragling_guard")
	_check(not ragling_raw.is_empty(), "ragling found by ID in raw JSON")
	_check(not guard_raw.is_empty(), "ragling_guard found by ID in raw JSON")

	_check(ragling_raw.get("id") == "ragling", "ragling id is ragling")
	_check(ragling_raw.get("name") == "Ragling", "ragling name is Ragling")
	_check(ragling_raw.get("max_hp") == 12, "ragling max_hp is 12")
	_check(ragling_raw.get("art_path") == "res://assets/paper/enemies/ragling.png",
		"ragling art_path is its own shipped puppet image")
	_check(FileAccess.file_exists("res://assets/paper/enemies/ragling.png"),
		"ragling idle puppet image exists on disk")

	_check(guard_raw.get("id") == "ragling_guard", "ragling_guard id correct")
	_check(guard_raw.get("name") == "Guard Ragling", "ragling_guard name is Guard Ragling")
	_check(guard_raw.get("max_hp") == 12, "ragling_guard max_hp is 12")
	_check(guard_raw.get("art_path") == "res://assets/paper/enemies/ragling_guard.png",
		"ragling_guard art_path is its own shipped puppet image")
	_check(ragling_raw.get("art_path") != guard_raw.get("art_path"),
		"ragling and ragling_guard keep distinct authored art paths")
	# Both already-shipped poses of the Guard must exist, or its idle/attack pairing is a lie.
	_check(FileAccess.file_exists("res://assets/paper/enemies/ragling_guard.png"),
		"ragling_guard idle puppet image exists on disk")
	_check(FileAccess.file_exists("res://assets/paper/enemies/ragling_guard_attack.png"),
		"ragling_guard attack puppet image exists on disk")

	# AC2: the authored path agrees with the live roster's own ID-based static resolver,
	# proven here without mounting or changing the app.
	var guard_live: Dictionary = ROSTER_ART.art_paths("ragling_guard")
	var ragling_live: Dictionary = ROSTER_ART.art_paths("ragling")
	_check(guard_live.get("idle") == guard_raw.get("art_path"),
		"ragling_guard authored art_path matches the live roster idle resolver")
	_check(guard_live.get("attack") == "res://assets/paper/enemies/ragling_guard_attack.png",
		"ragling_guard live roster attack companion is the paired _attack image")
	_check(FileAccess.file_exists(String(guard_live.get("idle", ""))),
		"ragling_guard resolved idle image exists on disk")
	_check(FileAccess.file_exists(String(guard_live.get("attack", ""))),
		"ragling_guard resolved attack image exists on disk")
	_check(ragling_live.get("idle") == ragling_raw.get("art_path"),
		"ragling authored art_path matches the live roster idle resolver")
	_check(not ragling_live.is_empty() and not guard_live.is_empty()
		and ragling_live.get("idle") != guard_live.get("idle")
		and ragling_live.get("attack") != guard_live.get("attack"),
		"live roster resolves distinct idle and attack assets for ragling and ragling_guard")

	# Verify exactly-one-match: duplicate the required entry locally and observe failure.
	var dup_ragling = _find_enemy_by_id(enemies_raw + [ragling_raw], "ragling")
	_check(dup_ragling.is_empty(), "duplicate ragling entry fails unique-ID check")
	var dup_guard = _find_enemy_by_id(enemies_raw + [guard_raw], "ragling_guard")
	_check(dup_guard.is_empty(), "duplicate ragling_guard entry fails unique-ID check")

	# Unrelated future catalog entries remain allowed (only duplicates of required IDs fail).
	var extra_enemy = {"id":"future","name":"Future","max_hp":10,"art_path":"x"}
	_check(not _find_enemy_by_id(enemies_raw + [extra_enemy], "ragling").is_empty(),
		"extra unrelated entry does not break required-ID lookup")

	# Verify non-integral floats are preserved (not truncated) so changed authored values fail.
	var float_hp_enemy = _normalize_enemies([{"id":"test","name":"T","max_hp":12.5,"art_path":"x"}])
	_check(float_hp_enemy[0].get("max_hp") != 12, "non-integral max_hp 12.5 preserved as float (not truncated to 12)")
	var float_amount_attack = _normalize_attacks([{"enemy_position":1,"pattern":[{"type":"attack","amount":1.5,"target_position":1}]}])
	_check(float_amount_attack[0]["pattern"][0].get("amount") != 1, "non-integral amount 1.5 preserved (not truncated to 1)")

	# Prove no mutation to on-disk content through copy construction.
	_check(enemies_raw == _load_enemies_json(), "loaded enemies JSON unchanged after reads")
	_check(attacks_raw == _load_attacks_json(), "loaded attacks JSON unchanged after reads")


func _test_encounter_patterns() -> void:
	var attacks_raw = _load_attacks_json()

	# AC2: check identified existing source patterns by position, not complete catalog size.
	var source1_raw = _find_attack_by_position(attacks_raw, 1)
	var source2_raw = _find_attack_by_position(attacks_raw, 2)
	_check(not source1_raw.is_empty(), "source 1 found by position 1")
	_check(not source2_raw.is_empty(), "source 2 found by position 2")

	var pattern1 = source1_raw.get("pattern")
	var pattern2 = source2_raw.get("pattern")
	_check(pattern1 is Array and pattern1.size() == 3, "source 1 has three actions")
	_check(pattern2 is Array and pattern2.size() == 1, "source 2 has one action")

	_check(pattern1[0].get("type") == "attack" and pattern1[0].get("amount") == 1
		and pattern1[0].get("target_position") == 1,
		"source 1 first action: attack 1 on hero 1")
	_check(pattern1[1].get("type") == "attack" and pattern1[1].get("amount") == 1
		and pattern1[1].get("target_position") == 2,
		"source 1 second action: attack 1 on hero 2")

	_check(pattern1[2] == {"type": "attack", "amount": 1, "target_position": 3},
		"source 1 third action: attack 1 on hero 3")

	_check(pattern2[0].get("type") == "block" and pattern2[0].get("amount") == 1,
		"source 2 single action: block 1 (repeats)")

	# Verify exactly-one-match for source positions.
	var dup1 = _find_attack_by_position(attacks_raw + [source1_raw], 1)
	_check(dup1.is_empty(), "duplicate source 1 fails unique-position check")
	var dup2 = _find_attack_by_position(attacks_raw + [source2_raw], 2)
	_check(dup2.is_empty(), "duplicate source 2 fails unique-position check")


func _test_services_and_announcements() -> void:
	# Load and explicitly assemble ONLY the two identified records in positions 1 and 2.
	var enemies_raw = _load_enemies_json()
	var ragling_raw = _find_enemy_by_id(enemies_raw, "ragling")
	var guard_raw = _find_enemy_by_id(enemies_raw, "ragling_guard")

	# Deep-copy before service construction.
	var enemy_defs = [ragling_raw.duplicate(true), guard_raw.duplicate(true)]

	var attacks_raw = _load_attacks_json()
	var source1_raw = _find_attack_by_position(attacks_raw, 1)
	var source2_raw = _find_attack_by_position(attacks_raw, 2)
	var attack_defs = [
		source1_raw.duplicate(true),
		source2_raw.duplicate(true)
	]

	# AC3: real combat services.
	var roster = CombatEnemies.new(enemy_defs)
	_check(roster.is_valid(), "roster is valid with two authored enemies")
	_check(roster.get_enemies().size() == 2, "roster has two enemy slots")

	# Verify independent starting HP 12 / Block 0 for both.
	var e1 = roster.get_enemy(1)
	var e2 = roster.get_enemy(2)
	_check(e1.get("id") == "ragling" and e1.get("hp") == 12 and e1.get("block") == 0,
		"enemy 1 (ragling) starts at HP 12 Block 0")
	_check(e2.get("id") == "ragling_guard" and e2.get("hp") == 12 and e2.get("block") == 0,
		"enemy 2 (guard ragling) starts at HP 12 Block 0")

	var scheduler = CombatEnemyIntents.new(attack_defs)
	_check(scheduler.is_valid(), "scheduler valid with two authored patterns")

	# Announcements cover every target and wraparound.
	var turn0: Array[Dictionary] = scheduler.get_intents()
	_check(turn0.size() == 2, "turn 0 announces two intents")
	_check(turn0[0].get("enemy_position") == 1, "turn 0 source 1 position")
	_check(turn0[0].get("type") == "attack", "turn 0 source 1 type")
	_check(turn0[0].get("amount") == 1, "turn 0 source 1 amount")
	_check(turn0[0].get("target_position") == 1, "turn 0 source 1 target")
	_check(turn0[1].get("enemy_position") == 2 and turn0[1].get("type") == "block"
		and turn0[1].get("amount") == 1,
		"turn 0 source 2: block 1")

	# Independent returned snapshot isolation.
	var turn0_copy = turn0.duplicate(true)
	turn0_copy[0]["amount"] = 999
	turn0_copy[0]["enemy_position"] = 99
	turn0_copy.append({"invented": true})
	var next_intents = scheduler.get_intents()
	_check(next_intents.size() == 2, "mutated first returned snapshot does not alter next announcement size")
	_check(next_intents[0].get("amount") == 1, "mutated first returned snapshot does not alter next announcement amount")

	# Advance and next announcement.
	_check(scheduler.advance_turn(), "advance succeeds")
	var turn1: Array[Dictionary] = scheduler.get_intents()
	_check(turn1[0].get("enemy_position") == 1 and turn1[0].get("type") == "attack"
		and turn1[0].get("amount") == 1 and turn1[0].get("target_position") == 2,
		"turn 1 source 1: attack 1 target 2 (alternates)")
	_check(turn1[1].get("enemy_position") == 2 and turn1[1].get("type") == "block"
		and turn1[1].get("amount") == 1,
		"turn 1 source 2: block 1 (repeats)")

	# Third target while source 2 stays fixed.
	_check(scheduler.advance_turn(), "second advance succeeds")
	var turn2: Array[Dictionary] = scheduler.get_intents()
	_check(turn2[0].get("enemy_position") == 1 and turn2[0].get("type") == "attack"
		and turn2[0].get("amount") == 1 and turn2[0].get("target_position") == 3,
		"turn 2 source 1 attacks target 3")
	_check(turn2[1].get("enemy_position") == 2 and turn2[1].get("type") == "block"
		and turn2[1].get("amount") == 1,
		"turn 2 source 2 remains block 1")

	_check(scheduler.advance_turn() and scheduler.get_intents() == turn0,
		"third advance wraps complete announcements to turn zero")

	# Fresh replay: second construction from same copied definitions must match.
	var replay_roster = CombatEnemies.new(_deep_copy(enemy_defs))
	var replay_scheduler = CombatEnemyIntents.new(_deep_copy(attack_defs))
	_check(replay_roster.get_enemies() == roster.get_enemies()
		and replay_scheduler.get_intents() == turn0,
		"fresh replay has identical initial state and first announcement")
	_check(replay_scheduler.advance_turn() and replay_scheduler.get_intents() == turn1,
		"fresh replay advance produces same turn 1")
	_check(replay_scheduler.advance_turn() and replay_scheduler.get_intents() == turn2,
		"fresh replay second advance produces same turn 2")

	_check(replay_scheduler.advance_turn() and replay_scheduler.get_intents() == turn0,
		"fresh replay also wraps on third advance")

	# Unchanged caller data after service interaction.
	_check(enemy_defs == [ragling_raw.duplicate(true), guard_raw.duplicate(true)],
		"enemy definitions preserved after service use")
	_check(attack_defs == [source1_raw.duplicate(true), source2_raw.duplicate(true)],
		"attack definitions preserved after scheduler use")


func _test_isolation_and_corruption() -> void:
	# AC4: corrupt only local copies of returned snapshots and locally malformed schedules.
	var enemies_raw = _load_enemies_json()
	var ragling_raw = _find_enemy_by_id(enemies_raw, "ragling")
	var guard_raw = _find_enemy_by_id(enemies_raw, "ragling_guard")

	var attack_raw = _load_attacks_json()
	var source1_raw = _find_attack_by_position(attack_raw, 1)
	var source2_raw = _find_attack_by_position(attack_raw, 2)

	# Normal services.
	var normal_roster = CombatEnemies.new([
		ragling_raw.duplicate(true), guard_raw.duplicate(true)])
	var normal_scheduler = CombatEnemyIntents.new([
		source1_raw.duplicate(true), source2_raw.duplicate(true)])
	_check(normal_roster.is_valid() and normal_scheduler.is_valid(),
		"normal services are valid")

	# Local mutation of returned snapshot must not affect service.
	var snapshot: Array[Dictionary] = normal_roster.get_enemies()
	snapshot[0]["hp"] = 0
	snapshot[0]["id"] = "corrupted"
	_check(normal_roster.get_enemy(1).get("hp") == 12,
		"local mutation of returned roster snapshot does not alter service")

	var intents_snapshot: Array[Dictionary] = normal_scheduler.get_intents()
	intents_snapshot[0]["amount"] = 777
	_check(normal_scheduler.get_intents()[0].get("amount") == 1,
		"local mutation of returned intents snapshot does not alter scheduler")

	# Deliberately malformed local schedule must fail-closed.
	var bad_patterns = [
		# Empty schedule.
		[],
		# Attack missing target_position.
		[{"enemy_position": 1, "pattern": [{"type":"attack","amount":1}]}],
		# Unknown action type.
		[{"enemy_position": 1, "pattern": [{"type":"heal","amount":1}]}],
		# Negative amount.
		[{"enemy_position": 1, "pattern": [{"type":"attack","amount":-1,"target_position":1}]}],
		# Block with extra target_position (invalid for block).
		[{"enemy_position": 1, "pattern": [{"type":"block","amount":1,"target_position":1}]}],
	]

	for bad in bad_patterns:
		var bad_scheduler = CombatEnemyIntents.new(bad)
		_check(not bad_scheduler.is_valid(), "locally malformed schedule is rejected (fail-closed) for " + str(bad))
		_check(bad_scheduler.get_intents().is_empty(), "invalid schedule produces no partial intents for " + str(bad))
		_check(not bad_scheduler.advance_turn(), "invalid schedule cannot advance for " + str(bad))

	# Prove no mutation of actual authored files after all checks.
	_check(_load_enemies_json() == enemies_raw, "authored enemy JSON unchanged after all checks")
	_check(_load_attacks_json() == attack_raw, "authored attacks JSON unchanged after all checks")
