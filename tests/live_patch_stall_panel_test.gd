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
	await _atmosphere_cases(valid)
	await _backdrop_motion_cases(valid)
	await _focus_cases()
	await _named_power_cases(slot_map)
	await _number_key_cases()
	for chosen in range(3):
		for option in range(3):
			await _buy_case(chosen, option, (chosen + option) % 2 == 0)
	await _leave_case(false, true)
	await _leave_case(true, false)
	await _fail_closed()
	await _scarce_stock_cases(slot_map)
	await _unlocked_heirloom_cases(slot_map)
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
	var heirloom_source: Variant = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/patches/mpw_heirloom_patches.json"))
	_check(heirloom_source is Array and heirloom_source.size() >= 2,
			"authored P12 heirloom catalog exists")
	var eligible_slots := {}
	for record in RunAuthoredPatchDefinitions.load_eligible_power_definitions(true):
		eligible_slots[record["id"]] = record["slot"]
	_check(eligible_slots.has("needle_echo") and eligible_slots["needle_echo"] == "HEAD",
			"eligible power projection knows needle_echo in HEAD slot")
	_check(eligible_slots.has("shared_hem") and eligible_slots["shared_hem"] == "ARM",
			"eligible power projection knows shared_hem in ARM slot")
	var canonical_heirlooms := panel._trusted_power_previews(eligible_slots, {}, null, heirloom_source)
	_check(canonical_heirlooms.has("needle_echo") and canonical_heirlooms.has("shared_hem"),
			"canonical heirloom catalog provides previews for needle_echo and shared_hem")
	if canonical_heirlooms.has("needle_echo"):
		_check(canonical_heirlooms["needle_echo"]["short"] == LivePatchStallPanel.NEEDLE_ECHO_SHORT,
				"needle_echo short text matches canonical specification")
		_check(canonical_heirlooms["needle_echo"]["full"] == LivePatchStallPanel.NEEDLE_ECHO_FULL,
				"needle_echo full tooltip matches canonical specification")
	if canonical_heirlooms.has("shared_hem"):
		_check(canonical_heirlooms["shared_hem"]["short"] == LivePatchStallPanel.SHARED_HEM_SHORT,
				"shared_hem short text matches canonical specification")
		_check(canonical_heirlooms["shared_hem"]["full"] == LivePatchStallPanel.SHARED_HEM_FULL,
				"shared_hem full tooltip matches canonical specification")
	if heirloom_source is Array:
		var corrupted_amount: Array = heirloom_source.duplicate(true)
		for record in corrupted_amount:
			if record.get("id") == "needle_echo":
				record["bonus_damage"] = 99
			if record.get("id") == "shared_hem":
				record["block"] = 99
		var wrong_amount := panel._trusted_power_previews(eligible_slots, {}, null, corrupted_amount)
		_check(not wrong_amount.has("needle_echo") and not wrong_amount.has("shared_hem"),
				"corrupted heirloom bonus_damage/block amount refuses power preview")

		var corrupted_trigger: Array = heirloom_source.duplicate(true)
		for record in corrupted_trigger:
			if record.get("id") == "needle_echo":
				record["trigger"] = "wrong_trigger"
			if record.get("id") == "shared_hem":
				record["trigger"] = "wrong_trigger"
		var wrong_trigger := panel._trusted_power_previews(eligible_slots, {}, null, corrupted_trigger)
		_check(not wrong_trigger.has("needle_echo") and not wrong_trigger.has("shared_hem"),
				"corrupted heirloom trigger refuses power preview")

		var corrupted_slot: Array = heirloom_source.duplicate(true)
		for record in corrupted_slot:
			if record.get("id") == "needle_echo":
				record["slot"] = "ARM"
			if record.get("id") == "shared_hem":
				record["slot"] = "HEAD"
		var wrong_cat_slot := panel._trusted_power_previews(eligible_slots, {}, null, corrupted_slot)
		_check(not wrong_cat_slot.has("needle_echo") and not wrong_cat_slot.has("shared_hem"),
				"mismatched heirloom catalog slot refuses power preview")

		var wrong_map := eligible_slots.duplicate()
		wrong_map["needle_echo"] = "ARM"
		wrong_map["shared_hem"] = "HEAD"
		var wrong_slot_previews := panel._trusted_power_previews(wrong_map, {}, null, heirloom_source)
		_check(not wrong_slot_previews.has("needle_echo") and not wrong_slot_previews.has("shared_hem"),
				"mismatched slot mapping refuses power preview")

		var duplicate_catalog: Array = heirloom_source.duplicate(true)
		for record in heirloom_source:
			if record.get("id") == "needle_echo":
				duplicate_catalog.append(record.duplicate(true))
		var dup_previews := panel._trusted_power_previews(eligible_slots, {}, null, duplicate_catalog)
		_check(not dup_previews.has("needle_echo"),
				"duplicate heirloom catalog record refuses power preview")
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


