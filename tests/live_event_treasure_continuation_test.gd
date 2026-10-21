extends "res://tests/live_shop_continuation_test.gd"
## Real won Fight, optional completed visit, then repeated no-effect placeholders.


func _find_path(map: RunMap, choices: Array, kinds: Array) -> Array:
	if kinds.is_empty():
		return []
	for id in choices:
		var node := map.get_node(id)
		if node.type != kinds[0]:
			continue
		if kinds.size() == 1:
			return [id]
		var tail := _find_path(map, node.outgoing, kinds.slice(1))
		if not tail.is_empty():
			return [id] + tail
	return []


func _placeholder_fixture(visit: String, kind: String) -> Dictionary:
	var kinds: Array = ["Fight"]
	if not visit.is_empty():
		kinds.append(visit)
	kinds.append_array([kind, kind, "Rest" if kind == "Event" else "Shop"])
	for value in range(1, 30000):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		var path := _find_path(map, map.get_legal_choices(), kinds)
		if path.is_empty():
			continue
		map.choose_node(path[0])
		var selected := RunAuthoredBattleEntry.new().entry_current_battle(map, rng, RunFightEncounterSelection.new())
		if selected.get("encounter_id") == "starter_attacks":
			return {"seed": value, "fight": path[0], "path": path.slice(1)}
	return {}


func _effects() -> Array:
	var state := _persistent()
	state.remove_at(4) # Route is the sole intended model change.
	return [state, app.run_removal_count,
		app.party_carryover.read_state(),
		app.shop_visit.get_state() if app.shop_visit != null else {},
		app.shop_purchases.get_state() if app.shop_purchases != null else {},
		app.shop_purchases.get_stock() if app.shop_purchases != null else {}]


func _placeholder_state() -> Array:
	return [_effects(), app.run_map.get_floors(), app.run_map.get_route(),
		app.route_view, app.route_buttons.duplicate(), app._placeholder_route.duplicate()]


func _reject_placeholder(callback: Callable, reason: String) -> void:
	var before := _placeholder_state()
	callback.call()
	_check(_placeholder_state() == before, reason + " preserves models, graph, route, chooser and RNG")


