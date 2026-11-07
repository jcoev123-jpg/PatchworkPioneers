extends SceneTree
## S11 live corridor: Wren is a passive, image-backed projection of rules and 3D ranks.

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, why: String) -> void:
	checks += 1
	if not ok:
		failures.append(why)


func _mount(config: Dictionary) -> StitchedCorridorFight:
	var screen := StitchedBattleScreen.new()
	_check(screen.begin(config), "precondition: real seeded StitchedRules 4v3 configuration begins")
	if screen.battle == null:
		screen.free()
		return null
	root.add_child(screen)
	await process_frame
	var old_count := screen.get_child_count()
	var fight := StitchedCorridorFight.attach(screen, "walls")
	_check(fight != null, "real StitchedCorridorFight.attach mounts successfully")
	if fight == null:
		screen.queue_free()
		return null
	await process_frame
	_check(screen.get_child_count() == 2 and fight.chrome.get_child_count() == old_count
		and not fight.chrome.visible and screen.kid_view.get_parent() == fight.chrome
		and fight.is_visible_in_tree(), "classic chrome and its original Wren layer stay hidden")
	_check(fight.battle.get_heroes().size() == 4 and fight.battle.get_foes().size() == 3
		and fight.stage.fighting, "real 4v3 rules and live 3D fight stage are present")
	return fight


func _projection(fight: StitchedCorridorFight, note: String) -> void:
	fight._place_overlays()
	var view := fight.kid_view
	var expected := 0
	var visible := 0
	var cut_count := 0
	var cuts := fight.battle.thread_cuts()
	for hero in fight.battle.get_heroes():
		var rank := int(hero.get("rank", 0))
		_check(rank >= 1 and rank <= 4, note + ": every hero has a valid rank")
		if rank < 1 or rank > 4:
			continue
		var rect := fight.stage.screen_rect("hero_%d" % rank)
		var present := not bool(hero.get("lost", false)) and rect.size.x > 0 and rect.size.y > 0
		var string: TextureRect = view.strings[rank]
		if not present:
			_check(not string.visible, note + ": LOST/empty/offscreen rank %d has no ghost string" % rank)
			continue
		expected += 1
		var cut := cuts.has(str(hero.get("id", "")))
		if string.visible:
			visible += 1
			if bool(string.get_meta("cut", false)):
				cut_count += 1
		var at := Vector2(rect.get_center().x, rect.position.y)
		var stored: Vector2 = string.get_meta("doll_top", Vector2(-1000, -1000))
		_check(string.is_visible_in_tree() and stored.distance_to(at) < 0.75,
			note + ": R%d string follows actual projected 3D head %s, not classic hit box" % [rank, str(at)])
		_check(bool(string.get_meta("cut", false)) == cut
			and string.texture == (view._thread_cut if cut else view._thread),
			note + ": R%d uses authoritative %s authored thread" % [rank, "CUT" if cut else "WHOLE"])
		if cut:
			_check(string.size.y <= StitchedKidView.CUT_LENGTH and string.size.y >= 4.0,
				note + ": cut thread is short, never a full-length picture")
		else:
			var reach: float = (at - view.knot(rank)).length()
			_check(absf(string.size.y - reach) < 0.75,
				note + ": full thread reaches the actual stage projection")
	_check(expected > 0 and visible == expected and cut_count == cuts.size(),
		note + ": one string per present non-LOST doll and exactly the rules' cut count")


func _unchanged(fight: StitchedCorridorFight, state: Dictionary, rng: int,
		receipts: Array, hand_open: bool, label: String) -> void:
	_check(fight.battle.state_snapshot() == state
		and fight.battle.rng_state() == rng
		and fight.engine.receipts == receipts
		and fight.battle.hand_action_open() == hand_open,
		label + ": passive projection/focus/input spend no state, RNG, receipts or Wren budget")


