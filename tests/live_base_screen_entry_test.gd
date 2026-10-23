extends SceneTree
## Cycle 151: the pinned Quilt village base between the title and a run.
## Proves the third sewn title action opens a full-screen Base with no run
## allocation, that Set out opens the existing seeded opening chooser exactly
## like direct "Choose a route", and that stale/hidden Base signals are inert.

const APP_SCENE := "res://scenes/app.tscn"
const BASE_SCENE := "res://scenes/base_screen.tscn"
const STARTER_DECK_PATH := "res://data/cards/starter_deck.json"
const BASE_BACKDROP := "res://assets/paper/backgrounds/base_village.png"

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		root.push_input(event, true)
		await process_frame


func _click(button: Button) -> void:
	_check(is_instance_valid(button) and button.is_visible_in_tree(), "mouse target is mounted")
	if not is_instance_valid(button):
		return
	var point := button.get_global_rect().get_center()
	_check(root.get_visible_rect().has_point(point), "mouse target inside viewport")
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
		await process_frame


## Everything the title state owns; opening and leaving the Base must not touch it.
func _title_snapshot(app) -> Array:
	return [app.run_seed, app.session_gold, app.run_scraps, app.run_deck.duplicate(),
		app.run_heroes.duplicate(true), app.run_map, app.deck, app.run_rng,
		app.fight_selection, app.encounter_id, app.party_carryover]


## The seeded opening-route model shared by both entry paths.
func _route_snapshot(app) -> Array:
	var state: Array = [app.run_seed, app.session_gold, app.run_scraps, app.run_deck.duplicate(),
		app.run_heroes.duplicate(true), app.run_map.get_generation_revision(),
		app.run_map.get_floors(), app.run_map.get_route(), app.run_map.get_legal_choices(),
		app.run_rng.state, app.party_carryover.read_state(), app.deck, app.encounter_id]
	for button in app.route_buttons:
		state.append([button.get_meta("route_id"), button.text, button.disabled])
	state.append([app.route_back_button.text, app.route_map_button.text])
	return state


