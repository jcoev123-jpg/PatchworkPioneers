class_name StitchedWalkScreen
extends Control
## Isolated S8b presentation. Only StitchedWalkRules owns walk state and receipts.

signal exit_requested
## Hosted by a run: the Walk is over and the session has opened its node.
signal walk_finished

const ART_PATH := "res://data/walk/walk_view_art.json"
const CHROME := preload("res://scripts/stitched/stitched_battle_chrome.gd")
const PREVIEW_SEED := 548
const VIEW := Rect2(32, 100, 920, 440)
## S9c: at fear 50+ the borrowed sight flickers; a fixed brightness beat, never the run's RNG.
const FLICKER_BEAT := 0.11
const FLICKER := [1.0, 1.0, 0.55, 1.0, 1.0, 1.0, 0.38, 0.8, 1.0, 1.0, 1.0, 0.62]
var walk: StitchedWalkRules
var expected: Dictionary = {}
var receipts: Array = []
var art: Dictionary = {}
var candle := 78
var reduced_motion := false
var eye_profile := "neutral"
## The corridor's own far picture, dimmed behind the whole screen (no bare clear colour).
var backdrop: TextureRect
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
var whirr_readout: Label
var candle_readout: Label
var fear_readout: Label
var whirr_warning: Label
var fear_warning: Label
var whirr_meter: ProgressBar
var candle_meter: ProgressBar
var fear_meter: ProgressBar
var hud_panels: Array[NinePatchRect] = []
var feedback: Label
var eye_overlay: TextureRect
var travel: Tween
var shadow_picture: TextureRect
var shadow_label: Label
var clue: Label
var snip_picker: OptionButton
var snip_button: Button
## S8f: in a run every command goes through the session, which journals and saves it.
var host: StitchedRunSession
## S9c: Wren's fear; a run reads its session, a preview its own value.
var fear_source: Callable
var preview_fear := 0
var flickering := false
var _flicker_time := 0.0
var _layer_tone := Color.WHITE


func attach(run: StitchedRunSession) -> bool:
	if walk != null or run == null or run.phase != "walk" or run.walk == null:
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ART_PATH))
	if not parsed is Dictionary or not validate_art(parsed):
		return false
	host = run
	walk = run.walk
	art = parsed
	candle = run.candle
	fear_source = run.kid_fear
	expected = walk.snapshot()
	return true


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
	walk = StitchedWalkRules.start(random, "walls", dolls, pockets, null, true)
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
	set_process(false)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	reduced_motion = bool(ProjectSettings.get_setting("patchwork/reduced_motion", false))
	backdrop = _picture(self, "WalkBackdrop", Rect2(Vector2.ZERO, Vector2(1280, 720)))
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.modulate = Color(0.32, 0.28, 0.3)
	CHROME.action_tray(self, Rect2(16, 16, 1248, 688))
	for index in 3:
		layers.append(_picture(self, "Depth" + str(index), VIEW))
	for index in 4:
		trailing.append(_picture(self, "TrailingRank" + str(index + 1), Rect2(90 + index * 206, 240, 150, 240)))
		trailing[index].stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rank_labels.append(_label(Rect2(70 + index * 206, 484, 190, 42), ""))
	shadow_picture = _picture(self, "ExtraThreadShadow", Rect2(90, 240, 150, 240))
	shadow_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shadow_label = _label(Rect2(70, 484, 220, 64), "")
	eye_overlay = _picture(self, "EyeTreatment", VIEW)
	clue = _label(Rect2(40, 202, 900, 36), "")
	# Three sewn, image-backed status strips fit wholly in the top border.
	# Leave the 920x440 eye picture and the command column untouched.
	hud_panels.append(_hud_panel("CorridorPlate", Rect2(36, 20, 486, 76)))
	hud_panels.append(_hud_panel("WhirrPlate", Rect2(528, 20, 227, 76)))
	hud_panels.append(_hud_panel("CandlePlate", Rect2(763, 20, 227, 76)))
	hud_panels.append(_hud_panel("FearPlate", Rect2(998, 20, 246, 76)))
	readout = _label(Rect2(48, 27, 466, 29), "")
	eye_readout = _label(Rect2(48, 60, 466, 26), "")
	for caption in [readout, eye_readout]:
		caption.clip_text = true
		caption.mouse_filter = Control.MOUSE_FILTER_STOP
	readout.add_theme_font_size_override("font_size", 23)
	eye_readout.add_theme_font_size_override("font_size", 20)
	whirr_readout = _hud_caption(Rect2(540, 26, 207, 24))
	candle_readout = _hud_caption(Rect2(775, 26, 207, 24))
	fear_readout = _hud_caption(Rect2(1010, 26, 224, 24))
	whirr_meter = CHROME._meter(self, "WalkWhirrMeter", Rect2(541, 54, 204, 10), Color("c68f6c"))
	candle_meter = CHROME._meter(self, "WalkCandleMeter", Rect2(776, 54, 204, 10), CHROME.AMBER)
	fear_meter = CHROME._meter(self, "WalkFearMeter", Rect2(1011, 54, 220, 10), Color("af6268"))
	whirr_warning = _hud_caption(Rect2(540, 71, 442, 23))
	fear_warning = _hud_caption(Rect2(1010, 71, 226, 23))
	whirr_warning.add_theme_font_size_override("font_size", 18)
	fear_warning.add_theme_font_size_override("font_size", 18)
	whirr_warning.add_theme_color_override("font_color", CHROME.AMBER)
	fear_warning.add_theme_color_override("font_color", Color("ffb1a0"))
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
	target_picker.item_selected.connect(func(_index: int): _refresh_pocket_actions())
	for index in 2:
		pocket_buttons.append(_button("", Rect2(980, 320 + index * 54, 250, 46), func():
			command("use_item", {"slot": index, "target": target_picker.get_item_metadata(target_picker.selected)})))
	var motion := CheckButton.new()
	motion.name = "ReducedMotionToggle"
	motion.text = "Reduced motion"
	motion.position = Vector2(980, 438)
	motion.size = Vector2(250, 40)
	CHROME.style_button(motion)
	motion.button_pressed = reduced_motion
	motion.toggled.connect(set_reduced_motion)
	add_child(motion)
	exit_button = _button("BACK TO TITLE", Rect2(980, 492, 250, 44), func(): exit_requested.emit())
	snip_picker = OptionButton.new()
	snip_picker.position = Vector2(650, 610)
	snip_picker.size = Vector2(300, 42)
	CHROME.style_button(snip_picker)
	add_child(snip_picker)
	snip_button = _button("SNIP THREAD", Rect2(980, 610, 250, 42), func():
		if snip_picker.selected >= 0:
			command("snip", {"target": snip_picker.get_item_metadata(snip_picker.selected)}))
	feedback = _label(Rect2(40, 660, 1190, 40), "Walk preview. Choose a doll to borrow its eyes and pocket.")
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


