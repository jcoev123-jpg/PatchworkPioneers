class_name LiveRunCardRewardChoicePanel
extends Control
## Presentation/request boundary for a prepared, witnessed M03 Fight or Elite reward.
## No RNG use, reward settlement, deck changes, gold payment or trinket grants.

signal choice_requested(node_id: String, selected_card_id: String)

const OWNER_COLORS := {
	"warden": Color("#4a5d73"),
	"seamstress": Color("#6e4f6b"),
	"tinker": Color("#c49a3a"),
}

const RARITY_COLORS := {
	"common": Color("#5a625a"),
	"uncommon": Color("#2d6342"),
	"rare": Color("#9e3d30"),
}

const RARITY_STITCH_COLORS := {
	"common": Color("#dedbd2"),
	"uncommon": Color("#d2eed8"),
	"rare": Color("#ffd8d0"),
}

const CARD_PAPER := Color("#ece0c8")
const DARK_INK := Color("#302b29")
const STITCH_THREAD := Color("#c9b996")

@onready var paper_panel: PanelContainer = $PaperPanel
@onready var title_label: Label = $PaperPanel/ContentMargin/RewardContent/RewardTitle
@onready var gold_label: Label = $PaperPanel/ContentMargin/RewardContent/GoldLabel
@onready var trinket_label: Label = $PaperPanel/ContentMargin/RewardContent/TrinketLabel
@onready var choices_container: HBoxContainer = $PaperPanel/ContentMargin/RewardContent/CardChoices
@onready var skip_button: Button = $PaperPanel/ContentMargin/RewardContent/SkipButton
@onready var top_stitches: Label = $PaperPanel/ContentMargin/RewardContent/TopStitches
@onready var bottom_stitches: Label = $PaperPanel/ContentMargin/RewardContent/BottomStitches

var _generation: int = 0
var _is_open: bool = false
var _awaiting_ack: bool = false
var _accepted: bool = false
var _node_id: String = ""
var _node_kind: String = ""
var _receipt: Dictionary = {}
var _choice_buttons: Array[Button] = []
var _bound_choices: Dictionary = {}
var _card_panels: Array[PanelContainer] = []
var _card_hovered: Array[bool] = []
var _card_focused: Array[bool] = []


func _ready() -> void:
	_apply_patchwork_style()
	close_rewards()


## Display only a detached valid RunFightVictoryRewards.prepare() receipt.
## Never replace an open receipt without first closing it.
func open_rewards(node_id: Variant, node_kind: Variant, prepared: Variant) -> bool:
	if _is_open or not is_node_ready() or not _valid_receipt(node_id, node_kind, prepared):
		return false
	var snapshot: Dictionary = (prepared as Dictionary).duplicate(true)
	_generation += 1
	_node_id = node_id
	_node_kind = node_kind
	_receipt = snapshot
	_is_open = true
	_awaiting_ack = false
	_accepted = false
	_card_panels.clear()
	_card_hovered = [false, false, false]
	_card_focused = [false, false, false]
	title_label.text = "%s reward" % node_kind
	gold_label.text = "Pending gold: +%d" % snapshot["gold_award"]
	trinket_label.visible = node_kind == "Elite"
	trinket_label.text = ("Patch: " + _humanize_patch(snapshot["trinket_drop_id"])) if node_kind == "Elite" else ""
	for index in range(3):
		var offered: Dictionary = snapshot["offers"][index]
		var definition: Dictionary = RunPoolCardRewardOffers.resolve_reward_definition(offered["id"])
		var card_panel := _mount_card(index, offered, definition)
		_card_panels.append(card_panel)
		choices_container.add_child(card_panel)
		var button := card_panel.get_node("CardMargin/CardContent/ChooseButton") as Button
		_choice_buttons.append(button)
		_bound_choices[button] = offered["id"]
		button.pressed.connect(_on_choice_pressed.bind(_generation, _node_id, offered["id"], button))
	skip_button.name = "Choice_Skip"
	skip_button.disabled = false
	skip_button.focus_mode = Control.FOCUS_ALL
	_style_button(skip_button, Color("#766351"))
	_choice_buttons.append(skip_button)
	_bound_choices[skip_button] = ""
	skip_button.pressed.connect(_on_choice_pressed.bind(_generation, _node_id, "", skip_button))
	for index in range(_choice_buttons.size()):
		var button := _choice_buttons[index]
		button.focus_next = button.get_path_to(_choice_buttons[(index + 1) % _choice_buttons.size()])
		button.focus_previous = button.get_path_to(_choice_buttons[(index + _choice_buttons.size() - 1) % _choice_buttons.size()])
	show()
	call_deferred("_focus_first", _generation)
	return true


