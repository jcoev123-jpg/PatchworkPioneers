extends SceneTree

## Deterministic headless coverage for the authored Frayneedle Rear Mark encounter:
## enemy_position 1 Fray Scavenger debuffs Tinker with Exposed on beat 1 before
## enemy_position 2 Spool Stalker strikes Tinker for 4 * 1.5 = 6 damage.
## On beat 2, Warden takes 3 damage and Seamstress receives Weak 1.
## On beat 3, Fray Scavenger gains 2 Block and Warden takes 3 damage.
## On beat 4, both enemies attack Seamstress for 3 damage each.
## The fifth beat loops back to beat 1.
## Standalone encounter content only; no live Fight-pool registration or UI wiring here.

const ENCOUNTER_PATH := "res://data/encounters/frayneedle_rear_mark.json"
const ENCOUNTER_ID := "frayneedle_rear_mark"
const FRAYMARK_FOCUS_PATH := "res://data/encounters/fraymark_focus.json"
const ENEMY_CATALOG_PATH := "res://data/enemies/run_enemies.json"
const HERO_CATALOG_PATH := "res://data/heroes/starter_party.json"
const FIXED_SEED := 20261022

const LOCAL_ROSTER_MAP := {
	ENCOUNTER_ID: ["fray_scavenger", "spool_stalker"]
}

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_ac1_schedule_parsing_and_assembly()
	_test_ac2_combat_phase_sequence_and_replay()
	_test_ac3_slain_source_and_rejections()
	if failures.is_empty():
		print("frayneedle_rear_mark_encounter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("frayneedle_rear_mark_encounter_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "file must open: " + path)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _normalize(data: Variant) -> Variant:
	if data is Array:
		var result: Array = []
		for item in data:
			result.append(_normalize(item))
		return result
	if data is Dictionary:
		var result: Dictionary = {}
		for key in data:
			result[key] = _normalize(data[key])
		return result
	if data is float and is_finite(data) and floorf(data) == data:
		return int(data)
	return data


func _load_catalog(path: String) -> Array:
	var text := _read_text(path)
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Array:
		_check(false, "catalog must be a JSON Array: " + path)
		return []
	return _normalize(parsed)


func _record_by_id(records: Array, id: String) -> Dictionary:
	var matches: Array = []
	for record in records:
		if record is Dictionary and record.get("id") == id:
			matches.append(record)
	_check(matches.size() == 1, "catalog has exactly one record named " + id)
	return matches[0].duplicate(true) if matches.size() == 1 else {}


func _all_numeric_leaves_integral(value: Variant) -> bool:
	if value is float:
		return not is_nan(value) and not is_inf(value) \
			and absf(value) <= 9007199254740991.0 and floorf(value) == value
	if value is Array:
		for item in value:
			if not _all_numeric_leaves_integral(item):
				return false
		return true
	if value is Dictionary:
		for key in value:
			if not _all_numeric_leaves_integral(value[key]):
				return false
		return true
	return true


func _count_numeric_leaves(value: Variant) -> int:
	if value is float or value is int:
		return 1
	var total := 0
	if value is Array:
		for item in value:
			total += _count_numeric_leaves(item)
		return total
	if value is Dictionary:
		for key in value:
			total += _count_numeric_leaves(value[key])
	return total


func _expected_definitions() -> Array:
	return [
		{
			"enemy_position": 1,
			"pattern": [
				{"type": "debuff", "amount": 1, "target_position": 3, "status": "exposed"},
				{"type": "attack", "amount": 3, "target_position": 1},
				{"type": "block", "amount": 2},
				{"type": "attack", "amount": 3, "target_position": 2}
			]
		},
		{
			"enemy_position": 2,
			"pattern": [
				{"type": "attack", "amount": 4, "target_position": 3},
				{"type": "debuff", "amount": 1, "target_position": 2, "status": "weak"},
				{"type": "attack", "amount": 3, "target_position": 1},
				{"type": "attack", "amount": 3, "target_position": 2}
			]
		}
	]


