extends SceneTree

## Deterministic headless coverage for the authored Ragspool Pinwheel Shift
## encounter (standalone M04 Fight content; NOT registered in the live pool):
##   enemy_position 1 (Guard Ragling): beat 1 shove, beat 2 Exposed debuff, beat 3 Block.
##   enemy_position 2 (Spool Stalker): beat 1 attack 4, beat 2 attack 4, beat 3 attack 3.
## Beat 1 swaps the middle Seamstress (2) with the rear Tinker (3) BEFORE the
## Stalker strikes slot 2, so the Tinker - not the Seamstress - loses 4 HP (26 to 22).
## Beat 2 marks the rear Seamstress (now 3) Exposed 1 BEFORE the base-4 hit, so it deals
## floor(4 * 1.5) = 6. Beat 3 the Guard takes exactly 3 Block while the Stalker
## hits Warden's still-available 6 opening Block for 3, reducing Block 6 to 3 with HP still 40.
## No live wiring, pool entry or UI here.

const ENCOUNTER_PATH := "res://data/encounters/ragspool_pinwheel_shift.json"
const ENCOUNTER_ID := "ragspool_pinwheel_shift"
const TYPED_POOLS_PATH := "res://data/encounters/m03_typed_battle_pools.json"
const ENEMY_CATALOG_PATH := "res://data/enemies/run_enemies.json"
const STARTER_ENEMY_CATALOG_PATH := "res://data/enemies/starter_enemies.json"
const HERO_CATALOG_PATH := "res://data/heroes/starter_party.json"
const FIXED_SEED := 20261022

var failures: Array[String] = []
var checks := 0
var phase := CombatEnemyPhase.new()


