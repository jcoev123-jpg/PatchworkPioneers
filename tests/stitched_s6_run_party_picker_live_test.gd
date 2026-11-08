extends SceneTree
## Physical input against the actual mounted title and Wren-room New Run entry.
const SAVE := "user://stitched_s6_run_party_picker_live_test.save"

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, detail: String) -> void:
	checks += 1
	if not value:
		failures.append(detail)


func _mouse(button: Button) -> void:
	await process_frame
	await process_frame
	if not is_instance_valid(button) or not button.is_visible_in_tree() or button.disabled:
		_check(false, "physical click target missing or disabled")
		return
	var at := button.get_global_rect().get_center()
	var hover := InputEventMouseMotion.new()
	hover.position = at
	root.push_input(hover, true)
	await process_frame
	for down in [true, false]:
		var input := InputEventMouseButton.new()
		input.button_index = MOUSE_BUTTON_LEFT
		input.position = at
		input.pressed = down
		root.push_input(input, true)
		await process_frame


func _key(code: Key) -> void:
	for down in [true, false]:
		var input := InputEventKey.new()
		input.keycode = code
		input.physical_keycode = code
		input.pressed = down
		Input.parse_input_event(input)
		await process_frame


func _picker(app: Node) -> StitchedRunPartyPicker:
	if not is_instance_valid(app.stitched_run_panel):
		_check(false, "production picker exists")
		return null
	var picker := app.stitched_run_panel.find_child("StitchedRunPartyPicker", true, false) as StitchedRunPartyPicker
	_check(picker != null and picker.is_visible_in_tree()
		and app.stitched_run_buttons.size() == 2
		and app.stitched_run_buttons[0].text == "Set out"
		and app.stitched_run_buttons[1].text == "Cancel",
		"live picker and both public actions are mounted in original order")
	return picker


## Examine the real GridContainer children in row-major display order, not tiles' dictionary.
func _visual_tile_ids(picker: StitchedRunPartyPicker) -> Array:
	var result: Array = []
	for child in picker.get_children():
		if child is Button:
			result.append(child.get_meta("hero_id", ""))
	return result


func _check_order(picker: StitchedRunPartyPicker, first: Array, rest: Array, context: String) -> void:
	if picker == null:
		return
	var expected := first + rest
	var actual := _visual_tile_ids(picker)
	_check(picker.columns == 2 and actual == expected
		and picker.get_child_count() == StitchedPartyAdmission.HERO_IDS.size(),
		context + ": exactly the original two-column tiles appear selected-first (actual %s, expected %s)" % [actual, expected])
	_check(picker.displayed_rank_ids() == (first if first.size() == 4 else []),
		context + ": only a complete admission exposes four pictured ranks")
	for i in range(mini(expected.size(), picker.get_child_count())):
		var child := picker.get_child(i) as Button
		_check(child == picker.tiles.get(expected[i]) and child.name == "HeroTile_" + str(expected[i]),
			context + ": original button instance occupies visual slot %d" % i)
	for row in range(picker.get_child_count() / 2):
		var left := picker.get_child(row * 2) as Button
		var right := picker.get_child(row * 2 + 1) as Button
		var a := left.get_global_rect()
		var b := right.get_global_rect()
		_check(a.end.x <= b.position.x and absf(a.position.y - b.position.y) < 1.0,
			context + ": left/right row-major geometry %d" % row)
		if row > 0:
			var above := (picker.get_child((row - 1) * 2) as Button).get_global_rect()
			_check(above.end.y <= a.position.y, context + ": row %d stays below prior row" % row)


