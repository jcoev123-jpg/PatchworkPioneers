class_name StitchedCorridorStage
extends SubViewportContainer
## S10 3D corridor: the doll's-eye view of a Walk, lit only by the run's candle.
## Presentation only: the screen tells it where the dolls stand; it never reads or writes rules.
## Every surface and figure is an authored picture; light and fog are the engine's.

const ROSTER := preload("res://scripts/live_enemy_roster.gd")
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
const STEP_TIME := 1.05   # owner 11-11: a step was too quick
const TURN_TIME := 0.8   # owner 11-11: turning round was too quick
## S11 fights stay in the corridor: the eye steps out through the near wall and looks across it.
const FIGHT_EYE := Vector2(5.0, 1.0)
const FIGHT_FOV := 44.0
const FIGHT_PITCH := -4.0
const FIGHT_FOG := 0.6
const WALK_FOV := 70.0
const WALK_LIGHT := Vector3(0.35, -0.25, -0.35)
const FIGHT_LIGHT := Vector3(0.0, 0.5, -3.1)
## The fight is seen from further off than the walk, so its candle burns stronger and reaches
## the whole line (playtest 11-10: the dolls stood in the dark).
const FIGHT_GLOW := 1.7
const FIGHT_REACH := 1.5
## Owner 11-10 attack spotlight: while a receipt's held beat plays the corridor surfaces
## and every uninvolved figure dim clearly, the acting pair brightens a touch and stands
## in front of everyone else. No new art: the existing materials and modulates move.
const SURFACE_TINT := Color(0.85, 0.8, 0.78)
const AMBIENT_BASE := 0.07
const SPOT_SURFACE := 0.35
const SPOT_AMBIENT := 0.02
const SPOT_DIM := Color(0.42, 0.4, 0.46)
const SPOT_LIT := Color(1.3, 1.22, 1.05)
const SPOT_IN := 0.14
const SPOT_EASE := 0.2
## Owner 11-08 maze junction: how far the crossing is, how long each opening runs before
## its end wall, where the eye waits, and how deep the stops stand in the openings.
const JUNCTION_STEPS := 2
const JUNCTION_RUN := 12.0
const JUNCTION_BACK := 3.4
const JUNCTION_SIDE_IN := 1.1
const JUNCTION_AHEAD_IN := 2.6
## Owner 11-09 "idle animations for characters": standing figures play their Flow idle strip at the
## 2D puppets' pace, each from its own point in the loop so a rank never breathes in step.
const IDLE_FPS := 12.0
## Loops rebuilt with twice the frames play twice as fast, so the motion keeps its speed.
const IDLE_SMOOTH_FPS := 24.0
const IDLE_SMOOTH_CHUNKS := 8

var viewport: SubViewport
var world: Node3D
var camera: Camera3D
var candle_light: OmniLight3D
var environment: Environment
var corridor: Node3D
var figures: Node3D
## id -> Sprite3D for everything standing in the corridor (dolls, the extra doll, props, horrors).
var figure_nodes: Dictionary = {}
## Holds every figure on its still (the walk's and fight's motion toggle).
var reduced_motion := false
var _idle_clock := 0.0
## Still path -> its idle loop frames; empty when the still has no strip.
static var _idle_cache: Dictionary = {}
## Still path -> how its loop cells line up with it (see _idle_fit).
static var _idle_fits: Dictionary = {}
## Still path -> the frame rate its loop was cut for.
static var _idle_rates: Dictionary = {}
var area := ""
var steps := 0
var step := 0
var looking_back := false
var band := "bright"
var dim := 1.0
var walk_tween: Tween
var fighting := false
## The exact side-on camera to restore after each receipt (no rules state).
var _fight_home := Transform3D.IDENTITY
var _focus_tween: Tween
## The attack spotlight's own ease in/out (see begin_spotlight).
var _spot_tween: Tween


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
	environment.ambient_light_energy = AMBIENT_BASE
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
	# Stop spotlight tweens before freeing their corridor materials or figures.
	end_spotlight(0.0)
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