func _valid_receipt(node_id: Variant, node_kind: Variant, prepared: Variant) -> bool:
	if not node_id is String or node_id.strip_edges().is_empty():
		return false
	if not node_kind is String or not node_kind in ["Fight", "Elite"]:
		return false
	if not prepared is Dictionary or prepared.get("ok") != true:
		return false
	var award: Variant = prepared.get("gold_award")
	if not award is int or award < (25 if node_kind == "Elite" else 10) \
			or award > (35 if node_kind == "Elite" else 20):
		return false
	var trinket: Variant = prepared.get("trinket_drop_id")
	if not trinket is String:
		return false
	if node_kind == "Elite" and trinket.strip_edges().is_empty():
		return false
	if node_kind == "Fight" and not trinket.is_empty():
		return false
	var offers: Variant = prepared.get("offers")
	if not offers is Array or offers.size() != 3:
		return false
	var ids := {}
	for offer in offers:
		if not offer is Dictionary:
			return false
		var id: Variant = offer.get("id")
		var owner: Variant = offer.get("owner")
		if not id is String or id.strip_edges().is_empty() or ids.has(id):
			return false
		if not owner is String or not OWNER_COLORS.has(owner):
			return false
		# Offers resolve against the real starter catalog or the authored D2-1
		# base pools; pool upgrades and unknown IDs are never valid rewards.
		var definition: Dictionary = RunPoolCardRewardOffers.resolve_reward_definition(id)
		if definition.is_empty() or definition.get("owner") != owner:
			return false
		if not definition.get("display_name") is String \
				or definition["display_name"].strip_edges().is_empty():
			return false
		if not definition.get("cost") is int or definition["cost"] < 0:
			return false
		ids[id] = true
	return true


