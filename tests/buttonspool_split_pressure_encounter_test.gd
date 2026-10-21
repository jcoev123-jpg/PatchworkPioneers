extends SceneTree
## Deterministic headless coverage for the standalone authored Buttonspool Split
## Pressure M04 normal Fight: source slot 1 Button Guard (Block 2, a 3-damage
## hit on the middle, Weak 1 on itself) and source slot 2 Spool Stalker (a
## 4-damage hit on the rear, Bleed 2 on the middle, a 3-damage hit on the
## front). This file only authors and verifies the schedule and its real
## service resolution; it does NOT publish the encounter into
## data/encounters/m03_typed_battle_pools.json, the app scene or any live
## play path (a later owner publishes it with routed-battle tests).

const ENCOUNTER_PATH := "res://data/encounters/buttonspool_split_pressure.json"
const ENCOUNTER_ID := "buttonspool_split_pressure"
const PARTY_PATH := "res://data/heroes/starter_party.json"
const ENEMY_PATH := "res://data/enemies/run_enemies.json"
const THREADBITE_PATH := "res://data/encounters/threadbite_midline_press.json"
const BUTTONFRONT_PATH := "res://data/encounters/buttonfront_pinfall.json"
const SHARED_POOL_PATH := "res://data/encounters/m03_typed_battle_pools.json"
const HERO_IDS := ["warden", "seamstress", "tinker"]
# Encounter slot order: 1 Button Guard, 2 Spool Stalker.
const ENEMY_IDS := ["button_guard", "spool_stalker"]
const SELECTION_SEED := 1092026

var failures: Array[String] = []
var checks := 0
var phase := CombatEnemyPhase.new()


func _initialize() -> void:
	_test_authored_schedule_and_catalog()
	_test_companion_schedules_still_valid()
	_test_intent_cycle()
	_test_phase_one_block_and_rear_hit()
	_test_phase_two_middle_hit_and_bleed()
	_test_phase_three_weak_and_front_hit()
	_test_block_absorbs_before_hp()
	_test_full_cycle_and_wrap()
	_test_slain_source_skips_action()
	_test_fail_closed_boundaries()
	_test_selection_failures()
	_test_selection_draw_discipline()
	_test_selection_cache_and_replay()
	if failures.is_empty():
		print("buttonspool_split_pressure_encounter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("buttonspool_split_pressure_encounter_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## Proves that the wrapped code consumed no GLOBAL RNG draw. The control probe
## in _test_intent_cycle proves that an injected extra draw really is caught.
func _global_probe(label: String, body: Callable) -> void:
	seed(20261022)
	var expected := randi()
	seed(20261022)
	body.call()
	_check(randi() == expected, label)


## The exact prescribed schedule for this encounter's own two sources.
func _expected() -> Array:
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "block", "amount": 2},
			{"type": "attack", "amount": 3, "target_position": 2},
			{"type": "debuff", "amount": 1, "target_position": 1, "status": "weak"}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 4, "target_position": 3},
			{"type": "debuff", "amount": 2, "target_position": 2, "status": "bleed"},
			{"type": "attack", "amount": 3, "target_position": 1}]},
	]


## Literal announced beats, independent of the parsed file and of _expected().
func _intents_for(beat: int) -> Array:
	var beats: Array = [
		[{"type": "block", "amount": 2, "enemy_position": 1},
			{"type": "attack", "amount": 4, "target_position": 3, "enemy_position": 2}],
		[{"type": "attack", "amount": 3, "target_position": 2, "enemy_position": 1},
			{"type": "debuff", "amount": 2, "target_position": 2, "status": "bleed",
				"enemy_position": 2}],
		[{"type": "debuff", "amount": 1, "target_position": 1, "status": "weak",
				"enemy_position": 1},
			{"type": "attack", "amount": 3, "target_position": 1, "enemy_position": 2}],
	]
	return beats[beat % beats.size()]


## Literal per-beat resolution through the real phase services.
func _events_for(beat: int) -> Array:
	var beats: Array = [
		[{"type": "block", "enemy_position": 1, "applied": true},
			{"type": "attack", "enemy_position": 2, "applied": true, "target_position": 3}],
		[{"type": "attack", "enemy_position": 1, "applied": true, "target_position": 2},
			{"type": "debuff", "enemy_position": 2, "applied": true, "target_position": 2,
				"status": "bleed"}],
		[{"type": "debuff", "enemy_position": 1, "applied": true, "target_position": 1,
				"status": "weak"},
			{"type": "attack", "enemy_position": 2, "applied": true, "target_position": 1}],
	]
	return beats[beat % beats.size()]


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "opens " + path)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


## Godot may hand whole JSON numbers to the rules as floats; authored catalog
## records are normalized exactly so the real model services see ints.
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
		if hp is float:
			if is_nan(hp) or is_inf(hp) or hp <= 0 or hp > 9007199254740991.0 \
					or floorf(hp) != hp:
				return []
			record["max_hp"] = int(hp)
		elif not hp is int or hp <= 0:
			return []
		records.append(record)
	return records


func _parsed() -> Array:
	return RunFightEncounterSelection._parse_schedule_text(_read_text(ENCOUNTER_PATH))


## One named record, located by its own ID (never by list order).
func _record(records: Array, id: String, label: String) -> Dictionary:
	var matches: Array = []
	for record in records:
		if record is Dictionary and record.get("id") == id:
			matches.append(record)
	_check(matches.size() == 1, "%s %s appears exactly once" % [label, id])
	return {} if matches.size() != 1 else matches[0].duplicate(true)


## One named entry, located by its own enemy_position (never by list order).
func _unique_entry(entries: Array, position: int) -> Dictionary:
	var matches: Array = []
	for entry in entries:
		if entry is Dictionary and entry.get("enemy_position") == position:
			matches.append(entry)
	_check(matches.size() == 1, "exactly one entry at enemy_position %d" % position)
	return {} if matches.size() != 1 else matches[0]


## Complete, ordered per-source action assertions.
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
	var records := _load_records(PARTY_PATH)
	var definitions: Array = []
	for id in HERO_IDS:
		definitions.append(_record(records, id, "authored hero"))
	return CombatParty.new(definitions)


func _build_enemies() -> CombatEnemies:
	var records := _load_records(ENEMY_PATH)
	var definitions: Array = []
	for id in ENEMY_IDS:
		definitions.append(_record(records, id, "authored enemy"))
	return CombatEnemies.new(definitions)


func _fixture_ok(party: CombatParty, enemies: CombatEnemies, label: String) -> bool:
	var valid := party.is_valid() and enemies.is_valid()
	_check(valid, label + ": real starter CombatParty and authored CombatEnemies are valid")
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
			label + ": %s sits in slot %d with %d HP, no Block and no status"
				% [id, index + 1, hp])
	for index in range(2):
		var enemy := enemies.get_enemy(index + 1)
		var id: String = ["button_guard", "spool_stalker"][index]
		var hp: int = [16, 14][index]
		_check(enemy.get("id") == id and enemy.get("hp") == hp
			and enemy.get("max_hp") == hp and enemy.get("block") == 0
			and enemy.get("position") == index + 1,
			label + ": %s sits in slot %d with %d HP and no Block" % [id, index + 1, hp])
	return true


