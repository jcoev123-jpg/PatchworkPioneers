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
var trusted_projection: Dictionary = {}
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
	await _portrait_missing_and_rebind_case(visit)
	_long_rule_case()
	_sold_card_projection_case(visit)
	await _preview_cases()
	await _portrait_click_case()
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
	await _patch_preview_cases()
	await _unaudited_patch_case()
	await _shared_hem_case()
	await _needle_echo_case()
	await _ambient_art_cases()
	_check(rng.state == expected_run,
			"all panel previews, intents and refusals preserve seeded run RNG")
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
	var allowance := panel._card_text_width(button) if panel.card_buttons.has(button) else button.size.x - 16.0
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
	var prefix := LivePeddlerPanel.ACTION_KEY_LABELS[index] + "  ·  " + str(offer["owner"]).capitalize() + "  ·  "
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
			label + ": key label, quote, sale/shortfall and catalog display name coexist")
	var energy := "%d energy  ·  " % int(definition["cost"])
	var effect := lines[1].substr(energy.length()) if lines[1].begins_with(energy) else ""
	var full := str(described["line"])
	var first_word := full.get_slice(" ", 0)
	_check(lines[1].begins_with(energy) and not effect.is_empty()
			and (effect == full or (effect.ends_with(LivePeddlerPanel.ELLIPSIS)
			and effect.contains(first_word))) ,
			label + ": measured row exposes real energy and recognisable authored mechanic")
	# A priced condition remains visible when its whole qualifier can fit
	# beside the shortened mechanic; the tooltip still holds the full rule.
	var font := button.get_theme_font("font")
	var px := button.get_theme_font_size("font_size")
	var rule_budget := panel._card_text_width(button) - panel._row_width(font, energy, px)
	for marker in [" if ", " when ", " while ", " after ", " unless ", " per "]:
		var split := full.find(marker)
		if split > 0:
			var qualifier := full.substr(split)
			if panel._row_width(font, qualifier, px) + panel._row_width(
					font, LivePeddlerPanel.ELLIPSIS, px) < rule_budget:
				_check(effect.ends_with(qualifier),
						label + ": fitted rule keeps its meaningful authored condition")
			break
	_check(button.tooltip_text.contains(str(offer["id"]))
			and button.tooltip_text.contains("%d energy" % int(definition["cost"]))
			and button.tooltip_text.contains(full)
			and button.tooltip_text.contains("%d gold" % int(offer["price"])),
			label + ": full rule, ID and quote remain in tooltip")
	_check(_fits(button) and button.size == LivePeddlerPanel.CARD_TICKET_SIZE
			and button.get_theme_font_size("font_size") >= 18,
			label + ": both lines fit the actual compact ticket font geometry")


## The actual three source-bound card Buttons, not detached picture buttons,
## carry one input-inert, unfocusable authored owner image each.
func _check_offer_portrait(index: int, offer: Dictionary, context: String) -> void:
	var button := panel.card_buttons[index]
	var owner := str(offer["owner"])
	var path := str(LivePeddlerPanel.HERO_PORTRAITS.get(owner, ""))
	var images := button.find_children("HeroPortrait", "TextureRect", false, false)
	var portrait := button.get_node_or_null("HeroPortrait") as TextureRect
	var label := context + " card " + str(index)
	_check(not path.is_empty() and ResourceLoader.exists(path, "Texture2D"),
			label + ": offered canonical owner has a shipped imported portrait")
	_check(images.size() == 1 and portrait != null and portrait.get_parent() == button,
			label + ": actual buy Button owns exactly one persistent portrait")
	if portrait == null:
		return
	_check(portrait.visible and portrait.texture != null
			and portrait.get_meta("art_path") == path
			and portrait.texture.resource_path == path,
			label + ": portrait is imported from the authenticated offer owner")
	_check(portrait.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and portrait.focus_mode == Control.FOCUS_NONE
			and portrait.expand_mode == TextureRect.EXPAND_IGNORE_SIZE
			and portrait.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED,
			label + ": illustration never intercepts mouse or keyboard focus and fits without stretch")
	_check(button.position == Vector2(39, 142 + 88 * index)
			and button.size == LivePeddlerPanel.CARD_TICKET_SIZE
			and button.focus_mode == Control.FOCUS_ALL
			and Rect2(Vector2.ZERO, button.size).encloses(Rect2(portrait.position, portrait.size))
			and portrait.position.x + portrait.size.x < LivePeddlerPanel.CARD_PORTRAIT_TEXT_LEFT,
			label + ": original fixed input rectangle and stitched edge remain clear")
	var face := button.get_theme_stylebox("normal") as StyleBoxFlat
	var inset_ok := face != null 			and face.get_content_margin(SIDE_LEFT) == LivePeddlerPanel.CARD_PORTRAIT_TEXT_LEFT
	for state in ["hover", "pressed", "disabled"]:
		var other := button.get_theme_stylebox(state) as StyleBoxFlat
		inset_ok = inset_ok and other != null 				and other.get_content_margin(SIDE_LEFT) == LivePeddlerPanel.CARD_PORTRAIT_TEXT_LEFT
	_check(inset_ok and button.alignment == HORIZONTAL_ALIGNMENT_LEFT
			and _fits(button), label + ": all states reserve a measured text pocket with 18px+ rows")


## Missing imports must not leave a blank reserved gutter, obscure captions,
## duplicate portraits, change source state or replace any purchase control.
func _portrait_missing_and_rebind_case(visit: RunPeddlerVisit) -> void:
	var prior := visit.read_state()
	_check(visit.is_open() and _offer_owners(prior) == PARTY,
			"portrait fallback starts with an authentic seeded three-owner visit")
	var portraits: Array = []
	for button in panel.card_buttons:
		portraits.append(button.get_node("HeroPortrait"))
	var missing_owner := str(prior["stock"]["cards"][0]["owner"])
	var real_path := str(panel._portrait_paths[missing_owner])
	panel._portrait_paths[missing_owner] = "res://assets/paper/heroes/missing_peddler_offer_art.png"
	_check(not ResourceLoader.exists(panel._portrait_paths[missing_owner], "Texture2D"),
			"art-less seam points at a genuinely missing import")
	panel._refresh()
	var button := panel.card_buttons[0]
	var image := button.get_node("HeroPortrait") as TextureRect
	var face := button.get_theme_stylebox("normal") as StyleBoxFlat
	_check(not image.visible and image.texture == null and image.get_meta("art_path") == ""
			and face.get_content_margin(SIDE_LEFT) == 8.0
			and panel._card_text_width(button) > LivePeddlerPanel.TICKET_WIDTH - LivePeddlerPanel.CARD_PORTRAIT_TEXT_LEFT - LivePeddlerPanel.CARD_TEXT_RIGHT,
			"missing image restores the wider text-first caption, not an empty portrait pocket")
	_check_card_row(0, prior["stock"]["cards"][0], "portrait-less fallback")
	_check(button.size == LivePeddlerPanel.CARD_TICKET_SIZE and not button.disabled
			and button.get_theme_stylebox("focus") != null,
			"portrait-less real card retains its fixed, usable focusable Button")
	_check(visit.read_state() == prior and intents.is_empty(),
			"simulated missing import neither spends nor emits a purchase intent")
	panel._portrait_paths[missing_owner] = real_path
	panel._refresh()
	for index in range(3):
		var offered: Dictionary = prior["stock"]["cards"][index]
		_check(panel.card_buttons[index].get_node("HeroPortrait") == portraits[index],
				"repeated same-visit refresh retains the sole existing image child")
		_check_offer_portrait(index, offered, "recovered import")
	await _bind(_visit(GOLD, "peddler_portrait_renewed"))
	var renewed := panel._source.duplicate(true)
	_check(renewed.get("status") == "open", "portrait rebind is another real open visit")
	for index in range(3):
		_check(panel.card_buttons[index].get_node("HeroPortrait") == portraits[index]
				and panel.card_buttons[index].find_children("HeroPortrait", "TextureRect", false, false).size() == 1,
				"fresh authenticated visit reuses its existing portrait child")
		_check_offer_portrait(index, renewed["stock"]["cards"][index], "renewed visit")
	_check(intents.is_empty() and visit.read_state() == prior,
			"rebind of a portrait never submits or mutates the earlier visit")
	await _bind(visit)


