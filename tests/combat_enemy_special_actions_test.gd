extends SceneTree

var failures: Array[String] = []
var checks := 0
var rules := CombatEnemySpecialActions.new()

const HERO_PATH := "res://data/heroes/starter_party.json"
const MAX_INT := 9223372036854775807


func _initialize() -> void:
	_test_ordered_transaction()
	_test_bidirectional_swaps()
	_test_status_additions_and_owner_turns()
	_test_dead_sources_and_rejections()
	_test_replay_and_detached_results()
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
		_buff(1, 1), _debuff(1, 1, "weak", 1)]
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
