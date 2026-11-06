class_name StitchedBedroom
extends Control
## Wren's bedroom, the base between runs (STITCHED_DESIGN.md 9d). One painted
## picture; each object is a hotspot whose hover lifts a crop of that same
## picture. The dolls on the shelf are the hero pictures, posed by how they came
## home. Presentation only: it owns no run, RNG or save.

signal spot_pressed(spot_id: String)

const NIGHT_ART := "res://assets/paper/kid/bedroom_night.png"
const MORNING_ART := "res://assets/paper/kid/bedroom_morning.png"
const DOLL_ART := "res://assets/paper/heroes/%s.png"
const FELT := "res://assets/paper/ui/panel_felt.png"
const DESIGN_SIZE := Vector2(1280.0, 720.0)
## Object places in the 1280x720 picture.
const SPOTS := {
	"shelf": Rect2(37, 47, 377, 544),
	"door": Rect2(493, 47, 256, 436),
	"drawings": Rect2(781, 128, 224, 236),
	"window": Rect2(1088, 33, 186, 314),
	"candle": Rect2(1102, 352, 158, 187),
	"tin": Rect2(298, 512, 269, 111),
}
const SPOT_NAMES := {
	"shelf": "Toy shelf", "door": "Set out", "drawings": "Drawings",
	"window": "Window", "candle": "Candle", "tin": "Sewing tin",
}
const SPOT_TIPS := {
	"shelf": "The dolls: choose four for tonight",
	"door": "Open the door and set out",
	"drawings": "Wren's drawings of every foe met",
	"window": "The moon counts the nights; how dark tonight is",
	"candle": "The candle burns through each night's road",
	"tin": "Spare parts and spoils in the sewing tin",
}
## Where the light leaks under the door.
const DOOR_LIGHT := Rect2(521, 476, 200, 14)
## Feet line of each shelf and how many dolls stand on it.
const SHELF_ROWS := [Vector2(246, 3), Vector2(384, 3), Vector2(492, 2)]
## Left and right inner sides of the shelf the dolls stand between.
const SHELF_X := Vector2(138, 400)
const DOLL_HEIGHT := 100.0
const LIFT := 6.0
const GLOW := Color(1.28, 1.16, 0.92)

var backdrop: TextureRect
var room: Control
var door_light: TextureRect
var spots := {}
var dolls := {}
var labels := {}
var record: Dictionary = StitchedBedroomRecord.fresh()
var _art: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	room = Control.new()
	room.name = "Room"
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room.size = DESIGN_SIZE
	add_child(room)
	backdrop = TextureRect.new()
	backdrop.name = "Backdrop"
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.size = DESIGN_SIZE
	room.add_child(backdrop)
	door_light = TextureRect.new()
	door_light.name = "DoorLight"
	door_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	door_light.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	door_light.stretch_mode = TextureRect.STRETCH_SCALE
	room.add_child(door_light)
	for id in SPOTS:
		var button := Button.new()
		button.name = str(id).capitalize().replace(" ", "") + "Spot"
		button.text = SPOT_NAMES[id]
		_make_spot(id, button)
	for id in StitchedPartyAdmission.HERO_IDS:
		var doll := TextureRect.new()
		doll.name = "Doll_" + str(id)
		doll.mouse_filter = Control.MOUSE_FILTER_IGNORE
		doll.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		doll.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var path := DOLL_ART % id
		doll.texture = load(path) as Texture2D if ResourceLoader.exists(path) else null
		room.add_child(doll)
		dolls[id] = doll
	resized.connect(_fit)
	present(record)
	_fit()


## Card-era regression tests switch the room off to keep the quilt village they check.
static var enabled := true


static func has_art() -> bool:
	return enabled and ResourceLoader.exists(NIGHT_ART) and ResourceLoader.exists(MORNING_ART)


## Take over a host button as one object's hotspot, keeping its signals and text.
func adopt(spot_id: String, button: Button) -> void:
	if not SPOTS.has(spot_id) or not is_instance_valid(button):
		return
	var old: Button = spots.get(spot_id)
	if is_instance_valid(old) and old != button:
		old.queue_free()
	if button.get_parent() != null:
		button.get_parent().remove_child(button)
	_make_spot(spot_id, button)
	_restyle_spots()


