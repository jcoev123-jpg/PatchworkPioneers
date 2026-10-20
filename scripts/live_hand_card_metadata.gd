extends RefCounted
## Read-only, per-panel CanvasItem decoration for the real shared combat hand.
## Never adds Controls, changes input/focus, or touches any combat model.

const WARDEN := Color("#4a5d73")
const SEAMSTRESS := Color("#6e4f6b")
const TINKER := Color("#c49a3a")
const CREAM := Color("#ece0c8")
const RUST := Color("#9e6f58")
const INK := Color("#3d3440")

var _catalog := StarterCards.new()
# Key: the ACTUAL hand panel, value: original card ID, facts and signal Callables.
var _bindings: Dictionary = {}


func base_effect_text(card_id: String) -> String:
	var definition: Dictionary = _catalog.get_definition(card_id)
	if definition.is_empty():
		return "Unknown card"
	var display_name: String = definition.get("display_name", card_id)
	var owner: String = definition.get("owner", "")
	var cost: int = int(definition.get("cost", -1))
	var effects: Dictionary = definition.get("effects", {})
	# Derive complete target description from catalog target_kind and positions.
	var target_kind: String = definition.get("target_kind", "")
	var to_positions: Array = definition.get("to_positions", [])
	var target_text := ""
	match target_kind:
		"enemy_single":
			target_text = "To one selected enemy"
			if not to_positions.is_empty():
				target_text += " " + _positions(to_positions)
		"enemy_all":
			target_text = "All enemies"
			if not to_positions.is_empty():
				target_text += " " + _positions(to_positions)
		"self":
			target_text = "Self"
		"ally_single":
			target_text = "Choose one living ally"
		"none":
			target_text = "No target"
		_:
			target_text = "Unknown target"
	# M01: leave Weak/Bleed for M02 live persistence.
	var from_text: String = describe(card_id).get("from_text", "From ?")
	var effect_parts: Array[String] = []
	if effects.has("damage"):
		effect_parts.append("BASE deal %d damage" % int(effects["damage"]))
	if effects.has("block"):
		effect_parts.append("BASE gain %d Block" % int(effects["block"]))
	if effects.has("heal"):
		effect_parts.append("BASE heal %d HP, capped at max HP" % int(effects["heal"]))
	if effects.has("draw"):
		effect_parts.append("BASE draw %d card" % int(effects["draw"]))
	var parts: Array[String] = ["%s; %s; %d energy" % [display_name, owner.capitalize(), cost], from_text]
	if target_text != "No target" and target_text != "Unknown target" and not target_text.is_empty():
		parts.append(target_text)
	elif target_text == "No target":
		parts.append("No target")
	if effect_parts.size() > 0:
		parts.append("; ".join(effect_parts))
	return "\n".join(parts)


func describe(card_id: String) -> Dictionary:
	var definition: Dictionary = _catalog.get_definition(card_id)
	if definition.is_empty():
		return {
			"id": card_id, "known": false, "owner": "", "owner_text": "Unknown",
			"cost_text": "Cost ?", "from_text": "Rules unknown",
			"target_text": "", "cost": -1,
		}
	var owner: String = definition.get("owner", "")
	var from_positions: Array = definition.get("from_positions", [])
	var to_positions: Array = definition.get("to_positions", [])
	var target_kind: String = definition.get("target_kind", "")
	var target_text := "Unknown target"
	match target_kind:
		"enemy_single":
			target_text = "To enemy " + _positions(to_positions)
		"enemy_all":
			target_text = "All enemies " + _positions(to_positions)
		"self":
			target_text = "Self"
		"ally_single":
			target_text = "Ally"
		"none":
			target_text = "No target"
	return {
		"id": card_id, "known": true, "owner": owner,
		"owner_text": owner.capitalize(), "cost": int(definition.get("cost", -1)),
		"cost_text": "Cost %d" % int(definition.get("cost", -1)),
		"from_text": "From " + _positions(from_positions),
		"target_text": target_text,
	}


