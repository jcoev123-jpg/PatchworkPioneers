extends SceneTree

## These schedules deliberately remain test-local: no live M03 pool/app wiring.
const GUARD := "guardwheel_holdfast"
const FRAY := "frayhem_bleedtrap"
const ENCOUNTERS := "res://data/encounters/"
const RUN_ENEMIES := "res://data/enemies/run_enemies.json"
const STARTER_ENEMIES := "res://data/enemies/starter_enemies.json"
const HEROES := "res://data/heroes/starter_party.json"
const ROSTERS := {
	GUARD: ["button_guard", "seam_ripper"],
	FRAY: ["spool_stalker", "fray_scavenger", "ragling_guard"]
}
const ENEMY_STATS := {
	"button_guard": ["Button Guard", 16, "res://assets/paper/enemies/button_guard.png"],
	"seam_ripper": ["Seam Ripper", 18, "res://assets/paper/enemies/seam_ripper.png"],
	"spool_stalker": ["Spool Stalker", 14, "res://assets/paper/enemies/spool_stalker.png"],
	"fray_scavenger": ["Fray Scavenger", 14, "res://assets/paper/enemies/fray_scavenger.png"],
	"ragling_guard": ["Guard Ragling", 12, "res://assets/paper/enemies/ragling.png"]
}
const EXPECTED := {
	GUARD: [
		{"enemy_position": 1, "pattern": [
			{"type": "block", "amount": 4},
			{"type": "buff", "amount": 3},
			{"type": "attack", "amount": 3, "target_position": 3}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 3, "target_position": 2},
			{"type": "attack", "amount": 4, "target_position": 1},
			{"type": "block", "amount": 2}]}
	],
	FRAY: [
		{"enemy_position": 1, "pattern": [
			{"type": "debuff", "amount": 1, "target_position": 2, "status": "bleed"},
			{"type": "attack", "amount": 3, "target_position": 3},
			{"type": "block", "amount": 2}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 2, "target_position": 2},
			{"type": "debuff", "amount": 1, "target_position": 3, "status": "weak"},
			{"type": "attack", "amount": 2, "target_position": 1}]},
		{"enemy_position": 3, "pattern": [
			{"type": "block", "amount": 3},
			{"type": "attack", "amount": 2, "target_position": 1},
			{"type": "buff", "amount": 2}]}
	]
}
const SHIPPED := {
	"starter_attacks": [
		{"enemy_position": 1, "pattern": [
			{"type": "attack", "amount": 1, "target_position": 1},
			{"type": "attack", "amount": 1, "target_position": 2},
			{"type": "attack", "amount": 1, "target_position": 3}]},
		{"enemy_position": 2, "pattern": [{"type": "block", "amount": 1}]}
	],
	"buttonhole_holdout": [
		{"enemy_position": 1, "pattern": [
			{"type": "attack", "amount": 1, "target_position": 1},
			{"type": "block", "amount": 1},
			{"type": "block", "amount": 1},
			{"type": "attack", "amount": 1, "target_position": 3}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 1, "target_position": 2},
			{"type": "attack", "amount": 1, "target_position": 2},
			{"type": "attack", "amount": 1, "target_position": 1},
			{"type": "attack", "amount": 1, "target_position": 3}]}
	]
}

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_authored_schedules()
	_test_rejected_selection()
	for id in [GUARD, FRAY]:
		_test_selection_and_replay(id)
	_test_guard_phases()
	_test_fray_phases_and_owner_tick()
	_test_slain_and_atomic_failures()
	if failures.is_empty():
		print("m03_guardwheel_frayhem_encounters_test: PASS (", checks, " checks)")
	else:
		for message in failures:
			printerr(message)
		print("m03_guardwheel_frayhem_encounters_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


func _text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "file exists and opens: " + path)
	if file == null:
		return ""
	var result := file.get_as_text()
	file.close()
	return result


func _schedule(id: String) -> Array:
	return RunFightEncounterSelection._parse_schedule_text(_text(ENCOUNTERS + id + ".json"))


func _beat(id: String, turn: int) -> Array:
	var actions: Array = []
	for definition in EXPECTED[id]:
		var pattern: Array = definition["pattern"]
		var action: Dictionary = pattern[turn % pattern.size()].duplicate(true)
		action["enemy_position"] = definition["enemy_position"]
		actions.append(action)
	return actions


