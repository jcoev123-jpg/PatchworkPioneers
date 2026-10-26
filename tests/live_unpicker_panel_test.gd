extends SceneTree
## Mounted, independent Unpicker view test; the controller alone applies receipts.

const NODE := "unpicker-panel-route-265"
const STRIKE := "warden_strike"
const PRICK := "seamstress_prick"
const POP := "tinker_pop_shot"
## A genuine reward-pool base card and a genuine authored starter upgrade.
const POOL := "warden_pinning_jab"
const UPGRADED := "warden_strike_plus"
var failures: Array[String] = []
var checks := 0
var intents: Array[Dictionary] = []
var panel: LiveUnpickerPanel

class Controller:
	static func apply(visit: RunUnpickerVisit, intent: Dictionary) -> Dictionary:
		if visit == null or not visit.is_valid() or visit.is_consumed():
			return {"ok": false}
		var source: Variant = intent.get("expected_snapshot")
		if typeof(source) != TYPE_DICTIONARY or visit.read_state() != source \
				or intent.get("visit_id") != source.get("visit_id") \
				or intent.get("node_id") != source.get("node_id"):
			return {"ok": false}
		match intent.get("action"):
			"remove_card":
				var id: Variant = intent.get("selected_card_id")
				if typeof(id) != TYPE_STRING or not source["deck"].has(id):
					return {"ok": false}
				return visit.remove_card(id, intent["visit_id"], intent["node_id"], source)
			"leave":
				if intent.has("selected_card_id"):
					return {"ok": false}
				return visit.leave(intent["visit_id"], intent["node_id"], source)
		return {"ok": false}


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _settle() -> void:
	for i in range(4):
		await process_frame


func _deck() -> Array[String]:
	var deck := StarterCards.new().get_starting_deck()
	_check(deck.size() > 4 and deck.count(STRIKE) >= 2 and deck.has(PRICK) and deck.has(POP),
			"genuine authored deck contains duplicate and cross-owner cards")
	return deck


func _make(gold: int = 175, prior: int = 0, deck: Array = [],
		descriptors: Dictionary = {}, cursor: int = 1) -> RunUnpickerVisit:
	if deck.is_empty():
		deck = _deck()
	return RunUnpickerVisit.new(NODE, deck, gold, prior, descriptors, cursor)


func _bind(visit: RunUnpickerVisit) -> void:
	intents.clear()
	panel.bind(visit)
	await _settle()


func _activate(button: Button, keyboard: bool, key: Key = KEY_ENTER) -> void:
	_check(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled,
			"real enabled mounted Button prerequisite")
	if button == null or button.disabled or not button.is_visible_in_tree():
		return
	if keyboard:
		button.grab_focus()
		_check(button.has_focus(), "focused keyboard activation target")
		for down in [true, false]:
			var event := InputEventKey.new()
			event.keycode = key
			event.pressed = down
			root.push_input(event)
			await process_frame
	else:
		var point := button.get_global_rect().get_center()
		# This test clicks a physically visible choice, never a synthesized signal.
		_check(Rect2(Vector2.ZERO, Vector2(root.size)).has_point(point),
				"mouse target lies in the physical viewport")
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
	await _settle()


## Independent catalog-derived oracle for the ordinary-card tooltip, mirroring
## only the presentation contract: owner/name, printed cost, legal slots and the
## exact CardShortRules sentence. It never reads the mounted button's text.
func _expected_tooltip(definition: Dictionary) -> String:
	var named := str(definition.get("display_name", ""))
	var owner := str(definition.get("owner", "")).capitalize()
	var title := (owner + " " + named) if not owner.is_empty() else named
	var lines: Array[String] = ["%s • %d energy" % [title, int(definition.get("cost", -1))]]
	var movement := _movement(definition)
	if not movement.is_empty():
		lines.append(movement)
	var rule := CardShortRules.line(definition)
	if not rule.is_empty():
		lines.append(rule)
	return "\n".join(lines)


func _movement(definition: Dictionary) -> String:
	var parts: Array[String] = []
	var from_text := _slots(definition.get("from_positions"))
	if not from_text.is_empty():
		parts.append("From " + from_text)
	var to_text := _slots(definition.get("to_positions"))
	if not to_text.is_empty():
		parts.append("To " + to_text)
	return " • ".join(parts)