func _expected_beat(beat_index: int) -> Array:
	var actions: Array = []
	for definition in _expected_definitions():
		var pattern: Array = definition["pattern"]
		var action: Dictionary = pattern[beat_index % pattern.size()].duplicate(true)
		action["enemy_position"] = definition["enemy_position"]
		actions.append(action)
	return actions


func _expected_events(beat_index: int, slain_slot: int = 0) -> Array:
	var events: Array = []
	for intent in _expected_beat(beat_index):
		var pos: int = intent["enemy_position"]
		var applied: bool = (pos != slain_slot)
		var event := {
			"type": intent["type"],
			"enemy_position": pos,
			"applied": applied
		}
		for field in ["target_position", "status", "direction"]:
			if intent.has(field):
				event[field] = intent[field]
		events.append(event)
	return events


func _build_party() -> CombatParty:
	var heroes := _load_catalog(HERO_CATALOG_PATH)
	var definitions: Array = []
	for id in ["warden", "seamstress", "tinker"]:
		definitions.append(_record_by_id(heroes, id))
	var party := CombatParty.new(definitions)
	_check(party.is_valid(), "starter party builds a valid 3-hero CombatParty")
	var starter_block := CombatStartingBlock.new(party)
	_check(starter_block.apply(), "CombatStartingBlock applies once at combat start")
	_check(not starter_block.apply(), "CombatStartingBlock does not apply a second time")
	_check(party.get_hero(1).get("block") == 6, "Warden starts with 6 Block")
	_check(party.get_hero(2).get("block") == 0, "Seamstress starts with 0 Block")
	_check(party.get_hero(3).get("block") == 0, "Tinker starts with 0 Block")
	_check(party.get_hero(1).get("hp") == 40, "Warden starts with 40 HP")
	_check(party.get_hero(2).get("hp") == 30, "Seamstress starts with 30 HP")
	_check(party.get_hero(3).get("hp") == 26, "Tinker starts with 26 HP")
	return party


func _assemble_roster(loaded_definitions: Array) -> Dictionary:
	var typed_choice := {
		"success": true,
		"node_type": "Fight",
		"encounter_id": ENCOUNTER_ID,
		"definitions": loaded_definitions.duplicate(true)
	}
	return RunTypedBattleRoster.new().assemble(
		typed_choice,
		{ENCOUNTER_ID: ["fray_scavenger", "spool_stalker"]},
		[ENEMY_CATALOG_PATH]
	)


