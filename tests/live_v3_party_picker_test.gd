extends SceneTree
## Real mounted Design-v3 chooser: actions are requests, never run admission.
const SCENE := "res://scenes/v3_party_picker.tscn"
const ORDER: Array[String] = [
	"warden", "seamstress", "tinker", "lantern_monk",
	"rag_duelist", "scarecrow", "yarn_ranger", "button_golem"]
const NAMES: Array[String] = [
	"Warden", "Seamstress", "Tinker", "Lantern Monk",
	"Rag Duelist", "Scarecrow", "Yarn Ranger", "Button Golem"]
const MOTIFS: Array[String] = [
	"HELMET", "NEEDLE", "GOGGLES", "LANTERN",
	"RAPIER", "FORK", "HOOD", "BUTTONS"]

var failures: Array[String] = []
var checks := 0
var requests: Array = []
var cancels := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _frames() -> void:
	for i in range(4):
		await process_frame


func _tile(picker: Control, hero_id: String) -> Button:
	return picker.get_node_or_null("PaperPanel/Margins/Body/HeroGrid/Hero_" + hero_id) as Button


func _mouse(button: Button) -> void:
	_check(button != null and button.is_visible_in_tree(), "real visible mouse target")
	if button == null or not button.is_visible_in_tree():
		return
	var p := button.get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position = p
	root.push_input(move, true)
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = p
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		root.push_input(e, true)
	await _frames()


func _key(button: Button, code: Key) -> void:
	_check(button != null and button.focus_mode == Control.FOCUS_ALL,
		"keyboard target focusable")
	if button == null:
		return
	button.grab_focus()
	await _frames()
	_check(button.has_focus(), "keyboard target really owns focus")
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		root.push_input(e, true)
	await _frames()


func _on_party(ids: Array[String]) -> void:
	requests.append(ids)


func _on_cancel() -> void:
	cancels += 1