## A physical click in the image area must be handled by the SAME authentic
## card Button exactly once; only the controller is allowed to spend gold.
func _portrait_click_case() -> void:
	var visit := _visit(GOLD, "peddler_portrait_click")
	var prior := visit.read_state()
	_check(visit.is_open(), "portrait click starts with a genuine funded visit")
	await _bind(visit)
	var button := panel.card_buttons[0]
	var portrait := button.get_node("HeroPortrait") as TextureRect
	_check_offer_portrait(0, prior["stock"]["cards"][0], "picture-area hit")
	var target := portrait.get_global_rect().get_center()
	_check(button.get_global_rect().has_point(target),
			"physical portrait center remains inside the original card Button")
	var motion := InputEventMouseMotion.new()
	motion.position = target
	root.push_input(motion)
	await process_frame
	_check(intents.is_empty() and visit.read_state() == prior,
			"pointer movement across authored art cannot emit an intent or spend")
	for down in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = target
		click.pressed = down
		root.push_input(click)
		await process_frame
	await _frames()
	_check(intents.size() == 1 and visit.read_state() == prior,
			"picture-area click emits a single intent without charging the wallet")
	if intents.size() == 1:
		var offer: Dictionary = prior["stock"]["cards"][0]
		_check(intents[0] == {
			"node_id": prior["node_id"], "kind": "card", "id": offer["id"],
			"expected_state": prior["state"], "expected_stock": prior["stock"],
		}, "picture-area hit forwards exactly the original authenticated card request")
		var receipt := Controller.settle(visit, intents[0], prior)
		_check(receipt.get("ok") == true and receipt["price"] == offer["price"]
				and receipt["state"]["gold"] == GOLD - int(offer["price"]),
				"picture-area request settles once at the unmodified authored price")


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
	var font := button.get_theme_font("font")
	var px := button.get_theme_font_size("font_size")
	var sold_lines := sold_caption.split("\n")
	_check(font != null and sold_lines.size() == 2
			and panel._row_width(font, sold_lines[0], px) <= panel._card_text_width(button)
			and panel._row_width(font, sold_lines[1], px) <= panel._card_text_width(button),
			"priced SOLD caption remains inside the portrait-adjusted two-line text interior")
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
	_check(LivePeddlerPanel.ACTION_KEY_LABELS == ["1", "2", "3", "4", "0"],
			"the five visible labels are the exact keys the panel routes: 1/2/3 cards, 4 patch, 0 Leave")
	# VIS-A: a genuinely opaque sewn-fabric backdrop keeps the illustrated
	# market from showing through under the labels; the imported art floats
	# on it and the art-less fallback is that same solid fabric.
	var fabric_backing := panel.get_node_or_null("FabricBacking") as Panel
	var art_backing := panel.get_node_or_null("PanelArt") as Panel
	var fabric_face: StyleBoxFlat = null
	if fabric_backing != null:
		fabric_face = fabric_backing.get_theme_stylebox("panel") as StyleBoxFlat
	_check(fabric_backing != null and art_backing != null
			and fabric_face != null and fabric_face.bg_color.a == 1.0
			and fabric_face.bg_color.get_luminance() < 0.3
			and fabric_backing.get_global_rect() == panel.get_global_rect()
			and fabric_backing.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and art_backing.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"alpha-1 deep-jewel fabric backs the whole sewn panel under the labels")
	if art_backing != null and ResourceLoader.exists(LivePeddlerPanel.PANEL_ART, "Texture2D"):
		var art_face := art_backing.get_theme_stylebox("panel") as StyleBoxTexture
		_check(art_face != null and art_face.texture != null
				and art_face.texture.resource_path == LivePeddlerPanel.PANEL_ART,
				"the imported reward_panel market art overlays the opaque fabric")
	_check(panel._fabric_style().bg_color.a == 1.0
			and panel._fabric_style().bg_color.get_luminance() < 0.3,
			"the art-less fallback backing is the same fully opaque dark fabric")
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
	_check(LivePeddlerPanel.STATUS_OPEN.contains("party's three cards")
			and LivePeddlerPanel.STATUS_OPEN.contains("leave for free")
			and not LivePeddlerPanel.STATUS_OPEN.contains("1-3")
			and not LivePeddlerPanel.STATUS_OPEN.contains("0 Leave"),
			"neutral hint explains one choice without shortcut diagnostics")
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
		_check_offer_portrait(index, offer, "mounted main")
		var face := button.get_theme_stylebox("normal") as StyleBoxFlat
		var edge := button.get_node_or_null("FabricEdging") as Panel
		_check(face != null and face.bg_color.a == 1.0
				and face.bg_color.get_luminance() > 0.6
				and face.border_width_top >= 4
				and face.get_corner_radius(CORNER_TOP_LEFT) > 0
				and button.get_theme_color("font_color").get_luminance() < 0.25
				and edge != null and edge.mouse_filter == Control.MOUSE_FILTER_IGNORE
				and edge.get_theme_stylebox("panel") is StyleBoxTexture,
				"opaque, clearly bordered card fabric uses imported sewn-button edge")
	_check(panel.patch_button.get_node_or_null("HeroPortrait") == null
			and panel.leave_button.get_node_or_null("HeroPortrait") == null,
			"patch and Leave remain original text-only actions without hero art")
	var patch_button := panel.patch_button
	var patch_offer: Dictionary = open["stock"]["trinkets"][0]
	_check(screen.encloses(patch_button.get_global_rect())
			and patch_button.get_meta("offer_id") == patch_offer["id"]
			and patch_button.get_meta("offer_kind") == "trinket" and not patch_button.disabled,
			"patch row retains authored ID metadata and is actionable")
	_check(patch_button.text.begins_with(LivePeddlerPanel.ACTION_KEY_LABELS[3] + "  ·  "),
			"patch row starts with its own 4 key label")
	_check(not patch_button.text.contains(str(patch_offer["id"]))
			and not patch_button.text.contains("_"), "patch row hides the raw item ID")
	_check(patch_button.text.contains(_expected_name(str(patch_offer["id"]))),
			"patch row shows independently readable authored name")
	_check(patch_button.text.split("\n")[0].ends_with("  ·  %d gold" % int(patch_offer["price"])),
			"patch ticket's first line keeps exact authored gold quote")
	var patch_details: Dictionary = panel._patch_details()
	_check(not patch_details.is_empty()
			and patch_button.text.split("\n").size() == 2
			and patch_button.text.split("\n")[1].begins_with(str(patch_details["slot"]) + "  ·  ")
			and patch_button.text.split("\n")[1].contains(str(patch_details["short"]).get_slice(" ", 0))
			and patch_button.tooltip_text.contains(str(patch_details["full"])),
			"authentic patch ticket shows audited slot and power with full tooltip")
	_check(_fits(patch_button) and patch_button.get_theme_stylebox("focus") != null,
			"patch row text fits its sewn button and has a focus ring")
	var patch_face := patch_button.get_theme_stylebox("normal") as StyleBoxFlat
	var card_face := panel.card_buttons[0].get_theme_stylebox("normal") as StyleBoxFlat
	_check(patch_face != null and card_face != null and patch_face.bg_color.a == 1.0
			and patch_face.bg_color != card_face.bg_color
			and patch_face.border_width_top >= 4
			and patch_button.get_node_or_null("FabricEdging") != null,
			"patch wears a separate opaque contrasting bordered ticket and shipped fabric edge")
	_check(screen.encloses(panel.leave_button.get_global_rect())
			and panel.leave_button.text == "0  ·  Leave  ·  FREE"
			and panel.leave_button.text.begins_with(LivePeddlerPanel.ACTION_KEY_LABELS[4] + "  ·  ")
			and not panel.leave_button.disabled,
			"free Leave is visible, carries its 0 key label and is enabled")
	_check(_fits(panel.leave_button), "Leave text fits its sewn button")
	# VIS-A: each of the five actions is one compact, clearly bordered sewn
	# ticket, so the illustrated market column stays uncovered beside them
	# instead of one edge-to-edge slab.
	var art_edge := panel.get_global_rect().end.x - LivePeddlerPanel.UNCOVERED_ART
	for ticket in panel.card_buttons + [panel.patch_button, panel.leave_button]:
		var ticket_face := ticket.get_theme_stylebox("normal") as StyleBoxFlat
		_check(ticket.size.x == LivePeddlerPanel.TICKET_WIDTH
				and ticket.get_global_rect().end.x <= art_edge
				and ticket_face != null and ticket_face.bg_color.a == 1.0
				and ticket_face.border_width_top >= 4
				and ticket_face.border_width_top == ticket_face.border_width_left
				and ticket_face.get_corner_radius(CORNER_TOP_LEFT) > 0,
				"sewn ticket is compact, opaque and clearly bordered with the market uncovered")
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
	# _caption remains the exact one-line oracle for the patch quote (now led
	# by its own visible 4 key label) and any legacy callers. Card rows instead
	# use measured two-line projections.
	var caption_font := panel.patch_button.get_theme_font("font")
	var caption_size := panel.patch_button.get_theme_font_size("font_size")
	var worst_patch := 0.0
	if caption_font != null:
		for entry in authored_cards + authored_patches:
			var prefix := str(entry["owner"]).capitalize() if entry.has("owner") \
					else LivePeddlerPanel.ACTION_KEY_LABELS[3]
			var line := "%s  ·  %s  ·  %d gold" % [
					prefix, _expected_name(str(entry["id"])), int(entry["price"])]
			_check(panel._caption(prefix, entry["id"], entry["price"], false) == line
					and panel._caption(prefix, entry["id"], entry["price"], true) == line + "  ·  SOLD",
					"legacy one-line caption keeps price and sold suffix: " + entry["id"])
			if prefix == LivePeddlerPanel.ACTION_KEY_LABELS[3]:
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


