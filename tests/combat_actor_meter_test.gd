extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _heroes() -> Array:
	return [
		{"id": "warden", "name": "Warden", "max_hp": 40},
		{"id": "seamstress", "name": "Seamstress", "max_hp": 30},
		{"id": "tinker", "name": "Tinker", "max_hp": 26}
	]


func _enemies() -> Array:
	return [{"id": "ragling", "name": "Ragling", "max_hp": 12}]


func _view(meter: CombatActorMeter, snapshot: Dictionary, side: String,
		party: CombatParty, enemies: CombatEnemies, rng: RandomNumberGenerator) -> void:
	var original: Dictionary = snapshot.duplicate(true)
	var all_heroes := party.get_heroes()
	var all_enemies := enemies.get_enemies()
	var rng_state := rng.state
	_check(meter.show_actor(snapshot, side), "fresh real combat snapshot must be accepted")
	_check(snapshot == original, "presenter leaves the input dictionary unchanged")
	_check(party.get_heroes() == all_heroes, "presenter does not mutate full party state")
	_check(enemies.get_enemies() == all_enemies, "presenter does not mutate full enemy roster")
	_check(rng.state == rng_state, "presenter consumes no run RNG")


func _visual(meter: CombatActorMeter) -> Dictionary:
	return {
		"visible": meter.visible,
		"heading": meter.actor_heading.text,
		"hp": meter.hp_text.text,
		"hp_value": meter.hp_bar.value,
		"hp_max": meter.hp_bar.max_value,
		"block": meter.block_text.text,
		"block_value": meter.block_bar.value,
		"block_max": meter.block_bar.max_value,
		"outer_children": meter.get_child_count(),
		"padding_children": meter.get_node("Padding").get_child_count(),
		"content_children": meter.get_node("Padding/Content").get_child_count()
	}


func _assert_actor(meter: CombatActorMeter, heading: String, hp: int, max_hp: int,
		block: int, note: String) -> void:
	_check(meter.visible and meter.is_visible_in_tree(), note + ": mounted and visible")
	_check(meter.actor_heading.text == heading, note + ": position/name/death heading")
	_check(meter.hp_text.text == "HP: %d/%d" % [hp, max_hp], note + ": exact HP text")
	_check(meter.block_text.text == "Block: %d" % block, note + ": exact Block text")
	_check(meter.hp_bar.min_value == 0.0 and meter.hp_bar.max_value == float(max_hp)
		and meter.hp_bar.value == float(hp), note + ": exact HP bar")
	_check(meter.block_bar.min_value == 0.0
		and meter.block_bar.max_value == float(maxi(1, maxi(max_hp, block)))
		and meter.block_bar.value == float(block), note + ": uncapped Block bar")
	_check(not meter.hp_bar.show_percentage and not meter.block_bar.show_percentage,
		note + ": readable separately titled bars")
	_check(meter.actor_heading.is_visible_in_tree() and meter.hp_text.is_visible_in_tree()
		and meter.block_text.is_visible_in_tree() and meter.hp_bar.is_visible_in_tree()
		and meter.block_bar.is_visible_in_tree(), note + ": all five visible child controls")
	_check(meter.get_node("Padding/Content").get_child_count() == 5,
		note + ": five persistent controls, never duplicate rows")
	_check(meter.hp_bar.get_theme_stylebox("fill") is StyleBoxFlat
		and meter.block_bar.get_theme_stylebox("fill") is StyleBoxFlat,
		note + ": bars have contrasting fill styles")


