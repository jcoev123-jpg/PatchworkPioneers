extends SceneTree
## Source-checked S14 gold-thread warnings on the live Wren Drawings page.

const SCENE := preload("res://scenes/base_screen.tscn")
var failures: Array[String] = []
var checks := 0
var original_bedroom_enabled := true
var host_commands := 0


func _initialize() -> void:
	original_bedroom_enabled = StitchedBedroom.enabled
	StitchedBedroom.enabled = true
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _frames() -> void:
	for _i in range(3):
		await process_frame


func _click(button: Button) -> void:
	var position := button.get_global_rect().get_center()
	_check(button.is_visible_in_tree() and not button.disabled
		and root.get_visible_rect().has_point(position), "clickable " + button.name)
	var motion := InputEventMouseMotion.new()
	motion.position = position
	root.push_input(motion, true)
	await process_frame
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
		await process_frame


func _key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		root.push_input(event, true)
		await process_frame


func _pad(button: JoyButton, down: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = down
	root.push_input(event, true)
	await process_frame


func _has_digit(value: String) -> bool:
	for i in value.length():
		if value[i].is_valid_int():
			return true
	return false


func _focusable(node: Node) -> int:
	var count := 0
	if node is Control and node.is_visible_in_tree() and node.focus_mode != Control.FOCUS_NONE:
		count += 1
	for child in node.get_children():
		count += _focusable(child)
	return count


func _gold_cases(patches: Dictionary) -> Array:
	var cases: Array = []
	for id in ["gold_hungry_button", "gold_heart_knot"]:
		var missing: Dictionary = patches.duplicate(true)
		missing.by_id.erase(id)
		cases.append(["missing " + id, missing])
		var renamed: Dictionary = patches.duplicate(true)
		renamed.by_id[id]["name"] = "Other Button"
		cases.append(["renamed " + id, renamed])
		var wrong_id: Dictionary = patches.duplicate(true)
		wrong_id.by_id[id]["id"] = "gold_other"
		cases.append(["contradictory id " + id, wrong_id])
		var rarity: Dictionary = patches.duplicate(true)
		rarity.by_id[id]["rarity"] = "silk"
		cases.append(["rarity " + id, rarity])
		var effect: Dictionary = patches.duplicate(true)
		effect.by_id[id]["effect"] = "bleed"
		cases.append(["effect " + id, effect])
		var amount: Dictionary = patches.duplicate(true)
		amount.by_id[id]["amount"] = 1
		cases.append(["amount " + id, amount])
		var invalid_type: Dictionary = patches.duplicate(true)
		invalid_type.by_id[id]["amount"] = "3"
		cases.append(["non-integral schema " + id, invalid_type])
		var extra_key: Dictionary = patches.duplicate(true)
		extra_key.by_id[id]["extra"] = true
		cases.append(["extra field " + id, extra_key])
	var wrong_outer: Dictionary = patches.duplicate(true)
	wrong_outer["by_id"] = []
	cases.append(["wrong by_id schema", wrong_outer])
	wrong_outer = patches.duplicate(true)
	wrong_outer["weights"] = []
	cases.append(["wrong weights schema", wrong_outer])
	return cases


func _pure_checks() -> void:
	var patches := StitchedS14Abilities.patches().duplicate(true)
	var snapshot := patches.duplicate(true)
	_check(not patches.is_empty() and patches.get("by_id") is Dictionary,
		"shipped detached patch source exists")
	for row in [
		["gold_hungry_button", "Hungry Button", "steal", 3],
		["gold_heart_knot", "Heart Knot", "heal", 5],
	]:
		var entry: Dictionary = patches.get("by_id", {}).get(row[0], {})
		_check(entry.get("id") == row[0] and entry.get("name") == row[1]
			and entry.get("rarity") == "gold" and entry.get("effect") == row[2]
			and entry.get("amount") == row[3] and entry.size() == 5,
			"the named gold record has the exact authored id, name, rarity, effect and amount: " + row[0])
	var lines := StitchedGoldThreadNotes.examples(patches)
	_check(lines.size() == 3, "pure formatter returns all three lines")
	if lines.size() == 3:
		_check(lines[0].contains("GOLD THREAD") and lines[0].contains("second socket")
			and lines[0].contains("actual target"), "gold lesson teaches both the socket and actual-target rule")
		_check(lines[1].contains("HEART KNOT") and lines[1].contains("foe")
			and lines[1].contains("survives") and lines[1].contains("mend"),
			"Heart Knot may mend a surviving struck foe")
		_check(lines[2].contains("HUNGRY BUTTON") and lines[2].contains("ally")
			and lines[2].contains("drain") and lines[2].contains("surviving caster")
			and lines[2].contains("recovers"), "Hungry Button may drain helped ally and restore surviving caster")
		var no_stats := true
		for line in lines:
			if _has_digit(line) or line.contains("%") or line.contains(" HP ") or line.contains(" RNG "):
				no_stats = false
		_check(no_stats, "all three lines omit numbers, odds, HP forecasts and stats")
	_check(StitchedGoldThreadNotes.examples() == lines,
		"default live patch lookup matches detached input")
	_check(StitchedGoldThreadNotes.examples({}) == []
		and StitchedGoldThreadNotes.examples([]) == [],
		"empty and non-dictionary sources reject as a group")
	seed(826493)
	var rng_before := randi()
	seed(826493)
	for pair in _gold_cases(patches):
		var before: Dictionary = (pair[1] as Dictionary).duplicate(true)
		_check(StitchedGoldThreadNotes.examples(pair[1]) == [],
			"gold group rejects " + str(pair[0]))
		_check(pair[1] == before, "gold formatter never mutates " + str(pair[0]))
	_check(randi() == rng_before, "gold formatter calls no global RNG")
	_check(patches == snapshot and StitchedS14Abilities.patches() == snapshot,
		"mutations to detached negatives never poison live catalog/cache")


func _assert_page(guide: StitchedFieldGuide, patches: Dictionary,
		expect_gold: bool, expected_four: bool) -> void:
	var page := guide.page_text(1)
	var baseline := "\n\n".join(StitchedFieldGuide.PAGES[1])
	var earlier := StitchedPatchLesson.examples(StitchedS14Abilities.kits(), patches)
	var gold := StitchedGoldThreadNotes.examples(StitchedS14Abilities.patches())
	var s15 := StitchedS15FieldNotes.examples()
	_check(page.begins_with(baseline) and not baseline.is_empty(),
		"all original static Seams & retreat lines remain first")
	_check(earlier.size() == 4 and gold.size() == 3,
		"four previous examples and three gold examples have real catalog preconditions")
	var previous := baseline.length()
	for line in earlier:
		var count := page.count(line)
		var at := page.find(line)
		_check(count == (1 if expected_four else 0)
			and (not expected_four or at > previous),
			"unchanged original example occurs in order only when validated: " + line)
		if expected_four:
			previous = at
	for line in gold:
		var count := page.count(line)
		var at := page.find(line)
		_check(count == (1 if expect_gold else 0)
			and (not expect_gold or at > previous),
			"gold line occurs once after originals only when validated: " + line)
		if expect_gold:
			previous = at
	_check(s15.size() == 3, "real S15 source validates all three independent guide notes")
	for line in s15:
		var count := page.count(line)
		var at := page.find(line)
		_check(count == 1 and at > previous,
			"independent S15 line occurs once after the valid S14 portion: " + line)
		previous = at
	if not expected_four:
		_check(page == baseline + "\n\n" + "\n\n".join(s15),
			"invalid legacy lesson retains static baseline and independent validated S15")
	elif not expect_gold:
		_check(page == baseline + "\n\n" + "\n\n".join(earlier + s15),
			"invalid gold retains exactly the baseline, four originals and independent S15")
	else:
		_check(page == baseline + "\n\n" + "\n\n".join(earlier + gold + s15),
			"valid page contains all ten derived lines without duplication")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	_pure_checks()
	var view := SCENE.instantiate() as BaseScreen
	root.add_child(view)
	await _frames()
	var room := view.bedroom
	var guide := view.field_guide
	_check(room != null and guide != null and not guide.is_open(),
		"real bedroom and closed field guide mount")
	if room == null or guide == null:
		view.queue_free()
		_finish()
		return
	var drawings := room.spot("drawings")
	_check(drawings != null and drawings == view.guide_button,
		"Wren Drawings is the real existing guide entry")
	_check(view.open_village(31, 7), "real village bedroom opens at 1280x720")
	await _frames()
	var patches := StitchedS14Abilities.patches().duplicate(true)
	var patch_snapshot := patches.duplicate(true)
	var room_snapshot: Dictionary = room.record.duplicate(true)
	var wallet := view.wallet_label.text
	var choice_snapshot := [view.selected_path_id(), view.selected_tinker_path_id(),
		view.selected_warden_path_id(), view._set_out_pending, view._back_pending]
	view.back_requested.connect(func() -> void: host_commands += 1)
	view.set_out_requested.connect(func() -> void: host_commands += 1)
	view.path_choice_requested.connect(func(_id: String) -> void: host_commands += 1)
	seed(190649)
	var rng_before := randi()
	seed(190649)
	await _click(drawings)
	_check(guide.is_open() and root.gui_get_focus_owner() == guide.tab_buttons[0],
		"Drawings opens original guide with first tab focused")
	_check(guide.tab_buttons.size() == 4 and guide.page_labels.size() == 4
		and guide.TABS == ["Ranks & turns", "Seams & retreat", "Fray & resolve", "Candle & stops"],
		"all four guide tabs and pages stay unchanged")
	_check(guide.get_child_count() == 2 and guide.get_node("FeltPanel") is NinePatchRect
		and guide.theme == null and _focusable(guide) == 6,
		"same felt artwork, inherited theme and six-control focus ring, no added controls")
	for i in [0, 2]:
		_check(guide.page_text(i) == "\n\n".join(StitchedFieldGuide.PAGES[i]),
			"other guide page stays exactly unchanged: " + str(i))
	var door_examples := StitchedFieldGuide.side_door_examples()
	_check(door_examples.size() == 4 and guide.page_text(3) == "\n\n".join(
		StitchedFieldGuide.PAGES[3] + door_examples),
		"Candle page keeps its original baseline and exactly four validated S14 door notes")
	await _click(guide.tab_buttons[1])
	_check(guide.page_index == 1 and guide.page_labels[1].is_visible_in_tree(),
		"existing Seams tab is reachable by pointer")
	_assert_page(guide, patches, true, true)
	var scroll := guide.page_scroll.get_v_scroll_bar()
	_check(guide.page_scroll.is_visible_in_tree() and scroll != null
		and guide.page_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
		"original page ScrollContainer is visible with no horizontal scrolling")
	var travel := maxf(0.0, scroll.max_value - scroll.page)
	guide.page_scroll.scroll_vertical = int(travel)
	await process_frame
	_check(travel > 0.0 and guide.page_scroll.scroll_vertical > 0,
		"1280x720 lesson overflows vertically and can scroll down")
	guide.page_scroll.scroll_vertical = 0
	await _key(KEY_RIGHT)
	_check(guide.page_index == 2 and root.gui_get_focus_owner() == guide.tab_buttons[2],
		"keyboard turns original tab while keeping focus inside ring")
	await _click(guide.close_button)
	_check(not guide.is_open() and root.gui_get_focus_owner() == drawings,
		"pointer Close restores Drawings focus")
	guide.lesson_patches = patches.duplicate(true)
	await _click(drawings)
	await _click(guide.tab_buttons[1])
	_assert_page(guide, patches, true, true)
	for bad in _gold_cases(patches).slice(0, 2):
		guide.lesson_patches = (bad[1] as Dictionary).duplicate(true)
		await _key(KEY_ESCAPE)
		_check(not guide.is_open() and root.gui_get_focus_owner() == drawings,
			"Escape closes and restores Drawings focus before bad gold reload")
		await _click(drawings)
		await _click(guide.tab_buttons[1])
		_assert_page(guide, patches, false, true)
	guide.lesson_patches = patches.duplicate(true)
	await _key(KEY_ESCAPE)
	await _click(drawings)
	await _click(guide.tab_buttons[1])
	_assert_page(guide, patches, true, true)
	var invalid_kits := StitchedS14Abilities.kits().duplicate(true)
	invalid_kits["seamstress"].erase("head")
	guide.lesson_kits = invalid_kits
	await _key(KEY_ESCAPE)
	await _click(drawings)
	await _click(guide.tab_buttons[1])
	_assert_page(guide, patches, false, false)
	guide.lesson_kits = null
	await _key(KEY_ESCAPE)
	await _click(drawings)
	await _click(guide.tab_buttons[1])
	_assert_page(guide, patches, true, true)
	await _click(guide.atlas_button)
	_check(guide._atlas_is_open() and guide.part_atlas.is_visible_in_tree(),
		"original Parts & spoils atlas remains reachable without added controls")
	await _pad(JOY_BUTTON_B, true)
	_check(guide.is_open() and not guide._atlas_is_open()
		and root.gui_get_focus_owner() == guide.atlas_button,
		"controller B dismisses just the nested atlas")
	await _pad(JOY_BUTTON_B, true)
	_check(guide.is_open(), "held controller B never double-dismisses")
	await _pad(JOY_BUTTON_B, false)
	await _pad(JOY_BUTTON_B, true)
	_check(not guide.is_open() and root.gui_get_focus_owner() == drawings,
		"fresh controller B dismisses guide and restores Drawings")
	await _pad(JOY_BUTTON_B, false)
	_check(room.record == room_snapshot and view.wallet_label.text == wallet
		and [view.selected_path_id(), view.selected_tinker_path_id(),
			view.selected_warden_path_id(), view._set_out_pending, view._back_pending] == choice_snapshot
		and host_commands == 0 and randi() == rng_before
		and patches == patch_snapshot and StitchedS14Abilities.patches() == patch_snapshot,
		"guide never mutates room/party, wallet, choices, host commands, RNG or patch catalog")
	view.queue_free()
	await _frames()
	_finish()


func _finish() -> void:
	StitchedBedroom.enabled = original_bedroom_enabled
	if failures.is_empty():
		print("stitched_s14_gold_thread_field_notes_live_test: PASS (%d checks)" % checks)
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		printerr("stitched_s14_gold_thread_field_notes_live_test: FAIL (%d/%d)" % [failures.size(), checks])
		quit(1)
