extends SceneTree

## Scene-free authored M03 Fight checks. These are standalone candidate schedules,
## deliberately NOT published to the live typed battle pool.
const SPINDLE := "spindle_cadence"
const NEEDLEWATCH := "needlewatch_steadyfire"
const ENCOUNTER_DIR := "res://data/encounters/"
const HERO_CATALOG := "res://data/heroes/starter_party.json"
const ENEMY_CATALOG := "res://data/enemies/run_enemies.json"
const REPLAY_SEED := 971126

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_data_and_rosters()
	for id in [SPINDLE, NEEDLEWATCH]:
		_test_announcements(id)
		_test_isolated_phase_beats(id)
		_test_slain_source(id)
		_test_selection_and_replay(id)
	_test_negative_parser_and_atomic_phase()
	_test_prechoice_and_nonfight_rejection()
	if failures.is_empty():
		print("m03_spindle_needlewatch_encounters_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("m03_spindle_needlewatch_encounters_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		_check(false, "required file missing: " + path)
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "required file opens: " + path)
	if file == null:
		return ""
	var result := file.get_as_text()
	file.close()
	return result


func _catalog(path: String) -> Array:
	var parsed: Variant = JSON.parse_string(_read_text(path))
	_check(parsed is Array, path + ": catalog JSON is an array")
	if not parsed is Array:
		return []
	var result: Array = []
	for record in parsed:
		_check(record is Dictionary, path + ": record is a dictionary")
		if not record is Dictionary:
			continue
		var copy: Dictionary = record.duplicate(true)
		var hp = copy.get("max_hp")
		_check((hp is int or hp is float) and float(hp) == floorf(float(hp))
			and float(hp) > 0.0, path + ": max_hp is a positive integer")
		if not (hp is int or hp is float) or float(hp) != floorf(float(hp)):
			continue
		copy["max_hp"] = int(hp)
		result.append(copy)
	return result


func _by_id(records: Array, id: String) -> Dictionary:
	var matches: Array = []
	for record in records:
		if record is Dictionary and record.get("id") == id:
			matches.append(record)
	_check(matches.size() == 1, id + ": exactly one catalog record")
	return matches[0].duplicate(true) if matches.size() == 1 else {}


func _enemy_ids(id: String) -> Array:
	if id == SPINDLE:
		return ["fray_scavenger", "spool_stalker", "seam_ripper"]
	return ["button_guard", "seam_ripper"]


func _enemy_hps(id: String) -> Array:
	if id == SPINDLE:
		return [14, 14, 18]
	return [16, 18]


func _party() -> CombatParty:
	var records := _catalog(HERO_CATALOG)
	var definitions: Array = []
	for id in ["warden", "seamstress", "tinker"]:
		definitions.append(_by_id(records, id))
	return CombatParty.new(definitions)


func _enemies(id: String) -> CombatEnemies:
	var records := _catalog(ENEMY_CATALOG)
	var definitions: Array = []
	for source_id in _enemy_ids(id):
		definitions.append(_by_id(records, source_id))
	return CombatEnemies.new(definitions)


func _fresh_party() -> CombatParty:
	var party := _party()
	_check(party.is_valid(), "real starter CombatParty is valid")
	if party.is_valid():
		var passive := CombatStartingBlock.new(party)
		_check(passive.apply(), "opening Warden +6 Block applies")
		_check(not passive.apply(), "opening Warden Block is strictly one-shot")
		_check(party.get_hero(1).get("block") == 6, "Warden starts with exactly 6 Block")
	return party


