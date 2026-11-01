extends SceneTree
## Deterministic bounds and authority tests on the REAL eight-tile chooser.
const SCENE := "res://scenes/v3_party_picker.tscn"
const SETTING := "accessibility/reduced_motion"
const ORDER: Array[String] = [
	"warden", "seamstress", "tinker", "lantern_monk",
	"rag_duelist", "scarecrow", "yarn_ranger", "button_golem",
]
var failures: Array[String] = []
var checks := 0
var requests: Array = []
var cancels := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)


func _frames() -> void:
	for i in range(4):
		await process_frame


func _tile(picker: LiveV3PartyPicker, id: String) -> Button:
	return picker.get_node_or_null("PaperPanel/Margins/Body/HeroGrid/Hero_" + id) as Button


func _portrait(picker: LiveV3PartyPicker, id: String) -> TextureRect:
	var tile := _tile(picker, id)
	return tile.get_node_or_null("Inset/Stack/Face/Portrait") as TextureRect if tile != null else null


func _neutral(picker: LiveV3PartyPicker, context: String) -> void:
	for id in ORDER:
		var portrait := _portrait(picker, id)
		if portrait != null:
			_check(is_equal_approx(portrait.rotation, 0.0)
				and portrait.scale.is_equal_approx(Vector2.ONE),
				context + " neutral image " + id)


func _geometry(picker: LiveV3PartyPicker) -> Dictionary:
	var result := {}
	for id in ORDER:
		var tile := _tile(picker, id)
		if tile == null:
			continue
		for relative in ["", "KeyCue", "Inset/Stack/NameLabel",
				"Inset/Stack/Face", "Inset/Stack/Face/SeatBadge",
				"Inset/Stack/MotifLabel", "Inset/Stack/PickLabel"]:
			var control: Control = tile if relative.is_empty() else tile.get_node(relative)
			result[id + "/" + relative] = [control.get_global_rect(),
				control.focus_mode, control.mouse_filter]
	for relative in ["PaperPanel/Margins/Body/InspectionPanel",
			"PaperPanel/Margins/Body/InspectionPanel/Inset/Stack/InspectionHeading",
			"PaperPanel/Margins/Body/InspectionPanel/Inset/Stack/InspectionFacts",
			"PaperPanel/Margins/Body/Foot/Hint",
			"PaperPanel/Margins/Body/Foot/SelectionCount",
			"PaperPanel/Margins/Body/Foot/ContinueButton",
			"PaperPanel/Margins/Body/Foot/CancelButton"]:
		var control := picker.get_node(relative) as Control
		result[relative] = [control.get_global_rect(), control.focus_mode, control.mouse_filter]
	return result


func _phase_checks(picker: LiveV3PartyPicker, label: String) -> void:
	var original := _geometry(picker)
	var ids := picker.selected_ids()
	var receipt := picker._seat_receipt.duplicate(true)
	var caption := picker.seat_preview.text
	var details := [picker.inspection_heading.text, picker.inspection_detail.text,
		picker.inspection_facts.text, picker.inspection_starters.text]
	var signals := [requests.size(), cancels]
	var poses: Array[float] = []
	for time in [0.0, 2.25, 4.5, 6.75, 9.0]:
		picker._pose_portraits_at(time)
		for index in range(ORDER.size()):
			var id := ORDER[index]
			var picture := _portrait(picker, id)
			if picture == null:
				var tile := _tile(picker, id)
				var motif := tile.get_node_or_null("Inset/Stack/Face/FallbackMotif") as Control
				_check(motif != null and is_equal_approx(motif.rotation, 0.0)
					and motif.scale.is_equal_approx(Vector2.ONE),
					label + " original missing-art fallback remains static " + id)
				continue
			_check(picture.texture != null and picture.mouse_filter == Control.MOUSE_FILTER_IGNORE,
				label + " loaded imported image is input inert " + id)
			_check(absf(picture.rotation) <= 0.005001,
				label + " absolute tilt cap " + id)
			_check(picture.scale.x >= 0.999999 and picture.scale.x <= 1.006001
				and is_equal_approx(picture.scale.x, picture.scale.y),
				label + " uniform, non-shrinking scale cap " + id)
			_check(picture.pivot_offset.is_equal_approx(picture.size * 0.5),
				label + " centre pivot " + id)
			if time == 2.25:
				poses.append(picture.rotation)
		if time == 0.0 or time == 9.0:
			_neutral(picker, label + " zero/full-period")
		_check(_geometry(picker) == original,
			label + " untouched tile/key/label/face/badge/inspection/action rects and focus")
		_check(picker.selected_ids() == ids and picker._seat_receipt == receipt
			and picker.seat_preview.text == caption
			and [picker.inspection_heading.text, picker.inspection_detail.text,
				picker.inspection_facts.text, picker.inspection_starters.text] == details
			and [requests.size(), cancels] == signals,
			label + " pose is presentation-only (receipt/preview/signal stable)")
	var distinct := false
	for a in range(poses.size()):
		for b in range(a + 1, poses.size()):
			if not is_equal_approx(poses[a], poses[b]):
				distinct = true
	_check(distinct, label + " fixed hero-index phases visibly differ at quarter period")


