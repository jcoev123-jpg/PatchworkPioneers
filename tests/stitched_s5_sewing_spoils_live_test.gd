extends SceneTree
## S5: authentic title Roadblock victory -> displayed Sewing Circle -> next Fight Snip.
var failures: Array[String] = []
var checks := 0
const CLAW := "scissor_crab_claw_arm"


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures.append(note)


func _spawn() -> Node:
	var app: Node = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	return app


func _no_wallet(app: Node) -> bool:
	return app.deck == null and app.run_map == null and app.run_rng == null \
		and app.session_gold == 0 and app.run_scraps == 0 and app.run_deck.is_empty()


func _admit(app: Node) -> StitchedBattleScreen:
	app.stitched_fight_button.pressed.emit()
	# Let the authored Roadblock's deferred focus settle, as real input does.
	await process_frame
	var offer: LiveEventChoicePanel = app.stitched_event_panel
	if offer == null or not offer.has_open_event() or offer.get_choice_buttons().size() != 3:
		return null
	offer.get_choice_buttons()[0].pressed.emit()
	await process_frame
	return app.stitched_fight_view


func _fight_to_victory(stage: StitchedBattleScreen) -> Dictionary:
	if stage == null or stage.battle == null:
		return {}
	var initial: Dictionary = stage.battle.state_snapshot()
	var steps := 0
	var abilities := 0
	# All damage, healing and enemy replies go through the mounted screen,
	# never through fixture HP edits, outcome assignment, or a mock service.
	for iteration in range(90):
		if stage.battle.is_over():
			break
		if stage.battle.current_side() != "hero":
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
				var side := str(legal[0]["side"])
				var score := -20
				if side == "foe":
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
	return {"initial": initial, "steps": steps, "abilities": abilities,
		"outcome": stage.battle.outcome(), "state": stage.battle.state_snapshot(),
		"rng": stage.battle.rng_state(), "receipts": stage.receipts.duplicate(true)}


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var app := _spawn()
	await process_frame
	_check(_no_wallet(app) and app.stitched_preview_satchel.is_empty(),
		"the title begins without a virtual wallet or pre-awarded claw")
	var escape: StitchedBattleScreen = await _admit(app)
	_check(escape != null and escape.battle.is_valid() and app.stitched_sewing_panel == null,
		"a genuine Roadblock Fight is mounted before any spoils exist")
	if escape == null:
		_finish()
		return
	escape._action_buttons["exit"].pressed.emit()
	await process_frame
	_check(app.stitched_preview_satchel.is_empty() and app.stitched_sewing_visit == null \
		and app.title_view.is_visible_in_tree() and _no_wallet(app),
		"unwon Back produces no claw and restores title")
	var retreat: StitchedBattleScreen = await _admit(app)
	_check(retreat != null and retreat.battle.is_valid(), "a second authenticated Roadblock is available")
	if retreat == null:
		_finish()
		return
	for turn in range(100):
		if retreat.battle.is_over():
			break
		if retreat.battle.current_side() != "hero":
			break
		retreat._action_buttons["retreat"].pressed.emit()
	_check(retreat.battle.is_over() and retreat.battle.outcome() in ["retreated", "defeat"],
		"non-victory is terminal combat, not a fabricated outcome")
	retreat._action_buttons["exit"].pressed.emit()
	await process_frame
	_check(app.stitched_preview_satchel.is_empty() and app.stitched_sewing_panel == null \
		and _no_wallet(app), "terminal non-victory never mints a claw or opens the Circle")
	var stage: StitchedBattleScreen = await _admit(app)
	if stage == null:
		_check(false, "winner fight admitted through the real title")
		_finish()
		return
	var witness := _fight_to_victory(stage)
	_check(int(witness.get("steps", 0)) > 0 and int(witness.get("abilities", 0)) > 0 \
		and stage.battle.get_foes().size() == 3 and stage.battle.get_unit("scissor_crab").get("dead") == true \
		and witness.get("outcome") == "victory",
		"mounted hero actions defeat all foes including Crab: " + str(witness.get("outcome", "")) + " / steps=" + str(witness.get("steps", 0)))
	if witness.get("outcome") != "victory":
		stage._action_buttons["exit"].pressed.emit()
		await process_frame
		_finish()
		return
	# A naturally earned post-battle service must also reject torn worn gear.
	# Force only this negative precondition on a real battle unit; combat
	# admission, kills, victory and all reward settlement remain live.
	var torn_hero := ""
	for hero in stage.battle.get_heroes():
		if not bool(hero.get("lost", false)):
			torn_hero = str(hero["id"])
			stage.battle._units[torn_hero]["parts"]["arms"]["torn"] = true
			break
	_check(not torn_hero.is_empty(), "a surviving real hero supplies the torn-gear witness")
	seed(820151)
	var expected_global := randi()
	seed(820151)
	var old_stage := stage
	stage._action_buttons["exit"].pressed.emit()
	var visit: RunStitchedSewingSwap = app.stitched_sewing_visit
	var panel: Control = app.stitched_sewing_panel
	_check(app.stitched_fight_view == null and old_stage.battle == null \
		and visit != null and panel != null and panel.is_visible_in_tree() \
		and not app.title_view.is_visible_in_tree(),
		"completed battle retires its authority before a gothic Sewing Circle is mounted")
	if panel == null or visit == null:
		_finish()
		return
	await process_frame
	var quote: Dictionary = visit.quote()
	_check(quote.get("ok") == true and quote.get("open") == true \
		and quote.get("satchel_count") == 1 and quote.get("satchel_max") == 6 \
		and quote["satchel"][0]["id"] == CLAW and quote["satchel"][0]["tier"] == 1 \
		and not quote["satchel"][0]["torn"] and _no_wallet(app),
		"one authentic tier-I untorn claw is shown in a bounded satchel")
	var blocked_torn := false
	for hero_row in quote["heroes"]:
		if str(hero_row["hero_id"]) != torn_hero:
			continue
		for slot_row in hero_row["slots"]:
			if str(slot_row["slot"]) == "arms":
				blocked_torn = not bool(slot_row["can_swap"]) \
					and str(slot_row["blocked"]).contains("torn") \
					and slot_row["offers"].is_empty()
	_check(blocked_torn, "the real mounted Circle shows a torn arm as blocked, with no offered swap")
	var buttons: Array = panel.find_children("Swap_*", "Button", true, false)
	var offers_found := 0
	var winner_id := ""
	for hero_row in quote["heroes"]:
		for slot_row in hero_row["slots"]:
			if str(slot_row["slot"]) == "arms" and bool(slot_row["can_swap"]):
				for option in slot_row["offers"]:
					if option["part"]["id"] == CLAW:
						offers_found += 1
						if winner_id.is_empty():
							winner_id = str(hero_row["hero_id"])
	_check(offers_found > 0 and buttons.size() == offers_found and not winner_id.is_empty(),
		"the displayed choice buttons exactly match real compatible hero/arms quotes")
	var old_state: Dictionary = quote["state"].duplicate(true)
	var before_satchel: Array = app.stitched_preview_satchel.duplicate(true)
	_check(not app._stitched_sewing_swap(torn_hero, "arms", 0, old_state, weakref(panel)).get("ok") \
		and not app._stitched_sewing_swap(winner_id, "legs", 0, old_state, weakref(panel)).get("ok") \
		and not app._stitched_sewing_swap(winner_id, "arms", 9, old_state, weakref(panel)).get("ok") \
		and not app._stitched_sewing_swap("impostor", "arms", 0, old_state, weakref(panel)).get("ok") \
		and app.stitched_preview_satchel == before_satchel \
		and visit.read_state() == old_state and randi() == expected_global and _no_wallet(app),
		"forged hero, wrong slot, invalid index leave items, versions, RNG and wallet untouched")
	var old_button: Button = buttons[0]
	var selected_id := str(old_button.name).trim_prefix("Swap_").rsplit("_", true, 1)[0]
	var equipped_before: Array = app._stitched_floor_config()["heroes"].duplicate(true)
	old_button.pressed.emit()
	var committed: Dictionary = visit.read_state()
	_check(int(committed.get("version", 0)) == 1 and committed["satchel"].size() == 1 \
		and committed["satchel"][0]["id"] != CLAW \
		and app._stitched_gear_overrides.get(selected_id, {}).get("arms", {}).get("id") == CLAW \
		and app.stitched_preview_satchel == committed["satchel"] and _no_wallet(app),
		"visible Sewing Circle click commits once, replacing the old arms without spending")
	var changed_before := committed.duplicate(true)
	seed(340721)
	var replay_expected := randi()
	seed(340721)
	_check(not app._stitched_sewing_swap(selected_id, "arms", 0, old_state, weakref(panel)).get("ok") \
		and not visit.swap(selected_id, "arms", 0, "wrong-node", old_state).get("ok") \
		and not visit.swap(selected_id, "arms", 0, "s5_scissor_crab_sewing_circle", old_state).get("ok") \
		and visit.read_state() == changed_before \
		and app.stitched_preview_satchel == committed["satchel"] and randi() == replay_expected,
		"duplicate, stale and wrong-node commits are rejected without inventory mutation")
	# Test RNG rejection using a fresh known global seed (previous check read once).
	seed(559201)
	var rng_expected := randi()
	seed(559201)
	var fresh_state: Dictionary = visit.read_state()
	_check(not app._stitched_sewing_swap(selected_id, "torso", 0, fresh_state, weakref(panel)).get("ok") \
		and not app._stitched_sewing_leave(old_state, weakref(panel)).get("ok") \
		and visit.read_state() == fresh_state and randi() == rng_expected and _no_wallet(app),
		"wrong-slot and stale Leave fail closed without spending or RNG")
	var leave: Button = panel.get_node("SewingLeave")
	leave.pressed.emit()
	_check(app.stitched_sewing_panel == null and app.stitched_sewing_visit == null \
		and app.title_view.is_visible_in_tree() and app.stitched_preview_satchel.size() == 1,
		"mounted Leave closes the Circle exactly once and restores title")
	_check(not app._stitched_sewing_leave(fresh_state, weakref(panel)).get("ok") \
		and not app._stitched_sewing_swap(selected_id, "arms", 0, fresh_state, weakref(panel)).get("ok"),
		"stale callbacks cannot reopen or change equipment after Leave")
	await process_frame
	var next_config: Dictionary = app._stitched_floor_config()
	var expected_gear: Dictionary = {}
	for hero in equipped_before:
		if str(hero["id"]) == selected_id:
			expected_gear = hero["parts"]
	var selected_next: Dictionary = {}
	for hero in next_config["heroes"]:
		if str(hero["id"]) == selected_id:
			selected_next = hero["parts"]
	var gear_ok: bool = selected_next.get("arms", {}).get("id") == CLAW
	for slot in ["head", "torso", "legs"]:
		gear_ok = gear_ok and selected_next.get(slot) == expected_gear.get(slot)
	_check(gear_ok and next_config.get("seed") == 4982026 and next_config["foes"].size() == 3,
		"next title config carries only the exchanged arms, preserving other gear, foes and replay seed")
	var next: StitchedBattleScreen = await _admit(app)
	_check(next != null and next.battle.get_unit(selected_id).get("parts", {}).get("arms", {}).get("id") == CLAW,
		"next authenticated Roadblock Fight actually equips the carried claw")
	if next != null:
		var snip_ok := false
		for turn in range(45):
			if next.battle.is_over() or next.battle.current_side() != "hero":
				break
			if next.battle.current_actor_id() == selected_id and next.select_part("arms"):
				for key in next.legal_targets():
					if str(key).begins_with("foe_"):
						var before_count := next.receipts.size()
						var result: Dictionary = next.submit_target("foe", int(str(key).split("_")[1]))
						snip_ok = result.get("ok") == true and next.receipts.size() > before_count \
							and str(result.get("ability")) == "snip"
						break
			if snip_ok:
				break
			next.submit_pass()
		_check(snip_ok, "authored Snip executes through the mounted next Fight and emits a combat receipt")
		next._action_buttons["exit"].pressed.emit()
	await process_frame
	_check(app.stitched_sewing_panel == null and _no_wallet(app),
		"non-victory second Fight adds no new drops or wallet")
	# A cap-state representing six previously earned parts receives no seventh
	# drop, even after another *real* mounted Scissor Crab victory.
	var full_satchel: Array = []
	for index in range(RunStitchedSewingSwap.SATCHEL_CAP):
		full_satchel.append({"id": CLAW, "slot": "arms", "tier": 1, "torn": false})
	app.stitched_preview_satchel = full_satchel.duplicate(true)
	var cap_stage: StitchedBattleScreen = await _admit(app)
	if cap_stage != null:
		var cap_witness: Dictionary = _fight_to_victory(cap_stage)
		_check(cap_witness.get("outcome") == "victory" and int(cap_witness.get("steps", 0)) > 0,
			"full-cap test still defeats Scissor Crab through an authenticated mounted Fight")
		if cap_witness.get("outcome") == "victory":
			seed(901721)
			var cap_rng := randi()
			seed(901721)
			cap_stage._action_buttons["exit"].pressed.emit()
			var cap_visit: RunStitchedSewingSwap = app.stitched_sewing_visit
			_check(cap_visit != null and app.stitched_preview_satchel == full_satchel \
				and cap_visit.quote().get("satchel_count") == RunStitchedSewingSwap.SATCHEL_CAP \
				and randi() == cap_rng and _no_wallet(app),
				"a full satchel prevents a seventh drop without RNG or wallet mutation")
			if cap_visit != null:
				var cap_panel: Control = app.stitched_sewing_panel
				cap_panel.get_node("SewingLeave").pressed.emit()
				_check(app.stitched_sewing_panel == null and app.title_view.is_visible_in_tree(),
					"full-cap Sewing Circle still Leaves cleanly")
		else:
			cap_stage._action_buttons["exit"].pressed.emit()
	else:
		_check(false, "full-cap Roadblock Fight admitted from real title")
	app.free()
	await process_frame
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("stitched_s5_sewing_spoils_live_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
