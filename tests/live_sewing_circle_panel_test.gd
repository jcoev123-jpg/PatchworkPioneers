extends SceneTree

const STRIKE := "warden_strike"
const PRICK := "seamstress_prick"
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
	seed(264)
	var seeded_next := randi()
	seed(264)
	await _test_layout()
	for keyboard in [false, true]:
		await _test_upgrade(keyboard)
		await _test_stitch(keyboard)
		await _test_leave(keyboard)
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
	for i in range(mini(4, panel.option_buttons.size())):
		_check(viewport.encloses(panel.option_buttons[i].get_global_rect()), "occurrence option fits viewport")
	_check(panel.choice_scroll.get_v_scroll_bar().max_value > panel.choice_scroll.size.y, "long deck contained in scroll")
	panel.option_buttons.back().grab_focus()
	await _settle_layout()
	_check(panel.choice_scroll.scroll_vertical > 0, "keyboard focus reveals offscreen copy")
	_check(visit.read_state() == source and intents.is_empty(), "browse does not change any ledger")


func _test_upgrade(keyboard: bool) -> void:
	var visit := _make()
	await _bind(visit)
	var source := visit.read_state()
	await _activate(panel.upgrade_button, keyboard)
	_check(panel.option_buttons.size() == 3 and panel.confirm_button.disabled, "upgrade needs explicit occurrence")
	await _activate(panel.option_buttons[1], keyboard)
	_check(panel.preview().index == 1 and panel.preview().effects == {"damage": 6}
		and panel.preview().plus_effects == {"damage": 7}, "genuine upgrade preview for second duplicate")
	_check(panel.preview_label.text.contains("damage 6") and panel.preview_label.text.contains("damage 7"), "visible before/after effects")
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
	_check(not expected.is_empty(), "authentic cross-owner preview prerequisite")
	await _activate(panel.stitch_button, keyboard)
	_check(panel.option_buttons.size() == 3, "canonical first copies including duplicates")
	for i in range(panel.option_buttons.size()):
		_check(panel.option_buttons[i].get_meta("option") == visit.stitch_first_options()[i], "exact canonical stitch first occurrence metadata")
	await _activate(panel.option_buttons[1], keyboard)
	_check(panel.option_buttons.size() == 1 and panel.option_buttons[0].get_meta("option").index == 2, "second stage only different-owner occurrence")
	_check(panel.option_buttons[0].get_meta("option") == visit.stitch_second_options(1)[0], "exact canonical stitch partner metadata")
	await _activate(panel.option_buttons[0], keyboard)
	_check(panel.preview() == expected and panel.preview_label.text.contains("Scraps: 7 -> 4"), "exact detached genuine stitch forecast")
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


func _test_rejections() -> void:
	for fixture in [[2, [STRIKE, PRICK]], [7, [STRIKE, STRIKE]]]:
		var visit := _make(fixture[1], fixture[0])
		await _bind(visit)
		var source := visit.read_state()
		_check(panel.stitch_button.disabled and not panel.upgrade_button.disabled and not panel.leave_button.disabled, "poor/no-pair keeps free decisions")
		_check(panel.status_label.text.contains("Insufficient") if fixture[0] == 2 else panel.status_label.text.contains("No different-owner"), "reason visibly explained")
		panel.stitch_button.pressed.emit()
		panel.confirm_button.pressed.emit()
		_check(intents.is_empty() and visit.read_state() == source, "disabled/forged activation no mutation")
		var bad := {"action": "stitch", "first_index": 0, "second_index": 1, "visit_id": source.visit_id, "node_id": source.node_id, "source_snapshot": source}
		_check(Controller.submit(visit, bad) == {"ok": false} and visit.read_state() == source, "poor/no-pair exact rejection receipt")
	var visit := _make()
	await _bind(visit)
	var source := visit.read_state()
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
	_check(intents.is_empty() and replacement.read_state() == settled, "authority drift rejects pending UI confirmation without spend")
