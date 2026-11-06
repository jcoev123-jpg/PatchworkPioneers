class_name StitchedKidView
extends Control
## S9b (design v4 section 9c): Wren's side view of a fight, laid over the battle stage. His hands
## hold the dolls' strings above the ranks; a snipped doll's string hangs cut until re-tied; at
## fear 50+ the hands shake. A read-only projection: it never touches battle state or RNG, and
## every pixel is an authored picture from data/kid/kid_view_art.json.

const ART_PATH := "res://data/kid/kid_view_art.json"
const BAR_PATH := "res://assets/paper/ui/hud_bar_frame.png"
const HANDS_RECT := Rect2(0, 92, 680, 383)
## The hands layer is clipped below the HEROES / FOES labels (y 105-130) so the sleeves never cover them.
const LAYER_TOP := 132.0
## Where each cross-bar's string knots sit inside HANDS_RECT (0..1); the back two ranks
## hang from the left bar and the front two from the right one.
const BAR_KNOTS := [Vector2(0.62, 0.30), Vector2(0.50, 0.30), Vector2(0.34, 0.27), Vector2(0.22, 0.27)]
const THREAD_WIDTH := 14.0
const CUT_LENGTH := 96.0
const SHAKE_PIXELS := 5.0
const BONE := Color("e9ddc7")
const DREAD := Color("c08ad8")

var fear := 0
var shaking := false
var reduced_motion := false
var hands: TextureRect
var strings: Dictionary = {}   # hero rank -> TextureRect (whole or cut thread)
var meter: Control
var meter_fill: TextureProgressBar
var meter_label: Label
var _art: Dictionary = {}
var _thread: Texture2D
var _thread_cut: Texture2D
var _clock := 0.0


static func art() -> Dictionary:
	var file := FileAccess.open(ART_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


## The kid's-view picture for one fight: the house area of its floor, the boss deepest of
## all; "" when the picture is missing, so the caller keeps its own stage.
static func backdrop_path(floor_number: int, kind: String) -> String:
	var book := art()
	var path := ""
	if kind == "Boss":
		path = str(book.get("boss", {}).get("path", ""))
	else:
		for area in book.get("areas", []):
			path = str(area.get("path", ""))
			if maxi(1, floor_number) <= int(area.get("last_floor", 0)):
				break
	return path if not path.is_empty() and ResourceLoader.exists(path, "Texture2D") else ""


static func icon_path(action_id: String) -> String:
	var path := str(art().get("icons", {}).get(action_id, ""))
	return path if not path.is_empty() and ResourceLoader.exists(path, "Texture2D") else ""


static func _texture(path: String) -> Texture2D:
	return load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path, "Texture2D") else null


func _ready() -> void:
	name = "StitchedKidView"
	position = Vector2.ZERO
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art = art()
	_thread = _texture(str(_art.get("thread", "")))
	_thread_cut = _texture(str(_art.get("thread_cut", "")))
	var hand_layer := Control.new()
	hand_layer.name = "KidHandsLayer"
	hand_layer.position = Vector2(0, LAYER_TOP)
	hand_layer.size = Vector2(1280, 560 - LAYER_TOP)
	hand_layer.clip_contents = true
	hand_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hand_layer)
	for rank in range(1, 5):
		var string := TextureRect.new()
		string.name = "KidString%d" % rank
		string.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		string.stretch_mode = TextureRect.STRETCH_SCALE
		string.mouse_filter = Control.MOUSE_FILTER_IGNORE
		string.visible = false
		hand_layer.add_child(string)
		strings[rank] = string
	hands = TextureRect.new()
	hands.name = "KidHands"
	hands.texture = _texture(str(_art.get("hands", "")))
	hands.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hands.position = HANDS_RECT.position - hand_layer.position
	hands.size = HANDS_RECT.size
	hands.stretch_mode = TextureRect.STRETCH_SCALE
	hands.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hands.visible = hands.texture != null
	hand_layer.add_child(hands)
	_build_meter()
	set_process(false)


