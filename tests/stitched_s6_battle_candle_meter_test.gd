extends SceneTree
## Genuine mounted S6 candle readout: real seeded rules, real refresh and focus/hover.
var failures: Array[String] = []
var checks := 0

const CASES := {
	0: {"name": "snuffed", "fray": 40, "acc": 0, "damage": 25, "loot": 100, "opening": "foe", "chance": 25},
	1: {"name": "dark", "fray": 30, "acc": 10, "damage": 15, "loot": 75, "opening": "", "chance": 0},
	25: {"name": "dark", "fray": 30, "acc": 10, "damage": 15, "loot": 75, "opening": "", "chance": 0},
	26: {"name": "gloom", "fray": 20, "acc": 5, "damage": 10, "loot": 50, "opening": "", "chance": 0},
	50: {"name": "gloom", "fray": 20, "acc": 5, "damage": 10, "loot": 50, "opening": "", "chance": 0},
	51: {"name": "dim", "fray": 10, "acc": 0, "damage": 0, "loot": 25, "opening": "", "chance": 0},
	75: {"name": "dim", "fray": 10, "acc": 0, "damage": 0, "loot": 25, "opening": "", "chance": 0},
	76: {"name": "bright", "fray": 0, "acc": 0, "damage": 0, "loot": 0, "opening": "hero", "chance": 15},
	100: {"name": "bright", "fray": 0, "acc": 0, "damage": 0, "loot": 0, "opening": "hero", "chance": 15},
}


func _initialize() -> void:
	# This test pins the meter's complete wording, including the Fray clause
	# that only the retired fray meter (StitchedRules.fray_enabled) ever shows.
	StitchedRules.fray_enabled = true
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _mount() -> StitchedBattleScreen:
	var view := StitchedBattleScreen.new()
	var config := StitchedBattleScreen.read_preview()
	_check(config.get("candle") == 78 and config.get("heroes", []).size() == 4 and
		config.get("foes", []).size() == 3, "precondition: authentic seeded S2 78-candle 4v3 preview")
	if not view.begin(config):
		_check(false, "fresh preview session must begin")
		view.free()
		return null
	root.add_child(view)
	await process_frame
	_check(view.is_inside_tree() and view.battle != null and view.battle.is_valid() and
		view._candle_meter != null and view._candle_meter.is_visible_in_tree(),
		"precondition: real battle screen and meter are mounted")
	return view


func _choose_part(view: StitchedBattleScreen) -> void:
	var chosen := false
	for slot in StitchedBattleScreen.SLOTS:
		if view.select_part(slot):
			chosen = true
			break
	_check(chosen and not view._selected_part.is_empty() and
		not view.legal_targets().is_empty(), "precondition: genuine hero ability and lit target are selected")


