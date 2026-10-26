extends SceneTree
## V3-3 Peddler choice panel: five mounted priced actions (three owner-labelled
## hero cards, one patch, Leave) from one genuine OPEN RunPeddlerVisit, detached
## source-bound intents, and the authentic once-only card/patch/Leave receipts
## around the existing seeded stock sampler and purchase ledger.
##
## The panel is intentionally NOT wired into the live route yet (a later task).
## This test mounts it under a 1280x720 Control and proves the presentation and
## intent contract; every settlement goes through RunPeddlerVisit itself.

const NODE := "v3_peddler_stop"
const PARTY := ["warden", "seamstress", "tinker"]
const DECK := ["warden_strike", "seamstress_prick", "tinker_pop_shot"]
const SEED := 2611790
const GOLD := 500

var checks := 0
var failures: Array[String] = []
var panel: LivePeddlerPanel
var host: Control
var rng: RandomNumberGenerator
var sampled: Dictionary = {}
var authored_cards: Array = []
var authored_patches: Array = []
var card_authored: Dictionary = {}
var patch_authored: Dictionary = {}
var intents: Array[Dictionary] = []


class Controller:
	## Deliberately independent of the panel: re-read the genuine service and
	## forward the intent's own unchanged values to the one-use authority.
	static func settle(visit: RunPeddlerVisit, intent: Dictionary,
			prior: Dictionary) -> Dictionary:
		if visit == null or not visit.is_valid() or not visit.is_open():
			return {"ok": false}
		var current := visit.read_state()
		if prior.is_empty() or current != prior or current.get("status") != "open":
			return {"ok": false}
		if intent.get("node_id") != current.get("node_id") \
				or intent.get("expected_state") != current.get("state") \
				or intent.get("expected_stock") != current.get("stock"):
			return {"ok": false}
		var keys: Array = intent.keys()
		keys.sort()
		var kind: Variant = intent.get("kind")
		if kind == "leave":
			var leave_keys := ["expected_state", "expected_stock", "kind", "node_id"]
			leave_keys.sort()
			if keys != leave_keys:
				return {"ok": false}
			return visit.leave(intent["node_id"], intent["expected_state"],
					intent["expected_stock"])
		var buy_keys := ["expected_state", "expected_stock", "id", "kind", "node_id"]
		buy_keys.sort()
		if kind != "card" and kind != "trinket":
			return {"ok": false}
		if keys != buy_keys or typeof(intent.get("id")) != TYPE_STRING:
			return {"ok": false}
		return visit.choose_purchase(intent["node_id"], intent["expected_state"],
				intent["expected_stock"], kind, intent["id"])


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)


func _frames() -> void:
	for _i in range(4):
		await process_frame


