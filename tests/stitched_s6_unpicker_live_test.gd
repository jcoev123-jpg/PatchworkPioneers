extends "res://tests/stitched_s6_campfire_wick_live_test.gd"
## Reuse the deterministic legal-battle driver and complete carry assertions.
const UNPICKER_MOUNT_SCRIPT := """extends "res://scripts/app.gd"
var fail_unpicker_mount := false
var unpicker_mounts := 0
var candle_at_mount: Variant
var projected_at_mount := -1
func _mount_stitched_unpicker(quote: Dictionary, candle: int, generation: int) -> Dictionary:
	unpicker_mounts += 1
	candle_at_mount = stitched_roadblock_candle
	projected_at_mount = candle
	if fail_unpicker_mount:
		return {}
	return super._mount_stitched_unpicker(quote, candle, generation)
"""


func _earned(duplicate_spares := false, carried_gold := 0) -> Node:
	var app: Node = load("res://scenes/app.tscn").instantiate()
	var script := GDScript.new()
	script.source_code = UNPICKER_MOUNT_SCRIPT
	_check(script.reload() == OK, "Unpicker failure-injection subclass compiles")
	app.set_script(script)
	root.add_child(app)
	await process_frame
	var fresh := _resources(app)
	_check(not app.stitched_unpicker_button.visible and app.stitched_unpicker_button.disabled
		and app.stitched_unpicker_button.focus_mode == Control.FOCUS_NONE
		and not app._open_stitched_unpicker() and _resources(app) == fresh,
		"unwon title cannot offer, open or charge Unpicker")
	app._stitched_postvictory_stop_available = true
	app._stitched_party_locked = true
	_check(not app._open_stitched_unpicker() and _resources(app) == fresh,
		"forged title eligibility cannot substitute for Circle receipts")
	app._stitched_postvictory_stop_available = false
	app._stitched_party_locked = false
	# Seed a prior run wallet before the genuine battle and authenticated Circle.
	app.stitched_preview_gold = carried_gold
	for battle_index in range(2 if duplicate_spares else 1):
		var stage: StitchedBattleScreen = await _admit(app)
		_check(stage != null and stage.battle != null, "real Roadblock mounted")
		if stage == null:
			return app
		var won := _victory(stage)
		_check(won.get("outcome") == "victory" and won.get("abilities", 0) > 0,
			"real legal part actions defeat Roadblock")
		if won.get("outcome") != "victory":
			return app
		var survivors: Array = stage.battle.get_heroes()
		app.set_meta("unpicker_rng_battle", stage.battle)
		_check(survivors.size() == 4 and survivors.all(func(hero): return hero["hp"] > 0 and not hero["lost"]),
			"four living survivors actually earn the Circle")
		stage._action_buttons["exit"].pressed.emit()
		await process_frame
		var circle: Control = app.stitched_sewing_panel
		_check(circle != null and app.stitched_sewing_visit != null,
			"victory exit mounts real Circle")
		if circle == null:
			return app
		var state: Dictionary = app.stitched_sewing_visit.read_state()
		var forged := state.duplicate(true)
		forged["version"] = -1
		var before := _resources(app)
		_check(not app._stitched_sewing_leave(forged, weakref(circle)).get("ok")
			and not app._open_stitched_unpicker() and _resources(app) == before,
			"forged Circle Leave cannot earn or charge Unpicker")
		circle.get_node("SewingLeave").pressed.emit()
		await process_frame
		_check(app.stitched_sewing_panel == null and app._stitched_party_locked
			and app._stitched_postvictory_stop_available and app.stitched_preview_satchel.size() > 0
			and app.stitched_unpicker_button.is_visible_in_tree()
			and not app.stitched_unpicker_button.disabled,
			"authentic Circle Leave offers the actual carried spares")
		_check(not app._stitched_sewing_leave(state, weakref(circle)).get("ok"),
			"Circle Leave replay cannot mint another offer")
	_check(app.stitched_postevent_button.focus_next == app.stitched_postevent_button.get_path_to(app.stitched_unpicker_button)
		and app.stitched_unpicker_button.focus_next == app.stitched_unpicker_button.get_path_to(app.start_button)
		and app.start_button.focus_previous == app.start_button.get_path_to(app.stitched_unpicker_button),
		"Unpicker belongs to the available-only title focus ring")
	_check(app.title_view.get_global_rect().position.y >= 0
		and app.title_view.get_global_rect().end.y <= 720
		and is_equal_approx(app.title_view.get_global_rect().get_center().y, 360),
		"earned title controls fit the 720px viewport")
	return app