## AC1: The standalone JSON parses to unique source positions 1 and 2 and their
## exact four-action cycles. CombatEnemyIntents accepts it and RunTypedBattleRoster
## assembles that roster from in-memory choice/binding. Existing fraymark_focus
## still parses.
func _test_ac1_schedule_parsing_and_assembly() -> void:
	_check(FileAccess.file_exists(ENCOUNTER_PATH), "authored schedule exists on disk")
	var raw_text := _read_text(ENCOUNTER_PATH)
	var raw_json = JSON.parse_string(raw_text)
	_check(raw_json is Array and raw_json.size() == 2, "raw file contains array of exactly 2 sources")
	_check(_all_numeric_leaves_integral(raw_json), "all numeric leaves are integral before coercion")
	_check(_count_numeric_leaves(raw_json) > 0, "schedule contains numeric fields")

	var loaded := RunFightEncounterSelection._parse_schedule_text(raw_text)
	_check(loaded == _expected_definitions(), "schedule matches exact expected definitions")
	_check(loaded.size() == 2, "schedule has 2 sources")

	var pos_1_matches: Array = []
	var pos_2_matches: Array = []
	for def in loaded:
		if def.get("enemy_position") == 1:
			pos_1_matches.append(def)
		elif def.get("enemy_position") == 2:
			pos_2_matches.append(def)
	_check(pos_1_matches.size() == 1, "exactly one source at enemy_position 1")
	_check(pos_2_matches.size() == 1, "exactly one source at enemy_position 2")

	var intents := CombatEnemyIntents.new(loaded)
	_check(intents.is_valid(), "CombatEnemyIntents accepts the loaded definitions")

	# Test mutation isolation on fetched intents (lesson 3)
	var fetched := intents.get_intents()
	_check(fetched == _expected_beat(0), "first intents match beat 1")
	fetched[0]["amount"] = 999
	fetched.append({"type": "bogus"})
	_check(intents.get_intents() == _expected_beat(0), "fetched intents mutation does not leak into intents service")

	# Assemble roster through RunTypedBattleRoster
	var assembled := _assemble_roster(loaded)
	_check(assembled.get("ok") == true, "RunTypedBattleRoster.assemble succeeds")
	_check(assembled.get("node_type") == "Fight", "assembled node_type is Fight")
	_check(assembled.get("encounter_id") == ENCOUNTER_ID, "assembled encounter_id is frayneedle_rear_mark")
	_check(assembled.get("definitions") == _expected_definitions(), "assembled definitions match expected")

	var foes: Variant = assembled.get("enemies")
	_check(foes is CombatEnemies and foes.is_valid(), "assembled enemies is a valid CombatEnemies")
	if foes is CombatEnemies:
		var enemies_list: Array = foes.get_enemies()
		_check(enemies_list.size() == 2, "roster holds exactly 2 enemies")

		var e1: Dictionary = foes.get_enemy(1)
		_check(e1.get("id") == "fray_scavenger", "slot 1 id is fray_scavenger")
		_check(e1.get("name") == "Fray Scavenger", "slot 1 name is Fray Scavenger")
		_check(e1.get("position") == 1, "slot 1 position is 1")
		_check(e1.get("max_hp") == 14, "slot 1 max_hp is 14")
		_check(e1.get("hp") == 14, "slot 1 hp is 14")
		_check(e1.get("block") == 0, "slot 1 block is 0")
		_check(e1.get("art_path") == "res://assets/paper/enemies/fray_scavenger.png", "slot 1 art_path is preserved")

		var e2: Dictionary = foes.get_enemy(2)
		_check(e2.get("id") == "spool_stalker", "slot 2 id is spool_stalker")
		_check(e2.get("name") == "Spool Stalker", "slot 2 name is Spool Stalker")
		_check(e2.get("position") == 2, "slot 2 position is 2")
		_check(e2.get("max_hp") == 14, "slot 2 max_hp is 14")
		_check(e2.get("hp") == 14, "slot 2 hp is 14")
		_check(e2.get("block") == 0, "slot 2 block is 0")
		_check(e2.get("art_path") == "res://assets/paper/enemies/spool_stalker.png", "slot 2 art_path is preserved")

	# Existing data/encounters/fraymark_focus.json remains valid and readable
	_check(FileAccess.file_exists(FRAYMARK_FOCUS_PATH), "fraymark_focus.json exists on disk")
	var fraymark_text := _read_text(FRAYMARK_FOCUS_PATH)
	var fraymark_parsed := RunFightEncounterSelection._parse_schedule_text(fraymark_text)
	_check(not fraymark_parsed.is_empty(), "fraymark_focus schedule parses successfully")
	_check(fraymark_parsed.size() == 3, "fraymark_focus has 3 sources")
	_check(CombatEnemyIntents.new(fraymark_parsed).is_valid(), "fraymark_focus intents are valid")
	_check(fraymark_parsed != loaded, "frayneedle_rear_mark is distinct from fraymark_focus")


