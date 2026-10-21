extends SceneTree

const HERO_CATALOG_PATH := "res://data/heroes/starter_party.json"
const ENEMY_CATALOG_PATH := "res://data/enemies/run_enemies.json"
const ENCOUNTER_ID := "ripper_switchstrike"
const ENCOUNTER_PATH := "res://data/encounters/ripper_switchstrike.json"
const STARTER_ATTACKS_PATH := "res://data/encounters/starter_attacks.json"
const SEAMWARD_TURNABOUT_PATH := "res://data/encounters/seamward_turnabout.json"

const LOCAL_FIGHT_POOL := {
	ENCOUNTER_ID: ENCOUNTER_PATH,
}
const LOCAL_POOLS_BY_TYPE := {
	"Fight": LOCAL_FIGHT_POOL,
}
const LOCAL_ROSTER_MAP := {
	ENCOUNTER_ID: ["seam_ripper", "fray_scavenger"],
}

var failures: Array[String] = []
var checks := 0


func _init() -> void:
	_verify_failure_harness()
	_run_all_checks()
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		print("ripper_switchstrike_encounter_test: FAIL (%d failures)" % failures.size())
		quit(1)
		return
	print("ripper_switchstrike_encounter_test: PASS (%d checks)" % checks)
	quit(0)


func _check(condition: bool, message: String, sink: Array[String] = failures) -> void:
	checks += 1
	if not condition:
		sink.append(message)


func _verify_failure_harness() -> void:
	var probe_failures: Array[String] = []
	_check(false, "deliberate failure probe", probe_failures)
	if probe_failures.size() != 1 or probe_failures[0] != "deliberate failure probe":
		failures.append("Failure harness did not record a deliberately failing check.")


func _read_text(path: String) -> String:
	_check(FileAccess.file_exists(path), "Expected file to exist: %s" % path)
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "Expected file to open: %s" % path)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _is_integral_number(value: Variant) -> bool:
	if value is int:
		return true
	if not value is float or is_nan(value) or is_inf(value):
		return false
	return absf(value) <= 9007199254740991.0 and floorf(value) == value


func _load_json_array(path: String) -> Array:
	var text := _read_text(path)
	if text.is_empty():
		return []
	var parser := JSON.new()
	var err := parser.parse(text)
	_check(err == OK, "Expected valid JSON in %s" % path)
	if err != OK or not parser.data is Array:
		_check(false, "Expected top-level JSON Array in %s" % path)
		return []
	return parser.data.duplicate(true)


func _find_unique_by_key(records: Array, key: String, expected_value: Variant, label: String) -> Dictionary:
	var matches: Array[Dictionary] = []
	for record in records:
		if record is Dictionary and record.get(key) == expected_value:
			matches.append(record.duplicate(true))
	_check(
		matches.size() == 1,
		"Expected exactly 1 record with %s=%s in %s, found %d" % [key, str(expected_value), label, matches.size()]
	)
	if matches.size() != 1:
		return {}
	return matches[0]


func _coerce_catalog_actor(raw: Dictionary, label: String) -> Dictionary:
	var copy := raw.duplicate(true)
	_check(copy.get("id") is String and not String(copy["id"]).is_empty(), "%s must have nonempty String id" % label)
	_check(copy.get("name") is String and not String(copy["name"]).is_empty(), "%s must have nonempty String name" % label)
	_check(copy.get("art_path") is String and not String(copy["art_path"]).is_empty(), "%s must have nonempty String art_path" % label)
	var max_hp: Variant = copy.get("max_hp")
	_check(_is_integral_number(max_hp), "%s max_hp must be integral" % label)
	if _is_integral_number(max_hp):
		copy["max_hp"] = int(max_hp)
	return copy


func _build_catalog_party(hero_catalog: Array) -> CombatParty:
	var warden := _coerce_catalog_actor(_find_unique_by_key(hero_catalog, "id", "warden", HERO_CATALOG_PATH), "warden")
	var seamstress := _coerce_catalog_actor(_find_unique_by_key(hero_catalog, "id", "seamstress", HERO_CATALOG_PATH), "seamstress")
	var tinker := _coerce_catalog_actor(_find_unique_by_key(hero_catalog, "id", "tinker", HERO_CATALOG_PATH), "tinker")
	return CombatParty.new([warden, seamstress, tinker])


func _expected_definitions() -> Array:
	return [
		{
			"enemy_position": 1,
			"pattern": [
				{"type": "shove", "amount": 0, "target_position": 2, "direction": 1},
				{"type": "attack", "amount": 3, "target_position": 2},
				{"type": "attack", "amount": 3, "target_position": 1},
			],
		},
		{
			"enemy_position": 2,
			"pattern": [
				{"type": "attack", "amount": 4, "target_position": 3},
				{"type": "buff", "amount": 3},
				{"type": "attack", "amount": 2, "target_position": 3},
			],
		},
	]


func _expected_beat_1() -> Array[Dictionary]:
	return [
		{"type": "shove", "amount": 0, "target_position": 2, "direction": 1, "enemy_position": 1},
		{"type": "attack", "amount": 4, "target_position": 3, "enemy_position": 2},
	]


func _expected_beat_2() -> Array[Dictionary]:
	return [
		{"type": "attack", "amount": 3, "target_position": 2, "enemy_position": 1},
		{"type": "buff", "amount": 3, "enemy_position": 2},
	]


func _expected_beat_3() -> Array[Dictionary]:
	return [
		{"type": "attack", "amount": 3, "target_position": 1, "enemy_position": 1},
		{"type": "attack", "amount": 2, "target_position": 3, "enemy_position": 2},
	]


func _assemble_local_enemies() -> CombatEnemies:
	var choice := {
		"success": true,
		"node_type": "Fight",
		"encounter_id": ENCOUNTER_ID,
		"definitions": _expected_definitions(),
	}
	var assembled := RunTypedBattleRoster.new().assemble(
		choice, LOCAL_ROSTER_MAP.duplicate(true), [ENEMY_CATALOG_PATH]
	)
	_check(assembled.get("ok") == true, "RunTypedBattleRoster.assemble must succeed for local ripper_switchstrike choice.")
	var enemies: CombatEnemies = assembled.get("enemies")
	_check(enemies != null and enemies.is_valid(), "Assembled CombatEnemies must be valid.")
	return enemies


func _run_all_checks() -> void:
	var raw_hero_catalog := _load_json_array(HERO_CATALOG_PATH)
	var raw_enemy_catalog := _load_json_array(ENEMY_CATALOG_PATH)
	var hero_catalog_snapshot := raw_hero_catalog.duplicate(true)
	var enemy_catalog_snapshot := raw_enemy_catalog.duplicate(true)

	_verify_ac1_schedule_intents_and_local_roster(raw_hero_catalog, raw_enemy_catalog)
	_verify_ac2_and_ac3_three_beat_combat_and_wrap(raw_hero_catalog)
	_verify_ac4_slain_skip_and_downed_atomic_rejection(raw_hero_catalog)
	_verify_ac5_typed_selection_caching_replay_and_rejections(raw_hero_catalog)
	_verify_companion_schedules_unmodified()

	_check(raw_hero_catalog == hero_catalog_snapshot, "Hero catalog snapshot must remain unmutated after all checks.")
	_check(raw_enemy_catalog == enemy_catalog_snapshot, "Enemy catalog snapshot must remain unmutated after all checks.")
	_check(_load_json_array(HERO_CATALOG_PATH) == hero_catalog_snapshot, "On-disk hero catalog must remain unmutated.")
	_check(_load_json_array(ENEMY_CATALOG_PATH) == enemy_catalog_snapshot, "On-disk enemy catalog must remain unmutated.")


