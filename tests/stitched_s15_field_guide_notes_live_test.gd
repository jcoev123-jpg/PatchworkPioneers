extends SceneTree
## S15's resistance/Rot teaching goes through Wren's actual bedroom Drawings entry.

const SCENE := preload("res://scenes/base_screen.tscn")
var failures: Array[String] = []
var checks := 0
var original_bedroom_enabled := false
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
	var at := button.get_global_rect().get_center()
	_check(button.is_visible_in_tree() and not button.disabled
		and root.get_visible_rect().has_point(at), "real clickable " + button.name)
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


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame


func _has_number(text: String) -> bool:
	for c in text:
		if c.is_valid_int():
			return true
	return text.contains("%")


func _focusable(node: Node) -> int:
	var count := 0
	if node is Control and node.is_visible_in_tree() \
			and node.focus_mode != Control.FOCUS_NONE:
		count += 1
	for child in node.get_children():
		count += _focusable(child)
	return count


func _invalid_cases(source: Dictionary) -> Array:
	var cases: Array = [
		["missing source", {}],
		["bad source type", []],
		["empty contract", {"resists": {}, "rot_attacks": {}}],
	]
	var bad := source.duplicate(true)
	bad.erase("rot_attacks")
	cases.append(["missing rot table", bad])
	bad = source.duplicate(true)
	bad["resists"] = []
	cases.append(["non-dictionary resists", bad])
	bad = source.duplicate(true)
	bad.resists["ragling"].erase("rot")
	cases.append(["missing resistance group", bad])
	bad = source.duplicate(true)
	bad.resists["ragling"]["rot"] = 91
	cases.append(["out-of-contract resist", bad])
	bad = source.duplicate(true)
	bad.resists["ragling"]["bleed"] = "20"
	cases.append(["untyped resist", bad])
	bad = source.duplicate(true)
	bad.resists["ragling"]["fire"] = 10
	cases.append(["unknown resistance group", bad])
	bad = source.duplicate(true)
	bad.rot_attacks.erase("moth_swarm")
	cases.append(["missing mildew carrier", bad])
	bad = source.duplicate(true)
	bad.rot_attacks["moth_swarm"]["wing_dust"] = 9
	cases.append(["impossible rot duration", bad])
	bad = source.duplicate(true)
	bad.rot_attacks["moth_swarm"]["wing_dust"] = 1
	cases.append(["contradictory authored mildew", bad])
	bad = source.duplicate(true)
	bad.rot_attacks["unknown_foe"] = {"spores": 2}
	cases.append(["rot absent from resistance roster", bad])
	bad = source.duplicate(true)
	bad["extra"] = true
	cases.append(["unexpected top-level schema", bad])
	return cases


func _pure_checks() -> void:
	var source: Dictionary = StitchedDeeperSeams.table()
	var snapshot := source.duplicate(true)
	_check(not source.is_empty() and source.get("resists") is Dictionary
		and source.get("rot_attacks") is Dictionary, "real validated S15 source exists")
	_check(StitchedRules.RESIST_KEYS == ["stun", "bleed", "rot", "move", "debuff"]
		and StitchedRules.RESIST_MAX == 90, "rules own all five foe resist groups and upper bound")
	_check(StitchedRules.PATCH_PIERCE == {"cotton": 0, "wool": 15, "silk": 30, "gold": 100},
		"rules own ordered cotton/wool/silk/gold resistance piercing")
	_check(StitchedRules.ROT_TICK == 2
		and StitchedRules.rot_heal({"statuses": {"rot": 1}}, 5) == 2
		and StitchedRules.rot_heal({"statuses": {}}, 5) == 5,
		"rules' rot deals through protection and halves odd healing rounded down")
	_check(StitchedDeeperSeams.DEPTH_HP_PERCENT == 5
		and StitchedDeeperSeams.DEPTH_DMG_FLOORS == 4
		and StitchedDeeperSeams.BOSS_HP_PERCENT == 60
		and StitchedDeeperSeams.BOSS_DMG_PERCENT == 70,
		"current S15 source owns deeper ordinary foes and softer boss tuning")
	_check(source.resists.has("ragling") and source.resists["ragling"].size() == 5
		and source.rot_attacks["moth_swarm"].get("wing_dust") == 2
		and source.rot_attacks["moth_queen"].get("queen_dust") == 3,
		"shipped authored resists and mildew attacks are real")
	var lines := StitchedS15FieldNotes.examples(source)
	_check(lines.size() == 3 and lines == StitchedS15FieldNotes.examples(),
		"detached S15 table and default live table agree on three complete notes")
	if lines.size() == 3:
		_check(lines[0].begins_with("SEAM RESISTS  |")
			and lines[0].contains("landed") and lines[0].contains("stun")
			and lines[0].contains("bleed") and lines[0].contains("rot")
			and lines[0].contains("pull/push") and lines[0].contains("debuff")
			and lines[0].contains("damage is separate"),
			"first note separates a landed hit's damage from five resistible effects")
		_check(lines[1].begins_with("PATCH THREAD  |")
			and lines[1].contains("Cotton cannot") and lines[1].contains("wool helps")
			and lines[1].contains("silk helps more") and lines[1].contains("gold")
			and lines[1].contains("sewn effect") and lines[1].contains("does not guarantee")
			and not lines[1].contains("Wren's hand"),
			"thread piercing is not attack certainty and no retired hand is advertised")
		_check(lines[2].begins_with("ROT  |")
			and lines[2].contains("Mildew") and lines[2].contains("stuffing protection")
			and lines[2].contains("healing") and lines[2].contains("farther down"),
			"third note teaches rot through PROT, weaker healing and deeper foes")
		for line in lines:
			_check(not _has_number(line) and not line.contains("always hits")
				and not line.contains("legal target"), "each S15 note has no stats or false hit guarantee")
	seed(419815)
	var rng_before := randi()
	seed(419815)
	for row in _invalid_cases(source):
		var bad: Variant = row[1]
		var copied: Variant = bad.duplicate(true)
		_check(StitchedS15FieldNotes.examples(bad).is_empty(),
			"S15 refuses detached " + str(row[0]))
		_check(bad == copied, "S15 leaves detached " + str(row[0]) + " untouched")
	_check(randi() == rng_before, "the formatter uses no global RNG")
	_check(source == snapshot and StitchedDeeperSeams.table() == snapshot,
		"negative copies do not mutate the real S15 table")
	_check(StitchedS15FieldNotes.examples(source) == lines,
		"subsequent good source recovers after every invalid copy")


