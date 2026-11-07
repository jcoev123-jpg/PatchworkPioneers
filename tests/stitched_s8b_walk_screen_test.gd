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


## Compare the mounted HUD with the authority, not a view-local estimate.
func _assert_hud(stage: StitchedWalkScreen) -> void:
	_check(stage.walk != null and not stage.expected.is_empty(), "HUD has authoritative mounted Walk")
	if stage.walk == null or stage.expected.is_empty():
		return
	var snapshot := stage.walk.snapshot()
	var band := StitchedS1BEffects.candle_band(stage.candle)
	var wren_fear := stage.fear()
	_check(snapshot == stage.expected, "HUD projects current authoritative snapshot")
	_check(stage.readout.text.contains(str(snapshot.corridor.name))
		and stage.readout.text.contains("Step %d/%d" % [snapshot.step, snapshot.corridor.steps]),
		"corridor and actual step/total separately legible")
	_check(stage.eye_readout.text.contains("eyes") and stage.eye_readout.text.contains(stage.eye_profile.replace("_", " ")),
		"equipped eye treatment still labelled")
	_check(stage.whirr_readout.text == "WHIRR %d/100" % snapshot.whirr
		and is_equal_approx(stage.whirr_meter.value, float(snapshot.whirr) / 100.0),
		"WHIRR caption and image-backed meter equal real Walk")
	_check(stage.candle_readout.text == "CANDLE %d / %s" % [stage.candle, str(band.name).to_upper()]
		and is_equal_approx(stage.candle_meter.value, float(stage.candle) / 100.0),
		"candle caption and image-backed meter use shared band service")
	_check(stage.fear_readout.text == "WREN FEAR %d/100" % wren_fear
		and is_equal_approx(stage.fear_meter.value, float(wren_fear) / 100.0),
		"live fear caption and image-backed meter use actual fear source")
	_check(stage.hud_panels.size() == 4, "four independent sewn panels are mounted")
	for panel in stage.hud_panels:
		_check(panel.texture != null and panel is NinePatchRect and panel.focus_mode == Control.FOCUS_ALL
			and panel.tooltip_text.length() > 8, "authored fabric panel has accessible numerical detail")
		_check(panel.get_global_rect().position.y >= 16 and panel.get_global_rect().end.y <= StitchedWalkScreen.VIEW.position.y,
			"top fabric panel fits above uninterrupted eye view")
	for meter in [stage.whirr_meter, stage.candle_meter, stage.fear_meter]:
		_check(meter.get_theme_stylebox("background") is StyleBoxTexture
			and meter.get_theme_stylebox("fill") is StyleBoxTexture
			and not meter.tooltip_text.is_empty(), "sewn meter uses authored textures and accessible state")
		_check(stage.get_node(meter.name + "SewnFrame") is NinePatchRect
			and stage.get_node(meter.name + "SewnFrame").texture != null,
			"real bar has an image-backed stitched frame")
	for caption in [stage.readout, stage.eye_readout, stage.whirr_readout, stage.candle_readout, stage.fear_readout]:
		_check(caption.get_theme_font_size("font_size") >= 18 and not caption.text.is_empty(),
			"numerical text stays at least 18px and populated")
		_check(caption.get_global_rect().end.y <= StitchedWalkScreen.VIEW.position.y,
			"caption never paints over 920x440 first-person picture")
		var font: Font = caption.get_theme_font("font")
		_check(font.get_string_size(caption.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			caption.get_theme_font_size("font_size")).x <= caption.size.x,
			"numerical and corridor captions genuinely fit without horizontal clipping")
	_check(stage.readout.tooltip_text.contains(str(snapshot.corridor.name))
		and stage.hud_panels[1].tooltip_text.contains("%d/100" % snapshot.whirr)
		and stage.hud_panels[2].tooltip_text.contains("%d/100" % stage.candle)
		and stage.hud_panels[3].tooltip_text.contains("%d/100" % wren_fear),
		"focusable status plates disclose full numerical state")


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
		_check(stage.layers.size() == 3 and stage.trailing.size() == 4 and stage.switch_buttons.size() == 4, "nonempty mounted layer and rank controls")
		_assert_hud(stage)
		_check(stage.forward_button.tooltip_text.contains("+0") and stage.back_button.tooltip_text.contains("+5"), "active movement explains actual WHIRR costs")
		_check(stage.pocket_buttons[0].tooltip_text.contains("+5") and stage.pocket_buttons[1].tooltip_text.contains("+15") and stage.pocket_buttons[1].tooltip_text.contains("35%"), "fresh stuffing disclosed only from inspected pocket")
		for button in stage.switch_buttons:
			_check(button.disabled or button.tooltip_text.contains("+5"), "legal Switch explains +5 and disabled offers no false cost")
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
		_assert_hud(stage)
		var visible_dolls := 0
		for index in stage.trailing.size():
			if stage.trailing[index].visible:
				visible_dolls += 1
				_check(stage.trailing[index].texture != null and stage.rank_labels[index].text.begins_with("Rank " + str(index + 1)), "trailing doll art retains real ranks")
		_check(visible_dolls == 3 and stage.shadow_picture.visible == oracle.shadow_visible(), "three real trailing dolls plus only scheduled shadow")
		stage.candle = 0
		stage.refresh()
		_check(stage.candle_readout.text.contains("0 / SNUFFED") and stage.trailing[3].modulate.a < 0.2, "actual zero SNUFFED band fades distant dolls")
		_assert_hud(stage)
		stage.candle = 78
		stage.refresh()
		_check(stage.trailing[3].modulate.a == 1.0, "bright candle restores trailing visibility")
		_assert_hud(stage)
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
			_check(stage.expected.whirr == oracle.snapshot().whirr and stage.whirr_meter.value == float(stage.expected.whirr) / 100.0, "SWITCH +5 updated true WHIRR meter")
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
		for cost in [5, 15]:
			var actor: String = oracle.snapshot().viewpoint
			var previous_whirr: int = stage.expected.whirr
			_check(stage.pocket_buttons[0].tooltip_text.contains("+%d" % cost), "current valid pocket discloses real item cost")
			stage.pocket_buttons[0].pressed.emit()
			receipt = oracle.act({"kind": "use_item", "actor": actor, "slot": 0, "target": actor}, oracle.snapshot())
			_check(receipt.ok and stage.receipts.back() == receipt and receipt.events[0].kind == "heal" and stage.expected.whirr == previous_whirr + cost, "mounted pocket receipt has exact +5 or +15 and real healing")
			_assert_hud(stage)
		_check(stage.pocket_buttons[0].disabled and stage.expected.pockets[stage.expected.viewpoint].is_empty(), "consumed items leave empty pockets")
		stage.forward_button.pressed.emit()
		receipt = oracle.act({"kind": "forward", "actor": oracle.snapshot().viewpoint}, oracle.snapshot())
		_check(stage.receipts.back() == receipt and stage.travel != null and stage.travel.is_running(), "ordinary forward creates travel tween after exact S8a action")
		_check(stage.expected.whirr == oracle.snapshot().whirr and stage.forward_button.tooltip_text.contains("+0"), "FORWARD spends exactly zero WHIRR")
		_assert_hud(stage)
		stage.set_reduced_motion(true)
		_check(stage.travel == null and stage.layers[2].position == StitchedWalkScreen.VIEW.position and stage.layers[2].scale == Vector2.ONE, "reduced motion immediately finishes travel geometry")
		while stage.expected.phase == "walking":
			stage.forward_button.pressed.emit()
			receipt = oracle.act({"kind": "forward", "actor": oracle.snapshot().viewpoint}, oracle.snapshot())
			_check(stage.receipts.back() == receipt and stage.travel == null, "reduced forward immediate and authoritative")
		_check(stage.forward_button.disabled and stage.back_button.disabled, "finished walk disables movement")
		_reject(stage, "forward", {})
		_check(stage.forward_button.tooltip_text.is_empty() and stage.back_button.tooltip_text.is_empty() and stage.pocket_buttons[0].tooltip_text.is_empty(), "completed or disabled actions never advertise payable costs")
		_assert_hud(stage)
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
	await _thresholds_and_passivity()
	await _curio_cost_mount()
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
		_check(stage.shadow_picture.visible == stage.expected.shadow.present, "real URL LOOK BACK reaches seeded reveal")
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
		var visible := int(stage.shadow_picture.visible)
		for picture in stage.trailing:
			visible += int(picture.visible)
		_check(visible == (4 if present else 3), "only seeded shadow shows four trailing figures")
		_check(stage.snip_button.visible == present and stage.clue.visible == present, "SNIP and clue only for shadow")
		if present:
			_check(stage.shadow_picture.texture != null and stage.shadow_label.text.contains("Loose seam"), "authored fallback and distinct stitched clue mounted")
			for doll in stage.expected.dolls:
				if doll.id == stage.expected.shadow.disguise:
					_check(stage.shadow_label.text.begins_with("Rank %d - %s" % [doll.rank, doll.name]), "extra doll uses actual disguised rank and name")
			for index in [1, 2, 3]:
				stage.switch_buttons[index].pressed.emit()
				stage.back_button.pressed.emit()
				_check(stage.clue.visible and not stage.clue.text.is_empty(), "all eye profiles retain readable clue")
				if index == 1:
					_check(stage.clue.text.contains("seams"), "glass eyes expose seams")
				if index == 3:
					_check(stage.clue.text.contains("breathing"), "stitched ears hear breathing")
			_check(stage.snip_picker.item_count == 4, "three real targets and extra doll")
			for control in [stage.snip_picker, stage.snip_button]:
				_check(control.is_visible_in_tree() and control.focus_mode == Control.FOCUS_ALL
					and Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(control.get_global_rect()), "SNIP reachable by mouse and keyboard")
			stage.snip_picker.grab_focus()
			_check(stage.snip_picker.has_focus(), "SNIP target picker accepts keyboard focus")
			stage.snip_button.grab_focus()
			_check(stage.snip_button.has_focus() and stage.snip_button.tooltip_text.contains("+5"), "SNIP action accepts focus with exact cost")
			stage.snip_picker.select(3)
			stage.snip_button.pressed.emit()
			_check(stage.receipts.back().ok and stage.expected.shadow.removed and not stage.shadow_picture.visible
				and not stage.snip_button.visible, "mounted SNIP delegates correct target and clears shadow")
		else:
			_reject(stage, "snip", {"target": "extra_thread_shadow"})
		stage.free()
	_check(witnesses[true] > 0 and witnesses[false] > 0, "non-vacuous shadow and ordinary public seeds")


