extends SceneTree
## Real routed Event scene: deterministic authored-image motion, choice invariance
## and a retired/rearmed single inert layer. No event catalog dependency.
const PANEL_SCENE := preload("res://scenes/event_choice_panel.tscn")
const AMBIENT := preload("res://scripts/live_battle_ambient.gd")
const ART := "res://assets/paper/backgrounds/event_crossroads.png"

var failures: Array[String] = []
var checks := 0
var panel: LiveEventChoicePanel
var legacy: Array[Dictionary] = []
var wallet_receipts: Array[Dictionary] = []
var vital_receipts: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


func _frames() -> void:
	for i in range(4):
		await process_frame


func _event(vitals := false) -> Dictionary:
	var entries := [
		{"id": "mend", "text": "Mend the soft signposts",
			"outcome": {"gold": -3, "scraps": 2}},
		{"id": "wait", "text": "Watch the dusk settle",
			"outcome": {"gold": 0, "scraps": 0}},
		{"id": "toll", "text": "Pay the too costly toll",
			"outcome": {"gold": -99, "scraps": 0}},
	]
	if vitals:
		entries = [
			{"id": "mend", "text": "Stitch a soft wound",
				"outcome": {"gold": -3, "scraps": 2, "hp": 3, "max_hp": 0}},
			{"id": "wait", "text": "Watch the dusk settle",
				"outcome": {"gold": 0, "scraps": 0, "hp": 0, "max_hp": 0}},
			{"id": "toll", "text": "Pay the too costly toll",
				"outcome": {"gold": -99, "scraps": 0, "hp": -99, "max_hp": 0}},
		]
	return {"id": "test_embroidered_crossroads", "title": "The Embroidered Crossroads",
		"description": "The stitched evening sways above a quiet three-way trail. Every word stays inked on the parchment.",
		"choices": entries}


func _open(mode: String) -> bool:
	var event := _event(mode == "vital")
	_check(RunEventChoice.new(event).is_valid(), mode + " synthetic service record validates")
	var ok := false
	match mode:
		"legacy":
			ok = panel.open_event(event)
		"wallet":
			ok = panel.open_event_with_wallet(event, {"gold": 9, "scraps": 3})
		"vital":
			ok = panel.open_event_with_vitals(event,
				{"gold": 9, "scraps": 3, "hero": {"id": "mallow", "hp": 14, "max_hp": 20}})
	_check(ok, mode + " genuine mounted event opens")
	return ok


