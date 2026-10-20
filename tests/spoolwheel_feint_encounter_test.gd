extends SceneTree
## Standalone M03 content test: no live run/UI registration.

const FEINT := "res://data/encounters/spoolwheel_feint.json"
const STARTER := "res://data/encounters/starter_attacks.json"
const GUARD := "res://data/encounters/guard_counterattack.json"
const HEROES := "res://data/heroes/starter_party.json"
const ENEMIES := "res://data/enemies/starter_enemies.json"

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_authored_data()
	_test_announcements()
	_test_combat_and_replay()
	_test_dead_source_and_rejections()
	_test_single_pool_selection()
	if failures.is_empty():
		print("spoolwheel_feint_encounter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("spoolwheel_feint_encounter_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, detail: String) -> void:
	checks += 1
	if not condition:
		failures.append(detail)


func _read(path: String) -> String:
	_check(FileAccess.file_exists(path), "authored file exists: " + path)
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "authored file opens: " + path)
	if file == null:
		return ""
	var contents := file.get_as_text()
	file.close()
	return contents


func _schedule(path: String) -> Array:
	return RunFightEncounterSelection._parse_schedule_text(_read(path))


func _attack(owner: int, target: int) -> Dictionary:
	return {"type": "attack", "amount": 1, "target_position": target,
		"enemy_position": owner}


func _block(owner: int) -> Dictionary:
	return {"type": "block", "amount": 1, "enemy_position": owner}


func _expected_schedule() -> Array:
	return [
		{"enemy_position": 1, "pattern": [
			{"type": "block", "amount": 1},
			{"type": "attack", "amount": 1, "target_position": 2}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 1, "target_position": 1},
			{"type": "attack", "amount": 1, "target_position": 3},
			{"type": "block", "amount": 1}]},
	]


func _expected_beats() -> Array:
	return [
		[_block(1), _attack(2, 1)],
		[_attack(1, 2), _attack(2, 3)],
		[_block(1), _block(2)],
		[_attack(1, 2), _attack(2, 1)],
		[_block(1), _attack(2, 3)],
		[_attack(1, 2), _block(2)],
	]


func _unique(records: Array, field: String, id: Variant) -> Dictionary:
	var found: Array = []
	for record in records:
		if record is Dictionary and record.get(field) == id:
			found.append(record)
	_check(found.size() == 1, "exactly one %s=%s record" % [field, str(id)])
	return found[0].duplicate(true) if found.size() == 1 else {}


func _test_authored_data() -> void:
	var raw := _read(FEINT)
	var parsed := RunFightEncounterSelection._parse_schedule_text(raw)
	var expected := _expected_schedule()
	_check(parsed == expected, "AC1: parsed new file has exact two positions and 2/3 action patterns")
	_check(parsed.size() == 2, "AC1: standalone new encounter has two enemy sources")
	if parsed.size() == 2:
		for i in range(2):
			var definition: Dictionary = parsed[i]
			_check(definition["enemy_position"] is int, "AC1: parsed position %d is int" % i)
			for action in definition["pattern"]:
				_check(action["amount"] is int, "AC1: parsed action amount is int")
				if action["type"] == "attack":
					_check(action["target_position"] is int, "AC1: parsed target is int")
	_check(CombatEnemyIntents.new(parsed).is_valid(), "AC1: exact file accepted by real scheduler")

	var baselines := [
		{"path": STARTER, "positions": [
			{"enemy_position": 1, "pattern": [
				{"type": "attack", "amount": 1, "target_position": 1},
				{"type": "attack", "amount": 1, "target_position": 2},
				{"type": "attack", "amount": 1, "target_position": 3}]},
			{"enemy_position": 2, "pattern": [{"type": "block", "amount": 1}]}]},
		{"path": GUARD, "positions": [
			{"enemy_position": 1, "pattern": [
				{"type": "block", "amount": 1},
				{"type": "attack", "amount": 1, "target_position": 1}]},
			{"enemy_position": 2, "pattern": [
				{"type": "attack", "amount": 1, "target_position": 3},
				{"type": "block", "amount": 1}]}]},
	]
	for baseline in baselines:
		var original := _schedule(baseline["path"])
		_check(CombatEnemyIntents.new(original).is_valid(),
			"AC1: named previous schedule remains valid: " + baseline["path"])
		for source in baseline["positions"]:
			var actual := _unique(original, "enemy_position", source["enemy_position"])
			_check(actual == source, "AC1: all ordered baseline actions preserved at %s source %d" %
				[baseline["path"], source["enemy_position"]])
	_check(_read(FEINT) == raw, "AC1: authored file bytes unchanged after validation")