func _initialize() -> void:
	_test_ac1_authored_schedule_and_intents()
	_test_ac2_three_beat_phase()
	_test_ac3_typed_selection_roster_and_negatives()
	if failures.is_empty():
		print("ragspool_pinwheel_shift_encounter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("ragspool_pinwheel_shift_encounter_test: FAIL (", failures.size(), " failures)")
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
	var parsed: Variant = JSON.parse_string(_read_text(path))
	if not parsed is Array:
		_check(false, "catalog must be a JSON Array: " + path)
		return []
	return _normalize(parsed)


func _record_by_id(records: Array, id: String) -> Dictionary:
	var matches: Array = []
	for record in records:
		if record is Dictionary and record.get("id") == id:
			matches.append(record)
	_check(matches.size() == 1, "catalog holds exactly one record named " + id)
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
	if value is Dictionary:
		for key in value:
			total += _count_numeric_leaves(value[key])
	return total


## The authored prescription, copied verbatim from the brief.
func _expected_definitions() -> Array:
	return [
		{
			"enemy_position": 1,
			"pattern": [
				{"type": "shove", "amount": 0, "target_position": 2, "direction": 1},
				{"type": "debuff", "amount": 1, "target_position": 3, "status": "exposed"},
				{"type": "block", "amount": 3}
			]
		},
		{
			"enemy_position": 2,
			"pattern": [
				{"type": "attack", "amount": 4, "target_position": 2},
				{"type": "attack", "amount": 4, "target_position": 3},
				{"type": "attack", "amount": 3, "target_position": 1}
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


func _expected_events(beat_index: int) -> Array:
	var events: Array = []
	for intent in _expected_beat(beat_index):
		var event := {
			"type": intent["type"],
			"enemy_position": intent["enemy_position"],
			"applied": true
		}
		for field in ["target_position", "status", "direction"]:
			if intent.has(field):
				event[field] = intent[field]
		events.append(event)
	return events


func _source_record(definitions: Array, position: int) -> Dictionary:
	var matches: Array = []
	for definition in definitions:
		if definition is Dictionary and definition.get("enemy_position") == position:
			matches.append(definition)
	_check(matches.size() == 1, "exactly one source record at enemy_position %d" % position)
	return matches[0] if matches.size() == 1 else {}


## The three shipped heroes, all with 0 Block and no statuses.
func _build_party() -> CombatParty:
	var heroes := _load_catalog(HERO_CATALOG_PATH)
	var definitions: Array = []
	for id in ["warden", "seamstress", "tinker"]:
		definitions.append(_record_by_id(heroes, id))
	var party := CombatParty.new(definitions)
	_check(party.is_valid(), "the three shipped heroes build a valid CombatParty")
	return party


## The two named shipped enemies, in slot order.
func _build_enemies() -> CombatEnemies:
	var roster := _load_catalog(STARTER_ENEMY_CATALOG_PATH)
	var run_roster := _load_catalog(ENEMY_CATALOG_PATH)
	# Merge catalogs to find both enemies
	var merged: Array = []
	merged.append(_record_by_id(roster, "ragling_guard"))
	merged.append(_record_by_id(run_roster, "spool_stalker"))
	var enemies := CombatEnemies.new(merged)
	_check(enemies.is_valid(), "the two shipped enemies build a valid CombatEnemies")
	return enemies


func _hero_record(id: String) -> Dictionary:
	return _record_by_id(_load_catalog(HERO_CATALOG_PATH), id)


func _enemy_record(id: String) -> Dictionary:
	var starter := _load_catalog(STARTER_ENEMY_CATALOG_PATH)
	var run := _load_catalog(ENEMY_CATALOG_PATH)
	for record in starter:
		if record.get("id") == id:
			return record.duplicate(true)
	for record in run:
		if record.get("id") == id:
			return record.duplicate(true)
	return {}


func _assemble_roster(typed_choice: Dictionary) -> Dictionary:
	return RunTypedBattleRoster.new().assemble(
		typed_choice,
		{ENCOUNTER_ID: ["ragling_guard", "spool_stalker"]},
		[STARTER_ENEMY_CATALOG_PATH, ENEMY_CATALOG_PATH]
	)


## AC1: the authored JSON holds exactly the two prescribed sources, the production
## parser accepts it, the intent service validates it and announces beats 1, 2, 3
## and then beat 1 again.
func _test_ac1_authored_schedule_and_intents() -> void:
	_check(FileAccess.file_exists(ENCOUNTER_PATH), "the authored schedule file exists")
	_check(ENCOUNTER_PATH.get_file().get_basename() == ENCOUNTER_ID,
		"the schedule file name carries the canonical encounter ID " + ENCOUNTER_ID)
	var raw_text := _read_text(ENCOUNTER_PATH)
	var raw_json: Variant = JSON.parse_string(raw_text)
	_check(raw_json is Array, "the authored file is a top-level JSON array")
	_check(raw_json is Array and raw_json.size() == 2,
		"the authored file holds exactly this encounter's two source records")
	_check(_all_numeric_leaves_integral(raw_json),
		"every numeric leaf of the raw file is integral before coercion")
	_check(_count_numeric_leaves(raw_json) > 0, "the schedule really carries numeric fields")

	var loaded := RunFightEncounterSelection._parse_schedule_text(raw_text)
	_check(loaded == _expected_definitions(),
		"the production parser returns exactly the prescribed two-source schedule")
	_check(loaded.size() == 2, "the parsed schedule holds exactly two sources")

	for position in [1, 2]:
		var record := _source_record(loaded, position)
		_check(record.size() == 2 and record.has("enemy_position") and record.has("pattern"),
			"source %d carries only enemy_position and pattern" % position)
		var pattern = record.get("pattern")
		_check(pattern is Array and pattern.size() == 3,
			"source %d repeats exactly three beats" % position)
	_check(_source_record(loaded, 1).get("pattern") == _expected_definitions()[0]["pattern"],
		"source 1 holds the exact shove / Exposed / Block beat records")
	_check(_source_record(loaded, 2).get("pattern") == _expected_definitions()[1]["pattern"],
		"source 2 holds the exact 4 / 4 / 3 attack beat records")
	for definition in loaded:
		_check(definition.get("enemy_position") is int,
			"the parsed enemy_position is an int, not a JSON float")
		for action in definition["pattern"]:
			_check(action.get("amount") is int, "the parsed beat amount is an int, not a JSON float")
			if action.has("target_position"):
				_check(action.get("target_position") is int,
					"the parsed beat target_position is an int, not a JSON float")
			if action.has("direction"):
				_check(action.get("direction") is int,
					"the parsed beat direction is an int, not a JSON float")

	var intents := CombatEnemyIntents.new(loaded)
	_check(intents.is_valid(), "CombatEnemyIntents validates the authored schedule")
	_check(intents.get_intents() == _expected_beat(0), "beat 1 announces the exact two actions")
	_check(intents.advance_turn(), "advance to beat 2")
	_check(intents.get_intents() == _expected_beat(1), "beat 2 announces the exact two actions")
	_check(intents.advance_turn(), "advance to beat 3")
	_check(intents.get_intents() == _expected_beat(2), "beat 3 announces the exact two actions")
	_check(intents.advance_turn(), "advance to beat 4")
	_check(intents.get_intents() == _expected_beat(0), "beat 4 repeats beat 1 exactly")

	var fetched := intents.get_intents()
	fetched[0]["amount"] = 999
	fetched.append({"type": "invented"})
	_check(intents.get_intents() == _expected_beat(0),
		"mutating an announced intent cannot change later announcements")

	# Negative drift probes: a fractional authored amount and a duplicated source
	# position must fail closed instead of being truncated into a valid schedule.
	var fractional: Array = _expected_definitions().duplicate(true)
	fractional[1]["pattern"][1]["amount"] = 4.5
	_check(RunFightEncounterSelection._parse_schedule_text(
		JSON.stringify(fractional)).is_empty(),
		"a fractional beat amount is rejected by the production parser")
	var duplicated: Array = _expected_definitions().duplicate(true)
	duplicated[1]["enemy_position"] = 1
	_check(RunFightEncounterSelection._parse_schedule_text(
		JSON.stringify(duplicated)).is_empty(),
		"a duplicated source position is rejected by the production parser")
	_check(loaded == _expected_definitions(),
		"the rejected probes leave the authored schedule untouched")


## AC2: three real CombatEnemyPhase executions over the three shipped heroes and
## the two shipped enemies, with Warden's one-time starting 6 Block.
func _run_three_beats() -> Dictionary:
	var loaded := RunFightEncounterSelection._parse_schedule_text(_read_text(ENCOUNTER_PATH))
	var party := _build_party()
	# Apply Warden's starting 6 Block once
	var starting_block := CombatStartingBlock.new(party)
	_check(starting_block.apply(), "Warden's starting 6 Block applies")
	var enemies := _build_enemies()
	var intents := CombatEnemyIntents.new(loaded)
	var results: Array = []
	var hero_snapshots: Array = []
	var enemy_snapshots: Array = []
	for beat in range(3):
		var announced := intents.get_intents()
		_check(announced == _expected_beat(beat),
			"beat %d announces the exact authored actions" % (beat + 1))
		results.append(phase.execute_phase(party, enemies, announced))
		hero_snapshots.append(party.get_heroes())
		enemy_snapshots.append(enemies.get_enemies())
		_check(intents.advance_turn(), "advance past beat %d" % (beat + 1))
	return {
		"results": results,
		"heroes": party.get_heroes(),
		"enemies": enemies.get_enemies(),
		"hero_snapshots": hero_snapshots,
		"enemy_snapshots": enemy_snapshots,
		"repeating": intents.get_intents(),
	}


func _test_ac2_three_beat_phase() -> void:
	var party := _build_party()
	_check(party.get_hero(1).get("id") == "warden" and party.get_hero(1).get("hp") == 40
		and party.get_hero(1).get("block") == 0 and not party.get_hero(1).has("statuses"),
		"Warden starts at position 1 with 40 HP, 0 Block and no statuses")
	_check(party.get_hero(2).get("id") == "seamstress" and party.get_hero(2).get("hp") == 30
		and party.get_hero(2).get("block") == 0 and not party.get_hero(2).has("statuses"),
		"Seamstress starts at position 2 with 30 HP, 0 Block and no statuses")
	_check(party.get_hero(3).get("id") == "tinker" and party.get_hero(3).get("hp") == 26
		and party.get_hero(3).get("block") == 0 and not party.get_hero(3).has("statuses"),
		"Tinker starts at position 3 with 26 HP, 0 Block and no statuses")

	var enemies := _build_enemies()
	_check(enemies.get_enemy(1).get("id") == "ragling_guard"
		and enemies.get_enemy(1).get("max_hp") == 12 and enemies.get_enemy(1).get("hp") == 12
		and enemies.get_enemy(1).get("block") == 0,
		"enemy slot 1 is the shipped Guard Ragling with 12 max HP")
	_check(enemies.get_enemy(2).get("id") == "spool_stalker"
		and enemies.get_enemy(2).get("max_hp") == 14 and enemies.get_enemy(2).get("hp") == 14
		and enemies.get_enemy(2).get("block") == 0,
		"enemy slot 2 is the shipped Spool Stalker with 14 max HP")

	seed(FIXED_SEED)
	var rng_before := randi()
	seed(FIXED_SEED)
	var run := _run_three_beats()
	_check(randi() == rng_before, "the three enemy phases draw no global RNG")

	var results: Array = run["results"]
	_check(results.size() == 3, "exactly three enemy phases were executed")
	_check(results[0] == {"ok": true, "events": _expected_events(0)},
		"beat 1 succeeds with the shove then the 4 attack")
	_check(results[1] == {"ok": true, "events": _expected_events(1)},
		"beat 2 succeeds with the Exposed debuff then the 4 attack")
	_check(results[2] == {"ok": true, "events": _expected_events(2)},
		"beat 3 succeeds with the Guard Block then the 3 attack")
	_check(run["repeating"] == _expected_beat(0), "beat 4 announces beat 1 again")

	# Beat 1: the shove swaps Seamstress (2) with Tinker (3) before the Stalker
	# strikes slot 2, so the Tinker takes the 4 damage, not the Seamstress.
	var heroes: Array = run["hero_snapshots"][0]
	_check(heroes[0].get("id") == "warden" and heroes[0].get("position") == 1,
		"beat 1: the Warden keeps hero position 1")
	_check(heroes[1].get("id") == "tinker" and heroes[1].get("position") == 2,
		"beat 1: the Tinker now occupies hero position 2")
	_check(heroes[2].get("id") == "seamstress" and heroes[2].get("position") == 3,
		"beat 1: the Seamstress now occupies hero position 3")
	_check(heroes[0].get("hp") == 40 and heroes[0].get("block") == 6,
		"beat 1: the front Warden is untouched at 40 HP with 6 Block")
	_check(heroes[1].get("hp") == 22 and heroes[1].get("block") == 0,
		"beat 1: the middle Tinker took the 4 damage (26 to 22)")
	_check(heroes[2].get("hp") == 30 and heroes[2].get("block") == 0,
		"beat 1: the rear Seamstress is untouched at 30 HP")
	var beat1_foes: Array = run["enemy_snapshots"][0]
	_check(beat1_foes[0].get("id") == "ragling_guard" and beat1_foes[0].get("block") == 0
		and beat1_foes[0].get("hp") == 12,
		"beat 1: the Guard Ragling is unchanged at 12 HP and 0 Block")
	_check(beat1_foes[1].get("id") == "spool_stalker" and beat1_foes[1].get("block") == 0
		and beat1_foes[1].get("hp") == 14,
		"beat 1: the Spool Stalker is unchanged at 14 HP and 0 Block")
	var tinker := _hero_record("tinker")
	_check(heroes[1].get("name") == tinker.get("name")
		and heroes[1].get("max_hp") == tinker.get("max_hp")
		and heroes[1].get("art_path") == tinker.get("art_path"),
		"beat 1: the swapped hero keeps every unrelated record field")

	# Beat 2: Exposed 1 lands on the rear Seamstress before the base-4 attack.
	heroes = run["hero_snapshots"][1]
	_check(heroes[2].get("hp") == 24 and heroes[2].get("block") == 0,
		"beat 2: the Exposed Seamstress took floor(4 * 1.5) = 6 damage (30 to 24)")
	_check(heroes[2].get("statuses", {}).get("exposed", 0) == 1,
		"beat 2: the Seamstress carries Exposed 1")
	_check(heroes[0].get("id") == "warden" and heroes[0].get("hp") == 40,
		"beat 2: the front Warden is unchanged at 40 HP")
	_check(heroes[1].get("id") == "tinker" and heroes[1].get("hp") == 22,
		"beat 2: the middle Tinker is unchanged at 22 HP")
	_check(heroes[0].get("statuses", {}).get("exposed", 0) == 0
		and heroes[1].get("statuses", {}).get("exposed", 0) == 0,
		"beat 2: Exposed 1 lands only on the targeted rear hero")
	var beat2_foes: Array = run["enemy_snapshots"][1]
	_check(beat2_foes[0].get("block") == 0 and beat2_foes[1].get("block") == 0,
		"beat 2: neither enemy gained Block yet")

	# Beat 3: the Guard banks exactly 3 Block while the Stalker hits the front Warden.
	heroes = run["hero_snapshots"][2]
	var foes: Array = run["enemy_snapshots"][2]
	_check(foes[0].get("id") == "ragling_guard" and foes[0].get("block") == 3
		and foes[0].get("hp") == 12,
		"beat 3: the Guard Ragling holds exactly 3 Block and 12 HP")
	_check(foes[1].get("id") == "spool_stalker" and foes[1].get("block") == 0
		and foes[1].get("hp") == 14,
		"beat 3: the Spool Stalker holds 0 Block and 14 HP")
	var guard := _enemy_record("ragling_guard")
	_check(foes[0].get("name") == guard.get("name")
		and foes[0].get("max_hp") == guard.get("max_hp")
		and foes[0].get("art_path") == guard.get("art_path"),
		"beat 3: the enemy record keeps every unrelated field")
	_check(heroes[0].get("id") == "warden" and heroes[0].get("hp") == 40
		and heroes[0].get("block") == 3,
		"beat 3: the front Warden took 3 damage absorbed by Block (6 to 3), HP still 40")
	_check(heroes[1].get("id") == "tinker" and heroes[1].get("hp") == 22,
		"beat 3: the middle Tinker keeps 22 HP")
	_check(heroes[2].get("id") == "seamstress" and heroes[2].get("hp") == 24,
		"beat 3: the rear Seamstress keeps 24 HP")

	# Exposed lasts its owner's turn: the detached owner-turn tick expires it
	# without touching the authoritative party.
	var tick := CombatStatusTurnBatch.new().tick_side("heroes", run["heroes"])
	_check(tick.get("ok", false), "the detached hero owner-turn tick succeeds")
	if tick.get("ok", false):
		var actors: Array = tick.get("actors", [])
		_check(actors[2].get("statuses", {}).get("exposed", 0) == 0,
			"the owner-turn tick expires the Seamstress's Exposed 1")
	_check(run["heroes"][2].get("statuses", {}).get("exposed", 0) == 1,
		"the detached owner-turn tick does not mutate the authoritative party")

	# Replay: two independent runs of the same fixture agree completely.
	seed(FIXED_SEED)
	var replay_before := randi()
	seed(FIXED_SEED)
	var replay := _run_three_beats()
	_check(randi() == replay_before, "the replayed fixture draws no global RNG")
	_check(replay["results"] == results, "the replayed fixture produces identical phase results")
	_check(replay["hero_snapshots"] == run["hero_snapshots"],
		"the replayed fixture produces identical per-beat hero snapshots")
	_check(replay["enemy_snapshots"] == run["enemy_snapshots"],
		"the replayed fixture produces identical per-beat enemy snapshots")
	_check(replay["heroes"] == run["heroes"] and replay["enemies"] == run["enemies"],
		"the replayed fixture ends in identical party and enemy state")


## AC3: a legal Fight typed choice with local binding map binds the shipped
## enemy IDs; missing or mismatched local binding fails closed.
func _test_ac3_typed_selection_roster_and_negatives() -> void:
	# Valid selection with correct local binding
	var choice: Dictionary = {
		"success": true,
		"node_type": "Fight",
		"encounter_id": ENCOUNTER_ID,
		"definitions": _expected_definitions()
	}
	var assembled := _assemble_roster(choice)
	_check(assembled.get("ok") == true,
		"RunTypedBattleRoster.assemble binds the local encounter to the starter/run enemy catalogs")
	_check(assembled.get("node_type") == "Fight", "the assembled roster keeps the Fight node type")
	_check(assembled.get("encounter_id") == ENCOUNTER_ID,
		"the assembled roster keeps the authored encounter ID")
	_check(assembled.get("definitions", []) == _expected_definitions(),
		"the assembled roster keeps the exact authored definitions")
	var bridged: Variant = assembled.get("enemies")
	_check(bridged is CombatEnemies and bridged.is_valid(),
		"the assembled roster is a valid CombatEnemies")
	if bridged is CombatEnemies:
		_check(bridged.get_enemy(1).get("id") == "ragling_guard"
			and bridged.get_enemy(1).get("max_hp") == 12
			and bridged.get_enemy(1).get("hp") == 12
			and bridged.get_enemy(1).get("position") == 1,
			"assembled slot 1 is the shipped Guard Ragling with 12 HP")
		_check(bridged.get_enemy(2).get("id") == "spool_stalker"
			and bridged.get_enemy(2).get("max_hp") == 14
			and bridged.get_enemy(2).get("hp") == 14
			and bridged.get_enemy(2).get("position") == 2,
			"assembled slot 2 is the shipped Spool Stalker with 14 HP")

	# Negative: missing local binding fails closed
	var choice_missing_binding: Dictionary = {
		"success": true,
		"node_type": "Fight",
		"encounter_id": ENCOUNTER_ID,
		"definitions": _expected_definitions()
	}
	var assembled_missing := RunTypedBattleRoster.new().assemble(
		choice_missing_binding,
		{},  # Empty local binding map
		[STARTER_ENEMY_CATALOG_PATH, ENEMY_CATALOG_PATH]
	)
	_check(assembled_missing.get("ok") == false,
		"missing local binding fails closed")
	_check(choice_missing_binding.get("success") == true,
		"the input choice is unaltered after missing binding rejection")

	# Negative: mismatched local binding (wrong ID count) fails closed
	var choice_wrong_binding: Dictionary = {
		"success": true,
		"node_type": "Fight",
		"encounter_id": ENCOUNTER_ID,
		"definitions": _expected_definitions()
	}
	var assembled_wrong := RunTypedBattleRoster.new().assemble(
		choice_wrong_binding,
		{ENCOUNTER_ID: ["ragling_guard"]},  # Only one ID for two sources
		[STARTER_ENEMY_CATALOG_PATH, ENEMY_CATALOG_PATH]
	)
	_check(assembled_wrong.get("ok") == false,
		"mismatched local binding (wrong count) fails closed")
	_check(choice_wrong_binding.get("success") == true,
		"the input choice is unaltered after wrong binding rejection")

	# Negative: local binding with unknown enemy ID fails closed
	var choice_unknown_binding: Dictionary = {
		"success": true,
		"node_type": "Fight",
		"encounter_id": ENCOUNTER_ID,
		"definitions": _expected_definitions()
	}
	var assembled_unknown := RunTypedBattleRoster.new().assemble(
		choice_unknown_binding,
		{ENCOUNTER_ID: ["ragling_guard", "unknown_enemy"]},
		[STARTER_ENEMY_CATALOG_PATH, ENEMY_CATALOG_PATH]
	)
	_check(assembled_unknown.get("ok") == false,
		"local binding with unknown enemy ID fails closed")
	_check(choice_unknown_binding.get("success") == true,
		"the input choice is unaltered after unknown binding rejection")

	# Determinism: replaying fresh intents and party/enemy instances is deterministic
	seed(FIXED_SEED)
	var rng_before := randi()
	seed(FIXED_SEED)
	var run1 := _run_three_beats()
	_check(randi() == rng_before, "first replay draws no global RNG")
	seed(FIXED_SEED)
	var rng_before2 := randi()
	seed(FIXED_SEED)
	var run2 := _run_three_beats()
	_check(randi() == rng_before2, "second replay draws no global RNG")
	_check(run1["results"] == run2["results"], "independent runs produce identical phase results")
	_check(run1["hero_snapshots"] == run2["hero_snapshots"],
		"independent runs produce identical per-beat hero snapshots")
	_check(run1["enemy_snapshots"] == run2["enemy_snapshots"],
		"independent runs produce identical per-beat enemy snapshots")
	_check(run1["heroes"] == run2["heroes"] and run1["enemies"] == run2["enemies"],
		"independent runs end in identical party and enemy state")

	# The encounter is NOT added to the live typed pool and requires separate live wiring.
	var pools: Variant = JSON.parse_string(_read_text(TYPED_POOLS_PATH))
	_check(pools is Dictionary and pools.get("Fight") is Dictionary,
		"the shipped typed battle pool file still parses with a Fight pool")
	_check(not pools["Fight"].has(ENCOUNTER_ID),
		"the new encounter is not present in the live typed battle pool")