extends SceneTree
## Mounted New Run keyboard picks: real viewport events, real tiles/receipt.
const SCENE := "res://scenes/v3_party_picker.tscn"
const IDS: Array[String] = [
	"warden", "seamstress", "tinker", "lantern_monk",
	"rag_duelist", "scarecrow", "yarn_ranger", "button_golem"]
const NAMES := [
	"Warden", "Seamstress", "Tinker", "Lantern Monk",
	"Rag Duelist", "Scarecrow", "Yarn Ranger", "Button Golem"]
const BASE := "PaperPanel/Margins/Body/"
var failures: Array[String] = []
var checks := 0
var requested: Array = []
var cancelled := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures.append(note)


func _frames() -> void:
	for i in range(4):
		await process_frame


func _tile(picker: LiveV3PartyPicker, index: int) -> Button:
	return picker.get_node_or_null(BASE + "HeroGrid/Hero_" + IDS[index]) as Button


func _event(code: Key, down: bool, echo: bool = false, modifier: String = "") -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = down
	e.echo = echo
	match modifier:
		"shift": e.shift_pressed = true
		"control": e.ctrl_pressed = true
		"alt": e.alt_pressed = true
		"meta": e.meta_pressed = true
	root.push_input(e, true)
	await _frames()


func _key(code: Key) -> void:
	await _event(code, true)
	await _event(code, false)


func _click(button: Button) -> void:
	_check(button != null and button.is_visible_in_tree() and not button.disabled,
		"real mouse click target available")
	if button == null or not button.is_visible_in_tree() or button.disabled:
		return
	var at := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	root.push_input(motion, true)
	await _frames()
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = at
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		root.push_input(e, true)
		await process_frame
	await _frames()


func _on_party(ids: Array[String]) -> void:
	requested.append(ids.duplicate())


func _on_cancel() -> void:
	cancelled += 1


func _state(picker: LiveV3PartyPicker) -> Array:
	return [picker.selected_ids(), picker._seat_receipt.duplicate(true),
		picker.continue_button.disabled, requested.size(), cancelled]


func _picks(picker: LiveV3PartyPicker, ids: Array[String], note: String) -> void:
	_check(picker.selected_ids() == ids, note + " ordered selection")
	_check(picker.selection_count.text == "Selected %d/3" % ids.size(),
		note + " visible pick count")
	_check(picker.continue_button.disabled == (ids.size() != 3),
		note + " exact Continue gate")
	if ids.size() != 3:
		_check(picker._seat_receipt.is_empty() and picker.seat_preview.text ==
			"Choose three to preview battle seats", note + " neutral seat preview")
		return
	var receipt := RunV3PartyAdmission.admit(ids)
	_check(receipt.get("ok", false) and receipt["deck"].size() == 12
		and receipt["hero_ids"].size() == 3 and receipt["party"].size() == 3,
		note + " canonical admitted three-hero twelve-occurrence deck")
	_check(picker._seat_receipt == receipt, note + " exact authenticated receipt")
	var seats: Array[String] = []
	for i in range(3):
		seats.append("%d %s" % [i + 1, receipt["party"][i]["name"]])
	_check(picker.seat_preview.text == "Seats: " + "  |  ".join(seats),
		note + " same sorted canonical seats, independent of pick order")