func _pointer(button: Button) -> void:
	var at := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	root.push_input(motion, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = at
		event.pressed = down
		root.push_input(event, true)
	await _frames()


func _key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		root.push_input(event, true)
	await _frames()


func _layer_count() -> int:
	return panel.find_children("LiveBattleAmbient", "Control", true, false).size()


func _state() -> Array:
	var buttons := []
	for b in panel.get_choice_buttons():
		buttons.append([b, b.text, b.tooltip_text, b.disabled, b.get_global_rect(),
			b.focus_mode, b.get_index()])
	return [panel.title_label.text, panel.description_label.text, buttons,
		panel.paper_panel.get_global_rect(), panel.story_scroll.get_global_rect(),
		panel._selector.get_event(), panel._offered_wallet.duplicate(true),
		panel._wallet_previews.duplicate(true), panel._offered_snapshot.duplicate(true),
		panel._vital_previews.duplicate(true),
		panel._wallet_label.text if is_instance_valid(panel._wallet_label) else "",
		panel._vital_label.text if is_instance_valid(panel._vital_label) else "",
		root.gui_get_focus_owner()]


func _assert_layer(label: String) -> void:
	var layer = panel.event_ambient
	_check(_layer_count() == 1 and is_instance_valid(layer), label + " exactly one layer")
	if not is_instance_valid(layer):
		return
	_check(layer.get_parent() == panel and layer.get_index() == panel.backdrop_art.get_index() + 1
		and layer.get_index() < panel.paper_panel.get_index(),
		label + " after crossroads backdrop and under original paper")
	_check(layer.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and layer.focus_mode == Control.FOCUS_NONE and layer.get_child_count() == 0,
		label + " no input, focus or generated child particles")
	_check(layer.profile == "scraps" and layer._visit_dressing and layer.fast
		and layer.visible_budget() == AMBIENT.FAST_MOTIFS
		and layer.self_modulate.a < 0.5 and layer.is_processing(),
		label + " quiet seven-mote authored scraps profile running")
	_check(layer.get_global_rect() == panel.backdrop_art.get_global_rect(),
		label + " renderer fits background without moving paper")
	_check(layer.felt_texture != null and layer.light_texture != null
		and layer.fluff_texture != null and layer.wisp_texture != null
		and (layer.vignette_texture != null) == ResourceLoader.exists(AMBIENT.VIGNETTE_PATH),
		label + " uses the four shipped PNGs and optionally the absent vignette")
	var marks: Array = layer.motif_metadata()
	_check(marks.size() == AMBIENT.FAST_MOTIFS
		and layer.added_metadata().size() == (4 if layer.vignette_texture != null else 3),
		label + " deterministic textured motif and drift metadata")
	for mark in marks:
		_check(Rect2(Vector2.ZERO, layer.size).encloses(mark["rect"]),
			label + " motif remains within 1280x720 picture")
	_check(panel.paper_panel.get_global_rect().size.x > 100.0
		and panel.paper_panel.get_global_rect().size.y > 80.0,
		label + " actual paper is legible-sized and unchanged")


## Inspect the real sewn StyleBoxTexture, not a simulated copy of its state.
func _ticket_face(button: Button) -> StyleBoxTexture:
	return button.get_theme_stylebox("normal") as StyleBoxTexture


func _move_pointer_to(control: Control) -> void:
	var move := InputEventMouseMotion.new()
	move.position = control.get_global_rect().get_center()
	root.push_input(move, true)
	await _frames()


func _ticket_motion(mode: String, buttons: Array[Button]) -> void:
	_check(ResourceLoader.exists("res://assets/paper/ui/reward_button.png"),
		mode + " shipped ticket art exists for image-only test")
	var face0 := _ticket_face(buttons[0])
	var face1 := _ticket_face(buttons[1])
	var face2 := _ticket_face(buttons[2])
	_check(face0 != null and face1 != null and face2 != null,
		mode + " mounted art-backed controls have sewn surfaces")
	if face0 == null or face1 == null or face2 == null:
		return
	var before := _state()
	var start_alpha := face0.modulate_color.a
	_check(is_equal_approx(start_alpha, panel.TICKET_START_ALPHA)
		and is_equal_approx(face2.modulate_color.a, start_alpha)
		and face0.expand_margin_top <= 2.0,
		mode + " real tickets start visible, all backing fade/offset only")
	_check(panel._ticket_clock == 0.0 and panel.get_choice_cues().size() == 3,
		mode + " fresh phase has three inert cues")
	panel._advance_ticket_motion(0.12)
	_check(face0.modulate_color.a > face1.modulate_color.a
		and face1.modulate_color.a >= face2.modulate_color.a
		and face0.modulate_color.a > start_alpha and face2.modulate_color.a < 1.0,
		mode + " middle alpha settles in original authored ticket order")
	_check(face0.expand_margin_top < 1.5 and face2.expand_margin_top <= 2.0,
		mode + " stagger moves only <2px backing ink")
	panel._advance_ticket_motion(0.25)
	_check(is_equal_approx(face0.modulate_color.a, 1.0)
		and is_equal_approx(face1.modulate_color.a, 1.0)
		and is_equal_approx(face2.modulate_color.a, 1.0)
		and is_zero_approx(face0.expand_margin_top)
		and is_zero_approx(face2.expand_margin_top),
		mode + " third backing finishes by .33s, no leftover reveal")
	_check(_state() == before, mode + " all text, button rects, order, prices, tooltips, selection and focus unchanged")
	# Both keyboard focus and real pointer motion feed this same inert art.
	buttons[0].grab_focus()
	panel._advance_ticket_motion(0.16)
	_check(buttons[0].has_focus() and face0.modulate_color.r > 1.0
		and face0.modulate_color.r <= 1.05
		and face0.expand_margin_top <= 2.0,
		mode + " focus highlights only normal authored backing within 5% / 2px")
	buttons[0].release_focus()
	await _move_pointer_to(panel.description_label)
	panel._advance_ticket_motion(0.16)
	_check(is_equal_approx(face0.modulate_color.r, 1.0)
		and is_zero_approx(face0.expand_margin_top),
		mode + " keyboard emphasis returns exactly to rest")
	await _move_pointer_to(buttons[1])
	panel._advance_ticket_motion(0.16)
	_check(buttons[1].is_hovered()
		and face1.modulate_color.r > 1.0 and face1.modulate_color.r <= 1.05,
		mode + " physical hover brightens a real enabled ticket")
	await _move_pointer_to(panel.description_label)
	panel._advance_ticket_motion(0.16)
	_check(is_equal_approx(face1.modulate_color.r, 1.0),
		mode + " mouse exit returns normal backing to rest")
	if mode != "legacy":
		await _move_pointer_to(buttons[2])
		panel._advance_ticket_motion(0.18)
		var disabled_skin := buttons[2].get_theme_stylebox("disabled") as StyleBoxTexture
		_check(buttons[2].disabled and buttons[2].focus_mode == Control.FOCUS_NONE
			and not buttons[2].has_focus() and disabled_skin != null
			and is_equal_approx(disabled_skin.modulate_color.r, 0.94)
			and is_zero_approx(disabled_skin.expand_margin_top),
			mode + " unaffordable ticket cannot glow or take focus even under pointer")
		await _move_pointer_to(panel.description_label)


func _mode(mode: String, activation: String) -> void:
	if not _open(mode):
		return
	# Freeze only the new ticket clock; the independent ambient still processes.
	panel.set_process(false)
	await _frames()
	_assert_layer(mode)
	var buttons := panel.get_choice_buttons()
	_check(buttons.size() == 3 and panel.get_choice_cues().size() == 3,
		mode + " three numbered true buttons")
	if buttons.size() != 3:
		panel.close_event()
		return
	_check(buttons[0].is_visible_in_tree() and not buttons[0].disabled
		and (mode == "legacy" or buttons[2].disabled),
		mode + " enabled and unavailable controls are authentic")
	await _ticket_motion(mode, buttons)
	buttons[0].grab_focus()
	await _frames()
	var before := _state()
	var layer = panel.event_ambient
	var start_clock: float = layer._time
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = 91263
	var rng_state: int = local_rng.state
	seed(21634)
	var next_global := randi()
	seed(21634)
	for tick in range(5):
		layer._process(0.31)
		layer.queue_redraw()
	await _frames()
	_check(layer._time > start_clock and layer.motif_metadata() != AMBIENT.motifs_for(
		"scraps", layer.size, 0.0, true),
		mode + " elapsed visual-only clock updates authored PNG metadata")
	_check(_state() == before and local_rng.state == rng_state
		and randi() == next_global, mode + " text, positions, focus, receipts and RNG fixed")
	_check(root.gui_get_focus_owner() == buttons[0], mode + " ambient never grabs focus")
	var count_before := legacy.size() + wallet_receipts.size() + vital_receipts.size()
	# Missing/unavailable choices cannot be spent even if their signals are forged.
	if mode != "legacy":
		buttons[2].pressed.emit()
		await _key(KEY_3)
		_check(legacy.size() + wallet_receipts.size() + vital_receipts.size() == count_before
			and panel._selector.is_valid(), mode + " unaffordable third choice fails closed")
	buttons[1].hide()
	buttons[1].pressed.emit()
	await _key(KEY_2)
	_check(legacy.size() + wallet_receipts.size() + vital_receipts.size() == count_before
		and panel._selector.is_valid(), mode + " hidden choice fails closed")
	buttons[1].show()
	match activation:
		"pointer":
			await _pointer(buttons[0])
		"key1":
			await _key(KEY_1)
		"key2":
			await _key(KEY_2)
	_check(legacy.size() + wallet_receipts.size() + vital_receipts.size() == count_before + 1
		and panel._selector.is_claimed(), mode + " one real " + activation + " claim")
	_check((legacy.back().get("choice_id") if mode == "legacy" else
		(wallet_receipts.back().get("choice_id") if mode == "wallet" else
		vital_receipts.back().get("choice_id"))) == ("wait" if activation == "key2" else "mend"),
		mode + " exact authored choice ID committed")
	for b in buttons:
		b.pressed.emit()
	await _key(KEY_1)
	_check(legacy.size() + wallet_receipts.size() + vital_receipts.size() == count_before + 1,
		mode + " no replay from keyboard or pressed callback")
	panel.close_event()
	panel.set_process(true)
	await _frames()
	_check(not panel.visible and not panel.has_open_event()
		and panel.get_choice_buttons().is_empty() and layer.profile.is_empty()
		and not layer.is_processing() and not layer.visible and layer._time == 0.0,
		mode + " close retires layer and clears choices")


func _two_choice_motion() -> void:
	var event := _event()
	(event["choices"] as Array).resize(2)
	_check(RunEventChoice.new(event).is_valid(), "short two-choice service fixture is valid")
	_check(panel.open_event(event), "real short two-choice scene opens")
	panel.set_process(false)
	await _frames()
	var buttons := panel.get_choice_buttons()
	_check(buttons.size() == 2 and panel.get_choice_cues().size() == 2,
		"two authored buttons and exactly two numbered noninteractive cues")
	if buttons.size() == 2:
		var rects := [buttons[0].get_global_rect(), buttons[1].get_global_rect()]
		var alpha0 := _ticket_face(buttons[0]).modulate_color.a
		panel._advance_ticket_motion(0.16)
		_check(_ticket_face(buttons[0]).modulate_color.a > alpha0
			and _ticket_face(buttons[1]).modulate_color.a < 1.0,
			"two tickets stagger before settling")
		panel._advance_ticket_motion(0.2)
		_check(is_equal_approx(_ticket_face(buttons[1]).modulate_color.a, 1.0)
			and buttons[0].get_global_rect() == rects[0]
			and buttons[1].get_global_rect() == rects[1],
			"two-choice settle leaves both authentic hitboxes fixed")
		var before := legacy.size()
		await _key(KEY_3)
		_check(legacy.size() == before and panel._selector.is_valid(),
			"missing third ticket's physical key still cannot claim")
		await _key(KEY_2)
		_check(legacy.size() == before + 1 and legacy.back().choice_id == "wait",
			"two-choice second ticket remains the real settled callback")
	panel.close_event()
	panel.set_process(true)
	await _frames()


func _lifecycle() -> void:
	if not _open("legacy"):
		return
	await _frames()
	var layer = panel.event_ambient
	var rect := panel.paper_panel.get_global_rect()
	panel.hide()
	await _frames()
	_check(panel._ticket_suspended and panel._ticket_clock == 0.0
		and is_equal_approx(_ticket_face(panel.get_choice_buttons()[0]).modulate_color.a, 1.0),
		"hide settles ticket image clock immediately")
	_check(layer.profile.is_empty() and layer._time == 0.0 and not layer.is_processing(),
		"explicit hide stops/retire the ambient clock")
	panel.show()
	await _frames()
	_check(panel._ticket_suspended
		and is_equal_approx(_ticket_face(panel.get_choice_buttons()[0]).modulate_color.a, 1.0),
		"hide/show never leaves a stale fade or replays a half-complete ticket")
	_check(panel.event_ambient == layer and layer.profile == "scraps" and layer._time >= 0.0
		and _layer_count() == 1, "show rearms same renderer: profile=%s time=%s count=%d visible=%s tree=%s" % [layer.profile, layer._time, _layer_count(), panel.visible, panel.is_visible_in_tree()])
	panel.set_ambient_reduced_motion_override(true)
	_check(layer.profile.is_empty() and layer._time == 0.0 and not layer.is_processing(),
		"test override immediately fully retires animation")
	panel.set_ambient_reduced_motion_override(false)
	_check(layer.profile == "scraps" and _layer_count() == 1,
		"test override restores one existing renderer")
	ProjectSettings.set_setting("accessibility/reduced_motion", true)
	panel.set_ambient_reduced_motion_override(null)
	_check(not layer.is_processing() and layer.profile.is_empty(),
		"ProjectSettings reduced motion independently stops visit effects")
	ProjectSettings.set_setting("accessibility/reduced_motion", false)
	panel.set_ambient_reduced_motion_override(null)
	_check(layer.profile == "scraps" and layer.is_processing(),
		"project setting re-enables authored-image motion")
	panel.bind_event_backdrop("res://assets/paper/backgrounds/not_present_crossroads.png")
	_check(panel.backdrop_art.texture == null and not panel.backdrop_art.visible
		and layer.profile.is_empty() and not layer.is_processing()
		and panel.get_node("SlateBackdrop").visible and panel.paper_panel.visible
		and panel.get_choice_buttons().size() == 3,
		"missing-art fallback retains slate, paper and exact offering without animation")
	panel.bind_event_backdrop("res://assets/paper/backgrounds/battle_meadow.png")
	_check(panel.backdrop_art.texture != null and layer.profile == "scraps"
		and panel.event_ambient == layer and _layer_count() == 1 and layer._time == 0.0,
		"replacement with another existing backdrop resets same texture renderer")
	panel.bind_event_backdrop()
	_check(panel.backdrop_art.texture != null and layer.profile == "scraps"
		and _layer_count() == 1 and layer._time == 0.0,
		"rebinding shipped crossroads art rearms same clock at start")
	_check(panel.paper_panel.get_global_rect() == rect,
		"backdrop and motion toggles never move paper hit rectangle")
	panel.get_parent().remove_child(panel)
	_check(layer.profile.is_empty() and not layer.is_processing(),
		"detached scene retires without leaving an active presentation")
	root.add_child(panel)
	await _frames()
	_check(panel.event_ambient == layer and _layer_count() == 1
		and panel.paper_panel != null, "restored panel keeps a single reusable layer")
	panel.close_event()
	await _frames()
	if _open("legacy"):
		panel.set_process(false)
		await _frames()
		_assert_layer("restored and reopened")
		_check(panel.event_ambient == layer and _layer_count() == 1
			and panel._ticket_clock == 0.0 and not panel._ticket_suspended,
			"reopen has one ambient renderer and a fresh, independent ticket phase")
		var ticket := _ticket_face(panel.get_choice_buttons()[0])
		_check(is_equal_approx(ticket.modulate_color.a, panel.TICKET_START_ALPHA),
			"reopen starts ticket fade from original alpha instead of previous state")
		panel.set_ambient_reduced_motion_override(true)
		panel._advance_ticket_motion(0.12)
		_check(layer.profile.is_empty() and ticket.modulate_color.a < 1.0
			and ticket.modulate_color.a > panel.TICKET_START_ALPHA,
			"ambient-only override stops backdrop without cancelling independent tickets")
		panel.set_ambient_reduced_motion_override(null)
		ProjectSettings.set_setting("accessibility/reduced_motion", true)
		panel.set_ambient_reduced_motion_override(null)
		panel._advance_ticket_motion(0.0)
		_check(panel._ticket_suspended and is_equal_approx(ticket.modulate_color.a, 1.0)
			and is_zero_approx(ticket.expand_margin_top)
			and not layer.is_processing(),
			"project reduced motion instantly settles mid-reveal even with zero delta")
		ProjectSettings.set_setting("accessibility/reduced_motion", false)
		panel._advance_ticket_motion(0.1)
		_check(is_equal_approx(ticket.modulate_color.a, 1.0)
			and is_zero_approx(ticket.expand_margin_top),
			"turning reduced motion back off cannot replay a partially spent fade")
		panel.close_event()
		panel.set_process(true)
		await _frames()
		_check(panel._ticket_clock == 0.0 and panel._ticket_focus_amount.is_empty()
			and panel.get_choice_cues().is_empty() and _layer_count() == 1,
			"close clears phase, focus cache and cues without duplicating ambient")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var had_setting := ProjectSettings.has_setting("accessibility/reduced_motion")
	var saved_setting: Variant = ProjectSettings.get_setting("accessibility/reduced_motion", false)
	ProjectSettings.set_setting("accessibility/reduced_motion", false)
	panel = PANEL_SCENE.instantiate()
	root.add_child(panel)
	panel.choice_committed.connect(func(e: String, c: String) -> void:
		legacy.append({"event_id": e, "choice_id": c}))
	panel.wallet_choice_committed.connect(func(receipt: Dictionary) -> void:
		wallet_receipts.append(receipt.duplicate(true)))
	panel.vital_choice_committed.connect(func(receipt: Dictionary) -> void:
		vital_receipts.append(receipt.duplicate(true)))
	await _frames()
	_check(ResourceLoader.exists(ART) and panel.backdrop_art.texture != null,
		"shipped crossroads PNG is actually available")
	_check(not panel.has_open_event() and not panel.visible and _layer_count() == 0,
		"closed initial scene has no active renderer")
	_check(AMBIENT.profile_for("Event", 5).is_empty(),
		"Event cannot be smuggled through the battle profile API")
	await _mode("legacy", "pointer")
	await _mode("wallet", "key1")
	await _mode("vital", "key2")
	await _two_choice_motion()
	await _lifecycle()
	panel.free()
	if had_setting:
		ProjectSettings.set_setting("accessibility/reduced_motion", saved_setting)
	else:
		ProjectSettings.clear("accessibility/reduced_motion")
	if failures.is_empty():
		print("live_event_ambient_motion_test: PASS (%d checks)" % checks)
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		printerr("live_event_ambient_motion_test: FAIL (%d/%d)" % [failures.size(), checks])
		quit(1)
