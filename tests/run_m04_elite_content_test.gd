extends SceneTree

var failures: Array[String] = []

var checks := 0

class MissingMoveArt extends LiveMovePoseCatalog:
	func _art_available(_path: String) -> bool:
		return false

const ELITES := "res://data/enemies/m04_elites.json"
const STARTER := "res://data/enemies/starter_enemies.json"
const RUN := "res://data/enemies/run_enemies.json"
const HEROES := "res://data/heroes/starter_party.json"
const MARSHAL := "res://data/encounters/needle_marshal_elite.json"
const HEXER := "res://data/encounters/spool_hexer_elite.json"
const ROSTERS := {
	"needle_marshal_elite": ["needle_marshal", "ragling_guard"],
	"spool_hexer_elite": ["spool_hexer", "spool_stalker"]}
## The ragling escort's authored self Block, proven by AC1 below.
const ESCORT_BLOCK := 5
## V3-2 appends two harder look-driven elites. Their authored alternatives are
## checked by ID only, never by catalog total or position.
const V3_ELITES := {
	## The Bailiff's shears shear through the recipient's whole Block before its
	## own nine-point cut lands (`chew_block_on_attack`), then the confirmed-hit
	## sting adds one Bleed. Both flags are real booleans on the shipped record,
	## checked by ID in _test_scissor_sting.
	"scissor_bailiff": {
		"name": "Scissor Bailiff", "max_hp": 36,
		"art_path": "res://assets/paper/enemies/scissor_bailiff.png",
		"target": "front",
		"actions": [
			{"type": "snip_block", "amount": 0, "weight": 2},
			{"type": "debuff", "amount": 2, "status": "bleed", "weight": 2},
			{"type": "attack", "amount": 9, "weight": 2},
			{"type": "attack", "amount": 8, "hits": 2, "move": "attack2", "weight": 1},
			{"type": "attack", "amount": 7, "move": "attack3", "weight": 1}]},
	## The Zipper Hauler looks like a hook: its shove is a forward pull (direction
	## -1) that yanks the living middle hero in front of its partner.
	"zipper_hauler": {
		"name": "Zipper Hauler", "max_hp": 38,
		"art_path": "res://assets/paper/enemies/zipper_hauler.png",
		"target": "front",
		"actions": [
			{"type": "shove", "amount": 0, "direction": -1, "weight": 2},
			{"type": "debuff", "amount": 1, "status": "exposed", "weight": 2},
			{"type": "attack", "amount": 8, "weight": 2},
			{"type": "attack", "amount": 10, "move": "attack2", "weight": 1},
			{"type": "attack", "amount": 6, "hits": 2, "move": "attack3", "weight": 1}]}}
## The two earlier Elite records must survive the append unchanged.
const LEGACY_ELITES := {
	"needle_marshal": {
		"name": "Needle Marshal", "max_hp": 28, "thorns": 3,
		"art_path": "res://assets/paper/enemies/needle_marshal.png",
		"target": "front",
		"actions": [
			{"type": "attack", "amount": 5, "weight": 2},
			{"type": "attack", "amount": 4, "move": "attack2", "weight": 1},
			{"type": "attack", "amount": 6, "move": "attack3", "weight": 1},
			{"type": "buff", "amount": 3, "weight": 1},
			{"type": "shove", "amount": 0, "direction": 1, "weight": 1}]},
	"spool_hexer": {
		"name": "Spool Hexer", "max_hp": 24,
		"art_path": "res://assets/paper/enemies/spool_hexer.png",
		"target": "random",
		"actions": [
			{"type": "attack", "amount": 9, "weight": 1},
			{"type": "attack", "amount": 8, "move": "attack2", "weight": 1},
			{"type": "attack", "amount": 10, "move": "attack3", "weight": 1},
			{"type": "debuff", "amount": 1, "status": "exposed", "weight": 1},
			{"type": "debuff", "amount": 1, "status": "weak", "weight": 1}]}}
## V3-2 appends two further harder Elites that reuse existing needle and spool
## puppets. They are authored content only: no encounter or floor-band pool
## binds them yet, so these checks read them by ID from the catalog itself.
## The Guard's prickly needle silhouette now authors Thorns 3 ("attacker takes
## N per hit"), proven against the real confirmed-hit retaliation service.
const V3_2_ELITES := {
	"needle_briar_guard": {
		"name": "Needle Briar Guard", "max_hp": 42, "thorns": 3,
		"art_path": "res://assets/paper/enemies/needle_briar_guard.png",
		"target": "front",
		"actions": [
			{"type": "debuff", "amount": 2, "status": "bleed", "weight": 2},
			{"type": "block", "amount": 8, "weight": 2},
			{"type": "attack", "amount": 9, "weight": 3}]},
	"spool_snarekeeper": {
		"name": "Spool Snarekeeper", "max_hp": 40,
		"art_path": "res://assets/paper/enemies/spool_snarekeeper.png",
		"target": "front",
		"actions": [
			{"type": "shove", "amount": 0, "direction": 1, "weight": 2},
			{"type": "debuff", "amount": 2, "status": "weak", "weight": 2},
			{"type": "attack", "amount": 8, "weight": 3}]}}
## Authored slot order for the two-record V3-2 roster fixtures.
const V3_2_ORDER := ["needle_briar_guard", "spool_snarekeeper"]
## Synthetic typed-encounter key used only to drive the production roster
## assembler: the actors themselves come from the shipped catalog files, never
## from a test-injected record. No shipped encounter routes this pair yet.
const BRIAR_PROBE := "needle_briar_guard_thorns_probe"
const BRIAR_PROBE_ROSTER := ["needle_briar_guard", "spool_snarekeeper"]
## The new unregistered Elite script. Every check below reaches it through one
## local candidate and production selection; no shipped pool entry is claimed.
const BRIAR_SNARE := "res://data/encounters/briar_snare_elite.json"
const BRIAR_SNARE_ID := "briar_snare_elite"
const BRIAR_SNARE_ROSTER := {
	"briar_snare_elite": ["needle_briar_guard", "spool_snarekeeper"]}
const BRIAR_SNARE_PATTERNS := [
	{"enemy_position": 1, "pattern": [
		{"type": "attack", "amount": 9, "target_position": 1},
		{"type": "debuff", "amount": 2, "status": "bleed", "target_position": 1},
		{"type": "block", "amount": 8}]},
	{"enemy_position": 2, "pattern": [
		{"type": "shove", "amount": 0, "target_position": 2, "direction": 1},
		{"type": "debuff", "amount": 2, "status": "weak", "target_position": 3},
		{"type": "attack", "amount": 8, "target_position": 2}]}]
