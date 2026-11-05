class_name StitchedWalkScreen
extends Control
## Isolated S8b presentation. Only StitchedWalkRules owns walk state and receipts.

signal exit_requested

const ART_PATH := "res://data/walk/walk_view_art.json"
const CHROME := preload("res://scripts/stitched/stitched_battle_chrome.gd")
const PREVIEW_SEED := 548
const VIEW := Rect2(32, 100, 920, 440)
var walk: StitchedWalkRules
var expected: Dictionary = {}
var receipts: Array = []
var art: Dictionary = {}
var candle := 78
var reduced_motion := false
var eye_profile := "neutral"
var layers: Array[TextureRect] = []
var trailing: Array[TextureRect] = []
var rank_labels: Array[Label] = []
var switch_buttons: Array[Button] = []
var pocket_buttons: Array[Button] = []
var forward_button: Button
var back_button: Button
var exit_button: Button
var target_picker: OptionButton
var readout: Label
var eye_readout: Label
var feedback: Label
var eye_overlay: TextureRect
var travel: Tween


func begin(seed_number: int = PREVIEW_SEED) -> bool:
	if walk != null:
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ART_PATH))
	if not parsed is Dictionary or not validate_art(parsed):
		return false
	var config := StitchedRunSession.starter_config(StitchedRunSession.DEFAULT_PICKS)
	if config.is_empty():
		return false
	var dolls: Array = config.heroes.duplicate(true)
	var pockets := {}
	var supplies := [["thimble_tonic", "fresh_stuffing"], ["starch", "dye"], ["pins", "spare_spool"], []]
	for index in dolls.size():
		dolls[index].merge({"rank": index + 1, "hp": int(dolls[index].max_hp) - 8, "lost": false}, true)
		pockets[dolls[index].id] = supplies[index].duplicate()
	var random := RandomNumberGenerator.new()
	random.seed = seed_number
	walk = StitchedWalkRules.start(random, "walls", dolls, pockets)
	if walk == null:
		return false
	art = parsed
	expected = walk.snapshot()
	return true


static func _art_path(value: Variant) -> bool:
	return value is String and value.begins_with("res://assets/paper/") and value.ends_with(".png") and not ".." in value


static func validate_art(value: Dictionary) -> bool:
	if value.get("version") != 1 or not value.get("fallbacks") is Array or value.fallbacks.size() != 3 \
		or not value.get("corridors") is Dictionary or not value.get("heads") is Dictionary \
		or not value.get("eyes") is Dictionary or not value.get("look_back") is Dictionary:
		return false
	for path in value.fallbacks:
		if not _art_path(path):
			return false
	for profile in ["neutral", "cracked", "glass", "one_eye", "ears"]:
		var record: Variant = value.eyes.get(profile)
		if not record is Dictionary or not _art_path(record.get("path")) or not _art_path(record.get("fallback")):
			return false
	for head in value.heads:
		if not head is String or head.is_empty() or not value.heads[head] in value.eyes:
			return false
	if not _art_path(value.look_back.get("path")) or not _art_path(value.look_back.get("fallback")):
		return false
	var catalogs := StitchedWalkRules.load_catalogs()
	if catalogs.is_empty():
		return false
	for corridor in catalogs.corridors:
		var steps: Variant = value.corridors.get(corridor.id)
		if not steps is Array or steps.size() != int(corridor.steps) + 1:
			return false
		for step in steps:
			if not step is Array or step.size() != 3:
				return false
			for path in step:
				if not _art_path(path):
					return false
	return true


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	reduced_motion = bool(ProjectSettings.get_setting("patchwork/reduced_motion", false))
	CHROME.action_tray(self, Rect2(16, 16, 1248, 688))
	for index in 3:
		layers.append(_picture(self, "Depth" + str(index), VIEW))
	for index in 4:
		trailing.append(_picture(self, "TrailingRank" + str(index + 1), Rect2(90 + index * 206, 240, 150, 240)))
		trailing[index].stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rank_labels.append(_label(Rect2(70 + index * 206, 484, 190, 42), ""))
	eye_overlay = _picture(self, "EyeTreatment", VIEW)
	readout = _label(Rect2(40, 26, 1190, 38), "")
	eye_readout = _label(Rect2(40, 64, 900, 32), "")
	forward_button = _button("FORWARD", Rect2(980, 106, 250, 48), func(): command("forward"))
	back_button = _button("LOOK BACK", Rect2(980, 166, 250, 48), func(): command("look_back"))
	for index in 4:
		switch_buttons.append(_button("", Rect2(36 + index * 308, 558, 294, 46), func():
			command("switch", {"target": expected.dolls[index].id})))
	_label(Rect2(980, 228, 250, 30), "POCKET TARGET")
	target_picker = OptionButton.new()
	target_picker.position = Vector2(980, 264)
	target_picker.size = Vector2(250, 42)
	CHROME.style_button(target_picker)
	add_child(target_picker)
	for index in 2:
		pocket_buttons.append(_button("", Rect2(980, 320 + index * 54, 250, 46), func():
			command("use_item", {"slot": index, "target": target_picker.get_item_metadata(target_picker.selected)})))
	var motion := CheckButton.new()
	motion.text = "Reduced motion"
	motion.position = Vector2(980, 438)
	motion.size = Vector2(250, 40)
	CHROME.style_button(motion)
	motion.button_pressed = reduced_motion
	motion.toggled.connect(set_reduced_motion)
	add_child(motion)
	exit_button = _button("BACK TO TITLE", Rect2(980, 492, 250, 44), func(): exit_requested.emit())
	feedback = _label(Rect2(40, 622, 1190, 60), "Walk preview. Choose a doll to borrow its eyes and pocket.")
	if walk != null:
		refresh()
		forward_button.grab_focus()


