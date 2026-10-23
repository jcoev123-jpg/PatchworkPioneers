extends RefCounted
## Read-only, per-panel CanvasItem decoration for the real shared combat hand.
## Never adds Controls, changes input/focus, or touches any combat model.

const WARDEN := Color("#4a5d73")
const SEAMSTRESS := Color("#6e4f6b")
const TINKER := Color("#c49a3a")
const CREAM := Color("#ece0c8")
const RUST := Color("#9e6f58")
const INK := Color("#3d3440")
## Every effect key this display formatter understands. Anything else stays
## undescribed and is flagged honestly instead of being interpreted as a number.
const KNOWN_EFFECT_KEYS := [
	"damage", "hits", "hit_count", "block", "other_ally_block", "block_all",
	"heal", "exposed", "weak", "bleed", "unravel", "bleed_multiplier", "pinned",
	"guarding", "thorns", "draw", "energy", "gain_energy", "self_hp_loss",
	"conditional_damage", "random_target_each_hit", "rng_source",
	"living_targets_only", "duration",
]
## Plain-text keyword reminders appended to the tooltip (never the card face)
## for authored cards that actually carry the mechanic. They explain only the
## published rule; no card is shown as automatically pinning or unravelling.
const PINNED_EXPLANATION := "PINNED: one pin per enemy, storing the hero who applied it. A DIFFERENT hero's next attack deals +5 damage BEFORE Weak/Exposed and consumes it once; same-hero attacks do not. A new pin replaces it; an unused pin lasts to combat end."
const UNRAVEL_EXPLANATION := "UNRAVEL: an Unravel N adds N to that enemy's gauge and each Bleed tick adds 1. At the normal 8 / elite 12 / boss 16 threshold the enemy becomes Unravelled and skips its next enemy action; the gauge then resets to 0 and its threshold rises by 4 for the rest of combat."

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


## Authored display knowledge only. Starter and movement records keep priority,
## then every reward-pool record (base and '+' upgrade) is a verified catalog
## lookup. Whether a recognized card may be played is a separate live decision
## made by the mounted presenters (see _wired); an unknown ID stays unknown.
func _definition(card_id: String) -> Dictionary:
	var move := M02PositionCards.new().get_definition(card_id)
	if not move.is_empty():
		return move
	var starter := _catalog.get_definition(card_id)
	if not starter.is_empty():
		return starter
	var warden_definition := _warden_pool.get_definition(card_id)
	if not warden_definition.is_empty():
		return warden_definition
	var seamstress_definition := _seamstress_pool.get_definition(card_id)
	if not seamstress_definition.is_empty():
		return seamstress_definition
	return _tinker_pool.get_definition(card_id)


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
	var from_text: String = describe(card_id).get("from_text", "From ?")
	var parts: Array[String] = ["%s; %s; %d energy" % [display_name, owner.capitalize(), cost], from_text]
	var target_text: String = _target_text(definition, true)
	if target_text == "No target":
		parts.append("No target")
	elif not target_text.is_empty() and target_text != "Unknown target":
		parts.append(target_text)
	var effect_parts: Array[String] = _effect_lines(card_id, definition, true)
	if not effect_parts.is_empty():
		parts.append("; ".join(effect_parts))
	for keyword_line in _keyword_lines(definition):
		parts.append(keyword_line)
	return "\n".join(parts)


## One catalog-derived target sentence for both the compact badge line and the
## precise tooltip. A target kind this formatter does not know stays "Unknown
## target" rather than guessing at legal recipients.
func _target_text(definition: Dictionary, precise: bool) -> String:
	var target_kind: String = str(definition.get("target_kind", ""))
	var to_positions: Array = definition.get("to_positions", [])
	var positions: String = _positions(to_positions)
	match target_kind:
		"enemy_single":
			return ("To one selected enemy " if precise else "To enemy ") + positions
		"enemy_all":
			return "All enemies " + positions
		"enemy_random":
			if precise:
				return "A random living enemy per hit (%s)" % positions
			return "Random enemy " + positions
		"self":
			return "Self"
		"ally_single":
			return "Choose one living ally" if precise else "Ally"
		"party_all":
			return "All living heroes"
		"adjacent_ally":
			var behind: bool = int(definition.get("direction", 0)) == 1
			if precise:
				return "Swap with the living adjacent ally %s" % ("behind" if behind else "ahead")
			return "Swap with ally " + ("behind" if behind else "ahead")
		"none":
			return "No target"
	return "Unknown target"