func _verify_ac1_schedule_intents_and_local_roster(hero_catalog: Array, enemy_catalog: Array) -> void:
	# Verify required catalog records by unique ID without asserting global catalog size or order.
	var warden := _coerce_catalog_actor(_find_unique_by_key(hero_catalog, "id", "warden", HERO_CATALOG_PATH), "warden")
	var seamstress := _coerce_catalog_actor(_find_unique_by_key(hero_catalog, "id", "seamstress", HERO_CATALOG_PATH), "seamstress")
	var tinker := _coerce_catalog_actor(_find_unique_by_key(hero_catalog, "id", "tinker", HERO_CATALOG_PATH), "tinker")
	_check(warden.get("name") == "Warden" and warden.get("max_hp") == 40, "Catalog Warden must have name Warden and 40 max_hp.")
	_check(seamstress.get("name") == "Seamstress" and seamstress.get("max_hp") == 30, "Catalog Seamstress must have name Seamstress and 30 max_hp.")
	_check(tinker.get("name") == "Tinker" and tinker.get("max_hp") == 26, "Catalog Tinker must have name Tinker and 26 max_hp.")

	var ripper := _coerce_catalog_actor(_find_unique_by_key(enemy_catalog, "id", "seam_ripper", ENEMY_CATALOG_PATH), "seam_ripper")
	var scavenger := _coerce_catalog_actor(_find_unique_by_key(enemy_catalog, "id", "fray_scavenger", ENEMY_CATALOG_PATH), "fray_scavenger")
	_check(
		ripper.get("name") == "Seam Ripper" and ripper.get("max_hp") == 18,
		"Catalog Seam Ripper must have name Seam Ripper and 18 max_hp."
	)
	_check(
		scavenger.get("name") == "Fray Scavenger" and scavenger.get("max_hp") == 14,
		"Catalog Fray Scavenger must have name Fray Scavenger and 14 max_hp."
	)

	var raw_text := _read_text(ENCOUNTER_PATH)
	var raw_json := _load_json_array(ENCOUNTER_PATH)
	_check(raw_json.size() == 2, "ripper_switchstrike.json must contain 2 enemy source definitions.")
	for raw_def in raw_json:
		_check(raw_def is Dictionary and raw_def.size() == 2, "Each raw definition must be a 2-key Dictionary.")
		if raw_def is Dictionary:
			_check(_is_integral_number(raw_def.get("enemy_position")), "Raw enemy_position must be integral before coercion.")
			var raw_pattern: Variant = raw_def.get("pattern", [])
			_check(raw_pattern is Array and raw_pattern.size() == 3, "Each raw pattern must be a 3-beat Array.")
			if raw_pattern is Array:
				for raw_action in raw_pattern:
					_check(raw_action is Dictionary, "Each raw action must be a Dictionary.")
					if raw_action is Dictionary:
						_check(_is_integral_number(raw_action.get("amount")), "Raw action amount must be integral.")
						if raw_action.has("target_position"):
							_check(_is_integral_number(raw_action.get("target_position")), "Raw target_position must be integral.")
						if raw_action.has("direction"):
							_check(_is_integral_number(raw_action.get("direction")), "Raw direction must be integral.")

	var definitions := RunFightEncounterSelection._parse_schedule_text(raw_text)
	_check(definitions == _expected_definitions(), "RunFightEncounterSelection._parse_schedule_text must return exact expected definitions.")
	var source_1 := _find_unique_by_key(definitions, "enemy_position", 1, ENCOUNTER_PATH)
	var source_2 := _find_unique_by_key(definitions, "enemy_position", 2, ENCOUNTER_PATH)
	_check(
		source_1.get("pattern") == _expected_definitions()[0]["pattern"],
		"Source 1 pattern must match exact 3-beat Seam Ripper schedule."
	)
	_check(
		source_2.get("pattern") == _expected_definitions()[1]["pattern"],
		"Source 2 pattern must match exact 3-beat Fray Scavenger schedule."
	)

	var intents := CombatEnemyIntents.new(definitions)
	_check(intents.is_valid(), "CombatEnemyIntents must validate ripper_switchstrike definitions.")

	var beat_1_a := intents.get_intents()
	var beat_1_b := intents.get_intents()
	_check(beat_1_a == _expected_beat_1(), "Beat 1 intents must match expected middle-to-rear shove and rear attack.")
	_check(beat_1_b == _expected_beat_1(), "Repeated get_intents() on Beat 1 must not advance implicitly.")
	if not beat_1_a.is_empty():
		beat_1_a[0]["amount"] = 999
		beat_1_a.clear()
	_check(beat_1_b == _expected_beat_1(), "Mutating one get_intents() result must not affect another fetched result.")
	_check(intents.get_intents() == _expected_beat_1(), "Mutating returned intents must not mutate CombatEnemyIntents state.")

	_check(intents.advance_turn(), "advance_turn() from Beat 1 to Beat 2 must succeed.")
	_check(intents.get_intents() == _expected_beat_2(), "Beat 2 intents must match expected middle attack and self-Block buff.")
	_check(intents.get_intents() == _expected_beat_2(), "Repeated get_intents() on Beat 2 must not advance implicitly.")

	_check(intents.advance_turn(), "advance_turn() from Beat 2 to Beat 3 must succeed.")
	_check(intents.get_intents() == _expected_beat_3(), "Beat 3 intents must match expected front and rear attacks.")
	_check(intents.get_intents() == _expected_beat_3(), "Repeated get_intents() on Beat 3 must not advance implicitly.")

	_check(intents.advance_turn(), "advance_turn() from Beat 3 to Beat 4 wrap must succeed.")
	_check(intents.get_intents() == _expected_beat_1(), "Beat 4 must wrap back to Beat 1 announcements.")
	_check(intents.advance_turn(), "advance_turn() from Beat 4 to Beat 5 must succeed.")
	_check(intents.get_intents() == _expected_beat_2(), "Beat 5 must match Beat 2 announcements.")
	_check(intents.advance_turn(), "advance_turn() from Beat 5 to Beat 6 must succeed.")
	_check(intents.get_intents() == _expected_beat_3(), "Beat 6 must match Beat 3 announcements.")

	var reversed_intents := CombatEnemyIntents.new([source_2.duplicate(true), source_1.duplicate(true)])
	_check(reversed_intents.is_valid(), "CombatEnemyIntents must accept reversed source order.")
	_check(reversed_intents.get_intents() == _expected_beat_1(), "CombatEnemyIntents must sort intents by ascending enemy_position.")

	# Verify local RunTypedBattleRoster assembly without touching global pool mappings.
	var typed_choice := {
		"success": true,
		"node_type": "Fight",
		"encounter_id": ENCOUNTER_ID,
		"definitions": definitions.duplicate(true),
	}
	var typed_choice_snapshot := typed_choice.duplicate(true)
	var roster_map := LOCAL_ROSTER_MAP.duplicate(true)
	var roster_map_snapshot := roster_map.duplicate(true)
	var assembled := RunTypedBattleRoster.new().assemble(
		typed_choice, roster_map, [ENEMY_CATALOG_PATH]
	)
	_check(typed_choice == typed_choice_snapshot, "RunTypedBattleRoster.assemble must not mutate caller typed_choice.")
	_check(roster_map == roster_map_snapshot, "RunTypedBattleRoster.assemble must not mutate caller roster_map.")
	_check(
		assembled.get("ok") == true
		and assembled.get("node_type") == "Fight"
		and assembled.get("encounter_id") == ENCOUNTER_ID
		and assembled.get("definitions") == _expected_definitions(),
		"RunTypedBattleRoster.assemble must return ok=true with Fight node_type, encounter_id, and definitions."
	)
	var enemies: CombatEnemies = assembled.get("enemies")
	_check(enemies != null and enemies.is_valid() and enemies.get_enemies().size() == 2, "Assembled roster must contain 2 valid enemies.")
	if enemies != null and enemies.is_valid():
		var slot_1 := enemies.get_enemy(1)
		var slot_2 := enemies.get_enemy(2)
		_check(
			slot_1.get("id") == "seam_ripper"
			and slot_1.get("name") == "Seam Ripper"
			and slot_1.get("position") == 1
			and slot_1.get("hp") == 18
			and slot_1.get("max_hp") == 18
			and slot_1.get("block") == 0
			and slot_1.get("art_path") == ripper.get("art_path"),
			"Assembled enemy slot 1 must be Seam Ripper with 18/18 HP, 0 Block, and catalog art_path."
		)
		_check(
			slot_2.get("id") == "fray_scavenger"
			and slot_2.get("name") == "Fray Scavenger"
			and slot_2.get("position") == 2
			and slot_2.get("hp") == 14
			and slot_2.get("max_hp") == 14
			and slot_2.get("block") == 0
			and slot_2.get("art_path") == scavenger.get("art_path"),
			"Assembled enemy slot 2 must be Fray Scavenger with 14/14 HP, 0 Block, and catalog art_path."
		)


