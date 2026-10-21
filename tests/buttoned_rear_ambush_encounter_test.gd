extends SceneTree

## Deterministic headless coverage for the authored Buttoned Rear Ambush encounter:
## slot 1 Button Guard buffs itself, exposes the back hero, then attacks the front;
## slot 2 Fray Scavenger pressures middle then rear, then blocks itself.
## Data/service only: this file never wires the encounter into live play.

const ENCOUNTER_PATH := "res://data/encounters/buttoned_rear_ambush.json"
const ENCOUNTER_ID := "buttoned_rear_ambush"
const STARTER_PATH := "res://data/encounters/starter_attacks.json"
const FRAYGUARD_PATH := "res://data/encounters/frayguard_attrition.json"
const PARTY_PATH := "res://data/heroes/starter_party.json"
const ENEMY_PATH := "res://data/enemies/run_enemies.json"

const GLOBAL_SEED := 20261021
const RUN_RNG_SEED := 90210

var failures: Array[String] = []
var checks := 0
var phase := CombatEnemyPhase.new()


func _initialize() -> void:
	_test_authored_schedule_and_parser()
	_test_intent_cycle_and_copies()
	_test_real_phase_sequence()
	_test_double_replay()
	_test_downed_slain_and_rejections()
	if failures.is_empty():
		print("buttoned_rear_ambush_encounter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("buttoned_rear_ambush_encounter_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## The exact prescribed schedule for this encounter's own two sources.
func _expected() -> Array:
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "buff", "amount": 3},
			{"type": "debuff", "amount": 1, "target_position": 3, "status": "exposed"},
			{"type": "attack", "amount": 3, "target_position": 1}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 2, "target_position": 2},
			{"type": "attack", "amount": 3, "target_position": 3},
			{"type": "block", "amount": 2}]}
	]


## Literal announced beats, independent of the parsed file and of _expected().
func _first_intents() -> Array:
	return [
		{"type": "buff", "amount": 3, "enemy_position": 1},
		{"type": "attack", "amount": 2, "target_position": 2, "enemy_position": 2}]


func _second_intents() -> Array:
	return [
		{"type": "debuff", "amount": 1, "target_position": 3, "status": "exposed",
			"enemy_position": 1},
		{"type": "attack", "amount": 3, "target_position": 3, "enemy_position": 2}]


func _third_intents() -> Array:
	return [
		{"type": "attack", "amount": 3, "target_position": 1, "enemy_position": 1},
		{"type": "block", "amount": 2, "enemy_position": 2}]


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "opens " + path)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _load_json(path: String) -> Array:
	var parsed: Variant = JSON.parse_string(_read_text(path))
	if not parsed is Array:
		return []
	return _normalize_json(parsed)


func _normalize_json(data) -> Variant:
	if data is Array:
		var result: Array = []
		for item in data:
			result.append(_normalize_json(item))
		return result
	if data is Dictionary:
		var result: Dictionary = {}
		for key in data:
			var value = data[key]
			if value is float and value == int(value):
				value = int(value)
			else:
				value = _normalize_json(value)
			result[key] = value
		return result
	if data is float and data == int(data):
		return int(data)
	return data


func _parsed() -> Array:
	return RunFightEncounterSelection._parse_schedule_text(_read_text(ENCOUNTER_PATH))


func _unique_entry(entries: Array, position: int) -> Dictionary:
	var matches: Array = []
	for entry in entries:
		if entry is Dictionary and entry.get("enemy_position") == position:
			matches.append(entry)
	_check(matches.size() == 1, "exactly one entry at enemy_position %d" % position)
	return {} if matches.is_empty() else matches[0]


func _check_entry(entries: Array, position: int, expected_actions: Array) -> void:
	var entry := _unique_entry(entries, position)
	_check(entry.size() == 2 and entry.has("enemy_position") and entry.has("pattern"),
		"entry %d has exactly enemy_position and pattern" % position)
	var pattern = entry.get("pattern")
	_check(pattern is Array and pattern.size() == expected_actions.size(),
		"entry %d has a %d-action cycle" % [position, expected_actions.size()])
	if not pattern is Array or pattern.size() != expected_actions.size():
		return
	for index in range(expected_actions.size()):
		_check(pattern[index] == expected_actions[index],
			"entry %d turn %d is exactly %s" % [position, index + 1,
				JSON.stringify(expected_actions[index])])