func spot(spot_id: String) -> Button:
	return spots.get(spot_id)


## Morning after a win, night otherwise. Dolls take the pose they came home in.
func present(next: Dictionary) -> void:
	record = next.duplicate(true) if StitchedBedroomRecord.valid(next) else StitchedBedroomRecord.fresh()
	if backdrop == null:
		return
	var path := MORNING_ART if is_morning() else NIGHT_ART
	_art = load(path) as Texture2D if ResourceLoader.exists(path) else null
	backdrop.texture = _art
	_restyle_spots()
	_place_door_light()
	_place_dolls()
	if labels.has("window"):
		labels.window.text = "Night %d" % night_number()
	if labels.has("door"):
		labels.door.text = spots.door.text if is_instance_valid(spots.get("door")) else SPOT_NAMES.door


func is_morning() -> bool:
	return record.get("outcome", "") == "victory"


## The night about to begin.
func night_number() -> int:
	return int(record.get("nights", 0)) + 1


## Light under the door widens with the deepest floor ever reached.
func door_light_width() -> float:
	return DOOR_LIGHT.size.x * (0.35 + 0.65 * clampf(float(record.get("deepest", 0)) / StitchedBedroomRecord.FLOORS, 0.0, 1.0))


## "upright", "slumped", "wall" (facing the wall), "side" (lying down) or "tin".
func doll_pose(id: String) -> String:
	var doll: Dictionary = record.get("dolls", {}).get(id, {})
	if doll.is_empty():
		return "upright"
	if doll.get("lost", false):
		return "tin"
	if doll.get("hanging", false):
		return "side"
	var fray := int(doll.get("fray", 0))
	return "wall" if fray >= 150 else "slumped" if fray >= 100 else "upright"


func _make_spot(spot_id: String, button: Button) -> void:
	var rect: Rect2 = SPOTS[spot_id]
	# Host text is hidden; clipping keeps a long caption from widening the hotspot.
	button.clip_text = true
	button.custom_minimum_size = rect.size
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = SPOT_TIPS[spot_id]
	button.theme_type_variation = &""
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_hover_pressed_color", "font_disabled_color", "font_outline_color"]:
		button.add_theme_color_override(state, Color(0, 0, 0, 0))
	# A host button's sewn edge is drawn by code; the picture is the hotspot's face.
	for child in button.get_children():
		if child is Control:
			child.visible = false
	room.add_child(button)
	# Sized inside the tree: an adopted host keeps a stale cached minimum until then.
	button.position = rect.position
	button.size = rect.size
	spots[spot_id] = button
	if not button.pressed.is_connected(_on_spot_pressed.bind(spot_id)):
		button.pressed.connect(_on_spot_pressed.bind(spot_id))
	var label: Label = labels.get(spot_id)
	if label == null:
		label = Label.new()
		label.name = button.name + "Label"
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color("#f4e5cd"))
		if ResourceLoader.exists(FELT):
			var tag := StyleBoxTexture.new()
			tag.texture = load(FELT)
			tag.set_texture_margin_all(12)
			tag.content_margin_left = 12
			tag.content_margin_right = 12
			tag.content_margin_top = 3
			tag.content_margin_bottom = 3
			label.add_theme_stylebox_override("normal", tag)
		room.add_child(label)
		labels[spot_id] = label
	label.text = button.text
	label.size = Vector2(rect.size.x, 0)
	label.position = Vector2(rect.position.x, rect.end.y - 30)
	_restyle_spot(spot_id)