func _verify_ac2_and_ac3_three_beat_combat_and_wrap(hero_catalog: Array) -> void:
	var party := _build_catalog_party(hero_catalog)
	var enemies := _assemble_local_enemies()
	_check(party.is_valid(), "Catalog CombatParty must be valid.")
	_check(enemies.is_valid(), "Assembled CombatEnemies must be valid.")

	var starting_block := CombatStartingBlock.new(party)
	_check(starting_block.apply(), "First CombatStartingBlock.apply() must grant Warden 6 opening Block.")
	_check(not starting_block.apply(), "Second CombatStartingBlock.apply() must fail closed as one-shot.")

	var warden_art: String = party.get_hero(1).get("art_path", "")
	var seamstress_art: String = party.get_hero(2).get("art_path", "")
	var tinker_art: String = party.get_hero(3).get("art_path", "")

	_check(
		party.get_hero(1).get("id") == "warden"
		and party.get_hero(1).get("position") == 1
		and party.get_hero(1).get("hp") == 40
		and party.get_hero(1).get("max_hp") == 40
		and party.get_hero(1).get("block") == 6,
		"Opening slot 1 must be Warden at 40/40 HP and 6 Block."
	)
	_check(
		party.get_hero(2).get("id") == "seamstress"
		and party.get_hero(2).get("position") == 2
		and party.get_hero(2).get("hp") == 30
		and party.get_hero(2).get("max_hp") == 30
		and party.get_hero(2).get("block") == 0,
		"Opening slot 2 must be Seamstress at 30/30 HP and 0 Block."
	)
	_check(
		party.get_hero(3).get("id") == "tinker"
		and party.get_hero(3).get("position") == 3
		and party.get_hero(3).get("hp") == 26
		and party.get_hero(3).get("max_hp") == 26
		and party.get_hero(3).get("block") == 0,
		"Opening slot 3 must be Tinker at 26/26 HP and 0 Block."
	)

	var definitions := RunFightEncounterSelection._parse_schedule_text(_read_text(ENCOUNTER_PATH))
	var intents := CombatEnemyIntents.new(definitions)
	var phase := CombatEnemyPhase.new()

	# AC2: Beat 1 shoves living Seamstress from slot 2 to slot 3 (swapping with Tinker),
	# then Fray Scavenger hits now-slot-3 Seamstress for 4 (30 -> 26 HP).
	var beat_1_announced := intents.get_intents()
	_check(beat_1_announced == _expected_beat_1(), "Beat 1 must announce source-1 shove (2 -> 3) then source-2 attack on slot 3.")
	var beat_1_result := phase.execute_phase(party, enemies, beat_1_announced)
	var expected_beat_1_events: Array[Dictionary] = [
		{"type": "shove", "enemy_position": 1, "target_position": 2, "direction": 1, "applied": true},
		{"type": "attack", "enemy_position": 2, "target_position": 3, "applied": true},
	]
	_check(
		beat_1_result == {"ok": true, "events": expected_beat_1_events},
		"Beat 1 execute_phase must return applied shove and attack events in ascending source order."
	)
	_check(
		party.get_hero(1).get("id") == "warden"
		and party.get_hero(1).get("name") == "Warden"
		and party.get_hero(1).get("art_path") == warden_art
		and party.get_hero(1).get("position") == 1
		and party.get_hero(1).get("hp") == 40
		and party.get_hero(1).get("max_hp") == 40
		and party.get_hero(1).get("block") == 6,
		"After Beat 1, Warden must remain in slot 1 with 40 HP and 6 Block."
	)
	_check(
		party.get_hero(2).get("id") == "tinker"
		and party.get_hero(2).get("name") == "Tinker"
		and party.get_hero(2).get("art_path") == tinker_art
		and party.get_hero(2).get("position") == 2
		and party.get_hero(2).get("hp") == 26
		and party.get_hero(2).get("max_hp") == 26
		and party.get_hero(2).get("block") == 0,
		"After Beat 1, Tinker must be at slot 2 with 26 HP, 0 Block, and full Tinker identity metadata."
	)
	_check(
		party.get_hero(3).get("id") == "seamstress"
		and party.get_hero(3).get("name") == "Seamstress"
		and party.get_hero(3).get("art_path") == seamstress_art
		and party.get_hero(3).get("position") == 3
		and party.get_hero(3).get("hp") == 26
		and party.get_hero(3).get("max_hp") == 30
		and party.get_hero(3).get("block") == 0,
		"After Beat 1, Seamstress must be at slot 3 with 26/30 HP, 0 Block, and full Seamstress identity metadata."
	)
	_check(
		enemies.get_enemy(1).get("id") == "seam_ripper"
		and enemies.get_enemy(1).get("hp") == 18
		and enemies.get_enemy(1).get("block") == 0
		and enemies.get_enemy(2).get("id") == "fray_scavenger"
		and enemies.get_enemy(2).get("hp") == 14
		and enemies.get_enemy(2).get("block") == 0,
		"After Beat 1, both enemies must remain at 18/14 HP and 0 Block."
	)

	# AC3: Advance intents and call start_player_turn before Beat 2 so opening Block resets.
	_check(intents.advance_turn(), "Advancing intents from Beat 1 to Beat 2 must succeed.")
	_check(party.start_player_turn(), "CombatParty.start_player_turn() before Beat 2 must succeed.")
	_check(party.get_hero(1).get("block") == 0, "start_player_turn() must reset Warden's 6 opening Block to 0 before Beat 2.")

	var beat_2_announced := intents.get_intents()
	_check(beat_2_announced == _expected_beat_2(), "Beat 2 must announce source-1 attack on slot 2 and source-2 buff of 3.")
	var beat_2_result := phase.execute_phase(party, enemies, beat_2_announced)
	var expected_beat_2_events: Array[Dictionary] = [
		{"type": "attack", "enemy_position": 1, "target_position": 2, "applied": true},
		{"type": "buff", "enemy_position": 2, "applied": true},
	]
	_check(
		beat_2_result == {"ok": true, "events": expected_beat_2_events},
		"Beat 2 execute_phase must return applied middle attack and self-Block buff events."
	)
	_check(
		party.get_hero(1).get("id") == "warden"
		and party.get_hero(1).get("position") == 1
		and party.get_hero(1).get("hp") == 40
		and party.get_hero(1).get("block") == 0,
		"After Beat 2, Warden in slot 1 must have 40 HP and 0 Block."
	)
	_check(
		party.get_hero(2).get("id") == "tinker"
		and party.get_hero(2).get("name") == "Tinker"
		and party.get_hero(2).get("position") == 2
		and party.get_hero(2).get("hp") == 23
		and party.get_hero(2).get("max_hp") == 26
		and party.get_hero(2).get("block") == 0,
		"After Beat 2, Tinker in slot 2 must take 3 damage (26 -> 23 HP) and have 0 Block."
	)
	_check(
		party.get_hero(3).get("id") == "seamstress"
		and party.get_hero(3).get("name") == "Seamstress"
		and party.get_hero(3).get("position") == 3
		and party.get_hero(3).get("hp") == 26
		and party.get_hero(3).get("max_hp") == 30
		and party.get_hero(3).get("block") == 0,
		"After Beat 2, Seamstress in slot 3 must remain at 26 HP and 0 Block."
	)
	_check(
		enemies.get_enemy(1).get("id") == "seam_ripper"
		and enemies.get_enemy(1).get("hp") == 18
		and enemies.get_enemy(1).get("block") == 0,
		"After Beat 2, Seam Ripper in slot 1 must have 18 HP and 0 Block."
	)
	_check(
		enemies.get_enemy(2).get("id") == "fray_scavenger"
		and enemies.get_enemy(2).get("hp") == 14
		and enemies.get_enemy(2).get("block") == 3,
		"After Beat 2, Fray Scavenger in slot 2 must have 14 HP and 3 Block."
	)

	# Advance intents and call start_player_turn before Beat 3.
	_check(intents.advance_turn(), "Advancing intents from Beat 2 to Beat 3 must succeed.")
	_check(party.start_player_turn(), "CombatParty.start_player_turn() before Beat 3 must succeed.")
	_check(
		enemies.get_enemy(2).get("block") == 3,
		"Fray Scavenger's 3 Block must persist across party.start_player_turn()."
	)

	var beat_3_announced := intents.get_intents()
	_check(beat_3_announced == _expected_beat_3(), "Beat 3 must announce source-1 attack on slot 1 (3) and source-2 attack on slot 3 (2).")
	var beat_3_result := phase.execute_phase(party, enemies, beat_3_announced)
	var expected_beat_3_events: Array[Dictionary] = [
		{"type": "attack", "enemy_position": 1, "target_position": 1, "applied": true},
		{"type": "attack", "enemy_position": 2, "target_position": 3, "applied": true},
	]
	_check(
		beat_3_result == {"ok": true, "events": expected_beat_3_events},
		"Beat 3 execute_phase must return applied front and rear attack events."
	)
	_check(
		party.get_hero(1).get("id") == "warden"
		and party.get_hero(1).get("position") == 1
		and party.get_hero(1).get("hp") == 37
		and party.get_hero(1).get("max_hp") == 40
		and party.get_hero(1).get("block") == 0,
		"After Beat 3, Warden in slot 1 must take 3 HP damage (40 -> 37 HP after Block reset)."
	)
	_check(
		party.get_hero(2).get("id") == "tinker"
		and party.get_hero(2).get("position") == 2
		and party.get_hero(2).get("hp") == 23
		and party.get_hero(2).get("max_hp") == 26
		and party.get_hero(2).get("block") == 0,
		"After Beat 3, Tinker in slot 2 must remain at 23 HP and 0 Block."
	)
	_check(
		party.get_hero(3).get("id") == "seamstress"
		and party.get_hero(3).get("position") == 3
		and party.get_hero(3).get("hp") == 24
		and party.get_hero(3).get("max_hp") == 30
		and party.get_hero(3).get("block") == 0,
		"After Beat 3, Seamstress in slot 3 must take 2 HP damage (26 -> 24 HP)."
	)
	_check(
		enemies.get_enemy(1).get("id") == "seam_ripper"
		and enemies.get_enemy(1).get("hp") == 18
		and enemies.get_enemy(1).get("block") == 0
		and enemies.get_enemy(2).get("id") == "fray_scavenger"
		and enemies.get_enemy(2).get("hp") == 14
		and enemies.get_enemy(2).get("block") == 3,
		"After Beat 3, Fray Scavenger's 3 Block must persist with both enemies at full HP."
	)

	# Fourth-beat wraparound announcement and execution: shoves then-slot-2 Tinker back to slot 3
	# (moving Seamstress from 3 back to 2) so the rear strike hits Tinker (23 -> 19 HP).
	_check(intents.advance_turn(), "Advancing intents from Beat 3 to Beat 4 wrap must succeed.")
	var beat_4_announced := intents.get_intents()
	_check(beat_4_announced == _expected_beat_1(), "Fourth beat must wrap back to exact Beat 1 announced intents.")
	_check(party.start_player_turn(), "CombatParty.start_player_turn() before Beat 4 must succeed.")
	var beat_4_result := phase.execute_phase(party, enemies, beat_4_announced)
	_check(
		beat_4_result == {"ok": true, "events": expected_beat_1_events},
		"Beat 4 wraparound execute_phase must apply shove and rear attack."
	)
	_check(
		party.get_hero(1).get("id") == "warden"
		and party.get_hero(1).get("position") == 1
		and party.get_hero(1).get("hp") == 37
		and party.get_hero(2).get("id") == "seamstress"
		and party.get_hero(2).get("position") == 2
		and party.get_hero(2).get("hp") == 24
		and party.get_hero(3).get("id") == "tinker"
		and party.get_hero(3).get("position") == 3
		and party.get_hero(3).get("hp") == 19,
		"Beat 4 wraparound must shove Seamstress back to slot 2 (24 HP) and Tinker back to slot 3 before hitting Tinker for 4 (23 -> 19 HP)."
	)