func _mount_card(index: int, offer: Dictionary, definition: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "Card_%d" % index
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_stretch_ratio = 1.0
	card.custom_minimum_size = Vector2(0, 320)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.focus_mode = Control.FOCUS_NONE
	_style_card(card, String(offer["owner"]), false)
	var margin := MarginContainer.new()
	margin.name = "CardMargin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	card.add_child(margin)
	var content := VBoxContainer.new()
	content.name = "CardContent"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 4)
	margin.add_child(content)

	# Owner color patch (sewn stripe at top)
	var owner_patch := _OwnerPatch.new()
	owner_patch.name = "OwnerPatch"
	owner_patch.owner_color = OWNER_COLORS[offer["owner"]]
	owner_patch.custom_minimum_size = Vector2(0, 18)
	content.add_child(owner_patch)

	# Name on a pinned torn-paper strip
	var name_label := _card_label("NameLabel", definition["display_name"], 21)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.custom_minimum_size = Vector2(0, 70)
	var name_box := StyleBoxFlat.new()
	name_box.bg_color = Color("#fbf3e4")
	name_box.border_color = Color("#c7b89f")
	name_box.set_border_width_all(1)
	name_box.set_corner_radius_all(4)
	name_box.content_margin_left = 6
	name_box.content_margin_right = 6
	name_box.content_margin_top = 4
	name_box.content_margin_bottom = 4
	name_label.add_theme_stylebox_override("normal", name_box)
	content.add_child(name_label)

	# Rarity tag (only for pool cards with authored rarity)
	var rarity_label := _card_label("RarityLabel", "", 15)
	rarity_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var rarity: String = String(definition.get("rarity", "")).strip_edges().to_lower()
	if RARITY_COLORS.has(rarity):
		rarity_label.text = rarity.capitalize()
		var tag_style := StyleBoxFlat.new()
		tag_style.bg_color = RARITY_COLORS[rarity]
		tag_style.border_color = RARITY_STITCH_COLORS[rarity]
		tag_style.set_border_width_all(2)
		tag_style.set_corner_radius_all(6)
		tag_style.content_margin_left = 8
		tag_style.content_margin_right = 8
		tag_style.content_margin_top = 2
		tag_style.content_margin_bottom = 2
		rarity_label.add_theme_stylebox_override("normal", tag_style)
		rarity_label.add_theme_color_override("font_color", Color("#fffaf0"))
		rarity_label.visible = true
	else:
		rarity_label.text = ""
		rarity_label.visible = false
	content.add_child(rarity_label)

	# Cost as a round sewn button (numeric only)
	var cost_value: int = definition["cost"]
	var cost_button := _CostButton.new()
	cost_button.name = "CostButton"
	cost_button.cost_value = cost_value
	cost_button.owner_color = OWNER_COLORS[offer["owner"]]
	cost_button.custom_minimum_size = Vector2(44, 44)
	cost_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cost_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_button.focus_mode = Control.FOCUS_NONE
	content.add_child(cost_button)

	# Position/target pips
	var pips_container := _PositionPips.new()
	pips_container.name = "PositionPips"
	var from_positions: Array[int] = []
	for pos in definition.get("from_positions", []):
		from_positions.append(int(pos))
	var to_positions: Array[int] = []
	for pos in definition.get("to_positions", []):
		to_positions.append(int(pos))
	pips_container.from_positions = from_positions
	pips_container.to_positions = to_positions
	pips_container.target_kind = String(definition.get("target_kind", ""))
	pips_container.owner_color = OWNER_COLORS[offer["owner"]]
	pips_container.custom_minimum_size = Vector2(0, 28)
	content.add_child(pips_container)

	# Rules text
	var rules_label := _card_label("RulesLabel", _format_rules(definition), 16)
	rules_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules_label.custom_minimum_size = Vector2(0, 60)
	content.add_child(rules_label)

	# Choose button
	var action := Button.new()
	action.name = "ChooseButton"
	action.text = "Choose card"
	action.focus_mode = Control.FOCUS_ALL
	action.custom_minimum_size = Vector2(0, 52)
	action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_button(action, OWNER_COLORS[offer["owner"]])
	content.add_child(action)

	var offered_id := String(offer["id"])
	card.gui_input.connect(_on_card_gui_input.bind(index, offered_id, action))
	card.mouse_entered.connect(_on_card_mouse_entered.bind(index))
	card.mouse_exited.connect(_on_card_mouse_exited.bind(index))
	action.focus_entered.connect(_on_card_focus_entered.bind(index))
	action.focus_exited.connect(_on_card_focus_exited.bind(index))
	return card


## A detached catalog card is the sole source of the preview, never battle
## passives, receipt/offer data, RNG or current combat availability.
## Every authored target kind and base-pool effect key is summarized here.
func _format_rules(definition: Dictionary) -> String:
	var kind: String = String(definition.get("target_kind", ""))
	var from_text := _position_text(definition.get("from_positions", []), true)
	var slots := _position_text(definition.get("to_positions", []), false)
	var target_text := ""
	match kind:
		"enemy_single": target_text = "pick 1 living enemy " + slots
		"enemy_all": target_text = "all living enemies " + slots
		"enemy_random": target_text = "1 random living enemy per hit " + slots
		"self": target_text = "self"
		"ally_single": target_text = "1 living ally 1-3"
		"party_all": target_text = "all allies"
		"none": target_text = "none"
	var effects: Dictionary = definition.get("effects", {})
	var copy: Array[String] = []
	var until_next_turn: bool = String(effects.get("duration", "")) == "until_next_turn"
	var hits: int = int(effects.get("hits", effects.get("hit_count", 1)))
	for key: String in effects:
		match key:
			"damage":
				var dealt := "Deal %d damage" % int(effects[key])
				if hits > 1:
					dealt += " ×%d hits" % hits
				elif kind == "enemy_all":
					dealt += " EACH"
				if bool(effects.get("random_target_each_hit", false)):
					dealt += " (random target each hit)"
				if effects.has("conditional_damage"):
					dealt += _conditional_damage_hint(effects["conditional_damage"])
				copy.append(dealt)
			"block":
				if kind == "ally_single":
					copy.append("Chosen ally gains %d Block" % int(effects[key]))
				elif kind == "self":
					copy.append("Gain %d Block" % int(effects[key]))
				else:
					copy.append("Gain %d Block" % int(effects[key]))
			"block_all":
				copy.append("All allies gain %d Block each" % int(effects[key]))
			"other_ally_block":
				copy.append("Every other ally gains %d Block" % int(effects[key]))
			"heal":
				if kind == "ally_single":
					copy.append("Chosen ally heals %d HP" % int(effects[key]))
				elif kind == "party_all":
					copy.append("All allies heal %d HP each" % int(effects[key]))
				else:
					copy.append("Heal %d HP" % int(effects[key]))
			"draw":
				var drawn: int = int(effects[key])
				copy.append("Draw %d card%s" % [drawn, "" if drawn == 1 else "s"])
			"weak":
				copy.append("Weak %d" % int(effects[key]))
			"bleed":
				copy.append("Bleed %d%s" % [int(effects[key]),
					" EACH" if kind == "enemy_all" else ""])
			"bleed_multiplier":
				copy.append("Bleed ×%d" % int(effects[key]))
			"unravel":
				copy.append("Unravel %d" % int(effects[key]))
			"exposed":
				copy.append("Exposed %d" % int(effects[key]))
			"pinned":
				copy.append("Pinned " + _pinned_hint(effects[key]))
			"guarding":
				copy.append("Guarding" + (" until next turn" if until_next_turn else ""))
			"thorns":
				copy.append("Thorns %d%s" % [int(effects[key]),
					" until next turn" if until_next_turn else ""])
			"energy", "gain_energy":
				copy.append("Gain +%d energy" % int(effects[key]))
			"self_hp_loss":
				copy.append("%d HP lost" % int(effects[key]))
			"conditional_damage":
				# Only reachable when authored without a base damage key.
				if not effects.has("damage"):
					var rule: Dictionary = effects[key] if effects[key] is Dictionary else {}
					copy.append("Deal %d damage conditionally" % int(rule.get("damage", 0)))
			_:
				pass
	return "From: %s\nTarget: %s\n%s" % [from_text, target_text, ", ".join(copy)]


