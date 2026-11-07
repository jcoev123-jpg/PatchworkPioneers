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
	state.append([app.run_rng.state if app.run_rng != null else null,
		is_instance_valid(app.party_picker), is_instance_valid(app.stitched_run_panel),
		app.stitched_run_draft.duplicate(), app.stitched_run_session != null,
		app.title_view.is_visible_in_tree()])
	return state


func _run() -> void:
	root.size = Vector2i(1280, 720)
	_check(not ProjectSettings.has_setting("patchwork/combat_mode"), "retired combat mode setting removed")
	_check(BOOT.PUBLIC_SCREENS == ["title", "base", "stitched_battle", "stitched_walk"], "exact public URL allowlist")
	for screen in ["title", "base", "stitched_battle", "stitched_walk"]:
		_check(screen in BOOT.PUBLIC_SCREENS and screen in BOOT.SCREENS, "public and direct preview supported: " + screen)
	for screen in ["map", "battle", "reward", "shop", "rest", "event", "results"]:
		_check(screen not in BOOT.SCREENS and screen not in BOOT.PUBLIC_SCREENS, "legacy preview cannot admit: " + screen)
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
		"?screen=map&screen=battle", "?screen=map&screen=map", "?screen=battle%26x", "?screen=Base",
		"?screen=base&screen=base", "?screen=base&screen=map", "?screen=base%26x", "?screen=village",
		"?screen=map", "?screen=battle", "?screen=reward", "?screen=shop", "?screen=rest", "?screen=event", "?screen=results",
		"?screen=title&screen=title", "?screen=stitched_battle&screen=title", "?screen=stitched_battle&screen=stitched_battle",
		"?screen=stitched_battle%26x", "?screen=title=base", "?screen=%20title", "?screen=title%00",
		"?screen%00=title", "?screen=title&scr%65en=base", "?screen=%6dap", "?screen=%62attle",
		"?screen=stitched_walk&screen=stitched_walk", "?screen=stitched_walk&scr%65en=title",
		"?screen=stitched_walk%00", "?screen=stitched_walk%", "?screen=stitched_walk%GG", "?screen=stitched_walk%2",
		"?screen=stitched_walk&x=%-1", "?screen=stitched_walk&x=%+a",
		null, 12]:
		var parsed: String = boot.screen_from_query(query)
		_check(parsed == "", "unsupported query rejected: " + str(query))
		_check(not await boot.enter_preview(app, parsed), "unsupported request cannot start run")
		_check(_snapshot(app) == pristine and app.run_rng == null and app.run_map == null,
			"invalid input preserves all title resources and seed")
		_check(not boot.preview_ready and app.title_view.is_visible_in_tree(), "invalid URL never ready or leaves title")
	_check(randi() == expected_global, "invalid input consumes no global RNG")
	_check(await boot.enter_preview(app, "stitched_walk"), "walk opens on pristine app")
	var first_walk: Dictionary = boot.walk_view.expected.duplicate(true)
	boot.walk_view.exit_button.pressed.emit()
	await process_frame
	_check(_snapshot(app) == pristine and boot.walk_view == null, "mounted exit restores pristine app")
	_check(await boot.enter_preview(app, "stitched_walk") and boot.walk_view.expected == first_walk, "same-app reopen creates identical seeded walk after cleanup")
	boot.walk_view.exit_button.pressed.emit()
	await process_frame
	app.free()
	# Retired card screens are refused before any mutation.
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await process_frame
	pristine = _snapshot(app)
	seed(114116)
	expected_global = randi()
	seed(114116)
	for screen in ["map", "battle", "reward", "shop", "rest", "event", "results"]:
		_check(not await boot.enter_preview(app, screen), "retired card preview refused: " + screen)
		_check(_snapshot(app) == pristine and app.run_rng == null and app.run_map == null
			and app.deck == null and not boot.preview_ready and not boot._busy,
			"card refusal preserves state, RNG, title and readiness: " + screen)
	_check(randi() == expected_global, "card refusal consumes no global RNG")
	app.start_button.pressed.emit()
	_check(is_instance_valid(app.stitched_run_panel) and app.stitched_run_session == null
		and app.stitched_run_draft.size() == 4 and app.run_rng == null and app.deck == null,
		"ordinary New Run still opens the four-pick Stitched chooser after refused previews")
	_check(not app.stitched_run_buttons.is_empty(), "Stitched chooser mounts Set out")
	if not app.stitched_run_buttons.is_empty():
		app.stitched_run_buttons[0].pressed.emit()
		_check(app.stitched_run_session != null and app.stitched_run_session.heroes.size() == 4
			and app.stitched_run_session.is_consistent() and app.run_map == null and app.deck == null,
			"real Set out starts a consistent four-doll Stitched run")
	app.free()
	for screen in BOOT.SCREENS:
		var replay: Array = []
		for repeat in range(2):
			app = load("res://scenes/app.tscn").instantiate()
			root.add_child(app)
			await process_frame
			boot.preview_ready = false
			var public_screen: bool = screen in BOOT.PUBLIC_SCREENS
			var parsed: String = boot.screen_from_query("?other=value&screen=" + screen)
			_check(parsed == (screen if public_screen else ""), "query uses public allowlist: " + screen)
			if public_screen:
				_check(boot.screen_from_query("?scr%65en=" + screen.uri_encode()) == screen, "decoded exact public query accepted: " + screen)
			var frames := Engine.get_process_frames()
			seed(114115)
			expected_global = randi()
			seed(114115)
			var opening_globals := _snapshot(app)
			_check(await boot.enter_preview(app, parsed), "preview succeeds: " + screen)
			_check(boot.preview_ready and Engine.get_process_frames() >= frames + 2, "ready follows two frames: " + screen)
			_check(boot._expected_view(app, screen), "matching mounted live view: " + screen)
			_check(randi() == expected_global, "preview preserves global RNG: " + screen)
			if screen == "title":
				_check(app.run_map == null and app.run_rng == null and app.run_deck.is_empty(), "title remains unstarted")
				_check(app.start_button.is_visible_in_tree() and app.start_button.has_focus(), "public title keeps keyboard New Run focus")
			elif screen == "base":
				_check(app.run_map == null and app.run_rng == null and app.run_deck.is_empty()
					and app.run_heroes.is_empty() and app.session_gold == 0 and app.run_scraps == 0,
					"village preview allocates no run, RNG, deck or currency")
				_check(not app.title_view.is_visible_in_tree() and app.base_screen.is_visible_in_tree()
					and app.base_screen.has_open_village(), "village preview replaces the title")
				_check(app.base_screen.set_out_button.is_visible_in_tree()
					and app.base_screen.set_out_button.has_focus()
					and app.base_screen.back_button.is_visible_in_tree(),
					"village preview mounts focusable Set out and Back to title")
			elif screen == "stitched_walk":
				var stage: StitchedWalkScreen = boot.walk_view
				_check(stage != null and stage.is_visible_in_tree() and stage.walk != null, "public walk mounts authoritative rules")
				_check(stage.expected.dolls.size() == 4 and stage.expected.step == 0 and stage.expected.revision == 0, "walk starts seeded four-doll fixture")
				_check(app.deck == null and app.run_map == null and app.run_rng == null and app.stitched_run_session == null, "walk remains isolated from run globals")
				if repeat == 0:
					replay = [stage.expected.duplicate(true)]
				else:
					_check(replay == [stage.expected], "public walk replay is identical")
				var walk_before := stage.walk.snapshot()
				_check(not await boot.enter_preview(app, "stitched_walk") and stage.walk.snapshot() == walk_before, "walk reentry refuses without mutation")
				boot.exit_stitched_preview(null)
				_check(boot.walk_view == stage and stage.is_visible_in_tree(), "foreign exit cannot unmount the active preview")
			elif screen == "stitched_battle":
				var stage: StitchedBattleScreen = boot.stitched_view
				_check(stage != null and stage.is_visible_in_tree() and stage.battle != null and stage.battle.is_valid(), "stitched public scene mounts real rules")
				_check(stage.battle.get_heroes().size() == 4 and stage.battle.get_foes().size() == 3, "stitched preview starts 4v3, with fourth foe rank empty")
				_check(app.deck == null and app.run_map == null and app.run_rng == null and app.run_deck.is_empty() and app.run_heroes.is_empty(), "stitched preview never allocates card run")
				_check(stage._puppets.size() == 8 and stage._seat_buttons.size() == 8, "four mounted rank seats per side")
			var snapshot := _snapshot(app)
			if screen == "stitched_walk":
				pass # Model replay checked above, independently of app globals.
			elif repeat == 0:
				replay = snapshot
			else:
				_check(snapshot == replay, "independent deterministic model replay: " + screen)
			if screen == "base":
				_check(not await boot.enter_preview(app, "base") and _snapshot(app) == snapshot,
					"already-open village preview cannot be re-entered")
			if screen not in ["title", "base"]:
				_check(not await boot.enter_preview(app, "stitched_battle") and _snapshot(app) == snapshot, "active run reentry rejected without spending")
				if screen in ["stitched_battle", "stitched_walk"]:
					boot.exit_stitched_preview(app)
					_check(boot.stitched_view == null and boot.walk_view == null and app.title_view.is_visible_in_tree() and not boot.preview_ready, "stitched preview unmounts and restores title")
					_check(_snapshot(app) == opening_globals, "preview exit restores all opening app globals")
					boot.exit_stitched_preview(app)
					_check(app.start_button.has_focus(), "repeat exit preserves title focus")
			app.free()
			await process_frame
	# A failed public callback must not announce readiness or allocate a run.
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await process_frame
	pristine = _snapshot(app)
	app.base_button.pressed.disconnect(Callable(app, "_open_base"))
	_check(not await boot.enter_preview(app, "base") and not boot.preview_ready and not boot._busy,
		"failed public Base admission never ready")
	_check(_snapshot(app) == pristine and app.run_rng == null and app.deck == null and app.run_map == null,
		"failed public Base admission preserves all resources")
	app.free()
	for failure in failures:
		printerr(failure)
	print("live_web_playtest_boot_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
