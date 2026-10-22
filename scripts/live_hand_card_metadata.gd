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
var _warden_pool := WardenPoolCards.new()
var _tinker_pool := TinkerPoolCards.new()
var _seamstress_pool := SeamstressPoolCards.new()
var _targeting := CombatAttackTargeting.new()
var _stitched_preview := CombatStitchedTargetPreview.new()
var _on_hit := CombatOnHitStatuses.new()
# Key: the ACTUAL hand panel, value: original card ID, facts and signal Callables.
var _bindings: Dictionary = {}
var _app


func set_app(app) -> void:
	_app = app


func _ledger() -> RunRestStitchCards:
	return RunRestStitchCards.new(_app.run_deck, _app.run_stitch_descriptors,
		_app.run_scraps, _app.run_next_stitch_id)


func _definition(card_id: String) -> Dictionary:
	var move := M02PositionCards.new().get_definition(card_id)
	if not move.is_empty():
		return move
	var starter := _catalog.get_definition(card_id)
	if not starter.is_empty():
		return starter
	# Reward-pool records are a separate authored catalog; lookup stays read-only.
	var warden_definition := _warden_pool.get_definition(card_id)
	if not warden_definition.is_empty():
		return warden_definition
	# Only the playable energy utilities, Spare Parts and Sight Glass are
	# advertised; all other Tinker/Seamstress pool records remain unknown.
	if CombatPoolEnergyCards.SUPPORTED_IDS.has(card_id) or card_id in [
			"tinker_spare_parts", "tinker_spare_parts_plus",
			"tinker_sight_glass", "tinker_sight_glass_plus"]:
		if card_id.begins_with("tinker_"):
			var tinker_definition := _tinker_pool.get_definition(card_id)
			if not tinker_definition.is_empty():
				return tinker_definition
		elif card_id.begins_with("seamstress_"):
			var seamstress_definition := _seamstress_pool.get_definition(card_id)
			if not seamstress_definition.is_empty():
				return seamstress_definition
	return {}


## Public read-only lookup shared by the mounted hand admission checks.
func definition(card_id: String) -> Dictionary:
	return _definition(card_id)


func base_effect_text(card_id: String) -> String:
	var definition: Dictionary = _definition(card_id)
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
		"party_all":
			target_text = "All living heroes"
		"none":
			target_text = "No target"
		_:
			target_text = "Unknown target"
	# Describe only effects backed by the real confirmed-hit adapter; an
	# authored counter by itself is not a promise of an applied status.
	var from_text: String = describe(card_id).get("from_text", "From ?")
	var effect_parts: Array[String] = []
	if definition.get("action_kind") == "adjacent_swap":
		effect_parts.append("Swap with the living adjacent ally %s" % ("behind" if definition.direction == 1 else "ahead"))
	if effects.has("damage"):
		effect_parts.append("BASE deal %d damage" % int(effects["damage"]))
	if effects.has("block"):
		effect_parts.append("BASE gain %d Block" % int(effects["block"]))
	# Hold the Line and Bastion Quilt pay other recipients too; never hide them.
	if effects.has("other_ally_block"):
		effect_parts.append("BASE each other living ally gains %d Block" % int(effects["other_ally_block"]))
	if effects.has("block_all"):
		effect_parts.append("BASE each living hero gains %d Block" % int(effects["block_all"]))
	if effects.has("heal"):
		effect_parts.append("BASE heal %d HP, capped at max HP" % int(effects["heal"]))
	if effects.has("exposed") and card_id in ["tinker_sight_glass", "tinker_sight_glass_plus"]:
		effect_parts.append("Apply Exposed %d to the selected enemy" % int(effects["exposed"]))
	if effects.has("draw"):
		effect_parts.append("BASE draw %d card" % int(effects["draw"]))
	if effects.has("gain_energy"):
		effect_parts.append("BASE gain %d energy" % int(effects["gain_energy"]))
	if effects.has("energy") and not effects.has("gain_energy"):
		effect_parts.append("BASE gain %d energy" % int(effects["energy"]))
	if effects.has("self_hp_loss"):
		effect_parts.append("BASE self-damage %d" % int(effects["self_hp_loss"]))
	var on_hit := CombatOnHitStatuses.new().status_for_confirmed_hit(card_id, true)
	for status in ["bleed", "weak"]:
		if not on_hit.has(status):
			continue
		var addition: int = on_hit[status]
		var rule := "ON CONFIRMED HIT add %s %d" % [status.capitalize(), addition]
		if status == "bleed" and owner == "seamstress":
			var authored: int = int(effects.get("bleed", 0))
			rule += " (authored Bleed %d + Seamstress passive %d)" % [authored, addition - authored]
		effect_parts.append(rule)
	var parts: Array[String] = ["%s; %s; %d energy" % [display_name, owner.capitalize(), cost], from_text]
	if target_text != "No target" and target_text != "Unknown target" and not target_text.is_empty():
		parts.append(target_text)
	elif target_text == "No target":
		parts.append("No target")
	if effect_parts.size() > 0:
		parts.append("; ".join(effect_parts))
	return "\n".join(parts)


