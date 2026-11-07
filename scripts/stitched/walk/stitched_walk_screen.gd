class_name StitchedWalkScreen
extends Control
## S10 Walk: a 3D doll's-eye corridor (StitchedCorridorStage) with a few big controls over it.
## Only StitchedWalkRules owns walk state and receipts; this screen just shows and asks.

signal exit_requested
## Hosted by a run: the Walk is over and the session has opened its node.
signal walk_finished

const ART_PATH := "res://data/walk/walk_view_art.json"
const CURIO_PATH := "res://data/walk/curios.json"
const CHROME := preload("res://scripts/stitched/stitched_battle_chrome.gd")
const PREVIEW_SEED := 548
## The whole screen is the corridor now.
const VIEW := Rect2(0, 0, 1280, 720)
## S9c: at fear 50+ the borrowed sight flickers; a fixed brightness beat, never the run's RNG.
const FLICKER_BEAT := 0.11
const FLICKER := [1.0, 1.0, 0.55, 1.0, 1.0, 1.0, 0.38, 0.8, 1.0, 1.0, 1.0, 0.62]
const BAND_DEPTH := {"bright": 4, "dim": 3, "gloom": 2, "dark": 1, "snuffed": 0}
## In-corridor event text: what the borrowed eyes see, and what each choice is called.
const CURIO_LINES := {
	"pincushion": "A pincushion as tall as a doll, bristling. Under the pins, something breathes.",
	"dummy": "A tailor's dummy blocks the way, wearing parts that are not its own.",
	"ragbag": "A ragbag slumps against the wall. Its mouth hangs open. It is warm.",
	"patterns": "Paper patterns are pinned along the wall, marked in a hand you almost know.",
	"door": "A little door, stitched shut from this side. Thread hums when you touch it.",
}
const CHOICE_CAPTIONS := {
	"leave": "LEAVE IT", "pull": "PULL A PIN", "take": "TAKE A PART", "inspect": "LOOK CLOSER",
	"reach": "REACH INSIDE", "read": "READ THEM", "unpick": "UNPICK IT",
}
const HEAL_ITEMS := ["thimble_tonic", "fresh_stuffing"]
var walk: StitchedWalkRules
var expected: Dictionary = {}
var receipts: Array = []
var art: Dictionary = {}
var curio_records: Dictionary = {}
var candle := 78
var reduced_motion := false
var eye_profile := "neutral"
var stage: StitchedCorridorStage
var switch_buttons: Array[Button] = []
var pocket_buttons: Array[Button] = []
var forward_button: Button
var back_button: Button
var exit_button: Button
var readout: Label
var eye_readout: Label
var feedback: Label
var clue: Label
var eye_overlay: TextureRect
var travel: Tween
## In-corridor event: the curio on this step, or the tug at the rear.
var event_panel: Control
var event_title: Label
var event_text: Label
var event_buttons: Array[Button] = []
## id -> Label / Button placed under each figure seen when looking back.
var figure_labels: Dictionary = {}
var snip_buttons: Dictionary = {}
## S8f: in a run every command goes through the session, which journals and saves it.
var host: StitchedRunSession
## S9c: Wren's fear; a run reads its session, a preview its own value.
var fear_source: Callable
var preview_fear := 0
var flickering := false
var _flicker_time := 0.0
var _built_for := ""


func attach(run: StitchedRunSession) -> bool:
	if walk != null or run == null or run.phase != "walk" or run.walk == null:
		return false
	if not _load_art():
		return false
	host = run
	walk = run.walk
	candle = run.candle
	fear_source = run.kid_fear
	expected = walk.snapshot()
	return true


func begin(seed_number: int = PREVIEW_SEED) -> bool:
	if walk != null:
		return false
	if not _load_art():
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
	expected = walk.snapshot()
	return true


