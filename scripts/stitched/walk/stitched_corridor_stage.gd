class_name StitchedCorridorStage
extends SubViewportContainer
## S10 3D corridor: the doll's-eye view of a Walk, lit only by the run's candle.
## Presentation only: the screen tells it where the dolls stand; it never reads or writes rules.
## Every surface and figure is an authored picture; light and fog are the engine's.

const ART_DIR := "res://assets/paper/walk3d/"
const HERO_DIR := "res://assets/paper/heroes/"
const SEGMENT := 3.0
const WIDTH := 3.2
const HEIGHT := 3.0
const EYE := 0.95
## Spare corridor before the first step and past the last, so the ends fall into fog, not into void.
const MARGIN := 3
const PROP_AHEAD := 2.4
const DOLL_HEIGHT := 1.15
const AREA_KEYS := {"floorboards": "floorboards", "walls": "walls", "sewing_basket": "basket"}
## Candle band -> [light energy, light range, fog density, how many trailing ranks stay lit].
const BANDS := {
	"bright": [2.6, 7.0, 0.07, 4],
	"dim": [2.2, 6.0, 0.09, 3],
	"gloom": [1.8, 5.0, 0.12, 2],
	"dark": [1.3, 3.8, 0.17, 1],
	"snuffed": [0.7, 2.4, 0.26, 0],
}
## Trailing dolls stand a little apart so all four read when the camera turns round.
const TRAIL_X := [0.0, -0.75, 0.75, 0.0]
const STEP_TIME := 0.5
const TURN_TIME := 0.35
## S11 fights stay in the corridor: the eye steps out through the near wall and looks across it.
const FIGHT_EYE := Vector2(5.0, 1.0)
const FIGHT_FOV := 40.0
const FIGHT_PITCH := -4.0
const FIGHT_FOG := 0.6
const WALK_FOV := 70.0
const WALK_LIGHT := Vector3(0.35, -0.25, -0.35)
const FIGHT_LIGHT := Vector3(0.0, 0.4, -2.3)

var viewport: SubViewport
var world: Node3D
var camera: Camera3D
var candle_light: OmniLight3D
var environment: Environment
var corridor: Node3D
var figures: Node3D
## id -> Sprite3D for everything standing in the corridor (dolls, the extra doll, props, horrors).
var figure_nodes: Dictionary = {}
var area := ""
var steps := 0
var step := 0
var looking_back := false
var band := "bright"
var dim := 1.0
var walk_tween: Tween
var fighting := false


func _init() -> void:
	name = "CorridorStage"
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.name = "CorridorViewport"
	viewport.own_world_3d = true
	viewport.size = Vector2i(1280, 720)
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)
	world = Node3D.new()
	world.name = "CorridorWorld"
	viewport.add_child(world)
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.01, 0.008, 0.01)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.2, 0.13, 0.1)
	environment.ambient_light_energy = 0.07
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.03, 0.02, 0.02)
	environment.fog_density = BANDS.bright[2]
	var surroundings := WorldEnvironment.new()
	surroundings.environment = environment
	world.add_child(surroundings)
	camera = Camera3D.new()
	camera.name = "DollEye"
	camera.fov = WALK_FOV
	camera.near = 0.05
	camera.far = 60.0
	camera.position = Vector3(0, EYE, 0)
	world.add_child(camera)
	candle_light = OmniLight3D.new()
	candle_light.name = "Candle"
	candle_light.position = WALK_LIGHT
	candle_light.light_color = Color(1.0, 0.7, 0.4)
	candle_light.omni_attenuation = 1.8
	camera.add_child(candle_light)
	corridor = Node3D.new()
	corridor.name = "Corridor"
	world.add_child(corridor)
	figures = Node3D.new()
	figures.name = "Figures"
	world.add_child(figures)
	set_candle("bright")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


static func art(key: String) -> Texture2D:
	var path := ART_DIR + key + ".png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## The area's own surface picture; a missing one borrows the area's wall, then the walls area's.
static func surface(area_name: String, part: String) -> Texture2D:
	var key: String = AREA_KEYS.get(area_name, "walls")
	for candidate in ["tex_%s_%s" % [key, part], "tex_%s_wall" % key, "tex_walls_" + part, "tex_walls_wall"]:
		var texture := art(candidate)
		if texture != null:
			return texture
	return null


static func hero_art(id: String) -> Texture2D:
	for path in [HERO_DIR + id + ".png", HERO_DIR + "seamstress.png"]:
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null


