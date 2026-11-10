extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _reject(stage: StitchedWalkScreen, kind: String, extra: Dictionary, stale: Variant = null) -> void:
	var before := stage.walk.snapshot()
	var receipt := stage.command(kind, extra, stale)
	_check(not receipt.ok and not receipt.error.is_empty() and receipt.events.is_empty(), "negative command returns rejection")
	_check(stage.walk.snapshot() == before and receipt.snapshot == before, "rejection preserves HP, pockets, ranks, WHIRR, pending and RNG")


## Exercise the real mounted buttons; their reveal is free and focuses a
## non-disabled action, while every original rule oracle remains independent.
func _open_drawer(stage: StitchedWalkScreen) -> void:
	var before := stage.walk.snapshot()
	var receipt_count := stage.receipts.size()
	_check(not stage.drawer_open and stage.drawer_toggle.is_visible_in_tree(), "drawer can reopen only from a visible, quiet toggle")
	stage.drawer_toggle.pressed.emit()
	_check(stage.drawer_open and stage.drawer_toggle.text == "CLOSE DRAWER", "same toggle reveals the drawer")
	var first_eligible: Button
	for button in stage.switch_buttons + stage.pocket_buttons:
		_check(button.is_visible_in_tree() and button.focus_mode == Control.FOCUS_ALL, "all four switches and both pockets reveal")
		if first_eligible == null and not button.disabled:
			first_eligible = button
	_check(first_eligible != null and first_eligible.has_focus(), "drawer opening focuses first eligible action")
	_check(stage.walk.snapshot() == before and stage.receipts.size() == receipt_count, "opening costs no state, RNG or receipt")


func _closed_drawer(stage: StitchedWalkScreen) -> void:
	_check(not stage.drawer_open, "drawer collapsed")
	for button in stage.switch_buttons + stage.pocket_buttons:
		_check(not button.visible and not button.has_focus() and button.focus_mode == Control.FOCUS_NONE, "hidden secondary action cannot retain focus")


