extends SceneTree
## Mounted S2 route regression: genuine rule-created heaps use one authored stage
## texture and the existing legal target/turn gates, not a replacement combat path.
const BOOT := preload("res://scripts/live_web_playtest_boot.gd")
const SCRAP := preload("res://assets/paper/stitched/icons/scrap_heap.png")
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures.append(description)


func _mount() -> Dictionary:
	var app: Node = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await process_frame
	var boot := root.get_node_or_null("LiveWebPlaytestBoot")
	_check(boot != null and BOOT.SCREENS.has("stitched_battle"),
		"precondition: public Stitched preview boot is mounted")
	if boot == null:
		return {"app": app, "screen": null}
	_check(await boot.enter_preview(app, "stitched_battle"),
		"public entry opens actual Stitched battle scene")
	await process_frame
	return {"app": app, "screen": boot.stitched_view}


func _no_change(stage: StitchedBattleScreen, before: Dictionary, rng: int,
		receipts: Array, description: String) -> void:
	_check(stage.battle.state_snapshot() == before and stage.battle.rng_state() == rng
		and stage.receipts == receipts, description)


func _mouse(node: Control) -> void:
	var position := node.get_global_rect().get_center()
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = position
		event.pressed = down
		root.push_input(event, true)
		await process_frame


func _enter(node: Control) -> void:
	node.grab_focus()
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.pressed = down
		root.push_input(event, true)
		await process_frame


func _visible_scraps(stage: StitchedBattleScreen) -> Array:
	var result: Array = []
	for scrap in stage._scrap_images.values():
		if scrap.visible:
			result.append(scrap)
	return result


func _inspect_geometry(stage: StitchedBattleScreen, rank: int, hp: int) -> void:
	var key := "foe_" + str(rank)
	var sprite: TextureRect = stage._scrap_images[key]
	var rect := sprite.get_global_rect()
	var plate: NinePatchRect = stage._foot_plates[key]
	_check(sprite.visible and sprite.is_visible_in_tree() and sprite.texture == SCRAP
		and SCRAP.get_width() == 128 and SCRAP.get_height() == 128
		and sprite.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		and sprite.focus_mode == Control.FOCUS_ALL
		and sprite.mouse_filter == Control.MOUSE_FILTER_STOP
		and _visible_scraps(stage).size() == 1,
		"one imported 128px scrap texture is visible with its own focusable input surface")
	_check(rect.size == Vector2(116, 116) and rect.position.y == 382
		and rect.end.y < plate.get_global_rect().position.y
		and plate.visible and plate.texture == load("res://assets/paper/ui/panel_felt.png")
		and plate.get_global_rect().size == Vector2(170, 50)
		and plate.get_global_rect().position.y == 505,
		"heap is smaller than figures, below intent air and above its real sewn footplate")
	_check(not stage._puppets[key].visible and not stage._figure_hits[key].visible
		and not stage._rank_meters[key]["root"].visible
		and not stage._foe_tickets[rank].visible
		and stage._foe_intents.get(rank, {}).is_empty()
		and stage._labels[key].visible and stage._labels[key].text == "SCRAP %d HP" % hp
		and stage._seat_buttons[key].visible
		and stage._seat_buttons[key].text.contains("Scrap heap")
		and not stage.status_detail("foe", rank).contains("FRAY")
		and stage.status_detail("foe", rank).contains("SCRAP %d HP" % hp),
		"heap has true HP and status only, no ghost puppet/hit/meter/intent")
	for foe_rank in range(1, 5):
		if foe_rank == rank:
			continue
		var puppet: Control = stage._puppets["foe_" + str(foe_rank)]
		if not puppet.visible:
			continue
		var art: Rect2 = puppet.posed_actor_rect()
		var figure_rect := Rect2(puppet.global_position + art.position, art.size)
		var crossing := rect.intersection(figure_rect)
		_check(crossing.size.x * crossing.size.y <= 0.15 * rect.size.x * rect.size.y,
			"heap cannot obscure adjacent living foe painted pixels at rank %d" % foe_rank)


