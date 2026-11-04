extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_attack_move_schema()
	_test_seam_ripper_routed_named_attacks()
	_test_scissor_crab_routed_named_attacks()
	_test_scavenger_gold_cache()
	_test_two_hit_schema()
	_test_special_schema()
	_test_snip_schema()
	_test_snip_bound_phases_and_badge()
	_test_one_enemy()
	_test_three_enemies_and_wrap()
	_test_four_enemies_and_wrap()
	_test_four_source_copy_isolation_and_replay()
	_test_four_catalog_binding()
	_test_copy_isolation_and_replay()
	_test_no_combat_mutation()
	_test_invalid_schedules()
	_test_authored_catalog_intents()
	_test_guard_ragling_shield_rush()
	_test_weighted_binding_and_policies()
	_test_weighted_announcement_reads_and_rerolls()
	_test_weighted_dead_slots_and_legacy_isolation()
	_test_weighted_rejections()
	_test_inkbrush_blind_schema()
	_test_behemoth_phase_transition_cache()
	_test_behemoth_phase_fail_closed()
	_test_boss_named_kits()
	_test_termite_split_admission()
	_test_ram_charge_seeded_cache()
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


func _test_attack_move_schema() -> void:
	var raw := {"type": "attack", "amount": 6, "weight": 1, "move": "attack2"}
	var normalized := CombatEnemyIntents.weighted_action(raw)
	_check(normalized == {"weight": 1, "action": {"type": "attack", "amount": 6, "move": "attack2"}},
		"keyed attack normalizes without losing move")
	for value in [null, 2, true, [], {}, "", "attack", "unknown", " attack2"]:
		var bad := raw.duplicate(true)
		bad.move = value
		_check(CombatEnemyIntents.weighted_action(bad).is_empty(), "invalid weighted move value rejects")
		bad.erase("weight")
		bad.target_position = 1
		_check(not CombatEnemyIntents.valid_action(bad), "invalid executable move value rejects")
	for kind in ["block", "buff", "debuff", "shove", "snip_block", "summon", "steal_gold"]:
		var bad := raw.duplicate(true)
		bad.type = kind
		_check(CombatEnemyIntents.weighted_action(bad).is_empty(), "move forbidden on " + kind)
	var extra := raw.duplicate(true)
	extra["pose"] = "attack2"
	_check(CombatEnemyIntents.weighted_action(extra).is_empty(), "arbitrary extra key rejects with real move")
	extra.erase("weight")
	extra.target_position = 1
	_check(not CombatEnemyIntents.valid_action(extra), "arbitrary executable key rejects")


class MissingSeamPose extends LiveMovePoseCatalog:
	func _art_available(_path: String) -> bool:
		return false


func _seam_route(count: int) -> Dictionary:
	# Seam Ripper belongs to the middle floor band. Commit legal map choices to it.
	for seed_value in range(1, 180):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var map := RunMap.new()
		if not map.generate(rng):
			continue
		while map.get_current_floor() < 8:
			var choices := map.get_legal_choices()
			if choices.is_empty():
				break
			var node: String = choices[0]
			for candidate in choices:
				if map.get_node(candidate).get("type") == "Fight":
					node = candidate
					break
			if not map.choose_node(node):
				break
			if map.get_current_floor() < 5 or map.get_node(node).get("type") != "Fight":
				continue
			var entry := RunAuthoredBattleEntry.new().entry_current_battle(
				map, rng, RunFightEncounterSelection.new())
			if entry.get("success", false):
				var ids: Array = entry.enemies.get_enemies().map(func(actor): return actor.id)
				if ids.size() == count and ids.has("seam_ripper"):
					return {"seed": seed_value, "route": map.get_route(), "ids": ids}
	return {}


func _test_seam_ripper_routed_named_attacks() -> void:
	for count in [2, 3]:
		var fixture := _seam_route(count)
		_check(not fixture.is_empty(), "Seam Ripper has an authentic routed %d-foe Fight" % count)
		if fixture.is_empty():
			continue
		for floor_number in [1, 5, 9]:
			var traces := []
			for replay in range(2):
				var rng := RandomNumberGenerator.new()
				rng.seed = fixture.seed
				var map := RunMap.new()
				_check(map.generate(rng), "real map generates")
				# Earlier encounter admissions spend the same run RNG as fixture discovery.
				for node in fixture.route:
					_check(map.choose_node(node), "real Fight route commits a legal step")
					if node != fixture.route.back() and map.get_current_floor() >= 5 \
							and map.get_node(node).get("type") == "Fight":
						_check(RunAuthoredBattleEntry.new().entry_current_battle(
							map, rng, RunFightEncounterSelection.new()).get("success", false), "prior routed Fight admits")
				var entry := RunAuthoredBattleEntry.new().entry_current_battle(
					map, rng, RunFightEncounterSelection.new())
				_check(entry.get("success", false), "real Seam Ripper entry succeeds")
				if not entry.get("success", false):
					return
				var definitions: Array = entry.enemies.get_enemies()
				_check(definitions.map(func(actor): return actor.id) == fixture.ids,
					"same-seed route supplies the original living group")
				# Apply the shipped floor transform before binding, as the live caller does.
				for actor in definitions:
					actor.max_hp = RunNormalAttackFloorScaling.scale_normal_max_hp(actor.max_hp, floor_number).max_hp
					for raw in actor.intent.actions:
						if raw.type == "attack":
							raw.amount = RunNormalAttackFloorScaling.scale_normal_attack(int(raw.amount), floor_number).amount
				var enemies := CombatEnemies.new(definitions)
				var target := 2 if count == 2 else 3
				var party := _party_fixture(0, 20 if target == 2 else 22, 20 if target == 3 else 22)
				party._heroes[target - 1].statuses = {"bleed": 2}
				var scheduler: CombatEnemyIntents = entry.intents
				_check(enemies.is_valid() and party.is_downed(1) and not party.is_downed(target)
					and scheduler.bind_battle(enemies, party, rng), "weighted real group binds with living lowest-HP recipient")
				if not scheduler.is_bound():
					return
				var source: int = fixture.ids.find("seam_ripper") + 1
				var seen := {}
				var trace := []
				for turn in range(128):
					var actions := scheduler.get_intents()
					var state := rng.state
					_check(actions.size() == count and scheduler.get_intents() == actions and rng.state == state,
						"all real sources announce and repeated previews spend no RNG")
					trace.append([actions.duplicate(true), state])
					var action: Dictionary = actions[source - 1]
					if action.has("move"):
						var move: String = action.move
						var amount: int = {1: [6, 7], 5: [7, 8], 9: [9, 10]}[floor_number][0 if move == "attack2" else 1]
						_check(move in ["attack2", "attack3"] and action.type == "attack"
							and action.amount == amount and action.target_position == target,
							"distinct keyed base hit retains truncating floor scaling and lowest-living-HP target")
						var snapshot := [party.get_heroes(), enemies.get_enemies(), rng.state, scheduler.get_intents()]
						var fallback := "res://assets/paper/enemies/seam_ripper_attack.png"
						var title := "Hook Rip" if move == "attack2" else "Ripper Throw"
						for catalog in [LiveMovePoseCatalog.new(), MissingSeamPose.new()]:
							var receipt: Dictionary = catalog.lookup_enemy("seam_ripper", action, fallback)
							_check(receipt.get("name") == title and receipt.get("pose") == move
								and receipt.get("named_art") == "res://assets/paper/enemies/seam_ripper_%s.png" % move
								and receipt.get("art") == (receipt.get("named_art") if receipt.get("art_available") else fallback),
								"routed action projects its authentic name and usable art/fallback")
							if catalog is MissingSeamPose:
								_check(receipt.get("fallback_used") == true, "forced unavailable Seam Ripper pose falls back")
						_check(snapshot == [party.get_heroes(), enemies.get_enemies(), rng.state, scheduler.get_intents()],
							"named previews preserve all actors, statuses, intent cache and RNG")
						var phase := CombatEnemyPhase.new()
						for bad_move in [null, 2, "unknown", "attack4"]:
							var forged := action.duplicate(true)
							forged.move = bad_move
							_check(phase.execute_phase(party, enemies, [forged], null, true, null, 19)
								== {"ok": false, "events": []}
								and snapshot == [party.get_heroes(), enemies.get_enemies(), rng.state, scheduler.get_intents()],
								"malformed or unauthored move refuses atomically without wallet/actor/RNG effects")
						# Isolate this authentic source's beat so companions cannot mask collateral.
						for block in [3, 12]:
							_check(party.gain_block(target, block), "living recipient gains real Block")
							var before := party.get_heroes()
							var expected: Array = before.duplicate(true)
							expected[target - 1].hp -= maxi(0, amount - block)
							expected[target - 1].block = maxi(0, block - amount)
							var result := phase.execute_phase(party, enemies, [action], null, true, null, 19)
							_check(result == {"ok": true, "gold": 19, "events": [{"type": "attack",
								"enemy_position": source, "target_position": target, "move": move, "applied": true}]}
								and party.get_heroes() == expected and enemies.get_enemies() == snapshot[1]
								and rng.state == state and scheduler.get_intents() == actions,
								"named hit spends Block before HP exactly once; wallets, statuses and all other actors intact")
							trace.append([result, party.get_heroes(), enemies.get_enemies(), rng.state])
							party._heroes = snapshot[0].duplicate(true)
						seen[move] = true
						_check(enemies.apply_damage(source, 99999) and enemies.is_slain(source), "dead named source precondition")
						var dead := [party.get_heroes(), enemies.get_enemies(), rng.state]
						_check(phase.execute_phase(party, enemies, [action], null, true, null, 19)
							== {"ok": true, "gold": 19, "events": [{"type": "attack", "enemy_position": source,
								"target_position": target, "move": move, "applied": false}]}
							and dead == [party.get_heroes(), enemies.get_enemies(), rng.state], "dead named source cannot strike or mutate state")
						enemies._enemies = snapshot[1].duplicate(true)
						if seen.has("attack2") and seen.has("attack3"):
							break
					_check(scheduler.advance_turn(), "real weighted alternatives advance with the run RNG")
				_check(seen.has("attack2") and seen.has("attack3"), "both weighted Seam Ripper alternatives were actually selected and executed")
				traces.append(trace)
			_check(not traces[0].is_empty() and traces[0] == traces[1], "same-seed route, choices, phase receipts, actors and RNG replay exactly")


func _crab_route(count: int) -> Dictionary:
	# Discover a legal Fight in the Crab's actual derived floor band, without
	# injecting a pool, encounter, action or RNG result.
	for seed_value in range(1, 180):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var map := RunMap.new()
		if not map.generate(rng):
			continue
		while map.get_current_floor() < 11:
			var choices := map.get_legal_choices()
			if choices.is_empty():
				break
			var node: String = choices[0]
			for candidate in choices:
				if map.get_node(candidate).get("type") == "Fight":
					node = candidate
					break
			if not map.choose_node(node):
				break
			if map.get_node(node).get("type") != "Fight":
				continue
			var entry := RunAuthoredBattleEntry.new().entry_current_battle(
				map, rng, RunFightEncounterSelection.new())
			if entry.get("success", false):
				var ids: Array = entry.enemies.get_enemies().map(func(actor): return actor.id)
				if ids.size() == count and ids.has("scissor_crab"):
					return {"seed": seed_value, "route": map.get_route(), "ids": ids}
	return {}


