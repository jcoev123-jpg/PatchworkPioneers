extends SceneTree
## Real S6 route: Roadblock legal part combat -> Circle Leave -> one Event
## choice -> next Roadblock, including forged/stale/replay/affordability denials.
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)

func _state(app: Node) -> Dictionary:
	return {"candle": app.stitched_roadblock_candle, "gold": app.stitched_preview_gold,
		"scraps": app.stitched_preview_scraps, "hp": app._stitched_hp_carry.duplicate(true),
		"fray": app._stitched_fray_carry.duplicate(true),
		"ranks": app._stitched_rank_carry.duplicate(true),
		"bleed": app._stitched_bleed_carry.duplicate(true),
		"satchel": app.stitched_preview_satchel.duplicate(true),
		"gear": app._stitched_gear_overrides.duplicate(true),
		"legacy_gold": app.session_gold, "legacy_scraps": app.run_scraps}

func _admit(app: Node) -> StitchedBattleScreen:
	if not app._open_stitched_fight():
		return null
	await process_frame
	var panel: LiveEventChoicePanel = app.stitched_event_panel
	if panel == null or panel.get_choice_buttons().size() != 3:
		return null
	panel.get_choice_buttons()[0].pressed.emit()
	await process_frame
	return app.stitched_fight_view

func _victory(stage: StitchedBattleScreen) -> Dictionary:
	if stage == null or stage.battle == null or not stage.battle.is_valid():
		return {}
	var actions := 0
	var abilities := 0
	for turn in range(200):
		if stage.battle.is_over() or stage.battle.current_side() != "hero":
			break
		var actor: Dictionary = stage.battle.get_unit(stage.battle.current_actor_id())
		var score := -10000
		var part := ""
		var target := 0
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
				var weight := -20
				if str(legal[0]["side"]) == "foe":
					weight = int(skill.get("dmg", [0, 0])[1]) * 4 \
						+ int(skill.get("dmg", [0, 0])[0])
				elif str(skill.get("kind", "")) == "heal":
					var ally: Dictionary = stage._unit_at("hero", rank)
					var missing := int(ally.get("max_hp", 0)) - int(ally.get("hp", 0))
					if missing >= 8:
						weight = 38 + missing
				if weight > score:
					score = weight
					part = id
					target = rank
		var receipt: Dictionary = stage.submit_part(part, target) if part != "" \
			else stage.submit_pass()
		if receipt.get("ok") != true:
			break
		if receipt.get("action") == "ability":
			abilities += 1
		actions += 1
	return {"outcome": stage.battle.outcome(), "actions": actions, "abilities": abilities}

func _earned() -> Node:
	var app: Node = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await process_frame
	_check(app.stitched_postevent_button != null and not app.stitched_postevent_button.visible \
		and app.stitched_postevent_button.disabled and not app._open_stitched_postevent() \
		and app.stitched_postevent_visit == null and app.stitched_postevent_panel == null,
		"fresh title has no Event authority")
	var unwon: StitchedBattleScreen = await _admit(app)
	_check(unwon != null and unwon.battle != null and unwon.battle.is_valid(),
		"unwon route mounts real battle")
	if unwon == null:
		return app
	unwon._action_buttons["exit"].pressed.emit()
	await process_frame
	_check(not app._open_stitched_postevent() and not app.stitched_postevent_button.visible \
		and app.stitched_preview_gold == 0 and app.stitched_preview_scraps == 0,
		"unwon exit cannot mint Event or currency")
	var stage: StitchedBattleScreen = await _admit(app)
	var won: Dictionary = _victory(stage)
	_check(won.get("outcome") == "victory" and won.get("actions", 0) > 0 \
		and won.get("abilities", 0) > 0 and stage.battle.get_foes().size() == 3,
		"real 3-foe fight won with legal mounted abilities")
	if won.get("outcome") != "victory":
		return app
	var survivors := 0
	for hero in stage.battle.get_heroes():
		if not bool(hero.get("lost", false)):
			survivors += 1
	_check(survivors == 4, "real victory leaves exactly four selected living heroes")
	stage._action_buttons["exit"].pressed.emit()
	await process_frame
	_check(app.stitched_sewing_panel != null \
		and not app.stitched_postevent_button.visible \
		and app.stitched_preview_gold == 10 and app.stitched_preview_scraps == 1,
		"victory awards only real preview wallet and enters Circle")
	if app.stitched_sewing_panel == null:
		return app
	var circle: Control = app.stitched_sewing_panel
	var old: Dictionary = app._stitched_sewing_quote.get("state", {}).duplicate(true)
	var forged := old.duplicate(true)
	forged["version"] = -12
	_check(app._stitched_sewing_leave(forged, weakref(circle)).get("ok") != true \
		and not app._open_stitched_postevent(),
		"forged Circle Leave cannot create Event")
	var leave: Button = circle.find_child("SewingLeave", true, false)
	if leave != null:
		leave.pressed.emit()
		await process_frame
	_check(app.stitched_sewing_panel == null \
		and app.stitched_postevent_button.visible and not app.stitched_postevent_button.disabled \
		and app.stitched_campfire_button.visible and app.stitched_peddler_button.visible \
		and app._stitched_campfire_roster.size() == 4 \
		and not app._stitched_sewing_leave(old, weakref(circle)).get("ok"),
		"authentic Circle Leave exposes 3 exclusive visits once")
	return app