func _key(picker: LiveV3PartyPicker, id: String, key: Key) -> void:
	var button := _tile(picker, id)
	_check(button != null and button.focus_mode == Control.FOCUS_ALL, "real keyboard tile " + id)
	if button == null:
		return
	button.grab_focus()
	await _frames()
	_check(button.has_focus(), "keyboard focus owns actual tile " + id)
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = down
		root.push_input(event, true)
	await _frames()


func _mouse(picker: LiveV3PartyPicker, id: String) -> void:
	var button := _tile(picker, id)
	_check(button != null and button.is_visible_in_tree(), "real mouse tile " + id)
	if button == null:
		return
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
	await _frames()


func _receipt(picker: LiveV3PartyPicker, chosen: Array[String], label: String) -> void:
	var canonical := RunV3PartyAdmission.admit(chosen)
	_check(canonical.get("ok", false) and canonical.get("hero_ids", []).size() == 3
		and canonical.get("deck", []).size() == 12, label + " real admission/12 starters")
	if not canonical.get("ok", false):
		return
	_check(picker.selected_ids() == chosen and picker._seat_receipt == canonical,
		label + " exact 3 chosen IDs, canonical sorted seats, HP, passives, starters")
	var seats: Array[String] = []
	for i in range(3):
		seats.append("%d %s" % [i + 1, canonical["party"][i]["name"]])
		_check(canonical["party"][i]["id"] == canonical["hero_ids"][i],
			label + " admitted hero in default-sorted seat")
	_check(picker.seat_preview.text == "Seats: " + "  |  ".join(seats),
		label + " visible receipt/seat preview")
	_check(picker._deck_receipt_rows().size() == 3
		and picker._deck_receipt_facts(picker._deck_receipt_rows()).size() == 3
		and not picker.continue_button.disabled,
		label + " authenticated deck and HP/passive inspection available")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var had_setting := ProjectSettings.has_setting(SETTING)
	var previous_setting: Variant = ProjectSettings.get_setting(SETTING, false)
	ProjectSettings.set_setting(SETTING, false)
	var packed := load(SCENE) as PackedScene
	_check(packed != null, "actual chooser scene is loadable")
	if packed == null:
		ProjectSettings.set_setting(SETTING, previous_setting if had_setting else null)
		_finish()
		return
	var picker := packed.instantiate() as LiveV3PartyPicker
	_check(picker != null, "actual chooser script is mounted")
	if picker == null:
		ProjectSettings.set_setting(SETTING, previous_setting if had_setting else null)
		_finish()
		return
	root.add_child(picker)
	await _frames()
	picker.party_requested.connect(func(ids: Array[String]) -> void: requests.append(ids))
	picker.cancel_requested.connect(func() -> void: cancels += 1)
	_check(picker.is_visible_in_tree() and picker._open
		and picker.grid.get_child_count() == 8, "actual opened four-column eight-hero grid")
	var loaded := 0
	for id in ORDER:
		var tile := _tile(picker, id)
		_check(tile != null and tile.get_parent() == picker.grid
			and not tile.disabled and tile.clip_contents, "genuine clipped Button Hero_" + id)
		if tile == null:
			continue
		var picture := _portrait(picker, id)
		var fallback := tile.get_node_or_null("Inset/Stack/Face/FallbackMotif")
		_check((picture != null) != (fallback != null), "one image or static fallback for " + id)
		if picture != null:
			loaded += 1
			_check(picker._portrait_art.get(id) == picture, "only imported image tracked " + id)
	_check(loaded > 0, "at least one actual authored hero PNG was imported (non-vacuous motion)")
	_check(picker.is_processing(), "one frame clock active only with mounted visible artwork")
	_phase_checks(picker, "initial open")

	ProjectSettings.set_setting(SETTING, true)
	await _frames()
	_check(not picker.is_processing(), "project accessibility reduced_motion stops processing")
	_neutral(picker, "project reduced motion")
	picker._pose_portraits_at(2.25)
	_neutral(picker, "no pose while project setting reduced")
	ProjectSettings.set_setting(SETTING, false)
	await _frames()
	_check(picker.is_processing(), "restored project setting starts new neutral clock")
	picker.set_reduced_motion_override(true)
	_check(not picker.is_processing(), "per-view reduced motion stops processing")
	_neutral(picker, "override reduced")
	picker.set_reduced_motion_override(false)
	_check(picker.is_processing(), "override false allows art clock")
	picker.set_reduced_motion_override(null)
	_phase_checks(picker, "restored accessibility")

	picker.hide()
	_check(not picker.is_processing(), "hidden picker stops clock")
	_neutral(picker, "hidden")
	picker._process(2.25)
	_neutral(picker, "hidden tick ignored")
	picker.show()
	await _frames()
	_check(picker.is_processing(), "shown picker resumes safely")

	await _key(picker, "yarn_ranger", KEY_7)
	await _mouse(picker, "warden")
	await _key(picker, "lantern_monk", KEY_4)
	_receipt(picker, ["yarn_ranger", "warden", "lantern_monk"], "mixed keyboard and mouse")
	_phase_checks(picker, "three authentic picks")
	var old_picture := _portrait(picker, "warden")
	var old_tile := _tile(picker, "warden")
	var old_generation: int = picker._generation
	picker.continue_button.pressed.emit()
	_check(requests.size() == 1 and requests[0] == ["yarn_ranger", "warden", "lantern_monk"]
		and picker._latched and not picker._open and not picker.is_processing(),
		"Continue latches and submits exactly one unmodified party")
	_neutral(picker, "continued")
	picker.continue_button.pressed.emit()
	picker.cancel_button.pressed.emit()
	_check(requests.size() == 1 and cancels == 0, "latched Continue/Cancel cannot double emit")

	picker.open_picker()
	_check(picker._generation == old_generation + 1 and picker._portrait_art.get("warden") != old_picture
		and picker._open and picker.selected_ids().is_empty(),
		"fresh generation discards all old portrait references and selection")
	old_tile.pressed.emit()
	picker._pressed_hero("warden", old_generation)
	_check(picker.selected_ids().is_empty(), "retired generation click is inert")
	await _frames()
	_check(picker.is_processing(), "reopened real chooser clock active")
	_phase_checks(picker, "second opening")

	# Missing imported art is resolved through the normal _mount_tile fallback
	# branch; no artwork files are modified or synthesized in the test.
	picker.portrait_path_overrides["tinker"] = "res://assets/paper/heroes/__absent_portrait__.png"
	picker.open_picker()
	await _frames()
	var fallback := _tile(picker, "tinker").get_node_or_null("Inset/Stack/Face/FallbackMotif") as Control
	_check(fallback != null and _portrait(picker, "tinker") == null
		and not picker._portrait_art.has("tinker"),
		"real missing-art loader selects existing input-inert fallback")
	picker._pose_portraits_at(2.25)
	_check(fallback != null and fallback.rotation == 0.0
		and fallback.scale == Vector2.ONE, "static stand-in never breathes")
	_phase_checks(picker, "real fallback alongside imported images")
	picker.portrait_path_overrides.clear()
	picker.cancel_button.pressed.emit()
	_check(cancels == 1 and requests.size() == 1 and not picker.visible
		and not picker.is_processing(), "Cancel hides/stops/one-shots without submitting")
	_neutral(picker, "cancelled")
	picker.cancel_button.pressed.emit()
	_check(cancels == 1, "cancel latch refuses duplicate signal")

	picker.open_picker()
	await _frames()
	_check(_portrait(picker, "tinker") != null and picker.is_processing(),
		"reopening restores genuine imported art and motion after fallback")
	await _key(picker, "button_golem", KEY_8)
	await _mouse(picker, "seamstress")
	await _key(picker, "scarecrow", KEY_6)
	_receipt(picker, ["button_golem", "seamstress", "scarecrow"], "after cancel/reopen")
	_phase_checks(picker, "second complete three-pick cycle")
	picker.continue_button.pressed.emit()
	picker.continue_button.pressed.emit()
	_check(requests.size() == 2 and requests[1] == ["button_golem", "seamstress", "scarecrow"]
		and cancels == 1 and not picker.is_processing(), "second submission exactly once")
	_neutral(picker, "second continued")
	picker.queue_free()
	await _frames()
	_check(not is_instance_valid(picker), "exit-tree releases old picker and references")
	ProjectSettings.set_setting(SETTING, previous_setting if had_setting else null)
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("PASS live_v3_party_picker_portrait_motion_test (%d checks)" % checks)
		quit(0)
		return
	for failure in failures:
		printerr("FAIL: " + failure)
	printerr("FAIL live_v3_party_picker_portrait_motion_test (%d/%d failed)" % [
		failures.size(), checks])
	quit(1)