## V3-3 late-run scarcity: every priced catalog power is already owned except
## the authored button_eye and pincushion_arm. The seeded sampler must keep the
## opened stall genuinely buyable: both remaining unowned choices stay
## purchasable at their authored 100-gold prices and the third slot is a
## truthful already-owned SOLD fallback row. The run RNG advances only for the
## two real stock draws, the sorted fallback completion consumes none, and
## same-seed replay reproduces the exact stock while the three-plus-unowned
## fixture keeps its prior reference output and RNG sequence untouched.
func _scarce_stock_cases(power_slots: Dictionary) -> void:
	var route_rng_before := rng.state
	var authored: Variant = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/shop/initial_offers.json"))
	if typeof(authored) != TYPE_DICTIONARY or not authored.has("trinkets"):
		_check(false, "scarce fixture needs the shipped priced catalog")
		return
	var scarce_owned: Array = []
	var priced_powers := 0
	for listing in authored["trinkets"]:
		if typeof(listing) != TYPE_DICTIONARY:
			continue
		var listing_id: Variant = listing.get("id")
		if typeof(listing_id) != TYPE_STRING or not power_slots.has(listing_id):
			continue
		priced_powers += 1
		if listing_id != "button_eye" and listing_id != "pincushion_arm":
			scarce_owned.append(listing_id)
	_check(power_slots.has("button_eye") and power_slots.has("pincushion_arm"),
			"the two named unowned witnesses are genuine priced catalog powers")
	_check(priced_powers >= 3 and not scarce_owned.has("button_eye")
				and not scarce_owned.has("pincushion_arm") and scarce_owned.size() >= 1,
			"scarce fixture owns every priced power except the two named witnesses")
	var seed_value := 314159
	var stall_rng := RandomNumberGenerator.new()
	stall_rng.seed = seed_value
	var sampled := RunShopPurchases.sample_patch_stall_offers(stall_rng,
		authored["trinkets"], scarce_owned)
	_check(sampled.get("ok") == true and sampled.get("offers") is Array
				and sampled["offers"].size() == 3,
			"seeded scarce sampler still stocks three distinct power patches")
	if sampled.get("ok") != true or sampled.get("offers", []).size() != 3:
		return
	var scarce_offers: Array = sampled["offers"]
	var seen_ids := {}
	var owned_rows := 0
	var unowned_ids: Array = []
	for offer in scarce_offers:
		_check(typeof(offer.get("id")) == TYPE_STRING and not seen_ids.has(offer["id"]),
			"scarce stock keeps three distinct power IDs")
		seen_ids[offer["id"]] = true
		if scarce_owned.has(offer["id"]):
			owned_rows += 1
		else:
			unowned_ids.append(offer["id"])
		var listed := false
		for entry in authored["trinkets"]:
			if entry["id"] == offer["id"] and int(entry["price"]) == offer["price"]:
				listed = true
		_check(listed and typeof(offer.get("price")) == TYPE_INT and offer["price"] == 100,
			"scarce offer keeps its original authored 100-gold price: " + str(offer["id"]))
	_check(owned_rows == 1 and unowned_ids.size() == 2
				and unowned_ids.has("button_eye") and unowned_ids.has("pincushion_arm"),
			"exactly one sold fallback completes the two named buyable choices")
	_check(scarce_owned.has(scarce_offers[2]["id"]),
			"the third scarce slot is the already-owned sold fallback")
	# Independent twin oracle: the same two sorted real stock draws, then the
	# sorted first owned priced candidate. Its twin RNG proves the fallback
	# completion consumes no run RNG beyond the genuine stock draws.
	var oracle := RandomNumberGenerator.new()
	oracle.seed = seed_value
	var rare_ids := {}
	var rare_json: Variant = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/patches/mpw_synergy_patches.json"))
	if typeof(rare_json) == TYPE_ARRAY:
		for record in rare_json:
			if typeof(record) == TYPE_DICTIONARY and typeof(record.get("id")) == TYPE_STRING:
				rare_ids[record["id"]] = true
	var eligible: Array = ["button_eye", "pincushion_arm"]
	eligible.sort()
	var expected: Array = []
	var total := 200
	for i in range(2):
		var ticket: int = oracle.randi_range(0, total - 1)
		var walked := 0
		var chosen := ""
		for id in eligible:
			walked += 100
			if ticket < walked:
				chosen = id
				break
		expected.append({"id": chosen, "price": 100})
		total -= 100
		eligible.erase(chosen)
	var fallback_sorted: Array = []
	for listing in authored["trinkets"]:
		if scarce_owned.has(listing["id"]) and not rare_ids.has(listing["id"]):
			fallback_sorted.append(listing["id"])
	fallback_sorted.sort()
	_check(not fallback_sorted.is_empty(), "scarce oracle has a priced owned fallback")
	expected.append({"id": fallback_sorted[0], "price": 100})
	_check(scarce_offers == expected,
			"scarce stock matches the independent seeded and sorted oracle")
	_check(stall_rng.state == oracle.state,
			"scarce run RNG advances only for the two real stock draws")
	var replay_rng := RandomNumberGenerator.new()
	replay_rng.seed = seed_value
	var replay := RunShopPurchases.sample_patch_stall_offers(replay_rng,
		authored["trinkets"], scarce_owned)
	_check(replay == sampled and replay_rng.state == stall_rng.state,
			"same-seed replay restocks the identical scarce quote and RNG state")
	# The untouched three-plus-unowned fixture keeps its exact prior reference.
	var reference_rng := RandomNumberGenerator.new()
	reference_rng.seed = 2680268
	var reference := RunShopPurchases.sample_patch_stall_offers(reference_rng,
		authored["trinkets"], OWNED)
	_check(reference.get("ok") == true and reference.get("offers") == offers,
			"three-plus-unowned stock keeps the exact prior reference output")
	_check(reference_rng.state == rng.state,
			"three-plus-unowned stock keeps the exact prior run RNG sequence")
	# Mounted scarce stall: the funded visit advertises all three offers plus
	# Leave; the owned fallback row is visibly SOLD and unclickable by mouse,
	# number key, focus and callback, while either unowned choice buys once.
	var visit := RunPatchStallVisit.new("scarce_funded", PARTY, DECK,
		scarce_owned.duplicate(true), 240, scarce_offers.duplicate(true))
	var before := visit.read_state()
	var quote := visit.quote()
	_check(visit.is_valid() and quote["offers"].size() == 3
				and quote.get("decisions") == ["buy_patch", "leave"],
			"scarce funded visit is a genuine three-offer service")
	var sold_index := -1
	var sold_flags := 0
	for i in range(3):
		if quote["offers"][i]["sold"] == true:
			sold_index = i
			sold_flags += 1
	var buyable: Array = []
	for i in range(3):
		if i != sold_index:
			buyable.append(i)
	_check(sold_flags == 1 and sold_index == 2
				and quote["offers"][sold_index]["id"] == scarce_offers[2]["id"],
			"admission marks exactly the already-owned fallback sold")
	await _bind(visit)
	_check_warning(visit, "scarce funded quote")
	_check(panel.offer_buttons[sold_index].disabled
				and panel.offer_buttons[sold_index].text.contains("SOLD")
				and not panel.offer_buttons[sold_index].text.contains("gold"),
			"owned fallback row shows SOLD with no payable price or action")
	for i in buyable:
		_check(panel.offer_buttons[i].is_visible_in_tree()
					and not panel.offer_buttons[i].disabled
					and panel.offer_buttons[i].text.contains("100 gold"),
				"remaining unowned 100-gold choices stay visible and active: "
					+ str(scarce_offers[i]["id"]))
	_check(panel.wearer_buttons.size() == 3
				and panel.wearer_buttons.all(func(pin: Button): return not pin.disabled)
				and not panel.leave_button.disabled
				and panel.leave_button.text == "0 Leave  ·  FREE",
			"three wearer selectors and the free Leave remain available")
	_check(root.gui_get_focus_owner() == panel.wearer_buttons[0],
			"affordable scarce stall focuses the first wearer selector")
	# Rejections: mouse press, numeric key and a direct service purchase on the
	# SOLD row change nothing.
	panel.offer_buttons[sold_index].pressed.emit()
	await _frames()
	await _key([KEY_1, KEY_2, KEY_3][sold_index])
	_check(intents.is_empty() and visit.read_state() == before
				and visit.quote() == quote and not visit.is_consumed(),
			"SOLD row presses and its number key emit no intent and mutate nothing")
	_check(not visit.buy_patch(quote["offers"][sold_index]["id"], before["visit_id"],
				before["node_id"], before["snapshot"]).get("ok"),
			"direct SOLD-row purchase is refused by the one-use service")
	# Poor wallet: no receipt, no gold loss and no route RNG change.
	var poor := RunPatchStallVisit.new("scarce_poor", PARTY, DECK,
		scarce_owned.duplicate(true), 50, scarce_offers.duplicate(true))
	var poor_before := poor.read_state()
	var poor_quote := poor.quote()
	await _bind(poor)
	_check(panel.offer_buttons.all(func(button: Button): return button.disabled),
			"poor scarce wallet disables every patch row including the SOLD fallback")
	for i in buyable:
		_check(panel.offer_buttons[i].text.contains("short 50"),
				"poor unsold rows show the exact shortfall")
	_check(root.gui_get_focus_owner() == panel.leave_button
				and panel.leave_button.has_focus(),
			"poor scarce stall focuses the free Leave as the only exit")
	await _key([KEY_1, KEY_2, KEY_3][buyable[0]])
	await _key([KEY_KP_1, KEY_KP_2, KEY_KP_3][sold_index])
	_check(intents.is_empty() and poor.read_state() == poor_before
				and poor.quote() == poor_quote and not poor.is_consumed(),
			"unaffordable scarce buys emit nothing and mutate no state")
	_check(not poor.buy_patch(scarce_offers[buyable[0]]["id"], poor_before["visit_id"],
				"scarce_poor", poor_before["snapshot"]).get("ok")
				and poor.read_state()["snapshot"]["gold"] == 50,
			"poor-wallet buy leaves no receipt and no gold loss")
	await _key(KEY_0)
	_check(intents.size() == 1, "free 0 Leave still answers the poor scarce stall")
	if intents.size() == 1:
		var left := Controller.settle(poor, intents[0], poor_before, poor_quote)
		_check(left.get("ok") == true and left.get("decision") == "leave"
					and left["ledger"]["gold"] == 50
					and left["ledger"]["trinkets"] == scarce_owned
					and left["ledger"]["deck"] == DECK,
				"poor scarce Leave settles once with zero spend")
		_check(not Controller.settle(poor, intents[0], poor_before, poor_quote).get("ok"),
				"poor scarce Leave replay refused")
	# One genuine purchase: choose a wearer, buy either unowned choice once
	# through the existing intent path; replay and stale presses fail.
	await _bind(visit)
	await _act(panel.wearer_buttons[2], true, KEY_SPACE)
	var buy_row: int = buyable[0]
	var stale: Callable = panel._connections[panel.offer_buttons[buy_row]]
	await _act(panel.offer_buttons[buy_row], false)
	_check(intents.size() == 1,
			"one affordable unsold scarce choice emits exactly one intent")
	if intents.size() == 1:
		var intent := intents[0]
		_check(intent.keys().size() == 6 and intent.get("action") == "buy_patch"
					and intent.get("patch_id") == scarce_offers[buy_row]["id"]
					and intent.get("wearer_id") == PARTY[2]
					and intent.get("node_id") == before["node_id"]
					and intent.get("visit_id") == before["visit_id"]
					and intent.get("expected_snapshot") == before["snapshot"],
				"scarce buy intent matches the exact existing source-bound schema")
		var receipt := Controller.settle(visit, intent, before, quote)
		_check(receipt.get("ok") == true and receipt.get("decision") == "buy_patch"
					and receipt["receipt"] == {"kind": "trinket",
							"id": scarce_offers[buy_row]["id"], "price": 100}
					and receipt["ledger"]["gold"] == 140
					and receipt["ledger"]["trinkets"] == scarce_owned + [scarce_offers[buy_row]["id"]],
				"controller settles the scarce purchase once at the authored price")
		_check(visit.is_consumed()
					and not Controller.settle(visit, intent, before, quote).get("ok"),
				"scarce purchase is one-use; replay refused")
		await _act_disabled_replay()
		if stale.is_valid():
			stale.call()
		_check(intents.size() == 1 and visit.is_consumed(),
				"stale and replayed scarce presses cannot emit or settle twice")
	_check(rng.state == route_rng_before,
			"scarce rejections and purchases never touch the route RNG")