func _ids(picker: LiveV3PartyPicker, expected: Array[String], note: String, latched: bool = false) -> void:
	_check(picker.selected_ids() == expected, note + " ordered selected IDs")
	var count: Label = picker.get_node(
		"PaperPanel/Margins/Body/Foot/SelectionCount")
	_check(count.text == "Selected %d/3" % expected.size(),
		note + " visible selected counter")
	var button: Button = picker.get_node(
		"PaperPanel/Margins/Body/Foot/ContinueButton")
	_check(button.disabled == (expected.size() != 3 or latched), note + " Continue gate")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var packed := load(SCENE) as PackedScene
	_check(packed != null, "actual .tscn resource loads")
	if packed == null:
		_finish()
		return
	var picker := packed.instantiate() as LiveV3PartyPicker
	_check(picker != null, "actual .tscn has the chooser script")
	if picker == null:
		_finish()
		return
	root.add_child(picker)
	await _frames()
	_check(picker.is_node_ready() and picker.is_visible_in_tree(),
		"instanced, opened chooser is visible")
	_check(picker.size.x >= 1200 and picker.size.y >= 690,
		"1280x720 scene anchors fill the view")
	var panel: PanelContainer = picker.get_node("PaperPanel")
	var grid: GridContainer = picker.get_node(
		"PaperPanel/Margins/Body/HeroGrid")
	_check(grid.columns == 4 and grid.get_child_count() == 8,
		"four columns, exactly two rows and eight actual buttons")
	_check(picker.get_signal_connection_list("party_requested").is_empty(),
		"new view is detached from any run controller")
	picker.party_requested.connect(_on_party)
	picker.cancel_requested.connect(_on_cancel)
	var input_bounds := Rect2(Vector2.ZERO, Vector2(1280, 720))
	for i in range(8):
		var tile := _tile(picker, ORDER[i])
		_check(tile != null, "authored hero button exists: " + ORDER[i])
		if tile == null:
			continue
		_check(tile.focus_mode == Control.FOCUS_ALL and not tile.disabled,
			"enabled, focusable hero button " + ORDER[i])
		var name_label := tile.get_node_or_null(
			"Inset/Stack/NameLabel") as Label
		var motif_label := tile.get_node_or_null(
			"Inset/Stack/MotifLabel") as Label
		_check(name_label != null and name_label.text == NAMES[i],
			"named tile %s" % ORDER[i])
		_check(motif_label != null and
			motif_label.text.contains(MOTIFS[i]),
			"authentic visible sewn look motif " + ORDER[i])
		var face := tile.get_node_or_null("Inset/Stack/Face")
		var portrait := face.get_node_or_null("Portrait") if face != null else null
		var fallback := face.get_node_or_null("FallbackMotif") if face != null else null
		_check((portrait != null) != (fallback != null),
			"exactly texture or drawn fall-back for " + ORDER[i])
		if portrait != null:
			_check((portrait as TextureRect).texture != null,
				"real imported portrait texture: " + ORDER[i])
		if fallback != null:
			_check(fallback is Control and fallback.is_visible_in_tree()
				and fallback.size.x > 60 and fallback.size.y > 60,
				"measurable drawn silhouette fallback: " + ORDER[i])
		_check(input_bounds.encloses(tile.get_global_rect()),
			"visible hit target stays on 1280x720: " + ORDER[i])
		_check(panel.get_global_rect().encloses(tile.get_global_rect()),
			"each button inside the sewn panel: " + ORDER[i])
		_check(name_label == null or
			name_label.get_theme_font_size("font_size") >= 20,
			"readable tile name typography: " + ORDER[i])
		for j in range(i):
			var prior := _tile(picker, ORDER[j])
			if prior != null:
				_check(not prior.get_global_rect().intersects(tile.get_global_rect()),
					"distinct button footprints: " + ORDER[j] + " / " + ORDER[i])
	var action: Button = picker.get_node(
		"PaperPanel/Margins/Body/Foot/ContinueButton")
	var cancel: Button = picker.get_node(
		"PaperPanel/Margins/Body/Foot/CancelButton")
	_check(input_bounds.encloses(action.get_global_rect()) and
		input_bounds.encloses(cancel.get_global_rect()),
		"Continue and Cancel reachable in viewport")
	_check(not cancel.disabled and action.disabled, "fresh zero selection gate")
	_check(picker.selected_ids().is_empty(), "fresh selection is empty")
	var before_json := FileAccess.get_file_as_string("res://data/heroes/starter_party.json")
	_check(before_json.contains("warden") and before_json.contains("seamstress")
		and before_json.contains("tinker"), "real unmodified three-hero fixture")

	# Guard interaction against using the global RNG (no runtime random draw).
	seed(48109)
	var first := randi()
	var second := randi()
	seed(48109)
	_check(randi() == first, "global RNG oracle established")

	await _mouse(_tile(picker, "warden"))
	_ids(picker, ["warden"], "mouse first")
	await _key(_tile(picker, "seamstress"), KEY_SPACE)
	_ids(picker, ["warden", "seamstress"], "Space second")
	await _mouse(_tile(picker, "tinker"))
	_ids(picker, ["warden", "seamstress", "tinker"], "mouse third")
	await _mouse(_tile(picker, "lantern_monk"))
	_ids(picker, ["warden", "seamstress", "tinker"], "fourth blocked")
	await _key(_tile(picker, "seamstress"), KEY_ENTER)
	_ids(picker, ["warden", "tinker"], "Enter unpicks second")
	await _key(_tile(picker, "lantern_monk"), KEY_SPACE)
	_ids(picker, ["warden", "tinker", "lantern_monk"],
		"re-pick appends to order")
	var snapshot: Array[String] = picker.selected_ids()
	snapshot.clear()
	_ids(picker, ["warden", "tinker", "lantern_monk"],
		"returned accessor is detached")
	await _mouse(action)
	_check(requests.size() == 1 and
		requests[0] == ["warden", "tinker", "lantern_monk"],
		"Continue emits one deterministic three-ID request")
	_check(action.disabled and cancel.disabled
		and _tile(picker, "warden").disabled,
		"Continue latches all actions and retains submitted view")
	action.pressed.emit()
	cancel.pressed.emit()
	_tile(picker, "rag_duelist").pressed.emit()
	_check(requests.size() == 1 and cancels == 0,
		"duplicate, canceled and mutation presses ignored after Continue")
	_ids(picker, ["warden", "tinker", "lantern_monk"], "latched snapshot", true)

	# Reopening replaces the actual buttons; an old generation cannot inject.
	var stale := _tile(picker, "warden")
	picker.open_picker()
	stale.pressed.emit()
	_check(picker.selected_ids().is_empty(), "stale generation ignored")
	await _frames()
	_ids(picker, [], "reopened")
	_check(not cancel.disabled and picker.is_visible_in_tree(),
		"open_picker resets latch and visibility")
	await _mouse(_tile(picker, "scarecrow"))
	_ids(picker, ["scarecrow"], "fresh selection after reopen")
	await _key(cancel, KEY_ENTER)
	_check(cancels == 1 and requests.size() == 1,
		"Cancel emits only cancel_requested")
	_check(not picker.visible and cancel.disabled, "Cancel closes/latches view")
	cancel.pressed.emit()
	_tile(picker, "scarecrow").pressed.emit()
	_check(cancels == 1 and picker.selected_ids() == ["scarecrow"],
		"cancelled opening ignores stale actions")
	picker.open_picker()
	await _frames()
	_ids(picker, [], "reopen after cancel")
	await _key(_tile(picker, "button_golem"), KEY_ENTER)
	await _mouse(_tile(picker, "yarn_ranger"))
	await _mouse(_tile(picker, "rag_duelist"))
	_ids(picker, ["button_golem", "yarn_ranger", "rag_duelist"],
		"second ordered full party")
	await _key(action, KEY_SPACE)
	_check(requests.size() == 2 and
		requests[1] == ["button_golem", "yarn_ranger", "rag_duelist"],
		"new opening emits fresh three IDs via Space Continue")
	(requests[1] as Array)[0] = "forged"
	_check(picker.selected_ids() == ["button_golem", "yarn_ranger", "rag_duelist"],
		"signal payload detached from stored selection")
	_check(requests[0] == ["warden", "tinker", "lantern_monk"],
		"first request unchanged by subsequent opening")
	_check(randi() == second, "all input/reopen operations consume no global RNG")
	_check(FileAccess.get_file_as_string(
		"res://data/heroes/starter_party.json") == before_json,
		"view changed no authoritative authored hero data")
	picker.queue_free()
	await _frames()
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("PASS live_v3_party_picker_test: %d assertions" % checks)
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		printerr("FAIL live_v3_party_picker_test: %d/%d" % [
			failures.size(), checks])
		quit(1)