func _expected(id: String) -> Array:
	if id == SPINDLE:
		return [
			{"enemy_position": 1, "pattern": [
				{"type": "attack", "amount": 2, "target_position": 1},
				{"type": "block", "amount": 2},
				{"type": "attack", "amount": 3, "target_position": 2},
				{"type": "block", "amount": 2}]},
			{"enemy_position": 2, "pattern": [
				{"type": "attack", "amount": 3, "target_position": 2},
				{"type": "block", "amount": 2},
				{"type": "attack", "amount": 2, "target_position": 3},
				{"type": "block", "amount": 3}]},
			{"enemy_position": 3, "pattern": [
				{"type": "attack", "amount": 2, "target_position": 3},
				{"type": "block", "amount": 3},
				{"type": "attack", "amount": 4, "target_position": 1},
				{"type": "block", "amount": 2}]},
		]
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "block", "amount": 4},
			{"type": "attack", "amount": 5, "target_position": 1},
			{"type": "block", "amount": 2},
			{"type": "attack", "amount": 3, "target_position": 2}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 3, "target_position": 3},
			{"type": "attack", "amount": 4, "target_position": 1},
			{"type": "attack", "amount": 3, "target_position": 2},
			{"type": "block", "amount": 3}]},
	]


func _parsed(id: String) -> Array:
	return RunFightEncounterSelection._parse_schedule_text(_read_text(ENCOUNTER_DIR + id + ".json"))


func _beat(id: String, index: int) -> Array:
	var result: Array = []
	for source in _expected(id):
		var action: Dictionary = source["pattern"][index % 4].duplicate(true)
		action["enemy_position"] = source["enemy_position"]
		result.append(action)
	return result


func _events(id: String, index: int, dead_slot: int = 0) -> Array:
	var expected_events: Array = []
	for action in _beat(id, index):
		var entry := {
			"type": action["type"], "enemy_position": action["enemy_position"],
			"applied": action["enemy_position"] != dead_slot}
		if action["type"] == "attack":
			entry["target_position"] = action["target_position"]
		expected_events.append(entry)
	return expected_events


func _test_data_and_rosters() -> void:
	var records := _catalog(ENEMY_CATALOG)
	for id in [SPINDLE, NEEDLEWATCH]:
		var expected := _expected(id)
		var parsed := _parsed(id)
		_check(parsed == expected, id + ": exact authored slots, all 4 actions and amounts")
		_check(parsed.size() == _enemy_ids(id).size(),
			id + ": exact number of scheduled occupied source slots")
		_check(CombatEnemyIntents.new(parsed).is_valid(),
			id + ": real parsed schedule builds a valid intent scheduler")
		for source in parsed:
			_check(source["enemy_position"] is int, id + ": parsed slot is int")
			_check(source["pattern"].size() == 4, id + ": source has four authored beats")
			for action in source["pattern"]:
				_check(action["amount"] is int, id + ": parsed amount is int")
				if action.has("target_position"):
					_check(action["target_position"] is int, id + ": parsed target is int")
		var enemies := _enemies(id)
		_check(enemies.is_valid(), id + ": real ordered CombatEnemies roster valid")
		for index in range(_enemy_ids(id).size()):
			var source := enemies.get_enemy(index + 1)
			var definition := _by_id(records, _enemy_ids(id)[index])
			_check(source.get("position") == index + 1
				and source.get("id") == _enemy_ids(id)[index]
				and source.get("max_hp") == _enemy_hps(id)[index]
				and source.get("hp") == _enemy_hps(id)[index]
				and source.get("block") == 0
				and source.get("art_path") == definition.get("art_path"),
				id + ": shipped source identity/HP/art preserved in occupied slot %d" % (index + 1))
	var party := _fresh_party()
	var expected_ids := ["warden", "seamstress", "tinker"]
	var hps := [40, 30, 26]
	for i in range(3):
		var hero := party.get_hero(i + 1)
		_check(hero.get("id") == expected_ids[i] and hero.get("position") == i + 1
			and hero.get("max_hp") == hps[i] and hero.get("hp") == hps[i],
			"shipped starter hero in exact formation position %d" % (i + 1))
	# Previously shipped encounter must remain present and accepted.
	var holdout := RunFightEncounterSelection._parse_schedule_text(
		_read_text("res://data/encounters/buttonhole_holdout.json"))
	_check(not holdout.is_empty() and CombatEnemyIntents.new(holdout).is_valid(),
		"earlier buttonhole_holdout stays parseable and valid")


