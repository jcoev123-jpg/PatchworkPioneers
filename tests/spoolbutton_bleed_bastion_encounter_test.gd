extends SceneTree
## Deterministic headless coverage for the standalone authored Spoolbutton Bleed
## Bastion M04 normal Fight: source slot 1 Spool Stalker (14 HP) and source
## slot 2 Button Guard (16 HP) on a three-beat cycle:
## Beat 1: Spool Stalker applies Bleed 2 to Warden (slot 1), Button Guard gains 3 Block.
## Beat 2: Spool Stalker attacks Tinker (slot 3) for base 3, Button Guard attacks Warden (slot 1) for base 4.
## Beat 3: Spool Stalker attacks Seamstress (slot 2) for base 2, Button Guard gains 2 Block via buff.
## Data/service only: standalone test-local pool; not yet registered in live pools.

const ENCOUNTER_PATH := "res://data/encounters/spoolbutton_bleed_bastion.json"
const ENCOUNTER_ID := "spoolbutton_bleed_bastion"
const HERO_CATALOG_PATH := "res://data/heroes/starter_party.json"
const ENEMY_CATALOG_PATH := "res://data/enemies/run_enemies.json"
const BOBBIN_SKIRMISH_PATH := "res://data/encounters/bobbin_skirmish.json"
const STARTER_ATTACKS_PATH := "res://data/encounters/starter_attacks.json"
const GUARD_COUNTERATTACK_PATH := "res://data/encounters/guard_counterattack.json"
const SHARED_POOL_PATH := "res://data/encounters/m03_typed_battle_pools.json"
const HERO_IDS := ["warden", "seamstress", "tinker"]
# Encounter slot order: 1 Spool Stalker, 2 Button Guard.
const ENEMY_IDS := ["spool_stalker", "button_guard"]
const SELECTION_SEED := 1092026

var failures: Array[String] = []
var checks := 0
var phase := CombatEnemyPhase.new()


func _initialize() -> void:
	_verify_failure_harness()
	_test_authored_schedule_and_catalog()
	_test_companion_and_earlier_schedules()
	_test_intent_cycle_forecast_ac1()
	_test_beat_1_bleed_and_block_ac2()
	_test_bleed_owner_turn_tick_ac2()
	_test_beat_2_attacks_and_block_ac2()
	_test_beat_3_attacks_and_buff_ac2()
	_test_full_sequential_cycle_and_wrap_ac2()
	_test_slain_source_and_downed_target()
	_test_fail_closed_boundaries()
	_test_selection_and_caching_ac3()

	if failures.is_empty():
		print("spoolbutton_bleed_bastion_encounter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			push_error(failure)
			printerr(failure)
		print("spoolbutton_bleed_bastion_encounter_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String, sink: Array[String] = failures) -> void:
	checks += 1
	if not condition:
		sink.append(message)


func _verify_failure_harness() -> void:
	var probe_failures: Array[String] = []
	_check(false, "deliberate failure probe", probe_failures)
	if probe_failures.size() != 1 or probe_failures[0] != "deliberate failure probe":
		failures.append("Failure harness did not record a deliberately failing check.")


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _global_probe(label: String, body: Callable) -> void:
	seed(20261022)
	var expected := randi()
	seed(20261022)
	body.call()
	_check(randi() == expected, label)


func _expected() -> Array:
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "debuff", "amount": 2, "target_position": 1, "status": "bleed"},
			{"type": "attack", "amount": 3, "target_position": 3},
			{"type": "attack", "amount": 2, "target_position": 2}]},
		{"enemy_position": 2, "pattern": [
			{"type": "block", "amount": 3},
			{"type": "attack", "amount": 4, "target_position": 1},
			{"type": "buff", "amount": 2}]},
	]


func _intents_for(beat: int) -> Array:
	var beats: Array = [
		[{"type": "debuff", "amount": 2, "target_position": 1, "status": "bleed",
				"enemy_position": 1},
			{"type": "block", "amount": 3, "enemy_position": 2}],
		[{"type": "attack", "amount": 3, "target_position": 3, "enemy_position": 1},
			{"type": "attack", "amount": 4, "target_position": 1, "enemy_position": 2}],
		[{"type": "attack", "amount": 2, "target_position": 2, "enemy_position": 1},
			{"type": "buff", "amount": 2, "enemy_position": 2}],
	]
	return beats[beat % beats.size()]


func _events_for(beat: int) -> Array:
	var beats: Array = [
		[{"type": "debuff", "enemy_position": 1, "target_position": 1, "status": "bleed",
				"applied": true},
			{"type": "block", "enemy_position": 2, "applied": true}],
		[{"type": "attack", "enemy_position": 1, "target_position": 3, "applied": true},
			{"type": "attack", "enemy_position": 2, "target_position": 1, "applied": true}],
		[{"type": "attack", "enemy_position": 1, "target_position": 2, "applied": true},
			{"type": "buff", "enemy_position": 2, "applied": true}],
	]
	return beats[beat % beats.size()]


func _read_text(path: String) -> String:
	_check(FileAccess.file_exists(path), "file exists: " + path)
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "opens " + path)
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


func _load_records(path: String) -> Array:
	var parsed: Variant = JSON.parse_string(_read_text(path))
	_check(parsed is Array, "catalog parses as an Array: " + path)
	if not parsed is Array:
		return []
	var records: Array = []
	for entry in parsed:
		if not entry is Dictionary or not entry.has("max_hp"):
			return []
		var record: Dictionary = entry.duplicate(true)
		var hp: Variant = record["max_hp"]
		if not _is_integral_number(hp) or hp <= 0:
			return []
		record["max_hp"] = int(hp)
		records.append(record)
	return records


func _parsed() -> Array:
	return RunFightEncounterSelection._parse_schedule_text(_read_text(ENCOUNTER_PATH))


func _record(records: Array, id: String, label: String) -> Dictionary:
	var matches: Array = []
	for record in records:
		if record is Dictionary and record.get("id") == id:
			matches.append(record)
	_check(matches.size() == 1, "%s %s appears exactly once" % [label, id])
	return {} if matches.size() != 1 else matches[0].duplicate(true)