## Lays out a fresh corridor of `step_count` steps in an area. Figures are cleared.
func build(area_name: String, step_count: int) -> void:
	area = area_name
	steps = maxi(1, step_count)
	for child in corridor.get_children():
		corridor.remove_child(child)
		child.free()
	clear_figures()
	var length := (steps + MARGIN * 2) * SEGMENT
	var middle := -(steps * SEGMENT) / 2.0
	var repeats := length / SEGMENT
	_quad("Floor", Vector2(WIDTH, length), Vector3(0, 0, middle), Vector3(-PI / 2, 0, 0),
		surface(area, "floor"), Vector2(1, repeats))
	_quad("Ceiling", Vector2(WIDTH, length), Vector3(0, HEIGHT, middle), Vector3(PI / 2, 0, 0),
		surface(area, "ceiling"), Vector2(1, repeats))
	_quad("LeftWall", Vector2(length, HEIGHT), Vector3(-WIDTH / 2, HEIGHT / 2, middle), Vector3(0, PI / 2, 0),
		surface(area, "wall"), Vector2(repeats, 1))
	_quad("RightWall", Vector2(length, HEIGHT), Vector3(WIDTH / 2, HEIGHT / 2, middle), Vector3(0, -PI / 2, 0),
		surface(area, "wall"), Vector2(repeats, 1))
	_quad("FarEnd", Vector2(WIDTH, HEIGHT), Vector3(0, HEIGHT / 2, middle - length / 2), Vector3.ZERO,
		surface(area, "wall"), Vector2.ONE)
	_quad("NearEnd", Vector2(WIDTH, HEIGHT), Vector3(0, HEIGHT / 2, middle + length / 2), Vector3(0, PI, 0),
		surface(area, "wall"), Vector2.ONE)
	go_to(0, false)
	turn(false, false)


func _quad(title: String, extent: Vector2, where: Vector3, rotation_angles: Vector3, texture: Texture2D, repeats: Vector2) -> void:
	var mesh := QuadMesh.new()
	mesh.size = extent
	var material := StandardMaterial3D.new()
	material.roughness = 1.0
	material.albedo_color = Color(0.85, 0.8, 0.78)
	if texture != null:
		material.albedo_texture = texture
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		material.uv1_scale = Vector3(repeats.x, repeats.y, 1)
	mesh.material = material
	var surface_node := MeshInstance3D.new()
	surface_node.name = title
	surface_node.mesh = mesh
	surface_node.position = where
	surface_node.rotation = rotation_angles
	corridor.add_child(surface_node)


func eye_z(at_step: int) -> float:
	return -float(at_step) * SEGMENT


