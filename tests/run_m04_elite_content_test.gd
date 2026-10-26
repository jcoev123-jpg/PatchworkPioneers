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
## V3-2 appends two harder look-driven elites. Their authored alternatives are
## checked by ID only, never by catalog total or position.
const V3_ELITES := {
	"scissor_bailiff": {
		"name": "Scissor Bailiff", "max_hp": 36,
		"art_path": "res://assets/paper/enemies/scissor_bailiff.png",
		"target": "front",
		"actions": [
			{"type": "snip_block", "amount": 0, "weight": 2},
			{"type": "debuff", "amount": 2, "status": "bleed", "weight": 2},
			{"type": "attack", "amount": 9, "weight": 2}]},
	"zipper_hauler": {
		"name": "Zipper Hauler", "max_hp": 38,
		"art_path": "res://assets/paper/enemies/zipper_hauler.png",
		"target": "front",
		"actions": [
			{"type": "shove", "amount": 0, "direction": 1, "weight": 2},
			{"type": "debuff", "amount": 1, "status": "exposed", "weight": 2},
			{"type": "attack", "amount": 8, "weight": 2}]}}
## The two earlier Elite records must survive the append unchanged.
const LEGACY_ELITES := {
	"needle_marshal": {
		"name": "Needle Marshal", "max_hp": 28,
		"art_path": "res://assets/paper/enemies/needle_marshal.png",
		"target": "front",
		"actions": [
			{"type": "attack", "amount": 5, "weight": 2},
			{"type": "attack", "amount": 4, "weight": 2},
			{"type": "buff", "amount": 3, "weight": 1},
			{"type": "shove", "amount": 0, "direction": 1, "weight": 1}]},
	"spool_hexer": {
		"name": "Spool Hexer", "max_hp": 24,
		"art_path": "res://assets/paper/enemies/spool_hexer.png",
		"target": "random",
		"actions": [
			{"type": "attack", "amount": 45, "weight": 3},
			{"type": "debuff", "amount": 1, "status": "exposed", "weight": 1},
			{"type": "debuff", "amount": 1, "status": "weak", "weight": 1}]}}
## V3-2 appends two further harder Elites that reuse existing needle and spool
## puppets. They are authored content only: no encounter or floor-band pool
## binds them yet, so these checks read them by ID from the catalog itself.
const V3_2_ELITES := {
	"needle_briar_guard": {
		"name": "Needle Briar Guard", "max_hp": 42,
		"art_path": "res://assets/paper/enemies/needle_marshal.png",
		"target": "front",
		"actions": [
			{"type": "debuff", "amount": 2, "status": "bleed", "weight": 2},
			{"type": "block", "amount": 8, "weight": 2},
			{"type": "attack", "amount": 9, "weight": 3}]},
	"spool_snarekeeper": {
		"name": "Spool Snarekeeper", "max_hp": 40,
		"art_path": "res://assets/paper/enemies/spool_hexer.png",
		"target": "front",
		"actions": [
			{"type": "shove", "amount": 0, "direction": 1, "weight": 2},
			{"type": "debuff", "amount": 2, "status": "weak", "weight": 2},
			{"type": "attack", "amount": 8, "weight": 3}]}}
## Authored slot order for the two-record V3-2 roster fixtures.
const V3_2_ORDER := ["needle_briar_guard", "spool_snarekeeper"]
const KEYWORD_ELITES := {
	"pincushion_matriarch": {
		"name": "Pincushion Matriarch", "max_hp": 44, "thorns": 4,
		"art_path": "res://assets/paper/enemies/pincushion_hedgehog.png",
		"target": "front", "actions": [
			{"type": "attack", "amount": 9, "weight": 3},
			{"type": "debuff", "status": "bleed", "amount": 2, "weight": 2},
			{"type": "block", "amount": 9, "weight": 2}]},
	"spool_leech": {
		"name": "Spool Leech", "max_hp": 42, "drain": true,
		"art_path": "res://assets/paper/enemies/spool_hexer.png",
		"target": "lowest_living_hp", "actions": [
			{"type": "attack", "amount": 8, "weight": 4},
			{"type": "debuff", "status": "weak", "amount": 2, "weight": 2},
			{"type": "block", "amount": 6, "weight": 1}]}}
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
	_test_v3_elites()
	_test_v3_2_elites()
	_test_keyword_elites()
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


## One authored Elite record checked by ID against its independent expectation:
## identity, HP, art, target policy and every executable weighted alternative.
func _authored_elite(records: Array, id: String, expected: Dictionary) -> Dictionary:
	var record := _record(records, id)
	if record.is_empty():
		return {}
	_check(record.get("id") == id and record.get("name") == expected["name"]
		and record.get("max_hp") is int and record.get("max_hp") == expected["max_hp"]
		and record.get("art_path") == expected["art_path"],
		"exact authored identity, HP and art " + id)
	var spec: Variant = record.get("intent")
	_check(spec is Dictionary and spec.size() == 2
		and spec.get("target") == expected["target"], "exact authored target policy " + id)
	var actions: Array = spec.get("actions") if spec is Dictionary else []
	var normalized: Array = []
	for raw in actions:
		if not raw is Dictionary:
			_check(false, "authored alternative is a dictionary " + id)
			continue
		_check(not raw.has("target_position") and not raw.has("enemy_position")
			and not raw.has("target_policy"),
			"authored alternative carries no target or slot field " + id + " " + str(raw))
		var weighted := CombatEnemyIntents.weighted_action(raw)
		var action: Dictionary = weighted.get("action", {}).duplicate(true)
		action["weight"] = weighted.get("weight", 0)
		normalized.append(action)
	_check(normalized == expected["actions"],
		"exact executable weighted alternatives " + id + " " + str(normalized))
	return record


