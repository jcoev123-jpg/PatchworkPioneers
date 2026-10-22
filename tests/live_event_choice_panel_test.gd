extends SceneTree
## Mounted, deterministic M04 Event panel contract. No live app wiring or effects.
const PANEL_SCENE := "res://scenes/event_choice_panel.tscn"
const EVENTS_PATH := "res://data/events/m04_events.json"
const REQUIRED := {
	"button_trail": "The Button Trail",
	"loose_seam": "The Loose Seam",
	"thimble_well": "The Thimble Well",
	"frayed_signpost": "The Frayed Signpost",
	"quiet_spool": "The Quiet Spool",
	"needle_gate": "The Needle Gate",
}

var panel: LiveEventChoicePanel
var failures: Array[String] = []
var checks: int = 0
var committed: Array[Dictionary] = []
var authored: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _frames() -> void:
	for i in range(4):
		await process_frame


func _key(key: Key) -> void:
	for state in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = state
		root.push_input(event, true)
	await _frames()


func _mouse(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for state in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = state
		root.push_input(event, true)
	await _frames()


func _on_choice_committed(event_id: String, choice_id: String) -> void:
	committed.append({"event_id": event_id, "choice_id": choice_id})


func _fixture_three() -> Dictionary:
	return {
		"id": "three_choice_fixture",
		"title": "Three Way Crossroads",
		"description": "A very long stitched description that must remain intact, even when a third choice appears underneath the patchwork paper scene.",
		"choices": [
			{"id": "left", "text": "Take the long, quiet left trail"},
			{"id": "right", "text": "Take the steep right trail"},
			{"id": "wait", "text": "Wait on the soft grass"},
		],
	}


func _read_authored() -> void:
	var file := FileAccess.open(EVENTS_PATH, FileAccess.READ)
	_check(file != null, "authored catalog opens")
	if file == null:
		return
	var parser := JSON.new()
	var err := parser.parse(file.get_as_text())
	file.close()
	_check(err == OK, "authored catalog parses")
	if err != OK:
		return
	_check(parser.data is Dictionary, "authored catalog object")
	if not parser.data is Dictionary:
		return
	var events: Variant = parser.data.get("events")
	_check(events is Array, "authored events array")
	if not events is Array:
		return
	for id in REQUIRED:
		var matches := (events as Array).filter(func(record) -> bool:
			return record is Dictionary and record.get("id") == id)
		_check(matches.size() == 1, "exactly one authored ID " + id)
		if matches.size() == 1:
			authored[id] = matches[0]
			_check(matches[0].get("title") == REQUIRED[id], "required title unchanged: " + id)
			_check(RunEventChoice.new(matches[0]).is_valid(), "required record valid: " + id)


func _validate_layout(record: Dictionary, label: String) -> void:
	_check(panel.is_visible_in_tree() and panel.has_open_event(), label + " panel open/visible")
	_check(panel.title_label.text == record["title"], label + " exact title")
	_check(panel.description_label.text == record["description"], label + " complete description")
	_check(panel.paper_panel.get_theme_stylebox("panel") is StyleBoxFlat,
		label + " patchwork paper StyleBoxFlat")
	_check(panel.get_node("SlateBackdrop") is ColorRect, label + " slate background node")
	var choices: Array = record["choices"]
	var buttons := panel.get_choice_buttons()
	_check(buttons.size() == choices.size(), label + " exact choice count")
	_check(panel.choices_container.get_child_count() == choices.size(), label + " mounted choices count")
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(root.size))
	_check(viewport_rect.encloses(panel.paper_panel.get_global_rect()), label + " paper fits viewport")
	for i in range(mini(buttons.size(), choices.size())):
		var button: Button = buttons[i]
		_check(panel.choices_container.get_child(i) == button, label + " authentic button " + str(i))
		_check(button.text == choices[i]["text"], label + " exact authored choice text " + str(i))
		_check(button.name == "Choice_%d" % i, label + " stable choice node identity " + str(i))
		_check(button.focus_mode == Control.FOCUS_ALL, label + " keyboard reachable " + str(i))
		_check(not button.disabled and button.is_visible_in_tree(), label + " enabled and visible " + str(i))
		_check(viewport_rect.encloses(button.get_global_rect()), label + " full button fits viewport " + str(i))
		_check(button.get_theme_stylebox("normal") is StyleBoxFlat
			and button.get_theme_stylebox("focus") is StyleBoxFlat, label + " procedural button/focus styling " + str(i))