func _test_authored_schedules() -> void:
	for id in [GUARD, FRAY]:
		var raw = JSON.parse_string(_text(ENCOUNTERS + id + ".json"))
		var expected: Array = EXPECTED[id]
		_check(raw is Array and raw.size() == expected.size(),
			id + ": top-level array contains precisely its own sources")
		var parsed := _schedule(id)
		_check(parsed == expected, id + ": full ordered three-beat schedule matches brief")
		_check(parsed.size() == ROSTERS[id].size(), id + ": local roster has one entry per source")
		for source in range(1, expected.size() + 1):
			var found: Array = []
			for record in parsed:
				if record is Dictionary and record.get("enemy_position") == source:
					found.append(record)
			_check(found.size() == 1, id + ": exactly one source in slot " + str(source))
			if found.size() != 1:
				continue
			_check(found[0].size() == 2 and found[0]["pattern"] == expected[source - 1]["pattern"],
				id + ": source has no invented fields and complete intended pattern")
			_check(found[0]["enemy_position"] is int, id + ": parsed source slot is integer")
			for action in found[0]["pattern"]:
				_check(action["amount"] is int and (not action.has("target_position")
					or action["target_position"] is int),
					id + ": JSON numeric action fields normalized to legal integers")
		var scheduler := CombatEnemyIntents.new(parsed)
		_check(scheduler.is_valid(), id + ": CombatEnemyIntents accepts parsed schedule")
		if not scheduler.is_valid():
			continue
		var replay := CombatEnemyIntents.new(_schedule(id))
		for turn in range(7):
			_check(scheduler.get_intents() == _beat(id, turn)
				and replay.get_intents() == _beat(id, turn),
				id + ": ascending source intents and independent cycle replay beat " + str(turn + 1))
			_check(scheduler.advance_turn() and replay.advance_turn(),
				id + ": successful explicit advance " + str(turn + 1))
		var copy_a := scheduler.get_intents()
		var copy_b := scheduler.get_intents()
		copy_a[0]["amount"] = 987
		copy_a.append({"enemy_position": 99})
		_check(copy_b == _beat(id, 1) and scheduler.get_intents() == _beat(id, 1),
			id + ": detached intent snapshots cannot change internal scheduler")
		parsed[0]["pattern"][0]["amount"] = 988
		_check(scheduler.get_intents() == _beat(id, 1) and _schedule(id) == expected,
			id + ": detaching original schedule and disk source")
	for id in SHIPPED:
		var parsed := _schedule(id)
		_check(parsed == SHIPPED[id] and CombatEnemyIntents.new(parsed).is_valid(),
			id + ": independently preserved shipped ID and complete action contents")
	for malformed in [
		'[{"enemy_position":1,"pattern":[{"type":"attack","amount":1.5,"target_position":2}]}]',
		'[{"enemy_position":1,"pattern":[{"type":"debuff","amount":1,"target_position":1.5,"status":"weak"}]}]',
		'[{"enemy_position":1,"pattern":[{"type":"unknown","amount":2}]}]',
		'[{"enemy_position":1,"pattern":[{"type":"block","amount":2}],"id":"not allowed"}]',
		'{broken'
	]:
		_check(RunFightEncounterSelection._parse_schedule_text(malformed).is_empty(),
			"real parser fails closed on malformed numeric/action/shape JSON")


func _catalog_records() -> Dictionary:
	var by_id := {}
	for path in [RUN_ENEMIES, STARTER_ENEMIES]:
		var records := RunTypedBattleRoster._parse_catalog_text(_text(path))
		_check(not records.is_empty(), "real enemy catalog parses: " + path)
		for record in records:
			var id: String = record.get("id", "")
			_check(not by_id.has(id), "unique ID across original enemy catalogs: " + id)
			by_id[id] = record.duplicate(true)
	for id in ENEMY_STATS:
		_check(by_id.has(id), "catalog contains required ID: " + id)
		if by_id.has(id):
			var stats: Array = ENEMY_STATS[id]
			var record: Dictionary = by_id[id]
			_check(record.get("name") == stats[0] and record.get("max_hp") == stats[1]
				and record.get("art_path") == stats[2],
				"shipped enemy name, HP and original art path: " + id)
	return by_id