## A genuinely living three-hero party and the new elite alone in enemy slot 1.
func _new_elite_fixture(record: Dictionary) -> Dictionary:
	var party := _party()
	var enemies := CombatEnemies.new([record])
	var living := 0
	for hero in party.get_heroes():
		if hero.get("hp", 0) > 0:
			living += 1
	_check(party.is_valid() and living == 3, "three living occupied hero slots "
		+ str(record.get("id")))
	_check(enemies.is_valid() and enemies.get_enemies().size() == 1
		and enemies.get_enemy(1).get("id") == record.get("id")
		and enemies.get_enemy(1).get("hp") == record.get("max_hp")
		and enemies.get_enemy(1).get("position") == 1,
		"new authored elite alone in enemy slot 1 " + str(record.get("id")))
	return {"party": party, "enemies": enemies}


## The event CombatEnemyPhase publishes for one applied announced beat.
func _phase_event(action: Dictionary) -> Dictionary:
	var event := {"type": action["type"], "enemy_position": action["enemy_position"],
		"applied": true}
	for field in ["target_position", "status", "direction"]:
		if action.has(field):
			event[field] = action[field]
	return event


## Seeded bound announcements for one authored elite over several turns.
func _announcements(record: Dictionary, seed_value: int, turns: int) -> Array:
	var fixture := _new_elite_fixture(record)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# The legacy schedule is only the binding fixture; the announcement comes
	# from the authored weighted intent of the real roster record.
	var scheduler := CombatEnemyIntents.new([
		{"enemy_position": 1, "pattern": [{"type": "block", "amount": 1}]}])
	if not scheduler.is_valid() or not scheduler.bind_battle(
			fixture["enemies"], fixture["party"], rng):
		return []
	var trace: Array = []
	for turn in range(turns):
		trace.append(scheduler.get_intents())
		if not scheduler.advance_turn():
			return []
	return trace


func _assert_elite_announcements(id: String, record: Dictionary) -> void:
	var bodies: Array = []
	for authored in V3_ELITES[id]["actions"]:
		var body: Dictionary = authored.duplicate(true)
		body.erase("weight")
		bodies.append(body)
	var first := _announcements(record, 41771, 8)
	var second := _announcements(record, 41771, 8)
	_check(first.size() == 8 and second == first,
		"identical seeded announcements from a fresh bound instance " + id)
	var observed := 0
	for turn in first:
		_check(turn.size() == 1 and turn[0].get("enemy_position") == 1,
			"one announcement for the single authored slot " + id)
		if turn.size() != 1:
			continue
		var announced: Dictionary = turn[0]
		var target = announced.get("target_position")
		var body := announced.duplicate(true)
		body.erase("enemy_position")
		body.erase("target_position")
		_check(target is int and target >= 1 and target <= CombatParty.PARTY_SIZE,
			"front policy picks one living hero slot " + id)
		_check(body in bodies,
			"announcement is one authored alternative only " + id + " " + str(announced))
		var executable: Dictionary = announced.duplicate(true)
		executable.erase("enemy_position")
		_check(CombatEnemyIntents.valid_action(executable),
			"announcement is an executable action " + id + " " + str(announced))
		observed += 1
	_check(observed == 8, "all seeded announcements observed " + id)


func _test_scissor_beats(record: Dictionary) -> void:
	var fixture := _new_elite_fixture(record)
	var party: CombatParty = fixture["party"]
	var enemies: CombatEnemies = fixture["enemies"]
	var snip := {"type": "snip_block", "enemy_position": 1, "amount": 0,
		"target_position": 1}
	_check(party.gain_block(1, 5) and party.get_hero(1).get("block") == 5
		and party.get_hero(1).get("hp") > 0,
		"snip precondition: a living, genuinely blocked front hero")
	var heroes_before := party.get_heroes()
	var foes_before := enemies.get_enemies()
	var input := [snip.duplicate(true)]
	var input_before := input.duplicate(true)
	var result: Dictionary = CombatEnemyPhase.new().execute_phase(party, enemies, input)
	_check(result == {"ok": true, "events": [_phase_event(snip)]},
		"announced Scissor snip resolves as one applied beat")
	var after := party.get_hero(1)
	_check(after.get("block") == 0 and after.get("hp") == heroes_before[0]["hp"],
		"Scissor snip takes the hero's Block to exactly 0 without HP damage")
	_check(party.get_hero(2) == heroes_before[1] and party.get_hero(3) == heroes_before[2]
		and enemies.get_enemies() == foes_before and input == input_before,
		"snip leaves other heroes, the enemy roster and the input untouched")

	fixture = _new_elite_fixture(record)
	party = fixture["party"]
	enemies = fixture["enemies"]
	var bleed := {"type": "debuff", "enemy_position": 1, "amount": 2,
		"status": "bleed", "target_position": 2}
	heroes_before = party.get_heroes()
	result = CombatEnemyPhase.new().execute_phase(party, enemies, [bleed.duplicate(true)])
	after = party.get_hero(2)
	_check(result == {"ok": true, "events": [_phase_event(bleed)]}
		and after.get("statuses") == {"bleed": 2}
		and after.get("hp") == heroes_before[1]["hp"]
		and after.get("block") == heroes_before[1]["block"]
		and party.get_hero(1).get("statuses", {}).is_empty()
		and party.get_hero(3).get("statuses", {}).is_empty(),
		"authored Bleed 2 lands twice on exactly the chosen living hero")

	fixture = _new_elite_fixture(record)
	party = fixture["party"]
	enemies = fixture["enemies"]
	party._heroes[0]["statuses"] = {"bleed": 1}
	result = CombatEnemyPhase.new().execute_phase(party, enemies, [
		{"type": "debuff", "enemy_position": 1, "amount": 2,
		"status": "bleed", "target_position": 1}])
	_check(result.get("ok", false) and party.get_hero(1).get("statuses") == {"bleed": 3},
		"authored Bleed 2 adds two to an existing hero counter")

	fixture = _new_elite_fixture(record)
	party = fixture["party"]
	enemies = fixture["enemies"]
	var strike := {"type": "attack", "enemy_position": 1, "amount": 9,
		"target_position": 3}
	_check(party.gain_block(3, 4) and party.get_hero(3).get("hp") == 26,
		"attack precondition: rear Tinker holds four Block and 26 HP")
	foes_before = enemies.get_enemies()
	result = CombatEnemyPhase.new().execute_phase(party, enemies, [strike.duplicate(true)])
	after = party.get_hero(3)
	_check(result == {"ok": true, "events": [_phase_event(strike)]}
		and after.get("block") == 0 and after.get("hp") == 21
		and enemies.get_enemies() == foes_before,
		"authored Scissor attack 9 absorbs four Block then deals exactly five HP")


