extends SceneTree
## Cycle 151: the pinned Quilt village base between the title and a run.
## Proves the third sewn title action opens a full-screen Base with no run
## allocation, that Set out opens the existing seeded opening chooser exactly
## like direct "Choose a route", and that stale/hidden Base signals are inert.

const APP_SCENE := "res://scenes/app.tscn"
const BASE_SCENE := "res://scenes/base_screen.tscn"
const STARTER_DECK_PATH := "res://data/cards/starter_deck.json"
const SEAMSTRESS_PATHS_PATH := "res://data/heroes/seamstress_paths.json"
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


## Authored JSON numbers arrive as floats; a validated receipt normalizes them.
func _norm(value: Variant) -> Variant:
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		if is_finite(number) and floor(number) == number:
			return int(number)
		return value
	if value is Array:
		var out_list: Array = []
		for item in value:
			out_list.append(_norm(item))
		return out_list
	if value is Dictionary:
		var out_dict: Dictionary = {}
		for key in value:
			out_dict[key] = _norm(value[key])
		return out_dict
	return value


## The exact authored Path record, read here independently of the run service.
func _authored_path(path_id: String) -> Dictionary:
	if not FileAccess.file_exists(SEAMSTRESS_PATHS_PATH):
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(SEAMSTRESS_PATHS_PATH)) != OK:
		return {}
	if not parser.data is Array:
		return {}
	for record in parser.data:
		if record is Dictionary and String(record.get("id", "")) == path_id:
			return _norm(record)
	return {}


## The receipt one Path must produce: its authored record plus the canonical
## twelve-card starter deck with exactly that Path card appended.
func _expected_receipt(path_id: String) -> Dictionary:
	var authored := _authored_path(path_id)
	var card: Dictionary = authored.get("card", {})
	var deck: Array = []
	for card_id in StarterCards.new().get_starting_deck():
		deck.append(card_id)
	deck.append(String(card.get("id", "")))
	return {
		"ok": true,
		"owner": "seamstress",
		"path_id": path_id,
		"display_name": String(authored.get("display_name", "")),
		"passive": authored.get("passive", {}),
		"card": card,
		"deck": deck,
	}


## An independent seed-42 opening: state generated without the app.
func _seeded_oracle() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var generated := RunMap.new()
	generated.generate(rng)
	return [rng.state, generated.get_floors(), generated.get_route(), generated.get_legal_choices()]


## The Path button for one authored ID, or null.
func _path_button(view: BaseScreen, path_id: String) -> Button:
	for button in view.path_buttons:
		if is_instance_valid(button) and String(button.get_meta("path_id", "")) == path_id:
			return button
	return null


## Physically Tab to one authored Path option and confirm it with Enter.
func _key_select_path(view: BaseScreen, path_id: String) -> void:
	var target := _path_button(view, path_id)
	_check(target != null, "keyboard Path option is mounted: " + path_id)
	if target == null:
		return
	for attempt in range(view.path_buttons.size() + 4):
		if target.has_focus():
			break
		await _key(KEY_TAB)
	_check(target.has_focus(), "physical Tab reaches the Path option: " + path_id)
	if not target.has_focus():
		return
	await _key(KEY_ENTER)


## Click one authored Path option with the mouse.
func _mouse_select_path(view: BaseScreen, path_id: String) -> void:
	var target := _path_button(view, path_id)
	_check(target != null, "mouse Path option is mounted: " + path_id)
	if target == null:
		return
	await _click(target)


## Everything the title state owns; opening and leaving the Base must not touch it.
func _title_snapshot(app) -> Array:
	return [app.run_seed, app.session_gold, app.run_scraps, app.run_deck.duplicate(),
		app.run_heroes.duplicate(true), app.run_map, app.deck, app.run_rng,
		app.fight_selection, app.encounter_id, app.party_carryover,
		app.run_seamstress_path_receipt.duplicate(true),
		app.run_tinker_path_receipt.duplicate(true)]


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