func _party() -> CombatParty:
	var raw = JSON.parse_string(_text(HEROES))
	_check(raw is Array, "starter heroes are an authored array")
	if not raw is Array:
		return CombatParty.new([])
	var definitions: Array = []
	var ordered_ids := ["warden", "seamstress", "tinker"]
	var hp := [40, 30, 26]
	for slot in range(3):
		var found: Array = []
		for record in raw:
			if record is Dictionary and record.get("id") == ordered_ids[slot]:
				found.append(record)
		_check(found.size() == 1, "unique real hero ID: " + ordered_ids[slot])
		if found.size() != 1:
			return CombatParty.new([])
		var record: Dictionary = found[0].duplicate(true)
		_check(record.get("max_hp") == hp[slot] and record.get("art_path") is String,
			"real hero HP/asset: " + ordered_ids[slot])
		_check(RunFightEncounterSelection._coerce_integral_field(record, "max_hp"),
			"hero max HP converts legally")
		definitions.append(record)
	var party := CombatParty.new(definitions)
	_check(party.is_valid(), "real CombatParty created from shipped heroes")
	if party.is_valid():
		var opening := CombatStartingBlock.new(party)
		_check(opening.apply() and not opening.apply(), "Warden opening Block is one-shot")
		_check(party.get_hero(1).get("hp") == 40 and party.get_hero(1).get("block") == 6
			and party.get_hero(2).get("hp") == 30 and party.get_hero(3).get("hp") == 26,
			"party begins with all three real heroes and only Warden's Block 6")
	return party


func _rng(value: int) -> RandomNumberGenerator:
	var result := RandomNumberGenerator.new()
	result.seed = value
	return result


func _fight(map: RunMap) -> String:
	for node_id in map.get_legal_choices():
		if map.get_node(node_id).get("type") == "Fight":
			return node_id
	return ""


func _snapshot(map: RunMap, rng: RandomNumberGenerator,
		selector: RunFightEncounterSelection) -> Dictionary:
	return {"graph": map.get_floors(), "route": map.get_route(),
		"rng": rng.state, "selected": selector._selected.duplicate(true),
		"bound": selector._bound_map}


func _fixture(id: String, seed_value: int = 28391) -> Dictionary:
	var rng := _rng(seed_value)
	var map := RunMap.new()
	_check(map.generate(rng), id + ": real map generated with seeded run RNG")
	var node := _fight(map)
	_check(not node.is_empty() and map.get_legal_choices().has(node),
		id + ": real legal opening Fight node found")
	if node.is_empty():
		return {}
	_check(map.choose_node(node) and map.get_current_node_id() == node
		and map.get_node(node).get("type") == "Fight",
		id + ": actual RunMap.choose_node chooses Fight")
	var selector := RunFightEncounterSelection.new()
	var pool := {"Fight": {id: ENCOUNTERS + id + ".json"}}
	var choice := selector.select_current_battle(map, rng, pool)
	_check(choice.get("success") == true and choice.get("encounter_id") == id
		and choice.get("node_type") == "Fight" and choice.get("definitions") == EXPECTED[id],
		id + ": one-entry Fight pool selects real JSON and exact encounter ID")
	if choice.get("success") != true:
		return {}
	var assembled := RunTypedBattleRoster.new().assemble(
		choice, {id: ROSTERS[id]}, [RUN_ENEMIES, STARTER_ENEMIES])
	_check(assembled.get("ok") == true and assembled.get("node_type") == "Fight"
		and assembled.get("encounter_id") == id and assembled.get("definitions") == EXPECTED[id],
		id + ": typed service assembles test-local roster from both real catalogs")
	if assembled.get("ok") != true:
		return {}
	var enemies: CombatEnemies = assembled["enemies"]
	_check(enemies.is_valid() and enemies.get_enemies().size() == ROSTERS[id].size(),
		id + ": assembled enemy sources are valid and precisely bound")
	var catalog := _catalog_records()
	for slot in ROSTERS[id].size():
		var enemy_id: String = ROSTERS[id][slot]
		var enemy := enemies.get_enemy(slot + 1)
		_check(catalog.has(enemy_id) and enemy.get("id") == enemy_id
			and enemy.get("position") == slot + 1
			and enemy.get("name") == ENEMY_STATS[enemy_id][0]
			and enemy.get("max_hp") == ENEMY_STATS[enemy_id][1]
			and enemy.get("hp") == ENEMY_STATS[enemy_id][1]
			and enemy.get("block") == 0
			and enemy.get("art_path") == catalog[enemy_id].get("art_path")
			and enemy.get("art_path") == ENEMY_STATS[enemy_id][2],
			id + ": real catalog identity, position, full HP and preserved asset " + enemy_id)
	var party := _party()
	var scheduler := CombatEnemyIntents.new(choice["definitions"])
	_check(party.is_valid() and scheduler.is_valid()
		and scheduler.get_intents() == _beat(id, 0),
		id + ": real party and announced first beat ready")
	if not party.is_valid() or not scheduler.is_valid():
		return {}
	return {"rng": rng, "map": map, "selector": selector,
		"choice": choice, "party": party, "enemies": enemies, "scheduler": scheduler}