func _slots(value: Variant) -> String:
	if not value is Array:
		return ""
	var parts: Array[String] = []
	for slot in value:
		parts.append(str(slot))
	return ", ".join(parts)


func _half_line(order: String, definition: Dictionary) -> String:
	var named := str(definition.get("display_name", ""))
	var owner := str(definition.get("owner", "")).capitalize()
	var title := (owner + " " + named) if not owner.is_empty() else named
	var parts: Array[String] = ["%s — %s" % [order, title],
		"%d energy" % int(definition.get("cost", -1))]
	var movement := _movement(definition)
	if not movement.is_empty():
		parts.append(movement)
	return " • ".join(parts)


## Independent oracle for a genuine stitched card: descriptor name and cost,
## then both authored half_ids in order with owner, cost, slots and rule line.
func _expected_stitched_tooltip(descriptor: Dictionary, first: Dictionary,
		second: Dictionary) -> String:
	var owners: Array[String] = []
	for half in [first, second]:
		owners.append(str(half.get("owner", "")).capitalize())
	var title := " / ".join(owners)
	var named := str(descriptor.get("display_name", ""))
	if not named.is_empty():
		title += (" — " if not title.is_empty() else "") + named
	var cost: int = mini(3, maxi(int(first.get("cost", -1)), int(second.get("cost", -1))) + 1)
	return "\n".join([
		"Stitched card • %d energy (higher half cost + 1, capped at 3)" % cost,
		title,
		_half_line("FIRST", first),
		CardShortRules.line(first),
		_half_line("SECOND", second),
		CardShortRules.line(second),
		"Both owners must be alive and in their own FROM slots to play it. " \
				+ "It cannot be stitched again or upgraded. " \
				+ "Inspection only: Remove retires it without playing it.",
	])


func _unique_ids(deck: Array) -> Array[String]:
	var result: Array[String] = []
	for id in deck:
		if not result.has(id):
			result.append(id)
	return result


