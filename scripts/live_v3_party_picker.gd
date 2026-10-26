class_name LiveV3PartyPicker
extends Control
## Detached Design-v3 party request screen. The eventual run resolver owns starting
## positions, HP, decks, passives and admission; this view never constructs them.

signal party_requested(ids: Array[String])
signal cancel_requested()

const HEROES := [
	{"id": "warden", "name": "Warden", "motif": "POT HELMET  •  GIANT SHIELD", "tone": "#496b85", "thread": "#b0d4ee", "role": "Bulwark", "signature": "Guard redirects the next allied hit; Shield Toss scales with own Block; Taunt draws attacks."},
	{"id": "seamstress", "name": "Seamstress", "motif": "GIANT THREADED NEEDLE", "tone": "#73517c", "thread": "#e3b4e5", "role": "Stitch healer", "signature": "Bleed wounds; Tether shares 50% damage with a linked foe; Mend heals; Darn cleanses."},
	{"id": "tinker", "name": "Tinker", "motif": "GOGGLES  •  SCRAP PACK", "tone": "#8a673e", "thread": "#f0d28a", "role": "Scrap engineer", "signature": "Build Scrap toward Overload; Wind-up Turret deals 3 random damage at turn end for 3 turns; Jury-rig copies the last card free once."},
	{"id": "lantern_monk", "name": "Lantern Monk", "motif": "RAISED LANTERN  •  MOTHS", "tone": "#466c65", "thread": "#c7e8ac", "role": "Light keeper", "signature": "Blind makes the next enemy attack miss; lantern light heals and cleanses allies; Moth Cloud blinds all foes and Exhausts."},
	{"id": "rag_duelist", "name": "Rag Duelist", "motif": "NEEDLE RAPIER  •  RAG CAPE", "tone": "#823e62", "thread": "#f0b1c6", "role": "Counterattacker", "signature": "Riposte on hit; Lunge advances; Feint applies Exposed and draws 1; dodge avoids a blow."},
	{"id": "scarecrow", "name": "Scarecrow", "motif": "BURLAP  •  FORK  •  CROW", "tone": "#77613d", "thread": "#ebd39a", "role": "Fear harrier", "signature": "Fear brings Weak and blocks next-turn buffs; backmost Crow Peck ignores Block; Re-stuff trades 2 max HP for 10 healing."},
	{"id": "yarn_ranger", "name": "Yarn Ranger", "motif": "KNIT HOOD  •  NEEDLE BOW", "tone": "#426785", "thread": "#b3d8ee", "role": "Tangle hunter", "signature": "Tangled prevents movement and adds 2 incoming attack damage; Reel In pulls forward 1; Unspool hits Tangled foes."},
	{"id": "button_golem", "name": "Button Golem", "motif": "STACKED BUTTONS  •  FISTS", "tone": "#5c577e", "thread": "#ded0f0", "role": "Block bruiser", "signature": "Pop Button spends 5 Block to deal 9; Roll swaps position and gains Block; Sew On scales Block with popped buttons."},
]

const INK := Color("#171e30")
const CREAM := Color("#fff0d8")
const SOFT := Color("#d4c4ad")
const GOLD := Color("#f7d68b")
const STITCH := Color("#efcba1")

@onready var paper_panel: PanelContainer = $PaperPanel
@onready var grid: GridContainer = $PaperPanel/Margins/Body/HeroGrid
@onready var selection_count: Label = $PaperPanel/Margins/Body/Foot/SelectionCount
@onready var inspection_panel: PanelContainer = $PaperPanel/Margins/Body/InspectionPanel
@onready var inspection_heading: Label = $PaperPanel/Margins/Body/InspectionPanel/Inset/Stack/InspectionHeading
@onready var inspection_detail: Label = $PaperPanel/Margins/Body/InspectionPanel/Inset/Stack/InspectionDetail
@onready var continue_button: Button = $PaperPanel/Margins/Body/Foot/ContinueButton
@onready var cancel_button: Button = $PaperPanel/Margins/Body/Foot/CancelButton