func _verify_ac4_slain_skip_and_downed_atomic_rejection(hero_catalog: Array) -> void:
	# 1. Prove global RNG probe detects an extra draw, then verify phase resolution consumes zero global RNG.
	var rng_seed := 246813579
	seed(rng_seed)
	var expected_global_draw := randi()
	seed(rng_seed)
	var _injected_draw := randi()
	_check(randi() != expected_global_draw, "Global RNG probe must detect an injected randi() draw.")

	var definitions := RunFightEncounterSelection._parse_schedule_text(_read_text(ENCOUNTER_PATH))
	var beat_1_intents := CombatEnemyIntents.new(definitions).get_intents()

	# 2. Slain source 1 (Seam Ripper, 18 HP) before Beat 1:
	# shove is skipped (applied=false) and surviving Fray Scavenger hits still-slot-3 Tinker for 4 (26 -> 22).
	var slain_first_party := _build_catalog_party(hero_catalog)
	var slain_first_enemies := _assemble_local_enemies()
	_check(CombatStartingBlock.new(slain_first_party).apply(), "Opening Block must apply for slain-source-1 fixture.")
	_check(slain_first_enemies.apply_damage(1, 18), "Slaying Seam Ripper (18 HP) at slot 1 must succeed.")
	_check(slain_first_enemies.is_slain(1) and not slain_first_enemies.is_slain(2), "Only enemy slot 1 must be slain.")

	seed(rng_seed)
	var slain_first_res := CombatEnemyPhase.new().execute_phase(
		slain_first_party, slain_first_enemies, beat_1_intents
	)
	_check(randi() == expected_global_draw, "Slain-source-1 phase execution must consume zero global RNG.")
	var expected_slain_first_events: Array[Dictionary] = [
		{"type": "shove", "enemy_position": 1, "target_position": 2, "direction": 1, "applied": false},
		{"type": "attack", "enemy_position": 2, "target_position": 3, "applied": true},
	]
	_check(
		slain_first_res == {"ok": true, "events": expected_slain_first_events},
		"When source 1 Seam Ripper is slain, Beat 1 must skip shove (applied=false) and apply source 2 attack (applied=true)."
	)
	_check(
		slain_first_party.get_hero(1).get("id") == "warden"
		and slain_first_party.get_hero(1).get("position") == 1
		and slain_first_party.get_hero(1).get("hp") == 40
		and slain_first_party.get_hero(1).get("block") == 6,
		"With source 1 slain, Warden in slot 1 must remain at 40 HP and 6 Block."
	)
	_check(
		slain_first_party.get_hero(2).get("id") == "seamstress"
		and slain_first_party.get_hero(2).get("position") == 2
		and slain_first_party.get_hero(2).get("hp") == 30
		and slain_first_party.get_hero(2).get("block") == 0,
		"With source 1 slain, Seamstress must remain unswapped in slot 2 at 30 HP and 0 Block."
	)
	_check(
		slain_first_party.get_hero(3).get("id") == "tinker"
		and slain_first_party.get_hero(3).get("position") == 3
		and slain_first_party.get_hero(3).get("hp") == 22
		and slain_first_party.get_hero(3).get("block") == 0,
		"With source 1 slain, Fray Scavenger must hit still-slot-3 Tinker for 4 (26 -> 22 HP)."
	)
	_check(
		slain_first_enemies.get_enemy(1).get("hp") == 0
		and slain_first_enemies.get_enemy(1).get("block") == 0
		and slain_first_enemies.get_enemy(2).get("hp") == 14
		and slain_first_enemies.get_enemy(2).get("block") == 0,
		"With source 1 slain, enemy HP/Block must remain 0/0 and 14/0."
	)

	# 3. Slain source 2 (Fray Scavenger, 14 HP) before Beat 1:
	# source 1 shove applies (applied=true), moving Seamstress to slot 3 unharmed, while source 2 attack is skipped (applied=false).
	var slain_second_party := _build_catalog_party(hero_catalog)
	var slain_second_enemies := _assemble_local_enemies()
	_check(CombatStartingBlock.new(slain_second_party).apply(), "Opening Block must apply for slain-source-2 fixture.")
	_check(slain_second_enemies.apply_damage(2, 14), "Slaying Fray Scavenger (14 HP) at slot 2 must succeed.")
	var slain_second_res := CombatEnemyPhase.new().execute_phase(
		slain_second_party, slain_second_enemies, beat_1_intents
	)
	var expected_slain_second_events: Array[Dictionary] = [
		{"type": "shove", "enemy_position": 1, "target_position": 2, "direction": 1, "applied": true},
		{"type": "attack", "enemy_position": 2, "target_position": 3, "applied": false},
	]
	_check(
		slain_second_res == {"ok": true, "events": expected_slain_second_events},
		"When source 2 Fray Scavenger is slain, Beat 1 must apply source 1 shove and skip source 2 attack."
	)
	_check(
		slain_second_party.get_hero(2).get("id") == "tinker"
		and slain_second_party.get_hero(2).get("hp") == 26
		and slain_second_party.get_hero(3).get("id") == "seamstress"
		and slain_second_party.get_hero(3).get("hp") == 30,
		"When source 2 is slain, Seamstress is shoved to slot 3 unharmed (30 HP) and Tinker moves to slot 2 (26 HP)."
	)

	# 4. Downed slot-2 Seamstress (mover in 2->3 shove): atomic phase rejection with party/enemy state unchanged.
	var downed_slot_2_party := _build_catalog_party(hero_catalog)
	var downed_slot_2_enemies := _assemble_local_enemies()
	_check(CombatStartingBlock.new(downed_slot_2_party).apply(), "Opening Block must apply before downing slot 2.")
	_check(downed_slot_2_party.apply_damage(2, 30), "Damaging Seamstress in slot 2 for 30 must succeed.")
	_check(downed_slot_2_party.is_downed(2), "Seamstress in slot 2 must be downed at 0 HP.")
	var heroes_before_downed_2 := downed_slot_2_party.get_heroes()
	var enemies_before_downed_2 := downed_slot_2_enemies.get_enemies()
	var intents_for_downed_2 := CombatEnemyIntents.new(definitions)
	var intents_snapshot_2 := intents_for_downed_2.get_intents()
	seed(rng_seed)
	var downed_slot_2_res := CombatEnemyPhase.new().execute_phase(
		downed_slot_2_party, downed_slot_2_enemies, intents_snapshot_2
	)
	_check(randi() == expected_global_draw, "Rejected phase with downed slot 2 must consume zero global RNG.")
	_check(
		downed_slot_2_res == {"ok": false, "events": []},
		"Beat 1 with downed slot-2 Seamstress must fail closed with empty events."
	)
	_check(
		downed_slot_2_party.get_heroes() == heroes_before_downed_2,
		"Rejected phase with downed slot 2 must leave party state byte-for-byte unchanged."
	)
	_check(
		downed_slot_2_enemies.get_enemies() == enemies_before_downed_2,
		"Rejected phase with downed slot 2 must leave enemy state byte-for-byte unchanged."
	)
	_check(
		intents_for_downed_2.get_intents() == _expected_beat_1() and intents_for_downed_2._turn_index == 0,
		"Rejected phase with downed slot 2 must leave CombatEnemyIntents unchanged."
	)

	# 5. Downed slot-3 Tinker (destination in 2->3 shove): atomic phase rejection with party/enemy state unchanged.
	var downed_slot_3_party := _build_catalog_party(hero_catalog)
	var downed_slot_3_enemies := _assemble_local_enemies()
	_check(CombatStartingBlock.new(downed_slot_3_party).apply(), "Opening Block must apply before downing slot 3.")
	_check(downed_slot_3_party.apply_damage(3, 26), "Damaging Tinker in slot 3 for 26 must succeed.")
	_check(downed_slot_3_party.is_downed(3), "Tinker in slot 3 must be downed at 0 HP.")
	var heroes_before_downed_3 := downed_slot_3_party.get_heroes()
	var enemies_before_downed_3 := downed_slot_3_enemies.get_enemies()
	seed(rng_seed)
	var downed_slot_3_res := CombatEnemyPhase.new().execute_phase(
		downed_slot_3_party, downed_slot_3_enemies, beat_1_intents
	)
	_check(randi() == expected_global_draw, "Rejected phase with downed slot 3 must consume zero global RNG.")
	_check(
		downed_slot_3_res == {"ok": false, "events": []},
		"Beat 1 with downed slot-3 Tinker must fail closed with empty events."
	)
	_check(
		downed_slot_3_party.get_heroes() == heroes_before_downed_3,
		"Rejected phase with downed slot 3 must leave party state byte-for-byte unchanged."
	)
	_check(
		downed_slot_3_enemies.get_enemies() == enemies_before_downed_3,
		"Rejected phase with downed slot 3 must leave enemy state byte-for-byte unchanged."
	)

	# 6. Control: when slot-1 Warden (non-participant in 2<->3 shove) is downed on Beat 1,
	# the 2<->3 shove and rear attack still succeed, proving rejection above is specific to shove participants.
	var downed_slot_1_party := _build_catalog_party(hero_catalog)
	var downed_slot_1_enemies := _assemble_local_enemies()
	_check(CombatStartingBlock.new(downed_slot_1_party).apply(), "Opening Block must apply before downing slot 1.")
	_check(downed_slot_1_party.apply_damage(1, 46), "Damaging Warden for 46 (6 Block + 40 HP) must down slot 1.")
	_check(downed_slot_1_party.is_downed(1), "Warden in slot 1 must be downed.")
	var downed_slot_1_res := CombatEnemyPhase.new().execute_phase(
		downed_slot_1_party, downed_slot_1_enemies, beat_1_intents
	)
	_check(
		downed_slot_1_res.get("ok") == true
		and downed_slot_1_party.get_hero(1).get("id") == "warden"
		and downed_slot_1_party.get_hero(1).get("hp") == 0
		and downed_slot_1_party.get_hero(2).get("id") == "tinker"
		and downed_slot_1_party.get_hero(2).get("hp") == 26
		and downed_slot_1_party.get_hero(3).get("id") == "seamstress"
		and downed_slot_1_party.get_hero(3).get("hp") == 26,
		"Control: when non-participant slot-1 Warden is downed, Beat 1 2<->3 shove and rear attack succeed."
	)

	# 7. Atomic rollback when source 1 stages a real state change (buff/attack) and source 2 fails on a downed shove participant.
	var rollback_party := _build_catalog_party(hero_catalog)
	var rollback_enemies := _assemble_local_enemies()
	_check(CombatStartingBlock.new(rollback_party).apply(), "Opening Block must apply for later-source rollback fixture.")
	_check(rollback_party.apply_damage(3, 26), "Downing slot-3 Tinker for later-source rollback fixture must succeed.")
	var rollback_heroes_before := rollback_party.get_heroes()
	var rollback_enemies_before := rollback_enemies.get_enemies()
	var later_fail_intents: Array[Dictionary] = [
		{"type": "attack", "amount": 4, "target_position": 1, "enemy_position": 1},
		{"type": "shove", "amount": 0, "target_position": 2, "direction": 1, "enemy_position": 2},
	]
	var rollback_res := CombatEnemyPhase.new().execute_phase(
		rollback_party, rollback_enemies, later_fail_intents
	)
	_check(
		rollback_res == {"ok": false, "events": []},
		"Later-source illegal shove after source-1 staged attack must reject the entire phase."
	)
	_check(
		rollback_party.get_heroes() == rollback_heroes_before
		and rollback_enemies.get_enemies() == rollback_enemies_before,
		"Later-source failure must roll back source 1's staged damage on Warden's Block."
	)