## The authored recipient phrase used by effect sentences; never a promise about
## a card whose target kind is unrecognized.
func _recipient(definition: Dictionary) -> String:
	match str(definition.get("target_kind", "")):
		"enemy_all":
			return "each living enemy"
		"enemy_random":
			return "the struck enemy"
		"party_all":
			return "each living hero"
		"ally_single":
			return "the chosen ally"
		"self":
			return "this hero"
	return "the target"


## Authored effect sentences, short on the card face and precise in the tooltip.
## No resolution is predicted: only catalog fields and the real confirmed-hit
## starter adapter are described, and any unrecognized effect key is flagged
## instead of being rendered as an invented value.
func _effect_lines(card_id: String, definition: Dictionary, precise: bool) -> Array[String]:
	var parts: Array[String] = []
	var raw_effects: Variant = definition.get("effects", {})
	var effects: Dictionary = raw_effects if raw_effects is Dictionary else {}
	var recipient: String = _recipient(definition)
	if definition.get("action_kind") == "adjacent_swap":
		parts.append("Swap with the living adjacent ally %s" % ("behind" if int(definition.get("direction", 0)) == 1 else "ahead"))
	if effects.has("damage"):
		var damage: int = int(effects["damage"])
		var hits: int = int(effects.get("hits", effects.get("hit_count", 1)))
		if precise:
			var line := "BASE deal %d damage" % damage
			if hits > 1:
				line += " in %d hits" % hits
			parts.append(line)
		else:
			var line := "%d dmg" % damage
			if hits > 1:
				line += " x%d" % hits
			parts.append(line)
	if bool(effects.get("random_target_each_hit", false)):
		parts.append("BASE each hit picks a random living enemy" if precise else "random each hit")
	if effects.has("block"):
		parts.append("BASE gain %d Block" % int(effects["block"]) if precise else "%d Block" % int(effects["block"]))
	# Hold the Line and Bastion Quilt pay other recipients too; never hide them.
	if effects.has("other_ally_block"):
		parts.append("BASE each other living ally gains %d Block" % int(effects["other_ally_block"])
			if precise else "%d Block to other allies" % int(effects["other_ally_block"]))
	if effects.has("block_all"):
		parts.append("BASE each living hero gains %d Block" % int(effects["block_all"])
			if precise else "%d Block to all heroes" % int(effects["block_all"]))
	if effects.has("heal"):
		parts.append("BASE heal %d HP, capped at max HP" % int(effects["heal"])
			if precise else "heal %d" % int(effects["heal"]))
	if effects.has("exposed"):
		var exposed: int = int(effects["exposed"])
		if card_id in CombatAttackTargeting.SIGHT_GLASS_IDS:
			parts.append("Apply Exposed %d to the selected enemy" % exposed)
		elif precise:
			parts.append("BASE apply Exposed %d to %s" % [exposed, recipient])
		else:
			parts.append("Exposed %d" % exposed)
	# The starter adapter is the authority for starter confirmed-hit statuses;
	# an authored status it already covers is never counted twice.
	var confirmed: Dictionary = _on_hit.status_for_confirmed_hit(card_id, true)
	if effects.has("bleed") and not confirmed.has("bleed"):
		var authored_bleed: int = int(effects["bleed"])
		var applied_bleed: int = authored_bleed
		var passive_bleed: bool = CombatSeamstressPoolBleed.SUPPORTED_IDS.has(card_id)
		if passive_bleed:
			applied_bleed += 1
		if precise:
			var bleed_line := "BASE apply Bleed %d to %s" % [applied_bleed, recipient]
			if passive_bleed:
				bleed_line += " (authored %d + Seamstress passive 1)" % authored_bleed
			parts.append(bleed_line)
		elif passive_bleed:
			parts.append("Bleed %d (%d+1)" % [applied_bleed, authored_bleed])
		else:
			parts.append("Bleed %d" % applied_bleed)
	if effects.has("weak") and not confirmed.has("weak"):
		parts.append("BASE apply Weak %d to %s" % [int(effects["weak"]), recipient]
			if precise else "Weak %d" % int(effects["weak"]))
	if effects.has("unravel"):
		parts.append("BASE add %d Unravel to %s" % [int(effects["unravel"]), recipient]
			if precise else "Unravel %d" % int(effects["unravel"]))
	if effects.has("bleed_multiplier"):
		var multiplier: int = int(effects["bleed_multiplier"])
		if precise:
			parts.append("BASE double the target's current Bleed" if multiplier == 2
				else "BASE multiply the target's current Bleed by %d" % multiplier)
		else:
			parts.append("double Bleed" if multiplier == 2 else "x%d Bleed" % multiplier)
	if effects.has("pinned"):
		var pin_bonus := 5
		var pin_rule: Variant = effects["pinned"]
		if pin_rule is Dictionary and pin_rule.get("bonus_damage") is int:
			pin_bonus = int(pin_rule["bonus_damage"])
		parts.append("BASE Pin %s: a different hero's next attack gets +%d damage" % [recipient, pin_bonus]
			if precise else "Pin")
	if effects.has("guarding"):
		parts.append("BASE Guard: enemy attacks are redirected to this hero" if precise else "Guard")
	if effects.has("thorns"):
		parts.append("BASE gain %d Thorns until your next turn" % int(effects["thorns"])
			if precise else "Thorns %d" % int(effects["thorns"]))
	if effects.has("draw"):
		var draw_count: int = int(effects["draw"])
		parts.append("BASE draw %d card%s" % [draw_count, "" if draw_count == 1 else "s"]
			if precise else "draw %d" % draw_count)
	if effects.has("gain_energy"):
		parts.append("BASE gain %d energy" % int(effects["gain_energy"])
			if precise else "+%d energy" % int(effects["gain_energy"]))
	if effects.has("energy") and not effects.has("gain_energy"):
		parts.append("BASE gain %d energy" % int(effects["energy"])
			if precise else "+%d energy" % int(effects["energy"]))
	if effects.has("self_hp_loss"):
		parts.append("BASE self-damage %d" % int(effects["self_hp_loss"])
			if precise else "-%d HP" % int(effects["self_hp_loss"]))
	if effects.has("conditional_damage"):
		var condition: Variant = effects["conditional_damage"]
		if condition is Dictionary and condition.get("damage") is int:
			var empowered: int = int(condition["damage"])
			var clauses: Array[String] = _condition_clauses(condition)
			if precise:
				var condition_line := "BASE deal %d damage instead" % empowered
				if not clauses.is_empty():
					condition_line += " if " + _join_conditions(condition, clauses)
				parts.append(condition_line)
			else:
				var short_conditions := _short_conditions(condition)
				parts.append("%d dmg if %s" % [empowered, short_conditions] if not short_conditions.is_empty()
					else "%d conditional dmg" % empowered)
		else:
			parts.append("BASE an additional conditional damage effect" if precise else "conditional damage")
	if precise:
		for status in ["bleed", "weak"]:
			if not confirmed.has(status):
				continue
			var addition: int = int(confirmed[status])
			var rule := "ON CONFIRMED HIT add %s %d" % [status.capitalize(), addition]
			if status == "bleed" and str(definition.get("owner", "")) == "seamstress":
				var authored: int = int(effects.get("bleed", 0))
				rule += " (authored Bleed %d + Seamstress passive %d)" % [authored, addition - authored]
			parts.append(rule)
	else:
		for status in ["bleed", "weak"]:
			if confirmed.has(status):
				parts.append("%d %s on hit" % [int(confirmed[status]), status.capitalize()])
	for key in effects:
		if str(key) not in KNOWN_EFFECT_KEYS:
			parts.append("BASE another authored effect is not described" if precise else "other effects")
			break
	return parts