## Owner 11-08: a maze junction with no dead ends. The corridor runs up to a crossing that
## opens left, forward and/or right (`open`); every closed side is a wall. Figures are cleared.
func build_junction(area_name: String, open: Array) -> void:
	# A pending fade must not keep tweening surfaces freed by this rebuild.
	end_spotlight(0.0)
	area = area_name
	steps = JUNCTION_STEPS
	for child in corridor.get_children():
		corridor.remove_child(child)
		child.free()
	clear_figures()
	var half := WIDTH / 2.0
	var cross := junction_z()
	var back := MARGIN * SEGMENT
	var main := back - (cross + half)
	var middle := (back + cross + half) / 2.0
	_quad("Floor", Vector2(WIDTH, main), Vector3(0, 0, middle), Vector3(-PI / 2, 0, 0),
		surface(area, "floor"), Vector2(1, main / SEGMENT))
	_quad("Ceiling", Vector2(WIDTH, main), Vector3(0, HEIGHT, middle), Vector3(PI / 2, 0, 0),
		surface(area, "ceiling"), Vector2(1, main / SEGMENT))
	_quad("LeftWall", Vector2(main, HEIGHT), Vector3(-half, HEIGHT / 2, middle), Vector3(0, PI / 2, 0),
		surface(area, "wall"), Vector2(main / SEGMENT, 1))
	_quad("RightWall", Vector2(main, HEIGHT), Vector3(half, HEIGHT / 2, middle), Vector3(0, -PI / 2, 0),
		surface(area, "wall"), Vector2(main / SEGMENT, 1))
	_quad("NearEnd", Vector2(WIDTH, HEIGHT), Vector3(0, HEIGHT / 2, back), Vector3(0, PI, 0),
		surface(area, "wall"), Vector2.ONE)
	_quad("CrossFloor", Vector2(WIDTH, WIDTH), Vector3(0, 0, cross), Vector3(-PI / 2, 0, 0),
		surface(area, "floor"), Vector2.ONE)
	_quad("CrossCeiling", Vector2(WIDTH, WIDTH), Vector3(0, HEIGHT, cross), Vector3(PI / 2, 0, 0),
		surface(area, "ceiling"), Vector2.ONE)
	var run := JUNCTION_RUN
	var reps := run / SEGMENT
	for side: String in ["left", "right"]:
		var sign: float = -1.0 if side == "left" else 1.0
		var facing: float = PI / 2 if side == "left" else -PI / 2
		var title := side.capitalize()
		if not open.has(side):
			_quad(title + "Shut", Vector2(WIDTH, HEIGHT), Vector3(sign * half, HEIGHT / 2, cross), Vector3(0, facing, 0),
				surface(area, "wall"), Vector2.ONE)
			continue
		var along := sign * (half + run / 2.0)
		_quad(title + "Floor", Vector2(run, WIDTH), Vector3(along, 0, cross), Vector3(-PI / 2, 0, 0),
			surface(area, "floor"), Vector2(reps, 1))
		_quad(title + "Ceiling", Vector2(run, WIDTH), Vector3(along, HEIGHT, cross), Vector3(PI / 2, 0, 0),
			surface(area, "ceiling"), Vector2(reps, 1))
		_quad(title + "FarSide", Vector2(run, HEIGHT), Vector3(along, HEIGHT / 2, cross - half), Vector3.ZERO,
			surface(area, "wall"), Vector2(reps, 1))
		_quad(title + "NearSide", Vector2(run, HEIGHT), Vector3(along, HEIGHT / 2, cross + half), Vector3(0, PI, 0),
			surface(area, "wall"), Vector2(reps, 1))
		_quad(title + "End", Vector2(WIDTH, HEIGHT), Vector3(sign * (half + run), HEIGHT / 2, cross), Vector3(0, facing, 0),
			surface(area, "wall"), Vector2.ONE)
	if open.has("forward"):
		var ahead := cross - half - run / 2.0
		_quad("AheadFloor", Vector2(WIDTH, run), Vector3(0, 0, ahead), Vector3(-PI / 2, 0, 0),
			surface(area, "floor"), Vector2(1, reps))
		_quad("AheadCeiling", Vector2(WIDTH, run), Vector3(0, HEIGHT, ahead), Vector3(PI / 2, 0, 0),
			surface(area, "ceiling"), Vector2(1, reps))
		_quad("AheadLeftWall", Vector2(run, HEIGHT), Vector3(-half, HEIGHT / 2, ahead), Vector3(0, PI / 2, 0),
			surface(area, "wall"), Vector2(reps, 1))
		_quad("AheadRightWall", Vector2(run, HEIGHT), Vector3(half, HEIGHT / 2, ahead), Vector3(0, -PI / 2, 0),
			surface(area, "wall"), Vector2(reps, 1))
		_quad("FarEnd", Vector2(WIDTH, HEIGHT), Vector3(0, HEIGHT / 2, cross - half - run), Vector3.ZERO,
			surface(area, "wall"), Vector2.ONE)
	else:
		_quad("FarEnd", Vector2(WIDTH, HEIGHT), Vector3(0, HEIGHT / 2, cross - half), Vector3.ZERO,
			surface(area, "wall"), Vector2.ONE)
	fighting = false
	camera.fov = WALK_FOV
	candle_light.position = WALK_LIGHT
	looking_back = false
	stop()
	camera.position = junction_eye()
	camera.rotation = Vector3.ZERO
	set_candle(band)