## The complete two-part tooltip for a stitched card. Each half is named from
## its authored catalog definition, so an upgraded half keeps its "+" name.
func stitched_tooltip(halves: Array) -> String:
	if halves.size() != 2:
		return ""
	return "1. " + base_effect_text(str(halves[0])) + "\n2. " + base_effect_text(str(halves[1]))


func describe(card_id: String) -> Dictionary:
	var definition: Dictionary = _definition(card_id)
	if _app != null and card_id.begins_with(RunRestStitchCards.ID_PREFIX):
		var ledger := _ledger()
		if ledger.is_valid() and ledger.get_snapshot() == _app._stitch_snapshot():
			definition = ledger.get_snapshot().descriptors.get(card_id, {})
			if not definition.is_empty():
				return {"id": card_id, "known": true, "owner": "", "owner_text": "Stitched", "cost": definition.cost, "cost_text": "Cost %d" % definition.cost, "from_text": "Ordered halves", "target_text": "Independent targets", "halves": definition.half_ids.duplicate()}
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
		"party_all":
			target_text = "All living heroes"
		"none":
			target_text = "No target"
		"adjacent_ally":
			target_text = "Swap with ally " + ("behind" if definition.direction == 1 else "ahead")
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
		if _bindings.has(panel) and _bindings[panel]["id"] == card_id and _bindings[panel].facts == describe(card_id):
			_update_visual(panel)
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
	panel.get_child(0).hide()
	panel.tooltip_text = base_effect_text(card_id)
	var halves: Array = _bindings[panel].facts.get("halves", [])
	if halves.size() == 2:
		panel.tooltip_text = stitched_tooltip(halves)
	_update_visual(panel)
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
		if panel.get_child_count() > 0:
			panel.get_child(0).show()
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
	return card_layout(panel.size)


## Single source of truth for the drawn card. Mounted tests check these rects
## stay inside the real panel; the renderer draws exactly these regions.
func card_layout(size: Vector2) -> Dictionary:
	if size.x < 88.0 or size.y < 30.0:
		return {}
	var compact := size.y < 120.0
	var frame := Rect2(2, 2, size.x - 4, size.y - 4)
	var inset := 6.0
	var cost_side := 24.0 if compact else 30.0
	var cost := Rect2(size.x - inset - cost_side, inset, cost_side, cost_side)
	var stripe := Rect2(inset, inset + 2, 5, frame.size.y - (inset + 2) * 2)
	var text_x := stripe.end.x + 3.0
	var text_width := maxf(24.0, cost.position.x - text_x - 4.0)
	var owner := Rect2(text_x, inset + (2.0 if compact else 3.0), text_width, 12.0)
	var title := Rect2(text_x, owner.end.y + 1.0, text_width, 16.0 if compact else 20.0)
	var body_top := title.end.y + 2.0
	var body := Rect2(text_x, body_top, maxf(24.0, size.x - text_x - inset), frame.end.y - inset - body_top)
	# Both faces reserve one row per ordered half: the compact hand gets two short
	# sewn rows, taller panels keep the detailed three-line halves.
	var halves: Array[Rect2] = []
	var gap := 4.0 if compact else 6.0
	var each := floorf((body.size.y - gap) / 2.0)
	if each >= (20.0 if compact else 30.0):
		halves = [Rect2(body.position, Vector2(body.size.x, each)),
			Rect2(body.position + Vector2(0, each + gap), Vector2(body.size.x, each))]
	return {"compact": compact, "frame": frame, "stripe": stripe, "owner": owner,
		"cost": cost, "title": title, "footer": body, "halves": halves}


func _owner_color(owner: String) -> Color:
	match owner:
		"warden":
			return WARDEN
		"seamstress":
			return SEAMSTRESS
		"tinker":
			return TINKER
	return INK