func _picture(parent: Control, title: String, rectangle: Rect2) -> TextureRect:
	var picture := TextureRect.new()
	picture.name = title
	picture.position = rectangle.position
	picture.size = rectangle.size
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(picture)
	return picture


func _label(rectangle: Rect2, caption: String) -> Label:
	var label := Label.new()
	label.position = rectangle.position
	label.size = rectangle.size
	label.text = caption
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", CHROME.BONE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _button(caption: String, rectangle: Rect2, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.position = rectangle.position
	button.size = rectangle.size
	button.add_theme_font_size_override("font_size", 23)
	CHROME.style_button(button)
	button.pressed.connect(action)
	add_child(button)
	return button


static func texture_or_fallback(path: String, fallback: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var resource := load(path)
		if resource is Texture2D:
			return resource
	return load(fallback) as Texture2D if ResourceLoader.exists(fallback) else null


func command(kind: String, extra: Dictionary = {}, snapshot: Variant = null) -> Dictionary:
	if walk == null:
		return {"ok": false, "error": "not_started"}
	var request := {"kind": kind, "actor": expected.viewpoint}
	request.merge(extra, true)
	var receipt := walk.act(request, expected if snapshot == null else snapshot)
	receipts.append(receipt.duplicate(true))
	expected = receipt.snapshot.duplicate(true)
	if is_node_ready():
		refresh()
		feedback.text = (kind.replace("_", " ").to_upper() + "  |  " + str(receipt.events)) if receipt.ok else receipt.error
		if receipt.ok and expected.phase == "complete":
			feedback.text = "Walk complete. Back to title."
		if receipt.ok and kind == "forward" and not reduced_motion:
			travel = create_tween().set_parallel(true)
			for index in layers.size():
				layers[index].position -= Vector2(0, 8 * (index + 1))
				layers[index].scale = Vector2.ONE * (1.02 + index * 0.01)
				travel.tween_property(layers[index], "position", VIEW.position, 0.28)
				travel.tween_property(layers[index], "scale", Vector2.ONE, 0.28)
	return receipt


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	if value:
		_stop_travel()


func _stop_travel() -> void:
	if travel != null:
		travel.kill()
		travel = null
	for layer in layers:
		layer.position = VIEW.position
		layer.scale = Vector2.ONE


func refresh() -> void:
	_stop_travel()
	var band := StitchedS1BEffects.candle_band(clampi(candle, 0, 100))
	var depth: int = {"bright": 4, "dim": 3, "gloom": 2, "dark": 1, "snuffed": 0}[band.name]
	var paths: Array = art.corridors[expected.corridor.id][expected.step]
	for index in layers.size():
		layers[index].texture = texture_or_fallback(paths[index], art.fallbacks[index])
		layers[index].self_modulate = Color(1, 1, 1, [1.0, 0.22, 0.65][index])
		layers[index].modulate = Color.WHITE * (0.35 + depth * 0.16)
		layers[index].modulate.a = 1
	if expected.looking_back:
		layers[0].texture = texture_or_fallback(art.look_back.path, art.look_back.fallback)
	var viewpoint: Dictionary = {}
	var selected_target: Variant = target_picker.get_item_metadata(target_picker.selected) if target_picker.selected >= 0 else ""
	target_picker.clear()
	for index in expected.dolls.size():
		var doll: Dictionary = expected.dolls[index]
		if doll.id == expected.viewpoint:
			viewpoint = doll
		target_picker.add_item("Rank %d - %s" % [doll.rank, doll.name])
		target_picker.set_item_metadata(index, doll.id)
		if doll.id == selected_target:
			target_picker.select(index)
		trailing[index].texture = texture_or_fallback("res://assets/paper/heroes/" + doll.id + ".png", "res://assets/paper/heroes/seamstress.png")
		trailing[index].visible = expected.looking_back and doll.id != expected.viewpoint and not doll.lost
		trailing[index].modulate.a = 1.0 if doll.rank <= depth else 0.12
		rank_labels[index].text = "Rank %d - %s" % [doll.rank, doll.name]
		rank_labels[index].visible = trailing[index].visible
		switch_buttons[index].text = "R%d  %s  %d/%d" % [doll.rank, doll.name, doll.hp, doll.max_hp]
		switch_buttons[index].disabled = doll.lost or doll.id == expected.viewpoint or expected.phase != "walking"
	# Anonymous instance targeting exposes no kind, contents, trap or mimic knowledge.
	for curio in expected.curios:
		if curio.step == expected.step:
			var index := target_picker.item_count
			target_picker.add_item("Object on this step")
			target_picker.set_item_metadata(index, curio.instance)
	var head: Variant = viewpoint.parts.get("head", "")
	var head_id: String = str(head.get("id", "")) if head is Dictionary else str(head)
	eye_profile = art.heads.get(head_id, "neutral")
	var eye: Dictionary = art.eyes[eye_profile]
	eye_overlay.texture = texture_or_fallback(eye.path, eye.fallback)
	eye_overlay.visible = eye_profile != "neutral"
	eye_overlay.position = VIEW.position
	eye_overlay.size = Vector2(VIEW.size.x * 0.5, VIEW.size.y) if eye_profile == "one_eye" else Vector2(VIEW.size.x, 24)
	if ResourceLoader.exists(eye.path):
		eye_overlay.size = VIEW.size
	eye_overlay.modulate = {"neutral": Color.WHITE, "cracked": Color("b87f69b0"), "glass": Color("90cfdf90"), "one_eye": Color("111018fa"), "ears": Color("dbc19e90")}[eye_profile]
	eye_readout.text = "%s's eyes  /  %s  /  %s" % [viewpoint.name, eye_profile.replace("_", " "), "LOOKING BACK" if expected.looking_back else "FRONT"]
	readout.text = "%s   |   Step %d/%d   |   Candle %d - %s   |   WHIRR %d/100" % [expected.corridor.name, expected.step, expected.corridor.steps, candle, band.name, expected.whirr]
	var pocket: Array = expected.pockets[expected.viewpoint]
	for index in pocket_buttons.size():
		pocket_buttons[index].text = str(pocket[index]).replace("_", " ").capitalize() if index < pocket.size() else "Empty pocket"
		pocket_buttons[index].disabled = index >= pocket.size() or expected.phase != "walking"
	forward_button.disabled = expected.phase != "walking"
	back_button.disabled = expected.phase != "walking"
	if expected.phase == "complete":
		feedback.text = "Walk complete. Back to title."