## AC1: the shipped file is exactly the prescribed two-source, three-beat
## schedule, and the catalog actors it names keep their identities and stats.
func _test_authored_schedule_and_catalog() -> void:
	_check(FileAccess.file_exists(ENCOUNTER_PATH), "new authored encounter file exists")
	_check(ENCOUNTER_PATH.get_file().get_basename() == ENCOUNTER_ID,
		"the schedule file name carries the canonical encounter ID %s" % ENCOUNTER_ID)
	var raw := _read_text(ENCOUNTER_PATH)
	var raw_json: Variant = JSON.parse_string(raw)
	_check(raw_json is Array and raw_json.size() == 2,
		"the authored file holds exactly this encounter's two source records")
	var parsed := _parsed()
	var expected := _expected()
	_check(parsed == expected, "real parser accepts the file as the exact prescribed schedule")
	_check(parsed.size() == 2, "the parsed schedule has exactly two sources")
	var positions: Array[int] = []
	for entry in parsed:
		if entry is Dictionary and entry.get("enemy_position") is int:
			positions.append(entry["enemy_position"])
	positions.sort()
	_check(positions == [1, 2], "the parsed schedule has the unique source positions 1 and 2")
	_check(CombatEnemyIntents.new(parsed).is_valid(),
		"CombatEnemyIntents.is_valid() for the new authored JSON")
	_check_entry(parsed, 1, expected[0]["pattern"])
	_check_entry(parsed, 2, expected[1]["pattern"])
	_check_entry(parsed, 1, [
		{"type": "block", "amount": 2},
		{"type": "attack", "amount": 3, "target_position": 2},
		{"type": "debuff", "amount": 1, "target_position": 1, "status": "weak"}])
	_check_entry(parsed, 2, [
		{"type": "attack", "amount": 4, "target_position": 3},
		{"type": "debuff", "amount": 2, "target_position": 2, "status": "bleed"},
		{"type": "attack", "amount": 3, "target_position": 1}])
	for entry in parsed:
		_check(entry.get("enemy_position") is int,
			"parsed enemy_position is an int, not a JSON float")
		var pattern: Array = entry["pattern"]
		_check(pattern.size() == 3,
			"source %d has exactly the three-action cycle" % entry["enemy_position"])
		for action in pattern:
			_check(action.get("amount") is int,
				"parsed beat amount is an int, not a JSON float")
			if action.has("target_position"):
				_check(action.get("target_position") is int,
					"parsed beat target_position is an int, not a JSON float")
	_check(CombatEnemyIntents.new(_expected()).is_valid(),
		"the literal prescription itself validates")
	_check(_read_text(ENCOUNTER_PATH) == raw,
		"the authored file bytes stay unchanged after validation")

	# The named actors really exist, exactly once each, with the stats this
	# schedule is authored against; slot order is 1 Button Guard, 2 Spool Stalker.
	var enemy_records := _load_records(ENEMY_PATH)
	var guard := _record(enemy_records, "button_guard", "authored enemy")
	var stalker := _record(enemy_records, "spool_stalker", "authored enemy")
	_check(guard.get("name") == "Button Guard" and guard.get("max_hp") == 16
		and guard.get("max_hp") is int,
		"shipped button_guard is Button Guard with 16 integer max HP")
	_check(stalker.get("name") == "Spool Stalker" and stalker.get("max_hp") == 14
		and stalker.get("max_hp") is int,
		"shipped spool_stalker is Spool Stalker with 14 integer max HP")
	_check(guard.get("art_path") == "res://assets/paper/enemies/button_guard.png"
		and stalker.get("art_path") == "res://assets/paper/enemies/spool_stalker.png",
		"both shipped enemies keep their existing paper-art paths")

	var enemies := _build_enemies()
	_check(enemies.is_valid() and enemies.get_enemies().size() == 2,
		"authored two-enemy roster is valid")
	var roster_ids: Array = []
	for enemy in enemies.get_enemies():
		roster_ids.append(enemy.get("id"))
	_check(roster_ids == ENEMY_IDS,
		"the constructed roster is exactly the two catalog records in this order")
	_check(enemies.get_enemy(1).get("name") == "Button Guard"
		and enemies.get_enemy(1).get("position") == 1
		and enemies.get_enemy(1).get("hp") == 16,
		"Button Guard keeps its name, slot 1 and 16 HP")
	_check(enemies.get_enemy(2).get("name") == "Spool Stalker"
		and enemies.get_enemy(2).get("position") == 2
		and enemies.get_enemy(2).get("hp") == 14,
		"Spool Stalker keeps its name, slot 2 and 14 HP")

	var party := _build_party()
	_check(party.is_valid(), "shipped starter party builds a real three-hero party")
	_check(_hero_ledger(party.get_heroes()) == [[40, 0], [30, 0], [26, 0]],
		"the party starts Warden 40, Seamstress 30, Tinker 26, all with no Block")
	_check(party.get_hero(1).get("name") == "Warden"
		and party.get_hero(1).get("max_hp") == 40,
		"starter slot 1 is Warden with 40 max HP")
	_check(party.get_hero(2).get("name") == "Seamstress"
		and party.get_hero(2).get("max_hp") == 30,
		"starter slot 2 is Seamstress with 30 max HP")
	_check(party.get_hero(3).get("name") == "Tinker"
		and party.get_hero(3).get("max_hp") == 26,
		"starter slot 3 is Tinker with 26 max HP")


## AC1/AC4: the two named earlier schedules still parse by their own content,
## and this standalone schedule stays out of the shared typed pool.
func _test_companion_schedules_still_valid() -> void:
	var threadbite := RunFightEncounterSelection._parse_schedule_text(_read_text(THREADBITE_PATH))
	_check(threadbite.size() == 2, "threadbite_midline_press still parses its two sources")
	_check_entry(threadbite, 1, [
		{"type": "debuff", "amount": 2, "target_position": 2, "status": "bleed"},
		{"type": "attack", "amount": 3, "target_position": 1},
		{"type": "block", "amount": 2}])
	_check_entry(threadbite, 2, [
		{"type": "attack", "amount": 3, "target_position": 2},
		{"type": "attack", "amount": 2, "target_position": 3},
		{"type": "buff", "amount": 2}])
	_check(CombatEnemyIntents.new(threadbite).is_valid(),
		"threadbite_midline_press still validates in CombatEnemyIntents")

	var buttonfront := RunFightEncounterSelection._parse_schedule_text(_read_text(BUTTONFRONT_PATH))
	_check(buttonfront.size() == 2, "buttonfront_pinfall still parses its two sources")
	_check_entry(buttonfront, 1, [
		{"type": "debuff", "amount": 1, "target_position": 1, "status": "exposed"},
		{"type": "block", "amount": 2},
		{"type": "attack", "amount": 3, "target_position": 2}])
	_check_entry(buttonfront, 2, [
		{"type": "attack", "amount": 4, "target_position": 1},
		{"type": "attack", "amount": 3, "target_position": 3},
		{"type": "buff", "amount": 2}])
	_check(CombatEnemyIntents.new(buttonfront).is_valid(),
		"buttonfront_pinfall still validates in CombatEnemyIntents")

	var pools: Variant = JSON.parse_string(_read_text(SHARED_POOL_PATH))
	_check(pools is Dictionary, "the shared typed battle pool still parses")
	_check(not _shared_pool_registers_encounter(),
		"the standalone %s stays out of the shared typed battle pool" % ENCOUNTER_ID)
	if pools is Dictionary:
		var fight_entries = pools.get("Fight")
		_check(fight_entries is Dictionary and (fight_entries as Dictionary).has("starter_attacks"),
			"an earlier Fight remains present in the shared pool by ID")