## The audited projection the live Patch Stall itself binds: the complete
## power/slot map from the same power-only catalogs, passed through that
## panel's own verified-preview audit. Computed once, it is the independent
## oracle for every patch tooltip/preview comparison, so a Peddler row can
## never pass with a description the Patch Stall audit would reject.
func _trusted_projection() -> Dictionary:
	if trusted_projection.is_empty():
		var slots: Dictionary = {}
		for record in RunAuthoredPatchDefinitions.load_power_definitions():
			if typeof(record) == TYPE_DICTIONARY and record.has("id") and record.has("slot"):
				slots[str(record["id"])] = str(record["slot"])
		var stall := LivePatchStallPanel.new()
		var previews: Dictionary = stall._trusted_power_previews(slots)
		stall.free()
		trusted_projection = {"slots": slots, "previews": previews}
	return trusted_projection


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
		_check_offer_portrait(index, offer, context + " portrait")
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

	# --- patch focus shows the truthful patch preview ---
	await _hover_none()
	panel.patch_button.grab_focus()
	await _frames()
	_check(panel.status_label.text.contains(str(before["stock"]["trinkets"][0]["id"]))
		or panel.status_label.text.contains(LivePeddlerPanel.PATCH_DETAILS_UNAVAILABLE),
		"patch focus shows the truthful preview")
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
	# --- enabled offers: 1/2/3 cards, 4 patch, 0 Leave, each pressed once.
	# Physical and keypad digits share one scenario table so the five VISIBLE
	# labels are proven against both key forms the mounted panel dispatches. ---
	var scenarios := [
		{"key": KEY_1, "label": "1", "index": 0, "kind": "card", "spy": "card0"},
		{"key": KEY_2, "label": "2", "index": 1, "kind": "card", "spy": "card1"},
		{"key": KEY_3, "label": "3", "index": 2, "kind": "card", "spy": "card2"},
		{"key": KEY_4, "label": "4", "index": 0, "kind": "trinket", "spy": "patch"},
		{"key": KEY_0, "label": "0", "index": -1, "kind": "leave", "spy": "leave"},
		{"key": KEY_KP_1, "label": "1", "index": 0, "kind": "card", "spy": "card0"},
		{"key": KEY_KP_2, "label": "2", "index": 1, "kind": "card", "spy": "card1"},
		{"key": KEY_KP_3, "label": "3", "index": 2, "kind": "card", "spy": "card2"},
		{"key": KEY_KP_4, "label": "4", "index": 0, "kind": "trinket", "spy": "patch"},
		{"key": KEY_KP_0, "label": "0", "index": -1, "kind": "leave", "spy": "leave"},
	]
	for scenario in scenarios:
		var key: int = scenario["key"]
		var label: String = scenario["label"]
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
		# The shortcut's target is the mounted action whose own caption visibly
		# opens with that exact numeral: the label and the dispatched key agree.
		var labeled: Button = panel.leave_button if kind == "leave" \
				else (panel.patch_button if kind == "trinket" \
				else panel.card_buttons[index])
		_check(labeled.text.begins_with(label + "  ·  "),
				"key " + str(key) + " targets the action visibly labeled " + label)
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
		if index < 3:
			_check_offer_portrait(index, offers[index], "unaffordable source")
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
		# The rare tooltip must state exactly the trusted Patch Stall
		# projection's slot and complete power/trigger for this P8 rare.
		var rare_projection := _trusted_projection()
		var rare_slot := str(rare_projection["slots"].get(patch_id, ""))
		var rare_full := str(rare_projection["previews"].get(patch_id, {}).get("full", ""))
		_check(not rare_slot.is_empty() and not rare_full.is_empty(),
			"trusted Patch Stall projection proves the P8 rare " + patch_id)
		_check(panel.patch_button.tooltip_text.contains(rare_slot)
			and panel.patch_button.tooltip_text.contains(rare_full),
			"rare tooltip states the trusted slot and complete power/trigger")
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