func _check_hero(party: CombatParty, position: int, hp: int, block: int, label: String) -> void:
	var hero := party.get_hero(position)
	_check(hero.get("hp") == hp and hero.get("block") == block,
		"%s: hero %d has %d HP and %d Block (got %d/%d)"
			% [label, position, hp, block, hero.get("hp"), hero.get("block")])


func _check_enemy(enemies: CombatEnemies, position: int, id: String, hp: int, block: int,
		label: String) -> void:
	var enemy := enemies.get_enemy(position)
	_check(enemy.get("id") == id and enemy.get("hp") == hp and enemy.get("block") == block,
		"%s: enemy %d is %s with %d HP and %d Block (got %s %d/%d)"
			% [label, position, id, hp, block, enemy.get("id"), enemy.get("hp"), enemy.get("block")])


func _build_authored_party() -> CombatParty:
	var heroes := _load_json(PARTY_PATH)
	var definitions: Array = []
	for id in ["warden", "seamstress", "tinker"]:
		var matches: Array = []
		for hero in heroes:
			if hero is Dictionary and hero.get("id") == id:
				matches.append(hero)
		_check(matches.size() == 1, "authored hero %s found once" % id)
		definitions.append({} if matches.is_empty() else matches[0].duplicate(true))
	return CombatParty.new(definitions)


func _build_authored_enemies() -> CombatEnemies:
	var enemies := _load_json(ENEMY_PATH)
	var definitions: Array = []
	for id in ["button_guard", "fray_scavenger"]:
		var matches: Array = []
		for enemy in enemies:
			if enemy is Dictionary and enemy.get("id") == id:
				matches.append(enemy)
		_check(matches.size() == 1, "authored enemy %s found once" % id)
		definitions.append({} if matches.is_empty() else matches[0].duplicate(true))
	return CombatEnemies.new(definitions)


func _with_beat(position: int, beat: int, replacement: Dictionary) -> Array:
	var data: Array = _expected().duplicate(true)
	for entry in data:
		if entry["enemy_position"] == position:
			var pattern: Array = entry["pattern"]
			pattern[beat] = replacement
	return data