const KEYWORD_ELITES := {
	"pincushion_matriarch": {
		"name": "Pincushion Matriarch", "max_hp": 44, "thorns": 4,
		"art_path": "res://assets/paper/enemies/pincushion_matriarch.png",
		"target": "front", "actions": [
			{"type": "attack", "amount": 9, "weight": 3},
			{"type": "debuff", "status": "bleed", "amount": 2, "weight": 2},
			{"type": "block", "amount": 9, "weight": 2}]},
	"spool_leech": {
		"name": "Spool Leech", "max_hp": 42, "drain": true, "chew_block_on_attack": true,
		"art_path": "res://assets/paper/enemies/spool_leech.png",
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
	_test_marshal_named_attacks()
	_test_marshal_sting()
	_test_scissor_sting()
	_test_bailiff_named_attacks()
	_test_hexer_lash()
	_test_hexer_named_attacks()
	_test_v3_elites()
	_test_zipper_pull_rng()
	_test_v3_2_elites()
	_test_briar_guard_thorns(_catalog(ELITES))
	_test_briar_snare_schedule()
	_test_briar_snare_live_registry()
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
				# The Marshal's authored 4 lands on the living slot-2 hero, which
				# holds no Block here, so the confirmed-hit sting adds exactly one
				# Bleed alongside the original HP loss.
				heroes[1]["hp"] -= 4
				var stung: Dictionary = heroes[1].get("statuses", {})
				stung["bleed"] = stung.get("bleed", 0) + 1
				heroes[1]["statuses"] = stung
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
			{"type": "attack", "amount": 4, "move": "attack2", "weight": 1},
			{"type": "attack", "amount": 6, "move": "attack3", "weight": 1},
			{"type": "buff", "amount": 3, "weight": 1},
			{"type": "shove", "amount": 0, "direction": 1, "weight": 1}]},
		"spool_hexer": {"target": "random", "actions": [
			{"type": "attack", "amount": 9, "weight": 1},
			{"type": "attack", "amount": 8, "move": "attack2", "weight": 1},
			{"type": "attack", "amount": 10, "move": "attack3", "weight": 1},
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
		var original_attacks := [4, 3, 3] if source_id == "needle_marshal" else [3, 3, 3]
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
				and attack.get("amount") in ([5, 4, 6] if source_id == "needle_marshal" else [9, 8, 10])
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


## Discover witnesses through the shipped typed pool and its untouched roster.
## No forced alternatives: selection and binding use the run's single RNG.
func _test_marshal_named_attacks() -> void:
	var witnesses := {}
	for attempt in range(1, 2001):
		var route := _elite_route(attempt)
		if route.is_empty():
			continue
		var entry := RunAuthoredBattleEntry.new().entry_current_battle(
			route.map, route.rng, RunFightEncounterSelection.new())
		if not entry.get("success", false) or entry.get("encounter_id") != "needle_marshal_elite":
			continue
		var party := _party()
		if not entry.intents.bind_battle(entry.enemies, party, route.rng):
			continue
		var actions: Array = entry.intents.get_intents()
		if actions.size() == 2 and actions[0].type == "attack" and actions[1].type == "block":
			witnesses[actions[0].get("move", "attack")] = attempt
		if witnesses.has("attack") and witnesses.has("attack2") and witnesses.has("attack3"):
			break
	var specs := {"attack": [5, "Needle Jab"], "attack2": [4, "Pike Charge"],
		"attack3": [6, "Needle Volley"]}
	for pose in specs:
		_check(witnesses.has(pose), "real seeded typed Marshal witness exists: " + pose)
		if not witnesses.has(pose):
			continue
		print("Marshal ", pose, " witness seed: ", witnesses[pose])
		var history: Array = []
		for mode in ["partial", "blocked", "enraged", "dead"]:
			for replay in range(2):
				var route := _elite_route(witnesses[pose])
				_check(not route.is_empty(), "replay has a real legal Elite route")
				if route.is_empty():
					continue
				var entry := RunAuthoredBattleEntry.new().entry_current_battle(
					route.map, route.rng, RunFightEncounterSelection.new())
				_check(entry.get("success", false) and entry.get("node_type") == "Elite"
					and entry.get("encounter_id") == "needle_marshal_elite",
					"replay enters genuine typed Marshal battle")
				if not entry.get("success", false):
					continue
				var enemies: CombatEnemies = entry.enemies
				var party := _party()
				var bound: CombatEnemyIntents = entry.intents
				_check(enemies.is_valid() and enemies.get_enemy(1).id == "needle_marshal"
					and enemies.get_enemy(2).id == "ragling_guard"
					and CombatEnemyIntents._weighted_slot(1, enemies.get_enemy(1).intent)
						== CombatEnemyIntents._weighted_slot(1, {
							"target": "front", "actions": LEGACY_ELITES.needle_marshal.actions}),
					"typed entry preserves authentic Marshal policy and escort")
				_check(bound.bind_battle(enemies, party, route.rng), "real weighted binding succeeds")
				var announced := bound.get_intents()
				_check(announced.size() == 2, "two real cached source announcements")
				if announced.size() != 2:
					continue
				var attack := announced[0]
				var expected := {"type": "attack", "amount": specs[pose][0],
					"enemy_position": 1, "target_position": 1}
				if pose != "attack":
					expected["move"] = pose
				_check(attack == expected and announced[1] == {
					"type": "block", "amount": ESCORT_BLOCK, "enemy_position": 2},
					"exact authentic amount/move, front target and escort Block")
				var rng_before: int = route.rng.state
				var catalog := LiveMovePoseCatalog.new()
				var fallback := "res://assets/paper/enemies/needle_marshal_attack.png"
				var receipt := catalog.lookup_enemy("needle_marshal", attack, fallback)
				var named_art: String = "res://assets/paper/enemies/needle_marshal_%s.png" % pose
				_check(receipt.get("name") == specs[pose][1] and receipt.get("pose") == pose
					and receipt.get("covers") == ["attack"] and receipt.get("named_art") == named_art
					and receipt.get("art_available") == ResourceLoader.exists(named_art, "Texture2D")
					and receipt.get("art") == (named_art if receipt.get("art_available") else fallback),
					"real move catalog returns exact name, pose and checked art")
				_check(MissingMoveArt.new().lookup_enemy("needle_marshal", attack, fallback) == {
					"name": specs[pose][1], "pose": pose, "covers": ["attack"],
					"named_art": named_art, "art": fallback, "art_available": false, "fallback_used": true},
					"unavailable art preserves authored identity and established fallback")
				receipt["name"] = "forged"
				_check(catalog.lookup_enemy("needle_marshal", attack, fallback).get("name") == specs[pose][1]
					and bound.get_intents() == announced and route.rng.state == rng_before,
					"cached announcements and detached name receipts consume no RNG")
				var bonus := 0
				if mode == "enraged":
					var pre := enemies.get_enemy(1)
					var hit := CombatStatusAttacks.new().resolve_vs_enemy(enemies, 1, 1, {}, {})
					_check(hit.get("ok", false) and hit.get("hp_loss") == 1
						and CombatEnemyKeywordRules.new().commit_enrage_after_hit(enemies, 1, pre, hit) == {
							"ok": true, "applied": true, "enrage_stacks": 1, "attack_bonus": 2},
						"real confirmed hit commits existing Enrage +2")
					bonus = 2
				if mode == "dead":
					_check(enemies.apply_damage(1, 28) and enemies.is_slain(1), "source genuinely dies after announcement")
				var block: int = specs[pose][0] if mode == "blocked" else 2
				_check(party.gain_block(1, block), "real Block precondition")
				var before := [party.get_heroes(), enemies.get_enemies(), route.rng.state, bound.get_intents()]
				# Every forgery is rejected before wallet publication or actor mutation.
				var forgeries: Array = []
				for field in ["move", "amount", "enemy_position"]:
					var forged := attack.duplicate(true)
					forged[field] = "attack4" if field == "move" else (99 if field == "amount" else 2)
					if field == "enemy_position":
						forged["move"] = "attack2"
					forgeries.append(forged)
				var mismatched := attack.duplicate(true)
				mismatched["move"] = "attack3" if pose != "attack3" else "attack2"
				forgeries.append(mismatched)
				for forged in forgeries:
					_check(CombatEnemyPhase.new().execute_phase(party, enemies, [forged], null, true, null, 73)
						== {"ok": false, "events": []}
						and before == [party.get_heroes(), enemies.get_enemies(), route.rng.state, bound.get_intents()],
						"forged move/source/amount publishes no effects, wallet or RNG changes")
				# Remove this exact alternative from the current source: old keyed AND
				# unkeyed receipts must fail authentication against stale source data.
				var original_spec: Dictionary = enemies._enemies[0].intent.duplicate(true)
				enemies._enemies[0].intent.actions = original_spec.actions.filter(
					func(a: Dictionary) -> bool: return int(a.amount) != specs[pose][0])
				var stale_before := enemies.get_enemies()
				_check(CombatEnemyPhase.new().execute_phase(party, enemies, [attack], null, true, null, 73)
					== {"ok": false, "events": []} and enemies.get_enemies() == stale_before
					and party.get_heroes() == before[0] and route.rng.state == rng_before,
					"stale source alternative fails closed without partial effects")
				enemies._enemies[0].intent = original_spec
				var settled := CombatEnemyPhase.new().execute_phase(party, enemies, announced, null, true, null, 73)
				var event := _event(attack)
				event["applied"] = mode != "dead"
				var damage: int = 0 if mode == "dead" else specs[pose][0] + bonus
				var loss := maxi(0, damage - block)
				_check(settled == {"ok": true, "events": [event, _event(announced[1])], "gold": 73}
					and party.get_hero(1).hp == 40 - loss and party.get_hero(1).block == maxi(0, block - damage)
					and party.get_hero(1).get("statuses", {}) == ({"bleed": 1} if loss > 0 else {})
					and party.get_hero(2) == before[0][1] and party.get_hero(3) == before[0][2]
					and enemies.get_enemy(2).block == ESCORT_BLOCK
					and enemies.get_enemy(1) == before[1][0] and route.rng.state == rng_before,
					"exact named phase events, Block/HP/confirmed Bleed, Enrage, escort and wallet")
				var trace := [announced, settled, party.get_heroes(), enemies.get_enemies(), route.rng.state]
				if replay == 0:
					history = trace
				else:
					_check(history == trace, "same-seed full attack/effect/RNG replay: " + pose + "/" + mode)


## Real routed Hexer witnesses use the untouched weighted catalog and escort.
func _test_hexer_named_attacks() -> void:
	var witnesses := {}
	var targets := {}
	for attempt in range(1, 2001):
		var route := _elite_route(attempt)
		if route.is_empty():
			continue
		var entry := RunAuthoredBattleEntry.new().entry_current_battle(
			route.map, route.rng, RunFightEncounterSelection.new())
		if not entry.get("success", false) or entry.get("encounter_id") != "spool_hexer_elite":
			continue
		var party := _party()
		if not entry.intents.bind_battle(entry.enemies, party, route.rng):
			continue
		var actions: Array = entry.intents.get_intents()
		if actions.size() == 2 and actions[0].type == "attack" and actions[1].type == "block":
			witnesses[actions[0].get("move", "attack")] = attempt
			targets[actions[0].target_position] = true
		if witnesses.has("attack") and witnesses.has("attack2") and witnesses.has("attack3") \
				and targets.has(1) and targets.has(2) and targets.has(3):
			break
	_check(targets.has(1) and targets.has(2) and targets.has(3),
		"real Hexer random policy reaches every living hero within bounded seeds")
	var specs := {"attack": [9, "Spool Lash"], "attack2": [8, "Hex Bolt"],
		"attack3": [10, "Spindle Jab"]}
	for pose in specs:
		_check(witnesses.has(pose), "real typed Hexer attack seed exists: " + pose)
		if not witnesses.has(pose):
			continue
		print("Hexer ", pose, " witness seed: ", witnesses[pose])
		for mode in ["partial", "blocked", "exposed", "dead"]:
			var history: Array = []
			for replay in range(2):
				var route := _elite_route(witnesses[pose])
				_check(not route.is_empty(), "Hexer replay has genuine legal Elite route")
				if route.is_empty():
					continue
				var entry := RunAuthoredBattleEntry.new().entry_current_battle(
					route.map, route.rng, RunFightEncounterSelection.new())
				_check(entry.get("success", false) and entry.get("node_type") == "Elite"
					and entry.get("encounter_id") == "spool_hexer_elite", "real typed Hexer entry")
				if not entry.get("success", false):
					continue
				var party := _party()
				var enemies: CombatEnemies = entry.enemies
				var bound: CombatEnemyIntents = entry.intents
				_check(enemies.is_valid() and enemies.get_enemies().size() == 2
					and enemies.get_enemy(1).id == "spool_hexer" and enemies.get_enemy(1).max_hp == 24
					and enemies.get_enemy(1).intent == _record(_catalog(ELITES), "spool_hexer").intent
					and enemies.get_enemy(2).id == "spool_stalker"
					and enemies.get_enemy(2).intent == _record(_catalog(RUN), "spool_stalker").intent,
					"genuine typed roster keeps exact Hexer policy, weights and unchanged escort")
				# Independently account for weighted choice, random living target and escort choice.
				var expected_rng := _rng(1)
				expected_rng.state = route.rng.state
				var roll := expected_rng.randi_range(1, 5)
				var expected_target := expected_rng.randi_range(0, 2) + 1
				var escort_roll := expected_rng.randi_range(1, 8)
				_check(bound.bind_battle(enemies, party, route.rng) and bound.is_bound(),
					"real Hexer weighted cache binds successfully")
				var announced := bound.get_intents()
				_check(announced.size() == 2, "two nonempty real Hexer announcements")
				if announced.size() != 2:
					continue
				var attack := announced[0]
				var target: int = attack.get("target_position", 0)
				var expected := {"type": "attack", "amount": specs[pose][0],
					"enemy_position": 1, "target_position": expected_target}
				if pose != "attack":
					expected["move"] = pose
				_check(attack == expected and roll == ["attack", "attack2", "attack3"].find(pose) + 1
					and escort_roll in [4, 5] and announced[1] == {
						"type": "block", "amount": 2, "enemy_position": 2}
					and route.rng.state == expected_rng.state and target in [1, 2, 3]
					and not party.is_downed(target), "exact weighted variant, living random target and RNG draw count")
				if target not in [1, 2, 3]:
					continue
				var rng_before: int = route.rng.state
				var catalog := LiveMovePoseCatalog.new()
				var fallback := "res://assets/paper/enemies/spool_hexer_attack.png"
				var named_art := "res://assets/paper/enemies/spool_hexer_%s.png" % pose
				var receipt := catalog.lookup_enemy("spool_hexer", attack, fallback)
				_check(receipt.get("name") == specs[pose][1] and receipt.get("pose") == pose
					and receipt.get("covers") == ["attack"] and receipt.get("named_art") == named_art
					and receipt.get("art_available") == ResourceLoader.exists(named_art, "Texture2D")
					and receipt.get("art") == (named_art if receipt.get("art_available") else fallback),
					"Hexer catalog returns exact cached move name and authored art path")
				_check(MissingMoveArt.new().lookup_enemy("spool_hexer", attack, fallback) == {
					"name": specs[pose][1], "pose": pose, "covers": ["attack"], "named_art": named_art,
					"art": fallback, "art_available": false, "fallback_used": true}, "Hexer missing art fallback retains name")
				receipt["name"] = "forged"
				_check(catalog.lookup_enemy("spool_hexer", attack, fallback).get("name") == specs[pose][1]
					and bound.get_intents() == announced and route.rng.state == rng_before,
					"detached name receipts and cached reads spend no RNG")
				var damage: int = specs[pose][0]
				if mode == "exposed":
					party._heroes[target - 1]["statuses"] = {"exposed": 1}
					damage = int(damage * 1.5)
				if mode == "dead":
					_check(enemies.apply_damage(1, 24) and enemies.is_slain(1), "Hexer source genuinely dies after caching")
					damage = 0
				var block: int = specs[pose][0] if mode == "blocked" else 2
				_check(party.gain_block(target, block), "chosen living hero really gains Block")
				var before := [party.get_heroes(), enemies.get_enemies(), route.rng.state, bound.get_intents()]
				var forgeries: Array = []
				for field in ["move", "amount", "enemy_position", "target_position"]:
					var values: Array = {"move": ["attack4", "skill", 2, "attack3" if pose != "attack3" else "attack2"],
						"amount": [99, 8 if pose != "attack2" else 9], "enemy_position": [0, 2, 3, "1"],
						"target_position": [0, 4, "1"]}[field]
					for value in values:
						var forged := attack.duplicate(true)
						forged[field] = value
						forgeries.append(forged)
				for forged in forgeries:
					# Preserve the full cached phase: a forged source cannot impersonate
					# the escort's already-announced slot, even on the unkeyed lash.
					_check(CombatEnemyPhase.new().execute_phase(party, enemies, [forged, announced[1]], null, true, null, 73)
						== {"ok": false, "events": []}
						and before == [party.get_heroes(), enemies.get_enemies(), route.rng.state, bound.get_intents()],
						"wrong move/amount/source/target rejects without actors, statuses, wallet or RNG publication: " + str(forged) + "/" + mode)
				var malformed := attack.duplicate(true)
				malformed["move"] = "attack4"
				_check(CombatEnemyPhase.new().execute_phase(party, enemies,
					[announced[1], malformed], null, true, null, 73) == {"ok": false, "events": []}
					and before == [party.get_heroes(), enemies.get_enemies(), route.rng.state, bound.get_intents()],
					"invalid later attack rolls back the valid escort Block too")
				var original_spec: Dictionary = enemies._enemies[0].intent.duplicate(true)
				enemies._enemies[0].intent.actions = original_spec.actions.filter(
					func(a: Dictionary) -> bool: return int(a.amount) != specs[pose][0])
				var stale_before := enemies.get_enemies()
				_check(CombatEnemyPhase.new().execute_phase(party, enemies,
					[announced[1], attack], null, true, null, 73) == {"ok": false, "events": []}
					and enemies.get_enemies() == stale_before and party.get_heroes() == before[0]
					and route.rng.state == rng_before and bound.get_intents() == announced,
					"stale keyed and unkeyed source alternatives reject atomically without RNG")
				enemies._enemies[0].intent = original_spec
				var settled := CombatEnemyPhase.new().execute_phase(party, enemies, announced, null, true, null, 73)
				var event := _event(attack)
				event["applied"] = mode != "dead"
				var expected_heroes: Array = before[0].duplicate(true)
				expected_heroes[target - 1].block = maxi(0, block - damage)
				expected_heroes[target - 1].hp -= maxi(0, damage - block)
				var expected_enemies: Array = before[1].duplicate(true)
				expected_enemies[1].block = 2
				_check(settled == {"ok": true, "events": [event, _event(announced[1])], "gold": 73}
					and party.get_heroes() == expected_heroes and enemies.get_enemies() == expected_enemies
					and bound.get_intents() == announced and route.rng.state == rng_before,
					"exact once-only named phase, Block then HP, Exposed, untouched bystanders and wallet")
				var trace := [announced, settled, party.get_heroes(), enemies.get_enemies(), route.rng.state]
				if replay == 0:
					history = trace
				else:
					_check(history == trace, "same-seed real Hexer action/effect/RNG replay: " + pose + "/" + mode)


## A genuine two-source roster narrowed to one authored Marshal alternative.
func _forced_marshal(alternative: Dictionary, seed_value: int,
		party: CombatParty, stings := true) -> Dictionary:
	var records := _all_catalogs()
	var marshal := _record(records, "needle_marshal")
	var escort := _record(records, "ragling_guard")
	if marshal.is_empty() or escort.is_empty():
		return {}
	var weighted := CombatEnemyIntents.weighted_action(alternative)
	var action: Dictionary = weighted.get("action", {}).duplicate(true)
	_check(not action.is_empty(),
		"forced Marshal alternative is a valid authored action " + str(alternative))
	action["weight"] = 1
	var forced: Dictionary = marshal.duplicate(true)
	forced["intent"] = {"target": "front", "actions": [action]}
	if not stings:
		forced.erase("bleed_on_attack")
	# The escort now authors Block 5, a right shield rush and a real six-point
	# hit. Narrow it to its own authored Block alternative so this sting suite
	# binds a genuine, deterministic non-damaging escort beat instead of
	# assuming the old passive one-Block schedule.
	var escort_intent: Dictionary = escort.get("intent", {}).duplicate(true)
	var escort_block: Dictionary = {}
	for raw in escort_intent.get("actions", []):
		if CombatEnemyIntents.weighted_action(raw).get("action", {}).get("type") == "block":
			escort_block = raw.duplicate(true)
			break
	_check(int(escort_block.get("amount", 0)) == ESCORT_BLOCK,
		"the shipped ragling escort still authors its own five Block alternative")
	if escort_block.is_empty():
		return {}
	escort_intent["actions"] = [escort_block]
	var narrowed: Dictionary = escort.duplicate(true)
	narrowed["intent"] = escort_intent
	var enemies := CombatEnemies.new([forced, narrowed])
	var scheduler := CombatEnemyIntents.new([
		{"enemy_position": 1, "pattern": [{"type": "block", "amount": 1}]},
		{"enemy_position": 2, "pattern": [{"type": "block", "amount": 1}]}])
	var bound: bool = enemies.is_valid() and scheduler.is_valid() \
		and scheduler.bind_battle(enemies, party, _rng(seed_value))
	_check(bound and enemies.get_enemies().size() == 2,
		"real Marshal/ragling roster binds seeded weighted intents " + str(alternative))
	if not bound:
		return {}
	return {"enemies": enemies, "scheduler": scheduler, "intents": scheduler.get_intents()}


## AC1/AC2/AC3: the shipped Needle Marshal now authors the confirmed-hit
## bleeding sting, and only a real HP-losing Marshal attack applies it. The
## Scissor Bailiff is the other named true carrier; its own focused checks
## follow in _test_scissor_sting.
func _test_marshal_sting() -> void:
	var elites := _catalog(ELITES)
	var catalog := _record(elites, "needle_marshal")
	_check(not catalog.is_empty(), "precondition: the shipped Marshal record loads")
	if catalog.is_empty():
		return
	_check(catalog.get("bleed_on_attack") is bool and catalog.get("bleed_on_attack") == true,
		"AC1: needle_marshal authors bleed_on_attack as a genuine bool true")
	_check(catalog.get("name") == "Needle Marshal" and catalog.get("max_hp") == 28
		and catalog.get("max_hp") is int
		and catalog.get("art_path") == "res://assets/paper/enemies/needle_marshal.png"
		and catalog.get("intent", {}).get("target") == "front",
		"AC1: the stinging Marshal keeps its exact name, HP, art and front policy")
	# AC1 (Enrage): the same shipped record newly authors a genuine boolean flag
	# and still starts with no committed stack counter of its own.
	_check(catalog.get("enrage") is bool and catalog.get("enrage") == true
		and not catalog.has("enrage_stacks"),
		"AC1: needle_marshal authors boolean enrage true at zero stacks")
	var enraged := elites.filter(func(record: Dictionary) -> bool:
		return record.get("enrage") is bool and record.get("enrage") == true)
	_check(enraged.size() == 1 and enraged[0].get("id") == "needle_marshal",
		"AC1: the shipped Elite catalog authors Enrage on the Marshal alone")
	var carriers := elites.filter(func(record: Dictionary) -> bool:
		return record.get("bleed_on_attack") is bool and record.get("bleed_on_attack") == true)
	var carrier_ids: Array = carriers.map(func(record: Dictionary) -> String:
		return String(record.get("id", "")))
	_check(carrier_ids.size() == 2 and carrier_ids.has("needle_marshal")
		and carrier_ids.has("scissor_bailiff"),
		"AC1: the shipped Elite catalog authors the sting on the two named carriers only")
	for id in ["spool_hexer", "zipper_hauler", "needle_briar_guard",
			"spool_snarekeeper", "pincushion_matriarch", "spool_leech"]:
		var companion := _record(elites, id)
		_check(not companion.is_empty() and not companion.has("bleed_on_attack"),
			"AC1: no fabricated sting flag on the unchanged elite " + id)
	var escort_record := _record(_all_catalogs(), "ragling_guard")
	var escort_actions: Array = []
	for raw in escort_record.get("intent", {}).get("actions", []):
		var normalized := CombatEnemyIntents.weighted_action(raw)
		var body: Dictionary = normalized.get("action", {}).duplicate(true)
		body["weight"] = normalized.get("weight", 0)
		escort_actions.append(body)
	_check(not escort_record.is_empty() and not escort_record.has("bleed_on_attack")
		and escort_actions == [
			{"type": "block", "amount": 5, "weight": 3},
			{"type": "shove", "amount": 0, "direction": 1, "weight": 2},
			{"type": "attack", "amount": 6, "weight": 1},
			{"type": "attack", "amount": 7, "weight": 1, "move": "attack2"}],
		"AC1: the ragling escort keeps its own shield Rush/Block/Hit alternatives and no sting")
	var roster := _roster("needle_marshal_elite")
	_check(roster.get_enemy(1).get("bleed_on_attack") is bool
		and roster.get_enemy(1).get("bleed_on_attack") == true
		and not roster.get_enemy(2).has("bleed_on_attack"),
		"AC1: the real needle_marshal_elite roster carries the flag on the Marshal only")
	_check(roster.get_enemy(1).get("enrage") is bool
		and roster.get_enemy(1).get("enrage") == true
		and not roster.get_enemy(2).has("enrage"),
		"AC1: the real needle_marshal_elite roster carries Enrage on the Marshal only")
	var assembled := RunTypedBattleRoster.new().assemble(
		{"success": true, "node_type": "Elite", "encounter_id": "needle_marshal_elite",
		"definitions": _schedule("needle_marshal_elite")}, ROSTERS, [ELITES, STARTER, RUN])
	_check(assembled.get("ok", false)
		and assembled.enemies.get_enemy(1).get("bleed_on_attack") == true
		and assembled.enemies.get_enemy(1).get("enrage") == true
		and not assembled.enemies.get_enemy(2).has("bleed_on_attack")
		and not assembled.enemies.get_enemy(2).has("enrage"),
		"AC1: production typed assembly propagates the flag to the live roster")

	var attack5 := {"type": "attack", "amount": 5, "weight": 2}
	# AC2: the authored Attack 5 over two Block removes real HP and stings.
	var party := _party()
	_check(party.get_hero(1).get("hp") == 40 and party.gain_block(1, 2)
		and party.get_hero(1).get("block") == 2,
		"AC2 precondition: the real Warden holds 40 HP and two Block")
	var case := _forced_marshal(attack5, 51007, party)
	if case.is_empty():
		return
	var untouched: Array = [party.get_hero(2), party.get_hero(3)]
	var announced: Array = case.intents
	var input_before := announced.duplicate(true)
	_check(announced.size() == 2
		and announced[0] == {"type": "attack", "amount": 5, "enemy_position": 1,
			"target_position": 1}
		and announced[1] == {"type": "block", "amount": ESCORT_BLOCK, "enemy_position": 2},
		"AC2: the bound Marshal announces its authored Attack 5 on the front hero")
	var settled: Dictionary = CombatEnemyPhase.new().execute_phase(
		party, case.enemies, announced)
	_check(settled.get("ok", false) and settled.get("events", []).size() == 2
		and settled.events[0] == {"type": "attack", "enemy_position": 1,
			"applied": true, "target_position": 1},
		"AC2: the sting keeps the pre-existing applied attack event shape")
	_check(party.get_hero(1).get("hp") == 37 and party.get_hero(1).get("block") == 0,
		"AC2: five damage absorbs the two Block then removes exactly three HP")
	_check(party.get_hero(1).get("statuses", {}).get("bleed", 0) == 1,
		"AC2: the hero who really lost HP gains exactly Bleed 1")
	_check([party.get_hero(2), party.get_hero(3)] == untouched,
		"AC2: the other heroes keep their HP, Block and statuses")
	_check(announced == input_before,
		"AC2: the announced sting input is never rewritten")
	# AC2: a second genuine hit stacks instead of replacing the status.
	var second := _forced_marshal(attack5, 51007, party)
	if not second.is_empty():
		var second_settled: Dictionary = CombatEnemyPhase.new().execute_phase(
			party, second.enemies, second.intents)
		_check(second_settled.get("ok", false)
			and party.get_hero(1).get("hp") == 32
			and party.get_hero(1).get("statuses", {}).get("bleed", 0) == 2,
			"AC2: a second confirmed sting stacks Bleed to 2 and removes five HP")
	# Bleed N is an end-of-owner-turn HP loss of N, then N decreases by 1.
	var tick := CombatStatusTurnBatch.new().tick_side("heroes", party.get_heroes())
	var ticked: Array = tick.get("actors", [])
	_check(tick.get("ok", false) and ticked.size() == 3
		and ticked[0].get("hp") == 30
		and ticked[0].get("statuses", {}).get("bleed", 0) == 1,
		"AC2: the owner turn removes exactly Bleed N HP then keeps N-1")
	_check(party.get_hero(1).get("hp") == 32,
		"AC2: the owner tick stays detached until the caller publishes it")

	# AC3: full Block soaks the whole sting, so no HP and no Bleed.
	var blocked_party := _party()
	_check(blocked_party.gain_block(1, 5),
		"AC3 precondition: the Warden really holds five Block")
	var blocked := _forced_marshal(attack5, 51008, blocked_party)
	if not blocked.is_empty():
		var blocked_result: Dictionary = CombatEnemyPhase.new().execute_phase(
			blocked_party, blocked.enemies, blocked.intents)
		_check(blocked_result.get("ok", false)
			and blocked_result.get("events", [{}])[0].get("applied") == true
			and blocked_party.get_hero(1).get("hp") == 40
			and blocked_party.get_hero(1).get("block") == 0
			and blocked_party.get_hero(1).get("statuses", {}).get("bleed", 0) == 0,
			"AC3: five Block absorb the whole sting and grant no Bleed")
	# AC3: the authored Marshal Buff 3 is not an attack and never stings.
	var buff_party := _party()
	var buff := _forced_marshal({"type": "buff", "amount": 3, "weight": 1}, 51009,
		buff_party)
	if not buff.is_empty():
		var buff_heroes := buff_party.get_heroes()
		var buff_result: Dictionary = CombatEnemyPhase.new().execute_phase(
			buff_party, buff.enemies, buff.intents)
		_check(buff_result.get("ok", false) and buff.enemies.get_enemy(1).get("block") == 3
			and buff_party.get_heroes() == buff_heroes,
			"AC3: the authored Marshal Buff 3 only adds enemy Block and never stings")
	# AC3: the authored Marshal shove is not damage either.
	var shove_party := _party()
	var shove := _forced_marshal({"type": "shove", "amount": 0, "direction": 1,
		"weight": 1}, 51010, shove_party)
	if not shove.is_empty():
		var shove_heroes := shove_party.get_heroes()
		var shove_result: Dictionary = CombatEnemyPhase.new().execute_phase(
			shove_party, shove.enemies, shove.intents)
		_check(shove_result.get("ok", false)
			and shove_party.get_hero(1).get("id") == "seamstress"
			and shove_party.get_hero(2).get("id") == "warden"
			and shove_party.get_hero(1).get("hp") == shove_heroes[1].get("hp")
			and shove_party.get_hero(2).get("hp") == shove_heroes[0].get("hp")
			and shove_party.get_hero(1).get("statuses", {}).is_empty()
			and shove_party.get_hero(2).get("statuses", {}).is_empty()
			and shove_party.get_hero(3).get("statuses", {}).is_empty(),
			"AC3: the authored Marshal shove moves heroes without any sting")
	# AC3: a slain Marshal's announced sting stays inert.
	var slain_party := _party()
	_check(slain_party.gain_block(1, 2), "AC3 precondition: real Warden Block before a slain beat")
	var slain := _forced_marshal(attack5, 51011, slain_party)
	if not slain.is_empty():
		_check(slain.enemies.apply_damage(1, 28) and slain.enemies.is_slain(1),
			"AC3 precondition: the stinging Marshal is genuinely slain")
		var slain_heroes := slain_party.get_heroes()
		var slain_result: Dictionary = CombatEnemyPhase.new().execute_phase(
			slain_party, slain.enemies, slain.intents)
		_check(slain_result.get("ok", false)
			and slain_result.get("events", [{}])[0].get("applied") == false
			and slain_party.get_heroes() == slain_heroes,
			"AC3: a slain Marshal deals no damage and grants no Bleed")
	# AC3: an escort-only phase never fabricates Bleed on any hero.
	var escort_party := _party()
	_check(escort_party.gain_block(1, 2), "AC3 precondition: real Warden Block for an escort beat")
	var escort := _forced_marshal(attack5, 51012, escort_party)
	if not escort.is_empty():
		_check(escort.enemies.apply_damage(1, 28) and escort.enemies.is_slain(1),
			"AC3 precondition: only the ragling escort can still act")
		var escort_heroes := escort_party.get_heroes()
		var escort_result: Dictionary = CombatEnemyPhase.new().execute_phase(
			escort_party, escort.enemies, escort.intents)
		_check(escort_result.get("ok", false)
			and escort.enemies.get_enemy(2).get("block") == ESCORT_BLOCK
			and escort_party.get_heroes() == escort_heroes,
			"AC3: the escort's own five Block touches no hero and applies no Bleed")
	# AC3: the same authored hit without the flag still damages but never stings.
	var plain_party := _party()
	var plain := _forced_marshal(attack5, 51013, plain_party, false)
	if not plain.is_empty():
		_check(not plain.enemies.get_enemy(1).has("bleed_on_attack"),
			"AC3 precondition: the control Marshal roster carries no sting flag")
		var plain_result: Dictionary = CombatEnemyPhase.new().execute_phase(
			plain_party, plain.enemies, plain.intents)
		_check(plain_result.get("ok", false)
			and plain_party.get_hero(1).get("hp") == 35
			and plain_party.get_hero(1).get("statuses", {}).get("bleed", 0) == 0,
			"AC3: real HP damage without the flag fabricates no Bleed")
	# AC3: a forged attack input is rejected without any state or RNG change.
	var reject_party := _party()
	_check(reject_party.gain_block(1, 3), "AC3 precondition: real Warden Block before a forgery")
	var reject := _forced_marshal(attack5, 51014, reject_party)
	if not reject.is_empty():
		var reject_heroes := reject_party.get_heroes()
		var reject_enemies: Array = reject.enemies.get_enemies()
		var forged: Array = reject.intents.duplicate(true)
		forged[0]["target_position"] = 0
		seed(93331)
		var expected_rng := randi()
		seed(93331)
		var rejected: Dictionary = CombatEnemyPhase.new().execute_phase(
			reject_party, reject.enemies, forged)
		_check(rejected == {"ok": false, "events": []}
			and reject_party.get_heroes() == reject_heroes
			and reject.enemies.get_enemies() == reject_enemies,
			"AC3: a forged Marshal sting target rejects the whole phase")
		_check(randi() == expected_rng,
			"AC3: the rejected sting leaves hero HP, Block, statuses and RNG unchanged")


## A genuine single-source Hexer fight built from the shipped catalog record,
## narrowed to exactly one real authored alternative. The record keeps its own
## identity, HP and authored random target policy; only the alternative list is
## reduced so a fixed seed can force one genuine beat.
func _forced_hexer(alternative: Dictionary, seed_value: int,
		party: CombatParty) -> Dictionary:
	var hexer := _record(_all_catalogs(), "spool_hexer")
	if hexer.is_empty():
		return {}
	var weighted := CombatEnemyIntents.weighted_action(alternative)
	var action: Dictionary = weighted.get("action", {}).duplicate(true)
	_check(not action.is_empty(),
		"forced Hexer alternative is a valid authored action " + str(alternative))
	if action.is_empty():
		return {}
	action["weight"] = 1
	var forced: Dictionary = hexer.duplicate(true)
	forced["intent"] = {"target": hexer.get("intent", {}).get("target", ""),
		"actions": [action]}
	var enemies := CombatEnemies.new([forced])
	var scheduler := CombatEnemyIntents.new([
		{"enemy_position": 1, "pattern": [{"type": "block", "amount": 1}]}])
	var bound: bool = enemies.is_valid() and enemies.get_enemies().size() == 1 \
		and scheduler.is_valid() and scheduler.bind_battle(enemies, party, _rng(seed_value))
	_check(bound, "real Hexer record binds seeded weighted intents " + str(alternative))
	if not bound:
		return {}
	return {"enemies": enemies, "scheduler": scheduler, "intents": scheduler.get_intents()}


## Retain the original lash, Exposed, debuff and forgery regressions alongside
## the three named weighted attacks. Identity and random targeting stay intact.
func _test_hexer_lash() -> void:
	seed(64717)
	var expected_rng := randi()
	seed(64717)
	var elites := _catalog(ELITES)
	var untouched := elites.duplicate(true)
	var catalog := _record(elites, "spool_hexer")
	_check(not catalog.is_empty(), "AC1 precondition: the shipped Hexer record loads")
	if catalog.is_empty():
		return
	_check(catalog.get("name") == "Spool Hexer" and catalog.get("max_hp") is int
		and catalog.get("max_hp") == 24
		and catalog.get("art_path") == "res://assets/paper/enemies/spool_hexer.png"
		and catalog.get("intent", {}).get("target") == "random",
		"AC1: Spool Hexer keeps its exact name, 24 HP, art and random policy")
	var alternatives: Array = []
	for raw in catalog.get("intent", {}).get("actions", []):
		var weighted := CombatEnemyIntents.weighted_action(raw)
		var body: Dictionary = weighted.get("action", {}).duplicate(true)
		body["weight"] = weighted.get("weight", 0)
		alternatives.append(body)
	_check(alternatives == [
		{"type": "attack", "amount": 9, "weight": 1},
		{"type": "attack", "amount": 8, "move": "attack2", "weight": 1},
		{"type": "attack", "amount": 10, "move": "attack3", "weight": 1},
		{"type": "debuff", "amount": 1, "status": "exposed", "weight": 1},
		{"type": "debuff", "amount": 1, "status": "weak", "weight": 1}],
		"AC1: attack 9/8/10 each weigh one; Exposed and Weak stay 1/1")
	# Read by ID, never as a catalog total: the correction is bounded to the one
	# outlier, so every other shipped elite keeps its own authored attack sizes.
	var peers := {
		"needle_marshal": [5, 4, 6], "scissor_bailiff": [9, 8, 7], "zipper_hauler": [8, 10, 6],
		"needle_briar_guard": [9], "spool_snarekeeper": [8],
		"pincushion_matriarch": [9], "spool_leech": [8]}
	for id in peers:
		var peer := _record(elites, id)
		var amounts: Array = []
		for raw in peer.get("intent", {}).get("actions", []):
			if not raw is Dictionary or raw.get("type") != "attack":
				continue
			amounts.append(CombatEnemyIntents.weighted_action(raw).get("action", {}).get("amount"))
		_check(not peer.is_empty() and amounts == peers[id],
			"AC1: the unchanged elite keeps its authored attack sizes " + id)
	if alternatives.size() != 5:
		return

	# AC2: the source-owned 9 resolved by the real enemy phase through Block then HP.
	var party := _party()
	_check(party.get_hero(1).get("hp") == 40 and party.gain_block(1, 4),
		"AC2 precondition: the real Warden holds 40 HP and four Block")
	var case := _forced_hexer(alternatives[0], 64719, party)
	if case.is_empty():
		return
	var announced: Array = case.intents
	var input_before := announced.duplicate(true)
	_check(announced.size() == 1 and announced[0].get("type") == "attack"
		and announced[0].get("amount") == 9
		and announced[0].get("enemy_position") == 1
		and announced[0].get("target_position") in [1, 2, 3],
		"AC2: the bound Hexer announces its authored 9-point lash on a living hero")
	var target: int = announced[0].get("target_position", 0)
	if target not in [1, 2, 3]:
		return
	var heroes_before := party.get_heroes()
	var foes_before: Array = case.enemies.get_enemies()
	var settled: Dictionary = CombatEnemyPhase.new().execute_phase(
		party, case.enemies, announced)
	var expected_heroes := heroes_before.duplicate(true)
	var block_before := int(expected_heroes[target - 1].get("block", 0))
	var absorbed := mini(9, block_before)
	expected_heroes[target - 1]["block"] = block_before - absorbed
	expected_heroes[target - 1]["hp"] = int(expected_heroes[target - 1].get("hp", 0)) \
		- (9 - absorbed)
	_check(settled == {"ok": true, "events": [{"type": "attack", "enemy_position": 1,
			"applied": true, "target_position": target}]},
		"AC2: the 9-point lash publishes one applied attack event")
	_check(party.get_heroes() == expected_heroes
		and case.enemies.get_enemies() == foes_before,
		"AC2: the real phase spends the target's Block then removes exactly the source 9")
	_check(announced == input_before,
		"AC2: the announced lash input is never rewritten")

	# AC2: the authored 9 stays the source amount before the defender's own
	# Exposed multiplier and Block resolution.
	var exposed_party := _party()
	for position in [1, 2, 3]:
		exposed_party._heroes[position - 1]["statuses"] = {"exposed": 1}
	_check(CombatStatuses.new().adjusted_attack_damage(9, {},
		exposed_party.get_hero(1).get("statuses", {})) == 13,
		"AC2: Exposed turns the authored 9 into 13 incoming damage")
	var exposed_case := _forced_hexer(alternatives[0], 64721, exposed_party)
	if not exposed_case.is_empty():
		var exposed_heroes: Array = exposed_party.get_heroes()
		var exposed_target: int = exposed_case.intents[0].get("target_position", 0)
		var exposed_result: Dictionary = CombatEnemyPhase.new().execute_phase(
			exposed_party, exposed_case.enemies, exposed_case.intents)
		_check(exposed_target in [1, 2, 3] and exposed_result.get("ok", false),
			"AC2: the same authored 9 is announced against a living Exposed hero")
		if exposed_target in [1, 2, 3]:
			var exposed_expected := exposed_heroes.duplicate(true)
			var exposed_block := int(exposed_expected[exposed_target - 1].get("block", 0))
			var exposed_absorbed := mini(13, exposed_block)
			exposed_expected[exposed_target - 1]["block"] = exposed_block - exposed_absorbed
			exposed_expected[exposed_target - 1]["hp"] = \
				int(exposed_expected[exposed_target - 1].get("hp", 0)) - (13 - exposed_absorbed)
			_check(exposed_party.get_heroes() == exposed_expected,
				"AC2: the authored 9 is multiplied by Exposed before Block resolves")

	# AC2: both untouched status alternatives remain available and deal no damage.
	for index in [3, 4]:
		var alternative: Dictionary = alternatives[index]
		var status_party := _party()
		var status_case := _forced_hexer(alternative, 64725 + index, status_party)
		if status_case.is_empty():
			continue
		var status_target: int = status_case.intents[0].get("target_position", 0)
		var status_before: Array = status_party.get_heroes()
		var status_result: Dictionary = CombatEnemyPhase.new().execute_phase(
			status_party, status_case.enemies, status_case.intents)
		_check(status_target in [1, 2, 3] and status_result.get("ok", false)
			and status_result.get("events", []).size() == 1,
			"AC2: the authored " + str(alternative["status"]) + " "
				+ str(alternative["amount"]) + " remains available and resolves")
		if status_target not in [1, 2, 3]:
			continue
		var status_expected := status_before.duplicate(true)
		var landed := {}
		landed[alternative["status"]] = alternative["amount"]
		status_expected[status_target - 1]["statuses"] = landed
		_check(status_party.get_heroes() == status_expected,
			"AC2: the authored " + str(alternative["status"]) + " "
				+ str(alternative["amount"]) + " lands on exactly one hero without damage")

	# AC3: the same seed reproduces the announcement, and a forged target still
	# fails closed without touching any actor or spending a random number.
	var replay_party := _party()
	_check(replay_party.gain_block(1, 4),
		"AC3 precondition: a fresh Warden really holds four Block")
	var replay := _forced_hexer(alternatives[0], 64719, replay_party)
	if not replay.is_empty():
		_check(replay.intents == input_before,
			"AC3: a same-seed bound Hexer replays the identical lash announcement")
		var replay_heroes: Array = replay_party.get_heroes()
		var replay_foes: Array = replay.enemies.get_enemies()
		var forged: Array = replay.intents.duplicate(true)
		forged[0]["target_position"] = 0
		_check(CombatEnemyPhase.new().execute_phase(
				replay_party, replay.enemies, forged) == {"ok": false, "events": []}
			and replay_party.get_heroes() == replay_heroes
			and replay.enemies.get_enemies() == replay_foes,
			"AC3: a forged Hexer lash target fails closed with no mutation or RNG spend")
	_check(elites == untouched and _catalog(ELITES) == untouched,
		"AC3: the shipped elite catalog and its parsed source stay untouched")
	_check(randi() == expected_rng,
		"AC3: the Hexer lash checks use no global RNG")


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
	# An authored Thorns keyword is content too: it must be the genuine integer
	# the strict catalog parser publishes, never a JSON double or a string.
	if expected.has("thorns"):
		_check(record.get("thorns") is int and record.get("thorns") == expected["thorns"],
			"exact authored integer Thorns keyword " + id + " " + str(record.get("thorns")))
	else:
		_check(not record.has("thorns"), "no fabricated Thorns keyword " + id)
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
		and after.get("block") == 0 and after.get("hp") == 17
		and after.get("statuses") == {"bleed": 1}
		and enemies.get_enemies() == foes_before,
		"authored Scissor attack 9 eats four Block, deals all nine HP and stings once")


## One fresh authentic Scissor Bailiff actor, built from the shipped catalog
## record as the real CombatEnemies roster carries it, facing the real party.
## `override` is only used by the focused controls that re-home an earlier
## negative on a copy of that same real record; the shipped catalog is untouched.
func _bailiff_fixture(override: Dictionary = {}) -> Dictionary:
	var record: Dictionary = override.duplicate(true)
	if record.is_empty():
		record = _record(_catalog(ELITES), "scissor_bailiff")
	if record.is_empty():
		return {}
	var party := _party()
	var enemies := CombatEnemies.new([record])
	_check(enemies.is_valid() and enemies.get_enemies().size() == 1
		and enemies.get_enemy(1).get("id") == "scissor_bailiff"
		and enemies.get_enemy(1).get("hp") == 36
		and enemies.get_enemy(1).get("bleed_on_attack") is bool
		and enemies.get_enemy(1).get("bleed_on_attack") == true,
		"the real Bailiff actor carries its authored sting flag")
	_check(party.is_valid(), "three living heroes face the real Bailiff")
	return {"party": party, "enemies": enemies}


## Keep the complete parsed policy; force choices by finding seeded scheduler
## witnesses rather than replacing the shipped alternatives with test attacks.
func _test_bailiff_named_attacks() -> void:
	var record := _record(_catalog(ELITES), "scissor_bailiff")
	var witnesses := {}
	for seed_value in range(1, 201):
		var fixture := _new_elite_fixture(record)
		var scheduler := CombatEnemyIntents.new([
			{"enemy_position": 1, "pattern": [{"type": "block", "amount": 1}]}])
		_check(scheduler.bind_battle(fixture.enemies, fixture.party, _rng(seed_value)),
			"authentic Bailiff policy binds for seeded witness")
		var announced := scheduler.get_intents()
		if announced.size() == 1 and announced[0].get("move") in ["attack2", "attack3"]:
			witnesses[announced[0].move] = seed_value
		if witnesses.size() == 2:
			break
	for pose in ["attack2", "attack3"]:
		_check(witnesses.has(pose), "real Bailiff scheduler witness exists: " + pose)
		if not witnesses.has(pose):
			continue
		var total := 8 if pose == "attack2" else 7
		var hits := 2 if pose == "attack2" else 1
		var title := "Scissor Cut" if pose == "attack2" else "Hook Pull"
		# Four HP dies to the first cut; five HP survives it and earns one
		# Bleed before the second cut kills. Together with the healthy total,
		# these boundaries prove the independent 4+4 split, not just total 8.
		for mode in ["healthy", "four_hp", "five_hp", "dead", "blocked_control"]:
			var history: Array = []
			for replay in range(2):
				var source := record.duplicate(true)
				if mode == "blocked_control":
					source.erase("chew_block_on_attack")
				var fixture := _new_elite_fixture(source)
				var party: CombatParty = fixture.party
				var enemies: CombatEnemies = fixture.enemies
				var rng := _rng(witnesses[pose])
				var scheduler := CombatEnemyIntents.new([
					{"enemy_position": 1, "pattern": [{"type": "block", "amount": 1}]}])
				_check(scheduler.bind_battle(enemies, party, rng), "real Bailiff scheduler binds")
				var announced := scheduler.get_intents()
				var expected := {"type": "attack", "amount": total, "move": pose,
					"enemy_position": 1, "target_position": 1}
				if hits == 2:
					expected["hits"] = 2
				_check(announced == [expected], "exact authored named attack and front target")
				var fallback := "res://assets/paper/enemies/scissor_bailiff_attack.png"
				var named_art := "res://assets/paper/enemies/scissor_bailiff_%s.png" % pose
				var receipt := LiveMovePoseCatalog.new().lookup_enemy("scissor_bailiff", expected, fallback)
				_check(receipt.get("name") == title and receipt.get("pose") == pose
					and receipt.get("named_art") == named_art and receipt.get("covers") == ["attack"]
					and receipt.get("art_available") == ResourceLoader.exists(named_art, "Texture2D")
					and receipt.get("art") == (named_art if receipt.get("art_available") else fallback),
					"Bailiff real pose lookup retains authored name and checked art")
				_check(MissingMoveArt.new().lookup_enemy("scissor_bailiff", expected, fallback) == {
					"name": title, "pose": pose, "covers": ["attack"], "named_art": named_art,
					"art": fallback, "art_available": false, "fallback_used": true},
					"missing Bailiff art safely falls back without losing move identity")
				var hp := 4 if mode == "four_hp" else (5 if mode == "five_hp" else 40)
				_check(party.apply_damage(1, 40 - hp) and party.gain_block(1, 12),
					"actual HP and substantial Block preconditions")
				if mode == "dead":
					_check(enemies.apply_damage(1, 36) and enemies.is_slain(1), "real source dies after announcement")
				var before := [party.get_heroes(), enemies.get_enemies(), rng.state, scheduler.get_intents()]
				for field in ["move", "hits"]:
					for value in (["skill", "attack4", 2, "attack3" if hits == 2 else "attack2"] if field == "move" else [0, 1, 3, "2", 2.5, 2]):
						var forged := expected.duplicate(true)
						forged[field] = value
						if forged == expected:
							continue
						_check(CombatEnemyPhase.new().execute_phase(party, enemies, [forged], null, true, null, 73)
							== {"ok": false, "events": []}
							and before == [party.get_heroes(), enemies.get_enemies(), rng.state, scheduler.get_intents()],
							"invalid or unauthored move/hits publishes no actors, wallet, cache or RNG")
				var settled := CombatEnemyPhase.new().execute_phase(party, enemies, announced, null, true)
				var events: Array = []
				for hit in range(hits):
					events.append({"type": "attack", "enemy_position": 1, "target_position": 1,
						"move": pose, "applied": mode != "dead" and not (hit == 1 and hp == 4)})
				var inert: bool = mode in ["dead", "blocked_control"]
				var expected_party: Array = before[0].duplicate(true)
				expected_party[0].hp = hp if inert else maxi(0, hp - total)
				expected_party[0].block = (12 if mode == "dead" else 12 - total) if inert else 0
				if not inert and (hp > total or (hits == 2 and hp == 5)):
					expected_party[0]["statuses"] = {"bleed": hits if hp > total else 1}
				_check(settled == {"ok": true, "events": events}
					and party.get_heroes() == expected_party and enemies.get_enemies() == before[1]
					and scheduler.get_intents() == announced and rng.state == before[2],
					"exact per-hit receipts, 4+4/7 HP, chew, confirmed Bleed and untouched bystanders: " + pose + "/" + mode)
				var trace := [announced, settled, party.get_heroes(), enemies.get_enemies(), rng.state]
				if replay == 0:
					history = trace
				else:
					_check(history == trace, "identical Bailiff inputs replay every receipt and state")


## The legal front-target scissor cut announced by the authentic slot 1.
func _bailiff_cut() -> Dictionary:
	return {"type": "attack", "enemy_position": 1, "amount": 9, "target_position": 1}


## AC1/AC2/AC3/AC4: the shipped Scissor Bailiff's existing nine-point scissor cut
## now shears through the real recipient's whole Block before it lands (the
## already-shipped CombatEnemyPhase chew_block_on_attack rule), then stings the
## hero who really loses HP with exactly one Bleed. Only a genuine cut by a
## living source stings; the fully blocked no-sting negative moves onto a genuine
## non-chewing control copied from the same record, so that coverage keeps its
## strength, while dead-source, non-attack, malformed-metadata and
## invalid-announcement beats stay clean and atomic.
func _test_scissor_sting() -> void:
	seed(64519)
	var expected_rng := randi()
	seed(64519)
	var catalog := _record(_catalog(ELITES), "scissor_bailiff")
	_check(not catalog.is_empty(), "AC1 precondition: the shipped Bailiff record loads")
	if catalog.is_empty():
		return
	# AC1: the same record authors both boolean trait flags; every other field is
	# untouched, and the cloth-eating cut is not a new keyword or action.
	_check(catalog.get("bleed_on_attack") is bool
		and catalog.get("bleed_on_attack") == true,
		"AC1: scissor_bailiff authors bleed_on_attack as a genuine bool true")
	_check(catalog.get("chew_block_on_attack") is bool
		and catalog.get("chew_block_on_attack") == true,
		"AC1: scissor_bailiff authors chew_block_on_attack as a genuine bool true")
	# AC1: read the peers by ID, never by catalog total or position, so a
	# parallel append cannot make this check lie about the shipped records.
	var elites := _catalog(ELITES)
	var chewer_ids: Array = []
	for record in elites:
		if record.get("chew_block_on_attack") is bool \
				and record.get("chew_block_on_attack") == true:
			chewer_ids.append(String(record.get("id", "")))
	_check(chewer_ids.has("scissor_bailiff") and chewer_ids.has("spool_leech"),
		"AC1: the shipped Elite catalog authors the cloth-eating cut on Bailiff and Leech")
	for id in ["needle_marshal", "spool_hexer", "zipper_hauler", "needle_briar_guard",
			"spool_snarekeeper", "pincushion_matriarch"]:
		var peer := _record(elites, id)
		_check(not peer.is_empty() and not peer.has("chew_block_on_attack"),
			"AC1: no fabricated cloth-eating trait on the unchanged elite " + id)
	# AC1: the new Leech record carries the genuine boolean flag.
	var leech_peer := _record(elites, "spool_leech")
	_check(not leech_peer.is_empty()
		and leech_peer.has("chew_block_on_attack")
		and leech_peer.get("chew_block_on_attack") is bool
		and leech_peer.get("chew_block_on_attack") == true,
		"AC1: the Spool Leech authors the genuine bool chew_block_on_attack")
	_check(catalog.get("name") == "Scissor Bailiff" and catalog.get("max_hp") is int
		and catalog.get("max_hp") == 36
		and catalog.get("art_path") == "res://assets/paper/enemies/scissor_bailiff.png"
		and catalog.get("intent", {}).get("target") == "front",
		"AC1: the Bailiff keeps its name, 36 HP, scissor art and front policy")
	var actions: Array = []
	for raw in catalog.get("intent", {}).get("actions", []):
		var weighted := CombatEnemyIntents.weighted_action(raw)
		var body: Dictionary = weighted.get("action", {}).duplicate(true)
		body["weight"] = weighted.get("weight", 0)
		actions.append(body)
	_check(actions == V3_ELITES["scissor_bailiff"]["actions"],
		"AC1: original snip, Bleed and cut precede the two named attacks")
	var cut := _bailiff_cut()
	_check(cut.get("amount") == 9, "AC1 precondition: the authored scissor cut is 9")

	# AC2: the authored cut over two Block eats that Block, removes real HP and
	# stings once; the published attack receipt shape is unchanged.
	var first := _bailiff_fixture()
	if first.is_empty():
		return
	var party: CombatParty = first["party"]
	var enemies: CombatEnemies = first["enemies"]
	_check(party.get_hero(1).get("hp") == 40 and party.gain_block(1, 2)
		and party.get_hero(1).get("block") == 2,
		"AC2 precondition: the front Warden holds 40 HP and two Block")
	var input := [cut.duplicate(true)]
	var input_before := input.duplicate(true)
	var heroes_before := party.get_heroes()
	var foes_before := enemies.get_enemies()
	var settled: Dictionary = CombatEnemyPhase.new().execute_phase(party, enemies, input)
	_check(settled == {"ok": true, "events": [{"type": "attack", "enemy_position": 1,
			"applied": true, "target_position": 1}]},
		"AC2: the real phase publishes one applied nine-point scissor cut")
	var after := party.get_hero(1)
	_check(after.get("block") == 0 and after.get("hp") == 31,
		"AC2: the shears eat the two Block, so all nine points reach HP")
	_check(after.get("statuses") == {"bleed": 1},
		"AC2: the hero who really lost HP gains exactly one Bleed")
	_check(party.get_hero(2) == heroes_before[1] and party.get_hero(3) == heroes_before[2]
		and enemies.get_enemies() == foes_before and input == input_before,
		"AC2: other heroes, the roster and the announcement stay untouched")
	# AC2: an equal same-input replay publishes and lands identically.
	var replay := _bailiff_fixture()
	if replay.is_empty():
		return
	var replay_party: CombatParty = replay["party"]
	var replay_enemies: CombatEnemies = replay["enemies"]
	_check(replay_party.gain_block(1, 2), "AC2 replay precondition: two Block")
	var replay_input := [cut.duplicate(true)]
	var replayed: Dictionary = CombatEnemyPhase.new().execute_phase(
		replay_party, replay_enemies, replay_input)
	_check(replayed == settled and replay_party.get_heroes() == party.get_heroes()
		and replay_enemies.get_enemies() == enemies.get_enemies()
		and replay_input == input_before,
		"AC2: the same nine-point cut on equal inputs replays identically")

	# AC3: nine Block no longer soak the cut. The shears eat all nine first, so
	# the full nine points reach HP and the confirmed hit still stings once.
	var eaten := _bailiff_fixture()
	if eaten.is_empty():
		return
	var eaten_party: CombatParty = eaten["party"]
	var eaten_enemies: CombatEnemies = eaten["enemies"]
	_check(eaten_party.get_hero(1).get("hp") == 40
		and eaten_party.gain_block(1, 9)
		and eaten_party.get_hero(1).get("block") == 9,
		"AC3 precondition: the front Warden really holds 40 HP and nine Block")
	var eaten_heroes := eaten_party.get_heroes()
	var eaten_input := [_bailiff_cut()]
	var eaten_result: Dictionary = CombatEnemyPhase.new().execute_phase(
		eaten_party, eaten_enemies, eaten_input)
	_check(eaten_result == {"ok": true, "events": [{"type": "attack",
			"enemy_position": 1, "applied": true, "target_position": 1}]},
		"AC3: the chewing cut still publishes one ordinary applied attack event")
	_check(eaten_party.get_hero(1).get("block") == 0
		and eaten_party.get_hero(1).get("hp") == 31
		and eaten_party.get_hero(1).get("hp") == eaten_heroes[0]["hp"] - 9
		and eaten_party.get_hero(1).get("statuses") == {"bleed": 1}
		and eaten_party.get_hero(2) == eaten_heroes[1]
		and eaten_party.get_hero(3) == eaten_heroes[2],
		"AC3: nine Block are eaten first, then exactly nine HP and one Bleed land")

	# AC3: the earlier fully blocked, no-HP-loss and no-sting negative moves onto
	# a genuine non-chewing control copied from the same shipped record, so that
	# coverage keeps its old strength instead of being deleted.
	for mode in ["explicit_false", "absent"]:
		var control_record: Dictionary = catalog.duplicate(true)
		if mode == "explicit_false":
			control_record["chew_block_on_attack"] = false
		else:
			control_record.erase("chew_block_on_attack")
		var control := _bailiff_fixture(control_record)
		if control.is_empty():
			return
		var control_party: CombatParty = control["party"]
		var control_enemies: CombatEnemies = control["enemies"]
		_check(not control_enemies.get_enemy(1).get("chew_block_on_attack", false)
			and control_party.get_hero(1).get("hp") == 40
			and control_party.gain_block(1, 9)
			and control_party.get_hero(1).get("block") == 9,
			"AC3 precondition: nine Block on the non-chewing control: " + mode)
		var control_heroes := control_party.get_heroes()
		var control_input := [_bailiff_cut()]
		var control_before := control_input.duplicate(true)
		var control_result: Dictionary = CombatEnemyPhase.new().execute_phase(
			control_party, control_enemies, control_input)
		_check(control_result == {"ok": true, "events": [{"type": "attack",
				"enemy_position": 1, "applied": true, "target_position": 1}]},
			"AC3: the non-chewing control still resolves one applied cut: " + mode)
		_check(control_party.get_hero(1).get("block") == 0
			and control_party.get_hero(1).get("hp") == control_heroes[0]["hp"]
			and control_party.get_hero(1).get("hp") == 40
			and not control_party.get_hero(1).get("statuses", {}).has("bleed")
			and control_party.get_hero(2) == control_heroes[1]
			and control_party.get_hero(3) == control_heroes[2]
			and control_input == control_before,
			"AC3: nine Block shield the whole cut, so no HP is lost and no Bleed lands: "
				+ mode)

	# AC3: a slain Bailiff cannot sting even with a Block-free front hero.
	var dead := _bailiff_fixture()
	if dead.is_empty():
		return
	var dead_party: CombatParty = dead["party"]
	var dead_enemies: CombatEnemies = dead["enemies"]
	_check(dead_party.gain_block(1, 2) and dead_enemies.apply_damage(1, 36)
		and dead_enemies.is_slain(1),
		"AC3 precondition: the Bailiff is genuinely slain")
	var dead_heroes := dead_party.get_heroes()
	var dead_result: Dictionary = CombatEnemyPhase.new().execute_phase(
		dead_party, dead_enemies, [_bailiff_cut()])
	_check(dead_result.get("ok", false)
		and dead_result.get("events", [{}])[0].get("applied") == false
		and dead_party.get_heroes() == dead_heroes,
		"AC3: a slain Bailiff deals no damage and grants no Bleed")

	# AC3: its own snip only removes Block and never stings.
	var snip_fixture := _bailiff_fixture()
	if snip_fixture.is_empty():
		return
	var snip_party: CombatParty = snip_fixture["party"]
	_check(snip_party.gain_block(1, 5),
		"AC3 precondition: the front hero holds five Block for the snip")
	var snip := {"type": "snip_block", "enemy_position": 1, "amount": 0,
		"target_position": 1}
	var snip_result: Dictionary = CombatEnemyPhase.new().execute_phase(
		snip_party, snip_fixture["enemies"], [snip.duplicate(true)])
	_check(snip_result == {"ok": true, "events": [_phase_event(snip)]}
		and snip_party.get_hero(1).get("block") == 0
		and snip_party.get_hero(1).get("hp") == 40
		and not snip_party.get_hero(1).get("statuses", {}).has("bleed"),
		"AC3: the authored snip removes Block only and never stings")

	# AC3: its own Bleed 2 debuff stays exactly two, with no extra attack sting.
	var debuff_fixture := _bailiff_fixture()
	if debuff_fixture.is_empty():
		return
	var debuff_party: CombatParty = debuff_fixture["party"]
	var debuff := {"type": "debuff", "enemy_position": 1, "amount": 2,
		"status": "bleed", "target_position": 1}
	var debuff_result: Dictionary = CombatEnemyPhase.new().execute_phase(
		debuff_party, debuff_fixture["enemies"], [debuff.duplicate(true)])
	_check(debuff_result == {"ok": true, "events": [_phase_event(debuff)]}
		and debuff_party.get_hero(1).get("statuses") == {"bleed": 2}
		and debuff_party.get_hero(1).get("hp") == 40,
		"AC3: the authored Bleed 2 debuff stays its own action with no extra sting")

	# AC4: malformed chew metadata rejects the whole staged phase before any beat
	# is staged, so no Block is eaten, no HP is lost and no Bleed lands.
	var malformed_record: Dictionary = catalog.duplicate(true)
	malformed_record["chew_block_on_attack"] = 1
	var malformed := _bailiff_fixture(malformed_record)
	if malformed.is_empty():
		return
	var malformed_party: CombatParty = malformed["party"]
	var malformed_enemies: CombatEnemies = malformed["enemies"]
	_check(malformed_enemies.is_valid()
		and malformed_enemies.get_enemy(1).has("chew_block_on_attack")
		and malformed_enemies.get_enemy(1).get("chew_block_on_attack") == 1,
		"AC4 precondition: the malformed chew trait reaches a valid roster")
	_check(malformed_party.gain_block(1, 9)
		and malformed_party.get_hero(1).get("block") == 9,
		"AC4 precondition: nine Block on the malformed-metadata case")
	var malformed_heroes := malformed_party.get_heroes()
	var malformed_roster := malformed_enemies.get_enemies()
	var malformed_input := [_bailiff_cut()]
	var malformed_before := malformed_input.duplicate(true)
	_check(CombatEnemyPhase.new().execute_phase(malformed_party, malformed_enemies,
		malformed_input) == {"ok": false, "events": []},
		"AC4: malformed chew metadata rejects the whole staged phase")
	_check(malformed_party.get_heroes() == malformed_heroes
		and malformed_enemies.get_enemies() == malformed_roster
		and malformed_party.get_hero(1).get("block") == 9
		and malformed_party.get_hero(1).get("hp") == 40
		and not malformed_party.get_hero(1).get("statuses", {}).has("bleed")
		and malformed_input == malformed_before,
		"AC4: a rejected malformed cut eats no Block and lands no HP loss or Bleed")

	# AC4: an invalid announcement never speculatively eats the recipient's Block.
	var bad := _bailiff_fixture()
	if bad.is_empty():
		return
	var bad_party: CombatParty = bad["party"]
	var bad_enemies: CombatEnemies = bad["enemies"]
	_check(bad_party.gain_block(1, 9) and bad_party.get_hero(1).get("block") == 9,
		"AC4 precondition: nine Block before an invalid announced cut")
	var bad_cut := _bailiff_cut()
	bad_cut["target_position"] = 0
	_reject_beat("Scissor cut outside the party", bad_party, bad_enemies, bad_cut)
	_check(bad_party.get_hero(1).get("block") == 9
		and bad_party.get_hero(1).get("hp") == 40
		and not bad_party.get_hero(1).get("statuses", {}).has("bleed"),
		"AC4: an invalid announced cut keeps all nine Block and grants no Bleed")
	_check(randi() == expected_rng,
		"AC1/AC2/AC3/AC4: the Bailiff catalog and phase checks use no global RNG")


## AC1/AC2/AC3: the shipped Zipper Hauler looks like a hook, so its authored
## shove is a forward pull (direction -1). A real CombatEnemyPhase yanks the
## living middle hero in slot 2 forward into slot 1 instead of shoving the front
## hero back, exchanging exactly those two actors.
class ZipperHitWitness extends CombatWardenGuardReactions:
	var packets: Array = []
	func resolve_enemy_attack(party: Variant, enemies: Variant, attack: Variant) -> Dictionary:
		var before: Dictionary = party.get_hero(attack.target_position)
		var result := super.resolve_enemy_attack(party, enemies, attack)
		var after: Dictionary = party.get_hero(attack.target_position)
		packets.append([attack.amount, before.hp, before.block, after.hp, after.block])
		return result


## Catalog-only Elite: bind its authentic policy directly, without claiming an
## encounter route. A narrowed copy forces each authored alternative as well.
func _test_zipper_named_strikes(record: Dictionary) -> void:
	var witnesses := {}
	for seed_value in range(1, 201):
		var announced := _announcements(record, seed_value, 1)
		if announced.size() == 1 and announced[0].size() == 1:
			var move: String = announced[0][0].get("move", "")
			if move in ["attack2", "attack3"]:
				witnesses[move] = seed_value
		if witnesses.size() == 2:
			break
	for move in ["attack2", "attack3"]:
		_check(witnesses.has(move), "authentic weighted Zipper witness exists: " + move)
		if not witnesses.has(move):
			continue
		var amount := 10 if move == "attack2" else 6
		var hits := 1 if move == "attack2" else 2
		var title := "Tusk Gore" if move == "attack2" else "Pull Tab Fling"
		for forced in [false, true]:
			for shield in [0, 2, 4, 10]:
				var history: Array = []
				for replay in range(2):
					var source := record.duplicate(true)
					if forced:
						source.intent.actions = source.intent.actions.filter(
							func(a: Dictionary) -> bool: return a.get("move") == move)
						_check(source.intent.actions.size() == 1,
							"forced policy retains exactly one genuine catalog alternative")
					var f := _new_elite_fixture(source)
					var rng := _rng(witnesses[move])
					var scheduler := CombatEnemyIntents.new([
						{"enemy_position": 1, "pattern": [{"type": "block", "amount": 1}]}])
					_check(scheduler.bind_battle(f.enemies, f.party, rng), "Zipper policy binds real actors")
					var oracle := _rng(witnesses[move])
					if not forced:
						var roll := oracle.randi_range(1, 8)
						_check(roll == (7 if move == "attack2" else 8),
							"independent weighted roll reaches appended weight-one alternative")
					_check(rng.state == oracle.state, "full policy spends one weighted draw; forced policy spends none")
					var expected := {"type": "attack", "amount": amount, "move": move,
						"enemy_position": 1, "target_position": 1}
					if hits == 2:
						expected.hits = 2
					var input := scheduler.get_intents()
					_check(input == [expected], "weighted/forced named announcement has exact front target and total/hits")
					var fallback := "res://assets/paper/enemies/zipper_hauler_attack.png"
					var named_art := "res://assets/paper/enemies/zipper_hauler_%s.png" % move
					var pose := LiveMovePoseCatalog.new().lookup_enemy("zipper_hauler", expected, fallback)
					_check(pose.get("name") == title and pose.get("pose") == move
						and pose.get("named_art") == named_art and pose.get("covers") == ["attack"]
						and pose.get("art_available") == ResourceLoader.exists(named_art, "Texture2D")
						and pose.get("art") == (named_art if pose.get("art_available") else fallback),
						"Zipper named pose retains identity and checked asset path")
					_check(MissingMoveArt.new().lookup_enemy("zipper_hauler", expected, fallback) == {
						"name": title, "pose": move, "covers": ["attack"], "named_art": named_art,
						"art": fallback, "art_available": false, "fallback_used": true},
						"missing Zipper art uses established fallback with named identity")
					_check(f.party.gain_block(1, shield), "real front hero Block precondition")
					var before := [f.party.get_heroes(), f.enemies.get_enemies(), rng.state,
						scheduler.get_intents(), input.duplicate(true)]
					for changes in [{"move": "attack4"}, {"move": "attack3" if hits == 1 else "attack2"},
							{"amount": 8}, {"hits": 3}, {"hits": 1 if hits == 2 else 2},
							{"target_position": 0}, {"target_position": 4}, {"target_position": "1"}]:
						var bad := [expected.merged(changes, true)]
						var bad_before := bad.duplicate(true)
						_check(CombatEnemyPhase.new().execute_phase(f.party, f.enemies, bad, null, true)
							== {"ok": false, "events": []} and bad == bad_before
							and before == [f.party.get_heroes(), f.enemies.get_enemies(), rng.state,
								scheduler.get_intents(), input],
							"forged move/amount/hits/target rejects without actors, inputs or RNG writes")
					var original: Dictionary = f.enemies.get_enemy(1).intent
					f.enemies._enemies[0].intent.actions = original.actions.filter(
						func(a: Dictionary) -> bool: return a.get("move") != move)
					var stale_before: Array = f.enemies.get_enemies()
					_check(CombatEnemyPhase.new().execute_phase(f.party, f.enemies, input, null, true)
						== {"ok": false, "events": []} and f.enemies.get_enemies() == stale_before
						and f.party.get_heroes() == before[0] and rng.state == before[2]
						and input == before[4] and scheduler.get_intents() == before[3],
						"expired genuine Zipper alternative rejects atomically")
					f.enemies._enemies[0].intent = original
					var witness := ZipperHitWitness.new()
					var receipt := CombatEnemyPhase.new().execute_phase(f.party, f.enemies, input, witness, true)
					var packets: Array = []
					var events: Array = []
					var hp := 40
					var block: int = shield
					for hit in range(hits):
						var packet := 10 if hits == 1 else 3
						var next_hp := hp - maxi(0, packet - block)
						var next_block := maxi(0, block - packet)
						packets.append([packet, hp, block, next_hp, next_block])
						hp = next_hp
						block = next_block
						events.append({"type": "attack", "enemy_position": 1, "target_position": 1,
							"move": move, "applied": true, "actual_target_position": 1, "redirected": false,
							"retaliation_damage": 0, "retaliatory_damage": 0})
					var heroes: Array = before[0].duplicate(true)
					heroes[0].hp = hp
					heroes[0].block = block
					_check(receipt == {"ok": true, "events": events} and witness.packets == packets
						and f.party.get_heroes() == heroes and f.enemies.get_enemies() == before[1]
						and rng.state == before[2] and scheduler.get_intents() == input and input == before[4],
						"exact one 10 or ordered 3+3 packets through Block; every other actor/input unchanged")
					_check(scheduler.advance_turn(), "real seeded scheduler advances after accepted phase")
					var trace := [input, receipt, witness.packets, f.party.get_heroes(),
						f.enemies.get_enemies(), scheduler.get_intents(), rng.state]
					if replay == 0:
						history = trace
					else:
						_check(history == trace, "same-seed Zipper announcements, phase, next draw and RNG replay exactly")


func _test_zipper_beats(record: Dictionary) -> void:
	_test_zipper_named_strikes(record)
	var fixture := _new_elite_fixture(record)
	var party: CombatParty = fixture["party"]
	var enemies: CombatEnemies = fixture["enemies"]
	var authored_pulls: Array = []
	for raw in record.get("intent", {}).get("actions", []):
		if raw is Dictionary and raw.get("type") == "shove":
			var weighted := CombatEnemyIntents.weighted_action(raw)
			var body: Dictionary = weighted.get("action", {}).duplicate(true)
			body["weight"] = weighted.get("weight", 0)
			authored_pulls.append(body)
	_check(authored_pulls == [{"type": "shove", "amount": 0, "direction": -1,
			"weight": 2}],
		"AC1: the shipped Zipper Hauler authors one pull: shove 0 direction -1 weight 2")
	var pull := {"type": "shove", "enemy_position": 1, "amount": 0,
		"target_position": 2, "direction": -1}
	_check(party.apply_damage(1, 4) and party.gain_block(1, 2)
		and party.apply_damage(2, 3) and party.gain_block(2, 1),
		"pull precondition: the front and middle heroes live with distinct HP and Block")
	_check(party.get_hero(1).get("id") == "warden"
		and party.get_hero(2).get("id") == "seamstress"
		and not party.is_downed(1) and not party.is_downed(2),
		"pull precondition: the hooked middle hero stands behind a living front hero")
	party._heroes[1]["statuses"] = {"exposed": 1}
	var heroes_before := party.get_heroes()
	var foes_before := enemies.get_enemies()
	var input := [pull.duplicate(true)]
	var input_before := input.duplicate(true)
	var result: Dictionary = CombatEnemyPhase.new().execute_phase(party, enemies, input)
	_check(result == {"ok": true, "events": [_phase_event(pull)]},
		"announced Zipper pull -1 resolves as one applied beat")
	var expected := heroes_before.duplicate(true)
	expected[0] = heroes_before[1].duplicate(true)
	expected[1] = heroes_before[0].duplicate(true)
	expected[0]["position"] = 1
	expected[1]["position"] = 2
	_check(party.get_heroes() == expected,
		"a -1 pull exchanges the living heroes in positions 2 and 1 with every other field kept")
	_check(party.get_hero(1).get("id") == "seamstress"
		and party.get_hero(2).get("id") == "warden"
		and party.get_hero(1).get("hp") == heroes_before[1]["hp"]
		and party.get_hero(2).get("hp") == heroes_before[0]["hp"]
		and party.get_hero(1).get("block") == heroes_before[1]["block"]
		and party.get_hero(2).get("block") == heroes_before[0]["block"],
		"the pulled heroes keep their identity, current HP, Block and statuses")
	_check(party.get_hero(1).get("statuses") == {"exposed": 1}
		and party.get_hero(3) == heroes_before[2],
		"the pulled hero keeps its Exposed stack and the rear hero stays in slot 3")
	_check(enemies.get_enemies() == foes_before and input == input_before,
		"a pull is not a damaging move and leaves the enemy roster and input untouched")

	# AC3: a forward pull whose front partner is genuinely downed fails closed.
	fixture = _new_elite_fixture(record)
	party = fixture["party"]
	enemies = fixture["enemies"]
	_check(party.apply_damage(1, 40) and party.is_downed(1) and not party.is_downed(2),
		"AC3 precondition: the front partner of the pull is genuinely downed")
	_reject_beat("forward pull into a downed front partner", party, enemies,
		pull.duplicate(true))

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


## AC3: the legitimate pull is a pure state exchange. Its own seeded global
## stream is checked here, outside _test_v3_elites, so the enclosing v3
## no-global-RNG witness keeps its exact seed.
func _test_zipper_pull_rng() -> void:
	var record := _record(_catalog(ELITES), "zipper_hauler")
	if record.is_empty():
		return
	var fixture := _new_elite_fixture(record)
	var party: CombatParty = fixture["party"]
	var enemies: CombatEnemies = fixture["enemies"]
	var pull := {"type": "shove", "enemy_position": 1, "amount": 0,
		"target_position": 2, "direction": -1}
	_check(not party.is_downed(1) and not party.is_downed(2),
		"AC3 precondition: the seeded pull has a living middle-to-front pair")
	seed(52499)
	var expected_rng := randi()
	seed(52499)
	var result: Dictionary = CombatEnemyPhase.new().execute_phase(party, enemies, [pull])
	_check(result.get("ok", false)
		and party.get_hero(1).get("id") == "seamstress"
		and party.get_hero(2).get("id") == "warden",
		"AC3: the seeded pull really resolves both living heroes")
	_check(randi() == expected_rng,
		"AC3: a resolved legitimate pull consumes no random number")


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
		_check(party.gain_block(1, 3) and party.gain_block(2, 4),
			"rejection precondition: front and middle Block must survive " + id)
		_reject_beat("forward pull from the front slot " + id, party, fixture["enemies"],
			{"type": "shove", "enemy_position": 1, "amount": 0,
			"target_position": 1, "direction": -1})

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


## The authentic shipped Needle Briar Guard as the production typed roster
## assembler publishes it from the real catalog files, beside its own authored
## companion. Nothing here injects, rewrites or duplicates a record.
func _briar_guard_roster() -> CombatEnemies:
	var choice := {"success": true, "node_type": "Elite", "encounter_id": BRIAR_PROBE,
		"definitions": [
			{"enemy_position": 1, "pattern": [{"type": "block", "amount": 8}]},
			{"enemy_position": 2, "pattern": [{"type": "block", "amount": 8}]}]}
	var assembled := RunTypedBattleRoster.new().assemble(choice,
		{BRIAR_PROBE: BRIAR_PROBE_ROSTER}, [ELITES, STARTER, RUN])
	_check(assembled.get("ok", false),
		"production typed assembly publishes the real Guard roster")
	if not assembled.get("ok", false):
		return null
	var enemies: CombatEnemies = assembled.enemies
	var living := 0
	for foe in enemies.get_enemies():
		if foe.get("hp", 0) > 0:
			living += 1
	_check(enemies.is_valid() and living == 2 and enemies.get_enemies().size() == 2
		and enemies.get_enemy(1).get("id") == "needle_briar_guard"
		and enemies.get_enemy(1).get("hp") == 42
		and enemies.get_enemy(1).get("block") == 0
		and enemies.get_enemy(2).get("id") == "spool_snarekeeper"
		and enemies.get_enemy(2).get("hp") == 40,
		"the assembled roster is the living authored 42/40 HP Guard pair")
	return enemies


## V3-2 Thorns AC1/AC2/AC3: the authored Guard, reached through the production
## typed roster from the shipped catalog, retaliates exactly 3 for one confirmed
## hero hit, spends hero Block before HP, and stays inert on no hit.
func _test_briar_guard_thorns(catalog: Array) -> void:
	var record := _record(catalog, "needle_briar_guard")
	if record.is_empty():
		return
	# AC1: the on-disk catalog authors exactly Thorns 3 on this one record.
	_check(record.get("thorns") is int and record.get("thorns") == 3,
		"AC1: the shipped Guard record authors a genuine integer Thorns 3")
	_check(record.get("name") == "Needle Briar Guard" and record.get("max_hp") is int
		and record.get("max_hp") == 42
		and record.get("art_path") == "res://assets/paper/enemies/needle_briar_guard.png"
		and record.get("intent", {}).get("target") == "front",
		"AC1: the thorned Guard keeps its name, 42 HP, art and front target")
	var actions: Array = []
	for raw in record.get("intent", {}).get("actions", []):
		var weighted := CombatEnemyIntents.weighted_action(raw)
		var body: Dictionary = weighted.get("action", {}).duplicate(true)
		body["weight"] = weighted.get("weight", 0)
		actions.append(body)
	_check(actions == V3_2_ELITES["needle_briar_guard"]["actions"],
		"AC1: the Guard keeps its three exact weighted alternatives")
	# Earlier Elite entries stay present with exactly their own keyword state,
	# checked by ID: only the Guard newly authors Thorns 3.
	var earlier := {
		"needle_marshal": 3, "pincushion_matriarch": 4,
		"spool_hexer": 0, "scissor_bailiff": 0, "zipper_hauler": 0,
		"spool_snarekeeper": 0, "spool_leech": 0}
	for id in earlier:
		var other := _record(catalog, id)
		if earlier[id] > 0:
			_check(other.get("thorns") is int and other.get("thorns") == earlier[id],
				"AC1: the earlier authored Thorns stays exact " + id)
		else:
			_check(not other.is_empty() and not other.has("thorns"),
				"AC1: the earlier elite gains no Thorns keyword " + id)

	# AC2: one confirmed five-damage hero hit on a living three-hero party.
	var party := _party()
	var enemies := _briar_guard_roster()
	if enemies == null:
		return
	var pre_hit := enemies.get_enemy(1)
	_check(pre_hit.get("thorns") is int and pre_hit.get("thorns") == 3,
		"AC2: the assembled live Guard actor carries Thorns 3")
	var receipt := CombatStatusAttacks.new().resolve_vs_enemy(enemies, 1, 5, {}, {})
	_check(receipt == {"ok": true, "damage": 5, "block_absorbed": 0, "hp_loss": 5},
		"AC2: the real status bridge confirms a five-damage hit")
	var heroes_before := party.get_heroes()
	var foes_before := enemies.get_enemies()
	seed(70731)
	var expected_rng := randi()
	seed(70731)
	var result := CombatEnemyKeywordRules.new().resolve_thorns_retaliation(
		party, 1, pre_hit, receipt)
	_check(randi() == expected_rng,
		"AC2: one retaliation consumes no random number")
	_check(result == {"ok": true, "applied": true, "thorns": 3,
		"block_absorbed": 0, "hp_loss": 3},
		"AC2: the confirmed hit retaliates exactly Thorns 3")
	_check(party.get_hero(1).get("hp") == heroes_before[0]["hp"] - 3
		and party.get_hero(1).get("block") == 0,
		"AC2: the attacking front hero loses exactly three HP from 40")
	_check(party.get_hero(2) == heroes_before[1] and party.get_hero(3) == heroes_before[2],
		"AC2: the middle and rear heroes keep their HP, Block and statuses")
	_check(enemies.get_enemy(1).get("hp") == 37 and enemies.get_enemy(1).get("block") == 0
		and enemies.get_enemy(2) == foes_before[1],
		"AC2: the hit removes five Guard HP and leaves the companion alone")
	_check(pre_hit.get("hp") == 42 and pre_hit.get("thorns") == 3
		and receipt == {"ok": true, "damage": 5, "block_absorbed": 0, "hp_loss": 5},
		"AC2: the pre-hit snapshot and the real receipt stay immutable")

	# AC2: hero Block absorbs the retaliation before HP.
	var blocked_party := _party()
	_check(blocked_party.gain_block(1, 1) and blocked_party.get_hero(1).get("block") == 1,
		"AC2 precondition: the attacking front hero really holds one Block")
	enemies = _briar_guard_roster()
	var blocked_pre := enemies.get_enemy(1)
	var blocked_receipt := CombatStatusAttacks.new().resolve_vs_enemy(enemies, 1, 5, {}, {})
	var blocked_result := CombatEnemyKeywordRules.new().resolve_thorns_retaliation(
		blocked_party, 1, blocked_pre, blocked_receipt)
	_check(blocked_result == {"ok": true, "applied": true, "thorns": 3,
		"block_absorbed": 1, "hp_loss": 2},
		"AC2: Thorns 3 spends one hero Block then removes two HP")
	_check(blocked_party.get_hero(1).get("block") == 0
		and blocked_party.get_hero(1).get("hp") == 38
		and blocked_party.get_hero(2).get("hp") == 30
		and blocked_party.get_hero(3).get("hp") == 26,
		"AC2: the attacker ends at zero Block and 38 HP, the rest untouched")

	# AC2: the Guard's own Block may absorb the hit without cancelling Thorns.
	enemies = _briar_guard_roster()
	_check(enemies.gain_block(1, 10) and enemies.get_enemy(1).get("block") == 10,
		"AC2 precondition: the Guard really holds ten Block")
	var armored_pre := enemies.get_enemy(1)
	var armored_receipt := CombatStatusAttacks.new().resolve_vs_enemy(enemies, 1, 5, {}, {})
	_check(armored_receipt == {"ok": true, "damage": 5, "block_absorbed": 5, "hp_loss": 0},
		"AC2: the Guard's Block fully absorbs the confirmed five damage")
	var armored_party := _party()
	var armored_heroes := armored_party.get_heroes()
	var armored_result := CombatEnemyKeywordRules.new().resolve_thorns_retaliation(
		armored_party, 1, armored_pre, armored_receipt)
	_check(armored_result == {"ok": true, "applied": true, "thorns": 3,
		"block_absorbed": 0, "hp_loss": 3},
		"AC2: a fully enemy-Block-absorbed hit still retaliates 3")
	_check(enemies.get_enemy(1).get("hp") == 42 and enemies.get_enemy(1).get("block") == 5
		and armored_party.get_hero(1).get("hp") == armored_heroes[0]["hp"] - 3
		and armored_party.get_hero(2) == armored_heroes[1]
		and armored_party.get_hero(3) == armored_heroes[2],
		"AC2: the absorbing Guard keeps 42 HP and five Block; only the attacker pays")

	# AC3: a confirmed zero-damage hit is inert and changes nothing at all.
	var zero_party := _party()
	enemies = _briar_guard_roster()
	var zero_pre := enemies.get_enemy(1)
	var zero_receipt := CombatStatusAttacks.new().resolve_vs_enemy(enemies, 1, 0, {}, {})
	_check(zero_receipt == {"ok": true, "damage": 0, "block_absorbed": 0, "hp_loss": 0},
		"AC3: the real bridge confirms a zero-damage hit")
	var zero_heroes := zero_party.get_heroes()
	var zero_foes := enemies.get_enemies()
	seed(70732)
	var zero_expected_rng := randi()
	seed(70732)
	var zero_result := CombatEnemyKeywordRules.new().resolve_thorns_retaliation(
		zero_party, 1, zero_pre, zero_receipt)
	_check(zero_result == {"ok": true, "applied": false, "thorns": 3,
		"block_absorbed": 0, "hp_loss": 0},
		"AC3: a zero-damage hit triggers no retaliation")
	_check(zero_party.get_heroes() == zero_heroes and enemies.get_enemies() == zero_foes
		and randi() == zero_expected_rng,
		"AC3: the zero hit changes no party, roster or random number")

	# AC3: a genuinely failed receipt from the real bridge fails closed.
	var dead_party := _party()
	enemies = _briar_guard_roster()
	var dead_pre := enemies.get_enemy(1)
	_check(enemies.apply_damage(1, 42) and enemies.is_slain(1),
		"AC3 precondition: the Guard is genuinely slain")
	var failed_receipt := CombatStatusAttacks.new().resolve_vs_enemy(enemies, 1, 5, {}, {})
	_check(failed_receipt == {"ok": false, "damage": 0, "block_absorbed": 0, "hp_loss": 0},
		"AC3: the real bridge fails a hit on a slain source")
	var dead_heroes := dead_party.get_heroes()
	var dead_result := CombatEnemyKeywordRules.new().resolve_thorns_retaliation(
		dead_party, 1, dead_pre, failed_receipt)
	_check(dead_result == {"ok": false, "applied": false, "thorns": 0,
		"block_absorbed": 0, "hp_loss": 0} and dead_party.get_heroes() == dead_heroes,
		"AC3: a failed receipt fails closed and touches no hero")

	# AC3: the non-Thorns companion never invents a reaction.
	var plain_party := _party()
	enemies = _briar_guard_roster()
	var plain_pre := enemies.get_enemy(2)
	_check(not plain_pre.has("thorns"),
		"AC3 precondition: the companion carries no Thorns keyword")
	var plain_receipt := CombatStatusAttacks.new().resolve_vs_enemy(enemies, 2, 5, {}, {})
	_check(plain_receipt == {"ok": true, "damage": 5, "block_absorbed": 0, "hp_loss": 5},
		"AC3: the companion really absorbs the same confirmed five damage")
	var plain_heroes := plain_party.get_heroes()
	var plain_result := CombatEnemyKeywordRules.new().resolve_thorns_retaliation(
		plain_party, 1, plain_pre, plain_receipt)
	_check(plain_result == {"ok": true, "applied": false, "thorns": 0,
		"block_absorbed": 0, "hp_loss": 0} and plain_party.get_heroes() == plain_heroes
		and enemies.get_enemy(2).get("hp") == 35,
		"AC3: the non-Thorns companion produces no retaliation")


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
	for scenario in [[12, 0, 10, 8, 8], [12, 3, 10, 8, 8],
			[12, 8, 10, 8, 8], [2, 0, 10, 8, 2], [12, 0, 3, 3, 3]]:
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

	# Separate UNFLAGGED Drain control: no chew_block_on_attack, 8 Block absorbs all,
	# zero healing, fail-closed if metadata or state is wrong.
	var unflagged_record := record.duplicate(true)
	unflagged_record.erase("chew_block_on_attack")
	var unflagged_fixture := _new_elite_fixture(unflagged_record)
	if not unflagged_fixture.is_empty():
		var unflagged_party: CombatParty = unflagged_fixture["party"]
		var unflagged_enemies: CombatEnemies = unflagged_fixture["enemies"]
		_check(unflagged_enemies.apply_damage(1, 12)
			and unflagged_party.apply_damage(2, 20) and not unflagged_party.is_downed(2)
			and unflagged_party.gain_block(2, 8)
			and unflagged_party.get_hero(2).get("hp") == 10
			and unflagged_party.get_hero(2).get("block") == 8,
			"unflagged precondition: 12 missing HP, 10 target HP, 8 Block, living")
		var unflagged_heroes := unflagged_party.get_heroes()
		var unflagged_foes := unflagged_enemies.get_enemies()
		var unflagged_beat := _authored_beat(unflagged_record, 1, "attack", 2)
		if not unflagged_beat.is_empty():
			var unflagged_result := CombatEnemyPhase.new().execute_phase(
				unflagged_party, unflagged_enemies, [unflagged_beat])
			unflagged_heroes[1]["block"] = 0
			unflagged_heroes[1]["hp"] = 10
			unflagged_foes[0]["hp"] += 0
			_check(unflagged_result == {"ok": true, "events": [_phase_event(unflagged_beat)]}
				and unflagged_party.get_heroes() == unflagged_heroes
				and unflagged_enemies.get_enemies() == unflagged_foes,
				"unflagged Drain: 8 Block fully absorbs 8 damage, zero HP loss, zero heal")


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


## The new Elite reached exactly as a run would reach an unregistered schedule:
## an actual legal generated Elite node, one local candidate, the production
## selector, and typed assembly from the shipped m04_elites catalog alone.
func _briar_snare_setup(seed_value: int) -> Dictionary:
	var route := _elite_route(seed_value)
	_check(not route.is_empty() and route.get("map") is RunMap,
		"generated map offers a legal Elite node for briar_snare_elite")
	if route.is_empty():
		return {}
	var selector := RunFightEncounterSelection.new()
	var choice := selector.select_current_battle(route.map, route.rng,
		{"Elite": {BRIAR_SNARE_ID: BRIAR_SNARE}})
	_check(choice.get("success") == true and choice.get("node_type") == "Elite"
		and choice.get("encounter_id") == BRIAR_SNARE_ID
		and choice.get("definitions") == BRIAR_SNARE_PATTERNS,
		"production selector picks the sole local briar_snare_elite candidate")
	if not choice.get("success", false):
		return {}
	var parsed := RunFightEncounterSelection._parse_schedule_text(
		FileAccess.get_file_as_string(BRIAR_SNARE))
	_check(parsed == BRIAR_SNARE_PATTERNS,
		"real JSON parses into the exact two-source three-beat schedule")
	var assembled := RunTypedBattleRoster.new().assemble(
		choice, BRIAR_SNARE_ROSTER, [ELITES])
	_check(assembled.get("ok", false),
		"typed assembly reads only the shipped m04_elites catalog")
	if not assembled.get("ok", false):
		return {}
	var enemies: CombatEnemies = assembled.enemies
	_check(enemies.is_valid() and enemies.get_enemies().size() == 2,
		"typed assembly publishes two fixed living source slots")
	return {"route": route, "selector": selector, "choice": choice,
		"enemies": enemies, "definitions": assembled.definitions,
		"rng_state": route.rng.state}


## The two announcements the fixed authored schedule must publish on one beat.
func _briar_snare_beat(beat: int) -> Array:
	var expected: Array = []
	for source in BRIAR_SNARE_PATTERNS:
		var pattern: Array = source["pattern"]
		var action: Dictionary = pattern[beat % pattern.size()].duplicate(true)
		action["enemy_position"] = source["enemy_position"]
		expected.append(action)
	return expected


## Commit one real hero owner-turn status tick the way CombatRoundFlow does:
## HP, Block and statuses only, then leave the actual party authoritative.
func _commit_hero_tick(party: CombatParty) -> void:
	var tick := CombatStatusTurnBatch.new().tick_side("heroes", party.get_heroes())
	_check(tick.get("ok", false), "real hero owner-turn status tick")
	if not tick.get("ok", false):
		return
	var actors: Array = tick.get("actors", [])
	for index in range(CombatParty.PARTY_SIZE):
		var hero: Dictionary = party._heroes[index]
		hero["hp"] = actors[index]["hp"]
		hero["block"] = actors[index]["block"]
		if hero.has("statuses") or not actors[index]["statuses"].is_empty():
			hero["statuses"] = actors[index]["statuses"].duplicate(true)


## Four real beats of the fixed schedule over the authentic roster, including
## the owner-turn tick that follows each enemy phase. Everything is detached and
## returned, so two equal runs can be compared byte for byte.
func _briar_snare_timeline(seed_value: int) -> Dictionary:
	var fixture := _briar_snare_setup(seed_value)
	if fixture.is_empty():
		return {}
	var party := _party()
	var enemies: CombatEnemies = fixture["enemies"]
	_check(CombatStartingBlock.new(party).apply()
		and party.get_hero(1).get("hp") == 40
		and party.get_hero(1).get("block") == CombatStartingBlock.BLOCK_AMOUNT,
		"authentic Warden opens with six Block")
	party._heroes[2]["statuses"] = {"exposed": 2}
	_check(party.get_hero(3).get("id") == "tinker"
		and party.get_hero(3).get("statuses") == {"exposed": 2},
		"rear Tinker carries a real status the shove must preserve")
	var scheduler := CombatEnemyIntents.new(fixture["choice"]["definitions"])
	_check(scheduler.is_valid(), "accepted scheduler for the new schedule")
	var stages: Array = []
	for beat in range(4):
		var expected := _briar_snare_beat(beat)
		var announced := scheduler.get_intents()
		_check(announced == expected,
			"exact two-source announcement for briar_snare beat " + str(beat))
		var input := announced.duplicate(true)
		var result := CombatEnemyPhase.new().execute_phase(party, enemies, announced)
		_check(result.get("ok", false) and result.get("events", []).size() == 2,
			"real phase resolves both sources for briar_snare beat " + str(beat))
		_check(announced == input and scheduler.get_intents() == expected,
			"phase neither rewrites nor advances the briar_snare announcement")
		var stage := {"announced": announced, "result": result,
			"phase_party": party.get_heroes(), "phase_enemies": enemies.get_enemies()}
		_commit_hero_tick(party)
		stage["tick_party"] = party.get_heroes()
		stages.append(stage)
		_check(scheduler.advance_turn(), "advance one fixed briar_snare beat")
	_check(fixture["route"].rng.state == fixture["rng_state"],
		"the fixed schedule and phase spend no run RNG")
	return {"stages": stages, "final_party": party.get_heroes(),
		"final_enemies": enemies.get_enemies(), "rng_state": fixture["rng_state"],
		"choice": fixture["choice"]}


## AC1/AC2/AC3: the new unregistered briar-and-snare schedule reached through a
## real legal Elite node, one fixed local candidate and the shipped catalog; the
## six authored actions run over four beats, replay identically, and rejections
## leave party, roster, selection, source and RNG untouched.
func _test_briar_snare_schedule() -> void:
	seed(64237)
	var expected_global := randi()
	seed(64237)
	var elites := _catalog(ELITES)
	var untouched := elites.duplicate(true)
	var raw_json := FileAccess.get_file_as_string(BRIAR_SNARE)
	var parsed := RunFightEncounterSelection._parse_schedule_text(raw_json)
	var scheduler := CombatEnemyIntents.new(parsed)
	_check(parsed == BRIAR_SNARE_PATTERNS and parsed.size() == 2
		and parsed[0].get("enemy_position") == 1
		and parsed[1].get("enemy_position") == 2,
		"AC1: new JSON is exactly two fixed source definitions in slots 1 and 2")
	_check(scheduler.is_valid() and scheduler.get_intents().size() == 2,
		"AC1: both authored sources form one accepted scheduler")
	_check(parsed[0].get("pattern") == [
		{"type":"attack","amount":9,"target_position":1},
		{"type":"debuff","amount":2,"status":"bleed","target_position":1},
		{"type":"block","amount":8}],
		"AC2: source 1 authors attack 9, Bleed 2, Block 8 in that order")
	_check(parsed[1].get("pattern") == [
		{"type":"shove","amount":0,"target_position":2,"direction":1},
		{"type":"debuff","amount":2,"status":"weak","target_position":3},
		{"type":"attack","amount":8,"target_position":2}],
		"AC2: source 2 authors shove +1, Weak 2, attack 8 in that order")
	var guard := _record(elites, "needle_briar_guard")
	var snare := _record(elites, "spool_snarekeeper")
	_check(guard.get("name") == "Needle Briar Guard" and guard.get("max_hp") == 42
		and guard.get("max_hp") is int
		and guard.get("art_path") == "res://assets/paper/enemies/needle_briar_guard.png"
		and guard.get("thorns") is int and guard.get("thorns") == 3,
		"AC1: Guard keeps its exact name, 42 HP, own art and integer Thorns 3")
	_check(snare.get("name") == "Spool Snarekeeper" and snare.get("max_hp") == 40
		and snare.get("max_hp") is int
		and snare.get("art_path") == "res://assets/paper/enemies/spool_snarekeeper.png"
		and not snare.has("thorns"),
		"AC1: Snarekeeper keeps its exact name, 40 HP, own art and no Thorns")
	for id in V3_2_ELITES:
		var record := _record(elites, id)
		var actions: Array = []
		for raw_action in record.get("intent", {}).get("actions", []):
			var weighted := CombatEnemyIntents.weighted_action(raw_action)
			var body: Dictionary = weighted.get("action", {}).duplicate(true)
			body["weight"] = weighted.get("weight", 0)
			actions.append(body)
		_check(actions == V3_2_ELITES[id]["actions"],
			"AC1: retained exact weighted catalog alternatives " + id)

	var seed_value := _elite_seed()
	_check(seed_value > 0, "AC1: bounded seed sequence discovers a legal Elite node")
	if seed_value < 0:
		return
	var fixture := _briar_snare_setup(seed_value)
	if fixture.is_empty():
		return
	var choice: Dictionary = fixture["choice"]
	var enemies: CombatEnemies = fixture["enemies"]
	var first_enemy := enemies.get_enemy(1)
	var second_enemy := enemies.get_enemy(2)
	_check(first_enemy.get("id") == "needle_briar_guard"
		and first_enemy.get("position") == 1
		and first_enemy.get("name") == "Needle Briar Guard"
		and first_enemy.get("hp") == 42 and first_enemy.get("max_hp") == 42
		and first_enemy.get("block") == 0
		and first_enemy.get("art_path") == guard.get("art_path")
		and first_enemy.get("thorns") is int and first_enemy.get("thorns") == 3
		and first_enemy.get("intent") == guard.get("intent"),
		"AC1: typed slot 1 is the authentic 42 HP thorned Needle Briar Guard")
	_check(second_enemy.get("id") == "spool_snarekeeper"
		and second_enemy.get("position") == 2
		and second_enemy.get("name") == "Spool Snarekeeper"
		and second_enemy.get("hp") == 40 and second_enemy.get("max_hp") == 40
		and second_enemy.get("block") == 0
		and second_enemy.get("art_path") == snare.get("art_path")
		and not second_enemy.has("thorns")
		and second_enemy.get("intent") == snare.get("intent"),
		"AC1: typed slot 2 is the authentic 40 HP Spool Snarekeeper")
	_check(choice.get("definitions") == BRIAR_SNARE_PATTERNS,
		"AC1: the selected choice carries the exact two fixed source schedules")

	var first_timeline := _briar_snare_timeline(seed_value)
	var second_timeline := _briar_snare_timeline(seed_value)
	_check(not first_timeline.is_empty() and not second_timeline.is_empty()
		and first_timeline.get("stages") == second_timeline.get("stages")
		and first_timeline.get("final_party") == second_timeline.get("final_party")
		and first_timeline.get("final_enemies") == second_timeline.get("final_enemies")
		and first_timeline.get("rng_state") == second_timeline.get("rng_state")
		and first_timeline.get("choice") == second_timeline.get("choice"),
		"AC3: same seed replays identical choices, effects and run-RNG state")
	var stages: Array = first_timeline.get("stages", [])
	if stages.size() != 4:
		_check(false, "AC2: four authored beats were observed")
		return

	var beat0: Dictionary = stages[0]
	_check(beat0.get("announced") == _briar_snare_beat(0)
		and beat0.get("result") == {"ok": true, "events": [
			{"type": "attack", "enemy_position": 1, "applied": true,
				"target_position": 1},
			{"type": "shove", "enemy_position": 2, "applied": true,
				"target_position": 2, "direction": 1}]},
		"AC2: beat 0 publishes source 1 attack then source 2 shove in slot order")
	var beat0_party: Array = beat0.get("phase_party", [])
	_check(beat0_party.size() == 3
		and beat0_party[0].get("id") == "warden"
		and beat0_party[0].get("hp") == 37 and beat0_party[0].get("block") == 0,
		"AC2: the authentic six Block absorbs six of nine, removing exactly three HP")
	_check(beat0_party[1].get("id") == "tinker"
		and beat0_party[1].get("position") == 2
		and beat0_party[1].get("hp") == 26
		and beat0_party[1].get("statuses") == {"exposed": 2}
		and beat0_party[2].get("id") == "seamstress"
		and beat0_party[2].get("position") == 3
		and beat0_party[2].get("hp") == 30
		and not beat0_party[2].get("statuses", {}).has("exposed"),
		"AC2: shove +1 swaps the living 2/3 pair and preserves the rear Exposed stack")
	var beat0_enemies: Array = beat0.get("phase_enemies", [])
	_check(beat0_enemies.size() == 2
		and beat0_enemies[0].get("id") == "needle_briar_guard"
		and beat0_enemies[0].get("hp") == 42 and beat0_enemies[0].get("block") == 0
		and beat0_enemies[1].get("id") == "spool_snarekeeper"
		and beat0_enemies[1].get("hp") == 40 and beat0_enemies[1].get("block") == 0,
		"AC2: the first beat leaves both authored enemy sources at full HP")
	var beat0_ticked: Array = beat0.get("tick_party", [])
	_check(beat0_ticked.size() == 3
		and beat0_ticked[0].get("hp") == 37
		and beat0_ticked[1].get("id") == "tinker"
		and beat0_ticked[1].get("statuses") == {"exposed": 1},
		"AC2: the owner-turn tick ages the preserved Exposed without extra HP loss")

	var beat1: Dictionary = stages[1]
	_check(beat1.get("announced") == _briar_snare_beat(1)
		and beat1.get("result") == {"ok": true, "events": [
			{"type": "debuff", "enemy_position": 1, "applied": true,
				"target_position": 1, "status": "bleed"},
			{"type": "debuff", "enemy_position": 2, "applied": true,
				"target_position": 3, "status": "weak"}]},
		"AC2: beat 1 publishes Bleed 2 on slot 1 then Weak 2 on slot 3")
	var beat1_party: Array = beat1.get("phase_party", [])
	_check(beat1_party.size() == 3
		and beat1_party[0].get("id") == "warden"
		and beat1_party[0].get("hp") == 37
		and beat1_party[0].get("statuses") == {"bleed": 2}
		and beat1_party[1].get("id") == "tinker"
		and beat1_party[1].get("statuses") == {"exposed": 1}
		and beat1_party[2].get("id") == "seamstress"
		and beat1_party[2].get("hp") == 30
		and beat1_party[2].get("statuses") == {"weak": 2},
		"AC2: the authored Bleed and Weak land on exactly their announced heroes")
	var beat1_ticked: Array = beat1.get("tick_party", [])
	_check(beat1_ticked.size() == 3
		and beat1_ticked[0].get("hp") == 35
		and beat1_ticked[0].get("statuses") == {"bleed": 1}
		and beat1_ticked[2].get("statuses") == {"weak": 1},
		"AC2: the owner tick removes Bleed N HP and ages both counters to one")
	_check(CombatStatuses.new().adjusted_attack_damage(
			8, beat1_ticked[2].get("statuses", {}), {}) == 6,
		"AC2: the aged Weak 1 still cuts a hero attack from 8 to exactly 6")

	var beat2: Dictionary = stages[2]
	_check(beat2.get("announced") == _briar_snare_beat(2)
		and beat2.get("result") == {"ok": true, "events": [
			{"type": "block", "enemy_position": 1, "applied": true},
			{"type": "attack", "enemy_position": 2, "applied": true,
				"target_position": 2}]},
		"AC2: beat 2 publishes guard Block 8 then the snare attack 8 on slot 2")
	var beat2_party: Array = beat2.get("phase_party", [])
	_check(beat2_party.size() == 3
		and beat2_party[0].get("hp") == 35
		and beat2_party[0].get("statuses") == {"bleed": 1}
		and beat2_party[1].get("id") == "tinker"
		and beat2_party[1].get("position") == 2
		and beat2_party[1].get("hp") == 18
		and beat2_party[2].get("id") == "seamstress"
		and beat2_party[2].get("statuses") == {"weak": 1},
		"AC2: the snare attack removes exactly eight HP from the swapped middle hero")
	var beat2_enemies: Array = beat2.get("phase_enemies", [])
	_check(beat2_enemies.size() == 2
		and beat2_enemies[0].get("id") == "needle_briar_guard"
		and beat2_enemies[0].get("hp") == 42 and beat2_enemies[0].get("block") == 8
		and beat2_enemies[1].get("id") == "spool_snarekeeper"
		and beat2_enemies[1].get("hp") == 40 and beat2_enemies[1].get("block") == 0,
		"AC2: Block 8 shields only the Guard's own slot")
	var beat2_ticked: Array = beat2.get("tick_party", [])
	_check(beat2_ticked.size() == 3
		and beat2_ticked[0].get("hp") == 34
		and beat2_ticked[0].get("statuses", {}).is_empty()
		and beat2_ticked[2].get("statuses", {}).is_empty(),
		"AC2: the owner tick spends the last Bleed HP and expires Weak")

	var beat3: Dictionary = stages[3]
	_check(beat3.get("announced") == stages[0].get("announced")
		and beat3.get("result") == stages[0].get("result"),
		"AC2: the three-beat schedule wraps to its exact first announcement")
	var beat3_party: Array = beat3.get("phase_party", [])
	_check(beat3_party.size() == 3
		and beat3_party[0].get("id") == "warden"
		and beat3_party[0].get("hp") == 25 and beat3_party[0].get("block") == 0
		and beat3_party[1].get("id") == "seamstress"
		and beat3_party[1].get("position") == 2
		and beat3_party[1].get("hp") == 30
		and beat3_party[2].get("id") == "tinker"
		and beat3_party[2].get("position") == 3
		and beat3_party[2].get("hp") == 18,
		"AC2: the wrapped nine removes exactly nine HP and the second shove restores slots")
	var beat3_enemies: Array = beat3.get("phase_enemies", [])
	_check(beat3_enemies.size() == 2
		and beat3_enemies[0].get("hp") == 42 and beat3_enemies[0].get("block") == 8
		and beat3_enemies[1].get("hp") == 40 and beat3_enemies[1].get("block") == 0,
		"AC2: the wrapped beat keeps the Guard Block and both authored HP totals")
	_check(first_timeline.get("final_party") == beat3.get("tick_party")
		and first_timeline.get("final_enemies") == beat3_enemies,
		"AC3: the replay holds the final detached timeline and roster")

	var thorn_fixture := _briar_snare_setup(seed_value)
	if thorn_fixture.is_empty():
		return
	var thorn_roster: CombatEnemies = thorn_fixture["enemies"]
	var pre_hit := thorn_roster.get_enemy(1)
	_check(pre_hit.get("id") == "needle_briar_guard"
		and pre_hit.get("thorns") is int and pre_hit.get("thorns") == 3
		and pre_hit.get("hp") == 42,
		"AC2: the production-assembled Guard still carries Thorns 3 at 42 HP")
	var thorn_party := _party()
	_check(thorn_party.gain_block(1, 1),
		"AC2 precondition: the attacking hero really holds one Block")
	var receipt := CombatStatusAttacks.new().resolve_vs_enemy(thorn_roster, 1, 5, {}, {})
	_check(receipt == {"ok": true, "damage": 5, "block_absorbed": 0, "hp_loss": 5},
		"AC2: the real bridge confirms a five-damage hit on the Guard")
	var thorn_heroes := thorn_party.get_heroes()
	var retaliation := CombatEnemyKeywordRules.new().resolve_thorns_retaliation(
		thorn_party, 1, pre_hit, receipt)
	_check(retaliation == {"ok": true, "applied": true, "thorns": 3,
		"block_absorbed": 1, "hp_loss": 2},
		"AC2: Thorns 3 spends the attacker's one Block then removes two HP")
	_check(thorn_party.get_hero(1).get("hp") == 38
		and thorn_party.get_hero(1).get("block") == 0
		and thorn_party.get_hero(2) == thorn_heroes[1]
		and thorn_party.get_hero(3) == thorn_heroes[2]
		and thorn_roster.get_enemy(1).get("hp") == 37,
		"AC2: only the attacking hero pays; the other heroes and Guard stay exact")
	var zero_fixture := _briar_snare_setup(seed_value)
	if zero_fixture.is_empty():
		return
	var zero_roster: CombatEnemies = zero_fixture["enemies"]
	var zero_pre := zero_roster.get_enemy(1)
	var zero_party := _party()
	var zero_receipt := CombatStatusAttacks.new().resolve_vs_enemy(
		zero_roster, 1, 0, {}, {})
	var zero_heroes := zero_party.get_heroes()
	var zero_foes := zero_roster.get_enemies()
	var zero_result := CombatEnemyKeywordRules.new().resolve_thorns_retaliation(
		zero_party, 1, zero_pre, zero_receipt)
	_check(zero_receipt == {"ok": true, "damage": 0, "block_absorbed": 0, "hp_loss": 0}
		and zero_result == {"ok": true, "applied": false, "thorns": 3,
			"block_absorbed": 0, "hp_loss": 0}
		and zero_party.get_heroes() == zero_heroes
		and zero_roster.get_enemies() == zero_foes,
		"AC2: an unconfirmed zero-damage contact triggers no Thorns retaliation")
	var dead_fixture := _briar_snare_setup(seed_value)
	if dead_fixture.is_empty():
		return
	var dead_roster: CombatEnemies = dead_fixture["enemies"]
	var dead_pre := dead_roster.get_enemy(1)
	_check(dead_roster.apply_damage(1, 42) and dead_roster.is_slain(1),
		"AC2 precondition: the Guard source is genuinely slain")
	var dead_party := _party()
	var dead_heroes := dead_party.get_heroes()
	var dead_receipt := CombatStatusAttacks.new().resolve_vs_enemy(
		dead_roster, 1, 5, {}, {})
	var dead_result := CombatEnemyKeywordRules.new().resolve_thorns_retaliation(
		dead_party, 1, dead_pre, dead_receipt)
	_check(dead_receipt == {"ok": false, "damage": 0, "block_absorbed": 0, "hp_loss": 0}
		and dead_result == {"ok": false, "applied": false, "thorns": 0,
			"block_absorbed": 0, "hp_loss": 0}
		and dead_party.get_heroes() == dead_heroes,
		"AC2: a failed unconfirmed receipt retaliates for nothing")

	_check(RunFightEncounterSelection._parse_schedule_text(
		"[{\"enemy_position\":1,\"pattern\":[{\"type\":\"shove\",\"amount\":0," +
		"\"target_position\":2,\"direction\":2}]}]").is_empty(),
		"AC3: the real parser rejects a malformed authored shove direction")
	_check(RunFightEncounterSelection._parse_schedule_text(
		"[{\"enemy_position\":1,\"pattern\":[{\"type\":\"attack\",\"amount\":2.5," +
		"\"target_position\":1}]}]").is_empty(),
		"AC3: the real parser rejects a fractional authored amount")
	var reject_fixture := _briar_snare_setup(seed_value)
	if reject_fixture.is_empty():
		return
	var reject_party := _party()
	var reject_enemies: CombatEnemies = reject_fixture["enemies"]
	_check(reject_party.apply_damage(3, 26) and reject_party.is_downed(3),
		"AC3 precondition: the shove destination is genuinely downed")
	var shove := {"type": "shove", "amount": 0, "enemy_position": 2,
		"target_position": 2, "direction": 1}
	var reject_choice: Dictionary = reject_fixture["choice"].duplicate(true)
	var reject_snapshot := [reject_party.get_heroes(), reject_enemies.get_enemies(),
		reject_fixture["route"].rng.state, reject_choice]
	var rejected := CombatEnemyPhase.new().execute_phase(
		reject_party, reject_enemies, [shove.duplicate(true)])
	_check(rejected == {"ok": false, "events": []}
		and [reject_party.get_heroes(), reject_enemies.get_enemies(),
			reject_fixture["route"].rng.state, reject_choice] == reject_snapshot,
		"AC3: a shove into a downed destination changes no actor and spends no RNG")
	var malformed_choice: Dictionary = reject_fixture["choice"].duplicate(true)
	malformed_choice["definitions"][1]["pattern"][0]["direction"] = 2
	var malformed_before := malformed_choice.duplicate(true)
	_check(RunTypedBattleRoster.new().assemble(
			malformed_choice, BRIAR_SNARE_ROSTER, [ELITES]) == {"ok": false}
		and malformed_choice == malformed_before,
		"AC3: typed assembly fails closed on a malformed source without mutation")
	var bad_target_party := _party()
	var bad_target_fixture := _briar_snare_setup(seed_value)
	if bad_target_fixture.is_empty():
		return
	var beyond := shove.duplicate(true)
	beyond["target_position"] = 3
	_reject_beat("briar_snare shove beyond the back slot", bad_target_party,
		bad_target_fixture["enemies"], beyond)
	var dead_source_fixture := _briar_snare_setup(seed_value)
	if dead_source_fixture.is_empty():
		return
	var dead_source_party := _party()
	var dead_source_enemies: CombatEnemies = dead_source_fixture["enemies"]
	_check(dead_source_enemies.apply_damage(2, 40)
		and dead_source_enemies.is_slain(2),
		"AC3 precondition: the Snarekeeper source is genuinely slain")
	var dead_source_snapshot := [dead_source_party.get_heroes(),
		dead_source_enemies.get_enemies()]
	_check(CombatEnemyPhase.new().execute_phase(dead_source_party,
			dead_source_enemies, [shove.duplicate(true)]) == {"ok": true, "events": [
				{"type": "shove", "enemy_position": 2, "applied": false,
					"target_position": 2, "direction": 1}]}
		and [dead_source_party.get_heroes(),
			dead_source_enemies.get_enemies()] == dead_source_snapshot,
		"AC3: a slain source's shove stays inert without any mutation")
	_check(elites == untouched and _catalog(ELITES) == untouched
		and FileAccess.get_file_as_string(BRIAR_SNARE) == raw_json,
		"AC3: the shipped catalog and the new on-disk source stay untouched")
	_check(randi() == expected_global,
		"AC3: the complete briar-and-snare case uses no global RNG")



## Replay the real production entry's returned actors and scheduler, not a
## manually assembled local-only Briar test roster.
func _briar_snare_live_trace(entry: Dictionary) -> Array:
	var party := _party()
	var foes: CombatEnemies = entry["enemies"]
	var scheduler: CombatEnemyIntents = entry["intents"]
	_check(CombatStartingBlock.new(party).apply()
		and party.get_hero(1).get("block") == CombatStartingBlock.BLOCK_AMOUNT,
		"live Briar replay starts with authentic Warden Block")
	party._heroes[2]["statuses"] = {"exposed": 2}
	var trace: Array = []
	for beat in range(4):
		var announced := scheduler.get_intents()
		_check(announced == _briar_snare_beat(beat),
			"live Briar registry entry announces exact attack/Bleed/Block and shove/Weak/attack beat " + str(beat))
		var settled := CombatEnemyPhase.new().execute_phase(party, foes, announced)
		_check(settled.get("ok", false) and settled.get("events", []).size() == 2,
			"live Briar roster executes both authored sources on beat " + str(beat))
		var stage := {"announced": announced, "settled": settled,
			"heroes": party.get_heroes(), "enemies": foes.get_enemies()}
		_commit_hero_tick(party)
		stage["tick"] = party.get_heroes()
		trace.append(stage)
		_check(scheduler.advance_turn(), "live Briar scheduler advances beat " + str(beat))
	return trace


## Full shipped pool, real committed Elite route and real production entry.
## A bounded search finds one actual Briar selection; it does not force a
## one-candidate selector or assume a fixed RNG outcome.
func _test_briar_snare_live_registry() -> void:
	var registry = JSON.parse_string(FileAccess.get_file_as_string(
		RunAuthoredBattleEntry.POOLS_PATH))
	_check(registry is Dictionary and registry.get("Elite") is Dictionary
		and registry["Elite"].has(BRIAR_SNARE_ID),
		"AC1: shipped typed registry includes the Briar Snare Elite")
	if not registry is Dictionary or not registry.get("Elite") is Dictionary:
		return
	var binding: Dictionary = registry["Elite"].get(BRIAR_SNARE_ID, {})
	_check(binding.get("schedule") == BRIAR_SNARE and
		binding.get("enemy_ids") == BRIAR_SNARE_ROSTER[BRIAR_SNARE_ID],
		"AC1: shipped Briar entry retains canonical schedule and ordered actors")
	var found: Dictionary = {}
	var service := RunAuthoredBattleEntry.new()
	for trial in range(1, 513):
		var route := _elite_route(trial)
		if route.is_empty():
			continue
		var selector := RunFightEncounterSelection.new()
		var entry := service.entry_current_battle(route.map, route.rng, selector)
		if entry.get("success", false) and entry.get("node_type") == "Elite" \
				and entry.get("encounter_id") == BRIAR_SNARE_ID:
			found = {"seed": trial, "route": route, "selector": selector,
				"entry": entry}
			break
	_check(not found.is_empty(),
		"AC2: within 512 seeds the full production pool selects Briar on a legal Elite node")
	if found.is_empty():
		return
	var route: Dictionary = found["route"]
	var map: RunMap = route["map"]
	var rng: RandomNumberGenerator = route["rng"]
	var selector: RunFightEncounterSelection = found["selector"]
	var selected: Dictionary = found["entry"]
	_check(map.get_current_node_id() == route["node"]
		and map.get_route().has(route["node"])
		and map.get_node(route["node"]).get("type") == "Elite"
		and registry["Elite"].size() > 1,
		"AC2 precondition: a genuinely chosen Elite node uses multiple shipped candidates")
	_check(selected.get("definitions") == BRIAR_SNARE_PATTERNS
		and selected.get("intents") is CombatEnemyIntents
		and selected["intents"].is_valid(),
		"AC2: production entry publishes the exact two-source three-beat schedule")
	var foes: CombatEnemies = selected.get("enemies")
	_check(foes is CombatEnemies and foes.is_valid() and foes.get_enemies().size() == 2,
		"AC2 precondition: live entry has exactly two living real enemies")
	if not foes is CombatEnemies or not foes.is_valid():
		return
	var guard: Dictionary = foes.get_enemy(1)
	var snare: Dictionary = foes.get_enemy(2)
	_check(guard.get("id") == "needle_briar_guard"
		and guard.get("hp") == 42 and guard.get("max_hp") == 42
		and guard.get("thorns") == 3
		and guard.get("art_path") == "res://assets/paper/enemies/needle_briar_guard.png"
		and snare.get("id") == "spool_snarekeeper"
		and snare.get("hp") == 40 and snare.get("max_hp") == 40
		and snare.get("art_path") == "res://assets/paper/enemies/spool_snarekeeper.png",
		"AC2: real entry mounts the exact 42 HP thorned Guard and 40 HP Snarekeeper")
	var initial_defs: Array = selected["definitions"].duplicate(true)
	var after_selection := _snapshot(map, rng, selector)
	var original_trace := _briar_snare_live_trace(selected)
	_check(original_trace.size() == 4
		and original_trace[0]["heroes"][0].get("hp") == 37
		and original_trace[1]["heroes"][0].get("statuses", {}).get("bleed") == 2
		and original_trace[2]["enemies"][0].get("block") == 8
		and original_trace[2]["heroes"][1].get("hp") == 18,
		"AC2: real Briar phase resolves attack 9, Bleed 2, Block 8, shove and Weak")
	_check(_snapshot(map, rng, selector) == after_selection,
		"AC2: live four-beat combat does not redraw the run selector or RNG")

	var replay_route := _elite_route(found["seed"])
	_check(not replay_route.is_empty() and replay_route["node"] == route["node"],
		"AC2: independent same-seed map reconstructs the same legal Elite route")
	if replay_route.is_empty():
		return
	var replay_selector := RunFightEncounterSelection.new()
	var replay := service.entry_current_battle(replay_route.map, replay_route.rng, replay_selector)
	_check(replay.get("success", false) and replay.get("encounter_id") == BRIAR_SNARE_ID
		and replay.get("definitions") == initial_defs and replay_route.rng.state == rng.state,
		"AC2: independent same-seed production entry reselects Briar without RNG drift")
	if not replay.get("success", false):
		return
	var replay_trace := _briar_snare_live_trace(replay)
	_check(replay_trace == original_trace,
		"AC2: independent production battle replays all four announced and resolved phases")

	# Exercise rejection on the same seed that legally selects Briar. None of
	# the invalid production candidate registries may publish a selector entry.
	var clean_route := _elite_route(found["seed"])
	var rejected_selector := RunFightEncounterSelection.new()
	var before := _snapshot(clean_route.map, clean_route.rng, rejected_selector)
	var bad_registries: Array = []
	for mutation in ["wrong_path", "missing_ids", "short_ids", "duplicate_ids", "unknown_id"]:
		var forged: Dictionary = registry.duplicate(true)
		var entry_binding: Dictionary = forged["Elite"][BRIAR_SNARE_ID]
		match mutation:
			"wrong_path":
				entry_binding["schedule"] = "res://data/encounters/needle_marshal_elite.json"
			"missing_ids":
				entry_binding.erase("enemy_ids")
			"short_ids":
				entry_binding["enemy_ids"] = ["needle_briar_guard"]
			"duplicate_ids":
				entry_binding["enemy_ids"] = ["needle_briar_guard", "needle_briar_guard"]
			"unknown_id":
				entry_binding["enemy_ids"] = ["needle_briar_guard", "missing_snarekeeper"]
		bad_registries.append({"label": mutation, "registry": forged})
	for invalid_case in bad_registries:
		_check(service._entry_from_data(clean_route.map, clean_route.rng,
			rejected_selector, invalid_case["registry"]) == {"success": false}
			and _snapshot(clean_route.map, clean_route.rng, rejected_selector) == before,
			"AC3: rejected real Briar binding leaves map/selector/cache/RNG untouched: " + invalid_case["label"])
	var duplicate_source := selected.duplicate()
	duplicate_source["definitions"] = initial_defs.duplicate(true)
	duplicate_source["definitions"][1]["enemy_position"] = 1
	var before_duplicate := _snapshot(clean_route.map, clean_route.rng, rejected_selector)
	_check(RunTypedBattleRoster.new().assemble(duplicate_source,
		BRIAR_SNARE_ROSTER, [ELITES, STARTER, RUN]) == {"ok": false}
		and _snapshot(clean_route.map, clean_route.rng, rejected_selector) == before_duplicate,
		"AC3: duplicate authentic Elite source position fails closed without map/RNG/cache spend")
	var corrected := service.entry_current_battle(
		clean_route.map, clean_route.rng, rejected_selector)
	_check(corrected.get("success", false)
		and corrected.get("encounter_id") == BRIAR_SNARE_ID
		and corrected.get("definitions") == initial_defs
		and clean_route.rng.state == rng.state,
		"AC3: corrected full-registry retry chooses the authentic Elite after all rejections")

	# Returned receipts and actor instances are detached from the cache.
	var cache_before: Dictionary = selector._selected.duplicate(true)
	var cached_rng := rng.state
	selected["definitions"][0]["pattern"].clear()
	selected["enemies"].apply_damage(1, 5)
	selected["encounter_id"] = "forged"
	var cached := service.entry_current_battle(map, rng, selector)
	_check(cached.get("success", false) and cached.get("encounter_id") == BRIAR_SNARE_ID
		and cached.get("definitions") == initial_defs
		and cached.get("enemies") is CombatEnemies
		and cached["enemies"].get_enemy(1).get("hp") == 42
		and cached["enemies"].get_enemy(2).get("hp") == 40
		and rng.state == cached_rng and selector._selected == cache_before
		and _snapshot(map, rng, selector) == after_selection,
		"AC3: detached cache replay returns pristine HP and three beats without extra RNG")
