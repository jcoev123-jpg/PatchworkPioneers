extends SceneTree
## Physical GUI and independent controller checks for the standalone Patch Stall.
const NODE := "f02_patch_stall"
const PARTY := ["warden", "seamstress", "tinker"]
const DECK := ["warden_strike", "tinker_pop_shot"]
const OWNED := ["quilted_coat"]
# Explicit authentic, unowned preview witnesses. Do not pin the power catalog's
# size or order; each tested ID is verified against the actual power projection.
const EXPECTED_SHORT := {
	"button_eye": "First successful attack/combat also gives Exposed 1",
	"pincushion_arm": "+1 damage on wearer's damaging cards",
	"switchback_button": "+2 Block once/turn after a different living hero's play",
	"quilted_coat": "+6 maximum HP",
	"padded_vest": "+4 maximum HP",
	"double_quilt_coat": "+8 maximum HP",
	"scrap_lined_vest": "+3 maximum HP",
	"wool_patch_cloak": "+5 maximum HP",
	"chain_stitched_coat": "+7 maximum HP",
	"reinforced_patchcoat": "+9 maximum HP",
	"thick_felt_mantle": "+10 maximum HP",
	"bloodstitch_bonnet": "+1 Bleed on wearer's eligible Bleed cards",
	"button_glass_visor": "+1 Exposed on wearer's eligible Exposed cards",
	"stern_seam_cap": "+1 Weak on wearer's eligible Weak cards",
	"reinforced_browband": "+2 Block on wearer's eligible Block cards",
	"hemguard_cuff": "+2 Block on wearer's eligible Block cards",
	"threadguard_wrap": "+1 Block on wearer's cards already granting Block",
	"red_bobbin_cuff": "+1 Bleed on wearer's eligible Bleed cards",
	"loose_thread_glove": "+1 Unravel on wearer's eligible Unravel cards",
	"frayfinder_mitt": "+2 first single-target hit at half Unravel, once/turn",
	"borrowed_button": "Ally's healing play gives wearer 3 Block once/combat",
	"relay_bobbin": "+1 shared energy (cap 3) when ally uses your Pin, 1/combat",
	"hearth_lining": "First earned Quilt bonus/combat heals wearer 2 HP",
}
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
	_check(root.gui_get_focus_owner() == panel.wearer_buttons[0],
		"funded pre-mount bind focuses the true first wearer selector")
	# Seed the global RNG only after Godot has mounted cosmetic UI nodes.
	seed(268)
	var expected_global := randi()
	seed(268)
	var expected_run := rng.state
	await _layout(valid)
	await _focus_cases()
	await _named_power_cases(slot_map)
	await _number_key_cases()
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
	_check_warning(visit, "seeded authentic quote")
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
		var lines := button.text.split("\n")
		_check(lines.size() == 2 and lines[0].begins_with(str(i + 1) + "  "),
			"offer caption visibly begins with its own physical/keypad number")
		_check(lines.size() == 2 and not lines[1].is_empty() 				and button.tooltip_text.contains("Torn") 				and button.tooltip_text.contains(offer["id"]),
				"real sampled quote shows an effect second line and a wearer-aware tooltip")
		if EXPECTED_SHORT.has(offer["id"]):
			_check(lines.size() == 2 and lines[1] == EXPECTED_SHORT[offer["id"]],
					"seeded offered ID uses the exact authored short power " + offer["id"])
		_check(button.get_theme_font_size("font_size") >= 20 and
				button.get_theme_color("font_color").get_luminance() > 0.6 and
				button.get_theme_stylebox("focus") != null, "readable focusable sewn choice")
		var font: Font = button.get_theme_font("font")
		var measured := font.get_multiline_string_size(
				button.text, HORIZONTAL_ALIGNMENT_CENTER, button.size.x - 24,
				button.get_theme_font_size("font_size"))
		_check(measured.x <= button.size.x - 24 and measured.y <= button.size.y - 14,
				"both text lines fit the sewn 90px action at 1280x720: " + offer["id"])
		if i > 0:
			_check(not button.get_global_rect().intersects(
					panel.offer_buttons[i - 1].get_global_rect()),
					"power-bearing patch buttons do not overlap")
	_check(screen.encloses(panel.leave_button.get_global_rect()) and
			panel.leave_button.text == "0 Leave  ·  FREE" and not panel.leave_button.disabled,
			"free Leave visibly numbered 0 and reachable")
	_check(panel.status_label.get_theme_font_size("font_size") >= 18
			and panel.status_label.get_theme_color("font_color").get_luminance() > 0.6
			and panel.status_label.text == "Choose one patch or Leave.  ·  1-3 Buy / 0 Leave",
			"footer instructions are readable 18px+ light body copy")
	_check(panel.get_global_rect().encloses(panel.status_label.get_global_rect())
			and not panel.status_label.get_global_rect().intersects(panel.leave_button.get_global_rect()),
			"footer band stays inside the sewn panel and never overlaps Leave")
	var footer_font: Font = panel.status_label.get_theme_font("font")
	if footer_font != null:
		var footer_size := footer_font.get_string_size(panel.status_label.text,
				HORIZONTAL_ALIGNMENT_LEFT, -1,
				panel.status_label.get_theme_font_size("font_size"))
		_check(footer_size.x <= panel.status_label.size.x - 4,
				"footer instructions fit their band without clipping")
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


