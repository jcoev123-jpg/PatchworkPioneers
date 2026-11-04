extends SceneTree
## Live S6: mounted legal Roadblock victory -> authenticated Circle Leave ->
## one shared Campfire/Peddler stop -> mounted next Fight with exact Mend HP.
const NODE := "s6_stitched_roadblock_campfire"
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, note: String) -> void:
	checks += 1
	if not value:
		failures.append(note)


func _resources(app: Node) -> Dictionary:
	return {"hp": app._stitched_hp_carry.duplicate(true),
		"candle": app.stitched_roadblock_candle,
		"gold": app.stitched_preview_gold,
		"bleed": app._stitched_bleed_carry.duplicate(true),
		"gear": app._stitched_gear_overrides.duplicate(true),
		"satchel": app.stitched_preview_satchel.duplicate(true),
		"scraps": app.stitched_preview_scraps,
		"legacy_gold": app.session_gold, "legacy_scraps": app.run_scraps}


func _no_legacy(app: Node) -> bool:
	return app.deck == null and app.run_map == null and app.run_rng == null \
		and app.session_gold == 0 and app.run_scraps == 0 and app.run_deck.is_empty()


func _admit(app: Node) -> StitchedBattleScreen:
	app.stitched_fight_button.pressed.emit()
	await process_frame
	var offer: LiveEventChoicePanel = app.stitched_event_panel
	if offer == null or not offer.has_open_event() or offer.get_choice_buttons().size() != 3:
		return null
	if offer.get_choice_buttons()[0].disabled:
		return null
	offer.get_choice_buttons()[0].pressed.emit()
	await process_frame
	return app.stitched_fight_view


## All foe kills come from the real mounted battle's legal part receipts.
func _victory(stage: StitchedBattleScreen) -> Dictionary:
	if stage == null or stage.battle == null or not stage.battle.is_valid():
		return {}
	var steps := 0
	var abilities := 0
	for turn in range(200):
		if stage.battle.is_over() or stage.battle.current_side() != "hero":
			break
		var actor: Dictionary = stage.battle.get_unit(stage.battle.current_actor_id())
		var best_score := -10000
		var best_part := ""
		var best_rank := 0
		for slot in StitchedParts.SLOTS:
			if not stage._valid_part(actor, actor["parts"][slot]):
				continue
			var id := str(actor["parts"][slot]["id"])
			var skill: Dictionary = StitchedParts.ability_at_tier(
				stage.parts.get(id, {}), int(actor["parts"][slot]["tier"]))
			for rank in range(1, 5):
				var legal: Array = stage.battle._legal_targets(actor, skill, rank)
				if legal.is_empty():
					continue
				var score := -20
				if str(legal[0]["side"]) == "foe":
					score = int(skill.get("dmg", [0, 0])[1]) * 4 \
						+ int(skill.get("dmg", [0, 0])[0])
				elif str(skill.get("kind", "")) == "heal":
					var ally: Dictionary = stage._unit_at("hero", rank)
					var missing := int(ally.get("max_hp", 0)) - int(ally.get("hp", 0))
					if missing >= 8:
						score = 38 + missing
				if score > best_score:
					best_score = score
					best_part = id
					best_rank = rank
		var result: Dictionary
		if best_part != "":
			result = stage.submit_part(best_part, best_rank)
			if result.get("ok") == true and result.get("action") == "ability":
				abilities += 1
		else:
			result = stage.submit_pass()
		if result.get("ok") != true:
			break
		steps += 1
	return {"outcome": stage.battle.outcome(), "steps": steps,
		"abilities": abilities, "rounds": stage.battle.round_number()}