func _opening_fight(map: RunMap) -> String:
	for id in map.get_legal_choices():
		if map.get_node(id).get("type") == "Fight":
			return id
	return ""


func _selector_snapshot(map: RunMap, rng: RandomNumberGenerator, selector: RunFightEncounterSelection) -> Dictionary:
	return {
		"floors": map.get_floors(),
		"route": map.get_route(),
		"current": map.get_current_node_id(),
		"choices": map.get_legal_choices(),
		"floor": map.get_current_floor(),
		"rng_state": rng.state,
		"cache": selector._selected.duplicate(true),
		"bound": selector._bound_map,
	}


func _assert_battle_rejected(
	map: RunMap,
	rng: RandomNumberGenerator,
	selector: RunFightEncounterSelection,
	pools_by_type: Dictionary,
	label: String,
	supplied_rng: RandomNumberGenerator = null
) -> void:
	var before := _selector_snapshot(map, rng, selector)
	var global_seed := 864209753
	seed(global_seed)
	var expected_global := randi()
	seed(global_seed)
	var answer := selector.select_current_battle(map, supplied_rng, pools_by_type)
	_check(randi() == expected_global, "%s: rejected select_current_battle must not draw global RNG." % label)
	_check(answer == {"success": false}, "%s: select_current_battle must reject with {success: false}." % label)
	_check(_selector_snapshot(map, rng, selector) == before, "%s: rejected select_current_battle must not mutate map, RNG, or selector cache." % label)