func _test_announcements(id: String) -> void:
	var scheduler := CombatEnemyIntents.new(_parsed(id))
	_check(scheduler.is_valid(), id + ": nonempty real scheduler for announcements")
	if not scheduler.is_valid():
		return
	for turn in range(9):
		var announced := scheduler.get_intents()
		_check(announced == _beat(id, turn), id + ": exact announced beat %d" % (turn + 1))
		if not announced.is_empty():
			announced[0]["amount"] = 999
			announced[0]["type"] = "forged"
			announced[0]["enemy_position"] = 3
			_check(scheduler.get_intents() == _beat(id, turn),
				id + ": get_intents returns detached source/action copies on beat %d" % (turn + 1))
		_check(scheduler.advance_turn(), id + ": advance_turn succeeds on beat %d" % (turn + 1))
	_check(scheduler.get_intents() == _beat(id, 9), id + ": scheduler continues periodic cycle")


func _expected_states(id: String) -> Array:
	if id == SPINDLE:
		return [
			{"heroes": [[40, 4], [27, 0], [24, 0]], "blocks": [0, 0, 0]},
			{"heroes": [[40, 6], [30, 0], [26, 0]], "blocks": [2, 2, 3]},
			{"heroes": [[40, 2], [27, 0], [24, 0]], "blocks": [0, 0, 0]},
			{"heroes": [[40, 6], [30, 0], [26, 0]], "blocks": [2, 3, 2]},
		]
	return [
		{"heroes": [[40, 6], [30, 0], [23, 0]], "blocks": [4, 0]},
		{"heroes": [[37, 0], [30, 0], [26, 0]], "blocks": [0, 0]},
		{"heroes": [[40, 6], [27, 0], [26, 0]], "blocks": [2, 0]},
		{"heroes": [[40, 6], [27, 0], [26, 0]], "blocks": [0, 3]},
	]


func _check_full_state(id: String, beat: int, party: CombatParty, enemies: CombatEnemies,
		before_heroes: Array, before_enemies: Array) -> void:
	var state: Dictionary = _expected_states(id)[beat]
	var expected_heroes := before_heroes.duplicate(true)
	var expected_enemies := before_enemies.duplicate(true)
	for i in range(3):
		expected_heroes[i]["hp"] = state["heroes"][i][0]
		expected_heroes[i]["block"] = state["heroes"][i][1]
	for i in range(_enemy_ids(id).size()):
		expected_enemies[i]["block"] = state["blocks"][i]
	_check(party.get_heroes() == expected_heroes,
		id + ": isolated beat %d all hero HP/Block, IDs, metadata and positions exact" % (beat + 1))
	_check(enemies.get_enemies() == expected_enemies,
		id + ": isolated beat %d all enemy HP/Block, IDs and slots exact" % (beat + 1))


func _test_isolated_phase_beats(id: String) -> void:
	for turn in range(5):
		var party := _fresh_party()
		var enemies := _enemies(id)
		_check(enemies.is_valid(), id + ": beat source roster valid")
		var scheduler := CombatEnemyIntents.new(_parsed(id))
		for preceding in range(turn):
			_check(scheduler.advance_turn(), id + ": move to isolated beat %d" % (preceding + 2))
		var announced := scheduler.get_intents()
		_check(announced == _beat(id, turn), id + ": isolated phase uses real announced actions")
		var before_heroes := party.get_heroes()
		var before_enemies := enemies.get_enemies()
		var phase := CombatEnemyPhase.new().execute_phase(party, enemies, announced)
		_check(phase.get("ok", false), id + ": real enemy phase executes isolated beat %d" % (turn + 1))
		_check(phase.get("events", []) == _events(id, turn),
			id + ": actual events are applied once in original source slot order on beat %d" % (turn + 1))
		_check_full_state(id, turn % 4, party, enemies, before_heroes, before_enemies)