## The keyword glossary is driven only by authored effects, so an ordinary
## damage card never gains a pin or Unravel paragraph. Unravelled/half-gauge
## conditionals (Snip the Seam) need the Unravel rules just as an Unravel N does.
func _keyword_lines(definition: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var raw_effects: Variant = definition.get("effects", {})
	var effects: Dictionary = raw_effects if raw_effects is Dictionary else {}
	if effects.has("pinned"):
		lines.append(PINNED_EXPLANATION)
	if effects.has("unravel") or _has_unravel_conditional(effects):
		lines.append(UNRAVEL_EXPLANATION)
	return lines


func _has_unravel_conditional(effects: Dictionary) -> bool:
	var condition: Variant = effects.get("conditional_damage")
	if not condition is Dictionary:
		return false
	var authored: Variant = condition.get("conditions", [])
	if not authored is Array:
		return false
	for entry in authored:
		if not entry is Dictionary:
			continue
		if str(entry.get("status", "")) == "unravelled":
			return true
		if str(entry.get("gauge", "")) == "unravel" \
				and str(entry.get("comparison", "")) == "at_least_half":
			return true
	return false


## Readable clauses for the authored conditional-damage predicates. Unrecognized
## predicates contribute nothing rather than a guessed rule.
func _condition_clauses(condition: Dictionary) -> Array[String]:
	var clauses: Array[String] = []
	var authored: Variant = condition.get("conditions", [])
	if not authored is Array:
		return clauses
	for entry in authored:
		if not entry is Dictionary:
			continue
		if entry.has("status") and str(entry["status"]) == "unravelled":
			clauses.append("the target is Unravelled")
		elif entry.has("gauge") and str(entry["gauge"]) == "unravel" \
				and str(entry.get("comparison", "")) == "at_least_half":
			clauses.append("its Unravel gauge is at least half")
	return clauses


func _join_conditions(condition: Dictionary, clauses: Array[String]) -> String:
	var joiner := " or " if str(condition.get("operator", "or")) == "or" else " and "
	return joiner.join(clauses)


## Compact form of the same predicates for the narrow card-face rule line.
func _short_conditions(condition: Dictionary) -> String:
	var keys: Array[String] = []
	var authored: Variant = condition.get("conditions", [])
	if authored is Array:
		for entry in authored:
			if not entry is Dictionary:
				continue
			if entry.has("status") and str(entry["status"]) == "unravelled":
				keys.append("Unravelled")
			elif entry.has("gauge") and str(entry["gauge"]) == "unravel" \
					and str(entry.get("comparison", "")) == "at_least_half":
				keys.append("half gauge")
	# Authored conditions are alternatives today; the card line stays one short row.
	return "/".join(keys)


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
				return {"id": card_id, "known": true, "owner": "", "owner_text": "Stitched",
					"display_name": str(definition.get("display_name", card_id)),
					"cost": definition.cost, "cost_text": "Cost %d" % definition.cost,
					"from_text": "Ordered halves", "target_text": "Independent targets",
					"rules": "Two ordered halves",
					"halves": definition.half_ids.duplicate()}
	if definition.is_empty():
		return {
			"id": card_id, "known": false, "owner": "", "owner_text": "Unknown",
			"display_name": "", "cost_text": "Cost ?", "from_text": "Rules unknown",
			"target_text": "", "rules": "", "cost": -1,
		}
	var owner: String = str(definition.get("owner", ""))
	var from_positions: Array = definition.get("from_positions", [])
	return {
		"id": card_id, "known": true, "owner": owner,
		"owner_text": owner.capitalize(),
		"display_name": str(definition.get("display_name", card_id)),
		"cost": int(definition.get("cost", -1)),
		"cost_text": "Cost %d" % int(definition.get("cost", -1)),
		"from_text": "From " + _positions(from_positions),
		"target_text": _target_text(definition, false),
		"rules": _rules(card_id),
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


## A recognized catalog record is display knowledge, never play admission. Only a
## panel a live presenter has actually wired for play (its own gui_input handler on
## the real hand panel, with the untouched identity label agreeing) may be drawn as
## an enabled card. An unwired pool card keeps its honest face but stays dim.
func _wired(panel: Control, card_id: String) -> bool:
	if _app == null or not is_instance_valid(panel):
		return false
	var hand = _app.hand_view
	if hand == null or panel.get_parent() != hand:
		return false
	if panel.gui_input.get_connections().is_empty():
		return false
	if panel.get_child_count() < 1 or not panel.get_child(0) is Label:
		return false
	return (panel.get_child(0) as Label).text == card_id


func _update_visual(panel: Control) -> void:
	var playable := false
	var id: String = _bindings[panel].id
	if _app != null and _app.deck != null and _app.party != null and _app.enemies != null \
			and _wired(panel, id):
		if _targeting.supports(id):
			# Starter, plain-strike, heavy and Sight Glass attacks share their own
			# read-only preview; no catalog record alone can claim a legal target.
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
			var position := _owner_position(str(support.get("owner", "")))
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
	var definition: Dictionary = _definition(id)
	if definition.is_empty():
		return ""
	return ", ".join(_effect_lines(id, definition, false))


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
		# A stale half contributes an honest placeholder, never its raw ID.
		names.append(authored.get("display_name", "Unknown half"))
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
