extends SceneTree
## S6: genuine Roadblock victories fund exactly one mounted torn-arms Mend.
var failures: Array[String] = []
var checks := 0
const NODE := "s5_scissor_crab_sewing_circle"
const CLAW := "scissor_crab_claw_arm"


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
	offer.get_choice_buttons()[0].pressed.emit()
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


func _torn_witness(stage: StitchedBattleScreen) -> Dictionary:
	for hero in stage.battle.get_heroes():
		if not bool(hero.get("lost", false)):
			var hero_id := str(hero["id"])
			var part: Dictionary = hero["parts"]["arms"].duplicate(true)
			stage.battle._units[hero_id]["parts"]["arms"]["torn"] = true
			return {"hero_id": hero_id, "part": part}
	return {}


func _finish(app: Node) -> void:
	if is_instance_valid(app):
		app.free()
	await process_frame
	for failure in failures:
		printerr(failure)
	print("stitched_s6_sewing_mend_live_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var app: Node = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await process_frame
	_check(app.stitched_preview_scraps == 0 and app.stitched_preview_satchel.is_empty()
		and _no_wallet(app), "real title starts with no earned preview scrap, spoils or legacy wallet")
	var unfinished: StitchedBattleScreen = await _admit(app)
	_check(unfinished != null and unfinished.battle.is_valid(),
		"an authenticated live Fight is mounted before any reward")
	if unfinished == null:
		await _finish(app)
		return
	unfinished._action_buttons["exit"].pressed.emit()
	await process_frame
	_check(app.stitched_preview_scraps == 0 and app.stitched_sewing_panel == null
		and _no_wallet(app), "unwon exit cannot award scrap or open Mend")
	var first: StitchedBattleScreen = await _admit(app)
	if first == null:
		_check(false, "first authentic earning Fight admitted")
		await _finish(app)
		return
	var first_win := _victory(first)
	_check(first_win.get("outcome") == "victory" and int(first_win.get("steps", 0)) > 0
		and int(first_win.get("abilities", 0)) > 0 and first_win.get("foes", []).size() == 3,
		"the first Roadblock is won via live abilities, not a forced outcome")
	if first_win.get("outcome") != "victory":
		await _finish(app)
		return
	var torn_one := _torn_witness(first)
	_check(not torn_one.is_empty(), "first won battle has a real surviving torn-arm witness")
	first._action_buttons["exit"].pressed.emit()
	await process_frame
	var panel: Control = app.stitched_sewing_panel
	var mend: RunStitchedSewingMend = app.stitched_sewing_mend_visit
	var swap: RunStitchedSewingSwap = app.stitched_sewing_visit
	var disabled: Button = panel.find_child("Mend_%s_arms" % torn_one.get("hero_id", ""), true, false) as Button if panel != null else null
	_check(panel != null and mend != null and swap != null
		and app.stitched_preview_scraps == 1 and mend.read_state().get("scraps") == 1
		and disabled != null and disabled.disabled and disabled.focus_mode == Control.FOCUS_NONE
		and disabled.text.contains("insufficient scraps") and _no_wallet(app),
		"first real victory earns exactly one scrap and shows a disabled two-scrap Mend")
	if panel == null:
		await _finish(app)
		return
	var one_state: Dictionary = mend.read_state()
	seed(271801)
	var one_rng := randi()
	seed(271801)
	_check(not app._stitched_sewing_mend(str(torn_one["hero_id"]), "arms",
		one_state, weakref(panel)).get("ok")
		and mend.read_state() == one_state and app.stitched_preview_scraps == 1
		and randi() == one_rng and _no_wallet(app),
		"one earned scrap cannot be spent or grant Mend")
	panel.get_node("SewingLeave").pressed.emit()
	await process_frame
	_check(app.stitched_sewing_panel == null and app.stitched_sewing_mend_visit == null
		and app.stitched_sewing_visit == null and not mend.read_state()["open"]
		and app.stitched_preview_scraps == 1, "Leave retires both visit authorities but preserves earned scraps")
	var second: StitchedBattleScreen = await _admit(app)
	if second == null:
		_check(false, "second authenticated earning Fight admitted")
		await _finish(app)
		return
	var second_win := _victory(second)
	_check(second_win.get("outcome") == "victory" and int(second_win.get("abilities", 0)) > 0
		and int(second_win.get("steps", 0)) > 0 and second_win.get("foes", []).size() == 3,
		"second scrap requires a second genuine terminal Roadblock victory")
	if second_win.get("outcome") != "victory":
		await _finish(app)
		return
	var torn_two := _torn_witness(second)
	_check(not torn_two.is_empty(), "second won Fight supplies the same real kind of torn arms")
	second._action_buttons["exit"].pressed.emit()
	await process_frame
	panel = app.stitched_sewing_panel
	mend = app.stitched_sewing_mend_visit
	swap = app.stitched_sewing_visit
	if panel == null or mend == null or swap == null:
		_check(false, "two earned scraps mount both Sewing Circle services")
		await _finish(app)
		return
	var button: Button = panel.find_child("Mend_%s_arms" % torn_two["hero_id"], true, false) as Button
	var quote := mend.quote()
	var before: Dictionary = mend.read_state()
	var swap_before: Dictionary = swap.read_state()
	var satchel_before: Array = app.stitched_preview_satchel.duplicate(true)
	var gear_before: Dictionary = app._stitched_gear_overrides.duplicate(true)
	_check(app.stitched_preview_scraps == 2 and before["scraps"] == 2 and before["mend_cost"] == 2
		and button != null and not button.disabled and button.focus_mode != Control.FOCUS_NONE
		and quote.get("ok") == true and before["heroes"] == swap_before["heroes"]
		and _no_wallet(app), "exactly two earned scraps expose a live and keyboard-usable Mend button")
	if button == null:
		await _finish(app)
		return
	var forged: Dictionary = before.duplicate(true)
	forged["scraps"] = 99
	seed(763321)
	var reject_rng := randi()
	seed(763321)
	_check(not mend.mend(str(torn_two["hero_id"]), "arms", "wrong-node", before).get("ok")
		and not mend.mend(str(torn_two["hero_id"]), "arms", NODE, forged).get("ok")
		and not app._stitched_sewing_mend("impostor", "arms", before, weakref(panel)).get("ok")
		and not app._stitched_sewing_mend(str(torn_two["hero_id"]), "torso", before, weakref(panel)).get("ok")
		and mend.read_state() == before and swap.read_state() == swap_before
		and app.stitched_preview_scraps == 2 and app.stitched_preview_satchel == satchel_before
		and app._stitched_gear_overrides == gear_before and randi() == reject_rng and _no_wallet(app),
		"forged, wrong-node, unoffered and wrong-slot mends fail closed without state/RNG/wallet changes")
	button.pressed.emit()
	var repaired: Dictionary = mend.read_state()
	var repaired_id := str(torn_two["hero_id"])
	var original_part: Dictionary = torn_two["part"].duplicate(true)
	original_part["torn"] = false
	var repaired_arms: Dictionary = {}
	for hero in repaired["heroes"]:
		if str(hero["id"]) == repaired_id:
			repaired_arms = hero["parts"]["arms"]
	_check(app.stitched_preview_scraps == 0 and repaired["scraps"] == 0
		and repaired_arms == original_part and app._stitched_gear_overrides.get(repaired_id, {}).get("arms") == original_part
		and app.stitched_sewing_visit.read_state()["heroes"] == repaired["heroes"]
		and app.stitched_preview_satchel == satchel_before and _no_wallet(app),
		"real Mend button charges exactly two scraps once, repairs precise existing gear and synchronizes swap")
	seed(764441)
	var replay_rng := randi()
	seed(764441)
	_check(not app._stitched_sewing_mend(repaired_id, "arms", before, weakref(panel)).get("ok")
		and not mend.mend(repaired_id, "arms", NODE, before).get("ok")
		and not mend.mend(repaired_id, "arms", NODE, repaired).get("ok")
		and app.stitched_preview_scraps == 0 and mend.read_state() == repaired
		and randi() == replay_rng and _no_wallet(app),
		"stale, repeated and already-repaired requests never double charge")
	var stale_swap: RunStitchedSewingSwap = swap
	_check(not stale_swap.read_state()["open"],
		"repair retires the former swap authority rather than allowing a stale worn-part quote")
	var first_swap: Button = panel.find_child("Swap_%s_0" % repaired_id, true, false) as Button
	_check(first_swap != null and not first_swap.disabled,
		"formerly torn arms now have an offered legitimate trophy swap")
	if first_swap == null:
		await _finish(app)
		return
	first_swap.pressed.emit()
	var swapped: Dictionary = app.stitched_sewing_visit.read_state()
	_check(swapped["satchel"][0] == {"id": original_part["id"], "slot": "arms",
		"tier": original_part["tier"], "torn": false}
		and app._stitched_gear_overrides.get(repaired_id, {}).get("arms", {}).get("id") == CLAW
		and app.stitched_sewing_mend_visit.read_state()["heroes"] == swapped["heroes"]
		and app.stitched_preview_scraps == 0,
		"lawful post-Mend swap stores the repaired, untorn arm without a second charge")
	var recipient := ""
	for hero in swapped["heroes"]:
		if str(hero["id"]) != repaired_id and not bool(hero.get("lost", false)):
			recipient = str(hero["id"])
			break
	_check(not recipient.is_empty(), "there is a second surviving real wearer for the repaired arm")
	if recipient.is_empty():
		await _finish(app)
		return
	var second_swap: Button = panel.find_child("Swap_%s_0" % recipient, true, false) as Button
	_check(second_swap != null and not second_swap.disabled,
		"same visit offers the repaired arm after the trophy exchange")
	if second_swap == null:
		await _finish(app)
		return
	second_swap.pressed.emit()
	var after_swaps: Dictionary = app.stitched_sewing_visit.read_state()
	_check(app._stitched_gear_overrides.get(recipient, {}).get("arms") == original_part
		and after_swaps["heroes"] == app.stitched_sewing_mend_visit.read_state()["heroes"]
		and app.stitched_preview_scraps == 0 and _no_wallet(app),
		"two consecutive compatible swaps preserve repaired tier/id/torn state and synchronized Mend quotes")
	var closed_mend: RunStitchedSewingMend = app.stitched_sewing_mend_visit
	var closed_swap: RunStitchedSewingSwap = app.stitched_sewing_visit
	panel.get_node("SewingLeave").pressed.emit()
	await process_frame
	_check(app.stitched_sewing_panel == null and app.stitched_sewing_visit == null
		and app.stitched_sewing_mend_visit == null and not closed_mend.read_state()["open"]
		and not closed_swap.read_state()["open"]
		and not app._stitched_sewing_mend(repaired_id, "arms", repaired, weakref(panel)).get("ok"),
		"Leave retires both services; stale Mend callbacks cannot reopen the Circle")
	var next: StitchedBattleScreen = await _admit(app)
	_check(next != null and next.battle != null and next.battle.is_valid(),
		"fresh authentic Roadblock Fight mounts after repaired Circle visit")
	if next != null and next.battle != null:
		_check(next.battle.get_unit(repaired_id).get("parts", {}).get("arms", {}).get("id") == CLAW
			and next.battle.get_unit(recipient).get("parts", {}).get("arms") == original_part
			and _no_wallet(app),
			"the next real Fight equips the trophy and exact repaired part on their lawful wearers")
		next._action_buttons["exit"].pressed.emit()
		await process_frame
	_check(app.stitched_preview_scraps == 0 and app.stitched_sewing_panel == null
		and _no_wallet(app), "unwon next Fight cannot refund mending or mint another scrap")
	await _finish(app)