func _test_rejected_selection() -> void:
	var rng := _rng(27182)
	var map := RunMap.new()
	var picker := RunFightEncounterSelection.new()
	var pool := {"Fight": {GUARD: ENCOUNTERS + GUARD + ".json"}}
	_check(map.generate(rng), "rejected-selection map generated")
	var before := _snapshot(map, rng, picker)
	_check(picker.select_current_battle(map, rng, pool) == {"success": false}
		and _snapshot(map, rng, picker) == before,
		"unchosen Fight rejects without route/cache/map binding/RNG mutation")
	var node := _fight(map)
	_check(not node.is_empty() and map.choose_node(node), "chosen Fight available for rejected retry")
	if node.is_empty():
		return
	for bad in [
		{"Fight": {}},
		{"Fight": {"missing": ENCOUNTERS + "no_such_encounter.json"}},
		{"Fight": {GUARD: ENCOUNTERS + GUARD + ".json", "bad": "invalid path"}},
		{"Fight": []}
	]:
		before = _snapshot(map, rng, picker)
		_check(picker.select_current_battle(map, rng, bad) == {"success": false}
			and _snapshot(map, rng, picker) == before,
			"invalid/missing selected Fight pool rejects atomically without RNG")
	var oracle_rng := _rng(27182)
	var oracle_map := RunMap.new()
	_check(oracle_map.generate(oracle_rng) and oracle_map.choose_node(node),
		"same-seed independent valid-selection RNG oracle")
	oracle_rng.randi_range(0, 0)
	var chosen := picker.select_current_battle(map, rng, pool)
	_check(chosen.get("encounter_id") == GUARD and rng.state == oracle_rng.state,
		"valid retry spends exactly the one allowed selection draw")
	# Search only real generated first-floor choices: never fabricate a node type.
	var nonfight_found := false
	for trial_seed in range(1, 65):
		var other_rng := _rng(trial_seed)
		var other_map := RunMap.new()
		if not other_map.generate(other_rng):
			continue
		for option in other_map.get_legal_choices():
			if other_map.get_node(option).get("type") != "Fight":
				var other_picker := RunFightEncounterSelection.new()
				var other_before := _snapshot(other_map, other_rng, other_picker)
				if other_map.choose_node(option):
					var post_choice := _snapshot(other_map, other_rng, other_picker)
					_check(other_picker.select_current_battle(other_map, other_rng, pool)
						== {"success": false}
						and other_picker.select_current_fight(other_map, other_rng,
						pool["Fight"]) == {"success": false}
						and _snapshot(other_map, other_rng, other_picker) == post_choice,
						"legally selected non-Fight rejects both APIs without any spend")
					_check(other_before["rng"] == other_rng.state,
						"non-Fight map traversal does not consume RNG")
					nonfight_found = true
				break
		if nonfight_found:
			break
	_check(nonfight_found, "seeded real map supplies a non-Fight negative fixture")