## True only when the shared typed pool registers this encounter by its own ID
## or by its schedule path. The pool is a shared catalog other lanes append to,
## so this looks the encounter up by its own identity, never by a total.
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


## AC3: three announced beats in ascending source order, then an exact wrap,
## with independent snapshots, no implicit advance and no RNG consumption.
func _test_intent_cycle() -> void:
	var definitions := _parsed()
	var pristine := definitions.duplicate(true)
	var first := CombatEnemyIntents.new(definitions.duplicate(true))
	var second := CombatEnemyIntents.new(definitions.duplicate(true))
	_check(first.is_valid() and second.is_valid(),
		"two independent schedulers accept the authored schedule")
	if not first.is_valid() or not second.is_valid():
		return

	for beat in range(3):
		var announced := first.get_intents()
		var replayed := second.get_intents()
		_check(announced == _intents_for(beat),
			"beat %d announces exactly the authored per-source actions" % (beat + 1))
		_check(replayed == _intents_for(beat),
			"an independent instance announces the same pair at beat %d" % (beat + 1))
		_check(announced.size() == 2
			and announced[0].get("enemy_position") == 1
			and announced[1].get("enemy_position") == 2,
			"beat %d lists source slot 1 then source slot 2" % (beat + 1))
		_check(first._turn_index == beat,
			"beat %d reports turn index %d (reading never advances)" % [beat + 1, beat])
		# The announced snapshot is a deep copy: editing the returned array in
		# place cannot change later reads.
		announced[0]["amount"] = 999
		announced[0]["type"] = "invented"
		announced[1]["target_position"] = 99
		announced.append({"enemy_position": 3, "type": "block", "amount": 5})
		_check(announced[0].get("type") == "invented" and announced.size() == 3,
			"beat %d: the caller's own copy really was edited in place" % (beat + 1))
		_check(first.get_intents() == _intents_for(beat),
			"beat %d returned announcements are detached deep copies" % (beat + 1))
		_check(second.get_intents() == _intents_for(beat),
			"beat %d the other instance is unaffected by the caller's edit" % (beat + 1))
		_check(first._turn_index == beat,
			"beat %d editing an announcement cannot advance the cycle" % (beat + 1))
		if beat < 2:
			_check(first.advance_turn() and second.advance_turn(),
				"advance from beat %d" % (beat + 1))

	_check(first.advance_turn() and second.advance_turn(),
		"advance from the third beat to the wrap")
	_check(first.get_intents() == _intents_for(0)
		and second.get_intents() == _intents_for(0),
		"the fourth announced beat wraps to the first authored pair")
	_check(first._turn_index == 3 and second._turn_index == 3,
		"the wrap follows exactly three advances")
	_check(definitions == pristine, "the parsed source stays exactly as authored")

	# The whole fixed cycle, viewed and advanced, draws no global RNG.
	var cycle_body := func() -> void:
		var probe := CombatEnemyIntents.new(definitions.duplicate(true))
		for turn in range(8):
			probe.get_intents()
			probe.advance_turn()
	_global_probe(
		"AC3: constructing, viewing and advancing this schedule draws no global RNG",
		cycle_body)
	seed(20261022)
	var without_extra := randi()
	seed(20261022)
	randi()
	_check(randi() != without_extra,
		"control: the global RNG probe detects an injected extra draw")


## AC3: phase 1 resolves Button Guard Block 2 plus a 4-damage hit on Tinker.
func _test_phase_one_block_and_rear_hit() -> void:
	var party := _build_party()
	var enemies := _build_enemies()
	if not _fixture_ok(party, enemies, "AC3 phase 1"):
		return
	var scheduler := CombatEnemyIntents.new(_parsed())
	_check(scheduler.is_valid(), "AC3 phase 1: the parsed schedule instantiates")
	if not scheduler.is_valid():
		return
	var announced: Array = scheduler.get_intents()
	_check(announced == _intents_for(0), "AC3 phase 1 announces the authored first pair")
	var input_copy: Array = announced.duplicate(true)
	# The probe runs on its own fixture so the measured phase stays untouched.
	var probe_party := _build_party()
	var probe_enemies := _build_enemies()
	var phase_body := func() -> void:
		phase.execute_phase(probe_party, probe_enemies, announced)
	_global_probe("AC3 phase 1: the real phase draws no global RNG", phase_body)
	var result := phase.execute_phase(party, enemies, announced)
	_check(result == {"ok": true, "events": _events_for(0)},
		"AC3 phase 1 resolves exactly the Block and rear-hit events")
	_check(result.get("events", []).size() == 2
		and result.get("events", [])[0].get("enemy_position") == 1
		and result.get("events", [])[1].get("enemy_position") == 2,
		"AC3 phase 1 events are in ascending enemy-source order")
	_check(announced == input_copy, "AC3 phase 1 leaves the caller intents untouched")
	_check(scheduler._turn_index == 0 and scheduler.get_intents() == _intents_for(0),
		"AC3 phase 1 does not advance or mutate the announcement cycle")

	_check(enemies.get_enemy(1).get("id") == "button_guard"
		and enemies.get_enemy(1).get("hp") == 16
		and enemies.get_enemy(1).get("block") == 2,
		"AC3 phase 1: the Button Guard gains exactly 2 Block and keeps its 16 HP")
	_check(enemies.get_enemy(2).get("id") == "spool_stalker"
		and enemies.get_enemy(2).get("hp") == 14
		and enemies.get_enemy(2).get("block") == 0,
		"AC3 phase 1: the Spool Stalker is untouched")
	_check(party.get_hero(3).get("hp") == 26 - 4 and party.get_hero(3).get("block") == 0,
		"AC3 phase 1: the Tinker takes the 4-damage hit (26 -> 22 HP)")
	_check(party.get_hero(1).get("hp") == 40 and party.get_hero(2).get("hp") == 30,
		"AC3 phase 1: the Warden and the Seamstress are unhurt")
	_check(_hero_ledger(party.get_heroes()) == [[40, 0], [30, 0], [22, 0]],
		"AC3 phase 1 hero HP/Block ledger")
	_check(_enemy_ledger(enemies.get_enemies()) == [[16, 2], [14, 0]],
		"AC3 phase 1 enemy HP/Block ledger")


