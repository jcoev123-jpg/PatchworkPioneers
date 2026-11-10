class_name StitchedCorridorJunction
extends Control
## Owner 11-08: the road map is a maze junction in the corridor. The way splits left,
## forward and/or right (never a dead end). Owner 11-09: no stop pictures or icons, only a
## stitched arrow on the floor for each way, so what lies down it stays a surprise.
## Presentation only: the host says which stops are legal and does the entering.

signal chosen(node_id: String)

const CHROME := preload("res://scripts/stitched/stitched_battle_chrome.gd")
const STOP_DIR := "res://assets/paper/walk3d/"
const ARROW_LENGTH := 0.75
const ARROW_TILT := 0.4
const SIDE_WORDS := {"left": "Left", "forward": "Straight on", "right": "Right"}
## Each opening on the 1280x720 screen: clicking anywhere in it takes that way.
const DOOR_RECTS := {
	"left": Rect2(40, 150, 420, 460), "forward": Rect2(480, 150, 320, 440), "right": Rect2(820, 150, 420, 460),
}

var stage: StitchedCorridorStage
var caption: Label
## node_id -> door Button over that stop.
var doors: Dictionary = {}
## node_id -> "left" | "forward" | "right".
var sides: Dictionary = {}
var _corner := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_ensure_stage()
	resized.connect(_place_doors)


func _ensure_stage() -> void:
	if stage != null:
		return
	stage = StitchedCorridorStage.new()
	add_child(stage)
	move_child(stage, 0)
	caption = Label.new()
	caption.name = "JunctionCaption"
	caption.position = Vector2(240, 610)
	caption.size = Vector2(800, 50)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 26)
	caption.add_theme_color_override("font_color", CHROME.BONE)
	caption.add_theme_color_override("font_outline_color", Color("140c0e"))
	caption.add_theme_constant_override("outline_size", 4)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caption)


## Which way each stop lies: sorted across the map, the outer ones open to the sides.
static func assign_sides(stops: Array) -> Dictionary:
	var ordered := stops.duplicate()
	ordered.sort_custom(func(a, b): return float(a.get("position", 0)) < float(b.get("position", 0)))
	var result := {}
	var count := ordered.size()
	for index in count:
		var side := "forward"
		if count >= 2 and index == 0:
			side = "left"
		elif count >= 2 and index == count - 1:
			side = "right"
		result[str(ordered[index].id)] = side
	return result


## stops: [{id, kind, position}], only legal stops, at least one.
func present(area_name: String, band_name: String, stops: Array) -> void:
	_ensure_stage()
	sides = assign_sides(stops)
	var open: Array = []
	for side in sides.values():
		if not open.has(side):
			open.append(side)
	stage.band = band_name
	stage.build_junction(area_name, open)
	var ahead: Array = []
	for stop in stops:
		if sides[str(stop.id)] == "forward":
			ahead.append(str(stop.id))
	for door in doors.values():
		door.queue_free()
	doors.clear()
	for stop in stops:
		var id := str(stop.id)
		var side: String = sides[id]
		var kind := str(stop.kind)
		var slot := ahead.find(id)
		var where := arrow_point(side, slot, ahead.size())
		stage.place_flat(id, stage.art("floor_arrow"), where, ARROW_LENGTH, arrow_roll(side, slot, ahead.size()), ARROW_TILT)
		# A faint glow over each arrow, so it shows through the fog at any candle.
		var glow := OmniLight3D.new()
		glow.name = "Glow_" + id.validate_node_name()
		glow.light_color = Color(1.0, 0.72, 0.45)
		glow.light_energy = 0.7
		glow.omni_range = 1.8
		glow.position = where + Vector3(0, 0.8, 0.3)
		stage.figures.add_child(glow)
		var door := Button.new()
		door.name = "Door_" + id.validate_node_name()
		door.flat = true
		door.focus_mode = Control.FOCUS_ALL
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			door.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		door.set_meta("route_id", id)
		door.set_meta("node_kind", kind)
		var rect: Rect2 = DOOR_RECTS[side]
		if side == "forward" and ahead.size() > 1:
			var share := rect.size.x / ahead.size()
			rect = Rect2(rect.position + Vector2(share * slot, 0), Vector2(share, rect.size.y))
		door.position = rect.position
		door.size = rect.size
		door.mouse_entered.connect(_light.bind(id, true))
		door.mouse_exited.connect(_light.bind(id, false))
		door.focus_entered.connect(_light.bind(id, true))
		door.focus_exited.connect(_light.bind(id, false))
		door.pressed.connect(func(): chosen.emit(id))
		add_child(door)
		doors[id] = door
	_wire_focus()
	caption.text = "The way splits." if stops.size() > 1 else "The way goes on."
	_place_doors.call_deferred()


