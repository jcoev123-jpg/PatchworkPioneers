class_name CombatActorMeter
extends VBoxContainer
## Snapshot-only combat presenter. The owner of CombatParty/CombatEnemies must
## supply a new get_hero/get_enemy dictionary after each combat state change.

const INK := Color("e9dec9")
const PANEL := Color("29353c")
const BORDER := Color("b7a48b")
const HP_HERO := Color("719796")
const HP_ENEMY := Color("b78373")
const BLOCK := Color("c6aa76")

var actor_heading: Label
var hp_text: Label
var hp_bar: ProgressBar
var block_text: Label
var block_bar: ProgressBar

var _panel_style: StyleBoxFlat


func _init() -> void:
	name = "CombatActorMeter"
	custom_minimum_size = Vector2(256, 156)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = PANEL
	_panel_style.border_color = BORDER
	_panel_style.set_border_width_all(2)
	_panel_style.set_corner_radius_all(5)

	var padding := MarginContainer.new()
	padding.name = "Padding"
	padding.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for edge in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		padding.add_theme_constant_override(edge, 12)
	add_child(padding)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 4)
	padding.add_child(content)

	actor_heading = _make_label(content, "ActorHeading")
	actor_heading.add_theme_font_size_override("font_size", 18)
	hp_text = _make_label(content, "HPText")
	hp_bar = _make_bar(content, "HPBar", HP_HERO)
	block_text = _make_label(content, "BlockText")
	block_bar = _make_bar(content, "BlockBar", BLOCK)
	_clear_actor()


func _draw() -> void:
	draw_style_box(_panel_style, Rect2(Vector2.ZERO, size))


func _make_label(parent: VBoxContainer, node_name: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.add_theme_color_override("font_color", INK)
	label.add_theme_font_size_override("font_size", 15)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _make_bar(parent: VBoxContainer, node_name: String, tint: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.name = node_name
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(220, 15)
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = 0.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color("17242c")
	background.border_color = BORDER.darkened(0.35)
	background.set_border_width_all(1)
	bar.add_theme_stylebox_override("background", background)
	var fill := StyleBoxFlat.new()
	fill.bg_color = tint
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar


## Invalid or missing data hides and wipes any previously shown living actor.
## No service references, background polling, input or state changes occur here.
func show_actor(snapshot: Dictionary, side: String) -> bool:
	if not _valid_snapshot(snapshot, side):
		_clear_actor()
		return false

	var position: int = snapshot["position"]
	var actor_name: String = snapshot["name"]
	var maximum: int = snapshot["max_hp"]
	var current: int = snapshot["hp"]
	var protection: int = snapshot["block"]
	var title := "%d. %s" % [position, actor_name]
	if current == 0:
		title += " — DOWNED" if side == "hero" else " — SLAIN"
	actor_heading.text = title
	hp_text.text = "HP: %d/%d" % [current, maximum]
	block_text.text = "Block: %d" % protection

	hp_bar.max_value = float(maximum)
	hp_bar.value = float(current)
	block_bar.max_value = float(maxi(1, maxi(maximum, protection)))
	block_bar.value = float(protection)

	var hp_style: StyleBoxFlat = hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if hp_style != null:
		hp_style.bg_color = HP_HERO if side == "hero" else HP_ENEMY
	show()
	queue_redraw()
	return true


func _valid_snapshot(snapshot: Dictionary, side: String) -> bool:
	if side != "hero" and side != "enemy":
		return false
	for field in ["name", "position", "max_hp", "hp", "block"]:
		if not snapshot.has(field):
			return false
	var actor_name = snapshot["name"]
	var position = snapshot["position"]
	var maximum = snapshot["max_hp"]
	var current = snapshot["hp"]
	var protection = snapshot["block"]
	if not actor_name is String or actor_name.strip_edges().is_empty():
		return false
	if not position is int or position < 1 or position > 3:
		return false
	if not maximum is int or maximum <= 0:
		return false
	if not current is int or current < 0 or current > maximum:
		return false
	if not protection is int or protection < 0:
		return false
	return true


func _clear_actor() -> void:
	actor_heading.text = ""
	hp_text.text = ""
	block_text.text = ""
	hp_bar.max_value = 1.0
	hp_bar.value = 0.0
	block_bar.max_value = 1.0
	block_bar.value = 0.0
	hide()