func _load_art() -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ART_PATH))
	if not parsed is Dictionary or not validate_art(parsed):
		return false
	art = parsed
	var curios: Variant = JSON.parse_string(FileAccess.get_file_as_string(CURIO_PATH))
	if curios is Dictionary:
		for record in curios.get("curios", []):
			curio_records[record.id] = record
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
	stage = StitchedCorridorStage.new()
	add_child(stage)
	eye_overlay = TextureRect.new()
	eye_overlay.name = "EyeTreatment"
	eye_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	eye_overlay.stretch_mode = TextureRect.STRETCH_SCALE
	eye_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(eye_overlay)
	# Owner 11-07: look simple, deep inside. The numbers stay in the rules (and this hidden
	# readout for tests and tools); the player reads them as light, fog and flicker.
	readout = _label(Rect2(28, 16, 800, 30), "", 19)
	readout.visible = false
	eye_readout = _label(Rect2(28, 18, 800, 30), "", 19)
	clue = _label(Rect2(240, 96, 800, 40), "", 22)
	clue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback = _label(Rect2(240, 560, 800, 40), "Borrow a doll's eyes, then walk on.", 20)
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	forward_button = _button("WALK ON", Rect2(500, 610, 280, 66), 30, func(): command("forward"))
	back_button = _button("LOOK BACK", Rect2(796, 620, 190, 48), 21, func(): command("look_back"))
	for index in 4:
		switch_buttons.append(_button("", Rect2(24, 474 + index * 54, 250, 46), 18, func():
			command("switch", {"target": expected.dolls[index].id})))
	for index in 2:
		pocket_buttons.append(_button("", Rect2(1010, 582 + index * 56, 246, 48), 19, func(): _use_pocket(index)))
	exit_button = _button("TITLE", Rect2(1110, 18, 150, 44), 19, func(): exit_requested.emit())
	_build_event_panel()
	if walk != null:
		refresh()
		forward_button.grab_focus()


func _build_event_panel() -> void:
	event_panel = Control.new()
	event_panel.name = "CorridorEvent"
	event_panel.position = Vector2(330, 360)
	event_panel.size = Vector2(620, 190)
	event_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(event_panel)
	CHROME.action_tray(event_panel, Rect2(Vector2.ZERO, event_panel.size))
	event_title = Label.new()
	event_title.position = Vector2(20, 12)
	event_title.size = Vector2(580, 32)
	event_title.add_theme_font_size_override("font_size", 24)
	event_title.add_theme_color_override("font_color", CHROME.AMBER)
	event_panel.add_child(event_title)
	event_text = Label.new()
	event_text.position = Vector2(20, 46)
	event_text.size = Vector2(580, 70)
	event_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_text.add_theme_font_size_override("font_size", 19)
	event_text.add_theme_color_override("font_color", CHROME.BONE)
	event_panel.add_child(event_text)
	event_panel.hide()


func _label(rectangle: Rect2, caption: String, font_size: int) -> Label:
	var label := Label.new()
	label.position = rectangle.position
	label.size = rectangle.size
	label.text = caption
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", CHROME.BONE)
	label.add_theme_color_override("font_outline_color", Color("140c0e"))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _button(caption: String, rectangle: Rect2, font_size: int, action: Callable, parent: Control = self) -> Button:
	var button := Button.new()
	button.text = caption
	button.position = rectangle.position
	button.size = rectangle.size
	button.add_theme_font_size_override("font_size", font_size)
	CHROME.style_button(button)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