func _unique_entry(entries: Array, position: int) -> Dictionary:
	var matches: Array = []
	for entry in entries:
		if entry is Dictionary and entry.get("enemy_position") == position:
			matches.append(entry)
	_check(matches.size() == 1, "exactly one entry at enemy_position %d" % position)
	return {} if matches.size() != 1 else matches[0]


func _check_entry(entries: Array, position: int, expected_actions: Array) -> void:
	var entry := _unique_entry(entries, position)
	_check(entry.size() == 2 and entry.has("enemy_position") and entry.has("pattern"),
		"entry %d has exactly enemy_position and pattern" % position)
	var pattern = entry.get("pattern")
	_check(pattern is Array and pattern.size() == expected_actions.size(),
		"entry %d has exactly %d actions" % [position, expected_actions.size()])
	if not pattern is Array or pattern.size() != expected_actions.size():
		return
	for index in range(expected_actions.size()):
		_check(pattern[index] == expected_actions[index],
			"entry %d beat %d is exactly %s" % [position, index + 1,
				JSON.stringify(expected_actions[index])])


func _hero_ledger(heroes: Array) -> Array:
	var result: Array = []
	for hero in heroes:
		result.append([hero.get("hp"), hero.get("block")])
	return result


func _enemy_ledger(enemies: Array) -> Array:
	var result: Array = []
	for enemy in enemies:
		result.append([enemy.get("hp"), enemy.get("block")])
	return result


func _build_party() -> CombatParty:
	var records := _load_records(HERO_CATALOG_PATH)
	var definitions: Array = []
	for id in HERO_IDS:
		definitions.append(_record(records, id, "authored hero"))
	return CombatParty.new(definitions)


func _build_enemies() -> CombatEnemies:
	var records := _load_records(ENEMY_CATALOG_PATH)
	var definitions: Array = []
	for id in ENEMY_IDS:
		definitions.append(_record(records, id, "authored enemy"))
	return CombatEnemies.new(definitions)


func _fixture_ok(party: CombatParty, enemies: CombatEnemies, label: String) -> bool:
	var valid := party.is_valid() and enemies.is_valid()
	_check(valid, label + ": starter CombatParty and CombatEnemies are valid")
	if not valid:
		return false
	for index in range(3):
		var hero := party.get_hero(index + 1)
		var hp: int = [40, 30, 26][index]
		var id: String = ["warden", "seamstress", "tinker"][index]
		_check(hero.get("id") == id and hero.get("hp") == hp
			and hero.get("max_hp") == hp and hero.get("block") == 0
			and hero.get("position") == index + 1
			and hero.get("statuses", {}) == {},
			label + ": %s in slot %d has %d HP, 0 Block, no status" % [id, index + 1, hp])
	for index in range(2):
		var enemy := enemies.get_enemy(index + 1)
		var id: String = ["spool_stalker", "button_guard"][index]
		var hp: int = [14, 16][index]
		_check(enemy.get("id") == id and enemy.get("hp") == hp
			and enemy.get("max_hp") == hp and enemy.get("block") == 0
			and enemy.get("position") == index + 1,
			label + ": %s in slot %d has %d HP, 0 Block" % [id, index + 1, hp])
	return true


## AC1: authored schedule exists, parses as exact prescribed two-source three-beat
## schedule, uses integral fields, and shipped actors keep their stats and identities.
func _test_authored_schedule_and_catalog() -> void:
	_check(FileAccess.file_exists(ENCOUNTER_PATH), "new authored encounter file exists")
	_check(ENCOUNTER_PATH.get_file().get_basename() == ENCOUNTER_ID,
		"the schedule file name matches canonical encounter ID %s" % ENCOUNTER_ID)
	var raw := _read_text(ENCOUNTER_PATH)
	var raw_json: Variant = JSON.parse_string(raw)
	_check(raw_json is Array and raw_json.size() == 2,
		"the authored file holds exactly two source records as a top-level array")

	# Validate integral fields before coercion in raw parsed data.
	if raw_json is Array:
		for raw_def in raw_json:
			_check(raw_def is Dictionary, "each raw definition is a Dictionary")
			if raw_def is Dictionary:
				_check(_is_integral_number(raw_def.get("enemy_position")),
					"raw enemy_position is integral before coercion")
				var pattern = raw_def.get("pattern", [])
				_check(pattern is Array and pattern.size() == 3,
					"raw pattern is a 3-beat Array")
				if pattern is Array:
					for action in pattern:
						_check(action is Dictionary, "raw action is a Dictionary")
						if action is Dictionary:
							_check(_is_integral_number(action.get("amount")),
								"raw action amount is integral")
							if action.has("target_position"):
								_check(_is_integral_number(action.get("target_position")),
									"raw target_position is integral")

	var parsed := _parsed()
	var expected := _expected()
	_check(parsed == expected, "real parser accepts the file as exact prescribed schedule")
	_check(parsed.size() == 2, "parsed schedule has exactly two sources")
	var positions: Array[int] = []
	for entry in parsed:
		if entry is Dictionary and entry.get("enemy_position") is int:
			positions.append(entry["enemy_position"])
	positions.sort()
	_check(positions == [1, 2], "parsed schedule has unique source positions 1 and 2")
	_check(CombatEnemyIntents.new(parsed).is_valid(),
		"CombatEnemyIntents.is_valid() returns true for parsed JSON")

	_check_entry(parsed, 1, expected[0]["pattern"])
	_check_entry(parsed, 2, expected[1]["pattern"])
	_check_entry(parsed, 1, [
		{"type": "debuff", "amount": 2, "target_position": 1, "status": "bleed"},
		{"type": "attack", "amount": 3, "target_position": 3},
		{"type": "attack", "amount": 2, "target_position": 2}])
	_check_entry(parsed, 2, [
		{"type": "block", "amount": 3},
		{"type": "attack", "amount": 4, "target_position": 1},
		{"type": "buff", "amount": 2}])

	for entry in parsed:
		_check(entry.get("enemy_position") is int, "parsed enemy_position is an int")
		var pattern: Array = entry["pattern"]
		_check(pattern.size() == 3, "source %d has exactly 3 actions" % entry["enemy_position"])
		for action in pattern:
			_check(action.get("amount") is int, "parsed action amount is an int")
			if action.has("target_position"):
				_check(action.get("target_position") is int, "parsed target_position is an int")

	_check(CombatEnemyIntents.new(expected).is_valid(), "canonical expectation itself validates")
	_check(_read_text(ENCOUNTER_PATH) == raw, "authored file remains unchanged after validation")

	# Validate shipped enemy catalog records.
	var enemy_records := _load_records(ENEMY_CATALOG_PATH)
	var stalker := _record(enemy_records, "spool_stalker", "authored enemy")
	var guard := _record(enemy_records, "button_guard", "authored enemy")
	_check(stalker.get("name") == "Spool Stalker" and stalker.get("max_hp") == 14
		and stalker.get("max_hp") is int,
		"shipped spool_stalker is Spool Stalker with 14 integer max HP")
	_check(guard.get("name") == "Button Guard" and guard.get("max_hp") == 16
		and guard.get("max_hp") is int,
		"shipped button_guard is Button Guard with 16 integer max HP")
	_check(stalker.get("art_path") == "res://assets/paper/enemies/spool_stalker.png"
		and guard.get("art_path") == "res://assets/paper/enemies/button_guard.png",
		"both shipped enemies retain their paper-art paths")

	# Validate constructed enemy roster binding: slot 1 Spool Stalker, slot 2 Button Guard.
	var enemies := _build_enemies()
	_check(enemies.is_valid() and enemies.get_enemies().size() == 2, "roster is valid")
	var roster_ids: Array = []
	for enemy in enemies.get_enemies():
		roster_ids.append(enemy.get("id"))
	_check(roster_ids == ENEMY_IDS, "constructed roster has slot 1 spool_stalker and slot 2 button_guard")
	_check(enemies.get_enemy(1).get("name") == "Spool Stalker"
		and enemies.get_enemy(1).get("position") == 1
		and enemies.get_enemy(1).get("hp") == 14,
		"Spool Stalker in slot 1 with 14 HP")
	_check(enemies.get_enemy(2).get("name") == "Button Guard"
		and enemies.get_enemy(2).get("position") == 2
		and enemies.get_enemy(2).get("hp") == 16,
		"Button Guard in slot 2 with 16 HP")

	# Validate shipped hero catalog records.
	var party := _build_party()
	_check(party.is_valid(), "shipped starter party is valid")
	_check(_hero_ledger(party.get_heroes()) == [[40, 0], [30, 0], [26, 0]],
		"party starts Warden 40, Seamstress 30, Tinker 26, all with 0 Block")
	_check(party.get_hero(1).get("name") == "Warden" and party.get_hero(1).get("max_hp") == 40,
		"starter slot 1 is Warden with 40 max HP")
	_check(party.get_hero(2).get("name") == "Seamstress" and party.get_hero(2).get("max_hp") == 30,
		"starter slot 2 is Seamstress with 30 max HP")
	_check(party.get_hero(3).get("name") == "Tinker" and party.get_hero(3).get("max_hp") == 26,
		"starter slot 3 is Tinker with 26 max HP")