func _assert_meter(view: StitchedBattleScreen, amount: int, expected: Dictionary) -> void:
	var battle := view.battle
	var meter := view._candle_meter
	var band := battle.candle_band()
	var canonical := StitchedS1BEffects.candle_band(amount)
	var caption := "CANDLE  %d / 100  ·  %s" % [amount, str(expected["name"]).to_upper()]
	_check(battle.candle() == amount and band == canonical and
		str(band.get("name", "")) == expected["name"],
		"battle band and authoritative S1B policy at " + str(amount))
	_check(int(band.get("fray_percent", -1)) == expected["fray"] and
		int(band.get("enemy_acc", -1)) == expected["acc"] and
		int(band.get("enemy_damage_percent", -1)) == expected["damage"] and
		int(band.get("loot_percent", -1)) == expected["loot"] and
		str(band.get("opening_side", "?")) == expected["opening"] and
		int(band.get("opening_percent", -1)) == expected["chance"],
		"independent canonical band effects at " + str(amount))
	_check(meter.value == amount and meter.fill.value == amount and
		meter.fill.max_value == 100 and meter.fill.min_value == 0 and
		meter.band_name == expected["name"] and meter.band_effects == band,
		"meter owns no second ledger and fills exactly " + str(amount))
	_check(view._labels["candle"] == meter.headline and meter.headline.is_visible_in_tree() and
		meter.headline.text == caption,
		"public candle label aliases the visible meter headline at " + str(amount))
	var readouts := 0
	for node in view.find_children("*", "Label", true, false):
		if node.is_visible_in_tree() and node.text.begins_with("CANDLE"):
			readouts += 1
	_check(readouts == 1, "exactly one visible CANDLE caption in mounted screen at " + str(amount))
	var headline := meter.headline
	var font := headline.get_theme_font("font")
	var font_size := headline.get_theme_font_size("font_size")
	var text_size := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	_check(text_size.x <= headline.size.x and font.get_height(font_size) <= headline.size.y and
		meter.fill.get_global_rect().encloses(headline.get_global_rect()) and
		not headline.get_global_rect().intersects(view._labels["round"].get_global_rect()) and
		not headline.get_global_rect().intersects(view._labels["order"].get_global_rect()) and
		not headline.get_global_rect().intersects(view._turn_ribbon.get_global_rect()),
		"actual caption font and bounds fit frame without round/order overlap at " + str(amount))
	_check(meter.info.focus_mode == Control.FOCUS_ALL and not meter.info.tooltip_text.is_empty() and
		meter.info.tooltip_text == meter.tooltip_text and
		meter.tooltip_text.contains("Fray gained: +%d%%" % expected["fray"]) and
		meter.tooltip_text.contains("Foe accuracy: +%d ACC" % expected["acc"]) and
		meter.tooltip_text.contains("Foe damage: +%d%%" % expected["damage"]) and
		meter.tooltip_text.contains("Loot: +%d%%" % expected["loot"]),
		"complete tooltip mirrors every canonical gameplay modifier at " + str(amount))
	_check(meter.tooltip_text.contains("Opening: ") and
		(meter.tooltip_text.contains("%d%% chance" % expected["chance"]) if expected["chance"] > 0 else
			meter.tooltip_text.contains("No extra first-strike chance")) and
		(not meter.tooltip_text.contains("guaranteed") or meter.tooltip_text.contains("not guaranteed")),
		"first-strike disclosure stays probabilistic at " + str(amount))
	_check(meter.is_visible_in_tree() and meter.position.x >= 645 and
		meter.position.x + meter.size.x < 1008 and meter.position.y + meter.size.y <= 46 and
		not meter.fill.mouse_filter == Control.MOUSE_FILTER_STOP and
		(meter.fill.value == 0 if amount == 0 else meter.fill.value > 0),
		"bar fits spare header without covering ribbon/label; Snuffed is empty")