## Moves the doll's eye to a step; animated it creeps with a small bob, else it snaps.
func go_to(at_step: int, animate: bool = true) -> Tween:
	step = clampi(at_step, 0, steps)
	stop()
	var target := Vector3(0, EYE, eye_z(step))
	if not animate or not is_inside_tree():
		camera.position = target
		return null
	walk_tween = create_tween()
	walk_tween.tween_property(camera, "position", target + Vector3(0, -0.05, SEGMENT * 0.45), STEP_TIME * 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	walk_tween.tween_property(camera, "position", target, STEP_TIME * 0.45) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return walk_tween


## Faces back down the corridor (the trailing dolls) or forward again.
func turn(back: bool, animate: bool = true) -> Tween:
	looking_back = back
	var yaw := PI if back else 0.0
	if not animate or not is_inside_tree():
		camera.rotation = Vector3(0, yaw, 0)
		return null
	stop()
	walk_tween = create_tween()
	walk_tween.tween_property(camera, "rotation", Vector3(0, yaw, 0), TURN_TIME).set_trans(Tween.TRANS_SINE)
	return walk_tween


func moving() -> bool:
	return walk_tween != null and walk_tween.is_running()


## Finishes any move at once (reduced motion, or a new command arriving mid-move).
func stop() -> void:
	if walk_tween != null:
		walk_tween.kill()
		walk_tween = null
		camera.position = Vector3(0, EYE, eye_z(step))
		camera.rotation = Vector3(0, PI if looking_back else 0.0, 0)


func set_candle(band_name: String) -> void:
	band = band_name if BANDS.has(band_name) else "dim"
	environment.fog_density = BANDS[band][2] * (FIGHT_FOG if fighting else 1.0)
	candle_light.omni_range = BANDS[band][1]
	set_dim(dim)


## Wren's fear flicker: a brightness factor on the candle only, never the camera.
func set_dim(factor: float) -> void:
	dim = clampf(factor, 0.0, 1.0)
	candle_light.light_energy = BANDS[band][0] * dim


func lit_ranks() -> int:
	return BANDS[band][3]


func clear_figures() -> void:
	for child in figures.get_children():
		figures.remove_child(child)
		child.free()
	figure_nodes.clear()


## Stands a picture upright in the corridor, feet on the floor, always turned to the eye.
func place(id: String, texture: Texture2D, where: Vector3, height: float) -> Sprite3D:
	var figure: Sprite3D = figure_nodes.get(id)
	if figure == null:
		figure = Sprite3D.new()
		figure.name = "Figure_" + id.validate_node_name()
		figure.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		figure.shaded = true
		figure.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		figure.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		figures.add_child(figure)
		figure_nodes[id] = figure
	figure.texture = texture
	var tall := float(texture.get_height()) if texture != null else 512.0
	figure.pixel_size = height / tall
	figure.position = where + Vector3(0, height / 2.0, 0)
	figure.modulate = Color.WHITE
	figure.visible = texture != null
	return figure


## Where the party trails behind the doll whose eyes we borrow: rank order, nearest first.
func trail_point(slot: int) -> Vector3:
	return Vector3(TRAIL_X[slot % TRAIL_X.size()], 0, eye_z(step) + 1.5 + slot * 0.85)


func ahead_point(distance: float = PROP_AHEAD, x: float = 0.0) -> Vector3:
	return Vector3(x, 0, eye_z(step) - distance)


## Screen position (in this stage's pixels) of a figure's feet, or null when it is out of sight.
func screen_point(id: String) -> Variant:
	var figure: Sprite3D = figure_nodes.get(id)
	if figure == null or not figure.visible or not is_inside_tree():
		return null
	var feet := figure.global_position - Vector3(0, figure.pixel_size * figure.texture.get_height() / 2.0, 0)
	if camera.is_position_behind(feet):
		return null
	var scale_factor := size / Vector2(viewport.size) if viewport.size.x > 0 else Vector2.ONE
	return camera.unproject_position(feet) * scale_factor


## Turns the corridor into a fight: the party stands on the left, the foes on the right,
## seen side-on through the cut-away near wall (its back face is never drawn).
func fight_view(on: bool = true) -> void:
	fighting = on
	stop()
	if on:
		camera.fov = FIGHT_FOV
		camera.position = Vector3(FIGHT_EYE.x, FIGHT_EYE.y, fight_z() + 0.3)
		camera.rotation = Vector3(deg_to_rad(FIGHT_PITCH), PI / 2, 0)
		candle_light.position = FIGHT_LIGHT
	else:
		camera.fov = WALK_FOV
		candle_light.position = WALK_LIGHT
		go_to(step, false)
		turn(looking_back, false)
	set_candle(band)


## Where the fight stands: a little ahead of the step the walk stopped on.
func fight_z() -> float:
	return eye_z(step) - SEGMENT * 0.5


## A rank's spot in the fight; rank 1 of each side stands nearest the middle.
func fight_point(side: String, rank: int) -> Vector3:
	var index := clampi(rank, 1, 4) - 1
	var depth := -0.15 if index % 2 == 1 else 0.1
	if side == "hero":
		return Vector3(depth, 0, fight_z() + 0.45 + index * 0.75)
	return Vector3(depth, 0, fight_z() - 0.45 - index * 0.8)


## The figure's whole picture on screen (in this stage's pixels); empty when out of sight.
func screen_rect(id: String) -> Rect2:
	var figure: Sprite3D = figure_nodes.get(id)
	if figure == null or not figure.visible or figure.texture == null or not is_inside_tree():
		return Rect2()
	var half := Vector2(figure.texture.get_width(), figure.texture.get_height()) * figure.pixel_size / 2.0
	var across := camera.global_transform.basis.x
	var top := figure.global_position + Vector3.UP * half.y - across * half.x
	var bottom := figure.global_position - Vector3.UP * half.y + across * half.x
	if camera.is_position_behind(top) or camera.is_position_behind(bottom):
		return Rect2()
	var scale_factor := size / Vector2(viewport.size) if viewport.size.x > 0 else Vector2.ONE
	return Rect2(camera.unproject_position(top) * scale_factor, Vector2.ZERO) 		.expand(camera.unproject_position(bottom) * scale_factor)
