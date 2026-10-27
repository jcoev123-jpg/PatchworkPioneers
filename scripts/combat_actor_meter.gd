class_name CombatActorMeter
extends VBoxContainer
## Snapshot-only combat presenter. The owner of CombatParty/CombatEnemies must
## supply a new get_hero/get_enemy dictionary after each combat state change.
##
## The HP numbers are drawn inside their own bar instead of on a second text row, so the
## mounted ribbon stays short; the trough is tall enough to hold the outlined numerals
## completely. The Block value is one sewn shield badge that only exists while the actor
## is actually protected.

const INK := Color("e9dec9")
const PANEL := Color("29353c")
const BORDER := Color("b7a48b")
const HP_HERO := Color("719796")
const HP_ENEMY := Color("b78373")
const BLOCK := Color("c6aa76")
const THREAD := Color("c9b996")
const TROUGH := Color("17242c")
## Status keys that carry a remaining owner-turn count, in stable display order.
const STATUS_KEYS := ["bleed", "weak", "exposed", "tangled", "riposte"]
## One-shot Blind is an integer 0/1 marker: 1 arms the actor's next attempted attack
## to miss, and the token is spent afterwards. It is never a stack or a turn counter.
const BLIND_KEY := "blind_next_attack"
## Dodge is likewise a one-shot integer token, never a timed counter.
const DODGE_KEY := "dodge_next_attack"

var actor_heading: Label
var hp_text: Label
var hp_bar: ProgressBar
var block_badge: HBoxContainer
var block_shield: BlockShield
var block_text: Label
var block_bar: ProgressBar
var status_text: Label
var modifier_explanation: Label
var bleed_warning: Label

var _panel_style: StyleBoxFlat


## Decorative sewn thread along the top and bottom hem of the bar. It is a child of the
## bar, ignores pointer and focus input and never touches the bar's value.
class BarStitch extends Control:
	var draw_count := 0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(queue_redraw)

	func _draw() -> void:
		if size.x < 12.0 or size.y < 4.0:
			return
		draw_count += 1
		var thread := CombatActorMeter.THREAD
		thread.a = 0.55
		for y in [1.0, size.y - 1.0]:
			draw_dashed_line(Vector2(2.0, y), Vector2(size.x - 2.0, y), thread, 1.0, 5.0)


## Sewn felt shield carrying the Block count. One stitched patch reads as Block without
## spending a whole word of a narrow ribbon on the label. It is deliberately wide enough
## to be recognisable at ribbon scale.
class BlockShield extends Control:
	const FELT := Color("c6aa76")
	const EDGE := Color("3a3229")
	const STITCH := Color("e9dec9")
	const GLYPH_SIZE := Vector2(24, 28)
	var draw_count := 0

	func _ready() -> void:
		custom_minimum_size = GLYPH_SIZE
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		resized.connect(queue_redraw)

	## Test hook: the shield body in this control's local space; it stays a badge glyph.
	func shield_rect() -> Rect2:
		return Rect2(Vector2(1, 1), size - Vector2(2, 2))

	func _draw() -> void:
		var body := shield_rect()
		if body.size.x < 6.0 or body.size.y < 8.0:
			return
		draw_count += 1
		var points := PackedVector2Array([
			Vector2(body.position.x, body.position.y),
			Vector2(body.end.x, body.position.y),
			Vector2(body.end.x, body.position.y + body.size.y * 0.55),
			Vector2(body.get_center().x, body.end.y),
			Vector2(body.position.x, body.position.y + body.size.y * 0.55)])
		draw_colored_polygon(points, FELT)
		var stitched := points.duplicate()
		stitched.append(points[0])
		draw_polyline(stitched, EDGE, 1.0, true)
		# Two crossed stitches inside the felt so the badge reads as sewn, not printed.
		# Both arms scale with the badge so the doubled glyph keeps the same stitch look.
		var middle := body.get_center().x
		var arm := body.size.x * 0.24
		draw_line(Vector2(middle - arm, body.position.y + body.size.y * 0.42),
			Vector2(middle + arm, body.position.y + body.size.y * 0.42), STITCH, 1.5, true)
		draw_line(Vector2(middle, body.position.y + body.size.y * 0.26),
			Vector2(middle, body.position.y + body.size.y * 0.58), STITCH, 1.5, true)


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
	hp_bar = _make_bar(content, "HPBar", HP_HERO)
	hp_text = _make_hp_overlay(hp_bar)
	_make_block_badge(content)
	block_bar = _make_bar(content, "BlockBar", BLOCK)
	status_text = _make_label(content, "StatusText")
	status_text.add_theme_font_size_override("font_size", 12)
	modifier_explanation = _make_label(content, "ModifierExplanation")
	modifier_explanation.add_theme_font_size_override("font_size", 11)
	modifier_explanation.focus_mode = Control.FOCUS_NONE
	bleed_warning = _make_label(content, "BleedWarning")
	bleed_warning.focus_mode = Control.FOCUS_NONE
	bleed_warning.add_theme_font_size_override("font_size", 11)
	bleed_warning.add_theme_color_override("font_color", HP_ENEMY)
	_clear_actor()
	_place_hp_overlay()


func _draw() -> void:
	draw_style_box(_panel_style, Rect2(Vector2.ZERO, size))


func _make_label(parent: Container, node_name: String) -> Label:
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
	background.bg_color = TROUGH
	background.border_color = BORDER.darkened(0.35)
	background.set_border_width_all(1)
	background.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", background)
	var fill := StyleBoxFlat.new()
	fill.bg_color = tint
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	var stitch := BarStitch.new()
	stitch.name = "BarStitch"
	bar.add_child(stitch)
	return bar