func _hud_panel(title: String, rectangle: Rect2) -> NinePatchRect:
	var panel := NinePatchRect.new()
	panel.name = title
	panel.texture = CHROME.FELT
	panel.position = rectangle.position
	panel.size = rectangle.size
	panel.patch_margin_left = 14
	panel.patch_margin_right = 14
	panel.patch_margin_top = 12
	panel.patch_margin_bottom = 12
	panel.self_modulate = Color("715356ed")
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.focus_mode = Control.FOCUS_ALL
	add_child(panel)
	return panel


func _hud_caption(rectangle: Rect2) -> Label:
	var caption := _label(rectangle, "")
	caption.add_theme_font_size_override("font_size", 20)
	caption.clip_text = true
	caption.mouse_filter = Control.MOUSE_FILTER_STOP
	return caption


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
	if kind == "forward" and walk.tug_unresolved():
		request = {"kind": "tug", "actor": expected.viewpoint, "target": expected.tug.id, "choice": "yield"}
	request.merge(extra, true)
	var receipt := host.walk_act(request, host.snapshot()) if host != null \
		else walk.act(request, expected if snapshot == null else snapshot)
	receipts.append(receipt.duplicate(true))
	if host != null and host.walk == null:
		walk_finished.emit()
		return receipt
	expected = walk.snapshot() if host != null else receipt.snapshot.duplicate(true)
	if is_node_ready():
		refresh()
		feedback.text = describe(kind, request, receipt, expected.dolls)
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


