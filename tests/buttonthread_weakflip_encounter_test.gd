extends SceneTree

const ENCOUNTER_PATH := "res://data/encounters/buttonthread_weakflip.json"
const ENCOUNTER_ID := "buttonthread_weakflip"
const ENEMIES_PATH := "res://data/enemies/run_enemies.json"
const HOLDOUT_PATH := "res://data/encounters/buttonhole_holdout.json"

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_ac1_parse_and_intents()
	_test_ac2_beat_1_weak_and_shove()
	_test_ac3_full_cycle_and_replay()
	_test_ac4_roster_mapping_and_holdout()
	if failures.is_empty():
		print("buttonthread_weakflip_encounter_test: PASS (", checks, " checks)")
	else:
		for f in failures:
			printerr(f)
		print("buttonthread_weakflip_encounter_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _load_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var t := f.get_as_text()
	f.close()
	return t


func _load_definitions(path: String) -> Array:
	var text := _load_text(path)
	if text.is_empty():
		return []
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return []
	var parsed = parser.data
	if not parsed is Array:
		return []
	return parsed.duplicate(true)


func _expected_schedule() -> Array:
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "debuff", "amount": 1, "target_position": 1, "status": "weak"},
			{"type": "block", "amount": 3},
			{"type": "attack", "amount": 4, "target_position": 1}
		]},
		{"enemy_position": 2, "pattern": [
			{"type": "shove", "amount": 0, "target_position": 2, "direction": -1},
			{"type": "attack", "amount": 5, "target_position": 2},
			{"type": "debuff", "amount": 1, "target_position": 3, "status": "exposed"}
		]}
	]


func _test_ac1_parse_and_intents() -> void:
	_check(FileAccess.file_exists(ENCOUNTER_PATH),
		"AC1: authored file exists")
	var definitions := _load_definitions(ENCOUNTER_PATH)
	_check(definitions.size() == 2,
		"AC1: exactly two source records")
	var expected := _expected_schedule()
	_check(definitions == expected,
		"AC1: definitions match authored schedule exactly")
	_check(CombatEnemyIntents.new(definitions).is_valid(),
		"AC1: real CombatEnemyIntents validates")
	var scheduler := CombatEnemyIntents.new(definitions)
	_check(scheduler.is_valid(),
		"AC1: scheduler is valid")
	for turn in range(3):
		var intents := scheduler.get_intents()
		_check(intents.size() == 2,
			"AC1: beat %d announces two actions" % turn)
		_check(intents[0]["enemy_position"] == 1
			and intents[1]["enemy_position"] == 2,
			"AC1: beat %d source order 1 then 2" % turn)
		scheduler.advance_turn()


func _test_ac2_beat_1_weak_and_shove() -> void:
	var definitions := _load_definitions(ENCOUNTER_PATH)
	var party := CombatParty.new([
		{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26},
	])
	var enemies := CombatEnemies.new([
		{"id": "button_guard", "max_hp": 16},
		{"id": "seam_ripper", "max_hp": 18},
	])
	_check(party.is_valid() and enemies.is_valid(),
		"AC2: valid party and enemies fixtures")

	var scheduler := CombatEnemyIntents.new(definitions)
	var phase := CombatEnemyPhase.new()
	var intents := scheduler.get_intents()

	# Beat 1: Weak on Warden (position 1), then shove position 2 toward 1
	_check(intents[0]["type"] == "debuff"
		and intents[0]["target_position"] == 1
		and intents[0]["status"] == "weak"
		and intents[0]["amount"] == 1,
		"AC2: beat 1 first action is Weak 1 on hero 1")
	_check(intents[1]["type"] == "shove"
		and intents[1]["target_position"] == 2
		and intents[1]["direction"] == -1,
		"AC2: beat 1 second action is shove position 2 toward 1")

	var result := phase.execute_phase(party, enemies, intents)
	_check(result.ok,
		"AC2: phase succeeds")
	_check(result.events.size() == 2,
		"AC2: two events recorded")

	# After shove: Seamstress (original middle) moves to front, Warden to middle
	var heroes_after := party.get_heroes()
	_check(heroes_after[0]["id"] == "seamstress"
		and heroes_after[1]["id"] == "warden"
		and heroes_after[2]["id"] == "tinker",
		"AC2: after shove, front=Seamstress, middle=Warden, rear=Tinker")

	# Warden carries Weak status after moving to middle
	var middle_hero := party.get_hero(2)  # position 2 is middle now
	_check(middle_hero.get("id") == "warden",
		"AC2: middle hero is Warden")
	_check(middle_hero.get("statuses", {}).get("weak", 0) == 1,
		"AC2: Warden carries Weak 1 after swap")

	# Both events applied
	_check(result.events[0]["applied"] == true
		and result.events[1]["applied"] == true,
		"AC2: both enemy events applied")


