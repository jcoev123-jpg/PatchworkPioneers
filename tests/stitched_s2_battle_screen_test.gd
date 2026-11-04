extends SceneTree
## Mounted, public-entry S2 test: not a made-up test-only action bridge.
const BOOT := preload("res://scripts/live_web_playtest_boot.gd")
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)


func _spawn() -> Node:
	var app: Node = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	return app


func _stage(app) -> StitchedBattleScreen:
	var boot := root.get_node("LiveWebPlaytestBoot")
	_check(await boot.enter_preview(app, "stitched_battle"), "public query entry mounts a Stitched session")
	return boot.stitched_view


func _rank_key(stage: StitchedBattleScreen) -> String:
	for key in stage.legal_targets():
		return key
	return ""


func _choose_legal(stage: StitchedBattleScreen) -> Dictionary:
	var actor := stage.battle.get_unit(stage.battle.current_actor_id())
	if actor.is_empty() or stage.battle.current_side() != "hero":
		return {}
	for slot in StitchedBattleScreen.SLOTS:
		if not stage.select_part(slot):
			continue
		var key := _rank_key(stage)
		if key.is_empty():
			continue
		var parts: Dictionary = actor["parts"]
		var before := stage.receipts.size()
		var receipt := stage.submit_target(key.split("_")[0], int(key.split("_")[1]))
		_check(bool(receipt.get("ok", false)), "legal target commits an authored ability")
		_check(stage.receipts.size() > before and stage.receipts[before].get("actor") == actor["id"] and
			stage.receipts[before].get("part") == parts[slot]["id"],
			"part action delegates exactly once, with the real acting part and receipt")
		return receipt
	return {}