func _test_zipper_beats(record: Dictionary) -> void:
	var fixture := _new_elite_fixture(record)
	var party: CombatParty = fixture["party"]
	var enemies: CombatEnemies = fixture["enemies"]
	var shove := {"type": "shove", "enemy_position": 1, "amount": 0,
		"target_position": 1, "direction": 1}
	_check(party.apply_damage(1, 4) and party.gain_block(1, 2)
		and party.apply_damage(2, 3) and party.gain_block(2, 1),
		"shove precondition: both front heroes live with distinct HP and Block")
	party._heroes[1]["statuses"] = {"exposed": 1}
	var heroes_before := party.get_heroes()
	var foes_before := enemies.get_enemies()
	var input := [shove.duplicate(true)]
	var input_before := input.duplicate(true)
	var result: Dictionary = CombatEnemyPhase.new().execute_phase(party, enemies, input)
	_check(result == {"ok": true, "events": [_phase_event(shove)]},
		"announced Zipper shove +1 resolves as one applied beat")
	var expected := heroes_before.duplicate(true)
	expected[0] = heroes_before[1].duplicate(true)
	expected[1] = heroes_before[0].duplicate(true)
	expected[0]["position"] = 1
	expected[1]["position"] = 2
	_check(party.get_heroes() == expected,
		"shove +1 exchanges the living heroes in positions 1/2 with every other field kept")
	_check(party.get_hero(1).get("id") == "seamstress"
		and party.get_hero(2).get("id") == "warden"
		and party.get_hero(1).get("hp") == heroes_before[1]["hp"]
		and party.get_hero(2).get("hp") == heroes_before[0]["hp"]
		and party.get_hero(1).get("block") == heroes_before[1]["block"]
		and party.get_hero(2).get("block") == heroes_before[0]["block"],
		"swapped heroes keep their current HP, Block and statuses")
	_check(enemies.get_enemies() == foes_before and input == input_before,
		"a shove is not a damaging move and leaves the authored input untouched")

	fixture = _new_elite_fixture(record)
	party = fixture["party"]
	enemies = fixture["enemies"]
	var expose := {"type": "debuff", "enemy_position": 1, "amount": 1,
		"status": "exposed", "target_position": 3}
	heroes_before = party.get_heroes()
	result = CombatEnemyPhase.new().execute_phase(party, enemies, [expose.duplicate(true)])
	_check(result == {"ok": true, "events": [_phase_event(expose)]}
		and party.get_hero(3).get("statuses") == {"exposed": 1}
		and party.get_hero(3).get("hp") == heroes_before[2]["hp"]
		and party.get_hero(1).get("statuses", {}).is_empty()
		and party.get_hero(2).get("statuses", {}).is_empty(),
		"authored Exposed 1 lands on exactly the chosen living hero")

	fixture = _new_elite_fixture(record)
	party = fixture["party"]
	enemies = fixture["enemies"]
	var strike := {"type": "attack", "enemy_position": 1, "amount": 8,
		"target_position": 2}
	_check(party.gain_block(2, 3) and party.get_hero(2).get("hp") == 30,
		"attack precondition: middle Seamstress holds three Block and 30 HP")
	foes_before = enemies.get_enemies()
	result = CombatEnemyPhase.new().execute_phase(party, enemies, [strike.duplicate(true)])
	var after := party.get_hero(2)
	_check(result == {"ok": true, "events": [_phase_event(strike)]}
		and after.get("block") == 0 and after.get("hp") == 25
		and enemies.get_enemies() == foes_before,
		"authored Zipper attack 8 absorbs three Block then deals exactly five HP")


## A rejected beat must leave both rosters and the announced input byte-identical.
func _reject_beat(label: String, party: CombatParty, enemies: CombatEnemies,
		action: Dictionary) -> void:
	var heroes_before := party.get_heroes()
	var foes_before := enemies.get_enemies()
	var input := [action.duplicate(true)]
	var input_before := input.duplicate(true)
	var result: Dictionary = CombatEnemyPhase.new().execute_phase(party, enemies, input)
	_check(result == {"ok": false, "events": []}, "illegal announced beat fails closed " + label)
	_check(party.get_heroes() == heroes_before and enemies.get_enemies() == foes_before
		and input == input_before,
		"rejected beat mutates no hero, enemy or input " + label)