## AC3: phase 2 resolves a 3-damage hit on the Seamstress plus Bleed 2, and
## the Bleed does not tick inside the enemy phase.
func _test_phase_two_middle_hit_and_bleed() -> void:
	var party := _build_party()
	var enemies := _build_enemies()
	if not _fixture_ok(party, enemies, "AC3 phase 2"):
		return
	var scheduler := CombatEnemyIntents.new(_parsed())
	_check(scheduler.advance_turn(), "AC3 phase 2: the cycle advances once")
	var announced: Array = scheduler.get_intents()
	_check(announced == _intents_for(1), "AC3 phase 2 announces the authored second pair")
	var result := phase.execute_phase(party, enemies, announced)
	_check(result == {"ok": true, "events": _events_for(1)},
		"AC3 phase 2 resolves exactly the middle-hit and Bleed events")
	_check(party.get_hero(2).get("hp") == 27,
		"AC3 phase 2: the Seamstress takes the 3-damage hit (30 -> 27 HP)")
	_check(party.get_hero(2).get("statuses") == {"bleed": 2},
		"AC3 phase 2: the Seamstress receives exactly Bleed 2")
	_check(party.get_hero(2).get("hp") == 27
		and party.get_hero(2).get("statuses") == {"bleed": 2},
		"AC3 phase 2: the Bleed did not tick during the enemy phase (27 HP, still Bleed 2)")
	_check(party.get_hero(1).get("hp") == 40 and party.get_hero(3).get("hp") == 26,
		"AC3 phase 2: the Warden and the Tinker are unhurt")
	_check(_hero_ledger(party.get_heroes()) == [[40, 0], [27, 0], [26, 0]],
		"AC3 phase 2 hero HP/Block ledger")
	_check(enemies.get_enemy(1).get("block") == 0,
		"AC3 phase 2: the Button Guard has no Block action this beat")

	# The Bleed becomes HP loss at the owner's own turn boundary, through the
	# real status service rather than an ad hoc decrement.
	var before: Array = party.get_heroes()
	var tick := CombatStatusTurnBatch.new().tick_side("heroes", party.get_heroes())
	_check(tick.get("ok") == true and tick.get("actors", []).size() == 3,
		"AC3 phase 2: the real hero owner-turn tick accepts all three slots")
	var actors: Array = tick.get("actors", [])
	_check(actors[1].get("id") == "seamstress" and actors[1].get("hp") == 25
		and actors[1].get("statuses") == {"bleed": 1},
		"AC3 phase 2: the owner turn turns Bleed 2 into 2 HP loss and Bleed 1")
	_check(actors[0].get("id") == "warden" and actors[0].get("hp") == 40
		and actors[0].get("statuses", {}) == {},
		"AC3 phase 2: the owner turn leaves the Warden untouched")
	_check(actors[2].get("id") == "tinker" and actors[2].get("hp") == 26,
		"AC3 phase 2: the owner turn leaves the Tinker untouched")
	_check(tick.get("events") == [
		{"side": "heroes", "position": 1, "id": "warden", "bleed_hp_loss": 0},
		{"side": "heroes", "position": 2, "id": "seamstress", "bleed_hp_loss": 2},
		{"side": "heroes", "position": 3, "id": "tinker", "bleed_hp_loss": 0}],
		"AC3 phase 2: the tick reports the Bleed HP loss on the Seamstress in slot order")
	_check(party.get_heroes() == before,
		"AC3 phase 2: the detached owner turn does not write to the real CombatParty")
	_check(party.get_hero(2).get("hp") == 27
		and party.get_hero(2).get("statuses") == {"bleed": 2},
		"AC3 phase 2: the party still holds the un-ticked Bleed 2")


## AC3: phase 3 resolves Weak 1 on the Warden plus a 3-damage hit on him.
func _test_phase_three_weak_and_front_hit() -> void:
	var party := _build_party()
	var enemies := _build_enemies()
	if not _fixture_ok(party, enemies, "AC3 phase 3"):
		return
	var scheduler := CombatEnemyIntents.new(_parsed())
	_check(scheduler.advance_turn(), "AC3 phase 3: the cycle advances once")
	_check(scheduler.advance_turn(), "AC3 phase 3: the cycle advances twice")
	var announced: Array = scheduler.get_intents()
	_check(announced == _intents_for(2), "AC3 phase 3 announces the authored third pair")
	var result := phase.execute_phase(party, enemies, announced)
	_check(result == {"ok": true, "events": _events_for(2)},
		"AC3 phase 3 resolves exactly the Weak and front-hit events")
	_check(party.get_hero(1).get("hp") == 37,
		"AC3 phase 3: the Warden takes the 3-damage hit (40 -> 37 HP)")
	_check(party.get_hero(1).get("statuses") == {"weak": 1},
		"AC3 phase 3: the Warden carries exactly Weak 1")
	_check(party.get_hero(2).get("hp") == 30 and party.get_hero(3).get("hp") == 26,
		"AC3 phase 3: the Seamstress and the Tinker are unhurt")
	_check(_hero_ledger(party.get_heroes()) == [[37, 0], [30, 0], [26, 0]],
		"AC3 phase 3 hero HP/Block ledger")

	# Weak 1 really means 25% less attack damage, rounded down, through the
	# real status service.
	var statuses := CombatStatuses.new()
	_check(statuses.adjusted_attack_damage(4, {"weak": 1}, {}) == 3,
		"AC3 phase 3: Weak 1 reduces a 4-damage attack to 3 in the real status service")
	_check(statuses.adjusted_attack_damage(4, {}, {}) == 4,
		"AC3 phase 3: an un-weakened attack keeps its full damage")
	var tick := CombatStatusTurnBatch.new().tick_side("heroes", party.get_heroes())
	var actors: Array = tick.get("actors", [])
	_check(tick.get("ok") == true and actors[0].get("statuses", {}) == {},
		"AC3 phase 3: Weak 1 expires at the owner's own turn boundary")
	_check(actors[0].get("hp") == 37,
		"AC3 phase 3: the expired Weak cost no HP")


