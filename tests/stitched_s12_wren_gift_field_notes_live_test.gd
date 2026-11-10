extends SceneTree
## Wren's gift notes through the real bedroom Drawings -> Field Guide control.

const SCENE := preload("res://scenes/base_screen.tscn")
var failures: Array[String] = []
var checks := 0
var before_enabled := false
var host_commands := 0


func _initialize() -> void:
	before_enabled = StitchedBedroom.enabled
	StitchedBedroom.enabled = true
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


func _frames() -> void:
	for _i in range(3):
		await process_frame


func _click(button: Button) -> void:
	var at := button.get_global_rect().get_center()
	_check(button.is_visible_in_tree() and not button.disabled and
		root.get_visible_rect().has_point(at), "clickable " + button.name)
	var motion := InputEventMouseMotion.new()
	motion.position = at
	root.push_input(motion, true)
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame


func _key(key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame


func _focusable(node: Node) -> int:
	var count := 0
	if node is Control and node.is_visible_in_tree() and node.focus_mode != Control.FOCUS_NONE:
		count += 1
	for child in node.get_children():
		count += _focusable(child)
	return count


func _saved_bytes() -> PackedByteArray:
	var file := FileAccess.open(StitchedWrenGifts.PROFILE_PATH, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	return file.get_buffer(file.get_length())


func _assert_notes(guide: StitchedFieldGuide, profile: Dictionary, cue: String) -> void:
	var notes := StitchedWrenGiftFieldNotes.examples(profile)
	var door_examples := StitchedFieldGuide.side_door_examples()
	var expected: Array = StitchedFieldGuide.PAGES[2].duplicate()
	expected.append_array(door_examples)
	expected.append_array(notes)
	var actual := guide.page_text(2)
	_check(notes.size() == 3 and door_examples.size() == 4 and actual == "\n\n".join(expected),
		"owner 11-10: open Candle page is baseline and door notes followed by three freshly validated notes")
	_check(actual.begins_with("\n\n".join(StitchedFieldGuide.PAGES[2])) and actual.contains(cue),
		"correct next unlock milestone: " + cue)
	_check(actual.contains("four gifts") and actual.contains("one hand action") and
		actual.contains("once per fight") and actual.contains("fear 50") and
		actual.contains("three gifts") and actual.contains("swap") and
		actual.contains("this run only") and actual.contains("later runs"),
		"notes teach hand/fear/offers/swaps and later-run unlocks")
	_check(not actual.contains("already equipped") and not actual.contains("guaranteed") and
		not actual.contains("resist Wren"), "no fabricated ownership, offers or resisted hand")
	for note in notes:
		_check(actual.count(note) == 1, "no repeated gift sentence on open")


func _pure_checks() -> void:
	var catalog := StitchedWrenGifts.catalog()
	_check(bool(catalog.get("ok", false)) and catalog.get("by_id") is Dictionary,
		"authored gift catalog validates")
	var initial := {"best_floor": 0, "boss_wins": 0}
	var pool := StitchedWrenGifts.pool_for(initial)
	_check(not pool.is_empty() and pool == StitchedWrenGifts.pool_for(initial),
		"the real Wren unlock pool is deterministic")
	var source_copy := catalog.duplicate(true)
	for case in [
		{}, [], {"best_floor": -1, "boss_wins": 0},
		{"best_floor": "4", "boss_wins": 0},
		{"best_floor": 4, "boss_wins": false},
		{"best_floor": 0}, {"best_floor": 0, "boss_wins": 0, "extra": 1},
	]:
		var prior: Variant = case.duplicate(true)
		_check(StitchedWrenGiftFieldNotes.examples(case, catalog).is_empty() and
			case == prior, "invalid detached profile rejected without mutation")
	var bad_book := source_copy.duplicate(true)
	bad_book.by_id.erase("point")
	_check(StitchedWrenGiftFieldNotes.examples(initial, bad_book).is_empty(),
		"missing gift rejects catalog source")
	bad_book = source_copy.duplicate(true)
	bad_book.by_id["point"]["name"] = "A made-up present"
	_check(StitchedWrenGiftFieldNotes.examples(initial, bad_book).is_empty(),
		"fabricated gift name rejects catalog source")
	_check(StitchedWrenGiftFieldNotes.examples(initial, {}) == [] and
		StitchedWrenGiftFieldNotes.examples(initial, []) == [],
		"wrong catalog shapes fail closed")
	_check(StitchedWrenGiftFieldNotes.examples(initial, source_copy) ==
		StitchedWrenGiftFieldNotes.examples(initial),
		"valid detached copy yields only authorized guide text")
	_check(catalog == StitchedWrenGifts.catalog(), "invalid copies never modify catalog")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	_pure_checks()
	var had_save := FileAccess.file_exists(StitchedWrenGifts.PROFILE_PATH)
	var save_snapshot := _saved_bytes()
	var view := SCENE.instantiate() as BaseScreen
	root.add_child(view)
	await _frames()
	var room := view.bedroom
	var guide := view.field_guide
	_check(room != null and guide != null and not guide.is_open(),
		"mounted real BaseScreen starts with a closed guide")
	if room == null or guide == null:
		view.queue_free()
		_finish()
		return
	var drawings := room.spot("drawings")
	_check(drawings != null and drawings == view.guide_button,
		"real Drawings hotspot is the mounted guide button")
	_check(view.open_village(31, 7), "real bedroom opens")
	await _frames()
	var room_snapshot: Dictionary = room.record.duplicate(true)
	var wallet := view.wallet_label.text
	var navigation := [view.selected_path_id(), view.selected_tinker_path_id(),
		view.selected_warden_path_id(), view._set_out_pending, view._back_pending]
	view.back_requested.connect(func() -> void: host_commands += 1)
	view.set_out_requested.connect(func() -> void: host_commands += 1)
	view.path_choice_requested.connect(func(_id: String) -> void: host_commands += 1)
	seed(62291)
	var expected_rng := randi()
	seed(62291)
	var profiles := [
		[{"best_floor": 0, "boss_wins": 0}, "Reach Floor Four"],
		[{"best_floor": 4, "boss_wins": 0}, "Reach Floor Eight"],
		[{"best_floor": 8, "boss_wins": 0}, "Win A Boss Fight"],
		[{"best_floor": 12, "boss_wins": 1}, "Every gift family"],
	]
	for record in profiles:
		guide.wren_gift_profile_source = (record[0] as Dictionary).duplicate(true)
		await _click(drawings)
		_check(guide.is_open() and root.gui_get_focus_owner() == guide.tab_buttons[0],
			"Drawings opens guide with first tab focused")
		_check(guide.get_child_count() == 2 and _focusable(guide) == 5 and
			guide.tab_buttons.size() == 3 and guide.page_labels.size() == 3,
			"owner 11-10: three-tab, five-focusable-control hierarchy after Fray retired")
		await _click(guide.tab_buttons[2])
		_check(guide.page_index == 2 and guide.page_labels[2].is_visible_in_tree(),
			"real Candle & stops tab is selected")
		_assert_notes(guide, record[0], str(record[1]))
		_check(guide.page_text(0) == "\n\n".join(StitchedFieldGuide.PAGES[0]),
			"rank page unchanged")
		await _click(guide.close_button)
		_check(not guide.is_open() and root.gui_get_focus_owner() == drawings,
			"Close restores focus to Drawings")
	# Invalid fixtures suppress ALL optional text, even after a prior valid open.
	for bad_profile in [{"best_floor": "8", "boss_wins": 0}, {"best_floor": 8}]:
		guide.wren_gift_profile_source = bad_profile
		await _click(drawings)
		_check(guide.page_text(2) == "\n\n".join(StitchedFieldGuide.PAGES[2] + StitchedFieldGuide.side_door_examples()),
			"bad profile clears old Wren advice but keeps the Candle baseline and door notes")
		await _key(KEY_ESCAPE)
		_check(not guide.is_open() and root.gui_get_focus_owner() == drawings,
			"Escape restores Drawings focus from invalid advice")
	guide.wren_gift_profile_source = {"best_floor": 0, "boss_wins": 0}
	guide.wren_gift_catalog_source = StitchedWrenGifts.catalog()
	guide.wren_gift_catalog_source.by_id["point"]["name"] = "Fake Point"
	await _click(drawings)
	_check(guide.page_text(2) == "\n\n".join(StitchedFieldGuide.PAGES[2] + StitchedFieldGuide.side_door_examples()),
		"invalid catalog clears stale Wren notes without changing the door-page baseline")
	await _click(guide.tab_buttons[1])
	await _click(guide.tab_buttons[2])
	_check(guide.page_text(2) == "\n\n".join(StitchedFieldGuide.PAGES[2] + StitchedFieldGuide.side_door_examples()),
		"tab switching cannot revive rejected notes")
	await _key(KEY_ESCAPE)
	guide.wren_gift_catalog_source = null
	await _click(drawings)
	await _click(guide.tab_buttons[2])
	_assert_notes(guide, {"best_floor": 0, "boss_wins": 0}, "Reach Floor Four")
	var scrollbar := guide.page_scroll.get_v_scroll_bar()
	var travel := maxf(0.0, scrollbar.max_value - scrollbar.page)
	guide.page_scroll.scroll_vertical = int(travel)
	await process_frame
	_check(travel > 0.0 and guide.page_scroll.scroll_vertical > 0,
		"original guide content scrolls with Wren notes visible")
	await _key(KEY_ESCAPE)
	_check(root.gui_get_focus_owner() == drawings and not guide.is_open(),
		"Escape after scrolling restores bedroom focus")
	_check(room.record == room_snapshot and view.wallet_label.text == wallet and
		[view.selected_path_id(), view.selected_tinker_path_id(),
			view.selected_warden_path_id(), view._set_out_pending, view._back_pending] == navigation
		and host_commands == 0, "no bedroom, wallet, run navigation or host mutation")
	_check(FileAccess.file_exists(StitchedWrenGifts.PROFILE_PATH) == had_save and
		_saved_bytes() == save_snapshot, "no real Wren profile file created or edited")
	_check(randi() == expected_rng, "live guide and pure formatter use no global RNG")
	view.queue_free()
	await _frames()
	_finish()


func _finish() -> void:
	StitchedBedroom.enabled = before_enabled
	if failures.is_empty():
		print("stitched_s12_wren_gift_field_notes_live_test: PASS (%d checks)" % checks)
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		printerr("stitched_s12_wren_gift_field_notes_live_test: FAIL (%d/%d)" %
			[failures.size(), checks])
		quit(1)
