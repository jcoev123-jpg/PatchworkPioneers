extends RefCounted
## Explicit test-only adapter for the retired card-route regression suite.
## No production title or village action installs these legacy connections.


static func start_button(app) -> Button:
	enable(app)
	var stitched_entry := Callable(app, "_open_stitched_run_picker")
	if app.start_button.pressed.is_connected(stitched_entry):
		app.start_button.pressed.disconnect(stitched_entry)
		app.start_button.pressed.connect(app.start_run_requested.emit)
	return app.start_button


static func route_button(app) -> Button:
	enable(app)
	app.route_button.show()
	app.route_button.disabled = false
	app.route_button.focus_mode = Control.FOCUS_ALL
	app.start_button.focus_next = app.start_button.get_path_to(app.route_button)
	app.route_button.focus_next = app.route_button.get_path_to(app.base_button)
	app.route_button.focus_previous = app.route_button.get_path_to(app.start_button)
	app.base_button.focus_previous = app.base_button.get_path_to(app.route_button)
	return app.route_button


static func _legacy_village_opened(app) -> void:
	var view: BaseScreen = app.base_screen
	if not is_instance_valid(view) or not view.has_open_village():
		return
	var source: WeakRef = weakref(view)
	var live_entry: Callable = Callable(app, "_base_set_out").bind(source)
	if view.set_out_requested.is_connected(live_entry):
		view.set_out_requested.disconnect(live_entry)
	view.set_out_requested.connect(_legacy_base_set_out.bind(app, source))


static func _legacy_base_set_out(app, source: WeakRef) -> void:
	var view: BaseScreen = app._live_base(source)
	if view == null:
		return
	if app.deck != null or app.run_map != null or is_instance_valid(app.party_picker) or not view._set_out_pending:
		view.release_set_out()
		return
	app._party_opening += 1
	app.party_picker = load("res://scenes/v3_party_picker.tscn").instantiate()
	app.add_child(app.party_picker)
	app.party_picker.party_requested.connect(app._admit_base_party.bind(
		weakref(app.party_picker), app._party_opening, source))
	app.party_picker.cancel_requested.connect(app._cancel_base_party.bind(
		weakref(app.party_picker), app._party_opening, source))
	view.hide()


static func prepare(app):
	start_button(app)
	route_button(app)
	var hook := _legacy_village_opened.bind(app)
	if not app.base_button.pressed.is_connected(hook):
		app.base_button.pressed.connect(hook)
	return app


## Card-only regression adapter. Production App deliberately leaves these hooks inert.
static func enable(app):
	StitchedBedroom.enabled = false
	var start := Callable(app, "_start_run")
	if not app.start_run_requested.is_connected(start):
		app.start_run_requested.connect(start)
	var route := Callable(app, "_open_route")
	if not app.route_button.pressed.is_connected(route):
		app.route_button.pressed.connect(route)
	return app


## The old seeded screenshots remain test-only. The production web entry point
## rejects every one of these screens even on an adapter-prepared app.
const LEGACY_SCREENS := ["map", "battle", "reward", "shop", "rest", "event", "results"]


static func enter_preview(boot, app, screen: String) -> bool:
	if screen in boot.PUBLIC_SCREENS:
		return await boot.enter_preview(app, screen)
	if screen not in LEGACY_SCREENS or boot._busy or not is_instance_valid(app) \
			or not app.is_node_ready() or app.run_map != null or app.deck != null \
			or not boot._visible(app.title_view):
		return false
	prepare(app)
	boot._busy = true
	boot.preview_ready = false
	app.run_seed = {"rest": 14, "shop": 14, "event": 6}.get(screen, 1)
	app.start_button.pressed.emit()
	if is_instance_valid(app.party_picker):
		for id in ["warden", "seamstress", "tinker"]:
			app.party_picker._tiles[id].pressed.emit()
		app.party_picker.continue_button.pressed.emit()
	if app.run_map == null or not boot._visible(app.route_view):
		boot._busy = false
		return false
	app.session_gold = boot.GOLD
	app.run_scraps = boot.SCRAPS
	boot._preview_map = weakref(app.run_map)
	if screen != "map":
		var route: String = {"shop": "f01_n3", "event": "f01_n1"}.get(screen, "f01_n0")
		var steps: Array = ["f01_n2", "f02_n2"] if screen == "rest" else [route]
		for id in steps:
			for button in app.route_buttons:
				if button.get_meta("route_id") == id and not button.disabled:
					if screen == "rest" and app.run_map.get_node(id).type == "Rest":
						if not app._choose_rest_route(id, weakref(app.run_map), app.run_map.get_route(), button):
							boot._busy = false
							return false
					else:
						button.pressed.emit()
					break
	if screen in ["reward", "results"] and app.battle_result != null:
		if screen == "reward":
			for enemy in app.enemies.get_enemies():
				app.enemies.apply_damage(enemy.position, enemy.hp + enemy.block)
		else:
			for hero in app.party.get_heroes():
				app.party.apply_damage(hero.position, hero.hp + hero.block)
		app._observe_battle_result()
	if not boot._expected_view(app, screen):
		boot._busy = false
		return false
	for frame in range(2):
		await boot.get_tree().process_frame
	if not is_instance_valid(app) or not boot._expected_view(app, screen):
		boot._busy = false
		return false
	boot.preview_ready = true
	boot._busy = false
	return true
