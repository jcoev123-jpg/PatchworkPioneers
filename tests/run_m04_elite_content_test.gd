extends SceneTree

var failures: Array[String] = []

var checks := 0
const ELITES := "res://data/enemies/m04_elites.json"
const STARTER := "res://data/enemies/starter_enemies.json"
const RUN := "res://data/enemies/run_enemies.json"
const HEROES := "res://data/heroes/starter_party.json"
const MARSHAL := "res://data/encounters/needle_marshal_elite.json"
const HEXER := "res://data/encounters/spool_hexer_elite.json"
const ROSTERS := {
	"needle_marshal_elite": ["needle_marshal", "ragling_guard"],
	"spool_hexer_elite": ["spool_hexer", "spool_stalker"]}
const PATTERNS := {
	"needle_marshal_elite": [
		{"enemy_position":1,"pattern":[
			{"type":"attack","amount":3,"target_position":1},
			{"type":"buff","amount":3},
			{"type":"shove","amount":0,"target_position":2,"direction":1},
			{"type":"attack","amount":4,"target_position":2}]},
		{"enemy_position":2,"pattern":[
			{"type":"block","amount":2},{"type":"attack","amount":1,"target_position":3}]}],
	"spool_hexer_elite": [
		{"enemy_position":1,"pattern":[
			{"type":"debuff","amount":1,"target_position":1,"status":"exposed"},
			{"type":"attack","amount":3,"target_position":1},
			{"type":"debuff","amount":1,"target_position":3,"status":"weak"},
			{"type":"attack","amount":3,"target_position":2}]},
		{"enemy_position":2,"pattern":[
			{"type":"attack","amount":1,"target_position":3},
			{"type":"block","amount":2},
			{"type":"attack","amount":1,"target_position":2}]}]}

