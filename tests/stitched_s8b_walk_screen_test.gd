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
		_check(stage.stage != null and stage.stage.get_rect() == StitchedWalkScreen.VIEW and stage.switch_buttons.size() == 4, "full-screen 3D corridor and rank controls")
		_check(stage.stage.corridor.get_child_count() == 6 and stage.stage.steps == int(stage.expected.corridor.steps), "corridor built for this walk")
		for surface in stage.stage.corridor.get_children():
			_check((surface as MeshInstance3D).mesh.material.albedo_texture != null, "every corridor surface is an authored picture")
		_check(stage.stage.camera.rotation.y == 0.0 and not stage.stage.looking_back, "the borrowed eye faces ahead")
		for button in [stage.forward_button, stage.back_button, stage.exit_button] + stage.switch_buttons + stage.pocket_buttons:
			_check(button.is_visible_in_tree() and button.focus_mode == Control.FOCUS_ALL and Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(button.get_global_rect()), "mouse and keyboard controls remain inside viewport")
			_check(button.get_theme_stylebox("normal") is StyleBoxTexture, "image-backed gothic control")
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
			var actor: String = oracle.snapshot().viewpoint
			var target: String = stage.expected.dolls[index].id
			stage.switch_buttons[index].pressed.emit()
			receipt = oracle.act({"kind": "switch", "actor": actor, "target": target}, oracle.snapshot())
			_check(stage.receipts.back() == receipt and stage.expected.viewpoint == target and not stage.expected.looking_back, "mounted SWITCH delegates exact receipt")
			_check(stage.eye_profile == ["cracked", "glass", "one_eye", "ears"][index], "head-part ID changes eye profile")
			_check(stage.eye_overlay.texture != null and stage.eye_overlay.visible, "each eye treatment backed by authored image")
			if index == 2:
				var expected_width := StitchedWalkScreen.VIEW.size.x if ResourceLoader.exists(art.eyes.one_eye.path) else StitchedWalkScreen.VIEW.size.x / 2
				_check(stage.eye_overlay.size.x == expected_width, "one eye uses full authored overlay or half-view fallback")
		_check(stage.expected.dolls.map(func(doll): return [doll.id, doll.rank]) == ranks, "all switching preserves ranks")
		_check(stage.pocket_buttons[0].disabled and stage.pocket_buttons[0].text == "Empty pocket", "empty pocket disabled on real doll")
		_reject(stage, "use_item", {"slot": 0, "target": stage.expected.viewpoint})
		stage.switch_buttons[0].pressed.emit()
		oracle.act({"kind": "switch", "actor": oracle.snapshot().viewpoint, "target": stage.expected.dolls[0].id}, oracle.snapshot())
		for slot in [0, 0]:
			var actor: String = oracle.snapshot().viewpoint
			var mend: String = stage.pocket_target(str(stage.expected.pockets[actor][slot]))
			stage.pocket_buttons[slot].pressed.emit()
			receipt = oracle.act({"kind": "use_item", "actor": actor, "slot": slot, "target": mend}, oracle.snapshot())
			_check(receipt.ok and stage.receipts.back() == receipt and receipt.events[0].kind == "heal", "mounted healing pockets reflect exact HP and WHIRR receipts")
		_check(stage.pocket_buttons[0].disabled and stage.expected.pockets[stage.expected.viewpoint].is_empty(), "consumed items leave empty pockets")
		stage.forward_button.pressed.emit()
		receipt = oracle.act({"kind": "forward", "actor": oracle.snapshot().viewpoint}, oracle.snapshot())
		_check(stage.receipts.back() == receipt and stage.travel != null and stage.travel.is_running(), "ordinary forward creates travel tween after exact S8a action")
		stage.set_reduced_motion(true)
		_check(stage.travel == null and not stage.stage.moving() and stage.stage.camera.position == Vector3(0, StitchedCorridorStage.EYE, stage.stage.eye_z(stage.expected.step)), "reduced motion immediately finishes travel geometry")
		while stage.expected.phase == "walking":
			stage.forward_button.pressed.emit()
			receipt = oracle.act({"kind": "forward", "actor": oracle.snapshot().viewpoint}, oracle.snapshot())
			_check(stage.receipts.back() == receipt and stage.travel == null, "reduced forward immediate and authoritative")
		_check(stage.forward_button.disabled and stage.back_button.disabled, "finished walk disables movement")
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
	await _mimic_mounts()
	await _deferred_items()
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
				stage.switch_buttons[index].pressed.emit()
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
	stage.switch_buttons[1].pressed.emit()
	for item in ["starch", "dye"]:
		stage.pocket_buttons[0].pressed.emit()
		var receipt: Dictionary = stage.receipts.back()
		_check(receipt.ok and receipt.snapshot.pending.back().kind == item and not receipt.snapshot.pending.back().consumed, "mounted deferred item queues truthful pending receipt " + item)
	stage.switch_buttons[2].pressed.emit()
	_reject(stage, "use_item", {"slot": 0, "target": stage.expected.viewpoint})
	while stage.expected.step < curio_step:
		stage.forward_button.pressed.emit()
	var curio := stage.current_curio()
	_check(not curio.is_empty() and stage.pocket_target("pins") == curio.instance, "pins go to the curio in the way")
	_check(stage.event_panel.visible and stage.event_buttons.size() >= 2 and stage.stage.figure_nodes.has("curio"), "the curio stands in the corridor with its choices")
	stage.pocket_buttons[0].pressed.emit()
	_check(stage.receipts.back().ok and stage.expected.pending.back().kind == "pins" and not stage.expected.pending.back().consumed, "mounted pins queues current-instance effect")
	stage.pocket_buttons[0].pressed.emit()
	_check(stage.receipts.back().ok and stage.expected.pending.back().kind == "spare_spool", "mounted spare spool queues receipt")
	_check(stage.expected.pending.size() == 4 and stage.expected.dolls == pristine_dolls and stage.expected.whirr == 30, "deferred items never resolve horrors, HP, ranks or fray")
	for pending in stage.expected.pending:
		_check(not pending.consumed, "pending effects left for later stages")
	stage.free()
