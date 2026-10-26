class_name LivePeddlerPanel
extends Control
## V3-3 Peddler presentation and detached intents only.
##
## One genuine OPEN RunPeddlerVisit renders as three owner-labelled, priced card
## buys (one per party hero), one priced patch buy and the free Leave. The view
## never buys, leaves, debits gold, appends a card or patch, samples stock or
## advances the run RNG: a press publishes exactly one deeply detached intent
##
##   {node_id, kind, id (buys only), expected_state, expected_stock}
##
## whose kind is "card", "trinket" or "leave". An external controller must
## re-read the visit and pass those values unchanged to
## RunPeddlerVisit.choose_purchase()/leave(), which stay the single purchase
## and Leave authority. The live Shop route mounts this view through app.gd.
##
## Read-only ability preview: hovering or focusing one offered card repeats its
## authored energy cost and CardShortRules sentence in the existing status band
## and leaves the complete sentences in that card Button's tooltip. The preview
## is resolved from the offered ID in the same authored catalogs the seeded
## stock generator validates against, only while the definition's owner matches
## the offer; anything unresolvable reads "Card details unavailable" instead of
## a guessed number. It never changes a quoted price, the five actions, the
## purchase intent or the visit state.
signal intent_requested(intent: Dictionary)

const PANEL_ART := "res://assets/paper/ui/reward_panel.png"
const BUTTON_ART := "res://assets/paper/ui/reward_button.png"
const THEME_PATH := "res://assets/fonts/patchwork_theme.tres"
const TITLE_TEXT := "PEDDLER  ·  one purchase or Leave"
const STATUS_OPEN := "Choose one offer, or Leave.  ·  1-3 cards · 4 patch · 0 Leave"
const STATUS_CLOSED := "No open Peddler visit. No offer can be submitted."
const DETAILS_UNAVAILABLE := "Card details unavailable"
const ELLIPSIS := "..."
const WALLET_CLOSED := "Wallet unavailable"
const LEAVE_TEXT := "Leave  ·  FREE"
const CARD_KIND := "card"
const PATCH_KIND := "trinket"
const LEAVE_KIND := "leave"
const CARD_COUNT := 3
const PANEL_SIZE := Vector2(900, 600)
## The status band's designed inner width at 1280x720: the compact single-line
## preview is kept inside it at the shipped 18px face, whatever a Label's own
## minimum-size growth would allow, so a long line can never spill over the
## sewn panel.
const STATUS_WIDTH := 822.0
const CREAM := Color("#f3e6cf")
const GOLD := Color("#e9c47d")
const THREAD := Color("#b9a58d")
const PLUM := Color("#37293f")
const TEAL := Color("#214b50")
const OXBLOOD := Color("#713544")
const INK := Color("#191b2a")
const DIM := Color("#b6a9a2")


## Input-transparent running stitch over the sewn paper surface.
class SewnBorder extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(queue_redraw)

	func _draw() -> void:
		if size.x < 24 or size.y < 24:
			return
		var r := Rect2(Vector2(9, 8), size - Vector2(18, 16))
		for y in [r.position.y, r.end.y]:
			draw_dashed_line(Vector2(r.position.x, y), Vector2(r.end.x, y), THREAD, 1.5, 8.0)
		for x in [r.position.x, r.end.x]:
			draw_dashed_line(Vector2(x, r.position.y), Vector2(x, r.end.y), THREAD, 1.5, 8.0)


var title_label: Label
var wallet_label: Label
var status_label: Label
var card_buttons: Array[Button] = []
var patch_button: Button
var leave_button: Button

var _visit: RunPeddlerVisit
var _source: Dictionary = {}
var _epoch := 0
var _submitted := false
var _pending_intent: Dictionary = {}
var _connections: Dictionary = {} # Only view-owned Button.pressed -> Callable.
var _preview_index := -1 # Card row whose read-only preview fills the status band.
var _hover_index := -1 # Card row under the pointer; -1 when no card is hovered.
var _catalogs: Array = [] # Read-only authored catalogs for the preview, built once.