func _test_scissor_crab_routed_named_attacks() -> void:
	for count in [2, 3]:
		var fixture := _crab_route(count)
		_check(not fixture.is_empty(), "Crab is reachable in a real routed %d-foe Fight" % count)
		if fixture.is_empty():
			continue
		for floor_number in [1, 5, 9]:
			var traces := []
			for replay in range(2):
				var rng := RandomNumberGenerator.new()
				rng.seed = fixture.seed
				var map := RunMap.new()
				_check(map.generate(rng), "Crab route map generates")
				for node in fixture.route:
					_check(map.choose_node(node), "Crab route commits a legal choice")
					if node != fixture.route.back() and map.get_node(node).get("type") == "Fight":
						_check(RunAuthoredBattleEntry.new().entry_current_battle(
							map, rng, RunFightEncounterSelection.new()).get("success", false), "prior Fight admits")
				var entry := RunAuthoredBattleEntry.new().entry_current_battle(map, rng, RunFightEncounterSelection.new())
				_check(entry.get("success", false) and entry.get("node_type") == "Fight", "routed Crab Fight admits")
				if not entry.get("success", false):
					return
				var definitions: Array = entry.enemies.get_enemies()
				_check(definitions.map(func(actor): return actor.id) == fixture.ids, "routed group replays without replacing companions")
				# Entry returns authored bases. Apply the same one-time transform as
				# app._choose_battle_route; exercise all tiers, even outside Crab's band.
				for actor in definitions:
					actor.max_hp = RunNormalAttackFloorScaling.scale_normal_max_hp(actor.max_hp, floor_number).max_hp
					for raw in actor.intent.actions:
						if raw.type == "attack" and raw.amount >= 5 and raw.amount <= 9:
							raw.amount = RunNormalAttackFloorScaling.scale_normal_attack(int(raw.amount), floor_number).amount
				var enemies := CombatEnemies.new(definitions)
				var source: int = fixture.ids.find("scissor_crab") + 1
				var target: int = 1 if count == 2 else 2
				var party := _party_fixture(40 if target == 1 else 0, 40, 40)
				var scheduler: CombatEnemyIntents = entry.intents
				_check(enemies.is_valid() and party.is_valid() and not party.is_downed(target)
					and scheduler.bind_battle(enemies, party, rng), "real Crab group binds to front living hero and run RNG")
				if not scheduler.is_bound():
					return
				var trace := []
				var seen := {}
				for turn in range(128):
					var actions := scheduler.get_intents()
					var state := rng.state
					_check(actions.size() == count and scheduler.get_intents() == actions and rng.state == state,
						"real group previews keep all announcements and spend no RNG")
					trace.append([actions.duplicate(true), state])
					var action: Dictionary = actions[source - 1]
					if action.has("move") and not seen.has(action.move):
						var move: String = action.move
						var amount: int = {1: [8, 7], 5: [10, 8], 9: [12, 10]}[floor_number][0 if move == "attack2" else 1]
						var hits: int = 1 if move == "attack2" else 2
						_check(move in ["attack2", "attack3"] and action.type == "attack" and action.amount == amount
							and action.get("hits", 1) == hits and action.target_position == target,
							"weighted Pinch/Blade Spin retains exact single-scaled total, hit count and front living target")
						var heroes := party.get_heroes()
						var foes := enemies.get_enemies()
						for mode in ["normal", "blind", "dead", "dodge", "riposte"]:
							party._heroes = heroes.duplicate(true)
							enemies._enemies = foes.duplicate(true)
							_check(party.gain_block(target, 19), "Crab recipient really has more Block than either strike total")
							if mode == "blind":
								enemies._enemies[source - 1].statuses = {"blind_next_attack": 1}
							elif mode == "dead":
								_check(enemies.apply_damage(source, 99999) and enemies.is_slain(source), "Crab source is genuinely slain")
							elif mode == "dodge":
								party._heroes[target - 1].statuses = {"dodge_next_attack": 1}
							elif mode == "riposte":
								party._heroes[target - 1].statuses = {"riposte": 1}
								enemies._enemies[source - 1].hp = 1
							var before := [party.get_heroes(), enemies.get_enemies(), rng.state, scheduler.get_intents()]
							var expected_heroes: Array = before[0].duplicate(true)
							var expected_foes: Array = before[1].duplicate(true)
							var event := {"type": "attack", "enemy_position": source,
								"target_position": target, "move": move, "applied": true}
							var events := []
							for hit in range(1 if mode == "blind" else hits):
								var beat := event.duplicate(true)
								beat.applied = not (mode in ["blind", "dead"] or (mode == "dodge" and hit == 0) or (mode == "riposte" and hit == 1))
								events.append(beat)
							@warning_ignore("integer_division")
							var second: int = amount / hits
							var loss := amount
							if mode == "blind":
								expected_foes[source - 1].statuses.erase("blind_next_attack")
							if mode in ["blind", "dead"]:
								loss = 0
							elif mode == "dodge":
								loss = second if hits == 2 else 0
								expected_heroes[target - 1].statuses.erase("dodge_next_attack")
							elif mode == "riposte":
								loss = amount - second if hits == 2 else amount
								expected_foes[source - 1].hp = 0
							if mode not in ["blind", "dead"]:
								expected_heroes[target - 1].block = 0
							expected_heroes[target - 1].hp -= loss
							var phase := CombatEnemyPhase.new()
							var result := phase.execute_phase(party, enemies, [action], null, true, null, 19)
							_check(result == {"ok": true, "gold": 19, "events": events}
								and party.get_heroes() == expected_heroes and enemies.get_enemies() == expected_foes
								and rng.state == state and scheduler.get_intents() == actions,
								"Crab %s floor %d %s: exact packets, Block-chew, wallet, companions and RNG" % [move, floor_number, mode])
							trace.append([mode, result, party.get_heroes(), enemies.get_enemies(), rng.state])
							party._heroes = before[0].duplicate(true)
							enemies._enemies = before[1].duplicate(true)
							for bad_move in [null, 2, "attack4", "unknown"]:
								var forged := action.duplicate(true)
								forged.move = bad_move
								_check(phase.execute_phase(party, enemies, [forged], null, true, null, 19) == {"ok": false, "events": []}
									and before == [party.get_heroes(), enemies.get_enemies(), rng.state, scheduler.get_intents()],
									"malformed/unauthored Crab move rejects atomically")
						party._heroes = heroes.duplicate(true)
						enemies._enemies = foes.duplicate(true)
						seen[move] = true
					if seen.has("attack2") and seen.has("attack3"):
						break
					_check(scheduler.advance_turn(), "real Crab weighted turn advances")
				_check(seen.has("attack2") and seen.has("attack3"), "bounded selection executes both authentic Crab alternatives")
				traces.append(trace)
			_check(not traces[0].is_empty() and traces[0] == traces[1], "Crab route, RNG, announcements and all phase receipts replay exactly")


func _scavenger_gold_record() -> Dictionary:
	var catalog := RunTypedBattleRoster._parse_catalog_text(
		FileAccess.get_file_as_string("res://data/enemies/run_enemies.json"))
	for record in catalog:
		if record.get("id") == "fray_scavenger":
			var copy: Dictionary = record.duplicate(true)
			return copy
	return {}


func _test_scavenger_gold_cache() -> void:
	var record := _scavenger_gold_record()
	_check(not record.is_empty() and record.get("name") == "Fray Scavenger"
		and record.get("max_hp") == 14 and record.intent.actions.size() == 6,
		"gold precondition: authentic copied Scavenger retains old choices plus theft")
	if record.is_empty():
		return
	_check(CombatEnemyIntents.weighted_action(
		{"type": "steal_gold", "amount": 2.0, "weight": 2.0}) ==
		{"weight": 2, "action": {"type": "steal_gold", "amount": 2}},
		"gold authored JSON integers normalize through the existing validator")
	var malformed: Array = []
	for amount in [0, -1, true, "2", null, 2.5, INF, NAN, [], {}]:
		malformed.append({"type": "steal_gold", "amount": amount, "weight": 2})
	for field in ["target_position", "enemy_position", "target_policy", "hits", "status", "direction", "extra"]:
		var bad := {"type": "steal_gold", "amount": 2, "weight": 2}
		bad[field] = 1
		malformed.append(bad)
	malformed.append({"type": "steal_gold", "weight": 2})
	for raw in malformed:
		var broken := record.duplicate(true)
		broken.intent.actions.append(raw)
		var enemies := CombatEnemies.new([broken])
		var rng := RandomNumberGenerator.new()
		rng.seed = 438
		var state := rng.state
		var selector := CombatEnemyIntents.new([_enemy(1, [_block(1)])])
		_check(enemies.is_valid() and not selector.bind_battle(enemies, _party_fixture(), rng)
			and not selector.is_bound() and rng.state == state,
			"malformed theft fails whole bind before any weighted draw: " + str(raw))
	for amount in [0, -1, true, "2", null, 2.0, 2.5]:
		_check(not CombatEnemyIntents.valid_action({"type": "steal_gold", "amount": amount}),
			"gold runtime announcement requires strictly positive literal integer")
	var traces: Array = []
	for repeat_index in range(2):
		var enemies := CombatEnemies.new([record])
		var party := _party_fixture(20, 20, 20)
		var rng := RandomNumberGenerator.new()
		rng.seed = 438
		var selector := CombatEnemyIntents.new([_enemy(1, [_block(1)])])
		_check(selector.bind_battle(enemies, party, rng), "extended Scavenger policy binds")
		if not selector.is_bound():
			return
		var trace: Array = []
		var thefts := 0
		var moves := {}
		for turn in range(64):
			var cached := selector.get_intents()
			var state := rng.state
			_check(cached.size() == 1 and selector.get_intents() == cached and rng.state == state,
				"repeated gold announcement reads preserve cache and run RNG")
			if cached[0].type == "steal_gold":
				thefts += 1
				_check(cached == [{"type": "steal_gold", "amount": 2, "enemy_position": 1}]
					and not enemies.is_slain(1), "weighted theft names living source without hero target")
			if cached[0].get("move", "") in ["attack2", "attack3"]:
				var action: Dictionary = cached[0]
				moves[action.move] = true
				_check(action.type == "attack" and action.amount == (6 if action.move == "attack2" else 7)
					and action.target_position == 1 and not enemies.is_slain(1),
					"bound named attack retains amount and front lowest-HP living target")
				var resolved_party := _party_fixture(20, 20, 20)
				var resolved_enemies := CombatEnemies.new([record])
				_check(resolved_party.gain_block(1, 3), "bound named hit has real partial Block")
				var phase := CombatEnemyPhase.new().execute_phase(resolved_party, resolved_enemies,
					cached, null, true, null, 9)
				_check(phase.get("ok", false) and phase.get("gold") == 9
					and resolved_party.get_hero(1).hp == 20 - action.amount + 3
					and resolved_party.get_hero(1).block == 0
					and resolved_party.get_hero(2).hp == 20 and resolved_party.get_hero(3).hp == 20
					and rng.state == state, "bound named attack resolves exact Block-before-HP without wallet/RNG debit")
			trace.append([cached.duplicate(true), state])
			cached[0].amount = -9
			_check(selector.get_intents() == trace[-1][0], "gold cache is detached from returned edits")
			_check(selector.advance_turn(), "extended policy advances normally")
		_check(thefts > 0, "seeded real weighted policy actually selected theft")
		_check(moves.has("attack2") and moves.has("attack3"), "seeded bound policy announces both added moves")
		traces.append(trace)
	_check(traces[0] == traces[1], "same-seed extended Scavenger actions and RNG replay exactly")


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

func _four_enemies() -> Array:
	# Intentionally shuffled: four distinct patterns of lengths 4, 3, 2 and 1.
	return [
		_enemy(4, [_block(8), _attack(4, 3), _block(0), _attack(9, 1)]),
		_enemy(2, [_attack(3, 2), _block(2), _attack(7, 1)]),
		_enemy(1, [_block(1), _attack(2, 1)]),
		_enemy(3, [_attack(5, 3)]),
	]


func _four_turns() -> Array:
	# Independent expected 12-beat least-common-multiple trace, in slot order.
	var one := [_block(1), _attack(2, 1)]
	var two := [_attack(3, 2), _block(2), _attack(7, 1)]
	var three := [_attack(5, 3)]
	var four := [_block(8), _attack(4, 3), _block(0), _attack(9, 1)]
	var expected: Array = []
	for turn in range(12):
		expected.append([
			_announced(1, one[turn % 2]),
			_announced(2, two[turn % 3]),
			_announced(3, three[0]),
			_announced(4, four[turn % 4]),
		])
	return expected


func _snip_action(target: int) -> Dictionary:
	return {"type": "snip_block", "amount": 0, "target_position": target}