func _test_announcements() -> void:
	var definitions := _schedule(FEINT)
	var pristine := definitions.duplicate(true)
	var expected := _expected_beats()
	var first := CombatEnemyIntents.new(definitions)
	var second := CombatEnemyIntents.new(definitions.duplicate(true))
	_check(first.is_valid() and second.is_valid(), "AC2: both independent schedulers valid")
	if not first.is_valid() or not second.is_valid():
		return

	for beat in range(7):
		var a := first.get_intents()
		var b := second.get_intents()
		_check(a == expected[beat % 6] and b == expected[beat % 6],
			"AC2: phase %d exact ordered pair (including phase 6 wrap)" % beat)
		_check(a == b and a.size() == 2
			and a[0]["enemy_position"] == 1 and a[1]["enemy_position"] == 2,
			"AC2: phase %d fresh scheduler replay and source-slot order" % beat)
		var dirty := a.duplicate(true)
		dirty[0]["amount"] = 999
		dirty[1]["enemy_position"] = 3
		dirty.append({"invented": true})
		_check(first.get_intents() == expected[beat % 6]
			and second.get_intents() == expected[beat % 6],
			"AC2: phase %d returned intent snapshots are independent" % beat)
		if beat < 6:
			_check(first.advance_turn() and second.advance_turn(),
				"AC2: phase %d advances ONCE for the whole enemy phase" % beat)
	_check(definitions == pristine and _schedule(FEINT) == pristine,
		"AC2: original caller data and file unchanged after cycling")


func _catalog(path: String) -> Array:
	var parsed: Variant = JSON.parse_string(_read(path))
	_check(parsed is Array, "catalog parses as an Array: " + path)
	if not parsed is Array:
		return []
	# JSON represents whole-valued max_hp as a float in some Godot versions.
	# Validate it before conversion; no fractional or unsafe HP is accepted.
	for entry in parsed:
		if not entry is Dictionary or not entry.has("max_hp"):
			return []
		var hp: Variant = entry["max_hp"]
		if hp is float:
			if is_nan(hp) or is_inf(hp) or hp <= 0 or hp > 9007199254740991.0 \
					or floorf(hp) != hp:
				return []
			entry["max_hp"] = int(hp)
	return parsed


func _party() -> CombatParty:
	var records := _catalog(HEROES)
	var definitions: Array = []
	for id in ["warden", "seamstress", "tinker"]:
		definitions.append(_unique(records, "id", id))
	return CombatParty.new(definitions)


func _enemies() -> CombatEnemies:
	var records := _catalog(ENEMIES)
	var definitions: Array = []
	for id in ["ragling", "ragling_guard"]:
		definitions.append(_unique(records, "id", id))
	return CombatEnemies.new(definitions)


func _fixture_ok(party: CombatParty, enemies: CombatEnemies, prefix: String) -> bool:
	var valid := party.is_valid() and enemies.is_valid()
	_check(valid, prefix + ": real starter CombatParty and CombatEnemies are valid")
	if not valid:
		return false
	for i in range(3):
		var hero := party.get_hero(i + 1)
		var hp: int = [40, 30, 26][i]
		var id: String = ["warden", "seamstress", "tinker"][i]
		_check(hero["id"] == id and hero["hp"] == hp
			and hero["max_hp"] == hp and hero["block"] == 0
			and hero["position"] == i + 1,
			prefix + ": %s correct slot, HP and zero isolated Block" % id)
	for i in range(2):
		var enemy := enemies.get_enemy(i + 1)
		var id: String = ["ragling", "ragling_guard"][i]
		_check(enemy["id"] == id and enemy["hp"] == 12 and enemy["max_hp"] == 12
			and enemy["position"] == i + 1 and enemy["block"] == 0
			and enemy["art_path"] == "res://assets/paper/enemies/ragling.png",
			prefix + ": %s correct slot, art, HP and zero Block" % id)
	return true


func _expected_events(intents: Array, dead_source: int = 0) -> Array:
	var events: Array = []
	for intent in intents:
		var event := {"type": intent["type"], "enemy_position": intent["enemy_position"],
			"applied": intent["enemy_position"] != dead_source}
		if intent["type"] == "attack":
			event["target_position"] = intent["target_position"]
		events.append(event)
	return events


