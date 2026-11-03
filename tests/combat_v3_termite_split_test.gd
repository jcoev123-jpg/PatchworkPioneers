extends SceneTree

## A detached, explicit post-lethal Quilt Termite split model contract.

## Live paid-card damage reaches it only through App._settle_pending_termite_split;



const CATALOG := "res://data/enemies/run_enemies.json"



var failures: Array[String] = []

var checks := 0





func _initialize() -> void:

	_test_authority()

	_test_once_only_and_victory()

	_test_scaled_and_detached()

	_test_inert_cases()

	_test_rejections()

	_test_no_implicit_wiring()

	if failures.is_empty():

		print("combat_v3_termite_split_test: PASS (", checks, " checks)")

	else:

		for failure in failures:

			printerr(failure)

		print("combat_v3_termite_split_test: FAIL (", failures.size(), " failures)")

	quit(0 if failures.is_empty() else 1)





func _check(condition: bool, message: String) -> void:

	checks += 1

	if not condition:

		failures.append(message)





func _termite() -> Dictionary:

	var records := RunTypedBattleRoster._parse_catalog_text(

		FileAccess.get_file_as_string(CATALOG))

	for record in records:

		if record.get("id") == CombatEnemies.TERMITE_ID:

			return record.duplicate(true)

	return {}





func _other(id: String = "passive") -> Dictionary:

	return {"id": id, "name": id, "max_hp": 12,

		"intent": {"target": "front", "actions": [

			{"type": "attack", "amount": 5, "weight": 1}]}}





func _fight(others: int = 0) -> CombatEnemies:

	var source := _termite()

	var records: Array = [source]

	for i in range(others):

		records.append(_other("ordinary_%d" % i))

	return CombatEnemies.new(records)





func _test_authority() -> void:

	var source := _termite()

	_check(not source.is_empty() and source.get("max_hp") == 26

		and source.get("split_on_death") is bool and source.get("split_on_death") == true,

		"precondition: strict typed loader returns the authentic 26 HP Termite split record")

	if source.is_empty():

		return

	_check(source.get("intent", {}).get("target") == "front"

		and source.get("intent", {}).get("actions", []).size() == 5

		and source.intent.actions[0].type == "attack"

		and source.intent.actions[0].amount == 6

		and source.intent.actions[0].weight == 4,

		"precondition: the genuine front-facing weighted six-damage attack exists")

	var material := RunAuthoredBattleEntry._floor_band_material(null)

	_check(material.get("ok", false) and material.get("records", {}).has(CombatEnemies.TERMITE_ID)

		and material.records[CombatEnemies.TERMITE_ID] == source,

		"precondition: the same Termite record reaches the normal Fight catalog")

	var parsed := RunTypedBattleRoster._parse_catalog_text(

		FileAccess.get_file_as_string(CATALOG))

	for record in parsed:

		if record.get("id") != CombatEnemies.TERMITE_ID:

			_check(not record.has("split_on_death"),

				"AC1: no unrelated normal authors split_on_death: " + str(record.get("id")))





func _assert_halves(actors: Array, first_position: int, second_position: int,

		maximum: int, bite: int) -> void:

	_check(actors.size() == second_position,

		"AC2: two clean records occupy the replacement and appended slots")

	if actors.size() != second_position:

		return

	var first: Dictionary = actors[first_position - 1]

	var second: Dictionary = actors[second_position - 1]

	_check(first.id == CombatEnemies.HALF_LEFT_ID

		and second.id == CombatEnemies.HALF_RIGHT_ID and first.id != second.id,

		"AC2: both half-Termite identities are stable and distinct")

	for position in [first_position, second_position]:

		var child: Dictionary = actors[position - 1]

		_check(child.get("hp") == maximum and child.get("max_hp") == maximum

			and child.get("block") == 0 and child.get("position") == position

			and child.get("enemy_position") == position,

			"AC2: each half has full half HP, zero Block and legal indexed positions")

		_check(not child.has("statuses") and not child.has("split_on_death")

			and not child.has("chew_block_on_attack") and not child.has("revive_once"),

			"AC2: no child inherits status, special damage flags or further splitting")

		_check(child.get("intent") == {"target": "front", "actions": [

			{"type": "attack", "amount": bite, "weight": 1}]}

			and not CombatEnemyIntents._weighted_slot(position, child.get("intent")).is_empty(),

			"AC2: each half has a single legal, authored front attack at half strength")