func _verify_status_readout(stage: StitchedBattleScreen) -> void:
	var battle := stage.battle
	var saved_units: Dictionary = {}
	for unit_id in battle._units:
		saved_units[unit_id] = battle._units[unit_id].duplicate(true)
	var saved_heaps: Array = battle._heaps.duplicate(true)
	var ordinary_log := str(stage._labels["log"].text)
	var foe_1_id := str(stage._unit_at("foe", 1).get("id", ""))
	var hero_1_id := str(stage._unit_at("hero", 1).get("id", ""))
	var hero_2_id := str(stage._unit_at("hero", 2).get("id", ""))
	_check(not foe_1_id.is_empty() and not hero_1_id.is_empty() and not hero_2_id.is_empty(),
		"precondition: mounted 4v3 fight has living actors in foe_1, hero_1 and hero_2")
	var foe_1: Dictionary = battle._units[foe_1_id]
	var hero_1: Dictionary = battle._units[hero_1_id]
	var hero_2: Dictionary = battle._units[hero_2_id]
	foe_1["statuses"] = {"bleed": 3, "weak": 2, "mark": 1, "stun": 1, "exposed": 0}
	hero_1["statuses"] = {"guard": 2, "stun_resist": 1, "tangled": 0}
	hero_1["dodge_buff"] = {"amount": 8, "turns": 2, "skip": false}
	hero_2["hp"] = 0
	hero_2["fray"] = 150
	hero_2["hanging"] = true
	hero_2["statuses"] = {}
	stage._refresh()
	var view_snapshot := battle.state_snapshot()
	var view_rng := battle.rng_state()
	var view_receipts := stage.receipts.size()
	_check(stage._labels["log"].text == ordinary_log,
		"passive refresh without seat hover or focus preserves the ordinary action message")
	_check(stage._seat_buttons["foe_1"].text.contains("R1") and
		stage._seat_buttons["foe_1"].text.contains(str(foe_1["name"])) and
		stage._labels["foe_1"].text.begins_with("HP %d/%d" % [int(foe_1["hp"]), int(foe_1["max_hp"])]) and
		stage._labels["foe_1"].text.contains("BLEED 3") and
		stage._labels["foe_1"].text.contains("WEAK 2") and
		stage._labels["foe_1"].text.contains("STUN 1") and
		stage._labels["foe_1"].text.contains("MARK 1") and
		not stage._labels["foe_1"].text.contains("EXPOSED"),
		"foe_1 rank seat keeps rank/name/HP and exposes positive counted statuses while omitting zero statuses")
	# Pointer hover over foe_1 seat.
	stage._seat_buttons["foe_1"].mouse_entered.emit()
	var foe_detail := str(stage._labels["log"].text)
	_check(foe_detail == stage.status_detail("foe", 1) and
		foe_detail.contains("R1") and foe_detail.contains(str(foe_1["name"])) and
		foe_detail.contains("HP %d/%d" % [int(foe_1["hp"]), int(foe_1["max_hp"])]) and
		foe_detail.contains("BLEED 3") and foe_detail.contains("WEAK 2") and
		foe_detail.contains("STUN 1") and foe_detail.contains("MARK 1") and
		not foe_detail.contains("EXPOSED") and not foe_detail.contains("DODGE") and
		not foe_detail.contains("HANGING"),
		"mouse hover on foe_1 shows full counted status summary in the side detail log without zero/foreign statuses")
	_check(battle.state_snapshot() == view_snapshot and battle.rng_state() == view_rng and
		stage.receipts.size() == view_receipts,
		"mouse hover inspection spends no turn, changes no snapshot and consumes no RNG")
	stage._seat_buttons["foe_1"].mouse_exited.emit()
	_check(stage._labels["log"].text == ordinary_log,
		"leaving hovered seat restores the prior ordinary action message")
	# Keyboard focus over hero_1 seat (Guard 2, Stun Resist 1, Dodge +8 / 2 turns).
	stage._seat_buttons["hero_1"].grab_focus()
	var hero_1_detail := str(stage._labels["log"].text)
	_check(stage._seat_buttons["hero_1"].has_focus() and
		hero_1_detail == stage.status_detail("hero", 1) and
		hero_1_detail.contains("R1") and hero_1_detail.contains(str(hero_1["name"])) and
		hero_1_detail.contains("HP %d/%d" % [int(hero_1["hp"]), int(hero_1["max_hp"])]) and
		hero_1_detail.contains("GUARD 2") and hero_1_detail.contains("STUN RESIST 1") and
		hero_1_detail.contains("DODGE +8 / 2 turns") and
		stage._labels["hero_1"].text.contains("GUARD 2") and
		stage._labels["hero_1"].text.contains("DODGE +8 / 2 turns") and
		not hero_1_detail.contains("TANGLED") and not hero_1_detail.contains("BLEED") and
		not hero_1_detail.contains("HANGING"),
		"keyboard focus on hero_1 shows GUARD 2, STUN RESIST 1 and temporary DODGE +8 / 2 turns")
	_check(battle.state_snapshot() == view_snapshot and battle.rng_state() == view_rng and
		stage.receipts.size() == view_receipts,
		"keyboard focus inspection spends no turn, changes no snapshot and consumes no RNG")
	stage._action_buttons["pass"].grab_focus()
	_check(stage._labels["log"].text == ordinary_log,
		"moving keyboard focus off the rank seat restores the prior action message")
	# Separate Hanging fixture on hero_2.
	stage._seat_buttons["hero_2"].mouse_entered.emit()
	var hero_2_detail := str(stage._labels["log"].text)
	_check(hero_2_detail == stage.status_detail("hero", 2) and
		hero_2_detail.contains("R2") and hero_2_detail.contains(str(hero_2["name"])) and
		hero_2_detail.contains("HP 0/%d" % int(hero_2["max_hp"])) and
		hero_2_detail.contains("FRAY 150/200") and hero_2_detail.contains("HANGING") and
		stage._labels["hero_2"].text.contains("FRAY 150") and
		stage._labels["hero_2"].text.contains("HANGING") and
		not hero_2_detail.contains("DODGE") and not hero_2_detail.contains("GUARD"),
		"Hanging hero fixture exposes HP 0, FRAY 150 and HANGING state in seat and detail readout")
	_check(battle.state_snapshot() == view_snapshot and battle.rng_state() == view_rng and
		stage.receipts.size() == view_receipts,
		"viewing Hanging seat preserves battle snapshot, RNG and receipt count")
	stage._seat_buttons["hero_2"].mouse_exited.emit()
	# Zero/removed statuses and expired/absent dodge_buff disappear on refresh.
	stage._seat_buttons["hero_1"].mouse_entered.emit()
	hero_1["statuses"]["guard"] = 0
	hero_1["statuses"].erase("stun_resist")
	hero_1["dodge_buff"] = {"amount": 8, "turns": 0, "skip": false}
	foe_1["statuses"] = {"bleed": 0}
	foe_1["statuses"].erase("weak")
	hero_2["hanging"] = false
	hero_2["hp"] = int(hero_2["max_hp"])
	hero_2["fray"] = 0
	var cleared_snapshot := battle.state_snapshot()
	var cleared_rng := battle.rng_state()
	stage._refresh()
	_check(stage._labels["log"].text.contains("STATUS: none") and
		not stage._labels["log"].text.contains("GUARD") and
		not stage._labels["log"].text.contains("STUN RESIST") and
		not stage._labels["log"].text.contains("DODGE") and
		not stage._labels["hero_1"].text.contains("GUARD") and
		not stage._labels["hero_1"].text.contains("DODGE") and
		not stage._labels["foe_1"].text.contains("BLEED") and
		not stage._labels["foe_1"].text.contains("WEAK") and
		not stage.status_detail("foe", 1).contains("BLEED") and
		not stage._labels["hero_2"].text.contains("HANGING") and
		not stage.status_detail("hero", 2).contains("HANGING"),
		"zero/removed statuses, expired temporary Dodge and cleared Hanging disappear on refresh")
	_check(battle.state_snapshot() == cleared_snapshot and battle.rng_state() == cleared_rng and
		stage.receipts.size() == view_receipts,
		"refreshing after status expiry spends no turn, snapshot or RNG")
	stage._seat_buttons["hero_1"].mouse_exited.emit()
	# Empty rank (foe_4) and scrap heap never leak stale or phantom status text.
	stage._seat_buttons["foe_4"].mouse_entered.emit()
	var empty_detail := str(stage._labels["log"].text)
	_check(stage._labels["foe_4"].text == "EMPTY" and
		empty_detail.contains("R4") and empty_detail.contains("EMPTY") and
		empty_detail.contains("STATUS: none") and
		not empty_detail.contains("BLEED") and not empty_detail.contains("GUARD") and
		not empty_detail.contains("DODGE") and not empty_detail.contains("HANGING"),
		"empty fourth foe rank is unambiguous and leaks no stale status text")
	battle._heaps.append({
		"id": "heap:test_scavenger", "side": "heap", "rank": 4,
		"hp": 9, "max_hp": 9, "foe_id": foe_1_id, "statuses": {"bleed": 4, "mark": 2},
	})
	var heap_snapshot := battle.state_snapshot()
	var heap_rng := battle.rng_state()
	stage._refresh()
	var heap_detail := str(stage._labels["log"].text)
	_check(stage._labels["foe_4"].text == "SCRAP 9 HP" and
		heap_detail.contains("R4") and heap_detail.contains("Scrap heap") and
		heap_detail.contains("SCRAP 9 HP") and heap_detail.contains("STATUS: none") and
		not heap_detail.contains("BLEED") and not heap_detail.contains("MARK"),
		"scrap heap rank displays heap HP and STATUS: none without phantom statuses")
	_check(battle.state_snapshot() == heap_snapshot and battle.rng_state() == heap_rng and
		stage.receipts.size() == view_receipts,
		"inspecting empty and scrap-heap seats preserves snapshot, RNG and receipt count")
	stage._seat_buttons["foe_4"].mouse_exited.emit()
	_check(stage._labels["log"].text == ordinary_log,
		"exiting empty/heap rank seat restores the prior action message")
	for unit_id in saved_units:
		battle._units[unit_id] = saved_units[unit_id]
	battle._heaps = saved_heaps
	stage._refresh()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var boot = root.get_node_or_null("LiveWebPlaytestBoot")
	_check(boot != null, "Web startup boot autoload exists")
	_check(BOOT.SCREENS.has("stitched_battle") and
		boot.screen_from_query("?screen=stitched_battle") == "stitched_battle" and
		boot.screen_from_query("?screen=stitched_battle&screen=battle") == "",
		"only the exact, unambiguous public query is admitted")
	_check(StitchedRules.uses_card_combat(), "shipped cards mode remains project default")
	var config := StitchedBattleScreen.read_preview()
	_check(str(config.get("mode", "")) == "stitched" and config.get("heroes", []).size() == 4 and
		config.get("foes", []).size() == 3, "representative seed and real 4v3 inputs exist")
	var shipped_catalog := StitchedParts.build_catalog(config.get("parts", []))
	_check(bool(shipped_catalog.get("ok", false)) and not config.has("parts_path") and
		shipped_catalog.get("by_id", {}).has("warden_head_iron_helm") and
		shipped_catalog.get("by_id", {}).has("any_arm_red_thread"),
		"Web S2 data ships its own validated part entries; excluded test fixtures are not needed")
	var copy: Array = []
	for repetition in range(2):
		var app := _spawn()
		await process_frame
		var global_seed := 204915
		seed(global_seed)
		var expected_global := randi()
		seed(global_seed)
		var stage: StitchedBattleScreen = await _stage(app)
		if stage == null:
			app.free()
			continue
		await process_frame
		var battle := stage.battle
		_check(battle != null and battle.is_valid() and battle.get_heroes().size() == 4 and
			battle.get_foes().size() == 3 and stage._puppets.size() == 8,
			"mounted stage is seeded 4v3 with all 8 rank puppet seats")
		_check(stage._unit_at("foe", 4).is_empty() and
			stage._seat_buttons.has("foe_4") and not stage._puppets["foe_4"].visible,
			"fourth foe rank is empty, available only for a later summon")
		_check(stage.is_visible_in_tree() and not app.title_view.is_visible_in_tree() and
			app.run_map == null and app.deck == null and app.run_rng == null and app.run_deck.is_empty(),
			"public entry displays S2 without entering card battle or constructing card resources")
		_check(stage._labels["round"].text.contains("ROUND") and
			stage._labels["order"].text.contains("TURN ORDER") and
			stage._labels["candle"].text.contains("CANDLE") and
			stage._labels["stats"].text.contains("Fray") and
			stage._action_buttons["pass"].is_visible_in_tree(),
			"full round/order/candle/HP/fray/action overlays mounted at 1280x720")
		_check(randi() == expected_global, "public mounting consumes no global RNG")
		var pristine := battle.state_snapshot()
		var rng := battle.rng_state()
		_check(not (await boot.enter_preview(app, "stitched_battle")) and battle.state_snapshot() == pristine,
			"re-entering an already active preview rejects without rolls")
		_check(not bool(stage.submit_part("missing_part", 1).get("ok")) and
			not bool(stage.submit_part("missing_part", 5).get("ok")) and
			not bool(stage.submit_target("foe", 0).get("ok")) and
			not bool(stage.submit_target("foe", 5).get("ok")) and
			not bool(stage.submit_move(0).get("ok")) and
			not bool(stage.submit_re_tie().get("ok")),
			"wrong part, out-of-bounds rank, invalid move and unsnipped Re-tie fail closed")
		_check(battle.state_snapshot() == pristine and battle.rng_state() == rng,
			"every rejected action preserves complete authoritative state and RNG")
		var actor := battle.get_unit(battle.current_actor_id())
		_check(str(actor.get("side", "")) == "hero", "preview advances initial foe turns to a live hero")
		# Hover/selection is pure, including disabled-range calculations and repeated UI refresh.
		var selected := false
		for slot in StitchedBattleScreen.SLOTS:
			if stage.select_part(slot):
				selected = true
				for i in range(4):
					stage._refresh()
					var key := _rank_key(stage)
					if not key.is_empty():
						_check(stage.legal_targets().has(key), "preview exposes only actual legal target masks")
				break
		_check(selected and battle.state_snapshot() == pristine and battle.rng_state() == rng,
			"part selection and repeated hover previews spend no turn or RNG")
		_verify_status_readout(stage)
		_check(battle.state_snapshot() == pristine and battle.rng_state() == rng,
			"status readout fixture cleanup leaves pristine snapshot and RNG intact")
		# A torn equipped seam disables its own action, with no effect on the action receipt.
		var selected_slot := stage._selected_part
		if not selected_slot.is_empty():
			var worn: Dictionary = battle._units[battle.current_actor_id()]["parts"][selected_slot]
			worn["torn"] = true
			var torn_snapshot := battle.state_snapshot()
			_check(not stage.select_part(selected_slot) and
				not bool(stage.submit_part(str(worn["id"]), 1).get("ok")) and
				battle.state_snapshot() == torn_snapshot, "torn part cannot spend a turn or roll")
			worn["torn"] = false
			stage._refresh()
		# Snipped thread blocks swaps; Re-tie is only enabled with an actual authoritative cut.
		battle._thread_cuts[battle.current_actor_id()] = int(actor["rank"])
		var cut_snapshot := battle.state_snapshot()
		_check(not bool(stage.submit_move(1).get("ok")) and battle.state_snapshot() == cut_snapshot,
			"snipped thread refuses crossing without changing state or RNG")
		stage._refresh()
		_check(not stage._action_buttons["re_tie"].disabled and stage.battle.thread_cuts().has(battle.current_actor_id()),
			"Re-tie is enabled only for an authoritative snipped thread")
		var retie_before := stage.receipts.size()
		var retie := stage.submit_re_tie()
		_check(bool(retie.get("ok", false)) and stage.receipts.size() > retie_before and
			stage.receipts[retie_before].get("action") == "re_tie" and
			not battle.thread_cuts().has(str(retie.get("actor", ""))),
			"live Re-tie delegates once, clears the cut and spends the acting turn")
		var receipt_log := str(stage._labels["log"].text)
		var post_retie_snapshot := battle.state_snapshot()
		var post_retie_rng := battle.rng_state()
		var post_retie_receipts := stage.receipts.size()
		stage._seat_buttons["hero_1"].mouse_entered.emit()
		_check(stage._labels["log"].text == stage.status_detail("hero", 1) and
			stage._labels["log"].text != receipt_log,
			"hovering a seat after a committed turn inspects that seat's status detail")
		stage._seat_buttons["hero_1"].mouse_exited.emit()
		_check(stage._labels["log"].text == receipt_log and
			battle.state_snapshot() == post_retie_snapshot and
			battle.rng_state() == post_retie_rng and
			stage.receipts.size() == post_retie_receipts,
			"ending seat inspection restores the committed action receipt without spending RNG or turns")
		# Repeatable public trace: the same entrance and the same approved action sequence.
		stage.set_reduced_motion(true)
		_check(stage.reduced_motion and stage._puppets["hero_1"].is_processing() == false,
			"reduced motion suppresses puppet idle/attack tweens without changing combat")
		_check(stage.battle.current_side() == "hero", "foe AI returns control to heroes using legal authored abilities or Pass")
		_check(not _choose_legal(stage).is_empty(), "real mounted part control resolves a legal action")
		var after := battle.state_snapshot()
		_check(stage.receipts.size() > 1 and battle.rng_state() == int(after["rng_state"]),
			"recorded action and foe responses have one seeded authoritative RNG state")
		if repetition == 0:
			copy = [after, stage.receipts.duplicate(true)]
		else:
			_check(copy.size() == 2 and copy[0] == after and copy[1] == stage.receipts,
				"independent public entries replay identical state, RNG and ordered receipts")
		boot.exit_stitched_preview(app)
		await process_frame
		_check(boot.stitched_view == null and app.title_view.is_visible_in_tree() and
			app.run_map == null and app.deck == null, "exit unmounts isolated S2 and restores original title")
		var reopened: StitchedBattleScreen = await _stage(app)
		_check(reopened != null and reopened != stage and reopened.battle.is_valid() and
			reopened.battle.get_heroes().size() == 4, "re-entering after exit starts a fresh seeded Stitched session")
		if reopened != null and reopened.battle.current_side() == "hero":
			var direction := -1 if reopened._can_move(-1) else 1
			var move_before := reopened.receipts.size()
			var move_receipt := reopened.submit_move(direction)
			_check(bool(move_receipt.get("ok", false)) and reopened.receipts.size() > move_before and
				reopened.receipts[move_before].get("action") == "move",
				"real mounted Move delegates once and records its rank swap")
			var pass_before := reopened.receipts.size()
			var pass_receipt := reopened.submit_pass()
			_check(bool(pass_receipt.get("ok", false)) and reopened.receipts.size() > pass_before and
				reopened.receipts[pass_before].get("action") == "pass",
				"real mounted Pass delegates once and records a spent turn")
			var retreat_before := reopened.receipts.size()
			var retreat_rng := reopened.battle.rng_state()
			var retreat_receipt := reopened.submit_retreat()
			_check(bool(retreat_receipt.get("ok", false)) and reopened.receipts.size() > retreat_before and
				reopened.receipts[retreat_before].get("action") == "retreat" and
				reopened.battle.rng_state() != retreat_rng,
				"mounted Retreat rolls the seeded authority once and records success/failure")
		boot.exit_stitched_preview(app)
		await process_frame
		_check(app.title_view.is_visible_in_tree() and StitchedRules.uses_card_combat(),
			"exiting S2 leaves original card route available and card mode unchanged")
		app.free()
		await process_frame
	for failure in failures:
		printerr(failure)
	print("stitched_s2_battle_screen_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
