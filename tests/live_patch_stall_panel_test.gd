extends SceneTree
## Physical GUI and independent controller checks for the standalone Patch Stall.
const NODE := "f02_patch_stall"
const PARTY := ["warden", "seamstress", "tinker"]
const DECK := ["warden_strike", "tinker_pop_shot"]
const OWNED := ["quilted_coat"]
var checks := 0
var failures: Array[String] = []
var panel: LivePatchStallPanel
var offers: Array = []
var rng: RandomNumberGenerator
var intents: Array[Dictionary] = []

class Controller:
	## Deliberately independent of the panel: re-read the real service and
	## validate the whole proposed payload before invoking the one-use receipt.
	static func settle(visit: RunPatchStallVisit, intent: Dictionary,
			prior_state: Dictionary, prior_quote: Dictionary) -> Dictionary:
		if visit == null or not visit.is_valid() or visit.is_consumed():
			return {"ok": false}
		var state := visit.read_state()
		var quote := visit.quote()
		if state != prior_state or quote != prior_quote or state.get("status") != "available":
			return {"ok": false}
		if intent.get("node_id") != state.get("node_id") or intent.get("visit_id") != state.get("visit_id") \
				or intent.get("expected_snapshot") != state.get("snapshot"):
			return {"ok": false}
		var actual_keys: Array = intent.keys()
		actual_keys.sort()
		if intent.get("action") == "leave":
			var leave_keys := ["action", "expected_snapshot", "node_id", "visit_id"]
			leave_keys.sort()
			if actual_keys != leave_keys or quote.get("decisions") != ["buy_patch", "leave"]:
				return {"ok": false}
			return visit.leave(intent["visit_id"], intent["node_id"], intent["expected_snapshot"])
		var buy_keys := ["action", "expected_snapshot", "node_id", "patch_id", "visit_id", "wearer_id"]
		buy_keys.sort()
		if intent.get("action") != "buy_patch" or actual_keys != buy_keys \
				or quote.get("decisions") != ["buy_patch", "leave"]:
			return {"ok": false}
		var patch: Variant = intent.get("patch_id")
		var wearer: Variant = intent.get("wearer_id")
		var snapshot: Dictionary = state["snapshot"]
		if typeof(patch) != TYPE_STRING or typeof(wearer) != TYPE_STRING \
				or not snapshot["party_ids"].has(wearer):
			return {"ok": false}
		var matching := false
		for offer in quote["offers"]:
			if offer["id"] == patch and offer["sold"] == false \
					and typeof(offer["price"]) == TYPE_INT and snapshot["gold"] >= offer["price"]:
				matching = true
		if not matching:
			return {"ok": false}
		return visit.buy_patch(patch, intent["visit_id"], intent["node_id"], intent["expected_snapshot"])

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)

func _frames() -> void:
	for i in range(4):
		await process_frame

func _bind(visit: RunPatchStallVisit) -> void:
	intents.clear()
	panel.bind(visit)
	await _frames()

func _act(button: Button, keyboard: bool, key: Key = KEY_ENTER) -> void:
	_check(button != null and button.is_inside_tree() and button.is_visible_in_tree() \
			and not button.disabled and button.focus_mode == Control.FOCUS_ALL,
			"mounted enabled button reachable")
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
			"mouse target inside viewport")
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

func _visit(node: String = NODE, gold: int = 240) -> RunPatchStallVisit:
	return RunPatchStallVisit.new(node, PARTY, DECK, OWNED, gold, offers)