func _assert_page(guide: StitchedFieldGuide, show_s15: bool) -> void:
	var baseline: Array = StitchedFieldGuide.PAGES[1].duplicate()
	var lessons := StitchedPatchLesson.examples()
	var gold := StitchedGoldThreadNotes.examples()
	var s15 := StitchedS15FieldNotes.examples()
	_check(lessons.size() == 4 and gold.size() == 3 and s15.size() == 3,
		"mounted page has valid four old examples, three gold notes and three S15 notes")
	var expected: Array = baseline.duplicate()
	expected.append_array(lessons)
	expected.append_array(gold)
	if show_s15:
		expected.append_array(s15)
	var page := guide.page_text(1)
	_check(page == "\n\n".join(expected) and guide.page_labels[1].text == page,
		"actual Seams page matches static baseline plus all validated notes in order")
	for line in lessons + gold:
		_check(page.count(line) == 1, "one unchanged S14 lesson remains: " + line)
	for line in s15:
		_check(page.count(line) == (1 if show_s15 else 0),
			"no duplicate or stale S15 line: " + line)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	_pure_checks()
	var view := SCENE.instantiate() as BaseScreen
	root.add_child(view)
	await _frames()
	var room := view.bedroom
	var guide := view.field_guide
	_check(room != null and guide != null and not guide.is_open(),
		"actual BaseScreen starts with a mounted bedroom and closed guide")
	if room == null or guide == null:
		view.queue_free()
		_finish()
		return
	var drawings := room.spot("drawings")
	_check(drawings != null and drawings == view.guide_button,
		"bedroom Drawings is the actual existing Guide entry")
	_check(view.open_village(31, 7), "real bedroom opens")
	await _frames()
	var initial_room: Dictionary = room.record.duplicate(true)
	var initial_wallet := view.wallet_label.text
	var initial_host := [view.selected_path_id(), view.selected_tinker_path_id(),
		view.selected_warden_path_id(), view._set_out_pending, view._back_pending]
	view.back_requested.connect(func() -> void: host_commands += 1)
	view.set_out_requested.connect(func() -> void: host_commands += 1)
	view.path_choice_requested.connect(func(_id: String) -> void: host_commands += 1)
	guide.wren_gift_profile_source = {"best_floor": 0, "boss_wins": 0}
	seed(819215)
	var expected_rng := randi()
	seed(819215)
	await _click(drawings)
	_check(guide.is_open() and root.gui_get_focus_owner() == guide.tab_buttons[0],
		"real Drawings opens guide on first focused tab")
	_check(guide.TABS == ["Ranks & turns", "Seams & retreat", "Candle & stops"]
		and guide.tab_buttons.size() == 3 and guide.page_labels.size() == 3
		and guide.get_node("FeltPanel/GuideContent/GuideTabs").get_child_count() == 3,
		"owner 11-10: three tabs and pages after Fray & resolve retired, without extra controls")
	_check(_focusable(guide) == 5 and guide.get_child_count() == 2
		and guide.get_node("FeltPanel") is NinePatchRect and guide.theme == null,
		"owner 11-10: five-focus ring and inherited gothic felt panel remain")
	for index in [0]:
		_check(guide.page_text(index) == "\n\n".join(StitchedFieldGuide.PAGES[index]),
			"non-Seams page remains precisely unchanged: " + str(index))
	var gift_notes := StitchedWrenGiftFieldNotes.examples({"best_floor": 0, "boss_wins": 0})
	var door_examples := StitchedFieldGuide.side_door_examples()
	_check(gift_notes.size() == 3 and door_examples.size() == 3 and guide.page_text(2) == "\n\n".join(
		StitchedFieldGuide.PAGES[2] + door_examples) and not guide.page_text(2).contains("WREN'S HAND"),
		"owner 11-10: Candle page preserves three usable doors, omits retired hand advice")
	await _click(guide.tab_buttons[1])
	_check(guide.page_index == 1 and guide.page_labels[1].is_visible_in_tree(),
		"existing second tab is opened by real pointer input")
	_assert_page(guide, true)
	var scrollbar := guide.page_scroll.get_v_scroll_bar()
	var travel := maxf(0.0, scrollbar.max_value - scrollbar.page)
	var felt_rect := (guide.get_node("FeltPanel") as Control).get_global_rect()
	_check(guide.page_scroll.get_global_rect().end.x <= felt_rect.end.x - 170.0
		and guide.page_scroll.get_global_rect().end.y <= felt_rect.end.y - 125.0,
		"guide notes stay inside the right and bottom stitched edges")
	await _key(KEY_END)
	_check(travel > 0.0 and guide.page_scroll.scroll_vertical >= int(travel) - 2,
		"End reveals the final Field Notes paragraphs without requiring scroll focus")
	await _key(KEY_HOME)
	_check(guide.page_scroll.scroll_vertical == 0,
		"Home brings the first Field Notes paragraph back into view")
	await _click(guide.atlas_button)
	_check(guide._atlas_is_open() and not guide.get_node("FeltPanel").visible,
		"opening Parts & spoils replaces, rather than stacks over, the guide panel")
	if guide._atlas_is_open():
		await _click(guide.part_atlas.get_node("CloseButton") as Button)
		_check(not guide._atlas_is_open() and guide.get_node("FeltPanel").visible
			and root.gui_get_focus_owner() == guide.atlas_button,
			"closing Parts & spoils restores the guide and the triggering button")
	guide.page_scroll.scroll_vertical = int(travel)
	await process_frame
	_check(guide.page_scroll.scroll_vertical > 0,
		"original scrolling page can reach the appended S15 notes")
	guide.page_scroll.scroll_vertical = 0
	await _key(KEY_ESCAPE)
	_check(not guide.is_open() and root.gui_get_focus_owner() == drawings,
		"Escape closes original Guide and restores Drawings focus")
	await _click(drawings)
	await _click(guide.tab_buttons[1])
	_assert_page(guide, true)
	guide.s15_source = {}
	await _click(guide.close_button)
	await _click(drawings)
	await _click(guide.tab_buttons[1])
	_assert_page(guide, false)
	var broken: Dictionary = StitchedDeeperSeams.table()
	broken.resists["ragling"]["rot"] = 91
	guide.s15_source = broken
	await _key(KEY_ESCAPE)
	await _click(drawings)
	await _click(guide.tab_buttons[1])
	_assert_page(guide, false)
	guide.s15_source = StitchedDeeperSeams.table()
	await _key(KEY_ESCAPE)
	await _click(drawings)
	await _click(guide.tab_buttons[1])
	_assert_page(guide, true)
	guide.s15_source = null
	await _click(guide.close_button)
	_check(not guide.is_open() and root.gui_get_focus_owner() == drawings,
		"Close still returns focus to Drawings")
	_check(room.record == initial_room and view.wallet_label.text == initial_wallet
		and [view.selected_path_id(), view.selected_tinker_path_id(),
			view.selected_warden_path_id(), view._set_out_pending, view._back_pending] == initial_host
		and host_commands == 0 and randi() == expected_rng,
		"guide open/turn/close/reopen does not change room state, wallet, host commands or RNG")
	view.queue_free()
	await _frames()
	_finish()


func _finish() -> void:
	StitchedBedroom.enabled = original_bedroom_enabled
	if failures.is_empty():
		print("stitched_s15_field_guide_notes_live_test: PASS (%d checks)" % checks)
		quit(0)
	else:
		for message in failures:
			printerr("FAIL: " + message)
		printerr("stitched_s15_field_guide_notes_live_test: FAIL (%d/%d)" % [failures.size(), checks])
		quit(1)