func _prepare() -> Dictionary:
	var app: Node = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await process_frame
	_check(app.stitched_campfire_button != null \
		and not app.stitched_campfire_button.visible \
		and app.stitched_campfire_button.disabled \
		and app.stitched_campfire_button.focus_mode == Control.FOCUS_NONE \
		and not app._open_stitched_campfire() and app.stitched_campfire_visit == null \
		and not app._stitched_postvictory_stop_available and _no_legacy(app),
		"fresh title has no Campfire or earned visit")
	var aborted: StitchedBattleScreen = await _admit(app)
	_check(aborted != null and aborted.battle != null and aborted.battle.is_valid(),
		"unwon real Roadblock mounts")
	if aborted == null:
		return {"app": app}
	aborted._action_buttons["exit"].pressed.emit()
	await process_frame
	app._stitched_fight_exit(weakref(aborted))
	app._stitched_fight_exit(null)
	_check(not app._open_stitched_campfire() \
		and not app.stitched_campfire_button.visible \
		and not app.stitched_peddler_button.visible \
		and app.stitched_sewing_panel == null \
		and app._stitched_hp_carry.is_empty(),
		"unwon exit and replay mint no Campfire or Peddler")
	var stage: StitchedBattleScreen = await _admit(app)
	var won: Dictionary = _victory(stage)
	_check(won.get("outcome") == "victory" and won.get("steps", 0) > 0 \
		and won.get("abilities", 0) > 0 and stage.battle.get_foes().size() == 3,
		"three real foes defeated through legal mounted part actions")
	if won.get("outcome") != "victory":
		return {"app": app}
	var survivors: Array = []
	var wounded := 0
	var wounds: Dictionary = {}
	for hero in stage.battle.get_heroes():
		if bool(hero.get("lost", false)):
			continue
		survivors.append(hero.duplicate(true))
		wounds[str(hero["id"])] = int(hero["hp"])
		if int(hero["hp"]) < int(hero["max_hp"]):
			wounded += 1
	_check(survivors.size() == 4 and wounded > 0 and wounds.size() == 4,
		"real winning team includes four survivors and actual damaged HP")
	stage._action_buttons["exit"].pressed.emit()
	await process_frame
	_check(app.stitched_sewing_panel != null and app.stitched_sewing_visit != null \
		and app._stitched_hp_carry == wounds and not app.stitched_campfire_button.visible \
		and not app._stitched_postvictory_stop_available,
		"victory alone opens Circle, but not Campfire")
	if app.stitched_sewing_panel == null:
		return {"app": app}
	var circle: Control = app.stitched_sewing_panel
	var state: Dictionary = app._stitched_sewing_quote["state"].duplicate(true)
	var forged := state.duplicate(true)
	forged["version"] = -1
	_check(app._stitched_sewing_leave(forged, weakref(circle)).get("ok") != true \
		and not app._open_stitched_campfire() \
		and app._stitched_hp_carry == wounds,
		"forged Circle Leave cannot mint a stop")
	circle.get_node("SewingLeave").pressed.emit()
	await process_frame
	_check(app.stitched_sewing_panel == null \
		and app._stitched_postvictory_stop_available \
		and app.stitched_campfire_button.visible \
		and app.stitched_campfire_button.focus_mode == Control.FOCUS_ALL \
		and app.stitched_peddler_button.visible \
		and app.stitched_peddler_button.focus_mode == Control.FOCUS_ALL \
		and app.stitched_peddler_button.focus_next == app.stitched_peddler_button.get_path_to(
			app.stitched_campfire_button) and _no_legacy(app),
		"one authentic Circle Leave offers both keyboard-reachable exclusive visits")
	_check(not app._stitched_sewing_leave(state, weakref(circle)).get("ok") \
		and app._stitched_postvictory_stop_available,
		"stale Circle Leave cannot mint another stop")
	return {"app": app, "survivors": survivors, "wounds": wounds,
		"wounded": wounded}