func _test_snip_schema() -> void:
	var valid := _snip_action(1)
	for position in [1, 2, 3]:
		_check(CombatEnemyIntents.valid_action(_snip_action(position)),
			"snip legacy exact zero-amount, living-slot shape validates")
	var legacy := CombatEnemyIntents.new([_enemy(2, [_snip_action(3), _snip_action(1)])])
	_check(legacy.is_valid() and legacy.get_intents() == [_announced(2, _snip_action(3))],
		"legacy snip caches the exact authored target and original source")
	_check(legacy.advance_turn() and legacy.get_intents() == [_announced(2, _snip_action(1))],
		"legacy snip cycles without retargeting")
	var weighted := {"type": "snip_block", "amount": 0.0, "weight": 2.0}
	_check(CombatEnemyIntents.weighted_action(weighted) ==
		{"weight": 2, "action": {"type": "snip_block", "amount": 0}},
		"JSON integral weight/amount normalize without a target in authored body")
	for bad in [
		{"type": "snip_block", "amount": 1, "target_position": 1},
		{"type": "snip_block", "amount": -1, "target_position": 1},
		{"type": "snip_block", "amount": 0, "target_position": 0},
		{"type": "snip_block", "amount": 0, "target_position": 4},
		{"type": "snip_block", "amount": 0, "target_position": 1.0},
		{"type": "snip_block", "amount": 0, "target_position": true},
		{"type": "snip_block", "amount": 0, "target_position": 1, "extra": true},
		{"type": "snip_block", "amount": 0, "target_position": 1, "direction": 1},
		{"type": "snip_block", "amount": 0, "target_position": 1, "status": "weak"},
		{"type": "snip_block", "target_position": 1}]:
		_reject("malformed legacy snip " + str(bad),
			[_enemy(1, [_block(1)]), _enemy(2, [_snip_action(1), bad])])
	for bad in [
		{"type": "snip_block", "amount": 1, "weight": 1},
		{"type": "snip_block", "amount": -1, "weight": 1},
		{"type": "snip_block", "amount": 0, "weight": 0},
		{"type": "snip_block", "amount": 0, "weight": 1, "target_position": 1},
		{"type": "snip_block", "amount": 0, "weight": 1, "enemy_position": 1},
		{"type": "snip_block", "amount": 0, "weight": 1, "target_policy": "front"},
		{"type": "snip_block", "amount": 0, "weight": 1, "extra": true},
		{"type": "snip_block", "amount": 0, "weight": 1, "direction": 1},
		{"type": "snip_block", "amount": 0, "weight": 1, "status": "weak"}]:
		_check(CombatEnemyIntents.weighted_action(bad).is_empty(),
			"malformed weighted snip fails exact shape " + str(bad))
		_reject_bind("malformed weighted snip", {"target": "front", "actions": [
			{"type": "attack", "amount": 1, "weight": 1}, bad]})


func _snip_two_source(reverse: bool, seed_value: int) -> Dictionary:
	var party := _party_fixture()
	_check(party.gain_block(1, 6) and party.get_hero(1).block == 6,
		"snip phase precondition: Warden has six Block")
	var snip := {"type": "snip_block", "amount": 0, "weight": 1}
	var attack := {"type": "attack", "amount": 5, "weight": 1}
	var second := _policy_enemy("front", [snip if reverse else attack])
	second["id"] = "policy_enemy_two"
	var enemies := CombatEnemies.new([
		_policy_enemy("front", [attack if reverse else snip]), second])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var scheduler := CombatEnemyIntents.new([
		_enemy(1, [_block(1)]), _enemy(2, [_block(1)])])
	_check(enemies.is_valid() and scheduler.bind_battle(enemies, party, rng),
		"snip phase precondition: 2 actual living CombatEnemies bind an authored intent")
	return {"party": party, "enemies": enemies, "rng": rng, "scheduler": scheduler}


func _test_snip_bound_phases_and_badge() -> void:
	for reverse in [false, true]:
		var fixture := _snip_two_source(reverse, 41371)
		var party: CombatParty = fixture.party
		var enemies: CombatEnemies = fixture.enemies
		var rng: RandomNumberGenerator = fixture.rng
		var schedule: CombatEnemyIntents = fixture.scheduler
		var oracle := RandomNumberGenerator.new()
		oracle.seed = 41371
		var actions := schedule.get_intents()
		var inputs := actions.duplicate(true)
		var before := party.get_heroes()
		var foes := enemies.get_enemies()
		var hero_refs := party._heroes.duplicate()
		_check(actions.size() == 2 and actions[0].enemy_position == 1
			and actions[1].enemy_position == 2
			and actions[0].type == ("attack" if reverse else "snip_block")
			and actions[1].type == ("snip_block" if reverse else "attack")
			and actions[0].target_position == 1 and actions[1].target_position == 1,
			"two-source authored snip/attack announcement cached in original source slots")
		_check(schedule.get_intents() == actions and rng.state == oracle.state,
			"singleton weighted/front policy spends zero RNG on binding or reads")
		var event_snip := {"type": "snip_block", "enemy_position": 2 if reverse else 1,
			"applied": true, "target_position": 1}
		var event_hit := {"type": "attack", "enemy_position": 1 if reverse else 2,
			"applied": true, "target_position": 1}
		var expected_events := [event_hit, event_snip] if reverse else [event_snip, event_hit]
		# Deliberately reverse caller order: CombatEnemyPhase must resolve source 1 first.
		var result := CombatEnemyPhase.new().execute_phase(
			party, enemies, [actions[1], actions[0]], null, true)
		var expected := before.duplicate(true)
		expected[0]["block"] = 0
		expected[0]["hp"] = 40 if reverse else 35
		_check(result == {"ok": true, "events": expected_events},
			"phase emits exact ordered snip/attack event trace with real target")
		_check(party.get_heroes() == expected and enemies.get_enemies() == foes,
			"snip-before-attack loses five HP; attack-before-snip preserves 40 HP")
		_check(actions == inputs and rng.state == oracle.state
			and is_same(party._heroes[0], hero_refs[0])
			and is_same(party._heroes[1], hero_refs[1]),
			"phase preserves cached announcement, RNG and canonical hero identities")
		var replay := _snip_two_source(reverse, 41371)
		var replay_actions: Array = replay.scheduler.get_intents()
		var replay_result := CombatEnemyPhase.new().execute_phase(
			replay.party, replay.enemies, replay_actions, null, true)
		_check(replay_actions == actions and replay_result == result
			and replay.party.get_heroes() == party.get_heroes()
			and replay.rng.state == rng.state,
			"independent same-seed two-source replay matches trace and complete state")
		if not reverse:
			var badge := LiveEnemyIntentBadge.new()
			get_root().add_child(badge)
			badge.size = Vector2(192, 28)
			badge.show_intent(actions[0], false, false, "front")
			var rect := badge.caption_text_rect()
			var available := badge.caption_text_area()
			_check(badge.icon_mode == "snip_block" and badge.intent_type == "snip_block"
				and badge.target_position == 1 and badge.readable_text.contains("Snip")
				and badge.readable_text.contains("Block")
				and badge.readable_text.contains("1") and badge.readable_text != "NO ACTION",
				"live sewn badge names the snip and its concrete hero")
			_check(badge.tooltip_text.contains("remove all Block")
				and badge.tooltip_text.contains("no direct HP damage")
				and badge.tooltip_text.contains("Hero 1 (front)")
				and badge.tooltip_text.contains("Target policy (FRONT)")
				and badge.tooltip_text.contains("picks the front living hero")
				and badge.policy_cue == "Front",
				"live tooltip explains entire Block removal, zero HP damage and priority")
			_check(badge.icon_art_path_for("snip_block") ==
				LiveEnemyIntentBadge.icon_path_for("debuff")
				and badge.caption_font_size() >= LiveEnemyIntentBadge.COMPACT_MIN_FONT
				and rect.size.x > 0 and rect.end.x <= available.end.x + 0.5
				and badge.policy_text_rect().size.x > 0,
				"snip selects existing art and caption fits the 192x28 mounted strip")
			badge.free()

	# A first source can tear the announced recipient during the SAME phase.
	# Source 2 must use its roster policy's first surviving choice at its beat.
	var late_party := _party_fixture()
	_check(late_party.gain_block(2, 4), "in-phase Torn fallback has four middle Block")
	var late_snip := _policy_enemy("lowest_living_hp", [
		{"type": "snip_block", "amount": 0, "weight": 1}])
	late_snip["id"] = "late_snipper"
	var late_enemies := CombatEnemies.new([
		_policy_enemy("lowest_living_hp", [
			{"type": "attack", "amount": 26, "weight": 1}]), late_snip])
	var late_rng := RandomNumberGenerator.new()
	late_rng.seed = 911
	var late_schedule := CombatEnemyIntents.new([
		_enemy(1, [_block(1)]), _enemy(2, [_block(1)])])
	_check(late_enemies.is_valid()
		and late_schedule.bind_battle(late_enemies, late_party, late_rng),
		"two actual sources bind a lethal hit followed by a policy snip")
	var late_announced := late_schedule.get_intents()
	var late_state := late_rng.state
	_check(late_announced.size() == 2 and late_announced[0].target_position == 3
		and late_announced[1].target_position == 3,
		"both cached policies initially choose living lowest-HP Tinker")
	var late_trace := CombatEnemyPhase.new().execute_phase(
		late_party, late_enemies, [late_announced[1], late_announced[0]], null, true)
	_check(late_trace == {"ok": true, "events": [
		{"type": "attack", "enemy_position": 1, "applied": true, "target_position": 3},
		{"type": "snip_block", "enemy_position": 2, "applied": true, "target_position": 2}]}
		and late_party.get_hero(3).hp == 0 and late_party.get_hero(2).hp == 30
		and late_party.get_hero(2).block == 0
		and late_rng.state == late_state and late_schedule.get_intents() == late_announced,
		"earlier lethal beat retargets later policy-bound snip without extra draw")
	# Every policy is reached by the same weighted snip without special-case targets.
	var low := _party_fixture(35, 28, 10)
	var marked := _party_fixture()
	marked._heroes[1]["statuses"] = {"exposed": 1}
	_check(_bound_announcement("lowest_living_hp", low, 41, [
		{"type": "snip_block", "amount": 0, "weight": 1}]).get("target_position") == 3
		and _bound_announcement("exposed", marked, 42, [
			{"type": "snip_block", "amount": 0, "weight": 1}]).get("target_position") == 2
		and _bound_announcement("exposed", _party_fixture(), 43, [
			{"type": "snip_block", "amount": 0, "weight": 1}]).get("target_position") == 1,
		"snip uses lowest HP, Exposed priority and front fallback")
	var random_party := _party_fixture()
	var random_rng := RandomNumberGenerator.new()
	random_rng.seed = 6742
	var target_oracle := RandomNumberGenerator.new()
	target_oracle.seed = 6742
	var expected_random := target_oracle.randi_range(0, 2) + 1
	var random_enemies := CombatEnemies.new([_policy_enemy("random", [
		{"type": "snip_block", "amount": 0, "weight": 1}])])
	var random_schedule := CombatEnemyIntents.new([_enemy(1, [_block(1)])])
	_check(random_schedule.bind_battle(random_enemies, random_party, random_rng)
		and random_schedule.get_intents()[0].target_position == expected_random
		and random_rng.state == target_oracle.state,
		"single-choice random snip consumes exactly one seeded target draw")
	var cached := random_schedule.get_intents()
	_check(random_schedule.get_intents() == cached
		and random_rng.state == target_oracle.state,
		"random snip reads leave run RNG and announcement unchanged")
	# Cached lowest-HP target Torn after binding must fall back without a new draw.
	var retarget_party := _party_fixture()
	_check(retarget_party.gain_block(2, 4), "fallback target initially has Block")
	var retarget_enemies := CombatEnemies.new([_policy_enemy("lowest_living_hp", [
		{"type": "snip_block", "amount": 0, "weight": 1}])])
	var retarget_rng := RandomNumberGenerator.new()
	retarget_rng.seed = 71
	var retarget_schedule := CombatEnemyIntents.new([_enemy(1, [_block(1)])])
	_check(retarget_schedule.bind_battle(retarget_enemies, retarget_party, retarget_rng),
		"policy snip bound to living weakest Tinker")
	var announced := retarget_schedule.get_intents()
	var rng_before := retarget_rng.state
	_check(announced[0].target_position == 3 and retarget_party.apply_damage(3, 26)
		and retarget_party.is_downed(3), "precondition: cached target becomes Torn")
	var resolved := CombatEnemyPhase.new().execute_phase(
		retarget_party, retarget_enemies, announced, null, true)
	_check(resolved == {"ok": true, "events": [
		{"type": "snip_block", "enemy_position": 1, "target_position": 2, "applied": true}]}
		and retarget_party.get_hero(2).block == 0
		and retarget_rng.state == rng_before and retarget_schedule.get_intents() == announced,
		"policy snip retargets newly Torn cached recipient without RNG or cache mutation")


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


