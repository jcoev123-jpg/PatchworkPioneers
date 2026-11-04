extends SceneTree
## S6: genuine won Roadblock -> Leave without Mend -> same torn gear in next Fight.
var failures: Array[String] = []
var checks := 0
const NODE := "s5_scissor_crab_sewing_circle"


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures.append(note)


func _no_wallet(app: Node) -> bool:
	return app.deck == null and app.run_map == null and app.run_rng == null \
		and app.session_gold == 0 and app.run_scraps == 0 and app.run_deck.is_empty()


func _admit(app: Node) -> StitchedBattleScreen:
	app.stitched_fight_button.pressed.emit()
	await process_frame
	var offer: LiveEventChoicePanel = app.stitched_event_panel
	if offer == null or not offer.has_open_event() or offer.get_choice_buttons().size() != 3:
		return null
	var button: Button = offer.get_choice_buttons()[0]
	if button.disabled:
		return null
	button.pressed.emit()
	await process_frame
	return app.stitched_fight_view


func _victory(stage: StitchedBattleScreen) -> Dictionary:
	if stage == null or stage.battle == null or not stage.battle.is_valid():
		return {}
	var steps := 0
	var abilities := 0
	for iteration in range(90):
		if stage.battle.is_over() or stage.battle.current_side() != "hero":
			break
		var actor: Dictionary = stage.battle.get_unit(stage.battle.current_actor_id())
		var best_score := -10000
		var best_id := ""
		var best_rank := 0
		for slot in StitchedParts.SLOTS:
			if not stage._valid_part(actor, actor["parts"][slot]):
				continue
			var id := str(actor["parts"][slot]["id"])
			var definition: Dictionary = stage.parts.get(id, {})
			var skill: Dictionary = StitchedParts.ability_at_tier(
				definition, int(actor["parts"][slot]["tier"]))
			for rank in range(1, 5):
				var legal: Array = stage.battle._legal_targets(actor, skill, rank)
				if legal.is_empty():
					continue
				var score := -20
				if str(legal[0]["side"]) == "foe":
					score = int(skill.get("dmg", [0, 0])[1]) * 4 + int(skill.get("dmg", [0, 0])[0])
					if str(skill.get("kind", "")) == "ranged":
						score += 1
					if rank == 1:
						score += 3
				elif str(skill.get("kind", "")) == "heal":
					var ally: Dictionary = stage._unit_at("hero", rank)
					var missing: int = int(ally.get("max_hp", 0)) - int(ally.get("hp", 0))
					if missing >= 8:
						score = 38 + missing
				if score > best_score:
					best_score = score
					best_id = id
					best_rank = rank
		var receipt: Dictionary
		if not best_id.is_empty():
			receipt = stage.submit_part(best_id, best_rank)
			if receipt.get("ok") == true and receipt.get("action") == "ability":
				abilities += 1
		else:
			receipt = stage.submit_pass()
		if receipt.get("ok") != true:
			break
		steps += 1
	return {"steps": steps, "abilities": abilities, "outcome": stage.battle.outcome(),
		"foes": stage.battle.get_foes().duplicate(true)}