## Presentation-only view of what the current live state allows. Read by the
## renderer and by mounted tests; it never mutates a combat model.
func visual_state(panel) -> Dictionary:
	if not _bindings.has(panel):
		return {}
	var visual: Array = _bindings[panel].get("visual", [false, false, Vector2.ZERO, false])
	return {"playable": bool(visual[0]), "hovered": bool(visual[1]),
		"aim": visual[2] if visual[2] is Vector2 else Vector2.ZERO, "aiming": bool(visual[3])}


func _update_visual(panel: Control) -> void:
	var playable := false
	var id: String = _bindings[panel].id
	if _app != null and _app.deck != null and _app.party != null and _app.enemies != null:
		if id in CombatAttackTargeting.ATTACK_IDS or _targeting.is_sight_glass(id):
			playable = bool(_targeting.get_preview(_app.deck, _app.party, _app.enemies, id).get("playable", false))
		elif id.begins_with(RunRestStitchCards.ID_PREFIX):
			playable = bool(_stitched_preview.get_preview(_ledger(), _app._stitch_snapshot(), _app.deck, _app.party, _app.enemies, id).get("playable", false))
		elif id in M02PositionCards.IDS:
			var move := _definition(id)
			playable = _app.deck.turn_active and _app.deck.energy >= int(move.get("cost", -1)) \
				and _owner_position(move.get("owner", "")) in move.get("from_positions", []) \
				and CombatPositionSwaps.preview_adjacent_swap(_app.party, _owner_position(move.get("owner", "")), move.get("direction", 0)).get("ok", false)
		else:
			var support := _definition(id)
			var position := _owner_position(support.get("owner", ""))
			playable = not support.is_empty() and _app.deck.turn_active and _app.deck.energy >= int(support.get("cost", -1)) \
				and position in support.get("from_positions", []) and not _app.party.is_downed(position)
	var hovered := false
	var viewport := panel.get_viewport()
	if viewport != null:
		# The viewport's GUI hover is the same state that routes real mouse
		# motion (and is deterministic under a pushed event in tests).
		var under: Control = viewport.gui_get_hovered_control()
		hovered = under == panel or (under != null and panel.is_ancestor_of(under))
	var aiming := bool(panel.get_meta("aiming", false))
	var aim: Vector2 = panel.get_meta("aim_point", Vector2.ZERO) if aiming else Vector2.ZERO
	var visual := [playable, hovered, aim, aiming]
	panel.self_modulate = Color.WHITE if playable or _app == null else Color(0.72, 0.70, 0.68)
	panel.z_index = 3 if hovered or aiming else 0
	if _bindings[panel].get("visual", []) != visual:
		_bindings[panel].visual = visual
		panel.queue_redraw()


func _owner_position(owner: String) -> int:
	for hero in _app.party.get_heroes():
		if hero.id == owner:
			return hero.position
	return 0


func _fit(font: Font, value: String, available: float, preferred: int) -> int:
	var point_size := preferred
	while point_size > 8 and font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, point_size).x > available:
		point_size -= 1
	return point_size


func _font(panel: Control) -> Font:
	var font: Font = panel.get_theme_default_font()
	return font if font != null else ThemeDB.fallback_font


func _text(panel: Control, value: String, rect: Rect2, preferred: int, color: Color = INK) -> void:
	if value.is_empty() or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var font := _font(panel)
	var point_size := _fit(font, value, rect.size.x, preferred)
	panel.draw_string(font, rect.position + Vector2(0, minf(float(point_size), rect.size.y)),
		value, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, point_size, color)


func _center_text(panel: Control, value: String, rect: Rect2, preferred: int) -> void:
	var font := _font(panel)
	var point_size := _fit(font, value, rect.size.x - 4.0, preferred)
	panel.draw_string(font, rect.position + Vector2(0, rect.size.y * 0.5 + float(point_size) * 0.36),
		value, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, point_size, INK)