func _test_four_enemies_and_wrap() -> void:
	var definitions := _four_enemies()
	var original := definitions.duplicate(true)
	var schedule := CombatEnemyIntents.new(definitions)
	_check(schedule.is_valid() and not schedule.is_bound(),
		"four unique shuffled source slots 1-4 admit a valid scene-free schedule")
	var expected := _four_turns()
	for turn in range(26):
		var announced := schedule.get_intents()
		_check(announced.size() == 4, "four-source turn %d publishes exactly four actions" % turn)
		if announced.size() == 4:
			_check(announced[0].enemy_position == 1 and announced[1].enemy_position == 2
				and announced[2].enemy_position == 3 and announced[3].enemy_position == 4,
				"four-source turn %d is strictly sorted with exactly one action per source" % turn)
		_check(announced == expected[turn % expected.size()],
			"four-source turn %d has exact independent 1/2/3/4-cycle action and target" % turn)
		_check(schedule.advance_turn(), "four-source turn %d explicitly advances" % turn)
	_check(definitions == original, "four-source reads/advances preserve input deeply")


func _test_four_source_copy_isolation_and_replay() -> void:
	var definitions := _four_enemies()
	var pristine := definitions.duplicate(true)
	var first := CombatEnemyIntents.new(definitions)
	var replay := CombatEnemyIntents.new(pristine.duplicate(true))
	_check(first.is_valid() and replay.is_valid(), "two independent identical four-source schedules validate")
	# Damage every layer of the caller's former schedule after construction.
	definitions[0]["pattern"][0]["amount"] = 777
	definitions[1]["pattern"].append(_attack(99, 1))
	definitions[2]["enemy_position"] = 5
	definitions[3]["pattern"].clear()
	definitions.reverse()
	definitions.clear()
	var expected := _four_turns()
	_check(first.get_intents() == expected[0] and replay.get_intents() == expected[0],
		"caller changes to source fields, nested arrays, order and size cannot affect either instance")
	for turn in range(26):
		var before_first := first.get_intents()
		var before_replay := replay.get_intents()
		_check(before_first.size() == 4 and before_replay.size() == 4
			and before_first == expected[turn % 12] and before_replay == before_first,
			"four-source replay turn %d matches an independent exact expected trace" % turn)
		# Returned dictionaries and arrays are disposable snapshots, even at wrap boundaries.
		if not before_first.is_empty():
			before_first[0]["amount"] = 888
			before_first[0]["enemy_position"] = 4
			before_first[-1].clear()
		before_first.append({"invented": true})
		before_replay.clear()
		_check(first.get_intents() == expected[turn % 12]
			and replay.get_intents() == expected[turn % 12],
			"four-source turn %d rejects edits to returned action dictionaries and arrays" % turn)
		_check(first.advance_turn() and replay.advance_turn(),
			"both independent four-source replays advance turn %d" % turn)
	_check(pristine == _four_enemies(), "replay leaves the original four-source snapshot intact")


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
	_reject("more than four enemies", [
		_enemy(1, [_block(1)]), _enemy(2, [_block(1)]),
		_enemy(3, [_block(1)]), _enemy(4, [_block(1)]),
		_enemy(5, [_block(1)])])
	_reject("malformed fourth source rejects all previous valid sources", [
		_enemy(1, [_block(1)]), _enemy(2, [_attack(2, 2)]),
		_enemy(3, [_block(3)]), _enemy(4, [_block(4), {"type": "heal", "amount": 1}])])
	_reject("duplicate position four rejects whole four-source schedule", [
		_enemy(1, [_block(1)]), _enemy(4, [_block(2)]),
		_enemy(3, [_block(3)]), _enemy(4, [_block(4)])])
	_reject("duplicate occupied position", [_enemy(1, [_attack(1, 1)]), _enemy(1, [_block(1)])])
	for position in [0, -1, 5, null, true, false, "1", 1.0, [], {}]:
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
			"patchwork_behemoth": ["Patchwork Behemoth", 84]},
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


## V3-2: the shipped Guard Ragling fights with a forward shield rush, a real
## six-point hit and five self Block, still behind the same front policy.
const GUARD_STARTER_PATH := "res://data/enemies/starter_enemies.json"
const GUARD_RUSH_INTENT := {
	"target": "front",
	"actions": [
		{"type": "block", "amount": 5, "weight": 3},
		{"type": "shove", "amount": 0, "direction": 1, "weight": 2},
		{"type": "attack", "amount": 6, "weight": 1},
		{"type": "attack", "amount": 7, "weight": 1, "move": "attack2"},
	],
}


## JSON decodes whole numbers as floats; mirror the app's numeric normalization
## so authored records can be compared with exact integer dictionaries.
func _normalize_ints(value: Variant) -> Variant:
	if value is Dictionary:
		var record := {}
		for key in value:
			record[key] = _normalize_ints(value[key])
		return record
	if value is Array:
		var items: Array = []
		for item in value:
			items.append(_normalize_ints(item))
		return items
	if value is float and is_finite(value) and floorf(value) == value:
		return int(value)
	return value


## One authority-bound fight against the on-disk Guard record, optionally with a
## single authored alternative. The real roster, party and run generator are
## passed through CombatEnemyIntents.bind_battle, never a shortcut state.
func _bind_authored_guard(record: Dictionary, party: CombatParty, seed_value: int,
		label: String) -> Dictionary:
	var enemies := CombatEnemies.new([record])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var scheduler := CombatEnemyIntents.new([_enemy(1, [_block(1)])])
	var bound: bool = enemies.is_valid() and party != null and party.is_valid() \
		and scheduler.bind_battle(enemies, party, rng)
	_check(bound, label + ": the on-disk Guard record binds a weighted announcement")
	return {"enemies": enemies, "rng": rng, "scheduler": scheduler}


## The authored Guard record with exactly one of its own alternatives bound.
func _guard_with_option(record: Dictionary, index: int) -> Dictionary:
	var authored: Dictionary = record.duplicate(true)
	var intent: Dictionary = authored.get("intent", {}).duplicate(true)
	var actions: Array = intent.get("actions", [])
	if actions.size() <= index:
		_check(false, "precondition: authored Guard alternative %d exists" % index)
		return {}
	intent["actions"] = [actions[index].duplicate(true)]
	authored["intent"] = intent
	return authored


