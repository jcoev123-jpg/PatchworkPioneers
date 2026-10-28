extends SceneTree
## V3-3 Peddler choice panel: five mounted priced actions (three owner-labelled
## hero cards, one patch, Leave) from one genuine OPEN RunPeddlerVisit, detached
## source-bound intents, and the authentic once-only card/patch/Leave receipts
## around the existing seeded stock sampler and purchase ledger.
##
## It also proves the read-only ability preview: each offered card's exact ID,
## authored owner, authored energy cost and CardShortRules sentences appear in
## the existing status band (and stay complete in that card's tooltip) on hover
## or keyboard focus, without changing a quote, minting an intent, spending gold
## or consuming RNG. The panel mounts under a 1280x720 Control; every settlement
## still goes through RunPeddlerVisit itself.

const NODE := "v3_peddler_stop"
const PARTY := ["warden", "seamstress", "tinker"]
const DECK := ["warden_strike", "seamstress_prick", "tinker_pop_shot"]
const PARTY_V3 := ["warden", "lantern_monk", "rag_duelist"]
const DECK_V3 := ["warden_strike", "lantern_monk_moth_lure", "rag_duelist_velvet_feint"]
const PARTY_V3_UNKNOWN := ["lantern_monk", "rag_duelist", "scarecrow"]
const DECK_V3_UNKNOWN := ["lantern_monk_moth_lure", "rag_duelist_velvet_feint", "scarecrow_re_stuff"]
const PARTY_MORE := ["scarecrow", "yarn_ranger", "button_golem"]
const DECK_MORE := ["scarecrow_fork_jab", "yarn_ranger_wool_bolas", "button_golem_starter_button_fist"]
const SEED := 2611790
const V3_SEED := 90210
const V3_UNKNOWN_SEED := 424242
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
var preview_catalogs: Array = []
var observer: KeyObserver
var presses: Dictionary = {}


## Event-observation hook: a key that reaches the unhandled stage was NOT
## consumed by the Peddler's shortcut handler, so the rest of the game could
## still act on it. A handled shortcut never appears here.
class KeyObserver:
	extends Node

	var seen: Array = []

	func _unhandled_key_input(event: InputEvent) -> void:
		var key := event as InputEventKey
		if key != null and key.pressed:
			seen.append(key.keycode)


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
	observer = KeyObserver.new()
	root.add_child(observer)
	# Independent Button.pressed spies: they count real signal emissions on the
	# mounted controls, separate from the panel's own view-owned callbacks.
	_spy("card0", panel.card_buttons[0])
	_spy("card1", panel.card_buttons[1])
	_spy("card2", panel.card_buttons[2])
	_spy("patch", panel.patch_button)
	_spy("leave", panel.leave_button)
	await _frames()
	_check(host.size == Vector2(1280, 720) and panel.get_parent() == host,
			"panel is mounted under a 1280x720 Control")
	# Seed the global RNG only after Godot has mounted cosmetic UI nodes.
	seed(268)
	var expected_global := randi()
	seed(268)
	var expected_run := rng.state

	await _layout(visit)
	_long_rule_case()
	_sold_card_projection_case(visit)
	await _preview_cases()
	for index in range(3):
		await _buy_case(index, "card", index % 2 == 0)
	await _buy_case(0, "trinket", true)
	await _leave_case(false)
	await _leave_case(true)
	await _shortcut_cases()
	await _affordability_cases()
	await _sold_case()
	await _fail_closed()
	await _rare_patch_panels()
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