func _test_once_only_and_victory() -> void:

	var source := _termite()

	source["statuses"] = {"bleed": 3, "weak": 1}

	var enemies := CombatEnemies.new([_other(), source])

	_check(enemies.is_valid() and enemies.get_enemy(2).hp == 26,

		"precondition: a real two-enemy roster has a living 26 HP Termite in slot 2")

	var original := enemies.get_enemy(1)

	_check(enemies.gain_block(2, 5) and enemies.apply_damage(2, 31)

		and enemies.is_slain(2), "precondition: lethal attack defeats the Blocked Termite")

	_check(enemies.get_enemies().size() == 2,

		"AC2: lethal damage alone does not implicitly split the Termite")

	var pre_stage := enemies.get_enemies()

	var result := enemies.stage_split_on_death(2)

	_check(result == {"ok": true, "split": true, "positions": [2, 3]},

		"AC2: explicit post-lethal staging publishes one atomic replacement plus append")

	var actors := enemies.get_enemies()

	_assert_halves(actors, 2, 3, 13, 3)

	_check(actors[0] == original and pre_stage[0] == actors[0],

		"AC2: the unrelated enemy survives staging byte-for-byte")

	var after := enemies.get_enemies()

	_check(enemies.stage_split_on_death(2) == {"ok": false, "split": false}

		and enemies.stage_split_on_death(3) == {"ok": false, "split": false}

		and enemies.get_enemies() == after,

		"AC3: either repeated half-stage is fail-closed and cannot create grandchildren")

	_check(enemies.apply_damage(1, 12) and not enemies.is_victorious(),

		"AC2: killing the unrelated foe cannot claim victory while both halves live")

	_check(enemies.apply_damage(2, 13) and enemies.is_slain(2)

		and not enemies.is_defeated(), "AC2: killing the first half still prevents victory")

	_check(enemies.apply_damage(3, 13) and enemies.is_slain(3)

		and enemies.is_defeated() and enemies.is_victorious(),

		"AC2: both halves must die for a legitimate CombatEnemies victory")





func _test_scaled_and_detached() -> void:
	for tier in [1, 2]:
		var difficulty := RunDifficulty.new()
		difficulty._selected_tier = tier
		var scaled: Array = difficulty.scale_definitions([_termite()])
		_check(scaled.size() == 1 and scaled[0].get("max_hp") == (29 if tier == 1 else 32)
			and scaled[0].get("intent", {}).get("actions", [])[0].get("amount")
				== (7 if tier == 1 else 8),
			"precondition: real tier %d scaling supplies its own HP and attack bonus" % tier)
		var source: Dictionary = scaled[0]
		source["statuses"] = {"exposed": 4}
		var copy := source.duplicate(true)
		var enemies := CombatEnemies.new([source])
		var rng := RandomNumberGenerator.new()
		rng.seed = 887163
		var before_state := rng.state
		_check(enemies.is_valid() and enemies.apply_damage(1, source.max_hp)
			and enemies.is_slain(1),
			"precondition: tier %d scaled parent reaches actual zero HP" % tier)
		var result := enemies.stage_split_on_death(1)
		_check(result == {"ok": true, "split": true, "positions": [1, 2]},
			"AC2: tier %d already-scaled Termite splits in one explicit operation" % tier)
		var expected_hp := 15 if tier == 1 else 16
		var expected_attack := 4
		_assert_halves(enemies.get_enemies(), 1, 2, expected_hp, expected_attack)
		_check(source == copy and rng.state == before_state,
			"AC2: tier %d split never changes its definition or draws RNG" % tier)
		var detached := enemies.get_enemies()
		detached[0].hp = 0
		detached[1].intent.actions[0].amount = 99
		_check(enemies.get_enemy(1).hp == expected_hp
			and enemies.get_enemy(2).intent.actions[0].amount == expected_attack,
			"AC2: tier %d child snapshots cannot back-mutate the roster" % tier)


func _test_inert_cases() -> void:

	var living := _fight(1)

	_check(living.is_valid() and living.get_enemy(1).hp == 26,

		"precondition: one live Termite plus a distinct normal occupies two slots")

	var snapshot := living.get_enemies()

	_check(living.stage_split_on_death(1) == {"ok": true, "split": false}

		and living.get_enemies() == snapshot,

		"AC3: nonlethal staging succeeds inert without consuming the death")

	_check(living.apply_damage(1, 25) and living.get_enemy(1).hp == 1,

		"precondition: positive nonlethal residual HP is real")

	snapshot = living.get_enemies()

	_check(living.stage_split_on_death(1) == {"ok": true, "split": false}

		and living.get_enemies() == snapshot,

		"AC3: one-HP source remains inert")

	var full := _fight(2)

	_check(full.is_valid() and full.get_enemies().size() == CombatEnemies.MAX_ENEMIES,

		"precondition: full roster occupies all three genuine slots")

	_check(full.apply_damage(1, 26) and full.apply_damage(2, 12)

		and full.apply_damage(3, 12) and full.is_defeated(),

		"precondition: all actors really die including the Termite in full capacity")

	snapshot = full.get_enemies()

	_check(full.stage_split_on_death(1) == {"ok": true, "split": false}

		and full.get_enemies() == snapshot and full.is_victorious(),

		"AC3: full-cap legitimate kill stays dead and does not spawn a fourth actor")