func _patch_preview_cases() -> void:
	# A genuine open visit with one audited patch offer: tooltip, preview,
	# tooltip clearing on close/rebind, and zero transaction mutation.
	var visit := _visit(GOLD, "peddler_patch_preview")
	var before := visit.read_state()
	_check(visit.is_open(), "patch preview fixture is open")
	await _bind(visit)
	var patch_offer: Dictionary = before["stock"]["trinkets"][0]
	var patch_id: String = str(patch_offer["id"])

	# The trusted Patch Stall projection is the independent oracle: the
	# offered patch must be one it proves, and the tooltip must state exactly
	# that audited slot and complete power/trigger, never a second-hand or
	# guessed description.
	var projection := _trusted_projection()
	var power_slots: Dictionary = projection["slots"]
	var power_previews: Dictionary = projection["previews"]
	_check(power_slots.has(patch_id) and power_previews.has(patch_id),
		"offered patch " + patch_id + " is proven by the trusted Patch Stall projection")
	var expected_slot := str(power_slots.get(patch_id, ""))
	var expected_full := str(power_previews.get(patch_id, {}).get("full", ""))
	var expected_short := str(power_previews.get(patch_id, {}).get("short", ""))
	_check(["HEAD", "ARM", "COAT"].has(expected_slot)
		and not expected_full.is_empty() and not expected_short.is_empty(),
		"trusted oracle for " + patch_id + " has a slot, short and full power")
	# The tooltip carries the real slot, complete trusted power, torn
	# suppression and exact replacement rule; never a guessed effect.
	var tooltip := panel.patch_button.tooltip_text
	_check(tooltip.contains(patch_id), "patch tooltip carries the offered patch ID")
	_check(tooltip.contains(expected_slot),
		"patch tooltip states the trusted projection's " + expected_slot + " slot")
	_check(tooltip.contains(expected_full),
		"patch tooltip carries the complete trusted power and trigger")
	_check(tooltip.contains("Patch powers do not work while the wearer is Torn."),
		"patch tooltip includes torn suppression")
	_check(tooltip.contains("destroyed for exactly +1 scrap")
		and tooltip.contains("destroys nothing and gains no scrap"),
		"patch tooltip includes both replacement outcomes")
	_check(tooltip.contains(str(int(patch_offer["price"])) + " gold"),
		"patch tooltip shows the exact quoted gold price")

	# Hover shows exactly the trusted projection in the status band (the band
	# may clamp a long line to its width, but the text is never anything else).
	# We trigger the hover manually to avoid mouse-motion timing differences.
	panel._hover_index = -1
	panel._patch_hover_active = true
	panel._sync_preview()
	await _frames()
	var expected_preview := "%s  ·  %s  ·  %s  ·  %s" % [
		expected_slot, _expected_name(patch_id), patch_id, expected_short]
	var preview_text := panel.status_label.text
	_check(preview_text == expected_preview
		or preview_text == panel._clamp_status(expected_preview),
		"patch hover shows exactly the trusted slot/name/ID/power line")
	_check(preview_text != LivePeddlerPanel.STATUS_CLOSED,
		"patch hover does not show the closed status (mechanism responds)")
	_check(_status_fits(), "patch hover preview fits the status band")

	# Focus shows the same trusted preview for keyboard users.
	await _hover_none()
	panel.patch_button.grab_focus()
	await _frames()
	_check(panel.patch_button.has_focus(), "patch button has real keyboard focus")
	# The preview is set from the focused patch button and repeats the same
	# truthful trusted line, never a different or guessed one.
	var focus_preview := panel.status_label.text
	_check(focus_preview == preview_text,
		"patch focus repeats the same trusted preview as hover")
	_check(focus_preview.contains(expected_short),
		"patch focus carries the trusted projection's short power line")

	# The preview mechanism responds without emitting any purchase intent.
	_check(intents.is_empty(), "patch preview emits no purchase or leave intent")

	# Unknown/unverified patch must close with unavailable, not a guess: the
	# dedicated _unaudited_patch_case below proves that fallback explicitly.

	# Rebind clears previous patch tooltip and shows the new visit's data.
	await _bind(_visit(GOLD, "peddler_patch_rebind"))
	# The new open visit carries a new patch tooltip; it should not be the
	# same as the old one, and it should reflect the new source.
	_check(not panel.patch_button.tooltip_text.is_empty() or panel.patch_button.tooltip_text.contains(LivePeddlerPanel.PATCH_DETAILS_UNAVAILABLE),
		"rebind updates the patch tooltip (not stale)")
	await _hover_none()
	await _frames()

	# Closure clears details.
	await _bind(visit)
	await _hover_none()
	await _frames()
	# All informational inspection (tooltip, hover, focus, rebind) has now
	# happened while this visit was still open: verify the untouched snapshot
	# BEFORE the deliberate Leave below mutates the lifecycle, so this oracle
	# cannot hide an inspection-time mutation behind that Leave.
	_check(visit.read_state() == before, "informational patch inspection leaves visit untouched")
	visit.leave(before["node_id"], before["state"], before["stock"])
	await _frames()
	await _bind(visit)
	await _frames()
	_check(panel.patch_button.tooltip_text == ""
		and panel.status_label.text == LivePeddlerPanel.STATUS_CLOSED,
		"closure clears patch tooltip and shows the closed status")
	_check(intents.is_empty(), "closure inspection emits no intent")

	# The only mutation is this test's own controller-issued Leave: the ledger
	# and stock stay exactly as inspected, and no intent was ever emitted.
	var left_state := visit.read_state()
	_check(left_state["status"] == "left" and left_state["state"] == before["state"]
		and left_state["stock"] == before["stock"],
		"deliberate test leave changes only the lifecycle status")
	_check(intents.is_empty(), "no purchase or leave intent was emitted during preview")


## A genuinely priced, open visit whose offered patch is an authored inert
## starter-slot trinket (the power-only catalog withholds it, so the trusted
## Patch Stall projection cannot prove any power for it) must fail closed:
## the tooltip is exactly the unavailable fallback, hover and focus repeat
## that line, and no guessed buff is ever published - all without a buy.
func _unaudited_patch_case() -> void:
	var unaudited_id := "stitched_badge"
	_check(patch_authored.has(unaudited_id),
		"unaudited fixture is a genuinely authored priced trinket")
	if not patch_authored.has(unaudited_id):
		return
	# Precondition: the trusted projection really cannot prove this ID, so
	# the fallback case cannot pass vacuously.
	var projection := _trusted_projection()
	_check(not projection["slots"].has(unaudited_id)
		and not projection["previews"].has(unaudited_id),
		"unaudited fixture patch is genuinely absent from the trusted projection")
	var stock := {
		"ok": true,
		"cards": sampled["cards"].duplicate(true),
		"patches": [{"id": unaudited_id, "price": int(patch_authored[unaudited_id])}],
	}
	var visit := _party_visit("peddler_unaudited_patch", PARTY, DECK, stock)
	_check(visit.is_valid() and visit.is_open(),
		"unaudited fixture opens a genuine Peddler visit")
	if not visit.is_open():
		return
	var before := visit.read_state()
	await _bind(visit)
	_check(panel.patch_button.get_meta("offer_id") == unaudited_id
		and not panel.patch_button.disabled,
		"unaudited patch row really offers the fixture trinket and is buyable")
	# The exact unavailable tooltip: never a guessed slot, power or trigger.
	var unavailable := "PATCH  ·  %s\n%s" % [
		_expected_name(unaudited_id), LivePeddlerPanel.PATCH_DETAILS_UNAVAILABLE]
	_check(panel.patch_button.tooltip_text == unavailable,
		"unaudited patch tooltip is exactly the unavailable fallback")
	_check(panel._patch_details().is_empty(),
		"unaudited patch resolves to no details at all")
	# Hover fails closed with the same unavailable line.
	panel._hover_index = -1
	panel._patch_hover_active = true
	panel._sync_preview()
	await _frames()
	var hover_text := panel.status_label.text
	_check(hover_text.contains(LivePeddlerPanel.PATCH_DETAILS_UNAVAILABLE),
		"unaudited patch hover fails closed with the unavailable line")
	_check(not hover_text.contains("+") and not hover_text.contains("Block")
		and not hover_text.contains("HP"),
		"unaudited patch hover never guesses a power")
	# Keyboard focus repeats the same unavailable line.
	await _hover_none()
	panel.patch_button.grab_focus()
	await _frames()
	_check(panel.patch_button.has_focus()
		and panel.status_label.text == hover_text,
		"unaudited patch focus repeats the unavailable line")
	# Information only: no intent, no buy, no spend, no state change.
	_check(intents.is_empty() and visit.read_state() == before
		and not visit.is_consumed(),
		"unaudited patch inspection never buys, emits an intent or mutates anything")


