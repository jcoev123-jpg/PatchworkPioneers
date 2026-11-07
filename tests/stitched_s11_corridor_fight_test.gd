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


## Every visible threat comes from the same read-only projection as the live
## driver. A fourth rank is checked too when the fixture has one.
func _verify_live_intents(fight: StitchedCorridorFight, expected: int) -> void:
	var found := 0
	var occupied := 0
	for rank in range(1, 5):
		var foe: Dictionary = fight.engine._unit_at("foe", rank)
		var projected: Dictionary = StitchedFoeIntent.choose(fight.battle, foe)
		var ticket: StitchedFoeIntentPlate = fight.intent_tickets[rank]
		var tag: Label = fight.intent_tags[rank]
		if foe.is_empty():
			_check(projected.is_empty() and not ticket.visible and ticket.foe_id.is_empty()
				and not ticket.glyph.visible and ticket.tooltip_text.is_empty()
				and not tag.visible and not fight.intent_projections.has(rank),
				"empty/dead/heap foe R%d has no cached projection, glyph, or plaque" % rank)
			continue
		occupied += 1
		_check(not projected.is_empty(), "live foe R%d has an actual next projection" % rank)
		if projected.is_empty():
			continue
		found += 1
		_check(ticket.is_visible_in_tree() and tag.is_visible_in_tree()
			and ticket.texture == StitchedFoeIntentPlate.PLATE_TEXTURE
			and ticket.foe_id == projected["foe_id"] and ticket.foe_rank == rank
			and fight.intent_projections.get(rank, {}) == projected
			and ticket.tooltip_text.contains(str(projected["foe_name"]))
			and tag.text.begins_with("FOE R%d" % rank),
			"mounted foe R%d has its own authored projection, ID/name and rank" % rank)
		_check(ticket.size.x >= 170 and ticket.primary.get_theme_font_size("font_size") >= 24
			and ticket.secondary.get_theme_font_size("font_size") >= 17
			and ticket.get_global_rect().end.x <= 1280
			and ticket.get_global_rect().position.y > fight.ribbon.get_global_rect().end.y
			and ticket.get_global_rect().end.y < StitchedCorridorFight.BAR_TOP
			and ticket.focus_mode == Control.FOCUS_ALL,
			"R%d native text and accessible plaque clear top ribbon and lower bar" % rank)
		# Compare live hit shapes, not hard-coded screen coordinates: the
		# threat strip must never steal a click from a 3D figure or Wren.
		for key in fight.hits:
			if fight.hits[key].visible:
				_check(not ticket.get_global_rect().intersects(fight.hits[key].get_global_rect()),
					"foe intent R%d clears the actual %s figure hit zone" % [rank, key])
		for action_id in fight.hand_buttons:
			_check(not ticket.get_global_rect().intersects(fight.hand_buttons[action_id].get_global_rect()),
				"foe intent R%d clears Wren's %s hand" % [rank, action_id])
		if bool(projected.get("stun", false)) or bool(projected.get("pass", false)):
			_check(ticket.primary.text in ["STUN", "PASS"] and ticket.secondary.text == "NO ACTION"
				and not ticket.glyph.visible and tag.text.contains("NO ACTION"),
				"R%d STUN/PASS is NO ACTION with no ghost strike" % rank)
		else:
			_check(ticket.tooltip_text.contains(str(projected["ability_name"]))
				and ticket.tooltip_text.contains("Kind: " + str(projected["ability_kind"]).to_upper())
				and tag.text.contains(str(projected["ability_kind"]).to_upper())
				and ticket.tooltip_text.contains("BASE ACC")
				and ticket.tooltip_text.contains("BASE DMG")
				and ticket.ability_kind == projected["ability_kind"],
				"R%d displays full authored ability name/kind/base details" % rank)
			var target_line: String = ticket.secondary.text
			var ranks := PackedStringArray()
			for affected in projected.get("affected_ranks", []):
				ranks.append(str(affected))
			var side := "HERO" if projected.get("target_side", "") == "hero" else "FOE"
			_check(not ranks.is_empty() and target_line.contains(side)
				and target_line.contains(",".join(ranks))
				and ticket.tooltip_text.contains("rank"),
				"R%d displays ALL exact affected %s ranks %s" % [rank, side, ",".join(ranks)])
	_check(occupied == expected and found == expected,
		"non-vacuous corridor intent count %d/%d matches %d living foes" % [found, occupied, expected])