func _check_tiles(picker: LiveV3PartyPicker) -> void:
	var bounds := Rect2(Vector2.ZERO, Vector2(1280, 720))
	_check(picker.grid.columns == 4 and picker.grid.get_child_count() == 8,
		"eight actual 4-column, 2-row mounted tiles")
	var subtitle := picker.get_node(BASE + "SubTitle") as Label
	_check(subtitle.is_visible_in_tree() and subtitle.text.contains("1–8")
		and subtitle.text.contains("pick") and subtitle.text.contains("undo"),
		"concise visible keyboard help")
	for i in range(8):
		var tile := _tile(picker, i)
		_check(tile != null and tile.is_visible_in_tree() and
			bounds.encloses(tile.get_global_rect()) and not tile.disabled,
			"authentic tile %d visible and clickable" % (i + 1))
		if tile == null:
			continue
		var cue := tile.get_node_or_null("KeyCue") as Label
		var name := tile.get_node_or_null("Inset/Stack/NameLabel") as Label
		var motif := tile.get_node_or_null("Inset/Stack/MotifLabel") as Label
		var face := tile.get_node_or_null("Inset/Stack/Face") as Control
		var pick := tile.get_node_or_null("Inset/Stack/PickLabel") as Label
		_check(cue != null and name != null and motif != null and face != null and pick != null,
			"tile %d preserves cue, name, face, motif and pick controls" % (i + 1))
		if cue == null or name == null or motif == null or face == null or pick == null:
			continue
		_check(cue.text == str(i + 1) and cue.is_visible_in_tree()
			and cue.get_theme_font_size("font_size") >= 14
			and tile.get_global_rect().encloses(cue.get_global_rect())
			and cue.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"tile %d has a small readable non-intercepting number ticket" % (i + 1))
		var printed_width := name.get_theme_font("font").get_string_size(name.text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, name.get_theme_font_size("font_size")).x
		var name_left := name.get_global_rect().get_center().x - printed_width / 2.0
		_check(name.text == NAMES[i] and cue.get_global_rect().end.x < name_left
			and name.get_global_rect().size.x >= printed_width
			and name.is_visible_in_tree(),
			"tile %d exact original name has no overlapping key glyph" % (i + 1))
		_check(motif.is_visible_in_tree() and not motif.text.is_empty()
			and pick.is_visible_in_tree() and face.is_visible_in_tree()
			and face.size.y >= 60 and face.get_child_count() == 2
			and (face.get_child(0).name == "Portrait" or face.get_child(0).name == "FallbackMotif")
			and face.get_child(1).name == "SeatBadge"
			and face.get_child(1) is Label
			and face.get_child(1).mouse_filter == Control.MOUSE_FILTER_IGNORE
			and not face.get_child(1).visible
			and (face.get_child(1) as Label).text.is_empty(),
			"tile %d original portrait/fallback and labels remain present" % (i + 1))
		_check(tile.get_global_rect().encloses(face.get_global_rect()),
			"tile %d face bounded: %s vs %s" % [i + 1, tile.get_global_rect(), face.get_global_rect()])
		_check(tile.get_global_rect().encloses(motif.get_global_rect()),
			"tile %d motif bounded: %s vs %s" % [i + 1, tile.get_global_rect(), motif.get_global_rect()])
		_check(tile.get_global_rect().encloses(pick.get_global_rect()),
			"tile %d pick bounded: %s vs %s" % [i + 1, tile.get_global_rect(), pick.get_global_rect()])
		if i > 0 and i % 4 != 0:
			_check(absf(tile.position.y - _tile(picker, i - 1).position.y) < 2,
				"tile %d on same row" % (i + 1))
		if i == 4:
			_check(tile.position.y > _tile(picker, 0).position.y + 100,
				"second row stays below the first")
	for path in ["Title", "SubTitle", "HeroGrid", "InspectionPanel", "Foot",
			"Foot/Hint", "Foot/CancelButton", "Foot/ContinueButton"]:
		var ctrl := picker.get_node(BASE + path) as Control
		_check(ctrl.is_visible_in_tree() and bounds.encloses(ctrl.get_global_rect()),
			"original screen control stays on screen: " + path)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var packed := load(SCENE) as PackedScene
	_check(packed != null, "actual live picker scene loads")
	if packed == null:
		_finish()
		return
	var picker := packed.instantiate() as LiveV3PartyPicker
	root.add_child(picker)
	await _frames()
	picker.party_requested.connect(_on_party)
	picker.cancel_requested.connect(_on_cancel)
	_check(picker._open and not picker._latched and picker.is_visible_in_tree()
		and root.gui_get_focus_owner() == null,
		"fresh visible opening has neutral focus without click")
	_check(picker.inspection_heading.text == "HOVER OR FOCUS A HERO TO INSPECT"
		and picker.inspection_starters.text.is_empty()
		and not picker._deck_mode and not picker._kit_mode and not picker._reward_mode,
		"neutral uninspected hero readout is intact")
	_check_tiles(picker)
	_picks(picker, [], "fresh")

	# Every physical top-row/bottom-row digit and matching keypad key both
	# toggles its real tile on and off, with no duplicate event on release.
	for i in range(8):
		await _key(KEY_1 + i as Key)
		_picks(picker, [IDS[i]], "main digit %d" % (i + 1))
		await _key(KEY_1 + i as Key)
		_picks(picker, [], "main digit %d undo" % (i + 1))
		await _key(KEY_KP_1 + i as Key)
		_picks(picker, [IDS[i]], "keypad %d" % (i + 1))
		await _key(KEY_KP_1 + i as Key)
		_picks(picker, [], "keypad %d undo" % (i + 1))
	_check(requested.is_empty() and cancelled == 0, "digits only select, never emit actions")

	# Mouse click and key must take the same existing generation-bound path.
	await _click(_tile(picker, 5))
	_picks(picker, ["scarecrow"], "mouse Scarecrow selection")
	await _key(KEY_6)
	_picks(picker, [], "digit toggles mouse pick off")
	await _key(KEY_6)
	await _click(_tile(picker, 5))
	_picks(picker, [], "mouse toggles keyboard pick off")

	await _key(KEY_8)
	await _key(KEY_4)
	await _key(KEY_2)
	_picks(picker, ["button_golem", "lantern_monk", "seamstress"],
		"three keys with nontrivial tied positions")
	var fixed := _state(picker)
	await _key(KEY_1)
	_check(_state(picker) == fixed, "fourth new hero ignored without receipt or signals")
	await _key(KEY_4)
	_picks(picker, ["button_golem", "seamstress"], "selected hero can undo at capacity")
	await _key(KEY_KP_5)
	var trio: Array[String] = ["button_golem", "seamstress", "rag_duelist"]
	_picks(picker, trio, "replacement hero via keypad")
	_check(requested.is_empty() and cancelled == 0,
		"complete keyboard preview is read-only until deliberate Continue")

	var frozen := _state(picker)
	await _event(KEY_2, false)
	await _event(KEY_2, true, true)
	for modifier in ["shift", "control", "alt", "meta"]:
		await _event(KEY_3, true, false, modifier)
		await _event(KEY_3, false, false, modifier)
	await _key(KEY_0)
	await _key(KEY_9)
	await _key(KEY_KP_0)
	await _key(KEY_A)
	_check(_state(picker) == frozen, "release, echo, every modifier and unrelated keys ignored")

	# Focus on another active view cannot redirect the picker's global keys.
	var external := Button.new()
	external.name = "OtherScreenAction"
	external.text = "Unrelated action"
	external.focus_mode = Control.FOCUS_ALL
	external.position = Vector2(0, 0)
	root.add_child(external)
	await _frames()
	external.grab_focus()
	await _frames()
	_check(external.has_focus(), "real unrelated screen control owns viewport focus")
	await _key(KEY_8)
	_check(_state(picker) == frozen, "externally focused control isolates picker")
	external.release_focus()
	external.queue_free()
	await _frames()

	picker.hide()
	await _key(KEY_8)
	_check(_state(picker) == frozen, "hidden but open instance refuses digit")
	picker.show()
	await _frames()

	# Inspect each nested readout and return: selection stays frozen inside.
	_tile(picker, 0).grab_focus()
	await _frames()
	_check(picker.inspection_heading.text.contains("Warden"),
		"real focused hero inspection available from keyboard")
	picker.inspect_cards_button.pressed.emit()
	_check(picker._kit_mode and picker.kit_readout.is_visible_in_tree(),
		"Starter Cards inspection really opened")
	await _key(KEY_8)
	_check(_state(picker) == frozen, "Starter Cards prevents digit pick")
	picker.kit_next.pressed.emit()
	_check(picker._kit_index == 1, "Starter Next still navigates")
	picker.kit_previous.pressed.emit()
	_check(picker._kit_index == 0, "Starter Previous still navigates")
	picker.kit_back.pressed.emit()
	_check(not picker._kit_mode, "Starter Back returns to hero grid")

	picker.reward_cards_button.pressed.emit()
	_check(picker._reward_mode and picker.reward_readout.is_visible_in_tree()
		and not picker._reward_candidates.is_empty(),
		"Reward Cards inspection opens with real authored candidates")
	await _key(KEY_KP_8)
	_check(_state(picker) == frozen, "Reward Cards prevents keypad pick")
	picker.reward_back.pressed.emit()
	_check(not picker._reward_mode, "Reward Back returns to hero grid")

	picker.inspect_deck_button.pressed.emit()
	_check(picker._deck_mode and picker.deck_readout.is_visible_in_tree(),
		"canonical shared Deck inspection really opened")
	await _key(KEY_1)
	_check(_state(picker) == frozen, "Deck mode prevents digit pick")
	picker.inspect_deck_button.pressed.emit()
	_check(not picker._deck_mode, "Deck Back returns to hero grid")

	await _key(KEY_8)
	_picks(picker, ["seamstress", "rag_duelist"], "hero-grid keyboard resumes after inspect")
	await _key(KEY_8)
	trio = ["seamstress", "rag_duelist", "button_golem"]
	_picks(picker, trio, "hero-grid reselect appends at end of pick order")
	var exact := RunV3PartyAdmission.admit(trio)
	_check(exact.get("ok", false) and picker._seat_receipt == exact
		and exact["deck"].size() == 12, "Continue uses the authentic successful receipt")
	picker.continue_button.grab_focus()
	await _frames()
	_check(picker.continue_button.has_focus() and not picker.continue_button.disabled,
		"keyboard-only Continue can own focus")
	await _key(KEY_ENTER)
	_check(requested.size() == 1 and requested[0] == trio and cancelled == 0,
		"focused Enter requests exactly the original ordered trio once")
	_check(not picker._open and picker._latched and picker.continue_button.disabled,
		"confirmed picker is latched")
	var confirmed := picker.selected_ids()
	await _key(KEY_1)
	await _key(KEY_KP_3)
	await _key(KEY_ENTER)
	picker.continue_button.pressed.emit()
	_check(picker.selected_ids() == confirmed and requested.size() == 1 and cancelled == 0,
		"latched Continue rejects digits and duplicate emission")

	var retired_generation := picker._generation
	var retired_button := _tile(picker, 0)
	picker.open_picker()
	# The former tile still exists until the queued deletion is flushed;
	# its bound pressed callback must fail closed in the new generation.
	_check(is_instance_valid(retired_button) and retired_button.get_parent() == null,
		"old button detached immediately on reopen")
	retired_button.pressed.emit()
	await _frames()
	_check(picker._generation > retired_generation and root.gui_get_focus_owner() == null
		and picker._open and picker.selected_ids().is_empty()
		and picker.inspection_heading.text == "HOVER OR FOCUS A HERO TO INSPECT",
		"reopen clears focus, selection, mode and stale preview")
	picker._pressed_hero("warden", retired_generation)
	_picks(picker, [], "stale generation refused")
	await _key(KEY_1)
	_picks(picker, ["warden"], "fresh generation remains usable")
	picker.cancel_button.grab_focus()
	await _key(KEY_ENTER)
	_check(cancelled == 1 and requested.size() == 1 and picker._latched
		and not picker._open and not picker.visible, "focused Cancel emits once and hides")
	var before := picker.selected_ids()
	await _key(KEY_2)
	await _key(KEY_KP_2)
	picker._pressed_hero("tinker", retired_generation)
	picker.cancel_button.pressed.emit()
	_check(picker.selected_ids() == before and cancelled == 1 and requested.size() == 1,
		"cancelled/hidden/stale screen never selects or re-emits")
	picker.open_picker()
	await _frames()
	await _key(KEY_KP_7)
	_picks(picker, ["yarn_ranger"], "fresh post-Cancel reopen keypad works")
	picker.queue_free()
	await _frames()
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("PASS live_v3_party_hotkeys_test: %d assertions" % checks)
		quit(0)
	else:
		for reason in failures:
			printerr("FAIL: " + reason)
		printerr("FAIL live_v3_party_hotkeys_test: %d/%d" % [failures.size(), checks])
		quit(1)
