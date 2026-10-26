extends SceneTree

const STRIKE := "warden_strike"
const PRICK := "seamstress_prick"
## The one seed this mounted session uses for its global-RNG purity check.
const RNG_SEED := 264
var failures: Array[String] = []
var checks := 0
var intents: Array[Dictionary] = []
var panel: LiveSewingCirclePanel

## The view never calls this controller. Submission is explicitly separate.
class Controller:
	static func submit(visit: RunSewingCircleVisit, intent: Dictionary) -> Dictionary:
		var source: Dictionary = intent.source_snapshot
		match intent.action:
			"upgrade": return visit.choose_upgrade(intent.first_index, intent.visit_id, intent.node_id, source)
			"stitch": return visit.choose_stitch(intent.first_index, intent.second_index, intent.visit_id, intent.node_id, source)
			"leave": return visit.leave(intent.visit_id, intent.node_id, source)
		return {"ok": false}


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _make(deck: Array = [STRIKE, STRIKE, PRICK], scraps: int = 7) -> RunSewingCircleVisit:
	return RunSewingCircleVisit.new("circle-264", deck, {}, scraps, 1)


func _settle_layout() -> void:
	for i in range(4):
		await process_frame


func _activate(button: Button, keyboard: bool) -> void:
	_check(button != null and button.is_visible_in_tree() and not button.disabled, "real enabled mounted action")
	if keyboard:
		button.grab_focus()
		_check(button.has_focus(), "keyboard action has focus")
		for down in [true, false]:
			var event := InputEventKey.new()
			event.keycode = KEY_ENTER
			event.pressed = down
			root.push_input(event)
			await process_frame
	else:
		var point := button.get_global_rect().get_center()
		var motion := InputEventMouseMotion.new()
		motion.position = point
		root.push_input(motion)
		for down in [true, false]:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.position = point
			event.pressed = down
			root.push_input(event)
			await process_frame
	await _settle_layout()


## A genuine physical key press pushed through the mounted SceneTree, exactly as
## a player's keyboard would: no direct callback calls and no view-side service.
func _key(keycode: int, pressed: bool = true, echo: bool = false,
		modified: Dictionary = {}) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	event.echo = echo
	event.ctrl_pressed = modified.get("ctrl", false)
	event.alt_pressed = modified.get("alt", false)
	event.shift_pressed = modified.get("shift", false)
	event.meta_pressed = modified.get("meta", false)
	root.push_input(event)
	await _settle_layout()