func _test_slain_source(id: String) -> void:
	var party := _fresh_party()
	var enemies := _enemies(id)
	var source_to_slay := 2 if id == SPINDLE else 1
	_check(enemies.apply_damage(source_to_slay, _enemy_hps(id)[source_to_slay - 1]),
		id + ": actual CombatEnemies.apply_damage slays source")
	_check(enemies.is_slain(source_to_slay), id + ": slain source remains in original slot")
	var snapshot_enemies := enemies.get_enemies()
	var scheduler := CombatEnemyIntents.new(_parsed(id))
	var announced := scheduler.get_intents()
	_check(announced == _beat(id, 0), id + ": dead source still announces its own intent")
	var result := CombatEnemyPhase.new().execute_phase(party, enemies, announced)
	_check(result.get("ok", false) and result.get("events", []) == _events(id, 0, source_to_slay),
		id + ": dead source unapplied, living sources act in ascending unchanged slots")
	var expected_heroes := _party().get_heroes()
	expected_heroes[0]["block"] = 4 if id == SPINDLE else 6
	if id == SPINDLE:
		expected_heroes[2]["hp"] = 24
	else:
		expected_heroes[2]["hp"] = 23
	_check(party.get_heroes() == expected_heroes,
		id + ": no hit from slain source, but living hits resolve")
	_check(enemies.get_enemies() == snapshot_enemies,
		id + ": slain source still in original slot, no enemy compaction or phantom Block")


func _rng(value: int) -> RandomNumberGenerator:
	var result := RandomNumberGenerator.new()
	result.seed = value
	return result


func _opening_fight(map: RunMap) -> String:
	for choice in map.get_legal_choices():
		if map.get_node(choice).get("type") == "Fight":
			return choice
	return ""


func _map_snapshot(map: RunMap, rng: RandomNumberGenerator,
		selector: RunFightEncounterSelection) -> Dictionary:
	return {
		"floors": map.get_floors(),
		"route": map.get_route(),
		"current": map.get_current_node_id(),
		"choices": map.get_legal_choices(),
		"rng": rng.state,
		"selected": selector._selected.duplicate(true),
		"bound": selector._bound_map,
	}