func _trace() -> Dictionary:
	var app: Node = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await process_frame
	_check(app._stitched_gear_overrides.is_empty() and app.stitched_preview_scraps == 0
		and _no_wallet(app), "fresh title has no carried parts, scraps or legacy resources")
	# No non-victory route may open the Circle or invent a torn-gear carry.
	var aborted: StitchedBattleScreen = await _admit(app)
	_check(aborted != null and aborted.battle != null and aborted.battle.is_valid(),
		"first public title Roadblock is genuinely mounted")
	if aborted == null:
		app.free()
		await process_frame
		return {}
	aborted._action_buttons["exit"].pressed.emit()
	await process_frame
	_check(app.stitched_sewing_panel == null and app._stitched_gear_overrides.is_empty()
		and app.stitched_preview_scraps == 0, "unwon exit grants neither Circle nor override")
	var first: StitchedBattleScreen = await _admit(app)
	if first == null:
		_check(false, "won battle needs authenticated Fight admission")
		app.free()
		await process_frame
		return {}
	var won := _victory(first)
	_check(won.get("outcome") == "victory" and int(won.get("steps", 0)) > 0
		and int(won.get("abilities", 0)) > 0 and won.get("foes", []).size() == 3,
		"all three foes defeated via mounted legal combat actions")
	if won.get("outcome") != "victory":
		first._action_buttons["exit"].pressed.emit()
		await process_frame
		app.free()
		await process_frame
		return {}
	# Only a surviving hero's torn flag is controlled AFTER genuine victory.
	var hero_id := ""
	var original_parts: Dictionary = {}
	for hero in first.battle.get_heroes():
		if not bool(hero.get("lost", false)):
			hero_id = str(hero["id"])
			original_parts = hero["parts"].duplicate(true)
			first.battle._units[hero_id]["parts"]["arms"]["torn"] = true
			break
	_check(not hero_id.is_empty() and original_parts.size() == StitchedParts.SLOTS.size()
		and original_parts["arms"]["id"] != "", "real surviving combat hero is torn only after victory")
	if hero_id.is_empty():
		app.free()
		await process_frame
		return {}
	var torn: Dictionary = original_parts["arms"].duplicate(true)
	torn["torn"] = true
	var intact: Dictionary = original_parts.duplicate(true)
	intact["arms"] = torn.duplicate(true)
	first._action_buttons["exit"].pressed.emit()
	await process_frame
	var panel: Control = app.stitched_sewing_panel
	var swap: RunStitchedSewingSwap = app.stitched_sewing_visit
	var mend: RunStitchedSewingMend = app.stitched_sewing_mend_visit
	_check(panel != null and swap != null and mend != null
		and app.stitched_fight_view == null and app.stitched_preview_scraps == 1
		and app.stitched_preview_satchel.size() == 3 and _no_wallet(app),
		"win mints one genuine scrap and three trophies, then mounts both Circle services")
	if panel == null or swap == null or mend == null:
		app.free()
		await process_frame
		return {}
	var displayed: Dictionary = app._stitched_sewing_quote["state"].duplicate(true)
	var mend_displayed: Dictionary = app._stitched_mend_quote["state"].duplicate(true)
	var part_in_circle: Dictionary = {}
	for hero in displayed["heroes"]:
		if str(hero["id"]) == hero_id:
			part_in_circle = hero["parts"]
	_check(part_in_circle == intact and displayed["heroes"] == mend_displayed["heroes"]
		and displayed["satchel"] == app.stitched_preview_satchel,
		"both live services display the same torn arm and other unchanged slots")
	var disabled: Button = panel.find_child("Mend_%s_arms" % hero_id, true, false) as Button
	_check(disabled != null and disabled.disabled and disabled.text.contains("insufficient scraps"),
		"one genuine scrap cannot silently repair torn arms")
	var before_overrides: Dictionary = app._stitched_gear_overrides.duplicate(true)
	var before_satchel: Array = app.stitched_preview_satchel.duplicate(true)
	var stale: Dictionary = displayed.duplicate(true)
	stale["version"] = -1
	seed(61544)
	var expected_rng := randi()
	seed(61544)
	_check(not app._stitched_sewing_leave(stale, weakref(panel)).get("ok")
		and not app._stitched_sewing_leave(displayed, null).get("ok")
		and not swap.leave("wrong-node", displayed).get("ok")
		and not mend.leave("wrong-node", mend_displayed).get("ok")
		and app._stitched_gear_overrides == before_overrides
		and swap.read_state() == displayed and mend.read_state() == mend_displayed
		and app.stitched_preview_scraps == 1 and app.stitched_preview_satchel == before_satchel
		and randi() == expected_rng and _no_wallet(app),
		"stale/forged/wrong-node Leave denied without resources, authority, gear or RNG changes")
	var leave: Button = panel.get_node("SewingLeave")
	leave.pressed.emit()
	var carried: Dictionary = app._stitched_gear_overrides.duplicate(true)
	var leave_ok: bool = app.stitched_sewing_panel == null and app.stitched_sewing_visit == null
	leave_ok = leave_ok and app.stitched_sewing_mend_visit == null
	leave_ok = leave_ok and not swap.read_state()["open"] and not mend.read_state()["open"]
	leave_ok = leave_ok and int(swap.read_state()["version"]) == int(displayed["version"]) + 1
	leave_ok = leave_ok and int(mend.read_state()["version"]) == int(mend_displayed["version"]) + 1
	leave_ok = leave_ok and swap.read_state()["heroes"] == mend.read_state()["heroes"]
	leave_ok = leave_ok and carried.get(hero_id, {}).get("arms") == torn
	leave_ok = leave_ok and app.stitched_preview_scraps == 1
	leave_ok = leave_ok and app.stitched_preview_satchel == before_satchel and _no_wallet(app)
	_check(leave_ok, "one displayed Leave closes both receipts and carries precise still-torn arm")
	var closed: Dictionary = carried.duplicate(true)
	leave.pressed.emit()
	_check(not app._stitched_sewing_leave(displayed, weakref(panel)).get("ok")
		and not swap.leave(NODE, displayed).get("ok")
		and not mend.leave(NODE, mend_displayed).get("ok")
		and app._stitched_gear_overrides == closed and app.stitched_preview_scraps == 1,
		"old displayed callbacks and closed receipts cannot replay a carry or spend")
	await process_frame
	var config: Dictionary = app._stitched_floor_config()
	var expected_parts: Dictionary = {}
	for hero in config.get("heroes", []):
		if str(hero["id"]) == hero_id:
			expected_parts = hero["parts"]
	var same_parts := expected_parts.size() == StitchedParts.SLOTS.size()
	for slot in StitchedParts.SLOTS:
		same_parts = same_parts and expected_parts.get(slot) == intact.get(slot)
	_check(same_parts and config.get("seed") == 4982026 and config.get("foes", []).size() == 3,
		"next authenticated floor input retains torn ID/tier/flag and all untouched slots")
	var second: StitchedBattleScreen = await _admit(app)
	_check(second != null and second.battle != null and second.battle.is_valid(),
		"real second Fight is mounted by title Roadblock button, not a fixture")
	var trace: Dictionary = {}
	if second != null and second.battle != null:
		var unit: Dictionary = second.battle.get_unit(hero_id)
		var arms: Dictionary = unit.get("parts", {}).get("arms", {})
		var correct := arms == torn and not second._valid_part(unit, arms)
		for slot in ["head", "torso", "legs"]:
			correct = correct and unit.get("parts", {}).get(slot) == intact.get(slot)
		_check(correct, "new real battle has torn original arm disabled, intact parts unchanged")
		var witness_turn := false
		var illegal_no_spend := false
		var legal_intact := false
		for turn in range(30):
			if second.battle.is_over() or second.battle.current_side() != "hero":
				break
			if second.battle.current_actor_id() == hero_id:
				witness_turn = true
				var snapshot: Dictionary = second.battle.state_snapshot()
				var rng_before: int = second.battle.rng_state()
				var count_before := second.receipts.size()
				var denied: Dictionary = second.submit_part(str(torn["id"]), 1)
				illegal_no_spend = denied.get("ok") != true and not second.select_part("arms") \
					and second.battle.state_snapshot() == snapshot \
					and second.battle.rng_state() == rng_before \
					and second.receipts.size() == count_before
				legal_intact = second._valid_part(second.battle.get_unit(hero_id), intact["head"])
				break
			second.submit_pass()
		_check(witness_turn and illegal_no_spend and legal_intact,
			"actual next hero turn refuses torn ability without action/RNG spend; intact ability remains legal")
		trace = {"parts": unit["parts"].duplicate(true), "config": expected_parts.duplicate(true),
			"opening": second.battle.opening_strike(), "scraps": app.stitched_preview_scraps,
			"satchel": app.stitched_preview_satchel.duplicate(true),
			"candle": app.stitched_roadblock_candle}
		second._action_buttons["exit"].pressed.emit()
		await process_frame
		_check(app.stitched_sewing_panel == null and app._stitched_gear_overrides == closed
			and app.stitched_preview_scraps == 1 and _no_wallet(app),
			"unfinished second Fight cannot repair gear, mint reward or change old carry")
	app.free()
	await process_frame
	return trace


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var one: Dictionary = await _trace()
	var two: Dictionary = await _trace()
	_check(not one.is_empty() and one == two,
		"two fresh identical public Roadblock/Victory/Leave/Fight traces reproduce same carried gear and opening")
	for failure in failures:
		printerr(failure)
	print("stitched_s6_torn_carry_live_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
