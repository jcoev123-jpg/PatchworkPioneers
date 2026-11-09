extends SceneTree
## Real 1280x720 title-mounted New Run picker: one physical Shift+digit
## exchanges the focused original doll, never the selected rank or a fifth tile.

const DEFAULT := ["warden", "seamstress", "tinker", "lantern_monk"]
const FIRST := ["rag_duelist", "seamstress", "tinker", "lantern_monk"]
const STRANDED := ["rag_duelist", "seamstress", "tinker", "warden"]
const SAVE := "user://stitched_s6_one_step_party_replace_live_test.save"

var checks := 0
var failures: Array[String] = []
var receipts: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _key(code: Key, pressed: bool = true, shifted: bool = false,
		echo: bool = false, modifier: String = "", physical: Key = KEY_NONE) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = physical if physical != KEY_NONE else code
	event.pressed = pressed
	event.echo = echo
	event.shift_pressed = shifted
	event.ctrl_pressed = modifier == "ctrl"
	event.alt_pressed = modifier == "alt"
	event.meta_pressed = modifier == "meta"
	Input.parse_input_event(event)
	await process_frame


func _stroke(code: Key, shifted: bool = false) -> void:
	await _key(code, true, shifted)
	await _key(code, false, shifted)


func _joy(button: JoyButton, down: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.device = 0
	event.pressed = down
	event.pressure = 1.0 if down else 0.0
	Input.parse_input_event(event)
	await process_frame


func _click(button: Button) -> void:
	if not is_instance_valid(button) or not button.is_visible_in_tree() or button.disabled:
		_check(false, "real pointer action requires a visible enabled Button")
		return
	await process_frame
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	await process_frame
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
		await process_frame


func _receipt(picks: Array) -> void:
	receipts.append(picks.duplicate())


func _visual_ids(picker: StitchedRunPartyPicker) -> Array:
	var result: Array = []
	for child in picker.get_children():
		result.append(child.get_meta("hero_id", ""))
	return result


func _pressed(picker: StitchedRunPartyPicker) -> Dictionary:
	var result := {}
	for id in StitchedPartyAdmission.HERO_IDS:
		var tile: Button = picker.tiles.get(id)
		if is_instance_valid(tile):
			result[id] = tile.button_pressed
	return result


func _snapshot(app: Node, picker: StitchedRunPartyPicker) -> Dictionary:
	return {
		"selected": picker.selected_ids(),
		"app": app.stitched_run_draft.duplicate(),
		"pressed": _pressed(picker),
		"order": _visual_ids(picker),
		"receipts": receipts.size(),
	}


func _unchanged(app: Node, picker: StitchedRunPartyPicker,
		before: Dictionary, message: String) -> void:
	_check(picker.selected_ids() == before["selected"]
		and app.stitched_run_draft == before["app"]
		and _pressed(picker) == before["pressed"]
		and _visual_ids(picker) == before["order"]
		and receipts.size() == before["receipts"]
		and picker.tiles_match_draft()
		and app.stitched_run_session == null and app.run_rng == null
		and app.run_map == null and app.deck == null,
		message)


func _check_real_tiles(picker: StitchedRunPartyPicker,
		originals: Dictionary, picks: Array, context: String) -> void:
	var receipt := StitchedPartyAdmission.admit(picks)
	var expected_order: Array = receipt.get("hero_ids", []).duplicate()
	for id in StitchedPartyAdmission.HERO_IDS:
		if not id in picks:
			expected_order.append(id)
	_check(receipt.get("ok") == true and picker.columns == 2
		and picker.get_child_count() == StitchedPartyAdmission.HERO_IDS.size()
		and picker.tiles.size() == StitchedPartyAdmission.HERO_IDS.size()
		and _visual_ids(picker) == expected_order
		and picker.displayed_rank_ids() == receipt.get("hero_ids", [])
		and picker.tiles_match_draft(), context + ": admitted ranks and selected-first grid")
	for id in StitchedPartyAdmission.HERO_IDS:
		var tile: Button = picker.tiles.get(id)
		var portrait := tile.get_node_or_null("Portrait") as TextureRect if tile != null else null
		var label := tile.get_node_or_null("DollName") as Label if tile != null else null
		_check(tile == originals.get(id) and tile.get_parent() == picker
			and tile.toggle_mode and tile.focus_mode == Control.FOCUS_ALL
			and tile.button_pressed == (id in picks) and tile.name == "HeroTile_" + id
			and portrait != null and portrait.get_meta("art_path", "") ==
				"res://assets/paper/heroes/" + id + ".png"
			and label != null and not label.text.is_empty()
			and (tile.get_theme_stylebox("normal") as StyleBoxTexture).texture.resource_path
				== StitchedRunPartyPicker.TILE_SKIN,
			context + ": exact original picture-skinned tile " + id)


## Reconstruct the current four signature launch annotations directly from
## canonical admission and authored S14 entries; compare native UI strings.
func _hints(app: Node, picker: StitchedRunPartyPicker, picks: Array,
		context: String) -> void:
	var admission := StitchedPartyAdmission.admit(picks)
	var catalog := StitchedS14Abilities.kits()
	var stranded: Array[String] = []
	_check(admission.get("ok") == true and not catalog.is_empty()
		and not app.stitched_run_buttons[0].disabled,
		context + ": valid admission and live Set out authority")
	if admission.get("ok") != true or catalog.is_empty():
		return
	for rank_index in admission["hero_ids"].size():
		var id: String = admission["hero_ids"][rank_index]
		var hero: Dictionary = admission["heroes"][rank_index]
		var count := 0
		var tile: Button = picker.tiles[id]
		var lines := tile.tooltip_text.split("\n")
		for slot_index in StitchedParts.SLOTS.size():
			var slot: String = StitchedParts.SLOTS[slot_index]
			var can_launch: bool = rank_index + 1 in catalog[id][slot]["launch"]
			if can_launch:
				count += 1
			_check(lines.size() >= StitchedParts.SLOTS.size()
				and lines[slot_index].contains(
					"From this rank" if can_launch else "Needs another rank")
				and lines[slot_index].contains("(launch only; target may be unavailable)"),
				context + ": true " + id + " " + slot + " launch rank")
		if count == 0:
			stranded.append("%s at rank %d" % [hero["name"], rank_index + 1])
			_check(lines.size() == StitchedParts.SLOTS.size() + 1
				and lines[-1].contains("cannot launch a signature move"),
				context + ": stranded original tile carries a warning")
		else:
			_check(lines.size() == StitchedParts.SLOTS.size(),
				context + ": launch-capable tile has no stale warning")
	var expected_warning := ""
	if not stranded.is_empty():
		expected_warning = "Opening rank warning: %s cannot launch any signature moves. Move or Pass is still possible." % ", ".join(stranded)
	_check(app.stitched_run_buttons[0].tooltip_text == expected_warning
		and StitchedPartyKitHints.opening_rank_advisory(picks) == expected_warning,
		context + ": source-derived Set out warning or its removal")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var packed := load("res://scenes/app.tscn") as PackedScene
	_check(packed != null, "real App scene loads")
	if packed == null:
		_finish()
		return
	var app: Node = packed.instantiate()
	app.stitched_walks = false
	app.run_seed = 7311
	app.stitched_save_path = SAVE
	app.wren_gifts_profile_path = "user://stitched_s6_one_step_missing_gifts.json"
	root.add_child(app)
	await process_frame
	_check(app.title_view != null and app.title_view.is_visible_in_tree()
		and app.start_button != null and app.start_button.has_focus(),
		"genuine title boots with New Run focused")
	await _click(app.start_button)
	var picker := app.stitched_run_panel.find_child(
		"StitchedRunPartyPicker", true, false) as StitchedRunPartyPicker
	_check(picker != null and picker.is_visible_in_tree()
		and app.stitched_run_panel.get_meta("page_kind", "") == "picker"
		and app.stitched_run_buttons.size() == 2
		and app.stitched_run_buttons[0].text == "Set out"
		and app.stitched_run_buttons[1].text == "Cancel",
		"real mounted eight-tile picker has original Set out and Cancel actions")
	if picker == null:
		app.free()
		_finish()
		return
	await process_frame
	var heading := app.stitched_run_panel.find_child("StitchedPageHeading", true, false) as Label
	_check(heading != null and heading.tooltip_text ==
		"Keys 1–8: choose dolls · Shift+1–8: replace focused doll · Esc/B: cancel",
		"original heading teaches replacement without adding controls")
	var originals := picker.tiles.duplicate()
	_check_real_tiles(picker, originals, DEFAULT, "default")
	_check(app.stitched_run_draft == DEFAULT and not app.stitched_run_buttons[0].disabled
		and app.stitched_run_session == null, "authored defaults are live before a run")
	picker.draft_changed.connect(_receipt)
	var emitted_arrays: Array = []
	picker.draft_changed.connect(func(picks: Array) -> void: emitted_arrays.append(picks))
	seed(469211)
	var expected_rng := randi()
	seed(469211)

	# Full board, but original Set out has focus: Shift+1 is not a shortcut.
	var before := _snapshot(app, picker)
	_check(app.stitched_run_buttons[0].has_focus(), "default Set out actually holds focus")
	await _stroke(KEY_1, true)
	_unchanged(app, picker, before, "Set out focus rejects shifted digit")
	app.stitched_run_buttons[1].grab_focus()
	before = _snapshot(app, picker)
	await _stroke(KEY_5, true)
	_unchanged(app, picker, before, "Cancel focus rejects shifted digit")
	picker.tiles["rag_duelist"].grab_focus()
	before = _snapshot(app, picker)
	await _stroke(KEY_5, true)
	_unchanged(app, picker, before, "unselected tile cannot be the outgoing focus")
	picker.tiles["warden"].grab_focus()
	before = _snapshot(app, picker)
	await _stroke(KEY_1, true)
	_unchanged(app, picker, before, "already-selected target rejects replacement")
	for variant in [
		{"code": KEY_5, "down": false},
		{"code": KEY_5, "down": true, "echo": true},
		{"code": KEY_9, "down": true},
		{"code": KEY_KP_5, "down": true},
		{"code": KEY_5, "down": true, "modifier": "ctrl"},
		{"code": KEY_5, "down": true, "modifier": "alt"},
		{"code": KEY_5, "down": true, "modifier": "meta"},
		{"code": KEY_5, "down": true, "physical": KEY_KP_5},
	]:
		before = _snapshot(app, picker)
		await _key(variant["code"], variant["down"], true,
			variant.get("echo", false), variant.get("modifier", ""),
			variant.get("physical", KEY_NONE))
		_unchanged(app, picker, before,
			"invalid shifted physical edge/chord stays inert: " + str(variant))
	# Refuse a pressed-state lie, even while the focused original still exists.
	picker.tiles["seamstress"].set_pressed_no_signal(false)
	var tampered := picker.selected_ids()
	var tampered_draft: Array = app.stitched_run_draft.duplicate()
	var tampered_receipts := receipts.size()
	await _stroke(KEY_5, true)
	_check(picker.selected_ids() == tampered and app.stitched_run_draft == tampered_draft
		and not picker.tiles["seamstress"].button_pressed
		and receipts.size() == tampered_receipts and app.stitched_run_session == null,
		"tampered original pressed state fails closed, not silently repaired")
	picker.tiles["seamstress"].set_pressed_no_signal(true)
	_check(picker.tiles_match_draft(), "test restores the genuine tile witness")
	# A dishonest reorder and an explicitly pending reflow must also fail closed.
	picker.move_child(picker.tiles["warden"], 4)
	var dishonest_order := _visual_ids(picker)
	before = _snapshot(app, picker)
	await _stroke(KEY_5, true)
	_unchanged(app, picker, before, "unsolicited moved tile cannot be replaced")
	_check(_visual_ids(picker) == dishonest_order, "rejected event does not repair forged order")
	picker._arrange_tiles()
	picker._reorder_pending = true
	before = _snapshot(app, picker)
	await _stroke(KEY_5, true)
	_unchanged(app, picker, before, "pending reflow blocks replacement")
	picker._reorder_pending = false
	# The mounted epoch and the real visible picker are separate hard gates.
	var epoch: int = app._stitched_run_epoch
	app._stitched_run_epoch += 1
	before = _snapshot(app, picker)
	await _stroke(KEY_5, true)
	_unchanged(app, picker, before, "stale mounted epoch rejects replacement")
	app._stitched_run_epoch = epoch
	picker.hide()
	before = _snapshot(app, picker)
	await _stroke(KEY_5, true)
	_unchanged(app, picker, before, "hidden picker rejects replacement")
	picker.show()
	await process_frame
	picker.update_opening_rank_cues(DEFAULT)

	# Genuine unmodified digit selection remains a toggle, not a replacement.
	picker.tiles["warden"].grab_focus()
	await _stroke(KEY_1)
	var three := ["seamstress", "tinker", "lantern_monk"]
	_check(picker.selected_ids() == three and app.stitched_run_draft == three
		and app.stitched_run_buttons[0].disabled and receipts.size() == 1,
		"normal 1 removes Warden through its original signal and disables Set out")
	before = _snapshot(app, picker)
	await _stroke(KEY_5, true)
	_unchanged(app, picker, before, "3-of-8 incomplete party rejects Shift+5")
	await _stroke(KEY_1)
	var appended := ["seamstress", "tinker", "lantern_monk", "warden"]
	_check(picker.selected_ids() == appended and app.stitched_run_draft == appended
		and receipts.size() == 2 and not app.stitched_run_buttons[0].disabled,
		"ordinary 1 restores fourth pick by appending it through native toggle")
	# A normal toggle appends, as before; clear and pick the original four in
	# order so the replacement witness truly begins with authored defaults.
	for code in [KEY_2, KEY_3, KEY_4, KEY_1]:
		await _stroke(code)
	_check(picker.selected_ids().is_empty() and app.stitched_run_buttons[0].disabled,
		"unmodified keys can empty the original four")
	for code in [KEY_1, KEY_2, KEY_3, KEY_4]:
		await _stroke(code)
	_check(picker.selected_ids() == DEFAULT and app.stitched_run_draft == DEFAULT
		and receipts.size() == 10 and not app.stitched_run_buttons[0].disabled,
		"unmodified keys reconstruct authored default pick order without replacement")
	_check_real_tiles(picker, originals, DEFAULT, "restored")
	# Navigate with real arrows, Tab and shoulders before the actual replacement.
	picker.tiles["warden"].grab_focus()
	await _stroke(KEY_RIGHT)
	_check(root.gui_get_focus_owner() == originals["seamstress"], "right arrow navigates originals")
	await _stroke(KEY_TAB)
	_check(root.gui_get_focus_owner() == originals["tinker"], "Tab navigates original grid")
	await _joy(JOY_BUTTON_RIGHT_SHOULDER, true)
	await _joy(JOY_BUTTON_RIGHT_SHOULDER, false)
	_check(root.gui_get_focus_owner() == originals["lantern_monk"],
		"controller shoulder navigates unchanged controls")

	picker.tiles["warden"].grab_focus()
	var count := receipts.size()
	await _stroke(KEY_5, true)
	_check(picker.selected_ids() == FIRST and app.stitched_run_draft == FIRST
		and receipts.size() == count + 1 and receipts.back() == FIRST
		and originals["rag_duelist"].has_focus()
		and not originals["warden"].button_pressed
		and not app.stitched_run_buttons[0].disabled
		and app.stitched_run_session == null,
		"Shift+5 replaces the focused Warden once and focuses original Rag Duelist")
	_check_real_tiles(picker, originals, FIRST, "Shift+5 canonical reflow")
	_hints(app, picker, FIRST, "Shift+5")
	# Mutating a delivered receipt must never mutate the retained picker draft.
	var detached: Array = emitted_arrays.back()
	detached.append("bogus")
	_check(picker.selected_ids() == FIRST and app.stitched_run_draft == FIRST
		and receipts.back() == FIRST and detached == FIRST + ["bogus"],
		"mutating actual emitted draft cannot affect App, picker or captured receipt")
	# Different focused original, second valid single edge: Warden is now
	# displaced to rank four and has no legal S14 launch from that rank.
	originals["lantern_monk"].grab_focus()
	count = receipts.size()
	await _stroke(KEY_1, true)
	_check(picker.selected_ids() == STRANDED and app.stitched_run_draft == STRANDED
		and receipts.size() == count + 1 and receipts.back() == STRANDED
		and originals["warden"].has_focus() and not originals["lantern_monk"].button_pressed,
		"second Shift+1 swaps only focused Lantern Monk and focuses incoming Warden")
	_check_real_tiles(picker, originals, STRANDED, "Warden stranded after second swap")
	_hints(app, picker, STRANDED, "Warden displaced to rank four")
	_check(app.stitched_run_buttons[0].tooltip_text.contains("Warden at rank 4"),
		"second replacement produces genuinely new source-derived launch warning")
	# The newly focused incoming tile can be replaced immediately, clearing
	# its warning without a mouse click or an extra selection.
	count = receipts.size()
	await _stroke(KEY_4, true)
	_check(picker.selected_ids() == FIRST and app.stitched_run_draft == FIRST
		and receipts.size() == count + 1 and receipts.back() == FIRST
		and originals["lantern_monk"].has_focus(),
		"focused incoming Warden can itself be replaced by one more Shift+4")
	_check_real_tiles(picker, originals, FIRST, "warning cleared by replacement")
	_hints(app, picker, FIRST, "restored launch ranks")
	_check(app.stitched_run_buttons[0].tooltip_text.is_empty(),
		"source warning clears after third replacement")
	_check(randi() == expected_rng and app.stitched_run_session == null,
		"all rejected and accepted picker edits are run-RNG and session neutral")

	var admitted := StitchedPartyAdmission.admit(FIRST)
	await _click(app.stitched_run_buttons[0])
	var session: StitchedRunSession = app.stitched_run_session
	var actual_ranks: Array = []
	if session != null:
		for hero in session.heroes:
			actual_ranks.append(hero.id)
	var expected_session := StitchedRunSession.start(7311, FIRST)
	_check(session != null and session.is_consistent() and expected_session != null
		and session.picks == FIRST and actual_ranks == admitted.get("hero_ids", [])
		and session.snapshot() == expected_session.snapshot()
		and app.stitched_run_intro != null and app.run_rng == null,
		"real Set out creates the seeded session with source-derived canonical ranks")
	app._return_stitched_run_title()
	await process_frame
	_check(app.title_view.is_visible_in_tree() and app.stitched_run_session == null
		and app.stitched_run_draft.is_empty() and app.start_button.has_focus(),
		"return from live run restores focused title and clears prior draft")
	await _click(app.start_button)
	var fresh := app.stitched_run_panel.find_child(
		"StitchedRunPartyPicker", true, false) as StitchedRunPartyPicker
	_check(fresh != null and fresh != picker and fresh.selected_ids() == DEFAULT
		and app.stitched_run_draft == DEFAULT
		and app.stitched_run_buttons[0].tooltip_text == ""
		and app.stitched_run_buttons[0].has_focus(),
		"reopened picker has original defaults, no stale focus, rank cue or warning")
	if fresh != null:
		_check_real_tiles(fresh, fresh.tiles.duplicate(), DEFAULT, "fresh title reopening")
		# Real Escape cancels this current mounted page; controller B is
		# still the other native cancel route after one more reopening.
		fresh.tiles["warden"].grab_focus()
		await _stroke(KEY_ESCAPE)
		_check(app.stitched_run_panel == null and app.title_view.is_visible_in_tree(),
			"physical Escape still uses native Cancel control")
		await _click(app.start_button)
		var next := app.stitched_run_panel.find_child(
			"StitchedRunPartyPicker", true, false) as StitchedRunPartyPicker
		_check(next != null and next.selected_ids() == DEFAULT,
			"controller cancel witness has real new default picker")
		if next != null:
			next.tiles["warden"].grab_focus()
			await _joy(JOY_BUTTON_B, true)
			await _joy(JOY_BUTTON_B, false)
			_check(app.stitched_run_panel == null and app.title_view.is_visible_in_tree(),
				"native controller B cancels through original action")
	app.free()
	await process_frame
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("stitched_s6_one_step_party_replace_live_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