func _hidden_signals_are_inert(stage: StitchedWalkScreen) -> void:
	var before := stage.walk.snapshot()
	var receipt_count := stage.receipts.size()
	for button in stage.switch_buttons + stage.pocket_buttons:
		button.pressed.emit()
	_check(stage.walk.snapshot() == before and stage.receipts.size() == receipt_count, "six hidden pressed signals bypass neither rules nor receipt guard")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var art: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(StitchedWalkScreen.ART_PATH))
	_check(StitchedWalkScreen.validate_art(art), "complete per-corridor per-step art validated")
	for field in ["corridors", "eyes", "heads", "look_back", "fallbacks"]:
		var broken := art.duplicate(true)
		broken.erase(field)
		_check(not StitchedWalkScreen.validate_art(broken), "missing art field rejected " + field)
	var broken := art.duplicate(true)
	broken.corridors.wall_lath_passage[0] = ["res://outside.png"]
	_check(not StitchedWalkScreen.validate_art(broken), "invalid layer schema rejected")
	_check(StitchedWalkScreen.texture_or_fallback("res://assets/paper/walk/missing_test.png", art.fallbacks[0]) != null, "absent layer uses authored texture")
	var replays: Array = []
	for repeat in 2:
		var stage := StitchedWalkScreen.new()
		_check(stage.begin(), "seeded screen starts")
		_check(not stage.begin(), "screen start cannot replace existing rules")
		root.add_child(stage)
		await process_frame
		_check(stage.walk != null and stage.expected.dolls.size() == 4, "mounted tests have actual four-doll rules")
		var random := RandomNumberGenerator.new()
		random.seed = StitchedWalkScreen.PREVIEW_SEED
		var oracle := StitchedWalkRules.start(random, "walls", stage.expected.dolls, stage.expected.pockets, null, true)
		_check(oracle != null and oracle.snapshot() == stage.expected, "screen opts into seeded mimic scheduling")
		_check(stage.stage != null and stage.stage.get_rect() == StitchedWalkScreen.VIEW and stage.switch_buttons.size() == 4 and stage.pocket_buttons.size() == 2, "full-screen 3D corridor and six original secondary controls")
		for index in 4:
			_check(stage.switch_buttons[index].position == Vector2(24, 474 + 54 * index), "all switch buttons retain left column coordinates")
		for index in 2:
			_check(stage.pocket_buttons[index].position == Vector2(1010, 582 + 56 * index), "both pocket controls retain right column coordinates")
		_check(stage.stage.corridor.get_child_count() == 6 and stage.stage.steps == int(stage.expected.corridor.steps), "corridor built for this walk")
		for surface in stage.stage.corridor.get_children():
			_check((surface as MeshInstance3D).mesh.material.albedo_texture != null, "every corridor surface is an authored picture")
		_check(stage.stage.camera.rotation.y == 0.0 and not stage.stage.looking_back, "the borrowed eye faces ahead")
		_check(stage.drawer_toggle.position == Vector2(24, 414) and stage.drawer_toggle.size.y <= 52.0, "quiet drawer toggle is left of central horror panel")
		for button in [stage.forward_button, stage.back_button, stage.exit_button, stage.drawer_toggle]:
			_check(button.is_visible_in_tree() and button.focus_mode == Control.FOCUS_ALL and Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(button.get_global_rect()), "primary mouse and keyboard controls remain in viewport")
		for button in [stage.exit_button, stage.drawer_toggle]:
			_check(button.get_theme_stylebox("normal") is StyleBoxTexture, "image-backed gothic primary control")
		# Owner 11-09: no WALK ON button; the hallway and the floor are the controls.
		for button in [stage.forward_button, stage.back_button]:
			_check(button.text.is_empty() and button.get_theme_stylebox("normal") is StyleBoxEmpty
				and button.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "walking is the hallway itself, not a framed button")
		_check(stage.forward_button.get_global_rect().size.x >= 600 and stage.forward_button.get_global_rect().encloses(Rect2(560, 200, 160, 120)),
			"the open hallway ahead is the walk-on target")
		for button in stage.switch_buttons + stage.pocket_buttons:
			_check(not button.is_visible_in_tree() and button.focus_mode == Control.FOCUS_NONE and Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(button.get_global_rect()), "quiet mount hides secondary controls at their original side positions")
			_check(button.get_theme_stylebox("normal") is StyleBoxTexture, "six secondary controls retain image-backed states")
		_closed_drawer(stage)
		_hidden_signals_are_inert(stage)
		var free_state := stage.walk.snapshot()
		var free_receipts := stage.receipts.size()
		_open_drawer(stage)
		var blocked_before := stage.walk.snapshot()
		var blocked_count := stage.receipts.size()
		stage.switch_buttons[0].pressed.emit()
		_check(stage.walk.snapshot() == blocked_before and stage.receipts.size() == blocked_count, "revealed but disabled current-doll switch is not a transaction")
		stage.drawer_toggle.pressed.emit()
		_closed_drawer(stage)
		_check(stage.drawer_toggle.has_focus() and stage.walk.snapshot() == free_state and stage.receipts.size() == free_receipts, "toggle dismissal restores focus without rule transaction")
		_open_drawer(stage)
		var esc := InputEventKey.new()
		esc.keycode = KEY_ESCAPE
		esc.pressed = true
		Input.parse_input_event(esc)
		await process_frame
		_closed_drawer(stage)
		_check(stage.drawer_toggle.has_focus() and stage.walk.snapshot() == free_state and stage.receipts.size() == free_receipts, "Escape dismissal restores toggle focus with exact snapshot and receipts")
		stage.drawer_toggle.grab_focus()
		var accept := InputEventKey.new()
		accept.keycode = KEY_ENTER
		accept.pressed = true
		Input.parse_input_event(accept)
		await process_frame
		_check(stage.drawer_open, "keyboard activation opens focusable drawer toggle")
		stage.drawer_toggle.pressed.emit()
		_closed_drawer(stage)
		_check(stage.walk.snapshot() == free_state and stage.receipts.size() == free_receipts, "keyboard opening and closing leave RNG and receipts unchanged")
		_check(stage.eye_profile == "cracked" and stage.eye_overlay.visible and stage.eye_overlay.texture != null, "lead head selects visible cracked treatment")
		var ranks: Array = stage.expected.dolls.map(func(doll): return [doll.id, doll.rank])
		var stale := stage.expected.duplicate(true)
		stage.back_button.pressed.emit()
		var receipt := oracle.act({"kind": "look_back", "actor": oracle.snapshot().viewpoint}, oracle.snapshot())
		_check(stage.receipts.back() == receipt and stage.expected.looking_back and stage.expected.whirr == 5, "mounted LOOK BACK matches exact receipt")
		_check(stage.stage.looking_back and not stage.event_panel.visible, "LOOK BACK turns the eye round")
		var visible_dolls := 0
		for doll in stage.expected.dolls:
			var figure: Sprite3D = stage.stage.figure_nodes.get(doll.id)
			if figure != null and figure.visible:
				visible_dolls += 1
				_check(figure.texture != null and stage.figure_labels[doll.id].text == doll.name, "trailing doll art carries its name")
		_check(visible_dolls == 3 and stage.stage.figure_nodes.has(stage.expected.shadow.id) == oracle.shadow_visible(), "three real trailing dolls plus only scheduled shadow")
		var last_doll: String = stage.expected.dolls[3].id
		stage.candle = 0
		stage.refresh()
		_check(stage.readout.text.contains("snuffed") and stage.stage.figure_nodes[last_doll].modulate.a < 0.2, "candle band fades distant dolls")
		stage.candle = 78
		stage.refresh()
		_check(stage.stage.figure_nodes[last_doll].modulate.a == 1.0, "bright candle restores trailing visibility")
		_reject(stage, "forward", {}, stale)
		_reject(stage, "switch", {"target": "LOST"})
		_reject(stage, "look_back", {"actor": "invalid"})
		_reject(stage, "use_item", {"slot": 3, "target": stage.expected.viewpoint})
		for index in range(1, 4):
			_open_drawer(stage)
			var actor: String = oracle.snapshot().viewpoint
			var target: String = stage.expected.dolls[index].id
			var former_whirr: int = stage.expected.whirr
			var former_count: int = stage.receipts.size()
			stage.switch_buttons[index].pressed.emit()
			_closed_drawer(stage)
			_check(stage.receipts.size() == former_count + 1 and stage.expected.whirr == former_whirr + 5, "accepted switch has exactly one +5 WHIRR receipt")
			receipt = oracle.act({"kind": "switch", "actor": actor, "target": target}, oracle.snapshot())
			_check(stage.receipts.back() == receipt and stage.expected.viewpoint == target and not stage.expected.looking_back, "mounted SWITCH delegates exact receipt")
			_check(stage.eye_profile == ["cracked", "glass", "one_eye", "ears"][index], "head-part ID changes eye profile")
			_check(stage.eye_overlay.texture != null and stage.eye_overlay.visible, "each eye treatment backed by authored image")
			if index == 2:
				var expected_width := StitchedWalkScreen.VIEW.size.x if ResourceLoader.exists(art.eyes.one_eye.path) else StitchedWalkScreen.VIEW.size.x / 2
				_check(stage.eye_overlay.size.x == expected_width, "one eye uses full authored overlay or half-view fallback")
		_check(stage.expected.dolls.map(func(doll): return [doll.id, doll.rank]) == ranks, "all switching preserves ranks")
		_check(stage.pocket_buttons[0].disabled and stage.pocket_buttons[0].text == "Empty pocket", "empty pocket disabled on real doll")
		_open_drawer(stage)
		var empty_state := stage.walk.snapshot()
		var empty_count := stage.receipts.size()
		stage.pocket_buttons[0].pressed.emit()
		_check(stage.walk.snapshot() == empty_state and stage.receipts.size() == empty_count and stage.drawer_open, "disabled empty pocket is inert and stays revealed")
		stage.drawer_toggle.pressed.emit()
		_closed_drawer(stage)
		_reject(stage, "use_item", {"slot": 0, "target": stage.expected.viewpoint})
		_open_drawer(stage)
		stage.switch_buttons[0].pressed.emit()
		_closed_drawer(stage)
		oracle.act({"kind": "switch", "actor": oracle.snapshot().viewpoint, "target": stage.expected.dolls[0].id}, oracle.snapshot())
		for slot in [0, 0]:
			_open_drawer(stage)
			var actor: String = oracle.snapshot().viewpoint
			var mend: String = stage.pocket_target(str(stage.expected.pockets[actor][slot]))
			var prior_whirr: int = stage.expected.whirr
			var prior_count: int = stage.receipts.size()
			stage.pocket_buttons[slot].pressed.emit()
			_closed_drawer(stage)
			_check(stage.receipts.size() == prior_count + 1, "accepted pocket produces exactly one receipt")
			_check(stage.expected.whirr - prior_whirr == (15 if stage.expected.pockets[actor].size() == 0 else 5), "ordinary pocket and fresh stuffing retain authored WHIRR costs")
			receipt = oracle.act({"kind": "use_item", "actor": actor, "slot": slot, "target": mend}, oracle.snapshot())
			_check(receipt.ok and stage.receipts.back() == receipt and receipt.events[0].kind == "heal", "mounted healing pockets reflect exact HP and WHIRR receipts")
		_check(stage.pocket_buttons[0].disabled and stage.expected.pockets[stage.expected.viewpoint].is_empty(), "consumed items leave empty pockets")
		_open_drawer(stage)
		var forward_count := stage.receipts.size()
		stage.forward_button.pressed.emit()
		_closed_drawer(stage)
		_check(stage.receipts.size() == forward_count + 1 and stage.expected.step == 1, "accepted forward step closes drawer after one receipt")
		receipt = oracle.act({"kind": "forward", "actor": oracle.snapshot().viewpoint}, oracle.snapshot())
		_check(stage.receipts.back() == receipt and stage.travel != null and stage.travel.is_running(), "ordinary forward creates travel tween after exact S8a action")
		stage.set_reduced_motion(true)
		_check(not stage.drawer_open and stage.drawer_toggle.is_visible_in_tree(), "reduced motion preserves quiet drawer")
		_check(stage.travel == null and not stage.stage.moving() and stage.stage.camera.position == Vector3(0, StitchedCorridorStage.EYE, stage.stage.eye_z(stage.expected.step)), "reduced motion immediately finishes travel geometry")
		while stage.expected.phase == "walking":
			stage.forward_button.pressed.emit()
			receipt = oracle.act({"kind": "forward", "actor": oracle.snapshot().viewpoint}, oracle.snapshot())
			_check(stage.receipts.back() == receipt and stage.travel == null, "reduced forward immediate and authoritative")
		_check(stage.forward_button.disabled and stage.back_button.disabled, "finished walk disables movement")
		_closed_drawer(stage)
		_check(not stage.drawer_toggle.visible and not stage.drawer_toggle.has_focus(), "completed walk has no hidden drawer toggle focused")
		var ended_snapshot := stage.walk.snapshot()
		var ended_count := stage.receipts.size()
		stage.forward_button.pressed.emit()
		stage.back_button.pressed.emit()
		_check(stage.walk.snapshot() == ended_snapshot and stage.receipts.size() == ended_count,
			"wrong-phase forward and look-back controls cannot create an extra transaction")
		_hidden_signals_are_inert(stage)
		stage.drawer_toggle.pressed.emit()
		_check(not stage.drawer_open, "completed walk refuses stale toggle activation")
		_reject(stage, "forward", {})
		_check(stage.expected.pending == oracle.snapshot().pending and stage.expected.pending.size() == (1 if stage.expected.shadow.present else 0)
			and stage.expected.rng == random.state, "only unresolved mimic deferred, with no action RNG draws")
		if repeat == 0:
			replays = stage.receipts.duplicate(true)
		else:
			_check(stage.receipts == replays, "complete mounted replay has identical receipts including negatives")
		stage.free()
	# Metadata is keyed by part ID, never doll identity. Unknown parts stay neutral.
	var neutral := StitchedWalkScreen.new()
	_check(neutral.begin(), "neutral fixture starts")
	neutral.art.heads.clear()
	root.add_child(neutral)
	await process_frame
	_check(neutral.eye_profile == "neutral" and not neutral.eye_overlay.visible, "unknown head metadata safely neutral")
	neutral.free()
	await _public_mount()
	await _host_tug_mount()
	await _mimic_mounts()
	await _deferred_items()
	await _animated_lookback_labels()
	var source := FileAccess.get_file_as_string("res://scripts/stitched/walk/stitched_walk_screen.gd")
	for forbidden in ["func _draw", "draw_", "StyleBoxFlat.new", "GradientTexture", "GPUParticles", "randi()", "randomize()"]:
		_check(not source.contains(forbidden), "screen has no generated art or unseeded RNG " + forbidden)
	for failure in failures:
		printerr(failure)
	print("stitched_s8b_walk_screen_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _public_mount() -> void:
	var app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await process_frame
	var boot = root.get_node("LiveWebPlaytestBoot")
	_check(await boot.enter_preview(app, boot.screen_from_query("?screen=stitched_walk")), "public URL mounts real app Walk")
	var stage: StitchedWalkScreen = boot.walk_view
	_check(is_instance_valid(stage) and stage.is_visible_in_tree() and stage.expected.has("shadow"), "real public mount opts into S8c scheduling")
	if is_instance_valid(stage):
		stage.set_reduced_motion(true)
		while stage.expected.step < stage.expected.shadow.step:
			stage.forward_button.pressed.emit()
		stage.back_button.pressed.emit()
		_check(stage.stage.figure_nodes.has(stage.expected.shadow.id) == stage.expected.shadow.present, "real URL LOOK BACK reaches seeded reveal")
		stage.exit_button.pressed.emit()
		await process_frame
		_check(boot.walk_view == null and app.title_view.is_visible_in_tree() and app.run_rng == null, "public exit restores title without allocating live route combat")
	app.free()


func _host_tug_mount() -> void:
	var app = load("res://scenes/app.tscn").instantiate()
	app.run_seed = 42
	root.add_child(app)
	await process_frame
	app.start_button.pressed.emit()
	await process_frame
	app.stitched_run_buttons[0].pressed.emit()
	await process_frame
	var pick := -1
	var choices: Array = app.stitched_run_session.choices()
	for index in choices.size():
		if app.stitched_run_session.map.get_node(choices[index]).type != "Boss":
			pick = index
			break
	_check(pick >= 0, "real New Run offers non-boss route")
	if pick < 0:
		app.free()
		return
	app.stitched_run_buttons[pick].pressed.emit()
	await process_frame
	var stage: StitchedWalkScreen = app.stitched_run_walk
	_check(stage != null and stage.host == app.stitched_run_session and stage.walk != null, "live route mounts authoritative walk with session")
	if stage == null:
		app.free()
		return
	_check(stage.expected.has("tug"), "live session has real scheduled tug")
	if not stage.expected.has("tug"):
		app.free()
		return
	stage.set_reduced_motion(true)
	var tug_step: int = int(stage.expected.tug.step)
	while stage.expected.step < tug_step and stage.expected.phase == "walking":
		stage.forward_button.pressed.emit()
	_check(stage.walk.tug_unresolved() and stage.event_panel.visible and stage.forward_button.tooltip_text == "Let it take one",
		"real hosted tug shows its required yield action at scheduled step")
	var held: Array = stage.expected.pockets[stage.expected.viewpoint]
	var item_choices := int("pins" in held) + int("spare_spool" in held)
	_check(stage.event_buttons.size() == item_choices, "genuine tug offers only the carried pin or spool alternatives")
	var before := stage.host.snapshot()
	var journal_count := stage.host.journal.size()
	_open_drawer(stage)
	stage.refresh()
	_check(stage.drawer_open and stage.event_panel.visible and stage.host.snapshot() == before and stage.host.journal.size() == journal_count,
		"real hosted tug keeps event visible and journal unchanged on drawer refresh")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await process_frame
	_closed_drawer(stage)
	_check(stage.drawer_toggle.has_focus() and stage.host.snapshot() == before and stage.host.journal.size() == journal_count,
		"hosted Escape closes drawer without a run journal entry")
	_open_drawer(stage)
	for button in stage.event_buttons:
		_check(button.is_visible_in_tree() and button.focus_mode == Control.FOCUS_ALL and not button.disabled, "tug answer remains keyboard and mouse accessible")
	stage.back_button.pressed.emit()
	_check(stage.drawer_open and not stage.event_panel.visible, "looking back hides only tug panel, not open drawer")
	var switch_index := -1
	for index in stage.switch_buttons.size():
		if not stage.switch_buttons[index].disabled:
			switch_index = index
			break
	_check(switch_index >= 0, "a real eligible doll can restore forward sight")
	if switch_index >= 0:
		stage.switch_buttons[switch_index].pressed.emit()
		_closed_drawer(stage)
		_check(not stage.expected.looking_back and stage.event_panel.visible, "switch returns to tug panel without obscuring it")
		_open_drawer(stage)
	var before_tug_step := int(stage.expected.step)
	var before_tug_count := stage.receipts.size()
	stage.forward_button.pressed.emit()
	_check(stage.receipts.size() == before_tug_count + 1 and stage.receipts.back().ok and not stage.walk.tug_unresolved()
		and int(stage.expected.step) == before_tug_step and stage.drawer_open, "actual tug resolution does not collapse drawer before a step transition")
	app.free()


func _mimic_mounts() -> void:
	var witnesses := {true: 0, false: 0}
	for seed_number in range(16):
		var stage := StitchedWalkScreen.new()
		_check(stage.begin(seed_number), "public seeded mimic witness starts")
		root.add_child(stage)
		await process_frame
		stage.set_reduced_motion(true)
		while stage.expected.step < stage.expected.shadow.step:
			stage.forward_button.pressed.emit()
		stage.back_button.pressed.emit()
		var present: bool = stage.expected.shadow.present
		witnesses[present] += 1
		var shadow_id: String = stage.expected.shadow.id
		var visible := 0
		for id in stage.stage.figure_nodes:
			if stage.figure_labels.has(id):
				visible += int(stage.stage.figure_nodes[id].visible)
		_check(visible == (4 if present else 3), "only seeded shadow shows four trailing figures")
		_check(stage.snip_buttons.size() == (4 if present else 0) and stage.clue.visible == present, "SNIP and clue only for shadow")
		if present:
			_check(stage.stage.figure_nodes[shadow_id].texture != null and stage.figure_labels[shadow_id].text.contains("Loose seam"), "authored fallback and distinct stitched clue mounted")
			for doll in stage.expected.dolls:
				if doll.id == stage.expected.shadow.disguise:
					_check(stage.figure_labels[shadow_id].text.begins_with(doll.name), "extra doll uses the disguised doll name")
			for index in [1, 2, 3]:
				_open_drawer(stage)
				stage.switch_buttons[index].pressed.emit()
				_closed_drawer(stage)
				stage.back_button.pressed.emit()
				_check(stage.clue.visible and not stage.clue.text.is_empty(), "all eye profiles retain readable clue")
				if index == 1:
					_check(stage.clue.text.contains("seams"), "glass eyes expose seams")
				if index == 3:
					_check(stage.clue.text.contains("breathing"), "stitched ears hear breathing")
			_check(stage.snip_buttons.size() == 4 and stage.snip_buttons.has(shadow_id), "three real targets and extra doll")
			for control in stage.snip_buttons.values():
				_check(control.is_visible_in_tree() and control.focus_mode == Control.FOCUS_ALL
					and Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(control.get_global_rect()), "SNIP reachable by mouse and keyboard")
			stage.snip_buttons[shadow_id].pressed.emit()
			_check(stage.receipts.back().ok and stage.expected.shadow.removed and not stage.stage.figure_nodes.has(shadow_id)
				and stage.snip_buttons.is_empty(), "mounted SNIP under the figure clears the shadow")
		else:
			_reject(stage, "snip", {"target": "extra_thread_shadow"})
		stage.free()
	_check(witnesses[true] > 0 and witnesses[false] > 0, "non-vacuous shadow and ordinary public seeds")


## Playtest 11-10: after an animated Look back the trailing name plates must
## settle under their own figures once the turn finishes, not stay stacked on the
## shared fallback point the mid-turn placement falls back to.
func _animated_lookback_labels() -> void:
	var stage := StitchedWalkScreen.new()
	_check(stage.begin(), "animated look back witness starts")
	root.add_child(stage)
	await process_frame
	stage.back_button.pressed.emit()
	_check(stage.travel != null, "live animated turn runs for the look back")
	if stage.travel == null:
		stage.free()
		return
	await stage.travel.finished
	var spots := {}
	for id in stage.figure_labels:
		spots[stage.figure_labels[id].position] = id
	_check(spots.size() == stage.figure_labels.size(), "finished turn spreads every name plate apart")
	for id in stage.figure_labels:
		_check(stage.figure_labels[id].position != Vector2(550, 424), "no name plate rests on the shared fallback point " + str(id))
	stage.free()


func _deferred_items() -> void:
	var stage: StitchedWalkScreen
	var curio_step := -1
	for seed_number in range(548, 564):
		var candidate := StitchedWalkScreen.new()
		_check(candidate.begin(seed_number), "item witness seed starts")
		for curio in candidate.expected.curios:
			if curio.step < candidate.expected.corridor.steps:
				curio_step = curio.step
		if curio_step >= 0:
			stage = candidate
			break
		candidate.free()
	_check(stage != null and curio_step > 0, "real reachable curio witness for pins")
	if stage == null:
		return
	root.add_child(stage)
	await process_frame
	stage.set_reduced_motion(true)
	var pristine_dolls: Array = stage.expected.dolls.duplicate(true)
	_open_drawer(stage)
	stage.switch_buttons[1].pressed.emit()
	_closed_drawer(stage)
	for item in ["starch", "dye"]:
		_open_drawer(stage)
		stage.pocket_buttons[0].pressed.emit()
		_closed_drawer(stage)
		var receipt: Dictionary = stage.receipts.back()
		_check(receipt.ok and receipt.snapshot.pending.back().kind == item and not receipt.snapshot.pending.back().consumed, "mounted deferred item queues truthful pending receipt " + item)
	_open_drawer(stage)
	stage.switch_buttons[2].pressed.emit()
	_closed_drawer(stage)
	_reject(stage, "use_item", {"slot": 0, "target": stage.expected.viewpoint})
	while stage.expected.step < curio_step:
		stage.forward_button.pressed.emit()
	var curio := stage.current_curio()
	_check(not curio.is_empty() and stage.pocket_target("pins") == curio.instance, "pins go to the curio in the way")
	_check(stage.event_panel.visible and stage.event_buttons.size() >= 2 and stage.stage.figure_nodes.has("curio"), "the curio stands in the corridor with its choices")
	for control in stage.event_buttons:
		_check(control.is_visible_in_tree() and not control.disabled and control.get_theme_stylebox("normal") is StyleBoxTexture, "curio choices stay reachable and sewn")
	_open_drawer(stage)
	var with_curio := stage.walk.snapshot()
	var with_curio_receipts := stage.receipts.size()
	stage.refresh()
	_check(stage.drawer_open and stage.event_panel.visible and stage.walk.snapshot() == with_curio and stage.receipts.size() == with_curio_receipts, "unresolved curio refresh never auto-closes pockets")
	_reject(stage, "switch", {"target": "LOST"})
	_check(stage.drawer_open, "rejected curio command leaves drawer open")
	stage.pocket_buttons[0].pressed.emit()
	_closed_drawer(stage)
	_check(stage.event_panel.visible, "pocket use leaves unresolved curio choices visible")
	_check(stage.receipts.back().ok and stage.expected.pending.back().kind == "pins" and not stage.expected.pending.back().consumed, "mounted pins queues current-instance effect")
	_open_drawer(stage)
	stage.pocket_buttons[0].pressed.emit()
	_closed_drawer(stage)
	_check(stage.receipts.back().ok and stage.expected.pending.back().kind == "spare_spool", "mounted spare spool queues receipt")
	_check(stage.expected.pending.size() == 4 and stage.expected.dolls == pristine_dolls and stage.expected.whirr == 30, "deferred items never resolve horrors, HP, ranks or fray")
	for pending in stage.expected.pending:
		_check(not pending.consumed, "pending effects left for later stages")
	var choice_count := stage.receipts.size()
	var old_event_button := stage.event_buttons[0]
	old_event_button.pressed.emit()
	_check(stage.receipts.size() == choice_count + 1 and stage.receipts.back().ok
		and stage.current_curio().is_empty() and not stage.event_panel.visible, "real event choice remains clickable after drawer and pocket use")
	var event_complete_snapshot := stage.walk.snapshot()
	old_event_button.pressed.emit()
	_check(stage.receipts.size() == choice_count + 1 and stage.walk.snapshot() == event_complete_snapshot,
		"stale event button cannot generate second receipt after curio resolves")
	stage.free()
