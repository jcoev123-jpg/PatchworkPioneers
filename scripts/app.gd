extends Control
## Root of the game. The hand view delegates all card movement to CombatDeck.

signal start_run_requested

const TITLE := "Patchwork Pioneers"
const STARTER_DECK_PATH := "res://data/cards/starter_deck.json"

@export var run_seed: int = 42

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
	run_rng = RandomNumberGenerator.new()
	run_rng.seed = run_seed
	deck = CombatDeck.new(cards, run_rng)
	deck.start_turn()
	title_view.hide()
	_build_battle()
	_refresh_hand()
	end_turn_button.grab_focus()


func _build_battle() -> void:
	battle_view = MarginContainer.new()
	battle_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		battle_view.add_theme_constant_override("margin_" + side, 32)
	add_child(battle_view)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	battle_view.add_child(column)
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


func _end_turn() -> void:
	if deck == null or not deck.end_turn():
		return
	deck.start_turn()
	_refresh_hand()


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
	deck = null
	run_rng = null
	title_view.show()
	start_button.grab_focus()