var _ids: Array[String] = []
var _tiles: Dictionary = {}
var _generation: int = 0
var _open: bool = false
var _latched: bool = false
var _hovered_id: String = ""
var _focused_id: String = ""


## A drawn stand-in for not-yet-delivered portraits. These five faces are
## emblematic ragdoll silhouettes, NOT combat sprites or generated PNG art.
class HeroMotif:
	extends Control
	var hero_id: String = ""
	var cloth: Color = Color("#718c94")
	var highlight: Color = Color("#f7d68b")

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_set_transform(Vector2(size.x / 2.0 - 58.0, 0), 0.0,
			Vector2(116.0 / 128.0, size.y / 112.0))
		var outline := Color("#182038")
		var paper := Color("#ead8bb")
		# The jointed, plump handmade doll stays recognizable without art.
		draw_colored_polygon(PackedVector2Array([
			Vector2(37, 107), Vector2(29, 77), Vector2(41, 57),
			Vector2(86, 57), Vector2(99, 84), Vector2(90, 107)]), outline)
		draw_colored_polygon(PackedVector2Array([
			Vector2(42, 103), Vector2(37, 78), Vector2(45, 62),
			Vector2(82, 62), Vector2(91, 84), Vector2(85, 103)]), cloth)
		draw_circle(Vector2(63, 39), 29, outline)
		draw_circle(Vector2(63, 38), 24, paper)
		draw_circle(Vector2(55, 38), 4, outline)
		draw_line(Vector2(72, 36), Vector2(78, 40), outline, 3)
		draw_line(Vector2(59, 52), Vector2(66, 54), outline, 2)
		# Crossed stitches on the chest, part of each fallback puppet.
		for p in [Vector2(51, 73), Vector2(65, 83), Vector2(78, 94)]:
			draw_line(p - Vector2(3, 3), p + Vector2(3, 3), highlight, 2)
			draw_line(p + Vector2(-3, 3), p + Vector2(3, -3), highlight, 2)
		match hero_id:
			"warden":
				draw_rect(Rect2(40, 8, 46, 10), outline)
				draw_rect(Rect2(43, 10, 40, 6), cloth)
				draw_circle(Vector2(24, 75), 24, outline)
				draw_circle(Vector2(24, 75), 20, highlight)
			"seamstress":
				draw_line(Vector2(110, 0), Vector2(92, 104), outline, 7)
				draw_line(Vector2(110, 0), Vector2(92, 104), highlight, 3)
				draw_arc(Vector2(103, 14), 10, 0.0, TAU, 20, paper, 2)
			"tinker":
				draw_rect(Rect2(82, 63, 26, 36), outline)
				draw_rect(Rect2(86, 66, 17, 28), highlight)
				for x in [47, 74]:
					draw_circle(Vector2(x, 37), 11, outline)
					draw_circle(Vector2(x, 37), 8, cloth)
				draw_line(Vector2(58, 37), Vector2(63, 37), outline, 3)
			"lantern_monk":
				draw_colored_polygon(PackedVector2Array([
					Vector2(41, 18), Vector2(63, 2), Vector2(89, 19),
					Vector2(88, 49), Vector2(40, 49)]), cloth)
				draw_line(Vector2(86, 74), Vector2(105, 38), outline, 7)
				draw_line(Vector2(104, 38), Vector2(104, 15), highlight, 3)
				draw_rect(Rect2(94, 19, 22, 26), outline)
				draw_rect(Rect2(98, 23, 14, 18), GOLD)
				for p in [Vector2(89, 5), Vector2(119, 9), Vector2(121, 49)]:
					draw_circle(p, 3, highlight)
					draw_line(p + Vector2(-5, 0), p + Vector2(5, 0), paper, 1)
			"rag_duelist":
				draw_colored_polygon(PackedVector2Array([
					Vector2(40, 55), Vector2(8, 66), Vector2(22, 110),
					Vector2(41, 94)]), highlight)
				draw_line(Vector2(91, 83), Vector2(122, 14), paper, 4)
				draw_line(Vector2(85, 67), Vector2(104, 75), outline, 5)
				draw_line(Vector2(91, 82), Vector2(91, 91), highlight, 3)
			"scarecrow":
				draw_colored_polygon(PackedVector2Array([
					Vector2(30, 24), Vector2(91, 24), Vector2(81, 12),
					Vector2(39, 12)]), cloth)
				draw_line(Vector2(99, 104), Vector2(99, 9), outline, 5)
				for x in [86, 99, 112]:
					draw_line(Vector2(x, 9), Vector2(x, 36), highlight, 4)
				draw_line(Vector2(86, 35), Vector2(112, 35), highlight, 3)
				draw_circle(Vector2(112, 52), 9, outline)
				draw_colored_polygon(PackedVector2Array([
					Vector2(116, 51), Vector2(128, 56), Vector2(115, 60)]), highlight)
				draw_circle(Vector2(114, 48), 2, paper)
			"yarn_ranger":
				draw_arc(Vector2(63, 34), 30, PI, TAU, 25, highlight, 7)
				for x in [45, 55, 65, 75]:
					draw_line(Vector2(x, 12), Vector2(x + 5, 19), paper, 2)
				draw_line(Vector2(104, 7), Vector2(104, 106), highlight, 4)
				draw_arc(Vector2(102, 56), 41, -PI / 2, PI / 2, 22, outline, 4)
				draw_line(Vector2(102, 15), Vector2(102, 97), paper, 2)
				draw_circle(Vector2(21, 93), 11, highlight)
				draw_circle(Vector2(32, 101), 7, cloth)
			"button_golem":
				for p in [Vector2(63, 70), Vector2(63, 92),
						Vector2(25, 83), Vector2(106, 83)]:
					draw_circle(p, 15, outline)
					draw_circle(p, 12, highlight)
					for offset in [Vector2(-4, -3), Vector2(4, -3),
							Vector2(-4, 4), Vector2(4, 4)]:
						draw_circle(p + offset, 2, outline)
				draw_circle(Vector2(64, 23), 12, cloth)
		draw_set_transform(Vector2.ZERO)