func _thresholds_and_passivity() -> void:
	var stage := StitchedWalkScreen.new()
	_check(stage.begin(548), "threshold fixture uses real seeded Walk rules")
	if stage.walk == null:
		stage.free()
		return
	root.add_child(stage)
	await process_frame
	var random := RandomNumberGenerator.new()
	random.seed = 548
	var oracle := StitchedWalkRules.start(random, "walls", stage.expected.dolls, stage.expected.pockets, null, true)
	_check(oracle != null and oracle.snapshot() == stage.expected, "boundary oracle starts from same RNG snapshot")
	var pristine := stage.walk.snapshot()
	var receipt_count := stage.receipts.size()
	stage.refresh()
	stage.refresh()
	stage.hud_panels[1].grab_focus()
	_check(root.gui_get_focus_owner() == stage.hud_panels[1], "keyboard reaches passive WHIRR status")
	stage.forward_button.grab_focus()
	_check(root.gui_get_focus_owner() == stage.forward_button, "keyboard returns to forward")
	_check(stage.walk.snapshot() == pristine and stage.receipts.size() == receipt_count, "passive refresh and focus spend no WHIRR, RNG, items or journal")
	stage.preview_fear = 49
	stage.refresh()
	_check(not stage.flickering and not stage.is_processing() and stage.fear_warning.text.is_empty(), "fear 49 keeps stable image")
	_assert_hud(stage)
	stage.preview_fear = 50
	stage.refresh()
	_check(stage.flickering and stage.is_processing() and stage.fear_warning.text.contains("flickers"), "fear 50 triggers existing flicker and visible warning")
	_assert_hud(stage)
	var motion: CheckButton = stage.get_node("ReducedMotionToggle")
	motion.grab_focus()
	_check(motion.has_focus() and motion.focus_mode == Control.FOCUS_ALL and motion.get_global_rect().end.x <= 1280,
		"reduced-motion toggle remains keyboard and pointer reachable")
	motion.button_pressed = true
	_check(stage.flickering and not stage.is_processing() and stage.fear_warning.text.contains("suppressed")
		and stage.layers[0].modulate == stage._layer_tone, "reduced motion suppresses visual flicker but preserves fear signal")
	_check(stage.walk.snapshot() == pristine and stage.receipts.size() == receipt_count, "fear and reduced motion never write rules or consume RNG")
	for action in range(20):
		var before := stage.walk.snapshot()
		stage.back_button.pressed.emit()
		var receipt := oracle.act({"kind": "look_back", "actor": oracle.snapshot().viewpoint}, oracle.snapshot())
		_check(receipt.ok and stage.receipts.back() == receipt and stage.expected == oracle.snapshot()
			and stage.expected.whirr == mini(100, int(before.whirr) + 5), "accepted LOOK BACK increments exact rule-produced WHIRR")
		if action == 8:
			_check(stage.expected.whirr == 45 and stage.whirr_warning.text.is_empty(), "last reachable sub-50 WHIRR has no false warning")
		if action == 9:
			_check(stage.expected.whirr == 50 and stage.whirr_warning.text.contains("stirring")
				and receipt.events.any(func(event): return event.kind == "whirr_warning"), "WHIRR 50 shows real Machine stirring receipt")
			_assert_hud(stage)
		if action == 19:
			_check(stage.expected.whirr == 100 and stage.whirr_warning.text.contains("+1 foe")
				and stage.whirr_warning.text.contains("+10 fray")
				and receipt.events.any(func(event): return event.kind == "machine_pending"), "WHIRR 100 discloses actual extra foe and each doll's fray")
			_check(stage.whirr_warning.get_theme_font("font").get_string_size(stage.whirr_warning.text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, stage.whirr_warning.get_theme_font_size("font_size")).x <= stage.whirr_warning.size.x,
				"next-fight Machine warning fits inside top border without clipping")
			var machines: Array = stage.expected.pending.filter(func(event): return event.kind == "machine")
			_check(machines.size() == 1 and machines[0].effects.next_fight_extra_foes == 1
				and machines[0].effects.party_fray == 10, "actual rules schedule exactly one next-fight Machine effect")
			_assert_hud(stage)
	var at_cap := stage.walk.snapshot()
	stage.refresh()
	_reject(stage, "switch", {"target": "LOST"})
	_check(stage.walk.snapshot() == at_cap and stage.whirr_readout.text == "WHIRR 100/100", "invalid input at cap preserves real state and warning")
	stage.free()