## V3-3: initial keyboard focus follows the wallet. When no authenticated
## quoted patch is affordable (zero gold or any positive shortfall below the
## least price), Enter on arrival must address the free Leave button instead
## of the no-op wearer selector. Any affordable offer keeps the first wearer
## as the default. The boundary wallet is derived from the MINIMUM actual
## quoted offer price, never a fixed number, list order or catalog size.
func _focus_cases() -> void:
	var minimum := -1
	for offer in offers:
		var price := int(offer["price"])
		if minimum < 0 or price < minimum:
			minimum = price
	_check(minimum > 1, "seeded authentic quote admits a positive below-minimum wallet")
	if minimum <= 1:
		return
	var run_rng_before := rng.state
	# Exact-minimum wallet: the least quoted price is genuinely affordable, so
	# the first wearer stays the default and the one purchase still works.
	var threshold := _visit("focus_threshold", minimum)
	var threshold_before := threshold.read_state()
	var threshold_quote := threshold.quote()
	_check(threshold.is_valid() and threshold_quote["offers"].size() == 3,
		"exact-minimum wallet visit is a genuine three-offer service")
	var cheapest := 0
	for i in range(3):
		if int(threshold_quote["offers"][i]["price"]) == minimum:
			cheapest = i
			break
	await _bind(threshold)
	_check(root.gui_get_focus_owner() == panel.wearer_buttons[0]
			and panel.wearer_buttons[0].has_focus(),
		"exact-minimum gold keeps the first wearer selector focused")
	for i in range(3):
		_check(panel.offer_buttons[i].disabled
				== (int(threshold_quote["offers"][i]["price"]) > minimum),
			"exact-minimum wallet enables the least quote and disables the rest")
	_check(panel.wearer_buttons.all(func(pin: Button): return not pin.disabled),
		"exact-minimum wallet keeps wearer selectors available")
	_check(intents.is_empty(), "initial focus never emits an intent")
	await _act(panel.wearer_buttons[1], true, KEY_SPACE)
	_check(panel.wearer_buttons[1].text.begins_with("✕")
			and panel.wearer_buttons[1].get_meta("wearer_id") == PARTY[1],
		"exact-minimum wallet still allows choosing the purchaser")
	await _act(panel.offer_buttons[cheapest], false)
	_check(intents.size() == 1 and intents[0].get("action") == "buy_patch"
			and intents[0].get("patch_id") == threshold_quote["offers"][cheapest]["id"]
			and intents[0].get("wearer_id") == PARTY[1],
		"exact-minimum wallet buys the least quoted patch for the chosen wearer")
	if intents.size() == 1:
		var paid := Controller.settle(threshold, intents[0], threshold_before, threshold_quote)
		_check(paid.get("ok") == true and paid["receipt"]["price"] == minimum
				and paid["ledger"]["gold"] == 0
				and paid["ledger"]["deck"] == DECK
				and paid["ledger"]["trinkets"] == OWNED + [intents[0]["patch_id"]],
			"exact-minimum purchase charges the least quote exactly once")
		_check(threshold.is_consumed() and not Controller.settle(threshold,
				intents[0], threshold_before, threshold_quote).get("ok"),
			"exact-minimum purchase replay refused")
	# Zero gold: no quoted patch is affordable, so Leave takes initial focus.
	var broke := _visit("focus_zero", 0)
	var broke_before := broke.read_state()
	var broke_quote := broke.quote()
	await _bind(broke)
	_check(root.gui_get_focus_owner() == panel.leave_button
			and panel.leave_button.has_focus() and not panel.leave_button.disabled,
		"zero gold focuses the enabled free Leave button")
	_check(panel.offer_buttons.all(func(button: Button): return button.disabled),
		"zero gold keeps every quoted patch buy disabled")
	for i in range(3):
		_check(panel.offer_buttons[i].text.contains(
				"short " + str(int(broke_quote["offers"][i]["price"]))),
			"zero gold shows the exact source shortfall")
	_check(panel.wearer_buttons.all(func(pin: Button): return not pin.disabled),
		"wearer selectors remain available when broke")
	_check(broke.read_state() == broke_before and intents.is_empty(),
		"zero-gold initial focus is inert")
	await _act(panel.leave_button, true, KEY_ENTER)
	_check(intents.size() == 1, "focused Enter on Leave emits exactly one intent")
	if intents.size() == 1:
		var leave_intent := intents[0]
		_check(leave_intent.keys().size() == 4 and leave_intent.get("action") == "leave"
				and leave_intent.get("node_id") == broke_before["node_id"]
				and leave_intent.get("visit_id") == broke_before["visit_id"]
				and leave_intent.get("expected_snapshot") == broke_before["snapshot"],
			"focused Leave carries only the current broke visit binding")
		var left := Controller.settle(broke, leave_intent, broke_before, broke_quote)
		_check(left.get("ok") == true and left.get("decision") == "leave"
				and left["ledger"]["gold"] == 0
				and left["ledger"]["trinkets"] == OWNED
				and left["ledger"]["deck"] == DECK,
			"independent controller settles focused Leave with zero spend")
		_check(not Controller.settle(broke, leave_intent, broke_before, broke_quote).get("ok"),
			"focused Leave replay refused")
	# Below-minimum positive gold: still no affordable patch, Leave stays focused.
	var nearly := _visit("focus_short", minimum - 1)
	var nearly_before := nearly.read_state()
	await _bind(nearly)
	_check(minimum - 1 > 0 and root.gui_get_focus_owner() == panel.leave_button
			and panel.leave_button.has_focus()
			and panel.offer_buttons.all(func(button: Button): return button.disabled),
		"below-minimum positive gold still focuses Leave")
	_check(nearly.read_state() == nearly_before and intents.is_empty(),
		"below-minimum focus emits nothing and mutates nothing")
	# Bidirectional rebinding swaps the correct focus without side effects.
	var rich := _visit("focus_rich", minimum * 3 + 7)
	var rich_before := rich.read_state()
	await _bind(rich)
	_check(root.gui_get_focus_owner() == panel.wearer_buttons[0]
			and panel.wallet_label.text.contains("%d gold" % (minimum * 3 + 7)),
		"rebind onto an affordable quote restores the first wearer focus")
	var rebroke := _visit("focus_rebind_broke", 0)
	await _bind(rebroke)
	_check(root.gui_get_focus_owner() == panel.leave_button
			and panel.wallet_label.text.contains("0 gold"),
		"rebind onto an unaffordable quote moves focus to Leave")
	await _bind(rich)
	_check(root.gui_get_focus_owner() == panel.wearer_buttons[0],
		"rebind back onto an affordable quote returns focus to the first wearer")
	_check(rich.read_state() == rich_before and not rich.is_consumed()
			and intents.is_empty() and rng.state == run_rng_before,
		"focus rebinding never mutates service, wallet or run RNG")
	# A pre-mount bind at zero gold must still land on Leave once mounted.
	var pre := LivePatchStallPanel.new()
	pre.position = Vector2(190, 45)
	var pre_intents: Array[Dictionary] = []
	pre.intent_requested.connect(func(intent: Dictionary): pre_intents.append(intent))
	pre.bind(_visit("focus_pre_mount", 0))
	root.add_child(pre)
	await _frames()
	_check(root.gui_get_focus_owner() == pre.leave_button and pre.leave_button.has_focus(),
		"pre-mount zero-gold bind focuses Leave once mounted")
	_check(pre.offer_buttons.all(func(button: Button): return button.disabled)
			and pre.wearer_buttons.all(func(pin: Button): return not pin.disabled)
			and pre_intents.is_empty(),
		"pre-mount rebound broke panel stays inert with selectors available")
	pre.queue_free()
	await process_frame