func _check_chooser() -> void:
	_check(is_instance_valid(app.route_view), "connected chooser is mounted")
	if not is_instance_valid(app.route_view):
		return
	_bounds(app.route_view)
	var shown: Array[String] = []
	for button in app.route_buttons:
		var id: String = button.get_meta("route_id")
		shown.append(id)
		var kind: String = app.run_map.get_node(id).type
		_check(button.is_visible_in_tree() and button.disabled == (kind not in ["Rest", "Shop", "Event", "Treasure", "Fight", "Elite", "Boss"]), "exact supported successor types actionable")
		if button.disabled:
			var before := _placeholder_state()
			await _click(button)
			button.grab_focus()
			await _key(KEY_ENTER)
			button.pressed.emit()
			_check(_placeholder_state() == before, "unsupported combat physical and signal inputs inert")
	_check(shown == app.run_map.get_legal_choices(), "exact actual successor IDs in order")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	for visit in ["", "Rest", "Shop"]:
		for kind in ["Event", "Treasure"]:
			var fixture := _placeholder_fixture(visit, kind)
			_check(not fixture.is_empty(), "seeded real Fight -> " + visit + " -> repeated " + kind)
			if fixture.is_empty():
				continue
			var replay: Array = []
			for session in range(2):
				seed(670067)
				var global_next := randi()
				seed(670067)
				if not await _routed_win(fixture, false):
					break
				if visit.is_empty():
					# Even a mounted chooser cannot bypass the real Fight reward gate.
					app._present_connected_route(weakref(app.run_map))
					var premature := _route_action(fixture.path[0])
					if premature != null:
						_reject_placeholder(premature.pressed.get_connections()[0].callable, "unclaimed Fight reward")
					app._clear_route_view()
				await _click(app.reward_buttons[0])
				_check(app.fight_reward_claimed, "real reward is claimed")
				await _click(app.continue_button)
				var path: Array = fixture.path.duplicate()
				if not visit.is_empty():
					var entry := _route_action(path.pop_front())
					if entry == null:
						break
					await _click(entry)
					# Forge presentation only; the still-open visit must reject traversal.
					app._present_connected_route(weakref(app.run_map))
					var premature := _route_action(path[0])
					if premature != null:
						_reject_placeholder(premature.pressed.get_connections()[0].callable, "unfinished " + visit)
					app._clear_route_view()
					if visit == "Rest":
						_check(app.rest_recovery != null and app.rest_continue_button.disabled, "real Rest requires completion")
						await _click(app.rest_heal_button)
						_check(app.rest_recovery.is_consumed(), "real Rest healed")
						await _click(app.rest_continue_button)
					else:
						_check(app.shop_visit != null, "real Shop visit mounted")
						await _click(app.shop_continue_button)
						_check(app.shop_visit.get_state().status == "closed", "real Shop closed")
				var stale: Array[Callable] = []
				var timeline: Array = []
				var final_visit: String = path.pop_back()
				for id in path:
					await _check_chooser()
					for callback in stale:
						_reject_placeholder(callback, "replayed prior placeholder")
					var button := _route_action(id)
					if button == null:
						break
					var map: RunMap = app.run_map
					var prior: Array[String] = map.get_route()
					var callback: Callable = button.pressed.get_connections()[0].callable
					_reject_placeholder(app._choose_placeholder_route.bind(id, weakref(RunMap.new()), prior, button), "foreign map")
					var empty: Array[String] = []
					_reject_placeholder(app._choose_placeholder_route.bind(id, weakref(map), empty, button), "foreign route")
					_reject_placeholder(app._choose_placeholder_route.bind(id, weakref(map), prior, app.route_back_button), "forged control")
					_reject_placeholder(app._choose_placeholder_route.bind(prior[0], weakref(map), prior, button), "nonadjacent ID")
					var edges: Array = map._nodes[prior.back()].outgoing.duplicate()
					map._nodes[prior.back()].outgoing.erase(id)
					_reject_placeholder(callback, "removed legal edge")
					map._nodes[prior.back()].outgoing = edges
					map._nodes[id].type = "Fight"
					_reject_placeholder(callback, "unsupported node type")
					map._nodes[id].type = kind
					button.disabled = true
					_reject_placeholder(callback, "disabled control")
					button.disabled = false
					button.hide()
					_reject_placeholder(callback, "hidden control")
					button.show()
					var heroes: Array = app.run_heroes
					app.run_heroes = []
					_reject_placeholder(callback, "invalid run roster")
					app.run_heroes = heroes
					var before := _effects()
					var old_view: Control = app.route_view
					if session == 0:
						await _click(button)
					else:
						button.grab_focus()
						await _key(KEY_SPACE if kind == "Event" else KEY_ENTER)
					_check(map.get_route() == prior + [id], "one legal input advances exactly chosen node")
					_check(_effects() == before, "placeholder changes no actors, resources, services or RNG")
					_check(not is_instance_valid(old_view), "previous chooser freed")
					_reject_placeholder(callback, "duplicate click")
					stale.append(callback)
					await _check_chooser()
					timeline.append([_effects(), map.get_route(), map.get_legal_choices()])
				_check(timeline.size() == 2, "both repeated placeholders exercised")
				var next := _route_action(final_visit)
				if next != null:
					await _click(next)
					_check(app.run_map.get_current_node_id() == final_visit, "completed placeholder admits next real visit")
					if kind == "Event":
						_check(app.rest_view.is_visible_in_tree() and not app.rest_recovery.is_consumed(), "Rest after placeholder is fresh")
						await _click(app.rest_heal_button)
						await _click(app.rest_continue_button)
					else:
						_check(app.shop_view.is_visible_in_tree() and app.shop_visit.get_state().status == "available", "Shop after placeholder is fresh")
						await _click(app.shop_continue_button)
					timeline.append([_effects(), app.run_map.get_route(), app.run_map.get_legal_choices()])
				if session == 0:
					replay = timeline
				else:
					_check(timeline == replay, "same-seed mouse/keyboard successor and state replay")
				_check(randi() == global_next, "real route consumes no global RNG")
				await _click(app.route_back_button)
				_check(app.title_view.visible and app.run_map == null and app._placeholder_route.is_empty() and app._placeholder_map == null, "title clears placeholder completion")
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_event_treasure_continuation_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