func _default(picker: StitchedRunPartyPicker, app: Node) -> void:
	if picker == null:
		return
	_check(picker.tiles.size() == StitchedPartyAdmission.HERO_IDS.size() and picker.selected_ids() == StitchedRunSession.DEFAULT_PICKS
		and app.stitched_run_draft == StitchedRunSession.DEFAULT_PICKS
		and picker.tiles_match_draft(), "eight tiles, four authored defaults, consistent checked draft")
	var admission := StitchedPartyAdmission.admit(StitchedRunSession.DEFAULT_PICKS)
	_check(admission.get("ok") == true and admission.get("hero_ids") == StitchedRunSession.DEFAULT_PICKS,
		"authored defaults have a real front-to-back admission receipt")
	_check_order(picker, admission.get("hero_ids", []),
		["rag_duelist", "scarecrow", "yarn_ranger", "button_golem"],
		"mounted default New Run")
	for id in StitchedPartyAdmission.HERO_IDS:
		var tile: Button = picker.tiles.get(id)
		var art: TextureRect = tile.get_node("Portrait") if tile != null else null
		var nameplate: Label = tile.get_node("DollName") if tile != null else null
		_check(tile != null and tile.focus_mode == Control.FOCUS_ALL
			and tile.button_pressed == (id in StitchedRunSession.DEFAULT_PICKS)
			and tile.get_meta("hero_id") == id and tile.get_global_rect().has_area()
			and art != null and art.get_meta("art_path") == "res://assets/paper/heroes/" + id + ".png"
			and (not ResourceLoader.exists("res://assets/paper/heroes/" + id + ".png", "Texture2D")
				or art.texture != null)
			and nameplate != null and nameplate.text.contains(id.replace("_", " ").capitalize()),
			"authored picture path, readable name, checked and focusable real hit area for " + id)
	_check(not app.stitched_run_buttons[0].disabled
		and app.stitched_run_buttons[0].focus_mode == Control.FOCUS_ALL
		and app.stitched_run_session == null and app.run_rng == null and app.deck == null,
		"default picker enables Set out but allocates no run or old deck")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var app: Node = (load("res://scenes/app.tscn") as PackedScene).instantiate()
	_check(app != null, "production res://scenes/app.tscn instantiates")
	if app == null:
		_finish()
		return
	app.stitched_walks = false
	app.run_seed = 7311
	app.stitched_save_path = SAVE
	app.wren_gifts_profile_path = "user://s6_run_picker_missing_gifts.json"
	root.add_child(app)
	await process_frame
	_check(app.start_button != null and app.title_view.is_visible_in_tree()
		and app.start_button.has_focus(), "actual title boots with focused New Run")
	await _mouse(app.start_button)
	var picker := _picker(app)
	if picker == null:
		app.free()
		_finish()
		return
	await process_frame
	_default(picker, app)
	var original_tiles: Dictionary = picker.tiles.duplicate()
	var wallet_before := [app.session_gold, app.run_scraps]
	var reachable: Dictionary = {}
	for step in range(StitchedPartyAdmission.HERO_IDS.size() + 3):
		await _key(KEY_TAB)
		for id in StitchedPartyAdmission.HERO_IDS:
			if picker.tiles[id].has_focus():
				reachable[id] = true
	_check(reachable.size() == StitchedPartyAdmission.HERO_IDS.size(),
		"physical Tab traversal reaches each of the eight pictured choices")
	var viewport := Rect2(Vector2.ZERO, Vector2(1280, 720))
	var earlier_rects: Array[Rect2] = []
	for id in StitchedPartyAdmission.HERO_IDS:
		var tile: Button = picker.tiles[id]
		var rect := tile.get_global_rect()
		_check(viewport.encloses(rect) and rect.size.y >= 80,
			"tile " + id + " is visible at 1280x720 with a full hit target")
		for previous in earlier_rects:
			_check(not rect.intersects(previous), "distinct doll tiles never overlap")
		for action in app.stitched_run_buttons:
			_check(not rect.intersects(action.get_global_rect()), "picker actions do not cover doll hit targets")
		earlier_rects.append(rect)
	# All edits, rejected fifth clicks, and Cancel must be RNG/resource/save-neutral.
	seed(71211)
	var expected_global := randi()
	seed(71211)
	await _mouse(picker.tiles["rag_duelist"])
	_check(not picker.tiles["rag_duelist"].button_pressed
		and picker.selected_ids() == StitchedRunSession.DEFAULT_PICKS
		and app.stitched_run_draft == StitchedRunSession.DEFAULT_PICKS,
		"mouse cannot add a fifth doll while four are chosen")
	_check_order(picker, StitchedRunSession.DEFAULT_PICKS,
		["rag_duelist", "scarecrow", "yarn_ranger", "button_golem"],
		"rejected fifth pick")
	picker.tiles["warden"].grab_focus()
	await _key(KEY_SPACE)
	await process_frame  # Idle-deferred layout moves only after Space has been released.
	_check(not picker.tiles["warden"].button_pressed
		and picker.selected_ids() == ["seamstress", "tinker", "lantern_monk"]
		and app.stitched_run_draft == picker.selected_ids()
		and app.stitched_run_buttons[0].disabled
		and app.stitched_run_buttons[0].focus_mode == Control.FOCUS_NONE,
		"physical keyboard removes Warden and disables/unfocuses incomplete Set out")
	_check(picker.tiles["warden"].has_focus(), "keyboard Space preserves focused tile across reflow")
	_check_order(picker, ["seamstress", "tinker", "lantern_monk"],
		["warden", "rag_duelist", "scarecrow", "yarn_ranger", "button_golem"],
		"incomplete draft has pick order but no invented rank receipt")
	# A directly emitted disabled action is also fail-closed, not only a pointer click.
	app.stitched_run_buttons[0].pressed.emit()
	_check(app.stitched_run_session == null and app.run_rng == null,
		"disabled action cannot start a run via its public signal")
	await _mouse(picker.tiles["rag_duelist"])
	var expected_picks := ["seamstress", "tinker", "lantern_monk", "rag_duelist"]
	_check(picker.tiles["rag_duelist"].button_pressed and picker.selected_ids() == expected_picks
		and app.stitched_run_draft == expected_picks and picker.tiles_match_draft()
		and not app.stitched_run_buttons[0].disabled
		and app.stitched_run_buttons[0].focus_mode == Control.FOCUS_ALL,
		"one replacement restores exactly four and enables Set out")
	var expected_ranks := ["rag_duelist", "seamstress", "tinker", "lantern_monk"]
	_check(picker.tiles["rag_duelist"].has_focus(),
		"mouse replacement retains Rag Duelist keyboard focus across grid reorder")
	_check_order(picker, expected_ranks,
		["warden", "scarecrow", "yarn_ranger", "button_golem"],
		"alternate admitted order visibly differs from the click-order draft")
	_check(picker.selected_ids() != picker.displayed_rank_ids(),
		"visible rank order is intentionally distinct from the four-ID draft")
	for id in StitchedPartyAdmission.HERO_IDS:
		_check(picker.tiles[id] == original_tiles[id]
			and picker.tiles[id].get_node("Portrait").get_meta("art_path")
				== "res://assets/paper/heroes/" + id + ".png",
			"rank reflow retains the exact original focusable picture control for " + id)
	await _mouse(picker.tiles["scarecrow"])
	_check(not picker.tiles["scarecrow"].button_pressed and picker.selected_ids() == expected_picks,
		"a second fifth choice still does nothing")
	_check_order(picker, expected_ranks,
		["warden", "scarecrow", "yarn_ranger", "button_golem"],
		"another rejected fifth pick never moves tiles")
	_check(app.stitched_run_session == null and app.run_rng == null and app.run_map == null
		and app.deck == null and app.run_deck.is_empty()
		and [app.session_gold, app.run_scraps] == wallet_before
		and not FileAccess.file_exists(SAVE) and randi() == expected_global,
		"drafting and fifth-choice refusals spend no RNG and allocate no run/save/cards")
	app.stitched_run_draft.append("seamstress")
	app.stitched_run_buttons[0].pressed.emit()
	_check(app.stitched_run_session == null and app.run_rng == null,
		"duplicate overfull stale draft cannot publish a session")
	app.stitched_run_draft = expected_picks.duplicate()
	# A stale/mismatched visible position must not authenticate a new session.
	picker.move_child(picker.tiles["rag_duelist"], 7)
	app.stitched_run_buttons[0].pressed.emit()
	_check(app.stitched_run_session == null and app.run_rng == null,
		"confirmation rejects an internally tampered on-screen rank order")
	picker.move_child(picker.tiles["rag_duelist"], 0)
	_check_order(picker, expected_ranks,
		["warden", "scarecrow", "yarn_ranger", "button_golem"],
		"restoring the genuine rank display re-enables authentic admission")
	var expected_admission := StitchedPartyAdmission.admit(expected_picks)
	_check(expected_admission.get("ok") == true
		and expected_admission.hero_ids == expected_ranks
		and picker.displayed_rank_ids() == expected_admission.hero_ids,
		"canonical four-doll admission equals all four actual pictured ranks")
	await _mouse(app.stitched_run_buttons[0])
	var session: StitchedRunSession = app.stitched_run_session
	_check(session != null and session.is_consistent() and app.stitched_run_intro != null,
		"real Set out starts an authentic session and keeps the S9c Wren intro")
	if session != null:
		var actual_ids: Array = []
		for hero in session.heroes:
			actual_ids.append(hero.id)
		var expected := StitchedRunSession.start(7311, expected_picks)
		_check(session.picks == expected_picks and actual_ids == expected_admission.hero_ids
			and session.heroes.size() == 4 and session.journal.is_empty()
			and expected != null and session.snapshot() == expected.snapshot()
			and session.map != null and session.rng != null,
			"original Set out starts exactly seeded canonical ranked snapshot")
		_check(app.deck == null and app.run_rng == null and app.run_map == null,
			"valid four-doll New Run never allocates legacy deck or wallet")
	app._return_stitched_run_title()
	await process_frame
	_check(app.title_view.is_visible_in_tree() and app.start_button.has_focus()
		and app.stitched_run_session == null, "return from real run restores title")
	await _mouse(app.start_button)
	picker = _picker(app)
	_default(picker, app)
	var stale_confirm: Button = app.stitched_run_buttons[0]
	app.stitched_run_buttons[1].pressed.emit()
	stale_confirm.pressed.emit()
	_check(app.stitched_run_session == null and app.title_view.is_visible_in_tree(),
		"cancelled confirmation cannot start a second run while its old node is pending free")
	await process_frame
	await _mouse(app.start_button)
	picker = _picker(app)
	app.stitched_run_buttons[1].grab_focus()
	await _key(KEY_ENTER)
	_check(app.title_view.is_visible_in_tree() and app.start_button.has_focus()
		and app.stitched_run_session == null and app.run_rng == null
		and [app.session_gold, app.run_scraps] == wallet_before,
		"keyboard Cancel restores original focused title with no run or wallet spend")
	await _mouse(app.base_button)
	var village: BaseScreen = app.base_screen
	_check(village != null and village.is_visible_in_tree() and village.has_open_village(),
		"real Wren-room/bedroom source opens")
	if village != null:
		await _mouse(village.set_out_button)
		picker = _picker(app)
		_default(picker, app)
		await _mouse(app.stitched_run_buttons[1])
		_check(village.is_visible_in_tree() and village.set_out_button.has_focus()
			and village.has_open_village() and app.stitched_run_session == null
			and app.run_rng == null and app.deck == null and not FileAccess.file_exists(SAVE)
			and [app.session_gold, app.run_scraps] == wallet_before,
			"Wren-room Cancel returns focus and original browseable bedroom, without save or spend")
		await _mouse(village.set_out_button)
		picker = _picker(app)
		_default(picker, app)
		await _mouse(app.stitched_run_buttons[1])
	app.free()
	await process_frame
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("stitched_s6_run_party_picker_live_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
