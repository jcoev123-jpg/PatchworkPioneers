extends SceneTree
## Standalone M03 Elite content and real typed combat regression. No live pool edits.

const PATHS := {
	"quiltguard_hex": "res://data/encounters/quiltguard_hex.json",
	"frayline_marshal": "res://data/encounters/frayline_marshal.json",
}
const BINDINGS := {
	"quiltguard_hex": ["button_guard", "spool_hexer"],
	"frayline_marshal": ["needle_marshal", "fray_scavenger"],
}
const CATALOGS := [
	"res://data/enemies/starter_enemies.json",
	"res://data/enemies/run_enemies.json",
	"res://data/enemies/m04_elites.json",
]
const HEROES := "res://data/heroes/starter_party.json"
const EXPECTED := {
	"quiltguard_hex": [
		{"enemy_position": 1, "pattern": [
			{"type": "block", "amount": 3},
			{"type": "attack", "amount": 2, "target_position": 1},
			{"type": "buff", "amount": 2},
			{"type": "attack", "amount": 2, "target_position": 2}]},
		{"enemy_position": 2, "pattern": [
			{"type": "debuff", "amount": 1, "target_position": 1, "status": "exposed"},
			{"type": "attack", "amount": 3, "target_position": 1},
			{"type": "debuff", "amount": 1, "target_position": 3, "status": "weak"},
			{"type": "attack", "amount": 3, "target_position": 2}]}],
	"frayline_marshal": [
		{"enemy_position": 1, "pattern": [
			{"type": "attack", "amount": 3, "target_position": 1},
			{"type": "shove", "amount": 0, "target_position": 2, "direction": 1},
			{"type": "buff", "amount": 3},
			{"type": "attack", "amount": 4, "target_position": 2}]},
		{"enemy_position": 2, "pattern": [
			{"type": "attack", "amount": 2, "target_position": 3},
			{"type": "block", "amount": 2},
			{"type": "attack", "amount": 2, "target_position": 1}]}],
}
const STATS := {
	"button_guard": [16, "res://assets/paper/enemies/button_guard.png"],
	"spool_hexer": [24, "res://assets/paper/enemies/spool_hexer.png"],
	"needle_marshal": [28, "res://assets/paper/enemies/needle_marshal.png"],
	"fray_scavenger": [14, "res://assets/paper/enemies/fray_scavenger.png"],
}
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_content()
	_selection()
	_phase_replays()
	_rejections()
	for issue in failures:
		printerr(issue)
	print("m03_elite_pair_encounters_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _read_schedule(id: String) -> Array:
	var path: String = PATHS[id]
	_check(FileAccess.file_exists(path), "real authored schedule exists: " + id)
	if not FileAccess.file_exists(path):
		return []
	return RunFightEncounterSelection._parse_schedule_text(FileAccess.get_file_as_string(path))


func _records(paths: Array) -> Array:
	var combined: Array = []
	for path in paths:
		_check(FileAccess.file_exists(path), "real catalog exists: " + path)
		if not FileAccess.file_exists(path):
			continue
		var parsed := RunTypedBattleRoster._parse_catalog_text(FileAccess.get_file_as_string(path))
		_check(not parsed.is_empty(), "valid real authored catalog: " + path)
		combined.append_array(parsed)
	return combined


func _record(records: Array, id: String) -> Dictionary:
	var found: Array = records.filter(func(record: Dictionary) -> bool:
		return record.get("id") == id)
	_check(found.size() == 1, "exactly one real catalog record: " + id)
	return found[0].duplicate(true) if found.size() == 1 else {}


func _party() -> CombatParty:
	var records := _records([HEROES])
	var party := CombatParty.new([
		_record(records, "warden"), _record(records, "seamstress"),
		_record(records, "tinker")])
	_check(party.is_valid() and party.get_hero(1).get("hp") == 40
		and party.get_hero(2).get("hp") == 30
		and party.get_hero(3).get("hp") == 26,
		"authored starter positions and max/current HP")
	_check(CombatStartingBlock.new(party).apply()
		and party.get_hero(1).get("block") == 6,
		"real Warden opening six Block")
	return party


func _enemies(id: String) -> CombatEnemies:
	var catalog := _records(CATALOGS)
	var actors: Array = []
	for enemy_id in BINDINGS[id]:
		actors.append(_record(catalog, enemy_id))
	var enemies := CombatEnemies.new(actors)
	_check(enemies.is_valid() and enemies.get_enemies().size() == 2,
		"real two-enemy roster: " + id)
	return enemies


func _content() -> void:
	var catalog := _records(CATALOGS)
	var catalog_copy := catalog.duplicate(true)
	for enemy_id in STATS:
		var record := _record(catalog, enemy_id)
		_check(record.get("max_hp") == STATS[enemy_id][0]
			and record.get("max_hp") is int
			and record.get("art_path") == STATS[enemy_id][1],
			"exact unchanged catalog HP and art: " + enemy_id)
	for id in PATHS:
		var raw := FileAccess.get_file_as_string(PATHS[id])
		var schedule := _read_schedule(id)
		_check(schedule == EXPECTED[id] and schedule.size() == 2,
			"exact two ordered sources and every named beat: " + id)
		var intents := CombatEnemyIntents.new(schedule)
		_check(intents.is_valid(), "production intent validator accepts " + id)
		if not intents.is_valid():
			continue
		_check(schedule[0]["enemy_position"] == 1
			and schedule[1]["enemy_position"] == 2,
			"unique occupied ascending source positions: " + id)
		var enemy := _enemies(id)
		for index in range(2):
			var actor := enemy.get_enemy(index + 1)
			_check(actor.get("id") == BINDINGS[id][index]
				and actor.get("hp") == STATS[actor.get("id", "")][0]
				and actor.get("position") == index + 1 and actor.get("block") == 0,
				"actual bound actor identity, HP and position: " + id)
		var original := schedule.duplicate(true)
		for step in range(13):
			var announced := intents.get_intents()
			var expected: Array = []
			for definition in EXPECTED[id]:
				var pattern: Array = definition["pattern"]
				var beat: Dictionary = pattern[step % pattern.size()].duplicate(true)
				beat["enemy_position"] = definition["enemy_position"]
				expected.append(beat)
			_check(announced == expected,
				"independent periodic announcements %s beat %d" % [id, step])
			announced[0]["amount"] = 999
			_check(intents.get_intents() == expected,
				"announced snapshot is detached %s beat %d" % [id, step])
			_check(intents.advance_turn(), "explicit scheduler advance " + id)
		_check(schedule == original and FileAccess.get_file_as_string(PATHS[id]) == raw,
			"intent reads and wrap never mutate source text or array: " + id)
	_check(catalog == catalog_copy, "entire shared catalog records untouched")


func _rng(value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	return rng


func _elite_route(value: int) -> Dictionary:
	var rng := _rng(value)
	var map := RunMap.new()
	if not map.generate(rng):
		return {}
	for node_id in map.get_legal_choices():
		if map.get_node(node_id).get("type") == "Elite" and map.choose_node(node_id):
			return {"map": map, "rng": rng, "node": node_id}
	return {}


func _seed_with_opening_elite() -> int:
	for candidate in range(1, 129):
		if not _elite_route(candidate).is_empty():
			return candidate
	return -1


func _state(map: RunMap, rng: RandomNumberGenerator,
		selector: RunFightEncounterSelection) -> Dictionary:
	return {"floors": map.get_floors(), "route": map.get_route(),
		"legal": map.get_legal_choices(), "node": map.get_current_node_id(),
		"rng": rng.state, "selected": selector._selected.duplicate(true),
		"bound": selector._bound_map}


func _selection() -> void:
	var chosen_seed := _seed_with_opening_elite()
	_check(chosen_seed > 0, "generated maps expose a legally reachable Elite")
	if chosen_seed < 0:
		return
	for id in PATHS:
		var a := _elite_route(chosen_seed)
		var b := _elite_route(chosen_seed)
		_check(not a.is_empty() and not b.is_empty() and a.node == b.node
			and a.map.get_floors() == b.map.get_floors(),
			"two genuine independent seeded Elite routes: " + id)
		if a.is_empty() or b.is_empty():
			continue
		var first := RunFightEncounterSelection.new()
		var second := RunFightEncounterSelection.new()
		var pool := {"Elite": {}}
		pool["Elite"][id] = PATHS[id]
		var original_pool := pool.duplicate(true)
		var a_choice := first.select_current_battle(a.map, a.rng, pool)
		var b_choice := second.select_current_battle(b.map, b.rng, pool)
		_check(a_choice.get("success") == true and a_choice.get("node_type") == "Elite"
			and a_choice.get("encounter_id") == id and a_choice.get("definitions") == EXPECTED[id],
			"production selector chooses exact focused Elite JSON: " + id)
		_check(a_choice == b_choice and a.rng.state == b.rng.state
			and pool == original_pool, "seeded selection, state and pool replay: " + id)
		if not a_choice.get("success", false):
			continue
		var state_before := _state(a.map, a.rng, first)
		var choice_before := a_choice.duplicate(true)
		var cached := first.select_current_battle(a.map, a.rng, {"Elite": {}})
		_check(cached == choice_before and _state(a.map, a.rng, first) == state_before,
			"claimed selector caches without any further draw: " + id)
		cached["definitions"][0]["pattern"][0]["amount"] = 999
		_check(first.select_current_battle(a.map, a.rng, {"Elite": {}}) == choice_before,
			"returned choice cannot mutate selector cache: " + id)
		var bindings := {}
		bindings[id] = BINDINGS[id].duplicate()
		var original_bindings := bindings.duplicate(true)
		var original_paths := CATALOGS.duplicate()
		var built := RunTypedBattleRoster.new().assemble(a_choice, bindings, CATALOGS)
		var repeated := RunTypedBattleRoster.new().assemble(b_choice, bindings, CATALOGS)
		_check(built.get("ok") == true and repeated.get("ok") == true,
			"real typed assembly succeeds twice: " + id)
		if built.get("ok") and repeated.get("ok"):
			_check(built["enemies"] is CombatEnemies and built["enemies"].is_valid()
				and built["enemies"].get_enemies().size() == 2
				and CombatEnemyIntents.new(built["definitions"]).is_valid(),
				"typed Elite has two real actors and valid real intents: " + id)
			_check(built["enemies"].get_enemies() == repeated["enemies"].get_enemies()
				and built["definitions"] == repeated["definitions"]
				and built["enemies"] != repeated["enemies"],
				"fresh independent typed assembly replay: " + id)
			for index in range(2):
				var actor: Dictionary = built["enemies"].get_enemy(index + 1)
				_check(actor.get("id") == BINDINGS[id][index]
					and actor.get("max_hp") == STATS[actor.get("id", "")][0]
					and actor.get("hp") == actor.get("max_hp")
					and actor.get("position") == index + 1 and actor.get("block") == 0,
					"exact assembled live HP and source binding: " + id)
			_check(built["enemies"].apply_damage(1, 1)
				and built["enemies"].get_enemy(1)["hp"] != repeated["enemies"].get_enemy(1)["hp"],
				"mutating first typed roster never touches replay: " + id)
		_check(_state(a.map, a.rng, first) == state_before
			and a_choice == choice_before and bindings == original_bindings
			and CATALOGS == original_paths,
			"complete original route, caller, catalog paths, cache and RNG detached: " + id)


## Independent oracle for a phase beat. The production phase never calls this.
func _expected_beat(heroes: Array, enemies: Array, action: Dictionary,
		slain_source: int = 0) -> Dictionary:
	var source: int = action["enemy_position"]
	var event := {"type": action["type"], "enemy_position": source,
		"applied": source != slain_source}
	for field in ["target_position", "status", "direction"]:
		if action.has(field):
			event[field] = action[field]
	if source == slain_source:
		return event
	var amount: int = action["amount"]
	match action["type"]:
		"block", "buff":
			enemies[source - 1]["block"] += amount
		"debuff":
			var target: Dictionary = heroes[action["target_position"] - 1]
			var statuses: Dictionary = target.get("statuses", {}).duplicate(true)
			statuses[action["status"]] = statuses.get(action["status"], 0) + amount
			target["statuses"] = statuses
		"shove":
			var start: int = action["target_position"] - 1
			var finish: int = start + action["direction"]
			var displaced: Dictionary = heroes[start]
			heroes[start] = heroes[finish]
			heroes[finish] = displaced
			heroes[start]["position"] = start + 1
			heroes[finish]["position"] = finish + 1
		"attack":
			var target: Dictionary = heroes[action["target_position"] - 1]
			var damage: int = amount
			if enemies[source - 1].get("statuses", {}).get("weak", 0) > 0:
				damage = (damage * 3) / 4
			if target.get("statuses", {}).get("exposed", 0) > 0:
				damage = (damage * 3) / 2
			var absorbed: int = mini(damage, target["block"])
			target["block"] -= absorbed
			var hp_before: int = target["hp"]
			target["hp"] = maxi(0, target["hp"] - (damage - absorbed))
			# The authored confirmed-hit sting: only a source whose record carries
			# the boolean flag and that really removed HP adds one Bleed to the
			# hero who lost it. A fully Blocked hit stays clean.
			var stings: Variant = enemies[source - 1].get("bleed_on_attack", false)
			if stings is bool and stings == true and target["hp"] < hp_before:
				var stung: Dictionary = target.get("statuses", {}).duplicate(true)
				stung["bleed"] = stung.get("bleed", 0) + 1
				target["statuses"] = stung
	return event


func _age_expected(heroes: Array) -> void:
	for hero in heroes:
		var statuses: Dictionary = hero.get("statuses", {})
		hero["hp"] = maxi(0, hero["hp"] - statuses.get("bleed", 0))
		var next_statuses := {}
		for status in statuses:
			if statuses[status] > 1:
				next_statuses[status] = statuses[status] - 1
		if hero.has("statuses") or not next_statuses.is_empty():
			hero["statuses"] = next_statuses


func _phase_replays() -> void:
	for id in PATHS:
		var history: Array = []
		for replay in range(2):
			var party := _party()
			var enemies := _enemies(id)
			var definitions := _read_schedule(id)
			var scheduler := CombatEnemyIntents.new(definitions)
			_check(scheduler.is_valid() and party.is_valid() and enemies.is_valid(),
				"real phase replay preconditions: " + id)
			if not scheduler.is_valid():
				continue
			var original := definitions.duplicate(true)
			var original_text := FileAccess.get_file_as_string(PATHS[id])
			var expected_heroes := party.get_heroes()
			var expected_enemies := enemies.get_enemies()
			var observations: Array = []
			seed(31926)
			var expected_global := randi()
			seed(31926)
			for step in range(13):
				if step > 0:
					var tick := CombatStatusTurnBatch.new().tick_side("heroes", party.get_heroes())
					_check(tick.get("ok") == true, "owner tick remains valid")
					if not tick.get("ok", false):
						break
					for index in range(3):
						var original_actor: Dictionary = party._heroes[index]
						var staged: Dictionary = tick["actors"][index]
						original_actor["hp"] = staged["hp"]
						if original_actor.has("statuses") or not staged["statuses"].is_empty():
							original_actor["statuses"] = staged["statuses"]
					_age_expected(expected_heroes)
				var announced := scheduler.get_intents()
				var current: Array = []
				for definition in EXPECTED[id]:
					var cycle: Array = definition["pattern"]
					var action: Dictionary = cycle[step % cycle.size()].duplicate(true)
					action["enemy_position"] = definition["enemy_position"]
					current.append(action)
				_check(announced == current, "real phase uses exact scheduled beat %s/%d" %
					[id, step])
				var intents_before := announced.duplicate(true)
				var events: Array = []
				for action in current:
					events.append(_expected_beat(expected_heroes, expected_enemies, action))
				# Reverse input deliberately: phase must report ascending source slots.
				var descending := announced.duplicate(true)
				descending.reverse()
				var phase := CombatEnemyPhase.new().execute_phase(party, enemies, descending)
				_check(phase == {"ok": true, "events": events},
					"exact ascending source-order phase events %s/%d" % [id, step])
				_check(party.get_heroes() == expected_heroes
					and enemies.get_enemies() == expected_enemies,
					"full HP/Block/status/positions/enemy state %s/%d" % [id, step])
				_check(announced == intents_before and scheduler.get_intents() == current,
					"phase leaves announcements and scheduler untouched: " + id)
				if id == "quiltguard_hex":
					if step == 0:
						_check(enemies.get_enemy(1)["block"] == 3
							and party.get_hero(1)["block"] == 6
							and party.get_hero(1).get("statuses", {}).get("exposed") == 1,
							"guard blocks while hexer exposes shielded Warden")
					elif step == 1:
						_check(party.get_hero(1)["hp"] == 35
							and party.get_hero(1).get("statuses", {}).get("exposed", 0) == 0,
							"expired Exposed does not exaggerate next-turn damage")
					elif step == 2:
						_check(party.get_hero(3).get("statuses", {}).get("weak") == 1
							and CombatStatuses.new().adjusted_attack_damage(
								4, party.get_hero(3).get("statuses", {}), {}) == 3,
							"real Weak quarter-reduction on the named back hero")
				if id == "frayline_marshal":
					if step == 0:
						_check(party.get_hero(1)["block"] == 3
							and party.get_hero(3)["hp"] == 24,
							"opening marshal hit consumes Warden Block; rear takes 2")
					elif step == 1:
						_check(party.get_hero(2)["id"] == "tinker"
							and party.get_hero(3)["id"] == "seamstress"
							and enemies.get_enemy(2)["block"] == 2,
							"marshal swaps living occupied hero slots; scavenger blocks")
					elif step == 2:
						_check(enemies.get_enemy(1)["block"] == 3
							and party.get_hero(1)["hp"] == 38,
							"marshal's buff is Block, scavenger hits Warden for 2")
				observations.append([announced, phase, party.get_heroes(), enemies.get_enemies()])
				var enemy_tick := CombatStatusTurnBatch.new().tick_side(
					"enemies", enemies.get_enemies())
				_check(enemy_tick.get("ok") == true, "enemy owner boundary valid")
				_check(party.start_player_turn(), "player opening Block resets each round")
				for hero in expected_heroes:
					hero["block"] = 0
				_check(scheduler.advance_turn(), "phase caller explicitly advances")
			_check(randi() == expected_global, "13 actual phases never use global RNG")
			_check(definitions == original
				and FileAccess.get_file_as_string(PATHS[id]) == original_text,
				"thirteen phases leave source and file unchanged: " + id)
			if replay == 0:
				history = observations
			else:
				_check(observations == history,
					"second independent full 12-beat/wrap timeline matches: " + id)
		# A dead second source retains its slot and announcement but cannot act.
		var party := _party()
		var enemies := _enemies(id)
		var scheduler := CombatEnemyIntents.new(_read_schedule(id))
		var second_hp: int = enemies.get_enemy(2)["hp"]
		_check(enemies.apply_damage(2, second_hp) and enemies.is_slain(2),
			"slain enemy slot two established: " + id)
		var heroes_before := party.get_heroes()
		var actors_before := enemies.get_enemies()
		var expected_events: Array = []
		for action in scheduler.get_intents():
			expected_events.append(_expected_beat(heroes_before, actors_before, action, 2))
		var killed_phase := CombatEnemyPhase.new().execute_phase(
			party, enemies, scheduler.get_intents())
		_check(killed_phase == {"ok": true, "events": expected_events}
			and party.get_heroes() == heroes_before
			and enemies.get_enemies() == actors_before
			and not enemies.is_victorious(),
			"dead source suppressed; surviving source remains active: " + id)


func _reject_assembly(choice: Dictionary, bindings: Dictionary, paths: Array,
		map: RunMap, rng: RandomNumberGenerator, selector: RunFightEncounterSelection,
		label: String) -> void:
	var snapshot := _state(map, rng, selector)
	var original_choice := choice.duplicate(true)
	var original_bindings := bindings.duplicate(true)
	var original_paths := paths.duplicate(true)
	seed(19977)
	var global_next := randi()
	seed(19977)
	_check(RunTypedBattleRoster.new().assemble(choice, bindings, paths) == {"ok": false},
		"typed reject " + label)
	_check(_state(map, rng, selector) == snapshot and choice == original_choice
		and bindings == original_bindings and paths == original_paths,
		"rejection does not spend run RNG or mutate caller/cache/route: " + label)
	_check(randi() == global_next, "rejection never spends global RNG: " + label)


func _rejections() -> void:
	var chosen_seed := _seed_with_opening_elite()
	if chosen_seed < 0:
		return
	var setup := _elite_route(chosen_seed)
	if setup.is_empty():
		return
	var map: RunMap = setup.map
	var rng: RandomNumberGenerator = setup.rng
	var selector := RunFightEncounterSelection.new()
	var id := "quiltguard_hex"
	var pool := {"Elite": {}}
	pool["Elite"][id] = PATHS[id]
	var choice := selector.select_current_battle(map, rng, pool)
	_check(choice.get("success") == true and choice.get("encounter_id") == id,
		"invalid-case fixture is a genuinely claimed Elite selector")
	if not choice.get("success", false):
		return
	var binding := {}
	binding[id] = BINDINGS[id].duplicate()
	var missing := binding.duplicate(true)
	missing[id] = [BINDINGS[id][0], "nonexistent_guard"]
	_reject_assembly(choice, missing, CATALOGS, map, rng, selector, "unknown catalog enemy")
	missing[id] = [BINDINGS[id][0], BINDINGS[id][0]]
	_reject_assembly(choice, missing, CATALOGS, map, rng, selector, "reused enemy ID")
	missing[id] = [BINDINGS[id][0]]
	_reject_assembly(choice, missing, CATALOGS, map, rng, selector, "missing bound source")
	_reject_assembly(choice, {}, CATALOGS, map, rng, selector, "wrong source ID / no binding")
	var fake := choice.duplicate(true)
	fake["encounter_id"] = "frayline_marshal"
	_reject_assembly(fake, binding, CATALOGS, map, rng, selector, "foreign encounter ID")
	fake = choice.duplicate(true)
	fake["definitions"][1]["enemy_position"] = 1
	_reject_assembly(fake, binding, CATALOGS, map, rng, selector, "duplicate source slot")
	fake = choice.duplicate(true)
	fake["definitions"][1]["pattern"][0]["status"] = "unavailable_status"
	_reject_assembly(fake, binding, CATALOGS, map, rng, selector, "malformed status field")
	_reject_assembly(choice, binding, CATALOGS + [CATALOGS[0]],
		map, rng, selector, "duplicate shared catalog source")
	for bad_text in [
		'[{"enemy_position":1,"pattern":[{"type":"debuff","amount":1,"target_position":1,"status":"burn"}]}]',
		'[{"enemy_position":1,"pattern":[{"type":"block","amount":1}]},{"enemy_position":1,"pattern":[{"type":"attack","amount":2,"target_position":2}]}]',
		'[{"enemy_position":1.5,"pattern":[{"type":"block","amount":1}]}]',
		'[{"enemy_position":1,"pattern":[{"type":"attack","amount":2.5,"target_position":2}]}]',
	]:
		_check(RunFightEncounterSelection._parse_schedule_text(bad_text).is_empty(),
			"real parser rejects malformed in-memory schema " + bad_text)
	# An already claimed selector is immutable even when given a different pool.
	var snapshot := _state(map, rng, selector)
	var cached := selector.select_current_battle(map, rng, {
		"Elite": {"frayline_marshal": PATHS["frayline_marshal"]}})
	_check(cached == choice and _state(map, rng, selector) == snapshot,
		"claimed selector does not switch encounters or reroll on new pool")
	# Off-route and wrong-kind nodes reject without claiming a cache or RNG draw.
	var fresh_rng := _rng(chosen_seed)
	var fresh_map := RunMap.new()
	_check(fresh_map.generate(fresh_rng), "off-route map is authentic")
	var off_selector := RunFightEncounterSelection.new()
	var before := _state(fresh_map, fresh_rng, off_selector)
	_check(off_selector.select_current_battle(fresh_map, fresh_rng, pool) == {"success": false}
		and _state(fresh_map, fresh_rng, off_selector) == before,
		"uncommitted Elite route rejects without route/cache/RNG mutation")
	var non_elite_id := ""
	for alternative_seed in range(1, 129):
		var trial_rng := _rng(alternative_seed)
		var trial_map := RunMap.new()
		if not trial_map.generate(trial_rng):
			continue
		for node_id in trial_map.get_legal_choices():
			if trial_map.get_node(node_id).get("type") != "Elite":
				non_elite_id = node_id
				fresh_map = trial_map
				fresh_rng = trial_rng
				break
		if not non_elite_id.is_empty():
			break
	_check(not non_elite_id.is_empty()
		and fresh_map.get_legal_choices().has(non_elite_id)
		and fresh_map.choose_node(non_elite_id),
		"a legal non-Elite route is actually committed")
	if not non_elite_id.is_empty():
		off_selector = RunFightEncounterSelection.new()
		before = _state(fresh_map, fresh_rng, off_selector)
		_check(off_selector.select_current_battle(fresh_map, fresh_rng, pool) == {
				"success": false} and _state(fresh_map, fresh_rng, off_selector) == before,
			"unsupported current node rejects without run/global RNG or selector spend")
	# Phase atomic failure after source 1 would have staged actual Block.
	var party := _party()
	var enemies := _enemies(id)
	_check(party.apply_damage(1, 46) and party.is_downed(1),
		"downed debuff target fixture uses actual Block and full HP damage")
	var heroes_before := party.get_heroes()
	var actors_before := enemies.get_enemies()
	var announced := CombatEnemyIntents.new(_read_schedule(id)).get_intents()
	var phase := CombatEnemyPhase.new().execute_phase(party, enemies, announced)
	_check(phase == {"ok": false, "events": []}
		and party.get_heroes() == heroes_before and enemies.get_enemies() == actors_before,
		"later debuff invalidates earlier guard Block atomically without mutations")