func _position_text(positions: Array, is_source: bool) -> String:
	match positions:
		[1]: return "1 (front)"
		[3]: return "3 (back)"
		[1, 2]: return "1-2 (front/middle)" if is_source else "1-2"
		[2, 3]: return "2-3 (middle/back)" if is_source else "2-3"
		[1, 2, 3]: return "1-3 (front to back)" if is_source else "1-3"
	return ""


func _pinned_hint(rule: Variant) -> String:
	var bonus := 5
	if rule is Dictionary and (rule as Dictionary).get("bonus_damage") is int:
		bonus = int((rule as Dictionary)["bonus_damage"])
	return "(+%d damage on another hero's next attack, once)" % bonus


func _conditional_damage_hint(condition: Variant) -> String:
	if not condition is Dictionary:
		return ""
	var rule: Dictionary = condition
	var empowered: int = int(rule.get("damage", 0))
	var hints: Array[String] = []
	for item: Variant in rule.get("conditions", []):
		if not item is Dictionary:
			continue
		var part: Dictionary = item
		if part.has("status"):
			hints.append(String(part["status"]).capitalize())
		elif part.has("gauge"):
			var gauge := String(part["gauge"]).capitalize()
			if String(part.get("comparison", "")) == "at_least_half":
				hints.append(gauge + " at half")
			else:
				hints.append(gauge + " " + String(part.get("comparison", "")).replace("_", " "))
	var joiner := " and " if String(rule.get("operator", "or")) == "and" else " or "
	if hints.is_empty():
		return " (%d instead under a condition)" % empowered
	return " (%d instead if %s)" % [empowered, joiner.join(hints)]


func _card_label(label_name: String, value: String, point_size: int) -> Label:
	var label := Label.new()
	label.name = label_name
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", DARK_INK)
	label.add_theme_font_size_override("font_size", point_size)
	return label


## A caller rejection re-enables this exact prepared offer; acceptance latches it.
## Acknowledgements while closed or without an outstanding request do nothing.
func acknowledge(accepted: bool) -> void:
	if not _is_open or not _awaiting_ack or _accepted:
		return
	_awaiting_ack = false
	if accepted:
		_accepted = true
		return
	for button in _choice_buttons:
		if is_instance_valid(button):
			button.disabled = false