func _bind(visit: RunSewingCircleVisit) -> void:
	intents.clear()
	panel.bind(visit)
	await _settle_layout()
	_check(visit.is_valid() and not visit.is_consumed(), "authentic open visit prerequisite")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	panel = LiveSewingCirclePanel.new()
	panel.position = Vector2(170, 50)
	panel.bind(_make()) # Binding before mounting is supported.
	root.add_child(panel)
	panel.intent_requested.connect(func(intent: Dictionary): intents.append(intent))
	await _settle_layout()
	_check(panel.upgrade_button.has_focus(), "mount makes the first primary action the keyboard stop")
	# Cosmetic mounts are done: from here the panel may only present state, so a
	# seeded global RNG must read the same after every browse and decision.
	seed(RNG_SEED)
	var seeded_next := randi()
	seed(RNG_SEED)
	await _test_layout()
	_check(panel._effects({"z_other": 9, "bleed": 2, "damage": 3, "a_other": 4})
		== "Deal 3 damage; apply Bleed 2; a other: 4; z other: 9",
		"mixed known and unknown fields preserve values in deterministic reading order")
	_check(panel._effects({"draw": 1, "weak": 1, "heal": 5, "block": 7})
		== "Gain 7 Block; heal 5 HP; apply Weak 1; draw 1 card"
		and panel._effects({}) == "No effects",
		"authored non-damage effects are readable and an empty source stays neutral")
	for keyboard in [false, true]:
		await _test_upgrade(keyboard)
		await _test_stitch(keyboard)
		await _test_pool_upgrade(keyboard)
		await _test_pool_stitch(keyboard)
		await _test_leave(keyboard)
	await _test_shortcuts()
	await _test_confirmation_handoff()
	await _test_rejections()
	_check(randi() == seeded_next, "mounted browsing and decisions consume no global RNG")
	panel.queue_free()
	await process_frame
	for failure in failures:
		printerr(failure)
	print("live_sewing_circle_panel_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _test_layout() -> void:
	var deck: Array = []
	for i in range(30):
		deck.append(STRIKE if i % 2 == 0 else PRICK)
	var visit := _make(deck)
	await _bind(visit)
	var source := visit.read_state()
	var viewport := Rect2(0, 0, 1280, 720)
	for control in [panel, panel.upgrade_button, panel.stitch_button, panel.leave_button, panel.confirm_button, panel.choice_scroll, panel.preview_scroll, panel.status_label]:
		_check(viewport.encloses(control.get_global_rect()), "panel/action/scroll fits viewport")
	# Exactly the visit's three canonical decisions are primary actions; every
	# further button belongs to the scrollable occurrence list.
	var primaries: Array[Button] = []
	for child in panel.get_children():
		if child is Button and child != panel.confirm_button:
			primaries.append(child)
	_check(visit.quote().choices == ["upgrade", "stitch", "leave"], "authentic three canonical decisions")
	_check(primaries == [panel.upgrade_button, panel.stitch_button, panel.leave_button], "exactly three primary actions")
	_check(not panel.upgrade_button.disabled and not panel.stitch_button.disabled and not panel.leave_button.disabled,
		"all three actions are live on a genuine open visit")
	_check(panel.status_label.text.contains("3 scraps") and panel.upgrade_button.text.contains("free")
		and panel.stitch_button.text.contains("3 scraps") and panel.leave_button.text.contains("free"), "visible canonical costs")
	# The shortcut mapping is printed on the same four existing actions, and each
	# caption still fits its sewn button at 1280x720.
	_check(panel.upgrade_button.text.contains("1 ") and panel.upgrade_button.text.contains("Upgrade")
		and panel.stitch_button.text.contains("2 ") and panel.stitch_button.text.contains("Stitch")
		and panel.leave_button.text.contains("0 ") and panel.leave_button.text.contains("Leave")
		and panel.confirm_button.text.contains("3 ") and panel.confirm_button.text.contains("Confirm"),
		"number-key mapping is printed on the four existing actions")
	for action in [panel.upgrade_button, panel.stitch_button, panel.leave_button, panel.confirm_button]:
		_check(_fits(action), "shortcut caption fits its existing button at 1280x720")
	# Every interaction state of a sewn action keeps dark, readable ink instead of
	# the shared theme's near-white defaults on this cream felt.
	for ink_state in ["font_color", "font_hover_color", "font_pressed_color",
			"font_hover_pressed_color", "font_focus_color"]:
		_check(panel.upgrade_button.get_theme_color(ink_state).get_luminance() < 0.45,
			"action ink stays readable in " + ink_state)
	_check(panel.stitch_button.get_theme_color("font_disabled_color").get_luminance() < 0.6,
		"an unaffordable action keeps readable ink")
	panel.upgrade_button.grab_focus()
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	root.push_input(tab)
	await process_frame
	_check(panel.stitch_button.has_focus(), "Tab reaches next primary action")
	tab = InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	root.push_input(tab)
	await process_frame
	_check(panel.leave_button.has_focus(), "Tab reaches the third primary action")
	_check(not panel.choice_scroll.get_global_rect().intersects(panel.preview_scroll.get_global_rect())
		and not panel.choice_scroll.get_global_rect().intersects(panel.confirm_button.get_global_rect()), "choices and preview stay clear of pinned confirmation")
	await _activate(panel.upgrade_button, false)
	_check(panel.option_buttons.size() == visit.upgrade_options().size() and panel.option_buttons.size() == 30, "nonempty canonical occurrence options")
	var canonical_upgrades: Array = visit.upgrade_options()
	for i in range(panel.option_buttons.size()):
		_check(panel.option_buttons[i].get_meta("option") == canonical_upgrades[i], "exact canonical upgrade metadata")
		# The rendered caption names the authored card, its owner and the
		# one-based copy the zero-based option index addresses.
		var rendered: String = panel.option_buttons[i].text
		_check(rendered.contains(canonical_upgrades[i].display_name)
			and rendered.contains(canonical_upgrades[i].owner)
			and rendered.contains("copy #%d" % (canonical_upgrades[i].index + 1)), "readable occurrence caption")
		_check(_card_ink(panel.option_buttons[i]).contains(canonical_upgrades[i].display_name)
			and _card_ink(panel.option_buttons[i]).contains(canonical_upgrades[i].plus_display_name)
			and _card_ink(panel.option_buttons[i]).contains("copy #%d" % (canonical_upgrades[i].index + 1))
			and _card_ink(panel.option_buttons[i]).contains("%d energy" % canonical_upgrades[i].cost)
			and _card_ink(panel.option_buttons[i]).contains("%d energy" % canonical_upgrades[i].plus_cost),
			"sewn ink exposes original, upgraded name, costs and canonical copy")
		_assert_decorations(panel.option_buttons[i])
	_check(viewport.encloses(panel.option_buttons[0].get_global_rect()), "first fully shown mini-card fits viewport")
	for button in panel.option_buttons:
		var clipped := button.get_global_rect().intersection(panel.choice_scroll.get_global_rect())
		_check(not clipped.intersects(panel.confirm_button.get_global_rect())
			and button.size.x <= panel.choice_scroll.size.x and button.size.y >= 100,
			"even offscreen copies only paint inside the choice scroll, never Confirm")
	_check(panel.choice_scroll.clip_contents and panel.choice_scroll.size == Vector2(440, 350)
		and panel.preview_scroll.size == Vector2(428, 350), "fixed clipped two-column layout")
	_check(panel.choice_scroll.get_v_scroll_bar().max_value > panel.choice_scroll.size.y, "long deck contained in scroll")
	panel.option_buttons.back().grab_focus()
	await _settle_layout()
	_check(panel.choice_scroll.scroll_vertical > 0, "keyboard focus reveals offscreen copy")
	_check(visit.read_state() == source and intents.is_empty(), "browse does not change any ledger")


## Expectations come directly from independently resolved cards, not the panel's
## formatting helpers or loose choice.effects fields.
func _expected_detail(card: Dictionary, index: int) -> String:
	var recipient := ""
	match str(card.target_kind):
		"enemy_single": recipient = "ENEMY TO %s" % str(card.to_positions)
		"enemy_all": recipient = "ALL ENEMIES TO %s" % str(card.to_positions)
		"enemy_random": recipient = "RANDOM ENEMY TO %s" % str(card.to_positions)
		"self": recipient = "TARGET: self"
		"ally_single": recipient = "TARGET: chosen ally"
		"party_all": recipient = "TARGET: all allies"
		"none": recipient = "TARGET: no chosen target"
		_: recipient = "TARGET: %s" % str(card.target_kind)
	return "%s | %s | %s | copy #%d | %d energy\nFROM %s | %s\n%s" % [
		str(card.owner).capitalize(), card.display_name, card.id, index + 1,
		card.cost, str(card.from_positions), recipient, CardShortRules.line(card)]


func _row_at(index: int) -> Button:
	for button in panel.option_buttons:
		if button.get_meta("option").index == index:
			return button
	_check(false, "a genuine catalog instance must have its own physical row #%d" % (index + 1))
	return null


func _test_upgrade(keyboard: bool) -> void:
	var visit := _make()
	await _bind(visit)
	var source := visit.read_state()
	var starter := StarterCards.new()
	var strike := starter.get_definition(STRIKE)
	var strike_plus := starter.get_definition("warden_strike_plus")
	var prick := starter.get_definition(PRICK)
	var prick_plus := starter.get_definition("seamstress_prick_plus")
	_check(strike.cost == 1 and strike.effects == {"damage": 6}
		and strike_plus.cost == 1 and strike_plus.effects == {"damage": 7}
		and prick.cost == 1 and prick.effects == {"damage": 3, "bleed": 2}
		and prick_plus.effects == {"damage": 4, "bleed": 3},
		"independent authored Strike, Strike+, Prick and Prick+ preconditions")
	await _activate(panel.upgrade_button, keyboard)
	_check(panel.option_buttons.size() == 3 and panel.confirm_button.disabled, "upgrade needs explicit occurrence")
	_check(visit.upgrade_options()[1].effects == strike.effects
		and visit.upgrade_options()[1].plus_effects == strike_plus.effects
		and visit.upgrade_options()[2].effects == prick.effects
		and visit.upgrade_options()[2].plus_effects == prick_plus.effects,
		"authentic typed upgrade options carry independent authored effects")
	_check(_card_ink(panel.option_buttons[2]).contains(CardShortRules.line(prick))
		and _card_ink(panel.option_buttons[2]).contains(CardShortRules.line(prick_plus))
		and panel.option_buttons[2].tooltip_text.contains(_expected_detail(prick, 2))
		and panel.option_buttons[2].tooltip_text.contains(_expected_detail(prick_plus, 2)),
		"real Prick row Help derives both card lines and positions from catalog")
	panel.option_buttons[2].grab_focus()
	await _settle_layout()
	await _activate(panel.option_buttons[2], keyboard)
	_check(panel.preview().index == 2
		and panel.preview_label.text.contains("BEFORE | " + _expected_detail(prick, 2))
		and panel.preview_label.text.contains("AFTER | " + _expected_detail(prick_plus, 2)),
		"real Prick preview explains authentic before and after")
	panel.option_buttons[1].grab_focus()
	await _settle_layout()
	await _activate(panel.option_buttons[1], keyboard)
	_check(panel.preview().index == 1 and panel.preview().effects == {"damage": 6}
		and panel.preview().plus_effects == {"damage": 7}, "genuine upgrade preview for second duplicate")
	_check(panel.option_buttons[1].get_meta("selected") and not panel.option_buttons[0].get_meta("selected"),
		"only the selected duplicate carries a sewn selection highlight")
	var upgrade_ink := _card_ink(panel.option_buttons[1])
	_check(upgrade_ink.contains("Warden") and upgrade_ink.contains(visit.upgrade_options()[1].display_name)
		and upgrade_ink.contains(visit.upgrade_options()[1].plus_display_name)
		and upgrade_ink.contains(CardShortRules.line(strike))
		and upgrade_ink.contains(CardShortRules.line(strike_plus))
		and panel.option_buttons[1].tooltip_text.contains(_expected_detail(strike, 1))
		and panel.option_buttons[1].tooltip_text.contains(_expected_detail(strike_plus, 1)),
		"real Warden occurrence displays independently authored energy, positions and 6-to-7 change")
	_check(panel.preview_label.text.contains("BEFORE | " + _expected_detail(strike, 1))
		and panel.preview_label.text.contains("AFTER | " + _expected_detail(strike_plus, 1))
		and panel.preview_label.text.contains("Only copy #2 changes"),
		"source-true card line and legal slots for selected duplicate")
	await _activate(panel.confirm_button, keyboard)
	_check(intents.size() == 1 and visit.read_state() == source, "UI emits once and never settles")
	if intents.size() != 1:
		return
	var intent := intents[0]
	_check(intent == {"action": "upgrade", "first_index": 1, "second_index": -1,
		"visit_id": source.visit_id, "node_id": source.node_id, "source_snapshot": source}, "mouse/keyboard exact source-bound upgrade intent")
	var result := Controller.submit(visit, intent)
	var oracle := RunRestCardUpgrade.new(source.deck, {STRIKE: "warden_strike_plus"}, {}, 1).choose_upgrade(1)
	_check(result.ok and result.action == "upgrade" and result.transaction == oracle, "exact typed upgrade transaction")
	_check(result.deck == [STRIKE, "warden_strike_plus", PRICK], "only selected duplicate upgraded")
	_check_receipt(result, source, 0)
	_check_replay(visit, intent)
	var after := visit.read_state()
	intent.source_snapshot.deck.clear()
	_check(visit.read_state() == after, "emitted intent detached from authority")


func _test_stitch(keyboard: bool) -> void:
	var visit := _make()
	await _bind(visit)
	var source := visit.read_state()
	var expected := visit.stitch_preview(1, 2)
	var starter := StarterCards.new()
	var first_def := starter.get_definition(STRIKE)
	var second_def := starter.get_definition(PRICK)
	_check(not expected.is_empty() and first_def.owner == "warden"
		and second_def.owner == "seamstress" and first_def.owner != second_def.owner
		and first_def.cost == 1 and second_def.cost == 1
		and first_def.effects == {"damage": 6}
		and second_def.effects == {"damage": 3, "bleed": 2},
		"genuine two-owner authored half preconditions")
	_check(expected.first_half == first_def and expected.second_half == second_def
		and expected.energy_cost == mini(3, maxi(first_def.cost, second_def.cost) + 1)
		and expected.energy_cost == 2 and expected.scrap_cost == 3
		and expected.remaining_scraps == 4 and expected.first_index == 1
		and expected.second_index == 2, "independent source-bound Stitch projection, energy cap and spend")
	await _activate(panel.stitch_button, keyboard)
	_check(panel.option_buttons.size() == 3, "canonical first copies including duplicates")
	_check(_card_ink(panel.option_buttons[1]).contains(CardShortRules.line(first_def)),
		"first-stage source row displays Warden's actual effect")
	for i in range(panel.option_buttons.size()):
		_check(panel.option_buttons[i].get_meta("option") == visit.stitch_first_options()[i], "exact canonical stitch first occurrence metadata")
	await _activate(panel.option_buttons[1], keyboard)
	_check(panel.option_buttons.size() == 1 and panel.option_buttons[0].get_meta("option").index == 2, "second stage only different-owner occurrence")
	_check(panel.option_buttons[0].get_meta("option") == visit.stitch_second_options(1)[0], "exact canonical stitch partner metadata")
	_check(panel.preview_label.text.contains("FIRST | " + _expected_detail(first_def, 1))
		and panel.preview_label.text.contains("DIFFERENT owner")
		and panel.preview_label.text.contains("each in their own legal FROM position")
		and _card_ink(panel.option_buttons[0]).contains("Seamstress")
		and _card_ink(panel.option_buttons[0]).contains(CardShortRules.line(second_def))
		and panel.option_buttons[0].tooltip_text.contains(_expected_detail(second_def, 2)),
		"real FIRST preview and THEN row Help show full catalog rules")
	_assert_decorations(panel.option_buttons[0])
	await _activate(panel.option_buttons[0], keyboard)
	_check(panel.preview() == expected and panel.preview_label.text.contains("Scraps: 7 -> 4"), "exact detached genuine stitch forecast")
	_check(panel.option_buttons[0].get_meta("selected")
		and panel.preview_label.text.contains("FIRST | " + _expected_detail(first_def, 1))
		and panel.preview_label.text.contains("THEN | " + _expected_detail(second_def, 2))
		and panel.preview_label.text.contains("Energy: 2 (max half + 1, capped at 3)")
		and panel.preview_label.text.contains("Scraps: 7 -> 4 (cost 3)")
		and panel.preview_label.text.contains("Both owners must be alive, each in their own legal FROM position"),
		"highlighted ordered FIRST/THEN full halves keep original owner and play caveat")
	_check(panel.preview_label.text.contains(expected.display_name)
		and panel.preview_label.text.contains("Energy: %d" % expected.energy_cost)
		and panel.preview_label.text.contains("Deck: %d -> %d cards" % [expected.deck_before_count, expected.deck_after_count]),
		"visible genuine stitch forecast")
	_check(panel.option_buttons.size() == 1 and panel.confirm_button.disabled == false, "chosen pair can be confirmed")
	var detached := panel.preview()
	detached.descriptor.clear()
	_check(panel.preview() == expected, "preview query detached")
	await _activate(panel.confirm_button, keyboard)
	_check(intents.size() == 1 and visit.read_state() == source, "stitch intent does not spend")
	if intents.size() != 1:
		return
	var intent := intents[0]
	_check(intent.action == "stitch" and intent.first_index == 1 and intent.second_index == 2 and intent.source_snapshot == source, "equivalent source-bound stitch intent")
	var result := Controller.submit(visit, intent)
	_check(result.ok and result.action == "stitch" and result.transaction == expected.projection, "exact typed stitch receipt")
	_check(result.deck == expected.resulting_deck and result.deck.count(STRIKE) == 1
		and result.descriptors == {expected.stitched_id: expected.descriptor}
		and result.next_stitch_id == 2 and result.remaining_scraps == 4, "two selected copies consumed, duplicate preserved, exact payment and cursor")
	_check_receipt(result, source, 3)
	_check_replay(visit, intent)


## Real reward-pool cards with distinct legal source and recipient positions.
## Every occurrence is checked against the independent catalog resolver.
func _test_pool_upgrade(keyboard: bool) -> void:
	const PIN := "warden_pinning_jab"
	const SNAG := "seamstress_snag"
	const GUARD := "warden_patch_guard"
	var visit := _make([PIN, SNAG, GUARD], 3)
	await _bind(visit)
	var source := visit.read_state()
	var pin := RunRestStitchCards.resolve_card_definition(PIN)
	var pin_plus := RunRestStitchCards.resolve_card_definition(PIN + "_plus")
	var snag := RunRestStitchCards.resolve_card_definition(SNAG)
	var snag_plus := RunRestStitchCards.resolve_card_definition(SNAG + "_plus")
	var guard := RunRestStitchCards.resolve_card_definition(GUARD)
	_check(visit.is_valid() and source.deck == [PIN, SNAG, GUARD]
		and pin.owner == "warden" and snag.owner == "seamstress"
		and pin.cost == 1 and pin_plus.cost == 1 and pin.from_positions == [1, 2]
		and pin.to_positions == [1] and pin.target_kind == "enemy_single"
		and pin.effects == {"damage": 4, "pinned": true}
		and pin_plus.effects == {"damage": 6, "pinned": true}
		and snag.cost == 1 and snag_plus.cost == 1 and snag.from_positions == [2, 3]
		and snag.to_positions == [1, 2, 3] and snag.target_kind == "enemy_single"
		and snag.effects == {"unravel": 3, "weak": 1}
		and snag_plus.effects == {"unravel": 4, "weak": 1}
		and guard.target_kind == "ally_single" and guard.to_positions.is_empty(),
		"nonvacuous authored Pinning Jab, Snag and chosen-ally source preconditions")
	await _activate(panel.upgrade_button, keyboard)
	var upgrades := visit.upgrade_options()
	_check(upgrades.size() >= 3 and panel.option_buttons.size() == upgrades.size()
		and panel.confirm_button.disabled, "catalog-backed occurrence list requires an explicit upgrade choice")
	for option in upgrades:
		var row := _row_at(option.index)
		if row == null:
			return
		var before := RunRestStitchCards.resolve_card_definition(option.source_id)
		var after := RunRestStitchCards.resolve_card_definition(option.plus_id)
		_check(not before.is_empty() and not after.is_empty()
			and source.deck[option.index] == before.id and option.owner == before.owner
			and option.cost == before.cost and option.plus_cost == after.cost
			and option.effects == before.effects and option.plus_effects == after.effects,
			"each authorized pool upgrade row binds exact authentic definitions")
		_check(row.tooltip_text.contains("BEFORE | " + _expected_detail(before, option.index))
			and row.tooltip_text.contains("AFTER | " + _expected_detail(after, option.index))
			and _card_ink(row).contains(CardShortRules.line(before))
			and _card_ink(row).contains(CardShortRules.line(after)),
			"hover/focus Help and row ink carry both printed catalog action lines and positions")
		row.grab_focus()
		await _settle_layout()
		var prior_preview := panel.preview()
		var prior_confirm_disabled := panel.confirm_button.disabled
		var hover := InputEventMouseMotion.new()
		hover.position = row.get_global_rect().get_center()
		root.push_input(hover)
		await process_frame
		_check(intents.is_empty() and visit.read_state() == source
			and panel.preview() == prior_preview
			and panel.confirm_button.disabled == prior_confirm_disabled,
			"hover and keyboard focus on authentic Help are read-only and create no intents")
		await _activate(row, keyboard)
		_check(panel.preview().index == option.index
			and panel.preview_label.text.contains("BEFORE | " + _expected_detail(before, option.index))
			and panel.preview_label.text.contains("AFTER | " + _expected_detail(after, option.index))
			and panel.preview_label.text.contains("Cost: free. Only copy #%d changes." % (option.index + 1)),
			"selected BEFORE/AFTER is the two complete canonical card records")
	_check(not panel.option_buttons[0].tooltip_text.contains("pinned: True")
		and panel.option_buttons[0].tooltip_text.contains(CardShortRules.line(pin))
		and panel.option_buttons[1].tooltip_text.contains(CardShortRules.line(snag)),
		"Pin and Unravel are authored keywords, never raw booleans or invented turn durations")
	_check(not panel.option_buttons[2].tooltip_text.contains("ENEMY TO")
		and panel.option_buttons[2].tooltip_text.contains("TARGET: chosen ally"),
		"support-target Help names the real recipient with no imaginary enemy slots")
	var unknown := pin.duplicate(true)
	unknown.effects["mystery_keyword"] = 19
	_check(CardShortRules.line(unknown).contains(CardShortRules.UNKNOWN_SENTENCE)
		and panel._card_detail(unknown, 0).contains(CardShortRules.UNKNOWN_SENTENCE),
		"unrecognized effect keeps CardShortRules' honest unknown-effect fallback")
	var pin_row := _row_at(0)
	if pin_row == null:
		return
	pin_row.grab_focus()
	await _settle_layout()
	await _activate(pin_row, keyboard)
	await _activate(panel.confirm_button, keyboard)
	_check(intents.size() == 1 and visit.read_state() == source,
		"pool Upgrade still sends one physical intent with no direct spend")
	if intents.size() != 1:
		return
	var intent := intents[0]
	var result := Controller.submit(visit, intent)
	_check(intent.action == "upgrade" and intent.first_index == 0
		and intent.source_snapshot == source and result.ok
		and result.deck == [PIN + "_plus", SNAG, GUARD]
		and result.charged_scraps == 0 and result.remaining_scraps == 3,
		"free pool upgrade replaces only the selected original occurrence")
	_check_receipt(result, source, 0)
	_check_replay(visit, intent)


func _test_pool_stitch(keyboard: bool) -> void:
	const PIN := "warden_pinning_jab"
	const SNAG := "seamstress_snag"
	var visit := _make([PIN, SNAG], 3)
	await _bind(visit)
	var source := visit.read_state()
	var first := RunRestStitchCards.resolve_card_definition(PIN)
	var second := RunRestStitchCards.resolve_card_definition(SNAG)
	var first_option: Dictionary = {}
	var second_option: Dictionary = {}
	for candidate in visit.stitch_first_options():
		if candidate.id == PIN and candidate.owner == first.owner:
			first_option = candidate
			break
	if not first_option.is_empty():
		for candidate in visit.stitch_second_options(first_option.index):
			if candidate.id == SNAG and candidate.owner == second.owner:
				second_option = candidate
				break
	_check(visit.is_valid() and source.deck == [PIN, SNAG] and source.remaining_scraps == 3
		and not first_option.is_empty() and not second_option.is_empty()
		and first.owner != second.owner and first.cost == 1 and second.cost == 1
		and first.from_positions == [1, 2] and first.to_positions == [1]
		and second.from_positions == [2, 3] and second.to_positions == [1, 2, 3],
		"payable source-authentic two-owner pool stitch and position preconditions")
	if first_option.is_empty() or second_option.is_empty():
		return
	var pair := visit.stitch_preview(first_option.index, second_option.index)
	_check(not pair.is_empty() and pair.first_half == first and pair.second_half == second
		and pair.first_id == PIN and pair.second_id == SNAG
		and pair.energy_cost == 2 and pair.scrap_cost == 3 and pair.remaining_scraps == 0
		and pair.deck_after_count == pair.deck_before_count - 1,
		"true visit projection gives exact 2-energy FIRST/THEN and 3-scrap cost")
	await _activate(panel.stitch_button, keyboard)
	var first_row := _row_at(first_option.index)
	if first_row == null:
		return
	_check(first_row.tooltip_text.contains("FIRST | " + _expected_detail(first, first_option.index))
		and panel.confirm_button.disabled, "FIRST Help shows real Warden positions and Pin")
	first_row.grab_focus()
	await _settle_layout()
	await _activate(first_row, keyboard)
	var second_row := _row_at(second_option.index)
	if second_row == null:
		return
	_check(second_row.tooltip_text.contains("THEN | " + _expected_detail(second, second_option.index))
		and panel.preview_label.text.contains("FIRST | " + _expected_detail(first, first_option.index))
		and panel.confirm_button.disabled, "THEN Help preserves source-order and nonactionable half pair")
	second_row.grab_focus()
	await _settle_layout()
	_check(intents.is_empty() and visit.read_state() == source,
		"focus on THEN Help is read-only")
	await _activate(second_row, keyboard)
	_check(panel.preview() == pair and panel.option_buttons.has(second_row)
		and panel.preview_label.text.contains("FIRST | " + _expected_detail(pair.first_half, first_option.index))
		and panel.preview_label.text.contains("THEN | " + _expected_detail(pair.second_half, second_option.index))
		and panel.preview_label.text.contains("Energy: 2 (max half + 1, capped at 3)")
		and panel.preview_label.text.contains("Scraps: 3 -> 0 (cost 3)")
		and panel.preview_label.text.contains("Deck: 2 -> 1 cards")
		and not panel.confirm_button.disabled,
		"selected fully ordered pool stitch quotes source-bound energy, currency and deck delta")
	await _activate(panel.confirm_button, keyboard)
	_check(intents.size() == 1 and visit.read_state() == source,
		"physical Confirm emits a single source-backed composite intent")
	if intents.size() != 1:
		return
	var intent := intents[0]
	var receipt := Controller.submit(visit, intent)
	_check(intent.action == "stitch" and intent.first_index == first_option.index
		and intent.second_index == second_option.index and intent.source_snapshot == source
		and receipt.ok and receipt.transaction == pair.projection
		and receipt.deck == pair.resulting_deck and receipt.deck.size() == 1
		and receipt.remaining_scraps == 0 and receipt.charged_scraps == 3
		and receipt.descriptors == {pair.stitched_id: pair.descriptor},
		"one real controller settlement preserves exactly ordered halves and single payment")
	_check_receipt(receipt, source, 3)
	_check_replay(visit, intent)


func _check_receipt(result: Dictionary, source: Dictionary, cost: int) -> void:
	_check(result.source_snapshot == source and result.source_receipt == source.receipt
		and result.visit_id == source.visit_id and result.node_id == source.node_id
		and result.consumed and result.valid and result.charged_scraps == cost, "complete typed authenticated receipt")
	# The one legitimate decision changed the ledger, so its own receipt moved on.
	_check(typeof(result.receipt) == TYPE_STRING and not result.receipt.is_empty()
		and result.receipt != source.receipt, "settled ledger carries its own advanced receipt")
	if cost == 0:
		_check(result.remaining_scraps == source.remaining_scraps and result.descriptors == source.descriptors
			and result.next_stitch_id == source.next_stitch_id, "all non-deck ledgers preserved")


func _check_replay(visit: RunSewingCircleVisit, intent: Dictionary) -> void:
	var after := visit.read_state()
	_check(Controller.submit(visit, intent) == {"ok": false} and visit.read_state() == after, "replay exact rejection and no spend")
	panel.confirm_button.pressed.emit()
	panel.leave_button.pressed.emit()
	_check(intents.size() == 1 and visit.read_state() == after, "double activation cannot emit another intent")


func _test_leave(keyboard: bool) -> void:
	var visit := _make()
	await _bind(visit)
	var source := visit.read_state()
	await _activate(panel.leave_button, keyboard)
	_check(intents.is_empty(), "Leave also requires confirmation")
	await _activate(panel.confirm_button, keyboard)
	_check(intents.size() == 1 and visit.read_state() == source, "Leave emits only")
	if intents.size() != 1:
		return
	var result := Controller.submit(visit, intents[0])
	var expected := source.duplicate(true)
	expected.consumed = true
	expected.merge({"ok": true, "action": "leave", "transaction": {}, "source_snapshot": source,
		"source_receipt": source.receipt, "charged_scraps": 0})
	_check(result == expected, "exact Leave receipt preserves complete ledger")
	_check_replay(visit, intents[0])


## Only this panel's own physical Confirm may mint the payload its controller
## settles: the hand-off is exact, detached and one-shot, and rebind/close retire it.
func _test_confirmation_handoff() -> void:
	var visit := _make()
	await _bind(visit)
	var source := visit.read_state()
	var forwarded := {"action": "leave", "first_index": -1, "second_index": -1,
		"visit_id": source.visit_id, "node_id": source.node_id, "source_snapshot": source}
	_check(panel.take_confirmed(forwarded) == {} and panel._confirmed.is_empty(),
		"no direct call can mint a confirmed payload")
	await _activate(panel.leave_button, false)
	_check(panel.take_confirmed(forwarded) == {} and panel._confirmed.is_empty() and intents.is_empty(),
		"an unconfirmed selection mints nothing and emits nothing")
	await _activate(panel.confirm_button, false)
	_check(intents.size() == 1 and panel._submitted and not panel._confirmed.is_empty(),
		"physical Confirm mints exactly one pending payload")
	if intents.size() != 1:
		return
	var confirmed := intents[0]
	var altered_action := confirmed.duplicate(true)
	altered_action.action = "upgrade"
	var altered_index := confirmed.duplicate(true)
	altered_index.first_index = 0
	var altered_snapshot := confirmed.duplicate(true)
	altered_snapshot.source_snapshot.remaining_scraps += 1
	var extra_key := confirmed.duplicate(true)
	extra_key.result = "ok"
	for altered in [altered_action, altered_index, altered_snapshot, extra_key]:
		_check(panel.take_confirmed(altered) == {} and panel._confirmed == confirmed,
			"an altered payload never matches or consumes the pending confirmation")
	var handed := panel.take_confirmed(confirmed)
	_check(handed == confirmed and panel._confirmed.is_empty(),
		"the exact confirmed payload is handed over once")
	_check(panel.take_confirmed(confirmed) == {} and panel._confirmed.is_empty(),
		"a second hand-over gets nothing")
	var second := _make()
	await _bind(second)
	await _activate(panel.upgrade_button, false)
	await _activate(panel.option_buttons[1], false)
	await _activate(panel.confirm_button, false)
	_check(intents.size() == 1 and panel._submitted and not panel._confirmed.is_empty(),
		"a fresh visit mints its own pending payload")
	if intents.size() != 1:
		return
	var pending := intents[0]
	await _bind(_make())
	_check(panel._confirmed.is_empty() and not panel._submitted and panel.take_confirmed(pending) == {},
		"rebind retires an unconsumed confirmed payload")
	await _activate(panel.leave_button, true)
	await _activate(panel.confirm_button, true)
	_check(intents.size() == 1 and not panel._confirmed.is_empty(), "a rebound visit mints its own payload")
	if intents.size() != 1:
		return
	var before_close := intents[0]
	panel.close()
	_check(not panel.visible and panel._confirmed.is_empty() and not panel._submitted
		and panel.take_confirmed(before_close) == {}, "close retires the pending confirmed payload")


## Physical number keys are only an alias for the four mounted Buttons. A valid
## press must land on the very same Button.pressed path as a mouse or Tab/Enter
## press, so each confirmed action below is compared with the authenticated
## source-bound intent and the real controller receipt.
func _test_shortcuts() -> void:
	seed(RNG_SEED)
	var seeded_next := randi()
	seed(RNG_SEED)
	# Keys 1/2/0 open the existing modes and never commit anything themselves.
	var visit := _make()
	await _bind(visit)
	var source := visit.read_state()
	panel.upgrade_button.grab_focus()
	await _settle_layout()
	_check(panel.upgrade_button.has_focus() and panel._active(),
		"authentic open visit on a focused mounted panel precedes the shortcuts")
	await _key(KEY_1)
	_check(panel._mode == "upgrade" and not panel.option_buttons.is_empty()
		and panel.confirm_button.disabled and intents.is_empty()
		and visit.read_state() == source, "key 1 opens Upgrade only and never commits")
	await _key(KEY_2)
	_check(panel._mode == "stitch" and panel._first == -1
		and panel.confirm_button.disabled and intents.is_empty()
		and visit.read_state() == source, "key 2 opens Stitch only and never commits")
	await _key(KEY_0)
	_check(panel._mode == "leave" and not panel.confirm_button.disabled
		and intents.is_empty() and visit.read_state() == source,
		"key 0 opens Leave only and never commits")

	# Upgrade: 1 selects the mode, the existing row navigation picks the exact
	# duplicate, and 3 presses the same Confirm the mouse/Enter route uses.
	visit = _make()
	await _bind(visit)
	source = visit.read_state()
	panel.upgrade_button.grab_focus()
	await _settle_layout()
	await _key(KEY_1)
	_check(panel._mode == "upgrade" and panel.option_buttons.size() == 3
		and panel.confirm_button.disabled, "key 1 still requires an exact occurrence")
	var row := _row_at(1)
	if row == null:
		return
	await _activate(row, true)
	_check(panel.preview().index == 1 and not panel.confirm_button.disabled,
		"existing Tab/Enter row navigation still selects the real duplicate")
	await _key(KEY_3)
	_check(intents.size() == 1 and visit.read_state() == source,
		"key 3 confirms the chosen occurrence once without settling")
	if intents.size() != 1:
		return
	var upgrade_intent := intents[0]
	_check(upgrade_intent == {"action": "upgrade", "first_index": 1, "second_index": -1,
		"visit_id": source.visit_id, "node_id": source.node_id, "source_snapshot": source},
		"key 3 emits the same source-bound upgrade intent as mouse/Enter")
	_check(panel.take_confirmed(upgrade_intent) == upgrade_intent
		and panel.take_confirmed(upgrade_intent) == {},
		"key 3 mints the same one-shot Confirm hand-off as mouse/Enter")
	var upgrade := Controller.submit(visit, upgrade_intent)
	var oracle := RunRestCardUpgrade.new(source.deck, {STRIKE: "warden_strike_plus"}, {}, 1).choose_upgrade(1)
	_check(upgrade.ok and upgrade.action == "upgrade" and upgrade.transaction == oracle
		and upgrade.deck == [STRIKE, "warden_strike_plus", PRICK],
		"key 3 yields one authorized upgrade receipt")
	_check_receipt(upgrade, source, 0)
	_check_replay(visit, upgrade_intent)
	for key in [KEY_1, KEY_2, KEY_0, KEY_3]:
		await _key(key)
	_check(intents.size() == 1 and visit.is_consumed(),
		"no further key acts on the consumed visit")

	# Stitch: 2 opens the canonical FIRST list, the existing rows pick the ordered
	# different-owner pair, and 3 confirms exactly that pair for 3 scraps.
	visit = _make()
	await _bind(visit)
	source = visit.read_state()
	var pair := visit.stitch_preview(1, 2)
	_check(not pair.is_empty() and pair.energy_cost == 2 and pair.scrap_cost == 3,
		"independent payable ordered-pair prerequisite")
	panel.upgrade_button.grab_focus()
	await _settle_layout()
	await _key(KEY_2)
	_check(panel._mode == "stitch" and panel.option_buttons.size() == 3
		and panel.confirm_button.disabled, "key 2 opens the canonical FIRST list")
	var first_row := _row_at(1)
	if first_row == null:
		return
	await _activate(first_row, true)
	var second_row := _row_at(2)
	if second_row == null:
		return
	await _activate(second_row, true)
	_check(panel.preview() == pair and not panel.confirm_button.disabled,
		"existing rows still select the ordered different-owner pair")
	await _key(KEY_3)
	_check(intents.size() == 1 and visit.read_state() == source,
		"key 3 confirms the shown pair once without spending")
	if intents.size() != 1:
		return
	var stitch_intent := intents[0]
	_check(stitch_intent.action == "stitch" and stitch_intent.first_index == 1
		and stitch_intent.second_index == 2 and stitch_intent.source_snapshot == source,
		"key 3 emits the exact ordered source-bound stitch intent")
	var stitch := Controller.submit(visit, stitch_intent)
	_check(stitch.ok and stitch.transaction == pair.projection
		and stitch.deck == pair.resulting_deck and stitch.remaining_scraps == 4
		and stitch.charged_scraps == 3,
		"keyboard stitch pays 3 scraps for exactly the shown authenticated halves")
	_check_receipt(stitch, source, 3)
	_check_replay(visit, stitch_intent)

	# Leave: 0 stages it and 3 commits the free one-use visit.
	visit = _make()
	await _bind(visit)
	source = visit.read_state()
	panel.upgrade_button.grab_focus()
	await _settle_layout()
	await _key(KEY_0)
	_check(panel._mode == "leave" and not panel.confirm_button.disabled
		and intents.is_empty(), "key 0 stages free Leave")
	await _key(KEY_3)
	_check(intents.size() == 1 and visit.read_state() == source, "key 3 confirms Leave once")
	if intents.size() != 1:
		return
	var expected := source.duplicate(true)
	expected.consumed = true
	expected.merge({"ok": true, "action": "leave", "transaction": {}, "source_snapshot": source,
		"source_receipt": source.receipt, "charged_scraps": 0})
	var leave := Controller.submit(visit, intents[0])
	_check(leave == expected and leave.deck == source.deck
		and leave.remaining_scraps == source.remaining_scraps,
		"free one-use Leave keeps the deck and scraps unchanged")
	_check_replay(visit, intents[0])

	# 3 before a valid selection does nothing at all.
	visit = _make()
	await _bind(visit)
	source = visit.read_state()
	panel.upgrade_button.grab_focus()
	await _settle_layout()
	await _key(KEY_3)
	_check(intents.is_empty() and panel.confirm_button.disabled
		and visit.read_state() == source, "3 with no mode selected does nothing")
	await _key(KEY_1)
	await _key(KEY_3)
	_check(intents.is_empty() and panel.preview().is_empty()
		and panel.confirm_button.disabled and visit.read_state() == source,
		"3 before an upgrade row is selected does nothing")
	await _key(KEY_2)
	await _key(KEY_3)
	_check(intents.is_empty() and panel._first == -1 and panel._second == -1
		and panel.confirm_button.disabled and visit.read_state() == source,
		"3 before a Stitch pair is selected does nothing")

	# A disabled action keeps its disabled shortcut: 2 under 3 scraps, and 2 with
	# no different-owner pair, while the free decisions stay reachable.
	visit = _make([STRIKE, STRIKE, PRICK], 2)
	await _bind(visit)
	source = visit.read_state()
	_check(panel.stitch_button.disabled, "two scraps leave Stitch disabled")
	panel.upgrade_button.grab_focus()
	await _settle_layout()
	await _key(KEY_2)
	_check(panel._mode == "" and panel.option_buttons.is_empty() and intents.is_empty()
		and visit.read_state() == source, "an unaffordable Stitch ignores key 2")
	await _key(KEY_1)
	_check(panel._mode == "upgrade", "free Upgrade still opens under key 1")
	await _key(KEY_0)
	_check(panel._mode == "leave" and not panel.confirm_button.disabled,
		"free Leave still opens under key 0 beside the disabled Stitch")
	await _key(KEY_3)
	_check(intents.size() == 1 and Controller.submit(visit, intents[0]).get("ok") == true,
		"a disabled Stitch does not block the genuine Leave receipt")
	var no_pair := _make([STRIKE, STRIKE], 7)
	await _bind(no_pair)
	_check(panel.stitch_button.disabled, "no different-owner pair leaves Stitch disabled")
	await _key(KEY_2)
	_check(panel._mode == "" and intents.is_empty(),
		"no-pair Stitch ignores key 2")

	# Hidden panel, another panel's focus, releases, echo and modified keys are
	# all inert, and a real press still works afterwards.
	visit = _make()
	await _bind(visit)
	source = visit.read_state()
	panel.upgrade_button.grab_focus()
	await _settle_layout()
	panel.hide()
	await _settle_layout()
	await _key(KEY_1)
	_check(not panel.visible and panel._mode == "" and intents.is_empty()
		and visit.read_state() == source, "a hidden panel ignores its shortcuts")
	panel.show()
	await _settle_layout()
	var outside := Control.new()
	outside.focus_mode = Control.FOCUS_ALL
	root.add_child(outside)
	await _settle_layout()
	outside.grab_focus()
	await _settle_layout()
	_check(root.gui_get_focus_owner() == outside, "another panel genuinely owns GUI focus")
	for key in [KEY_1, KEY_2, KEY_0, KEY_3]:
		await _key(key)
	_check(panel._mode == "" and intents.is_empty() and visit.read_state() == source,
		"shortcuts never take keyboard input from another panel")
	outside.queue_free()
	await _settle_layout()
	panel.upgrade_button.grab_focus()
	await _settle_layout()
	_check(panel.upgrade_button.has_focus() and not panel.upgrade_button.disabled,
		"the panel is genuinely keyboard-live before the event guards")
	for key in [KEY_1, KEY_2, KEY_0, KEY_3]:
		await _key(key, false)
	_check(panel._mode == "" and intents.is_empty() and visit.read_state() == source,
		"key releases do nothing")
	await _key(KEY_1, true, true)
	_check(panel._mode == "" and intents.is_empty(), "auto-repeat echo does nothing")
	for modified in [{"ctrl": true}, {"alt": true}, {"shift": true}, {"meta": true}]:
		await _key(KEY_0, true, false, modified)
	_check(panel._mode == "" and intents.is_empty() and visit.read_state() == source,
		"modified keys do nothing")
	for key in [KEY_9, KEY_4, KEY_5, KEY_MINUS]:
		await _key(key)
	_check(panel._mode == "" and intents.is_empty() and visit.read_state() == source,
		"unmapped keys do nothing")
	await _key(KEY_1)
	_check(panel._mode == "upgrade" and not panel.option_buttons.is_empty(),
		"a real key press still works after the ignored events")

	# A rebind retires a staged shortcut selection, and the old payload cannot
	# settle the replacement visit.
	var pending := _make()
	await _bind(pending)
	var pending_source := pending.read_state()
	await _key(KEY_0)
	_check(panel._mode == "leave" and not panel.confirm_button.disabled,
		"a genuine staged Leave precedes the rebind")
	var rebound := _make()
	await _bind(rebound)
	var rebound_source := rebound.read_state()
	await _key(KEY_3)
	_check(intents.is_empty() and panel.confirm_button.disabled and panel.preview().is_empty()
		and rebound.read_state() == rebound_source, "rebind retires the staged Leave for key 3")
	var retired := {"action": "leave", "first_index": -1, "second_index": -1,
		"visit_id": pending_source.visit_id, "node_id": pending_source.node_id,
		"source_snapshot": pending_source}
	_check(Controller.submit(rebound, retired) == {"ok": false}
		and rebound.read_state() == rebound_source,
		"the rebound visit rejects the retired shortcut payload")
	_check(randi() == seeded_next, "keyboard routes consume no global RNG")
	seed(RNG_SEED)


func _test_rejections() -> void:
	for fixture in [[0, [STRIKE, PRICK]], [2, [STRIKE, PRICK]], [7, [STRIKE, STRIKE]]]:
		var visit := _make(fixture[1], fixture[0])
		await _bind(visit)
		var source := visit.read_state()
		_check(panel.stitch_button.disabled and not panel.upgrade_button.disabled and not panel.leave_button.disabled, "poor/no-pair keeps free decisions")
		_check(panel.option_buttons.is_empty() and panel.preview().is_empty()
			and panel.preview_label.text == "Choose Upgrade, Stitch or Leave, then confirm."
			and panel.confirm_button.disabled, "unavailable Stitch has a neutral unselected preview")
		_check(panel.status_label.text.contains("Insufficient") if fixture[0] < 3 else panel.status_label.text.contains("No different-owner"), "reason visibly explained")
		panel.stitch_button.pressed.emit()
		panel.confirm_button.pressed.emit()
		_check(intents.is_empty() and visit.read_state() == source, "disabled/forged activation no mutation")
		var bad := {"action": "stitch", "first_index": 0, "second_index": 1, "visit_id": source.visit_id, "node_id": source.node_id, "source_snapshot": source}
		_check(Controller.submit(visit, bad) == {"ok": false} and visit.read_state() == source, "poor/no-pair exact rejection receipt")
	var visit := _make()
	await _bind(visit)
	var source := visit.read_state()
	await _activate(panel.upgrade_button, false)
	var prior_row: Button = panel.option_buttons[1]
	var retired_row: Callable = prior_row.pressed.get_connections()[0].callable
	await _activate(panel.stitch_button, false)
	var stage_rows: int = panel._rows_epoch
	retired_row.call()
	_check(not is_instance_valid(prior_row) or (prior_row.get_parent() == null
		and prior_row.is_queued_for_deletion()), "retired Help is detached from active scroll and focus")
	_check(panel._rows_epoch == stage_rows and panel._first == -1 and panel.preview().is_empty()
		and panel.confirm_button.disabled and visit.read_state() == source,
		"mode switch retires old occurrence callback without substituting a legal stitch index")
	await _activate(panel.option_buttons[0], false)
	var retired_partner: Callable = panel.option_buttons[0].pressed.get_connections()[0].callable
	await _activate(panel.stitch_button, false)
	retired_partner.call()
	_check(panel._first == -1 and panel._second == -1 and panel.confirm_button.disabled,
		"restarting Stitch retires old first-stage callbacks")
	var hidden_options := panel.option_buttons.size()
	panel.hide()
	var hidden_mode: Callable = panel.upgrade_button.pressed.get_connections()[0].callable
	hidden_mode.call()
	_check(not panel.visible and panel._mode == "stitch" and panel.option_buttons.size() == hidden_options
		and panel.confirm_button.disabled, "hidden controls cannot recreate or authorize options")
	panel.show()
	await _activate(panel.upgrade_button, false)
	var stale_select: Callable = panel.option_buttons[1].pressed.get_connections()[0].callable
	panel._select(99, panel._epoch)
	_check(panel.confirm_button.disabled and panel.preview().is_empty() and visit.read_state() == source, "bad occurrence cannot confirm or spend")
	await _activate(panel.option_buttons[1], false)
	var stale_confirm: Callable = panel.confirm_button.pressed.get_connections()[0].callable
	await _activate(panel.confirm_button, false)
	_check(intents.size() == 1, "captured genuine pending intent")
	if intents.is_empty():
		return
	var old := intents[0].duplicate(true)
	var replacement := _make()
	await _bind(replacement)
	var replacement_source := replacement.read_state()
	stale_select.call()
	stale_confirm.call()
	_check(intents.is_empty() and panel.preview().is_empty() and panel.confirm_button.disabled, "rebind retires callbacks and selection")
	_check(Controller.submit(replacement, old) == {"ok": false} and replacement.read_state() == replacement_source and visit.read_state() == source, "rebound intent rejects with both ledgers unchanged")
	for indices in [[-1, 2], [0, 0], [0, 1], [99, 2]]:
		var bad := old.duplicate(true)
		bad.action = "stitch"
		bad.first_index = indices[0]
		bad.second_index = indices[1]
		_check(Controller.submit(visit, bad) == {"ok": false} and visit.read_state() == source, "bad/same-owner selection exact rejection")
	var forged := old.duplicate(true)
	forged.source_snapshot.remaining_scraps += 1
	_check(Controller.submit(visit, forged) == {"ok": false} and visit.read_state() == source, "tampered source no-spend")
	panel.close()
	stale_select.call()
	stale_confirm.call()
	_check(not panel.visible and panel.preview().is_empty() and intents.is_empty()
		and replacement.read_state() == replacement_source, "close retires callbacks without mutation")
	await _bind(replacement)
	await _activate(panel.leave_button, true)
	var pending_confirm: Callable = panel.confirm_button.pressed.get_connections()[0].callable
	var external := replacement.leave(replacement_source.visit_id, replacement_source.node_id, replacement_source)
	_check(external.ok, "genuine external settlement prerequisite")
	var settled := replacement.read_state()
	pending_confirm.call()
	_check(intents.is_empty() and replacement.read_state() == settled and panel.confirm_button.disabled
		and panel.option_buttons.is_empty() and panel.preview().is_empty()
		and panel.preview_label.text == "Choose Upgrade, Stitch or Leave, then confirm.",
		"consumed authority retires stale preview and disables confirmation without spend")
	var invalid := RunSewingCircleVisit.new("circle-invalid", ["not_a_card"], {}, 3, 1)
	_check(not invalid.is_valid(), "malformed visit cannot produce genuine options")
	panel.bind(invalid)
	await _settle_layout()
	_check(panel.option_buttons.is_empty() and panel.preview().is_empty()
		and panel.confirm_button.disabled and panel.upgrade_button.disabled
		and panel.stitch_button.disabled and panel.leave_button.disabled
		and panel.preview_label.text == "Choose Upgrade, Stitch or Leave, then confirm.",
		"invalid source binding retires all active choice Help and Confirm")


## Measured against the shipped font: a printed shortcut must fit the sewn
## button it names, at the same 18px size the screen uses.
func _fits(button: Button) -> bool:
	var font := button.get_theme_font("font")
	if font == null or button.text.is_empty():
		return false
	var font_size := button.get_theme_font_size("font_size")
	if font_size < 18:
		return false
	var width := font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return width <= button.size.x - 16.0 and button.size.y >= font.get_height(font_size) * 1.4


## Inspect visible label nodes, not the Button's retained accessibility text.
func _card_ink(button: Button) -> String:
	var lines: PackedStringArray = []
	for node in button.find_children("*", "Label", true, false):
		lines.append((node as Label).text)
	return "\n".join(lines)


func _assert_decorations(button: Button) -> void:
	_check(button.focus_mode == Control.FOCUS_ALL and button.mouse_filter == Control.MOUSE_FILTER_STOP,
		"canonical option Button alone owns click and keyboard focus")
	var children := button.find_children("*", "Control", true, false)
	_check(children.size() >= 5, "real sewn labels, seam and cost coin exist")
	for child in children:
		var control: Control = child
		_check(control.mouse_filter == Control.MOUSE_FILTER_IGNORE and control.focus_mode == Control.FOCUS_NONE,
			"every decorative descendant ignores pointer and cannot take focus")
		_check(Rect2(Vector2.ZERO, button.size).has_point(control.position) or control.get_parent() != button,
			"each top-level ink decoration starts within its canonical card")
