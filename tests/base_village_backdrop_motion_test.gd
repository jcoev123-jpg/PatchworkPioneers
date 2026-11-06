extends SceneTree
## Mounted Quilt Village authored-image idle; no Control or run-state animation.
const SCENE := preload("res://scenes/base_screen.tscn")
const ART := "res://assets/paper/backgrounds/base_village.png"
var failures: Array[String] = []
var checks := 0
var view: BaseScreen
var set_out_count := 0
var back_count := 0
var path_count := 0
var difficulty_count := 0

func _initialize() -> void:
	StitchedBedroom.enabled = false
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func _frames() -> void:
	for i in range(3):
		await process_frame

func _click(button: Button) -> void:
	_check(button.is_visible_in_tree() and not button.disabled, "real GUI target enabled")
	var point := button.get_global_rect().get_center()
	_check(root.get_visible_rect().has_point(point), "pointer inside viewport")
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = point
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		root.push_input(e, true)
		await process_frame

func _options(path: String) -> Array:
	var json: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var rows: Variant = json.get("paths", []) if json is Dictionary else json
	var result: Array = []
	if rows is Array:
		for raw in rows:
			if raw is Dictionary:
				var card: Dictionary = raw.get("card", {})
				result.append({"id": String(raw.get("id", "")),
					"display_name": String(raw.get("display_name", "")),
					"card_name": String(card.get("display_name", ""))})
	return result

func _controls() -> Array:
	var result: Array = []
	for child in view.find_children("*", "Control", true, false):
		var control := child as Control
		var caption := ""
		if control is Button or control is Label:
			caption = control.text
		result.append([control, control.get_global_rect(), control.visible,
			control.mouse_filter, control.focus_mode, control.focus_next,
			control.focus_previous, control.has_focus(), caption,
			control.disabled if control is Button else false])
	return result

func _state() -> Array:
	return [view.village_buildings(), view.village_paths(), view.village_spool(),
		view.path_options(), view.tinker_path_options(), view.warden_path_options(),
		view.selected_path_id(), view.selected_tinker_path_id(),
		view.selected_warden_path_id(), view.wallet_label.text,
		view.village_title_label.text, view.path_hint_label.text,
		view.tinker_hint_label.text, view.warden_hint_label.text,
		view.set_out_button.text, view.back_button.text, view.parts_button.text,
		root.gui_get_focus_owner()]

func _near(a: Rect2, b: Rect2) -> bool:
	return a.position.distance_to(b.position) < 0.02 and a.size.distance_to(b.size) < 0.02

func _phase_checks() -> void:
	var neutral := view.backdrop_rect()
	var layout := _controls()
	var state := _state()
	_check(neutral.has_area() and neutral.encloses(Rect2(Vector2.ZERO, Vector2(1280, 720))),
		"neutral image cover contract is unchanged")
	_check(_near(view.backdrop_image_rect(), neutral), "open starts neutral")
	var quarter := view.backdrop_image_rect_at(3.5)
	var half := view.backdrop_image_rect_at(7.0)
	_check(quarter.size.distance_to(neutral.size * 1.01) < 0.02
		and absf((quarter.get_center() - neutral.get_center()).x - 1.5) < 0.02,
		"quarter phase scales 1% and gently pans")
	_check(half.size.distance_to(neutral.size * 1.02) < 0.02
		and absf((half.get_center() - neutral.get_center()).y + 3.0) < 0.02,
		"half phase scales at most 2% and pans at most 3px")
	_check(_near(view.backdrop_image_rect_at(14.0), neutral), "14-second loop returns neutral")
	var covers := true
	for i in range(65):
		var rect := view.backdrop_image_rect_at(14.0 * float(i) / 64.0)
		var sx := rect.size.x / neutral.size.x
		var sy := rect.size.y / neutral.size.y
		var pan := rect.get_center() - neutral.get_center()
		covers = covers and rect.position.x <= 0.01 and rect.position.y <= 0.01
		covers = covers and rect.end.x >= 1279.99 and rect.end.y >= 719.99
		covers = covers and sx >= 0.99999 and sx <= 1.02001
		covers = covers and absf(sx - sy) <= 0.00001
		covers = covers and absf(pan.x) <= 3.0001 and absf(pan.y) <= 3.0001
	_check(covers, "every phase remains full-cover, uniform and within pan/zoom limits")
	var start: float = view._backdrop_elapsed
	view._process(3.5)
	_check(_near(view.backdrop_image_rect(), view.backdrop_image_rect_at(start + 3.5)),
		"genuine mounted _process advances deterministic elapsed phase")
	view._process(10.5)
	_check(_near(view.backdrop_image_rect(), view.backdrop_image_rect_at(start)),
		"mounted clock wraps without RNG at a full period")
	_check(_controls() == layout and _state() == state,
		"sewn buildings, actions, focus, labels, paths and wallet stay fixed")