func _reject_with_no_change(actor: Dictionary, explanation: String) -> void:

	var enemies := CombatEnemies.new([actor, _other()])

	if not enemies.is_valid():

		_check(true, "precondition: malformed authored flag rejected at construction: " + explanation)

		return

	_check(enemies.apply_damage(1, 1000),

		"precondition: malformed parent setup reaches post-lethal staging: " + explanation)

	var snapshot := enemies.get_enemies()

	_check(enemies.stage_split_on_death(1) == {"ok": false, "split": false}

		and enemies.get_enemies() == snapshot,

		"AC3: malformed parent refuses staging atomically: " + explanation)





func _test_rejections() -> void:

	for bad in ["true", 1, 1.0, null, [], {}]:

		var actor := _termite()

		actor["split_on_death"] = bad

		_check(not CombatEnemies.new([actor]).is_valid(),

			"AC3: non-boolean split flag is rejected by the constructor: " + str(bad))

		var late := _fight()

		late._enemies[0]["split_on_death"] = bad

		var before := late._enemies.duplicate(true)

		_check(late.stage_split_on_death(1) == {"ok": false, "split": false}

			and late._enemies == before,

			"AC3: late malformed split flag is rejected without mutation")

	var impostor := _other()

	impostor["split_on_death"] = true

	_check(not CombatEnemies.new([impostor]).is_valid(),

		"AC3: non-Termite with forged true split flag is not a legal actor")

	var no_flag := _termite()

	no_flag.erase("split_on_death")

	_reject_with_no_change(no_flag, "missing split flag")

	var false_flag := _termite()

	false_flag["split_on_death"] = false

	_reject_with_no_change(false_flag, "false split flag")

	var wrong_name := _termite()

	wrong_name["name"] = "Impostor"

	_reject_with_no_change(wrong_name, "wrong name")

	var wrong_policy := _termite()

	wrong_policy["intent"]["target"] = "random"

	_reject_with_no_change(wrong_policy, "wrong target policy")

	var missing_attack := _termite()

	missing_attack["intent"]["actions"].remove_at(0)

	_reject_with_no_change(missing_attack, "missing authored attack")

	var extra_attack := _termite()

	extra_attack["intent"]["actions"][0]["hits"] = 2

	_reject_with_no_change(extra_attack, "attack with forged hits")

	var bad_weight := _termite()

	bad_weight["intent"]["actions"][0]["weight"] = 5

	_reject_with_no_change(bad_weight, "wrong weighted attack")

	var bad_block := _termite()

	bad_block["intent"]["actions"][1]["amount"] = 20

	_reject_with_no_change(bad_block, "altered authored block")

	var invalid_position := _fight(1)

	_check(invalid_position.is_valid() and invalid_position.apply_damage(1, 26),

		"precondition: valid dead source for position/actor corruption")

	for corrupt in ["position", "hp", "block", "enemy_position"]:

		var broken := _fight(1)

		broken.apply_damage(1, 26)

		broken._enemies[1][corrupt] = -4

		var before := broken._enemies.duplicate(true)

		_check(broken.stage_split_on_death(1) == {"ok": false, "split": false}

			and broken._enemies == before,

			"AC3: malformed unrelated actor " + corrupt + " rejects all writes")

	var wrong_slot := _fight(1)

	_check(wrong_slot.stage_split_on_death(0) == {"ok": false, "split": false}

		and wrong_slot.stage_split_on_death(3) == {"ok": false, "split": false}

		and wrong_slot.stage_split_on_death("1") == {"ok": false, "split": false},

		"AC3: invalid or non-integer source positions are rejected")

	var duplicate_child := CombatEnemies.new([_termite(), _other(CombatEnemies.HALF_LEFT_ID)])

	duplicate_child.apply_damage(1, 26)

	var before_duplicate := duplicate_child.get_enemies()

	_check(duplicate_child.stage_split_on_death(1) == {"ok": false, "split": false}

		and duplicate_child.get_enemies() == before_duplicate,

		"AC3: a colliding child ID causes atomic rejection rather than duplicate identity")





func _test_no_implicit_wiring() -> void:

	var enemies := _fight()

	_check(enemies.is_valid() and enemies.get_enemy(1).hp == 26,

		"precondition: live-style authoring creates a genuine 26 HP Termite")

	_check(enemies.apply_damage(1, 26) and enemies.is_slain(1)

		and enemies.get_enemies().size() == 1 and enemies.is_victorious(),

		"AC3: ordinary lethal damage is intentionally unchanged without explicit stage")