## AC1
func _test_authored_schedule_and_parser() -> void:
	_check(FileAccess.file_exists(ENCOUNTER_PATH), "new authored encounter file exists")
	_check(ENCOUNTER_PATH.get_file().get_basename() == ENCOUNTER_ID,
		"the schedule file name carries the canonical encounter ID %s" % ENCOUNTER_ID)
	var raw: Variant = JSON.parse_string(_read_text(ENCOUNTER_PATH))
	_check(raw is Array and raw.size() == 2,
		"the authored file holds exactly this encounter's two source records")
	var parsed := _parsed()
	_check(parsed == _expected(), "real parser accepts the file as the exact prescribed schedule")
	_check(parsed.size() == 2, "the parsed schedule has exactly two sources")
	_check(CombatEnemyIntents.new(parsed).is_valid(),
		"CombatEnemyIntents.is_valid() for the new authored JSON")
	_check_entry(parsed, 1, _expected()[0]["pattern"])
	_check_entry(parsed, 2, _expected()[1]["pattern"])
	for entry in parsed:
		_check(entry.get("enemy_position") is int,
			"parsed enemy_position is an int, not a JSON float")
		var pattern: Array = entry["pattern"]
		for action in pattern:
			_check(action.get("amount") is int,
				"parsed beat amount is an int, not a JSON float")
			if action.has("target_position"):
				_check(action.get("target_position") is int,
					"parsed beat target_position is an int, not a JSON float")

	var roster := _load_json(ENEMY_PATH)
	for expected_actor in [{"id": "button_guard", "name": "Button Guard", "max_hp": 16},
			{"id": "fray_scavenger", "name": "Fray Scavenger", "max_hp": 14}]:
		var matches: Array = []
		for enemy in roster:
			if enemy is Dictionary and enemy.get("id") == expected_actor["id"]:
				matches.append(enemy)
		_check(matches.size() == 1, "shipped enemy %s exists exactly once" % expected_actor["id"])
		if matches.size() == 1:
			_check(matches[0].get("name") == expected_actor["name"]
				and matches[0].get("max_hp") == expected_actor["max_hp"],
				"shipped enemy %s is %s with %d max HP"
					% [expected_actor["id"], expected_actor["name"], expected_actor["max_hp"]])

	var party := _build_authored_party()
	_check(party.is_valid(), "shipped starter party builds a real three-hero party")
	_check(party.get_hero(1).get("id") == "warden" and party.get_hero(1).get("max_hp") == 40
		and party.get_hero(2).get("id") == "seamstress" and party.get_hero(2).get("max_hp") == 30
		and party.get_hero(3).get("id") == "tinker" and party.get_hero(3).get("max_hp") == 26,
		"starter party is Warden/Seamstress/Tinker at 40/30/26 HP in positions 1/2/3")

	var starter := RunFightEncounterSelection._parse_schedule_text(_read_text(STARTER_PATH))
	_check(CombatEnemyIntents.new(starter).is_valid(), "starter_attacks still valid")
	var frayguard := RunFightEncounterSelection._parse_schedule_text(_read_text(FRAYGUARD_PATH))
	_check(CombatEnemyIntents.new(frayguard).is_valid(), "frayguard_attrition still valid")
	_check(starter != parsed and frayguard != parsed,
		"the new schedule differs from both named earlier schedules")
	_check_entry(starter, 1, [{"type": "attack", "amount": 1, "target_position": 1},
		{"type": "attack", "amount": 1, "target_position": 2},
		{"type": "attack", "amount": 1, "target_position": 3}])
	_check_entry(starter, 2, [{"type": "block", "amount": 1}])
	_check_entry(frayguard, 1, [{"type": "debuff", "amount": 2, "target_position": 3, "status": "bleed"},
		{"type": "attack", "amount": 3, "target_position": 3},
		{"type": "attack", "amount": 2, "target_position": 2}])
	_check_entry(frayguard, 2, [{"type": "block", "amount": 4},
		{"type": "attack", "amount": 2, "target_position": 1},
		{"type": "buff", "amount": 2}])


## Intent cycle + copies
func _test_intent_cycle_and_copies() -> void:
	var definitions := _parsed()
	var intents := CombatEnemyIntents.new(definitions)
	_check(intents.get_intents() == _first_intents(), "turn 1 announces the exact first beats")
	_check(intents.advance_turn(), "advance to turn 2")
	_check(intents.get_intents() == _second_intents(), "turn 2 announces the exact second beats")
	_check(intents.advance_turn(), "advance to turn 3")
	_check(intents.get_intents() == _third_intents(), "turn 3 announces the exact third beats")
	_check(intents.advance_turn(), "advance past the third beat")
	_check(intents.get_intents() == _first_intents(),
		"turn 4 repeats the first announced intents exactly")

	for turn in range(4):
		var announced := intents.get_intents()
		_check(announced.size() == 2 and announced[0].get("enemy_position") == 1
			and announced[1].get("enemy_position") == 2,
			"announcement %d lists slot 1 then slot 2" % (turn + 1))
		intents.advance_turn()

	seed(GLOBAL_SEED)
	var baseline := randi()
	seed(GLOBAL_SEED)
	var probe := CombatEnemyIntents.new(definitions)
	for turn in range(7):
		probe.get_intents()
		probe.advance_turn()
	_check(randi() == baseline, "constructing, viewing and advancing this schedule draws no global RNG")
	seed(GLOBAL_SEED)
	var without_extra := randi()
	seed(GLOBAL_SEED)
	randi()
	_check(randi() != without_extra, "the global RNG probe detects an injected extra draw")

	var snapshot_selector := CombatEnemyIntents.new(_expected().duplicate(true))
	var snapshot := snapshot_selector.get_intents()
	_check(snapshot == _first_intents(), "snapshot is the exact first announced beats")
	snapshot[0]["type"] = "block"
	snapshot[0]["amount"] = 99
	snapshot.append({"enemy_position": 3, "type": "block", "amount": 5})
	_check(snapshot_selector.get_intents() == _first_intents(),
		"mutating a returned announcement cannot alter later intents")
	_check(definitions == _expected(), "parsed schedule starts from its prescribed source")
	var isolated := CombatEnemyIntents.new(definitions)
	var parsed_pattern: Array = definitions[0]["pattern"]
	parsed_pattern[0]["amount"] = 7
	_check(isolated.get_intents() == _first_intents(),
		"mutating the parsed source cannot alter an independently constructed intent selector")


