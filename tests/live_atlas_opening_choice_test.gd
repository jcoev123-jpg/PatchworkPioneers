extends "res://tests/live_run_map_entry_test.gd"


func _marker(app, id: String) -> Button:
	var button := app.route_atlas.get_node_or_null("Node_" + id + "/Action") as Button
	_check(button != null and button.is_visible_in_tree(), "actual highlighted marker mounted")
	return button


func _inert(app, callback: Callable, id: String, reason: String) -> void:
	var before := _snapshot(app)
	var controls: Array = [app.route_view, app.route_atlas, app.route_atlas_overlay,
		app.route_map_button, root.gui_get_focus_owner()]
	callback.call(id)
	_check(_snapshot(app) == before and controls == [app.route_view, app.route_atlas,
		app.route_atlas_overlay, app.route_map_button, root.gui_get_focus_owner()], reason)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.run_seed = 6
	var id := "f01_n0"
	var replay: Array = []
	var stale: Array[Callable] = []
	# Same scene, title resets, same seed: chooser, mouse atlas, Enter atlas, Space atlas.
	for mode in range(4):
		await _click(app.route_button)
		_check(app.run_map != null and app.run_map.get_node(id).type == "Fight",
			"seed has legal opening Fight")
		for callback in stale:
			_inert(app, callback, id, "disposed listener cannot affect restarted session")
		if mode == 0:
			await _click(app.route_buttons[0])
		else:
			await _click(app.route_map_button)
			var atlas: RunRouteAtlas = app.route_atlas
			var cleared: Array = []
			atlas.tree_exiting.connect(func(): cleared.append(atlas._map == null))
			_check(atlas.node_requested.get_connections().size() == 1, "exactly one app listener")
			var callback: Callable = atlas.node_requested.get_connections()[0].callable
			for old in stale:
				_inert(app, old, id, "old listener cannot affect new mounted overlay")
			stale.append(callback)
			# Forge each captured identity independently while all other sources stay valid.
			for index in range(5):
				var args: Array = callback.get_bound_arguments()
				args[index] = weakref(app.route_back_button)
				var forged := Callable(app, "_choose_atlas_opening").bindv(args)
				_inert(app, forged, id, "forged captured identity rejected: " + str(index))
			_inert(app, callback, "unknown", "unknown signal rejected")
			_inert(app, callback, "f02_n0", "future signal rejected")
			for opening in app.run_map.get_legal_choices():
				if app.run_map.get_node(opening).type != "Fight":
					_inert(app, callback, opening, "unsupported opening signal rejected")
			app.route_buttons[0].disabled = true
			_inert(app, callback, id, "disabled matching chooser rejects signal")
			app.route_buttons[0].disabled = false
			var original_id = app.route_buttons[0].get_meta("route_id")
			app.route_buttons[0].set_meta("route_id", "forged")
			_inert(app, callback, id, "forged chooser identity rejected")
			app.route_buttons[0].set_meta("route_id", original_id)
			var map = app.run_map
			var foreign := RunMap.new()
			var rng := RandomNumberGenerator.new()
			rng.seed = 6
			_check(foreign.generate(rng), "foreign generated map fixture")
			app.run_map = foreign
			_inert(app, callback, id, "foreign live map rejected")
			app.run_map = map
			atlas.bind_map(foreign)
			_inert(app, callback, id, "foreign atlas binding rejected")
			atlas.bind_map(map)
			_check(map.choose_node(id), "external route progress fixture")
			_inert(app, callback, id, "changed route rejects listener")
			var empty_route: Array[String] = []
			_check(map.undo_choice(id, empty_route), "restore external route fixture")
			app.route_atlas_overlay.remove_child(atlas)
			_inert(app, callback, id, "detached atlas rejected")
			app.route_atlas_overlay.add_child(atlas)
			var overlay = app.route_atlas_overlay
			app.remove_child(overlay)
			_inert(app, callback, id, "detached overlay rejected")
			app.add_child(overlay)
			cleared.clear()
			var marker := _marker(app, id)
			if marker == null:
				break
			if mode == 1:
				await _click(marker)
			else:
				marker.grab_focus()
				_check(marker.has_focus(), "actual atlas marker keyboard focus")
				await _key(KEY_ENTER if mode == 2 else KEY_SPACE)
			_check(cleared == [true] and app.route_atlas == null, "acceptance clears atlas before disposal")
		_check(app.deck != null and app.battle_view != null and app.battle_view.is_visible_in_tree(),
			"actual input mounts routed battle")
		if app.deck == null:
			break
		_check(app.run_map.get_route() == [id] and app.route_view == null
			and app.hand_view.get_child_count() == 5 and app.deck._rng == app.run_rng,
			"exactly one route commit with real hand and shared RNG")
		var state := _snapshot(app)
		if mode == 0:
			replay = state
		else:
			_check(state == replay, "atlas matches direct graph/encounter/party/deck/enemies/RNG")
		for callback in stale:
			_inert(app, callback, id, "disposed callback cannot enter twice or alter battle")
			_inert(app, callback, "f01_n1", "disposed unsupported signal cannot alter battle")
		await _click(app.return_button)
		await process_frame
	# Failed admission must expose a usable chooser and roll back the transaction.
	await _click(app.route_button)
	var before := _snapshot(app)
	await _click(app.route_map_button)
	app.fight_encounter_paths = {}
	await _click(_marker(app, id))
	_check(app.route_atlas == null and app.route_view.is_visible_in_tree()
		and app.route_buttons[0].has_focus() and _snapshot(app) == before,
		"failed atlas startup restores exact chooser/models/RNG")
	app.fight_encounter_paths = app.FIGHT_ENCOUNTER_PATHS.duplicate()
	await _click(app.route_buttons[0])
	_check(app.deck != null and _snapshot(app) == replay, "failed atlas entry retries with identical seeded battle")
	await _click(app.return_button)
	# Same graph regenerated on the same object must invalidate a saved listener.
	await _click(app.route_button)
	await _click(app.route_map_button)
	var callback: Callable = app.route_atlas.node_requested.get_connections()[0].callable
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	_check(app.run_map.generate(rng), "same-object regeneration fixture")
	_inert(app, callback, id, "generation mismatch rejects even identical graph")
	app._return_to_title()
	await process_frame
	await _click(app.route_button)
	_inert(app, callback, id, "title reset invalidates old listener")
	await _click(app.route_map_button)
	var back_callback: Callable = app.route_atlas.node_requested.get_connections()[0].callable
	app._cancel_route()
	await process_frame
	await _click(app.route_button)
	_inert(app, back_callback, id, "Back invalidates old listener")
	app.free()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_atlas_opening_choice_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