func _verify_inspection(fight: StitchedCorridorFight) -> void:
	var screen := fight.engine
	var pristine := fight.battle.state_snapshot()
	var rng := fight.battle.rng_state()
	var receipts := screen.receipts.duplicate(true)
	var part := screen._selected_part
	var hand_pending := screen._hand_pending
	var hand_budget := fight.battle.hand_action_open()
	fight.refresh()
	_verify_live_intents(fight, 3)
	var ticket: StitchedFoeIntentPlate = fight.intent_tickets[1]
	_check(ticket.visible and not ticket.tooltip_text.is_empty(), "precondition: a live foe's sewn ticket is inspectable")
	ticket.mouse_entered.emit()
	_check(fight.intent_disclosure.visible and fight.intent_detail.text.contains(ticket.tooltip_text)
		and fight.intent_detail.text.contains("FOE R1") and fight.intent_disclosure.texture == StitchedCorridorFight.FELT
		and fight.intent_detail.get_theme_font_size("font_size") >= 18
		and ticket.primary.get_theme_color("font_color") == StitchedFoeIntentPlate.BRASS
		and ticket._get_tooltip(Vector2.ZERO).is_empty(),
		"actual hovered ticket opens pale bone sewn full-detail disclosure, never a stock tooltip")
	_check(fight.intent_detail.get_visible_line_count() == fight.intent_detail.get_line_count()
		and fight.intent_detail.get_theme_color("font_color") == StitchedCorridorFight.BONE,
		"all authoritative disclosure lines fit the pale-bone authored panel without clipping")
	for key in fight.hits:
		if fight.hits[key].visible:
			_check(not fight.intent_disclosure.get_global_rect().intersects(fight.hits[key].get_global_rect()),
				"hovered sewn disclosure clears actual 3D figure %s click zone (panel=%s hit=%s)" % [key, str(fight.intent_disclosure.get_global_rect()), str(fight.hits[key].get_global_rect())])
	ticket.mouse_exited.emit()
	_check(not fight.intent_disclosure.visible and fight.intent_detail.text.is_empty(),
		"hover exit closes the sewn details")
	ticket.grab_focus()
	_check(ticket.has_focus() and fight.intent_disclosure.visible
		and fight.intent_detail.text.contains(ticket.tooltip_text),
		"keyboard focus opens the identical complete intent details")
	ticket.release_focus()
	_check(not fight.intent_disclosure.visible, "keyboard focus exit hides the disclosure")
	_check(fight.battle.state_snapshot() == pristine and fight.battle.rng_state() == rng
		and screen.receipts == receipts and screen._selected_part == part
		and screen._hand_pending == hand_pending and fight.battle.hand_action_open() == hand_budget,
		"idle refresh, hover and keyboard focus spend no battle state, RNG, part or hand")