func _ambient_controls() -> Array:
	var result: Array = []
	for b in panel.wearer_buttons + panel.offer_buttons + [panel.leave_button]:
		result.append([b.get_global_rect(), b.text, b.tooltip_text, b.disabled,
			b.focus_mode, b.focus_next, b.focus_previous, b.has_focus(),
			b.get_meta("wearer_id", ""), b.get_meta("patch_id", "")])
	return result


func _ambient_retired(reason: String) -> void:
	var layer: Control = panel.ambient_layer
	_check(layer.profile.is_empty() and layer._time == 0.0 and not layer.visible
			and not layer.is_processing() and layer.motif_metadata().is_empty(),
			reason + " retires its animation and clock")
	layer._process(6.0)
	_check(layer._time == 0.0 and layer.motif_metadata().is_empty(),
			reason + " cannot drift when presentation delta advances")


func _atmosphere_cases(original: RunPatchStallVisit) -> void:
	var layer: Control = panel.ambient_layer
	var backing := panel.get_child(0) as Panel
	_check(layer != null and backing != null and layer.get_parent() == backing
			and backing.clip_contents and backing.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and layer.get_index() < backing.get_child(1).get_index()
			and backing.get_index() < panel.title_label.get_index(),
			"one clipped layer sits beneath sewn border and all original controls")
	_check(panel.find_children("LiveBattleAmbient", "Control", true, false).size() == 1
			and layer.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and layer.focus_mode == Control.FOCUS_NONE and layer.size == Vector2(900, 630)
			and panel.position == Vector2(190, 45),
			"one input-inert renderer fits fixed stitched panel")
	_check(layer.profile == "scraps" and layer.fast and layer._visit_dressing
			and layer.visible_budget() == 7 and layer.is_processing()
			and is_equal_approx(layer.self_modulate.a, 0.42),
			"authentic visit enables quiet seven-mote nonbattle scraps profile")
	var marks: Array = layer.motif_metadata()
	_check(marks.size() == 7 and layer._time < 1.0 and layer.felt_texture != null
			and layer.light_texture != null and layer.fluff_texture != null
			and layer.wisp_texture != null, "shipped imported VFX textures supply seven motifs")
	for mark in marks:
		_check(Rect2(Vector2.ZERO, layer.size).encloses(mark["rect"]),
			"quiet motif lies inside the clipped sewn panel")
	var before_state := original.read_state()
	var before_quote := original.quote()
	var before_controls := _ambient_controls()
	var before_focus := root.gui_get_focus_owner()
	var before_labels := [panel.title_label.text, panel.wallet_label.text,
		panel.wearer_label.text, panel.status_label.text, panel._wearer_index]
	var before_intents := intents.duplicate(true)
	var before_run_rng := rng.state
	seed(812732)
	var expected_global := randi()
	seed(812732)
	var before_light: float = layer.light_alpha(layer._time, layer.fast)
	layer._process(3.25)
	_check(layer.motif_metadata() != marks and layer._time > 0.0
			and layer.light_alpha(layer._time, layer.fast) != before_light,
			"presentation-only delta visibly drifts motes and warm image")
	_check(_ambient_controls() == before_controls and root.gui_get_focus_owner() == before_focus
			and [panel.title_label.text, panel.wallet_label.text, panel.wearer_label.text,
				panel.status_label.text, panel._wearer_index] == before_labels,
			"all real button rects, captions, disabled flags and focus stay invariant")
	_check(original.read_state() == before_state and original.quote() == before_quote
			and intents == before_intents and rng.state == before_run_rng
			and randi() == expected_global, "presentation never mutates source, intents or RNG")
	seed(268)
	await _bind(original)
	_check(panel.ambient_layer == layer and layer._time < 1.0
			and panel.find_children("LiveBattleAmbient", "Control", true, false).size() == 1,
			"authentic rebind resets one reused renderer")
	panel.hide()
	_ambient_retired("hidden view")
	panel.show()
	await _frames()
	_check(layer.profile == "scraps" and layer._time < 1.0 and layer.is_processing(),
			"visible re-show of open quote starts fresh clock")
	layer._process(2.0)
	root.remove_child(panel)
	_ambient_retired("detached view")
	root.add_child(panel)
	await _frames()
	_check(layer.profile == "scraps" and layer._time < 1.0 and layer.is_processing(),
			"tree reattach restarts the same renderer")

	panel.reduced_motion_override = true
	_ambient_retired("local reduced-motion override")
	panel.reduced_motion_override = false
	_check(layer.profile == "scraps" and layer._time == 0.0,
			"disabling local override resumes true visit")
	var previous_setting: Variant = ProjectSettings.get_setting("accessibility/reduced_motion", false)
	ProjectSettings.set_setting("accessibility/reduced_motion", true)
	panel.reduced_motion_override = null
	_ambient_retired("ProjectSettings reduced motion")
	panel.reduced_motion_override = false
	_check(layer.profile == "scraps" and layer._time == 0.0,
			"false override permits animation while global setting is true")
	panel.reduced_motion_override = null
	_ambient_retired("null override follows global setting")
	ProjectSettings.set_setting("accessibility/reduced_motion", previous_setting)
	panel._process(0.016)
	_check(layer.profile == "scraps" and layer._time == 0.0,
			"restored project setting resumes authentic view")
	layer._process(1.0)
	original._snapshot.gold += 1
	panel._process(0.016)
	_ambient_retired("stale source at render frame")
	original._snapshot.gold -= 1
	await _bind(original)
	_check(layer.profile == "scraps" and layer._time < 1.0,
			"fresh bind after stale source starts at zero")
	var used := _visit("ambient_consumed")
	var used_state := used.read_state()
	await _bind(used)
	layer._process(2.0)
	_check(used.leave(used_state.visit_id, used_state.node_id,
			used_state.snapshot).get("ok"), "external consumption uses real one-use service")
	panel._process(0.016)
	_ambient_retired("externally consumed visit")
	var invalid := _visit("", 240)
	_check(not invalid.is_valid(), "unavailable fixture genuinely fails validation")
	await _bind(invalid)
	_ambient_retired("invalid mounted visit")
	var pre := LivePatchStallPanel.new()
	pre.bind(invalid)
	root.add_child(pre)
	await _frames()
	_check(pre.ambient_layer != null and pre.ambient_layer.profile.is_empty()
			and not pre.ambient_layer.is_processing(), "invalid pre-mount bind never animates")
	pre.queue_free()
	await process_frame
	await _ambient_fallback_case()
	await _bind(original)
	panel.close()
	_ambient_retired("explicit close")
	await _bind(original)
	_check(layer.profile == "scraps" and layer._time < 1.0
			and panel.find_children("LiveBattleAmbient", "Control", true, false).size() == 1,
			"fresh genuine show/bind after close has one zero-clock renderer")


