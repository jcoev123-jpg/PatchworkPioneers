extends SceneTree
## Owner 11-09 "idle animations for characters": corridor figures play their Flow idle strip,
## keep their feet on the still's foot line, yield to fight poses and hold still on reduced motion.
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, why: String) -> void:
	checks += 1
	if not ok:
		failures.append(why)


func _frames(count: int) -> void:
	for _frame in range(count):
		await process_frame


## The painted part of what the figure shows now, in its own world units (x across, y up from its middle).
func _drawn_box(figure: Sprite3D) -> Rect2:
	var shown := figure.texture
	var image: Image
	if shown is AtlasTexture:
		image = (shown as AtlasTexture).atlas.get_image().get_region(Rect2i((shown as AtlasTexture).region))
	else:
		image = shown.get_image()
	if image.is_compressed():
		image.decompress()
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for y in range(0, image.get_height(), 2):
		for x in range(0, image.get_width(), 2):
			if image.get_pixel(x, y).a > 0.5:
				low = low.min(Vector2(x, y))
				high = high.max(Vector2(x + 2, y + 2))
	var half := Vector2(image.get_width(), image.get_height()) / 2.0
	var left := (figure.offset.x - half.x + low.x) if not figure.flip_h else (figure.offset.x + half.x - high.x)
	var bottom := figure.offset.y + half.y - high.y
	return Rect2(Vector2(left, bottom) * figure.pixel_size, (high - low) * figure.pixel_size)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var stage := StitchedCorridorStage.new()
	stage.size = Vector2(1280, 720)
	root.add_child(stage)
	stage.build("walls", 4)
	var still := StitchedCorridorStage.hero_art("rag_duelist")
	_check(still != null and ResourceLoader.exists("res://assets/paper/heroes/rag_duelist_idle.png"),
		"precondition: a hero still with its idle strip")
	var figure := stage.place("hero_1", still, stage.ahead_point(), StitchedCorridorStage.DOLL_HEIGHT)
	var frames: Array = stage.idle_frames(still)
	_check(frames.size() > 1, "the hero's idle strip cuts into frames")
	_check(stage.screen_rect("hero_1").size.y > 0.0, "precondition: the hero stands in sight")
	var rest_rect := stage.screen_rect("hero_1")
	var rest_feet: Variant = stage.screen_point("hero_1")

	var seen: Dictionary = {}
	var feet_world: Array[float] = []
	for _beat in range(12):
		await _frames(3)
		seen[figure.texture] = true
		var drawn: float = figure.position.y + (figure.offset.y - figure.texture.get_height() / 2.0) * figure.pixel_size
		feet_world.append(drawn)
	_check(seen.size() > 2, "the figure cycles through several idle frames (%d seen)" % seen.size())
	var all_frames := true
	for texture in seen:
		all_frames = all_frames and texture in frames
	_check(all_frames, "every idling picture is a frame of the figure's own strip")
	var foot_line: float = figure.position.y - still.get_height() / 2.0 * figure.pixel_size
	var level := true
	for drawn in feet_world:
		level = level and absf(drawn - foot_line) < 0.002
	_check(level, "loop frames stand on the still's foot line")
	_check(stage.placed_texture(figure) == still, "placement still reads the still while it idles")
	_check(stage.screen_rect("hero_1").is_equal_approx(rest_rect) and stage.screen_point("hero_1") == rest_feet,
		"targets and feet use the still, not the moving frame")

	var pose := load("res://assets/paper/heroes/rag_duelist_attack.png") as Texture2D
	if pose == null:
		pose = StitchedCorridorStage.hero_art("seamstress")
	figure.texture = pose
	figure.offset = Vector2.ZERO
	await _frames(6)
	_check(figure.texture == pose and figure.offset == Vector2.ZERO, "a fight pose is never overwritten by the loop")
	figure.texture = still
	await _frames(6)
	_check(figure.texture in frames, "handing the figure back its still resumes the loop")

	stage.reduced_motion = true
	await _frames(3)
	_check(figure.texture == still and figure.offset == Vector2.ZERO, "reduced motion holds the figure on its still")
	stage.reduced_motion = false

	# Some strips were drawn smaller than their still: the loop is scaled so the figure keeps its size.
	var guard := ResourceLoader.load("res://assets/paper/enemies/button_guard.png") as Texture2D
	if guard != null and ResourceLoader.exists("res://assets/paper/enemies/button_guard_idle.png"):
		var foe := stage.place("foe_1", guard, stage.ahead_point(1.2, 0.4), StitchedCorridorStage.DOLL_HEIGHT)
		foe.flip_h = true
		var still_box := _drawn_box(foe)
		await _frames(4)
		_check(foe.texture in stage.idle_frames(guard), "precondition: the foe is idling")
		var loop_box := _drawn_box(foe)
		_check(absf(loop_box.size.y - still_box.size.y) < still_box.size.y * 0.12,
			"a small-drawn loop is scaled to the still's height (%.3f vs %.3f)" % [loop_box.size.y, still_box.size.y])
		_check(absf(loop_box.position.y - still_box.position.y) < still_box.size.y * 0.04,
			"the scaled loop keeps the still's feet")
		_check(absf(loop_box.get_center().x - still_box.get_center().x) < still_box.size.x * 0.25,
			"the scaled loop stays over the still's spot, flipped too")
		_check(stage.screen_rect("foe_1").size.y > 0.0 and is_equal_approx(stage.placed_size(foe).y, guard.get_height() * float(foe.get_meta("still_pixel_size"))),
			"targets still use the still's size")
		stage.reduced_motion = true
		await _frames(3)
		_check(foe.texture == guard and is_equal_approx(foe.pixel_size, foe.get_meta("still_pixel_size")),
			"reduced motion puts the foe back at its still's scale")
		stage.reduced_motion = false

	var flat := stage.place_flat("rug", still, stage.ahead_point(1.0), 1.0)
	await _frames(6)
	_check(flat.texture == still, "pictures laid flat on the floor never play a loop")
	var prop := stage.place("prop", StitchedCorridorStage.art("tex_walls_wall"), stage.ahead_point(1.5), 1.0)
	_check(stage.idle_frames(prop.texture).is_empty(), "a picture without a strip has no loop")

	stage.free()
	for failure in failures:
		printerr("FAIL: ", failure)
	print("stitched_corridor_idle_loop_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
