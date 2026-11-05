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
			_check(surface.visible == present and hp is ProgressBar and
				hp.get_theme_stylebox("fill") is StyleBoxTexture and
				surface.get_node("HPFillSewnFrame") is NinePatchRect,
				"%s rank %d has only its occupied authored-framed meter" % [side, rank])
			if not present:
				continue
			_check(hp.value == float(expected["hp"]) and
				hp.max_value == float(expected["max_hp"]) and
				hp.tooltip_text.contains("%d/%d" % [int(expected["hp"]), int(expected["max_hp"])]) and
				screen._labels[key].text.contains("HP "),
				"%s rank %d HP is the authoritative current/max fill and bone caption" % [side, rank])
			if side == "hero":
				var fray: ProgressBar = meters["fray"]
				_check(fray.max_value == 200.0 and fray.value == float(expected["fray"])
					and meters["fray_text"].text == "FRAY %d/200" % int(expected["fray"])
					and surface.get_node("FrayFillSewnFrame") is NinePatchRect,
					"hero rank %d FRAY is exact current/200 and is visibly labeled" % rank)


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
	_check(screen._puppets[key].visible and screen._rank_meters[key]["root"].visible
		and screen._rank_meters[key]["hp"].value == 0.0
		and screen._rank_meters[key]["fray"].value == 173.0
		and screen.status_detail("hero", int(hero["rank"])).contains("HANGING"),
		"zero-HP HANGING doll still occupies visible zero-fill HP and exact FRAY")
	screen.battle._units[id]["lost"] = true
	screen._refresh()
	_check(not screen._rank_meters[key]["root"].visible and
		not screen._puppets[key].visible,
		"LOST hero removes all meter surfaces instead of leaving a ghost bar")
	screen.battle._units[id] = original
	screen._refresh()
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


func _run() -> void:
	var mounted := _mount()
	await process_frame
	var screen: StitchedBattleScreen = mounted["screen"]
	if screen.battle != null and screen.battle.is_valid():
		_verify_styles(screen)
		_verify_meters(screen)
		_test_hanging_and_lost(screen)
		_test_controls(screen)
	mounted["host"].free()
	await process_frame
	for failure in failures:
		printerr(failure)
	print("stitched_s2_battle_chrome_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