func _execute_full_seeded_run_and_combat(seed_value: int, hero_catalog: Array) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var map := RunMap.new()
	var generated := map.generate(rng)
	var opening_id := _opening_fight(map)
	var chosen := map.choose_node(opening_id)
	var rng_before_select := rng.state
	var selector := RunFightEncounterSelection.new()
	var choice := selector.select_current_battle(map, rng, LOCAL_POOLS_BY_TYPE.duplicate(true))
	var rng_after_select := rng.state
	var assembled := RunTypedBattleRoster.new().assemble(
		choice, LOCAL_ROSTER_MAP.duplicate(true), [ENEMY_CATALOG_PATH]
	)
	var party := _build_catalog_party(hero_catalog)
	var enemies: CombatEnemies = assembled.get("enemies")
	var starting_block_ok := CombatStartingBlock.new(party).apply()
	var intents := CombatEnemyIntents.new(assembled.get("definitions", []))
	var phase := CombatEnemyPhase.new()
	var beats: Array[Dictionary] = []
	for beat_index in range(4):
		if beat_index > 0:
			party.start_player_turn()
		var announced := intents.get_intents()
		var res := phase.execute_phase(party, enemies, announced)
		var advanced := intents.advance_turn()
		beats.append({
			"announced": announced,
			"result": res,
			"advanced": advanced,
			"heroes": party.get_heroes(),
			"enemies": enemies.get_enemies(),
			"rng_state": rng.state,
		})
	return {
		"generated": generated,
		"opening_id": opening_id,
		"chosen": chosen,
		"rng_before_select": rng_before_select,
		"rng_after_select": rng_after_select,
		"choice": choice,
		"assembled_ok": assembled.get("ok", false),
		"starting_block_ok": starting_block_ok,
		"beats": beats,
		"final_rng_state": rng.state,
		"next_rng_draw": rng.randi(),
	}