func _campfire_mend() -> Dictionary:
	var setup: Dictionary = await _prepare()
	var app: Node = setup["app"]
	if setup.get("survivors", []).size() != 4 or not app.stitched_campfire_button.visible:
		app.free()
		await process_frame
		return {}
	var roster: Array = app._stitched_campfire_roster.duplicate(true)
	var ordered := true
	for index in range(roster.size()):
		var hero: Dictionary = roster[index]
		ordered = ordered and hero["position"] == index + 1
		var matched := false
		for original in setup["survivors"]:
			if original["id"] == hero["id"]:
				matched = hero["hp"] == original["hp"] \
					and hero["max_hp"] == original["max_hp"] \
					and hero["fray"] == original["fray"] \
					and hero["position"] == original["rank"]
		ordered = ordered and matched
	_check(ordered and roster.size() == 4,
		"Campfire quoted positions, HP, worn max HP and fray are real final battle state")
	var forged: Array = roster.duplicate(true)
	forged[0]["max_hp"] += 50
	app._stitched_campfire_roster = forged
	_check(not app._open_stitched_campfire() and app.stitched_campfire_panel == null,
		"forged roster cannot become an opened Campfire")
	app._stitched_campfire_roster = roster.duplicate(true)
	var before: Dictionary = _resources(app)
	app.stitched_campfire_button.pressed.emit()
	await process_frame
	var panel: Control = app.stitched_campfire_panel
	var visit: RunCampfireVisit = app.stitched_campfire_visit
	if panel == null or visit == null:
		_check(false, "earned Campfire must open real scene panel and service")
		app.free()
		await process_frame
		return {}
	var quoted: Dictionary = app._stitched_campfire_state.duplicate(true)
	var mend: Button = panel.find_child("CampfireMend", true, false)
	var leave: Button = panel.find_child("CampfireLeave", true, false)
	var frame: NinePatchRect = panel.find_child("CampfireFrame", true, false)
	var generation: int = app._stitched_campfire_generation
	_check(frame != null and frame.texture != null \
		and panel.theme == load("res://themes/gothic_theme.tres") \
		and mend != null and leave != null \
		and mend.focus_mode == Control.FOCUS_ALL and leave.focus_mode == Control.FOCUS_ALL \
		and not mend.disabled and not leave.disabled \
		and quoted == visit.read_state() \
		and quoted.get("node_id") == NODE \
		and quoted.get("status") == RunCampfireVisit.STITCHED_OPEN \
		and quoted.get("mode") == RunCampfireVisit.STITCHED \
		and quoted.get("heroes") == roster and quoted.get("candle") == before["candle"] \
		and panel.is_visible_in_tree() and not app.title_view.is_visible_in_tree() \
		and not app.stitched_peddler_button.visible and not app.stitched_campfire_button.visible \
		and not app._stitched_postvictory_stop_available,
		"real themed fabric Campfire shows complete quote and consumes both stop choices on open")
	var wrong_node: Dictionary = quoted.duplicate(true)
	wrong_node["node_id"] = "forged"
	var wrong_heroes: Dictionary = quoted.duplicate(true)
	wrong_heroes["heroes"][0]["hp"] = 0
	var wrong_quote: Dictionary = quoted.duplicate(true)
	wrong_quote["quote"]["choices"].erase(RunCampfireVisit.MEND)
	var wrong_candle: Dictionary = quoted.duplicate(true)
	wrong_candle["candle"] = -1
	seed(62911)
	var expected_rng := randi()
	seed(62911)
	var refusals := [
		app._stitched_campfire_choose(RunCampfireVisit.MEND, wrong_node, weakref(panel), generation),
		app._stitched_campfire_choose(RunCampfireVisit.MEND, wrong_heroes, weakref(panel), generation),
		app._stitched_campfire_choose(RunCampfireVisit.MEND, wrong_quote, weakref(panel), generation),
		app._stitched_campfire_choose(RunCampfireVisit.MEND, wrong_candle, weakref(panel), generation),
		app._stitched_campfire_choose(RunCampfireVisit.MEND, quoted, null, generation),
		app._stitched_campfire_choose(RunCampfireVisit.MEND, quoted, weakref(panel), generation - 1),
		app._stitched_campfire_choose(RunCampfireVisit.TELL_TALES, quoted, weakref(panel), generation),
		visit.select(RunCampfireVisit.MEND, "forged", roster, before["candle"]),
		visit.select(RunCampfireVisit.MEND, NODE, wrong_heroes["heroes"], before["candle"]),
	]
	var forged_panel := Control.new()
	forged_panel.name = "ForgedCampfire"
	app.add_child(forged_panel)
	refusals.append(app._stitched_campfire_choose(
		RunCampfireVisit.MEND, quoted, weakref(forged_panel), generation))
	forged_panel.queue_free()
	var hp_before: Dictionary = app._stitched_hp_carry.duplicate(true)
	var one_id := str(roster[0]["id"])
	app._stitched_hp_carry[one_id] = -1
	refusals.append(app._stitched_campfire_choose(
		RunCampfireVisit.MEND, quoted, weakref(panel), generation))
	app._stitched_hp_carry = hp_before
	var none_succeeded := true
	for item in refusals:
		none_succeeded = none_succeeded and item.get("ok") == false
	_check(none_succeeded and visit.read_state() == quoted \
		and _resources(app) == before and randi() == expected_rng,
		"forged node/panel/roster/quote/candle/generation or mutated ledger never heals or spends")
	var expected: Dictionary = before["hp"].duplicate(true)
	var nonzero_gains := 0
	for hero in roster:
		var id := str(hero["id"])
		@warning_ignore("integer_division")
		var amount: int = (int(hero["max_hp"]) * RunCampfireVisit.MEND_HEAL_PERCENT) / 100
		expected[id] = mini(int(hero["max_hp"]), int(hero["hp"]) + amount)
		if int(expected[id]) > int(before["hp"][id]):
			nonzero_gains += 1
	_check(nonzero_gains > 0 and setup["wounded"] > 0,
		"winning combat has a non-vacuous payable Mend amount")
	mend.pressed.emit()
	var after: Dictionary = _resources(app)
	var unchanged: Dictionary = before.duplicate(true)
	unchanged["hp"] = expected.duplicate(true)
	_check(after == unchanged and app.stitched_campfire_panel == null \
		and app.stitched_campfire_visit == null \
		and not app.stitched_peddler_button.visible and not app.stitched_campfire_button.visible \
		and not app._open_stitched_peddler() and not app._open_stitched_campfire() \
		and _no_legacy(app),
		"one mounted Mend carries exact capped 30% for each survivor, no other ledger changes")
	_check(not visit.select(RunCampfireVisit.MEND, NODE, roster, before["candle"]).get("ok") \
		and not app._stitched_campfire_choose(
			RunCampfireVisit.MEND, quoted, weakref(panel), generation).get("ok") \
		and not app._stitched_campfire_choose(
			RunCampfireVisit.STITCHED_LEAVE, quoted, weakref(panel), generation).get("ok"),
		"closed Campfire and stale Mend/Leave callbacks cannot replay")
	await process_frame
	var next: StitchedBattleScreen = await _admit(app)
	_check(next != null and next.battle != null and next.battle.is_valid(),
		"next Fight admitted through real title picker after Mend")
	if next != null:
		var mounted: Dictionary = {}
		for hero in next.battle.get_heroes():
			mounted[str(hero["id"])] = int(hero["hp"])
		_check(mounted == expected and next.config.get("candle") == maxi(0, int(before["candle"]) - 8) \
			and app.stitched_roadblock_candle == next.config.get("candle") \
			and app._stitched_bleed_carry == before["bleed"] \
			and app._stitched_gear_overrides == before["gear"] and _no_legacy(app),
			"subsequent actual Fight starts at precisely Mend HP with ordinary entry candle cost")
		next._action_buttons["exit"].pressed.emit()
		await process_frame
		_check(app._stitched_hp_carry == expected \
			and not app._stitched_postvictory_stop_available \
			and not app.stitched_campfire_button.visible,
			"unwon next exit cannot re-award earned stop or change healed carry")
	var trace := {"before": before["hp"], "after": expected,
		"candle": before["candle"], "wounded": setup["wounded"]}
	app.free()
	await process_frame
	return trace


