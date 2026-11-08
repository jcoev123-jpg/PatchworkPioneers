extends SceneTree
## S6 later escort: only legal routed entries, canonical kits and the session's seeded RNG.
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


func _path_from(map: RunMap, node_id: String, target_floor: int, kind: String) -> Array:
	var node := map.get_node(node_id)
	if node.is_empty():
		return []
	if int(node.floor) == target_floor:
		return [node_id] if node.type == kind else []
	if int(node.floor) > target_floor or node.type in ["Fight", "Elite", "Boss"]:
		return []
	for next_id in node.outgoing:
		var tail := _path_from(map, str(next_id), target_floor, kind)
		if not tail.is_empty():
			var route: Array = [node_id]
			route.append_array(tail)
			return route
	return []


func _route(seed_number: int, floor_number: int, kind: String) -> Array:
	var seeded := RandomNumberGenerator.new()
	seeded.seed = seed_number
	var map := RunMap.new()
	if not map.generate(seeded):
		return []
	for start_id in map.get_legal_choices():
		var path := _path_from(map, str(start_id), floor_number, kind)
		if not path.is_empty():
			return path
	return []


func _visit_choice(session: StitchedRunSession) -> Dictionary:
	var actions := session.visit_actions()
	for action in actions:
		if action.id == "leave" and action.enabled:
			return action
	for action in actions:
		if action.enabled:
			return action
	return {}


func _enter_path(seed_number: int, path: Array) -> Dictionary:
	var session := StitchedRunSession.start(seed_number)
	if session == null or path.is_empty():
		return {}
	var before_target := {}
	for index in path.size():
		var node_id: String = path[index]
		if not node_id in session.choices():
			return {}
		var before := session.snapshot()
		var stale := before.duplicate(true)
		stale.candle = int(stale.candle) + 1
		if session.enter(node_id, stale) or session.enter("forged_node", before) \
				or session.snapshot() != before or not session.is_consistent():
			return {}
		if index == path.size() - 1:
			before_target = before
		if not session.enter(node_id, before):
			return {}
		if index == path.size() - 1:
			if session.phase != "battle" or session.battle == null:
				return {}
			break
		if session.phase != "visit":
			return {}
		for visit_step in range(12):
			if session.phase != "visit":
				break
			var action := _visit_choice(session)
			if action.is_empty() or not session.choose_visit(str(action.id), action.arguments, session.snapshot()):
				return {}
		if session.phase != "map":
			return {}
	return {"session": session, "pre": before_target, "route": path.duplicate()}


func _ids(foes: Array) -> Array:
	var result: Array = []
	for foe in foes:
		result.append(str(foe.id))
	return result


func _distinct_count(ids: Array) -> int:
	var distinct: Array = []
	for id in ids:
		if not id in distinct:
			distinct.append(id)
	return distinct.size()


func _expected(run: Dictionary, kind: String) -> Dictionary:
	var session: StitchedRunSession = run.session
	var oracle := RandomNumberGenerator.new()
	oracle.state = int(run.pre.rng)
	var tier: String = {"Fight": "normal", "Elite": "elite", "Boss": "boss"}[kind]
	var primaries: Array = []
	for id in session.enemies.order:
		if session.enemies.enemies[id].tier == tier:
			primaries.append(id)
	primaries.sort()
	if primaries.is_empty():
		return {}
	var chosen: String = primaries[oracle.randi_range(0, primaries.size() - 1)]
	var expected: Array = [chosen]
	for id in ["scissor_crab", "moth_scribe"]:
		if expected.size() == 2 and kind == "Boss":
			break
		if id != chosen:
			expected.append(id)
	var fixed: Array = expected.duplicate()
	var later := session.map.get_current_floor() >= 3 and kind in ["Fight", "Elite"] and expected.size() == 3
	var eligible: Array = []
	if later:
		for id in session.enemies.order:
			if session.enemies.enemies[id].tier == StitchedEnemyCatalog.TIER_NORMAL \
					and id != "moth_scribe" and id != expected[0] and id != expected[1]:
				eligible.append(id)
		eligible.sort()
		if eligible.is_empty():
			return {}
		expected[2] = eligible[oracle.randi_range(0, eligible.size() - 1)]
	return {"ids": expected, "fixed": fixed, "pool": eligible, "later": later, "rng": oracle}