func _create_real_heap(stage: StitchedBattleScreen) -> Dictionary:
	var battle := stage.battle
	var foe: Dictionary = stage._unit_at("foe", 1)
	_check(not foe.is_empty() and foe.get("side") == "foe" and int(foe.get("hp", 0)) > 0,
		"precondition: seeded preview has a living front foe to kill")
	if foe.is_empty():
		return {}
	var id := str(foe["id"])
	var generated: Dictionary = battle._kill_foe(battle._units[id])
	stage._refresh()
	var heap: Dictionary = stage._heap_at(1)
	_check(not heap.is_empty() and heap.get("foe_id") == id
		and int(heap.get("hp", -1)) == StitchedRules.heap_hp_for(int(foe["max_hp"]))
		and int(generated.get("hp", -1)) == int(heap.get("hp", -2))
		and stage._unit_at("foe", 1).is_empty(),
		"genuine rule kill generates the exactly-one-third blocking heap in vacated rank")
	if not heap.is_empty():
		_inspect_geometry(stage, 1, int(heap["hp"]))
	return heap


func _select_damage_part(stage: StitchedBattleScreen, rank: int) -> Dictionary:
	# Choose from actual equipped, untorn attacks and the rule's true heap target.
	var battle := stage.battle
	var selected: Dictionary = {}
	for hero in battle.get_heroes():
		for slot in StitchedBattleScreen.SLOTS:
			var worn: Dictionary = hero.get("parts", {}).get(slot, {})
			if not stage._valid_part(hero, worn):
				continue
			var part: Dictionary = stage.parts.get(str(worn.get("id", "")), {})
			if part.is_empty():
				continue
			var ability: Dictionary = StitchedParts.ability_at_tier(part, int(worn["tier"]))
			if int(ability.get("dmg", [0, 0])[1]) <= 0:
				continue
			var targets: Array = battle._legal_targets(hero, ability, rank)
			if not targets.is_empty() and str(targets[0].get("side", "")) == "heap":
				selected = {"hero": str(hero["id"]), "slot": slot, "part": str(worn["id"])}
				break
		if not selected.is_empty():
			break
	_check(not selected.is_empty(),
		"precondition: an equipped untorn real hero part legally attacks the rule-created heap")
	if selected.is_empty():
		return {}
	var next_id := ""
	for hero in battle.get_heroes():
		if str(hero["id"]) != selected["hero"]:
			next_id = str(hero["id"])
			break
	_check(not next_id.is_empty(), "precondition: another hero can inherit the spent turn")
	battle._order = [selected["hero"], next_id]
	battle._turn_index = 0
	stage._refresh()
	_check(battle.current_actor_id() == selected["hero"] and battle.current_side() == "hero"
		and stage.select_part(str(selected["slot"]))
		and stage.legal_targets().has("foe_" + str(rank))
		and not stage._target_buttons["foe_" + str(rank)].disabled,
		"mounted part selection projects real StitchedRules legal heap target")
	return selected


func _guarantee_seeded_hit(battle: StitchedRules) -> void:
	# Find a deterministic *local battle* seed whose first hit roll is <= 5,
	# the rules' minimum chance; never consume the global RNG during inspection.
	for candidate in range(1, 5000):
		var probe := RandomNumberGenerator.new()
		probe.seed = candidate
		if probe.randi_range(1, 100) <= 5:
			battle._rng.seed = candidate
			return
	_check(false, "precondition: found a fixed seed permitting a genuine heap hit")