func _test_v3_phase_rejections(records: Dictionary) -> void:
	for id in records:
		var record: Dictionary = records[id]
		var fixture := _new_elite_fixture(record)
		var party: CombatParty = fixture["party"]
		_check(party.gain_block(1, 5) and party.gain_block(3, 4),
			"rejection precondition: real hero Block must survive " + id)
		_reject_beat("out-of-range snip target " + id, party, fixture["enemies"],
			{"type": "snip_block", "enemy_position": 1, "amount": 0, "target_position": 0})

		fixture = _new_elite_fixture(record)
		party = fixture["party"]
		_check(party.gain_block(1, 5) and party.apply_damage(2, 30) and party.is_downed(2),
			"rejection precondition: the middle hero is genuinely downed " + id)
		_reject_beat("Bleed on a downed hero " + id, party, fixture["enemies"],
			{"type": "debuff", "enemy_position": 1, "amount": 2,
			"status": "bleed", "target_position": 2})
		_reject_beat("Exposed on a downed hero " + id, party, fixture["enemies"],
			{"type": "debuff", "enemy_position": 1, "amount": 1,
			"status": "exposed", "target_position": 2})

		fixture = _new_elite_fixture(record)
		party = fixture["party"]
		_check(party.gain_block(3, 4), "rejection precondition: rear Block must survive " + id)
		_reject_beat("shove past the back slot " + id, party, fixture["enemies"],
			{"type": "shove", "enemy_position": 1, "amount": 0,
			"target_position": 3, "direction": 1})

		fixture = _new_elite_fixture(record)
		party = fixture["party"]
		_check(party.gain_block(1, 4) and party.apply_damage(2, 30) and party.is_downed(2),
			"rejection precondition: the shove partner is genuinely downed " + id)
		_reject_beat("shove into a downed neighbour " + id, party, fixture["enemies"],
			{"type": "shove", "enemy_position": 1, "amount": 0,
			"target_position": 1, "direction": 1})

		fixture = _new_elite_fixture(record)
		_reject_beat("announced source outside the roster " + id,
			fixture["party"], fixture["enemies"],
			{"type": "attack", "enemy_position": 2, "amount": 9, "target_position": 1})


func _test_v3_elites() -> void:
	seed(61388)
	var expected_rng := randi()
	seed(61388)
	var elites := _catalog(ELITES)
	var untouched := elites.duplicate(true)
	for id in LEGACY_ELITES:
		_authored_elite(elites, id, LEGACY_ELITES[id])
	var records := {}
	for id in V3_ELITES:
		records[id] = _authored_elite(elites, id, V3_ELITES[id])
	_check(records["scissor_bailiff"].get("id") == "scissor_bailiff"
		and records["zipper_hauler"].get("id") == "zipper_hauler"
		and records["scissor_bailiff"].get("id") != records["zipper_hauler"].get("id"),
		"two distinct new Elite IDs exist exactly once each")
	_check(records["scissor_bailiff"].get("intent") != records["zipper_hauler"].get("intent"),
		"the two new elites author distinct weighted alternatives")
	for id in records:
		_assert_elite_announcements(id, records[id])
	_test_scissor_beats(records["scissor_bailiff"])
	_test_zipper_beats(records["zipper_hauler"])
	_test_v3_phase_rejections(records)
	_check(elites == untouched and RunTypedBattleRoster._parse_catalog_text(
		FileAccess.get_file_as_string(ELITES)) == untouched,
		"authored elite records and on-disk source untouched by the append checks")
	_check(randi() == expected_rng,
		"v3 elite catalog lookups, announcements and beats use no global RNG")


## A fresh two-Elite battle: both V3-2 records in authored slot order and a
## genuinely living Warden/Seamstress/Tinker party.
func _v3_2_fixture(records: Dictionary) -> Dictionary:
	var definitions: Array = []
	for id in V3_2_ORDER:
		definitions.append(records[id].duplicate(true))
	var party := _party()
	var enemies := CombatEnemies.new(definitions)
	var living := 0
	for hero in party.get_heroes():
		if hero.get("hp", 0) > 0:
			living += 1
	_check(party.is_valid() and living == 3,
		"three living hero slots for the V3-2 fixtures")
	_check(enemies.is_valid() and enemies.get_enemies().size() == 2
		and enemies.get_enemy(1).get("id") == "needle_briar_guard"
		and enemies.get_enemy(2).get("id") == "spool_snarekeeper"
		and enemies.get_enemy(1).get("hp") == 42
		and enemies.get_enemy(2).get("hp") == 40,
		"both authored V3-2 elites occupy real slots 1 and 2")
	return {"party": party, "enemies": enemies}


## One executable beat taken from an authenticated record's authored list with
## its own source slot and a resolved hero target. A missing alternative fails.
func _authored_beat(record: Dictionary, source: int, kind: String,
		target: int) -> Dictionary:
	var spec: Variant = record.get("intent", {})
	var raw_actions: Variant = spec.get("actions", []) if spec is Dictionary else []
	if not raw_actions is Array:
		_check(false, "authenticated record authors an action list")
		return {}
	for raw in raw_actions:
		if not raw is Dictionary or raw.get("type") != kind:
			continue
		var weighted := CombatEnemyIntents.weighted_action(raw)
		var body: Variant = weighted.get("action", {})
		_check(body is Dictionary and not body.is_empty(),
			"authenticated authored alternative " + kind + " of "
				+ str(record.get("id")))
		if not body is Dictionary or body.is_empty():
			return {}
		var action: Dictionary = body.duplicate(true)
		action["enemy_position"] = source
		if kind in ["attack", "debuff", "shove", "snip_block"]:
			action["target_position"] = target
		return action
	_check(false, "authored alternative exists for " + kind + " of "
		+ str(record.get("id")))
	return {}


## Authored action bodies of one V3-2 record without their weights.
func _authored_bodies(id: String) -> Array:
	var bodies: Array = []
	for authored in V3_2_ELITES[id]["actions"]:
		var body: Dictionary = authored.duplicate(true)
		body.erase("weight")
		bodies.append(body)
	return bodies


## Bind one fresh seeded scheduler to the authentic two-Elite roster and the
## real three-hero party, then replay a fixed number of announced turns.
func _v3_2_announcements(records: Dictionary, seed_value: int, turns: int) -> Dictionary:
	var fixture := _v3_2_fixture(records)
	var party: CombatParty = fixture["party"]
	var enemies: CombatEnemies = fixture["enemies"]
	var rng := _rng(seed_value)
	# The legacy schedule is only the binding fixture: announcements come from
	# the authentic roster's authored weighted intents.
	var scheduler := CombatEnemyIntents.new([
		{"enemy_position": 1, "pattern": [{"type": "block", "amount": 1}]},
		{"enemy_position": 2, "pattern": [{"type": "block", "amount": 1}]}])
	if not scheduler.is_valid() or not scheduler.bind_battle(enemies, party, rng):
		_check(false, "genuine V3-2 roster binds to seeded weighted intentions")
		return {}
	var quiet_state: int = rng.state
	var trace: Array = []
	var states: Array = []
	for turn in range(turns):
		var announced := scheduler.get_intents()
		_check(scheduler.get_intents() == announced and rng.state == quiet_state,
			"V3-2 announcement readback spends no run RNG")
		trace.append(announced)
		states.append(rng.state)
		if not scheduler.advance_turn():
			_check(false, "bound V3-2 scheduler advances one turn")
			return {}
		quiet_state = rng.state
	return {"trace": trace, "states": states, "rng": rng.state}