func _verify_intent_fixtures(fight: StitchedCorridorFight) -> void:
	var screen := fight.engine
	var battle := fight.battle
	var pristine := battle.state_snapshot()
	var rng := battle.rng_state()
	var receipts := screen.receipts.duplicate(true)
	var original: Dictionary = screen._unit_at("foe", 1).duplicate(true)
	var third: Dictionary = screen._unit_at("foe", 3).duplicate(true)
	_check(not original.is_empty() and not third.is_empty()
		and not original.get("abilities", []).is_empty() and screen._unit_at("foe", 4).is_empty(),
		"precondition: actual 4v3 fight has authored foe abilities and a vacant fourth rank")
	if original.is_empty() or third.is_empty() or original.get("abilities", []).is_empty():
		return
	# The same kind of retained combat unit as the S2 post-summon fixture.
	var extra := third.duplicate(true)
	extra["id"] = "ragling"
	extra["name"] = "Ragling"
	extra["rank"] = 4
	battle._units[str(extra["id"])] = extra
	fight.refresh()
	_verify_live_intents(fight, 4)
	_check(fight.stage.figure_nodes.has("foe_4") and fight.stage.figure_nodes["foe_4"].visible,
		"a fourth living unit appears in the mounted 3D corridor with its own ticket")
	battle._units.erase(str(extra["id"]))
	fight.refresh()
	_verify_live_intents(fight, 3)
	_check(not fight.intent_tickets[4].visible and fight.intent_tickets[4].foe_id.is_empty(),
		"retired fourth foe never leaves a stale intent")
	var actor: Dictionary = battle._units[str(original["id"])]
	for state in ["PASS", "STUN", "MULTI"]:
		actor["abilities"] = []
		actor["statuses"] = {}
		if state == "STUN":
			actor["statuses"] = {"stun": 1}
		elif state == "MULTI":
			var ability: Dictionary = original["abilities"][0].duplicate(true)
			ability["name"] = "A Long Tangle of Moonlit Needles and Unravelling Threads"
			ability["multi"] = true
			ability["target_mask"] = StitchedParts.rank_mask([1, 2, 3, 4])
			ability["launch_mask"] = StitchedParts.rank_mask([1, 2, 3, 4])
			actor["abilities"] = [ability]
		fight.refresh()
		_verify_live_intents(fight, 3)
		var threat: StitchedFoeIntentPlate = fight.intent_tickets[1]
		if state == "MULTI":
			_check(fight.intent_projections[1].get("affected_ranks", []) == [1, 2, 3, 4]
				and threat.secondary.text.contains("1,2,3,4")
				and threat.tooltip_text.contains("A Long Tangle of Moonlit Needles")
				and threat.glyph.visible,
				"four-rank splash keeps the exact ranks, authored full name and glyph")
		else:
			_check(threat.primary.text == state and threat.secondary.text == "NO ACTION"
				and not threat.glyph.visible, state + " cannot show a stale attack")
	battle._units[str(original["id"])] = original.duplicate(true)
	# Dead units and their scrap heaps are not intent-bearing actors.
	var down: Dictionary = battle._units[str(original["id"])]
	down["hp"] = 0
	down["dead"] = true
	var original_heaps := battle._heaps.duplicate(true)
	battle._heaps.append({"rank": 1, "hp": 5, "max_hp": 5})
	fight.refresh()
	_verify_live_intents(fight, 2)
	_check(fight.plates["foe_1"].visible and fight.plates["foe_1"].get_node("Name").text == "Scrap heap"
		and not fight.intent_tickets[1].visible, "a visible fallen foe's heap never has a phantom threat")
	battle._heaps = original_heaps
	battle._units[str(original["id"])] = original.duplicate(true)
	fight.refresh()
	_verify_live_intents(fight, 3)
	_check(battle.state_snapshot() == pristine and battle.rng_state() == rng
		and screen.receipts == receipts and screen._selected_part.is_empty()
		and battle.hand_action_open(), "all detached fixtures restore the genuine 4v3 battle, RNG and hand")


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
	_verify_live_intents(fight, 3)
	_verify_inspection(fight)
	_verify_intent_fixtures(fight)
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
	# Wren's hand sits on the bar as four small hands, not behind More.
	_check(fight.hand_buttons.size() == 4, "four of Wren's hands on the bar")
	for action_id in StitchedKidHandActions.IDS:
		var hand: TextureButton = fight.hand_buttons[action_id]
		_check(hand.texture_normal != null and hand.visible and not fight.more_buttons.has(action_id),
			action_id + " is a picture on the bar, not a More choice")
		_check(hand.position.x + hand.size.x <= 1264.0 and hand.position.y >= StitchedCorridorFight.BAR_TOP
			and hand.position.y + hand.size.y <= StitchedCorridorFight.BAR_TOP + 126.0, action_id + " fits inside the bar")
		_check(not RegEx.create_from_string(r"\d").search(hand.tooltip_text), action_id + " hover shows no number: " + hand.tooltip_text)
		_check(not hand.get_global_rect().intersects(fight.more_button.get_global_rect()), action_id + " clears More")
	_check(StitchedCorridorFight._plain("Wren cups a doll: -8 fray.") == "Wren cups a doll.", "the fray number is cut from the hover")
	if screen.battle.hand_action_open():
		_check(not fight.hand_buttons.steady.disabled, "the hand is free at the round's start")
		fight.hand_buttons.steady.pressed.emit()
		_check(screen._hand_pending == "steady" and fight.hand_buttons.steady.modulate.r > 1.0, "Steady waits for a doll and glows")
		var before_hand := screen.receipts.size()
		fight.click_figure("hero", 1)
		await process_frame
		_check(screen.receipts.size() > before_hand and not screen.battle.hand_action_open(), "Wren steadies a doll from the bar")
		for action_id in StitchedKidHandActions.IDS:
			_check(fight.hand_buttons[action_id].disabled, action_id + " rests once the hand is spent this round")
		_verify_live_intents(fight, 3)
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
		if not screen.battle.is_over():
			var remaining := 0
			for rank in range(1, 5):
				if not screen._unit_at("foe", rank).is_empty():
					remaining += 1
			_verify_live_intents(fight, remaining)
	_check(acted >= 3, "dolls act through the round part buttons (%d)" % acted)
	_check(screen.battle.is_over(), "the fight ends")
	await process_frame
	_check(fight._seen_receipts == screen.receipts.size(), "every action reaches the corridor view %d/%d" % [fight._seen_receipts, screen.receipts.size()])
	_check(fight.continue_button.visible and fight.outcome_label.visible, "Continue appears at the end")
	_check(not fight.hand_buttons.lift.visible, "Wren's hands step aside for Continue")
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