func _verify(run: Dictionary, kind: String, label: String) -> void:
	var session: StitchedRunSession = run.session
	var model := _expected(run, kind)
	_check(not model.is_empty(), label + " has a canonical nonempty selection pool")
	if model.is_empty():
		return
	var selected: Array = session.battle.get_foes()
	var actual_ids := _ids(selected)
	_check(session.battle.is_valid() and selected.size() == model.ids.size() \
		and selected.size() <= 3 and actual_ids == model.ids and session.pending.kind == kind,
		label + " preserves the seeded line-up without adding a fourth foe")
	var ranks_and_kits := true
	for index in selected.size():
		var id: String = str(selected[index].id)
		var canonical := StitchedEnemyCatalog.foe_for(session.enemies, id)
		ranks_and_kits = ranks_and_kits and not canonical.is_empty() \
			and int(selected[index].rank) == index + 1 \
			and selected[index].abilities == canonical.get("abilities", []) \
			and selected[index].max_hp == canonical.get("max_hp") \
			and selected[index].name == canonical.get("name") \
			and session.enemies.enemies.has(id)
	_check(ranks_and_kits and actual_ids.size() == _distinct_count(actual_ids),
		label + " ranks and complete abilities resolve from distinct canonical catalog IDs")
	if model.later:
		_check(model.fixed.size() == 3 and model.fixed[2] == "moth_scribe" \
			and actual_ids[0] == model.fixed[0] and actual_ids[1] == model.fixed[1] \
			and actual_ids[2] in model.pool and actual_ids[2] != "moth_scribe" \
			and session.enemies.enemies[actual_ids[2]].tier == "normal",
			label + " changes only the Moth Scribe slot to one distinct normal escort")
	else:
		_check(actual_ids == model.fixed, label + " preserves the fixed early/Boss/two-foe roster")
	# Independently replay exactly the old primary draw and optional new escort draw,
	# then the actual ranked setup's initiative draws from that oracle RNG.
	var expected_rng: RandomNumberGenerator = model.rng
	var config := session.battle_config.duplicate(true)
	var kits: Array = []
	for id in model.ids:
		kits.append(StitchedEnemyCatalog.foe_for(session.enemies, str(id)))
	config["foes"] = kits
	config["run_rng"] = expected_rng
	var control := StitchedRules.new()
	var setup_error := control._setup(config)
	_check(setup_error.is_empty() and expected_rng.state == session.rng.state \
		and control.state_snapshot() == session.battle.state_snapshot(),
		label + " uses the exact expected selection and initiative RNG draws")


func _replay(run: Dictionary, label: String) -> void:
	var first: StitchedRunSession = run.session
	var repeated := _enter_path(first.seed_value, run.route)
	_check(not repeated.is_empty(), label + " re-enters the identical legal route")
	if repeated.is_empty():
		return
	var second: StitchedRunSession = repeated.session
	_check(first.snapshot() == second.snapshot() and first.journal == second.journal \
		and first.receipts == second.receipts and first.rng.state == second.rng.state,
		label + " matches battle, stop receipts, journal, snapshot and run RNG on replay")
	var first_before := first.snapshot()
	var second_before := second.snapshot()
	var first_action := first.battle.pass_turn()
	var second_action := second.battle.pass_turn()
	_check(first_action.get("ok") == true and first_action == second_action \
		and first.snapshot() != first_before and second.snapshot() != second_before \
		and first.snapshot() == second.snapshot() and first.journal == second.journal \
		and first.receipts == second.receipts and first.rng.state == second.rng.state,
		label + " repeats one authentic ranked command and its sealed RNG/receipts")
	var loaded := StitchedRunSave.restore(StitchedRunSave.capture(first))
	_check(loaded != null and loaded.is_consistent() and loaded.snapshot() == first.snapshot() \
		and loaded.journal == first.journal and loaded.receipts == first.receipts \
		and loaded.rng.state == first.rng.state,
		label + " persists and restores the exact later-battle state")
	if loaded != null:
		var next_original := first.battle.pass_turn()
		var next_loaded := loaded.battle.pass_turn()
		_check(next_original.get("ok") == true and next_original == next_loaded \
			and first.snapshot() == loaded.snapshot() and first.journal == loaded.journal \
			and first.receipts == loaded.receipts and first.rng.state == loaded.rng.state,
			label + " restored battle legally continues the same actions, receipts and RNG")
	var after := first.snapshot()
	_check(not first.enter(str(run.route.back()), first_before) \
		and not first.enter("forged_node", after) and first.snapshot() == after,
		label + " refuses stale and forged post-entry choices without spending")