func _click(where: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = where
	motion.global_position = where
	root.push_input(motion, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = where
		event.global_position = where
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var book := StitchedKidView.art()
	for name in ["hands", "thread", "thread_cut", "fear_jar", "fear_ink"]:
		_check(ResourceLoader.exists(str(book.get(name, "")), "Texture2D"),
			"authored Wren image is installed: " + name)
	var fear_box := [0]
	var fight := await _mount(StitchedBattleScreen.read_preview())
	if fight == null:
		_finish()
		return
	var screen := fight.engine
	screen.kid_fear_source = func(): return fear_box[0]
	var view := fight.kid_view
	var count := 0
	for child in fight.get_children():
		if child is StitchedKidView:
			count += 1
	_check(count == 1 and view.get_parent() == fight and view.is_visible_in_tree()
		and view.get_index() > fight.stage.get_index()
		and view.get_index() < fight.hits["hero_1"].get_index(),
		"one visible Wren layer is above 3D stage but below clickable hit boxes")
	_check(view.hands.visible and view.hands.texture != null
		and view.meter.is_visible_in_tree()
		and view.meter.get_node("KidFearJar").texture != null
		and view.meter_fill.texture_progress != null
		and view.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and view.meter.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"authored hands, fear jar and ink are visible and transparent to pointer hits")
	_check(view.meter.get_global_rect().end.y < fight.ribbon.get_global_rect().position.y
		and view.meter.get_global_rect().end.y < StitchedCorridorFight.BAR_TOP
		and view.meter.get_global_rect().end.x <= 1280,
		"fear jar stays in top right, clear of intents/turn strip/action bar at 1280x720")
	for key in fight.hits:
		_check(fight.hits[key].get_index() > view.get_index()
			and fight.hits[key].mouse_filter != Control.MOUSE_FILTER_IGNORE,
			"figure " + key + " remains reachable above Wren")
	for slot in fight.part_buttons:
		_check(fight.part_buttons[slot].get_index() > view.get_index()
			and fight.part_buttons[slot].focus_mode == Control.FOCUS_ALL,
			"part button " + slot + " remains focusable above Wren")
	for action in fight.hand_buttons:
		_check(fight.hand_buttons[action].get_index() > view.get_index()
			and fight.hand_buttons[action].focus_mode == Control.FOCUS_ALL,
			"hand " + action + " remains focusable above Wren")
	_projection(fight, "mounted calm fight")
	var baseline := fight.battle.state_snapshot()
	var rng := fight.battle.rng_state()
	var receipts := screen.receipts.duplicate(true)
	var budget := fight.battle.hand_action_open()
	for value in [0, 49, 50, 60, 100]:
		fear_box[0] = value
		await process_frame  # No new battle receipt or state change.
		_check(screen.kid_fear() == value and view.fear == value
			and int(view.meter_fill.value) == value
			and view.meter_label.text.contains("%d / 100" % value)
			and view.shaking == (value >= 50)
			and view.is_processing() == (value >= 50),
			"source-only fear %d updates ink, label and live shake threshold" % value)
		_unchanged(fight, baseline, rng, receipts, budget, "fear %d" % value)
	screen.set_reduced_motion(true)
	await process_frame
	_check(view.fear == 100 and view.shaking and not view.is_processing()
		and view.meter_label.text.contains("100 / 100") and view.hands.rotation == 0.0,
		"reduced motion still shows source FEAR 100 but suppresses hand animation")
	_unchanged(fight, baseline, rng, receipts, budget, "reduced motion")
	fight.intent_tickets[1].grab_focus()
	_click(view.meter.get_global_rect().get_center())
	_click(fight.hits["hero_1"].get_global_rect().get_center())
	_unchanged(fight, baseline, rng, receipts, budget, "intent focus and passive mouse pointers")
	fight.intent_tickets[1].release_focus()
	# A real legal hand command and a stage figure click still pass through.
	fear_box[0] = 0
	screen.set_reduced_motion(false)
	_check(not fight.hand_buttons["steady"].disabled, "precondition: real Steady hand is legal")
	_click(fight.hand_buttons["steady"].get_global_rect().get_center())
	_check(screen._hand_pending == "steady", "pointer activates existing authored hand button")
	var before_hand := screen.receipts.size()
	_click(fight.hits["hero_1"].get_global_rect().get_center())
	_check(screen.receipts.size() > before_hand and not fight.battle.hand_action_open()
		and screen._hand_pending.is_empty(),
		"pointer passes Wren strings to legal 3D hero and commits existing Steady action")
	_projection(fight, "after live hand")
	# Exercise the first real enabled body-part button and its legal targeting.
	var part := ""
	for slot in StitchedBattleScreen.SLOTS:
		if not fight.part_buttons[slot].disabled:
			part = slot
			break
	_check(not part.is_empty(), "precondition: an equipped body part is legal")
	if not part.is_empty():
		var before_part := screen.receipts.size()
		_click(fight.part_buttons[part].get_global_rect().get_center())
		if not screen._selected_part.is_empty():
			var choices := screen.legal_targets()
			_check(not choices.is_empty(), "selected real part has a legal occupied target")
			if not choices.is_empty():
				var key: String = choices.keys()[0]
				_click(fight.hits[key].get_global_rect().get_center())
		_check(screen.receipts.size() > before_part, "part click reaches existing engine target/receipt")
	_projection(fight, "after live part")
	screen.queue_free()
	await process_frame

	# Genuine rules cut: Walk arrival requires already-paid 20 Fray and a rank boundary.
	var cut_config := StitchedBattleScreen.read_preview()
	var cut_hero: Dictionary = cut_config.heroes[1]
	cut_hero["fray"] = 20
	cut_config["walk_cuts"] = {str(cut_hero.id): 2}
	var cut_fight := await _mount(cut_config)
	if cut_fight == null:
		_finish()
		return
	var cut_screen := cut_fight.engine
	_check(cut_fight.battle.thread_cuts() == {str(cut_hero.id): 2}
		and int(cut_fight.battle.get_unit(str(cut_hero.id)).get("fray", 0)) >= 20,
		"StitchedRules accepted paid Walk SNIP boundary; no presentation-created cut")
	_projection(cut_fight, "genuine Walk cut")
	var turns := 0
	while not cut_fight.battle.is_over() and cut_fight.battle.current_actor_id() != str(cut_hero.id) and turns < 12:
		turns += 1
		if cut_fight.battle.current_side() == "hero":
			cut_screen.submit_pass()
		else:
			cut_screen._drive_foes()
		await process_frame
	_check(not cut_fight.battle.is_over() and cut_fight.battle.current_actor_id() == str(cut_hero.id)
		and cut_fight.battle.current_side() == "hero" and not cut_fight.more_buttons.re_tie.disabled,
		"precondition: real snipped doll's turn has enabled Re-tie")
	if cut_fight.battle.current_actor_id() == str(cut_hero.id) and not cut_fight.battle.is_over():
		var before_retie := cut_screen.receipts.size()
		cut_fight.set_more_open(true)
		cut_fight.more_buttons.re_tie.pressed.emit()
		await process_frame
		var accepted := false
		for index in range(before_retie, cut_screen.receipts.size()):
			var receipt: Dictionary = cut_screen.receipts[index]
			if bool(receipt.get("ok", false)) and str(receipt.get("action", "")) == "re_tie" and str(receipt.get("actor", "")) == str(cut_hero.id):
				accepted = true
		_check(accepted and cut_fight.battle.thread_cuts().is_empty(),
			"actual Re-tie button yields accepted StitchedRules receipt and clears authoritative cut")
		_projection(cut_fight, "accepted Re-tie")
	cut_screen.queue_free()
	await process_frame

	# A real legal Lift changes both hero ranks; each thread must follow its new doll.
	var move_fight := await _mount(StitchedBattleScreen.read_preview())
	if move_fight == null:
		_finish()
		return
	var lifted_id := ""
	var direction := 0
	var from_rank := 0
	for hero in move_fight.battle.get_heroes():
		for way in [-1, 1]:
			if lifted_id.is_empty() and move_fight.battle.hand_action_check("lift", str(hero.id), way).is_empty():
				lifted_id = str(hero.id)
				from_rank = int(hero.rank)
				direction = way
	_check(not lifted_id.is_empty() and move_fight.battle.hand_action_open(),
		"precondition: actual Lift has an allowed direction")
	if not lifted_id.is_empty():
		_check(bool(move_fight.choose_hand("lift").get("ok", false)), "existing engine offers Lift")
		var pending := move_fight.click_figure("hero", from_rank)
		_check(str(pending.get("pending", "")) == "lift:%d" % from_rank,
			"real hero figure selects Lift target")
		var button: Button = move_fight.more_buttons.move_front if direction == -1 else move_fight.more_buttons.move_back
		_check(not button.disabled, "Lift direction button is enabled by rules")
		button.pressed.emit()
		await process_frame
		_check(int(move_fight.battle.get_unit(lifted_id).get("rank", 0)) == from_rank + direction,
			"real accepted Lift shifts the doll's actual rank")
		_projection(move_fight, "after genuine Lift rank movement")
	move_fight.engine.queue_free()
	await process_frame

	# Valid carried LOST hero occupies no active string, without mutating the live rules.
	var lost_config := StitchedBattleScreen.read_preview()
	lost_config.heroes[3]["lost"] = true
	lost_config.heroes[3]["hp"] = 0
	lost_config.heroes[3]["parts"] = {}
	var lost_fight := await _mount(lost_config)
	if lost_fight != null:
		_check(bool(lost_fight.battle.get_unit(str(lost_config.heroes[3].id)).get("lost", false))
			and not lost_fight.stage.figure_nodes.has("hero_4"),
			"precondition: real accepted carried-LOST doll has no stage figure")
		_projection(lost_fight, "carried LOST rank")
		_check(not lost_fight.kid_view.strings[4].visible,
			"LOST fourth rank has no ghost string")
		lost_fight.engine.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr("FAIL: " + failure)
	print("stitched_s11_wren_strings_fear_test: %s (%d checks, %d failures)" % [
		"PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