func _assert_cleared(meter: CombatActorMeter, note: String) -> void:
	_check(not meter.visible and not meter.is_visible_in_tree(), note + ": invalid actor hidden")
	_check(meter.actor_heading.text.is_empty() and meter.hp_text.text.is_empty()
		and meter.block_text.text.is_empty(), note + ": all old text cleared")
	_check(meter.hp_bar.value == 0 and meter.hp_bar.max_value == 1
		and meter.block_bar.value == 0 and meter.block_bar.max_value == 1,
		note + ": no old bar value or range remains")
	_check(meter.get_node("Padding/Content").get_child_count() == 5,
		note + ": invalid source does not append controls")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var stage := Control.new()
	stage.name = "MountedStage"
	root.add_child(stage)
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	var meter := CombatActorMeter.new()
	meter.position = Vector2(18, 18)
	stage.add_child(meter)
	await process_frame

	var party := CombatParty.new(_heroes())
	var enemies := CombatEnemies.new(_enemies())
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	_check(party.is_valid() and party.get_heroes().size() == 3,
		"non-vacuous valid Warden/Seamstress/Tinker party")
	_check(enemies.is_valid() and enemies.get_enemies().size() == 1,
		"non-vacuous valid Ragling roster")
	_check(party.get_hero(1).get("id") == "warden"
		and party.get_hero(2).get("name") == "Seamstress"
		and party.get_hero(3).get("max_hp") == 26
		and enemies.get_enemy(1).get("id") == "ragling",
		"named actors have the exact requested real combat preconditions")
	_check(meter.has_method("show_actor") and meter.is_inside_tree()
		and meter.get_parent() == stage, "required public API and mounted instance exist")
	_check(not meter.visible, "new meter does not pretend an actor exists")

	var expected_heroes := party.get_heroes()
	var expected_enemies := enemies.get_enemies()
	_check(party.gain_block(1, 6), "real starting Warden Block operation succeeds")
	expected_heroes[0]["block"] = 6
	_check(party.get_heroes() == expected_heroes, "exact full party state after Block 6")
	_view(meter, party.get_hero(1), "hero", party, enemies, rng)
	_assert_actor(meter, "1. Warden", 40, 40, 6, "starting Warden")
	await process_frame
	_check(meter.position.x >= 0 and meter.position.y >= 0
		and meter.size.x > 0 and meter.size.y > 0
		and meter.position.x + meter.size.x <= 1280
		and meter.position.y + meter.size.y <= 720,
		"visible meter rectangle fits the 1280x720 target canvas")
	_check(meter.hp_bar.size.x > 0 and meter.block_bar.size.x > 0
		and meter.hp_bar.size.y > 0 and meter.block_bar.size.y > 0,
		"bars have nonempty mounted rectangles")

	var starting_visual := _visual(meter)
	_view(meter, party.get_hero(1), "hero", party, enemies, rng)
	_check(_visual(meter) == starting_visual, "second identical refresh is fully idempotent")

	_check(party.apply_damage(1, 4), "real damage of 4 hits Warden Block first")
	expected_heroes[0]["block"] = 2
	_check(party.get_heroes() == expected_heroes, "full party snapshot after Block absorbs 4")
	_view(meter, party.get_hero(1), "hero", party, enemies, rng)
	_assert_actor(meter, "1. Warden", 40, 40, 2, "Warden partially blocked hit")
	_check(party.apply_damage(1, 5), "real overflow damage succeeds")
	expected_heroes[0]["block"] = 0
	expected_heroes[0]["hp"] = 37
	_check(party.get_heroes() == expected_heroes, "full party snapshot after HP overflow")
	_view(meter, party.get_hero(1), "hero", party, enemies, rng)
	_assert_actor(meter, "1. Warden", 37, 40, 0, "Warden 3 HP lost")

	# A newly selected actor retains its actual 1-based position, not the old name.
	_view(meter, party.get_hero(2), "hero", party, enemies, rng)
	_assert_actor(meter, "2. Seamstress", 30, 30, 0, "different living hero")
	_view(meter, party.get_hero(3), "hero", party, enemies, rng)
	_assert_actor(meter, "3. Tinker", 26, 26, 0, "third hero")

	_view(meter, enemies.get_enemy(1), "enemy", party, enemies, rng)
	_assert_actor(meter, "1. Ragling", 12, 12, 0, "starting enemy")
	_check(enemies.get_enemies() == expected_enemies, "initial enemy full state unchanged")
	_check(enemies.gain_block(1, 4), "real Ragling Block operation succeeds")
	expected_enemies[0]["block"] = 4
	_check(enemies.get_enemies() == expected_enemies, "full enemy snapshot after Block 4")
	_view(meter, enemies.get_enemy(1), "enemy", party, enemies, rng)
	_assert_actor(meter, "1. Ragling", 12, 12, 4, "protected Ragling")
	_check(enemies.apply_damage(1, 6), "real enemy damage absorbed before HP")
	expected_enemies[0]["hp"] = 10
	expected_enemies[0]["block"] = 0
	_check(enemies.get_enemies() == expected_enemies, "exact enemy roster after Block 4 absorbs 6")
	_view(meter, enemies.get_enemy(1), "enemy", party, enemies, rng)
	_assert_actor(meter, "1. Ragling", 10, 12, 0, "Ragling loses 2 HP")

	# Block can exceed max HP. A progress bar's presentation scale cannot cap it.
	_check(enemies.gain_block(1, 17), "Ragling can gain Block exceeding max HP")
	expected_enemies[0]["block"] = 17
	_check(enemies.get_enemies() == expected_enemies, "full enemy state has uncapped Block 17")
	_view(meter, enemies.get_enemy(1), "enemy", party, enemies, rng)
	_assert_actor(meter, "1. Ragling", 10, 12, 17, "uncapped Block above HP")

	_check(party.apply_damage(1, 100), "real Warden lethal overflow damage succeeds")
	expected_heroes[0]["hp"] = 0
	_check(party.is_downed(1) and party.get_heroes() == expected_heroes,
		"downed hero retains original position and full state is exact")
	_view(meter, party.get_hero(1), "hero", party, enemies, rng)
	_assert_actor(meter, "1. Warden — DOWNED", 0, 40, 0, "downed hero")
	_check(enemies.apply_damage(1, 27), "real Ragling lethal damage after Block 17 succeeds")
	expected_enemies[0]["hp"] = 0
	expected_enemies[0]["block"] = 0
	_check(enemies.is_slain(1) and enemies.get_enemies() == expected_enemies,
		"slain enemy retains position and exact full state")
	_view(meter, enemies.get_enemy(1), "enemy", party, enemies, rng)
	_assert_actor(meter, "1. Ragling — SLAIN", 0, 12, 0, "slain enemy")

	var no_cap_party := CombatParty.new(_heroes())
	_check(no_cap_party.gain_block(1, 51), "hero Block also exceeds maximum HP")
	_view(meter, no_cap_party.get_hero(1), "hero", party, enemies, rng)
	_assert_actor(meter, "1. Warden", 40, 40, 51, "Block 51 across new session")
	_check(no_cap_party.get_hero(1).get("block") == 51, "view never limits source Block")

	var valid := no_cap_party.get_hero(1)
	var invalids: Array[Dictionary] = [
		{},
		{"name": "Ghost", "position": 1, "max_hp": 5, "hp": 5},
		{"name": "", "position": 1, "max_hp": 5, "hp": 5, "block": 0},
		{"name": "  ", "position": 1, "max_hp": 5, "hp": 5, "block": 0},
		{"name": 3, "position": 1, "max_hp": 5, "hp": 5, "block": 0},
		{"name": "Ghost", "position": 0, "max_hp": 5, "hp": 5, "block": 0},
		{"name": "Ghost", "position": 4, "max_hp": 5, "hp": 5, "block": 0},
		{"name": "Ghost", "position": 1.0, "max_hp": 5, "hp": 5, "block": 0},
		{"name": "Ghost", "position": 1, "max_hp": 0, "hp": 0, "block": 0},
		{"name": "Ghost", "position": 1, "max_hp": 5.0, "hp": 5, "block": 0},
		{"name": "Ghost", "position": 1, "max_hp": 5, "hp": -1, "block": 0},
		{"name": "Ghost", "position": 1, "max_hp": 5, "hp": 6, "block": 0},
		{"name": "Ghost", "position": 1, "max_hp": 5, "hp": 5.0, "block": 0},
		{"name": "Ghost", "position": 1, "max_hp": 5, "hp": 5, "block": -1},
		{"name": "Ghost", "position": 1, "max_hp": 5, "hp": 5, "block": 1.0}
	]
	var rng_before_invalid := rng.state
	var party_before_invalid := party.get_heroes()
	var enemy_before_invalid := enemies.get_enemies()
	for invalid in invalids:
		_check(meter.show_actor(valid, "hero"), "restore living actor before negative case")
		_check(not meter.show_actor(invalid, "hero"), "malformed source must fail closed: " + str(invalid))
		_assert_cleared(meter, "malformed source")
	for bad_side in ["", "ally", "HERO", "Enemy"]:
		_check(meter.show_actor(valid, "hero"), "restore living actor before invalid side")
		_check(not meter.show_actor(valid, bad_side), "unknown side must fail closed: " + bad_side)
		_assert_cleared(meter, "unknown side")
	_check(party.get_heroes() == party_before_invalid
		and enemies.get_enemies() == enemy_before_invalid
		and rng.state == rng_before_invalid,
		"all negative refreshes leave complete combat states and RNG untouched")

	# Deterministic replay of every displayed text and bar value.
	var first_replay: Array[Dictionary] = []
	var second_replay: Array[Dictionary] = []
	for output in [first_replay, second_replay]:
		var replay_party := CombatParty.new(_heroes())
		var replay_enemies := CombatEnemies.new(_enemies())
		for index in range(4):
			match index:
				0:
					_check(replay_party.gain_block(1, 6), "replay gain Block")
					_view(meter, replay_party.get_hero(1), "hero", party, enemies, rng)
				1:
					_check(replay_party.apply_damage(1, 9), "replay Block-before-HP hit")
					_view(meter, replay_party.get_hero(1), "hero", party, enemies, rng)
				2:
					_check(replay_enemies.gain_block(1, 4), "replay enemy Block")
					_view(meter, replay_enemies.get_enemy(1), "enemy", party, enemies, rng)
				3:
					_check(replay_enemies.apply_damage(1, 6), "replay enemy damage")
					_view(meter, replay_enemies.get_enemy(1), "enemy", party, enemies, rng)
			output.append(_visual(meter))
	_check(first_replay.size() == 4 and first_replay == second_replay,
		"deterministic second run matches all text, bars, visibility and child counts")
	_check(rng.state == rng_before_invalid, "full deterministic replay consumes no RNG")

	stage.queue_free()
	if failures.is_empty():
		print("combat_actor_meter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("combat_actor_meter_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)