func _campfire_leave() -> void:
	var setup: Dictionary = await _prepare()
	var app: Node = setup["app"]
	if not app.stitched_campfire_button.visible:
		app.free()
		await process_frame
		return
	var before := _resources(app)
	app.stitched_campfire_button.pressed.emit()
	await process_frame
	var panel: Control = app.stitched_campfire_panel
	_check(panel != null, "second complete run can select earned Campfire")
	if panel != null:
		var visit: RunCampfireVisit = app.stitched_campfire_visit
		var state: Dictionary = app._stitched_campfire_state.duplicate(true)
		var leave: Button = panel.find_child("CampfireLeave", true, false)
		_check(leave != null and not leave.disabled and visit != null,
			"Campfire free Leave is enabled and focusable")
		if leave != null:
			leave.pressed.emit()
		_check(_resources(app) == before \
			and not app._open_stitched_campfire() and not app._open_stitched_peddler() \
			and not app.stitched_campfire_button.visible \
			and not app.stitched_peddler_button.visible \
			and not visit.select(RunCampfireVisit.MEND, NODE,
				state["heroes"], state["candle"]).get("ok"),
			"Campfire Leave consumes earned stop for free, with no healing or replay")
	app.free()
	await process_frame


func _peddler_exclusive() -> void:
	var setup: Dictionary = await _prepare()
	var app: Node = setup["app"]
	if not app.stitched_peddler_button.visible:
		app.free()
		await process_frame
		return
	var before := _resources(app)
	app.stitched_peddler_button.pressed.emit()
	await process_frame
	var panel: Control = app.stitched_peddler_panel
	_check(panel != null and app.stitched_peddler_visit != null \
		and not app.stitched_campfire_button.visible and not app._open_stitched_campfire() \
		and not app._stitched_postvictory_stop_available,
		"Peddler selection immediately spends the same earned Campfire stop")
	if panel != null:
		var leave: Button = panel.find_child("PeddlerLeave", true, false)
		_check(leave != null and not leave.disabled, "Peddler free Leave remains playable")
		if leave != null:
			leave.pressed.emit()
		_check(_resources(app) == before and not app._open_stitched_campfire() \
			and not app._open_stitched_peddler() and not app.stitched_campfire_button.visible \
			and not app.stitched_peddler_button.visible,
			"Peddler Leave cannot restore the spent Campfire option")
	app.free()
	await process_frame


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var first: Dictionary = await _campfire_mend()
	_check(not first.is_empty(), "complete real Mend trace produced")
	await _campfire_leave()
	await _peddler_exclusive()
	# Independent identical real-play traces prove deterministic quote and carry.
	var replay: Dictionary = await _campfire_mend()
	_check(not replay.is_empty() and first == replay,
		"two independent legitimate victories replay identical mounted Mend results")
	for failure in failures:
		printerr(failure)
	print("stitched_s6_campfire_mend_live_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