## AC3: Block absorbs before HP, on the real party service.
func _test_block_absorbs_before_hp() -> void:
	var party := _build_party()
	var enemies := _build_enemies()
	if not _fixture_ok(party, enemies, "AC3 block"):
		return
	_check(party.gain_block(3, 4) and party.get_hero(3).get("block") == 4,
		"AC3 block: the Tinker really holds 4 Block before the rear hit")
	var scheduler := CombatEnemyIntents.new(_parsed())
	var result := phase.execute_phase(party, enemies, scheduler.get_intents())
	_check(result.get("ok") == true, "AC3 block: phase 1 still resolves")
	_check(party.get_hero(3).get("hp") == 26 and party.get_hero(3).get("block") == 0,
		"AC3 block: the 4 Block absorbs the whole 4-damage rear hit (Tinker keeps 26 HP)")

	var shielded := _build_party()
	var roster := _build_enemies()
	if not _fixture_ok(shielded, roster, "AC3 block 2"):
		return
	_check(shielded.gain_block(2, 2) and shielded.get_hero(2).get("block") == 2,
		"AC3 block: the Seamstress really holds 2 Block before the middle hit")
	var second := CombatEnemyIntents.new(_parsed())
	second.advance_turn()
	var result2 := phase.execute_phase(shielded, roster, second.get_intents())
	_check(result2.get("ok") == true, "AC3 block: phase 2 still resolves")
	_check(shielded.get_hero(2).get("hp") == 29 and shielded.get_hero(2).get("block") == 0,
		"AC3 block: 2 Block absorbs 2 of the 3-damage middle hit (Seamstress 30 -> 29 HP)")
	_check(shielded.get_hero(2).get("statuses") == {"bleed": 2},
		"AC3 block: the same beat still applies the Spool Stalker's Bleed 2")


## AC3: the full three-beat cycle plus the wraparound, replayed from scratch.
func _cycle() -> Dictionary:
	var party := _build_party()
	var enemies := _build_enemies()
	var scheduler := CombatEnemyIntents.new(_parsed())
	var beats: Array = []
	for index in range(4):
		if index > 0:
			scheduler.advance_turn()
		var announced: Array = scheduler.get_intents()
		var result := phase.execute_phase(party, enemies, announced)
		beats.append({"announced": announced, "events": result.get("events", []),
			"ok": result.get("ok"), "heroes": party.get_heroes(),
			"enemies": enemies.get_enemies()})
	return {"beats": beats, "final_announcement": scheduler.get_intents(),
		"turn_index": scheduler._turn_index}


func _test_full_cycle_and_wrap() -> void:
	var first := _cycle()
	var second := _cycle()
	_check(first == second,
		"AC3: two independently constructed cycles produce identical observations")
	var beats: Array = first.get("beats", [])
	_check(beats.size() == 4, "AC3: the cycle captured every beat including the wrap")
	if beats.size() != 4:
		return
	for index in range(3):
		_check(beats[index].get("announced") == _intents_for(index)
			and beats[index].get("events") == _events_for(index),
			"AC3: cycle beat %d announces and resolves the authored pair" % index)
	_check(beats[3].get("announced") == _intents_for(0),
		"AC3: the fourth announced beat wraps to the first authored pair")
	_check(beats[3].get("events") == _events_for(0),
		"AC3: the fourth resolved beat repeats the first beat's events")
	_check(_hero_ledger(beats[0]["heroes"]) == [[40, 0], [30, 0], [22, 0]],
		"AC3: cycle beat 0 hero ledger")
	_check(_hero_ledger(beats[1]["heroes"]) == [[40, 0], [27, 0], [22, 0]],
		"AC3: cycle beat 1 hero ledger")
	_check(_hero_ledger(beats[2]["heroes"]) == [[37, 0], [27, 0], [22, 0]],
		"AC3: cycle beat 2 hero ledger")
	_check(_hero_ledger(beats[3]["heroes"]) == [[37, 0], [27, 0], [18, 0]],
		"AC3: cycle beat 3 hero ledger after the wrap")
	_check(_enemy_ledger(beats[3]["enemies"]) == [[16, 4], [14, 0]],
		"AC3: cycle beat 3 enemy ledger (the Button Guard blocks twice)")
	_check(first.get("final_announcement") == _intents_for(0)
		and first.get("turn_index") == 3,
		"AC3: the wrapped cycle ends on the first authored pair")


## AC4: a slain source skips only its own action; the living source still acts.
func _test_slain_source_skips_action() -> void:
	var party := _build_party()
	var enemies := _build_enemies()
	if not _fixture_ok(party, enemies, "AC4 slain"):
		return
	_check(enemies.apply_damage(1, 16) and enemies.is_slain(1)
		and not enemies.is_slain(2),
		"AC4: the Button Guard is really slain and the Spool Stalker stays alive")
	var dead_before: Dictionary = enemies.get_enemy(1)
	var scheduler := CombatEnemyIntents.new(_parsed())
	var announced: Array = scheduler.get_intents()
	_check(announced == _intents_for(0), "AC4: the slain-source fixture announces the first pair")
	var result := phase.execute_phase(party, enemies, announced)
	_check(result == {"ok": true, "events": [
		{"type": "block", "enemy_position": 1, "applied": false},
		{"type": "attack", "enemy_position": 2, "applied": true, "target_position": 3}]},
		"AC4: the slain Button Guard's Block is skipped; the living Spool Stalker still attacks")
	_check(party.get_hero(3).get("hp") == 22 and party.get_hero(3).get("block") == 0,
		"AC4: the Tinker still takes the living source's 4-damage hit (26 -> 22 HP)")
	_check(enemies.get_enemy(1) == dead_before,
		"AC4: the slain source keeps its original slot, HP and zero Block")
	_check(enemies.get_enemy(2).get("hp") == 14 and enemies.get_enemy(2).get("block") == 0,
		"AC4: the living source gains no Block this beat")
	_check(scheduler._turn_index == 0 and scheduler.get_intents() == _intents_for(0),
		"AC4: the slain-source phase leaves the announcement cycle untouched")

	# The same rule for a slain debuff source.
	var other_party := _build_party()
	var other_enemies := _build_enemies()
	if not _fixture_ok(other_party, other_enemies, "AC4 slain debuff"):
		return
	_check(other_enemies.apply_damage(2, 14) and other_enemies.is_slain(2),
		"AC4: the Spool Stalker is really slain")
	var other_scheduler := CombatEnemyIntents.new(_parsed())
	other_scheduler.advance_turn()
	var other_result := phase.execute_phase(other_party, other_enemies,
		other_scheduler.get_intents())
	_check(other_result == {"ok": true, "events": [
		{"type": "attack", "enemy_position": 1, "applied": true, "target_position": 2},
		{"type": "debuff", "enemy_position": 2, "applied": false, "target_position": 2,
			"status": "bleed"}]},
		"AC4: the slain Spool Stalker's Bleed is skipped; the Button Guard still hits")
	_check(other_party.get_hero(2).get("hp") == 27,
		"AC4: the Seamstress still takes the living source's 3-damage hit (30 -> 27 HP)")
	_check(other_party.get_hero(2).get("statuses", {}) == {},
		"AC4: the skipped Bleed leaves no status on the Seamstress")