## The authored weighted spec, bind_battle, front targets and fixed-seed replay
## of both new records on a genuine roster and party.
func _test_v3_2_announcements(records: Dictionary) -> void:
	var fixture := _v3_2_fixture(records)
	var roster: CombatEnemies = fixture["enemies"]
	for position in range(1, V3_2_ORDER.size() + 1):
		var id: String = V3_2_ORDER[position - 1]
		var expected: Dictionary = V3_2_ELITES[id]
		_check(roster.get_enemy(position).get("id") == id
			and roster.get_enemy(position).get("intent") == records[id].get("intent"),
			"authentic roster slot carries the authored intent " + id)
		var slot := CombatEnemyIntents._weighted_slot(position, records[id].get("intent"))
		_check(not slot.is_empty() and slot.get("enemy_position") == position
			and slot.get("target") == expected["target"]
			and slot.get("actions", []).size() == expected["actions"].size(),
			"authored weighted spec normalizes for its own slot " + id)
		if slot.is_empty():
			continue
		var normalized: Array = []
		for entry in slot["actions"]:
			var action: Dictionary = entry["action"].duplicate(true)
			action["weight"] = entry["weight"]
			normalized.append(action)
		_check(normalized == expected["actions"],
			"exact authored weighted alternatives and positive weights " + id)

	var first := _v3_2_announcements(records, 41771, 6)
	var second := _v3_2_announcements(records, 41771, 6)
	_check(not first.is_empty() and first == second,
		"two fresh same-seed bound instances announce identical actions and RNG")
	if first.is_empty():
		return
	_check(first["trace"].size() == 6,
		"six seeded turns were announced from the authentic roster")
	var observed := 0
	for turn in first["trace"]:
		_check(turn.size() == 2 and turn[0].get("enemy_position") == 1
			and turn[1].get("enemy_position") == 2,
			"one announcement for each authentic V3-2 slot")
		for action in turn:
			observed += 1
			var source: int = action.get("enemy_position", 0)
			if source < 1 or source > V3_2_ORDER.size():
				_check(false, "announced source is an authentic V3-2 slot")
				continue
			var id: String = V3_2_ORDER[source - 1]
			var body: Dictionary = action.duplicate(true)
			body.erase("enemy_position")
			body.erase("target_position")
			_check(body in _authored_bodies(id),
				"announcement is one authored alternative only " + id + " "
					+ str(action))
			if action.get("type") in ["attack", "debuff", "shove"]:
				_check(action.get("target_position") == 1,
					"front policy announces the living front hero " + id)
	_check(observed == 12, "every seeded two-slot announcement was checked")