## V3-3: the physical number keys are only an alias for the same authenticated
## Button.pressed path the mouse and Enter use: every numbered case drives a
## real InputEventKey through the mounted panel, matches the exact
## pressed-button intent schema and settles through the independent controller.
func _number_key_cases() -> void:
	var normal_keys := [KEY_1, KEY_2, KEY_3]
	var keypad_keys := [KEY_KP_1, KEY_KP_2, KEY_KP_3]
	# Funded wallet: 1-3 (normal and keypad) buy the exact quoted offer for the
	# currently chosen wearer; the selected party wearer is preserved.
	for chosen in range(3):
		for option in range(3):
			var visit := _visit("keys_buy_%d_%d" % [chosen, option])
			var before := visit.read_state()
			var quote := visit.quote()
			_check(visit.is_valid() and quote["offers"].size() == 3,
				"keyed buy fixture is a genuine funded three-offer service")
			await _bind(visit)
			await _act(panel.wearer_buttons[chosen], true, KEY_SPACE)
			_check(panel.wearer_buttons[chosen].text.begins_with("✕")
				and panel.wearer_buttons[chosen].get_meta("wearer_id") == PARTY[chosen],
				"keyed buy keeps a real chosen wearer before the number key")
			var code: Key = normal_keys[option] if (chosen + option) % 2 == 0 else keypad_keys[option]
			_check(panel.offer_buttons[option].text.begins_with(str(option + 1) + "  ")
				and panel.leave_button.text == "0 Leave  ·  FREE",
				"keyed buy dispatches the button that visibly shows its own number")
			await _key(code)
			_check(intents.size() == 1, "physical number key emits exactly one buy intent")
			if intents.size() == 1:
				var intent := intents[0]
				_check(intent.keys().size() == 6 and intent.get("action") == "buy_patch"
					and intent.get("patch_id") == quote["offers"][option]["id"]
					and intent.get("wearer_id") == PARTY[chosen]
					and intent.get("node_id") == before["node_id"]
					and intent.get("visit_id") == before["visit_id"]
					and intent.get("expected_snapshot") == before["snapshot"],
					"keyed buy intent matches the pressed-button schema for the chosen wearer")
				var receipt := Controller.settle(visit, intent, before, quote)
				var expected := {"kind": "trinket", "id": intent["patch_id"],
					"price": quote["offers"][option]["price"]}
				_check(receipt.get("ok") == true and receipt.get("decision") == "buy_patch"
					and receipt["receipt"] == expected
					and receipt["ledger"]["gold"] == 240 - quote["offers"][option]["price"]
					and receipt["ledger"]["trinkets"] == OWNED + [intent["patch_id"]],
					"independent controller settles the keyed buy once at the quoted price")
			await _key(code)
			_check(intents.size() == 1 and visit.is_consumed()
				and not Controller.settle(visit, intents[0], before, quote).get("ok"),
				"keyed replay after submission emits nothing and cannot settle twice")
	# Zero-gold wallet: only the free Leave answers; numbered buys stay inert.
	var broke := _visit("keys_broke", 0)
	var broke_before := broke.read_state()
	var broke_quote := broke.quote()
	await _bind(broke)
	_check(panel.offer_buttons.all(func(button: Button): return button.disabled)
		and not panel.leave_button.disabled,
		"broke keyed fixture leaves only the free exit actionable")
	for code in [KEY_1, KEY_2, KEY_3, KEY_KP_1, KEY_KP_2, KEY_KP_3]:
		await _key(code)
	_check(intents.is_empty() and broke.read_state() == broke_before
		and broke.quote() == broke_quote,
		"unaffordable numbered buys emit nothing and mutate no state")
	_check(panel.leave_button.text == "0 Leave  ·  FREE",
		"physical 0 label sits on the free Leave button")
	await _key(KEY_0)
	_check(intents.size() == 1, "physical 0 emits exactly one Leave intent")
	if intents.size() == 1:
		var leave_intent := intents[0]
		_check(leave_intent.keys().size() == 4 and leave_intent.get("action") == "leave"
			and leave_intent.get("node_id") == broke_before["node_id"]
			and leave_intent.get("visit_id") == broke_before["visit_id"]
			and leave_intent.get("expected_snapshot") == broke_before["snapshot"],
			"keyed Leave intent matches the pressed-button schema")
		var left := Controller.settle(broke, leave_intent, broke_before, broke_quote)
		_check(left.get("ok") == true and left.get("decision") == "leave"
			and left["ledger"]["gold"] == 0 and left["ledger"]["trinkets"] == OWNED
			and left["ledger"]["deck"] == DECK,
			"independent controller settles keyed zero-gold Leave with zero spend")
	await _key(KEY_KP_0)
	_check(intents.size() == 1 and broke.is_consumed()
		and not Controller.settle(broke, intents[0], broke_before, broke_quote).get("ok"),
		"keyed Leave replay refused after submission")
	# Funded wallet: keypad 0 also leaves for free without spending anything.
	var funded := _visit("keys_leave_funded")
	var funded_before := funded.read_state()
	var funded_quote := funded.quote()
	await _bind(funded)
	await _key(KEY_KP_0)
	_check(intents.size() == 1, "keypad 0 leaves a funded stall too")
	if intents.size() == 1:
		var funded_left := Controller.settle(funded, intents[0], funded_before, funded_quote)
		_check(funded_left.get("ok") == true and funded_left["ledger"]["gold"] == 240
			and funded_left["ledger"]["trinkets"] == OWNED
			and funded_left["ledger"]["deck"] == DECK,
			"keyed funded Leave spends no gold and grants no patch")
	# Negative guards: releases, echoes, modifiers, unrelated keys, foreign
	# focus and hidden/detached/closed/rebound panels never mint an intent.
	await _number_key_guards()


