extends "res://tests/live_atlas_opening_choice_test.gd"
## Real generated routes: direct, atlas pointer and physical number-key parity.

var app
var reached: Dictionary = {}
var departed: Dictionary = {}
var used_keys: Dictionary = {}
var retained: Array[Callable] = []


func _path(map: RunMap, id: String, before: String, after: String, prefix: Array) -> Array:
	var route := prefix + [id]
	if route.size() > 1 and (after == "" or map.get_node(id).type == after) \
		and (before == "" or map.get_node(prefix.back()).type == before):
		return route
	for next in map.get_node(id).outgoing:
		var found := _path(map, next, before, after, route)
		if not found.is_empty():
			return found
	return []


func _fixture(before: String, after: String) -> Dictionary:
	for value in range(1, 40):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		_check(map.generate(rng), "fixture graph generated")
		for id in map.get_legal_choices():
			var path := _path(map, id, before, after, [])
			if not path.is_empty():
				return {"seed": value, "path": path}
	return {}


func _state() -> Array:
	return [_values(app), app.party.get_heroes() if app.party != null else [],
		app.reward_choice_panel, app.continue_button, app.route_atlas, app.route_view,
		app.fight_reward_claimed, app.fight_reward_offers.duplicate(true),
		app.fight_reward_gold, app.fight_reward_trinket]


func _frames() -> void:
	await process_frame
	await process_frame