## VIS V5/V3-3: the authored backdrop's gentle 18-second idle loop, advanced
## only by accumulated presentation delta. The moving oversized backing always
## covers the fixed 900x630 window and never touches an offer, price, wearer
## choice, caption, focus or authority; every stop path restores the exact
## static baseline and restarts a genuinely open visit from zero phase.
func _backdrop_motion_cases(visit: RunPatchStallVisit) -> void:
	var baseline := {"scale": 1.0, "offset": Vector2.ZERO}
	var base := Vector2.ONE * -LivePatchStallPanel.BACKDROP_OVERSCAN
	var art: Texture2D = panel.panel_art_texture
	_check(art != null and str(art.resource_path) == LivePatchStallPanel.PANEL_ART,
			"mounted Patch Stall loads the already-present authored sewn panel art")
	# Freeze automatic processing: only deterministic hand-fed deltas advance.
	panel.set_process(false)
	var backing := panel.get_child(0) as Panel
	panel.bind(visit)
	_check(panel.clip_contents and backing.get_index() == 0 and backing.clip_contents
			and backing.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and backing.size == LivePatchStallPanel.PANEL_SIZE
					+ Vector2.ONE * (LivePatchStallPanel.BACKDROP_OVERSCAN * 2.0)
			and backing.position == base and backing.scale == Vector2.ONE,
			"one oversized clipped input-inert backing stays the panel's first child")
	_check(panel.ambient_layer.get_parent() == backing
			and backing.get_child(0) == panel.ambient_layer
			and panel.ambient_layer.size == LivePatchStallPanel.PANEL_SIZE
			and panel.ambient_layer.position == Vector2.ONE * LivePatchStallPanel.BACKDROP_OVERSCAN
			and backing.get_child(1).size == LivePatchStallPanel.PANEL_SIZE
			and backing.get_child(1).position == Vector2.ONE * LivePatchStallPanel.BACKDROP_OVERSCAN
			and panel.find_children("*", "Button", true, false).size() == 7,
			"retained ambient and border children stay framed at the fixed window")
	_check(LivePatchStallPanel.backdrop_motion_at(0.0) == baseline
			and LivePatchStallPanel.backdrop_motion_at(LivePatchStallPanel.BACKDROP_LOOP) == baseline,
			"backdrop motion rests exactly at phase zero and the completed 18 s loop")
	var breath_peak: Dictionary = LivePatchStallPanel.backdrop_motion_at(9.0)
	var drift_peak: Dictionary = LivePatchStallPanel.backdrop_motion_at(4.5)
	var drift_lift: Dictionary = LivePatchStallPanel.backdrop_motion_at(2.25)
	var peak_offset: Vector2 = drift_peak["offset"]
	var lift_offset: Vector2 = drift_lift["offset"]
	_check(absf(float(breath_peak["scale"]) - 1.01) < 0.0005
			and absf(peak_offset.x - 3.0) < 0.001 and absf(peak_offset.y) < 0.001
			and absf(lift_offset.y - 3.0) < 0.001,
			"an eased 18 s breath to 1% plus at most 3 px of horizontal and vertical drift")
	_check(LivePatchStallPanel.backdrop_motion_at(4.0) == LivePatchStallPanel.backdrop_motion_at(4.0)
			and LivePatchStallPanel.backdrop_motion_at(4.0) != LivePatchStallPanel.backdrop_motion_at(5.0)
			and LivePatchStallPanel.backdrop_motion_at(3.0)
					== LivePatchStallPanel.backdrop_motion_at(3.0 + LivePatchStallPanel.BACKDROP_LOOP),
			"the backdrop transform is deterministic and periodic on the 18 s loop")
	var in_bounds := true
	var no_edge := true
	for step in range(73):
		var motion := LivePatchStallPanel.backdrop_motion_at(float(step) * 0.25)
		var breath: float = motion["scale"]
		var offset: Vector2 = motion["offset"]
		if breath < 1.0 or breath > 1.01 or absf(offset.x) > 3.0 or absf(offset.y) > 3.0:
			in_bounds = false
		var grown := backing.size * breath
		var drawn := Rect2(base + offset - (grown - backing.size) * 0.5, grown)
		if not drawn.encloses(Rect2(Vector2.ZERO, LivePatchStallPanel.PANEL_SIZE)):
			no_edge = false
	_check(in_bounds, "every sampled loop phase keeps the 0%-1% breath and 3 px drift bounds")
	_check(no_edge,
			"the breathing backing stays oversized for the whole cycle, exposing no image edge")
	_check(panel.backdrop_motion_active() and panel.backdrop_motion_elapsed() == 0.0
			and panel.backdrop_motion_transform() == baseline,
			"a freshly bound authentic visit starts at the exact static baseline")
	var focused: Control = root.gui_get_focus_owner()
	var panel_rect := panel.get_global_rect()
	var title_rect := panel.title_label.get_global_rect()
	var wallet_rect := panel.wallet_label.get_global_rect()
	var wearer_rect := panel.wearer_label.get_global_rect()
	var status_rect := panel.status_label.get_global_rect()
	var before_controls := _ambient_controls()
	var before_state := visit.read_state()
	var before_quote := visit.quote()
	var before_run_rng := rng.state
	seed(812733)
	var expected_global := randi()
	seed(812733)
	panel._process(0.25)
	_check(panel.backdrop_motion_elapsed() == 0.25
			and panel.backdrop_motion_transform() == LivePatchStallPanel.backdrop_motion_at(0.25),
			"the real _process presentation delta advances the same deterministic clock")
	panel.advance_backdrop_motion(4.25)
	var moved: Dictionary = panel.backdrop_motion_transform()
	var moved_offset: Vector2 = moved["offset"]
	_check(panel.backdrop_motion_elapsed() == 4.5
			and moved == LivePatchStallPanel.backdrop_motion_at(4.5) and moved != baseline
			and absf(float(moved["scale"]) - 1.005) < 0.001
			and absf(moved_offset.x - 3.0) < 0.01,
			"accumulated presentation delta alone drives the restrained backdrop transform")
	_check(backing.scale == Vector2.ONE * float(moved["scale"])
			and backing.position == base + moved_offset,
			"only the decorative backing's own position and scale follow the transform")
	_check(panel.get_global_rect() == panel_rect
			and panel.title_label.get_global_rect() == title_rect
			and panel.wallet_label.get_global_rect() == wallet_rect
			and panel.wearer_label.get_global_rect() == wearer_rect
			and panel.status_label.get_global_rect() == status_rect
			and _ambient_controls() == before_controls
			and root.gui_get_focus_owner() == focused,
			"the fixed panel, captions, all seven hit rectangles and focus never move")
	_check(visit.read_state() == before_state and visit.quote() == before_quote
			and intents.is_empty() and rng.state == before_run_rng
			and randi() == expected_global,
			"backdrop motion never reads, quotes, spends or consumes the visit or any RNG")
	panel.advance_backdrop_motion(13.5)
	_check(panel.backdrop_motion_elapsed() == 18.0
			and panel.backdrop_motion_transform() == baseline
			and backing.scale == Vector2.ONE and backing.position == base,
			"one exactly complete 18 s cycle restores the exact static baseline")
	var prior_setting: Variant = ProjectSettings.get_setting("accessibility/reduced_motion", false)
	ProjectSettings.set_setting("accessibility/reduced_motion", true)
	panel.advance_backdrop_motion(5.0)
	_check(not panel.backdrop_motion_active() and panel.backdrop_motion_transform() == baseline
			and backing.scale == Vector2.ONE and backing.position == base,
			"ProjectSettings accessibility/reduced_motion keeps the backdrop exactly static")
	ProjectSettings.set_setting("accessibility/reduced_motion", prior_setting)
	panel.advance_backdrop_motion(4.5)
	var inflight: Dictionary = panel.backdrop_motion_transform()
	var inflight_offset: Vector2 = inflight["offset"]
	_check(panel.backdrop_motion_elapsed() == 4.5 and inflight != baseline
			and absf(float(inflight["scale"]) - 1.005) < 0.001
			and absf(inflight_offset.x - 3.0) < 0.01
			and backing.scale != Vector2.ONE and backing.position != base,
			"the backdrop is genuinely translated and scaled before the override")
	panel.reduced_motion_override = true
	_check(not panel.backdrop_motion_active() and panel.backdrop_motion_transform() == baseline
			and backing.scale == Vector2.ONE and backing.position == base
			and panel.backdrop_motion_elapsed() == 0.0,
			"an explicit reduced-motion override retires an in-flight transform immediately")
	panel.advance_backdrop_motion(4.0)
	_check(panel.backdrop_motion_transform() == baseline
			and backing.scale == Vector2.ONE and backing.position == base,
			"no presentation time accumulates while the explicit override is true")
	panel.reduced_motion_override = false
	_check(panel.backdrop_motion_active() and panel.backdrop_motion_transform() == baseline
			and panel.backdrop_motion_elapsed() == 0.0,
			"lifting the override restarts only from zero phase at the static baseline")
	panel.advance_backdrop_motion(2.0)
	_check(panel.backdrop_motion_transform() == LivePatchStallPanel.backdrop_motion_at(2.0),
			"motion resumes only through fresh presentation time after the override lifts")
	ProjectSettings.set_setting("accessibility/reduced_motion", true)
	panel.reduced_motion_override = null
	_check(not panel.backdrop_motion_active() and panel.backdrop_motion_transform() == baseline
			and backing.scale == Vector2.ONE and backing.position == base
			and panel.backdrop_motion_elapsed() == 0.0,
			"a null override follows the ProjectSettings reduced-motion request again")
	ProjectSettings.set_setting("accessibility/reduced_motion", prior_setting)
	panel.reduced_motion_override = null
	panel.advance_backdrop_motion(2.0)
	_check(panel.backdrop_motion_transform() != baseline,
			"the backdrop is genuinely moving before hiding")
	panel.hide()
	_check(not panel.backdrop_motion_active() and panel.backdrop_motion_transform() == baseline
			and backing.position == base,
			"a hidden view restores the exact static baseline")
	panel.advance_backdrop_motion(3.0)
	_check(panel.backdrop_motion_transform() == baseline,
			"a hidden view accumulates no motion")
	panel.show()
	_check(panel.backdrop_motion_active() and panel.backdrop_motion_transform() == baseline
			and backing.scale == Vector2.ONE,
			"the shown view resumes only from the static baseline")
	panel.advance_backdrop_motion(2.0)
	_check(panel.backdrop_motion_transform() != baseline,
			"the backdrop is genuinely moving before bind(null)")
	panel.bind(null)
	_check(not panel.backdrop_motion_active() and panel.backdrop_motion_transform() == baseline
			and backing.position == base,
			"bind(null) stops and restores the exact static baseline")
	panel.advance_backdrop_motion(7.0)
	_check(panel.backdrop_motion_transform() == baseline,
			"a panel without a source accumulates no motion")
	panel.bind(visit)
	panel.advance_backdrop_motion(3.0)
	_check(panel.backdrop_motion_transform() != baseline,
			"the backdrop is genuinely moving before close()")
	panel.close()
	_check(not panel.is_visible_in_tree() and not panel.backdrop_motion_active()
			and panel.backdrop_motion_transform() == baseline
			and backing.position == base and backing.scale == Vector2.ONE,
			"close() stops and restores the exact static baseline on the closed panel")
	panel.advance_backdrop_motion(7.0)
	_check(panel.backdrop_motion_transform() == baseline,
			"no old motion resumes on the closed panel")
	panel.bind(visit)
	_check(panel.backdrop_motion_active() and panel.backdrop_motion_transform() == baseline
			and backing.scale == Vector2.ONE,
			"a new authentic bind restarts the backdrop from the exact static baseline")
	panel.advance_backdrop_motion(3.0)
	_check(panel.backdrop_motion_transform() != baseline,
			"the backdrop moves on the rebound authentic visit")
	panel.bind(visit)
	_check(panel.backdrop_motion_transform() == baseline,
			"rebinding an open visit restarts at the static baseline, never resuming stale state")
	var invalid := _visit("", 240)
	_check(not invalid.is_valid(), "backdrop fixture is a real invalid service")
	panel.bind(invalid)
	panel.advance_backdrop_motion(4.0)
	_check(not panel.backdrop_motion_active() and panel.backdrop_motion_transform() == baseline,
			"an invalid visit never animates the backdrop")
	var already := _visit("backdrop_already_used")
	var already_state := already.read_state()
	_check(already.leave(already_state.visit_id, already_state.node_id,
				already_state.snapshot).get("ok"), "already-used real visit prerequisite")
	panel.bind(already)
	panel.advance_backdrop_motion(4.0)
	_check(not panel.backdrop_motion_active() and panel.backdrop_motion_transform() == baseline,
			"a consumed visit never animates the backdrop")
	panel.bind(visit)
	panel.advance_backdrop_motion(1.0)
	_check(panel.backdrop_motion_transform() != baseline,
			"the backdrop moves while the bound visit is genuinely open")
	visit._snapshot.gold += 1
	panel.advance_backdrop_motion(1.0)
	_check(not panel.backdrop_motion_active() and panel.backdrop_motion_transform() == baseline
			and backing.position == base,
			"a stale source stops the backdrop at the static baseline")
	visit._snapshot.gold -= 1
	panel.advance_backdrop_motion(1.0)
	_check(panel.backdrop_motion_active()
			and panel.backdrop_motion_transform() == LivePatchStallPanel.backdrop_motion_at(1.0),
			"a restored current source resumes only from the static baseline")
	var external := _visit("backdrop_external")
	var external_state := external.read_state()
	panel.bind(external)
	panel.advance_backdrop_motion(1.0)
	_check(panel.backdrop_motion_transform() != baseline,
			"the backdrop moves before the external consumption")
	_check(external.leave(external_state.visit_id, external_state.node_id,
				external_state.snapshot).get("ok"), "external owner really consumed the animated visit")
	panel.advance_backdrop_motion(1.0)
	_check(not panel.backdrop_motion_active() and panel.backdrop_motion_transform() == baseline
			and backing.position == base,
			"an externally consumed source stops the backdrop at the static baseline")
	panel.bind(visit)
	panel.advance_backdrop_motion(2.0)
	_check(panel.backdrop_motion_transform() != baseline,
			"the backdrop is genuinely moving before detach")
	root.remove_child(panel)
	_check(panel.backdrop_motion_elapsed() == 0.0 and backing.scale == Vector2.ONE
			and backing.position == base,
			"an exit-tree view resets the exact static baseline")
	root.add_child(panel)
	_check(panel.backdrop_motion_active() and panel.backdrop_motion_transform() == baseline,
			"a reattached open visit restarts only from the static baseline")
	var moving := _visit("backdrop_buy")
	var moving_before := moving.read_state()
	var moving_quote := moving.quote()
	await _bind(moving)
	panel.advance_backdrop_motion(2.5)
	await _act(panel.wearer_buttons[1], true, KEY_SPACE)
	await _act(panel.offer_buttons[0], false)
	_check(intents.size() == 1 and intents[0].get("action") == "buy_patch"
			and intents[0].get("patch_id") == moving_quote["offers"][0]["id"]
			and intents[0].get("wearer_id") == PARTY[1]
			and intents[0].get("node_id") == moving_before["node_id"]
			and intents[0].get("visit_id") == moving_before["visit_id"]
			and intents[0].get("expected_snapshot") == moving_before["snapshot"],
			"a real keyboard-wearer mouse purchase submits one source-bound intent while the backdrop animates")
	if intents.size() == 1:
		var receipt := Controller.settle(moving, intents[0], moving_before, moving_quote)
		_check(receipt.get("ok") == true and receipt["ledger"]["gold"]
					== 240 - int(moving_quote["offers"][0]["price"]),
				"the independent controller settles the animated purchase exactly once")
		_check(moving.is_consumed() and not Controller.settle(moving, intents[0],
					moving_before, moving_quote).get("ok"),
				"the animated visit is consumed exactly once and replay is refused")
	panel.bind(visit)
	panel.set_process(true)
	seed(268)