## The app's own signal handler, captured so an old Base can try to replay it.
func _app_binding(app, source: Signal) -> Callable:
	for connection in source.get_connections():
		var callable: Callable = connection.callable
		if callable.get_object() == app:
			return callable
	return Callable()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := load(APP_SCENE) as PackedScene
	_check(scene != null, "real app scene loads")
	var base_scene := load(BASE_SCENE) as PackedScene
	_check(base_scene != null, "real Base scene loads")
	if scene == null or base_scene == null:
		_finish()
		return
	var app = scene.instantiate()
	root.add_child(app)
	await process_frame

	# --- AC1: a third focused, stitched title action and a run-free Base ------
	_check(app.title_view.is_visible_in_tree() and app.start_button.has_focus(),
		"ordinary title boot keeps its own focus")
	var title_children: Array = app.title_view.get_children()
	_check(is_instance_valid(app.base_button) and app.base_button.is_visible_in_tree()
		and app.base_button.text == "Quilt village", "third title action is the Quilt village")
	_check(title_children.find(app.base_button) == title_children.find(app.route_button) + 1,
		"Quilt village follows Choose a route")
	_check(app.base_button.get_child_count() == 1
		and app.base_button.get_child(0).mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"village action is sewn, never a bare control")
	var focus_style := app.base_button.get_theme_stylebox("focus") as StyleBoxFlat
	_check(focus_style != null and focus_style.border_width_top >= 3
		and focus_style.border_color.a == 1.0, "village action shows an opaque keyboard focus ring")
	var pristine := _title_snapshot(app)
	seed(151151)
	var expected_global := randi()
	seed(151151)
	await _key(KEY_TAB)
	_check(app.route_button.has_focus(), "Tab still reaches Choose a route first")
	await _key(KEY_TAB)
	_check(app.base_button.has_focus(), "physical Tab reaches Quilt village")
	await _key(KEY_ENTER)
	_check(is_instance_valid(app.base_screen) and app.base_screen.is_visible_in_tree(),
		"physical Enter opens a full-screen Base")
	if not is_instance_valid(app.base_screen):
		app.free()
		_finish()
		return
	var view: BaseScreen = app.base_screen
	_check(view.has_open_village(), "Base reports its open village state")
	_check(_title_snapshot(app) == pristine and app.run_map == null and app.deck == null
		and app.run_rng == null and app.run_deck.is_empty() and app.run_heroes.is_empty()
		and app.session_gold == 0 and app.run_scraps == 0 and app.fight_selection == null,
		"Base allocates no run, RNG, deck, heroes or currency")
	_check(not app.title_view.is_visible_in_tree(), "Base replaces the title")
	_check(randi() == expected_global, "opening the Base spends no global RNG")
	var viewport := Rect2(Vector2.ZERO, Vector2(1280, 720))
	_check(view.get_global_rect().encloses(viewport), "Base covers the whole 1280x720 screen")
	_check(view.set_out_button.is_visible_in_tree() and view.set_out_button.has_focus()
		and view.set_out_button.text == "Set out", "Set out is mounted and focused")
	_check(view.back_button.is_visible_in_tree() and view.back_button.text == "Back to title",
		"Back to title is mounted")
	_check(view.set_out_button.get_child_count() == 1 and view.back_button.get_child_count() == 1
		and view.set_out_button.get_child(0).mouse_filter == Control.MOUSE_FILTER_IGNORE
		and view.back_button.get_child(0).mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"both Base actions are sewn, keyboard-reachable controls")
	# Visible village: houses and tents with pinned names, a central spool, stitched paths.
	var buildings: Array = view.village_buildings()
	var labels: Array[String] = []
	var kinds: Array[String] = []
	for building in buildings:
		labels.append(String(building.get("label", "")))
		kinds.append(String(building.get("kind", "")))
		var rect: Rect2 = building.get("rect", Rect2())
		_check(rect.size.x > 0.0 and rect.size.y > 0.0
			and Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(rect),
			"drawn building stays on the quilt: " + String(building.get("label", "")))
	_check(buildings.size() >= 4 and labels.has("Heroes") and labels.has("Camp")
		and kinds.has("house") and kinds.has("tent"), "houses and tents are drawn and named")
	var spool: Rect2 = view.village_spool()
	_check(spool.size.x > 0.0 and spool.size.y > 0.0
		and absf(spool.get_center().x - 640.0) < 1.0, "central spool sits mid-village")
	var paths: Array = view.village_paths()
	_check(paths.size() >= 2, "stitched paths join the village")
	for path in paths:
		_check((path as PackedVector2Array).size() >= 2, "path is a real stitched link")
	# Optional owner image: loader is gated and cover math keeps proportions.
	_check(view.backdrop_path() == BASE_BACKDROP, "owner village backdrop path is authored")
	_check(BaseScreen.load_base_backdrop("res://assets/paper/backgrounds/fabricated_missing_village.png") == null
		and BaseScreen.load_base_backdrop("") == null,
		"a missing village image loads no texture and cannot fail boot")
	var probe := ImageTexture.create_from_image(Image.create_empty(400, 300, false, Image.FORMAT_RGBA8))
	var cover: Rect2 = view.cover_rect_for(probe)
	_check(cover.encloses(viewport), "a supplied village image covers the whole screen")
	_check(is_equal_approx(cover.size.x / cover.size.y, 400.0 / 300.0),
		"a supplied village image keeps its own proportions")
	if view.has_backdrop_texture():
		_check(view.backdrop_texture() is Texture2D and view.backdrop_rect().encloses(viewport),
			"the mounted village image is drawn as a cover")
	# Real keyboard focus cycle between the two sewn actions.
	await _key(KEY_TAB)
	_check(view.back_button.has_focus(), "Tab reaches Back to title")
	await _key(KEY_TAB)
	_check(view.set_out_button.has_focus(), "Tab wraps back to Set out")
	seed(151152)
	var back_global := randi()
	seed(151152)
	await _click(view.back_button)
	await process_frame
	_check(app.base_screen == null and not is_instance_valid(app.base_screen)
		and app.title_view.is_visible_in_tree() and app.base_button.has_focus(),
		"mouse Back restores the title and the village action focus")
	_check(_title_snapshot(app) == pristine, "Back spends no run, RNG, deck or currency")
	_check(randi() == back_global, "closing the Base spends no global RNG")

	# --- AC2: invalid Set out creates nothing and keeps the Base usable ------
	await _click(app.base_button)
	_check(is_instance_valid(app.base_screen) and app.base_screen.is_visible_in_tree(),
		"mouse opens the village again")
	view = app.base_screen
	var invalid_before := _title_snapshot(app)
	app.starter_deck_path = "res://missing-base-village-deck.json"
	await _click(view.set_out_button)
	_check(app.run_map == null and app.deck == null and app.run_rng == null
		and _title_snapshot(app) == invalid_before, "invalid Set out creates no run or RNG")
	_check(app.base_screen == view and view.is_visible_in_tree()
		and not view.set_out_button.disabled and not view.back_button.disabled,
		"failed Set out leaves the Base open and actionable")
	app.starter_deck_path = STARTER_DECK_PATH

	# --- AC2: Set out opens the real seeded chooser exactly like the title ---
	var stale_binding := _app_binding(app, view.set_out_requested)
	_check(stale_binding.is_valid(), "the app really handles the Base Set out signal")
	await _click(view.set_out_button)
	_check(is_instance_valid(app.route_view) and app.route_view.is_visible_in_tree(),
		"Set out opens the opening-route chooser")
	_check(app.base_screen == null, "Base hides only after the route was created")
	_check(app.deck == null and app.run_map != null and app.run_map.get_route().is_empty()
		and app.run_map.get_generation_revision() == 1,
		"exactly one seeded map with no combat or committed node")
	var base_route := _route_snapshot(app)
	_check(app.run_deck == StarterCards.new().get_starting_deck() and app.run_heroes.size() == 3
		and app.session_gold == 0 and app.run_scraps == 0 and app.run_seed == 42,
		"Base preserves the authored deck, three heroes, seed and currency")
	_check(app.route_buttons.size() == app.run_map.get_legal_choices().size(),
		"one mounted action per legal opening")
	_check(is_instance_valid(app.route_book_backdrop) and app.route_book_backdrop.is_visible_in_tree()
		and app.route_book_backdrop.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"Set out mounts the book-backed opening chooser")
	for button in app.route_buttons:
		var id: String = button.get_meta("route_id")
		_check(app.run_map.get_legal_choices().has(id)
			and app.run_map.get_node(id).get("type") == button.get_meta("route_kind")
			and button.text.begins_with(String(button.get_meta("route_kind")))
			and not button.text.contains(id) and button.is_visible_in_tree(),
			"legal mounted opening type label: " + id)
	# A replayed Base callback cannot replace or re-open the live chooser.
	var chooser_before := _route_snapshot(app)
	stale_binding.call()
	_check(_route_snapshot(app) == chooser_before and app.route_view.is_visible_in_tree(),
		"replayed freed Base Set out cannot overwrite the run")
	# Back from a Base-launched, uncommitted chooser returns to the village.
	app.route_back_button.grab_focus()
	await _key(KEY_ENTER)
	await process_frame
	_check(is_instance_valid(app.base_screen) and app.base_screen.is_visible_in_tree()
		and app.base_screen.has_open_village() and not app.title_view.is_visible_in_tree(),
		"keyboard Back from the Base-launched chooser restores the Quilt village")
	_check(app.run_map == null and app.run_rng == null and app.run_deck.is_empty()
		and app.party_carryover == null and app.route_view == null and app.deck == null
		and app.route_book_backdrop == null,
		"restored Base releases the whole opening model")
	_check(_title_snapshot(app) == pristine, "restored Base spends nothing")
	view = app.base_screen
	_check(view.set_out_button.has_focus(), "restored Base focuses Set out again")

	# --- AC2: a hidden Base callback is inert and cannot start a run ---------
	var hidden_binding := _app_binding(app, view.set_out_requested)
	_check(hidden_binding.is_valid(), "restored Base has exactly the app handler")
	view.hide()
	hidden_binding.call()
	view.set_out_button.pressed.emit()
	_check(app.run_map == null and app.deck == null and app.route_view == null
		and app.base_screen == view, "hidden Base signals cannot create a run")
	view.show()
	_check(not view.set_out_button.disabled, "shown Base stays actionable after the probe")
	await _click(view.back_button)
	_check(app.base_screen == null and app.title_view.is_visible_in_tree(),
		"Back to title closes the village")

	# --- AC2: direct Choose a route is unchanged and seeded identically ------
	await _click(app.route_button)
	_check(is_instance_valid(app.route_view) and app.run_map != null,
		"direct Choose a route still opens the chooser")
	var direct_route := _route_snapshot(app)
	_check(direct_route == base_route,
		"Base Set out and direct Choose a route share the exact seeded model")
	_check(app.run_map.get_generation_revision() == 1 and app.run_rng != null,
		"direct route allocates one map and one run RNG")
	await _click(app.route_back_button)
	await process_frame
	_check(app.run_map == null and app.run_rng == null and app.deck == null
		and app.title_view.is_visible_in_tree() and app.start_button.has_focus(),
		"direct route Back still returns to the title, never to the Base")
	_check(app.base_screen == null and _title_snapshot(app) == pristine,
		"direct route Back spends nothing")

	app.free()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_base_screen_entry_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
