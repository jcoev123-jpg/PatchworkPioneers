class_name LivePatchStallPanel
extends Control
## Presentation and source-bound intents only. Purchasing and sewing belong to a controller.
signal intent_requested(intent: Dictionary)

const PANEL_ART := "res://assets/paper/ui/reward_panel.png"
const CREAM := Color("#f3e6cf")
const GOLD := Color("#e9c47d")
const THREAD := Color("#b9a58d")
const PLUM := Color("#37293f")
const TEAL := Color("#214b50")
const OXBLOOD := Color("#713544")
const INK := Color("#191b2a")
const DIM := Color("#b6a9a2")
const PANEL_SIZE := Vector2(900, 630)

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
var wearer_label: Label
var status_label: Label
var wearer_buttons: Array[Button] = []
var offer_buttons: Array[Button] = []
var leave_button: Button

var _visit: RunPatchStallVisit
var _source: Dictionary = {}
var _quoted: Dictionary = {}
var _slots: Dictionary = {}
var _epoch := 0
var _submitted := false
var _wearer_index := 0
var _connections: Dictionary = {} # Only view-owned Button.pressed -> Callable.

func _ready() -> void:
	size = PANEL_SIZE
	custom_minimum_size = PANEL_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backing := Panel.new()
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backing)
	backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backing.add_theme_stylebox_override("panel", _panel_style())
	backing.add_child(SewnBorder.new())
	title_label = _label("PATCH STALL    ✕    sewn power patches", Vector2(40, 24), Vector2(820, 48), 32, GOLD)
	wallet_label = _label("", Vector2(43, 76), Vector2(808, 36), 25, CREAM)
	wearer_label = _label("Pin the patch to:", Vector2(43, 128), Vector2(760, 31), 22, GOLD)
	for i in range(3):
		wearer_buttons.append(_button("", Vector2(43 + i * 278, 165), Vector2(264, 57), TEAL, 22))
	for i in range(3):
		offer_buttons.append(_button("", Vector2(43, 239 + i * 99), Vector2(814, 90), OXBLOOD, 23))
	leave_button = _button("Leave  ·  FREE", Vector2(43, 545), Vector2(814, 60), TEAL, 26)
	status_label = _label("", Vector2(43, 612), Vector2(814, 15), 12, DIM)
	_refresh()
	_focus_initial()

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
	var focus := _style(Color.TRANSPARENT, GOLD, 4)
	focus.draw_center = false
	button.add_theme_stylebox_override("focus", focus)
	add_child(button)
	button.add_child(SewnBorder.new())
	return button

## A valid bind captures both independently returned service receipts; no prices
## or identities can be supplied separately by the caller.
func bind(visit: RunPatchStallVisit) -> void:
	_epoch += 1
	_retire_callbacks()
	_visit = null
	_source = {}
	_quoted = {}
	_slots = {}
	_submitted = false
	_wearer_index = 0
	if visit != null and visit.is_valid() and not visit.is_consumed():
		var state: Dictionary = visit.read_state()
		var quote: Dictionary = visit.quote()
		var powers := RunAuthoredPatchDefinitions.load_power_definitions()
		var slots: Dictionary = {}
		for record in powers:
			if typeof(record) == TYPE_DICTIONARY and record.has("id") and record.has("slot"):
				slots[record["id"]] = record["slot"]
		if _valid_receipts(state, quote, slots):
			_visit = visit
			_source = state.duplicate(true)
			_quoted = quote.duplicate(true)
			_slots = slots.duplicate(true)
	if is_node_ready():
		show()
		_refresh()
		_focus_initial()

func close() -> void:
	bind(null)
	hide()