func junction_z() -> float:
	return -JUNCTION_STEPS * SEGMENT


## Where the eye waits: far enough back that all three openings are in view.
func junction_eye() -> Vector3:
	return Vector3(0, EYE, junction_z() + JUNCTION_BACK)


## Where a stop stands in an opening, seen in the fog; `slot`/`of` share the way ahead.
func junction_point(side: String, slot: int = 0, of: int = 1) -> Vector3:
	var cross := junction_z()
	match side:
		"left":
			return Vector3(-(WIDTH / 2.0 + JUNCTION_SIDE_IN), 0, cross - 0.5)
		"right":
			return Vector3(WIDTH / 2.0 + JUNCTION_SIDE_IN, 0, cross - 0.5)
	var spread := 0.0 if of <= 1 else lerpf(-0.65, 0.65, float(slot) / float(of - 1))
	return Vector3(spread, 0, cross - WIDTH / 2.0 - JUNCTION_AHEAD_IN)


## Arriving through a junction opening: the eye starts turned toward where it came from
## and swings round to face down the new corridor. Purely a camera beat.
func arrive_from(side: String, animate: bool = true) -> Tween:
	if side != "left" and side != "right":
		return null
	stop()
	if not animate or not is_inside_tree():
		return null
	var home := camera.rotation
	camera.rotation = home + Vector3(0, -PI / 2 if side == "left" else PI / 2, 0)
	walk_tween = create_tween()
	walk_tween.tween_property(camera, "rotation", home, TURN_TIME * 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return walk_tween


func _quad(title: String, extent: Vector2, where: Vector3, rotation_angles: Vector3, texture: Texture2D, repeats: Vector2) -> void:
	var mesh := QuadMesh.new()
	mesh.size = extent
	var material := StandardMaterial3D.new()
	material.roughness = 1.0
	material.albedo_color = SURFACE_TINT
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
	candle_light.omni_range = BANDS[band][1] * (FIGHT_REACH if fighting else 1.0)
	set_dim(dim)


## Wren's fear flicker: a brightness factor on the candle only, never the camera.
func set_dim(factor: float) -> void:
	dim = clampf(factor, 0.0, 1.0)
	candle_light.light_energy = BANDS[band][0] * dim * (FIGHT_GLOW if fighting else 1.0)


func lit_ranks() -> int:
	return BANDS[band][3]


func clear_figures() -> void:
	# A standalone clear can also occur while the held spotlight is easing out.
	end_spotlight(0.0)
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
	# A seat reused after a Hanging doll recovers must stand upright again.
	# place_flat() sets a lying pose after this common reset.
	figure.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	figure.rotation = Vector3.ZERO
	figure.texture = texture
	figure.offset = Vector2.ZERO
	figure.scale = Vector3.ONE
	var tall := float(texture.get_height()) if texture != null else 512.0
	figure.pixel_size = height / tall
	figure.position = where + Vector3(0, height / 2.0, 0)
	figure.modulate = Color.WHITE
	figure.visible = texture != null
	figure.set_meta("still", texture)
	figure.set_meta("still_pixel_size", figure.pixel_size)
	figure.set_meta("idle_frames", idle_frames(texture))
	figure.set_meta("idle_fit", _idle_fits.get(texture.resource_path if texture != null else "", Vector3.ONE))
	figure.set_meta("idle_phase", float(absi(hash(id)) % 997) / 997.0)
	return figure


## A still's idle loop: the Flow strip beside it ("<still>_idle.png") cut into frames, or empty.
func idle_frames(still: Texture2D) -> Array:
	if still == null or still.resource_path.is_empty():
		return []
	var path := still.resource_path
	if not _idle_cache.has(path):
		# Smooth loop first: "<still>_idle24_<n>.png" strips played in order at IDLE_SMOOTH_FPS.
		var strip: Texture2D = null
		var frames: Array = []
		for chunk in range(IDLE_SMOOTH_CHUNKS):
			var chunk_path := "%s_idle24_%d.png" % [path.get_basename(), chunk]
			if not ResourceLoader.exists(chunk_path):
				break
			var part: Texture2D = load(chunk_path)
			var cut: Array = ROSTER.Puppet.loop_frames(part, still)
			if cut.is_empty():
				frames = []
				break
			strip = part if strip == null else strip
			frames.append_array(cut)
		_idle_rates[path] = IDLE_SMOOTH_FPS if not frames.is_empty() else IDLE_FPS
		if frames.is_empty():
			var strip_path := path.get_basename() + "_idle.png"
			strip = load(strip_path) if ResourceLoader.exists(strip_path) else null
			frames = ROSTER.Puppet.loop_frames(strip, still)
		_idle_cache[path] = frames
		if not frames.is_empty():
			_idle_fits[path] = _idle_fit(strip, still)
	return _idle_cache[path]


## How a loop cell lines up with its still: x = the cell's scale, y/z = its offset in cell pixels
## (unflipped). Most strips are drawn at the still's pixel scale with the figure standing on the
## cell's bottom edge; a few were drawn smaller (cell shorter than the still), so their figure is
## measured and scaled up to the still's, feet on the same spot.
static func _idle_fit(strip: Texture2D, still: Texture2D) -> Vector3:
	var cell := float(strip.get_height())
	var tall := float(still.get_height())
	var plain := Vector3(1.0, 0.0, (cell - tall) / 2.0)
	if cell >= tall * 0.95:
		return plain
	var art := _art_rect(_plain(still.get_image()), Rect2i(0, 0, still.get_width(), still.get_height()))
	var image := _plain(strip.get_image())
	var count := floori(float(strip.get_width()) / cell)
	var cells: Array[Rect2] = []
	for index in range(0, count, maxi(1, floori(count / 5.0))):
		var seen := _art_rect(image, Rect2i(index * int(cell), 0, int(cell), int(cell)))
		if seen.size.y > 0.0:
			cells.append(seen)
	if art.size.y <= 0.0 or cells.is_empty():
		return plain
	cells.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.size.y < b.size.y)
	var middle := cells[cells.size() >> 1]
	var grow := art.size.y / middle.size.y
	var across := (art.get_center().x - still.get_width() / 2.0) / grow + cell / 2.0 - middle.get_center().x
	var lift := ((tall - art.end.y) - tall / 2.0) / grow + cell / 2.0 - (cell - middle.end.y)
	return Vector3(grow, across, lift)


