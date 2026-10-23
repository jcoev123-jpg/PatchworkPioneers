extends SceneTree
## Mounted, deterministic M04 Event panel contract. No live app wiring or effects.
const PANEL_SCENE := "res://scenes/event_choice_panel.tscn"
const EVENTS_PATH := "res://data/events/m04_events.json"
const REQUIRED := {
	"button_trail": "The Button Trail",
	"loose_seam": "The Loose Seam",
	"thimble_well": "The Thimble Well",
	"frayed_signpost": "The Frayed Signpost",
	"quiet_spool": "The Quiet Spool",
	"needle_gate": "The Needle Gate",
	"quilting_bee": "The Quilting Bee",
}

var panel: LiveEventChoicePanel
var failures: Array[String] = []
var checks: int = 0
var committed: Array[Dictionary] = []
var authored: Dictionary = {}
var wallet_committed: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _frames() -> void:
	for i in range(4):
		await process_frame


func _key(key: Key) -> void:
	for state in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = state
		root.push_input(event, true)
	await _frames()


func _mouse_motion(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	await _frames()


func _mouse(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for state in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = state
		root.push_input(event, true)
	await _frames()


func _on_choice_committed(event_id: String, choice_id: String) -> void:
	committed.append({"event_id": event_id, "choice_id": choice_id})


func _on_wallet_choice_committed(result: Dictionary) -> void:
	wallet_committed.append(result.duplicate(true))


func _wallet_record(path: String, event_id: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, event_id + " genuine JSON opens")
	if file == null:
		return {}
	var parser := JSON.new()
	var error := parser.parse(file.get_as_text())
	file.close()
	_check(error == OK, event_id + " genuine JSON parses")
	if error != OK:
		return {}
	var value: Variant = parser.data
	_check(value is Dictionary and value.get("id") == event_id, event_id + " exact authored ID")
	if not value is Dictionary:
		return {}
	return value


## Independent oracle for the third ticket line, from the exact caller wallet
## and the service row's own deltas (never from the panel's helper).
func _expected_forecast(row: Dictionary, wallet: Dictionary) -> String:
	if row["affordable"]:
		var after: Dictionary = row["wallet"]
		return "After: %d gold | %d scraps" % [after["gold"], after["scraps"]]
	return "   •   ".join(_expected_needs(row, wallet))


func _expected_needs(row: Dictionary, wallet: Dictionary) -> Array[String]:
	var needs: Array[String] = []
	var missing_gold: int = -(int(wallet["gold"]) + int(row["gold_delta"])) if typeof(row["gold_delta"]) == TYPE_INT else 0
	var missing_scraps: int = -(int(wallet["scraps"]) + int(row["scraps_delta"])) if typeof(row["scraps_delta"]) == TYPE_INT else 0
	if missing_gold > 0:
		needs.append("Need %d gold" % missing_gold)
	if missing_scraps > 0:
		needs.append("Need %d scraps" % missing_scraps)
	return needs


func _wallet_index(record: Dictionary, choice_id: String) -> int:
	var choices: Array = record.get("choices", [])
	for i in range(choices.size()):
		if choices[i] is Dictionary and choices[i].get("id") == choice_id:
			return i
	return -1


func _check_wallet_layout(record: Dictionary, wallet: Dictionary, label: String) -> void:
	_check(panel.has_open_event() and panel.is_visible_in_tree(), label + " mounted visible event")
	_check(panel.title_label.text == record["title"] and panel.description_label.text == record["description"],
		label + " authored title and description visible")
	var balance := panel.choices_container.get_parent().get_node_or_null("WalletBalance") as Label
	_check(balance != null, label + " visible balance label")
	if balance != null:
		_check(balance.is_visible_in_tree() and balance.text == "Wallet  •  %d gold   /   %d scraps" % [wallet["gold"], wallet["scraps"]],
			label + " current exact gold and scraps")
	var preview := RunEventChoice.new(record).preview_wallet_choices(wallet)
	_check(preview.get("ok", false) == true, label + " valid RunEventChoice preview")
	var buttons := panel.get_choice_buttons()
	var choices: Array = record["choices"]
	var rows: Array = preview.get("choices", [])
	_check(buttons.size() == choices.size() and rows.size() == choices.size(),
		label + " authentic offered choice count")
	if buttons.size() != choices.size() or rows.size() != choices.size():
		return
	var viewport := Rect2(Vector2.ZERO, Vector2(root.size))
	_check(viewport.encloses(panel.paper_panel.get_global_rect()), label + " paper card within 1280x720")
	for i in range(buttons.size()):
		var button: Button = buttons[i]
		var row: Dictionary = rows[i]
		var expected := "%s\nGold %s   |   Scraps %s\n%s" % [
			choices[i]["text"], panel._delta_label(row["gold_delta"]), panel._delta_label(row["scraps_delta"]),
			_expected_forecast(row, wallet)]
		_check(button.text == expected, label + " authored text, signed deltas and exact service forecast " + str(i))
		var lines := button.text.split("\n")
		_check(lines.size() == 3, label + " ticket carries name, deltas and forecast lines " + str(i))
		if row["affordable"]:
			var after: Dictionary = row["wallet"]
			_check(lines[2] == "After: %d gold | %d scraps" % [after["gold"], after["scraps"]],
				label + " affordable choice shows exact after totals " + str(i))
		else:
			var needs := _expected_needs(row, wallet)
			_check(not needs.is_empty(), label + " unaffordable choice really lacks a resource " + str(i))
			_check(lines[2] == "   •   ".join(needs),
				label + " unaffordable choice names exactly the missing resource " + str(i))
			_check(not lines[2].contains("After:"), label + " unaffordable choice shows no after totals " + str(i))
		_check(button.disabled == not row["affordable"] and
			button.focus_mode == (Control.FOCUS_ALL if row["affordable"] else Control.FOCUS_NONE),
			label + " affordability disables and skips focus for unavailable choice " + str(i))
		_check(button.get_parent() == panel.choices_container and button.is_visible_in_tree(),
			label + " actual mounted choice button " + str(i))
		_check(viewport.encloses(button.get_global_rect()), label + " full choice onscreen " + str(i))
		_check(button.get_theme_stylebox("normal") is StyleBoxFlat and
			button.get_theme_stylebox("disabled") is StyleBoxFlat and
			button.get_theme_stylebox("focus") is StyleBoxFlat,
			label + " paper/cardboard/focus styling intact " + str(i))


func _wallet_success(record: Dictionary, wallet: Dictionary, choice_id: String,
		expected_wallet: Dictionary, mouse_activation: bool = false) -> void:
	var label := str(record.get("id", "")) + "/" + choice_id + " @ " + str(wallet)
	var original_record := record.duplicate(true)
	var original_wallet := wallet.duplicate(true)
	wallet_committed.clear()
	committed.clear()
	_check(panel.open_event_with_wallet(record, wallet), label + " opens fresh wallet panel")
	if not panel.has_open_event():
		return
	await _frames()
	_check_wallet_layout(original_record, original_wallet, label)
	var index := _wallet_index(original_record, choice_id)
	_check(index >= 0 and index < panel.get_choice_buttons().size(), label + " desired choice is offered")
	if index < 0 or index >= panel.get_choice_buttons().size():
		panel.close_event()
		await _frames()
		return
	var button: Button = panel.get_choice_buttons()[index]
	_check(not button.disabled, label + " target really affordable and enabled")
	# Mutation after mounting cannot influence the detached, authoritative
	# transaction, even when the same caller Dictionary is reused elsewhere.
	wallet["gold"] = 777
	wallet["scraps"] = 777
	record["title"] = "forged title"
	record["choices"][index]["outcome"]["gold"] = 999
	if mouse_activation:
		await _mouse(button)
	else:
		button.pressed.emit()
	_check(wallet_committed.size() == 1, label + " emits exactly one wallet receipt")
	var expected := {"ok": true, "event_id": original_record["id"],
		"choice_id": choice_id, "wallet": expected_wallet}
	if wallet_committed.size() == 1:
		_check(wallet_committed[0] == expected, label + " exact ID-specific settled wallet")
		(wallet_committed[0]["wallet"] as Dictionary)["gold"] = -999
		_check(panel._committed_choice == expected, label + " emitted result detached from panel receipt")
	_check(committed.is_empty(), label + " never emits legacy choice_committed in wallet mode")
	_check(panel._selector.is_claimed(), label + " selector claimed exactly once")
	for current in panel.get_choice_buttons():
		_check(current.disabled, label + " all choices disabled after claim")
		current.pressed.emit()
	_check(wallet_committed.size() == 1, label + " duplicate input cannot settle twice")
	_check(wallet == {"gold": 777, "scraps": 777} and record["title"] == "forged title",
		label + " panel selection never mutates caller wallet or event")
	panel.close_event()
	await _frames()
	_check(panel.choices_container.get_parent().get_node_or_null("WalletBalance") == null,
		label + " close removes balance caption")


func _wallet_denied_then_recover(record: Dictionary, wallet: Dictionary, denied_id: String,
		recovery_id: String, expected_wallet: Dictionary) -> void:
	var label := str(record.get("id", "")) + "/" + denied_id + " insufficient"
	var snapshot := wallet.duplicate(true)
	wallet_committed.clear()
	committed.clear()
	seed(913417)
	var expected_rng := randi()
	seed(913417)
	_check(panel.open_event_with_wallet(record, wallet), label + " event opens for refused choice")
	if not panel.has_open_event():
		return
	await _frames()
	_check_wallet_layout(record, wallet, label)
	var rows: Array = RunEventChoice.new(record).preview_wallet_choices(wallet).get("choices", [])
	_check(rows.size() == (record["choices"] as Array).size(), label + " oracle preview rows available")
	var denied_index := _wallet_index(record, denied_id)
	var recovery_index := _wallet_index(record, recovery_id)
	var buttons := panel.get_choice_buttons()
	if rows.size() != buttons.size():
		panel.close_event()
		await _frames()
		return
	_check(denied_index >= 0 and recovery_index >= 0, label + " both choices actually present")
	if denied_index < 0 or recovery_index < 0:
		panel.close_event()
		await _frames()
		return
	var disabled: Button = buttons[denied_index]
	var recovery: Button = buttons[recovery_index]
	_check(disabled.disabled and disabled.focus_mode == Control.FOCUS_NONE, label + " inaccessible and unfocusable")
	_check(not recovery.disabled and recovery.focus_mode == Control.FOCUS_ALL, label + " recovery option available")
	# Exact shortfall, derived independently from the wallet and service deltas.
	var denied_row: Dictionary = rows[denied_index]
	var needs := _expected_needs(denied_row, snapshot)
	_check(not needs.is_empty(), label + " denied choice really is missing a resource")
	for need in needs:
		_check(disabled.text.contains(need), label + " denied ticket states exact " + need)
	_check(not disabled.text.contains("After:"), label + " denied ticket shows no after totals")
	var recovery_row: Dictionary = rows[recovery_index]
	_check(recovery.text.contains("After: %d gold | %d scraps" % [
		expected_wallet["gold"], expected_wallet["scraps"]]),
		label + " recovery ticket shows exact service after totals")
	# Hovering a ticket alone must not settle, mutate or consume RNG.
	await _mouse_motion(recovery)
	await _mouse_motion(disabled)
	_check(wallet_committed.is_empty() and committed.is_empty(), label + " hover alone commits nothing")
	_check(wallet == snapshot, label + " hover leaves caller wallet unchanged")
	disabled.pressed.emit()
	panel._on_choice_pressed(panel._selector, denied_id, panel._generation, disabled)
	panel._on_choice_pressed(panel._selector, "unoffered", panel._generation, recovery)
	panel._on_choice_pressed(panel._selector, denied_id, panel._generation, recovery)
	_check(wallet_committed.is_empty() and committed.is_empty() and panel._selector.is_valid(),
		label + " forced unaffordable/unoffered/mismatched activation fails before claim")
	_check(wallet == snapshot, label + " refused action leaves caller wallet unchanged")
	_check(randi() == expected_rng, label + " refusal, preview and opening use zero RNG")
	recovery.pressed.emit()
	_check(wallet_committed.size() == 1 and wallet_committed[0] == {
		"ok": true, "event_id": record["id"], "choice_id": recovery_id, "wallet": expected_wallet},
		label + " same selector recovers and settles exactly once")
	panel.close_event()
	await _frames()


func _test_wallet_authored() -> void:
	var estate := _wallet_record("res://data/events/estate_sale.json", "estate_sale")
	var needle := _wallet_record("res://data/events/needle_gate.json", "needle_gate")
	var exchange := _wallet_record("res://data/events/thimble_exchange.json", "thimble_exchange")
	var bee: Dictionary = authored.get("quilting_bee", {})
	for record in [estate, needle, exchange, bee]:
		_check(not record.is_empty() and RunEventChoice.new(record).is_valid(),
			"wallet fixture is a genuine valid authored event " + str(record.get("id", "")))
	if estate.is_empty() or needle.is_empty() or exchange.is_empty() or bee.is_empty():
		return
	await _wallet_success(estate.duplicate(true), {"gold": 20, "scraps": 0}, "buy_thread",
		{"gold": 5, "scraps": 2}, true)
	await _wallet_denied_then_recover(estate, {"gold": 14, "scraps": 0}, "buy_thread", "leave",
		{"gold": 14, "scraps": 0})
	await _wallet_success(needle.duplicate(true), {"gold": 0, "scraps": 2}, "cut_bindings",
		{"gold": 28, "scraps": 0})
	await _wallet_denied_then_recover(needle, {"gold": 0, "scraps": 1}, "cut_bindings", "pass",
		{"gold": 0, "scraps": 1})
	await _wallet_success(exchange.duplicate(true), {"gold": 0, "scraps": 0}, "gather_thread",
		{"gold": 0, "scraps": 2})
	await _wallet_denied_then_recover(exchange, {"gold": 0, "scraps": 0}, "trade_scrap", "gather_thread",
		{"gold": 0, "scraps": 2})
	await _wallet_success(exchange.duplicate(true), {"gold": 0, "scraps": 1}, "trade_scrap",
		{"gold": 10, "scraps": 0})
	await _wallet_success(bee.duplicate(true), {"gold": 0, "scraps": 2}, "sew_panel",
		{"gold": 32, "scraps": 0})
	await _wallet_success(bee.duplicate(true), {"gold": 15, "scraps": 0}, "buy_thread",
		{"gold": 0, "scraps": 2})


## Reopening the same authored record with a different wallet must refresh every
## ticket's forecast line to that wallet's exact service projection.
func _test_wallet_reopen_refresh() -> void:
	var bee: Dictionary = authored.get("quilting_bee", {})
	var estate := _wallet_record("res://data/events/estate_sale.json", "estate_sale")
	_check(not bee.is_empty() and not estate.is_empty(), "reopen refresh fixtures are authored events")
	if bee.is_empty() or estate.is_empty():
		return
	var wallets: Array = [{"gold": 0, "scraps": 2}, {"gold": 15, "scraps": 0}, {"gold": 0, "scraps": 0}]
	var snapshots: Array = []
	for wallet in wallets:
		_check(panel.open_event_with_wallet(bee, wallet),
			"quilting bee opens at " + str(wallet))
		if not panel.has_open_event():
			return
		await _frames()
		_check_wallet_layout(bee, wallet, "reopen bee @ " + str(wallet))
		var texts: Array[String] = []
		for button in panel.get_choice_buttons():
			texts.append(button.text)
		snapshots.append(texts)
		panel.close_event()
		await _frames()
	_check(snapshots.size() == 3, "three quilting bee wallet snapshots captured")
	if snapshots.size() == 3:
		_check(snapshots[0] != snapshots[1] and snapshots[1] != snapshots[2]
			and snapshots[0] != snapshots[2],
			"different wallets refresh every ticket for the same authored event")
		_check((snapshots[0] as Array)[0].ends_with("After: 32 gold | 0 scraps"),
			"2 scraps wallet previews sew_panel after totals")
		_check((snapshots[1] as Array)[0].ends_with("Need 2 scraps"),
			"15 gold wallet ticket names the missing scraps for sew_panel")
		_check((snapshots[1] as Array)[1].ends_with("After: 0 gold | 2 scraps"),
			"15 gold wallet previews buy_thread after totals")
		_check((snapshots[2] as Array)[1].ends_with("Need 15 gold"),
			"0 gold wallet ticket names the missing gold for buy_thread")
	# Estate Sale at a contrasting wallet must reuse the same authoritative path.
	_check(panel.open_event_with_wallet(estate, {"gold": 20, "scraps": 0}),
		"estate sale reopens at 20 gold")
	await _frames()
	_check_wallet_layout(estate, {"gold": 20, "scraps": 0}, "reopen estate @ 20 gold")
	var estate_buttons := panel.get_choice_buttons()
	var buy_index := _wallet_index(estate, "buy_thread")
	var sell_index := _wallet_index(estate, "sell_fabric")
	var leave_index := _wallet_index(estate, "leave")
	if buy_index >= 0 and sell_index >= 0 and leave_index >= 0:
		_check(estate_buttons[buy_index].text.ends_with("After: 5 gold | 2 scraps"),
			"estate buy_thread shows exact after totals")
		_check(estate_buttons[sell_index].text.ends_with("Need 2 scraps")
			and estate_buttons[sell_index].disabled
			and estate_buttons[sell_index].focus_mode == Control.FOCUS_NONE,
			"estate sell_fabric names missing scraps and cannot be selected")
		_check(estate_buttons[leave_index].text.ends_with("After: 20 gold | 0 scraps"),
			"estate leave shows unchanged exact after totals")
	else:
		_check(false, "estate sale choice IDs offered for reopen refresh")
	panel.close_event()
	await _frames()


func _test_wallet_keyboard() -> void:
	var exchange := _wallet_record("res://data/events/thimble_exchange.json", "thimble_exchange")
	if exchange.is_empty():
		return
	wallet_committed.clear()
	_check(panel.open_event_with_wallet(exchange, {"gold": 0, "scraps": 1}),
		"wallet keyboard exchange opens with two affordable choices")
	await _frames()
	var buttons := panel.get_choice_buttons()
	_check(buttons.size() == 2 and not buttons[0].disabled and not buttons[1].disabled,
		"wallet keyboard has two real affordable buttons")
	if buttons.size() == 2:
		buttons[0].grab_focus()
		await _frames()
		_check(buttons[0].has_focus(), "wallet keyboard first choice focused")
		await _key(KEY_TAB)
		_check(buttons[1].has_focus(), "wallet keyboard Tab reaches next affordable button")
		await _key(KEY_SPACE)
		_check(wallet_committed.size() == 1 and wallet_committed[0] == {
			"ok": true, "event_id": "thimble_exchange", "choice_id": "trade_scrap",
			"wallet": {"gold": 10, "scraps": 0}},
			"wallet keyboard Space commits the actual focused choice once")
	panel.close_event()
	await _frames()
	var estate := _wallet_record("res://data/events/estate_sale.json", "estate_sale")
	if estate.is_empty():
		return
	wallet_committed.clear()
	_check(panel.open_event_with_wallet(estate, {"gold": 14, "scraps": 0}),
		"wallet keyboard unaffordable estate opens")
	await _frames()
	var leave_index := _wallet_index(estate, "leave")
	var buy_index := _wallet_index(estate, "buy_thread")
	var estate_buttons := panel.get_choice_buttons()
	if leave_index < 0 or buy_index < 0:
		_check(false, "wallet keyboard estate choice IDs offered")
		panel.close_event()
		return
	_check(estate_buttons[buy_index].focus_mode == Control.FOCUS_NONE and
		estate_buttons[buy_index].disabled, "wallet keyboard unaffordable choice cannot receive focus")
	estate_buttons[leave_index].grab_focus()
	await _frames()
	_check(estate_buttons[leave_index].has_focus(), "wallet keyboard affordable Leave focused")
	await _key(KEY_ENTER)
	_check(wallet_committed.size() == 1 and wallet_committed[0] == {
		"ok": true, "event_id": "estate_sale", "choice_id": "leave",
		"wallet": {"gold": 14, "scraps": 0}},
		"wallet keyboard Enter settles affordable option at insufficient gold")
	panel.close_event()
	await _frames()


func _test_wallet_rejection_and_generation() -> void:
	var record: Dictionary = authored.get("quilting_bee", {})
	if record.is_empty():
		_check(false, "quilting bee available for wallet negative tests")
		return
	for invalid in [
		null, {"gold": 3}, {"gold": 3, "scraps": 0, "extra": 1},
		{"gold": -1, "scraps": 0}, {"gold": 1.0, "scraps": 0},
		{"gold": 1, "scraps": "0"}, {"gold": 1, "scraps": -1},
	]:
		var original: Variant = invalid.duplicate(true) if invalid is Dictionary else invalid
		_check(not panel.open_event_with_wallet(record, invalid),
			"invalid wallet rejected before opening: " + str(invalid))
		_check(not panel.has_open_event() and panel.get_choice_buttons().is_empty(),
			"invalid wallet never mounts choice: " + str(invalid))
		_check(invalid == original, "invalid wallet never mutated: " + str(invalid))
	var malformed := record.duplicate(true)
	var idx := _wallet_index(malformed, "sew_panel")
	malformed["choices"][idx]["outcome"]["gold"] = "not coins"
	wallet_committed.clear()
	_check(panel.open_event_with_wallet(malformed, {"gold": 0, "scraps": 2}),
		"malformed authored outcome visible but disabled")
	await _frames()
	var bad: Button = panel.get_choice_buttons()[idx]
	_check(bad.disabled and bad.text.contains("UNAVAILABLE") and bad.text.contains("Gold —"),
		"malformed outcome never appears affordable")
	_check(bad.focus_mode == Control.FOCUS_NONE, "malformed outcome is unfocusable")
	bad.pressed.emit()
	_check(wallet_committed.is_empty() and panel._selector.is_valid(),
		"malformed outcome cannot spend visit")
	panel.get_choice_buttons()[_wallet_index(record, "watch")].pressed.emit()
	_check(wallet_committed.size() == 1 and wallet_committed[0]["choice_id"] == "watch",
		"valid alternative after malformed outcome settles")
	panel.close_event()
	await _frames()
	var wallet := {"gold": 15, "scraps": 0}
	var rng := RandomNumberGenerator.new()
	rng.seed = 918273
	var state := rng.state
	seed(918273)
	var next_global := randi()
	seed(918273)
	wallet_committed.clear()
	_check(panel.open_event_with_wallet(record, wallet), "stale test first wallet offer opens")
	await _frames()
	var old_selector := panel._selector
	var old_gen := panel._generation
	var old_buttons := panel.get_choice_buttons()
	var old_callable: Callable = old_buttons[1].pressed.get_connections()[0]["callable"]
	_check(not panel.open_event_with_wallet(record, wallet), "active offer cannot be overwritten")
	panel._on_choice_pressed(RunEventChoice.new(record), "buy_thread", old_gen, old_buttons[1])
	var outsider := Button.new()
	panel.choices_container.add_child(outsider)
	panel._on_choice_pressed(old_selector, "buy_thread", old_gen, outsider)
	outsider.queue_free()
	_check(wallet_committed.is_empty() and old_selector.is_valid(), "foreign selectors/buttons cannot claim")
	panel.close_event()
	_check(panel.open_event_with_wallet(record, {"gold": 0, "scraps": 2}),
		"new wallet selector opens after close")
	var new_selector := panel._selector
	if is_instance_valid(old_buttons[1]):
		old_callable.call()
		panel._on_choice_pressed(old_selector, "buy_thread", old_gen, old_buttons[1])
	_check(wallet_committed.is_empty() and new_selector.is_valid(),
		"stale callback cannot operate reopened wallet offering")
	await _frames()
	panel.get_choice_buttons()[_wallet_index(record, "sew_panel")].pressed.emit()
	_check(wallet_committed.size() == 1 and wallet_committed[0] == {
		"ok": true, "event_id": "quilting_bee", "choice_id": "sew_panel",
		"wallet": {"gold": 32, "scraps": 0}},
		"reopened selector settles fresh original balance once")
	_check(wallet == {"gold": 15, "scraps": 0},
		"wallet supplied to closed selector untouched by later offer")
	_check(rng.state == state and randi() == next_global,
		"rejected and accepted wallet UI operations consume no RNG")
	panel.close_event()
	await _frames()


func _fixture_three() -> Dictionary:
	return {
		"id": "three_choice_fixture",
		"title": "Three Way Crossroads",
		"description": "A very long stitched description that must remain intact, even when a third choice appears underneath the patchwork paper scene.",
		"choices": [
			{"id": "left", "text": "Take the long, quiet left trail"},
			{"id": "right", "text": "Take the steep right trail"},
			{"id": "wait", "text": "Wait on the soft grass"},
		],
	}


func _read_authored() -> void:
	var file := FileAccess.open(EVENTS_PATH, FileAccess.READ)
	_check(file != null, "authored catalog opens")
	if file == null:
		return
	var parser := JSON.new()
	var err := parser.parse(file.get_as_text())
	file.close()
	_check(err == OK, "authored catalog parses")
	if err != OK:
		return
	_check(parser.data is Dictionary, "authored catalog object")
	if not parser.data is Dictionary:
		return
	var events: Variant = parser.data.get("events")
	_check(events is Array, "authored events array")
	if not events is Array:
		return
	for id in REQUIRED:
		var matches := (events as Array).filter(func(record) -> bool:
			return record is Dictionary and record.get("id") == id)
		_check(matches.size() == 1, "exactly one authored ID " + id)
		if matches.size() == 1:
			authored[id] = matches[0]
			_check(matches[0].get("title") == REQUIRED[id], "required title unchanged: " + id)
			_check(RunEventChoice.new(matches[0]).is_valid(), "required record valid: " + id)


func _validate_layout(record: Dictionary, label: String) -> void:
	_check(panel.is_visible_in_tree() and panel.has_open_event(), label + " panel open/visible")
	_check(panel.title_label.text == record["title"], label + " exact title")
	_check(panel.description_label.text == record["description"], label + " complete description")
	_check(panel.paper_panel.get_theme_stylebox("panel") is StyleBoxFlat,
		label + " patchwork paper StyleBoxFlat")
	_check(panel.get_node("SlateBackdrop") is ColorRect, label + " slate background node")
	var choices: Array = record["choices"]
	var buttons := panel.get_choice_buttons()
	_check(buttons.size() == choices.size(), label + " exact choice count")
	_check(panel.choices_container.get_child_count() == choices.size(), label + " mounted choices count")
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(root.size))
	_check(viewport_rect.encloses(panel.paper_panel.get_global_rect()), label + " paper fits viewport")
	for i in range(mini(buttons.size(), choices.size())):
		var button: Button = buttons[i]
		_check(panel.choices_container.get_child(i) == button, label + " authentic button " + str(i))
		_check(button.text == choices[i]["text"], label + " exact authored choice text " + str(i))
		_check(button.name == "Choice_%d" % i, label + " stable choice node identity " + str(i))
		_check(button.focus_mode == Control.FOCUS_ALL, label + " keyboard reachable " + str(i))
		_check(not button.disabled and button.is_visible_in_tree(), label + " enabled and visible " + str(i))
		_check(viewport_rect.encloses(button.get_global_rect()), label + " full button fits viewport " + str(i))
		_check(button.get_theme_stylebox("normal") is StyleBoxFlat
			and button.get_theme_stylebox("focus") is StyleBoxFlat, label + " procedural button/focus styling " + str(i))


func _test_authored() -> void:
	var step := 0
	for id in REQUIRED:
		if not authored.has(id):
			continue
		step += 1
		var record: Dictionary = authored[id]
		committed.clear()
		_check(panel.open_event(record), "open authored " + id)
		await _frames()
		_validate_layout(record, id)
		var buttons := panel.get_choice_buttons()
		if buttons.size() != (record["choices"] as Array).size():
			panel.close_event()
			await _frames()
			continue
		var desired_index := step % buttons.size()
		var selected: Button = buttons[desired_index]
		# Verify physical pointer and both keyboard activation paths.
		if step == 1:
			await _mouse(selected)
		elif step == 2:
			selected.grab_focus()
			await _frames()
			_check(selected.has_focus(), "Enter target really focused")
			await _key(KEY_ENTER)
		elif step == 3:
			# Native keyboard focus traversal, then physical Space.
			# Select buttons[1] for focus traversal test, adjust expected index accordingly.
			buttons[0].grab_focus()
			await _frames()
			await _key(KEY_TAB)
			_check(buttons[1].has_focus(), "Tab moves focus between real authored buttons")
			selected = buttons[1]
			desired_index = 1
			await _key(KEY_SPACE)
		else:
			selected.pressed.emit()
		_check(committed.size() == 1, "exactly one authored commit " + id)
		if committed.size() == 1:
			_check(committed[0] == {"event_id": id, "choice_id": record["choices"][desired_index]["id"]},
				"exact chosen authored IDs " + id)
		for button in buttons:
			_check(button.disabled, "all authored buttons spent after success " + id)
			button.pressed.emit()
		_check(committed.size() == 1, "no replay despite explicit pressed signals " + id)
		_check(panel._selector.is_claimed(), "real selector claimed " + id)
		panel.close_event()
		await _frames()
		_check(not panel.has_open_event() and not panel.visible
			and panel.get_choice_buttons().is_empty(), "close releases authored " + id)


func _test_three_choice_and_identity() -> void:
	var original := _fixture_three()
	var caller := original.duplicate(true)
	committed.clear()
	_check(panel.open_event(caller), "valid three-choice fixture accepted")
	await _frames()
	_validate_layout(original, "three-choice fixture")
	var buttons := panel.get_choice_buttons()
	_check(buttons.size() == 3, "three independent selector buttons present")
	if buttons.size() != 3:
		panel.close_event()
		await _frames()
		return
	var first_selector := panel._selector
	var first_generation := panel._generation
	var stale_callable: Callable = buttons[0].pressed.get_connections()[0]["callable"]
	# Detachment includes nested structures and current presentation text.
	caller["title"] = "TAMPERED"
	caller["description"] = "TAMPERED"
	caller["choices"][0]["text"] = "TAMPERED"
	caller["choices"][0]["id"] = "forged"
	caller["choices"].append({"id": "new", "text": "new"})
	_validate_layout(original, "detached caller")
	_check(panel._selector.get_event() == original, "authoritative snapshot immune to nested caller mutation")
	# A physically hidden or disabled button's forcibly raised signal must not commit.
	buttons[0].hide()
	buttons[0].pressed.emit()
	_check(committed.is_empty() and panel._selector.is_valid(), "hidden choice inert")
	buttons[0].show()
	buttons[0].disabled = true
	buttons[0].pressed.emit()
	_check(committed.is_empty() and panel._selector.is_valid(), "disabled choice inert")
	buttons[0].disabled = false
	# Attempt an unoffered choice using a valid live button and a foreign valid
	# selector, plus a forged ID on a different real button.
	panel._on_choice_pressed(first_selector, "not_offered", first_generation, buttons[0])
	panel._on_choice_pressed(first_selector, "right", first_generation, buttons[0])
	panel._on_choice_pressed(RunEventChoice.new(original), "left", first_generation, buttons[0])
	var foreign := Button.new()
	panel.choices_container.add_child(foreign)
	panel._on_choice_pressed(first_selector, "left", first_generation, foreign)
	foreign.queue_free()
	_check(committed.is_empty() and first_selector.is_valid(), "foreign and forged callbacks reject without claim")
	# An invalid replacement must not consume/overwrite the current offering.
	_check(not panel.open_event(_fixture_three()), "active unclaimed event cannot be overwritten")
	_check(panel._selector == first_selector and panel._generation == first_generation,
		"refused overwrite preserves identity and generation")
	# Closed callbacks from the prior scene cannot spend the new selector.
	panel.close_event()
	var replacement := _fixture_three()
	replacement["id"] = "replacement_event"
	_check(panel.open_event(replacement), "new valid event opens after close")
	var replacement_selector := panel._selector
	var replacement_gen := panel._generation
	# Old Button is queued but not yet freed; its signal's saved Callable
	# and a direct forged stale callback both must fail closed.
	if is_instance_valid(buttons[0]):
		stale_callable.call()
		panel._on_choice_pressed(first_selector, "left", first_generation, buttons[0])
	_check(committed.is_empty() and replacement_selector.is_valid()
		and panel._selector == replacement_selector and replacement_gen != first_generation,
		"closed/reopened old callback cannot affect replacement")
	await _frames()
	_validate_layout(replacement, "replacement")
	var new_buttons := panel.get_choice_buttons()
	# Invalid offered ID on a current valid button is inert; later valid is accepted.
	panel._on_choice_pressed(replacement_selector, "unoffered", replacement_gen, new_buttons[0])
	_check(committed.is_empty() and replacement_selector.is_valid(), "unoffered ID remains claimable")
	new_buttons[2].pressed.emit()
	_check(committed.size() == 1 and committed[0] == {"event_id": "replacement_event", "choice_id": "wait"},
		"third offered choice commits exact replacement event and choice IDs")
	_check(replacement_selector.is_claimed(), "replacement selector latched")
	_check(not panel.open_event(original), "claimed open panel must close before next event")
	panel.close_event()
	await _frames()


func _test_frayed_new_button() -> void:
	var record: Dictionary = authored.get("frayed_signpost", {})
	if record.is_empty():
		return
	committed.clear()
	# Open the authored frayed_signpost (now 3 choices).
	_check(panel.open_event(record), "author frayed_signpost opens with new third choice")
	await _frames()
	_validate_layout(record, "frayed_new_button")
	var buttons := panel.get_choice_buttons()
	_check(buttons.size() == 3, "frayed_signpost now has three buttons")
	if buttons.size() != 3:
		panel.close_event()
		await _frames()
		return
	# The new button is the third option.
	var new_button: Button = buttons[2]
	_check(new_button.text == "Sell the stitched arrowwork (spend 2 scraps; gain 26 gold)",
		"new sell_arrowwork button text readable")
	_check(new_button.focus_mode == Control.FOCUS_ALL, "new button keyboard reachable")
	_check(not new_button.disabled and new_button.is_visible_in_tree(),
		"new button enabled and visible")
	# Mouse activation of the new choice.
	committed.clear()
	await _mouse(new_button)
	_check(committed.size() == 1, "new choice emits exactly once from mouse")
	if committed.size() == 1:
		_check(committed[0] == {"event_id": "frayed_signpost", "choice_id": "sell_arrowwork"},
			"new choice emits exact event/choice IDs from mouse")
	for button in buttons:
		_check(button.disabled, "all buttons disabled after mouse claim")
	# Close/reopen and verify stale callbacks are invalidated.
	panel.close_event()
	await _frames()
	_check(not panel.has_open_event() and panel.get_choice_buttons().is_empty(),
		"close releases buttons and selector")
	committed.clear()
	# Reopen and activate via keyboard (focus traversal to the new third button).
	_check(panel.open_event(record.duplicate(true)), "reopen frayed_signpost after close")
	await _frames()
	var reopened_buttons := panel.get_choice_buttons()
	_check(reopened_buttons.size() == 3, "reopened frayed_signpost has three buttons")
	# Focus traversal to the third button then Space.
	if reopened_buttons.size() == 3:
		reopened_buttons[0].grab_focus()
		await _frames()
		await _key(KEY_TAB)
		await _frames()
		await _key(KEY_TAB)
		await _frames()
		var focused: Button = reopened_buttons[2]
		_check(focused.has_focus(), "tab reaches third new button after reopen")
		await _key(KEY_SPACE)
		_check(committed.size() == 1, "new choice emits exactly once from keyboard after reopen")
		if committed.size() == 1:
			_check(committed[0] == {"event_id": "frayed_signpost", "choice_id": "sell_arrowwork"},
				"reopened keyboard claim exact IDs")
	panel.close_event()
	await _frames()


func _test_invalid_and_replay() -> void:
	var valid := _fixture_three()
	var invalids: Array[Dictionary] = []
	for field in ["id", "title", "description", "choices"]:
		var missing := valid.duplicate(true)
		missing.erase(field)
		invalids.append(missing)
	for field in ["id", "title", "description"]:
		var blank := valid.duplicate(true)
		blank[field] = "   "
		invalids.append(blank)
	var numeric := valid.duplicate(true)
	numeric["id"] = 5
	invalids.append(numeric)
	var bad_choices := valid.duplicate(true)
	bad_choices["choices"] = "not an array"
	invalids.append(bad_choices)
	for n in [0, 1, 4]:
		var wrong_count := valid.duplicate(true)
		wrong_count["choices"] = valid["choices"].slice(0, n) if n < 4 else [
			{"id": "a", "text": "A"}, {"id": "b", "text": "B"},
			{"id": "c", "text": "C"}, {"id": "d", "text": "D"}]
		invalids.append(wrong_count)
	var duplicated := valid.duplicate(true)
	duplicated["choices"][1]["id"] = duplicated["choices"][0]["id"]
	invalids.append(duplicated)
	var malformed := valid.duplicate(true)
	malformed["choices"][0]["text"] = ""
	invalids.append(malformed)
	var nonobject := valid.duplicate(true)
	nonobject["choices"][1] = "invalid"
	invalids.append(nonobject)
	var blank_choice_id := valid.duplicate(true)
	blank_choice_id["choices"][1]["id"] = " "
	invalids.append(blank_choice_id)
	for i in range(invalids.size()):
		var before: Dictionary = invalids[i].duplicate(true)
		committed.clear()
		_check(not panel.open_event(invalids[i]), "malformed record rejected #" + str(i))
		_check(not panel.has_open_event() and not panel.visible
			and panel.get_choice_buttons().is_empty(), "invalid record never mounted buttons #" + str(i))
		_check(invalids[i] == before, "rejection never mutates caller #" + str(i))
		_check(committed.is_empty(), "rejection never emits #" + str(i))
	# Repeatable identical claim trace from independent selectors behind same panel.
	var replay: Array = []
	for attempt in range(2):
		committed.clear()
		_check(panel.open_event(valid), "replay opens independent fresh selector #" + str(attempt))
		await _frames()
		panel.get_choice_buttons()[1].pressed.emit()
		replay.append(committed.duplicate(true))
		panel.close_event()
		await _frames()
	_check(replay.size() == 2 and replay[0] == replay[1]
		and replay[0] == [{"event_id": "three_choice_fixture", "choice_id": "right"}],
		"two independent reopen traces are deterministic and identical")


func _test_rng_zero_draws() -> void:
	var original := _fixture_three()
	var local := RandomNumberGenerator.new()
	local.seed = 745392
	var local_state := local.state
	seed(743291)
	var expected := randi()
	seed(743291)
	committed.clear()
	_check(panel.open_event(original), "RNG test opens valid fixture")
	var buttons := panel.get_choice_buttons()
	panel._on_choice_pressed(panel._selector, "unoffered", panel._generation, buttons[0])
	buttons[0].pressed.emit()
	for button in buttons:
		button.pressed.emit()
	panel.close_event()
	_check(local.state == local_state, "local seeded RNG state untouched by all panel operations")
	_check(randi() == expected, "same global seeded stream has zero draws")
	_check(committed == [{"event_id": "three_choice_fixture", "choice_id": "left"}],
		"RNG flow commits once without effects")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := load(PANEL_SCENE) as PackedScene
	_check(scene != null, "real panel scene loads")
	if scene == null:
		_finish()
		return
	panel = scene.instantiate() as LiveEventChoicePanel
	_check(panel != null, "real scene has expected panel script")
	if panel == null:
		_finish()
		return
	root.add_child(panel)
	panel.choice_committed.connect(_on_choice_committed)
	panel.wallet_choice_committed.connect(_on_wallet_choice_committed)
	await _frames()
	_check(not panel.visible and not panel.has_open_event(), "initially closed")
	_check(panel.has_method("open_event") and panel.has_method("close_event"),
		"required public lifecycle methods exist")
	_read_authored()
	await _test_authored()
	await _test_three_choice_and_identity()
	await _test_frayed_new_button()
	await _test_invalid_and_replay()
	_test_rng_zero_draws()
	await _test_wallet_authored()
	await _test_wallet_reopen_refresh()
	await _test_wallet_keyboard()
	await _test_wallet_rejection_and_generation()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_event_choice_panel_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	if is_instance_valid(panel):
		panel.free()
	quit(0 if failures.is_empty() else 1)
