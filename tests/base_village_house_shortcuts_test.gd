extends SceneTree
## Headless mounted Quilt Village shortcut integration: real pointer/keyboard events.
const SCENE := preload("res://scenes/base_screen.tscn")
var failures: Array[String] = []
var checks := 0
var view: BaseScreen
var path_requests: Array[String] = []
var set_out_count := 0
var back_count := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, what: String) -> void:
	checks += 1
	if not value:
		failures.append(what)

func _frames() -> void:
	for i in range(3):
		await process_frame

func _mouse(button: Button) -> void:
	var p := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = p
	root.push_input(motion, true)
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = p
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func _key(key: Key, shifted: bool = false) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.shift_pressed = shifted
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func _paths() -> Array:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/heroes/seamstress_paths.json"))
	var rows: Variant = raw.get("paths", []) if raw is Dictionary else raw
	var output: Array = []
	if rows is Array:
		for option in rows:
			if option is Dictionary:
				output.append({"id": String(option.get("id", "")),
					"display_name": String(option.get("display_name", "")),
					"card_name": String(option.get("card", {}).get("display_name", ""))})
	return output

func _rects_clear(a: Control, b: Control) -> bool:
	return not a.get_global_rect().intersects(b.get_global_rect())

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var options := _paths()
	_check(options.size() >= 2, "real authored Path options are available")
	view = SCENE.instantiate() as BaseScreen
	root.add_child(view)
	await _frames()
	var heroes := view.heroes_house_button
	var camp := view.camp_house_button
	_check(view.scene_file_path == "res://scenes/base_screen.tscn"
		and heroes != null and camp != null and not view.has_open_village(),
		"the actual screen mounts closed with both shortcuts")
	_check(heroes.name == "HeroesHouseButton" and camp.name == "CampHouseButton"
		and heroes.disabled and camp.disabled, "closed shortcuts are disabled")
	_check(not view.present_path_options([]), "empty authored list is refused")
	_check(view.present_path_options(options), "canonical Path board is mounted")
	view.path_choice_requested.connect(func(id: String) -> void: path_requests.append(id))
	view.set_out_requested.connect(func() -> void: set_out_count += 1)
	view.back_requested.connect(func() -> void: back_count += 1)
	_check(view.open_village(17, 5), "real host entry opens the village")
	await _frames()
	var first := view.path_buttons[0]
	_check(view.path_panel.is_visible_in_tree() and first.is_visible_in_tree()
		and not first.disabled and not heroes.disabled and not camp.disabled,
		"authored Path and both live landmark shortcuts are actionable")
	_check(heroes.text == "Path choices" and camp.text == "Set out"
		and heroes.tooltip_text.contains("Heroes") and camp.tooltip_text.contains("Camp")
		and heroes.focus_mode == Control.FOCUS_ALL and camp.focus_mode == Control.FOCUS_ALL
		and heroes.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND
		and camp.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND,
		"named, readable sewn controls expose mouse cursor, hints and keyboard focus")
	var hero_rect := heroes.get_global_rect()
	var camp_rect := camp.get_global_rect()
	var buildings := view.village_buildings()
	_check((buildings[0].rect as Rect2).encloses(hero_rect)
		and (buildings[1].rect as Rect2).encloses(camp_rect)
		and hero_rect.end.y < BaseScreen.HEROES_PANEL_RECT.position.y
		and camp_rect.end.y < BaseScreen.TINKER_PANEL_RECT.position.y
		and root.get_visible_rect().encloses(hero_rect)
		and root.get_visible_rect().encloses(camp_rect),
		"1280x720 clickable areas lie wholly inside real Heroes/Camp landmarks above boards")
	var clear := (_rects_clear(heroes, camp) and _rects_clear(heroes, view.deck_button)
		and _rects_clear(camp, view.deck_button)
		and _rects_clear(heroes, view.back_button)
		and _rects_clear(camp, view.back_button)
		and _rects_clear(heroes, view.set_out_button)
		and _rects_clear(camp, view.set_out_button)
		and _rects_clear(heroes, view.wallet_label)
		and _rects_clear(camp, view.wallet_label))
	for board in [view.path_panel, view.tinker_panel, view.warden_panel]:
		clear = clear and _rects_clear(heroes, board) and _rects_clear(camp, board)
	_check(clear, "shortcuts do not cover Deck, wallet, Back, Set out or any Path board")
	_check(heroes.focus_next == heroes.get_path_to(camp)
		and camp.focus_previous == camp.get_path_to(heroes)
		and view.back_button.focus_next == view.back_button.get_path_to(heroes),
		"the existing forward and reverse Tab ring includes both landmarks")
	view.back_button.grab_focus()
	await _key(KEY_TAB)
	_check(root.gui_get_focus_owner() == heroes, "real Tab navigates Back to Heroes")
	await _key(KEY_TAB)
	_check(root.gui_get_focus_owner() == camp, "real Tab navigates Heroes to Camp")
	await _key(KEY_TAB, true)
	_check(root.gui_get_focus_owner() == heroes, "real Shift-Tab navigates Camp to Heroes")
	await _mouse(heroes)
	_check(root.gui_get_focus_owner() == first and path_requests.is_empty()
		and view.selected_path_id().is_empty() and not view._path_pending,
		"mouse Heroes focuses first actual authored Path without choosing or signalling")
	heroes.grab_focus()
	await _key(KEY_ENTER)
	_check(root.gui_get_focus_owner() == first and path_requests.is_empty(),
		"Enter on Heroes moves focus without selecting a Path")
	heroes.grab_focus()
	await _key(KEY_SPACE)
	_check(root.gui_get_focus_owner() == first and path_requests.is_empty(),
		"Space on Heroes moves focus without selecting a Path")
	# Unlike the house, activating the original Path button must still report the pick.
	await _key(KEY_ENTER)
	_check(path_requests.size() == 1 and path_requests[0] == String(options[0]["id"])
		and view.selected_path_id().is_empty(),
		"the unchanged first Path option still emits its unconfirmed host request")
	_check(view.mark_path_selected(String(options[0]["id"]), String(options[0]["display_name"])),
		"host can confirm the real Path choice")
	_check(heroes.disabled and not camp.disabled,
		"Heroes disables after all authored choices become ineligible")
	view._on_heroes_house_pressed()
	_check(path_requests.size() == 1 and view.selected_path_id() == String(options[0]["id"]),
		"stale Heroes activation cannot mutate a confirmed Path")
	await _mouse(view.deck_button)
	_check(view.deck_gallery.is_open() and heroes.disabled and camp.disabled,
		"Deck's original gallery opens and suppresses both shortcuts")
	view._on_camp_house_pressed()
	_check(set_out_count == 0, "Camp cannot start a run through an open gallery")
	view._on_deck_closed()
	await _frames()
	_check(not view.deck_gallery.is_open() and not camp.disabled,
		"closing gallery restores eligible Camp landmark")
	await _mouse(camp)
	_check(set_out_count == 1 and view._set_out_pending and view.set_out_button.disabled
		and camp.disabled and back_count == 0,
		"actual Camp click uses Set out's one-shot pending latch")
	await _mouse(camp)
	view._on_camp_house_pressed()
	_check(set_out_count == 1, "repeat Camp clicks and stale callbacks are inert")
	_check(view.release_set_out() and not camp.disabled, "host refusal restores Camp eligibility")
	camp.grab_focus()
	await _key(KEY_SPACE)
	_check(set_out_count == 2 and view._set_out_pending,
		"Space on focused Camp uses exactly the same existing Set out handler")
	_check(view.release_set_out(), "second host refusal resets the original latch")
	camp.grab_focus()
	await _key(KEY_ENTER)
	_check(set_out_count == 3 and view._set_out_pending,
		"Enter on focused Camp uses exactly the same handler")
	view.hide()
	await _frames()
	view._on_camp_house_pressed()
	_check(set_out_count == 3 and camp.disabled, "hidden view refuses a stale Camp invocation")
	view.show()
	await _frames()
	_check(view.has_open_village() and view._set_out_pending and camp.disabled,
		"showing a pending view cannot restart Set out")
	view.close_village()
	view._on_camp_house_pressed()
	_check(set_out_count == 3 and heroes.disabled and camp.disabled,
		"closed view refuses both shortcuts")
	view.queue_free()
	await _frames()
	# A second real mounted village with NO authored options must not activate Heroes.
	var empty := SCENE.instantiate() as BaseScreen
	root.add_child(empty)
	await _frames()
	_check(empty.open_village() and empty.path_buttons.is_empty()
		and not empty.path_panel.visible and empty.heroes_house_button.disabled
		and not empty.camp_house_button.disabled,
		"without authored Paths the Heroes shortcut disables but Camp remains live")
	empty._on_heroes_house_pressed()
	_check(root.gui_get_focus_owner() != empty.heroes_house_button,
		"no authored option means no invalid Hero focus target")
	empty.set_out_button.disabled = true
	empty._on_camp_house_pressed()
	_check(not empty._set_out_pending,
		"Camp cannot bypass a disabled original SetOutButton")
	empty.close_village()
	empty.queue_free()
	await _frames()
	if failures.is_empty():
		print("base_village_house_shortcuts_test: PASS (%d checks)" % checks)
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		printerr("base_village_house_shortcuts_test: FAIL (%d/%d)" % [failures.size(), checks])
		quit(1)
