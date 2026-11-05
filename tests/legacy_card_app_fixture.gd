extends RefCounted
## Explicit test-only adapter for the retired card-route regression suite.
## No production title or village action installs these legacy connections.


static func start_button(app) -> Button:
	var stitched_entry := Callable(app, "_open_stitched_run_picker")
	if app.start_button.pressed.is_connected(stitched_entry):
		app.start_button.pressed.disconnect(stitched_entry)
		app.start_button.pressed.connect(app.start_run_requested.emit)
	return app.start_button


static func route_button(app) -> Button:
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