## AC4: rejected schedules, rosters, targets and phases change nothing.
func _test_fail_closed_boundaries() -> void:
	var pristine := _read_text(ENCOUNTER_PATH)
	var valid := _parsed()
	var broken: Array = [
		"{bad", "[]",
		JSON.stringify([valid[0], valid[0]]),
		JSON.stringify([{"enemy_position": 1, "pattern": []}, valid[1]]),
		JSON.stringify([{"enemy_position": 1, "pattern": [
			{"type": "attack", "amount": 1}]}, valid[1]]),
		JSON.stringify([{"enemy_position": 1, "pattern": [
			{"type": "block", "amount": 1, "target_position": 2}]}, valid[1]]),
		JSON.stringify([{"enemy_position": 1, "pattern": [
			{"type": "heal", "amount": 1}]}, valid[1]]),
		JSON.stringify([{"enemy_position": 1, "pattern": [
			{"type": "attack", "amount": -1, "target_position": 2}]}, valid[1]]),
		JSON.stringify([{"enemy_position": 1.5, "pattern": [
			{"type": "block", "amount": 1}]}, valid[1]]),
		JSON.stringify([{"enemy_position": 1, "pattern": [
			{"type": "block", "amount": 1.5}]}, valid[1]]),
		JSON.stringify([{"enemy_position": 1, "pattern": [
			{"type": "attack", "amount": 1, "target_position": 2.5}]}, valid[1]]),
		JSON.stringify([{"enemy_position": 1, "pattern": [
			{"type": "block", "amount": "1"}]}, valid[1]]),
	]
	for index in range(broken.size()):
		_check(RunFightEncounterSelection._parse_schedule_text(broken[index]).is_empty(),
			"AC4: malformed local schedule %d rejected without partial data" % index)
	_check(_read_text(ENCOUNTER_PATH) == pristine and _parsed() == valid,
		"AC4: the malformed local copies never alter the valid authored data")

	# An invalid later action rejects the whole phase, with no partial change.
	var party := _build_party()
	var enemies := _build_enemies()
	if not _fixture_ok(party, enemies, "AC4 invalid phase"):
		return
	var party_before: Array = party.get_heroes()
	var enemies_before: Array = enemies.get_enemies()
	var invalid_phase: Array = [
		{"type": "attack", "amount": 3, "target_position": 2, "enemy_position": 1},
		{"type": "attack", "amount": 9, "target_position": 4, "enemy_position": 2}]
	var phase_copy: Array = invalid_phase.duplicate(true)
	_check(phase.execute_phase(party, enemies, invalid_phase)
		== {"ok": false, "events": []},
		"AC4: an invalid later attack rejects the entire phase")
	_check(party.get_heroes() == party_before
		and enemies.get_enemies() == enemies_before
		and invalid_phase == phase_copy,
		"AC4: the invalid phase leaves all state and its inputs intact")

	# A downed target rejects the debuff, rolling back the earlier source's
	# staged damage as well.
	var downed_party := _build_party()
	var downed_enemies := _build_enemies()
	if not _fixture_ok(downed_party, downed_enemies, "AC4 downed target"):
		return
	_check(downed_party.apply_damage(2, 30) and downed_party.is_downed(2)
		and downed_party.get_hero(2).get("hp") == 0,
		"AC4: real party damage downs the Seamstress at position 2")
	var downed_before: Array = downed_party.get_heroes()
	var downed_roster_before: Array = downed_enemies.get_enemies()
	var downed_phase: Array = [
		{"type": "attack", "amount": 3, "target_position": 1, "enemy_position": 1},
		{"type": "debuff", "amount": 2, "target_position": 2, "status": "bleed",
			"enemy_position": 2}]
	_check(phase.execute_phase(downed_party, downed_enemies, downed_phase)
		== {"ok": false, "events": []},
		"AC4: a debuff onto a downed hero rejects the whole phase")
	_check(downed_party.get_heroes() == downed_before
		and downed_enemies.get_enemies() == downed_roster_before,
		"AC4: the rejected phase leaves no partial HP, Block, status or enemy change")
	_check(downed_party.get_hero(1).get("hp") == 40,
		"AC4: the earlier source's staged attack is rolled back with the phase")
	_check(downed_party.get_hero(2).get("id") == "seamstress"
		and downed_party.get_hero(2).get("statuses", {}) == {},
		"AC4: the downed Seamstress stays in her slot, unbled and unrevived")

	# An unknown source slot is refused before anything is applied.
	var unknown_party := _build_party()
	var unknown_enemies := _build_enemies()
	if not _fixture_ok(unknown_party, unknown_enemies, "AC4 unknown source"):
		return
	var unknown_party_before: Array = unknown_party.get_heroes()
	var unknown_roster_before: Array = unknown_enemies.get_enemies()
	var unknown_phase: Array = [
		{"type": "block", "amount": 2, "enemy_position": 1},
		{"type": "attack", "amount": 4, "target_position": 3, "enemy_position": 3}]
	_check(phase.execute_phase(unknown_party, unknown_enemies, unknown_phase)
		== {"ok": false, "events": []},
		"AC4: a source slot outside the real roster rejects the phase")
	_check(unknown_party.get_heroes() == unknown_party_before
		and unknown_enemies.get_enemies() == unknown_roster_before,
		"AC4: the refused phase grants no enemy Block and no hero damage")

	# A downed hero is simply not targetable by an attack.
	var downed_target_party := _build_party()
	var downed_target_enemies := _build_enemies()
	if not _fixture_ok(downed_target_party, downed_target_enemies, "AC4 downed attack"):
		return
	_check(downed_target_party.apply_damage(3, 26) and downed_target_party.is_downed(3),
		"AC4: real party damage downs the Tinker at position 3")
	var attack_phase: Array = [
		{"type": "block", "amount": 2, "enemy_position": 1},
		{"type": "attack", "amount": 4, "target_position": 3, "enemy_position": 2}]
	var attack_result := phase.execute_phase(downed_target_party, downed_target_enemies,
		attack_phase)
	_check(attack_result.get("ok") == true,
		"AC4: an attack onto a downed hero still resolves the phase")
	_check(attack_result.get("events", [])[1].get("applied") == false,
		"AC4: the attack onto the downed hero is not applied")
	_check(downed_target_party.get_hero(3).get("hp") == 0
		and downed_target_party.get_hero(3).get("id") == "tinker",
		"AC4: the downed Tinker keeps her slot and takes no damage")

	# A malformed roster binding is refused by the real assembler, atomically.
	var catalog_before := _read_text(ENEMY_PATH)
	var bad_choice := {"success": true, "node_type": "Fight",
		"encounter_id": ENCOUNTER_ID, "definitions": _expected()}
	var assembler := RunTypedBattleRoster.new()
	for bad_binding in [
		[ENEMY_IDS[0]], [], ["button_guard", "spool_stalker", "fray_scavenger"],
		["button_guard", "button_guard"], ["button_guard", "no_such_enemy"],
		["button_guard", 7], "button_guard",
	]:
		var bindings := {ENCOUNTER_ID: bad_binding}
		_check(assembler.assemble(bad_choice, bindings, [ENEMY_PATH]) == {"ok": false},
			"AC4: malformed roster binding %s is refused" % str(bad_binding))
	_check(_read_text(ENEMY_PATH) == catalog_before,
		"AC4: the real enemy catalog file is never mutated")