func _ready() -> void:
	_style_screen()
	continue_button.pressed.connect(_continue_pressed)
	cancel_button.pressed.connect(_cancel_pressed)
	open_picker()


## Reuse for each opening. Old tiles are detached immediately and their
## captured generation can never activate the new opening.
func open_picker() -> void:
	if not is_node_ready():
		return
	_generation += 1
	_open = true
	_latched = false
	_ids.clear()
	_hovered_id = ""
	_focused_id = ""
	for old in grid.get_children():
		grid.remove_child(old)
		old.queue_free()
	_tiles.clear()
	for definition in HEROES:
		_mount_tile(definition, _generation)
	visible = true
	_refresh()
	_update_inspection()  # Neutral until actual pointer motion or keyboard focus.



## An input-transparent comparison readout. Pointer preview takes precedence
## while over a tile; leaving it restores keyboard focus (if any).
## Every callback carries the tile generation so retired buttons are inert.
func _inspection_active(generation: int) -> bool:
	return _open and not _latched and generation == _generation


func _inspect_motion(event: InputEvent, hero_id: String, generation: int) -> void:
	if not _inspection_active(generation) or not event is InputEventMouseMotion:
		return
	_hovered_id = hero_id
	_update_inspection()


func _inspect_mouse_exit(hero_id: String, generation: int) -> void:
	if not _inspection_active(generation) or _hovered_id != hero_id:
		return
	_hovered_id = ""
	_update_inspection()


func _inspect_focus(hero_id: String, generation: int, entered: bool) -> void:
	if not _inspection_active(generation):
		return
	if entered:
		_focused_id = hero_id
	elif _focused_id == hero_id:
		_focused_id = ""
	_update_inspection()