func _run_six(label: String) -> Array:
	var party := _party()
	var enemies := _enemies()
	if not _fixture_ok(party, enemies, label):
		return []
	var scheduler := CombatEnemyIntents.new(_schedule(FEINT))
	_check(scheduler.is_valid(), label + ": parsed schedule instantiates")
	if not scheduler.is_valid():
		return []
	var phase := CombatEnemyPhase.new()
	var expected := _expected_beats()
	var hero_hp := [
		[39, 30, 26], [39, 29, 25], [39, 29, 25],
		[38, 28, 25], [38, 28, 24], [38, 27, 24],
	]
	var enemy_blocks := [
		[1, 0], [1, 0], [2, 1], [2, 1], [3, 1], [3, 2],
	]
	var initial_heroes := party.get_heroes()
	var initial_enemies := enemies.get_enemies()
	var trace: Array = []
	for beat in range(6):
		var intents := scheduler.get_intents()
		var untouched := intents.duplicate(true)
		_check(intents == expected[beat], label + ": beat %d exact intents" % beat)
		var result := phase.execute_phase(party, enemies, intents)
		_check(result == {"ok": true, "events": _expected_events(expected[beat])},
			label + ": beat %d exact ordered applied/target events" % beat)
		_check(intents == untouched and scheduler.get_intents() == expected[beat],
			label + ": beat %d phase does not mutate intents or auto-advance" % beat)
		var expected_party := initial_heroes.duplicate(true)
		for i in range(3):
			expected_party[i]["hp"] = hero_hp[beat][i]
		var expected_roster := initial_enemies.duplicate(true)
		for i in range(2):
			expected_roster[i]["block"] = enemy_blocks[beat][i]
		_check(party.get_heroes() == expected_party,
			label + ": beat %d full hero HP/Block and metadata state" % beat)
		_check(enemies.get_enemies() == expected_roster,
			label + ": beat %d full enemy HP/Block and metadata state" % beat)
		trace.append({"intents": intents, "result": result,
			"party": party.get_heroes(), "enemies": enemies.get_enemies()})
		_check(scheduler.advance_turn(), label + ": beat %d one owner advance" % beat)
	_check(scheduler.get_intents() == expected[0], label + ": after six phases wraps to zero")
	return trace


func _test_combat_and_replay() -> void:
	# The isolated fixture deliberately does not invoke Warden's opening passive.
	var first := _run_six("AC3 first")
	var replay := _run_six("AC3 replay")
	_check(first.size() == 6 and replay.size() == 6 and first == replay,
		"AC3: six complete per-beat effects replay from fresh real fixtures")
	if first.size() == 6:
		_check(first[5]["party"][0]["hp"] == 38
			and first[5]["party"][1]["hp"] == 27
			and first[5]["party"][2]["hp"] == 24
			and first[5]["enemies"][0]["block"] == 3
			and first[5]["enemies"][1]["block"] == 2,
			"AC3: final Warden/Seamstress/Tinker HP 38/27/24, enemy Block 3/2")
	seed(707)
	var oracle := randi()
	seed(707)
	_run_six("AC3 RNG unchanged")
	_check(randi() == oracle, "AC3: combat schedule/phase uses no global RNG draws")


