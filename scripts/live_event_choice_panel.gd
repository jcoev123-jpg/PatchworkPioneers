class_name LiveEventChoicePanel
extends Control
## Standalone, unwired presentation for an authored M04 Event.
## open_event() accepts a RunEventChoice-compatible Dictionary and returns true
## only when a fresh offering was displayed. close_event() releases that offer.
## No event outcome, session, deck, gold, trinket or RNG is touched here.

signal choice_committed(event_id: String, choice_id: String)

@onready var paper_panel: PanelContainer = $PaperPanel
@onready var title_label: Label = $PaperPanel/ContentMargin/EventContent/EventTitle
@onready var description_label: Label = $PaperPanel/ContentMargin/EventContent/EventDescription
@onready var choices_container: VBoxContainer = $PaperPanel/ContentMargin/EventContent/Choices
@onready var top_stitches: Label = $PaperPanel/ContentMargin/EventContent/TopStitches
@onready var bottom_stitches: Label = $PaperPanel/ContentMargin/EventContent/BottomStitches

var _selector: RunEventChoice = null
var _generation: int = 0
var _is_open: bool = false
var _choice_buttons: Array[Button] = []
var _bound_choices: Dictionary = {}
var _committed_choice: Dictionary = {}


func _ready() -> void:
	_apply_patchwork_style()
	close_event()


## Displays a detached authored offering; refuses invalid records and refuses
## to replace an open offer (including an already-claimed offer) until closed.
func open_event(event_record: Dictionary) -> bool:
	if _is_open:
		return false
	var offered := RunEventChoice.new(event_record)
	if not offered.is_valid():
		return false
	var snapshot: Dictionary = offered.get_event()
	_generation += 1
	_selector = offered
	_is_open = true
	title_label.text = snapshot["title"]
	description_label.text = snapshot["description"]
	for entry in snapshot["choices"]:
		var choice: Dictionary = entry
		var choice_id: String = choice["id"]
		var button := Button.new()
		button.name = "Choice_%d" % _choice_buttons.size()
		button.text = choice["text"]
		button.custom_minimum_size = Vector2(0.0, 56.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		_style_choice_button(button)
		choices_container.add_child(button)
		_choice_buttons.append(button)
		_bound_choices[button] = choice_id
		# All four bindings are captured at presentation time, never looked up
		# from mutable caller data when the button is activated.
		button.pressed.connect(_on_choice_pressed.bind(offered, choice_id, _generation, button))
	visible = true
	return true


## Discards the selector, removes the currently active buttons and invalidates
## all prior callback generations before another event can be opened.
func close_event() -> void:
	_committed_choice.clear()
	_generation += 1
	_is_open = false
	_selector = null
	visible = false
	if is_node_ready():
		title_label.text = ""
		description_label.text = ""
	for button in _choice_buttons:
		if not is_instance_valid(button):
			continue
		button.disabled = true
		button.release_focus()
		if button.get_parent() == choices_container:
			choices_container.remove_child(button)
		button.queue_free()
	_choice_buttons.clear()
	_bound_choices.clear()


func has_open_event() -> bool:
	return _is_open


## Snapshot of the actual visible choice controls for external scene inspection.
func get_choice_buttons() -> Array[Button]:
	return _choice_buttons.duplicate()


func _on_choice_pressed(offered: RunEventChoice, choice_id: String, generation: int, button: Button) -> void:
	if not _is_open or not is_visible_in_tree() or _generation != generation:
		return
	if _selector == null or _selector != offered or not offered.is_valid():
		return
	if not is_instance_valid(button) or not button.is_inside_tree():
		return
	if not button.visible or not button.is_visible_in_tree() or button.disabled:
		return
	if not _choice_buttons.has(button) or _bound_choices.get(button, "") != choice_id:
		return
	var result: Dictionary = offered.choose(choice_id)
	if result.get("ok", false) != true:
		return
	_committed_choice = result.duplicate(true)
	for current in _choice_buttons:
		current.disabled = true
		current.release_focus()
	choice_committed.emit(result["event_id"], result["choice_id"])


func _apply_patchwork_style() -> void:
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("#e5d5b5")
	paper.border_color = Color("#766351")
	paper.set_border_width_all(5)
	paper.set_corner_radius_all(14)
	paper.shadow_color = Color(0.04, 0.07, 0.08, 0.75)
	paper.shadow_size = 12
	paper_panel.add_theme_stylebox_override("panel", paper)
	for label in [title_label, description_label]:
		label.add_theme_color_override("font_color", Color("#2c3437"))
	title_label.add_theme_font_size_override("font_size", 36)
	description_label.add_theme_font_size_override("font_size", 23)
	for stitch_label in [top_stitches, bottom_stitches]:
		stitch_label.add_theme_color_override("font_color", Color("#85715b"))
		stitch_label.add_theme_font_size_override("font_size", 17)


func _style_choice_button(button: Button) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		match state:
			"normal":
				style.bg_color = Color("#bca17e")
			"hover":
				style.bg_color = Color("#d2b58c")
			"pressed":
				style.bg_color = Color("#9f805e")
			"disabled":
				style.bg_color = Color("#948875")
		style.border_color = Color("#6c5347")
		style.set_border_width_all(2)
		style.set_corner_radius_all(7)
		style.content_margin_left = 18
		style.content_margin_right = 18
		button.add_theme_stylebox_override(state, style)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("#fff5d4")
	focus.set_border_width_all(4)
	focus.set_corner_radius_all(8)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_color_override("font_color", Color("#27343a"))
	button.add_theme_color_override("font_hover_color", Color("#1e292e"))
	button.add_theme_color_override("font_pressed_color", Color("#1e292e"))
	button.add_theme_color_override("font_disabled_color", Color("#302e2d"))
	button.add_theme_font_size_override("font_size", 21)