## One authentic physical key press followed by its release, with optional
## per-event property overrides for the negative variants.
func _key(code: Key, changes: Dictionary = {}) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		for property in changes:
			event.set(property, changes[property])
		root.push_input(event)
		await process_frame
	await _frames()


func _reject_key(code: Key, reason: String, changes: Dictionary = {}) -> void:
	var count := intents.size()
	await _key(code, changes)
	_check(intents.size() == count,
		reason + " emits no Patch Stall intent: " + str(code))


func _number_key_guards() -> void:
	var visit := _visit("keys_guards")
	var before := visit.read_state()
	var quote := visit.quote()
	await _bind(visit)
	_check(panel.status_label.text.contains("1-3 Buy") and panel.status_label.text.contains("0 Leave"),
		"open status line advertises the numbered shortcuts")
	panel.wearer_buttons[1].grab_focus()
	await _frames()
	_check(panel.wearer_buttons[1].has_focus(), "key guard fixture focuses a panel control")
	for code in [KEY_1, KEY_2, KEY_3, KEY_0, KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_0]:
		for changes in [{"echo": true}, {"pressed": false}, {"shift_pressed": true},
				{"ctrl_pressed": true}, {"alt_pressed": true}, {"meta_pressed": true}]:
			await _reject_key(code, "echo/release/modified number key", changes)
	for code in [KEY_4, KEY_5, KEY_9, KEY_KP_4, KEY_P, KEY_ESCAPE]:
		await _reject_key(code, "unrelated key")
	# Focus owned by a control outside this panel: the key is never stolen.
	var outside := Button.new()
	root.add_child(outside)
	outside.grab_focus()
	_check(outside.has_focus() and not panel.is_ancestor_of(outside),
		"guard fixture moves focus outside the Patch Stall")
	for code in [KEY_1, KEY_2, KEY_3, KEY_0, KEY_KP_2, KEY_KP_0]:
		await _reject_key(code, "focus outside the panel")
	outside.free()
	# Hidden and detached panels never act on number keys.
	panel.wearer_buttons[1].grab_focus()
	panel.hide()
	for code in [KEY_1, KEY_2, KEY_3, KEY_0]:
		await _reject_key(code, "hidden panel")
	panel.show()
	await _frames()
	panel.wearer_buttons[1].grab_focus()
	root.remove_child(panel)
	for code in [KEY_1, KEY_0]:
		await _reject_key(code, "detached panel")
	root.add_child(panel)
	await _frames()
	# An invalid or already consumed rebound service disables every key.
	var invalid := RunPatchStallVisit.new("", PARTY, DECK, OWNED, 240, offers)
	_check(not invalid.is_valid(), "guard fixture is a real invalid service")
	await _bind(invalid)
	for code in [KEY_1, KEY_2, KEY_3, KEY_0, KEY_KP_1, KEY_KP_0]:
		await _reject_key(code, "invalid rebound service")
	var consumed := _visit("keys_guards_used")
	var consumed_state := consumed.read_state()
	_check(consumed.leave(consumed_state["visit_id"], consumed_state["node_id"],
		consumed_state["snapshot"]).get("ok"), "guard fixture truly consumed")
	await _bind(consumed)
	for code in [KEY_1, KEY_3, KEY_0]:
		await _reject_key(code, "consumed rebound visit")
	# A closed panel is inert even while its controls stay mounted.
	await _bind(_visit("keys_close_guard"))
	panel.close()
	for code in [KEY_1, KEY_2, KEY_3, KEY_0, KEY_KP_3, KEY_KP_0]:
		await _reject_key(code, "closed panel")
	_check(visit.read_state() == before and visit.quote() == quote
		and not visit.is_consumed(),
		"rejected number keys never mutate the guarded visit")


