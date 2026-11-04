extends SceneTree

var failures: Array[String] = []
var checks := 0
var rules := CombatEnemySpecialActions.new()

const HERO_PATH := "res://data/heroes/starter_party.json"
const MAX_INT := 9223372036854775807


func _initialize() -> void:
	_test_ordered_transaction()
	_test_fear_buff_gate()
	_test_snip_transactions_and_rejections()
	_test_bidirectional_swaps()
	_test_status_additions_and_owner_turns()
	_test_dead_sources_and_rejections()
	_test_replay_and_detached_results()
	_test_tangled_enemy_debuff()
	_test_inkbrush_blind_transaction()
	_test_stitched_blind_guard()
	_test_blind_ricochet_paid_miss()
	for failure in failures:
		printerr(failure)
	print("combat_enemy_special_actions_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _party() -> CombatParty:
	var source := FileAccess.get_file_as_string(HERO_PATH)
	var definitions = JSON.parse_string(source)
	_check(not source.is_empty() and definitions is Array and definitions.size() == 3,
		"precondition: actual authored three-hero party loaded")
	if not definitions is Array or definitions.size() != 3:
		return CombatParty.new([])
	for hero in definitions:
		if hero is Dictionary and hero.get("max_hp") is float:
			_check(hero["max_hp"] == floor(hero["max_hp"]), "authored max HP is integral")
			hero["max_hp"] = int(hero["max_hp"])
	var party := CombatParty.new(definitions)
	_check(party.is_valid() and _ids(party) == ["warden", "seamstress", "tinker"]
		and party.get_hero(1)["hp"] == 40 and party.get_hero(2)["hp"] == 30
		and party.get_hero(3)["hp"] == 26,
		"precondition: real Warden 40, Seamstress 30 and Tinker 26 HP")
	return party


func _enemies() -> CombatEnemies:
	var enemies := CombatEnemies.new([
		{"id": "ragling_one", "max_hp": 12, "metadata": {"thread": [1, 2]}},
		{"id": "ragling_two", "max_hp": 14},
		{"id": "ragling_three", "max_hp": 16}])
	_check(enemies.is_valid() and enemies.get_enemies().size() == 3
		and enemies.get_enemy(1)["hp"] == 12 and enemies.get_enemy(2)["hp"] == 14
		and enemies.get_enemy(3)["hp"] == 16,
		"precondition: three living distinct enemy source slots")
	return enemies


func _ids(party: CombatParty) -> Array:
	var result: Array = []
	for hero in party.get_heroes():
		result.append(hero["id"])
	return result


func _shove(source: int, target: int, direction: int) -> Dictionary:
	return {"type": "shove", "enemy_position": source,
		"amount": 0, "target_position": target, "direction": direction}


func _debuff(source: int, target: int, status: String, amount: int) -> Dictionary:
	return {"type": "debuff", "enemy_position": source,
		"amount": amount, "target_position": target, "status": status}


func _buff(source: int, amount: int) -> Dictionary:
	return {"type": "buff", "enemy_position": source, "amount": amount}


func _event(kind: String, source: int, applied: bool, target: int = 0,
		direction: int = 0, status: String = "") -> Dictionary:
	var event := {"type": kind, "enemy_position": source, "applied": applied}
	if kind == "shove":
		event["target_position"] = target
		event["direction"] = direction
	elif kind == "debuff":
		event["target_position"] = target
		event["status"] = status
	return event


func _snapshot(party: CombatParty, enemies: CombatEnemies) -> String:
	return JSON.stringify({"party": party.get_heroes(), "enemies": enemies.get_enemies()})


func _rng_expected() -> int:
	seed(19840217)
	var result := randi()
	seed(19840217)
	return result



func _snip(source: int, target: int) -> Dictionary:
	return {"type": "snip_block", "enemy_position": source,
		"amount": 0, "target_position": target}


func _test_snip_transactions_and_rejections() -> void:
	for initial_block in [0, 6]:
		var party := _party()
		var enemies := _enemies()
		_check(party.gain_block(1, initial_block)
			and party.gain_block(2, 3) and party.gain_block(3, 4)
			and enemies.gain_block(2, 5),
			"snip precondition: concrete Block on allies and enemies")
		party._heroes[0]["statuses"] = {"weak": 2}
		party._heroes[1]["statuses"] = {"exposed": 1}
		var before := party.get_heroes()
		var foes := enemies.get_enemies()
		var identities := party._heroes.duplicate()
		var input := [_snip(1, 1)]
		var input_before := input.duplicate(true)
		var expected := before.duplicate(true)
		expected[0]["block"] = 0
		var expected_rng := _rng_expected()
		var result := rules.execute_actions(party, enemies, input)
		_check(result == {"ok": true, "events": [
			{"type": "snip_block", "enemy_position": 1, "applied": true, "target_position": 1}]},
			"snip of zero or positive Block is a legal applied non-damaging beat")
		_check(party.get_heroes() == expected and enemies.get_enemies() == foes
			and input == input_before and randi() == expected_rng,
			"snip changes only recipient Block, not HP, statuses, enemies, inputs or RNG")
		_check(is_same(party._heroes[0], identities[0])
			and is_same(party._heroes[1], identities[1])
			and is_same(party._heroes[2], identities[2]),
			"snip preserves each original live hero dictionary")
	var party := _party()
	var enemies := _enemies()
	_check(party.gain_block(1, 6) and enemies.apply_damage(1, 12)
		and enemies.is_slain(1), "slain-snipper precondition: source 1 is dead, Warden has 6 Block")
	var before_state := _snapshot(party, enemies)
	var dead_result := rules.execute_actions(party, enemies, [_snip(1, 1)])
	_check(dead_result == {"ok": true, "events": [
		{"type": "snip_block", "enemy_position": 1, "applied": false, "target_position": 1}]}
		and _snapshot(party, enemies) == before_state,
		"slain source emits inert snip beat and cannot remove Block")
	for bad in [
		{"type": "snip_block", "enemy_position": 2, "amount": 1, "target_position": 1},
		{"type": "snip_block", "enemy_position": 2, "amount": -1, "target_position": 1},
		{"type": "snip_block", "enemy_position": 2, "amount": 0, "target_position": 0},
		{"type": "snip_block", "enemy_position": 2, "amount": 0, "target_position": 4},
		{"type": "snip_block", "enemy_position": 2, "amount": 0, "target_position": true},
		{"type": "snip_block", "enemy_position": 2, "amount": 0, "target_position": 1.0},
		{"type": "snip_block", "enemy_position": 2, "amount": 0, "target_position": 1,
			"status": "weak"},
		{"type": "snip_block", "enemy_position": 2, "amount": 0, "target_position": 1,
			"extra": "forbidden"},
		{"type": "snip_block", "enemy_position": 2, "target_position": 1},
		{"type": "unknown_snip", "enemy_position": 2, "amount": 0, "target_position": 1},
		_snip(1, 1)]:
		party = _party()
		enemies = _enemies()
		_check(party.gain_block(1, 6), "malformed mixed batch starts with six real Block")
		_reject("late malformed snip preserves earlier staged Block removal " + str(bad),
			[_snip(1, 1), bad], party, enemies)
	party = _party()
	enemies = _enemies()
	_check(party.gain_block(1, 6) and party.apply_damage(2, 30)
		and party.is_downed(2), "downed snip precondition: middle is genuinely Torn")
	_reject("late snip on Torn hero rolls back earlier positive snip",
		[_snip(1, 1), _snip(2, 2)], party, enemies)
	party = _party()
	enemies = _enemies()
	_check(party.gain_block(1, 6) and party.apply_damage(2, 30)
		and party.is_downed(2), "late mixed batch precondition: target genuinely downed")
	_reject("late invalid debuff after staged snip is atomic",
		[_snip(1, 1), _debuff(2, 2, "weak", 1)], party, enemies)


func _test_ordered_transaction() -> void:
	_check(rules.has_method("execute_actions"), "public scene-free entrypoint exists")
	var party := _party()
	var enemies := _enemies()
	_check(party.gain_block(1, 6) and party.gain_block(2, 4)
		and party.gain_block(3, 2) and enemies.gain_block(3, 7),
		"precondition: distinguishable pre-existing hero and enemy Block")
	party._heroes[0]["statuses"] = {"bleed": 2}
	party._heroes[1]["statuses"] = {"exposed": 1}
	party._heroes[2]["statuses"] = {"weak": 2}
	party._heroes[0]["metadata"] = {"nested": [{"mark": [1, 2, 3]}]}
	enemies._enemies[2]["statuses"] = {"exposed": 3}
	var original_heroes := party.get_heroes()
	var original_enemies := enemies.get_enemies()
	var references := {}
	for hero in party._heroes:
		references[hero["id"]] = hero
	var actions := [_buff(3, 1), _shove(1, 1, 1), _debuff(2, 1, "weak", 1)]
	var untouched_actions := actions.duplicate(true)
	var expected_rng := _rng_expected()
	var result := rules.execute_actions(party, enemies, actions)
	_check(randi() == expected_rng, "mixed transaction consumes no global RNG")
	_check(result == {"ok": true, "events": [
		_event("shove", 1, true, 1, 1),
		_event("debuff", 2, true, 1, 0, "weak"),
		_event("buff", 3, true)]},
		"AC1: unordered 3,1,2 announcements execute as 1,2,3 with typed events")
	_check(actions == untouched_actions, "caller action records and order remain immutable")
	_check(_ids(party) == ["seamstress", "warden", "tinker"]
		and party.get_hero(1)["position"] == 1
		and party.get_hero(2)["position"] == 2 and party.get_hero(3)["position"] == 3,
		"AC1: swap commits to fixed positions without changing actor IDs")
	var expected_heroes := original_heroes.duplicate(true)
	expected_heroes[0] = original_heroes[1].duplicate(true)
	expected_heroes[1] = original_heroes[0].duplicate(true)
	expected_heroes[0]["position"] = 1
	expected_heroes[1]["position"] = 2
	expected_heroes[0]["statuses"]["weak"] = 1
	var expected_enemies := original_enemies.duplicate(true)
	expected_enemies[2]["block"] += 1
	_check(party.get_heroes() == expected_heroes and enemies.get_enemies() == expected_enemies,
		"AC1: exact complete rosters retain 40/30/26 HP, old Block/status/metadata; only new Weak and one enemy Block")
	_check(is_same(party._heroes[0], references["seamstress"])
		and is_same(party._heroes[1], references["warden"])
		and is_same(party._heroes[2], references["tinker"]),
		"swaps retain original live actor dictionary identities")
	var reader := party.get_heroes()
	reader[0]["statuses"]["weak"] = 444
	reader[1]["metadata"]["nested"][0]["mark"].clear()
	_check(party.get_heroes() == expected_heroes,
		"nested reader mutation cannot change authoritative state")
	_check(enemies.apply_damage(3, 3) and enemies.get_enemy(3)["hp"] == 16
		and enemies.get_enemy(3)["block"] == 5,
		"AC1: gained enemy Block absorbs later attack damage before HP")


func _test_fear_buff_gate() -> void:
	for feared in [true, false]:
		var party := _party()
		var enemies := _enemies()
		_check(enemies.gain_block(1, 2), "Fear fixture starts with two real Block")
		enemies._enemies[0]["statuses"] = {"weak": 1}
		if feared:
			enemies._enemies[0]["statuses"]["cannot_buff_next_turn"] = true
		var before_party := party.get_heroes()
		var expected := enemies.get_enemies()
		var original: Dictionary = enemies._enemies[0]
		if not feared:
			expected[0]["block"] = 5
		var rng_expected := _rng_expected()
		var result := rules.execute_actions(party, enemies, [_buff(1, 3)])
		_check(result == {"ok": true, "events": [_event("buff", 1, not feared)]}
			and party.get_heroes() == before_party and enemies.get_enemies() == expected
			and is_same(enemies._enemies[0], original) and randi() == rng_expected,
			"Fear alone skips buff without aging statuses; unlocked buff adds exactly three, preserving rosters/identity/RNG")

	var party := _party()
	var enemies := _enemies()
	_check(enemies.gain_block(1, 2), "expiry fixture has measurable prior Block")
	enemies._enemies[0]["statuses"] = {"cannot_buff_next_turn": true, "weak": 2}
	var expected := enemies.get_enemies()
	expected[1]["block"] = 3
	var before_party := party.get_heroes()
	var rng_expected := _rng_expected()
	var result := rules.execute_actions(party, enemies, [_buff(2, 3), _buff(1, 3)])
	_check(result == {"ok": true, "events": [
		_event("buff", 1, false), _event("buff", 2, true)]}
		and enemies.get_enemies() == expected and party.get_heroes() == before_party
		and randi() == rng_expected,
		"feared skip preserves Fear/Weak and allows separate later source in position order")
	var detached := enemies.get_enemies()
	var tick := CombatStatusTurnBatch.new().tick_side("enemies", detached)
	expected[0]["statuses"] = {"weak": 1}
	expected[1]["statuses"] = {}
	expected[2]["statuses"] = {}
	_check(tick["ok"] and tick["actors"] == expected
		and enemies.get_enemies() == detached,
		"only detached owner-turn tick removes Fear and independently ages Weak two to one")
	var fresh := CombatEnemies.new(tick["actors"])
	fresh._enemies = tick["actors"].duplicate(true)
	_check(fresh.is_valid() and fresh.get_enemies() == expected,
		"rehydrated valid enemy roster preserves exact post-owner-turn state")
	expected[0]["block"] = 5
	result = rules.execute_actions(party, fresh, [_buff(1, 3)])
	_check(result == {"ok": true, "events": [_event("buff", 1, true)]}
		and fresh.get_enemies() == expected and party.get_heroes() == before_party,
		"identical buff after owner-turn expiry grants full three Block")

	enemies = _enemies()
	enemies._enemies[0]["statuses"] = {"cannot_buff_next_turn": true, "weak": 1}
	_check(enemies.apply_damage(1, 12) and enemies.is_slain(1), "feared source genuinely slain")
	var stable := _snapshot(party, enemies)
	rng_expected = _rng_expected()
	_check(rules.execute_actions(party, enemies, [_buff(1, 3)]) == {
		"ok": true, "events": [_event("buff", 1, false)]}
		and _snapshot(party, enemies) == stable and randi() == rng_expected,
		"slain feared source remains inert without status or RNG changes")
	for malformed in [false, 1, 1.0, "true"]:
		enemies = _enemies()
		enemies._enemies[1]["statuses"] = {"cannot_buff_next_turn": malformed}
		_reject("malformed Fear rejects earlier staged buff", [_buff(1, 3), _buff(2, 3)], party, enemies)
	enemies = _enemies()
	enemies._enemies[0]["statuses"] = {"cannot_buff_next_turn": true, "weak": 1}
	_reject("malformed later action after feared skip", [_buff(1, 3), _buff(2, 0)], party, enemies)
	enemies._enemies[2]["statuses"] = {"weak": "1"}
	_reject("unrelated malformed Weak rejects feared batch", [_buff(1, 3)], party, enemies)


func _test_bidirectional_swaps() -> void:
	for parameters in [[1, 1], [2, -1], [2, 1], [3, -1]]:
		var source_position: int = parameters[0]
		var direction: int = parameters[1]
		var party := _party()
		var enemies := _enemies()
		var original := party.get_heroes()
		for index in range(3):
			_check(party.apply_damage(index + 1, index + 1)
				and party.gain_block(index + 1, index + 3),
				"precondition: all heroes have unique HP and Block")
			party._heroes[index]["statuses"] = {"bleed": index + 1,
				"weak": index + 2, "exposed": index + 3}
		original = party.get_heroes()
		var expected := original.duplicate(true)
		var other_index: int = source_position + direction - 1
		var first_index: int = source_position - 1
		var tmp: Dictionary = expected[first_index]
		expected[first_index] = expected[other_index]
		expected[other_index] = tmp
		expected[first_index]["position"] = first_index + 1
		expected[other_index]["position"] = other_index + 1
		var before_enemies := enemies.get_enemies()
		var result := rules.execute_actions(party, enemies, [_shove(1, source_position, direction)])
		_check(result == {"ok": true, "events": [
			_event("shove", 1, true, source_position, direction)]},
			"AC2: direction and source are exactly reported")
		_check(party.get_heroes() == expected and enemies.get_enemies() == before_enemies,
			"AC2: legal swap preserves every non-position hero field and all enemy records")
	# Explicit reverse of both adjacent pairs with four directed moves.
	for parameters in [[1, 1], [2, -1], [2, 1], [3, -1]]:
		var party := _party()
		var enemies := _enemies()
		var start := party.get_heroes()
		var result := rules.execute_actions(party, enemies,
			[_shove(1, parameters[0], parameters[1])])
		_check(result["ok"] and result["events"].size() == 1
			and _ids(party) != ["warden", "seamstress", "tinker"],
			"each of 1->2, 2->1, 2->3 and 3->2 is a legal live swap")
		_check(party.get_hero(parameters[0] + parameters[1])["id"]
			== start[parameters[0] - 1]["id"],
			"directed mover arrives in exactly adjacent destination")


func _test_status_additions_and_owner_turns() -> void:
	var party := _party()
	var enemies := _enemies()
	_check(party.gain_block(1, 7), "precondition: Warden is shielded for Bleed test")
	party._heroes[0]["statuses"] = {"bleed": 1, "weak": 1}
	var result := rules.execute_actions(party, enemies, [
		_debuff(3, 1, "exposed", 1),
		_debuff(1, 1, "bleed", 2),
		_debuff(2, 1, "weak", 1)])
	_check(result == {"ok": true, "events": [
		_event("debuff", 1, true, 1, 0, "bleed"),
		_event("debuff", 2, true, 1, 0, "weak"),
		_event("debuff", 3, true, 1, 0, "exposed")]},
		"AC2: source-ordered status actions retain their names and destinations")
	_check(party.get_hero(1)["statuses"] == {"bleed": 3, "weak": 2, "exposed": 1}
		and party.get_hero(1)["hp"] == 40 and party.get_hero(1)["block"] == 7,
		"AC2: same counters add, new named counter only, no immediate aging/HP loss")
	var statuses := CombatStatuses.new()
	_check(statuses.adjusted_attack_damage(9, {"weak": 1}, {}) == 6
		and statuses.adjusted_attack_damage(9, {}, {"exposed": 1}) == 13
		and statuses.adjusted_attack_damage(9, {"weak": 1}, {"exposed": 1}) == 10
		and statuses.adjusted_attack_damage(1, {"weak": 1}, {}) == 0,
		"AC2: -25% Weak, +50% Exposed, combined 9/8 and floor-once minimum zero")
	var batch := CombatStatusTurnBatch.new()
	var original := party.get_heroes()
	var first := batch.tick_side("heroes", original)
	_check(first["ok"] and first["actors"][0]["hp"] == 37
		and first["actors"][0]["block"] == 7
		and first["actors"][0]["statuses"] == {"bleed": 2, "weak": 1}
		and first["events"][0]["bleed_hp_loss"] == 3,
		"AC2: Bleed bypasses seven Block, all statuses age at owner-turn end only")
	var second := batch.tick_side("heroes", first["actors"])
	_check(second["actors"][0]["hp"] == 35
		and second["actors"][0]["block"] == 7
		and second["actors"][0]["statuses"] == {"bleed": 1},
		"AC2: second owner turn loses two HP and expires Weak")
	var third := batch.tick_side("heroes", second["actors"])
	_check(third["actors"][0]["hp"] == 34 and third["actors"][0]["statuses"] == {}
		and party.get_heroes() == original and enemies.get_enemies()[0]["block"] == 0,
		"AC2: third tick expires Bleed and no tick writes authoritative state")
	# Add an Exposed and Weak to different heroes after an intervening swap.
	party = _party()
	enemies = _enemies()
	result = rules.execute_actions(party, enemies, [
		_shove(1, 2, 1), _debuff(2, 2, "exposed", 1)])
	_check(result["ok"] and party.get_hero(2)["id"] == "tinker"
		and party.get_hero(2)["statuses"] == {"exposed": 1}
		and party.get_hero(3)["id"] == "seamstress",
		"AC2: debuff after a prior swap targets current occupant, not original slot owner")


func _reject(name: String, actions: Array, party: CombatParty = null,
		enemies: CombatEnemies = null) -> void:
	if party == null:
		party = _party()
	if enemies == null:
		enemies = _enemies()
	var before := _snapshot(party, enemies)
	var input := actions.duplicate(true)
	var expected_rng := _rng_expected()
	var result := rules.execute_actions(party, enemies, actions)
	_check(result == {"ok": false, "events": []}, name + ": invalid batch fails atomically")
	_check(_snapshot(party, enemies) == before, name + ": full authoritative JSON snapshot unchanged")
	_check(actions == input, name + ": caller source order and nested fields unchanged")
	_check(randi() == expected_rng, name + ": no global RNG consumed")


func _test_dead_sources_and_rejections() -> void:
	var party := _party()
	var enemies := _enemies()
	_check(enemies.apply_damage(1, 12) and enemies.is_slain(1),
		"precondition: enemy slot 1 truly slain and remains in original slot")
	var before := enemies.get_enemy(1)
	var result := rules.execute_actions(party, enemies, [
		_buff(3, 1), _debuff(2, 1, "bleed", 2), _shove(1, 1, 1)])
	_check(result == {"ok": true, "events": [
		_event("shove", 1, false, 1, 1),
		_event("debuff", 2, true, 1, 0, "bleed"),
		_event("buff", 3, true)]},
		"AC3: dead first source skipped, later valid actions still execute in slot order")
	_check(_ids(party) == ["warden", "seamstress", "tinker"]
		and party.get_hero(1)["statuses"] == {"bleed": 2}
		and enemies.get_enemy(1) == before and enemies.get_enemy(3)["block"] == 1,
		"AC3: dead source neither shoves nor buffs, surviving debuff and buff apply")
	party = _party()
	enemies = _enemies()
	_check(enemies.apply_damage(1, 12), "precondition: slain source for no-action-only test")
	var stable := _snapshot(party, enemies)
	result = rules.execute_actions(party, enemies, [_buff(1, 2)])
	_check(result == {"ok": true, "events": [_event("buff", 1, false)]}
		and _snapshot(party, enemies) == stable,
		"AC3: sole slain source leaves both full authoritative rosters unchanged")

	var valid_first := _shove(1, 1, 1)
	var bad_later: Array = [
		null, [], {}, "debuff",
		{"type": "buff", "enemy_position": 2},
		{"type": "debuff", "enemy_position": 2, "amount": 1},
		{"type": "heal", "enemy_position": 2, "amount": 1},
		{"type": "buff", "enemy_position": 2, "amount": 1, "extra": 1},
		{"type": "buff", "enemy_position": 2, "amount": -1},
		{"type": "buff", "enemy_position": 2, "amount": 0},
		{"type": "buff", "enemy_position": 2, "amount": 1.0},
		{"type": "buff", "enemy_position": 2, "amount": "1"},
		{"type": "buff", "enemy_position": 2.0, "amount": 1},
		{"type": "buff", "enemy_position": 0, "amount": 1},
		{"type": "buff", "enemy_position": 4, "amount": 1},
		{"type": "debuff", "enemy_position": 2, "amount": 1,
			"status": "poison", "target_position": 1},
		{"type": "debuff", "enemy_position": 2, "amount": -1,
			"status": "weak", "target_position": 1},
		{"type": "debuff", "enemy_position": 2, "amount": 0,
			"status": "weak", "target_position": 1},
		{"type": "debuff", "enemy_position": 2, "amount": 1.5,
			"status": "weak", "target_position": 1},
		{"type": "debuff", "enemy_position": 2, "amount": 1,
			"status": "bleed", "target_position": 0},
		{"type": "debuff", "enemy_position": 2, "amount": 1,
			"status": "exposed", "target_position": 4},
		{"type": "debuff", "enemy_position": 2, "amount": 1,
			"status": false, "target_position": 1},
		{"type": "shove", "enemy_position": 2, "amount": 1,
			"direction": 1, "target_position": 1},
		{"type": "shove", "enemy_position": 2, "amount": 0,
			"direction": 0, "target_position": 1},
		{"type": "shove", "enemy_position": 2, "amount": 0,
			"direction": 1.0, "target_position": 1},
		{"type": "shove", "enemy_position": 2, "amount": 0,
			"direction": 1, "target_position": 3},
		{"type": "shove", "enemy_position": 2, "amount": 0,
			"direction": -1, "target_position": 1},
		{"type": "shove", "enemy_position": 2, "amount": 0,
			"direction": 1, "target_position": 0},
		{"type": "shove", "enemy_position": 2, "amount": 0,
			"direction": -1, "target_position": 4},
		{"type": "shove", "enemy_position": 2, "amount": 0,
			"direction": 1, "target_position": "1"},
		{"type": "shove", "enemy_position": 2, "amount": 0,
			"direction": 1, "target_position": 1, "extra": true},
		{"type": "debuff", "enemy_position": 2, "amount": 1,
			"status": "tangle", "target_position": 1},
		{"type": "debuff", "enemy_position": 2, "amount": 0,
			"status": "tangled", "target_position": 1},
		{"type": "debuff", "enemy_position": 2, "amount": -1,
			"status": "tangled", "target_position": 1},
		{"type": "debuff", "enemy_position": 2, "amount": 1.5,
			"status": "tangled", "target_position": 1},
		{"type": "debuff", "enemy_position": 2, "amount": "1",
			"status": "tangled", "target_position": 1},
		{"type": "debuff", "enemy_position": 2, "amount": 1,
			"status": "tangled", "target_position": 0},
		{"type": "debuff", "enemy_position": 2, "amount": 1,
			"status": "tangled", "target_position": 4},
		_buff(1, 1), _debuff(1, 1, "weak", 1), _debuff(1, 1, "tangled", 1)]
	for bad in bad_later:
		_reject("late bad/duplicate action " + str(bad), [valid_first, bad])
	_reject("duplicate after valid buff", [_buff(1, 1), _shove(1, 2, 1)])
	_reject("invalid lone source", [_buff(4, 1)])
	_reject("bad early source followed by valid later source", [_buff(0, 1), _buff(3, 1)])
	party = _party()
	enemies = _enemies()
	_check(party.apply_damage(2, 30) and party.is_downed(2),
		"precondition: middle hero downed cannot be exchanged")
	_reject("downed neighbor in later shove", [_buff(1, 2), _shove(2, 1, 1)],
		party, enemies)
	_reject("downed hero initiating shove", [_buff(1, 2), _shove(2, 2, -1)],
		party, enemies)
	_reject("downed hero status target", [_buff(1, 2), _debuff(2, 2, "weak", 1)],
		party, enemies)

	party = _party()
	enemies = _enemies()
	_check(enemies.gain_block(3, MAX_INT - 1)
		and enemies.get_enemy(3)["block"] == MAX_INT - 1,
		"precondition: third living source one below Block ceiling")
	_reject("late Block arithmetic overflow after shove/debuff",
		[_shove(1, 1, 1), _debuff(2, 1, "weak", 1), _buff(3, 2)],
		party, enemies)
	party = _party()
	enemies = _enemies()
	party._heroes[1]["statuses"] = {"weak": MAX_INT}
	_reject("late Weak counter arithmetic overflow after shove",
		[_shove(1, 1, 1), _debuff(2, 1, "weak", 1)],
		party, enemies)
	party = _party()
	enemies = _enemies()
	party._heroes[1]["statuses"] = {"tangled": MAX_INT}
	_reject("late Tangled counter arithmetic overflow after shove",
		[_shove(1, 1, 1), _debuff(2, 1, "tangled", 1)],
		party, enemies)
	party = _party()
	enemies = _enemies()
	party._heroes[2]["statuses"] = {"poison": 1}
	_reject("invalid original hero statuses reject even lone buff", [_buff(1, 1)],
		party, enemies)
	enemies._enemies[2]["statuses"] = {"weak": -1}
	_reject("invalid original enemy statuses", [_buff(1, 1)], party, enemies)
	party = _party()
	enemies = _enemies()
	var foes_before := enemies.get_enemies()
	_check(rules.execute_actions(null, enemies, [_buff(1, 1)]) ==
		{"ok": false, "events": []} and enemies.get_enemies() == foes_before,
		"null party rejected leaving live enemies intact")
	var party_before := party.get_heroes()
	_check(rules.execute_actions(party, null, [_buff(1, 1)]) ==
		{"ok": false, "events": []} and party.get_heroes() == party_before,
		"null enemies rejected leaving live party intact")
	_check(rules.execute_actions(CombatParty.new([]), enemies, [_buff(1, 1)]) ==
		{"ok": false, "events": []} and enemies.get_enemies() == foes_before,
		"invalid party rejected")
	_check(rules.execute_actions(party, CombatEnemies.new([]), [_buff(1, 1)]) ==
		{"ok": false, "events": []} and party.get_heroes() == party_before,
		"invalid enemies rejected")


func _test_replay_and_detached_results() -> void:
	var expected: Dictionary = {}
	for repetition in range(3):
		var party := _party()
		var enemies := _enemies()
		_check(party.gain_block(2, 3) and enemies.gain_block(3, 2),
			"replay: nontrivial initial defense established")
		var actions := [_buff(3, 1), _shove(1, 1, 1), _debuff(2, 1, "weak", 1)]
		var before_actions := actions.duplicate(true)
		var before := _snapshot(party, enemies)
		var rng_expected := _rng_expected()
		var result := rules.execute_actions(party, enemies, actions)
		var after := _snapshot(party, enemies)
		_check(result["ok"] and result["events"].size() == 3
			and _ids(party) == ["seamstress", "warden", "tinker"]
			and party.get_hero(1)["statuses"] == {"weak": 1}
			and enemies.get_enemy(3)["block"] == 3,
			"AC4: every repeated real actor fixture effects correct")
		_check(before != after and actions == before_actions and randi() == rng_expected,
			"AC4: deterministic replay changes only models, not input or global RNG")
		if repetition == 0:
			expected = {"result": result.duplicate(true), "after": after}
		else:
			_check(result == expected["result"] and after == expected["after"],
				"AC4: identical fresh models and repeated seed yield exact same typed events and snapshots")
		var unmodified_result := result.duplicate(true)
		var result_again := rules.execute_actions(party, enemies, [])
		_check(result_again == {"ok": true, "events": []}
			and _snapshot(party, enemies) == after,
			"empty batch returns success without modifying anything")
		result["events"][0]["target_position"] = 999
		result["events"][0]["direction"] = -1
		result["events"].clear()
		_check(unmodified_result == expected["result"]
			and result_again == {"ok": true, "events": []}
			and _snapshot(party, enemies) == after,
			"events are independent detached return dictionaries")


func _test_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _test_deck(cards: Array[String], seed_value: int = 4701) -> CombatDeck:
	var deck := CombatDeck.new(cards, _test_rng(seed_value))
	_check(deck.draw_pile.size() == cards.size(), "test deck has all supplied cards")
	_check(deck.start_turn() and deck.turn_active and deck.energy == 3,
		"test deck starts active with 3 energy")
	return deck


func _deck_snapshot(deck: CombatDeck, party: CombatParty) -> Dictionary:
	var result := {}
	if party != null:
		result["party"] = party.get_heroes()
	if deck != null:
		result["hand"] = deck.hand.duplicate(true)
		result["draw"] = deck.draw_pile.duplicate(true)
		result["discard"] = deck.discard_pile.duplicate(true)
		result["energy"] = deck.energy
		result["turn"] = deck.turn_active
		result["state_energy"] = deck.combat_state.energy
		result["state_turn"] = deck.combat_state.player_turn_active
		result["rng_seed"] = deck._rng.seed
		result["rng_state"] = deck._rng.state
	return result


## Full authoritative state for a paid-miss call: rosters, deck piles, energy and
## both run-RNG fields, so any hidden spend, draw or hit shows up as a difference.
func _blind_state(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies) -> String:
	return JSON.stringify({"deck": _deck_snapshot(deck, party),
		"enemies": enemies.get_enemies()})


## A real shared CombatDeck holding two copies of one card plus a spare.
func _ricochet_deck(card_id: String, seed_value: int = 49217) -> CombatDeck:
	var deck := CombatDeck.new([card_id, card_id, "tinker_spare_parts"], _test_rng(seed_value))
	_check(deck.start_turn() and deck.turn_active and deck.energy == 3,
		"precondition: genuine shared deck starts active with three energy")
	deck.hand.assign([card_id, card_id])
	deck.draw_pile.assign(["tinker_spare_parts"])
	deck.discard_pile.clear()
	_check(deck.hand.count(card_id) == 2 and deck.energy == 3,
		"precondition: two held " + card_id + " copies and three energy")
	return deck


func _armed_party() -> CombatParty:
	var party := _party()
	party._heroes[2]["statuses"] = {"blind_next_attack": 1}
	_check(party.get_hero(3).get("id") == "tinker"
		and party.get_hero(3).get("statuses", {}).get("blind_next_attack") == 1
		and party.get_hero(3).hp == 26,
		"precondition: Blind 1 armed on the living back-seat Tinker")
	return party


## A rejected cast must be a complete no-op: no energy, card, status, actor or RNG.
func _blind_reject(service: CombatHeroBlindMiss, deck: CombatDeck,
		party: CombatParty, enemies: CombatEnemies, card_id: String, target: int,
		definition: Dictionary, discount: int, label: String) -> Dictionary:
	var before := _blind_state(deck, party, enemies)
	var result := service.attempt(deck, party, enemies, card_id, target, definition, discount)
	_check(not result.get("ok", false) and _blind_state(deck, party, enemies) == before,
		label + ": pays no energy, discards nothing, spends no Blind and draws no RNG")
	return result


func _apply_turn_batch(party: CombatParty, ticked_actors: Array) -> void:
	for index in range(CombatParty.PARTY_SIZE):
		var hero: Dictionary = party._heroes[index]
		var next: Dictionary = ticked_actors[index]
		hero["hp"] = next["hp"]
		hero["block"] = next["block"]
		if hero.has("statuses") or not next["statuses"].is_empty():
			hero["statuses"] = next["statuses"].duplicate(true)


func _test_tangled_enemy_debuff() -> void:
	# --- AC1: Tangled debuff execution, receipt shape, and state isolation ---
	var party := _party()
	var enemies := _enemies()
	_check(party.gain_block(1, 4) and party.gain_block(2, 6) and party.gain_block(3, 2),
		"AC1: distinct initial block on heroes")
	_check(enemies.gain_block(1, 3) and enemies.gain_block(2, 5),
		"AC1: distinct initial block on enemies")
	var before_heroes := party.get_heroes()
	var before_foes := enemies.get_enemies()
	var identities := party._heroes.duplicate()
	var authored_action := {
		"type": "debuff",
		"enemy_position": 1,
		"amount": 1,
		"target_position": 2,
		"status": "tangled"
	}
	var input_actions := [authored_action]
	var input_before := input_actions.duplicate(true)
	var expected_rng := _rng_expected()
	var result := rules.execute_actions(party, enemies, input_actions)

	_check(randi() == expected_rng, "AC1: execute_actions consumes no global RNG")
	_check(result == {"ok": true, "events": [
		{"type": "debuff", "enemy_position": 1, "applied": true, "target_position": 2, "status": "tangled"}]},
		"AC1: execute_actions succeeds and emits exact receipt shape")
	_check(input_actions == input_before, "AC1: caller action records and order remain immutable")
	_check(party.get_hero(2)["id"] == "seamstress"
		and party.get_hero(2)["statuses"] == {"tangled": 1}
		and party.get_hero(2)["hp"] == 30 and party.get_hero(2)["block"] == 6,
		"AC1: writes Tangled 1 on only the living hero currently at position 2, HP and Block unchanged")
	_check(party.get_hero(1)["id"] == "warden" and party.get_hero(1)["hp"] == 40
		and party.get_hero(1)["block"] == 4 and party.get_hero(1).get("statuses", {}).is_empty(),
		"AC1: hero at position 1 untouched in HP, Block, and statuses")
	_check(party.get_hero(3)["id"] == "tinker" and party.get_hero(3)["hp"] == 26
		and party.get_hero(3)["block"] == 2 and party.get_hero(3).get("statuses", {}).is_empty(),
		"AC1: hero at position 3 untouched in HP, Block, and statuses")
	var expected_heroes := before_heroes.duplicate(true)
	expected_heroes[1]["statuses"] = {"tangled": 1}
	_check(party.get_heroes() == expected_heroes and enemies.get_enemies() == before_foes,
		"AC1: exact snapshots verify no mutation to unrelated heroes, enemies, HP, Block or roster order")
	_check(is_same(party._heroes[0], identities[0])
		and is_same(party._heroes[1], identities[1])
		and is_same(party._heroes[2], identities[2]),
		"AC1: retains original live hero dictionary identities")

	# --- AC2: Rules enforcement (Damage, Movement denial, Shove allowed, Expiry) ---
	var statuses_service := CombatStatuses.new()
	var tangled_hero_statuses: Dictionary = party.get_hero(2)["statuses"]

	# 1. Damage rules
	_check(statuses_service.adjusted_attack_damage(8, {}, tangled_hero_statuses) == 10,
		"AC2: incoming attack against Tangled 1 hero gets +2 damage (8 to 10)")
	_check(statuses_service.adjusted_attack_damage(8, {"weak": 1}, tangled_hero_statuses) == 8,
		"AC2: Tangled +2 applies after attacker Weak floor (8 * 3/4 = 6 to 8)")
	_check(statuses_service.adjusted_attack_damage(8, {"weak": 1}, {"exposed": 1, "tangled": 1}) == 11,
		"AC2: Tangled +2 applies after attacker Weak and defender Exposed floor (8 * 9/8 = 9 to 11)")
	_check(statuses_service.adjusted_attack_damage(8, {}, {"tangled": 3}) == 10,
		"AC2: +2 damage is independent of Tangled counter magnitude (Tangled 3 is still +2)")
	_check(statuses_service.adjusted_attack_damage(0, {}, tangled_hero_statuses) == 0,
		"AC2: zero-base attack gets no Tangled bonus")
	_check(statuses_service.adjusted_attack_damage(8, {}, party.get_hero(1).get("statuses", {})) == 8,
		"AC2: untangled hero at position 1 receives unmodified base damage")

	# 2. Movement denial: ally paid swap involving Tangled hero
	var backstep_def := M02PositionCards.new().get_definition("warden_backstep")
	var deck := _test_deck(["warden_backstep"])
	var before_swap_snap := _deck_snapshot(deck, party)
	_check(deck.hand.has("warden_backstep") and deck.energy >= backstep_def["cost"] and deck.turn_active,
		"AC2 precondition: warden_backstep legitimately held, affordable, turn active")
	_check(CombatPositionSwaps.preview_adjacent_swap(party, 1, 1).get("ok", false),
		"AC2 precondition: generic preview succeeds for adjacent swap 1 to 2")
	var swap_denied := CombatPositionSwaps.play_move_card(deck, party, "warden_backstep", backstep_def)
	_check(not swap_denied, "AC2: ally swap involving Tangled neighbor at position 2 is denied")
	_check(_deck_snapshot(deck, party) == before_swap_snap,
		"AC2: denied swap causes no energy, hand, discard or position mutation")

	# Mover itself Tangled
	var mover_tangled_party := _party()
	mover_tangled_party._heroes[0]["statuses"] = {"tangled": 1}
	var mover_deck := _test_deck(["warden_backstep"])
	var mover_snap := _deck_snapshot(mover_deck, mover_tangled_party)
	var mover_swap_denied := CombatPositionSwaps.play_move_card(
		mover_deck, mover_tangled_party, "warden_backstep", backstep_def)
	_check(not mover_swap_denied, "AC2: ally swap with Tangled mover at position 1 is denied")
	_check(_deck_snapshot(mover_deck, mover_tangled_party) == mover_snap,
		"AC2: denied mover-tangled swap preserves deck and party state")

	# 3. Enemy shove is NOT blocked by Tangled
	var shove_result := rules.execute_actions(party, enemies, [_shove(1, 2, -1)])
	_check(shove_result == {"ok": true, "events": [_event("shove", 1, true, 2, -1)]},
		"AC2: enemy shove targeting Tangled hero succeeds")
	_check(_ids(party) == ["seamstress", "warden", "tinker"]
		and party.get_hero(1)["id"] == "seamstress" and party.get_hero(1)["statuses"] == {"tangled": 1}
		and party.get_hero(2)["id"] == "warden",
		"AC2: enemy shove moved Tangled Seamstress to position 1 and Warden to position 2")

	# 4. Hero owner-turn tick expires Tangled 1 so later legal ally swap can proceed
	var batch := CombatStatusTurnBatch.new()
	var tick_result := batch.tick_side("heroes", party.get_heroes())
	_check(tick_result.get("ok", false)
		and tick_result["actors"][0]["statuses"].is_empty(),
		"AC2: hero owner-turn tick expires Tangled 1 to empty statuses")
	_apply_turn_batch(party, tick_result["actors"])
	_check(party.get_hero(1)["statuses"].is_empty()
		and party.get_hero(2).get("statuses", {}).is_empty(),
		"AC2: Seamstress at position 1 and Warden at position 2 are now clear of Tangled")

	# Now Warden at pos 2 plays warden_advance (-1 direction to swap with pos 1)
	var advance_def := M02PositionCards.new().get_definition("warden_advance")
	var advance_deck := _test_deck(["warden_advance"])
	var advance_ok := CombatPositionSwaps.play_move_card(
		advance_deck, party, "warden_advance", advance_def)
	_check(advance_ok, "AC2: legal ally swap succeeds after Tangled expiry")
	_check(_ids(party) == ["warden", "seamstress", "tinker"]
		and party.get_hero(1)["id"] == "warden" and party.get_hero(2)["id"] == "seamstress",
		"AC2: Warden and Seamstress successfully swapped positions")
	_check(advance_deck.energy == 2 and advance_deck.hand.is_empty()
		and advance_deck.discard_pile == ["warden_advance"],
		"AC2: successful play spent 1 energy and moved card to discard")

	# --- AC3: Stacking, shove re-targeting, dead source, atomic validation ---
	# 1. Two ordered debuffs on same hero accumulate additively
	var p3 := _party()
	var e3 := _enemies()
	var res3 := rules.execute_actions(p3, e3, [
		_debuff(1, 2, "tangled", 1),
		_debuff(2, 2, "tangled", 2)
	])
	_check(res3 == {"ok": true, "events": [
		_event("debuff", 1, true, 2, 0, "tangled"),
		_event("debuff", 2, true, 2, 0, "tangled")]},
		"AC3: two ordered debuffs on same hero succeed with ordered events")
	_check(p3.get_hero(2)["statuses"] == {"tangled": 3}
		and p3.get_hero(2)["hp"] == 30 and p3.get_hero(2)["block"] == 0,
		"AC3: Tangled values accumulate additively (1 + 2 is 3), no immediate aging or damage")
	_check(p3.get_hero(1).get("statuses", {}).is_empty()
		and p3.get_hero(3).get("statuses", {}).is_empty(),
		"AC3: untargeted heroes have no statuses")

	# 2. Preceding shove changes target occupant for subsequent debuff
	p3 = _party()
	e3 = _enemies()
	res3 = rules.execute_actions(p3, e3, [
		_shove(1, 1, 1),
		_debuff(2, 2, "tangled", 2)
	])
	_check(res3 == {"ok": true, "events": [
		_event("shove", 1, true, 1, 1),
		_event("debuff", 2, true, 2, 0, "tangled")]},
		"AC3: shove followed by Tangled debuff executes in order")
	_check(_ids(p3) == ["seamstress", "warden", "tinker"],
		"AC3: shove moved Seamstress to 1 and Warden to 2")
	_check(p3.get_hero(2)["id"] == "warden" and p3.get_hero(2)["statuses"] == {"tangled": 2},
		"AC3: occupant after shove (Warden) receives Tangled 2")
	_check(p3.get_hero(1)["id"] == "seamstress" and p3.get_hero(1).get("statuses", {}).is_empty(),
		"AC3: original slot 2 occupant (Seamstress) receives no debuff")

	# 3. Dead source no-op
	p3 = _party()
	e3 = _enemies()
	_check(e3.apply_damage(1, 12) and e3.is_slain(1), "AC3 precondition: enemy 1 slain")
	var snap_dead := _snapshot(p3, e3)
	var res_dead := rules.execute_actions(p3, e3, [_debuff(1, 2, "tangled", 1)])
	_check(res_dead == {"ok": true, "events": [
		_event("debuff", 1, false, 2, 0, "tangled")]},
		"AC3: dead enemy source produces applied=false event for Tangled")
	_check(_snapshot(p3, e3) == snap_dead,
		"AC3: dead source leaves party and enemies unchanged")

	# 4. Atomic rejections and fail-closed validation
	_reject("AC3: malformed status name tangle", [_debuff(1, 2, "tangle", 1)])
	_reject("AC3: malformed status name tangled_hero", [_debuff(1, 2, "tangled_hero", 1)])
	_reject("AC3: zero amount Tangled", [_debuff(1, 2, "tangled", 0)])
	_reject("AC3: negative amount Tangled", [_debuff(1, 2, "tangled", -1)])
	_reject("AC3: float amount Tangled",
		[{"type": "debuff", "enemy_position": 1, "amount": 1.5, "status": "tangled", "target_position": 2}])
	_reject("AC3: string amount Tangled",
		[{"type": "debuff", "enemy_position": 1, "amount": "1", "status": "tangled", "target_position": 2}])
	_reject("AC3: bool amount Tangled",
		[{"type": "debuff", "enemy_position": 1, "amount": true, "status": "tangled", "target_position": 2}])
	_reject("AC3: invalid target position 0 Tangled", [_debuff(1, 0, "tangled", 1)])
	_reject("AC3: invalid target position 4 Tangled", [_debuff(1, 4, "tangled", 1)])
	_reject("AC3: float target position Tangled",
		[{"type": "debuff", "enemy_position": 1, "amount": 1, "status": "tangled", "target_position": 2.0}])

	# Downed hero
	p3 = _party()
	e3 = _enemies()
	_check(p3.apply_damage(2, 30) and p3.is_downed(2), "AC3 precondition: hero 2 downed")
	_reject("AC3: Tangled debuff targeting downed hero rejects atomically",
		[_debuff(1, 2, "tangled", 1)], p3, e3)

	# Arithmetic overflow
	p3 = _party()
	e3 = _enemies()
	p3._heroes[1]["statuses"] = {"tangled": MAX_INT}
	_reject("AC3: Tangled overflow past MAX_INT rejects atomically",
		[_debuff(1, 2, "tangled", 1)], p3, e3)

	# Late-invalid Tangled action after valid staged action rolls back atomically
	p3 = _party()
	e3 = _enemies()
	_reject("AC3: late malformed status name rolls back valid shove",
		[_shove(1, 1, 1), _debuff(2, 2, "tangle", 1)], p3, e3)
	p3 = _party()
	e3 = _enemies()
	_reject("AC3: late zero amount Tangled rolls back valid buff",
		[_buff(1, 1), _debuff(2, 2, "tangled", 0)], p3, e3)
	p3 = _party()
	e3 = _enemies()
	_reject("AC3: late negative amount Tangled rolls back valid Tangled debuff",
		[_debuff(1, 2, "tangled", 1), _debuff(2, 2, "tangled", -1)], p3, e3)
	p3 = _party()
	e3 = _enemies()
	_reject("AC3: late invalid target Tangled rolls back valid shove",
		[_shove(1, 1, 1), _debuff(2, 4, "tangled", 1)], p3, e3)
	p3 = _party()
	e3 = _enemies()
	p3._heroes[1]["statuses"] = {"tangled": MAX_INT}
	_reject("AC3: late Tangled overflow rolls back valid buff",
		[_buff(1, 1), _debuff(2, 2, "tangled", 1)], p3, e3)


func _test_inkbrush_blind_transaction() -> void:
	var catalog := RunTypedBattleRoster._parse_catalog_text(
		FileAccess.get_file_as_string("res://data/enemies/run_enemies.json"))
	var imp: Dictionary = {}
	for record in catalog:
		if record.get("id") == "inkbrush_imp":
			imp = record
	_check(not imp.is_empty() and imp.get("max_hp") == 23,
		"real living Imp source and HP exist in authored catalog")
	if imp.is_empty():
		return
	var party := _party()
	var enemies := CombatEnemies.new([imp])
	var blind := _debuff(1, 3, "blind_next_attack", 1)
	var before_foes := enemies.get_enemies()
	var before_heroes := party.get_heroes()
	var result := rules.execute_actions(party, enemies, [blind])
	_check(result.get("ok") == true and result.events.size() == 1
		and result.events[0].applied == true
		and party.get_hero(3).get("statuses", {}).get("blind_next_attack") == 1
		and party.get_hero(3).hp == before_heroes[2].hp
		and enemies.get_enemies() == before_foes,
		"living authored Imp commits exactly one Blind to actual back hero without damage")
	_check(rules.execute_actions(party, enemies, [blind]).get("ok") == true
		and party.get_hero(3).statuses.get("blind_next_attack") == 1,
		"second Blind re-arms at 1, never stacks to 2")
	for bad_amount in [0, 2, -1]:
		var bad := _debuff(1, 3, "blind_next_attack", bad_amount)
		var saved := _snapshot(party, enemies)
		_check(not rules.execute_actions(party, enemies, [bad]).ok
			and _snapshot(party, enemies) == saved,
			"invalid Blind amount rejects atomically without spend")
	var snapshot := _snapshot(party, enemies)
	_check(not rules.execute_actions(party, enemies,
		[_buff(1, 1), _debuff(1, 3, "blind_next_attack", 1)]).ok
		and _snapshot(party, enemies) == snapshot,
		"duplicate-source batch rejects and rolls back")
	_check(enemies.apply_damage(1, 23) and enemies.is_slain(1),
		"source really downed for inert action witness")
	var saved := _snapshot(party, enemies)
	var dead := rules.execute_actions(party, enemies, [blind])
	_check(dead.ok and dead.events.size() == 1 and not dead.events[0].applied
		and _snapshot(party, enemies) == saved,
		"dead Imp cannot re-arm Blind")
	party = _party()
	enemies = CombatEnemies.new([imp])
	_check(party.apply_damage(3, 26) and party.is_downed(3),
		"target really downed for fail-closed witness")
	saved = _snapshot(party, enemies)
	_check(not rules.execute_actions(party, enemies, [blind]).ok
		and _snapshot(party, enemies) == saved,
		"living Imp cannot Blind a downed hero")


func _test_stitched_blind_guard() -> void:
	var party := _party()
	var cards := StarterCards.new()
	var strike := cards.get_definition("warden_strike")
	var brace := cards.get_definition("warden_brace")
	_check(not strike.is_empty() and not brace.is_empty()
		and strike.effects.get("damage") == 6 and brace.effects.get("block") == 7,
		"real authored damage and support halves are available for stitched gate")
	_check(not CombatHeroBlindMiss.blocks_stitched(party, strike, brace),
		"unblinded stitched half is not rejected by the Blind gate")
	party._heroes[0]["statuses"] = {"blind_next_attack": 1}
	_check(CombatHeroBlindMiss.blocks_stitched(party, strike, brace)
		and CombatHeroBlindMiss.blocks_stitched(party, brace, strike),
		"blinded attack in either ordered stitched half is rejected before payment")
	_check(not CombatHeroBlindMiss.blocks_stitched(party, brace, brace),
		"nonattack-only stitched combination stays usable while Blind waits")
	party._heroes[0]["statuses"].erase("blind_next_attack")
	_check(not CombatHeroBlindMiss.blocks_stitched(party, strike, brace),
		"once consumed Blind no longer blocks genuine stitched attacks")


func _test_blind_ricochet_paid_miss() -> void:
	var catalog := TinkerPoolCards.new()
	var service := CombatHeroBlindMiss.new()
	for entry in CombatHeroBlindMiss.RICOCHET_IDS:
		var card_id: String = entry
		var definition := catalog.get_definition(card_id)
		var effects: Dictionary = definition.get("effects", {})
		var printed_damage := 4 if card_id == "tinker_ricochet" else 6
		_check(definition.get("id") == card_id and definition.get("owner") == "tinker"
			and definition.get("cost") == 1 and definition.get("from_positions") == [2, 3]
			and definition.get("to_positions") == [1, 2, 3]
			and definition.get("target_kind") == "enemy_random"
			and effects.get("damage") == printed_damage and effects.get("hit_count") == 3
			and effects.get("random_target_each_hit") == true
			and effects.get("rng_source") == "run"
			and effects.get("living_targets_only") == true,
			"precondition: genuine authored " + card_id + " is three 1-cost random hits")

		# --- AC1: the whole card misses once, before any random targeting ---
		var party := _armed_party()
		var enemies := _enemies()
		var deck := _ricochet_deck(card_id)
		var heroes_before := party.get_heroes()
		var foes_before := enemies.get_enemies()
		var hand_size_before: int = deck.hand.size()
		var rng_before: int = deck._rng.state
		var rng_seed_before: int = deck._rng.seed
		var result := service.attempt(deck, party, enemies, card_id, 0, definition)
		var expected := {"handled": true, "ok": true, "miss": true, "card_id": card_id,
			"owner_position": 3, "target_position": 0, "cost": 1, "hits": [],
			"damage": 0, "hp_loss": 0, "block_absorbed": 0, "reason": "blind_miss"}
		_check(result == expected,
			"AC1: blinded " + card_id + " returns exactly the zero-hit miss receipt")
		_check(deck.energy == 2 and deck.combat_state.energy == 2
			and deck.hand.size() == hand_size_before - 1
			and deck.hand.count(card_id) == 1 and deck.discard_pile == [card_id],
			"AC1: one printed energy and exactly one held copy move on " + card_id)
		_check(not party.get_hero(3).get("statuses", {}).has("blind_next_attack")
			and party.get_hero(3).hp == heroes_before[2].hp,
			"AC1: the Tinker keeps every HP and loses only the one-shot Blind token")
		var heroes_after := party.get_heroes()
		var actors_intact: bool = heroes_after[0] == heroes_before[0] \
			and heroes_after[1] == heroes_before[1] \
			and heroes_after[2]["hp"] == heroes_before[2]["hp"] \
			and heroes_after[2]["block"] == heroes_before[2]["block"]
		_check(actors_intact and enemies.get_enemies() == foes_before
			and deck._rng.state == rng_before and deck._rng.seed == rng_seed_before,
			"AC1: all three random hits are absent, so no foe, ally or run draw changes")
		var replay_party := _armed_party()
		var replay_enemies := _enemies()
		var replay_deck := _ricochet_deck(card_id)
		var replay := service.attempt(replay_deck, replay_party, replay_enemies, card_id, 0,
			catalog.get_definition(card_id))
		_check(replay == result and _blind_state(replay_deck, replay_party, replay_enemies)
			== _blind_state(deck, party, enemies),
			"AC1: an independent same-seed cast repeats " + card_id + " receipt and post-state")

		# --- AC2: only the one attempted card is swallowed ---
		var spent_state := _blind_state(deck, party, enemies)
		var second := service.attempt(deck, party, enemies, card_id, 0, definition)
		_check(second == {"handled": false, "ok": false}
			and _blind_state(deck, party, enemies) == spent_state,
			"AC2: a spent Blind leaves the second " + card_id + " unpaid and untouched")
		var ordinary := CombatTinkerPoolAttacks.new().play_attack(
			deck, party, enemies, card_id, 0)
		_check(ordinary.get("ok") == true and ordinary.get("hits", []).size() == 3
			and deck.energy == 1 and deck.discard_pile == [card_id, card_id],
			"AC2: that second " + card_id + " still resolves its ordinary three random hits")
		var clean_party := _party()
		var clean_enemies := _enemies()
		var clean_deck := _ricochet_deck(card_id)
		var clean_state := _blind_state(clean_deck, clean_party, clean_enemies)
		_check(service.attempt(clean_deck, clean_party, clean_enemies, card_id, 0, definition)
			== {"handled": false, "ok": false}
			and _blind_state(clean_deck, clean_party, clean_enemies) == clean_state,
			"AC2: without Blind " + card_id + " is neither handled nor charged")
		clean_party._heroes[2]["statuses"] = {"blind_next_attack": 0}
		var inert_state := _blind_state(clean_deck, clean_party, clean_enemies)
		_check(service.attempt(clean_deck, clean_party, clean_enemies, card_id, 0, definition)
			== {"handled": false, "ok": false}
			and _blind_state(clean_deck, clean_party, clean_enemies) == inert_state,
			"AC2: an inert 0 token never starts a " + card_id + " miss")

		# --- AC3: narrow, fail-closed admission ---
		for target in [1, 2, 3, -1, 4]:
			var target_party := _armed_party()
			var target_enemies := _enemies()
			var target_deck := _ricochet_deck(card_id)
			var wrong_target := _blind_reject(service, target_deck, target_party,
				target_enemies, card_id, target, definition, 0,
				"AC3: preselected Ricochet target %d" % target)
			_check(wrong_target.get("handled") == true,
				"AC3: only target 0 is legal for " + card_id)
		var dead_party := _armed_party()
		var dead_enemies := _enemies()
		var dead_deck := _ricochet_deck(card_id)
		_check(dead_enemies.apply_damage(1, 99) and dead_enemies.apply_damage(2, 99)
			and dead_enemies.apply_damage(3, 99) and dead_enemies.is_victorious(),
			"precondition: every authored TO foe is dead")
		_blind_reject(service, dead_deck, dead_party, dead_enemies, card_id, 0,
			definition, 0, "AC3: no living TO foe")
		for discount in [2, -1, 99]:
			var discount_party := _armed_party()
			var discount_enemies := _enemies()
			var discount_deck := _ricochet_deck(card_id)
			_blind_reject(service, discount_deck, discount_party, discount_enemies,
				card_id, 0, definition, discount,
				"AC3: unprinted discount %d" % discount)
		var poor_party := _armed_party()
		var poor_enemies := _enemies()
		var poor_deck := _ricochet_deck(card_id)
		poor_deck.combat_state.energy = 0
		_check(poor_deck.energy == 0, "precondition: no energy for the one-shot miss")
		_blind_reject(service, poor_deck, poor_party, poor_enemies, card_id, 0,
			definition, 0, "AC3: unavailable energy")
		var unheld_party := _armed_party()
		var unheld_enemies := _enemies()
		var unheld_deck := _ricochet_deck(card_id)
		unheld_deck.hand.assign(["tinker_spare_parts"])
		_check(not unheld_deck.hand.has(card_id),
			"precondition: no " + card_id + " is really held")
		var unheld := _blind_reject(service, unheld_deck, unheld_party, unheld_enemies,
			card_id, 0, definition, 0, "AC3: unheld " + card_id)
		_check(unheld.get("handled") == true,
			"AC3: an unheld " + card_id + " is a refused attempt, not a miss")
		var forged_effects: Dictionary = definition["effects"].duplicate(true)
		forged_effects["damage"] = 400
		var inflated := definition.duplicate(true)
		inflated["effects"] = forged_effects.duplicate(true)
		var free := definition.duplicate(true)
		free["cost"] = 0
		var widened := definition.duplicate(true)
		widened["to_positions"] = [1, 2, 3, 4]
		var two_hits_effects: Dictionary = definition["effects"].duplicate(true)
		two_hits_effects["hit_count"] = 2
		var two_hits := definition.duplicate(true)
		two_hits["effects"] = two_hits_effects
		var turn_rng_effects: Dictionary = definition["effects"].duplicate(true)
		turn_rng_effects["rng_source"] = "turn"
		var turn_rng := definition.duplicate(true)
		turn_rng["effects"] = turn_rng_effects
		for forged in [inflated, free, widened, two_hits, turn_rng]:
			var forged_party := _armed_party()
			var forged_enemies := _enemies()
			var forged_deck := _ricochet_deck(card_id)
			var forged_result := _blind_reject(service, forged_deck, forged_party,
				forged_enemies, card_id, 0, forged, 0,
				"AC3: forged " + card_id + " pool descriptor")
			_check(forged_result == {"handled": false, "ok": false},
				"AC3: an unauthentic random descriptor is not an attack at all")
		var seat_party := _party()
		seat_party._heroes[0]["id"] = "tinker"
		seat_party._heroes[2]["id"] = "warden"
		seat_party._heroes[0]["statuses"] = {"blind_next_attack": 1}
		var seat_enemies := _enemies()
		var seat_deck := _ricochet_deck(card_id)
		_check(seat_party.get_hero(1).get("id") == "tinker"
			and seat_party.get_hero(3).get("id") == "warden"
			and seat_party.get_hero(1).get("statuses", {}).get("blind_next_attack") == 1,
			"precondition: the real Tinker sits in the front seat outside FROM [2,3]")
		_blind_reject(service, seat_deck, seat_party, seat_enemies, card_id, 0,
			definition, 0, "AC3: illegal Tinker seat")
		var downed_party := _armed_party()
		_check(downed_party.apply_damage(3, 26) and downed_party.is_downed(3),
			"precondition: the Blinded Tinker is really downed")
		var downed_enemies := _enemies()
		var downed_deck := _ricochet_deck(card_id)
		_blind_reject(service, downed_deck, downed_party, downed_enemies, card_id, 0,
			definition, 0, "AC3: downed Tinker")
		for bad_blind in [{"blind_next_attack": 2}, {"blind_next_attack": -1},
				{"blind_next_attack": true}, {"bogus_status": 1}]:
			var shape_party := _party()
			shape_party._heroes[2]["statuses"] = bad_blind.duplicate(true)
			var shape_enemies := _enemies()
			var shape_deck := _ricochet_deck(card_id)
			_blind_reject(service, shape_deck, shape_party, shape_enemies, card_id, 0,
				definition, 0, "AC3: malformed Blind status")
		var array_party := _party()
		array_party._heroes[2]["statuses"] = ["blind_next_attack"]
		var array_enemies := _enemies()
		var array_deck := _ricochet_deck(card_id)
		_blind_reject(service, array_deck, array_party, array_enemies, card_id, 0,
			definition, 0, "AC3: non-dictionary Blind statuses")

	# --- AC3/AC4: neighbouring card shapes keep their existing contracts ---
	var support := catalog.get_definition("tinker_spare_parts")
	var support_party := _armed_party()
	var support_enemies := _enemies()
	var support_deck := _test_deck(["tinker_spare_parts", "tinker_spare_parts"], 49218)
	support_deck.hand.assign(["tinker_spare_parts"])
	var support_result := _blind_reject(service, support_deck, support_party,
		support_enemies, "tinker_spare_parts", 0, support, 0,
		"AC3: nonattack Tinker card")
	_check(support_result == {"handled": false, "ok": false},
		"AC3: a nonattack card never reads or spends Blind")
	var rivet := catalog.get_definition("tinker_rivet_shot")
	_check(rivet.get("target_kind") == "enemy_single"
		and rivet.get("effects", {}).get("damage") == 4,
		"precondition: genuine single-target Tinker attack")
	var unprinted_party := _armed_party()
	var unprinted_enemies := _enemies()
	var unprinted_deck := _test_deck(["tinker_rivet_shot", "tinker_rivet_shot"], 49219)
	unprinted_deck.hand.assign(["tinker_rivet_shot"])
	var unprinted := _blind_reject(service, unprinted_deck, unprinted_party,
		unprinted_enemies, "tinker_rivet_shot", 4, rivet, 0,
		"AC3: unprinted single target")
	_check(unprinted.get("handled") == true,
		"AC3: existing single-target legality still fails closed")
	var single_party := _armed_party()
	var single_enemies := _enemies()
	var single_deck := _test_deck(["tinker_rivet_shot", "tinker_rivet_shot"], 49219)
	single_deck.hand.assign(["tinker_rivet_shot"])
	var single := service.attempt(single_deck, single_party, single_enemies,
		"tinker_rivet_shot", 1, rivet)
	_check(single.get("ok") == true and single.get("miss") == true
		and single.get("hits") == [] and single_deck.energy == 2
		and single_deck.discard_pile == ["tinker_rivet_shot"]
		and not single_party.get_hero(3).get("statuses", {}).has("blind_next_attack"),
		"AC3: existing single-target Blind miss is unchanged")
	var scatter := catalog.get_definition("tinker_scatter_bolts")
	_check(scatter.get("target_kind") == "enemy_all",
		"precondition: genuine area Tinker attack")
	var scatter_party := _armed_party()
	var scatter_enemies := _enemies()
	var scatter_deck := _test_deck(["tinker_scatter_bolts"], 49220)
	scatter_deck.hand.assign(["tinker_scatter_bolts"])
	var scatter_target := _blind_reject(service, scatter_deck, scatter_party,
		scatter_enemies, "tinker_scatter_bolts", 1, scatter, 0,
		"AC3: preselected area target")
	_check(scatter_target.get("handled") == true,
		"AC3: existing area-target legality still fails closed")
	var area_party := _armed_party()
	var area_enemies := _enemies()
	var area_deck := _test_deck(["tinker_scatter_bolts"], 49221)
	area_deck.hand.assign(["tinker_scatter_bolts"])
	var area := service.attempt(area_deck, area_party, area_enemies,
		"tinker_scatter_bolts", 0, scatter)
	_check(area.get("ok") == true and area.get("miss") == true
		and area.get("hits") == [] and area_deck.energy == 2
		and area_deck.discard_pile == ["tinker_scatter_bolts"],
		"AC3: existing all-target Blind miss still pays exactly once")
