extends SceneTree
## Live S6: genuine battle FRAY -> Circle Leave -> Tell Tales -> next Roadblock.
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
		"fray": app._stitched_fray_carry.duplicate(true),
		"ranks": app._stitched_rank_carry.duplicate(true),
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


## Check the presenter's narrow quote separately; the real-route test below
## must still win its own fight and use the resulting unmodified carry.
func _quote_only_buttons(app: Node, roster: Array) -> void:
	var full: Array = roster.duplicate(true)
	for hero in full:
		hero["hp"] = hero["max_hp"]
	var service := RunCampfireVisit.new(NODE, full, RunCampfireVisit.STITCHED, 100)
	var state: Dictionary = service.read_state()
	var choices: Array = state.get("quote", {}).get("choices", [])
	_check(state.get("ok") == true and choices.has(RunCampfireVisit.TELL_TALES)
		and choices.has(RunCampfireVisit.STITCHED_LEAVE)
		and not choices.has(RunCampfireVisit.MEND)
		and not choices.has(RunCampfireVisit.TRIM_THE_WICK),
		"full HP and full candle offer Tales/Leave but neither ineffective action")
	if not state.get("ok") or not choices.has(RunCampfireVisit.TELL_TALES):
		return
	var mounted: Dictionary = app._mount_stitched_campfire(state, 4567, {})
	var panel: Control = mounted.get("panel")
	if panel == null:
		_check(false, "quote-only presenter should create a panel")
		return
	var tales: Button = panel.find_child("CampfireTales", true, false)
	var leave: Button = panel.find_child("CampfireLeave", true, false)
	_check(tales != null and leave != null
		and panel.find_child("CampfireMend", true, false) == null
		and panel.find_child("CampfireWick", true, false) == null
		and mounted["first"] == tales
		and tales.focus_mode == Control.FOCUS_ALL
		and leave.focus_mode == Control.FOCUS_ALL
		and tales.focus_next == tales.get_path_to(leave)
		and leave.focus_previous == leave.get_path_to(tales),
		"quoted Tales/Leave alone retain labelled keyboard-mouse route on gothic NinePatch")
	panel.free()


