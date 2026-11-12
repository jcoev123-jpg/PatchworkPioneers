class_name StitchedCornerMap
extends Control
## Owner combat job 5 (docs/COMBAT_JOBS.md): the small map of the corridor routes that
## sits in the lower right corner of the fight and corridor screens. During a fight the
## hovered foe's full details take the same corner; the fight view drives that swap.
## Presentation only: the host hands over the run's real route records and every
## picture comes from a file (nothing is ever drawn by code).

const FELT := preload("res://assets/paper/ui/panel_felt.png")
const FONT := preload("res://assets/fonts/PatrickHand-Regular.ttf")
const NODE_ART := "res://assets/paper/ui/map_node_%s.png"
const CANDLE_ART := "res://assets/paper/stitched/icons/candle_bright.png"
const ROUTE_ART := "res://assets/paper/stitched/ui/map_route_thread.png"
const BONE := Color("f0ddc0")
const AMBER := Color("e4b76a")
## A room the party has walked dims like the visited rows of the route atlas.
const VISITED := Color("c6b6d9")
const FUTURE := Color("9a8f86")
const HERE := Color("ffe0a0")
const ICON := 30.0
const MARK := 16.0
const FLOOR_COUNT := 12

var back: NinePatchRect
var title_label: Label
var map_holder: Control
var foe_body: Label
var _map_title := ""
var _stamp := ""
var _foe_mode := false
static var _textures: Dictionary = {}


func _init(rect: Rect2) -> void:
	name = "CornerMap"
	position = rect.position
	size = rect.size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	back = NinePatchRect.new()
	back.name = "Back"
	back.texture = FELT
	back.patch_margin_left = 40
	back.patch_margin_right = 40
	back.patch_margin_top = 40
	back.patch_margin_bottom = 40
	back.size = rect.size
	back.self_modulate = Color("241c2af5")
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	title_label = _label(Rect2(10, 6, rect.size.x - 20, 24), 17, AMBER)
	map_holder = Control.new()
	map_holder.name = "RouteRow"
	map_holder.position = Vector2.ZERO
	map_holder.size = rect.size
	map_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(map_holder)
	# Keep the details below the 24px title, but spend the unused bottom gutter
	# on legibility instead of shrinking even ordinary foes to a 12px font.
	foe_body = _label(Rect2(12, 30, rect.size.x - 24, rect.size.y - 34), 15, BONE)
	foe_body.name = "FoeDetail"
	foe_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foe_body.clip_text = true
	foe_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	foe_body.visible = false


func _label(rect: Rect2, font_size: int, color: Color, parent: Control = self) -> Label:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("1a1012"))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


static func _texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path) as Texture2D if ResourceLoader.exists(path, "Texture2D") else null
	return _textures[path]


## One authored picture per room kind, the same lookup as the route atlas; the
## event icon stands in until a kind's own picture is drawn.
func _node_art(kind: String) -> Texture2D:
	var key := kind.to_snake_case()
	if key == "treasure":
		key = "event"
	var picture := _texture(NODE_ART % key)
	if picture == null:
		picture = _texture(NODE_ART % "event")
	return picture