func _test_selection_and_replay(id: String) -> void:
	var pool: Dictionary = {}
	pool[id] = ENCOUNTER_DIR + id + ".json"
	var rng := _rng(REPLAY_SEED)
	var replay_rng := _rng(REPLAY_SEED)
	var map := RunMap.new()
	var replay_map := RunMap.new()
	_check(map.generate(rng) and replay_map.generate(replay_rng),
		id + ": independently generated seeded real RunMaps")
	_check(map.get_floors() == replay_map.get_floors(),
		id + ": same-seed maps have identical graph")
	var fight := _opening_fight(map)
	_check(not fight.is_empty() and map.get_legal_choices().has(fight),
		id + ": opening node is a genuinely legal Fight")
	if fight.is_empty():
		return
	_check(map.choose_node(fight) and replay_map.choose_node(fight),
		id + ": both RunMaps legally choose the real Fight")
	var picker := RunFightEncounterSelection.new()
	var replay_picker := RunFightEncounterSelection.new()
	var prior := _map_snapshot(map, rng, picker)
	_check(picker.select_current_fight(map, rng, {"bad": ENCOUNTER_DIR + "not_a_fight.json"})
		== {"success": false}, id + ": missing resource rejected on chosen Fight")
	_check(picker.select_current_fight(map, rng,
		{id: ENCOUNTER_DIR + id + ".json", "invalid": "res://data/enemies/run_enemies.json"})
		== {"success": false}, id + ": invalid candidate rejects whole pool")
	_check(_map_snapshot(map, rng, picker) == prior,
		id + ": bad pools don't advance map/RNG or bind/cache selector")
	seed(197100 + id.length())
	var global_expected := randi()
	seed(197100 + id.length())
	var chosen := picker.select_current_fight(map, rng, pool)
	_check(randi() == global_expected, id + ": legal selection does not touch global RNG")
	var canonical := chosen.duplicate(true)
	_check(chosen.get("success", false) and chosen.get("encounter_id") == id
		and chosen.get("definitions", []) == _expected(id),
		id + ": standalone one-ID pool selects exact parsed new Fight")
	_check(map.get_route() == [fight] and map.get_current_node_id() == fight,
		id + ": selection leaves the real chosen route untouched")
	var selected_state := rng.state
	chosen["definitions"][0]["pattern"][0]["amount"] = 999
	chosen["definitions"][0]["pattern"][0]["type"] = "forged"
	chosen["definitions"].clear()
	chosen["encounter_id"] = "mutated"
	var cached := picker.select_current_fight(map, rng, {})
	_check(cached == canonical and rng.state == selected_state,
		id + ": cached selection makes no RNG draw and resists caller mutation")
	cached["definitions"][0]["pattern"][0]["amount"] = 111
	var pristine := picker.select_current_fight(map, rng, pool)
	_check(pristine == canonical and rng.state == selected_state,
		id + ": repeated cached selection is a fresh deep copy")
	var replay := replay_picker.select_current_fight(replay_map, replay_rng, pool)
	_check(replay == pristine and replay_rng.state == rng.state
		and replay_map.get_route() == map.get_route(),
		id + ": new run with same seed replays selection, definitions, route and RNG")
	_check(CombatEnemyIntents.new(pristine.get("definitions", [])).is_valid()
		and CombatEnemyIntents.new(replay.get("definitions", [])).is_valid(),
		id + ": selected definitions instantiate real valid schedulers")
	var first_intents := CombatEnemyIntents.new(pristine["definitions"])
	var second_intents := CombatEnemyIntents.new(replay["definitions"])
	for turn in range(5):
		var first_actions := first_intents.get_intents()
		var second_actions := second_intents.get_intents()
		_check(first_actions == second_actions and first_actions == _beat(id, turn),
			id + ": replay exact full announced beat %d" % (turn + 1))
		var party_a := _fresh_party()
		var party_b := _fresh_party()
		var enemies_a := _enemies(id)
		var enemies_b := _enemies(id)
		var outcome_a := CombatEnemyPhase.new().execute_phase(party_a, enemies_a, first_actions)
		var outcome_b := CombatEnemyPhase.new().execute_phase(party_b, enemies_b, second_actions)
		_check(outcome_a.get("ok", false) and outcome_a == outcome_b
			and outcome_a.get("events", []) == _events(id, turn),
			id + ": same-seed replay matches real applied ordered phase events %d" % (turn + 1))
		_check(party_a.get_heroes() == party_b.get_heroes()
			and enemies_a.get_enemies() == enemies_b.get_enemies(),
			id + ": replay full actual party/enemy snapshots identical %d" % (turn + 1))
		_check(first_intents.advance_turn() and second_intents.advance_turn(),
			id + ": both schedulers advance for replay")
	_check(rng.state == replay_rng.state and rng.state == selected_state,
		id + ": real phase/replay consumes no extra run RNG")