func _verify_empty_and_inspection(stage: StitchedBattleScreen) -> void:
	var battle := stage.battle
	var empty: TextureRect = stage._scrap_images["foe_4"]
	_check(battle.get_heroes().size() == 4 and battle.get_foes().size() == 3
		and battle.current_side() == "hero" and not battle.is_over()
		and stage._scrap_images.size() == 4 and _visible_scraps(stage).is_empty()
		and not empty.visible and not stage._figure_hits["foe_4"].visible
		and not stage._foot_plates["foe_4"].visible
		and not stage._foe_tickets[4].visible
		and stage._puppets["foe_1"].visible and stage._figure_hits["foe_1"].visible
		and stage._rank_meters["foe_1"]["root"].visible
		and stage._foe_tickets[1].visible,
		"precondition: public 1280x720 stage is true 4v3 with empty fourth rank and live foe UI")
	var before := battle.state_snapshot()
	var rng := battle.rng_state()
	var receipts := stage.receipts.duplicate(true)
	await _mouse(empty)
	empty.gui_input.emit(_click_event())
	_no_change(stage, before, rng, receipts,
		"empty fourth-rank image is hidden and rejects even forced pointer callbacks")
	var heap := _create_real_heap(stage)
	if heap.is_empty():
		return
	var sprite: TextureRect = stage._scrap_images["foe_1"]
	var created := battle.state_snapshot()
	var created_rng := battle.rng_state()
	sprite.mouse_entered.emit()
	_check(stage._labels["log"].text == stage.status_detail("foe", 1)
		and stage._status_disclosure.visible and stage._status_disclosure_label.text.contains("SCRAP"),
		"hovering actual heap image shows the true scrap status in sewn disclosure")
	sprite.mouse_exited.emit()
	sprite.grab_focus()
	_check(sprite.has_focus() and stage._status_disclosure.visible
		and stage._status_disclosure_label.text.contains("SCRAP"),
		"keyboard focus on heap image exposes the same authoritative status")
	stage._action_buttons["pass"].grab_focus()
	_no_change(stage, created, created_rng, receipts,
		"heap image hover/focus, inspection and refresh spend no turn or RNG")
	sprite.gui_input.emit(_click_event())
	_no_change(stage, created, created_rng, receipts,
		"unselected heap click is refused without a receipt or RNG draw")
	var illegal_slot := ""
	for slot in StitchedBattleScreen.SLOTS:
		if stage.select_part(slot) and not stage.legal_targets().has("foe_1"):
			illegal_slot = slot
			break
	_check(not illegal_slot.is_empty(),
		"precondition: authentic equipped ability exists that cannot target a heap")
	if not illegal_slot.is_empty():
		var illegal_before := battle.state_snapshot()
		var illegal_rng := battle.rng_state()
		sprite.gui_input.emit(_click_event())
		sprite.gui_input.emit(_enter_event())
		_no_change(stage, illegal_before, illegal_rng, receipts,
			"actual illegal selected ability cannot be routed through heap click or Enter")
	stage._selected_part = ""
	stage._refresh()
	var enemy_id := str(stage._unit_at("foe", 2).get("id", ""))
	_check(not enemy_id.is_empty(), "precondition: a second living foe can hold an enemy turn")
	var order := battle._order.duplicate()
	var index := battle._turn_index
	battle._order = [enemy_id]
	battle._turn_index = 0
	stage._refresh()
	var enemy_state := battle.state_snapshot()
	var enemy_rng := battle.rng_state()
	sprite.gui_input.emit(_click_event())
	sprite.gui_input.emit(_enter_event())
	_no_change(stage, enemy_state, enemy_rng, receipts,
		"heap rejects pointer/Enter on enemy turn without mutation")
	battle._order = order
	battle._turn_index = index
	# Exercise truthful wound refresh without fabricating a different heap.
	var damage_receipt := {}
	var prior_hp := int(heap["hp"])
	if prior_hp > 1:
		battle._damage_target(battle._heaps[0], 1, damage_receipt)
		stage._refresh()
		var damaged := stage._heap_at(1)
		_check(int(damaged.get("hp", -1)) == prior_hp - 1
			and int(damage_receipt.get("target_hp", -1)) == prior_hp - 1,
			"real rule damage updates the same heap without creating another")
		_inspect_geometry(stage, 1, prior_hp - 1)
	_no_change(stage, battle.state_snapshot(), battle.rng_state(), receipts,
		"wounded heap refresh itself never creates extra combat receipts")


func _click_event() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


func _enter_event() -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.pressed = true
	return event