## The run's real route: this floor's rooms in corridor order, the ones already
## walked, and the candle marking where the party stands now.
func present_floor(floor_number: int, records: Array, visited: Array, current_id: String,
		next_records: Array = []) -> void:
	var stamp := "%d|%s|%s|%s|%s" % [floor_number, current_id,
		",".join(PackedStringArray(visited)), JSON.stringify(records), JSON.stringify(next_records)]
	if stamp == _stamp:
		return
	_stamp = stamp
	_map_title = "THE STITCHED ROAD · FLOOR %02d OF %d" % [clampi(floor_number, 1, FLOOR_COUNT), FLOOR_COUNT]
	title_label.text = _map_title
	for child in map_holder.get_children():
		child.queue_free()
	var ordered: Array = records.duplicate()
	ordered.sort_custom(func(a, b): return int(a.get("position", 0)) < int(b.get("position", 0)))
	var count := ordered.size()
	if count == 0:
		return
	var slot := (size.x - 16.0) / float(count)
	for index in count:
		var record: Dictionary = ordered[index]
		var id := str(record.get("id", ""))
		var kind := str(record.get("type", "event"))
		var here := id == current_id
		var walked := visited.has(id)
		var centre := 8.0 + slot * (float(index) + 0.5)
		var column := Control.new()
		column.name = "Room_" + id
		column.position = Vector2(centre - slot / 2.0, 34)
		column.size = Vector2(slot, size.y - 40)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		map_holder.add_child(column)
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = _node_art(kind)
		icon.position = Vector2((slot - ICON) / 2.0, 0)
		icon.size = Vector2(ICON, ICON)
		icon.modulate = HERE if here else (VISITED if walked else FUTURE)
		# Rooms on a floor are parallel choices. Only outgoing edges to the NEXT
		# floor are corridors; do not label an unchosen sibling as "ahead".
		icon.tooltip_text = "%s · %s" % [kind, "you are here" if here else ("visited" if walked else "alternate route")]
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(icon)
		if here:
			# A clear mark where the party is now: the run's own candle under the room.
			var candle := TextureRect.new()
			candle.name = "HereMark"
			candle.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			candle.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			candle.texture = _texture(CANDLE_ART)
			candle.position = Vector2((slot - MARK) / 2.0, ICON + 8.0)
			candle.size = Vector2(MARK, MARK)
			candle.modulate = HERE
			candle.tooltip_text = "The party stands here"
			candle.mouse_filter = Control.MOUSE_FILTER_IGNORE
			column.add_child(candle)
		# Same-floor rooms are alternatives, never an invented chain.
	if next_records.is_empty():
		return
	var next_ordered: Array = next_records.duplicate()
	next_ordered.sort_custom(func(a, b): return int(a.get("position", 0)) < int(b.get("position", 0)))
	var next_slot := (size.x - 16.0) / float(next_ordered.size())
	var exits := {}
	for index in next_ordered.size():
		var target: Dictionary = next_ordered[index]
		var id := str(target.get("id", ""))
		var x := 8.0 + next_slot * (float(index) + 0.5)
		exits[id] = x
		var icon := Sprite2D.new()
		icon.name = "Next_" + id
		icon.texture = _node_art(str(target.get("type", "event")))
		icon.position = Vector2(x, size.y - ICON / 2.0 - 8.0)
		if icon.texture != null:
			icon.scale = Vector2.ONE * (ICON / float(maxi(icon.texture.get_width(), icon.texture.get_height())))
		icon.modulate = FUTURE
		icon.set_meta("route_id", id)
		icon.set_meta("next_floor", true)
		map_holder.add_child(icon)
	for index in count:
		var record: Dictionary = ordered[index]
		for target_id in record.get("outgoing", []):
			if not exits.has(str(target_id)):
				continue
			var start := Vector2(8.0 + slot * (float(index) + 0.5), 34.0 + ICON)
			var finish := Vector2(float(exits[str(target_id)]), size.y - ICON - 9.0)
			var delta := finish - start
			# An authored texture scaled to a narrow seam, never a code-drawn line.
			# Sprite2D has no Control minimum size: a large felt fallback cannot
			# expand the entire fight corner into giant overlapping panels.
			var thread := Sprite2D.new()
			thread.name = "Seam_%s_%s" % [str(record.get("id", "")), str(target_id)]
			thread.texture = _texture(ROUTE_ART)
			if thread.texture == null:
				thread.texture = FELT
			thread.centered = false
			thread.position = start
			thread.scale = Vector2(delta.length() / float(thread.texture.get_width()),
				3.0 / float(thread.texture.get_height()))
			thread.rotation = delta.angle()
			thread.modulate = HERE if str(record.get("id", "")) == current_id else FUTURE
			map_holder.add_child(thread)
			map_holder.move_child(thread, 0)


## The hovered foe takes the corner; the fight view builds the lines from live rules.
func show_foe(foe_name: String, lines: PackedStringArray) -> void:
	_foe_mode = true
	title_label.text = foe_name
	foe_body.text = "\n".join(lines)
	# Measure the real word-wrapped paragraph at each size. A sum of glyph
	# widths undercounts a wrap when a long move name does not fit at the end
	# of a row; it used to leave boss statuses beyond this fixed corner.
	# WORD_SMART also splits a word wider than the card. Allow extra leading
	# for that rare fallback so the final live-status row does not get clipped.
	var oversized_word := false
	for word in foe_body.text.replace("\n", " ").split(" ", false):
		if FONT.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x > foe_body.size.x:
			oversized_word = true
			break
	for font_size in range(15, 7 if oversized_word else 9, -1):
		var paragraph := TextParagraph.new()
		paragraph.width = foe_body.size.x
		# Match Label's WORD_SMART fallback for unbroken names wider than the card.
		paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_GRAPHEME_BOUND
		paragraph.add_string(foe_body.text, FONT, font_size)
		foe_body.add_theme_font_size_override("font_size", font_size)
		# Godot's Label adds row leading beyond TextParagraph's raw height.
		# Budget for that leading or the last status may be clipped offscreen.
		if paragraph.get_line_count() * (FONT.get_height(font_size) + (7.0 if oversized_word else 3.0)) <= size.y - 38.0:
			break
	map_holder.visible = false
	foe_body.visible = true


## The pointer left the foe: the road map comes back.
func show_map() -> void:
	if not _foe_mode:
		return
	_foe_mode = false
	title_label.text = _map_title
	map_holder.visible = true
	foe_body.visible = false