func _test_authored() -> void:
	var step := 0
	for id in REQUIRED:
		if not authored.has(id):
			continue
		step += 1
		var record: Dictionary = authored[id]
		committed.clear()
		_check(panel.open_event(record), "open authored " + id)
		await _frames()
		_validate_layout(record, id)
		var buttons := panel.get_choice_buttons()
		if buttons.size() != (record["choices"] as Array).size():
			panel.close_event()
			await _frames()
			continue
		var desired_index := step % buttons.size()
		var selected: Button = buttons[desired_index]
		# Verify physical pointer and both keyboard activation paths.
		if step == 1:
			await _mouse(selected)
		elif step == 2:
			selected.grab_focus()
			await _frames()
			_check(selected.has_focus(), "Enter target really focused")
			await _key(KEY_ENTER)
		elif step == 3:
			# Native keyboard focus traversal, then physical Space.
			# Select buttons[1] for focus traversal test, adjust expected index accordingly.
			buttons[0].grab_focus()
			await _frames()
			await _key(KEY_TAB)
			_check(buttons[1].has_focus(), "Tab moves focus between real authored buttons")
			selected = buttons[1]
			desired_index = 1
			await _key(KEY_SPACE)
		else:
			selected.pressed.emit()
		_check(committed.size() == 1, "exactly one authored commit " + id)
		if committed.size() == 1:
			_check(committed[0] == {"event_id": id, "choice_id": record["choices"][desired_index]["id"]},
				"exact chosen authored IDs " + id)
		for button in buttons:
			_check(button.disabled, "all authored buttons spent after success " + id)
			button.pressed.emit()
		_check(committed.size() == 1, "no replay despite explicit pressed signals " + id)
		_check(panel._selector.is_claimed(), "real selector claimed " + id)
		panel.close_event()
		await _frames()
		_check(not panel.has_open_event() and not panel.visible
			and panel.get_choice_buttons().is_empty(), "close releases authored " + id)


func _test_three_choice_and_identity() -> void:
	var original := _fixture_three()
	var caller := original.duplicate(true)
	committed.clear()
	_check(panel.open_event(caller), "valid three-choice fixture accepted")
	await _frames()
	_validate_layout(original, "three-choice fixture")
	var buttons := panel.get_choice_buttons()
	_check(buttons.size() == 3, "three independent selector buttons present")
	if buttons.size() != 3:
		panel.close_event()
		await _frames()
		return
	var first_selector := panel._selector
	var first_generation := panel._generation
	var stale_callable: Callable = buttons[0].pressed.get_connections()[0]["callable"]
	# Detachment includes nested structures and current presentation text.
	caller["title"] = "TAMPERED"
	caller["description"] = "TAMPERED"
	caller["choices"][0]["text"] = "TAMPERED"
	caller["choices"][0]["id"] = "forged"
	caller["choices"].append({"id": "new", "text": "new"})
	_validate_layout(original, "detached caller")
	_check(panel._selector.get_event() == original, "authoritative snapshot immune to nested caller mutation")
	# A physically hidden or disabled button's forcibly raised signal must not commit.
	buttons[0].hide()
	buttons[0].pressed.emit()
	_check(committed.is_empty() and panel._selector.is_valid(), "hidden choice inert")
	buttons[0].show()
	buttons[0].disabled = true
	buttons[0].pressed.emit()
	_check(committed.is_empty() and panel._selector.is_valid(), "disabled choice inert")
	buttons[0].disabled = false
	# Attempt an unoffered choice using a valid live button and a foreign valid
	# selector, plus a forged ID on a different real button.
	panel._on_choice_pressed(first_selector, "not_offered", first_generation, buttons[0])
	panel._on_choice_pressed(first_selector, "right", first_generation, buttons[0])
	panel._on_choice_pressed(RunEventChoice.new(original), "left", first_generation, buttons[0])
	var foreign := Button.new()
	panel.choices_container.add_child(foreign)
	panel._on_choice_pressed(first_selector, "left", first_generation, foreign)
	foreign.queue_free()
	_check(committed.is_empty() and first_selector.is_valid(), "foreign and forged callbacks reject without claim")
	# An invalid replacement must not consume/overwrite the current offering.
	_check(not panel.open_event(_fixture_three()), "active unclaimed event cannot be overwritten")
	_check(panel._selector == first_selector and panel._generation == first_generation,
		"refused overwrite preserves identity and generation")
	# Closed callbacks from the prior scene cannot spend the new selector.
	panel.close_event()
	var replacement := _fixture_three()
	replacement["id"] = "replacement_event"
	_check(panel.open_event(replacement), "new valid event opens after close")
	var replacement_selector := panel._selector
	var replacement_gen := panel._generation
	# Old Button is queued but not yet freed; its signal's saved Callable
	# and a direct forged stale callback both must fail closed.
	if is_instance_valid(buttons[0]):
		stale_callable.call()
		panel._on_choice_pressed(first_selector, "left", first_generation, buttons[0])
	_check(committed.is_empty() and replacement_selector.is_valid()
		and panel._selector == replacement_selector and replacement_gen != first_generation,
		"closed/reopened old callback cannot affect replacement")
	await _frames()
	_validate_layout(replacement, "replacement")
	var new_buttons := panel.get_choice_buttons()
	# Invalid offered ID on a current valid button is inert; later valid is accepted.
	panel._on_choice_pressed(replacement_selector, "unoffered", replacement_gen, new_buttons[0])
	_check(committed.is_empty() and replacement_selector.is_valid(), "unoffered ID remains claimable")
	new_buttons[2].pressed.emit()
	_check(committed.size() == 1 and committed[0] == {"event_id": "replacement_event", "choice_id": "wait"},
		"third offered choice commits exact replacement event and choice IDs")
	_check(replacement_selector.is_claimed(), "replacement selector latched")
	_check(not panel.open_event(original), "claimed open panel must close before next event")
	panel.close_event()
	await _frames()


