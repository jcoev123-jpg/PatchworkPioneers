class_name StitchedCorridorVisit
extends Control
## Owner 11-08: a road stop happens in the corridor, not on a pop-up page. The party stands at
## their ranks on the left, the stop itself stands across from them in the candlelight, and its
## few words and choices hang beside it. Presentation only: the host makes and wires the choices.

const CHROME := preload("res://scripts/stitched/stitched_battle_chrome.gd")
const STOP_HEIGHT := 1.6
const CHOICE_RECT := Rect2(944, 84, 316, 470)
const STORY_RECT := Rect2(120, 586, 800, 64)

var stage: StitchedCorridorStage
var heading: Label
var story: Label
var choices: VBoxContainer
var scroll: ScrollContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_ensure_parts()


func _ensure_parts() -> void:
	if stage != null:
		return
	stage = StitchedCorridorStage.new()
	add_child(stage)
	move_child(stage, 0)
	var column := VBoxContainer.new()
	column.name = "VisitColumn"
	column.position = CHOICE_RECT.position
	column.size = CHOICE_RECT.size
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	heading = _label("StitchedPageHeading", 24, CHROME.BONE)
	column.add_child(heading)
	scroll = ScrollContainer.new()
	scroll.name = "RunActionScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	column.add_child(scroll)
	choices = VBoxContainer.new()
	choices.name = "PublicRouteDecisions"
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.add_theme_constant_override("separation", 6)
	scroll.add_child(choices)
	story = _label("RouteOrVisitStory", 20, Color("e8d6b8"))
	story.position = STORY_RECT.position
	story.size = STORY_RECT.size
	story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(story)


func _label(title: String, font_size: int, tone: Color) -> Label:
	var label := Label.new()
	label.name = title
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tone)
	label.add_theme_color_override("font_outline_color", Color("140c0e"))
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## The corridor where the walk stopped, seen side-on like a fight; the stop stands at the far rank.
func present(area_name: String, band_name: String, kind: String, title: String, words: String) -> void:
	_ensure_parts()
	stage.build(area_name, 2)
	stage.fight_view(true)
	stage.set_candle(band_name)
	var where := stage.fight_point("foe", 1)
	stage.place("stop", StitchedCorridorJunction.stop_art(kind), where, STOP_HEIGHT)
	var glow := OmniLight3D.new()
	glow.name = "StopGlow"
	glow.light_color = Color(1.0, 0.72, 0.45)
	glow.light_energy = 1.1
	glow.omni_range = 3.4
	glow.position = where + Vector3(1.2, 1.4, 0)
	stage.figures.add_child(glow)
	heading.text = title
	story.text = words


## A choice beside the stop, in the fight's own sewn button face.
func dress_choice(button: Button) -> void:
	CHROME.style_button(button)
	button.add_theme_font_size_override("font_size", 16)
	button.custom_minimum_size = Vector2(0, 46)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
