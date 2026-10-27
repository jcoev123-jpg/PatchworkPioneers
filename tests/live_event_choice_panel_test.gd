extends SceneTree
## Mounted, deterministic M04 Event panel contract. No live app wiring or effects.
const PANEL_SCENE := "res://scenes/event_choice_panel.tscn"
const EVENTS_PATH := "res://data/events/m04_events.json"
const HEADING_FONT := "res://assets/fonts/LondrinaSolid-Regular.ttf"
const BODY_FONT := "res://assets/fonts/PatrickHand-Regular.ttf"
## The master Theme's Label variation that carries the Londrina display face.
const DISPLAY_VARIATION := "PatchHeading"
## The one committed Event scene this screen reuses; never a new asset.
const EVENT_ART := "res://assets/paper/backgrounds/event_crossroads.png"
const PANEL_ART := "res://assets/paper/ui/reward_panel.png"
const REQUIRED := {
	"button_trail": "The Button Trail",
	"loose_seam": "The Loose Seam",
	"thimble_well": "The Thimble Well",
	"frayed_signpost": "The Frayed Signpost",
	"quiet_spool": "The Quiet Spool",
	"needle_gate": "The Needle Gate",
	"quilting_bee": "The Quilting Bee",
}
## Independent wording for the three hover endings. The panel's own constants
## are never consulted, so a shared mistake cannot hide behind an oracle.
const ZERO_HINT := "No change to gold or scraps."
const LEGACY_HINT := "Authored outcome; your run's wallet is not checked here."
const UNAVAILABLE_HINT := "Outcome unavailable: this choice cannot be settled."

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


## The authored gold/scraps amounts of one choice, parsed exactly as the service
## parses them (integral floats allowed, an outcome that is not exactly the two
## amount keys is unknown). Never reads the panel or its preview rows.
func _authored_amounts(choice: Dictionary) -> Dictionary:
	var outcome: Variant = choice.get("outcome")
	if not outcome is Dictionary:
		return {}
	var dict: Dictionary = outcome
	if dict.size() != 2 or not dict.has("gold") or not dict.has("scraps"):
		return {}
	var gold: Variant = _authored_int(dict.get("gold"))
	var scraps: Variant = _authored_int(dict.get("scraps"))
	if gold == null or scraps == null:
		return {}
	return {"gold": int(gold), "scraps": int(scraps)}


func _authored_int(value: Variant) -> Variant:
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		if is_finite(number) and floor(number) == number:
			return int(number)
	return null


## Independent visible ticket oracle, using authored data rather than the
## panel formatter or its preview rows.
func _expected_ticket(choice: Dictionary) -> String:
	var amount := _authored_amounts(choice)
	var impact := UNAVAILABLE_HINT
	if not amount.is_empty():
		var effects: Array[String] = []
		if amount["gold"] != 0:
			effects.append("Gold %+d" % amount["gold"])
		if amount["scraps"] != 0:
			effects.append("Scraps %+d" % amount["scraps"])
		impact = ZERO_HINT if effects.is_empty() else "   |   ".join(effects)
	return String(choice["text"]) + "\n" + impact


## Independent legacy hover oracle retains the full signed resource row and
## explanation, even when the visible ticket omits zero deltas.
func _expected_authored_tooltip(choice: Dictionary) -> String:
	var amount := _authored_amounts(choice)
	if amount.is_empty():
		return String(choice["text"]) + "\n" + UNAVAILABLE_HINT
	var lines: Array[String] = [String(choice["text"]),
		"Gold %+d   |   Scraps %+d" % [amount["gold"], amount["scraps"]]]
	if amount["gold"] == 0 and amount["scraps"] == 0:
		lines.append(ZERO_HINT)
	else:
		lines.append(LEGACY_HINT)
	return "\n".join(lines)


## Independent wallet hover oracle: the authored action and signed deltas, then
## the balance those exact amounts project from the caller wallet, or the exact
## shortfall per resource when the projection would go negative.
func _expected_wallet_tooltip(choice: Dictionary, wallet: Dictionary) -> String:
	var amount := _authored_amounts(choice)
	if amount.is_empty():
		return String(choice["text"]) + "\n" + UNAVAILABLE_HINT
	var after_gold: int = int(wallet["gold"]) + amount["gold"]
	var after_scraps: int = int(wallet["scraps"]) + amount["scraps"]
	var lines: Array[String] = [String(choice["text"]),
		"Gold %+d   |   Scraps %+d" % [amount["gold"], amount["scraps"]]]
	if after_gold >= 0 and after_scraps >= 0:
		lines.append("After: %d gold | %d scraps" % [after_gold, after_scraps])
	else:
		var needs: Array[String] = []
		if after_gold < 0:
			needs.append("Need %d gold" % -after_gold)
		if after_scraps < 0:
			needs.append("Need %d scraps" % -after_scraps)
		lines.append("UNAVAILABLE" if needs.is_empty() else "   •   ".join(needs))
	return "\n".join(lines)


func _wallet_index(record: Dictionary, choice_id: String) -> int:
	var choices: Array = record.get("choices", [])
	for i in range(choices.size()):
		if choices[i] is Dictionary and choices[i].get("id") == choice_id:
			return i
	return -1