## Each authored V3-2 alternative on its own fresh full-party fixture.
func _test_v3_2_beats(records: Dictionary) -> void:
	var needle: Dictionary = records["needle_briar_guard"]
	var spool: Dictionary = records["spool_snarekeeper"]

	# Needle: authored Bleed 2 on the living front hero, no immediate damage.
	var fixture := _v3_2_fixture(records)
	var party: CombatParty = fixture["party"]
	var enemies: CombatEnemies = fixture["enemies"]
	var beat := _authored_beat(needle, 1, "debuff", 1)
	if beat.is_empty():
		return
	_check(beat.get("status") == "bleed" and beat.get("amount") == 2,
		"authenticated Needle alternative is authored Bleed 2")
	var heroes_before := party.get_heroes()
	var foes_before := enemies.get_enemies()
	var input := [beat.duplicate(true)]
	var input_before := input.duplicate(true)
	var result: Dictionary = CombatEnemyPhase.new().execute_phase(party, enemies, input)
	var after := party.get_hero(1)
	_check(result == {"ok": true, "events": [_phase_event(beat)]}
		and after.get("statuses") == {"bleed": 2}
		and after.get("hp") == heroes_before[0]["hp"]
		and after.get("block") == heroes_before[0]["block"],
		"authored Bleed 2 lands without immediate damage")
	_check(party.get_hero(2) == heroes_before[1] and party.get_hero(3) == heroes_before[2]
		and enemies.get_enemies() == foes_before and input == input_before,
		"Needle Bleed leaves the other heroes, roster and input untouched")

	# Needle: authored Block 8 on its own enemy slot.
	fixture = _v3_2_fixture(records)
	party = fixture["party"]
	enemies = fixture["enemies"]
	beat = _authored_beat(needle, 1, "block", 0)
	if beat.is_empty():
		return
	_check(beat == {"type": "block", "amount": 8, "enemy_position": 1},
		"authenticated Needle alternative is authored Block 8")
	heroes_before = party.get_heroes()
	foes_before = enemies.get_enemies()
	input = [beat.duplicate(true)]
	input_before = input.duplicate(true)
	result = CombatEnemyPhase.new().execute_phase(party, enemies, input)
	_check(result == {"ok": true, "events": [_phase_event(beat)]}
		and enemies.get_enemy(1).get("block") == 8
		and enemies.get_enemy(1).get("hp") == foes_before[0]["hp"]
		and enemies.get_enemy(2) == foes_before[1]
		and party.get_heroes() == heroes_before and input == input_before,
		"authored Block 8 guards only the Needle slot and touches no hero")

	# Needle: authored Attack 9 into a front hero who holds four Block.
	fixture = _v3_2_fixture(records)
	party = fixture["party"]
	enemies = fixture["enemies"]
	beat = _authored_beat(needle, 1, "attack", 1)
	if beat.is_empty():
		return
	_check(beat.get("amount") == 9 and party.gain_block(1, 4)
		and party.get_hero(1).get("hp") == 40,
		"authenticated Needle attack is 9 against a living four-Block front hero")
	foes_before = enemies.get_enemies()
	result = CombatEnemyPhase.new().execute_phase(party, enemies, [beat.duplicate(true)])
	after = party.get_hero(1)
	_check(result == {"ok": true, "events": [_phase_event(beat)]}
		and after.get("block") == 0 and after.get("hp") == 35
		and party.get_hero(2).get("hp") == 30 and party.get_hero(3).get("hp") == 26
		and enemies.get_enemies() == foes_before,
		"authored Needle attack 9 absorbs four Block then deals exactly five HP")

	# Spool: authored shove +1 from the living front hero into the middle slot.
	fixture = _v3_2_fixture(records)
	party = fixture["party"]
	enemies = fixture["enemies"]
	beat = _authored_beat(spool, 2, "shove", 1)
	if beat.is_empty():
		return
	_check(beat.get("amount") == 0 and beat.get("direction") == 1,
		"authenticated Spool alternative is an authored shove +1")
	_check(party.get_hero(1).get("id") == "warden"
		and party.get_hero(2).get("id") == "seamstress"
		and party.get_hero(1).get("hp") == 40 and party.get_hero(2).get("hp") == 30,
		"shove precondition: distinct living front and middle heroes")
	_check(party.apply_damage(1, 4) and party.gain_block(1, 2)
		and party.apply_damage(2, 3) and party.gain_block(2, 1),
		"shove precondition: distinct current HP and Block on both heroes")
	heroes_before = party.get_heroes()
	foes_before = enemies.get_enemies()
	input = [beat.duplicate(true)]
	input_before = input.duplicate(true)
	result = CombatEnemyPhase.new().execute_phase(party, enemies, input)
	_check(result == {"ok": true, "events": [_phase_event(beat)]},
		"authored Spool shove +1 from slot 2 resolves as one applied beat")
	var expected: Array = heroes_before.duplicate(true)
	expected[0] = heroes_before[1].duplicate(true)
	expected[1] = heroes_before[0].duplicate(true)
	expected[0]["position"] = 1
	expected[1]["position"] = 2
	_check(party.get_heroes() == expected,
		"shove +1 exchanges the living front and middle heroes only")
	_check(party.get_hero(1).get("id") == "seamstress"
		and party.get_hero(2).get("id") == "warden"
		and party.get_hero(1).get("hp") == heroes_before[1]["hp"]
		and party.get_hero(2).get("hp") == heroes_before[0]["hp"]
		and party.get_hero(1).get("block") == heroes_before[1]["block"]
		and party.get_hero(2).get("block") == heroes_before[0]["block"],
		"swapped heroes keep their identity, current HP and Block")
	_check(enemies.get_enemies() == foes_before and input == input_before,
		"a shove is not a damaging move and leaves the input untouched")

	# Spool: authored Weak 2 on the living front hero.
	fixture = _v3_2_fixture(records)
	party = fixture["party"]
	enemies = fixture["enemies"]
	beat = _authored_beat(spool, 2, "debuff", 1)
	if beat.is_empty():
		return
	_check(beat.get("status") == "weak" and beat.get("amount") == 2,
		"authenticated Spool alternative is authored Weak 2")
	heroes_before = party.get_heroes()
	foes_before = enemies.get_enemies()
	result = CombatEnemyPhase.new().execute_phase(party, enemies, [beat.duplicate(true)])
	_check(result == {"ok": true, "events": [_phase_event(beat)]}
		and party.get_hero(1).get("statuses") == {"weak": 2}
		and party.get_hero(1).get("hp") == heroes_before[0]["hp"]
		and party.get_hero(2).get("statuses", {}).is_empty()
		and party.get_hero(3).get("statuses", {}).is_empty()
		and enemies.get_enemies() == foes_before,
		"authored Weak 2 lands twice on exactly the living front hero")

	# Spool: authored Attack 8 into the front hero who holds three Block.
	fixture = _v3_2_fixture(records)
	party = fixture["party"]
	enemies = fixture["enemies"]
	beat = _authored_beat(spool, 2, "attack", 1)
	if beat.is_empty():
		return
	_check(beat.get("amount") == 8 and party.gain_block(1, 3)
		and party.get_hero(1).get("hp") == 40,
		"authenticated Spool attack is 8 against a living three-Block front hero")
	foes_before = enemies.get_enemies()
	result = CombatEnemyPhase.new().execute_phase(party, enemies, [beat.duplicate(true)])
	after = party.get_hero(1)
	_check(result == {"ok": true, "events": [_phase_event(beat)]}
		and after.get("block") == 0 and after.get("hp") == 35
		and party.get_hero(2).get("hp") == 30 and party.get_hero(3).get("hp") == 26
		and enemies.get_enemies() == foes_before,
		"authored Spool attack 8 absorbs three Block then deals exactly five HP")