func _test_ac3_full_cycle_and_replay() -> void:
	var definitions := _load_definitions(ENCOUNTER_PATH)
	var party := CombatParty.new([
		{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26},
	])
	var enemies := CombatEnemies.new([
		{"id": "button_guard", "max_hp": 16},
		{"id": "seam_ripper", "max_hp": 18},
	])
	var scheduler := CombatEnemyIntents.new(definitions)
	var phase := CombatEnemyPhase.new()

	# Beat 1 (already tested) - apply it to get to state after beat 1
	var beat1 := scheduler.get_intents()
	var r1 := phase.execute_phase(party, enemies, beat1)
	_check(r1.ok, "AC3: beat 1 succeeds")
	scheduler.advance_turn()

	# Beat 2: Block 3 (Button Guard) and Attack 5 on current hero position 2
	var beat2 := scheduler.get_intents()
	_check(beat2[0]["type"] == "block" and beat2[0]["amount"] == 3,
		"AC3: beat 2 first action Block 3")
	_check(beat2[1]["type"] == "attack" and beat2[1]["amount"] == 5
		and beat2[1]["target_position"] == 2,
		"AC3: beat 2 second action attack 5 on hero 2")

	var before_beat2_heroes := party.get_heroes()
	var before_beat2_enemies := enemies.get_enemies()
	var r2 := phase.execute_phase(party, enemies, beat2)
	_check(r2.ok, "AC3: beat 2 succeeds")

	# After beat 2: Button Guard has 3 Block
	_check(enemies.get_enemy(1).get("block", 0) == 3,
		"AC3: Button Guard has 3 Block after beat 2")
	# Attack 5 on hero position 2 (current middle, Warden after swap)
	# Block 3 absorbs first 3, so 2 damage reaches Warden
	var hero_2_after_beat2 := party.get_hero(2)
	_check(hero_2_after_beat2.get("id") == "warden"
		and hero_2_after_beat2.get("hp") == 38,  # 40 - (5 - 3) = 38
		"AC3: Warden at position 2 takes 2 damage (5 - 3 Block) = 38 HP")

	# Both events applied
	_check(r2.events.size() == 2,
		"AC3: beat 2 produces two events")
	_check(r2.events[0]["type"] == "block" and r2.events[0]["applied"] == true,
		"AC3: beat 2 block event applied")
	_check(r2.events[1]["type"] == "attack" and r2.events[1]["applied"] == true,
		"AC3: beat 2 attack event applied")
	scheduler.advance_turn()

	# Beat 3: Attack 4 on hero position 1 (current front, Seamstress) and Exposed 1 on hero 3
	var beat3 := scheduler.get_intents()
	_check(beat3[0]["type"] == "attack" and beat3[0]["amount"] == 4
		and beat3[0]["target_position"] == 1,
		"AC3: beat 3 first action attack 4 on hero 1")
	_check(beat3[1]["type"] == "debuff" and beat3[1]["amount"] == 1
		and beat3[1]["target_position"] == 3
		and beat3[1]["status"] == "exposed",
		"AC3: beat 3 second action debuff exposed 1 on hero 3")

	var r3 := phase.execute_phase(party, enemies, beat3)
	_check(r3.ok, "AC3: beat 3 succeeds")

	# After beat 3: Seamstress (front) takes 4 damage, Tinker (rear) gets Exposed 1
	var hero_1_after_beat3 := party.get_hero(1)
	var hero_3_after_beat3 := party.get_hero(3)
	_check(hero_1_after_beat3.get("id") == "seamstress"
		and hero_1_after_beat3.get("hp") == 26,  # 30 - 4 = 26
		"AC3: Seamstress takes 4 damage = 26 HP")
	_check(hero_3_after_beat3.get("statuses", {}).get("exposed", 0) == 1,
		"AC3: Tinker has Exposed 1")

	_check(r3.events[0]["type"] == "attack" and r3.events[0]["applied"] == true,
		"AC3: beat 3 attack applied")
	_check(r3.events[1]["type"] == "debuff" and r3.events[1]["applied"] == true,
		"AC3: beat 3 debuff applied")

	# Verify wrap back to beat 1
	scheduler.advance_turn()
	var beat_wrap := scheduler.get_intents()
	_check(beat_wrap == [
		{"enemy_position": 1, "type": "debuff", "amount": 1, "target_position": 1, "status": "weak"},
		{"enemy_position": 2, "type": "shove", "amount": 0, "target_position": 2, "direction": -1}
	],
		"AC3: wrap to beat 1 announces original actions")

	# Fresh fixture replay identically
	var replay_party := CombatParty.new([
		{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26},
	])
	var replay_enemies := CombatEnemies.new([
		{"id": "button_guard", "max_hp": 16},
		{"id": "seam_ripper", "max_hp": 18},
	])
	var replay_scheduler := CombatEnemyIntents.new(definitions)
	var replay_phase := CombatEnemyPhase.new()

	var replay_beat1 := replay_scheduler.get_intents()
	var replay_r1 := replay_phase.execute_phase(replay_party, replay_enemies, replay_beat1)
	replay_scheduler.advance_turn()
	var replay_beat2 := replay_scheduler.get_intents()
	var replay_r2 := replay_phase.execute_phase(replay_party, replay_enemies, replay_beat2)
	replay_scheduler.advance_turn()
	var replay_beat3 := replay_scheduler.get_intents()
	var replay_r3 := replay_phase.execute_phase(replay_party, replay_enemies, replay_beat3)

	_check(replay_r1.ok and replay_r2.ok and replay_r3.ok,
		"AC3: replay succeeds for all three beats")