func _check_wallet_layout(record: Dictionary, wallet: Dictionary, label: String) -> void:
	_check_story_structure(label)
	_check(panel.has_open_event() and panel.is_visible_in_tree(), label + " mounted visible event")
	_check(panel.title_label.text == record["title"] and panel.description_label.text == record["description"],
		label + " authored title and description visible")
	# AC2: the wallet offering's story keeps the body face while its dynamic
	# balance caption joins the Event title in the sewn display face.
	_check(panel.title_label.theme_type_variation == DISPLAY_VARIATION
		and (panel.title_label.get_theme_font("font") as Font).resource_path == HEADING_FONT,
		label + " wallet Event title keeps the display heading face")
	_check(panel.description_label.theme_type_variation == ""
		and (panel.description_label.get_theme_font("font") as Font).resource_path == BODY_FONT,
		label + " wallet Event description keeps the inherited body face")
	# AC2: wallet offerings keep the same natural-height story above their
	# three-line 78px tickets instead of reserving a fixed story block.
	_check(panel.description_label.size_flags_vertical & Control.SIZE_EXPAND == 0
		and panel.description_label.custom_minimum_size == Vector2.ZERO,
		label + " wallet story sits at its natural wrapped height above the tickets")
	var balance := panel.choices_container.get_parent().get_node_or_null("WalletBalance") as Label
	_check(balance != null, label + " visible balance label")
	if balance != null:
		_check(balance.is_visible_in_tree() and balance.text == "Wallet  •  %d gold   /   %d scraps" % [wallet["gold"], wallet["scraps"]],
			label + " current exact gold and scraps")
		_check(balance.theme_type_variation == DISPLAY_VARIATION,
			label + " balance caption wears the master PatchHeading variation")
		var balance_font := balance.get_theme_font("font") as Font
		_check(balance_font != null and balance_font.resource_path == HEADING_FONT,
			label + " balance caption is sewn in the Londrina display face")
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
		var ticket_font := button.get_theme_font("font") as Font
		_check(ticket_font != null and ticket_font.resource_path == BODY_FONT,
			label + " ticket action, deltas and after-wallet lines keep the body face " + str(i))
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
		_check(button.tooltip_text == _expected_wallet_tooltip(choices[i], wallet),
			label + " hover repeats the exact authored action and current projection " + str(i))
		_check(button.tooltip_text.begins_with(String(choices[i]["text"]))
			and button.tooltip_text.split("\n").size() == 3,
			label + " hover is exactly action, deltas and one projection " + str(i))
		_check(button.get_parent() == panel.choices_container and button.is_visible_in_tree(),
			label + " actual mounted choice button " + str(i))
		_check(viewport.encloses(button.get_global_rect()), label + " full choice onscreen " + str(i))
		_check_ticket_skin(button, label + str(i))


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
	var denied_tooltip: String = disabled.tooltip_text
	var recovery_tooltip: String = recovery.tooltip_text
	await _mouse_motion(recovery)
	_check(root.gui_get_hovered_control() == recovery, label + " pointer really rests on the recovery ticket")
	await _mouse_motion(disabled)
	_check(root.gui_get_hovered_control() == disabled, label + " pointer really rests on the unavailable ticket")
	_check(disabled.tooltip_text == denied_tooltip and recovery.tooltip_text == recovery_tooltip,
		label + " hover reveals the same read-only text and rewrites nothing")
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
	var tooltip_snapshots: Array = []
	for wallet in wallets:
		_check(panel.open_event_with_wallet(bee, wallet),
			"quilting bee opens at " + str(wallet))
		if not panel.has_open_event():
			return
		await _frames()
		_check_wallet_layout(bee, wallet, "reopen bee @ " + str(wallet))
		var texts: Array[String] = []
		var tooltips: Array[String] = []
		for button in panel.get_choice_buttons():
			texts.append(button.text)
			tooltips.append(button.tooltip_text)
		snapshots.append(texts)
		tooltip_snapshots.append(tooltips)
		panel.close_event()
		await _frames()
	_check(snapshots.size() == 3 and tooltip_snapshots.size() == 3,
		"three quilting bee wallet snapshots captured")
	if snapshots.size() == 3 and tooltip_snapshots.size() == 3:
		_check(snapshots[0] != snapshots[1] and snapshots[1] != snapshots[2]
			and snapshots[0] != snapshots[2],
			"different wallets refresh every ticket for the same authored event")
		_check(tooltip_snapshots[0] != tooltip_snapshots[1]
			and tooltip_snapshots[1] != tooltip_snapshots[2]
			and tooltip_snapshots[0] != tooltip_snapshots[2],
			"reopening at another wallet refreshes every hover projection")
		_check((snapshots[0] as Array)[0].ends_with("After: 32 gold | 0 scraps"),
			"2 scraps wallet previews sew_panel after totals")
		_check((tooltip_snapshots[0] as Array)[0].ends_with("After: 32 gold | 0 scraps"),
			"2 scraps wallet hover previews sew_panel after totals")
		_check((snapshots[1] as Array)[0].ends_with("Need 2 scraps"),
			"15 gold wallet ticket names the missing scraps for sew_panel")
		_check((tooltip_snapshots[1] as Array)[0].ends_with("Need 2 scraps"),
			"15 gold wallet hover names the missing scraps for sew_panel")
		_check((snapshots[1] as Array)[1].ends_with("After: 0 gold | 2 scraps"),
			"15 gold wallet previews buy_thread after totals")
		_check((tooltip_snapshots[1] as Array)[1].ends_with("After: 0 gold | 2 scraps"),
			"15 gold wallet hover previews buy_thread after totals")
		_check((snapshots[2] as Array)[1].ends_with("Need 15 gold"),
			"0 gold wallet ticket names the missing gold for buy_thread")
		_check((tooltip_snapshots[2] as Array)[1].ends_with("Need 15 gold"),
			"0 gold wallet hover names the missing gold for buy_thread")
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
		_check(estate_buttons[buy_index].tooltip_text.ends_with("After: 5 gold | 2 scraps"),
			"estate buy_thread hover shows exact after totals")
		_check(estate_buttons[sell_index].text.ends_with("Need 2 scraps")
			and estate_buttons[sell_index].disabled
			and estate_buttons[sell_index].focus_mode == Control.FOCUS_NONE,
			"estate sell_fabric names missing scraps and cannot be selected")
		_check(estate_buttons[sell_index].tooltip_text.ends_with("Need 2 scraps")
			and not estate_buttons[sell_index].tooltip_text.contains("After:"),
			"estate sell_fabric hover names the exact shortfall only")
		_check(estate_buttons[leave_index].text.ends_with("After: 20 gold | 0 scraps"),
			"estate leave shows unchanged exact after totals")
		_check(estate_buttons[leave_index].tooltip_text.ends_with("After: 20 gold | 0 scraps"),
			"estate leave hover shows unchanged exact after totals")
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
	_check(bad.tooltip_text == String(malformed["choices"][idx]["text"]) + "\n" + UNAVAILABLE_HINT,
		"malformed outcome hover keeps the authored action and an honest placeholder")
	_check(not bad.tooltip_text.contains("\nGold ") and not bad.tooltip_text.contains("After:")
		and not bad.tooltip_text.contains("Need "),
		"malformed outcome hover invents no amount, balance or shortfall")
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
	_check_story_structure(label)
	_check(panel.is_visible_in_tree() and panel.has_open_event(), label + " panel open/visible")
	_check(panel.title_label.text == record["title"], label + " exact title")
	_check(panel.description_label.text == record["description"], label + " complete description")
	# AC1: the story takes only its natural wrapped height, so no expanding
	# description (or spacer) can push the first authored ticket away from it.
	_check(panel.description_label.size_flags_vertical & Control.SIZE_EXPAND == 0
		and panel.description_label.custom_minimum_size == Vector2.ZERO,
		label + " story sits at its natural wrapped height above the choices")
	_check(panel.title_label.theme_type_variation == DISPLAY_VARIATION
		and (panel.title_label.get_theme_font("font") as Font).resource_path == HEADING_FONT,
		label + " authored Event title wears the master PatchHeading Londrina face")
	_check(panel.description_label.theme_type_variation == ""
		and (panel.description_label.get_theme_font("font") as Font).resource_path == BODY_FONT,
		label + " Event description stays in the inherited body font")
	_check_paper_skin(label)
	_check(panel.get_node("SlateBackdrop") is ColorRect, label + " slate background node")
	_check_backdrop_layer(label)
	var choices: Array = record["choices"]
	var buttons := panel.get_choice_buttons()
	_check(buttons.size() == choices.size(), label + " exact choice count")
	_check(panel.choices_container.get_child_count() == choices.size(), label + " mounted choices count")
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(root.size))
	_check(viewport_rect.encloses(panel.paper_panel.get_global_rect()), label + " paper fits viewport")
	for i in range(mini(buttons.size(), choices.size())):
		var button: Button = buttons[i]
		_check(panel.choices_container.get_child(i) == button, label + " authentic button " + str(i))
		_check(button.text == _expected_ticket(choices[i]), label + " exact authored choice text " + str(i))
		_check((button.get_theme_font("font") as Font).resource_path == BODY_FONT,
			label + " authored action and impact stay in the body face " + str(i))
		_check(button.name == "Choice_%d" % i, label + " stable choice node identity " + str(i))
		_check(button.focus_mode == Control.FOCUS_ALL, label + " keyboard reachable " + str(i))
		_check(not button.disabled and button.is_visible_in_tree(), label + " enabled and visible " + str(i))
		_check(viewport_rect.encloses(button.get_global_rect()), label + " full button fits viewport " + str(i))
		_check_ticket_skin(button, label + str(i))
		_check(button.tooltip_text == _expected_authored_tooltip(choices[i]),
			label + " authored action and exact signed outcome on hover " + str(i))
		# open_event() carries no run wallet, so its neutral zero-wallet service
		# preview must never surface as an affordability claim.
		_check(not button.tooltip_text.contains("After:")
			and not button.tooltip_text.contains("Need "),
			label + " legacy hover never claims this run's affordability " + str(i))


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
		_check(panel.description_label.custom_minimum_size == Vector2.ZERO,
			"close resets the story to its natural height " + id)


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
	_check(new_button.text == "Sell the stitched arrowwork (spend 2 scraps; gain 26 gold)\nGold +26   |   Scraps -2",
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


## AC1: the three run-owner Events the app really mounts explain their authored
## action and exact currency on hover, including zero-change exits and a priced
## branch that the neutral preview calls unaffordable.
func _test_authored_tooltips() -> void:
	var quiet: Dictionary = authored.get("quiet_spool", {})
	var moth := _wallet_record("res://data/events/moth_infestation.json", "moth_infestation")
	var dye := _wallet_record("res://data/events/dye_vat.json", "dye_vat")
	for record in [quiet, moth, dye]:
		_check(not record.is_empty() and RunEventChoice.new(record).is_valid(),
			"authored hover fixture is a genuine valid event " + str(record.get("id", "")))
	if quiet.is_empty() or moth.is_empty() or dye.is_empty():
		return
	seed(616263)
	var expected_rng := randi()
	seed(616263)
	committed.clear()
	for record in [quiet, moth, dye]:
		var id := String(record["id"])
		_check(panel.open_event(record), "legacy hover opens " + id)
		if not panel.has_open_event():
			return
		await _frames()
		var buttons := panel.get_choice_buttons()
		var choices: Array = record["choices"]
		_check(buttons.size() == choices.size(), "legacy hover fixture mounts every choice " + id)
		if buttons.size() != choices.size():
			panel.close_event()
			await _frames()
			continue
		_check_numbered_cues(record, "authored impact " + id)
		var by_id: Dictionary = {}
		for i in range(buttons.size()):
			var choice_id := String(choices[i]["id"])
			by_id[choice_id] = buttons[i]
			_check(buttons[i].tooltip_text == _expected_authored_tooltip(choices[i]),
				"legacy hover states the exact authored action and outcome " + id + "/" + choice_id)
			_check(buttons[i].text == _expected_ticket(choices[i]),
				"ticket shows the authored action and parsed impact " + id + "/" + choice_id)
			_check(buttons[i].focus_mode == Control.FOCUS_ALL and not buttons[i].disabled,
				"hover keeps every legacy choice reachable " + id + "/" + choice_id)
		# Moth feeding removes a chosen card; the Dye Vat rewrites a pool card.
		if id == "moth_infestation":
			var feed: String = by_id["sacrifice_card"].tooltip_text
			_check(feed.begins_with("Feed one ordinary card to the moths")
				and feed.contains("Scraps +2") and not feed.contains("Need "),
				"moth feed hover names the removal action and its exact gain")
			var fumigate: String = by_id["fumigate"].tooltip_text
			_check(fumigate.begins_with("Fumigate the deck")
				and fumigate.contains("Scraps -1") and not fumigate.contains("Need 1 scrap")
				and not fumigate.contains("After:"),
				"moth fumigate hover states its cost without a run-wallet claim")
			_check((by_id["escape"] as Button).tooltip_text.ends_with(ZERO_HINT),
				"moth escape hover states the zero-change exit")
		elif id == "dye_vat":
			var immerse: String = by_id["immerse"].tooltip_text
			_check(immerse.begins_with("Immerse one owned pool card in the dye")
				and immerse.contains("it becomes its authored + version")
				and immerse.contains("Scraps -3") and not immerse.contains("Need 3 scraps"),
				"dye immerse hover keeps the upgrade action and exact cost")
			_check((by_id["leave"] as Button).tooltip_text.ends_with(ZERO_HINT),
				"dye leave hover states the zero-change exit")
		else:
			_check((by_id["watch"] as Button).tooltip_text.contains("Scraps +1")
				and (by_id["watch"] as Button).tooltip_text.ends_with(LEGACY_HINT),
				"quiet spool watch hover states its exact gain")
			_check((by_id["ignore"] as Button).tooltip_text.ends_with(ZERO_HINT),
				"quiet spool ignore hover states the zero-change exit")
		# Real pointer hover cannot settle, mutate or draw from the RNG.
		var view_rect := Rect2(Vector2.ZERO, Vector2(root.size))
		_check(view_rect.encloses(panel.paper_panel.get_global_rect()),
			"hover fixture paper card stays inside 1280x720 " + id)
		for button in buttons:
			_check(view_rect.encloses(button.get_global_rect()),
				"hover fixture ticket stays inside 1280x720 " + id)
		for button in buttons:
			await _mouse_motion(button)
			_check(root.gui_get_hovered_control() == button,
				"pointer really rests on " + id + "/" + str(panel._bound_choices.get(button, "")))
		_check(committed.is_empty() and panel._selector.is_valid(),
			"hovering every legacy choice commits nothing " + id)
		panel.close_event()
		await _frames()
	_check(randi() == expected_rng, "legacy hover and close consume zero RNG")


## AC2: malformed or unknown authored outcomes keep their action and print the
## honest placeholder, invent no number, and change no selection rule. Closing
## really releases the hover-bearing tickets and reopening rebuilds them.
func _test_malformed_tooltips() -> void:
	var base: Dictionary = authored.get("quiet_spool", {})
	_check(not base.is_empty(), "malformed hover fixture is the authored Quiet Spool")
	if base.is_empty():
		return
	var broken: Array[Dictionary] = []
	var missing := base.duplicate(true)
	missing["choices"][0].erase("outcome")
	broken.append(missing)
	var nonnumeric := base.duplicate(true)
	nonnumeric["choices"][0]["outcome"] = {"gold": "not coins", "scraps": 1}
	broken.append(nonnumeric)
	var extra := base.duplicate(true)
	extra["choices"][0]["outcome"] = {"gold": 4, "scraps": 1, "card": "keep"}
	broken.append(extra)
	for i in range(broken.size()):
		var record: Dictionary = broken[i]
		committed.clear()
		_check(panel.open_event(record), "legacy record with a broken outcome opens #" + str(i))
		await _frames()
		var buttons := panel.get_choice_buttons()
		_check(buttons.size() == 2, "both legacy tickets still mount #" + str(i))
		if buttons.size() != 2:
			panel.close_event()
			await _frames()
			continue
		for index in range(buttons.size()):
			_check(buttons[index].text == _expected_ticket(record["choices"][index]),
				"malformed ticket shows only known impact #" + str(i) + "/" + str(index))
		_check(not buttons[0].text.contains("Gold ") and not buttons[0].text.contains("Scraps ")
			and not buttons[0].text.contains("After:") and not buttons[0].text.contains("Need "),
			"malformed ticket invents no amounts or affordability #" + str(i))
		_check(buttons[0].tooltip_text == String(record["choices"][0]["text"]) + "\n" + UNAVAILABLE_HINT,
			"broken legacy outcome keeps its action and the honest placeholder #" + str(i))
		_check(not buttons[0].tooltip_text.contains("\nGold ")
			and not buttons[0].tooltip_text.contains("Need "),
			"broken legacy outcome invents no amount #" + str(i))
		_check(buttons[1].tooltip_text == _expected_authored_tooltip(record["choices"][1]),
			"intact sibling keeps its exact zero-change hover #" + str(i))
		_check(not buttons[0].disabled and not buttons[1].disabled,
			"broken legacy outcome never changes selection rules #" + str(i))
		panel.close_event()
		await _frames()
	var quiet: Dictionary = base.duplicate(true)
	_check(panel.open_event(quiet), "legacy hover fixture opens for the reopen check")
	await _frames()
	var first: Array[String] = []
	for button in panel.get_choice_buttons():
		first.append(button.tooltip_text)
	_check(first.size() == 2 and first[0].contains("Scraps +1") and first[1].ends_with(ZERO_HINT),
		"first legacy opening explains both authored outcomes")
	panel.close_event()
	await _frames()
	_check(panel.get_choice_buttons().is_empty(), "close releases the hover-bearing tickets")
	_check(panel.open_event(quiet), "same legacy offering reopens after close")
	await _frames()
	var second: Array[String] = []
	for button in panel.get_choice_buttons():
		second.append(button.tooltip_text)
	_check(not second.is_empty() and second == first, "reopening rebuilds identical hover text")
	panel.close_event()
	await _frames()


## AC2: an unknown outcome in a real wallet offering is disabled, explains the
## authored action, names no balance or shortfall, and never blocks a genuine
## alternative from settling exactly once.
func _test_wallet_malformed_tooltips() -> void:
	var record: Dictionary = authored.get("quilting_bee", {})
	_check(not record.is_empty(), "wallet malformed hover fixture is the authored bee")
	if record.is_empty():
		return
	var unknown := record.duplicate(true)
	var watch := _wallet_index(unknown, "watch")
	_check(watch >= 0, "bee watch choice present for the unknown outcome")
	if watch < 0:
		return
	unknown["choices"][watch].erase("outcome")
	var wallet := {"gold": 15, "scraps": 0}
	wallet_committed.clear()
	committed.clear()
	_check(panel.open_event_with_wallet(unknown, wallet), "bee with one unknown outcome opens")
	await _frames()
	var buttons := panel.get_choice_buttons()
	_check(buttons.size() == 3, "unknown-outcome wallet offering mounts every ticket")
	if buttons.size() != 3:
		panel.close_event()
		await _frames()
		return
	_check(buttons[watch].tooltip_text == String(unknown["choices"][watch]["text"]) + "\n" + UNAVAILABLE_HINT,
		"unknown wallet outcome keeps the action and the honest placeholder")
	_check(buttons[watch].disabled and buttons[watch].focus_mode == Control.FOCUS_NONE,
		"unknown wallet outcome cannot be selected or focused")
	_check(not buttons[watch].tooltip_text.contains("\nGold ")
		and not buttons[watch].tooltip_text.contains("After:")
		and not buttons[watch].tooltip_text.contains("Need "),
		"unknown wallet outcome invents no amount, balance or shortfall")
	for index in range(3):
		if index == watch:
			continue
		_check(buttons[index].tooltip_text == _expected_wallet_tooltip(unknown["choices"][index], wallet),
			"known sibling wallet hover keeps its exact projection " + str(index))
	buttons[watch].pressed.emit()
	_check(wallet_committed.is_empty() and panel._selector.is_valid(),
		"unknown wallet outcome cannot spend the visit")
	var buy := _wallet_index(unknown, "buy_thread")
	_check(buy >= 0 and buy != watch, "known bee alternative present")
	if buy >= 0:
		buttons[buy].pressed.emit()
		_check(wallet_committed.size() == 1 and wallet_committed[0] == {
			"ok": true, "event_id": "quilting_bee", "choice_id": "buy_thread",
			"wallet": {"gold": 0, "scraps": 2}},
			"known alternative still settles exactly once from the real ticket")
	_check(wallet == {"gold": 15, "scraps": 0}, "unknown outcome never touches the caller wallet")
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


## AC1/AC2: one inert full-stage crossroads picture (with its own darkening scrim)
## sits above the opaque slate and behind the parchment. It draws the committed
## image only when that shipped file resolves; otherwise the layer is hidden and
## the slate stays the ground. No pixel, node-position or fixed-coordinate claim.
func _check_backdrop_layer(label: String) -> void:
	var backdrop := panel.get_node_or_null("EventBackdrop") as TextureRect
	_check(backdrop != null and backdrop.get_parent() == panel,
		label + " mounts one Event backdrop picture layer")
	if backdrop == null:
		return
	_check(backdrop.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and backdrop.focus_mode == Control.FOCUS_NONE,
		label + " backdrop never takes pointer or keyboard focus")
	_check(backdrop.gui_input.get_connections().is_empty()
		and backdrop.mouse_entered.get_connections().is_empty()
		and backdrop.mouse_exited.get_connections().is_empty(),
		label + " backdrop listens to no input signal")
	_check(backdrop.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED
		and backdrop.expand_mode == TextureRect.EXPAND_IGNORE_SIZE,
		label + " backdrop covers the stage without stretching the scene")
	_check(backdrop.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR,
		label + " backdrop keeps the linear felt filtering")
	if ResourceLoader.exists(EVENT_ART):
		_check(backdrop.texture != null and backdrop.texture.resource_path == EVENT_ART,
			label + " backdrop draws the committed crossroads scene")
		_check(backdrop.visible and backdrop.is_visible_in_tree(),
			label + " shipped crossroads scene is really shown")
	else:
		_check(backdrop.texture == null and not backdrop.visible,
			label + " unavailable scene leaves the slate ground")
	var slate := panel.get_node_or_null("SlateBackdrop")
	_check(slate is ColorRect and slate.visible and backdrop.get_index() > slate.get_index()
		and backdrop.get_index() < panel.paper_panel.get_index(),
		label + " art sits above the opaque slate and behind the parchment")
	var scrim := backdrop.get_node_or_null("EventScrim") as ColorRect
	_check(scrim != null and scrim.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and scrim.focus_mode == Control.FOCUS_NONE,
		label + " darkening scrim never takes pointer or keyboard focus")
	_check(scrim != null and scrim.get_parent() == backdrop
		and scrim.is_visible_in_tree() == backdrop.is_visible_in_tree(),
		label + " scrim darkens only the mounted picture, above it and behind the paper")


func _check_story_structure(label: String) -> void:
	_check(panel.choices_container.size_flags_vertical & Control.SIZE_EXPAND == 0,
		label + " choices do not stretch away from the story")
	_check(panel.description_label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART,
		label + " complete story wraps naturally")
	var content := panel.choices_container.get_parent()
	# The authored display line keeps only the height its own font needs: no
	# reserved title block may open a blank band above the story.
	var title_font := panel.title_label.get_theme_font("font")
	var title_size := panel.title_label.get_theme_font_size("font_size")
	var title_height := title_font.get_height(title_size) if title_font != null else 0.0
	_check(title_font != null
		and panel.title_label.get_combined_minimum_size().y <= title_height + 4.0,
		label + " title takes only its natural display height")
	_check(panel.title_label.get_index() + 1 == panel.description_label.get_index()
		and panel.description_label.get_index() < panel.choices_container.get_index()
		and panel.bottom_stitches.get_index() > panel.choices_container.get_index(),
		label + " title, story, tickets, bottom stitching stay in content order")
	# Nothing but the optional wallet caption may sit between the story and the
	# tickets; any other block there would be the blank gulf this view avoids.
	for index in range(panel.description_label.get_index() + 1, panel.choices_container.get_index()):
		var between := content.get_child(index)
		_check(between is Label and between.name == "WalletBalance",
			label + " only the wallet caption sits between story and tickets")
	for child in content.get_children():
		var block := child as Control
		_check(block != null and block.size_flags_vertical & Control.SIZE_EXPAND == 0,
			label + " no content block stretches the parchment")
	_check(absf(panel.paper_panel.size.y - panel.paper_panel.get_combined_minimum_size().y) <= 1.0,
		label + " parchment stays content-sized")
	var balance := content.get_node_or_null("WalletBalance")
	if balance != null:
		_check(balance.get_index() > panel.description_label.get_index()
			and balance.get_index() < panel.choices_container.get_index(),
			label + " wallet sits between story and tickets")


func _check_ticket_skin(button: Button, label: String, art_expected := true) -> void:
	var faces: Array[Color] = []
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := button.get_theme_stylebox(state)
		var face := Color.BLACK
		if art_expected and ResourceLoader.exists("res://assets/paper/ui/reward_button.png"):
			_check(style is StyleBoxTexture, label + " sewn art face " + state)
			if style is StyleBoxTexture:
				var sewn := style as StyleBoxTexture
				_check(sewn.texture != null and sewn.texture.resource_path == "res://assets/paper/ui/reward_button.png",
					label + " exact reward fabric " + state)
				_check(sewn.texture_margin_left > 0 and sewn.texture_margin_top > 0
					and sewn.texture_margin_right > 0 and sewn.texture_margin_bottom > 0,
					label + " nine-sliced edges " + state)
				if sewn.texture != null:
					var image := sewn.texture.get_image()
					face = image.get_pixel(image.get_width() / 2, image.get_height() / 2) * sewn.modulate_color
		else:
			_check(style is StyleBoxFlat, label + " readable missing-art fallback " + state)
			if style is StyleBoxFlat:
				face = (style as StyleBoxFlat).bg_color
		var ink_name: String = "font_color" if state == "normal" else "font_" + state + "_color"
		_check(_contrast(button.get_theme_color(ink_name), face) >= 4.5,
			label + " dark readable text " + state)
		faces.append(face)
	_check(faces[0] != faces[1] and faces[0] != faces[2] and faces[0] != faces[3],
		label + " hover, press and disabled faces differ from normal")
	_check(button.get_theme_stylebox("hover_pressed") == button.get_theme_stylebox("pressed"),
		label + " held hover uses pressed surface")
	var focus := button.get_theme_stylebox("focus") as StyleBoxFlat
	_check(focus != null and not focus.draw_center and focus.border_width_left >= 3,
		label + " distinct nonoccluding keyboard ring")
	if focus != null:
		_check(_contrast(focus.border_color, faces[0]) >= 3.0, label + " visible focus ring")
	_check(_contrast(button.get_theme_color("font_focus_color"), faces[0]) >= 4.5,
		label + " focused caption stays dark")


func _test_fallback_tickets() -> void:
	# Reuse real mounted two-/three-line offerings; only the requested art path
	# differs. This exercises missing-art rendering without editing any asset.
	for wallet_mode in [false, true]:
		var record: Dictionary = authored["frayed_signpost"].duplicate(true)
		var opened := panel.open_event_with_wallet(record, {"gold": 10, "scraps": 10}) if wallet_mode else panel.open_event(record)
		_check(opened, "fallback genuine three-choice offering opens")
		if not opened:
			continue
		await _frames()
		for button in panel.get_choice_buttons():
			var font_size := button.get_theme_font_size("font_size")
			panel._style_choice_button(button, "res://assets/paper/ui/event_ticket_missing_test.png")
			button.add_theme_font_size_override("font_size", font_size)
			_check_ticket_skin(button, "fallback wallet=" + str(wallet_mode), false)
		await _check_ticket_input_states(false)
		panel.close_event()
		await _frames()


func _check_ticket_input_states(art_expected := true) -> void:
	var buttons := panel.get_choice_buttons()
	_check(buttons.size() == 3 and not buttons[0].disabled, "state probe has three real enabled tickets")
	if buttons.size() != 3 or buttons[0].disabled:
		return
	var button: Button = buttons[0]
	var legacy_before := committed.duplicate(true)
	var wallet_before := wallet_committed.duplicate(true)
	button.grab_focus()
	await _mouse_motion(button)
	_check(button.has_focus() and button.is_hovered(), "real focus and pointer hover reach ticket")
	_check_ticket_skin(button, "focused hovered ticket", art_expected)
	var press := InputEventMouseButton.new()
	press.position = button.get_global_rect().get_center()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	root.push_input(press, true)
	await _frames()
	_check(button.button_pressed, "real held mouse press reaches ticket")
	_check_ticket_skin(button, "held ticket", art_expected)
	# Cancel over the story so checking the pressed style never spends a choice.
	var outside := panel.description_label.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = outside
	root.push_input(motion, true)
	press = InputEventMouseButton.new()
	press.position = outside
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = false
	root.push_input(press, true)
	await _frames()
	_check(not button.button_pressed and not panel._selector.is_claimed()
		and committed == legacy_before and wallet_committed == wallet_before,
		"cancelled state inspection neither claims nor emits")


## WCAG relative-luminance contrast for ticket ink and sewn number tags.
func _contrast(first: Color, second: Color) -> float:
	var a := _luminance(first)
	var b := _luminance(second)
	return (maxf(a, b) + 0.05) / (minf(a, b) + 0.05)


func _luminance(color: Color) -> float:
	return 0.2126 * _linear_channel(color.r) + 0.7152 * _linear_channel(color.g) \
		+ 0.0722 * _linear_channel(color.b)


func _linear_channel(value: float) -> float:
	return value / 12.92 if value <= 0.04045 else pow((value + 0.055) / 1.055, 2.4)


## AC1: every mounted ticket wears exactly one sewn numeral tag in authored
## order; the tag is a tiny felt patch on the ticket's left edge that is legible,
## never takes pointer or focus, and stays clear of the centred authored caption
## and wallet forecast.
func _check_numbered_cues(record: Dictionary, label: String) -> void:
	var buttons := panel.get_choice_buttons()
	var cues := panel.get_choice_cues()
	var choices: Array = record["choices"]
	_check(cues.size() == buttons.size() and cues.size() == choices.size(),
		label + " one sewn number tag per offered choice")
	if cues.size() != buttons.size() or buttons.size() != choices.size():
		return
	var viewport := Rect2(Vector2.ZERO, Vector2(root.size))
	for i in range(cues.size()):
		var cue: Label = cues[i]
		var button: Button = buttons[i]
		_check(cue.text == str(i + 1), label + " tag repeats the authored position " + str(i))
		_check(cue.get_parent() == button and cue.is_visible_in_tree(),
			label + " tag is mounted on its own ticket " + str(i))
		_check(cue.theme_type_variation == DISPLAY_VARIATION,
			label + " tag wears the master PatchHeading variation " + str(i))
		var cue_font := cue.get_theme_font("font") as Font
		_check(cue_font != null and cue_font.resource_path == HEADING_FONT,
			label + " tag numeral is sewn in the Londrina display face " + str(i))
		_check(panel._bound_choices.get(button, "") == String(choices[i]["id"])
			and button.get_parent() == panel.choices_container
			and not button.pressed.get_connections().is_empty(),
			label + " tagged ticket keeps its authored choice binding " + str(i))
		_check((button.get_theme_font("font") as Font).resource_path == BODY_FONT,
			label + " tagged ticket still speaks in the body face " + str(i))
		_check(cue.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and cue.focus_mode == Control.FOCUS_NONE,
			label + " tag never takes pointer or keyboard focus " + str(i))
		var cue_rect: Rect2 = cue.get_global_rect()
		_check(viewport.encloses(cue_rect), label + " tag stays inside 1280x720 " + str(i))
		_check(button.get_global_rect().encloses(cue_rect),
			label + " tag sits fully on its ticket " + str(i))
		# Independent caption geometry: the widest drawn ticket line is centred,
		# so its left edge is the forbidding boundary for the tag.
		var font: Font = button.get_theme_font("font")
		var font_size: int = button.get_theme_font_size("font_size")
		var widest := 0.0
		for line in button.text.split("\n"):
			widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
		var caption_left: float = button.get_global_rect().position.x \
			+ maxf(0.0, (button.size.x - widest) * 0.5)
		_check(cue_rect.end.x <= caption_left,
			label + " tag keeps clear of the centred caption " + str(i))
		var patch := cue.get_theme_stylebox("normal") as StyleBoxFlat
		_check(patch != null and patch.bg_color.a > 0.0,
			label + " tag is a drawn felt patch " + str(i))
		if patch != null:
			_check(_contrast(cue.get_theme_color("font_color"), patch.bg_color) >= 4.5,
				label + " numeral stays readable on its felt tag " + str(i))
			_check(patch.border_width_left >= 1 and patch.corner_radius_top_left >= 1,
				label + " tag keeps its stitched thread border " + str(i))
		_check(cue.get_theme_font_size("font_size") >= 14,
			label + " tag numeral legible at 1280x720 " + str(i))


## AC1/AC3: physical 1/2/3 keys pick the authored-order option through the same
## guarded pressed path in a three-choice Event; a two-choice Event has no third
## tag and ignores key 3, while spent and out-of-range keys stay inert.
func _test_numbered_choice_keys() -> void:
	var signpost: Dictionary = authored.get("frayed_signpost", {})
	var spool: Dictionary = authored.get("quiet_spool", {})
	_check(not signpost.is_empty() and not spool.is_empty(),
		"numbered legacy key fixtures are authored Events")
	if signpost.is_empty() or spool.is_empty():
		return
	seed(424242)
	var expected_rng := randi()
	seed(424242)
	var digests: Array = [KEY_1, KEY_2, KEY_3]
	var expected_ids := ["read", "choose", "sell_arrowwork"]
	for index in range(digests.size()):
		committed.clear()
		wallet_committed.clear()
		_check(panel.open_event(signpost), "numbered three-choice Event opens #" + str(index))
		await _frames()
		_check_numbered_cues(signpost, "numbered three-choice #" + str(index))
		await _key(digests[index])
		_check(committed.size() == 1 and committed[0] == {
			"event_id": "frayed_signpost", "choice_id": expected_ids[index]},
			"physical key %d commits the authored option #%d" % [index + 1, index])
		_check(wallet_committed.is_empty(), "legacy numbered key emits no wallet receipt #" + str(index))
		_check(panel._selector.is_claimed(), "numbered key latched the real selector #" + str(index))
		await _key(KEY_1)
		await _key(KEY_3)
		await _key(KEY_0)
		await _key(KEY_4)
		_check(committed.size() == 1, "spent and out-of-range numbered keys cannot replay #" + str(index))
		panel.close_event()
		await _frames()
		_check(panel.get_choice_cues().is_empty(), "close releases every sewn tag #" + str(index))
	# Two-choice Event: there is no third tag, and key 3 leaves the visit unspent.
	committed.clear()
	_check(panel.open_event(spool), "two-choice Event opens for numbered keys")
	await _frames()
	_check_numbered_cues(spool, "numbered two-choice")
	_check(panel.get_choice_cues().size() == 2, "two-choice Event wears exactly two tags")
	await _key(KEY_3)
	_check(committed.is_empty() and panel._selector.is_valid(),
		"two-choice Event ignores physical key 3")
	await _key(KEY_2)
	_check(committed == [{"event_id": "quiet_spool", "choice_id": "ignore"}],
		"two-choice second tag commits the authored second option")
	panel.close_event()
	await _frames()
	_check(randi() == expected_rng, "numbered legacy keys and tags consume zero RNG")


## AC2: with the real Quilting Bee at 0 gold / 2 scraps, tag 2 is an
## unaffordable ticket that spends nothing, tag 1 claims sew_panel exactly once
## with the exact detached after-wallet, and hidden, repeated and stale
## generation keys can never emit again or draw from the RNG.
func _test_wallet_numbered_keys() -> void:
	var bee: Dictionary = authored.get("quilting_bee", {})
	_check(not bee.is_empty(), "numbered wallet fixture is the authored Quilting Bee")
	if bee.is_empty():
		return
	var wallet := {"gold": 0, "scraps": 2}
	var original := wallet.duplicate(true)
	wallet_committed.clear()
	committed.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 515253
	var rng_state := rng.state
	seed(515253)
	var next_global := randi()
	seed(515253)
	_check(panel.open_event_with_wallet(bee, wallet), "numbered wallet bee opens at 0 gold / 2 scraps")
	await _frames()
	_check_numbered_cues(bee, "numbered wallet bee")
	var buttons := panel.get_choice_buttons()
	var sew := _wallet_index(bee, "sew_panel")
	var buy := _wallet_index(bee, "buy_thread")
	var watch := _wallet_index(bee, "watch")
	_check(sew == 0 and buy == 1 and watch == 2,
		"authored Quilting Bee order is 1 sew, 2 buy, 3 watch")
	if buttons.size() != 3 or sew < 0 or buy < 0 or watch < 0:
		panel.close_event()
		await _frames()
		return
	_check(buttons[buy].disabled and buttons[buy].focus_mode == Control.FOCUS_NONE,
		"numbered tag 2 sits on a really unaffordable ticket")
	await _key(KEY_2)
	_check(wallet_committed.is_empty() and panel._selector.is_valid(),
		"unaffordable numbered option cannot claim the visit")
	_check(wallet == original and rng.state == rng_state,
		"refused numbered purchase spends no wallet or RNG")
	# A hidden panel is inert even though the visit is still open and unspent.
	panel.hide()
	await _frames()
	_check(not panel.is_visible_in_tree() and panel.has_open_event() and panel._selector.is_valid(),
		"hidden numbered visit is really open, unspent and invisible")
	await _key(KEY_1)
	_check(wallet_committed.is_empty() and panel._selector.is_valid(),
		"hidden panel ignores numbered keys")
	panel.show()
	await _frames()
	await _key(KEY_1)
	_check(wallet_committed.size() == 1 and wallet_committed[0] == {
		"ok": true, "event_id": "quilting_bee", "choice_id": "sew_panel",
		"wallet": {"gold": 32, "scraps": 0}},
		"physical key 1 settles the first authored option with its exact after-wallet")
	_check(wallet == original, "numbered settlement never mutates the supplied wallet")
	(wallet_committed[0]["wallet"] as Dictionary)["gold"] = -5
	_check(panel._committed_choice == {"ok": true, "event_id": "quilting_bee",
		"choice_id": "sew_panel", "wallet": {"gold": 32, "scraps": 0}},
		"numbered receipt is detached from the panel's own record")
	await _key(KEY_1)
	await _key(KEY_2)
	await _key(KEY_3)
	_check(wallet_committed.size() == 1 and committed.is_empty(),
		"repeated numbered keys cannot settle twice")
	var old_callable: Callable = buttons[0].pressed.get_connections()[0]["callable"]
	var old_selector := panel._selector
	var old_generation := panel._generation
	panel.close_event()
	_check(is_instance_valid(buttons[0]) and not panel.has_open_event(),
		"closed numbered visit is still holding its released ticket")
	old_callable.call()
	_check(wallet_committed.size() == 1, "closed ticket's saved callback cannot emit again")
	await _frames()
	_check(not is_instance_valid(buttons[0]), "closed numbered tickets are really gone")
	_check(panel.open_event_with_wallet(bee, original), "numbered bee reopens after a claim")
	await _frames()
	var reopened_selector := panel._selector
	var reopened_buttons := panel.get_choice_buttons()
	_check(reopened_buttons.size() == 3 and not reopened_buttons[0].disabled,
		"reopened numbered tickets are fresh and selectable")
	if reopened_buttons.size() == 3:
		panel._on_choice_pressed(old_selector, "sew_panel", old_generation, reopened_buttons[0])
	_check(wallet_committed.size() == 1 and reopened_selector.is_valid()
		and not reopened_selector.is_claimed(),
		"old-generation callbacks stay inert on the reopened panel")
	await _key(KEY_3)
	_check(wallet_committed.size() == 2 and wallet_committed[1] == {
		"ok": true, "event_id": "quilting_bee", "choice_id": "watch",
		"wallet": {"gold": 0, "scraps": 3}},
		"reopened panel answers key 3 with its fresh authored third option")
	_check(wallet == original, "reopened numbered keys still leave the caller wallet alone")
	_check(rng.state == rng_state and randi() == next_global,
		"numbered wallet keys and reopen consume zero RNG")
	panel.close_event()
	await _frames()


## AC3: closing and reopening a legacy and a wallet offering really rebuilds the
## sewn tags and the balance caption in the display face, with the body-face
## story and exact captions intact, and without changing guarded input or RNG.
func _test_cue_font_reopen() -> void:
	var spool: Dictionary = authored.get("quiet_spool", {})
	var bee: Dictionary = authored.get("quilting_bee", {})
	_check(not spool.is_empty() and not bee.is_empty(), "font reopen fixtures are authored Events")
	if spool.is_empty() or bee.is_empty():
		return
	seed(313131)
	var expected_rng := randi()
	seed(313131)
	var legacy_fonts: Array[String] = []
	var legacy_captions: Array[String] = []
	for attempt in range(2):
		committed.clear()
		_check(panel.open_event(spool), "legacy font reopen opens #" + str(attempt))
		if not panel.has_open_event():
			return
		await _frames()
		_check_numbered_cues(spool, "legacy font reopen #" + str(attempt))
		var fonts: Array[String] = []
		var captions: Array[String] = []
		for cue in panel.get_choice_cues():
			var cue_font := cue.get_theme_font("font") as Font
			fonts.append(cue_font.resource_path if cue_font != null else "")
		for button in panel.get_choice_buttons():
			captions.append(button.text)
		legacy_fonts.append("|".join(fonts))
		legacy_captions.append("|".join(captions))
		panel.close_event()
		await _frames()
		_check(panel.get_choice_cues().is_empty() and panel.get_choice_buttons().is_empty(),
			"close releases the reopened legacy tags #" + str(attempt))
	_check(legacy_fonts.size() == 2 and legacy_fonts[0] == legacy_fonts[1]
		and legacy_fonts[0] == HEADING_FONT + "|" + HEADING_FONT,
		"legacy reopen recreates every tag in the Londrina display face")
	_check(legacy_captions.size() == 2 and legacy_captions[0] == legacy_captions[1]
		and not legacy_captions.is_empty(),
		"legacy reopen rebuilds identical body-face tickets")
	var wallets: Array = [{"gold": 0, "scraps": 2}, {"gold": 15, "scraps": 0}]
	var wallet_captions: Array[String] = []
	var wallet_fonts: Array[String] = []
	for wallet in wallets:
		wallet_committed.clear()
		committed.clear()
		_check(panel.open_event_with_wallet(bee, wallet), "wallet font reopen opens at " + str(wallet))
		if not panel.has_open_event():
			return
		await _frames()
		_check_wallet_layout(bee, wallet, "wallet font reopen " + str(wallet))
		_check_numbered_cues(bee, "wallet font reopen " + str(wallet))
		var balance := panel.choices_container.get_parent().get_node_or_null("WalletBalance") as Label
		_check(balance != null, "wallet font reopen mounts its balance caption " + str(wallet))
		if balance == null:
			panel.close_event()
			await _frames()
			continue
		var balance_font := balance.get_theme_font("font") as Font
		wallet_fonts.append(balance_font.resource_path if balance_font != null else "")
		wallet_captions.append(balance.text)
		_check(balance.text == "Wallet  •  %d gold   /   %d scraps" % [wallet["gold"], wallet["scraps"]],
			"reopened balance caption states the exact supplied balances " + str(wallet))
		panel.close_event()
		await _frames()
		_check(panel.choices_container.get_parent().get_node_or_null("WalletBalance") == null,
			"close releases the reopened balance caption " + str(wallet))
	_check(wallet_fonts.size() == 2 and wallet_fonts[0] == HEADING_FONT and wallet_fonts[1] == HEADING_FONT,
		"both reopened wallet captions are sewn in the Londrina display face")
	_check(wallet_captions.size() == 2 and wallet_captions[0] != wallet_captions[1],
		"wallet reopen refreshes the caption to each supplied balance")
	_check(randi() == expected_rng, "font reopen and close consume zero RNG")


## Mounted surface contract for both shipped fabric and opaque missing-art paper.
func _check_paper_skin(label: String, fallback: bool = false) -> void:
	_check(panel.find_children("PaperPanel", "PanelContainer", true, false).size() == 1,
		label + " exactly one existing paper surface")
	_check(panel.paper_panel.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR,
		label + " fabric uses linear filtering")
	var style := panel.paper_panel.get_theme_stylebox("panel")
	if not fallback and ResourceLoader.exists(PANEL_ART, "Texture2D"):
		_check(style is StyleBoxTexture, label + " shipped paper uses nine-sliced fabric")
		if style is StyleBoxTexture:
			_check(style.texture != null and style.texture.resource_path == PANEL_ART,
				label + " uses existing reward panel texture")
			_check(style.draw_center, label + " fabric fills the story surface")
			for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
				_check(style.get_texture_margin(side) == 36.0,
					label + " preserves sewn texture edge " + str(side))
	else:
		_check(style is StyleBoxFlat, label + " missing fabric retains flat paper")
		if style is StyleBoxFlat:
			_check(style.bg_color == Color("#e5d5b5") and style.bg_color.a == 1.0
				and style.draw_center, label + " fallback paper is opaque")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		_check(style.get_content_margin(side) == 5.0,
			label + " preserves original paper content inset " + str(side))


## AC1/AC3: missing paper and backdrop art preserve a genuine three-choice
## wallet offering. The inert picture settles nothing; flat-paper pointer input
## settles once, and close/reopen plus art restoration preserve layout and wallet.
func _test_backdrop_fallback() -> void:
	var record: Dictionary = authored.get("frayed_signpost", {})
	_check(not record.is_empty(), "backdrop fallback fixture is a genuine authored Event")
	if record.is_empty():
		return
	seed(918273)
	var expected_rng := randi()
	seed(918273)
	var wallet := {"gold": 6, "scraps": 1}
	var original_wallet := wallet.duplicate(true)
	wallet_committed.clear()
	committed.clear()
	_check(panel.open_event_with_wallet(record, wallet), "wallet Event opens for the art fallback probe")
	await _frames()
	_check_backdrop_layer("wallet art probe")
	var before: Array[String] = []
	for button in panel.get_choice_buttons():
		before.append(button.text)
	var selector := panel._selector
	var paper := panel.paper_panel
	var paper_rect := paper.get_global_rect()
	panel.bind_event_paper("res://assets/paper/ui/event_panel_missing_test.png")
	await _frames()
	_check_paper_skin("mounted missing fabric", true)
	_check(panel.paper_panel == paper and paper.get_global_rect() == paper_rect,
		"missing fabric reuses the same panel and natural layout")
	panel.bind_event_backdrop("res://assets/paper/backgrounds/event_crossroads_missing_test.png")
	await _frames()
	var backdrop := panel.get_node("EventBackdrop") as TextureRect
	_check(backdrop.texture == null and not backdrop.visible,
		"unavailable optional art hides the picture and keeps the plain slate")
	_check(panel.get_node("SlateBackdrop").is_visible_in_tree(),
		"unavailable optional art leaves the opaque slate as the ground")
	var after: Array[String] = []
	for button in panel.get_choice_buttons():
		after.append(button.text)
	_check(after == before and panel._selector == selector and selector.is_valid()
		and not selector.is_claimed(), "art fallback probe changes no ticket and no offering")
	# A real pointer press away from the parchment must never land on the picture.
	var corner := Vector2(4, 4)
	var motion := InputEventMouseMotion.new()
	motion.position = corner
	root.push_input(motion, true)
	await _frames()
	_check(root.gui_get_hovered_control() != backdrop,
		"pointer over the art never lands on the inert picture layer")
	for state in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = corner
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = state
		root.push_input(click, true)
	await _frames()
	_check(wallet_committed.is_empty() and selector.is_valid() and not selector.is_claimed(),
		"clicking the picture layer settles nothing")
	_check(wallet == original_wallet, "art probe never touches the supplied wallet")
	# Commit while the flat paper is mounted, through actual pointer input.
	var fallback_buttons := panel.get_choice_buttons()
	_check(fallback_buttons.size() == 3 and not fallback_buttons[0].disabled,
		"flat paper keeps three live choices")
	if fallback_buttons.size() == 3 and not fallback_buttons[0].disabled:
		await _mouse(fallback_buttons[0])
		await _mouse(fallback_buttons[0])
	_check(wallet_committed.size() == 1 and wallet_committed[0] == {
		"ok": true, "event_id": "frayed_signpost", "choice_id": "read",
		"wallet": {"gold": 16, "scraps": 0}}, "flat paper mouse choice commits exactly once")
	panel.close_event()
	await _frames()
	_check(panel.open_event_with_wallet(record, wallet), "flat paper Event reopens")
	await _frames()
	_check_paper_skin("reopened flat paper", true)
	_check(wallet_committed.size() == 1 and wallet == original_wallet,
		"close/reopen adds no wallet side effect")
	wallet_committed.clear()
	panel.bind_event_paper()
	panel.bind_event_backdrop()
	await _frames()
	_check_paper_skin("restored sewn paper")
	_check(panel.paper_panel == paper and paper.get_global_rect() == paper_rect,
		"restore and reopen reuse the same paper with unchanged layout")
	_check((backdrop.texture != null) == ResourceLoader.exists(EVENT_ART)
		and backdrop.visible == (backdrop.texture != null),
		"committed crossroads scene restores after the fallback probe")
	var buttons := panel.get_choice_buttons()
	_check(buttons.size() == 3 and not buttons[0].disabled,
		"restored offering keeps its three reachable authored tickets")
	if buttons.size() == 3 and not buttons[0].disabled:
		buttons[0].pressed.emit()
	_check(wallet_committed.size() == 1 and wallet_committed[0] == {
		"ok": true, "event_id": "frayed_signpost", "choice_id": "read",
		"wallet": {"gold": 16, "scraps": 0}},
		"restored offering still settles its first authored choice exactly once")
	_check(wallet == original_wallet, "art restore never spends the supplied wallet")
	_check(randi() == expected_rng, "art binding, fallback and restore consume no RNG")
	panel.close_event()
	await _frames()


func _test_needle_carryover() -> void:
	var party := CombatParty.new([
		{"id": "warden", "max_hp": 40}, {"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26}])
	var carry := RunTornCarryover.new(party.get_heroes())
	var enemies := CombatEnemies.new([{"id": "dummy", "max_hp": 1}])
	var result := CombatBattleResult.new(party, enemies)
	_check(carry.begin_battle("before_toll", result, party), "real carryover admits the pre-toll battle")
	party.apply_damage(2, 30)
	enemies.apply_damage(1, 1)
	_check(result.evaluate() == CombatBattleResult.VICTORY, "pre-toll battle actually ends with a torn ally")
	_check(carry.commit_victory("before_toll", result, party).ok
		and carry.apply_reward("before_toll", result, party).ok, "battle and reward publish the genuine tear")
	_check(carry.choose_rest_heal("before_toll_rest").ok, "real rest revives torn hero before toll")
	var ledger := carry.torn.read_state()
	_check(ledger.tear_counts.seamstress == 1 and ledger.heroes[1].max_hp == 27
		and ledger.heroes[1].hp >= 7, "toll starts from a genuinely reduced cap and nonempty tear history")
	var rng := RandomNumberGenerator.new()
	rng.seed = 245
	var toll := RunNeedleToll.new({"heroes": carry.read_state().heroes,
		"wallet": {"gold": 0, "scraps": 0}, "deck": ["warden_strike"]}, rng)
	var paid := toll.pay_toll("seamstress")
	_check(paid.ok and carry.apply_needle_toll(toll, carry.read_state()), "paid toll commits through carryover")
	ledger.heroes = paid.heroes
	_check(carry.torn.read_state() == ledger and carry.read_state().heroes == paid.heroes,
		"toll preserves the genuine tear, reduced max HP, battle and rest history")
	var before := carry.read_state()
	var state: int = rng.state
	_check(not carry.apply_needle_toll(toll, before) and carry.read_state() == before
		and carry.torn.read_state() == ledger and rng.state == state, "replayed carryover payment is inert")
	_check(carry.create_next_fight_party() != null and carry.choose_rest_heal("after_toll_rest").ok
		and carry.create_next_fight_party() != null, "later rest and fight hydration replay toll history successfully")


func _test_needle_toll() -> void:
	var heroes: Array = CombatParty.new([
		{"id": "warden", "max_hp": 40}, {"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26}]).get_heroes()
	heroes[0].hp = 6
	heroes[1].hp = 0
	heroes[2].hp = 7
	var context := {"heroes": heroes, "wallet": {"gold": 0, "scraps": 0},
		"deck": ["warden_strike"]}
	var rng := RandomNumberGenerator.new()
	rng.seed = 245
	var outcome := RunNeedleToll.new(context, rng)
	var state: int = rng.state
	_check(outcome.is_open() and panel.open_needle_toll(outcome), "real toll contract mounts")
	await _frames()
	_check(panel.needle_payer != null and panel.needle_payer.item_count == 1
		and panel.needle_payer.get_item_metadata(0) == "tinker",
		"only the living hero at the exact 7 HP boundary is presented")
	_check(panel.get_choice_buttons()[1].text == outcome.get_event().choices[1].text,
		"safe exit keeps the authored +1 scrap wording")
	var old: Callable = panel.get_choice_buttons()[0].pressed.get_connections()[0].callable
	var count := committed.size()
	panel.hide()
	await _key(KEY_1)
	old.call()
	_check(committed.size() == count and rng.state == state and outcome.is_open(),
		"hidden payment changes neither rules nor RNG")
	panel.show()
	panel.needle_payer.grab_focus()
	await _key(KEY_TAB)
	_check(panel.get_choice_buttons()[0].has_focus(), "Tab reaches pay from the eligible payer")
	await _key(KEY_TAB)
	_check(panel.get_choice_buttons()[1].has_focus(), "Tab reaches authored safe exit")
	await _key(KEY_SPACE)
	_check(committed.size() == count + 1 and committed.back().choice_id == "safe_exit"
		and outcome.is_open() and rng.state == state and context.heroes == heroes,
		"keyboard safe exit emits presentation intent without spending caller state")
	panel.close_event()
	_check(panel.needle_payer == null and panel.get_choice_buttons().is_empty(), "close clears payer and choices")
	_check(panel.open_needle_toll(outcome), "uncommitted rules can be presented again")
	old.call()
	_check(not panel._selector.is_claimed(), "old generation cannot commit reopened toll")
	panel.close_event()
	var paid := outcome.pay_toll("tinker")
	_check(paid.ok and paid.heroes[2].hp == 1 and paid.offered_ids.size() == 2,
		"boundary payer pays exactly six and supplies two real rare cards")
	_check(panel.open_needle_toll(outcome), "paid rare offers mount")
	await _frames()
	_check(panel.needle_payer == null and panel.get_choice_buttons().size() == 3,
		"paid offering has two cards and Skip without stale payer")
	for index in range(2):
		_check(panel._bound_choices[panel.get_choice_buttons()[index]] == paid.offered_ids[index]
			and panel.get_choice_buttons()[index].text.contains("rare")
			and Rect2(0, 0, 1280, 720).encloses(panel.get_choice_buttons()[index].get_global_rect()),
			"rare offer identity is bound to a visible control that fits")
	await _mouse(panel.get_choice_buttons()[1])
	_check(committed.back().choice_id == paid.offered_ids[1] and outcome.is_paid(),
		"mouse chooses exactly the second offered card without mutating rules")
	panel.close_event()
	_check(panel.open_needle_toll(outcome), "paid offering reopens for Skip keyboard check")
	await _frames()
	await _key(KEY_3)
	_check(committed.back().choice_id == "skip", "physical third key reaches Skip")
	panel.close_event()
	heroes[2].hp = 6
	var denied := RunNeedleToll.new(context, rng)
	_check(denied.is_open() and panel.open_needle_toll(denied), "all-ineligible party still mounts safe exit")
	await _frames()
	_check(panel.needle_payer.item_count == 0 and panel.needle_payer.disabled
		and panel.get_choice_buttons()[0].disabled and panel.get_choice_buttons()[1].has_focus(),
		"no ineligible payer is shown and safe exit remains focused")
	count = committed.size()
	state = rng.state
	await _key(KEY_1)
	await _mouse(panel.get_choice_buttons()[0])
	_check(committed.size() == count and rng.state == state, "ineligible pay mouse and key consume nothing")
	panel.close_event()
	_check(denied.is_open() and rng.state == state, "abandoning the open view consumes no rules or RNG")


func _test_fate_pin_auction() -> void:
	var heroes := CombatParty.new([{"id": "warden", "max_hp": 40}, {"id": "seamstress", "max_hp": 30}, {"id": "tinker", "max_hp": 26}]).get_heroes()
	heroes[0].hp = 4
	heroes[1].hp = 5
	var w := RunPatchWardrobe.new(heroes, [], RunAuthoredPatchDefinitions.load_definitions(), 0, 65, [], 343, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 343
	var outcome := RunFatePinAuction.new(w, rng)
	var before := w.get_snapshot()
	var before_rng := rng.state
	_check(outcome.is_valid() and panel.open_fate_pin_auction(outcome), "auction mounts on actual Event parchment")
	await _frames()
	var picker := panel.auction_payer
	_check(is_instance_valid(picker) and picker.item_count == 2 and picker.get_item_metadata(0) == "seamstress", "living HP >=5 payer choices")
	_check(panel.get_choice_buttons().size() == 3 and panel.get_choice_cues().size() == 3, "two power tickets and safe exit")
	_check(panel.get_choice_buttons()[0].text.contains("-4 HP, -65 gold") \
		and panel.get_choice_buttons()[0].tooltip_text.contains("+1 scrap"), "exact payment and displacement copy")
	for button in panel.get_choice_buttons():
		_check(button.get_global_rect().position.y >= 0 and button.get_global_rect().end.y <= 720, "auction actions fit viewport")
	var count := committed.size()
	await _key(KEY_2)
	_check(committed.size() == count + 1 and committed.back() == {"event_id": "fate_pin_auction", "choice_id": "patch_1"}, "number key emits selected patch identity")
	var receipt := outcome.prepare(w, "patch_1", picker.get_item_metadata(picker.selected), outcome.get_offers()[1].slot, before)
	_check(receipt.ok and receipt.state.heroes[1].hp == 1 and receipt.state.gold == 0, "mounted selected payer yields exact receipt")
	await _key(KEY_3)
	_check(committed.size() == count + 1 and w.get_snapshot() == before and rng.state == before_rng, "panel commits one intent without mutating rules")
	var old := panel.get_choice_buttons()[0]
	panel.close_event()
	old.pressed.emit()
	_check(committed.size() == count + 1 and panel.auction_payer == null, "closed auction controls inert and payer removed")
	_check(panel.open_fate_pin_auction(outcome), "reopen detached unclaimed service")
	await _frames()
	await _mouse(panel.get_choice_buttons()[2])
	_check(committed.back().choice_id == "safe_exit", "mouse safe exit mounted")
	panel.close_event()
	var poor := RunPatchWardrobe.new(heroes, [], RunAuthoredPatchDefinitions.load_definitions(), 0, 64, [], 343, true)
	_check(panel.open_fate_pin_auction(RunFatePinAuction.new(poor, rng)), "poor player still sees safe auction")
	_check(panel.get_choice_buttons()[0].disabled and panel.get_choice_buttons()[1].disabled \
		and not panel.get_choice_buttons()[2].disabled, "unaffordable paid choices disabled; safe enabled")
	panel.close_event()


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
	await _test_fate_pin_auction()
	_check(panel.has_method("open_event") and panel.has_method("close_event"),
		"required public lifecycle methods exist")
	_read_authored()
	await _test_authored_tooltips()
	await _test_malformed_tooltips()
	await _test_wallet_malformed_tooltips()
	await _test_authored()
	await _test_three_choice_and_identity()
	await _test_fallback_tickets()
	_check(panel.open_event(authored["frayed_signpost"]), "art state offering opens")
	await _frames()
	await _check_ticket_input_states()
	panel.close_event()
	await _frames()
	await _test_frayed_new_button()
	await _test_invalid_and_replay()
	_test_rng_zero_draws()
	await _test_wallet_authored()
	await _test_wallet_reopen_refresh()
	await _test_wallet_keyboard()
	await _test_numbered_choice_keys()
	await _test_wallet_numbered_keys()
	await _test_cue_font_reopen()
	await _test_backdrop_fallback()
	await _test_wallet_rejection_and_generation()
	await _test_needle_toll()
	_test_needle_carryover()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_event_choice_panel_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	if is_instance_valid(panel):
		panel.free()
	quit(0 if failures.is_empty() else 1)
