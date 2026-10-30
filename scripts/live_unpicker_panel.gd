class_name LiveUnpickerPanel
extends Control
## Standalone Unpicker view. The route owner alone may validate and settle intents.
signal decision_requested(intent: Dictionary)

const PANEL_ART := "res://assets/paper/ui/reward_panel.png"
const BUTTON_ART := "res://assets/paper/ui/reward_button.png"
const CREAM := Color("#f0e4ca")
const THREAD := Color("#c9b996")
const FELT := Color("#343c39")
const GOLD := Color("#f1d18b")
const DIM := Color("#b8aca0")

## The stitched outline is input-transparent; every actual action is a Button.
class SewnOutline extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(queue_redraw)

	func _draw() -> void:
		if size.x < 24 or size.y < 24:
			return
		var rect := Rect2(Vector2(9, 8), size - Vector2(18, 16))
		for y in [rect.position.y, rect.end.y]:
			draw_dashed_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), THREAD, 1.5, 7.0)
		for x in [rect.position.x, rect.end.x]:
			draw_dashed_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), THREAD, 1.5, 7.0)

var title_label: Label
var wallet_label: Label
var status_label: Label
var choice_scroll: ScrollContainer
var choices: VBoxContainer
var remove_button: Button
var leave_button: Button
var card_buttons: Array[Button] = []

var _visit: RunUnpickerVisit
var _source: Dictionary = {}
var _epoch := 0
var _submitted := false
var _selected_id := ""
var _selected_button: Button
var _rows: Dictionary = {} # Button -> immutable card ID, first index and caption.
var _connections: Dictionary = {} # Only view-owned pressed callbacks; retired on rebind.


func _ready() -> void:
	custom_minimum_size = Vector2(880, 600)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backing := Panel.new()
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backing)
	backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backing.add_theme_stylebox_override("panel", _panel_style())
	backing.add_child(SewnOutline.new())

	title_label = _label("UNPICKER  ·  remove one card", Vector2(30, 23), Vector2(820, 43), 30, GOLD)
	wallet_label = _label("", Vector2(30, 73), Vector2(820, 34), 22, CREAM)
	# Reserved height: a long stitched owner/name forecast wraps to three lines and
	# must stay above the card rows instead of drawing over them.
	status_label = _label("", Vector2(30, 116), Vector2(820, 86), 18, CREAM)

	choice_scroll = ScrollContainer.new()
	choice_scroll.position = Vector2(30, 208)
	choice_scroll.size = Vector2(820, 278)
	choice_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	choice_scroll.follow_focus = true
	add_child(choice_scroll)
	choices = VBoxContainer.new()
	choices.custom_minimum_size.x = 792
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.add_theme_constant_override("separation", 9)
	choice_scroll.add_child(choices)

	remove_button = _button("1 Remove", Vector2(30, 510), Vector2(390, 62))
	leave_button = _button("0 Leave · free", Vector2(450, 510), Vector2(400, 62))
	_refresh()
	_grab_initial_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.ctrl_pressed or key.alt_pressed or key.shift_pressed or key.meta_pressed:
		return
	var button: Button
	match key.keycode:
		KEY_1, KEY_KP_1: button = remove_button
		KEY_0, KEY_KP_0: button = leave_button
	if button == null or not is_visible_in_tree() or not _active():
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner == null or (focus_owner != self and not is_ancestor_of(focus_owner)):
		return
	if button.disabled or not button.is_visible_in_tree():
		return
	get_viewport().set_input_as_handled()
	button.pressed.emit()


func _panel_style() -> StyleBox:
	if ResourceLoader.exists(PANEL_ART, "Texture2D"):
		var image := ResourceLoader.load(PANEL_ART) as Texture2D
		if image != null:
			var texture := StyleBoxTexture.new()
			texture.texture = image
			texture.modulate_color = Color("#647269")
			texture.set_texture_margin_all(24)
			return texture
	var style := StyleBoxFlat.new()
	style.bg_color = FELT
	style.border_color = THREAD
	style.set_border_width_all(4)
	style.set_corner_radius_all(6)
	return style