## V3-3 P12: both unlocked Heirlooms compete for the ONE
## Peddler patch draw at its authored 100 gold, and the mounted panel explains
## it truthfully before any spend. Everything comes from the real sampler and
## genuine visits on the mounted controls: the default locked flag keeps both
## out of each draw, and hover/keyboard previews pay
## nothing, one real buy settles once at 100 gold, Leave stays free, and the
## ordinary/P8 audited descriptions above are untouched.
func _shared_hem_case() -> void:
	# The canonical contract and the authored record the description must state.
	var required: Dictionary = RunAuthoredPatchDefinitions.HEIRLOOM_REQUIRED.get("shared_hem", {})
	var authored_heirloom: Variant = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/patches/mpw_heirloom_patches.json"))
	var authored_hem: Dictionary = {}
	if typeof(authored_heirloom) == TYPE_ARRAY:
		for record in authored_heirloom:
			if typeof(record) == TYPE_DICTIONARY \
					and str(record.get("id", "")) == "shared_hem":
				authored_hem = record
	_check(not required.is_empty() and not authored_hem.is_empty(),
		"canonical HEIRLOOM_REQUIRED and the authored P12 catalog both carry Shared Hem")
	_check(RunAuthoredPatchDefinitions._valid_heirloom(authored_hem),
		"authored Shared Hem record passes the canonical P12 validation")
	_check(str(authored_hem.get("slot", "")) == "ARM"
		and int(authored_hem.get("shop_price_gold", -1)) == 100,
		"authored Shared Hem is the canonical 100-gold ARM power")
	if authored_hem.is_empty():
		return

	# The seeded P12 candidate fixture: every authored priced patch plus the
	# canonical Shared Hem and Needle Echo (no data change).
	var hem_candidates: Array = authored_patches.duplicate(true)
	hem_candidates.append({"id": "shared_hem",
		"price": int(required["shop_price_gold"])})
	hem_candidates.append({"id": "needle_echo", "price": 100})
	var hem_seed := -1
	var hem_stock := {}
	for seed_value in range(1, 300):
		var unlocked_rng := RandomNumberGenerator.new()
		unlocked_rng.seed = seed_value
		var unlocked := RunShopStockOffers.generate_peddler_stock(unlocked_rng,
			PARTY, authored_cards, hem_candidates, [], true)
		_check(unlocked.ok and unlocked.patches.size() == 1
			and not str(unlocked.patches[0].id).is_empty(),
			"unlocked seeded stock keeps one valid patch slot")
		var locked_rng := RandomNumberGenerator.new()
		locked_rng.seed = seed_value
		var locked := RunShopStockOffers.generate_peddler_stock(locked_rng,
			PARTY, authored_cards, hem_candidates, [])
		_check(locked.ok and str(locked.patches[0].id) != "shared_hem"
			and str(locked.patches[0].id) != "needle_echo",
			"default locked stock offers neither P12 patch")
		if hem_seed < 0 and str(unlocked.patches[0].id) == "shared_hem":
			hem_seed = seed_value
			hem_stock = unlocked
	_check(hem_seed > 0, "a deterministic genuine seed draws the authored Shared Hem")
	if hem_stock.is_empty():
		return
	_check(int(hem_stock.patches[0].price) == 100,
		"the genuine drawn Hem is quoted at its authored 100 gold")

	# --- genuine mounted visit: truthful row, price, preview and purchase ---
	var hem_visit := _party_visit("peddler_shared_hem", PARTY, DECK, hem_stock)
	_check(hem_visit.is_valid() and hem_visit.is_open(),
		"the genuine unlocked Hem stock opens a real Peddler visit")
	if not hem_visit.is_open():
		return
	var hem_before := hem_visit.read_state()
	await _bind(hem_visit)
	var hem_offer: Dictionary = hem_before["stock"]["trinkets"][0]
	_check(str(hem_offer["id"]) == "shared_hem" and int(hem_offer["price"]) == 100
		and int(hem_offer["price"]) == int(authored_hem["shop_price_gold"]),
		"bound Hem offer is the canonical 100-gold ARM ID")
	var hem_rows: Array = panel.patch_button.text.split("\n")
	_check(hem_rows.size() == 2 and hem_rows[0] == "4  ·  Shared Hem  ·  100 gold",
		"Hem ticket keeps its exact source-quoted 100-gold price and authored name")
	_check(hem_rows[1].begins_with("ARM  ·  ")
		and (hem_rows[1] == "ARM  ·  " + LivePeddlerPanel.SHARED_HEM_SHORT
			or (hem_rows[1].ends_with(LivePeddlerPanel.ELLIPSIS)
				and LivePeddlerPanel.SHARED_HEM_SHORT.begins_with(
					hem_rows[1].trim_prefix("ARM  ·  ").trim_suffix(LivePeddlerPanel.ELLIPSIS).strip_edges()))),
		"Hem ticket states the authored ARM slot and truthful condensed power")
	_check(_fits(panel.patch_button), "Hem ticket fits its actual sewn button")
	var hem_details: Dictionary = panel._patch_details()
	_check(not hem_details.is_empty() and str(hem_details["slot"]) == "ARM"
		and str(hem_details["short"]) == LivePeddlerPanel.SHARED_HEM_SHORT
		and str(hem_details["full"]) == LivePeddlerPanel.SHARED_HEM_FULL,
		"the Peddler projection recognizes the canonically verified Hem")
	_check(LivePeddlerPanel.SHARED_HEM_FULL.contains("different living hero")
		and LivePeddlerPanel.SHARED_HEM_FULL.contains("actually gains Block")
		and LivePeddlerPanel.SHARED_HEM_FULL.contains("living, untorn wearer")
		and LivePeddlerPanel.SHARED_HEM_FULL.contains("+1 Block")
		and LivePeddlerPanel.SHARED_HEM_FULL.contains("Once per turn"),
		"the full description states every authored Hem condition truthfully")
	_check(bool(authored_hem.get("source_hero_must_differ_from_wearer", false))
		and bool(authored_hem.get("source_hero_must_be_living", false))
		and bool(authored_hem.get("requires_actual_block_gain", false))
		and bool(authored_hem.get("wearer_must_be_living", false))
		and bool(authored_hem.get("wearer_must_be_untorn", false))
		and int(authored_hem.get("block", 0)) == 1
		and int(authored_hem.get("uses_per_turn", 0)) == 1,
		"the authored record really carries the described conditions")
	var hem_tooltip := panel.patch_button.tooltip_text
	_check(hem_tooltip.contains("shared_hem") and hem_tooltip.contains("ARM")
		and hem_tooltip.contains("100 gold")
		and hem_tooltip.contains(LivePeddlerPanel.SHARED_HEM_FULL)
		and hem_tooltip.contains(LivePeddlerPanel.PATCH_TORN_WARNING),
		"Hem tooltip carries the complete truthful rule, slot, price and torn warning")

	# Hover preview pays nothing and mutates nothing.
	await _move_pointer(panel.patch_button.get_global_rect().get_center())
	var hem_hover := panel.status_label.text
	var hem_expected := "ARM  ·  Shared Hem  ·  shared_hem  ·  " \
		+ LivePeddlerPanel.SHARED_HEM_SHORT
	_check(hem_hover == hem_expected or hem_hover == panel._clamp_status(hem_expected),
		"Hem hover shows exactly the truthful slot/name/ID/power line")
	_check(_status_fits(), "Hem hover preview fits the status band")
	_check(intents.is_empty() and hem_visit.read_state() == hem_before
		and hem_visit.is_open(),
		"Hem hover mutates no source, spends nothing and keeps the visit open")
	# Keyboard focus repeats the same truthful preview.
	await _hover_none()
	panel.patch_button.grab_focus()
	await _frames()
	_check(panel.patch_button.has_focus() and panel.status_label.text == hem_hover,
		"Hem keyboard focus repeats the same truthful preview")
	_check(intents.is_empty() and hem_visit.read_state() == hem_before,
		"Hem focus spends nothing and emits no intent")

	# The withheld HEAD power is never described: a relabelled row fails closed.
	var authentic_source := panel._source.duplicate(true)
	panel._source["stock"]["trinkets"][0]["id"] = "needle_echo"
	_check(panel._patch_details().is_empty()
		and panel._patch_preview().contains(LivePeddlerPanel.PATCH_DETAILS_UNAVAILABLE),
		"stale relabelled offer cannot borrow Needle Echo details")
	panel._source = authentic_source
	_check(panel._source_current() and hem_visit.read_state() == hem_before,
		"restoring the genuine Hem row restores its bound source untouched")
	# Contradictory/missing/unreadable P12 catalog material fails closed too.
	_check(panel._verified_shared_hem("needle_echo").is_empty()
		and panel._verified_shared_hem("stitched_badge").is_empty(),
		"the Hem-only authentication seam refuses other IDs")
	_check(not panel._verified_shared_hem("shared_hem").is_empty()
		and not panel._verified_shared_hem("shared_hem", authored_heirloom).is_empty(),
		"the shipped and supplied genuine catalogs both verify the Hem")
	var forged_catalog: Array = (authored_heirloom as Array).duplicate(true)
	for record in forged_catalog:
		if typeof(record) == TYPE_DICTIONARY \
				and str(record.get("id", "")) == "shared_hem":
			record["block"] = 2
	_check(panel._verified_shared_hem("shared_hem", forged_catalog).is_empty(),
		"a contradictory authored field refuses any Hem description")
	var missing_catalog: Array = []
	for record in forged_catalog:
		if str(record.get("id", "")) != "shared_hem":
			missing_catalog.append(record)
	_check(panel._verified_shared_hem("shared_hem", missing_catalog).is_empty()
		and panel._verified_shared_hem("shared_hem", "not an array").is_empty(),
		"a missing Hem record and an unreadable P12 catalog fail closed")

	# One real submitted purchase settles once at 100 gold through the visit.
	await _act(panel.patch_button, true, KEY_SPACE)
	_check(intents.size() == 1, "the genuine Hem buy emits exactly one intent")
	if intents.size() == 1:
		_check(intents[0]["kind"] == "trinket" and intents[0]["id"] == "shared_hem"
			and intents[0]["node_id"] == hem_before["node_id"],
			"Hem intent is the source-bound trinket buy")
		var hem_receipt := Controller.settle(hem_visit, intents[0], hem_before)
		_check(hem_receipt.get("ok") == true and hem_receipt.get("price") == 100
				and hem_receipt["state"]["gold"] == GOLD - 100
				and hem_receipt["state"]["trinkets"] == ["shared_hem"],
				"real Hem purchase settles once at exactly 100 gold")
		_check(hem_visit.is_consumed()
				and not Controller.settle(hem_visit, intents[0], hem_before).get("ok", true),
				"consumed Hem visit refuses a replayed intent")

	# Leave stays free on a separately opened genuine Hem visit.
	var leave_visit := _party_visit("peddler_shared_hem_leave", PARTY, DECK, hem_stock)
	_check(leave_visit.is_open(), "a separately opened genuine Hem visit stays open")
	var leave_before := leave_visit.read_state()
	await _bind(leave_visit)
	_check(panel.leave_button.text == "0  ·  Leave  ·  FREE" and not panel.leave_button.disabled,
		"Leave remains free and 0-labeled beside the priced Hem")
	await _act(panel.leave_button, true, KEY_SPACE)
	_check(intents.size() == 1 and intents[0]["kind"] == "leave",
		"Leave emits exactly one leave intent")
	if intents.size() == 1:
		var leave_receipt := Controller.settle(leave_visit, intents[0], leave_before)
		_check(leave_receipt.get("ok") == true
				and leave_receipt.get("decision") == "leave"
				and leave_receipt["state"]["gold"] == GOLD
				and leave_receipt["state"]["trinkets"].is_empty(),
				"Leave on the Hem visit spends nothing and adds no patch")