func _ready() -> void:
	size = PANEL_SIZE
	custom_minimum_size = PANEL_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	var master := _load_theme()
	if master != null:
		theme = master
	var backing := Panel.new()
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backing)
	backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backing.add_theme_stylebox_override("panel", _panel_style())
	backing.add_child(SewnBorder.new())
	title_label = _label(TITLE_TEXT, Vector2(36, 20), Vector2(828, 44), 29, GOLD)
	wallet_label = _label("", Vector2(39, 68), Vector2(822, 32), 22, CREAM)
	status_label = _label("", Vector2(39, 102), Vector2(822, 30), 18, CREAM)
	for i in range(CARD_COUNT):
		card_buttons.append(_button("", Vector2(39, 142 + i * 88), Vector2(822, 78), OXBLOOD, 20))
	patch_button = _button("", Vector2(39, 406), Vector2(822, 78), TEAL, 20)
	leave_button = _button(LEAVE_TEXT, Vector2(39, 498), Vector2(822, 58), TEAL, 24)
	_wire_previews()
	_refresh()
	_focus_initial()


func _input(event: InputEvent) -> void:
	if not _active():
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	# is_ancestor_of() needs a real node: with nothing focused (or focus on a
	# control outside this panel) no shortcut belongs to the Peddler.
	if focus_owner == null or (focus_owner != self and not is_ancestor_of(focus_owner)):
		return
	var key_event := event as InputEventKey
	if key_event == null or not key_event.is_pressed() or key_event.is_echo():
		return
	if key_event.shift_pressed or key_event.alt_pressed or key_event.ctrl_pressed or key_event.meta_pressed:
		return

	var button: Button = null
	match key_event.keycode:
		KEY_1, KEY_KP_1:
			button = card_buttons[0]
		KEY_2, KEY_KP_2:
			button = card_buttons[1]
		KEY_3, KEY_KP_3:
			button = card_buttons[2]
		KEY_4, KEY_KP_4:
			button = patch_button
		KEY_0, KEY_KP_0:
			button = leave_button

	if button != null:
		get_viewport().set_input_as_handled()
		button.pressed.emit()


## A detached copy of the master Theme so the panel never mutates the project
## resource; a missing theme leaves Godot's default font and the per-control
## overrides below, which stay readable.
static func _load_theme() -> Theme:
	if not ResourceLoader.exists(THEME_PATH, "Theme"):
		return null
	var master := load(THEME_PATH) as Theme
	if master == null:
		return null
	return master.duplicate(true) as Theme


func _panel_style() -> StyleBox:
	if ResourceLoader.exists(PANEL_ART, "Texture2D"):
		var texture := ResourceLoader.load(PANEL_ART) as Texture2D
		if texture != null:
			var style := StyleBoxTexture.new()
			style.texture = texture
			style.modulate_color = Color("#635264")
			style.set_texture_margin_all(24)
			return style
	return _style(PLUM, THREAD, 5)


func _style(fill: Color, edge: Color, width: int = 3) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(width)
	style.set_corner_radius_all(7)
	style.set_content_margin_all(8)
	return style


## The shipped sewn button art as a gold focus ring, with the flat ring as a
## fallback when that texture is unavailable.
func _focus_style() -> StyleBox:
	if ResourceLoader.exists(BUTTON_ART, "Texture2D"):
		var texture := ResourceLoader.load(BUTTON_ART) as Texture2D
		if texture != null:
			var sewn := StyleBoxTexture.new()
			sewn.texture = texture
			sewn.modulate_color = GOLD
			sewn.draw_center = false
			for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
				sewn.set_texture_margin(side, 8)
				sewn.set_expand_margin(side, 3)
			return sewn
	var ring := _style(Color.TRANSPARENT, GOLD, 4)
	ring.draw_center = false
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		ring.set_expand_margin(side, 3)
	return ring