func _test_dead_source_and_rejections() -> void:
	var party := _party()
	var enemies := _enemies()
	if not _fixture_ok(party, enemies, "AC4 slain"):
		return
	var scheduler := CombatEnemyIntents.new(_schedule(FEINT))
	_check(scheduler.is_valid(), "AC4: slain-source schedule precondition valid")
	_check(enemies.apply_damage(1, 12) and enemies.is_slain(1)
		and not enemies.is_slain(2), "AC4: first source really slain, second alive")
	var dead_roster := enemies.get_enemies()
	var intents := scheduler.get_intents()
	var result := CombatEnemyPhase.new().execute_phase(party, enemies, intents)
	_check(result == {"ok": true, "events": _expected_events(_expected_beats()[0], 1)},
		"AC4: slain source Block skipped; source 2 attack still applied")
	_check(party.get_hero(1)["hp"] == 39 and party.get_hero(2)["hp"] == 30
		and party.get_hero(3)["hp"] == 26
		and enemies.get_enemies() == dead_roster,
		"AC4: only Warden loses 1 HP, no slain-source Block gain")
	_check(scheduler.get_intents() == _expected_beats()[0],
		"AC4: slain source does not advance or mutate scheduler")

	var pristine := _read(FEINT)
	var valid := _schedule(FEINT)
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
	for i in range(broken.size()):
		_check(RunFightEncounterSelection._parse_schedule_text(broken[i]).is_empty(),
			"AC4: malformed local schedule %d rejected without partial data" % i)

	# Rejection by the real phase executor must not allow the first valid
	# action to land before a later invalid action is inspected.
	var clean_party := _party()
	var clean_enemies := _enemies()
	_check(_fixture_ok(clean_party, clean_enemies, "AC4 invalid phase"),
		"AC4: rejection uses valid service fixtures")
	var before_party := clean_party.get_heroes()
	var before_enemies := clean_enemies.get_enemies()
	var invalid_phase := [_block(1), {"type": "attack", "amount": 1,
		"enemy_position": 2, "target_position": 4}]
	var phase_copy := invalid_phase.duplicate(true)
	_check(CombatEnemyPhase.new().execute_phase(clean_party, clean_enemies, invalid_phase)
		== {"ok": false, "events": []}, "AC4: invalid later attack rejects entire phase")
	_check(clean_party.get_heroes() == before_party
		and clean_enemies.get_enemies() == before_enemies
		and invalid_phase == phase_copy, "AC4: invalid phase leaves all state and inputs intact")
	_check(_read(FEINT) == pristine and _schedule(FEINT) == valid,
		"AC4: malformed local copies do not affect valid authored data")


func _opening_fight(map: RunMap) -> String:
	for candidate in map.get_legal_choices():
		if map.get_node(candidate).get("type") == "Fight":
			return candidate
	return ""


func _test_single_pool_selection() -> void:
	const_seeded_selection(62019)


func const_seeded_selection(seed_value: int) -> void:
	var pool := {"spoolwheel_feint": FEINT}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var replay_rng := RandomNumberGenerator.new()
	replay_rng.seed = seed_value
	var oracle_rng := RandomNumberGenerator.new()
	oracle_rng.seed = seed_value
	var map := RunMap.new()
	var replay_map := RunMap.new()
	var oracle_map := RunMap.new()
	_check(map.generate(rng) and replay_map.generate(replay_rng)
		and oracle_map.generate(oracle_rng),
		"AC5: three independent seeded RunMap services generated")
	_check(map.get_floors() == replay_map.get_floors()
		and map.get_floors() == oracle_map.get_floors(),
		"AC5: identical seeded maps produced")
	var fight := _opening_fight(map)
	_check(not fight.is_empty() and map.get_legal_choices().has(fight),
		"AC5: single-pool test found an actual legal Fight")
	if fight.is_empty():
		return
	_check(map.choose_node(fight) and replay_map.choose_node(fight)
		and oracle_map.choose_node(fight),
		"AC5: all maps enter same chosen Fight")
	_check(map.get_current_node_id() == fight and map.get_node(fight)["type"] == "Fight"
		and map.get_route() == [fight], "AC5: selector input truly is chosen current Fight")
	var before_floors := map.get_floors()
	var before_route := map.get_route()
	var oracle_id := oracle_rng.randi_range(0, 0)
	var picker := RunFightEncounterSelection.new()
	var second := RunFightEncounterSelection.new()
	var answer := picker.select_current_fight(map, rng, pool)
	var replay := second.select_current_fight(replay_map, replay_rng, pool)
	_check(oracle_id == 0 and rng.state == oracle_rng.state,
		"AC5: single-entry selector consumes exactly one run RNG draw")
	_check(answer == {"success": true, "encounter_id": "spoolwheel_feint",
		"definitions": _expected_schedule()},
		"AC5: real selector returns exact new ID and full parsed actions")
	_check(replay == answer and replay_rng.state == rng.state,
		"AC5: independent same-seed map/selector replay selects same encounter")
	_check(CombatEnemyIntents.new(answer.get("definitions", [])).is_valid(),
		"AC5: selected full schedule is immediately usable by real intent service")
	var original := answer.duplicate(true)
	var after_pick := rng.state
	answer["definitions"][0]["pattern"][0]["amount"] = 909
	answer["definitions"].clear()
	var cached := picker.select_current_fight(map, rng, {})
	_check(cached == original and rng.state == after_pick,
		"AC5: selector caches choice without RNG, deep-isolated from caller edits")
	_check(map.get_floors() == before_floors and map.get_route() == before_route,
		"AC5: selection does not change graph or chosen route")