func _positions(positions: Array) -> String:
	if positions.is_empty():
		return "?"
	var values: Array[String] = []
	for position in positions:
		values.append(str(position))
	# Authored ranges are contiguous today, but do not claim holes are legal.
	var contiguous := true
	for index in range(1, positions.size()):
		if int(positions[index]) != int(positions[index - 1]) + 1:
			contiguous = false
	if contiguous and positions.size() > 1:
		return "%s–%s" % [values.front(), values.back()]
	return ",".join(values)


func sync(panels: Array[Node], hand: Array[String]) -> void:
	var current := {}
	for index in range(mini(panels.size(), hand.size())):
		var panel := panels[index] as Control
		if not is_instance_valid(panel) or panel.get_child_count() < 1:
			continue
		var label := panel.get_child(0) as Label
		# Both the hand order and the untouched FIRST label must agree.
		if label == null or label.text != hand[index]:
			continue
		current[panel] = true
		var card_id: String = label.text
		if _bindings.has(panel) and _bindings[panel]["id"] == card_id:
			continue
		_unbind(panel)
		_bind(panel, card_id)
	for panel in _bindings.keys():
		if not is_instance_valid(panel) or not current.has(panel):
			_unbind(panel)


func _bind(panel: Control, card_id: String) -> void:
	var draw_callback := _draw_panel.bind(panel)
	var resize_callback := _resized.bind(panel)
	var exit_callback := _panel_exiting.bind(panel)
	var original_tooltip: String = ""
	if is_instance_valid(panel):
		original_tooltip = panel.tooltip_text
	_bindings[panel] = {
		"id": card_id, "facts": describe(card_id), "draw": draw_callback,
		"resize": resize_callback, "exit": exit_callback, "draw_count": 0,
		"original_tooltip": original_tooltip,
	}
	panel.tooltip_text = base_effect_text(card_id)
	panel.draw.connect(draw_callback)
	panel.resized.connect(resize_callback)
	panel.tree_exiting.connect(exit_callback)
	panel.queue_redraw()


func _resized(panel: Control) -> void:
	if _bindings.has(panel) and is_instance_valid(panel):
		panel.queue_redraw()


func _panel_exiting(panel: Control) -> void:
	_unbind(panel)


func _unbind(panel) -> void:
	if not _bindings.has(panel):
		return
	var binding: Dictionary = _bindings[panel]
	if is_instance_valid(panel):
		if panel.draw.is_connected(binding["draw"]):
			panel.draw.disconnect(binding["draw"])
		if panel.resized.is_connected(binding["resize"]):
			panel.resized.disconnect(binding["resize"])
		if panel.tree_exiting.is_connected(binding["exit"]):
			panel.tree_exiting.disconnect(binding["exit"])
		# Restore original tooltip so unbind/rebind is clean.
		if binding.has("original_tooltip"):
			panel.tooltip_text = binding.get("original_tooltip", "")
	_bindings.erase(panel)


func clear() -> void:
	for panel in _bindings.keys():
		_unbind(panel)


func get_facts(panel: Control) -> Dictionary:
	if not _bindings.has(panel):
		return {}
	return _bindings[panel]["facts"].duplicate(true)


func get_geometry(panel: Control) -> Dictionary:
	if not _bindings.has(panel) or not is_instance_valid(panel):
		return {}
	return _geometry(panel.size)


func _geometry(size: Vector2) -> Dictionary:
	var width := size.x
	var height := size.y
	if width < 88.0 or height < 30.0:
		return {}
	# Non-support hands can measure just 34px high. Keep that hitbox:
	# compact cards use one sewn rules line below the untouched center ID.
	var compact := height < 68.0
	var margin := 4.0
	var cost_width := 52.0
	var header_height := 11.0 if compact else 22.0
	var footer_height := 12.0 if compact else 39.0
	var header_y := 1.0 if compact else margin
	var footer_y := height - footer_height - (1.0 if compact else margin)
	return {
		"compact": compact,
		"owner": Rect2(margin, header_y, width - cost_width - margin * 3.0, header_height),
		"cost": Rect2(width - cost_width - margin, header_y, cost_width, header_height),
		"footer": Rect2(margin, footer_y, width - margin * 2.0, footer_height),
	}