func _verify_ac5_typed_selection_caching_replay_and_rejections(hero_catalog: Array) -> void:
	var seed_value := 20261022
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var oracle_rng := RandomNumberGenerator.new()
	oracle_rng.seed = seed_value

	var map := RunMap.new()
	var oracle_map := RunMap.new()
	var selector := RunFightEncounterSelection.new()

	# 1. Rejections before map generation and before choosing a node.
	_assert_battle_rejected(map, rng, selector, LOCAL_POOLS_BY_TYPE.duplicate(true), "ungenerated map", rng)
	_check(map.generate(rng) and oracle_map.generate(oracle_rng), "Seeded RunMap and oracle map must generate.")
	var opening_id := _opening_fight(map)
	_check(not opening_id.is_empty(), "Generated RunMap must offer a legal opening Fight node.")
	_assert_battle_rejected(map, rng, selector, LOCAL_POOLS_BY_TYPE.duplicate(true), "unchosen legal Fight node", rng)

	# 2. Choose the legal opening Fight node, then test invalid candidate/input rejections before valid selection.
	_check(map.choose_node(opening_id) and oracle_map.choose_node(opening_id), "Choosing legal opening Fight node must succeed.")
	_check(
		map.get_current_node_id() == opening_id
		and map.get_current_floor() == 1
		and map.get_node(opening_id).get("type") == "Fight",
		"Current node must be the chosen floor-1 Fight."
	)

	_assert_battle_rejected(map, rng, selector, LOCAL_POOLS_BY_TYPE.duplicate(true), "null RNG", null)
	_assert_battle_rejected(map, rng, selector, {}, "empty pools_by_type", rng)
	_assert_battle_rejected(map, rng, selector, {"Elite": LOCAL_FIGHT_POOL.duplicate(true)}, "missing Fight pool key", rng)
	_assert_battle_rejected(map, rng, selector, {"Fight": {}}, "empty Fight candidate pool", rng)
	_assert_battle_rejected(
		map, rng, selector,
		{"Fight": {"absent": "res://data/encounters/no_such_ripper_schedule.json"}},
		"missing encounter file", rng
	)
	_assert_battle_rejected(
		map, rng, selector,
		{"Fight": {"bad_dir": "res://data/enemies/run_enemies.json"}},
		"out-of-directory JSON candidate", rng
	)
	_assert_battle_rejected(
		map, rng, selector,
		{"Fight": {"traversal": "res://data/encounters/../encounters/ripper_switchstrike.json"}},
		"noncanonical path traversal candidate", rng
	)
	_assert_battle_rejected(
		map, rng, selector,
		{"Fight": {"": ENCOUNTER_PATH}},
		"empty encounter ID candidate", rng
	)
	_assert_battle_rejected(
		map, rng, selector,
		{"Fight": {ENCOUNTER_ID: null}},
		"null path candidate", rng
	)
	_assert_battle_rejected(
		map, rng, selector,
		{"Fight": {ENCOUNTER_ID: ENCOUNTER_PATH, "broken": "res://data/encounters/missing_second.json"}},
		"mixed valid and invalid candidate pool", rng
	)

	# 3. Valid selection on the chosen Fight node consumes exactly one sorted-pool RNG draw and caches the choice.
	var _oracle_draw := oracle_rng.randi_range(0, 0)
	var expected_rng_after_one_draw := oracle_rng.state

	var global_seed := 975318642
	seed(global_seed)
	var expected_global := randi()
	seed(global_seed)
	var choice := selector.select_current_battle(map, rng, LOCAL_POOLS_BY_TYPE.duplicate(true))
	_check(randi() == expected_global, "Valid select_current_battle must not draw global RNG.")
	var expected_choice := {
		"success": true,
		"node_type": "Fight",
		"encounter_id": ENCOUNTER_ID,
		"definitions": _expected_definitions(),
	}
	_check(choice == expected_choice, "select_current_battle must return the exact typed ripper_switchstrike choice.")
	_check(rng.state == expected_rng_after_one_draw, "select_current_battle must consume exactly one run_rng draw.")
	_check(map.get_current_node_id() == opening_id and map.get_route() == [opening_id], "select_current_battle must not advance or alter map route.")

	# 4. Assemble the selected typed choice with local roster map and verify enemies.
	var assembled := RunTypedBattleRoster.new().assemble(
		choice, LOCAL_ROSTER_MAP.duplicate(true), [ENEMY_CATALOG_PATH]
	)
	_check(
		assembled.get("ok") == true
		and assembled.get("node_type") == "Fight"
		and assembled.get("encounter_id") == ENCOUNTER_ID
		and assembled.get("definitions") == _expected_definitions(),
		"RunTypedBattleRoster.assemble on selector output must succeed and preserve definitions."
	)
	var assembled_enemies: CombatEnemies = assembled.get("enemies")
	_check(
		assembled_enemies != null
		and assembled_enemies.is_valid()
		and assembled_enemies.get_enemy(1).get("id") == "seam_ripper"
		and assembled_enemies.get_enemy(1).get("hp") == 18
		and assembled_enemies.get_enemy(2).get("id") == "fray_scavenger"
		and assembled_enemies.get_enemy(2).get("hp") == 14,
		"Assembled enemies from selector output must be slot 1 Seam Ripper (18 HP) and slot 2 Fray Scavenger (14 HP)."
	)

	# 5. Cached same-node replay and deep-copy isolation across both select_current_battle and select_current_fight.
	choice["encounter_id"] = "mutated_id"
	choice["definitions"][0]["pattern"][0]["amount"] = 777
	choice["definitions"].clear()

	seed(global_seed)
	var cached_battle := selector.select_current_battle(map, rng, {"Fight": {}})
	_check(randi() == expected_global, "Cached select_current_battle must not draw global RNG.")
	_check(cached_battle == expected_choice, "Cached select_current_battle must return unmutated deep copy even with empty pool.")
	_check(rng.state == expected_rng_after_one_draw, "Cached select_current_battle must consume zero run_rng draws.")

	var cached_fight := selector.select_current_fight(map, rng, {})
	var expected_legacy_choice := {
		"success": true,
		"encounter_id": ENCOUNTER_ID,
		"definitions": _expected_definitions(),
	}
	_check(cached_fight == expected_legacy_choice, "Cached select_current_fight must share the node cache and omit node_type.")
	_check(rng.state == expected_rng_after_one_draw, "Cached select_current_fight must consume zero run_rng draws.")

	# 6. Traverse the map to exercise wrong-kind node rejection (non-Fight / Boss) while preserving cached Fight entry.
	var saw_non_fight := false
	for _floor_step in range(2, 13):
		var legal := map.get_legal_choices()
		if legal.is_empty():
			break
		var picked: String = legal[0]
		for candidate_id in legal:
			if map.get_node(candidate_id).get("type") != "Fight":
				picked = candidate_id
				break
		_check(map.choose_node(picked), "Advancing along legal route choice %s must succeed." % picked)
		var node_kind: String = map.get_node(picked).get("type", "")
		if node_kind != "Fight":
			saw_non_fight = true
			var before_wrong_kind := _selector_snapshot(map, rng, selector)
			var fight_reject := selector.select_current_fight(map, rng, LOCAL_FIGHT_POOL.duplicate(true))
			_check(fight_reject == {"success": false}, "select_current_fight must reject chosen non-Fight node (%s)." % node_kind)
			_check(_selector_snapshot(map, rng, selector) == before_wrong_kind, "Rejected select_current_fight on %s must not mutate state." % node_kind)
			# select_current_battle with only a Fight pool must also reject any non-Fight node (including Elite/Boss/Rest/Shop/Event/Treasure).
			_assert_battle_rejected(map, rng, selector, LOCAL_POOLS_BY_TYPE.duplicate(true), "non-Fight node %s with Fight-only pool" % node_kind, rng)
	_check(saw_non_fight, "Route traversal must encounter at least one non-Fight node (such as floor 12 Boss).")
	_check(selector._selected.get(opening_id) == expected_choice, "Rejecting later non-Fight nodes must preserve the cached opening Fight selection.")

	# 7. Negative checks for parser, CombatEnemyIntents, and RunTypedBattleRoster.assemble.
	var invalid_schedule_texts: Array[Dictionary] = [
		{
			"label": "duplicate enemy_position 1",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "shove", "amount": 0, "target_position": 2, "direction": 1}]}, {"enemy_position": 1, "pattern": [{"type": "attack", "amount": 4, "target_position": 3}]}]',
		},
		{
			"label": "out-of-bounds backward shove from slot 3 (3 + 1 = 4)",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "shove", "amount": 0, "target_position": 3, "direction": 1}]}]',
		},
		{
			"label": "out-of-bounds forward shove from slot 1 (1 + -1 = 0)",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "shove", "amount": 0, "target_position": 1, "direction": -1}]}]',
		},
		{
			"label": "nonzero shove amount",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "shove", "amount": 2, "target_position": 2, "direction": 1}]}]',
		},
		{
			"label": "fractional attack amount 3.5",
			"json": '[{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 3.5, "target_position": 2}]}]',
		},
		{
			"label": "zero buff amount",
			"json": '[{"enemy_position": 2, "pattern": [{"type": "buff", "amount": 0}]}]',
		},
	]
	for bad_case in invalid_schedule_texts:
		_check(
			RunFightEncounterSelection._parse_schedule_text(bad_case["json"]).is_empty(),
			"RunFightEncounterSelection._parse_schedule_text must reject %s." % bad_case["label"]
		)

	var valid_choice := expected_choice.duplicate(true)
	var roster_Assembler := RunTypedBattleRoster.new()
	_check(
		roster_Assembler.assemble(valid_choice, {ENCOUNTER_ID: ["seam_ripper"]}, [ENEMY_CATALOG_PATH]) == {"ok": false},
		"RunTypedBattleRoster.assemble must reject 1-enemy roster for 2-source schedule."
	)
	_check(
		roster_Assembler.assemble(valid_choice, {ENCOUNTER_ID: ["seam_ripper", "seam_ripper"]}, [ENEMY_CATALOG_PATH]) == {"ok": false},
		"RunTypedBattleRoster.assemble must reject duplicate enemy IDs in roster."
	)
	_check(
		roster_Assembler.assemble(valid_choice, {ENCOUNTER_ID: ["seam_ripper", "unknown_enemy"]}, [ENEMY_CATALOG_PATH]) == {"ok": false},
		"RunTypedBattleRoster.assemble must reject unknown enemy ID."
	)

	# 8. Same-seed fresh-run determinism across map generation, typed selection, roster assembly, and 4 combat beats.
	var run_a := _execute_full_seeded_run_and_combat(20261022, hero_catalog)
	var run_b := _execute_full_seeded_run_and_combat(20261022, hero_catalog)
	_check(run_a == run_b, "Two independent same-seed runs must produce identical selection, roster, combat state transitions, and RNG states.")
	_check(
		run_a["rng_after_select"] == run_a["final_rng_state"],
		"Combat roster assembly, starting Block, intent cycling, and 4 enemy phases must consume zero run_rng draws after selection."
	)