func close_rewards() -> void:
	_generation += 1
	_is_open = false
	_awaiting_ack = false
	_accepted = false
	_node_id = ""
	_node_kind = ""
	_receipt.clear()
	hide()
	if not is_node_ready():
		return
	title_label.text = ""
	gold_label.text = ""
	trinket_label.text = ""
	trinket_label.hide()
	for connection in skip_button.pressed.get_connections():
		skip_button.pressed.disconnect(connection["callable"])
	for button in _choice_buttons:
		if is_instance_valid(button):
			button.disabled = true
			button.release_focus()
	for card in choices_container.get_children():
		choices_container.remove_child(card)
		card.queue_free()
	_choice_buttons.clear()
	_bound_choices.clear()
	_card_panels.clear()
	_card_hovered.clear()
	_card_focused.clear()
	skip_button.disabled = true
	skip_button.release_focus()


func has_open_rewards() -> bool:
	return _is_open


func get_choice_buttons() -> Array[Button]:
	return _choice_buttons.duplicate()


func _focus_first(generation: int) -> void:
	if _is_open and _generation == generation and not _choice_buttons.is_empty() \
			and is_visible_in_tree() and not _choice_buttons[0].disabled:
		_choice_buttons[0].grab_focus()


func _on_choice_pressed(generation: int, node_id: String, selected_card_id: String, button: Button) -> void:
	if not _is_open or _accepted or _awaiting_ack or _generation != generation \
			or _node_id != node_id or not is_visible_in_tree():
		return
	if not is_instance_valid(button) or not button.is_inside_tree() \
			or not button.is_visible_in_tree() or button.disabled:
		return
	if not _choice_buttons.has(button) or not _bound_choices.has(button) \
			or _bound_choices[button] != selected_card_id:
		return
	if button != skip_button and not choices_container.is_ancestor_of(button):
		return
	if button == skip_button and selected_card_id != "":
		return
	_awaiting_ack = true
	for choice in _choice_buttons:
		choice.disabled = true
	choice_requested.emit(_node_id, selected_card_id)


func _style_card(card: PanelContainer, owner: String, active: bool) -> void:
	var patch := StyleBoxFlat.new()
	patch.bg_color = CARD_PAPER
	if OWNER_COLORS.has(owner):
		patch.border_color = OWNER_COLORS[owner]
	else:
		patch.border_color = Color("#736451")
	patch.set_border_width_all(8 if active else 5)
	patch.set_corner_radius_all(10)
	patch.content_margin_left = 10
	patch.content_margin_right = 10
	patch.content_margin_top = 12
	patch.content_margin_bottom = 12
	patch.shadow_color = Color(0.03, 0.06, 0.07, 0.8)
	patch.shadow_size = 18 if active else 12
	patch.shadow_offset = Vector2(0, 4) if active else Vector2.ZERO
	card.add_theme_stylebox_override("panel", patch)


func _on_card_gui_input(event: InputEvent, index: int, card_id: String, button: Button) -> void:
	if not _is_open or _accepted or _awaiting_ack:
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	_on_choice_pressed(_generation, _node_id, card_id, button)


func _on_card_mouse_entered(index: int) -> void:
	if index < 0 or index >= _card_hovered.size():
		return
	_card_hovered[index] = true
	_update_card_style(index)


func _on_card_mouse_exited(index: int) -> void:
	if index < 0 or index >= _card_hovered.size():
		return
	_card_hovered[index] = false
	_update_card_style(index)


func _on_card_focus_entered(index: int) -> void:
	if index < 0 or index >= _card_focused.size():
		return
	_card_focused[index] = true
	_update_card_style(index)


func _on_card_focus_exited(index: int) -> void:
	if index < 0 or index >= _card_focused.size():
		return
	_card_focused[index] = false
	_update_card_style(index)


func _update_card_style(index: int) -> void:
	if not _is_open or index < 0 or index >= _card_panels.size():
		return
	var card := _card_panels[index]
	if not is_instance_valid(card):
		return
	var owner := ""
	if index < _receipt.get("offers", []).size():
		owner = String((_receipt["offers"][index] as Dictionary).get("owner", ""))
	if owner.is_empty():
		return
	_style_card(card, owner, _card_hovered[index] or _card_focused[index])