func _curio_cost_mount() -> void:
	var stage: StitchedWalkScreen
	var chosen_seed := -1
	var target: Dictionary = {}
	for seed_number in range(548, 564):
		var candidate := StitchedWalkScreen.new()
		_check(candidate.begin(seed_number), "curio witness starts from valid seeded rules")
		for record in candidate.expected.curios:
			if record.step < candidate.expected.corridor.steps:
				stage = candidate
				chosen_seed = seed_number
				target = record.duplicate(true)
				break
		if stage != null:
			break
		candidate.free()
	_check(stage != null and chosen_seed >= 0 and not target.is_empty(), "legal authored curio witness is non-vacuous")
	if stage == null:
		return
	root.add_child(stage)
	await process_frame
	stage.set_reduced_motion(true)
	var random := RandomNumberGenerator.new()
	random.seed = chosen_seed
	var oracle := StitchedWalkRules.start(random, "walls", stage.expected.dolls, stage.expected.pockets, null, true)
	_check(oracle != null and oracle.snapshot() == stage.expected, "curio witness has independent authoritative oracle")
	while stage.expected.step < target.step:
		stage.forward_button.pressed.emit()
		var move := oracle.act({"kind": "forward", "actor": oracle.snapshot().viewpoint}, oracle.snapshot())
		_check(stage.receipts.back() == move and stage.expected == oracle.snapshot(), "curio witness reaches the actual step without WHIRR cost")
	var choices: Array = stage.walk.curio_choices(target.instance)
	_check(not choices.is_empty(), "authoritative curio has a lawful interaction")
	if choices.is_empty():
		stage.free()
		return
	var item_index := -1
	for index in stage.target_picker.item_count:
		if stage.target_picker.get_item_metadata(index) == target.instance:
			item_index = index
	_check(item_index >= 4 and stage.target_picker.get_item_text(item_index) == "Object on this step",
		"curio stays anonymous and does not reveal a mimic or object kind")
	if item_index >= 0:
		stage.target_picker.select(item_index)
		stage.target_picker.item_selected.emit(item_index)
		_check(stage.target_picker.tooltip_text.contains("Curio interactions cost WHIRR +5"),
			"current anonymous curio displays exact legal interaction cost")
	var before := stage.walk.snapshot()
	var action := {"kind": "curio", "actor": before.viewpoint, "target": target.instance, "choice": choices[0]}
	var result := stage.command("curio", {"target": target.instance, "choice": choices[0]})
	var predicted := oracle.act(action, oracle.snapshot())
	_check(result.ok and result == predicted and stage.receipts.back() == predicted
		and stage.expected.whirr == before.whirr + 5 and stage.expected == oracle.snapshot(),
		"accepted curio costs +5 with real receipt, no speculative HUD action")
	_assert_hud(stage)
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
	stage.target_picker.item_selected.emit(4)
	_check(stage.target_picker.tooltip_text.contains("Curio interactions cost WHIRR +5")
		and not stage.pocket_buttons[0].disabled and stage.pocket_buttons[0].tooltip_text.contains("+5"),
		"anonymous target picker and legal pins disclose +5 without revealing curio kind")
	stage.pocket_buttons[0].pressed.emit()
	_check(stage.receipts.back().ok and stage.expected.pending.back().kind == "pins" and not stage.expected.pending.back().consumed, "mounted pins queues current-instance effect")
	stage.target_picker.select(0)
	stage.pocket_buttons[0].pressed.emit()
	_check(stage.receipts.back().ok and stage.expected.pending.back().kind == "spare_spool", "mounted spare spool queues receipt")
	_check(stage.expected.pending.size() == 4 and stage.expected.dolls == pristine_dolls and stage.expected.whirr == 30, "deferred items never resolve horrors, HP, ranks or fray")
	for pending in stage.expected.pending:
		_check(not pending.consumed, "pending effects left for later stages")
	stage.free()
