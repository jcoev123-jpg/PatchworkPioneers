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
	var boss_id := ""
	for enemy in app.enemies.get_enemies():
		if kind == "Boss":
			boss_id = enemy.id
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
			if kind == "Boss" and enemy.id == CombatBehemothPhaseRules.BOSS_ID:
				# Only the Behemoth's bound schedule is rebuilt by
				# CombatBehemothPhaseRules.select_phase, which normalizes JSON
				# numbers to ints. The Colossus keeps its raw JSON-authored
				# numeric representation in the mounted roster, so its expected
				# dictionary keeps the authored floats (except the tier bonus,
				# which RunDifficulty.scale_intent writes as an int).
				expected.amount = int(expected.amount)
				expected.weight = int(expected.weight)
			_check(enemy.intent.actions[index] == expected, "mounted intent has exactly one chosen-tier bonus")
	var before := _state()
	app._mount_terminal_result()
	_check(_state() == before, "unsettled battle cannot publish a difficulty win")
	_check(not app.heirloom_unlocked or app._difficulty_completed_map != app.run_map,
		"unsettled battle cannot record a first-run unlock")
	var won := await super._battle(loss)
	if tier > 0 and kind == "Boss" and boss_id == CombatBehemothPhaseRules.BOSS_ID:
		_check(app.enemy_intents._boss_phase == 2, "real mounted chosen-tier Boss reaches phase two")
		for action in app.enemies.get_enemy(1).intent.actions:
			if action.type == "attack":
				_check(action.amount == 40 + tier, "mounted phase-two attack retains exactly the chosen tier bonus")
	elif kind == "Boss" and boss_id != CombatBehemothPhaseRules.BOSS_ID:
		# Only the Behemoth authors a phase two; the chosen Colossus must never
		# inherit its phase state or its stronger phase-two schedule.
		_check(app.enemy_intents._boss_phase == 0,
			"real mounted Colossus never binds a Behemoth phase")
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
	_check(not app.heirloom_unlocked and app.difficulty_state().size() == 2,
		"fresh real app begins locked with public two-field difficulty")
	for invalid in [null, {}, {"selected_tier": 2, "highest_cleared_tier": -1},
		{"selected_tier": true, "highest_cleared_tier": 0},
		{"selected_tier": 0, "highest_cleared_tier": 0, "extra": 1}]:
		var before: Dictionary = app.difficulty_state()
		_check(not app.restore_difficulty_state(invalid) and app.difficulty_state() == before,
			"malformed or unearned saved tier rejects atomically")
	var fixture := _fixture()
	_check(not fixture.is_empty(), "real full-run fixture exists")
	if not fixture.is_empty():
		# Loss-first on an actual mounted run must unlock P12 without advancing
		# difficulty, awarding a victory receipt or inventing terminal state.
		var initial_difficulty: Dictionary = app.difficulty_state()
		await _start(fixture)
		await _node(fixture.path[0], 0)
		_check(not app.heirloom_unlocked and app.run_map != null,
			"first real battle is still nonterminal and eligibility stays locked")
		_check(await _battle(true), "first genuine enemy-phase defeat settles")
		_check(app.heirloom_unlocked and app.difficulty_state() == initial_difficulty,
			"first genuine LOSS unlocks Heirlooms without clearing difficulty")
		var first_loss_saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
		_check(first_loss_saved is Dictionary and first_loss_saved.get("heirloom_unlocked") == true
			and int(first_loss_saved.get("difficulty", {}).get("highest_cleared_tier", -99)) == -1,
			"first loss durably records eligibility in versioned profile")
		await _return_terminal("Defeat")
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
				# Repinned again to seed 2404 when the Moth Queen joined the
				# sorted Boss choice: seed 3012's unchanged route now selects the
				# Queen at both higher tiers and the unchanged held-card pilot
				# loses that Boss (Queen at 4 HP, all three heroes down). Seed
				# 2404's legal twelve-floor route selects the Sewing Machine
				# Colossus (106 HP at tier 1, 116 HP at tier 2) in both tiers and
				# the same pilot genuinely wins both runs and the tier-1 replay.
				# Repinned to seed 2855 when the real selected Seamstress began
				# shipping her four V3 needle/thread starters: the authentic kit
				# changes the pilot's draws and RNG cadence, so seed 2404's
				# tier-2 Colossus now kills all three heroes at 44 HP. Seed 2855
				# met the same twelve-floor/Shop/Rest/Event prerequisites and the
				# same held-card pilot genuinely won tier 1, its replay and tier 2.
				# Repinned to seed 1718 when every Boss received its three authored
				# named attacks: the same genuine twelve-floor seed and held-card
				# pilot genuinely win tier 1, its replay and tier 2 again, where seed
				# 2855's tier-2 Boss left all three heroes down with it at 10 HP.
				var witness_seed := 1718
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
			_check(app.heirloom_unlocked, "authenticated first completed victory latches both patch eligibility")
			var persisted: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
			_check(persisted is Dictionary and persisted.size() == 3
				and persisted.get("version") == 1 and persisted.get("heirloom_unlocked") == true
				and persisted.get("difficulty") is Dictionary
				and int(persisted["difficulty"].get("selected_tier", -1)) == tier
				and int(persisted["difficulty"].get("highest_cleared_tier", -1)) == tier
				and app.difficulty_state().size() == 2,
				"real main-scene victory persists envelope with unchanged two-field authority")
			if tier == 1:
				attacks = 0
				var replay := await _win(fixture)
				_check(not result.is_empty() and result == replay,
					"chosen-tier seed replay preserves encounters, wallets, heroes, deck and RNG")
		if app.run_map == null:
			var before_loss: Dictionary = app.difficulty_state()
			var before_loss_profile: String = FileAccess.get_file_as_string(save_path)
			await _start(fixture)
			await _node(fixture.path[0], 0)
			_check(await _battle(true), "chosen-tier opening reaches genuine enemy-phase defeat")
			await _return_terminal("Defeat")
			_check(app.difficulty_state() == before_loss, "real chosen-tier loss preserves earnings and selection")
			_check(app.heirloom_unlocked and FileAccess.get_file_as_string(save_path) == before_loss_profile,
				"repeated genuine loss keeps first unlock without duplicate profile writes")
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
	_check(app.difficulty_state() == saved and app.heirloom_unlocked,
		"fresh real main scene restores both selected difficulty and first-run eligibility")
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string('{"selected_tier":2,"highest_cleared_tier":-1}')
	file.close()
	app._load_difficulty_progress()
	_check(app.difficulty_state() == saved and app.heirloom_unlocked,
		"malformed/unearned disk save cannot change either saved profile field")
	DirAccess.remove_absolute(save_path)
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("run_difficulty_live_entry_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
