extends Control
## One reusable, input-inert battle atmosphere. The roster admits the scene; this
## renderer only decorates it and never reads gameplay authorities or any RNG.
## The two CPUParticles2D nodes are constructed once at listener startup, before
## the player begins a seeded run. They are recycled between every routed fight.

const ROSTER := preload("res://scripts/live_enemy_roster.gd")
const ROUTE_MAP := preload("res://scripts/run_map.gd")
const FELT_PATH := "res://assets/paper/vfx/felt_mote.png"
const LIGHT_PATH := "res://assets/paper/vfx/warm_light_pool.png"
const NORMAL_LINT := 2
const NORMAL_AREA := 3
const FAST_LINT := 1
const FAST_AREA := 2
const NORMAL_MOTIFS := 30
const FAST_MOTIFS := 7
const NORMAL_BUDGET := NORMAL_LINT + NORMAL_AREA + NORMAL_MOTIFS
const FAST_BUDGET := FAST_LINT + FAST_AREA + FAST_MOTIFS
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
var lint: CPUParticles2D
var weather: CPUParticles2D
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
	# Construct only at the listener's initial _ready, outside a battle. Even the
	# CPUParticles2D constructor may otherwise consume Godot's global RNG.
	lint = _new_emitter("SoftLint", 70747)
	weather = _new_emitter("AreaWeather", 80849)
	add_child(lint)
	add_child(weather)
	resized.connect(_resize_emitters)


static func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path, "Texture2D"):
		return null
	return load(path) as Texture2D


func _new_emitter(label: String, fixed_seed: int) -> CPUParticles2D:
	var emitter := CPUParticles2D.new()
	emitter.name = label
	emitter.emitting = false
	emitter.use_fixed_seed = true
	emitter.seed = fixed_seed
	emitter.texture = felt_texture
	emitter.visible = felt_texture != null
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.add_point(0.2, Color.WHITE)
	fade.add_point(0.75, Color.WHITE)
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	emitter.color_ramp = fade
	emitter.one_shot = false
	emitter.lifetime = 8.0
	emitter.fixed_fps = 15
	emitter.explosiveness = 0.0
	emitter.randomness = 0.35
	emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	emitter.direction = Vector2(0.15, 1.0)
	emitter.spread = 25.0
	emitter.gravity = Vector2(0.0, 3.0)
	emitter.initial_velocity_min = 3.0
	emitter.initial_velocity_max = 9.0
	emitter.scale_amount_min = 1.5
	emitter.scale_amount_max = 3.0
	return emitter


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
	_apply_profile()
	_resize_emitters()
	lint.emitting = felt_texture != null
	weather.emitting = felt_texture != null
	show()
	queue_redraw()
	return true


func set_fast(enabled: bool) -> void:
	if fast == enabled:
		return
	fast = enabled
	if not profile.is_empty():
		_apply_profile()
		queue_redraw()


func _apply_profile() -> void:
	lint.amount = FAST_LINT if fast else NORMAL_LINT
	weather.amount = FAST_AREA if fast else NORMAL_AREA
	lint.seed = 70747
	weather.seed = int(PROFILE_SEEDS.get(profile, 80849))
	lint.color = Color("#eee1c8", 0.25 if fast else 0.43)
	weather.color = Color(PROFILE_COLORS.get(profile, Color.WHITE), 0.28 if fast else 0.51)
	lint.gravity = Vector2(-1.0, 1.5)
	lint.direction = Vector2(-0.1, 1.0)
	lint.initial_velocity_min = 1.0
	lint.initial_velocity_max = 5.0
	lint.scale_amount_min = 1.0
	lint.scale_amount_max = 2.0
	weather.gravity = Vector2(0.0, 3.5)
	weather.direction = Vector2(-0.2, 1.0)
	weather.spread = 27.0
	weather.initial_velocity_min = 4.0
	weather.initial_velocity_max = 9.0
	weather.scale_amount_min = 2.0
	weather.scale_amount_max = 3.5
	match profile:
		"pollen":
			weather.gravity = Vector2(0, -2.0)
			weather.initial_velocity_max = 5.0
		"leaves":
			weather.gravity = Vector2(-9.0, 9.0)
			weather.scale_amount_max = 4.0
		"fireflies":
			weather.gravity = Vector2.ZERO
			weather.initial_velocity_min = 1.0
			weather.initial_velocity_max = 3.0
		"snow":
			weather.gravity = Vector2(-2.0, 7.0)
			weather.initial_velocity_max = 5.0
		"ash":
			weather.gravity = Vector2(-5.0, -4.0)
			weather.scale_amount_max = 2.5
		"scraps":
			weather.gravity = Vector2(-10.0, 7.0)
			weather.scale_amount_min = 2.5
			weather.scale_amount_max = 4.5
	# The authored image can be any resolution; preserve small felt flecks.
	var pixel_scale := 3.0 / maxf(1.0, felt_texture.get_width()) if felt_texture != null else 1.0
	lint.scale_amount_min *= pixel_scale
	lint.scale_amount_max *= pixel_scale
	weather.scale_amount_min *= pixel_scale
	weather.scale_amount_max *= pixel_scale


func _resize_emitters() -> void:
	var usable := Vector2(maxf(1.0, size.x), maxf(1.0, size.y * 0.76))
	for emitter in [lint, weather]:
		emitter.position = Vector2(size.x * 0.5, usable.y * 0.49)
		emitter.emission_rect_extents = usable * 0.49
	queue_redraw()


func visible_budget() -> int:
	if profile.is_empty():
		return 0
	return lint.amount + weather.amount + (FAST_MOTIFS if fast else NORMAL_MOTIFS)


func retire() -> void:
	lint.emitting = false
	weather.emitting = false
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