func _ambient_fallback_case() -> void:
	var fallback := LivePatchStallPanel.new()
	fallback.position = Vector2(190, 45)
	fallback.panel_art_path = "res://assets/paper/ui/missing_test_stall.png"
	var visit := _visit("ambient_no_art")
	var state := visit.read_state()
	var quote := visit.quote()
	var received: Array[Dictionary] = []
	fallback.intent_requested.connect(func(intent: Dictionary): received.append(intent))
	fallback.bind(visit)
	root.add_child(fallback)
	await _frames()
	var backing := fallback.get_child(0) as Panel
	_check(backing.get_theme_stylebox("panel") is StyleBoxFlat
			and fallback.wearer_buttons.all(func(b: Button): return not b.disabled)
			and fallback.offer_buttons.all(func(b: Button): return not b.disabled)
			and not fallback.leave_button.disabled,
			"missing panel image retains solid sewn border and genuine buttons")
	_check(fallback.panel_art_texture == null and not fallback.backdrop_motion_active()
			and fallback.backdrop_motion_transform()["scale"] == 1.0
			and fallback.backdrop_motion_elapsed() == 0.0
			and backing.scale == Vector2.ONE
			and backing.position == Vector2.ONE * -LivePatchStallPanel.BACKDROP_OVERSCAN,
			"missing authored art installs no backdrop motion at all")
	fallback.advance_backdrop_motion(6.0)
	_check(not fallback.backdrop_motion_active()
			and fallback.backdrop_motion_elapsed() == 0.0
			and backing.scale == Vector2.ONE
			and backing.position == Vector2.ONE * -LivePatchStallPanel.BACKDROP_OVERSCAN,
			"absent texture ignores presentation advances without drifting")
	fallback.ambient_layer.felt_texture = null
	fallback.ambient_layer.light_texture = null
	fallback.ambient_layer.fluff_texture = null
	fallback.ambient_layer.wisp_texture = null
	fallback.ambient_layer.vignette_texture = null
	fallback.ambient_layer.queue_redraw()
	fallback.ambient_layer._process(3.0)
	_check(fallback.ambient_layer.profile == "scraps" and received.is_empty()
			and visit.read_state() == state and visit.quote() == quote,
			"missing optional VFX changes no purchase quote or action")
	fallback.leave_button.pressed.emit()
	var settled := false
	if received.size() == 1:
		settled = Controller.settle(visit, received[0], state, quote).get("ok")
	_check(settled and received.size() == 1 and received[0].get("action") == "leave",
			"missing art still forwards authentic free Leave to independent controller")
	fallback.queue_free()
	await process_frame