## Bind every named, authored power as a genuine three-offer service quote,
## with prices deliberately different from ordinary stock's 100. The quote's
## order and wallet, never test position or catalog counts, govern the UI.
func _named_power_cases(power_slots: Dictionary) -> void:
	var names: Array = EXPECTED_SHORT.keys()
	names.sort()
	var rare_source: Variant = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/patches/mpw_synergy_patches.json"))
	_check(typeof(rare_source) == TYPE_ARRAY and rare_source.size() >= 2,
			"authored P8 rare power catalog exists")
	_check(not power_slots.has("stitched_badge") and not power_slots.has("spare_spool"),
			"Shop-only starter slot modifiers are not Patch Stall power stock")
	for id in names:
		_check(power_slots.has(id) and power_slots[id] in ["HEAD", "ARM", "COAT"],
				"named power fixture belongs to real validated power catalog: " + id)
	for start in range(0, names.size(), 3):
		var trio: Array = []
		for offset in range(3):
			trio.append(names[(start + offset) % names.size()])
		var records := [
			{"id": trio[0], "price": 61},
			{"id": trio[1], "price": 82},
			{"id": trio[2], "price": 113},
		]
		var visit := RunPatchStallVisit.new("named_powers_%d" % start,
				PARTY, DECK, [], 70, records)
		var before := visit.read_state()
		var quote := visit.quote()
		_check(visit.is_valid() and quote.get("offers", []).size() == 3
				and quote.get("decisions") == ["buy_patch", "leave"],
				"three genuine unsold named offers for " + str(start))
		if not visit.is_valid():
			continue
		await _bind(visit)
		_check(panel.offer_buttons.size() == 3 and panel.wearer_buttons.size() == 3,
				"named genuine visit has three purchase and wearer controls")
		_check_warning(visit, "named trio %d" % start)
		for i in range(3):
			var id: String = trio[i]
			var action := panel.offer_buttons[i]
			var quoted: Dictionary = quote["offers"][i]
			var lines := action.text.split("\n")
			_check(lines.size() == 2 and lines[0].begins_with(str(i + 1) + "  "),
				"named power caption visibly begins with its own number: " + id)
			_check(quoted["id"] == id and not quoted["sold"] and
					quote["offers"][i]["price"] == records[i]["price"],
					"genuine quote retains named ID, order and unique authored fixture price")
			_check(lines.size() == 2 and lines[0].contains(id) 					and lines[0].contains(id.replace("_", " ").capitalize()) 					and lines[0].contains(power_slots[id]) 					and lines[0].contains(str(quoted["price"]) + " gold") 					and lines[1] == EXPECTED_SHORT[id],
					"authentic slot, quote price, and exact power second line: " + id)
			_check(action.disabled == (quoted["price"] > 70) and
					(action.text.contains("short %d" % (quoted["price"] - 70)) 						if quoted["price"] > 70 else not action.text.contains("short ")),
					"independent dynamic shortfall and affordability for " + id)
			var tooltip: String = action.tooltip_text
			_check(tooltip.contains(id) and tooltip.contains("Torn") 					and not tooltip.contains(panel.DETAILS_UNAVAILABLE),
					"known power has actual conditions rather than unavailable copy: " + id)
			if RunPatchWearerSummary.KNOWN_TEXTS.has(id):
				_check(tooltip.contains(RunPatchWearerSummary.KNOWN_TEXTS[id]),
						"full audited catalog description unabridged: " + id)
			elif CombatShopPatchRules.EFFECTS.has(id):
				var authority: Dictionary = RunPatchWearerSummary._authority({})
				var full := RunPatchWearerSummary._resolve_rules_text(id, authority["slots"])
				_check(not full.is_empty() and tooltip.contains(full),
						"shop modifier uses authoritative amount, owner and living restrictions")
			elif id == "relay_bobbin":
				_check(tooltip.contains("Once per combat") and tooltip.contains("different living hero")
						and tooltip.contains("Pinned") and tooltip.contains("living, untorn")
						and tooltip.contains("confirmed receipt") and tooltip.contains("+1 shared energy")
						and tooltip.contains("capped at 3"),
						"P8 Relay trigger, source, receipt, cap and per-combat limit")
			elif id == "hearth_lining":
				_check(tooltip.contains("Once per combat") and tooltip.contains("first EARNED Quilt")
						and tooltip.contains("living, untorn") and tooltip.contains("2 HP")
						and tooltip.contains("maximum HP"),
						"P8 Hearth earned-only, living/untorn, max-capped once/combat heal")
			var font: Font = action.get_theme_font("font")
			var size_text := font.get_multiline_string_size(
					action.text, HORIZONTAL_ALIGNMENT_CENTER, action.size.x - 24,
					action.get_theme_font_size("font_size"))
			_check(size_text.x <= action.size.x - 24 and size_text.y <= action.size.y - 14,
					"named source text actually fits 90px button: " + id)
		_check(panel.leave_button.text.contains("FREE") and not panel.leave_button.disabled,
				"Leave remains free alongside mixed-price previews")
		_check(visit.read_state() == before and visit.quote() == quote and intents.is_empty(),
				"named preview and disabled options do not mutate ledger or emit")
	# Deliberately inconsistent source records must not claim any known power.
	var attack: Variant = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/patches/m04_attack_patches.json"))
	_check(attack is Array and attack.size() > 0, "real attack fixture available to corrupt")
	if attack is Array and not attack.is_empty():
		attack[0]["amount"] = 99
		var wrong := panel._trusted_power_previews(power_slots, {"attack": attack})
		_check(not wrong.has("button_eye") and not wrong.has("pincushion_arm") 				and not wrong.has("switchback_button"),
				"contradictory authored amount refuses all unauthenticated M04 powers")
	var wrong_slots := panel._trusted_power_previews({"button_eye": "ARM",
			"relay_bobbin": "COAT", "invented_patch": "HEAD"})
	_check(not wrong_slots.has("button_eye") and not wrong_slots.has("relay_bobbin") 			and not wrong_slots.has("invented_patch"),
			"unsupported or slot-contradictory IDs receive no made-up effect")
	if rare_source is Array:
		var corrupted: Array = rare_source.duplicate(true)
		for record in corrupted:
			if record.get("id") == "relay_bobbin":
				record["shared_energy_cap"] = 8
			if record.get("id") == "hearth_lining":
				record["requires_earned_bonus"] = false
		var wrong_rares := panel._trusted_power_previews(power_slots, {}, corrupted)
		_check(not wrong_rares.has("relay_bobbin") and not wrong_rares.has("hearth_lining"),
				"rare wrong energy cap or unearned Quilt condition cannot be advertised")
	# A real quoted visit with unknown power stock fails at bind rather than
	# creating a fictitious click or hiding its authoritative identity.
	var unknown := RunPatchStallVisit.new("unsupported_patch", PARTY, DECK, [], 70,
			[{"id": "unpublished_power", "price": 20},
				{"id": "button_eye", "price": 82}, {"id": "relay_bobbin", "price": 113}])
	_check(unknown.is_valid(), "synthetic unknown source still a valid shop service")
	await _bind(unknown)
	_check(panel.offer_buttons.all(func(b: Button): return b.disabled) 			and panel.leave_button.disabled and intents.is_empty(),
			"unknown unauthenticated power cannot produce a clickable quote")