func _opened(app: Node) -> Dictionary:
	if not app._open_stitched_postevent():
		_check(false, "earned Event panel must open")
		return {}
	await process_frame
	var panel: Control = app.stitched_postevent_panel
	var quote: Dictionary = app._stitched_postevent_quote.duplicate(true)
	var snap: Dictionary = app._stitched_postevent_snapshot.duplicate(true)
	var gold: Button = panel.find_child("FerryPayGold", true, false)
	var wick: Button = panel.find_child("FerryMendWick", true, false)
	var leave: Button = panel.find_child("FerryLeave", true, false)
	_check(panel.is_visible_in_tree() and panel.theme == load("res://themes/gothic_theme.tres") \
		and panel.find_child("FerryEventFrame", true, false) is NinePatchRect \
		and gold != null and wick != null and leave != null \
		and not leave.disabled and not app.title_view.is_visible_in_tree() \
		and not app.stitched_peddler_button.visible and not app.stitched_campfire_button.visible \
		and not app._open_stitched_peddler() and not app._open_stitched_campfire() \
		and not app._open_stitched_fight() \
		and quote == app.stitched_postevent_visit.preview(snap) \
		and snap["party"].size() == 4 and snap["candle"] == app.stitched_roadblock_candle,
		"one mounted gothic Event owns quoted 4-hero snapshot and all rival stops are shut")
	return {"panel": panel, "quote": quote, "snapshot": snap,
		"gold": gold, "wick": wick, "leave": leave,
		"service": app.stitched_postevent_visit,
		"generation": app._stitched_postevent_generation}

func _forgeries(app: Node, opened: Dictionary) -> void:
	var before := _state(app)
	seed(8675309)
	var next_invalid_rng := randi()
	seed(8675309)
	var q: Dictionary = opened["quote"]
	var snap: Dictionary = opened["snapshot"]
	var source: WeakRef = weakref(opened["panel"])
	var gen: int = opened["generation"]
	var service: RunStitchedEventConsequence = opened["service"]
	var forged: Dictionary = snap.duplicate(true)
	forged["candle"] = 0
	_check(app._stitched_postevent_choose("pay_gold", forged, q, source, gen).get("ok") != true,
		"forged snapshot rejected")
	var quoted := q.duplicate(true)
	quoted["choices"][0]["gold"] = 999
	_check(app._stitched_postevent_choose("pay_gold", snap, quoted, source, gen).get("ok") != true,
		"forged quoted result rejected")
	_check(app._stitched_postevent_choose("no_such_choice", snap, q, source, gen).get("ok") != true \
		and app._stitched_postevent_choose("pay_gold", snap, q, source, gen-1).get("ok") != true \
		and app._stitched_postevent_choose("pay_gold", snap, q, null, gen).get("ok") != true,
		"unoffered, stale generation and detached control rejected")
	var id: String = str(snap["party"][0]["id"])
	app._stitched_hp_carry[id] += 1
	_check(app._stitched_postevent_choose("pay_gold", snap, q, source, gen).get("ok") != true,
		"changed live HP rejects")
	app._stitched_hp_carry[id] -= 1
	app._stitched_fray_carry[id]["fray"] += 1
	_check(app._stitched_postevent_choose("pay_gold", snap, q, source, gen).get("ok") != true,
		"changed live FRAY rejects")
	app._stitched_fray_carry[id]["fray"] -= 1
	var before_party: Array = app._stitched_party_picks.duplicate()
	app._stitched_party_picks.reverse()
	_check(app._stitched_postevent_choose("pay_gold", snap, q, source, gen).get("ok") != true,
		"changed selected party rejects")
	app._stitched_party_picks = before_party
	app.stitched_preview_gold += 1
	_check(app._stitched_postevent_choose("pay_gold", snap, q, source, gen).get("ok") != true,
		"changed live wallet rejects")
	app.stitched_preview_gold -= 1
	_check(_state(app) == before and service.is_valid() and not service.is_claimed() \
		and randi() == next_invalid_rng,
		"all invalid actions preserve resources, service and RNG")

