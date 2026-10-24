extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_special_schema()
	_test_one_enemy()
	_test_three_enemies_and_wrap()
	_test_copy_isolation_and_replay()
	_test_no_combat_mutation()
	_test_invalid_schedules()
	_test_authored_catalog_intents()
	_test_weighted_binding_and_policies()
	_test_weighted_announcement_reads_and_rerolls()
	_test_weighted_dead_slots_and_legacy_isolation()
	_test_weighted_rejections()
	_test_behemoth_phase_transition_cache()
	_test_behemoth_phase_fail_closed()
	if failures.is_empty():
		print("combat_enemy_intents_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("combat_enemy_intents_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _attack(amount: int, target: int) -> Dictionary:
	return {"type": "attack", "amount": amount, "target_position": target}


func _block(amount: int) -> Dictionary:
	return {"type": "block", "amount": amount}


func _enemy(position: int, pattern: Array) -> Dictionary:
	return {"enemy_position": position, "pattern": pattern}


func _announced(position: int, action: Dictionary) -> Dictionary:
	var result := action.duplicate(true)
	result["enemy_position"] = position
	return result


func _three_enemies() -> Array:
	# Deliberately shuffled source positions and independently sized patterns.
	return [
		_enemy(3, [_attack(8, 2)]),
		_enemy(1, [_attack(6, 1), _block(4)]),
		_enemy(2, [_block(2), _attack(0, 3), _block(0)])
	]


func _turns() -> Array:
	return [
		[_announced(1, _attack(6, 1)), _announced(2, _block(2)), _announced(3, _attack(8, 2))],
		[_announced(1, _block(4)), _announced(2, _attack(0, 3)), _announced(3, _attack(8, 2))],
		[_announced(1, _attack(6, 1)), _announced(2, _block(0)), _announced(3, _attack(8, 2))],
		[_announced(1, _block(4)), _announced(2, _block(2)), _announced(3, _attack(8, 2))],
		[_announced(1, _attack(6, 1)), _announced(2, _attack(0, 3)), _announced(3, _attack(8, 2))],
		[_announced(1, _block(4)), _announced(2, _block(0)), _announced(3, _attack(8, 2))]
	]


func _test_one_enemy() -> void:
	var schedule := CombatEnemyIntents.new([_enemy(3, [_block(0), _attack(3, 3)])])
	_check(schedule.is_valid(), "single enemy position 3 is valid without renumbering")
	_check(schedule.get_intents() == [_announced(3, _block(0))],
		"turn zero announces zero Block without a target")
	_check(schedule.advance_turn(), "one-enemy advance succeeds")
	_check(schedule.get_intents() == [_announced(3, _attack(3, 3))],
		"second turn announces exact attack hero target 3")
	_check(schedule.advance_turn(), "one-enemy wrap advances")
	_check(schedule.get_intents() == [_announced(3, _block(0))],
		"single enemy loops back to turn zero")


func _test_three_enemies_and_wrap() -> void:
	var definitions := _three_enemies()
	var original := definitions.duplicate(true)
	var schedule := CombatEnemyIntents.new(definitions)
	_check(schedule.is_valid(), "shuffled three-enemy fixture is valid")
	var expected := _turns()
	for turn in range(13):
		var announced := schedule.get_intents()
		_check(announced == expected[turn % expected.size()],
			"turn %d has exact sorted fixed action shapes and independently wrapping cycles" % turn)
		_check(announced.size() == 3
			and announced[0]["enemy_position"] == 1
			and announced[1]["enemy_position"] == 2
			and announced[2]["enemy_position"] == 3,
			"turn %d returns one intent from each fixed enemy position" % turn)
		_check(schedule.advance_turn(), "turn %d advances explicitly" % turn)
	_check(definitions == original, "turn selection and advance never change caller definitions")


func _test_copy_isolation_and_replay() -> void:
	var definitions := _three_enemies()
	var original := definitions.duplicate(true)
	var schedule := CombatEnemyIntents.new(definitions)
	_check(schedule.is_valid(), "isolation schedule is valid before mutations")
	definitions[0]["pattern"][0]["amount"] = 777
	definitions[1]["pattern"][0]["target_position"] = 3
	definitions[2]["pattern"].append(_attack(900, 1))
	definitions.reverse()
	definitions.clear()
	_check(schedule.get_intents() == _turns()[0],
		"caller mutations of nested dictionaries, arrays and order cannot alter schedule")
	var first := schedule.get_intents()
	first[0]["amount"] = 1000
	first[0]["target_position"] = 3
	first[1]["type"] = "attack"
	first[2]["enemy_position"] = 1
	first.append({"invented": true})
	_check(schedule.get_intents() == _turns()[0],
		"editing returned dictionaries or array cannot modify subsequent announcements")
	_check(schedule.advance_turn(), "isolation schedule advances")
	var another := schedule.get_intents()
	another[0].clear()
	another.remove_at(1)
	_check(schedule.get_intents() == _turns()[1],
		"return values from later turns are also independent defensive snapshots")

	var first_replay := CombatEnemyIntents.new(original)
	var second_replay := CombatEnemyIntents.new(original.duplicate(true))
	_check(first_replay.is_valid() and second_replay.is_valid(), "both replay fixtures are valid")
	var trace_a: Array = []
	var trace_b: Array = []
	for turn in range(18):
		trace_a.append(first_replay.get_intents())
		trace_b.append(second_replay.get_intents())
		_check(first_replay.advance_turn() and second_replay.advance_turn(),
			"both replay instances advance at turn %d" % turn)
	_check(trace_a == trace_b, "identical initial patterns and advances have identical complete sequences")
	for turn in range(trace_a.size()):
		_check(trace_a[turn] == _turns()[turn % 6],
			"deterministic replay turn %d matches exact authored cycle" % turn)
	_check(original == _three_enemies(), "replays do not mutate their input")


func _test_no_combat_mutation() -> void:
	var party := CombatParty.new([
		{"id": "a", "max_hp": 10}, {"id": "b", "max_hp": 12}, {"id": "c", "max_hp": 14}])
	_check(party.is_valid(), "combat party fixture is valid")
	_check(party.gain_block(1, 5) and party.apply_damage(2, 3),
		"combat fixture is actually blocked and wounded")
	var state_before := party.get_heroes()
	var scheduler := CombatEnemyIntents.new(_three_enemies())
	_check(scheduler.is_valid(), "nonmutation scheduler is valid")
	for turn in range(10):
		_check(scheduler.get_intents().size() == 3 and scheduler.advance_turn(),
			"selection-only scheduler announces and advances without execution")
	_check(party.get_heroes() == state_before,
		"announcing attacks and Blocks never changes any party HP or Block")


func _reject(name: String, definitions: Array) -> void:
	var before := definitions.duplicate(true)
	var scheduler := CombatEnemyIntents.new(definitions)
	_check(not scheduler.is_valid(), name + ": entirely invalid")
	_check(scheduler.get_intents().is_empty(), name + ": no partial schedule is exposed")
	_check(not scheduler.advance_turn(), name + ": cannot advance invalid schedule")
	_check(scheduler.get_intents().is_empty(), name + ": remains inert after advance")
	_check(definitions == before, name + ": rejection preserves caller definitions")


func _test_invalid_schedules() -> void:
	_reject("empty lineup", [])
	_reject("more than three enemies", [
		_enemy(1, [_block(1)]), _enemy(2, [_block(1)]),
		_enemy(3, [_block(1)]), _enemy(1, [_block(1)])])
	_reject("duplicate occupied position", [_enemy(1, [_attack(1, 1)]), _enemy(1, [_block(1)])])
	for position in [0, -1, 4, null, true, false, "1", 1.0, [], {}]:
		_reject("invalid position " + str(position), [_enemy(2, [_block(1)]),
			{"enemy_position": position, "pattern": [_block(2)]}])
	for invalid in [null, "enemy", [], 3, {}]:
		_reject("malformed definition " + str(invalid), [_enemy(1, [_block(2)]), invalid])
	_reject("missing enemy position", [_enemy(1, [_block(1)]), {"pattern": [_block(2)]}])
	_reject("missing pattern", [_enemy(1, [_block(1)]), {"enemy_position": 2}])
	_reject("unexpected definition key", [_enemy(1, [_block(1)]),
		{"enemy_position": 2, "pattern": [_block(2)], "hp": 10}])
	for pattern in [[], null, "attack", {}, 10, [null], [42], [[]],
		[_block(2), {}], [_attack(6, 1), {"type": "unknown", "amount": 4}]]:
		_reject("empty or malformed pattern " + str(pattern), [
			_enemy(1, [_attack(5, 1)]), {"enemy_position": 2, "pattern": pattern}])
	var bad_actions: Array = [
		{}, {"type": "attack"}, {"type": "block"},
		{"amount": 1}, {"type": "heal", "amount": 3},
		{"type": 4, "amount": 1}, {"type": "attack", "amount": 2},
		{"type": "block", "amount": 2, "target_position": 1},
		{"type": "attack", "amount": 2, "target_position": 1, "status": "poison"},
		{"type": "attack", "amount": 1, "target_position": null},
		{"type": "attack", "amount": 1, "target_position": 0},
		{"type": "attack", "amount": 1, "target_position": 4},
		{"type": "attack", "amount": 1, "target_position": true},
		{"type": "attack", "amount": 1, "target_position": 1.0},
		{"type": "attack", "amount": 1, "target_position": "2"}
	]
	for kind in ["attack", "block"]:
		for amount in [-1, -100, null, true, false, 2.0, "3", [], {}]:
			var action: Dictionary = _attack(1, 1) if kind == "attack" else _block(1)
			action["amount"] = amount
			bad_actions.append(action)
	for bad in bad_actions:
		# A valid earlier enemy and a valid first action must not leak from a bad later action.
		_reject("invalid late action " + str(bad), [
			_enemy(1, [_attack(7, 1)]), _enemy(2, [_block(3), bad])])


func _test_special_schema() -> void:
	var valid: Array = [
		{"type": "shove", "amount": 0, "target_position": 2, "direction": -1},
		{"type": "debuff", "amount": 2, "target_position": 1, "status": "weak"},
		{"type": "buff", "amount": 3}]
	for action in valid:
		_check(CombatEnemyIntents.new([_enemy(1, [action])]).is_valid(), "special schema accepts " + str(action))
		for key in action:
			var missing: Dictionary = action.duplicate(true)
			missing.erase(key)
			_reject("missing special key", [_enemy(1, [_block(1), missing])])
		var extra: Dictionary = action.duplicate(true)
		extra["extra"] = 1
		_reject("extra special key", [_enemy(1, [_block(1), extra])])
		for field in ["amount", "target_position", "direction", "status"]:
			if not action.has(field):
				continue
			for value in [null, true, 0.5, "1", [], {}]:
				var bad: Dictionary = action.duplicate(true)
				bad[field] = value
				_reject("invalid special field", [_enemy(1, [_block(1), bad])])
	for bad in [
		{"type": "shove", "amount": 1, "target_position": 2, "direction": -1},
		{"type": "shove", "amount": 0, "target_position": 1, "direction": -1},
		{"type": "shove", "amount": 0, "target_position": 2, "direction": 0},
		{"type": "debuff", "amount": 1, "target_position": 1, "status": "poison"},
		{"type": "debuff", "amount": 0, "target_position": 1, "status": "weak"},
		{"type": "buff", "amount": 0}]:
		_reject("special range rejection", [_enemy(1, [_block(1), bad])])


func _catalog_records(path: String) -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(parsed is Array and not parsed.is_empty(), "authored catalog parses: " + path)
	return parsed if parsed is Array else []


func _authored_enemy(path: String, id: String) -> Dictionary:
	var matches: Array = _catalog_records(path).filter(
		func(record: Variant) -> bool: return record is Dictionary and record.get("id") == id)
	_check(matches.size() == 1, "authored enemy present exactly once: " + id)
	if matches.size() != 1:
		return {}
	var record: Dictionary = matches[0].duplicate(true)
	# JSON decodes whole numbers as floats; mirror the app's numeric normalization.
	record["max_hp"] = int(record["max_hp"])
	return record


## The nine live enemy IDs each author positive weighted actions and one of the
## four target policies, while keeping their existing identity, HP and art.
func _test_authored_catalog_intents() -> void:
	var authored := {
		"res://data/enemies/starter_enemies.json": {
			"ragling": ["Ragling", 12], "ragling_guard": ["Guard Ragling", 12]},
		"res://data/enemies/run_enemies.json": {
			"fray_scavenger": ["Fray Scavenger", 14], "button_guard": ["Button Guard", 16],
			"spool_stalker": ["Spool Stalker", 14], "seam_ripper": ["Seam Ripper", 18]},
		"res://data/enemies/m04_elites.json": {
			"needle_marshal": ["Needle Marshal", 28], "spool_hexer": ["Spool Hexer", 24]},
		"res://data/enemies/boss.json": {
			"patchwork_behemoth": ["Patchwork Behemoth", 42]},
	}
	var policies: Array[String] = []
	for path in authored:
		for id in authored[path]:
			var record := _authored_enemy(path, id)
			if record.is_empty():
				continue
			_check(record.get("name") == authored[path][id][0] and record.get("max_hp") == authored[path][id][1],
				"authored identity and HP preserved: " + id)
			_check(record.get("art_path") is String
				and String(record["art_path"]).begins_with("res://assets/paper/enemies/"),
				"authored art path preserved: " + id)
			var spec = record.get("intent")
			_check(spec is Dictionary and spec.size() == 2 and spec.get("target") is String
				and spec["target"] in CombatEnemyIntents.TARGET_POLICIES,
				"authored target policy is one of four: " + id)
			if spec is Dictionary and spec.get("target") is String \
					and spec["target"] in CombatEnemyIntents.TARGET_POLICIES \
					and not policies.has(spec["target"]):
				policies.append(spec["target"])
			var actions = spec.get("actions") if spec is Dictionary else null
			_check(actions is Array and not actions.is_empty(), "authored weighted actions exist: " + id)
			if not actions is Array:
				continue
			for raw in actions:
				_check(CombatEnemyIntents.positive_weight(raw.get("weight")) > 0
					if raw is Dictionary else false, "positive integer weight: " + id + " " + str(raw))
				_check(not CombatEnemyIntents.weighted_action(raw).is_empty(),
					"authored alternative validates as an executable action: " + id + " " + str(raw))
	_check(policies.size() == 4, "the nine authored IDs use every target policy")
	# A real authored roster binds and announces exactly one executed shape per slot.
	var roster: Array = [_authored_enemy("res://data/enemies/run_enemies.json", "button_guard"),
		_authored_enemy("res://data/enemies/run_enemies.json", "spool_stalker"),
		_authored_enemy("res://data/enemies/run_enemies.json", "seam_ripper")]
	var enemies := CombatEnemies.new(roster)
	var party := _party_fixture()
	var rng := RandomNumberGenerator.new()
	rng.seed = 71221
	var scheduler := CombatEnemyIntents.new([
		_enemy(1, [_block(1)]), _enemy(2, [_block(1)]), _enemy(3, [_block(1)])])
	_check(enemies.is_valid() and party.is_valid(), "precondition: real three-enemy authored roster")
	_check(scheduler.bind_battle(enemies, party, rng), "authored roster and party bind the weighted cache")
	_check(scheduler.is_bound(), "binding is reported as the weighted mode")
	var announced := scheduler.get_intents()
	_check(announced.size() == 3, "one announcement for every original slot")
	for index in range(announced.size()):
		var action: Dictionary = announced[index]
		var copy: Dictionary = action.duplicate(true)
		_check(copy.get("enemy_position") == index + 1, "announcement keeps its original source slot")
		copy.erase("enemy_position")
		_check(CombatEnemyIntents.valid_action(copy), "announcement is an executable action: " + str(action))
		_check(copy.size() in [2, 3, 4], "announcement keeps the exact published action shape")
		if action.type in ["attack", "debuff", "shove"]:
			_check(action.get("target_position") in [1, 2, 3],
				"targeting announcement names a concrete living target")
			_check(not CombatEnemyIntents.policy_for(enemies, index + 1).is_empty(),
				"the original roster slot keeps its authored policy")
		else:
			_check(not action.has("target_position"), "self action announces no hero target")


func _party_fixture(warden_hp: int = 40, seamstress_hp: int = 30,
		tinker_hp: int = 26) -> CombatParty:
	var party := CombatParty.new([
		{"id": "warden", "max_hp": 40}, {"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26}])
	_check(party.is_valid(), "precondition: three living authored heroes")
	if warden_hp < 40:
		party.apply_damage(1, 40 - warden_hp)
	if seamstress_hp < 30:
		party.apply_damage(2, 30 - seamstress_hp)
	if tinker_hp < 26:
		party.apply_damage(3, 26 - tinker_hp)
	return party


func _policy_enemy(policy: String, actions: Array = [{"type": "attack", "amount": 2, "weight": 1}]) -> Dictionary:
	return {"id": "policy_enemy", "max_hp": 10,
		"intent": {"target": policy, "actions": actions.duplicate(true)}}


func _bound_announcement(policy: String, party: CombatParty, seed_value: int = 900,
		actions: Array = [{"type": "attack", "amount": 2, "weight": 1}]) -> Dictionary:
	var enemies := CombatEnemies.new([_policy_enemy(policy, actions)])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var scheduler := CombatEnemyIntents.new([_enemy(1, [_block(1)])])
	if not enemies.is_valid() or not scheduler.bind_battle(enemies, party, rng):
		return {}
	return scheduler.get_intents()[0] if not scheduler.get_intents().is_empty() else {}


func _test_weighted_binding_and_policies() -> void:
	# Priority policies choose living heroes only; ties break to the front slot.
	var deep_back := _party_fixture(30, 25, 10)
	_check(_bound_announcement("front", deep_back).get("target_position") == 1,
		"front policy announces the front-most living hero")
	_check(_bound_announcement("lowest_living_hp", deep_back).get("target_position") == 3,
		"lowest-HP policy announces the weakest living hero")
	deep_back._heroes[2]["hp"] = 25
	_check(_bound_announcement("lowest_living_hp", deep_back).get("target_position") == 2,
		"equal lowest HP ties to the front-most living slot")
	var exposed := _party_fixture(40, 30, 26)
	exposed._heroes[1]["statuses"] = {"exposed": 2}
	_check(_bound_announcement("exposed", exposed).get("target_position") == 2,
		"exposed policy announces the living Exposed hero")
	_check(_bound_announcement("front", exposed).get("target_position") == 1,
		"another policy ignores the Exposed hero it did not target")
	var no_exposed := _party_fixture(40, 30, 26)
	_check(_bound_announcement("exposed", no_exposed).get("target_position") == 1,
		"exposed policy falls back to the front living hero when nobody is marked")
	# A downed hero is never announced by any policy.
	var wounded := _party_fixture(0, 30, 26)
	for policy in ["front", "lowest_living_hp", "exposed", "random"]:
		var target: int = _bound_announcement(policy, wounded).get("target_position", 0)
		_check(target in [2, 3], "policy " + policy + " skips the downed front hero")
	# Random policy uses the seeded run RNG but stays stable across reads.
	var first := _bound_announcement("random", _party_fixture(), 4242)
	var second := _bound_announcement("random", _party_fixture(), 4242)
	var other := _bound_announcement("random", _party_fixture(), 4343)
	_check(first == second, "same seed announces the same random target")
	_check(first.get("target_position") in [1, 2, 3]
		and other.get("target_position") in [1, 2, 3], "random target is always a living slot")
	# A real weighted choice is drawn from the one run RNG on every commit.
	var choices: Array = [{"type": "attack", "amount": 1, "weight": 3},
		{"type": "attack", "amount": 2, "weight": 1}]
	var seen := {}
	for seed_value in [11, 12, 13, 14, 15, 16]:
		var announced := _bound_announcement("front", _party_fixture(), seed_value, choices)
		_check(announced.get("target_position") == 1, "weighted choice keeps the authored policy target")
		seen[announced.get("amount")] = true
	_check(seen.has(1) and seen.has(2), "both authored alternatives are announced across seeds")
	var shove := _bound_announcement("front", _party_fixture(), 7,
		[{"type": "shove", "amount": 0, "direction": -1, "weight": 1}])
	_check(shove.get("type") == "shove" and shove.get("target_position") == 1
		and shove.get("direction") == 1, "a policy shove flips an illegal direction deterministically")


func _test_weighted_announcement_reads_and_rerolls() -> void:
	var enemies := CombatEnemies.new([
		_authored_enemy("res://data/enemies/run_enemies.json", "button_guard"),
		_authored_enemy("res://data/enemies/run_enemies.json", "fray_scavenger")])
	var party := _party_fixture()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5511
	var scheduler := CombatEnemyIntents.new([_enemy(1, [_block(1)]), _enemy(2, [_block(1)])])
	_check(scheduler.bind_battle(enemies, party, rng), "real roster binds before any hand")
	var committed := rng.state
	var announced := scheduler.get_intents()
	_check(announced.size() == 2 and announced == scheduler.get_intents(),
		"repeated reads return the same cached batch")
	_check(rng.state == committed, "reads never draw from the run RNG")
	for attempt in range(5):
		scheduler.get_intents()
	_check(rng.state == committed and scheduler.get_intents() == announced,
		"presentation reads never reroll or spend RNG")
	var hostile := announced.duplicate(true)
	hostile[0]["amount"] = 999
	hostile[0]["target_position"] = 3
	hostile.clear()
	_check(scheduler.get_intents() == announced, "callers cannot edit the cached batch")
	_check(scheduler.advance_turn(), "one successful phase advances the cache once")
	var next := scheduler.get_intents()
	_check(next.size() == 2 and next == scheduler.get_intents(), "the new batch is a complete cached set")
	_check(rng.state != committed, "a real weighted choice spends the shared run RNG on commit")
	var replay_rng := RandomNumberGenerator.new()
	replay_rng.seed = 5511
	var replay_enemies := CombatEnemies.new([
		_authored_enemy("res://data/enemies/run_enemies.json", "button_guard"),
		_authored_enemy("res://data/enemies/run_enemies.json", "fray_scavenger")])
	var replay := CombatEnemyIntents.new([_enemy(1, [_block(1)]), _enemy(2, [_block(1)])])
	_check(replay.bind_battle(replay_enemies, _party_fixture(), replay_rng),
		"independent same-seed scheduler binds")
	_check(replay.get_intents() == announced and replay.advance_turn()
		and replay.get_intents() == next and replay_rng.state == rng.state,
		"identical seeds commit identical batches and identical RNG states")
	# A single authored alternative never needs a draw.
	var single := CombatEnemies.new([_policy_enemy("front")])
	var quiet_rng := RandomNumberGenerator.new()
	quiet_rng.seed = 601
	var quiet := CombatEnemyIntents.new([_enemy(1, [_block(1)])])
	_check(quiet.bind_battle(single, _party_fixture(), quiet_rng), "single-alternative enemy binds")
	var quiet_state := quiet_rng.state
	_check(quiet.advance_turn() and quiet_rng.state == quiet_state,
		"a slot with no choice consumes no randomness")


func _test_weighted_dead_slots_and_legacy_isolation() -> void:
	var enemies := CombatEnemies.new([
		_authored_enemy("res://data/enemies/run_enemies.json", "button_guard"),
		_authored_enemy("res://data/enemies/run_enemies.json", "fray_scavenger"),
		_authored_enemy("res://data/enemies/run_enemies.json", "seam_ripper")])
	var rng := RandomNumberGenerator.new()
	rng.seed = 8080
	var scheduler := CombatEnemyIntents.new([_enemy(1, [_block(1)]), _enemy(2, [_block(1)]),
		_enemy(3, [_block(1)])])
	_check(scheduler.bind_battle(enemies, _party_fixture(), rng), "three-slot roster binds")
	_check(enemies.apply_damage(2, 14) and enemies.is_slain(2), "precondition: middle source slain")
	_check(scheduler.advance_turn(), "a phase after a death still commits one new batch")
	var announced := scheduler.get_intents()
	_check(announced.size() == 3 and announced[0].enemy_position == 1
		and announced[1].enemy_position == 2 and announced[2].enemy_position == 3,
		"a slain source keeps its original announcement slot")
	# The legacy constructor is not a bound fight: it keeps its pattern behavior.
	var definitions := _three_enemies()
	var legacy := CombatEnemyIntents.new(definitions)
	_check(legacy.is_valid() and not legacy.is_bound(), "legacy pattern scheduler stays unbound")
	_check(legacy.get_intents() == _turns()[0], "binding does not change independent legacy fixtures")
	_check(legacy.advance_turn() and legacy.get_intents() == _turns()[1],
		"an unbound legacy scheduler still cycles its authored pattern")


func _reject_bind(name: String, spec: Variant) -> void:
	var record := {"id": "reject_enemy", "max_hp": 10}
	if spec != null:
		record["intent"] = spec
	var enemies := CombatEnemies.new([record])
	var party := _party_fixture()
	var rng := RandomNumberGenerator.new()
	rng.seed = 313
	var before := rng.state
	var scheduler := CombatEnemyIntents.new([_enemy(1, [_attack(2, 1)])])
	_check(enemies.is_valid(), name + ": fixture roster is structurally valid")
	_check(not scheduler.bind_battle(enemies, party, rng), name + ": authored intent rejection")
	_check(rng.state == before, name + ": rejection spends no run RNG")
	_check(not scheduler.is_bound() and scheduler.get_intents() == [_announced(1, _attack(2, 1))],
		name + ": rejection keeps the validated legacy schedule intact")


func _test_weighted_rejections() -> void:
	_check(CombatEnemyIntents.weighted_action({"type": "attack", "amount": 1, "weight": 2}).size() == 2,
		"precondition: a valid weighted action is accepted")
	for bad in [
		null, [], "intent", 0, {},
		{"target": "front"}, {"actions": [{"type": "attack", "amount": 1, "weight": 1}]},
		{"target": "nearest", "actions": [{"type": "attack", "amount": 1, "weight": 1}]},
		{"target": 1, "actions": [{"type": "attack", "amount": 1, "weight": 1}]},
		{"target": "front", "actions": []},
		{"target": "front", "actions": [{"type": "attack", "amount": 1, "weight": 0}]},
		{"target": "front", "actions": [{"type": "attack", "amount": 1, "weight": -1}]},
		{"target": "front", "actions": [{"type": "attack", "amount": 1, "weight": 1.5}]},
		{"target": "front", "actions": [{"type": "attack", "amount": 1, "weight": "1"}]},
		{"target": "front", "actions": [{"type": "attack", "amount": 1, "weight": true}]},
		{"target": "front", "actions": [{"type": "attack", "amount": 1, "weight": 1, "target_position": 2}]},
		{"target": "front", "actions": [{"type": "attack", "amount": 1, "weight": 1, "extra": 1}]},
		{"target": "front", "actions": [{"type": "heal", "amount": 1, "weight": 1}]},
		{"target": "front", "actions": [{"type": "attack", "amount": -1, "weight": 1}]},
		{"target": "front", "actions": [{"type": "attack", "amount": 1.5, "weight": 1}]},
		{"target": "front", "actions": [{"type": "debuff", "amount": 1, "weight": 1}]},
		{"target": "front", "actions": [{"type": "debuff", "amount": 1, "status": "poison", "weight": 1}]},
		{"target": "front", "actions": [{"type": "shove", "amount": 0, "weight": 1}]},
		{"target": "front", "actions": [{"type": "shove", "amount": 1, "direction": 1, "weight": 1}]},
		{"target": "front", "actions": [{"type": "block", "amount": 1, "weight": 1, "target_position": 1}]},
		{"target": "front", "actions": [{"type": "buff", "amount": 0, "weight": 1}]},
		{"target": "front", "actions": [
			{"type": "attack", "amount": 1, "weight": 9223372036854775807},
			{"type": "attack", "amount": 1, "weight": 9223372036854775807}]},
		{"target": "front", "actions": [{"type": "attack", "amount": 1, "weight": 1}], "extra": 1}]:
		_reject_bind("invalid authored intent " + str(bad), bad)
	# A roster with any source lacking authored intent fails closed as a whole.
	var mixed := CombatEnemies.new([
		_authored_enemy("res://data/enemies/run_enemies.json", "button_guard"),
		{"id": "unreadable", "max_hp": 10}])
	var rng := RandomNumberGenerator.new()
	rng.seed = 71
	var before := rng.state
	var scheduler := CombatEnemyIntents.new([_enemy(1, [_block(1)]), _enemy(2, [_block(1)])])
	_check(mixed.is_valid() and not scheduler.bind_battle(mixed, _party_fixture(), rng),
		"a roster with one unauthored source rejects the whole binding")
	_check(rng.state == before and scheduler.get_intents() == [_announced(1, _block(1)), _announced(2, _block(1))],
		"mixed roster rejection leaves the schedule and RNG untouched")
	# Null/mismatched collaborators and double binding fail closed.
	var real := CombatEnemies.new([
		_authored_enemy("res://data/enemies/run_enemies.json", "button_guard")])
	var bound := CombatEnemyIntents.new([_enemy(1, [_block(1)])])
	var bind_rng := RandomNumberGenerator.new()
	bind_rng.seed = 88
	_check(not bound.bind_battle(null, _party_fixture(), bind_rng)
		and not bound.bind_battle(real, null, bind_rng)
		and not bound.bind_battle(real, _party_fixture(), null),
		"missing roster, party or generator is rejected")
	_check(not CombatEnemyIntents.new([]).bind_battle(real, _party_fixture(), bind_rng),
		"an invalid legacy schedule cannot bind a fight")
	var wrong_size := CombatEnemyIntents.new([_enemy(1, [_block(1)]), _enemy(2, [_block(1)])])
	_check(not wrong_size.bind_battle(real, _party_fixture(), bind_rng),
		"a roster whose slot count differs from the validated schedule is rejected")
	_check(bound.bind_battle(real, _party_fixture(), bind_rng) and bound.is_bound(),
		"a validated one-slot roster binds")
	_check(not bound.bind_battle(real, _party_fixture(), bind_rng),
		"an already bound fight cannot bind twice")




func _boss_fixture() -> Dictionary:
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies/boss.json"))
	_check(catalog is Array and catalog.size() == 1, "boss fixture: real catalog contains Behemoth")
	if not catalog is Array or catalog.size() != 1:
		return {}
	var record: Dictionary = catalog[0].duplicate(true)
	record["max_hp"] = int(record["max_hp"])
	return record


func _phase_two_fixture() -> Dictionary:
	var phase: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		CombatBehemothPhaseRules.PHASE_TWO_PATH))
	_check(phase is Dictionary, "phase two fixture: real authored JSON parses")
	return phase if phase is Dictionary else {}


func _assert_boss_slot(slot: Dictionary, amount: int, policy: String, label: String) -> void:
	_check(slot.get("enemy_position") == 1 and slot.get("target") == policy,
		label + ": original slot and precise policy")
	var actions: Array = slot.get("actions", [])
	_check(actions.size() == 3, label + ": three authored alternatives")
	if actions.size() != 3:
		return
	_check(actions[0] == {"weight": 4, "action": {"type": "attack", "amount": amount}}
		and actions[1] == {"weight": 2, "action": {"type": "block", "amount": 3}}
		and actions[2] == {"weight": 1, "action": {"type": "debuff", "amount": 1, "status": "weak"}},
		label + ": exact 4:2:1 weights, attack, Block 3 and Weak 1")


func _test_behemoth_phase_transition_cache() -> void:
	var source := _boss_fixture()
	var phase := _phase_two_fixture()
	if source.is_empty() or phase.is_empty():
		return
	var enemies := CombatEnemies.new([source])
	var party := _party_fixture(35, 5, 8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 18721
	var schedule := CombatEnemyIntents.new([_enemy(1, [_block(1)])])
	_check(enemies.is_valid() and schedule.bind_battle(enemies, party, rng),
		"canonical real Behemoth binds at 42 HP")
	if not schedule.is_bound():
		return
	_assert_boss_slot(schedule._slots[0], 2, "front", "42 HP")
	_check(CombatEnemyIntents.policy_for(enemies, 1) == "front",
		"executor policy is front for phase one")
	var first := schedule.get_intents()
	_check(first.size() == 1 and first[0].enemy_position == 1,
		"real Boss has one cached slot")
	var before := rng.state
	_check(enemies.gain_block(1, 6) and enemies.apply_damage(1, 6)
		and enemies.get_enemy(1).hp == 42, "Block absorbs damage without lowering HP")
	_check(schedule.get_intents() == first and rng.state == before,
		"Block and read cannot transition or spend RNG")
	_check(enemies.apply_damage(1, 20) and enemies.get_enemy(1).hp == 22
		and schedule.advance_turn(), "22 HP advances in phase one")
	_assert_boss_slot(schedule._slots[0], 2, "front", "22 HP")
	var locked := schedule.get_intents()
	before = rng.state
	_check(enemies.apply_damage(1, 1) and enemies.get_enemy(1).hp == 21,
		"player hit crosses the actual half-HP boundary")
	for ignored in range(5):
		var hostile := schedule.get_intents()
		hostile[0]["amount"] = 999
	_check(schedule.get_intents() == locked and rng.state == before
		and CombatEnemyIntents.policy_for(enemies, 1) == "front",
		"threshold does not rewrite the current announcement or policy on reads")
	_check(schedule.advance_turn(), "next committed roll transitions phase")
	_assert_boss_slot(schedule._slots[0], 4, "lowest_living_hp", "21 HP")
	_check(schedule._boss_phase == 2 and
		CombatEnemyIntents.policy_for(enemies, 1) == "lowest_living_hp",
		"cached phase and authoritative executor policy switch together")
	var next := schedule.get_intents()
	_check(next.size() == 1 and next[0].get("enemy_position") == 1
		and (next[0].get("amount") in [1, 3, 4]),
		"21 HP publishes one phase-two action with authored amount")
	before = rng.state
	_check(next == schedule.get_intents() and rng.state == before,
		"phase two remains stable across repeated reads")
	_check(enemies.apply_damage(1, 20) and enemies.get_enemy(1).hp == 1
		and schedule.advance_turn() and schedule._boss_phase == 2,
		"living 1 HP Behemoth retains phase two")
	_assert_boss_slot(schedule._slots[0], 4, "lowest_living_hp", "1 HP")
	_check(enemies.apply_damage(1, 1) and enemies.is_slain(1)
		and schedule.advance_turn() and enemies.get_enemy(1).hp == 0,
		"slain Behemoth stays in its slot and advances inertly")
	var heroes_before := party.get_heroes()
	var result := CombatEnemyPhase.new().execute_phase(
		party, enemies, schedule.get_intents(), null, true)
	_check(result.get("ok", false) and result.events.size() == 1
		and not result.events[0].applied and party.get_heroes() == heroes_before,
		"0 HP Behemoth never executes its cached action")
	# Authored caller-owned data cannot mutate phase choices after binding.
	source["intent"]["actions"][0]["amount"] = 999
	phase["intent"]["actions"][0]["amount"] = 999
	_check(schedule._boss_definition.intent.actions[0].amount != 999
		and schedule._phase_two_record.intent.actions[0].amount != 999,
		"both bound authored definitions are detached")


func _test_behemoth_phase_fail_closed() -> void:
	var boss := _boss_fixture()
	var phase := _phase_two_fixture()
	if boss.is_empty() or phase.is_empty():
		return
	for variant in ["missing", "wrong_threshold", "wrong_action", "counterfeit",
			"wrong_roster_name", "mixed_boss_roster"]:
		var source: Variant = boss.duplicate(true)
		var p2: Variant = phase.duplicate(true)
		var roster := [boss.duplicate(true)]
		if variant == "missing":
			p2 = null
		elif variant == "wrong_threshold":
			p2["threshold_hp"] = 20
		elif variant == "wrong_action":
			p2["intent"]["actions"][0]["amount"] = 3
		elif variant == "counterfeit":
			source["id"] = "false_behemoth"
		elif variant == "wrong_roster_name":
			roster[0]["name"] = "Impostor"
		else:
			roster.append({"id": "ordinary", "max_hp": 5,
				"intent": {"target": "front", "actions": [
					{"type": "attack", "amount": 1, "weight": 1}]}})
		var enemies := CombatEnemies.new(roster)
		var party := _party_fixture()
		var rng := RandomNumberGenerator.new()
		rng.seed = 9000
		var initial_rng := rng.state
		var initial_enemies := enemies.get_enemies()
		var initial_party := party.get_heroes()
		var schedule := CombatEnemyIntents.new([_enemy(1, [_block(1)])]
			if roster.size() == 1 else [_enemy(1, [_block(1)]), _enemy(2, [_block(1)])])
		var fixed := schedule.get_intents()
		_check(not schedule._bind_battle_with_phase_data(enemies, party, rng, source, p2),
			variant + ": invalid Boss metadata fails before binding")
		_check(not schedule.is_bound() and schedule.get_intents() == fixed
			and rng.state == initial_rng and enemies.get_enemies() == initial_enemies
			and party.get_heroes() == initial_party,
			variant + ": rejection publishes no cache, RNG draw or combat mutation")