func _test_selection_and_replay(id: String) -> void:
	var a := _fixture(id, 33843)
	var b := _fixture(id, 33843)
	_check(not a.is_empty() and not b.is_empty(), id + ": two complete independent seeded fixtures")
	if a.is_empty() or b.is_empty():
		return
	_check(a["map"].get_floors() == b["map"].get_floors()
		and a["map"].get_route() == b["map"].get_route()
		and a["choice"] == b["choice"] and a["rng"].state == b["rng"].state
		and a["enemies"].get_enemies() == b["enemies"].get_enemies(),
		id + ": seeded map, roster, schedule, RNG replay identical")
	var oracle_rng := _rng(33843)
	var oracle_map := RunMap.new()
	_check(oracle_map.generate(oracle_rng)
		and oracle_map.choose_node(a["map"].get_current_node_id()),
		id + ": independent oracle follows legal chosen map node")
	oracle_rng.randi_range(0, 0)
	_check(a["rng"].state == oracle_rng.state,
		id + ": one sorted index RNG draw after generated map")
	var before: int = a["rng"].state
	var picker: RunFightEncounterSelection = a["selector"]
	var map: RunMap = a["map"]
	var cached := picker.select_current_battle(map, a["rng"], {"Fight": {}})
	_check(cached == a["choice"] and a["rng"].state == before,
		id + ": repeat same-node selection uses cache without RNG")
	cached["definitions"][0]["pattern"][0]["amount"] = 900
	cached["encounter_id"] = "corrupted"
	_check(picker.select_current_battle(map, a["rng"], {"Fight": {}})
		== a["choice"] and a["rng"].state == before,
		id + ": selector returns detached choices that cannot corrupt cache")
	for f in [a, b]:
		var party: CombatParty = f["party"]
		var foes: CombatEnemies = f["enemies"]
		var phase := CombatEnemyPhase.new().execute_phase(
			party, foes, f["scheduler"].get_intents())
		_check(phase.get("ok") == true and phase.get("events", []).size() == ROSTERS[id].size(),
			id + ": initial deterministic replay executes full real enemy phase")
	_check(a["party"].get_heroes() == b["party"].get_heroes()
		and a["enemies"].get_enemies() == b["enemies"].get_enemies()
		and a["rng"].state == b["rng"].state,
		id + ": equal seed reproduces entire first phase party/enemy/RNG snapshot")


func _hero(party: CombatParty, slot: int, id: String,
		hp: int, block: int, statuses: Dictionary, label: String) -> void:
	var hero := party.get_hero(slot)
	_check(hero.get("id") == id and hero.get("position") == slot
		and hero.get("hp") == hp and hero.get("block") == block
		and hero.get("statuses", {}) == statuses,
		label + ": expected " + str([id, hp, block, statuses]) + " at " + str(slot)
		+ " got " + str(hero))


func _apply(f: Dictionary, id: String, turn: int) -> Dictionary:
	var intents: Array = f["scheduler"].get_intents()
	_check(intents == _beat(id, turn), id + ": full announced source-ordered beat " + str(turn + 1))
	var before_rng: int = f["rng"].state
	var result := CombatEnemyPhase.new().execute_phase(f["party"], f["enemies"], intents)
	var events: Array = []
	for action in _beat(id, turn):
		var event := {"type": action["type"], "enemy_position": action["enemy_position"],
			"applied": true}
		for field in ["target_position", "status", "direction"]:
			if action.has(field):
				event[field] = action[field]
		events.append(event)
	_check(result == {"ok": true, "events": events},
		id + ": complete real phase event list matches announced actions in source order")
	_check(f["rng"].state == before_rng and f["scheduler"].get_intents() == intents,
		id + ": phase does not draw run RNG or implicitly advance scheduler")
	_check(f["scheduler"].advance_turn(), id + ": caller advances scheduler after valid phase")
	return result


func _test_guard_phases() -> void:
	var f := _fixture(GUARD)
	if f.is_empty():
		return
	var party: CombatParty = f["party"]
	var enemies: CombatEnemies = f["enemies"]
	_apply(f, GUARD, 0)
	_hero(party, 1, "warden", 40, 6, {}, "Guardwheel first phase")
	_hero(party, 2, "seamstress", 27, 0, {}, "Guardwheel first phase")
	_hero(party, 3, "tinker", 26, 0, {}, "Guardwheel first phase")
	_check(enemies.get_enemy(1).get("block") == 4 and enemies.get_enemy(2).get("block") == 0,
		"Guardwheel first phase grants exactly 4 self-Block to Button Guard")
	_check(party.start_player_turn(), "real player-turn boundary resets opening Block")
	_hero(party, 1, "warden", 40, 0, {}, "Guardwheel after opening Block expiry")
	_apply(f, GUARD, 1)
	_hero(party, 1, "warden", 36, 0, {}, "Guardwheel second beat targets front after reset")
	_hero(party, 2, "seamstress", 27, 0, {}, "Guardwheel second beat")
	_check(enemies.get_enemy(1).get("block") == 7,
		"Guardwheel buff grants +3 self-Block, not attack damage")
	_apply(f, GUARD, 2)
	_hero(party, 3, "tinker", 23, 0, {}, "Guardwheel third beat hits back")
	_check(enemies.get_enemy(2).get("block") == 2,
		"Guardwheel third beat gives Seam Ripper 2 self-Block")
	_check(f["scheduler"].get_intents() == _beat(GUARD, 3),
		"Guardwheel wraps to first actions on fourth beat")
	_apply(f, GUARD, 3)
	_hero(party, 2, "seamstress", 24, 0, {}, "Guardwheel wrapped attack targets middle")
	_check(enemies.get_enemy(1).get("block") == 11,
		"Guardwheel replays first-beat Block without changing damage")