## Hover and focus show the object itself, brighter and a little larger.
func _restyle_spot(spot_id: String) -> void:
	var button: Button = spots.get(spot_id)
	if not is_instance_valid(button):
		return
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "disabled"]:
		button.add_theme_stylebox_override(state, empty)
	var lifted: StyleBox = empty
	if _art != null:
		var crop := AtlasTexture.new()
		crop.atlas = _art
		var scale_to_art := Vector2(_art.get_size()) / DESIGN_SIZE
		var rect: Rect2 = SPOTS[spot_id]
		crop.region = Rect2(rect.position * scale_to_art, rect.size * scale_to_art)
		var box := StyleBoxTexture.new()
		box.texture = crop
		box.modulate_color = GLOW
		box.set_expand_margin_all(LIFT)
		lifted = box
	for state in ["hover", "pressed", "focus", "hover_pressed"]:
		button.add_theme_stylebox_override(state, lifted)


func _restyle_spots() -> void:
	for id in spots:
		_restyle_spot(id)
	# Dolls and their pinned names stay above the lifted objects.
	for id in dolls:
		room.move_child(dolls[id], -1)
	for id in labels:
		room.move_child(labels[id], -1)


func _place_door_light() -> void:
	if _art == null:
		door_light.visible = false
		return
	var crop := AtlasTexture.new()
	crop.atlas = _art
	var scale_to_art := Vector2(_art.get_size()) / DESIGN_SIZE
	crop.region = Rect2(DOOR_LIGHT.position * scale_to_art, DOOR_LIGHT.size * scale_to_art)
	door_light.texture = crop
	var width := door_light_width()
	door_light.size = Vector2(width, DOOR_LIGHT.size.y)
	door_light.position = Vector2(DOOR_LIGHT.get_center().x - width * 0.5, DOOR_LIGHT.position.y)
	var deep := clampf(float(record.get("deepest", 0)) / StitchedBedroomRecord.FLOORS, 0.0, 1.0)
	door_light.modulate = Color(1.0 + 0.6 * deep, 1.0 + 0.45 * deep, 1.0 + 0.2 * deep)
	door_light.visible = true


func _place_dolls() -> void:
	var slots: Array[Vector2] = []
	for row in SHELF_ROWS:
		var count := int(row.y)
		for index in range(count):
			slots.append(Vector2(SHELF_X.x + (SHELF_X.y - SHELF_X.x) * (index + 0.5) / count, row.x))
	var tin: Rect2 = SPOTS.tin
	var in_tin := 0
	var index := 0
	for id in StitchedPartyAdmission.HERO_IDS:
		var doll: TextureRect = dolls[id]
		var pose := doll_pose(id)
		var width := DOLL_HEIGHT * 0.86
		doll.size = Vector2(width, DOLL_HEIGHT)
		doll.pivot_offset = Vector2(width * 0.5, DOLL_HEIGHT)
		doll.rotation = 0.0
		doll.flip_h = false
		doll.modulate = Color(0.86, 0.82, 0.78)
		doll.set_meta("pose", pose)
		if pose == "tin":
			# In pieces among the scraps: small, dark and lying across the tin.
			doll.size = Vector2(width, DOLL_HEIGHT) * 0.62
			doll.pivot_offset = doll.size * 0.5
			doll.position = Vector2(tin.position.x + 30 + in_tin * 46, tin.position.y + 18)
			doll.rotation = deg_to_rad(78.0 + in_tin * 14.0)
			doll.modulate = Color(0.55, 0.5, 0.5)
			in_tin += 1
			index += 1
			continue
		var feet := slots[index]
		doll.position = feet - Vector2(width * 0.5, DOLL_HEIGHT)
		match pose:
			"slumped":
				doll.rotation = deg_to_rad(-16.0)
				doll.modulate = Color(0.74, 0.7, 0.68)
			"wall":
				doll.flip_h = true
				doll.rotation = deg_to_rad(-8.0)
				doll.modulate = Color(0.5, 0.48, 0.5)
			"side":
				doll.rotation = deg_to_rad(-90.0)
				doll.position.y += width * 0.35
				doll.modulate = Color(0.66, 0.6, 0.6)
		index += 1


func _fit() -> void:
	if room == null or size.x <= 0.0 or size.y <= 0.0:
		return
	room.scale = size / DESIGN_SIZE


func _on_spot_pressed(spot_id: String) -> void:
	spot_pressed.emit(spot_id)