func _lifecycle() -> void:
	var neutral := view.backdrop_rect()
	view.hide()
	await _frames()
	_check(view.has_open_village() and not view.is_processing()
		and is_zero_approx(view._backdrop_elapsed)
		and _near(view.backdrop_image_rect(), neutral),
		"hide retires processing and neutralizes image")
	view.show()
	_check(view.is_processing() and is_zero_approx(view._backdrop_elapsed),
		"show restarts at phase zero")
	ProjectSettings.set_setting("accessibility/reduced_motion", true)
	await _frames()
	_check(not view.is_processing() and is_zero_approx(view._backdrop_elapsed)
		and _near(view.backdrop_image_rect(), neutral),
		"reduced motion immediately disables and resets moving picture")
	ProjectSettings.set_setting("accessibility/reduced_motion", false)
	await create_timer(0.45).timeout
	_check(view.is_processing() and view._backdrop_elapsed < 1.0,
		"clearing reduced motion re-arms a fresh phase without reopening")
	view._process(4.0)
	_check(not _near(view.backdrop_image_rect(), neutral), "rearmed picture moves")
	var art: Texture2D = view._backdrop
	_check(BaseScreen.load_base_backdrop("res://assets/paper/backgrounds/nonexistent_village.png") == null,
		"missing-art loader safely returns null")
	view._backdrop = null
	view._sync_backdrop_motion()
	_check(not view.has_backdrop_texture() and not view.is_processing()
		and is_zero_approx(view._backdrop_elapsed)
		and view.backdrop_rect() == Rect2() and view.backdrop_image_rect() == Rect2(),
		"missing image keeps original static matte fallback and no processing")
	view.queue_redraw()
	await _frames()
	view._backdrop = art
	view._sync_backdrop_motion()
	_check(view.is_processing() and is_zero_approx(view._backdrop_elapsed),
		"restored cached authored image can restart in place")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var had_setting := ProjectSettings.has_setting("accessibility/reduced_motion")
	var old_setting: Variant = ProjectSettings.get_setting("accessibility/reduced_motion", false)
	ProjectSettings.set_setting("accessibility/reduced_motion", false)
	seed(428006)
	var expected_rng := randi()
	seed(428006)
	view = SCENE.instantiate() as BaseScreen
	root.add_child(view)
	await _frames()
	_check(view.scene_file_path == "res://scenes/base_screen.tscn"
		and not view.has_open_village() and not view.is_processing(),
		"genuine scene mounts closed, never auto-animates")
	_check(ResourceLoader.exists(ART, "Texture2D") and view.has_backdrop_texture()
		and view.backdrop_texture().get_size().x > 0,
		"actual imported authored village image exists and is usable")
	var seam := _options("res://data/heroes/seamstress_paths.json")
	var tink := _options("res://data/heroes/tinker_paths.json")
	var ward := _options("res://data/heroes/warden_paths.json")
	_check(seam.size() >= 2 and tink.size() >= 2 and ward.size() >= 2,
		"all three shipped Path catalogs have authored choices")
	_check(view.present_path_options(seam) and view.present_tinker_path_options(tink)
		and view.present_warden_path_options(ward), "all real Path boards are mounted")
	view.present_difficulty([0], 0)
	view.set_out_requested.connect(func() -> void: set_out_count += 1)
	view.back_requested.connect(func() -> void: back_count += 1)
	view.path_choice_requested.connect(func(_id: String) -> void: path_count += 1)
	view.difficulty_choice_requested.connect(func(_tier: int) -> void: difficulty_count += 1)
	_check(view.open_village(23, 7), "real open_village succeeds with host wallet")
	await _frames()
	_check(view.is_visible_in_tree() and view.is_processing()
		and view.set_out_button.has_focus(), "Set out takes live keyboard focus")
	_check(view.wallet_label.text == "Gold 23  ·  Scraps 7"
		and view.village_title_label.text == "Quilt village"
		and view.set_out_button.text == "Set out"
		and view.back_button.text == "Back to title"
		and view.parts_button.text == "Parts & spoils"
		and view.path_buttons.size() >= 2 and view.tinker_buttons.size() >= 2
		and view.warden_buttons.size() >= 2 and view.difficulty_buttons.size() == 3,
		"wallet, title, parts modal, Path/difficulty buttons and caption remain live")
	_phase_checks()
	await _lifecycle()
	view.close_village()
	_check(not view.has_open_village() and not view.is_processing()
		and is_zero_approx(view._backdrop_elapsed)
		and _near(view.backdrop_image_rect(), view.backdrop_rect()),
		"close neutralizes image and disables idle")
	for cycle in range(2):
		_check(view.open_village(23, 7) and is_zero_approx(view._backdrop_elapsed)
			and view.is_processing(), "reopen begins zero phase at cycle %d" % cycle)
		await _frames()
		await _click(view.parts_button)
		_check(view.field_guide.is_open() and view.field_guide.part_atlas.is_visible_in_tree(), "actual parts inspector opens")
		view._on_field_guide_close_requested()
		await _frames()
		if cycle == 0:
			await _click(view.back_button)
			view._on_back_pressed()
			_check(back_count == 1 and set_out_count == 0,
				"Back request fires once with pending guard")
		else:
			await _click(view.set_out_button)
			view._on_set_out_pressed()
			_check(set_out_count == 1 and back_count == 1,
				"Set Out request fires once with pending guard")
		view.close_village()
		await _frames()
		_check(not view.is_processing() and is_zero_approx(view._backdrop_elapsed),
			"closed cycle has no stale clock")
	_check(path_count == 0 and difficulty_count == 0
		and view.wallet_label.text == "Gold 23  ·  Scraps 7"
		and view.selected_path_id().is_empty()
		and view.selected_tinker_path_id().is_empty()
		and view.selected_warden_path_id().is_empty() and randi() == expected_rng,
		"animated navigation cannot mutate paths, wallet, difficulty or seeded RNG")
	_check(view.open_village(23, 7), "final mounted exit test opens live village")
	view._process(2.0)
	root.remove_child(view)
	_check(not view.is_inside_tree() and not view.is_processing()
		and is_zero_approx(view._backdrop_elapsed),
		"tree exit disables visual processing and retires phase")
	view.free()
	await _frames()
	if had_setting:
		ProjectSettings.set_setting("accessibility/reduced_motion", old_setting)
	else:
		ProjectSettings.clear("accessibility/reduced_motion")
	if failures.is_empty():
		print("base_village_backdrop_motion_test: PASS (%d checks)" % checks)
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		printerr("base_village_backdrop_motion_test: FAIL (%d/%d)" % [failures.size(), checks])
		quit(1)