func _test_guard_ragling_shield_rush() -> void:
	# AC1: the disk record keeps its identity and authors exactly four
	# alternatives; each validates as an executable weighted slot on its own.
	var record := _authored_enemy(GUARD_STARTER_PATH, "ragling_guard")
	_check(record.get("name") == "Guard Ragling" and record.get("max_hp") == 12,
		"on-disk Guard Ragling keeps its authored name and 12 integer HP")
	_check(record.get("art_path") == "res://assets/paper/enemies/ragling_guard.png",
		"on-disk Guard Ragling keeps its authored shield art path")
	var intent = record.get("intent")
	_check(intent is Dictionary and intent.size() == 2 and intent.get("target") == "front",
		"on-disk Guard Ragling keeps exactly the front target policy")
	_check(_normalize_ints(intent) == GUARD_RUSH_INTENT,
		"on-disk Guard Ragling authors Block 5/3, right shove 0/2, Jab 6/1 and Bash 7/1")
	var actions: Array = intent.get("actions", []) if intent is Dictionary else []
	_check(actions.size() == 4, "the Guard authors exactly four weighted alternatives")
	var expected_options := [
		{"weight": 3, "action": {"type": "block", "amount": 5}},
		{"weight": 2, "action": {"type": "shove", "amount": 0, "direction": 1}},
		{"weight": 1, "action": {"type": "attack", "amount": 6}},
		{"weight": 1, "action": {"type": "attack", "amount": 7, "move": "attack2"}}]
	for index in range(mini(actions.size(), expected_options.size())):
		_check(CombatEnemyIntents.weighted_action(actions[index]) == expected_options[index],
			"authored Guard alternative %d normalizes to its exact executable action" % index)
		_check(not CombatEnemyIntents._weighted_slot(1, {
			"target": "front", "actions": [actions[index].duplicate(true)]}).is_empty(),
			"authored Guard alternative %d validates as a whole weighted slot" % index)
	_check(not CombatEnemyIntents._weighted_slot(1, intent).is_empty(),
		"the complete authored Guard intent validates as one weighted slot")
	var ragling := _authored_enemy(GUARD_STARTER_PATH, "ragling")
	_check(ragling.get("name") == "Ragling" and ragling.get("max_hp") == 12
		and ragling.get("art_path") == "res://assets/paper/enemies/ragling.png",
		"the plain Ragling keeps its identity, 12 HP and art")
	_check(_normalize_ints(ragling.get("intent")) == {"target": "front", "actions": [
		{"type": "attack", "amount": 5, "weight": 3}]},
		"the plain Ragling keeps its single Attack 5/3 alternative")
	if actions.size() != 4:
		return

	# AC2: a bound shove from a living three-slot party swaps slots 1 and 2
	# through the real phase, carrying HP, Block and statuses, and damaging nobody.
	var party := _party_fixture()
	_check(party.get_hero(1).get("id") == "warden"
		and party.get_hero(2).get("id") == "seamstress"
		and party.get_hero(3).get("id") == "tinker",
		"precondition: living Warden, Seamstress and Tinker fill slots 1-3")
	party._heroes[0]["statuses"] = {"weak": 1}
	party._heroes[1]["statuses"] = {"exposed": 2}
	_check(party.gain_block(2, 3), "precondition: the middle hero holds three Block")
	var before := party.get_heroes()
	var shove_fixture := _bind_authored_guard(_guard_with_option(record, 1), party,
		33601, "shield rush")
	var shove_announced: Array = shove_fixture.scheduler.get_intents()
	_check(shove_announced == [{"type": "shove", "amount": 0, "direction": 1,
		"target_position": 1, "enemy_position": 1}],
		"the bound shield rush announces a right push of the front hero")
	var shove_foes: Array = shove_fixture.enemies.get_enemies()
	var shove_result := CombatEnemyPhase.new().execute_phase(party,
		shove_fixture.enemies, shove_announced, null, true)
	_check(shove_result == {"ok": true, "events": [{"type": "shove", "enemy_position": 1,
		"target_position": 1, "direction": 1, "applied": true}]},
		"CombatEnemyPhase applies exactly one announced shield rush")
	var after := party.get_heroes()
	_check(after[0].get("id") == "seamstress" and after[1].get("id") == "warden"
		and after[2].get("id") == "tinker",
		"the shield rush swaps the living front and middle heroes")
	_check(after[0].get("position") == 1 and after[1].get("position") == 2
		and after[2].get("position") == 3,
		"swapped heroes carry positions matching their new slots")
	_check(after[0].get("hp") == 30 and after[0].get("block") == 3
		and after[0].get("statuses") == {"exposed": 2}
		and after[1].get("hp") == 40 and after[1].get("block") == 0
		and after[1].get("statuses") == {"weak": 1},
		"the rush carries HP, Block and statuses with each hero instead of damaging them")
	_check(after[2] == before[2], "the back hero is untouched by the shield rush")
	_check(shove_fixture.enemies.get_enemies() == shove_foes,
		"a shield rush changes no enemy HP, Block or metadata")
	_check(shove_fixture.scheduler.get_intents() == shove_announced,
		"executing the rush leaves the cached announcement unchanged")

	# AC3: the real six-point hit spends hero Block before HP, five Block lands on
	# the Guard and keeps absorbing until it is gone.
	var hit_party := _party_fixture()
	_check(hit_party.gain_block(1, 4), "precondition: the front hero holds four Block")
	var hit_fixture := _bind_authored_guard(_guard_with_option(record, 2), hit_party,
		33602, "six-point hit")
	var hit_announced: Array = hit_fixture.scheduler.get_intents()
	_check(hit_announced == [{"type": "attack", "amount": 6, "target_position": 1,
		"enemy_position": 1}],
		"the bound Guard announces a real six-point hit on the front hero")
	var hit_result := CombatEnemyPhase.new().execute_phase(hit_party,
		hit_fixture.enemies, hit_announced, null, true)
	_check(hit_result == {"ok": true, "events": [{"type": "attack", "enemy_position": 1,
		"target_position": 1, "applied": true}]},
		"CombatEnemyPhase lands the announced six-point hit")
	_check(hit_party.get_hero(1).get("block") == 0 and hit_party.get_hero(1).get("hp") == 38,
		"six damage spends the hero's four Block before two HP")
	_check(hit_party.get_hero(2).get("hp") == 30 and hit_party.get_hero(3).get("hp") == 26,
		"the Guard's hit never reaches the other heroes")
	_check(hit_fixture.enemies.get_enemy(1).get("hp") == 12
		and hit_fixture.enemies.get_enemy(1).get("block") == 0,
		"the attacking Guard is unchanged by its own hit")

	var block_party := _party_fixture()
	var block_fixture := _bind_authored_guard(_guard_with_option(record, 0), block_party,
		33603, "five Block")
	var block_announced: Array = block_fixture.scheduler.get_intents()
	_check(block_announced == [{"type": "block", "amount": 5, "enemy_position": 1}],
		"the bound Guard announces five Block with no hero target")
	var block_heroes: Array = block_party.get_heroes()
	var block_result := CombatEnemyPhase.new().execute_phase(block_party,
		block_fixture.enemies, block_announced, null, true)
	_check(block_result == {"ok": true, "events": [{"type": "block",
		"enemy_position": 1, "applied": true}]},
		"CombatEnemyPhase grants the announced Block to the Guard")
	_check(block_fixture.enemies.get_enemy(1).get("block") == 5
		and block_party.get_heroes() == block_heroes,
		"five Block lands on the Guard and leaves every hero untouched")
	_check(block_fixture.enemies.apply_damage(1, 3)
		and block_fixture.enemies.get_enemy(1).get("block") == 2
		and block_fixture.enemies.get_enemy(1).get("hp") == 12,
		"the Guard's Block absorbs a later three-point hit without losing HP")
	_check(block_fixture.enemies.apply_damage(1, 4)
		and block_fixture.enemies.get_enemy(1).get("block") == 0
		and block_fixture.enemies.get_enemy(1).get("hp") == 10,
		"the Guard's Block persists until spent, then HP takes the remaining two")

	# AC3: two seeded weighted runs over the authentic four-way record replay
	# exactly, and reading the cached announcement never advances the run RNG.
	var weighted_party := _party_fixture()
	var weighted_fixture := _bind_authored_guard(record, weighted_party, 33604,
		"weighted guard")
	var oracle := RandomNumberGenerator.new()
	oracle.seed = 33604
	oracle.randi_range(1, 7)
	_check(weighted_fixture.rng.state == oracle.state,
		"binding the authentic Guard intent spends exactly one weighted choice draw")
	var weighted_first: Array = weighted_fixture.scheduler.get_intents()
	_check(weighted_first.size() == 1
		and weighted_first[0].get("enemy_position") == 1,
		"the authentic Guard announces one action in its own slot")
	var executable: Dictionary = weighted_first[0].duplicate(true)
	executable.erase("enemy_position")
	_check(CombatEnemyIntents.valid_action(executable),
		"the weighted Guard announcement is an executable authored action")
	for attempt in range(4):
		_check(weighted_fixture.scheduler.get_intents() == weighted_first,
			"reading the cached Guard announcement never rerolls it")
	_check(weighted_fixture.rng.state == oracle.state,
		"cached Guard announcement reads never spend the run RNG")
	var sequence: Array = [weighted_first]
	for turn in range(5):
		_check(weighted_fixture.scheduler.advance_turn(),
			"the Guard commits one new weighted batch per advance")
		sequence.append(weighted_fixture.scheduler.get_intents())
	var replay := _bind_authored_guard(record, _party_fixture(), 33604,
		"weighted guard replay")
	var replay_sequence: Array = [replay.scheduler.get_intents()]
	for turn in range(5):
		_check(replay.scheduler.advance_turn(),
			"the replay Guard commits one new weighted batch per advance")
		replay_sequence.append(replay.scheduler.get_intents())
	_check(sequence == replay_sequence
		and replay.rng.state == weighted_fixture.rng.state,
		"two same-seed Guard fights replay identical batches and RNG states")
	var kinds := {}
	for batch in sequence:
		var action: Dictionary = batch[0].duplicate(true)
		action.erase("enemy_position")
		_check(CombatEnemyIntents.valid_action(action),
			"every weighted Guard batch stays an executable authored action")
		kinds[action.get("type")] = true
	_check(kinds.size() >= 2,
		"the weighted Guard rotates through more than one authored alternative")

	# AC4: illegal, slain and malformed beats stay fail-closed and atomic.
	var downed_party := _party_fixture()
	_check(downed_party.apply_damage(2, 30) and downed_party.is_downed(2),
		"precondition: the middle hero is downed before the rush")
	var downed_fixture := _bind_authored_guard(_guard_with_option(record, 1),
		downed_party, 33605, "illegal rush")
	var downed_announced: Array = downed_fixture.scheduler.get_intents()
	var downed_before: Array = downed_party.get_heroes()
	var downed_result := CombatEnemyPhase.new().execute_phase(downed_party,
		downed_fixture.enemies, downed_announced, null, true)
	_check(downed_result == {"ok": true, "events": [{"type": "shove",
		"enemy_position": 1, "target_position": 1, "direction": 1, "applied": false}]},
		"a rush toward a downed neighbour stays inert instead of failing the phase")
	_check(downed_party.get_heroes() == downed_before,
		"an inert shield rush changes no hero HP, Block, status or slot")

	var slain_party := _party_fixture()
	var slain_fixture := _bind_authored_guard(_guard_with_option(record, 1),
		slain_party, 33606, "slain rush")
	var slain_announced: Array = slain_fixture.scheduler.get_intents()
	_check(slain_fixture.enemies.apply_damage(1, 12)
		and slain_fixture.enemies.is_slain(1),
		"precondition: the Guard is slain after announcing its rush")
	var slain_before: Array = slain_party.get_heroes()
	var slain_result := CombatEnemyPhase.new().execute_phase(slain_party,
		slain_fixture.enemies, slain_announced, null, true)
	_check(slain_result == {"ok": true, "events": [{"type": "shove",
		"enemy_position": 1, "target_position": 1, "direction": 1, "applied": false}]},
		"a slain Guard never executes its announced shield rush")
	_check(slain_party.get_heroes() == slain_before,
		"a slain Guard's announcement changes no hero state")

	var bad_party := _party_fixture()
	var bad_enemies := CombatEnemies.new([record])
	var bad_heroes: Array = bad_party.get_heroes()
	var bad_foes: Array = bad_enemies.get_enemies()
	for bad in [
		{"type": "shove", "enemy_position": 1, "amount": 1, "target_position": 1, "direction": 1},
		{"type": "shove", "enemy_position": 1, "amount": 0, "target_position": 1},
		{"type": "shove", "enemy_position": 1, "amount": 0, "target_position": 1, "direction": 0},
		{"type": "attack", "enemy_position": 1, "amount": 6.0, "target_position": 1},
		{"type": "attack", "enemy_position": 1, "amount": 6, "target_position": 4},
		{"type": "block", "enemy_position": 1, "amount": 5, "target_position": 1},
		{"type": "attack", "enemy_position": 2, "amount": 6, "target_position": 1}]:
		var bad_copy: Dictionary = bad.duplicate(true)
		_check(CombatEnemyPhase.new().execute_phase(bad_party, bad_enemies, [bad],
			null, true) == {"ok": false, "events": []},
			"a malformed Guard action fails the whole phase closed: " + str(bad))
		_check(bad == bad_copy, "phase rejection leaves the caller's Guard action unchanged")
	_check(bad_party.get_heroes() == bad_heroes
		and bad_enemies.get_enemies() == bad_foes,
		"rejected Guard actions publish no hero or enemy change")


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
	# A battle-bound forward pull names the hero it drags toward the front: the
	# front policy's own hero cannot step forward, so the announcement names the
	# living middle hero and keeps the authored direction instead of reversing it.
	var pull_party := _party_fixture()
	_check(pull_party.get_hero(1).get("id") == "warden"
		and pull_party.get_hero(2).get("id") == "seamstress"
		and pull_party.get_hero(3).get("id") == "tinker",
		"precondition: living Warden, Seamstress and Tinker fill slots 1-3")
	var pull_actions: Array = [{"type": "shove", "amount": 0, "direction": -1, "weight": 1}]
	var pull_enemies := CombatEnemies.new([_policy_enemy("front", pull_actions)])
	var pull_rng := RandomNumberGenerator.new()
	pull_rng.seed = 7
	var pull_scheduler := CombatEnemyIntents.new([_enemy(1, [_block(1)])])
	_check(pull_enemies.is_valid() and pull_scheduler.bind_battle(pull_enemies, pull_party, pull_rng),
		"a battle-bound front-policy forward pull binds the real roster and party")
	if pull_scheduler.is_bound():
		var committed := pull_rng.state
		var pull := pull_scheduler.get_intents()
		_check(pull.size() == 1 and pull[0] == {"type": "shove", "amount": 0,
			"target_position": 2, "direction": -1, "enemy_position": 1},
			"the bound forward pull announces hero 2 pulled toward slot 1")
		_check(CombatEnemyIntents.shove_is_legal(pull_party, 2, -1),
			"precondition: the announced middle-to-front pull is legal")
		var tampered := pull.duplicate(true)
		tampered[0]["target_position"] = 3
		tampered[0]["direction"] = 1
		tampered.clear()
		_check(pull_scheduler.get_intents() == pull and pull_scheduler.get_intents() == pull,
			"repeated reads return the same detached cached pull")
		_check(pull_rng.state == committed, "reading the cached pull never spends run RNG")
		# Seed/RNG-stable replay of the same bound announcement.
		var replay_party := _party_fixture()
		var replay_enemies := CombatEnemies.new([_policy_enemy("front", pull_actions)])
		var replay_rng := RandomNumberGenerator.new()
		replay_rng.seed = 7
		var replay := CombatEnemyIntents.new([_enemy(1, [_block(1)])])
		_check(replay_enemies.is_valid()
			and replay.bind_battle(replay_enemies, replay_party, replay_rng)
			and replay.get_intents() == pull and replay_rng.state == committed,
			"a same-seed rebuild announces the identical pull with the identical RNG state")
	# A pull whose policy target can already step forward keeps that hero, and
	# ordinary attacks, debuffs and backwards pushes keep their own policies.
	var lowest := _bound_announcement("lowest_living_hp", _party_fixture(30, 25, 10), 7,
		[{"type": "shove", "amount": 0, "direction": -1, "weight": 1}])
	_check(lowest.get("target_position") == 3 and lowest.get("direction") == -1,
		"a legal forward pull keeps the policy's own lowest-HP hero")
	var attack := _bound_announcement("lowest_living_hp", _party_fixture(30, 25, 10), 7,
		[{"type": "attack", "amount": 2, "weight": 1}])
	_check(attack.get("target_position") == 3, "ordinary attacks still use the authored policy")
	var debuff := _bound_announcement("exposed", _party_fixture(), 7,
		[{"type": "debuff", "amount": 1, "status": "weak", "weight": 1}])
	_check(debuff.get("target_position") == 1, "debuffs still use the authored policy")
	var push := _bound_announcement("front", _party_fixture(), 7,
		[{"type": "shove", "amount": 0, "direction": 1, "weight": 1}])
	_check(push.get("target_position") == 1 and push.get("direction") == 1,
		"an authored backwards push still shoves the policy's front hero")
	# The authentic catalog record keeps one weighted draw per source, so the
	# correction never changes the run RNG cadence.
	var snake := _authored_enemy("res://data/enemies/run_enemies.json", "zipper_snake")
	var snake_enemies := CombatEnemies.new([snake])
	var snake_party := _party_fixture()
	var snake_rng := RandomNumberGenerator.new()
	snake_rng.seed = 31415
	var snake_scheduler := CombatEnemyIntents.new([_enemy(1, [_block(1)])])
	_check(not snake.is_empty() and snake_enemies.is_valid()
		and snake_scheduler.bind_battle(snake_enemies, snake_party, snake_rng),
		"the authentic Zipper Snake record binds its weighted intent")
	if snake_scheduler.is_bound():
		var oracle := RandomNumberGenerator.new()
		oracle.seed = 31415
		oracle.randi_range(1, 5)
		_check(snake_rng.state == oracle.state,
			"the authored pull keeps exactly one weighted draw per source")
		var snake_action: Dictionary = snake_scheduler.get_intents()[0]
		if snake_action.get("type") == "shove":
			_check(snake_action.get("target_position") == 2
				and snake_action.get("direction") == -1,
				"an announced Snake pull names the middle hero and keeps direction -1")
		else:
			_check(snake_action.get("type") == "attack" and snake_action.get("amount") == 6
				and snake_action.get("target_position") == 1,
				"an announced Snake attack keeps the front policy and authored damage")


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
	_check(catalog is Array, "boss fixture: real catalog is an array")
	if not catalog is Array:
		return {}
	var matches: Array = catalog.filter(func(entry): return entry is Dictionary \
		and entry.get("id") == CombatBehemothPhaseRules.BOSS_ID)
	_check(matches.size() == 1, "boss fixture: one authentic Behemoth by ID")
	if matches.size() != 1:
		return {}
	var record: Dictionary = matches[0].duplicate(true)
	record["max_hp"] = int(record["max_hp"])
	return record