## Measure each actual rendered line, not the combined multi-line string:
## Button autowrap must never be relied on to hide a long effect or price.
func _fits(button: Button) -> bool:
	var font := button.get_theme_font("font")
	if font == null or button.text.is_empty():
		return false
	var size_px := button.get_theme_font_size("font_size")
	if size_px < 18:
		return false
	var lines := button.text.split("\n")
	var allowance := button.size.x - (32.0 if panel.card_buttons.has(button) else 16.0)
	for line in lines:
		if line.is_empty() or font.get_string_size(line,
				HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x > allowance:
			return false
	return button.size.y >= font.get_height(size_px) * lines.size() + 16.0


## The legacy one-line caption falls back to the shipped ID-to-name renderer
## (readable_id) when a row has no catalog display name. Mirroring that same
## documented projection keeps the oracle honest for IDs that carry digits
## (for example a v3 printing) without weakening the quote/sale assertions.
func _expected_name(item_id: String) -> String:
	return item_id.replace("_", " ").capitalize()


## A separate catalog oracle checks the *mounted* two-line caption. Prices
## come from the quoted visit, not the authored card's cost or the row builder.
func _check_card_row(index: int, offer: Dictionary, context: String) -> void:
	var definition := _authored_definition(offer)
	var described := CardShortRules.describe(definition)
	var button := panel.card_buttons[index]
	var lines := button.text.split("\n")
	var label := context + " card " + str(index)
	_check(not definition.is_empty() and definition.get("id") == offer["id"]
			and definition.get("owner") == offer["owner"]
			and typeof(definition.get("cost")) == TYPE_INT
			and described.get("known") == true and not str(described.get("line", "")).is_empty(),
			label + ": oracle resolves genuine owner, cost and authored effect")
	if lines.size() != 2 or definition.is_empty():
		_check(false, label + ": exactly two informative lines")
		return
	var name := str(definition.get("display_name", "")).strip_edges()
	if name.is_empty():
		name = _expected_name(str(offer["id"]))
	var prefix := str(offer["owner"]).capitalize() + "  ·  "
	var suffix := "  ·  %d gold" % int(offer["price"])
	var money := int(panel._source["state"]["gold"])
	if bool(offer["sold"]):
		suffix += "  ·  SOLD"
	elif money < int(offer["price"]):
		suffix += "  ·  short %d" % (int(offer["price"]) - money)
	var actual_name := lines[0].substr(prefix.length(),
			lines[0].length() - prefix.length() - suffix.length())
	_check(lines[0].begins_with(prefix) and lines[0].ends_with(suffix)
			and (actual_name == name or (actual_name.ends_with(LivePeddlerPanel.ELLIPSIS)
			and name.begins_with(actual_name.trim_suffix(LivePeddlerPanel.ELLIPSIS).strip_edges())))
			and not lines[0].contains(str(offer["id"])),
			label + ": quote, sale/shortfall and catalog display name coexist")
	var energy := "%d energy  ·  " % int(definition["cost"])
	var effect := lines[1].substr(energy.length()) if lines[1].begins_with(energy) else ""
	var full := str(described["line"])
	var first_word := full.get_slice(" ", 0)
	_check(lines[1].begins_with(energy) and not effect.is_empty()
			and (effect == full or (effect.ends_with(LivePeddlerPanel.ELLIPSIS)
			and effect.contains(first_word))) ,
			label + ": measured row exposes real energy and recognisable authored mechanic")
	_check(button.tooltip_text.contains(str(offer["id"]))
			and button.tooltip_text.contains("%d energy" % int(definition["cost"]))
			and button.tooltip_text.contains(full)
			and button.tooltip_text.contains("%d gold" % int(offer["price"])),
			label + ": full rule, ID and quote remain in tooltip")
	_check(_fits(button) and button.size == Vector2(822, 78)
			and button.get_theme_font_size("font_size") >= 18,
			label + ": both lines fit the actual 822x78 font geometry")


## Exercise the bounded rule formatter with the longest genuinely authored
## priced description, without manufacturing an effect or a source card.
func _long_rule_case() -> void:
	var font := panel.card_buttons[0].get_theme_font("font")
	var px := panel.card_buttons[0].get_theme_font_size("font_size")
	var longest := ""
	var longest_id := ""
	for candidate in authored_cards:
		var definition := _authored_definition(candidate)
		if definition.is_empty():
			continue
		var described := CardShortRules.describe(definition)
		var sentence := str(described.get("line", ""))
		if described.get("known") == true and sentence.length() > longest.length():
			longest = sentence
			longest_id = str(candidate["id"])
	_check(font != null and not longest_id.is_empty() and longest.length() > 30,
			"the stress-rule source is a real, substantive authored catalog sentence")
	if font == null or longest.is_empty():
		return
	var budget := 290.0
	var fitted := panel._fit_card_rule(longest, budget, font, px)
	_check(font.get_string_size(fitted, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x <= budget
			and fitted.ends_with(LivePeddlerPanel.ELLIPSIS)
			and fitted.contains(longest.get_slice(" ", 0)),
			"the longest priced authored rule is measurably abbreviated with a visible ellipsis")
	_check(intents.is_empty(), "measuring the real authored rule emits no buy intent")


## A purchased card closes its visit immediately: no real OPEN service can
## quote it as SOLD. Check the sale badge on a detached source projection only,
## and prove it does not enable a purchase against the unchanged service.
func _sold_card_projection_case(visit: RunPeddlerVisit) -> void:
	var original := panel._source.duplicate(true)
	var button := panel.card_buttons[0]
	var unchanged_caption := button.text
	panel._source["stock"]["cards"][0]["sold"] = true
	var sold_caption := panel._card_caption(0)
	_check(sold_caption.split("\n").size() == 2 and
			sold_caption.split("\n")[0].ends_with("  ·  SOLD") and
			sold_caption.contains(" energy"),
			"an explicitly sold card still presents its original priced energy/rule row")
	_check(not panel._source_current() and visit.read_state() == original,
			"a forged SOLD projection cannot become an authenticated live offer")
	panel._source = original
	_check(panel._card_caption(0) == unchanged_caption and intents.is_empty(),
			"restored authentic card caption cannot generate an intent during inspection")


func _layout(visit: RunPeddlerVisit) -> void:
	var screen := Rect2(host.get_global_rect().position, host.size)
	_check(screen.encloses(panel.get_global_rect()) and panel.size == LivePeddlerPanel.PANEL_SIZE,
			"compact sewn panel is wholly visible at 1280x720")
	var actual: Array = panel.find_children("*", "Button", true, false)
	_check(actual.size() == 5 and panel.card_buttons.size() == 3
			and actual.has(panel.patch_button) and actual.has(panel.leave_button),
			"exactly three card buys, one patch buy and Leave (five buttons)")
	_check(panel.title_label.text.contains("PEDDLER")
			and panel.wallet_label.text.contains("500 gold"), "title and wallet are readable")
	# The band opens on the neutral hint or on the genuine preview of the card
	# that already holds focus; any other opening text would not be this stock.
	var opening_status := panel.status_label.text
	var opening_authentic := opening_status == LivePeddlerPanel.STATUS_OPEN
	if panel._preview_index >= 0:
		opening_authentic = opening_authentic \
				or opening_status == panel._clamp_status(panel._card_preview(panel._preview_index))
	_check(opening_authentic and _status_fits(),
			"status band opens with the neutral hint or a fitted current-card preview")
	var open := visit.read_state()
	for index in range(3):
		var button := panel.card_buttons[index]
		var offer: Dictionary = open["stock"]["cards"][index]
		_check(screen.encloses(button.get_global_rect()) and button.size.y >= 70,
				"unclipped card action row " + str(index))
		_check_card_row(index, offer, "mounted main")
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
	_check(panel.status_label.size.x >= LivePeddlerPanel.STATUS_WIDTH
			and panel.status_label.size.y >= 24,
			"the status band really has its designed room at 1280x720")
	# _caption remains the exact one-line oracle for the unchanged patch and
	# any legacy callers. Card rows instead use measured two-line projections.
	var caption_font := panel.patch_button.get_theme_font("font")
	var caption_size := panel.patch_button.get_theme_font_size("font_size")
	var worst_patch := 0.0
	if caption_font != null:
		for entry in authored_cards + authored_patches:
			var prefix := str(entry["owner"]).capitalize() if entry.has("owner") else "PATCH"
			var line := "%s  ·  %s  ·  %d gold" % [
					prefix, _expected_name(str(entry["id"])), int(entry["price"])]
			_check(panel._caption(prefix, entry["id"], entry["price"], false) == line
					and panel._caption(prefix, entry["id"], entry["price"], true) == line + "  ·  SOLD",
					"legacy one-line caption keeps price and sold suffix: " + entry["id"])
			if prefix == "PATCH":
				for caption in [line, line + "  ·  SOLD", line + "  ·  short %d" % int(entry["price"])]:
					worst_patch = maxf(worst_patch, caption_font.get_string_size(caption,
							HORIZONTAL_ALIGNMENT_LEFT, -1, caption_size).x)
	_check(caption_font != null and not authored_patches.is_empty()
			and worst_patch <= panel.patch_button.size.x - 16.0,
			"every unchanged patch quote fits one measured line at its font size")
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


## Independently resolved authored definition for one genuine offer, through the
## same catalogs the seeded stock generator validates candidates against.
func _authored_definition(offer: Dictionary) -> Dictionary:
	if preview_catalogs.is_empty():
		preview_catalogs = RunShopStockOffers._peddler_catalogs()
	var found: Dictionary = RunShopStockOffers._find_card_definition(
			str(offer.get("id", "")), preview_catalogs)
	if found.is_empty():
		return {}
	var definition: Variant = found.get("def", {})
	return definition if definition is Dictionary else {}


## The status band's measured readability: its shipped 18px face must fit the
## width the band actually has at 1280x720.
func _status_fits() -> bool:
	var font := panel.status_label.get_theme_font("font")
	if font == null or panel.status_label.text.is_empty():
		return false
	var size_px := panel.status_label.get_theme_font_size("font_size")
	if size_px < 18:
		return false
	var width := font.get_string_size(panel.status_label.text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	var band: float = minf(LivePeddlerPanel.STATUS_WIDTH, panel.status_label.size.x)
	return band > 0.0 and width <= band


func _seeded_stock(party: Array, seed_value: int) -> Dictionary:
	var local := RandomNumberGenerator.new()
	local.seed = seed_value
	return RunShopStockOffers.generate_peddler_stock(local, party, authored_cards,
			authored_patches, [])


func _party_visit(node: String, party: Array, deck: Array, stock: Dictionary,
		gold: int = GOLD) -> RunPeddlerVisit:
	return RunPeddlerVisit.new(node, party, deck, [], gold, stock)


func _offer_owners(state: Dictionary) -> Array:
	var owners: Array = []
	for offer in state["stock"]["cards"]:
		owners.append(str(offer["owner"]))
	return owners


func _all_tooltips_empty() -> bool:
	for button in panel.card_buttons:
		if not button.tooltip_text.is_empty():
			return false
	return true


func _move_pointer(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	root.push_input(motion)
	await _frames()


func _hover_card(index: int) -> void:
	await _move_pointer(panel.card_buttons[index].get_global_rect().get_center())


func _hover_none() -> void:
	await _move_pointer(Vector2(2, 2))


## One highlighted card's preview must state exactly who and what it is, from
## that card's own authored record, and leave the priced caption untouched.
func _check_preview(index: int, offer: Dictionary, definition: Dictionary,
		label: String) -> void:
	var described := CardShortRules.describe(definition)
	var line := str(described.get("line", ""))
	var cost := "%d energy" % int(definition.get("cost", -1))
	var button := panel.card_buttons[index]
	var status := panel.status_label.text
	var tooltip := button.tooltip_text
	_check(not definition.is_empty() and definition.get("owner") == offer["owner"]
			and typeof(definition.get("cost")) == TYPE_INT
			and described.get("known") == true and not line.is_empty(),
			label + ": " + str(offer["id"]) + " resolves to a genuine authored definition and rule line")
	_check(panel._preview_index == index and _status_fits(),
			label + ": card row " + str(index) + " is previewed and the band fits its width")
	_check(status.contains(str(offer["id"]))
			and status.contains(str(offer["owner"]).capitalize()),
			label + ": the preview names the exact offered ID and its authored owner")
	_check(status.contains(cost), label + ": the preview shows the authored " + cost)
	_check(status.contains(line), label + ": the preview itself carries the authored effect line")
	_check(tooltip.contains(str(offer["id"])) and tooltip.contains(cost)
			and tooltip.contains(line), label + ": the card tooltip keeps the complete ability text")
	if bool(described.get("unknown", false)):
		_check(status.contains(CardShortRules.UNKNOWN_SENTENCE)
				or tooltip.contains(CardShortRules.UNKNOWN_SENTENCE),
				label + ": an undescribed authored effect is labelled honestly, never guessed")
	_check(button.text.split("\n")[0].ends_with("  ·  %d gold" % int(offer["price"])),
			label + ": the quoted gold stays on line one after the preview")


## Hover and keyboard focus for each of the three genuine offers.
func _assert_card_previews(context: String, before: Dictionary) -> void:
	for index in range(3):
		var offer: Dictionary = before["stock"]["cards"][index]
		var definition := _authored_definition(offer)
		_check_card_row(index, offer, context + " pre-hover")
		await _hover_card(index)
		_check_preview(index, offer, definition, context + " hover card " + str(index))
		_check(intents.is_empty() and panel._source_current(),
				context + " hover card " + str(index) + ": preview only, no intent and no source drift")
	for index in range(3):
		await _hover_none()
		panel.card_buttons[index].grab_focus()
		await _frames()
		var offer: Dictionary = before["stock"]["cards"][index]
		var definition := _authored_definition(offer)
		_check(panel.card_buttons[index].has_focus(),
				context + " keyboard card " + str(index) + " has real focus")
		_check_preview(index, offer, definition, context + " focus card " + str(index))
		_check_card_row(index, offer, context + " focus")
	_check(intents.is_empty() and panel._source_current(),
			context + ": focused previews emit no intent and never mutate the source")


func _preview_cases() -> void:
	var run_state := rng.state
	# --- one genuine main visit explains every card before any purchase ---
	var visit := _visit(GOLD, "peddler_preview_main")
	var before := visit.read_state()
	_check(visit.is_open(), "preview fixture is a genuine open visit")
	await _bind(visit)
	await _assert_card_previews("main", before)
	_check(intents.is_empty() and visit.read_state() == before,
			"hovering and focusing cards changes no ledger and emits nothing")
	# A shortened display is only a display: the unshortened sentence stays in
	# the card's own tooltip.
	var overlong := LivePeddlerPanel.STATUS_OPEN.repeat(4)
	var shortened: String = panel._clamp_status(overlong)
	var status_font := panel.status_label.get_theme_font("font")
	var shortened_width := 0.0
	if status_font != null:
		shortened_width = status_font.get_string_size(shortened,
				HORIZONTAL_ALIGNMENT_LEFT, -1,
				panel.status_label.get_theme_font_size("font_size")).x
	_check(status_font != null and shortened.ends_with(LivePeddlerPanel.ELLIPSIS)
			and shortened.length() < overlong.length()
			and shortened_width <= LivePeddlerPanel.STATUS_WIDTH,
			"an overlong line is shortened to the status band's width")
	_check(panel._card_tooltip(0).contains(str(before["stock"]["cards"][0]["id"]))
			and panel._card_tooltip(0).contains(
				CardShortRules.line(_authored_definition(before["stock"]["cards"][0]))),
			"the complete ability text stays in the card tooltip, not only its display")

	# --- patch/Leave focus returns the neutral hint ---
	await _hover_none()
	panel.patch_button.grab_focus()
	await _frames()
	_check(panel.status_label.text == LivePeddlerPanel.STATUS_OPEN and panel._preview_index == -1
			and _status_fits(), "patch focus returns to the neutral Peddler hint")
	panel.leave_button.grab_focus()
	await _frames()
	_check(panel.status_label.text == LivePeddlerPanel.STATUS_OPEN and panel._preview_index == -1
			and _status_fits(), "Leave focus returns to the neutral Peddler hint")

	# --- a different highlighted card replaces the earlier summary ---
	panel.card_buttons[0].grab_focus()
	await _frames()
	var first := panel.status_label.text
	await _hover_card(1)
	_check(panel.status_label.text != first and panel._preview_index == 1
			and _status_fits(), "hovering another card replaces the earlier preview")
	await _hover_none()
	_check(panel.status_label.text == first and panel._preview_index == 0,
			"leaving the pointer returns to the focused card's preview")

	# --- a second authentic visit (real V3 heroes) replaces every detail ---
	var v3 := _party_visit("peddler_preview_v3", PARTY_V3, DECK_V3,
			_seeded_stock(PARTY_V3, V3_SEED))
	var v3_before := v3.read_state()
	_check(v3.is_open() and _offer_owners(v3_before) == PARTY_V3
			and v3_before["stock"]["trinkets"].size() == 1,
			"authentic seeded stock offers one real card per V3 party hero and one patch")
	await _bind(v3)
	for index in range(3):
		var offer: Dictionary = v3_before["stock"]["cards"][index]
		var tooltip := panel.card_buttons[index].tooltip_text
		_check(tooltip.contains(str(offer["id"])),
				"rebind gives card " + str(index) + " the new source's tooltip")
		for old in before["stock"]["cards"]:
			if str(old["id"]) != str(offer["id"]):
				_check(not tooltip.contains(str(old["id"])),
						"rebind drops the previous visit's card " + str(old["id"]) + " from every tooltip")
	if panel._preview_index >= 0:
		_check(panel.status_label.text.contains(str(v3_before["stock"]["cards"][panel._preview_index]["id"])),
				"rebind replaces the status summary with the new source")
	else:
		_check(panel.status_label.text == LivePeddlerPanel.STATUS_OPEN,
				"rebind shows the neutral hint when no new card is highlighted")
	await _assert_card_previews("v3", v3_before)

	# --- V3 heroes carry their own authored (not guessed) rule text ---
	for index in range(3):
		var offer: Dictionary = v3_before["stock"]["cards"][index]
		var definition := _authored_definition(offer)
		_check(["lantern_monk", "rag_duelist"].has(str(offer["owner"]))
				or str(offer["owner"]) == "warden",
				"the V3 fixture really offers a V3 hero card: " + str(offer["id"]))
		_check(str(definition.get("owner", "")) == str(offer["owner"]),
				"the offered V3 card resolves to its own authored owner")

	# --- a different authentic three-hero party exercises yarn and button
	# motifs without inventing stock or borrowing another hero's card data. ---
	var more_stock := _seeded_stock(PARTY_MORE, 78113)
	_check(more_stock.get("ok") == true, "the Yarn/Button/Scarecrow generator supplies genuine priced stock")
	if more_stock.get("ok") == true:
		var more := _party_visit("peddler_more_motifs", PARTY_MORE, DECK_MORE, more_stock)
		var more_before := more.read_state()
		_check(more.is_open() and _offer_owners(more_before) == PARTY_MORE,
				"the second v3 cohort opens with three correctly owned card offers")
		if more.is_open():
			await _bind(more)
			await _assert_card_previews("more v3 motifs", more_before)
			_check(more.read_state() == more_before and intents.is_empty(),
					"the Yarn/Button/Scarecrow rows only read the quoted stock")

	# --- an authored effect the formatter cannot describe stays honest ---
	var unknown_visit := _party_visit("peddler_preview_unknown", PARTY_V3_UNKNOWN,
			DECK_V3_UNKNOWN, _seeded_stock(PARTY_V3_UNKNOWN, V3_UNKNOWN_SEED))
	var unknown_before := unknown_visit.read_state()
	_check(unknown_visit.is_open(), "unknown-effect preview fixture is a genuine open visit")
	var scarecrow_index := -1
	for index in range(3):
		if str(unknown_before["stock"]["cards"][index]["owner"]) == "scarecrow":
			scarecrow_index = index
	_check(scarecrow_index >= 0, "the V3 fixture genuinely offers Scarecrow's priced card")
	await _bind(unknown_visit)
	if scarecrow_index >= 0:
		var scarecrow_offer: Dictionary = unknown_before["stock"]["cards"][scarecrow_index]
		var scarecrow_definition := _authored_definition(scarecrow_offer)
		var described := CardShortRules.describe(scarecrow_definition)
		_check(described.get("known") == true and described.get("unknown") == true
				and str(described.get("line", "")).contains(CardShortRules.UNKNOWN_SENTENCE),
				"Scarecrow Re-Stuff authors an effect the formatter must not guess")
		panel.card_buttons[scarecrow_index].grab_focus()
		await _frames()
		_check(panel.status_label.text.contains(CardShortRules.UNKNOWN_SENTENCE)
				and panel.card_buttons[scarecrow_index].tooltip_text.contains(
					CardShortRules.UNKNOWN_SENTENCE),
				"the preview labels that undescribed authored effect honestly")
		_check(not panel.status_label.text.contains("10")
				and not panel.status_label.text.contains("HP"),
				"the preview invents no heal or max-HP number for it")
		_check(_status_fits(), "the honest preview still fits the band")
		# A definition that is not exactly this offer can never describe it.
		var authentic := panel._source.duplicate(true)
		panel._source["stock"]["cards"][scarecrow_index]["owner"] = "warden"
		var placeholder: String = panel._card_preview(scarecrow_index)
		var bad_row: String = panel._card_caption(scarecrow_index)
		_check(placeholder.contains(LivePeddlerPanel.DETAILS_UNAVAILABLE)
				and not placeholder.contains("Other authored effects"),
				"a mismatched definition shows Card details unavailable, not a guessed effect")
		_check(bad_row.split("\n").size() == 2
				and bad_row.contains(LivePeddlerPanel.DETAILS_UNAVAILABLE)
				and not bad_row.contains(" energy"),
				"a mismatched row cannot invent a mechanic or zero-energy eligibility")
		panel._source = authentic

	# --- invalid, consumed and externally closed sources clear the detail ---
	var invalid := RunPeddlerVisit.new("", PARTY, DECK, [], GOLD, sampled)
	_check(not invalid.is_valid(), "invalid preview fixture is genuinely rejected")
	await _bind(invalid)
	_check(panel.status_label.text == LivePeddlerPanel.STATUS_CLOSED and _all_tooltips_empty(),
			"an invalid source clears every preview and tooltip")
	var used := _visit(GOLD, "peddler_preview_used")
	var used_open := used.read_state()
	_check(used.leave(used_open["node_id"], used_open["state"], used_open["stock"]).get("ok") == true,
			"preview fixture visit is really consumed")
	await _bind(used)
	_check(panel.status_label.text == LivePeddlerPanel.STATUS_CLOSED and _all_tooltips_empty(),
			"a consumed source clears every preview and tooltip")
	var closing := _visit(GOLD, "peddler_preview_closing")
	await _bind(closing)
	await _hover_card(0)
	_check(panel._preview_index == 0 and not panel.card_buttons[0].tooltip_text.is_empty(),
			"a genuine source previews before it closes")
	var closing_open := closing.read_state()
	_check(closing.leave(closing_open["node_id"], closing_open["state"],
			closing_open["stock"]).get("ok") == true, "fixture visit closes while still bound")
	await _hover_none()
	_check(panel.status_label.text == LivePeddlerPanel.STATUS_CLOSED and _all_tooltips_empty(),
			"a source closed while bound clears the detail on the next highlight change")

	# --- previews are read-only for the ledger, intents and the seeded RNG ---
	_check(intents.is_empty() and rng.state == run_state,
			"every preview left the seeded run RNG and the intent log untouched")

	# --- a real purchase after previews is still source-bound and once-only ---
	var buy := _party_visit("peddler_preview_buy", PARTY_V3, DECK_V3,
			_seeded_stock(PARTY_V3, V3_SEED))
	var buy_before := buy.read_state()
	await _bind(buy)
	var target := 1
	var offer: Dictionary = buy_before["stock"]["cards"][target]
	await _hover_card(target)
	_check(panel._preview_index == target, "the purchase target is previewed before the click")
	await _act(panel.card_buttons[target], false)
	_check(intents.size() == 1, "one previewed click emits exactly one intent")
	if intents.size() == 1:
		_check(intents[0] == {
			"node_id": buy_before["node_id"], "kind": "card", "id": offer["id"],
			"expected_state": buy_before["state"],
			"expected_stock": buy_before["stock"],
		}, "the intent still carries exactly the source-bound node, kind, ID and both snapshots")
		var receipt := Controller.settle(buy, intents[0], buy_before)
		_check(receipt.get("ok") == true and receipt.get("price") == int(offer["price"])
				and receipt["state"]["gold"] == GOLD - int(offer["price"])
				and receipt["state"]["deck"] == DECK_V3 + [offer["id"]],
				"previews did not disturb the once-only authored-price purchase")
		_check(buy.is_consumed() and Controller.settle(buy, intents[0], buy_before).get("ok") != true,
				"replay after that purchase is still refused")


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


## Independent spies on the mounted controls: they count real Button.pressed
## emissions without passing through the panel's own intent callbacks.
func _spy(name: String, button: Button) -> void:
	presses[name] = 0
	button.pressed.connect(_count_press.bind(name))


func _count_press(name: String) -> void:
	presses[name] = int(presses[name]) + 1


func _press_totals() -> Dictionary:
	return presses.duplicate()


## Exactly the named spy (or no spy at all, for a refused shortcut) gained one
## press and every other mounted control stayed silent.
func _pressed_only(name: String, before: Dictionary) -> bool:
	for key in presses:
		var expected := int(before[key]) + (1 if key == name else 0)
		if int(presses[key]) != expected:
			return false
	return true


## One genuine physical number key through the real viewport. Returns true when
## the event reached the unhandled stage, i.e. the Peddler did NOT consume it.
func _push_shortcut(key: Key, echo: bool = false, shift: bool = false) -> bool:
	observer.seen.clear()
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	event.echo = echo
	event.shift_pressed = shift
	root.push_input(event)
	await _frames()
	var passed_on := observer.seen.has(key)
	var release := InputEventKey.new()
	release.keycode = key
	release.pressed = false
	release.echo = echo
	release.shift_pressed = shift
	root.push_input(release)
	await _frames()
	return passed_on


func _shortcut_cases() -> void:
	# --- enabled offers: 1/2/3 cards, 4 patch, 0 Leave, each pressed once ---
	var scenarios := [
		{"key": KEY_1, "index": 0, "kind": "card", "spy": "card0"},
		{"key": KEY_2, "index": 1, "kind": "card", "spy": "card1"},
		{"key": KEY_3, "index": 2, "kind": "card", "spy": "card2"},
		{"key": KEY_4, "index": 0, "kind": "trinket", "spy": "patch"},
		{"key": KEY_0, "index": -1, "kind": "leave", "spy": "leave"},
	]
	for scenario in scenarios:
		var key: int = scenario["key"]
		var index: int = scenario["index"]
		var kind: String = scenario["kind"]
		var spy_name: String = scenario["spy"]
		var visit := _visit(GOLD, "peddler_shortcut_" + str(key))
		var before := visit.read_state()
		await _bind(visit)
		panel.card_buttons[0].grab_focus()
		await _frames()
		_check(panel.get_viewport().gui_get_focus_owner() == panel.card_buttons[0],
				"panel button has focus before shortcut " + str(key))
		var counts := _press_totals()
		var passed_on := await _push_shortcut(key)
		_check(not passed_on, "enabled shortcut " + str(key) + " is handled, not passed on")
		_check(_pressed_only(spy_name, counts),
				"shortcut " + str(key) + " presses exactly its own enabled button once")
		_check(intents.size() == 1, "shortcut key " + str(key) + " emits exactly one intent")
		if intents.size() != 1:
			continue
		var receipt := Controller.settle(visit, intents[0], before)
		_check(receipt.get("ok") == true and receipt.get("kind", "leave") == kind,
				"shortcut key " + str(key) + " settles authentically")
		if kind == "leave":
			_check(receipt.get("state") == before["state"]
					and receipt.get("stock") == before["stock"],
					"the Leave shortcut spends nothing and changes no quote")
		else:
			var expected := _expected_receipt(before, kind, index)
			_check(receipt.get("price") == expected["price"]
					and receipt.get("state") == expected["state"]
					and receipt.get("stock") == expected["stock"],
					"the " + kind + " shortcut charges the authored quote exactly once")
		_check(visit.is_consumed() and visit.read_state().get("status") != "open",
				"shortcut key " + str(key) + " closes the visit exactly once")
		_check(Controller.settle(visit, intents[0], before).get("ok") != true,
				"replaying the settled shortcut intent is refused")
		var replay_counts := _press_totals()
		await _push_shortcut(key)
		_check(_pressed_only("", replay_counts) and intents.size() == 1,
				"replaying shortcut key " + str(key) + " presses no control")

	# --- zero gold: all four paid offers disabled, the free Leave intact ---
	var broke := _visit(0, "peddler_shortcut_broke")
	var broke_before := broke.read_state()
	await _bind(broke)
	_check(panel.leave_button.has_focus(),
			"the zero-gold panel focuses its only enabled action")
	for key in [KEY_1, KEY_2, KEY_3, KEY_4]:
		var counts := _press_totals()
		var passed_on := await _push_shortcut(key)
		_check(_pressed_only("", counts),
				"broke visit: disabled shortcut " + str(key) + " presses no button")
		_check(passed_on, "broke visit: disabled shortcut " + str(key) + " is not consumed")
		_check(intents.is_empty() and broke.read_state() == broke_before,
				"broke visit: disabled shortcut " + str(key) + " emits no intent and spends nothing")
	var leave_counts := _press_totals()
	var leave_passed_on := await _push_shortcut(KEY_0)
	_check(not leave_passed_on and _pressed_only("leave", leave_counts),
			"broke visit: 0 still presses the one free Leave and is handled")
	_check(intents.size() == 1 and intents[0]["kind"] == "leave",
			"broke visit: 0 shortcut emits one Leave intent")
	if intents.size() == 1:
		var leave_receipt := Controller.settle(broke, intents[0], broke_before)
		_check(leave_receipt.get("ok") == true and leave_receipt.get("decision") == "leave"
				and leave_receipt["state"] == broke_before["state"]
				and leave_receipt["stock"] == broke_before["stock"],
				"broke visit: that Leave settles free against the real service")

	# --- owned/SOLD patch: key 4 inert, an enabled card still authentic ---
	var patch_id: String = str(sampled["patches"][0]["id"])
	var sold := _visit(GOLD, "peddler_shortcut_sold", [patch_id])
	var sold_before := sold.read_state()
	await _bind(sold)
	_check(panel.patch_button.disabled and sold_before["stock"]["trinkets"][0]["sold"],
			"owned-patch fixture really disables the patch offer")
	panel.card_buttons[0].grab_focus()
	await _frames()
	var patch_counts := _press_totals()
	var patch_passed_on := await _push_shortcut(KEY_4)
	_check(_pressed_only("", patch_counts) and intents.is_empty(),
			"owned patch: key 4 makes zero patch presses and no intent")
	_check(patch_passed_on and sold.read_state() == sold_before,
			"owned patch: key 4 is not consumed and changes no quote")
	var card_counts := _press_totals()
	var card_passed_on := await _push_shortcut(KEY_1)
	_check(not card_passed_on and _pressed_only("card0", card_counts),
			"owned patch: enabled key 1 still presses exactly one card")
	_check(intents.size() == 1 and intents[0]["kind"] == "card",
			"owned patch: enabled key 1 still sends a valid card intent")
	if intents.size() == 1:
		var card_receipt := Controller.settle(sold, intents[0], sold_before)
		_check(card_receipt.get("ok") == true
				and card_receipt["state"]["trinkets"] == [patch_id]
				and card_receipt["state"]["deck"] == DECK
				+ [str(sold_before["stock"]["cards"][0]["id"])]
				and card_receipt["price"] == int(sold_before["stock"]["cards"][0]["price"]),
				"owned patch: the card shortcut still settles at its authored quote")

	# --- refusals: unrelated, focus away, echo, modifier, hidden, stale, closed ---
	var guarded := _visit(GOLD, "peddler_shortcut_guarded")
	var guarded_before := guarded.read_state()
	await _bind(guarded)
	panel.card_buttons[0].grab_focus()
	await _frames()

	var unrelated_counts := _press_totals()
	_check(await _push_shortcut(KEY_9) and _pressed_only("", unrelated_counts)
			and intents.is_empty(), "unrelated key does nothing and stays unconsumed")

	var other_control := Control.new()
	other_control.focus_mode = Control.FOCUS_ALL
	host.add_child(other_control)
	other_control.grab_focus()
	await _frames()
	var away_counts := _press_totals()
	_check(await _push_shortcut(KEY_1) and _pressed_only("", away_counts)
			and intents.is_empty(), "shortcut ignored when focus is away")
	other_control.queue_free()
	panel.card_buttons[0].grab_focus()
	await _frames()

	var echo_counts := _press_totals()
	_check(await _push_shortcut(KEY_1, true) and _pressed_only("", echo_counts)
			and intents.is_empty(), "shortcut ignores echo events and does not consume them")

	var mod_counts := _press_totals()
	_check(await _push_shortcut(KEY_1, false, true) and _pressed_only("", mod_counts)
			and intents.is_empty(), "shortcut ignores modifier keys and does not consume them")

	panel.hide()
	var hidden_counts := _press_totals()
	_check(await _push_shortcut(KEY_1) and _pressed_only("", hidden_counts)
			and intents.is_empty(), "hidden panel presses nothing for a shortcut")
	panel.show()
	await _frames()
	panel.card_buttons[0].grab_focus()
	await _frames()

	guarded._purchases._state["gold"] += 1
	var stale_counts := _press_totals()
	_check(await _push_shortcut(KEY_1) and _pressed_only("", stale_counts)
			and intents.is_empty(), "stale bound source presses nothing for a shortcut")
	guarded._purchases._state["gold"] -= 1
	_check(guarded.read_state() == guarded_before,
			"restored source is still the unchanged open visit")

	var closing := _visit(GOLD, "peddler_shortcut_closed")
	var closing_before := closing.read_state()
	await _bind(closing)
	_check(closing.leave(closing_before["node_id"], closing_before["state"],
			closing_before["stock"]).get("ok") == true, "shortcut fixture really closes")
	var closed_counts := _press_totals()
	_check(await _push_shortcut(KEY_1) and _pressed_only("", closed_counts)
			and intents.is_empty(), "closed visit presses nothing for a shortcut")

	# --- one accepted shortcut retires every control and refuses a replay ---
	await _bind(guarded)
	panel.card_buttons[0].grab_focus()
	await _frames()
	var first_counts := _press_totals()
	_check(not await _push_shortcut(KEY_1) and _pressed_only("card0", first_counts)
			and intents.size() == 1, "first valid shortcut presses once and emits once")
	var second_counts := _press_totals()
	await _push_shortcut(KEY_2)
	_check(_pressed_only("", second_counts) and intents.size() == 1,
			"second valid shortcut cannot press or emit while pending")


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
	# An unaffordable offer still explains itself truthfully before the player
	# has to choose between it and Leave.
	await _hover_card(0)
	var broke_offer: Dictionary = broke_open["stock"]["cards"][0]
	var broke_definition := _authored_definition(broke_offer)
	var broke_line := CardShortRules.line(broke_definition)
	_check(not broke_definition.is_empty() and not broke_line.is_empty(),
			"the unaffordable fixture card has a genuine authored rule line")
	_check(panel.card_buttons[0].disabled and panel._preview_index == 0
			and panel.status_label.text.contains(broke_line)
			and panel.status_label.text.contains("%d energy" % int(broke_definition.get("cost", -1)))
			and panel.status_label.text.contains(str(broke_offer["id"])) and _status_fits(),
			"an unaffordable card still previews its authored cost and effect")
	_check(intents.is_empty() and broke.read_state() == broke_open,
			"the unfunded preview spends nothing and emits nothing")
	await _hover_none()
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
	panel.status_label.text = "Forged card preview  ·  deal 99 to every enemy"
	card_callback.call()
	_check(intents.is_empty(), "forged status preview text cannot authenticate a press")
	panel._sync_preview()
	_check(panel.status_label.text != "Forged card preview  ·  deal 99 to every enemy",
			"the band is restored from the bound source, never the forged line")

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


func _rare_patch_panels() -> void:
	for patch_id in ["relay_bobbin", "hearth_lining"]:
		var stock := {}
		for value in range(1, 10000):
			var seeded := RandomNumberGenerator.new()
			seeded.seed = value
			var candidate := RunShopStockOffers.generate_peddler_stock(seeded, PARTY,
				authored_cards, authored_patches, [])
			if candidate.ok and candidate.patches[0].id == patch_id:
				stock = candidate
				break
		_check(not stock.is_empty(), "real seeded Peddler sample reaches " + patch_id)
		if stock.is_empty():
			continue
		var visit := RunPeddlerVisit.new(NODE, PARTY, DECK, [], GOLD, stock)
		_check(visit.is_valid() and visit.is_open(), "rare mounted panel has genuine open service")
		await _bind(visit)
		var before := visit.read_state()
		_check(panel.patch_button.text.contains(patch_id.replace("_", " ").capitalize())
			and panel.patch_button.text.contains("100 gold") and panel.card_buttons.size() == 3,
			"rare uses existing readable priced patch row without extra offer")
		await _act(panel.patch_button, patch_id == "hearth_lining")
		_check(intents.size() == 1 and intents[0].get("id") == patch_id,
			"rare mouse/keyboard action emits genuine source-bound selection")
		if intents.size() != 1:
			continue
		var receipt := Controller.settle(visit, intents[0], before)
		_check(receipt.ok and receipt.state.gold == GOLD - 100
			and receipt.state.trinkets.has(patch_id), "rare actual service receipt pays 100 exactly once")
		var settled := visit.read_state()
		_check(not Controller.settle(visit, intents[0], before).ok and visit.read_state() == settled,
			"rare panel receipt replay cannot spend again")