func _run() -> void:
	root.size = Vector2i(1280, 720)
	panel = LiveUnpickerPanel.new()
	panel.position = Vector2(200, 60)
	panel.bind(_make())
	root.add_child(panel)
	panel.decision_requested.connect(func(intent: Dictionary): intents.append(intent))
	await _settle()
	_check(not panel.card_buttons.is_empty() and panel.card_buttons[0].has_focus(),
			"pre-mount authenticated bind starts with focused card choice")
	seed(265)
	var global_next := randi()
	seed(265)
	await _test_layout()
	await _test_card_tooltips()
	for keyboard in [false, true]:
		await _test_remove(keyboard)
		await _test_leave(keyboard, 74)
	await _test_price_boundaries()
	await _test_stitched()
	await _test_rejections()
	_check(randi() == global_next, "mounting completed before guard; all browsing/decisions preserve global RNG")
	panel.queue_free()
	await process_frame
	for failure in failures:
		printerr(failure)
	print("live_unpicker_panel_test: ", "PASS" if failures.is_empty() else "FAIL",
			" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _test_layout() -> void:
	var visit := _make(250, 2)
	await _bind(visit)
	var source := visit.read_state()
	var quote := visit.quote()
	_check(visit.is_valid() and not visit.is_consumed() and quote.ok
			and quote.price == 125, "authentic and nonempty source, third gold quote")
	_check(panel.title_label.text.contains("UNPICKER")
			and panel.wallet_label.text.contains("250 gold")
			and panel.wallet_label.text.contains("125 gold"), "readable source-bound wallet and 75+25 per prior")
	_check(panel.title_label.get_theme_font_size("font_size") >= 26
			and panel.wallet_label.get_theme_font_size("font_size") >= 20,
			"sewn title and wallet readable at real font sizes")
	_check(panel.get_child(0) is Panel
			and panel.remove_button.get_theme_stylebox("normal") != null
			and panel.remove_button.get_theme_stylebox("focus") != null,
			"panel and selectable controls use explicitly styled sewn fabric/felt")
	var viewport := Rect2(Vector2.ZERO, Vector2(1280, 720))
	for control in [panel, panel.title_label, panel.wallet_label, panel.status_label,
			panel.choice_scroll, panel.remove_button, panel.leave_button]:
		_check(viewport.encloses(control.get_global_rect()), "stitched panel and fixed actions fit 1280x720")
	_check(not panel.choice_scroll.get_global_rect().intersects(panel.remove_button.get_global_rect())
			and not panel.choice_scroll.get_global_rect().intersects(panel.leave_button.get_global_rect()),
			"bounded scroll never clips footer Remove/Leave")
	_check(panel.remove_button.disabled and not panel.leave_button.disabled,
			"only two distinct actions, selection required for Remove")
	_check(panel.status_label.text == "Choose one card, then Remove it once. Or Leave.",
			"unselected visit keeps the original choose-card hint")
	_check(panel.status_label.get_global_rect().end.y <= panel.choice_scroll.get_global_rect().position.y,
			"reserved forecast band sits above the card rows")
	var unique: Array[String] = []
	for id in source.deck:
		if not unique.has(id):
			unique.append(id)
	_check(unique.size() > 4 and panel.card_buttons.size() == unique.size(),
			"canonical first-occurrence choices, never duplicate tiles")
	for i in range(unique.size()):
		var id: String = unique[i]
		var first: int = source.deck.find(id)
		var definition := RunRestStitchCards.resolve_card_definition(id)
		_check(not definition.is_empty(), "authentic definition resolves for mounted row " + id)
		if not definition.is_empty():
			var rule := CardShortRules.line(definition)
			_check(not rule.is_empty() and panel.card_buttons[i].tooltip_text == _expected_tooltip(definition),
					"row tooltip is the exact authored owner/name/cost/slots/rule for " + id)
			_check(panel.card_buttons[i].tooltip_text == LiveUnpickerPanel.card_tooltip(source, id),
					"public tooltip formatter is source-detached and matches the mounted row for " + id)
		var expected_name := str(definition.get("display_name", ""))
		var expected_owner := str(definition.get("owner", "")).capitalize()
		_check(not expected_name.is_empty() and panel.card_buttons[i].text.contains(expected_name)
				and (expected_owner.is_empty() or panel.card_buttons[i].text.contains(expected_owner))
				and panel.card_buttons[i].text.contains("%02d" % (first + 1)),
				"first source position and independently resolved authored name and readable owner for " + id)
		_check(panel.card_buttons[i].focus_mode == Control.FOCUS_ALL,
				"canonical card row is keyboard reachable")
	_check(panel.choice_scroll.get_v_scroll_bar().max_value > panel.choice_scroll.size.y,
			"nontrivial deck scrolls vertically within fixed viewport")
	panel.card_buttons.back().grab_focus()
	await _settle()
	_check(panel.choice_scroll.scroll_vertical > 0,
			"offscreen canonical last card is revealed by keyboard focus")
	panel.card_buttons[0].grab_focus()
	await _settle()
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	root.push_input(tab)
	await process_frame
	_check(panel.card_buttons[1].has_focus(), "Tab moves to next card without pointer")
	_check(visit.read_state() == source and intents.is_empty(),
			"readability, scroll and keyboard browsing are view-only")


func _test_card_tooltips() -> void:
	var deck := _deck()
	deck.append(POOL)
	deck.append(UPGRADED)
	var visit := _make(150, 0, deck)
	await _bind(visit)
	var source := visit.read_state()
	var unique := _unique_ids(source.deck)
	# Independent prerequisites: the fixture really is genuine pool stock and a
	# genuine upgraded starter card, both already admitted to the visit ledger.
	_check(WardenPoolCards.new().get_base_ids().has(POOL)
			and not RunPoolCardRewardOffers.resolve_reward_definition(POOL).is_empty()
			and source.deck.has(POOL), "genuine reward-pool card fixture prerequisite")
	_check(StarterCards.new().has_card(UPGRADED)
			and int(StarterCards.new().get_definition(UPGRADED).get("starting_copies", -1)) == 0
			and source.deck.has(UPGRADED), "genuine upgraded starter card fixture prerequisite")
	for id in [STRIKE, PRICK, POOL, UPGRADED]:
		var definition := RunRestStitchCards.resolve_card_definition(id)
		var row_index := unique.find(id)
		_check(not definition.is_empty() and source.deck.has(id) and row_index >= 0,
				"independent catalog, deck and canonical-row precondition for " + id)
		if definition.is_empty() or row_index < 0:
			continue
		var rule := CardShortRules.line(definition)
		var tooltip := panel.card_buttons[row_index].tooltip_text
		_check(not rule.is_empty() and tooltip == _expected_tooltip(definition),
				"tooltip derives owner/name/cost/slots and exact CardShortRules line for " + id)
		_check(tooltip.contains(str(definition.get("owner", "")).capitalize())
				and tooltip.contains(str(definition.get("display_name", "")))
				and tooltip.contains("%d energy" % int(definition.get("cost", -1))),
				"tooltip names the same authored owner and card with its true energy cost for " + id)
		var movements := _movement(definition)
		_check(movements.is_empty() or tooltip.contains(movements),
				"tooltip carries the authored FROM/TO slots when applicable for " + id)
		_check(tooltip == LiveUnpickerPanel.card_tooltip(source, id),
				"tooltip is a pure detached projection of the authenticated source for " + id)
	# Hovering the visible row is inspection only: no selection, intent, spend or
	# state change, and affordability stays exactly what the visit quote says.
	var strike_index := unique.find(STRIKE)
	var row: Button = panel.card_buttons[strike_index]
	var strike_tip: String = row.tooltip_text
	var hover := InputEventMouseMotion.new()
	hover.position = row.get_global_rect().get_center()
	_check(Rect2(Vector2.ZERO, Vector2(root.size)).has_point(hover.position),
			"hover target lies in the physical viewport")
	root.push_input(hover)
	await _settle()
	var quote_before := visit.quote()
	_check(row.tooltip_text == strike_tip and not row.text.begins_with("◆")
			and panel.status_label.text == "Choose one card, then Remove it once. Or Leave."
			and panel.remove_button.disabled and not panel.leave_button.disabled
			and intents.is_empty() and visit.read_state() == source
			and visit.quote() == quote_before and not visit.is_consumed(),
			"hovering a card row only exposes its tooltip: no intent, spend or snapshot change")
	# Inspection must not make an unaffordable visit actionable either.
	var broke := _make(74, 0, deck)
	await _bind(broke)
	var broke_source := broke.read_state()
	_check(not panel.card_buttons.is_empty()
			and panel.card_buttons[0].tooltip_text != ""
			and panel.remove_button.disabled and not panel.leave_button.disabled,
			"unaffordable visit keeps inspectable rows while Remove stays disabled")
	root.push_input(hover)
	await _settle()
	_check(intents.is_empty() and broke.read_state() == broke_source
			and int(panel._source["gold"]) < int(panel._source["price"]),
			"inspecting an unaffordable quote cannot enable or mutate a purchase")


func _test_remove(keyboard: bool) -> void:
	var visit := _make(150)
	await _bind(visit)
	var source := visit.read_state()
	_check(source.deck.count(STRIKE) >= 2 and not panel.card_buttons.is_empty(),
			"authentic duplicate selection prerequisite")
	var row: Button = panel.card_buttons[0]
	var id: String = source.deck[0]
	await _activate(row, keyboard, KEY_SPACE if keyboard else KEY_ENTER)
	_check(row.text.begins_with("◆") and not panel.remove_button.disabled
			and panel.card_buttons.filter(func(item): return item.text.begins_with("◆")).size() == 1,
			"exactly one visibly selected canonical row")
	var deck := source["deck"] as Array
	var first := deck.find(id)
	var copies := deck.count(id)
	var expected_price: int = RunShopCardRemoval.BASE_PRICE + RunShopCardRemoval.PRICE_STEP * int(source["prior_removals"])
	var gold := int(source["gold"])
	_check(copies == 2 and first == 0 and row.text.contains("%02d" % (first + 1)),
			"independent starter first-copy and first-position prerequisite")
	_check(panel.status_label.text.contains("Warden Strike")
			and panel.status_label.text.contains("first of %d copies" % copies)
			and panel.status_label.text.contains("deck %d→%d" % [deck.size(), deck.size() - 1])
			and panel.status_label.text.contains("gold %d→%d (%d cost)" % [
					gold, gold - expected_price, expected_price]),
			"compact pre-confirmation preview: authored name, first copy of 2, deck 12→11, 75 quote")
	var projected := LiveUnpickerPanel.forecast(source, id)
	_check(projected.get("card_id") == id and projected.get("first") == first
			and projected.get("copies") == copies and projected.get("deck_before") == deck.size()
			and projected.get("deck_after") == deck.size() - 1
			and projected.get("gold_before") == gold and projected.get("gold_after") == gold - expected_price
			and projected.get("price") == expected_price and projected.get("stitched") == false
			and LiveUnpickerPanel.forecast(source, "") == {},
			"pure source projection matches the independent ledger, not hardcoded UI text")
	_check(visit.read_state() == source and intents.is_empty() and not visit.is_consumed(),
			"forecast is display-only, never a spend or service mutation")
	await _activate(panel.remove_button, keyboard, KEY_ENTER)
	_check(intents.size() == 1 and visit.read_state() == source and not visit.is_consumed(),
			"one detached intent, never a view-side spend")
	if intents.size() != 1:
		return
	var intent := intents[0]
	_check(intent == {"action": "remove_card", "node_id": source.node_id,
			"visit_id": source.visit_id, "expected_snapshot": source, "selected_card_id": id},
			"mouse/keyboard emit identical fully captured source-bound intent")
	var receipt := Controller.apply(visit, intent)
	var expected: Array = source.deck.duplicate()
	expected.remove_at(expected.find(id))
	_check(receipt.get("ok") == true and receipt.action == "remove_card"
			and receipt.removed_card_id == id and receipt.charged_gold == 75
			and receipt.gold == 75 and receipt.prior_removals == 1,
			"controller alone applies exact 75-gold receipt once")
	_check(receipt.deck == expected and receipt.deck.count(id) == source.deck.count(id) - 1
			and receipt.source_snapshot == source and receipt.source_receipt == source.receipt,
			"first matching copy only, complete immutable source proof")
	_check(visit.is_consumed() and receipt.next_stitch_id == source.next_stitch_id,
			"accepted service is single-use and never rewinds cursor")
	var after := visit.read_state()
	_check(Controller.apply(visit, intent).get("ok") == false and visit.read_state() == after,
			"controller refuses replay with no second charge")
	panel.remove_button.pressed.emit()
	panel.leave_button.pressed.emit()
	_check(intents.size() == 1 and visit.read_state() == after, "view also blocks repeated pressed callbacks")
	intent.expected_snapshot.deck.clear()
	_check(visit.read_state() == after, "intent snapshot detached from service")


func _test_leave(keyboard: bool, gold: int) -> void:
	var visit := _make(gold)
	await _bind(visit)
	var source := visit.read_state()
	_check(panel.remove_button.disabled and not panel.leave_button.disabled
			and panel.status_label.text.contains("1 more gold"), "74-gold shortage disables Remove, not Leave")
	await _activate(panel.leave_button, keyboard, KEY_SPACE if keyboard else KEY_ENTER)
	_check(intents.size() == 1 and visit.read_state() == source, "Leave emits before route controller applies")
	if intents.size() != 1:
		return
	var intent := intents[0]
	_check(intent == {"action": "leave", "node_id": source.node_id,
			"visit_id": source.visit_id, "expected_snapshot": source},
			"Leave has exact source binding, without selected card")
	var receipt := Controller.apply(visit, intent)
	_check(receipt.get("ok") == true and receipt.action == "leave" and receipt.charged_gold == 0
			and receipt.deck == source.deck and receipt.gold == gold
			and receipt.prior_removals == source.prior_removals
			and receipt.descriptors == source.descriptors
			and receipt.next_stitch_id == source.next_stitch_id,
			"gold-independent Leave changes no card/currency/stitched ledger")
	var after := visit.read_state()
	_check(Controller.apply(visit, intent).get("ok") == false
			and visit.read_state() == after and visit.is_consumed(), "Leave consumes once without retry rights")


func _test_price_boundaries() -> void:
	for fixture in [{"gold": 74, "prior": 0, "price": 75, "can_remove": false},
			{"gold": 75, "prior": 0, "price": 75, "can_remove": true},
			{"gold": 99, "prior": 1, "price": 100, "can_remove": false},
			{"gold": 100, "prior": 1, "price": 100, "can_remove": true}]:
		var visit := _make(fixture.gold, fixture.prior)
		await _bind(visit)
		var before := visit.read_state()
		var selected_id: String = before.deck[0]
		_check(visit.quote().price == fixture.price
				and panel.wallet_label.text.contains("%d gold" % fixture.price),
				"service-derived price shown at boundary " + str(fixture))
		if not fixture.can_remove:
			panel.card_buttons[0].grab_focus()
			await _settle()
			_check(panel.remove_button.disabled and not panel.leave_button.disabled,
					"focus alone never enables an unaffordable paid action " + str(fixture))
		await _activate(panel.card_buttons[0], false)
		_check(panel.remove_button.disabled != fixture.can_remove
				and not panel.leave_button.disabled,
				"affordability and free Leave at boundary " + str(fixture))
		if not fixture.can_remove:
			_check(panel.status_label.text.contains("Need %d more gold" % (fixture.price - fixture.gold)),
					"unaffordable quote still shows shortfall despite selection")
		else:
			_check(panel.status_label.text.contains("first of %d %s" % [
							before.deck.count(selected_id), "copy" if before.deck.count(selected_id) == 1 else "copies"])
					and panel.status_label.text.contains("gold %d→%d (%d cost)" % [
							fixture.gold, fixture.gold - fixture.price, fixture.price]),
					"preview quotes the escalating service price, never a hardcoded 75 " + str(fixture))
		if fixture.can_remove:
			await _activate(panel.remove_button, false)
			_check(intents.size() == 1, "affordable 75/100 sends one intent")
			if intents.size() == 1:
				var result := Controller.apply(visit, intents[0])
				_check(result.get("ok") == true and result.charged_gold == fixture.price
						and result.gold == fixture.gold - fixture.price,
						"controller charges exact boundary quote")
		else:
			panel.remove_button.pressed.emit()
			_check(intents.is_empty() and visit.read_state() == before,
					"insufficient gold cannot forge a paid request")


func _stitched_fixture() -> Dictionary:
	var deck := _deck()
	var circle := RunRestStitchCards.new(deck, {}, 3, 1)
	_check(circle.is_valid(), "genuine Rest stitch authority")
	if not circle.is_valid():
		return {}
	var stitched := circle.choose_stitch(deck.find(PRICK), deck.find(POP), circle.get_snapshot())
	_check(stitched.get("ok") == true and stitched.descriptors.has(stitched.stitched_id),
			"authentically stitched composite with descriptor")
	return stitched if stitched.get("ok") == true else {}


func _test_stitched() -> void:
	var fixture := _stitched_fixture()
	if fixture.is_empty():
		return
	var visit := _make(100, 0, fixture.deck, fixture.descriptors, fixture.next_stitch_id)
	await _bind(visit)
	var source := visit.read_state()
	var id: String = fixture.stitched_id
	var first: int = source.deck.find(id)
	var unique: Array[String] = []
	for card in source.deck:
		if not unique.has(card):
			unique.append(card)
	var row_index := unique.find(id)
	_check(visit.is_valid() and first >= 0 and row_index >= 0 and source.descriptors.has(id),
			"source-owned stitched-card selection prerequisite")
	if row_index < 0:
		return
	var card_row := panel.card_buttons[row_index]
	var halves: Array = source.descriptors[id].half_ids
	var owner1 := str(RunRestStitchCards.resolve_card_definition(halves[0]).get("owner", "")).capitalize()
	var owner2 := str(RunRestStitchCards.resolve_card_definition(halves[1]).get("owner", "")).capitalize()
	var expected_name := owner1 + " / " + owner2 + " - " + str(source.descriptors[id].display_name)
	_check(card_row.text.contains(source.descriptors[id].display_name)
			and card_row.text.contains("%02d" % (first + 1))
			and card_row.text.contains(owner1 + " / " + owner2 + " - "),
			"descriptor names composite on canonical first-occurrence tile with ordered owners")
	var first_half := RunRestStitchCards.resolve_card_definition(halves[0])
	var second_half := RunRestStitchCards.resolve_card_definition(halves[1])
	_check(not first_half.is_empty() and not second_half.is_empty()
			and first_half.get("owner") != second_half.get("owner"),
			"both authentic cross-owner half definitions resolve for the stitched fixture")
	if first_half.is_empty() or second_half.is_empty():
		return
	_check(RunRestStitchCards.resolve_card_definition(id).is_empty(),
			"a stitched composite is genuinely not a standalone catalog card")
	var descriptor: Dictionary = source.descriptors[id]
	var stitched_cost: int = mini(3, maxi(int(first_half.get("cost", -1)),
			int(second_half.get("cost", -1))) + 1)
	_check(int(descriptor.get("cost", -1)) == stitched_cost,
			"descriptor cost is the authored higher half cost + 1, capped at 3")
	var stitched_tip: String = card_row.tooltip_text
	_check(stitched_tip == _expected_stitched_tooltip(descriptor, first_half, second_half),
			"stitched tooltip exposes descriptor name, cost and both authored halves in order")
	var first_at := stitched_tip.find("FIRST — ")
	var second_at := stitched_tip.find("SECOND — ")
	_check(first_at >= 0 and second_at > first_at
			and stitched_tip.find(str(descriptor.get("display_name", ""))) >= 0
			and stitched_tip.contains("%d energy" % stitched_cost)
			and stitched_tip.substr(first_at, second_at - first_at).contains(
					str(first_half.get("display_name", "")))
			and stitched_tip.substr(first_at, second_at - first_at).contains(
					CardShortRules.line(first_half))
			and stitched_tip.substr(second_at).contains(
					str(second_half.get("display_name", "")))
			and stitched_tip.substr(second_at).contains(CardShortRules.line(second_half))
			and stitched_tip.contains("Both owners must be alive and in their own FROM slots"),
			"stitched tooltip names FIRST then SECOND with their owners, slots and exact rule lines")
	_check(stitched_tip == LiveUnpickerPanel.card_tooltip(source, id),
			"stitched tooltip is a pure projection of the authenticated descriptor ledger")
	await _activate(card_row, false)
	var copies: int = source.deck.count(id)
	_check(panel.status_label.text.contains(expected_name)
			and panel.status_label.text.contains("first of %d %s" % [copies, "copy" if copies == 1 else "copies"])
			and panel.status_label.text.contains("deck %d→%d" % [source.deck.size(), source.deck.size() - 1])
			and panel.status_label.text.contains("gold 100→25 (75 cost)")
			and panel.status_label.text.contains("stitched descriptor removed"),
			"stitched row selection previews composed name, one absorbed entry and descriptor retirement")
	var lines: int = panel.status_label.get_line_count()
	var line_height: float = float(panel.status_label.get_line_height())
	_check(float(lines) * line_height <= panel.status_label.size.y + 0.5
			and panel.status_label.size.y >= 2.0 * line_height
			and panel.status_label.get_global_rect().end.y <= panel.choice_scroll.get_global_rect().position.y
			and not panel.status_label.get_global_rect().intersects(panel.remove_button.get_global_rect())
			and not panel.status_label.get_global_rect().intersects(panel.leave_button.get_global_rect()),
			"long stitched owner/name forecast wraps inside its band above rows and buttons (%d lines of %d)"
					% [lines, int(line_height)])
	_check(visit.read_state() == source and intents.is_empty()
			and visit.is_valid() and not visit.is_consumed(),
			"stitched forecast neither mutates nor consumes the authenticated visit")
	await _activate(panel.remove_button, false)
	_check(intents.size() == 1 and intents[0].get("selected_card_id") == id,
			"selected descriptor identity captured without row metadata")
	if intents.size() != 1:
		return
	var receipt := Controller.apply(visit, intents[0])
	var expected: Array = source.deck.duplicate()
	expected.remove_at(first)
	_check(receipt.get("ok") == true and receipt.deck == expected
			and not receipt.descriptors.has(id) and receipt.descriptors.size() == source.descriptors.size() - 1,
			"controller genuinely retires selected owned stitched descriptor and first copy")
	_check(receipt.next_stitch_id == source.next_stitch_id and receipt.gold == 25
			and receipt.charged_gold == 75,
			"stitched removal charges only gold and never frees stitch serial")
	_check(RunRestStitchCards.new(receipt.deck, receipt.descriptors, 0,
			receipt.next_stitch_id).is_valid(), "post-removal stitched ledger stays legal")


func _test_rejections() -> void:
	var invalid := RunUnpickerVisit.new(NODE, [], 75, 0, {}, 1)
	_check(not invalid.is_valid(), "empty-deck service invalid by real validation")
	await _bind(invalid)
	_check(panel.card_buttons.is_empty() and panel.remove_button.disabled
			and panel.leave_button.disabled, "invalid/no-card service exposes no actions")
	var already := _make()
	var snapshot := already.read_state()
	_check(already.leave(snapshot.visit_id, snapshot.node_id, snapshot).ok,
			"already-used real visit prerequisite")
	await _bind(already)
	_check(panel.card_buttons.is_empty() and panel.remove_button.disabled
			and panel.leave_button.disabled, "consumed visit never reopens")

	var old := _make()
	await _bind(old)
	var before := old.read_state()
	var row := panel.card_buttons[0]
	var retired_remove: Callable = panel._connections[panel.remove_button]
	var retired_leave: Callable = panel._connections[panel.leave_button]
	await _activate(row, false)
	var original_quote := panel.wallet_label.text
	var forecast_text := panel.status_label.text
	_check(forecast_text.contains("first of") and forecast_text.contains("gold"),
			"genuine selection really produced a forecast before rebind")
	panel.wallet_label.text = "Wallet: 99999 gold • Remove: 0 gold"
	panel.remove_button.pressed.emit()
	panel.leave_button.pressed.emit()
	_check(intents.is_empty() and old.read_state() == before,
			"forged displayed price suppresses both actionable source intents")
	panel.wallet_label.text = original_quote
	panel.hide()
	panel.remove_button.pressed.emit()
	panel.leave_button.pressed.emit()
	_check(intents.is_empty() and old.read_state() == before,
			"hidden control has no actionable callbacks")
	panel.show()
	panel.bind(old)
	await _settle()
	panel.card_buttons[0].text = "Forged card"
	panel.card_buttons[0].pressed.emit()
	panel.remove_button.pressed.emit()
	_check(intents.is_empty() and panel.remove_button.disabled
			and old.read_state() == before, "forged row/caption cannot select or spend")
	var newer := _make(100, 1)
	await _bind(newer)
	var after_new := newer.read_state()
	var newer_ids := _unique_ids(after_new.deck)
	var newer_definition := RunRestStitchCards.resolve_card_definition(newer_ids[0]) \
			if not newer_ids.is_empty() else {}
	_check(not newer_definition.is_empty() and not panel.card_buttons.is_empty()
			and panel.card_buttons[0].tooltip_text == _expected_tooltip(newer_definition),
			"rebind rebuilds mounted tooltips from the new authenticated deck")
	retired_remove.call()
	retired_leave.call()
	_check(intents.is_empty() and old.read_state() == before
			and newer.read_state() == after_new
			and panel.remove_button.disabled
			and panel.status_label.text == "Choose one card, then Remove it once. Or Leave."
			and panel.status_label.text != forecast_text,
			"retired callbacks and rebind reset selection and forecast without touching either source")
	var closed_before := newer.read_state()
	panel.close()
	_check(panel.card_buttons.is_empty(), "closed view keeps no reachable stale tooltip row")
	panel.leave_button.pressed.emit()
	_check(intents.is_empty() and newer.read_state() == closed_before,
			"closed view cannot request Leave")
	await _bind(newer)
	var stale := newer.read_state()
	# Actual service state advances outside the panel, not merely forged UI fields.
	var advance := newer.leave(stale.visit_id, stale.node_id, stale)
	_check(advance.ok and newer.is_consumed(), "external owner really consumed service")
	var consumed_state := newer.read_state()
	panel.leave_button.pressed.emit()
	panel.remove_button.pressed.emit()
	_check(intents.is_empty() and newer.read_state() == consumed_state,
			"changed original source disables stale removal and Leave")
