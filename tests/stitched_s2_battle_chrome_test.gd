extends SceneTree
## S2 mounted chrome contract: real preview data, real buttons and authoritative state.
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, note: String) -> void:
	checks += 1
	if not condition:
		failures.append(note)


func _mount() -> Dictionary:
	var host := Control.new()
	host.name = "SewnBattleChromeHost"
	host.size = Vector2(1280, 720)
	host.theme = load("res://themes/gothic_theme.tres")
	root.add_child(host)
	var screen := StitchedBattleScreen.new()
	var data := StitchedBattleScreen.read_preview()
	_check(int(data.get("seed", -1)) == 4952026 and int(data.get("candle", -1)) == 78
		and data.get("heroes", []).size() == 4 and data.get("foes", []).size() == 3,
		"precondition: unmodified 4952026 Stitched four-hero/three-foe preview")
	_check(screen.begin(data), "precondition: mounted S2 screen uses real validated rules")
	host.add_child(screen)
	return {"host": host, "screen": screen}


func _no_mutation(screen: StitchedBattleScreen, state: Dictionary, rng: int, count: int, note: String) -> void:
	_check(screen.battle.state_snapshot() == state and screen.battle.rng_state() == rng
		and screen.receipts.size() == count, note)


func _verify_styles(screen: StitchedBattleScreen) -> void:
	var fabric: Texture2D = load("res://assets/paper/ui/panel_felt.png")
	var button_art: Texture2D = load("res://assets/paper/ui/reward_button.png")
	var tray := screen.get_node_or_null("StitchedActionTray") as NinePatchRect
	_check(tray != null and tray.texture == fabric
		and tray.get_global_rect() == Rect2(12, 557, 1256, 155)
		and screen._candle_meter != null and screen._turn_ribbon != null,
		"authored nine-slice tray remains under controls and below full stage")
	var buttons: Array[BaseButton] = []
	for group in [screen._part_buttons, screen._part_help_buttons,
			screen._target_buttons, screen._action_buttons, screen._seat_buttons]:
		for button in group.values():
			buttons.append(button)
	_check(buttons.size() >= 29 and screen._part_buttons.size() == 4
		and screen._target_buttons.size() == 8 and screen._seat_buttons.size() == 8,
		"precondition: all part/help/target/action/seat controls exist")
	var states := ["normal", "hover", "pressed", "disabled", "focus"]
	for button in buttons:
		var sewn := true
		for state in states:
			var style := button.get_theme_stylebox(state)
			if not style is StyleBoxTexture or style.texture != button_art:
				sewn = false
		_check(sewn and button.focus_mode == Control.FOCUS_ALL and button.text != "",
			"%s has authored all-state button chrome, identity and keyboard focus" % button.name)
	_check(screen._target_buttons["foe_4"].disabled and
		screen._action_buttons["re_tie"].disabled,
		"empty foe target and unavailable Re-tie retain fail-closed disabled state")
	var pass_button: Button = screen._action_buttons["pass"]
	pass_button.grab_focus()
	_check(pass_button.has_focus() and pass_button.get_theme_stylebox("focus") is StyleBoxTexture,
		"keyboard focus really enters stitched turn-action button")
	pass_button.release_focus()