func _phase_two_fixture() -> Dictionary:
	var phase: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		CombatBehemothPhaseRules.PHASE_TWO_PATH))
	_check(phase is Dictionary, "phase two fixture: real authored JSON parses")
	return phase if phase is Dictionary else {}


func _assert_boss_slot(slot: Dictionary, kit: Array, policy: String, label: String) -> void:
	_check(slot.get("enemy_position") == 1 and slot.get("target") == policy,
		label + ": original slot and precise policy")
	var actions: Array = slot.get("actions", [])
	_check(actions.size() == kit.size(), label + ": every authored alternative is normalized")
	if actions.size() != kit.size():
		return
	_check(actions == kit, label + ": exact authored weights, totals, packets and named moves")


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
		"canonical real Behemoth binds at 84 HP")
	if not schedule.is_bound():
		return
	_assert_boss_slot(schedule._slots[0], BOSS_PHASE_ONE_KIT, "front", "84 HP")
	_check(CombatEnemyIntents.policy_for(enemies, 1) == "front",
		"executor policy is front for phase one")
	var first := schedule.get_intents()
	_check(first.size() == 1 and first[0].enemy_position == 1,
		"real Boss has one cached slot")
	var before := rng.state
	_check(enemies.gain_block(1, 6) and enemies.apply_damage(1, 6)
		and enemies.get_enemy(1).hp == 84, "Block absorbs damage without lowering HP")
	_check(schedule.get_intents() == first and rng.state == before,
		"Block and read cannot transition or spend RNG")
	_check(enemies.apply_damage(1, 62) and enemies.get_enemy(1).hp == 22
		and schedule.advance_turn(), "22 HP advances in phase one")
	_assert_boss_slot(schedule._slots[0], BOSS_PHASE_ONE_KIT, "front", "22 HP")
	var locked := schedule.get_intents()
	before = rng.state
	_check(enemies.apply_damage(1, 1) and enemies.get_enemy(1).hp == 21,
		"player hit crosses the fixed 21-HP boundary")
	for ignored in range(5):
		var hostile := schedule.get_intents()
		hostile[0]["amount"] = 999
	_check(schedule.get_intents() == locked and rng.state == before
		and CombatEnemyIntents.policy_for(enemies, 1) == "front",
		"threshold does not rewrite the current announcement or policy on reads")
	_check(schedule.advance_turn(), "next committed roll transitions phase")
	_assert_boss_slot(schedule._slots[0], BOSS_PHASE_TWO_KIT, "lowest_living_hp", "21 HP")
	_check(schedule._boss_phase == 2 and
		CombatEnemyIntents.policy_for(enemies, 1) == "lowest_living_hp",
		"cached phase and authoritative executor policy switch together")
	var next := schedule.get_intents()
	_check(next.size() == 1 and next[0].get("enemy_position") == 1
		and (next[0].get("amount") in [1, 3, 40, 36, 28, 44]),
		"21 HP publishes one phase-two action with authored amount")
	before = rng.state
	_check(next == schedule.get_intents() and rng.state == before,
		"phase two remains stable across repeated reads")
	_check(enemies.apply_damage(1, 20) and enemies.get_enemy(1).hp == 1
		and schedule.advance_turn() and schedule._boss_phase == 2,
		"living 1 HP Behemoth retains phase two")
	_assert_boss_slot(schedule._slots[0], BOSS_PHASE_TWO_KIT, "lowest_living_hp", "1 HP")
	_check(enemies.apply_damage(1, 1) and enemies.is_slain(1)
		and schedule.advance_turn() and enemies.get_enemy(1).hp == 0,
		"slain Behemoth stays in its slot and advances inertly")
	var heroes_before := party.get_heroes()
	var dead_action: Array = schedule.get_intents()
	var expected_events: int = int(dead_action[0].get("hits", 1))
	var result := CombatEnemyPhase.new().execute_phase(
		party, enemies, dead_action, null, true)
	_check(result.get("ok", false) and result.events.size() == expected_events
		and result.events.all(func(beat): return not beat.applied)
		and party.get_heroes() == heroes_before,
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
			"wrong_roster_name", "mixed_boss_roster", "forged_move", "forged_hits",
			"forged_weight", "extra_action"]:
		var source: Variant = boss.duplicate(true)
		var p2: Variant = phase.duplicate(true)
		var roster := [boss.duplicate(true)]
		if variant == "missing":
			p2 = null
		elif variant == "wrong_threshold":
			p2["threshold_hp"] = 20
		elif variant == "wrong_action":
			p2["intent"]["actions"][0]["amount"] = 3
		elif variant == "forged_move":
			source["intent"]["actions"][3]["move"] = "attack3"
		elif variant == "forged_hits":
			p2["intent"]["actions"][4]["hits"] = 3
		elif variant == "forged_weight":
			source["intent"]["actions"][5]["weight"] = 2
		elif variant == "extra_action":
			p2["intent"]["actions"].append(
				{"type": "attack", "amount": 44, "move": "attack4", "weight": 1})
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


## The three canonical floor-12 Bosses author the original attack and skills plus
## three weight-1 named attacks each. These are the exact authored kits.
const BOSS_KIT_CATALOG := "res://data/enemies/boss.json"
const BOSS_PHASE_ONE_KIT := [
	{"weight": 4, "action": {"type": "attack", "amount": 34}},
	{"weight": 2, "action": {"type": "block", "amount": 3}},
	{"weight": 1, "action": {"type": "debuff", "amount": 1, "status": "weak"}},
	{"weight": 1, "action": {"type": "attack", "amount": 30, "move": "attack2"}},
	{"weight": 1, "action": {"type": "attack", "amount": 22, "hits": 2, "move": "attack3"}},
	{"weight": 1, "action": {"type": "attack", "amount": 38, "move": "attack4"}},
]
const BOSS_PHASE_TWO_KIT := [
	{"weight": 4, "action": {"type": "attack", "amount": 40}},
	{"weight": 2, "action": {"type": "block", "amount": 3}},
	{"weight": 1, "action": {"type": "debuff", "amount": 1, "status": "weak"}},
	{"weight": 1, "action": {"type": "attack", "amount": 36, "move": "attack2"}},
	{"weight": 1, "action": {"type": "attack", "amount": 28, "hits": 2, "move": "attack3"}},
	{"weight": 1, "action": {"type": "attack", "amount": 44, "move": "attack4"}},
]
## Manifest title plus authored total damage and packet count per named attack.
const BOSS_NAMED_ATTACKS := {
	"patchwork_behemoth": {
		"attack2": ["Knuckle Slam", 30, 1],
		"attack3": ["Stuffing Hurl", 22, 2],
		"attack4": ["Rope Lash", 38, 1],
	},
	"sewing_machine_colossus": {
		"attack2": ["Needle Drive", 9, 1],
		"attack3": ["Bobbin Shot", 6, 2],
		"attack4": ["Treadle Stomp", 10, 1],
	},
	"moth_queen": {
		"attack2": ["Dust Gale", 6, 2],
		"attack3": ["Pin Crown Dive", 9, 1],
		"attack4": ["Devour", 10, 1],
	},
}
## Each Boss keeps the original non-attack alternatives it shipped with.
const BOSS_KEPT_SKILLS := {
	"patchwork_behemoth": ["block", "debuff"],
	"sewing_machine_colossus": ["block", "debuff"],
	"moth_queen": ["summon"],
}


func _boss_catalog_record(id: String) -> Dictionary:
	var matches: Array = _catalog_records(BOSS_KIT_CATALOG).filter(
		func(record: Variant) -> bool: return record is Dictionary and record.get("id") == id)
	_check(matches.size() == 1, "Boss catalog has exactly one record: " + id)
	if matches.size() != 1:
		return {}
	var record: Dictionary = matches[0].duplicate(true)
	record["max_hp"] = int(record["max_hp"])
	return record


## One genuinely bound fight's ordered announcements and RNG states, used only
## to prove two identical seeds replay the real weighted kit identically.
func _boss_announcement_trace(record: Dictionary, seed_value: int) -> Array:
	var party := _party_fixture()
	var enemies := CombatEnemies.new([record.duplicate(true)])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var scheduler := CombatEnemyIntents.new([_enemy(1, [_block(1)])])
	if not enemies.is_valid() or not scheduler.bind_battle(enemies, party, rng):
		return []
	var trace: Array = []
	for turn in range(24):
		trace.append([scheduler.get_intents(), rng.state])
		if not scheduler.advance_turn():
			return []
	return trace


## Resolve one announced named strike on a fresh real party. Block equal to one
## packet proves the exact authored total and the exact number of packets.
func _execute_boss_strike(enemies: CombatEnemies, action: Dictionary,
		total: int, hits: int) -> bool:
	var party := _party_fixture()
	var target := int(action.get("target_position", 0))
	if target < 1 or target > CombatParty.PARTY_SIZE or not party.is_valid():
		return false
	# Block one point short of the authored total: a real resolution then spends
	# every point of Block and costs exactly one HP, whatever the packet split.
	var hp_before: int = party.get_hero(target).hp
	if not party.gain_block(target, total - 1):
		return false
	var result := CombatEnemyPhase.new().execute_phase(party, enemies, [action], null, true)
	return result.get("ok", false) and result.events.size() == hits \
		and result.events.all(func(beat: Dictionary) -> bool: return beat.applied) \
		and hp_before - party.get_hero(target).hp == 1 \
		and party.get_hero(target).block == 0