func _apply_patchwork_style() -> void:
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("#e9dcc3")
	paper.border_color = Color("#736451")
	paper.set_border_width_all(5)
	paper.set_corner_radius_all(14)
	paper.shadow_color = Color(0.03, 0.06, 0.07, 0.8)
	paper.shadow_size = 12
	paper_panel.add_theme_stylebox_override("panel", paper)
	for label in [title_label, gold_label, trinket_label]:
		label.add_theme_color_override("font_color", Color("#263137"))
	title_label.add_theme_font_size_override("font_size", 31)
	gold_label.add_theme_font_size_override("font_size", 22)
	trinket_label.add_theme_font_size_override("font_size", 19)
	for label in [top_stitches, bottom_stitches]:
		label.add_theme_color_override("font_color", Color("#77624f"))
		label.add_theme_font_size_override("font_size", 17)


func _style_button(button: Button, accent: Color) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		match state:
			"normal": box.bg_color = Color("#d4bf9e")
			"hover": box.bg_color = Color("#e2cba5")
			"pressed": box.bg_color = Color("#ae9472")
			"disabled": box.bg_color = Color("#a89b87")
		box.border_color = accent
		box.set_border_width_all(3)
		box.set_corner_radius_all(7)
		box.content_margin_left = 10
		box.content_margin_right = 10
		button.add_theme_stylebox_override(state, box)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("#fffaf0")
	focus.set_border_width_all(5)
	focus.set_corner_radius_all(7)
	button.add_theme_stylebox_override("focus", focus)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		button.add_theme_color_override(state, Color("#263137"))
	button.add_theme_font_size_override("font_size", 20)


static func _humanize_patch(id: String) -> String:
	if id.is_empty():
		return ""
	var parts: PackedStringArray = id.split("_")
	var words: PackedStringArray = []
	for part in parts:
		if not part.is_empty():
			words.append(part.capitalize())
	return " ".join(words)


## Owner color patch (sewn stripe at top of card)
class _OwnerPatch extends Control:
	@export var owner_color: Color = Color.WHITE

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		var rect := Rect2(Vector2(0, 0), size)
		# Draw the patch background
		draw_rect(rect, owner_color)
		# Draw running stitch along bottom edge
		var y := rect.end.y - 2
		draw_dashed_line(Vector2(rect.position.x + 8, y), Vector2(rect.end.x - 8, y), STITCH_THREAD, 1.5, 6.0)
		# Draw running stitch along top edge
		y = rect.position.y + 2
		draw_dashed_line(Vector2(rect.position.x + 8, y), Vector2(rect.end.x - 8, y), STITCH_THREAD, 1.5, 6.0)


## Round sewn energy coin, drawn exactly like the shared hand's cost coin: a
## golden felt disc with a pale rim and a stitched ring around a centred numeral.
## Decoration only; the authored cost text is drawn from the coin's own font
## metrics so 0, 1 and 2 stay centred inside their glyph bounds.
class _CostButton extends Control:
	@export var cost_value: int = 0
	## Kept because every mounted offer records its owner palette here; the coin
	## itself matches the hand's gold regardless of owner.
	@export var owner_color: Color = Color.WHITE

	## Same golden felt the live hand paints its energy coin with.
	const COIN_GOLD := Color("#c49a3a")
	const COIN_RIM := Color("#ece0c8")
	const STITCH_COUNT := 12

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		resized.connect(queue_redraw)

	func coin_color() -> Color:
		return COIN_GOLD

	func coin_radius() -> float:
		return minf(size.x, size.y) * 0.5

	## One font size for every numeral, decided once from the coin's own size.
	func numeral_font_size() -> int:
		return maxi(18, int(coin_radius() * 0.9))

	func numeral_text() -> String:
		return str(cost_value)

	## The exact baseline origin draw_string() needs: the advance width comes
	## from the drawn point size and the baseline is offset by half the real
	## ascent/descent so the numeral's ink box sits on the coin's centre.
	func numeral_origin(font: Font) -> Vector2:
		var point_size: int = numeral_font_size()
		var advance: Vector2 = font.get_string_size(numeral_text(),
			HORIZONTAL_ALIGNMENT_LEFT, -1, point_size)
		var ascent: float = font.get_ascent(point_size)
		var descent: float = font.get_descent(point_size)
		var center: Vector2 = size * 0.5
		return Vector2(center.x - advance.x * 0.5, center.y + (ascent - descent) * 0.5)

	## Measured ink box of the numeral at the font size actually drawn.
	func numeral_bounds(font: Font) -> Rect2:
		var point_size: int = numeral_font_size()
		var origin: Vector2 = numeral_origin(font)
		var advance: Vector2 = font.get_string_size(numeral_text(),
			HORIZONTAL_ALIGNMENT_LEFT, -1, point_size)
		var ascent: float = font.get_ascent(point_size)
		var descent: float = font.get_descent(point_size)
		return Rect2(origin.x, origin.y - ascent, advance.x, ascent + descent)

	## Ring radius for the stitches: inside the rim, outside every numeral bound.
	func stitch_radius() -> float:
		return maxf(0.0, coin_radius() - 4.0)

	## Dashed ring spans, as (start_angle, end_angle). Never a diameter line.
	func stitch_spans() -> Array[Vector2]:
		var spans: Array[Vector2] = []
		var step: float = TAU / float(STITCH_COUNT)
		for index in range(STITCH_COUNT):
			var start: float = step * float(index) + step * 0.15
			spans.append(Vector2(start, start + step * 0.55))
		return spans

	func _draw() -> void:
		var center: Vector2 = size * 0.5
		var radius: float = coin_radius()
		var font: Font = get_theme_default_font()
		if font == null:
			font = ThemeDB.fallback_font
		draw_circle(center, radius, COIN_GOLD)
		draw_arc(center, maxf(0.0, radius - 1.0), 0.0, TAU, 32, COIN_RIM, 1.5, true)
		for span: Vector2 in stitch_spans():
			draw_arc(center, stitch_radius(), span.x, span.y, 6, STITCH_THREAD, 2.0, true)
		draw_string(font, numeral_origin(font), numeral_text(),
			HORIZONTAL_ALIGNMENT_LEFT, -1, numeral_font_size(), DARK_INK)


