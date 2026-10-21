extends "res://tests/live_event_treasure_continuation_test.gd"


func _effects() -> Array:
	var carry := app.party_carryover as RunTornCarryover
	return [app.run_heroes.duplicate(true), app.run_deck.duplicate(), app.session_gold,
		app.run_scraps, app.run_trinkets.duplicate(), app.run_removal_count,
		app.run_stitch_descriptors.duplicate(true), app.run_next_stitch_id,
		app.run_rng.state, carry.read_state(), carry.torn.read_state(),
		carry._wardrobe.get_snapshot() if carry._wardrobe != null else {},
		app.act_outcome.get_state(), _state() if app.deck != null else {},
		app.shop_visit.get_state() if app.shop_visit != null else {},
		app.shop_purchases.get_state() if app.shop_purchases != null else {}]


func _event_state() -> Array:
	return [_effects(), app.run_map.get_floors(), app.run_map.get_route(),
		app._quiet_spool_completed, app.quiet_spool_panel, app._quiet_spool_outcome,
		app._quiet_spool_outcome.is_consumed() if app._quiet_spool_outcome != null else false]


func _reject_event(callback: Callable, reason: String) -> void:
	var before := _event_state()
	if callback.is_valid():
		callback.call()
	_check(_event_state() == before, reason + " preserves entire run, map, ownership and RNG")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	var stale: Array[Callable] = []
	for won in [false, true]:
		var fixture := _placeholder_fixture("", "Event") if won else {"seed": 7, "path": ["f01_n1", "f02_n0"]}
		_check(not fixture.is_empty(), "real seeded Event fixture exists")
		if fixture.is_empty():
			continue
		for choice_index in range(2):
			var replay: Array = []
			for mode in range(2):
				seed(1110111)
				var global_next := randi()
				seed(1110111)
				if won:
					if not await _routed_win(fixture, false):
						break
					await _click(app.reward_buttons[3])
					await _click(app.continue_button)
				else:
					app.run_seed = fixture.seed
					await _click(app.start_button)
				var before_stale := _event_state()
				for callback in stale:
					if callback.is_valid():
						callback.call()
				_check(_event_state() == before_stale, "fresh same-seed run rejects old bindings")
				var id: String = fixture.path[0]
				var action := _route_action(id)
				var entry: Callable = action.pressed.get_connections()[0].callable
				# Invalid authored records fail before choosing the node or mounting anything.
				var path := OS.get_environment("TEMP").path_join("quiet_spool_route_invalid.json")
				for malformed in ["{}", "not JSON", '{"events":[{"id":"quiet_spool"}]}',
					'{"events":[{"id":"quiet_spool","title":"bad","description":"bad","choices":[{"id":"watch","text":"Watch"},{"id":"ignore","text":"Ignore"}]}]}']:
					var file := FileAccess.open(path, FileAccess.WRITE)
					_check(file != null, "external malformed fixture writable")
					file.store_string(malformed)
					file.close()
					app.event_catalog_path = path
					_reject_event(entry, "malformed authored record")
				DirAccess.remove_absolute(path)
				_reject_event(entry, "missing authored catalog")
				app.event_catalog_path = "res://data/events/m04_events.json"
				var prior: Array = app.run_map.get_route()
				var effects := _effects()
				var scraps: int = app.run_scraps
				_check(won or scraps == 0, "title opening starts with zero scraps")
				await _click(action)
				var panel: LiveEventChoicePanel = app.quiet_spool_panel
				_check(panel != null and panel.has_open_event(), "first connected Event mounts real authored panel")
				if panel == null:
					break
				_check(app.route_view == null and app.route_buttons.is_empty() and not app._can_choose_connected_route(), "no onward controls before choice")
				_check(app.run_map.get_route() == prior + [id] and _effects() == effects, "entry changes only selected route")
				_check(panel.title_label.text == "The Quiet Spool", "record selected by stable authored ID")
				var buttons := panel.get_choice_buttons()
				_check(buttons.size() == 2 and buttons[0].text == "Watch the thread unwind" and buttons[1].text == "Leave the spool alone", "authored Watch and Ignore controls")
				_check(buttons[0].has_focus(), "Watch receives initial keyboard focus")
				for button in buttons:
					_check(Rect2(0, 0, 1280, 720).encloses(button.get_global_rect()), "choice fits viewport")
				var commit: Callable = panel.choice_committed.get_connections()[0].callable
				_reject_event(commit.bind("quiet_spool", "watch"), "forged uncommitted signal")
				_reject_event(entry, "duplicate entry while pending")
				_reject_event(app._choose_placeholder_route.bind(id, weakref(app.run_map), app.run_map.get_route(), buttons[0]), "placeholder bypass")
				var selected: Button = buttons[choice_index]
				var click: Callable = selected.pressed.get_connections()[0].callable
				selected.disabled = true
				_reject_event(click, "disabled choice callback")
				selected.disabled = false
				selected.hide()
				_reject_event(click, "hidden choice callback")
				selected.show()
				app.session_gold += 1
				_reject_event(commit.bind("quiet_spool", "watch"), "drifted wallet")
				app.session_gold -= 1
				if mode == 0:
					await _click(selected)
				else:
					buttons[0].grab_focus()
					if choice_index == 1:
						await _key(KEY_TAB)
					_check(selected.has_focus(), "Tab reaches intended choice")
					await _key(KEY_ENTER if choice_index == 0 else KEY_SPACE)
				_check(app.quiet_spool_panel == null and app._quiet_spool_completed and app.route_view != null, "commit disposes panel and restores chooser")
				_check(app.run_scraps == scraps + (1 if choice_index == 0 else 0), "exact one-scrap Watch or zero-scrap Ignore receipt")
				# Compare every other resource independently of the intended wallet delta.
				var settled_scraps: int = app.run_scraps
				app.run_scraps = scraps
				_check(_effects() == effects, "choice preserves heroes, deck, gold, ownership and RNG")
				app.run_scraps = settled_scraps
				for callback in [commit.bind("quiet_spool", "watch"), commit.bind("quiet_spool", "ignore"), click, entry]:
					_reject_event(callback, "replay after completion")
					stale.append(callback)
				await _check_chooser()
				var timeline := [_effects(), app.run_map.get_route(), app.run_map.get_legal_choices()]
				if mode == 0:
					replay = timeline
				else:
					_check(timeline == replay, "independent same-seed input modes reproduce outcome")
				await _click(_route_action(fixture.path[1]))
				_check(app.run_map.get_current_node_id() == fixture.path[1], "completed Event allows actual next node")
				if won:
					_check(app.quiet_spool_panel == null and app.route_view != null, "later Event retains no-effect continuation")
				_check(randi() == global_next, "entry, rejection and outcome preserve actual global RNG")
				app._return_to_title()
				await _frames()
				_check(app.quiet_spool_panel == null and app._quiet_spool_context.is_empty() and not app._quiet_spool_completed, "title invalidates completed binding")
	# Abandon an unresolved visit, then prove its live callbacks cannot reach a new one.
	app.run_seed = 7
	await _click(app.start_button)
	await _click(_route_action("f01_n1"))
	var old_panel: LiveEventChoicePanel = app.quiet_spool_panel
	var abandoned: Callable = old_panel.choice_committed.get_connections()[0].callable
	var abandoned_click: Callable = old_panel.get_choice_buttons()[0].pressed.get_connections()[0].callable
	app._return_to_title()
	await _frames()
	await _click(app.start_button)
	await _click(_route_action("f01_n1"))
	_reject_event(abandoned.bind("quiet_spool", "watch"), "abandoned signal in fresh seeded visit")
	_reject_event(abandoned_click, "abandoned choice in fresh seeded visit")
	# A real panel commit with a stale run wallet must reject, even though the
	# panel itself accepted the choice. It cannot repair or spend the drift.
	var pending: LiveEventChoicePanel = app.quiet_spool_panel
	var outcome: RunQuietSpoolOutcome = app._quiet_spool_outcome
	app.session_gold += 1
	var drifted := _event_state()
	await _click(pending.get_choice_buttons()[0])
	_check(pending._selector.is_claimed() and not outcome.is_consumed(), "actual panel signal reaches stale-context rejection")
	_check(_event_state() == drifted and app.route_view == null, "stale wallet cannot settle or traverse")
	app._return_to_title()
	await _frames()
	await _click(app.start_button)
	await _click(_route_action("f01_n1"))
	await _click(app.quiet_spool_panel.get_choice_buttons()[1])
	_check(app.run_scraps == 0, "fresh Ignore has independent outcome")
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_quiet_spool_route_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