func _valid_receipts(state: Dictionary, quote: Dictionary, slots: Dictionary) -> bool:
	if state.get("status") != "available" or typeof(state.get("node_id")) != TYPE_STRING \
			or typeof(state.get("visit_id")) != TYPE_STRING \
			or str(state["node_id"]).strip_edges().is_empty() \
			or str(state["visit_id"]).strip_edges().is_empty():
		return false
	var snapshot: Variant = state.get("snapshot")
	if typeof(snapshot) != TYPE_DICTIONARY or typeof(snapshot.get("party_ids")) != TYPE_ARRAY \
			or snapshot["party_ids"].size() != 3 or typeof(snapshot.get("deck_ids")) != TYPE_ARRAY \
			or typeof(snapshot.get("owned_trinkets")) != TYPE_ARRAY \
			or typeof(snapshot.get("gold")) != TYPE_INT or snapshot["gold"] < 0:
		return false
	var seen_party := {}
	for hero in snapshot["party_ids"]:
		if typeof(hero) != TYPE_STRING or hero.strip_edges().is_empty() or seen_party.has(hero):
			return false
		seen_party[hero] = true
	if quote.get("decisions") != ["buy_patch", "leave"] or typeof(quote.get("offers")) != TYPE_ARRAY \
			or quote["offers"].size() != 3:
		return false
	var seen := {}
	for record in quote["offers"]:
		if typeof(record) != TYPE_DICTIONARY:
			return false
		var id: Variant = record.get("id")
		var price: Variant = record.get("price")
		if typeof(id) != TYPE_STRING or id.strip_edges().is_empty() or seen.has(id) \
				or not slots.has(id) or not slots[id] in ["HEAD", "ARM", "COAT"] \
				or typeof(price) != TYPE_INT or price < 0 or record.get("sold") != false \
				or snapshot["owned_trinkets"].has(id):
			return false
		seen[id] = true
	return true

func _source_current() -> bool:
	if _visit == null or _submitted or not _visit.is_valid() or _visit.is_consumed() \
			or _source.is_empty() or _quoted.is_empty():
		return false
	return _visit.read_state() == _source and _visit.quote() == _quoted \
			and _valid_receipts(_source, _quoted, _slots)

func _active() -> bool:
	return is_inside_tree() and is_visible_in_tree() and _source_current()

func _name(id: String) -> String:
	return id.replace("_", " ").capitalize()

func _wallet_caption() -> String:
	return "Wallet    ✕    %d gold" % int(_source["snapshot"]["gold"])

func _wearer_caption(i: int) -> String:
	var id: String = _source["snapshot"]["party_ids"][i]
	return ("✕  " if _wearer_index == i else "·  ") + _name(id)

func _offer_caption(i: int) -> String:
	var offer: Dictionary = _quoted["offers"][i]
	var id: String = offer["id"]
	var price: int = offer["price"]
	var shortfall: int = maxi(0, price - int(_source["snapshot"]["gold"]))
	var cost := "%d gold" % price if shortfall == 0 else "%d gold  ·  short %d" % [price, shortfall]
	return "%s  [%s]    ✕ %s    ·    %s" % [_name(id), id, _slots[id], cost]

func _retire_callbacks() -> void:
	for button in _connections:
		if is_instance_valid(button) and button.pressed.is_connected(_connections[button]):
			button.pressed.disconnect(_connections[button])
	_connections.clear()

func _attach(button: Button, callback: Callable) -> void:
	button.pressed.connect(callback)
	_connections[button] = callback

func _refresh() -> void:
	if title_label == null:
		return
	_retire_callbacks()
	var open := _source_current()
	wallet_label.text = _wallet_caption() if open else "Wallet unavailable"
	wearer_label.text = "Pin the patch to:" if open else "Patch Stall unavailable"
	status_label.text = "Choose one patch or Leave." if open else "No open quote."
	for i in range(3):
		var pin := wearer_buttons[i]
		var offer_button := offer_buttons[i]
		pin.disabled = not open
		pin.text = _wearer_caption(i) if open else ""
		pin.set_meta("wearer_id", _source["snapshot"]["party_ids"][i] if open else "")
		pin.add_theme_stylebox_override("normal", _style(OXBLOOD if open and i == _wearer_index else TEAL, GOLD if open and i == _wearer_index else INK))
		offer_button.text = _offer_caption(i) if open else ""
		offer_button.set_meta("patch_id", _quoted["offers"][i]["id"] if open else "")
		offer_button.disabled = not open or int(_source["snapshot"]["gold"]) < int(_quoted["offers"][i]["price"]) if open else true
		if open:
			_attach(pin, _choose_wearer.bind(i, pin, _epoch, _visit))
			_attach(offer_button, _request_patch.bind(i, offer_button, _epoch, _visit))
	leave_button.text = "Leave  ·  FREE"
	leave_button.disabled = not open
	if open:
		_attach(leave_button, _request_leave.bind(_epoch, _visit))
	_wire_focus()

