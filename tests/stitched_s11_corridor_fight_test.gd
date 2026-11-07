extends SceneTree
## S11: a fight plays in the corridor itself: party left, foes right, one bottom bar, and the
## classic battle screen kept underneath as the hidden engine.
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, why: String) -> void:
	checks += 1
	if not ok:
		failures.append(why)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var screen := StitchedBattleScreen.new()
	_check(screen.begin(StitchedBattleScreen.read_preview()), "precondition: preview battle starts")
	root.add_child(screen)
	await process_frame
	var old_children := screen.get_child_count()
	var fight := StitchedCorridorFight.attach(screen, "walls")
	_check(fight != null, "the corridor view mounts over the engine")
	await process_frame
	_check(screen.get_child_count() == 2 and fight.chrome.get_child_count() == old_children
		and not fight.chrome.visible, "the classic chrome is tucked away whole, not torn out")
	_check(screen.is_visible_in_tree() and screen._action_buttons.has("exit"), "the engine itself stays live")
	_check(fight.stage.fighting and fight.stage.camera.fov == StitchedCorridorStage.FIGHT_FOV, "the corridor turns to the fight view")
	var heroes := 0
	var foes := 0
	for key in fight.plates:
		if fight.plates[key].visible:
			if key.begins_with("hero"):
				heroes += 1
			else:
				foes += 1
	_check(heroes == 4 and foes == 3, "a name plate for each of 4 dolls and 3 foes")
	var hero_spot: Vector2 = fight.stage.screen_point("hero_1")
	var foe_spot: Vector2 = fight.stage.screen_point("foe_1")
	_check(hero_spot.x < 640.0 and foe_spot.x > 640.0, "the party stands left, the foes right")
	_check(fight.stage.screen_point("hero_4").x < hero_spot.x and fight.stage.screen_point("foe_3").x > foe_spot.x,
		"front ranks face each other in the middle")
	for key in fight.plates:
		if fight.plates[key].visible:
			var plate: Control = fight.plates[key]
			_check(plate.position.y + plate.size.y <= StitchedCorridorFight.BAR_TOP and plate.position.x > -60.0
				and plate.position.x < 1280.0, key + " plate stays on screen above the bar")
			_check(fight.hits[key].size.x > 20.0 and fight.hits[key].size.y > 40.0, key + " can be clicked")
	_check(fight.stage.figure_nodes["foe_1"].flip_h and not fight.stage.figure_nodes["hero_1"].flip_h,
		"foes turn round to face the party")
	for key in fight.hits:
		_check(not fight.hits[key].tooltip_text.contains("FRAY") and not fight.hits[key].tooltip_text.contains("/200"),
			key + " hover shows no fray count: " + fight.hits[key].tooltip_text)
	_check(StitchedCorridorFight._simple_detail("R3 Tinker · HP 29/29 · FRAY 0/200
STATUS: none") == "R3 Tinker · HP 29/29",
		"hover detail keeps name and health only: " + StitchedCorridorFight._simple_detail("R3 Tinker · HP 29/29 · FRAY 0/200
STATUS: none"))
	_check(fight.part_buttons.size() == 4 and fight.candle_icon.texture != null, "four body parts and the candle")
	var hidden_numbers := ["fray", "candle", "fear", "whirr"]
	for label in fight.find_children("*", "Label", true, false):
		if label.is_visible_in_tree():
			for word in hidden_numbers:
				_check(not (label.text.to_lower().contains(word) and label.text.to_lower().contains(":")),
					"no readout for " + word + ": " + label.text)
	_check(not fight.continue_button.visible, "Continue waits for the fight to end")
	# Left alone on a turn, a standing doll speaks over its own head.
	for kind in ["fight_idle", "fight_hurt", "fight_dark", "fight_boss", "fight_winning", "fight_losing"]:
		_check(not fight.barks.data.contexts.get(kind, []).is_empty(), "fight lines for " + kind)
	_check(not fight.bark_label.visible and (fight.bark_timer.is_stopped() == (screen.battle.current_side() != "hero")),
		"the dolls start quiet with the wait armed on the player's turn")
	var said := fight.bark()
	_check(not said.is_empty() and fight.bark_label.visible and fight.bark_label.text.contains(said.line)
		and said.side == "hero" and str(screen.battle.get_unit(said.speaker).get("side", "")) == "hero",
		"a doll in the party speaks a fight line: " + str(said))
	_check(fight.bark_label.position.y >= 132.0 and fight.bark_label.position.y + fight.bark_label.size.y < StitchedCorridorFight.BAR_TOP,
		"the line sits between the turn strip and the bar")
	var again := StitchedWalkBarks.new().pick_fight(screen.battle, 0)
	_check(again.line == said.line and again.speaker == said.speaker, "the same turn picks the same first line")
	var second := fight.bark()
	_check(second.line != said.line or fight.barks.data.contexts[second.context].size() == 1, "no fight line twice in a row")
	fight.hush()
	_check(not fight.bark_label.visible, "the player's touch hushes the doll")
	_check(StitchedWalkBarks.fight_context(screen.battle) in ["fight_idle", "fight_boss", "fight_losing", "fight_dark"],
		"a fresh fight is not called hurt or won: " + StitchedWalkBarks.fight_context(screen.battle))
	# Play the whole fight through the corridor view only.
	var acted := 0
	var guard := 0
	while not screen.battle.is_over() and guard < 200:
		guard += 1
		if screen.battle.current_side() != "hero":
			break
		var done := false
		for slot in StitchedBattleScreen.SLOTS:
			if fight.part_buttons[slot].disabled:
				continue
			var before := screen.receipts.size()
			var picked := fight.choose_part(slot)
			if picked.get("pending", "") == slot:
				var key: String = screen.legal_targets().keys()[0]
				fight.click_figure(key.get_slice("_", 0), int(key.get_slice("_", 1)))
			if screen.receipts.size() > before:
				done = true
				acted += 1
				break
			screen._selected_part = ""
		if not done:
			screen.submit_pass()
		await process_frame
	_check(acted >= 3, "dolls act through the round part buttons (%d)" % acted)
	_check(screen.battle.is_over(), "the fight ends")
	await process_frame
	_check(fight._seen_receipts == screen.receipts.size(), "every action reaches the corridor view %d/%d" % [fight._seen_receipts, screen.receipts.size()])
	_check(fight.continue_button.visible and fight.outcome_label.visible, "Continue appears at the end")
	_check(fight.bark_timer.is_stopped() and fight.bark().is_empty(), "the dolls fall quiet once the fight is over")
	var exited := [false]
	screen.exit_requested.connect(func(): exited[0] = true)
	fight.finish()
	_check(exited[0], "Continue hands the result back like the classic exit")
	var extra := fight.add_more("save", "Save run", func(): pass)
	_check(extra.get_parent() == fight.more_grid, "the host can add choices behind More")
	screen.free()
	for failure in failures:
		printerr(failure)
	print("stitched_s11_corridor_fight_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