## AC4: an illegal Fight pool is refused before any RNG is drawn, and the
## selector still works with the legal pool afterwards.
func _test_selection_failures() -> void:
	var rng := _rng(SELECTION_SEED + 7)
	var map := RunMap.new()
	_check(map.generate(rng), "AC4: a second seeded map generates for the selection failures")
	var fight := _opening_fight(map)
	_check(not fight.is_empty() and map.get_legal_choices().has(fight),
		"AC4: the second map offers a real legal Fight node")
	if fight.is_empty():
		return
	_check(map.choose_node(fight), "AC4: the second map enters its Fight node")
	var selector := RunFightEncounterSelection.new()
	var state_before := rng.state
	var bad_pools: Array = [
		{},
		{"Fight": {}},
		{"Fight": {ENCOUNTER_ID: "res://data/encounters/no_such_encounter.json"}},
		{"Fight": {ENCOUNTER_ID: "res://data/enemies/run_enemies.json"}},
		{"Fight": {ENCOUNTER_ID: "res://data/encounters/../enemies/run_enemies.json"}},
		{"Fight": {ENCOUNTER_ID: 7}},
		{"Fight": {ENCOUNTER_ID: null}},
		{"Elite": {ENCOUNTER_ID: ENCOUNTER_PATH}},
	]
	for bad_pool in bad_pools:
		var answer := selector.select_current_battle(map, rng, bad_pool)
		_check(answer == {"success": false},
			"AC4: the illegal Fight pool %s is refused" % str(bad_pool))
		_check(rng.state == state_before,
			"AC4: the refused Fight pool %s advances no run RNG" % str(bad_pool))
		_check(not selector._selected.has(fight),
			"AC4: the refused Fight pool %s leaves the selection cache empty" % str(bad_pool))
	var answer := selector.select_current_battle(map, rng,
		{"Fight": {ENCOUNTER_ID: ENCOUNTER_PATH,
			"threadbite_midline_press": THREADBITE_PATH}})
	_check(answer.get("success") == true,
		"AC4: the legal Fight pool still selects after every refusal")
	_check(rng.state != state_before,
		"AC4: the legal selection after the refusals really draws its one RNG value")


## AC2: the selection consumes exactly ONE real run RNG draw. A one-candidate
## pool cannot prove that (Godot's randi_range(0, 0) does not advance the
## stream), so the draw is proven with a two-candidate pool against an oracle,
## and the oracle is shown to be sensitive to an extra injected draw.
func _test_selection_draw_discipline() -> void:
	var pool := {"Fight": {ENCOUNTER_ID: ENCOUNTER_PATH,
		"threadbite_midline_press": THREADBITE_PATH}}
	var rng := _rng(SELECTION_SEED)
	var map := RunMap.new()
	_check(map.generate(rng), "AC2: the draw-discipline map generates")
	var fight := _opening_fight(map)
	_check(not fight.is_empty(), "AC2: the draw-discipline map offers a legal Fight")
	if fight.is_empty():
		return
	_check(map.choose_node(fight), "AC2: the draw-discipline map enters its Fight")

	var oracle := _rng(SELECTION_SEED)
	var oracle_map := RunMap.new()
	_check(oracle_map.generate(oracle), "AC2: the draw oracle map generates")
	_check(oracle_map.get_floors() == map.get_floors(),
		"AC2: the draw oracle sees the identical graph")
	_check(oracle_map.choose_node(fight), "AC2: the draw oracle enters the same Fight")
	var ids: Array = pool["Fight"].keys()
	ids.sort()
	var expected_id: String = ids[oracle.randi_range(0, ids.size() - 1)]
	var after_one_draw := oracle.state

	var selector := RunFightEncounterSelection.new()
	var choice := selector.select_current_battle(map, rng, pool)
	_check(choice.get("success") == true
		and choice.get("encounter_id") == expected_id,
		"AC2: the two-candidate pool selects the oracle's sorted-index draw")
	_check(choice.get("definitions")
		== RunFightEncounterSelection._parse_schedule_text(_read_text(pool["Fight"][expected_id])),
		"AC2: the drawn encounter returns its own complete authored schedule")
	_check(rng.state == after_one_draw,
		"AC2: the selection consumes exactly one real run RNG draw")
	_check(map.get_current_node_id() == fight and map.get_route() == [fight],
		"AC2: the selection never chooses or advances a map node")

	# The oracle is sensitive: an extra injected draw changes the state, so
	# the one-draw comparison above cannot pass vacuously.
	var extra := _rng(SELECTION_SEED)
	extra.randi_range(0, ids.size() - 1)
	extra.randi_range(0, ids.size() - 1)
	_check(extra.state != after_one_draw,
		"AC2: the one-draw oracle detects an injected extra draw")

	# The cached re-entry spends nothing at all.
	var cached := selector.select_current_battle(map, rng, {"Fight": {}})
	_check(cached == choice and rng.state == after_one_draw,
		"AC2: the cached re-entry spends no second real draw")
	var cached_legacy := selector.select_current_fight(map, rng, {})
	_check(cached_legacy.get("success") == true
		and cached_legacy.get("encounter_id") == expected_id
		and rng.state == after_one_draw,
		"AC2: the legacy entry point returns the cached choice without a draw")

	# An independent, same-seed run replays the identical draw and choice.
	var replay_rng := _rng(SELECTION_SEED)
	var replay_map := RunMap.new()
	_check(replay_map.generate(replay_rng), "AC2: the draw replay map generates")
	_check(replay_map.choose_node(fight), "AC2: the draw replay map enters the same Fight")
	var replay := RunFightEncounterSelection.new().select_current_battle(replay_map,
		replay_rng, pool)
	_check(replay == choice and replay_rng.state == rng.state,
		"AC2: an independent seeded run replays the identical draw and choice")