static func texture_or_fallback(path: String, fallback: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var resource := load(path)
		if resource is Texture2D:
			return resource
	return load(fallback) as Texture2D if ResourceLoader.exists(fallback) else null


## The open curio on this step, or {} when there is none to face.
func current_curio() -> Dictionary:
	if expected.is_empty() or expected.get("phase") != "walking":
		return {}
	for curio in expected.curios:
		if curio.step == expected.step and not curio.get("resolved", false):
			return curio
	return {}


## Pockets pick their own target: menders go to the most-hurt doll, pins to the open curio,
## anything else to the doll whose eyes we hold.
func pocket_target(item: String) -> String:
	if item == "pins":
		return str(current_curio().get("instance", expected.viewpoint))
	if item in HEAL_ITEMS:
		var best := {}
		for doll in expected.dolls:
			if not doll.lost and (best.is_empty() or doll.max_hp - doll.hp > best.max_hp - best.hp):
				best = doll
		return str(best.get("id", expected.viewpoint))
	return str(expected.viewpoint)


func _use_pocket(slot: int) -> void:
	var pocket: Array = expected.pockets[expected.viewpoint]
	if slot < pocket.size():
		command("use_item", {"slot": slot, "target": pocket_target(str(pocket[slot]))})


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
		var animate: bool = receipt.ok and not reduced_motion
		refresh(animate)
		feedback.text = describe(kind, request, receipt, expected.dolls)
		if receipt.ok and expected.phase == "complete":
			feedback.text = "The corridor ends here."
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
	_update_flicker()


func fear() -> int:
	return clampi(int(fear_source.call()) if fear_source.is_valid() else preview_fear, 0, 100)


## The walk is Wren's borrowed sight: at fear 50+ the candle gutters, unless motion is reduced.
func _update_flicker() -> void:
	flickering = fear() >= StitchedKidFear.SHAKE_THRESHOLD
	set_process(flickering and not reduced_motion)
	if not is_processing():
		_flicker_time = 0.0
		stage.set_dim(1.0)


func _process(delta: float) -> void:
	_flicker_time += delta
	stage.set_dim(FLICKER[int(_flicker_time / FLICKER_BEAT) % FLICKER.size()])
	_place_figure_controls()


func _stop_travel() -> void:
	stage.stop()
	travel = null


func refresh(animate: bool = false) -> void:
	_stop_travel()
	var band := StitchedS1BEffects.candle_band(clampi(candle, 0, 100))
	var depth: int = BAND_DEPTH[band.name]
	if _built_for != expected.corridor.id:
		_built_for = expected.corridor.id
		stage.build(expected.area, int(expected.corridor.steps))
	stage.set_candle(band.name)
	var moved: bool = expected.step != stage.step
	travel = stage.go_to(expected.step, animate and moved)
	if expected.looking_back != stage.looking_back:
		var turning := stage.turn(expected.looking_back, animate and not moved)
		if turning != null:
			travel = turning
	var viewpoint: Dictionary = {}
	for doll in expected.dolls:
		if doll.id == expected.viewpoint:
			viewpoint = doll
	_stand_figures(depth)
	for index in expected.dolls.size():
		var doll: Dictionary = expected.dolls[index]
		switch_buttons[index].text = "%s  %d/%d" % [doll.name, doll.hp, doll.max_hp]
		switch_buttons[index].disabled = doll.lost or doll.id == expected.viewpoint or expected.phase != "walking"
		switch_buttons[index].tooltip_text = "Borrow %s's eyes (rank %d)" % [doll.name, doll.rank]
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
	eye_overlay.modulate = {"neutral": Color.WHITE, "cracked": Color("b87f6960"), "glass": Color("90cfdf60"), "one_eye": Color("111018fa"), "ears": Color("dbc19e60")}[eye_profile]
	eye_readout.text = "%s  -  through %s's eyes" % [expected.corridor.name, viewpoint.name]
	var shadow_visible := walk.shadow_visible()
	clue.visible = shadow_visible
	if shadow_visible:
		clue.text = StitchedWrenLines.mimic(eye_profile)
	readout.text = "%s   Step %d/%d   Candle %d %s   WHIRR %d/100   WREN FEAR %d/100" % [expected.corridor.name, expected.step, expected.corridor.steps, candle, band.name, expected.whirr, fear()]
	var pocket: Array = expected.pockets[expected.viewpoint]
	for index in pocket_buttons.size():
		pocket_buttons[index].text = str(pocket[index]).replace("_", " ").capitalize() if index < pocket.size() else "Empty pocket"
		pocket_buttons[index].disabled = index >= pocket.size() or expected.phase != "walking"
	forward_button.disabled = expected.phase != "walking"
	forward_button.text = "LET IT TAKE ONE" if walk.tug_unresolved() else "WALK ON"
	exit_button.visible = host == null
	back_button.disabled = expected.phase != "walking"
	_show_event()
	if expected.phase == "complete":
		feedback.text = "The corridor ends here."
	_update_flicker()
	_place_figure_controls()


## Who stands in the corridor right now: the curio ahead, the dolls trailing behind,
## the extra doll among them, the mannequins and the machine when they have come.
func _stand_figures(depth: int) -> void:
	stage.clear_figures()
	for label in figure_labels.values():
		label.queue_free()
	for button in snip_buttons.values():
		button.queue_free()
	figure_labels.clear()
	snip_buttons.clear()
	var curio := current_curio()
	if not curio.is_empty():
		var kind: String = curio_records.get(curio.id, {}).get("kind", "pincushion")
		stage.place("curio", StitchedCorridorStage.art("prop_" + kind), stage.ahead_point(), 1.6)
	if int(expected.whirr) >= 50:
		stage.place("machine", StitchedCorridorStage.art("horror_machine"),
			stage.ahead_point(float(expected.corridor.steps - expected.step) * StitchedCorridorStage.SEGMENT + 1.5), 2.4)
	var slot := 0
	var shadow_visible := walk.shadow_visible()
	var snips: Array = walk.snip_targets()
	for doll in expected.dolls:
		if doll.lost:
			continue
		if doll.id == expected.viewpoint:
			# The borrowed eyes cannot see their own body; the extra doll stands in that gap.
			if shadow_visible:
				var shadow: Dictionary = expected.shadow
				var picture := texture_or_fallback(str(shadow.art_path), StitchedCorridorStage.HERO_DIR + str(shadow.disguise) + ".png")
				stage.place(shadow.id, picture, stage.trail_point(slot), StitchedCorridorStage.DOLL_HEIGHT)
				_figure_controls(shadow.id, _disguise_caption(shadow), snips)
			slot += 1
			continue
		var figure := stage.place(doll.id, StitchedCorridorStage.hero_art(doll.id), stage.trail_point(slot), StitchedCorridorStage.DOLL_HEIGHT)
		figure.modulate.a = 1.0 if doll.rank <= depth else 0.12
		_figure_controls(doll.id, "%s" % doll.name, snips)
		slot += 1
	if walk.mannequins_visible():
		var stage_number := int(expected.mannequins.get("stage", 0))
		stage.place("mannequins", StitchedCorridorStage.art("horror_mannequins"),
			stage.trail_point(3) + Vector3(0, 0, 4.5 - stage_number * 1.2), 1.9)


func _disguise_caption(shadow: Dictionary) -> String:
	for doll in expected.dolls:
		if doll.id == shadow.disguise:
			return "%s\nLoose seam" % doll.name
	return "Loose seam"


func _figure_controls(id: String, caption: String, snips: Array) -> void:
	if not expected.looking_back:
		return
	var label := _label(Rect2(0, 0, 180, 52), caption, 18)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	figure_labels[id] = label
	if id in snips:
		var target := id
		snip_buttons[id] = _button("SNIP", Rect2(0, 0, 110, 40), 19, func(): command("snip", {"target": target}))


## Name plates and SNIP buttons follow the figures on screen as the eye moves.
func _place_figure_controls() -> void:
	for id in figure_labels:
		var point: Variant = stage.screen_point(id)
		var at: Vector2 = point if point is Vector2 else Vector2(640, 420)
		at = at.clamp(Vector2(100, 120), Vector2(1180, 520))
		figure_labels[id].position = at + Vector2(-90, 4)
		if snip_buttons.has(id):
			snip_buttons[id].position = at + Vector2(-55, 56)


## The in-corridor event: a curio on this step, or the tug holding the rear doll.
func _show_event() -> void:
	for button in event_buttons:
		button.queue_free()
	event_buttons.clear()
	event_panel.hide()
	if expected.phase != "walking" or expected.looking_back:
		return
	var choices: Array = []
	if walk.tug_unresolved():
		event_title.text = "SOMETHING HAS THE THREAD"
		event_text.text = "A thread pulls tight from the dark behind the last doll. It wants a part, or something sharp."
		var pocket: Array = expected.pockets[expected.viewpoint]
		for item in ["pins", "spare_spool"]:
			var slot := pocket.find(item)
			if slot >= 0:
				choices.append(["GIVE IT " + item.replace("_", " ").to_upper(), {"kind": "tug", "target": expected.tug.id, "choice": item, "slot": slot}])
	else:
		var curio := current_curio()
		if curio.is_empty():
			return
		var record: Dictionary = curio_records.get(curio.id, {})
		event_title.text = str(record.get("name", "Something in the way")).to_upper()
		event_text.text = CURIO_LINES.get(record.get("kind", ""), "Something waits in the candlelight.")
		for choice in walk.curio_choices(curio.instance):
			choices.append([CHOICE_CAPTIONS.get(choice, str(choice).to_upper()), {"kind": "curio", "target": curio.instance, "choice": choice}])
	event_panel.show()
	for index in choices.size():
		var request: Dictionary = choices[index][1]
		var width := (580.0 - 12.0 * (choices.size() - 1)) / choices.size()
		var button := _button(choices[index][0], Rect2(20 + index * (width + 12), 118, width, 44), 19,
			func(): command(request.kind, request), event_panel)
		event_buttons.append(button)