func _refusals() -> void:
	var app: Node = await _earned()
	var original := _resources(app)
	for invalid in [-1, 101, 8.0, "8", null, true]:
		app.stitched_roadblock_candle = invalid
		var before := _resources(app)
		_check(not app._open_stitched_unpicker() and _resources(app) == before
			and app.unpicker_mounts == 0 and app._stitched_postvictory_stop_available,
			"malformed candle fails before mount without spending %s" % str(invalid))
	app.stitched_roadblock_candle = original["candle"]
	var roster: Array = app._stitched_campfire_authorized_roster.duplicate(true)
	app._stitched_campfire_authorized_roster[0]["position"] = 4
	_check(not app._open_stitched_unpicker() and _resources(app) == original,
		"forged rank roster cannot spend")
	app._stitched_campfire_authorized_roster = roster
	for bad_satchel in [[], [{"id": "invalid", "slot": "arms", "tier": 1, "torn": false}],
		[{"id": "broken"}], [42]]:
		app.stitched_preview_satchel = bad_satchel.duplicate(true)
		app._refresh_stitched_peddler_button()
		var before := _resources(app)
		_check(not app.stitched_unpicker_button.visible and not app._open_stitched_unpicker()
			and _resources(app) == before and app.unpicker_mounts == 0,
			"no spare or malformed satchel cannot offer, mount or spend")
	app.stitched_preview_satchel = original["satchel"].duplicate(true)
	app.fail_unpicker_mount = true
	_check(not app._open_stitched_unpicker() and app.unpicker_mounts == 1
		and _resources(app) == original and app._stitched_postvictory_stop_available
		and app.candle_at_mount == original["candle"]
		and app.projected_at_mount == maxi(0, int(original["candle"]) - 8),
		"actual failed mount preserves candle, wallet and eligibility")
	app.fail_unpicker_mount = false
	app._stitched_postvictory_stop_available = false
	_check(not app._open_stitched_unpicker() and _resources(app) == original,
		"missing stop authority refuses genuine old receipts")
	app._stitched_postvictory_stop_available = true
	_check(app._open_stitched_unpicker(), "failure recovery mounts original earned visit")
	app.free()
	await process_frame