## The fear jar in the top bar: an ink fill over the shared bar frame, the jar picture and
## Wren's fear readout.
func _build_meter() -> void:
	meter = Control.new()
	meter.name = "KidFearMeter"
	meter.position = Vector2(998, 10)
	meter.size = Vector2(262, 34)
	meter.mouse_filter = Control.MOUSE_FILTER_PASS
	meter.tooltip_text = "Wren's fear. At 50 his hands shake and a hand action can fail; at 100 he loses the strings for one doll's turn."
	add_child(meter)
	meter_fill = TextureProgressBar.new()
	meter_fill.name = "KidFearFill"
	meter_fill.position = Vector2(30, 2)
	meter_fill.size = Vector2(232, 30)
	meter_fill.min_value = 0
	meter_fill.max_value = 100
	meter_fill.step = 1
	meter_fill.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
	meter_fill.texture_under = _texture(BAR_PATH)
	meter_fill.texture_progress = _texture(str(_art.get("fear_ink", ""))) if _art.has("fear_ink") else null
	if meter_fill.texture_progress == null:
		meter_fill.texture_progress = meter_fill.texture_under
		meter_fill.tint_progress = DREAD
	meter_fill.nine_patch_stretch = true
	meter_fill.stretch_margin_left = 12
	meter_fill.stretch_margin_right = 12
	meter_fill.stretch_margin_top = 9
	meter_fill.stretch_margin_bottom = 9
	meter_fill.size = Vector2(232, 30)   # again: before nine_patch_stretch the bar clamps to its texture
	meter_fill.tint_under = Color("4f4448")
	meter_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.add_child(meter_fill)
	var jar := TextureRect.new()
	jar.name = "KidFearJar"
	jar.texture = _texture(str(_art.get("fear_jar", "")))
	jar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	jar.position = Vector2(0, 0)
	jar.size = Vector2(34, 34)
	jar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	jar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.add_child(jar)
	meter_label = Label.new()
	meter_label.name = "KidFearReadout"
	meter_label.position = Vector2(40, 2)
	meter_label.size = Vector2(212, 29)
	meter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	meter_label.add_theme_font_size_override("font_size", 16)
	meter_label.add_theme_color_override("font_color", BONE)
	meter_label.add_theme_color_override("font_outline_color", Color("0d1016"))
	meter_label.add_theme_constant_override("outline_size", 5)
	meter_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.add_child(meter_label)


## Project Wren's fear and every doll's string. heroes is StitchedRules.get_heroes();
## doll_tops maps hero rank -> the screen point on top of its painted figure; cuts is
## StitchedRules.thread_cuts().
func show_state(fear_value: int, heroes: Array, doll_tops: Dictionary, cuts: Dictionary, motion_reduced: bool) -> void:
	fear = clampi(fear_value, 0, 100)
	shaking = fear >= StitchedKidFear.SHAKE_THRESHOLD
	reduced_motion = motion_reduced
	meter_fill.value = fear
	meter_label.text = "WREN FEAR %d / 100%s" % [fear, "  ·  SHAKING" if shaking else ""]
	meter_label.add_theme_color_override("font_color", DREAD if shaking else BONE)
	for rank in strings:
		strings[rank].visible = false
	for hero in heroes:
		var rank := int(hero.get("rank", 0))
		if not strings.has(rank) or bool(hero.get("lost", false)) or not doll_tops.has(rank):
			continue
		_hang(strings[rank], rank, doll_tops[rank], cuts.has(str(hero.get("id", ""))))
	set_process(shaking and not reduced_motion)
	if not is_processing():
		hands.position = HANDS_RECT.position - Vector2(0, LAYER_TOP)
		hands.rotation = 0.0


func knot(rank: int) -> Vector2:
	var at: Vector2 = BAR_KNOTS[clampi(rank, 1, 4) - 1]
	return HANDS_RECT.position + HANDS_RECT.size * at


## One thread from its cross-bar knot down to the doll; a snipped one hangs short and frayed.
func _hang(string: TextureRect, rank: int, top: Vector2, cut: bool) -> void:
	var from := knot(rank)
	var reach := top - from
	var length := reach.length() if not cut else minf(CUT_LENGTH, reach.length())
	string.texture = _thread_cut if cut else _thread
	if string.texture == null or length < 4.0:
		return
	string.visible = true
	string.size = Vector2(THREAD_WIDTH, length)
	string.pivot_offset = Vector2(THREAD_WIDTH * 0.5, 0)
	string.position = from - Vector2(0, LAYER_TOP) - string.pivot_offset
	# A cut string hangs straight down; a whole one leans toward its doll.
	string.rotation = 0.0 if cut else reach.angle() - PI * 0.5
	string.set_meta("cut", cut)
	string.set_meta("doll_top", top)


func _process(delta: float) -> void:
	_clock += delta
	hands.position = HANDS_RECT.position - Vector2(0, LAYER_TOP) + Vector2(sin(_clock * 9.0), cos(_clock * 7.0)) * SHAKE_PIXELS
	hands.rotation = sin(_clock * 6.0) * 0.012