func _test_fray_phases_and_owner_tick() -> void:
	var f := _fixture(FRAY)
	if f.is_empty():
		return
	var party: CombatParty = f["party"]
	var enemies: CombatEnemies = f["enemies"]
	_apply(f, FRAY, 0)
	_hero(party, 1, "warden", 40, 6, {}, "Frayhem initial enemy phase")
	_hero(party, 2, "seamstress", 28, 0, {"bleed": 1}, "Frayhem initial enemy phase")
	_hero(party, 3, "tinker", 26, 0, {}, "Frayhem initial enemy phase")
	_check(enemies.get_enemy(3).get("block") == 3
		and enemies.get_enemy(1).get("block") == 0
		and enemies.get_enemy(2).get("block") == 0,
		"Frayhem first phase gives 3 Block only to Guard Ragling")
	_check(party.gain_block(2, 5), "Seamstress has real positive Block before owner tick")
	var before := party.get_heroes()
	var tick := CombatStatusTurnBatch.new().tick_side("heroes", before)
	_check(tick.get("ok") == true and tick.get("actors", []).size() == 3
		and tick.get("events", []).size() == 3, "real hero-owner status batch ticks all three")
	if tick.get("ok") == true:
		var next: Dictionary = tick["actors"][1]
		_check(next.get("hp") == 27 and next.get("block") == 5
			and next.get("statuses", {}) == {}
			and tick["events"][1].get("bleed_hp_loss") == 1,
			"Bleed 1 deals 1 direct HP bypassing 5 Block and expires on owner tick")
		_check(tick["actors"][0].get("hp") == 40
			and tick["actors"][2].get("hp") == 26,
			"only Seamstress loses HP during her owner's Bleed tick")
	_hero(party, 2, "seamstress", 28, 5, {"bleed": 1},
		"detached owner tick never silently mutates authoritative CombatParty")
	_check(party.start_player_turn(), "player-turn Block resets independently of detached tick")
	_hero(party, 2, "seamstress", 28, 0, {"bleed": 1},
		"turn opening only resets Block, never duplicates a Bleed tick")
	var beat2 := _fixture(FRAY)
	if beat2.is_empty():
		return
	_check(beat2["scheduler"].advance_turn(), "fresh Frayhem scheduler advances to beat two")
	_check(beat2["party"].start_player_turn(), "fresh Frayhem player Block reset before second phase")
	_apply(beat2, FRAY, 1)
	_hero(beat2["party"], 1, "warden", 38, 0, {}, "Frayhem beat two front hit")
	_hero(beat2["party"], 2, "seamstress", 30, 0, {}, "Frayhem beat two middle untouched")
	_hero(beat2["party"], 3, "tinker", 23, 0, {"weak": 1}, "Frayhem beat two rear damage and Weak")
	var beat3 := _fixture(FRAY)
	if beat3.is_empty():
		return
	_check(beat3["scheduler"].advance_turn() and beat3["scheduler"].advance_turn(),
		"fresh Frayhem scheduler advances to third beat")
	_apply(beat3, FRAY, 2)
	_hero(beat3["party"], 1, "warden", 40, 4, {}, "Frayhem third beat front damage blocked")
	_check(beat3["enemies"].get_enemy(1).get("block") == 2
		and beat3["enemies"].get_enemy(3).get("block") == 2,
		"Frayhem third beat applies self-Block 2 and self-buff 2")
	_check(beat3["scheduler"].get_intents() == _beat(FRAY, 3),
		"Frayhem third beat advances to wrapped first intents")