## A whole fresh app session for one authored Path: real title action, real
## village pick (mouse or keyboard), real Set out and the real opening book.
func _fresh_path_run(path_id: String, use_mouse: bool, enter_fight: bool) -> void:
	var scene := load(APP_SCENE) as PackedScene
	var app = scene.instantiate()
	root.add_child(app)
	await process_frame
	var expected := _expected_receipt(path_id)
	var other_id := "unpicker" if path_id == "bloodline" else "bloodline"
	var card_id := String((expected["card"] as Dictionary).get("id", ""))
	var starter: Array[String] = StarterCards.new().get_starting_deck()
	_check(not _authored_path(path_id).is_empty() and not (expected["card"] as Dictionary).is_empty()
		and not card_id.is_empty() and app.run_seamstress_path_receipt.is_empty()
		and app.title_view.is_visible_in_tree(),
		"authored Path record is readable and the session boots clean: " + path_id)

	await _click(app.base_button)
	_check(is_instance_valid(app.base_screen) and app.base_screen.has_open_village(),
		"fresh session opens the real village: " + path_id)
	if not is_instance_valid(app.base_screen):
		app.free()
		return
	var view: BaseScreen = app.base_screen
	var shown: Array = view.path_options()
	_check(shown.size() == 2 and String(shown[0].get("id", "")) == "bloodline"
		and String(shown[1].get("id", "")) == "unpicker",
		"both authored Paths are offered in authored order")
	for index in range(shown.size()):
		var option: Dictionary = shown[index]
		var authored := _authored_path(String(option.get("id", "")))
		_check(String(option.get("display_name", "")) == String(authored.get("display_name", ""))
			and not String(option.get("display_name", "")).is_empty()
			and String(view.path_buttons[index].text) == String(option.get("display_name", "")),
			"village Path option shows its authored name: " + String(option.get("id", "")))
	_check(app.run_seamstress_path_choice != null and app.run_seamstress_path_choice.is_valid()
		and not app.run_seamstress_path_choice.is_claimed(),
		"the village holds one unclaimed run-setup Path choice")
	var stale: Callable = _app_binding(app, view.path_choice_requested)
	_check(stale.is_valid(), "the app really handles the Base Path signal")

	# Unknown admissions are rejected before any claim and spend no RNG at all.
	seed(166166)
	var expected_global := randi()
	seed(166166)
	for unknown in ["not_an_authored_path", "", "bloodline\n"]:
		stale.call(unknown)
		_check(view.selected_path_id() == "" and app.run_seamstress_path_receipt.is_empty()
			and not app.run_seamstress_path_choice.is_claimed()
			and not view.path_buttons[0].disabled and not view.path_buttons[1].disabled,
			"unknown Path request is refused and claims nothing: " + str(unknown))
	_check(randi() == expected_global, "refused Path requests spend no global RNG")

	if use_mouse:
		await _mouse_select_path(view, path_id)
	else:
		await _key_select_path(view, path_id)
	_check(view.selected_path_id() == path_id
		and view.selected_path_name() == String(expected["display_name"]),
		"the village shows the actual selected Path: " + path_id)
	_check(view.path_status_label.is_visible_in_tree()
		and view.path_status_label.text.contains(String(expected["display_name"])),
		"the selected Path is readable on the village board: " + path_id)
	_check(app.run_seamstress_path_receipt.is_empty(), "a pick alone commits no run receipt")
	_check(app.run_seamstress_path_choice.is_claimed()
		and app.run_seamstress_path_choice.get_receipt() == expected,
		"the setup's one valid Path claim is the authored receipt")
	_check(view.path_buttons[0].disabled and view.path_buttons[1].disabled
		and view.set_out_button.has_focus(), "a confirmed Path leaves only the sewn actions")
	# Repeated, alternate and directly-invoked requests cannot overwrite the pick.
	for again in [path_id, other_id, path_id]:
		stale.call(again)
	_check(view.selected_path_id() == path_id
		and app.run_seamstress_path_choice.get_receipt() == expected
		and app.run_seamstress_path_receipt.is_empty(),
		"repeated or alternate Path requests cannot overwrite the pick")
	_check(not view.mark_path_selected(other_id, String(_authored_path(other_id).get("display_name", "")))
		and view.selected_path_id() == path_id,
		"the view itself cannot replace a confirmed Path")

	seed(166167)
	expected_global = randi()
	seed(166167)
	await _click(view.set_out_button)
	_check(is_instance_valid(app.route_view) and app.route_view.is_visible_in_tree()
		and app.base_screen == null, "Set out reaches the real opening book: " + path_id)
	_check(app.run_seamstress_path_receipt == expected,
		"the run carries the validated Path receipt: " + path_id)
	_check(randi() == expected_global, "Set out with a Path spends no global RNG")

	var oracle := _seeded_oracle()
	_check(app.run_rng != null and app.run_rng.state == oracle[0]
		and app.run_map.get_floors() == oracle[1] and app.run_map.get_route() == oracle[2]
		and app.run_map.get_legal_choices() == oracle[3],
		"the seeded opening model is the independent seed-42 oracle: " + path_id)
	_check(app.run_deck == starter and app.run_deck.size() == 12 and not app.run_deck.has(card_id),
		"the playable twelve-card deck is unchanged by the Path: " + path_id)
	_check((app.run_seamstress_path_receipt["deck"] as Array).size() == 13
		and String(app.run_seamstress_path_receipt["deck"][12]) == card_id,
		"the proposed thirteenth Path card stays inside the receipt: " + path_id)
	_check(app.deck == null and app.battle_result == null and app.session_gold == 0
		and app.run_scraps == 0 and app.run_heroes.size() == 3,
		"no combat, reward or currency is created by the Path: " + path_id)

	# Detached: mutating the run's receipt copy cannot reach the setup's own copy.
	var stored: Dictionary = app.run_seamstress_path_receipt
	stored["path_id"] = "tampered"
	(stored["card"] as Dictionary)["display_name"] = "Tampered stitch"
	(stored["deck"] as Array).append("tampered_card")
	_check(app.run_seamstress_path_choice != null
		and app.run_seamstress_path_choice.get_receipt() == expected,
		"the committed receipt is detached from its setup: " + path_id)
	app.run_seamstress_path_receipt["path_id"] = path_id
	(app.run_seamstress_path_receipt["card"] as Dictionary)["display_name"] \
		= String((expected["card"] as Dictionary)["display_name"])
	(app.run_seamstress_path_receipt["deck"] as Array).pop_back()
	_check(app.run_seamstress_path_receipt == expected,
		"the run receipt is the authored record again: " + path_id)

	# A post-run request (the Base is gone) can neither overwrite it nor re-open anything.
	var opening := _route_snapshot(app)
	stale.call(other_id)
	_check(app.run_seamstress_path_receipt == expected and _route_snapshot(app) == opening
		and app.base_screen == null, "post-run Path requests stay inert: " + path_id)

	if enter_fight:
		# The receipt is run-scoped: it survives a real routed battle and its Return.
		var fight_button: Button = null
		for button in app.route_buttons:
			if not button.disabled \
				and String(button.get_meta("route_kind", "")) in ["Fight", "Elite"]:
				fight_button = button
				break
		_check(fight_button != null, "the seeded opening offers a real fight: " + path_id)
		if fight_button != null:
			await _click(fight_button)
			_check(app.deck != null and app.battle_result != null
				and is_instance_valid(app.battle_view) and app.battle_view.is_visible_in_tree()
				and app.run_seamstress_path_receipt == expected,
				"the Path receipt survives into the live battle: " + path_id)
			var total := 0
			var path_cards := 0
			var leaked := false
			for pile in [app.deck.draw_pile, app.deck.hand, app.deck.discard_pile]:
				total += (pile as Array).size()
				path_cards += (pile as Array).count(card_id)
				for other in ["seamstress_leech_stitch", "seamstress_fray"]:
					if other != card_id:
						leaked = leaked or (pile as Array).has(other)
			_check(total == 13 and path_cards == 1 and not leaked,
				"the live hand, draw and discard hold the twelve authored cards plus exactly this Path card: " + path_id)
			await _click(app.return_button)
			await process_frame
			_check(app.title_view.is_visible_in_tree() and app.deck == null
				and app.run_map == null and app.run_seamstress_path_receipt.is_empty()
				and app.run_seamstress_path_choice == null
				and app.run_tinker_path_receipt.is_empty()
				and app.run_tinker_path_choice == null,
				"Return from the live run leaves a fresh title with no Path: " + path_id)
			app.free()
			await process_frame
			return

	# Abandoning the opening restores the village with no receipt; Back leaves a clean title.
	await _click(app.route_back_button)
	await process_frame
	_check(is_instance_valid(app.base_screen) and app.base_screen.has_open_village()
		and app.run_seamstress_path_receipt.is_empty() and app.run_map == null and app.deck == null,
		"abandoning the opening restores a receipt-free village: " + path_id)
	var restored: BaseScreen = app.base_screen
	_check(restored.selected_path_id() == "" and restored.path_buttons.size() == 2
		and not restored.path_buttons[0].disabled and not restored.path_buttons[1].disabled,
		"the restored village offers a fresh unclaimed Path setup: " + path_id)
	await _click(restored.back_button)
	await process_frame
	_check(app.base_screen == null and app.title_view.is_visible_in_tree()
		and app.run_seamstress_path_receipt.is_empty() and app.run_seamstress_path_choice == null
		and app.run_tinker_path_receipt.is_empty() and app.run_tinker_path_choice == null
		and app.run_map == null and app.deck == null and app.run_rng == null
		and app.run_deck.is_empty(), "Back to title leaves no Path or run behind: " + path_id)
	app.free()
	await process_frame


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := load(APP_SCENE) as PackedScene
	_check(scene != null, "real app scene loads")
	var base_scene := load(BASE_SCENE) as PackedScene
	_check(base_scene != null, "real Base scene loads")
	if scene == null or base_scene == null:
		_finish()
		return
	# The village itself is presentation-only: it refuses malformed host data and
	# never resolves a Path ID, authored record or deck on its own.
	var standalone := base_scene.instantiate() as BaseScreen
	root.add_child(standalone)
	await process_frame
	_check(not standalone.present_path_options("bloodline")
		and not standalone.present_path_options([{"id": "", "display_name": "Bloodline",
			"card_name": "Leech Stitch"}])
		and not standalone.present_path_options([{"id": "bloodline", "display_name": "",
			"card_name": ""}])
		and not standalone.present_path_options([{"id": "bloodline", "display_name": "Bloodline"},
			{"id": "bloodline", "display_name": "Again"}]),
		"the view refuses malformed or duplicate Path options")
	_check(not standalone.present_tinker_path_options("sharpshot")
		and not standalone.present_tinker_path_options([{"id": "", "display_name": "Sharpshot",
			"card_name": "Scope"}])
		and not standalone.present_tinker_path_options([{"id": "sharpshot", "display_name": "",
			"card_name": ""}])
		and not standalone.present_tinker_path_options([{"id": "sharpshot", "display_name": "Sharpshot"},
			{"id": "sharpshot", "display_name": "Again"}]),
		"the view refuses malformed or duplicate Tinker options")
	_check(standalone.path_buttons.is_empty() and standalone.tinker_buttons.is_empty()
		and not standalone.path_panel.visible and not standalone.tinker_panel.visible
		and not standalone.has_open_village(), "refused options build nothing on a closed village")
	_check(standalone.open_village(3, 4), "a standalone village still opens")
	_check(standalone.present_path_options([
		{"id": "bloodline", "display_name": "Bloodline", "card_name": "Leech Stitch"},
		{"id": "unpicker", "display_name": "Unpicker", "card_name": "Fray"}])
		and standalone.path_buttons.size() == 2
		and standalone.path_buttons[0].text == "Bloodline"
		and standalone.path_buttons[1].text == "Unpicker"
		and standalone.selected_path_id() == "",
		"the view presents exactly the authored names it was given")
	_check(standalone.mark_path_selected("bloodline", "Bloodline")
		and standalone.selected_path_id() == "bloodline"
		and standalone.path_buttons[0].disabled and standalone.path_buttons[1].disabled
		and not standalone.mark_path_selected("unpicker", "Unpicker")
		and standalone.selected_path_id() == "bloodline"
		and not standalone.release_path_choice(),
		"a confirmed Path in the view cannot be replaced or released")
	_check(standalone.present_tinker_path_options([
		{"id": "sharpshot", "display_name": "Sharpshot", "card_name": "Scope"},
		{"id": "clockwork", "display_name": "Clockwork", "card_name": "Wind-up"}])
		and standalone.tinker_buttons.size() == 2
		and standalone.tinker_buttons[0].text == "Sharpshot"
		and standalone.tinker_buttons[1].text == "Clockwork"
		and standalone.selected_tinker_path_id() == "",
		"the view presents exactly the authored Tinker names it was given")
	_check(standalone.mark_tinker_path_selected("clockwork", "Clockwork")
		and standalone.selected_tinker_path_id() == "clockwork"
		and standalone.tinker_buttons[0].disabled and standalone.tinker_buttons[1].disabled
		and not standalone.mark_tinker_path_selected("sharpshot", "Sharpshot")
		and standalone.selected_tinker_path_id() == "clockwork"
		and not standalone.release_tinker_path_choice()
		and standalone.selected_path_id() == "bloodline",
		"a confirmed Tinker Path cannot be replaced and leaves the Seamstress board alone")
	standalone.close_village()
	_check(standalone.selected_path_id() == "" and standalone.selected_tinker_path_id() == "",
		"closing the view clears both shown Paths")
	root.remove_child(standalone)
	standalone.free()
	await process_frame
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
	# --- AC1: both authored Paths on the mounted Heroes board ---------------
	var shown: Array = view.path_options()
	_check(shown.size() == 2 and String(shown[0].get("id", "")) == "bloodline"
		and String(shown[1].get("id", "")) == "unpicker",
		"the Heroes board offers both authored Seamstress Paths")
	for index in range(shown.size()):
		var option: Dictionary = shown[index]
		var authored := _authored_path(String(option.get("id", "")))
		_check(not authored.is_empty()
			and String(option.get("display_name", "")) == String(authored.get("display_name", ""))
			and String(view.path_buttons[index].text) == String(authored.get("display_name", ""))
			and String(option.get("card_name", ""))
				== String((authored.get("card", {}) as Dictionary).get("display_name", ""))
			and view.path_buttons[index].is_visible_in_tree()
			and not view.path_buttons[index].disabled,
			"readable authored Path option: " + String(option.get("id", "")))
	var panel_rect: Rect2 = view.path_panel.get_global_rect()
	_check(view.path_panel.visible and panel_rect.size.x > 0.0 and panel_rect.size.y > 0.0
		and viewport.encloses(panel_rect), "the Path board stays on the 1280x720 quilt")
	var heroes_house := Rect2()
	for building in view.village_buildings():
		if String(building.get("label", "")) == "Heroes":
			heroes_house = building.get("rect", Rect2())
	_check(heroes_house.size.y > 0.0 and panel_rect.position.y >= heroes_house.end.y
		and absf(panel_rect.get_center().x - heroes_house.get_center().x) < heroes_house.size.x,
		"the Path board is pinned under the Heroes house")
	_check(not panel_rect.intersects(view.set_out_button.get_global_rect())
		and not panel_rect.intersects(view.back_button.get_global_rect()),
		"the Path board never covers Set out or Back to title")
	_check(_title_snapshot(app) == pristine, "presenting both Paths spends no run state")
	# The independent Tinker board offers its own two authored options.
	var tinker_shown: Array = view.tinker_path_options()
	_check(tinker_shown.size() == 2 and String(tinker_shown[0].get("id", "")) == "sharpshot"
		and String(tinker_shown[1].get("id", "")) == "clockwork"
		and view.tinker_buttons.size() == 2,
		"the Tinker board offers both authored Tinker Paths in authored order")
	for index in range(tinker_shown.size()):
		_check(String(view.tinker_buttons[index].text)
			== String(tinker_shown[index].get("display_name", ""))
			and view.tinker_buttons[index].is_visible_in_tree()
			and not view.tinker_buttons[index].disabled,
			"readable authored Tinker option: " + String(tinker_shown[index].get("id", "")))
	var tinker_rect: Rect2 = view.tinker_panel.get_global_rect()
	_check(view.tinker_panel.visible and tinker_rect.size.x > 0.0 and tinker_rect.size.y > 0.0
		and viewport.encloses(tinker_rect),
		"the Tinker board stays on the 1280x720 quilt")
	_check(not tinker_rect.intersects(panel_rect)
		and not tinker_rect.intersects(view.set_out_button.get_global_rect())
		and not tinker_rect.intersects(view.back_button.get_global_rect()),
		"the Tinker board covers neither the Seamstress board nor the sewn actions")
	_check(view.selected_tinker_path_id() == "",
		"the Tinker board starts with no Path chosen")
	# Real keyboard focus cycle: Back, both Path options, both Tinker options, Set out.
	await _key(KEY_TAB)
	_check(view.back_button.has_focus(), "Tab reaches Back to title")
	await _key(KEY_TAB)
	_check(view.path_buttons[0].has_focus(), "Tab reaches the first authored Path")
	await _key(KEY_TAB)
	_check(view.path_buttons[1].has_focus(), "Tab reaches the second authored Path")
	await _key(KEY_TAB)
	_check(view.tinker_buttons[0].has_focus(), "Tab reaches the first Tinker Path")
	await _key(KEY_TAB)
	_check(view.tinker_buttons[1].has_focus(), "Tab reaches the second Tinker Path")
	await _key(KEY_TAB)
	_check(view.set_out_button.has_focus(), "Tab wraps back to Set out")
	# Keyboard pick of Bloodline: the host validates it and the village shows it.
	var path_binding: Callable = _app_binding(app, view.path_choice_requested)
	_check(path_binding.is_valid(), "the app really handles the Base Path signal")
	await _key_select_path(view, "bloodline")
	_check(view.selected_path_id() == "bloodline" and view.selected_path_name() == "Bloodline"
		and view.path_status_label.text.contains("Bloodline")
		and view.path_buttons[0].disabled and view.path_buttons[1].disabled,
		"a keyboard pick shows the actual selected Path and closes the other option")
	_check(app.run_seamstress_path_choice != null
		and app.run_seamstress_path_choice.get_receipt() == _expected_receipt("bloodline")
		and app.run_seamstress_path_receipt.is_empty(),
		"a confirmed Path is validated by RunSeamstressPathChoice but commits no receipt yet")
	path_binding.call("bloodline")
	path_binding.call("unpicker")
	_check(view.selected_path_id() == "bloodline"
		and app.run_seamstress_path_choice.get_receipt()["path_id"] == "bloodline",
		"repeated or alternate Path callbacks cannot overwrite the pick")
	# The confirmed Seamstress Path narrows the sewn loop to Back, the still-open
	# Tinker options and Set out.
	await _key(KEY_TAB)
	_check(view.back_button.has_focus(), "Tab reaches Back to title")
	await _key(KEY_TAB)
	_check(view.tinker_buttons[0].has_focus(), "Tab reaches the still-open first Tinker Path")
	await _key(KEY_TAB)
	_check(view.tinker_buttons[1].has_focus(), "Tab reaches the still-open second Tinker Path")
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
	_check(_title_snapshot(app) == pristine and app.run_seamstress_path_receipt.is_empty()
		and app.run_seamstress_path_choice == null,
		"Back spends no run, RNG, deck, currency or Path receipt")
	_check(randi() == back_global, "closing the Base spends no global RNG")

	# --- AC2: a mouse Path pick, a refused Set out and the real opening ------
	await _click(app.base_button)
	_check(is_instance_valid(app.base_screen) and app.base_screen.is_visible_in_tree(),
		"mouse opens the village again")
	view = app.base_screen
	_check(_title_snapshot(app) == pristine and view.has_open_village()
		and view.selected_path_id() == "" and view.path_buttons.size() == 2
		and not view.path_buttons[0].disabled and not view.path_buttons[1].disabled,
		"reopening the village offers a fresh unselected Path setup")
	await _mouse_select_path(view, "unpicker")
	_check(view.selected_path_id() == "unpicker" and view.selected_path_name() == "Unpicker"
		and view.path_status_label.text.contains("Unpicker")
		and view.set_out_button.has_focus(),
		"a mouse pick shows the actual selected Path")
	var invalid_before := _title_snapshot(app)
	app.starter_deck_path = "res://missing-base-village-deck.json"
	await _click(view.set_out_button)
	_check(app.run_map == null and app.deck == null and app.run_rng == null
		and _title_snapshot(app) == invalid_before, "invalid Set out creates no run or RNG")
	_check(app.run_seamstress_path_receipt.is_empty() and app.base_screen == view
		and view.is_visible_in_tree() and not view.set_out_button.disabled
		and not view.back_button.disabled,
		"failed Set out commits no Path receipt and leaves the Base actionable")
	_check(view.selected_path_id() == "unpicker", "failed Set out keeps the confirmed Path")
	app.starter_deck_path = STARTER_DECK_PATH

	# --- AC2: Set out opens the real seeded chooser exactly like the title ---
	var stale_binding := _app_binding(app, view.set_out_requested)
	_check(stale_binding.is_valid(), "the app really handles the Base Set out signal")
	await _click(view.set_out_button)
	_check(is_instance_valid(app.route_view) and app.route_view.is_visible_in_tree(),
		"Set out opens the opening-route chooser")
	_check(app.base_screen == null, "Base hides only after the route was created")
	_check(app.run_seamstress_path_receipt == _expected_receipt("unpicker"),
		"Set out commits the validated detached Path receipt")
	_check(app.run_deck == StarterCards.new().get_starting_deck()
		and not app.run_deck.has("seamstress_fray")
		and (app.run_seamstress_path_receipt["deck"] as Array).size() == 13,
		"the playable deck stays twelve cards while the proposal stays in the receipt")
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
	var receipt_before: Dictionary = app.run_seamstress_path_receipt.duplicate(true)
	stale_binding.call()
	path_binding.call("bloodline")
	_check(_route_snapshot(app) == chooser_before and app.route_view.is_visible_in_tree(),
		"replayed freed Base Set out cannot overwrite the run")
	_check(app.run_seamstress_path_receipt == receipt_before,
		"a post-Set out Path callback cannot overwrite the committed receipt")
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
	_check(app.run_seamstress_path_receipt.is_empty()
		and app.run_seamstress_path_choice != null
		and not app.run_seamstress_path_choice.is_claimed(),
		"an abandoned opening drops its Path receipt and holds a fresh setup")
	_check(_title_snapshot(app) == pristine, "restored Base spends nothing")
	view = app.base_screen
	_check(view.set_out_button.has_focus(), "restored Base focuses Set out again")
	_check(view.selected_path_id() == "" and view.path_buttons.size() == 2
		and not view.path_buttons[0].disabled and not view.path_buttons[1].disabled
		and view.path_status_label.text == "No Path chosen yet",
		"restored Base offers both Paths again with nothing chosen")

	# --- AC3: a hidden Base cannot choose a Path or start a run -------------
	var hidden_binding := _app_binding(app, view.set_out_requested)
	var hidden_path_binding := _app_binding(app, view.path_choice_requested)
	_check(hidden_binding.is_valid() and hidden_path_binding.is_valid(),
		"restored Base has exactly the app handlers")
	view.hide()
	hidden_binding.call()
	view.set_out_button.pressed.emit()
	hidden_path_binding.call("bloodline")
	view.path_choice_requested.emit("unpicker")
	_check(app.run_map == null and app.deck == null and app.route_view == null
		and app.base_screen == view, "hidden Base signals cannot create a run")
	_check(view.selected_path_id() == "" and app.run_seamstress_path_receipt.is_empty()
		and not app.run_seamstress_path_choice.is_claimed(),
		"hidden Base Path signals cannot choose a Path")
	view.show()
	_check(not view.set_out_button.disabled and not view.path_buttons[0].disabled
		and not view.path_buttons[1].disabled and view.path_buttons.size() == 2,
		"shown Base stays actionable after the probe")
	await _click(view.back_button)
	await process_frame
	_check(app.base_screen == null and app.title_view.is_visible_in_tree(),
		"Back to title closes the village")
	_check(not is_instance_valid(view), "Back really frees the old village")
	hidden_path_binding.call("bloodline")
	path_binding.call("unpicker")
	_check(app.run_seamstress_path_receipt.is_empty() and app.run_seamstress_path_choice == null
		and app.run_map == null and app.deck == null and app.base_screen == null
		and app.title_view.is_visible_in_tree(), "freed Base Path callbacks stay inert")

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
	_check(app.base_screen == null and _title_snapshot(app) == pristine
		and app.run_seamstress_path_receipt.is_empty()
		and app.run_seamstress_path_choice == null,
		"direct route Back spends nothing and leaves no Path")

	app.free()
	await process_frame

	# --- AC1/AC2/AC3: each authored Path in its own fresh mounted session ----
	await _fresh_path_run("bloodline", true, true)
	await _fresh_path_run("unpicker", false, false)
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_base_screen_entry_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