func slot_map_for(id: String) -> String:
	for record in RunAuthoredPatchDefinitions.load_power_definitions():
		if record["id"] == id:
			return record["slot"]
	return ""

## Independently authored copy of the irreversibility warning. The panel states
## the rule, not any hero's live loadout, because a visit carries no wardrobe.
func _slot_warning(slot: String) -> String:
	return "%s slot: a patch already worn in this slot is destroyed for exactly +1 scrap.\nA free %s slot destroys nothing and gains no scrap." % [slot, slot]

## The warning must be always visible AND truthful for every offered patch, in
## the quote's own order: each tooltip names only that patch's authored slot and
## explains both the occupied-slot (+1 scrap, destruction) and free-slot outcomes.
func _check_warning(visit: RunPatchStallVisit, tag: String) -> void:
	var header: Label = panel.wearer_label
	var header_text: String = header.text if header != null else ""
	_check(header != null and header.is_visible_in_tree()
			and header_text == LivePatchStallPanel.WEARER_WARNING
			and header_text.contains("same-slot") and header_text.contains("destroyed")
			and header_text.contains("+1 scrap")
			and header.get_theme_font_size("font_size") >= 20
			and header.get_theme_color("font_color").get_luminance() > 0.6,
			"always-visible readable header warns of same-slot destruction for +1 scrap: " + tag)
	for hero in PARTY:
		_check(header_text.find(hero.capitalize()) < 0,
				"header states the sewing rule, not a guessed live wearer: " + tag)
	if header != null:
		var font: Font = header.get_theme_font("font")
		var measured := font.get_string_size(header_text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				header.get_theme_font_size("font_size"))
		_check(measured.x <= header.size.x - 4,
				"compact header warning is not clipped at 1280x720: " + tag)
		_check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(header.get_global_rect()),
				"header warning lies inside the mounted panel: " + tag)
	var quote := visit.quote()
	_check(quote.get("offers", []).size() == 3 and panel.offer_buttons.size() == 3,
			"warning fixture is a genuine three-offer quote: " + tag)
	for i in range(quote.get("offers", []).size()):
		var id: String = quote["offers"][i]["id"]
		var slot := slot_map_for(id)
		var text: String = panel.offer_buttons[i].tooltip_text
		var warning := _slot_warning(slot)
		var lines := text.split("\n")
		_check(slot in ["HEAD", "ARM", "COAT"] and text.contains("[%s]" % id) and text.contains("Torn")
				and text.ends_with("Patch powers do not work while the wearer is Torn.\n" + warning)
				and lines[0].begins_with(id.replace("_", " ").capitalize())
				and not lines[1].is_empty(),
				"tooltip keeps patch ID, authored power and Torn caveat, then the quoted %s slot rule: %s" % [slot, id])
		_check(warning.contains("destroyed for exactly +1 scrap") and warning.contains("destroys nothing")
				and warning.contains("gains no scrap") and warning.contains(slot),
				"warning states destruction, exactly +1 scrap and empty-slot non-replacement: " + id)
		for other in ["HEAD", "ARM", "COAT"]:
			if other != slot:
				_check(not text.contains("%s slot:" % other),
						"tooltip warning names only its own %s slot, never %s: %s" % [slot, other, id])

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
	_check_warning(visit, "after choosing wearer %d" % wearer)
	var old_quote := visit.quote()
	var old_state := visit.read_state()
	await _act(panel.offer_buttons[index], not keyboard, KEY_ENTER)
	_check(intents.size() == 1, "exactly one quoted button intent")
	_check_warning(visit, "after patch activation %d" % index)
	_check(panel.wearer_label.text == LivePatchStallPanel.WEARER_WARNING
			and panel.wearer_label.is_visible_in_tree(),
			"same-slot warning still shown once the intent is sent")
	_check(not visit.read_state()["snapshot"]["owned_trinkets"].has(quote["offers"][index]["id"])
			and visit.quote()["offers"][index]["sold"] == false,
			"view activation is an intent only, never a direct purchase")
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
	var saved_caption := offer_button.text
	offer_button.text += "  +999 damage"
	callback.call()
	_check(intents.is_empty(), "forged effect-bearing caption rejected by auth")
	offer_button.text = saved_caption
	var saved_tooltip := offer_button.tooltip_text
	offer_button.tooltip_text = "+999 damage on every card"
	callback.call()
	_check(intents.is_empty(), "forged full-power tooltip rejected by auth")
	offer_button.tooltip_text = saved_tooltip
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
	_check_warning(fresh, "after rebind")
	var fresh_state := fresh.read_state()
	callback.call()
	pin_callback.call()
	leave_callback.call()
	_check(intents.is_empty() and fresh.read_state() == fresh_state,
			"retired handlers cannot act on different service")
	await _act(panel.offer_buttons[1], false)
	_check(observers[0] == 1 and intents.size() == 1,
			"independently attached observer preserved across rebind")
	_check_warning(fresh, "after rebind activation")
	_check(fresh.read_state() == fresh_state and not fresh.is_consumed() \
			and not fresh_state["snapshot"]["owned_trinkets"].has(fresh.quote()["offers"][1]["id"]),
			"rebound warning plus physical click emits only the source-bound intent")
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