## Player-facing line for one receipt; never shows ids or raw event data.
static func describe(kind: String, request: Dictionary, receipt: Dictionary, dolls: Array) -> String:
	if not receipt.get("ok", false):
		return "That cannot be done: %s." % str(receipt.get("error", "blocked")).replace("_", " ")
	var names := {}
	for doll in dolls:
		names[doll.id] = doll.name
	var lines: Array[String] = []
	for event in receipt.get("events", []):
		var who: String = names.get(event.get("target", event.get("actor", "")), "a doll")
		match str(event.get("kind", "")):
			"tug_torn":
				lines.append("Something tugs from the dark: %s's %s tears." % [who, str(event.get("slot", "seam"))])
			"tug_saved":
				lines.append("%s gives up the %s and the tug lets go." % [who, str(event.get("item", "item")).replace("_", " ")])
			"tug_no_part":
				lines.append("Something tugs at the last doll but finds nothing left to tear.")
			"mimic_removed":
				lines.append("The snip finds the false thread. The extra doll falls away.")
			"wrong_snip":
				lines.append("Wrong thread! %s frays (+%d)." % [who, int(event.get("fray", 0))])
			"mimic_pending":
				lines.append("A fifth doll follows you into the next room.")
			"mannequins_stage":
				lines.append("The mannequins have moved closer.")
			"mannequins_pending":
				lines.append("The mannequins wait at the next stop.")
			"shadow_revealed":
				lines.append("Looking back, there is one doll too many.")
			"heal":
				lines.append("%s is mended (+%d)." % [who, int(event.get("amount", 0))])
			"whirr_warning":
				lines.append("A sewing machine whirrs somewhere ahead.")
			"machine_pending":
				lines.append("The sewing machine waits at the next stop.")
			"dummy_inspected":
				lines.append("You study the tailor's dummy.")
			"curio_choice":
				lines.append("You chose to %s." % str(event.get("choice", "look")).replace("_", " "))
	if lines.is_empty():
		match kind:
			"forward":
				lines.append("You creep forward.")
			"look_back":
				lines.append("You look back the way you came.")
			"switch":
				lines.append("You borrow %s's eyes." % names.get(request.get("target", ""), "another doll"))
			"use_item":
				lines.append("Used.")
			_:
				lines.append("Done.")
	return " ".join(lines)


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	if value:
		_stop_travel()
	if is_node_ready() and not expected.is_empty():
		_refresh_status(StitchedS1BEffects.candle_band(clampi(candle, 0, 100)))
	_update_flicker()


func fear() -> int:
	return clampi(int(fear_source.call()) if fear_source.is_valid() else preview_fear, 0, 100)


## The walk is Wren's borrowed sight: at fear 50+ it flickers, unless motion is reduced.
func _update_flicker() -> void:
	flickering = fear() >= StitchedKidFear.SHAKE_THRESHOLD
	set_process(flickering and not reduced_motion)
	if not is_processing():
		_flicker_time = 0.0
		for layer in layers:
			layer.modulate = _layer_tone


func _process(delta: float) -> void:
	_flicker_time += delta
	var dim: float = FLICKER[int(_flicker_time / FLICKER_BEAT) % FLICKER.size()]
	for layer in layers:
		layer.modulate = Color(_layer_tone.r * dim, _layer_tone.g * dim, _layer_tone.b * dim, 1)


func _stop_travel() -> void:
	if travel != null:
		travel.kill()
		travel = null
	for layer in layers:
		layer.position = VIEW.position
		layer.scale = Vector2.ONE


## All status is projected from the detached Walk snapshot and the session's live
## candle/fear. This routine deliberately never calls WalkRules.act or RNG.
func _refresh_status(band: Dictionary) -> void:
	var current_whirr := clampi(int(expected.whirr), 0, 100)
	var current_candle := clampi(candle, 0, 100)
	var current_fear := fear()
	var warning := ""
	if current_whirr >= 100:
		warning = "NEXT FIGHT: +1 foe, +10 fray per doll"
	elif current_whirr >= 50:
		warning = "The Machine is stirring."
	whirr_readout.text = "WHIRR %d/100" % current_whirr
	candle_readout.text = "CANDLE %d / %s" % [current_candle, str(band.name).to_upper()]
	fear_readout.text = "WREN FEAR %d/100" % current_fear
	whirr_warning.text = warning
	fear_warning.text = ("Flicker suppressed" if reduced_motion else "Sight flickers at 50+") if current_fear >= StitchedKidFear.SHAKE_THRESHOLD else ""
	whirr_meter.value = current_whirr / 100.0
	candle_meter.value = current_candle / 100.0
	fear_meter.value = current_fear / 100.0
	var whirr_detail := "WHIRR %d/100. %s" % [current_whirr, warning if not warning.is_empty() else "The Machine is quiet."]
	var candle_detail := "Candle %d/100. %s light." % [current_candle, str(band.name).to_upper()]
	var fear_detail := "Wren fear %d/100. %s" % [current_fear, fear_warning.text if not fear_warning.text.is_empty() else "Sight is steady."]
	var corridor_detail := "%s, step %d of %d." % [expected.corridor.name, expected.step, expected.corridor.steps]
	readout.tooltip_text = corridor_detail
	eye_readout.tooltip_text = eye_readout.text
	hud_panels[0].tooltip_text = corridor_detail + " " + eye_readout.text
	for index in 3:
		var detail: String = [whirr_detail, candle_detail, fear_detail][index]
		hud_panels[index + 1].tooltip_text = detail
		[whirr_readout, candle_readout, fear_readout][index].tooltip_text = detail
		[whirr_meter, candle_meter, fear_meter][index].tooltip_text = detail
	whirr_warning.tooltip_text = whirr_detail
	fear_warning.tooltip_text = fear_detail