func _scenario(choice: String, candle_override: int = -1,
		scraps_override: int = -1, gold_override: int = -1) -> Dictionary:
	seed(41203)
	var app: Node = await _earned()
	if not app.stitched_postevent_button.visible:
		app.free()
		await process_frame
		return {}
	if candle_override >= 0:
		app.stitched_roadblock_candle = candle_override
	if scraps_override >= 0:
		app.stitched_preview_scraps = scraps_override
	if gold_override >= 0:
		app.stitched_preview_gold = gold_override
	var opened: Dictionary = await _opened(app)
	if opened.is_empty():
		app.free()
		await process_frame
		return {}
	var before := _state(app)
	var q: Dictionary = opened["quote"]
	var snap: Dictionary = opened["snapshot"]
	var gold: Button = opened["gold"]
	var wick: Button = opened["wick"]
	var leave: Button = opened["leave"]
	_check(q["choices"].size() == 3 and q["choices"][0]["choice_id"] == "pay_gold" \
		and q["choices"][1]["choice_id"] == "mend_wick" \
		and q["choices"][2]["choice_id"] == "leave" \
		and q["choices"][2]["available"] == true and not leave.disabled,
		"exact ordered three-effect quote with always-enabled Leave")
	_check(gold.disabled == (before["gold"] < 10) \
		and wick.disabled == (before["scraps"] < 1 or before["candle"] == 100),
		"quote-controlled affordability and full-wick no-effect admission")
	_forgeries(app, opened)
	var button: Button = gold if choice == "pay_gold" else wick if choice == "mend_wick" else leave
	var selected_available: bool = not button.disabled
	if not selected_available:
		var denied: Dictionary = app._stitched_postevent_choose(choice, snap, q,
			weakref(opened["panel"]), opened["generation"])
		_check(denied.get("ok") != true and not opened["service"].is_claimed() \
			and _state(app) == before,
			"disabled choice cannot consume service, funds or candle")
		leave.pressed.emit()
	else:
		seed(42132)
		var next_rng := randi()
		seed(42132)
		button.pressed.emit()
		_check(randi() == next_rng, "valid Event choice does not consume RNG")
	await process_frame
	_check(app.stitched_postevent_visit == null and app.stitched_postevent_panel == null \
		and not app._stitched_postvictory_stop_available \
		and not app.stitched_postevent_button.visible \
		and not app.stitched_campfire_button.visible and not app.stitched_peddler_button.visible \
		and opened["service"].is_claimed(),
		"choice retires all three postvictory stops and claims service once")
	var after := _state(app)
	var expected_gold: int = int(before["gold"]) - (10 if choice == "pay_gold" and selected_available else 0)
	var expected_scraps: int = int(before["scraps"]) + (2 if choice == "pay_gold" and selected_available \
		else -1 if choice == "mend_wick" and selected_available else 0)
	var expected_candle := mini(100, before["candle"] + (8 if choice == "mend_wick" and selected_available else 0))
	_check(after["gold"] == expected_gold and after["scraps"] == expected_scraps \
		and after["candle"] == expected_candle \
		and after["hp"] == before["hp"] and after["fray"] == before["fray"] \
		and after["ranks"] == before["ranks"] and after["gear"] == before["gear"] \
		and after["satchel"] == before["satchel"] \
		and after["legacy_gold"] == 0 and after["legacy_scraps"] == 0,
		"exact gold/scrap/capped candle settlement, other carry and legacy state untouched")
	var replay: Dictionary = app._stitched_postevent_choose(choice, snap, q,
		weakref(opened["panel"]), opened["generation"])
	_check(replay.get("ok") != true and not app._open_stitched_postevent() \
		and _state(app) == after,
		"stale receipt and duplicate visit cannot settle again")
	var next_stage: StitchedBattleScreen = await _admit(app)
	_check(next_stage != null and next_stage.battle != null \
		and next_stage.battle.is_valid() \
		and app.stitched_roadblock_candle == maxi(0, expected_candle - 8) \
		and next_stage.config.get("candle") == maxi(0, expected_candle - 8) \
		and next_stage.battle.candle() == maxi(0, expected_candle - 8) \
		and next_stage.battle.state_snapshot().get("candle") == maxi(0, expected_candle - 8),
		"next real Roadblock imports the exact Event-carried candle to rules")
	if next_stage != null:
		next_stage._action_buttons["exit"].pressed.emit()
		await process_frame
	app.free()
	await process_frame
	return {"before": before, "after": after}

func _run() -> void:
	var bought: Dictionary = await _scenario("pay_gold")
	var repaired: Dictionary = await _scenario("mend_wick")
	var left: Dictionary = await _scenario("leave")
	var capped: Dictionary = await _scenario("mend_wick", 100)
	var partial_cap: Dictionary = await _scenario("mend_wick", 96)
	_check(partial_cap.get("before", {}).get("candle") == 96 \
		and partial_cap.get("after", {}).get("candle") == 100 \
		and partial_cap.get("after", {}).get("scraps") == 0,
		"one paid scrap restores candle to precisely 100, never above the cap")
	var short_gold: Dictionary = await _scenario("pay_gold", -1, -1, 9)
	var short_scraps: Dictionary = await _scenario("mend_wick", -1, 0)
	_check(not bought.is_empty() and not repaired.is_empty() and not left.is_empty() \
		and not capped.is_empty() and not short_gold.is_empty() and not short_scraps.is_empty(),
		"all six real-play choice witnesses completed")
	if failures.is_empty():
		print("stitched_s6_ferry_event_live_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("stitched_s6_ferry_event_live_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)