## Human-readable rules from the authored effect fields plus the real
## confirmed-hit adapter; no resolved or promised value is invented.
func _rules(id: String) -> String:
	var definition := _definition(id)
	if definition.is_empty():
		return ""
	var effects: Dictionary = definition.get("effects", {}) if definition.get("effects", {}) is Dictionary else {}
	var parts: PackedStringArray = []
	if effects.has("damage"):
		parts.append("%d damage" % int(effects["damage"]))
	if effects.has("block"):
		parts.append("%d Block" % int(effects["block"]))
	if effects.has("other_ally_block"):
		parts.append("%d Block to other living allies" % int(effects["other_ally_block"]))
	if effects.has("block_all"):
		parts.append("%d Block to all living heroes" % int(effects["block_all"]))
	if effects.has("heal"):
		parts.append("heal %d HP" % int(effects["heal"]))
	if effects.has("exposed") and id in ["tinker_sight_glass", "tinker_sight_glass_plus"]:
		parts.append("apply Exposed %d" % int(effects["exposed"]))
	if effects.has("draw"):
		parts.append("draw %d card" % int(effects["draw"]))
	if effects.has("gain_energy"):
		parts.append("gain %d energy" % int(effects["gain_energy"]))
	if effects.has("energy") and not effects.has("gain_energy"):
		parts.append("gain %d energy" % int(effects["energy"]))
	if effects.has("self_hp_loss"):
		parts.append("self-damage %d" % int(effects["self_hp_loss"]))
	var statuses: Dictionary = _on_hit.status_for_confirmed_hit(id, true)
	for status in ["bleed", "weak"]:
		if statuses.has(status):
			parts.append("%d %s on hit" % [int(statuses[status]), status.capitalize()])
	return ", ".join(parts)


## Filled felt pips mark authored source slots; outlined squares mark authored
## legal target slots. Decoration only, never an input or rules authority.
func _draw_pips(panel: Control, facts: Dictionary, rect: Rect2) -> void:
	var definition := _definition(facts.get("id", ""))
	var from_positions: Array = definition.get("from_positions", [])
	var to_positions: Array = definition.get("to_positions", [])
	if from_positions.is_empty() and to_positions.is_empty():
		return
	var step := 7.0
	var radius := 2.0
	var x: float = rect.end.x - step * 5.0 - 4.0
	var y: float = rect.position.y + rect.size.y * 0.5
	for index in range(1, 4):
		var center := Vector2(x + step * (index - 1), y)
		if from_positions.has(index):
			panel.draw_circle(center, radius, _owner_color(facts.get("owner", "")))
		else:
			panel.draw_arc(center, radius, 0.0, TAU, 12, RUST, 1.0, true)
	for index in range(1, 4):
		var center := Vector2(x + step * (2 + index) + 5.0, y)
		if to_positions.has(index):
			panel.draw_rect(Rect2(center - Vector2(radius, radius), Vector2.ONE * radius * 2.0), INK, true)
		else:
			panel.draw_rect(Rect2(center - Vector2(radius, radius), Vector2.ONE * radius * 2.0), RUST, false, 1.0)


## One authored half (or a whole ordinary card): owner colour, fitted name,
## source/target rules and effect line. Ordered halves pass a "1." prefix.
func _draw_half(panel: Control, id: String, rect: Rect2, order: String = "") -> void:
	var facts := describe(id)
	var definition := _definition(id)
	var owner_color := _owner_color(facts.get("owner", ""))
	var x: float = rect.position.x
	var width: float = rect.size.x
	if order.is_empty():
		_text(panel, facts.get("from_text", ""), Rect2(x, rect.position.y, width - 60.0, 12), 10, RUST)
		_draw_pips(panel, facts, Rect2(x, rect.position.y, width, 12))
		_text(panel, facts.get("target_text", ""), Rect2(x, rect.position.y + 16.0, width, 13), 11)
		var rules := _rules(id)
		if not rules.is_empty():
			_text(panel, rules, Rect2(x, rect.position.y + 34.0, width, 15), 12)
		return
	panel.draw_rect(Rect2(x - 3.0, rect.position.y + 1.0, 3, rect.size.y - 2.0), owner_color)
	_text(panel, order + definition.get("display_name", id), Rect2(x, rect.position.y, width, 14), 13)
	_text(panel, facts.get("owner_text", "") + " | " + facts.get("from_text", ""),
		Rect2(x, rect.position.y + 14.0, width - 44.0, 11), 9, owner_color)
	_draw_pips(panel, facts, Rect2(x, rect.position.y + 14.0, width, 11))
	var detail: String = facts.get("target_text", "")
	var rules := _rules(id)
	if not rules.is_empty():
		detail = rules if detail.is_empty() else "%s · %s" % [detail, rules]
	_text(panel, detail, Rect2(x, rect.position.y + 27.0, width, 12), 10)


## True only when both ledger halves are real authored definitions; an unknown
## half must fall back to the honest placeholder instead of invented rules.
func _halves_known(pair: Array) -> bool:
	if pair.size() != 2:
		return false
	return not _definition(str(pair[0])).is_empty() and not _definition(str(pair[1])).is_empty()