## Authored position marks, identical in convention to the shared hand's pips:
## three source circles (owner-colour filled when legal, outlined when not) and
## three target squares (ink filled when legal, outlined when not). Slot 1 is
## always the front. The readable target kind lives in RulesLabel; this control
## draws no glyph and no miniature number.
class _PositionPips extends Control:
	@export var from_positions: Array[int] = []
	@export var to_positions: Array[int] = []
	@export var target_kind: String = ""
	@export var owner_color: Color = Color.WHITE

	const SLOT_COUNT := 3
	const SLOT_RADIUS := 6.0
	const SLOT_GAP := 15.0
	const GROUP_GAP := 24.0
	const OUTLINE := Color("#9e6f58")

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(queue_redraw)

	## Exactly six drawable slots in a stable order: three circles (source
	## positions 1..3) then three squares (target positions 1..3). Filled only
	## when the resolved definition authorises that position.
	func slots() -> Array[Dictionary]:
		var markers: Array[Dictionary] = []
		var radius: float = SLOT_RADIUS
		var group_width: float = float(SLOT_COUNT - 1) * SLOT_GAP + radius * 2.0
		var total_width: float = group_width * 2.0 + GROUP_GAP
		var first_x: float = maxf(radius + 2.0, (size.x - total_width) * 0.5 + radius)
		var y: float = size.y * 0.5
		for index in range(1, SLOT_COUNT + 1):
			markers.append({
				"shape": "circle",
				"position": index,
				"center": Vector2(first_x + SLOT_GAP * float(index - 1), y),
				"radius": radius,
				"filled": from_positions.has(index),
			})
		var square_x: float = first_x + group_width + GROUP_GAP
		for index in range(1, SLOT_COUNT + 1):
			markers.append({
				"shape": "square",
				"position": index,
				"center": Vector2(square_x + SLOT_GAP * float(index - 1), y),
				"radius": radius,
				"filled": to_positions.has(index),
			})
		return markers

	func _draw() -> void:
		for marker: Dictionary in slots():
			var center: Vector2 = marker["center"]
			var radius: float = marker["radius"]
			var filled: bool = marker["filled"]
			if String(marker["shape"]) == "circle":
				if filled:
					draw_circle(center, radius, owner_color)
					draw_arc(center, radius, 0.0, TAU, 16, STITCH_THREAD, 1.0, true)
				else:
					draw_arc(center, radius, 0.0, TAU, 16, OUTLINE, 1.5, true)
			else:
				var box := Rect2(center - Vector2(radius, radius), Vector2.ONE * radius * 2.0)
				if filled:
					draw_rect(box, DARK_INK, true)
				else:
					draw_rect(box, CARD_PAPER, true)
					draw_rect(box, OUTLINE, false, 1.5)