## Completed-run P12 HEAD is not a placeholder: a seeded, genuine visit
## displays the authenticated confirmed-Pinned +1 rule and accepts both
## physical mouse and numeral-4 purchase actions, once only.
func _needle_echo_case() -> void:
	var required: Dictionary = RunAuthoredPatchDefinitions.HEIRLOOM_REQUIRED["needle_echo"]
	var records: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/patches/mpw_heirloom_patches.json"))
	var needle: Dictionary = {}
	if records is Array:
		for record in records:
			if record is Dictionary and record.get("id") == "needle_echo":
				needle = record
	_check(not needle.is_empty() and RunAuthoredPatchDefinitions._valid_heirloom(needle)
		and needle.get("slot") == "HEAD" and needle.get("shop_price_gold") == 100
		and needle.get("bonus_damage") == 1 and needle.get("uses_per_turn") == 1
		and needle.get("requires_confirmed_receipt") == true
		and needle.get("requires_pinned_enemy") == true,
		"authored Needle Echo requires confirmed Pinned contact for HEAD +1 once/turn")
	var candidates: Array = authored_patches.duplicate(true)
	for heirloom_id in ["needle_echo", "shared_hem"]:
		var spec: Dictionary = RunAuthoredPatchDefinitions.HEIRLOOM_REQUIRED[heirloom_id]
		candidates.append({"id": heirloom_id, "price": spec["shop_price_gold"]})
	var chosen := {}
	var chosen_seed := -1
	for value in range(1, 400):
		var probe := RandomNumberGenerator.new()
		probe.seed = value
		var stock := RunShopStockOffers.generate_peddler_stock(
			probe, PARTY, authored_cards, candidates, [], true)
		if stock.ok and stock.patches.size() == 1 and stock.patches[0].id == "needle_echo":
			chosen = stock
			chosen_seed = value
			break
	_check(chosen_seed > 0 and chosen.get("patches", []).size() == 1
		and int(chosen.get("patches", [{}])[0].get("price", -1)) == 100,
		"genuine seeded unlocked Peddler selects one canonical 100-gold Needle Echo")
	if chosen.is_empty():
		return
	var first := RandomNumberGenerator.new()
	first.seed = chosen_seed
	var second := RandomNumberGenerator.new()
	second.seed = chosen_seed
	var reversed := candidates.duplicate(true)
	reversed.reverse()
	_check(RunShopStockOffers.generate_peddler_stock(first, PARTY, authored_cards, candidates, [], true)
		== RunShopStockOffers.generate_peddler_stock(second, PARTY, authored_cards, reversed, [], true)
		and first.state == second.state,
		"Needle Echo seeded lottery ignores candidate order and preserves RNG stream")
	var broken: Array = (records as Array).duplicate(true)
	for record in broken:
		if record.get("id") == "needle_echo":
			record["bonus_damage"] = 2
	_check(not panel._verified_heirloom("needle_echo").is_empty()
		and not panel._verified_heirloom("needle_echo", records).is_empty()
		and panel._verified_heirloom("needle_echo", broken).is_empty()
		and panel._verified_heirloom("unverified_patch").is_empty(),
		"HEAD details require an exact authenticated Heirloom record")
	for keyboard in [false, true]:
		var visit := _party_visit("needle_echo_" + str(keyboard), PARTY, DECK, chosen)
		var before := visit.read_state()
		_check(visit.is_open() and before.stock.trinkets[0].id == "needle_echo"
			and before.stock.trinkets[0].price == 100 and before.state.gold == GOLD,
			"real open Needle Echo visit has payable HEAD offer and funded wallet")
		await _bind(visit)
		var ticket: Array = panel.patch_button.text.split("\n")
		var details := panel._patch_details()
		_check(ticket.size() == 2 and ticket[0] == "4  ·  Needle Echo  ·  100 gold"
			and ticket[1].begins_with("HEAD  ·  ") and _fits(panel.patch_button)
			and not details.is_empty() and details.slot == "HEAD"
			and details.short == LivePeddlerPanel.NEEDLE_ECHO_SHORT
			and details.full == LivePeddlerPanel.NEEDLE_ECHO_FULL,
			"mounted key-4 ticket fits and explains authentic HEAD triggered +1 damage")
		_check(panel.patch_button.tooltip_text.contains("needle_echo")
			and panel.patch_button.tooltip_text.contains("HEAD")
			and panel.patch_button.tooltip_text.contains("100 gold")
			and panel.patch_button.tooltip_text.contains(LivePeddlerPanel.NEEDLE_ECHO_FULL)
			and panel.patch_button.tooltip_text.contains(LivePeddlerPanel.PATCH_TORN_WARNING)
			and not panel.patch_button.tooltip_text.contains(LivePeddlerPanel.PATCH_DETAILS_UNAVAILABLE),
			"mounted Needle Echo tooltip names precise trigger, torn suppression and quote")
		await _move_pointer(panel.patch_button.get_global_rect().get_center())
		_check(panel.status_label.text.contains("HEAD") and _status_fits()
			and visit.read_state() == before and intents.is_empty(),
			"Needle Echo mouse hover gives no-cost, non-mutating HEAD preview")
		await _hover_none()
		panel.patch_button.grab_focus()
		await _frames()
		_check(panel.patch_button.has_focus()
			and panel.status_label.text.contains("Needle Echo")
			and visit.read_state() == before and intents.is_empty(),
			"Needle Echo keyboard focus previews without spend or intent")
		if keyboard:
			_check(not await _push_shortcut(KEY_4), "number 4 is consumed by mounted Peddler")
		else:
			await _act(panel.patch_button, false)
		_check(intents.size() == 1 and intents[0].get("id") == "needle_echo"
			and intents[0].get("kind") == "trinket",
			"physical Needle Echo buy emits one source-bound patch purchase")
		if intents.size() != 1:
			continue
		var paid := Controller.settle(visit, intents[0], before)
		var accepted := visit.read_state()
		_check(paid.ok and paid.price == 100
			and accepted.state.gold == GOLD - 100
			and accepted.state.trinkets == ["needle_echo"]
			and accepted.state.deck == DECK and accepted.status == "used",
			"genuine Needle Echo purchase debits 100 once, owns HEAD and preserves deck")
		_check(not Controller.settle(visit, intents[0], before).get("ok")
			and visit.read_state() == accepted,
			"duplicate/stale Needle Echo purchase preserves accepted wallet and inventory")
	var broke := _party_visit("needle_echo_unfunded", PARTY, DECK, chosen, 99)
	var broke_before := broke.read_state()
	await _bind(broke)
	_check(broke.is_open() and panel.patch_button.disabled
		and panel.patch_button.text.contains("short 1"),
		"unaffordable Needle Echo stays visible but cannot be bought")
	await _push_shortcut(KEY_4)
	_check(intents.is_empty() and broke.read_state() == broke_before,
		"unfunded key-4 attempt leaves gold, deck and inventory untouched")
	await _act(panel.leave_button, false)
	_check(intents.size() == 1 and intents[0].kind == "leave",
		"Needle Echo visit still provides a free physical Leave")
	if intents.size() == 1:
		var left := Controller.settle(broke, intents[0], broke_before)
		_check(left.ok and left.state.gold == 99 and left.state.trinkets.is_empty()
			and left.state.deck == DECK,
			"leaving a Needle Echo visit preserves wallet, owned patches and deck")