static func _plain(image: Image) -> Image:
	if image != null and image.is_compressed():
		image.decompress()
	return image


## The painted part of `region` (alpha over half), sampled every third pixel.
static func _art_rect(image: Image, region: Rect2i) -> Rect2:
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for y in range(region.position.y, region.end.y, 3):
		for x in range(region.position.x, region.end.x, 3):
			if image.get_pixel(x, y).a > 0.5:
				low = low.min(Vector2(x, y))
				high = high.max(Vector2(x + 3, y + 3))
	if high.x <= low.x:
		return Rect2()
	return Rect2(low - Vector2(region.position), high - low)


## The picture a figure is placed and aimed by: its still while it idles, else the pose it shows.
func placed_texture(figure: Sprite3D) -> Texture2D:
	var frames: Array = figure.get_meta("idle_frames", [])
	return figure.get_meta("still") if not frames.is_empty() and figure.texture in frames else figure.texture


## That picture's world size (a loop cell drawn at its fitted scale still counts as the still).
func placed_size(figure: Sprite3D) -> Vector2:
	var placed := placed_texture(figure)
	if placed == null:
		return Vector2.ZERO
	var scale := float(figure.get_meta("still_pixel_size", figure.pixel_size)) if placed != figure.texture else figure.pixel_size
	return Vector2(placed.get_width(), placed.get_height()) * scale