func _test_ac4_roster_mapping_and_holdout() -> void:
	# Load the existing buttonhole_holdout entry by named path; do not assert pool size
	_check(FileAccess.file_exists(HOLDOUT_PATH),
		"AC4: existing buttonhole_holdout file exists and is parseable")
	var holdout_definitions := _load_definitions(HOLDOUT_PATH)
	_check(holdout_definitions.size() == 2,
		"AC4: existing holdout parses (size not a total claim)")

	# Load new file by its named path
	_check(FileAccess.file_exists(ENCOUNTER_PATH),
		"AC4: new encounter file exists")

	# Load existing enemy catalog
	_check(FileAccess.file_exists(ENEMIES_PATH),
		"AC4: existing run_enemies.json exists")

	# Load catalog records
	var catalog_text := _load_text(ENEMIES_PATH)
	_check(not catalog_text.is_empty(),
		"AC4: enemy catalog is readable")
	var catalog_parser := JSON.new()
	_check(catalog_parser.parse(catalog_text) == OK,
		"AC4: enemy catalog parses as JSON")
	var catalog = catalog_parser.data
	_check(catalog is Array,
		"AC4: enemy catalog is array")

	# Verify the two required IDs exist
	var found_guard := false
	var found_ripper := false
	for record in catalog:
		if record is Dictionary:
			var id: String = record.get("id", "")
			if id == "button_guard":
				found_guard = true
				_check(record.get("max_hp", 0) == 16,
					"AC4: button_guard has max_hp 16")
			elif id == "seam_ripper":
				found_ripper = true
				_check(record.get("max_hp", 0) == 18,
					"AC4: seam_ripper has max_hp 18")
	_check(found_guard and found_ripper,
		"AC4: both existing M04 enemy IDs present in catalog")

	# Test-local roster mapping through RunTypedBattleRoster
	var definitions := _load_definitions(ENCOUNTER_PATH)
	var typed_choice := {
		"success": true,
		"node_type": "Fight",
		"encounter_id": ENCOUNTER_ID,
		"definitions": definitions,
	}
	var encounter_rosters := {
		"buttonthread_weakflip": ["button_guard", "seam_ripper"]
	}
	var roster := RunTypedBattleRoster.new()
	var result := roster.assemble(typed_choice, encounter_rosters, [ENEMIES_PATH])
	_check(result.get("ok", false) == true,
		"AC4: test-local roster mapping succeeds")
	_check(result.get("encounter_id") == ENCOUNTER_ID,
		"AC4: roster preserves encounter id")
	_check(result.get("node_type") == "Fight",
		"AC4: roster preserves Fight node type")

	# Verify assembled enemies
	var assembled_enemies := result.get("enemies", null)
	_check(assembled_enemies != null and assembled_enemies.is_valid(),
		"AC4: assembled enemies valid")
	var assembled_roster := assembled_enemies.get_enemies()
	_check(assembled_roster.size() == 2,
		"AC4: assembled roster has exactly two enemies")
	_check(assembled_roster[0].get("id") == "button_guard",
		"AC4: first enemy is button_guard")
	_check(assembled_roster[1].get("id") == "seam_ripper",
		"AC4: second enemy is seam_ripper")

	# Verify definitions preserved
	var preserved_definitions := result.get("definitions", [])
	_check(preserved_definitions == definitions,
		"AC4: definitions preserved in roster result")

	# No new shared Fight-pool entry or live route claim made in this test