func _tales_replay(seed_value: int) -> Dictionary:
	seed(seed_value)
	var setup: Dictionary = await _prepare()
	var app: Node = setup["app"]
	if setup.get("survivors", []).size() != 4 or not app.stitched_campfire_button.visible:
		_check(false, "Tales requires an earned four-survivor Circle Leave")
		app.free()
		await process_frame
		return {}
	var roster: Array = app._stitched_campfire_roster.duplicate(true)
	var before: Dictionary = _resources(app)
	var earned_fray: Dictionary = {}
	var natural_positive := 0
	for hero in setup["survivors"]:
		var id := str(hero["id"])
		earned_fray[id] = {"fray": int(hero["fray"]), "resolve": str(hero["resolve"])}
		if int(hero["fray"]) > 0:
			natural_positive += 1
	_check(natural_positive > 0 and earned_fray.size() == 4
		and earned_fray == before["fray"]
		and app._stitched_campfire_held_fray_valid(roster),
		"genuine mounted Roadblock combat produced nonzero FRAY and exact selected-ID resolve pairs")
	if natural_positive == 0:
		app.free()
		await process_frame
		return {}
	_quote_only_buttons(app, roster)
	var forged_roster: Array = roster.duplicate(true)
	forged_roster[0]["fray"] += 1
	app._stitched_campfire_roster = forged_roster
	_check(not app._open_stitched_campfire()
		and app.stitched_campfire_panel == null and _resources(app) == before,
		"forged Campfire FRAY cannot mint or consume a live stop")
	app._stitched_campfire_roster = roster.duplicate(true)
	var foreign: Dictionary = before["fray"].duplicate(true)
	foreign["foreign_doll"] = {"fray": 12, "resolve": ""}
	app._stitched_fray_carry = foreign
	_check(not app._open_stitched_campfire() and _resources(app)["fray"] == foreign
		and app._stitched_postvictory_stop_available,
		"unexpected extra selected-ID FRAY record fails closed without spend")
	app._stitched_fray_carry = before["fray"].duplicate(true)
	app.stitched_campfire_button.pressed.emit()
	await process_frame
	var panel: Control = app.stitched_campfire_panel
	var visit: RunCampfireVisit = app.stitched_campfire_visit
	if panel == null or visit == null:
		_check(false, "earned Tales visit mounts live panel and service")
		app.free()
		await process_frame
		return {}
	var state: Dictionary = app._stitched_campfire_state.duplicate(true)
	var generation: int = app._stitched_campfire_generation
	var tales: Button = panel.find_child("CampfireTales", true, false)
	var frame: NinePatchRect = panel.find_child("CampfireFrame", true, false)
	var choices: Array = state.get("quote", {}).get("choices", [])
	_check(tales != null and not tales.disabled and tales.focus_mode == Control.FOCUS_ALL
		and frame != null and frame.texture != null
		and panel.theme == load("res://themes/gothic_theme.tres")
		and choices.has(RunCampfireVisit.TELL_TALES)
		and choices.has(RunCampfireVisit.STITCHED_LEAVE)
		and state == visit.read_state()
		and state["heroes"] == roster and state["candle"] == before["candle"]
		and not app.stitched_campfire_button.visible
		and not app.stitched_peddler_button.visible,
		"live Tales is quoted, focusable, and consumes the shared stop on entry")
	var wrong_node := state.duplicate(true)
	wrong_node["node_id"] = "forged"
	var wrong_quote := state.duplicate(true)
	wrong_quote["quote"]["choices"].erase(RunCampfireVisit.TELL_TALES)
	var wrong_hero := state.duplicate(true)
	wrong_hero["heroes"][0]["fray"] += 1
	var wrong_candle := state.duplicate(true)
	wrong_candle["candle"] = -1
	seed(837401)
	var rng_expected: int = randi()
	seed(837401)
	var refusals := [
		app._stitched_campfire_choose(RunCampfireVisit.TELL_TALES, wrong_node, weakref(panel), generation),
		app._stitched_campfire_choose(RunCampfireVisit.TELL_TALES, wrong_quote, weakref(panel), generation),
		app._stitched_campfire_choose(RunCampfireVisit.TELL_TALES, wrong_hero, weakref(panel), generation),
		app._stitched_campfire_choose(RunCampfireVisit.TELL_TALES, wrong_candle, weakref(panel), generation),
		app._stitched_campfire_choose(RunCampfireVisit.TELL_TALES, state, null, generation),
		app._stitched_campfire_choose(RunCampfireVisit.TELL_TALES, state, weakref(panel), generation - 1),
		app._stitched_campfire_choose("forged_action", state, weakref(panel), generation),
		visit.select(RunCampfireVisit.TELL_TALES, "wrong_node", roster, before["candle"]),
		visit.select(RunCampfireVisit.TELL_TALES, NODE, wrong_hero["heroes"], before["candle"]),
	]
	var forged_panel := Control.new()
	app.add_child(forged_panel)
	refusals.append(app._stitched_campfire_choose(
		RunCampfireVisit.TELL_TALES, state, weakref(forged_panel), generation))
	forged_panel.queue_free()
	panel.set_meta("campfire_generation", generation - 1)
	refusals.append(app._stitched_campfire_choose(
		RunCampfireVisit.TELL_TALES, state, weakref(panel), generation))
	panel.set_meta("campfire_generation", generation)
	panel.hide()
	refusals.append(app._stitched_campfire_choose(
		RunCampfireVisit.TELL_TALES, state, weakref(panel), generation))
	panel.show()
	var first_id := str(roster[0]["id"])
	app._stitched_fray_carry[first_id]["fray"] += 1
	refusals.append(app._stitched_campfire_choose(
		RunCampfireVisit.TELL_TALES, state, weakref(panel), generation))
	app._stitched_fray_carry = before["fray"].duplicate(true)
	app._stitched_hp_carry[first_id] = -1
	refusals.append(app._stitched_campfire_choose(
		RunCampfireVisit.TELL_TALES, state, weakref(panel), generation))
	app._stitched_hp_carry = before["hp"].duplicate(true)
	var all_refused := true
	for receipt in refusals:
		all_refused = all_refused and receipt.get("ok") == false
	_check(all_refused and visit.read_state() == state
		and _resources(app) == before and randi() == rng_expected,
		"forged/stale/replayed/wrong-node/generation/panel/FRAY/HP attempts are RNG- and wallet-neutral")
	var expected_fray: Dictionary = before["fray"].duplicate(true)
	var changed := 0
	for id in expected_fray.keys():
		var previous: int = int(expected_fray[id]["fray"])
		var reduced := maxi(0, previous - RunCampfireVisit.TALES_FRAY_REDUCTION)
		if reduced < previous:
			changed += 1
		expected_fray[id]["fray"] = reduced
		if reduced < StitchedRules.FRAY_RECOVER \
				and str(expected_fray[id]["resolve"]) in StitchedS1BEffects.RESOLVE_TRAITS:
			expected_fray[id]["resolve"] = ""
	_check(changed > 0 and expected_fray.size() == 4,
		"at least one real battle-earned FRAY pair has a payable capped Tales reduction")
	tales.pressed.emit()
	var after: Dictionary = _resources(app)
	var only_fray: Dictionary = before.duplicate(true)
	only_fray["fray"] = expected_fray.duplicate(true)
	_check(after == only_fray and visit.read_state().get("status") == RunCampfireVisit.STITCHED_DECIDED
		and app.stitched_campfire_visit == null and app.stitched_campfire_panel == null
		and not app._open_stitched_campfire() and not app._open_stitched_peddler()
		and not app.stitched_campfire_button.visible and not app.stitched_peddler_button.visible,
		"one live Tales publishes exact capped -25 FRAY and legal resolve, no HP/CANDLE/gear/currency change")
	_check(not visit.select(RunCampfireVisit.TELL_TALES, NODE, roster, before["candle"]).get("ok")
		and not app._stitched_campfire_choose(
			RunCampfireVisit.TELL_TALES, state, weakref(panel), generation).get("ok")
		and not app._stitched_campfire_choose(
			RunCampfireVisit.STITCHED_LEAVE, state, weakref(panel), generation).get("ok")
		and _resources(app) == after,
		"decided visit and stale callback cannot repeat Tales or reverse its settlement")
	await process_frame
	var next: StitchedBattleScreen = await _admit(app)
	_check(next != null and next.battle != null and next.battle.is_valid(),
		"subsequent real Roadblock battle admits the earned Tales carry")
	if next != null and next.battle != null:
		var actual_fray: Dictionary = {}
		for hero in next.battle.get_heroes():
			actual_fray[str(hero["id"])] = {"fray": int(hero["fray"]),
				"resolve": str(hero["resolve"])}
		_check(actual_fray == expected_fray and next.config["candle"] == maxi(0, before["candle"] - 8)
			and app._stitched_fray_carry == expected_fray
			and app._stitched_hp_carry == before["hp"]
			and app._stitched_bleed_carry == before["bleed"]
			and app._stitched_rank_carry == before["ranks"]
			and app._stitched_gear_overrides == before["gear"]
			and app.stitched_preview_gold == before["gold"]
			and app.stitched_preview_scraps == before["scraps"],
			"next mounted StitchedRules starts with exact Tales FRAY/resolve, normal 8 CANDLE and untouched ledgers")
		next._action_buttons["exit"].pressed.emit()
		await process_frame
		_check(app._stitched_fray_carry == expected_fray
			and not app._stitched_postvictory_stop_available,
			"unwon subsequent exit cannot grant or erase earned Tales")
	var trace := {"before": before["fray"], "after": expected_fray,
		"candle": before["candle"], "winner_count": setup["survivors"].size()}
	app.free()
	await process_frame
	return trace


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var first: Dictionary = await _tales_replay(526144)
	var second: Dictionary = await _tales_replay(526144)
	_check(not first.is_empty() and first == second
		and first.get("before", {}) != first.get("after", {})
		and first.get("winner_count") == 4,
		"two authentic seeded Roadblock→Circle→Tales→Fight routes replay identical capped FRAY receipts")
	for failure in failures:
		printerr(failure)
	print("stitched_s6_campfire_tales_live_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