## The real phase engine's existing dead-neighbour and malformed-beat behaviour
## for the V3-2 pair: no forced move, no partial mutation, no RNG spend.
func _test_v3_2_phase_rejections(records: Dictionary) -> void:
	var run_rng := _rng(91807)
	var run_state: int = run_rng.state
	var spool: Dictionary = records["spool_snarekeeper"]

	# A genuinely downed shove partner: the middle hero is at zero HP.
	var fixture := _v3_2_fixture(records)
	var party: CombatParty = fixture["party"]
	var enemies: CombatEnemies = fixture["enemies"]
	var shove := _authored_beat(spool, 2, "shove", 1)
	if shove.is_empty():
		return
	_check(party.apply_damage(2, 30) and party.is_downed(2)
		and not party.is_downed(1),
		"dead-neighbour precondition: only the middle hero is downed")
	_reject_beat("V3-2 shove +1 into a downed neighbour", party, enemies, shove)

	# The same announcement through the bound live path stays inert instead of
	# forcing an illegal exchange.
	fixture = _v3_2_fixture(records)
	party = fixture["party"]
	enemies = fixture["enemies"]
	_check(party.apply_damage(2, 30) and party.is_downed(2)
		and not party.is_downed(1),
		"bound dead-neighbour precondition: only the middle hero is downed")
	_check(CombatEnemyIntents.policy_for(enemies, 2) == "front",
		"authentic Spool slot carries the front policy for the bound path")
	var heroes_before := party.get_heroes()
	var foes_before := enemies.get_enemies()
	var input := [shove.duplicate(true)]
	var input_before := input.duplicate(true)
	var inert: Dictionary = CombatEnemyPhase.new().execute_phase(
		party, enemies, input, null, true)
	var skipped := _phase_event(shove)
	skipped["applied"] = false
	_check(inert == {"ok": true, "events": [skipped]}
		and party.get_heroes() == heroes_before
		and enemies.get_enemies() == foes_before and input == input_before,
		"a dead shove neighbour is skipped without a fake forced move")

	# Malformed target, source and direction fail closed and mutate nothing.
	fixture = _v3_2_fixture(records)
	party = fixture["party"]
	enemies = fixture["enemies"]
	_check(party.gain_block(1, 5) and enemies.gain_block(2, 3),
		"malformed-beat precondition: real hero and enemy Block survive")
	var bad_target := shove.duplicate(true)
	bad_target["target_position"] = 0
	_reject_beat("V3-2 shove target outside the party", party, enemies, bad_target)
	var bad_source := _authored_beat(records["needle_briar_guard"], 3, "attack", 1)
	_reject_beat("V3-2 announced source outside the roster", party, enemies, bad_source)
	var bad_direction := shove.duplicate(true)
	bad_direction["direction"] = 2
	_reject_beat("V3-2 shove direction outside the authored pair", party, enemies,
		bad_direction)
	_check(run_rng.state == run_state,
		"rejected V3-2 beats leave the run RNG state untouched")


## V3-2: exact authored content, seeded authentic announcements and each
## authored beat, with every earlier Elite record still intact by ID.
func _test_v3_2_elites() -> void:
	seed(62117)
	var expected_rng := randi()
	seed(62117)
	var elites := _catalog(ELITES)
	var untouched := elites.duplicate(true)
	var records := {}
	for id in V3_2_ELITES:
		records[id] = _authored_elite(elites, id, V3_2_ELITES[id])
	for id in LEGACY_ELITES:
		_authored_elite(elites, id, LEGACY_ELITES[id])
	for id in V3_ELITES:
		_authored_elite(elites, id, V3_ELITES[id])
	_check(records["needle_briar_guard"].get("id") == "needle_briar_guard"
		and records["spool_snarekeeper"].get("id") == "spool_snarekeeper"
		and records["needle_briar_guard"].get("id")
			!= records["spool_snarekeeper"].get("id"),
		"both V3-2 Elite IDs exist exactly once each and are distinct")
	_check(records["needle_briar_guard"].get("intent")
		!= records["spool_snarekeeper"].get("intent"),
		"the two V3-2 elites author distinct weighted alternatives")
	_test_v3_2_announcements(records)
	_test_v3_2_beats(records)
	_test_v3_2_phase_rejections(records)
	_check(elites == untouched and RunTypedBattleRoster._parse_catalog_text(
		FileAccess.get_file_as_string(ELITES)) == untouched,
		"V3-2 checks never mutate the authored elite records")
	_check(randi() == expected_rng,
		"V3-2 catalog lookups, bound announcements and beats use no global RNG")


## Independent weighted-draw oracle: both policies are deterministic and spend
## exactly one draw per announcement, with no target-selection draw.
func _keyword_trace(record: Dictionary) -> Array:
	var fixture := _new_elite_fixture(record)
	var party: CombatParty = fixture["party"]
	var enemies: CombatEnemies = fixture["enemies"]
	_check(party.apply_damage(2, 20) and party.get_hero(2).get("hp") == 10,
		"middle hero is uniquely lowest living HP")
	var rng := _rng(27701)
	var oracle := _rng(27701)
	var scheduler := CombatEnemyIntents.new([
		{"enemy_position": 1, "pattern": [{"type": "block", "amount": 1}]}])
	_check(scheduler.is_valid() and scheduler.bind_battle(enemies, party, rng)
		and scheduler.is_bound(), "authentic keyword elite binds weighted scheduler")
	if not scheduler.is_bound():
		return []
	var spec: Dictionary = KEYWORD_ELITES[record["id"]]
	var total := 0
	for action in spec["actions"]:
		total += action["weight"]
	var trace: Array = []
	var seen := {}
	for turn in range(24):
		var roll := oracle.randi_range(1, total)
		var expected: Dictionary = {}
		for action in spec["actions"]:
			roll -= action["weight"]
			if roll <= 0:
				expected = action.duplicate(true)
				break
		expected.erase("weight")
		expected["enemy_position"] = 1
		if expected["type"] != "block":
			expected["target_position"] = 1 if spec["target"] == "front" else 2
		var announced := scheduler.get_intents()
		_check(announced == [expected] and rng.state == oracle.state,
			"exact weighted alternative, policy target and RNG at turn " + str(turn))
		_check(scheduler.get_intents() == announced and rng.state == oracle.state,
			"cached reads consume no RNG")
		seen[expected["type"]] = true
		trace.append([announced, rng.state])
		if turn < 23:
			_check(scheduler.advance_turn(), "advance bound keyword elite")
	_check(seen.has("attack") and seen.has("debuff") and seen.has("block"),
		"fixed seed exercises all three authored alternatives")
	return trace