func _verify_companion_schedules_unmodified() -> void:
	var starter_defs := RunFightEncounterSelection._parse_schedule_text(_read_text(STARTER_ATTACKS_PATH))
	_check(starter_defs.size() == 2, "starter_attacks.json must still parse into 2 source definitions.")
	var starter_s1 := _find_unique_by_key(starter_defs, "enemy_position", 1, STARTER_ATTACKS_PATH)
	var starter_s2 := _find_unique_by_key(starter_defs, "enemy_position", 2, STARTER_ATTACKS_PATH)
	var expected_starter_s1: Array = [
		{"type": "attack", "amount": 1, "target_position": 1},
		{"type": "attack", "amount": 1, "target_position": 2},
		{"type": "attack", "amount": 1, "target_position": 3},
	]
	var expected_starter_s2: Array = [
		{"type": "block", "amount": 1},
	]
	_check(starter_s1.get("pattern") == expected_starter_s1, "starter_attacks.json source 1 pattern must remain unchanged.")
	_check(starter_s2.get("pattern") == expected_starter_s2, "starter_attacks.json source 2 pattern must remain unchanged.")

	var seamward_defs := RunFightEncounterSelection._parse_schedule_text(_read_text(SEAMWARD_TURNABOUT_PATH))
	_check(seamward_defs.size() == 2, "seamward_turnabout.json must still parse into 2 source definitions.")
	var seamward_s1 := _find_unique_by_key(seamward_defs, "enemy_position", 1, SEAMWARD_TURNABOUT_PATH)
	var seamward_s2 := _find_unique_by_key(seamward_defs, "enemy_position", 2, SEAMWARD_TURNABOUT_PATH)
	var expected_seamward_s1: Array = [
		{"type": "shove", "amount": 0, "target_position": 2, "direction": -1},
		{"type": "attack", "amount": 3, "target_position": 1},
		{"type": "block", "amount": 2},
	]
	var expected_seamward_s2: Array = [
		{"type": "attack", "amount": 4, "target_position": 1},
		{"type": "buff", "amount": 3},
		{"type": "attack", "amount": 3, "target_position": 3},
	]
	_check(seamward_s1.get("pattern") == expected_seamward_s1, "seamward_turnabout.json source 1 pattern must remain unchanged.")
	_check(seamward_s2.get("pattern") == expected_seamward_s2, "seamward_turnabout.json source 2 pattern must remain unchanged.")