func _motion_held() -> bool:
	return reduced_motion or bool(ProjectSettings.get_setting("accessibility/reduced_motion", false))


func _process(delta: float) -> void:
	_idle_clock += delta
	var held := _motion_held()
	for figure: Sprite3D in figure_nodes.values():
		_idle_step(figure, held)


## Shows the figure's current loop frame; a fight pose on it is left alone (the fight hands the
## figure back to its still), and reduced motion holds the still.
func _idle_step(figure: Sprite3D, held: bool) -> void:
	var frames: Array = figure.get_meta("idle_frames", [])
	if frames.is_empty() or not figure.visible:
		return
	var still: Texture2D = figure.get_meta("still")
	if figure.texture != still and not figure.texture in frames:
		return
	var still_size := float(figure.get_meta("still_pixel_size", figure.pixel_size))
	if held:
		figure.texture = still
		figure.offset = Vector2.ZERO
		figure.pixel_size = still_size
		return
	var count := frames.size()
	var fit: Vector3 = figure.get_meta("idle_fit", Vector3.ONE)
	var rate := float(_idle_rates.get(still.resource_path, IDLE_FPS))
	figure.texture = frames[int(_idle_clock * rate + float(figure.get_meta("idle_phase", 0.0)) * count) % count]
	figure.pixel_size = still_size * fit.x
	# Sprite3D mirrors only the picture inside its rect, so a flipped figure mirrors the offset too.
	figure.offset = Vector2(-fit.y if figure.flip_h else fit.y, fit.z)


## Lays a picture on the floor, tipped up a little toward the eye so it still reads. Roll turns it on
## the floor: an up-pointing picture points down the hall at 0, left at PI/2 and right at -PI/2.
func place_flat(id: String, texture: Texture2D, where: Vector3, length: float, roll: float = 0.0, tilt: float = 0.55) -> Sprite3D:
	var figure := place(id, texture, where, length)
	figure.set_meta("idle_frames", [])
	figure.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	figure.rotation = Vector3(-(PI / 2.0 - tilt), 0, roll)
	var wide := float(texture.get_width()) * figure.pixel_size if texture != null else length
	var lift := (absf(length * cos(roll)) + absf(wide * sin(roll))) / 2.0 * sin(tilt)
	figure.position = where + Vector3(0, lift + 0.01, 0)
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
	var feet := figure.global_position
	if figure.billboard != BaseMaterial3D.BILLBOARD_DISABLED:
		feet -= Vector3(0, placed_size(figure).y / 2.0, 0)
	if camera.is_position_behind(feet):
		return null
	var scale_factor := size / Vector2(viewport.size) if viewport.size.x > 0 and size.x > 0 else Vector2.ONE
	return camera.unproject_position(feet) * scale_factor


## Turns the corridor into a fight: the party stands on the left, the foes on the right,
## seen side-on through the cut-away near wall (its back face is never drawn).
func fight_view(on: bool = true) -> void:
	cancel_fight_focus()
	fighting = on
	stop()
	if on:
		camera.fov = FIGHT_FOV
		camera.position = Vector3(FIGHT_EYE.x, FIGHT_EYE.y, fight_z() - 0.25)
		camera.rotation = Vector3(deg_to_rad(FIGHT_PITCH), PI / 2, 0)
		_fight_home = camera.transform
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
## Three foes get breathing room for broad stitched silhouettes. A fourth occupant
## uses the tighter layout so the back rank and its hit target remain on screen.
const FOE_SPREAD_THREE := 1.23
const FOE_SPREAD_FOUR := 0.62
func fight_point(side: String, rank: int, four_foes: bool = false) -> Vector3:
	var index := clampi(rank, 1, 4) - 1
	var depth := -0.15 if index % 2 == 1 else 0.1
	if side == "hero":
		return Vector3(depth, 0, fight_z() + 0.45 + index * 0.75)
	# Give broad front foes clearance from the Warden's shield in two/three-foe
	# fights; keep the compact four-foe line inside the viewport.
	var lead := 0.45 if four_foes else 0.63
	return Vector3(depth, 0, fight_z() - lead - index * (FOE_SPREAD_FOUR if four_foes else FOE_SPREAD_THREE))