func _keyword_beats(record: Dictionary) -> void:
	var is_needle: bool = record["id"] == "pincushion_matriarch"
	var target := 1 if is_needle else 2
	for kind in ["debuff", "block", "attack"]:
		var fixture := _new_elite_fixture(record)
		var party: CombatParty = fixture["party"]
		var enemies: CombatEnemies = fixture["enemies"]
		_check(party.apply_damage(2, 20), "living lowest-HP middle hero for forced beat")
		var beat := _authored_beat(record, 1, kind, target)
		if beat.is_empty():
			return
		var heroes := party.get_heroes()
		var foes := enemies.get_enemies()
		var input := [beat.duplicate(true)]
		var before := input.duplicate(true)
		var result := CombatEnemyPhase.new().execute_phase(party, enemies, input)
		_check(result == {"ok": true, "events": [_phase_event(beat)]}
			and input == before, "forced genuine alternative executes without input mutation")
		match kind:
			"debuff":
				heroes[target - 1]["statuses"] = {"bleed": 2} if is_needle else {"weak": 2}
				_check(party.get_heroes() == heroes and enemies.get_enemies() == foes,
					"exact status 2 only on selected hero, no immediate HP loss")
				if not is_needle:
					_check(CombatStatuses.new().adjusted_attack_damage(8,
						party.get_hero(target)["statuses"], {}) == 6,
						"Leech Weak reduces attacks by 25 percent")
			"block":
				foes[0]["block"] = 9 if is_needle else 6
				_check(enemies.get_enemies() == foes and party.get_heroes() == heroes,
					"exact authored Block on own slot only")
			"attack":
				heroes[target - 1]["hp"] -= 9 if is_needle else 8
				_check(party.get_heroes() == heroes and enemies.get_enemies() == foes,
					"exact authored attack hits policy target; full enemy cannot overheal")


func _pincushion_thorns(record: Dictionary) -> void:
	for damage in [3, 0]:
		for block in [0, 2, 6]:
			var fixture := _new_elite_fixture(record)
			var party: CombatParty = fixture["party"]
			var enemies: CombatEnemies = fixture["enemies"]
			_check(party.gain_block(1, block), "authentic attacker Block precondition")
			var pre_hit := enemies.get_enemy(1)
			var receipt := CombatStatusAttacks.new().resolve_vs_enemy(enemies, 1, damage, {}, {})
			_check(receipt == {"ok": true, "damage": damage, "block_absorbed": 0,
				"hp_loss": damage}, "genuine positive/zero confirmed hero hit receipt")
			var before := party.get_heroes()
			var result := CombatEnemyKeywordRules.new().resolve_thorns_retaliation(
				party, 1, pre_hit, receipt)
			var absorbed := mini(block, 4) if damage > 0 else 0
			var hp_loss := 4 - absorbed if damage > 0 else 0
			_check(result == {"ok": true, "applied": damage > 0, "thorns": 4,
				"block_absorbed": absorbed, "hp_loss": hp_loss},
				"Thorns 4 exact receipt through Block; zero hit inert")
			before[0]["block"] -= absorbed
			before[0]["hp"] -= hp_loss
			_check(party.get_heroes() == before and enemies.get_enemy(1)["hp"] == 44 - damage,
				"retaliation changes only attacking hero, after genuine enemy HP loss")


func _leech_drain(record: Dictionary) -> void:
	# Missing HP, hero Block, hero HP, expected HP removed, expected healing.
	for scenario in [[12, 0, 10, 8, 8], [12, 3, 10, 5, 5],
			[12, 8, 10, 0, 0], [2, 0, 10, 8, 2], [12, 0, 3, 3, 3]]:
		var fixture := _new_elite_fixture(record)
		var party: CombatParty = fixture["party"]
		var enemies: CombatEnemies = fixture["enemies"]
		_check(enemies.apply_damage(1, scenario[0]) and party.apply_damage(2, 30 - scenario[2])
			and party.gain_block(2, scenario[1]) and not party.is_downed(2)
			and enemies.get_enemy(1)["hp"] == 42 - scenario[0],
			"genuinely wounded Leech and living lowest-HP blocked hero")
		var heroes := party.get_heroes()
		var foes := enemies.get_enemies()
		var beat := _authored_beat(record, 1, "attack", 2)
		var result := CombatEnemyPhase.new().execute_phase(party, enemies, [beat])
		heroes[1]["block"] = maxi(0, scenario[1] - 8)
		heroes[1]["hp"] -= scenario[3]
		foes[0]["hp"] += scenario[4]
		_check(result == {"ok": true, "events": [_phase_event(beat)]}
			and party.get_heroes() == heroes and enemies.get_enemies() == foes,
			"phase Attack 8 drains actual HP only, fully blocked zero, capped at 42: " + str(scenario))


func _test_keyword_elites() -> void:
	var catalog := _catalog(ELITES)
	var untouched := catalog.duplicate(true)
	for id in KEYWORD_ELITES:
		var expected: Dictionary = KEYWORD_ELITES[id]
		var record := _authored_elite(catalog, id, expected)
		if record.is_empty():
			continue
		var exact := expected.duplicate(true)
		exact["id"] = id
		exact["intent"] = {"target": exact["target"], "actions": exact["actions"]}
		exact.erase("target")
		exact.erase("actions")
		_check(record.size() == exact.size(), "exact authored record fields " + id)
		for field in exact:
			if field != "intent":
				_check(record.get(field) == exact[field]
					and typeof(record.get(field)) == typeof(exact[field]),
					"exact typed field including keyword metadata " + id + "/" + field)
		var first := _keyword_trace(record)
		_check(first.size() == 24 and first == _keyword_trace(record),
			"complete fixed-seed keyword elite replay " + id)
		_keyword_beats(record)
		if id == "pincushion_matriarch":
			_pincushion_thorns(record)
		else:
			_leech_drain(record)
	# Earlier tests validate every field of all six earlier identities by ID.
	_check(catalog == untouched and _catalog(ELITES) == untouched,
		"keyword elite tests preserve the real catalog and parsed inputs")
