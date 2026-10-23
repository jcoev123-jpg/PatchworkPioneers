extends SceneTree
const WEIGHTED = preload("res://tests/weighted_roster_assert.gd")

## Deterministic headless coverage for the authored Buttonrail Frontshift
## encounter (standalone M04 Fight content; NOT registered in the live pool):
##   enemy_position 1 (Button Guard): beat 1 shove, beat 2 Exposed debuff, beat 3 Block.
##   enemy_position 2 (Spool Stalker): beat 1 attack 3, beat 2 attack 4, beat 3 attack 2.
## Beat 1 swaps the middle Seamstress (2) with the front Warden (1) BEFORE the
## Stalker strikes slot 1, so the Seamstress - not the Warden - loses 3 HP.
## Beat 2 marks the rear Tinker (3) Exposed 1 BEFORE the base-4 hit, so it deals
## floor(4 * 1.5) = 6. Beat 3 the Guard takes exactly 3 Block while the Stalker
## hits the now-middle Warden for 2. No live wiring, pool entry or UI here.

const ENCOUNTER_PATH := "res://data/encounters/buttonrail_frontshift.json"
const ENCOUNTER_ID := "buttonrail_frontshift"
const FRONT_HEM_PIVOT_PATH := "res://data/encounters/front_hem_pivot.json"
const TYPED_POOLS_PATH := "res://data/encounters/m03_typed_battle_pools.json"
const ENEMY_CATALOG_PATH := "res://data/enemies/run_enemies.json"
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
		print("buttonrail_frontshift_encounter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("buttonrail_frontshift_encounter_test: FAIL (", failures.size(), " failures)")
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
				{"type": "shove", "amount": 0, "target_position": 2, "direction": -1},
				{"type": "debuff", "amount": 1, "target_position": 3, "status": "exposed"},
				{"type": "block", "amount": 3}
			]
		},
		{
			"enemy_position": 2,
			"pattern": [
				{"type": "attack", "amount": 3, "target_position": 1},
				{"type": "attack", "amount": 4, "target_position": 3},
				{"type": "attack", "amount": 2, "target_position": 2}
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
	var roster := _load_catalog(ENEMY_CATALOG_PATH)
	var definitions: Array = []
	for id in ["button_guard", "spool_stalker"]:
		definitions.append(_record_by_id(roster, id))
	var enemies := CombatEnemies.new(definitions)
	_check(enemies.is_valid(), "the two shipped enemies build a valid CombatEnemies")
	return enemies


func _hero_record(id: String) -> Dictionary:
	return _record_by_id(_load_catalog(HERO_CATALOG_PATH), id)


func _enemy_record(id: String) -> Dictionary:
	return _record_by_id(_load_catalog(ENEMY_CATALOG_PATH), id)


func _assemble_roster(typed_choice: Dictionary) -> Dictionary:
	return RunTypedBattleRoster.new().assemble(
		typed_choice,
		{ENCOUNTER_ID: ["button_guard", "spool_stalker"]},
		[ENEMY_CATALOG_PATH]
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
		"source 2 holds the exact 3 / 4 / 2 attack beat records")
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
## the two shipped enemies, with 0 Block and no starting statuses.
func _run_three_beats() -> Dictionary:
	var loaded := RunFightEncounterSelection._parse_schedule_text(_read_text(ENCOUNTER_PATH))
	var party := _build_party()
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
	_check(enemies.get_enemy(1).get("id") == "button_guard"
		and enemies.get_enemy(1).get("max_hp") == 16 and enemies.get_enemy(1).get("hp") == 16
		and enemies.get_enemy(1).get("block") == 0,
		"enemy slot 1 is the shipped Button Guard with 16 max HP")
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
		"beat 1 succeeds with the shove then the 3 attack")
	_check(results[1] == {"ok": true, "events": _expected_events(1)},
		"beat 2 succeeds with the Exposed debuff then the 4 attack")
	_check(results[2] == {"ok": true, "events": _expected_events(2)},
		"beat 3 succeeds with the Guard Block then the 2 attack")
	_check(run["repeating"] == _expected_beat(0), "beat 4 announces beat 1 again")

	# Beat 1: the shove swaps Seamstress (2) with Warden (1) before the Stalker
	# strikes slot 1, so the Seamstress takes the 3 damage, not the Warden.
	var heroes: Array = run["hero_snapshots"][0]
	_check(heroes[0].get("id") == "seamstress" and heroes[0].get("position") == 1,
		"beat 1: the Seamstress now occupies hero position 1")
	_check(heroes[1].get("id") == "warden" and heroes[1].get("position") == 2,
		"beat 1: the Warden now occupies hero position 2")
	_check(heroes[2].get("id") == "tinker" and heroes[2].get("position") == 3,
		"beat 1: the Tinker keeps hero position 3")
	_check(heroes[0].get("hp") == 27 and heroes[0].get("block") == 0,
		"beat 1: the front Seamstress took the 3 damage (30 to 27)")
	_check(heroes[1].get("hp") == 40 and heroes[1].get("block") == 0,
		"beat 1: the middle Warden is untouched at 40 HP")
	_check(heroes[2].get("hp") == 26 and heroes[2].get("block") == 0,
		"beat 1: the rear Tinker is untouched at 26 HP")
	var beat1_foes: Array = run["enemy_snapshots"][0]
	_check(beat1_foes[0].get("id") == "button_guard" and beat1_foes[0].get("block") == 0
		and beat1_foes[0].get("hp") == 16,
		"beat 1: the Button Guard is unchanged at 16 HP and 0 Block")
	_check(beat1_foes[1].get("id") == "spool_stalker" and beat1_foes[1].get("block") == 0
		and beat1_foes[1].get("hp") == 14,
		"beat 1: the Spool Stalker is unchanged at 14 HP and 0 Block")
	var seamstress := _hero_record("seamstress")
	_check(heroes[0].get("name") == seamstress.get("name")
		and heroes[0].get("max_hp") == seamstress.get("max_hp")
		and heroes[0].get("art_path") == seamstress.get("art_path"),
		"beat 1: the swapped hero keeps every unrelated record field")

	# Beat 2: Exposed 1 lands on the rear Tinker before the base-4 attack.
	heroes = run["hero_snapshots"][1]
	_check(heroes[2].get("hp") == 20 and heroes[2].get("block") == 0,
		"beat 2: the Exposed Tinker took floor(4 * 1.5) = 6 damage (26 to 20)")
	_check(heroes[2].get("statuses", {}).get("exposed", 0) == 1,
		"beat 2: the Tinker carries Exposed 1")
	_check(heroes[0].get("id") == "seamstress" and heroes[0].get("hp") == 27,
		"beat 2: the front Seamstress is unchanged at 27 HP")
	_check(heroes[1].get("id") == "warden" and heroes[1].get("hp") == 40,
		"beat 2: the middle Warden is unchanged at 40 HP")
	_check(heroes[0].get("statuses", {}).get("exposed", 0) == 0
		and heroes[1].get("statuses", {}).get("exposed", 0) == 0,
		"beat 2: Exposed 1 lands only on the targeted rear hero")
	var beat2_foes: Array = run["enemy_snapshots"][1]
	_check(beat2_foes[0].get("block") == 0 and beat2_foes[1].get("block") == 0,
		"beat 2: neither enemy gained Block yet")

	# Beat 3: the Guard banks exactly 3 Block while the Stalker hits the middle Warden.
	heroes = run["hero_snapshots"][2]
	var foes: Array = run["enemy_snapshots"][2]
	_check(foes[0].get("id") == "button_guard" and foes[0].get("block") == 3
		and foes[0].get("hp") == 16,
		"beat 3: the Button Guard holds exactly 3 Block and 16 HP")
	_check(foes[1].get("id") == "spool_stalker" and foes[1].get("block") == 0
		and foes[1].get("hp") == 14,
		"beat 3: the Spool Stalker holds 0 Block and 14 HP")
	var guard := _enemy_record("button_guard")
	_check(foes[0].get("name") == guard.get("name")
		and foes[0].get("max_hp") == guard.get("max_hp")
		and foes[0].get("art_path") == guard.get("art_path"),
		"beat 3: the enemy record keeps every unrelated field")
	_check(heroes[1].get("id") == "warden" and heroes[1].get("hp") == 38
		and heroes[1].get("block") == 0,
		"beat 3: the now-middle Warden took 2 damage (40 to 38)")
	_check(heroes[0].get("id") == "seamstress" and heroes[0].get("hp") == 27,
		"beat 3: the front Seamstress is unchanged at 27 HP")
	_check(heroes[2].get("id") == "tinker" and heroes[2].get("hp") == 20,
		"beat 3: the rear Tinker keeps 20 HP")

	# Exposed lasts its owner's turn: the detached owner-turn tick expires it
	# without touching the authoritative party.
	var tick := CombatStatusTurnBatch.new().tick_side("heroes", run["heroes"])
	_check(tick.get("ok", false), "the detached hero owner-turn tick succeeds")
	if tick.get("ok", false):
		var actors: Array = tick.get("actors", [])
		_check(actors[2].get("statuses", {}).get("exposed", 0) == 0,
			"the owner-turn tick expires the Tinker's Exposed 1")
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


## AC3: a legal seeded RunMap Fight route selects this encounter through a
## test-local pool with a stable cache, the typed roster bridge binds the shipped
## enemy IDs, the existing front_hem_pivot schedule still parses and a downed
## participant fails the beat-1 shove closed.
func _test_ac3_typed_selection_roster_and_negatives() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = FIXED_SEED
	var map := RunMap.new()
	_check(map.generate(rng), "the seeded run map generates")

	var fight_id := ""
	for node_id in map.get_legal_choices():
		if map.get_node(node_id).get("type") == "Fight":
			fight_id = node_id
			break
	_check(not fight_id.is_empty(), "the seeded map offers a legal Fight node")
	_check(map.choose_node(fight_id), "the legal Fight node is chosen")
	_check(map.get_current_node_id() == fight_id
		and map.get_node(fight_id).get("type") == "Fight",
		"the current route node is the chosen Fight")

	var pool := {"Fight": {ENCOUNTER_ID: ENCOUNTER_PATH}}
	var selector := RunFightEncounterSelection.new()
	var state_before := rng.state
	var choice := selector.select_current_battle(map, rng, pool)
	var state_after := rng.state
	_check(choice.get("success", false), "the test-local pool selects the authored Fight")
	_check(choice.get("node_type") == "Fight", "the selection reports a Fight node")
	_check(choice.get("encounter_id") == ENCOUNTER_ID,
		"the selection is the buttonrail_frontshift encounter")
	_check(choice.get("definitions", []) == _expected_definitions(),
		"the selection returns the exact authored schedule")

	# The selector spends exactly the one candidate draw of this pool and nothing
	# else: an oracle run from the same seed reaches the same RNG state.
	var oracle_rng := RandomNumberGenerator.new()
	oracle_rng.seed = FIXED_SEED
	var oracle_map := RunMap.new()
	_check(oracle_map.generate(oracle_rng), "the oracle map generates")
	_check(oracle_map.choose_node(fight_id), "the oracle map chooses the same Fight node")
	_check(state_before == oracle_rng.state, "the run RNG state before selection matches the oracle")
	oracle_rng.randi_range(0, 0)
	_check(state_after == oracle_rng.state,
		"the first selection spends exactly the pool's single candidate draw")

	var cached := selector.select_current_battle(map, rng, pool)
	_check(cached == choice, "the cached selection repeats the same choice")
	_check(rng.state == state_after, "the cached selection draws no further RNG")

	var replay_rng := RandomNumberGenerator.new()
	replay_rng.seed = FIXED_SEED
	var replay_map := RunMap.new()
	_check(replay_map.generate(replay_rng), "the replayed seeded map generates")
	_check(replay_map.choose_node(fight_id), "the replayed map chooses the same Fight node")
	var replay_choice := RunFightEncounterSelection.new().select_current_battle(
		replay_map, replay_rng, pool)
	_check(replay_choice == choice, "a fresh same-seed run selects the same encounter")
	_check(replay_rng.state == rng.state, "a fresh same-seed run leaves the same RNG state")

	# A pool with two real candidates draws an index, so the cached repeat is
	# proven to skip the draw instead of being vacuously true.
	var wide_rng := RandomNumberGenerator.new()
	wide_rng.seed = FIXED_SEED
	var wide_map := RunMap.new()
	_check(wide_map.generate(wide_rng), "the two-candidate map generates")
	_check(wide_map.choose_node(fight_id), "the two-candidate map chooses the same Fight node")
	var wide_selector := RunFightEncounterSelection.new()
	var wide_before := wide_rng.state
	var wide_choice := wide_selector.select_current_battle(wide_map, wide_rng, {
		"Fight": {ENCOUNTER_ID: ENCOUNTER_PATH, "front_hem_pivot": FRONT_HEM_PIVOT_PATH}})
	var wide_after := wide_rng.state
	_check(wide_choice.get("success", false), "the two-candidate pool selects a real encounter")
	_check(wide_after != wide_before, "a two-candidate pool really spends one selection draw")
	var wide_cached := wide_selector.select_current_battle(wide_map, wide_rng, {
		"Fight": {ENCOUNTER_ID: ENCOUNTER_PATH, "front_hem_pivot": FRONT_HEM_PIVOT_PATH}})
	_check(wide_cached == wide_choice, "the two-candidate cached selection repeats the same choice")
	_check(wide_rng.state == wide_after, "the two-candidate cached selection draws no further RNG")

	var assembled := _assemble_roster(choice)
	_check(assembled.get("ok") == true,
		"RunTypedBattleRoster.assemble binds the local encounter to the run enemy catalog")
	_check(assembled.get("node_type") == "Fight", "the assembled roster keeps the Fight node type")
	_check(assembled.get("encounter_id") == ENCOUNTER_ID,
		"the assembled roster keeps the authored encounter ID")
	_check(assembled.get("definitions", []) == _expected_definitions(),
		"the assembled roster keeps the exact authored definitions")
	var bridged: Variant = assembled.get("enemies")
	_check(bridged is CombatEnemies and bridged.is_valid(),
		"the assembled roster is a valid CombatEnemies")
	if bridged is CombatEnemies:
		_check(bridged.get_enemy(1).get("id") == "button_guard"
			and bridged.get_enemy(1).get("max_hp") == 16
			and bridged.get_enemy(1).get("hp") == 16
			and bridged.get_enemy(1).get("position") == 1,
			"assembled slot 1 is the shipped Button Guard with 16 HP")
		_check(bridged.get_enemy(2).get("id") == "spool_stalker"
			and bridged.get_enemy(2).get("max_hp") == 14
			and bridged.get_enemy(2).get("hp") == 14
			and bridged.get_enemy(2).get("position") == 2,
			"assembled slot 2 is the shipped Spool Stalker with 14 HP")
		_check(WEIGHTED.same(bridged.get_enemies(), _build_enemies().get_enemies()),
			"the bridged roster equals the roster built straight from the shipped catalog")

	# The shipped typed pool stays untouched and readable; no global Fight count
	# or order is asserted here.
	var pools: Variant = JSON.parse_string(_read_text(TYPED_POOLS_PATH))
	_check(pools is Dictionary and pools.get("Fight") is Dictionary,
		"the shipped typed battle pool file still parses with a Fight pool")

	# The existing authored encounter still parses on its own.
	var pivot := RunFightEncounterSelection._parse_schedule_text(_read_text(FRONT_HEM_PIVOT_PATH))
	_check(not pivot.is_empty(), "the existing front_hem_pivot schedule still parses")
	_check(CombatEnemyIntents.new(pivot).is_valid(),
		"the existing front_hem_pivot schedule still validates")
	_check(pivot != _expected_definitions(),
		"the new schedule is distinct from the existing front_hem_pivot schedule")

	# Targeted negative: the beat-1 shove cannot swap a downed middle hero or a
	# downed front neighbour, so the whole proposed phase fails closed.
	for downed_position in [2, 1]:
		var party := _build_party()
		var enemies := _build_enemies()
		var downed_hp: int = party.get_hero(downed_position).get("max_hp")
		_check(party.apply_damage(downed_position, downed_hp),
			"the hero in position %d is downed for the negative case" % downed_position)
		_check(party.is_downed(downed_position),
			"the downed precondition holds for position %d" % downed_position)
		var preview := CombatPositionSwaps.preview_adjacent_swap(party, 2, -1)
		_check(not preview.get("ok", false),
			"the beat-1 shove cannot swap positions 2 and 1 while one of them is downed")
		var before_party := party.get_heroes()
		var before_enemies := enemies.get_enemies()
		var intents := CombatEnemyIntents.new(_expected_definitions())
		var result := phase.execute_phase(party, enemies, intents.get_intents())
		_check(result == {"ok": false, "events": []},
			"the beat-1 shove fails the phase when position %d is downed" % downed_position)
		_check(party.get_heroes() == before_party,
			"the authoritative party is unchanged after the rejected phase (position %d)"
				% downed_position)
		_check(enemies.get_enemies() == before_enemies,
			"the authoritative enemy roster is unchanged after the rejected phase (position %d)"
				% downed_position)
