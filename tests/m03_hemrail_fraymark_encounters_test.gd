extends SceneTree
## Test-local encounters; publication to the live M03 pool is intentionally deferred.
const H := "hemrail_exchange"
const F := "fraymark_focus"
const BASE := "res://data/encounters/"
const RUN_ENEMIES := "res://data/enemies/run_enemies.json"
const STARTER_ENEMIES := "res://data/enemies/starter_enemies.json"
const HEROES := "res://data/heroes/starter_party.json"
const ROSTERS := {
	H: ["button_guard", "spool_stalker"],
	F: ["fray_scavenger", "seam_ripper", "ragling_guard"]
}
const STATS := {
	"button_guard": ["Button Guard", 16, "res://assets/paper/enemies/button_guard.png"],
	"spool_stalker": ["Spool Stalker", 14, "res://assets/paper/enemies/spool_stalker.png"],
	"fray_scavenger": ["Fray Scavenger", 14, "res://assets/paper/enemies/fray_scavenger.png"],
	"seam_ripper": ["Seam Ripper", 18, "res://assets/paper/enemies/seam_ripper.png"],
	"ragling_guard": ["Guard Ragling", 12, "res://assets/paper/enemies/ragling.png"]
}
const EXPECTED := {
	H: [
		{"enemy_position": 1, "pattern": [
			{"type": "shove", "amount": 0, "target_position": 1, "direction": 1},
			{"type": "block", "amount": 3},
			{"type": "attack", "amount": 2, "target_position": 3},
			{"type": "attack", "amount": 3, "target_position": 1}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 3, "target_position": 2},
			{"type": "debuff", "amount": 1, "target_position": 3, "status": "weak"},
			{"type": "block", "amount": 2},
			{"type": "attack", "amount": 2, "target_position": 2}]}
	],
	F: [
		{"enemy_position": 1, "pattern": [
			{"type": "debuff", "amount": 1, "target_position": 2, "status": "exposed"},
			{"type": "attack", "amount": 2, "target_position": 1},
			{"type": "block", "amount": 2},
			{"type": "attack", "amount": 2, "target_position": 3}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 4, "target_position": 2},
			{"type": "block", "amount": 3},
			{"type": "attack", "amount": 2, "target_position": 2},
			{"type": "buff", "amount": 2}]},
		{"enemy_position": 3, "pattern": [
			{"type": "block", "amount": 2},
			{"type": "attack", "amount": 2, "target_position": 3},
			{"type": "attack", "amount": 3, "target_position": 1},
			{"type": "block", "amount": 1}]}
	]
}
const OLD := {
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
	_test_authored()
	_test_prechoice_and_malformed()
	for id in [H, F]:
		_test_run_replay(id)
		_test_phases(id)
	_test_slain_and_atomic_failure()
	if failures.is_empty():
		print("m03_hemrail_fraymark_encounters_test: PASS (", checks, " checks)")
	else:
		for error in failures:
			printerr(error)
		print("m03_hemrail_fraymark_encounters_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


func _text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "resource must open: " + path)
	if file == null:
		return ""
	var content := file.get_as_text()
	file.close()
	return content


func _schedule(id: String) -> Array:
	return RunFightEncounterSelection._parse_schedule_text(_text(BASE + id + ".json"))


func _expected_beat(id: String, index: int) -> Array:
	var actions: Array = []
	for source in EXPECTED[id]:
		var pattern: Array = source["pattern"]
		var action: Dictionary = pattern[index % pattern.size()].duplicate(true)
		action["enemy_position"] = source["enemy_position"]
		actions.append(action)
	return actions


func _events(id: String, index: int, slain_slot: int = 0) -> Array:
	var result: Array = []
	for action in _expected_beat(id, index):
		var event := {"type": action["type"], "enemy_position": action["enemy_position"],
			"applied": action["enemy_position"] != slain_slot}
		for field in ["target_position", "direction", "status"]:
			if action.has(field):
				event[field] = action[field]
		result.append(event)
	return result


func _test_authored() -> void:
	for id in [H, F]:
		var raw = JSON.parse_string(_text(BASE + id + ".json"))
		var expected: Array = EXPECTED[id]
		_check(raw is Array and raw.size() == expected.size(),
			id + ": only expected local sources")
		var parsed := _schedule(id)
		_check(parsed == expected, id + ": exact action dictionaries and four beats")
		_check(parsed.size() == ROSTERS[id].size(),
			id + ": occupied source slots match test-local roster")
		for slot in range(1, expected.size() + 1):
			var matching: Array = []
			for source in parsed:
				if source is Dictionary and source.get("enemy_position") == slot:
					matching.append(source)
			_check(matching.size() == 1, id + ": unique authored source " + str(slot))
			if matching.size() != 1:
				continue
			_check(matching[0].size() == 2 and matching[0]["pattern"].size() == 4
				and matching[0]["pattern"] == expected[slot - 1]["pattern"]
				and matching[0]["enemy_position"] is int,
				id + ": exact 4-action source " + str(slot))
			for action in matching[0]["pattern"]:
				_check(action["amount"] is int and (not action.has("target_position")
					or action["target_position"] is int)
					and (not action.has("direction") or action["direction"] is int),
					id + ": integral normalized action fields")
		var scheduler := CombatEnemyIntents.new(parsed)
		var replay := CombatEnemyIntents.new(_schedule(id))
		_check(scheduler.is_valid() and replay.is_valid(), id + ": genuine schedulers valid")
		if not scheduler.is_valid() or not replay.is_valid():
			continue
		for beat in range(9):
			_check(scheduler.get_intents() == _expected_beat(id, beat)
				and replay.get_intents() == _expected_beat(id, beat),
				id + ": five-plus ordered announced beats wrap and replay " + str(beat))
			_check(scheduler.advance_turn() and replay.advance_turn(),
				id + ": explicit advance " + str(beat))
		var detached := scheduler.get_intents()
		detached[0]["amount"] = 909
		detached.append({"enemy_position": 99})
		parsed[0]["pattern"][0]["amount"] = 800
		_check(scheduler.get_intents() == _expected_beat(id, 9)
			and replay.get_intents() == _expected_beat(id, 9)
			and _schedule(id) == expected,
			id + ": detached intent snapshots and original data cannot mutate scheduler")
	for id in OLD:
		var previous := _schedule(id)
		_check(previous == OLD[id] and CombatEnemyIntents.new(previous).is_valid(),
			id + ": named shipped schedule remains parseable with complete original beats")


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _fight(map: RunMap) -> String:
	for node in map.get_legal_choices():
		if map.get_node(node).get("type") == "Fight":
			return node
	return ""


func _map_snapshot(map: RunMap, rng: RandomNumberGenerator,
		selector: RunFightEncounterSelection) -> Dictionary:
	return {"floors": map.get_floors(), "route": map.get_route(),
		"rng": rng.state, "cache": selector._selected.duplicate(true),
		"bound": selector._bound_map}


func _catalog() -> Dictionary:
	var catalog: Dictionary = {}
	for path in [RUN_ENEMIES, STARTER_ENEMIES]:
		var entries := RunTypedBattleRoster._parse_catalog_text(_text(path))
		_check(not entries.is_empty(), "original catalog parses " + path)
		for entry in entries:
			var id: String = entry.get("id", "")
			_check(not catalog.has(id), "unique shipped enemy ID " + id)
			catalog[id] = entry.duplicate(true)
	for id in STATS:
		_check(catalog.has(id), "required catalog ID is present: " + id)
		if catalog.has(id):
			_check(catalog[id].get("name") == STATS[id][0]
				and catalog[id].get("max_hp") == STATS[id][1]
				and catalog[id].get("art_path") == STATS[id][2],
				"unchanged shipped enemy identity/stat/art " + id)
	return catalog


func _party() -> CombatParty:
	var raw = JSON.parse_string(_text(HEROES))
	_check(raw is Array, "starter party is a real JSON array")
	if not raw is Array:
		return CombatParty.new([])
	var definitions: Array = []
	for expected in [["warden", 40], ["seamstress", 30], ["tinker", 26]]:
		var matches: Array = []
		for source in raw:
			if source is Dictionary and source.get("id") == expected[0]:
				matches.append(source)
		_check(matches.size() == 1, "exactly one shipped hero " + expected[0])
		if matches.size() != 1:
			return CombatParty.new([])
		var record: Dictionary = matches[0].duplicate(true)
		_check(RunFightEncounterSelection._coerce_integral_field(record, "max_hp")
			and record["max_hp"] == expected[1] and record.get("art_path") is String,
			"normalized real hero HP and art " + expected[0])
		definitions.append(record)
	var party := CombatParty.new(definitions)
	_check(party.is_valid(), "real three-hero party valid")
	if party.is_valid():
		var opening := CombatStartingBlock.new(party)
		_check(opening.apply() and not opening.apply(), "combat-start Warden Block granted once")
		_check(party.get_hero(1).get("block") == 6
			and party.get_hero(2).get("block") == 0
			and party.get_hero(3).get("block") == 0,
			"only Warden has six opening Block")
	return party


func _fixture(id: String, seed_value: int = 38179) -> Dictionary:
	var rng := _rng(seed_value)
	var map := RunMap.new()
	_check(map.generate(rng), id + ": real seeded map generated")
	var node := _fight(map)
	_check(not node.is_empty() and map.get_legal_choices().has(node),
		id + ": legal generated Fight offered")
	if node.is_empty():
		return {}
	_check(map.choose_node(node) and map.get_current_node_id() == node,
		id + ": real route chooses offered Fight")
	var selector := RunFightEncounterSelection.new()
	var pool := {"Fight": {id: BASE + id + ".json"}}
	var choice := selector.select_current_battle(map, rng, pool)
	_check(choice.get("success") == true and choice.get("node_type") == "Fight"
		and choice.get("encounter_id") == id and choice.get("definitions") == EXPECTED[id],
		id + ": true single-ID seeded Fight selection")
	if choice.get("success") != true:
		return {}
	var assembled := RunTypedBattleRoster.new().assemble(
		choice, {id: ROSTERS[id]}, [RUN_ENEMIES, STARTER_ENEMIES])
	_check(assembled.get("ok") == true and assembled.get("definitions") == EXPECTED[id],
		id + ": typed assembly succeeds from both real catalogs")
	if assembled.get("ok") != true:
		return {}
	var foes: CombatEnemies = assembled["enemies"]
	var catalog := _catalog()
	_check(foes.is_valid() and foes.get_enemies().size() == ROSTERS[id].size(),
		id + ": valid full roster with required number of occupied sources")
	for index in range(ROSTERS[id].size()):
		var enemy_id: String = ROSTERS[id][index]
		var enemy := foes.get_enemy(index + 1)
		_check(catalog.has(enemy_id) and enemy.get("id") == enemy_id
			and enemy.get("position") == index + 1 and enemy.get("hp") == STATS[enemy_id][1]
			and enemy.get("max_hp") == STATS[enemy_id][1] and enemy.get("block") == 0
			and enemy.get("name") == STATS[enemy_id][0]
			and enemy.get("art_path") == STATS[enemy_id][2],
			id + ": named source occupies original enemy slot " + str(index + 1))
	var party := _party()
	var intents := CombatEnemyIntents.new(choice["definitions"])
	_check(party.is_valid() and intents.is_valid()
		and intents.get_intents() == _expected_beat(id, 0),
		id + ": true actors and first announced intents ready")
	if not party.is_valid() or not intents.is_valid():
		return {}
	return {"rng": rng, "map": map, "selector": selector, "choice": choice,
		"party": party, "enemies": foes, "intents": intents}


func _test_prechoice_and_malformed() -> void:
	for bad in [
		'{',
		'[{"enemy_position":1,"pattern":[{"type":"attack","amount":2.5,"target_position":1}]}]',
		'[{"enemy_position":1,"pattern":[{"type":"attack","amount":2,"target_position":3.5}]}]',
		'[{"enemy_position":1,"pattern":[{"type":"debuff","amount":1,"status":"weak","target_position":4}]}]',
		'[{"enemy_position":1,"pattern":[{"type":"shove","amount":0,"target_position":1,"direction":-1}]}]',
		'[{"enemy_position":1,"pattern":[{"type":"shove","amount":0,"target_position":2,"direction":0}]}]',
		'[{"enemy_position":1,"pattern":[{"type":"block","amount":1}],"extra":true}]'
	]:
		_check(RunFightEncounterSelection._parse_schedule_text(bad).is_empty(),
			"invalid schedule/action/target/shove rejected without normalization loopholes: " + bad)
	var rng := _rng(38179)
	var map := RunMap.new()
	var selector := RunFightEncounterSelection.new()
	_check(map.generate(rng), "prechoice map generated")
	var before := _map_snapshot(map, rng, selector)
	_check(selector.select_current_battle(map, rng, {"Fight": {H: BASE + H + ".json"}})
		== {"success": false} and _map_snapshot(map, rng, selector) == before,
		"pre-choice selection rejects without route/cache/RNG mutation")
	var node := _fight(map)
	_check(not node.is_empty() and map.choose_node(node), "invalid-pool node legally chosen")
	if node.is_empty():
		return
	for pool in [
		{"Fight": {}},
		{"Fight": {"missing": BASE + "not_on_disk.json"}},
		{"Fight": {H: BASE + H + ".json", "bad": "not-a-resource"}},
		{"Fight": []}
	]:
		before = _map_snapshot(map, rng, selector)
		_check(selector.select_current_battle(map, rng, pool) == {"success": false}
			and _map_snapshot(map, rng, selector) == before,
			"invalid local pool is rejected before RNG/cache changes")


func _test_run_replay(id: String) -> void:
	var a := _fixture(id)
	var b := _fixture(id)
	_check(not a.is_empty() and not b.is_empty(), id + ": independent complete fixtures")
	if a.is_empty() or b.is_empty():
		return
	_check(a["map"].get_floors() == b["map"].get_floors()
		and a["map"].get_route() == b["map"].get_route()
		and a["choice"] == b["choice"] and a["rng"].state == b["rng"].state
		and a["enemies"].get_enemies() == b["enemies"].get_enemies(),
		id + ": equal-seed map/typed roster/choice/RNG replay")
	var oracle_rng := _rng(38179)
	var oracle_map := RunMap.new()
	_check(oracle_map.generate(oracle_rng)
		and oracle_map.choose_node(a["map"].get_current_node_id()),
		id + ": replay RNG oracle follows identical legal node")
	oracle_rng.randi_range(0, 0)
	_check(a["rng"].state == oracle_rng.state,
		id + ": selection consumed exactly one local RNG draw")
	var before: int = a["rng"].state
	var picker: RunFightEncounterSelection = a["selector"]
	var cached := picker.select_current_battle(a["map"], a["rng"], {"Fight": {}})
	_check(cached == a["choice"] and a["rng"].state == before,
		id + ": selected node cache does not inspect pool or consume RNG")
	cached["definitions"][0]["pattern"][0]["amount"] = 921
	cached["encounter_id"] = "mutated"
	_check(picker.select_current_battle(a["map"], a["rng"], {"Fight": {}})
		== a["choice"] and a["rng"].state == before,
		id + ": cached definitions are detached from caller edits")
	for beat in range(5):
		var ap: Dictionary = _apply(a, id, beat)
		var bp: Dictionary = _apply(b, id, beat)
		_check(ap == bp and a["party"].get_heroes() == b["party"].get_heroes()
			and a["enemies"].get_enemies() == b["enemies"].get_enemies()
			and a["rng"].state == b["rng"].state,
			id + ": full same-seed phase/RNG snapshot replay beat " + str(beat + 1))


func _apply(f: Dictionary, id: String, beat: int) -> Dictionary:
	var announced: Array = f["intents"].get_intents()
	_check(announced == _expected_beat(id, beat),
		id + ": announced exact actions before phase beat " + str(beat + 1))
	var before_rng: int = f["rng"].state
	var result := CombatEnemyPhase.new().execute_phase(f["party"], f["enemies"], announced)
	_check(result == {"ok": true, "events": _events(id, beat)},
		id + ": actual source-ordered complete phase events beat " + str(beat + 1)
		+ " got " + str(result))
	_check(f["rng"].state == before_rng and f["intents"].get_intents() == announced,
		id + ": no hidden RNG spend or implicit scheduler advance")
	_check(f["intents"].advance_turn(), id + ": explicit scheduler advance")
	return result


func _assert_formation(f: Dictionary, expected_heroes: Array,
		expected_blocks: Array, label: String) -> void:
	var party: CombatParty = f["party"]
	var foes: CombatEnemies = f["enemies"]
	for i in range(expected_heroes.size()):
		var hero := party.get_hero(i + 1)
		var goal: Array = expected_heroes[i]
		_check(hero.get("id") == goal[0] and hero.get("position") == i + 1
			and hero.get("hp") == goal[1] and hero.get("block") == goal[2]
			and hero.get("statuses", {}) == goal[3], label + ": exact hero slot "
			+ str(i + 1) + ": " + str(hero))
	for i in range(expected_blocks.size()):
		var foe := foes.get_enemy(i + 1)
		_check(foe.get("id") == ROSTERS[label.split(" ")[0]][i]
			and foe.get("position") == i + 1 and foe.get("hp") == STATS[foe["id"]][1]
			and foe.get("block") == expected_blocks[i],
			label + ": original enemy source slot and Block " + str(i + 1))


func _test_phases(id: String) -> void:
	var goal_heroes: Array = []
	var goal_blocks: Array = []
	if id == H:
		goal_heroes = [
			[["seamstress", 30, 0, {}], ["warden", 40, 3, {}], ["tinker", 26, 0, {}]],
			[["warden", 40, 6, {}], ["seamstress", 30, 0, {}], ["tinker", 26, 0, {"weak": 1}]],
			[["warden", 40, 6, {}], ["seamstress", 30, 0, {}], ["tinker", 24, 0, {}]],
			[["warden", 40, 3, {}], ["seamstress", 28, 0, {}], ["tinker", 26, 0, {}]]
		]
		goal_blocks = [[0, 0], [3, 0], [0, 2], [0, 0]]
	else:
		goal_heroes = [
			[["warden", 40, 6, {}], ["seamstress", 24, 0, {"exposed": 1}], ["tinker", 26, 0, {}]],
			[["warden", 40, 4, {}], ["seamstress", 30, 0, {}], ["tinker", 24, 0, {}]],
			[["warden", 40, 3, {}], ["seamstress", 28, 0, {}], ["tinker", 26, 0, {}]],
			[["warden", 40, 6, {}], ["seamstress", 30, 0, {}], ["tinker", 24, 0, {}]]
		]
		goal_blocks = [[0, 0, 2], [0, 3, 0], [2, 0, 0], [0, 2, 1]]
	for beat in range(4):
		var f := _fixture(id)
		_check(not f.is_empty(), id + ": independent fresh combat fixture beat " + str(beat + 1))
		if f.is_empty():
			continue
		for ignored in range(beat):
			_check(f["intents"].advance_turn(), id + ": skip to isolated beat " + str(beat + 1))
		_apply(f, id, beat)
		_assert_formation(f, goal_heroes[beat], goal_blocks[beat],
			id + " isolated beat " + str(beat + 1))
		if beat == 3:
			_check(f["intents"].get_intents() == _expected_beat(id, 0),
				id + ": fifth announcement wraps to first after fourth")


func _reject(f: Dictionary, actions: Array, label: String) -> void:
	var heroes: Array = f["party"].get_heroes()
	var enemies: Array = f["enemies"].get_enemies()
	var announced: Array = f["intents"].get_intents()
	var scheduler_index: int = f["intents"]._turn_index
	var rng_state: int = f["rng"].state
	var map_route: Array = f["map"].get_route()
	var original: Array = actions.duplicate(true)
	seed(334407)
	var oracle: int = randi()
	seed(334407)
	_check(CombatEnemyPhase.new().execute_phase(f["party"], f["enemies"], actions)
		== {"ok": false, "events": []}, label + ": atomic invalid phase rejected")
	_check(f["party"].get_heroes() == heroes and f["enemies"].get_enemies() == enemies,
		label + ": full authoritative actors unchanged")
	_check(f["intents"].get_intents() == announced
		and f["intents"]._turn_index == scheduler_index and actions == original,
		label + ": scheduler and caller action definitions unchanged")
	_check(f["rng"].state == rng_state and f["map"].get_route() == map_route
		and randi() == oracle, label + ": map, run RNG and global RNG unchanged")


func _test_slain_and_atomic_failure() -> void:
	var dead := _fixture(F)
	if not dead.is_empty():
		var foes: CombatEnemies = dead["enemies"]
		_check(foes.apply_damage(2, 18) and foes.is_slain(2)
			and foes.get_enemy(2).get("position") == 2,
			"dead Seam Ripper remains in original source slot two")
		var rng_before: int = dead["rng"].state
		var result := CombatEnemyPhase.new().execute_phase(
			dead["party"], foes, dead["intents"].get_intents())
		_check(result == {"ok": true, "events": _events(F, 0, 2)},
			"dead source action unapplied while living Exposed and Block sources act")
		_check(dead["party"].get_hero(2).get("hp") == 30
			and dead["party"].get_hero(2).get("statuses", {}) == {"exposed": 1}
			and foes.get_enemy(1).get("position") == 1
			and foes.get_enemy(2).get("hp") == 0
			and foes.get_enemy(3).get("block") == 2
			and dead["rng"].state == rng_before,
			"dead source preserves slot, other sources act, no attack/selection RNG")
	var invalid := _fixture(H)
	if invalid.is_empty():
		return
	_check(invalid["party"].apply_damage(3, 26) and invalid["party"].is_downed(3),
		"illegal late target is an actually downed Tinker")
	var actions: Array = invalid["intents"].get_intents()
	actions[1] = {"enemy_position": 2, "type": "debuff",
		"amount": 1, "target_position": 3, "status": "weak"}
	_check(actions[0]["type"] == "shove" and actions[1]["type"] == "debuff",
		"legal earlier shove stages before later illegal live-target debuff")
	_reject(invalid, actions, "late invalid target after earlier staged shove")
	_check(invalid["party"].get_hero(1).get("id") == "warden",
		"rejected late phase cannot publish staged swap")
	var malformed := _fixture(F)
	if malformed.is_empty():
		return
	var wrong: Array = malformed["intents"].get_intents()
	wrong[2]["type"] = "invalid"
	_reject(malformed, wrong, "malformed final source after valid Exposed and attack")
	_check(malformed["party"].get_hero(2).get("hp") == 30
		and malformed["party"].get_hero(2).get("statuses", {}) == {},
		"invalid final source cannot publish earlier real attack or Exposed")
	var retry := CombatEnemyPhase.new().execute_phase(
		malformed["party"], malformed["enemies"], malformed["intents"].get_intents())
	_check(retry == {"ok": true, "events": _events(F, 0)}
		and malformed["party"].get_hero(2).get("hp") == 24,
		"valid retry after rejection executes exact 6-damage exposed hit")