## AC2 phase sequence
func _test_real_phase_sequence() -> void:
	var party := _build_authored_party()
	_check(party.is_valid(), "authored party is valid")
	var enemies := _build_authored_enemies()
	_check(enemies.is_valid(), "authored two-enemy roster is valid")
	_check_enemy(enemies, 1, "button_guard", 16, 0, "start")
	_check_enemy(enemies, 2, "fray_scavenger", 14, 0, "start")

	var opening := CombatStartingBlock.new(party)
	_check(opening.apply(), "Warden opening Block 6 applies once")
	_check_hero(party, 1, 40, 6, "opening")
	_check(not opening.apply(), "opening Block cannot be applied twice")

	var scheduler := CombatEnemyIntents.new(_parsed())
	_check(scheduler.get_intents() == _first_intents(), "T1 announces buff then attack")

	var turn1 := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(turn1.get("ok") == true, "T1 phase succeeds")
	_check(turn1.get("events") == [
		{"type": "buff", "enemy_position": 1, "applied": true},
		{"type": "attack", "enemy_position": 2, "target_position": 2, "applied": true}],
		"T1 events: slot-1 self buff then slot-2 attack on middle, both applied")
	_check_hero(party, 1, 40, 6, "T1")
	_check_hero(party, 2, 28, 0, "T1")
	_check_hero(party, 3, 26, 0, "T1")
	_check(party.get_hero(2).get("statuses", {}) == {},
		"T1 Seamstress carries no status")
	_check(party.get_hero(3).get("statuses", {}) == {},
		"T1 Tinker carries no status")
	_check_enemy(enemies, 1, "button_guard", 16, 3, "T1")
	_check_enemy(enemies, 2, "fray_scavenger", 14, 0, "T1")

	_check(scheduler.advance_turn(), "explicit advance to turn 2")

	var turn2 := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(turn2.get("ok") == true, "T2 phase succeeds")
	_check(turn2.get("events") == [
		{"type": "debuff", "enemy_position": 1, "target_position": 3, "status": "exposed",
			"applied": true},
		{"type": "attack", "enemy_position": 2, "target_position": 3, "applied": true}],
		"T2 events: slot-1 Exposed then slot-2 attack on rear, both applied")
	_check_hero(party, 1, 40, 6, "T2")
	_check_hero(party, 2, 28, 0, "T2")
	_check_hero(party, 3, 22, 0, "T2")
	_check(party.get_hero(3).get("statuses", {}) == {"exposed": 1},
		"T2 Tinker keeps exactly Exposed 1")
	_check(party.get_hero(1).get("statuses", {}) == {} and party.get_hero(2).get("statuses", {}) == {},
		"T2 only the debuffed hero carries a status")
	_check_enemy(enemies, 1, "button_guard", 16, 3, "T2")
	_check_enemy(enemies, 2, "fray_scavenger", 14, 0, "T2")

	_check(scheduler.advance_turn(), "explicit advance to turn 3")

	var turn3 := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(turn3.get("ok") == true, "T3 phase succeeds")
	_check(turn3.get("events") == [
		{"type": "attack", "enemy_position": 1, "target_position": 1, "applied": true},
		{"type": "block", "enemy_position": 2, "applied": true}],
		"T3 events: slot-1 attack on front then slot-2 self block, both applied")
	_check_hero(party, 1, 40, 3, "T3")
	_check_hero(party, 2, 28, 0, "T3")
	_check_hero(party, 3, 22, 0, "T3")
	_check(party.get_hero(3).get("statuses", {}) == {"exposed": 1},
		"T3 Exposed 1 is retained: the enemy phase validates the owner tick but leaves status aging to the round flow")
	_check_enemy(enemies, 1, "button_guard", 16, 3, "T3")
	_check_enemy(enemies, 2, "fray_scavenger", 14, 2, "T3")

	# Detached owner-tick check: tick_side proposes aging but does not write the party.
	var batch := CombatStatusTurnBatch.new()
	var proposed := batch.tick_side("heroes", party.get_heroes())
	_check(proposed.get("ok") == true, "detached owner tick is valid")
	_check(party.get_hero(3).get("statuses", {}) == {"exposed": 1},
		"the detached tick does not age Exposed on the real party")
	_check(proposed.get("actors", [])[2].get("statuses", {}) == {},
		"the detached tick proposes Exposed aging only on its own result")

	_check(scheduler.advance_turn(), "explicit advance past the third beat")
	_check(scheduler.get_intents() == _first_intents(),
		"after exactly three advances the schedule announces its first intents again")