func _wire_focus() -> void:
	var focusables: Array[Button] = []
	for button in wearer_buttons + offer_buttons + [leave_button]:
		if not button.disabled:
			focusables.append(button)
	for i in range(focusables.size()):
		focusables[i].focus_next = focusables[i].get_path_to(focusables[(i + 1) % focusables.size()])
		focusables[i].focus_previous = focusables[i].get_path_to(focusables[(i + focusables.size() - 1) % focusables.size()])

func _focus_initial() -> void:
	if not is_inside_tree() or not _source_current():
		return
	wearer_buttons[0].grab_focus()

func _auth(epoch: int, source: RunPatchStallVisit) -> bool:
	if epoch != _epoch or source == null or not is_same(source, _visit) or not _active():
		return false
	if title_label.text != "PATCH STALL    ✕    sewn power patches" \
			or wallet_label.text != _wallet_caption() or wearer_label.text != "Pin the patch to:" \
			or leave_button.text != "Leave  ·  FREE":
		return false
	for i in range(3):
		if not _attached(wearer_buttons[i]) or wearer_buttons[i].disabled \
				or wearer_buttons[i].text != _wearer_caption(i) \
				or wearer_buttons[i].get_meta("wearer_id") != _source["snapshot"]["party_ids"][i]:
			return false
		if not _attached(offer_buttons[i]) or offer_buttons[i].text != _offer_caption(i) \
				or offer_buttons[i].get_meta("patch_id") != _quoted["offers"][i]["id"] \
				or offer_buttons[i].disabled != (int(_source["snapshot"]["gold"]) < int(_quoted["offers"][i]["price"])):
			return false
	return _attached(leave_button) and not leave_button.disabled

func _attached(button: Button) -> bool:
	return is_instance_valid(button) and button.get_parent() == self \
			and button.is_inside_tree() and button.is_visible_in_tree()

func _choose_wearer(index: int, button: Button, epoch: int, source: RunPatchStallVisit) -> void:
	if not _auth(epoch, source) or index < 0 or index >= wearer_buttons.size() \
			or wearer_buttons[index] != button or button.disabled:
		return
	_wearer_index = index
	for i in range(3):
		wearer_buttons[i].text = _wearer_caption(i)
		wearer_buttons[i].add_theme_stylebox_override("normal",
			_style(OXBLOOD if i == index else TEAL, GOLD if i == index else INK))

func _request_patch(index: int, button: Button, epoch: int, source: RunPatchStallVisit) -> void:
	if not _auth(epoch, source) or index < 0 or index >= offer_buttons.size() \
			or button != offer_buttons[index] or button.disabled \
			or _wearer_index < 0 or _wearer_index >= 3:
		return
	var offer: Dictionary = _quoted["offers"][index]
	if int(_source["snapshot"]["gold"]) < int(offer["price"]):
		return
	_submit({
		"action": "buy_patch", "patch_id": offer["id"],
		"wearer_id": _source["snapshot"]["party_ids"][_wearer_index],
		"node_id": _source["node_id"], "visit_id": _source["visit_id"],
		"expected_snapshot": _source["snapshot"].duplicate(true),
	})

func _request_leave(epoch: int, source: RunPatchStallVisit) -> void:
	if not _auth(epoch, source):
		return
	_submit({
		"action": "leave", "node_id": _source["node_id"],
		"visit_id": _source["visit_id"],
		"expected_snapshot": _source["snapshot"].duplicate(true),
	})

func _submit(intent: Dictionary) -> void:
	_submitted = true
	for button in wearer_buttons + offer_buttons + [leave_button]:
		button.disabled = true
	_retire_callbacks()
	intent_requested.emit(intent.duplicate(true))
