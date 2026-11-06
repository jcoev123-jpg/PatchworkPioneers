extends SceneTree
## S5: explicit regression entry retains authenticated Fight-or-toll Roadblock admission.
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)


func _spawn() -> Node:
	var app: Node = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	return app


func _no_run(app: Node) -> bool:
	return app.deck == null and app.run_map == null and app.run_rng == null \
		and app.party == null and app.enemies == null and app.battle_result == null \
		and app.run_deck.is_empty() and app.run_heroes.is_empty() \
		and app.session_gold == 0 and app.run_scraps == 0


func _key(number: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = number
	event.pressed = true
	return event


func _exercise(repetition: int) -> Dictionary:
	var app := _spawn()
	await process_frame
	_check(app.title_view.is_visible_in_tree() and not app.stitched_fight_button.is_visible_in_tree() \
		and app.stitched_fight_button.disabled and app.stitched_fight_button.focus_mode == Control.FOCUS_NONE \
		and app.stitched_fight_button.pressed.get_connections().is_empty() and _no_run(app),
		"ordinary title keeps Roadblock dormant and has no run")
	seed(804215)
	var expected_rng := randi()
	seed(804215)
	app._open_stitched_fight() # Explicit Roadblock regression entry.
	await process_frame
	var panel: LiveEventChoicePanel = app.stitched_event_panel
	var gate: RunV3FightEventGate = app.stitched_event_gate
	_check(panel != null and gate != null and gate.is_valid() \
		and app.stitched_fight_view == null and _no_run(app) \
		and not app.title_view.is_visible_in_tree(),
		"the explicit regression entry admits an authored offer without combat, deck, RNG or wallet")
	if panel == null or gate == null:
		app.free()
		await process_frame
		return {}
	var preview: Dictionary = gate.preview_choices({"gold": 0, "scraps": 0})
	var buttons := panel.get_choice_buttons()
	_check(panel.has_open_event() and panel.is_visible_in_tree() \
		and panel._wallet_mode and panel._selector.get_event() == gate.get_event() \
		and gate.get_event_id() == "v3_stitchline_roadblock" \
		and gate.get_fight_choice_id() == "break_barricade" \
		and preview.get("ok") == true and preview.get("choices", []).size() == 3 \
		and buttons.size() == 3 and panel._wallet_label != null,
		"mounted tickets match the gate's canonical Roadblock preview and zero-wallet caption")
	if buttons.size() != 3:
		app.free()
		await process_frame
		return {}
	_check(not buttons[0].disabled and buttons[0].focus_mode != Control.FOCUS_NONE \
		and buttons[1].disabled and buttons[1].focus_mode == Control.FOCUS_NONE \
		and not buttons[2].disabled and buttons[2].focus_mode != Control.FOCUS_NONE \
		and preview["choices"][0]["fight_request"] == {"node_type": "Fight"} \
		and preview["choices"][1]["affordable"] == false \
		and preview["choices"][2]["fight_request"] == {},
		"Fight and Leave are keyboard-usable; the authentic preview disables the toll")
	var selector: RunEventChoice = panel._selector
	var forged := {"ok": true, "event_id": "v3_stitchline_roadblock",
		"choice_id": "break_barricade", "wallet": {"gold": 0, "scraps": 0},
		"fight_request": {"node_type": "Boss"}}
	app._commit_stitched_roadblock(forged, weakref(panel), gate)
	app._commit_stitched_roadblock({"ok": true, "event_id": "v3_stitchline_roadblock",
		"choice_id": "leave", "wallet": {"gold": 0, "scraps": 0}}, weakref(panel), gate)
	panel._on_choice_pressed(selector, "break_barricade", panel._generation - 1, buttons[0])
	panel._on_choice_pressed(selector, "break_barricade", panel._generation, buttons[1])
	panel._on_choice_pressed(selector, "pay_road_toll", panel._generation, buttons[1])
	buttons[1].pressed.emit()
	panel._input(_key(KEY_2))
	app._open_route()
	_check(not app._open_stitched_fight() and not app._open_base() \
		and app.stitched_event_panel == panel and gate.is_valid() and not gate.is_claimed() \
		and not selector.is_claimed() and app.stitched_fight_view == null \
		and app.run_map == null and _no_run(app),
		"forged, wrong-button, stale-generation, unaffordable and concurrent route inputs fail closed")
	_check(randi() == expected_rng, "opening and rejecting the offer never draw global RNG")
	panel._input(_key(KEY_3))
	_check(app.stitched_event_panel == null and app.stitched_event_gate == null \
		and panel.has_open_event() == false and gate.is_claimed() \
		and app.stitched_fight_view == null and _no_run(app),
		"real keyboard Leave settles without spending or allocating a run")
	panel._on_choice_pressed(selector, "break_barricade", panel._generation, buttons[0])
	await process_frame
	_check(app.title_view.is_visible_in_tree() and app.stitched_fight_view == null \
		and app.get_viewport().gui_get_focus_owner() == app.base_button,
		"Leave frees the ticket panel and restores title keyboard focus")
	# Re-enter with the same title and obtain a fresh, still-unclaimed authority.
	seed(804216)
	var second_rng := randi()
	seed(804216)
	app._open_stitched_fight() # Explicit Roadblock regression entry.
	await process_frame
	var fight_panel: LiveEventChoicePanel = app.stitched_event_panel
	var fight_gate: RunV3FightEventGate = app.stitched_event_gate
	_check(fight_panel != null and fight_gate != null and fight_gate.is_valid() \
		and fight_gate != gate and app.stitched_fight_view == null and _no_run(app),
		"fresh title revisit receives an independent unclaimed bound gate")
	if fight_panel == null or fight_gate == null:
		app.free()
		await process_frame
		return {}
	var fight_buttons := fight_panel.get_choice_buttons()
	if fight_buttons.size() != 3:
		_check(false, "fresh Roadblock shows all three authentic choices")
		app.free()
		await process_frame
		return {}
	# A client-supplied Elite/Boss receipt is not admission even when the ID matches.
	var valid_shape := {"ok": true, "event_id": "v3_stitchline_roadblock",
		"choice_id": "break_barricade", "wallet": {"gold": 0, "scraps": 0}}
	fight_panel._committed_choice = valid_shape.duplicate(true)
	app._commit_stitched_roadblock(valid_shape, weakref(fight_panel), fight_gate)
	_check(not fight_gate.is_claimed() and app.stitched_fight_view == null \
		and _no_run(app), "a forged pre-commit UI receipt cannot start ordinary/Elite/Boss combat")
	fight_panel._committed_choice.clear()
	fight_buttons[0].pressed.emit()
	var stage: StitchedBattleScreen = app.stitched_fight_view
	_check(stage != null and fight_gate.is_claimed() and app.stitched_event_gate == null \
		and app.stitched_event_panel == null and not fight_panel.has_open_event() \
		and _no_run(app),
		"the first authenticated Fight retires the event before mounting battle")
	if stage == null:
		app.free()
		await process_frame
		return {}
	var before_duplicate := stage.battle.state_snapshot()
	var rng_duplicate := stage.battle.rng_state()
	fight_buttons[0].pressed.emit()
	fight_panel._on_choice_pressed(fight_panel._selector, "break_barricade",
		fight_panel._generation, fight_buttons[0])
	app._commit_stitched_roadblock(valid_shape, weakref(fight_panel), fight_gate)
	_check(app.stitched_fight_view == stage and stage.battle.state_snapshot() == before_duplicate \
		and stage.battle.rng_state() == rng_duplicate and _no_run(app),
		"double-clicks, duplicate receipts and stale ticket callbacks cannot create another battle")
	_check(randi() == second_rng, "authenticated title admission does not consume global RNG")
	_check(stage.is_visible_in_tree() and stage.battle.is_valid() \
		and stage.battle.get_heroes().size() == 4 and stage.battle.get_foes().size() == 3 \
		and stage._seat_buttons.size() == 8 and stage.battle.current_side() == "hero",
		"real seeded Floor 01 battle has four heroes, three foes and working rank controls")
	var start_state := stage.battle.state_snapshot()
	var start_rng := stage.battle.rng_state()
	_check(not app._open_stitched_fight() \
		and not app._begin_stitched_battle({"ok": true, "event_id": "v3_stitchline_roadblock",
			"choice_id": "break_barricade", "wallet": {"gold": 0, "scraps": 0},
			"fight_request": {"node_type": "Elite"}}, fight_gate) \
		and stage.battle.state_snapshot() == start_state \
		and stage.battle.rng_state() == start_rng and _no_run(app),
		"duplicate admission and claimed Elite escalation leave the active battle and RNG unchanged")
	var receipts_before := stage.receipts.size()
	stage._action_buttons["pass"].pressed.emit()
	_check(stage.receipts.size() > receipts_before \
		and stage.battle.state_snapshot() != start_state,
		"mounted Pass turn advances the authentic seeded combat controller")
	var after_action := stage.battle.state_snapshot()
	var after_rng := stage.battle.rng_state()
	for turn in range(80):
		if stage.battle.is_over() or stage.battle.current_side() != "hero":
			break
		stage._action_buttons["retreat"].pressed.emit()
	_check(stage.battle.is_over() and stage.battle.outcome() in ["retreated", "victory", "defeat"] \
		and stage._action_buttons["pass"].disabled,
		"mounted Retreat reaches the legitimate terminal battle state")
	var trace := {"before": start_state, "before_rng": start_rng,
		"after_action": after_action, "after_rng": after_rng,
		"receipts": stage.receipts.duplicate(true),
		"end": stage.battle.state_snapshot(), "outcome": stage.battle.outcome()}
	var old_stage := stage
	stage._action_buttons["exit"].pressed.emit()
	_check(not bool(old_stage.submit_pass().get("ok", false)),
		"Back retires old battle action authority before queued controls can act")
	await process_frame
	_check(app.stitched_fight_view == null and not is_instance_valid(old_stage) \
		and app.title_view.is_visible_in_tree() and _no_run(app) \
		and app.get_viewport().gui_get_focus_owner() == app.base_button,
		"Back restores the clean ordinary title and keyboard focus")
	app.free()
	await process_frame
	return trace


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var first: Dictionary = await _exercise(0)
	var replay: Dictionary = await _exercise(1)
	_check(not first.is_empty() and first == replay,
		"two independently mounted same-seed Roadblock fights replay state, RNG and receipts")
	for failure in failures:
		printerr(failure)
	print("stitched_s5_roadblock_live_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