## The exact current/max numbers live inside the bar itself, centred and outlined so they
## read over both the filled and the empty part of the trough. The label is a child of the
## bar, so it never adds a second HP row to the layout, and the trough is given at least the
## numerals' own height so no ink can spill outside the stitched bar.
func _make_hp_overlay(bar: ProgressBar) -> Label:
	var label := Label.new()
	label.name = "HPText"
	label.add_theme_color_override("font_color", INK)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_outline_color", TROUGH)
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.focus_mode = Control.FOCUS_NONE
	bar.add_child(label)
	bar.resized.connect(_place_hp_overlay)
	_fit_hp_bar(label)
	return label


## The bar owns the height of its own numerals; any host that mounts the meter with a
## different font size gets a trough that still encloses the text completely.
func _fit_hp_bar(label: Label) -> void:
	if hp_bar == null:
		return
	var needed: float = label.get_combined_minimum_size().y
	if hp_bar.custom_minimum_size.y < needed:
		hp_bar.custom_minimum_size.y = needed


## Fill the bar exactly with its number label: same rectangle, so the text is centred on
## the trough and wholly contained inside the stitched fill at any compact height.
func _place_hp_overlay() -> void:
	if hp_text == null or hp_bar == null:
		return
	_fit_hp_bar(hp_text)
	hp_text.position = Vector2.ZERO
	hp_text.size = hp_bar.size


## One small sewn shield plus its count. The whole badge is hidden while protection is
## zero, so no empty placeholder row or bare "Block: 0" text is ever laid out.
func _make_block_badge(parent: VBoxContainer) -> void:
	block_badge = HBoxContainer.new()
	block_badge.name = "BlockBadge"
	block_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block_badge.focus_mode = Control.FOCUS_NONE
	block_badge.alignment = BoxContainer.ALIGNMENT_CENTER
	block_badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	block_badge.add_theme_constant_override("separation", 3)
	parent.add_child(block_badge)
	block_shield = BlockShield.new()
	block_shield.name = "BlockShield"
	block_badge.add_child(block_shield)
	block_text = _make_label(block_badge, "BlockText")
	block_text.add_theme_color_override("font_color", BLOCK)
	block_text.add_theme_font_size_override("font_size", 13)
	block_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	block_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	block_badge.hide()


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
	hp_text.text = "%d/%d" % [current, maximum]
	# The count is the uncapped model value; only its presentation is conditional.
	block_text.text = "%d" % protection if protection > 0 else ""
	block_badge.visible = protection > 0
	var statuses: Dictionary = snapshot.get("statuses", {})
	var active: Array[String] = []
	for key in STATUS_KEYS:
		var count: int = statuses.get(key, 0)
		if count > 0:
			active.append("%s %d" % [key.capitalize(), count])
	# Blind is one-shot, so it reads as one word: no count, stack or duration.
	if statuses.get(BLIND_KEY, 0) == 1:
		active.append("Blind")
	if statuses.get(DODGE_KEY, 0) == 1:
		active.append("Dodge")
	status_text.text = "Statuses: none" if active.is_empty() else "Statuses: " + " · ".join(active)

	# Presentation-only rules: counters and damage math remain owned by CombatStatuses.
	var explanations: Array[String] = []
	if current > 0:
		if statuses.get("weak", 0) > 0:
			explanations.append("Weak: -25% attack damage")
		if statuses.get("exposed", 0) > 0:
			explanations.append("Exposed: +50% attack damage taken")
	modifier_explanation.text = "\n".join(explanations)
	modifier_explanation.visible = not explanations.is_empty()

	# A copied, pure owner-turn result is a forecast only; never apply it to actors.
	bleed_warning.text = ""
	bleed_warning.hide()
	if current > 0 and statuses.get("bleed", 0) > 0:
		var tick: Dictionary = CombatStatuses.new().end_owner_turn(
			current, protection, statuses.duplicate(true))
		if tick["ok"] and tick["bleed_hp_loss"] > 0:
			var lethal: bool = tick["hp"] == 0
			bleed_warning.text = "Bleed next: -%d HP (bypasses Block)%s" % [
				tick["bleed_hp_loss"], " — LETHAL" if lethal else ""]
			bleed_warning.add_theme_color_override("font_color", BORDER if lethal else HP_ENEMY)
			bleed_warning.show()

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
	if snapshot.has("statuses"):
		var statuses = snapshot["statuses"]
		if not statuses is Dictionary:
			return false
		for key in statuses:
			if not key is String:
				return false
			var count = statuses[key]
			# Blind is a one-shot 0/1 marker: any other count or type fails closed.
			if key in [BLIND_KEY, DODGE_KEY]:
				if not count is int or (count != 0 and count != 1):
					return false
				continue
			if key not in STATUS_KEYS:
				return false
			if not count is int or count < 0:
				return false
	return true


func _clear_actor() -> void:
	actor_heading.text = ""
	hp_text.text = ""
	block_text.text = ""
	block_badge.hide()
	status_text.text = ""
	modifier_explanation.text = ""
	modifier_explanation.hide()
	bleed_warning.text = ""
	bleed_warning.hide()
	hp_bar.max_value = 1.0
	hp_bar.value = 0.0
	block_bar.max_value = 1.0
	block_bar.value = 0.0
	hide()