## One short sewn row of a compact stitched card: the authored half name in
## resolution order plus that half's own owner colour and label.
func _draw_sewn_half(panel: Control, id: String, rect: Rect2, order: int) -> void:
	var facts := describe(id)
	var definition := _definition(id)
	if definition.is_empty() or rect.size.y <= 12.0:
		return
	var owner_color := _owner_color(facts.get("owner", ""))
	panel.draw_rect(Rect2(rect.position.x - 3.0, rect.position.y + 1.0, 3.0, rect.size.y - 2.0), owner_color)
	_text(panel, "%d. %s" % [order, definition.get("display_name", id)],
		Rect2(rect.position, Vector2(rect.size.x, minf(14.0, rect.size.y))), 11)
	_text(panel, facts.get("owner_text", ""),
		Rect2(rect.position.x, rect.position.y + 12.0, rect.size.x, maxf(6.0, rect.size.y - 12.0)), 9, owner_color)


func _title(facts: Dictionary) -> String:
	var definition := _definition(facts.get("id", ""))
	if not definition.is_empty():
		return definition.get("display_name", facts.get("id", ""))
	var names: PackedStringArray = []
	for half in facts.get("halves", []):
		var authored := _definition(half)
		names.append(authored.get("display_name", str(half)))
	return " + ".join(names) if not names.is_empty() else "Unknown card"


func _draw_panel(panel: Control) -> void:
	if not _bindings.has(panel) or not is_instance_valid(panel):
		return
	var facts: Dictionary = _bindings[panel].facts
	var visual := visual_state(panel)
	var layout := card_layout(panel.size)
	if layout.is_empty():
		return
	# Hover (or an armed drag) lifts the drawn card and enlarges it around its
	# centre. Only the drawing transforms: the panel hitbox, layout and input
	# stay untouched.
	var raised: bool = visual["hovered"] or visual["aiming"]
	var grow := 1.04 if raised else 1.0
	var lift := -6.0 if visual["hovered"] else 0.0
	var centre: Vector2 = panel.size * 0.5
	panel.draw_set_transform(centre * (1.0 - grow) + Vector2(0, lift), 0.0, Vector2(grow, grow))
	var frame: Rect2 = layout["frame"]
	panel.draw_rect(frame, CREAM)
	panel.draw_rect(frame, RUST, false, 2.0)
	panel.draw_dashed_line(frame.position + Vector2(5, 5),
		Vector2(frame.end.x - 5.0, frame.position.y + 5.0), RUST, 1.0, 5.0)
	panel.draw_dashed_line(Vector2(frame.position.x + 5.0, frame.end.y - 5.0),
		frame.end - Vector2(5, 5), RUST, 1.0, 5.0)
	panel.draw_rect(layout["stripe"], _owner_color(facts.get("owner", "")))
	var cost: Rect2 = layout["cost"]
	panel.draw_circle(cost.get_center(), cost.size.x * 0.5, TINKER)
	panel.draw_arc(cost.get_center(), cost.size.x * 0.5 - 1.5, 0.0, TAU, 24, CREAM, 1.5, true)
	_center_text(panel, str(facts.get("cost", -1)) if int(facts.get("cost", -1)) >= 0 else "?",
		cost, 14 if not layout["compact"] else 12)
	_text(panel, facts.get("owner_text", ""), layout["owner"], 11, _owner_color(facts.get("owner", "")))
	_text(panel, _title(facts), layout["title"], 15 if not layout["compact"] else 13)
	var halves: Array = layout["halves"]
	var pair: Array = facts.get("halves", [])
	if halves.size() == 2 and _halves_known(pair):
		for index in range(2):
			if layout["compact"]:
				_draw_sewn_half(panel, str(pair[index]), halves[index], index + 1)
			else:
				_draw_half(panel, str(pair[index]), halves[index], "%d. " % (index + 1))
		panel.draw_dashed_line(Vector2(halves[1].position.x, halves[0].end.y + 3.0),
			Vector2(halves[1].end.x, halves[0].end.y + 3.0), RUST, 1.0, 5.0)
	else:
		_draw_half(panel, _bindings[panel].id, layout["footer"])
	panel.draw_set_transform(Vector2.ZERO)
	if visual["aiming"]:
		var start := Vector2(panel.size.x * 0.5, 0)
		var end: Vector2 = panel.get_global_transform().affine_inverse() * visual["aim"]
		var direction := (end - start).normalized()
		if direction != Vector2.ZERO:
			panel.draw_line(start, end, TINKER, 3.0, true)
			panel.draw_colored_polygon(PackedVector2Array([end,
				end - direction.rotated(0.45) * 14.0, end - direction.rotated(-0.45) * 14.0]), TINKER)
	_bindings[panel].draw_count = int(_bindings[panel].draw_count) + 1