## Earlier schedules and bobbin_skirmish still parse, and standalone encounter stays out of shared pool.
func _test_companion_and_earlier_schedules() -> void:
	var bobbin := RunFightEncounterSelection._parse_schedule_text(_read_text(BOBBIN_SKIRMISH_PATH))
	_check(bobbin.size() == 2, "bobbin_skirmish.json still parses its two sources")
	_check_entry(bobbin, 1, [
		{"type": "attack", "amount": 1, "target_position": 2},
		{"type": "block", "amount": 1},
		{"type": "attack", "amount": 1, "target_position": 3}])
	_check_entry(bobbin, 2, [
		{"type": "attack", "amount": 1, "target_position": 1},
		{"type": "block", "amount": 1}])
	_check(CombatEnemyIntents.new(bobbin).is_valid(), "bobbin_skirmish still validates in CombatEnemyIntents")

	var starter := RunFightEncounterSelection._parse_schedule_text(_read_text(STARTER_ATTACKS_PATH))
	_check(starter.size() == 2, "starter_attacks.json still parses")
	_check(CombatEnemyIntents.new(starter).is_valid(), "starter_attacks validates in CombatEnemyIntents")

	var guard := RunFightEncounterSelection._parse_schedule_text(_read_text(GUARD_COUNTERATTACK_PATH))
	_check(guard.size() == 2, "guard_counterattack.json still parses")
	_check(CombatEnemyIntents.new(guard).is_valid(), "guard_counterattack validates in CombatEnemyIntents")

	var pools: Variant = JSON.parse_string(_read_text(SHARED_POOL_PATH))
	_check(pools is Dictionary, "shared typed battle pool still parses")
	_check(not _shared_pool_registers_encounter(),
		"standalone %s stays out of shared m03_typed_battle_pools.json" % ENCOUNTER_ID)


