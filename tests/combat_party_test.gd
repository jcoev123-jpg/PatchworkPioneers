extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_construction()
	_test_damage_and_turns()
	_test_healing_and_defeat()
	_test_rejections()
	if failures.is_empty():
		print("combat_party_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("combat_party_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _definitions() -> Array:
	# GAME_DESIGN.md starting heroes; balance stays out of CombatParty.
	return [{"id": "warden", "max_hp": 40, "metadata": {"tags": ["front"]}},
		{"id": "seamstress", "max_hp": 30}, {"id": "tinker", "max_hp": 26}]


func _test_construction() -> void:
	var definitions := _definitions()
	var party := CombatParty.new(definitions)
	_check(party.is_valid(), "three valid definitions construct a party")
	_check(party.get_heroes().size() == 3, "party has three actual heroes")
	var ids := ["warden", "seamstress", "tinker"]
	var hp := [40, 30, 26]
	for position in range(1, 4):
		var hero := party.get_hero(position)
		_check(hero.get("id") == ids[position - 1], "starting stable ID")
		_check(hero.get("position") == position, "fixed 1-based starting position")
		_check(hero.get("max_hp") == hp[position - 1] and hero.get("hp") == hp[position - 1], "starting full HP")
		_check(hero.get("block") == 0 and not party.is_downed(position), "starts living without Block")
	_check(not party.is_defeated(), "living party is not defeated")
	var before := party.get_heroes()
	definitions[0]["metadata"]["tags"].append("changed")
	definitions[0]["max_hp"] = 1
	definitions.clear()
	_check(party.get_heroes() == before, "constructor deeply copies definitions")
	var hero := party.get_hero(1)
	hero["hp"] = 0
	hero["position"] = 3
	hero["metadata"]["tags"].clear()
	var heroes := party.get_heroes()
	heroes[1]["id"] = "changed"
	heroes[0]["metadata"]["tags"].clear()
	heroes.clear()
	_check(party.get_heroes() == before, "all readers return defensive deep copies")
	var custom := CombatParty.new([{"id": "a", "max_hp": 7}, {"id": "b", "max_hp": 8}, {"id": "c", "max_hp": 9}])
	_check(custom.get_hero(1).get("hp") == 7 and custom.get_hero(3).get("hp") == 9, "injected stats replace starter values")
	var invalid_sets: Array = [[], [{"id": "a", "max_hp": 1}],
		_definitions() + [{"id": "extra", "max_hp": 1}]]
	for bad in [{"id": "", "max_hp": 1}, {"id": "warden", "max_hp": 1},
		{"id": "bad", "max_hp": 0}, {"id": "bad", "max_hp": -1},
		{"id": "bad", "max_hp": 1.5}, {"id": 12, "max_hp": 1}, {}, null]:
		var invalid := _definitions()
		invalid[2] = bad
		invalid_sets.append(invalid)
	for definitions_bad in invalid_sets:
		var invalid := CombatParty.new(definitions_bad)
		_check(not invalid.is_valid() and invalid.get_heroes().is_empty(), "invalid definitions rejected atomically")
		_check(not invalid.apply_damage(1, 1) and not invalid.gain_block(1, 1)
			and not invalid.heal(1, 1) and not invalid.start_player_turn(), "invalid party is inert")
		_check(not invalid.is_defeated() and not invalid.is_downed(1), "empty invalid state is not vacuous defeat")


func _test_damage_and_turns() -> void:
	var party := CombatParty.new(_definitions())
	_check(party.gain_block(1, 7) and party.gain_block(1, 3), "Block accumulates")
	_check(party.gain_block(2, 5) and party.gain_block(3, 2), "each hero gains individual Block")
	var allies := [party.get_hero(2), party.get_hero(3)]
	_check(party.apply_damage(1, 6), "partially blocked hit succeeds")
	_check(party.get_hero(1).get("block") == 4 and party.get_hero(1).get("hp") == 40, "Block absorbs before HP")
	_check(party.apply_damage(1, 4), "exactly blocked hit succeeds")
	_check(party.get_hero(1).get("block") == 0 and party.get_hero(1).get("hp") == 40, "exact absorption preserves HP")
	_check(party.gain_block(1, 3) and party.apply_damage(1, 8), "overflow hit succeeds")
	_check(party.get_hero(1).get("block") == 0 and party.get_hero(1).get("hp") == 35, "only overflow reduces HP")
	_check([party.get_hero(2), party.get_hero(3)] == allies, "damage leaves allies and their Block unchanged")
	_check(party.gain_block(1, 9), "Block persists until turn boundary")
	var before := party.get_heroes()
	_check(party.start_player_turn(), "player turn starts")
	for position in range(1, 4):
		var expected: Dictionary = before[position - 1].duplicate(true)
		expected["block"] = 0
		_check(party.get_hero(position) == expected, "turn start clears only Block for every hero")
	var cleared := party.get_heroes()
	_check(party.start_player_turn() and party.get_heroes() == cleared, "repeated reset is idempotent")
	_check(party.gain_block(2, 6) and party.get_hero(2).get("block") == 6, "new turn Block remains until next start")


func _test_healing_and_defeat() -> void:
	var party := CombatParty.new(_definitions())
	_check(party.apply_damage(2, 12) and party.gain_block(2, 5), "wound and protect Seamstress")
	_check(party.heal(2, 4) and party.get_hero(2).get("hp") == 22, "healing restores exact HP")
	_check(party.heal(2, CombatParty.MAX_INT), "large heal succeeds without overflow")
	_check(party.get_hero(2).get("hp") == 30 and party.get_hero(2).get("block") == 5, "healing caps at max and preserves Block")
	_check(party.apply_damage(1, 40) and party.is_downed(1), "exact lethal damage downs Warden")
	_check(not party.is_defeated(), "one down is not defeat")
	_check(party.apply_damage(2, 1000) and party.get_hero(2).get("hp") == 0, "overkill clamps HP at zero")
	_check(party.is_downed(2) and not party.is_defeated(), "two down is not defeat")
	_check(party.apply_damage(3, CombatParty.MAX_INT), "large lethal hit succeeds")
	_check(party.is_defeated(), "defeat begins exactly at third down")
	for position in range(1, 4):
		_check(party.is_downed(position) and party.get_hero(position).get("position") == position, "downed heroes keep their positions")
		for amount in [0, 1, 100]:
			_reject(party, "apply_damage", position, amount)
			_reject(party, "gain_block", position, amount)
			_reject(party, "heal", position, amount)
	var before := party.get_heroes()
	_check(party.start_player_turn() and party.get_heroes() == before and party.is_defeated(), "turn reset never revives heroes")


func _reject(party: CombatParty, method: String, position: int, amount: int) -> void:
	var before := party.get_heroes()
	_check(party.call(method, position, amount) == false, method + " rejects invalid target/amount")
	_check(party.get_heroes() == before, method + " rejection leaves the entire party unchanged")


func _test_rejections() -> void:
	var party := CombatParty.new(_definitions())
	_check(party.apply_damage(1, 5) and party.gain_block(2, 7), "negative tests use wounded/protected state")
	for method in ["apply_damage", "gain_block", "heal"]:
		for position in [-100, -1, 0, 4, 100]:
			_reject(party, method, position, 3)
			_check(party.get_hero(position).is_empty() and not party.is_downed(position), "invalid state reads are safe")
		for position in range(1, 4):
			_reject(party, method, position, -1)
			var before := party.get_heroes()
			_check(party.call(method, position, 0) == true and party.get_heroes() == before, "zero on living hero succeeds without mutation")
	_check(party.gain_block(3, CombatParty.MAX_INT), "maximum representable Block succeeds")
	_reject(party, "gain_block", 3, 1)