func _reject_phase(f: Dictionary, actions: Array, label: String) -> void:
	var before_heroes: Array = f["party"].get_heroes()
	var before_enemies: Array = f["enemies"].get_enemies()
	var before_intents: Array = f["scheduler"].get_intents()
	var before_index: int = f["scheduler"]._turn_index
	var before_rng: int = f["rng"].state
	var before_actions := actions.duplicate(true)
	seed(787711)
	var expected_global := randi()
	seed(787711)
	_check(CombatEnemyPhase.new().execute_phase(f["party"], f["enemies"], actions)
		== {"ok": false, "events": []}, label + ": whole invalid phase rejected with zero events")
	_check(f["party"].get_heroes() == before_heroes
		and f["enemies"].get_enemies() == before_enemies,
		label + ": every authoritative HP/Block/status/slot unchanged on rejection")
	_check(f["scheduler"].get_intents() == before_intents
		and f["scheduler"]._turn_index == before_index
		and actions == before_actions,
		label + ": scheduler and caller-owned intents unchanged on rejection")
	_check(f["rng"].state == before_rng and randi() == expected_global,
		label + ": neither run RNG nor global RNG spent")


func _test_slain_and_atomic_failures() -> void:
	var slain := _fixture(FRAY)
	if not slain.is_empty():
		var foes: CombatEnemies = slain["enemies"]
		_check(foes.apply_damage(2, 14) and foes.is_slain(2)
			and foes.get_enemy(2).get("position") == 2,
			"slain Fray Scavenger stays in source slot two")
		var before_rng: int = slain["rng"].state
		var action := CombatEnemyPhase.new().execute_phase(slain["party"], foes,
			slain["scheduler"].get_intents())
		_check(action.get("ok") == true and action.get("events", []).size() == 3
			and action["events"][1].get("applied") == false,
			"slain source is announced but cannot attack on first beat")
		_hero(slain["party"], 2, "seamstress", 30, 0, {"bleed": 1},
			"slain middle source deals no extra two HP damage")
		_check(foes.get_enemy(2).get("hp") == 0
			and foes.get_enemy(3).get("block") == 3 and slain["rng"].state == before_rng,
			"other living sources still act; slain source keeps original slot and RNG")
	var invalid := _fixture(FRAY)
	if invalid.is_empty():
		return
	_check(invalid["party"].apply_damage(3, 26) and invalid["party"].is_downed(3),
		"invalid late target fixture has actually downed Tinker")
	var invalid_actions: Array = invalid["scheduler"].get_intents()
	# Source 1's legitimate Bleed would stage a status before source 2's
	# valid-shaped debuff discovers downed Tinker. Neither may commit.
	invalid_actions[1] = {"enemy_position": 2, "type": "debuff",
		"amount": 1, "target_position": 3, "status": "weak"}
	_check(invalid_actions[0]["type"] == "debuff"
		and invalid_actions[1]["type"] == "debuff",
		"first actor can stage legitimate status before illegal later target")
	_reject_phase(invalid, invalid_actions, "late target invalid after staged first Bleed")
	_check(invalid["party"].get_hero(2).get("statuses", {}) == {},
		"staged early Bleed rolls back when later target is downed")
	var retry := CombatEnemyPhase.new().execute_phase(invalid["party"],
		invalid["enemies"], invalid["scheduler"].get_intents())
	_check(retry.get("ok") == true and retry.get("events", []).size() == 3,
		"valid original first beat succeeds after atomic rejection")
	_hero(invalid["party"], 2, "seamstress", 28, 0, {"bleed": 1},
		"valid retry commits one Bleed and correct middle damage")
	var malformed := _fixture(GUARD)
	if malformed.is_empty():
		return
	var wrong: Array = malformed["scheduler"].get_intents()
	wrong[1]["type"] = "not_an_action"
	_check(wrong[0]["type"] == "block" and wrong[0]["amount"] == 4,
		"positive first Block exists before invalid late malformed action")
	_reject_phase(malformed, wrong, "malformed later intent after valid first Block")
	_check(malformed["enemies"].get_enemy(1).get("block") == 0,
		"no partial Guard Block published from rejected malformed batch")
	_check(CombatEnemyPhase.new().execute_phase(malformed["party"],
		malformed["enemies"], malformed["scheduler"].get_intents()).get("ok") == true
		and malformed["enemies"].get_enemy(1).get("block") == 4,
		"valid original Guardwheel phase succeeds after malformed action rejection")