func _run() -> void:
	var seen_fight := {}
	var seen_elite := {}
	var later_fight := {}
	var later_elite := {}
	var two_late := {}
	var early_two := {}
	var early_three := {}
	var floor_two := {}
	var boss := {}
	for seed_number in range(500):
		for kind in ["Fight", "Elite"]:
			if seed_number >= 140 and not (later_fight.is_empty() if kind == "Fight" else later_elite.is_empty()):
				continue
			var path := _route(seed_number, 3, kind)
			if path.is_empty():
				continue
			var run := _enter_path(seed_number, path)
			if run.is_empty():
				continue
			var session: StitchedRunSession = run.session
			if session.battle.get_foes().size() == 3:
				if kind == "Fight":
					seen_fight[str(session.battle.get_foes()[2].id)] = true
					if later_fight.is_empty() or seen_fight.size() < 3:
						_verify(run, kind, "later Fight seed %d" % seed_number)
					if later_fight.is_empty():
						later_fight = run
				else:
					seen_elite[str(session.battle.get_foes()[2].id)] = true
					if later_elite.is_empty() or seen_elite.size() < 3:
						_verify(run, kind, "later Elite seed %d" % seed_number)
					if later_elite.is_empty():
						later_elite = run
			elif kind == "Fight" and two_late.is_empty():
				two_late = run
				_verify(run, kind, "later genuine two-foe Fight")
		if early_two.is_empty() or early_three.is_empty():
			var opening := _route(seed_number, 1, "Fight")
			if not opening.is_empty():
				var run := _enter_path(seed_number, opening)
				if not run.is_empty():
					if run.session.battle.get_foes().size() == 2 and early_two.is_empty():
						early_two = run
						_verify(run, "Fight", "opening two-foe Fight")
					elif run.session.battle.get_foes().size() == 3 and early_three.is_empty():
						early_three = run
						_verify(run, "Fight", "opening three-foe Fight")
		if floor_two.is_empty():
			var second_path := _route(seed_number, 2, "Fight")
			if not second_path.is_empty():
				var run := _enter_path(seed_number, second_path)
				if not run.is_empty():
					floor_two = run
					_verify(run, "Fight", "floor-two Fight")
		if boss.is_empty():
			var boss_path := _route(seed_number, 12, "Boss")
			if not boss_path.is_empty():
				var run := _enter_path(seed_number, boss_path)
				if not run.is_empty():
					boss = run
					_verify(run, "Boss", "real floor-twelve Boss")
		if seen_fight.size() >= 2 and seen_elite.size() >= 2 \
				and not later_fight.is_empty() and not later_elite.is_empty() \
				and not early_two.is_empty() and not early_three.is_empty() \
				and not floor_two.is_empty() and not two_late.is_empty() and not boss.is_empty():
			break
	_check(seen_fight.size() >= 2 and seen_elite.size() >= 2 \
		and not later_fight.is_empty() and not later_elite.is_empty(),
		"AC1: multiple real seeded floor-three Fights and Elites produce alternative normal third foes")
	_check(not early_two.is_empty() and not early_three.is_empty() and not floor_two.is_empty() \
		and not two_late.is_empty() and not boss.is_empty(),
		"AC2: real opening, floor-two, later two-foe and final Boss paths all have witnesses")
	if not later_fight.is_empty():
		_replay(later_fight, "later Fight")
	if not later_elite.is_empty():
		_replay(later_elite, "later Elite")
	for failure in failures:
		printerr(failure)
	print("stitched_s6_later_foe_escorts_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
