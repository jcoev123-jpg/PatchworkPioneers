extends Control
## One reusable, input-inert battle atmosphere. The roster admits the scene; this
## renderer only decorates it and never reads gameplay authorities or any RNG.
## The two CPUParticles2D nodes are constructed once at listener startup, before
## the player begins a seeded run. They are recycled between every routed fight.

const ROSTER := preload("res://scripts/live_enemy_roster.gd")
const ROUTE_MAP := preload("res://scripts/run_map.gd")
const NORMAL_LINT := 7
const NORMAL_AREA := 20
const FAST_LINT := 2
const FAST_AREA := 6
const NORMAL_MOTIFS := 4
const FAST_MOTIFS := 1
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


func _init() -> void:
	name = "LiveBattleAmbient"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Construct only at the listener's initial _ready, outside a battle. Even the
	# CPUParticles2D constructor may otherwise consume Godot's global RNG.
	lint = _new_emitter("SoftLint", 70747)
	weather = _new_emitter("AreaWeather", 80849)
	add_child(lint)
	add_child(weather)
	resized.connect(_resize_emitters)


func _new_emitter(label: String, fixed_seed: int) -> CPUParticles2D:
	var emitter := CPUParticles2D.new()
	emitter.name = label
	emitter.emitting = false
	emitter.use_fixed_seed = true
	emitter.seed = fixed_seed
	emitter.texture = null
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
	lint.emitting = true
	weather.emitting = true
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


func _draw() -> void:
	if profile.is_empty() or size.x < 1.0 or size.y < 1.0:
		return
	# Gentle honey light on the three heroes, never a second dim/vignette.
	# It lives between the roster's already-dimmed backdrop and the actor row.
	var center := Vector2(size.x * 0.26, size.y * 0.62)
	draw_set_transform(center, 0.0, Vector2(1.65, 0.58))
	for ring in range(9, 0, -1):
		draw_circle(Vector2.ZERO, 13.0 + ring * 12.0,
			Color(1.0, 0.81, 0.49, (0.008 if fast else 0.014)))
	draw_set_transform(Vector2.ZERO)
	# A few larger, hand-cut silhouettes make the weather recognisable at 720p.
	# Their positions are fixed arithmetic, not samples of the game's RNG.
	for i in range(FAST_MOTIFS if fast else NORMAL_MOTIFS):
		var phase := _time * (0.16 + 0.035 * i) + float(i) * 1.81
		var x := fposmod(size.x * (0.15 + 0.22 * i) + sin(phase) * 32.0, size.x)
		var y := fposmod(size.y * (0.15 + 0.11 * i) + _time * _fall_speed()
			+ cos(phase * 1.4) * 9.0, maxf(1.0, size.y * 0.73))
		_draw_motif(Vector2(x, y), i)


func _fall_speed() -> float:
	match profile:
		"leaves", "snow", "scraps":
			return 5.0
		"ash":
			return -3.0
	return 1.5


func _draw_motif(at: Vector2, index: int) -> void:
	var tint: Color = PROFILE_COLORS[profile]
	tint.a = 0.33 if fast else 0.63
	match profile:
		"pollen":
			draw_circle(at, 2.7, tint)
			draw_circle(at, 5.0, Color(tint.r, tint.g, tint.b, 0.07))
		"fireflies":
			draw_circle(at, 8.0, Color(tint.r, tint.g, tint.b, 0.045))
			draw_circle(at, 3.1, tint)
		"snow":
			draw_circle(at, 3.1 + float(index % 2), tint)
		"ash":
			draw_line(at + Vector2(-2, 1), at + Vector2(2, -1), tint, 1.5)
		"leaves":
			draw_colored_polygon(PackedVector2Array([
				at + Vector2(-5, -2), at + Vector2(1, -4),
				at + Vector2(6, 2), at + Vector2(-1, 4)]), tint)
			draw_line(at + Vector2(-3, -2), at + Vector2(4, 2),
				Color("#574d3f", 0.35), 0.8)
		"scraps":
			draw_colored_polygon(PackedVector2Array([
				at + Vector2(-5, -3), at + Vector2(5, -2),
				at + Vector2(4, 4), at + Vector2(-4, 3)]), tint)
			draw_line(at + Vector2(-3, 0), at + Vector2(3, 1),
				Color("#7d6357", 0.5), 0.9)