func _shared_pool_registers_encounter() -> bool:
	var file := FileAccess.open(SHARED_POOL_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return false
	for kind in parsed:
		var group = parsed[kind]
		if not group is Dictionary:
			continue
		for encounter_id in group:
			var entry = group[encounter_id]
			if not entry is Dictionary:
				continue
			if encounter_id == ENCOUNTER_ID or entry.get("schedule") == ENCOUNTER_PATH:
				return true
	return false


## AC1: CombatEnemyIntents forecasts exact three authored beats before returning to beat 1 on fourth forecast.
func _test_intent_cycle_forecast_ac1() -> void:
	var definitions := _parsed()
	var pristine := definitions.duplicate(true)
	var first := CombatEnemyIntents.new(definitions.duplicate(true))
	var second := CombatEnemyIntents.new(definitions.duplicate(true))
	_check(first.is_valid() and second.is_valid(), "independent schedulers accept authored schedule")
	if not first.is_valid() or not second.is_valid():
		return

	# Beats 1, 2, 3
	for beat in range(3):
		var announced := first.get_intents()
		var replayed := second.get_intents()
		_check(announced == _intents_for(beat),
			"AC1: beat %d announces exact authored per-source actions" % (beat + 1))
		_check(replayed == _intents_for(beat),
			"AC1: independent instance announces same actions at beat %d" % (beat + 1))
		_check(announced.size() == 2
			and announced[0].get("enemy_position") == 1
			and announced[1].get("enemy_position") == 2,
			"AC1: beat %d lists slot 1 then slot 2" % (beat + 1))
		_check(first._turn_index == beat, "reading intents does not advance turn index")

		# Detached copies check
		announced[0]["amount"] = 999
		announced[0]["type"] = "invented"
		announced.append({"enemy_position": 3, "type": "block", "amount": 5})
		_check(first.get_intents() == _intents_for(beat),
			"AC1: returned intents are detached deep copies")
		_check(second.get_intents() == _intents_for(beat),
			"AC1: second instance unaffected by caller modification")

		_check(first.advance_turn() and second.advance_turn(), "scheduler advances from beat %d" % (beat + 1))

	# Beat 4: wraps to Beat 1
	_check(first.get_intents() == _intents_for(0) and second.get_intents() == _intents_for(0),
		"AC1: fourth announced beat wraps to beat 1")
	_check(first._turn_index == 3 and second._turn_index == 3, "fourth forecast has turn_index 3")
	_check(definitions == pristine, "parsed source array stays unmutated")

	# Forecasting consumes no global RNG
	var cycle_body := func() -> void:
		var probe := CombatEnemyIntents.new(definitions.duplicate(true))
		for _turn in range(8):
			probe.get_intents()
			probe.advance_turn()
	_global_probe("AC1: viewing and advancing schedule draws no global RNG", cycle_body)
	seed(20261022)
	var probe_baseline := randi()
	seed(20261022)
	randi()
	_check(randi() != probe_baseline, "global RNG probe catches injected extra draw")


## AC2: Beat 1 applies front Bleed 2 and gives Button Guard 3 Block.
func _test_beat_1_bleed_and_block_ac2() -> void:
	var party := _build_party()
	var enemies := _build_enemies()
	if not _fixture_ok(party, enemies, "AC2 Beat 1"):
		return
	var scheduler := CombatEnemyIntents.new(_parsed())
	var announced: Array = scheduler.get_intents()
	_check(announced == _intents_for(0), "AC2 Beat 1 announces first pair")

	var probe_party := _build_party()
	var probe_enemies := _build_enemies()
	var phase_body := func() -> void:
		phase.execute_phase(probe_party, probe_enemies, announced)
	_global_probe("AC2 Beat 1: phase execution draws no global RNG", phase_body)

	var result := phase.execute_phase(party, enemies, announced)
	_check(result == {"ok": true, "events": _events_for(0)},
		"AC2 Beat 1: resolves exact Bleed 2 and 3 Block events")
	_check(result.get("events", [])[0].get("enemy_position") == 1
		and result.get("events", [])[1].get("enemy_position") == 2,
		"AC2 Beat 1: events in slot 1 then slot 2 order")

	# Warden receives Bleed 2, HP and Block untouched
	_check(party.get_hero(1).get("id") == "warden"
		and party.get_hero(1).get("hp") == 40
		and party.get_hero(1).get("block") == 0
		and party.get_hero(1).get("statuses") == {"bleed": 2},
		"AC2 Beat 1: Warden receives Bleed 2, retains 40 HP, 0 Block (no tick in enemy phase)")
	_check(party.get_hero(2).get("hp") == 30 and party.get_hero(3).get("hp") == 26,
		"AC2 Beat 1: Seamstress and Tinker untouched")

	# Button Guard gains 3 Block, retains 16 HP; Spool Stalker unchanged
	_check(enemies.get_enemy(1).get("id") == "spool_stalker"
		and enemies.get_enemy(1).get("hp") == 14
		and enemies.get_enemy(1).get("block") == 0,
		"AC2 Beat 1: Spool Stalker untouched at 14 HP and 0 Block")
	_check(enemies.get_enemy(2).get("id") == "button_guard"
		and enemies.get_enemy(2).get("hp") == 16
		and enemies.get_enemy(2).get("block") == 3,
		"AC2 Beat 1: Button Guard gains exactly 3 Block and retains 16 HP")

	# Fixture with Warden starting Block (6 Block from CombatStartingBlock)
	var shielded_party := _build_party()
	var shielded_enemies := _build_enemies()
	_check(CombatStartingBlock.new(shielded_party).apply(), "Warden starts combat with 6 Block")
	_check(shielded_party.get_hero(1).get("block") == 6, "Warden holds 6 Block before Beat 1")
	var shielded_result := phase.execute_phase(shielded_party, shielded_enemies, announced)
	_check(shielded_result.get("ok") == true, "Beat 1 resolves with shielded Warden")
	_check(shielded_party.get_hero(1).get("hp") == 40
		and shielded_party.get_hero(1).get("block") == 6
		and shielded_party.get_hero(1).get("statuses") == {"bleed": 2},
		"AC2 Beat 1: Warden with opening 6 Block receives Bleed 2 with 6 Block intact and 40 HP")


## AC2: Bleed owner-turn tick bypasses Block, inflicts direct HP loss, and decrements Bleed 2 to 1.
func _test_bleed_owner_turn_tick_ac2() -> void:
	# Unshielded tick
	var party := _build_party()
	var enemies := _build_enemies()
	var scheduler := CombatEnemyIntents.new(_parsed())
	phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(party.get_hero(1).get("statuses") == {"bleed": 2}, "Warden has Bleed 2")

	var party_before: Array = party.get_heroes()
	var tick := CombatStatusTurnBatch.new().tick_side("heroes", party.get_heroes())
	_check(tick.get("ok") == true and tick.get("actors", []).size() == 3,
		"AC2 Bleed tick: hero owner-turn tick succeeds")
	var actors: Array = tick.get("actors", [])
	_check(actors[0].get("id") == "warden"
		and actors[0].get("hp") == 38
		and actors[0].get("block") == 0
		and actors[0].get("statuses") == {"bleed": 1},
		"AC2 Bleed tick: Warden takes 2 direct HP loss (40 -> 38 HP) and Bleed 2 decrements to 1")
	_check(actors[1].get("hp") == 30 and actors[2].get("hp") == 26,
		"AC2 Bleed tick: Seamstress and Tinker untouched by Warden's tick")
	_check(tick.get("events") == [
		{"side": "heroes", "position": 1, "id": "warden", "bleed_hp_loss": 2},
		{"side": "heroes", "position": 2, "id": "seamstress", "bleed_hp_loss": 0},
		{"side": "heroes", "position": 3, "id": "tinker", "bleed_hp_loss": 0}],
		"AC2 Bleed tick: events report 2 bleed HP loss on Warden in slot order")
	_check(party.get_heroes() == party_before,
		"AC2 Bleed tick: detached tick does not mutate live CombatParty")

	# Shielded tick: Bleed bypasses Block completely without consuming Block
	var shielded_party := _build_party()
	var shielded_enemies := _build_enemies()
	_check(CombatStartingBlock.new(shielded_party).apply(), "Warden gains 6 Block")
	phase.execute_phase(shielded_party, shielded_enemies, scheduler.get_intents())
	_check(shielded_party.get_hero(1).get("block") == 6
		and shielded_party.get_hero(1).get("statuses") == {"bleed": 2},
		"Warden holds 6 Block and Bleed 2")

	var shielded_tick := CombatStatusTurnBatch.new().tick_side("heroes", shielded_party.get_heroes())
	_check(shielded_tick.get("ok") == true, "shielded tick succeeds")
	var shielded_actors: Array = shielded_tick.get("actors", [])
	_check(shielded_actors[0].get("id") == "warden"
		and shielded_actors[0].get("hp") == 38
		and shielded_actors[0].get("block") == 6
		and shielded_actors[0].get("statuses") == {"bleed": 1},
		"AC2 Bleed tick: direct HP loss (40 -> 38 HP) bypasses 6 Block completely, Block remains 6")


## AC2: Beat 2 deals base 3 to Tinker at position 3 and base 4 to Warden at position 1 (subject to Block).
func _test_beat_2_attacks_and_block_ac2() -> void:
	# Subtest A: Unblocked attacks
	var party := _build_party()
	var enemies := _build_enemies()
	if not _fixture_ok(party, enemies, "AC2 Beat 2 unblocked"):
		return
	var scheduler := CombatEnemyIntents.new(_parsed())
	_check(scheduler.advance_turn(), "advance to Beat 2")
	var announced: Array = scheduler.get_intents()
	_check(announced == _intents_for(1), "AC2 Beat 2 announces second pair")

	var result := phase.execute_phase(party, enemies, announced)
	_check(result == {"ok": true, "events": _events_for(1)},
		"AC2 Beat 2: resolves attack 3 on Tinker and attack 4 on Warden")
	_check(party.get_hero(3).get("hp") == 23 and party.get_hero(3).get("block") == 0,
		"AC2 Beat 2: Tinker takes base 3 damage (26 -> 23 HP)")
	_check(party.get_hero(1).get("hp") == 36 and party.get_hero(1).get("block") == 0,
		"AC2 Beat 2: Warden takes base 4 damage (40 -> 36 HP)")
	_check(party.get_hero(2).get("hp") == 30 and party.get_hero(2).get("block") == 0,
		"AC2 Beat 2: Seamstress untouched (30 HP)")
	_check(_hero_ledger(party.get_heroes()) == [[36, 0], [30, 0], [23, 0]],
		"AC2 Beat 2: unblocked hero HP/Block ledger")

	# Subtest B: Controlled Block absorption
	var shielded_party := _build_party()
	var shielded_enemies := _build_enemies()
	_check(CombatStartingBlock.new(shielded_party).apply(), "Warden gains 6 Block")
	_check(shielded_party.gain_block(3, 4), "Tinker gains 4 Block")
	_check(shielded_party.get_hero(1).get("block") == 6
		and shielded_party.get_hero(3).get("block") == 4,
		"Warden has 6 Block, Tinker has 4 Block")

	var shielded_result := phase.execute_phase(shielded_party, shielded_enemies, announced)
	_check(shielded_result == {"ok": true, "events": _events_for(1)},
		"AC2 Beat 2: shielded phase resolves same events")
	# Tinker takes 3 against 4 Block: 4 - 3 = 1 Block, 26 HP
	_check(shielded_party.get_hero(3).get("hp") == 26
		and shielded_party.get_hero(3).get("block") == 1,
		"AC2 Beat 2: Tinker Block absorbs 3 damage (4 -> 1 Block, 26 HP)")
	# Warden takes 4 against 6 Block: 6 - 4 = 2 Block, 40 HP
	_check(shielded_party.get_hero(1).get("hp") == 40
		and shielded_party.get_hero(1).get("block") == 2,
		"AC2 Beat 2: Warden Block absorbs 4 damage (6 -> 2 Block, 40 HP)")
	_check(shielded_party.get_hero(2).get("hp") == 30, "Seamstress untouched at 30 HP")


## AC2: Beat 3 deals base 2 to Seamstress at position 2 and gives Button Guard another 2 Block.
func _test_beat_3_attacks_and_buff_ac2() -> void:
	var party := _build_party()
	var enemies := _build_enemies()
	if not _fixture_ok(party, enemies, "AC2 Beat 3"):
		return
	var scheduler := CombatEnemyIntents.new(_parsed())
	_check(scheduler.advance_turn() and scheduler.advance_turn(), "advance to Beat 3")
	var announced: Array = scheduler.get_intents()
	_check(announced == _intents_for(2), "AC2 Beat 3 announces third pair")

	var result := phase.execute_phase(party, enemies, announced)
	_check(result == {"ok": true, "events": _events_for(2)},
		"AC2 Beat 3: resolves attack 2 on Seamstress and buff 2 on Button Guard")
	_check(party.get_hero(2).get("hp") == 28 and party.get_hero(2).get("block") == 0,
		"AC2 Beat 3: Seamstress takes base 2 damage (30 -> 28 HP)")
	_check(party.get_hero(1).get("hp") == 40 and party.get_hero(3).get("hp") == 26,
		"AC2 Beat 3: Warden and Tinker untouched")
	_check(enemies.get_enemy(2).get("id") == "button_guard"
		and enemies.get_enemy(2).get("hp") == 16
		and enemies.get_enemy(2).get("block") == 2,
		"AC2 Beat 3: Button Guard gains 2 Block via buff (0 -> 2 Block)")
	_check(enemies.get_enemy(1).get("hp") == 14 and enemies.get_enemy(1).get("block") == 0,
		"AC2 Beat 3: Spool Stalker unchanged at 14 HP and 0 Block")

	# Shielded Seamstress absorbs attack
	var shielded_party := _build_party()
	var shielded_enemies := _build_enemies()
	_check(shielded_party.gain_block(2, 5), "Seamstress gains 5 Block")
	var shielded_result := phase.execute_phase(shielded_party, shielded_enemies, announced)
	_check(shielded_result.get("ok") == true, "shielded Beat 3 resolves")
	_check(shielded_party.get_hero(2).get("hp") == 30
		and shielded_party.get_hero(2).get("block") == 3,
		"AC2 Beat 3: Seamstress 5 Block absorbs 2 damage (5 -> 3 Block, 30 HP)")


## AC2: Full sequential cycle execution across beats 1, 2, 3 and wrap (beat 4), replayed from scratch.
func _run_cycle() -> Dictionary:
	var party := _build_party()
	var enemies := _build_enemies()
	var scheduler := CombatEnemyIntents.new(_parsed())
	var beats: Array = []
	for index in range(4):
		if index > 0:
			scheduler.advance_turn()
		var announced: Array = scheduler.get_intents()
		var result := phase.execute_phase(party, enemies, announced)
		beats.append({
			"announced": announced,
			"events": result.get("events", []),
			"ok": result.get("ok"),
			"heroes": party.get_heroes(),
			"enemies": enemies.get_enemies(),
		})
	return {
		"beats": beats,
		"final_announcement": scheduler.get_intents(),
		"turn_index": scheduler._turn_index,
	}


func _test_full_sequential_cycle_and_wrap_ac2() -> void:
	var first := _run_cycle()
	var second := _run_cycle()
	_check(first == second, "AC2: two independently constructed cycles replay identically")

	var beats: Array = first.get("beats", [])
	_check(beats.size() == 4, "AC2: captured all 4 beats including wrap")
	if beats.size() != 4:
		return

	# Check beats 1..3 announced and events
	for index in range(3):
		_check(beats[index].get("announced") == _intents_for(index),
			"AC2: beat %d announced matches authored pair" % index)
		_check(beats[index].get("events") == _events_for(index),
			"AC2: beat %d events match authored resolution" % index)

	# Beat 4 (index 3) wrap checks
	_check(beats[3].get("announced") == _intents_for(0),
		"AC2: fourth announced beat wraps to beat 1 intents")
	_check(beats[3].get("events") == _events_for(0),
		"AC2: fourth resolved beat repeats beat 1 events")

	# Ledgers progression
	# Beat 1: Warden [40, 0] with bleed 2, Seamstress [30, 0], Tinker [26, 0]; Enemies: Stalker [14, 0], Guard [16, 3]
	_check(_hero_ledger(beats[0]["heroes"]) == [[40, 0], [30, 0], [26, 0]], "beat 1 hero ledger")
	_check(_enemy_ledger(beats[0]["enemies"]) == [[14, 0], [16, 3]], "beat 1 enemy ledger (Guard 3 Block)")
	_check(beats[0]["heroes"][0].get("statuses") == {"bleed": 2}, "beat 1 Warden holds Bleed 2")

	# Beat 2: Stalker hits Tinker for 3 (26 -> 23), Guard hits Warden for 4 (40 -> 36)
	_check(_hero_ledger(beats[1]["heroes"]) == [[36, 0], [30, 0], [23, 0]], "beat 2 hero ledger")
	_check(_enemy_ledger(beats[1]["enemies"]) == [[14, 0], [16, 3]], "beat 2 enemy ledger")

	# Beat 3: Stalker hits Seamstress for 2 (30 -> 28), Guard buffs 2 Block (3 -> 5)
	_check(_hero_ledger(beats[2]["heroes"]) == [[36, 0], [28, 0], [23, 0]], "beat 3 hero ledger")
	_check(_enemy_ledger(beats[2]["enemies"]) == [[14, 0], [16, 5]], "beat 3 enemy ledger (Guard 5 Block)")

	# Beat 4 (wrap): Stalker debuffs Warden bleed 2 (accumulates 2 + 2 = 4), Guard blocks 3 (5 + 3 = 8)
	_check(_hero_ledger(beats[3]["heroes"]) == [[36, 0], [28, 0], [23, 0]], "beat 4 hero ledger")
	_check(beats[3]["heroes"][0].get("statuses") == {"bleed": 4}, "beat 4 Warden holds accumulated Bleed 4")
	_check(_enemy_ledger(beats[3]["enemies"]) == [[14, 0], [16, 8]], "beat 4 enemy ledger (Guard 8 Block)")


## Slain source skips its action while living source still acts; downed hero is not retargeted.
func _test_slain_source_and_downed_target() -> void:
	# Slain source 1 (Spool Stalker) on Beat 1: Debuff skipped (applied=false), Button Guard still gains 3 Block
	var party := _build_party()
	var enemies := _build_enemies()
	_check(enemies.apply_damage(1, 14) and enemies.is_slain(1), "Spool Stalker is slain")
	var dead_stalker: Dictionary = enemies.get_enemy(1)
	var scheduler := CombatEnemyIntents.new(_parsed())
	var result1 := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(result1 == {"ok": true, "events": [
		{"type": "debuff", "enemy_position": 1, "target_position": 1, "status": "bleed", "applied": false},
		{"type": "block", "enemy_position": 2, "applied": true}]},
		"slain Spool Stalker debuff is skipped, living Button Guard blocks")
	_check(party.get_hero(1).get("statuses", {}) == {}, "Warden received no bleed from slain source")
	_check(enemies.get_enemy(2).get("block") == 3, "Button Guard still gained 3 Block")
	_check(enemies.get_enemy(1) == dead_stalker, "slain source stays unchanged")

	# Slain source 2 (Button Guard) on Beat 2: Spool Stalker attacks Tinker (applied=true), Button Guard attack skipped
	var party2 := _build_party()
	var enemies2 := _build_enemies()
	_check(enemies2.apply_damage(2, 16) and enemies2.is_slain(2), "Button Guard is slain")
	var scheduler2 := CombatEnemyIntents.new(_parsed())
	scheduler2.advance_turn()
	var result2 := phase.execute_phase(party2, enemies2, scheduler2.get_intents())
	_check(result2 == {"ok": true, "events": [
		{"type": "attack", "enemy_position": 1, "target_position": 3, "applied": true},
		{"type": "attack", "enemy_position": 2, "target_position": 1, "applied": false}]},
		"living Spool Stalker attacks Tinker, slain Button Guard attack skipped")
	_check(party2.get_hero(3).get("hp") == 23, "Tinker takes 3 damage from living source")
	_check(party2.get_hero(1).get("hp") == 40, "Warden unharmed by slain source")

	# Downed hero target on attack: Tinker downed (hp 0). Beat 2 attack on Tinker is applied=false and not redirected
	var party3 := _build_party()
	var enemies3 := _build_enemies()
	_check(party3.apply_damage(3, 26) and party3.is_downed(3), "Tinker is downed")
	var result3 := phase.execute_phase(party3, enemies3, scheduler2.get_intents())
	_check(result3.get("ok") == true, "attack phase with downed hero still succeeds")
	_check(result3.get("events") == [
		{"type": "attack", "enemy_position": 1, "target_position": 3, "applied": false},
		{"type": "attack", "enemy_position": 2, "target_position": 1, "applied": true}],
		"attack on downed Tinker is unapplied and not redirected")
	_check(party3.get_hero(3).get("hp") == 0, "downed Tinker takes no further damage")
	_check(party3.get_hero(1).get("hp") == 36, "Button Guard still hits Warden")
	_check(party3.get_hero(2).get("hp") == 30, "Seamstress not retargeted")

	# Downed hero target on debuff: Warden downed (hp 0). Debuff onto downed Warden rejects entire phase atomically
	var party4 := _build_party()
	var enemies4 := _build_enemies()
	_check(party4.apply_damage(1, 40) and party4.is_downed(1), "Warden is downed")
	var party4_before: Array = party4.get_heroes()
	var enemies4_before: Array = enemies4.get_enemies()
	var scheduler4 := CombatEnemyIntents.new(_parsed())
	var result4 := phase.execute_phase(party4, enemies4, scheduler4.get_intents())
	_check(result4 == {"ok": false, "events": []}, "debuff on downed hero rejects phase atomically")
	_check(party4.get_heroes() == party4_before and enemies4.get_enemies() == enemies4_before,
		"rejected phase leaves heroes and enemies unmutated")


## Fail-closed boundaries for parser and phase execution.
func _test_fail_closed_boundaries() -> void:
	var pristine := _read_text(ENCOUNTER_PATH)
	var valid := _parsed()
	var broken: Array = [
		"{bad_json",
		"[]",
		JSON.stringify([valid[0], valid[0]]),
		JSON.stringify([{"enemy_position": 1, "pattern": []}, valid[1]]),
		JSON.stringify([{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 1}]}, valid[1]]),
		JSON.stringify([{"enemy_position": 1, "pattern": [{"type": "block", "amount": 1, "target_position": 2}]}, valid[1]]),
		JSON.stringify([{"enemy_position": 1, "pattern": [{"type": "heal", "amount": 1}]}, valid[1]]),
		JSON.stringify([{"enemy_position": 1, "pattern": [{"type": "attack", "amount": -1, "target_position": 2}]}, valid[1]]),
		JSON.stringify([{"enemy_position": 1.5, "pattern": [{"type": "block", "amount": 1}]}, valid[1]]),
		JSON.stringify([{"enemy_position": 1, "pattern": [{"type": "block", "amount": 1.5}]}, valid[1]]),
		JSON.stringify([{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 1, "target_position": 2.5}]}, valid[1]]),
		JSON.stringify([{"enemy_position": 1, "pattern": [{"type": "block", "amount": "3"}]}, valid[1]]),
	]
	for index in range(broken.size()):
		_check(RunFightEncounterSelection._parse_schedule_text(broken[index]).is_empty(),
			"malformed schedule %d rejected fail-closed" % index)
	_check(_read_text(ENCOUNTER_PATH) == pristine and _parsed() == valid,
		"authored file unmutated after malformed schedule checks")

	# Malformed runtime intents in execute_phase: later invalid action rolls back earlier staged action
	var party := _build_party()
	var enemies := _build_enemies()
	var party_before: Array = party.get_heroes()
	var enemies_before: Array = enemies.get_enemies()
	var invalid_phase: Array = [
		{"type": "block", "amount": 3, "enemy_position": 1},
		{"type": "attack", "amount": 4, "target_position": 99, "enemy_position": 2},
	]
	_check(phase.execute_phase(party, enemies, invalid_phase) == {"ok": false, "events": []},
		"later invalid intent rejects whole phase")
	_check(party.get_heroes() == party_before and enemies.get_enemies() == enemies_before,
		"phase rejection preserves full state atomically")