func _finish() -> void:
	for failure in failures:
		printerr("FAIL: ", failure)
	print("live_patch_stall_panel_test: ", "PASS" if failures.is_empty() else "FAIL",
			" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var source_text := FileAccess.get_file_as_string("res://data/shop/initial_offers.json")
	var authored: Variant = JSON.parse_string(source_text)
	_check(not source_text.is_empty() and typeof(authored) == TYPE_DICTIONARY \
			and authored.has("trinkets"), "shipped shop source exists")
	if typeof(authored) != TYPE_DICTIONARY or not authored.has("trinkets"):
		_finish()
		return
	rng = RandomNumberGenerator.new()
	rng.seed = 2680268
	var sampled := RunShopPurchases.sample_patch_stall_offers(rng, authored["trinkets"], OWNED)
	_check(sampled.get("ok") == true and sampled.get("offers") is Array,
		"genuine seeded sampler returns offers")
	if not sampled.get("ok"):
		_finish()
		return
	offers = sampled["offers"]
	_check(offers.size() == 3, "exactly three sampled offers")
	if offers.size() != 3:
		_finish()
		return
	var ids := {}
	var slot_map := {}
	for record in RunAuthoredPatchDefinitions.load_power_definitions():
		slot_map[record["id"]] = record["slot"]
	for record in offers:
		_check(not ids.has(record["id"]) and not OWNED.has(record["id"]),
			"distinct unowned source patch " + str(record["id"]))
		ids[record["id"]] = true
		_check(slot_map.has(record["id"]) and slot_map.get(record["id"]) in ["HEAD", "ARM", "COAT"],
			"sampled id is from authored power projection")
		var found := false
		for listing in authored["trinkets"]:
			if listing["id"] == record["id"] and int(listing["price"]) == record["price"]:
				found = true
		# A shipped P8 rare is priced in its own authored catalog rather than initial_offers.
		if not found:
			var rare: Variant = JSON.parse_string(FileAccess.get_file_as_string(
				"res://data/patches/mpw_synergy_patches.json"))
			if typeof(rare) == TYPE_ARRAY:
				for listing in rare:
					if listing["id"] == record["id"] and int(listing["shop_price_gold"]) == record["price"]:
						found = true
		_check(found and record["price"] > 0, "authoritative sampled patch price")
	var valid := _visit()
	_check(valid.is_valid() and valid.read_state().get("status") == "available"
			and valid.quote().get("offers", []).size() == 3, "real visit ready")
	panel = LivePatchStallPanel.new()
	panel.position = Vector2(190, 45)
	panel.bind(valid) # Pre-mount bind is permitted and must be honored.
	root.add_child(panel)
	panel.intent_requested.connect(func(intent: Dictionary): intents.append(intent))
	await _frames()
	_check(panel.wearer_buttons[0].has_focus(), "pre-mount bind gives initial focus")
	# Seed the global RNG only after Godot has mounted cosmetic UI nodes.
	seed(268)
	var expected_global := randi()
	seed(268)
	var expected_run := rng.state
	await _layout(valid)
	for chosen in range(3):
		for option in range(3):
			await _buy_case(chosen, option, (chosen + option) % 2 == 0)
	await _leave_case(false, true)
	await _leave_case(true, false)
	await _fail_closed()
	_check(rng.state == expected_run, "all panel actions preserve seeded run RNG")
	_check(randi() == expected_global, "all mounted actions preserve global RNG")
	panel.queue_free()
	await process_frame
	_finish()

func _layout(visit: RunPatchStallVisit) -> void:
	var screen := Rect2(Vector2.ZERO, Vector2(root.size))
	_check(screen.encloses(panel.get_global_rect()) and panel.size == Vector2(900, 630),
			"fixed sewn panel wholly visible 1280x720")
	var actual: Array = panel.find_children("*", "Button", true, false)
	_check(actual.size() == 7 and panel.offer_buttons.size() == 3 \
			and panel.wearer_buttons.size() == 3 and actual.has(panel.leave_button),
			"exactly three purchase buttons, three compact pins and Leave")
	_check(panel.wallet_label.text.contains("240 gold") and panel.title_label.text.contains("PATCH STALL"),
			"wallet and title readable")
	for i in range(3):
		var pin := panel.wearer_buttons[i]
		var button := panel.offer_buttons[i]
		var offer: Dictionary = visit.quote()["offers"][i]
		_check(screen.encloses(pin.get_global_rect()) and pin.size.y >= 50 \
				and screen.encloses(button.get_global_rect()) and button.size.y >= 80,
				"unclipped compact pin and large patch action " + str(i))
		_check(pin.text.to_lower().contains(PARTY[i]) and button.text.contains(offer["id"]) \
				and button.text.to_lower().contains(offer["id"].replace("_", " ").capitalize().to_lower()) \
				and button.text.contains(slot_map_for(offer["id"])) \
				and button.text.contains(str(offer["price"]) + " gold") and not button.disabled,
				"source ID/name, authored HEAD/ARM/COAT slot, exact gold and affordability")
		_check(button.get_theme_font_size("font_size") >= 20 and
				button.get_theme_color("font_color").get_luminance() > 0.6 and
				button.get_theme_stylebox("focus") != null, "readable focusable sewn choice")
	_check(screen.encloses(panel.leave_button.get_global_rect()) and
			panel.leave_button.text.contains("FREE") and not panel.leave_button.disabled,
			"free Leave is reachable")
	var focus_seen: Array = []
	panel.wearer_buttons[0].grab_focus()
	for i in range(7):
		focus_seen.append(root.gui_get_focus_owner())
		var tab := InputEventKey.new()
		tab.keycode = KEY_TAB
		tab.pressed = true
		root.push_input(tab)
		await process_frame
	for button in panel.wearer_buttons + panel.offer_buttons + [panel.leave_button]:
		_check(focus_seen.has(button), "Tab visits all enabled pins and decisions")
	_check(visit.read_state().get("status") == "available" and intents.is_empty(),
		"mere preview/focus has no transaction")

func slot_map_for(id: String) -> String:
	for record in RunAuthoredPatchDefinitions.load_power_definitions():
		if record["id"] == id:
			return record["slot"]
	return ""

func _buy_case(wearer: int, index: int, keyboard: bool) -> void:
	var visit := _visit("patch_%d_%d" % [wearer, index])
	var before := visit.read_state()
	var quote := visit.quote()
	_check(visit.is_valid() and quote["offers"].size() == 3, "funded valid source precondition")
	await _bind(visit)
	await _act(panel.wearer_buttons[wearer], keyboard, KEY_SPACE)
	_check(panel.wearer_buttons[wearer].text.begins_with("✕") \
			and panel.wearer_buttons[wearer].get_meta("wearer_id") == PARTY[wearer],
			"real input selects exact source wearer")
	var old_quote := visit.quote()
	var old_state := visit.read_state()
	await _act(panel.offer_buttons[index], not keyboard, KEY_ENTER)
	_check(intents.size() == 1, "exactly one quoted button intent")
	_check(visit.read_state() == old_state and visit.quote() == old_quote and not visit.is_consumed(),
			"panel emits without any service mutation or settlement")
	if intents.size() != 1:
		return
	var intent := intents[0]
	_check(intent.keys().size() == 6 and intent.get("action") == "buy_patch" \
			and intent.get("wearer_id") == PARTY[wearer] \
			and intent.get("patch_id") == quote["offers"][index]["id"] \
			and intent.get("node_id") == before["node_id"] \
			and intent.get("visit_id") == before["visit_id"] \
			and intent.get("expected_snapshot") == before["snapshot"],
			"source-bound ID, price selection, wearer, node, visit, full snapshot")
	var receipt := Controller.settle(visit, intent, before, quote)
	_check(receipt.get("ok") == true and receipt.get("decision") == "buy_patch",
			"independent controller accepts one genuine funded intent")
	if not receipt.get("ok"):
		return
	var price: int = quote["offers"][index]["price"]
	_check(receipt["receipt"] == {"kind": "trinket", "id": intent["patch_id"], "price": price},
			"receipt contains authoritative exact paid price")
	_check(receipt["ledger"]["gold"] == before["snapshot"]["gold"] - price \
			and receipt["ledger"]["deck"] == DECK \
			and receipt["ledger"]["trinkets"] == OWNED + [intent["patch_id"]] \
			and receipt["ledger"]["party_ids"] == PARTY, "one charge and one patch, no deck/party mutation")
	_check(visit.is_consumed() and not Controller.settle(visit, intent, before, quote).get("ok"),
			"one-use receipt; replay refused")
	var stale: Callable = panel._connections.get(panel.offer_buttons[index], Callable())
	await _act_disabled_replay()
	_check(intents.size() == 1, "repeat and opposite button cannot emit")
	if stale.is_valid():
		stale.call()
	_check(intents.size() == 1 and visit.is_consumed(), "stale captured callback cannot emit")
	intent["expected_snapshot"]["party_ids"][0] = "forged"
	_check(visit.read_state()["snapshot"] == before["snapshot"],
		"mutating deeply detached emitted snapshot does not corrupt real source")

func _act_disabled_replay() -> void:
	for button in panel.offer_buttons + [panel.leave_button]:
		_check(button.disabled, "submitted action disabled for replay")
		button.pressed.emit()
	await _frames()

func _leave_case(keyboard: bool, unfunded: bool) -> void:
	var visit := _visit("free_leave", 0 if unfunded else 240)
	var before := visit.read_state()
	var quote := visit.quote()
	await _bind(visit)
	if unfunded:
		_check(panel.offer_buttons.all(func(button: Button): return button.disabled),
				"all shortfall offers visibly disabled at zero gold")
		for i in range(3):
			_check(panel.offer_buttons[i].text.contains("short " + str(quote["offers"][i]["price"])),
					"source quote shows precise shortfall")
			panel.offer_buttons[i].pressed.emit()
		_check(intents.is_empty(), "disabled patch presses do not emit")
	_check(not panel.leave_button.disabled, "Leave remains free when broke")
	await _act(panel.leave_button, keyboard, KEY_SPACE)
	_check(intents.size() == 1, "physical Leave emits exactly once")
	if intents.size() != 1:
		return
	var intent := intents[0]
	_check(intent.keys().size() == 4 and intent.get("action") == "leave" \
			and intent.get("node_id") == before["node_id"] \
			and intent.get("visit_id") == before["visit_id"] \
			and intent.get("expected_snapshot") == before["snapshot"] \
			and not intent.has("patch_id") and not intent.has("wearer_id"),
			"Leave carries only source bound fields")
	_check(visit.read_state() == before and visit.quote() == quote,
			"view-side Leave causes zero transactions")
	var receipt := Controller.settle(visit, intent, before, quote)
	_check(receipt.get("ok") == true and receipt.get("decision") == "leave" \
			and receipt["ledger"]["gold"] == before["snapshot"]["gold"] \
			and receipt["ledger"]["trinkets"] == OWNED \
			and receipt["ledger"]["deck"] == DECK \
			and visit.is_consumed(), "controller Leave receipt is zero-spend/zero-patch")
	_check(not Controller.settle(visit, intent, before, quote).get("ok"), "Leave replay refused")

func _fail_closed() -> void:
	var source := _visit("guarded")
	await _bind(source)
	var state := source.read_state()
	var quote := source.quote()
	var callback: Callable = panel._connections[panel.offer_buttons[0]]
	var pin_callback: Callable = panel._connections[panel.wearer_buttons[1]]
	var leave_callback: Callable = panel._connections[panel.leave_button]
	var forged := {
		"action": "buy_patch", "patch_id": "forged_patch", "wearer_id": PARTY[0],
		"node_id": state["node_id"], "visit_id": state["visit_id"],
		"expected_snapshot": state["snapshot"].duplicate(true)}
	_check(not Controller.settle(source, forged, state, quote).get("ok"),
			"controller refuses forged non-offer patch")
	forged["patch_id"] = quote["offers"][0]["id"]
	forged["wearer_id"] = "forged_hero"
	_check(not Controller.settle(source, forged, state, quote).get("ok"),
			"controller refuses forged wearer")
	forged["wearer_id"] = PARTY[0]
	forged["node_id"] = "other_tile"
	_check(not Controller.settle(source, forged, state, quote).get("ok"),
			"controller refuses cross-node intent")
	forged["node_id"] = state["node_id"]
	forged["expected_snapshot"]["gold"] = 999
	_check(not Controller.settle(source, forged, state, quote).get("ok"),
			"controller refuses changed expected source")
	_check(source.read_state() == state and source.quote() == quote,
			"forgeries do not touch service ledger")
	# A live visible control with forged metadata or disabled state cannot send.
	var offer_button := panel.offer_buttons[0]
	offer_button.set_meta("patch_id", "forged_patch")
	callback.call()
	_check(intents.is_empty(), "forged offer metadata rejected")
	offer_button.set_meta("patch_id", quote["offers"][0]["id"])
	panel.wearer_buttons[0].set_meta("wearer_id", "impostor")
	callback.call()
	pin_callback.call()
	_check(intents.is_empty(), "forged wearer tag rejected")
	panel.wearer_buttons[0].set_meta("wearer_id", PARTY[0])
	offer_button.disabled = true
	callback.call()
	_check(intents.is_empty(), "disabled button callback rejected")
	offer_button.disabled = false
	panel.hide()
	callback.call()
	leave_callback.call()
	_check(intents.is_empty(), "hidden panel refuses actions")
	panel.show()
	root.remove_child(panel)
	callback.call()
	_check(intents.is_empty(), "detached button cannot request")
	root.add_child(panel)
	await _frames()
	# Mutating source quote after bind must fail closed, even with a valid-looking ID.
	source._purchases._stock["trinkets"][0]["price"] += 1
	callback.call()
	leave_callback.call()
	_check(intents.is_empty(), "stale authentic quote price refused")
	source._purchases._stock["trinkets"][0]["price"] -= 1
	source._snapshot["gold"] += 1
	callback.call()
	_check(intents.is_empty(), "source snapshot drift refused")
	source._snapshot["gold"] -= 1
	var observers := [0]
	var independent := func(): observers[0] += 1
	panel.offer_buttons[1].pressed.connect(independent)
	var invalid := RunPatchStallVisit.new("", PARTY, DECK, OWNED, 240, offers)
	_check(not invalid.is_valid(), "real invalid service fixture")
	await _bind(invalid)
	_check(panel.offer_buttons.all(func(button: Button): return button.disabled) \
			and panel.leave_button.disabled, "invalid service offers no actions")
	callback.call()
	pin_callback.call()
	leave_callback.call()
	_check(intents.is_empty(), "prior generation not reusable on invalid bind")
	var consumed := _visit("already_used")
	var consumed_state := consumed.read_state()
	_check(consumed.leave(consumed_state["visit_id"], consumed_state["node_id"],
			consumed_state["snapshot"]).get("ok"), "fixture truly consumed")
	await _bind(consumed)
	_check(panel.leave_button.disabled and panel.offer_buttons[0].disabled,
			"already consumed visit cannot reopen")
	var fresh := _visit("fresh_node")
	await _bind(fresh)
	var fresh_state := fresh.read_state()
	callback.call()
	pin_callback.call()
	leave_callback.call()
	_check(intents.is_empty() and fresh.read_state() == fresh_state,
			"retired handlers cannot act on different service")
	await _act(panel.offer_buttons[1], false)
	_check(observers[0] == 1 and intents.size() == 1,
			"independently attached observer preserved across rebind")
	# That was a permitted real signal on mounted Button; controller still
	# authenticates it, and only it can settle.
	var good := Controller.settle(fresh, intents[0], fresh_state, fresh.quote()) if intents.size() == 1 else {}
	_check(good.get("ok") == true, "fresh genuine rebind allows exactly one controller purchase")
	await _bind(_visit("close_guard"))
	var after_close: Callable = panel._connections[panel.leave_button]
	panel.close()
	after_close.call()
	_check(intents.is_empty() and panel.leave_button.disabled and not panel.visible,
			"close retires all callbacks and disables controls")