func _initialize() -> void:
	_test_catalogs()
	_test_cycles()
	_test_selection()
	_test_live_weighted_elites()
	_test_rejections()
	for failure in failures:
		printerr(failure)
	print("run_m04_elite_content_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func _catalog(path: String) -> Array:
	_check(FileAccess.file_exists(path), "real JSON exists " + path)
	var records := RunTypedBattleRoster._parse_catalog_text(FileAccess.get_file_as_string(path))
	_check(not records.is_empty(), "real catalog parsed " + path)
	return records

func _all_catalogs() -> Array:
	var records := _catalog(ELITES)
	records.append_array(_catalog(STARTER))
	records.append_array(_catalog(RUN))
	return records

func _record(records: Array, id: String) -> Dictionary:
	var matches := records.filter(func(r: Dictionary) -> bool: return r.get("id") == id)
	_check(matches.size() == 1, "exactly one real catalog record " + id)
	return matches[0].duplicate(true) if matches.size() == 1 else {}

func _party() -> CombatParty:
	var records := _catalog(HEROES)
	var party := CombatParty.new([
		_record(records, "warden"), _record(records, "seamstress"),
		_record(records, "tinker")])
	_check(party.is_valid() and party.get_hero(1).get("hp") == 40
		and party.get_hero(2).get("hp") == 30 and party.get_hero(3).get("hp") == 26,
		"real three hero definitions")
	return party

func _roster(id: String) -> CombatEnemies:
	var records := _all_catalogs()
	var definitions: Array = []
	for name in ROSTERS[id]:
		definitions.append(_record(records, name))
	var result := CombatEnemies.new(definitions)
	_check(result.is_valid() and result.get_enemies().size() == 2,
		"real two-source CombatEnemies " + id)
	return result

func _path(id: String) -> String:
	return MARSHAL if id == "needle_marshal_elite" else HEXER

func _schedule(id: String) -> Array:
	var path := _path(id)
	_check(FileAccess.file_exists(path), "real encounter exists " + path)
	var result := RunFightEncounterSelection._parse_schedule_text(FileAccess.get_file_as_string(path))
	_check(result == PATTERNS[id] and CombatEnemyIntents.new(result).is_valid(),
		"exact two-source authored JSON action patterns " + id)
	return result



func _test_catalogs() -> void:
	var elites := _catalog(ELITES)
	var records := _all_catalogs()
	var before := records.duplicate(true)
	var required := {
		"needle_marshal": ["Needle Marshal", 28, "res://assets/paper/enemies/needle_marshal.png"],
		"spool_hexer": ["Spool Hexer", 24, "res://assets/paper/enemies/spool_hexer.png"],
		"ragling_guard": ["Guard Ragling", 12, "res://assets/paper/enemies/ragling_guard.png"],
		"spool_stalker": ["Spool Stalker", 14, "res://assets/paper/enemies/spool_stalker.png"]}
	for id in required:
		var record := _record(records, id)
		_check(record.get("name") == required[id][0]
			and record.get("max_hp") == required[id][1] and record.get("max_hp") is int
			and record.get("art_path") == required[id][2],
			"exact authored identity, HP, art " + id)
	for id in ["needle_marshal", "spool_hexer"]:
		_record(elites, id)
	_check(_record(elites, "needle_marshal").get("id") !=
		_record(elites, "spool_hexer").get("id"), "two distinct Elite IDs")
	for id in ROSTERS:
		var first := _roster(id)
		var second := _roster(id)
		var original := second.get_enemies()
		for index in range(2):
			var actor := first.get_enemy(index + 1)
			var definition := _record(records, ROSTERS[id][index])
			_check(actor.get("id") == definition.get("id")
				and actor.get("position") == index + 1
				and actor.get("max_hp") == definition.get("max_hp")
				and actor.get("hp") == definition.get("max_hp")
				and actor.get("block") == 0,
				"real actor slot, HP, zero Block " + id + "/" + str(index))
		_check(first.apply_damage(1, 2) and first.gain_block(2, 3),
			"first roster genuinely mutates " + id)
		var fetched := first.get_enemies()
		fetched[0]["hp"] = 0
		_check(second.get_enemies() == original and first.get_enemy(1)["hp"] > 0,
			"two independent rosters and isolated state snapshots " + id)
	_check(records == before, "complete authored catalog source untouched")


func _event(action: Dictionary) -> Dictionary:
	var value := action.duplicate(true)
	value.erase("amount")
	value["applied"] = true
	return value


func _swap(heroes: Array) -> void:
	var tmp: Dictionary = heroes[1]
	heroes[1] = heroes[2]
	heroes[2] = tmp
	heroes[1]["position"] = 2
	heroes[2]["position"] = 3


## Expected changes authored separately from the real enemy-phase implementation.
func _expected_beat(id: String, step: int, heroes: Array, enemies: Array) -> void:
	if id == "needle_marshal_elite":
		match step % 4:
			0:
				if heroes[0]["block"] > 0:
					heroes[0]["block"] -= 3
				else:
					heroes[0]["hp"] -= 3
			1:
				enemies[0]["block"] += 3
			2:
				_swap(heroes)
			3:
				heroes[1]["hp"] -= 4
		if step % 2 == 0:
			enemies[1]["block"] += 2
		else:
			heroes[2]["hp"] -= 1
	else:
		match step % 4:
			0:
				var statuses: Dictionary = heroes[0].get("statuses", {})
				statuses["exposed"] = statuses.get("exposed", 0) + 1
				heroes[0]["statuses"] = statuses
			1:
				var absorption: int = mini(heroes[0]["block"], 4)
				heroes[0]["block"] -= absorption
				heroes[0]["hp"] -= 4 - absorption
			2:
				var statuses: Dictionary = heroes[2].get("statuses", {})
				statuses["weak"] = statuses.get("weak", 0) + 1
				heroes[2]["statuses"] = statuses
			3:
				heroes[1]["hp"] -= 3
		match step % 3:
			0:
				heroes[2]["hp"] -= 1
			1:
				enemies[1]["block"] += 2
			2:
				heroes[1]["hp"] -= 1


func _test_cycles() -> void:
	for id in ROSTERS:
		var raw_json := FileAccess.get_file_as_string(_path(id))
		var history: Array = []
		for replay in range(2):
			var definitions := _schedule(id)
			var untouched := definitions.duplicate(true)
			var scheduler := CombatEnemyIntents.new(definitions)
			var party := _party()
			var enemies := _roster(id)
			_check(scheduler.is_valid() and CombatStartingBlock.new(party).apply(),
				"real intents and Warden opening Block " + id)
			var expected_heroes := party.get_heroes()
			var expected_enemies := enemies.get_enemies()
			# Marshal joint period 4, Hexer joint period 12: include first beat after wrap.
			var period := 4 if id == "needle_marshal_elite" else 12
			var observations: Array = []
			seed(62004)
			var expected_rng := randi()
			seed(62004)
			for step in range(period + 1):
				var announced := scheduler.get_intents()
				var expected: Array = []
				for source in PATTERNS[id]:
					var pattern: Array = source["pattern"]
					var action: Dictionary = pattern[step % pattern.size()].duplicate(true)
					action["enemy_position"] = source["enemy_position"]
					expected.append(action)
				_check(announced == expected, "exact each-source announced beat %s/%d" %
					[id, step])
				var copy := announced.duplicate(true)
				copy[0]["amount"] = 99
				_check(scheduler.get_intents() == expected, "announcement snapshot isolation")
				var input_before := announced.duplicate(true)
				var result := CombatEnemyPhase.new().execute_phase(party, enemies, announced)
				_check(result == {"ok": true, "events": [_event(expected[0]), _event(expected[1])]},
					"exact ordered phase events %s/%d" % [id, step])
				_expected_beat(id, step, expected_heroes, expected_enemies)
				_check(party.get_heroes() == expected_heroes,
					"complete actual hero identity/HP/Block/status %s/%d" % [id, step])
				_check(enemies.get_enemies() == expected_enemies,
					"complete actual enemy HP/Block %s/%d" % [id, step])
				_check(announced == input_before and scheduler.get_intents() == expected,
					"no input or scheduler advance by phase")
				if id == "spool_hexer_elite" and step == 1:
					_check(party.get_hero(1).get("hp") == 40 and
						party.get_hero(1).get("block") == 2,
						"Exposed changes incoming 3 into 4 before Warden Block")
				if id == "spool_hexer_elite" and step == 2:
					_check(party.get_hero(3).get("statuses", {}).get("weak") == 1 and
						CombatStatuses.new().adjusted_attack_damage(4,
							party.get_hero(3).get("statuses", {}), {}) == 3,
						"Weak applies exact 25 percent cut to Tinker attack")
				if id == "needle_marshal_elite" and step == 2:
					_check(party.get_hero(2).get("id") == "tinker" and
						party.get_hero(3).get("id") == "seamstress",
						"shove swaps occupied 2 and 3 with original hero identities")
				observations.append([announced, result, party.get_heroes(), enemies.get_enemies()])
				_check(scheduler.advance_turn(), "explicitly advance single beat")
			_check(randi() == expected_rng, "entire encounter timeline uses no global RNG")
			_check(definitions == untouched and
				FileAccess.get_file_as_string(_path(id)) == raw_json,
				"caller definitions and on-disk authored JSON unchanged")
			if replay == 0:
				history = observations
			else:
				_check(observations == history, "fresh complete multi-source replay " + id)



func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func _elite_route(seed_value: int) -> Dictionary:
	var rng := _rng(seed_value)
	var map := RunMap.new()
	if not map.generate(rng):
		return {}
	for node_id in map.get_legal_choices():
		if map.get_node(node_id).get("type") == "Elite" and map.choose_node(node_id):
			return {"map": map, "rng": rng, "node": node_id}
	return {}

func _elite_seed() -> int:
	for seed_value in range(1, 129):
		if not _elite_route(seed_value).is_empty():
			return seed_value
	return -1

func _snapshot(map: RunMap, rng: RandomNumberGenerator,
		selector: RunFightEncounterSelection) -> Dictionary:
	return {"floors": map.get_floors(), "route": map.get_route(),
		"current": map.get_current_node_id(), "choices": map.get_legal_choices(),
		"rng": rng.state, "cache": selector._selected.duplicate(true),
		"bound": selector._bound_map}

func _validate_assembly(answer: Dictionary, choice: Dictionary, id: String) -> void:
	_check(answer.get("ok") == true and answer.get("node_type") == "Elite"
		and answer.get("encounter_id") == id
		and answer.get("definitions") == choice.get("definitions"),
		"typed Elite choice identity and complete original definitions " + id)
	var enemies = answer.get("enemies")
	_check(enemies is CombatEnemies and enemies.is_valid(),
		"real valid CombatEnemies from typed assembly " + id)
	if not enemies is CombatEnemies or not enemies.is_valid():
		return
	_check(enemies.get_enemies().size() == 2, "two occupied typed Elite slots")
	var catalog := _all_catalogs()
	for i in range(2):
		var actor: Dictionary = enemies.get_enemy(i + 1)
		var source := _record(catalog, ROSTERS[id][i])
		_check(actor.get("id") == ROSTERS[id][i]
			and actor.get("position") == i + 1
			and actor.get("hp") == source.get("max_hp")
			and actor.get("max_hp") == source.get("max_hp")
			and actor.get("block") == 0,
			"typed actor exact ID/slot/max/current HP/Block " + id + "/" + str(i))
	var schedule := CombatEnemyIntents.new(answer.get("definitions", []))
	_check(schedule.is_valid() and schedule.get_intents().size() == 2,
		"typed result provides both source intent cycles " + id)

func _test_selection() -> void:
	var seed_value := _elite_seed()
	_check(seed_value > 0, "bounded seed sequence discovers legal generated Elite node")
	if seed_value < 0:
		return
	var a := _elite_route(seed_value)
	var b := _elite_route(seed_value)
	_check(not a.is_empty() and not b.is_empty() and a.node == b.node,
		"identical generated map and committed legal Elite")
	if a.is_empty() or b.is_empty():
		return
	var selector_a := RunFightEncounterSelection.new()
	var selector_b := RunFightEncounterSelection.new()
	var pool_a := {"needle_marshal_elite": MARSHAL, "spool_hexer_elite": HEXER}
	var pool_b := {"spool_hexer_elite": HEXER, "needle_marshal_elite": MARSHAL}
	var choice_a := selector_a.select_current_battle(a.map, a.rng, {"Elite": pool_a})
	var choice_b := selector_b.select_current_battle(b.map, b.rng, {"Elite": pool_b})
	_check(choice_a.get("success") == true and choice_a.get("node_type") == "Elite"
		and ROSTERS.has(choice_a.get("encounter_id"))
		and choice_a.get("definitions") == _schedule(choice_a.get("encounter_id", "")),
		"real Elite node chose one of two new JSON paths")
	_check(choice_a == choice_b and a.rng.state == b.rng.state,
		"reversed pool insertion yields identical deterministic choice/RNG")
	if not choice_a.get("success", false):
		return
	var before := _snapshot(a.map, a.rng, selector_a)
	var pristine := choice_a.duplicate(true)
	var duplicate := selector_a.select_current_battle(a.map, a.rng, {"Elite": {}})
	_check(duplicate == pristine and _snapshot(a.map, a.rng, selector_a) == before,
		"duplicate selection has exact cache identity and no extra RNG draw")
	duplicate["definitions"][0]["pattern"][0]["amount"] = 987
	_check(selector_a.select_current_battle(a.map, a.rng, {"Elite": {}}) == pristine,
		"mutating returned selection cannot corrupt internal cache")
	var bindings := ROSTERS.duplicate(true)
	var paths := [ELITES, STARTER, RUN]
	var bindings_before := bindings.duplicate(true)
	var paths_before := paths.duplicate(true)
	var typed := RunTypedBattleRoster.new().assemble(choice_a, bindings, paths)
	_validate_assembly(typed, pristine, pristine["encounter_id"])
	_check(_snapshot(a.map, a.rng, selector_a) == before and choice_a == pristine
		and bindings == bindings_before and paths == paths_before,
		"typed assembly does not reroll or alter map/selection/binding/catalog paths")
	# Both encounters, not just the seeded winner, assemble with their real JSON.
	for id in ROSTERS:
		var direct := {"success": true, "node_type": "Elite",
			"encounter_id": id, "definitions": _schedule(id)}
		var original := direct.duplicate(true)
		var one := RunTypedBattleRoster.new().assemble(direct, bindings, paths)
		var two := RunTypedBattleRoster.new().assemble(direct, bindings, paths)
		_validate_assembly(one, original, id)
		_validate_assembly(two, original, id)
		if one.get("ok") and two.get("ok"):
			_check(one["enemies"] != two["enemies"] and
				one["enemies"].get_enemies() == two["enemies"].get_enemies(),
				"typed actors are fresh and equal on direct replay " + id)
			_check(one["enemies"].apply_damage(1, 5)
				and two["enemies"].get_enemy(1)["hp"] ==
					_record(_all_catalogs(), ROSTERS[id][0])["max_hp"],
				"isolated mutable typed rosters " + id)
		_check(direct == original and _snapshot(a.map, a.rng, selector_a) == before,
			"direct assembly preserves source and seeded map/RNG/cache " + id)



func _reject(choice: Dictionary, bindings: Dictionary, paths: Array, label: String,
		map: RunMap, rng: RandomNumberGenerator, selector: RunFightEncounterSelection,
		party: CombatParty, enemies: CombatEnemies) -> void:
	var snapshot := _snapshot(map, rng, selector)
	var heroes := party.get_heroes()
	var actors := enemies.get_enemies()
	var original_choice := choice.duplicate(true)
	var original_bindings := bindings.duplicate(true)
	var original_paths := paths.duplicate(true)
	seed(76541)
	var expected_rng := randi()
	seed(76541)
	_check(RunTypedBattleRoster.new().assemble(choice, bindings, paths) == {"ok": false},
		"typed Elite fail-closed rejection " + label)
	_check(_snapshot(map, rng, selector) == snapshot
		and party.get_heroes() == heroes and enemies.get_enemies() == actors
		and choice == original_choice and bindings == original_bindings
		and paths == original_paths,
		"no partial actor/map/RNG/selection/source mutation " + label)
	_check(randi() == expected_rng, "rejection uses no global RNG " + label)

func _test_rejections() -> void:
	var seed_value := _elite_seed()
	if seed_value < 0:
		return
	var selected := _elite_route(seed_value)
	if selected.is_empty():
		return
	var map: RunMap = selected.map
	var rng: RandomNumberGenerator = selected.rng
	var selector := RunFightEncounterSelection.new()
	var choice := selector.select_current_battle(map, rng, {"Elite": {
		"needle_marshal_elite": MARSHAL, "spool_hexer_elite": HEXER}})
	_check(choice.get("success") == true and ROSTERS.has(choice.get("encounter_id")),
		"reject fixture is selected from authentic Elite node")
	if not choice.get("success", false):
		return
	var id: String = choice["encounter_id"]
	var bindings := ROSTERS.duplicate(true)
	var paths := [ELITES, STARTER, RUN]
	var party := _party()
	var enemies := _roster(id)
	_check(party.apply_damage(3, 2) and enemies.gain_block(2, 2),
		"nontrivial party damage and enemy Block before rejected assembly")
	var missing := bindings.duplicate(true)
	missing.erase(id)
	_reject(choice, missing, paths, "missing encounter binding",
		map, rng, selector, party, enemies)
	var unknown := bindings.duplicate(true)
	unknown[id] = [ROSTERS[id][0], "unknown_escort"]
	_reject(choice, unknown, paths, "unknown escort ID",
		map, rng, selector, party, enemies)
	var repeated := bindings.duplicate(true)
	repeated[id] = [ROSTERS[id][0], ROSTERS[id][0]]
	_reject(choice, repeated, paths, "repeated enemy ID",
		map, rng, selector, party, enemies)
	var short_binding := bindings.duplicate(true)
	short_binding[id] = [ROSTERS[id][0]]
	_reject(choice, short_binding, paths, "absent second enemy ID",
		map, rng, selector, party, enemies)
	_reject(choice, bindings, [ELITES, STARTER, RUN, ELITES],
		"duplicate catalog ID", map, rng, selector, party, enemies)
	_reject(choice, bindings, [ELITES, STARTER, "res://data/enemies/absent.json"],
		"missing catalog", map, rng, selector, party, enemies)
	var invalid := choice.duplicate(true)
	invalid["definitions"][1]["enemy_position"] = 1
	_reject(invalid, bindings, paths, "duplicate source position",
		map, rng, selector, party, enemies)
	invalid = choice.duplicate(true)
	invalid["definitions"][0]["pattern"][0]["type"] = "invented"
	_reject(invalid, bindings, paths, "bad source schedule",
		map, rng, selector, party, enemies)
	_check(RunFightEncounterSelection._parse_schedule_text(
		'[{"enemy_position":1,"pattern":[{"type":"attack","amount":2.5,"target_position":1}]}]'
		).is_empty(), "fractional authored source amount rejected before coercion")
	_check(RunFightEncounterSelection._parse_schedule_text(
		'[{"enemy_position":1,"pattern":[{"type":"shove","amount":0,"target_position":2,"direction":0.5}]}]'
		).is_empty(), "fractional shove direction rejected before coercion")
	var normalized_shove := RunFightEncounterSelection._parse_schedule_text(
		'[{"enemy_position":1,"pattern":[{"type":"shove","amount":0,"target_position":2,"direction":1.0}]}]')
	_check(normalized_shove.size() == 1 and normalized_shove[0]["pattern"][0]["direction"] is int
		and normalized_shove[0]["pattern"][0]["direction"] == 1,
		"exact integral JSON shove direction normalizes without truncation")
	var before := _snapshot(map, rng, selector)
	var good := RunTypedBattleRoster.new().assemble(choice, bindings, paths)
	_validate_assembly(good, choice, id)
	_check(_snapshot(map, rng, selector) == before,
		"subsequent valid typed assembly succeeds without reroll after rejections")



## The real authored entry picks both the roster and schedule; opt that exact
## returned scheduler into the same weighted battle binding used by a run.
## The escort is deliberately required to announce a non-damaging beat so
## the primary Elite attack has an independent Block-before-HP oracle.
func _test_live_weighted_elites() -> void:
	var expected_specs := {
		"needle_marshal": {"target": "front", "actions": [
			{"type": "attack", "amount": 5, "weight": 2},
			{"type": "attack", "amount": 4, "weight": 2},
			{"type": "buff", "amount": 3, "weight": 1},
			{"type": "shove", "amount": 0, "direction": 1, "weight": 1}]},
		"spool_hexer": {"target": "random", "actions": [
			{"type": "attack", "amount": 45, "weight": 3},
			{"type": "debuff", "amount": 1, "status": "exposed", "weight": 1},
			{"type": "debuff", "amount": 1, "status": "weak", "weight": 1}]}}
	var elites := _catalog(ELITES)
	for source_id in expected_specs:
		var actual := _record(elites, source_id)
		var spec: Dictionary = actual.get("intent", {})
		_check(spec.get("target") == expected_specs[source_id].target
			and spec.get("actions", []).size() == expected_specs[source_id].actions.size(),
			"retained exact target and weighted action count " + source_id)
		if spec.get("actions", []).size() == expected_specs[source_id].actions.size():
			for i in range(spec.actions.size()):
				var normalized := CombatEnemyIntents.weighted_action(spec.actions[i])
				var action: Dictionary = normalized.get("action", {}).duplicate(true)
				action["weight"] = normalized.get("weight", 0)
				_check(action == expected_specs[source_id].actions[i],
					"exact attack/nonattack amount, action type and weight " + source_id + "/" + str(i))
		var original_attacks := [4, 3] if source_id == "needle_marshal" else [3]
		var attack_index := 0
		for action in expected_specs[source_id].actions:
			if action.type == "attack":
				_check(action.amount > original_attacks[attack_index],
					"authored weighted attack exceeds exact original " + source_id + "/" + str(attack_index))
				attack_index += 1
		_check(actual.get("max_hp") == (28 if source_id == "needle_marshal" else 24)
			and actual.get("art_path") == "res://assets/paper/enemies/%s.png" % source_id,
			"retained exact health and art on weighted routed Elite " + source_id)
	for encounter_id in ROSTERS:
		var source_id: String = ROSTERS[encounter_id][0]
		var seed_value := -1
		# Require an actual legal node AND production pool choice, not a test
		# roster with its weights injected. Only select a seed with a live
		# weighted attack plus a non-damaging escort announcement.
		for attempt in range(1, 401):
			var candidate := _elite_route(attempt)
			if candidate.is_empty():
				continue
			var entry := RunAuthoredBattleEntry.new().entry_current_battle(
				candidate.map, candidate.rng, RunFightEncounterSelection.new())
			if not entry.get("success", false) or entry.get("encounter_id") != encounter_id:
				continue
			var party := _party()
			for position in [1, 2, 3]:
				_check(party.gain_block(position, 2), "genuine seeded Elite Block precondition")
			var intents: CombatEnemyIntents = entry.intents
			if not intents.bind_battle(entry.enemies, party, candidate.rng):
				continue
			var announced := intents.get_intents()
			if announced.size() == 2 and announced[0].get("type") == "attack" \
					and announced[1].get("type") in ["block", "buff"]:
				seed_value = attempt
				break
		_check(seed_value > 0, "bounded real route and weighted attack seed for " + encounter_id)
		if seed_value < 0:
			continue
		var replay_history: Array = []
		for replay in range(2):
			var routed := _elite_route(seed_value)
			_check(not routed.is_empty(), "real legal Elite route on replay " + encounter_id)
			if routed.is_empty():
				break
			var admitted := RunAuthoredBattleEntry.new().entry_current_battle(
				routed.map, routed.rng, RunFightEncounterSelection.new())
			_check(admitted.get("success", false) and admitted.get("encounter_id") == encounter_id
				and admitted.get("node_type") == "Elite",
				"live authored weighted Elite entry " + encounter_id)
			if not admitted.get("success", false):
				break
			var enemies: CombatEnemies = admitted.enemies
			var party := _party()
			for position in [1, 2, 3]:
				_check(party.gain_block(position, 2), "independent starting Block " + encounter_id)
			_check(enemies.get_enemies().size() == 2
				and enemies.get_enemy(1).get("id") == source_id
				and enemies.get_enemy(1).get("intent") == _record(elites, source_id).get("intent")
				and not admitted.definitions.is_empty(),
				"non-vacuous true catalog-bound roster and schedule " + encounter_id)
			var bound: CombatEnemyIntents = admitted.intents
			_check(bound.bind_battle(enemies, party, routed.rng) and bound.is_bound(),
				"run RNG drives real bound weighted intentions " + encounter_id)
			if not bound.is_bound():
				break
			var rng_at_announcement: int = routed.rng.state
			var announced: Array[Dictionary] = bound.get_intents()
			_check(announced.size() == 2 and announced == bound.get_intents()
				and routed.rng.state == rng_at_announcement,
				"cached attack announcement has no extra draw " + encounter_id)
			if announced.size() != 2:
				break
			var attack := announced[0]
			var escort := announced[1]
			_check(attack.get("type") == "attack"
				and escort.get("type") in ["block", "buff"]
				and attack.get("amount") in ([5, 4] if source_id == "needle_marshal" else [45])
				and attack.get("enemy_position") == 1 and escort.get("enemy_position") == 2,
				"exact strengthened attack and harmless companion weighted beat " + encounter_id)
			var target: int = attack.get("target_position", 0)
			_check(target in [1, 2, 3] and
				(target == 1 if source_id == "needle_marshal" else true),
				"retained live front/random target policy " + encounter_id)
			if target not in [1, 2, 3]:
				break
			var original := party.get_hero(target)
			var before_hp: int = original.hp
			var before_block: int = original.block
			_check(before_hp > 0 and before_block == 2 and attack.amount > before_block,
				"non-vacuous Block-before-HP attack preconditions " + encounter_id)
			var snapshot := [party.get_heroes(), enemies.get_enemies(), routed.rng.state]
			var bad := CombatEnemyPhase.new().execute_phase(party, enemies, [
				{"enemy_position": 1, "type": "attack", "amount": attack.amount, "target_position": 0}])
			_check(not bad.get("ok", false) and snapshot ==
				[party.get_heroes(), enemies.get_enemies(), routed.rng.state],
				"invalid phase action refuses without HP/Block/RNG mutation " + encounter_id)
			var settled := CombatEnemyPhase.new().execute_phase(party, enemies, announced)
			var after := party.get_hero(target)
			_check(settled.get("ok", false)
				and settled.get("events", []).size() == 2
				and settled.events[0] == _event(attack)
				and after.block == maxi(0, before_block - attack.amount)
				and after.hp == maxi(0, before_hp - maxi(0, attack.amount - before_block)),
				"independently verified exact Block absorption before HP " + encounter_id)
			var trace := [admitted.encounter_id, announced, settled, party.get_heroes(),
				enemies.get_enemies(), routed.rng.state]
			if replay == 0:
				replay_history = trace
			else:
				_check(replay_history == trace,
					"identical real typed Elite entry, bound weighted attack, phase and RNG replay " + encounter_id)