func _verify_passive(view: StitchedBattleScreen, amount: int) -> void:
	var battle := view.battle
	var meter := view._candle_meter
	var before := battle.state_snapshot()
	var rng := battle.rng_state()
	var actor := battle.current_actor_id()
	var round := battle.round_number()
	var receipts := view.receipts.size()
	var selection := view._selected_part
	var targets := view.legal_targets()
	var inspected := view._inspected_seat
	var motion := view.reduced_motion
	meter.info.mouse_entered.emit()
	_check(meter.disclosure.visible and meter.disclosure_label.text.contains(meter.band_name.to_upper()) and
		meter.disclosure_label.text.contains("Foes +%d ACC" % int(meter.band_effects["enemy_acc"])),
		"mouse hover makes effect disclosure visible at " + str(amount))
	meter.info.mouse_exited.emit()
	_check(not meter.disclosure.visible, "exiting info hover hides disclosure at " + str(amount))
	meter.info.grab_focus()
	_check(meter.info.has_focus() and meter.disclosure.visible and
		meter.disclosure_label.text.contains("Fray +%d%%" % int(meter.band_effects["fray_percent"])),
		"keyboard focus reveals current risk even with zero light at " + str(amount))
	_check(meter.disclosure_label.get_line_count() <= meter.disclosure_label.get_visible_line_count(),
		"focused disclosure fits its stitched plate at " + str(amount))
	view._refresh()
	_check(meter.disclosure.visible and meter.info.has_focus(),
		"focus disclosure survives actual mounted refresh at " + str(amount))
	view._action_buttons["pass"].grab_focus()
	_check(not meter.disclosure.visible and not meter.info.has_focus(),
		"changing focus restores unobscured header at " + str(amount))
	view.set_reduced_motion(not motion)
	view._refresh()
	_check(view.reduced_motion != motion and meter.headline.text ==
		"CANDLE  %d / 100  ·  %s" % [amount, meter.band_name.to_upper()],
		"reduced motion preserves current caption at " + str(amount))
	view.set_reduced_motion(motion)
	_check(battle.state_snapshot() == before and battle.rng_state() == rng and
		battle.current_actor_id() == actor and battle.round_number() == round and
		view.receipts.size() == receipts and view._selected_part == selection and
		view.legal_targets() == targets and view._inspected_seat == inspected,
		"hover/focus/refresh are non-mutating for session, RNG, turn, receipts and targets at " + str(amount))
	for key in targets:
		_check(not view._target_buttons[key].disabled and not view._seat_buttons[key].disabled,
			"previous legal target affordance remains lit at " + str(amount))


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var first: StitchedBattleScreen = await _mount()
	if first == null:
		_finish()
		return
	_choose_part(first)
	_assert_meter(first, 78, CASES[76])
	_verify_passive(first, 78)
	# Move across the two narrowest edges on the SAME screen so stale text is caught.
	for target in [75, 76, 0, 1]:
		var before := first.battle.candle()
		var receipt := first.battle.adjust_candle("event", target - before)
		_check(receipt.get("ok") == true and receipt.get("before") == before and
			receipt.get("after") == target and receipt.get("band") == first.battle.candle_band(),
			"real event receipt applies the requested transition into " + str(target))
		var former := first._candle_meter.info.tooltip_text
		var former_band := first._candle_meter.band_name
		first._refresh()
		_assert_meter(first, target, CASES[target])
		_check(first._candle_meter.info.tooltip_text != former and
			first._candle_meter.band_name != former_band and
			not first._candle_meter.info.tooltip_text.contains("Candle %d–" % before),
			"no stale amount, band or explanation after crossing to " + str(target))
		_verify_passive(first, target)
	var ended := first.submit_retreat()
	_check(ended.get("ok") == true and first.battle.is_over(), "real Retreat produces a completed battle")
	if first.battle.is_over():
		_verify_passive(first, first.battle.candle())
	first.battle = null
	first._refresh()
	_check(not first._candle_meter.visible and first._candle_meter.value == -1 and
		first._candle_meter.info.tooltip_text.is_empty() and
		first._candle_meter.fill.value == 0 and first._labels["candle"].text.is_empty() and
		first._candle_meter.disclosure_label.text.is_empty() and
		not first._candle_meter.disclosure.visible,
		"unmounted/invalid session clears the stale risk display")
	first.free()
	await process_frame

	for amount in CASES:
		var view: StitchedBattleScreen = await _mount()
		if view == null:
			continue
		_choose_part(view)
		var receipt := view.battle.adjust_candle("event", int(amount) - 78)
		_check(receipt.get("ok") == true and receipt.get("source") == "event" and
			receipt.get("before") == 78 and receipt.get("after") == amount and
			receipt.get("band") == view.battle.candle_band(),
			"actual StitchedRules event delta and receipt for boundary " + str(amount))
		var preserved := view.battle.state_snapshot()
		var rng := view.battle.rng_state()
		view._refresh()
		_check(view.battle.state_snapshot() == preserved and view.battle.rng_state() == rng,
			"refresh after authentic candle adjustment is read-only at " + str(amount))
		_assert_meter(view, int(amount), CASES[amount])
		_verify_passive(view, int(amount))
		view.free()
		await process_frame

	var again: StitchedBattleScreen = await _mount()
	if again != null:
		_assert_meter(again, 78, CASES[76])
		_check(not again._candle_meter.info.tooltip_text.contains("SNUFFED") and
			again._candle_meter.fill.value == 78,
			"fresh session never inherits previous Snuffed candle or tooltip")
		again.free()
		await process_frame
	_finish()


func _finish() -> void:
	for issue in failures:
		printerr(issue)
	print("stitched_s6_battle_candle_meter_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