## AC3: Seeded RunMap selection returns encounter from test-local pool, caches choice without extra RNG draw,
## and rejected non-Fight/no-node requests remain fail-closed.
func _test_selection_and_caching_ac3() -> void:
	var pool := {ENCOUNTER_ID: ENCOUNTER_PATH}
	var rng := _rng(SELECTION_SEED)
	var map := RunMap.new()
	_check(map.generate(rng), "AC3: seeded RunMap generates")
	var fight := _opening_fight(map)
	_check(not fight.is_empty() and map.get_legal_choices().has(fight),
		"AC3: map offers legal opening Fight node")
	if fight.is_empty():
		return
	_check(map.choose_node(fight), "AC3: map enters legal Fight node")
	_check(map.get_current_node_id() == fight
		and map.get_node(fight).get("type") == "Fight"
		and map.get_route() == [fight],
		"AC3: current node is Fight")

	var state_before_selection := rng.state
	var selector := RunFightEncounterSelection.new()
	var choice := selector.select_current_fight(map, rng, pool)
	_check(choice.get("success") == true and choice.get("encounter_id") == ENCOUNTER_ID,
		"AC3: legacy selector picks spoolbutton_bleed_bastion from local pool")
	_check(choice.get("definitions") == _expected(),
		"AC3: selection returns exact canonical schedule")
	_check(rng.state == state_before_selection,
		"AC3: one-candidate pool leaves RNG untouched")
	_check(map.get_current_node_id() == fight and map.get_route() == [fight],
		"AC3: selector does not advance map")

	# Repeated query served from cache with no extra RNG draw
	var cached := selector.select_current_fight(map, rng, {})
	_check(cached == choice and rng.state == state_before_selection,
		"AC3: repeated query returns cached choice without RNG draw even with empty pool")

	# select_current_battle also returns cached choice
	var cached_battle := selector.select_current_battle(map, rng, {"Fight": {}})
	_check(cached_battle.get("success") == true
		and cached_battle.get("node_type") == "Fight"
		and cached_battle.get("encounter_id") == ENCOUNTER_ID
		and cached_battle.get("definitions") == _expected()
		and rng.state == state_before_selection,
		"AC3: select_current_battle returns cached choice without RNG draw")

	# Result isolation: caller mutation cannot corrupt selector's cache
	var copy_before := choice.duplicate(true)
	choice["definitions"][0]["pattern"][0]["amount"] = 999
	choice["definitions"].clear()
	choice["encounter_id"] = "mutated"
	_check(selector.select_current_fight(map, rng, pool) == copy_before,
		"AC3: selector cache is isolated from caller mutation")

	# Replay: independent same-seed map and selector replay identically
	var replay_rng := _rng(SELECTION_SEED)
	var replay_map := RunMap.new()
	_check(replay_map.generate(replay_rng), "AC3: replay map generates")
	_check(replay_map.choose_node(fight), "AC3: replay map enters same Fight")
	var replay_choice := RunFightEncounterSelection.new().select_current_fight(
		replay_map, replay_rng, pool)
	_check(replay_choice == copy_before and replay_rng.state == rng.state,
		"AC3: independent seeded run replays identical selection and RNG state")

	# RNG draw discipline: two-candidate pool vs oracle
	var two_pool := {
		ENCOUNTER_ID: ENCOUNTER_PATH,
		"bobbin_skirmish": BOBBIN_SKIRMISH_PATH,
	}
	var disc_rng := _rng(SELECTION_SEED + 100)
	var disc_map := RunMap.new()
	disc_map.generate(disc_rng)
	var disc_fight := _opening_fight(disc_map)
	disc_map.choose_node(disc_fight)

	var oracle := _rng(SELECTION_SEED + 100)
	var oracle_map := RunMap.new()
	oracle_map.generate(oracle)
	oracle_map.choose_node(disc_fight)
	var ids: Array = two_pool.keys()
	ids.sort()
	var expected_id: String = ids[oracle.randi_range(0, ids.size() - 1)]
	var after_one_draw := oracle.state

	var disc_selector := RunFightEncounterSelection.new()
	var disc_choice := disc_selector.select_current_fight(disc_map, disc_rng, two_pool)
	_check(disc_choice.get("success") == true and disc_choice.get("encounter_id") == expected_id,
		"AC3 draw discipline: selects oracle's sorted-index draw")
	_check(disc_rng.state == after_one_draw,
		"AC3 draw discipline: consumes exactly one real RNG draw")

	# Oracle sensitivity check
	var extra_oracle := _rng(SELECTION_SEED + 100)
	extra_oracle.randi_range(0, ids.size() - 1)
	extra_oracle.randi_range(0, ids.size() - 1)
	_check(extra_oracle.state != after_one_draw, "draw discipline oracle catches extra draw")

	# Refusal: non-Fight node refuses Fight selection and advances no RNG
	var non_fight := _map_with_non_fight_opening()
	_check(not non_fight.is_empty(), "AC3: non-Fight node exists")
	if not non_fight.is_empty():
		var nf_map: RunMap = non_fight["map"]
		var nf_rng: RandomNumberGenerator = non_fight["rng"]
		var state_before_refusal := nf_rng.state
		var refused := RunFightEncounterSelection.new().select_current_fight(nf_map, nf_rng, pool)
		_check(refused == {"success": false}, "AC3: non-Fight node refused fail-closed")
		_check(nf_rng.state == state_before_refusal, "AC3: refused selection advances no RNG")

	# Refusal: unchosen node (no current node)
	var unchosen_rng := _rng(SELECTION_SEED + 200)
	var unchosen_map := RunMap.new()
	unchosen_map.generate(unchosen_rng)
	var state_unchosen := unchosen_rng.state
	var unchosen_refused := RunFightEncounterSelection.new().select_current_fight(
		unchosen_map, unchosen_rng, pool)
	_check(unchosen_refused == {"success": false}, "AC3: unchosen node refused")
	_check(unchosen_rng.state == state_unchosen, "AC3: unchosen refusal advances no RNG")

	# Integration with RunTypedBattleRoster.assemble
	var typed_choice := {
		"success": true,
		"node_type": "Fight",
		"encounter_id": ENCOUNTER_ID,
		"definitions": _expected(),
	}
	var bindings := {ENCOUNTER_ID: ENEMY_IDS}
	var assembled := RunTypedBattleRoster.new().assemble(typed_choice, bindings, [ENEMY_CATALOG_PATH])
	_check(assembled.get("ok") == true, "AC3: RunTypedBattleRoster assembles this encounter")
	if assembled.get("ok", false):
		var assembled_enemies: CombatEnemies = assembled.get("enemies")
		_check(assembled_enemies is CombatEnemies and assembled_enemies.is_valid(),
			"AC3: assembled CombatEnemies is valid")
		_check(assembled_enemies.get_enemy(1).get("id") == "spool_stalker"
			and assembled_enemies.get_enemy(1).get("hp") == 14
			and assembled_enemies.get_enemy(1).get("position") == 1,
			"AC3: assembled slot 1 is Spool Stalker (14 HP)")
		_check(assembled_enemies.get_enemy(2).get("id") == "button_guard"
			and assembled_enemies.get_enemy(2).get("hp") == 16
			and assembled_enemies.get_enemy(2).get("position") == 2,
			"AC3: assembled slot 2 is Button Guard (16 HP)")


func _opening_fight(map: RunMap) -> String:
	for candidate in map.get_legal_choices():
		if map.get_node(candidate).get("type") == "Fight":
			return candidate
	return ""


func _map_with_non_fight_opening() -> Dictionary:
	for value in range(1, 200):
		var rng := _rng(value)
		var map := RunMap.new()
		if not map.generate(rng):
			continue
		for candidate in map.get_legal_choices():
			var kind: String = map.get_node(candidate).get("type", "")
			if kind in ["Fight", "Elite", "Boss"]:
				continue
			map.choose_node(candidate)
			return {"map": map, "node": candidate, "rng": rng}
	return {}