func _finish() -> void:
	for failure in failures:
		printerr("FAIL: ", failure)
	print("live_peddler_panel_test: ", "PASS" if failures.is_empty() else "FAIL",
			" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var source_text := FileAccess.get_file_as_string("res://data/shop/initial_offers.json")
	var authored: Variant = JSON.parse_string(source_text)
	_check(not source_text.is_empty() and typeof(authored) == TYPE_DICTIONARY
			and authored.get("cards") is Array and authored.get("trinkets") is Array,
			"real authored shop candidate source loads")
	if typeof(authored) != TYPE_DICTIONARY or not (authored.get("cards") is Array) \
			or not (authored.get("trinkets") is Array):
		_finish()
		return
	authored_cards = authored["cards"]
	authored_patches = authored["trinkets"]
	_check(not authored_cards.is_empty() and not authored_patches.is_empty(),
			"authored source lists priced cards and patches")
	for entry in authored_cards:
		card_authored[entry["id"]] = {"owner": entry["owner"], "price": int(entry["price"])}
	for entry in authored_patches:
		patch_authored[entry["id"]] = int(entry["price"])

	rng = RandomNumberGenerator.new()
	rng.seed = SEED
	sampled = RunShopStockOffers.generate_peddler_stock(rng, PARTY, authored_cards,
			authored_patches, [])
	_check(sampled.get("ok") == true and sampled.get("cards") is Array
			and sampled.get("patches") is Array, "authentic seeded Peddler stock generates")
	if sampled.get("ok") != true:
		_finish()
		return
	_check(sampled["cards"].size() == 3 and sampled["patches"].size() == 1,
			"Peddler stock is exactly three cards and one patch")
	if sampled["cards"].size() != 3 or sampled["patches"].size() != 1:
		_finish()
		return
	var owners: Array = []
	var offer_ids := {}
	for offer in sampled["cards"]:
		owners.append(offer["owner"])
		offer_ids[offer["id"]] = true
		_check(card_authored.has(offer["id"])
				and card_authored[offer["id"]]["owner"] == offer["owner"]
				and card_authored[offer["id"]]["price"] == int(offer["price"]),
				"sampled card " + str(offer["id"]) + " keeps its authored owner and price")
	_check(owners == PARTY and offer_ids.size() == 3,
			"exactly one distinct card per party hero, in party order")
	var patch: Dictionary = sampled["patches"][0]
	_check(patch_authored.has(patch["id"]) and patch_authored[patch["id"]] == int(patch["price"]),
			"sampled patch " + str(patch["id"]) + " keeps its authored price")

	var visit := _visit()
	_check(visit.is_valid() and visit.is_open(), "genuine stock opens a real Peddler visit")
	var open_state := visit.read_state()
	_check(open_state.get("ok") == true and open_state.get("status") == "open"
			and open_state.get("node_id") == NODE, "visit publishes a genuine OPEN projection")
	_check(open_state["stock"] == _ledger_stock(sampled),
			"visit stock is the authoritative 3+1 ledger projection")
	if not visit.is_open():
		_finish()
		return

	host = Control.new()
	host.size = Vector2(1280, 720)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(host)
	panel = LivePeddlerPanel.new()
	panel.position = Vector2(190, 60)
	panel.bind(visit) # Pre-mount bind is permitted and must be honored.
	host.add_child(panel)
	panel.intent_requested.connect(func(intent: Dictionary): intents.append(intent))
	await _frames()
	_check(host.size == Vector2(1280, 720) and panel.get_parent() == host,
			"panel is mounted under a 1280x720 Control")
	# Seed the global RNG only after Godot has mounted cosmetic UI nodes.
	seed(268)
	var expected_global := randi()
	seed(268)
	var expected_run := rng.state

	await _layout(visit)
	for index in range(3):
		await _buy_case(index, "card", index % 2 == 0)
	await _buy_case(0, "trinket", true)
	await _leave_case(false)
	await _leave_case(true)
	await _shortcut_cases()
	await _affordability_cases()
	await _sold_case()
	await _fail_closed()
	_check(rng.state == expected_run, "all panel previews, intents and refusals preserve seeded run RNG")
	_check(randi() == expected_global, "all mounted actions preserve global RNG")
	panel.queue_free()
	await process_frame
	_finish()


func _visit(gold: int = GOLD, node: String = NODE,
		owned: Array = []) -> RunPeddlerVisit:
	return RunPeddlerVisit.new(node, PARTY, DECK, owned, gold, sampled)


## The authentic ledger stock projection: authored prices, nothing sold yet.
func _ledger_stock(stock: Dictionary) -> Dictionary:
	var cards: Array = []
	for offer in stock["cards"]:
		cards.append({"id": offer["id"], "owner": offer["owner"],
			"price": offer["price"], "sold": false})
	var trinkets: Array = []
	for offer in stock["patches"]:
		trinkets.append({"id": offer["id"], "price": offer["price"], "sold": false})
	return {"cards": cards, "trinkets": trinkets}


func _bind(visit: RunPeddlerVisit) -> void:
	intents.clear()
	panel.bind(visit)
	await _frames()


func _act(button: Button, keyboard: bool, key: Key = KEY_ENTER) -> void:
	_check(button != null and button.is_inside_tree() and button.is_visible_in_tree()
			and not button.disabled and button.focus_mode == Control.FOCUS_ALL,
			"mounted enabled action is reachable")
	if button == null or not button.is_inside_tree() or button.disabled:
		return
	if keyboard:
		button.grab_focus()
		_check(button.has_focus(), "keyboard action has real focus")
		for down in [true, false]:
			var event := InputEventKey.new()
			event.keycode = key
			event.pressed = down
			root.push_input(event)
			await process_frame
	else:
		var target := button.get_global_rect().get_center()
		_check(Rect2(Vector2.ZERO, Vector2(root.size)).has_point(target),
				"mouse target inside the 1280x720 viewport")
		var motion := InputEventMouseMotion.new()
		motion.position = target
		root.push_input(motion)
		await process_frame
		for down in [true, false]:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.position = target
			event.pressed = down
			root.push_input(event)
			await process_frame
	await _frames()


## Measured readability: the shipped font's single-line width must fit the
## button's inner width at the actual themed size, and the row must be tall
## enough for that line.
func _fits(button: Button) -> bool:
	var font := button.get_theme_font("font")
	if font == null or button.text.is_empty():
		return false
	var size_px := button.get_theme_font_size("font_size")
	if size_px < 18:
		return false
	var width := font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	return width <= button.size.x - 16.0 and button.size.y >= font.get_height(size_px) * 1.4


func _expected_name(item_id: String) -> String:
	var words: PackedStringArray = item_id.split("_")
	for i in range(words.size()):
		words[i] = words[i].left(1).to_upper() + words[i].substr(1)
	return " ".join(words)


func _layout(visit: RunPeddlerVisit) -> void:
	var screen := Rect2(host.get_global_rect().position, host.size)
	_check(screen.encloses(panel.get_global_rect()) and panel.size == LivePeddlerPanel.PANEL_SIZE,
			"compact sewn panel is wholly visible at 1280x720")
	var actual: Array = panel.find_children("*", "Button", true, false)
	_check(actual.size() == 5 and panel.card_buttons.size() == 3
			and actual.has(panel.patch_button) and actual.has(panel.leave_button),
			"exactly three card buys, one patch buy and Leave (five buttons)")
	_check(panel.title_label.text.contains("PEDDLER")
			and panel.wallet_label.text.contains("500 gold")
			and panel.status_label.text.contains("Leave"), "title, wallet and one-choice hint readable")
	var open := visit.read_state()
	for index in range(3):
		var button := panel.card_buttons[index]
		var offer: Dictionary = open["stock"]["cards"][index]
		_check(screen.encloses(button.get_global_rect()) and button.size.y >= 70,
				"unclipped card action row " + str(index))
		_check(button.text.begins_with(str(offer["owner"]).capitalize() + "  ·  "),
				"card row starts with its proper owner")
		_check(not button.text.contains(str(offer["id"])) and not button.text.contains("_"),
				"card row hides the raw item ID")
		_check(button.text.contains(_expected_name(str(offer["id"]))),
				"card row shows independently readable authored name")
		_check(button.text.ends_with("  ·  %d gold" % int(offer["price"])),
				"card row shows exact authored quote")
		_check(not button.disabled and button.get_meta("offer_kind") == "card"
				and button.get_meta("offer_id") == offer["id"],
				"funded card row is actionable and source-tagged")
		_check(_fits(button) and button.get_theme_stylebox("focus") != null,
				"card row text fits its sewn button and has a focus ring")
	var patch_button := panel.patch_button
	var patch_offer: Dictionary = open["stock"]["trinkets"][0]
	_check(screen.encloses(patch_button.get_global_rect())
			and patch_button.get_meta("offer_id") == patch_offer["id"]
			and patch_button.get_meta("offer_kind") == "trinket" and not patch_button.disabled,
			"patch row retains authored ID metadata and is actionable")
	_check(patch_button.text.begins_with("PATCH  ·  "), "patch row starts with PATCH")
	_check(not patch_button.text.contains(str(patch_offer["id"]))
			and not patch_button.text.contains("_"), "patch row hides the raw item ID")
	_check(patch_button.text.contains(_expected_name(str(patch_offer["id"]))),
			"patch row shows independently readable authored name")
	_check(patch_button.text.ends_with("  ·  %d gold" % int(patch_offer["price"])),
			"patch row shows exact authored quote")
	_check(_fits(patch_button) and patch_button.get_theme_stylebox("focus") != null,
			"patch row text fits its sewn button and has a focus ring")
	_check(screen.encloses(panel.leave_button.get_global_rect())
			and panel.leave_button.text == "Leave  ·  FREE" and not panel.leave_button.disabled,
			"free Leave is visible, enabled and inside the viewport")
	_check(_fits(panel.leave_button), "Leave text fits its sewn button")
	var action_rects: Array[Rect2] = []
	for button in panel.card_buttons + [panel.patch_button, panel.leave_button]:
		action_rects.append(button.get_global_rect())
	var distinct := true
	for i in range(action_rects.size()):
		for j in range(i + 1, action_rects.size()):
			if action_rects[i].intersects(action_rects[j]):
				distinct = false
	_check(distinct, "the five sewn actions have distinct, non-overlapping targets")
	var heading_clear := true
	for label in [panel.title_label, panel.wallet_label, panel.status_label]:
		for rect in action_rects:
			if label.get_global_rect().intersects(rect):
				heading_clear = false
	_check(heading_clear, "headings stay clear of every action row")
	# Every authored card and patch quote this panel can ever be handed must fit
	# one measured line, not just this seed's four offers.
	var caption_font := panel.card_buttons[0].get_theme_font("font")
	var caption_size := panel.card_buttons[0].get_theme_font_size("font_size")
	var worst := 0.0
	if caption_font != null:
		for entry in authored_cards + authored_patches:
			var prefix := str(entry["owner"]).capitalize() if entry.has("owner") else "PATCH"
			var line := "%s  ·  %s  ·  %d gold" % [
					prefix, _expected_name(str(entry["id"])), int(entry["price"])]
			_check(panel._caption(prefix, entry["id"], entry["price"], false) == line
					and panel._caption(prefix, entry["id"], entry["price"], true) == line + "  ·  SOLD",
					"every authored caption has exact readable name, prefix, price and sold suffix: " + entry["id"])
			for caption in [line, line + "  ·  SOLD", line + "  ·  short %d" % int(entry["price"])]:
				worst = maxf(worst, caption_font.get_string_size(caption,
						HORIZONTAL_ALIGNMENT_LEFT, -1, caption_size).x)
	_check(caption_font != null and not authored_cards.is_empty() and not authored_patches.is_empty()
			and worst <= panel.card_buttons[0].size.x - 16.0,
			"every authored Peddler quote fits one measured line at the shipped font size")
	# Keyboard traversal reaches every one of the five actions.
	var focus_seen: Array = []
	panel.card_buttons[0].grab_focus()
	for _i in range(5):
		focus_seen.append(root.gui_get_focus_owner())
		var tab := InputEventKey.new()
		tab.keycode = KEY_TAB
		tab.pressed = true
		root.push_input(tab)
		await process_frame
	for button in panel.card_buttons + [panel.patch_button, panel.leave_button]:
		_check(focus_seen.has(button), "Tab visits every one of the five actions")
	_check(visit.read_state() == open and intents.is_empty(),
			"focus and preview only: no intent and no service mutation")


func _expected_receipt(prior: Dictionary, kind: String, index: int) -> Dictionary:
	var offer: Dictionary = prior["stock"]["cards"][index] if kind == "card" \
			else prior["stock"]["trinkets"][0]
	var price := int(offer["price"])
	var state: Dictionary = prior["state"].duplicate(true)
	state["gold"] = int(state["gold"]) - price
	if kind == "card":
		state["deck"].append(offer["id"])
	else:
		state["trinkets"].append(offer["id"])
	var stock: Dictionary = prior["stock"].duplicate(true)
	if kind == "card":
		stock["cards"][index]["sold"] = true
	else:
		stock["trinkets"][0]["sold"] = true
	return {"state": state, "stock": stock, "price": price}


func _buy_case(index: int, kind: String, keyboard: bool) -> void:
	var visit := _visit(GOLD, "peddler_" + kind + "_" + str(index))
	var before := visit.read_state()
	_check(visit.is_open(), "funded genuine visit is OPEN for a " + kind + " buy")
	await _bind(visit)
	var button: Button = panel.patch_button if kind == "trinket" else panel.card_buttons[index]
	var offer: Dictionary = before["stock"]["trinkets"][0] if kind == "trinket" \
			else before["stock"]["cards"][index]
	var callback: Callable = panel._connections.get(button, Callable())
	_check(callback.is_valid(), "press handler is bound before the action")
	await _act(button, keyboard, KEY_SPACE if keyboard else KEY_ENTER)
	_check(intents.size() == 1, kind + " " + str(offer["id"]) + ": exactly one emitted intent")
	_check(visit.read_state() == before and visit.is_open(),
			kind + " " + str(offer["id"]) + ": panel emits without mutating the visit")
	if intents.size() != 1:
		return
	var intent: Dictionary = intents[0]
	var keys: Array = intent.keys()
	keys.sort()
	var expected_keys := ["expected_state", "expected_stock", "id", "kind", "node_id"]
	expected_keys.sort()
	_check(keys == expected_keys and intent["kind"] == kind
			and intent["id"] == offer["id"] and intent["node_id"] == before["node_id"]
			and intent["expected_state"] == before["state"]
			and intent["expected_stock"] == before["stock"],
			kind + ": detached intent carries node, kind, offered ID and both exact snapshots")
	var expected := _expected_receipt(before, kind, index)
	var receipt := Controller.settle(visit, intent, before)
	var expected_receipt := {
		"ok": true, "node_id": before["node_id"], "decision": "buy", "kind": kind,
		"id": offer["id"], "price": expected["price"],
		"state": expected["state"], "stock": expected["stock"],
	}
	_check(receipt == expected_receipt,
			kind + ": authentic once-only receipt charges the authored quote exactly")
	_check(visit.is_consumed() and visit.read_state() == {
			"ok": true, "node_id": before["node_id"], "status": "used",
			"state": expected["state"], "stock": expected["stock"]},
			kind + ": one purchase consumes the visit and settles gold/deck/patch ledger")
	_check(Controller.settle(visit, intent, before).get("ok") != true,
			kind + ": replay of the same intent is refused")
	_check(Controller.settle(visit, intent, visit.read_state()).get("ok") != true,
			kind + ": a structurally fresh but consumed visit refuses the intent")
	# Retired callbacks and disabled controls cannot mint a second intent.
	for other in panel.card_buttons + [panel.patch_button, panel.leave_button]:
		_check(other.disabled, kind + ": every action disabled after the one purchase")
		other.pressed.emit()
	if callback.is_valid():
		callback.call()
	await _frames()
	_check(intents.size() == 1 and visit.is_consumed(),
			kind + ": stale handler and disabled presses emit nothing")
	intent["expected_stock"]["cards"][0]["price"] = 1
	intent["expected_state"]["gold"] = 99999
	_check(visit.read_state()["stock"] == expected["stock"]
			and visit.read_state()["state"] == expected["state"],
			kind + ": mutating the emitted intent cannot corrupt the real source")


func _leave_case(keyboard: bool) -> void:
	var visit := _visit(GOLD, "peddler_leave_" + ("key" if keyboard else "mouse"))
	var before := visit.read_state()
	await _bind(visit)
	var callback: Callable = panel._connections.get(panel.leave_button, Callable())
	_check(callback.is_valid() and not panel.leave_button.disabled, "Leave is bound and free while open")
	await _act(panel.leave_button, keyboard, KEY_SPACE if keyboard else KEY_ENTER)
	_check(intents.size() == 1, "physical Leave emits exactly once")
	_check(visit.read_state() == before, "view-side Leave performs no transaction")
	if intents.size() != 1:
		return
	var intent: Dictionary = intents[0]
	var keys: Array = intent.keys()
	keys.sort()
	var expected_keys := ["expected_state", "expected_stock", "kind", "node_id"]
	expected_keys.sort()
	_check(keys == expected_keys and intent["kind"] == "leave"
			and intent["node_id"] == before["node_id"]
			and intent["expected_state"] == before["state"]
			and intent["expected_stock"] == before["stock"],
			"Leave intent is kind leave with node and both exact snapshots only")
	var receipt := Controller.settle(visit, intent, before)
	_check(receipt == {
		"ok": true, "node_id": before["node_id"], "decision": "leave",
		"state": before["state"], "stock": before["stock"],
	}, "authentic Leave receipt spends nothing and changes no ledger")
	_check(visit.read_state() == {"ok": true, "node_id": before["node_id"], "status": "left",
		"state": before["state"], "stock": before["stock"]},
		"Leave closes the visit with unchanged wallet, deck and patches")
	_check(Controller.settle(visit, intent, visit.read_state()).get("ok") != true,
			"duplicate Leave is refused")
	if callback.is_valid():
		callback.call()
	panel.leave_button.pressed.emit()
	await _frames()
	_check(intents.size() == 1, "retired Leave handler cannot emit after the one Leave")


func _shortcut_cases() -> void:
	# 1, 2, 3, 4, 0 keys
	var scenarios := [
		{"key": KEY_1, "index": 0, "kind": "card"},
		{"key": KEY_2, "index": 1, "kind": "card"},
		{"key": KEY_3, "index": 2, "kind": "card"},
		{"key": KEY_4, "index": 0, "kind": "trinket"},
		{"key": KEY_0, "index": -1, "kind": "leave"},
	]
	for scenario in scenarios:
		var key: int = scenario["key"]
		var index: int = scenario["index"]
		var kind: String = scenario["kind"]
		var visit := _visit(GOLD, "peddler_shortcut_" + str(key))
		var before := visit.read_state()
		await _bind(visit)
		panel.card_buttons[0].grab_focus()
		await _frames()
		_check(panel.get_viewport().gui_get_focus_owner() != null, "panel button has focus")
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = true
		root.push_input(event)
		await _frames()
		_check(intents.size() == 1, "shortcut key " + str(key) + " emits exactly one intent")
		if intents.size() == 1:
			var receipt := Controller.settle(visit, intents[0], before)
			_check(receipt.get("ok") == true and receipt.get("kind", "leave") == kind,
					"shortcut key " + str(key) + " settles authentically")
		var up_event := InputEventKey.new()
		up_event.keycode = key
		up_event.pressed = false
		root.push_input(up_event)
		await _frames()

	# Zero gold
	var broke := _visit(0, "peddler_shortcut_broke")
	await _bind(broke)
	panel.card_buttons[0].grab_focus()
	for key in [KEY_1, KEY_2, KEY_3, KEY_4]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = true
		root.push_input(event)
	await _frames()
	_check(intents.is_empty(), "broke visit ignores 1-4 shortcuts")
	var leave_event := InputEventKey.new()
	leave_event.keycode = KEY_0
	leave_event.pressed = true
	root.push_input(leave_event)
	await _frames()
	_check(intents.size() == 1 and intents[0]["kind"] == "leave",
			"broke visit still accepts 0 shortcut to Leave")

	# Owned/SOLD patch
	var patch_id: String = str(sampled["patches"][0]["id"])
	var sold := _visit(GOLD, "peddler_shortcut_sold", [patch_id])
	await _bind(sold)
	panel.card_buttons[0].grab_focus()
	var patch_event := InputEventKey.new()
	patch_event.keycode = KEY_4
	patch_event.pressed = true
	root.push_input(patch_event)
	await _frames()
	_check(intents.is_empty(), "owned patch ignores 4 shortcut")
	var card_event := InputEventKey.new()
	card_event.keycode = KEY_1
	card_event.pressed = true
	root.push_input(card_event)
	await _frames()
	_check(intents.size() == 1 and intents[0]["kind"] == "card",
			"available card still works with 1 shortcut after sold patch")

	# Invalid states (focus away, stale, repeat, echo)
	var guarded := _visit(GOLD, "peddler_shortcut_guarded")
	await _bind(guarded)

	# Unrelated key
	var unrelated := InputEventKey.new()
	unrelated.keycode = KEY_9
	unrelated.pressed = true
	root.push_input(unrelated)
	await _frames()
	_check(intents.is_empty(), "unrelated key does nothing")

	# Focus away
	var other_control := Control.new()
	other_control.focus_mode = Control.FOCUS_ALL
	host.add_child(other_control)
	other_control.grab_focus()
	await _frames()
	var away_event := InputEventKey.new()
	away_event.keycode = KEY_1
	away_event.pressed = true
	root.push_input(away_event)
	await _frames()
	_check(intents.is_empty(), "shortcut ignored when focus is away")
	other_control.queue_free()
	panel.card_buttons[0].grab_focus()
	await _frames()

	# Echo
	var echo_event := InputEventKey.new()
	echo_event.keycode = KEY_1
	echo_event.pressed = true
	echo_event.echo = true
	root.push_input(echo_event)
	await _frames()
	_check(intents.is_empty(), "shortcut ignores echo events")

	# Modifier
	var mod_event := InputEventKey.new()
	mod_event.keycode = KEY_1
	mod_event.pressed = true
	mod_event.shift_pressed = true
	root.push_input(mod_event)
	await _frames()
	_check(intents.is_empty(), "shortcut ignores modifier keys")

	# Already pending intent cannot be duplicated
	var valid_event := InputEventKey.new()
	valid_event.keycode = KEY_1
	valid_event.pressed = true
	root.push_input(valid_event)
	await _frames()
	_check(intents.size() == 1, "first valid shortcut emits")
	var duplicate_event := InputEventKey.new()
	duplicate_event.keycode = KEY_2
	duplicate_event.pressed = true
	root.push_input(duplicate_event)
	await _frames()
	_check(intents.size() == 1, "second valid shortcut cannot emit while pending")


func _affordability_cases() -> void:
	# Zero gold: all four buys disabled with a precise shortfall, Leave enabled.
	var broke := _visit(0, "peddler_broke")
	var broke_open := broke.read_state()
	_check(broke.is_open(), "zero-gold visit still opens for one free Leave")
	await _bind(broke)
	var offers: Array = []
	var buttons: Array = []
	for index in range(3):
		offers.append(broke_open["stock"]["cards"][index])
		buttons.append(panel.card_buttons[index])
	offers.append(broke_open["stock"]["trinkets"][0])
	buttons.append(panel.patch_button)
	for index in range(buttons.size()):
		var button: Button = buttons[index]
		var price := int(offers[index]["price"])
		_check(button.disabled and button.text.contains("short " + str(price)),
				"unaffordable " + str(offers[index]["id"]) + " is disabled with its exact shortfall")
		button.pressed.emit()
	await _frames()
	_check(intents.is_empty() and broke.read_state() == broke_open,
			"pressing disabled unaffordable buys emits nothing and spends nothing")
	_check(not panel.leave_button.disabled, "Leave stays enabled when nothing is affordable")
	await _act(panel.leave_button, true, KEY_SPACE)
	_check(intents.size() == 1 and Controller.settle(broke, intents[0], broke_open).get("ok") == true,
			"broke player can still Leave once through the authentic authority")

	# Exactly the cheapest quote: only offerings at or under that gold are enabled.
	var prices: Array = []
	for index in range(3):
		prices.append(int(broke_open["stock"]["cards"][index]["price"]))
	prices.append(int(broke_open["stock"]["trinkets"][0]["price"]))
	prices.sort()
	var exact := _visit(int(prices[0]), "peddler_exact")
	var exact_open := exact.read_state()
	await _bind(exact)
	for index in range(3):
		var offer: Dictionary = exact_open["stock"]["cards"][index]
		_check(panel.card_buttons[index].disabled == (int(prices[0]) < int(offer["price"])),
				"exact-gold card affordability matches gold vs authored price")
	var patch_offer: Dictionary = exact_open["stock"]["trinkets"][0]
	_check(panel.patch_button.disabled == (int(prices[0]) < int(patch_offer["price"])),
			"exact-gold patch affordability matches gold vs authored price")
	_check(not panel.leave_button.disabled, "Leave ignores affordability")
	_check(panel._focusables().size() >= 1, "at least one focusable action at exact gold")


func _sold_case() -> void:
	var patch_id: String = str(sampled["patches"][0]["id"])
	var visit := _visit(GOLD, "peddler_sold", [patch_id])
	var before := visit.read_state()
	_check(visit.is_open() and before["stock"]["trinkets"][0]["sold"] == true
			and before["state"]["trinkets"] == [patch_id],
			"sold fixture is a genuine open visit with its own patch already owned")
	await _bind(visit)
	_check(panel.patch_button.disabled and panel.patch_button.text.contains("SOLD"),
			"genuinely sold patch is disabled and labelled SOLD")
	panel.patch_button.pressed.emit()
	await _frames()
	_check(intents.is_empty(), "pressing the sold patch emits nothing")
	await _act(panel.card_buttons[0], false)
	_check(intents.size() == 1 and intents[0]["kind"] == "card",
			"a funded card stays buyable beside a sold patch")
	if intents.size() != 1:
		return
	var first: Dictionary = before["stock"]["cards"][0]
	var receipt := Controller.settle(visit, intents[0], before)
	_check(receipt.get("ok") == true and receipt["price"] == first["price"]
			and receipt["state"]["deck"] == DECK + [first["id"]]
			and receipt["state"]["trinkets"] == [patch_id]
			and receipt["state"]["gold"] == GOLD - int(first["price"]),
			"card receipt adds one card, keeps the owned patch and charges its quote")


func _assert_controller_refused(visit: RunPeddlerVisit, prior: Dictionary,
		forged: Dictionary, label: String) -> void:
	var before := visit.read_state()
	_check(Controller.settle(visit, forged, prior).get("ok") != true,
			label + ": controller refuses the intent")
	_check(visit.read_state() == before and visit.is_open(),
			label + ": refusal left the visit untouched")


func _fail_closed() -> void:
	var visit := _visit(GOLD, "peddler_guarded")
	var before := visit.read_state()
	_check(visit.is_open(), "guard fixture is a genuine open visit")
	await _bind(visit)
	var card_callback: Callable = panel._connections[panel.card_buttons[0]]
	var patch_callback: Callable = panel._connections[panel.patch_button]
	var leave_callback: Callable = panel._connections[panel.leave_button]

	# Forged intents never settle: wrong node, stale/forged snapshots, an
	# unoffered item, a non-contract kind, missing fields or a relabelled buy.
	var genuine := {
		"node_id": before["node_id"], "kind": "card", "id": before["stock"]["cards"][0]["id"],
		"expected_state": before["state"].duplicate(true),
		"expected_stock": before["stock"].duplicate(true),
	}
	var wrong_node := genuine.duplicate(true)
	wrong_node["node_id"] = "other_tile"
	_assert_controller_refused(visit, before, wrong_node, "wrong node")
	var richer := genuine.duplicate(true)
	richer["expected_state"]["gold"] = GOLD + 1
	_assert_controller_refused(visit, before, richer, "forged richer state snapshot")
	var cheaper := genuine.duplicate(true)
	cheaper["expected_stock"]["cards"][0]["price"] = 1
	_assert_controller_refused(visit, before, cheaper, "forged cheaper stock snapshot")
	var unoffered := genuine.duplicate(true)
	unoffered["id"] = "not_offered"
	_assert_controller_refused(visit, before, unoffered, "unoffered item")
	var wrong_kind := genuine.duplicate(true)
	wrong_kind["kind"] = "patch"
	_assert_controller_refused(visit, before, wrong_kind, "non-contract kind")
	var incomplete := genuine.duplicate(true)
	incomplete.erase("expected_stock")
	_assert_controller_refused(visit, before, incomplete, "incomplete intent")
	var relabelled := genuine.duplicate(true)
	relabelled["kind"] = "leave"
	_assert_controller_refused(visit, before, relabelled, "buy fields relabelled as Leave")
	_assert_controller_refused(visit, {}, genuine, "empty prior projection")

	# A mounted control with forged metadata or state cannot mint an intent.
	panel.card_buttons[0].set_meta("offer_id", "forged_card")
	card_callback.call()
	panel.card_buttons[0].set_meta("offer_id", before["stock"]["cards"][0]["id"])
	panel.patch_button.set_meta("offer_kind", "card")
	patch_callback.call()
	panel.patch_button.set_meta("offer_kind", "trinket")
	panel.card_buttons[0].disabled = true
	card_callback.call()
	panel.card_buttons[0].disabled = false
	_check(intents.is_empty(), "forged metadata and disabled state cannot emit")

	# Hidden or detached panels refuse; a re-shown panel is honest again.
	panel.hide()
	card_callback.call()
	leave_callback.call()
	_check(intents.is_empty(), "hidden panel refuses every action")
	panel.show()
	host.remove_child(panel)
	card_callback.call()
	leave_callback.call()
	_check(intents.is_empty(), "detached panel refuses every action")
	host.add_child(panel)
	await _frames()

	# Source drift after bind (authentic but stale) fails closed.
	visit._purchases._stock["cards"][0]["price"] += 1
	card_callback.call()
	_check(intents.is_empty(), "stale authentic card price refuses the press")
	visit._purchases._stock["cards"][0]["price"] -= 1
	visit._purchases._state["gold"] += 1
	leave_callback.call()
	_check(intents.is_empty(), "wallet drift after bind refuses the press")
	visit._purchases._state["gold"] -= 1
	_check(visit.read_state() == before and intents.is_empty(),
			"restored genuine source is still open and untouched")

	# Closed externally while bound: no payable intent may be minted.
	var closed := _visit(GOLD, "peddler_closed")
	var closed_before := closed.read_state()
	await _bind(closed)
	var closed_callback: Callable = panel._connections[panel.card_buttons[0]]
	_check(closed.leave(closed_before["node_id"], closed_before["state"],
			closed_before["stock"]).get("ok") == true, "fixture really closes the visit")
	closed_callback.call()
	_check(intents.is_empty(), "a visit closed after bind refuses the stale press")

	# A retired generation cannot act on a freshly rebound visit.
	var retired_card := card_callback
	var retired_leave := leave_callback
	var fresh := _visit(GOLD, "peddler_fresh")
	var fresh_before := fresh.read_state()
	await _bind(fresh)
	retired_card.call()
	retired_leave.call()
	_check(intents.is_empty(), "callbacks from the prior rebind are retired")
	await _act(panel.card_buttons[1], true, KEY_SPACE)
	_check(intents.size() == 1 and intents[0]["node_id"] == "peddler_fresh"
			and intents[0]["id"] == fresh_before["stock"]["cards"][1]["id"],
			"the rebound panel emits exactly one fresh source-bound intent")
	if intents.size() == 1:
		var receipt := Controller.settle(fresh, intents[0], fresh_before)
		_check(receipt.get("ok") == true and fresh.is_consumed(),
				"a fresh rebind still settles through the authentic authority")

	# Invalid, consumed and null bindings expose no payable action at all.
	var invalid := RunPeddlerVisit.new("", PARTY, DECK, [], GOLD, sampled)
	_check(not invalid.is_valid(), "invalid fixture is genuinely rejected by the service")
	await _bind(invalid)
	_check(panel.card_buttons.all(func(button: Button): return button.disabled)
			and panel.patch_button.disabled and panel.leave_button.disabled,
			"invalid service binds closed with every action disabled")
	await _act_noop(invalid)
	var consumed := _visit(GOLD, "peddler_used")
	var consumed_open := consumed.read_state()
	_check(consumed.leave(consumed_open["node_id"], consumed_open["state"],
			consumed_open["stock"]).get("ok") == true, "fixture visit is really consumed")
	await _bind(consumed)
	_check(panel.card_buttons[0].disabled and panel.patch_button.disabled
			and panel.leave_button.disabled, "a consumed visit binds closed")
	await _act_noop(consumed)
	await _bind(null)
	_check(panel.card_buttons[0].disabled and panel.patch_button.disabled
			and panel.leave_button.disabled, "null binding exposes no actions")
	panel.close()
	_check(intents.is_empty() and not panel.visible and panel.leave_button.disabled,
			"close retires every callback and hides the panel")


func _act_noop(visit: RunPeddlerVisit) -> void:
	var before := visit.read_state()
	for button in panel.card_buttons + [panel.patch_button, panel.leave_button]:
		button.pressed.emit()
	await _frames()
	_check(intents.is_empty() and visit.read_state() == before,
			"closed binding emits nothing and changes nothing")