func _visit(candle: int, leave := false, duplicate_spares := false, calm := false) -> void:
	var app: Node = await _earned(duplicate_spares, 75 if calm else 0)
	app.stitched_roadblock_candle = candle
	var before := _resources(app)
	var earned_battle: StitchedRules = app.get_meta("unpicker_rng_battle")
	_check(earned_battle != null and earned_battle.is_valid() and earned_battle.is_over(),
		"RNG witness is the actual settled seeded Roadblock")
	var held_rng: int = earned_battle.rng_state()
	seed(53401)
	var expected_global := randi()
	seed(53401)
	app.stitched_unpicker_button.pressed.emit()
	var event_panel: Control = app.stitched_unpicker_panel
	var event: RunStitchedInkblackUnpickerEvent = app.stitched_unpicker_event
	_check(event_panel != null and event != null and event.is_valid()
		and app.stitched_unpicker_visit == null, "earned button mounts Inkblack before any service")
	if event_panel == null or event == null:
		app.free()
		return
	var event_entered := before.duplicate(true)
	event_entered["candle"] = maxi(0, candle - 8)
	_check(_resources(app) == event_entered and app.candle_at_mount == candle
		and app.projected_at_mount == event_entered["candle"]
		and event.quote()["choices"].size() == 3
		and event.read_state()["heroes"] == app._stitched_campfire_authorized_roster,
		"three-choice Event mounts before exactly one candle debit with real ranked heroes")
	var hire: Button = event_panel.find_child("Inkblack_hire_unpicker", true, false)
	_check(hire != null and not hire.disabled and hire.focus_mode == Control.FOCUS_ALL,
		"post-toll spare makes Hire keyboard and mouse reachable")
	hire.pressed.emit()
	hire.pressed.emit()
	var panel: Control = app.stitched_unpicker_panel
	var visit: RunUnpickerVisit = app.stitched_unpicker_visit
	_check(panel != null and visit != null and visit.is_valid(), "offered button mounts real Unpicker")
	if panel == null or visit == null:
		app.free()
		return
	var source: WeakRef = weakref(panel)
	var generation: int = app._stitched_unpicker_generation
	var state := visit.read_state()
	var quote := visit.quote()
	_check(state["price"] == 75 and state["scrap_yield"] == 2
		and (not quote["hero_ids"].is_empty()) == calm,
		"live service uses the authored calm quote and only offers it when affordable after Hire")
	var entered := before.duplicate(true)
	entered["candle"] = maxi(0, candle - 8)
	entered["gold"] -= 10
	_check(_resources(app) == entered and app.candle_at_mount == entered["candle"]
		and app.projected_at_mount == entered["candle"]
		and str(entered["candle"]) in panel.get_node("UnpickerHeading").text
		and state["satchel"] == before["satchel"] and state["scraps"] == before["scraps"]
		and state["gold"] == entered["gold"] and event.is_claimed()
		and app._stitched_unpicker_event_receipt["source_state"]["wallet"]["gold"] == before["gold"],
		"Hire pays ten once, forwards post-toll wallet and retains its detached source receipt")
	_check(panel.theme == null and panel.get_theme_stylebox("normal", "Button") == app.get_theme_stylebox("normal", "Button"),
		"panel inherits existing gothic Theme")
	var buttons: Array[Node] = panel.find_children("UnpickSpare_*", "Button", true, false)
	_check(buttons.size() == before["satchel"].size() and quote["spare_indices"].size() == buttons.size()
		and panel.find_children("*", "Button", true, false).size() == buttons.size() + quote["hero_ids"].size() + 1,
		"all quoted indexed spare choices, calm targets and Leave are rendered")
	_check(not app._open_stitched_unpicker() and not app._open_stitched_peddler()
		and not app._open_stitched_campfire() and not app._open_stitched_postevent()
		and not app._open_stitched_fight() and _resources(app) == entered
		and not app.stitched_unpicker_button.visible and app.stitched_unpicker_button.focus_mode == Control.FOCUS_NONE,
		"mounted Unpicker excludes all competing stops, duplicate entry and fight")
	for index in [-2, 100]:
		_check(not app._stitched_unpicker_choose(index, source, generation).get("ok")
			and not visit.is_consumed() and _resources(app) == entered, "invalid indices preserve open visit and resources")
	var held_scraps: int = app.stitched_preview_scraps
	app.stitched_preview_scraps += 1
	var drifted := _resources(app)
	buttons[0].pressed.emit()
	_check(not visit.is_consumed() and _resources(app) == drifted, "drifted canonical wallet rejects mounted callback")
	app.stitched_preview_scraps = held_scraps
	var replacement := RunUnpickerVisit.open_stitched(app.STITCHED_UNPICKER_NODE_ID,
		state["heroes"], state["gold"], 75, state["satchel"], state["scraps"], 2)
	_check(replacement.is_valid() and replacement.read_state()["visit_id"] != state["visit_id"],
		"stale-visit witness is an independently valid equal-wallet service")
	app.stitched_unpicker_visit = replacement
	buttons[0].pressed.emit()
	_check(not visit.is_consumed() and not replacement.is_consumed() and _resources(app) == entered,
		"old mounted control cannot authorize a replacement visit")
	app.stitched_unpicker_visit = visit
	var hero_id: String = state["heroes"][0]["id"]
	var held_hp: int = app._stitched_hp_carry[hero_id]
	app._stitched_hp_carry[hero_id] = 0
	var fallen := _resources(app)
	buttons[0].pressed.emit()
	_check(not visit.is_consumed() and _resources(app) == fallen,
		"lost living-party prerequisite rejects mounted callbacks without spending")
	app._stitched_hp_carry[hero_id] = held_hp
	var index := 0
	if duplicate_spares:
		var found := false
		for i in before["satchel"].size():
			for j in range(i + 1, before["satchel"].size()):
				if before["satchel"][i]["id"] == before["satchel"][j]["id"]:
					index = j
					found = true
		_check(found, "two genuine victories earned repeated spare IDs")
	var calmed_id := ""
	if calm:
		_check(not quote["hero_ids"].is_empty() and not buttons.is_empty(),
			"post-toll wallet offers both separately paid calm and spare actions")
		if not quote["hero_ids"].is_empty():
			calmed_id = quote["hero_ids"][0]
	var button: Button = panel.find_child("CalmHero_" + calmed_id, true, false) if calm else \
		panel.find_child("UnpickerLeave", true, false) if leave else panel.find_child("UnpickSpare_%d" % index, true, false)
	_check(button != null and not button.disabled and button.focus_mode == Control.FOCUS_ALL,
		"genuinely offered decision is keyboard and mouse reachable")
	button.pressed.emit()
	button.pressed.emit()
	var after := entered.duplicate(true)
	if calm:
		after["gold"] -= 75
		after["fray"][calmed_id]["fray"] = maxi(0, int(after["fray"][calmed_id]["fray"]) - 50)
		if after["fray"][calmed_id]["fray"] < 50 and after["fray"][calmed_id]["resolve"] in StitchedS1BEffects.RESOLVE_TRAITS:
			after["fray"][calmed_id]["resolve"] = ""
	elif not leave:
		after["satchel"].remove_at(index)
		after["scraps"] += 2
	_check(_resources(app) == after and visit.is_consumed() and app.stitched_unpicker_panel == null
		and app.title_view.is_visible_in_tree(),
		"one indexed occurrence becomes exactly two scraps, or Leave preserves wallet")
	var saved: Dictionary = app._stitched_unpicker_event_receipt.duplicate(true)
	var exported := event.read_state()
	exported["wallet"]["gold"] = 999
	var service_export := visit.read_state()
	service_export["heroes"][0]["fray"] = 199
	_check(app._stitched_unpicker_event_receipt == saved
		and app._stitched_unpicker_service_receipt["source_snapshot"] == state,
		"retained Event and service receipts remain detached from exported states")
	_check(not app._stitched_unpicker_choose(index, source, generation).get("ok")
		and not app._open_stitched_unpicker() and not app._open_stitched_campfire()
		and not app._open_stitched_peddler() and not app._open_stitched_postevent()
		and _resources(app) == after and earned_battle.rng_state() == held_rng and randi() == expected_global,
		"stale/double controls and spent stop cannot mutate any carry or RNG")
	var stage: StitchedBattleScreen = await _admit(app)
	_check(stage != null and stage.battle != null and stage.battle.is_valid(), "later live fight mounts")
	if stage != null and stage.battle != null:
		_check(app.stitched_roadblock_candle == maxi(0, int(after["candle"]) - 8)
			and stage.battle.candle() == app.stitched_roadblock_candle
			and app.stitched_preview_satchel == after["satchel"] and app.stitched_preview_scraps == after["scraps"],
			"later real battle retains the Unpicker wallet and pays only its own candle toll")
		var later := _resources(app)
		# Inspect the real battle's admitted config before automatic opening turns
		# apply carried Bleed or foe actions to its runtime units.
		_check(stage.config["heroes"].size() == 4, "next Fight admits all four survivors")
		for rank in range(4):
			var hero: Dictionary = stage.config["heroes"][rank]
			var id: String = hero["id"]
			_check(hero["hp"] == after["hp"][id] and rank + 1 == after["ranks"][id]
				and hero["fray"] == after["fray"][id]["fray"]
				and hero["resolve"] == after["fray"][id]["resolve"],
				"next Fight receives genuine HP, rank, Fray and resolve for " + id)
		_check(not app._stitched_unpicker_choose(index, source, generation).get("ok")
			and _resources(app) == later, "old visit remains inert in later live play")
	app.free()
	await process_frame