func _verify_action_icons(screen: StitchedBattleScreen) -> void:
	var keys := ["move_front", "move_back", "re_tie", "pass", "retreat"]
	var names := ["Move front", "Move back", "Re-tie", "Pass turn", "Retreat"]
	var art := ["move", "move", "retie", "pass", "retreat"]
	# The requested 29px control height is clamped to a 30px Godot/Gothic
	# themed minimum at runtime; confirm the real hit rect stays clear at y672.
	var expected := [
		Rect2(260, 642, 136, 30), Rect2(403, 642, 136, 30),
		Rect2(546, 642, 136, 30), Rect2(689, 642, 150, 30),
		Rect2(846, 642, 165, 30),
	]
	var preview: Rect2 = screen._labels["preview"].get_global_rect()
	var figure: Rect2 = screen.get_node("SharedStitchedBackdrop").get_global_rect()
	var references: Array[Rect2] = []
	for control in screen._target_buttons.values():
		references.append(control.get_global_rect())
	for index in range(keys.size()):
		var key: String = keys[index]
		var button: Button = screen._action_buttons[key]
		var path: String = "res://assets/paper/stitched/icons/action_" + art[index] + ".png"
		var icon: Texture2D = load(path)
		var emblem: TextureRect = button.get_node_or_null("ActionEmblem") as TextureRect
		var rect := button.get_global_rect()
		_check(icon != null and icon.get_size() == Vector2(128, 128)
			and emblem != null and emblem.texture == icon
			and emblem.size == Vector2(19, 19) and emblem.position == Vector2(9, 5)
			and emblem.expand_mode == TextureRect.EXPAND_IGNORE_SIZE
			and emblem.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			and emblem.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and emblem.focus_mode == Control.FOCUS_NONE
			and button.focus_mode == Control.FOCUS_ALL and button.text == names[index]
			and button.get_theme_font_size("font_size") == 14,
			"%s mounts the 128px authored art in a non-interactive 19px button emblem" % key)
		_check(rect == expected[index] and not rect.intersects(preview)
			and not rect.intersects(figure) and rect.position.y >= 642
			and rect.end.y < 675 and Rect2(0, 0, 1280, 720).encloses(rect),
			"%s retains its existing mouse rectangle clear of stage, forecast and targets" % key)
		for other in references:
			_check(not rect.intersects(other), "%s cannot overlap any prior action or target" % key)
		references.append(rect)
		var font: Font = button.get_theme_font("font")
		_check(font != null and font.get_string_size(button.text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x < rect.size.x - 38.0,
			"%s has room for the authored emblem beside its unclipped readable text" % key)
	var state := screen.battle.state_snapshot()
	var rng := screen.battle.rng_state()
	var receipts := screen.receipts.size()
	for key in keys:
		var button: Button = screen._action_buttons[key]
		screen._action_buttons["pass"].release_focus()
		button.mouse_entered.emit()
		_check(screen._labels["preview"].text.contains(button.text)
			or screen._labels["preview"].tooltip_text.contains(button.text),
			"%s exposes a real hover description in the sewn forecast row" % key)
		button.mouse_exited.emit()
		if not button.disabled:
			button.grab_focus()
			_check(button.has_focus() and screen._labels["preview"].tooltip_text != "",
				"%s keyboard focus reveals full action availability without activation" % key)
			button.release_focus()
	_no_mutation(screen, state, rng, receipts,
		"action icon hover, keyboard focus and tooltip never consume RNG or combat state")


func _verify_meters(screen: StitchedBattleScreen) -> void:
	var heroes: Array = screen.battle.get_heroes()
	var foes: Array = screen.battle.get_foes()
	_check(heroes.size() == 4 and foes.size() == 3,
		"precondition: occupied meter assertions observe four heroes and three foes")
	for side in ["hero", "foe"]:
		var actors: Array = heroes if side == "hero" else foes
		for rank in range(1, 5):
			var key: String = str(side) + "_" + str(rank)
			var expected: Dictionary = {}
			for actor in actors:
				if int(actor["rank"]) == rank and not bool(actor.get("lost", false)) and not bool(actor.get("dead", false)) and (side == "hero" or int(actor["hp"]) > 0):
					expected = actor
					break
			var meters: Dictionary = screen._rank_meters[key]
			var surface: Control = meters["root"]
			var hp: ProgressBar = meters["hp"]
			var present := not expected.is_empty()
			var hp_frame: NinePatchRect = surface.get_node("HPFillSewnFrame")
			var hp_style := hp.get_theme_stylebox("fill") as StyleBoxTexture
			var hp_text: Label = meters["hp_text"]
			_check(surface.visible == present and hp is ProgressBar and
				hp_frame is NinePatchRect and hp_frame.texture == load("res://assets/paper/ui/hud_bar_frame.png") and
				hp_style != null and hp_style.texture == load("res://assets/paper/ui/reward_button.png") and
				not screen._labels[key].visible and
				(screen._labels[key].text.is_empty() or not present),
				"%s rank %d has only its occupied authored-framed meter, not painted duplicate text" % [side, rank])
			if not present:
				continue
			var foot: NinePatchRect = screen._foot_plates[key]
			var name: Button = screen._seat_buttons[key]
			_check(hp.value == float(expected["hp"]) and
				hp.max_value == float(expected["max_hp"]) and
				hp.tooltip_text.contains("%d/%d" % [int(expected["hp"]), int(expected["max_hp"])]) and
				hp_text.text == "HP %d/%d" % [int(expected["hp"]), int(expected["max_hp"])] and
				hp_text.get_theme_color("font_color") == StitchedBattleChrome.BONE and
				foot.get_global_rect().encloses(surface.get_global_rect()) and
				not name.get_global_rect().intersects(surface.get_global_rect()) and
				not hp_text.get_global_rect().intersects(hp_frame.get_global_rect()) and
				not hp_text.get_global_rect().intersects(hp.get_global_rect()) and
				hp.get_global_rect().size.y >= 6.0,
				"%s rank %d HP fill, bone readout and frame fit distinct plate bands" % [side, rank])
			if side == "hero":
				var fray: ProgressBar = meters["fray"]
				var fray_frame: NinePatchRect = surface.get_node("FrayFillSewnFrame")
				var fray_caption: Label = meters["fray_text"]
				var fray_style := fray.get_theme_stylebox("fill") as StyleBoxTexture
				_check(fray.max_value == 200.0 and fray.value == float(expected["fray"])
					and fray_caption.text == "FRAY %d/200" % int(expected["fray"])
					and fray_frame.texture == load("res://assets/paper/ui/hud_bar_frame.png")
					and fray_style != null and fray_style.texture == load("res://assets/paper/ui/reward_button.png")
					and not fray_caption.get_global_rect().intersects(fray_frame.get_global_rect())
					and not fray_caption.get_global_rect().intersects(hp_text.get_global_rect())
					and foot.get_global_rect().encloses(fray_frame.get_global_rect()),
					"hero rank %d exact FRAY fill/caption and stitched frame stay in separate bands" % rank)


func _test_hanging_and_lost(screen: StitchedBattleScreen) -> void:
	var hero: Dictionary = screen.battle.get_heroes()[0]
	var id := str(hero["id"])
	var original: Dictionary = screen.battle._units[id].duplicate(true)
	var baseline := screen.battle.state_snapshot()
	var rng := screen.battle.rng_state()
	var receipts := screen.receipts.size()
	var key := "hero_" + str(int(hero["rank"]))
	screen.battle._units[id]["hp"] = 0
	screen.battle._units[id]["hanging"] = true
	screen.battle._units[id]["fray"] = 173
	screen._refresh()
	var meters: Dictionary = screen._rank_meters[key]
	var hp_frame: NinePatchRect = meters["root"].get_node("HPFillSewnFrame")
	var fray_frame: NinePatchRect = meters["root"].get_node("FrayFillSewnFrame")
	_check(screen._puppets[key].visible and meters["root"].visible
		and meters["hp"].value == 0.0 and meters["hp_text"].text == "HANGING"
		and meters["hp_text"].get_theme_color("font_color") == StitchedBattleChrome.AMBER
		and hp_frame.self_modulate == Color("ffd18c")
		and meters["fray"].value == 173.0 and meters["fray_text"].text == "FRAY 173/200"
		and meters["fray_text"].get_theme_color("font_color") == StitchedBattleChrome.AMBER
		and fray_frame.self_modulate == Color("ffd18c")
		and screen.status_detail("hero", int(hero["rank"])).contains("HANGING")
		and meters["root"].tooltip_text.contains("FRAY 173/200"),
		"zero-HP HANGING doll retains warned bone/amber captions, framed fills and full status")
	screen.battle._units[id]["lost"] = true
	screen._refresh()
	_check(not screen._rank_meters[key]["root"].visible and
		not screen._puppets[key].visible,
		"LOST hero removes all meter surfaces instead of leaving a ghost bar")
	screen.battle._units[id] = original
	screen._refresh()
	_check(meters["root"].visible and meters["hp_text"].text == "HP %d/%d" % [int(original["hp"]), int(original["max_hp"])]
		and meters["fray_text"].text == "FRAY %d/200" % int(original["fray"])
		and hp_frame.self_modulate == Color.WHITE and fray_frame.self_modulate == Color.WHITE
		and meters["hp_text"].get_theme_color("font_color") == StitchedBattleChrome.BONE
		and meters["fray_text"].get_theme_color("font_color") == StitchedBattleChrome.BONE,
		"restored healthy hero clears hanging/fray warnings and returns to ordinary bone captions")
	_no_mutation(screen, baseline, rng, receipts,
		"restored authority, RNG and receipts unchanged after hanging/LOST presentation probes")


func _test_controls(screen: StitchedBattleScreen) -> void:
	var state := screen.battle.state_snapshot()
	var rng := screen.battle.rng_state()
	var receipts := screen.receipts.size()
	screen._refresh()
	screen._part_buttons["head"].mouse_entered.emit()
	screen._part_buttons["head"].mouse_exited.emit()
	screen._seat_buttons["hero_1"].focus_entered.emit()
	screen._seat_buttons["hero_1"].focus_exited.emit()
	screen._action_buttons["reduce_motion"].toggled.emit(true)
	screen._action_buttons["reduce_motion"].toggled.emit(false)
	screen._refresh()
	_no_mutation(screen, state, rng, receipts,
		"refresh, hover, focus and reduced-motion toggle never spend/roll/commit")
	_check(screen._action_buttons["re_tie"].disabled and
		screen._target_buttons["foe_4"].disabled, "blocked action and empty target remain disabled")
	screen._action_buttons["re_tie"].pressed.emit()
	screen._target_buttons["foe_4"].pressed.emit()
	_no_mutation(screen, state, rng, receipts, "even forced blocked callbacks cannot mutate battle")
	var selected := ""
	var chosen := ""
	for slot in StitchedBattleScreen.SLOTS:
		if not screen.select_part(slot):
			continue
		for key in screen.legal_targets():
			if not screen._target_buttons[key].disabled:
				selected = slot
				chosen = str(key)
				break
		if not chosen.is_empty():
			break
	_check(not selected.is_empty() and not chosen.is_empty(),
		"precondition: real current hero has a selectable part and legal target")
	if not chosen.is_empty():
		_no_mutation(screen, state, rng, receipts, "part selection and legal-target preview spend no state or RNG")
		screen._target_buttons[chosen].pressed.emit()
		_check(screen.receipts.size() > receipts and screen.battle.state_snapshot() != state
			and screen.receipts[receipts].get("action") == "ability",
			"real mounted target button delegates one legal sewn-part action through existing gate")
		_verify_meters(screen)
		var after := screen.battle.state_snapshot()
		var after_rng := screen.battle.rng_state()
		var after_count := screen.receipts.size()
		screen._refresh()
		_no_mutation(screen, after, after_rng, after_count,
			"post-action meters refresh entirely from authoritative state without RNG or receipts")


func _click(button: BaseButton) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = button.get_global_rect().get_center()
		event.pressed = pressed
		root.push_input(event, true)
	await process_frame


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
	await process_frame


func _test_utilities(screen: StitchedBattleScreen) -> void:
	var selected := false
	for slot in StitchedBattleScreen.SLOTS:
		if screen.select_part(slot) and not screen.legal_targets().is_empty():
			selected = true
			break
	_check(selected and not screen.receipts.is_empty(),
		"precondition: utilities preserve a real selected ability, legal targets and committed receipt")
	var state := screen.battle.state_snapshot()
	var rng := screen.battle.rng_state()
	var receipts := screen.receipts.duplicate(true)
	var last := screen.last_receipt.duplicate(true)
	var targets := screen.legal_targets().duplicate(true)
	var log_text: String = screen._labels["log"].text
	var opener: Button = screen._action_buttons["help"]
	var close: Button = screen._action_buttons["close_help"]
	var motion: CheckButton = screen._action_buttons["reduce_motion"]
	var exit_button: Button = screen._action_buttons["exit"]
	_check(opener.is_visible_in_tree() and screen._labels["log"].is_visible_in_tree()
		and screen._labels["log"].size.y >= 100 and not motion.is_visible_in_tree()
		and not exit_button.is_visible_in_tree() and not close.is_visible_in_tree(),
		"normal right tray shows readable log and one utility opener with secondary controls concealed")
	await _click(opener)
	_check(screen._utilities_open and close.has_focus() and not opener.is_visible_in_tree()
		and motion.is_visible_in_tree() and exit_button.is_visible_in_tree()
		and screen._labels["help"].is_visible_in_tree() and not screen._part_disclosure.visible,
		"real mouse opens instructions and settings inside the sewn tray and focuses close")
	var tray_rect := Rect2(1031, 562, 230, 144)
	for utility in [motion, exit_button, close, screen._labels["help"]]:
		_check(tray_rect.encloses(utility.get_global_rect()), "expanded utility remains inside right tray")
		for group in [screen._part_buttons, screen._part_help_buttons, screen._target_buttons]:
			for control in group.values():
				_check(not utility.get_global_rect().intersects(control.get_global_rect()),
					"utility never covers part, inspection or target control")
		for key in ["move_front", "move_back", "re_tie", "pass", "retreat"]:
			_check(not utility.get_global_rect().intersects(screen._action_buttons[key].get_global_rect()),
				"utility never covers turn action")
	var original_motion := screen.reduced_motion
	await _click(motion)
	_check(screen.reduced_motion != original_motion and motion.button_pressed == screen.reduced_motion,
		"real mouse toggle updates motion preference and check state")
	for puppet in screen._puppets.values():
		_check(puppet.is_processing() == not screen.reduced_motion, "motion toggle updates real puppets")
	motion.grab_focus()
	await _key(KEY_SPACE)
	_check(screen.reduced_motion == original_motion and motion.button_pressed == original_motion,
		"keyboard toggles real motion check back to original preference")
	await _key(KEY_ESCAPE)
	_check(not screen._utilities_open and opener.has_focus()
		and screen._labels["log"].visible and screen._labels["log"].text == log_text,
		"Escape dismisses utilities, restores opener focus and retains log text")
	await _key(KEY_ENTER)
	_check(screen._utilities_open and close.has_focus(), "keyboard reopens utility tray")
	await _key(KEY_ENTER)
	_check(not screen._utilities_open and opener.has_focus(), "keyboard close restores opener focus")
	await _click(opener)
	await _click(close)
	_check(not screen._utilities_open and opener.has_focus(), "mouse close restores opener focus")
	screen._seat_buttons["hero_1"].mouse_entered.emit()
	screen._seat_buttons["hero_1"].mouse_exited.emit()
	_check(screen.legal_targets() == targets and not targets.is_empty()
		and screen.receipts == receipts and screen.last_receipt == last,
		"help, motion and inspection preserve exact legal targets and all receipt contents")
	_no_mutation(screen, state, rng, receipts.size(), "utilities and inspection preserve snapshot and RNG")
	_check(screen._target_buttons["foe_4"].disabled and screen._action_buttons["re_tie"].disabled,
		"utilities retain blocked empty target and unavailable Re-tie")
	var exits := [0]
	screen.exit_requested.connect(func(): exits[0] += 1)
	await _click(opener)
	await _click(exit_button)
	_check(exits[0] == 1, "one real Back to title click emits exactly one exit signal")
	_no_mutation(screen, state, rng, receipts.size(), "exit signal does not commit combat")


func _run() -> void:
	var mounted := _mount()
	await process_frame
	var screen: StitchedBattleScreen = mounted["screen"]
	if screen.battle != null and screen.battle.is_valid():
		_verify_styles(screen)
		_verify_action_icons(screen)
		_verify_meters(screen)
		_test_hanging_and_lost(screen)
		_test_controls(screen)
		await _test_utilities(screen)
	mounted["host"].free()
	await process_frame
	for failure in failures:
		printerr(failure)
	print("stitched_s2_battle_chrome_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