## Only the way, never what waits down it.
static func describe(side: String) -> String:
	return SIDE_WORDS.get(side, "Straight on")


## Where a way's arrow lies on the crossing floor; `slot`/`of` share the way ahead.
func arrow_point(side: String, slot: int = 0, of: int = 1) -> Vector3:
	var cross := stage.junction_z()
	match side:
		"left":
			return Vector3(-1.15, 0, cross + 0.8)
		"right":
			return Vector3(1.15, 0, cross + 0.8)
	var spread := 0.0 if of <= 1 else lerpf(-0.7, 0.7, float(slot) / float(of - 1))
	return Vector3(spread, 0, cross - 0.6)


## Left and right arrows turn on the floor; several ways ahead fan out a little.
static func arrow_roll(side: String, slot: int = 0, of: int = 1) -> float:
	match side:
		"left":
			return PI / 2.0
		"right":
			return -PI / 2.0
	return 0.0 if of <= 1 else lerpf(0.3, -0.3, float(slot) / float(of - 1))


## A stop's own Flow picture (for the stop itself, never the junction), or null.
static func stop_art(kind: String) -> Texture2D:
	var path := STOP_DIR + "stop_" + kind.to_snake_case() + ".png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## Each door is its whole opening, grown to take in its arrow once the stage can project it.
func _place_doors() -> void:
	if stage == null or not is_inside_tree():
		return
	var ahead := 0
	for id in doors:
		if sides.get(id, "") == "forward":
			ahead += 1
	var slot := 0
	for id in doors:
		var side := str(sides.get(id, "forward"))
		var rect: Rect2 = DOOR_RECTS[side]
		if side == "forward" and ahead > 1:
			var share := rect.size.x / ahead
			rect = Rect2(rect.position + Vector2(share * slot, 0), Vector2(share, rect.size.y))
			slot += 1
		var arrow := stage.screen_rect(id)
		if arrow.size.x > 4 and arrow.size.y > 4:
			rect = rect.merge(arrow.grow(16))
		var door: Button = doors[id]
		door.position = rect.position
		door.size = rect.size


func _light(id: String, on: bool) -> void:
	var figure: Sprite3D = stage.figure_nodes.get(id) if stage != null else null
	if figure != null:
		figure.modulate = Color(1.45, 1.25, 1.0) if on else Color.WHITE
	if on and doors.has(id):
		caption.text = describe(str(sides.get(id, "forward")))


func _row() -> Array:
	var row: Array = doors.values()
	row.sort_custom(func(a, b): return a.position.x < b.position.x)
	return row


## Left/Up/Right walk the doors in the order they stand across the screen.
func _wire_focus() -> void:
	var row := _row()
	for index in row.size():
		var door: Button = row[index]
		door.focus_neighbor_left = door.get_path_to(row[maxi(index - 1, 0)])
		door.focus_neighbor_right = door.get_path_to(row[mini(index + 1, row.size() - 1)])
		door.focus_neighbor_top = door.get_path_to(row[row.size() / 2])


func focus_first() -> void:
	var row := _row()
	if not row.is_empty():
		(row[row.size() / 2] as Button).grab_focus()


## Owner 11-10: one quiet line in the caption corner, e.g. that the run was saved.
func say(text: String) -> void:
	_ensure_stage()
	caption.text = text


## A small quiet corner button (Save run, Return to title).
func add_action(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = Vector2(1060, 20 + _corner * 52)
	button.size = Vector2(196, 44)
	button.add_theme_font_size_override("font_size", 17)
	CHROME.style_button(button)
	button.pressed.connect(action)
	add_child(button)
	_corner += 1
	return button