func _competition() -> void:
	for stop in ["_open_stitched_peddler", "_open_stitched_campfire", "_open_stitched_postevent"]:
		var app: Node = await _earned()
		_check(app.call(stop), "competing stop actually mounts " + stop)
		var before := _resources(app)
		_check(not app._open_stitched_unpicker() and _resources(app) == before,
			"competing stop consumes common eligibility without extra Unpicker toll")
		app.free()
		await process_frame


func _event_transactions() -> void:
	for choice in ["sell_trim", "leave", "hire_unpicker"]:
		var app: Node = await _earned()
		app.stitched_unpicker_button.pressed.emit()
		var panel: Control = app.stitched_unpicker_panel
		var event: RunStitchedInkblackUnpickerEvent = app.stitched_unpicker_event
		_check(panel != null and event != null and event.is_valid(), "transaction witness is mounted earned Event")
		if panel == null or event == null:
			app.free()
			continue
		var source: WeakRef = weakref(panel)
		var generation: int = app._stitched_unpicker_generation
		var state := event.read_state()
		_check(panel.find_children("Inkblack_*", "Button", true, false).size() == 3
			and state["quoted_calm_price"] == 75 and state["quoted_scrap_yield"] == 2,
			"mounted Event preserves all three authored choices and separate service prices")
		for row: Dictionary in event.quote()["choices"]:
			var offered_button: Button = panel.find_child("Inkblack_" + str(row["choice_id"]), true, false)
			_check(offered_button != null and offered_button.disabled == not row["available"],
				"mounted availability agrees with the post-toll action quote")
		var before := _resources(app)
		var battle: StitchedRules = app.get_meta("unpicker_rng_battle")
		var held_rng := battle.rng_state()
		seed(536)
		var expected_global := randi()
		seed(536)
		for key in ["node_id", "version", "visit_id", "heroes", "wallet"]:
			var forged := state.duplicate(true)
			forged[key] = "forged"
			_check(not app._stitched_unpicker_event_choose(choice, forged, source, generation).get("ok")
				and not event.is_claimed() and _resources(app) == before,
				"forged or wrong-node Event snapshot fails closed " + key)
		_check(not app._stitched_unpicker_event_choose("bogus", state, source, generation).get("ok")
			and not app._stitched_unpicker_event_choose(choice, state, source, generation - 1).get("ok")
			and not app._open_stitched_unpicker() and not app._open_stitched_peddler()
			and not app._open_stitched_campfire() and not app._open_stitched_postevent()
			and not app._open_stitched_fight() and _resources(app) == before,
			"unoffered and stale requests and concurrent entry points preserve Event resources")
		var button: Button = panel.find_child("Inkblack_" + choice, true, false)
		_check(button != null and not button.disabled and button.focus_mode == Control.FOCUS_ALL,
			"authored decision uses a mounted keyboard reachable button")
		app.stitched_preview_gold += 1
		var drifted := _resources(app)
		button.pressed.emit()
		_check(not event.is_claimed() and _resources(app) == drifted, "wallet drift cannot settle Event")
		app.stitched_preview_gold -= 1
		app.stitched_peddler_panel = Control.new()
		button.pressed.emit()
		_check(not event.is_claimed() and _resources(app) == before, "concurrent screen cannot settle Event")
		app.stitched_peddler_panel.free()
		app.stitched_peddler_panel = null
		if choice == "hire_unpicker":
			app.fail_unpicker_mount = true
			button.pressed.emit()
			_check(not event.is_claimed() and app.stitched_unpicker_visit == null
				and _resources(app) == before and app.stitched_unpicker_panel == panel,
				"failed paid-service mount cannot claim Hire or spend any resource")
			app.fail_unpicker_mount = false
		button.pressed.emit()
		button.pressed.emit()
		var after := before.duplicate(true)
		if choice == "sell_trim":
			after["scraps"] += 1
		elif choice == "hire_unpicker":
			after["gold"] -= 10
		_check(event.is_claimed() and _resources(app) == after
			and (app.stitched_unpicker_visit != null) == (choice == "hire_unpicker")
			and (app.stitched_unpicker_panel == null) == (choice != "hire_unpicker"),
			"authored trade or Leave closes without service, Hire alone admits one service")
		_check(not app._stitched_unpicker_event_choose(choice, state, source, generation).get("ok")
			and _resources(app) == after and battle.rng_state() == held_rng and randi() == expected_global,
			"Event replay and all refused transactions leave currency, parts, Fray and RNG intact")
		app.free()
		await process_frame


func _run() -> void:
	await _refusals()
	await _event_transactions()
	await _visit(84)
	await _visit(3, true)
	await _visit(0)
	await _visit(84, false, true)
	await _visit(84, false, false, true)
	await _competition()
	if failures.is_empty():
		print("stitched_s6_unpicker_live_test: PASS (%d checks)" % checks)
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		quit(1)