func _update_inspection() -> void:
	var chosen: String = _hovered_id if not _hovered_id.is_empty() else _focused_id
	for hero in HEROES:
		if hero["id"] == chosen:
			inspection_heading.text = "%s  •  %s  /  %s" % [
				hero["name"], hero["motif"], hero["role"]]
			inspection_detail.text = hero["signature"]
			return
	inspection_heading.text = "HOVER OR FOCUS A HERO TO INSPECT"
	inspection_detail.text = "Compare sewn looks and intended roles before choosing three."


func selected_ids() -> Array[String]:
	return _ids.duplicate()


func _pressed_hero(hero_id: String, generation: int) -> void:
	if not _open or _latched or generation != _generation:
		return
	if _ids.has(hero_id):
		_ids.erase(hero_id)
	elif _ids.size() < 3:
		_ids.append(hero_id)
	_refresh()


func _continue_pressed() -> void:
	if not _open or _latched or _ids.size() != 3:
		return
	_latched = true
	_open = false
	_refresh()
	party_requested.emit(_ids.duplicate())


func _cancel_pressed() -> void:
	if not _open or _latched:
		return
	_latched = true
	_open = false
	_refresh()
	visible = false
	cancel_requested.emit()


func _refresh() -> void:
	selection_count.text = "Selected %d/3" % _ids.size()
	continue_button.disabled = not _open or _latched or _ids.size() != 3
	cancel_button.disabled = not _open or _latched
	for definition in HEROES:
		var hero_id: String = definition["id"]
		var tile: Button = _tiles[hero_id]
		var number := _ids.find(hero_id) + 1
		tile.disabled = not _open or _latched
		tile.get_node("Inset/Stack/PickLabel").text = (
			"PICK %d OF 3  ◆  SELECTED" % number if number > 0 else "✕  STITCH TO PARTY")
		_style_tile(tile, Color(definition["tone"]), number > 0)


func _mount_tile(definition: Dictionary, generation: int) -> void:
	var hero_id: String = definition["id"]
	var tile := Button.new()
	tile.name = "Hero_" + hero_id
	tile.custom_minimum_size = Vector2(234, 188)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tile.focus_mode = Control.FOCUS_ALL
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tile.clip_contents = true
	tile.pressed.connect(_pressed_hero.bind(hero_id, generation))
	tile.gui_input.connect(_inspect_motion.bind(hero_id, generation))
	tile.mouse_exited.connect(_inspect_mouse_exit.bind(hero_id, generation))
	tile.focus_entered.connect(_inspect_focus.bind(hero_id, generation, true))
	tile.focus_exited.connect(_inspect_focus.bind(hero_id, generation, false))
	grid.add_child(tile)
	_tiles[hero_id] = tile

	var inset := MarginContainer.new()
	inset.name = "Inset"
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		inset.add_theme_constant_override("margin_" + side, 9)
	inset.add_theme_constant_override("margin_top", 8)
	inset.add_theme_constant_override("margin_bottom", 7)
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(inset)

	var stack := VBoxContainer.new()
	stack.name = "Stack"
	stack.add_theme_constant_override("separation", 2)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inset.add_child(stack)

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = definition["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", CREAM)
	name_label.add_theme_font_size_override("font_size", 23)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(name_label)

	var face := Control.new()
	face.name = "Face"
	face.custom_minimum_size = Vector2(0, 100)
	face.size_flags_vertical = Control.SIZE_EXPAND_FILL
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(face)

	var path := "res://assets/paper/heroes/%s.png" % hero_id
	var portrait: Texture2D = null
	if ResourceLoader.exists(path, "Texture2D"):
		portrait = ResourceLoader.load(path, "Texture2D") as Texture2D
	if portrait != null:
		var picture := TextureRect.new()
		picture.name = "Portrait"
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		picture.texture = portrait
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.add_child(picture)
	else:
		var drawing := HeroMotif.new()
		drawing.name = "FallbackMotif"
		drawing.hero_id = hero_id
		drawing.cloth = Color(definition["tone"])
		drawing.highlight = Color(definition["thread"])
		drawing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		face.add_child(drawing)

	var motif := Label.new()
	motif.name = "MotifLabel"
	motif.text = definition["motif"]
	motif.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	motif.add_theme_font_size_override("font_size", 13)
	motif.add_theme_color_override("font_color", Color(definition["thread"]))
	motif.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(motif)

	var pick := Label.new()
	pick.name = "PickLabel"
	pick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pick.add_theme_font_size_override("font_size", 15)
	pick.add_theme_color_override("font_color", GOLD)
	pick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(pick)


