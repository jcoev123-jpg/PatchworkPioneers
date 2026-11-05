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
		var oracle := StitchedWalkRules.start(random, "walls", stage.expected.dolls, stage.expected.pockets)
		_check(oracle != null and oracle.snapshot() == stage.expected, "screen starts through exact S8a seed API")
		_check(stage.layers.size() == 3 and stage.trailing.size() == 4 and stage.switch_buttons.size() == 4, "nonempty mounted layer and rank controls")
		for index in stage.layers.size():
			_check(stage.layers[index].texture != null and stage.layers[index].get_rect() == StitchedWalkScreen.VIEW, "ordered authored layer geometry")
			if index > 0:
				_check(stage.layers[index - 1].get_index() < stage.layers[index].get_index(), "far mid near draw order")
		for button in [stage.forward_button, stage.back_button, stage.exit_button] + stage.switch_buttons + stage.pocket_buttons:
			_check(button.is_visible_in_tree() and button.focus_mode == Control.FOCUS_ALL and Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(button.get_global_rect()), "mouse and keyboard controls remain inside viewport")
			_check(button.get_theme_stylebox("normal") is StyleBoxTexture, "image-backed gothic control")
		_check(stage.eye_profile == "cracked" and stage.eye_overlay.visible and stage.eye_overlay.texture != null, "lead head selects visible cracked treatment")
		var ranks: Array = stage.expected.dolls.map(func(doll): return [doll.id, doll.rank])
		var stale := stage.expected.duplicate(true)
		stage.back_button.pressed.emit()
		var receipt := oracle.act({"kind": "look_back", "actor": oracle.snapshot().viewpoint}, oracle.snapshot())
		_check(stage.receipts.back() == receipt and stage.expected.looking_back and stage.expected.whirr == 5, "mounted LOOK BACK matches exact receipt")
		var visible_dolls := 0
		for index in stage.trailing.size():
			if stage.trailing[index].visible:
				visible_dolls += 1
				_check(stage.trailing[index].texture != null and stage.rank_labels[index].text.begins_with("Rank " + str(index + 1)), "trailing doll art retains real ranks")
		_check(visible_dolls == 3, "exactly three other dolls visible on look-back")
		stage.candle = 0
		stage.refresh()
		_check(stage.readout.text.contains("snuffed") and stage.trailing[3].modulate.a < 0.2, "candle band fades distant dolls")
		stage.candle = 78
		stage.refresh()
		_check(stage.trailing[3].modulate.a == 1.0, "bright candle restores trailing visibility")
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
		stage.target_picker.select(0)
		for slot in [0, 0]:
			var actor: String = oracle.snapshot().viewpoint
			stage.pocket_buttons[slot].pressed.emit()
			receipt = oracle.act({"kind": "use_item", "actor": actor, "slot": slot, "target": actor}, oracle.snapshot())
			_check(receipt.ok and stage.receipts.back() == receipt and receipt.events[0].kind == "heal", "mounted healing pockets reflect exact HP and WHIRR receipts")
		_check(stage.pocket_buttons[0].disabled and stage.expected.pockets[stage.expected.viewpoint].is_empty(), "consumed items leave empty pockets")
		stage.forward_button.pressed.emit()
		receipt = oracle.act({"kind": "forward", "actor": oracle.snapshot().viewpoint}, oracle.snapshot())
		_check(stage.receipts.back() == receipt and stage.travel != null and stage.travel.is_running(), "ordinary forward creates travel tween after exact S8a action")
		stage.set_reduced_motion(true)
		_check(stage.travel == null and stage.layers[2].position == StitchedWalkScreen.VIEW.position and stage.layers[2].scale == Vector2.ONE, "reduced motion immediately finishes travel geometry")
		while stage.expected.phase == "walking":
			stage.forward_button.pressed.emit()
			receipt = oracle.act({"kind": "forward", "actor": oracle.snapshot().viewpoint}, oracle.snapshot())
			_check(stage.receipts.back() == receipt and stage.travel == null, "reduced forward immediate and authoritative")
		_check(stage.forward_button.disabled and stage.back_button.disabled, "finished walk disables movement")
		_reject(stage, "forward", {})
		_check(stage.expected.pending.is_empty() and stage.expected.rng == random.state, "no curio or horror resolution or action RNG draws")
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
	await _deferred_items()
	var source := FileAccess.get_file_as_string("res://scripts/stitched/walk/stitched_walk_screen.gd")
	for forbidden in ["func _draw", "draw_", "StyleBoxFlat.new", "GradientTexture", "GPUParticles", "randi()", "randomize()"]:
		_check(not source.contains(forbidden), "screen has no generated art or unseeded RNG " + forbidden)
	for failure in failures:
		printerr(failure)
	print("stitched_s8b_walk_screen_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


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
	_check(stage.target_picker.item_count > 4, "current object exposed as anonymous target")
	stage.target_picker.select(4)
	stage.pocket_buttons[0].pressed.emit()
	_check(stage.receipts.back().ok and stage.expected.pending.back().kind == "pins" and not stage.expected.pending.back().consumed, "mounted pins queues current-instance effect")
	stage.target_picker.select(0)
	stage.pocket_buttons[0].pressed.emit()
	_check(stage.receipts.back().ok and stage.expected.pending.back().kind == "spare_spool", "mounted spare spool queues receipt")
	_check(stage.expected.pending.size() == 4 and stage.expected.dolls == pristine_dolls and stage.expected.whirr == 30, "deferred items never resolve horrors, HP, ranks or fray")
	for pending in stage.expected.pending:
		_check(not pending.consumed, "pending effects left for later stages")
	stage.free()