func _test_invalid_and_replay() -> void:
	var valid := _fixture_three()
	var invalids: Array[Dictionary] = []
	for field in ["id", "title", "description", "choices"]:
		var missing := valid.duplicate(true)
		missing.erase(field)
		invalids.append(missing)
	for field in ["id", "title", "description"]:
		var blank := valid.duplicate(true)
		blank[field] = "   "
		invalids.append(blank)
	var numeric := valid.duplicate(true)
	numeric["id"] = 5
	invalids.append(numeric)
	var bad_choices := valid.duplicate(true)
	bad_choices["choices"] = "not an array"
	invalids.append(bad_choices)
	for n in [0, 1, 4]:
		var wrong_count := valid.duplicate(true)
		wrong_count["choices"] = valid["choices"].slice(0, n) if n < 4 else [
			{"id": "a", "text": "A"}, {"id": "b", "text": "B"},
			{"id": "c", "text": "C"}, {"id": "d", "text": "D"}]
		invalids.append(wrong_count)
	var duplicated := valid.duplicate(true)
	duplicated["choices"][1]["id"] = duplicated["choices"][0]["id"]
	invalids.append(duplicated)
	var malformed := valid.duplicate(true)
	malformed["choices"][0]["text"] = ""
	invalids.append(malformed)
	var nonobject := valid.duplicate(true)
	nonobject["choices"][1] = "invalid"
	invalids.append(nonobject)
	var blank_choice_id := valid.duplicate(true)
	blank_choice_id["choices"][1]["id"] = " "
	invalids.append(blank_choice_id)
	for i in range(invalids.size()):
		var before: Dictionary = invalids[i].duplicate(true)
		committed.clear()
		_check(not panel.open_event(invalids[i]), "malformed record rejected #" + str(i))
		_check(not panel.has_open_event() and not panel.visible
			and panel.get_choice_buttons().is_empty(), "invalid record never mounted buttons #" + str(i))
		_check(invalids[i] == before, "rejection never mutates caller #" + str(i))
		_check(committed.is_empty(), "rejection never emits #" + str(i))
	# Repeatable identical claim trace from independent selectors behind same panel.
	var replay: Array = []
	for attempt in range(2):
		committed.clear()
		_check(panel.open_event(valid), "replay opens independent fresh selector #" + str(attempt))
		await _frames()
		panel.get_choice_buttons()[1].pressed.emit()
		replay.append(committed.duplicate(true))
		panel.close_event()
		await _frames()
	_check(replay.size() == 2 and replay[0] == replay[1]
		and replay[0] == [{"event_id": "three_choice_fixture", "choice_id": "right"}],
		"two independent reopen traces are deterministic and identical")


func _test_rng_zero_draws() -> void:
	var original := _fixture_three()
	var local := RandomNumberGenerator.new()
	local.seed = 745392
	var local_state := local.state
	seed(743291)
	var expected := randi()
	seed(743291)
	committed.clear()
	_check(panel.open_event(original), "RNG test opens valid fixture")
	var buttons := panel.get_choice_buttons()
	panel._on_choice_pressed(panel._selector, "unoffered", panel._generation, buttons[0])
	buttons[0].pressed.emit()
	for button in buttons:
		button.pressed.emit()
	panel.close_event()
	_check(local.state == local_state, "local seeded RNG state untouched by all panel operations")
	_check(randi() == expected, "same global seeded stream has zero draws")
	_check(committed == [{"event_id": "three_choice_fixture", "choice_id": "left"}],
		"RNG flow commits once without effects")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := load(PANEL_SCENE) as PackedScene
	_check(scene != null, "real panel scene loads")
	if scene == null:
		_finish()
		return
	panel = scene.instantiate() as LiveEventChoicePanel
	_check(panel != null, "real scene has expected panel script")
	if panel == null:
		_finish()
		return
	root.add_child(panel)
	panel.choice_committed.connect(_on_choice_committed)
	await _frames()
	_check(not panel.visible and not panel.has_open_event(), "initially closed")
	_check(panel.has_method("open_event") and panel.has_method("close_event"),
		"required public lifecycle methods exist")
	_read_authored()
	await _test_authored()
	await _test_three_choice_and_identity()
	await _test_invalid_and_replay()
	_test_rng_zero_draws()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_event_choice_panel_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	if is_instance_valid(panel):
		panel.free()
	quit(0 if failures.is_empty() else 1)