## The figure's whole picture on screen (in this stage's pixels); empty when out of sight.
func screen_rect(id: String) -> Rect2:
	var figure: Sprite3D = figure_nodes.get(id)
	if figure == null or not figure.visible or figure.texture == null or not is_inside_tree():
		return Rect2()
	var half := placed_size(figure) / 2.0
	var scale_factor := size / Vector2(viewport.size) if viewport.size.x > 0 and size.x > 0 else Vector2.ONE
	if figure.billboard == BaseMaterial3D.BILLBOARD_DISABLED:
		# Lying on the floor: the bounds of its four corners as the eye sees them.
		var corners: Array[Vector2] = []
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var point: Vector3 = figure.global_transform * Vector3(corner.x * half.x, corner.y * half.y, 0)
			if camera.is_position_behind(point):
				return Rect2()
			corners.append(camera.unproject_position(point) * scale_factor)
		var bounds := Rect2(corners[0], Vector2.ZERO)
		for seen in corners:
			bounds = bounds.expand(seen)
		return bounds
	var across := camera.global_transform.basis.x
	var top := figure.global_position + Vector3.UP * half.y - across * half.x
	var bottom := figure.global_position - Vector3.UP * half.y + across * half.x
	if camera.is_position_behind(top) or camera.is_position_behind(bottom):
		return Rect2()
	return Rect2(camera.unproject_position(top) * scale_factor, Vector2.ZERO).expand(camera.unproject_position(bottom) * scale_factor)


## A single authored-figure camera beat. Keys are live occupied seats supplied by the
## receipt presenter; never derive them from an assumed rank or an attack cursor.
## The camera is only borrowed: it always returns to the exact fight transform.
func start_fight_focus(keys: Array[String], duration: float = 0.4) -> bool:
	if not fighting or not is_inside_tree() or keys.size() < 2:
		return false
	cancel_fight_focus()
	var anchors: Array[Sprite3D] = []
	for key in keys:
		var figure: Sprite3D = figure_nodes.get(key)
		if figure == null or not figure.visible or figure.texture == null:
			continue
		if camera.is_position_behind(figure.global_position):
			continue
		anchors.append(figure)
	if anchors.size() < 2:
		return false
	# Keep the camera at its full-line centre: panning toward the acting pair
	# can send the distant rear rank outside the screen. The lit pair still
	# steps forward and grows during the strike.
	var aim := _fight_home.origin
	# Zoom toward the acting pair only while the OTHER seated figures still fit.
	# A rear foe or doll can be pushed off-screen when only the two lit seats are
	# measured, even though they are correctly framed themselves.
	var framed: Array[String] = []
	for key in figure_nodes:
		var seated: Sprite3D = figure_nodes[key]
		if seated.visible and seated.texture != null and not camera.is_position_behind(seated.global_position):
			framed.append(key)
	var chosen := FIGHT_FOV
	# Leave room for a wider follow-through silhouette and the 10% foreground
	# growth after the framing check (the still is narrower than some poses).
	# A three-foe line needs the outer safe margin for its wider separation;
	# still reject any candidate that would actually clip a sprite off screen.
	var safe := Rect2(size.x * 0.01, size.y * 0.15, size.x * 0.98, size.y * 0.62)
	camera.position = aim
	for candidate in [33.0, 35.0, 37.0, 39.0, 41.0, 42.0, 43.0]:
		camera.fov = candidate
		var within := true
		for key in framed:
			var rect := screen_rect(key)
			if rect.size.x <= 0.0 or not safe.encloses(rect):
				within = false
				break
		if within:
			chosen = candidate
			break
	camera.transform = _fight_home
	camera.fov = FIGHT_FOV
	if chosen >= FIGHT_FOV:
		return false
	var ease_in := duration * 0.32
	var ease_out := duration * 0.44
	_focus_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_focus_tween.tween_property(camera, "position", aim, ease_in).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_focus_tween.parallel().tween_property(camera, "fov", chosen, ease_in).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_focus_tween.tween_interval(duration - ease_in - ease_out)
	_focus_tween.tween_property(camera, "position", _fight_home.origin, ease_out).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_focus_tween.parallel().tween_property(camera, "fov", FIGHT_FOV, ease_out).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_focus_tween.finished.connect(func(): _focus_tween = null)
	return true