## AC2: a legal seeded Fight selects this encounter from a test-local pool;
## the choice is cached, spends exactly one draw and replays identically.
func _test_selection_cache_and_replay() -> void:
	var pool := {"Fight": {ENCOUNTER_ID: ENCOUNTER_PATH}}
	var rng := _rng(SELECTION_SEED)
	var map := RunMap.new()
	_check(map.generate(rng), "AC2: a real seeded twelve-floor RunMap is generated")
	var fight := _opening_fight(map)
	_check(not fight.is_empty() and map.get_legal_choices().has(fight),
		"AC2: the generated map offers a real legal Fight node")
	if fight.is_empty():
		return
	_check(map.choose_node(fight), "AC2: the legal Fight node is entered")
	_check(map.get_current_node_id() == fight
		and map.get_node(fight).get("type") == "Fight"
		and map.get_route() == [fight],
		"AC2: the selector input really is the chosen current Fight")

	# A one-candidate pool cannot advance the stream at all (Godot's
	# randi_range(0, 0) draws nothing), so the "exactly one real draw" proof
	# lives in _test_selection_draw_discipline with a two-candidate pool.
	var state_before_selection := rng.state

	var selector := RunFightEncounterSelection.new()
	var choice := selector.select_current_battle(map, rng, pool)
	_check(choice.get("success") == true and choice.get("node_type") == "Fight"
		and choice.get("encounter_id") == ENCOUNTER_ID,
		"AC2: the typed selector picks this encounter from the local Fight pool")
	_check(choice.get("definitions") == _expected(),
		"AC2: the selection returns the complete authored schedule")
	_check(rng.state == state_before_selection,
		"AC2: the one-candidate selection leaves the run RNG stream untouched")
	_check(map.get_current_node_id() == fight and map.get_route() == [fight],
		"AC2: the selection never chooses or advances a map node")

	# Re-entry is served from the cache, with no further draw.
	var cached := selector.select_current_battle(map, rng, {"Fight": {}})
	_check(cached == choice and rng.state == state_before_selection,
		"AC2: re-entry is cached without a second RNG draw")
	var cached_legacy := selector.select_current_fight(map, rng, {})
	_check(cached_legacy.get("success") == true
		and cached_legacy.get("encounter_id") == ENCOUNTER_ID
		and cached_legacy.get("definitions") == _expected()
		and rng.state == state_before_selection,
		"AC2: the legacy entry point returns the same cached choice without a draw")

	# The returned data is detached from the selector's cache.
	var original := choice.duplicate(true)
	choice["definitions"][0]["pattern"][0]["amount"] = 909
	choice["definitions"].clear()
	choice["encounter_id"] = "mutated"
	_check(selector.select_current_battle(map, rng, pool) == original,
		"AC2: caller edits cannot reach the selector's cached schedule")
	_check(selector.select_current_battle(map, rng, pool) == original,
		"AC2: a fresh read still returns the untouched cached schedule")

	# An independent, same-seed run replays the same selection exactly.
	var replay_rng := _rng(SELECTION_SEED)
	var replay_map := RunMap.new()
	_check(replay_map.generate(replay_rng), "AC2: the replay map generates")
	_check(replay_map.choose_node(fight), "AC2: the replay map enters the same Fight")
	var replay := RunFightEncounterSelection.new().select_current_battle(replay_map,
		replay_rng, pool)
	_check(replay == original and replay_rng.state == rng.state,
		"AC2: an independent seeded run selects the identical encounter and schedule")

	# The real enemy catalog becomes the authoritative roster for this choice.
	var catalog_before := _read_text(ENEMY_PATH)
	var bindings := {ENCOUNTER_ID: ENEMY_IDS}
	var assembled := RunTypedBattleRoster.new().assemble(original, bindings, [ENEMY_PATH])
	_check(assembled.get("ok") == true,
		"AC2: the real assembler builds this encounter's roster")
	if not assembled.get("ok", false):
		return
	var enemies: CombatEnemies = assembled.get("enemies")
	_check(enemies is CombatEnemies and enemies.is_valid(),
		"AC2: the assembled roster is a real CombatEnemies")
	_check(assembled.get("encounter_id") == ENCOUNTER_ID
		and assembled.get("node_type") == "Fight"
		and assembled.get("definitions") == _expected(),
		"AC2: the assembly keeps the selected identity, kind and schedule")
	_check(enemies.get_enemy(1).get("id") == "button_guard"
		and enemies.get_enemy(1).get("name") == "Button Guard"
		and enemies.get_enemy(1).get("position") == 1
		and enemies.get_enemy(1).get("hp") == 16
		and enemies.get_enemy(1).get("max_hp") == 16
		and enemies.get_enemy(1).get("block") == 0,
		"AC2: slot 1 is the real Button Guard with 16 HP")
	_check(enemies.get_enemy(2).get("id") == "spool_stalker"
		and enemies.get_enemy(2).get("name") == "Spool Stalker"
		and enemies.get_enemy(2).get("position") == 2
		and enemies.get_enemy(2).get("hp") == 14
		and enemies.get_enemy(2).get("max_hp") == 14
		and enemies.get_enemy(2).get("block") == 0,
		"AC2: slot 2 is the real Spool Stalker with 14 HP")
	var second_assembly := RunTypedBattleRoster.new().assemble(original, bindings, [ENEMY_PATH])
	_check(second_assembly.get("ok") == true
		and second_assembly.get("enemies") != assembled.get("enemies")
		and second_assembly.get("enemies").get_enemies() == enemies.get_enemies(),
		"AC2: a second assembly is fresh, independent and identical")
	_check(_read_text(ENEMY_PATH) == catalog_before,
		"AC2: the real enemy catalog file is unchanged by the assembly")

	# A non-Fight node may not select a Fight, and the refusal costs no RNG.
	var non_fight := _map_with_non_fight_opening()
	_check(not non_fight.is_empty(),
		"AC2: a real seeded map offers a legal non-Fight opening node")
	if not non_fight.is_empty():
		var other_map: RunMap = non_fight["map"]
		var other_node: String = non_fight["node"]
		var other_rng: RandomNumberGenerator = non_fight["rng"]
		var other_kind: String = other_map.get_node(other_node).get("type", "")
		_check(other_kind in ["Rest", "Shop", "Event", "Treasure"],
			"AC2: the refusal fixture really is a non-battle node (%s)" % other_kind)
		var state_before := other_rng.state
		var refused := RunFightEncounterSelection.new().select_current_battle(other_map,
			other_rng, pool)
		_check(refused == {"success": false},
			"AC2: a non-Fight node refuses a Fight selection")
		_check(other_rng.state == state_before,
			"AC2: the refused non-Fight selection advances no RNG")
		var refused_legacy := RunFightEncounterSelection.new().select_current_fight(other_map,
			other_rng, pool)
		_check(refused_legacy == {"success": false}
			and other_rng.state == state_before,
			"AC2: the legacy entry point refuses the non-Fight node without a draw")
		var refused_pool := RunFightEncounterSelection.new().select_current_battle(other_map,
			other_rng, {"Elite": {ENCOUNTER_ID: ENCOUNTER_PATH}})
		_check(refused_pool == {"success": false}
			and other_rng.state == state_before,
			"AC2: a pool without the chosen kind refuses the non-Fight node")


func _opening_fight(map: RunMap) -> String:
	for candidate in map.get_legal_choices():
		if map.get_node(candidate).get("type") == "Fight":
			return candidate
	return ""


## A real seeded map whose legal opening choices include a non-battle node
## (Rest, Shop, Event or Treasure): such a node may never select a Fight.
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