## AC3 double replay
func _play_three_turns() -> Dictionary:
	var party := _build_authored_party()
	var enemies := _build_authored_enemies()
	var opening := CombatStartingBlock.new(party)
	_check(opening.apply(), "replay precondition: Warden opening Block applies")
	var scheduler := CombatEnemyIntents.new(_parsed())
	var events: Array = []
	for turn in range(3):
		events.append(phase.execute_phase(party, enemies, scheduler.get_intents()))
		_check(scheduler.advance_turn(), "replay advance after turn %d" % (turn + 1))
	return {"events": events, "heroes": party.get_heroes(), "enemies": enemies.get_enemies(),
		"repeating": scheduler.get_intents()}


func _test_double_replay() -> void:
	seed(GLOBAL_SEED)
	var expected_rng := randi()
	seed(GLOBAL_SEED)
	var first := _play_three_turns()
	_check(randi() == expected_rng,
		"three real authored phases draw no global RNG")
	var second := _play_three_turns()
	_check(first["events"].size() == 3 and second["events"].size() == 3,
		"each replay resolved exactly three enemy phases")
	_check(first["heroes"].size() == 3 and first["enemies"].size() == 2,
		"each replay ends with the complete authored formation")
	_check(first["heroes"][0]["hp"] == 40 and first["heroes"][0]["block"] == 3
		and first["heroes"][0].get("statuses", {}) == {}
		and first["heroes"][1]["hp"] == 28 and first["heroes"][1]["block"] == 0
		and first["heroes"][1].get("statuses", {}) == {}
		and first["heroes"][2]["hp"] == 22 and first["heroes"][2]["block"] == 0
		and first["heroes"][2].get("statuses", {}) == {"exposed": 1},
		"replay end state is Warden 40/3, Seamstress 28/0, Tinker 22/0 with Exposed 1")
	_check(first["enemies"][0]["id"] == "button_guard" and first["enemies"][0]["hp"] == 16
		and first["enemies"][0]["block"] == 3
		and first["enemies"][1]["id"] == "fray_scavenger" and first["enemies"][1]["hp"] == 14
		and first["enemies"][1]["block"] == 2,
		"replay end state is Button Guard 16/3 and Fray Scavenger 14/2")
	_check(first["repeating"] == _first_intents() and second["repeating"] == _first_intents(),
		"both copies return to the first announced intents on turn 4")
	_check(first["events"] == second["events"],
		"two independently constructed copies produce identical phase results")
	_check(first["heroes"] == second["heroes"] and first["enemies"] == second["enemies"],
		"two independently constructed copies end in identical party and enemy state")