## AC2: 4-beat combat sequence with authentic hero stats, starting block,
## source-sorted actions, status calculations, player turn block resets,
## and 5th-beat wraparound. Replay determinism with fixed seed.
func _run_fixture_four_beats() -> Dictionary:
	var loaded := RunFightEncounterSelection._parse_schedule_text(_read_text(ENCOUNTER_PATH))
	var party := _build_party()
	var assembled := _assemble_roster(loaded)
	var foes: CombatEnemies = assembled["enemies"]
	var intents := CombatEnemyIntents.new(loaded)
	var phase_runner := CombatEnemyPhase.new()

	var traces: Array[Dictionary] = []
	var hero_snapshots: Array[Array] = []
	var enemy_snapshots: Array[Array] = []

	# Beat 1:
	# slot 1 Exposed 1 on pos 3 (Tinker)
	# slot 2 Attack 4 on pos 3 (Tinker) -> 4 * 1.5 = 6 damage -> Tinker 26 to 20 HP
	# Warden starts with 40 HP and 6 Block
	var b1_intents := intents.get_intents()
	_check(b1_intents == _expected_beat(0), "beat 1 announced intents match expected")
	var b1_res := phase_runner.execute_phase(party, foes, b1_intents)
	_check(b1_res == {"ok": true, "events": _expected_events(0)}, "beat 1 phase execution ok and events match")
	_check(party.get_hero(3).get("hp") == 20, "beat 1: Tinker HP is 20 (lost 6)")
	_check(party.get_hero(3).get("statuses", {}).get("exposed", 0) == 1, "beat 1: Tinker has Exposed 1")
	_check(party.get_hero(1).get("hp") == 40, "beat 1: Warden HP is 40")
	_check(party.get_hero(1).get("block") == 6, "beat 1: Warden Block is 6")
	_check(party.get_hero(2).get("hp") == 30, "beat 1: Seamstress HP is 30")
	traces.append(b1_res)
	hero_snapshots.append(party.get_heroes())
	enemy_snapshots.append(foes.get_enemies())

	# Reset player turn block between beats (hero Block resets to 0)
	_check(intents.advance_turn(), "advance after beat 1")
	_check(party.start_player_turn(), "start player turn after beat 1")
	_check(party.get_hero(1).get("block") == 0, "Warden Block reset to 0 at start of player turn")

	# Beat 2:
	# slot 1 Attack 3 on pos 1 (Warden) -> Warden takes 3 HP (40 to 37)
	# slot 2 Debuff Weak 1 on pos 2 (Seamstress) -> Seamstress receives Weak 1
	var b2_intents := intents.get_intents()
	_check(b2_intents == _expected_beat(1), "beat 2 announced intents match expected")
	var b2_res := phase_runner.execute_phase(party, foes, b2_intents)
	_check(b2_res == {"ok": true, "events": _expected_events(1)}, "beat 2 phase execution ok and events match")
	_check(party.get_hero(1).get("hp") == 37, "beat 2: Warden takes 3 HP (40 to 37)")
	_check(party.get_hero(2).get("statuses", {}).get("weak", 0) == 1, "beat 2: Seamstress receives Weak 1")
	_check(party.get_hero(3).get("hp") == 20, "beat 2: Tinker HP remains 20")
	traces.append(b2_res)
	hero_snapshots.append(party.get_heroes())
	enemy_snapshots.append(foes.get_enemies())

	_check(intents.advance_turn(), "advance after beat 2")
	_check(party.start_player_turn(), "start player turn after beat 2")

	# Beat 3:
	# slot 1 Block 2 -> Fray Scavenger receives 2 Block
	# slot 2 Attack 3 on pos 1 (Warden) -> Warden takes 3 more HP (37 to 34)
	var b3_intents := intents.get_intents()
	_check(b3_intents == _expected_beat(2), "beat 3 announced intents match expected")
	var b3_res := phase_runner.execute_phase(party, foes, b3_intents)
	_check(b3_res == {"ok": true, "events": _expected_events(2)}, "beat 3 phase execution ok and events match")
	_check(party.get_hero(1).get("hp") == 34, "beat 3: Warden HP is 34 (37 to 34)")
	_check(foes.get_enemy(1).get("block") == 2, "beat 3: Fray Scavenger receives 2 Block")
	_check(party.get_hero(2).get("hp") == 30, "beat 3: Seamstress HP is 30")
	_check(party.get_hero(3).get("hp") == 20, "beat 3: Tinker HP is 20")
	traces.append(b3_res)
	hero_snapshots.append(party.get_heroes())
	enemy_snapshots.append(foes.get_enemies())

	_check(intents.advance_turn(), "advance after beat 3")
	_check(party.start_player_turn(), "start player turn after beat 3")

	# Beat 4:
	# slot 1 Attack 3 on pos 2 (Seamstress)
	# slot 2 Attack 3 on pos 2 (Seamstress)
	# Seamstress takes 3 + 3 = 6 HP (30 to 24)
	# Tinker is still 20
	var b4_intents := intents.get_intents()
	_check(b4_intents == _expected_beat(3), "beat 4 announced intents match expected")
	var b4_res := phase_runner.execute_phase(party, foes, b4_intents)
	_check(b4_res == {"ok": true, "events": _expected_events(3)}, "beat 4 phase execution ok and events match")
	_check(party.get_hero(2).get("hp") == 24, "beat 4: Seamstress takes 3+3 damage (30 to 24)")
	_check(party.get_hero(3).get("hp") == 20, "beat 4: Tinker HP is still 20")
	_check(party.get_hero(1).get("hp") == 34, "beat 4: Warden HP remains 34")
	_check(foes.get_enemy(1).get("block") == 2, "beat 4: Fray Scavenger retains Block 2")
	traces.append(b4_res)
	hero_snapshots.append(party.get_heroes())
	enemy_snapshots.append(foes.get_enemies())

	# Beat 5:
	# After four advances, fifth pair equals beat 1
	_check(intents.advance_turn(), "advance after beat 4")
	var b5_intents := intents.get_intents()
	_check(b5_intents == _expected_beat(0), "fifth announced pair equals the first beat after four advances")

	return {
		"traces": traces,
		"hero_snapshots": hero_snapshots,
		"enemy_snapshots": enemy_snapshots,
		"fifth_intents": b5_intents
	}