func _owner_color(owner: String) -> Color:
	match owner:
		"warden":
			return WARDEN
		"seamstress":
			return SEAMSTRESS
		"tinker":
			return TINKER
	return INK


func _fit(font: Font, value: String, available: float, preferred: int) -> int:
	var point_size := preferred
	while point_size > 8 and font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, point_size).x > available:
		point_size -= 1
	return point_size


func _draw_panel(panel: Control) -> void:
	if not _bindings.has(panel) or not is_instance_valid(panel):
		return
	var geometry := _geometry(panel.size)
	if geometry.is_empty():
		return
	var facts: Dictionary = _bindings[panel]["facts"]
	var owner_rect: Rect2 = geometry["owner"]
	var cost_rect: Rect2 = geometry["cost"]
	var footer_rect: Rect2 = geometry["footer"]
	var font: Font = panel.get_theme_default_font()
	if font == null:
		font = ThemeDB.fallback_font
	var owner_color := _owner_color(facts["owner"])
	var owner_ink := CREAM
	var owner_label: String = facts["owner_text"]
	var cost_label: String = facts["cost_text"]
	# The felt owner tag, paper energy chip, and bottom rule strip never leave
	# the panel rect and never intercept input.
	panel.draw_rect(owner_rect, owner_color)
	panel.draw_rect(cost_rect, CREAM)
	panel.draw_rect(footer_rect, CREAM)
	panel.draw_rect(Rect2(footer_rect.position, Vector2(footer_rect.size.x, 2)), RUST)
	var compact: bool = geometry["compact"]
	var baseline := 9.0 if compact else 15.0
	var owner_size := _fit(font, owner_label, owner_rect.size.x - 8, 10 if compact else 12)
	var cost_size := _fit(font, cost_label, cost_rect.size.x - 6, 9 if compact else 11)
	panel.draw_string(font, owner_rect.position + Vector2(6, baseline), owner_label,
		HORIZONTAL_ALIGNMENT_LEFT, owner_rect.size.x - 8, owner_size, owner_ink)
	panel.draw_string(font, cost_rect.position + Vector2(4, baseline), cost_label,
		HORIZONTAL_ALIGNMENT_LEFT, cost_rect.size.x - 6, cost_size, INK)
	var from_text: String = facts["from_text"]
	var target_text: String = facts["target_text"]
	var line_width: float = footer_rect.size.x - 13.0
	if compact:
		var combined := from_text
		if not target_text.is_empty():
			combined += " • " + target_text
		var rules_size := _fit(font, combined, line_width, 9)
		panel.draw_string(font, footer_rect.position + Vector2(8, 10), combined,
			HORIZONTAL_ALIGNMENT_LEFT, line_width, rules_size, INK)
	else:
		var from_size := _fit(font, from_text, line_width, 12)
		panel.draw_string(font, footer_rect.position + Vector2(8, 16), from_text,
			HORIZONTAL_ALIGNMENT_LEFT, line_width, from_size, INK)
		if not target_text.is_empty():
			var target_size := _fit(font, target_text, line_width, 12)
			panel.draw_string(font, footer_rect.position + Vector2(8, 31), target_text,
				HORIZONTAL_ALIGNMENT_LEFT, line_width, target_size, INK)
	# Tiny stitches and a felt button/pip inside the footer margin.
	for index in range(3):
		var px := footer_rect.end.x - 19.0 + float(index * 5)
		panel.draw_line(Vector2(px, footer_rect.position.y + 3),
			Vector2(px + 2, footer_rect.position.y + 6), RUST, 1.0)
	panel.draw_circle(owner_rect.position + Vector2(owner_rect.size.x - 5, 5), 2.0, CREAM)
	_bindings[panel]["draw_count"] = int(_bindings[panel]["draw_count"]) + 1