func _button_style(fill: Color, edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(8)
	return style


func _label(value: String, at: Vector2, dimensions: Vector2, font_size: int, ink: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.position = at
	label.size = dimensions
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", ink)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _button(value: String, at: Vector2, dimensions: Vector2) -> Button:
	var button := Button.new()
	button.text = value
	button.position = at
	button.size = dimensions
	button.custom_minimum_size = dimensions
	button.focus_mode = Control.FOCUS_ALL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", 20)
	for state in ["font_color", "font_hover_color", "font_pressed_color",
			"font_hover_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, CREAM)
	button.add_theme_color_override("font_disabled_color", DIM)
	button.add_theme_stylebox_override("normal", _button_style(Color("#485348"), THREAD))
	button.add_theme_stylebox_override("hover", _button_style(Color("#63705a"), CREAM))
	button.add_theme_stylebox_override("pressed", _button_style(Color("#35463e"), GOLD))
	button.add_theme_stylebox_override("disabled", _button_style(Color("#41423c"), Color("#8a8378")))
	var focus := _button_style(Color.TRANSPARENT, GOLD)
	focus.draw_center = false
	focus.set_border_width_all(3)
	button.add_theme_stylebox_override("focus", focus)
	# Same drawn running-stitch treatment as the shared patchwork shell's buttons.
	button.add_child(SewnOutline.new())
	add_child(button)
	return button


## Binding is restricted to a real valid, unconsumed service. Never accept a quote
## or deck supplied by a view caller separately from that service.
func bind(visit: RunUnpickerVisit) -> void:
	_epoch += 1
	_retire_callbacks()
	_visit = visit if visit != null and visit.is_valid() and not visit.is_consumed() else null
	_source = _visit.read_state().duplicate(true) if _visit != null else {}
	_submitted = false
	_selected_id = ""
	_selected_button = null
	if is_node_ready():
		visible = true
		_refresh()
		_grab_initial_focus()


func close() -> void:
	bind(null)
	hide()


## The single authoritative initial-focus decision, shared by _ready and bind:
## a visit whose authentic wallet cannot pay the exact removal quote starts on
## the only finishable action, free Leave; an affordable visit starts on the
## first real card row. Focus never disables or hides rows, and an invalid,
## closed or consumed visit acquires neither focus nor callbacks.
func _grab_initial_focus() -> void:
	if not _active():
		return
	if _affordable() and not card_buttons.is_empty():
		card_buttons[0].grab_focus()
	else:
		leave_button.grab_focus()


func _source_current() -> bool:
	if _visit == null or _submitted or not _visit.is_valid() or _visit.is_consumed():
		return false
	if _source.is_empty() or not _source.get("valid", false) or _source.get("consumed", true):
		return false
	if _visit.read_state() != _source:
		return false
	var quote := _visit.quote()
	var expected_price: int = RunShopCardRemoval.BASE_PRICE + RunShopCardRemoval.PRICE_STEP * int(_source["prior_removals"])
	return quote.get("ok") == true and quote.get("visit_id") == _source["visit_id"] \
			and quote.get("node_id") == _source["node_id"] \
			and quote.get("price") == expected_price and _source.get("price") == expected_price \
			and quote.get("choices") == ["remove_card", "leave"]


func _quote_line() -> String:
	if _source.is_empty():
		return ""
	return "Wallet: %d gold    •    Remove: %d gold" % [int(_source["gold"]), int(_source["price"])]


func _remove_caption() -> String:
	if not _source_current():
		return "1 Remove"
	return "1 Remove · %d gold" % int(_source["price"])


func _active() -> bool:
	return is_inside_tree() and is_visible_in_tree() and _source_current() \
			and wallet_label != null and wallet_label.text == _quote_line() \
			and remove_button != null and remove_button.text == _remove_caption()


func _canonical_ids() -> Array[String]:
	var result: Array[String] = []
	if _source.is_empty():
		return result
	for card_id in _source["deck"]:
		if not result.has(card_id):
			result.append(card_id)
	return result


func _card_name(id: String) -> String:
	var descriptors: Dictionary = _source.get("descriptors", {})
	if descriptors.has(id):
		var descriptor: Dictionary = descriptors[id]
		var named := str(descriptor.get("display_name", "")).strip_edges()
		var halves: Array = descriptor.get("half_ids", [])
		if named.is_empty():
			var names: PackedStringArray = []
			for half in halves:
				var definition := RunRestStitchCards.resolve_card_definition(half)
				names.append(str(definition.get("display_name", "Unknown half")))
			named = " / ".join(names) if not names.is_empty() else "Unknown stitched card"
		var owners: PackedStringArray = []
		for half in halves:
			var definition := RunRestStitchCards.resolve_card_definition(half)
			var owner_id := str(definition.get("owner", ""))
			if not owner_id.is_empty():
				owners.append(owner_id.capitalize())
		var owner_prefix := " / ".join(owners)
		if not owner_prefix.is_empty():
			owner_prefix += " - "
		return owner_prefix + named
	# The canonical P11 curse is deck-only: the stitchable-catalog resolver
	# intentionally returns {} for it. This narrow, trusted path names only that
	# exact authored record; every other ID keeps the ordinary/unknown rules.
	if id == MpwFrayedDebt.CARD_ID:
		var curse: Dictionary = MpwFrayedDebt.new().get_definition(id)
		var curse_name := str(curse.get("display_name", "")).strip_edges()
		if not curse.is_empty() and str(curse.get("owner", "owned")) == "" and not curse_name.is_empty():
			return curse_name
	var definition := RunRestStitchCards.resolve_card_definition(id)
	var named := str(definition.get("display_name", "")).strip_edges()
	if named.is_empty():
		named = "Unknown card"
	var owner_id := str(definition.get("owner", ""))
	var owner_prefix := owner_id.capitalize() + " " if not owner_id.is_empty() else ""
	return owner_prefix + named


func _caption(id: String) -> String:
	var first: int = (_source["deck"] as Array).find(id) + 1
	return "%02d  •  %s" % [first, _card_name(id)]


## A detached, purely informational hover explanation of one authenticated row.
## It reads only the supplied source snapshot and the authored card catalogs:
## it never selects, removes, spends or draws randomness. A stitched composite
## is described from its descriptor halves, always in authored FIRST/THEN order.
static func card_tooltip(source: Dictionary, id: String) -> String:
	var deck: Array = source.get("deck", [])
	if id.is_empty() or not deck.has(id):
		return ""
	var descriptors: Dictionary = source.get("descriptors", {})
	if descriptors.has(id):
		var descriptor: Variant = descriptors[id]
		if not descriptor is Dictionary:
			return "Unknown stitched card: its descriptor is not authentic."
		return _stitched_tooltip(descriptor)
	# Same narrow exception as _card_name: only the exact canonical P11 curse
	# ID, and only through its own authenticated authored record. Any other
	# ID keeps the ordinary stitchable-catalog rules below.
	if id == MpwFrayedDebt.CARD_ID:
		var curse: Dictionary = MpwFrayedDebt.new().get_definition(id)
		if not curse.is_empty():
			return _curse_tooltip(curse, source)
	return _definition_tooltip(RunRestStitchCards.resolve_card_definition(id))


## An ordinary starter, pool or upgraded card: authored owner/name, printed
## energy cost, the legal FROM/TO slots when the record carries them, and the
## exact terse CardShortRules sentence. Nothing is inferred from button text.
static func _definition_tooltip(definition: Dictionary) -> String:
	if definition.is_empty():
		return "Unknown card: no authentic authored definition resolves."
	var lines: Array[String] = [
		"%s • %s" % [_card_title(definition), _cost_text(definition.get("cost"))]]
	var movement := _movement_text(definition)
	if not movement.is_empty():
		lines.append(movement)
	var rule := CardShortRules.line(definition)
	if not rule.is_empty():
		lines.append(rule)
	return "\n".join(lines)


## The canonical P11 Frayed Debt curse, described only from its authenticated
## authored record: an ownerless, unplayable curse that automatically Exhausts
## on its first draw of each fight while still using that draw up, never
## upgrades or stitches, and leaves the deck only through the Unpicker's paid
## gold removal. It is never given a fictitious energy cost.
static func _curse_tooltip(definition: Dictionary, source: Dictionary) -> String:
	if definition.is_empty():
		return "Unknown card: no authentic authored definition resolves."
	var named := str(definition.get("display_name", "")).strip_edges()
	var lines: Array[String] = ["%s • %s" % [
			named if not named.is_empty() else "Unknown card",
			str(definition.get("card_type", "curse"))]]
	if definition.get("playable") == false:
		lines.append("Unplayable: it has no energy cost and never enters play.")
	if definition.get("exhaust_on_first_draw") == true:
		var draw := "Automatically Exhausts on its first draw of each fight"
		if definition.get("consumes_draw") == true:
			draw += ", and that draw is still used up (no extra card, no energy charged)"
		lines.append(draw + ".")
	if definition.get("can_upgrade") == false and definition.get("can_stitch") == false:
		lines.append("It cannot be upgraded or stitched.")
	if definition.get("removable") == true:
		var price: Variant = source.get("price", null)
		if typeof(price) == TYPE_INT and int(price) > 0:
			lines.append("The Unpicker can remove one copy for %d gold." % int(price))
		else:
			lines.append("The Unpicker can remove one copy for gold.")
	return "\n".join(lines)


## A genuine stitched card is never a standalone catalog ID: both halves come
## from the descriptor's canonical half_ids through the production resolver.
static func _stitched_tooltip(descriptor: Dictionary) -> String:
	var half_ids: Array = descriptor.get("half_ids", [])
	var named := str(descriptor.get("display_name", "")).strip_edges()
	if half_ids.size() != 2:
		return ("Stitched card: " + named if not named.is_empty() else "Unknown stitched card") \
				+ "\nIts authored half definitions do not resolve."
	var first := RunRestStitchCards.resolve_card_definition(half_ids[0])
	var second := RunRestStitchCards.resolve_card_definition(half_ids[1])
	if first.is_empty() or second.is_empty():
		return ("Stitched card: " + named if not named.is_empty() else "Unknown stitched card") \
				+ "\nIts authored half definitions do not resolve."
	var owners: Array[String] = []
	for half in [first, second]:
		var owner_id := str(half.get("owner", "")).strip_edges()
		if not owner_id.is_empty():
			owners.append(owner_id.capitalize())
	var title := " / ".join(owners)
	if not named.is_empty():
		title += (" — " if not title.is_empty() else "") + named
	var cost := _stitched_cost(descriptor, first, second)
	var lines: Array[String] = [
		"Stitched card • %s (higher half cost + 1, capped at 3)" % _cost_text(cost),
		title,
		_half_text("FIRST", first),
	]
	var first_rule := CardShortRules.line(first)
	if not first_rule.is_empty():
		lines.append(first_rule)
	lines.append(_half_text("SECOND", second))
	var second_rule := CardShortRules.line(second)
	if not second_rule.is_empty():
		lines.append(second_rule)
	lines.append("Both owners must be alive and in their own FROM slots to play it. " \
			+ "It cannot be stitched again or upgraded. " \
			+ "Inspection only: Remove retires it without playing it.")
	return "\n".join(lines)


## The descriptor's validated cost; a malformed ledger falls back to the
## authored stitched formula instead of inventing a price.
static func _stitched_cost(descriptor: Dictionary, first: Dictionary,
		second: Dictionary) -> int:
	var authored: Variant = descriptor.get("cost")
	if authored is int and int(authored) >= 0:
		return int(authored)
	var first_cost: Variant = first.get("cost")
	var second_cost: Variant = second.get("cost")
	if first_cost is int and second_cost is int:
		return mini(3, maxi(int(first_cost), int(second_cost)) + 1)
	return -1


static func _half_text(order: String, definition: Dictionary) -> String:
	var parts: Array[String] = [
		"%s — %s" % [order, _card_title(definition)],
		_cost_text(definition.get("cost")),
	]
	var movement := _movement_text(definition)
	if not movement.is_empty():
		parts.append(movement)
	return " • ".join(parts)


static func _card_title(definition: Dictionary) -> String:
	var named := str(definition.get("display_name", "")).strip_edges()
	if named.is_empty():
		named = str(definition.get("id", "")).strip_edges()
	if named.is_empty():
		named = "Unknown card"
	var owner_id := str(definition.get("owner", "")).strip_edges()
	if owner_id.is_empty():
		return named
	return owner_id.capitalize() + " " + named


static func _cost_text(value: Variant) -> String:
	if value is int and int(value) >= 0:
		return "%d energy" % int(value)
	return "cost unknown"


## The authored legal slots, spelled out only when the record authors them.
static func _movement_text(definition: Dictionary) -> String:
	var parts: Array[String] = []
	var from_text := _slots_text(definition.get("from_positions"))
	if not from_text.is_empty():
		parts.append("From " + from_text)
	var to_text := _slots_text(definition.get("to_positions"))
	if not to_text.is_empty():
		parts.append("To " + to_text)
	return " • ".join(parts)


static func _slots_text(value: Variant) -> String:
	if not value is Array:
		return ""
	var parts: Array[String] = []
	for slot in value:
		parts.append(str(slot))
	return ", ".join(parts)


func _retire_callbacks() -> void:
	for button in _connections:
		if is_instance_valid(button) and button.pressed.is_connected(_connections[button]):
			button.pressed.disconnect(_connections[button])
	_connections.clear()


func _clear_choices() -> void:
	card_buttons.clear()
	_rows.clear()
	for child in choices.get_children():
		choices.remove_child(child)
		child.queue_free()


func _connect_button(button: Button, callback: Callable) -> void:
	_connections[button] = callback
	button.pressed.connect(callback)


## Display-only projection of the authenticated source for one selectable card.
## Pure: it reads the bound snapshot only and never mutates the visit, run state or RNG.
static func forecast(source: Dictionary, selected_id: String) -> Dictionary:
	var deck: Array = source.get("deck", [])
	if selected_id.is_empty() or not deck.has(selected_id):
		return {}
	var descriptors: Dictionary = source.get("descriptors", {})
	var gold := int(source.get("gold", 0))
	var price := int(source.get("price", 0))
	return {
		"card_id": selected_id,
		"first": deck.find(selected_id),
		"copies": deck.count(selected_id),
		"deck_before": deck.size(),
		"deck_after": deck.size() - 1,
		"gold_before": gold,
		"gold_after": gold - price,
		"price": price,
		"stitched": descriptors.has(selected_id),
	}


func _forecast_line() -> String:
	var projected := LiveUnpickerPanel.forecast(_source, _selected_id)
	if projected.is_empty():
		return ""
	var copies := int(projected["copies"])
	var line := "%s  •  first of %d %s  •  deck %d→%d  •  gold %d→%d (%d cost)" % [
			_card_name(_selected_id), copies, "copy" if copies == 1 else "copies",
			int(projected["deck_before"]), int(projected["deck_after"]),
			int(projected["gold_before"]), int(projected["gold_after"]), int(projected["price"])]
	if projected["stitched"]:
		line += "  •  stitched descriptor removed"
	return line


func _affordable() -> bool:
	return not _source.is_empty() and _source.has("gold") and _source.has("price") \
			and int(_source["gold"]) >= int(_source["price"])


func _status_line() -> String:
	if not _active():
		return "Visit closed or changed. No choice can be submitted."
	if not _affordable():
		return "Need %d more gold to Remove. Leave is free." % [int(_source["price"]) - int(_source["gold"])]
	if _selected_id.is_empty():
		return "Choose one card, then Remove it once. Or Leave."
	var line := _forecast_line()
	return line if not line.is_empty() else "Choose one card, then Remove it once. Or Leave."


func _update_status() -> void:
	status_label.text = _status_line()


func _refresh() -> void:
	_retire_callbacks()
	_clear_choices()
	wallet_label.text = _quote_line()
	remove_button.text = _remove_caption()
	var open := _active()
	_update_status()
	for id in _canonical_ids() if open else []:
		var first: int = (_source["deck"] as Array).find(id)
		var label_text := _caption(id)
		var button := _button(label_text, Vector2.ZERO, Vector2(784, 64))
		remove_child(button)
		choices.add_child(button)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_rows[button] = {"id": id, "first": first, "caption": label_text}
		# Read-only authored explanation; rebuilding rows on rebind replaces it.
		button.tooltip_text = LiveUnpickerPanel.card_tooltip(_source, id)
		card_buttons.append(button)
		_connect_button(button, _choose.bind(id, button, _epoch))
		button.focus_entered.connect(choice_scroll.ensure_control_visible.bind(button))
	remove_button.disabled = not _affordable() or _selected_id.is_empty() or card_buttons.is_empty()
	leave_button.disabled = not open
	if open:
		_connect_button(remove_button, _request_remove.bind(_epoch))
		_connect_button(leave_button, _request_leave.bind(_epoch))
	_wire_focus()


func _wire_focus() -> void:
	var focusables: Array[Button] = []
	for button in card_buttons + [remove_button, leave_button]:
		if not button.disabled:
			focusables.append(button)
	for i in range(focusables.size()):
		focusables[i].focus_next = focusables[i].get_path_to(focusables[(i + 1) % focusables.size()])
		focusables[i].focus_previous = focusables[i].get_path_to(focusables[(i + focusables.size() - 1) % focusables.size()])


func _honest_row(button: Button, id: String, selected: bool) -> bool:
	if not is_instance_valid(button) or not _rows.has(button):
		return false
	var row: Dictionary = _rows[button]
	if row.get("id") != id or int(row.get("first", -1)) != (_source["deck"] as Array).find(id):
		return false
	if not _canonical_ids().has(id):
		return false
	var caption: String = _caption(id)
	return row.get("caption") == caption and button.text == ("◆  " + caption if selected else caption)


func _choose(id: String, button: Button, epoch: int) -> void:
	if epoch != _epoch or not _active() or not _honest_row(button, id, button == _selected_button):
		return
	if _selected_button != null and is_instance_valid(_selected_button):
		if not _honest_row(_selected_button, _selected_id, true):
			_selected_id = ""
			_selected_button = null
			remove_button.disabled = true
			_update_status()
			return
		_selected_button.text = _caption(_selected_id)
		_selected_button.add_theme_stylebox_override("normal", _button_style(Color("#485348"), THREAD))
	_selected_id = id
	_selected_button = button
	button.text = "◆  " + _caption(id)
	button.add_theme_stylebox_override("normal", _button_style(Color("#5b6849"), GOLD))
	remove_button.disabled = int(_source["gold"]) < int(_source["price"])
	_update_status()
	_wire_focus()


func _request_remove(epoch: int) -> void:
	if epoch != _epoch or not _active() or remove_button.disabled \
			or _selected_id.is_empty() or not _honest_row(_selected_button, _selected_id, true):
		return
	if int(_source["gold"]) < int(_source["price"]):
		return
	_emit_decision("remove_card", _selected_id)


func _request_leave(epoch: int) -> void:
	if epoch != _epoch or not _active() or leave_button.disabled:
		return
	_emit_decision("leave")


func _emit_decision(action: String, card_id: String = "") -> void:
	var intent := {"action": action, "visit_id": _source["visit_id"],
			"node_id": _source["node_id"], "expected_snapshot": _source.duplicate(true)}
	if action == "remove_card":
		intent["selected_card_id"] = card_id
	_submitted = true
	remove_button.disabled = true
	leave_button.disabled = true
	_retire_callbacks()
	decision_requested.emit(intent.duplicate(true))