func _tile_box(tone: Color, edge: Color, wide: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = tone.darkened(0.35)
	box.border_color = edge
	box.set_border_width_all(wide)
	box.set_corner_radius_all(11)
	box.set_content_margin_all(3)
	box.shadow_color = Color("#090e18ab")
	box.shadow_size = 3
	return box


func _style_tile(tile: Button, tone: Color, picked: bool) -> void:
	var edge := GOLD if picked else SOFT
	tile.add_theme_stylebox_override("normal", _tile_box(tone, edge, 4 if picked else 2))
	tile.add_theme_stylebox_override("hover", _tile_box(tone.lightened(0.14), GOLD, 4))
	tile.add_theme_stylebox_override("pressed", _tile_box(tone.lightened(0.22), GOLD, 5))
	tile.add_theme_stylebox_override("disabled", _tile_box(tone, edge, 3))
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color("#fff8dc")
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(11)
	tile.add_theme_stylebox_override("focus", focus)


func _style_screen() -> void:
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("#252d40")
	frame.border_color = Color("#b89069")
	frame.set_border_width_all(5)
	frame.set_corner_radius_all(17)
	frame.shadow_color = Color("#0a0b18b0")
	frame.shadow_size = 10
	paper_panel.add_theme_stylebox_override("panel", frame)
	var title: Label = $PaperPanel/Margins/Body/Title
	title.add_theme_color_override("font_color", CREAM)
	title.add_theme_font_size_override("font_size", 34)
	var subtitle: Label = $PaperPanel/Margins/Body/SubTitle
	subtitle.add_theme_color_override("font_color", SOFT)
	subtitle.add_theme_font_size_override("font_size", 16)
	for node_path in ["PaperPanel/Margins/Body/TopStitches",
			"PaperPanel/Margins/Body/BottomStitches"]:
		var label := get_node(node_path) as Label
		label.add_theme_color_override("font_color", STITCH)
		label.add_theme_font_size_override("font_size", 15)
	var readout := StyleBoxFlat.new()
	readout.bg_color = Color("#1d2639")
	readout.border_color = STITCH
	readout.set_border_width_all(2)
	readout.set_corner_radius_all(9)
	inspection_panel.add_theme_stylebox_override("panel", readout)
	inspection_heading.add_theme_color_override("font_color", GOLD)
	inspection_heading.add_theme_font_size_override("font_size", 18)
	inspection_detail.add_theme_color_override("font_color", CREAM)
	inspection_detail.add_theme_font_size_override("font_size", 16)
	selection_count.add_theme_color_override("font_color", CREAM)
	selection_count.add_theme_font_size_override("font_size", 24)
	for button in [continue_button, cancel_button]:
		button.focus_mode = Control.FOCUS_ALL
		button.add_theme_font_size_override("font_size", 22)
		button.add_theme_color_override("font_color", CREAM)
		button.add_theme_color_override("font_disabled_color", Color("#abaca8"))
		var idle := _tile_box(Color("#386e65") if button == continue_button
			else Color("#765061"), SOFT, 3)
		var hover := _tile_box(Color("#487d73") if button == continue_button
			else Color("#906179"), GOLD, 4)
		button.add_theme_stylebox_override("normal", idle)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", hover)
		button.add_theme_stylebox_override("disabled", _tile_box(Color("#343a48"), Color("#727585"), 2))