func _test_ac2_combat_phase_sequence_and_replay() -> void:
	# Run first fixture and verify deterministic replay with identical trace
	seed(FIXED_SEED)
	var oracle_rng := randi()
	seed(FIXED_SEED)
	var fixture_1 := _run_fixture_four_beats()
	_check(randi() == oracle_rng, "AC2 fixture draws no global RNG during execution")

	seed(FIXED_SEED)
	var fixture_2 := _run_fixture_four_beats()
	_check(randi() == oracle_rng, "repeated AC2 fixture draws no global RNG")

	_check(fixture_1["traces"] == fixture_2["traces"], "repeat fixture produces identical action traces")
	_check(fixture_1["hero_snapshots"] == fixture_2["hero_snapshots"], "repeat fixture produces identical hero snapshots")
	_check(fixture_1["enemy_snapshots"] == fixture_2["enemy_snapshots"], "repeat fixture produces identical enemy snapshots")
	_check(fixture_1["fifth_intents"] == fixture_2["fifth_intents"], "repeat fixture fifth intents match")


## AC3: Slain source skips Exposed debuff while Spool Stalker deals unamplified 4 damage.
## Validation rejection of duplicate slot / missing target with untouched model state.
func _test_ac3_slain_source_and_rejections() -> void:
	# 1. Slain slot 1 test:
	var loaded := RunFightEncounterSelection._parse_schedule_text(_read_text(ENCOUNTER_PATH))
	var party := _build_party()
	var assembled := _assemble_roster(loaded)
	var foes: CombatEnemies = assembled["enemies"]
	var intents := CombatEnemyIntents.new(loaded)
	var phase_runner := CombatEnemyPhase.new()

	# Pre-kill slot 1 Fray Scavenger (14 max HP)
	_check(foes.apply_damage(1, 14), "pre-kill slot 1 Fray Scavenger with 14 damage")
	_check(foes.is_slain(1), "slot 1 is slain")
	_check(foes.get_enemy(1).get("hp") == 0, "slot 1 HP is 0")
	_check(not foes.is_slain(2), "slot 2 is living")

	var announced := intents.get_intents()
	_check(announced == _expected_beat(0), "beat 1 announces both source intents even if source is dead")

	seed(FIXED_SEED)
	var rng_before := randi()
	seed(FIXED_SEED)
	var slain_phase_res := phase_runner.execute_phase(party, foes, announced)
	_check(randi() == rng_before, "slain source phase execution consumes no global RNG")

	# Expected events: slot 1 applied=false, slot 2 applied=true
	_check(slain_phase_res == {"ok": true, "events": _expected_events(0, 1)},
		"slain source event has applied=false, living source has applied=true")

	# Slot 1 Exposed debuff was skipped, so Tinker takes base 4 damage (26 to 22)
	_check(party.get_hero(3).get("hp") == 22, "Tinker takes base 4 damage (26 to 22) without Exposed")
	_check(party.get_hero(3).get("statuses", {}).is_empty()
		or party.get_hero(3).get("statuses", {}).get("exposed", 0) == 0,
		"Tinker does not receive Exposed status from slain enemy")
	_check(party.get_hero(1).get("hp") == 40, "Warden retains 40 HP")
	_check(party.get_hero(1).get("block") == 6, "Warden retains initial 6 Block")
	_check(party.get_hero(2).get("hp") == 30, "Seamstress retains 30 HP")

	# 2. Malformed duplicate source position:
	var duplicate_slot_text := JSON.stringify([
		{
			"enemy_position": 1,
			"pattern": [
				{"type": "attack", "amount": 3, "target_position": 1}
			]
		},
		{
			"enemy_position": 1,
			"pattern": [
				{"type": "attack", "amount": 4, "target_position": 3}
			]
		}
	])
	var dup_parsed := RunFightEncounterSelection._parse_schedule_text(duplicate_slot_text)
	_check(dup_parsed.is_empty(), "parser rejects schedule with duplicate enemy_position")
	var dup_raw_data = JSON.parse_string(duplicate_slot_text)
	var dup_intents := CombatEnemyIntents.new(dup_raw_data if dup_raw_data is Array else [])
	_check(not dup_intents.is_valid(), "CombatEnemyIntents rejects duplicate enemy_position")

	# 3. Malformed missing attack target:
	var missing_target_text := JSON.stringify([
		{
			"enemy_position": 1,
			"pattern": [
				{"type": "attack", "amount": 3}
			]
		},
		{
			"enemy_position": 2,
			"pattern": [
				{"type": "attack", "amount": 4, "target_position": 3}
			]
		}
	])
	var missing_target_parsed := RunFightEncounterSelection._parse_schedule_text(missing_target_text)
	_check(missing_target_parsed.is_empty(), "parser rejects attack without target_position")
	var missing_target_raw = JSON.parse_string(missing_target_text)
	var missing_intents := CombatEnemyIntents.new(missing_target_raw if missing_target_raw is Array else [])
	_check(not missing_intents.is_valid(), "CombatEnemyIntents rejects attack without target_position")

	# 4. Untouched model state on phase rejection:
	var fresh_party := _build_party()
	var fresh_foes: CombatEnemies = _assemble_roster(loaded)["enemies"]
	var party_heroes_before := fresh_party.get_heroes()
	var foes_enemies_before := fresh_foes.get_enemies()

	var bad_phase_intents := [
		{"type": "attack", "amount": 3, "target_position": 1, "enemy_position": 1},
		{"type": "attack", "amount": 4, "enemy_position": 2} # missing target_position
	]
	var bad_phase_res := phase_runner.execute_phase(fresh_party, fresh_foes, bad_phase_intents)
	_check(bad_phase_res == {"ok": false, "events": []}, "malformed intent batch rejects phase")
	_check(fresh_party.get_heroes() == party_heroes_before, "party state is completely untouched on rejection")
	_check(fresh_foes.get_enemies() == foes_enemies_before, "enemies state is completely untouched on rejection")
	_check(fresh_party.get_hero(1).get("hp") == 40 and fresh_party.get_hero(1).get("block") == 6,
		"staged first attack rolled back on subsequent intent rejection")

	# Duplicate source in intent batch
	var dup_intent_batch := [
		{"type": "attack", "amount": 3, "target_position": 1, "enemy_position": 1},
		{"type": "attack", "amount": 3, "target_position": 1, "enemy_position": 1}
	]
	var dup_phase_res := phase_runner.execute_phase(fresh_party, fresh_foes, dup_intent_batch)
	_check(dup_phase_res == {"ok": false, "events": []}, "duplicate source intent batch rejects phase")
	_check(fresh_party.get_heroes() == party_heroes_before, "party untouched after duplicate source rejection")
	_check(fresh_foes.get_enemies() == foes_enemies_before, "enemies untouched after duplicate source rejection")
