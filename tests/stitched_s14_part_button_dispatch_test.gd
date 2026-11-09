extends SceneTree
## S14 fight bar (Mistral web playtest 11-09): a part button performs the fixed signature
## ability at its limb slot, so every bar gate judges that ability, not the part's retired
## skill. A settled action drops bar focus, and a refused click says why.
var failures: Array[String] = []
var checks := 0
const SEED := 55


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, why: String) -> void:
	checks += 1
	if not ok:
		failures.append(why)


func _screen(s14: bool) -> StitchedBattleScreen:
	var config := StitchedRunSession.starter_config(StitchedRunSession.DEFAULT_PICKS)
	_check(not config.is_empty(), "precondition: real starter config")
	config["seed"] = SEED
	config["s14"] = s14
	config["s14_sockets"] = {}
	var screen := StitchedBattleScreen.new()
	_check(screen.begin(config), "precondition: the battle screen begins (s14=%s)" % s14)
	return screen


## Passes real turns until the Lantern Monk acts; returns its unit.
func _monk_turn(screen: StitchedBattleScreen) -> Dictionary:
	for step in range(64):
		var unit: Dictionary = screen.battle._current_unit()
		if screen.battle.current_side() == "hero" and str(unit.get("id", "")).contains("lantern_monk"):
			return unit
		if screen.battle.is_over() or not screen.battle.pass_turn().get("ok", false):
			break
	return {}


func _verify_dispatch_gates() -> void:
	var screen := _screen(true)
	var monk := _monk_turn(screen)
	_check(not monk.is_empty(), "precondition: the Lantern Monk gets a turn")
	if monk.is_empty():
		return
	_check(int(monk.rank) == 4, "precondition: the Monk stands at rank 4, got %d" % int(monk.rank))
	var legs: Dictionary = monk.parts.get("legs", {})
	_check(screen._part_lock_reason(monk, legs) == "", "Pole Shelter is open at rank 4: " + screen._part_lock_reason(monk, legs))
	_check(screen._valid_part(monk, legs), "the legs button is valid at rank 4")
	var signature: Dictionary = screen._dispatched_ability(monk, legs)
	_check(str(signature.get("id", "")) == "lantern_monk_legs_pole_shelter",
		"legs dispatch the S14 Pole Shelter: " + str(signature.get("id", "")))
	var retired: Dictionary = StitchedParts.ability_at_tier(screen.parts[str(legs.id)], int(legs.tier))
	_check(not StitchedParts.ranks_allowed(int(retired.get("launch_mask", 0)), 4),
		"precondition: the retired legs skill itself cannot launch from rank 4")
	var receipt := screen.submit_part(str(legs.id), int(monk.rank))
	_check(not str(receipt.get("error", "")).contains("unavailable"), "submit_part accepts the rank-4 legs: " + str(receipt))
	screen.free()
	# Outside S14 the part keeps its own authored skill and its own launch ranks.
	var classic := _screen(false)
	var old_monk := _monk_turn(classic)
	if not old_monk.is_empty():
		var old_legs: Dictionary = old_monk.parts.get("legs", {})
		_check(str(classic._dispatched_ability(old_monk, old_legs).get("id", "")) == str(retired.get("id", "")),
			"non-S14 fights still use the part's own skill")
		_check(not classic._valid_part(old_monk, old_legs), "non-S14 rank-4 legs stay locked as before")
	classic.free()


func _verify_bar_focus_and_errors() -> void:
	var screen := StitchedBattleScreen.new()
	_check(screen.begin(StitchedBattleScreen.read_preview()), "precondition: preview battle starts")
	root.add_child(screen)
	await process_frame
	var fight := StitchedCorridorFight.attach(screen, "walls")
	await process_frame
	var button: Control = null
	for slot in fight.part_buttons:
		if fight.part_buttons[slot].visible:
			button = fight.part_buttons[slot]
			break
	_check(button != null, "precondition: a visible part button")
	if button != null:
		button.focus_mode = Control.FOCUS_ALL
		button.grab_focus()
		_check(root.gui_get_focus_owner() == button, "precondition: the part button holds focus")
		fight._act({"ok": true})
		_check(root.gui_get_focus_owner() != button, "a settled action drops the part button's focus")
		button.grab_focus()
		fight._act({"ok": true, "pending": "target"})
		_check(root.gui_get_focus_owner() == button, "an action still waiting for a target keeps focus")
	fight._act({"ok": false, "error": "illegal target"})
	_check(fight.log_label.text == "Illegal Target", "a refused click says why: " + fight.log_label.text)
	screen._selected_part = ""
	screen._hand_pending = ""
	var refused := fight.click_figure("foe", 1)
	_check(not bool(refused.get("ok", true)) and fight.log_label.text == "Pick an ability first.",
		"clicking a figure first asks for an ability: " + fight.log_label.text)
	for label in fight.find_children("*", "Label", true, false):
		_check(not label.text.to_lower().contains("body part"), "no 'body part' wording: " + label.text)
	screen.queue_free()
	await process_frame


## The S14 bar hover names the ability the button performs, with no slot heading, tier or stats.
func _verify_s14_hover() -> void:
	var screen := _screen(true)
	var monk := _monk_turn(screen)
	root.add_child(screen)
	await process_frame
	var fight := StitchedCorridorFight.attach(screen, "walls")
	await process_frame
	fight.refresh()
	var shown: Dictionary = screen.battle._current_unit()
	_check(str(shown.get("id", "")) == str(monk.get("id", "")), "precondition: the Monk is still acting")
	for slot in fight.part_buttons:
		var tip: String = fight.part_buttons[slot].tooltip_text
		var equipped: Dictionary = shown.parts.get(slot, {})
		var expected := str(screen._dispatched_ability(shown, equipped).get("name", ""))
		_check(not expected.is_empty() and tip.get_slice("\n", 0) == expected, slot + " hover names " + expected + ": " + tip)
		for word in ["HEAD", "ARM", "TORSO", "LEG", "body part", "patch", "·", "LAUNCH", "DMG"]:
			_check(not tip.contains(word), slot + " hover has no '" + word + "': " + tip)
		_check(not RegEx.create_from_string(r"\d").search(tip), slot + " hover shows no number: " + tip)
		if fight.part_buttons[slot].disabled:
			_check(tip.contains("\n"), slot + " is locked and says why: " + tip)
	_check(StitchedCorridorFight._plain_lock("Wrong launch rank (current R4)") == "Can't be used from this spot.",
		"a rank lock reads plainly")
	_check(StitchedCorridorFight._plain_lock("") == "", "an open ability adds no line")
	screen.queue_free()
	await process_frame


func _run() -> void:
	root.size = Vector2i(1280, 720)
	_verify_dispatch_gates()
	await _verify_s14_hover()
	await _verify_bar_focus_and_errors()
	if failures.is_empty():
		print("PASS stitched_s14_part_button_dispatch_test (%d checks)" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL stitched_s14_part_button_dispatch_test (%d of %d checks)" % [failures.size(), checks])
		quit(1)