func _label(value: String, at: Vector2, extent: Vector2, font_size: int, ink: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.position = at
	label.size = extent
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", ink)
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", 2)
	add_child(label)
	return label


func _button(value: String, at: Vector2, extent: Vector2, fill: Color, font_size: int) -> Button:
	var button := Button.new()
	button.text = value
	button.position = at
	button.size = extent
	button.custom_minimum_size = extent
	button.focus_mode = Control.FOCUS_ALL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", font_size)
	for state in ["font_color", "font_hover_color", "font_pressed_color",
			"font_hover_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, CREAM)
	button.add_theme_color_override("font_disabled_color", DIM)
	button.add_theme_stylebox_override("normal", _style(fill, INK))
	button.add_theme_stylebox_override("hover", _style(fill.lightened(0.13), GOLD))
	button.add_theme_stylebox_override("pressed", _style(fill.darkened(0.12), GOLD))
	button.add_theme_stylebox_override("disabled", _style(PLUM, DIM))
	button.add_theme_stylebox_override("focus", _focus_style())
	add_child(button)
	button.add_child(SewnBorder.new())
	return button


## Only a genuine valid OPEN Peddler projection may be quoted. A rejected,
## USED or LEFT visit, a malformed stock/state or a shape this panel cannot
## label binds closed with no payable action.
func bind(visit: RunPeddlerVisit) -> void:
	_epoch += 1
	_retire_callbacks()
	_visit = null
	_source = {}
	_submitted = false
	_pending_intent.clear()
	if visit != null and visit.is_valid() and visit.is_open():
		var state: Dictionary = visit.read_state()
		if _valid_open_state(state):
			_visit = visit
			_source = state.duplicate(true)
	if is_node_ready():
		visible = true
		_refresh()
		_focus_initial()


func close() -> void:
	bind(null)
	hide()


## The authentic read_state() shape this view can present: three distinct party
## heroes, one offered card per hero at its authored owner and whole gold price,
## one patch at its authored whole gold price, and the current wallet.
static func _valid_open_state(state: Variant) -> bool:
	if typeof(state) != TYPE_DICTIONARY:
		return false
	var projection: Dictionary = state
	if projection.get("ok") != true or projection.get("status") != "open":
		return false
	var node_id: Variant = projection.get("node_id")
	if typeof(node_id) != TYPE_STRING or str(node_id).strip_edges().is_empty() \
			or str(node_id) != str(node_id).strip_edges():
		return false
	var ledger: Variant = projection.get("state")
	var stock: Variant = projection.get("stock")
	if typeof(ledger) != TYPE_DICTIONARY or typeof(stock) != TYPE_DICTIONARY:
		return false
	var party: Variant = ledger.get("party_ids")
	if typeof(party) != TYPE_ARRAY \
			or _distinct_ids(party) != CARD_COUNT:
		return false
	var party_set := {}
	for hero in party:
		party_set[hero] = true
	for field in ["deck", "trinkets"]:
		var entries: Variant = ledger.get(field)
		if typeof(entries) != TYPE_ARRAY:
			return false
		for entry in entries:
			if typeof(entry) != TYPE_STRING or str(entry).strip_edges().is_empty():
				return false
	if typeof(ledger.get("gold")) != TYPE_INT or int(ledger["gold"]) < 0:
		return false
	var cards: Variant = stock.get("cards")
	var patches: Variant = stock.get("trinkets")
	if typeof(cards) != TYPE_ARRAY or cards.size() != CARD_COUNT \
			or typeof(patches) != TYPE_ARRAY or patches.size() != 1:
		return false
	var card_ids := {}
	var owners := {}
	for record in cards:
		if typeof(record) != TYPE_DICTIONARY:
			return false
		var offer: Dictionary = record
		var offer_id: Variant = offer.get("id")
		var owner: Variant = offer.get("owner")
		if typeof(offer_id) != TYPE_STRING or str(offer_id).strip_edges().is_empty() \
				or card_ids.has(offer_id):
			return false
		if typeof(owner) != TYPE_STRING or not party_set.has(owner) or owners.has(owner):
			return false
		if typeof(offer.get("price")) != TYPE_INT or int(offer["price"]) < 0 \
				or typeof(offer.get("sold")) != TYPE_BOOL:
			return false
		card_ids[offer_id] = true
		owners[owner] = true
	var patch: Variant = patches[0]
	if typeof(patch) != TYPE_DICTIONARY:
		return false
	var priced_patch: Dictionary = patch
	if typeof(priced_patch.get("id")) != TYPE_STRING \
			or str(priced_patch["id"]).strip_edges().is_empty() \
			or typeof(priced_patch.get("price")) != TYPE_INT \
			or int(priced_patch["price"]) < 0 \
			or typeof(priced_patch.get("sold")) != TYPE_BOOL:
		return false
	return true


## Distinct, non-blank string entries, or -1 when one is malformed or repeated:
## a duplicated or blank hero can never be labelled.
static func _distinct_ids(entries: Array) -> int:
	var seen := {}
	for entry in entries:
		if typeof(entry) != TYPE_STRING or str(entry).strip_edges().is_empty() or seen.has(entry):
			return -1
		seen[entry] = true
	return seen.size()


func _source_current() -> bool:
	if _visit == null or _submitted or not _visit.is_valid() or not _visit.is_open():
		return false
	if _source.is_empty() or not _valid_open_state(_source):
		return false
	return _visit.read_state() == _source


func _active() -> bool:
	return is_inside_tree() and is_visible_in_tree() and _source_current()


## "warden_strike" -> "Warden Strike": the authored ID stays readable on screen
## even when no display-name catalog is consulted.
static func readable_id(item_id: String) -> String:
	return item_id.replace("_", " ").capitalize()


func _gold() -> int:
	return int(_source["state"]["gold"])


func _offer(index: int) -> Dictionary:
	return _source["stock"]["cards"][index]


func _patch_offer() -> Dictionary:
	return _source["stock"]["trinkets"][0]


func _caption(prefix: String, item_id: String, price: int, sold: bool) -> String:
	var line := "%s  ·  %s  ·  %d gold" % [
			prefix, readable_id(item_id), price]
	if sold:
		return line + "  ·  SOLD"
	if _gold() < price:
		return line + "  ·  short %d" % (price - _gold())
	return line


## Preserve the entire source-quoted price and state on line one. Only the
## catalog display name and the catalog effect may be shortened. Both lines are
## measured against the real Button font rather than left to autowrap/clipping.
func _card_caption(index: int) -> String:
	var offer := _offer(index)
	var details := _card_details(index)
	var button := card_buttons[index]
	var font := button.get_theme_font("font")
	var px := button.get_theme_font_size("font_size")
	var width := maxf(0.0, button.size.x - 32.0)
	var prefix := "%s  ·  " % str(offer["owner"]).capitalize()
	var suffix := "  ·  %d gold" % int(offer["price"])
	if bool(offer["sold"]):
		suffix += "  ·  SOLD"
	elif _gold() < int(offer["price"]):
		suffix += "  ·  short %d" % (int(offer["price"]) - _gold())
	var name := str(details.get("name", DETAILS_UNAVAILABLE))
	var available_name := width - _row_width(font, prefix + suffix, px)
	var first := prefix + _fit_row_text(name, available_name, font, px) + suffix
	if details.is_empty():
		return first + "\n" + DETAILS_UNAVAILABLE
	var energy := "%d energy  ·  " % int(details["cost"])
	var rule_width := width - _row_width(font, energy, px)
	var rule := _fit_card_rule(str(details["line"]), rule_width, font, px)
	return first + "\n" + energy + rule


func _row_width(font: Font, value: String, px: int) -> float:
	if font == null:
		return 0.0
	return font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x


## The on-row projection is intentionally lossy, but a visible ellipsis
## distinguishes it from the complete, unmodified authored tooltip.
func _fit_row_text(value: String, width: float, font: Font, px: int) -> String:
	if font == null or _row_width(font, value, px) <= width:
		return value
	if width <= _row_width(font, ELLIPSIS, px):
		return ELLIPSIS
	var low := 0
	var high := value.length()
	while low < high:
		var middle := int((low + high + 1) / 2)
		if _row_width(font, value.substr(0, middle).strip_edges() + ELLIPSIS, px) <= width:
			low = middle
		else:
			high = middle - 1
	var head := value.substr(0, low).strip_edges()
	var word_end := head.rfind(" ")
	if word_end > 0:
		head = head.substr(0, word_end)
	return head.strip_edges() + ELLIPSIS


## When an authored rule ends in a condition, retain that qualifier alongside
## the mechanic rather than turning conditional damage/Block into an unconditional
## claim. No numbers or effects are reconstructed from the offer's ID.
func _fit_card_rule(line: String, width: float, font: Font, px: int) -> String:
	if font == null or _row_width(font, line, px) <= width:
		return line
	for marker in [" if ", " when ", " while ", " after ", " unless ", " per "]:
		var split := line.find(marker)
		if split > 0:
			var qualification := line.substr(split)
			if _row_width(font, qualification, px) < width:
				var lead := _fit_row_text(line.substr(0, split), width -
						_row_width(font, qualification, px) -
						_row_width(font, ELLIPSIS, px), font, px)
				var result := lead + qualification
				if _row_width(font, result, px) <= width:
					return result
	return _fit_row_text(line, width, font, px)


func _patch_caption() -> String:
	var offer := _patch_offer()
	return _caption("PATCH", str(offer["id"]), int(offer["price"]), bool(offer["sold"]))


func _wallet_caption() -> String:
	return "Wallet  ·  %d gold" % _gold()


## One-shot signal wiring for the display-only preview. These listeners only
## repaint the status band and never mint an intent, so they carry no epoch:
## each recomputes from the currently bound source and silently does nothing
## once that source is gone.
func _wire_previews() -> void:
	for i in range(CARD_COUNT):
		var button := card_buttons[i]
		button.mouse_entered.connect(_on_card_hover.bind(i, true))
		button.mouse_exited.connect(_on_card_hover.bind(i, false))
		button.focus_entered.connect(_on_card_focus.bind(i))
		button.focus_exited.connect(_on_preview_refresh)
	for button in [patch_button, leave_button]:
		button.mouse_entered.connect(_on_plain_hover)
		button.focus_entered.connect(_on_preview_refresh)
		button.focus_exited.connect(_on_preview_refresh)


func _on_card_hover(index: int, entered: bool) -> void:
	if index < 0 or index >= CARD_COUNT:
		return
	if entered:
		_hover_index = index
	elif _hover_index == index:
		_hover_index = -1
	_sync_preview()


func _on_plain_hover() -> void:
	_hover_index = -1
	_sync_preview()


func _on_card_focus(index: int) -> void:
	if index < 0 or index >= CARD_COUNT:
		return
	_sync_preview()


## focus_exited fires before the next control receives focus, so the recompute
## waits a frame for the new focus owner instead of flashing the wrong row.
func _on_preview_refresh() -> void:
	_sync_preview.call_deferred()


## The card row the preview currently describes: the pointer wins while it is
## over an offer, otherwise the keyboard focus ring decides, otherwise none.
func _focused_card() -> int:
	for i in range(CARD_COUNT):
		if is_instance_valid(card_buttons[i]) and card_buttons[i].has_focus():
			return i
	return -1


func _sync_preview() -> void:
	if status_label == null:
		return
	if not _active():
		_hover_index = -1
		_preview_index = -1
		for button in card_buttons:
			if is_instance_valid(button):
				button.tooltip_text = ""
		if not _source_current():
			status_label.text = STATUS_CLOSED
		return
	var index := _hover_index
	if index < 0:
		index = _focused_card()
	_apply_preview(index)


func _apply_preview(index: int) -> void:
	_preview_index = index if index >= 0 and index < CARD_COUNT else -1
	if status_label == null:
		return
	if _preview_index < 0:
		status_label.text = STATUS_OPEN
		return
	status_label.text = _clamp_status(_card_preview(_preview_index))


## The authored catalogs the seeded Peddler stock generator itself validates
## candidate offers against. They are immutable authored data, so one instance
## is reused for every preview on this panel.
func _preview_catalogs() -> Array:
	if _catalogs.is_empty():
		_catalogs = RunShopStockOffers._peddler_catalogs()
	return _catalogs


## The offered card's own authored record, or {} when the exact offered ID has
## no definition, the definition's owner is not the verified offer owner, or
## the record cannot be stated truthfully (non-integer cost, no effect line).
func _card_details(index: int) -> Dictionary:
	if _source.is_empty() or index < 0 or index >= CARD_COUNT:
		return {}
	var offer := _offer(index)
	var offer_id := str(offer.get("id", ""))
	var offer_owner := str(offer.get("owner", ""))
	if offer_id.is_empty() or offer_owner.is_empty():
		return {}
	var found := RunShopStockOffers._find_card_definition(offer_id, _preview_catalogs())
	if found.is_empty():
		return {}
	var definition: Variant = found.get("def")
	if typeof(definition) != TYPE_DICTIONARY or (definition as Dictionary).is_empty():
		return {}
	var card: Dictionary = definition
	if typeof(card.get("id")) != TYPE_STRING or str(card["id"]) != offer_id:
		return {}
	if typeof(card.get("owner")) != TYPE_STRING or str(card["owner"]) != offer_owner:
		return {}
	if typeof(card.get("cost")) != TYPE_INT or int(card["cost"]) < 0:
		return {}
	var described := CardShortRules.describe(card)
	if described.get("known") != true:
		return {}
	var line := str(described.get("line", "")).strip_edges()
	if line.is_empty():
		return {}
	var display_name := str(card.get("display_name", "")).strip_edges()
	return {
		"id": offer_id,
		"owner": offer_owner,
		"name": display_name if not display_name.is_empty() else readable_id(offer_id),
		"cost": int(card["cost"]),
		"line": line,
		"unknown": described.get("unknown") == true,
	}


## The complete single-line preview: exact offered ID, its authored owner, its
## authored energy cost and the CardShortRules sentences that print the real
## effects (including the honest "other effects not described" sentence).
func _card_preview(index: int) -> String:
	if _source.is_empty() or index < 0 or index >= CARD_COUNT:
		return DETAILS_UNAVAILABLE
	var offer := _offer(index)
	var details := _card_details(index)
	if details.is_empty():
		return "%s  ·  %s  ·  %s" % [str(offer.get("owner", "")).capitalize(),
				readable_id(str(offer.get("id", ""))), DETAILS_UNAVAILABLE]
	return "%s  ·  %s  ·  %s  ·  %d energy  ·  %s" % [
			str(details["owner"]).capitalize(), str(details["name"]), str(details["id"]),
			int(details["cost"]), str(details["line"])]


## The full ability text for one offered card, kept in that card Button's
## tooltip even when the status band can only show a shortened display line.
func _card_tooltip(index: int) -> String:
	if _source.is_empty() or index < 0 or index >= CARD_COUNT:
		return ""
	var offer := _offer(index)
	var details := _card_details(index)
	if details.is_empty():
		return "%s  ·  %s\n%s" % [str(offer.get("owner", "")).capitalize(),
				readable_id(str(offer.get("id", ""))), DETAILS_UNAVAILABLE]
	return "%s  ·  %s\n%s card  ·  %d energy  ·  %d gold\n%s" % [
			str(details["name"]), str(details["id"]), str(details["owner"]).capitalize(),
			int(details["cost"]), int(offer.get("price", 0)), str(details["line"])]


## Shortens only the on-screen display when the status band is too narrow for
## the complete preview at its shipped 18px face. The unshortened text stays in
## the card's tooltip, so a cut line is never the only description a player gets.
func _clamp_status(text: String) -> String:
	if status_label == null:
		return text
	var font := status_label.get_theme_font("font")
	if font == null:
		return text
	var width := STATUS_WIDTH
	if status_label.size.x > 0.0:
		width = minf(STATUS_WIDTH, status_label.size.x)
	var font_size := status_label.get_theme_font_size("font_size")
	if _status_width(font, text, font_size) <= width:
		return text
	var low := 0
	var high := text.length()
	while low < high:
		var mid := int((low + high + 1) / 2)
		var candidate := text.substr(0, mid).strip_edges() + ELLIPSIS
		if _status_width(font, candidate, font_size) <= width:
			low = mid
		else:
			high = mid - 1
	if low <= 0:
		return ELLIPSIS
	var head := text.substr(0, low)
	var last_space := head.rfind(" ")
	if last_space > 0:
		head = head.substr(0, last_space)
	return head.strip_edges() + ELLIPSIS


func _status_width(font: Font, text: String, font_size: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func _card_buyable(index: int) -> bool:
	var offer := _offer(index)
	return not bool(offer["sold"]) and _gold() >= int(offer["price"])


func _patch_buyable() -> bool:
	var offer := _patch_offer()
	return not bool(offer["sold"]) and _gold() >= int(offer["price"])


func _retire_callbacks() -> void:
	for button in _connections:
		if is_instance_valid(button) and button.pressed.is_connected(_connections[button]):
			button.pressed.disconnect(_connections[button])
	_connections.clear()


func _attach(button: Button, callback: Callable) -> void:
	button.pressed.connect(callback)
	_connections[button] = callback


func _attached(button: Button) -> bool:
	return is_instance_valid(button) and button.get_parent() == self \
			and button.is_inside_tree() and button.is_visible_in_tree()


func _refresh() -> void:
	if title_label == null:
		return
	_retire_callbacks()
	_hover_index = -1
	_preview_index = -1
	var open := _source_current()
	title_label.text = TITLE_TEXT
	wallet_label.text = _wallet_caption() if open else WALLET_CLOSED
	status_label.text = STATUS_OPEN if open else STATUS_CLOSED
	for i in range(CARD_COUNT):
		var button := card_buttons[i]
		button.text = _card_caption(i) if open else ""
		button.disabled = true if not open else not _card_buyable(i)
		button.set_meta("offer_kind", CARD_KIND if open else "")
		button.set_meta("offer_id", str(_offer(i)["id"]) if open else "")
		# The complete authored ability belongs to the card's own tooltip, so a
		# shortened on-panel line never hides an effect. A closed binding and a
		# fresh rebind drop the previous visit's text instead of keeping it.
		button.tooltip_text = _card_tooltip(i) if open else ""
		button.add_theme_stylebox_override("normal", _style(
				OXBLOOD if open else PLUM, GOLD if open and not button.disabled else INK))
		if open:
			_attach(button, _request_buy.bind(i, false, button, _epoch, _visit))
	patch_button.text = _patch_caption() if open else ""
	patch_button.disabled = true if not open else not _patch_buyable()
	patch_button.set_meta("offer_kind", PATCH_KIND if open else "")
	patch_button.set_meta("offer_id", str(_patch_offer()["id"]) if open else "")
	patch_button.add_theme_stylebox_override("normal", _style(
			TEAL if open else PLUM, GOLD if open and not patch_button.disabled else INK))
	if open:
		_attach(patch_button, _request_buy.bind(0, true, patch_button, _epoch, _visit))
	leave_button.text = LEAVE_TEXT
	leave_button.disabled = not open
	if open:
		_attach(leave_button, _request_leave.bind(_epoch, _visit))
	_wire_focus()
	# Re-derive the band from the current source only: neutral unless a card of
	# this exact generation is still hovered or focused.
	_sync_preview()


func _focusables() -> Array[Button]:
	var list: Array[Button] = []
	for button in card_buttons + [patch_button, leave_button]:
		if not button.disabled:
			list.append(button)
	return list


func _wire_focus() -> void:
	var focusables := _focusables()
	for i in range(focusables.size()):
		focusables[i].focus_next = focusables[i].get_path_to(
				focusables[(i + 1) % focusables.size()])
		focusables[i].focus_previous = focusables[i].get_path_to(
				focusables[(i + focusables.size() - 1) % focusables.size()])


func _focus_initial() -> void:
	if not is_inside_tree() or not _source_current():
		return
	var focusables := _focusables()
	if not focusables.is_empty():
		focusables[0].grab_focus()


## The band may show the neutral hint or a preview computed from THIS source.
## Any other text (a forged or stale line) is refused, so a mutable label can
## never authenticate a press.
func _status_authentic() -> bool:
	if status_label == null:
		return false
	if status_label.text == STATUS_OPEN:
		return true
	if _source.is_empty() or not _valid_open_state(_source):
		return false
	for i in range(CARD_COUNT):
		if status_label.text == _clamp_status(_card_preview(i)):
			return true
	return false


## Every displayed control must still be a mounted, honestly labelled projection
## of THIS exact open generation before any press may leave the view.
func _auth(epoch: int, source: RunPeddlerVisit) -> bool:
	if epoch != _epoch or source == null or not is_same(source, _visit) or not _active():
		return false
	if title_label.text != TITLE_TEXT or wallet_label.text != _wallet_caption() \
			or not _status_authentic() or leave_button.text != LEAVE_TEXT:
		return false
	for i in range(CARD_COUNT):
		var button := card_buttons[i]
		if not _attached(button) or button.text != _card_caption(i) \
				or not button.get_meta("offer_kind", "") is String \
				or not button.get_meta("offer_id", "") is String \
				or button.get_meta("offer_kind", "") != CARD_KIND \
				or button.get_meta("offer_id", "") != str(_offer(i)["id"]) \
				or button.disabled != (not _card_buyable(i)):
			return false
	if not _attached(patch_button) or patch_button.text != _patch_caption() \
			or not patch_button.get_meta("offer_kind", "") is String \
			or not patch_button.get_meta("offer_id", "") is String \
			or patch_button.get_meta("offer_kind", "") != PATCH_KIND \
			or patch_button.get_meta("offer_id", "") != str(_patch_offer()["id"]) \
			or patch_button.disabled != (not _patch_buyable()):
		return false
	return _attached(leave_button) and not leave_button.disabled


func _request_buy(index: int, is_patch: bool, button: Button, epoch: int,
		source: RunPeddlerVisit) -> void:
	if not _auth(epoch, source):
		return
	if is_patch:
		if button != patch_button or index != 0:
			return
	elif index < 0 or index >= CARD_COUNT or button != card_buttons[index]:
		return
	if button.disabled:
		return
	var offer := _patch_offer() if is_patch else _offer(index)
	if bool(offer["sold"]) or _gold() < int(offer["price"]):
		return
	_submit({
		"node_id": str(_source["node_id"]),
		"kind": PATCH_KIND if is_patch else CARD_KIND,
		"id": str(offer["id"]),
		"expected_state": _source["state"].duplicate(true),
		"expected_stock": _source["stock"].duplicate(true),
	})


func _request_leave(epoch: int, source: RunPeddlerVisit) -> void:
	if not _auth(epoch, source) or leave_button.disabled:
		return
	_submit({
		"node_id": str(_source["node_id"]),
		"kind": LEAVE_KIND,
		"expected_state": _source["state"].duplicate(true),
		"expected_stock": _source["stock"].duplicate(true),
	})


## Only the exact receipt from a genuine button press can reach the controller.
func consume_intent(intent: Dictionary) -> bool:
	if not _submitted or _pending_intent.is_empty() or intent != _pending_intent:
		return false
	_pending_intent.clear()
	return true


func retry_submission() -> void:
	if not _pending_intent.is_empty():
		return
	_submitted = false
	_refresh()


func _submit(intent: Dictionary) -> void:
	_submitted = true
	_pending_intent = intent.duplicate(true)
	for button in card_buttons + [patch_button, leave_button]:
		button.disabled = true
	_retire_callbacks()
	intent_requested.emit(intent.duplicate(true))