func _test_negative_parser_and_atomic_phase() -> void:
	var malformed := [
		'[{"enemy_position":1,"pattern":[{"type":"block","amount":2}]},' +
			'{"enemy_position":1,"pattern":[{"type":"block","amount":3}]}]',
		'[{"enemy_position":1,"pattern":[{"type":"attack","amount":2,"target_position":4}]}]',
		'[{"enemy_position":1,"pattern":[{"type":"heal","amount":2}]}]',
		'[{"enemy_position":1,"pattern":[{"type":"block","amount":"2"}]}]',
		'[{"enemy_position":1,"pattern":[{"type":"attack","amount":2.5,"target_position":1}]}]',
		'[{"enemy_position":1,"pattern":[{"type":"attack","amount":2,"target_position":1.5}]}]',
		'[{"enemy_position":1.5,"pattern":[{"type":"block","amount":2}]}]',
		'[{"enemy_position":1,"pattern":[{"type":"attack","amount":0,"target_position":1,"extra":1}]}]',
	]
	var party := _fresh_party()
	var enemies := _enemies(SPINDLE)
	var before_party := party.get_heroes()
	var before_enemies := enemies.get_enemies()
	seed(20260971)
	var global_expected := randi()
	seed(20260971)
	for i in range(malformed.size()):
		_check(RunFightEncounterSelection._parse_schedule_text(malformed[i]).is_empty(),
			"invalid schedule text %d rejected by real parser" % i)
	_check(randi() == global_expected, "malformed parser consumes no global RNG")
	_check(party.get_heroes() == before_party and enemies.get_enemies() == before_enemies,
		"malformed data parsing does not mutate source party/enemy rosters")
	# The first (valid) source would stage +4 Block; the later bad target
	# must reject the WHOLE batch with no earlier changes published.
	var bad_batch := [
		{"type": "block", "amount": 4, "enemy_position": 1},
		{"type": "attack", "amount": 3, "target_position": 4, "enemy_position": 2}]
	seed(30260971)
	global_expected = randi()
	seed(30260971)
	var rejected := CombatEnemyPhase.new().execute_phase(party, enemies, bad_batch)
	_check(rejected == {"ok": false, "events": []},
		"invalid later source makes real CombatEnemyPhase reject all earlier staged work")
	_check(randi() == global_expected, "rejected phase consumes no global RNG")
	_check(party.get_heroes() == before_party and enemies.get_enemies() == before_enemies,
		"rejected phase preserves entire party and enemies without partial Block")
	_check(CombatEnemyIntents.new(_parsed(SPINDLE)).is_valid(),
		"valid authored intents remain usable after parser and phase rejection")


func _test_prechoice_and_nonfight_rejection() -> void:
	var rng := _rng(28943)
	var map := RunMap.new()
	var picker := RunFightEncounterSelection.new()
	_check(map.generate(rng), "negative map is a genuinely generated seeded RunMap")
	_check(not _opening_fight(map).is_empty(), "legal opening Fight exists before choosing")
	var before := _map_snapshot(map, rng, picker)
	var pool := {SPINDLE: ENCOUNTER_DIR + SPINDLE + ".json"}
	_check(picker.select_current_fight(map, rng, pool) == {"success": false},
		"legally offered but not yet chosen Fight rejected")
	_check(_map_snapshot(map, rng, picker) == before,
		"pre-choice rejection leaves full map, route, selector and run RNG unchanged")
	var nonfight := ""
	for floor_index in range(RunMap.FLOOR_COUNT):
		var legal := map.get_legal_choices()
		if legal.is_empty():
			break
		var pick: String = legal[0]
		for candidate in legal:
			if map.get_node(candidate).get("type") != "Fight":
				pick = candidate
				break
		_check(map.choose_node(pick), "non-Fight probe chooses an actual legal node")
		if map.get_node(pick).get("type") != "Fight":
			nonfight = pick
			break
	_check(not nonfight.is_empty(), "seeded route actually reached a non-Fight node")
	if nonfight.is_empty():
		return
	before = _map_snapshot(map, rng, picker)
	_check(picker.select_current_fight(map, rng, pool) == {"success": false},
		"chosen non-Fight node rejected")
	_check(_map_snapshot(map, rng, picker) == before,
		"non-Fight rejection leaves entire map, route, run RNG and cache unchanged")
