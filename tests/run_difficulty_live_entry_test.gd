extends "res://tests/run_full_run_test.gd"
## Physical routed runs use the existing full-run policy and visit/reward guards.

var mounted_kinds := {}


func _start(fixture: Dictionary) -> void:
	await super._start(fixture)
	var before := _state()
	var difficulty: Dictionary = app.difficulty_state()
	_check(not app.restore_difficulty_state({"selected_tier": 0, "highest_cleared_tier": 2})
		and _state() == before and app.difficulty_state() == difficulty,
		"restore during a real routed run rejects without touching any ledger or RNG")


func _battle(loss: bool = false) -> bool:
	var tier: int = app.run_difficulty.get_selected_tier()
	var kind: String = app.run_map.get_node(app.run_map.get_current_node_id()).type
	mounted_kinds[[tier, kind]] = true
	var catalogs := {}
	for path in RunAuthoredBattleEntry.CATALOG_PATHS:
		for record in RunTypedBattleRoster._parse_catalog_text(FileAccess.get_file_as_string(path)):
			catalogs[record.id] = record
	var percent: int = [0, 10, 20][tier]
	for enemy in app.enemies.get_enemies():
		_check(catalogs.has(enemy.id), "mounted enemy has an authored definition")
		if not catalogs.has(enemy.id):
			continue
		var original: Dictionary = catalogs[enemy.id]
		var hp: int = original.max_hp
		var floor_number: int = app.run_map.get_current_floor()
		if kind == "Fight":
			hp = int(hp * (1.0 if floor_number <= 4 else (1.25 if floor_number <= 8 else 1.5)))
		var expected_hp := hp + int(ceil(hp * percent / 100.0))
		_check(enemy.hp == expected_hp and enemy.max_hp == expected_hp,
			"mounted %s tier %d HP applies after floor scaling exactly once" % [kind, tier])
		for index in range(original.intent.actions.size()):
			var authored: Dictionary = original.intent.actions[index]
			var expected: Dictionary = authored.duplicate(true)
			if authored.type == "attack":
				var amount := int(authored.amount)
				if kind == "Fight" and amount >= 5 and amount <= 9:
					amount = int(amount * (1.0 if floor_number <= 4 else (1.25 if floor_number <= 8 else 1.5)))
					expected.amount = amount
				if tier > 0:
					expected.amount = amount + tier
			if kind == "Boss":
				expected.amount = int(expected.amount)
				expected.weight = int(expected.weight)
			_check(enemy.intent.actions[index] == expected, "mounted intent has exactly one chosen-tier bonus")
	var before := _state()
	app._mount_terminal_result()
	_check(_state() == before, "unsettled battle cannot publish a difficulty win")
	var won := await super._battle(loss)
	if tier > 0 and kind == "Boss":
		_check(app.enemy_intents._boss_phase == 2, "real mounted chosen-tier Boss reaches phase two")
		for action in app.enemies.get_enemy(1).intent.actions:
			if action.type == "attack":
				_check(action.amount == 40 + tier, "mounted phase-two attack retains exactly the chosen tier bonus")
	return won


func _choose_tier(tier: int) -> void:
	await _activate(app.base_button)
	var view: BaseScreen = app.base_screen
	_check(is_instance_valid(view), "real village offers earned tiers")
	if not is_instance_valid(view):
		return
	var before: Dictionary = app.difficulty_state()
	view.difficulty_choice_requested.emit(2)
	_check(app.difficulty_state() == before, "forged tier signal without physical request is inert")
	await _activate(view.difficulty_buttons[tier], true)
	_check(app.difficulty_state().selected_tier == tier, "physical village tier selection reaches authority")
	var binding: Callable = view.difficulty_choice_requested.get_connections()[0].callable
	await _activate(view.back_button)
	before = app.difficulty_state()
	binding.call(0)
	_check(app.difficulty_state() == before, "disposed village tier callback is stale")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	var save_path := OS.get_environment("TEMP").path_join("quilt_difficulty_%d.json" % OS.get_process_id())
	app.difficulty_save_path = save_path
	root.add_child(app)
	current_scene = app
	await _frames()
	for invalid in [null, {}, {"selected_tier": 2, "highest_cleared_tier": -1},
		{"selected_tier": true, "highest_cleared_tier": 0},
		{"selected_tier": 0, "highest_cleared_tier": 0, "extra": 1}]:
		var before: Dictionary = app.difficulty_state()
		_check(not app.restore_difficulty_state(invalid) and app.difficulty_state() == before,
			"malformed or unearned saved tier rejects atomically")
	var fixture := _fixture()
	_check(not fixture.is_empty(), "real full-run fixture exists")
	if not fixture.is_empty():
		for tier in range(3):
			if tier > 0:
				var rng := RandomNumberGenerator.new()
				# The Guard Ragling's authored shield rush makes the old 979/309
				# witnesses lose the final Boss from 32 HP; the same genuine legal
				# seed and full-route policy wins every tier and its replay.
				# Repinned to seed 3012 when the Peddler began pricing the Warden,
				# Seamstress and Tinker look-driven v3 printings: the expanded
				# party stock changes that route's cheapest genuine Shop purchase,
				# so the old 1550 witness no longer wins the tier-2 Boss.
				var witness_seed := 3012
				rng.seed = witness_seed
				var map := RunMap.new()
				_check(map.generate(rng), "higher-tier witness generates the actual map")
				fixture = {"seed": witness_seed, "path": _search(map, map.get_legal_choices(), [], {}), "graph": map.get_floors()}
				_check(not fixture.path.is_empty(), "higher-tier witness meets unchanged full-route prerequisites")
			await _choose_tier(tier)
			attacks = 0
			var result := await _win(fixture)
			_check(not result.is_empty() and app.run_map == null, "real chosen-tier run reaches terminal")
			if app.run_map != null:
				break
			_check(app.difficulty_state().highest_cleared_tier == tier, "only real sequential wins unlock the next tier")
			var persisted: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
			_check(persisted is Dictionary and persisted.size() == 2
				and persisted.get("selected_tier") == tier and persisted.get("highest_cleared_tier") == tier,
				"real main-scene victory persists exactly the two authority fields")
			if tier == 1:
				attacks = 0
				var replay := await _win(fixture)
				_check(not result.is_empty() and result == replay,
					"chosen-tier seed replay preserves encounters, wallets, heroes, deck and RNG")
		if app.run_map == null:
			var before_loss: Dictionary = app.difficulty_state()
			await _start(fixture)
			await _node(fixture.path[0], 0)
			_check(await _battle(true), "chosen-tier opening reaches genuine enemy-phase defeat")
			await _return_terminal("Defeat")
			_check(app.difficulty_state() == before_loss, "real chosen-tier loss preserves earnings and selection")
		for tier in range(3):
			for kind in ["Fight", "Elite", "Boss"]:
				_check(mounted_kinds.has([tier, kind]), "nonvacuous live tier/type entry: %d %s" % [tier, kind])
	var saved: Dictionary = app.difficulty_state()
	app.free()
	app = load("res://scenes/app.tscn").instantiate()
	app.difficulty_save_path = save_path
	root.add_child(app)
	current_scene = app
	await _frames()
	_check(app.difficulty_state() == saved, "fresh real main scene automatically restores saved selection and earnings")
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string('{"selected_tier":2,"highest_cleared_tier":-1}')
	file.close()
	app._load_difficulty_progress()
	_check(app.difficulty_state() == saved, "malformed/unearned disk save cannot change live state")
	DirAccess.remove_absolute(save_path)
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("run_difficulty_live_entry_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