## AC3 downed, slain, malformed
func _test_downed_slain_and_rejections() -> void:
	var phase_local := CombatEnemyPhase.new()

	# Downed Tinker before beat 2 rejects the whole phase.
	var downed_party := _build_authored_party()
	var downed_enemies := _build_authored_enemies()
	_check(CombatStartingBlock.new(downed_party).apply(), "downed: opening Block applied")
	var downed_scheduler := CombatEnemyIntents.new(_parsed())
	_check(phase_local.execute_phase(downed_party, downed_enemies, downed_scheduler.get_intents()).get("ok") == true,
		"downed: beat 1 succeeds before downing Tinker")
	_check(downed_scheduler.advance_turn(), "downed: advance to beat 2")
	_check(downed_party.apply_damage(3, 26) and downed_party.is_downed(3),
		"downed: Tinker is downed at 0 HP")
	var downed_party_before := downed_party.get_heroes()
	var downed_enemies_before := downed_enemies.get_enemies()
	var downed_intents_before := downed_scheduler.get_intents().duplicate(true)
	var downed_rng := RandomNumberGenerator.new()
	downed_rng.seed = RUN_RNG_SEED
	var downed_rng_before := downed_rng.state
	seed(GLOBAL_SEED)
	var downed_global_expected := randi()
	seed(GLOBAL_SEED)
	var downed_result := phase_local.execute_phase(downed_party, downed_enemies, downed_scheduler.get_intents())
	_check(downed_result == {"ok": false, "events": []},
		"downed: Weak/Exposed on downed Tinker rejects the whole beat-2 phase")
	_check(downed_party.get_heroes() == downed_party_before,
		"downed: no partial party mutation survives")
	_check(downed_enemies.get_enemies() == downed_enemies_before,
		"downed: no enemy mutation survives")
	_check(downed_scheduler.get_intents() == downed_intents_before,
		"downed: caller intents are unchanged")
	_check(downed_scheduler.get_intents() == _second_intents(),
		"downed: a rejected phase causes no intent progression")
	_check(randi() == downed_global_expected and downed_rng.state == downed_rng_before,
		"downed: a rejected phase consumes no RNG")

	# Slain first source before beat 2: debuff unapplied, source 2 deals unmodified 3.
	var slain_party := _build_authored_party()
	var slain_enemies := _build_authored_enemies()
	_check(CombatStartingBlock.new(slain_party).apply(), "slain: opening Block applied")
	var slain_scheduler := CombatEnemyIntents.new(_parsed())
	_check(phase_local.execute_phase(slain_party, slain_enemies, slain_scheduler.get_intents()).get("ok") == true,
		"slain: beat 1 succeeds before slaying source 1")
	_check(slain_scheduler.advance_turn(), "slain: advance to beat 2")
	_check(slain_enemies.apply_damage(1, 19) and slain_enemies.is_slain(1)
		and not slain_enemies.is_slain(2), "slain: Button Guard slain, Fray Scavenger lives")
	var slain_result := phase_local.execute_phase(slain_party, slain_enemies, slain_scheduler.get_intents())
	_check(slain_result == {"ok": true, "events": [
		{"type": "debuff", "enemy_position": 1, "target_position": 3, "status": "exposed",
			"applied": false},
		{"type": "attack", "enemy_position": 2, "target_position": 3, "applied": true}]},
		"slain: source 1 debuff unapplied while source 2 hits the rear")
	_check_hero(slain_party, 3, 23, 0, "slain")
	_check(slain_party.get_hero(3).get("statuses", {}) == {},
		"slain: Exposed is not applied to living Tinker")
	_check_enemy(slain_enemies, 1, "button_guard", 0, 0, "slain")
	_check_enemy(slain_enemies, 2, "fray_scavenger", 14, 0, "slain")

	# Malformed schedules fail closed through the canonical parser.
	var duplicate_slot := [
		{"enemy_position": 1, "pattern": [{"type": "buff", "amount": 3}]},
		{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 2, "target_position": 2}]}
	]
	_check(RunFightEncounterSelection._parse_schedule_text(JSON.stringify(duplicate_slot)).is_empty(),
		"duplicate enemy slot fails closed")
	var fractional := _with_beat(1, 0, {"type": "buff", "amount": 1.5})
	_check(RunFightEncounterSelection._parse_schedule_text(JSON.stringify(fractional)).is_empty(),
		"fractional buff amount fails closed")
	var target_four := _with_beat(2, 0, {"type": "attack", "amount": 2, "target_position": 4})
	_check(RunFightEncounterSelection._parse_schedule_text(JSON.stringify(target_four)).is_empty(),
		"off-board target 4 fails closed")
	var fractional_target := _with_beat(2, 1, {"type": "attack", "amount": 3, "target_position": 2.5})
	_check(RunFightEncounterSelection._parse_schedule_text(JSON.stringify(fractional_target)).is_empty(),
		"fractional target fails closed")

	# Valid authored file remains unchanged after all reads.
	var pristine := _read_text(ENCOUNTER_PATH)
	_check(_read_text(ENCOUNTER_PATH) == pristine, "authored file unchanged after parser reads")