## VIS-B ambient art: the authored sewn panel's decorative market image alone
## breathes/drifts on a slow deterministic cycle, while every priced ticket,
## status label, sewn outline, route-added wearer selector, quote, receipt
## and RNG stay exactly unchanged. Every stop path (reduced motion via the
## project setting or the nullable override, absent art, hide/show, close,
## rebind, a stale or consumed visit, exit-tree) restores the exact static
## baseline. Equality checks follow only synchronous operations so headless
## frame deltas cannot disturb them; the cycle math is asserted through the
## panel's own pure transform function.
func _ambient_art_cases() -> void:
	var baseline := {"scale": 1.0, "offset": Vector2.ZERO}
	var visit := _visit(GOLD, "peddler_ambient_motion")
	var before := visit.read_state()
	_check(visit.is_open(), "ambient fixture is a genuine open visit")
	intents.clear()
	panel.bind(visit)
	var art_host := panel.get_node_or_null("PanelArt") as Panel
	var drift := panel.get_node_or_null("PanelArt/PanelArtDrift") as Panel
	if art_host == null or drift == null:
		# A checkout without the authored image still shows the static
		# readable panel; the motion simply has nothing to move.
		panel.advance_art_motion(2.0)
		_check(panel.art_motion_transform() == baseline
				and panel.title_label.text.contains("PEDDLER"),
				"absent art keeps the exact static readable baseline panel")
		return
	_check(panel.art_motion_transform() == baseline,
			"freshly bound mounted visit starts the art at the exact static baseline")
	_check(drift.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and drift.focus_mode == Control.FOCUS_NONE
			and art_host.clip_contents and drift.get_index() == 0
			and art_host.get_index() < panel.card_buttons[0].get_index(),
			"the decorative image is input-inert, clipped and under the fixed outline and tickets")
	var static_face := art_host.get_theme_stylebox("panel") as StyleBoxTexture
	_check(static_face != null and static_face.texture != null
			and static_face.texture.resource_path == LivePeddlerPanel.PANEL_ART,
			"the static authored market copy beneath the drift stays the readable fallback")
	# The route's own wearer selector and moved patch row, exactly as app.gd
	# mounts them on this screen: the selector must stay a real fixed target.
	var wearer := OptionButton.new()
	wearer.position = Vector2(39, 440)
	wearer.size = Vector2(240, 44)
	for hero in PARTY:
		wearer.add_item(str(hero).capitalize())
	panel.add_child(wearer)
	panel.patch_button.position = Vector2(295, 406)
	panel.patch_button.custom_minimum_size = Vector2(566, 78)
	panel.patch_button.size = Vector2(566, 78)
	await _frames()
	var art_rect := art_host.get_global_rect()
	var drift_base := drift.position
	var panel_rect := panel.get_global_rect()
	var wearer_rect := wearer.get_global_rect()
	var fabric := panel.get_node_or_null("FabricBacking") as Panel
	var action_rects: Array[Rect2] = []
	var quotes: Array[String] = []
	for button in panel.card_buttons + [panel.patch_button, panel.leave_button]:
		action_rects.append(button.get_global_rect())
		quotes.append(button.text)
	var wallet_text := panel.wallet_label.text
	var run_state := rng.state
	panel.advance_art_motion(2.0)
	var moved := panel.art_motion_transform()
	var moved_offset: Vector2 = moved["offset"]
	_check(float(moved["scale"]) > 1.0
			and float(moved["scale"]) - 1.0 <= LivePeddlerPanel.ART_MOTION_BREATH
			and moved_offset != Vector2.ZERO
			and moved_offset.length() <= LivePeddlerPanel.ART_MOTION_PAN.length(),
			"elapsed presentation time moves only the restrained decorative transform")
	_check(drift.position != drift_base and drift.scale.x > 1.0,
			"the mounted decorative image itself visibly breathes and drifts")
	_check(drift.get_global_rect().encloses(panel.get_global_rect()),
			"the breathing image still covers the whole sewn panel with no crop gaps")
	var stationary := true
	var index := 0
	for button in panel.card_buttons + [panel.patch_button, panel.leave_button]:
		if button.get_global_rect() != action_rects[index] or button.text != quotes[index]:
			stationary = false
		index += 1
	_check(stationary and panel.get_global_rect() == panel_rect
			and wearer.get_global_rect() == wearer_rect
			and art_host.get_global_rect() == art_rect,
			"buttons, quotes, panel, sewn outline and route wearer selector stay fixed under motion")
	_check(fabric != null and fabric.get_global_rect() == panel.get_global_rect(),
			"the opaque static fabric backing stays fixed while the art moves")
	_check(panel.wallet_label.text == wallet_text
			and visit.read_state() == before and intents.is_empty()
			and rng.state == run_state,
			"ambient motion consumes no quote, wallet, ledger, intent or seeded RNG")
	# The unchanged source-bound one-shot signal path still works under motion.
	panel.card_buttons[0].grab_focus()
	await _frames()
	var motion_counts := _press_totals()
	_check(not await _push_shortcut(KEY_1) and _pressed_only("card0", motion_counts)
			and intents.size() == 1,
			"the 1 shortcut still follows the unchanged source-bound path under motion")
	if intents.size() == 1:
		var receipt := Controller.settle(visit, intents[0], before)
		_check(receipt.get("ok") == true
				and receipt["state"]["gold"] == GOLD - int(before["stock"]["cards"][0]["price"])
				and receipt["state"]["deck"] == DECK + [before["stock"]["cards"][0]["id"]],
				"one genuine purchase settles at its authored quote while the art animates")
	wearer.queue_free()
	await process_frame

	# --- deterministic cycle: exact transform values at half and full periods ---
	var cycled := _visit(GOLD, "peddler_ambient_cycle")
	intents.clear()
	panel.bind(cycled)
	var half := LivePeddlerPanel.ART_MOTION_PERIOD * 0.5
	panel.advance_art_motion(half)
	var at_half := panel.art_motion_transform()
	var half_offset: Vector2 = at_half["offset"]
	_check(absf(float(at_half["scale"])
				- (1.0 + LivePeddlerPanel.ART_MOTION_BREATH)) < 0.001,
			"half the deterministic cycle reaches the full gentle 1% breath")
	_check(half_offset.length() < 0.25,
			"the drift is back at rest at the half cycle")
	panel.advance_art_motion(half)
	_check(panel.art_motion_transform() == baseline,
			"one full deterministic period returns the art to the exact static baseline")
	_check(LivePeddlerPanel.art_motion_transform_at(0.0) == baseline
			and LivePeddlerPanel.art_motion_transform_at(
					LivePeddlerPanel.ART_MOTION_PERIOD) == baseline
			and LivePeddlerPanel.art_motion_transform_at(2.5) == LivePeddlerPanel.art_motion_transform_at(
					2.5 + LivePeddlerPanel.ART_MOTION_PERIOD * 3.0),
			"the pure presentation transform is deterministic and periodic")

	# --- ProjectSettings accessibility/reduced_motion (default false), restored ---
	var prior: Variant = ProjectSettings.get_setting(
			"accessibility/reduced_motion", false)
	ProjectSettings.set_setting("accessibility/reduced_motion", true)
	panel.advance_art_motion(5.0)
	_check(panel.art_motion_transform() == baseline,
			"accessibility/reduced_motion keeps the authored art exactly static")
	_check(panel.is_visible_in_tree() and not panel.card_buttons[0].disabled
			and not panel.patch_button.disabled and not panel.leave_button.disabled
			and panel.title_label.text.contains("PEDDLER"),
			"reduced motion still mounts the readable actionable panel")
	ProjectSettings.set_setting("accessibility/reduced_motion", prior)
	_check(not panel._reduced_motion_active(),
			"prior reduced-motion setting restored afterward")

	# --- nullable explicit override for focused tests ---
	panel.set_reduced_motion_override(true)
	_check(panel.art_motion_transform() == baseline,
			"explicit reduced-motion override restores the exact static baseline")
	panel.advance_art_motion(4.0)
	_check(panel.art_motion_transform() == baseline,
			"no motion accumulates while the explicit override is true")
	panel.set_reduced_motion_override(null)
	_check(panel.art_motion_transform() == baseline,
			"lifted override restarts only from the static baseline")
	panel.advance_art_motion(2.0)
	_check(panel.art_motion_transform() != baseline,
			"motion resumes only through fresh presentation time after the override lifts")

	# --- absent art keeps the static readable fallback without errors ---
	var saved_drift: Panel = panel._art_drift
	panel._art_drift = null
	panel.advance_art_motion(5.0)
	_check(panel.art_motion_transform() == baseline,
			"absent art keeps the exact static baseline transform without errors")
	_check(panel.is_visible_in_tree() and panel.title_label.text.contains("PEDDLER")
			and panel.wallet_label.text.contains("%d gold" % GOLD)
			and not panel.leave_button.disabled and not panel.card_buttons[0].disabled,
			"absent art retains the same readable actionable static panel")
	panel._art_drift = saved_drift
	_check(panel.art_motion_transform() != baseline,
			"restoring the authored art resumes the honest mounted decoration")

	# --- hide stops and restores; show resumes only from the baseline ---
	panel.advance_art_motion(3.0)
	_check(panel.art_motion_transform() != baseline,
			"art is genuinely moving before hide")
	panel.hide()
	_check(panel.art_motion_transform() == baseline,
			"a hidden panel restores the static baseline")
	panel.advance_art_motion(3.0)
	_check(panel.art_motion_transform() == baseline,
			"hidden panels accumulate no motion")
	panel.show()
	_check(panel.art_motion_transform() == baseline,
			"the shown panel resumes only from the static baseline")
	await _frames()

	# --- close() stops and restores; rebinding restarts from the baseline ---
	var closing := _visit(GOLD, "peddler_ambient_close")
	await _bind(closing)
	panel.advance_art_motion(6.0)
	_check(panel.art_motion_transform() != baseline,
			"art is genuinely moving before close")
	panel.close()
	_check(panel.art_motion_transform() == baseline
			and not panel.is_visible_in_tree() and panel.leave_button.disabled,
			"close() stops and restores the exact static transform on the closed panel")
	panel.advance_art_motion(7.0)
	_check(panel.art_motion_transform() == baseline,
			"no old motion resumes on the closed panel")

	# --- rebinding another authentic visit restarts from the baseline ---
	var rebound := _party_visit("peddler_ambient_rebind", PARTY_V3, DECK_V3,
			_seeded_stock(PARTY_V3, V3_SEED))
	intents.clear()
	panel.bind(rebound)
	_check(panel.is_visible_in_tree() and not panel.leave_button.disabled
			and panel.art_motion_transform() == baseline,
			"rebinding another authentic visit restarts from the exact static baseline")
	panel.advance_art_motion(2.0)
	_check(panel.art_motion_transform() != baseline,
			"the rebound visit's art moves through fresh presentation time")

	# --- a stale bound visit stops the decoration ---
	var stale := _visit(GOLD, "peddler_ambient_stale")
	await _bind(stale)
	panel.advance_art_motion(2.0)
	_check(panel.art_motion_transform() != baseline,
			"art moves before the bound source drifts")
	stale._purchases._state["gold"] += 1
	await _frames()
	_check(panel.art_motion_transform() == baseline,
			"a stale bound visit stops and restores the static baseline")
	stale._purchases._state["gold"] -= 1

	# --- a consumed bound visit stops the decoration ---
	var used := _visit(GOLD, "peddler_ambient_used")
	var used_open := used.read_state()
	await _bind(used)
	panel.advance_art_motion(2.0)
	_check(panel.art_motion_transform() != baseline,
			"art moves before the visit is consumed")
	_check(used.leave(used_open["node_id"], used_open["state"],
			used_open["stock"]).get("ok") == true,
			"ambient fixture visit is really consumed")
	await _frames()
	_check(panel.art_motion_transform() == baseline,
			"a consumed bound visit stops and restores the static baseline")

	# --- leaving the tree restores the decorative image's exact baseline ---
	var detached := _visit(GOLD, "peddler_ambient_exit_tree")
	await _bind(detached)
	panel.advance_art_motion(2.0)
	_check(panel.art_motion_transform() != baseline,
			"art moves before the panel leaves the tree")
	var drift_node: Panel = panel._art_drift
	host.remove_child(panel)
	await _frames()
	_check(drift_node.position == panel._art_drift_base
			and drift_node.scale == Vector2.ONE
			and drift_node.pivot_offset == drift_node.size * 0.5,
			"exit-tree restores the decorative image's exact baseline position, scale and pivot")
	host.add_child(panel)
	_check(panel.art_motion_transform() == baseline,
			"a remounted panel resumes only from the static baseline")