## The inspected pocket is the ONLY source for a fresh-stuffing +15 hint.
## Disabled/invalid targets expose no asserted cost and spend nothing.
func _refresh_pocket_actions() -> void:
	if expected.is_empty() or pocket_buttons.size() != 2:
		return
	var pocket: Array = expected.pockets[expected.viewpoint]
	var chosen: Variant = target_picker.get_item_metadata(target_picker.selected) if target_picker.selected >= 0 else ""
	var doll_target := false
	var curio_target := false
	for doll in expected.dolls:
		if doll.id == chosen and not doll.lost:
			doll_target = true
	for curio in expected.curios:
		if curio.instance == chosen and curio.step == expected.step and not curio.get("resolved", false):
			curio_target = true
	for index in pocket_buttons.size():
		var button := pocket_buttons[index]
		var has_item := index < pocket.size()
		button.text = str(pocket[index]).replace("_", " ").capitalize() if has_item else "Empty pocket"
		var item := str(pocket[index]) if has_item else ""
		var legal: bool = has_item and expected.phase == "walking" and (curio_target if item == "pins" else doll_target)
		button.disabled = not legal
		button.tooltip_text = ("WHIRR +15: fresh stuffing heals 35% HP (+5 use, +10 stuffing)."
			if item == "fresh_stuffing" else "WHIRR +5: use %s." % item.replace("_", " ")) if legal else ""
	target_picker.tooltip_text = ("Select a doll or an unidentified object. Curio interactions cost WHIRR +5."
		if curio_target else "Choose a legal doll or unidentified object for a pocket action.") if expected.phase == "walking" else ""


func refresh() -> void:
	_stop_travel()
	if host != null:
		candle = host.candle
	var band := StitchedS1BEffects.candle_band(clampi(candle, 0, 100))
	var depth: int = {"bright": 4, "dim": 3, "gloom": 2, "dark": 1, "snuffed": 0}[band.name]
	var paths: Array = art.corridors[expected.corridor.id][expected.step]
	for index in layers.size():
		layers[index].texture = texture_or_fallback(paths[index], art.fallbacks[index])
		layers[index].self_modulate = Color(1, 1, 1, [1.0, 0.22, 0.65][index])
		_layer_tone = Color.WHITE * (0.35 + depth * 0.16)
		_layer_tone.a = 1
		layers[index].modulate = _layer_tone
	backdrop.texture = layers[0].texture
	if expected.looking_back:
		layers[0].texture = texture_or_fallback(art.look_back.path, art.look_back.fallback) if walk.shadow_visible() \
			else texture_or_fallback(art.look_back.fallback, art.fallbacks[0])
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
	var shadow_visible := walk.shadow_visible()
	shadow_picture.visible = shadow_visible
	shadow_label.visible = shadow_visible
	clue.visible = shadow_visible
	snip_picker.clear()
	if shadow_visible:
		var shadow: Dictionary = expected.shadow
		for index in expected.dolls.size():
			var doll: Dictionary = expected.dolls[index]
			if doll.id == expected.viewpoint:
				shadow_picture.position = trailing[index].position
				shadow_label.position = rank_labels[index].position
			if doll.id == shadow.disguise:
				shadow_picture.texture = texture_or_fallback(shadow.art_path, "res://assets/paper/heroes/" + doll.id + ".png")
				shadow_label.text = "Rank %d - %s\nLoose seam" % [doll.rank, doll.name]
		clue.text = StitchedWrenLines.mimic(eye_profile)
		for target in walk.snip_targets():
			var caption := "Loose-seamed extra doll"
			for doll in expected.dolls:
				if doll.id == target:
					caption = "Rank %d - %s" % [doll.rank, doll.name]
			var index := snip_picker.item_count
			snip_picker.add_item(caption)
			snip_picker.set_item_metadata(index, target)
	snip_picker.visible = shadow_visible and snip_picker.item_count > 0
	snip_button.visible = snip_picker.visible
	snip_button.disabled = not snip_picker.visible
	readout.text = "%s  |  Step %d/%d" % [expected.corridor.name, expected.step, expected.corridor.steps]
	_refresh_status(band)
	_refresh_pocket_actions()
	forward_button.disabled = expected.phase != "walking"
	forward_button.text = "LET IT TAKE ONE" if walk.tug_unresolved() else "FORWARD"
	forward_button.tooltip_text = ("WHIRR +5: yield to the thread tug." if walk.tug_unresolved() else "WHIRR +0: advance one step.") if not forward_button.disabled else ""
	exit_button.visible = host == null
	back_button.disabled = expected.phase != "walking"
	back_button.tooltip_text = "WHIRR +5: look behind the lead doll." if not back_button.disabled else ""
	for button in switch_buttons:
		button.tooltip_text = "WHIRR +5: borrow this doll's eyes and pocket; ranks stay put." if not button.disabled else ""
	snip_button.tooltip_text = "WHIRR +5: snip the chosen thread." if not snip_button.disabled else ""
	if expected.phase == "complete":
		feedback.text = "Walk complete. Back to title."
	_update_flicker()