func _verify_legal_action(stage: StitchedBattleScreen, keyboard: bool) -> void:
	var battle := stage.battle
	if stage._heap_at(1).is_empty():
		_create_real_heap(stage)
	var selected := _select_damage_part(stage, 1)
	if selected.is_empty():
		return
	var sprite: TextureRect = stage._scrap_images["foe_1"]
	# Fourth rank is still empty, despite a currently selected part.
	var before := battle.state_snapshot()
	var rng := battle.rng_state()
	var receipts := stage.receipts.duplicate(true)
	stage._scrap_images["foe_4"].gui_input.emit(_click_event())
	stage._scrap_images["foe_4"].gui_input.emit(_enter_event())
	_check(battle._legal_targets(battle.get_unit(str(selected["hero"])), 
		StitchedParts.ability_at_tier(stage.parts[str(selected["part"])],
			int(battle.get_unit(str(selected["hero"]))["parts"][str(selected["slot"])]["tier"])), 4).is_empty(),
		"precondition: selected equipped ability cannot hit empty fourth-rank foe")
	_no_change(stage, before, rng, receipts,
		"wrong-rank/empty heap activation is rejected even with a real part selected")
	# Even a stale selected-slot UI must honor the rule's torn-part rejection.
	var live_part: Dictionary = battle._units[str(selected["hero"])]["parts"][str(selected["slot"])]
	var prior_torn := bool(live_part.get("torn", false))
	live_part["torn"] = true
	var torn_before := battle.state_snapshot()
	var torn_rng := battle.rng_state()
	sprite.gui_input.emit(_click_event())
	sprite.gui_input.emit(_enter_event())
	_no_change(stage, torn_before, torn_rng, receipts,
		"torn selected part refuses heap pointer/Enter before any RNG or receipt")
	live_part["torn"] = prior_torn
	stage._refresh()
	_check(stage._selected_part == selected["slot"] and stage.legal_targets().has("foe_1"),
		"restoring untorn real part restores its projected heap target")
	# Reduce the already-authentic heap to a single HP so this next successful
	# rule action must clear it, then compact living foes into the open rank.
	battle._heaps[0]["hp"] = 1
	stage._refresh()
	_check(stage._labels["foe_1"].text == "SCRAP 1 HP" and sprite.visible,
		"real previously generated and wounded heap remains targetable at one HP")
	_guarantee_seeded_hit(battle)
	before = battle.state_snapshot()
	rng = battle.rng_state()
	receipts = stage.receipts.duplicate(true)
	if keyboard:
		await _enter(sprite)
	else:
		await _mouse(sprite)
	var after := battle.state_snapshot()
	var next_receipts := stage.receipts
	var result: Dictionary = next_receipts[receipts.size()] if next_receipts.size() > receipts.size() else {}
	_check(next_receipts.size() == receipts.size() + 1
		and bool(result.get("ok", false)) and result.get("action") == "ability"
		and result.get("actor") == selected["hero"]
		and result.get("part") == selected["part"]
		and not result.get("results", []).is_empty()
		and str(result["results"][0].get("target_side", "")) == "heap"
		and bool(result["results"][0].get("hit", false))
		and bool(result["results"][0].get("heap_cleared", false))
		and after != before and battle.rng_state() != rng,
		"image pointer/Enter commits one authentic seeded heap hit and clears it")
	_check(stage._heap_at(1).is_empty() and not sprite.visible
		and _visible_scraps(stage).is_empty()
		and stage._selected_part.is_empty()
		and not stage._unit_at("foe", 1).is_empty()
		and stage._puppets["foe_1"].visible
		and stage._figure_hits["foe_1"].visible
		and stage._rank_meters["foe_1"]["root"].visible
		and stage._foe_tickets[1].visible
		and not stage._labels["foe_1"].visible,
		"clear removes heap image/focus and compacts living foe with real meter, intent and hit")
	var cleared := battle.state_snapshot()
	var cleared_rng := battle.rng_state()
	var cleared_receipts := stage.receipts.duplicate(true)
	sprite.gui_input.emit(_click_event())
	sprite.gui_input.emit(_enter_event())
	stage._refresh()
	_no_change(stage, cleared, cleared_rng, cleared_receipts,
		"stale hidden image cannot commit a second action or spend seeded RNG")
	_check(stage._scrap_images["foe_4"].visible == false
		and stage._target_buttons["foe_4"].disabled
		and not stage._figure_hits["foe_4"].visible,
		"empty fourth rank stays hidden and untargetable after heap clear")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	for keyboard in [false, true]:
		var mounted := await _mount()
		var stage: StitchedBattleScreen = mounted["screen"]
		_check(stage != null and stage.battle != null and stage.battle.is_valid(),
			"non-vacuous public mounted rules session exists")
		if stage != null and stage.battle != null and stage.battle.is_valid():
			if not keyboard:
				await _verify_empty_and_inspection(stage)
			await _verify_legal_action(stage, keyboard)
		mounted["app"].free()
		await process_frame
	for failure in failures:
		printerr(failure)
	print("stitched_s2_scrap_heap_stage_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
