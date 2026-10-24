extends Control
## One reusable, input-inert battle atmosphere drawn only from authored
## images. The roster admits the scene; this renderer only decorates it and
## never reads gameplay authorities or any RNG. All image families are loaded
## once at listener startup, before the player begins a seeded run, and the
## same layer is recycled between every routed fight.

const ROSTER := preload("res://scripts/live_enemy_roster.gd")
const ROUTE_MAP := preload("res://scripts/run_map.gd")
const FELT_PATH := "res://assets/paper/vfx/felt_mote.png"
const LIGHT_PATH := "res://assets/paper/vfx/warm_light_pool.png"
const FLUFF_PATH := "res://assets/paper/vfx/fluff_puff.png"
const WISP_PATH := "res://assets/paper/vfx/thread_wisp.png"
const VIGNETTE_PATH := "res://assets/paper/backgrounds/battle_vignette.png"
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
var fluff_texture: Texture2D
var wisp_texture: Texture2D
var vignette_texture: Texture2D


func _init() -> void:
	name = "LiveBattleAmbient"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Admit imported art once, before seeded play; absent art stays invisible.
	felt_texture = _load_texture(FELT_PATH)
	light_texture = _load_texture(LIGHT_PATH)
	fluff_texture = _load_texture(FLUFF_PATH)
	wisp_texture = _load_texture(WISP_PATH)
	vignette_texture = _load_texture(VIGNETTE_PATH)
	resized.connect(queue_redraw)


static func _load_texture(path: String) -> Texture2D:
	if not FileAccess.file_exists(path) or not ResourceLoader.exists(path, "Texture2D"):
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


## Fit the complete authored image without stretching or crossing stage edges.
static func fitted_extent(image_size: Vector2, limit: Vector2) -> Vector2:
	if image_size.x <= 0.0 or image_size.y <= 0.0 or limit.x <= 0.0 or limit.y <= 0.0:
		return Vector2.ZERO
	return image_size * minf(limit.x / image_size.x, limit.y / image_size.y)


## Sparse upper-stage dressing leaves the grounded feet and lower HUD clear.
## Profiles and index arithmetic supply phases without sampling any RNG.
static func drifts_for(family: String, art: String, bounds: Vector2, elapsed: float,
		fast_mode: bool, image_size: Vector2) -> Array:
	var marks: Array = []
	if not PROFILE_SEEDS.has(family) or art not in ["fluff", "wisp"] \
			or bounds.x < 40.0 or bounds.y < 40.0:
		return marks
	var fluff := art == "fluff"
	var extent := fitted_extent(image_size,
		Vector2(minf(42.0 if fluff else 64.0, bounds.x * 0.08), bounds.y * 0.12))
	if extent == Vector2.ZERO:
		return marks
	var count := (2 if fluff else 1) if fast_mode else (6 if fluff else 4)
	var clock := fposmod(elapsed, 120.0) * TAU / 120.0
	for i in range(count):
		var phase := float(PROFILE_SEEDS[family] % 29) + i * 1.73 + (0.0 if fluff else 0.91)
		var anchor := Vector2(bounds.x * (0.12 + 0.76 * float(posmod(i * 7 + PROFILE_SEEDS[family], 13)) / 12.0),
			bounds.y * (0.16 + 0.32 * float(posmod(i * 3, 5)) / 4.0))
		var drift := Vector2(sin(phase + clock) - sin(phase), cos(phase + clock) - cos(phase))
		var at := anchor + drift * minf(6.0, bounds.y * 0.02) * (0.3 if fast_mode else 1.0)
		var tint: Color = PROFILE_COLORS[family]
		tint.a = (0.10 if fast_mode else 0.24) * (0.85 + 0.15 * sin(phase + clock))
		marks.append({"rect": Rect2(at - extent * 0.5, extent), "color": tint})
	return marks


static func vignette_for(family: String, bounds: Vector2, fast_mode: bool, image_size: Vector2) -> Dictionary:
	if not PROFILE_SEEDS.has(family) or bounds.x < 40.0 or bounds.y < 40.0:
		return {}
	var extent := fitted_extent(image_size, bounds)
	if extent == Vector2.ZERO:
		return {}
	return {"rect": Rect2((bounds - extent) * 0.5, extent),
		"color": Color(1, 1, 1, 0.05 if fast_mode else 0.10)}


func added_metadata() -> Array:
	var marks: Array = []
	for entry in [["fluff", fluff_texture], ["wisp", wisp_texture]]:
		if entry[1] != null:
			marks.append_array(drifts_for(profile, entry[0], size, _time, fast, entry[1].get_size()))
	if vignette_texture != null:
		var shade := vignette_for(profile, size, fast, vignette_texture.get_size())
		if not shade.is_empty():
			marks.append(shade)
	return marks


## Nothing is synthesised when an image is unavailable.
func _draw() -> void:
	if profile.is_empty() or size.x < 40.0 or size.y < 40.0:
		return
	if vignette_texture != null:
		var shade := vignette_for(profile, size, fast, vignette_texture.get_size())
		if not shade.is_empty():
			draw_texture_rect(vignette_texture, shade["rect"], false, shade["color"])
	if light_texture != null:
		var extent := Vector2(size.x * 0.38, size.y * 0.48)
		draw_texture_rect(light_texture, Rect2(size * Vector2(0.26, 0.62) - extent * 0.5, extent),
			false, Color(1, 1, 1, light_alpha(_time, fast)))
	if felt_texture != null:
		for i in range(FAST_MOTIFS if fast else NORMAL_MOTIFS):
			var mark := mote_at(profile, size, _time, fast, i)
			draw_texture_rect(felt_texture, mark["rect"], false, mark["color"])
	if fluff_texture != null:
		for mark in drifts_for(profile, "fluff", size, _time, fast, fluff_texture.get_size()):
			draw_texture_rect(fluff_texture, mark["rect"], false, mark["color"])
	if wisp_texture != null:
		for mark in drifts_for(profile, "wisp", size, _time, fast, wisp_texture.get_size()):
			draw_texture_rect(wisp_texture, mark["rect"], false, mark["color"])