func fight_focus_active() -> bool:
	return _focus_tween != null and _focus_tween.is_running()


## Used on a replaced receipt, motion-toggle, fight exit and stage teardown.
func cancel_fight_focus() -> void:
	if _focus_tween != null:
		_focus_tween.kill()
		_focus_tween = null
	end_spotlight(0.0)
	if fighting:
		camera.transform = _fight_home
		camera.fov = FIGHT_FOV


## Owner 11-10 attack spotlight: the corridor dims around the acting pair (`lit_keys`),
## the pair brightens a touch and is drawn in front of everyone else; figures in
## `flash_keys` keep their own held hit-reaction colour instead of the brighten.
func begin_spotlight(lit_keys: Array[String], flash_keys: Array[String] = [], time: float = SPOT_IN) -> void:
	if not is_inside_tree() or corridor == null:
		return
	end_spotlight(0.0)
	_spot_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	for surface_node in corridor.get_children():
		var material := (surface_node as MeshInstance3D).get_active_material(0) as StandardMaterial3D
		if material != null:
			_spot_tween.parallel().tween_property(material, "albedo_color", SURFACE_TINT * SPOT_SURFACE, time) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_spot_tween.parallel().tween_property(environment, "ambient_light_energy", SPOT_AMBIENT, time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for key in figure_nodes:
		var figure: Sprite3D = figure_nodes[key]
		# The acting figure (first lit seat) is drawn over its targets so a close target, or a
		# big foe, never hides the strike pose it has to read.
		figure.render_priority = 2 if (not lit_keys.is_empty() and lit_keys[0] == key) \
			else (1 if lit_keys.has(key) else 0)
		if flash_keys.has(key):
			continue
		var tone := SPOT_LIT if lit_keys.has(key) else SPOT_DIM
		_spot_tween.parallel().tween_property(figure, "modulate", tone, time) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Everything eases back to its normal light; figures return to plain white and the
## fight re-shades them straight after. A `time` of 0 snaps (toggles, teardown).
func end_spotlight(time: float = SPOT_EASE) -> void:
	if _spot_tween != null:
		_spot_tween.kill()
		_spot_tween = null
	if time <= 0.0 or not is_inside_tree() or corridor == null:
		if figure_nodes != null:
			for key in figure_nodes:
				figure_nodes[key].render_priority = 0
		if corridor != null:
			for surface_node in corridor.get_children():
				var snap := (surface_node as MeshInstance3D).get_active_material(0) as StandardMaterial3D
				if snap != null:
					snap.albedo_color = SURFACE_TINT
		if environment != null:
			environment.ambient_light_energy = AMBIENT_BASE
		if figure_nodes != null:
			for key in figure_nodes:
				figure_nodes[key].modulate = Color.WHITE
				figure_nodes[key].scale = Vector3.ONE
		return
	_spot_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	for surface_node in corridor.get_children():
		var material := (surface_node as MeshInstance3D).get_active_material(0) as StandardMaterial3D
		if material != null:
			_spot_tween.parallel().tween_property(material, "albedo_color", SURFACE_TINT, time) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_spot_tween.parallel().tween_property(environment, "ambient_light_energy", AMBIENT_BASE, time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for key in figure_nodes:
		_spot_tween.parallel().tween_property(figure_nodes[key], "modulate", Color.WHITE, time) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Keep the acting pair drawn in front until the return light has fully eased.
	_spot_tween.finished.connect(func():
		for figure in figure_nodes.values():
			figure.render_priority = 0
		_spot_tween = null
	)


## The whole spotlight as one unattended pulse (reduced motion: the movement is
## skipped, the dim/brighten beat still plays out and eases back by itself).
func spot_pulse(lit_keys: Array[String], flash_keys: Array[String], hold: float, time: float = SPOT_IN) -> void:
	begin_spotlight(lit_keys, flash_keys, time)
	if _spot_tween == null:
		return
	_spot_tween.tween_interval(hold)
	_spot_tween.tween_callback(end_spotlight)


func _exit_tree() -> void:
	cancel_fight_focus()