## Every canonical Boss really announces and resolves each authored named attack
## from its shipped catalog entry, the live manifest names that pose, the
## original skills still appear, forged alternatives refuse atomically and the
## same seed replays the identical weighted choices.
func _test_boss_named_kits() -> void:
	for id in BOSS_NAMED_ATTACKS:
		var record := _boss_catalog_record(id)
		if record.is_empty():
			continue
		var spec: Dictionary = record.get("intent")
		_check(spec.get("target") == "front"
			and String(record.get("art_path", "")).begins_with("res://assets/paper/enemies/"),
			"original Boss policy and art path preserved: " + id)
		var raw_actions: Array = spec.get("actions", [])
		var authored: Array = []
		var attack_keys: Array = []
		var kinds: Array = []
		for raw in raw_actions:
			var normalized := CombatEnemyIntents.weighted_action(raw)
			_check(not normalized.is_empty(), "authored Boss alternative validates: " + id + " " + str(raw))
			if normalized.is_empty():
				continue
			authored.append(normalized.action)
			kinds.append(String(normalized.action.type))
			if normalized.action.type == "attack":
				var key := String(normalized.action.get("move", "attack"))
				_check(not attack_keys.has(key), "no duplicate Boss attack key: " + id + " " + key)
				attack_keys.append(key)
		_check(attack_keys.size() == 4 and attack_keys.has("attack"),
			"exactly four distinct Boss attacks including the original: " + id)
		for move in BOSS_NAMED_ATTACKS[id]:
			_check(attack_keys.has(move), "authored Boss named attack present: " + id + " " + move)
		for skill in BOSS_KEPT_SKILLS[id]:
			_check(kinds.has(skill), "original Boss skill retained: " + id + " " + skill)

		var party := _party_fixture()
		var enemies := CombatEnemies.new([record.duplicate(true)])
		var rng := RandomNumberGenerator.new()
		rng.seed = 48701
		var scheduler := CombatEnemyIntents.new([_enemy(1, [_block(1)])])
		_check(enemies.is_valid() and scheduler.bind_battle(enemies, party, rng),
			"shipped Boss catalog binds the real weighted kit: " + id)
		if not scheduler.is_bound():
			continue
		var strike_path := "res://assets/paper/enemies/%s_attack.png" % id
		var seen := {}
		var captured: Dictionary = {}
		for turn in range(160):
			var announced := scheduler.get_intents()
			var state := rng.state
			if announced.size() != 1 or announced[0].get("enemy_position") != 1:
				_check(false, "one Boss announcement for its single slot: " + id)
				break
			var action: Dictionary = announced[0]
			_check(scheduler.get_intents() == announced and rng.state == state,
				"reading the announced Boss action spends no RNG: " + id)
			var bare := action.duplicate(true)
			bare.erase("enemy_position")
			bare.erase("target_position")
			_check(authored.has(bare),
				"announced Boss action is an authored alternative: " + id + " " + str(action))
			if action.type == "attack" and action.has("move"):
				var move := String(action.move)
				var expected: Array = BOSS_NAMED_ATTACKS[id][move]
				_check(action.get("amount") == expected[1]
					and int(action.get("hits", 1)) == expected[2],
					"announced %s keeps authored total and packets: %s" % [move, id])
				var receipt := LiveMovePoseCatalog.new().lookup_enemy(id, action, strike_path)
				_check(receipt.get("name") == expected[0] and receipt.get("pose") == move
					and String(receipt.get("named_art", "")).ends_with("/%s_%s.png" % [id, move]),
					"manifest names the announced %s: %s" % [move, id])
				_check(_execute_boss_strike(enemies, action, expected[1], expected[2]),
					"living Boss resolves %s for its exact total in packets: %s" % [move, id])
				seen[move] = true
				captured = action.duplicate(true)
			else:
				seen[String(action.type)] = true
			if not scheduler.advance_turn():
				_check(false, "real Boss weighted turn advances: " + id)
				break
		for move in BOSS_NAMED_ATTACKS[id]:
			_check(seen.has(move), "genuine weighted selection announced " + id + " " + move)
		for skill in BOSS_KEPT_SKILLS[id]:
			_check(seen.has(skill), "genuine weighted selection retained " + id + " " + skill)
		_check(seen.has("attack"), "genuine weighted selection retained the base attack: " + id)
		_check(not captured.is_empty(), "captured a real named Boss announcement: " + id)
		if captured.is_empty():
			continue
		var first := _boss_announcement_trace(record, 7301)
		var second := _boss_announcement_trace(record, 7301)
		_check(not first.is_empty() and first == second,
			"identically seeded Boss catalog replays every announcement and RNG state: " + id)
		# Forged move, total or packet count and a stale (removed) alternative
		# must each refuse the whole phase without spend, mutation or RNG drift.
		var forgeries: Array = []
		for move in BOSS_NAMED_ATTACKS[id]:
			if move != String(captured.move):
				var swapped := captured.duplicate(true)
				swapped.move = move
				forgeries.append(swapped)
				break
		var inflated := captured.duplicate(true)
		inflated.amount = int(inflated.amount) + 1
		forgeries.append(inflated)
		var repacked := captured.duplicate(true)
		if repacked.has("hits"):
			repacked.erase("hits")
		else:
			repacked.hits = 2
		forgeries.append(repacked)
		var phase := CombatEnemyPhase.new()
		var snapshot := [party.get_heroes(), enemies.get_enemies(), rng.state]
		for forged in forgeries:
			_check(phase.execute_phase(party, enemies, [forged], null, true)
				== {"ok": false, "events": []}
				and snapshot == [party.get_heroes(), enemies.get_enemies(), rng.state],
				"forged Boss move/total/packets refuses without spend or RNG drift: " + id)
		var original_intent: Dictionary = enemies._enemies[0].intent.duplicate(true)
		enemies._enemies[0].intent.actions = original_intent.actions.filter(
			func(raw: Dictionary) -> bool: return raw.get("move") != captured.move)
		var stale_before := [party.get_heroes(), enemies.get_enemies(), rng.state]
		_check(phase.execute_phase(party, enemies, [captured], null, true)
			== {"ok": false, "events": []}
			and stale_before == [party.get_heroes(), enemies.get_enemies(), rng.state],
			"stale removed Boss alternative refuses without spend or RNG drift: " + id)
		enemies._enemies[0].intent = original_intent


func _test_two_hit_schema() -> void:
	var raw := {"type": "attack", "amount": 8, "hits": 2, "weight": 3}
	_check(CombatEnemyIntents.weighted_action(raw).action ==
		{"type": "attack", "amount": 8, "hits": 2}, "two hits retain a TOTAL of eight")
	for value in [0, 1, 3, -2, true, "2", null, [], {}, 2.5]:
		var bad := raw.duplicate(true)
		bad.hits = value
		_reject_bind("malformed two-hit " + str(value), {"target": "random", "actions": [bad]})
	for value in [2.0, true, "2", 1, 3]:
		_check(not CombatEnemyIntents.valid_action({"type": "attack", "amount": 8,
			"hits": value, "target_position": 1}), "phase hits must be integer two")
	for kind in ["block", "buff", "debuff", "snip_block", "shove"]:
		var bad := raw.duplicate(true)
		bad.type = kind
		_check(CombatEnemyIntents.weighted_action(bad).is_empty(), "hits only legal on attack")
	var traces: Array = []
	for multi in [false, true]:
		var authored := raw.duplicate(true)
		if not multi:
			authored.erase("hits")
		var enemy := CombatEnemies.new([{"id": "probe", "max_hp": 22,
			"intent": {"target": "random", "actions": [authored]}}])
		var rng := RandomNumberGenerator.new()
		rng.seed = 331
		var scheduler := CombatEnemyIntents.new([_enemy(1, [_block(1)])])
		_check(scheduler.bind_battle(enemy, _party_fixture(), rng), "bind RNG comparison")
		var trace: Array = []
		for turn in range(5):
			var announced: Dictionary = scheduler.get_intents()[0]
			_check(announced.get("hits", 1) == (2 if multi else 1), "cached hits retained")
			announced.erase("hits")
			trace.append([announced, rng.state])
			_check(scheduler.advance_turn(), "advance RNG comparison")
		traces.append(trace)
	_check(traces[0] == traces[1], "two hits use same weighted and random target draws, reentry cache")


func _termite_intent_source() -> Dictionary:
	var parsed := RunTypedBattleRoster._parse_catalog_text(
		FileAccess.get_file_as_string("res://data/enemies/run_enemies.json"))
	for record in parsed:
		if record.get("id") == CombatEnemies.TERMITE_ID:
			return record.duplicate(true)
	return {}


func _split_peer(id: String) -> Dictionary:
	return {"id": id, "name": id, "max_hp": 10,
		"intent": {"target": "front", "actions": [
			{"type": "attack", "amount": 2, "weight": 1}]}}


func _termite_intent_fixture(count: int = 2, seed_value: int = 707) -> Dictionary:
	var source := _termite_intent_source()
	var records: Array = [source]
	for index in range(1, count):
		records.append(_split_peer("split_peer_%d" % index))
	var enemies := CombatEnemies.new(records)
	var party := _party_fixture()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var definitions: Array = []
	for index in range(count):
		definitions.append(_enemy(index + 1, [_block(1)]))
	var scheduler := CombatEnemyIntents.new(definitions)
	if source.is_empty() or not enemies.is_valid() or not party.is_valid() \
			or not scheduler.is_valid() or not scheduler.bind_battle(enemies, party, rng):
		return {}
	return {"enemies": enemies, "party": party, "rng": rng, "intents": scheduler}


func _test_termite_split_admission() -> void:
	var f := _termite_intent_fixture(2, 707)
	_check(not f.is_empty(),
		"precondition: a genuine authored Termite fight binds the weighted scheduler")
	if f.is_empty():
		return
	var enemies: CombatEnemies = f.enemies
	var intents: CombatEnemyIntents = f.intents
	var rng: RandomNumberGenerator = f.rng
	var original_announcements := intents.get_intents()
	var original_slots := intents._slots.duplicate(true)
	var original_rng := rng.state
	_check(not intents.can_admit_split(enemies, 1),
		"AC3: a nonlethal roster admits no split announcements")
	_check(enemies.stage_split_on_death(1) == {"ok": true, "split": false}
		and intents.get_intents() == original_announcements and rng.state == original_rng,
		"AC3: nonlethal staging leaves every announcement and RNG untouched")
	_check(enemies.apply_damage(1, 26) and enemies.is_slain(1),
		"precondition: one lethal transition leaves the Termite at zero HP")
	var staged := enemies.stage_split_on_death(1)
	_check(staged.get("ok", false) and staged.get("split", false)
		and staged.get("positions") == [1, 3],
		"precondition: the existing splitter publishes one replacement and one append")
	var proposed := enemies.get_enemies()
	var rng_before := rng.state
	_check(intents.can_admit_split(enemies, 1, proposed) and rng.state == rng_before,
		"AC2: preflight accepts both halves without a scheduler draw")
	_check(intents.admit_split(enemies, 1),
		"AC2: the bound scheduler publishes both new sources")
	var announcements := intents.get_intents()
	_check(announcements.size() == 3
		and announcements.map(func(a): return a.enemy_position) == [1, 2, 3],
		"AC2: exactly one announcement per occupied slot in roster order")
	_check(intents._slots.size() == 3 and rng.state == rng_before,
		"AC2: the bound slot cache grows with the roster and consumes no RNG")
	_check(announcements[1] == original_announcements[1]
		and intents._slots[1] == original_slots[1],
		"AC2: the unrelated peer announcement and slot stay byte-for-byte intact")
	_check(announcements[0] == {"enemy_position": 1, "type": "attack",
			"amount": 3, "target_position": 1}
		and announcements[2] == {"enemy_position": 3, "type": "attack",
			"amount": 3, "target_position": 1}
		and intents._slots[0] == {"enemy_position": 1, "target": "front",
			"actions": [{"weight": 1, "action": {"type": "attack", "amount": 3}}]}
		and intents._slots[2] == {"enemy_position": 3, "target": "front",
			"actions": [{"weight": 1, "action": {"type": "attack", "amount": 3}}]},
		"AC2: each half announces its own single front attack at once-scaled half strength")
	var after := intents.get_intents()
	_check(not intents.can_admit_split(enemies, 1)
		and not intents.admit_split(enemies, 1)
		and intents.get_intents() == after,
		"AC3: a duplicate split receipt cannot publish grandchildren")
	var legacy := CombatEnemyIntents.new([_enemy(1, [_block(1)])])
	_check(not legacy.can_admit_split(enemies, 1, proposed)
		and not legacy.admit_split(enemies, 1),
		"AC3: an unbound legacy schedule never admits a split")
	var full := _termite_intent_fixture(3, 708)
	_check(full.enemies.apply_damage(1, 26) and full.enemies.is_slain(1),
		"precondition: the full-capacity Termite really dies")
	var full_before := [full.intents.get_intents(), full.intents._slots.duplicate(true),
		full.rng.state]
	_check(full.enemies.stage_split_on_death(1) == {"ok": true, "split": false}
		and not full.intents.can_admit_split(full.enemies, 1)
		and not full.intents.admit_split(full.enemies, 1)
		and [full.intents.get_intents(), full.intents._slots.duplicate(true),
			full.rng.state] == full_before,
		"AC3: full three-slot occupancy keeps the normal death and the whole schedule")
	var broken := _termite_intent_fixture(2, 709)
	broken.enemies.apply_damage(1, 26)
	broken.enemies.stage_split_on_death(1)
	broken.enemies._enemies[2]["hp"] = 0
	broken.enemies._enemies[2]["block"] = 4
	var broken_before := [broken.intents.get_intents(),
		broken.intents._slots.duplicate(true), broken.rng.state]
	_check(not broken.intents.can_admit_split(broken.enemies, 1)
		and not broken.intents.admit_split(broken.enemies, 1)
		and [broken.intents.get_intents(), broken.intents._slots.duplicate(true),
			broken.rng.state] == broken_before,
		"AC3: a malformed or modified half refuses admission atomically")
	var replay: Array = []
	for repeat_index in range(2):
		var fight := _termite_intent_fixture(2, 711)
		fight.enemies.apply_damage(1, 26)
		fight.enemies.stage_split_on_death(1)
		_check(fight.intents.admit_split(fight.enemies, 1),
			"same-seed split announcement admission succeeds")
		var snap := [fight.intents.get_intents(), fight.intents._slots.duplicate(true),
			fight.rng.state]
		if repeat_index == 0:
			replay = snap
		else:
			_check(snap == replay,
				"AC3: same-seed split announcement replay is byte-for-byte identical")


