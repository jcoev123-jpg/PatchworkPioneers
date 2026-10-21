extends SceneTree

const BOOT := preload("res://scripts/live_web_playtest_boot.gd")
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _snapshot(app) -> Array:
	var state: Array = [app.run_seed, app.session_gold, app.run_scraps, app.run_deck.duplicate(), app.run_heroes.duplicate(true)]
	if app.run_map != null:
		state.append([app.run_map.get_floors(), app.run_map.get_route(), app.run_rng.state, app.act_outcome.get_state()])
	if app.deck != null:
		state.append([app.encounter_id, app.party.get_heroes(), app.enemies.get_enemies(),
			app.deck.hand.duplicate(), app.deck.draw_pile.duplicate(), app.deck.discard_pile.duplicate(),
			app.deck.turn_active, app.battle_result.get_outcome(), app.fight_reward_offers.duplicate(true)])
	return state


func _run() -> void:
	root.size = Vector2i(1280, 720)
	_check(root.get_node_or_null("LiveWebPlaytestBoot") != null, "startup autoload registered")
	var boot = root.get_node("LiveWebPlaytestBoot")
	var app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await process_frame
	_check(not boot.preview_ready and app.title_view.is_visible_in_tree() and app.run_rng == null,
		"non-web autoload leaves ordinary title without allocating RNG")
	seed(114114)
	var expected_global := randi()
	seed(114114)
	var pristine := _snapshot(app)
	for query in ["", "?other=map", "?screen", "?screen=", "?screen=unknown", "?screen=Battle",
		"?screen=map&screen=battle", "?screen=map&screen=map", "?screen=battle%26x", null, 12]:
		var parsed: String = boot.screen_from_query(query)
		_check(parsed == "", "unsupported query rejected: " + str(query))
		_check(not await boot.enter_preview(app, parsed), "unsupported request cannot start run")
		_check(_snapshot(app) == pristine and app.run_rng == null and app.run_map == null,
			"invalid input preserves all title resources and seed")
	_check(randi() == expected_global, "invalid input consumes no global RNG")
	app.free()
	for screen in BOOT.SCREENS:
		var replay: Array = []
		for repeat in range(2):
			app = load("res://scenes/app.tscn").instantiate()
			root.add_child(app)
			await process_frame
			boot.preview_ready = false
			_check(boot.screen_from_query("?other=value&screen=" + screen) == screen, "exact query accepted: " + screen)
			var frames := Engine.get_process_frames()
			seed(114115)
			expected_global = randi()
			seed(114115)
			_check(await boot.enter_preview(app, screen), "preview succeeds: " + screen)
			_check(boot.preview_ready and Engine.get_process_frames() >= frames + 2, "ready follows two frames: " + screen)
			_check(boot._expected_view(app, screen), "matching mounted live view: " + screen)
			_check(randi() == expected_global, "preview preserves global RNG: " + screen)
			if screen == "title":
				_check(app.run_map == null and app.run_rng == null and app.run_deck.is_empty(), "title remains unstarted")
			else:
				_check(app.run_seed == {"rest": 2, "shop": 3, "event": 7}.get(screen, 1), "fixed seed: " + screen)
				_check(app.session_gold == 100 and app.run_scraps == 10, "consistent currency fixture: " + screen)
				_check(app.run_deck == StarterCards.new().get_starting_deck(), "authored complete starter deck: " + screen)
				var heroes: Array = app.run_heroes
				_check(heroes.size() == 3, "three actual heroes")
				for index in range(heroes.size()):
					_check(heroes[index].id == ["warden", "seamstress", "tinker"][index]
						and heroes[index].position == index + 1 and heroes[index].hp > 0, "authored hero identity/position")
				var route: Array = app.run_map.get_route()
				if screen == "map":
					_check(route.is_empty() and app.deck == null and not app.route_buttons.is_empty(), "seed-1 actionable chooser")
					_check(app._unfought_run(), "bound preview wallet admits opening route")
					app.session_gold += 1
					_check(not app._unfought_run(), "preview gold drift still fails closed")
					app.session_gold -= 1
					app.run_scraps += 1
					_check(not app._unfought_run(), "preview scraps drift still fails closed")
					app.run_scraps -= 1
				else:
					var id: String = {"rest": "f01_n2", "shop": "f01_n2", "event": "f01_n1"}.get(screen, "f01_n0")
					_check(route == [id] and app.run_map.get_current_node_id() == id, "exact real route chosen")
					_check(app.run_map.get_node(id).type == {"rest": "Rest", "shop": "Shop", "event": "Event"}.get(screen, "Fight"), "legal node type")
				if screen in ["battle", "reward", "results"]:
					_check(app.party != null and app.enemies != null and app.party.is_valid() and app.enemies.is_valid() and not app.enemies.get_enemies().is_empty(), "real mounted combat services")
				if screen == "reward":
					_check(app.enemies.is_defeated() and not app.party.is_defeated()
						and app.battle_result.get_outcome() == CombatBattleResult.VICTORY, "actual victory witnessed")
					_check(app.reward_buttons.size() == 4 and app.fight_rewards != null
						and not app.fight_reward_claimed and app.terminal_result_panel == null, "unclaimed legal reward without defeat panel")
					for button in app.reward_buttons:
						_check(button.is_visible_in_tree() and not button.disabled, "reward action mounted and enabled")
				if screen == "results":
					_check(app.party.is_defeated() and not app.enemies.is_defeated()
						and app.act_outcome.get_state().run_status == "DEFEAT", "actual routed defeat settled")
					_check(app.reward_buttons.is_empty() and app.fight_rewards == null and app.card_reward == null, "defeat never offers rewards")
			var snapshot := _snapshot(app)
			if repeat == 0:
				replay = snapshot
			else:
				_check(snapshot == replay, "independent deterministic model replay: " + screen)
			if screen != "title":
				_check(not await boot.enter_preview(app, "battle") and _snapshot(app) == snapshot, "active run reentry rejected without spending")
				app._return_to_title()
				app.start_button.pressed.emit()
				_check(app.run_map != null and app.session_gold == 0 and app.run_scraps == 0
					and app._unfought_run(), "ordinary restart on same app restores zero wallet")
				app.session_gold = 100
				app.run_scraps = 10
				_check(not app._unfought_run(), "previous preview cannot authorize new map wallet drift")
			app.free()
			await process_frame
	# Failed Start and failed route admission never announce readiness.
	for broken in ["start", "route"]:
		app = load("res://scenes/app.tscn").instantiate()
		root.add_child(app)
		await process_frame
		if broken == "start":
			app.starter_deck_path = "res://missing-preview-deck.json"
		else:
			app.start_run_requested.connect(func():
				for button in app.route_buttons:
					button.disabled = true)
		_check(not await boot.enter_preview(app, "battle") and not boot.preview_ready, "failed admission never ready: " + broken)
		_check(app.deck == null and app.battle_result == null, "failed admission creates no combat")
		app.free()
	for failure in failures:
		printerr(failure)
	print("live_web_playtest_boot_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
