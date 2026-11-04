extends SceneTree
## Real mounted S4 Quilt Village combat-guide contract: focus, modal guards,
## seeded RNG and host state stay untouched by a read-only browse.
const SCENE := preload("res://scenes/base_screen.tscn")
var failures: Array[String] = []
var checks := 0
var view: BaseScreen
var back_calls := 0
var set_out_calls := 0
var path_calls := 0
var tinker_calls := 0
var warden_calls := 0
var difficulty_calls := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)


func _frames() -> void:
	for _i in range(3):
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


func _click(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	_check(root.get_visible_rect().has_point(point), "visible pointer target " + button.name)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame


func _paths(path: String) -> Array:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var rows: Variant = raw.get("paths", []) if raw is Dictionary else raw
	var result: Array = []
	if rows is Array:
		for record in rows:
			if record is Dictionary:
				var card: Dictionary = record.get("card", {})
				result.append({"id": String(record.get("id", "")),
					"display_name": String(record.get("display_name", "")),
					"card_name": String(card.get("display_name", ""))})
	return result


func _all_present(haystack: String, needles: Array) -> bool:
	for needle in needles:
		if not haystack.contains(needle):
			return false
	return true


func _state() -> Array:
	return [view.wallet_label.text, view.selected_path_id(),
		view.selected_tinker_path_id(), view.selected_warden_path_id(),
		view._set_out_pending, view._back_pending, view._path_pending,
		view._tinker_pending, view._warden_pending, view._difficulty_request,
		view.deck_gallery.is_open(), back_calls, set_out_calls, path_calls,
		tinker_calls, warden_calls, difficulty_calls]


func _run() -> void:
	root.size = Vector2i(1280, 720)
	view = SCENE.instantiate() as BaseScreen
	root.add_child(view)
	await _frames()
	var guide := view.field_guide
	var entry := view.guide_button
	_check(view.scene_file_path == "res://scenes/base_screen.tscn" and guide != null
		and entry != null and not view.has_open_village() and entry.disabled
		and not guide.is_open(), "live scene mounts one closed/disabled village guide")
	if guide == null or entry == null:
		_finish()
		return
	view._on_guide_pressed()
	_check(not guide.is_open(), "closed village refuses stale guide invocation")
	var seam := _paths("res://data/heroes/seamstress_paths.json")
	var tinker := _paths("res://data/heroes/tinker_paths.json")
	var warden := _paths("res://data/heroes/warden_paths.json")
	_check(seam.size() >= 2 and tinker.size() >= 2 and warden.size() >= 2,
		"real authored hero Path fixtures are nonempty")
	if seam.is_empty() or tinker.is_empty() or warden.is_empty():
		_finish()
		return
	_check(view.present_path_options(seam)
		and view.present_tinker_path_options(tinker)
		and view.present_warden_path_options(warden), "live village Path boards mount")
	view.present_difficulty([0, 1], 0)
	view.back_requested.connect(func() -> void: back_calls += 1)
	view.set_out_requested.connect(func() -> void: set_out_calls += 1)
	view.path_choice_requested.connect(func(_id: String) -> void: path_calls += 1)
	view.tinker_path_choice_requested.connect(func(_id: String) -> void: tinker_calls += 1)
	view.warden_path_choice_requested.connect(func(_id: String) -> void: warden_calls += 1)
	view.difficulty_choice_requested.connect(func(_tier: int) -> void: difficulty_calls += 1)
	_check(view.open_village(27, 6), "valid host opens actual Quilt Village")
	await _frames()
	var strip := view.get_node("TopStrip/StripRow")
	_check(entry.get_parent() == strip and entry.text == "Battle guide"
		and entry.focus_mode == Control.FOCUS_ALL and not entry.disabled
		and entry.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND
		and root.get_visible_rect().encloses(entry.get_global_rect())
		and not entry.get_global_rect().intersects(view.wallet_label.get_global_rect())
		and not entry.get_global_rect().intersects(view.back_button.get_global_rect()),
		"distinct focusable top-strip entry has space at 1280x720")
	_check(view.back_button.focus_next == view.back_button.get_path_to(view.heroes_house_button)
		and view.heroes_house_button.focus_next == view.heroes_house_button.get_path_to(view.camp_house_button),
		"Back -> Heroes -> Camp Tab order is preserved")
	entry.grab_focus()
	await _key(KEY_ENTER)
	_check(guide.is_open() and guide.is_visible_in_tree()
		and root.gui_get_focus_owner() == guide.tab_buttons[0] and entry.disabled,
		"Enter opens actual modal overlay and focuses first tab")
	_check(view.get_children().filter(func(node: Node) -> bool: return node is StitchedFieldGuide).size() == 1,
		"guide has exactly one mounted instance")
	_check(guide.theme == load("res://themes/gothic_theme.tres")
		and guide.get_node("FeltPanel") is NinePatchRect
		and (guide.get_node("FeltPanel") as NinePatchRect).texture != null,
		"existing Gothic theme and supplied felt art mount")
	var texts := [
		["Friendly ranks", "1 (front)", "4 (back)", "Foes", "2–3 foes",
			"fourth", "summon or split", "SPEED + 1d8", "seeded RNG",
			"Ties favour heroes", "lower ranks", "one turn", "two-turn bosses",
			"HEAD / ARMS / TORSO / LEGS", "one ability each", "launch ranks",
			"target ranks", "MOVE", "adjacent ally", "RE-TIE", "snipped", "PASS"],
		["non-boss", "75%", "consumes that hero's turn", "EACH hero +15 Fray",
			"forfeits all rewards", "SNIPPED THREAD", "healing or guard",
			"re-tied", "0 HP", "Hanging by a Thread", "still act",
			"random non-torso part", "67%", "33%"],
		["0–200", "100", "25% Steadfast", "45 Fray", "75% Unravelled",
			"200 Fray", "Comes Apart", "150", "Begins at 100",
			"Bright 76–100", "Dim 51–75", "Gloom 26–50",
			"Dark 1–25", "Snuffed 0", "8 Candle per map node",
			"S6 run integration", "NOT active", "S4 play"]
	]
	for i in range(3):
		if i > 0:
			await _click(guide.tab_buttons[i])
		_check(guide.page_index == i and guide.page_labels[i].is_visible_in_tree()
			and guide.tab_buttons[i].button_pressed,
			"actual tab %d reveals one selected page" % i)
		var single := true
		for j in range(3):
			single = single and (guide.page_labels[j].visible == (i == j))
		_check(single and _all_present(guide.page_text(i), texts[i]),
			"page %d shows exact S4 rule/rank/numeric statements" % i)
		_check(guide.page_labels[i].get_theme_font_size("font_size") >= 18
			and not guide.page_text(i).to_lower().contains("energy cost")
			and not guide.page_text(i).to_lower().contains("draw a card"),
			"legible body size and no obsolete deck/hand/energy copy on page %d" % i)
	# One keyboard-only trip around the guide ring must never focus the village.
	guide.tab_buttons[0].grab_focus()
	await _key(KEY_TAB)
	_check(root.gui_get_focus_owner() == guide.tab_buttons[1],
		"Tab stays within the three-page guide")
	await _key(KEY_TAB, true)
	_check(root.gui_get_focus_owner() == guide.tab_buttons[0],
		"Shift-Tab stays within the guide")
	seed(501006)
	var next_rng := randi()
	seed(501006)
	var witness := _state()
	view._on_back_pressed()
	view._on_set_out_pressed()
	view._on_deck_pressed()
	view._on_heroes_house_pressed()
	view._on_camp_house_pressed()
	view._on_path_pressed(String(seam[0]["id"]))
	view._on_tinker_path_pressed(String(tinker[0]["id"]))
	view._on_warden_path_pressed(String(warden[0]["id"]), view.warden_buttons[0])
	view._request_difficulty(0)
	_check(not view.mark_path_selected(String(seam[0]["id"]), String(seam[0]["display_name"]))
		and not view.mark_tinker_path_selected(String(tinker[0]["id"]), String(tinker[0]["display_name"]))
		and not view.mark_warden_path_selected(String(warden[0]["id"]), String(warden[0]["display_name"])),
		"host confirmation cannot select Paths through an open modal")
	view._on_guide_pressed()
	_check(guide.is_open() and view.get_children().filter(func(node: Node) -> bool: return node is StitchedFieldGuide).size() == 1,
		"repeated entry is inert, with no duplicate overlay")
	_check(_state() == witness and randi() == next_rng,
		"all stale underlying actions preserve signals, wallet, choice, gallery and seeded RNG")
	await _click(guide.close_button)
	_check(not guide.is_open() and not guide.visible and root.gui_get_focus_owner() == entry
		and not entry.disabled, "pointer Close dismisses and restores guide entry focus")
	await _click(entry)
	_check(guide.is_open(), "pointer reopens same mounted guide")
	await _key(KEY_ESCAPE)
	_check(not guide.is_open() and root.gui_get_focus_owner() == entry,
		"Escape dismisses and restores guide entry focus")
	await _click(view.deck_button)
	_check(view.deck_gallery.is_open() and entry.disabled,
		"real starter-kit gallery stays separate and blocks guide entry")
	view._on_guide_pressed()
	_check(not guide.is_open(), "gallery-open stale guide request is inert")
	view._on_deck_closed()
	await _frames()
	_check(not view.deck_gallery.is_open() and not entry.disabled,
		"closing Deck gallery restores the guide entry")
	view._on_set_out_pressed()
	_check(view._set_out_pending and entry.disabled and set_out_calls == 1,
		"pending Set out blocks guide without changing existing one-shot dispatch")
	view._on_guide_pressed()
	_check(not guide.is_open(), "pending host Set out rejects guide")
	_check(view.release_set_out() and not entry.disabled, "host refusal restores entry")
	await _click(entry)
	_check(guide.is_open(), "guide opens again after pending release")
	view.hide()
	await _frames()
	_check(not guide.is_open() and not guide.visible, "hiding parent dismisses modal")
	view.show()
	await _frames()
	_check(not guide.is_open() and not entry.disabled, "showing parent has no stale guide")
	await _click(entry)
	_check(guide.is_open(), "guide remains reusable after parent hide/show")
	view.close_village()
	_check(not guide.is_open() and not view.has_open_village() and entry.disabled,
		"closing parent dismisses modal and disables entry")
	view._on_guide_pressed()
	_check(not guide.is_open(), "closed parent rejects stale entry")
	_check(view.open_village(27, 6), "second actual host entry is supported")
	await _frames()
	await _click(entry)
	_check(guide.is_open() and view.get_children().filter(func(node: Node) -> bool: return node is StitchedFieldGuide).size() == 1,
		"subsequent village uses same guide without callbacks or nodes multiplying")
	await _key(KEY_ESCAPE)
	_check(not guide.is_open() and view.wallet_label.text == "Gold 27  ·  Scraps 6"
		and not view._back_pending and not view._set_out_pending,
		"second Escape leaves real village actions live and wallet unchanged")
	view._on_back_pressed()
	_check(back_calls == 1 and view._back_pending,
		"normal original Back callback works after guide dismissal")
	view.close_village()
	view.queue_free()
	await _frames()
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("stitched_s4_village_combat_guide_test: PASS (%d checks)" % checks)
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		printerr("stitched_s4_village_combat_guide_test: FAIL (%d/%d)" % [failures.size(), checks])
		quit(1)