## AC1/AC2: a genuine already-floor-scaled Ram source owns its pending
## strike. Reads, wind-up, held release and a fresh fight never roll RNG.
func _test_ram_charge_seeded_cache() -> void:
	var records := RunTypedBattleRoster._parse_catalog_text(
		FileAccess.get_file_as_string("res://data/enemies/run_enemies.json"))
	var ram: Dictionary = {}
	for record in records:
		if record.get("id") == CombatEnemyIntents.CHARGE_ID:
			ram = record.duplicate(true)
	_check(not ram.is_empty() and ram.get("charge") == true
		and ram.get("intent", {}).get("actions", []).size() == 3,
		"AC1 precondition: real catalog Ram has Charge and all three authored choices")
	if ram.is_empty():
		return
	var attack: Dictionary = ram["intent"]["actions"][2].duplicate(true)
	_check(attack.get("type") == "attack" and attack.get("amount") == 8,
		"AC2 precondition: source attack has exactly eight authored damage")
	ram["intent"]["actions"] = [attack]
	ram["intent"] = RunDifficulty.scale_intent(ram["intent"], 1)
	var control := {"id": "other-foe", "max_hp": 18, "intent":
		{"target": "front", "actions": [{"type": "block", "amount": 3, "weight": 1}]}}
	var traces: Array = []
	for trial in range(2):
		var party := _party_fixture()
		var enemies := CombatEnemies.new([control, ram])
		var rng := RandomNumberGenerator.new()
		rng.seed = 871
		var selector := CombatEnemyIntents.new([_enemy(1, [_block(1)]),
			_enemy(2, [_block(1)])])
		_check(enemies.is_valid() and selector.bind_battle(enemies, party, rng)
			and enemies.get_enemy(2).get("charge") == true,
			"AC1 precondition: seeded actual two-source fight binds Ram in slot 2")
		if not selector.is_bound():
			return
		var turn := selector.get_intents()
		var state := rng.state
		_check(turn.size() == 2 and turn[0]["type"] == "block"
			and turn[1] == {"type": "attack", "amount": 0,
				"enemy_position": 2, "target_position": 1}
			and selector.get_intents() == turn and rng.state == state,
			"AC1: slot-2 Ram telegraphs zero while the other actor keeps Block")
		_check(not enemies.get_enemy(2).has("charge_pending")
			and not enemies.get_enemy(1).has("charge_pending"),
			"AC2: fresh combat has neither actor armed")
		var first := CombatEnemyPhase.new().execute_phase(party, enemies, turn, null, true)
		_check(first.get("ok") and first.get("events", []).size() == 2
			and first["events"][1].get("type") == "wind_up"
			and party.get_hero(1).get("hp") == 40
			and enemies.get_enemy(2).get("charge_pending") ==
				{"amount": 9, "target_position": 1}
			and not enemies.get_enemy(1).has("charge_pending"),
			"AC1/2: first real beat only arms scaled-nine attack on source 2")
		_check(selector.advance_turn() and rng.state == state,
			"AC2: held strike requires no new weighted roll or target roll")
		var held := selector.get_intents()
		_check(held[1] == {"type": "attack", "amount": 22,
			"enemy_position": 2, "target_position": 1},
			"AC1/2: once-scaled nine projects to exactly floor(22.5)=22")
		var next := CombatEnemyPhase.new().execute_phase(party, enemies, held, null, true)
		_check(next.get("ok") and next["events"][1].get("applied") == true
			and party.get_hero(1).get("hp") == 18
			and not enemies.get_enemy(2).has("charge_pending")
			and rng.state == state,
			"AC1/2: normal phase delivers 22 HP loss, clears only actor latch, spends no RNG")
		_check(selector.advance_turn() and selector.get_intents()[1].get("amount") == 0,
			"AC2: the next genuine attack announces wind-up again, not a repeat strike")
		traces.append([turn, first, held, next, rng.state, enemies.get_enemies(),
			party.get_heroes()])
	_check(traces.size() == 2 and traces[0] == traces[1],
		"AC2: fresh same-seed fights replay complete charge and actor/RNG history")


func _test_inkbrush_blind_schema() -> void:
	var catalog := RunTypedBattleRoster._parse_catalog_text(
		FileAccess.get_file_as_string("res://data/enemies/run_enemies.json"))
	var imp: Dictionary = {}
	for record in catalog:
		if record.get("id") == "inkbrush_imp":
			imp = record
	_check(not imp.is_empty() and imp.get("max_hp") == 23
		and imp.get("intent", {}).get("target") == "lowest_living_hp",
		"real Inkbrush Imp retains 23 HP and lowest living HP targeting")
	if imp.is_empty():
		return
	var slot := CombatEnemyIntents._weighted_slot(1, imp.intent)
	_check(not slot.is_empty() and slot.actions.size() == 3,
		"real Imp binds all three authored choices")
	var options: Array = []
	for item in slot.get("actions", []):
		options.append({"action": item.action, "weight": item.weight})
	_check(options == [
		{"action": {"type": "debuff", "amount": 2, "status": "exposed"}, "weight": 2},
		{"action": {"type": "attack", "amount": 6}, "weight": 3},
		{"action": {"type": "debuff", "amount": 1, "status": "blind_next_attack"}, "weight": 2}],
		"Imp preserves original Exposed/attack alternatives and exact Blind 1/2")
	var legal := {"type": "debuff", "amount": 1,
		"status": "blind_next_attack", "target_position": 3}
	_check(CombatEnemyIntents.valid_action(legal), "canonical Blind 1 announcement accepted")
	for amount in [0, 2, -1, true, 1.0, "1"]:
		var bad := legal.duplicate(true)
		bad["amount"] = amount
		_check(not CombatEnemyIntents.valid_action(bad),
			"Blind noncanonical amount rejected: " + str(amount))
	for status in ["blind", "blind_next_attack_extra", "weak_next_attack"]:
		var bad := legal.duplicate(true)
		bad["status"] = status
		_check(not CombatEnemyIntents.valid_action(bad), "unknown blind-like token rejected")

## These are four *different authored actors*, not a fabricated four-entry schedule.
## The weighted choices and target policies come from both shipped normal catalogs.
func _four_authored_normal_definitions() -> Array:
	var wanted := ["moth_swarm", "button_guard", "spool_stalker", "ragling_guard"]
	var found := {}
	for catalog_path in ["res://data/enemies/run_enemies.json",
			"res://data/enemies/starter_enemies.json"]:
		var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
		if not catalog is Array:
			return []
		for entry in catalog:
			if entry is Dictionary and entry.get("id") in wanted:
				var actor: Dictionary = entry.duplicate(true)
				actor["max_hp"] = int(actor["max_hp"])
				found[actor["id"]] = actor
	var definitions := []
	for id in wanted:
		if not found.has(id):
			return []
		definitions.append(found[id])
	return definitions


func _test_four_catalog_binding() -> void:
	var definitions := _four_authored_normal_definitions()
	_check(definitions.size() == 4, "AC1 precondition: both actual normal catalogs supply four distinct authored foes")
	if definitions.size() != 4:
		return
	var scheduler_definitions: Array = []
	for position in range(1, 5):
		scheduler_definitions.append(_enemy(position, [_block(1)]))
	var denied := CombatEnemies.new(definitions)
	var party := _party_fixture()
	var denied_rng := RandomNumberGenerator.new()
	denied_rng.seed = 422404
	var rejected := CombatEnemyIntents.new(scheduler_definitions)
	var denied_state := denied_rng.state
	_check(not denied.is_valid() and rejected.is_valid()
		and not rejected.bind_battle(denied, party, denied_rng)
		and not rejected.is_bound() and denied_rng.state == denied_state,
		"AC1/AC3: default roster refuses a real four-source bind without an RNG draw")
	var broken := definitions.duplicate(true)
	broken[3]["intent"]["actions"][0]["weight"] = 0
	var invalid_foes := CombatEnemies.new(broken, 4)
	var invalid_schedule := CombatEnemyIntents.new(scheduler_definitions)
	var invalid_rng := RandomNumberGenerator.new()
	invalid_rng.seed = 422405
	var invalid_state := invalid_rng.state
	var invalid_before := invalid_foes.get_enemies()
	_check(invalid_foes.is_valid() and not invalid_schedule.bind_battle(
		invalid_foes, party, invalid_rng) and invalid_rng.state == invalid_state
		and invalid_foes.get_enemies() == invalid_before and not invalid_schedule.is_bound(),
		"AC3: malformed fourth weighted catalog choice rejects atomically before RNG")
	var four := CombatEnemies.new(definitions, 4)
	var replay_four := CombatEnemies.new(definitions, 4)
	var rng := RandomNumberGenerator.new()
	var replay_rng := RandomNumberGenerator.new()
	rng.seed = 422406
	replay_rng.seed = 422406
	var bound := CombatEnemyIntents.new(scheduler_definitions)
	var replay := CombatEnemyIntents.new(scheduler_definitions)
	_check(four.is_valid() and replay_four.is_valid() and party.is_valid()
		and bound.bind_battle(four, party, rng)
		and replay.bind_battle(replay_four, _party_fixture(), replay_rng)
		and bound.is_bound() and replay.is_bound(),
		"AC1: real four-source weighted catalog bind succeeds only after explicit opt-in")
	if not bound.is_bound() or not replay.is_bound():
		return
	var input_snapshot := definitions.duplicate(true)
	for turn in range(10):
		var actions := bound.get_intents()
		var mirror := replay.get_intents()
		var source_ids: Array = []
		var valid := actions.size() == 4
		for index in range(actions.size()):
			var action: Dictionary = actions[index].duplicate(true)
			var source: int = action["enemy_position"]
			source_ids.append(four.get_enemy(source).id)
			action.erase("enemy_position")
			valid = valid and source == index + 1 and CombatEnemyIntents.valid_action(action)
		_check(valid and source_ids == [
			"moth_swarm", "button_guard", "spool_stalker", "ragling_guard"],
			"AC1: every announced beat belongs to one original catalog actor in slot order")
		_check(actions == mirror and rng.state == replay_rng.state,
			"AC3: seeded weighted four-actor replay matches full cached actions and RNG state")
		actions[0]["amount"] = -404
		_check(bound.get_intents() == mirror and rng.state == replay_rng.state,
			"AC3: editing detached fourth-roster announcements cannot mutate the cache or RNG")
		_check(bound.advance_turn() and replay.advance_turn(),
			"AC1: bound four-source schedule advances all four original catalogs")
	_check(definitions == input_snapshot,
		"AC3: seeded four-way selection does not alter authored catalog definitions")
