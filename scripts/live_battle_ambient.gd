extends Control
## One reusable, input-inert battle atmosphere drawn only from two authored
## images. The roster admits the scene; this renderer only decorates it and
## never reads gameplay authorities or any RNG. Both image families are loaded
## once at listener startup, before the player begins a seeded run, and the
## same layer is recycled between every routed fight.

const ROSTER := preload("res://scripts/live_enemy_roster.gd")
const ROUTE_MAP := preload("res://scripts/run_map.gd")
const FELT_PATH := "res://assets/paper/vfx/felt_mote.png"
const LIGHT_PATH := "res://assets/paper/vfx/warm_light_pool.png"
const NORMAL_MOTIFS := 30
const FAST_MOTIFS := 7
const NORMAL_BUDGET := NORMAL_MOTIFS
const FAST_BUDGET := FAST_MOTIFS
const PROFILE_COLORS := {
	"pollen": Color("#eadba0"),
	"leaves": Color("#9ead83"),
	"fireflies": Color("#cfe997"),
	"snow": Color("#e7e9df"),
	"ash": Color("#c0ada2"),
	"scraps": Color("#d6b9a1"),
}
const PROFILE_SEEDS := {
	"pollen": 10103, "leaves": 20207, "fireflies": 30313,
	"snow": 40423, "ash": 50531, "scraps": 60637,
}

var profile := ""
var fast := false
var _time := 0.0
var felt_texture: Texture2D
var light_texture: Texture2D


func _init() -> void:
	name = "LiveBattleAmbient"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Admit imported art once, before seeded play; absent art stays invisible.
	felt_texture = _load_texture(FELT_PATH)
	light_texture = _load_texture(LIGHT_PATH)
	resized.connect(queue_redraw)


static func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path, "Texture2D"):
		return null
	return load(path) as Texture2D


## Mirrors the roster's *admitted* stage scene, never a guessed default for bad
## routed kinds/floors. Elite and Boss have routed positive floors; only the
## standalone Fight may use zero.
static func profile_for(kind: String, floor_number: int) -> String:
	if floor_number < 0 or not ROSTER.BATTLE_BACKDROPS.has(kind):
		return ""
	if kind == "Boss" and floor_number != ROUTE_MAP.FLOOR_COUNT:
		return ""
	if kind == "Elite" and (floor_number == 0 or floor_number >= ROUTE_MAP.FLOOR_COUNT):
		return ""
	if kind == "Fight" and floor_number >= ROUTE_MAP.FLOOR_COUNT:
		return ""
	var file := ROSTER.stage_backdrop_path(kind, floor_number).get_file()
	match file:
		"battle_meadow.png":
			return "pollen"
		"battle_woods.png":
			return "leaves"
		"battle_marsh.png":
			return "fireflies"
		"battle_peaks.png":
			return "snow"
		"battle_ruins.png":
			return "ash"
		"battle_boss.png":
			return "scraps"
	return ""


func configure(kind: String, floor_number: int, fast_mode: bool) -> bool:
	var chosen := profile_for(kind, floor_number)
	if chosen.is_empty():
		retire()
		return false
	var changed := profile != chosen
	profile = chosen
	fast = fast_mode
	if changed:
		_time = 0.0
	show()
	queue_redraw()
	return true


func set_fast(enabled: bool) -> void:
	if fast == enabled:
		return
	fast = enabled
	if not profile.is_empty():
		queue_redraw()


func visible_budget() -> int:
	if profile.is_empty():
		return 0
	return FAST_BUDGET if fast else NORMAL_BUDGET


func retire() -> void:
	profile = ""
	_time = 0.0
	hide()
	queue_redraw()


func _process(delta: float) -> void:
	if profile.is_empty() or not visible or delta <= 0.0:
		return
	_time = fposmod(_time + delta, 120.0)
	queue_redraw()


## Pure texture placement, shared by the renderer and detached diagnostics.
static func mote_at(family: String, bounds: Vector2, elapsed: float, fast_mode: bool, index: int) -> Dictionary:
	var cell := posmod(index * 13, NORMAL_MOTIFS)
	var phase := fposmod(elapsed, 120.0) * TAU / 120.0 + float(index) * 1.81 + float(PROFILE_SEEDS[family] % 17)
	var motion_scale := 0.4 if fast_mode else 1.0
	var at := Vector2(
		18.0 + (bounds.x - 36.0) * (float(cell % 10) + 0.5) / 10.0,
		18.0 + (bounds.y - 36.0) * (float(cell / 10) + 0.5) / 3.0)
	at += Vector2(sin(phase) * 10.0, cos(phase) * 8.0) * motion_scale
	var width := 6.0 + float(posmod(index, 9))
	var tint: Color = PROFILE_COLORS[family]
	tint.a = (0.32 if fast_mode else 0.72) * (0.75 + 0.25 * sin(phase))
	return {"center": at, "rect": Rect2(at - Vector2.ONE * width * 0.5, Vector2.ONE * width), "color": tint}


static func motifs_for(family: String, bounds: Vector2, elapsed: float, fast_mode: bool) -> Array:
	var marks: Array = []
	if not PROFILE_COLORS.has(family) or bounds.x < 40.0 or bounds.y < 40.0:
		return marks
	for i in range(FAST_MOTIFS if fast_mode else NORMAL_MOTIFS):
		marks.append(mote_at(family, bounds, elapsed, fast_mode, i))
	return marks


func motif_metadata() -> Array:
	return motifs_for(profile, size, _time, fast)


static func light_alpha(elapsed: float, fast_mode: bool) -> float:
	return (0.16 if fast_mode else 0.32) * (0.9 + 0.1 * sin(fposmod(elapsed, 120.0) * TAU / 12.0))


## The whole battle atmosphere: the warm pool image plus the drifting felt
## marks. Nothing is synthesised when an image is unavailable.
func _draw() -> void:
	if profile.is_empty() or size.x < 40.0 or size.y < 40.0:
		return
	if light_texture != null:
		var extent := Vector2(size.x * 0.38, size.y * 0.48)
		draw_texture_rect(light_texture, Rect2(size * Vector2(0.26, 0.62) - extent * 0.5, extent),
			false, Color(1, 1, 1, light_alpha(_time, fast)))
	if felt_texture != null:
		for i in range(FAST_MOTIFS if fast else NORMAL_MOTIFS):
			var mark := mote_at(profile, size, _time, fast, i)
			draw_texture_rect(felt_texture, mark["rect"], false, mark["color"])
