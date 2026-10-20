extends Control
## Root of the game. The hand view delegates all card movement to CombatDeck.

signal start_run_requested

const TITLE := "Patchwork Pioneers"
const STARTER_DECK_PATH := "res://data/cards/starter_deck.json"
const STARTER_PARTY_PATH := "res://data/heroes/starter_party.json"

@export var run_seed: int = 42
@export_file("*.json") var starter_party_path: String = STARTER_PARTY_PATH

var title_label: Label
var start_button: Button
var title_view: VBoxContainer
var battle_view: MarginContainer
var hand_view: HBoxContainer
var pile_label: Label
var end_turn_button: Button
var return_button: Button
var deck: CombatDeck
var run_rng: RandomNumberGenerator
var party: CombatParty
var hero_view: HBoxContainer
var hero_panels: Array[PanelContainer] = []


func _ready() -> void:
	_build_title()
	start_run_requested.connect(_start_run)


func _build_title() -> void:
	var bg := ColorRect.new()
	bg.color = Color("2b3135")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var box := VBoxContainer.new()
	title_view = box
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 32)
	add_child(box)

	title_label = Label.new()
	title_label.text = TITLE
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 64)
	title_label.add_theme_color_override("font_color", Color("ece0c8"))
	title_label.add_theme_constant_override("outline_size", 12)
	title_label.add_theme_color_override("font_outline_color", Color("1a1d20"))
	box.add_child(title_label)

	start_button = Button.new()
	start_button.text = "Start run"
	start_button.custom_minimum_size = Vector2(240, 56)
	start_button.add_theme_font_size_override("font_size", 28)
	start_button.pressed.connect(func(): start_run_requested.emit())
	box.add_child(start_button)
	start_button.grab_focus.call_deferred()
	box.position -= box.get_combined_minimum_size() / 2.0


func _start_run() -> void:
	if deck != null:
		return
	var source = JSON.parse_string(FileAccess.get_file_as_string(STARTER_DECK_PATH))
	if not source is Array or source.is_empty():
		push_error("Starter deck must be a nonempty array of card IDs")
		return
	var cards: Array[String] = []
	for card in source:
		if not card is String or card.is_empty():
			push_error("Starter deck contains an invalid card ID")
			return
		cards.append(card)
	var definitions := _load_party_definitions()
	var starting_party := CombatParty.new(definitions)
	if not starting_party.is_valid():
		push_warning("Starter party definitions are invalid; run was not started")
		return
	party = starting_party
	run_rng = RandomNumberGenerator.new()
	run_rng.seed = run_seed
	deck = CombatDeck.new(cards, run_rng)
	deck.start_turn()
	title_view.hide()
	_build_battle()
	_refresh_hand()
	_refresh_party()
	end_turn_button.grab_focus()


func _load_party_definitions() -> Array:
	if not FileAccess.file_exists(starter_party_path):
		return []
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(starter_party_path)) != OK:
		return []
	var source = parser.data
	if not source is Array:
		return []
	for definition in source:
		if not definition is Dictionary:
			return []
		var max_hp = definition.get("max_hp")
		# JSON numbers decode as floats; reject fractions before converting for CombatParty.
		if not (max_hp is float or max_hp is int):
			return []
		if not is_finite(float(max_hp)) or max_hp <= 0 or max_hp >= float(CombatParty.MAX_INT):
			return []
		if floor(float(max_hp)) != float(max_hp):
			return []
		for field in ["name", "art_path"]:
			if not definition.get(field) is String or definition[field].is_empty():
				return []
		definition["max_hp"] = int(max_hp)
	return source


func _build_battle() -> void:
	battle_view = MarginContainer.new()
	battle_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		battle_view.add_theme_constant_override("margin_" + side, 32)
	add_child(battle_view)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	battle_view.add_child(column)
	hero_view = HBoxContainer.new()
	hero_view.add_theme_constant_override("separation", 16)
	column.add_child(hero_view)
	for index in range(CombatParty.PARTY_SIZE):
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(0, 100)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hero_view.add_child(panel)
		hero_panels.append(panel)
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 22)
		panel.add_child(label)
	var heading := Label.new()
	heading.text = "Shared hand"
	heading.add_theme_font_size_override("font_size", 32)
	column.add_child(heading)
	pile_label = Label.new()
	column.add_child(pile_label)
	hand_view = HBoxContainer.new()
	hand_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_view.add_theme_constant_override("separation", 16)
	column.add_child(hand_view)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 24)
	column.add_child(actions)
	end_turn_button = Button.new()
	end_turn_button.text = "End Turn"
	end_turn_button.custom_minimum_size = Vector2(240, 56)
	end_turn_button.pressed.connect(_end_turn)
	actions.add_child(end_turn_button)
	return_button = Button.new()
	return_button.text = "Return to title"
	return_button.custom_minimum_size = Vector2(240, 56)
	return_button.pressed.connect(_return_to_title)
	actions.add_child(return_button)
	end_turn_button.focus_next = end_turn_button.get_path_to(return_button)
	end_turn_button.focus_previous = end_turn_button.get_path_to(return_button)
	return_button.focus_next = return_button.get_path_to(end_turn_button)
	return_button.focus_previous = return_button.get_path_to(end_turn_button)


func _refresh_hand() -> void:
	for child in hand_view.get_children():
		child.free()
	for card_id in deck.hand:
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hand_view.add_child(panel)
		var label := Label.new()
		label.text = card_id
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 22)
		panel.add_child(label)
	pile_label.text = "Draw: %d | Discard: %d" % [deck.draw_pile.size(), deck.discard_pile.size()]


func _refresh_party() -> void:
	for index in range(hero_panels.size()):
		var hero := party.get_hero(index + 1)
		var label := hero_panels[index].get_child(0) as Label
		label.text = "%d - %s\nHP: %d/%d | Block: %d%s" % [
			hero["position"], hero["name"], hero["hp"], hero["max_hp"], hero["block"],
			"\nDOWNED" if party.is_downed(index + 1) else ""]


func _end_turn() -> void:
	if deck == null or party == null or not deck.end_turn():
		return
	if not deck.start_turn():
		return
	party.start_player_turn()
	_refresh_hand()
	_refresh_party()


func _return_to_title() -> void:
	if battle_view == null:
		return
	remove_child(battle_view)
	battle_view.queue_free()
	battle_view = null
	hand_view = null
	pile_label = null
	end_turn_button = null
	return_button = null
	hero_view = null
	hero_panels.clear()
	party = null
	deck = null
	run_rng = null
	title_view.show()
	start_button.grab_focus()