func _physical(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		root.push_input(event, true)
		await _frames()


func _atlas_boundaries(id: String) -> Callable:
	var atlas: RunRouteAtlas = app.route_atlas
	_check(atlas != null and app.route_atlas_overlay.is_visible_in_tree(), "mounted connected atlas exists")
	var callback: Callable = atlas.node_requested.get_connections()[0].callable
	_inert(app, callback, "forged-node", "forged atlas request conserves state and focus")
	var before := _state()
	var overlay: Control = app.route_atlas_overlay
	overlay.hide()
	callback.call(id)
	_check(_state() == before, "hidden atlas cannot commit")
	overlay.show()
	app.remove_child(overlay)
	callback.call(id)
	_check(_state() == before, "detached atlas cannot commit")
	app.add_child(overlay)
	var route: Array[String] = app.run_map.get_route()
	_check(app.run_map.choose_node(id), "external legal advancement fixture")
	var advanced := _state()
	callback.call(id)
	_check(_state() == advanced, "stale atlas route prefix cannot commit")
	_check(app.run_map.undo_choice(id, route), "restore legal route prefix")
	for floor in app.run_map.get_floors():
		for node in floor:
			var marker := atlas.get_node_or_null("Node_" + node.id) as Control
			_check(marker != null and Rect2(0, 0, 1280, 720).encloses(marker.get_global_rect()),
				"every atlas marker fits viewport")
			var action := marker.get_node_or_null("Action") as Button if marker != null else null
			_check((action != null) == app.run_map.get_legal_choices().has(node.id),
				"atlas enables exactly legal route nodes")
	return callback


func _enter_node(id: String, mode: int) -> void:
	_check(app.route_view != null and app.route_view.is_visible_in_tree(), "real chooser mounted before input")
	if mode == 0:
		await _click(_button(app, id))
		return
	var prior: Array[String] = app.run_map.get_route()
	var rng_before: int = app.run_rng.state
	await _click(app.route_map_button)
	_check(app.run_rng.state == rng_before and app.run_map.get_route() == prior, "mounting atlas draws no RNG")
	var callback := _atlas_boundaries(id)
	if mode == 1:
		await _click(app.route_atlas_close)
		_check(app.route_map_button.has_focus() and app.route_view.is_visible_in_tree(), "Close restores chooser focus")
		_inert(app, callback, id, "closed overlay callback is inert")
		await _click(app.route_map_button)
		callback = app.route_atlas.node_requested.get_connections()[0].callable
		await _click(_marker(app, id))
	else:
		var index: int = app.route_atlas._rendered_shortcuts.find(id)
		_check(index >= 0 and index < 4, "physical shortcut corresponds to requested legal node")
		used_keys[index + 1] = true
		await _physical((KEY_1 + index) as Key)
	_check(app.run_map.get_route() == prior + [id] and app.route_atlas == null, "one atlas input commits exactly its legal node")
	var before := _state()
	callback.call(id)
	_check(_state() == before, "removed atlas listener cannot activate twice")
	retained.append(callback.bind(id))


func _reward_boundaries() -> void:
	var panel: LiveRunCardRewardChoicePanel = app.reward_choice_panel
	_check(panel != null and panel.has_open_rewards() and panel.get_choice_buttons().size() == 4,
		"witnessed victory mounts authored three-card panel and Skip")
	var service = app._routed_reward_service()
	var request: Callable = panel.choice_requested.get_connections()[0].callable
	var button: Button = panel.get_choice_buttons()[0]
	var callback: Callable = button.pressed.get_connections()[0].callable
	var before := _state()
	request.call(app._carryover_node, app.fight_reward_offers[0].id)
	app._claim_card_reward(app.fight_reward_offers[0].id, button, service)
	_check(_state() == before and not panel._awaiting_ack, "forged panel signal and stale inline adapter cannot pay")
	panel.hide()
	callback.call()
	_check(_state() == before, "hidden reward callback cannot mutate")
	panel.show()
	app.remove_child(panel)
	callback.call()
	_check(_state() == before, "detached reward callback cannot mutate")
	app.add_child(panel)
	# Genuine view request, rejected by the existing settlement witness; then retry.
	app.session_gold += 1
	var drift := _state()
	await _click(button)
	_check(_state() == drift and not panel._awaiting_ack and not panel._accepted
		and panel.get_choice_buttons().all(func(action: Button) -> bool: return not action.disabled),
		"rejected request acknowledges without payment and enables retry")
	app.session_gold -= 1
	_check(_state() == before, "rejected request preserves exact prepared receipt and RNG")
	retained.append(callback)
	retained.append(request.bind(app._carryover_node, app.fight_reward_offers[0].id))


func _complete_node(kind: String, mode: int, step: int) -> void:
	match kind:
		"Fight", "Elite", "Boss":
			_check(app.battle_result.get_outcome() == CombatBattleResult.ACTIVE and app.deck.turn_active,
				"connected route publishes real active battle")
			for enemy in app.enemies.get_enemies():
				_check(app.enemies.apply_damage(enemy.position, 9999), "defeat each real mounted enemy")
			app._observe_battle_result()
			await _frames()
			if kind == "Boss":
				_check(app.terminal_result_panel != null and app.reward_choice_panel == null
					and app.reward_buttons.is_empty(), "Boss victory retains sole terminal panel and grants no rewards")
				return
			await _reward_boundaries()
			var panel: LiveRunCardRewardChoicePanel = app.reward_choice_panel
			var receipt: Dictionary = panel._receipt.duplicate(true)
			_check(receipt.offers == app.fight_reward_offers and receipt.gold_award == app.fight_reward_gold,
				"panel presents exact cached receipt")
			for index in range(3):
				var button: Button = panel.get_choice_buttons()[index]
				var def: Dictionary = RunPoolCardRewardOffers.resolve_reward_definition(receipt.offers[index].id)
				_check(button.get_parent().get_node("NameLabel").text == def.get("display_name", "") and button.get_parent().get_node("RarityLabel").text == def.get("rarity", "").capitalize()
					and Rect2(0, 0, 1280, 720).encloses(button.get_global_rect()), "prepared card is visible inside viewport")
			var gold: int = app.session_gold
			var scraps: int = app.run_scraps
			var owned: Array = app.run_deck.duplicate()
			var inventory: Array = app.run_trinkets.duplicate()
			var index := 0 if step % 2 == 0 else 3
			if index == 0:
				owned.append(receipt.offers[0].id)
			if mode == 2:
				panel.get_choice_buttons()[index].grab_focus()
				await _key(KEY_ENTER)
			else:
				await _click(panel.get_choice_buttons()[index])
			if kind == "Elite":
				inventory.append(receipt.trinket_drop_id)
			_check(app.fight_reward_claimed and panel._accepted and not panel._awaiting_ack
				and app.run_deck == owned and app.session_gold == gold + receipt.gold_award
				and app.run_trinkets == inventory and app.run_scraps == scraps + (2 if kind == "Elite" else 1),
				"mounted pick/Skip pays exact card, gold, trinket and scraps once")
			var settled := _state()
			for callback in retained:
				callback.call()
			_check(_state() == settled, "paid and old callbacks conserve complete settlement")
			await _click(app.continue_button)
			_check(app.reward_choice_panel == null and app.reward_buttons.is_empty(), "Continue clears reward bindings")
		"Rest":
			await _click(app.rest_heal_button)
			await _click(app.rest_continue_button)
		"Shop":
			await _click(app.shop_continue_button)
		"Event":
			if is_instance_valid(app.quiet_spool_panel):
				_check(app.route_view == null and not app._can_choose_connected_route(),
					"pending Event blocks connected atlas until choice")
				var scraps: int = app.run_scraps
				var ignore: Button = app.quiet_spool_panel.get_choice_buttons()[1]
				if mode == 2:
					ignore.grab_focus()
					await _key(KEY_SPACE)
				else:
					await _click(ignore)
				_check(app.run_scraps == scraps and app.quiet_spool_panel == null,
					"Ignore completes Event without changing scraps")
	departed[kind] = true
	_check(app.route_view != null and app.route_view.is_visible_in_tree(), "completed node exposes connected atlas entry")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	await _four_keys()
	var fixtures: Array = []
	for kind in ["Fight", "Elite", "Rest", "Shop", "Event", "Treasure", "Boss"]:
		fixtures.append(_fixture("", kind))
	for kind in ["Fight", "Rest", "Shop", "Event", "Treasure"]:
		fixtures.append(_fixture(kind, ""))
	for fixture in fixtures:
		_check(not fixture.is_empty(), "concrete generated connected fixture exists")
		if fixture.is_empty():
			continue
		var replay: Array = []
		for mode in range(3):
			app.run_seed = fixture.seed
			await _click(app.start_button)
			var observations: Array = []
			for step in range(fixture.path.size()):
				var id: String = fixture.path[step]
				var kind: String = app.run_map.get_node(id).type
				await _enter_node(id, mode)
				if step > 0:
					reached[kind] = true
				observations.append(_values(app))
				await _complete_node(kind, mode, step)
				observations.append(_values(app))
			if mode == 0:
				replay = observations.duplicate(true)
			else:
				_check(observations == replay, "atlas pointer/physical key replay equals direct route, deck, party, offers and uninterrupted RNG")
			if app.terminal_result_panel != null:
				await _click(app.terminal_result_panel.return_button)
			else:
				await _click(app.route_back_button)
			for callback in retained:
				callback.call()
			_check(app.run_map == null and app.reward_choice_panel == null and app.title_view.visible,
				"Return clears bindings; retained callbacks cannot revive session")
	for kind in ["Fight", "Elite", "Boss", "Rest", "Shop", "Event", "Treasure"]:
		_check(reached.has(kind), "actually entered connected " + kind)
	for kind in ["Fight", "Rest", "Shop", "Event", "Treasure"]:
		_check(departed.has(kind), "actually completed predecessor " + kind)
	for number in range(1, 5):
		_check(used_keys.has(number), "actually exercised physical key " + str(number))
	app.free()
	for failure in failures:
		printerr(failure)
	print("live_routed_ui_boundaries_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks; physical keys ", used_keys.keys(), ")")
	quit(0 if failures.is_empty() else 1)


func _four_keys() -> void:
	var value := 1
	var map := RunMap.new()
	while value < 100:
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		map.generate(rng)
		if map.get_legal_choices().size() == 4:
			break
		value += 1
	_check(value < 100, "concrete four-opening fixture found")
	if value >= 100:
		return
	for id in map.get_legal_choices():
		var replay: Array = []
		for mode in [0, 2]:
			app.run_seed = value
			await _click(app.start_button)
			await _enter_node(id, mode)
			if mode == 0:
				replay = _values(app)
			else:
				_check(_values(app) == replay, "each physical key exactly matches corresponding opening route control")
			await _leave_flow(app, map.get_node(id).type)