func _unlocked_heirloom_cases(power_slots: Dictionary) -> void:
	var authored: Variant = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/shop/initial_offers.json"))
	if typeof(authored) != TYPE_DICTIONARY or not authored.has("trinkets"):
		_check(false, "heirloom fixture needs the shipped priced catalog")
		return

	var late_owned: Array = []
	for listing in authored["trinkets"]:
		if typeof(listing) != TYPE_DICTIONARY:
			continue
		var id: Variant = listing.get("id")
		if typeof(id) != TYPE_STRING:
			continue
		if id != "button_eye":
			late_owned.append(id)
	_check(not late_owned.has("needle_echo") and not late_owned.has("shared_hem"),
			"Heirlooms are unowned in late-run fixture")

	# Locked/default sampler excludes the two P12 IDs:
	var locked_rng := RandomNumberGenerator.new()
	locked_rng.seed = 424242
	var locked_sample := RunShopPurchases.sample_patch_stall_offers(
			locked_rng, authored["trinkets"], late_owned, null, false)
	_check(locked_sample.get("ok") == true, "locked sampler succeeds")
	for offer in locked_sample.get("offers", []):
		_check(offer.get("id") != "needle_echo" and offer.get("id") != "shared_hem",
				"locked sampler excludes Heirloom ID: " + str(offer.get("id")))

	var default_rng := RandomNumberGenerator.new()
	default_rng.seed = 424242
	var default_sample := RunShopPurchases.sample_patch_stall_offers(
			default_rng, authored["trinkets"], late_owned)
	_check(default_sample.get("ok") == true, "default sampler succeeds")
	for offer in default_sample.get("offers", []):
		_check(offer.get("id") != "needle_echo" and offer.get("id") != "shared_hem",
				"default sampler excludes Heirloom ID: " + str(offer.get("id")))

	# Genuine unlocked deterministic quote containing both authored Heirlooms:
	var unlocked_rng := RandomNumberGenerator.new()
	unlocked_rng.seed = 424242
	var unlocked_sample := RunShopPurchases.sample_patch_stall_offers(
			unlocked_rng, authored["trinkets"], late_owned, null, true)
	_check(unlocked_sample.get("ok") == true and unlocked_sample.get("offers") is Array
			and unlocked_sample["offers"].size() == 3,
			"unlocked sampler returns exactly three offers")
	if unlocked_sample.get("ok") != true or unlocked_sample.get("offers", []).size() != 3:
		return

	var sample_offers: Array = unlocked_sample["offers"]
	var sampled_ids := {}
	for offer in sample_offers:
		sampled_ids[offer.get("id")] = offer
	_check(sampled_ids.has("needle_echo") and sampled_ids.has("shared_hem"),
			"unlocked late-run sampler drew both authored Heirlooms")
	_check(sampled_ids.get("needle_echo", {}).get("price") == 100,
			"Needle Echo quoted at canonical 100 gold")
	_check(sampled_ids.get("shared_hem", {}).get("price") == 100,
			"Shared Hem quoted at canonical 100 gold")

	# Pass through a genuine RunPatchStallVisit:
	var gold := 250
	var visit := RunPatchStallVisit.new("heirloom_stall_visit", PARTY, DECK, late_owned, gold, sample_offers)
	_check(visit.is_valid() and visit.read_state().get("status") == "available",
			"unlocked heirloom visit is valid and available")
	var before_state: Dictionary = visit.read_state()
	var before_quote: Dictionary = visit.quote()
	var before_run_rng := rng.state

	for offer in before_quote.get("offers", []):
		if offer.get("id") == "needle_echo" or offer.get("id") == "shared_hem":
			_check(offer.get("sold") == false, "authored heirloom in unowned visit is unsold: " + str(offer.get("id")))

	await _bind(visit)

	# Assert visit, wallet, RNG, and purchase ledger unchanged
	_check(visit.read_state() == before_state, "bind leaves authentic visit state unchanged")
	_check(visit.quote() == before_quote, "bind leaves authentic quote unchanged")
	_check(visit.read_state()["snapshot"]["gold"] == gold, "bind leaves wallet unchanged")
	_check(rng.state == before_run_rng, "bind leaves seeded run RNG unchanged")
	_check(intents.is_empty(), "bind emits no purchase intent")

	# Controls and admission:
	_check(panel._active(), "panel is active for genuine unlocked heirloom visit")
	_check(panel.offer_buttons.size() == 3, "panel has three offer buttons")
	for i in range(3):
		var button := panel.offer_buttons[i]
		var quoted: Dictionary = before_quote["offers"][i]
		var offer_id: String = quoted["id"]
		_check(not button.disabled, "affordable unsold offer button is enabled: " + offer_id)
		_check(button.get_meta("patch_id") == offer_id, "offer button meta matches quoted ID: " + offer_id)
		var lines := button.text.split("\n")
		_check(lines.size() == 2, "offer button has two lines: " + offer_id)
		_check(lines[0].contains(str(quoted["price"]) + " gold"), "offer caption shows quoted price: " + offer_id)

		if offer_id == "needle_echo":
			_check(lines[0].contains("Needle Echo") and lines[0].contains("HEAD"),
					"Needle Echo caption shows name and HEAD slot")
			_check(lines[1] == LivePatchStallPanel.NEEDLE_ECHO_SHORT,
					"Needle Echo caption shows exact short rule")
			var tooltip := button.tooltip_text
			_check(tooltip.contains("Needle Echo [needle_echo]"), "Needle Echo tooltip has title and ID")
			_check(tooltip.contains(LivePatchStallPanel.NEEDLE_ECHO_FULL),
					"Needle Echo tooltip contains exact full rule")
			_check(tooltip.contains("Once per turn") and tooltip.contains("+1 damage")
					and tooltip.contains("first confirmed hit") and tooltip.contains("Pinned enemy")
					and tooltip.contains("living, untorn wearer"),
					"Needle Echo tooltip retains all trigger/eligibility limits")
			_check(tooltip.contains("HEAD slot") and tooltip.contains("+1 scrap"),
					"Needle Echo tooltip contains HEAD slot scrap warning")
			_check(not tooltip.contains(panel.DETAILS_UNAVAILABLE),
					"Needle Echo tooltip does not show details unavailable")
		elif offer_id == "shared_hem":
			_check(lines[0].contains("Shared Hem") and lines[0].contains("ARM"),
					"Shared Hem caption shows name and ARM slot")
			_check(lines[1] == LivePatchStallPanel.SHARED_HEM_SHORT,
					"Shared Hem caption shows exact short rule")
			var tooltip := button.tooltip_text
			_check(tooltip.contains("Shared Hem [shared_hem]"), "Shared Hem tooltip has title and ID")
			_check(tooltip.contains(LivePatchStallPanel.SHARED_HEM_FULL),
					"Shared Hem tooltip contains exact full rule")
			_check(tooltip.contains("Once per turn") and tooltip.contains("+1 Block")
					and tooltip.contains("different living hero") and tooltip.contains("actually gains Block")
					and tooltip.contains("living, untorn wearer"),
					"Shared Hem tooltip retains all trigger/eligibility limits")
			_check(tooltip.contains("ARM slot") and tooltip.contains("+1 scrap"),
					"Shared Hem tooltip contains ARM slot scrap warning")
			_check(not tooltip.contains(panel.DETAILS_UNAVAILABLE),
					"Shared Hem tooltip does not show details unavailable")

	# Negative source checks:
	var bad_slot_visit := RunPatchStallVisit.new("bad_slot_visit", PARTY, DECK, [], 200,
			[{"id": "needle_echo", "price": 100}, {"id": "button_eye", "price": 100}, {"id": "pincushion_arm", "price": 100}])
	var invalid_slots := {"needle_echo": "INVALID_SLOT", "button_eye": "HEAD", "pincushion_arm": "ARM"}
	_check(not panel._valid_receipts(bad_slot_visit.read_state(), bad_slot_visit.quote(), invalid_slots),
			"slot map with invalid slot name is rejected by receipt validation")

	var unknown_visit := RunPatchStallVisit.new("unknown_visit", PARTY, DECK, [], 200,
			[{"id": "unknown_heirloom", "price": 100}, {"id": "button_eye", "price": 100}, {"id": "pincushion_arm", "price": 100}])
	await _bind(unknown_visit)
	_check(not panel._active(), "unknown patch offer fails bind closed")
	_check(panel.offer_buttons.all(func(b: Button): return b.disabled),
			"offer buttons disabled on rejected unknown visit")

	var consumed_visit := RunPatchStallVisit.new("consumed_visit", PARTY, DECK, [], 200, sample_offers)
	consumed_visit.leave(consumed_visit.read_state()["visit_id"], "consumed_visit", consumed_visit.read_state()["snapshot"])
	_check(consumed_visit.is_consumed(), "visit is consumed after leave")
	await _bind(consumed_visit)
	_check(not panel._active(), "consumed visit fails bind closed")

	var dup_offers := [{"id": "needle_echo", "price": 100}, {"id": "needle_echo", "price": 100}, {"id": "shared_hem", "price": 100}]
	var dup_visit := RunPatchStallVisit.new("dup_visit", PARTY, DECK, [], 200, dup_offers)
	await _bind(dup_visit)
	_check(not panel._active(), "duplicate offer ID in quote fails bind closed")

	# Affordability: insufficient gold disables buttons and shows shortfall
	var broke_visit := RunPatchStallVisit.new("broke_heirloom_visit", PARTY, DECK, late_owned, 50, sample_offers)
	await _bind(broke_visit)
	_check(panel._active(), "panel active for broke visit")
	for i in range(3):
		if sample_offers[i]["id"] == "needle_echo" or sample_offers[i]["id"] == "shared_hem":
			_check(panel.offer_buttons[i].disabled, "unaffordable heirloom button is disabled")
			_check(panel.offer_buttons[i].text.contains("short 50"), "caption displays shortfall")

	# Pre-owned heirloom shows as SOLD and is disabled
	var preowned: Array = late_owned.duplicate()
	preowned.append("needle_echo")
	var preowned_offers := [
		{"id": "needle_echo", "price": 100},
		{"id": "shared_hem", "price": 100},
		{"id": "button_eye", "price": 100}
	]
	var sold_visit := RunPatchStallVisit.new("sold_heirloom_visit", PARTY, DECK, preowned, 200, preowned_offers)
	await _bind(sold_visit)
	_check(panel._active(), "panel active for sold heirloom visit")
	for i in range(3):
		if preowned_offers[i]["id"] == "needle_echo":
			_check(panel.offer_buttons[i].disabled, "sold heirloom button is disabled")
			_check(panel.offer_buttons[i].text.contains("SOLD"), "caption displays SOLD")
			_check(not panel.offer_buttons[i].text.contains("gold"), "sold caption displays no price")
